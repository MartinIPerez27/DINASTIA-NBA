# Verificación independiente A2a — Área 2 (Balance y simulación), primera mitad

Tramo: AUDITORIA_EXTERNA.md líneas 646–1060 (CAR-01 … MOT-07; MOT-09 empieza en la 1060 y queda fuera).
Copia de trabajo: worktree en c453f39. Todo el código citado es de ese commit. Los tests temporales (`test/zz_verif_*.dart`) se borraron y `git status` quedó limpio. Dos veces edité `lib/domain/motor.dart` en la copia (para probar variantes) y lo restauré de inmediato desde un respaldo.
Salidas crudas de mis mediciones: `/tmp/claude-0/-home-user/b2ab324b-7311-5a2f-a1eb-f08ab7cbaa11/scratchpad/verif/A2a_*.out`.

## Tabla resumen

| ID | Veredicto | Severidad informe | Severidad mía | Evidencia en una línea |
|---|---|---|---|---|
| CAR-01 | CONFIRMADO | crítico | crítico | Reproducido: media 69→76→84→92→99, 42–57 pts/partido, 82-0 desde la T7, 99 hasta el retiro forzoso a los 41, 17 anillos en 21 temporadas |
| MOT-01 | CONFIRMADO (cifras de época algo menores) | alto | medio-alto | Liga rival-rival: 85,1 posesiones y 93,5 pts; con base 9,6 → 95,2 posesiones y 104,4 pts (informe: 95,6 y 104,9) |
| MOT-02 | CONFIRMADO | alto / medio | medio | 3PAr 19,2 %, FT/FGA 33,5 %, TOV 14,5 %, falta en el 15,0 % de los dobles (informe: 19–21, 33, 14,6–19, 14,9) |
| MOT-03 | CONFIRMADO | alto | alto | balance_test exacto (56/97/101,2 · 29/89/104,7 · 7/57/103,6); con táctica recomendada Leyenda 0 % de 82-0, Normal 60–64 % |
| MOT-04 | CONFIRMADO | alto | alto | P&S 33–39 % también con sus efectos anulados (32,7/33,0/37,5/38,8); `interior` nunca se lee; recomendada 66–80 % |
| MOT-05 | CONFIRMADO (un dato a la mitad) | alto | alto | Presión toda cancha 59–81 %; presión alta en vivo 58,0 % contra 48,5 %; energía 0 en el 22 % de los partidos (informe 43 %) |
| CMP-01 | CONFIRMADO | alto | alto | 72/72 campañas completas (sin álbum y con álbum flojo); derrotas máximas 0 / 1 / 2 (4 con álbum flojo en Leyenda) sobre 8 vidas |
| CAR-02 | CONFIRMADO (cifras exactas distintas) | alto | alto | Figura 72–76 → 85–92 de media con 11–18 pts/partido; récords 4-78, 6-76, 14-68 en la T1–T3 |
| MDA-04 | CONFIRMADO | alto | alto | Camino típico Normal 2,05 escalones y 0 % campeón; Mejores equipos típico 0,25; Mundial Leyenda mejor plantel 1,30 rondas y 0 % |
| MDA-05 | CONFIRMADO | alto | alto | Media 86 vs 2000s: 50s 25,3 %, 60s 36,5 %, 70s 33,8 %, 2010s 70,0 %, 2020s 66,5 % (informe 24/31/31/57/67,5) |
| CMP-03 | CONFIRMADO (con matiz) | alto | medio-alto | Una temporada simulada deja a "victorias" en 5/5 etapas en las 6 cartas; puntos, triples, rebotes, robos y tapones llegan a 4–5 en las estrellas |
| CMP-04 | CONFIRMADO (cifras de 89–91 más lentas) | alto | alto | Media 82–86: techo división 2–5; 95: D1 en 9 temporadas en todas las corridas; 70 % de títulos después |
| ONL-02 | CONFIRMADO (la reproducibilidad entre plataformas es NO VERIFICABLE) | alto | medio hoy / alto cuando haya ranking | Mismo plantel y calendario, 16 semillas: rangos 42–54 y 55–70 victorias, desvío 3,7–4,1 |
| CAR-05 | PARCIAL | medio-alto | medio | Dinastía converge a 83–89 y los rivales no reaccionan (✓); anillos 1–6/15, no 0–2; Reescribí no reproduce 36–54 victorias ni 0 anillos |
| MOT-07 | PARCIAL | medio | bajo-medio | Triple en clutch 56,6 % y rotación apagada 29,0 % (✓); P&R NO es peor que no elegir (48,5 % contra 49,3 %, y 51,2 % contra 50,8 %); acelerar +2 pp |

