#!/usr/bin/env python3
"""Génère Modules/BoatLinesDB.lua : les lignes de bateaux et de zeppelins de WoW Forever.

Trajets : table TaxiPathNode des fichiers du jeu (wago.tools), lue directement : quais (nœuds avec un arrêt),
tracé (coordonnées monde, x nord, y ouest), changements de continent. Aucun horaire.

Usage : python3 tools/gen_boats.py [TaxiPathNode.csv]   (sans fichier : téléchargé sur wago.tools, dernière version wowf)
"""
import csv
import json
import math
import os
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "Modules", "BoatLinesDB.lua")
WAGO = "https://wago.tools"
UA = "Mozilla/5.0 (WarbandKeeper data tools)"


def get(url, timeout=120):
    return urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": UA}), timeout=timeout)

# n° de trajet du jeu » ligne. Noms des quais en français ; vessel = nom du navire.
# Ordre des quais : celui du trajet du jeu, en partant du premier arrêt.
LINES = [
    {"path": 11616, "key": "AUB_SW", "kind": "boat", "side": "A", "vessel": "Navire de Hurlevent",
     "stops": ["Auberdine", "Port de Hurlevent"]},
    {"path": 293, "key": "RUT_AUB", "kind": "boat", "side": "A", "vessel": "Le Chant-de-lune",
     "stops": ["Rut'theran", "Auberdine"]},
    {"path": 292, "key": "MEN_THE", "kind": "boat", "side": "A", "vessel": "La Dame Mehley",
     "stops": ["Port de Menethil", "Theramore"]},
    {"path": 11167, "key": "MEN_AUS_AUB", "kind": "boat", "side": "A", "vessel": "Le Bravoure",
     "stops": ["Port de Menethil", "Austrivage", "Auberdine"]},
    {"path": 303, "key": "PLU_COTE", "kind": "boat", "side": "A", "vessel": "Bac de Plumelune",
     "stops": ["Bastion de Plumelune", "Côte Oubliée"]},
    {"path": 241, "key": "RAT_BB", "kind": "boat", "side": None, "vessel": "La Belle Demoiselle",
     "stops": ["Cabestan", "Baie-du-Butin"]},
    {"path": 11391, "key": "GENT_POUD", "kind": "boat", "side": None, "vessel": "Navire des Paluns",
     "stops": ["Port de Gentepression", "Port de Poudrefuse"]},
    {"path": 302, "key": "ORG_FOS", "kind": "zeppelin", "side": "H", "vessel": "Le Porte-tonnerre",
     "stops": ["Orgrimmar", "Fossoyeuse"]},
    {"path": 285, "key": "GG_ORG", "kind": "zeppelin", "side": "H", "vessel": "L'Aigle de fer",
     "stops": ["Grom'gol", "Orgrimmar"]},
    {"path": 301, "key": "GG_FOS", "kind": "zeppelin", "side": "H", "vessel": "La Princesse pourpre",
     "stops": ["Grom'gol", "Fossoyeuse"]},
    {"path": 11457, "key": "MUL_ZEP", "kind": "zeppelin", "side": "H", "vessel": "Tranche-ciel",
     "stops": ["Mulgore", "Île de Zephras"]},
    {"path": 11398, "key": "DAL_ZEP", "kind": "zeppelin", "side": "A", "vessel": "Tranche-ciel",
     "stops": ["Dalaran", "Île de Zephras"]},
]


def wowf_version():
    with get(WAGO + "/api/builds", 60) as r:
        return json.load(r)["wowf"][0]["version"]


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
    if len(sys.argv) > 1:
        path, version = sys.argv[1], "fichier local"
    else:
        path, version = fetch_nodes()
    nodes = load(path)
    out = []
    out.append("local ADDON_NAME, WK = ...\n")
    out.append("-- GÉNÉRÉ par tools/gen_boats.py : ne pas modifier à la main.\n")
    out.append("-- Lignes de bateaux et de zeppelins de WoW Forever (version du jeu %s).\n" % version)
    out.append("-- Trajets : table TaxiPathNode des fichiers du jeu (wago.tools).\n")
    out.append("-- stops = { name, c (continent), x, y (monde) } ; legs[i] = du quai i au suivant :\n")
    out.append("-- len (m, hors sauts), pts = { c, x, y, ... }.\n")
    out.append("WK.BoatLines = {\n")
    total = 0
    for line in LINES:
        rows = nodes.get(line["path"])
        if not rows:
            print("  ! trajet %d absent : ligne %s ignorée" % (line["path"], line["key"]))
            continue
        stops, legs = build(line, rows)
        total += 1
        out.append("    { key = %s, path = %d, kind = %s, side = %s, vessel = %s,\n" % (
            lua_str(line["key"]), line["path"], lua_str(line["kind"]), lua_str(line["side"]) if line["side"] else "nil",
            lua_str(line["vessel"])))
        out.append("      stops = {\n")
        for st in stops:
            out.append("        { name = %s, c = %d, x = %s, y = %s },\n" % (lua_str(st["name"]), st["c"], st["x"], st["y"]))
        out.append("      },\n      legs = {\n")
        for g in legs:
            flat = ", ".join("%d, %s, %s" % (p[0], p[1], p[2]) for p in g["pts"])
            out.append("        { len = %s, pts = { %s } },\n" % (g["len"], flat))
        out.append("      },\n    },\n")
    out.append("}\n")
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("".join(out))
    print("BoatLinesDB.lua : %d lignes" % total)


if __name__ == "__main__":
    main()
