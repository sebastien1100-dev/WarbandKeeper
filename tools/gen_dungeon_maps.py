#!/usr/bin/env python3
"""Cartes des donjons : Modules/DungeonMapsDB.lua et Data/Maps/*.blp.

python3 tools/gen_dungeon_maps.py <dossier DungeonJournal de Naowh Forever>

Cartes (images du jeu) et positions des boss reprises du Dungeon Journal de Naowh Forever, **avec l'accord
de son auteur** (exception à la règle « idées seulement » pour Naowh) : rien d'autre n'en est repris, aucun
code. Son fichier Data/Maps.lua est **lu comme du texte** (analyseur de tables de tools/questie_forever.py),
jamais exécuté. Chaque carte de Naowh est rattachée à nos donjons (Modules/DungeonsDB.lua) par les n° de PNJ
de ses boss ; un de nos donjons fait de plusieurs ailes reçoit les étages de chacune. Les images (1024 px,
DXT1 avec niveaux réduits) sont gardées telles quelles, sans recompression : seul leur niveau de 512 px et les
suivants sont recopiés dans un nouveau BLP2 (le jeu ne lit pas un BLP à palette fait par Pillow) dans Data/Maps (dossier WarbandKeeper_Data, chargé à la demande :
une texture se lit par son chemin même si le dossier n'est pas chargé).
"""
import os
import struct
import sys

from lupa import luajit21 as lupa

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from questie_forever import Parser, tokenize  # noqa: E402

OUT_LUA = os.path.join(ROOT, "Modules", "DungeonMapsDB.lua")
OUT_DIR = os.path.join(ROOT, "Data", "Maps")


def read_maps(src):
    text = open(os.path.join(src, "Data", "Maps.lua"), encoding="utf-8").read()
    toks = tokenize(text)
    for i, t in enumerate(toks):
        if t[0] == "name" and t[1] == "Maps" and toks[i + 1][1] == "=":
            return Parser(toks, {}, i + 2).expr()
    raise SystemExit("Maps.lua : table des cartes introuvable")


def naowh_encounters(src):
    """{ n° de rencontre: n° du PNJ }, { clé de carte: nom anglais } et { objet: % de drop } des fichiers
    Data/Dungeons (lus en texte ; taux 0 = inconnu, ignoré ; même objet chez plusieurs boss : le plus haut)."""
    enc, names, drops, models, bynames, npcnames = {}, {}, {}, {}, {}, {}
    folder = os.path.join(src, "Data", "Dungeons")
    for fn in os.listdir(folder):
        if not fn.endswith(".lua"):
            continue
        text = open(os.path.join(folder, fn), encoding="utf-8").read()
        toks = tokenize(text)
        for i, t in enumerate(toks):
            if t[0] == "name" and t[1] == "AddDungeon" and toks[i + 1][1] == "(":
                key = toks[i + 2][1]
                v = Parser(toks, {}, i + 4).expr()
                names[key] = v.get("name")
                for w in seq(v.get("wings")):
                    for b in seq(w.get("bosses")):
                        if isinstance(b.get("npc"), int) and isinstance(b.get("model"), int):
                            models[b["npc"]] = b["model"]
                        # aussi par nom anglais (en minuscules) : boss sans n° chez nous, ou n° appris en jeu différent
                        if isinstance(b.get("name"), str) and isinstance(b.get("model"), int):
                            bynames[b["name"].lower()] = b["model"]
                        # n° du PNJ par nom (boss sans modèle : portrait lu dans le cache du jeu, SetCreature)
                        if isinstance(b.get("name"), str) and isinstance(b.get("npc"), int) and b["npc"] > 0:
                            npcnames[b["name"].lower()] = b["npc"]
                        for item, pct in zip(seq(b.get("loot")), seq(b.get("chance"))):
                            if isinstance(item, int) and isinstance(pct, (int, float)) and pct > 0:
                                drops[item] = max(drops.get(item, 0), pct)
                        for e in seq(b.get("encounters")):
                            if b.get("npc"):
                                enc[int(e)] = int(b["npc"])
                break
    return enc, names, drops, models, bynames, npcnames


