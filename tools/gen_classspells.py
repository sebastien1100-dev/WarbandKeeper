#!/usr/bin/env python3
"""Génère Modules/ClassSpellsDB.lua : les sorts de chaque classe et leur niveau requis.

Usage : python3 tools/gen_classspells.py [dossier des tables wago]
        (par défaut tools/.cache/wago, rempli par tools/update_data.py : tables SkillLineAbility,
        SkillLine, SpellLevels, SpellName, Talent du client WoW Forever, en anglais)

Sorts gardés : lignes de compétence de classe (catégorie 7) hors familiers, montures, runes et
gravures ; méthode d'acquisition 0 (maître) ; pas un rang de talent ; niveau requis connu (> 0).
Les noms, rangs et le niveau exact sont relus en jeu (C_Spell, GetSpellLevelLearned) ; les prix
viennent de la fenêtre du maître (Modules/ClassSpells.lua).

Format : WK.ClassSpellsRaw[CLASSE] = "niveau,sort,t;…" (t = 1 si un talent porte le même nom :
sort de talent, montré seulement si le perso a ce talent).
"""
import csv
import os
import sys

CLASSES = {1: "WARRIOR", 2: "PALADIN", 4: "HUNTER", 8: "ROGUE", 16: "PRIEST", 64: "SHAMAN", 128: "MAGE",
           256: "WARLOCK", 1024: "DRUID"}
SKIP_LINES = ("Runes", "Engraving", "Mounts", "Companions", "Beast Training")


def rd(folder, name):
    with open(os.path.join(folder, name + "-enUS.csv"), encoding="utf-8") as f:
        return list(csv.DictReader(f))


def main(folder, out):
    lines = {int(r["ID"]): r for r in rd(folder, "SkillLine")}
    level = {}
    for r in rd(folder, "SpellLevels"):
        if r["DifficultyID"] == "0":
            level[int(r["SpellID"])] = int(r["BaseLevel"] or 0)
    names = {int(r["ID"]): r["Name_lang"] for r in rd(folder, "SpellName")}
    talent, talent_names = set(), set()
    for r in rd(folder, "Talent"):
        for i in range(9):
            v = int(r.get("SpellRank_%d" % i) or 0)
            if v:
                talent.add(v)
                talent_names.add(names.get(v))
    per = {c: {} for c in CLASSES.values()}
    for r in rd(folder, "SkillLineAbility"):
        sl = lines.get(int(r["SkillLine"]))
        if not sl or sl["CategoryID"] != "7":
            continue
        ln = sl["DisplayName_lang"]
        if ln in SKIP_LINES or ln.startswith("Pet - "):
            continue
        if r["AcquireMethod"] != "0":
            continue
        sp = int(r["Spell"])
        lvl = level.get(sp, 0)
        if sp not in names or sp in talent or lvl <= 0:
            continue
        if 400000 <= sp < 1000000:   # sorts de Season of Discovery présents dans le client, pas dans le jeu
            continue
        t = 1 if names[sp] in talent_names else 0
        for bit, cls in CLASSES.items():
            if int(r["ClassMask"]) & bit:
                per[cls][sp] = (lvl, sp, t)
    with open(out, "w", encoding="utf-8") as f:
        f.write("-- FICHIER GÉNÉRÉ par tools/gen_classspells.py : ne pas modifier à la main.\n"
                "-- Sorts de classe et niveau requis, tirés des tables du client WoW Forever (wago.tools).\n"
                "-- WK.ClassSpellsRaw[CLASSE] = \"niveau,sort,talent;…\" (format dans le générateur).\n"
                "local ADDON_NAME, WK = ...\nWK.ClassSpellsRaw = {\n")
        total = 0
        for cls in sorted(per):
            items = sorted(per[cls].values())
            total += len(items)
            f.write('%s="%s",\n' % (cls, ";".join("%d,%d,%d" % x for x in items)))
        f.write("}\n")
    print("%d sorts de classe" % total)


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    folder = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, ".cache", "wago")
    main(folder, os.path.join(here, "..", "Modules", "ClassSpellsDB.lua"))
