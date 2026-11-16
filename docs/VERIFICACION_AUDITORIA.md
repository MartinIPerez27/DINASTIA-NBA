# Verificación independiente de la auditoría externa

- **Informe verificado:** `AUDITORIA_EXTERNA.md` (commit auditado `c453f39`).
- **Cómo se verificó:** 8 verificadores independientes, cada uno con su copia aislada del repo y un tramo del informe. Reprodujeron las mediciones con semillas fijas y escribieron tests temporales ya borrados. El detalle por hallazgo está en `docs/verificacion/A*.md`.
- **No se cambió código del juego.**
- **Veredictos:** CONFIRMADO (evidencia propia) · PARCIAL · NO CONFIRMADO · NO VERIFICABLE aquí (necesita dispositivo, interpretación legal o un servicio externo).

## 1. Resultado global
- **106 hallazgos técnicos verificados** (áreas 1 a 5): ~90 confirmados y ~16 parciales. **Ninguno resultó falso en su totalidad.**
- **24 propuestas de modos y online:** 11 confirmadas, 10 parciales, 3 no verificables (las cifras y hechos en que se apoyan).
- **39 afirmaciones sobre el traspaso:** 16 confirmadas, 12 parciales, 1 no confirmada, 10 dependían de otros tramos y quedaron cubiertas allí.
- **Lo que el informe exagera:** sobre todo cifras (no mecanismos) y algunas severidades. Detalle en §4.
- **Lo que nadie pudo verificar:** nada de lo que depende de un teléfono real (rendimiento, voz, ML Kit, tablet, cerrar la app a mitad de un partido) ni la interpretación legal.

## 2. Hallazgos confirmados, por impacto real (mi ordenamiento)

### Integridad del progreso (perder o inflar lo ganado)
| ID | Qué pasa (confirmado) | Gravedad del informe → verificador |
|---|---|---|
| META-01 | Un solo `try` al arrancar: si la última partida no se puede leer, el perfil no se carga y el próximo guardado lo pisa. Probabilidad baja, pérdida total. | crítico → alto |
| CAR-04 | El receso borra la temporada vieja antes de guardar la nueva, con el error ignorado. Ventana de milisegundos. | alto → medio |
| META-03 | Una Dinastía/Mi carrera importada pisa a la original al avanzar (ids `raiz-tN`). | alto → alto |
| META-02 | Importar una partida vuelve a cobrar todo. Medido: 3 reimportaciones dan trofeos 19→76. | alto → alto |
| META-04 | Los enums con `byName` revientan con valores desconocidos; un `ModoJuego` desconocido cae a clásico. "Retrocompatibilidad total" era falso. | alto → medio en la práctica |
| META-06 | Perfil y partida se escriben por separado, sin transacción, y el error del perfil se ignora. | medio-alto → medio |
| META-08 | Misiones diarias cumplidas y sin cobrar se pierden a medianoche; atrasar el reloj permite cobrar de nuevo. | medio → medio-bajo |
| MDA-07 | Borrar la partida de Momentos clutch reinicia y vuelve a pagar. (Las cifras del informe no cuadran: son 80 XP y 40 monedas por momento.) | medio → medio-bajo |
| META-11 | La copia omite en silencio partidas dañadas, no es atómica y arma todo en memoria. | medio → medio-bajo |