Hallazgos falsos: ninguno. Exagerados o no reproducidos: la afirmación de que el Pick & roll "pierde" (MOT-07), el "0 anillos en 30 temporadas" y el arranque de 36–54 victorias de Reescribí (CAR-05), el 43 % de partidos con energía 0 (MOT-05) y el "casi siempre" de 77–85 % de 82-0 en Normal (MOT-03; mi muestra de 25 temporadas da 60–64 %).

---

## Detalle por hallazgo

### CAR-01 — Mi carrera se rompe a la 3.ª temporada (CONFIRMADO)

Código:
- `ModeloCarrera.costo` es 1/2/3 por tramo de atributo (`carrera_jugador.dart:340`).
- `phDeLinea` (`:1434`) da `min(24, pj·0,1 + max(0, valor−6)·0,25)`.
- `phObjetivos = cumplidos * 3` (`:1569`), o sea 9 PH por 3 objetivos.
- `phPremios = campeón 4 + premios·2 + allStar 2` (`:1570`).
- `desarrolloNatural` (`:344`) tiene el −1…−2,8 que cita el informe después de los 31.
- `retiroForzoso` = `edad >= 41 || (edad >= 36 && media < 66)` (`:1855`).
- `_estadisticas` usa clamp de ppp de 2 a 38 (`:253`).

Medición (reducida a 1 jugador, no a un lote): escolta creado `tiradorPantallas` con fuertes tiro/iq/defensa, pick 17, DAL, Normal, gastando todos los PH en el atributo de mayor peso/costo del puesto y renovando cada año.

```
T1 e20 media 69 11,1 pts 58-24
T2 e21 media 76 16,8 pts 62-20
T3 e22 media 84 25,7 pts 71-11
T4 e23 media 92 29,1 pts 78-4  ANILLO
T5 e24 media 99 42,1 pts 80-2  MVP
T6 e25 media 99 54,8 pts 80-2  ANILLO MVP
T7..T21 media 99 en todas, 48,8–57,2 pts, 81-1 / 82-0, ANILLO y MVP cada año
retiro forzoso a los 41 con media 99     → 17 anillos en 21 temporadas
```

Sin gastar PH: 69→71→74→76→79→80→81→83 (T8–T9), 7 anillos en 21 temporadas, retiro forzoso a los 40 con media 64. La causa 4 del informe ("el problema son los PH") se sostiene.

La forma coincide con la del informe (70→78→87→96→99; 53 pts; 82-0; 99 hasta los 41). Mi curva es un poco más lenta (84 contra 87 en la T3), lo que se explica por la prensa y el desempate de atributos.

Opinión: la severidad crítica es justa, porque el modo se vuelve trivial en 4 temporadas. La propuesta (costo progresivo por media + techo de potencial + test de bandas) es razonable. Un tope duro de PH por temporada sería la corrección más barata. El costo por tramo ya existe (`costo`), así que lo mínimo es subir los umbrales o agregar un tramo de costo 5–7 desde 90.

### MOT-01 — Pocas posesiones (CONFIRMADO)

Código:
- `segundos = 11.6 − 1.6·ritmo + U(0;5,5)` en `motor.dart:688` ✓.
- Rebote ofensivo → `_restoPosesion = 14` (`:1152`).
- Falta sin tiro 0,085 por posesión (`:668`).

Medición (600 partidos rival-rival de la liga Normal, equipos de `liga.equipo`, tácticas recomendadas, posesiones = FGA + 0,44·FTA − OREB + TOV):

```
LIGA: pts/eq 93,5 · poss/eq 85,1 · ORtg 109,8     (informe: 85,0–89,4 posesiones, 93–100 pts, ORtg 109–112)
```

Por época (150 partidos cada una, plantel de cartas de esa década, contra otro igual): 40s 70,9 · 50s 74,7 · 60s 81,0 · 70s 86,9 · 80s 94,7 · 90s 96,9 · 2000 97,3 · 2010 100,9 · 2020 104,1. El informe da 71,6 / 75,8 / 83,5 / 89,7 / 98,4 / 101,4 / 99,1 / 102,5 / 105,6. Mismo orden y misma forma, pero el informe sale 1–4 pts más alto. Mis planteles de década son aleatorios y los suyos pueden ser los mejores de cada una, así que lo atribuyo a la muestra. Las posesiones por época fueron 83–88 en todas.

Variante propuesta: con la base 9,6 (−2 s) en la copia, 600 partidos:
```
pts/eq 104,4 · poss/eq 95,2 · ORtg 109,6          (informe: posesiones 95,6/100,6/100,5; pts 104,9/113,8/111,7)
```
La primera cifra coincide. La recomendación de "11.0 + tiro V2" no la medí (depende de MOT-02).

