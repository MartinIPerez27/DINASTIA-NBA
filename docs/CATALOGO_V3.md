# Catálogo v3: una carta = un tramo real

Regla del dueño: cada carta refleja el rendimiento REAL en la época y el equipo que juega (el Porziņģis de Dallas, de
Washington, de Boston, de Atlanta y de Golden State no son lo mismo; el Curry de 2010 no es el de hoy).
Pipeline: `tools/catalogo_bbref.py` (datos de Basketball-Reference, hasta la última temporada TERMINADA: 2025-26).

## 1. Qué es un tramo

Tramo = jugador + franquicia + **ventana de temporadas** (campo `temporadas`: [primer año de cierre, último]).

1. Las temporadas del jugador con una franquicia se agrupan en **rachas consecutivas** (un año sin jugar ahí corta la racha).
2. Cada racha se parte en los **límites de década** (la `epoca` de la carta sigue siendo una sola: "Una sola década", la
   ruleta de épocas y los sobres no cambian).
3. Cada tramo se parte en ventanas de **1 a 4 temporadas** por programación dinámica (`partir`): una ventana nueva cuesta
   `PENALIZACION_VENTANA = 6`, más la dispersión (ponderada por partidos) del *nivel* de sus temporadas, más un sesgo
   pequeño hacia 3 temporadas. Resultado: se corta donde el rendimiento cambia más de ~2 puntos de nivel y, si es parejo,
   cada 3–4 temporadas. El nivel de cada temporada es el de `puntaje_v3` **menos 0,5 por año pasados los 33** (solo para
   cortar: el declive del veterano separa su última ventana; la media usa el rendimiento real, sin ese descuento).
4. Mínimos: una ventana necesita **20 partidos** (`MIN_PARTIDOS`); las más chicas se fusionan con la vecina. Una parada de
   traspaso a mitad de temporada (toda la ventana en una temporada con otro equipo, 250+ minutos) entra desde **12
   partidos** y casi siempre queda en Tier B (Porziņģis en ATL y GSW 2026). Si en una década ninguna ventana llega a 20 pero
   el conjunto sí (existía la carta v2), se unen en una carta con huecos (`temporadas_huecos.json`; hoy 8 cartas).
5. Cada ventana calcula **sus** 11 estadísticas, posiciones, rol, IQ, media y Tier. Se exporta también `edad` (años en la
   primera temporada de la ventana, de Basketball-Reference) y `nacimiento`.

Resultado: 13.026 cartas activas (antes 11.323) de 4.070 jugadores. Tiers v2 → v3: S+ 70 → 81, S 138 → 187,
A 2.704 → 3.097, B 8.411 → 9.656. Ventanas de 1 temporada: 5.885; de 2: 3.698; de 3: 2.326; de 4: 1.107; 5 cartas con
huecos (5–8 temporadas). Cartas v2 que ahora tienen más de una ventana en su década: 1.295 de 11.318.

## 2. Ids y compatibilidad

* **Todos los ids v2 siguen existiendo** (tests: `test/catalogo_v3_test.dart` y `tools/test_catalogo_bbref.py`, con
  `test/fixtures/catalogo_v2_ids.json`).
* Opción elegida: **cada carta v2 por década se convierte en una de sus ventanas conservando el id** (la de más partidos;
  mapa congelado en `tools/ids_heredados.json`, 11.318 ids). Las demás ventanas nacen con id
  `pid-FRANQ-<año de inicio>` (p. ej. `curryst01-GSW-2015`), la convención para siempre. Se descartó dejar 11.323 cartas
  "legado" duplicadas: inflaban el JSON, el álbum (cartas por completar que no existen en los sorteos) y los pools, y
  dejaban dos "Curry de los 2010" distintos. Costo: una partida vieja que guardó `curryst01-GSW-10` ahora encuentra la
  ventana 2017–19 en vez de toda la década (igual que ya cambiaban las medias con cada catálogo).
