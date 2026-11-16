# Verificación A1b: tramo líneas 400-645 del informe (Área 1, resto)

Copia de trabajo: `.../scratchpad/wt/A1b` (commit c453f39). Tests temporales `test/zz_verif_*.dart` borrados; `git status` limpio. En `perfil_perfecto.dart` toqué temporalmente el umbral 600→60 para medir y lo restauré (git status sin cambios).

META-06 (líneas 400-406) es el final del hallazgo anterior; no es de mi tramo y no lo evalué.

## Tabla

| ID | Veredicto | Sev. informe | Sev. mía | Evidencia en una línea |
|---|---|---|---|---|
| MOT-06 | CONFIRMADO | medio-alto | medio-alto (medio) | En 4.018 partidos de liga: 572 con expulsión, 152 con expulsado que sigue en cancha, 23 jugadores con >6 faltas; 0,208 expulsiones/partido (motor.dart:554-556, 572) |
| MDA-07 | CONFIRMADO (parte clutch); import no verificado | medio | medio-bajo | Borrar `momentos-clutch` reinicia `superados` y se vuelve a pagar (historia.dart:588-604, 661-667; presentation/modos/historia.dart:58-64; partidas_pantalla.dart:197-212). Las cifras "160 XP/80" no cuadran con 80/40 por momento |
| MDA-09 | CONFIRMADO (el "sin botón de salida" es falso) | medio | medio | Test: álbum de 6, Magic en Sexto, `puedeRepartir(base)=false` con `coleccionAlcanza=true` |
| MDA-13 | CONFIRMADO en código (solapa con MOT-08) | medio | bajo-medio | `_guardar(antes)` antes del vivo; solo `onTerminado` registra (temporada_pantalla.dart:127-140) |
| MDA-08 | CONFIRMADO | medio | bajo | `_fase/_marcador` sin Escalera/Épocas/Clutch; fase cae en "Temporada regular"/"Draft" y 0-0 |
| CMP-07 | CONFIRMADO | medio | medio-bajo | 120/120 niveles con solución única; el recorte por reloj de pared hace cambiar 14 de 120 niveles con límite 60 ms |
| META-08 | CONFIRMADO | medio | medio-bajo | Test: 6 cumplidas → tras medianoche 3 sin cobrar sobreviven (solo semanales); atrasar y volver deja 0 diarias reclamadas |
| META-11 | CONFIRMADO (el tamaño de 10 MB no se midió) | medio | medio-bajo | partidas_pantalla.dart:113-120, 165-174, 190; db_local.dart:47-58 |
| ONL-06 | PARCIAL | medio | bajo-medio | Config 2000 objetos es cierta, pero las fotos son por jugador: 4.063 jugadores únicos, no 11.323 cartas |
| MOT-08 | CONFIRMADO en código (duplica MDA-13) | medio | bajo-medio | Igual que MDA-13; `Liga` usa `Random()` sin semilla (main.dart:78, liga.dart:21) |
| CMP-08 | CONFIRMADO | bajo | bajo | `_album` sin `aplicarEvoluciones` (presentation/modos/armado.dart:1052-1055) pese a `usaAlbum` incluir `desafiosArmado` (modo_juego.dart:123) |
| CAR-11 | PARCIAL (una afirmación es falsa) | bajo | bajo | `pidioTraspaso` SÍ se persiste (carrera_jugador_pantallas.dart:561, 923-926, 563-566); el paso no |
| CAR-10 | CONFIRMADO el mecanismo; datos del log NO VERIFICABLES | bajo | bajo | premios.dart:161-165, sin exclusión de MVP. `zzlog/mc_lote1.txt` no existe en el commit |
| META-12 | CONFIRMADO (latente) | bajo | bajo | main.dart:265 asigna `_guardada = t` antes de `if (_liga case final liga?)` |
| MOT-11 | CONFIRMADO los 6 puntos (cada uno por lectura; el de energía 0 también medido) | bajo | bajo | liga.dart:337-345, motor.dart:543, 720, liga.dart:419 |

