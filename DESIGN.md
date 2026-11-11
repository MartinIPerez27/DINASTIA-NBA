---
name: Dinastía NBA (82-0)
description: El marcador central del estadio, encendido con los colores de tu franquicia.
colors:
  panel-mate: "#0F1012"
  superficie-tenida: "#1A1015"
  led-encendido: "#ED2558"
  sobre-led: "#000000"
typography:
  display:
    fontFamily: "BigShouldersDisplay, Roboto, sans-serif"
    fontSize: "76px"
    fontWeight: 800
    lineHeight: 0.9
    letterSpacing: "0px"
  headline:
    fontFamily: "BigShouldersDisplay, Roboto, sans-serif"
    fontSize: "24px"
    fontWeight: 600
    lineHeight: 1.33
    letterSpacing: "0.5px"
  title:
    fontFamily: "BigShouldersDisplay, Roboto, sans-serif"
    fontSize: "24px"
    fontWeight: 800
    lineHeight: 1.33
    letterSpacing: "3px"
  led-marcador:
    fontFamily: "Doto, monospace"
    fontSize: "44px"
    fontWeight: 800
    lineHeight: 1
    fontFeature: "tnum"
  led-sigla:
    fontFamily: "Doto, monospace"
    fontSize: "18px"
    fontWeight: 800
    lineHeight: 1
    fontFeature: "tnum"
  label-boton:
    fontFamily: "BigShouldersDisplay, Roboto, sans-serif"
    fontSize: "20px"
    fontWeight: 700
    letterSpacing: "1px"
  body:
    fontFamily: "Roboto, sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.43
    letterSpacing: "0.25px"
rounded:
  indicador: "2px"
  toque: "12px"
  tablero: "16px"
  pastilla: "9999px"
spacing:
  xs: "6px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  tablero: "20px"
components:
  boton-dirigir:
    backgroundColor: "{colors.led-encendido}"
    textColor: "{colors.sobre-led}"
    typography: "{typography.label-boton}"
    rounded: "{rounded.pastilla}"
    height: "56px"
  boton-seguir:
    textColor: "{colors.led-encendido}"
    rounded: "{rounded.pastilla}"
    height: "48px"
  tablero:
    backgroundColor: "{colors.panel-mate}"
    rounded: "{rounded.tablero}"
    padding: "20px"
  cinta-item:
    rounded: "{rounded.toque}"
    width: "72px"
    height: "92px"
  cinta-indicador:
    backgroundColor: "{colors.led-encendido}"
    rounded: "{rounded.indicador}"
    width: "28px"
    height: "3px"
---

# Design System: Dinastía NBA (82-0)

## Overview

**Creative North Star: "El Marcador"**

La app es el tablero central colgado sobre la cancha. Todo sucede sobre un panel mate casi negro; lo que importa se enciende en puntos LED del color de la franquicia y lo que no está activo queda como LED apagado, presente pero tenue. Elegir un equipo es encender el tablero: el tema completo de Material 3 se recalcula a partir de la franquicia enfocada y cruza de un equipo a otro en 250 ms.

La jerarquía sale casi solo del tamaño de letra: el nombre del equipo en condensada de cartelería de estadio a 76 px domina, la ciudad va arriba más chica y apagada, y el resto es cuerpo en Roboto. La densidad es baja, de pocas decisiones grandes por pantalla: un tablero que ocupa todo el alto disponible, un selector de conferencia, una cinta de siglas y un botón principal de ancho completo. Es una app oscura por diseño, sin modo claro.

El sistema no tiene color de marca fijo. El color propio es el de la franquicia, filtrado por una regla de legibilidad: sobre el panel, el LED encendido siempre mide al menos 4.5:1. Profundidad sin sombras, sin brillos, sin desenfoque.

**Key Characteristics:**
- Panel mate #0F1012 con un 6% del color principal del equipo como superficie general.
- Un único acento dinámico: el color LED de la franquicia, elegido por contraste.
- Tres voces tipográficas: puntos LED (Doto) para números y siglas, condensada de estadio (Big Shoulders Display) para nombres, Roboto para leer.
- Estados encendido/apagado como lenguaje de selección.
- Movimiento corto y sobrio, que se anula con la preferencia de animaciones reducidas.

## Colors

Un panel casi negro, constante, y un solo color vivo que cambia con la franquicia; los valores de la frontmatter son los del equipo por defecto (Chicago Bulls).

