#!/usr/bin/env python3
"""Publication automatique d'une mise à jour des données (appelé par .github/workflows/update-data.yml
quand tools/update_schedule.json dit "publier": true).

Usage : python3 tools/publish_data.py <résumé.json de tools/update_data.py --json>

Monte la version de l'addon d'un cran (0.90.3 » 0.90.4), ajoute en tête de Core/Changelog.lua une entrée
« Données mises à jour » écrite à partir des chiffres (du point de vue du joueur), et régénère CHANGELOG.md.
Les données ne sont que des fichiers déjà chargés par le jeu : un /reload suffit (pas de restart).
Écrit la nouvelle version sur la sortie standard.
"""
import json
import os
import re
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# chiffre de tools/update_data.py » (phrase si ça monte, phrase si ça baisse) ; {n} = écart
PHRASES = {
    "Quêtes": ("{n} quête(s) de plus", "{n} quête(s) retirée(s)"),
    "Rares": ("{n} monstre(s) rare(s) de plus", "{n} rare(s) retiré(s)"),
    "Lieux (boîtes, marchands, maîtres…)": ("{n} lieu(x) utile(s) de plus sur la carte", "{n} lieu(x) retiré(s) de la carte"),
    "Chemins de base": ("{n} chemin(s) de plus pour la navigation", "{n} chemin(s) en moins"),
    "Donjons et raids": ("{n} donjon(s) ou raid(s) de plus", "{n} donjon(s) en moins"),
    "Boss": ("{n} boss de plus", "{n} boss en moins"),
    "Boss sans n° de PNJ (appris en jeu)": ("", "{n} boss du nouveau contenu désormais reconnus d'office"),
    "Objets de butin des boss": ("{n} objet(s) de butin de plus", "{n} objet(s) de butin en moins"),
    "Objets pas encore découverts": ("", "{n} objet(s) de butin désormais découverts"),
    "Recettes": ("{n} recette(s) de plus", "{n} recette(s) en moins"),
    "Boss avec n° de rencontre": ("{n} boss de plus détectés par la fin de rencontre", ""),
    "Boss avec nom français": ("{n} boss de plus avec leur nom français", ""),
    "Donjons avec n° d'instance": ("{n} donjon(s) de plus reconnus en entrant", ""),
    "Guides de métiers": ("{n} guide(s) de métier de plus", ""),
    "Objets avec taux de drop observé": ("{n} objet(s) de plus avec un taux de drop observé", ""),
    "Trajets de vol (fichiers du jeu)": ("{n} trajet(s) de vol de plus", ""),
    "Sorts de classe": ("{n} sort(s) de classe de plus", "{n} sort(s) de classe en moins"),
    "Prix des sorts de classe": ("{n} prix de sort(s) de plus chez les maîtres", "{n} prix de sort(s) en moins"),
    "Maîtres d'armes": ("{n} maître(s) d'armes de plus", "{n} maître(s) d'armes en moins"),
    "Quêtes avec camps d'objectifs": ("{n} quête(s) de plus avec leurs camps d'objectifs", "{n} quête(s) sans camps d'objectifs"),
    "Objets portables (liste BiS)": ("{n} objet(s) de plus pour les listes BiS", "{n} objet(s) retiré(s) des listes BiS"),
    "Lignes de bateaux et zeppelins": ("{n} ligne(s) de bateau ou de zeppelin de plus", "{n} ligne(s) en moins"),
    "Zones pour /way": ("{n} zone(s) de plus pour /way", "{n} zone(s) en moins pour /way"),
    "Cartes sans brouillard": ("{n} carte(s) de plus sans brouillard", "{n} carte(s) sans brouillard en moins"),
    "Mises à jour de la base notées (journal)": ("", ""),
}


def sources_text(sources):
    """Noms courts des sources, sans doublon, « A, B et C ». Une source dont la parenthèse nomme le site
    (wago.tools, What's Training) prend ce nom ; sinon le texte avant la parenthèse ou le numéro de version.
    Avant, le premier mot de chaque source donnait « QuestieDB et Everloot et tables et … et prix »."""
    names = []
    for s in sources:
        m = re.search(r"\(([^)]*)\)", s)
        inner = m.group(1) if m else ""
        if inner and ("." in inner or "What's" in inner) and not inner[0].isdigit():
            name = inner
        else:
            name = re.split(r" \(| `", s)[0]
        name = name.strip()
        if name and name not in names:
            names.append(name)
    if len(names) <= 1:
        return "".join(names)
    return ", ".join(names[:-1]) + " et " + names[-1]


def plural(text, n):
    # « (s) », « (x) » : pluriel si n > 1
    return re.sub(r"\((s|x)\)", lambda m: m.group(1) if n > 1 else "", text)


def main(path):
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    before, after = data["before"], data["after"]
    bits = []
    for k, (up, down) in PHRASES.items():
        d = after.get(k, 0) - before.get(k, 0)
        tpl = up if d > 0 else down if d < 0 else ""
        if tpl:
            bits.append(plural(tpl.format(n=abs(d)), abs(d)))
    changed = data.get("changed", [])
    if any("Guides" in c or "guides/" in c for c in changed) and not any("guide" in b for b in bits):
        bits.append("guides de métiers revus par wowtbc.gg")
    src = sources_text(data.get("sources", [])) or "les sources"
    line = "Données mises à jour depuis %s%s." % (src, (" : " + ", ".join(bits)) if bits else " (corrections dans les données existantes)")

    toc = os.path.join(ROOT, "WarbandKeeper.toc")
    with open(toc, encoding="utf-8") as f:
        t = f.read()
    cur = re.search(r"^## Version:\s*(\S+)", t, re.M).group(1)
    parts = [int(x) for x in cur.split(".")]
    parts[-1] += 1
    new = ".".join(str(x) for x in parts)
    with open(toc, "w", encoding="utf-8") as f:
        f.write(re.sub(r"^## Version:.*$", "## Version: " + new, t, count=1, flags=re.M))
    # dossier WarbandKeeper_Data (chargé à la demande) : même version
    dtoc = os.path.join(ROOT, "Data", "WarbandKeeper_Data.toc")
    if os.path.exists(dtoc):
        with open(dtoc, encoding="utf-8") as f:
            d = f.read()
        with open(dtoc, "w", encoding="utf-8") as f:
            f.write(re.sub(r"^## Version:.*$", "## Version: " + new, d, count=1, flags=re.M))
    init = os.path.join(ROOT, "Core", "Init.lua")
    with open(init, encoding="utf-8") as f:
        s = f.read()
    with open(init, "w", encoding="utf-8") as f:
        f.write(re.sub(r'WK\.version = "[^"]*"', 'WK.version = "%s"' % new, s, count=1))
    cl = os.path.join(ROOT, "Core", "Changelog.lua")
    with open(cl, encoding="utf-8") as f:
        s = f.read()
    entry = ('WK.Changelog = {\n    {\n        version = "%s", date = "%s",\n        changed = {\n            "%s",\n        },\n    },'
             % (new, time.strftime("%d/%m/%Y"), line.replace("\\", "\\\\").replace('"', '\\"')))
    with open(cl, "w", encoding="utf-8") as f:
        f.write(s.replace("WK.Changelog = {", entry, 1))
    subprocess.run([sys.executable, os.path.join(ROOT, "tools", "gen_changelog.py")], check=True, cwd=ROOT,
                   stdout=subprocess.DEVNULL)
    print(new)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1])
