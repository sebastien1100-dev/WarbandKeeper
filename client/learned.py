# -*- coding: utf-8 -*-
"""Découvertes : ce que l'addon a appris en jeu, intégré à l'addon pour tout le monde.

Partagé par le client PC (page « Découvertes ») et tools/gen_learned.py :
  * read_save(texte)        : lit WarbandKeeper.lua (SavedVariables) comme du texte (jamais exécuté) ;
  * extract(db)             : garde seulement ce que l'addon a appris (jamais persos, or, sacs, courrier),
                              par genre (GENRES) et par clé ;
  * export_wkd / read_wkd   : fichier .wkd (JSON) qu'un autre joueur envoie au mainteneur ;
  * merge(sources, base)    : fusion de plusieurs sources : statut de chaque découverte (intégrée, en attente
                              d'une 2e confirmation, à vérifier, rejetée, déjà connue) ;
  * build(base, rows)       : nouvelle base = ancienne + découvertes intégrées ;
  * to_lua(base)            : Modules/LearnedDB.lua (WK.LearnedDB), lu par Modules/Learned.lua au démarrage.
"""
import hashlib
import json
import math
import re
import time

VERSION = 1

# genre : (libellé, chemin dans WarbandKeeperDB, sûr = une seule confirmation suffit)
GENRES = [
    ("quests", "Quêtes apprises", False),
    ("chains", "Chaînes de quêtes", False),
    ("bossIds", "Boss (n° de PNJ)", False),
    ("bossNames", "Noms de boss", False),
    ("instNames", "Noms d'instances", True),
    ("inst", "Instances reconnues", True),
    ("flightTimes", "Vols : durées", True),
    ("flightPaths", "Vols : tracés", True),
    ("tram", "Tram : stations", True),
    ("trails", "Chemins appris", True),
    ("camp", "Feu de camp : effets", True),
    ("campIcons", "Feu de camp : icônes", True),
    ("trainerPrices", "Prix des maîtres", True),
    ("vendorPrices", "Prix des marchands", True),
    ("gather", "Points de récolte", True),
]
LABEL = {g: l for g, l, _ in GENRES}
SAFE = {g for g, _, s in GENRES if s}


# --- Lecture de SavedVariables (texte Lua, jamais exécuté) ---------------------------------------
def parse_lua(text):
    """Valeurs `nom = { ... }` d'un fichier SavedVariables. Tables à clés et listes : des dict (listes = clés 1..n)."""
    i, n = 0, len(text)

    def ws():
        nonlocal i
        while i < n:
            c = text[i]
            if c in " \t\r\n,;":
                i += 1
            elif text.startswith("--", i):
                j = text.find("\n", i)
                i = n if j < 0 else j
            else:
                break

    def string():
        nonlocal i
        q = text[i]
        i += 1
        out = []
        while i < n:
            c = text[i]
            if c == "\\":
                if i + 1 >= n:  # fichier coupé juste après une barre oblique
                    i = n
                    break
                nx = text[i + 1]
                if nx == "n":
                    out.append("\n"); i += 2
                elif nx.isdigit():
                    m = re.match(r"\d{1,3}", text[i + 1:i + 4])
                    out.append(chr(int(m.group()))); i += 1 + len(m.group())
                else:
                    out.append(nx); i += 2
            elif c == q:
                i += 1
                break
            else:
                out.append(c); i += 1
        s = "".join(out)
        try:  # octets UTF-8 écrits en \ddd par le jeu
            s = s.encode("latin-1").decode("utf-8")
        except (UnicodeEncodeError, UnicodeDecodeError):
            pass
        return s

    # nombres, y compris les formes écrites par le jeu sous Windows : -nan(ind), 1.#INF, 1.#QNAN
    num = re.compile(r"-?(?:0x[0-9a-fA-F]+|\d+\.#(?:INF|IND|QNAN|SNAN)\d*|\d+\.?\d*(?:[eE][-+]?\d+)?"
                     r"|inf|nan(?:\(ind\))?)")

    def value():
        nonlocal i
        ws()
        c = text[i]
        if c == "{":
            return table()
        if c in "\"'":
            return string()
        m = num.match(text, i)
        if m and m.group():
            i = m.end()
            s = m.group()
            if "#" in s or "(" in s:
                return 0.0
            try:
                return int(s, 0) if re.fullmatch(r"-?(0x[0-9a-fA-F]+|\d+)", s) else float(s)
            except ValueError:
                return 0
        for w, v in (("true", True), ("false", False), ("nil", None)):
            if text.startswith(w, i):
                i += len(w)
                return v
        # jeton inconnu : sauté jusqu'au séparateur suivant (avant : toute la sauvegarde devenait illisible)
        m = re.compile(r"[^,;}\n]*").match(text, i)
        if m.end() == i:
            raise ValueError("valeur illisible à %d" % i)
        i = m.end()
        return None

    def table():
        nonlocal i
        i += 1
        d, k = {}, 1
        while True:
            ws()
            if i >= n:
                return d
            if text[i] == "}":
                i += 1
                return d
            if text[i] == "[":
                i += 1
                key = value()
                ws(); i += 1  # ]
                ws(); i += 1  # =
                d[key] = value()
            else:
                m = re.match(r"([A-Za-z_]\w*)\s*=", text[i:i + 80])
                if m and m.group(1) not in ("true", "false", "nil"):
                    i += m.end()
                    d[m.group(1)] = value()
                else:
                    d[k] = value()
                    k += 1

    res = {}
    while True:
        ws()
        if i >= n:
            break
        m = re.match(r"([A-Za-z_]\w*)\s*=", text[i:i + 80])
        if not m:
            break
        i += m.end()
        res[m.group(1)] = value()
    return res


