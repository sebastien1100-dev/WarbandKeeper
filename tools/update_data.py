#!/usr/bin/env python3
"""Met à jour toutes les données générées de Warband Keeper, en une commande.

Usage : python3 tools/update_data.py [--questie <clone de QuestieDB>] [--summary <fichier.md>]
                                     [--sans-questie] [--sans-wowtbc]
        (nécessite : pip install lupa)

Étapes :
  1. QuestieDB : clone (ou mise à jour) dans tools/.cache/QuestieDB, sauf si --questie est donné ;
  2. wowtbc.gg : téléchargement des guides de métiers (ceux de tools/guides) et des tables de butin
     des donjons et raids (liste lue sur le site) ;
  3. tous les générateurs : lieux, chemins, rares, quêtes, donjons, guides et recettes ;
  4. contrôle : chaque fichier généré doit se charger, et aucun chiffre ne doit s'effondrer
     (perte de plus de 20 %) : sinon tout est remis comme avant et le script s'arrête (code 2) ;
  5. résumé de ce qui a changé (écran, et fichier Markdown avec --summary, repris par la PR
     de .github/workflows/update-data.yml).
Les mentions de licence restent dans l'en-tête de chaque fichier généré (écrites par les générateurs).
"""
import glob
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
CACHE = os.path.join(HERE, ".cache")
QUESTIE_URL = "https://github.com/Questie/QuestieDB"
WOWTBC = "https://wowtbc.gg/page-data/warcraftforever"
UA = "WarbandKeeper-data-update"
TARGETS = ["PlacesDB", "RoadsDB", "RaresDB", "QuestsDB", "DungeonsDB", "Guides", "RecipeDB"]
KEEP = [os.path.join(HERE, "guides"), os.path.join(HERE, "dungeons")]  # données importées, versionnées
DROP_LIMIT = 0.20


def log(*a):
    print(*a, flush=True)


def run(*args):
    log("  $", " ".join(os.path.relpath(a, ROOT) if os.path.isabs(a) and a.startswith(ROOT) else a for a in args))
    subprocess.run([sys.executable, *args], cwd=ROOT, check=True)


def fetch(url, dest):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                data = r.read()
            with open(dest, "wb") as f:
                f.write(data)
            time.sleep(0.3)
            return True
        except Exception as e:  # réseau capricieux : on réessaie
            err = e
            time.sleep(2 ** attempt)
    log("  ! échec :", url, err)
    return False


def git(*args, cwd=None):
    out = subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True, text=True).stdout
    return out.rstrip() if args[0] == "status" else out.strip()  # status : l'espace de tête compte


def questie(path):
    if path:
        return path, git("rev-parse", "--short", "HEAD", cwd=path)
    dest = os.path.join(CACHE, "QuestieDB")
    if os.path.isdir(os.path.join(dest, ".git")):
        git("fetch", "-q", "--depth", "1", "origin", cwd=dest)
        git("reset", "-q", "--hard", "FETCH_HEAD", cwd=dest)
    else:
        os.makedirs(CACHE, exist_ok=True)
        subprocess.run(["git", "clone", "-q", "--depth", "1", QUESTIE_URL, dest], check=True)
    return dest, git("rev-parse", "--short", "HEAD", cwd=dest)


# ---------------------------------------------------------------------------
# Chiffres de chaque fichier généré (chargé avec lupa : sert aussi de contrôle)
# ---------------------------------------------------------------------------
def metrics():
    import lupa
    out = {}
    for name in TARGETS:
        path = os.path.join(ROOT, "Modules", name + ".lua")
        if not os.path.exists(path):
            continue
        L = lupa.LuaRuntime(unpack_returned_tuples=True)
        with open(path, encoding="utf-8") as f:
            src = f.read()
        fn = L.eval("function(src) local f, e = load(src) if not f then error(e) end local WK = {} f('WarbandKeeper', WK) return WK end")
        WK = fn(src)
        g = L.globals()
        count = L.eval("function(t) local n = 0 for _, v in pairs(t or {}) do n = n + #v end return n end")
        size = L.eval("function(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end")
        if name == "PlacesDB":
            out["Lieux (boîtes, marchands, maîtres…)"] = count(WK.PlacesDB)
        elif name == "RoadsDB":
            out["Chemins de base"] = count(WK.RoadsDB)
        elif name == "RaresDB":
            out["Rares"] = count(WK.RaresDB)
        elif name == "QuestsDB":
            out["Quêtes"] = count(WK.QuestsDB)
        elif name == "Guides":
            out["Guides de métiers"] = size(WK.Guides)
        elif name == "RecipeDB":
            out["Recettes"] = count(WK.RecipeDB)
        elif name == "DungeonsDB":
            stats = L.eval("""function(db, items)
                local d, b, nb, it, und = 0, 0, 0, 0, 0
                for _, x in ipairs(db or {}) do
                    d = d + 1
                    for _, y in ipairs(x.bosses) do b = b + 1; if y[1] == 0 then nb = nb + 1 end; it = it + #y[5] end
                end
                for _, v in pairs(items or {}) do if v[5] then und = und + 1 end end
                return d, b, nb, it, und end""")
            d, b, nb, it, und = stats(WK.DungeonsDB, WK.DungeonItems)
            out["Donjons et raids"] = d
            out["Boss"] = b
            out["Boss sans n° de PNJ (appris en jeu)"] = nb
            out["Objets de butin des boss"] = it
            out["Objets pas encore découverts"] = und
    return out


