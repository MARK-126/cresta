"""Genera el ícono de Cresta: montaña cian sobre pizarra con resplandor (estilo del splash).

Escribe los PNG de Android (mipmap-*) y de iOS (AppIcon.appiconset). El ícono adaptativo
de Android 8+ está en XML (res/mipmap-anydpi-v26 y res/drawable/ic_launcher_*.xml) y usa
la misma figura.

Uso, desde la raíz del proyecto:  python3 tool/make_icon.py
"""

import json
import os

from PIL import Image, ImageDraw, ImageFilter

SLATE = (14, 20, 22)  # Andes.surface
GLOW = (11, 110, 121)  # cian profundo del resplandor
CYAN = (70, 234, 229)  # Andes.cyan

# Montaña de Material Icons ("landscape") en su cuadrícula de 24 × 24.
MOUNTAIN = [(14, 6), (10.25, 11), (13.1, 14.8), (11.5, 16), (7, 10), (1, 18), (23, 18)]

SS = 4  # sobremuestreo para bordes suaves


def render(size, rounded):
    """Ícono cuadrado de `size` px; con `rounded` recorta las esquinas (Android antiguo)."""
    big = size * SS
    img = Image.new("RGB", (big, big), SLATE)

    # Resplandor: círculo cian difuminado, arriba del centro, como en el splash
    glow = Image.new("RGB", (big, big), SLATE)
    r = int(big * 0.42)
    cx, cy = big // 2, int(big * 0.36)
    ImageDraw.Draw(glow).ellipse((cx - r, cy - r, cx + r, cy + r), fill=GLOW)
    glow = glow.filter(ImageFilter.GaussianBlur(big * 0.18))
    img = Image.blend(img, glow, 0.9)

    # Montaña al 56 % del ancho, centrada (su base queda un poco abajo del centro)
    scale = big * 0.56 / 22
    ox = big / 2 - 12 * scale
    oy = big / 2 - 12.5 * scale
    pts = [(ox + x * scale, oy + y * scale) for x, y in MOUNTAIN]
    ImageDraw.Draw(img).polygon(pts, fill=CYAN)

    img = img.resize((size, size), Image.LANCZOS)
    if not rounded:
        return img
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, big - 1, big - 1), radius=big * 0.22, fill=255)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask.resize((size, size), Image.LANCZOS))
    return out


def main():
    android = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for density, px in android.items():
        path = f"android/app/src/main/res/mipmap-{density}/ic_launcher.png"
        render(px, rounded=True).save(path)
        print(path)

    # iOS no admite transparencia en el ícono: cuadrado completo, el sistema redondea
    folder = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    with open(os.path.join(folder, "Contents.json")) as f:
        images = json.load(f)["images"]
    for im in images:
        base = float(im["size"].split("x")[0])
        px = round(base * int(im["scale"].rstrip("x")))
        path = os.path.join(folder, im["filename"])
        render(px, rounded=False).save(path)
        print(path)


if __name__ == "__main__":
    main()