def read_save(text):
    """WarbandKeeperDB lu dans le texte de WarbandKeeper.lua (ou {})."""
    return parse_lua(text).get("WarbandKeeperDB") or {}


def _list(t):
    """Liste Lua (dict à clés 1..n, ou list) en list Python."""
    if isinstance(t, list):
        return t
    if isinstance(t, dict):
        return [t[k] for k in sorted(k for k in t if isinstance(k, int))]
    return []


def _num(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v)


# --- Extraction : seulement ce qui est appris (rien de personnel) ---------------------------------
def extract(db):
    """{ genre: { clé (str): valeur } } depuis WarbandKeeperDB."""
    out = {g: {} for g, _, _ in GENRES}
    for q, e in (db.get("questLearn") or {}).items():
        if isinstance(e, dict) and e.get("n"):
            v = {k: e[k] for k in ("n", "l", "s", "k", "z") if k in e}
            for w in ("g", "t"):  # donneur, rendu
                t = e.get(w)
                if isinstance(t, dict):
                    v[w] = {k: t[k] for k in ("npc", "map", "x", "y") if k in t}
            out["quests"][str(q)] = v
    for q, e in (db.get("questChains") or {}).items():
        if isinstance(e, dict) and e.get("pre"):
            out["chains"][str(q)] = {"pre": e["pre"], "how": e.get("how")}
    dg = db.get("dungeons") or {}
    for k, v in (dg.get("bossIds") or {}).items():
        out["bossIds"][str(k)] = v
    for k, v in (dg.get("bossNames") or {}).items():
        out["bossNames"][str(k)] = v
    for k, v in (dg.get("names") or {}).items():
        out["instNames"][str(k)] = v
    for k, v in (dg.get("inst") or {}).items():
        out["inst"][str(k)] = v
    fl = db.get("flights") or {}
    for k, v in (fl.get("routes") or {}).items():
        out["flightTimes"][str(k)] = v
    for k, v in (fl.get("paths") or {}).items():
        if isinstance(v, dict):
            out["flightPaths"][str(k)] = {"c": v.get("c"), "pts": _list(v.get("pts"))}
    nav = db.get("nav") or {}
    for st in _list(nav.get("tramSt")):
        st = _list(st)
        if len(st) >= 3 and all(_num(x) for x in st[:3]):
            out["tram"]["%d:%d:%d" % (st[0], round(st[1] / 20), round(st[2] / 20))] = st[:3]
    for cont, segs in (nav.get("trails") or {}).items():
        for seg in _list(segs):
            seg = _list(seg)
            if len(seg) >= 4:
                key = "%s:%s" % (cont, hashlib.sha1(json.dumps(seg).encode()).hexdigest()[:12])
                out["trails"][key] = {"c": cont, "pts": seg}
    camp = db.get("camp") or {}
    for k, v in (camp.get("seen") or {}).items():
        out["camp"][str(k)] = v
    for k, v in (camp.get("icons") or {}).items():
        out["campIcons"][str(k)] = v
    for cls, prices in ((db.get("classSpells") or {}).get("prices") or {}).items():
        for k, v in (prices or {}).items():
            out["trainerPrices"]["%s|%s" % (cls, k)] = _list(v)
    for k, v in (db.get("vendorSeen") or {}).items():
        if isinstance(v, dict) and _num(v.get("p")) and v["p"] > 0:
            out["vendorPrices"][str(k)] = {"p": v["p"], "npc": v.get("npc")}
    for mp, pts in (db.get("gatherSpots") or {}).items():
        for p in _list(pts):
            if isinstance(p, dict) and _num(p.get("x")) and _num(p.get("y")) and p.get("i"):
                key = "%s:%s:%s:%d:%d" % (mp, p.get("k"), p.get("i"), round(p["x"] * 200), round(p["y"] * 200))
                out["gather"][key] = {"m": mp, "k": p.get("k"), "i": p.get("i"),
                                      "x": round(p["x"], 4), "y": round(p["y"], 4)}
    return out


