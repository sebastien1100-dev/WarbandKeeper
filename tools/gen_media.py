"""Génère les textures de l'addon (Media/*.tga) : cercle anti-aliasé pour les
coins arrondis et icônes monochromes blanches (teintées en jeu via SetVertexColor).

Usage : python3 tools/gen_media.py
"""
import math
import os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "Media")
SS = 8  # sur-échantillonnage pour l'anti-aliasing
W = (255, 255, 255, 255)


def canvas(size):
    s = size * SS
    img = Image.new("RGBA", (s, s), (255, 255, 255, 0))
    return img, ImageDraw.Draw(img), s


def save(img, name, size):
    img = img.resize((size, size), Image.LANCZOS)
    img.save(os.path.join(OUT, name + ".tga"))


def P(v, s):
    """Coordonnée relative (0..1) -> pixels."""
    return v * s


def line(d, s, pts, w):
    pts = [(P(x, s), P(y, s)) for x, y in pts]
    d.line(pts, fill=W, width=int(w * s), joint="curve")
    r = w * s / 2
    for x, y in (pts[0], pts[-1]):
        d.ellipse([x - r, y - r, x + r, y + r], fill=W)


def rrect(d, s, x0, y0, x1, y1, rad, w=None):
    box = [P(x0, s), P(y0, s), P(x1, s), P(y1, s)]
    if w:
        d.rounded_rectangle(box, radius=rad * s, outline=W, width=int(w * s))
    else:
        d.rounded_rectangle(box, radius=rad * s, fill=W)


def circle(d, s, cx, cy, r, w=None):
    box = [P(cx - r, s), P(cy - r, s), P(cx + r, s), P(cy + r, s)]
    if w:
        d.ellipse(box, outline=W, width=int(w * s))
    else:
        d.ellipse(box, fill=W)


SW = 0.085  # épaisseur de trait par défaut


def icon_circle():
    img, d, s = canvas(128)
    d.ellipse([0, 0, s - 1, s - 1], fill=W)
    save(img, "circle", 128)


def icon_logo():
    """Étendard de bataillon : hampe + drapeau à queue d'aronde avec un W en creux."""
    img, d, s = canvas(64)
    line(d, s, [(0.2, 0.06), (0.2, 0.95)], 0.07)
    circle(d, s, 0.2, 0.06, 0.06)
    flag = [(0.26, 0.12), (0.86, 0.12), (0.86, 0.72), (0.56, 0.6), (0.26, 0.72)]
    d.polygon([(P(x, s), P(y, s)) for x, y in flag], fill=W)
    wpts = [(0.36, 0.24), (0.44, 0.48), (0.56, 0.32), (0.68, 0.48), (0.76, 0.24)]
    pts = [(P(x, s), P(y, s)) for x, y in wpts]
    d.line(pts, fill=(0, 0, 0, 0), width=int(0.055 * s), joint="curve")
    r = 0.055 * s / 2
    for x, y in (pts[0], pts[-1]):
        d.ellipse([x - r, y - r, x + r, y + r], fill=(0, 0, 0, 0))
    save(img, "logo", 64)


def icon_home():
    img, d, s = canvas(64)
    line(d, s, [(0.12, 0.48), (0.5, 0.14), (0.88, 0.48)], SW)
    line(d, s, [(0.22, 0.42), (0.22, 0.86), (0.78, 0.86), (0.78, 0.42)], SW)
    rrect(d, s, 0.42, 0.6, 0.58, 0.86, 0.03)
    save(img, "home", 64)


def icon_users():
    img, d, s = canvas(64)
    circle(d, s, 0.38, 0.32, 0.15)
    d.pieslice([P(0.1, s), P(0.52, s), P(0.66, s), P(1.1, s)], 180, 360, fill=W)
    circle(d, s, 0.72, 0.36, 0.12, SW * 0.9)
    d.arc([P(0.56, s), P(0.6, s), P(0.96, s), P(1.0, s)], 200, 340, fill=W, width=int(SW * 0.9 * s))
    save(img, "users", 64)


def icon_bag():
    img, d, s = canvas(64)
    rrect(d, s, 0.16, 0.34, 0.84, 0.9, 0.14, SW)
    d.arc([P(0.32, s), P(0.1, s), P(0.68, s), P(0.5, s)], 180, 360, fill=W, width=int(SW * s))
    line(d, s, [(0.38, 0.55), (0.62, 0.55)], SW)
    save(img, "bag", 64)


