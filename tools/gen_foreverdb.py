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


if __name__ == "__main__":
    if "--fetch" in sys.argv:
        fetch()
    else:
        args = [a for a in sys.argv[1:] if not a.startswith("--")]
        generate(args[0] if args else None)
