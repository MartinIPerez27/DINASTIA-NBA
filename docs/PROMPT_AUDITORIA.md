# Prompt para la auditoría (pegar junto con `TRASPASO_COMPLETO.md` y el repositorio)

Copiá todo lo que está debajo de la línea y pegalo en el chat, adjuntando `docs/TRASPASO_COMPLETO.md` y el repositorio (`MartinIPerez27/DINASTIA-NBA`, rama `main`, commit `f276184` o posterior).

---

Actuá como un equipo senior de auditoría formado por: ingeniero Flutter/Dart, diseñador de sistemas de juego (game designer de simuladores deportivos y juegos de cartas), ingeniero de datos deportivos, diseñador de producto/UX móvil y especialista en QA. Hablá en **español rioplatense (voseo)**.

## Contexto
Te adjunto `TRASPASO_COMPLETO.md` (estado completo del proyecto, decisiones, pendientes y riesgos) y el repositorio. Es "Dinastía NBA (82-0)": un juego de Android hecho en Flutter. Es un roguelike de draft de cartas NBA (11.323 cartas históricas) + simulador de temporada y playoffs, con motor de partido por posesiones, partido en vivo 2D animado, 34 modos de juego y un metajuego (XP, monedas, álbum, misiones, pase, cosméticos). Leé primero el documento de traspaso completo y después verificá lo que afirma contra el código real. **No des por cierto nada del documento sin comprobarlo** (decime dónde el documento miente, exagera o está desactualizado).

## Cambio importante de restricción
Hasta ahora el juego era **100 % offline y gratis**. **Eso ya no es una restricción dura**: al dueño no le importa que el juego use internet. Puede buscar o necesitar conexión para mejorar los modos (por ejemplo: estadísticas y resultados reales actualizados para Fantasy NBA, actualización del catálogo de cartas, desafíos y rankings compartidos entre jugadores, fotos, calendarios reales). Seguí estas reglas:
- Proponé soluciones online cuando sean claramente mejores, pero **indicá siempre qué pasa sin conexión** (degradación elegante) y cuánto cuesta.
- **Preferí fuentes y servicios gratuitos**. Si una alternativa cuesta plata, marcala explícitamente y dame también una alternativa gratuita.
- **Privacidad:** no se puede enviar el email ni datos personales del dueño a servicios externos. Cualquier backend o analítica tiene que justificarse y ser mínimo.
- Verificá licencias y términos de uso de cualquier API, dataset o imagen (NBA, Basketball-Reference, Wikipedia) y avisame si algo es riesgoso. Es un proyecto personal pero el repositorio es público.

## Qué quiero que hagas
Auditá **todo lo construido** y entregá correcciones, mejoras y cosas nuevas. Cubrí al menos estas áreas, en este orden de prioridad:

1. **Corrección y bugs:** errores lógicos en el motor de partido, la liga, el draft, los 34 modos y el metajuego; casos borde (partidas viejas, JSON, cartas faltantes, ediciones concurrentes de estado); inconsistencias entre lo que el documento dice y lo que hace el código.
2. **Balance y simulación:** realismo estadístico (puntos por partido ≈ 101–105 hoy contra ≈ 110–115 de la NBA moderna), rangos de dificultad, calibración de los modos sin prueba de balance (Camino al anillo, Guantelete, Universitario, Conquista, Divisiones, etc.), riesgo de explotación (estrategias rotas), y la fórmula de medias/tiers del catálogo.
3. **Datos del catálogo:** calidad de medias y tiers, tramos por década, estadísticas estimadas, franquicias extintas sin uso (327 cartas), datos curados escritos de memoria (campeones 1977–2025 y situaciones clutch) que haya que contrastar con una fuente, y cobertura de fotos.
4. **Experiencia de usuario y diseño:** onboarding, descubribilidad de 34 modos, claridad de la UI, accesibilidad, rendimiento en gama media, tablet horizontal (no se probó en un dispositivo real), consistencia con el sistema de diseño "El Marcador" (`DESIGN.md`).
5. **Arquitectura y calidad de código:** archivos gigantes (`partido_pantalla.dart`, `motor.dart`, varios modos de 1.300–2.000 líneas), estado global estático, acoplamiento entre modos, duplicación, testabilidad, rendimiento (recorte de fotos en el hilo principal, serialización de `Temporada`), CI.
6. **Modos y contenido nuevo:** qué modos conviene mejorar, fusionar o eliminar; cómo hacer que el juego enganche a largo plazo (retención, progresión, meta); qué modos nuevos sumar (podés usar como inspiración EA FC, NBA 2K, Retro Bowl, Fantasy ESPN, Football Manager, Balatro, Slay the Spire, juegos de lógica y de trivia). Incluí lo que antes no se podía por ser offline.
7. **Funciones online posibles:** ranking global o entre amigos, desafío del día compartido, Fantasy con estadísticas reales, actualización remota del catálogo y de los datos de historia, copia de seguridad en la nube, código de reto con servidor. Evaluá costo, complejidad y riesgos de cada una.

