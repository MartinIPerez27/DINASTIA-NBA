"""Genera el catálogo histórico completo de cartas desde datos públicos de Basketball-Reference.

Fuente: https://github.com/sumitrodatta/bball-reference-datasets (totales por temporada y equipo
desde 1947, posición jugada cada temporada, All-Star, All-NBA/All-Defense y premios).

Catálogo v3 (ver docs/CATALOGO_V3.md): una carta = un TRAMO REAL = jugador + franquicia + ventana de
temporadas homogénea (racha continua con el mismo equipo, dentro de una década, de 1 a 4 temporadas,
partida donde cambia el rendimiento). Estadísticas, posiciones, Rol, IQ, media y Tier se calculan solo
con esa ventana; el campo `temporadas` dice cuál es. Los datos parciales de la temporada en curso
(posterior a ULTIMA_TEMPORADA) no entran.

Los datos que la NBA no registraba (robos y tapones antes de 1974, pérdidas antes de 1978, rebotes
antes de 1951, minutos antes de 1952) se estiman con el promedio por posición de las primeras
temporadas que sí los tienen, y quedan marcados en "estimadas". Los triples antes de 1980 son 0
(la línea no existía).

Fotos: lista de fuentes en orden (ver tools/fotos.py). Uso:
    pip install nba_api
    python tools/fotos.py            # resuelve fotos (lento la 1ª vez; deja caché)
    python tools/catalogo_bbref.py
"""

import csv
import json
import os
import re
import unicodedata
import urllib.request
import zlib
from pathlib import Path
from collections import Counter, defaultdict

import extraer_cartas as ec

FUENTE = "https://raw.githubusercontent.com/sumitrodatta/bball-reference-datasets/master/Data/"
CACHE = ec.CACHE / "bbref"
FOTOS = ec.CACHE / "fotos.json"
MIN_PARTIDOS = 20  # mínimo de partidos de una ventana para ser carta
MIN_PARTIDOS_TRASPASO = 12  # una parada de traspaso a mitad de temporada (con 250+ minutos) ya es carta
MIN_VENTANA = 40  # una ventana nace de cortar un tramo solo si cada parte tiene al menos estos partidos
MAX_TEMPORADAS = 4  # ventana máxima (temporadas)
PENALIZACION_VENTANA = 6.0  # costo de abrir otra ventana: un cambio de nivel de ~2 puntos la justifica
ULTIMA_TEMPORADA = 2026  # último año de cierre terminado (2025-26); 2026-27 está en curso y no entra
HEREDADOS = ec.RAIZ / "tools" / "ids_heredados.json"  # id v2 por década → ventana que lo conserva
LEGADO = ec.RAIZ / "tools" / "cartas_legado.json"  # cartas v2 que no se pueden recalcular (se conservan tal cual)

# Sigla de Basketball-Reference → (franquicia actual, identidad). Las franquicias actuales usan su
# propio id como identidad; los equipos extintos sin sucesor son su propia franquicia.
EQUIPOS = {
    # Actuales
    "ATL": ("ATL", "ATL"), "BOS": ("BOS", "BOS"), "BRK": ("BKN", "BKN"), "CHO": ("CHA", "CHA"),
    "CHI": ("CHI", "CHI"), "CLE": ("CLE", "CLE"), "DAL": ("DAL", "DAL"), "DEN": ("DEN", "DEN"),
    "DET": ("DET", "DET"), "GSW": ("GSW", "GSW"), "HOU": ("HOU", "HOU"), "IND": ("IND", "IND"),
    "LAC": ("LAC", "LAC"), "LAL": ("LAL", "LAL"), "MEM": ("MEM", "MEM"), "MIA": ("MIA", "MIA"),
    "MIL": ("MIL", "MIL"), "MIN": ("MIN", "MIN"), "NOP": ("NOP", "NOP"), "NYK": ("NYK", "NYK"),
    "OKC": ("OKC", "OKC"), "ORL": ("ORL", "ORL"), "PHI": ("PHI", "PHI"), "PHO": ("PHX", "PHX"),
    "POR": ("POR", "POR"), "SAC": ("SAC", "SAC"), "SAS": ("SAS", "SAS"), "TOR": ("TOR", "TOR"),
    "UTA": ("UTA", "UTA"), "WAS": ("WAS", "WAS"),
    # Identidades anteriores de franquicias actuales
    "TRI": ("ATL", "TRI"), "MLH": ("ATL", "MLH"), "STL": ("ATL", "STL"),
    "NYN": ("BKN", "NYN"), "NJN": ("BKN", "NJN"),
    "CHH": ("CHA", "CHH"), "CHA": ("CHA", "CHB"),  # en Basketball-Reference CHA = Bobcats
    "FTW": ("DET", "FTW"), "PHW": ("GSW", "PHW"), "SFW": ("GSW", "SFW"), "SDR": ("HOU", "SDR"),
    "BUF": ("LAC", "BUF"), "SDC": ("LAC", "SDC"), "MNL": ("LAL", "MNL"), "VAN": ("MEM", "VAN"),
    "NOH": ("NOP", "NOH"), "NOK": ("NOP", "NOK"), "SEA": ("OKC", "SEA"), "SYR": ("PHI", "SYR"),
    "ROC": ("SAC", "ROC"), "CIN": ("SAC", "CIN"), "KCO": ("SAC", "KCO"), "KCK": ("SAC", "KCK"),
    "NOJ": ("UTA", "NOJ"), "CHP": ("WAS", "CHP"), "CHZ": ("WAS", "CHZ"), "BAL": ("WAS", "BAL"),
    "CAP": ("WAS", "CAP"), "WSB": ("WAS", "WSB"),
    # Extintos sin sucesor (años 40 y 50)
    "AND": ("AND", "AND"), "BLB": ("BLB", "BLB"), "CHS": ("CHS", "CHS"), "CLR": ("CLR", "CLR"),
    "DNN": ("DNN", "DNN"), "DTF": ("DTF", "DTF"), "INJ": ("INJ", "INJ"), "INO": ("INO", "INO"),
    "PIT": ("PIT", "PIT"), "PRO": ("PRO", "PRO"), "SHE": ("SHE", "SHE"), "STB": ("STB", "STB"),
    "TRH": ("TRH", "TRH"), "WAT": ("WAT", "WAT"), "WSC": ("WSC", "WSC"),
}
POSICIONES = {"PG": "BASE", "SG": "ESCOLTA", "SF": "ALERO", "PF": "ALA-PÍVOT", "C": "PÍVOT"}

