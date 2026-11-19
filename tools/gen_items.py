#!/usr/bin/env python3
"""Génère Modules/ItemsDB.lua : objets portables de WoW Forever (qualité verte et plus) pour la liste BiS.

Sources :
  - opendata de wowlayerup-forever (https://github.com/wowlayerup-forever/opendata), données sous licence
    CC BY 4.0 : data/client/items.jsonl (emplacement, type, qualité, niveaux, caractéristiques),
    quests.jsonl (récompenses de quêtes), recipes.jsonl (objets fabriqués) ;
  - noms français : table ItemSparse du client en français (wago.tools), facultative.

Usage : python3 tools/gen_items.py <clone d'opendata> [ItemSparse-frFR.csv]
"""
import csv
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Modules", "ItemsDB.lua")
LOADER = r'''function WK.LoadItemsDB()
    if WK.ItemsDB then return WK.ItemsDB end
    local out, raw = {}, WK.ItemsDBRaw or ""
    for line in raw:gmatch("[^\n]+") do
        local id, slot, cls, sub, q, ilvl, req, name, stats, src = line:match("^(%d+)\t([^\t]*)\t(%d+)\t(%d+)\t(%d+)\t(%d+)\t(%d+)\t([^\t]*)\t([^\t]*)\t([^\t]*)$")
        if id then
            out[#out + 1] = { tonumber(id), slot, tonumber(cls), tonumber(sub), tonumber(q), tonumber(ilvl), tonumber(req), name, stats, src }
        end
    end
    WK.ItemsDB, WK.ItemsDBRaw = out, nil
    return out
end
'''

# type d'emplacement du jeu » groupe d'emplacement de la liste BiS
SLOT = {1: "head", 2: "neck", 3: "shoulder", 16: "back", 5: "chest", 20: "chest", 9: "wrist", 10: "hands",
        6: "waist", 7: "legs", 8: "feet", 11: "finger", 12: "trinket", 13: "one", 17: "two", 21: "main",
        14: "off", 22: "off", 23: "off", 15: "ranged", 25: "ranged", 26: "ranged", 28: "ranged"}
STATS = [("strength", "For"), ("agility", "Agi"), ("stamina", "End"), ("intellect", "Int"), ("spirit", "Esp"),
         ("attack_power", "PA"), ("ranged_attack_power", "PA dist."), ("spell_power", "Puiss. sorts"),
         ("spell_damage", "Dégâts sorts"), ("spell_healing", "Soins"), ("crit_rating", "Crit."),
         ("hit_rating", "Toucher"), ("defense_rating", "Déf."), ("dodge_rating", "Esquive"),
         ("block_rating", "Blocage"), ("mana_regen", "Mana/5"), ("bonus_armor", "Armure"),
         ("fire_resistance", "Rés. feu"), ("frost_resistance", "Rés. givre"), ("nature_resistance", "Rés. nature"),
         ("shadow_resistance", "Rés. ombre"), ("arcane_resistance", "Rés. arcanes")]


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ") + '"'


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    od = sys.argv[1]
    client = os.path.join(od, "data", "client")
    fr = {}
    if len(sys.argv) > 2 and os.path.exists(sys.argv[2]):
        with open(sys.argv[2], encoding="utf-8", newline="") as f:
            for row in csv.DictReader(f):
                name = (row.get("Display_lang") or "").strip()
                if name:
                    fr[int(row["ID"])] = name
    # sources : quêtes (récompense ou choix) et artisanat (métier, compétence)
    src = {}
    with open(os.path.join(client, "quests.jsonl"), encoding="utf-8") as f:
        for line in f:
            q = json.loads(line)
            rw = q.get("rewards") or {}
            for key in ("items", "choice_items"):
                for it in rw.get(key) or []:
                    src.setdefault(it["item_id"], "q%d" % q["quest_id"])
    with open(os.path.join(client, "recipes.jsonl"), encoding="utf-8") as f:
        for line in f:
            r = json.loads(line)
            cr = r.get("creates") or {}
            if cr.get("item_id"):
                src.setdefault(cr["item_id"], "c%d:%d" % (r.get("skill_id") or 0, r.get("skill_required") or 0))
    items = []
    with open(os.path.join(client, "items.jsonl"), encoding="utf-8") as f:
        for line in f:
            d = json.loads(line)
            if d.get("item_class") not in (2, 4) or (d.get("quality") or 0) < 2:
                continue
            slot = SLOT.get(d.get("inventory_type") or 0)
            if not slot:
                continue
            st = d.get("stats") or {}
            parts = ["%s +%d" % (lab, st[k]) for k, lab in STATS if isinstance(st.get(k), (int, float)) and st[k]]
            name = fr.get(d["item_id"]) or d.get("name") or ""
            items.append((d["item_id"], slot, d["item_class"], d.get("item_subclass") or 0, d.get("quality") or 2,
                          d.get("item_level") or 0, d.get("required_level") or 0, name, " · ".join(parts[:5]),
                          src.get(d["item_id"], "")))
    items.sort()
    with open(OUT, "w", encoding="utf-8", newline="\n") as o:
        o.write("-- FICHIER GÉNÉRÉ par tools/gen_items.py : ne pas modifier à la main.\n")
        o.write("-- Objets portables de WoW Forever (qualité verte et plus), pour la liste BiS.\n")
        o.write("-- Données : wowlayerup-forever/opendata (https://github.com/wowlayerup-forever/opendata), licence CC BY 4.0,\n")
        o.write("-- reprises et réduites ; noms français : table ItemSparse du client (wago.tools).\n")
        o.write("-- WK.LoadItemsDB() rend WK.ItemsDB = { { n°, groupe d'emplacement, classe, sous-classe, qualité, niveau d'objet, niveau requis,\n")
        o.write("--   nom, caractéristiques, source (\"q<quête>\", \"c<métier>:<compétence>\" ou \"\") }, ... }\n")
        # une ligne par objet, champs séparés par des tabulations, dans une seule chaîne : décodée à la
        # première ouverture de la liste BiS (bien plus léger en mémoire qu'une table par objet)
        o.write("-- Chargé à la demande (WK.LoadItemsDB) : une seule chaîne tant que la liste BiS n'est pas ouverte.\n")
        o.write("local ADDON_NAME, WK = ...\nWK.ItemsDBRaw = [==[\n")
        for it in items:
            for v in it:
                if isinstance(v, str):
                    assert "\t" not in v and "\n" not in v and "]==]" not in v, v
            o.write("%d\t%s\t%d\t%d\t%d\t%d\t%d\t%s\t%s\t%s\n" % it)
        o.write("]==]\n" + LOADER)
    print("ItemsDB.lua : %d objets (%d noms français), %d Ko" % (len(items), sum(1 for i in items if i[0] in fr),
                                                               os.path.getsize(OUT) // 1024))


if __name__ == "__main__":
    main()
