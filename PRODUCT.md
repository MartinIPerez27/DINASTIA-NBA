# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users

Un único jugador: el dueño del proyecto, fan de la NBA que conoce jugadores, épocas y jerga.
Juega en su celular Android, en ratos libres. No hace falta explicar términos de básquet.

## Product Purpose

Dinastía NBA (82-0) es un juego personal de draft roguelike y gestión táctica: elegís una franquicia,
armás un quinteto + Sexto Hombre con un tragamonedas de leyendas por época, y buscás la temporada
perfecta de 82-0 y el anillo en Playoffs. El éxito es que sea divertido de rejugar y fiel a la historia.

## Positioning

El jugador no gestiona un equipo genérico: devuelve la gloria a una franquicia real con cartas
jugador + franquicia + época, cuyos números salen de ese tramo de su carrera real.

## Operating Context

- 100% offline una vez descargadas las fotos; gratis, sin compras ni publicidad.
- Se instala por APK desde GitHub Releases (sin Play Store).
- El GDD (`documento_maestro_gdd_82_0_2.md`, en poder del usuario) es la fuente de verdad de reglas.

## Capabilities and Constraints

- Flutter, solo Android por ahora (iPhone no está en el alcance).
- Posiciones y estadísticas en español: BASE, ESCOLTA, ALERO, ALA-PÍVOT, PÍVOT, SEXTO HOMBRE; PPP, RPP, APP, ROB/P, TAP/P, %TC, %T3, %TL, IQ.
- Fotos y escudos del CDN público de la NBA; catálogo generado con `tools/extraer_cartas.py`.

## Brand Commitments

- Voz: voseo rioplatense ("Elegí tu franquicia", "Armá tu quinteto").
- La interfaz adopta los colores y el escudo de la franquicia elegida (GDD §2).
- Debe evitar parecer una planilla/app de estadísticas y también un casino barato de brillos y neón.

## Evidence on Hand

- 30 franquicias con colores oficiales (`lib/data/franquicias.dart`) y escudos SVG del CDN.
- Catálogo de cartas provisorio de 14 jugadores (`assets/database/nba_players.json`); el real se genera aparte.
- No hay arte propio, tipografías ni íconos de marca todavía.

## Product Principles

1. Fiel a la historia: cada número y posición tiene que poder rastrearse a la carrera real.
2. Identidad de franquicia en todo: el equipo elegido tiñe la experiencia.
3. Suspenso sin spoilers: el resultado se descubre jugando.
4. Pocas pantallas, decisiones rápidas: se juega en ratos libres.