Opinión: el diagnóstico es exacto. La severidad es medio-alta, no alta: afecta la sensación de los tanteos, no la jugabilidad ni el balance relativo. El orden de la recalibración (ritmo y perfil de tiro juntos, con el `balance_test` delante) es correcto.

### MOT-02 — Perfil de tiro irreal (CONFIRMADO)

Código: `_tasaTriples` con bases 0,38/0,32/0,20/0,08 y tope 0,6 (`motor.dart:1189-1201`); falta en dos `0.112 + pctTl·0.05` (`:1037`); `pPerdida` `0.178·…` con clamp(0,09; 0,3) (`:712-721`). Todo coincide.

Medición (mismos 600 partidos de MOT-01):
```
3PAr 19,2 % · FT/FGA 33,5 % · TOV% 14,5 · falta en el 15,0 % de los dobles
(informe: 19–21 % · 33 % · 14,6–19 % · 14,9 %)
```
No remedí el "valor por intento" (1,148 / 1,216) ni la variante V2.

Opinión: severidad media es justa. Cambiar las constantes globales (alternativa 1) es correcto como primer paso. Ojo con que las cartas de los 50–70 tienen `pctT3 = 0` y por eso siguen en 0,5 % de triples (visto en mi medición por época).

### MOT-03 — 82-0 en Normal casi siempre / imposible en Leyenda (CONFIRMADO)

- `balance_test` corrido tal cual: Normal 56 % / 97 % / 101,2 · Difícil 29 % / 89 % / 104,7 · Leyenda 7 % / 57 % / 103,6. Igual que el TRASPASO §9.1 y que el informe.
- `balance_test.dart:56-58` crea la `Temporada` sin `tactica` (default Motion / Switch All, `tactica.dart:149`), sin entrenador, con `temporadas = 3` por defecto ✓.
- La descripción "El 82-0 es una hazaña" está en `temporada.dart:112` ✓.
- `pesoDiferencia = 1/225` (`motor.dart:470`) y el término `(media−82)/400` (`:1007`) ✓. La suma es 1/144, como dice el informe.

Medición (mejor plantel de CHI y de LAL, táctica `recomendar(...)`, 25 temporadas por celda, partidos del usuario, semillas 2000+k):

| Dificultad | CHI (Aislamiento/Pack-Line) | LAL (Triángulo/Drop) | Informe (100 temporadas) |
|---|---|---|---|
| Normal | media 81,4 · mín 78 · 82-0 en 15/25 (60 %) | media 81,5 · mín 79 · 16/25 (64 %) | 81,7 / 77 % · 81,8 / 85 % |
| Difícil | media 79,6 · 73–82 · 4/25 (16 %) | media 80,1 · 74–82 · 5/25 (20 %) | 79,4 / 9 % · 80,2 / 20 % |
| Leyenda | media 63,6 · 56–71 · 0/25 | media 66,0 · 58–72 · 0/25 | 64,0 / 0 % · 67,3 / 0 % |

Las medias de victorias coinciden. Los porcentajes de 82-0 en Normal que da el informe (77–85 %) quedan más arriba que los míos (60–64 %). Con N=25 el error es de ±10 pp, así que son 1,5–2 desvíos de diferencia. La conclusión no cambia: en Normal es un coin-flip favorable, y en Leyenda es imposible (0,8^82 ≈ 10⁻⁸ ✓).

No reproduje la tabla de sensibilidad (+1 a +8 de media).

Opinión: severidad alta es justa por ser la promesa del juego. Cambiar el `balance_test` para que use la táctica recomendada y una métrica de P(82-0) es lo correcto. Alternativa 4 (cambiar el texto) es el parche inmediato mientras tanto.

### MOT-04 — La táctica la decide la afinidad (CONFIRMADO)

Código:
- `(afinidadOfensiva − afinidadDefensiva)/1500` en `motor.dart:1017` ✓; el +12 por entrenador en `:287-290` ✓; química ±1 pp (`quimica.dart:122`: `(puntaje−50)/5000`) ✓.
- `_Efectos.interior` (`:240`) se declara y nunca se lee. `grep` de `.interior` en motor.dart solo encuentra la declaración y la función local `interior(Jugador)`. Post Inside-Out, Dribble Drive, PnR Español y 5-Out no reciben su efecto ✓.

Mediciones (300–600 partidos por celda, mismo plantel contra sí mismo con Motion/Switch All, local alternado; 4 planteles: CHI, LAL, BOS y un típico):

