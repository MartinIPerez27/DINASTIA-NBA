# Verificación A2b — Área 2 (Balance y simulación), segunda mitad (líneas 1060–1442)

Copia de trabajo: `/tmp/claude-0/-home-user/b2ab324b-7311-5a2f-a1eb-f08ab7cbaa11/scratchpad/wt/A2b` (commit c453f39). Los tests temporales `test/zz_verif_*.dart` se borraron al terminar; `git status` queda limpio. Los `zzlog/*.txt` que cita el informe no existen en el repo, así que todo se midió de nuevo desde cero. Las salidas crudas están en `scratchpad/verif/` (car06_*.txt, car08.txt, car09.txt, cmp06.txt, cmp09.txt, cmp09b.txt, cmp10.txt, cmp11.txt, mda06.txt, mda10.txt, mda11.txt, mda12.txt, mda14.txt, meta09.txt).

## Tabla resumen

| ID | Veredicto | Sev. informe | Sev. mía | Evidencia en una línea |
|---|---|---|---|---|
| MOT-09 | CONFIRMADO | medio | medio | `motor.dart` no referencia `RolCancha`/`.rol`; defensa = `_media(defensa.enCancha…)` en motor.dart:1006; el rol solo entra en playbook.dart:22-49 |
| CAR-06 | CONFIRMADO | medio | medio-alto | Medido: mismo jugador y semilla, lote 1 y 6: confianza 52→100 y titular; lote 82: 52→58 y sexto hombre; phObjetivos 9 vs 6 |
| CAR-09 | CONFIRMADO | medio | medio | Medido: victorias T1..T10 idénticas al informe (13,12,21,25,24,23,23,28,21,25…); prestigio 100 desde T10/T7/T7; títulos 0/3/1 |
| MDA-06 | PARCIAL | medio | bajo-medio | Medias exactas (93,8/92,3; 97,5/94,3) y 1984 domina (92,5 %), pero no es "una sola elección ganadora": 2018 50 %, 1987 32 %, UCLA 57 %, UNC 55 % |
| MDA-10 | CONFIRMADO (con matiz) | medio | bajo-medio | Medido: Manos rápidas +6,9 y Segunda chance +5,6; Showtime +0,6, Banco profundo −1,4 (ruido); las 12 juntas +28 pp |
| MDA-11 | PARCIAL | medio | bajo-medio | Normal 20–37 %, Difícil 3–20 %, Leyenda 3–10 % (N=30); `static var` confirmado (epocas.dart:319, 550); "reclutar no importa" no se sostiene en mi medición |
| CMP-05 | CONFIRMADO | medio | medio | Sin tope: `competitivo.dart:1306` (200·mult XP + 80 monedas por campeón), `armado.dart:1179` (10 XP + 5 monedas por acierto); "REPETIR" en torneos.dart:657 |
| CMP-06 | CONFIRMADO | medio | medio | Medido: medias por precio 96,6/92,0/86,7/81,0/70,8; óptimo 433221 (45/120); user − IA = −0,02…−0,07; presupuesto igual para IA (armado.dart:386) |
| CMP-09 | CONFIRMADO | medio | bajo-medio | Medido: 0,105 % de aleatorios válidos, 0 transposiciones, 0 con 1 error, 7/2000 con 2 errores; rivales distintos 11 %; fichas 3+extra en `Reto.aceptar` |
| CMP-10 | CONFIRMADO (cifras de puntos distintas) | medio | medio-bajo | Precios por puntos exactos (7,7/11,4/17,5/28,2/36,1/48,0); óptimo campeón 1–8/30 Normal, 4–12/30 Leyenda; ventaja de puntos +2–7 %, no +12–15 % |
| META-09 | CONFIRMADO | medio | medio | Simulación con `Tienda` real: 28,7–31,8 mil sobres, 1,66–1,81 M monedas; 50 % a ~210 k, 90 % a ~550 k; catálogo 11.323 (70/138/2.704/8.411) |
| CAR-08 | CONFIRMADO | medio | medio | Medido: Robinson SAS 99 a los 22 (conf 82, titular), Yardley 93; los 12 primeros candidatos son 97–99; `Liga.iniciar` sin parámetro de época |
| MOT-10 | CONFIRMADO (mecanismo por código) | medio-bajo | medio-bajo | mercado.dart:65 `_valor = media + forma`, margen −1 para su peor carta, `evaluar` sin costo, `_contraoferta` ordena por valor ascendente |
| MOT-12 | CONFIRMADO | bajo-medio | bajo-medio | `balance_test.dart:~52` `temporadas = 3`; solo mide % de victorias; el test corre en 31 s (informe: ≈33 s) |
| MDA-12 | CONFIRMADO | bajo-medio | bajo-medio | Medido (N=200): finales98 21 %, finales16 26,5 %, finales93 9 %, finales84 69 %, finales13 91 % en Normal; Leyenda 4,5/8,5/2,5/47,5/71,5 % |
| MDA-14 | CONFIRMADO (con matiz) | bajo | bajo | Medido (N=300): jordan98 32,7/23,3, kawhi19 93/84, kyrie16 71/58,7, tmac04 1,7/1,7, fisher04 2,3/2,3 |
| MDA-15 | CONFIRMADO (a, b, d por código; c sigue siendo hipótesis) | bajo | bajo | variantes.dart:29-33 (84/86/90), `semilla(DateTime)` local, draft.dart:286 usa `t.id.hashCode` solo como respaldo |
| CMP-11 | CONFIRMADO | bajo | bajo | Medido (60 duelos): |dif| mediana 1,8, p90 4,3, máx 5,8; el de más media gana 44/60 (73 %); 10/60 con ≥4 pts |

