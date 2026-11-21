#!/usr/bin/env python3
"""Génère Modules/WayZonesDB.lua : noms des zones (anglais et français) pour la commande /way.

Usage : python3 tools/gen_wayzones.py [dossier des tables wago]

Source : table UiMap du client WoW Forever (wago.tools, UiMap-enUS.csv et UiMap-frFR.csv, récupérées par
update_data.py). Un guide ou un message donne souvent « /way Elwynn Forest 32.3 48.5 » en anglais : la
commande reconnaît le nom anglais comme le nom du jeu (français).
  WK.WayZones = { { n° de carte, "nom anglais", "nom français", genre }, ... }  (genre 3 = zone, 6 = champ de bataille)
"""
import csv
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def main(src):
    def read(loc):
        with open(os.path.join(src, "UiMap-%s.csv" % loc), encoding="utf-8") as f:
            return {r["ID"]: r for r in csv.DictReader(f)}
    en, fr = read("enUS"), read("frFR")
    rows, seen = [], set()
    for i, r in sorted(en.items(), key=lambda x: int(x[0])):
        kind = int(r.get("Type") or 0)
        if kind not in (3, 6) or int(r.get("ParentUiMapID") or 0) == 0:
            continue
        name_en = r["Name_lang"].strip()
        name_fr = (fr.get(i) or {}).get("Name_lang", name_en).strip()
        if not name_en or (name_en, kind) in seen:
            continue
        seen.add((name_en, kind))
        rows.append((int(i), name_en, name_fr, kind))

    def s(x):
        return '"' + x.replace("\\", "\\\\").replace('"', '\\"') + '"'
    out = os.path.join(HERE, "..", "Modules", "WayZonesDB.lua")
    with open(out, "w", encoding="utf-8") as f:
        f.write("-- FICHIER GÉNÉRÉ par tools/gen_wayzones.py : ne pas modifier à la main.\n"
                "-- Noms des zones pour /way (table UiMap du client WoW Forever, wago.tools).\n"
                "local ADDON_NAME, WK = ...\nWK.WayZones = {\n")
        for r in rows:
            f.write("{%d,%s,%s,%d},\n" % (r[0], s(r[1]), s(r[2]), r[3]))
        f.write("}\n")
    print("%d zones -> %s" % (len(rows), out))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, ".cache", "wago"))
