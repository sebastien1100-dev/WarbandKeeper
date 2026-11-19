#!/usr/bin/env python3
"""Génère Modules/BoatLinesDB.lua : les lignes de bateaux et de zeppelins de WoW Forever.

Trajets : table TaxiPathNode des fichiers du jeu (wago.tools), lue directement : quais (nœuds avec un arrêt),
durée d'arrêt à quai, tracé (coordonnées monde, x nord, y ouest), changements de continent.
Durées de tour : mesurées par NauticusClassicResurrected (licence MIT, psynct et sam-k-taylor,
https://github.com/sam-k-taylor/NauticusClassicResurrected) ; « exact » pour celles mesurées sur plusieurs
jours, « approx » pour les lignes propres à WoW Forever (mesurées sur quelques tours) : l'addon les affine
avec les départs vus en jeu. Une ligne sans durée connue est apprise en jeu.

Tram des profondeurs : table TransportAnimation des fichiers du jeu (positions des rames dans leur tour, en ms) :
tour, départs (les deux rames partent en même temps, chacune d'un bout), durée du trajet et de l'arrêt.

Minutage des quais : trajets enregistrés point par point par NauticusClassicResurrected 1.5.4 (licence MIT),
importés une fois dans tools/boats/nauticus.json : heure d'arrivée et de départ de chaque quai dans le tour,
d'où les temps d'escale et de trajet exacts (avant : estimés d'après la longueur des trajets).

Usage : python3 tools/gen_boats.py [TaxiPathNode.csv [TransportAnimation.csv]]
        (sans fichier : téléchargés sur wago.tools, dernière version wowf)
        python3 tools/gen_boats.py --import-nauticus <data.lua de NauticusClassicResurrected>
"""
import csv
import json
import math
import os
import re
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "Modules", "BoatLinesDB.lua")
WAGO = "https://wago.tools"
UA = "Mozilla/5.0 (WarbandKeeper data tools)"


def get(url, timeout=120):
    return urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": UA}), timeout=timeout)

# n° de trajet du jeu » ligne. Noms des quais en français ; vessel = nom du navire ; period = tour (s).
# Ordre des quais : celui du trajet du jeu, en partant du premier arrêt.
LINES = [
    {"path": 11616, "key": "AUB_SW", "kind": "boat", "side": "A", "vessel": "Navire de Hurlevent",
     "stops": ["Auberdine", "Port de Hurlevent"], "period": 246.5, "prec": "approx"},
    {"path": 293, "key": "RUT_AUB", "kind": "boat", "side": "A", "vessel": "Le Chant-de-lune",
     "stops": ["Rut'theran", "Auberdine"], "period": 316.254198816156, "prec": "exact"},
    {"path": 292, "key": "MEN_THE", "kind": "boat", "side": "A", "vessel": "La Dame Mehley",
     "stops": ["Port de Menethil", "Theramore"], "period": 329.3162968069666, "prec": "exact"},
    {"path": 11167, "key": "MEN_AUS_AUB", "kind": "boat", "side": "A", "vessel": "Le Bravoure",
     "stops": ["Port de Menethil", "Austrivage", "Auberdine"], "period": 486.226, "prec": "approx"},
    {"path": 303, "key": "PLU_COTE", "kind": "boat", "side": "A", "vessel": "Bac de Plumelune",
     "stops": ["Bastion de Plumelune", "Côte Oubliée"], "period": 317.0452004189944, "prec": "exact"},
    {"path": 241, "key": "RAT_BB", "kind": "boat", "side": None, "vessel": "La Belle Demoiselle",
     "stops": ["Cabestan", "Baie-du-Butin"], "period": 350.8233330757341, "prec": "exact"},
    {"path": 11391, "key": "GENT_POUD", "kind": "boat", "side": None, "vessel": "Navire des Paluns",
     "stops": ["Port de Gentepression", "Port de Poudrefuse"], "period": 271.4125, "prec": "approx"},
    {"path": 302, "key": "ORG_FOS", "kind": "zeppelin", "side": "H", "vessel": "Le Porte-tonnerre",
     "stops": ["Orgrimmar", "Fossoyeuse"], "period": 356.28836360078276, "prec": "exact"},
    {"path": 285, "key": "GG_ORG", "kind": "zeppelin", "side": "H", "vessel": "L'Aigle de fer",
     "stops": ["Grom'gol", "Orgrimmar"], "period": 303.4671353784595, "prec": "exact"},
    {"path": 301, "key": "GG_FOS", "kind": "zeppelin", "side": "H", "vessel": "La Princesse pourpre",
     "stops": ["Grom'gol", "Fossoyeuse"], "period": 335.2982692023634, "prec": "exact"},
    {"path": 11457, "key": "MUL_ZEP", "kind": "zeppelin", "side": "H", "vessel": "Tranche-ciel",
     "stops": ["Mulgore", "Île de Zephras"], "period": 347.0, "prec": "approx"},
    {"path": 11398, "key": "DAL_ZEP", "kind": "zeppelin", "side": "A", "vessel": "Tranche-ciel",
     "stops": ["Dalaran", "Île de Zephras"], "period": 353.0, "prec": "approx"},
]
# ligne de NauticusClassicResurrected (n°) et son quai (platN) de chacun de nos quais, dans notre ordre
NAUTICUS = {
    "ORG_FOS": (1, [1, 2]), "GG_ORG": (2, [2, 1]), "GG_FOS": (3, [2, 1]), "RAT_BB": (4, [1, 2]),
    "MEN_AUS_AUB": (5, [1, 2, 3]), "MEN_THE": (6, [1, 2]), "RUT_AUB": (7, [1, 2]), "PLU_COTE": (8, [1, 2]),
    "AUB_SW": (11, [2, 1]), "MUL_ZEP": (12, [2, 1]), "DAL_ZEP": (13, [2, 1]), "GENT_POUD": (14, [2, 1]),
}
NAUT_JSON = os.path.join(HERE, "boats", "nauticus.json")


