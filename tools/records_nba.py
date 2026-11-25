"""Genera assets/database/records_nba.json: los récords históricos reales de la NBA para Mi carrera.

Fuente: Basketball-Reference (páginas públicas de líderes). Se usa solo la tabla de la NBA (no la ABA):
  * Carrera: totales (puntos, rebotes, asistencias, robos, tapones, triples y triples-dobles), top 15.
  * Temporada: promedios por partido (puntos, rebotes, asistencias, robos y tapones), top 10.
  * Partido: marcas en un solo partido (puntos, rebotes, asistencias, robos, tapones y triples), top 10.
Los jugadores en actividad vienen marcados (`activo`). El archivo guarda la fecha en que se generó.

Uso:
    python tools/records_nba.py            # baja las páginas y escribe el JSON
    python -m unittest tools/test_records_nba.py
"""

import json
import re
import sys
import time
import urllib.request
from datetime import date
from html.parser import HTMLParser
from pathlib import Path

BASE = "https://www.basketball-reference.com/leaders/"
SALIDA = Path(__file__).resolve().parent.parent / "assets" / "database" / "records_nba.json"

CARRERA = {
    "puntos": ("pts_career", "Puntos"),
    "rebotes": ("trb_career", "Rebotes"),
    "asistencias": ("ast_career", "Asistencias"),
    "robos": ("stl_career", "Robos"),
    "tapones": ("blk_career", "Tapones"),
    "triples": ("fg3_career", "Triples"),
    "triplesDobles": ("trp_dbl_career", "Triples-dobles"),
}
TEMPORADA = {
    "puntos": ("pts_per_g_season", "Puntos por partido"),
    "rebotes": ("trb_per_g_season", "Rebotes por partido"),
    "asistencias": ("ast_per_g_season", "Asistencias por partido"),
    "robos": ("stl_per_g_season", "Robos por partido"),
    "tapones": ("blk_per_g_season", "Tapones por partido"),
}
# Las listas por partido de Basketball-Reference no cubren las épocas viejas (no figuran, por ejemplo, los 55 rebotes de
# Chamberlain): los récords de puntos, rebotes, asistencias, robos y tapones salen de Wikipedia (listas completas de la
# NBA, temporada regular). Los triples, que existen desde 1979, salen de Basketball-Reference.
PARTIDO_WIKI = {
    "puntos": ("List_of_NBA_single-game_scoring_leaders", "Points", "Puntos en un partido"),
    "rebotes": ("List_of_NBA_single-game_rebounding_leaders", "Rebounds", "Rebotes en un partido"),
    "asistencias": ("List_of_NBA_single-game_assists_leaders", "Assists", "Asistencias en un partido"),
    "robos": ("List_of_NBA_single-game_steals_leaders", "Steals", "Robos en un partido"),
    "tapones": ("List_of_NBA_single-game_blocks_leaders", "Blocks", "Tapones en un partido"),
}
PARTIDO = {"triples": ("fg3_game", "Triples en un partido")}


class _Tablas(HTMLParser):
    """Lee todas las tablas: cada una con su id y filas de celdas (texto, ¿en negrita?)."""

    def __init__(self):
        super().__init__()
        self.tablas = []  # [(id, [[(texto, negrita)]])]
        self._actual = None
        self._fila = None
        self._celda = None
        self._negrita = False
        self._strong = 0

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == "table":
            self._actual = (a.get("id", ""), [])
        elif tag == "tr" and self._actual is not None:
            self._fila = []
        elif tag in ("td", "th") and self._fila is not None:
            self._celda = []
            self._negrita = False
        elif tag == "strong" and self._celda is not None:
            self._negrita = True

    def handle_endtag(self, tag):
        if tag in ("td", "th") and self._celda is not None and self._fila is not None:
            self._fila.append((" ".join("".join(self._celda).split()), self._negrita))
            self._celda = None
        elif tag == "tr" and self._fila is not None and self._actual is not None:
            if self._fila:
                self._actual[1].append(self._fila)
            self._fila = None
        elif tag == "table" and self._actual is not None:
            self.tablas.append(self._actual)
            self._actual = None

    def handle_data(self, d):
        if self._celda is not None:
            self._celda.append(d)


def tablas(html):
    p = _Tablas()
    p.feed(html)
    return p.tablas


def _numero(txt):
    txt = txt.replace(",", "").strip()
    return float(txt) if "." in txt else int(txt)


def _limpiar(nombre):
    return nombre.replace("*", "").strip()


