#!/usr/bin/env python3
"""Génère Modules/QuestsDB.lua : les quêtes de WoW Forever, rangées par zone.

Usage : python3 tools/gen_quests.py <clone de QuestieDB>
        (git clone --depth 1 https://github.com/Questie/QuestieDB)
        Le nom français vient de l10n/Classic/lookupQuests/frFR.lua (mêmes numéros de quête).

Source : QuestieDB (data/Forever) : niveau, niveau requis, faction, classes, métier requis,
prérequis, donneur et son emplacement, XP (support/Forever/QuestXP). Les quêtes de donjon sont
rangées dans la zone de l'entrée du donjon. Les quêtes répétables sont ignorées.
Données Questie (GPLv3 selon son équipe) : garder la mention en tête du fichier généré et dans
Options > À propos.
"""
import os
import re
import sys

import lupa

ALLIANCE = 1 | 4 | 8 | 64     # humain, nain, elfe de la nuit, gnome
HORDE = 2 | 16 | 32 | 128     # orc, mort-vivant, tauren, troll
SKILLS = {164: "Forge", 165: "Travail du cuir", 171: "Alchimie", 182: "Herboristerie", 185: "Cuisine",
          186: "Minage", 197: "Couture", 202: "Ingénierie", 333: "Enchantement", 356: "Pêche",
          393: "Dépeçage", 129: "Secourisme"}
# tri de quête (zoneOrSort négatif) -> métier
SORT_SKILL = {-24: "Herboristerie", -101: "Pêche", -121: "Forge", -181: "Alchimie", -182: "Travail du cuir",
              -201: "Ingénierie", -264: "Couture", -304: "Cuisine", -324: "Secourisme"}
SORT_CLASS = {-61, -81, -82, -141, -161, -162, -261, -262, -263}


