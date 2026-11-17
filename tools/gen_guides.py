#!/usr/bin/env python3
"""Génère Modules/Guides.lua (guides de montée des métiers) à partir des données
des guides WoW Forever de wowtbc.gg.

Usage :
  python3 tools/gen_guides.py                      # régénère depuis tools/guides/*.json
  python3 tools/gen_guides.py --import page.json   # importe un page-data.json du site

Le page-data.json d'un guide se télécharge à l'adresse
  https://wowtbc.gg/page-data/warcraftforever/professions/<métier>/page-data.json
L'import n'en garde que ce qui sert (parcours, maîtres, recettes utilisées).
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "guides")
OUT = os.path.join(ROOT, "Modules", "Guides.lua")
OUT_DB = os.path.join(ROOT, "Modules", "RecipeDB.lua")

# Nom du métier en jeu (français) pour chaque guide.
PROFS = {
    "Leatherworking": "Travail du cuir",
    "First Aid": "Secourisme",
    "Cooking": "Cuisine",
    "Tailoring": "Couture",
    "Blacksmithing": "Forge",
    "Alchemy": "Alchimie",
    "Enchanting": "Enchantement",
    "Engineering": "Ingénierie",
}
RANKS = {"Apprentice": "Apprenti", "Journeyman": "Compagnon", "Expert": "Expert", "Artisan": "Artisan"}
PLACES = {
    "Arathi Highlands": "Hautes-terres d'Arathi", "Ashenvale": "Orneval", "Darnassus": "Darnassus",
    "Desolace": "Désolace", "Dustwallow Marsh": "Marécage d'Âprefange", "Feralas": "Feralas",
    "Ironforge": "Forgefer", "Orgrimmar": "Orgrimmar", "Stormwind City": "Hurlevent",
    "The Hinterlands": "Les Hinterlands", "Thunder Bluff": "Les Pitons-du-Tonnerre", "Undercity": "Fossoyeuse",
    "Booty Bay": "Baie-du-Butin", "Elwynn Forest": "Forêt d'Elwynn", "Hillsbrad Foothills": "Contreforts de Hautebrande",
    "Stonetalon Mountains": "Les Serres-Rocheuses", "Swamp of Sorrows": "Marais des Chagrins", "Tanaris": "Tanaris",
    "Tirisfal Glades": "Clairières de Tirisfal", "Uldaman (Dungeon)": "Uldaman (donjon)",
    "Duswallow Marsh": "Marécage d'Âprefange",
}
# Outils achetés (les autres outils sont fabriqués par le parcours lui-même).
BOUGHT_TOOLS = {"Blacksmith Hammer": 5956}
# Zone des vendeurs de recettes (seulement ceux dont on est sûr ; les autres sans zone).
VENDOR_PLACES = {
    "Jase Farlane": "Maleterres de l'Est", "Blimo Gadgetspring": "Azshara",
    "Kelsey Yance": "Baie-du-Butin", "Stuart Fleming": "Les Paluns", "Heldan Galesong": "Sombrivage",
    "Tansy Puddlefizz": "Forgefer", "Shankys": "Orgrimmar", "Lindea Rabonne": "Contreforts de Hautebrande",
    "Derak Nightfall": "Contreforts de Hautebrande", "Kilxx": "Les Tarides", "Naal Mistrunner": "Les Pitons-du-Tonnerre",
    "Sewa Mistrunner": "Les Pitons-du-Tonnerre", "Ronald Burch": "Fossoyeuse", "Wulan": "Désolace",
    "Catherine Leland": "Hurlevent", "Xizzer Fizzbolt": "Berceau-de-l'Hiver", "Gearcutter Cogspinner": "Forgefer",
    "Mythrin'dir": "Darnassus", "Daniel Bartlett": "Fossoyeuse", "Kor'geld": "Orgrimmar", "Soolie Berryfizz": "Forgefer",
}
# Remarques des guides, traduites. {n:id} = n fois l'objet id ; {id} = l'objet id (nom pris dans le jeu).
NOTES = {
    "To raise your skill cap to 225, you will need to buy an Expert Cookbook for 1g. It can also be found on the Auction House.":
        "Pour monter le plafond à 225, achète le {16072} (1 po) ; il se trouve aussi à l'hôtel des ventes.",
    "Bring x12 Giant Egg, x10 Zesty Clam Meat, and x20 Alterac Swiss for the training quest.":
        "Apporte {12:12207}, {10:7974} et {20:8932} pour la quête de formation.",
    "Buy Manual: Heavy Silk Bandage and Manual: Mageweave Bandage while you're there.":
        "Achète au passage le {16112} et le {16113}.",
    "The trainer is inside Uldaman and will likely require a group to access if you're not 60.":
        "Le maître est dans Uldaman : il faudra sans doute un groupe pour y accéder si tu n'es pas niveau 60.",
}


def slim(page):
    """Garde du page-data.json le parcours, les maîtres et les recettes utilisées."""
    prof = page["result"]["pageContext"]["profession"]
    recipes = {r["id"]: r for c in prof["categories"] for r in c["recipes"]}
    used = set()
    for st in prof["leveling"]:
        used.add(st["recipe"])
        for f in st.get("first", []):
            used.add(f["recipe"])
    keep = {}
    for rid in used:
        r = recipes[rid]
        keep[str(rid)] = {
            "name": r["name"],
            "item": {"id": r["item"]["id"], "count": r["item"].get("count", 1)} if r.get("item") else None,
            "reagents": [{"id": g["id"], "name": g["name"], "count": g["count"], "price": g.get("price")}
                         for g in r["reagents"]],
            "source": r.get("source"),
            "tools": r.get("tools", []),
            "taught_by": [{"id": t["id"], "name": t["name"], "vendors": t.get("vendors") or [], "price": t.get("price")}
                          for t in r.get("taught_by", [])],
        }
    # Toutes les recettes du métier (pour « recettes manquantes »), en version courte.
    allr = []
    for r in recipes.values():
        t = (r.get("taught_by") or [{}])[0]
        allr.append({"id": r["id"], "out": r["item"]["id"] if r.get("item") else None, "learn": r.get("learn") or r["skill"][0],
                     "src": r.get("source"), "recipe": t.get("id"), "price": t.get("price"), "vendors": t.get("vendors") or []})
    allr.sort(key=lambda x: (x["learn"], x["id"]))
    return {"name": prof["name"], "leveling": prof["leveling"], "sections": prof["sections"], "all": allr,
            "craftedParts": prof.get("craftedParts", {}), "skillOnly": prof.get("skillOnly", []),
            "craftedTools": prof.get("craftedTools", {}), "recipes": keep}


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def gen():
    guides = []
    for f in sorted(os.listdir(SRC)):
        if f.endswith(".json"):
            guides.append(json.load(open(os.path.join(SRC, f), encoding="utf-8")))
    out = ["local ADDON_NAME, WK = ...", "",
           "-- Guides de montée des métiers de WoW Forever (d'après wowtbc.gg).",
           "-- FICHIER GÉNÉRÉ par tools/gen_guides.py : ne pas modifier à la main.",
           "-- steps : { from, to, crafts, out = objet fabriqué, qty, reagents = { {id, n par fabrication} },",
           "--           src = \"trainer\" | \"recipe\", learn = recette (objet), vendors = { {nom, zone?} },",
           "--           first = étapes à faire avant }",
           "-- spell = recette (sort : nom en jeu même sans objet fabriqué) ; tools = outils nécessaires (objets).",
           "-- skillOnly : objets fabriqués seulement pour monter (cuirs…) : il faut quand même s'en procurer.",
           "-- prices : prix de secours des composants (cuivre) quand ni le scan de l'HV ni le marchand n'en donnent.",
           "WK.Guides = {"]
    prices = {}
    for g in guides:
        name = PROFS.get(g["name"], g["name"])
        rec = g["recipes"]

        def step(rid, crafts):
            r = rec[str(rid)]
            for x in r["reagents"]:
                if x.get("price"):
                    prices[x["id"]] = x["price"]
            parts = ["crafts = %d" % crafts, "spell = %d" % rid]
            if r["item"]:
                parts.append("out = %d, qty = %d" % (r["item"]["id"], r["item"]["count"] or 1))
            parts.append("reagents = { " + ", ".join("{ %d, %d }" % (x["id"], x["count"]) for x in r["reagents"]) + " }")
            parts.append("src = %s" % lua_str(r["source"] or "trainer"))
            tool_ids = []
            for t in r.get("tools", []):
                if t in BOUGHT_TOOLS:
                    tool_ids.append(BOUGHT_TOOLS[t])
                elif t in g.get("craftedTools", {}):
                    tr = rec.get(str(g["craftedTools"][t]))
                    if tr and tr["item"]:
                        tool_ids.append(tr["item"]["id"])
                else:
                    sys.exit("Outil inconnu (à ajouter dans BOUGHT_TOOLS) : " + t)
            if tool_ids:
                parts.append("tools = { " + ", ".join(str(i) for i in tool_ids) + " }")
            if r["taught_by"]:
                t = r["taught_by"][0]
                if t.get("price"):
                    prices[t["id"]] = t["price"]
                parts.append("learn = %d" % t["id"])
                if t["vendors"]:
                    vs = []
                    for v in t["vendors"]:
                        place = VENDOR_PLACES.get(v)
                        vs.append("{ %s, %s }" % (lua_str(v), lua_str(place)) if place else "{ %s }" % lua_str(v))
                    parts.append("vendors = { " + ", ".join(vs) + " }")
            return parts

        out.append("    [%s] = {" % lua_str(name))
        out.append("        en = %s," % lua_str(g["name"]))
        if g.get("skillOnly"):
            out.append("        skillOnly = { " + ", ".join("[%d] = true" % i for i in g["skillOnly"]) + " },")
        out.append("        sections = {")
        for s in g["sections"]:
            t = s.get("trainers") or {}
            line = "            { rank = %s, from = %d, to = %d" % (lua_str(RANKS.get(s["rank"], s["rank"])), s["skill"][0], s["skill"][1])
            for fac in ("alliance", "horde"):
                if t.get(fac):
                    line += ", %s = { %s }" % (fac, ", ".join("{ %s, %s }" % (lua_str(n["npc"]), lua_str(PLACES.get(n["location"], n["location"]))) for n in t[fac]))
            if t.get("note"):
                if t["note"] not in NOTES:
                    sys.exit("Remarque sans traduction dans NOTES : " + t["note"])
                line += ", note = %s" % lua_str(NOTES[t["note"]])
            out.append(line + " },")
        out.append("        },")
        out.append("        steps = {")
        for st in g["leveling"]:
            parts = ["from = %d, to = %d" % (st["skill"][0], st["skill"][1])] + step(st["recipe"], st["crafts"])
            if st.get("first"):
                firsts = ["{ " + ", ".join(step(f["recipe"], f["crafts"])) + " }" for f in st["first"]]
                parts.append("first = { " + ", ".join(firsts) + " }")
            out.append("            { " + ", ".join(parts) + " },")
        out.append("        },")
        out.append("    },")
    out.append("}")
    out.append("")
    out.append("WK.GuidePrices = {")
    for i in sorted(prices):
        out.append("    [%d] = %d," % (i, prices[i]))
    out.append("}")
    open(OUT, "w", encoding="utf-8").write("\n".join(out) + "\n")
    print("écrit", OUT, "(%d guides)" % len(guides))
    gen_db(guides)


def gen_db(guides):
    """Modules/RecipeDB.lua : toutes les recettes de chaque métier (recettes manquantes)."""
    out = ["local ADDON_NAME, WK = ...", "",
           "-- Toutes les recettes des métiers de WoW Forever (d'après wowtbc.gg), pour les recettes manquantes.",
           "-- FICHIER GÉNÉRÉ par tools/gen_guides.py : ne pas modifier à la main.",
           "-- s = recette (sort), o = objet fabriqué, l = niveau pour l'apprendre, t = 1 si elle s'apprend chez le maître,",
           "-- r = objet de recette (à trouver ou acheter), p = prix chez le vendeur (cuivre), v = vendeurs.",
           "WK.RecipeDB = {"]
    n = 0
    for g in guides:
        name = PROFS.get(g["name"], g["name"])
        out.append("    [%s] = {" % lua_str(name))
        for r in g.get("all", []):
            parts = ["s = %d" % r["id"], "l = %d" % r["learn"]]
            if r["out"]:
                parts.append("o = %d" % r["out"])
            if r["src"] == "trainer":
                parts.append("t = 1")
            if r["recipe"]:
                parts.append("r = %d" % r["recipe"])
            if r["price"]:
                parts.append("p = %d" % r["price"])
            if r["vendors"]:
                vs = []
                for v in r["vendors"]:
                    place = VENDOR_PLACES.get(v)
                    vs.append("{ %s, %s }" % (lua_str(v), lua_str(place)) if place else "{ %s }" % lua_str(v))
                parts.append("v = { " + ", ".join(vs) + " }")
            out.append("        { " + ", ".join(parts) + " },")
            n += 1
        out.append("    },")
    out.append("}")
    open(OUT_DB, "w", encoding="utf-8").write("\n".join(out) + "\n")
    print("écrit", OUT_DB, "(%d recettes)" % n)


if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "--import":
        os.makedirs(SRC, exist_ok=True)
        for path in sys.argv[2:]:
            data = slim(json.load(open(path, encoding="utf-8")))
            key = data["name"].lower().replace(" ", "-")
            json.dump(data, open(os.path.join(SRC, key + ".json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
            print("importé", data["name"])
    gen()
