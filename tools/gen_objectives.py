#!/usr/bin/env python3
"""Génère Data/QuestObjDB.lua (dossier WarbandKeeper_Data, chargé à la demande) : où faire chaque objectif de quête (camps) et où la rendre.

Usage : python3 tools/gen_objectives.py <clone de QuestieDB>

Source : QuestieDB (data/Forever) : objectifs de chaque quête (monstres, objets au sol, objets à
ramasser et qui les donne), apparitions des PNJ et des objets, PNJ qui termine la quête.
Les apparitions de chaque objectif sont regroupées en camps (centre et rayon, en coordonnées de
carte 0-100). Données Questie (GPLv3 selon son équipe) : garder la mention en tête du fichier
généré et dans Options > À propos.

Format (une chaîne par quête, décodée par Modules/QuestTrack.lua à la demande) :
  WK.QuestObjRaw[quête] = "m:carte,x,y,r,n;carte,x,y,r,n|i:...|o:...@carte,x,y"
  - un bloc par objectif, dans l'ordre du jeu par genre (m = monstre, i = objet à ramasser,
    o = objet au sol) ; bloc vide (« m: ») si aucun camp connu ; puis « e: » = zone à explorer, et
    « xN: » = objectif caché de Questie (objet à utiliser à tel endroit…) rattaché au N-ième objectif du
    jeu (« x: » sans objectif du jeu) ;
  - après « @ » : où rendre la quête (premier PNJ ou objet qui la termine).
  WK.QuestBuy[quête] = "objet,objet" : objets demandés par la quête qui se vendent chez un marchand
    (leur bloc « i: » reste vide : on les achète au lieu de les chercher sur un monstre).
  (Objets qui démarrent une quête, marchands des objets et noms des monstres : plus écrits, rien ne les lisait
  depuis le retrait de la tournée et du guide de montée.)
"""
DATA_HDR = "local WK = WarbandKeeper -- table de l'addon principal (dossier chargé à la demande)"
import math
import os
import sys

import lupa

MAX_POINTS = 400     # apparitions prises en compte par objectif
JOIN = 2.5           # deux apparitions à moins de 2,5 % de la carte : même camp
MAX_CAMPS = 10
MAX_KEYS = 16        # PNJ ou objets gardés par objectif pour les points
MAX_SPAWN = 300      # points gardés par PNJ ou objet et par carte (zones de chaleur)
B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
R_PCT = 0.85         # rayon d'un camp : 85 % de ses points dedans (un point isolé ne l'agrandit pas)


