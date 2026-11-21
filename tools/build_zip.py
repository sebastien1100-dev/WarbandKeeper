#!/usr/bin/env python3
"""Construit le zip de l'addon : WarbandKeeper/ (dépôt sans Data/, ni ce que .gitattributes exclut) et
WarbandKeeper_Data/ (contenu de Data/, chargé à la demande), deux dossiers côte à côte dans Interface\\AddOns.

    python3 tools/build_zip.py <sortie.zip> [révision, HEAD par défaut]

Utilisé par .github/workflows/release.yml et pour les zips de dist/.
"""
import io
import subprocess
import sys
import tarfile
import zipfile


def tar_of(rev, prefix, tree):
    out = subprocess.run(["git", "archive", "--format=tar", "--prefix=" + prefix, tree], check=True,
                         capture_output=True).stdout
    return tarfile.open(fileobj=io.BytesIO(out))


def main(dest, rev="HEAD"):
    main_tar = tar_of(rev, "WarbandKeeper/", rev)
    data_tar = tar_of(rev, "WarbandKeeper_Data/", rev + ":Data")
    n = 0
    with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED) as z:
        for t, skip in ((main_tar, "WarbandKeeper/Data/"), (data_tar, None)):
            for m in t.getmembers():
                if skip and (m.name + "/").startswith(skip):
                    continue
                if m.isdir():
                    z.writestr(m.name.rstrip("/") + "/", b"")
                elif m.isfile():
                    z.writestr(m.name, t.extractfile(m).read())
                    n += 1
    print("%s : %d fichiers (WarbandKeeper + WarbandKeeper_Data)" % (dest, n))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(*sys.argv[1:3])
