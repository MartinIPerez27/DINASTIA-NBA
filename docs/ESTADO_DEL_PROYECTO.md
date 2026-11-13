# Dinastía NBA (82-0): estado del proyecto

Documento para auditar el proyecto: qué se construyó, cómo funciona, cómo se compila y se prueba, qué decisiones se tomaron y qué limitaciones se conocen.

- **Fecha:** 2026-11-13.
- **Último commit en `main` al escribirlo:** `9cc80d2` (build 24).
- **Repositorio:** `MartinIPerez27/DINASTIA-NBA`, rama `main`.

---

## 1. Qué es

Juego personal para Android, gratis y **100 % offline**. No tiene cuentas ni compras, y no usa APIs pagas ni analítica. El jugador:

1. Arma un plantel de 6 cartas: 5 titulares y un Sexto Hombre.
2. Elige las tácticas.
3. Juega una temporada NBA de 82 partidos contra las otras 29 franquicias, armadas con sus jugadores históricos. Cada partido se puede jugar "en vivo" (simulación 2D animada) o simular. Después vienen los playoffs.

El objetivo simbólico es la temporada perfecta, el **82-0**.

Además del modo clásico hay 15 modos más: desafíos, torneos históricos, carrera de varias temporadas, modos con amigos en el mismo dispositivo y el reto por código. También hay un metajuego: nivel, monedas, logros, álbum, misiones, pase de temporada y cosméticos.

- **Idioma:** español rioplatense con voseo.
- **Estilo visual:** "El Marcador": tablero LED de estadio, tipografías Doto (LED) y Big Shoulders. Detalle en `DESIGN.md` y `PRODUCT.md`.

---

## 2. Cómo se obtiene, compila y prueba

### Descargar el APK

- La CI (`.github/workflows/apk.yml`) compila en cada push a `main` y lo publica en el Release `ultima`.
- Descarga directa: `https://github.com/MartinIPerez27/DINASTIA-NBA/releases/download/ultima/dinastia-nba.apk`.
- Antes de compilar, la CI corre `flutter analyze`, `flutter test` y los tests Python de `tools/`. Si algo falla, no publica.

### Compilar a mano

Requiere **Flutter 3.47.9** (Dart 3.13.7) y Java 17.

```bash
flutter pub get
flutter analyze
flutter test                      # ~165 tests, ~1 minuto
flutter build apk --release --target-platform android-arm,android-arm64 --build-number=N
```

### Capturas visuales

- Hay golden tests con fuentes reales en `capturas/*_test.dart`. Generan PNG en `capturas/salida/`, que está en `.gitignore`.
- **No corren en la CI.** Se generan con:

```bash
flutter test --update-goldens capturas/<archivo>_test.dart
```

### Herramientas de datos (`tools/`, Python)

| Script | Para qué |
|---|---|
| `catalogo_bbref.py` | Genera el catálogo de cartas (`assets/database/nba_players.json`). |
| `fotos.py` | Resuelve las fuentes de foto de cada carta. |
| `extraer_cartas.py` | Extracción de cartas. |
| `normalizar_escudos.py` | Prepara los escudos. |
| `entrenadores.py` | Baja las fotos de entrenadores de Wikimedia Commons y les quita el fondo con rembg. |
| `encuadrar_entrenadores.py` | Encuadre parejo de las fotos de entrenadores (usa OpenCV/numpy). |
| `sonidos.py` | Sintetiza los sonidos OGG. |
| `ajustes_cartas.json` | Correcciones manuales a cartas. |

Hay tests unitarios en `tools/test_*.py`.

---

## 3. Stack y arquitectura

- **Flutter/Dart**, con Material 3 y un tema propio por franquicia (`presentation/tema`).
- **Dependencias:**

| Paquete | Uso |
|---|---|
| `sqflite` | Partidas guardadas y perfil. |
| `cached_network_image`, `flutter_cache_manager` | Fotos con caché en disco. |
| `flutter_svg` | Escudos. |
| `audioplayers` | Sonidos. |
| `google_mlkit_selfie_segmentation` | Recorte de fondo de fotos en el dispositivo. |
| `path_provider` | Rutas locales. |
| `share_plus` | Compartir imagen y código de reto. |
| `file_picker` | Importar copias de seguridad. |
| `flutter_tts` | Voz opcional del relator. |

- **Arquitectura limpia en tres capas:**
  - `lib/domain/`: Dart puro, sin Flutter. Reglas, motor de partido, liga, draft, modos y metajuego. Todo es testeable sin UI.
  - `lib/data/`: catálogo, franquicias, base local (`db_local.dart`) y estado global de la app (`estado_app.dart`, con `perfilApp` y `ajustesApp` como `ValueNotifier`).
  - `lib/presentation/`: pantallas, widgets, partido en vivo (`partido/`), draft (`draft/`), modos (`modos/`), temporada (`temporada/`) y compartir (`compartir/`).