# --- Contrôles : valeurs impossibles = rejetées ------------------------------------------------------
def _in01(v):
    return _num(v) and 0 <= v <= 1


def check(genre, key, v):
    """Raison du rejet, ou None si la valeur est plausible."""
    try:
        if genre == "quests":
            if not str(key).isdigit() or not isinstance(v.get("n"), str):
                return "numéro ou nom illisible"
            for w in ("g", "t"):
                t = v.get(w)
                if t and "x" in t and not (_in01(t.get("x")) and _in01(t.get("y"))):
                    return "position impossible"
        elif genre in ("bossIds",):
            if not (_num(v) and v > 0):
                return "numéro impossible"
        elif genre == "flightTimes":
            if not (_num(v) and 10 <= v <= 1800):
                return "durée impossible"
        elif genre in ("flightPaths", "trails"):
            pts = v.get("pts") or []
            if len(pts) < 4 or len(pts) % 2 or not all(_num(x) and abs(x) < 40000 for x in pts):
                return "tracé illisible"
        elif genre == "gather":
            if not (_in01(v.get("x")) and _in01(v.get("y"))):
                return "position impossible"
        elif genre == "vendorPrices":
            if not (_num(v.get("p")) and 0 < v["p"] < 10 ** 9):
                return "prix impossible"
        elif genre == "trainerPrices":
            if not (v and _num(v[0]) and 0 <= v[0] < 10 ** 8):
                return "prix impossible"
        elif genre in ("camp", "campIcons"):
            if v not in ("flame", "sit", "perk", "fed"):
                return "genre inconnu"
    except (AttributeError, TypeError, IndexError):
        return "valeur illisible"
    return None


def _same(genre, a, b):
    if genre == "flightTimes":
        return _num(a) and _num(b) and abs(a - b) <= max(5, 0.15 * max(a, b))
    if genre == "quests":
        return isinstance(a, dict) and isinstance(b, dict) and a.get("n") == b.get("n")
    if genre in ("vendorPrices",):
        return a.get("p") == b.get("p")
    return json.dumps(a, sort_keys=True) == json.dumps(b, sort_keys=True)


