# Verificación A1a: Área 1 (líneas 112 a 400 de la auditoría externa)

Copia de trabajo: `/tmp/claude-0/-home-user/b2ab324b-7311-5a2f-a1eb-f08ab7cbaa11/scratchpad/wt/A1a` (commit c453f39). Tests temporales `test/zz_verif_*.dart` ya borrados. No se commiteó nada.

Aclaración general: los números de línea del informe están corridos entre 1 y 15 líneas respecto del commit c453f39. Por ejemplo, `_guardarImportada` está en `partidas_pantalla.dart:201-206` y no en 188-192, y `fotoWikipedia` usa `getSingleFile` en `foto_wikipedia.dart:17-20` y no en 22-25. El mecanismo descrito es el correcto en todos los casos. No lo trato como error del informe.

## Tabla

| ID | Veredicto | Sev. informe | Sev. mía | Evidencia (una línea) |
|---|---|---|---|---|
| META-01 | CONFIRMADO (mecanismo, por código; el disparador depende del caso) | crítico | alto (crítico solo si pasa; probabilidad baja) | `main.dart:49-56` un solo try; `db_local.dart:72-75` `ultimaTemporada` sin `_intentar`; `progreso.dart:224` siempre perfil nuevo |
| CAR-04 | CONFIRMADO | alto (raro) | medio (ventana de milisegundos) | `carrera.dart:225-227` y `carrera_jugador.dart:251-254` hacen delete y luego guardar |
| META-03 | CONFIRMADO (por código) | alto | alto | `dinastia.dart:911` y `carrera_jugador.dart:1940` ids `raiz-tN`; import no toca `raiz`; `db_local.dart:64` replace |
| UX-01 | CONFIRMADO | alto | alto | `inicio_pantalla.dart:225-294` `_BarraCarrera.build` no usa `onAlbum`; `AlbumPantalla(` solo en `main.dart:180` |
| META-02 | CONFIRMADO (reproducido con las mismas cifras) | alto | alto | Test: tras cierre xp=5035 monedas=1901 trofeos=19; tras 3 reimportaciones xp=6935, trofeos=76, historial=4 |
| META-04 | CONFIRMADO | alto | alto en teoría, medio en práctica (solo se dispara al renombrar enums o con datos de otra versión) | Test: dificultad, regla, modo draft, trofeo futuro dan ArgumentError; xp double da TypeError; `modoJuego` futuro cae a clasico |
| META-05 | CONFIRMADO | alto | medio-alto | `progreso.dart:62-70` retornos tempranos; test Divisiones: xp 0 a 300, puntosPase=0 |
| CMP-02 | CONFIRMADO (duplica META-05) | alto | medio-alto | Test: 10 victorias en Divisiones, evolución "partidos" progreso=0 |
| MDA-01 | CONFIRMADO (mecanismo); cifras exactas no reproducidas | alto (crítico con ranking) | medio hoy (no hay ranking) | `variantes.dart:264-270` no mira el id; test: marca 5 sube a 29 con una copia de id distinto |
| MDA-02 | CONFIRMADO (reproducido) | alto | medio-alto | Test: ruleta reabriendo da CLE/2000s/a y vuelve a CLE/2000s/a con la ficha 3 a 2; sin cerrar da IND/actualidad/a |
| MDA-03 | CONFIRMADO | alto | medio-alto (decisión de diseño) | `progreso_escalera.dart:66-75` no excluye temporadaReal ni queHubiera; test: álbum +6 con Jordan y Pippen |
| ONL-01 | CONFIRMADO el mecanismo; alcance NO VERIFICABLE | alto | alto (impacto medio) | `cache_manager.dart:76-80` getSingleFile lanza sin red; `cache-control: ... max-age=300` medido hoy con curl |
| CAR-03 | CONFIRMADO | alto | medio-alto | `universitario.dart:545-555` `comoCreado` pierde atributos; test: egresado media 99 pasa a 70 |
| META-06 | CONFIRMADO (por código) | medio-alto | medio | `main.dart:271` `.ignore()` y `:276` por separado; `partidas_pantalla.dart:168-174` perfil escrito antes de validar partidas |

## Detalle

