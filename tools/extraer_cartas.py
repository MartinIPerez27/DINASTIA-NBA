"""Genera assets/database/nba_players.json desde stats.nba.com con nba_api (GDD §9.4).

Una carta = un jugador + una franquicia + una época. Estadísticas, posiciones, Tier, Rol e IQ
se calculan SOLO con las temporadas de esa franquicia en esa época: el LeBron de Cleveland
2014-18 y el LeBron de los Lakers actuales son cartas distintas, con números distintos.

Uso (en tu PC; stats.nba.com bloquea servidores en la nube):
    pip install nba_api
    python tools/extraer_cartas.py                 # catálogo completo (~40 min la 1ª vez)
    python tools/extraer_cartas.py --solo 2544,893  # prueba rápida con algunos jugadores

Las respuestas se guardan en tools/.cache/: si se corta, volvé a ejecutar y sigue donde quedó.
Las correcciones manuales van en tools/ajustes_cartas.json y se aplican al final.
"""

import argparse
import json
import time
from collections import defaultdict
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
CACHE = RAIZ / "tools" / ".cache"
SALIDA = RAIZ / "assets" / "database" / "nba_players.json"
AJUSTES = RAIZ / "tools" / "ajustes_cartas.json"

# TEAM_ID no cambia cuando la franquicia se muda (Seattle → OKC, New Jersey → Brooklyn).
EQUIPOS = {
    1610612737: "ATL", 1610612738: "BOS", 1610612739: "CLE", 1610612740: "NOP", 1610612741: "CHI",
    1610612742: "DAL", 1610612743: "DEN", 1610612744: "GSW", 1610612745: "HOU", 1610612746: "LAC",
    1610612747: "LAL", 1610612748: "MIA", 1610612749: "MIL", 1610612750: "MIN", 1610612751: "BKN",
    1610612752: "NYK", 1610612753: "ORL", 1610612754: "IND", 1610612755: "PHI", 1610612756: "PHX",
    1610612757: "POR", 1610612758: "SAC", 1610612759: "SAS", 1610612760: "OKC", 1610612761: "TOR",
    1610612762: "UTA", 1610612763: "MEM", 1610612764: "WAS", 1610612765: "DET", 1610612766: "CHA",
}

CODIGO_EPOCA = {
    "anios40": "40", "anios50": "50", "anios60": "60", "anios70": "70", "anios80": "80",
    "anios90": "90", "anios2000": "00", "anios2010": "10", "actualidad": "act",
}
EPOCA_POR_DECADA = {1940: "anios40", 1950: "anios50", 1960: "anios60", 1970: "anios70", 1980: "anios80",
                    1990: "anios90", 2000: "anios2000", 2010: "anios2010"}
PRIMER_ANIO = 1947  # primera temporada BAA/NBA (1946-47)

# Peso de cada premio para medir el nivel del jugador en ese tramo.
PUNTOS_PREMIO = {
    "NBA Most Valuable Player": 10,
    "NBA Finals Most Valuable Player": 8,
    "NBA Defensive Player of the Year": 3,
    "NBA Sixth Man of the Year": 2,
    "NBA All-Star": 1,
}
PUNTOS_ALL_NBA = {"1": 5, "2": 3, "3": 2}
SEXTO_HOMBRE_DEL_ANIO = "NBA Sixth Man of the Year"

TIER_S_PLUS = 25  # p. ej. un MVP + varios 1er equipo All-NBA
TIER_S = 8
MIN_PARTIDOS = 82  # al menos una temporada completa con esa franquicia en esa época

CAMPOS = ["GP", "GS", "MIN", "FGM", "FGA", "FG3M", "FG3A", "FTM", "FTA",
          "OREB", "DREB", "REB", "AST", "STL", "BLK", "TOV", "PTS"]

# Posición de carrera (CommonPlayerInfo) → posiciones del juego, en orden de preferencia.
FAMILIAS = {
    "Guard": ["BASE", "ESCOLTA"],
    "Guard-Forward": ["ESCOLTA", "ALERO"],
    "Forward-Guard": ["ALERO", "ESCOLTA"],
    "Forward": ["ALERO", "ALA-PÍVOT"],
    "Forward-Center": ["ALA-PÍVOT", "PÍVOT"],
    "Center-Forward": ["PÍVOT", "ALA-PÍVOT"],
    "Center": ["PÍVOT"],
}