- **Tamaño:** 98 archivos Dart y ~30.000 líneas en `lib/`, más 31 archivos de test.

### Archivos clave

| Archivo | Qué hace |
|---|---|
| `lib/main.dart` | Arranque, navegación por fase, guardado y aplicación del metajuego en cada guardado. |
| `lib/domain/motor.dart` | Motor de partido por posesiones. |
| `lib/domain/liga.dart` | Temporada: calendario, rivales, simulación, lesiones, forma, playoffs, agentes libres. |
| `lib/domain/draft.dart` | Draft: ruleta, sobres, reglas, serpiente, entrenadores. |
| `lib/domain/entities/temporada.dart` | La partida guardada completa (JSON). |
| `lib/domain/progreso.dart` | Metajuego: XP, monedas, logros, trofeos, misiones, revancha. |
| `lib/presentation/pantallas/partido_pantalla.dart` | Partido en vivo. |
| `lib/presentation/partido/coreografia.dart` | Animación de cada jugada. |
| `lib/presentation/modos/modos.dart` | Menú y despacho de modos (`ContextoModos`, `iniciarModo`, `pantallaDeModo`). |

---

## 4. Datos

### Catálogo de cartas (`assets/database/nba_players.json`, 4,1 MB)

- **11.323 cartas.** Una carta es jugador + franquicia + época (década), con un mínimo de partidos en ese tramo.
- **Por tier:** B 8.084 · A 3.004 · S 161 · S+ 74.
- **Fuente:** datasets públicos de Basketball-Reference (`sumitrodatta/bball-reference-datasets`): totales por temporada y equipo desde 1947, posiciones, All-Star, All-NBA y premios.
- **Contenido de cada carta:**
  - 11 estadísticas: PPP, RPP, APP, robos, tapones, %TC, %T3, %TL, minutos, pérdidas e IQ (1–99);
  - posiciones, tier, rol (arquetipo) y media;
  - identidad de época (por ejemplo "Seattle SuperSonics") y fuentes de foto.
- **Estadísticas estimadas:** 2.183 cartas tienen datos estimados, marcados en `estimadas`. La NBA no registraba robos y tapones antes de 1974, pérdidas antes de 1978, rebotes antes de 1951 ni minutos antes de 1952. Se estiman con el promedio por posición de las primeras temporadas que sí los tienen. Los triples antes de 1980 valen 0.
- **Dorsales:** el catálogo solo los tenía en 15 cartas. **Se quitaron de toda la UI** (regla: todos o ninguno). En las fichas se ven las iniciales y en las placas el apellido.
- **Sin año de draft:** el catálogo no tiene el año de draft de cada jugador. Esto afecta a "Reescribí la historia" (ver §9).

### Franquicias e identidades

- Son 30 franquicias (`data/franquicias.dart`), con colores, conferencia, división y escudo SVG (`assets/logos/`).
- Las identidades históricas (SuperSonics, Bullets, New Jersey Nets…) tienen escudos en `assets/logos/historicos/`.

### Fotos de jugadores

- **Fuentes por carta, en orden:** `n` (CDN de la NBA, headshots de 1040×760), `b` (Basketball-Reference) y `w` (Wikipedia).
- **Reparto:** 4.655 cartas usan `n`; 6.668 usan `b` y `w`.
- **Wikipedia:** se consulta desde el celular, porque Wikipedia limita a los servidores en la nube. Se pide la miniatura de 960 px, o el original si es más chico (`core/foto_wikipedia.dart`).
- **Recorte de fondo:** las fotos de archivo se recortan **en el dispositivo** con ML Kit Selfie Segmentation (`core/recorte_fotos.dart`), con caché en `recortes_v2/`.
- **Sin red:** se juega igual. Las fotos ya vistas quedan en caché; si falta una, se muestran las iniciales.

### Entrenadores

- Hay 18 entrenadores reales (Jackson, Popovich, Riley, Auerbach, Kerr…), con su táctica preferida y las franquicias que dirigieron.
- Sus fotos son WebP sin fondo, de Wikimedia Commons, con créditos en `assets/entrenadores/CREDITOS.md`.
- Ocho fotos se reencuadraron a mano para que todas se vean parecidas.

### Sonido y tipografías

