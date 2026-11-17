#!/usr/bin/env python3
"""Génère Modules/DungeonsDB.lua : donjons et raids de WoW Forever, leurs boss et le butin de chacun.

Deux étapes :
  1. python3 tools/gen_dungeons.py --import <dossier>
     <dossier> contient les page-data.json des tables de butin de wowtbc.gg, téléchargés depuis
       https://wowtbc.gg/page-data/warcraftforever/loot-tables/dungeons/<donjon>/page-data.json
       https://wowtbc.gg/page-data/warcraftforever/loot-tables/raids/<raid>/page-data.json
     (liste des donjons : https://wowtbc.gg/page-data/warcraftforever/loot-tables/dungeons/page-data.json).
     Le script en garde l'essentiel dans tools/dungeons/wowtbc.json (boss, objets, rareté, niveau,
     taux de drop quand le site le donne, objet découvert ou non).
  1b. python3 tools/gen_dungeons.py --import-encounters <client-encounters.json>
     (catalogue des rencontres de boss lu dans les fichiers du jeu par Everloot :
      https://github.com/Everloot/everloot, web/src/data/game-data/client-encounters.json) : gardé dans
      tools/dungeons/encounters.json (n° d'instance » rencontres { n°, nom anglais }). Sert à la détection des
      boss tués (événement ENCOUNTER_END du jeu) et au nom français des boss (donné par le jeu en français).
  1c. python3 tools/gen_dungeons.py --import-wago <dossier>
     (tables du client WoW Forever lues sur wago.tools, en anglais et en français : Map-enUS.csv, Map-frFR.csv,
      DungeonEncounter-enUS.csv, DungeonEncounter-frFR.csv, de https://wago.tools/db2/<table>/csv?build=<version>
      &locale=<langue>) : gardé dans tools/dungeons/wago.json. Donne les n° d'instance du nouveau contenu, les noms
      français des donjons et des boss, et les rencontres (prioritaire sur le catalogue d'Everloot).
  2. python3 tools/gen_dungeons.py <clone de QuestieDB>
     (git clone --depth 1 https://github.com/Questie/QuestieDB)

Sources :
  - butin par boss et des monstres du donjon : tables de butin WoW Forever de wowtbc.gg (comme les guides
    de métiers) ; à citer dans l'en-tête du fichier généré et dans Options > À propos ;
  - n° de PNJ et niveau des boss (pour noter les boss tués), noms français, entrées, zones annexes et
    recettes lâchées par les boss : QuestieDB (data/Forever, support/Forever/Zones, l10n/Forever),
    GPLv3 selon son équipe : garder la mention.
Les ailes d'une même instance (Monastère Écarlate, Hache-Tripes, Pic Rochenoire) forment un seul donjon :
le jeu leur donne le même n° d'instance ; chaque boss garde le nom de son aile.
"""
import glob
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, "dungeons", "wowtbc.json")
ENCOUNTERS = os.path.join(HERE, "dungeons", "encounters.json")
WAGO = os.path.join(HERE, "dungeons", "wago.json")
OUT = os.path.join(HERE, "..", "Modules", "DungeonsDB.lua")

