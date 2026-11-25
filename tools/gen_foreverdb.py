#!/usr/bin/env python3
"""Génère Modules/ForeverVendorsDB.lua depuis l'API de ForeverDB (https://foreverdb.net/developers).

Usage : python3 tools/gen_foreverdb.py --fetch      télécharge les marchands dans tools/.cache/foreverdb
        python3 tools/gen_foreverdb.py              écrit Modules/ForeverVendorsDB.lua depuis le cache

Clé : en-tête X-API-Key, lue dans la variable FOREVERDB_KEY (GitHub Actions) ; sans elle, une valeur factice
est envoyée (le proxy de la session cloud la remplace par la vraie clé). Limites du compte gratuit : 30 requêtes
par minute, 5 000 par jour : les en-têtes X-Ratelimit-* et X-Daily-Remaining sont suivis. Un marchand déjà en
cache pour la même version du jeu n'est pas redemandé.

Données : seulement les marchands et les objets **vus dans WoW Forever** par les joueurs (seenInForever) ; la
mention « Data from ForeverDB.net (https://foreverdb.net) » est obligatoire partout où elles sont montrées
(en-tête du fichier généré, Options > À propos, lignes d'infobulle). Seuls des nombres et des positions sont
repris, jamais leurs textes. Noms des PNJ : français de QuestieDB / Everloot (`WK.EverNpcs`) en jeu.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "Modules", "ForeverVendorsDB.lua")
CACHE = os.path.join(HERE, ".cache", "foreverdb")
BASE = "https://foreverdb.net/api/v1/"
UA = "WarbandKeeper-data-update (WoW addon data tool)"
ATTRIB = "Data from ForeverDB.net (https://foreverdb.net)"


class Api:
    def __init__(self):
        self.key = os.environ.get("FOREVERDB_KEY") or "fdb_proxy"
        self.minute_left = 30
        self.reset_at = 0
        self.day_left = None
        self.calls = 0

    def get(self, path):
        for attempt in range(6):
            if self.day_left is not None and self.day_left <= 5:
                raise RuntimeError("quota du jour presque épuisé (%d)" % self.day_left)
            if self.minute_left <= 1 and self.reset_at:
                time.sleep(max(1, self.reset_at - time.time() + 1))
            req = urllib.request.Request(BASE + path, headers={"User-Agent": UA, "X-API-Key": self.key,
                                                               "Accept": "application/json"})
            try:
                with urllib.request.urlopen(req, timeout=60) as r:
                    self._limits(r.headers)
                    self.calls += 1
                    return json.loads(r.read().decode("utf-8"))
            except urllib.error.HTTPError as e:
                self._limits(e.headers)
                if e.code == 429:
                    wait = int(e.headers.get("Retry-After") or 30)
                    time.sleep(wait + 1)
                    continue
                if e.code in (500, 502, 503, 504):
                    time.sleep(5 * (attempt + 1))
                    continue
                raise RuntimeError("%s : HTTP %d %s" % (path, e.code, e.read()[:200]))
            except (urllib.error.URLError, TimeoutError) as e:
                time.sleep(5 * (attempt + 1))
                last = e
        raise RuntimeError("%s : pas de réponse" % path)

    def _limits(self, h):
        if not h:
            return
        try:
            if h.get("X-Ratelimit-Remaining") is not None:
                self.minute_left = int(h.get("X-Ratelimit-Remaining"))
            if h.get("X-Ratelimit-Reset") is not None:
                self.reset_at = int(h.get("X-Ratelimit-Reset"))
            if h.get("X-Daily-Remaining") is not None:
                self.day_left = int(h.get("X-Daily-Remaining"))
        except ValueError:
            pass


def fetch(dest=CACHE):
    api = Api()
    vdir = os.path.join(dest, "vendors")
    os.makedirs(vdir, exist_ok=True)
    meta = api.get("meta")
    build = meta["data"]["build"]
    with open(os.path.join(dest, "meta.json"), "w", encoding="utf-8") as f:
        json.dump(meta["data"], f)
    # liste (100 par page)
    vendors, off = [], 0
    while True:
        page = api.get("vendors?limit=100&offset=%d" % off)
        vendors += page["data"]
        off += 100
        if not page["meta"].get("next") or off >= page["meta"].get("total", 0):
            break
    with open(os.path.join(dest, "vendors.json"), "w", encoding="utf-8") as f:
        json.dump(vendors, f)
    todo = [v for v in vendors if v.get("seenInForever")]
    print("marchands : %d dont %d vus dans Forever ; version %s" % (len(vendors), len(todo), build), flush=True)
    for i, v in enumerate(todo):
        path = os.path.join(vdir, "%d.json" % v["id"])
        if os.path.exists(path):
            try:
                with open(path, encoding="utf-8") as f:
                    if json.load(f).get("_build") == build:
                        continue
            except (ValueError, OSError):
                pass
        d = api.get("vendors/%d" % v["id"])["data"]
        d["_build"] = build
        with open(path, "w", encoding="utf-8") as f:
            json.dump(d, f)
        if i % 50 == 0:
            print("  %d / %d (reste aujourd'hui : %s)" % (i, len(todo), api.day_left), flush=True)
    print("fini : %d requêtes" % api.calls, flush=True)


PROFS = ["alchemy", "blacksmithing", "enchanting", "engineering", "leatherworking", "tailoring",
         "herbalism", "mining", "skinning", "cooking", "first-aid", "fishing"]


def fetch_professions(api=None, dest=CACHE):
    """Métiers : rangs, maîtres et recettes (100 par page) ; un métier déjà lu pour la même version est gardé."""
    api = api or Api()
    pdir = os.path.join(dest, "professions")
    os.makedirs(pdir, exist_ok=True)
    build = api.get("meta")["data"]["build"]
    for slug in PROFS:
        path = os.path.join(pdir, slug + ".json")
        if os.path.exists(path):
            try:
                with open(path, encoding="utf-8") as f:
                    if json.load(f).get("_build") == build:
                        continue
            except (ValueError, OSError):
                pass
        off, data, recipes = 0, None, []
        while True:
            page = api.get("professions/%s?limit=100&offset=%d" % (slug, off))
            data = data or page["data"]
            recipes += page["data"].get("recipes") or []
            off += 100
            if not page["meta"].get("next") or off >= (page["meta"].get("total") or 0):
                break
        data["recipes"] = recipes
        data["_build"] = build
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f)
        print("  %s : %d recettes, %d maîtres" % (slug, len(recipes), len(data.get("trainers") or [])), flush=True)
    print("métiers : %d requêtes" % api.calls, flush=True)


def fetch_quests(api=None, dest=CACHE):
    """Quêtes (100 par page, donneur, rendu, chaîne) : une seule liste, gardée pour la même version du jeu."""
    api = api or Api()
    path = os.path.join(dest, "quests.json")
    build = api.get("meta")["data"]["build"]
    if os.path.exists(path):
        try:
            with open(path, encoding="utf-8") as f:
                if json.load(f).get("_build") == build:
                    print("quêtes : déjà à jour", flush=True)
                    return
        except (ValueError, OSError):
            pass
    quests, off = [], 0
    while True:
        page = api.get("quests?limit=100&offset=%d" % off)
        quests += page["data"]
        off += 100
        if not page["meta"].get("next") or off >= (page["meta"].get("total") or 0):
            break
    with open(path, "w", encoding="utf-8") as f:
        json.dump({"_build": build, "quests": quests}, f)
    print("quêtes : %d (%d requêtes)" % (len(quests), api.calls), flush=True)


def quest_points(src=CACHE):
    """Donneur et rendu des quêtes **vus dans WoW Forever** (cache de --fetch-quests), pour gen_quests.py et
    gen_objectives.py : { quête: {"start": (genre, n°, carte, x, y) ou None, "end": (…) ou None} } ; {} sans cache."""
    path = os.path.join(src, "quests.json")
    if not os.path.exists(path):
        return {}
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except (ValueError, OSError):
        return {}
    out = {}

    def pt(e):
        if not e or e.get("instance") or e.get("type") not in ("npc", "object") or not e.get("id"):
            return None
        loc = e.get("location") or {}
        if not str(loc.get("source") or "").startswith("seen in WoW Forever"):
            return None
        if loc.get("uiMapId") is None or loc.get("x") is None or loc.get("y") is None:
            return None
        return (e["type"], int(e["id"]), int(loc["uiMapId"]), round(float(loc["x"]), 1), round(float(loc["y"]), 1))
    for q in data.get("quests") or []:
        s, e = pt(q.get("starts")), pt(q.get("ends"))
        if s or e:
            out[int(q["id"])] = {"start": s, "end": e}
    return out


def fetch_bis(api=None, dest=CACHE):
    """Listes BiS par spécialisation (niveau max) : JcE, et JcJ pour chaque camp ; gardées pour la même version."""
    api = api or Api()
    bdir = os.path.join(dest, "bis")
    os.makedirs(bdir, exist_ok=True)
    build = api.get("meta")["data"]["build"]
    specs = api.get("bis")["data"]
    with open(os.path.join(dest, "bis.json"), "w", encoding="utf-8") as f:
        json.dump(specs, f)
    for sp in specs:
        for mode, side in (("pve", None), ("pvp", "a"), ("pvp", "h")):
            name = "%s-%s%s.json" % (sp["id"], mode, ("-" + side) if side else "")
            path = os.path.join(bdir, name)
            if os.path.exists(path):
                try:
                    with open(path, encoding="utf-8") as f:
                        if json.load(f).get("_build") == build:
                            continue
                except (ValueError, OSError):
                    pass
            q = "bis/%s?mode=%s" % (sp["id"], mode) + (("&side=" + side) if side else "")
            d = api.get(q)["data"]
            d["_build"] = build
            with open(path, "w", encoding="utf-8") as f:
                json.dump(d, f)
    print("BiS : %d spécialisations (%d requêtes)" % (len(specs), api.calls), flush=True)


def fr_names(root):
    """Noms français des PNJ (QuestieDB, comme tools/gen_places.py) ; {} sans clone ni lupa."""
    try:
        import lupa
    except ImportError:
        return {}
    path = os.path.join(root, "l10n", "Forever", "lookupNpcs", "frFR.lua")
    if not os.path.exists(path):
        return {}
    L = lupa.LuaRuntime(unpack_returned_tuples=True)
    L.execute('L10N={npcNameLookup={}}; loadstring=load; GetLocale=function() return "frFR" end\n'
              'QuestieLoader={ImportModule=function(_,n) return L10N end}')
    with open(path, encoding="utf-8") as f:
        L.execute(f.read())
    fr = L.globals().L10N.npcNameLookup["frFR"]
    if lupa.lua_type(fr) == "function":
        fr = fr()
    out = {}
    for k, v in fr.items():
        name = v[1] if lupa.lua_type(v) == "table" else v
        if isinstance(name, str) and name:
            out[int(k)] = name
    return out


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ") + '"'


SIDE = {"Alliance": 1, "Horde": 2}


def generate(questie=None, src=CACHE, out=OUT):
    with open(os.path.join(src, "meta.json"), encoding="utf-8") as f:
        meta = json.load(f)
    fr = fr_names(questie) if questie else {}
    npcs, sells = {}, {}
    vdir = os.path.join(src, "vendors")
    for fn in sorted(os.listdir(vdir)):
        if not fn.endswith(".json"):
            continue
        with open(os.path.join(vdir, fn), encoding="utf-8") as f:
            v = json.load(f)
        if not v.get("seenInForever") or v.get("mapId") is None or v.get("x") is None:
            continue
        got = False
        for it in v.get("sells") or []:
            if not it.get("seenInForever") or it.get("costs"):
                continue
            p = it.get("pricePerItem")
            if p is None or p <= 0:
                continue
            sells.setdefault(int(it["itemId"]), []).append((int(v["id"]), int(round(p))))
            got = True
        if got:
            npcs[int(v["id"])] = (int(v["mapId"]), round(float(v["x"]), 1), round(float(v["y"]), 1),
                                  SIDE.get(v.get("side"), 3), v.get("name") or "", fr.get(int(v["id"])))
    lines = [
        "local ADDON_NAME, WK = ...",
        "-- GÉNÉRÉ par tools/gen_foreverdb.py : ne pas modifier à la main.",
        "-- " + ATTRIB + " : marchands et objets vus dans WoW Forever par les joueurs de ForeverDB",
        "-- (API https://foreverdb.net/developers, version du jeu %s). Mention obligatoire, avec le lien," % meta.get("build"),
        "-- partout où ces données sont montrées (Options > À propos, infobulles : Modules/Vendors.lua).",
        "-- Noms français des PNJ : QuestieDB (GPLv3).",
        "-- WK.FVendorNpc[pnj] = { carte, x, y, camp (1 Alliance, 2 Horde, 3 les deux), nom anglais, nom français }",
        "-- WK.FVendorSells[objet] = \"pnj:prix,…\" (prix d'un objet en cuivre)",
        "WK.FVendorBuild = %s" % lua_str(meta.get("build") or ""),
        "WK.FVendorNpc = {",
    ]
    for nid in sorted(npcs):
        m, x, y, side, en, frn = npcs[nid]
        lines.append("    [%d] = { %d, %s, %s, %d, %s%s }," % (nid, m, x, y, side, lua_str(en),
                                                         (", " + lua_str(frn)) if frn else ""))
    lines.append("}")
    lines.append("WK.FVendorSells = {")
    for iid in sorted(sells):
        lines.append("    [%d] = \"%s\"," % (iid, ",".join("%d:%d" % (n, p) for n, p in sorted(sells[iid], key=lambda t: t[1]))))
    lines.append("}")
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print("ForeverVendorsDB.lua : %d marchands, %d objets" % (len(npcs), len(sells)))
    return {"vendors": len(npcs), "items": len(sells)}


PROF_OUT = os.path.join(HERE, "..", "Modules", "ForeverProfDB.lua")


def generate_prof(questie=None, src=CACHE, out=PROF_OUT):
    """Maîtres et recettes des métiers : seulement ce que les joueurs ont vu dans Forever (lieu, prix)."""
    pdir = os.path.join(src, "professions")
    if not os.path.isdir(pdir):
        print("ForeverProfDB.lua : pas de cache des métiers, rien d'écrit")
        return None
    fr = fr_names(questie) if questie else {}
    npcs, trainers, recipes, build = {}, {}, {}, ""
    side_of = {"alliance": 1, "horde": 2, "both": 3, "Alliance": 1, "Horde": 2, "Both": 3}

    def npc(e):
        nid = int(e["npcId"])
        if nid not in npcs and e.get("mapId") is not None and e.get("x") is not None:
            npcs[nid] = (int(e["mapId"]), round(float(e["x"]), 1), round(float(e["y"]), 1),
                         side_of.get(e.get("side") or e.get("faction"), 3), e.get("name") or "", fr.get(nid))
        return nid if nid in npcs else None

    for pi, slug in enumerate(PROFS, 1):
        path = os.path.join(pdir, slug + ".json")
        if not os.path.exists(path):
            continue
        with open(path, encoding="utf-8") as f:
            d = json.load(f)
        build = d.get("_build") or build
        tl = []
        for t in d.get("trainers") or []:
            if t.get("placeSeenInForever") and npc(t):
                tl.append((int(t["npcId"]), int(t.get("trainsUpToSkill") or 0)))
        trainers[slug] = tl
        for r in d.get("recipes") or []:
            lf = r.get("learnedFrom") or {}
            so = lf.get("sources") or {}
            tr = [npc(t) for side in (so.get("trainers") or {}).values() for t in side if t.get("seenInForever")]
            tr = sorted(set(x for x in tr if x))
            vd = []
            for side in (so.get("vendors") or {}).values():
                for v in side:
                    if v.get("seenInForever") and not v.get("costs") and v.get("pricePerItem") and npc(v):
                        vd.append((int(v["npcId"]), int(round(v["pricePerItem"]))))
            vd = sorted(set(vd), key=lambda t: t[1])
            cost = so.get("trainerCost") or (lf.get("trainer") or {}).get("cost") or 0
            seen = 1 if str(so.get("trainerCostSource") or "").startswith("seen") else 0
            ri = (so.get("recipeItem") or {}).get("itemId") or 0
            learn = so.get("learnAtSkill") or (r.get("skill") or {}).get("orange") or 0
            if not tr and not vd and not cost:
                continue
            recipes[int(r["spellId"])] = "%d|%d|%d|%d|%d|%s|%s" % (
                pi, learn, cost, seen, ri, ",".join(str(x) for x in tr), ",".join("%d:%d" % t for t in vd))
    lines = [
        "local ADDON_NAME, WK = ...",
        "-- GÉNÉRÉ par tools/gen_foreverdb.py : ne pas modifier à la main.",
        "-- " + ATTRIB + " : maîtres de métier et recettes vus dans WoW Forever par les joueurs de ForeverDB",
        "-- (API https://foreverdb.net/developers, version du jeu %s). Mention obligatoire, avec le lien," % build,
        "-- partout où ces données sont montrées (Options > À propos, infobulles : Modules/Vendors.lua).",
        "-- Noms français des PNJ : QuestieDB (GPLv3).",
        "-- WK.FProfNpc[pnj] = { carte, x, y, camp (1 Alliance, 2 Horde, 3 les deux), nom anglais, nom français }",
        "-- WK.FProfTrainers[métier] = { { pnj, enseigne jusqu'à (0 = inconnu) }, … }",
        "-- WK.FRecipes[sort] = \"métier|apprise à|prix du maître|prix vu (1/0)|objet de recette|maîtres|pnj:prix,…\"",
        "WK.FProfSlugs = { %s }" % ", ".join(lua_str(x) for x in PROFS),
        "WK.FProfNpc = {",
    ]
    for nid in sorted(npcs):
        m, x, y, side, en, frn = npcs[nid]
        lines.append("    [%d] = { %d, %s, %s, %d, %s%s }," % (nid, m, x, y, side, lua_str(en),
                                                         (", " + lua_str(frn)) if frn else ""))
    lines.append("}")
    lines.append("WK.FProfTrainers = {")
    for slug in PROFS:
        if trainers.get(slug):
            lines.append("    [%s] = { %s }," % (lua_str(slug), ", ".join("{ %d, %d }" % t for t in trainers[slug])))
    lines.append("}")
    lines.append("WK.FRecipes = {")
    for sid in sorted(recipes):
        lines.append("    [%d] = %s," % (sid, lua_str(recipes[sid])))
    lines.append("}")
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print("ForeverProfDB.lua : %d PNJ, %d recettes" % (len(npcs), len(recipes)))
    return {"npcs": len(npcs), "recipes": len(recipes)}


BIS_OUT = os.path.join(HERE, "..", "Data", "BiSSpecDB.lua")
BIS_SLOT = {"head": 1, "neck": 2, "shoulder": 3, "back": 15, "chest": 5, "wrist": 9, "hands": 10, "waist": 6,
            "legs": 7, "feet": 8, "finger1": 11, "finger2": 12, "trinket1": 13, "trinket2": 14, "main": 16, "off": 17,
            "ranged": 18}
BIS_EASE = {"easy": "e", "some effort": "m", "hard": "h", "very hard": "h", "source not known yet": "u"}
SPEC_FR = {"arms": "Armes", "fury": "Fureur", "protection": "Protection", "holy": "Sacré", "retribution": "Vindicte",
           "beast-mastery": "Maîtrise des bêtes", "marksmanship": "Précision", "survival": "Survie",
           "assassination": "Assassinat", "combat": "Combat", "subtlety": "Finesse", "discipline": "Discipline",
           "shadow": "Ombre", "elemental": "Élémentaire", "enhancement": "Amélioration",
           "restoration": "Restauration", "arcane": "Arcanes", "fire": "Feu", "frost": "Givre",
           "affliction": "Affliction", "demonology": "Démonologie", "destruction": "Destruction",
           "balance": "Équilibre", "feral": "Combat farouche", "feral-cat": "Farouche (félin)",
           "feral-bear": "Farouche (ours)", "guardian": "Gardien"}


def generate_bis(src=CACHE, out=BIS_OUT):
    """Listes BiS de ForeverDB par spécialisation (Data/BiSSpecDB.lua, chargé à la demande) : seulement des n°
    d'objets, d'enchantements et une note de difficulté, jamais leurs textes."""
    path = os.path.join(src, "bis.json")
    if not os.path.exists(path):
        print("BiSSpecDB.lua : pas de cache BiS, rien d'écrit")
        return None
    with open(path, encoding="utf-8") as f:
        specs = json.load(f)
    by_class, items, build = {}, {}, ""

    def ease(e):
        return BIS_EASE.get(str(e or "").lower(), "?")
    for sp in specs:
        cls = str(sp.get("class") or "").upper().replace(" ", "")
        sid = sp["id"]
        suffix = sid.split("-", 1)[1] if "-" in sid else sid
        role = ""
        for mode, side in (("pve", None), ("pvp", "a"), ("pvp", "h")):
            name = "%s-%s%s.json" % (sid, mode, ("-" + side) if side else "")
            fp = os.path.join(src, "bis", name)
            if not os.path.exists(fp):
                continue
            with open(fp, encoding="utf-8") as f:
                d = json.load(f)
            build = d.get("_build") or build
            role = role or d.get("role") or ""
            parts = []
            for sl in d.get("slots") or []:
                n = BIS_SLOT.get(sl.get("slot"))
                best = sl.get("best") or {}
                if not n or not best.get("itemId"):
                    continue
                ids = ["%d:%s" % (best["itemId"], ease(best.get("ease")))]
                for a in (sl.get("alternatives") or [])[:2]:
                    if a.get("itemId"):
                        ids.append("%d:%s" % (a["itemId"], ease(a.get("ease"))))
                enh = ""
                for e in sl.get("enhancements") or []:
                    if e.get("rank") == 1:
                        if e.get("spellId"):
                            enh = "s%d" % e["spellId"]
                        elif e.get("itemId"):
                            enh = "i%d" % e["itemId"]
                        break
                parts.append("%d=%s%s" % (n, ",".join(ids), ("|" + enh) if enh else ""))
            if parts:
                items["%s:%s" % (sid, mode + ("-" + side if side else ""))] = ";".join(parts)
        by_class.setdefault(cls, []).append((sid, sp.get("spec") or suffix, SPEC_FR.get(suffix), role))
    lines = [
        "-- FICHIER GÉNÉRÉ par tools/gen_foreverdb.py : ne pas modifier à la main.",
        "-- Listes BiS par spécialisation (niveau max) : " + ATTRIB + ", API https://foreverdb.net/developers,",
        "-- version du jeu %s. Mention obligatoire, avec le lien, partout où elles sont montrées." % build,
        "local WK = WarbandKeeper -- table de l'addon principal (dossier chargé à la demande)",
        "-- WK.BiSSpecs[CLASSE] = { { id, spécialisation (anglais), français, rôle }, … }",
        "-- WK.BiSSpecItems[\"id:pve\" | \"id:pvp-a\" | \"id:pvp-h\"] = \"emplacement=objet:facilité,alt:f,alt:f|i/s enchant;…\"",
        "--   facilité : e facile, m un peu d'effort, h difficile, u source inconnue ; enchant : i = objet, s = sort",
        "WK.BiSSpecs = {",
    ]
    for cls in sorted(by_class):
        rows = ", ".join("{ %s, %s, %s, %s }" % (lua_str(a), lua_str(b), lua_str(c) if c else "nil", lua_str(r))
                         for a, b, c, r in by_class[cls])
        lines.append("    %s = { %s }," % (cls, rows))
    lines.append("}")
    lines.append("WK.BiSSpecItems = {")
    for k in sorted(items):
        lines.append("    [%s] = %s," % (lua_str(k), lua_str(items[k])))
    lines.append("}")
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print("BiSSpecDB.lua : %d classes, %d listes" % (len(by_class), len(items)))
    return {"specs": sum(len(v) for v in by_class.values()), "lists": len(items)}


if __name__ == "__main__":
    if "--fetch-prof" in sys.argv:
        fetch_professions()
    elif "--fetch-quests" in sys.argv:
        fetch_quests()
    elif "--fetch-bis" in sys.argv:
        fetch_bis()
    elif "--fetch" in sys.argv:
        fetch()
        fetch_professions()
        fetch_quests()
        fetch_bis()
    else:
        args = [a for a in sys.argv[1:] if not a.startswith("--")]
        generate(args[0] if args else None)
        generate_prof(args[0] if args else None)
        generate_bis()
