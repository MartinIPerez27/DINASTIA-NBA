# Mi carrera — Plan de la tercera tanda (decidido con el usuario)

Estado: **aprobado, sin implementar**. Cada bloque se hace por separado, con APK al final. Lo decidido está
marcado como ✔; lo que sigue abierto, como ❓.

## Diagnóstico que originó el plan
- **Puntos de temporada**: el tope por edad (12 hasta los 23 años) recortaba a un jugador de 30/13/6 de ~17 a 12.
- **Costos**: el "techo blando" multiplicaba ×2 (hasta ×6) el costo base cuando la media pasaba el techo por edad:
  subir de 85 a 89 costaba 6 × 2 = 12. Escala base: <60:1, 60–69:2, 70–77:3, 78–84:4, 85–89:6, 90–94:9, 95+:14.
- **Año/plantilla**: un jugador creado arranca en 2026; uno real, en su año de draft. La temporada N cierra en
  `anioBase + N` y de ese año sale la época. 7 compañeros de la franquicia: cada receso cada uno se queda con 70 %.
- **Decisiones en vivo**: son opciones sobre el motor; el resultado lo resuelve el motor solo.

## Decisiones

### 1. Puntos de temporada ✔ (opción C)
- Sacar el tope por edad (queda un seguro altísimo, ~30) y curva suave.
- **Calificación por partido** (D a A+) según tu línea y si ganó el equipo: A+ ≈ 1,5 puntos, C ≈ 0,3.
- Objetivo: ~25–35 puntos en una temporada buena.

### 3. Costos ✔ (A + C)
- Multiplicador del techo blando: ×1,25 por punto de exceso, máximo ×2.
- El techo depende solo del **potencial** (no de la edad): un joven con potencial 95 no se frena a los 22.
- Si después sigue caro, suavizar la escala base (1/1/2/3/4/6/8).

### 2. Objetivos ✔ (todo lo propuesto)
- Pool de ~25 tipos en 5 familias: estadística, equipo, personal, vestuario, carrera.
- Objetivos de temporada en 4 niveles (fácil 1, normal 2, difícil 4, élite 6 puntos); elegís cuántos aceptás (4–6).
- Objetivos de carrera (varios años): 10.000 puntos, primer anillo, mejor quinteto ×3…
- Mini-objetivos por mes.

### 4. Premios ✔ (todo lo propuesto)
- Por estadística: Jugador de la semana (Este/Oeste), Jugador del mes, Novato del año, Novato del mes,
  Quinteto de novatos, MVP de Finales, Clutch Player, All-Defensive, líderes de la liga.
- Con minijuego (después del punto 8): Concurso de volcadas y de triples del fin de semana All-Star.

### 5. Estadísticas estilo NBA2K ✔ (A + B + C)
- ~36 habilidades con nombres de 2K (bandeja, volcada, tiro cercano, media distancia, triple, libre, pelota,
  velocidad con pelota, pase, visión, defensa perimetral/interior, robo, tapón, rebote ofensivo/defensivo,
  velocidad, fuerza, salto, resistencia, agilidad…).
- Rasgos mentales: Consistencia, Clutch, Durabilidad, Garra.
- Las nuevas afectan al **motor** (no solo a las estadísticas finales).
- ❓ Confirmar si además quiere más estadísticas de partido (+/-, minutos…).

### 6. Año de inicio y plantilla ✔ (A + B + C + elegir edad)
- Pantalla **"Mi equipo"**: quién llegó y quién se fue cada año, y por qué.
- **Elegir el año de inicio** (2026 o época clásica) y la **edad de inicio** del jugador al crearlo.
- Rotación con edad y contratos: los compañeros envejecen, se retiran, llegan novatos del draft.

### 7. Edición de personaje ✔ (A + B + C)
- Rasgos: ojos, cejas, nariz, boca, orejas, ~20 peinados, tipos de barba, tatuajes, vincha, muñequeras, gafas.
- Cuerpo y estilo: complexión, envergadura, mano dominante, origen (secundario, universidad, internacional), número.
- Estilo de juego: forma de tirar, festejos.

### 8. Control del jugador ✔ (todo lo propuesto)
- **Barra de tiro**: el timing da Perfecto / Bueno / Temprano / Tarde; la zona verde es más ancha con mejor habilidad.
- Timing también en tiros libres, robo, tapón y rebote; pase.
- Acciones importantes por defecto, con opción de activarlo en todos tus tiros y modo automático.
- **Quitar todo lo de entrenador** en Mi carrera (AJUSTES, playbook, rotaciones, minutos).
- Técnica: partir la resolución del tiro en el motor en dos pasos (va a tirar → timing → resolución).

### Más ideas ✔ (todas)
Entrenamientos interactivos · contratos y mercado (salario, tope, agencia libre) · rivales y mentores · informe de
scouting · camino a hitos · rehabilitación de lesiones · prensa y redes con consecuencias · fin de semana All-Star
jugable · Salón de la Fama con cuadro de honor por generación.

### Récords históricos ✔ (pedido nuevo)
- Tu jugador compite contra los **récords reales** de la NBA: carrera (puntos, rebotes, asistencias, robos,
  tapones, triples, triples-dobles), temporada (promedios), partido (puntos, rebotes, asistencias; partidos de 40+
  y 50+ puntos), rachas.