def lua_block(text, start):
    """Texte entre l'accolade ouvrante qui suit `start` et son accolade fermante."""
    i = text.index("{", text.index(start))
    depth = 0
    for j in range(i, len(text)):
        if text[j] == "{":
            depth += 1
        elif text[j] == "}":
            depth -= 1
            if depth == 0:
                return text[i + 1:j]
    raise ValueError(start)


def import_nauticus(path):
    """Lit data.lua de NauticusClassicResurrected : tour de chaque ligne et, pour chaque quai (platN),
    arrivée et départ dans le tour (secondes depuis le début de son trajet enregistré)."""
    text = open(path, encoding="utf-8").read()
    rtts = {}
    for m in re.finditer(r"^\s*([0-9.]+),\s*--\s*\[(\d+)\]", lua_block(text, "NauticusClassic.rtts ="), re.M):
        rtts[int(m.group(2))] = float(m.group(1))
    for m in re.finditer(r"\[(\d+)\]\s*=\s*([0-9.]+)", lua_block(text, "NauticusClassic.rtts_forever")):
        rtts[int(m.group(1))] = float(m.group(2))

    def routes(block):
        out = {}
        for m in re.finditer(r"\[(\d+)\]\s*=\s*\{", block):
            body = lua_block(block[m.start():], "[" + m.group(1) + "]")
            out[int(m.group(1))] = re.findall(r'"([^"]+)"', body)
        return out
    packed = routes(lua_block(text, "NauticusClassic.packedData ="))
    packed.update({k: v for k, v in routes(lua_block(text, "NauticusClassic.packedData_forever")).items() if v})
    out = {}
    for nid, pts in packed.items():
        if nid not in rtts:
            continue
        off, prev, plats = 0.0, 0.0, {}
        for p in pts:
            f = p.split(":")
            prev, off = off, off + float(f[2])
            for tag in f[5:]:
                if tag.startswith("plat"):
                    plats[int(tag[4:])] = {"arr": round(prev, 3), "dep": round(off, 3)}
        out[nid] = {"P": rtts[nid], "plats": plats}
    os.makedirs(os.path.dirname(NAUT_JSON), exist_ok=True)
    with open(NAUT_JSON, "w", encoding="utf-8") as f:
        json.dump(out, f, indent=1, sort_keys=True)
    print("nauticus.json : %d lignes" % len(out))


def times_of(line, naut):
    """Départ et arrivée de chacun de nos quais dans le tour (t = 0 : départ de notre quai 1), ou None."""
    m = NAUTICUS.get(line["key"])
    e = naut.get(str(m[0])) if m else None
    if not e:
        return None
    P = e["P"]
    try:
        plats = [e["plats"][str(n)] for n in m[1]]
    except KeyError:
        return None
    d0 = plats[0]["dep"]
    dep = [round((p["dep"] - d0) % P, 2) for p in plats]
    arr = [round((p["arr"] - d0) % P, 2) for p in plats]
    return {"P": P, "dep": dep, "arr": arr}