* **`legado: true`** (5 cartas, `tools/cartas_legado.json`): cartas v2 que no se pueden recalcular sin datos de la
  temporada en curso (las creó 2026-27). Se conservan tal cual, **no salen en sorteos** (`parsearCatalogo` las excluye) y
  se encuentran por id (`cartasLegado`, usado por `Liga` y `Draft`).
* `cartaOReemplazo` ahora también reemplaza una carta cuyo id existe pero que **ya no puede jugar ese puesto** (la
  ventana heredada tiene otras posiciones): sin esto, un rival guardado explotaba al cargar.
* Las partidas guardadas embeben la carta completa del plantel del usuario: cargan con las cartas que tenían.
* Futuras regeneraciones: las ventanas con id publicado mantienen su año de inicio; el generador aborta si un id heredado
  deja de existir. Las 327 cartas de franquicias extintas no cambian de uso.

## 3. Media v3 (por ventana)

`puntaje_v3(ventana)`, con c = PJ / (PJ + 50):

```
impacto  = c · impacto_norm + (1 − c) · (−2)              # BPM (Win Shares + PER antes de 1974), regresado a reemplazo
minutos  = mpg − 24
volumen  = 0,22 · min(minutos, 0) + k · max(minutos, 0)  # k = 0,22 con impacto ≥ 0; 0,11 si no (volumen sin impacto = mitad)
puntaje  = impacto + c · (volumen + 0,45 · min(premios por temporada, 12))
```

* `impacto_norm`: BPM por minuto de cada temporada-equipo, llevado a la escala de las épocas modernas (z-score por época;
  en v2 se hacía por carta) y promediado por minutos en la ventana.
* Premios por temporada, atribuidos al equipo con el que más jugó ese año: MVP 10, MVP de Finales 8, All-NBA 5/3/2,
  DPOY 3, 6.º Hombre 2, All-Star 1, 1.er equipo defensivo 1. **Temporada 2025-26 completa**: los premios que el dataset
  no trae (MVP Gilgeous-Alexander, DPOY Wembanyama, 6.º Hombre K. Johnson, Finales Brunson, tres All-NBA; fuente:
  Wikipedia) están en `PREMIOS_2026`. Sin All-Defense 2026 (sin fuente).
* **Escala**: dentro de cada época las ventanas se ordenan por `puntaje_v3` y se reparten con la misma distribución de
  medias de v1/v2 (estirada). El promedio por época no cambia (74,4 en las modernas).
* Anti-inflado: (a) minutos y premios de muestras chicas pesan como el impacto (c); (b) el volumen sin impacto vale la
  mitad; (c) las ventanas se parten donde cambia el rendimiento y por edad, así el declive del veterano no queda diluido
  en una media de década. Chequeo: de 393 jugadores con 3+ ventanas y 34+ años en la última, 391 tienen la última por
  debajo de su pico; el rango medio entre ventanas de un mismo jugador es de 10 puntos.

Tier v3: S+ = media ≥ 95 y (premios/temporada ≥ 4 o ≥ 25 puntos); S = media ≥ 91 o (≥ 88 y premios/temporada ≥ 4);
A = media ≥ 79 o con premios; B el resto.

## 4. Datos corregidos

* DAT-03: posición = la declarada; si falta, la mayoritaria del mismo jugador en otras temporadas; si no, la de carrera de
  `Player Career Info.csv` afinada con altura (relativa a la media de la temporada) o peso. Los rebotes estimados
  (1947-50) usan esa posición y un ajuste por altura. Años 40: ninguna posición supera el 25 % (antes 88 % escoltas).
* DAT-04/05: `ULTIMA_TEMPORADA = 2026` (en `catalogo_bbref.py` y `temporadas_jugadas.py`); `campeonesReales[2026] = 'NYK'`.
* DAT-06: `fotos` por defecto `["b","w"]` si el ID oficial es negativo; salida determinística (dos corridas idénticas).
* DAT-12: `dorsal` 0 en todas (se omite del JSON; los ajustes manuales ya no traen dorsales).
* CAR-07/DAT-15: `edad` y `nacimiento` exportados (no se cableó `dinastia.dart`: es de otro frente).
* DAT-14: README actualizado. DAT-10: las franquicias extintas quedan como estaban.