def icon_hammer():
    img, d, s = canvas(64)
    line(d, s, [(0.2, 0.86), (0.6, 0.42)], SW * 1.2)
    head = [(0.42, 0.24), (0.62, 0.06), (0.92, 0.36), (0.74, 0.54)]
    d.polygon([(P(x, s), P(y, s)) for x, y in head], fill=W)
    save(img, "hammer", 64)


def icon_chart():
    img, d, s = canvas(64)
    rrect(d, s, 0.16, 0.52, 0.32, 0.84, 0.04)
    rrect(d, s, 0.42, 0.3, 0.58, 0.84, 0.04)
    rrect(d, s, 0.68, 0.14, 0.84, 0.84, 0.04)
    save(img, "chart", 64)


def icon_mail():
    img, d, s = canvas(64)
    rrect(d, s, 0.1, 0.22, 0.9, 0.78, 0.08, SW)
    line(d, s, [(0.16, 0.3), (0.5, 0.56), (0.84, 0.3)], SW)
    save(img, "mail", 64)


def icon_gear():
    img, d, s = canvas(64)
    cx = cy = 0.5
    pts = []
    teeth = 8
    for i in range(teeth * 4):
        a = 2 * math.pi * i / (teeth * 4)
        r = 0.44 if (i % 4) in (1, 2) else 0.33
        pts.append((P(cx + math.cos(a) * r, s), P(cy + math.sin(a) * r, s)))
    d.polygon(pts, fill=W)
    circle(d, s, cx, cy, 0.13)
    # trou central
    r = 0.13
    d.ellipse([P(cx - r, s), P(cy - r, s), P(cx + r, s), P(cy + r, s)], fill=(0, 0, 0, 0))
    save(img, "gear", 64)


def icon_coin():
    img, d, s = canvas(64)
    circle(d, s, 0.5, 0.5, 0.38, SW)
    circle(d, s, 0.5, 0.5, 0.17)
    save(img, "coin", 64)


def icon_clock():
    img, d, s = canvas(64)
    circle(d, s, 0.5, 0.5, 0.38, SW)
    line(d, s, [(0.5, 0.28), (0.5, 0.5), (0.66, 0.6)], SW)
    save(img, "clock", 64)


def icon_close():
    img, d, s = canvas(64)
    line(d, s, [(0.28, 0.28), (0.72, 0.72)], SW)
    line(d, s, [(0.72, 0.28), (0.28, 0.72)], SW)
    save(img, "close", 64)


def icon_search():
    img, d, s = canvas(64)
    circle(d, s, 0.43, 0.43, 0.25, SW)
    line(d, s, [(0.62, 0.62), (0.84, 0.84)], SW)
    save(img, "search", 64)


def icon_trash():
    img, d, s = canvas(64)
    line(d, s, [(0.18, 0.26), (0.82, 0.26)], SW)
    line(d, s, [(0.4, 0.14), (0.6, 0.14)], SW)
    line(d, s, [(0.26, 0.34), (0.3, 0.86), (0.7, 0.86), (0.74, 0.34)], SW)
    save(img, "trash", 64)


def icon_plus():
    img, d, s = canvas(64)
    line(d, s, [(0.5, 0.22), (0.5, 0.78)], SW * 1.1)
    line(d, s, [(0.22, 0.5), (0.78, 0.5)], SW * 1.1)
    save(img, "plus", 64)


def icon_arrow():
    img, d, s = canvas(64)
    line(d, s, [(0.18, 0.5), (0.8, 0.5)], SW)
    line(d, s, [(0.56, 0.26), (0.8, 0.5), (0.56, 0.74)], SW)
    save(img, "arrow", 64)


def icon_refresh():
    img, d, s = canvas(64)
    d.arc([P(0.18, s), P(0.18, s), P(0.82, s), P(0.82, s)], 30, 320, fill=W, width=int(SW * s))
    a = math.radians(320)
    cx, cy = 0.5 + 0.32 * math.cos(a), 0.5 + 0.32 * math.sin(a)
    d.polygon([(P(cx + 0.14, s), P(cy - 0.02, s)), (P(cx - 0.06, s), P(cy - 0.14, s)), (P(cx - 0.02, s), P(cy + 0.12, s))], fill=W)
    save(img, "refresh", 64)


def icon_notes():
    img, d, s = canvas(64)
    rrect(d, s, 0.2, 0.1, 0.8, 0.9, 0.1, SW)
    for y, x1 in ((0.32, 0.66), (0.46, 0.66), (0.6, 0.56), (0.74, 0.48)):
        line(d, s, [(0.34, y), (x1, y)], SW * 0.8)
    save(img, "notes", 64)