En este tramo no hay hallazgos falsos. Los dos que menos aguantan literalmente son MDA-06 y MDA-11, ambos PARCIAL.

---

## Detalle por hallazgo

### MOT-09 — CONFIRMADO
- Evidencia: `grep rol` en `lib/domain/motor.dart` solo da la jugada "Pick & roll". `RolCancha` no aparece en motor.dart ni en liga.dart. El rol entra solo en `playbook.dart:22-49` (`_rolesTransicion`, `_rolesDefensivos`, para la afinidad). La defensa del tiro usa `_media(defensa.enCancha, (j) => defensa.media(j))` en `motor.dart:1006`. `EsquemaDefensivo.cajaYUno` es `estrella: 0.75` (`motor.dart:272`), sin defensor asignado.
- Opinión: severidad justa; es profundidad táctica, no un bug. La alternativa 2 (efectos pasivos por rol, ±1–2 pp) es la mejor primera medida: barata y sin romper el balance.

### CAR-06 — CONFIRMADO (la parte más reproducible del tramo)
- Código: `carrera_jugador.dart:1455` (en `lib/domain/modos/`) tiene `final paso = min(nuevos, 6) / 6.0;`. `dConfianza = clamp(-6,6) * paso + (moral-50)/50 * paso`. `TemporadaPantalla._guardar` llama a `ajustar` una vez por tanda (`lib/presentation/pantallas/temporada_pantalla.dart:96`).
- Medición (jugador creado, DAL, pick 20, Normal, semilla de liga 41, una temporada regular):

| Lote de guardado | Confianza fin de T1 | Rol | Moral | phObjetivos |
|---|---|---|---|---|
| 1 (partido a partido) | 52→100 | titular | 100 | 9 |
| 6 | 52→100 | titular | 100 | 9 |
| 82 ("simular todo") | 52→58 | sexto hombre | 68 | 6 |

  Coincide exactamente con el informe (52→100 y titular frente a 52→58 y sexto hombre). La misma partida da carreras distintas según el botón.
- No medí la saturación a lo largo de 80 temporadas. Pero la fórmula `e.confianza + dConfianza` con clamp ±6 por paso lleva a 100, y T1 ya lo muestra.
- Opinión: sube a medio-alto. Es un bug de diseño, no solo de balance: el resultado depende de la interfaz. La alternativa 1 (normalizar por partido) es correcta. Hay que hacerlo antes de calibrar objetivos.