## Reglas obligatorias para cada hallazgo
Para **cada** problema o propuesta, usá exactamente este formato:

- **ID y título.**
- **Severidad / impacto** (crítico, alto, medio, bajo) y **esfuerzo estimado** (S, M, L, XL).
- **Evidencia:** archivo y línea, o prueba/medición concreta, o cita del documento. Si es una hipótesis que no pudiste comprobar, marcala como tal.
- **Cómo lo harías:** pasos concretos, archivos a tocar, cambios en los modelos de datos, y cómo lo probarías.
- **Al menos 3 alternativas** distintas para resolverlo (no variaciones de lo mismo), cada una con **ventajas, desventajas, costo, riesgo y qué pasa sin conexión**. Marcá cuál recomendás y por qué.
- **Dependencias y riesgos de regresión** (qué se rompe o se descalibra: balance, códigos de reto, partidas guardadas, versión del catálogo).

Si un hallazgo es trivial, igual dame las 3 alternativas, aunque sean breves.

## Entregables
1. **Resumen ejecutivo** (máx. una página): estado general, 5 mayores riesgos, 5 mayores oportunidades.
2. **Lista priorizada de hallazgos** en el formato de arriba, agrupada por las 7 áreas.
3. **Hoja de ruta** en tandas (Corto / Medio / Largo plazo) con orden de ejecución, dependencias y estimación.
4. **Sección "lo que el documento de traspaso no dice o dice mal"**.
5. **Lista de preguntas** al dueño para las decisiones que dependen de sus gustos (con tu recomendación para cada una).
6. Para las 10 mejoras más valiosas: un **prompt listo para pegar en un agente de código** (con archivos a tocar, criterios de aceptación y pruebas), que respete las reglas del proyecto (abajo).

## Reglas del proyecto que tus propuestas deben respetar
- Voseo rioplatense en toda la UI. Estilo "El Marcador" (LED, sin sombras, contraste ≥ 4,5:1, `TextoLed` para números).
- **IDs de cartas estables:** no cambiar ni borrar IDs (partidas guardadas, álbum y rivales los usan). Cualquier cambio de medias/tiers/cartas exige: versión del catálogo, recalibrar el balance (`test/balance_test.dart`) y avisar del efecto en códigos de reto y Desafío del día.
- **JSON retrocompatible:** campos nuevos opcionales, escritos solo si no están vacíos.
- **Sin dorsales** (todos o ninguno; hoy ninguno). Las **evoluciones de cartas** solo afectan a los modos que usan el álbum. Cada tramo (franquicia + década) es su propia carta y se muestra con sus temporadas.
- El teléfono (vertical) debe seguir funcionando igual; hay diseño de tablet horizontal con `esTabletApaisada`.
- Archivos compartidos (`motor.dart`, `liga.dart`, `perfil.dart`, `progreso.dart`, `temporada.dart`, `modos.dart`, `main.dart`) se editan de forma mínima y aditiva.
- Cada cambio se valida con: `flutter analyze` limpio, `flutter test` completo, capturas revisadas y, si toca el motor o las medias, el test de balance.

## Cómo trabajar
- Corré lo que puedas (`flutter pub get`, `flutter analyze`, `flutter test`, `python3 -m unittest discover tools`) y medí en lugar de opinar cuando sea posible. Mostrá los números.
- Distinguí claramente: **hecho comprobado**, **hipótesis** y **opinión**.
- No inventes datos NBA. Si citás hechos deportivos, indicá la fuente o decí que no la verificaste.
- Priorizá por impacto en la experiencia del jugador, no por elegancia técnica.
- No hagas cambios en el repositorio en esta fase: **solo auditoría y propuestas**, salvo que te lo pida después.