def main(root, out):
    L = lupa.LuaRuntime(unpack_returned_tuples=True)
    L.execute('QDB={}; ZDB={private={}}; L10N={npcNameLookup={}}\nloadstring=load\n'
              'GetLocale=function() return "frFR" end\n'
              'QuestieLoader={ImportModule=function(_,n) if n=="ZoneDB" then return ZDB elseif n=="l10n" then return L10N end return QDB end}')

    def run(rel):
        with open(os.path.join(root, rel), encoding="utf-8") as f:
            L.execute(f.read())
    for rel in ("data/Forever/foreverQuestDB.lua", "data/Forever/foreverNpcDB.lua", "data/Forever/foreverObjectDB.lua",
                "data/Forever/foreverItemDB.lua", "support/Forever/Zones/areaIdToUiMapId.lua",
                "l10n/Forever/lookupNpcs/frFR.lua"):
        run(rel)
    frn = L.globals().L10N.npcNameLookup["frFR"]
    if lupa.lua_type(frn) == "function":
        frn = frn()
    quests = L.execute("return load(QDB.questData)()")
    npcs = L.execute("return load(QDB.npcData)()")
    objs = L.execute("return load(QDB.objectData)()")
    items = L.execute("return load(QDB.itemData)()")
    # corrections WoW Forever de QuestieDB (lues comme du texte, voir questie_forever.py)
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from questie_forever import apply_forever
    for mod, (n, new, unk) in apply_forever(L, root, quests=quests, npcs=npcs, objects=objs, items=items).items():
        print("  %s : %d corrigés, %d nouveaux" % (mod, n, new), file=sys.stderr)
    amap = L.execute("return load(ZDB.private.areaIdToUiMapId)()")

    def lst(t):
        return [t[i] for i in range(1, len(t) + 1)] if t else []

    def spawns(e, key):
        """[(carte, x, y)] d'un PNJ ou d'un objet"""
        out = []
        sp = e and e[key]
        if not sp:
            return out
        for area, coords in sp.items():
            m = amap[area]
            if not m:
                continue
            for c in lst(coords):
                if c and c[1] is not None and c[1] >= 0 and c[2] is not None and c[2] >= 0:
                    out.append((m, c[1], c[2]))
        return out

    def npc_pts(nid):
        return spawns(npcs[nid], 7)

    def obj_pts(oid):
        return spawns(objs[oid], 4)

    def item_pts(iid):
        it = items[iid]
        pts = []
        if not it:
            return pts
        for nid in lst(it[2]):
            pts += npc_pts(nid)
        for oid in lst(it[3]):
            pts += obj_pts(oid)
        return pts

    def camps(pts):
        if not pts:
            return []
        if len(pts) > MAX_POINTS:
            step = len(pts) / MAX_POINTS
            pts = [pts[int(i * step)] for i in range(MAX_POINTS)]
        cl = []  # [carte, sx, sy, n, [points]]
        for m, x, y in pts:
            best = None
            for c in cl:
                if c[0] != m:
                    continue
                d = math.hypot(c[1] / c[3] - x, c[2] / c[3] - y)
                if d <= JOIN and (best is None or d < best[0]):
                    best = (d, c)
            if best:
                c = best[1]
                c[1] += x; c[2] += y; c[3] += 1; c[4].append((x, y))
            else:
                cl.append([m, x, y, 1, [(x, y)]])
        cl.sort(key=lambda c: -c[3])
        res = []
        for m, sx, sy, n, ps in cl[:MAX_CAMPS]:
            cx, cy = sx / n, sy / n
            ds = sorted(math.hypot(px - cx, py - cy) for px, py in ps)
            r = ds[min(len(ds) - 1, int(len(ds) * R_PCT))]
            res.append("%d,%.1f,%.1f,%.1f,%d" % (m, cx, cy, min(8, max(1.0, r)), n))
        return res

    def area_pts(sp):
        """[(carte, x, y)] d'une liste {[zone] = {{x, y}, ...}} (zone d'exploration, objectif caché)"""
        out = []
        if not sp:
            return out
        for area, coords in sp.items():
            m = amap[area] if isinstance(area, int) else None
            if not m:
                continue
            for c in lst(coords):
                if c and c[1] is not None and c[1] >= 0 and c[2] is not None and c[2] >= 0:
                    out.append((m, c[1], c[2]))
        return out

    def ref_pts(refs):
        """apparitions des PNJ ou objets cités par un objectif caché ({{"monster"|"object"|"item", n°}, ...})"""
        pts = []
        for r in lst(refs):
            if not r or not r[2]:
                continue
            kind = str(r[1]).lower()
            if kind.startswith("mon") or kind == "npc":
                pts += npc_pts(r[2])
            elif kind.startswith("obj"):
                pts += obj_pts(r[2])
            elif kind.startswith("item"):
                pts += item_pts(r[2])
        return pts

    def finisher(q):
        fb = q[3]
        if not fb:
            return None
        for kind, fn in ((1, npc_pts), (2, obj_pts)):
            for i in lst(fb[kind]):
                p = fn(i)
                if p:
                    return "%d,%.1f,%.1f" % p[0]
        return None

    vend = {}  # objet -> ["carte,x,y,faction,nom"]

    def vendors_of(iid):
        if iid in vend:
            return vend[iid]
        it = items[iid]
        out = []
        for nid in (lst(it[14]) if it and it[14] else []):
            n = npcs[nid]
            p = npc_pts(nid)
            if n and p:
                fac = n[13] or "AH"
                out.append("%d,%.1f,%.1f,%s,%s" % (p[0][0], p[0][1], p[0][2], fac, str(n[1]).replace(";", " ")))
        vend[iid] = out[:40]
        return vend[iid]

    buy = {}  # quête -> [objets à acheter]
    lines, n_obj, n_camp, n_explore, n_extra = [], 0, 0, 0, 0
    plines = []
    spawn = {}  # « n123 » / « o45 » -> points codés (une seule fois par PNJ ou objet)

    def enc(pts):
        """points sur une grille de 0,5 % de la carte : « carte:ccc…;carte:… » (3 caractères par point)"""
        per = {}
        for m, x, y in pts:
            gx, gy = min(200, max(0, int(round(x * 2)))), min(200, max(0, int(round(y * 2))))
            per.setdefault(m, set()).add(gx * 201 + gy)
        out = []
        for m in sorted(per):
            codes = sorted(per[m])
            if len(codes) > MAX_SPAWN:
                step = len(codes) / MAX_SPAWN
                codes = [codes[int(i * step)] for i in range(MAX_SPAWN)]
            out.append("%d:%s" % (m, "".join(B64[c >> 12] + B64[(c >> 6) & 63] + B64[c & 63] for c in codes)))
        return ";".join(out)

    def pool(keys):
        """clés des PNJ / objets qui ont des points ; leurs points vont une fois dans WK.SpawnPts"""
        out = []
        for k in keys:
            if k not in spawn:
                pts = npc_pts(int(k[1:])) if k[0] == "n" else obj_pts(int(k[1:]))
                spawn[k] = enc(pts) if pts else ""
            if spawn[k] and k not in out:
                out.append(k)
        return ",".join(out)
    starts = {}  # objet qui démarre une quête (clic droit dessus) : objet -> quête
    for qid in sorted(quests.keys()):
        q = quests[qid]
        if not q or not q[1]:
            continue
        if q[2]:
            for iid in lst(q[2][3]):
                if iid and iid not in starts:
                    starts[iid] = qid
        ob = q[10]
        blocks, prefs = [], []
        if ob:
            mons = [("m", npc_pts(o[1]), ["n%d" % o[1]]) for o in lst(ob[1]) if o and o[1]]
            # crédit de mort (plusieurs monstres comptent pour un objectif)
            for kc in lst(ob[5]):
                if kc and kc[1]:
                    pts = []
                    for nid in lst(kc[1]):
                        pts += npc_pts(nid)
                    mons.append(("m", pts, ["n%d" % nid for nid in lst(kc[1])]))
            obs = [("o", obj_pts(o[1]), ["o%d" % o[1]]) for o in lst(ob[2]) if o and o[1]]
            its = []
            for o in lst(ob[3]):
                if not (o and o[1]):
                    continue
                v = vendors_of(o[1])
                if v:
                    buy.setdefault(qid, []).append(o[1])
                    its.append(("i", [], []))
                else:
                    it = items[o[1]]
                    keys = (["n%d" % n for n in lst(it[2])] + ["o%d" % n for n in lst(it[3])]) if it else []
                    its.append(("i", item_pts(o[1]), keys))
            for kind, pts, keys in mons + its + obs:
                c = camps(pts)
                n_obj += 1
                n_camp += len(c)
                blocks.append(kind + ":" + ";".join(c))
                if len(keys) > MAX_KEYS:
                    # objet donné par des dizaines de monstres : ceux des cartes des principaux camps, les plus présents
                    maps = {cc.split(",")[0] for cc in c[:3]}
                    def here(k):
                        pts = npc_pts(int(k[1:])) if k[0] == "n" else obj_pts(int(k[1:]))
                        return sum(1 for m, _, _ in pts if str(m) in maps)
                    keys = [k for k in sorted(keys, key=here, reverse=True)[:MAX_KEYS] if here(k) > 0]
                prefs.append(pool(keys))
        # zone à explorer (« trouve tel endroit ») : bloc « e: »
        te = q[9]
        if te and te[2]:
            ap = area_pts(te[2])
            c = camps(ap)
            if c:
                n_explore += 1
                blocks.append("e:" + ";".join(c))
                prefs.append("*" + enc(ap))
        # objectifs cachés de Questie (utiliser un objet à tel endroit…) : « xN: » rattaché au N-ième objectif
        # du jeu, « x: » sinon
        for ex in lst(q[29]):
            if not ex:
                continue
            pts = area_pts(ex[1]) or ref_pts(ex[5])
            c = camps(pts)
            if c:
                n_extra += 1
                idx = ex[4] if isinstance(ex[4], int) else ""
                blocks.append("x%s:" % idx + ";".join(c))
                prefs.append("*" + enc(pts))
        fin = finisher(q)
        if not blocks and not fin:
            continue
        lines.append('[%d]="%s%s",' % (qid, "|".join(blocks), ("@" + fin) if fin else ""))
        if any(prefs):
            plines.append('[%d]="%s",' % (qid, "|".join(prefs)))
    with open(out, "w", encoding="utf-8") as f:
        f.write("-- FICHIER GÉNÉRÉ par tools/gen_objectives.py : ne pas modifier à la main.\n"
                "-- Camps des objectifs de quête et point de rendu. Données tirées de QuestieDB\n"
                "-- (https://github.com/Questie/QuestieDB), base de données de l'addon Questie : sous la\n"
                "-- licence de Questie (GPLv3 selon son équipe). Format décrit dans tools/gen_objectives.py.\n"
                "%s\nWK.QuestObjRaw = {\n" % DATA_HDR)
        f.write("\n".join(lines))
        f.write("\n}\n-- objets de quête vendus chez un marchand : [quête] = \"objet,objet\"\nWK.QuestBuy = {\n")
        f.write("\n".join('[%d]="%s",' % (q, ",".join(str(i) for i in buy[q])) for q in sorted(buy)))
        f.write("\n}\n-- points exacts (zones de chaleur) : [quête] = clés par objectif, dans l'ordre des blocs de\n"
                "-- WK.QuestObjRaw (« n12,o5 » = PNJ / objets de WK.SpawnPts, « *carte:… » = points de l'objectif)\n"
                "WK.QuestPtsRaw = {\n")
        f.write("\n".join(plines))
        f.write("\n}\n-- [« n » PNJ / « o » objet .. n°] = « carte:ccc…;… » : grille de 0,5 %% de la carte, 3 caractères\n"
                "-- base64 par point (x * 201 + y, x et y de 0 à 200)\nWK.SpawnPts = {\n")
        f.write("\n".join('%s="%s",' % (k, v) for k, v in sorted(spawn.items()) if v))
        f.write("\n}\n")
    print("%d PNJ ou objets avec points (%d Ko)" % (sum(1 for v in spawn.values() if v), sum(len(v) for v in spawn.values()) // 1024))
    print("%d quêtes, %d objectifs, %d camps, %d zones à explorer, %d objectifs cachés, %d objets qui démarrent une quête, %d quêtes avec achat" % (len(lines), n_obj, n_camp, n_explore, n_extra, len(starts), len(buy)))


if __name__ == "__main__":
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), ".cache", "QuestieDB")
    main(root, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Data", "QuestObjDB.lua"))