### META-01: CONFIRMADO
- `lib/main.dart:49-56`: `db = await DbLocal.abrir(); guardada = await db.ultimaTemporada();` y luego ajustes y perfil, todo en un solo `try`. Si `ultimaTemporada()` lanza, se salta la lectura del perfil. `db` queda asignada y `perfilApp` queda como `const PerfilEntrenador()`.
- `db_local.dart:72-75`: `ultimaTemporada` hace `_decodificar` sin atrapar. `temporadas()` (l. 48-52) usa `_intentar` y oculta la fila dañada, así que la partida no se puede ver ni borrar. Sigue siendo la más reciente, y el arranque falla otra vez.
- `progreso.dart:224`: `p.copyWith(metajuego: ...)` siempre devuelve un objeto nuevo. Mi test lo confirmó: `identical(resultado, const PerfilEntrenador())` da false aun con antes==después. Entonces `main.dart:268-271` (`!identical` y luego `escribir('perfil')`) escribe en cada guardado. Tras 1 partido sobre perfil vacío: xp=130, que es lo que pisaría el perfil real.
- Otros escritores del perfil además de `_guardarCambios`: `Misiones.initState` (`misiones_pantalla.dart:33-40`), Vestuario y Desafío del día (`variantes.dart` escribe el perfil al crear). Hay 7 llamadas a `escribir('perfil'`.
- Se verificó por lectura que el enum desconocido lanza: `Temporada.fromJson` con dificultad "pesadilla" da ArgumentError (ver META-04). No pude correr SQLite real: no hay `sqflite_common_ffi` en `pubspec.yaml`. El informe dice haber usado ffi. La cadena de código es lineal y no deja dudas.
- Opinión: la severidad "crítico" es justa por el impacto (pérdida total del perfil), pero la probabilidad es baja. Hace falta una partida ilegible que sea la más reciente. Es real tras un downgrade o un renombre de enum. La corrección 1 (try separados) más 3 (`ultimaTemporada` tolerante) es la mejor y es barata. El respaldo rotativo (alternativa 3) también vale la pena.

### CAR-04: CONFIRMADO
- `presentation/modos/carrera.dart:224-227`: `await c.db?.borrarTemporada(t.id)` envuelto en try/catch vacío, y después `await c.guardar(nueva)`. En `carrera_jugador.dart:250-254` es idéntico. No hay transacción.
- Peor que lo descrito: si el `delete` tiene éxito y el `guardarTemporada` falla, `_guardarCambios` (`main.dart:274-280`) solo muestra un SnackBar y la vieja ya no está.
- La ventana real es de milisegundos (dos operaciones SQLite seguidas), y de ahí el "raro" del informe. Yo bajaría la severidad a medio. La corrección propuesta es buena (`reemplazarTemporada` con transacción). Con solo invertir el orden ya alcanza como mínimo.

### META-03: CONFIRMADO (por código; el informe admite que no lo reprodujo de punta a punta)
- `dinastia.dart:911` usa `'${estado.raiz}-t${estado.numero + 1}'` y `carrera_jugador.dart:1940` usa `'${e.raiz}-t$numero'`.
- `partidas_pantalla.dart:201-206` solo cambia `datos['id']` y deja `datosModo['raiz']`.
- `db_local.dart:64` usa `ConflictAlgorithm.replace`.
- La secuencia descrita se sigue del código: la copia y la original generan el mismo `R-t3`, la segunda escritura pisa a la primera. Me faltó una reproducción con UI (receso). Lo veo sin fisuras en el código.
- "Importar copia completa" en el mismo teléfono agrava el caso: todas las partidas existentes se duplican con id nuevo y la misma raíz.
- Opinión: severidad alta justa (pérdida de partida), aunque exige un flujo poco común (importar una partida propia y avanzar ambas). La corrección 1 + 2 es la mejor.

### UX-01: CONFIRMADO
- `inicio_pantalla.dart:28,44,80,214,218` declara y reenvía `onAlbum`. `_BarraCarrera.build` (l. 225-294) solo dibuja píldora, Misiones, Partidas y Ajustes.
- `grep AlbumPantalla(` solo da `main.dart:180`. No hay otra entrada (Perfil, Misiones, modos). Los modos solo muestran textos que remiten a "la tienda" (`armado.dart:1130`, `elegir_modo.dart:74`).
- `git log -S"onAlbum" -- inicio_pantalla.dart` devuelve únicamente a8236c7 (el commit que lo introdujo). Nunca hubo botón.
- Es la mejor noticia/peor noticia del tramo: la mitad del metajuego (álbum, tienda, evoluciones) queda inaccesible. Severidad alta justa. Quizás conviene "crítico" por impacto en el producto, pero es un arreglo de 1 línea.