def our_dungeons():
    L = lupa.LuaRuntime(unpack_returned_tuples=True)
    code = open(os.path.join(ROOT, "Modules", "DungeonsDB.lua"), encoding="utf-8").read()
    ns = L.eval("{}")
    L.execute("return function(c, ns) local f = assert(loadstring(c)); return f('WarbandKeeper', ns) end")(code, ns)
    out = []
    for _, d in ns.DungeonsDB.items():
        ids = [b[1] for _, b in d.bosses.items() if b[1]]
        encs = [b[7] for _, b in d.bosses.items() if b[7]]
        out.append((d.key, d.name, ids, encs, d.en))
    return out


def lua_str(v):
    return '"' + v.replace("\\", "\\\\").replace('"', '\\"') + '"'


def seq(t):
    """Table Lua à indices 1..n (dict) -> liste."""
    if not isinstance(t, dict):
        return []
    return [t[i] for i in range(1, len(t) + 1) if i in t]


def floors_of(m):
    n = int(m.get("floors") or 1)
    order = seq(m.get("order")) or list(range(1, n + 1))
    images = m.get("images") or {}
    names = m.get("names") or {}
    out = []
    for f in order:
        img = images.get(f)
        if not img:
            # sans liste d'images : étage n > 1 = même nom suivi du n° (« AlcazPrison2 »)
            img = m.get("image") + (str(f) if f > 1 else "")
        out.append((f, img.replace("/", "\\").split("\\")[-1], names.get(f), m.get("imageBottom")))
    return out