# MVP de las Finales (no está en el dataset): temporada (año de cierre) → nombre.
MVP_FINALES = {
    1969: "Jerry West", 1970: "Willis Reed", 1971: "Kareem Abdul-Jabbar", 1972: "Wilt Chamberlain",
    1973: "Willis Reed", 1974: "John Havlicek", 1975: "Rick Barry", 1976: "Jo Jo White",
    1977: "Bill Walton", 1978: "Wes Unseld", 1979: "Dennis Johnson",
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
    2024: "Jaylen Brown", 2025: "Shai Gilgeous-Alexander", 2026: "Jalen Brunson",
}
# Premios de 2025-26 que el dataset todavía no trae (Wikipedia, "2025–26 NBA season"): (nombre, puntos).
# All-NBA con los puntos de ALL_NBA (1º 5, 2º 3, 3º 2). Sin All-Defense 2026 (sin fuente).
PREMIOS_2026 = {
    "mvp": ["Shai Gilgeous-Alexander"], "dpoy": ["Victor Wembanyama"], "smoy": ["Keldon Johnson"],
    "1st": ["Cade Cunningham", "Luka Dončić", "Shai Gilgeous-Alexander", "Nikola Jokić", "Victor Wembanyama"],
    "2nd": ["Jaylen Brown", "Jalen Brunson", "Kevin Durant", "Kawhi Leonard", "Donovan Mitchell"],
    "3rd": ["Tyrese Maxey", "Jamal Murray", "Jalen Johnson", "Chet Holmgren", "Jalen Duren"],
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

COLUMNAS = {  # dataset → nombres de extraer_cartas.CAMPOS
    "g": "GP", "gs": "GS", "mp": "MIN", "fg": "FGM", "fga": "FGA", "x3p": "FG3M", "x3pa": "FG3A",
    "ft": "FTM", "fta": "FTA", "orb": "OREB", "drb": "DREB", "trb": "REB", "ast": "AST", "stl": "STL",
    "blk": "BLK", "tov": "TOV", "pts": "PTS",
}
# Campo → (columna fuente, nombre del dato en la carta) para marcar estimaciones.
ESTIMABLES = {"mp": "minP", "trb": "rpp", "orb": None, "stl": "robP", "blk": "tapP", "tov": "perP"}
# Para cada dato faltante, temporadas de referencia (las primeras que lo registran).
REFERENCIA = {"mp": (1952, 1956), "trb": (1951, 1955), "orb": (1974, 1978), "stl": (1974, 1978),
              "blk": (1974, 1978), "tov": (1978, 1982)}


def vecina(pos, perfil):
    """Posición vecina que todo jugador puede cubrir (GDD §3.3: multi-posición universal)."""
    return {
        "BASE": ["ESCOLTA"],
        "ESCOLTA": (["ALERO"] if perfil["reb"] >= 4.5 else []) + (["BASE"] if perfil["ast"] >= 5 else []) or ["BASE"],
        "ALERO": ["ALA-PÍVOT"] if perfil["reb"] >= 7 else ["ESCOLTA"],
        "ALA-PÍVOT": ["PÍVOT"] if perfil["blk"] >= 1.2 or perfil["reb"] >= 10 else ["ALERO"],
        "PÍVOT": ["ALA-PÍVOT"],
    }[pos]


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
        return None


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


def posicion_inferida(fila):
    """Último recurso, sin ficha biográfica: se deduce del perfil (rebotes y asistencias por partido)."""
    g = numero(fila["g"]) or 1
    reb, ast = (numero(fila["trb"]) or 0) / g, (numero(fila["ast"]) or 0) / g
    if reb >= 10:
        return "PÍVOT"
    if reb >= 7.5:
        return "ALA-PÍVOT"
    if ast >= 4:
        return "BASE"
    return "ALERO" if reb >= 5 else "ESCOLTA"


class Biografico:
    """Datos de Player Career Info.csv que sirven para inferir posición y rebotes: posición de carrera
    (G, G-F, F, F-C, C…), altura en pulgadas y peso, y la altura media de cada temporada."""

    def __init__(self, carreras, filas):
        self.info = {}
        for f in carreras:
            self.info[f["player_id"]] = (f.get("pos"), numero(f.get("ht_in_in")), numero(f.get("wt")))
        alturas = defaultdict(list)
        for f in filas:
            if (h := self.altura(f["player_id"])) is not None:
                alturas[int(f["season"])].append(h)
        self.media_temporada = {s: sum(v) / len(v) for s, v in alturas.items()}
        self.conocida = defaultdict(Counter)  # jugador → posiciones declaradas por partidos
        for f in filas:
            if f["pos"] in POSICIONES:
                self.conocida[f["player_id"]][POSICIONES[f["pos"]]] += numero(f["g"]) or 0

    def altura(self, pid):
        return self.info.get(pid, (None, None, None))[1]

    def posicion(self, fila):
        """Posición de una fila: la declarada; si falta, la mayoritaria del mismo jugador en otras
        temporadas; si no, la de carrera afinada con la altura relativa a su temporada (y el peso si
        falta la altura); como último recurso, el perfil estadístico. (DAT-03: en los años 40 casi
        ninguna fila trae posición ni rebotes.)"""
        if fila["pos"] in POSICIONES:
            return POSICIONES[fila["pos"]]
        if self.conocida.get(fila["player_id"]):
            return self.conocida[fila["player_id"]].most_common(1)[0][0]
        carrera, altura, peso = self.info.get(fila["player_id"], (None, None, None))
        if carrera in (None, "NA", ""):
            return posicion_inferida(fila)
        media = self.media_temporada.get(int(fila["season"]), 74.0)
        if altura is not None:
            rel = altura - media
        elif peso is not None:
            rel = (peso - 195) / 12  # ~12 libras por pulgada de altura
        else:
            rel = 0.0
        g = numero(fila["g"]) or 1
        ast = (numero(fila["ast"]) or 0) / g
        primera = carrera.split("-")[0]
        if primera == "G":
            if carrera == "G-F":
                return "ALERO" if rel >= 3 else "ESCOLTA"
            return "BASE" if rel < 0 or ast >= 3 else "ESCOLTA"
        if primera == "F":
            if carrera == "F-G":
                return "ALERO" if rel >= -1 else "ESCOLTA"
            if carrera == "F-C":
                return "PÍVOT" if rel >= 5 else "ALA-PÍVOT"
            return "ALA-PÍVOT" if rel >= 3 else "ALERO"
        if carrera == "C-F":
            return "PÍVOT" if rel >= 3 else "ALA-PÍVOT"
        return "PÍVOT"


def promedios_referencia(filas, bio):
    """Por posición, cada dato faltante por minuto (o minutos por punto) en sus primeras temporadas, y la
    altura media de cada posición en esas temporadas."""
    sumas = defaultdict(lambda: [0.0, 0.0])  # (campo, posición) → [dato, minutos]
    alturas = defaultdict(list)
    for f in filas:
        anio = int(f["season"])
        mp = numero(f["mp"])
        for campo, (desde, hasta) in REFERENCIA.items():
            if not desde <= anio <= hasta:
                continue
            pos = bio.posicion(f)
            if campo == "mp":
                pts = numero(f["pts"])
                if mp and pts:
                    sumas[(campo, pos)][0] += mp
                    sumas[(campo, pos)][1] += pts
            elif (v := numero(f[campo])) is not None and mp:
                sumas[(campo, pos)][0] += v
                sumas[(campo, pos)][1] += mp
            if campo == "trb" and (h := bio.altura(f["player_id"])) is not None:
                alturas[pos].append(h - bio.media_temporada.get(anio, 74.0))
    ref = {k: d / m for k, (d, m) in sumas.items() if m}
    for pos, v in alturas.items():
        ref[("altura", pos)] = sum(v) / len(v)
    return ref


def completar(fila, ref, bio):
    """Copia la fila con los datos faltantes estimados; devuelve (fila, campos estimados, posición).
    Rebotes y tapones se ajustan por la altura del jugador respecto de la media de su posición."""
    f = dict(fila)
    pos = bio.posicion(f)
    estimados = set()
    if numero(f["mp"]) is None:
        # Minutos por punto de su posición en los primeros años registrados, acotado a 10–42 por partido.
        g = numero(f["g"]) or 1
        mpg = min(42.0, max(10.0, ref[("mp", pos)] * (numero(f["pts"]) or 0) / g))
        f["mp"] = str(mpg * g)
        estimados.add("mp")
    mp = numero(f["mp"])
    altura = bio.altura(f["player_id"])
    factor = 1.0
    if altura is not None:
        rel = altura - bio.media_temporada.get(int(f["season"]), 74.0) - ref.get(("altura", pos), 0.0)
        factor = min(1.35, max(0.75, 1 + 0.05 * rel))
    for campo in ("trb", "orb", "stl", "blk", "tov"):
        if numero(f[campo]) is None:
            f[campo] = str(ref[(campo, pos)] * mp * (factor if campo in ("trb", "orb", "blk") else 1.0))
            estimados.add(campo)
    if numero(f["drb"]) is None:
        f["drb"] = str(numero(f["trb"]) - numero(f["orb"]))
    for campo in ("x3p", "x3pa"):  # sin línea de tres: cero real, no estimación
        if numero(f[campo]) is None:
            f[campo] = "0"
    return f, estimados, pos


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


# Distribución de medias por época (cantidad de cartas por media, 60–99), la del catálogo v1. La media
# v2 ordena las cartas de cada época por impacto y las reparte con la misma forma: se corrige quién
# está arriba y quién abajo sin cambiar la escala (la dificultad apunta a medias de rivales) ni el
# peso relativo de las épocas (la BAA de los 40 era una liga más débil).
DISTRIBUCION_MEDIA = {
    "anios40": {60: 27, 61: 18, 62: 28, 63: 30, 64: 19, 65: 18, 66: 19, 67: 20, 68: 20, 69: 12, 70: 11, 71: 8, 72: 6, 73: 11, 74: 3, 75: 4, 76: 7, 77: 4, 78: 1, 79: 1, 80: 2, 81: 5, 82: 1, 86: 1, 91: 1},
    "anios50": {61: 3, 62: 7, 63: 9, 64: 18, 65: 24, 66: 19, 67: 26, 68: 24, 69: 26, 70: 42, 71: 40, 72: 34, 73: 27, 74: 27, 75: 34, 76: 28, 77: 22, 78: 22, 79: 16, 80: 6, 81: 11, 82: 15, 83: 13, 84: 6, 85: 9, 86: 6, 87: 3, 88: 3, 89: 2, 90: 2, 91: 4, 92: 1, 93: 2, 94: 3, 95: 1, 96: 2, 97: 2, 98: 1},
    "anios60": {61: 1, 62: 2, 63: 10, 64: 20, 65: 23, 66: 23, 67: 24, 68: 23, 69: 15, 70: 27, 71: 23, 72: 31, 73: 32, 74: 27, 75: 35, 76: 18, 77: 18, 78: 19, 79: 22, 80: 11, 81: 13, 82: 11, 83: 11, 84: 9, 85: 9, 86: 9, 87: 9, 88: 7, 89: 2, 90: 6, 92: 3, 93: 2, 94: 1, 96: 1, 97: 2, 98: 5},
    "anios70": {61: 4, 62: 10, 63: 27, 64: 34, 65: 46, 66: 38, 67: 48, 68: 61, 69: 52, 70: 55, 71: 56, 72: 62, 73: 60, 74: 45, 75: 56, 76: 65, 77: 44, 78: 42, 79: 31, 80: 40, 81: 31, 82: 30, 83: 31, 84: 31, 85: 11, 86: 23, 87: 12, 88: 7, 89: 6, 90: 10, 91: 10, 92: 1, 93: 4, 94: 1, 95: 7, 96: 2, 97: 2, 98: 1},
    "anios80": {60: 2, 61: 1, 62: 10, 63: 26, 64: 34, 65: 55, 66: 50, 67: 64, 68: 59, 69: 60, 70: 80, 71: 72, 72: 69, 73: 75, 74: 57, 75: 63, 76: 81, 77: 62, 78: 39, 79: 62, 80: 42, 81: 51, 82: 43, 83: 40, 84: 34, 85: 34, 86: 16, 87: 15, 88: 9, 89: 10, 90: 10, 91: 3, 92: 3, 93: 2, 94: 3, 95: 2, 96: 3, 97: 2, 99: 2},
    "anios90": {62: 11, 63: 37, 64: 54, 65: 58, 66: 84, 67: 88, 68: 91, 69: 85, 70: 104, 71: 102, 72: 87, 73: 78, 74: 85, 75: 79, 76: 62, 77: 79, 78: 89, 79: 57, 80: 61, 81: 48, 82: 51, 83: 49, 84: 31, 85: 37, 86: 30, 87: 12, 88: 11, 89: 11, 90: 7, 91: 4, 92: 7, 93: 2, 94: 4, 95: 3, 96: 3, 98: 2, 99: 2},
    "anios2000": {60: 1, 61: 3, 62: 15, 63: 20, 64: 64, 65: 62, 66: 81, 67: 115, 68: 105, 69: 99, 70: 102, 71: 117, 72: 129, 73: 113, 74: 110, 75: 92, 76: 76, 77: 91, 78: 81, 79: 73, 80: 75, 81: 53, 82: 54, 83: 48, 84: 46, 85: 36, 86: 22, 87: 22, 88: 10, 89: 6, 90: 6, 91: 9, 92: 3, 93: 5, 94: 3, 95: 2, 96: 2, 97: 2, 98: 3, 99: 1},
    "anios2010": {61: 8, 62: 14, 63: 32, 64: 52, 65: 66, 66: 72, 67: 77, 68: 84, 69: 111, 70: 120, 71: 145, 72: 134, 73: 134, 74: 140, 75: 131, 76: 119, 77: 119, 78: 92, 79: 94, 80: 81, 81: 71, 82: 74, 83: 56, 84: 39, 85: 25, 86: 20, 87: 17, 88: 19, 89: 15, 90: 10, 91: 10, 92: 9, 93: 2, 94: 2, 95: 3, 96: 2, 97: 4, 98: 2},
    "actualidad": {60: 1, 61: 1, 62: 8, 63: 14, 64: 27, 65: 31, 66: 54, 67: 58, 68: 74, 69: 83, 70: 90, 71: 85, 72: 91, 73: 91, 74: 115, 75: 121, 76: 92, 77: 80, 78: 88, 79: 88, 80: 72, 81: 45, 82: 57, 83: 50, 84: 41, 85: 31, 86: 15, 87: 23, 88: 13, 89: 15, 90: 11, 91: 9, 92: 6, 93: 5, 94: 1, 95: 2, 96: 4, 98: 2},
}
# Si una época tiene más cartas que las de la tabla (más ventanas que cartas v1), se estira proporcionalmente.
PRIOR_IMPACTO = -2.0  # impacto (escala BPM) de un jugador de reemplazo: hacia ahí van las muestras chicas
PARTIDOS_CONFIANZA = 50  # con 50 partidos, la mitad del peso es del jugador y la mitad del prior
MINUTOS_REFERENCIA = 24.0
MODERNAS = {"anios80", "anios90", "anios2000", "anios2010", "actualidad"}


def impacto_de_fila(bpm, ws48, per):
    """Impacto por minuto en escala BPM (+10 MVP, 0 promedio, −2 reemplazo). BPM existe desde 1973-74;
    antes se estima con Win Shares por 48 minutos y PER."""
    if bpm is not None:
        return bpm
    if ws48 is None:
        return None
    estimado = (ws48 - 0.100) * 60
    return estimado if per is None else 0.5 * estimado + 0.5 * (per - 15) * 0.6


def puntaje_v3(c):
    """Nivel de una carta (una ventana de temporadas): impacto por minuto (regresado a la media según los
    partidos) + minutos (los entrenadores le dan más minutos al que más sabe) + premios por temporada.
    El volumen sin impacto vale la mitad: jugar mucho siendo peor que un reemplazo no infla la media."""
    gp = c["_gp"]
    peso = gp / (gp + PARTIDOS_CONFIANZA)
    impacto = c["_impacto_norm"] if c.get("_impacto_norm") is not None else PRIOR_IMPACTO
    impacto = peso * impacto + (1 - peso) * PRIOR_IMPACTO
    minutos = c["_mpg"] - MINUTOS_REFERENCIA
    coef = 0.22 if impacto >= 0 else 0.11
    premios = min(c["_tasa_premios"], 12.0)
    # Minutos y premios de una muestra chica también son ruido: pesan lo mismo que el impacto medido.
    return impacto + peso * (0.22 * min(minutos, 0) + coef * max(minutos, 0) + 0.45 * premios)


def momentos_por_epoca(temporadas):
    """(media, desvío) del impacto por temporada-equipo de cada época y los de referencia (épocas con BPM).
    Lleva el impacto de las épocas viejas (Win Shares y PER, y en los 40 minutos estimados) a la escala
    de las modernas; sin esto, los suplentes de 1947 quedarían como figuras."""
    import statistics

    def momentos(filas):
        vals = [t["impacto"] for t in filas if t["impacto"] is not None and t["gp"] >= 40]
        return statistics.fmean(vals), statistics.pstdev(vals) or 1.0

    por_epoca = defaultdict(list)
    for t in temporadas:
        por_epoca[t["epoca"]].append(t)
    ref = momentos([t for e in MODERNAS for t in por_epoca[e]])
    return {e: momentos(g) for e, g in por_epoca.items()}, ref


def normalizar_impacto(cartas):
    """Variante para cartas ya armadas (usada en pruebas): z-score del impacto de cada época contra las
    épocas modernas, con las cartas de 60+ partidos."""
    import statistics

    def momentos(grupo):
        vals = [c["_impacto"] for c in grupo if c["_impacto"] is not None and c["_gp"] >= 60]
        return statistics.fmean(vals), statistics.pstdev(vals) or 1.0

    media_ref, desvio_ref = momentos([c for c in cartas if c["epoca"] in MODERNAS])
    por_epoca = defaultdict(list)
    for c in cartas:
        por_epoca[c["epoca"]].append(c)
    for epoca, grupo in por_epoca.items():
        media, desvio = momentos(grupo)
        for c in grupo:
            if c["_impacto"] is not None:
                c["_impacto_norm"] = media_ref + (c["_impacto"] - media) / desvio * desvio_ref


def asignar_media(cartas, normalizar=True):
    """Media 60–99: dentro de cada época, las cartas (ventanas) se ordenan por puntaje_v3 y se reparten
    según DISTRIBUCION_MEDIA de esa época (estirada si hay más cartas que las v1). `normalizar=False`
    si las cartas ya traen `_impacto_norm` (el catálogo real lo normaliza por temporada)."""
    if normalizar:
        normalizar_impacto(cartas)
    por_epoca = defaultdict(list)
    for c in cartas:
        por_epoca[c["epoca"]].append(c)
    for epoca, grupo in por_epoca.items():
        # Sin minutos registrados (antes de 1951-52) el impacto por minuto no es confiable: esas
        # cartas se ordenan por eficiencia + premios (como en v1) y se intercalan por percentil.
        reales = [c for c in grupo if "minP" not in c.get("estimadas", ())]
        sin_minutos = [c for c in grupo if "minP" in c.get("estimadas", ())]
        percentil = {}
        for sub, clave in ((reales, puntaje_v3), (sin_minutos, lambda c: c["_eficiencia"] + 0.6 * c["_puntos"])):
            for i, c in enumerate(sorted(sub, key=lambda c: (clave(c), c["id"]))):
                percentil[c["id"]] = (i + 0.5) / len(sub)
        orden = sorted(grupo, key=lambda c: (percentil[c["id"]], c["id"]))
        escala = [m for m, n in sorted(DISTRIBUCION_MEDIA[epoca].items()) for _ in range(n)]
        for i, c in enumerate(orden):
            c["media"] = escala[min(len(escala) - 1, int(i * len(escala) / len(orden)))]


# Tier v3: rareza = nivel (media) + premios por temporada de la ventana.
TIER_SPLUS_MEDIA, TIER_SPLUS_PREMIOS = 95, 4.0  # 95+ y, por temporada, ~All-NBA 2º equipo + All-Star
TIER_S_MEDIA, TIER_S_MEDIA_CON_PREMIOS, TIER_S_PREMIOS = 91, 88, 4.0
TIER_A_MEDIA = 79


def tier_v3(c):
    media, tasa = c["media"], c["_tasa_premios"]
    if media >= TIER_SPLUS_MEDIA and (tasa >= TIER_SPLUS_PREMIOS or c["_puntos"] >= 25):
        return "sPlus"
    if media >= TIER_S_MEDIA or (media >= TIER_S_MEDIA_CON_PREMIOS and tasa >= TIER_S_PREMIOS):
        return "s"
    if media >= TIER_A_MEDIA or c["_puntos"] > 0:
        return "a"
    return "b"


tier_v2 = tier_v3  # nombre anterior


# ── Ventanas: partir cada racha de temporadas en tramos homogéneos ──


EDAD_VETERANO, DESCUENTO_EDAD = 33, 0.5  # solo para cortar ventanas: cada año pasados los 33 resta 0.5


def nivel_temporada(t):
    """Nivel de una temporada-equipo para decidir los cortes: el de puntaje_v3 menos un descuento por edad
    (el declive del veterano separa su última ventana aunque el impacto de ese año todavía sea bueno).
    La media de la carta usa puntaje_v3 sin el descuento."""
    nivel = puntaje_v3({
        "_gp": t["gp"], "_mpg": t["mpg"], "_impacto_norm": t["impacto"], "_tasa_premios": t["premios"],
    })
    return nivel - DESCUENTO_EDAD * max(0, (t.get("edad") or 0) - EDAD_VETERANO)


def partir(temporadas):
    """Parte una lista de temporadas consecutivas (dentro de una década) en ventanas de 1 a MAX_TEMPORADAS.

    Programación dinámica: cada ventana cuesta PENALIZACION_VENTANA + la dispersión (ponderada por partidos)
    del nivel de sus temporadas + un pequeño sesgo hacia 3 temporadas; una ventana con menos de MIN_VENTANA
    partidos paga una multa grande. Resultado: se corta donde el nivel cambia (más de ~2 puntos) y, si el
    rendimiento es parejo, cada 3–4 temporadas. Devuelve listas de índices [(desde, hasta_exclusivo)]."""
    n = len(temporadas)
    gp = [t["gp"] for t in temporadas]
    niv = [nivel_temporada(t) for t in temporadas]

    def costo(j, i):
        g = sum(gp[j:i])
        w = [min(x, 82) / 70 for x in gp[j:i]]
        sw = sum(w) or 1.0
        media = sum(wi * x for wi, x in zip(w, niv[j:i])) / sw
        var = sum(wi * (x - media) ** 2 for wi, x in zip(w, niv[j:i]))
        multa = 500 if g < MIN_PARTIDOS else (40 + MIN_VENTANA - g if g < MIN_VENTANA else 0)
        return PENALIZACION_VENTANA + var + 0.4 * (i - j - 3) ** 2 + multa

    mejor = [float("inf")] * (n + 1)
    previo = [0] * (n + 1)
    mejor[0] = 0.0
    for i in range(1, n + 1):
        for j in range(max(0, i - MAX_TEMPORADAS), i):
            c = mejor[j] + costo(j, i)
            if c < mejor[i] - 1e-9:
                mejor[i], previo[i] = c, j
    cortes, i = [], n
    while i > 0:
        cortes.append((previo[i], i))
        i = previo[i]
    return cortes[::-1]


def minimo_partidos(temporadas):
    """20 partidos; 12 (y 250 minutos) si toda la ventana es una parada de traspaso a mitad de temporada:
    Porziņģis en Atlanta y en Golden State no se pierden, y con pocos partidos igual caen a Tier B."""
    if all(t["traspaso"] for t in temporadas) and sum(t["t"]["MIN"] for t in temporadas) >= 250:
        return MIN_PARTIDOS_TRASPASO
    return MIN_PARTIDOS


def fusionar_chicas(ventanas, partidos):
    """Una ventana con menos de MIN_PARTIDOS partidos se une a la vecina (la anterior, si no la siguiente).
    Si queda una sola y es chica, desaparece (se resuelve fuera)."""
    v = [list(x) for x in ventanas]
    cambio = True
    while cambio and len(v) > 1:
        cambio = False
        for k, (j, i) in enumerate(v):
            if sum(partidos[j:i]) < MIN_PARTIDOS:
                if k > 0:
                    v[k - 1][1] = i
                else:
                    v[k + 1][0] = j
                del v[k]
                cambio = True
                break
    return [tuple(x) for x in v]


def id_estable(pid):
    """ID negativo para cartas sin ID oficial de la NBA (no pide fotos al CDN). Determinístico."""
    return -(zlib.crc32(pid.encode()) % 10_000_000) - 1


# Nombre canónico de las universidades que Basketball-Reference abrevia o escribe distinto.
UNIVERSIDADES_ALIAS = {"UNC": "North Carolina", "UConn": "Connecticut", "Pennslyvania": "Pennsylvania"}


def universidad_canonica(nombre):
    """Nombre limpio y estable: sin "University of"/"University", espacios de más ni abreviaturas."""
    n = " ".join((nombre or "").split())
    n = re.sub(r"^University of ", "", n)
    n = re.sub(r" University$", "", n)
    n = n.replace("Pennslyvania", "Pennsylvania")
    return UNIVERSIDADES_ALIAS.get(n, n)


def biografias(carreras, drafts):
    """player_id → {"draft": [año, pick] o None, "universidad": str o None, "nacimiento": año o None}.

    Universidad: la última de la lista (la de egreso, si hubo traspasos). Draft: el último draft de la
    NBA/BAA en el que fue elegido (algunos se volvieron a presentar)."""
    bio = {}
    for f in carreras:
        colegios = [c.strip() for c in next(csv.reader([f.get("colleges") or ""]), []) if c.strip()]
        colegios = [c for c in colegios if c != "NA"]
        nacimiento = (f.get("birth_date") or "")[:4]
        bio[f["player_id"]] = {
            "draft": None,
            "universidad": universidad_canonica(colegios[-1]) if colegios else None,
            "nacimiento": int(nacimiento) if nacimiento.isdigit() else None,
        }
    for f in sorted(drafts, key=lambda f: (int(f["season"]), numero(f["overall_pick"]) or 0)):
        if f["lg"] not in ("NBA", "BAA") or f["player_id"] in ("", "NA"):
            continue
        pick = numero(f["overall_pick"])
        bio.setdefault(f["player_id"], {"draft": None, "universidad": None, "nacimiento": None})
        bio[f["player_id"]]["draft"] = [int(f["season"]), int(pick) if pick else 0]
    return bio


def rachas(anios):
    """Años consecutivos → listas; además se parten en los límites de década (la época de la carta es
    siempre una sola)."""
    salida, actual = [], []
    for a in sorted(anios):
        if actual and (a != actual[-1] + 1 or epoca_de(a) != epoca_de(actual[-1])):
            salida.append(actual)
            actual = []
        actual.append(a)
    if actual:
        salida.append(actual)
    return salida


def sumar_temporadas(temps):
    """Suma las temporadas-equipo de una ventana: totales, posiciones, identidades, impacto, premios."""
    t = dict.fromkeys(ec.CAMPOS, 0.0)
    w = {"pos": Counter(), "ident": Counter(), "est": set(), "sin_gs": False, "imp": [0.0, 0.0],
         "dbpm": [0.0, 0.0], "premios": 0, "sexto": False, "anios": [], "edad": None}
    for s in sorted(temps, key=lambda s: s["anio"]):
        for c in ec.CAMPOS:
            t[c] += s["t"][c]
        w["pos"].update(s["pos"])
        w["ident"].update(s["ident"])
        w["est"] |= s["est"]
        w["sin_gs"] |= s["sin_gs"]
        w["imp"][0] += s["imp"][0]
        w["imp"][1] += s["imp"][1]
        w["dbpm"][0] += s["dbpm"][0]
        w["dbpm"][1] += s["dbpm"][1]
        w["premios"] += s["premios"]
        w["sexto"] |= s["sexto"]
        w["anios"].append(s["anio"])
        if w["edad"] is None:
            w["edad"] = s["edad"]
    w["t"] = t
    return w


def clave_corta(pid, franquicia, anio):
    return f"{pid}-{franquicia}-{anio}"


def main():
    carreras = leer("Player Career Info.csv")
    todas = [f for f in leer("Player Totals.csv") if f["lg"] in ("NBA", "BAA") and int(f["season"]) <= ULTIMA_TEMPORADA]
    bio_fis = Biografico(carreras, todas)
    ref = promedios_referencia(todas, bio_fis)
    filas = [f for f in todas if f["team"] in EQUIPOS]  # sin filas "2TM"/"TOT" de traspasos
    print(f"{len(filas)} filas de temporada de {ec.PRIMER_ANIO} a {ULTIMA_TEMPORADA}")

    # 1) Temporada-equipo: (jugador, franquicia, año) → totales, posiciones, identidad, impacto, premios.
    temps = {}
    nombres = {}
    partidos_temporada = defaultdict(dict)  # (player_id, temporada) → {franquicia: partidos}
    for original in filas:
        f, estimados, pos = completar(original, ref, bio_fis)
        franquicia, identidad = EQUIPOS[f["team"]]
        anio = int(f["season"])
        g = numero(f["g"]) or 0
        if g <= 0:
            continue
        s = temps.setdefault((f["player_id"], franquicia, anio), {
            "anio": anio, "epoca": epoca_de(anio), "t": dict.fromkeys(ec.CAMPOS, 0.0), "pos": Counter(),
            "ident": Counter(), "est": set(), "sin_gs": False, "imp": [0.0, 0.0], "dbpm": [0.0, 0.0],
            "premios": 0, "sexto": False, "edad": None, "gp": 0, "mp_fila": 0.0, "traspaso": False})
        for col, campo in COLUMNAS.items():
            s["t"][campo] += numero(f[col]) or 0
        s["pos"][pos] += g
        s["ident"][identidad] += g
        s["est"] |= {ESTIMABLES[c] for c in estimados if ESTIMABLES[c]}
        if numero(f["gs"]) is None:
            s["sin_gs"] = True
        s["edad"] = int(f["age"]) if (f.get("age") or "").isdigit() else s["edad"]
        s["gp"] += g
        s["mp_fila"] += numero(f["mp"]) or 0
        nombres[f["player_id"]] = f["player"]
        partidos_temporada[(f["player_id"], anio)][franquicia] = g
    principal = {k: max(v, key=v.get) for k, v in partidos_temporada.items()}
    for (pid, franquicia, anio), s in temps.items():
        s["traspaso"] = len(partidos_temporada[(pid, anio)]) > 1

    # Impacto por minuto (BPM; antes de 1974, Win Shares/48 y PER) ponderado por minutos.
    for f in leer("Advanced.csv"):
        if f["lg"] not in ("NBA", "BAA") or f["team"] not in EQUIPOS or int(f["season"]) > ULTIMA_TEMPORADA:
            continue
        anio = int(f["season"])
        s = temps.get((f["player_id"], EQUIPOS[f["team"]][0], anio))
        if s is None:
            continue
        mp = numero(f["mp"]) or s["mp_fila"]
        if mp <= 0:
            continue
        ws48 = numero(f["ws_48"])
        if ws48 is None and (ws := numero(f["ws"])) is not None:
            ws48 = ws / mp * 48
        valor = impacto_de_fila(numero(f["bpm"]), ws48, numero(f["per"]))
        if valor is None:
            continue
        s["imp"][0] += valor * mp
        s["imp"][1] += mp
        if (dbpm := numero(f["dbpm"])) is not None:
            s["dbpm"][0] += dbpm * mp
            s["dbpm"][1] += mp

    # Premios por temporada, atribuidos al equipo con el que más jugó ese año.
    def premiar(pid, anio, valor, es_sexto=False):
        franquicia = principal.get((pid, anio))
        if franquicia and (s := temps.get((pid, franquicia, anio))):
            s["premios"] += valor
            s["sexto"] |= es_sexto

    for f in leer("All-Star Selections.csv"):
        if f["lg"] == "NBA" and int(f["season"]) <= ULTIMA_TEMPORADA:
            premiar(f["player_id"], int(f["season"]), 1)
    for f in leer("End of Season Teams.csv"):
        if f["lg"] in ("NBA", "BAA") and int(f["season"]) <= ULTIMA_TEMPORADA:
            if f["type"] == "All-NBA":
                premiar(f["player_id"], int(f["season"]), ALL_NBA.get(f["number_tm"], 0))
            elif f["type"] == "All-Defense" and f["number_tm"] == "1st":
                premiar(f["player_id"], int(f["season"]), 1)
    for f in leer("Player Award Shares.csv"):
        if f["award"] in PREMIOS and f["winner"] == "TRUE" and int(f["season"]) <= ULTIMA_TEMPORADA:
            premiar(f["player_id"], int(f["season"]), PREMIOS[f["award"]], f["award"] == "nba smoy")
    id_por_nombre_temporada = {(int(f["season"]), f["player"]): f["player_id"] for f in filas}
    for anio, nombre in MVP_FINALES.items():
        pid = id_por_nombre_temporada.get((anio, nombre))
        if pid is None:
            print(f"  aviso: MVP de las Finales {anio} ({nombre}) no encontrado")
            continue
        premiar(pid, anio, 8)
    if ULTIMA_TEMPORADA >= 2026:  # premios de 2025-26 que el dataset todavía no trae
        for premio, nombres_premio in PREMIOS_2026.items():
            for nombre in nombres_premio:
                pid = id_por_nombre_temporada.get((2026, nombre))
                if pid is None:
                    print(f"  aviso: premio 2026 ({nombre}) no encontrado")
                    continue
                valor = {"mvp": PREMIOS["nba mvp"], "dpoy": PREMIOS["nba dpoy"], "smoy": PREMIOS["nba smoy"]}.get(
                    premio) or ALL_NBA[premio]
                premiar(pid, 2026, valor, premio == "smoy")

    # 2) Impacto de cada temporada llevado a la escala moderna (por época) y minutos por partido.
    for s in temps.values():
        s["impacto_crudo"] = s["imp"][0] / s["imp"][1] if s["imp"][1] > 0 else None
        s["impacto"] = s["impacto_crudo"]
        s["mpg"] = s["t"]["MIN"] / s["gp"]
    por_epoca, ref_momentos = momentos_por_epoca(
        [{"epoca": s["epoca"], "impacto": s["impacto_crudo"], "gp": s["gp"]} for s in temps.values()])
    for s in temps.values():
        if s["impacto_crudo"] is not None:
            m, d = por_epoca[s["epoca"]]
            s["impacto"] = ref_momentos[0] + (s["impacto_crudo"] - m) / d * ref_momentos[1]

    # 3) Ventanas: por (jugador, franquicia), rachas consecutivas dentro de una década, partidas por nivel.
    anios_de = defaultdict(set)
    for (pid, franquicia, anio) in temps:
        anios_de[(pid, franquicia)].add(anio)
    ventanas = []  # (pid, franquicia, [temporadas-equipo])
    sueltas = defaultdict(list)  # (pid, franquicia, época) → temporadas de ventanas chicas descartadas
    for (pid, franquicia), anios in sorted(anios_de.items()):
        for racha in rachas(anios):
            ts = [temps[(pid, franquicia, a)] for a in racha]
            gps = [t["gp"] for t in ts]
            partes = fusionar_chicas(partir(ts), gps)
            for j, i in partes:
                if sum(gps[j:i]) >= minimo_partidos(ts[j:i]):
                    ventanas.append((pid, franquicia, ts[j:i]))
                else:
                    sueltas[(pid, franquicia, epoca_de(racha[0]))] += ts[j:i]

    # Por década y franquicia, si ninguna ventana alcanza el mínimo pero el conjunto sí (la carta v2
    # existía), se unen las rachas chicas en una carta con huecos: nunca se pierde un id publicado.
    con_ventana = {(pid, fr, epoca_de(ts[0]["anio"])) for pid, fr, ts in ventanas}
    for (pid, fr, epoca), ts in sorted(sueltas.items()):
        if (pid, fr, epoca) not in con_ventana and sum(t["gp"] for t in ts) >= MIN_PARTIDOS:
            ventanas.append((pid, fr, ts))
    print(f"{len(ventanas)} ventanas")

    # 4) Ids: v2 por década se conserva en una ventana de cada década (la de más partidos); las demás,
    # {jugador}-{franquicia}-{año de inicio}.
    anteriores_ids = {}
    anteriores_cartas = {}
    if ec.SALIDA.exists():
        for c in json.loads(ec.SALIDA.read_text(encoding="utf-8")):
            anteriores_ids[c["id"]] = c["nbaPlayerId"]
            anteriores_cartas[c["id"]] = c
    claves = {}
    for pid, fr, ts in ventanas:
        claves[(pid, fr, ts[0]["anio"])] = (pid, fr, ts)
    if HEREDADOS.exists():
        heredados = json.loads(HEREDADOS.read_text(encoding="utf-8"))
    else:  # primera migración desde el catálogo v2 (una carta por década)
        mejor = {}
        for (pid, fr, anio), (_, _, ts) in sorted(claves.items()):
            vieja = f"{pid}-{fr}-{ec.CODIGO_EPOCA[epoca_de(anio)]}"
            gp = sum(t["gp"] for t in ts)
            if vieja in anteriores_ids and (vieja not in mejor or gp > mejor[vieja][0]):
                mejor[vieja] = (gp, clave_corta(pid, fr, anio))
        heredados = {k: v[1] for k, v in sorted(mejor.items())}
        HEREDADOS.write_text(json.dumps(heredados, indent=0, ensure_ascii=False), encoding="utf-8")
        legado = {k: c for k, c in anteriores_cartas.items() if k not in heredados and not c.get("legado")}
        LEGADO.write_text(json.dumps(sorted(legado.values(), key=lambda c: c["id"]), ensure_ascii=False,
                                     separators=(",", ":")), encoding="utf-8")
        print(f"migración: {len(heredados)} ids v2 heredados, {len(legado)} cartas en legado")
    id_heredado = {v: k for k, v in heredados.items()}

    nba = ids_nba()
    homonimos = defaultdict(list)  # nombre → bbref ids por orden de debut
    for pid in sorted(nombres, key=lambda p: (p[-2:], p)):
        homonimos[normalizar(nombres[pid])].append(pid)

    def id_oficial(pid):
        if pid in ID_FIJO:
            return ID_FIJO[pid]
        candidatos = nba.get(normalizar(ALIAS.get(nombres[pid], nombres[pid])), [])
        indice = homonimos[normalizar(nombres[pid])].index(pid)
        return candidatos[indice] if indice < len(candidatos) else None

    negativo_previo = {}
    for cid, nid in anteriores_ids.items():
        if nid < 0:
            negativo_previo.setdefault(cid.split("-")[0], nid)
    fotos = json.loads(FOTOS.read_text(encoding="utf-8")) if FOTOS.exists() else {}
    bio = biografias(carreras, leer("Draft Pick History.csv"))

    cartas = []
    for pid, fr, ts in sorted(ventanas, key=lambda v: (v[0], v[1], v[2][0]["anio"])):
        w = sumar_temporadas(ts)
        t = w["t"]
        if t["GP"] < MIN_PARTIDOS_TRASPASO or t["MIN"] <= 0:
            continue
        p = ec.perfil_de(t)
        p["dbpm"] = w["dbpm"][0] / w["dbpm"][1] if w["dbpm"][1] >= 200 else None
        if w["sin_gs"]:
            p["suplente"] = False  # sin titularidades registradas no se puede saber
        pos = posiciones(w["pos"], p)
        nba_id = id_oficial(pid)
        anios = sorted(w["anios"])
        epoca = epoca_de(anios[0])
        corta = clave_corta(pid, fr, anios[0])
        card_id = id_heredado.get(corta, corta)
        if not nba_id:
            # Sin ID oficial: un número negativo único (no pide nada al CDN), estable entre corridas.
            nba_id = negativo_previo.get(pid) or id_estable(pid)
        tasa = w["premios"] / max(1, len(anios))
        impacto = w["imp"][0] / w["imp"][1] if w["imp"][1] > 0 else None
        carta = {
            "id": card_id,
            "nbaPlayerId": nba_id,
            "nombre": nombres[pid],
            "franquicia": fr,
            "equipo": w["ident"].most_common(1)[0][0],
            "epoca": epoca,
            "tier": "b",  # se define después de la media (tier_v3)
            "posiciones": pos,
            # Arquetipo de sexto hombre: premiados o suplentes con minutos de rotación fuerte.
            "rol": ec.rol_de(pos[0], p, w["sexto"] or (p["suplente"] and t["MIN"] / t["GP"] >= 22)),
            "dorsal": 0,  # todas o ninguna: el dataset no trae dorsales
            "stats": ec.stats_de(t),
            "temporadas": [anios[0], anios[-1]],
            "draft": bio.get(pid, {}).get("draft"),
            "universidad": bio.get(pid, {}).get("universidad"),
            "nacimiento": bio.get(pid, {}).get("nacimiento"),
            "edad": w["edad"],
            "fotos": fotos.get(pid, ["n", "b", "w"] if nba_id > 0 else ["b", "w"]),
            "_perfil": p,
            "_puntos": w["premios"],
            "_puntos_iq": tasa,
            "_eficiencia": eficiencia(t),
            "_impacto": impacto,
            "_impacto_norm": (sum(s["impacto"] * s["mp_fila"] for s in ts if s["impacto"] is not None)
                              / sum(s["mp_fila"] for s in ts if s["impacto"] is not None))
            if any(s["impacto"] is not None for s in ts) else None,
            "_gp": t["GP"],
            "_mpg": t["MIN"] / t["GP"],
            "_tasa_premios": tasa,
            "_huecos": anios if anios[-1] - anios[0] + 1 != len(anios) else None,
        }
        if w["est"]:
            carta["estimadas"] = sorted(w["est"])
        cartas.append(carta)

    # Ids duplicados (no debería): se aborta.
    ids = Counter(c["id"] for c in cartas)
    repetidos = [i for i, n in ids.items() if n > 1]
    assert not repetidos, f"ids repetidos: {repetidos[:5]}"

    ec.asignar_iq(cartas)
    asignar_media(cartas, normalizar=False)
    for c in cartas:
        c["tier"] = tier_v3(c)
    ajustes = json.loads(ec.AJUSTES.read_text(encoding="utf-8")) if ec.AJUSTES.exists() else {}
    ec.aplicar_ajustes(cartas, ajustes_por_ventana(ajustes, cartas))

    # Legado: cartas v2 que no se pueden recalcular (p. ej. creadas solo por datos de la temporada en
    # curso). Se conservan tal cual y los sorteos las ignoran.
    nuevas = {c["id"] for c in cartas}
    legado = json.loads(LEGADO.read_text(encoding="utf-8")) if LEGADO.exists() else []
    cartas_legado = [dict(c, legado=True) for c in legado if c["id"] not in nuevas]
    # Todo id publicado sigue existiendo.
    for vieja in heredados:
        assert vieja in nuevas, f"falta el id heredado {vieja}"

    if depuracion := os.environ.get("CATALOGO_DEPURACION"):  # volcado de los datos internos, para revisar
        Path(depuracion).write_text(json.dumps({c["id"]: {
            k: c[k] for k in ("_impacto", "_impacto_norm", "_gp", "_mpg", "_tasa_premios", "_puntos")
        } for c in cartas}), encoding="utf-8")
    orden = {"sPlus": 0, "s": 1, "a": 2, "b": 3}
    cartas.sort(key=lambda c: (orden[c["tier"]], -c["media"], c["id"]))
    opcionales = {"draft", "universidad", "nacimiento", "edad"}  # sin dato: no se escribe la clave
    # Formato compacto: `dorsal` (siempre 0) y `equipo` (si es la franquicia) se omiten; Jugador.fromJson
    # usa esos valores por defecto.
    limpias = [
        {k: v for k, v in c.items() if not k.startswith("_") and not (k in opcionales and v is None)
         and not (k == "dorsal" and v == 0) and not (k == "equipo" and v == c["franquicia"])}
        for c in cartas
    ] + cartas_legado
    ec.SALIDA.write_text(json.dumps(limpias, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")

    por_tier = Counter(c["tier"] for c in cartas)
    por_grupo = Counter((c["franquicia"], c["epoca"]) for c in cartas)
    print(f"{len(limpias)} cartas ({len(cartas_legado)} legado; S+ {por_tier['sPlus']}, S {por_tier['s']}, "
          f"A {por_tier['a']}, B {por_tier['b']}); por franquicia y época: mín {min(por_grupo.values())}, "
          f"máx {max(por_grupo.values())}, promedio {len(cartas) / len(por_grupo):.1f}; "
          f"con datos estimados {sum('estimadas' in c for c in cartas)}")


def ajustes_por_ventana(ajustes, cartas):
    """Los ajustes manuales están escritos por id v2 (jugador-franquicia-década): valen para todas las
    ventanas de esa década. El dorsal ya no existe (todas o ninguna)."""
    codigo_a_epoca = {v: k for k, v in ec.CODIGO_EPOCA.items()}
    por_grupo = defaultdict(list)
    for c in cartas:
        pid = c["id"].split("-")[0]
        por_grupo[(pid, c["franquicia"], c["epoca"])].append(c["id"])
    salida = {}
    for clave, cambios in ajustes.items():
        if clave.startswith("_"):
            continue
        cambios = {k: v for k, v in cambios.items() if k != "dorsal"}
        if not cambios:
            continue
        partes = clave.split("-")
        epoca = codigo_a_epoca.get(partes[-1]) if len(partes) == 3 else None
        ids = por_grupo.get((partes[0], partes[1], epoca), []) if epoca else [clave]
        for i in ids:
            salida[i] = cambios
    return salida


if __name__ == "__main__":
    main()