- Panel "Camino a los récords" con progreso, ritmo y cuándo lo alcanzarías.
- Los datos reales se cargan desde una fuente verificada (Basketball-Reference) y se revisan antes de usarlos.
- Hay que guardar el **mejor partido** y los hitos por partido en tu carrera (hoy solo se guardan totales por año).

### Ideas adicionales elegidas ✔
- **Compañero de generación**: una clase de draft que se sigue a lo largo de los años (el #1 de tu año, tu rival).
- **Camiseta y número**: elegir el número al crear el jugador; se retira junto con la camiseta.
- **Fecha límite de traspasos**, con rumores que se concretan.
- **Slots y exportación**: varias carreras en paralelo y copia de seguridad.
- No elegidas: dificultad de carrera, eras comparables, capítulos, álbum, reto del día, fantasma de leyenda,
  tarjeta para compartir, logros de carrera.

### Segunda ronda de ideas ✔ (todas aprobadas para implementar)
Desglose de puntos · bandeja de entrada · opciones de control de la barra de tiro · rivales que se adaptan ·
personalidad de jugador · química con compañeros · carga de partidos y cansancio · lesiones por partes del cuerpo ·
camino secundario→universidad→NBA · selección nacional (Mundial y Juegos Olímpicos) · carrera generacional ·
staff y agente · tu carta de carrera (cruce con álbum/Dinastía) · relator con memoria · mapa de tiro de carrera y
estadísticas avanzadas.

## Estado de implementación
- **Bloque 1 (puntos y costos) — hecho.** Rendimiento sin tope por edad (seguro 30), calificación de cada partido
  (D a A+) que acredita fracciones de punto, techo blando por potencial (recargo ×(1+0,5·exceso), máx. ×4, con el
  desgaste del cuerpo desde los 29), desglose de puntos en pantalla y contadores de carrera por partido
  (`uso`: `c:p30/p40/p50/td/dd`, `m:pts/reb/ast/rob/tap/t3`) que alimentan los récords.
  - Balance medido: un jugador de potencial 88 que gasta todo llega a ~94; con potencial 99 se mantiene en 99
    entre los 26 y los 34 años (antes 4 temporadas).
- **Bloque 2 (objetivos y premios) — hecho.**
  - Objetivos: 23 tipos en 4 familias (estadística, equipo, personal, vestuario) y 4 niveles (1/2/4/6 puntos).
    El DT ofrece 8 por temporada y aceptás de 4 a 6 hasta el primer partido (pantalla "Elegir objetivos").
    16 objetivos de carrera (10.000 puntos, anillos, All-Star, triples-dobles…) y un mini-objetivo cada 14 partidos.
  - Premios nuevos: Jugador de la semana (4 partidos) y del mes (14), Novato del año / del mes, Quinteto de novatos,
    MVP de las Finales, Clutch Player, All-Defensive y líderes de la liga. Se calculan contra la liga "hasta ahora"
    (aproximación honesta: no hay un registro semanal de toda la liga) y cada uno da puntos de habilidad.
  - Balance: recargo del techo blando ×(1+0,75·exceso), máx. ×5. Con potencial 88 y gasto óptimo se llega a ~96;
    con potencial 99 se mantiene en 99 hasta los ~35 años.
  - Faltan del punto 4: concurso de volcadas y de triples (dependen de la barra de tiro).
- **Bloque 3 (habilidades estilo 2K) — hecho.** 34 habilidades técnicas (tiro 5, finalización 7, defensa 7, físico 8,
  IQ y pase 7) y 4 rasgos mentales (Consistencia, Clutch, Durabilidad, Garra) bajo los 5 atributos; 7 insignias nuevas
  (33 en total). Cada habilidad mueve la carta que usa el motor; Durabilidad baja o sube la probabilidad de lesión
  (×0,7 a ×1,3) y las acciones del partido en vivo (triple, aro, pelota, última jugada, marca, robo, energía) usan las
  habilidades nuevas y el rasgo Clutch. Las partidas viejas cargan sin migración (las nuevas arrancan en el valor del
  atributo).
- **Bloque 4 (año, edad, plantilla, traspasos y generación) — hecho.**
  - Creador: año del draft (1980–2026), edad de arranque (18–28) y número de camiseta; el año define la época de
    compañeros y carta. El número se muestra al retirarse la camiseta.
  - Plantilla: edad de los compañeros (por año de nacimiento), contrato de 1 a 4 años, retiro desde los 35 con
    probabilidad creciente, traspasos y fin de contrato; las bajas se reemplazan (novatos del draft, agentes libres,
    traspasos). Todo queda en "Mi equipo" (`movimientos`).
  - Fecha límite de traspasos: rumor en el partido 35 y decisión en el 49 (quedarte, pedir el traspaso o extender el
    contrato); un rumor sobre un compañero se concreta con 60 % y cambia el plantel en plena temporada.
  - Mi generación: los primeros 8 elegidos de tu draft con números reales por época (hasta 2025) o una clase
    ficticia determinística para años sin datos (2026); el #1 es tu rival.
  - Pendiente de este punto: que el jugador "salga" mid-season por una decisión del club (hoy solo se mueven
    compañeros; el traspaso propio se negocia en el receso).

## Orden sugerido
1. Puntos y costos (1, 3) · 2. Objetivos y premios (2, 4) · 3. Habilidades 2K (5) · 4. Año, edad y plantilla (6)
· 5. Editor de personaje (7) · 6. Récords históricos · 7. Barra de tiro y control del jugador (8)
· 8. El resto de las ideas.
