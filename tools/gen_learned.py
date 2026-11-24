#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Découvertes : ajoute à la base (tools/learned/learned.json) ce qu'une sauvegarde de l'addon a appris en jeu,
puis régénère Modules/LearnedDB.lua.

  python3 tools/gen_learned.py [WarbandKeeper.lua ...] [--wkd fichier.wkd ...]

Une sauvegarde passée ici compte comme source sûre (celle du mainteneur) ; un fichier .wkd (envoyé par un autre
joueur) a besoin d'une 2e confirmation pour les quêtes, chaînes et boss. Sans argument : régénère seulement le .lua.
La sauvegarde est lue comme du texte (jamais exécutée) ; rien de personnel n'en sort (voir client/learned.py).
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "client"))
import learned as L  # noqa: E402

JSON = os.path.join(HERE, "learned", "learned.json")
LUA = os.path.join(HERE, "..", "Modules", "LearnedDB.lua")


def main(argv):
    base = L.from_json(open(JSON, encoding="utf-8").read()) if os.path.exists(JSON) else {}
    sources, wkd = [], False
    for a in argv:
        if a == "--wkd":
            wkd = True
            continue
        text = open(a, encoding="utf-8", errors="replace").read()
        if wkd:
            src, data = L.read_wkd(text)
            sources.append({"name": src, "trusted": False, "data": data})
        else:
            sources.append({"name": os.path.basename(a), "trusted": True, "data": L.extract(L.read_save(text))})
    rows = L.merge(sources, base)
    new = L.build(base, rows)
    st = {}
    for r in rows:
        st[r["status"]] = st.get(r["status"], 0) + 1
    os.makedirs(os.path.dirname(JSON), exist_ok=True)
    with open(JSON, "w", encoding="utf-8", newline="\n") as f:
        f.write(L.to_json(new))
    with open(LUA, "w", encoding="utf-8", newline="\n") as f:
        f.write(L.to_lua(new))
    print("Découvertes : %s" % (", ".join("%s %d" % (L.STATUS_LABEL[k], v) for k, v in sorted(st.items())) or "rien"))
    print("Base : %s" % ", ".join("%s %d" % (g, n) for g, n in L.counts(new).items() if n))


if __name__ == "__main__":
    main(sys.argv[1:])
