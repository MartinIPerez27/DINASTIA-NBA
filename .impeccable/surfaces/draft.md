# Superficie: Draft — cancha con siluetas y tragamonedas

Modo: experience · Plataforma: android · Mundo: El Marcador (heredado, ver DESIGN.md)
Composición fijada por el GDD §4 (no se sorteó): media cancha de parqué con escudo en el círculo
central, 5 siluetas de camiseta en sus posiciones y el Sexto Hombre; abajo, 3 carretes LED con
RETENER y las cartas que salieron.

Decisiones de juego (el GDD no las fija): ver `lib/domain/draft.dart`.
- Los carretes solo frenan en combinaciones con al menos una carta que entre.
- Rareza 6/3/1 (A/S/S+). Retener solo al volver a tirar (1 ficha), hasta 2 carretes.
- La tirada se guarda al instante.

Momento propio: al ubicar una carta, la camiseta se "enciende" en el LED y se apaga (700 ms).
Las fichas de Reroll son LED del equipo (un solo color vivo, DESIGN.md), no doradas.

## Revisión (pedido del usuario: cancha "muy básica")
- Rareza estilo 82-0: franquicia + época definen el plantel; el carrete de rareza garantiza
  al menos una carta de ese Tier (aparece primera).
- Puesto ocupado = mini carta con foto, Tier LED y placa con dorsal y apellido en el uniforme.
- Cancha: borde en el color del equipo con su nombre en la línea de fondo (GDD §2), vetas de
  madera, escudo pintado en el piso, marcas de la zona. Excepción al "sin degradados" de
  DESIGN.md: la penumbra radial de la luz del estadio es iluminación de la escena, no decoración.
- Cartas: PPP/RPP/APP/IQ; mantener apretado abre la ficha con las 11 estadísticas y el rol.
