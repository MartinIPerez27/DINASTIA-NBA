#!/usr/bin/env python3
"""Cobertura de fotos por época.

Uso:
  python3 tools/cobertura_fotos.py [catalogo.json] [resultados.json]

`resultados.json` es {id_bbref: "ok" | "sin" | {"estado": "ok", "fuente": "wikipedia"}} (lo que resuelve
GestorFotos en el teléfono, o `tools/cobertura_fotos.py --muestra N` contra Wikipedia con pausas de 3 s).
Sin resultados, se asume solo lo que garantiza el catálogo (fotos 'n' = CDN NBA) y se informa la
cobertura mínima segura. Una persona = id de Basketball-Reference (prefijo del id de carta).
Con --muestra N: resuelve N personas sin CDN contra Wikipedia (REST summary, 1 pedido cada 3 s)
y reporta la tasa de acierto de esa muestra.
"""
import json
import sys
import time
import urllib.parse
import urllib.request
from collections import defaultdict

UA = "DinastiaNBA/1.0 (+https://github.com/MartinIPerez27/dinatia-nba)"
ORDEN = ["anios40", "anios50", "anios60", "anios70", "anios80", "anios90", "anios2000", "anios2010", "actualidad"]


def personas(catalogo):
    por = {}
    for c in catalogo:
        if not c.get("fotos"):
            continue
        k = c["id"].split("-")[0]
        p = por.setdefault(k, {"nombre": c["nombre"], "nba": False, "epocas": set()})
        p["nba"] |= "n" in c["fotos"] and c.get("nbaPlayerId", 0) > 0
        p["epocas"].add(c["epoca"])
    return por


def estado_de(res, k, p):
    r = res.get(k)
    if isinstance(r, dict):
        r = r.get("estado")
    if r is None:
        return "ok" if p["nba"] else "desconocido"
    return r


def muestra(por, n):
    res, cand = {}, [k for k, p in sorted(por.items()) if not p["nba"]]
    paso = max(1, len(cand) // n)
    for k in cand[::paso][:n]:
        nombre = por[k]["nombre"]
        ok = False
        err = False
        for t in (f"{nombre} (basketball)", nombre):
            url = "https://en.wikipedia.org/api/rest_v1/page/summary/" + urllib.parse.quote(t.replace(" ", "_"))
            try:
                d = json.load(urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": UA}), timeout=20))
                if d.get("type") == "standard" and "basketball" in d.get("description", "").lower() and d.get("thumbnail"):
                    ok = True
                    break
            except Exception as e:  # 404 = no existe; 429/red = no concluyente
                err |= '404' not in str(e)
                print(f"  {t}: {e}", file=sys.stderr)
            time.sleep(3)
        res[k] = "ok" if ok else ("desconocido" if err else "sin")
        time.sleep(3)
    return res


def main():
    argv = sys.argv[1:]
    n_muestra = None
    if "--muestra" in argv:
        i = argv.index("--muestra")
        n_muestra = int(argv[i + 1])
        del argv[i:i + 2]
    args = argv
    cat = json.load(open(args[0] if args else "assets/database/nba_players.json"))
    por = personas(cat)
    res = json.load(open(args[1])) if len(args) > 1 else {}
    if n_muestra:
        res = muestra(por, n_muestra)
        ok = sum(v == "ok" for v in res.values())
        dud = sum(v == "desconocido" for v in res.values())
        print(f"Muestra Wikipedia (solo summary): {ok} ok, {dud} no concluyentes (429/red) de {len(res)}")
        por = {k: p for k, p in por.items() if k in res}
    tot = defaultdict(lambda: defaultdict(int))
    for k, p in por.items():
        e = estado_de(res, k, p)
        for ep in p["epocas"]:
            tot[ep][e] += 1
            tot[ep]["total"] += 1
    print(f"{'época':<10}{'personas':>9}{'ok':>7}{'sin':>7}{'?':>7}{'% ok':>8}{'% seguro':>10}")
    gt = defaultdict(int)
    for ep in ORDEN:
        t = tot[ep]
        if not t["total"]:
            continue
        print(f"{ep:<10}{t['total']:>9}{t['ok']:>7}{t['sin']:>7}{t['desconocido']:>7}"
              f"{100 * t['ok'] / t['total']:>7.0f}%{100 * t['ok'] / t['total']:>9.0f}%")
        for k in ("total", "ok", "sin", "desconocido"):
            gt[k] += t[k]
    print(f"{'(cuenta por época: una persona con cartas en varias épocas suma en cada una)'}")
    print(f"Personas únicas: {len(por)}; sin foto: {sum(estado_de(res, k, p) == 'sin' for k, p in por.items())}")


if __name__ == "__main__":
    main()
