"""Descarga los 30 escudos del CDN de la NBA a assets/logos/ y los deja listos para flutter_svg.

Los SVG oficiales usan <style> con clases (.st0{fill:#CD1F43}); flutter_svg no siempre los aplica,
así que cada clase se reemplaza por atributos de presentación (fill="#CD1F43").

Uso: python tools/normalizar_escudos.py
"""

import re
import urllib.request
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
DESTINO = RAIZ / "assets" / "logos"


def equipos():
    texto = (RAIZ / "lib" / "data" / "franquicias.dart").read_text(encoding="utf-8")
    return re.findall(r"id: '([A-Z]{3})',\s*nbaTeamId: (\d+)", texto)


def normalizar(svg):
    reglas = {}
    for bloque in re.findall(r"<style[^>]*>(.*?)</style>", svg, re.S):
        for selectores, cuerpo in re.findall(r"([^{}]+)\{([^}]*)\}", bloque):
            props = {k.strip(): v.strip() for k, v in
                     (p.split(":", 1) for p in cuerpo.split(";") if ":" in p)}
            for sel in selectores.split(","):
                reglas.setdefault(sel.strip().lstrip("."), {}).update(props)
    svg = re.sub(r"<style[^>]*>.*?</style>", "", svg, flags=re.S)

    def a_atributos(m):
        props = {}
        for clase in m.group(1).split():
            props.update(reglas.get(clase, {}))
        return " ".join(f'{k}="{v}"' for k, v in props.items())

    return re.sub(r'class="([^"]*)"', a_atributos, svg)


def main():
    DESTINO.mkdir(parents=True, exist_ok=True)
    for abbr, team_id in equipos():
        url = f"https://cdn.nba.com/logos/nba/{team_id}/primary/L/logo.svg"
        with urllib.request.urlopen(url, timeout=30) as r:
            svg = r.read().decode("utf-8")
        (DESTINO / f"{abbr}.svg").write_text(normalizar(svg), encoding="utf-8")
        print(abbr)


if __name__ == "__main__":
    main()
