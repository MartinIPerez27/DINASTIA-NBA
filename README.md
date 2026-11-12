# Dinastía NBA (82-0)

Draft roguelike y simulación de temporada NBA para celulares y tablets. 100% gratuito y offline.
El diseño completo está en el GDD; este repo avanza por fases (ahora: **Fase 4 — playbook con asistente de recomendación**).
Dirección visual: *El Marcador* (el tablero central del estadio), ver `PRODUCT.md` y `DESIGN.md`.

## Probarlo en el celular Android (sin instalar nada en la PC)

Cada cambio subido a `main` se compila solo en GitHub (pestaña **Actions**, unos 5–8 minutos) y el APK queda en
**Releases → Última versión**.

1. Desde el navegador del celular abrí:
   https://github.com/MartinIPerez27/DINASTIA-NBA/releases/download/ultima/dinastia-nba.apk
2. Al terminar la descarga, tocá el archivo. Android va a pedir permiso para **instalar apps desconocidas**
   desde el navegador: activalo solo para esa app y volvé atrás.
3. Tocá **Instalar** y abrí *Dinastía NBA*.

Para actualizar, repetí los mismos pasos: la versión nueva se instala encima y conserva los datos.
Si Play Protect avisa "app no verificada", elegí *Instalar de todas formas* (es tu propia app, sin firmar en Play Store).

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
git clone https://github.com/MartinIPerez27/DINASTIA-NBA.git
cd DINASTIA-NBA
flutter pub get
flutter test
```

Para ver la app, abrí un emulador desde Android Studio (*Device Manager → ▶*) o conectá tu celular Android
con *Depuración USB* activada, y ejecutá:

```bash
flutter run
```

La app arranca en el tablero: recorré las franquicias en la cinta LED, la app se tiñe con cada una, y "Dirigir a…" te deja elegir cómo armar el plantel: **Ruleta** (3 carretes estilo 82-0: franquicia, época y rareza; retené hasta 2 al volver a tirar) o **Cartas** (tocá un puesto y fichá 1 de 5 cartas reveladas). Con el plantel completo, el playbook recomienda tácticas.

> **Sin Android Studio (solo Windows):** `flutter create --platforms=windows .` y después `flutter run -d windows`
> (requiere Visual Studio con "Desarrollo para el escritorio con C++"). La versión web no muestra las fotos porque el
> CDN de la NBA no permite CORS.

## Catálogo de cartas

`assets/database/nba_players.json` trae **11.323 cartas** de toda la historia (desde 1946-47): 74 S+, 161 S,
3004 A y 8084 B, unas 53 por franquicia y época. Las genera `tools/catalogo_bbref.py` desde datos públicos de
Basketball-Reference ([sumitrodatta/bball-reference-datasets](https://github.com/sumitrodatta/bball-reference-datasets)).

Cada carta es **jugador + franquicia + década** con al menos 20 partidos en ese tramo, y todo se calcula solo
con esas temporadas:

| Campo | Cómo se calcula |
| --- | --- |
| Identidad | El equipo con el que jugó: Thunder en los 90 es **Seattle SuperSonics**; también Bullets, Royals, Braves, New Jersey Nets y los extintos de los 40/50 (Chicago Stags…). |
| Estadísticas | Totales del tramo ÷ partidos. Lo que la NBA no registraba (robos/tapones antes de 1974, pérdidas antes de 1978, rebotes y minutos en los 40) se estima por posición y se marca con "~". Sin triples antes de 1980. |
| Posiciones | Las que jugó en esas temporadas + la vecina que su perfil cubre. |
| Tier | **S+/S/A** por premios (MVP, MVP de Finales, All-NBA, DPOY, 6.º Hombre, All-Star); sin premios, **A** si fue titular productivo y **B (Rotación)** si no. |
| Media (60–99) | Eficiencia corregida por época + premios. |
| Arquetipo | Uno de los 24 del GDD según su perfil por 36 minutos (+ correcciones a mano para leyendas). |
| Foto | 1) CDN de la NBA (si no es la silueta genérica), 2) Basketball-Reference, 3) Wikipedia (la busca la app desde el celular), 4) iniciales. |

```bash
python -m pip install nba_api
python tools/fotos.py
python tools/catalogo_bbref.py
```

- Correcciones a mano (dorsal, posiciones, rol, excluir una carta) en `tools/ajustes_cartas.json`, por id
  de carta (`{id_bbref}-{franquicia}-{época}`, p. ej. `bryanko01-LAL-00`). El dataset no trae dorsales:
  sin dato, la app no muestra número.
- `tools/extraer_cartas.py` es la alternativa con `nba_api` (necesita una PC personal) y aporta las reglas
  que reutiliza `catalogo_bbref.py`.
- Tests sin internet: `python -m unittest discover tools`

## Estructura

```
lib/
├── core/          URLs del CDN de la NBA y caché de imágenes en disco
├── domain/        Modelos inmutables en Dart puro (sin Flutter): Jugador, Franquicia,
│                  Plantel (regla de no duplicación), Táctica, Partido, Temporada
├── data/          30 franquicias, carga del catálogo JSON, SQLite para partidas guardadas
└── presentation/  Tema por franquicia, pantallas (inicio, draft) y widgets (LED, escudo, foto)
assets/database/   Catálogo de cartas empaquetado en la app
assets/logos/      30 escudos oficiales en SVG (regenerar: python tools/normalizar_escudos.py)
assets/fonts/      Doto (LED) y Big Shoulders Display (estadio), licencia OFL
tools/             Scripts de datos (Python): catálogo de cartas y escudos del CDN
capturas/          Capturas de pantalla con tipografías reales: flutter test capturas --update-goldens
```