### CAR-09 — CONFIRMADO
- Medí 10 temporadas × semillas 7/8/9 con firma greedy de los mejores reclutas que alcanzan los puntos y que caben en el plantel (máx 13).
- Victorias idénticas a las del informe: semilla 7: 13,12,21,25,24,23,23,28,21,25; semilla 8: 14,17,24,27,27,22,25,28,28,29; semilla 9: 16,21,23,29,26,24,25,27,29,26.
- Prestigio: 100 en T10 (semilla 7) y desde T7 (semillas 8 y 9). Títulos 0/3/1.
- Fuerza propia 66,7→78–79; la mejor IA queda en ~76–79 (ej. semilla 7: 75,8 vs 77,2 en T10). Coincide con el informe.
- Opinión: severidad justa; es de meta, no de bug. Fuga de talento y metas por temporada (alternativas 2 y 3) son una buena combinación.

### MDA-06 — PARCIAL
- Las medias coinciden exactamente (93,8/92,3 en camadas; 97,5/94,3 en universidades). La dominancia de 1984 y de "Directo a la NBA" se confirma. El resto de la afirmación ("los demás son decorativos") no se sostiene.
- Medición (N=40 por equipo, Normal, semillas de liga distintas):

| Equipo (Normal) | Campeón |
|---|---|
| Camada 1984 | 92,5 % (informe 86 %) |
| Camada 2018 | 50 % |
| Camada 1987 | 32,5 % |
| Camada 2011 | 27,5 % |
| Camada 1996 | 15 % |
| Camada 1985 / 2009 / 2003 | 7,5 % / 2,5 % / 0 % |
| Directo a la NBA | 65 % (informe 74 %) |
| UCLA | 57,5 % |
| North Carolina | 55 % |
| Kentucky | 32,5 % |
| Duke, Ohio State, Indiana, Texas… | 0–7,5 % |

  En Leyenda: 1984 70 % (informe 61 %); Directo 32,5 %, UNC 25 %, UCLA 12,5 %.
- Conclusión: hay una elección claramente superior en cada modo, pero también 3–4 elecciones viables (2018, 1987, 2011 en camadas; UCLA, UNC, Kentucky en universidades). Que el equipo de mayor media gane más es esperable (el diseño es "equipos reales") y no es un bug. Mi N=40 tiene ±8 pp de error, así que las cifras de las alternativas son orientativas.
- Opinión: baja a bajo-medio. La corrección 2 (multiplicador de premio por desventaja) es razonable. Quitar "Directo a la NBA" como elegible es discutible: es la propuesta de mayor impacto sobre la identidad del modo y tiene poco respaldo en los datos.

### MDA-10 — CONFIRMADO, con matiz
- Reproducción con un diseño propio: 20 planteles de draft "mejor de 4 al azar" (media 80,8) contra un rival de 86,8 (el informe usa rival de 79,2 y base de 39,8 %). Mi base fue 27,5 %. El nivel absoluto difiere, pero el orden y las magnitudes coinciden. 800 partidos por insignia (error estándar ≈ ±1,6 pp).

| Insignia | pp |
|---|---|
| Manos rápidas | +6,9 |
| Segunda chance | +5,6 |
| Química | +2,6 |
| Sangre fría | +2,0 |
| Mamba | +1,6 |
| Pizarrón | +0,8 |
| Showtime | +0,6 |
| Zona prohibida | +0,6 |
| Splash | +0,1 |
| Bad Boys | −0,9 |
| Banco profundo | −1,4 |
| Refuerzo | 0,0 |
| Las 12 juntas | +28,1 |

