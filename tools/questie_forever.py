"""Corrections WoW Forever de QuestieDB, lues comme du texte et appliquées aux données brutes.

QuestieDB garde à part, dans src/corrections/Forever/, ce que WoW Forever change par rapport à Classic :
une base générée depuis wowhead.com/forever (generated/foreverBase*.lua : quêtes propres à Forever,
nouveaux PNJ et objets, niveaux, races, donneurs) puis des corrections écrites à la main
(forever*Fixes.lua). Les données brutes (data/Forever/forever*DB.lua) ne les contiennent pas.

Aucun de ces fichiers n'est exécuté : un petit analyseur (ci-dessous) lit la table rendue par
`function X:Load()` (constructeurs de table, nombres, chaînes, noms de constantes, + et -) et les
constantes (src/corrections/enum, src/meta) sont lues de la même façon. Ce qui n'est pas une donnée
(appels, fonctions) est ignoré et compté. `LoadDynamic` (corrections selon le perso) n'est pas lu.

Opérations d'un champ (comme dans QuestieDB) : « champ » = valeur remplacée ; « champ_add » (+1000) =
valeurs ajoutées à la liste (ou à chaque groupe d'une liste groupée {PNJ, objets, objets d'inventaire}) ;
« champ_remove » (-1000) = valeurs retirées.

Usage (dans un générateur, après avoir chargé les tables Lua des données dans le LuaRuntime L) :
    from questie_forever import apply_forever
    stats = apply_forever(L, root, quests=quests, npcs=npcs, objects=objs, items=items)
Données Questie (GPLv3 selon son équipe), comme le reste de QuestieDB.
"""
import os
import re

# --------------------------------------------------------------------------- lecture du texte Lua

_TOKEN = re.compile(r"""
    (?P<ws>\s+)
  | (?P<lcomment>--\[(?P<leq>=*)\[.*?\](?P=leq)\])
  | (?P<comment>--[^\n]*)
  | (?P<lstr>\[(?P<seq>=*)\[.*?\](?P=seq)\])
  | (?P<str>"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*')
  | (?P<num>0[xX][0-9a-fA-F]+|\d+\.?\d*(?:[eE][+-]?\d+)?|\.\d+(?:[eE][+-]?\d+)?)
  | (?P<name>[A-Za-z_][A-Za-z_0-9]*)
  | (?P<op>\.\.\.|\.\.|==|~=|<=|>=|[{}\[\]=,;()+\-*/.:#<>%^])
""", re.X | re.S)

_ESC = {"n": "\n", "t": "\t", "r": "\r", "\\": "\\", '"': '"', "'": "'", "\n": "\n", "a": "\a", "b": "\b", "f": "\f", "v": "\v"}


def _unescape(s):
    out, i = [], 0
    while i < len(s):
        c = s[i]
        if c == "\\" and i + 1 < len(s):
            n = s[i + 1]
            if n.isdigit():
                m = re.match(r"\d{1,3}", s[i + 1:])
                out.append(chr(int(m.group(0))))
                i += 1 + len(m.group(0))
                continue
            out.append(_ESC.get(n, n))
            i += 2
            continue
        out.append(c)
        i += 1
    return "".join(out)


def tokenize(text):
    toks, pos = [], 0
    while pos < len(text):
        m = _TOKEN.match(text, pos)
        if not m:
            raise ValueError("caractère inattendu à %d : %r" % (pos, text[pos:pos + 20]))
        pos = m.end()
        kind = m.lastgroup
        if kind in ("ws", "comment", "lcomment"):
            continue
        if kind in ("leq", "seq"):
            kind = "lstr" if m.group("lstr") else "lcomment"
            if kind == "lcomment":
                continue
        v = m.group(0)
        if kind == "str":
            toks.append(("str", _unescape(v[1:-1]), m.start()))
        elif kind == "lstr":
            body = v[v.index("[", 1) + 1:v.rindex("]", 0, len(v) - 1)]
            toks.append(("str", body[1:] if body.startswith("\n") else body, m.start()))
        elif kind == "num":
            if v.lower().startswith("0x"):
                n = int(v, 16)
            else:
                f = float(v)
                n = int(f) if f.is_integer() and not re.search(r"[.eE]", v) else f
            toks.append(("num", n, m.start()))
        elif kind == "name":
            toks.append(("name", v, m.start()))
        else:
            toks.append(("op", v, m.start()))
    toks.append(("eof", None, len(text)))
    return toks


