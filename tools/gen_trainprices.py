#!/usr/bin/env python3
"""Génère Modules/ClassPricesDB.lua : le prix de base de chaque sort de classe chez le maître.

Source : What's Training (https://github.com/fusionpit/WhatsTraining, licence MIT,
(c) 2019 What's Training authors), fichiers Classes/Vanilla/<Classe>.lua, lus sur GitHub.
Seuls les couples (sort, prix) sont repris ; le code de What's Training n'est pas repris.

Usage : python3 tools/gen_trainprices.py [dossier local de What's Training]
        (sans dossier : téléchargement depuis raw.githubusercontent.com)

Format : WK.ClassBasePrice = "sort:prix,sort:prix,…" (prix en pièces de cuivre, sans remise de
réputation). Le prix relevé chez le maître (Modules/ClassSpells.lua) passe devant.

Compétences d'armes (Classes/WeaponSkills.lua de What's Training, lu comme du texte, jamais exécuté) :
WK.WeaponSkillsDB[sort] = { classes = "CLASSE,…", level = niveau requis, cost = cuivre } et
WK.WeaponMasters = { { npc, faction, carte, x, y, "sorts enseignés", nom anglais, nom français } }
(maîtres de Classic Era, ceux de WoW Forever).
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


def weapons(folder):
    if folder:
        with open(os.path.join(folder, "Classes", "WeaponSkills.lua"), encoding="utf-8") as f:
            src = f.read()
    else:
        with urllib.request.urlopen(URL.replace("Vanilla/%s.lua", "WeaponSkills.lua"), timeout=30) as r:
            src = r.read().decode("utf-8")
    consts = dict(re.findall(r"local ([A-Z_]+) = (\d+)\n", src))
    zones = {consts[k]: int(v) for k, v in re.findall(r"\[([A-Z_]+)\] = \{ uiMapId = (\d+)", src)}
    ws = src[src.index("local weaponSkills"):src.index("local weaponMasters")]
    skills = {}
    for name, body in re.findall(r"\[([A-Z_]+)\] = \{(.*?)\n    \},", ws, re.S):
        cls = [c for c, v in re.findall(r'(\w+) = (true|version == "tbc")', body) if v == "true"]
        lvl = re.search(r"requiredLevel = (\d+)", body)
        cost = re.search(r"costCopper = (\d+)", body)
        skills[int(consts[name])] = (cls, int(lvl.group(1)) if lvl else 0, int(cost.group(1)) if cost else 1000)
    end = src.index("local presentation") if "local presentation" in src else len(src)
    wm = src[src.index("local weaponMasters"):end]
    masters = []
    for npc, body in re.findall(r"\n    \[(\d+)\] = \{(.*?)\n    \},", wm, re.S):
        ver = re.search(r"versions = \{([^}]*)\}", body)
        if not ver or "era" not in ver.group(1):
            continue
        fac = re.search(r'faction = "(\w+)"', body).group(1)
        loc = re.search(r"zoneId = ([A-Z_]+), x = ([\d.]+), y = ([\d.]+)", body)
        teach = [consts[t] for t in re.findall(r"\[([A-Z_]+)\] = true", re.search(r"teaches = \{(.*?)\}", body, re.S).group(1))]
        en = re.search(r'enUS = "([^"]+)"', body).group(1)
        fr = re.search(r'frFR = "([^"]+)"', body)
        masters.append((int(npc), fac, zones[consts[loc.group(1)]], float(loc.group(2)) / 100, float(loc.group(3)) / 100,
                        ",".join(sorted(teach, key=int)), en, fr.group(1) if fr else en))
    if len(skills) < 10 or len(masters) < 6:
        sys.exit("compétences d'armes : trop peu de données lues (source changée ?)")
    return skills, sorted(masters)


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


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
        skills, masters = weapons(folder)
        f.write("\n-- Compétences d'armes : classes qui les apprennent, niveau requis, prix de base (cuivre)\n")
        f.write("WK.WeaponSkillsDB = {\n")
        for sid in sorted(skills):
            cls, lvl, cost = skills[sid]
            f.write('    [%d] = { classes = "%s", level = %d, cost = %d },\n' % (sid, ",".join(cls), lvl, cost))
        f.write("}\n")
        f.write("-- Maîtres d'armes : { n° de PNJ, faction, carte, x, y, sorts enseignés, nom anglais, nom français }\n")
        f.write("WK.WeaponMasters = {\n")
        for m in masters:
            f.write('    { %d, "%s", %d, %.3f, %.3f, "%s", %s, %s },\n' % (m[0], m[1], m[2], m[3], m[4], m[5], lua_str(m[6]), lua_str(m[7])))
        f.write("}\n")
    print("ClassPricesDB.lua : %d prix, %d armes, %d maîtres d'armes" % (len(prices), len(skills), len(masters)))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else None)