- **Sonidos:** sintetizados con `tools/sonidos.py`, sin licencias de terceros. Son bocina, red, aro, pique, silbato, público, abucheo, "defensa", ovación y golpe.
- **Tipografías:** OFL, con sus licencias registradas en la app.

---

## 5. Flujo del modo clásico

### 5.1 Draft

- **Dos modos de armado:**
  - **Ruleta:** tres carretes (franquicia, época y rareza), y se elige 1 de las cartas que salen.
  - **Cartas:** se elige 1 de 3 sobres (época, franquicia o misterioso), se abre y se ficha 1 de 5.
- **Reglas de draft:** Libre, Una sola década, Franquicia pura, Underdog (solo A y B), A ciegas, Draft en serpiente y Mi colección. A ciegas y Serpiente son solo para el modo Cartas.
- **Serpiente:** los rivales también eligen ("robos"), y esas cartas entran sí o sí en su plantel.
- **Fichas para volver a tirar:** 3 por temporada, más las de las ventajas de nivel. Cada paso del draft se guarda al instante, así que cerrar la app no regala tiradas.
- **Química** (`domain/quimica.dart`):
  - **Puntaje:** de 0 a 100, según vínculos entre pares: misma franquicia (+1), misma época (+1), compañeros de época (+3), dúo legendario (+6, hay 44 dúos curados) y entrenador que los dirigió (+2).
  - **Efecto en el partido:** de −1 a +1 punto porcentual de acierto en cada tiro; 50 es neutro.
  - **Medidor:** franjas Baja (0–39), Media (40–59), Alta (60–84) y Excelente (85–100), con la marca del plantel.
- **Entrenador:** se elige 1 de 18. Si coincide su táctica, suma afinidad.
- **Versiones de carta:** Novato, Prime y Veterano.

### 5.2 Tácticas (Playbook)

- Hay sistemas ofensivos (Pace & Space, Triángulo, Seven Seconds…) y defensivos (Drop Coverage, Switch All, Trap/Blitz, Zona, Presión…). Cada uno tiene efectos en triples, juego interior, pérdidas, robos, contraataque, ritmo y fatiga.
- El juego recomienda la táctica según el perfil del plantel.

### 5.3 Temporada regular

- **Calendario:** 82 partidos, con jornadas comprimidas (88).
- **Rivales:** las 29 franquicias restantes, armadas con su plantel "Histórico" (lo mejor de su historia) o "de Época" (una década real). Se muestran como "Detroit Pistons (90’)".
- **Dificultad:** fija la media a la que apuntan los planteles rivales (ver §8).
- **Desgaste del calendario:**
  - back-to-back en ~18 % de los partidos, asignado de forma determinista;
  - giras de visitante de 3 partidos o más;
  - los dos le bajan la energía inicial al equipo.
- **Forma (−3 a +3, se suma a la media):**
  - Después de cada partido se compara la producción del jugador con lo que promedia su carta en esos minutos, **relativo a sus compañeros del mismo partido**.
  - Un partido muy bueno suma 1, uno muy flojo resta 1 y uno normal la acerca 1 a cero.
  - Corrección reciente: antes se comparaba en absoluto, la forma tendía a −2/−3 y no volvía a cero.
- **Lesiones:**
  - Probabilidad de 0,5 % por jugador y por partido jugado.
  - Duración: 1–3 partidos (60 %), 4–10 (30 %) u 11–25 (10 %).
  - El titular lesionado lo reemplaza el sano que puede jugar ese puesto. Los rivales usan jugadores de su franquicia y época.
- **Banco largo:**
  - Hasta 2 suplentes además del Sexto Hombre, o sea una rotación de 8.
  - **Desde el último cambio, cada temporada arranca con 2 suplentes de puestos distintos**, elegidos entre los agentes libres. Se liberan o cambian desde la pestaña Plantel con FIRMAR.
  - Entran si un titular está fundido o lesionado, o en un final liquidado (último cuarto, 18 puntos o más).
- **Agentes libres:** 8 cartas A o B con media de 72 a 86 que no estén en ningún plantel. Son deterministas por bloque de 10 jornadas.
- **Mercado de pases:**
  - Cierra al 60 % de la temporada y permite como máximo 3 pases.
  - El cambio es carta por carta y en el mismo puesto. Las S+ son casi intocables y hay contraofertas.
- **Copa NBA:**
  - Arranca al 35 % de la temporada con los 4 mejores de cada conferencia, a partido único (cuartos, semis y final).
  - No cuenta para el récord. Tiene trofeo y logro propios.
  - Si el usuario no juega su partido en 4 jornadas, se simula solo.
- **Clima de temporada:** titulares semanales, carrera al MVP, récords históricos en juego y fin de semana All-Star.
- **Simular:** de a 1, de a 10 o la temporada entera. El récord y los resultados se actualizan en pantalla partido a partido.