class Unknown:
    """Valeur qu'on ne sait pas lire (appel, constante absente) : jamais appliquée."""
    def __init__(self, what):
        self.what = what

    def __repr__(self):
        return "Unknown(%s)" % self.what


class Parser:
    """Expressions de données Lua : tables, nombres, chaînes, nil/true/false, noms (pointés ou indexés)
    résolus dans `env`, + - * / et moins unaire, appels (rendent Unknown, sauf l10n(« texte ») = texte)."""

    def __init__(self, toks, env, i=0):
        self.t, self.i, self.env = toks, i, env
        self.unknown = []

    def peek(self, k=0):
        return self.t[self.i + k]

    def take(self, v=None):
        tok = self.t[self.i]
        if v is not None and tok[1] != v:
            raise ValueError("attendu %r, trouvé %r à %d" % (v, tok[1], tok[2]))
        self.i += 1
        return tok

    def is_op(self, v, k=0):
        tok = self.t[self.i + k]
        return tok[0] == "op" and tok[1] == v

    def expr(self):
        v = self.term()
        while self.is_op("+") or self.is_op("-"):
            op = self.take()[1]
            r = self.term()
            v = self._arith(op, v, r)
        return v

    def term(self):
        v = self.unary()
        while self.is_op("*") or self.is_op("/"):
            op = self.take()[1]
            r = self.unary()
            v = self._arith(op, v, r)
        return v

    def unary(self):
        if self.is_op("-"):
            self.take()
            v = self.unary()
            return -v if isinstance(v, (int, float)) else Unknown("-")
        return self.primary()

    def _arith(self, op, a, b):
        if not isinstance(a, (int, float)) or not isinstance(b, (int, float)):
            return Unknown(op)
        return a + b if op == "+" else a - b if op == "-" else a * b if op == "*" else a / b

    def primary(self):
        kind, v, pos = self.peek()
        if kind in ("num", "str"):
            self.take()
            return v
        if kind == "op" and v == "{":
            return self.table()
        if kind == "op" and v == "(":
            self.take()
            r = self.expr()
            self.take(")")
            return r
        if kind == "name":
            self.take()
            if v == "nil":
                return None
            if v == "true":
                return True
            if v == "false":
                return False
            if v == "function":
                self._skip_function()
                self.unknown.append("function")
                return Unknown("function")
            cur = self.env.get(v, Unknown(v))
            path = v
            while True:
                if self.is_op("."):
                    self.take()
                    key = self.take()[1]
                    path += "." + key
                    cur = cur.get(key, Unknown(path)) if isinstance(cur, dict) else Unknown(path)
                elif self.is_op("["):
                    self.take()
                    key = self.expr()
                    self.take("]")
                    path += "[]"
                    cur = cur.get(key, Unknown(path)) if isinstance(cur, dict) else Unknown(path)
                elif self.is_op("(") or self.peek()[0] == "str" or self.is_op("{"):
                    args = self._call_args()
                    if path == "l10n" and args and isinstance(args[0], str):
                        cur = args[0]
                    else:
                        cur = Unknown(path + "()")
                elif self.is_op(":"):
                    self.take()
                    path += ":" + self.take()[1]
                    self._call_args()
                    cur = Unknown(path + "()")
                else:
                    break
            if isinstance(cur, Unknown):
                self.unknown.append(cur.what)
            return cur
        raise ValueError("valeur inattendue %r à %d" % (v, pos))

    def _call_args(self):
        if self.peek()[0] == "str":
            return [self.take()[1]]
        if self.is_op("{"):
            return [self.table()]
        self.take("(")
        args = []
        while not self.is_op(")"):
            args.append(self.expr())
            if self.is_op(","):
                self.take()
        self.take(")")
        return args

    def _skip_function(self):
        # saute jusqu'au « end » qui ferme la fonction (blocs imbriqués comptés)
        depth = 1
        while depth:
            kind, v, _ = self.take()
            if kind == "eof":
                raise ValueError("fonction sans fin")
            if kind == "name":
                if v in ("function", "do", "if"):
                    depth += 1
                elif v == "end":
                    depth -= 1

    def table(self):
        """Table Lua » dict : positions 1..n (nil compris dans le compte) et clés nommées."""
        self.take("{")
        out, n = {}, 0
        while not self.is_op("}"):
            if self.is_op("["):
                self.take()
                k = self.expr()
                self.take("]")
                self.take("=")
                v = self.expr()
                if not isinstance(k, Unknown) and k is not None:
                    out[k] = v
            elif self.peek()[0] == "name" and self.is_op("=", 1):
                k = self.take()[1]
                self.take("=")
                out[k] = self.expr()
            else:
                n += 1
                v = self.expr()
                if v is not None:
                    out[n] = v
            if self.is_op(",") or self.is_op(";"):
                self.take()
        self.take("}")
        return out


