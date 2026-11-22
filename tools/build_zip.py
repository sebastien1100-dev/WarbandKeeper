#!/usr/bin/env python3
"""Construit le zip de l'addon : WarbandKeeper/ (dépôt sans Data/, ni ce que .gitattributes exclut) et
WarbandKeeper_Data/ (contenu de Data/, chargé à la demande), deux dossiers côte à côte dans Interface\\AddOns.

    python3 tools/build_zip.py <sortie.zip> [révision, HEAD par défaut]

Utilisé par .github/workflows/release.yml et pour les zips de dist/.
"""
import datetime
import io
import re
import subprocess
import sys
import tarfile
import zipfile


def tar_of(rev, prefix, tree):
    out = subprocess.run(["git", "archive", "--format=tar", "--prefix=" + prefix, tree], check=True,
                         capture_output=True).stdout
    return tarfile.open(fileobj=io.BytesIO(out))


KEEP_DAYS, KEEP_MIN = 3, 15  # notes gardées en jeu : les 3 derniers jours, 15 versions au moins
ENTRY = re.compile(r'^    \{\n        version = "([^"]+)", date = "(\d\d)/(\d\d)/(\d{4})"', re.M)
LSTR = re.compile(r'"((?:[^"\\]|\\.)*)"')


def trim_notes(changelog, enus, others):
    """Allège les notes de version du zip : seules les dernières versions restent dans Core/Changelog.lua
    (tout l'historique reste dans le dépôt, CHANGELOG.md et les Releases), et leurs traductions anglaises
    qui ne servent plus nulle part sont retirées de Locales/enUS.lua. Rend (changelog, enus, gardées, total)."""
    start = changelog.index("WK.Changelog = {\n") + len("WK.Changelog = {\n")
    end = changelog.index("\n}\n", start) + 1
    body = changelog[start:end]
    heads = list(ENTRY.finditer(body))
    if not heads:
        return changelog, enus, 0, 0
    day = lambda m: datetime.date(int(m.group(4)), int(m.group(3)), int(m.group(2)))
    limit = day(heads[0]) - datetime.timedelta(days=KEEP_DAYS - 1)
    keep = 0
    for i, m in enumerate(heads):
        if i < KEEP_MIN or day(m) >= limit:
            keep = i + 1
        else:
            break
    if keep >= len(heads):
        return changelog, enus, len(heads), len(heads)
    cut = heads[keep].start()
    kept, dropped = body[:cut], body[cut:]
    new = changelog[:start] + kept + changelog[end:]
    new = new.replace("\n}\n", "\n}\nWK.ChangelogTrim = { kept = %d, total = %d }\n" % (keep, len(heads)), 1)
    # traductions des lignes retirées, si le texte n'apparaît plus dans aucun autre fichier
    used = set(LSTR.findall(kept)) | set(LSTR.findall(changelog[end:]))
    gone = {t for t in LSTR.findall(dropped) if len(t) > 25 and t not in used}
    gone = {t for t in gone if not any(t in o for o in others)}
    out = []
    for line in enus.split("\n"):
        m = re.match(r'^    \["((?:[^"\\]|\\.)*)"\] = ', line)
        if m and m.group(1) in gone:
            continue
        out.append(line)
    return new, "\n".join(out), keep, len(heads)


def main(dest, rev="HEAD"):
    main_tar = tar_of(rev, "WarbandKeeper/", rev)
    data_tar = tar_of(rev, "WarbandKeeper_Data/", rev + ":Data")
    # fichiers de l'addon lus d'avance : les notes de version et leurs traductions sont allégées
    files = {}
    for t in (main_tar,):
        for m in t.getmembers():
            if m.isfile() and m.name.endswith(".lua") and not m.name.startswith("WarbandKeeper/Data/"):
                files[m.name] = t.extractfile(m).read().decode("utf-8")
    CL, EN = "WarbandKeeper/Core/Changelog.lua", "WarbandKeeper/Locales/enUS.lua"
    others = [v for k, v in files.items() if k not in (CL, EN)]
    for k, v in data_tar_texts(rev):
        others.append(v)
    cl, en, kept, total = trim_notes(files[CL], files[EN], others)
    patched = {CL: cl.encode("utf-8"), EN: en.encode("utf-8")}
    n = 0
    with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED) as z:
        for t, skip in ((main_tar, "WarbandKeeper/Data/"), (data_tar, None)):
            for m in t.getmembers():
                if skip and (m.name + "/").startswith(skip):
                    continue
                if m.isdir():
                    z.writestr(m.name.rstrip("/") + "/", b"")
                elif m.isfile():
                    z.writestr(m.name, patched.get(m.name) or t.extractfile(m).read())
                    n += 1
    print("%s : %d fichiers (WarbandKeeper + WarbandKeeper_Data), notes en jeu : %d versions sur %d"
          % (dest, n, kept, total))


def data_tar_texts(rev):
    t = tar_of(rev, "WarbandKeeper_Data/", rev + ":Data")
    for m in t.getmembers():
        if m.isfile() and m.name.endswith(".lua"):
            yield m.name, t.extractfile(m).read().decode("utf-8")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(*sys.argv[1:3])
