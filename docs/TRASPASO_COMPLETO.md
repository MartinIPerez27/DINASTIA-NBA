# Dinastía NBA (82-0): documento de traspaso completo

Este documento existe para **continuar el proyecto en otro chat** sin perder contexto. Reemplaza y amplía a `docs/ESTADO_DEL_PROYECTO.md` (que quedó en el build 24) y a `docs/AUDITORIA_PROPIA.md` (auditoría del catálogo, ya aplicada en gran parte).

- **Fecha de escritura:** 2026-11-14.
- **Último commit en `main`:** `f276184` ("Modos v3: 20 modos nuevos…"), **build 26** del APK.
- **Repositorio:** `MartinIPerez27/DINASTIA-NBA` (público), rama `main`. Directorio de trabajo en la sesión: `/home/user/dinatia-nba`.
- **Estado de verificación al escribirlo:** `flutter analyze` sin issues, `flutter test` 322 pruebas pasando, `python3 -m unittest discover tools` OK. **Nada se probó en un dispositivo Android real** (ver §20).

---

## 0. Cómo usar este documento en un chat nuevo

1. Pegá este archivo completo al empezar el chat y pedí que lo lea antes de tocar nada.
2. Pedí que corra, en este orden, para confirmar el estado: `flutter pub get`, `flutter analyze`, `flutter test` (≈1 min por la suite grande, hasta ~2 min si hay mucha carga) y `git log --oneline -5`.
3. Las **reglas del usuario** (§1) y el **modo de trabajo** (§2) son parte del contrato: hay que respetarlas igual que el código.

---

## 1. El usuario, sus preferencias y reglas estables

### 1.1 Qué es el proyecto
Un juego **personal, gratuito y 100 % offline** para Android hecho en Flutter. Un "roguelike de draft" + simulador de temporada NBA: se arma un plantel de 6 cartas (5 titulares + Sexto Hombre), se eligen tácticas y se juega una temporada de 82 partidos y playoffs. El objetivo simbólico es el **82-0**. Sobre eso se construyeron 34 modos de juego y un metajuego (XP, monedas, álbum, misiones, pase, cosméticos).

### 1.2 Preferencias del usuario (respetar siempre)
- **Idioma:** español rioplatense con **voseo** ("elegí", "tocá", "jugá") en toda la UI y en las respuestas. Las respuestas en el chat van en voseo, claras y directas.
- **Estilo visual "El Marcador":** tablero LED de estadio, fondo mate oscuro (`#0F1012`), tipografías Doto (puntos LED) y Big Shoulders Display. Detalle en `DESIGN.md` y `PRODUCT.md`. Reglas clave de `DESIGN.md`: números LED con "dígito fantasma" (usar `TextoLed`/`CeldaLed`), **sin sombras** (`BoxShadow` prohibido), contraste ≥ 4,5:1.
- **100 % gratis y offline:** sin APIs pagas, sin cuentas, sin analítica, sin servidor propio. La única red es la descarga de fotos/escudos (CDN de la NBA, Basketball-Reference, Wikipedia/Wikimedia) con caché en disco.
- **Privacidad:** el email del usuario es privado. Nunca se manda a servicios externos (ni en User-Agent, ni en URLs, ni en payloads).
- **Tablet:** el usuario tiene una **BMAX Power 11,4" 2K, horizontal**, pero **no la tiene a mano** para probar: confía en que quedó bien. Los teléfonos deben seguir funcionando igual en vertical.
- **Decisiones explícitas del usuario que no se deben revertir:**
  - **Dorsales:** o los tienen todas las cartas o ninguna. Hoy **ninguna** (se quitaron de toda la UI: el catálogo solo los tenía en 15 de 11.323 cartas).
  - **Narrador:** texto + voz opcional.
  - **Colección:** las evoluciones de cartas afectan **solo** a los modos que usan el álbum.
  - **Cada tramo es su propia carta:** "Lillard de Bucks no es el de Portland, así la lógica con todos los equipos". Cada carta = jugador + franquicia + década y debe mostrar su tramo real de temporadas ("MIL 2024–25", "POR 2020–23").
  - El **Tope salarial** se había descartado una vez, pero el usuario lo **pidió después** explícitamente: está implementado.
- **Dificultad:** pidió que Difícil sea "más duro" (se subió la media objetivo de rivales).
- **Lo que le gusta:** profundidad, inmersión ("que lo que yo haga influya"), modos inspirados en EA FC, NBA 2K, Retro Bowl, Fantasy (ESPN / El Gran DT), SBC de FIFA y el puzzle "Profile Perfect". Pide que se le **sugieran modos nuevos** y que **valide ideas antes de programarlas**.

### 1.3 Reglas de entrega (del usuario y del entorno)
- **Commits** terminan con las líneas de atribución que dé el `system-reminder` de la sesión (en esta sesión: `Co-Authored-By: ...` y `Claude-Session: https://claude.ai/code/session_012r9VTC3Dt4fbUwjtMaaJ5J`). No poner identificadores de modelo en código, comentarios ni títulos de PR.
- **No crear PRs** salvo que el usuario lo pida. Se empuja directo a `main` (repo personal).
- **Cada push a `main` dispara la CI** que compila y publica el APK en Releases: no empujar features a medias a `main`.
- **Entregables:** al terminar una tanda se manda el **APK** (`build/app/outputs/flutter-apk/app-release.apk`) y capturas con `SendUserFile`, más un resumen en voseo.
- El usuario subió documentos a otros chats para **auditoría externa** (Gemini). Se contrastó punto por punto en `docs/AUDITORIA_PROPIA.md`.

---

## 2. Modo de trabajo (lecciones aprendidas, importante)

### 2.1 Agentes en paralelo ("forks")
Se trabajó repartiendo features grandes entre **forks** (subagentes que heredan contexto) que editan el **mismo árbol de trabajo a la vez**. Lo que funcionó:
- Un **base común** que se deja armado antes de repartir: enums (`ModoJuego`), puntos de entrada (stubs en `lib/presentation/modos/*.dart`), el despacho en `modos.dart`. Cada fork reemplaza **su** stub.
- Reglas en cada prompt: "archivos compartidos (`motor.dart`, `liga.dart`, `perfil.dart`, `progreso.dart`, `temporada.dart`, `modos.dart`, `modo_juego.dart`, `main.dart`) se editan **mínimo y aditivo**, releyendo justo antes de cada edición"; "no commit, no push, no APK"; "`dart format` solo en tus archivos (ancho 120)".
- **Nunca usar `git stash`, `git checkout` ni nada que reescriba el árbol** mientras hay forks activos. Un fork lo hizo y hubo que restaurar a mano (se verificó después que los enganches siguieron en su lugar).
- Las ediciones concurrentes pueden **perder una línea** de otro fork. Al integrar, verificar con `grep` que sigan los enganches de `progreso.dart` (`avanzarEvoluciones`, `premiarFantasy`, `premiarCompetitivo`, `premiarUniversitario`, `premiarVariante`), `liga.dart` (`nivelEvolucion`) y `main.dart`.

### 2.2 El "stop hook" y las ramas WIP
Un hook exige "commitear y pushear" cuando hay cambios sin commitear. Con forks a mitad de trabajo no se puede empujar a `main`. Patrón usado: **instantánea a una rama WIP temporal** sin tocar el índice real:
```bash
export GIT_INDEX_FILE=/ruta/scratch/idxN; rm -f $GIT_INDEX_FILE
git read-tree HEAD && git add -A && tree=$(git write-tree)
c=$(git commit-tree $tree -p HEAD -m "…(en curso)…")
unset GIT_INDEX_FILE
git push -q -f origin $c:refs/heads/NOMBRE-wip
```
Al terminar: se integra en una rama de feature (`tanda-N`, `modos-v3`…), se prueba todo y se hace **fast-forward a `main`**.

### 2.3 Límites de uso de la API
Los agentes se cortan con "5-hour limit" (error 429). **Su trabajo queda guardado**: se retoman con `SendMessage` al `agentId` cuando pasa la hora de reinicio. Pasó dos veces.

### 2.4 Rutina de cierre de una tanda
1. `flutter analyze` limpio. 2. `flutter test` completo. 3. Si cambió el motor o las medias: `flutter test test/balance_test.dart` y recalibrar. 4. Regenerar capturas (`flutter test --update-goldens capturas/<archivo>_test.dart`) y **mirarlas** (desbordes). 5. Actualizar `ROADMAP.md`. 6. `flutter build apk --release --target-platform android-arm,android-arm64 --build-number=N`. 7. Commit con atribución, push, fast-forward a `main`. 8. `SendUserFile` con APK + capturas y resumen.

---

## 3. Entorno, herramientas y comandos

- **Flutter 3.47.9 / Dart 3.13.7** en `/opt/flutter/bin` (agregar al `PATH`). Java 17 para el APK. Corre como root (Flutter avisa; ignorar).
- **Cloud container** efímero: lo que importa debe quedar commiteado y pusheado.
- **Comandos:**
  ```bash
  export PATH=/opt/flutter/bin:$PATH
  flutter pub get
  flutter analyze
  timeout 590 flutter test                      # suite completa
  flutter test --update-goldens capturas/X_test.dart   # capturas con fuentes reales → capturas/salida/*.png (gitignored)
  python3 -m unittest discover tools            # tests Python del pipeline
  flutter build apk --release --target-platform android-arm,android-arm64 --build-number=N
  dart format --page-width 120 <archivos propios>
  ```
