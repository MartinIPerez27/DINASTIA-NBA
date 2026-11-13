# Auditoría propia y opinión sobre la auditoría de Gemini

**Versión auditada:** commit `9cc80d2`, build 24. **Fecha:** 13 de noviembre de 2026.

Cada afirmación de la auditoría de Gemini se comprobó contra el código y el catálogo real (`assets/database/nba_players.json`). Para la pregunta de las medias se armó además un **prototipo de media alternativa** con estadísticas avanzadas de Basketball-Reference (BPM, VORP y WS/48). Esos datos están disponibles gratis en el mismo dataset que ya usa el proyecto.

---

## 1. Respuesta corta: ¿Lillard 93 y Holiday 88 están bien?

**Sí, están bien. El problema es lo que dice la etiqueta, no el número.**

- **Qué significa "HOY":** las cartas `actualidad` son **toda la década del 2020**, desde la temporada 2019-20 hasta la 2026-27 en curso. La carta "Lillard · POR · HOY" es el Lillard de Portland **2019-20 a 2022-23**: 29,2 puntos por partido, All-NBA y top 10 de la liga. No es el Lillard de hoy, que se perdió la temporada por el tendón de Aquiles. Leer "HOY" lleva a pensar en el jugador actual, y ahí está la confusión.
- **Con estadísticas avanzadas, Lillard sube:** su BPM en esas 225 partidas fue +6,1 y la media alternativa da **95**, no 93.
- **Holiday Milwaukee (2020-23, campeón, All-Star y All-Defense):** la media alternativa da exactamente **88**, la misma que tiene hoy.
- **Holiday hoy:** su carta en Boston está en **82**. La alternativa da 84, una diferencia razonable.

**Las que sí están mal son otras.** La fórmula actual premia el volumen de rebotes y asistencias por partido. Así quedan infladas:

| Carta | Media actual | Media con impacto (BPM/VORP) | BPM real | Partidos |
|---|---|---|---|---|
| Andre Drummond · DET · 2020s | **90** | 82 | +1,1 | 49 |
| Andre Drummond · DET · 2010s | 89 | 86 | +1,5 | 542 |
| Andre Drummond · CLE · 2020s | 87 | 76 | −0,7 | 33 |
| Russell Westbrook · WAS · 2020s | **91** | 87 | +3,7 | 65 |
| Russell Westbrook · HOU · 2020s | 90 | 83 | +1,5 | 57 |
| Russell Westbrook · LAL · 2020s | 85 | 78 | −1,1 | 130 |
| Rudy Gobert · MIN · 2020s | 89 | 85 | +1,3 | 300 |
| Karl-Anthony Towns · NYK · 2020s | 91 | 88 | +3,4 | 153 |

Y quedan **subvaloradas** cartas de jugadores con impacto que no se ve en el volumen bruto:

| Carta | Media actual | Media con impacto | BPM real |
|---|---|---|---|
| Jimmy Butler · CHI · 2010s | 86 | 91 | +3,9 |
| Jimmy Butler · MIA · 2020s | 91 | 95 | +6,4 |
| Nikola Jokić · DEN · 2010s | 91 | 94 | +7,0 |
| Arvydas Sabonis · POR · 90s | 85 | 90 | +5,2 |
| Tyrese Haliburton · IND · 2020s | 91 | 94 | +6,1 |
| Andre Iguodala · PHI · 2010s | 86 | 90 | +3,1 |

Las figuras indiscutidas no se mueven: Jordan 99, Jokić 2020s 98→99, Giannis 98, Curry 95–97, Durant OKC 97→98. Eso confirma que el método alternativo es coherente.

> El prototipo está en el scratchpad, no en el repo. Asigna las medias nuevas repartiéndolas igual que las actuales (por percentiles), así que la escala no cambia. Tiene un defecto: a jugadores con muy pocos minutos (por ejemplo Kostas Antetokounmpo, con 3,8 minutos por partido) los sube un poco de más. Hay que ajustar el peso de los minutos antes de usarlo en serio.

---

## 2. Opinión sobre cada punto de la auditoría de Gemini

Leyenda: ✅ correcto · 🟡 correcto a medias o con matices · ❌ incorrecto.