# --------------------------------------------------------------------------- constantes

def _read(root, rel):
    with open(os.path.join(root, rel), encoding="utf-8") as f:
        return f.read()


def _assignments(text, env, scope):
    """Affectations du niveau du fichier « [local] nom(.champ)* = expression », dans l'ordre."""
    toks = tokenize(text)
    i = 0
    starts = []
    line_start = True
    # repère les débuts d'instruction : un nom en début de ligne suivi d'un = (après .champ éventuels)
    for j, tok in enumerate(toks):
        if tok[0] == "eof":
            break
        prev_nl = j == 0 or "\n" in text[toks[j - 1][2]:tok[2]]
        if not prev_nl or tok[0] != "name":
            continue
        k, local = j, False
        if tok[1] == "local":
            local, k = True, j + 1
        if toks[k][0] != "name":
            continue
        path = [toks[k][1]]
        k += 1
        while toks[k][0] == "op" and toks[k][1] == "." and toks[k + 1][0] == "name":
            path.append(toks[k + 1][1])
            k += 2
        if toks[k][0] == "op" and toks[k][1] == "=" and not (toks[k + 1][0] == "op" and toks[k + 1][1] == "="):
            starts.append((path, k + 1))
    del i, line_start
    for path, k in starts:
        p = Parser(toks, scope, k)
        try:
            v = p.expr()
        except ValueError:
            continue
        if len(path) == 1:
            scope[path[0]] = v
        else:
            cur = scope.setdefault(path[0], {})
            for key in path[1:-1]:
                if not isinstance(cur, dict):
                    break
                cur = cur.setdefault(key, {})
            if isinstance(cur, dict):
                cur[path[-1]] = v
    return scope


def load_constants(root):
    """Constantes de QuestieDB (src/corrections/enum) lues comme du texte : dict constants.*"""
    constants = {}
    scope = {"constants": constants}
    for f in ("items", "quests", "professions", "factions", "zones", "phases", "icons", "waypoints", "expansions"):
        rel = "src/corrections/enum/%s.lua" % f
        if os.path.exists(os.path.join(root, rel)):
            text = _read(root, rel)
            text = text.replace("local constants = LibQuestieDB.Enum", "")
            _assignments(text, scope, scope)
    return constants


