"""Temporadas exactas de las cartas con huecos (para Temporada real y los modos de historia).

Una carta es un tramo jugador + franquicia + década y trae `temporadas` = [primera, última]. Si el
jugador se fue y volvió dentro de esa década (LeBron en Cleveland: 2010 y 2015-18), ese rango
incluye años en que no estaba. Este script lista, solo para esas cartas, los años de cierre en que
jugó de verdad: assets/database/temporadas_huecos.json = {id de carta: [años]}.

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
CODIGO = {"anios40": "40", "anios50": "50", "anios60": "60", "anios70": "70", "anios80": "80",
          "anios90": "90", "anios2000": "00", "anios2010": "10", "actualidad": "act"}
DECADA = {1940: "anios40", 1950: "anios50", 1960: "anios60", 1970: "anios70", 1980: "anios80",
          1990: "anios90", 2000: "anios2000", 2010: "anios2010"}


def epoca(fin):
    return "actualidad" if fin >= 2020 else DECADA[fin // 10 * 10]


def huecos(filas, equipos, ids):
    """{id de carta: años} para las cartas cuyo tramo no es continuo."""
    anios = defaultdict(set)
    for f in filas:
        if f["lg"] not in ("NBA", "BAA") or f["team"] not in equipos or not float(f["g"] or 0):
            continue
        fin = int(f["season"])
        franquicia = equipos[f["team"]][0]
        anios[f"{f['player_id']}-{franquicia}-{CODIGO[epoca(fin)]}"].add(fin)
    return {
        k: sorted(v) for k, v in sorted(anios.items())
        if k in ids and max(v) - min(v) + 1 != len(v)
    }


def main():
    fuente = (RAIZ / "tools/catalogo_bbref.py").read_text(encoding="utf-8")
    equipos = ast.literal_eval(re.search(r"EQUIPOS = (\{.*?\n\})", fuente, re.S).group(1))
    ids = {c["id"] for c in json.loads(CATALOGO.read_text(encoding="utf-8"))}
    with TOTALES.open(encoding="utf-8") as f:
        salida = huecos(list(csv.DictReader(f)), equipos, ids)
    SALIDA.write_text(json.dumps(salida, separators=(",", ":")), encoding="utf-8")
    print(f"{len(salida)} cartas con huecos")


if __name__ == "__main__":
    main()