### META-02: CONFIRMADO (reproducido con las mismas cifras del informe)
- Test sobre la temporada completa de CHI. Salida: `META02 tras cierre original: xp=5035 monedas=1901 historial=1 trofeos=19`. Es la misma línea que cita el informe ("Tras jugar: xp=5035 monedas=1901 trofeos=19 historial=1").
- Luego 3 importaciones con id nuevo y 1 guardado cada una (`aplicar(perfil, copia, copia)`): `xp=6935 monedas=2701 historial=4 trofeos=76 cerradas=4`. Cada copia paga una temporada completa más (+630 xp, +267 monedas, +19 trofeos).
- Causa: `progreso.dart:203` solo protege con `temporadasCerradas.contains(despues.id)`; el id nuevo no está en el conjunto.
- La duplicación en "copia completa" está en `partidas_pantalla.dart:201-206` (id existente da id nuevo).
- Opinión: severidad alta justa mientras no haya ranking. La alternativa 1 (importada = de exhibición) es la más simple. Ojo con que `Progreso.aplicar` no distingue hoy partidas importadas; hace falta un flag o `origenId`.

### META-04: CONFIRMADO
Salida de mi test (JSON generado con `toJson` y mutado):
```
modoJuego futuro "hazanas"  -> ModoJuego.clasico        (degrada en silencio)
dificultad futura           -> EXCEPCION ArgumentError
regla futura                -> EXCEPCION ArgumentError
modo draft futuro           -> EXCEPCION ArgumentError
perfil vacio {}             -> OK
trofeo futuro               -> EXCEPCION ArgumentError
xp double (1.0)             -> EXCEPCION _TypeError
logro inexistente           -> OK (se descarta)
calendario ausente          -> EXCEPCION _TypeError
calendario null             -> EXCEPCION _TypeError
id numerico                 -> EXCEPCION _TypeError
```
- Código: `temporada.dart:493-495` usan `byName`; `temporada.dart:505` usa `asNameMap()[...] ?? clasico`; `temporada.dart:532` solo escribe `modoJuego` si no es clasico (se pierde el modo original); `perfil.dart:103` y `metajuego.dart:56` usan `byName`.
- Matiz: "calendario ausente" da TypeError, lo que el informe agrupa con "null/ausente". Ojo, esto es un JSON mutado a mano: una partida real guardada siempre trae el campo. El disparador real son los renombres de enum, que son un riesgo de refactor y no de uso normal.
- Opinión: alto es razonable como riesgo de mantenimiento; el test de nombres congelados (alternativa 3) es muy barato y la mejor defensa.

### META-05 y CMP-02: CONFIRMADOS (se solapan casi del todo)
- `progreso.dart:62-70`: los 5 desvíos (amigos, armado, competitivo, universitario, fantasy) hacen `return` antes de `avanzarEvoluciones` (l. 212), `Misiones.cobrarPendientes()` (l. 216) y el pase (l. 224).
- Medición propia con Divisiones (10 victorias, evolución "partidos" a 0): `xp 0->300 monedas 0->100 evo progreso=0 puntosPase=0 novedades=[+300 XP · +100 monedas]`. Hay XP suficiente para nivel 2 y aun así no hay aviso de nivel. Es lo que dice el informe.
- `Misiones.anotar(ganarDesafio)` se llama desde `competitivo.dart:139,509` y `torneos.dart:631`. La cola es estática (`misiones.dart:14`), no persiste, y solo la vacía el próximo `aplicar` que pase por el camino común (`progreso.dart:216`).
- Matiz importante sobre el número: "9 modos" de CMP-02 es correcto (draftEnGrupo, duelo, topeSalarial, ligaIA, 3 competitivos, universitario, fantasy). Pero de los 5 modos de `usaAlbum` (`modo_juego.dart:123`), `desafiosArmado` NO entra en un desvío (no es `esPartidaArmada`), así que sí avanza. El informe lo dice bien: nombra solo Divisiones, Conquista, Creador y Fantasy como afectados.
- El informe afirma que TRASPASO §11 dice "el progreso se gana jugando en cualquier modo": está literalmente en `docs/TRASPASO_COMPLETO.md:343`. La contradicción es real.
- CMP-02 agrega que `avanzarEvoluciones` lee `calendario` y `lineas`, que esos modos no usan: cierto, por eso no basta con quitar el `return`; hay que usar el enfoque "registrarEvolucion por victorias/partidos".
- Opinión: META-05 y CMP-02 son el mismo defecto; la severidad es media-alta (es la mitad del metajuego diario, no destruye datos). La recomendación 1 es correcta pero M, no S: ojo con el doble premio (misiones y pase se pagan por diferencia).