def load_keys(root, name):
    """Clés des champs (src/meta/<name>Meta.lua : ['champ'] = n°) avec les alias _add / _remove."""
    text = _read(root, "src/meta/%sMeta.lua" % name)
    m = re.search(r"\bkeys\s*=\s*\{", text)
    out = {}
    if not m:
        return out
    toks = tokenize(text[m.end() - 1:])
    tbl = Parser(toks, {}).table()
    for k, i in tbl.items():
        if isinstance(k, str) and isinstance(i, int):
            out[k] = i
            out[k + "_add"] = i + 1000
            out[k + "_remove"] = i - 1000
    return out


def build_env(root):
    C = load_constants(root)
    by = C.get("byExpansion", {})
    fe, cl = by.get("Forever", {}), by.get("Classic", {})
    QuestieDB = {
        "questKeys": load_keys(root, "quest"), "npcKeys": load_keys(root, "npc"),
        "itemKeys": load_keys(root, "item"), "objectKeys": load_keys(root, "object"),
        "raceKeys": fe.get("raceKeys") or cl.get("raceKeys", {}),
        "classKeys": fe.get("classKeys") or cl.get("classKeys", {}),
        "npcFlags": fe.get("npcFlags") or cl.get("npcFlags", {}),
    }
    for k, v in C.items():
        QuestieDB.setdefault(k, v)
    return {
        "QuestieDB": QuestieDB,
        "ZoneDB": {"zoneIDs": C.get("zoneIDs", {})},
        "QuestieProfessions": {"professionKeys": C.get("professionKeys", {}),
                               "specializationKeys": C.get("specializationKeys", {}),
                               "rankNames": C.get("rankNames", {})},
        "Phasing": {"phases": C.get("phases", {})},
    }


def read_corrections(root, rel, env):
    """Table rendue par « function X:Load() » d'un fichier de corrections, sans l'exécuter.
    Rend (dict id » {n° de champ: valeur}, liste des valeurs non lues)."""
    text = _read(root, rel)
    m = re.search(r"^function\s+\w+:Load\(\)\s*$", text, re.M)
    if not m:
        return None, []
    body_end = re.search(r"^end\s*$", text[m.end():], re.M)
    body = text[m.end(): m.end() + (body_end.start() if body_end else len(text))]
    scope = {}
    # locales du début de Load : « local x = Module.champ »
    for lm in re.finditer(r"^\s*local\s+(\w+)\s*=\s*(\w+)\.(\w+)\s*$", body, re.M):
        mod = env.get(lm.group(2))
        scope[lm.group(1)] = mod.get(lm.group(3), {}) if isinstance(mod, dict) else {}
    r = re.search(r"^\s*return\s*\{", body, re.M)
    if not r:
        return None, []
    toks = tokenize(body[r.end() - 1:])
    p = Parser(toks, scope)
    tbl = p.table()
    return tbl, p.unknown


# --------------------------------------------------------------------------- application

def _lua(L, v):
    """valeur Python » valeur Lua (tables récursives)"""
    if isinstance(v, dict):
        return L.table_from({k: _lua(L, x) for k, x in v.items() if not isinstance(x, Unknown)})
    return v


def _lst(t):
    if t is None:
        return []
    out, i = [], 1
    while t[i] is not None:
        out.append(t[i])
        i += 1
    return out


def _grouped(v):
    return isinstance(v, dict) and any(isinstance(v.get(g), dict) for g in (1, 2, 3))


def _values(d):
    return [d[k] for k in sorted(k for k in d if isinstance(k, int))] if isinstance(d, dict) else []


def _is_table(L, x):
    import lupa
    return lupa.lua_type(x) == "table"


