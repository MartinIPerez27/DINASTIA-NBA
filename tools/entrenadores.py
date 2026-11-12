"""Fotos de los entrenadores (7.º puesto): las baja de Wikipedia/Wikimedia Commons, les quita el
fondo y las deja en assets/entrenadores/<id>.webp, encuadradas de cabeza y hombros.

Necesita (en una PC o venv aparte): pip install "rembg[cpu]" pillow scipy
Uso: python tools/entrenadores.py
Respeta los límites de Wikimedia (pausas entre pedidos). Los créditos quedan en CREDITOS.md.
"""
import json
import pathlib
import re
import time
import urllib.parse
import urllib.request

import numpy as np
from PIL import Image
from rembg import new_session, remove
from scipy import ndimage

UA = {'User-Agent': 'DinastiaNBA/1.0 (juego personal, sin fines de lucro)'}
PAGINAS = {
    'jackson': 'Phil Jackson', 'auerbach': 'Red Auerbach', 'popovich': 'Gregg Popovich', 'riley': 'Pat Riley',
    'kerr': 'Steve Kerr', 'daly': 'Chuck Daly', 'sloan': 'Jerry Sloan', 'dantoni': "Mike D'Antoni",
    'spoelstra': 'Erik Spoelstra', 'holzman': 'Red Holzman', 'brown': 'Larry Brown (basketball)',
    'tomjanovich': 'Rudy Tomjanovich', 'carlisle': 'Rick Carlisle', 'thibodeau': 'Tom Thibodeau',
    'wilkens': 'Lenny Wilkens', 'karl': 'George Karl', 'rivers': 'Doc Rivers', 'mazzulla': 'Joe Mazzulla',
}
# Recortes previos (fracciones de la foto original) para sacar a otras personas o encuadrar.
RECORTES = {'wilkens': (0, 0, 1, 0.55), 'mazzulla': (0.26, 0, 1, 0.7)}
RAIZ = pathlib.Path(__file__).resolve().parent.parent
CACHE = RAIZ / 'tools' / '.cache' / 'entrenadores'
DESTINO = RAIZ / 'assets' / 'entrenadores'


def bajar(url):
    for intento in range(5):
        try:
            return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=30).read()
        except urllib.error.HTTPError as e:
            if e.code != 429:
                raise
            time.sleep(15 * (intento + 1))
    raise RuntimeError(f'Wikimedia sigue limitando: {url}')


def persona_principal(rgba):
    """Deja solo la silueta más grande (descarta cabezas y brazos de otros)."""
    alfa = np.array(rgba.getchannel('A'))
    etiquetas, n = ndimage.label(alfa > 60)
    if n == 0:
        return rgba
    tamanos = ndimage.sum(np.ones_like(alfa), etiquetas, range(1, n + 1))
    mantener = ndimage.binary_dilation(etiquetas == (np.argmax(tamanos) + 1), iterations=3)
    arr = np.array(rgba)
    arr[..., 3] = np.where(mantener, arr[..., 3], 0)
    return Image.fromarray(arr)


def main():
    CACHE.mkdir(parents=True, exist_ok=True)
    DESTINO.mkdir(parents=True, exist_ok=True)
    sesion = new_session('isnet-general-use')
    creditos = []
    for id_, pagina in PAGINAS.items():
        original = CACHE / f'{id_}.jpg'
        resumen = json.loads(bajar('https://en.wikipedia.org/api/rest_v1/page/summary/' + urllib.parse.quote(pagina.replace(' ', '_'))))
        miniatura = resumen['thumbnail']['source'].split('?')[0]
        archivo = urllib.parse.unquote(miniatura.split('/thumb/')[1].split('/')[2]) if '/thumb/' in miniatura else miniatura.split('/')[-1]
        if not original.exists():
            time.sleep(3)
            original.write_bytes(bajar(re.sub(r'/(\d+)px-', '/500px-', miniatura)))
        imagen = Image.open(original).convert('RGB')
        if id_ in RECORTES:
            x0, y0, x1, y1 = RECORTES[id_]
            imagen = imagen.crop((int(imagen.width * x0), int(imagen.height * y0), int(imagen.width * x1), int(imagen.height * y1)))
        recorte = persona_principal(remove(imagen, session=sesion))
        recorte = recorte.crop(recorte.getchannel('A').point(lambda a: 255 if a > 40 else 0).getbbox())
        ancho, alto = recorte.size
        recorte = recorte.crop((0, 0, ancho, min(alto, int(ancho * 1.2))))  # cabeza y hombros
        if recorte.width > 420:
            recorte = recorte.resize((420, int(recorte.height * 420 / recorte.width)), Image.LANCZOS)
        recorte.save(DESTINO / f'{id_}.webp', quality=86, method=6)
        creditos.append(f'- **{pagina}** (`{id_}.webp`, recortada sin fondo): https://commons.wikimedia.org/wiki/File:{urllib.parse.quote(archivo.replace(" ", "_"))}')
        print(id_, recorte.size)
        time.sleep(3)
    (DESTINO / 'CREDITOS.md').write_text(
        '# Fotos de entrenadores\n\nTomadas de Wikipedia / Wikimedia Commons. Cada foto conserva su licencia y autoría, '
        'que figuran en su página de Commons (enlace abajo).\n\n' + '\n'.join(creditos) + '\n'
    )


if __name__ == '__main__':
    main()