### Cosas rotas o desconectadas que el jugador nota
| ID | Qué pasa | Gravedad |
|---|---|---|
| UX-01 | **El Álbum y la Tienda no tienen ningún botón** (`onAlbum` se pasa y nunca se dibuja). Regresión mía. Deja inaccesibles las evoluciones y los modos del álbum. | alto → alto |
| META-05 + CMP-02 (mismo defecto) | Misiones, pase y evoluciones no avanzan en amigos, armado, competitivo, universitario y Fantasy. | alto → medio-alto |
| MDA-03 | Temporada real y ¿Qué hubiera pasado si…? regalan al álbum el plantel histórico (Jordan, Pippen, Kukoč). | alto → medio-alto |
| MDA-02 | En el Desafío del día, reabrir la pantalla gasta la ficha y repite la tirada. El draft no es igual para todos. | alto → medio-alto |
| MDA-01 | Se puede repetir el Desafío del día exportando e importando la partida. | alto → medio |
| MDA-09 | "Mi colección" puede quedar trabada para siempre (chequeo inicial pasa, el draft no puede repartir). | medio → medio |
| MDA-08 | Las partidas de escalera/épocas/clutch se ven como "Temporada regular 0-0" o "Draft 0-0". | medio → bajo |
| MOT-06 | Un jugador expulsado sigue en cancha. 0,21 expulsiones por partido (mi traspaso decía ~0,1). | medio-alto → medio-alto |
| CAR-03 | Exportar un egresado del universitario a Mi carrera descarta sus 4 años: un 99 llega con 70. | alto → medio-alto |
| ONL-01 | Las fotos de Wikipedia vencen a los 5 minutos y sin red no se muestran. | alto → alto |
| CMP-07 | En Perfil perfecto, el nivel depende de la velocidad del teléfono (14 de 120 niveles cambian). Todos tienen solución única. | medio → medio-bajo |

### Balance y modos que no aguantan el largo plazo (los modos favoritos del dueño están acá)
| ID | Qué pasa (medido por el verificador) | Gravedad |
|---|---|---|
| **CAR-01** | **Mi carrera llega a 99 de media en la T5, anota 49–57 pts, gana 82-0 todos los años y suma 17 anillos en 21 temporadas.** Solo ocurre gastando todos los puntos. Sin gastarlos, la curva es sana. | crítico |
| CAR-02 | Figura franquicia: la media sube de 72–76 a 85–92 pero los puntos solo de 11–14 a 13–18. | alto |
| CAR-06 | La confianza del DT depende de **cómo simulás** (de a 1 o 6 partidos sube a 100; "Simular todo" deja 58 y sexto hombre). Subir a medio-alto. | medio-alto |
| CAR-09 | Universitario: el prestigio llega a 100 entre T7 y T10; 28-29 victorias de 30. | medio |
| CAR-08 | Mi carrera con un jugador real arranca con la carta de su década (Robinson 99 a los 22). | medio |
| CMP-01 | **Conquista no se puede perder:** 72/72 campañas completas. | alto |
| CMP-03 | Evoluciones: 5 etapas de "victorias" en una sola temporada simulada. | medio-alto |
| CMP-04 | Divisiones es un escalón: con media ≤ 88 nunca llegás a la 1; con 95 llegás en 9 temporadas. | alto |
| MDA-04 | Camino, Mejores equipos y Mundial en Leyenda: 0 % de campeón con un draft típico. | alto |
| MDA-05 | **Sesgo de época:** a igual media 86, contra un plantel de los 2000: años 50 gana 25 %, 60s 37 %, 70s 34 %, 2010s 70 %. | alto |
| CMP-05 / CMP-06 | Farmeo sin tope (torneos repetibles, Adiviná, Divisiones, Fantasy). La dificultad del Tope salarial es cosmética pero multiplica la XP. | medio |
| META-09 | Completar el álbum cuesta ~1,7 M monedas y ~30 mil sobres; el 50 % ~210 k. | medio |

### Motor
| ID | Qué pasa | Gravedad |
|---|---|---|
| MOT-01 | Faltan posesiones, no puntería: 85 por partido (vs ~99 NBA). Con la base de 9,6 s: 95 posesiones y 104 puntos. | medio-alto |
| MOT-02 | Perfil de tiro irreal: 3PAr 19 %, FT/FGA 33,5 % (NBA 42 % y 19 %). | medio |
| MOT-03 | **El `balance_test` mide un usuario sin táctica ni entrenador.** Con la táctica recomendada, el mejor plantel gana 82-0 el 60–64 % de las temporadas en Normal y 0 % en Leyenda. | alto |
| MOT-04 | La táctica la decide la afinidad, no el sistema. Pace & Space da lo mismo con y sin sus efectos. `_Efectos.interior` no se lee nunca. | alto |
| MOT-05 | La presión alta en vivo gana 58 % contra 48,5 %. | alto |
| MOT-09 | El motor no usa `rol` ni defiende por emparejamiento. | medio |
| MOT-11 | Un jugador a energía 0 sigue jugando, entre otros 5 detalles menores. | bajo |
| (nuevo) | Al simular, tu lado nunca pide tiempo muerto automático; en partidos IA el visitante tampoco. | — |

