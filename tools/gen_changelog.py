"""Génère CHANGELOG.md à partir de Core/Changelog.lua (source unique des notes de patch).

Usage : python3 tools/gen_changelog.py   (nécessite : pip install lupa)
"""
import os
from lupa import LuaRuntime

ROOT = os.path.join(os.path.dirname(__file__), "..")
SECTIONS = [("added", "Ajouts"), ("changed", "Modifications"), ("fixed", "Corrections")]

lua = LuaRuntime(unpack_returned_tuples=True)
wk = lua.eval("{ On = function() end }")
code = open(os.path.join(ROOT, "Core", "Changelog.lua"), encoding="utf-8").read()
lua.execute("return function(code, wk) return loadstring and loadstring(code)('WarbandKeeper', wk) or load(code)('WarbandKeeper', wk) end")(code, wk)


def items(t):
    return [t[i] for i in range(1, len(t) + 1)] if t else []


out = [
    "# Patch notes",
    "",
    "Toutes les modifications de Warband Keeper, version par version.",
    "Ce fichier est généré à partir de `Core/Changelog.lua` (les mêmes notes sont visibles en jeu : `/wk notes`).",
    "",
]
roadmap = items(wk.Roadmap)
# « À venir » toujours en haut.
if roadmap:
    out.append("## À venir")
    out.append("")
    out.append("_Prévu, pas encore commencé._")
    out.append("")
    out.extend(f"- {line}" for line in roadmap)
    out.append("")
for i, entry in enumerate(items(wk.Changelog)):
    out.append(f"## v{entry.version} — {entry.date}")
    out.append("")
    for key, label in SECTIONS:
        lst = items(entry[key])
        if lst:
            out.append(f"### {label}")
            out.extend(f"- {line}" for line in lst)
            out.append("")

open(os.path.join(ROOT, "CHANGELOG.md"), "w", encoding="utf-8").write("\n".join(out))
print("CHANGELOG.md généré")