| | CHI | LAL | BOS | típico | Informe |
|---|---|---|---|---|---|
| Recomendada contra la por defecto | 80,3 % | 70,0 % | 73,3 % | 66,3 % | 69 / 69 / 78 / 73 % |
| Pace & Space (afinidad) | 33,3 % (30) | 32,7 % (39) | 38,0 % (34) | 38,0 % (30) | 35–39 % |
| Seven Seconds | 30,0 % | 32,7 % | 35,7 % | 28,0 % | 27–37 % |
| Princeton | 57,7 % | 56,3 % | 61,0 % | 55,0 % | 50–57 % |
| Triángulo | 50,0 % | 53,3 % | 50,7 % | 53,3 % | 50–57 % |

Prueba clave: neutralicé `paceAndSpace` a `_Efectos()` (todos los efectos propios en 1) en mi copia y volví a medir 600 partidos: **32,7 % / 33,0 % / 37,5 % / 38,8 %**, igual que con los efectos puestos (33–38 %). Es decir, los efectos propios de P&S no mueven el resultado y lo único que lo decide es la afinidad. (No anulé el ritmo, porque viene del enum y no de `_Efectos`.) El motor quedó restaurado.

No medí el efecto del entrenador (+4–5 pp) ni la comparación mejor entrenador contra recomendada.

Opinión: severidad alta justa. Conectar `interior` es un arreglo de una línea y es un bug claro. Bajar la afinidad a /3000 puede dejar inútil la recomendación; conviene medirlo con el test `playbook_balance_test` que propone el informe antes de fijar el número.

### MOT-05 — Defensas de robo y presión alta (CONFIRMADO; un dato a la mitad)

Código: `presion` multiplica pérdidas ×1,3 y faltas ×1,25 (`motor.dart:703, 719`). El castigo por energía baja solo afecta al tirador (`:1029-1030`). `presionAlta`/`acelerarRitmo` solo se llaman desde `partido_pantalla.dart:810,815`, o sea que la IA nunca los usa ✓. Switch All es el default (`tactica.dart:149`) ✓.

Mediciones (300 partidos por celda, mismo plantel, defensa distinta contra Switch All):

| Defensa | CHI | LAL | BOS | típico | Informe |
|---|---|---|---|---|---|
| Presión toda cancha | 76,3 % | 80,7 % | 78,0 % | 59,0 % | 59–79 % |
| Trap & Blitz | 68,7 % | 72,3 % | 71,7 % | 59,0 % | 56–75 % |
| 1-3-1 | 69,0 % | 75,7 % | 74,7 % | 60,7 % | 58–71 % |
| Pack-Line | 67,3 % | 70,3 % | 73,7 % | 62,7 % | (no citada) |
| Princeton + Presión contra la recomendada | 50,3 % | 60,7 % | 64,3 % | 47,3 % | 50,8 / 52,5 / 38,7 / 61,7 % |

Presión alta en vivo todo el partido (plantel típico, 800 partidos, local alternado): **58,0 %** contra **48,5 %** de control (informe 60,4 contra 49,3).

Partidos con alguien en cancha a energía 0 con presión en los dos equipos: **131/600 (22 %)**, el informe da 1.704/4.000 (43 %). Mi conteo solo mira a los jugadores en cancha en cada evento, y la rotación automática saca a algunos antes de que lleguen a 0, así que puede ser metodológico. No lo reproduje al mismo nivel.

Opinión: severidad alta justa; es la jugada dominante del Playbook. El informe recomienda 2 + 1 suave (que la energía baja penalice también la defensa y recalibrar robos/presión), y es lo más coherente.

### CMP-01 — Conquista no se puede perder (CONFIRMADO)

Código (todas las líneas exactas): `conquistados: [franquiciaId]` en `competitivo.dart:1060`; `cartasDisponiblesConquista` suma todas las cartas de las franquicias conquistadas (`:1088-1091`); el pozo se ofrece desde el primer turno (`presentation/modos/competitivo.dart:541`); objetivo de rivales `72/76/80 + 0,35·conquistados` (`:1065-1070`); `vidas = 8` (`:259`); el test que habría que reescribir está en `competitivo_test.dart:196`.

Medición: campañas completas con la API real (`nuevaConquista` → `atacar` → `simularConquista`, rearmando el mejor equipo del pozo tras cada conquista, atacando un vecino cualquiera). 6 franquicias iniciales (LAL, CHI, ORL, MEM, TOR, CHA) × 2 corridas por dificultad:

```
sin álbum    Normal  12/12 completas, derrotas máx 0
sin álbum    Difícil 12/12 completas, derrotas máx 1 (media 0,08)
sin álbum    Leyenda 12/12 completas, derrotas máx 2 (media 0,58)
álbum flojo  Normal  12/12 completas, derrotas máx 0
álbum flojo  Difícil 12/12 completas, derrotas máx 1
álbum flojo  Leyenda 12/12 completas, derrotas máx 4 (media 0,58)   (vidas: 8)
```
72/72 completas, igual que el informe (72/72, derrotas máx 0 en Normal y 2 en Leyenda). El álbum no cambia el resultado.