### Datos y licencias
| ID | Qué pasa | Gravedad |
|---|---|---|
| DAT-03 | **Años 40: 245 de 277 cartas (88 %) son ESCOLTA** (los rebotes estimados salen de ahí). | alto |
| DAT-01 | Escudos oficiales de la NBA versionados en repo público y fotos de una ruta que el `robots.txt` de Basketball-Reference excluye (`Disallow: /req/`). Lo legal no se pudo verificar. | medio-alto |
| DAT-02 | Fotos de entrenadores: 11 exigen atribución CC y `CREDITOS.md` solo tiene enlaces. | medio |
| DAT-04/05 | 2025-26 sin cerrar; los datos parciales de 2026-27 crean 9 cartas y mueven 121 medias y 10 tiers. | medio |
| CAR-07 | La edad por hash tiene 36 % de cartas con error ≥ 4 años; 297 cartas de 29+ entran al mini-draft como si tuvieran 20–22. | medio |
| DAT-06/08/10/12/14/15 | Pipeline sin blindar, 4.655 cartas dependen del CDN NBA, 327 cartas extintas sin uso, 15 dorsales, README desactualizado. | bajo a medio |

### UX, arquitectura y operación
| ID | Qué pasa | Gravedad |
|---|---|---|
| UX-04 | El tutorial desborda 22 px en 360×640 con texto normal y 195–243 px con texto ×2,0. | medio |
| UX-02 | 34 modos en una lista plana de 3,6 a 12,8 pantallas; Carrera queda después de 19 tarjetas. | alto → medio |
| UX-03 | El LED no llega a 4,5:1 sobre tarjetas en 17 de 30 equipos y sobre diálogos en 20 de 30. | medio |
| UX-05/06 | Inicio desborda en horizontal (31 px) y con texto ×2,0 (58 px a 360 dp). | medio |
| ARQ-01 | El APK de release se firma con la clave de debug del repo. | alto → medio |
| ARQ-02/03 | CI sin caché, borra el release antes de crear el nuevo; 2 archivos de capturas rotos y 30 de 31 con ruta fija. | bajo-medio |
| META-07/CAR-12 | Cada guardado serializa ~211 KB (72 % calendario) en el hilo principal. Jank real: hipótesis. | bajo-medio |
| ONL-07/08 | 6.668 cartas con foto de Basketball-Reference primero, sin timeouts ni reintentos, User-Agent sin contacto. | medio |
| ARQ-04 a 07, 10 | 22 métodos > 150 líneas, ciclo `progreso` ↔ modos, estado global, series duplicadas, lints por defecto. | bajo-medio |

## 3. Qué dice mal mi traspaso (confirmado)
- "Retrocompatibilidad total del JSON": falso para enums (META-04).
- Misiones y evoluciones "en cualquier modo": no pasa en 5 grupos de modos.
- "Cada temporada/id premia una sola vez": solo el cierre por id; importar cambia el id.
- Expulsiones "~0,1": son ~0,21.
- "Sin red se juega igual": las fotos de Wikipedia vencen a los 5 minutos.
- `pesoDiferencia` 1/225: el efectivo es **1/144** (hay un término extra en `motor.dart`).
- Los 101–105 puntos son solo partidos del usuario; entre rivales la liga anota 93–100.
- Tabla de balance §9.1: mide sin táctica ni entrenador.
- Camino al anillo: 10 escalones (mi propio traspaso se contradice con "12"); típico llega a ~2–3, no 3,3–4.
- Guantelete: 20–37 % / 3–20 % / 3–10 %, no 31/19/6.
- Dorsales "siempre 0": hay 15; catálogo "~4 MB": 5,14 MB; README con conteos de tiers viejos.
- "El teléfono no cambia": con orientación libre, Inicio y tutorial se desbordan.
- Qué NO dijo mal: el balance clásico (idéntico), 11.323 cartas, tiers, fotos, 49/49 campeones y 11/11 situaciones clutch (según el informe), 48 logros, tamaños.

