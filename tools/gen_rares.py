#!/usr/bin/env python3
"""Génère Modules/RaresDB.lua : les monstres rares de WoW Forever.

Usage : python3 tools/gen_rares.py <clone de QuestieDB>
        (git clone --depth 1 https://github.com/Questie/QuestieDB)

Source : QuestieDB (data/Forever) : PNJ de rang rare (4) ou rare élite (2), leurs points
d'apparition et patrouilles par zone, leur nom français, et leur butin notable (recettes, et objets
que peu de monstres donnent). Données Questie (GPLv3 selon son équipe) : garder la mention en tête
du fichier généré et dans Options > À propos.
"""
import os
import sys

import lupa

RARE, RARE_ELITE = 4, 2
MAX_LOOT = 6


def main(root):
    L = lupa.LuaRuntime(unpack_returned_tuples=True)
    L.execute('QDB={}; ZDB={private={}}; L10N={npcNameLookup={}, objectNameLookup={}}\n'
              'GetLocale=function() return "frFR" end\n'
              'loadstring=load\n'
              'QuestieLoader={ImportModule=function(_,n) if n=="ZoneDB" then return ZDB elseif n=="l10n" then return L10N end return QDB end}')

    def run(rel):
        with open(os.path.join(root, rel), encoding="utf-8") as f:
            L.execute(f.read())
    run("data/Forever/foreverNpcDB.lua")
    run("data/Forever/foreverItemDB.lua")
    run("support/Forever/Zones/areaIdToUiMapId.lua")
    run("l10n/Forever/lookupNpcs/frFR.lua")
    npcs = L.execute("return load(QDB.npcData)()")
    items = L.execute("return load(QDB.itemData)()")
    amap = L.execute("return load(ZDB.private.areaIdToUiMapId)()")
    fr = L.globals().L10N.npcNameLookup["frFR"]
    if lupa.lua_type(fr) == "function":
        fr = fr()

    rares = {}
    for nid, n in npcs.items():
        if n[6] in (RARE, RARE_ELITE) and n[7]:
            rares[nid] = n

    # butin notable : recettes (classe 9), et objets que peu de monstres donnent (au plus 3)
    loot = {}
    for iid, it in items.items():
        drops = it[2]
        if not drops:
            continue
        ids = [drops[i] for i in range(1, len(drops) + 1)]
        mine = [d for d in ids if d in rares]
        if not mine:
            continue
        cls, sub = it[12], it[13]
        if cls == 9 or (len(ids) <= 3 and cls in (2, 4)):
            for d in mine:
                loot.setdefault(d, []).append((0 if cls == 9 else 1, iid, sub if cls == 9 else -1))

    per_map = {}
    for nid, n in rares.items():
        f = fr[nid] if fr else None
        name_fr = f[1] if f else None
        for area, coords in n[7].items():
            ui = amap[area]
            if not ui:
                continue
            pts = []
            for i in range(1, len(coords) + 1):
                c = coords[i]
                if c[1] is not None and c[1] >= 0:
                    pts.append((round(c[1], 1), round(c[2], 1)))
            if not pts:
                continue
            path = []
            wp = n[8]
            if wp and wp[area]:
                lines = wp[area]
                for li in range(1, len(lines) + 1):
                    seg = lines[li]
                    for k in range(1, len(seg) + 1):
                        c = seg[k]
                        if c[1] is not None and c[1] >= 0:
                            path.append((round(c[1], 1), round(c[2], 1)))
            per_map.setdefault(ui, []).append((nid, n, name_fr, pts, path))

    def s(x):
        return '"' + x.replace("\\", "\\\\").replace('"', '\\"') + '"' if x else "nil"

    lines = [
        "-- FICHIER GÉNÉRÉ par tools/gen_rares.py : ne pas modifier à la main.",
        "-- Monstres rares de WoW Forever : apparitions, patrouilles et butin notable.",
        "-- Données tirées de QuestieDB (https://github.com/Questie/QuestieDB), base de données de l'addon",
        "-- Questie : sous la licence de Questie (GPLv3 selon son équipe).",
        "-- WK.RaresDB[uiMapID] = { { id, nom, nom fr, niv. min, niv. max, élite (true/nil),",
        "--                          { x, y, ... } apparitions, { x, y, ... } patrouille }, ... }  (x, y : 0-100)",
        "-- WK.RaresLoot[id] = { objet, ... } (recettes d'abord) ; WK.RaresRecipe[objet] = sous-classe de recette",
        "local ADDON_NAME, WK = ...",
        "WK.RaresDB = {",
    ]
    total = 0
    for ui in sorted(per_map):
        lines.append("[%d] = {" % ui)
        for nid, n, name_fr, pts, path in sorted(per_map[ui], key=lambda e: (e[1][4] or 0, e[0])):
            total += 1
            lines.append("{%d,%s,%s,%d,%d,%s,{%s},{%s}}," % (
                nid, s(n[1]), s(name_fr), n[4] or 0, n[5] or 0, "true" if n[6] == RARE_ELITE else "nil",
                ",".join("%g,%g" % p for p in pts), ",".join("%g,%g" % p for p in path[:80])))
        lines.append("},")
    lines.append("}")
    lines.append("WK.RaresLoot = {")
    recipes = {}
    for nid in sorted(loot):
        lst = sorted(set(loot[nid]))[:MAX_LOOT]
        lines.append("[%d]={%s}," % (nid, ",".join(str(e[1]) for e in lst)))
        for kind, iid, sub in lst:
            if kind == 0:
                recipes[iid] = sub
    lines.append("}")
    lines.append("WK.RaresRecipe = {" + ",".join("[%d]=%d" % (k, v) for k, v in sorted(recipes.items())) + "}")
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Modules", "RaresDB.lua")
    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("%d rares sur %d cartes, butin pour %d -> %s (%d Ko)" % (total, len(per_map), len(loot), out, os.path.getsize(out) // 1024))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(sys.argv[1])