### Estadísticas, medias y tiers (§2 y §3.1)

| Punto | Veredicto | Comentario |
|---|---|---|
| "HOY" mezcla toda la década del 2020 | ✅ | Comprobado: `epoca_de` agrupa por año de cierre ≥ 2020. **Proponemos más que renombrar:** mostrar en la carta el rango real de temporadas ("POR 2020–23"). Es el cambio con mejor relación entre esfuerzo e impacto. |
| La fórmula premia el volumen e ignora la defensa | ✅ en el diagnóstico, 🟡 en la solución | La fórmula es el "NBA Efficiency" lineal por partido: un rebote vale lo mismo que un punto. Gemini propone sumar robos y tapones con más peso, que es un parche. **La solución de fondo:** usar `Advanced.csv` del mismo dataset (BPM desde 1974, WS/48 y PER antes), que ya mide el impacto por minuto, ajustado por ritmo y con la defensa incluida. Lo verificamos: el archivo existe y se descarga sin problemas. |
| Regresión por muestra chica (pocos partidos) | ✅ | De acuerdo, pero aplicada al impacto (BPM) y no a la eficiencia. El prototipo usa peso = PJ / (PJ + 50) hacia un BPM de −2. |
| Tier y media se solapan | ✅ el problema, 🟡 la solución | Hay **69 cartas A o B con media ≥ 90** y **10 cartas S con media ≤ 85**. Gemini propone acotar la media según el tier (A ≤ 89, S ≥ 88), pero eso falsearía números que hoy están bien: Durant Brooklyn 93 es correcto, el que está mal es su tier A. **Mejor arreglar el tier** (ver §3.2). |
| Error en `rol_de()` con los aleros | ✅ | Confirmado: **938 aleros son "Cerrojo defensivo" y solo 1 es "Especialista 3D"**, porque el `else` por defecto devuelve cerrojo. La corrección de Gemini va en la dirección correcta. **Atención:** en el perfil, `tres` es la proporción de tiros que son triples, no el porcentaje de acierto. Hay que usar las dos cosas (cantidad y acierto) para decidir quién es tirador. |

### Bugs y deuda técnica (§3.2 a §3.6)

| Punto | Veredicto | Comentario |
|---|---|---|
| Dinastía pierde la media envejecida | 🟡 | Gemini exagera. **En los partidos la media envejecida sí se usa**, porque el motor juega con el `Jugador` del plantel. Donde se busca la carta original del catálogo es en la forma (que usa estadísticas, que el envejecimiento no toca, así que no afecta) y en premios y Stats 82, solo al mostrar la media. Es un detalle de presentación, de prioridad baja. |
| Franquicias extintas sin uso | ✅ | Son **327 cartas** (no 296): Baltimore Bullets 69, Washington Capitols 36, etc. No salen en la ruleta por franquicia, ni como rivales, ni en Franquicia pura. **No coincido** con asignarlas a una franquicia actual (los Baltimore Bullets de 1947-54 no son los Wizards). Mejor una franquicia especial **"Pioneros BAA/NBA"**, con su pestaña en el álbum y como rival de modos históricos. |
| All-Star solo en memoria | ✅ | Ya estaba anotado como limitación. Hay que guardarlo en `Temporada` al cruzar la mitad de la temporada. |
| `CartaVertical.versiones` vacío | ✅ | Confirmado: solo se llena en `DraftPantalla`. Si abrís el álbum o una temporada sin pasar por el draft, no aparecen las etiquetas NOVATO, PRIME y VETERANO. **Es un bug real y se arregla con una línea.** |
| Cola estática de `Misiones` | 🟡 | Es real pero de riesgo bajo, porque todo pasa en el mismo guardado. Prioridad baja. |
| Violaciones de `DESIGN.md` | ✅ | Hay 6 `Text` con `Fuentes.led` sin `TextoLed`, así que les falta el dígito fantasma. El `BoxShadow` del medidor de química se agregó en la última tanda. Se arregla rápido. |

### Mejoras (§4)