- **CI** (`.github/workflows/apk.yml`): en cada push a `main` corre analyze + tests Flutter + tests Python, compila el APK y lo publica en el Release `ultima`. Descarga directa: `https://github.com/MartinIPerez27/DINASTIA-NBA/releases/download/ultima/dinastia-nba.apk`. El número de build real lo pone la CI (`--build-number=${{ github.run_number }}`); `pubspec.yaml` dice `0.1.0+1`.
- **Capturas golden:** son tests en `capturas/*_test.dart` que cargan las fuentes reales (Roboto, Doto, Big Shoulders, MaterialIcons) y escriben PNG en `capturas/salida/`. **No corren en la CI** (necesitan las fuentes del SDK). Hay 31 archivos de captura.
- **Python:** el pipeline de datos usa `nba_api` (`pip install nba_api`), `rembg`, `opencv-python-headless<5` (OpenCV 5 no tiene `CascadeClassifier`), `Pillow`, `numpy`. Los CSV se cachean en `tools/.cache/` (gitignored).
- **GitHub desde la sesión:** `gh api` REST funciona; GraphQL no. `gh release view` falla (usa GraphQL). El borrado de ramas remotas (`git push origin :refs/heads/X`) lo bloqueó el clasificador de permisos una vez: se deja al usuario.
- **Web:** `WebSearch` es solo EE. UU.; la ficha de Google Play de "Profile Perfect" no cargó con `WebFetch` (página dinámica).

---

## 4. Arquitectura

### 4.1 Capas
- `lib/domain/`: **Dart puro**, sin Flutter. Reglas, motor de partido, liga, draft, modos, metajuego. Todo testeable sin UI.
- `lib/data/`: catálogo (`catalogo_jugadores.dart`), franquicias (`franquicias.dart`), base local SQLite (`db_local.dart`), estado global de la app (`estado_app.dart`: `perfilApp` y `ajustesApp` como `ValueNotifier`), datos curados de historia NBA (`historia_nba.dart`, generado).
- `lib/presentation/`: pantallas, widgets, partido en vivo (`partido/`), draft (`draft/`), modos (`modos/`), temporada (`temporada/`), compartir (`compartir/`), tema (`tema/`).
- `lib/core/`: caché de imágenes, foto de Wikipedia, URLs del CDN de la NBA, recorte de fondo de fotos (ML Kit).
- **Tamaño:** 125 archivos Dart, ~51.900 líneas en `lib/`; 44 archivos de test; 31 de capturas.

### 4.2 Archivos más grandes (candidatos a dividir)
`domain/modos/carrera_jugador.dart` (1.968), `domain/modos/universitario.dart` (1.561), `domain/modos/escalera.dart` (1.401), `domain/modos/competitivo.dart` (1.364), `domain/motor.dart` (1.333), `domain/modos/armado.dart` (1.280), `presentation/pantallas/partido_pantalla.dart` (~1.900).

### 4.3 Flujo de la app (`lib/main.dart`)
- `DinastiaNbaApp` mantiene la `Liga` única (`_ligaLista()`), el `ContextoModos` (`_modos`) y la partida guardada. Carga perfil/ajustes/última temporada de SQLite al arrancar.
- `_abrirTemporada(t)`: primero consulta `pantallaDeModo(t, _modos)` (los modos); si devuelve `null`, usa `_pantallaClasica(t)` según `t.fase` (`draft` → `tacticas` → `temporadaRegular` → `playoffs`/`finalizada`).
- `_guardarCambios(t)`: guarda **y aplica el metajuego** (`Progreso(liga).aplicar(perfilApp.value, antes, t)`), muestra avisos (overlay, nunca encolados) y sella la versión del catálogo.
- `_dirigir(franquicia)`: flujo del modo clásico (modo de draft → regla → dificultad); a cada partida clásica nueva le pone semilla y fichas en `datosModo` (para el código de reto).
- `_abrirModos()` abre `ModosPantalla` → `iniciarModo(modo, enfocada, _modos)`.
- `_confirmarTacticas` arma el calendario y rivales con `liga.iniciar(t)` solo si `t.modoJuego.usaTemporada` (los demás modos arman lo suyo).

### 4.4 `Temporada` (la partida guardada, `domain/entities/temporada.dart`)
Todo se serializa a JSON (`toJson`/`fromJson`); **los campos nuevos son opcionales y se escriben solo si no están vacíos**, y se leen con valor por defecto (retrocompatible). Campos: `id`, `franquiciaUsuarioId`, `plantel`, `tactica`, `rerollsRestantes`, `calendario`, `series` (playoffs), `tirada`/`oferta` (draft en curso), `tacticaConfirmada`, `modo` (`ModoDraft`: ruleta/cartas), `rivales`, `lineas`/`lineasPlayoffs` (estadísticas), `dificultad`, `regla` + `epocaRegla`, `robos` (serpiente), `entrenadorId`, `forma`, `suplentes`, `lesiones`, `pases`, `copa`, `modoJuego`, `datosModo` (mapa JSON libre, estado propio de cada modo), `allStar`, `versionCatalogo`. `fase` se deduce del estado.

### 4.5 Sistema de modos
- `ModoJuego` (`domain/entities/modo_juego.dart`): enum con 34 valores. Cada uno tiene `grupo` (`GrupoModo`), `nombre`, `descripcion`. Getters: `usaTemporada` (¿arma el calendario de 82?) y `usaAlbum` (¿usa cartas del álbum, y por lo tanto aplica evoluciones?: `desafiosArmado, divisiones, creadorTorneos, conquista, fantasy`).
- `lib/presentation/modos/modos.dart`:
  - `ContextoModos`: lo que la app le presta a cada modo: `liga()`, `db`, `navegador`, `guardar(t)` (guarda + metajuego), `abrirTemporada(t, {reemplazar})`, `nuevoId()`.
  - `iniciarModo(...)`: despacha por modo/grupo a `iniciarEscalera / iniciarVariante / iniciarCarrera / iniciarReto / iniciarAmigos / iniciarHistoria / iniciarEpocas / iniciarArmado / iniciarCarreraJugador / iniciarUniversitario / iniciarCompetitivo / iniciarFantasy / iniciarPerfilPerfecto`.
  - `pantallaDeModo(t, c)`: devuelve la pantalla propia del modo para una partida guardada (o `null` si sigue el flujo clásico en esa fase).
  - `ModosPantalla`: menú agrupado con íconos (`ModosPantalla.icono`).
- **Para agregar un modo nuevo:** (1) valor en `ModoJuego` + ícono en `ModosPantalla.icono`; (2) `usaTemporada`/`usaAlbum` según corresponda; (3) predicado `esModoX` + `iniciarX` + `pantallaX` en su archivo de `presentation/modos/`; (4) enganchar en `iniciarModo` y `pantallaDeModo`; (5) premios en `Progreso.aplicar` (aditivo); (6) etiqueta de fase y marcador en `partidas_pantalla.dart` (`_fase`, `_marcador`); (7) tests y captura.

---

## 5. Datos

### 5.1 Catálogo de cartas (`assets/database/nba_players.json`, ~4 MB)
- **11.323 cartas.** Una carta = jugador + franquicia + **década** (con mínimo de 20 partidos en ese tramo). **IDs estables** (`pid-FRANQUICIA-codigoEpoca`, p. ej. `lillada01-POR-act`): **no se deben cambiar ni borrar** (partidas guardadas, álbum y rivales los referencian).
- **Campos por carta:** `id`, `nbaPlayerId` (ID oficial para la foto; negativo si no hay cruce), `nombre`, `franquicia`, `equipo` (identidad de época, p. ej. "SEA" para Seattle SuperSonics), `epoca`, `tier`, `posiciones`, `rol`, `dorsal` (siempre 0), `stats` (11 estadísticas), `fotos`, `media`, `temporadas: [primerAñoDeCierre, últimoAñoDeCierre]`, `draft: [año, pick]` (84,2 % de las cartas), `universidad` (91,9 %, normalizada: "UNC" → "North Carolina"), `nacimiento` (100 %), y `estimadas` (si hay datos estimados).
- **Épocas (`Epoca`):** `anios40 … anios2010, actualidad`. `actualidad` = **toda la década 2020** (2019-20 en adelante, incluye 2026-27 en curso). Etiquetas visibles: "Años 2020", código "20s", corta "20’" (antes "HOY"). El nombre del enum `actualidad` **no** se renombra (compatibilidad de JSON).
- **Tiers:** B 8.411 · A 2.704 · S 138 · S+ 70 (v2). **Media** 60–99.
- **Estadísticas estimadas:** 2.183 cartas (robos/tapones antes de 1974, pérdidas antes de 1978, rebotes antes de 1951, minutos antes de 1952) se estiman con promedios por posición de las primeras temporadas registradas y quedan marcadas en `estimadas`. Triples antes de 1980 = 0 (la línea no existía).
- **Extintos sin sucesor** (BLB, WSC, STB, CHS, PRO, INO, DTF, AND, TRH, WAT, INJ, SHE, DNN, CLR, PIT): **327 cartas** que no salen en ruleta por franquicia, ni como rivales, ni en "Franquicia pura". Idea pendiente: franquicia especial "Pioneros BAA/NBA" (§19).
- **`assets/database/temporadas_huecos.json`:** cartas con temporadas no contiguas (432), generado por `tools/temporadas_jugadas.py`; lo usa "Temporada real" para ubicar jugadores que fueron y volvieron.