ACCEL = 600.0  # longueur équivalente (m) d'un départ et d'un arrêt : partage du temps de trajet entre les étapes


def wowf_version():
    with get(WAGO + "/api/builds", 60) as r:
        return json.load(r)["wowf"][0]["version"]


def fetch_table(name, version):
    url = "%s/db2/%s/csv?build=%s" % (WAGO, name, version)
    path = os.path.join(HERE, ".cache", name + ".csv")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with get(url) as r, open(path, "wb") as f:
        f.write(r.read())
    return path


# rames du tram des profondeurs (objets de transport du jeu) : 3 voitures par rame, une rame par voie
TRAM_CARS = [176080, 176081, 176082, 176083, 176084, 176085]


def tram(path):
    """Tour du tram (s), départ toutes les `every` s de chaque station, trajet et arrêt (s)."""
    cars = {}
    with open(path, encoding="utf-8") as f:
        for r in csv.DictReader(f):
            tid = int(r["TransportID"])
            if tid in TRAM_CARS:
                cars.setdefault(tid, []).append((int(r["TimeIndex"]), float(r["Pos_1"])))
    if len(cars) < 2:
        return None
    period = max(t for v in cars.values() for t, _ in v)
    rides, dwells = [], []
    for v in cars.values():
        v.sort()
        far = max(v, key=lambda e: abs(e[1]))[1]
        dep = next(t for t, y in v if abs(y) > 0.5)                       # quitte sa station
        prev = [t for t, y in v if abs(y) < 0.5 and t < dep]
        dep = max(prev) if prev else 0
        at_far = [t for t, y in v if abs(y - far) < 0.5]                  # à l'autre station
        rides.append((min(at_far) - dep) / 1000.0)
        dwells.append((max(at_far) - min(at_far)) / 1000.0)
    ride = sum(rides) / len(rides)
    return {"period": period / 1000.0, "every": period / 2000.0, "ride": round(ride, 1),
            "dwell": round(period / 2000.0 - ride, 1)}


def fetch_nodes():
    version = wowf_version()
    url = "%s/db2/TaxiPathNode/csv?build=%s" % (WAGO, version)
    path = os.path.join(HERE, ".cache", "TaxiPathNode.csv")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with get(url) as r, open(path, "wb") as f:
        f.write(r.read())
    return path, version


def load(path):
    nodes = {}
    with open(path, encoding="utf-8") as f:
        for r in csv.DictReader(f):
            nodes.setdefault(int(r["PathID"]), []).append(r)
    for k in nodes:
        nodes[k].sort(key=lambda r: int(r["NodeIndex"]))
    return nodes