def half_blp(src_path, dst_path):
    """BLP2 compressé avec niveaux : recopie à partir du 2e niveau (moitié de la taille), octets inchangés."""
    d = open(src_path, "rb").read()
    if d[:4] != b"BLP2" or d[11] != 1:
        raise SystemExit("%s : BLP2 avec niveaux attendu" % src_path)
    w, h = struct.unpack("<II", d[12:20])
    offs = struct.unpack("<16I", d[20:84])
    sizes = struct.unpack("<16I", d[84:148])
    levels = [(offs[i], sizes[i]) for i in range(1, 16) if sizes[i] > 0]
    head = 1172  # 20 + 64 + 64 + palette (1024)
    new_offs, new_sizes, data, at = [], [], b"", head
    for o, n in levels:
        new_offs.append(at); new_sizes.append(n)
        data += d[o:o + n]
        at += n
    new_offs += [0] * (16 - len(new_offs)); new_sizes += [0] * (16 - len(new_sizes))
    out = d[:12] + struct.pack("<II", w // 2, h // 2) + struct.pack("<16I", *new_offs) + struct.pack("<16I", *new_sizes)
    out += d[148:head] + data
    open(dst_path, "wb").write(out)


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    src = sys.argv[1]
    maps = read_maps(src)
    enc2npc, mapnames, drops, models, bynames, npcnames = naowh_encounters(src)
    ours = our_dungeons()
    os.makedirs(OUT_DIR, exist_ok=True)
    lines, used = [], set()
    matched = 0
    for key, name, ids, encs, en in sorted(ours, key=lambda x: x[0]):
        # boss du nouveau contenu sans n° de PNJ chez nous : rattachés par leur n° de rencontre
        idset = set(ids) | set(enc2npc[e] for e in encs if e in enc2npc)
        parts = [(mk, m) for mk, m in maps.items()
                 if idset & set((m.get("pins") or {}).keys()) or (en and mapnames.get(mk) == en)]
        if not parts:
            continue
        matched += 1
        floors, pins, entrance = [], {}, None
        for mk, m in parts:
            base = len(floors)
            local = {}
            for f, img, fname, bottom in floors_of(m):
                # image du jeu : la carte n'occupe que le haut (683 / 1024, format 3:2), sauf imageBottom = 1 (carré)
                floors.append((img, 1 if bottom == 1 else 0))
                local[f] = len(floors)
                used.add(img)
            for npc, p in (m.get("pins") or {}).items():
                p = seq(p)
                if len(p) == 3 and p[0] in local:
                    pins[npc] = (local[p[0]], p[1], p[2])
            e = seq(m.get("entrance"))
            if entrance is None and len(e) == 3 and e[0] in local:
                entrance = (local[e[0]], e[1], e[2])
        fl = ", ".join('{"%s",%d}' % f for f in floors)
        pl = ", ".join("[%d]={%d,%.3f,%.3f}" % (n, p[0], p[1], p[2]) for n, p in sorted(pins.items()))
        el = (", e={%d,%.3f,%.3f}" % entrance) if entrance else ""
        xs = sorted((e, enc2npc[e]) for e in encs if e in enc2npc and enc2npc[e] in pins)
        xl = (", x={%s}" % ", ".join("[%d]=%d" % kv for kv in xs)) if xs else ""
        lines.append("[%d]={f={%s}%s, p={%s}%s}, -- %s" % (key, fl, el, pl, xl, name))
    for img in sorted(used):
        half_blp(os.path.join(src, "Media", "Maps", img + ".blp"), os.path.join(OUT_DIR, img + ".blp"))
    for f in os.listdir(OUT_DIR):
        if f.endswith(".blp") and f[:-4] not in used:
            os.remove(os.path.join(OUT_DIR, f))
    with open(OUT_LUA, "w", encoding="utf-8") as out:
        out.write("-- FICHIER GÉNÉRÉ par tools/gen_dungeon_maps.py : ne pas modifier à la main.\n")
        out.write("-- Cartes des donjons (images du jeu) et positions des boss : Dungeon Journal de Naowh Forever,\n")
        out.write("-- reprises avec l'accord de son auteur. Images dans WarbandKeeper_Data\\Maps.\n")
        out.write("-- WK.DungeonMaps[clé du donjon] = { f = { { image, carré (1) ou 3:2 (0) } par étage }, e = { étage, x, y } (entrée),\n")
        out.write("--   p = { [n° du PNJ] = { étage, x, y } }, x = { [n° de rencontre] = n° du PNJ } } ; x et y de 0 à 1 sur l'image.\n")
        out.write("local ADDON_NAME, WK = ...\nWK.DungeonMaps = {\n")
        out.write("\n".join(lines) + "\n}\n")
        out.write("-- WK.DungeonDrops[objet] = % de drop (Dungeon Journal de Naowh Forever, même accord) : après wowtbc.gg,\n")
        out.write("-- avant les taux observés d'Everloot (Dungeons:ItemInfo).\nWK.DungeonDrops = {\n")
        items = sorted(drops.items())
        for i in range(0, len(items), 12):
            out.write(" ".join("[%d]=%s," % (k, ("%g" % v)) for k, v in items[i:i + 12]) + "\n")
        out.write("}\n")
        out.write("-- WK.DungeonBossModels[n° du PNJ] = n° de modèle (portrait : SetPortraitTextureFromCreatureDisplayID),\n")
        out.write("-- même source et même accord.\nWK.DungeonBossModels = {\n")
        ms = sorted(models.items())
        for i in range(0, len(ms), 12):
            out.write(" ".join("[%d]=%d," % kv for kv in ms[i:i + 12]) + "\n")
        out.write("}\n")
        out.write("-- WK.DungeonBossModelsByName[nom anglais en minuscules] = n° de modèle (même source, même accord).\n")
        out.write("WK.DungeonBossModelsByName = {\n")
        for k, v in sorted(bynames.items()):
            out.write("[%s]=%d,\n" % (lua_str(k), v))
        out.write("}\n")
        # seulement les boss sans modèle : les autres ont déjà leur portrait
        out.write("-- WK.DungeonBossNpcByName[nom anglais en minuscules] = n° du PNJ, pour les boss sans n° de modèle.\n")
        out.write("WK.DungeonBossNpcByName = {\n")
        for k, v in sorted(npcnames.items()):
            if k not in bynames:
                out.write("[%s]=%d,\n" % (lua_str(k), v))
        out.write("}\n")
    print("%d donjons avec carte, %d images, %d taux de drop, %d portraits" % (matched, len(used), len(drops), len(models)))


if __name__ == "__main__":
    main()