## Detalle

### MOT-06: CONFIRMADO
- Código: `_faltaPersonal` pone `salePendiente` al llegar a 6 faltas (motor.dart:652-655). `_cambioPedido` limpia `salePendiente` antes de comprobar que el banco no esté expulsado y devuelve null (motor.dart:554-556), así que el expulsado se queda en cancha. `_rotar` retorna temprano si el banco está expulsado (motor.dart:572). El banco largo (`reserva`) no se usa para reemplazar expulsados.
- Medición: replicé el método del informe (`Liga.motor` con la franquicia CHI, 49×82 partidos, semillas fijas). Detecté "expulsado sigue en cancha" cuando está en cancha tras dos eventos consecutivos, porque el cambio se aplica en el evento siguiente a la expulsión.

| | Informe (4.000) | Mía (4.018) |
|---|---|---|
| Partidos con expulsión | 550 (13,8 %) | 572 (14,2 %) |
| Con expulsado en cancha | 111 (2,8 %) | 152 (3,8 %) |
| Jugadores con >6 faltas | 9 | 23 |
| Expulsiones por partido | 0,20-0,22 | 0,208 |

- Mi criterio de "en cancha" es algo más amplio (dos eventos consecutivos), de ahí la diferencia. El orden de magnitud y el mecanismo coinciden. Con presión en ambos equipos, 300 partidos de equipos aleatorios del catálogo: 169 con expulsión y 69 con expulsado en cancha.
- TRASPASO §7.3 dice "expulsiones ~0,1 por partido" (docs/TRASPASO_COMPLETO.md:222): lo real es ~0,21. El informe acierta.
- Opinión: severidad "medio-alto" algo alta. El bug aparece en ~4 % de partidos y no afecta resultados de forma sistemática, pero es visible en vivo ("a las duchas" y sigue jugando). La alternativa 1 (reemplazo desde `reserva`) es la correcta.

### MDA-07: CONFIRMADO la parte clutch
- `superados` vive en `datosModo` de la partida `momentos-clutch` (historia.dart:588-604). Entrar sin esa partida crea una vacía (presentation/modos/historia.dart:58-64). `premiarHistoria` paga `xpMomentoClutch=80 / monedasMomentoClutch=40` por momento nuevo (historia.dart:649, 661-667). Borrar la partida desde Partidas está permitido para cualquier partida (partidas_pantalla.dart:197-212). Por lo tanto es cobrable de nuevo.
- Reparo: el informe dice "160 XP / 80 monedas" para Kawhi '19, pero la constante es 80/40 por momento. Solo cuadraría con otro multiplicador o dos momentos. No lo ejecuté. La conclusión no cambia.
- La parte "import" (Extremo +1000/+400, trofeos de escalera) depende de MDA-01 (fuera de mi tramo). Las condiciones citadas existen (variantes.dart:273-276 equivale a `lib/domain/variantes.dart`; la ruta del informe es imprecisa), pero no probé el flujo de importar.
- Opinión: en un juego personal sin ranking es bajo-medio. La opción 1 (estado en el perfil) es buena; la 3 (libro mayor) solo si habrá ranking.

### MDA-09: CONFIRMADO
- `Draft.coleccionAlcanza` solo se evalúa al elegir la regla (draft.dart:74-84; llamadas en elegir_modo.dart:61, main.dart:290, competitivo.dart:44, carrera.dart:38, torneos.dart:340).
- Test: álbum de 6 cartas con Magic Johnson como único base-capaz (posiciones base/escolta) → `coleccionAlcanza=true`. Fichando a Magic en Sexto Hombre, `puedeRepartir(base)=false` (draft.dart:142-143 con `_elegibles` vacío). `tirar` lanza `StateError('No quedan cartas…')` (draft.dart:125) y la pantalla lo muestra en un SnackBar (draft_pantalla.dart:137-140).
- El "No hay botón de salida del draft" es incorrecto: la pantalla tiene AppBar (draft_pantalla.dart:288) y se puede salir y borrar la partida. Lo cierto es que la partida queda inutilizable.
- Observación extra: `coleccionAlcanza` es una asignación voraz (draft.dart:76-83), sin backtracking. Puede dar falsos negativos, no solo falsos positivos.
- Opinión: severidad justa. La recomendada (validar factibilidad + comodín) es buena.

