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


def fx_beam():
    """Colonne de lumière : douce sur les côtés, pleine au pied, s'éteint vers le haut."""
    w, h = 64, 256
    img = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    px = img.load()
    c = (w - 1) / 2
    for y in range(h):
        v = y / (h - 1)                      # 0 en haut, 1 au pied
        up = v ** 1.4                        # s'éteint vers le haut
        foot = min(1.0, (1 - v) / 0.04)      # pied arrondi
        for x in range(w):
            dx = abs(x - c) / c
            a = math.exp(-(dx * 2.3) ** 2) * up * foot
            px[x, y] = (255, 255, 255, int(255 * min(1, a)))
    img.save(os.path.join(OUT, "fxbeam.tga"))


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


def icon_crown():
    """Couronne (chef de groupe) : trois pointes et un bandeau, posée comme un chapeau."""
    img, d, s = canvas(64)
    d.polygon([(P(0.08, s), P(0.78, s)), (P(0.08, s), P(0.30, s)), (P(0.30, s), P(0.52, s)), (P(0.50, s), P(0.18, s)),
               (P(0.70, s), P(0.52, s)), (P(0.92, s), P(0.30, s)), (P(0.92, s), P(0.78, s))], fill=W)
    for cx, cy in ((0.08, 0.26), (0.50, 0.13), (0.92, 0.26)):
        circle(d, s, cx, cy, 0.07)
    d.rectangle([P(0.08, s), P(0.84, s), P(0.92, s), P(0.94, s)], fill=W)
    save(img, "crown", 64)


def icon_star():
    """Étoile pleine à cinq branches (notes des joueurs)."""
    img, d, s = canvas(64)
    pts = []
    for i in range(10):
        ang = -math.pi / 2 + i * math.pi / 5
        r = 0.46 if i % 2 == 0 else 0.19
        pts.append((P(0.5 + math.cos(ang) * r, s), P(0.53 + math.sin(ang) * r, s)))
    d.polygon(pts, fill=W)
    save(img, "star", 64)


def icon_lfg():
    """LFG : trois silhouettes, celle du milieu au premier plan."""
    img, d, s = canvas(64)
    for cx, cy, r, sh in ((0.24, 0.36, 0.10, 0.20), (0.76, 0.36, 0.10, 0.20)):
        circle(d, s, cx, cy, r)
        d.pieslice([P(cx - sh, s), P(0.50, s), P(cx + sh, s), P(0.92, s)], 180, 360, fill=W)
    # contour évidé autour de la silhouette centrale pour la détacher des deux autres
    circle(d, s, 0.5, 0.32, 0.17)
    d.pieslice([P(0.16, s), P(0.50, s), P(0.84, s), P(1.18, s)], 180, 360, fill=CLEAR)
    d.rectangle([P(0.16, s), P(0.84, s), P(0.84, s), P(1.0, s)], fill=CLEAR)
    circle(d, s, 0.5, 0.32, 0.13)
    d.pieslice([P(0.22, s), P(0.56, s), P(0.78, s), P(1.12, s)], 180, 360, fill=W)
    save(img, "lfg", 64)


def icon_fish():
    """Poisson (pêche) : corps en amande, queue en triangle, œil évidé."""
    img, d, s = canvas(64)
    d.ellipse([P(0.10, s), P(0.28, s), P(0.72, s), P(0.72, s)], fill=W)
    d.polygon([(P(0.62, s), P(0.50, s)), (P(0.92, s), P(0.24, s)), (P(0.92, s), P(0.76, s))], fill=W)
    d.ellipse([P(0.24, s), P(0.40, s), P(0.32, s), P(0.48, s)], fill=(255, 255, 255, 0))
    save(img, "fish", 64)


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
    # anneau en pointillés (sans cible) : 14 tirets
    img, d, s2 = canvas(128)
    r0, r1 = 0.06 * s2, 0.94 * s2
    for i in range(14):
        a = i * 360 / 14
        d.arc([r0, r0, r1, r1], a, a + 15, fill=W, width=int(0.09 * s2))
    save(img, "ring_dash", 128)
    # viseur (centre de l'anneau sans cible)
    img, d, s2 = canvas(64)
    circle(d, s2, 0.5, 0.5, 0.2, 0.09)
    for seg in ([(0.5, 0.08), (0.5, 0.26)], [(0.5, 0.74), (0.5, 0.92)], [(0.08, 0.5), (0.26, 0.5)], [(0.74, 0.5), (0.92, 0.5)]):
        line(d, s2, seg, 0.09)
    save(img, "crosshair", 64)


# Pictogrammes du micro menu, dans le style de l'addon (formes pleines, traits épais).
# Les autres raccourcis reprennent les icônes existantes (logo, mail, home, users, hammer, play, gear, fish).
CLEAR = (255, 255, 255, 0)