Opinión: severidad alta justa. La propuesta de botín de una carta por territorio es la mejor (ataca la causa, que es el desbloqueo masivo). Bastaría con excluir `e.inicio` del pozo como parche de una línea, pero el informe tiene razón en que no alcanza.

### CAR-02 — Figura franquicia (CONFIRMADO)

Código:
- `Jugador.conMedia` copia `stats` tal cual (`jugador.dart:184-…`) ✓.
- El motor elige al tirador/estrella por `stats.ppp` (`motor.dart:759, 828, 893, 952, 970, 985`) ✓.
- `crecimientoFigura` (`dinastia.dart:702`): `porJuego` es 0 si `pts+0,7reb+0,7ast < 22` ✓; crece por edad clamp(1,5) hasta los 30.
- El resto del plantel es Tier B 66–76 (`nuevaFigura`, `:662`) ✓.

Medición: DET, Normal, 3 semillas, 6 temporadas, eligiendo el novato de más media en cada receso:

```
semilla 1 Justin Holiday 76: récords 14-68, 31-51, 15-67, 20-62, 24-58, 14-68 | pts 13,9→17,1 (media 76→91)
semilla 2 Sedale Threatt 72: récords 7-75, 13-69, 27-55, 34-48, 40-42, 34-48 | pts 11,0→12,7 (72→85)
semilla 3 Joe Caldwell 75: récords 6-76, 4-78, 7-75, 17-65, 19-63, 28-54 | pts 14,1→18,1→16,4 (75→92)
```
La figura sube 15–19 de media y sus puntos solo pasan de ~11–14 a ~13–18. Coincide con "12–17 pts, sin premios" del informe. Los arranques de 1-81 / 2-80 los reproduje solo en parte (peor mío: 4-78, 6-76 y 7-75), y esa diferencia es de semilla. Un detalle: el motor sí le da más acierto a la figura por la media (`motor.dart:1006-1007`), pero no más tiros.

Opinión: severidad alta justa para el modo. La propuesta (reescalar stats con `ModeloCarrera.estadisticasActuales`) es buena, con cuidado de no repetir CAR-01.

### MDA-04 — Camino / Mejores equipos / Mundial (CONFIRMADO)

Código: Camino `base + 2 + round(1,7·i)` (`escalera.dart:1003`); Mejores equipos con planteles all-time y ajuste de dificultad (`:1158-1160, 1186-1191`); Mundial usa `mediaRivales` (null en Leyenda) (`:1032, 1040`) ✓.

Medición reducida: N=20 corridas por celda (informe N=60), típico = draft de ruleta (mismo generador que `balance_test`), mejor = mejor plantel de CHI/LAL/BOS, API real de `ModosEscalera`.

| Modo | Dificultad | Típico (ganados · completan) | Mejor (ganados · completan) | Informe típico / mejor |
|---|---|---|---|---|
| Camino | Normal | 2,05 · 0 % | 9,65 · 95 % | 3,08 · 1,7 % / 9,03 · 80 % |
| | Difícil | 2,20 · 0 % | 8,35 · 60 % | 2,45 · 0 % / 8,13 · 68 % |
| | Leyenda | 0,95 · 0 % | 6,90 · 30 % | 0,97 · 0 % / 6,80 · 40 % |
| Mejores equipos | Normal | 0,25 · 0 % | 5,80 · 25 % | 0,15 · 0 % / 7,35 · 37 % |
| | Difícil | 0,00 · 0 % | 5,00 · 15 % | 0,07 · 0 % / 5,25 · 7 % |
| | Leyenda | 0,00 · 0 % | 4,25 · 0 % | 0,03 · 0 % / 3,58 · 1,7 % |
| Mundial | Normal | 2,20 · 25 % | 5,00 · 100 % | 2,02 · 21,7 % / 4,83 · 97 % |
| | Difícil | 0,40 · 0 % | 3,75 · 65 % | 0,65 · 3,3 % / 4,10 · 72 % |
| | Leyenda | 0,00 · 0 % | 1,30 · 0 % | 0,02 · 0 % / 1,37 · 1,7 % |
| Racha | Normal | 6,3 · logro ≥15: 10 % | 19,05 · 85 % | 7,5 · 10 % / 19,5 · 82 % |
| | Difícil | 3,75 · 0 % | 15,4 · 55 % | 4,6 · 0 % / 16,4 · 58 % |
| | Leyenda | 1,45 · 0 % | 9,2 · 20 % | 1,7 · 0 % / 9,7 · 22 % |

