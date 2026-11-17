#!/usr/bin/env python3
"""Génère Modules/EverlootDB.lua depuis l'export de données ouvertes d'Everloot (https://everloot.app).

Usage : python3 tools/gen_everloot.py --fetch            télécharge le dernier export dans tools/.cache/everloot-data
        python3 tools/gen_everloot.py <clone de QuestieDB> [dossier de l'export]

L'export (https://data.everloot.app/open-data/latest.json) a deux parties :
  - observed/ : ce que 3 joueurs au moins ont vu en jeu, sous licence CC BY-SA 4.0 (« Data from Everloot
    (https://everloot.app), CC BY-SA 4.0. ») : ici les taux de drop (drop-rates.ndjson, sources PNJ) ;
  - game-files/ : ce que disent les fichiers du jeu (données de Blizzard, hors licence d'Everloot) : ici les
    maîtres de vol et les trajets de vol réels (flight-masters, flight-paths).
Le fichier généré garde les deux mentions ; ses taux de drop restent sous CC BY-SA 4.0.
Noms des PNJ : QuestieDB (français si connu, GPLv3), sinon le nom vu par les joueurs (Everloot).
"""
import json
import os
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "Modules", "EverlootDB.lua")
CACHE = os.path.join(HERE, ".cache", "everloot-data")
BASE = "https://data.everloot.app/"
FILES = ["observed/drop-rates", "observed/npcs", "game-files/flight-masters", "game-files/flight-paths"]
UA = "WarbandKeeper-data-update"
MIN_WINDOWS = 3  # un taux sur moins de 3 butins ne dit rien


def fetch(dest=CACHE):
    def get(path):
        req = urllib.request.Request(BASE + path, headers={"User-Agent": UA})
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.read()
    latest = json.loads(get("open-data/latest.json"))
    folder = latest["manifest"].rsplit("/", 1)[0]
    os.makedirs(os.path.join(dest, "observed"), exist_ok=True)
    os.makedirs(os.path.join(dest, "game-files"), exist_ok=True)
    manifest = get(latest["manifest"])
    with open(os.path.join(dest, "manifest.json"), "wb") as f:
        f.write(manifest)
    for name in FILES:
        with open(os.path.join(dest, name + ".ndjson"), "wb") as f:
            f.write(get(folder + "/" + name + ".ndjson"))
    print("export Everloot du", json.loads(manifest).get("dataAsOf"), "->", dest)
    return dest


def rows(folder, name):
    p = os.path.join(folder, name + ".ndjson")
    if not os.path.exists(p):
        return []
    with open(p, encoding="utf-8") as f:
        return [json.loads(l) for l in f if l.strip()]


def npc_names(root):
    """Noms des PNJ de QuestieDB : { id: (anglais, français) }."""
    if not root:
        return {}
    import lupa
    L = lupa.LuaRuntime(unpack_returned_tuples=True)
    L.execute('QDB={}; L10N={npcNameLookup={}}\nGetLocale=function() return "frFR" end\nloadstring=load\n'
              'QuestieLoader={ImportModule=function(_,n) if n=="l10n" then return L10N end return QDB end}')
    for rel in ("data/Forever/foreverNpcDB.lua", "l10n/Forever/lookupNpcs/frFR.lua"):
        with open(os.path.join(root, rel), encoding="utf-8") as f:
            L.execute(f.read())
    npcs = L.execute("return load(QDB.npcData)()")
    fr = L.globals().L10N.npcNameLookup["frFR"]
    if lupa.lua_type(fr) == "function":
        fr = fr()
    out = {}
    for nid, n in npcs.items():
        f = fr[nid] if fr else None
        out[int(nid)] = (n[1], f[1] if f else None)
    return out


def generate(root, folder=CACHE):
    with open(os.path.join(folder, "manifest.json"), encoding="utf-8") as f:
        manifest = json.load(f)
    names = npc_names(root)
    seen = {r["npcId"]: r.get("name") for r in rows(folder, "observed/npcs")}

    def s(x):
        return '"' + x.replace("\\", "\\\\").replace('"', '\\"') + '"' if x else "nil"

    # taux de drop par objet : PNJ sources, du plus fréquent au moins fréquent
    drops = {}
    for r in rows(folder, "observed/drop-rates"):
        if r.get("sourceNpcId") and r["lootWindows"] >= MIN_WINDOWS:
            drops.setdefault(r["itemId"], []).append((r["sourceNpcId"], r["rate"], r["lootWindows"]))
    used = set()
    lines = [
        "-- FICHIER GÉNÉRÉ par tools/gen_everloot.py : ne pas modifier à la main.",
        "-- Taux de drop observés par les joueurs : Data from Everloot (https://everloot.app), CC BY-SA 4.0",
        "-- (https://creativecommons.org/licenses/by-sa/4.0/) ; ces taux restent sous cette licence.",
        "-- Export du %s, %d relevés de %d installations ; un fait n'y figure que si 3 joueurs au moins l'ont vu."
        % ((manifest.get("dataAsOf") or "")[:10], (manifest.get("source") or {}).get("records", 0),
           (manifest.get("source") or {}).get("installs", 0)),
        "-- Maîtres et trajets de vol : fichiers du jeu (Game data © Blizzard Entertainment, Inc., lus par Everloot,",
        "-- version %s) ; noms des PNJ : QuestieDB (GPLv3) ou Everloot." % ((manifest.get("gameFiles") or {}).get("version")),
        "-- WK.EverDrops[objet] = { pnj, taux en pour mille, butins observés, pnj, taux, butins, ... }",
        "-- WK.EverNpcs[pnj] = { nom anglais, nom français }",
        "-- WK.FlightGame = { nodes = { [n°] = { continent, x, y } }, paths = { [\"a-b\"] = { x, y, ... } } }",
        "local ADDON_NAME, WK = ...",
        "WK.EverlootAsOf = %s" % s((manifest.get("dataAsOf") or "")[:10]),
        "WK.EverDrops = {",
    ]
    nd = 0
    for item in sorted(drops):
        src = sorted(drops[item], key=lambda x: -x[1])[:4]
        parts = []
        for npc, rate, win in src:
            parts += [str(npc), str(int(round(rate * 1000))), str(win)]
            used.add(npc)
        lines.append("[%d]={%s}," % (item, ",".join(parts)))
        nd += 1
    lines.append("}")
    lines.append("WK.EverNpcs = {")
    for npc in sorted(used):
        en, fr = names.get(npc, (seen.get(npc), None))
        lines.append("[%d]={%s,%s}," % (npc, s(en or seen.get(npc)), s(fr)))
    lines.append("}")
    lines.append("WK.FlightGame = { nodes = {")
    for n in sorted(rows(folder, "game-files/flight-masters"), key=lambda r: r["id"]):
        lines.append("[%d]={%d,%d,%d}," % (n["id"], n["continentId"], round(n["worldX"]), round(n["worldY"])))
    lines.append("}, paths = {")
    npaths = 0
    for p in rows(folder, "game-files/flight-paths"):
        pts = [str(round(v)) for xy in p["points"] for v in xy]
        lines.append('["%d-%d"]={%s},' % (p["from"], p["to"], ",".join(pts)))
        npaths += 1
    lines.append("} }")
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("%d objets avec taux de drop (%d PNJ), %d trajets de vol -> %s (%d Ko)" % (
        nd, len(used), npaths, os.path.normpath(OUT), os.path.getsize(OUT) // 1024))


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "--fetch":
        fetch()
    elif len(sys.argv) >= 2:
        generate(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else CACHE)
    else:
        print(__doc__)
        sys.exit(1)