def short(genre, key, v):
    """Texte court d'une découverte pour la liste du client."""
    if genre == "quests":
        return "Quête %s « %s »" % (key, v.get("n"))
    if genre == "chains":
        return "Quête %s : après %s" % (key, v.get("pre"))
    if genre == "bossIds":
        return "Boss %s : PNJ %s" % (str(key).split(":", 1)[-1], v)
    if genre in ("bossNames", "instNames"):
        return "%s : %s" % (key, v)
    if genre == "flightTimes":
        return "Vol %s · %d min %02d" % (str(key).replace("|", " » "), int(v) // 60, int(v) % 60)
    if genre == "flightPaths":
        return "Tracé %s" % str(key).replace("|", " » ")
    if genre == "tram":
        return "Station du tram (%s)" % key
    if genre == "trails":
        return "Chemin (continent %s, %d points)" % (v.get("c"), len(v.get("pts") or []) // 2)
    if genre == "camp":
        return "Effet %s : %s" % (key, v)
    if genre == "campIcons":
        return "Icône %s : %s" % (key, v)
    if genre == "trainerPrices":
        return "Maître %s" % key
    if genre == "vendorPrices":
        return "Objet %s chez le marchand" % key
    if genre == "gather":
        return "Récolte %s (carte %s)" % (v.get("i"), v.get("m"))
    return "%s %s" % (genre, key)


# --- Fichier d'un autre joueur ------------------------------------------------------------------------
def export_wkd(data, src):
    """Texte du fichier .wkd : JSON, rien de personnel (src = identifiant aléatoire de l'installation)."""
    return json.dumps({"wkd": VERSION, "at": int(time.time()), "src": src, "data": data},
                      ensure_ascii=False, separators=(",", ":"))


def read_wkd(text):
    """(src, data) d'un fichier .wkd ; ValueError s'il est abîmé."""
    d = json.loads(text)
    if not isinstance(d, dict) or d.get("wkd") != VERSION or not isinstance(d.get("data"), dict):
        raise ValueError("fichier de découvertes illisible")
    data = {g: {} for g, _, _ in GENRES}
    for g in data:
        part = d["data"].get(g)
        if isinstance(part, dict):
            data[g] = {str(k): v for k, v in part.items()}
    return str(d.get("src") or "?"), data


# --- Fusion -----------------------------------------------------------------------------------------
INTEGRATED, PENDING, CHECK, REJECTED, KNOWN = "integrated", "pending", "check", "rejected", "known"
STATUS_LABEL = {INTEGRATED: "intégrée", PENDING: "en attente d'une 2e", CHECK: "à vérifier",
                REJECTED: "rejetée", KNOWN: "déjà connue"}


def merge(sources, base=None, choices=None):
    """sources = [{ name, trusted, data }] ; base = données déjà dans l'addon ({ genre: { clé: valeur } }) ;
    choices = { (genre, clé): n° de la valeur choisie } pour les « à vérifier » (et « en attente » : intégrée quand même).
    Rend [{ genre, key, value, values, srcs, status, reason }] (une ligne par découverte)."""
    base = base or {}
    choices = choices or {}
    seen = {}
    for s in sources:
        for g, part in (s.get("data") or {}).items():
            if g not in LABEL or not isinstance(part, dict):
                continue
            for k, v in part.items():
                e = seen.setdefault((g, k), {"vals": [], "srcs": [], "trusted": False, "bad": None})
                bad = check(g, k, v)
                if bad:
                    e["bad"] = e["bad"] or bad
                    if s["name"] not in e["srcs"]:
                        e["srcs"].append(s["name"])
                    continue
                if s["name"] not in e["srcs"]:
                    e["srcs"].append(s["name"])
                e["vals"].append(v)
                e["trusted"] = e["trusted"] or bool(s.get("trusted"))
    rows = []
    for (g, k), e in sorted(seen.items()):
        row = {"genre": g, "key": k, "srcs": e["srcs"], "values": [], "value": None, "reason": None}
        if not e["vals"]:
            row.update(status=REJECTED, reason=e["bad"])
            rows.append(row)
            continue
        groups = []  # valeurs différentes (les voisines comptent pour une)
        for v in e["vals"]:
            for grp in groups:
                if _same(g, grp[0], v):
                    grp.append(v)
                    break
            else:
                groups.append([v])
        row["values"] = [grp[0] for grp in groups]
        if g == "flightTimes":
            allv = [v for grp in groups for v in grp]
            row["value"] = round(sum(allv) / len(allv))
            groups = [allv]
        else:
            row["value"] = groups[0][0]
        known = (base.get(g) or {}).get(k)
        if len(groups) > 1:
            pick = choices.get((g, k))
            if pick is None:
                row.update(status=CHECK, reason="%d valeurs différentes" % len(groups))
                rows.append(row)
                continue
            row["value"] = row["values"][pick]
        if known is not None and _same(g, known, row["value"]):
            row["status"] = KNOWN
        elif e["trusted"] or g in SAFE or len(e["srcs"]) >= 2 or (g, k) in choices:
            row["status"] = INTEGRATED
        else:
            row.update(status=PENDING, reason="1 seule confirmation")
        row["confirm"] = len(e["srcs"])
        rows.append(row)
    return rows


def build(base, rows):
    """Nouvelle base : l'ancienne + les découvertes intégrées."""
    out = {g: dict((base or {}).get(g) or {}) for g, _, _ in GENRES}
    for r in rows:
        if r["status"] == INTEGRATED:
            out[r["genre"]][r["key"]] = r["value"]
    return out


# --- Modules/LearnedDB.lua -----------------------------------------------------------------------
_RESERVED = {"and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local", "nil",
             "not", "or", "repeat", "return", "then", "true", "until", "while", "goto"}


def _lua(v, ind=""):
    if isinstance(v, bool):
        return "true" if v else "false"
    if v is None:
        return "nil"
    if isinstance(v, (int, float)):
        return repr(round(v, 4)) if isinstance(v, float) else str(v)
    if isinstance(v, str):
        return '"' + v.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'
    if isinstance(v, list):
        return "{" + ",".join(_lua(x) for x in v) + "}"
    if isinstance(v, dict):
        parts = []
        for k in sorted(v, key=lambda x: str(x)):
            kk = str(k) if re.fullmatch(r"[A-Za-z_]\w*", str(k)) and str(k) not in _RESERVED else "[%s]" % _key(k)
            parts.append("%s=%s" % (kk, _lua(v[k])))
        return "{" + ",".join(parts) + "}"
    return "nil"


def _key(k):
    """Clé Lua : nombre si la clé est un nombre (n° de quête, de sort, d'objet, de carte), sinon texte."""
    if isinstance(k, int) or re.fullmatch(r"-?\d{1,12}", str(k)):
        return str(int(k))
    return _lua(str(k))


def stamp(base):
    """Empreinte de la base : l'addon ne l'applique qu'une fois par empreinte (WK.DB.global.learnedV)."""
    return hashlib.sha1(json.dumps(base or {}, sort_keys=True, ensure_ascii=False).encode("utf-8")).hexdigest()[:10]


def to_json(base):
    """Texte canonique de tools/learned/learned.json (la base de référence, lue par le client)."""
    return json.dumps({"wkl": VERSION, "data": {g: (base or {}).get(g) or {} for g, _, _ in GENRES}},
                      ensure_ascii=False, sort_keys=True, indent=0, separators=(",", ":")) + "\n"


def from_json(text):
    """Base lue dans learned.json ({} si vide ou illisible)."""
    try:
        d = json.loads(text)
    except ValueError:
        return {}
    data = d.get("data") if isinstance(d, dict) else None
    return {g: dict((data or {}).get(g) or {}) for g, _, _ in GENRES}


def from_lua(text):
    """Base lue dans Modules/LearnedDB.lua (celui de l'addon installé) ; {} si absent ou illisible."""
    i = text.find("WK.LearnedDB")
    j = text.find("{", i) if i >= 0 else -1
    if j < 0:
        return {}
    try:
        t = parse_lua("X = " + text[j:]).get("X") or {}
    except (ValueError, IndexError):
        return {}
    out = {}
    for g, _, _ in GENRES:
        part = t.get(g) if isinstance(t.get(g), dict) else {}
        conv = {}
        for k, v in part.items():
            if isinstance(v, dict) and "pts" in v:
                v = dict(v, pts=_list(v["pts"]))
            elif isinstance(v, dict) and all(isinstance(x, int) for x in v) and v:
                v = _list(v)
            conv[str(k)] = v
        out[g] = conv
    return out


def to_lua(base):
    """Texte de Modules/LearnedDB.lua."""
    lines = ["-- luacheck: no max line length", "local _, WK = ...",
             "-- Découvertes intégrées à l'addon (généré par tools/gen_learned.py ou le client PC, page Découvertes) :",
             "-- ce que l'addon a appris en jeu chez ses joueurs, ajouté au démarrage à ce qui manque",
             "-- (Modules/Learned.lua). Ne pas modifier à la main.",
             "WK.LearnedDB = {",
             "    v = %s," % _lua(stamp(base))]
    for g, _, _ in GENRES:
        part = (base or {}).get(g) or {}
        lines.append("    %s = {" % g)
        for k in sorted(part, key=str):
            lines.append("        [%s] = %s," % (_key(k), _lua(part[k])))
        lines.append("    },")
    lines.append("}")
    return "\n".join(lines) + "\n"


def counts(data):
    return {g: len((data or {}).get(g) or {}) for g, _, _ in GENRES}
