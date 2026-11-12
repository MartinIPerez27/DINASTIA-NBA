"""Resuelve las fuentes de foto de cada jugador del catálogo y las guarda en tools/.cache/fotos.json.

Orden de fuentes (la app prueba una tras otra y, si ninguna carga, muestra las iniciales):
  "n"        CDN oficial de la NBA (solo si la foto es real: la silueta genérica pesa 12430 bytes)
  "b"        Basketball-Reference (headshot por id de jugador)
  "w"        Wikipedia: la app busca el artículo del jugador desde el celular (los servidores en la
             nube reciben 429 de Wikipedia) y guarda el resultado para usarlo sin internet.
  "w:<url>"  Wikipedia ya resuelto (si se corre este script con --wikipedia desde una PC personal).

Es reanudable: lo ya resuelto queda en la caché.
Uso: python tools/fotos.py   (después: python tools/catalogo_bbref.py)
"""

import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor

import extraer_cartas as ec

CACHE = ec.CACHE / "fotos.json"
NBA = "https://cdn.nba.com/headshots/nba/latest/1040x760/{}.png"
WIKI = "https://en.wikipedia.org/api/rest_v1/page/summary/{}"
TAMANO_SILUETA = 12430
AGENTE = "DinastiaNBA/0.1 (proyecto personal sin fines de lucro)"


def foto_nba_real(nba_id):
    pedido = urllib.request.Request(NBA.format(nba_id), method="HEAD", headers={"User-Agent": AGENTE})
    try:
        with urllib.request.urlopen(pedido, timeout=20) as r:
            return int(r.headers.get("Content-Length", 0)) not in (0, TAMANO_SILUETA)
    except urllib.error.URLError:
        return False


def resumen_wiki(titulo):
    """Resumen de Wikipedia con reintentos ante el límite de ritmo (429 o respuesta vacía)."""
    url = WIKI.format(urllib.parse.quote(titulo.replace(" ", "_")))
    for intento in range(5):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": AGENTE}), timeout=20) as r:
                return json.loads(r.read() or b"{}")
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return {}
            time.sleep(3 * 2**intento)
        except (urllib.error.URLError, json.JSONDecodeError, TimeoutError):
            time.sleep(3 * 2**intento)
    return None  # no se pudo: se reintenta en la próxima corrida


def foto_wiki(nombre):
    for titulo in (f"{nombre} (basketball)", nombre):
        datos = resumen_wiki(titulo)
        if datos is None:
            return None
        es_jugador = "basketball" in (datos.get("description") or "").lower()
        imagen = (datos.get("thumbnail") or {}).get("source")
        if datos.get("type") == "standard" and es_jugador and imagen:
            return "w:" + imagen.split("?")[0]
        time.sleep(0.8)
    return ""


def main():
    cartas = json.loads(ec.SALIDA.read_text(encoding="utf-8"))
    jugadores = {}
    for c in cartas:
        jugadores[c["id"].split("-")[0]] = (c["nombre"], c["nbaPlayerId"])
    cache = json.loads(CACHE.read_text(encoding="utf-8")) if CACHE.exists() else {}
    print(f"{len(jugadores)} jugadores, {len(cache)} ya resueltos")

    pendientes = [pid for pid in jugadores if pid not in cache]
    con_nba = [pid for pid in pendientes if jugadores[pid][1] > 0]
    with ThreadPoolExecutor(16) as pool:
        reales = dict(zip(con_nba, pool.map(lambda pid: foto_nba_real(jugadores[pid][1]), con_nba)))
    for pid, real in reales.items():
        if real:
            cache[pid] = ["n"]
    CACHE.write_text(json.dumps(cache), encoding="utf-8")
    print(f"NBA: {sum(reales.values())} fotos reales de {len(con_nba)} consultadas")

    sin_foto = [pid for pid in pendientes if pid not in cache]
    if "--wikipedia" not in sys.argv:
        for pid in sin_foto:
            cache[pid] = ["b", "w"]
        CACHE.write_text(json.dumps(cache), encoding="utf-8")
        print(f"{len(sin_foto)} sin foto NBA: Basketball-Reference y búsqueda en Wikipedia desde la app")
        return
    for i, pid in enumerate(sin_foto, 1):
        wiki = foto_wiki(jugadores[pid][0])
        if wiki is None:
            continue
        cache[pid] = ["b"] + ([wiki] if wiki else ["w"])
        if i % 25 == 0:
            CACHE.write_text(json.dumps(cache), encoding="utf-8")
            print(f"  Wikipedia {i}/{len(sin_foto)}")
        time.sleep(0.8)
    CACHE.write_text(json.dumps(cache), encoding="utf-8")
    con_wiki = sum(any(f.startswith("w:") for f in v) for v in cache.values())
    print(f"Listo: {len(cache)} jugadores; {sum(v == ['n'] for v in cache.values())} con foto NBA, "
          f"{con_wiki} con foto de Wikipedia como respaldo")


if __name__ == "__main__":
    main()
