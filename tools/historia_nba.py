"""Genera lib/data/historia_nba.dart: récords reales por temporada desde Team Summaries.csv
(Basketball-Reference, mismo dataset que catalogo_bbref.py).
Uso: python3 -I tools/historia_nba.py TEAM_SUMMARIES_CSV tools/catalogo_bbref.py lib/data/historia_nba.dart"""
import ast, csv, re, sys
from collections import defaultdict
ts, bbref, salida = sys.argv[1:4]
EQUIPOS = ast.literal_eval(re.search(r"EQUIPOS = (\{.*?\n\})", open(bbref, encoding='utf-8').read(), re.S).group(1))
ACTUALES = {"ATL","BOS","BKN","CHA","CHI","CLE","DAL","DEN","DET","GSW","HOU","IND","LAC","LAL","MEM","MIA","MIL","MIN","NOP","NYK","OKC","ORL","PHI","PHX","POR","SAC","SAS","TOR","UTA","WAS"}
por = defaultdict(dict)
for f in csv.DictReader(open(ts, encoding='utf-8')):
    if f['lg'] not in ('NBA', 'BAA') or f['team'] == 'League Average':
        continue
    anio = int(f['season'])
    if anio >= 2027:  # temporada en curso
        continue
    ab = f['abbreviation']
    if ab not in EQUIPOS:
        continue
    fr, ident = EQUIPOS[ab]
    if fr not in ACTUALES:
        continue
    por[anio][fr] = (ident, int(float(f['w'])), int(float(f['l'])))
lineas = ["// GENERADO por tools/historia_nba.py desde Team Summaries.csv (Basketball-Reference). No editar a mano.",
          "", "/// Récord real de cada franquicia actual por temporada (año de cierre): (identidad, victorias, derrotas).",
          "const registrosReales = <int, Map<String, (String, int, int)>>{"]
for anio in sorted(por):
    items = ", ".join(f"'{fr}': ('{i}', {w}, {l})" for fr, (i, w, l) in sorted(por[anio].items()))
    lineas.append(f"  {anio}: {{{items}}},")
lineas.append("};")
open(salida, 'w', encoding='utf-8').write("\n".join(lineas) + "\n")
print(len(por), min(por), max(por), {a: len(por[a]) for a in (1950, 1961, 1968, 1977, 1990, 2005, 2026)})