## 5. Casos testigo (temporadas por año de cierre; media y estadísticas de la ventana)

**Stephen Curry**

| Equipo | Temporadas (cierre) | Media | Tier | PPP | RPP | APP | MIN | IQ |
|---|---|---|---|---|---|---|---|---|
| GSW | 2010–2012 | 85 | a | 17.5 | 4.1 | 5.8 | 34.0 | 91 |
| GSW | 2013–2014 | 91 | s | 23.5 | 4.2 | 7.7 | 37.4 | 92 |
| GSW | 2015–2016 | 98 | sPlus | 26.9 | 4.8 | 7.2 | 33.4 | 96 |
| GSW | 2017–2019 | 92 | s | 26.3 | 4.9 | 6.0 | 33.2 | 94 |
| GSW | 2020–2023 | 94 | s | 28.7 | 5.6 | 6.1 | 34.3 | 90 |
| GSW | 2024–2026 | 91 | s | 25.8 | 4.2 | 5.4 | 32.1 | 90 |

**LeBron James**

| Equipo | Temporadas (cierre) | Media | Tier | PPP | RPP | APP | MIN | IQ |
|---|---|---|---|---|---|---|---|---|
| CLE | 2004 | 84 | a | 20.9 | 5.5 | 5.9 | 39.5 | 83 |
| CLE | 2005–2008 | 98 | sPlus | 29.0 | 7.2 | 6.8 | 41.6 | 93 |
| CLE | 2009 | 97 | sPlus | 28.4 | 7.6 | 7.2 | 37.7 | 96 |
| CLE | 2010 | 97 | sPlus | 29.7 | 7.3 | 8.6 | 39.0 | 96 |
| MIA | 2011–2014 | 98 | sPlus | 26.9 | 7.6 | 6.7 | 38.0 | 94 |
| CLE | 2015–2018 | 97 | sPlus | 26.1 | 7.7 | 8.0 | 36.6 | 93 |
| LAL | 2019 | 89 | a | 27.4 | 8.5 | 8.3 | 35.2 | 93 |
| LAL | 2020 | 93 | s | 25.3 | 7.8 | 10.2 | 34.6 | 89 |
| LAL | 2021–2024 | 93 | s | 27.5 | 7.8 | 7.3 | 35.4 | 91 |
| LAL | 2025–2026 | 90 | a | 22.8 | 7.0 | 7.7 | 34.1 | 91 |

**Kristaps Porziņģis**

| Equipo | Temporadas (cierre) | Media | Tier | PPP | RPP | APP | MIN | IQ |
|---|---|---|---|---|---|---|---|---|
| NYK | 2016–2018 | 83 | a | 17.8 | 7.1 | 1.3 | 31.0 | 81 |
| DAL | 2020–2022 | 85 | a | 20.0 | 8.8 | 1.8 | 30.9 | 84 |
| WAS | 2022–2023 | 87 | a | 22.9 | 8.5 | 2.7 | 31.7 | 90 |
| BOS | 2024–2025 | 87 | a | 19.8 | 7.0 | 2.0 | 29.3 | 91 |
| ATL | 2026 | 80 | a | 17.1 | 5.1 | 2.7 | 24.3 | 93 |
| GSW | 2026 | 77 | b | 16.1 | 5.3 | 2.3 | 23.7 | 85 |

**Damian Lillard**