### 5.2 Pipeline Python (`tools/`)
- **`catalogo_bbref.py`** genera el catálogo desde datasets públicos de Basketball-Reference (`sumitrodatta/bball-reference-datasets`, descarga con `FUENTE` + nombre de CSV): `Player Totals`, `Advanced` (BPM, VORP, WS/48, PER), `All-Star Selections`, `End of Season Teams`, `Player Award Shares`, `Player Career Info`, `Draft Pick History`. Determinístico (dos corridas con distinto `PYTHONHASHSEED` dan el mismo md5; el fallback de `nbaPlayerId` usa `zlib.crc32`, no `hash()`).
- **Media v2 (por impacto):** BPM ponderado por minutos por tramo (desde 1974; antes, WS/48 y PER llevados a escala BPM, reescalados por época); regresión por muestra chica (peso = PJ/(PJ+50) hacia −2); puntaje = impacto + 0,22·(mpg−24) + 0,45·min(premios por temporada, 12); mapeo por ranking **dentro de cada época** sobre el histograma de medias v1 (`DISTRIBUCION_MEDIA`) para mantener la escala y la fuerza relativa entre épocas. Antes de 1951-52 (sin minutos) se conserva el orden v1 intercalado por percentil.
- **Tier v2:** S+ = media ≥ 95 con ≥ 4 puntos de premios por temporada (o ≥ 25 en total); S = media ≥ 91, o ≥ 88 con ≥ 4 por temporada; A = media ≥ 79 o cualquier premio; B el resto. Resultado: A/B ≥ 92 pasó de 69 a 0; S < 86 de 10 a 0.
- **Roles (`extraer_cartas.py: rol_de`)** corregido: los aleros ya no caen por defecto en `cerrojoDefensivo` (antes 938 cerrojos y 1 especialista 3D; ahora 95 cerrojos, 122 especialistas 3D, 179 tiradores…); usa % de triple y DBPM.
- **Otros scripts:** `fotos.py` (resuelve fuentes de foto por carta), `extraer_cartas.py`, `normalizar_escudos.py`, `entrenadores.py` (baja fotos de Wikimedia Commons y quita el fondo con rembg isnet), `encuadrar_entrenadores.py` (encuadre manual de 8 fotos de entrenadores), `sonidos.py` (sintetiza los OGG), `historia_nba.py` (genera `lib/data/historia_nba.dart`: récords reales y campeones), `temporadas_jugadas.py`, `ajustes_cartas.json` (correcciones manuales). **Después de cualquier cambio de catálogo hay que re-correr `temporadas_jugadas.py` e `historia_nba.py`.**
- **Antes de cambiar medias o cartas otra vez:** el balance (§9.6) se descalibra y hay que recalibrar; y los códigos de reto / Desafío del día cambian de contenido (por eso existe `versionCatalogo`, §13).

### 5.3 Fotos
- Fuentes por carta en orden: `n` (CDN NBA, headshot 1040×760), `b` (Basketball-Reference), `w` (Wikipedia). 4.655 cartas usan `n`; 6.668 usan `b`+`w`.
- Wikipedia se consulta **desde el celular** (desde la nube devuelve 429). `core/foto_wikipedia.dart` pide la miniatura de **960 px** (o el original si es más chico).
- El **recorte de fondo** de fotos de archivo se hace **en el dispositivo** con ML Kit Selfie Segmentation (`core/recorte_fotos.dart`, carpeta `recortes_v2/`). Corre en el hilo de la UI (mejora pendiente: `Isolate`).
- Sin red: se juega igual con lo que esté en caché; si falta una foto, iniciales.

### 5.4 Entrenadores, escudos, sonido, tipografías
- **18 entrenadores reales** (`domain/entities/entrenador.dart`), con táctica preferida y franquicias que dirigieron. Fotos WebP sin fondo en `assets/entrenadores/` (créditos en `CREDITOS.md`). La de Holzman es de baja resolución.
- **Escudos** SVG en `assets/logos/` (30 actuales) y `assets/logos/historicos/` (identidades como SuperSonics, Bullets, New Jersey Nets).
- **Sonidos** sintetizados (`tools/sonidos.py`, sin licencias): bocina, red, aro, pique, silbato, público, abucheo, defensa, ovación, golpe.
- **Fuentes:** Doto y Big Shoulders Display (OFL), licencias registradas en la app.

---

## 6. Modo clásico (la temporada 82-0)

### 6.1 Draft (`domain/draft.dart`, `presentation/pantallas/draft_pantalla.dart`)
- **Ruleta:** 3 carretes (franquicia, época, rareza); se elige 1 de las cartas que salen. **Cartas:** se elige 1 de 3 sobres (época/franquicia/misterioso), se abre y se ficha 1 de 5.
- **Reglas (`ReglaDraft`):** Libre, Una sola década, Franquicia pura, Underdog (solo A y B), A ciegas (solo Cartas), Draft en serpiente (solo Cartas; los rivales se llevan cartas, "robos"), Mi colección (solo cartas del álbum; `Draft.coleccionAlcanza`).
- **Fichas para volver a tirar:** 3 por temporada + las de las ventajas de nivel. Cada paso se guarda al instante.
- **Química (`quimica.dart`):** puntaje 0–100 por vínculos entre pares: misma franquicia +1, misma época +1, compañeros de época +3, dúo legendario +6 (44 dúos curados), entrenador que los dirigió +2; tope de 36 puntos = 100. Efecto en el motor: ±1 punto de acierto (50 neutro). **Medidor** (`MedidorQuimica`): franjas Baja 0–39, Media 40–59, Alta 60–84, Excelente 85–100.
- **Entrenador:** 1 de 18 (afinidad +12 si coincide su táctica). **Versiones de carta** (`versiones.dart`): Novato / Prime / Veterano, calculadas al cargar el catálogo (`registrarVersiones`, `versionesCatalogo`).
- **Semillas:** `Draft.azarPara(...)` deriva un `Random` por paso (semilla + picks + paso + rerolls) para que el código de reto reproduzca el mismo draft.

### 6.2 Tácticas (`domain/playbook.dart`, `entities/tactica.dart`)
Sistemas ofensivos (Pace & Space, Triángulo, Seven Seconds…) y defensivos (Drop Coverage, Switch All, Trap/Blitz, Zonas, Presión). Cada uno afecta triples, interior, pérdidas, robos, contraataque, ritmo y fatiga. El juego recomienda según el perfil del plantel (`recomendar(PerfilPlantel.de(plantel))`).

### 6.3 Temporada regular (`domain/liga.dart`, `presentation/pantallas/temporada_pantalla.dart`)
- 82 partidos, jornadas comprimidas (88). 29 rivales: plantel "Histórico" (lo mejor de su historia) o "de Época" (una década real); se muestran como "Detroit Pistons (90’)".
- **Dificultad (`Dificultad`):** fija la media a la que apuntan los rivales: **Normal 78, Difícil 83, Leyenda = lo mejor de cada franquicia**.
- **Desgaste:** back-to-back en ~18 % (determinista por hash) y giras de ≥ 3 visitas; bajan la energía inicial.
- **Forma (−3..+3, se suma a la media):** tras cada partido se compara la producción de cada jugador (pts + 0,7 reb + 0,7 ast + rob + tap − per − 0,5·tiros errados) con lo que promedia su carta en esos minutos, **relativo a sus compañeros del mismo partido**; muy bueno +1, muy flojo −1, normal acerca 1 a cero. (Se corrigió: antes se medía en absoluto y tendía a −2/−3.)
- **Lesiones:** 0,5 % por jugador y partido jugado; duración 1–3 (60 %), 4–10 (30 %), 11–25 (10 %). El titular lesionado lo reemplaza el sano que puede jugar el puesto.
- **Banco largo:** hasta 2 suplentes además del Sexto Hombre (`Temporada.maxSuplentes`). **Cada temporada arranca con 2 suplentes** de puestos distintos (`Liga._bancoInicial`, de los agentes libres); se liberan/cambian con FIRMAR. Entran si un titular está fundido o lesionado, o en final liquidado (≥ 18 de diferencia en el último cuarto).
- **Agentes libres:** 8 cartas A/B con media 72–86 que no estén en ningún plantel; deterministas por bloque de 10 jornadas.
- **Mercado de pases (`mercado.dart`):** cierra al 60 % de la temporada, máximo 3 pases, carta por carta y del mismo puesto, S+ casi intocables, contraoferta.
- **Copa NBA (`copa.dart`):** arranca al 35 %; 4 mejores de cada conferencia, partido único (cuartos, semis, final); no cuenta para el récord; trofeo y logro; si el usuario no juega su partido en 4 jornadas se simula solo.
- **Clima de temporada:** titulares semanales, carrera al MVP, récords históricos en juego, fin de semana All-Star (ahora **persistido** en `Temporada.allStar`, generado al pasar la mitad).
- **Revancha:** el perfil recuerda quién te eliminó/ganó mucho; chip "REVANCHA · Te eliminaron en…" en la tarjeta del próximo partido y en la serie de playoffs.
- **Simular:** de a 1, 10 o toda la temporada; el récord se actualiza partido a partido (pasos de 16 ms).