def _add(L, cur, v):
    if not isinstance(v, dict):
        return _lua(L, v)
    if not _is_table(L, cur):
        cur = L.table()
    if _grouped(v):
        for g in range(1, 7):
            add = v.get(g)
            if isinstance(add, dict):
                if not _is_table(L, cur[g]):
                    cur[g] = L.table()
                have = _lst(cur[g])
                for x in _values(add):
                    if x not in have:
                        have.append(x)
                        cur[g][len(have)] = x
    else:
        have = _lst(cur)
        for x in _values(v):
            if isinstance(x, dict):
                cur[len(have) + 1] = _lua(L, x)
                have.append(None)
            elif x not in have:
                have.append(x)
                cur[len(have)] = x
    return cur


def _remove(L, cur, v):
    if not _is_table(L, cur) or not isinstance(v, dict):
        return cur

    def strip(t, gone):
        return L.table_from([x for x in _lst(t) if x not in gone])
    if _grouped(v):
        for g in range(1, 7):
            if isinstance(v.get(g), dict) and _is_table(L, cur[g]):
                cur[g] = strip(cur[g], _values(v[g]))
        return cur
    return strip(cur, _values(v))


def _apply(L, db, patch):
    n = new = 0
    for eid, fields in patch.items():
        if not isinstance(fields, dict) or not isinstance(eid, int):
            continue
        row = db[eid]
        if row is None:
            row = L.table()
            db[eid] = row
            new += 1
        for k, v in fields.items():
            if not isinstance(k, int) or isinstance(v, Unknown):
                continue
            if k > 1000:
                row[k - 1000] = _add(L, row[k - 1000], v)
            elif k < 0:
                row[k + 1000] = _remove(L, row[k + 1000], v)
            else:
                row[k] = _lua(L, v)
        n += 1
    return n, new


PLAN = (
    ("quests", "src/corrections/Forever/generated/foreverBaseQuest.lua", "ForeverBaseQuest"),
    ("npcs", "src/corrections/Forever/generated/foreverBaseNpc.lua", "ForeverBaseNpc"),
    ("objects", "src/corrections/Forever/generated/foreverBaseObject.lua", "ForeverBaseObject"),
    ("items", "src/corrections/Forever/generated/foreverBaseItem.lua", "ForeverBaseItem"),
    ("quests", "src/corrections/Forever/foreverQuestFixes.lua", "ForeverQuestFixes"),
    ("npcs", "src/corrections/Forever/foreverNPCFixes.lua", "ForeverNpcFixes"),
    ("objects", "src/corrections/Forever/foreverObjectFixes.lua", "ForeverObjectFixes"),
    ("items", "src/corrections/Forever/foreverItemFixes.lua", "ForeverItemFixes"),
)


def apply_forever(L, root, quests=None, npcs=None, objects=None, items=None):
    """Applique les corrections Forever aux tables Lua données (modifiées sur place).
    Rend { module: (entités corrigées, entités nouvelles, valeurs non lues) } ; -1 = fichier absent."""
    root = os.path.abspath(root)
    env = build_env(root)
    dbs = {"quests": quests, "npcs": npcs, "objects": objects, "items": items}
    out = {}
    for what, rel, label in PLAN:
        db = dbs.get(what)
        if db is None:
            continue
        if not os.path.exists(os.path.join(root, rel)):
            out[label] = (-1, 0, 0)
            continue
        tbl, unknown = read_corrections(root, rel, env)
        if tbl is None:
            out[label] = (-1, 0, 0)
            continue
        n, new = _apply(L, db, tbl)
        out[label] = (n, new, len(unknown))
    return out


if __name__ == "__main__":
    import sys
    from collections import Counter
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), ".cache", "QuestieDB")
    env = build_env(root)
    qk = env["QuestieDB"]["questKeys"]
    print("champs de quête :", len(qk) // 3, "· ALL_HORDE =", env["QuestieDB"]["raceKeys"].get("ALL_HORDE"),
          "· zones :", len(env["ZoneDB"]["zoneIDs"]))
    for _, rel, label in PLAN:
        tbl, unknown = read_corrections(root, rel, env)
        print("%-20s %5s entités, non lus : %s" % (label, len(tbl or {}), Counter(unknown).most_common(6)))