def icon_chevron():
    img, d, s = canvas(64)
    line(d, s, [(0.26, 0.38), (0.5, 0.62), (0.74, 0.38)], SW * 1.1)
    save(img, "chevron", 64)


def icon_play():
    img, d, s = canvas(64)
    d.polygon([(P(0.3, s), P(0.18, s)), (P(0.84, s), P(0.5, s)), (P(0.3, s), P(0.82, s))], fill=W)
    save(img, "play", 64)


def icon_pause():
    img, d, s = canvas(64)
    rrect(d, s, 0.24, 0.18, 0.42, 0.82, 0.05)
    rrect(d, s, 0.58, 0.18, 0.76, 0.82, 0.05)
    save(img, "pause", 64)


def icon_stop():
    img, d, s = canvas(64)
    rrect(d, s, 0.22, 0.22, 0.78, 0.78, 0.08)
    save(img, "stop", 64)


def icon_minus():
    img, d, s = canvas(64)
    line(d, s, [(0.22, 0.5), (0.78, 0.5)], SW * 1.1)
    save(img, "minus", 64)


def icon_filter():
    img, d, s = canvas(64)
    d.polygon([(P(0.14, s), P(0.18, s)), (P(0.86, s), P(0.18, s)), (P(0.58, s), P(0.52, s)),
               (P(0.58, s), P(0.84, s)), (P(0.42, s), P(0.74, s)), (P(0.42, s), P(0.52, s))], fill=W)
    save(img, "filter", 64)


def icon_grip():
    img, d, s = canvas(64)
    for k in (0.35, 0.6, 0.85):
        line(d, s, [(0.92, 0.92 - k), (0.92 - k, 0.92)], SW * 0.7)
    save(img, "grip", 64)


def icon_back():
    img, d, s = canvas(64)
    line(d, s, [(0.82, 0.5), (0.2, 0.5)], SW)
    line(d, s, [(0.44, 0.26), (0.2, 0.5), (0.44, 0.74)], SW)
    save(img, "back", 64)


def fx_halo():
    """Halo doux : blanc au centre, s'éteint vers le bord (alpha gaussien)."""
    size = 128
    img = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    px = img.load()
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            r = math.hypot(x - c, y - c) / c
            a = math.exp(-(r * 2.2) ** 2) if r < 1 else 0
            px[x, y] = (255, 255, 255, int(255 * a))
    img.save(os.path.join(OUT, "fxhalo.tga"))


def fx_ring():
    """Anneau lumineux fin aux bords adoucis."""
    size = 128
    img = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    px = img.load()
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            r = math.hypot(x - c, y - c) / c
            a = math.exp(-((r - 0.78) / 0.07) ** 2) if r < 1 else 0
            px[x, y] = (255, 255, 255, int(255 * a))
    img.save(os.path.join(OUT, "fxring.tga"))


def icon_spark():
    """Étincelle (qualité de vie) : grande étoile à quatre branches et une petite."""
    img, d, s = canvas(64)
    def star(cx, cy, r, k):
        pts = []
        for i in range(8):
            a = math.pi / 4 * i - math.pi / 2
            rr = r if i % 2 == 0 else r * k
            pts.append((P(cx + math.cos(a) * rr, s), P(cy + math.sin(a) * rr, s)))
        d.polygon(pts, fill=W)
    star(0.42, 0.56, 0.36, 0.3)
    star(0.76, 0.22, 0.16, 0.32)
    save(img, "spark", 64)


def icon_guide():
    """Flèche de guidage pleine, pointe vers le haut (tournée en jeu avec SetRotation)."""
    img, d, s = canvas(128)
    pts = [(0.5, 0.06), (0.86, 0.84), (0.5, 0.66), (0.14, 0.84)]
    d.polygon([(P(x, s), P(y, s)) for x, y in pts], fill=W)
    save(img, "guide", 128)


def icon_ring():
    """Anneau net (indicateur de distance)."""
    img, d, s = canvas(128)
    circle(d, s, 0.5, 0.5, 0.44, 0.09)
    save(img, "ring", 128)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for fn in [icon_circle, icon_logo, icon_home, icon_users, icon_bag, icon_hammer,
               icon_chart, icon_mail, icon_gear, icon_coin, icon_clock, icon_close,
               icon_search, icon_trash, icon_plus, icon_arrow, icon_refresh, icon_notes, icon_chevron, icon_play, icon_pause, icon_stop, icon_minus, icon_filter, icon_grip, icon_back, icon_spark, icon_guide, icon_ring, fx_halo, fx_ring]:
        fn()
    print("OK")