### Primary
- **LED Encendido** (dinámico; Bulls `led-encendido`): el color de los puntos encendidos. Se usa en el marcador "82-0", la sigla enfocada de la cinta, el indicador bajo la sigla, el botón principal y como semilla del esquema Material 3 (`DynamicSchemeVariant.fidelity`, brillo oscuro). Se calcula así: se toma el color principal del uniforme y se aclara de a 2% de luminosidad HSL hasta llegar a 4.5:1 contra el panel. Si el principal es poco saturado (≤25%, negros y grises) o hubo que aclararlo más de 20 puntos, se usa el secundario, también aclarado; si el secundario tampoco llega a 4.5:1, se vuelve al principal aclarado. Ejemplos del código actual: Celtics verde aclarado, Lakers oro, Nets blanco, Spurs plata, Warriors oro.

### Neutral
- **Panel Mate** (`panel-mate`): el material del tablero. Es el fondo del tablero (`surfaceContainerLowest`) y la referencia de todo cálculo de contraste. No cambia entre equipos.
- **Superficie Teñida** (dinámica; Bulls `superficie-tenida`): el panel con el color principal del equipo mezclado al 6%. Es el fondo del scaffold y el `surface` del esquema. El tablero queda apenas más oscuro y neutro que su entorno.
- **Sobre LED** (`sobre-led`): texto sobre el LED encendido; se elige entre negro y blanco por mayor contraste. Con los 30 colores actuales siempre resulta negro.
- **Textos y bordes**: `onSurface`, `onSurfaceVariant` y `outlineVariant` salen del esquema Material 3 generado desde el LED, así que tienen un leve tinte del equipo. No se fijan a mano.

### Named Rules
**The 4.5 Rule.** Ningún LED encendido mide menos de 4.5:1 contra el panel #0F1012. Un color nuevo de equipo pasa por `colorLed()`; nunca se pinta el hex del uniforme directamente.

**The One Light Rule.** El LED es el único color vivo de la interfaz. Los escudos traen sus propios colores; el resto es panel, texto tintado y LED apagado.

**The Re-Tint Rule.** El tema se deriva de la franquicia enfocada, no de la elegida: al recorrer equipos toda la app cambia de color en vivo (250 ms, `easeOutCubic`) antes de confirmar.

## Typography

**Display Font:** Big Shoulders Display (variable, empaquetada; respaldo Roboto)
**Body Font:** Roboto (sistema Android)
**Label/Mono Font:** Doto (variable, puntos LED, empaquetada)

**Character:** Doto es la matriz de puntos del tablero: números y siglas, nunca prosa. Big Shoulders es la cartelería condensada del estadio, siempre en mayúsculas. Roboto se queda con lo que hay que leer de corrido.

### Hierarchy
- **Display** (Big Shoulders 800, 76 px, interlineado 0.9): el nombre de la franquicia en el tablero, en mayúsculas, una línea, se achica para entrar (`FittedBox`).
- **Headline** (Big Shoulders 600, 24 px, +0.5 px): la ciudad sobre el nombre, en mayúsculas y color `onSurfaceVariant`.
- **Title** (Big Shoulders 800, 24 px, +3 px): la marca "DINASTÍA" del encabezado.
- **LED Marcador** (Doto 800, 44 px, cifras tabulares): el "82-0" del encabezado.
- **LED Sigla** (Doto 800, 18 px, cifras tabulares): las siglas de equipo en la cinta.
- **Label Botón** (Big Shoulders 700, 20 px, +1 px, mayúsculas): el texto del botón principal.
- **Body** (Roboto 400, 14/20 px): la línea de conferencia y división, textos auxiliares.

### Named Rules
**The Ghost Digit Rule.** Todo texto LED lleva detrás su versión apagada: cada cifra reemplazada por "8" en el mismo color al 12% de opacidad, como los segmentos sin encender de un tablero real. Las letras se dibujan sin fantasma.

**The Dots Are For Numbers Rule.** Doto solo para cifras, marcadores y siglas de tres letras. Nombres en Big Shoulders; frases en Roboto.

## Layout

Una sola columna centrada, con ancho máximo de 560 dp y márgenes de 16 dp a los costados, 12 dp arriba y 16 dp abajo, dentro de `SafeArea` con la app en modo edge-to-edge. El tablero se expande para ocupar todo el alto sobrante; los controles quedan anclados abajo, al alcance del pulgar. El ritmo vertical usa 16 dp entre bloques mayores y 8 o 12 dp entre controles relacionados.

Dentro del tablero el escudo mide la mitad de la altura del panel (entre 72 y 280 dp), con un espacio del 15% de su tamaño hasta la ciudad, y el bloque completo se escala hacia abajo en pantallas bajas (360x640) en vez de desbordarse. La cinta es una lista horizontal desplazable con ítems de 72x92 dp; al cambiar de equipo, el ítem enfocado se centra solo (250 ms).

Los objetivos táctiles miden 48 dp como mínimo: 56 dp el botón principal, 48 dp el secundario, 72x92 dp cada ítem de la cinta.