### 6.4 Playoffs y premios
Play-In (7–10) a partido único; cuadro 1-8, 4-5, 3-6, 2-7; series al mejor de 7 con localía 2-2-1-1-1; desempates oficiales (h2h, récord de conferencia, diferencia). Premios: MVP, Máximo Anotador, DPOY, Sexto Hombre, Más Mejorado, All-NBA 1-2-3.

---

## 7. Motor de partido (`domain/motor.dart`, ~1.330 líneas)

### 7.1 Mecánica
Simulación **por posesiones** con reloj de juego y de posesión (24 s); 4 cuartos de 12 min + prórrogas de 5. `MotorPartido(local, visitante, usuarioLocal, azar)`; cada `EquipoPartido` tiene `identidadId`, `plantel`, `tactica`, `entrenador`, `forma`, `energiaInicial`, `reserva` y (nuevo) `modificadores`.

**Probabilidad de acierto:** base por tipo de tiro y jugador (%TC/%T3) + (media del tirador − media de los defensores en cancha) × `pesoDiferencia` (**1/225**) + química (±1 pt) + afinidad táctica y de entrenador ((ofensiva − defensiva)/1500) + localía (`_localia = 0,012`) + clutch ("sangre fría") − fatiga. **Clutch:** últimos 5 min del 4.º o prórroga con ≤ 6 de diferencia; la estrella toma ×1,6 tiros.

**Cambios:** rotación automática por energía/minutos del Sexto (pocos/normal/muchos), cambios manuales en vivo, forzados por faltas, guarda anti ping-pong (≥ 2 posesiones entre cambios), reserva del banco largo. **Jugada clave** en el final apretado (el usuario elige).

**Estado inicial configurable:** `MotorPartido.arrancarEn(...)` (cuarto, reloj, marcador, posesión, faltas) para los "Momentos clutch"; por defecto es idéntico al arranque normal.

**Modificadores por equipo (`domain/modificadores.dart`, `ModificadoresEquipo`):** bonus de triple/interior/clutch, factor de fatiga, de contraataque, de robos y de tapones; neutros por defecto (un test verifica que un partido con la misma semilla es idéntico sin modificadores). Los usan las insignias de Camino al anillo y el "impulso histórico" de los clutch.

### 7.2 Jugadas modeladas
- **Tiros:** dobles, triples, volcadas, alley-oops, contraataques, rebote ofensivo con segunda oportunidad, interferencia (el tiro errado vale como convertido), tapones (a veces los recupera el ataque; también a triples).
- **Pérdidas (`TipoPerdida`):** robo, pelota afuera, carga (falta en ataque), pasos, dobles, 24 s, 3 s, campo atrás.
- **Faltas (`TipoFalta`):** en el tiro (2–3 libres, 2+1), **sin tiro** (saque lateral hasta la 4.ª del equipo en el cuarto; desde la 5.ª **bonus** = 2 libres), técnica (1 libre, no cuenta como personal, la 2.ª expulsa), flagrante (2 libres + posesión), **intencional** en el final, sexta falta = expulsión. Los jugadores cargados de faltas cometen menos (`((6−fal)/6)^2,5`).
- **Fin de cuarto:** tiro sobre la chicharra; con ≤ 2,6 s, lanzamiento desde la otra mitad (3,5 % de acierto). **Salto entre dos** por pelota retenida.
- **Final de partido (reglas para todos los modos):** el que pierde por 1–2 con < 24 s hace falta intencional; pierde por 3 (≤ 24 s) o por 4–9 (≤ 40 s) → busca triple; cerca del final el que pierde tira rápido (4–8 s) y el que gana gasta reloj (17–22 s). *Esto bajó el balance y obligó a recalibrar (§9.6).*
- **Seguridad:** todo evento consume ≥ 0,5 s (no hay bucles infinitos; ya hubo uno con ping-pong de cambios por faltas).

### 7.3 Tasas por partido (los dos equipos, 60 partidos)
Tapones 10,3 · robos 15,1 · pérdidas 27,9 · faltas 40,5 · tiros libres 48 (NBA real ≈ 10/15/27/40/45). Puntos por equipo ≈ 101–105 (la NBA moderna ≈ 110–115; las pruebas aceptan 90–118). Raros a propósito: técnicas 0,42, flagrantes 0,05, intencionales 0,45, interferencias 0,32, saltos 0,22, expulsiones ~0,1 por partido.

---

## 8. Partido en vivo (presentación)

- **Cancha 2D** (`partido/cancha_partido.dart`): vista de transmisión, aros, escudo central, carteles LED, cámara que sigue la pelota con zoom, fichas con colores de camiseta e iniciales (sin dorsales), el salto se ve como ficha que crece con sombra.
- **Coreografía** (`partido/coreografia.dart`): cada evento es una línea de tiempo en segundos con keyframes y curva seno exacta; defensores que persiguen con velocidad/aceleración limitadas; la pelota siempre sale de una mano y llega a otra; animaciones propias (robo, tapón con pelota despedida, carga, violaciones, salto entre dos, lanzamiento lejano, interferencia, silbato). **Semilla estable por jugada** (FNV-1a, no `Object.hash`) → las repeticiones se dibujan igual. Un test verifica partidos completos: continuidad, dentro de la cancha, sin teletransporte.
- **Marcador estilo TV:** cuarto, reloj LED, 24 s, faltas por equipo y BONUS, tiempos muertos; carteles por jugada (FALTA TÉCNICA, EN BONUS · 2 LIBRES…). Las siglas se achican con `FittedBox` y nunca se cortan.
- **Relator** (`domain/relator.dart`): frases rioplatenses por tipo de jugada y contexto; **voz opcional** (`VozRelator`, flutter_tts). **Sonido** (`SonidoPartido`), apagable.
- **Controles:** velocidad x1/x2/x4, pausa, tiempo muerto, acelerar ritmo, presión alta, cambios, jugada clave, saltar al final. **Paneles:** Equipo, Tiros (mapa de tiros), Partido (probabilidad de ganar + parciales), Relato.
- **Repeticiones** en cámara lenta de las jugadas destacadas (`repeticion.dart`, `Destacada.valor`), **pospartido** (jugador del partido, box score de ambos, 3 mejores jugadas).
- **Tablet** (`widgets/disposicion.dart`: `esTabletApaisada`, `DosPaneles`, `AnchoMaximo`): ancho ≥ 900 y más ancho que alto → cancha a la izquierda a toda altura y paneles a la derecha sin scroll. El teléfono no cambia.

---

## 9. Dificultad y balance

### 9.1 Estado actual (medido con `test/balance_test.dart`)
| Dificultad | Media objetivo de rivales | Draft típico gana | Mejor plantel gana | Puntos por equipo |
|---|---|---|---|---|
| Normal | 78 | 56 % | 97 % | 101,2 |
| Difícil | 83 | 29 % | 89 % | 104,7 |
| Leyenda | lo mejor de cada franquicia | 7 % | 57 % | 103,6 |

### 9.2 Bandas que exige el test
Normal: típico 45–78 %, mejor ≥ 90 %. Difícil: típico 20–40 %, mejor 75–96 %. Leyenda: típico ≤ 30 %, mejor 50–90 %. Orden estricto Normal > Difícil > Leyenda. Puntos entre 90 y 118.

### 9.3 Historia de ajustes
Normal 79 → 78 (con el catálogo v2); Difícil 82 → 84 → 83 (ver §9.4); `pesoDiferencia` 1/250 → 1/225 (compensar los libres extra de las jugadas nuevas).

### 9.4 Cuidado al tocar el balance
Cualquier cambio en motor, medias o tiers lo mueve. Procedimiento: `flutter test test/balance_test.dart` (imprime los porcentajes), ajustar `Dificultad.mediaRivales` en `temporada.dart` y/o `pesoDiferencia` en `motor.dart`. Probar 77 en Normal da 65 %/100 % (demasiado fácil).

### 9.5 Modos sin test de balance permanente
Racha, Camino, Mundial, Escenarios, Guantelete, Universitario, etc. se midieron con scripts temporales que se borraron. Valores medidos: Camino con draft típico llega al escalón ~3,3–4 (mejor plantel 9–12 de 12); Guantelete se completa 31 % / 19 % / 6 % (Normal/Difícil/Leyenda) con picks al azar; universitario: 13, 17, 21, 25, 23 victorias en 5 temporadas. Idea pendiente: `test/escalera_balance_test.dart` con semilla fija.

---

## 10. Los 34 modos de juego (`ModoJuego`)

Menú: Inicio → "OTROS MODOS DE JUEGO". Grupos: La temporada · Partidas rápidas · Desafíos · Historia de la NBA · Torneos históricos · Gestión y carrera · Con amigos · Competitivo y torneos · Minijuegos.