Coincide en todas las celdas dentro del ruido. Aclaro que "completan" de Racha no aplica (no tiene fin); para ese modo reporto el logro ≥15.

Opinión: severidad alta justa. La recomendación 1 (recalibrar y test de bandas) más la 3 (progresión meta) es sensata. El Mundial en Leyenda con `mediaRivales = null` es el caso más claro: no se puede ganar ni con el mejor plantel.

### MDA-05 — Sesgo de época (CONFIRMADO)

Código: `epocas.dart:536-546` y `porDecada = 3.0` (`:550`) con el comentario "El motor juega las épocas viejas más débiles que su media" ✓.

Medición: 5 planteles de cada década con media de los 6 = 86,0 exacta (suma 516) contra 5 planteles 2000s de media 86,0, tácticas recomendadas, 400 partidos por década, local alternado:

```
          mío     informe
50s     25,3 %    24,0 %
60s     36,5 %    31,3 %
70s     33,8 %    30,5 %
80s     57,5 %    58,3 %
90s     65,0 %    62,3 %
2010s   70,0 %    57,3 %
2020s   66,5 %    67,5 %
40s: no hay planteles con media 86 en esa década
```
Las desviaciones de 60s/70s (+5 y +3 pp) y de 2010s (+13 pp) son compatibles con la selección aleatoria de cartas. El sesgo de época está más que probado.

Opinión: severidad alta justa. Ya hay una prueba en el código (`porDecada`), pero solo para el Guantelete. La opción 2 (media efectiva en catálogo) arregla la causa visible; la causa mecánica está en MOT-02 (las cartas viejas tienen 0 triples y el 3PAr de 50s–70s fue 0,5 % en mi medición).

### CMP-03 — Evoluciones, 5 etapas en una temporada (CONFIRMADO con matiz)

Código: metas en `evoluciones.dart:90-98` (el informe dice 87-97: corrido 3 líneas); `maxNivel = 5`, `maxActivas = 3`; `activas` cuenta solo las incompletas, así que al completar una carta se libera el cupo (`:124, :130`).

Medición: temporada regular completa (82 partidos) de un plantel con media 98,7 (Jordan, LeBron, Bird, Shaq, Robinson, Jokić), luego `avanzarEvoluciones` con cada objetivo asignado a las 6 cartas. Etapas alcanzadas (de 5):

```
victorias    5/5 en las 6 cartas (45 victorias de meta)
puntos       Jordan 5, resto 4
triples      LeBron 5, Jordan 4, Bird 4
rebotes      Shaq 5, Bird 4, Robinson 4, Jokić 4, Jordan 3, LeBron 3
robos        Jordan 5, Bird 5, resto 3–4
tapones      Shaq 5, Robinson 5, resto 3–4
asistencias  4 en LeBron/Bird/Jokić; 2–3 el resto (el informe usa a Lillard: 500 → 5)
partidos     4 en todas (82 de 90)
noche30      0 (no cuenta en simulación en bloque; está documentado en el código)
```
El informe tiene razón: "victorias" llega a 5 etapas en una sola simulación para cualquier carta de un equipo que gane ≥45 partidos, y las demás metas llegan a 4–5 para las estrellas.

Matiz: "+15 de media" es la suma sobre 3 cartas (+5 a cada una), no +15 a la media del equipo (que sube +2,5 si las tres son titulares). La severidad la bajaría a medio-alta: aplica solo a los modos de álbum, y un equipo típico (56 % de victorias, ≈46 victorias) apenas llega a la meta de victorias.

Opinión: la alternativa 1 (metas ×3) es lo más simple; lo importante es que el cupo se libera al completar y que en una temporada se completa una carta entera. Un tope de etapas por día sería más fuerte pero depende del reloj local.

### CMP-04 — Divisiones (CONFIRMADO; cifras en 89–91 más lentas que las del informe)

Código: objetivo `min(95, 68 + round((10−div)·2,6) + {0,2,4})` (`competitivo.dart:124`), de 68 a 91 (Normal) y de 72 a 95 (Leyenda) ✓; 10 partidos por temporada, asciende con ≥21 puntos y desciende con ≤9 (`:95-96`), 3 por victoria y 4 por paliza ≥15 (`:106`). XP por título: `300·mult` XP + 120 monedas (`:1277`) más `ganados·30·mult` XP por partido (`:1255-1262`) = 900 XP y 220 monedas en Leyenda ✓ (cálculo de mi lectura; no medí `mult` a mano).

Medición (4 corridas por celda, tope 25 temporadas, equipos con media de los 6 dada exacta; informe: ídem, 4 corridas):