def filas_carrera(html, tope=15):
    """Tabla 'nba' de una página de totales de carrera: [{nombre, valor, activo}]."""
    for ident, filas in tablas(html):
        if ident != "nba":
            continue
        salida = []
        for f in filas[1:]:
            if len(f) < 3:
                continue
            (nombre, activo), (valor, _) = f[1], f[2]
            salida.append({"nombre": _limpiar(nombre), "valor": _numero(valor), "activo": bool(activo)})
            if len(salida) >= tope:
                break
        return salida
    raise ValueError("no hay tabla 'nba'")


def filas_temporada(html, tope=10):
    """Tabla 'stats_NBA' de promedios por partido de una temporada: [{nombre, valor, temporada}]."""
    for ident, filas in tablas(html):
        if ident != "stats_NBA":
            continue
        return [
            {"nombre": _limpiar(f[1][0]), "valor": float(f[2][0]), "temporada": f[3][0], "activo": f[1][1]}
            for f in filas[1 : tope + 1]
            if len(f) >= 4
        ]
    raise ValueError("no hay tabla 'stats_NBA'")


def filas_partido(html, tope=10):
    """Primera tabla de una página de marcas en un partido: [{nombre, valor, fecha, equipo}]."""
    ts = tablas(html)
    if not ts:
        raise ValueError("sin tablas")
    filas = ts[0][1]
    return [
        {"nombre": _limpiar(f[1][0]), "valor": _numero(f[2][0]), "fecha": f[3][0], "equipo": f[4][0], "activo": f[1][1]}
        for f in filas[1 : tope + 1]
        if len(f) >= 5
    ]


def filas_partido_wiki(html, columna, tope=10):
    """Primera tabla de una lista de Wikipedia cuyo encabezado trae [columna] (Points, Rebounds…): [{nombre, valor, fecha, equipo}].

    Las celdas combinadas (varios jugadores con la misma marca) llegan sin el valor: se hereda el de la fila anterior."""
    for _ident, filas in tablas(html):
        if len(filas) < 10:
            continue
        cab = [c[0] for c in filas[0]]
        if columna not in cab or "Player" not in cab or "Date" not in cab:
            continue
        iv, ip, ifecha = cab.index(columna), cab.index("Player"), cab.index("Date")
        ie = cab.index("Team") if "Team" in cab else None
        salida, ultimo = [], None
        for f in filas[1:]:
            celdas = [c[0] for c in f]
            if len(celdas) < len(cab):
                celdas = [ultimo] + celdas  # el valor venía combinado con la fila anterior
            try:
                valor = _numero(re.sub(r"[^0-9.,]", "", celdas[iv]))
            except (ValueError, IndexError):
                continue
            nombre = re.sub(r"\s*\(\d+\)$", "", re.sub(r"[\^†‡*]", "", celdas[ip]).strip())
            if not nombre or re.search(r"\d", nombre):
                continue  # fila de un empate con varias celdas combinadas: no se puede alinear, se descarta
            ultimo = celdas[iv]
            salida.append(
                {
                    "nombre": nombre,
                    "valor": valor,
                    "fecha": celdas[ifecha],
                    "equipo": celdas[ie] if ie is not None else "",
                    "activo": "^" in celdas[ip] or "[a]" in celdas[ip],
                }
            )
            if len(salida) >= tope:
                break
        return salida
    raise ValueError("no hay tabla con " + columna)


def bajar_wiki(pagina):
    req = urllib.request.Request(
        "https://en.wikipedia.org/wiki/" + pagina, headers={"User-Agent": "Mozilla/5.0 (records-nba)"}
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read().decode("utf-8")


def bajar(pagina):
    req = urllib.request.Request(BASE + pagina + ".html", headers={"User-Agent": "Mozilla/5.0 (records-nba)"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read().decode("utf-8")


def generar():
    datos = {"fuente": "Basketball-Reference y Wikipedia (solo NBA)", "fecha": date.today().isoformat()}
    for clave, grupo, parser in (("carrera", CARRERA, filas_carrera), ("temporada", TEMPORADA, filas_temporada), ("partido", PARTIDO, filas_partido)):
        datos[clave] = {}
        for nombre, (pagina, etiqueta) in grupo.items():
            datos[clave][nombre] = {"etiqueta": etiqueta, "filas": parser(bajar(pagina))}
            time.sleep(4)  # sin apurar al servidor
    for nombre, (pagina, columna, etiqueta) in PARTIDO_WIKI.items():
        datos["partido"][nombre] = {"etiqueta": etiqueta, "filas": filas_partido_wiki(bajar_wiki(pagina), columna)}
        time.sleep(4)
    return datos


if __name__ == "__main__":
    datos = generar()
    SALIDA.write_text(json.dumps(datos, ensure_ascii=False, indent=1), encoding="utf-8")
    print("escrito", SALIDA)
    sys.exit(0)
