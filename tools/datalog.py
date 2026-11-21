"""Journal des données : ce qui change dans la base de quêtes à chaque génération.

Appelé par gen_quests.py : compare l'ancien Modules/QuestsDB.lua (avant réécriture) et le nouveau, et ajoute
une entrée à Modules/DataLogDB.lua (les 30 dernières) quand quelque chose a changé :
    WK.DataLog = { { t = date (s), src = "QuestieDB", total = n, add = { n°, ... },
                     rem = { { n°, "nom" }, ... }, chg = { { n°, "l30>31 g" }, ... } }, ... }  (la plus récente en tête)
Codes d'une correction : l = niveau, r = niveau requis, g = donneur (autre PNJ ou déplacé), z = zone,
p = prérequis, n = nom, f = faction.
L'historique est relu depuis la ligne « -- DATA » du fichier (JSON), rien d'autre à garder à côté.

Seule une première entrée peut être faite à la main :
    python3 tools/datalog.py <ancien QuestsDB.lua> <nouveau QuestsDB.lua> [--date JJ/MM/AAAA] [--src texte]
"""
import json
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from questie_forever import tokenize, Parser  # noqa: E402  (petit analyseur de tables Lua, rien n'est exécuté)

KEEP = 30
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Modules", "DataLogDB.lua")


def parse_rows(text):
    """{ n°: (carte, ligne) } d'un QuestsDB.lua (carte 0 = sans zone)"""
    out = {}
    if not text:
        return out
    cur = None
    for line in text.splitlines():
        m = re.match(r"^\[(\d+)\] = \{$", line)
        if m:
            cur = int(m.group(1))
            continue
        if line.startswith("WK.QuestsOther"):
            cur = 0
            continue
        if line.startswith("{") and line.endswith("},") and cur is not None:
            try:
                row = Parser(tokenize(line[:-1]), {}).table()
            except ValueError:
                continue
            if isinstance(row.get(1), int):
                out[row[1]] = (cur, row)
    return out


def _lst(v):
    return sorted(x for k, x in v.items() if isinstance(k, int)) if isinstance(v, dict) else []


def diff(old, new):
    """entrée du journal (sans date) ou None si rien n'a changé"""
    add = sorted(i for i in new if i not in old)
    rem = sorted(i for i in old if i not in new)
    chg = []
    for i in sorted(set(old) & set(new)):
        (om, o), (nm, n) = old[i], new[i]
        codes = []
        if (o.get(4) or 0) != (n.get(4) or 0):
            codes.append("l%d>%d" % (o.get(4) or 0, n.get(4) or 0))
        if (o.get(5) or 0) != (n.get(5) or 0):
            codes.append("r%d>%d" % (o.get(5) or 0, n.get(5) or 0))
        moved = False
        if o.get(12) != n.get(12):
            moved = True
        elif o.get(10) is not None and n.get(10) is not None:
            moved = abs(o[10] - n[10]) > 2 or abs(o.get(11, 0) - n.get(11, 0)) > 2
        elif (o.get(10) is None) != (n.get(10) is None):
            moved = True
        if moved:
            codes.append("g")
        if om != nm:
            codes.append("z")
        if _lst(o.get(14)) != _lst(n.get(14)) or _lst(o.get(15)) != _lst(n.get(15)):
            codes.append("p")
        if o.get(2) != n.get(2) or o.get(3) != n.get(3):
            codes.append("n")
        if o.get(6) != n.get(6):
            codes.append("f")
        if codes:
            chg.append([i, " ".join(codes)])
    if not (add or rem or chg):
        return None
    return {"src": "QuestieDB", "total": len(new), "add": add,
            "rem": [[i, old[i][1].get(3) or old[i][1].get(2) or ""] for i in rem], "chg": chg}


def read_history(path=OUT):
    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                if line.startswith("-- DATA "):
                    return json.loads(line[8:])
    except (OSError, ValueError):
        pass
    return []


def lua_str(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ") + '"'


def write(history, path=OUT):
    lines = [
        "-- FICHIER GÉNÉRÉ par tools/gen_quests.py (tools/datalog.py) : ne pas modifier à la main.",
        "-- Journal des données : quêtes ajoutées, corrigées ou retirées à chaque mise à jour de la base",
        "-- (QuestieDB et ses corrections WoW Forever), les 30 dernières, la plus récente en tête.",
        "-- WK.DataLog = { { t, src, total, add = { n° }, rem = { { n°, nom } }, chg = { { n°, codes } } } }",
        "-- codes : l = niveau, r = niveau requis, g = donneur, z = zone, p = prérequis, n = nom, f = faction",
        "-- DATA " + json.dumps(history, ensure_ascii=False, separators=(",", ":")),
        "local ADDON_NAME, WK = ...",
        "WK.DataLog = {",
    ]
    for e in history:
        lines.append("{t=%d,src=%s,total=%d,add={%s},rem={%s},chg={%s}}," % (
            e["t"], lua_str(e.get("src", "QuestieDB")), e.get("total", 0),
            ",".join(str(i) for i in e.get("add", [])),
            ",".join("{%d,%s}" % (i, lua_str(n)) for i, n in e.get("rem", [])),
            ",".join("{%d,%s}" % (i, lua_str(c)) for i, c in e.get("chg", []))))
    lines.append("}")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


def record(old_text, new_text, when=None, src=None, path=OUT):
    """ajoute l'entrée de cette génération ; rend l'entrée (ou None)"""
    history = read_history(path)
    e = diff(parse_rows(old_text), parse_rows(new_text))
    if e is None:
        if not os.path.exists(path):
            write(history, path)
        return None
    e["t"] = int(when or time.time())
    if src:
        e["src"] = src
    history.insert(0, e)
    write(history[:KEEP], path)
    return e


if __name__ == "__main__":
    args = sys.argv[1:]
    if len(args) < 2:
        sys.exit(__doc__)
    when, src = None, None
    if "--date" in args:
        d = args[args.index("--date") + 1]
        when = time.mktime(time.strptime(d + " 12:00", "%d/%m/%Y %H:%M"))
    if "--src" in args:
        src = args[args.index("--src") + 1]
    with open(args[0], encoding="utf-8") as f:
        old = f.read()
    with open(args[1], encoding="utf-8") as f:
        new = f.read()
    e = record(old, new, when, src)
    print("rien de changé" if e is None else "+%d, %d corrigées, %d retirées" % (len(e["add"]), len(e["chg"]), len(e["rem"])))
