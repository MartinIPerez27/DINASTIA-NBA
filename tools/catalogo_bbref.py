"""Genera el catálogo completo de cartas desde datos públicos de Basketball-Reference.

Fuente: https://github.com/sumitrodatta/bball-reference-datasets (totales por temporada y equipo,
posición jugada cada temporada, All-Star, All-NBA/All-Defense y premios). No usa stats.nba.com,
así que corre en cualquier lado. Las fotos usan el ID oficial de la NBA, que se cruza por nombre
con la lista que trae nba_api (sin internet).

Igual que extraer_cartas.py: una carta = jugador + franquicia + época, con estadísticas, posiciones,
Tier, Rol e IQ calculados solo con ese tramo. Catálogo amplio (estilo 82-0): además de los
premiados, entran los titulares productivos (Tier A).

Uso:
    pip install nba_api
    python tools/catalogo_bbref.py
"""

import csv
import json
import re
import unicodedata
import urllib.request
from collections import Counter, defaultdict
from pathlib import Path

import extraer_cartas as ec

FUENTE = "https://raw.githubusercontent.com/sumitrodatta/bball-reference-datasets/master/Data/"
CACHE = ec.CACHE / "bbref"

# Siglas de Basketball-Reference → franquicia actual (sigue la historia oficial de cada franquicia).
EQUIPOS = {
    "ATL": "ATL", "BOS": "BOS", "BRK": "BKN", "NJN": "BKN", "CHA": "CHA", "CHO": "CHA", "CHH": "CHA",
    "CHI": "CHI", "CLE": "CLE", "DAL": "DAL", "DEN": "DEN", "DET": "DET", "GSW": "GSW", "HOU": "HOU",
    "IND": "IND", "LAC": "LAC", "SDC": "LAC", "LAL": "LAL", "MEM": "MEM", "VAN": "MEM", "MIA": "MIA",
    "MIL": "MIL", "MIN": "MIN", "NOP": "NOP", "NOH": "NOP", "NOK": "NOP", "NYK": "NYK", "OKC": "OKC",
    "SEA": "OKC", "ORL": "ORL", "PHI": "PHI", "PHO": "PHX", "POR": "POR", "SAC": "SAC", "KCK": "SAC",
    "SAS": "SAS", "TOR": "TOR", "UTA": "UTA", "WAS": "WAS", "WSB": "WAS",
}
POSICIONES = {"PG": "BASE", "SG": "ESCOLTA", "SF": "ALERO", "PF": "ALA-PÍVOT", "C": "PÍVOT"}

# MVP de las Finales (no está en el dataset): temporada (año de cierre) → nombre.
MVP_FINALES = {
    1980: "Magic Johnson", 1981: "Cedric Maxwell", 1982: "Magic Johnson", 1983: "Moses Malone",
    1984: "Larry Bird", 1985: "Kareem Abdul-Jabbar", 1986: "Larry Bird", 1987: "Magic Johnson",
    1988: "James Worthy", 1989: "Joe Dumars", 1990: "Isiah Thomas", 1991: "Michael Jordan",
    1992: "Michael Jordan", 1993: "Michael Jordan", 1994: "Hakeem Olajuwon", 1995: "Hakeem Olajuwon",
    1996: "Michael Jordan", 1997: "Michael Jordan", 1998: "Michael Jordan", 1999: "Tim Duncan",
    2000: "Shaquille O'Neal", 2001: "Shaquille O'Neal", 2002: "Shaquille O'Neal", 2003: "Tim Duncan",
    2004: "Chauncey Billups", 2005: "Tim Duncan", 2006: "Dwyane Wade", 2007: "Tony Parker",
    2008: "Paul Pierce", 2009: "Kobe Bryant", 2010: "Kobe Bryant", 2011: "Dirk Nowitzki",
    2012: "LeBron James", 2013: "LeBron James", 2014: "Kawhi Leonard", 2015: "Andre Iguodala",
    2016: "LeBron James", 2017: "Kevin Durant", 2018: "Kevin Durant", 2019: "Kawhi Leonard",
    2020: "LeBron James", 2021: "Giannis Antetokounmpo", 2022: "Stephen Curry", 2023: "Nikola Jokić",
    2024: "Jaylen Brown", 2025: "Shai Gilgeous-Alexander",
}
PREMIOS = {"nba mvp": 10, "nba dpoy": 3, "nba smoy": 2}
ALL_NBA = {"1st": 5, "2nd": 3, "3rd": 2}