# Ces chiffres-là baissent quand c'est une bonne nouvelle
GOOD_DOWN = {"Boss sans n° de PNJ (appris en jeu)", "Objets pas encore découverts"}


def main():
    args = sys.argv[1:]
    opt = lambda k: args[args.index(k) + 1] if k in args else None
    summary_path = opt("--summary")
    do_questie, do_wowtbc = "--sans-questie" not in args, "--sans-wowtbc" not in args

    backup = tempfile.mkdtemp(prefix="wk-backup-")
    for name in TARGETS:
        src = os.path.join(ROOT, "Modules", name + ".lua")
        if os.path.exists(src):
            shutil.copy2(src, backup)
    for d in KEEP:
        if os.path.isdir(d):
            shutil.copytree(d, os.path.join(backup, os.path.basename(d)))

    def restore():
        for name in TARGETS:
            src = os.path.join(backup, name + ".lua")
            if os.path.exists(src):
                shutil.copy2(src, os.path.join(ROOT, "Modules"))
        for d in KEEP:
            b = os.path.join(backup, os.path.basename(d))
            if os.path.isdir(b):
                shutil.rmtree(d, ignore_errors=True)
                shutil.copytree(b, d)

    before = metrics()
    sources = []
    try:
        if do_questie:
            log("QuestieDB")
            qpath, qrev = questie(opt("--questie"))
            sources.append("QuestieDB `%s`" % qrev)
            for gen in ["gen_places.py", "gen_roads.py", "gen_rares.py", "gen_quests.py"]:
                run(os.path.join(HERE, gen), qpath)
        if do_wowtbc:
            log("wowtbc.gg")
            tmp = tempfile.mkdtemp(prefix="wk-wowtbc-")
            # guides de métiers : ceux qu'on a déjà
            pages = []
            for f in sorted(glob.glob(os.path.join(HERE, "guides", "*.json"))):
                slug = os.path.splitext(os.path.basename(f))[0]
                dest = os.path.join(tmp, "guide-" + slug + ".json")
                if fetch("%s/professions/%s/page-data.json" % (WOWTBC, slug), dest):
                    pages.append(dest)
            if pages:
                run(os.path.join(HERE, "gen_guides.py"), "--import", *pages)
            # tables de butin : liste des donjons et raids lue sur le site
            ldir = os.path.join(tmp, "loot")
            os.makedirs(ldir)
            slugs = set()
            for kind in ("dungeons", "raids"):
                idx = os.path.join(tmp, kind + ".json")
                if fetch("%s/loot-tables/%s/page-data.json" % (WOWTBC, kind), idx):
                    slugs |= set(re.findall(r"loot-tables/(?:dungeons|raids)/[a-z0-9-]+", open(idx, encoding="utf-8").read()))
            for s in sorted(slugs):
                fetch("%s/%s/page-data.json" % (WOWTBC, s), os.path.join(ldir, s.replace("/", "_") + ".json"))
            if slugs:
                run(os.path.join(HERE, "gen_dungeons.py"), "--import", ldir)
            sources.append("wowtbc.gg (%d guides, %d tables de butin)" % (len(pages), len(slugs)))
        if do_questie:
            run(os.path.join(HERE, "gen_dungeons.py"), qpath)
        after = metrics()
    except Exception as e:
        log("ÉCHEC :", e, "-> fichiers remis comme avant")
        restore()
        sys.exit(2)

    # contrôle : un chiffre qui s'effondre = une source a changé de format
    broken = []
    for k, v in before.items():
        a = after.get(k)
        if k in GOOD_DOWN:
            continue
        if a is None or (v >= 20 and a < v * (1 - DROP_LIMIT)):
            broken.append("%s : %s » %s" % (k, v, a))
    if broken:
        log("CHIFFRES EN CHUTE, fichiers remis comme avant :")
        for b in broken:
            log("  -", b)
        restore()
        sys.exit(2)
    shutil.rmtree(backup, ignore_errors=True)

    # résumé
    changed = git("status", "--porcelain", "--", "Modules", "tools/guides", "tools/dungeons", cwd=ROOT)
    lines = ["## Mise à jour des données (%s)" % time.strftime("%d/%m/%Y"), "",
             "Sources : " + ", ".join(sources), "",
             "| | Avant | Après | Écart |", "|---|---:|---:|---:|"]
    for k in after:
        v, a = before.get(k, 0), after[k]
        d = a - v
        lines.append("| %s | %s | %s | %s |" % (k, v, a, ("+%d" % d) if d > 0 else (str(d) if d else "=")))
    lines += ["", "Fichiers modifiés :" if changed else "Aucun fichier modifié.", ""]
    for l in changed.splitlines():
        lines.append("- `%s`" % l[3:])
    lines += ["", "Rien n'est publié tout seul : à intégrer puis publier comme une version (changelog, version, zip)."]
    text = "\n".join(lines) + "\n"
    log("")
    log(text)
    if summary_path:
        with open(summary_path, "w", encoding="utf-8") as f:
            f.write(text)


if __name__ == "__main__":
    main()