| Punto | Veredicto | Comentario |
|---|---|---|
| Año de draft y edad desde el dataset | ✅ | Verificado: existen **`Draft Pick History.csv`** (año, ronda y número de elección) y **`Player Career Info.csv`** (fecha de nacimiento, debut, retiro y si está en el Salón de la Fama). Con esto "Reescribí la historia" puede usar la **camada real de cada año**, y Dinastía edades reales. |
| Dorsales para el 98 % | ❌ | **El dataset no trae dorsales**: lo revisamos y ninguno de esos archivos los tiene. `nba_api` da un solo número por jugador (el último), no uno por franquicia, y la NBA bloquea esas consultas desde la nube (desde una PC de casa funcionaría). Wikidata tiene números para muchos jugadores, pero incompletos. Se puede llegar a una cobertura alta, no del 98 % garantizado, y llevaría su trabajo. |
| Versionar el catálogo en el código de reto | ✅ | Es importante, y **hay que hacerlo antes de cambiar las medias**. Si no, los códigos de reto y el Desafío del día ya compartidos dejan de reproducir el mismo draft. |
| Dividir `partido_pantalla.dart` (1.907 líneas) y `motor.dart` (1.274) | ✅ | Coincido. Es mantenimiento y el usuario no lo nota: prioridad media. |
| Recorte de fotos y guardado fuera del hilo principal | ✅ | El recorte con máscara (`recortarConMascara`) corre en el hilo de la interfaz, sin `compute` ni `Isolate`. En celulares de gama media puede trabar la animación de la ruleta. Vale la pena. |
| Subir el ritmo a ~110 puntos | 🟡 | Es posible: las pruebas aceptan hasta 118. Pero es solo estético, y hay que volver a calibrar el balance. |
| Defensa por emparejamiento (60 % el rival directo) | ✅ como idea | Es la mejora del motor que más se sentiría. Cambia el balance, así que hay que hacerla con las pruebas de balance. |
| Arquetipos con efecto en el motor | ✅ | Confirmado: el motor no consulta `rol`; solo se usa en la afinidad del playbook. Efectos chicos y transparentes por arquetipo tendrían sentido, **pero recién después de arreglar el error de los aleros**. Si no, 938 "cerrojos" falsos tendrían un efecto defensivo. |
| Pulido de interfaz (LED animado, mapa de tiros de ambos equipos, revelado de cartas S/S+) | ✅ | Buenas ideas, de prioridad baja. |
| Test de balance permanente para los modos de escalera | ✅ | Ya estaba anotado como limitación. |

### Modos nuevos (§5)

| Propuesta | Opinión |
|---|---|
| **Tope salarial ($15)** | ⚠️ **Lo descartaste explícitamente** cuando elegimos los modos ("No quiero el tope salarial"). No lo sumaría salvo que hayas cambiado de idea. |
| Desafíos de armado con el álbum | 👍 Buena: le da un uso estratégico al álbum. |
| Carrera de una figura | 🟡 Se superpone bastante con Dinastía. Mejor como variante de Dinastía ("tu figura franquicia"). |
| **Guantelete de las décadas** | 👍 Muy buena: aprovecha las 9 épocas del catálogo. Las cartas anteriores a 1980 ya tienen 0 triples, así que esas eras ya se juegan distinto sin tocar el motor. |
| Insignias en Camino al anillo | 👍 Le suma profundidad al modo roguelike. |
| Escenarios de "último cuarto" | 👍 Muy buena: reutiliza el partido en vivo arrancando de un marcador real. |

---

## 3. Hallazgos propios (que Gemini no menciona)

### 3.1 Los premios se acumulan por tramo y sesgan la media hacia los tramos largos

- La media suma `0,6 × puntos de premios`, y esos puntos son **totales del tramo** (franquicia + década).
- Por eso, en igualdad de nivel, una carta de 9 temporadas en el mismo equipo tiene más media que una de 2. Ejemplo: Westbrook OKC 2010s tiene 97, en parte por 739 partidos de premios acumulados.
- **Propuesta:** usar los premios **por temporada** (tasa), no el total.

### 3.2 El tier también se acumula y castiga a las estrellas de paso corto

