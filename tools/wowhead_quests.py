#!/usr/bin/env python3
"""Relève sur wowhead (partie WoW Forever) le nom français et le niveau de chaque quête de la base.

Usage : python3 tools/wowhead_quests.py [--refresh] [--only-missing]

Source : les infobulles publiques de wowhead (nether.wowhead.com/forever/fr/tooltip/quest/<n°>), qui donnent
le nom de la quête dans le jeu, son niveau et son objectif. Les pages complètes (chaîne, prérequis) passent par
une vérification anti-robot et ne sont pas lisibles ici. Réponses gardées dans tools/.cache/wowhead/ (une par
quête) ; résultat dans tools/quests/wowhead.json : { "n°": { "fr": nom, "lvl": niveau ou null } ou
{ "missing": true } }, lu par gen_quests.py (noms français manquants, niveau du jeu, quêtes absentes).
"""
import json
import os
import re
import sys
import threading
import time
import urllib.request
import urllib.error

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, ".cache", "wowhead")
OUT = os.path.join(HERE, "quests", "wowhead.json")
URL = "https://nether.wowhead.com/forever/fr/tooltip/quest/%d"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
THREADS, DELAY = 3, 0.35   # 3 fils, une requête toutes les 0,35 s par fil (env. 8 par seconde)


def quest_ids():
    sys.path.insert(0, HERE)
    from datalog import parse_rows
    with open(os.path.join(HERE, "..", "Modules", "QuestsDB.lua"), encoding="utf-8") as f:
        return sorted(parse_rows(f.read()).keys())


def fetch(qid, refresh):
    path = os.path.join(CACHE, "%d.json" % qid)
    if not refresh and os.path.exists(path):
        return
    req = urllib.request.Request(URL % qid, headers={"User-Agent": UA, "Accept": "application/json"})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                body = r.read().decode("utf-8")
            break
        except urllib.error.HTTPError as e:
            if e.code == 404:
                body = e.read().decode("utf-8", "replace") or '{"error":"404"}'
                break
            time.sleep(2 * (attempt + 1))
        except Exception:
            time.sleep(2 * (attempt + 1))
    else:
        return
    with open(path, "w", encoding="utf-8") as f:
        f.write(body)


def parse(qid):
    path = os.path.join(CACHE, "%d.json" % qid)
    if not os.path.exists(path):
        return None
    try:
        with open(path, encoding="utf-8") as f:
            d = json.load(f)
    except ValueError:
        return None
    if "error" in d or not d.get("name"):
        return {"missing": True}
    m = re.search(r"Level (\d+)", d.get("tooltip", ""))
    return {"fr": d["name"].strip(), "lvl": int(m.group(1)) if m else None}


def main():
    refresh = "--refresh" in sys.argv
    os.makedirs(CACHE, exist_ok=True)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    ids = quest_ids()
    if "--only-missing" in sys.argv:
        ids = [i for i in ids if not os.path.exists(os.path.join(CACHE, "%d.json" % i))]
    todo = list(ids)
    lock = threading.Lock()
    done = [0]

    def worker():
        while True:
            with lock:
                if not todo:
                    return
                qid = todo.pop()
            fetch(qid, refresh)
            with lock:
                done[0] += 1
                if done[0] % 250 == 0:
                    print("  %d / %d" % (done[0], len(ids)), flush=True)
            time.sleep(DELAY)
    ts = [threading.Thread(target=worker) for _ in range(THREADS)]
    for t in ts:
        t.start()
    for t in ts:
        t.join()
    out = {}
    for qid in quest_ids():
        r = parse(qid)
        if r:
            out[str(qid)] = r
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=0, sort_keys=True)
    miss = sum(1 for v in out.values() if v.get("missing"))
    print("%d quêtes relevées (%d absentes de wowhead) -> %s" % (len(out), miss, OUT))


if __name__ == "__main__":
    main()