### MDA-13 / MOT-08: CONFIRMADO en código, [HIPÓTESIS] en dispositivo (no probado)
- `_jugarEnVivo` llama `_guardar(antes)` antes de abrir el vivo; el resultado se registra solo en `onTerminado` (temporada_pantalla.dart:127-140; igual en escalera.dart:132, epocas.dart:194, armado.dart:213, playoffs_pantalla.dart:114, copa.dart:64). `_terminar` (partido_pantalla.dart:471-478) y `_salir` (481-510) registran, pero matar el proceso no. El ciclo de vida solo pausa (partido_pantalla.dart:211-213). `Liga` usa `Random()` sin semilla (liga.dart:21; main.dart `_liga ??= Liga(...)`).
- Son el mismo hallazgo con dos IDs: conviene fusionarlos. No pude matar un APK real.
- Opinión: MOT-08 dice "rompe la épica del 82-0"; es sobreestimado en un juego sin ranking. MDA-13 lo trata más razonablemente. Subir a medio solo si habrá rankings o códigos de reto competitivos. La alternativa 1 es la mejor.

### MDA-08: CONFIRMADO
- `_fase`/`_marcador` (partidas_pantalla.dart:313-349) manejan amigos, competitivos (`faseCompetitiva`/`marcadorCompetitivo`, competitivo.dart:1326-1364: solo divisiones, conquista y torneos), universitario, extremo perdido, dinastía y el resto cae en `_faseClasica` (Temporada.fase, temporada.dart:293-302). No hay manejo de Escalera (racha, camino, mejores equipos, mundial, escenario), Épocas ni Momentos clutch. El recuento de "9 modos" no lo verifiqué uno por uno.
- Mitigante: la etiqueta de modo sí aparece (línea de `t.modoJuego.nombre`), solo la fase y el marcador son engañosos.
- Opinión: UX menor, bajo. La opción 2 (interfaz `ResumenPartida`) es razonable pero cara; con 1 alcanza.

### CMP-07: CONFIRMADO
- Medí los 120 niveles con `SolucionadorPP.contar` (límite 2): 0 niveles con solución no única. La afirmación de unicidad es cierta.
- El corte por reloj existe en perfil_perfecto.dart:611-613 (`elapsedMilliseconds > 600`). En mi máquina 6-7 niveles superaron 600 ms; el total fue 8,7-11,8 s para los 120. El informe midió 8,8 s.
- Con 60 ms (emulando teléfono 10× más lento) cambian las pistas de 14 de 120 niveles (informe: 15). Ejemplos que coinciden con el informe: 97: 10→17 (informe 10→20), 106: 22→39 (igual), 87: 13→15.
- Dato extra: dos corridas con el límite normal de 600 ms ya difieren en 7 niveles entre sí. Es no determinismo incluso en la misma máquina.
- La generación corre en el hilo principal (presentation/modos/perfil_perfecto.dart:216-217). La congelación de 2-5 s en teléfono es [HIPÓTESIS] (no medible aquí).
- Opinión: severidad media justa solo si importa que "el diario sea igual para todos". La alternativa 1 (presupuesto por evaluaciones) es la mejor; precalcular los 120 niveles también es buena.