## Elevation & Depth

Plano. No hay sombras en ningún elemento propio. La profundidad sale de capas tonales: la superficie teñida al fondo, el tablero un paso más oscuro y neutro con un borde fino (`outlineVariant` al 50%), y adentro una grilla de LED apagados (puntos de 1.2 px de radio cada 7 px, `onSurface` al 5%) que da textura de panel sin brillo.

### Named Rules
**The Matte Panel Rule.** Sin glow, sin blur, sin sombras: un LED encendido se distingue por color y opacidad, nunca por resplandor.

## Shapes

Esquinas suaves y pocas. El tablero tiene radio de 16 dp y borde de 1 dp; la respuesta táctil de los ítems de la cinta, 12 dp; el indicador LED, 2 dp. Los botones y el selector de conferencia conservan la forma de pastilla de Material 3. Los escudos son SVG oficiales sin recorte ni marco.

## Components

### Buttons
Grandes, de ancho completo, con voz de cartel.
- **Shape:** pastilla (Material 3 por defecto).
- **Primary ("Dirigir a los …"):** `FilledButton` de 56 dp de alto, fondo LED, texto sobre-LED en Big Shoulders 700 a 20 px en mayúsculas. Hay uno por pantalla: confirma la franquicia.
- **Secondary ("Seguir la temporada de los …"):** `OutlinedButton` de 48 dp, solo aparece si hay una temporada guardada, en tipografía Material por defecto, encima del principal.
- **Hover / Focus:** capas de estado de Material 3, sin cambios propios.

### Chips (selector de conferencia)
- **Style:** `SegmentedButton` de Material 3 con "Este" y "Oeste", sin ícono de selección. El segmento elegido toma `secondaryContainer` del esquema teñido.
- **State:** cambiar de conferencia enfoca su primera franquicia (y re-tiñe la app).

### Cards / Containers (el tablero)
- **Corner Style:** 16 dp.
- **Background:** panel mate, con la grilla de LED apagados encima.
- **Shadow Strategy:** ninguna (ver Elevation & Depth).
- **Border:** 1 dp, `outlineVariant` al 50%.
- **Internal Padding:** 20 dp.
- **Contenido:** escudo grande, ciudad, nombre display y línea "Conferencia · División".
- **Transición:** al cambiar de equipo el contenido sale y entra con fundido y un desplazamiento vertical del 3% en 220 ms (`easeOutCubic` al entrar, `easeInCubic` al salir).

### Navigation (la cinta LED)
La cinta que rodea el estadio: las franquicias de la conferencia actual como escudo de 36 dp, sigla LED y un indicador.
- **Encendida:** escudo opaco, sigla en color LED, indicador de 28x3 dp en LED.
- **Apagada:** escudo al 45% de opacidad, sigla en `onSurfaceVariant` (≥ 4.5:1 sobre el tablero, verificado en test), indicador de ancho 0.
- **Transición:** opacidad e indicador animan en 150 ms; tocar emite `HapticFeedback.selectionClick`.
- **Accesibilidad:** cada ítem se anuncia como botón con el nombre completo y su estado de selección.

### Texto LED (componente firma)
`TextoLed`: texto en Doto 800 con cifras tabulares, color LED por defecto, apilado sobre su fantasma de "8" al 12%. Se lee como una sola etiqueta para lectores de pantalla. Se usa en el marcador del encabezado (44 px) y en las siglas (18 px).

### Escudo
SVG oficial empaquetado en `assets/logos` (funciona offline), cuadrado, con etiqueta "Escudo de …". Nunca se tiñe ni se recorta.

## Do's and Don'ts

### Do:
- **Do** derivar todo color de la franquicia con `temaFranquicia()` y `colorLed()`; el LED siempre a ≥4.5:1 sobre #0F1012.
- **Do** usar el par encendido/apagado para la selección: el elemento activo en color LED y opaco, los demás atenuados.
- **Do** poner cifras y siglas con `TextoLed` (Doto con fantasma de "8" al 12%), y nombres en Big Shoulders en mayúsculas.
- **Do** respetar `MediaQuery.disableAnimationsOf`: con animaciones reducidas, las duraciones pasan a cero.
- **Do** mantener objetivos táctiles de 48 dp como mínimo y un único botón principal de 56 dp por pantalla.

### Don't:
- **Don't** usar glow, blur, sombras ni degradados decorativos: el panel es mate.
- **Don't** pintar el hex del uniforme directo sobre el panel sin pasar por la regla de contraste.
- **Don't** usar Doto para frases ni Roboto para nombres de equipo.
- **Don't** agregar un segundo color de acento fijo: el único color vivo es el LED de la franquicia.