# page wowtbc.gg -> (clé, n° d'instance du jeu, nom français, aile, raid)
# clé : zone QuestieDB du donjon (ou zone proche pour les nouveaux), stable : les boss tués et les
# envies sont rangés sous cette clé. n° d'instance inconnu (None) : le donjon est reconnu en jeu par
# son nom ou par ses boss, et le n° est alors retenu.
DUNGEONS = {
    "ragefire-chasm": (2437, 389, "Gouffre de Ragefeu", None, False),
    "hall-of-thanes": (16919, 3065, "Hall of Thanes", None, False),
    "wailing-caverns": (718, 43, "Cavernes des Lamentations", None, False),
    "ruins-of-lordaeron": (16611, 2999, "Ruines de Lordaeron", None, False),
    "the-deadmines": (1581, 36, "Les Mortemines", None, False),
    "shadowfang-keep": (209, 33, "Donjon d'Ombrecroc", None, False),
    "blackfathom-deeps": (719, 48, "Profondeurs de Brassenoire", None, False),
    "the-stockade": (717, 34, "La Prison", None, False),
    "excavation-site-wetlands": (16732, 2998, "Excavation Site: Wetlands", None, False),
    "city-of-dalaran": (16544, 2959, "Cité de Dalaran", None, False),
    "gnomeregan": (721, 90, "Gnomeregan", None, False),
    "razorfen-kraul": (491, 47, "Kraal de Tranchebauge", None, False),
    "scarlet-monastery-graveyard": (796, 189, "Monastère Écarlate", "Cimetière", False),
    "scarlet-monastery-library": (796, 189, "Monastère Écarlate", "Bibliothèque", False),
    "scarlet-monastery-armory": (796, 189, "Monastère Écarlate", "Armurerie", False),
    "scarlet-monastery-cathedral": (796, 189, "Monastère Écarlate", "Cathédrale", False),
    "the-drowned-city": (990001, None, "The Drowned City", None, False),
    "razorfen-downs": (722, 129, "Souilles de Tranchebauge", None, False),
    "krol-dok-stronghold": (17780, None, "Krol'dok Stronghold", None, False),
    "uldaman": (1337, 70, "Uldaman", None, False),
    "alcaz-prison": (2079, None, "Alcaz Prison", None, False),
    "zul-farrak": (1176, 209, "Zul'Farrak", None, False),
    "maraudon": (2100, 349, "Maraudon", None, False),
    "the-temple-of-atal-hakkar": (1477, 109, "Le temple d'Atal'Hakkar", None, False),
    "blackrock-depths": (1584, 230, "Profondeurs de Rochenoire", None, False),
    "blackrock-spire-lower": (1583, 229, "Pic Rochenoire", "Bas", False),
    "blackrock-spire-upper": (1583, 229, "Pic Rochenoire", "Haut", False),
    "blackmaw-hold": (1216, None, "Blackmaw Hold", None, False),
    "dire-maul-east": (2557, 429, "Hache-Tripes", "Est", False),
    "dire-maul-north": (2557, 429, "Hache-Tripes", "Nord", False),
    "dire-maul-west": (2557, 429, "Hache-Tripes", "Ouest", False),
    "scholomance": (2057, 289, "Scholomance", None, False),
    "stratholme": (2017, 329, "Stratholme", None, False),
    "shaper-s-terrace": (16985, None, "Shaper's Terrace", None, False),
    "onyxia-s-lair": (2159, 249, "Repaire d'Onyxia", None, True),
    "barrow-deeps": (990002, None, "Barrow Deeps", None, True),
    "hyjal-summit": (990003, None, "Hyjal Summit", None, True),
}
RARITY = {"poor": 0, "common": 1, "uncommon": 2, "rare": 3, "epic": 4, "legendary": 5}
MAX_DROPPERS = 4  # recettes de QuestieDB ajoutées au butin d'un boss : lâchées par 4 PNJ au plus


def do_import(src):
    pages = {}
    for f in sorted(glob.glob(os.path.join(src, "*.json"))):
        try:
            with open(f, encoding="utf-8") as fh:
                j = json.load(fh)
            d = j["result"]["pageContext"]
        except (KeyError, ValueError):
            continue
        m = re.search(r"/loot-tables/(?:dungeons|raids)/([a-z0-9-]+)/", j.get("path") or "")
        slug = m.group(1) if m else None
        if slug not in DUNGEONS:
            continue
        gear = {}
        for g in d.get("gearData", []):
            other = g.get("other_stats") or {}
            gear[g["id"]] = {
                "q": RARITY.get(g.get("rarity"), 1),
                "ilvl": g.get("ilvl") or 0,
                "req": other.get("min_level") or 0,
                "drop": g.get("drop_chance"),
                # « hidden » : objet annoncé mais pas encore vu tomber (« Not yet discovered » sur le site)
                "found": not g.get("hidden") and g.get("discovered", True) is not False,
            }
        for l in d.get("loot", []):
            bosses, trash = [], []
            for b in l.get("bosses", []):
                items = [i for i in b.get("items", []) if i in gear]
                if b["name"] in ("Trash", "Trash Drop"):
                    trash += [i for i in items if i not in trash]
                else:
                    bosses.append({"name": b["name"], "items": items})
            pages[slug] = {
                "name": l.get("dungeon") or l.get("raid"),
                "levels": l.get("levels") or [60, 60],
                "bosses": bosses,
                "trash": trash,
                "items": {str(i): gear[i] for b in bosses for i in b["items"]} | {str(i): gear[i] for i in trash},
            }
    os.makedirs(os.path.dirname(CACHE), exist_ok=True)
    with open(CACHE, "w", encoding="utf-8") as f:
        json.dump(pages, f, ensure_ascii=False, indent=0, sort_keys=True)
    missing = sorted(set(DUNGEONS) - set(pages))
    print("%d pages -> %s%s" % (len(pages), CACHE, ("  (manquent : " + ", ".join(missing) + ")") if missing else ""))