### 5.4 Playoffs

- **Play-In:** 7º–10º, a partido único: 7–8 y 9–10, y después el último boleto.
- **Cuadro:** 1-8, 4-5, 3-6 y 2-7. Series al mejor de 7 con localía 2-2-1-1-1.
- **Desempates oficiales:** enfrentamiento directo, récord contra la conferencia y diferencia de puntos.
- La serie del usuario se juega partido a partido, y el resto de la ronda avanza a la par.

### 5.5 Premios

MVP, Máximo Anotador, DPOY, Sexto Hombre, Más Mejorado y quintetos All-NBA 1-2-3, con un historial por partida.

---

## 6. Motor de partido (`lib/domain/motor.dart`)

### Mecánica general

- Es una **simulación por posesiones** con reloj de juego y de posesión (24 s): 4 cuartos de 12 minutos, más prórrogas de 5.
- **Probabilidad de acierto de cada tiro:**
  - Parte de la base del tipo de tiro y del jugador (%TC y %T3).
  - Suma la diferencia de media entre el tirador y la defensa en cancha (×`pesoDiferencia` = **1/225**).
  - Suma la química (±1 punto), la afinidad táctica y del entrenador (diferencia ofensiva menos defensiva /1500) y la localía (+1,2 puntos).
  - En el clutch suma la "sangre fría", deducida del nivel del jugador.
  - La fatiga (energía) la reduce.
- **Clutch:** los últimos 5 minutos del 4º cuarto o de la prórroga, con 6 puntos de diferencia o menos. La estrella toma más tiros (×1,6) y aplica el modificador de clutch.
- **Cambios:**
  - rotación automática por energía y minutos del Sexto Hombre (pocos, normal o muchos);
  - cambios manuales en vivo;
  - cambio forzado por carga de faltas;
  - guarda anti ping-pong: al menos 2 posesiones entre cambios.
- **Jugada clave:** en el final apretado, el usuario elige entre aislamiento, pick & roll, etc.

### Jugadas modeladas

- **Tiros:** dobles, triples, volcadas, alley-oops, contraataques, rebote ofensivo con segunda oportunidad e interferencia (el tiro errado vale como convertido).
- **Tapones:** a veces los recupera el ataque.
- **Pérdidas:** por robo, pelota afuera, carga (falta en ataque), pasos, dobles, 24 segundos, 3 segundos y campo atrás.
- **Faltas:**
  - en el tiro (2 o 3 libres, y el 2+1);
  - sin tiro: saque lateral hasta la 4ª falta del equipo en el cuarto, y desde la 5ª bonus con 2 libres;
  - técnica: 1 libre, no cuenta como personal, y 2 técnicas expulsan;
  - flagrante: 2 libres y la pelota;
  - falta intencional en los últimos 35 s, del que pierde por 3 a 8, al peor tirador de libres;
  - sexta falta: expulsión.
- **Fin de cuarto:** tiro sobre la chicharra, y lanzamiento desde la otra mitad con 2,6 s o menos.
- **Otras:** salto inicial, salto entre dos por pelota retenida, tiempos muertos y fin de cuarto o de partido.
- **Cerca del final:** el que pierde tira rápido (4–8 s) y el que gana gasta el reloj (17–22 s).
- **Seguridad:** todo evento consume como mínimo 0,5 s, así que no puede haber bucles infinitos (ya pasó una vez).

### Tasas por partido (los dos equipos, 60 partidos simulados)

| | Antes | Ahora | NBA real |
|---|---|---|---|
| Tapones | 4,8 | 10,3 | ~10 |
| Robos | 9,4 | 15,1 | ~15 |
| Pérdidas | 16,9 | 27,9 | ~27 |
| Faltas personales | 18,8 | 40,5 | ~40 |
| Tiros libres intentados | 30 | 48 | ~45 |
| Puntos por equipo | 93 | ~103 | ~110–115 |

Hay valores más bajos de propósito: técnicas 0,42, flagrantes 0,05, intencionales 0,45, interferencias 0,32, saltos entre dos 0,22 y expulsiones por faltas ~0,10 por partido.

---

## 7. Partido en vivo (presentación)

- **Cancha 2D en vista de transmisión:**
  - aros, escudo central y carteles LED;
  - cámara que sigue la pelota con zoom;
  - fichas con los colores de la camiseta y las iniciales;
  - el salto se ve como una ficha que crece con su sombra.
