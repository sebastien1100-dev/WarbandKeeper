#!/usr/bin/env python3
"""Génère Modules/MapRevealDB.lua : les morceaux de carte (zones à découvrir) de chaque carte de WoW Forever.

Tables des fichiers du jeu (wago.tools, dernière version wowf) : WorldMapOverlay (taille et place de chaque
zone sur l'image de la carte), WorldMapOverlayTile (images qui la composent, 256 px de côté), UiMapXMapArt et
UiMapArt (carte » image), UiMapArtStyleLayer (taille de l'image de la carte). L'addon dessine sur la carte du
monde les zones que le perso n'a pas encore découvertes (celles qu'il a découvertes, le jeu les dessine).

Usage : python3 tools/gen_reveal.py [dossier des CSV]   (sans dossier : téléchargés sur wago.tools)
"""
import csv
import json
import os
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "Modules", "MapRevealDB.lua")
WAGO = "https://wago.tools"
UA = "Mozilla/5.0 (WarbandKeeper data tools)"
TABLES = ["WorldMapOverlay", "WorldMapOverlayTile", "UiMapXMapArt", "UiMapArt", "UiMapArtStyleLayer"]


def get(url, timeout=120):
    return urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": UA}), timeout=timeout)


def fetch(dest):
    with get(WAGO + "/api/builds", 60) as r:
        version = json.load(r)["wowf"][0]["version"]
    os.makedirs(dest, exist_ok=True)
    for t in TABLES:
        with get("%s/db2/%s/csv?build=%s" % (WAGO, t, version)) as r, open(os.path.join(dest, t + ".csv"), "wb") as f:
            f.write(r.read())
    return version


def rows(folder, name):
    with open(os.path.join(folder, name + ".csv"), encoding="utf-8") as f:
        return list(csv.DictReader(f))


def main():
    if len(sys.argv) > 1:
        folder, version = sys.argv[1], "fichiers locaux"
    else:
        folder = os.path.join(HERE, ".cache", "reveal")
        version = fetch(folder)
    style = {}
    for r in rows(folder, "UiMapArtStyleLayer"):
        if int(r["LayerIndex"]) == 0:
            style[int(r["UiMapArtStyleID"])] = (int(r["LayerWidth"]), int(r["LayerHeight"]))
    art_style = {int(r["ID"]): int(r["UiMapArtStyleID"]) for r in rows(folder, "UiMapArt")}
    map_of_art = {}
    for r in rows(folder, "UiMapXMapArt"):
        if int(r["PhaseID"]) == 0:
            map_of_art.setdefault(int(r["UiMapArtID"]), []).append(int(r["UiMapID"]))
    tiles = {}
    for r in rows(folder, "WorldMapOverlayTile"):
        if int(r["LayerIndex"]) == 0:
            tiles.setdefault(int(r["WorldMapOverlayID"]), []).append((int(r["RowIndex"]), int(r["ColIndex"]), int(r["FileDataID"])))
    maps = {}
    for r in rows(folder, "WorldMapOverlay"):
        art = int(r["UiMapArtID"])
        oid = int(r["ID"])
        t = sorted(tiles.get(oid, []))
        if not t or art not in map_of_art:
            continue
        w, h = int(r["TextureWidth"]), int(r["TextureHeight"])
        cols = (w + 255) // 256
        rws = (h + 255) // 256
        grid = {(a, b): fid for a, b, fid in t}
        ids = []
        for j in range(rws):
            for i in range(cols):
                ids.append(grid.get((j, i), 0))
        if not any(ids):
            continue
        sw, sh = style.get(art_style.get(art, 1), (1002, 668))
        for m in map_of_art[art]:
            e = maps.setdefault(m, {"w": sw, "h": sh, "o": []})
            e["o"].append((w, h, int(r["OffsetX"]), int(r["OffsetY"]), ids))
    out = ["local ADDON_NAME, WK = ...\n",
           "-- GÉNÉRÉ par tools/gen_reveal.py : ne pas modifier à la main.\n",
           "-- Zones à découvrir de chaque carte (version du jeu %s) : tables WorldMapOverlay et\n" % version,
           "-- WorldMapOverlayTile des fichiers du jeu (wago.tools).\n",
           "-- WK.MapRevealDB[carte] = { largeur, hauteur de l'image, { largeur, hauteur, x, y, \"images (lignes puis colonnes)\" }, ... }\n",
           "WK.MapRevealDB = {\n"]
    n = 0
    for m in sorted(maps):
        e = maps[m]
        parts = ["%d, %d" % (e["w"], e["h"])]
        for w, h, x, y, ids in sorted(e["o"], key=lambda o: (o[3], o[2])):
            parts.append('{ %d, %d, %d, %d, "%s" }' % (w, h, x, y, ",".join(str(i) for i in ids)))
            n += 1
        out.append("    [%d] = { %s },\n" % (m, ", ".join(parts)))
    out.append("}\n")
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("".join(out))
    print("MapRevealDB.lua : %d cartes, %d zones" % (len(maps), n))


if __name__ == "__main__":
    main()