| Media | Normal (temporadas hasta D1) | Leyenda |
|---|---|---|
| 82 | nunca (techo 2–3) | nunca (techo 4–5) |
| 86 | nunca, 10, nunca, 22 | nunca (techo 3–4) |
| 89 | nunca, 13, nunca, 12 | nunca, 11, nunca, nunca |
| 91 | 21, 19, 9, 10 | 13, nunca, 10, 13 |
| 95 | 9, 9, 9, 9 | 9, 11, 11, 9 |

Títulos hasta la T25 con media 95 en Normal: 5, 13, 15, 12 (de 16 posibles después de llegar, 70 % en promedio); en Leyenda: 7, 11, 9, 12. El informe da "61 títulos en 66 temporadas" (92 %). Mi muestra queda por debajo, pero con un 70 % se sigue farmeando. Con 89 el informe dice "9–10" en Normal y yo veo 12–13 o nunca; con 91 veo 9–21 contra 9–11. Eso moderaría el titular "con media ≥89 subís en el mínimo posible": en mi medición eso solo ocurre con ~95.

Opinión: severidad alta justa. El objetivo elástico + premio decreciente es una corrección razonable; el premio de título sin tope (900 XP y 220 monedas por 2 toques) es el problema de economía más claro.

### ONL-02 — Desafío del día mide suerte (CONFIRMADO; arm64 contra x86 NO VERIFICABLE)

Código:
- `semillaDeAzar` y `azarDraftDelDia` en `variantes.dart:185-193` ✓. `iniciar` crea una `Liga` sembrada solo para armar rivales y calendario (`:214-215`) ✓.
- La liga global se crea sin semilla (`main.dart:77-78`) y cada partido usa `azar ?? _azar` (`liga.dart:305-309`).
- Llamadas en `presentation/pantallas/temporada_pantalla.dart:131` y `playoffs_pantalla.dart:109` ✓.
- El día sale de `DateTime.now()` (`presentation/modos/variantes.dart:383`) ✓.
- `desafiosDelDia` es un campo del perfil local (`perfil.dart:198`).

Medición: mismo plantel, mismos rivales y calendario (`t0` fijo), 16 `Liga` con semilla distinta solo para los partidos:

```
plantel 500: [42,42,46,46,47,47,49,49,50,50,51,52,52,53,54,54] media 49,0 · desvío 3,7 · rango 42–54
plantel 501: [55,58,58,59,60,62,62,64,64,65,66,66,66,67,69,70] media 63,2 · desvío 4,1 · rango 55–70
(informe: 64–74, desvío 2,6 · 53–68, desvío 4,5)
```
Mis planteles usan otro calendario, pero la conclusión es la misma: dos amigos con el mismo draft quedan separados por 12–15 victorias.

NO VERIFICABLE: que `Random(seed)` de Dart sea idéntico entre arm64 y x86 (no tengo ni dispositivo ni arquitectura distintos).

Opinión: hoy no hay ranking online, así que lo pondría en medio; sube a alto en cuanto se agregue. La propuesta de sembrar cada partido con `hash(semilla, partido.id)` es la mejor y es barata.

### CAR-05 — Dinastía y Reescribí sin contrapeso (PARCIAL)

Código: `cambioPorEdad` (`dinastia.dart:370`) da +3 hasta los 23, +2 hasta los 25, +1 hasta los 27; los novatos llegan con edad 22 ± 1 (`edadInicial`, `:358-366`) ✓. Cada temporada `liga.iniciar` rearma los rivales con el mismo objetivo de dificultad (`rivalesDeEpoca` línea 473 usa `mediaRivales`), sin memoria entre temporadas ✓. No hay tope salarial ni agencia libre.

Medición Dinastía (CHI, Normal, plantel típico semillas 500+k, eligiendo el novato de más media, 15 temporadas, 3 semillas):

```
s1: T1 86,7/62  T3 85,2/66  T5 85,5/58  T8 83,3/53  T10 83,2/48  T12 86,5/58  T15 85,3/67 | anillos 2/15
s2: T1 79,3/30  T3 79,7/24  T5 78,2/21  T8 79,7/27  T10 86,0/50  T12 88,2/62  T15 88,7/66 | anillos 1/15
s3: T1 86,0/60  T3 86,0/59  T5 83,0/57  T8 77,0/39  T10 81,7/65  T12 86,2/66  T15 89,2/79 | anillos 6/15
```
Curva y convergencia a 85–89 reproducidas. Anillos: 2, 1 y 6 (media 3,0/15), contra "1,3/15 (4 en 45)" del informe. Con 3 muestras el rango es amplio; el "los playoffs al azar pesan" sí se ve (la semilla 3 con 79-3 de T15 ganó 6).