def main(root):
    L = lupa.LuaRuntime(unpack_returned_tuples=True)
    L.execute('QDB={}; ZDB={private={}}; QXP={}; L10N={questLookup={}}\n'
              'GetLocale=function() return "frFR" end\n'
              'loadstring=load\n'
              'QuestieLoader={ImportModule=function(_,n) if n=="ZoneDB" then return ZDB elseif n=="l10n" then return L10N'
              ' elseif n=="QuestXP" then return QXP end return QDB end}')

    def run(rel):
        with open(os.path.join(root, rel), encoding="utf-8") as f:
            L.execute(f.read())
    run("data/Forever/foreverQuestDB.lua")
    run("data/Forever/foreverNpcDB.lua")
    run("data/Forever/foreverObjectDB.lua")
    run("support/Forever/Zones/areaIdToUiMapId.lua")
    run("support/Forever/QuestXP/xpDB-classic.lua")
    run("support/Forever/QuestXP/xpDB-traces.lua")
    run("l10n/Classic/lookupQuests/frFR.lua")
    quests = L.execute("return load(QDB.questData)()")
    npcs = L.execute("return load(QDB.npcData)()")
    objs = L.execute("return load(QDB.objectData)()")
    amap = L.execute("return load(ZDB.private.areaIdToUiMapId)()")
    xp = L.globals().QXP.db
    fr = L.globals().L10N.questLookup["frFR"]
    if lupa.lua_type(fr) == "function":
        fr = fr()
    # donjons : zone d'entrée
    dungeon_parent = {}
    with open(os.path.join(root, "support/Forever/Zones/dungeons.lua"), encoding="utf-8") as f:
        for m in re.finditer(r'\[(\d+)\] = \{"[^"]*",(\{[\d,]*\}|nil),(\d+),', f.read()):
            parent = int(m.group(3))
            dungeon_parent[int(m.group(1))] = parent
            if m.group(2) != "nil":
                for a in re.findall(r"\d+", m.group(2)):
                    dungeon_parent[int(a)] = parent

    def ui(area):
        return amap[area] if area and amap[area] else None

    def lst(t):
        return [t[i] for i in range(1, len(t) + 1)] if t else []

    def starter(q):
        """(numéro du donneur : PNJ > 0, objet < 0, {aire: (x, y)})"""
        sb = q[2]
        if not sb:
            return None, {}
        for kind, db, sign in ((1, npcs, 1), (2, objs, -1)):
            for sid in lst(sb[kind]):
                e = db[sid]
                sp = e and (e[7] if sign == 1 else e[4])
                if not sp:
                    continue
                pos = {}
                for area, coords in sp.items():
                    c = coords[1]
                    if c and c[1] is not None and c[1] >= 0:
                        pos[area] = (round(c[1], 1), round(c[2], 1))
                if pos:
                    return sign * sid, pos
        return None, {}

    per_map = {}
    skipped = 0
    for qid, q in quests.items():
        if not q[1] or (q[24] or 0) & 1:
            skipped += 1
            continue
        sid, pos = starter(q)
        zs = q[17] or 0
        kind = None
        area = zs if zs > 0 else None
        if area in dungeon_parent:
            kind, area = "d", dungeon_parent[area]
        skill = None
        if q[18]:
            skill = SKILLS.get(q[18][1])
        if zs in SORT_SKILL:
            skill = skill or SORT_SKILL[zs]
        if skill:
            kind = "p"
        elif zs in SORT_CLASS or (q[7] or 0):
            kind = kind or "c"
        mp = ui(area)
        x = y = smap = None
        if mp and pos:
            for a, p in pos.items():
                if ui(a) == mp:
                    x, y = p
                    break
            if x is None:
                for a, p in pos.items():
                    if ui(a) and a not in dungeon_parent:
                        smap, (x, y) = ui(a), p
                        break
        if not mp and pos:
            a, (x, y) = next(iter(pos.items()))
            if a in dungeon_parent:
                a, x, y = dungeon_parent[a], None, None
            mp = ui(a)
        if not mp:
            skipped += 1
            continue
        races = q[6] or 0
        side = 0
        if races and not (races & HORDE):
            side = 1
        elif races and not (races & ALLIANCE):
            side = 2
        pre = lst(q[13])
        preAll = lst(q[12])
        f = fr[qid] if fr else None
        xpe = xp[qid]
        per_map.setdefault(mp, []).append(dict(
            id=qid, name=q[1], fr=f[1] if f else None, lvl=q[5] or 0, req=q[4] or 0, side=side,
            cls=q[7] or 0, kind=kind, skill=skill, x=x, y=y, smap=smap, sid=sid,
            xp=xpe[2] if xpe else 0, pre=pre, preAll=preAll, nxt=q[22] or 0))

    def s(x):
        return '"' + x.replace("\\", "\\\\").replace('"', '\\"') + '"' if x else "nil"

    def n(v):
        return "nil" if v is None or v == 0 else ("%g" % v)

    lines = [
        "-- FICHIER GÉNÉRÉ par tools/gen_quests.py : ne pas modifier à la main.",
        "-- Quêtes de WoW Forever rangées par zone (quêtes de donjon : zone de l'entrée).",
        "-- Données tirées de QuestieDB (https://github.com/Questie/QuestieDB), base de données de l'addon",
        "-- Questie : sous la licence de Questie (GPLv3 selon son équipe).",
        "-- WK.QuestsDB[uiMapID] = { { id, nom, nom fr, niveau, niveau requis, faction (1 Alliance, 2 Horde),",
        "--   classes (masque), genre (\"d\" donjon, \"p\" métier, \"c\" classe), métier, x, y (donneur, 0-100),",
        "--   donneur (PNJ > 0, objet < 0), XP, { une de ces quêtes avant }, { toutes ces quêtes avant }, suivante,",
        "--   carte du donneur s'il est dans une autre zone }, ... }",
        "local ADDON_NAME, WK = ...",
        "WK.QuestsDB = {",
    ]
    total = 0
    for mp in sorted(per_map):
        lines.append("[%d] = {" % mp)
        for e in sorted(per_map[mp], key=lambda e: (e["lvl"], e["id"])):
            total += 1
            lines.append("{%d,%s,%s,%d,%d,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s}," % (
                e["id"], s(e["name"]), s(e["fr"]), e["lvl"], e["req"], n(e["side"]), n(e["cls"]),
                s(e["kind"]), s(e["skill"]), n(e["x"]), n(e["y"]), n(e["sid"]), n(e["xp"]),
                ("{" + ",".join(map(str, e["pre"])) + "}") if e["pre"] else "nil",
                ("{" + ",".join(map(str, e["preAll"])) + "}") if e["preAll"] else "nil",
                n(e["nxt"]), n(e["smap"])))
        lines.append("},")
    lines.append("}")
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Modules", "QuestsDB.lua")
    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("%d quêtes sur %d cartes (%d ignorées) -> %s (%d Ko)" % (total, len(per_map), skipped, out, os.path.getsize(out) // 1024))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(sys.argv[1])
