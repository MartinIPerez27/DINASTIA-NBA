"""Sonidos del partido en vivo, sintetizados desde cero (sin licencias ni descargas).

Genera WAV mono de 44,1 kHz y los pasa a Ogg Vorbis (Android los reproduce nativo) en
assets/sonidos/. Solo usa numpy y ffmpeg:

    python tools/sonidos.py

Los ruidos se filtran por FFT: el filtrado es circular, así que el ambiente del público
sale como un bucle perfecto (el final empalma con el principio sin clic).
"""

from __future__ import annotations

import pathlib
import subprocess
import tempfile
import wave

import numpy as np

SR = 44100
SALIDA = pathlib.Path(__file__).resolve().parent.parent / "assets" / "sonidos"
rng = np.random.default_rng(82)


def t_de(segundos: float) -> np.ndarray:
    return np.arange(int(SR * segundos)) / SR


def banda(senal: np.ndarray, bajo: float, alto: float, suave: float = 0.15) -> np.ndarray:
    """Pasa-banda por FFT con flancos suaves (coseno) para no generar ringing."""
    espectro = np.fft.rfft(senal)
    f = np.fft.rfftfreq(len(senal), 1 / SR)
    mascara = np.ones_like(f)
    if bajo > 0:
        ancho = bajo * suave
        mascara *= np.clip((f - (bajo - ancho)) / (2 * ancho), 0, 1)
    if alto < SR / 2:
        ancho = alto * suave
        mascara *= np.clip(((alto + ancho) - f) / (2 * ancho), 0, 1)
    mascara = 0.5 - 0.5 * np.cos(np.pi * mascara)
    return np.fft.irfft(espectro * mascara, n=len(senal))


def ruido(segundos: float, bajo: float, alto: float) -> np.ndarray:
    n = rng.standard_normal(int(SR * segundos))
    r = banda(n, bajo, alto)
    return r / (np.max(np.abs(r)) + 1e-12)


def fundido(x: np.ndarray, entrada: float = 0.003, salida: float = 0.01) -> np.ndarray:
    x = x.copy()
    a, b = int(SR * entrada), int(SR * salida)
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def normalizar(x: np.ndarray, dbfs: float) -> np.ndarray:
    return x / (np.max(np.abs(x)) + 1e-12) * 10 ** (dbfs / 20)


def lfo_periodico(segundos: float, ciclos_max: int, fuerza: float) -> np.ndarray:
    """Curva lenta y aleatoria que se repite exacto en `segundos` (para el bucle)."""
    t = t_de(segundos)
    curva = np.zeros_like(t)
    for k in range(1, ciclos_max + 1):
        curva += rng.uniform(0.3, 1) / k * np.sin(2 * np.pi * k * t / segundos + rng.uniform(0, 2 * np.pi))
    curva /= np.max(np.abs(curva))
    return 1 + fuerza * curva


# ------------------------------------------------------------------ sonidos


def pique() -> np.ndarray:
    t = t_de(0.16)
    # Golpe grave con caída de tono (la pelota contra el parqué) + clic del cuero.
    frec = 85 + 60 * np.exp(-t / 0.02)
    fase = 2 * np.pi * np.cumsum(frec) / SR
    golpe = np.sin(fase) * np.exp(-t / 0.035)
    toque = np.sin(2 * np.pi * 620 * t) * np.exp(-t / 0.008) * 0.35
    clic = ruido(0.16, 1500, 6000) * np.exp(-t / 0.004) * 0.5
    return normalizar(fundido(golpe + toque + clic, 0.001, 0.02), -3)


def red() -> np.ndarray:
    t = t_de(0.38)
    env = (1 - np.exp(-t / 0.03)) * np.exp(-t / 0.09)
    sh = ruido(0.38, 2500, 9000) * env
    cuerpo = ruido(0.38, 700, 2200) * env * 0.35
    return normalizar(fundido(sh + cuerpo, 0.005, 0.04), -4)