Medición Reescribí (1 semilla, 14 temporadas, novato de más media):
```
CHI años 60: T1 83/45 T2 84/60 T3 86/54 T4 87/57 … T9 84/34 T10 82/38 T11–T14 81/42–47 | 1 anillo
LAL años 50: T1 89/63 T2 90/65 T3 91/67 … T8 84/47 T9 81/34 T10 78/27 T11 82/38 T12 85/59 … | 3 anillos
```
NO reproduzco "CHI años 60 y LAL años 50 ganan solo 36–54" (LAL 50s arranca con 63–67 victorias) ni "0 anillos en 30 temporadas" (obtuve 1 y 3 en 14). Sí aparece el bajón entre T8 y T10 (27–38 victorias) que el informe describe como hundimiento, pero se recupera en T11–T12 en LAL y llega a 81 de media en CHI.

Opinión: severidad medio es justa. Lo robusto del hallazgo es "la liga no reacciona y el plantel converge". La parte de Reescribí no la sostendría tal cual (le falta N). Lo más barato es la alternativa 3 (rival elástico con tu récord) como parche.

### MOT-07 — Vivo contra simulado (PARCIAL)

Código verificado: `liga.motor` pasa `usuarioLocal: p.localId == t.franquiciaUsuarioId` (booleano, nunca null) (`liga.dart:308`); el chequeo de tiempo muerto es `usuarioLocal != local && rival.racha >= 10` (`motor.dart:516-517`), por lo que el lado del usuario nunca pide tiempo muerto automático al simular ✓. En los partidos donde el usuario no juega (todos sus rivales entre sí) `usuarioLocal` también es `false`, así que el visitante nunca pide tiempo muerto y el local sí (asimetría chica, no está en el informe). `porElTriple` exige `jugada == null` (`:960-962`) ✓. El Pick & roll tiene `triple = false` y el bonus de +0,04 (`:1011`).

Medición (mismo plantel contra sí mismo, local alternado):

| Política | % victoria mío (2.500 partidos, plantel típico) | 2.500 partidos, plantel LAL | Informe (1.000) |
|---|---|---|---|
| Ambos IA (`usuarioLocal` null) | 51,1 | 49,2 | 49,2 |
| Usuario marcado sin intervenir | 49,3 | 50,8 | 49,3 |
| Tiempo muerto si alguien <50 (800 partidos) | 48,9 | — | 50,9 |
| Jugada clave Triple en clutch | **56,6** | — | 56,7 |
| Jugada clave Aislamiento en clutch | **55,5** | 50,2 | 53,6 |
| Jugada clave Pick & roll en clutch | 48,5 | 51,2 | **45,8** |
| Acelerar todo | 51,4 | — | 48,3 |
| Presión alta todo el partido (800) | 58,0 | — | 60,4 |
| Rotación automática apagada (800) | **29,0** | — | 27,4 |

Confirmo: Triple en clutch es la opción dominante (+7 pp), la rotación apagada se funde (29 %), la presión es dominante y el tiempo muerto automático no actúa al simular. **No reproduzco que el Pick & roll sea peor que no elegir**: con dos planteles distintos da 48,5 contra 49,3 y 51,2 contra 50,8, es decir neutral. (Aislamiento con LAL, que ya es un plantel muy superior al rival, también queda en neutral.) Esa parte del informe no se sostiene. El informe vio −3,5 pp, que puede ser ruido de N=1.000 (error estándar ≈ 1,6 pp) o un plantel específico.

Opinión: severidad media es justa o incluso baja. La corrección de dejar que `liga.motor` use `usuarioLocal: null` al simular es válida y barata. El texto "el P&R pierde" debería tomarse con cautela y retirarse del titular.

---

## Cosas que no se midieron (honestidad)
- MOT-01: los datos por época son de mi propia selección de planteles. La combinación "11.0 + V2" y la tanda V2 no se midieron.
- MOT-02: valor por intento (1,148 / 1,216) y la variante V2 (0,62/0,54/0,34/0,14).
- MOT-03: la tabla de sensibilidad +1/+3/+5/+8 de media.
- MOT-04: el efecto del entrenador y mejor entrenador contra recomendada. El resto del hallazgo sí.
- MOT-05: el 43 % de energía 0 salió en 22 % con mi método.
- ONL-02: determinismo de `Random` entre arm64 y x86 (NO VERIFICABLE).
- CAR-01: un solo jugador (escolta) en 21 temporadas, no el lote de 80 temporadas del informe; no medí el pívot ni los jugadores reales.
- CAR-05: Dinastía y Reescribí con 3 y 1 semillas respectivamente.
