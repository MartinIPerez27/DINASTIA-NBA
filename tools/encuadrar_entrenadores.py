"""Encuadre parejo de las fotos de entrenadores (recortes sin fondo, ver entrenadores.py).

En la tarjeta del draft se ven en un cuadrado, así que las fotos de cuerpo entero se acercan a
cabeza y hombros, y los primerísimos planos se alejan un poco (con el pecho desvanecido abajo).
Los cuadros se eligieron a ojo sobre cada foto: (x, y, lado) en píxeles de la foto original; lo
que cae fuera de la foto queda transparente.

Uso: python3 tools/encuadrar_entrenadores.py ORIGENES_DIR DESTINO_DIR
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

LADO = 400

# Planos lejanos: se acercan.
CUADROS = {
    'dantoni': (-10, -35, 300),
    'popovich': (5, -30, 330),
    'riley': (60, -30, 330),
    'rivers': (25, -25, 250),
}
# Primerísimos planos: el contenido ocupa 1/factor del cuadro, centrado y con aire arriba.
ALEJAR = {'daly': 1.3, 'tomjanovich': 1.3, 'thibodeau': 1.35, 'holzman': 1.3}
# Zonas a borrar (otra persona detrás): (x0, y0, x1, y1).
BORRAR = {'rivers': [(229, 0, 420, 128)]}
# Alrededor de la cabeza: se borra todo lo que quede fuera de la elipse (cx, cy, rx, ry) por encima
# de la fila y_max y a la derecha de x_min (asoma otra persona detrás).
ELIPSE = {'rivers': (178, 88, 50, 68, 128, 120)}


def cuadro(rgba, x0, y0, lado):
    lienzo = Image.new('RGBA', (lado, lado), (0, 0, 0, 0))
    fuente = rgba.crop((max(0, x0), max(0, y0), min(rgba.width, x0 + lado), min(rgba.height, y0 + lado)))
    lienzo.alpha_composite(fuente, dest=(max(0, -x0), max(0, -y0)))
    fin = rgba.height - y0  # fila del cuadro donde se termina la foto
    if fin < lado:
        alfa = np.array(lienzo.getchannel('A'), dtype=np.float32)
        largo = max(8, int(lado * 0.14))
        for fila in range(max(0, fin - largo), fin):
            alfa[fila, :] *= (fin - fila) / largo
        lienzo.putalpha(Image.fromarray(alfa.clip(0, 255).astype(np.uint8)))
    return lienzo.resize((LADO, LADO), Image.LANCZOS)


def main():
    origen, destino = Path(sys.argv[1]), Path(sys.argv[2])
    for id_ in sorted({*CUADROS, *ALEJAR}):
        rgba = Image.open(origen / f'{id_}.webp').convert('RGBA')
        for x0, y0, x1, y1 in BORRAR.get(id_, []):
            alfa = rgba.getchannel('A')
            alfa.paste(0, (x0, y0, x1, y1))
            rgba.putalpha(alfa)
        if id_ in ELIPSE:
            cx, cy, rx, ry, y_max, x_min = ELIPSE[id_]
            alfa = np.array(rgba.getchannel('A'))
            ys, xs = np.mgrid[0 : rgba.height, 0 : rgba.width]
            fuera = ((xs - cx) / rx) ** 2 + ((ys - cy) / ry) ** 2 > 1
            alfa[fuera & (ys < y_max) & (xs > x_min)] = 0
            rgba.putalpha(Image.fromarray(alfa))
        if id_ in CUADROS:
            salida = cuadro(rgba, *CUADROS[id_])
        else:
            lado = round(rgba.width * ALEJAR[id_])
            salida = cuadro(rgba, -(lado - rgba.width) // 2, -round(lado * 0.08), lado)
        salida.save(destino / f'{id_}.webp', quality=88, method=6)
        print(id_, 'ok')


if __name__ == '__main__':
    main()