def do_import_encounters(src):
    with open(src, encoding="utf-8") as f:
        d = json.load(f)
    out = {"source": "Everloot, client-encounters.json (https://github.com/Everloot/everloot)",
           "credit": d.get("credit"), "build": (d.get("build") or {}).get("version"),
           "instances": {k: [[e["id"], e["name"]] for e in v] for k, v in d["instances"].items()}}
    os.makedirs(os.path.dirname(ENCOUNTERS), exist_ok=True)
    with open(ENCOUNTERS, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=0, sort_keys=True)
    print("%d instances, %d rencontres (build %s) -> %s" % (len(out["instances"]),
          sum(len(v) for v in out["instances"].values()), out["build"], ENCOUNTERS))


def do_import_wago(src, build=None):
    import csv

    def rows(name):
        with open(os.path.join(src, name), encoding="utf-8") as f:
            return {r["ID"]: r for r in csv.DictReader(f)}
    men, mfr = rows("Map-enUS.csv"), rows("Map-frFR.csv")
    een, efr = rows("DungeonEncounter-enUS.csv"), rows("DungeonEncounter-frFR.csv")
    maps = {i: [r["MapName_lang"], (mfr.get(i) or {}).get("MapName_lang"), int(r.get("InstanceType") or 0)]
            for i, r in men.items() if r.get("InstanceType") in ("1", "2")}
    encs = {i: [int(r["MapID"]), int(r.get("OrderIndex") or 0), r["Name_lang"], (efr.get(i) or {}).get("Name_lang")]
            for i, r in een.items()}
    out = {"source": "wago.tools (tables du client WoW Forever)", "build": build, "maps": maps, "encounters": encs}
    os.makedirs(os.path.dirname(WAGO), exist_ok=True)
    with open(WAGO, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=0, sort_keys=True)
    print("%d instances, %d rencontres (build %s) -> %s" % (len(maps), len(encs), build, WAGO))


def _norm(x):
    return re.sub(r"[^a-z0-9]", "", re.sub(r"^the ", "", (x or "").lower()))


