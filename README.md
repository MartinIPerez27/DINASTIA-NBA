# Dinastía NBA (82-0)

Draft roguelike y simulación de temporada NBA para celulares y tablets. 100% gratuito y offline.
El diseño completo está en el GDD; este repo avanza por fases (ahora: **Fase 1 — modelos y datos**).

## Probarlo en tu PC

### 1. Instalar (una sola vez)

1. **Git**: https://git-scm.com/downloads
2. **Flutter** (incluye Dart): https://docs.flutter.dev/get-started/install — elegí tu sistema y seguí la guía para **Android**.
3. **Android Studio**: https://developer.android.com/studio — trae el SDK de Android y el emulador.
4. Verificá con:

   ```bash
   flutter doctor
   ```

   Lo importante es que aparezcan en verde *Flutter* y *Android toolchain*. Si pide licencias: `flutter doctor --android-licenses`.

### 2. Descargar y correr

```bash
git clone https://github.com/MartinIPerez27/DINATIA-NBA.git
cd DINATIA-NBA
flutter pub get
flutter test
```

Para ver la app, abrí un emulador desde Android Studio (*Device Manager → ▶*) o conectá tu celular Android
con *Depuración USB* activada, y ejecutá:

```bash
flutter run
```

Por ahora la app muestra el catálogo de cartas (foto oficial o, sin internet, iniciales con los colores de la franquicia).

> **Sin Android Studio (solo Windows):** `flutter create --platforms=windows .` y después `flutter run -d windows`
> (requiere Visual Studio con "Desarrollo para el escritorio con C++"). La versión web no muestra las fotos porque el
> CDN de la NBA no permite CORS.

## Generar el catálogo real de cartas

`assets/database/nba_players.json` trae 14 cartas **provisorias**. El catálogo real se genera con
`tools/extraer_cartas.py`, que descarga los datos de stats.nba.com una sola vez.

Cada carta es **jugador + franquicia + época**, y todo se calcula solo con las temporadas de ese tramo:

| Campo | Cómo se calcula |
| --- | --- |
| Estadísticas | Totales de esas temporadas con esa franquicia ÷ partidos (PPP, RPP, %TC…). |
| Posiciones | Posición de carrera + perfil de ese tramo (p. ej. LeBron suma BASE en Lakers por asistencias). |
| Tier | Premios ganados en ese tramo: MVP, MVP de Finales, All-NBA, DPOY, 6.º Hombre, All-Star. |
| Rol | Perfil por 36 minutos: tasa de triples, tiros libres, asistencias, rebotes, tapones. |
| IQ (60–99) | Asistencias por pérdida, eficiencia comparada con su época, premios y defensa. |

```bash
python -m pip install nba_api
python tools/extraer_cartas.py --solo 2544,893   # prueba rápida: LeBron y Jordan
python tools/extraer_cartas.py                   # catálogo completo (~40 min la primera vez)
```

- Si se corta, volvé a ejecutarlo: lo ya descargado queda en `tools/.cache/` y sigue donde quedó.
- Si una carta queda mal (posición, rol, dorsal…), corregila en `tools/ajustes_cartas.json` por su id
  (`{nbaPlayerId}-{franquicia}-{época}`, p. ej. `977-LAL-00`) y volvé a ejecutar el script.
- Tests del script, sin internet: `python -m unittest discover tools`

## Estructura

```
lib/
├── core/          URLs del CDN de la NBA y caché de imágenes en disco
├── domain/        Modelos inmutables en Dart puro (sin Flutter): Jugador, Franquicia,
│                  Plantel (regla de no duplicación), Táctica, Partido, Temporada
├── data/          30 franquicias, carga del catálogo JSON, SQLite para partidas guardadas
└── presentation/  Widgets (foto del jugador con fallback)
assets/database/   Catálogo de cartas empaquetado en la app
tools/             Script de extracción de datos (Python + nba_api)
```