- Código: `escalera.dart:142-260` define los efectos y `InsigniaCamino.suma` los acumula con `ModificadoresEquipo.mas`, sin tope.
- Matiz: "trampas" (efecto negativo) es exagerado. Showtime y Banco profundo valen ≈ 0 dentro del ruido, no son perjudiciales. En mi muestra Splash también queda en ≈ 0, y en el informe vale +1,2 (también dentro del ruido). La conclusión de fondo ("dos son inútiles, dos sobresalen, no hay tope") se mantiene.
- Opinión: severidad justa a media-baja. Retocar números y agregar un test de bandas (alternativa 1) es lo correcto.

### MDA-11 — PARCIAL
- Código: `epocas.dart:317` (`objetivoEtapa = mediaPropia + objetivosGuantelete[etapa]`), `:319` y `:550` son `static var` mutables (confirmado). `_ajuste` (epocas.dart:538) resta `porDecada` por década de distancia y se achica al modernizar el equipo.
- Medición (N=30 por celda, error estándar de las tasas de completación ≈ ±8 pp; mi política de reclutamiento: la carta de mayor media en el puesto de mayor ganancia):

| | azar+recluta | azar+ninguno | mejor+recluta | mejor+ninguno |
|---|---|---|---|---|
| Normal | 3,77 / 36,7 % | 3,10 / 20,0 % | 3,20 / 30,0 % | 3,00 / 23,3 % |
| Difícil | 2,80 / 20,0 % | 1,77 / 3,3 % | 2,63 / 20,0 % | 2,07 / 6,7 % |
| Leyenda | 1,70 / 6,7 % | 1,53 / 3,3 % | 1,87 / 10,0 % | 1,17 / 3,3 % |

- Sí se confirma: Normal ≈ 30 %, y Difícil/Leyenda quedan por debajo de lo documentado (31/19/6 %).
- No se confirma: "reclutar casi no importa / con draft al azar no reclutar rinde igual o mejor". En mi muestra reclutar suma décadas en todos los casos (por ejemplo Difícil azar 2,80 vs 1,77). El informe midió lo contrario (3,51 vs 3,81 en Normal). Con N=30–80 hay mucho ruido, y mi política de reclutamiento es distinta de la del informe. Lo prudente es decir que el efecto del reclutamiento no está demostrado en ninguno de los dos sentidos.
- Opinión: severidad bajo-media. La propuesta de excluir al recluta del cálculo de `objetivoEtapa` es válida de todas formas (es un mecanismo que se auto-cancela). Hay que volver `const` los parámetros.

### CMP-05 — CONFIRMADO
- Todos los premios están en código y ninguno tiene tope diario:
  - Creador de torneos: campeón `xpMonedas((200 * mult).round(), 80, …)` en `domain/modos/competitivo.dart:~1306`, más XP/monedas por partido. "REPETIR EL TORNEO" en `presentation/modos/torneos.dart:657` crea otro torneo igual.
  - Divisiones: campeón de la élite 300·mult XP + 120 monedas; ascenso 150·mult + 60 (`competitivo.dart:1271-1277`).
  - Adiviná la carta: `conSesionAdivina` (`armado.dart:1179`) da `aciertos*10` XP y `aciertos*5` monedas, más 100 XP y 50 monedas la primera vez con 10/10. Sin límite de sesiones.
  - Fantasy: 25 XP y 8 monedas por semana ganada, más 400/200 por campeón (`fantasy.dart` `premiarFantasy`).
  - Tope salarial: XP ×1,25/1,5 por dificultad (`armado.dart:~801`).
  - Sobre común 150 monedas, leyenda 1.200 (`tienda.dart:9-11`).
- No reproduje el "22/30 campeón con mi álbum 95,5" ni el 200 XP + 76 monedas medios (depende del álbum de cada uno). La mecánica y el orden de magnitud sí coinciden por código.
- Opinión: severidad justa. Los premios proporcionales a la dificultad y un tope diario (alternativa 1) son lo adecuado. Ojo: la opción 3 ("no tocar") no es razonable si se quiere preservar CMP-01 y CMP-04.