- El tier sale de los puntos de premios acumulados en el tramo (S desde 8, S+ desde 25).
- Por eso **Durant Brooklyn (All-NBA, 3 All-Star) es A**, **Harden Houston 2019-20 (All-NBA 1º equipo) es A** y **Jokić Denver 2010s (All-NBA 1º en 2019) es A**.
- **Propuesta:**
  - El tier se calcula con la **tasa de premios por temporada** y con el **pico de nivel** (media).
  - Por ejemplo: S+ si media ≥ 95 y premios de élite; S si media ≥ 90 o un All-NBA de 1º equipo; A desde 80 o con premios; B el resto.
  - Así el tier vuelve a significar "qué tan buena es la carta" y deja de significar "cuánto tiempo estuvo en ese equipo".

### 3.3 El corte por década parte carreras

- Wilt Chamberlain en los Lakers queda partido entre 1969 (años 60) y 1970-73 (años 70). Cada mitad acumula menos premios, y la de los 60 queda en **Tier A**.
- Lo mismo pasa con muchas carreras que cruzan un cambio de década.
- Con el rango de temporadas visible en la carta (§2) se entiende mejor, y con el tier por tasa (§3.2) deja de castigar.

### 3.4 Entra la temporada 2026-27 en curso

- El caché tiene **441 filas de 2026-27** (temporada en curso, partidos parciales), que entran en las cartas `actualidad`.
- No es un error, pero mezcla datos parciales. Conviene decidir si se incluye la temporada en curso o se corta en la última terminada.

### 3.5 Cualquier cambio de medias desarma el balance y el determinismo

- La dificultad apunta a medias objetivo de rivales (79 en Normal, 84 en Difícil). Si cambia la escala de medias, hay que **recalibrar**. Las pruebas de balance lo van a marcar, que es justamente para lo que están.
- Antes de cambiar el catálogo hay que **versionarlo** (un campo `versionCatalogo` en las partidas y en el código de reto), para que los retos y desafíos ya compartidos sigan funcionando.

### 3.6 Las estadísticas estimadas de antes de 1974 pesan en la media

- 2.183 cartas tienen robos, tapones, pérdidas o minutos estimados con promedios por posición. En la media actual esos valores inventados suman o restan lo mismo que los reales.
- Con WS/48 y PER (que existen desde los años 50) se puede calcular el impacto de esas cartas sin depender de lo estimado.

---

## 4. Plan sugerido, en orden

| Prioridad | Bloque | Qué incluye | Impacto en el balance |
|---|---|---|---|
| **1** | Arreglos rápidos sin riesgo | Mostrar el **rango de temporadas** en la carta y cambiar "HOY" por "20s"; arreglar los **arquetipos de alero**; inicializar las **versiones** al cargar el catálogo; guardar el **All-Star** en la partida; los 6 `TextoLed` y el `BoxShadow`. | Ninguno |
| **2** | **Versionar el catálogo** | `versionCatalogo` en las partidas, en el código de reto y en el Desafío del día. | Ninguno, y protege lo que viene |
| **3** | **Media y tier v2** | Media por impacto (BPM/VORP/WS48) con regresión por muestra y premios por temporada; tier por tasa de premios + pico; **volver a calibrar la dificultad** con las pruebas de balance. | Alto: hay que recalibrar |
| **4** | Datos nuevos | Año de draft y edad real (camadas reales en Reescribí, edades reales en Dinastía); franquicia **Pioneros** para las 327 cartas extintas. | Bajo |
| **5** | Motor | Defensa por emparejamiento; arquetipos con efecto (después del bloque 1); ritmo opcional hacia ~108–110 puntos. | Medio: recalibrar |
| **6** | Contenido | Escenarios de último cuarto, Guantelete de las décadas, insignias en Camino al anillo, desafíos de armado con el álbum. | Bajo |
| **7** | Mantenimiento | Dividir `partido_pantalla.dart` y `motor.dart`; recorte de fotos en `Isolate`; test de balance de los modos de escalera. | Ninguno |

**Recomendación:** hacer 1 y 2 juntos (son cortos y seguros), después 3. El bloque 3 es el que corrige lo que viste en las medias y deja ordenada la jerarquía de cartas.
