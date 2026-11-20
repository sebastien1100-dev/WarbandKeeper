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


def icon_pin():
    """Épingle du repère de navigation (goutte pointe en bas), teintée en jeu."""
    img, d, s = canvas(128)
    circle(d, s, 0.5, 0.38, 0.36)
    d.polygon([(P(0.5 - 0.27, s), P(0.62, s)), (P(0.5 + 0.27, s), P(0.62, s)), (P(0.5, s), P(0.98, s))], fill=W)
    save(img, "pin", 128)


def icon_skull():
    """Tête de mort (rare guidé), blanche ; yeux et nez évidés."""
    img, d, s = canvas(64)
    circle(d, s, 0.5, 0.42, 0.34)
    rrect(d, s, 0.3, 0.56, 0.7, 0.86, 0.06)
    clear = (255, 255, 255, 0)
    for cx in (0.36, 0.64):
        r = 0.095
        d.ellipse([P(cx - r, s), P(0.46 - r, s), P(cx + r, s), P(0.46 + r, s)], fill=clear)
    d.polygon([(P(0.5, s), P(0.56, s)), (P(0.45, s), P(0.66, s)), (P(0.55, s), P(0.66, s))], fill=clear)
    for x in (0.41, 0.5, 0.59):
        d.rectangle([P(x - 0.018, s), P(0.74, s), P(x + 0.018, s), P(0.86, s)], fill=clear)
    save(img, "skull", 64)


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


def icon_power():
    # recharger l'interface : symbole marche/arrêt (cercle ouvert en haut, trait vertical)
    img, d, s = canvas(64)
    d.arc([P(0.2, s), P(0.22, s), P(0.8, s), P(0.82, s)], -55, 235, fill=W, width=int(SW * s))
    line(d, s, [(0.5, 0.12), (0.5, 0.5)], SW)
    save(img, "power", 64)


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


def icon_move():
    """Déplacer : croix à quatre flèches."""
    img, d, s = canvas(64)
    w = SW * 0.95
    line(d, s, [(0.5, 0.16), (0.5, 0.84)], w)
    line(d, s, [(0.16, 0.5), (0.84, 0.5)], w)
    for (tx, ty), (ax, ay), (bx, by) in [((0.5, 0.06), (0.36, 0.22), (0.64, 0.22)), ((0.5, 0.94), (0.36, 0.78), (0.64, 0.78)),
                                          ((0.06, 0.5), (0.22, 0.36), (0.22, 0.64)), ((0.94, 0.5), (0.78, 0.36), (0.78, 0.64))]:
        d.polygon([(P(tx, s), P(ty, s)), (P(ax, s), P(ay, s)), (P(bx, s), P(by, s))], fill=W)
    save(img, "move", 64)


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


def fx_spark():
    """Étincelle du halo : étoile à quatre branches fines, cœur lumineux (effet « Étincelles »)."""
    size = 64
    img = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    px = img.load()
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            dx, dy = abs(x - c) / c, abs(y - c) / c
            # branches : fines le long des axes, s'amincissent vers le bout
            arm = max(math.exp(-(dy / max(0.02, 0.10 * (1 - dx))) ** 2) * (1 - dx) if dx < 1 else 0,
                      math.exp(-(dx / max(0.02, 0.10 * (1 - dy))) ** 2) * (1 - dy) if dy < 1 else 0)
            core = math.exp(-((math.hypot(dx, dy)) * 3.2) ** 2)
            a = min(1.0, arm * 1.1 + core)
            px[x, y] = (255, 255, 255, int(255 * a))
    img.save(os.path.join(OUT, "fxspark.tga"))


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
    """Couronne penchée (chef de groupe), posée de travers comme un chapeau : bandeau arrondi,
    trois pointes à boules, une échancrure sur le bandeau. Dessinée droite puis tournée."""
    img, d, s = canvas(64)
    # corps : bandeau légèrement bombé et trois pointes
    d.polygon([(P(0.14, s), P(0.70, s)), (P(0.10, s), P(0.34, s)), (P(0.31, s), P(0.52, s)), (P(0.50, s), P(0.24, s)),
               (P(0.69, s), P(0.52, s)), (P(0.90, s), P(0.34, s)), (P(0.86, s), P(0.70, s))], fill=W)
    d.rounded_rectangle([P(0.12, s), P(0.64, s), P(0.88, s), P(0.84, s)], radius=0.08 * s, fill=W)
    for cx, cy, r in ((0.10, 0.29, 0.075), (0.50, 0.19, 0.085), (0.90, 0.29, 0.075)):
        circle(d, s, cx, cy, r)
    # pierre au centre du bandeau (évidée)
    circle(d, s, 0.50, 0.74, 0.055, None)
    d.ellipse([P(0.445, s), P(0.685, s), P(0.555, s), P(0.795, s)], fill=CLEAR)
    img = img.rotate(-22, resample=Image.BICUBIC, center=(s * 0.5, s * 0.55))
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