- **Coreografía** (`presentation/partido/coreografia.dart`):
  - Cada evento tiene su línea de tiempo en segundos, con keyframes y una curva seno exacta.
  - Los defensores persiguen al atacante con velocidad y aceleración limitadas.
  - La pelota siempre sale de una mano y llega a otra.
  - Hay animaciones propias para robos, tapones (pelota despedida), carga, violaciones, salto entre dos, lanzamiento desde lejos e interferencia, y momentos de silbato.
  - Nadie sale de la cancha ni se teletransporta. Lo verifica un test sobre partidos completos.
- **Marcador estilo TV:** cuarto, reloj, 24 s, faltas por equipo y BONUS, y tiempos muertos.
- **Carteles por jugada:** FALTA TÉCNICA, EN BONUS · 2 LIBRES, etc.
- **Relator** (`domain/relator.dart`): frases variadas en rioplatense para cada tipo de jugada y para el contexto (empate, lo da vuelta, final apretado, sangre fría). La voz es opcional con TTS (`VozRelator`).
- **Sonido:** red, aro, pique, silbato, golpe del tapón, público y abucheos de visitante, que se pueden apagar.
- **Controles:** velocidad x1/x2/x4, pausa, tiempo muerto, acelerar ritmo o presión alta, cambios, jugada clave y saltar al final.
- **Paneles:** Equipo, Tiros (mapa de tiros), Partido (probabilidad de ganar y parciales por cuarto) y Relato.
- **Repeticiones** de las jugadas destacadas en cámara lenta, y un **pospartido** con jugador del partido, box score de los dos equipos y las 3 mejores jugadas.

---

## 8. Dificultad y balance

| Dificultad | Media objetivo de rivales | Gana un draft típico | Gana el mejor plantel posible | Puntos por equipo |
|---|---|---|---|---|
| Normal | 79 | 59 % | 98 % | 103 |
| Difícil | **84** (antes 82) | 30 % | 89 % | 105 |
| Leyenda | lo mejor de cada franquicia | 14 % | 60 % | 104 |

`test/balance_test.dart` simula temporadas y exige:

- Normal: típico entre 45 y 78 %, mejor ≥ 90 %.
- Difícil: típico entre 20 y 40 %, mejor entre 75 y 96 %.
- Leyenda: típico ≤ 30 %, mejor entre 50 y 90 %.
- Orden estricto Normal > Difícil > Leyenda.
- Puntos por equipo entre 90 y 118.

Así cualquier cambio del motor que desbalancee se detecta.

---

## 9. Modos de juego

Se entra desde **Inicio → "OTROS MODOS DE JUEGO"**. Cada partida guarda su modo en `Temporada.modoJuego` y su estado propio en `Temporada.datosModo` (JSON).

| Grupo | Modo | Reglas clave |
|---|---|---|
| Temporada | **Temporada 82-0** | El flujo clásico (§5). |
| Partidas rápidas | **Racha infinita** | Draft y después rivales al azar cada vez más fuertes hasta perder. La mejor racha va al Salón. |
| Desafíos | **Desafío del día** | Mismo draft, rivales y calendario para todos según la fecha (semilla `aaaammdd`). Un intento por día; el puntaje son las victorias. |
| | **Escenarios históricos** | 8 momentos reales (Finales 98 Jazz-Bulls, 2016 Cavs 1-3, etc.). Sin draft: plantel histórico y serie que arranca en el resultado real. No suman al álbum. |
| | **Camino al anillo** | 9 rivales a partido único y Las Finales al mejor de 7 contra un "mejor equipo de la historia". Entre partidos se elige 1 de 3 ventajas. Si perdés, se termina. |
| | **Extremo** | 0 fichas, lesiones ×2 de frecuencia y +50 % de duración, Difícil fijo, una sola partida activa. Eliminado = partida perdida. |
| | **Leyenda única** | Elegís 1 de 6 figuras (S+ o S) y el resto sale al azar. No suma al álbum. |
| | **Modo espejo** | Dirigís el plantel que la IA armó con las cartas que dejaste pasar; tu draft juega en tu contra en tu conferencia. |
| Torneos | **Los mejores equipos de la historia** | 10 planteles reales (Bulls 95-96, Warriors 16-17, Lakers 86-87…) en series al mejor de 3. Es a propósito el modo más difícil. |
| | **Mundial de franquicias** | Cuadro de 32: tu equipo, las otras 29 y dos clásicos (Sonics y Nets de New Jersey). Partido único hasta cuartos; semis y final al mejor de 3. |
| Gestión y carrera | **Dinastía** | Temporadas encadenadas. En el receso: envejecimiento con media según la edad, retiros con despedida (como mucho 3) y mini-draft de 1 de 3 novatos por puesto libre. Historia narrada en una línea de tiempo. |
| | **Reescribí la historia** | Plantel real de una franquicia en una década. Avanza de década cada 3 temporadas. **Los novatos son de la década siguiente, no del draft real de ese año**, porque el catálogo no tiene años de draft. La UI lo aclara. |
| | **Solo entrenador** | Plantel al azar y vos solo manejás tácticas y rotación. No suma al álbum. |
| Con amigos | **Draft en grupo** | De 2 a 8 personas en el mismo dispositivo. Draft por turnos con "pasale el dispositivo": 4 cartas por turno y sin repetidos. Después todos contra todos (ida y vuelta) y final al mejor de 3. Da poco XP. |
| | **Duelo** | 2 personas, 2 drafts y serie al mejor de 7 con localía 2-2-1-1-1. |
| | **Reto de un amigo** | Ingresar un código de reto (§11). |