# Nombres que la NBA escribe distinto (Basketball-Reference → lista oficial) e IDs de homónimos.
ALIAS = {
    "World B. Free": "World Free", "Fat Lever": "Lafayette Lever", "Tiny Archibald": "Nate Archibald",
    "Clarence Weatherspoon": "Clar. Weatherspoon", "Dave Greenwood": "David Greenwood",
    "Melvin Turpin": "Mel Turpin", "Danny Schayes": "Dan Schayes", "Isaac Austin": "Ike Austin",
    "Michael Ray Richardson": "Micheal Ray Richardson", "Steve Smith": "Steven Smith",
}
ID_FIJO = {"robincl01": 77986, "robincl02": 361, "smithst01": 120}

# Posición vecina que todo jugador puede cubrir (GDD §3.3: multi-posición universal).
def vecina(pos, perfil):
    return {
        "BASE": ["ESCOLTA"],
        "ESCOLTA": (["ALERO"] if perfil["reb"] >= 4.5 else []) + (["BASE"] if perfil["ast"] >= 5 else []) or ["BASE"],
        "ALERO": ["ALA-PÍVOT"] if perfil["reb"] >= 7 else ["ESCOLTA"],
        "ALA-PÍVOT": ["PÍVOT"] if perfil["blk"] >= 1.2 or perfil["reb"] >= 10 else ["ALERO"],
        "PÍVOT": ["ALA-PÍVOT"],
    }[pos]


MIN_POR_GRUPO = 10  # cada franquicia y época ofrece al menos esta cantidad de cartas (si existen)

# Tier A por producción (catálogo amplio): titular con minutos y eficiencia (EFF de la NBA).
MIN_MINUTOS = 20
MIN_EFICIENCIA = 11.0

COLUMNAS = {  # dataset → nombres de extraer_cartas.CAMPOS
    "g": "GP", "gs": "GS", "mp": "MIN", "fg": "FGM", "fga": "FGA", "x3p": "FG3M", "x3pa": "FG3A",
    "ft": "FTM", "fta": "FTA", "orb": "OREB", "drb": "DREB", "trb": "REB", "ast": "AST", "stl": "STL",
    "blk": "BLK", "tov": "TOV", "pts": "PTS",
}


def leer(archivo):
    destino = CACHE / archivo
    if not destino.exists():
        CACHE.mkdir(parents=True, exist_ok=True)
        with urllib.request.urlopen(FUENTE + archivo.replace(" ", "%20"), timeout=60) as r:
            destino.write_bytes(r.read())
    with destino.open(encoding="utf-8") as f:
        return list(csv.DictReader(f))