def epoca_de(season_id):
    """'2015-16' → 'anios2010'. Se usa el año de cierre: 2009-10 a 2018-19 son los Años 2010."""
    fin = int(season_id[:4]) + 1
    if fin < PRIMER_ANIO:
        return None
    if fin >= 2020:
        return "actualidad"
    return EPOCA_POR_DECADA[fin // 10 * 10]


def agrupar(carrera):
    """Suma totales por (franquicia, época) y anota el equipo principal de cada temporada."""
    grupos = defaultdict(lambda: dict.fromkeys(CAMPOS, 0))
    partidos_por_temporada = defaultdict(dict)  # season -> {abbr: GP}
    for fila in carrera:
        abbr, epoca = EQUIPOS.get(fila["TEAM_ID"]), epoca_de(fila["SEASON_ID"])
        if not abbr or not epoca:  # TEAM_ID 0 = fila "TOT" de traspasos; ABA/pre-1980 fuera
            continue
        g = grupos[(abbr, epoca)]
        for c in CAMPOS:
            g[c] += fila.get(c) or 0  # temporadas viejas no registran GS/TOV: cuentan como 0
        partidos_por_temporada[fila["SEASON_ID"]][abbr] = fila.get("GP") or 0
    equipo_principal = {s: max(eq, key=eq.get) for s, eq in partidos_por_temporada.items()}
    return grupos, equipo_principal


def premios_por_grupo(premios, equipo_principal):
    """Puntos de premios y si ganó Sexto Hombre del Año, por (franquicia, época)."""
    puntos, sexto = defaultdict(int), set()
    for p in premios:
        temporada = p.get("SEASON") or ""
        abbr = equipo_principal.get(temporada)
        if not abbr:
            continue
        clave = (abbr, epoca_de(temporada))
        if p["DESCRIPTION"] == "All-NBA":
            puntos[clave] += PUNTOS_ALL_NBA.get(str(p.get("ALL_NBA_TEAM_NUMBER")), 0)
        else:
            puntos[clave] += PUNTOS_PREMIO.get(p["DESCRIPTION"], 0)
        if p["DESCRIPTION"] == SEXTO_HOMBRE_DEL_ANIO:
            sexto.add(clave)
    return puntos, sexto


def tier_de(puntos):
    if puntos >= TIER_S_PLUS:
        return "sPlus"
    if puntos >= TIER_S:
        return "s"
    return "a" if puntos > 0 else None  # sin premios en el tramo: no es carta


def stats_de(t):
    gp = t["GP"]

    def pg(c):
        return round(t[c] / gp, 1)

    def pct(m, a):
        return round(t[m] / t[a], 3) if t[a] else 0.0

    return {
        "ppp": pg("PTS"), "rpp": pg("REB"), "app": pg("AST"), "robP": pg("STL"), "tapP": pg("BLK"),
        "pctTc": pct("FGM", "FGA"), "pctT3": pct("FG3M", "FG3A"), "pctTl": pct("FTM", "FTA"),
        "minP": pg("MIN"), "perP": pg("TOV"),
    }


def perfil_de(t):
    """Producción por 36 minutos y tasas de tiro: describe el estilo, no el volumen."""
    minutos, fga = t["MIN"] or 1, t["FGA"] or 1
    p = {k.lower(): t[k] * 36 / minutos for k in ("PTS", "REB", "OREB", "AST", "STL", "BLK")}
    p["tres"] = t["FG3A"] / fga
    p["libres"] = t["FTA"] / fga
    p["ts"] = t["PTS"] / (2 * (t["FGA"] + 0.44 * t["FTA"])) if t["FGA"] else 0.0
    p["ast_per"] = t["AST"] / t["TOV"] if t["TOV"] else None
    p["suplente"] = 0 < t["GS"] < t["GP"] * 0.35
    return p


def posiciones_de(posicion_carrera, p):
    pos = list(FAMILIAS.get(posicion_carrera, ["ALERO", "ALA-PÍVOT"]))
    if pos == ["BASE", "ESCOLTA"] and p["ast"] < 6:
        pos.reverse()  # escolta que casi no organiza
    if pos[0] == "ALERO" and p["reb"] >= 9 and p["tres"] < 0.2:
        pos[0:2] = ["ALA-PÍVOT", "ALERO"]
    if "BASE" not in pos and pos[0] != "PÍVOT" and p["ast"] >= 8:
        pos.append("BASE")  # p. ej. LeBron en Lakers organizando
    if pos == ["PÍVOT"] and (p["ast"] >= 5 or p["tres"] >= 0.2):
        pos.append("ALA-PÍVOT")  # pívot con manos o tiro abre a la posición 4
    if pos[0] == "ALA-PÍVOT" and "PÍVOT" not in pos and p["blk"] >= 2:
        pos.append("PÍVOT")
    return pos


def rol_de(posicion, p, sexto_hombre):
    """Arquetipo del GDD §3.2 a partir del perfil estadístico en ese tramo."""
    if sexto_hombre:
        if p["ast"] >= 5:
            return "directorSegundaUnidad"
        return "microondas" if p["pts"] >= 20 else "inyeccionEnergia"
    if posicion == "BASE":
        if p["stl"] >= 2 and p["pts"] < 18:
            return "baseDefensivo"
        if p["tres"] >= 0.35:
            return "anotadorExterior"
        if p["libres"] >= 0.35 and p["pts"] >= 22:
            return "penetradorAtletico"
        return "organizadorPuro" if p["ast"] >= 7 else "penetradorAtletico"
    if posicion == "ESCOLTA":
        if p["pts"] < 15 and (p["stl"] >= 1.8 or p["tres"] >= 0.45):
            return "especialista3D"
        if p["ast"] >= 6:
            return "escoltaGenerador"
        if p["tres"] >= 0.4 and p["libres"] < 0.25:
            return "tiradorPantallas"
        return "superestrellaAclarados" if p["pts"] >= 20 else "tiradorPantallas"
    if posicion == "ALERO":
        if p["reb"] >= 11:
            return "fuerzaBruta"  # alero de pura energía en la pintura (Rodman en Detroit)
        if p["ast"] >= 5.5:
            return "controladorTotal"
        if p["stl"] + p["blk"] >= 2.6 and p["pts"] < 17:
            return "cerrojoDefensivo"
        if p["pts"] >= 22:
            return "anotadorTresNiveles"
        return "aleroCortador" if p["reb"] >= 7 or p["oreb"] >= 2.2 or p["libres"] >= 0.3 else "cerrojoDefensivo"
    if posicion == "ALA-PÍVOT":
        if p["ast"] >= 4.5:
            return "distribuidorInterior"
        if p["tres"] >= 0.2:
            return "alaPivotTirador"
        if p["pts"] >= 18 and p["tres"] < 0.1:
            return "maestroPoste"
        if p["reb"] >= 11.5 or p["oreb"] >= 3.5:
            return "fuerzaBruta"
        return "maestroPoste" if p["pts"] >= 16 else "fuerzaBruta"
    # PÍVOT
    if p["ast"] >= 5:
        return "pivotOrganizador"
    if p["tres"] >= 0.25:
        return "pivotTirador"
    if p["libres"] >= 0.45 and p["pts"] >= 18:
        return "goliatPintura"
    if p["pts"] >= 21:
        return "juegoDePies"
    if p["blk"] >= 1.8:
        return "protectorAro"
    return "goliatPintura" if p["reb"] >= 12 or p["oreb"] >= 4 else "protectorAro"


def dorsal_de(jersey):
    # shortcut: CommonPlayerInfo da el último dorsal; si cambió por época, corregir en ajustes_cartas.json
    digitos = "".join(c for c in str(jersey or "").split("-")[0] if c.isdigit())
    return int(digitos) if digitos else 0


def cartas_de_jugador(info, carrera, premios):
    grupos, equipo_principal = agrupar(carrera)
    puntos, sexto = premios_por_grupo(premios, equipo_principal)
    cartas = []
    for (abbr, epoca), t in grupos.items():
        tier = tier_de(puntos[(abbr, epoca)])
        if t["GP"] < MIN_PARTIDOS or not tier:
            continue
        p = perfil_de(t)
        pos = posiciones_de(info.get("POSITION") or "", p)
        cartas.append({
            "id": f"{info['PERSON_ID']}-{abbr}-{CODIGO_EPOCA[epoca]}",
            "nbaPlayerId": info["PERSON_ID"],
            "nombre": info["DISPLAY_FIRST_LAST"],
            "franquicia": abbr,
            "epoca": epoca,
            "tier": tier,
            "posiciones": pos,
            "rol": rol_de(pos[0], p, (abbr, epoca) in sexto or p["suplente"]),
            "dorsal": dorsal_de(info.get("JERSEY")),
            "stats": stats_de(t),
            "_perfil": p,
            "_puntos": puntos[(abbr, epoca)],
        })
    return cartas


def _percentiles(valores):
    posicion = {v: i for i, v in enumerate(sorted(valores))}  # O(n log n): el catálogo tiene miles
    n = len(valores)
    return [posicion[v] / (n - 1) if n > 1 else 1.0 for v in valores]


def asignar_iq(cartas):
    """IQ 60–99: toma de decisiones (ast/pérdida), eficiencia vs. su época, premios y defensa.
    Es relativo al catálogo: todos son All-Stars, así que el piso es 60."""
    if not cartas:
        return
    ts_epoca = defaultdict(list)
    for c in cartas:
        ts_epoca[c["epoca"]].append(c["_perfil"]["ts"])
    media_ts = {e: sum(v) / len(v) for e, v in ts_epoca.items()}
    conocidos = sorted(c["_perfil"]["ast_per"] for c in cartas if c["_perfil"]["ast_per"] is not None)
    mediana_ast = conocidos[len(conocidos) // 2] if conocidos else 1.5

    componentes = [
        (0.35, [c["_perfil"]["ast_per"] or mediana_ast for c in cartas]),
        (0.35, [c["_perfil"]["ts"] - media_ts[c["epoca"]] for c in cartas]),
        (0.15, [c["_puntos"] for c in cartas]),
        (0.15, [c["_perfil"]["stl"] + c["_perfil"]["blk"] for c in cartas]),
    ]
    rangos = [(peso, _percentiles(vals)) for peso, vals in componentes]
    for i, c in enumerate(cartas):
        compuesto = sum(peso * r[i] for peso, r in rangos)
        c["stats"]["iq"] = round(60 + 39 * compuesto)


def aplicar_ajustes(cartas, ajustes):
    por_id = {c["id"]: c for c in cartas}
    for card_id, cambios in ajustes.items():
        if card_id.startswith("_"):
            continue  # claves de comentario
        if card_id not in por_id:
            print(f"  aviso: ajuste para carta inexistente {card_id}")
            continue
        if cambios.get("excluir"):
            cartas.remove(por_id.pop(card_id))
            continue
        for campo, valor in cambios.items():
            if campo == "iq":
                por_id[card_id]["stats"]["iq"] = valor
            else:
                por_id[card_id][campo] = valor


def api(endpoint, **params):
    """Llamada a stats.nba.com con caché en disco y reintentos con espera creciente."""
    archivo = CACHE / f"{endpoint}_{'_'.join(f'{k}-{v}' for k, v in sorted(params.items()))}.json"
    if archivo.exists():
        return json.loads(archivo.read_text(encoding="utf-8"))
    from nba_api.stats import endpoints

    for intento in range(4):
        try:
            datos = getattr(endpoints, endpoint)(**params, timeout=60).get_normalized_dict()
            break
        except Exception as e:  # timeouts y bloqueos de tasa
            if intento == 3:
                raise
            espera = 5 * 2**intento
            print(f"  {endpoint} {params}: {e!r}; reintento en {espera}s")
            time.sleep(espera)
    time.sleep(0.6)  # respetar el límite de tasa
    CACHE.mkdir(parents=True, exist_ok=True)
    archivo.write_text(json.dumps(datos), encoding="utf-8")
    return datos


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--solo", help="IDs de jugadores separados por coma (prueba rápida)")
    args = parser.parse_args()

    if args.solo:
        ids = [int(x) for x in args.solo.split(",")]
    else:
        todos = api("CommonAllPlayers", is_only_current_season=0)["CommonAllPlayers"]
        ids = [j["PERSON_ID"] for j in todos if int(j.get("TO_YEAR") or 0) >= 1980]

    cartas = []
    for n, pid in enumerate(ids, 1):
        premios = api("PlayerAwards", player_id=pid)["PlayerAwards"]
        if not any(p["DESCRIPTION"] in PUNTOS_PREMIO or p["DESCRIPTION"] == "All-NBA" for p in premios):
            continue  # nunca fue All-Star ni ganó premios: no entra al catálogo
        carrera = api("PlayerCareerStats", player_id=pid)["SeasonTotalsRegularSeason"]
        info = api("CommonPlayerInfo", player_id=pid)["CommonPlayerInfo"][0]
        nuevas = cartas_de_jugador(info, carrera, premios)
        cartas += nuevas
        print(f"[{n}/{len(ids)}] {info['DISPLAY_FIRST_LAST']}: {len(nuevas)} carta(s)")

    asignar_iq(cartas)
    aplicar_ajustes(cartas, json.loads(AJUSTES.read_text(encoding="utf-8")) if AJUSTES.exists() else {})
    orden_tier = {"sPlus": 0, "s": 1, "a": 2}
    cartas.sort(key=lambda c: (orden_tier[c["tier"]], -c["stats"]["ppp"]))
    limpias = [{k: v for k, v in c.items() if not k.startswith("_")} for c in cartas]
    SALIDA.write_text(json.dumps(limpias, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"\n{len(limpias)} cartas → {SALIDA.relative_to(RAIZ)}")


if __name__ == "__main__":
    main()
