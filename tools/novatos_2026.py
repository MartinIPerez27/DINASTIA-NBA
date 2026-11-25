"""Suma a assets/database/draft_2026.json las estadísticas reales de la temporada 2026-27 de los novatos.

Fuente: Basketball-Reference (tabla de novatos de la temporada, solo NBA). Por cada elegido de la clase 2026
agrega `real: {g, pts, reb, ast}` (partidos jugados y promedios por partido) y deja `fecha` en el archivo
`assets/database/novatos_2026_fecha.txt`. En la app pesan según los partidos jugados.

Uso:
    python tools/novatos_2026.py
    python -m unittest tools/test_novatos_2026.py
"""

import json
import re
import unicodedata
import urllib.request
from datetime import date
from html.parser import HTMLParser
from pathlib import Path

URL = "https://www.basketball-reference.com/leagues/NBA_2027_rookies.html"
RAIZ = Path(__file__).resolve().parent.parent / "assets" / "database"
DRAFT = RAIZ / "draft_2026.json"
FECHA = RAIZ / "novatos_2026_fecha.txt"


def normalizar(nombre: str) -> str:
    """Sin tildes, puntos ni mayúsculas ("A.J. Dybantsa" == "AJ Dybantsa")."""
    s = unicodedata.normalize("NFKD", nombre)
    s = "".join(c for c in s if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9 ]", "", s.lower().replace(".", "")).strip()


class _Tabla(HTMLParser):
    """Lee la tabla `rookies`: una fila por jugador con sus celdas `data-stat`."""

    def __init__(self):
        super().__init__()
        self.en_tabla = False
        self.en_fila = False
        self.celda = None
        self.fila = {}
        self.filas = []

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == "table" and a.get("id") == "rookies":
            self.en_tabla = True
        elif self.en_tabla and tag == "tr":
            self.en_fila = True
            self.fila = {}
        elif self.en_tabla and self.en_fila and tag in ("td", "th") and a.get("data-stat"):
            self.celda = a["data-stat"]
            self.fila.setdefault(self.celda, "")

    def handle_endtag(self, tag):
        if tag == "table" and self.en_tabla:
            self.en_tabla = False
        elif tag == "tr" and self.en_fila:
            self.en_fila = False
            if self.fila.get("player"):
                self.filas.append(self.fila)
        elif tag in ("td", "th"):
            self.celda = None

    def handle_data(self, data):
        if self.en_tabla and self.en_fila and self.celda:
            self.fila[self.celda] += data


def parsear(html: str) -> dict:
    """nombre normalizado -> {g, pts, reb, ast} de los novatos con al menos un partido."""
    p = _Tabla()
    p.feed(html)
    salida = {}
    for f in p.filas:
        try:
            g = int(f.get("g", "0") or 0)
            if g <= 0:
                continue
            salida[normalizar(f["player"])] = {
                "g": g,
                "pts": float(f.get("pts_per_g") or 0),
                "reb": float(f.get("trb_per_g") or 0),
                "ast": float(f.get("ast_per_g") or 0),
            }
        except ValueError:
            continue
    return salida


def combinar(draft: list, novatos: dict) -> list:
    """Agrega `real` a cada elegido que ya debutó (el resto queda sin tocar)."""
    for x in draft:
        r = novatos.get(normalizar(x["nombre"]))
        if r:
            x["real"] = r
        else:
            x.pop("real", None)
    return draft


def main():
    req = urllib.request.Request(URL, headers={"User-Agent": "Mozilla/5.0"})
    html = urllib.request.urlopen(req, timeout=60).read().decode("utf-8", "ignore")
    novatos = parsear(html)
    draft = combinar(json.loads(DRAFT.read_text(encoding="utf-8")), novatos)
    DRAFT.write_text(json.dumps(draft, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    FECHA.write_text(date.today().isoformat() + "\n", encoding="utf-8")
    con = sum(1 for x in draft if "real" in x)
    print(f"{con} de {len(draft)} elegidos con estadísticas reales (al {date.today().isoformat()}).")


if __name__ == "__main__":
    main()