### CMP-06 — CONFIRMADO
- Código: `armado.dart:~135` `presupuestoTope` 15/14/13. `nuevoTope` (`armado.dart:369-386`) arma la IA con el mismo `presupuesto` (`mejorPlantelTope(suyo, presupuesto)`). `premiarArmado` multiplica la XP por 1,0/1,25/1,5 (`armado.dart:793-805`).
- Medición (120 tableros por dificultad):

| Precio | Media |
|---|---|
| $5 | 96,6 |
| $4 | 92,0 |
| $3 | 86,7 |
| $2 | 81,0 |
| $1 | 70,8 |

  El salto $1→$2 es +10,2 y los demás ~5; coincide con el informe.
- Composición óptima: Normal 433221 (45/120; informe 52/120), Difícil 432221 (37/120), Leyenda 332221 (48/120). Coincide.
- Diferencia media usuario−IA: −0,02 (Normal), −0,07 (Difícil), −0,05 (Leyenda); informe +0,03. Equivalente a empate. Usuario 1.º por media estricta en 12/120, 7/120 y 11/120 (informe: "1.º por suma en 14 de 120").
- No corrí la liga completa (30 corridas por estrategia). Es lo único del hallazgo sin medir.
- Opinión: severidad justa. La propuesta de brecha de presupuesto y la IA con estilos son buenas. XP gratis en Leyenda es el punto más concreto.

### CMP-09 — CONFIRMADO
- CRC: 300.000 códigos aleatorios de 12 caracteres → 316 válidos (0,105 %; informe 0,094 %). Transposiciones de vecinos: 0/4.252. Un error de un carácter: 0/37.200. Dos errores: 7/2.000 (0,35 %; informe 0,25 %). Coincide.
- Versión de 8 bits: `reto.dart:~66` `version & 0xff`; `avisoCatalogo` solo avisa (`presentation/modos/reto.dart:~120`), el reto se juega igual.
- Rivales: dos ligas con la misma semilla, plantel propio distinto en 1 de 5 cartas (10 códigos, 29 rivales por código): 258/290 rivales idénticos, es decir 11 % distintos (informe 13 %). Cartas en común 33/50. La causa es la que dice el informe: `Liga.iniciar` excluye tus jugadores y todos comparten un `_azar` (`liga.dart:37-52, 93-95`).
- Fichas: `Reto.aceptar` da `Temporada.rerollsPorTemporada + fichasExtra` (`domain/reto.dart`, `aceptar`), y `iniciarReto` pasa `perfilApp.value.fichasExtra` (`presentation/modos/reto.dart:18`).
- Opinión: severidad bajo-media. La alternativa 2 (fichas fijas en retos) es la mejor y es una línea. El anti-trampa solo importa si hay ranking.

### CMP-10 — CONFIRMADO, con cifras de puntos distintas
- Código: `fantasy.dart:53` `precio = max(1, round((media−62)/2,8))` (exacto).
- Puntos por precio (2016), idénticos al informe: P1 7,7 · P3 11,4 · P5 17,5 · P8 28,2 · P10 36,1 · P13 48,0.
- Equipo óptimo: búsqueda exacta, con los 2 mejores por precio y puesto, sin duplicar personas, capitán = mejor promedio, sin tocar nada, 7 rivales IA, 30 temporadas por fila. Puntos semanales del usuario vs IA:

| Año | Normal: pts | Normal: campeón | Leyenda: pts | Leyenda: campeón |
|---|---|---|---|---|
| 1986 | 910 vs 872 | 8/30 | 803 vs 780 | 6/30 |
| 1997 | 901 vs 871 | 5/30 | 820 vs 780 | 5/30 |
| 2008 | 888 vs 837 | 8/30 | 809 vs 746 | 12/30 |
| 2016 | 894 vs 845 | 8/30 | 793 vs 756 | 8/30 |
| 2024 | 935 vs 914 | 1/30 | 841 vs 824 | 4/30 |