## 4. Lo que el informe exagera o se equivoca (verificado)
| Hallazgo | Corrección |
|---|---|
| MOT-03 | "82-0 en 77–85 % en Normal": medido **60–64 %**. |
| MOT-07 | "El Pick & roll pierde": neutral en 2.500 partidos. |
| MOT-05 | Energía 0 en 43 % de partidos: medido 22 % (puede ser el método). |
| CAR-05 | Reescribí: el arranque de 36–54 victorias de los Lakers 50 no sale (63–67); el "0 anillos en 30 temporadas" tampoco. |
| CMP-04 | "Con 89–91 subís el mínimo": tardás 9–21 temporadas. |
| CMP-03 | "+15 de media" es +5 a cada una de 3 cartas. |
| CMP-10 | Ventaja de puntos del óptimo +2–7 %, no +12–15 %. |
| MDA-06/10/11/14 | "Los demás son decorativos", "trampas" y "reclutar no importa" se sostienen mal: hay 3–4 elecciones viables, Showtime/Banco profundo valen ≈ 0 (no negativo), y el impulso histórico sí mueve +9–12 pp en 3 clutch. |
| ARQ-09 | "32 % de cobertura" era de un subconjunto de 7 tests; la suite completa da **72,6 %**. |
| ARQ-04 | "50+ campos" del estado: son 37–40. |
| ONL-06 | 11.323 cartas: las fotos se piden por **4.063 jugadores**; alcanza con ~5.000 objetos de caché. |
| CAR-11 | El pedido de traspaso sí se guarda; lo que no se guarda es el paso del receso. |
| MDA-09 | "No hay botón de salida" es falso: la partida queda inutilizable igual. |
| DAT-07 | La app sí nombra a Basketball-Reference (en Historia); falta un crédito general. |
| DAT-05 | Trendon Watford no está entre las 9 cartas que desaparecen. |
| DAT-03 | El test propuesto (Mikan, Risen y Kurland PÍVOT) es en parte vacío: Mikan y Risen ya son pívot y Kurland no tiene carta. |
| UX-07/09/11 | Cancha ~29 % (no ~40 %); la carga del catálogo ya tiene pantalla propia en "Dirigir"; lo que tapa el cartel es el aro y el tablero, no `_carteles`. |
| #39 | Mi traspaso no dice "1 test de Python salteado" (dice 24 OK, y dan 24 OK sin saltos). |
| ONL-04 | Datos de PocketHost y los "90 días" de Supabase no aparecen en las páginas oficiales. |
| META-05/CMP-02, MOT-08/MDA-13 | Son el mismo hallazgo con dos IDs. |

## 5. Mi síntesis
1. **Lo urgente es lo que pierde o infla progreso:** META-01, META-02, META-03, CAR-04, META-04, META-06 y el botón del Álbum (UX-01). Todo confirmado, todo barato de arreglar.
2. **El modo favorito más roto es Mi carrera (CAR-01) y le sigue Figura franquicia.** Es crítico y es de lo que más te importa.
3. **El balance está peor medido que roto:** el test usa un usuario irreal (MOT-03). El problema real son las tácticas que no importan (MOT-04), el ritmo (MOT-01) y el sesgo de época (MDA-05).
4. **Los modos de desafío están mal calibrados** (Conquista imposible de perder; Camino/Mundial/Mejores equipos imposibles con un draft normal).
5. **Gravedades que bajo:** ARQ-01 (firma), CAR-04, MDA-01, UX-02, ONL-02 (hasta que haya ranking).
6. **Gravedades que subo:** CAR-06 (la simulación cambia el resultado de la carrera).
7. **Online:** nada de lo propuesto es urgente; los hechos que lo sostienen son ciertos (límites de Cloudflare/Supabase/Firebase) y para un grupo de amigos Supabase con un cron diario es más simple que Cloudflare.