### META-08: CONFIRMADO
- `alDia` genera misiones de la fecha y conserva solo las de ids vigentes (misiones.dart:73-82). Test: día 14/11, 6 misiones cumplidas; al pasar a 15/11 00:01 quedan 3 cumplidas sin cobrar de 6 (todas semanales; las 3 diarias desaparecen). Cobrando las 3 diarias de hoy, atrasando el reloj un día y volviendo: 0 diarias reclamadas, progreso [0,0,0] (se pueden volver a cumplir y cobrar).
- El `DateTime.now()` del Desafío del día está en `lib/presentation/modos/variantes.dart:383` (el informe dice `variantes.dart:382`, línea off-by-one y carpeta no explícita). Otro uso: progreso.dart:218 y misiones_pantalla.dart:37.
- No reproduje lo de zonas horarias/DST (5.840 casos).
- Opinión: la pérdida de misiones cumplidas es un bug real de UX. La trampa del reloj es irrelevante sin ranking. Correcta la opción 1 (autocobrar al vencer + `ultimoDia` monótono).

### META-11: CONFIRMADO
- `temporadas()` descarta ilegibles sin aviso (db_local.dart:47-58) y la exportación usa eso (partidas_pantalla.dart:113). La copia entera se arma con `jsonEncode` en el hilo UI (114-120). La importación escribe perfil y ajustes antes que las partidas (165-174), sin transacción. `_guardarImportada` llama `cargarTemporada(id)` sin try (190; db_local.dart:66-69 decodifica y puede tirar), y el `catch` general muestra "El archivo está dañado" con el perfil ya pisado. `'version': 1` es solo del formato; no hay `appVersion`.
- El perfil se valida antes de escribir (fromJson primero, línea ~164): cierto.
- "Unos 10 MB con 50 partidas": no lo medí. El "no valida el tipo" del título es más una consecuencia del `catch` general que una validación ausente concreta.
- Opinión: medio es algo alto para un juego personal; bajo-medio. La opción 1 es correcta.

### ONL-06: PARCIAL
- Cierto: `maxNrOfCacheObjects: 2000` y el comentario que promete "siempre sin internet" (cache_imagenes.dart:3-7); `cacheHeadshots` lo usan jugador_avatar.dart:141, foto_wikipedia.dart:15 y recorte_fotos.dart:45.
- Exagerado: las fotos se piden por `nbaPlayerId` (nba_cdn.dart:3). Medí que el catálogo tiene 11.323 cartas pero solo 4.063 jugadores únicos. El universo real de fotos es ~4.063 objetos (CDN) hasta ~12.000 en el peor caso (Wikipedia, hasta 3 objetos), no 11.323×k. Con 2.000 se desaloja a un usuario con álbum grande, pero "es falso" para casi todos es excesivo.
- No verifiqué que los 404 no se cacheen (depende de flutter_cache_manager) ni los mitigantes de `recortes_v2`.
- Opinión: severidad media sobreestimada. Con 4.063 jugadores, subir a ~5.000 objetos resuelve casi todo, sin tocar 15.000/3 GB como propone.

### CMP-08: CONFIRMADO
- `_album` filtra el catálogo por `coleccion` sin evolución (presentation/modos/armado.dart:1052-1055); `aplicarEvoluciones` solo se usa en `elegir_alineacion.dart:36`. `ModoJuego.usaAlbum` incluye `desafiosArmado` (modo_juego.dart:123), y el doc §4.5 dice que aplica evoluciones. `MediaMinima`/`MediaMaxima` usan `j.media` (domain/modos/armado.dart ~887/896). Es un hallazgo de coherencia, bajo. La recomendada 1 con exclusión de `MediaMaxima` es sensata.

### CAR-11: PARCIAL
- Falso: "`EstadoCarrera.pidioTraspaso` existe pero el toggle solo hace `setState`". El botón (carrera_jugador_pantallas.dart:920-933) hace `setState` y además `_cambiar(_e.copyWith(pidioTraspaso: true, …))`; `_cambiar` llama `widget.onEstado(e)` (563-566), que guarda con `c.guardar` (carrera_jugador.dart:236-239). Al reabrir se inicializa desde lo guardado (`late var _pidioTraspaso = widget.estado.pidioTraspaso`, línea 561). Mismo patrón en "Mejor me quedo" (955-966).
- Cierto: `_paso` es local y arranca en `entrenar` si `cierre == null` (carrera_jugador_pantallas.dart:559).
- Probable pero no ejecutado: `onSiguienteTemporada` recalcula `cerrar(x, e, …)` con la `Temporada` de la pantalla de playoffs (carrera_jugador.dart:197-207; playoffs_pantalla.dart:240), y el receso es una ruta apilada con AppBar, por lo que se puede volver (sin PopScope). Mi lectura respalda que se pisa lo gastado, pero no corrí el escenario.
- Opinión: bajo, de acuerdo. Hay que sacar del hallazgo la parte del traspaso.