def icon_warn():
    """Triangle d'avertissement aux coins arrondis, point d'exclamation évidé (corrections des patch notes)."""
    img, d, s = canvas(64)
    pts = [(0.5, 0.10), (0.94, 0.88), (0.06, 0.88)]
    d.polygon([(P(x, s), P(y, s)) for x, y in pts], fill=W)
    for i in range(3):
        a, b = pts[i], pts[(i + 1) % 3]
        line(d, s, [a, b], 0.10)
    O = (255, 255, 255, 0)
    d.rounded_rectangle([P(0.455, s), P(0.36, s), P(0.545, s), P(0.66, s)], radius=0.04 * s, fill=O)
    d.ellipse([P(0.45, s), P(0.71, s), P(0.55, s), P(0.81, s)], fill=O)
    save(img, "warn", 64)


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


def icon_menu():
    """Micro menu : trois barres arrondies."""
    s = 4
    img = Image.new("RGBA", (64 * s, 64 * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for y in (16, 30, 44):
        d.rounded_rectangle((10 * s, (y - 3) * s, 54 * s, (y + 3) * s), radius=3 * s, fill=(255, 255, 255, 255))
    img.resize((64, 64), Image.LANCZOS).save(os.path.join(OUT, "menu.tga"))


def icon_safe():
    """Coffre-fort (banque pleine) : caisse, porte, cadran, poignée, pieds."""
    s = 4
    img = Image.new("RGBA", (64 * s, 64 * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    W, O = (255, 255, 255, 255), (0, 0, 0, 0)
    d.rounded_rectangle((6 * s, 8 * s, 58 * s, 52 * s), radius=7 * s, fill=W)
    d.rounded_rectangle((12 * s, 14 * s, 52 * s, 46 * s), radius=4 * s, fill=O)
    d.rounded_rectangle((15 * s, 17 * s, 49 * s, 43 * s), radius=3 * s, fill=W)
    d.ellipse((24 * s, 22 * s, 40 * s, 38 * s), fill=O)
    d.ellipse((28 * s, 26 * s, 36 * s, 34 * s), fill=W)
    d.rectangle((31 * s, 19 * s, 33 * s, 24 * s), fill=W)
    d.rectangle((44 * s, 26 * s, 47 * s, 34 * s), fill=O)
    d.rectangle((12 * s, 52 * s, 20 * s, 57 * s), fill=W)
    d.rectangle((44 * s, 52 * s, 52 * s, 57 * s), fill=W)
    img.resize((64, 64), Image.LANCZOS).save(os.path.join(OUT, "safe.tga"))


def icon_guild():
    """Guilde : écu."""
    s = 4
    img = Image.new("RGBA", (64 * s, 64 * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    W, O = (255, 255, 255, 255), (0, 0, 0, 0)
    shield = [(32, 6), (54, 13), (52, 34), (32, 58), (12, 34), (10, 13)]
    d.polygon([(x * s, y * s) for x, y in shield], fill=W)
    inner = [(32, 13), (47, 18), (46, 33), (32, 50), (18, 33), (17, 18)]
    d.polygon([(x * s, y * s) for x, y in inner], fill=O)
    d.polygon([(32 * s, 18 * s), (42 * s, 22 * s), (41 * s, 32 * s), (32 * s, 44 * s)], fill=W)
    img.resize((64, 64), Image.LANCZOS).save(os.path.join(OUT, "guild.tga"))


def icon_collect():
    """Collections : trois cartes en éventail."""
    s = 4
    img = Image.new("RGBA", (64 * s, 64 * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    W, O = (255, 255, 255, 255), (0, 0, 0, 0)
    for x0 in (8, 20, 32):
        d.rounded_rectangle((x0 * s, (14 - (x0 - 8) // 4) * s, (x0 + 24) * s, (54 - (x0 - 8) // 4) * s), radius=4 * s, fill=W)
        d.rounded_rectangle(((x0 + 3) * s, (17 - (x0 - 8) // 4) * s, (x0 + 21) * s, (51 - (x0 - 8) // 4) * s), radius=3 * s, fill=O)
    d.ellipse((38 * s, 22 * s, 50 * s, 34 * s), fill=W)
    img.resize((64, 64), Image.LANCZOS).save(os.path.join(OUT, "collect.tga"))


def icon_send():
    """Objets à envoyer : enveloppe et flèche sortante."""
    s = 4
    img = Image.new("RGBA", (64 * s, 64 * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    W, O = (255, 255, 255, 255), (0, 0, 0, 0)
    d.rounded_rectangle((4 * s, 16 * s, 44 * s, 48 * s), radius=4 * s, fill=W)
    d.rounded_rectangle((8 * s, 20 * s, 40 * s, 44 * s), radius=2 * s, fill=O)
    d.line([(9 * s, 21 * s), (24 * s, 33 * s), (39 * s, 21 * s)], fill=W, width=4 * s)
    d.line([(40 * s, 32 * s), (58 * s, 32 * s)], fill=W, width=5 * s)
    d.polygon([(50 * s, 23 * s), (61 * s, 32 * s), (50 * s, 41 * s)], fill=W)
    img.resize((64, 64), Image.LANCZOS).save(os.path.join(OUT, "send.tga"))


def icon_lock():
    """Cadenas (objets verrouillés) : anse et corps avec trou de serrure."""
    s = 4
    img = Image.new("RGBA", (64 * s, 64 * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    W, O = (255, 255, 255, 255), (0, 0, 0, 0)
    d.rounded_rectangle((16 * s, 6 * s, 48 * s, 40 * s), radius=16 * s, fill=W)
    d.rounded_rectangle((23 * s, 13 * s, 41 * s, 40 * s), radius=9 * s, fill=O)
    d.rounded_rectangle((10 * s, 28 * s, 54 * s, 60 * s), radius=6 * s, fill=W)
    d.ellipse((28 * s, 36 * s, 36 * s, 44 * s), fill=O)
    d.rectangle((30 * s, 42 * s, 34 * s, 52 * s), fill=O)
    img.resize((64, 64), Image.LANCZOS).save(os.path.join(OUT, "lock.tga"))


def icon_fire():
    """Feu de camp : flamme et bûches."""
    s = 4
    img = Image.new("RGBA", (64 * s, 64 * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    W, O = (255, 255, 255, 255), (0, 0, 0, 0)
    flame = [(32, 4), (40, 16), (46, 26), (46, 36), (42, 44), (32, 48), (22, 44), (18, 36), (19, 27), (24, 20), (27, 28), (30, 18)]
    d.polygon([(x * s, y * s) for x, y in flame], fill=W)
    inner = [(32, 26), (37, 34), (37, 40), (32, 44), (27, 40), (28, 34)]
    d.polygon([(x * s, y * s) for x, y in inner], fill=O)
    d.line([(10 * s, 58 * s), (54 * s, 50 * s)], fill=W, width=6 * s)
    d.line([(10 * s, 50 * s), (54 * s, 58 * s)], fill=W, width=6 * s)
    img.resize((64, 64), Image.LANCZOS).save(os.path.join(OUT, "fire.tga"))


def icon_boat():
    """Bateau : coque, mât et deux voiles (quais des bateaux sur la carte)."""
    s = 4
    img = Image.new("RGBA", (64 * s, 64 * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    W = (255, 255, 255, 255)
    hull = [(6, 42), (58, 42), (50, 54), (14, 54)]
    d.polygon([(x * s, y * s) for x, y in hull], fill=W)
    d.line([(32 * s, 8 * s), (32 * s, 42 * s)], fill=W, width=4 * s)
    d.polygon([(x * s, y * s) for x, y in [(35, 10), (52, 36), (35, 36)]], fill=W)
    d.polygon([(x * s, y * s) for x, y in [(29, 16), (29, 36), (14, 36)]], fill=W)
    img.resize((64, 64), Image.LANCZOS).save(os.path.join(OUT, "boat.tga"))


def icon_zeppelin():
    """Zeppelin : ballon allongé, ailerons et nacelle (quais des zeppelins sur la carte)."""
    s = 4
    img = Image.new("RGBA", (64 * s, 64 * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    W, O = (255, 255, 255, 255), (0, 0, 0, 0)
    d.ellipse([6 * s, 14 * s, 54 * s, 38 * s], fill=W)
    d.polygon([(x * s, y * s) for x, y in [(48, 26), (60, 14), (60, 38)]], fill=W)
    d.line([(14 * s, 26 * s), (46 * s, 26 * s)], fill=O, width=2 * s)
    d.rounded_rectangle([22 * s, 42 * s, 38 * s, 50 * s], radius=2 * s, fill=W)
    d.line([(25 * s, 37 * s), (25 * s, 43 * s)], fill=W, width=2 * s)
    d.line([(35 * s, 37 * s), (35 * s, 43 * s)], fill=W, width=2 * s)
    img.resize((64, 64), Image.LANCZOS).save(os.path.join(OUT, "zeppelin.tga"))


def icon_griffon():
    """Griffon en vol, de profil : grande aile relevée, tête d'aigle, pattes repliées (maîtres de vol)."""
    s = 4
    img = Image.new("RGBA", (64 * s, 64 * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    W, O = (255, 255, 255, 255), (0, 0, 0, 0)
    def poly(pts, f=W): d.polygon([(x * s, y * s) for x, y in pts], fill=f)
    # grande aile relevée vers l'arrière, bord de fuite en plumes
    poly([(30, 34), (40, 30), (34, 18), (24, 6), (20, 14), (14, 8), (13, 18), (6, 14), (8, 24), (2, 24), (10, 32), (20, 36)])
    # corps allongé
    d.ellipse([16 * s, 30 * s, 48 * s, 44 * s], fill=W)
    # cou et tête d'aigle
    poly([(40, 34), (46, 24), (52, 22), (50, 36)])
    d.ellipse([44 * s, 18 * s, 56 * s, 29 * s], fill=W)
    # bec crochu
    poly([(54, 21), (63, 24), (59, 29), (54, 27)])
    d.ellipse([49 * s, 21 * s, 52 * s, 24 * s], fill=O)  # œil
    # pattes avant (serres) et arrière, repliées
    d.line([(44 * s, 42 * s), (50 * s, 50 * s)], fill=W, width=4 * s)
    d.line([(22 * s, 42 * s), (16 * s, 50 * s)], fill=W, width=4 * s)
    # queue de lion, fine, terminée par une touffe
    d.line([(17 * s, 38 * s), (6 * s, 44 * s), (2 * s, 40 * s)], fill=W, width=2 * s)
    poly([(0, 37), (5, 39), (2, 44)])
    img.resize((64, 64), Image.LANCZOS).save(os.path.join(OUT, "griffon.tga"))

def icon_navarrow():
    """Flèche de navigation (statistiques en vol) : pointe vers le haut, blanche bordée de noir,
    tournée par le jeu dans le sens du vol (pas teintée)."""
    img, d, s = canvas(64)
    out = [(0.5, 0.06), (0.86, 0.9), (0.5, 0.7), (0.14, 0.9)]
    d.polygon([(P(x, s), P(y, s)) for x, y in out], fill=(0, 0, 0, 235))
    inner = [(0.5, 0.17), (0.77, 0.8), (0.5, 0.64), (0.23, 0.8)]
    d.polygon([(P(x, s), P(y, s)) for x, y in inner], fill=W)
    save(img, "navarrow", 64)


def icon_flask():
    """Fiole (poisons) : col étroit, panse ronde, liquide évidé au-dessus d'une ligne."""
    img, d, s = canvas(64)
    rrect(d, s, 0.38, 0.06, 0.62, 0.16, 0.04)          # bouchon
    rrect(d, s, 0.42, 0.14, 0.58, 0.42, 0.03)          # col
    circle(d, s, 0.5, 0.64, 0.30)                      # panse
    # reflet évidé, pour que la fiole se lise en petit
    d.ellipse([P(0.33, s), P(0.50, s), P(0.43, s), P(0.66, s)], fill=(255, 255, 255, 0))
    save(img, "flask", 64)


def icon_paw():
    """Patte (familier) : coussinet et quatre doigts."""
    img, d, s = canvas(64)
    d.ellipse([P(0.26, s), P(0.46, s), P(0.74, s), P(0.86, s)], fill=W)
    for cx, cy, r in ((0.20, 0.42, 0.10), (0.37, 0.24, 0.10), (0.63, 0.24, 0.10), (0.80, 0.42, 0.10)):
        circle(d, s, cx, cy, r)
    save(img, "paw", 64)


def icon_shop():
    """Marchand : étal à auvent festonné et comptoir."""
    img, d, s = canvas(64)
    # auvent : bande pleine et festons ronds dessous
    rrect(d, s, 0.10, 0.14, 0.90, 0.34, 0.04)
    for cx in (0.20, 0.40, 0.60, 0.80):
        circle(d, s, cx, 0.34, 0.10)
    # montants et comptoir
    rrect(d, s, 0.16, 0.40, 0.24, 0.86, 0.02)
    rrect(d, s, 0.76, 0.40, 0.84, 0.86, 0.02)
    rrect(d, s, 0.10, 0.66, 0.90, 0.86, 0.04)
    save(img, "shop", 64)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for fn in [icon_circle, icon_logo, icon_home, icon_users, icon_bag, icon_hammer,
               icon_chart, icon_mail, icon_gear, icon_coin, icon_clock, icon_close,
               icon_search, icon_trash, icon_plus, icon_arrow, icon_refresh, icon_power, icon_notes, icon_chevron, icon_play, icon_pause, icon_stop, icon_minus, icon_filter, icon_grip, icon_back, icon_spark, icon_guide, icon_ring, icon_person, icon_book, icon_tree, icon_map, icon_bang, icon_lfg, icon_star, icon_crown, icon_fish, fx_halo, fx_beam, fx_ring, fx_spark, icon_pin, icon_skull, icon_move, icon_menu, icon_safe, icon_guild, icon_collect, icon_send, icon_lock, icon_fire, icon_boat, icon_zeppelin, icon_griffon, icon_warn, icon_navarrow, icon_flask, icon_paw, icon_shop]:
        fn()
    print("OK")