def icon_person():
    """Personnage : tête et épaules pleines."""
    img, d, s = canvas(64)
    circle(d, s, 0.5, 0.3, 0.17)
    d.pieslice([P(0.14, s), P(0.54, s), P(0.86, s), P(1.26, s)], 180, 360, fill=W)
    save(img, "person", 64)


def icon_book():
    """Grimoire : livre plein, dos et deux lignes évidés."""
    img, d, s = canvas(64)
    rrect(d, s, 0.16, 0.12, 0.84, 0.88, 0.08)
    d.line([(P(0.31, s), P(0.12, s)), (P(0.31, s), P(0.88, s))], fill=CLEAR, width=int(0.05 * s))
    for y in (0.34, 0.5):
        d.line([(P(0.44, s), P(y, s)), (P(0.72, s), P(y, s))], fill=CLEAR, width=int(0.07 * s))
    save(img, "book", 64)


def icon_tree():
    """Talents : un arbre à trois nœuds pleins."""
    img, d, s = canvas(64)
    line(d, s, [(0.5, 0.88), (0.5, 0.56)], SW * 1.1)
    line(d, s, [(0.5, 0.56), (0.24, 0.26)], SW * 1.1)
    line(d, s, [(0.5, 0.56), (0.76, 0.26)], SW * 1.1)
    circle(d, s, 0.5, 0.56, 0.12)
    circle(d, s, 0.24, 0.24, 0.13)
    circle(d, s, 0.76, 0.24, 0.13)
    circle(d, s, 0.5, 0.88, 0.09)
    save(img, "tree", 64)


def icon_map():
    """Carte : trois volets pleins d'une carte pliée."""
    img, d, s = canvas(64)
    for x0, x1, up in ((0.10, 0.34, False), (0.39, 0.61, True), (0.66, 0.90, False)):
        ya, yb = (0.14, 0.24) if up else (0.24, 0.14)
        d.polygon([(P(x0, s), P(ya, s)), (P(x1, s), P(yb, s)), (P(x1, s), P(yb + 0.62, s)), (P(x0, s), P(ya + 0.62, s))], fill=W)
    save(img, "map", 64)


def icon_bang():
    """Quêtes : le point d'exclamation des quêtes."""
    img, d, s = canvas(64)
    rrect(d, s, 0.40, 0.08, 0.60, 0.64, 0.10)
    circle(d, s, 0.5, 0.82, 0.11)
    save(img, "bang", 64)


def icon_fish():
    """Poisson (pêche) : corps en amande, queue en triangle, œil évidé."""
    img, d, s = canvas(64)
    d.ellipse([P(0.10, s), P(0.28, s), P(0.72, s), P(0.72, s)], fill=W)
    d.polygon([(P(0.62, s), P(0.50, s)), (P(0.92, s), P(0.24, s)), (P(0.92, s), P(0.76, s))], fill=W)
    d.ellipse([P(0.24, s), P(0.40, s), P(0.32, s), P(0.48, s)], fill=(255, 255, 255, 0))
    save(img, "fish", 64)


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
    # anneau en pointillés (sans cible) : 14 tirets
    img, d, s2 = canvas(128)
    r0, r1 = 0.06 * s2, 0.94 * s2
    for i in range(14):
        a = i * 360 / 14
        d.arc([r0, r0, r1, r1], a, a + 15, fill=W, width=int(0.09 * s2))
    save(img, "ring_dash", 128)
    # viseur (centre de l'anneau sans cible)
    img, d, s2 = canvas(64)
    circle(d, s2, 0.5, 0.5, 0.2, 0.09)
    for seg in ([(0.5, 0.08), (0.5, 0.26)], [(0.5, 0.74), (0.5, 0.92)], [(0.08, 0.5), (0.26, 0.5)], [(0.74, 0.5), (0.92, 0.5)]):
        line(d, s2, seg, 0.09)
    save(img, "crosshair", 64)


# Pictogrammes du micro menu (style trait fin, grille 24 comme les maquettes)
MM = 2.0 / 24  # épaisseur du trait


def _g(v):
    return v / 24.0


def _pts(pts):
    return [(_g(x), _g(y)) for x, y in pts]


def _arc(d, s, box, a0, a1):
    d.arc([P(_g(box[0]), s), P(_g(box[1]), s), P(_g(box[2]), s), P(_g(box[3]), s)], a0, a1, fill=W, width=int(MM * s))


def _poly(d, s, pts, closed=True):
    pts = _pts(pts)
    if closed:
        pts = pts + [pts[0]]
    line(d, s, pts, MM)