def aro() -> np.ndarray:
    t = t_de(0.45)
    parciales = [(520, 0.13, 1.0), (1135, 0.09, 0.7), (1478, 0.07, 0.5), (1893, 0.05, 0.4), (2610, 0.03, 0.25)]
    metal = sum(a * np.sin(2 * np.pi * f * t + rng.uniform(0, 6)) * np.exp(-t / d) for f, d, a in parciales)
    golpe = np.sin(2 * np.pi * 170 * t) * np.exp(-t / 0.02) * 0.6
    clic = ruido(0.45, 2000, 8000) * np.exp(-t / 0.003) * 0.4
    return normalizar(fundido(metal + golpe + clic, 0.001, 0.05), -4)


def chicharra() -> np.ndarray:
    t = t_de(1.2)

    def sierra(f: float) -> np.ndarray:
        return 2 * ((f * t) % 1) - 1

    def cuadrada(f: float) -> np.ndarray:
        return np.sign(np.sin(2 * np.pi * f * t))

    x = sierra(232) + 0.8 * sierra(235.5) + 0.35 * cuadrada(464)
    x = np.tanh(1.6 * x / 2)  # saturación de parlante de estadio
    x = banda(x, 150, 3800)
    env = np.minimum(1, t / 0.012) * np.minimum(1, (1.2 - t) / 0.06)
    return normalizar(x * env, -4)


def silbato() -> np.ndarray:
    t = t_de(0.55)
    # El "trino" de la bolita: modulación rápida de tono y volumen.
    trino = np.sin(2 * np.pi * 31 * t)
    frec = 3000 + 110 * trino + 40 * np.sin(2 * np.pi * 5 * t)
    fase = 2 * np.pi * np.cumsum(frec) / SR
    tono = np.sin(fase) * (0.65 + 0.35 * trino) + 0.12 * np.sin(2 * fase)
    soplido = ruido(0.55, 2200, 5000) * 0.18
    env = np.minimum(1, t / 0.015) * np.minimum(1, (0.55 - t) / 0.05)
    return normalizar((tono + soplido) * env, -6)


def publico() -> np.ndarray:
    seg = 6.0
    murmullo = ruido(seg, 180, 900) * lfo_periodico(seg, 6, 0.25)
    charla = ruido(seg, 900, 2800) * lfo_periodico(seg, 9, 0.35) * 0.55
    brillo = ruido(seg, 2800, 6000) * lfo_periodico(seg, 4, 0.4) * 0.12
    x = murmullo + charla + brillo
    # Sin fundidos: el filtrado circular ya empalma el final con el principio.
    return normalizar(x, -16)


def ovacion() -> np.ndarray:
    seg = 2.2
    t = t_de(seg)
    env = np.sin(np.pi * np.clip(t / seg, 0, 1)) ** 1.5
    env *= np.minimum(1, t / 0.35)
    gente = ruido(seg, 250, 1400) + 0.7 * ruido(seg, 1400, 3500) + 0.2 * ruido(seg, 3500, 7000)
    # Voces: formantes que tiemblan un poco (gritos sueltos dentro de la ola).
    voces = sum(
        ruido(seg, f * 0.85, f * 1.15) * (0.6 + 0.4 * np.sin(2 * np.pi * rng.uniform(3, 7) * t + rng.uniform(0, 6)))
        for f in (520, 780, 1150, 1600)
    )
    return normalizar(fundido((gente + 0.5 * voces) * env, 0.01, 0.1), -5)


SONIDOS = {
    "pique": pique,
    "red": red,
    "aro": aro,
    "chicharra": chicharra,
    "silbato": silbato,
    "publico": publico,
    "ovacion": ovacion,
}


def escribir_wav(ruta: pathlib.Path, x: np.ndarray) -> None:
    datos = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(str(ruta), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(datos.tobytes())


def main() -> None:
    SALIDA.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for nombre, generar in SONIDOS.items():
            x = generar()
            assert np.max(np.abs(x)) <= 1.0, nombre
            wav = pathlib.Path(tmp) / f"{nombre}.wav"
            escribir_wav(wav, x)
            ogg = SALIDA / f"{nombre}.ogg"
            subprocess.run(
                ["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "3", str(ogg)],
                check=True,
            )
            print(f"{ogg.name}: {len(x) / SR:.2f} s, pico {20 * np.log10(np.max(np.abs(x))):.1f} dBFS, "
                  f"{ogg.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