Organización del código: `presentation/modos/{escalera, variantes, carrera, amigos, reto}.dart` y `domain/modos/*`, más `domain/variantes.dart` y `domain/reto.dart`. `ModoJuego.usaTemporada` indica si el modo arma el calendario de 82.

---

## 10. Metajuego (`domain/progreso.dart`, `domain/entities/perfil.dart`)

`Progreso.aplicar(perfil, antes, después)` corre en cada guardado y calcula todo a partir de la diferencia de estado:

- **XP y nivel:** el umbral del nivel n es 75·n·(n−1).
- **Ventajas por nivel:**
  - +1 ficha (nivel 3);
  - +1 tiempo muerto (nivel 6);
  - 2ª ficha extra (nivel 10);
  - tiempos muertos que recuperan el doble (nivel 15).
- **Monedas del juego:** no son dinero real. Se usan en la tienda de sobres.
- **Puntaje personal (estilo Elo):** según resultados y dificultad.
- **32 logros:** primer triunfo, rachas, 60/70 victorias, 82-0, 16-0 en playoffs, campeón en Difícil o Leyenda, Copa NBA, modos (Camino, Mundial, Dinastía ×3, Revancha, Extremo, Espejo, etc.).
- **Vitrina de trofeos**, historial de temporadas y **carrera de cada carta** (usos y promedios con vos).
- **Álbum:** colección permanente de cartas y tienda de sobres. Lo ganado en modos con plantel prestado no suma al álbum.
- **Misiones:** 3 diarias y 3 semanales, deterministas por fecha. Avanzan solas y se cobran con XP, monedas y puntos del pase.
- **Pase de temporada offline:** 20 niveles por trimestre, con premios solo estéticos.
- **Vestuario:**
  - 4 canchas (moderna, parquet de los 70, parquet a cuadros, cemento de barrio);
  - 3 pelotas (naranja, ABA, dorada);
  - 3 uniformes (titular, alternativo, crema clásico);
  - 5 temas LED.
  - Algunos se ganan por nivel. Sin nada elegido, el juego se ve igual que antes.
- **Rivalidades / Revancha:**
  - El perfil recuerda quién te eliminó o te ganó muchas veces.
  - El aviso "REVANCHA · Te eliminaron en…" sale en la tarjeta del próximo partido y en la serie de playoffs.
  - Ganarle una serie después da un logro y premios.

---

## 11. Compartir y código de reto

- **Imagen para compartir:**
  - 1080×1920, renderizada fuera de pantalla con `RepaintBoundary` y compartida con `share_plus`.
  - Lleva escudo, récord LED, anillo, las 6 cartas, premios y el código de reto.
  - Tiene variantes para temporada, desafíos, dinastía y reto.
- **Código de reto `82-XXXX-XXXX-XXXX`** (`domain/reto.dart`):
  - Es Crockford base32 con 52 bits de datos más CRC-8. Rechaza cualquier error de un carácter.
  - Lleva: semilla (28 bits), franquicia, modo de draft, regla y época, dificultad, y las victorias del que reta y si salió campeón.
  - Al cargarlo se reproduce el mismo draft (un `Random` derivado por paso), los mismos entrenadores, rivales y calendario.
  - Al final se comparan los récords; si empatan, desempata el anillo.
  - Solo las partidas creadas desde esa versión tienen semilla. La regla "Mi colección" no se puede retar.

---

## 12. Persistencia

- **Base local SQLite** (`data/db_local.dart`): partidas (`Temporada` serializada a JSON), perfil y ajustes.
- **Compatibilidad:** el JSON es retrocompatible. Los campos nuevos se escriben solo si no están vacíos y se leen con valores por defecto.
- **Guardado:** se hace en cada paso relevante (cada pick del draft, cada partido). El metajuego se aplica en el mismo momento.
- **Copias:** se pueden exportar e importar partidas sueltas o una copia completa con perfil y ajustes (Partidas → menú).
- **Varias partidas guardadas:** la lista muestra el modo, la fase ("Temporada 3", "Liga", "Perdida") y el récord o la serie.