### MDA-01: CONFIRMADO el mecanismo; cifras exactas no reproducidas
- `variantes.dart:264-270` (dominio): `premiarVariante` solo mira `modoJuego == desafioDelDia` y `datosModo['semilla']`, y guarda la marca si `v > marca`. No comprueba que el id sea `dia-aaaammdd`.
- Test: perfil con marca 5; copia de la temporada con id `1731590000000000` jugada hasta el final; `aplicar` deja `desafiosDelDia['20261114'] = 29`. Con la marca del informe (30) y mi copia de 29 victorias no se supera; el informe usó 69-13 y no pude replicar la misma simulación. El mecanismo es el mismo.
- "Importar copia completa" reemplaza el perfil (`partidas_pantalla.dart:165-172`) y puede borrar el registro del día. Ver código: sí, y `_desafioDelDia` (`presentation/modos/variantes.dart:383-398`) solo bloquea por id y por marca del perfil.
- Opinión: sin ranking es trampa solo contra uno mismo; el informe ya lo califica así. Alto es un poco generoso hoy; medio.

### MDA-02: CONFIRMADO (reproducido)
- `presentation/modos/variantes.dart:82` pasa `azar: Variantes.azarDraftDelDia(t)` (un Random por pantalla), y `domain/variantes.dart:192-193` siembra con `semilla*31 + jugadores*7919 + rerollsRestantes`.
- Mi test, con `Draft.tirar` y ruleta, mismo desafío:
```
A (sin cerrar):   CLE/2000s/a -> IND/actualidad/a -> NOP/2000s/b    fichas 3->3->2->1
B (reabre cada vez): CLE/2000s/a -> CLE/2000s/a -> MIL/2010s/a      fichas 3->2->1
```
  Reabrir y volver a tirar repite la tirada anterior y gasta una ficha. Y dos jugadores con las mismas decisiones ven secuencias distintas. La promesa "Mismas tiradas... para todos" (`presentation/modos/variantes.dart`, texto del intro) es falsa en cuanto alguien cierra la app.
- Las tiradas concretas difieren de las del informe (DEN/80s), porque el catálogo/versión de la semilla no es el mismo: yo usé la semilla 20261114 sin `versionCatalogo`. El comportamiento es idéntico.
- No probé el modo cartas (sobres); el código del azar es el mismo `azarDraftDelDia`.
- Opinión: la corrección propuesta (`azarPara` por paso, como los retos) es la mejor. Severidad media-alta: afecta la equidad del desafío, no los datos.

### MDA-03: CONFIRMADO
- `progreso.dart:75-76` suma el plantel al álbum si `sumaAlAlbum(despues)`. `progreso_escalera.dart:66-75` solo excluye escenario, leyendaUnica, soloEntrenador, guantelete, camadas y universidades.
- Test: `HistoriaNba.nuevaTemporada(CHI, 1996)` más `iniciarLiga` (confirmar tácticas) y `aplicar`: `sumaAlAlbum(temporadaReal)=true coleccion=6 -> [Ron Harper, Dennis Rodman, Luc Longley, Michael Jordan, Scottie Pippen, Toni Kukoč]`. También `sumaAlAlbum(queHubiera)=true` y `espejo=true`. Coincide con la lista del informe.
- TRASPASO `docs/TRASPASO_COMPLETO.md:281,338` dice que se excluyen escenarios, Leyenda única y Solo entrenador, y "modos con plantel prestado/ficticio no suma". El plantel de Temporada real es prestado, así que el comportamiento contradice la intención documentada.
- Matiz: es un hueco de diseño más que un bug de código. `espejo` no lo probé a fondo: en ese modo el plantel del usuario sale de su propio draft según el informe. Mi test solo muestra que `sumaAlAlbum` da true.
- Opinión: severidad alta es defendible por el impacto en la economía del álbum. La corrección (agregar los dos modos al set) es de una línea.