| Equipo | Temporadas (cierre) | Media | Tier | PPP | RPP | APP | MIN | IQ |
|---|---|---|---|---|---|---|---|---|
| POR | 2013 | 81 | a | 19.0 | 3.1 | 6.5 | 38.6 | 86 |
| POR | 2014–2017 | 90 | a | 23.3 | 4.3 | 6.1 | 35.8 | 89 |
| POR | 2018–2019 | 92 | s | 26.3 | 4.5 | 6.7 | 36.0 | 92 |
| POR | 2020–2023 | 93 | s | 29.4 | 4.4 | 7.6 | 36.5 | 91 |
| MIL | 2024–2025 | 88 | a | 24.6 | 4.5 | 7.0 | 35.7 | 90 |

**Jrue Holiday**

| Equipo | Temporadas (cierre) | Media | Tier | PPP | RPP | APP | MIN | IQ |
|---|---|---|---|---|---|---|---|---|
| PHI | 2010–2013 | 82 | a | 13.4 | 3.6 | 5.8 | 32.9 | 84 |
| NOP | 2014–2017 | 84 | a | 15.5 | 3.6 | 6.9 | 31.4 | 88 |
| NOP | 2018–2019 | 86 | a | 20.0 | 4.7 | 6.8 | 36.0 | 92 |
| NOP | 2020 | 83 | a | 19.1 | 4.8 | 6.7 | 34.7 | 86 |
| MIL | 2021–2023 | 88 | a | 18.5 | 4.7 | 6.8 | 32.6 | 92 |
| BOS | 2024–2025 | 84 | a | 11.8 | 4.9 | 4.4 | 31.7 | 90 |
| POR | 2026 | 82 | a | 16.3 | 4.6 | 6.1 | 29.4 | 86 |

**Andre Drummond**

| Equipo | Temporadas (cierre) | Media | Tier | PPP | RPP | APP | MIN | IQ |
|---|---|---|---|---|---|---|---|---|
| DET | 2013–2015 | 83 | a | 12.1 | 11.8 | 0.5 | 28.5 | 81 |
| DET | 2016–2019 | 86 | a | 15.5 | 15.0 | 1.6 | 32.4 | 81 |
| DET | 2020 | 82 | a | 17.8 | 15.8 | 2.8 | 33.8 | 79 |
| CLE | 2020–2021 | 78 | b | 17.5 | 12.9 | 2.4 | 28.7 | 76 |
| LAL | 2021 | 75 | b | 11.9 | 10.2 | 1.4 | 24.8 | 79 |
| BKN | 2022 | 78 | b | 11.8 | 10.3 | 1.4 | 22.3 | 87 |
| PHI | 2022 | 79 | a | 6.1 | 8.8 | 2.0 | 18.4 | 82 |
| CHI | 2023–2024 | 74 | b | 7.3 | 7.9 | 0.5 | 15.1 | 81 |
| PHI | 2025–2026 | 74 | b | 6.8 | 8.2 | 1.1 | 19.2 | 79 |

**Russell Westbrook**

| Equipo | Temporadas (cierre) | Media | Tier | PPP | RPP | APP | MIN | IQ |
|---|---|---|---|---|---|---|---|---|
| OKC | 2009 | 77 | b | 15.3 | 4.9 | 5.3 | 32.5 | 81 |
| OKC | 2010 | 82 | a | 16.1 | 4.9 | 8.0 | 34.3 | 83 |
| OKC | 2011–2014 | 90 | a | 22.7 | 5.0 | 7.1 | 34.2 | 88 |
| OKC | 2015–2016 | 93 | s | 25.6 | 7.6 | 9.6 | 34.4 | 90 |
| OKC | 2017 | 96 | sPlus | 31.6 | 10.7 | 10.4 | 34.6 | 90 |
| OKC | 2018–2019 | 91 | s | 24.2 | 10.5 | 10.5 | 36.2 | 87 |
| HOU | 2020 | 84 | a | 27.2 | 7.9 | 7.0 | 35.9 | 82 |
| WAS | 2021 | 86 | a | 22.2 | 11.5 | 11.7 | 36.4 | 82 |
| LAL | 2022–2023 | 79 | a | 17.4 | 6.9 | 7.2 | 32.1 | 79 |
| LAC | 2023–2024 | 80 | a | 12.2 | 5.0 | 5.2 | 24.3 | 84 |
| DEN | 2025 | 78 | b | 13.3 | 4.9 | 6.1 | 27.9 | 84 |
| SAC | 2026 | 79 | a | 15.2 | 5.4 | 6.7 | 29.0 | 82 |