---

## 13. Tablet horizontal

- Pensada para una BMAX Power 11.4" 2K usada en apaisado.
- Helper `presentation/widgets/disposicion.dart`: `esTabletApaisada(context)` es verdadero con ancho ≥ 900 y más ancho que alto. Incluye `DosPaneles` y `AnchoMaximo`.
- **Pantallas en dos paneles:**
  - Partido en vivo: la cancha a la izquierda a toda altura, los paneles a la derecha, sin scroll.
  - Draft: la cancha del plantel y la grilla de cartas en 4 columnas.
  - Temporada: el hub a la izquierda y las pestañas a la derecha.
  - Playoffs: cuadro completo Este | Finales | Oeste.
  - Inicio: el escudo y una grilla de las 15 franquicias.
  - Playbook.
- **El resto** se centra con un ancho máximo. **El teléfono no cambia.**
- **Orientación:** no está bloqueada en ningún lado.

---

## 14. Calidad y pruebas

- **`flutter analyze`:** sin issues.
- **`flutter test`:** 165 tests, todos pasan. Cubren:
  - dominio, draft, liga, calendario, motor, jugadas;
  - coreografía (continuidad, cancha, sin teletransporte);
  - balance, playoffs, premios, lesiones, mercado, Copa;
  - escalera, variantes, dinastía, amigos, metajuego, compartir/reto, fotos de Wikipedia;
  - pantallas (inicio, draft, playbook, temporada, playoffs, partidas, partido en vivo), progreso, ajustes y tutorial.
- **Golden captures:** 23 archivos en `capturas/`. Se revisaron a ojo en cada tanda (desbordes, legibilidad). No corren en la CI porque necesitan las fuentes reales.
- **CI:** analyze, tests Flutter y tests Python de `tools/` antes de compilar y publicar el APK.

---

## 15. Decisiones de diseño y supuestos (para revisar)

1. **Rivales por "media objetivo"** en vez de lo mejor de cada franquicia, salvo en Leyenda. Es la forma de regular la dificultad.
2. **Forma relativa a los compañeros:** en un equipo de figuras la pelota se reparte y nadie llega a sus números reales. Si se midiera en absoluto, la forma sería negativa en forma sistemática.
3. **Química de efecto chico** (±1 punto de acierto): da ventaja, pero no decide partidos.
4. **`pesoDiferencia` 1/225:** se subió desde 1/250 para compensar los libres extra de las jugadas nuevas y mantener el balance.
5. **Banco largo automático** al iniciar la temporada: el usuario esperaba ver 8 jugadores sin tener que fichar.
6. **Draft de amigos simplificado** (4 cartas por turno) en vez de ruleta o sobres: el dominio del draft está atado a una sola temporada y no evita repetidos entre jugadores.
7. **Extremo en Difícil fijo:** en Leyenda, con lesiones dobles y sin fichas, no era jugable.
8. **"Los mejores equipos" al mejor de 3:** a partido único era demasiado azar, y al mejor de 7 diez veces se hacía demasiado largo.
9. **Mundial con rivales a la media de la dificultad** y no con su plantel all-time: con all-time ni el mejor plantel posible ganaba nunca.
10. **Dorsales eliminados:** solo 15 de 11.323 cartas los tenían.
11. **Wikipedia consultada desde el dispositivo:** desde la nube devuelve 429. Se usa la miniatura de 960 px.
12. **Recorte de fondo en el dispositivo** (ML Kit) para las fotos de archivo. Las fotos de entrenadores vienen ya recortadas como asset.

---

## 16. Limitaciones conocidas y deuda técnica

- **No probado en dispositivo real** por el autor del código: el diseño de tablet, la voz TTS, los sonidos, la hoja de compartir de Android y el recorte con ML Kit. Las pruebas son simulaciones y capturas renderizadas.
- **All-Star memorizado solo en memoria:** se arma la primera vez que se mira pasada la mitad de la temporada y no se guarda en la partida. Con la app recién abierta podría salir distinto.
- **Estado global estático:**
  - `Misiones.anotar` es una cola estática que consume el próximo `Progreso.aplicar`;
  - `SonidoPartido.habilitado` y `VozRelator.habilitado` son flags estáticos.
