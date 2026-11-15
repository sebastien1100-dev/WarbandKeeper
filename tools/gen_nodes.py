#!/usr/bin/env python3
"""Génère Modules/NodesDB.lua : emplacements connus des filons et des plantes de WoW Forever.

Usage : python3 tools/gen_nodes.py <clone de QuestieDB>
        (git clone --depth 1 https://github.com/Questie/QuestieDB)

Source : la base d'objets de QuestieDB (data/Forever/foreverObjectDB.lua), qui donne pour
chaque filon et chaque plante ses points d'apparition par zone. On ne garde que la position
et l'objet récolté. Données Questie (GPLv3 selon son équipe) : garder la mention en tête du
fichier généré et dans Options > À propos.
"""
import os
import sys

import lupa

# Nom de l'objet du décor (anglais) -> objet récolté (identifiant de Modules/Gathering.lua)
ORE = {
    "copper vein": 2770, "tin vein": 2771, "silver vein": 2775, "iron deposit": 2772, "gold vein": 2776,
    "mithril deposit": 3858, "truesilver deposit": 7911, "small thorium vein": 10620,
    "rich thorium vein": 10620, "dark iron deposit": 11370,
}
HERB = {
    "peacebloom": 2447, "silverleaf": 765, "earthroot": 2449, "mageroyal": 785, "briarthorn": 2450,
    "stranglekelp": 3820, "bruiseweed": 2453, "wild steelbloom": 3355, "grave moss": 3369, "kingsblood": 3356,
    "liferoot": 3357, "fadeleaf": 3818, "goldthorn": 3821, "khadgar's whisker": 3358, "wintersbite": 3819,
    "firebloom": 4625, "purple lotus": 8831, "arthas' tears": 8836, "sungrass": 8838, "blindweed": 8839,
    "ghost mushroom": 8845, "gromsblood": 8846, "golden sansam": 13464, "dreamfoil": 13463,
    "mountain silversage": 13465, "plaguebloom": 13466, "icecap": 13467, "black lotus": 13468,
}
PREFIXES = ("ooze covered ", "hakkari ")  # variantes d'un même filon


def item_for(name):
    low = (name or "").lower().strip()
    for p in PREFIXES:
        if low.startswith(p):
            low = low[len(p):]
    return ORE.get(low) or HERB.get(low)


def main(root):
    L = lupa.LuaRuntime(unpack_returned_tuples=True)
    L.execute('QDB={}; ZDB={private={}}; L10N={npcNameLookup={}, objectNameLookup={}}\n'
              'GetLocale=function() return "frFR" end\n'
              'loadstring=load\n'
              'QuestieLoader={ImportModule=function(_,n) if n=="ZoneDB" then return ZDB elseif n=="l10n" then return L10N end return QDB end}')

    def run(rel):
        with open(os.path.join(root, rel), encoding="utf-8") as f:
            L.execute(f.read())
    run("data/Forever/foreverObjectDB.lua")
    run("support/Forever/Zones/areaIdToUiMapId.lua")
    objs = L.execute("return load(QDB.objectData)()")
    amap = L.execute("return load(ZDB.private.areaIdToUiMapId)()")

    per_map = {}  # uiMapID -> itemID -> set((x, y))  en dixièmes de pour cent (0-1000)
    for _, o in objs.items():
        item = item_for(o[1])
        if not item or not o[4]:
            continue
        for area, coords in o[4].items():
            ui = amap[area]
            if not ui:
                continue
            for i in range(1, len(coords) + 1):
                c = coords[i]
                x, y = c[1], c[2]
                if x is None or y is None or x < 0 or y < 0:
                    continue
                per_map.setdefault(ui, {}).setdefault(item, set()).add((int(round(x * 10)), int(round(y * 10))))

    lines = [
        "-- FICHIER GÉNÉRÉ par tools/gen_nodes.py : ne pas modifier à la main.",
        "-- Emplacements connus des filons et des plantes de WoW Forever (points d'apparition possibles).",
        "-- Données tirées de QuestieDB (https://github.com/Questie/QuestieDB), base de données de l'addon",
        "-- Questie : positions seulement, sous la licence de Questie (GPLv3 selon son équipe).",
        "-- WK.NodesDB[uiMapID][objet récolté] = { x1, y1, x2, y2, ... }  (x, y de 0 à 1000 sur la carte de la zone)",
        "local ADDON_NAME, WK = ...",
        "WK.NodesDB = {",
    ]
    total = 0
    for ui in sorted(per_map):
        lines.append("[%d] = {" % ui)
        for item in sorted(per_map[ui]):
            pts = sorted(per_map[ui][item])
            total += len(pts)
            lines.append("[%d]={%s}," % (item, ",".join("%d,%d" % p for p in pts)))
        lines.append("},")
    lines.append("}")
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Modules", "NodesDB.lua")
    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("%d emplacements sur %d cartes -> %s (%d Ko)" % (total, len(per_map), out, os.path.getsize(out) // 1024))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(sys.argv[1])