def build(line, rows):
    pts = [(float(r["Loc_0"]), float(r["Loc_1"]), int(r["ContinentID"]), int(r["Flags"]), int(r["Delay"])) for r in rows]
    n = len(pts)
    stops = [i for i in range(n) if pts[i][4] > 0]
    if not stops:
        raise SystemExit("trajet %d : aucun arrêt" % line["path"])
    # arrêts presque au même endroit (le jeu coupe parfois un arrêt en deux à la fin du tour) : un seul quai
    merged = []
    for i in stops:
        if merged and math.dist(pts[merged[-1][-1]][:2], pts[i][:2]) < 40 and pts[merged[-1][-1]][2] == pts[i][2]:
            merged[-1].append(i)
        else:
            merged.append([i])
    if len(merged) > 1 and math.dist(pts[merged[0][0]][:2], pts[merged[-1][-1]][:2]) < 40 and pts[merged[0][0]][2] == pts[merged[-1][-1]][2]:
        merged[0] = merged.pop() + merged[0]
    if len(merged) != len(line["stops"]):
        raise SystemExit("trajet %d : %d quais trouvés, %d attendus" % (line["path"], len(merged), len(line["stops"])))
    out_stops, legs = [], []
    for k, grp in enumerate(merged):
        p = pts[grp[-1]]
        out_stops.append({"name": line["stops"][k], "c": p[2], "x": round(p[0], 1), "y": round(p[1], 1),
                          "dwell": sum(pts[i][4] for i in grp)})
    # étapes : du dernier nœud d'un quai au dernier nœud du quai suivant ; un saut de continent ou un nœud
    # marqué « téléportation » (drapeau 1) ne compte pas dans la longueur
    for k, grp in enumerate(merged):
        start = grp[-1]
        end = merged[(k + 1) % len(merged)][-1]
        i, length, trace = start, 0.0, [[pts[start][2], round(pts[start][0], 1), round(pts[start][1], 1)]]
        while i != end:
            j = (i + 1) % n
            a, b = pts[i], pts[j]
            if a[2] == b[2] and not (a[3] & 1):
                length += math.dist(a[:2], b[:2])
            trace.append([b[2], round(b[0], 1), round(b[1], 1)])
            i = j
        legs.append({"len": round(length, 1), "pts": trace})
    return out_stops, legs


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    if len(sys.argv) > 2 and sys.argv[1] == "--import-nauticus":
        return import_nauticus(sys.argv[2])
    naut = {}
    if os.path.exists(NAUT_JSON):
        with open(NAUT_JSON, encoding="utf-8") as f:
            naut = json.load(f)
    if len(sys.argv) > 1:
        path, version = sys.argv[1], "fichier local"
        anim = sys.argv[2] if len(sys.argv) > 2 else None
    else:
        path, version = fetch_nodes()
        anim = fetch_table("TransportAnimation", version)
    nodes = load(path)
    out = []
    out.append("local ADDON_NAME, WK = ...\n")
    out.append("-- GÉNÉRÉ par tools/gen_boats.py : ne pas modifier à la main.\n")
    out.append("-- Lignes de bateaux et de zeppelins de WoW Forever (version du jeu %s).\n" % version)
    out.append("-- Trajets : table TaxiPathNode des fichiers du jeu (wago.tools). Durées de tour : mesurées par\n")
    out.append("-- NauticusClassicResurrected (MIT License, Copyright (c) 2020 psynct ; sam-k-taylor),\n")
    out.append("-- https://github.com/sam-k-taylor/NauticusClassicResurrected\n")
    out.append("-- Minutage des quais (times : départ et arrivée de chaque quai dans le tour, t = 0 au départ du quai 1) :\n")
    out.append("-- trajets enregistrés par NauticusClassicResurrected 1.5.4 (même licence MIT).\n")
    out.append("-- stops = { name, c (continent), x, y (monde), dwell (s à quai) } ; legs[i] = du quai i au suivant :\n")
    out.append("-- len (m, hors sauts), pts = { c, x, y, ... } ; period = tour (s, nil = appris en jeu) ; prec = exact / approx.\n")
    out.append("WK.BoatLines = {\n")
    total = 0
    for line in LINES:
        rows = nodes.get(line["path"])
        if not rows:
            print("  ! trajet %d absent : ligne %s ignorée" % (line["path"], line["key"]))
            continue
        stops, legs = build(line, rows)
        total += 1
        out.append("    { key = %s, path = %d, kind = %s, side = %s, vessel = %s, period = %s, prec = %s,\n" % (
            lua_str(line["key"]), line["path"], lua_str(line["kind"]), lua_str(line["side"]) if line["side"] else "nil",
            lua_str(line["vessel"]), repr(line["period"]) if line["period"] else "nil", lua_str(line["prec"]) if line["prec"] else "nil"))
        tm = times_of(line, naut)
        if tm:
            out.append("      times = { P = %s, dep = { %s }, arr = { %s } },\n" % (
                repr(tm["P"]), ", ".join(repr(x) for x in tm["dep"]), ", ".join(repr(x) for x in tm["arr"])))
        out.append("      stops = {\n")
        for s in stops:
            out.append("        { name = %s, c = %d, x = %s, y = %s, dwell = %d },\n" % (lua_str(s["name"]), s["c"], s["x"], s["y"], s["dwell"]))
        out.append("      },\n      legs = {\n")
        for g in legs:
            flat = ", ".join("%d, %s, %s" % (p[0], p[1], p[2]) for p in g["pts"])
            out.append("        { len = %s, pts = { %s } },\n" % (g["len"], flat))
        out.append("      },\n    },\n")
    out.append("}\n")
    tr = tram(anim) if anim else None
    if tr:
        out.append("-- Tram des profondeurs (table TransportAnimation) : tour, un départ de chaque station toutes les `every` s\n")
        out.append("-- (les deux rames partent en même temps, chacune d'un bout), trajet et arrêt (s).\n")
        out.append("WK.TramLine = { period = %s, every = %s, ride = %s, dwell = %s }\n" % (
            repr(round(tr["period"], 3)), repr(round(tr["every"], 4)), repr(tr["ride"]), repr(tr["dwell"])))
    else:
        print("  ! TransportAnimation absente : tram non généré")
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("".join(out))
    print("BoatLinesDB.lua : %d lignes" % total)


if __name__ == "__main__":
    main()