**Kevin Durant**

| Equipo | Temporadas (cierre) | Media | Tier | PPP | RPP | APP | MIN | IQ |
|---|---|---|---|---|---|---|---|---|
| SEA | 2008–2009 | 84 | a | 22.7 | 5.4 | 2.6 | 36.7 | 83 |
| OKC | 2010–2012 | 95 | sPlus | 28.7 | 7.4 | 3.0 | 39.0 | 87 |
| OKC | 2013–2014 | 97 | sPlus | 30.1 | 7.6 | 5.1 | 38.5 | 91 |
| OKC | 2015–2016 | 92 | s | 27.4 | 7.7 | 4.8 | 35.3 | 91 |
| GSW | 2017–2019 | 96 | sPlus | 25.8 | 7.1 | 5.4 | 34.1 | 95 |
| BKN | 2021–2023 | 92 | s | 29.0 | 7.1 | 5.8 | 35.7 | 92 |
| PHX | 2023–2025 | 90 | a | 26.8 | 6.3 | 4.6 | 36.7 | 90 |
| HOU | 2026 | 89 | s | 26.0 | 5.5 | 4.8 | 36.4 | 89 |

**Nikola Jokić**

| Equipo | Temporadas (cierre) | Media | Tier | PPP | RPP | APP | MIN | IQ |
|---|---|---|---|---|---|---|---|---|
| DEN | 2016–2018 | 89 | a | 14.9 | 9.1 | 4.4 | 27.3 | 94 |
| DEN | 2019 | 92 | s | 20.1 | 10.8 | 7.2 | 31.3 | 94 |
| DEN | 2020 | 90 | s | 19.9 | 9.7 | 7.0 | 32.0 | 92 |
| DEN | 2021–2024 | 98 | sPlus | 26.1 | 12.2 | 8.7 | 34.1 | 96 |
| DEN | 2025–2026 | 96 | sPlus | 28.7 | 12.8 | 10.5 | 35.8 | 97 |

**Michael Jordan**

| Equipo | Temporadas (cierre) | Media | Tier | PPP | RPP | APP | MIN | IQ |
|---|---|---|---|---|---|---|---|---|
| CHI | 1985–1986 | 92 | s | 27.2 | 6.0 | 5.3 | 36.0 | 92 |
| CHI | 1987–1989 | 99 | sPlus | 34.9 | 6.2 | 6.2 | 40.2 | 95 |
| CHI | 1990–1993 | 99 | sPlus | 31.9 | 6.5 | 5.9 | 38.5 | 96 |
| CHI | 1995–1998 | 98 | sPlus | 29.4 | 6.1 | 4.1 | 38.2 | 91 |
| WAS | 2002–2003 | 85 | a | 21.2 | 5.9 | 4.4 | 36.1 | 83 |

**Kobe Bryant**

| Equipo | Temporadas (cierre) | Media | Tier | PPP | RPP | APP | MIN | IQ |
|---|---|---|---|---|---|---|---|---|
| LAL | 1997–1999 | 82 | a | 13.8 | 3.2 | 2.4 | 25.3 | 86 |
| LAL | 2000–2002 | 92 | s | 25.4 | 5.9 | 5.1 | 39.1 | 90 |
| LAL | 2003–2005 | 94 | s | 27.4 | 6.2 | 5.7 | 40.1 | 91 |
| LAL | 2006–2009 | 97 | sPlus | 30.5 | 5.6 | 5.0 | 39.2 | 90 |
| LAL | 2010–2013 | 93 | s | 26.8 | 5.3 | 5.1 | 37.3 | 85 |
| LAL | 2014–2016 | 79 | a | 18.9 | 4.4 | 3.9 | 30.3 | 77 |