- **`MotorPartido.tecnicaDePrueba()`:** gancho público solo para tests (no se usó `@visibleForTesting` porque `meta` no es dependencia directa).
- **Determinismo del Desafío del día y del reto:** depende de la versión del catálogo. Con versiones distintas de la app, el mismo código o fecha podría dar otro draft.
- **Partidas viejas:** las anteriores al selector de dificultad se cargan como Leyenda. Las anteriores a la Tanda 6 no tienen código de reto.
- **Balance de los modos de escalera:** se midió con scripts que después se borraron; no tienen un test de balance permanente como la temporada. Valores medidos en Normal con un draft típico:
  - racha mediana de 7 a 9;
  - Camino llega en promedio al escalón 4;
  - Mundial se gana ~2 de cada 12;
  - escenarios, ~50 %.
- **Estadísticas estimadas en cartas viejas** (2.183 cartas, ver §4).
- **Fotos de Wikipedia** de calidad variable. La de Holzman (entrenador) es de baja resolución.
- **`pubspec.yaml`** dice `version: 0.1.0+1`. El número de build real lo pone la CI con `--build-number`.
- **Ramas de trabajo viejas en GitHub**, ya incluidas en `main`: `tanda-2`, `tanda-4a`, `tanda-4b`, `tanda-5`, `tanda-5-wip`, `tanda-6`, `tanda-6-wip`. Se pueden borrar.
- **Privacidad:** no hay analítica, cuentas ni servidores propios. La única red es la descarga de fotos y escudos desde el CDN de la NBA, Basketball-Reference y Wikipedia/Wikimedia, con caché local.

---

## 17. Historial de trabajo (resumen por tandas)

| Tanda | Contenido |
|---|---|
| Fases 1–5 | Catálogo histórico, fotos con 3 fuentes, escudos históricos, arquetipos, ruleta, temporada de 82, rivales, motor y partido en vivo 2D. |
| Mejoras de motor | La calidad pesa más, clutch, faltas, selector de dificultad, sonido sintetizado, estética de transmisión (aros, LED, zoom, marcador con 24 s, mapa de tiros, probabilidad de ganar), botón de simular la temporada entera. |
| Tanda 1 | Perfil, XP, monedas, logros, partidas múltiples, exportar/importar, ajustes, tutorial y tests de balance. |
| Tanda 2 | Draft y cartas: sobres, reglas de draft, serpiente, química, entrenadores, versiones, carta sorpresa, colección, álbum y tienda. |
| Tanda 3 | Partido en vivo: jugada clave, cambios, faltas y expulsiones, volcadas y alley-oops, relator y voz, repeticiones, pospartido. |
| Fotos de entrenadores | 18 fotos reales sin fondo. |
| Tanda 4a | Play-In, desempates oficiales, historial contra cada rival, desgaste del calendario, premios completos, récords en juego, titulares, carrera al MVP, All-Star. |
| Tanda 4b | Banco largo y lesiones, mercado de pases y Copa NBA. |
| Tanda 5 | Los 14 modos nuevos, misiones, pase, vestuario, revancha, historia de la dinastía. |
| Tanda 6 | Imagen para compartir, código de reto y tablet apaisada. |
| Ajustes posteriores | Revancha en playoffs, marcador de partidas con amigos, fotos de Wikipedia en 960 px, medidor de química, forma corregida, rotación de 8 automática, récord en vivo al simular, entrenadores reencuadrados, sin dorsales, All-Star robusto, todas las jugadas que faltaban con tasas de NBA, Difícil más duro (build 24). |

---

## 18. Guía rápida para auditar

1. **Compilar y testear:**

   ```bash
   flutter pub get && flutter analyze && flutter test
   ```

2. **Balance:** correr `flutter test test/balance_test.dart`. Imprime el porcentaje típico y el mejor por dificultad.
3. **Motor:** revisar `motor.dart` buscando `pesoDiferencia`, `_localia`, `_pFaltaSinTiro`, `clutch` y la función de probabilidad de tiro. `test/jugadas_test.dart` fija las bandas de tasas por partido.
4. **Persistencia y compatibilidad:** revisar `Temporada.fromJson`/`toJson` y `PerfilEntrenador.fromJson`. Todos los campos nuevos son opcionales al leer.
5. **Determinismo:** revisar `domain/reto.dart`, `Draft.azarPara`, `Liga.agentesLibres` (semilla por id y bloque) y `Liga.desgaste` (hash).
6. **Riesgos a mirar:**
   - el estado global estático (misiones, sonido);
   - el All-Star en memoria;
   - el tamaño de `partido_pantalla.dart` (~1.900 líneas) y `motor.dart` (~1.200 líneas), candidatos a dividir;
   - el balance de los modos de escalera sin test permanente.
