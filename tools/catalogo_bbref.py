"""Genera el catálogo histórico completo de cartas desde datos públicos de Basketball-Reference.

Fuente: https://github.com/sumitrodatta/bball-reference-datasets (totales por temporada y equipo
desde 1947, posición jugada cada temporada, All-Star, All-NBA/All-Defense y premios).

Una carta = jugador + franquicia + época (década), con al menos MIN_PARTIDOS partidos en ese tramo.
Estadísticas, posiciones, Tier, Rol, IQ y media se calculan solo con ese tramo. La identidad de la
carta (Seattle SuperSonics, Washington Bullets…) es la del equipo con el que más jugó en ese tramo.

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
import re
import unicodedata
import urllib.request
import zlib
from collections import Counter, defaultdict

import extraer_cartas as ec

FUENTE = "https://raw.githubusercontent.com/sumitrodatta/bball-reference-datasets/master/Data/"
CACHE = ec.CACHE / "bbref"
FOTOS = ec.CACHE / "fotos.json"
MIN_PARTIDOS = 20

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
    """Temporadas viejas sin posición: se deduce del perfil (rebotes y asistencias por partido)."""
    g = numero(fila["g"]) or 1
    reb, ast = (numero(fila["trb"]) or 0) / g, (numero(fila["ast"]) or 0) / g
    if reb >= 10:
        return "PÍVOT"
    if reb >= 7.5:
        return "ALA-PÍVOT"
    if ast >= 4:
        return "BASE"
    return "ALERO" if reb >= 5 else "ESCOLTA"


def promedios_referencia(filas):
    """Por posición, cada dato faltante por minuto (o minutos por punto) en sus primeras temporadas."""
    sumas = defaultdict(lambda: [0.0, 0.0])  # (campo, posición) → [dato, minutos]
    for f in filas:
        anio = int(f["season"])
        pos = POSICIONES.get(f["pos"]) or posicion_inferida(f)
        mp = numero(f["mp"])
        for campo, (desde, hasta) in REFERENCIA.items():
            if not desde <= anio <= hasta:
                continue
            if campo == "mp":
                pts = numero(f["pts"])
                if mp and pts:
                    sumas[(campo, pos)][0] += mp
                    sumas[(campo, pos)][1] += pts
            elif (v := numero(f[campo])) is not None and mp:
                sumas[(campo, pos)][0] += v
                sumas[(campo, pos)][1] += mp
    return {k: d / m for k, (d, m) in sumas.items() if m}


def completar(fila, ref):
    """Copia la fila con los datos faltantes estimados; devuelve (fila, campos estimados)."""
    f = dict(fila)
    pos = POSICIONES.get(f["pos"]) or posicion_inferida(f)
    estimados = set()
    if numero(f["mp"]) is None:
        # Minutos por punto de su posición en los primeros años registrados, acotado a 10–42 por partido.
        g = numero(f["g"]) or 1
        mpg = min(42.0, max(10.0, ref[("mp", pos)] * (numero(f["pts"]) or 0) / g))
        f["mp"] = str(mpg * g)
        estimados.add("mp")
    mp = numero(f["mp"])
    for campo in ("trb", "orb", "stl", "blk", "tov"):
        if numero(f[campo]) is None:
            f[campo] = str(ref[(campo, pos)] * mp)
            estimados.add(campo)
    if numero(f["drb"]) is None:
        f["drb"] = str(numero(f["trb"]) - numero(f["orb"]))
    for campo in ("x3p", "x3pa"):  # sin línea de tres: cero real, no estimación
        if numero(f[campo]) is None:
            f[campo] = "0"
    return f, estimados


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
# Si una época tiene más cartas que las de la tabla (temporadas nuevas), se estira proporcionalmente.
PRIOR_IMPACTO = -2.0  # impacto (escala BPM) de un jugador de reemplazo: hacia ahí van las muestras chicas
PARTIDOS_CONFIANZA = 50  # con 50 partidos, la mitad del peso es del jugador y la mitad del prior
MINUTOS_REFERENCIA = 24.0


def impacto_de_fila(bpm, ws48, per):
    """Impacto por minuto en escala BPM (+10 MVP, 0 promedio, −2 reemplazo). BPM existe desde 1973-74;
    antes se estima con Win Shares por 48 minutos y PER."""
    if bpm is not None:
        return bpm
    if ws48 is None:
        return None
    estimado = (ws48 - 0.100) * 60
    return estimado if per is None else 0.5 * estimado + 0.5 * (per - 15) * 0.6


def puntaje_v2(c):
    """Nivel de la carta: impacto por minuto (regresado a la media según los partidos) + minutos (los
    entrenadores le dan más minutos al que más sabe) + premios por temporada (no acumulados)."""
    gp = c["_gp"]
    peso = gp / (gp + PARTIDOS_CONFIANZA)
    impacto = c["_impacto_norm"] if c.get("_impacto_norm") is not None else PRIOR_IMPACTO
    impacto = peso * impacto + (1 - peso) * PRIOR_IMPACTO
    minutos = c["_mpg"] - MINUTOS_REFERENCIA
    premios = min(c["_tasa_premios"], 12.0)
    return impacto + 0.22 * minutos + 0.45 * premios


def normalizar_impacto(cartas):
    """Lleva el impacto de cada época a la escala de las épocas con BPM (desde los 80). Antes de 1974
    se estima con Win Shares y, en los 40, con minutos también estimados: sin esto, los suplentes de
    1947 quedarían como figuras."""
    import statistics

    def momentos(grupo):
        vals = [c["_impacto"] for c in grupo if c["_impacto"] is not None and c["_gp"] >= 60]
        return statistics.fmean(vals), statistics.pstdev(vals) or 1.0

    modernas = {"anios80", "anios90", "anios2000", "anios2010", "actualidad"}
    media_ref, desvio_ref = momentos([c for c in cartas if c["epoca"] in modernas])
    por_epoca = defaultdict(list)
    for c in cartas:
        por_epoca[c["epoca"]].append(c)
    for epoca, grupo in por_epoca.items():
        media, desvio = momentos(grupo)
        for c in grupo:
            if c["_impacto"] is not None:
                c["_impacto_norm"] = media_ref + (c["_impacto"] - media) / desvio * desvio_ref


def asignar_media(cartas):
    """Media 60–99: dentro de cada época, las cartas se ordenan por puntaje_v2 y se reparten según
    DISTRIBUCION_MEDIA de esa época."""
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
        for sub, clave in ((reales, puntaje_v2), (sin_minutos, lambda c: c["_eficiencia"] + 0.6 * c["_puntos"])):
            for i, c in enumerate(sorted(sub, key=lambda c: (clave(c), c["id"]))):
                percentil[c["id"]] = (i + 0.5) / len(sub)
        orden = sorted(grupo, key=lambda c: (percentil[c["id"]], c["id"]))
        escala = [m for m, n in sorted(DISTRIBUCION_MEDIA[epoca].items()) for _ in range(n)]
        for i, c in enumerate(orden):
            c["media"] = escala[min(len(escala) - 1, int(i * len(escala) / len(orden)))]


# Tier v2: rareza = nivel (media) + premios por temporada. Ya no depende de cuánto tiempo estuvo.
TIER_SPLUS_MEDIA, TIER_SPLUS_PREMIOS = 95, 4.0  # 95+ y, por temporada, ~All-NBA 2º equipo + All-Star
TIER_S_MEDIA, TIER_S_MEDIA_CON_PREMIOS, TIER_S_PREMIOS = 91, 88, 4.0
TIER_A_MEDIA = 79


def tier_v2(c):
    media, tasa = c["media"], c["_tasa_premios"]
    if media >= TIER_SPLUS_MEDIA and (tasa >= TIER_SPLUS_PREMIOS or c["_puntos"] >= 25):
        return "sPlus"
    if media >= TIER_S_MEDIA or (media >= TIER_S_MEDIA_CON_PREMIOS and tasa >= TIER_S_PREMIOS):
        return "s"
    if media >= TIER_A_MEDIA or c["_puntos"] > 0:
        return "a"
    return "b"


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


def main():
    todas = [f for f in leer("Player Totals.csv") if f["lg"] in ("NBA", "BAA")]
    ref = promedios_referencia(todas)
    filas = [f for f in todas if f["team"] in EQUIPOS]  # sin filas "2TM"/"TOT" de traspasos
    print(f"{len(filas)} filas de temporada desde {ec.PRIMER_ANIO}")

    grupos = defaultdict(lambda: dict.fromkeys(ec.CAMPOS, 0.0))
    conteo_pos = defaultdict(Counter)
    identidades = defaultdict(Counter)
    estimadas = defaultdict(set)
    sin_gs = set()
    nombres = {}
    partidos_temporada = defaultdict(dict)  # (player_id, temporada) → {franquicia: partidos}
    temporadas = defaultdict(set)  # clave → años de cierre jugados
    minutos_fila = {}  # (player_id, sigla, temporada) → minutos (estimados si faltan)
    for original in filas:
        f, estimados = completar(original, ref)
        franquicia, identidad = EQUIPOS[f["team"]]
        temporada = int(f["season"])
        clave = (f["player_id"], franquicia, epoca_de(temporada))
        for col, campo in COLUMNAS.items():
            grupos[clave][campo] += numero(f[col]) or 0
        g = numero(f["g"]) or 0
        conteo_pos[clave][POSICIONES.get(f["pos"]) or posicion_inferida(f)] += g
        identidades[clave][identidad] += g
        estimadas[clave] |= {ESTIMABLES[c] for c in estimados if ESTIMABLES[c]}
        if numero(f["gs"]) is None:
            sin_gs.add(clave)
        nombres[f["player_id"]] = f["player"]
        partidos_temporada[(f["player_id"], temporada)][franquicia] = g
        if g > 0:
            temporadas[clave].add(temporada)
        minutos_fila[(f["player_id"], f["team"], temporada)] = numero(f["mp"]) or 0
    principal = {k: max(v, key=v.get) for k, v in partidos_temporada.items()}

    # Impacto por minuto (BPM; antes de 1974, Win Shares/48 y PER) ponderado por minutos, por tramo.
    impacto = defaultdict(lambda: [0.0, 0.0, 0.0, 0.0])  # clave → [Σ impacto·min, Σ min, Σ dbpm·min, Σ min dbpm]
    for f in leer("Advanced.csv"):
        if f["lg"] not in ("NBA", "BAA") or f["team"] not in EQUIPOS:
            continue
        temporada = int(f["season"])
        clave = (f["player_id"], EQUIPOS[f["team"]][0], epoca_de(temporada))
        mp = numero(f["mp"]) or minutos_fila.get((f["player_id"], f["team"], temporada), 0)
        if mp <= 0:
            continue
        ws48 = numero(f["ws_48"])
        if ws48 is None and (ws := numero(f["ws"])) is not None:
            ws48 = ws / mp * 48
        valor = impacto_de_fila(numero(f["bpm"]), ws48, numero(f["per"]))
        if valor is None:
            continue
        d = impacto[clave]
        d[0] += valor * mp
        d[1] += mp
        if (dbpm := numero(f["dbpm"])) is not None:
            d[2] += dbpm * mp
            d[3] += mp

    puntos, sexto = defaultdict(int), set()

    def premiar(pid, temporada, valor, es_sexto=False):
        franquicia = principal.get((pid, temporada))
        if franquicia:
            clave = (pid, franquicia, epoca_de(temporada))
            puntos[clave] += valor
            if es_sexto:
                sexto.add(clave)

    for f in leer("All-Star Selections.csv"):
        if f["lg"] == "NBA":
            premiar(f["player_id"], int(f["season"]), 1)
    for f in leer("End of Season Teams.csv"):
        if f["lg"] in ("NBA", "BAA"):
            if f["type"] == "All-NBA":
                premiar(f["player_id"], int(f["season"]), ALL_NBA.get(f["number_tm"], 0))
            elif f["type"] == "All-Defense" and f["number_tm"] == "1st":
                premiar(f["player_id"], int(f["season"]), 1)
    for f in leer("Player Award Shares.csv"):
        if f["award"] in PREMIOS and f["winner"] == "TRUE":
            premiar(f["player_id"], int(f["season"]), PREMIOS[f["award"]], f["award"] == "nba smoy")
    id_por_nombre_temporada = {(int(f["season"]), f["player"]): f["player_id"] for f in filas}
    for temporada, nombre in MVP_FINALES.items():
        pid = id_por_nombre_temporada.get((temporada, nombre))
        if pid is None:
            print(f"  aviso: MVP de las Finales {temporada} ({nombre}) no encontrado")
            continue
        premiar(pid, temporada, 8)

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

    fotos = json.loads(FOTOS.read_text(encoding="utf-8")) if FOTOS.exists() else {}
    # IDs ya publicados (sin ID oficial): se conservan para no cambiar cartas guardadas.
    anteriores = {}
    if ec.SALIDA.exists():
        anteriores = {c["id"]: c["nbaPlayerId"] for c in json.loads(ec.SALIDA.read_text(encoding="utf-8"))}

    bio = biografias(leer("Player Career Info.csv"), leer("Draft Pick History.csv"))

    cartas = []
    for clave, t in grupos.items():
        pid, franquicia, epoca = clave
        if t["GP"] < MIN_PARTIDOS or t["MIN"] <= 0:
            continue
        pts = puntos[clave]
        p = ec.perfil_de(t)
        d = impacto.get(clave)
        p["dbpm"] = d[2] / d[3] if d and d[3] >= 200 else None
        if clave in sin_gs:
            p["suplente"] = False  # sin titularidades registradas no se puede saber
        pos = posiciones(conteo_pos[clave], p)
        nba_id = id_oficial(pid)
        card_id = f"{pid}-{franquicia}-{ec.CODIGO_EPOCA[epoca]}"
        if not nba_id:
            # Sin ID oficial: un número negativo único (no pide nada al CDN), estable entre corridas.
            nba_id = anteriores.get(card_id) if (anteriores.get(card_id) or 0) < 0 else id_estable(pid)
        anios = sorted(temporadas[clave]) or [0]
        carta = {
            "id": card_id,
            "nbaPlayerId": nba_id,
            "nombre": nombres[pid],
            "franquicia": franquicia,
            "equipo": identidades[clave].most_common(1)[0][0],
            "epoca": epoca,
            "tier": "b",  # se define después de la media (tier_v2)
            "posiciones": pos,
            # Arquetipo de sexto hombre: premiados o suplentes con minutos de rotación fuerte.
            "rol": ec.rol_de(pos[0], p, clave in sexto or (p["suplente"] and t["MIN"] / t["GP"] >= 22)),
            "dorsal": 0,  # el dataset no trae dorsales; se cargan en ajustes_cartas.json
            "stats": ec.stats_de(t),
            "temporadas": [anios[0], anios[-1]],
            "draft": bio.get(pid, {}).get("draft"),
            "universidad": bio.get(pid, {}).get("universidad"),
            "nacimiento": bio.get(pid, {}).get("nacimiento"),
            "fotos": fotos.get(pid, ["n", "b", "w"] if nba_id else ["b", "w"]),
            "_perfil": p,
            "_puntos": pts,
            "_eficiencia": eficiencia(t),
            "_impacto": d[0] / d[1] if d and d[1] > 0 else None,
            "_gp": t["GP"],
            "_mpg": t["MIN"] / t["GP"],
            "_tasa_premios": pts / max(1, len(temporadas[clave])),
        }
        if estimadas[clave]:
            carta["estimadas"] = sorted(estimadas[clave])
        cartas.append(carta)

    ec.asignar_iq(cartas)
    asignar_media(cartas)
    for c in cartas:
        c["tier"] = tier_v2(c)
    ajustes = json.loads(ec.AJUSTES.read_text(encoding="utf-8")) if ec.AJUSTES.exists() else {}
    ec.aplicar_ajustes(cartas, ajustes)
    orden = {"sPlus": 0, "s": 1, "a": 2, "b": 3}
    cartas.sort(key=lambda c: (orden[c["tier"]], -c["media"]))
    opcionales = {"draft", "universidad", "nacimiento"}  # sin dato: no se escribe la clave
    limpias = [
        {k: v for k, v in c.items() if not k.startswith("_") and not (k in opcionales and v is None)}
        for c in cartas
    ]
    ec.SALIDA.write_text(json.dumps(limpias, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")

    por_tier = Counter(c["tier"] for c in limpias)
    por_grupo = Counter((c["franquicia"], c["epoca"]) for c in limpias)
    print(f"{len(limpias)} cartas (S+ {por_tier['sPlus']}, S {por_tier['s']}, A {por_tier['a']}, "
          f"B {por_tier['b']}); por franquicia y época: mín {min(por_grupo.values())}, "
          f"máx {max(por_grupo.values())}, promedio {len(limpias) / len(por_grupo):.1f}; "
          f"con datos estimados {sum('estimadas' in c for c in limpias)}")


if __name__ == "__main__":
    main()