- Cifras sin grano fino: el óptimo gana entre 3 % y 40 % de los títulos, con una media de ~20 % frente al 12,5 % de azar, y aun ganando por +2–7 % de puntos. El informe habla de +12–15 % de puntos esperados y 10–33 %. La diferencia está en cómo se mide (mis puntos son los acumulados de la temporada regular, no el "esperado" por partido). La conclusión ("el mejor equipo posible gana poco más que al azar") se mantiene.
- No encontré exploit de capitán. No verifiqué la afirmación de que Huertas e Ish Smith son los mejores pts/$.
- Opinión: severidad justa a media-baja. Bajar la varianza y playoffs de 2 semanas (alternativa 1) es lo directo.

### META-09 — CONFIRMADO
- Código: `perfil.dart:245` `xpParaNivel = 75·n·(n−1)`. `misiones.dart:178` `niveles = 20, puntosPorNivel = 200` (4.000 puntos de pase). `tienda.dart:36` `monedasPorRepetida = 20`. Los sobres tienen peso por tier (comun B10/A6/S3/S+1).
- Medición con el `Tienda.abrir` real y sobres comunes, hasta completar el álbum de 11.323 cartas:
  - Catálogo: 11.323 cartas (B 8.411, A 2.704, S 138, S+ 70). Coincide exactamente.
  - Corridas 1–3: 29.835 / 28.696 / 31.761 sobres; 1,72 / 1,66 / 1,81 M monedas netas (informe: 28–38 mil sobres y 1,6–2,1 M).
  - Hitos: 50 % con ~209–211 k monedas (informe 207 k); 90 % con ~550–553 k (informe 541 k).
- No reproduje el ingreso por temporada clásica ni el ritmo de misiones (dependen de simular temporadas completas con logros ya ganados); quedan como no medidos en esta pasada.
- Opinión: severidad justa. Álbum por páginas y sobres dirigidos (alternativa 1) es correcta; la alternativa 2 (reducir a A/S/S+) es la más barata.