### ONL-01: CONFIRMADO el mecanismo; el alcance (3.000-4.000 cartas) NO VERIFICABLE
- `foto_wikipedia.dart:17-20` llama `cacheHeadshots.getSingleFile(url, ...)`. `catch (_)` (l. 28) traga el error y la función devuelve null.
- Fuente de la librería (`flutter_cache_manager-3.5.0/lib/src/cache_manager.dart:76-80`): `getSingleFile` devuelve el archivo solo si `validTill` es futuro; si no, `downloadFile`, que lanza sin red. `web/file_service.dart` calcula `validTill` desde `max-age` (7 días por defecto).
- Medición propia hoy: `curl -I https://en.wikipedia.org/api/rest_v1/page/summary/Michael_Jordan` da `cache-control: s-maxage=1209600, max-age=300`. Coincide con el informe.
- `cache_imagenes.dart` fija `stalePeriod` de 10 años, pero eso solo afecta a la limpieza; no cambia `validTill`. Por eso el comentario del archivo ("funciona siempre sin internet") es falso para este JSON.
- `_resueltas` (`foto_wikipedia.dart:5`) memoiza el Future con null por sesión: cierto.
- No pude correr el test con cliente HTTP simulado (el informe lo cita, `zz_auditoria_online_cache_test.dart`, no está en el repo) ni medir las 8 de 15 cartas contra Basketball-Reference. Dependen de red y de datos externos.
- Opinión: severidad alta justa si el juego quiere funcionar sin internet. La corrección 1 (leer primero `getFileFromCache` aunque esté vencido) es la mejor y mínima.

### CAR-03: CONFIRMADO
- `Egresado.comoCreado` (`universitario.dart:545-555`) arma un `JugadorCreado` con puesto, rol, 3 fuertes, altura y peso; `JugadorCreado.atributos` (`carrera_jugador.dart:413-419`) recalcula desde el arquetipo a 58,5. `iniciarCarreraJugador(creadoInicial:)` (`presentation/modos/carrera_jugador.dart:93-123`) vuelve a correr `carrera.combine` y toma el pick del combine nuevo; `estadoCreado` arranca con `edad = 20`.
- Medición propia (egresado con atributos de perfil 84, pick 1): `egresado media=99 -> comoCreado.media=70`. Con los valores del informe (89 a 69) la pérdida es del mismo orden.
- No leí `zzlog/univ.txt` (no está en el repo) pero el mecanismo es inequívoco.
- Opinión: severidad alta es un poco generosa: es una integración de dos modos, sin pérdida de datos. Medio-alto. La corrección 1 + 2 (atributos fijos con descuento y pick real) es buena.

### META-06: CONFIRMADO (por código)
- `main.dart:271`: `widget.db?.escribir('perfil', perfil.toJson()).ignore();` y `main.dart:276`: `await widget.db?.guardarTemporada(t)` por separado. Sin transacción.
- `partidas_pantalla.dart:168-174`: `db.escribir('perfil')` y `db.escribir('ajustes')` y `perfilApp.value = ...` ocurren antes del bucle de `_guardarImportada`. Si una partida falla en `Temporada.fromJson`, el perfil ya fue reemplazado y solo se avisa "dañado".
- El informe marca la frecuencia como [HIPÓTESIS] y reconoce que no hay carreras de orden; coincido. No lo reproduje (no es reproducible sin matar el proceso).
- Opinión: medio es lo justo. La corrección (`guardarTodo` con `transaction`) es la correcta. El valor práctico más inmediato es validar todas las partidas antes de tocar el perfil en la importación.

## Resumen de exageraciones o imprecisiones
- Ninguna afirmación del tramo resultó falsa. Los hallazgos reproducibles (META-02, META-04, MDA-02, MDA-03, META-05/CMP-02, CAR-03) dieron el comportamiento descrito; META-02 con las mismas cifras exactas.
- Severidad algo inflada: CAR-04 (ventana de milisegundos), MDA-01 (sin ranking solo es trampa propia), CAR-03 (integración entre modos, sin pérdida de datos), META-01 (crítico por impacto, pero con probabilidad baja).
- META-05 y CMP-02 son el mismo defecto contado dos veces.
- Líneas de referencia del informe corridas de 1 a 15 líneas respecto del commit auditado (no cambia ninguna conclusión).
- No verificables aquí: alcance cuantitativo de ONL-01 (cartas dependientes de Wikipedia) y SQLite real en META-01 (falta `sqflite_common_ffi`).
