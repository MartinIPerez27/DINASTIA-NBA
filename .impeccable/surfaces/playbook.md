# Superficie: Playbook — 10 ofensivas + 10 defensivas con asistente

Modo: operate (se elige y se confirma) · Mundo heredado: El Marcador (DESIGN.md).
Arriba, el panel del asistente con la pareja recomendada (afinidad en LED + motivos con nombre y
estadística). Abajo, Ofensiva/Defensiva y la lista ordenada por afinidad; la elegida con borde LED.
Lógica en `lib/domain/playbook.dart` (rasgos del plantel → afinidad 1–99; pareja con castigo por
ritmos opuestos). Los pesos y el ritmo viven en cada sistema (`tactica.dart`) para la Fase 5.
