"""Genera el ícono de la app: pelota de básquet en llamas sobre fondo azul, con destellos.
Uso: python3 tools/icono.py  (escribe assets/icono y android/app/src/main/res)."""
from PIL import Image, ImageDraw, ImageFilter
import math
import os

AZUL = (38, 54, 170)
NARANJA = (240, 120, 50)
NARANJA_OSC = (205, 85, 30)
LINEA = (120, 45, 15)
FUEGO = [(255, 190, 40), (255, 215, 90), (255, 238, 170)]
DESTELLO = (70, 150, 230)
N = 1024
SS = 2  # supersampling


def estrella(d, cx, cy, r, color, puntas=4, interior=0.28):
    pts = []
    for i in range(puntas * 2):
        ang = math.pi / puntas * i - math.pi / 2
        rr = r if i % 2 == 0 else r * interior
        pts.append((cx + rr * math.cos(ang), cy + rr * math.sin(ang)))
    d.polygon(pts, fill=color)


def dibujar(con_fondo, escala=1.0):
    n = N * SS
    img = Image.new("RGBA", (n, n), AZUL + (255,) if con_fondo else (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = n / 2
    R = n * 0.27 * escala  # radio de la pelota
    bx, by = c + n * 0.06 * escala, c + n * 0.03 * escala
    # Estela de fuego: cometa con cola curva hacia abajo a la izquierda (tres capas, de amarillo a claro).
    dirx, diry = -0.82, 0.57
    perp = (-diry, dirx)
    for k, col in enumerate(FUEGO):
        f = 1.0 - k * 0.22
        ancho = R * 1.12 * f
        largo = R * 2.6 * f
        pts = []
        for i in range(0, 41):  # lado superior de la cola
            t = i / 40
            w = ancho * (1 - t) ** 0.8
            curva = math.sin(t * math.pi) * R * 0.25
            pts.append((bx + dirx * largo * t + perp[0] * (w + curva), by + diry * largo * t + perp[1] * (w + curva)))
        for i in range(40, -1, -1):  # lado inferior
            t = i / 40
            w = ancho * (1 - t) ** 0.8
            curva = math.sin(t * math.pi) * R * 0.25
            pts.append((bx + dirx * largo * t - perp[0] * (w - curva), by + diry * largo * t - perp[1] * (w - curva)))
        d.polygon(pts, fill=col + (255,))
        d.ellipse([bx - R * 1.1 * f, by - R * 1.1 * f, bx + R * 1.1 * f, by + R * 1.1 * f], fill=col + (255,))
    # Pelota.
    d.ellipse([bx - R, by - R, bx + R, by + R], fill=NARANJA + (255,))
    capa = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    dc = ImageDraw.Draw(capa)
    w = int(R * 0.07)
    dc.line([bx - R, by, bx + R, by], fill=LINEA + (255,), width=w)
    dc.line([bx, by - R, bx, by + R], fill=LINEA + (255,), width=w)
    for sgn in (-1, 1):
        cx = bx + sgn * R * 1.25
        dc.ellipse([cx - R * 0.8, by - R * 1.15, cx + R * 0.8, by + R * 1.15], outline=LINEA + (255,), width=w)
    mascara = Image.new("L", (n, n), 0)
    ImageDraw.Draw(mascara).ellipse([bx - R, by - R, bx + R, by + R], fill=255)
    capa.putalpha(Image.composite(capa.getchannel("A"), Image.new("L", (n, n), 0), mascara))
    img = Image.alpha_composite(img, capa)
    luz = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    ImageDraw.Draw(luz).ellipse([bx - R * 0.8, by - R * 0.85, bx - R * 0.1, by - R * 0.2], fill=(255, 190, 130, 80))
    luz = luz.filter(ImageFilter.GaussianBlur(R * 0.12))
    img = Image.alpha_composite(img, luz)
    d = ImageDraw.Draw(img)
    # Destellos.
    estrella(d, bx + R * 0.0, by + R * 0.25, R * 0.22, (255, 255, 255, 255))
    for (dx, dy, r) in [(-0.9, -1.55, 0.14), (-1.6, -0.5, 0.1), (-1.35, -1.05, 0.08), (1.4, -1.45, 0.1), (1.8, 0.35, 0.09), (0.7, 1.8, 0.08), (-0.4, 1.9, 0.09)]:
        estrella(d, bx + R * dx * 1.35, by + R * dy * 1.05, R * r * 1.3, DESTELLO + (255,))
    estrella(d, bx - R * 1.4, by - R * 0.6, R * 0.09, (255, 255, 255, 255))
    return img.resize((N, N), Image.LANCZOS)


completo = dibujar(True)
frente = dibujar(False, 0.78)  # zona segura del ícono adaptativo (se recorta ~1/3 del borde)
os.makedirs("assets/icono", exist_ok=True)
completo.convert("RGB").save("assets/icono/icono.png")
frente.save("assets/icono/icono_frente.png")

res = "android/app/src/main/res"
tam = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
tam_ad = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
for d, s in tam.items():
    # ícono clásico: cuadrado con esquinas redondeadas
    base = completo.resize((s, s), Image.LANCZOS).convert("RGBA")
    m = Image.new("L", (s, s), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, s - 1, s - 1], radius=int(s * 0.22), fill=255)
    base.putalpha(m)
    base.save(f"{res}/mipmap-{d}/ic_launcher.png")
    frente.resize((tam_ad[d], tam_ad[d]), Image.LANCZOS).save(f"{res}/mipmap-{d}/ic_launcher_foreground.png")
os.makedirs(f"{res}/mipmap-anydpi-v26", exist_ok=True)
open(f"{res}/mipmap-anydpi-v26/ic_launcher.xml", "w").write(
    '<?xml version="1.0" encoding="utf-8"?>\n<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
    '    <background android:drawable="@color/ic_launcher_background"/>\n'
    '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n</adaptive-icon>\n')
open(f"{res}/values/ic_launcher_background.xml", "w").write(
    '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">#2636AA</color>\n</resources>\n')
