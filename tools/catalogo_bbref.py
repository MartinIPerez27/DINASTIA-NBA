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

# Tier A sin premios: titular productivo. El resto de los que llegan a MIN_PARTIDOS es Tier B.
MIN_MINUTOS_A = 20
MIN_EFICIENCIA_A = 11.0

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


def asignar_media(cartas):
    """Media 60–99 en escala absoluta: eficiencia corregida por época (en los 60 se jugaba a otro ritmo)
    más premios, con rendimientos decrecientes. ~66 suplente, ~78 titular, ~89 All-Star, 97+ GOAT."""
    import math

    por_epoca = defaultdict(list)
    for c in cartas:
        if c["tier"] != "b":
            por_epoca[c["epoca"]].append(c["_eficiencia"])
    media_epoca = {e: sum(v) / len(v) for e, v in por_epoca.items()}
    base = media_epoca.get("anios2010", 1)
    for c in cartas:
        eficiencia_ajustada = c["_eficiencia"] * base / media_epoca.get(c["epoca"], base)
        puntaje = max(0.0, eficiencia_ajustada + 0.6 * c["_puntos"])
        c["media"] = min(99, round(60 + 39 * (1 - math.exp(-puntaje / 18))))


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

    cartas = []
    for clave, t in grupos.items():
        pid, franquicia, epoca = clave
        if t["GP"] < MIN_PARTIDOS or t["MIN"] <= 0:
            continue
        pts = puntos[clave]
        tier = ec.tier_de(pts)
        if not tier:
            productivo = t["MIN"] / t["GP"] >= MIN_MINUTOS_A and eficiencia(t) >= MIN_EFICIENCIA_A
            tier = "a" if productivo else "b"
        p = ec.perfil_de(t)
        if clave in sin_gs:
            p["suplente"] = False  # sin titularidades registradas no se puede saber
        pos = posiciones(conteo_pos[clave], p)
        nba_id = id_oficial(pid)
        carta = {
            "id": f"{pid}-{franquicia}-{ec.CODIGO_EPOCA[epoca]}",
            # ID oficial para la foto; sin cruce, un número negativo único (no pide nada al CDN).
            "nbaPlayerId": nba_id if nba_id else -(abs(hash(pid)) % 10_000_000) - 1,
            "nombre": nombres[pid],
            "franquicia": franquicia,
            "equipo": identidades[clave].most_common(1)[0][0],
            "epoca": epoca,
            "tier": tier,
            "posiciones": pos,
            # Arquetipo de sexto hombre: premiados o suplentes con minutos de rotación fuerte.
            "rol": ec.rol_de(pos[0], p, clave in sexto or (p["suplente"] and t["MIN"] / t["GP"] >= 22)),
            "dorsal": 0,  # el dataset no trae dorsales; se cargan en ajustes_cartas.json
            "stats": ec.stats_de(t),
            "fotos": fotos.get(pid, ["n", "b", "w"] if nba_id else ["b", "w"]),
            "_perfil": p,
            "_puntos": pts,
            "_eficiencia": eficiencia(t),
        }
        if estimadas[clave]:
            carta["estimadas"] = sorted(estimadas[clave])
        cartas.append(carta)

    ec.asignar_iq(cartas)
    asignar_media(cartas)
    ajustes = json.loads(ec.AJUSTES.read_text(encoding="utf-8")) if ec.AJUSTES.exists() else {}
    ec.aplicar_ajustes(cartas, ajustes)
    orden = {"sPlus": 0, "s": 1, "a": 2, "b": 3}
    cartas.sort(key=lambda c: (orden[c["tier"]], -c["media"]))
    limpias = [{k: v for k, v in c.items() if not k.startswith("_")} for c in cartas]
    ec.SALIDA.write_text(json.dumps(limpias, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")

    por_tier = Counter(c["tier"] for c in limpias)
    por_grupo = Counter((c["franquicia"], c["epoca"]) for c in limpias)
    print(f"{len(limpias)} cartas (S+ {por_tier['sPlus']}, S {por_tier['s']}, A {por_tier['a']}, "
          f"B {por_tier['b']}); por franquicia y época: mín {min(por_grupo.values())}, "
          f"máx {max(por_grupo.values())}, promedio {len(limpias) / len(por_grupo):.1f}; "
          f"con datos estimados {sum('estimadas' in c for c in limpias)}")


if __name__ == "__main__":
    main()