def mm_icons():
    def make(name, draw):
        img, d, s = canvas(64)
        draw(d, s)
        save(img, "mm_" + name, 64)

    make("wk", lambda d, s: (line(d, s, _pts([(6, 21), (6, 3)]), MM), _poly(d, s, [(6, 4), (18, 4), (15, 8), (18, 12), (6, 12)]),
                              line(d, s, _pts([(9, 6.5), (10.2, 9.5), (11.5, 7.3), (12.8, 9.5), (14, 6.5)]), MM * 0.8)))
    make("mail", lambda d, s: (rrect(d, s, _g(3), _g(5), _g(21), _g(19), _g(2), MM), line(d, s, _pts([(3.5, 6.5), (12, 13), (20.5, 6.5)]), MM)))
    make("hearth", lambda d, s: (_arc(d, s, (6, 3, 18, 17), 180, 360), line(d, s, _pts([(6, 10), (6, 19), (18, 19), (18, 10)]), MM),
                                  line(d, s, _pts([(12, 8), (12, 12), (14.5, 14.5)]), MM)))
    make("char", lambda d, s: (circle(d, s, _g(12), _g(8), _g(4), MM), _arc(d, s, (4, 14, 20, 28), 180, 360)))
    make("book", lambda d, s: (rrect(d, s, _g(4), _g(3), _g(19), _g(21), _g(2), MM), line(d, s, _pts([(7.5, 3.5), (7.5, 20.5)]), MM),
                                _poly(d, s, [(13, 7.5), (14, 10), (16.5, 10.2), (14.6, 11.9), (15.2, 14.4), (13, 13), (10.8, 14.4), (11.4, 11.9), (9.5, 10.2), (12, 10)])))
    make("talents", lambda d, s: (line(d, s, _pts([(12, 20), (12, 13)]), MM), line(d, s, _pts([(10.6, 9.6), (8.4, 7.4)]), MM),
                                   line(d, s, _pts([(13.4, 9.6), (15.6, 7.4)]), MM), circle(d, s, _g(12), _g(11), _g(2), MM),
                                   circle(d, s, _g(7), _g(6), _g(2), MM), circle(d, s, _g(17), _g(6), _g(2), MM), circle(d, s, _g(12), _g(21), _g(1.4))))
    make("map", lambda d, s: (_poly(d, s, [(3, 6), (9, 4), (15, 6), (21, 4), (21, 18), (15, 20), (9, 18), (3, 20)]),
                               line(d, s, _pts([(9, 4), (9, 18)]), MM), line(d, s, _pts([(15, 6), (15, 20)]), MM)))
    make("quest", lambda d, s: (rrect(d, s, _g(5), _g(3), _g(19), _g(21), _g(2), MM), line(d, s, _pts([(12, 7), (12, 13)]), MM),
                                 circle(d, s, _g(12), _g(16.6), _g(1.2))))
    make("social", lambda d, s: (circle(d, s, _g(9), _g(8), _g(3.2), MM), circle(d, s, _g(17), _g(9), _g(2.6), MM),
                                  _arc(d, s, (3, 14.4, 15, 25.6), 180, 360), _arc(d, s, (11, 14.6, 22, 25.6), 270, 360)))
    make("prof", lambda d, s: (_poly(d, s, [(14, 4), (20, 10), (17, 13), (11, 7)]), line(d, s, _pts([(11, 7), (3, 15), (6, 18), (14, 10)]), MM)))
    make("farm", lambda d, s: (circle(d, s, _g(12), _g(12), _g(9), MM),
                                d.polygon([(P(_g(10), s), P(_g(8), s)), (P(_g(16), s), P(_g(12), s)), (P(_g(10), s), P(_g(16), s))], fill=W)))
    make("menu", lambda d, s: (circle(d, s, _g(12), _g(12), _g(3), MM),
                                [line(d, s, _pts(seg), MM) for seg in ([(12, 2.5), (12, 5)], [(12, 19), (12, 21.5)], [(2.5, 12), (5, 12)], [(19, 12), (21.5, 12)],
                                                                       [(5.3, 5.3), (7, 7)], [(17, 17), (18.7, 18.7)], [(5.3, 18.7), (7, 17)], [(17, 7), (18.7, 5.3)])]))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for fn in [icon_circle, icon_logo, icon_home, icon_users, icon_bag, icon_hammer,
               icon_chart, icon_mail, icon_gear, icon_coin, icon_clock, icon_close,
               icon_search, icon_trash, icon_plus, icon_arrow, icon_refresh, icon_notes, icon_chevron, icon_play, icon_pause, icon_stop, icon_minus, icon_filter, icon_grip, icon_back, icon_spark, icon_guide, icon_ring, icon_person, icon_book, icon_tree, icon_map, icon_bang, icon_lfg, icon_star, icon_crown, icon_fish, fx_halo, fx_beam, fx_ring]:
        fn()
    print("OK")
