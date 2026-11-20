#!/usr/bin/env python3
"""Génère Modules/ClassPricesDB.lua : le prix de base de chaque sort de classe chez le maître.

Source : What's Training (https://github.com/fusionpit/WhatsTraining, licence MIT,
(c) 2019 What's Training authors), fichiers Classes/Vanilla/<Classe>.lua, lus sur GitHub.
Seuls les couples (sort, prix) sont repris ; le code de What's Training n'est pas repris.

Usage : python3 tools/gen_trainprices.py [dossier local de What's Training]
        (sans dossier : téléchargement depuis raw.githubusercontent.com)

Format : WK.ClassBasePrice = "sort:prix,sort:prix,…" (prix en pièces de cuivre, sans remise de
réputation). Le prix relevé chez le maître (Modules/ClassSpells.lua) passe devant.
"""
import os
import re
import sys
import urllib.request

CLASSES = ["Druid", "Hunter", "Mage", "Paladin", "Priest", "Rogue", "Shaman", "Warlock", "Warrior"]
URL = "https://raw.githubusercontent.com/fusionpit/WhatsTraining/master/Classes/Vanilla/%s.lua"
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "Modules", "ClassPricesDB.lua")
ROW = re.compile(r"\{\s*id\s*=\s*(\d+)\s*,\s*cost\s*=\s*(\d+)")


def read(cls, folder):
    if folder:
        with open(os.path.join(folder, "Classes", "Vanilla", cls + ".lua"), encoding="utf-8") as f:
            return f.read()
    with urllib.request.urlopen(URL % cls, timeout=30) as r:
        return r.read().decode("utf-8")


def license_text(folder):
    if folder:
        with open(os.path.join(folder, "LICENSE"), encoding="utf-8") as f:
            return f.read()
    with urllib.request.urlopen(URL.replace("Classes/Vanilla/%s.lua", "LICENSE"), timeout=30) as r:
        return r.read().decode("utf-8")


def main(folder=None):
    prices = {}
    for cls in CLASSES:
        for sid, cost in ROW.findall(read(cls, folder)):
            if int(cost) > 0:
                prices[int(sid)] = int(cost)
    if len(prices) < 500:
        sys.exit("trop peu de prix lus (%d) : source changée ?" % len(prices))
    body = ",".join("%d:%d" % (k, prices[k]) for k in sorted(prices))
    lines = [body[i:i + 160] for i in range(0, len(body), 160)]
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("local ADDON_NAME, WK = ...\n\n")
        f.write("-- Généré par tools/gen_trainprices.py, ne pas modifier à la main.\n")
        f.write("-- Prix de base des sorts de classe chez le maître (cuivre, sans remise de réputation).\n")
        f.write("-- Source : What's Training, https://github.com/fusionpit/WhatsTraining (licence MIT).\n")
        f.write("-- Licence de What's Training, reprise telle quelle :\n")
        for ln in license_text(folder).strip().splitlines():
            f.write(("-- " + ln).rstrip() + "\n")
        f.write("WK.ClassBasePrice = table.concat({\n")
        for ln in lines:
            f.write('    "%s",\n' % ln)
        f.write("})\n")
    print("ClassPricesDB.lua : %d prix" % len(prices))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else None)
