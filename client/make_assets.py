#!/usr/bin/env python3
"""Logo du client (client/assets/logo.png et logo.ico) : carré rose arrondi et étendard de
l'addon (même dessin que icon_logo de tools/gen_media.py), en grand. Usage : python3 client/make_assets.py"""
import os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets")
ACCENT, DARK = (245, 140, 186, 255), (13, 13, 15, 255)


def logo(size=512):
    s = size * 4  # dessin agrandi puis réduit (bords lisses)
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, s - 1, s - 1], radius=int(s * 0.22), fill=ACCENT)
    m, k = 0.18, 0.64  # étendard dans la marge du carré
    P = lambda x, y: (s * (m + x * k), s * (m + y * k))
    w = int(0.07 * k * s)
    d.line([P(0.2, 0.06), P(0.2, 0.95)], fill=DARK, width=w)
    cx, cy = P(0.2, 0.06)
    r = 0.06 * k * s
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=DARK)
    d.polygon([P(x, y) for x, y in [(0.26, 0.12), (0.86, 0.12), (0.86, 0.72), (0.56, 0.6), (0.26, 0.72)]], fill=DARK)
    pts = [P(x, y) for x, y in [(0.36, 0.24), (0.44, 0.48), (0.56, 0.32), (0.68, 0.48), (0.76, 0.24)]]
    lw = int(0.055 * k * s)
    d.line(pts, fill=ACCENT, width=lw, joint="curve")
    for x, y in (pts[0], pts[-1]):
        d.ellipse([x - lw / 2, y - lw / 2, x + lw / 2, y + lw / 2], fill=ACCENT)
    return img.resize((size, size), Image.LANCZOS)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    big = logo(512)
    big.resize((128, 128), Image.LANCZOS).save(os.path.join(OUT, "logo.png"))
    big.save(os.path.join(OUT, "logo.ico"), sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    print("logo.png, logo.ico ->", OUT)