### CAR-08 — CONFIRMADO
- Código: `candidatosReales` (`carrera_jugador.dart:1103`) toma, por persona, la carta de menor `temporadas.$1`. `estadoReal` (`:1190`) usa `carta.media` como base. `Liga.iniciar` (`liga.dart:37`) no recibe época.
- Medición: David Robinson SAS (1990-99, draft 1987 #1) arranca con media 99 a los 22 años, confianza 82, titular. George Yardley DET (50s) arranca con 93. Los 12 primeros candidatos de la lista (ordenada por media) son todos 97–99 a los 19–23 años; hay 7 jugadores con media inicial 98 o más.
- Opinión: severidad justa. Estimar la media de novato por edad (alternativa 1) más reusar `rivalesDeEpoca` es lo correcto.

### MOT-10 — CONFIRMADO por código (no medido)
- `mercado.dart:65` `_valor = media + forma`; `forma` va de −3 a +3 (`liga.dart:~482` `clamp(-3, 3)`; el motor también usa la forma, `motor.dart:313`). `margen` (`mercado.dart:~79-85`): −1 si es su carta más floja y no es S+. `evaluar` no gasta nada ni tiene azar. `_contraoferta` ordena por valor ascendente y devuelve la de menor valor que acepta.
- Matiz: "+4 de media permanentes por pase" solo ocurre contra el rival cuya peor carta sea alta (84): ahí margen −1 y forma +3 compran una carta de 84 con una de 80. Contra cartas de tier B, la ganancia permanente es +1 (la forma decae). Lo grave es la combinación (consulta ilimitada + contraoferta mínima) más que el +4.
- Opinión: medio-bajo es justo. Sacar la forma del valor (alternativa 1) es una línea y es la mejor.

### MOT-12 — CONFIRMADO
- `balance_test.dart`: `medir(…, {int temporadas = 3})`, el "típico" son 3 planteles al azar (`tipico(Random(500+k))`), `tacticaConfirmada: true` sin táctica explícita (usa la por defecto) y sin entrenador. Las bandas solo miran % de victorias y puntos por equipo.
- Corrí el test: 31 s en esta máquina (informe: ≈33 s).
- Opinión: justo. Etiquetarlo `@Tags(['balance'])` con más semillas (alternativa 2) es lo sensato.

### MDA-12 — CONFIRMADO
- N=200 por escenario (informe N=400). Normal: finales98 21,0 % · finales16 26,5 % · finales93 9,0 % · finales84 69,0 % · finales13 91,0 % · oeste02 59,0 % · finales06 74,0 % · finales94 50,5 %. Informe: 17,5/21,3/10,8/73,8/86,3/58,0/73,3/55,8. Todos dentro de ±5 pp (error de mi muestra ±3 pp).
- Leyenda: 4,5/8,5/2,5/47,5/71,5/37,5/59,0/33,5 % frente a 5,8/3,8/3,8/54,5/69,3/37/55,3/34,5 % del informe.
- No verifiqué los datos históricos de marcador/localía (el propio informe aclara que no los comprobó).
- Opinión: severidad justa. Mostrar estrellas de dificultad (2) es lo más barato y aporta; el ajuste por escenario (1) toca el balance de cada uno.

### MDA-14 — CONFIRMADO, con matiz
- N=300 por celda. Con impulso / sin impulso (%): jordan98 32,7/23,3 · allen13 8,0/5,7 · tmac04 1,7/1,7 · kawhi19 93,0/84,0 · kyrie16 71,0/58,7 · reggie95 5,3/1,7 · magic87 51,0/47,3 · shot89 69,7/62,7 · dame19 71,0/64,7 · bird87 25,7/23,0 · fisher04 2,3/2,3. Coincide con el informe dentro del error de muestra.
- Los 4 "casi imposibles": allen13, tmac04, reggie95, fisher04, con 1,7–8 %. `momentosClutch` tiene 11 momentos (`historia.dart:243`). `impulsoHistorico` está definido en `historia.dart:~610`. Fisher no cambia con impulso (confirmado).
- Matiz: "el impulso casi no mueve la aguja" solo es cierto en los imposibles. En Jordan (+9), Kawhi (+9) y Kyrie (+12) sí mueve. Lo que falta es que el impulso no ayuda donde más hace falta.
- Opinión: bajo es justo. Objetivos escalonados (alternativa 1) es lo mejor.

### MDA-15 — CONFIRMADO (a, b, d por código; c sigue siendo [HIPÓTESIS])
- (a) `presentation/modos/variantes.dart:170-189`: solo se consulta `enCurso` al crear (confirmado en el código; no probé la importación en vivo).
- (b) `variantes.dart:29-33` (en `lib/domain/`): `objetivo` 84/86/90 (exacto).
- (c) `draft.dart:286`: `Random(t.datosModo['semilla'] as int? ?? t.id.hashCode)`. Importante: el `hashCode` solo se usa si no hay `semilla`; con semilla (retos, desafío del día) no interviene. Existe `_semilla` con FNV-1a en `epocas.dart:323`. Es una hipótesis razonable pero sin impacto probado.
- (d) `Variantes.semilla(DateTime d)` = `y*10000+m*100+d` y `presentation/modos/variantes.dart:383` usa `DateTime.now()` local.
- Opinión: bajo es justo; los arreglos puntuales (alternativa 1) son baratos.

### CMP-11 — CONFIRMADO
- Código: `amigos.dart` `_sortear` sortea cartas para quien elige con pesos S+ 1 / S 3 / A 6 / B 4 (`_pesos`, `amigos.dart:294`), 4 por turno.
- Medición (60 duelos, cada uno elige siempre la mejor de sus 4): |diferencia de media| mediana 1,8 (informe 1,5), p90 4,3 (4,3), máximo 5,8 (8,8). El de más media gana la serie 44/60 = 73 % (informe 30/39 = 77 %). Duelos con ≥4 pts de diferencia: 10/60 (≈1 de cada 6; el informe dice 1 de cada 10).
- Opinión: bajo es justo. Mismas 4 cartas por ronda (alternativa 2) es lo más simple.