def generate(root):
    import lupa
    with open(CACHE, encoding="utf-8") as f:
        pages = json.load(f)
    encounters = {}
    if os.path.exists(ENCOUNTERS):
        with open(ENCOUNTERS, encoding="utf-8") as f:
            encounters = json.load(f)["instances"]
    # tables du jeu (wago.tools) : instances et rencontres, avec leurs noms français (prioritaires)
    wago_maps, enc_fr, enc_order = {}, {}, {}
    if os.path.exists(WAGO):
        with open(WAGO, encoding="utf-8") as f:
            wg = json.load(f)
        wago_maps = wg["maps"]
        byMap = {}
        for eid, (mid, order_, en, frn) in wg["encounters"].items():
            byMap.setdefault(str(mid), []).append((order_, int(eid), en))
            enc_fr[int(eid)] = frn
            enc_order[int(eid)] = order_
        for mid, lst in byMap.items():
            encounters[mid] = [[eid, en] for _, eid, en in sorted(lst)]

    def words(x):
        return {w for w in re.findall(r"[a-z']+", (x or "").lower().replace("’", "'")) if len(w) >= 4 and w not in ("the", "and")}

    def encounter_of(inst, name):
        """N° de rencontre du boss : nom anglais exact (ou l'une des parties de « A / B », « A and B »),
        sinon la seule rencontre de l'instance qui partage un mot du nom (« War Handler Ashka » / « Handler Ashka »)."""
        if not inst:
            return 0
        parts = [name] + name.split(" / ") + re.split(r" and | & ", name)
        keys = {_norm(p) for p in parts if p}
        lst = encounters.get(str(inst), [])
        for eid, ename in lst:
            if _norm(ename) in keys:
                return eid
        w = words(name)
        hits = [eid for eid, ename in lst if w & words(ename)]
        return hits[0] if len(hits) == 1 else 0

    def wago_inst(en_name, boss_names):
        """N° d'instance d'un donjon sans n° connu : par son nom anglais dans les tables du jeu, sinon l'instance
        dont les rencontres portent le plus de noms de ses boss."""
        n = _norm(en_name)
        for mid, (en, frn, kind) in wago_maps.items():
            if _norm(en) == n:
                return int(mid)
        best, bh = None, 0
        names = {_norm(b) for b in boss_names}
        for mid, lst in encounters.items():
            h = sum(1 for _, en in lst if _norm(en) in names)
            if h > bh:
                best, bh = int(mid), h
        return best if bh >= 2 else None
    L = lupa.LuaRuntime(unpack_returned_tuples=True)
    L.execute('QDB={}; ZDB={private={}}; L10N={npcNameLookup={}}\nGetLocale=function() return "frFR" end\nloadstring=load\n'
              'UnitFactionGroup=function() return "Alliance" end\n'
              'QuestieLoader={ImportModule=function(_,n) if n=="ZoneDB" then return ZDB elseif n=="l10n" then return L10N end return QDB end}')

    def run(rel):
        with open(os.path.join(root, rel), encoding="utf-8") as fh:
            L.execute(fh.read())
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

    alt, entrance = {}, {}
    with open(os.path.join(root, "support/Forever/Zones/dungeons.lua"), encoding="utf-8") as f:
        for line in f:
            m = re.match(r'\s*\[(\d+)\] = \{"[^"]*",(nil|\{[\d,]*\}),(\d+),\{\{(\d+), ([\d.]+), ([\d.]+)\}', line)
            if m:
                area = int(m.group(1))
                alt[area] = [int(a) for a in re.findall(r"\d+", m.group(2))] if m.group(2) != "nil" else []
                if area not in entrance:
                    entrance[area] = (int(m.group(4)), float(m.group(5)), float(m.group(6)))

    # PNJ par nom anglais (minuscules) : [(id, zone, niveau min, niveau max, rang)]
    by_name = {}
    for nid, n in npcs.items():
        if n[1]:
            by_name.setdefault(n[1].lower(), []).append((nid, n[9], n[4] or 0, n[5] or 0, n[6] or 0))
    # recettes et qui les lâche
    recipe_droppers = {}
    for iid, it in items.items():
        if it[12] == 9 and it[2]:
            ds = [it[2][k] for k in range(1, len(it[2]) + 1)]
            if len(ds) <= MAX_DROPPERS:
                for nid in ds:
                    recipe_droppers.setdefault(nid, []).append(iid)

    def match(name, zones):
        # « Grand Crusader Dathrohan / Balnazzar » : le PNJ qu'on tue en dernier
        name = name.split(" / ")[-1]
        cands = by_name.get(name.lower(), [])
        inzone = [c for c in cands if c[1] in zones]
        pick = inzone or [c for c in cands if c[4] >= 1] or cands
        if not pick:
            return None
        pick.sort(key=lambda c: (-c[4], -c[3]))
        return pick[0]

    def s(x):
        return '"' + x.replace("\\", "\\\\").replace('"', '\\"') + '"' if x else "nil"

    merged, order = {}, []
    for slug, (key, inst, name, wing, raid) in DUNGEONS.items():
        p = pages.get(slug)
        if not p:
            continue
        d = merged.get(key)
        if not d:
            d = {"key": key, "inst": inst, "name": name, "en": p["name"], "min": p["levels"][0], "max": p["levels"][1],
                 "raid": raid, "bosses": [], "trash": [], "zones": sorted(set([key] + alt.get(key, [])))}
            if wing:
                d["en"] = re.sub(r":.*$", "", p["name"])
            merged[key] = d
            order.append(key)
        d["min"], d["max"] = min(d["min"], p["levels"][0]), max(d["max"], p["levels"][1])
        for b in p["bosses"]:
            d["bosses"].append((b, wing))
        d["trash"] += [i for i in p["trash"] if i not in d["trash"]]
        d.setdefault("items", {}).update(p["items"])

    # n° d'instance et nom français repris des tables du jeu quand ils manquent
    named_from_game = 0
    for key, d in merged.items():
        if not d["inst"]:
            d["inst"] = wago_inst(d["en"], [b["name"] for b, _ in d["bosses"]])
        wm = d["inst"] and wago_maps.get(str(d["inst"]))
        if wm and wm[1] and d["name"] == d["en"]:
            d["name"] = wm[1].replace("’", "'")
            named_from_game += 1

    lines = [
        "-- FICHIER GÉNÉRÉ par tools/gen_dungeons.py : ne pas modifier à la main.",
        "-- Donjons et raids de WoW Forever : boss, butin de chacun et des monstres du donjon.",
        "-- Butin : tables de butin WoW Forever de wowtbc.gg (https://wowtbc.gg/warcraftforever/loot-tables/dungeons/).",
        "-- N° et niveau des boss, noms français, entrées, recettes : QuestieDB (https://github.com/Questie/QuestieDB),",
        "-- base de données de l'addon Questie, sous la licence de Questie (GPLv3 selon son équipe).",
        "-- WK.DungeonsDB = { { key, inst (n° d'instance ou nil), name, en (nom anglais), min, max, raid, zones,",
        "--   entry = { uiMapID, x, y }, trash = { objet, ... },",
        "--   bosses = { { id (PNJ, 0 si inconnu), nom, nom fr, niveau, { objet, ... }, aile, rencontre (0 si inconnue) }, ... } }, ... }",
        "-- N° des rencontres (ENCOUNTER_END), n° d'instance du nouveau contenu, noms français des donjons et des boss :",
        "-- tables du client WoW Forever (données du jeu, lues sur wago.tools ; à défaut, catalogue d'Everloot).",
        "-- WK.DungeonItems[objet] = { qualité, niveau d'objet, niveau requis, % de drop ou nil, pas encore vu tomber }",
        "local ADDON_NAME, WK = ...",
        "WK.DungeonsDB = {",
    ]
    all_items = {}
    tb = ti = unmatched = matched_enc = 0
    order.sort(key=lambda k: (merged[k]["raid"], merged[k]["min"], merged[k]["max"]))
    for key in order:
        d = merged[key]
        e = entrance.get(key)
        entry = "nil"
        if e and amap[e[0]]:
            entry = "{%d,%g,%g}" % (amap[e[0]], e[1], e[2])
        lines.append("{key=%d,inst=%s,name=%s,en=%s,min=%d,max=%d,raid=%s,zones={%s},entry=%s,trash={%s},bosses={" % (
            key, str(d["inst"]) if d["inst"] else "nil", s(d["name"]), s(d["en"]), d["min"], d["max"],
            "true" if d["raid"] else "false", ",".join(str(z) for z in d["zones"]), entry, ",".join(str(i) for i in d["trash"])))
        # ordre du jeu (DungeonEncounter.OrderIndex) : les boss à n° de rencontre sont rangés entre eux,
        # aile par aile, sur les places qu'ils occupent ; les autres (rares, facultatifs) ne bougent pas
        bl = list(d["bosses"])
        encs = [encounter_of(d["inst"], b["name"]) for b, _ in bl]
        for wg_ in {w for _, w in bl}:
            idx = [i for i, (_, w) in enumerate(bl) if w == wg_ and encs[i] and encs[i] in enc_order]
            srt = sorted(idx, key=lambda i: (enc_order[encs[i]], i))
            moved = [bl[i] for i in srt]
            for i, x in zip(idx, moved):
                bl[i] = x
        for b, wing in bl:
            m = match(b["name"], d["zones"])
            nid, lvl, nmfr = 0, 0, None
            loot = list(b["items"])
            if m:
                nid, lvl = m[0], m[3]
                f = fr[nid] if fr else None
                nmfr = f[1] if f else None
                for r in recipe_droppers.get(nid, []):
                    if r not in loot:
                        loot.append(r)
            else:
                unmatched += 1
            enc = encounter_of(d["inst"], b["name"])
            if enc:
                matched_enc += 1
                if enc_fr.get(enc):
                    nmfr = enc_fr[enc].replace("\u2019", "'")  # nom français officiel du jeu
            lines.append("{%d,%s,%s,%d,{%s},%s,%d}," % (nid, s(b["name"]), s(nmfr), lvl, ",".join(str(i) for i in loot), s(wing), enc))
            tb += 1
            ti += len(loot)
        lines.append("}},")
        all_items.update(d.get("items", {}))
    lines.append("}")
    lines.append("WK.DungeonItems = {")
    for iid in sorted(all_items, key=int):
        g = all_items[iid]
        drop = g.get("drop")
        lines.append("[%s]={%d,%d,%d,%s%s}," % (iid, g["q"], g["ilvl"], g["req"],
                                               ("%g" % drop) if isinstance(drop, (int, float)) else "nil",
                                               "" if g["found"] else ",true"))
    lines.append("}")
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("%d donjons et raids, %d boss (%d sans n° de PNJ, %d avec n° de rencontre), %d objets -> %s (%d Ko)" % (
        len(order), tb, unmatched, matched_enc, ti, os.path.normpath(OUT), os.path.getsize(OUT) // 1024))


if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "--import":
        do_import(sys.argv[2])
    elif len(sys.argv) >= 3 and sys.argv[1] == "--import-wago":
        do_import_wago(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
    elif len(sys.argv) >= 3 and sys.argv[1] == "--import-encounters":
        do_import_encounters(sys.argv[2])
    elif len(sys.argv) >= 2 and not sys.argv[1].startswith("-"):
        generate(sys.argv[1])
    else:
        print(__doc__)
        sys.exit(1)