### 10.1 Clásico y variantes de temporada (`domain/variantes.dart`, `presentation/modos/variantes.dart`)
- **Temporada 82-0** (`clasico`).
- **Leyenda única:** 1 de 6 figuras (2 S+ y 4 S) + resto al azar ≈ 2 puntos bajo el objetivo de la dificultad; sin draft, 0 rerolls; no suma al álbum.
- **Extremo:** 0 fichas, lesiones ×2 de frecuencia y +50 % de duración, **Difícil fijo**, una sola partida activa; eliminado/sin playoffs = partida perdida (`Variantes.extremoPerdido(t)`, calculado, no guardado). +1000 XP, +400 monedas y logro al ganar.
- **Solo entrenador:** plantel completo al azar de nivel acorde; vos manejás tácticas/rotación/jugada clave. No suma al álbum.
- **Modo espejo:** draft normal, se guardan las cartas ofrecidas y no elegidas (`datosModo['pasadas']`); al terminar, la IA arma con ellas el plantel que dirigís vos, y tu draft pasa a ser un rival en tu conferencia (pantalla `EspejoRevelado`).
- **Desafío del día:** id `dia-aaaammdd`, mismo draft/rivales/calendario para todos (semilla = fecha XOR 16 bits de la versión del catálogo); un intento por día (`PerfilEntrenador.desafiosDelDia`); puntaje = victorias; 50+ = logro.

### 10.2 Escalera (`domain/modos/escalera.dart`, 1.401 líneas)
Clase `Escalera` en `datosModo`: lista de cruces (rival, formato partido único o serie, resultados). Pantalla `EscaleraPantalla`.
- **Racha infinita:** draft + rivales al azar cada vez más fuertes hasta perder (rival sube 0,6 por victoria desde 72/74/78); mejor racha en `PerfilEntrenador.mejorRacha`; 15 victorias = logro.
- **Camino al anillo:** 9 partidos únicos + Las Finales al mejor de 7 contra uno de los mejores equipos de la historia; objetivo de rival 74 + 1,7 por escalón (Finales +2). Tras cada victoria se elige **1 de 3 insignias** (12, acumulables; ver abajo). Las ventajas planas viejas siguen cargando en partidas viejas.
  - **Insignias** (ver `insignias_test.dart`): Showtime (+80 % contraataque; versión chica +30 %), Bad Boys (rival se cansa 25 % más), Zona prohibida (−4,5 % a dobles rivales con 2 jugadores de ≥ 2,0 tapones), Pizarrón de Popovich (+4,5 % en tiros asistidos con 3 jugadores IQ ≥ 88), Splash (+4 % triples con 2 tiradores ≥ 37 %), Sangre fría (+6 % clutch), Banco profundo (−25 % fatiga), Química de vestuario (+2,5 % con química ≥ 60), Mamba mentality (+8 % de tu máximo anotador en el 4.º), Manos rápidas (+35 % robos), Segunda chance (+40 % rebotes ofensivos), Refuerzo (suplente extra). Las versiones "chicas" aplican cuando no se cumple el requisito.
- **Los mejores equipos de la historia:** 10 planteles reales (Bulls 95-96 el último), series al mejor de 3, el modo más difícil a propósito.
- **Mundial de franquicias:** 32 equipos (vos + 29 franquicias + Sonics y Nets de New Jersey como clásicos); rivales a la media de la dificultad (con all-time ni el mejor plantel ganaba); partido único hasta cuartos, semis/final al mejor de 3.
- **Escenarios históricos:** 8 momentos reales (Finales 98, 16, 93, 84, 13, 06, 94 y la final del Oeste 2002) con plantel histórico y serie que arranca en el resultado real; no suman al álbum.
- Progreso por modos en `domain/modos/progreso_escalera.dart` (`sumaAlAlbum`: excluye escenarios, Leyenda única y Solo entrenador).

### 10.3 Carrera
- **Dinastía** (`domain/modos/dinastia.dart`): cada temporada es una `Temporada` nueva con id `<raiz>-tN`; `EstadoDinastia` en `datosModo` (número, edades, años en el club, historial, década). Receso: envejecimiento (edad inicial por versión: Novato 22 / Prime 27 / Veterano 32; cambio por edad +3…−4 ±1), retiros (≥ 34 y probabilidad creciente, o media < 66; máx. 3 titulares), mini-draft de 1 de 3 novatos por puesto libre, línea de tiempo narrada. Logro `dinastia3` (3 anillos). El receso es determinista por id.
- **Reescribí la historia:** plantel real de una franquicia en una década; avanza de década cada 3 temporadas; novatos de la década **siguiente** (por época, no por año de draft; con el campo `draft` ya disponible podría pasar a camadas reales).
- **Figura franquicia:** elegís 1 de 8 jóvenes (Novato o media 72–80, 20 años); resto Tier B 66–76; crece +1..+5 por receso hasta los 30 según edad, línea de la temporada (≥ 20 partidos) y premios; declina desde los 31; no se retira antes de 35 salvo media < 70; panel de legado con veredicto de Salón de la Fama. `figuraId` en `EstadoDinastia`.
- **Mi carrera (estilo MyCareer)** (`domain/modos/carrera_jugador.dart` + `presentation/modos/carrera_jugador*.dart` + `creador_jugador.dart`):
  - **Inicio:** jugador **real** (carta más temprana, su equipo y pick real) o **creado** (`CreadorJugadorPantalla` → `JugadorCreado`: nombre, posición, arquetipo, 3 fuertes, altura/peso, vista previa). Creado: combine de 5 pruebas, noche del draft con sorteo de las 30 franquicias; sin draft → elige entre 3 contratos. Contrato 4 años (1.ª ronda) o 2.
  - **Temporadas:** la IA arma 7 compañeros; se usa la pantalla de temporada normal con tarjeta "Mi jugador". **Confianza del DT (0–100)** con histéresis define el rol (≥ 60 titular, 35–59 sexto, < 35 banco); al cambiar se rearma el plantel.
  - **Progresión:** puntos de habilidad por rendimiento (tope 24/temporada) que se gastan en 5 atributos (tiro, finalización, defensa, físico, IQ/pase; cuestan 1/2/3 según nivel) y mueven las stats que lee el motor (un test verifica > 2 pts/partido más con mejoras). 7 insignias que suman stats (sin doble conteo con las del jugador real).
  - **Receso (se guarda por paso):** resumen, objetivos del DT (3 × 3 puntos), cambio natural por edad, entrenamiento, 2 preguntas de prensa (confianza/ánimo/fans/vestuario), contrato (renovar u ofertas de 3 equipos con rol según competencia en tu puesto; pedido de traspaso desde la 2.ª temporada). Retiro desde los 34, forzoso a los 41 o desde 36 con media < 66. Legado, veredicto del Salón, línea de tiempo; logro `salonDeLaFama` (una sola vez).
  - **Pendiente:** premio al novato del año; foto del jugador creado (usa iniciales); rivales no se ajustan a la época del jugador real; los equipos ofrecen todos media ≈ 78 (Normal).
  - **API reutilizable:** `JugadorCreado` (`error`, `atributos`, `media`, `estadisticas`, `comoCarta(id, franquiciaId, epoca, anio)`, JSON), `ModeloCarrera.mediaDe/estadisticasDe`.
- **Modo universitario** (`domain/modos/universitario.dart`, `presentation/modos/universitario*.dart`): creás un programa (nombre, apodo, 2 colores de una paleta de 12, escudo con monograma LED) y 2–5 jugadores con el creador; el juego completa 10. **32 universidades ficticias** en 4 conferencias de 8 (Pacífico, Gran Lago, Sureña, Atlántica), las 31 de la IA se regeneran de la semilla (no se guardan). 30 jornadas (14 de conferencia ida y vuelta + 16 interconferencia sin repetir rival). Tus partidos usan el `MotorPartido` real; IA vs IA usa un modelo liviano calibrado (1 punto de media ≈ 0,8 de margen; marcadores a escala NBA ~100). Tabla por conferencia, **Top 25**, plantel, historia; torneo de **16** equipos (4 campeones de conferencia + 12 mejores récords); premios (Jugador del Año, All-American 1.º/2.º, Novato del Año). Receso: se gradúan los de último año; los de 2.º/3.º con media ≥ 72 pueden declararse; crecimiento (1.er año el mayor salto); **reclutamiento** de 8 jugadores con 1–5 estrellas por "puntos de reclutamiento" (el prestigio mejora la oferta); roster 8–13; **draft ficticio de 30 picks** con 34 prospectos; un graduado de 1.ª ronda se puede **exportar a Mi carrera** (`creadoInicial`). Recompensas: 15 XP y 3 monedas por victoria; título nacional 400 XP + 150 monedas + logro `campeonNacional`. La partida guarda un id de franquicia NBA real (el de color más cercano) para el tema de la app.

