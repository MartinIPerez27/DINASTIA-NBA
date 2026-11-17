"""Genera el ícono de la app: marcador LED con "82-0" en matriz de puntos, sobre fondo oscuro.
Uso: python3 tools/icono.py  (escribe assets/icono y android/app/src/main/res)."""
from PIL import Image, ImageDraw, ImageFilter
import os

FONT = {
    '8': ["01110","10001","10001","01110","10001","10001","01110"],
    '2': ["01110","10001","00001","00110","01000","10000","11111"],
    '-': ["00000","00000","00000","11111","00000","00000","00000"],
    '0': ["01110","10001","10001","10001","10001","10001","01110"],
}
FONDO = (11, 12, 14)
LED = (255, 176, 32)
APAGADO = (44, 36, 22)
N = 1024

def dibujar(con_fondo, escala=1.0):
    img = Image.new("RGBA", (N, N), FONDO + (255,) if con_fondo else (0, 0, 0, 0))
    lineas = ["82", "-0"]
    col, fila = 5, 7
    gap = 1
    cols_total = 2 * col + gap
    filas_total = 2 * fila + 2
    paso = int(N * 0.78 * escala / max(cols_total, filas_total))
    x0 = (N - cols_total * paso) // 2
    y0 = (N - filas_total * paso) // 2
    brillo = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    puntos = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    db, dp = ImageDraw.Draw(brillo), ImageDraw.Draw(puntos)
    r = paso * 0.38
    for li, texto in enumerate(lineas):
      for i, ch in enumerate(texto):
        for f in range(fila):
            for c in range(col):
                cx = x0 + (i * (col + gap) + c) * paso + paso / 2
                cy = y0 + (li * (fila + 2) + f) * paso + paso / 2
                if FONT[ch][f][c] == "1":
                    db.ellipse([cx - r * 1.5, cy - r * 1.5, cx + r * 1.5, cy + r * 1.5], fill=LED + (120,))
                    dp.ellipse([cx - r, cy - r, cx + r, cy + r], fill=LED + (255,))
                elif con_fondo:
                    dp.ellipse([cx - r * 0.6, cy - r * 0.6, cx + r * 0.6, cy + r * 0.6], fill=APAGADO + (255,))
    brillo = brillo.filter(ImageFilter.GaussianBlur(paso * 0.35))
    img = Image.alpha_composite(img, brillo)
    img = Image.alpha_composite(img, puntos)
    return img

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
    '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">#0B0C0E</color>\n</resources>\n')
