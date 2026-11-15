"""Génère Modules/PlacesDB.lua : boîtes aux lettres, banquiers, marchands (avec ce qu'ils vendent)
et maîtres de classe de WoW Forever, tirés de la base de données QuestieDB.

Source : https://github.com/Questie/QuestieDB (données Questie, voir sa licence : GPLv3 selon
l'équipe Questie). Seules les positions et les rôles sont repris, sous forme allégée.

Usage : python3 tools/gen_places.py <chemin d'un clone de QuestieDB>
  (git clone --depth 1 https://github.com/Questie/QuestieDB)
Dépendance : lupa (pip install lupa).
"""
import os
import sys

import lupa.lua54 as lupa

OUT = os.path.join(os.path.dirname(__file__), "..", "Modules", "PlacesDB.lua")

# npcFlags (client Classic) et rôles retenus
VENDOR, TRAINER, BANKER, STABLE, REPAIR = 4, 16, 256, 8192, 16384
# Bits de l'addon
K = {"mail": 1, "bank": 2, "vendor": 4, "repair": 8, "ammo": 16, "reagent": 32, "poison": 64, "trainer": 128, "general": 256, "stable": 512, "fishing": 1024}
CLASSES = {
    "Warrior Trainer": "WARRIOR", "Paladin Trainer": "PALADIN", "Hunter Trainer": "HUNTER", "Rogue Trainer": "ROGUE",
    "Priest Trainer": "PRIEST", "Shaman Trainer": "SHAMAN", "Mage Trainer": "MAGE", "Warlock Trainer": "WARLOCK",
    "Druid Trainer": "DRUID",
}
AMMO_WORDS = ("bowyer", "gunsmith", "ammo", "arrow", "bullet", "bow merchant", "gun merchant", "general goods", "general supplies")
SEASONAL_WORDS = ("smokywood", "holiday", "festival", "darkmoon", "fireworks", "brewfest", "hallow", "lunar", "midsummer")
GENERAL_WORDS = ("general goods", "general supplies", "trade supplies", "trade supplier", "tradesman", "trade goods")


def kinds_of(npc):
    flags = npc[15] or 0
    sub = (npc[14] or "")
    low = sub.lower()
    k, cls = 0, None
    if any(w in low for w in SEASONAL_WORDS):
        return 0, None  # marchands saisonniers (fêtes, foire de Sombrelune) : pas toute l'année
    if flags & BANKER:
        k |= K["bank"]
    if flags & REPAIR:
        k |= K["repair"]
    if flags & STABLE:
        k |= K["stable"]
    if flags & VENDOR:
        k |= K["vendor"]
        if any(w in low for w in AMMO_WORDS):
            k |= K["ammo"]
        if "reagent" in low:
            k |= K["reagent"]
        if "poison" in low:
            k |= K["poison"]
        if any(w in low for w in GENERAL_WORDS):
            k |= K["general"]
        if "fishing" in low or "fisherman" in low:
            k |= K["fishing"]  # fournitures de pêche : vend des cannes et des appâts
    if flags & TRAINER and sub in CLASSES:
        k |= K["trainer"]
        cls = CLASSES[sub]
    return k, cls


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


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
    run("data/Forever/foreverObjectDB.lua")
    run("support/Forever/Zones/areaIdToUiMapId.lua")
    run("l10n/Forever/lookupNpcs/frFR.lua")
    npcs = L.execute("return load(QDB.npcData)()")
    objs = L.execute("return load(QDB.objectData)()")
    amap = L.execute("return load(ZDB.private.areaIdToUiMapId)()")
    fr = L.globals().L10N.npcNameLookup["frFR"]
    if lupa.lua_type(fr) == "function":
        fr = fr()

    per_map = {}

    def add(area, coords, kind, cls, fac, name_en, name_fr, sub_fr):
        ui = amap[area]
        if not ui:
            return
        for i in range(1, len(coords) + 1):
            c = coords[i]
            x, y = c[1], c[2]
            if x is None or y is None or x < 0 or y < 0:
                continue
            per_map.setdefault(ui, []).append((round(x, 1), round(y, 1), kind, cls, fac, name_en, name_fr, sub_fr))

    n_npc = 0
    for nid, npc in npcs.items():
        kind, cls = kinds_of(npc)
        if not kind or not npc[7]:
            continue
        fac = npc[13]
        if not fac:  # hostile aux deux factions
            continue
        f = fr[nid] if fr else None
        name_fr = f[1] if f else None
        sub_fr = f[2] if f else None
        n_npc += 1
        for area, coords in npc[7].items():
            add(area, coords, kind, cls, fac if fac in ("A", "H") else None, npc[1], name_fr, sub_fr)
    n_mail = 0
    for oid, o in objs.items():
        if (o[1] or "").lower() != "mailbox" or not o[4]:
            continue
        n_mail += 1
        for area, coords in o[4].items():
            add(area, coords, K["mail"], None, None, None, None, None)

    lines = [
        "-- FICHIER GÉNÉRÉ par tools/gen_places.py : ne pas modifier à la main.",
        "-- Lieux utiles de WoW Forever : boîtes aux lettres, banquiers, marchands et maîtres de classe.",
        "-- Données tirées de QuestieDB (https://github.com/Questie/QuestieDB), base de données de l'addon",
        "-- Questie : positions et rôles seulement, sous la licence de Questie (GPLv3 selon son équipe).",
        "-- WK.PlacesDB[uiMapID] = { { x, y, genre (bits), classe, faction (\"A\"|\"H\"|nil), nom, nom fr, métier fr }, ... }",
        "-- Genres : 1 boîte aux lettres, 2 banque, 4 marchand, 8 réparation, 16 munitions, 32 composants,",
        "--          64 poisons, 128 maître de classe, 256 fournitures générales, 512 maître des écuries,",
        "--          1024 fournitures de pêche. x, y : 0-100.",
        "local ADDON_NAME, WK = ...",
        "WK.PlacesDB = {",
    ]
    total = 0
    for ui in sorted(per_map):
        lines.append("[%d] = {" % ui)
        seen = set()
        for x, y, kind, cls, fac, en, frn, sub in sorted(per_map[ui], key=lambda e: (e[0], e[1])):
            key = (x, y, kind, cls)
            if key in seen:
                continue
            seen.add(key)
            total += 1
            parts = ["%g" % x, "%g" % y, str(kind), lua_str(cls) if cls else "nil", lua_str(fac) if fac else "nil",
                     lua_str(en) if en else "nil", lua_str(frn) if frn and frn != en else "nil", lua_str(sub) if sub else "nil"]
            while parts[-1] == "nil":
                parts.pop()
            lines.append("{" + ",".join(parts) + "},")
        lines.append("},")
    lines.append("}")
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("%d PNJ, %d boîtes aux lettres, %d lieux sur %d cartes -> %s" % (n_npc, n_mail, total, len(per_map), OUT))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1])
