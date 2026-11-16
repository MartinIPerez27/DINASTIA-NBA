# Estilo de narración (brief para la ronda de simulación)

**Pedido del dueño:** usar el estilo de narración de transmisiones de ESPN para Latinoamérica con una dupla: uno técnico y uno coloquial.

## Reglas
- Son **dos personajes propios**: el **Relator** y el **Comentarista**. No se nombra a personas reales en la UI ni se les atribuyen frases.
- Las frases son **originales** o variaciones de expresiones comunes del básquet en español. Las referencias de abajo se usan para calibrar el tono, no para copiarlas literalmente.
- No se imitan voces: la voz opcional usa dos voces distintas del motor de voz del sistema (`flutter_tts`), una por personaje.
- Voseo rioplatense en el Comentarista; el Relator usa un español más neutro y preciso.

## Roles
| Personaje | Rol | Tono |
|---|---|---|
| **Relator** | Canta la jugada y aporta el rigor técnico: léxico preciso del básquet, análisis táctico (rotaciones, defensa, ritmo, reloj de posesión), datos del partido. | Sereno, preciso; sube la intensidad en el cierre apretado y en los playoffs ("no hay mañana"). |
| **Comentarista** | Color y espontaneidad: humor rioplatense, remates coloquiales, reacciones ("no te la puedo creer"), temperatura del partido. | Cercano, divertido, exclamativo. Abre y retoma el comentario cuando el partido está parejo. |

## Referencias de tono (aportadas por el dueño, sin verificar su autoría)
**Relator técnico:** sacar la bola de la mano cuando se amasa el balón y se consume el reloj · "no hay mañana" en partidos de eliminación · de costa a costa (rebote y cruce de cancha hasta anotar) · triple desde muy lejos ("desde el estacionamiento") · ladrillo en un tiro muy desviado · tapón contundente en la pintura · tirador encendido tras 3–4 triples seguidos · queja ante una falta rigurosa · tiempo pedido para "detener la hemorragia" tras un parcial en contra · la línea de los suspiros (tiros libres en cierres apretados).

**Comentarista:** "¡a cobrar!" (anota con falta y va al libre adicional, o liquida) · grito de triple clave en el cierre · asombro ante una volcada espectacular · "se picó el partido" (empujones, técnicas, temperatura) · incredulidad ante una pérdida insólita o un tiro fallado solo debajo del aro · "modo bestia" (estrella dominando ambos lados) · tiro que pega fuerte en el aro (le sacó pintura) · sentencia de Curry en el último cuarto ("a dormir") · crossover que deja desairado al defensor ("qué baile le pegó") · apertura "partidazo tenemos en [ciudad]".

## Qué se construye
1. **Diálogo de dos voces** alternado y contextual: el Relator canta, el Comentarista reacciona; no responden a cada jugada (ritmo natural, con silencios).
2. **Catálogo de frases por situación** (volcada, triple, triple de cierre, tapón, robo, pérdida insólita, ladrillo, libre, falta técnica, parcial en contra, tiempo muerto, remontada, final apretado, racha del tirador, jugador dominante, partido parejo/picado, playoffs, rivalidad, récord) con varias variantes cada una, sin repetirse seguido.
3. **Contexto:** marcador y momento del partido, rachas, historial entre los equipos, récords en juego, lesión o expulsión, fatiga, la historia de la temporada (noticias del Hub).
4. **Intensidad dinámica:** el tono sube en el último cuarto, en playoffs y con partido parejo.
5. **Ajuste del usuario:** relato completo, solo relator, o solo texto; voz opcional con dos voces.
6. Pruebas: ninguna frase vacía, variedad mínima (no repetir la misma en N jugadas), todas las situaciones cubiertas, y cada situación solo se dispara cuando corresponde.

Se implementa en la segunda ronda junto con la animación, la cámara, el público, las decisiones durante el partido y las historias entre partidos.