### 10.4 Historia (`domain/modos/historia.dart`, `lib/data/historia_nba.dart`)
- **Temporada real:** elegís un año (1976-77 a 2025-26) y cualquier equipo; los 29 rivales juegan con su plantel **real** de ese año (cartas cuyo rango `temporadas` lo contiene; los que se fueron y volvieron se ubican con `temporadas_huecos.json`); franquicias que no existían usan su plantel más cercano y lo dicen. Flujo clásico de 82 + playoffs; botón con el récord y campeón reales. La dificultad no influye. Los récords salen de `Team Summaries.csv` (generados); **los campeones 1977–2025 están escritos de memoria**, sin contrastar con fuente.
- **¿Qué hubiera pasado si…?:** 8 historias alternativas (Jordan '94, Jordan a Portland '85, Shaq/Kobe '05, Shaq en Orlando '97, Brandon Roy sano, Sabonis joven en Portland, Durant en OKC '17, LeBron en Cleveland '11), cada una una temporada real con 1 carta sumada; meta: ganar el título. Se reemplazaron Penny/Shaq y Len Bias (sin carta).
- **Momentos clutch:** 11 finales reales que se juegan **en vivo** desde el marcador/reloj real (Jordan '98, Ray Allen '13, McGrady '04, Kawhi '19, Kyrie '16, Reggie '95, Magic '87, "The Shot" '89, Lillard '19, Bird '87, Fisher '04). Ganar = +80 XP y +40 monedas; ganar las 11 = logro `clutchHistorico`; se puede reintentar. **Las situaciones están de memoria** (Kyrie, Magic y Lillard marcados "basado en el partido real"). Tasas de victoria simuladas: Jordan ~33 %, Kyrie 71 %, Kawhi 93 %, Bird 26 %; Ray Allen, McGrady, Reggie y Fisher ≈ 2–8 % (casi imposibles, como en la realidad). Tu lado usa un pequeño "impulso histórico" vía `ModificadoresEquipo`.

### 10.5 Torneos por época (`domain/modos/epocas.dart`)
- **Guantelete de las décadas:** mini-draft de 6 (uno por puesto, 4 opciones por puesto, años 40/50); rival = la mejor franquicia de cada década (50s → 2020s), mejor de 3; tras cada victoria reclutás 1 jugador del rival; perder termina la corrida. Logro `guantelete`.
- **Batalla de camadas:** 8 clases de draft (1984, 85, 87, 92, 96, 98, 2003, 2009, 2011, 2018…; usa `Jugador.draft`), cada equipo = mejor carta de cada persona; cuadro con partido único y mejor de 3 en semis/final. Logro `camadas`.
- **Torneo de universidades:** 16 equipos de ex alumnos (15 universidades más fuertes + "Directo a la NBA"); usa `Jugador.universidad`. En el torneo el escudo mostrado es el de la franquicia de su figura. Logro `universidades`.

### 10.6 Armado (`domain/modos/armado.dart`)
- **Tope salarial:** tablero 5×5 de 25 cartas con precios: $5 (S+), $4 (S), $3 (A ≥ 85), $2 (A), $1 (B); columnas = puestos, semilla por partida, cada columna garantiza una carta elegible. Presupuesto **$15 / $14 / $13** (Normal/Difícil/Leyenda); no se puede comprar si quedaría menos de $1 por puesto vacío; tocar una carta comprada la vende. 7 equipos de IA con el mismo presupuesto (roster óptimo por suma de media); liga de 14 partidos (doble vuelta entre 8) + playoffs top 4 (semis y final al mejor de 3). Logro `topeSalarial`.
- **Desafíos de armado (el SBC):** 20 acertijos progresivos que usan **solo cartas de tu álbum** (no se consumen). Requisitos con ✓/✗ en vivo (química ≥ X, décadas distintas, conferencias, media del equipo, misma franquicia, límites de tier, arquetipos, robos+tapones). Premios: monedas, XP y puntos de pase una vez; se desbloquean en orden; se muestran bloqueados si el álbum no alcanza. 10 resueltos = logro. **Lee la media del catálogo; falta enchufar `aplicarEvoluciones`** (§16).
- **Liga de 8 contra la IA:** draft en serpiente con pool visible de 72 cartas, 7 mánagers con personalidad (triples, defensa, leyendas, química, jóvenes, nostálgico, números); sin repetidos; luego liga de 14 + playoffs top 4. Logro `ligaIA`.
- **Adiviná la carta:** 10 rondas, "¿Quién es?" (línea de estadísticas y 4 opciones plausibles del mismo puesto/época) y "Más o menos" (¿cuál tiene más media?); 10 XP y 5 monedas por acierto; mejor puntaje en el perfil; 10/10 = logro `adivina`. No crea partida (se abre directo).

### 10.7 Competitivo (`domain/modos/competitivo.dart`, `presentation/modos/competitivo*.dart`, `torneos.dart`, `elegir_alineacion.dart`)
Los tres usan tu **álbum** y aplican evoluciones a tu equipo (no a los rivales).
- **Divisiones:** 10 divisiones (10 → 1); cada "temporada de división" son 10 partidos contra planteles del nivel; victoria 3 puntos (4 si es por ≥ 15), derrota 0; ≥ 21 asciende, ≤ 9 desciende (la 10 no desciende, la 1 no asciende; ganar en la 1 = título de la élite). Cada partido en vivo o simulado, o simular toda la temporada. Logro `divisionUno` y trofeo.
- **Conquista:** tablero de 10×5 (no es un mapa real) con las 30 franquicias (Oeste izquierda, Este derecha, norte arriba); arrancás en la tuya; atacás vecinos (8 direcciones); ganar conquista el territorio y desbloquea sus cartas; podés perder hasta **8** veces; los rivales suben 0,35 de media por territorio. **Beneficio por división (agregado por el agente, no pedido):** 3 de 5 franquicias de una división = +1 de forma a ciertos puestos (+2 con las 5). Conquistar las 30 = logro `conquistaTotal` y trofeo; completar una conferencia paga bonus.
- **Creador de torneos:** liga (hasta 16), eliminación o grupos + eliminación; 4–32 equipos; los equipos pueden ser franquicias (mejor roster all-time), planteles de franquicia+década, "mejores de la historia", tus partidas guardadas o un equipo de tu álbum; mejor de 1/3/5/7; byes para cantidades impares; jugás en vivo/simulás o mirás; REPETIR con los mismos equipos. Logro `campeonTorneo`.
- **Fantasy NBA** (`domain/modos/fantasy.dart`): ver §10.9.

### 10.8 Con amigos, en el mismo dispositivo (`domain/modos/amigos.dart`)
- **Draft en grupo (2–8 personas):** pantalla "Pasale el dispositivo"; draft en serpiente con **4 cartas por turno** (peso por tier S+ 1, S 3, A 6, B 4), sin repetidos entre jugadores, fijas por semilla, 1 "OTRAS CARTAS" por persona (no usa el dominio de `Draft`, que está atado a una sola temporada); tácticas con `recomendar()`; liga todos contra todos ida y vuelta; final al mejor de 3 entre los 2 primeros.
- **Duelo:** 2 personas, 2 drafts, serie al mejor de 7 con localía 2-2-1-1-1; en vivo manda la jugada clave el local.
- **Reto de un amigo:** ver §13.
- Dan solo +40 XP al terminar (sin premios de 82-0 ni campeón).
- Tablet: dos columnas desde 900 px.

### 10.9 Fantasy NBA y Perfil perfecto (`domain/modos/fantasy.dart`, `perfil_perfecto.dart`)
- **Fantasy NBA (offline, sin datos en vivo):** elegís un año (1980–2025) o tu álbum, dificultad, 3–7 rivales de IA y nombre; armás quinteto + Sexto con presupuesto **$48 / $44 / $40** (precio $1–$13 por media); **12 semanas** todos contra todos + semis y final para los 4 primeros; 1 cambio por semana, capitán (suma doble), reemplazo de lesionados. Puntaje: pts + 1,2 reb + 1,5 ast + 3 rob + 3 tap − per, +2 doble-doble, +5 triple-doble. **Los puntos salen de los promedios reales de cada carta con variación de partido a partido, rachas y lesiones simuladas, no de logs reales** (la pantalla lo aclara; no hay forma offline de usar rendimiento real actual). 8 mánagers de IA con personalidad (Triples, Defensivo, Coleccionista de Leyendas, Contador, Rebotero, Repartidor, Equilibrado, Caótico). Con el álbum aplica evoluciones (+2 % de producción por etapa y suben el precio). Logro `campeonFantasy`.
- **Perfil perfecto:** acertijo de lógica **original** de básquet inspirado en la descripción de "Profile Perfect" (la ficha de Play Store no se pudo leer entera; fuentes de terceros se contradicen: investigación de perfiles vs. asignar categorías en una grilla). Cada nivel muestra 3–5 perfiles identificados por franquicia; hay que deducir puesto/época/media/arquetipo/tier/universidad con pistas de texto ("es / no es", "más media o época que", "es el de mayor/menor…", "es X o Y", conferencia). Generador determinista (nivel n → siempre igual) y **solucionador que garantiza solución única**; **120 niveles** (3×1 a 5×4) + acertijo del día; 3 vidas, 2 ayudas por nivel; estrellas (3 sin errores ni ayudas); monedas y XP la primera vez; logros `detective` (25) y `maestroDetective` (100). Se abre con `iniciarPerfilPerfecto` (sin partida).

---

## 11. Metajuego (`domain/progreso.dart`, `entities/perfil.dart`, `entities/metajuego.dart`, `misiones.dart`)

`Progreso.aplicar(perfil, antes, despues)` corre en **cada guardado** y calcula todo por diferencia de estado → (perfil nuevo, novedades). Hay desvíos por modo antes del flujo general: `premiarVariante`, modos de amigos, `premiarFantasy`, `premiarCompetitivo`, `premiarUniversitario`, escalera (`progreso_escalera.dart`), Mi carrera, etc. Cada temporada/id premia una sola vez (`temporadasCerradas`).

- **XP y nivel:** umbral del nivel n = 75·n·(n−1). **Ventajas** por nivel: +1 ficha (3), +1 tiempo muerto (6), 2.ª ficha extra (10), tiempos muertos que recuperan el doble (15).
- **Monedas** (sin dinero real) para la tienda de sobres. **Puntaje personal** estilo Elo. **48 logros** (`Logro`) y **20 tipos de trofeo** (`TipoTrofeo`) para la vitrina. Historial de temporadas y carrera de cada carta (`ResumenTemporada`).
- **Álbum:** colección permanente de cartas (`PerfilEntrenador.coleccion`) y tienda de sobres; lo ganado en modos con plantel prestado/ficticio no suma (`sumaAlAlbum`).
- **Misiones:** 3 diarias + 3 semanales deterministas por fecha (diarias renuevan a medianoche, semanales los lunes); avanzan por diferencia de estado y por una cola estática `Misiones.anotar(TipoMision, n)` que consume el próximo `aplicar` (los modos de desafío la llaman al ganar). Premian XP, monedas y puntos de pase.
- **Pase de temporada offline:** 20 niveles por trimestre (`2026-T4`), 200 puntos por nivel; puntos de misiones, 10 por victoria y 3 por derrota; premios solo estéticos.
- **Vestuario** (`presentation/tema/vestuario.dart`, `vestuario_pantalla.dart`): 4 canchas (moderna, parquet 70s, parquet a cuadros, cemento de barrio), 3 pelotas (naranja, ABA, dorada), 3 uniformes (titular, alternativo, crema clásico), 5 temas LED; algunos se desbloquean por nivel de entrenador; sin elegir nada el juego se ve como siempre.
- **Revancha:** rivalidades por franquicia en el perfil; logro `revancha`.
- **Evoluciones de cartas** (`domain/modos/evoluciones.dart`): objetivo de 5 etapas por carta (+1 media por etapa, tope +5; 3 en curso a la vez; 9 tipos de objetivo: triples, puntos, rebotes, asistencias, robos, tapones, victorias, partidos jugados, noches de 30+). **Solo se aplican cuando `partidaUsaAlbum(t)`** (`modoJuego.usaAlbum || regla == coleccion`); el progreso se gana jugando en cualquier modo. Pestaña "Evoluciones" en el Álbum. **API:** `nivelEvo(perfil, cartaId)`, `mediaEvolucionada(perfil, jugador, usaAlbum:)`, `aplicarEvolucion(...)`, `aplicarEvoluciones(...)`, `partidaUsaAlbum(t)`, `registrarEvolucion(perfil, cartaId, MetricaEvo.x, n)`. `Liga.equipo` ya lo aplica solo al equipo del usuario (nunca a rivales) vía `Liga.nivelEvolucion` (conectado en `main.dart`). Las noches de 30+ solo se detectan en partidos en vivo; las victorias se prorratean por partidos jugados.
- **Campos del perfil agregados** (todos opcionales, perfiles viejos cargan): `metajuego` (misiones, pase, cosméticos, rivalidades), `mejorRacha`, `desafiosDelDia`, `armado` (acertijos resueltos y mejores puntajes), `evoluciones`, `perfilPerfecto`, etc.

---

## 12. Persistencia

- SQLite (`data/db_local.dart`): partidas (`Temporada` en JSON), perfil y ajustes. Se guarda en cada paso relevante (cada pick del draft, cada partido).
- **Retrocompatibilidad total del JSON:** campos nuevos opcionales; partidas anteriores al selector de dificultad se cargan como Leyenda; las anteriores a la v. del catálogo tienen `versionCatalogo` nulo; las anteriores a la Tanda 6 no tienen código de reto.
- Exportar/importar partidas sueltas o copia completa (perfil + ajustes) desde Partidas.
- La lista de partidas muestra el modo, la fase y el marcador (`partidas_pantalla.dart: _fase`, `_marcador`): amigos → "Draft por turnos/Liga/Serie"; Dinastía → "Temporada N"; Extremo perdido → "Perdida".
- **Cartas que faltan en partidas viejas:** `cartaOReemplazo` (en `liga.dart`) elige un reemplazo que juegue el puesto (misma franquicia y época si puede) en vez de crashear; lo usan `Liga.plantelDe`, `Escalera.plantelDe` y `Variantes.plantelTuyo`.

---

## 13. Compartir, código de reto y versión del catálogo

- **Imagen para compartir** (`presentation/compartir/tarjeta_compartir.dart`): tarjeta 360×640 exportada a 1080×1920 (`RepaintBoundary` + archivo temporal + `share_plus`); variantes: temporada, escalera, Dinastía, reto. Muestra escudo, récord LED, anillo, las 6 cartas con su **tramo**, premios y el código de reto. Entradas: íconos en temporada y playoffs, botón en el final de los desafíos, línea de tiempo de la Dinastía y menú de cada partida.
- **Código de reto `82-XXXX-XXXX-XXXX`** (`domain/reto.dart`): Crockford base32, 52 bits de datos + CRC-8 (rechaza cualquier error de un carácter; ignora mayúsculas/espacios/guiones, mapea O→0, I/L→1). **Formato nuevo:** bandera 1, semilla 20 bits, **versión del catálogo 8 bits**, franquicia, modo de draft, regla y época, dificultad, victorias del que reta y si salió campeón; **formato viejo:** bandera 0, semilla 28 bits (se sigue leyendo). Reproduce el mismo draft (un `Random` derivado por paso), los mismos entrenadores, rivales y calendario (`Reto.ligaPara`). Al ingresar un código con otra versión del catálogo se avisa ("Este reto se armó con otra versión de las cartas…"). Comparación final: gana el mejor récord, el anillo desempata. "Mi colección" no se puede retar. `ModoJuego.reto` usa el flujo clásico.
- **Versión del catálogo** (`domain/version_catalogo.dart`): hash FNV-1a de 32 bits del JSON, fijado en `cargarCatalogo()` (0 = desconocido en tests); `Temporada.versionCatalogo` se estampa en partidas nuevas.

---

## 14. Tablet y UI

- `widgets/disposicion.dart`: `esTabletApaisada(context)` (ancho ≥ 900 y más ancho que alto), `DosPaneles`, `AnchoMaximo`. Pantallas en dos paneles: partido en vivo, draft (cancha del plantel + grilla de 4 columnas), temporada, playoffs (Este | Finales | Oeste), Inicio (tablero + 15 franquicias en grilla), Playbook y los modos nuevos. El resto se centra con ancho máximo. **La orientación no está bloqueada.** Verificado solo con capturas a 1340×900 DPR 1,8 y 1280×800.
- **Tramo en la carta:** `Jugador.tramo` ("2020–23"), `tramoCorto` ("20-23"), `tramoConEquipo` ("POR 2020–23"); se muestra en `CartaVertical`, `CartaJugador`, ficha, plantel, mercado, álbum y tarjeta de compartir. La ruleta y los sobres de época siguen mostrando el código de década.
- **Widgets propios:** `TextoLed` (con dígito fantasma), `CeldaLed` (variante para tablas), `MedidorQuimica`, `Escudo`, `CartaVertical`, `JugadorAvatar`, etc. `cancha_partido.dart` usa `Fuentes.led` directo (dibuja un cartel desplazable en canvas; excepción consciente a la regla del dígito fantasma).

---

## 15. Pruebas

- **`flutter test`: 322 pruebas, todas pasan**; `flutter analyze` sin issues; tests Python: 24 OK. Cubren dominio, draft, liga, calendario, motor y jugadas, coreografía (continuidad/cancha/sin teletransporte), balance, playoffs, premios, lesiones, mercado, Copa, escalera, variantes, dinastía, amigos, historia, épocas, armado, competitivo, fantasy, perfil perfecto (solución única en muchos niveles), evoluciones, insignias, figura, Mi carrera, universitario, metajuego, compartir/reto, tramos, fotos de Wikipedia, y pantallas.
- `test/jugadas_test.dart` tiene un test pesado (6 partidos completos de coreografía) con `timeout` de 3 minutos; fue intermitente por una semilla no determinista que ya se corrigió.
- **Capturas** en `capturas/*_test.dart` (31 archivos) → `capturas/salida/*.png` (gitignored). Una ya estaba rota de antes y no se arregló: `capturas/cartas_capturas_test.dart` ("cartas: secuencia") espera cartas inmediatas pero la pantalla ahora muestra primero el selector de sobres.
- No hay test de balance permanente para los modos de escalera, universitario, Guantelete, etc.

---

## 16. Pendientes y deuda técnica (qué falta, en orden aproximado de valor)

### 16.1 Cosas ya conocidas por incompletas
1. **Evoluciones en "Desafíos de armado":** lee la media del catálogo; falta cambiar la lista de cartas del álbum en `DesafiosArmadoPantalla` para pasar por `aplicarEvoluciones(..., usaAlbum: true)`. (Los de Competitivo y Fantasy sí las aplican.)
2. **Revancha en playoffs:** hecho; **la revancha en otros modos** no existe (solo temporada clásica/playoffs).
3. **Mi carrera:** premio al novato del año; foto del jugador creado; ajustar rivales a la época del jugador real.
4. **Catálogo:** franquicia especial **"Pioneros BAA/NBA"** para las 327 cartas de franquicias extintas (propuesta: no mapearlas a franquicias actuales, es históricamente falso).
5. **Datos escritos de memoria sin contrastar:** campeones 1977–2025 y las 11 situaciones clutch (`lib/data/historia_nba.dart`, `domain/modos/historia.dart`). Conviene verificarlos con una fuente.
6. **Reescribí la historia:** ahora que existe `Jugador.draft`, pasar de "novatos de la década siguiente" a **camadas reales por año**; en Dinastía usar edad real (`nacimiento`) en lugar del hash 22/27/32.
7. **Motor:** defensa por emparejamiento (60 % defensor directo / 40 % equipo) y efectos pasivos chicos por arquetipo (`rol`; hoy el motor no lo consulta); ritmo hacia ~108–110 puntos (cambia el balance).
8. **Calidad de código:** dividir `partido_pantalla.dart`, `motor.dart` y los modos grandes; mover el recorte ML Kit y la serialización de `Temporada` a `Isolate`/`compute`; test de balance permanente para modos de escalera.
9. **Estado global estático:** `Misiones.anotar` (cola estática), `SonidoPartido.habilitado`, `VozRelator.habilitado`; `MotorPartido.tecnicaDePrueba()` (gancho público solo para tests).
10. **Fotos:** las de Wikipedia pueden verse blandas en cartas grandes de tablet (ya se pide 960 px); la de Holzman (entrenador) es de baja resolución.
11. **Modos sugeridos y NO elegidos** (por si el usuario los retoma): Batallas de la semana, Fin de semana de campeones, Hazañas (estilo Jordan Challenge: recrear actuaciones), Callejero 3x3, Arcade 2v2 estilo NBA Jam, Clasificatorias con rangos, Rescate (equipo a mitad de temporada), Draft de expansión, Sprint (temporada de 20), Playoffs directos, Rivalidades clásicas, Fin de semana All-Star jugable (concurso de triples y volcadas). Y de la auditoría de Gemini: insignias ✓ hecho, "Carrera de una figura" ✓ hecho como Figura franquicia.
12. **`pubspec.yaml`** dice `version: 0.1.0+1`; el build real lo fija la CI.
13. **Higiene de ramas en GitHub** (el usuario las puede borrar; ya están en `main`): `tanda-2`, `tanda-4a`, `tanda-4b`, `tanda-5`, `tanda-5-wip`, `tanda-6`, `tanda-6-wip`, `catalogo-v2-wip`, `modos-v3`, `modos-v3-wip`.

### 16.2 Riesgos para tener presentes
- **Nada se probó en dispositivo real:** voz TTS, sonidos, hoja de compartir de Android, recorte con ML Kit y todo el diseño de tablet (solo capturas). Es lo primero que el usuario va a ver.
- **Fantasy NBA no usa rendimiento real de partidos** (imposible offline): usa promedios reales de temporadas pasadas con variación.
- **Cualquier cambio de catálogo** cambia medias/tiers (descalibra el balance) y el contenido de códigos de reto y Desafío del día (se avisa por `versionCatalogo`).
- **`git stash`/`checkout` con forks activos** puede pisar trabajo ajeno (ya pasó una vez).
- **Estadísticas estimadas** en 2.183 cartas viejas pesan en la media con valores inventados por posición.
- El corte por década parte carreras (p. ej. Wilt en los Lakers queda en 2 cartas, una por década); el tramo visible lo hace explícito.
- **Datos parciales de 2026-27** (temporada en curso) entran en las cartas `actualidad`.

---

## 17. Ideas de la auditoría externa (Gemini) y qué se decidió
Ver `docs/AUDITORIA_PROPIA.md` para el análisis punto por punto. Resumen: aplicado → etiqueta "HOY" y tramo visible, corrección de arquetipos de aleros, media v2 por impacto, tiers v2, All-Star persistido, `versiones` siempre disponibles, `TextoLed`/sin `BoxShadow`, versión de catálogo en reto/desafío, año de draft/universidad/nacimiento. **Descartado/matizado:** dorsales para el 98 % (el dataset no los trae), mapear franquicias extintas a actuales (falso históricamente), forzar la media por tier (se arregló el tier, no la media). Pendiente: puntos 4–7 del plan (datos nuevos parciales, motor, contenido, mantenimiento).

---

## 18. Mapa de archivos importantes

**Dominio (`lib/domain/`):** `motor.dart`, `liga.dart`, `draft.dart`, `quimica.dart`, `playbook.dart`, `progreso.dart`, `misiones.dart`, `mercado.dart`, `copa.dart`, `premios.dart`, `all_star.dart`, `noticias.dart`, `historicos.dart`, `relator.dart`, `reto.dart`, `variantes.dart`, `versiones.dart`, `version_catalogo.dart`, `modificadores.dart`, `calendario.dart`, `tienda.dart`; `entities/` (`temporada.dart`, `jugador.dart`, `perfil.dart`, `metajuego.dart`, `modo_juego.dart`, `plantel.dart`, `tactica.dart`, `entrenador.dart`, `rival.dart`, `partido.dart`, `oferta.dart`, `franquicia.dart`, `ajustes.dart`, `tirada.dart`, `rol_cancha.dart`, `posicion.dart`); `modos/` (`escalera`, `progreso_escalera`, `dinastia`, `amigos`, `historia`, `epocas`, `armado`, `competitivo`, `universitario`, `carrera_jugador`, `fantasy`, `perfil_perfecto`, `evoluciones`).
**Datos (`lib/data/`):** `catalogo_jugadores.dart`, `franquicias.dart`, `db_local.dart`, `estado_app.dart`, `historia_nba.dart` (generado).
**Presentación:** `pantallas/` (inicio, draft, temporada, playoffs, partido, pospartido, playbook, mercado, álbum, perfil, partidas, misiones, vestuario, ajustes, tutorial, stats82, evoluciones_vista), `partido/` (cancha, coreografía, repetición, sonido, voz), `modos/` (todos los modos), `draft/`, `temporada/` (clima, copa), `compartir/`, `tema/`, `widgets/`.
**Tests:** `test/*_test.dart` (44). **Capturas:** `capturas/*_test.dart` (31). **Docs:** `README.md`, `PRODUCT.md`, `DESIGN.md`, `ROADMAP.md` (todo marcado ✅ hasta §7), `docs/ESTADO_DEL_PROYECTO.md` (build 24), `docs/AUDITORIA_PROPIA.md`, este archivo.

---

## 19. Historial de tandas (para contexto)

| Tanda | Contenido |
|---|---|
| Fases 1–5 | Catálogo histórico, fotos con 3 fuentes, escudos históricos, arquetipos, ruleta, temporada de 82, rivales, motor y partido en vivo 2D. |
| Mejoras de motor | Calidad pesa más, clutch, faltas, selector de dificultad, sonido sintetizado, estética de transmisión, simular toda la temporada. |
| Tanda 1 | Perfil, XP, monedas, logros, partidas múltiples, exportar/importar, ajustes, tutorial, balance. |
| Tanda 2 | Draft y cartas: sobres, reglas, serpiente, química, entrenadores, versiones, sorpresa, álbum y tienda. |
| Tanda 3 | Partido en vivo: jugada clave, cambios, faltas y expulsiones, volcadas/alley-oops, relator y voz, repeticiones, pospartido. |
| Entrenadores | 18 fotos reales sin fondo. |
| Tanda 4a | Play-In, desempates oficiales, historial vs. rival, desgaste del calendario, premios, récords, titulares, carrera al MVP, All-Star. |
| Tanda 4b | Banco largo y lesiones, mercado de pases, Copa NBA. |
| Tanda 5 | Modos (racha, camino, extremo, leyenda única, mundial, mejores equipos, escenarios, dinastía, reescribí, solo entrenador, espejo, desafío del día, draft en grupo, duelo), misiones, pase, vestuario, revancha. |
| Tanda 6 | Imagen para compartir, código de reto, tablet apaisada. |
| Ajustes | Revancha en playoffs, fotos Wikipedia 960 px, medidor de química, forma corregida, rotación de 8, entrenadores reencuadrados, sin dorsales, todas las jugadas de NBA (build 23), Difícil más duro (build 24). |
| Catálogo v2 (build 25) | Medias por impacto, tiers v2, arquetipos de aleros, tramo en cada carta, All-Star guardado, versión del catálogo. |
| Modos v3 (build 26) | 20 modos nuevos (historia, épocas, armado, carrera, competitivo, fantasy, perfil perfecto), evoluciones de cartas, insignias de Camino, Mi carrera, Modo universitario, datos de draft/universidad/nacimiento, recalibración de balance. |

---

## 20. Qué hacer a continuación (sugerencia para el próximo chat)

1. **Verificar en un dispositivo real** (celular y, si el usuario la consigue, la BMAX): arranque, rendimiento de la ruleta (ML Kit), voz y sonidos, hoja de compartir, tablet horizontal. Pedirle al usuario un listado de lo que ve mal.
2. **Cerrar los pendientes chicos** de §16.1 (1, 3, 5, 6) antes de abrir modos nuevos.
3. **Test de balance permanente** para los modos de escalera y el universitario.
4. Si el usuario quiere más contenido: ofrecer los modos no elegidos de §16.1 (11) y **validarlos antes de programarlos**.
5. Mantener la rutina de cierre de §2.4 y entregar siempre APK + capturas + resumen en voseo.
