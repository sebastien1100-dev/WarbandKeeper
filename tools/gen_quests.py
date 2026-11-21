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
import json
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


# Corrections constatées en jeu sur WoW Forever (QuestieDB se trompe ou n'a pas l'info) :
# quête -> { "preAll": [quêtes à faire avant], "pre": [une de ces quêtes avant], "nxt": suite,
#           "group": True / False (quête de groupe, si le rang des monstres trompe) }
FIXES = {
    472: {"preAll": [304]},  # La chute de Dun Modr : après « Une tâche sinistre » (Les Paluns)
}


# noms des quêtes que le jeu ne propose pas (pas encore faites, retirées, tests)
JUNK = re.compile(r"^\s*(<NYI>|<TXT>|<UNUSED>|<TEST>|\[DEPRECATED\]|\[UNUSED\]|\[PH\]|ZZOLD|zzOLD)|DEPRECATED", re.I)


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
    run("data/Forever/foreverItemDB.lua")
    run("support/Forever/Zones/areaIdToUiMapId.lua")
    run("support/Forever/QuestXP/xpDB-classic.lua")
    run("support/Forever/QuestXP/xpDB-traces.lua")
    run("l10n/Classic/lookupQuests/frFR.lua")
    quests = L.execute("return load(QDB.questData)()")
    npcs = L.execute("return load(QDB.npcData)()")
    objs = L.execute("return load(QDB.objectData)()")
    items = L.execute("return load(QDB.itemData)()")
    # corrections WoW Forever de QuestieDB (lues comme du texte, voir questie_forever.py)
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from questie_forever import apply_forever
    for mod, (n, new, unk) in apply_forever(L, root, quests=quests, npcs=npcs, objects=objs, items=items).items():
        print("  %s : %d corrigés, %d nouveaux" % (mod, n, new), file=sys.stderr)
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

    def elite(nid):
        e = npcs[nid]
        return bool(e and (e[6] or 0) in (1, 2, 3))  # élite, rare élite, boss

    def group_quest(q):
        """quête de groupe : un monstre à tuer est élite, ou un objet ne tombe que sur des élites
        (QuestieDB n'a pas le nombre de joueurs conseillé : déduit du rang des monstres)"""
        ob = q[10]
        if not ob:
            return False
        for o in lst(ob[1]):
            if o and o[1] and elite(o[1]):
                return True
        for kc in lst(ob[5]):
            if kc and kc[1] and any(elite(n) for n in lst(kc[1])):
                return True
        for o in lst(ob[3]):
            it = o and o[1] and items[o[1]]
            if it:
                drops = lst(it[2])
                if drops and not lst(it[3]) and not lst(it[14]) and all(elite(n) for n in drops):
                    return True
        return False

    # relevé wowhead (tools/wowhead_quests.py) : nom français et niveau du jeu, quêtes absentes du site
    wh = {}
    whp = os.path.join(os.path.dirname(os.path.abspath(__file__)), "quests", "wowhead.json")
    if os.path.exists(whp):
        with open(whp, encoding="utf-8") as f:
            wh = {int(k): v for k, v in json.load(f).items()}
    wh_stats = {"fr": 0, "lvl": 0, "missing": 0}
    per_map = {}
    skipped = 0
    for qid, q in quests.items():
        # répétables, et quêtes jamais ouvertes dans le jeu (« <NYI> », « [DEPRECATED] »…)
        if not q[1] or (q[24] or 0) & 1 or JUNK.search(q[1]):
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
            # aucune zone connue (ni zone de la quête, ni donneur placé) : gardée à part (WK.QuestsOther),
            # comptée dans les totaux mais sur aucune carte
            mp = 0
        races = q[6] or 0
        side = 0
        if races and not (races & HORDE):
            side = 1
        elif races and not (races & ALLIANCE):
            side = 2
        pre = lst(q[13])
        preAll = lst(q[12])
        fx = FIXES.get(qid, {})
        pre = fx.get("pre", pre)
        preAll = fx.get("preAll", preAll)
        f = fr[qid] if fr else None
        frname = f[1] if f else None
        lvl = q[5] or 0
        w = wh.get(qid)
        if w and w.get("missing"):
            wh_stats["missing"] += 1
        elif w:
            if not frname and w.get("fr") and w["fr"] != q[1]:
                frname = w["fr"]
                wh_stats["fr"] += 1
            if w.get("lvl") and w["lvl"] != lvl:
                lvl = w["lvl"]
                wh_stats["lvl"] += 1
        xpe = xp[qid]
        # fermée quand une de ces quêtes est prise ou faite : exclusives, quête annoncée (introduction),
        # suite de la chaîne (nextQuestInChain), désactivée par, disponible jusqu'à
        excl = set(lst(q[16]))
        for k in (22, 27, 33, 36):
            if isinstance(q[k], int) and q[k] > 0:
                excl.add(q[k])
        excl.discard(qid)
        rep = lst(q[19]) if q[19] else None
        per_map.setdefault(mp, []).append(dict(
            excl=sorted(excl), maxLvl=q[32] or 0, rep=rep if rep and len(rep) == 2 else None,
            bread=q[27] or 0, races=races,
            id=qid, name=q[1], fr=frname, lvl=lvl, req=q[4] or 0, side=side,
            cls=q[7] or 0, kind=kind, skill=skill, x=x, y=y, smap=smap, sid=sid,
            xp=xpe[2] if xpe else 0, pre=pre, preAll=preAll, nxt=fx.get("nxt", q[22] or 0),
            grp=1 if (kind != "d" and fx.get("group", group_quest(q))) else 0))

    # quête qui en suit une autre (nextQuestInChain) sans prérequis noté : au moins une de celles d'avant
    # (même faction et même niveau, sans restriction de classe propre, pas une simple quête d'introduction)
    allq = {e["id"]: e for lst_ in per_map.values() for e in lst_}
    before = {}
    for e in allq.values():
        if e["nxt"] and e["nxt"] != e["id"]:
            before.setdefault(e["nxt"], []).append(e)
    nprev = 0
    for e in allq.values():
        e["prev"] = []
        if e["pre"] or e["preAll"] or e["id"] not in before:
            continue
        ps = []
        for b in before[e["id"]]:
            if b["bread"] == e["id"]:
                ps = []
                break  # une quête d'introduction y mène : la quête se prend aussi sans elle
            if b["side"] and e["side"] and b["side"] != e["side"]:
                continue
            if b["side"] and not e["side"]:
                continue
            if b["cls"] and b["cls"] != e["cls"]:
                continue
            if b["races"] and e["races"] and (b["races"] & e["races"]) != e["races"]:
                continue
            if (b["lvl"] or 0) < (e["lvl"] or 0):
                continue  # plus bas niveau : une introduction le plus souvent, la quête se prend sans elle
            ps.append(b["id"])
        if ps and len(ps) == len(before[e["id"]]):
            e["prev"] = sorted(ps)
            nprev += 1
    print("  %d quêtes avec une quête d'avant tirée de la chaîne" % nprev, file=sys.stderr)

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
        "--   carte du donneur s'il est dans une autre zone, 1 si quête de groupe (monstre élite à tuer),",
        "--   { quêtes qui la ferment (exclusives, annoncée, désactivée par) }, niveau max, { faction, réputation min },",
        "--   { une de ces quêtes avant (tiré de la chaîne) }, races (masque, seulement s'il ne couvre pas toute la faction) },",
        "--   ... }",
        "local ADDON_NAME, WK = ...",
        "WK.QuestsDB = {",
    ]
    total = 0
    other = per_map.pop(0, [])

    def race_mask(r):
        """races des 8 races d'origine, seulement si elles ne couvrent pas toute une faction (sinon 0)"""
        m = (r or 0) & 255
        if m == 0 or (m & ALLIANCE) == ALLIANCE or (m & HORDE) == HORDE:
            return 0
        return m

    def tl(v):
        return ("{" + ",".join(map(str, v)) + "}") if v else "nil"

    def row(e):
        f = [str(e["id"]), s(e["name"]), s(e["fr"]), str(e["lvl"]), str(e["req"]), n(e["side"]), n(e["cls"]),
             s(e["kind"]), s(e["skill"]), n(e["x"]), n(e["y"]), n(e["sid"]), n(e["xp"]), tl(e["pre"]), tl(e["preAll"]),
             n(e["nxt"]), n(e["smap"]), "1" if e["grp"] else "nil",
             tl(e["excl"]), n(e["maxLvl"]), tl(e["rep"]), tl(e["prev"]),
             n(race_mask(e["races"]))]
        while f[-1] == "nil":
            f.pop()
        return "{" + ",".join(f) + "},"
    for mp in sorted(per_map):
        lines.append("[%d] = {" % mp)
        for e in sorted(per_map[mp], key=lambda e: (e["lvl"], e["id"])):
            total += 1
            lines.append(row(e))
        lines.append("},")
    lines.append("}")
    # quêtes sans zone connue : même format, comptées dans les totaux (Modules/Quests.lua), sur aucune carte
    lines.append("WK.QuestsOther = {")
    for e in sorted(other, key=lambda e: (e["lvl"], e["id"])):
        lines.append(row(e))
    lines.append("}")
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Modules", "QuestsDB.lua")
    try:
        with open(out, encoding="utf-8") as f:
            before = f.read()
    except OSError:
        before = ""
    text = "\n".join(lines) + "\n"
    with open(out, "w", encoding="utf-8") as f:
        f.write(text)
    # journal des données : ce qui a changé depuis la génération précédente (Modules/DataLogDB.lua)
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import datalog
    entry = datalog.record(before, text)
    if entry:
        print("journal : +%d quêtes, %d corrigées, %d retirées" % (len(entry["add"]), len(entry["chg"]), len(entry["rem"])))
    if wh:
        print("  wowhead : %d noms français ajoutés, %d niveaux corrigés, %d quêtes absentes du site" % (
            wh_stats["fr"], wh_stats["lvl"], wh_stats["missing"]), file=sys.stderr)
    print("%d quêtes sur %d cartes, %d sans zone (%d ignorées) -> %s (%d Ko)" % (total, len(per_map), len(other), skipped, out, os.path.getsize(out) // 1024))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(sys.argv[1])
