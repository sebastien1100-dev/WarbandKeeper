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

Familiers (lignes « Pet - … ») : WK.ClassPetFamilies[CLASSE] = { noms français des familles } et
WK.ClassPetSpellsRaw[CLASSE] = "niveau,sort,n°.n°;…" (n° des familles qui ont le sort) : démons du démoniste
(grimoires du maître des démons) et techniques des familiers du chasseur. Méthode 0 seulement, niveau > 0,
sans les sorts techniques (DND, Scaling).

Arbres de talents (tables Talent et TalentTab, pour faire un plan sans perso de la classe) :
WK.ClassTalentTrees[CLASSE] = { { "nom fr", "nom en", "rangée,colonne,rangs,sort,prérequis;…" }, … } dans
l'ordre du jeu (OrderIndex) ; talents rangés par rangée puis colonne ; nom et icône relus en jeu par le sort ;
prérequis = « rangée.colonne » du talent demandé (au rang max), 0 sans prérequis.
"""
import csv
import os
import sys

CLASSES = {1: "WARRIOR", 2: "PALADIN", 4: "HUNTER", 8: "ROGUE", 16: "PRIEST", 64: "SHAMAN", 128: "MAGE",
           256: "WARLOCK", 1024: "DRUID"}
SKIP_LINES = ("Runes", "Engraving", "Mounts", "Companions", "Beast Training")
DEMONS = {"Imp": "Diablotin", "Voidwalker": "Marcheur du Vide", "Succubus": "Succube", "Felhunter": "Chasseur corrompu",
          "Felguard": "Gangregarde"}
BEASTS = {"Bat": "Chauve-souris", "Bear": "Ours", "Bird of Prey": "Oiseau de proie", "Boar": "Sanglier",
          "Carrion Bird": "Charognard", "Cat": "Félin", "Core Hound": "Chien du Magma", "Crab": "Crabe",
          "Crocilisk": "Crocilisque", "Gorilla": "Gorille", "Hyena": "Hyène", "Raptor": "Raptor", "Scorpid": "Scorpide",
          "Spider": "Araignée", "Tallstrider": "Haut-trotteur", "Turtle": "Tortue", "Wind Serpent": "Serpent des vents",
          "Wolf": "Loup", "Fox": "Renard"}


def pet_spells(lines, rows, level, names):
    """Sorts des familiers : { CLASSE: (familles, { sort: [niveau, {n° de famille}] }) }."""
    out = {"WARLOCK": ([], {}), "HUNTER": ([], {})}
    for r in rows:
        sl = lines.get(int(r["SkillLine"]))
        if not sl or sl["CategoryID"] != "7" or not sl["DisplayName_lang"].startswith("Pet - "):
            continue
        fam = sl["DisplayName_lang"][6:]
        cls = "WARLOCK" if fam in DEMONS else ("HUNTER" if fam in BEASTS else None)
        if not cls or r["AcquireMethod"] != "0":
            continue
        sp = int(r["Spell"])
        nm, lvl = names.get(sp), level.get(sp, 0)
        if not nm or lvl <= 0 or "(DND)" in nm or "Scaling" in nm:
            continue
        fams, spells = out[cls]
        label = (DEMONS if cls == "WARLOCK" else BEASTS)[fam]
        if label not in fams:
            fams.append(label)
        e = spells.setdefault(sp, [lvl, set()])
        e[1].add(fams.index(label) + 1)
    return out


def rd(folder, name):
    with open(os.path.join(folder, name + "-enUS.csv"), encoding="utf-8") as f:
        return list(csv.DictReader(f))


def talent_trees(folder):
    """{ CLASSE: [ (nom fr, nom en, [ (rangée, colonne, rangs, sort) ]) ] }, ou {} sans la table TalentTab."""
    try:
        tabs_en = {int(r["ID"]): r for r in rd(folder, "TalentTab")}
        with open(os.path.join(folder, "TalentTab-frFR.csv"), encoding="utf-8") as f:
            tabs_fr = {int(r["ID"]): r for r in csv.DictReader(f)}
    except OSError:
        return {}
    trees = {}
    rows = rd(folder, "Talent")
    pos_of = {int(r["ID"]): (int(r["TierID"]) + 1, int(r["ColumnIndex"]) + 1) for r in rows}
    for r in rows:
        tab = tabs_en.get(int(r["TabID"]))
        if not tab:
            continue
        ranks = [int(r.get("SpellRank_%d" % i) or 0) for i in range(9)]
        ranks = [x for x in ranks if x]
        if not ranks:
            continue
        pos = (int(r["TierID"]) + 1, int(r["ColumnIndex"]) + 1)
        pre = pos_of.get(int(r.get("PrereqTalent_0") or 0))
        trees.setdefault(int(r["TabID"]), []).append(pos + (len(ranks), ranks[0], "%d.%d" % pre if pre else "0"))
    out = {}
    for tid, lst in trees.items():
        tab = tabs_en[tid]
        for bit, cls in CLASSES.items():
            if int(tab["ClassMask"]) & bit:
                fr = tabs_fr.get(tid, tab)["Name_lang"]
                out.setdefault(cls, []).append((int(tab["OrderIndex"]), fr, tab["Name_lang"], sorted(lst)))
    return {c: [t[1:] for t in sorted(v)] for c, v in out.items()}


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
    sla = rd(folder, "SkillLineAbility")
    pets = pet_spells(lines, sla, level, names)
    for r in sla:
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
        npet = 0
        f.write("WK.ClassPetFamilies = {\n")
        for cls in sorted(pets):
            f.write('%s={%s},\n' % (cls, ",".join('"%s"' % x for x in pets[cls][0])))
        f.write("}\nWK.ClassPetSpellsRaw = {\n")
        for cls in sorted(pets):
            items = sorted(pets[cls][1].items(), key=lambda kv: (kv[1][0], kv[0]))
            npet += len(items)
            f.write('%s="%s",\n' % (cls, ";".join("%d,%d,%s" % (v[0], sp, ".".join(str(x) for x in sorted(v[1])))
                                               for sp, v in items)))
        f.write("}\n")
        trees = talent_trees(folder)
        ntal = 0
        f.write("WK.ClassTalentTrees = {\n")
        for cls in sorted(trees):
            parts = []
            for fr, en, lst in trees[cls]:
                ntal += len(lst)
                parts.append('{"%s","%s","%s"}' % (fr, en, ";".join("%d,%d,%d,%d,%s" % x for x in lst)))
            f.write("%s={%s},\n" % (cls, ",".join(parts)))
        f.write("}\n")
    print("%d sorts de classe, %d sorts de familiers, %d talents" % (total, npet, ntal))


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    folder = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, ".cache", "wago")
    main(folder, os.path.join(here, "..", "Modules", "ClassSpellsDB.lua"))