### CAR-10: mecanismo CONFIRMADO, datos NO VERIFICABLES
- `masMejorado` se calcula como delta de pts/reb/ast vs. la carta, filtrando solo `pts > ppp` (premios.dart:161-165), sin excluir al MVP (`mvp: base.first`). Un jugador de Mi carrera que sube de 34 a 53 pts y es MVP gana ambos premios.
- `zzlog/mc_lote1.txt` no existe en el commit (ni en /home/user/dinatia-nba), así que las cifras (T5/T6/T12, Robinson T3/T15/T16) no son verificables.
- Opinión: severidad baja correcta. La opción 2 (delta de media, no de puntos) arreglaría la raíz mejor que excluir al MVP.

### META-12: CONFIRMADO (latente)
- main.dart:264-266: `setState(() => _guardada = t)` precede a `if (_liga case final liga?)`. Si `_liga` es null, el diff (`antes` → `t`) nunca se aplica. El efecto hoy es nulo (solo el álbum del draft, recalculado por conjuntos). Es difícil de alcanzar: `_dirigir` dispara `_ligaLista()` desde la elección de regla (main.dart:290). La opción 1 (`await _ligaLista()`) es correcta y trivial.

### MOT-11: CONFIRMADO (seis puntos)
- `_conDesgaste` reconstruye `EquipoPartido` sin `modificadores` (liga.dart:337-345; `modificadores` es campo de `EquipoPartido`, motor.dart:76/94). Confirmado.
- `pPerdida` usa `ataque.equipo.plantel.jugadores.map(...iq).reduce(max)` (motor.dart:720): todo el plantel, incluido el banco. Confirmado.
- Saque: `cuarto++` y luego `if (cuarto == 3) _ataqueLocal = !_ataqueLocal` (motor.dart:~541-543); el 2.º, 4.º y las prórrogas heredan la posesión corriente. Confirmado.
- Lesiones del suplente liberado: `equipo(id) => equipoDe[id] ?? _porId[id]?.franquiciaId` (liga.dart:~417-419): fallback a la franquicia histórica de la carta. Confirmado por lectura.
- Energía 0 sin piso ni cambio forzado: medí 300 partidos con presión alta en ambos equipos: energía mínima 0,0 y 28.847 eventos con algún jugador en cancha con energía 0 (`_fatiga` clampa a 0, motor.dart:1232-1240). Confirmado.
- Determinismo: lo afirmado como [HECHO] es consistente con el código; no lo reproduje por separado, pero en mis corridas con semilla fija los resultados coinciden (misma `Random(1000*rep+i)`).
- Opinión: bajo correcto. De los seis, el de `modificadores` (único capaz de romper un modo) y el de IQ en cancha valen la pena.

## Resumen para quien decide
- Hallazgos graves confirmados: MOT-06 (reproducido y medido), MDA-09 (partida trabada, reproducida), META-08 (pérdida de misiones, reproducida).
- Falso o exagerado: CAR-11 (afirma que el pedido de traspaso no se guarda; sí se guarda), ONL-06 (usa 11.323 cartas cuando las fotos son por jugador: 4.063), MDA-09 ("no hay botón de salida" es falso), MDA-07 (cifras 160/80 no cuadran con 80/40), MOT-08/MDA-13 (duplicados; la severidad "rompe la épica" es exagerada).
- No verificables aquí: dispositivo real (MDA-13, MOT-08, congelación de CMP-07), zzlog de CAR-10 (archivo ausente), peso de 10 MB de la copia (META-11).
