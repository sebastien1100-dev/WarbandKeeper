#!/usr/bin/env python3
"""Génère Modules/DungeonsDB.lua : donjons de WoW Forever, leurs boss et le butin de chacun.

Usage : python3 tools/gen_dungeons.py <clone de QuestieDB>
        (git clone --depth 1 https://github.com/Questie/QuestieDB)

Source : QuestieDB (data/Forever, support/Forever/Zones/dungeons.lua, l10n/Forever/lookupNpcs).
Pour chaque donjon de la liste DUNGEONS (nom français, niveaux, n° d'instance du jeu) :
  - zones du donjon (zone principale + zones annexes de dungeons.lua) ;
  - entrée (carte et position, convertie en uiMapID) pour le guidage ;
  - boss : PNJ élites du donjon de niveau fixe, qui lâchent peu d'objets (12 au plus) dont au moins un à
    eux seuls (ou presque) ; les élites de passage, à fourchette de niveaux et butin courant, sont écartés ;
  - butin : armes, armures, recettes et objets divers que lâchent au plus MAX_DROPPERS PNJ (le butin commun,
    tissu et nourriture, est écarté) ;
  - butin de chaque boss : ces objets. La rareté et le taux de drop ne sont pas dans QuestieDB (rareté lue en jeu).
Données Questie (GPLv3 selon son équipe) : garder la mention en tête du fichier généré et dans
Options > À propos.
"""
import os
import re
import sys

import lupa

MAX_DROPPERS = 4
LOOT_CLASSES = {2, 4, 9, 15}  # arme, armure, recette, divers
# zone principale, n° d'instance, nom français, niveau min, niveau max
DUNGEONS = [
    (2437, 389, "Gouffre de Ragefeu", 13, 18),
    (718, 43, "Cavernes des Lamentations", 17, 24),
    (1581, 36, "Les Mortemines", 17, 26),
    (209, 33, "Donjon d'Ombrecroc", 22, 30),
    (719, 48, "Profondeurs de Brassenoire", 24, 32),
    (717, 34, "La Prison", 24, 32),
    (721, 90, "Gnomeregan", 29, 38),
    (491, 47, "Kraal de Tranchebauge", 30, 40),
    (796, 189, "Monastère Écarlate", 26, 45),
    (722, 129, "Souilles de Tranchebauge", 37, 46),
    (1337, 70, "Uldaman", 41, 51),
    (1176, 209, "Zul'Farrak", 44, 54),
    (2100, 349, "Maraudon", 46, 55),
    (1477, 109, "Le temple d'Atal'Hakkar", 50, 60),
    (1584, 230, "Profondeurs de Rochenoire", 52, 60),
    (1583, 229, "Pic Rochenoire", 55, 60),
    (2557, 429, "Hache-Tripes", 55, 60),
    (2057, 289, "Scholomance", 58, 60),
    (2017, 329, "Stratholme", 58, 60),
]


def main(root):
    L = lupa.LuaRuntime(unpack_returned_tuples=True)
    L.execute('QDB={}; ZDB={private={}}; L10N={npcNameLookup={}}\nGetLocale=function() return "frFR" end\nloadstring=load\n'
              'UnitFactionGroup=function() return "Alliance" end\n'
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

    # zones annexes et entrées (dungeons.lua, lu en texte)
    alt, entrance = {}, {}
    with open(os.path.join(root, "support/Forever/Zones/dungeons.lua"), encoding="utf-8") as f:
        for line in f:
            m = re.match(r'\s*\[(\d+)\] = \{"[^"]*",(nil|\{[\d,]*\}),(\d+),\{\{(\d+), ([\d.]+), ([\d.]+)\}', line)
            if m:
                area = int(m.group(1))
                alt[area] = [int(a) for a in re.findall(r"\d+", m.group(2))] if m.group(2) != "nil" else []
                entrance[area] = (int(m.group(4)), float(m.group(5)), float(m.group(6)))

    # objets : qui les lâche
    droppers = {}
    for iid, it in items.items():
        d = it[2]
        if d:
            droppers[iid] = [d[k] for k in range(1, len(d) + 1)]

    def s(x):
        return '"' + x.replace("\\", "\\\\").replace('"', '\\"') + '"' if x else "nil"

    lines = [
        "-- FICHIER GÉNÉRÉ par tools/gen_dungeons.py : ne pas modifier à la main.",
        "-- Donjons de WoW Forever : boss et butin propre à chacun (armes, armures, recettes, objets rares).",
        "-- Données tirées de QuestieDB (https://github.com/Questie/QuestieDB), base de données de l'addon",
        "-- Questie : sous la licence de Questie (GPLv3 selon son équipe).",
        "-- WK.DungeonsDB = { { key (zone), inst (n° d'instance), name, min, max, zones = { zone, ... },",
        "--   entry = { uiMapID, x, y } (0-100), bosses = { { id, nom, nom fr, niveau, { objet, ... } }, ... } }, ... }",
        "local ADDON_NAME, WK = ...",
        "WK.DungeonsDB = {",
    ]
    total_b, total_i = 0, 0
    for area, inst, name, lo, hi in DUNGEONS:
        zones = set([area] + alt.get(area, []))
        bosses = []
        for nid, n in npcs.items():
            if n[9] in zones and (n[6] or 0) >= 1:
                # un boss a un niveau fixe, peu d'objets (les élites de passage lâchent des dizaines
                # d'objets courants) et au moins un objet à lui seul (ou presque)
                if (n[4] or 0) != (n[5] or 0):
                    continue
                loot, own, anyCount = [], False, 0
                for iid, ds in droppers.items():
                    if nid in ds and items[iid][12] in LOOT_CLASSES:
                        anyCount += 1
                        if len(ds) <= MAX_DROPPERS:
                            loot.append(iid)
                            if len(ds) <= 2:
                                own = True
                if anyCount > 12:
                    continue
                if loot and own:
                    f = fr[nid] if fr else None
                    name_fr = f[1] if f else None
                    bosses.append((n[4] or 0, nid, n[1], name_fr, sorted(loot)))
        bosses.sort()
        e = entrance.get(area)
        entry = "nil"
        if e and amap[e[0]]:
            entry = "{%d,%g,%g}" % (amap[e[0]], e[1], e[2])
        lines.append("{key=%d,inst=%d,name=%s,min=%d,max=%d,zones={%s},entry=%s,bosses={" % (
            area, inst, s(name), lo, hi, ",".join(str(z) for z in sorted(zones)), entry))
        for lvl, nid, nm, nmfr, loot in bosses:
            lines.append("{%d,%s,%s,%d,{%s}}," % (nid, s(nm), s(nmfr), lvl, ",".join(str(i) for i in loot)))
            total_b += 1
            total_i += len(loot)
        lines.append("}},")
    lines.append("}")
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Modules", "DungeonsDB.lua")
    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("%d donjons, %d boss, %d objets -> %s (%d Ko)" % (len(DUNGEONS), total_b, total_i, out, os.path.getsize(out) // 1024))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1])