## 6. Top 20 de bajadas y subidas (mejor ventana v3 contra la carta por década v2)

Formato: (diferencia, id v2, media v2, media mínima v3 de sus ventanas, máxima, nº de ventanas).

Bajadas:
```
(-8, 'bayloel01-LAL-50', 94, 86, 86, 1)
(-7, 'felixra01-BLB-50', 90, 83, 83, 1)
(-7, 'unselwe01-WAS-60', 97, 90, 90, 1)
(-6, 'cousybo01-BOS-50', 97, 83, 91, 3)
(-6, 'debusda01-NYK-60', 87, 81, 81, 1)
(-6, 'hattove01-SAC-50', 75, 69, 69, 1)
(-6, 'hutchme01-ATL-50', 86, 80, 80, 1)
(-6, 'hutchme01-DET-50', 85, 79, 79, 1)
(-6, 'jacksji01-GSW-90', 83, 77, 77, 1)
(-6, 'mannida01-LAC-80', 82, 76, 76, 1)
(-6, 'sauldwo01-WAS-60', 73, 67, 67, 1)
(-6, 'sharmbi01-BOS-50', 94, 85, 88, 2)
(-6, 'webbech01-SAC-90', 88, 82, 82, 1)
(-5, 'afflaar01-NYK-10', 79, 74, 74, 1)
(-5, 'barneji01-NYK-60', 82, 77, 77, 1)
(-5, 'barnhle01-BLB-50', 77, 72, 72, 1)
(-5, 'billuch01-TOR-90', 78, 73, 73, 1)
(-5, 'butleca01-WAS-10', 83, 78, 78, 1)
(-5, 'carrica01-WAS-act', 74, 69, 69, 1)
(-5, 'crawfja01-GSW-00', 82, 77, 77, 1)
```
Subidas:
```
(7, 'murrake01-DET-50', 69, 64, 76, 2)
(7, 'mogusle01-GSW-50', 71, 66, 78, 2)
(7, 'macaued01-STB-50', 82, 89, 89, 1)
(7, 'kupchmi01-LAL-80', 69, 63, 76, 2)
(7, 'keybr01-DEN-act', 68, 75, 75, 1)
(7, 'huffja01-DEN-act', 67, 74, 74, 1)
(6, 'toomaja01-DNN-50', 75, 81, 81, 1)
(6, 'smithja01-SAC-00', 64, 64, 70, 2)
(6, 'simpkdi01-CHI-90', 68, 63, 74, 2)
(6, 'sadowed01-BOS-40', 75, 81, 81, 1)
(6, 'pricebr01-WAS-90', 76, 67, 82, 2)
(6, 'nuttde01-DAL-80', 69, 75, 75, 1)
(6, 'novakst01-UTA-10', 69, 75, 75, 1)
(6, 'mitchto02-DET-10', 67, 73, 73, 1)
(6, 'marshdo01-PHI-00', 73, 79, 79, 1)
(6, 'leedo01-SAC-90', 70, 76, 76, 1)
(6, 'komenmi01-AND-50', 69, 75, 75, 1)
(6, 'kinnebo01-BOS-50', 75, 81, 81, 1)
(6, 'greenje02-HOU-act', 73, 69, 79, 2)
(6, 'boykoha01-WAT-50', 80, 86, 86, 1)
```

## 7. Balance

`Dificultad.mediaRivales`: Normal 78 → 79, Difícil 83 (sin cambio; Leyenda sin objetivo). Medición (`test/balance_test.dart`):
Normal 61 % típico / 98 % mejor; Difícil 31 % / 87 %; Leyenda 13 % / 59 % (objetivo 56/97, 29/89, 7/57: Leyenda queda algo fácil, depende de las mejores ventanas por franquicia).
