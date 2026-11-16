"""Temporadas exactas de las cartas con huecos (para Temporada real y los modos de historia).

Una carta (catálogo v3) es un tramo jugador + franquicia + ventana de temporadas y trae `temporadas` =
[primera, última]. Casi todas son rachas continuas; las pocas que no (ventanas chicas unidas, cartas
heredadas del catálogo anterior por década) incluyen años en que el jugador no estaba. Este script
lista, solo para esas cartas, los años de cierre en que jugó de verdad con esa franquicia:
assets/database/temporadas_huecos.json = {id de carta: [años]}.

Uso: python3 tools/temporadas_jugadas.py   (usa el caché de tools/.cache/bbref)
"""
import ast
import csv
import json
import re
from collections import defaultdict
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
TOTALES = RAIZ / "tools/.cache/bbref/Player Totals.csv"
CATALOGO = RAIZ / "assets/database/nba_players.json"
SALIDA = RAIZ / "assets/database/temporadas_huecos.json"
ULTIMA_TEMPORADA = 2026  # los datos de la temporada en curso no entran (igual que catalogo_bbref.py)


def huecos(filas, equipos, cartas):
    """{id de carta: años} para las cartas cuyo tramo no es continuo."""
    anios = defaultdict(set)  # (jugador, franquicia) → años de cierre jugados
    for f in filas:
        if f["lg"] not in ("NBA", "BAA") or f["team"] not in equipos or not float(f["g"] or 0):
            continue
        if int(f["season"]) > ULTIMA_TEMPORADA:
            continue
        anios[(f["player_id"], equipos[f["team"]][0])].add(int(f["season"]))
    salida = {}
    for c in cartas:
        if c.get("legado") or "temporadas" not in c:
            continue
        desde, hasta = c["temporadas"]
        jugados = sorted(a for a in anios[(c["id"].split("-")[0], c["franquicia"])] if desde <= a <= hasta)
        if jugados and hasta - desde + 1 != len(jugados):
            salida[c["id"]] = jugados
    return dict(sorted(salida.items()))


def main():
    fuente = (RAIZ / "tools/catalogo_bbref.py").read_text(encoding="utf-8")
    equipos = ast.literal_eval(re.search(r"EQUIPOS = (\{.*?\n\})", fuente, re.S).group(1))
    cartas = json.loads(CATALOGO.read_text(encoding="utf-8"))
    with TOTALES.open(encoding="utf-8") as f:
        salida = huecos(list(csv.DictReader(f)), equipos, cartas)
    SALIDA.write_text(json.dumps(salida, separators=(",", ":")), encoding="utf-8")
    print(f"{len(salida)} cartas con huecos")


if __name__ == "__main__":
    main()