def numero(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return 0.0


def epoca_de(anio_cierre):
    return ec.epoca_de(f"{anio_cierre - 1}-00")


def normalizar(nombre):
    s = unicodedata.normalize("NFKD", nombre.replace("ı", "i")).encode("ascii", "ignore").decode().lower()
    s = re.sub(r",?\s(jr|sr|ii|iii|iv)\.?$", "", s.strip())
    return re.sub(r"[^a-z]", "", s)


def ids_nba():
    """Nombre normalizado → IDs oficiales de la NBA (ordenados: los repetidos se asignan por debut)."""
    from nba_api.stats.static import players

    por_nombre = defaultdict(list)
    for p in players.get_players():
        por_nombre[normalizar(p["full_name"])].append(p["id"])
    return {k: sorted(v) for k, v in por_nombre.items()}


def eficiencia(t):
    gp = t["GP"] or 1
    return (t["PTS"] + t["REB"] + t["AST"] + t["STL"] + t["BLK"]
            - (t["FGA"] - t["FGM"]) - (t["FTA"] - t["FTM"]) - t["TOV"]) / gp


def posiciones(conteo, perfil):
    total = sum(conteo.values()) or 1
    pos = [p for p, g in conteo.most_common() if g / total >= 0.2][:3]
    for extra in vecina(pos[0], perfil):
        if extra not in pos and len(pos) < 3:
            pos.append(extra)
    if "BASE" not in pos and pos[0] != "PÍVOT" and perfil["ast"] >= 8:
        pos.append("BASE")
    return pos


def main():
    totales = [f for f in leer("Player Totals.csv") if f["lg"] == "NBA" and int(f["season"]) >= 1980]
    print(f"{len(totales)} filas de temporada desde 1980")

    grupos = defaultdict(lambda: dict.fromkeys(ec.CAMPOS, 0.0))
    conteo_pos = defaultdict(Counter)
    nombres = {}
    partidos_temporada = defaultdict(dict)  # (player_id, temporada) → {franquicia: partidos}
    for f in totales:
        franquicia, epoca = EQUIPOS.get(f["team"]), epoca_de(int(f["season"]))
        if not franquicia or not epoca:  # filas "2TM"/"TOT" de traspasos
            continue
        clave = (f["player_id"], franquicia, epoca)
        for col, campo in COLUMNAS.items():
            grupos[clave][campo] += numero(f[col])
        if f["pos"] in POSICIONES:
            conteo_pos[clave][POSICIONES[f["pos"]]] += numero(f["g"])
        nombres[f["player_id"]] = f["player"]
        partidos_temporada[(f["player_id"], int(f["season"]))][franquicia] = numero(f["g"])
    principal = {k: max(v, key=v.get) for k, v in partidos_temporada.items()}

    puntos, sexto = defaultdict(int), set()

    def premiar(pid, temporada, valor, es_sexto=False):
        franquicia = principal.get((pid, temporada))
        if franquicia:
            clave = (pid, franquicia, epoca_de(temporada))
            puntos[clave] += valor
            if es_sexto:
                sexto.add(clave)

    for f in leer("All-Star Selections.csv"):
        if f["lg"] == "NBA" and int(f["season"]) >= 1980:
            premiar(f["player_id"], int(f["season"]), 1)
    for f in leer("End of Season Teams.csv"):
        if f["lg"] == "NBA" and int(f["season"]) >= 1980:
            if f["type"] == "All-NBA":
                premiar(f["player_id"], int(f["season"]), ALL_NBA.get(f["number_tm"], 0))
            elif f["type"] == "All-Defense" and f["number_tm"] == "1st":
                premiar(f["player_id"], int(f["season"]), 1)
    for f in leer("Player Award Shares.csv"):
        if f["award"] in PREMIOS and f["winner"] == "TRUE" and int(f["season"]) >= 1980:
            premiar(f["player_id"], int(f["season"]), PREMIOS[f["award"]], f["award"] == "nba smoy")
    id_por_nombre_temporada = {(int(f["season"]), f["player"]): f["player_id"] for f in totales}
    for temporada, nombre in MVP_FINALES.items():
        pid = id_por_nombre_temporada.get((temporada, nombre))
        if pid is None:
            print(f"  aviso: MVP de las Finales {temporada} ({nombre}) no encontrado")
            continue
        premiar(pid, temporada, 8)

    nba = ids_nba()
    usados_por_nombre = defaultdict(list)  # para repetidos: bbref id → orden de debut
    for pid in sorted(nombres, key=lambda p: (p[-2:], p)):
        usados_por_nombre[normalizar(nombres[pid])].append(pid)

    def id_oficial(pid):
        if pid in ID_FIJO:
            return ID_FIJO[pid]
        candidatos = nba.get(normalizar(ALIAS.get(nombres[pid], nombres[pid])), [])
        homonimos = usados_por_nombre[normalizar(nombres[pid])]
        indice = homonimos.index(pid)
        if indice < len(candidatos):
            return candidatos[indice]
        return -(abs(hash(pid)) % 10_000_000) - 1  # sin foto: ID negativo único (no pide nada al CDN)

    elegidos, reserva = {}, defaultdict(list)
    for clave, t in grupos.items():
        if t["GP"] < ec.MIN_PARTIDOS or t["MIN"] <= 0:
            continue
        tier = ec.tier_de(puntos[clave])
        if not tier and t["MIN"] / t["GP"] >= MIN_MINUTOS and eficiencia(t) >= MIN_EFICIENCIA:
            tier = "a"
        if tier:
            elegidos[clave] = tier
        elif t["MIN"] / t["GP"] >= 15:
            reserva[clave[1:]].append(clave)
    # Planteles con pocas cartas: se completan con los mejores de la rotación.
    por_grupo = Counter(clave[1:] for clave in elegidos)
    for grupo, claves in reserva.items():
        faltan = MIN_POR_GRUPO - por_grupo[grupo]
        for clave in sorted(claves, key=lambda c: -eficiencia(grupos[c]))[: max(faltan, 0)]:
            elegidos[clave] = "a"

    cartas, sin_foto = [], 0
    for (pid, franquicia, epoca), tier in elegidos.items():
        t = grupos[(pid, franquicia, epoca)]
        pts = puntos[(pid, franquicia, epoca)]
        p = ec.perfil_de(t)
        pos = posiciones(conteo_pos[(pid, franquicia, epoca)] or Counter({"ALERO": 1}), p)
        nba_id = id_oficial(pid)
        sin_foto += nba_id < 0
        cartas.append({
            "id": f"{pid}-{franquicia}-{ec.CODIGO_EPOCA[epoca]}",
            "nbaPlayerId": nba_id,
            "nombre": nombres[pid],
            "franquicia": franquicia,
            "epoca": epoca,
            "tier": tier,
            "posiciones": pos,
            "rol": ec.rol_de(pos[0], p, (pid, franquicia, epoca) in sexto or p["suplente"]),
            "dorsal": 0,  # el dataset no trae dorsales; se cargan en ajustes_cartas.json
            "stats": ec.stats_de(t),
            "_perfil": p,
            "_puntos": pts,
            "_puntaje": eficiencia(t) + 0.6 * pts,
        })

    ec.asignar_iq(cartas)
    # Media (62–99), estilo valoración general: percentil de eficiencia + premios en el tramo.
    for carta, rango in zip(cartas, ec._percentiles([c["_puntaje"] for c in cartas])):
        carta["media"] = round(62 + 37 * rango)
    ajustes = json.loads(ec.AJUSTES.read_text(encoding="utf-8")) if ec.AJUSTES.exists() else {}
    ec.aplicar_ajustes(cartas, ajustes)
    orden = {"sPlus": 0, "s": 1, "a": 2}
    cartas.sort(key=lambda c: (orden[c["tier"]], -c["stats"]["ppp"]))
    limpias = [{k: v for k, v in c.items() if not k.startswith("_")} for c in cartas]
    ec.SALIDA.write_text(json.dumps(limpias, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")

    por_tier = Counter(c["tier"] for c in limpias)
    por_grupo = Counter((c["franquicia"], c["epoca"]) for c in limpias)
    print(f"{len(limpias)} cartas (S+ {por_tier['sPlus']}, S {por_tier['s']}, A {por_tier['a']}), "
          f"{sin_foto} sin foto; por franquicia y época: mín {min(por_grupo.values())}, "
          f"máx {max(por_grupo.values())}, promedio {len(limpias) / len(por_grupo):.1f}")


if __name__ == "__main__":
    main()
