#!/usr/bin/env python3
"""Génère Modules/RoadsDB.lua : chemins praticables tirés des patrouilles des PNJ de WoW Forever.

Usage : python3 tools/gen_roads.py <clone de QuestieDB>
        (git clone --depth 1 https://github.com/Questie/QuestieDB)

Source : QuestieDB (data/Forever), champ « waypoints » des PNJ : les trajets que les PNJ
(gardes, patrouilles, caravanes, monstres) suivent dans le monde. Un PNJ y a marché : ce sont
des chemins praticables (routes, ponts, cols), qui servent de base au guidage de Modules/Nav.lua.
Trajets simplifiés (Ramer-Douglas-Peucker), doublons retirés, les plus courts écartés.
Données Questie (GPLv3 selon son équipe) : garder la mention en tête du fichier généré et dans
Options > À propos.
"""
import math
import os
import sys

import lupa

TOL = 0.25        # tolérance de simplification (en % de carte, x compté x1,5)
MIN_LEN = 2.0     # trajets plus courts écartés (en % de carte)
ASPECT = 1.5      # cartes 1002 x 668 : 1 % en x vaut 1,5 % en y


def dist(a, b):
    return math.hypot((a[0] - b[0]) * ASPECT, a[1] - b[1])


def seg_dist(p, a, b):
    ax, ay, bx, by, px, py = a[0] * ASPECT, a[1], b[0] * ASPECT, b[1], p[0] * ASPECT, p[1]
    dx, dy = bx - ax, by - ay
    l2 = dx * dx + dy * dy
    if l2 == 0:
        return math.hypot(px - ax, py - ay)
    t = max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / l2))
    return math.hypot(px - ax - t * dx, py - ay - t * dy)


def rdp(pts):
    if len(pts) < 3:
        return pts
    keep = [False] * len(pts)
    keep[0] = keep[-1] = True
    stack = [(0, len(pts) - 1)]
    while stack:
        i, j = stack.pop()
        best, bi = 0, -1
        for k in range(i + 1, j):
            d = seg_dist(pts[k], pts[i], pts[j])
            if d > best:
                best, bi = d, k
        if best > TOL:
            keep[bi] = True
            stack.append((i, bi))
            stack.append((bi, j))
    return [p for p, k in zip(pts, keep) if k]


def main(root):
    L = lupa.LuaRuntime(unpack_returned_tuples=True)
    L.execute('QDB={}; ZDB={private={}}\nloadstring=load\n'
              'QuestieLoader={ImportModule=function(_,n) if n=="ZoneDB" then return ZDB end return QDB end}')

    def run(rel):
        with open(os.path.join(root, rel), encoding="utf-8") as f:
            L.execute(f.read())
    run("data/Forever/foreverNpcDB.lua")
    run("support/Forever/Zones/areaIdToUiMapId.lua")
    npcs = L.execute("return load(QDB.npcData)()")
    amap = L.execute("return load(ZDB.private.areaIdToUiMapId)()")

    per_map, seen = {}, set()
    raw = 0
    for nid, n in npcs.items():
        wp = n[8]
        if not wp:
            continue
        for area, lines in wp.items():
            ui = amap[area]
            if not ui:
                continue
            for li in range(1, len(lines) + 1):
                seg = lines[li]
                pts = []
                for k in range(1, len(seg) + 1):
                    c = seg[k]
                    if c[1] is not None and c[1] >= 0 and c[2] is not None and c[2] >= 0:
                        p = (round(c[1], 1), round(c[2], 1))
                        if not pts or pts[-1] != p:
                            pts.append(p)
                raw += len(pts)
                if len(pts) < 2:
                    continue
                length = sum(dist(pts[i], pts[i + 1]) for i in range(len(pts) - 1))
                if length < MIN_LEN:
                    continue
                pts = rdp(pts)
                key = (ui, tuple(pts))
                rkey = (ui, tuple(reversed(pts)))
                if key in seen or rkey in seen:
                    continue
                seen.add(key)
                per_map.setdefault(ui, []).append(pts)

    lines = [
        "-- FICHIER GÉNÉRÉ par tools/gen_roads.py : ne pas modifier à la main.",
        "-- Chemins praticables de WoW Forever : trajets de patrouille des PNJ (routes, ponts, cols).",
        "-- Données tirées de QuestieDB (https://github.com/Questie/QuestieDB), base de données de l'addon",
        "-- Questie : sous la licence de Questie (GPLv3 selon son équipe).",
        "-- WK.RoadsDB[uiMapID] = { { x, y, x, y, ... }, ... }  (x, y : 0-100, un trajet par liste)",
        "local ADDON_NAME, WK = ...",
        "WK.RoadsDB = {",
    ]
    total = 0
    for ui in sorted(per_map):
        lines.append("[%d] = {" % ui)
        for pts in per_map[ui]:
            total += len(pts)
            lines.append("{" + ",".join("%g,%g" % p for p in pts) + "},")
        lines.append("},")
    lines.append("}")
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Modules", "RoadsDB.lua")
    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("%d trajets, %d points (sur %d) sur %d cartes -> %s (%d Ko)" % (
        sum(len(v) for v in per_map.values()), total, raw, len(per_map), out, os.path.getsize(out) // 1024))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1])
