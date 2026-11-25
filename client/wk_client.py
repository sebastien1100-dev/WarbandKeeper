#!/usr/bin/env python3
"""Warband Keeper : client PC.

Warband Keeper est fait pour WoW Forever seulement : le client ne propose que les installations de WoW Forever.
Installe et met à jour l'addon depuis les versions publiées sur GitHub (Releases), montre les nouveautés,
sauvegarde les réglages de l'addon (SavedVariables) avant chaque mise à jour, permet de revenir à la
version précédente, et se met à jour lui-même.

Lancer : python wk_client.py (Python 3.9+ avec Tkinter), ou WarbandKeeper-Client.exe (construit par
.github/workflows/release.yml avec PyInstaller).

Pour ajouter une page : une classe qui hérite de Page, décorée par @page("clé", "Libellé", "icône").
"""
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import queue
import urllib.error
import urllib.request
import webbrowser
import zipfile
from datetime import datetime

import tkinter as tk
from tkinter import filedialog, font as tkfont

import learned  # Découvertes (client/learned.py, partagé avec tools/gen_learned.py)

CLIENT_VERSION = "1.9.29"
REPO = "sebastien1100-dev/WarbandKeeper"
ADDON = "WarbandKeeper"
DATA_ADDON = "WarbandKeeper_Data"  # grosses bases, chargées à la demande (dossier à côté de l'addon)
DATA_KEEP = "__" + DATA_ADDON  # copie du dossier de données rangée dans la sauvegarde d'une version
API = "https://api.github.com/repos/" + REPO
UA = "WarbandKeeper-Client/" + CLIENT_VERSION
TOKEN_URL = "https://github.com/settings/personal-access-tokens/new"
IS_WIN = sys.platform.startswith("win")
FROZEN = getattr(sys, "frozen", False)

# ---------------------------------------------------------------------------
# Couleurs : thème Graphite de l'addon (UI/Themes.lua), accent bleu électrique
# ---------------------------------------------------------------------------
C = {
    "bg": "#0f1012", "sidebar": "#0c0d0e", "surface": "#17191b", "surface2": "#1c1e21",
    "hover": "#212327", "border": "#303338", "text": "#edeff2", "muted": "#999ea8",
    "dim": "#65686f", "accent": "#1f8fff", "accent2": "#4da6ff", "onAccent": "#ffffff",
    "positive": "#9ed17a", "warning": "#f2a84d", "negative": "#e86b6b", "gold": "#e8c35a",
}
# couleurs de classe du jeu (persos de l'Accueil)
CLASS_COLORS = {"WARRIOR": "#c79c6e", "PALADIN": "#f58cba", "HUNTER": "#abd473", "ROGUE": "#fff569", "PRIEST": "#e6e6e6",
                "SHAMAN": "#0070de", "MAGE": "#69ccf0", "WARLOCK": "#9482c9", "DRUID": "#ff7d0a"}

# ---------------------------------------------------------------------------
# Réglages du client
# ---------------------------------------------------------------------------
def data_dir():
    base = os.environ.get("APPDATA") if IS_WIN else os.path.join(os.path.expanduser("~"), ".config")
    d = os.path.join(base or os.path.expanduser("~"), "WarbandKeeper Client")
    os.makedirs(d, exist_ok=True)
    return d


CONFIG_PATH = os.path.join(data_dir(), "config.json")
DEFAULTS = {"addons": "", "token": "", "checkEvery": "1h", "autoInstall": False, "backupBefore": True, "keepBackups": 15,
            "startup": False,
            "notify": {"auctions": True, "cds": True, "rest": False, "mail": True, "data": True, "quiet": True}, "notified": {},
            "dataNotified": 0}
RUN_KEY = r"Software\Microsoft\Windows\CurrentVersion\Run"
RUN_NAME = "WarbandKeeperClient"
SCHEDULE_PATH = "tools/update_schedule.json"
DATALOG_PATH = "Modules/DataLogDB.lua"  # journal des données (ligne « -- DATA » en JSON, tools/datalog.py)
DATA_WORKFLOW = "update-data.yml"
LEARNED_JSON = "tools/learned/learned.json"  # Découvertes : base de référence (client/learned.py)
LEARNED_LUA = "Modules/LearnedDB.lua"
# Découvertes proposées par des joueurs sans droit d'écriture sur le dépôt (fork + demande de fusion) : un fichier
# .wkd par envoi, lu comme une source « autre joueur » par le client du mainteneur (learned_pr)
LEARNED_INBOX = "tools/learned/inbox"
# jeton « classique » pour un joueur qui propose ses découvertes depuis sa copie (fork) du dépôt public
FRIEND_TOKEN_URL = "https://github.com/settings/tokens/new?scopes=public_repo&description=Warband%20Keeper"


def load_config():
    cfg = dict(DEFAULTS)
    try:
        with open(CONFIG_PATH, encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, dict):  # un fichier abîmé (liste, texte) ne fait plus planter le démarrage
            cfg.update(data)
    except (OSError, ValueError):
        pass
    # copies (les réglages par défaut ne doivent pas être modifiés), nouvelles clés ajoutées
    cfg["notify"] = dict(DEFAULTS["notify"], **(cfg.get("notify") if isinstance(cfg.get("notify"), dict) else {}))
    cfg["notified"] = dict(cfg.get("notified") if isinstance(cfg.get("notified"), dict) else {})
    if cfg.pop("checkOnStart", True) is False and cfg.get("checkEvery") == "start":
        cfg["checkEvery"] = "manual"  # réglage du client 1.0-1.2
    if not cfg.get("hourly14"):
        # client 1.4 : vérification toutes les heures par défaut (l'ancien défaut était « au démarrage »)
        if cfg.get("checkEvery") == "start":
            cfg["checkEvery"] = "1h"
        cfg["hourly14"] = True
    return cfg


def set_startup(on):
    """Lancer le client avec Windows, réduit (clé Run de l'utilisateur). Rend True si c'est fait."""
    if not (IS_WIN and FROZEN):
        return False
    try:
        import winreg
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, RUN_KEY, 0, winreg.KEY_SET_VALUE) as k:
            if on:
                winreg.SetValueEx(k, RUN_NAME, 0, winreg.REG_SZ, '"%s" --minimized' % sys.executable)
            else:
                try:
                    winreg.DeleteValue(k, RUN_NAME)
                except FileNotFoundError:
                    pass
        return True
    except OSError:
        return False


def flash_taskbar(root):
    """Fait clignoter le bouton du client dans la barre des tâches (Windows) pour attirer l'œil."""
    if not IS_WIN:
        return
    try:
        import ctypes
        from ctypes import wintypes

        class FLASHWINFO(ctypes.Structure):
            _fields_ = [("cbSize", wintypes.UINT), ("hwnd", wintypes.HWND), ("dwFlags", wintypes.DWORD),
                        ("uCount", wintypes.UINT), ("dwTimeout", wintypes.DWORD)]
        hwnd = ctypes.windll.user32.GetParent(root.winfo_id())
        info = FLASHWINFO(ctypes.sizeof(FLASHWINFO), hwnd, 3 | 12, 0, 0)  # tout, jusqu'au retour au premier plan
        ctypes.windll.user32.FlashWindowEx(ctypes.byref(info))
    except Exception:
        pass


def save_config(cfg):
    """Écrit dans un fichier temporaire puis le renomme : un arrêt brutal pendant l'écriture ne laisse plus un
    fichier tronqué (le jeton et le dossier étaient alors perdus)."""
    tmp = CONFIG_PATH + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=1)
    os.replace(tmp, CONFIG_PATH)


def vtuple(v):
    return tuple(int(x) for x in re.findall(r"\d+", v or "0")[:4]) or (0,)


# ---------------------------------------------------------------------------
# Jeu et addon
# ---------------------------------------------------------------------------
FLAVORS = {"_retail_": "Retail", "_classic_": "Classic", "_classic_era_": "Classic Era",
           "_anniversary_": "Anniversary", "_classic_ptr_": "Classic PTR", "_ptr_": "PTR", "_beta_": "Bêta",
           "_forever_": "WoW Forever", "_forever_beta_": "WoW Forever (bêta)", "_forever_ptr_": "WoW Forever (PTR)"}


def _registry_paths():
    """Emplacements de WoW notés par l'installeur (registre Windows)."""
    out = []
    try:
        import winreg
    except ImportError:
        return out
    keys = [r"SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft",
            r"SOFTWARE\Blizzard Entertainment\World of Warcraft",
            r"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\World of Warcraft",
            r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\World of Warcraft"]
    for hive in (winreg.HKEY_LOCAL_MACHINE, winreg.HKEY_CURRENT_USER):
        for k in keys:
            try:
                h = winreg.OpenKey(hive, k)
            except OSError:
                continue
            for val in ("InstallPath", "GamePath", "InstallLocation"):
                try:
                    out.append(winreg.QueryValueEx(h, val)[0])
                except OSError:
                    pass
    return out


def _battlenet_paths():
    """Dossier d'installation par défaut de Battle.net (%APPDATA%\\Battle.net\\Battle.net.config)."""
    out = []
    p = os.path.join(os.environ.get("APPDATA", ""), "Battle.net", "Battle.net.config")
    try:
        with open(p, encoding="utf-8", errors="replace") as f:
            txt = f.read()
    except OSError:
        return out
    for m in re.findall(r'"(?:DefaultInstallPath|InstallPath|Path)"\s*:\s*"([^"]+)"', txt):
        m = m.replace("\\\\", "\\").replace("/", os.sep)
        out += [m, os.path.join(m, "World of Warcraft")]
    return out


def wow_roots():
    """Dossiers « World of Warcraft » (ceux qui contiennent _retail_, _classic_era_…)."""
    cands = []
    if IS_WIN:
        cands += _registry_paths() + _battlenet_paths()
        for drive in "CDEFGHIJK":
            d = drive + ":\\"
            if not os.path.isdir(d):
                continue
            bases = [d]
            try:  # un niveau de dossiers sous la racine (Program Files, Jeux, Games…), puis Blizzard
                for n in os.listdir(d):
                    full = os.path.join(d, n)
                    if os.path.isdir(full) and not n.startswith(("$", ".")) and n.lower() not in ("windows", "users", "programdata"):
                        bases.append(full)
                        bases.append(os.path.join(full, "Blizzard"))
                        bases.append(os.path.join(full, "Blizzard Entertainment"))
            except OSError:
                pass
            for base in bases:
                for name in ("World of Warcraft", "World of Warcraft Forever", "WoW Forever", "WoW"):
                    cands.append(os.path.join(base, name))
    else:
        home = os.path.expanduser("~")
        cands += [os.path.join(home, "Games", "World of Warcraft"), "/Applications/World of Warcraft",
                  os.path.join(home, ".wine", "drive_c", "Program Files (x86)", "World of Warcraft")]
    roots = []
    for c in cands:
        if not c:
            continue
        c = os.path.normpath(c)
        if os.path.basename(c).startswith("_"):  # le registre donne parfois ...\\_retail_
            c = os.path.dirname(c)
        if os.path.isdir(c) and c not in roots:
            try:
                if any(n.startswith("_") and os.path.isdir(os.path.join(c, n)) for n in os.listdir(c)) or \
                        os.path.isdir(os.path.join(c, "Interface")):
                    roots.append(c)
            except OSError:
                pass
    return roots


def _is_forever(flavor_dir, name):
    """WoW Forever : nom du dossier, .flavor.info, ou addons pour l'interface 16xxx."""
    if "forever" in name.lower():
        return True
    try:
        with open(os.path.join(flavor_dir, ".flavor.info"), encoding="utf-8", errors="replace") as f:
            if "forever" in f.read().lower():
                return True
    except OSError:
        pass
    addons = os.path.join(flavor_dir, "Interface", "AddOns")
    try:
        for n in os.listdir(addons)[:60]:
            toc = os.path.join(addons, n, n + ".toc")
            if os.path.isfile(toc):
                with open(toc, encoding="utf-8", errors="replace") as f:
                    if re.search(r"^## Interface:\s*16\d{3}\b", f.read(4000), re.M):
                        return True
    except OSError:
        pass
    return False


def find_installs():
    """Versions de WoW installées : [{ addons, label, forever, version }], les plus probables d'abord
    (celle qui a déjà l'addon, puis WoW Forever). Le dossier AddOns est créé s'il manque."""
    out = []
    for root in wow_roots():
        flavors = [n for n in sorted(os.listdir(root)) if n.startswith("_") and os.path.isdir(os.path.join(root, n))]
        for n in flavors or [""]:
            fdir = os.path.join(root, n) if n else root
            if n and not any(os.path.exists(os.path.join(fdir, x)) for x in ("Interface", "WTF", "Data", ".flavor.info")) \
                    and not any(f.lower().endswith(".exe") for f in os.listdir(fdir)):
                continue
            addons = os.path.join(fdir, "Interface", "AddOns")
            forever = _is_forever(fdir, n or root)
            label = FLAVORS.get(n) or ("WoW Forever" if forever else n.strip("_").replace("_", " ").title() or "World of Warcraft")
            if any(o["addons"] == addons for o in out):
                continue
            out.append({"addons": addons, "label": label, "forever": forever, "root": root,
                        "version": installed_version(addons) if os.path.isdir(addons) else None})
    # l'addon déjà installé d'abord, puis WoW Forever « normal » avant la bêta ou le PTR
    out.sort(key=lambda i: (i["version"] is None, not i["forever"], "(" in i["label"]))
    return out


def find_forever():
    """Installations de WoW Forever seulement (Warband Keeper n'existe que pour WoW Forever)."""
    return [i for i in find_installs() if i["forever"]]


def find_addons_dirs():
    return [i["addons"] for i in find_forever()]


def short_path(p, n=55):
    """Chemin raccourci pour l'affichage : début…fin."""
    return p if len(p) <= n else p[:18] + "…" + p[-(n - 19):]


def flavor_label(addons):
    """Nom lisible de l'installation d'un dossier AddOns (WoW Forever, Classic Era…)."""
    fdir = game_dir(addons)
    n = os.path.basename(fdir)
    if n in FLAVORS:
        return FLAVORS[n]
    if _is_forever(fdir, n):
        return "WoW Forever"
    return n.strip("_").replace("_", " ").title() or "World of Warcraft"


def use_install(inst):
    """Prépare le dossier AddOns d'une installation (créé s'il manque) et le rend."""
    os.makedirs(inst["addons"], exist_ok=True)
    return inst["addons"]


def normalize_addons(path):
    """Accepte le dossier du jeu (ou _xxx_), Interface ou AddOns : rend le dossier AddOns, ou None."""
    if not path:
        return None
    for cand in (path, os.path.join(path, "AddOns"), os.path.join(path, "Interface", "AddOns")):
        if os.path.basename(os.path.normpath(cand)).lower() == "addons" and os.path.isdir(cand):
            return os.path.normpath(cand)
    if os.path.isdir(path):
        for s in os.listdir(path):
            a = os.path.join(path, s, "Interface", "AddOns")
            if s.startswith("_") and os.path.isdir(a):
                return a
    return None


def data_missing(addons, version):
    """Vrai si la version installée attend le dossier WarbandKeeper_Data (1.128.0 et plus) et qu'il manque (zip
    installé par un client 1.9.0 ou plus ancien, dossier supprimé) : il faut réinstaller la même version."""
    if not (addons and version) or vtuple(version) < vtuple("1.128.0"):
        return False
    return not os.path.isfile(os.path.join(addons, DATA_ADDON, DATA_ADDON + ".toc"))


def installed_version(addons):
    try:
        with open(os.path.join(addons, ADDON, ADDON + ".toc"), encoding="utf-8", errors="replace") as f:
            m = re.search(r"^## Version:\s*(\S+)", f.read(), re.M)
            return m.group(1) if m else "inconnue"  # (« ? » donnait un nom de dossier interdit sous Windows)
    except OSError:
        return None


def game_dir(addons):
    return os.path.dirname(os.path.dirname(addons))


def saved_variables(addons, chars=False):
    """Fichiers de réglages de l'addon : WTF/Account/*/SavedVariables/WarbandKeeper.lua (+ .bak) ; avec chars,
    aussi ceux de chaque perso (WTF/Account/<compte>/<royaume>/<perso>/SavedVariables/WarbandKeeper.lua :
    positions des éléments à l'écran, LFG, tenue de pêche…), pour les sauvegardes."""
    out = []
    wtf = os.path.join(game_dir(addons), "WTF", "Account")
    names = (ADDON + ".lua", ADDON + ".lua.bak")
    if os.path.isdir(wtf):
        for acc in os.listdir(wtf):
            sv = os.path.join(wtf, acc, "SavedVariables")
            for n in names:
                p = os.path.join(sv, n)
                if os.path.isfile(p):
                    out.append(p)
            if not chars:
                continue
            accDir = os.path.join(wtf, acc)
            try:
                realms = [r for r in os.listdir(accDir) if os.path.isdir(os.path.join(accDir, r)) and r != "SavedVariables"]
            except OSError:
                realms = []
            for realm in realms:
                rDir = os.path.join(accDir, realm)
                try:
                    persos = os.listdir(rDir)
                except OSError:
                    continue
                for perso in persos:
                    for n in names:
                        p = os.path.join(rDir, perso, "SavedVariables", n)
                        if os.path.isfile(p):
                            out.append(p)
    return out


# --- Lecture des réglages de l'addon (hors du jeu) : persos du compte -------------------------------
_LUA_TOKEN = re.compile(r'\s+|--\[\[.*?\]\]|--[^\n]*|"(?:\\.|[^"\\])*"|-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?|[A-Za-z_][A-Za-z0-9_]*|[{}\[\]=,;]', re.S)


class _LuaTokens:
    """Jetons Lua des réglages, avec un coup d'avance (peek) pour distinguer « nom = valeur » d'une valeur de liste."""

    def __init__(self, text, start):
        self.text, self.pos, self.ahead = text, start, None

    def __iter__(self):
        return self

    def _read(self):
        text, n = self.text, len(self.text)
        while self.pos < n:
            m = _LUA_TOKEN.match(text, self.pos)
            if not m:
                self.pos += 1
                continue
            tok = m.group(0)
            self.pos = m.end()
            if tok[0].isspace() or tok.startswith("--"):
                continue
            return tok
        raise StopIteration

    def __next__(self):
        if self.ahead is not None:
            tok, self.ahead = self.ahead, None
            return tok
        return self._read()

    def peek(self):
        if self.ahead is None:
            self.ahead = self._read()
        return self.ahead


def _lua_tokens(text, start):
    return _LuaTokens(text, start)


def _lua_value(it, tok):
    """Valeur Lua des réglages (tables, chaînes, nombres, booléens) à partir du jeton tok."""
    if tok == "{":
        out, arr = {}, 1
        for t in it:
            if t == "}":
                return out
            if t in (",", ";"):
                continue
            if t == "[":
                k = _lua_value(it, next(it))
                next(it)  # ]
                next(it)  # =
                out[k] = _lua_value(it, next(it))
            elif re.match(r"[A-Za-z_]", t) and t not in ("true", "false", "nil") and it.peek() == "=":
                next(it)  # =
                out[t] = _lua_value(it, next(it))
            else:
                # valeur de liste (y compris une table imbriquée)
                out[arr] = _lua_value(it, t)
                arr += 1
        return out
    if tok.startswith('"'):
        return bytes(tok[1:-1], "utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8", "replace")
    if tok == "true":
        return True
    if tok in ("false", "nil"):
        return False if tok == "false" else None
    try:
        return float(tok) if "." in tok or "e" in tok.lower() else int(tok)
    except ValueError:
        return tok


_SCAN = re.compile(r'"(?:\\.|[^"\\])*"|--\[\[.*?\]\]|--[^\n]*|[{}]', re.S)
_AFTER_KEY = re.compile(r'\s*\]\s*=\s*\{')


def _top_key(text, key):
    """Position de l'accolade ouvrante de WarbandKeeperDB[key] (clé au premier niveau seulement :
    d'autres tables, profils par exemple, ont aussi une clé « characters »)."""
    start = text.find("WarbandKeeperDB")
    if start < 0:
        return None
    depth, want = 0, '"%s"' % key
    for m in _SCAN.finditer(text, start):
        tok = m.group(0)
        if tok == "{":
            depth += 1
        elif tok == "}":
            depth -= 1
            if depth <= 0:
                return None
        elif depth == 1 and tok == want:
            a = _AFTER_KEY.match(text, m.end())
            if a:
                return a.end() - 1
    return None


_chars_cache = {}
_dash_cache = {}
_save_lock = threading.Lock()


def _save_file(addons):
    """(chemin, mtime) du WarbandKeeper.lua le plus récent, ou (None, None)."""
    files = [p for p in saved_variables(addons) if p.endswith(".lua")] if addons else []
    if not files:
        return None, None
    try:
        path = max(files, key=os.path.getmtime)
        return path, os.path.getmtime(path)
    except OSError:  # fichier remplacé par le jeu à cet instant
        return None, None


def save_state(addons):
    """Ce que le cache sait déjà, sans lire le fichier (sûr sur le thread Tk) : (résumé, persos, à jour).
    « à jour » est faux quand WarbandKeeper.lua a changé ou n'a pas encore été lu : App.load_save le relit
    en arrière-plan ; en attendant, la lecture précédente du même fichier est rendue (ou rien)."""
    path, mt = _save_file(addons)
    if path is None:
        return None, [], True
    d, c = _dash_cache, _chars_cache
    fresh = d.get("path") == path and d.get("mt") == mt and c.get("path") == path and c.get("mt") == mt
    return (d.get("dash") if d.get("path") == path else None), (c.get("list") if c.get("path") == path else []) or [], fresh


def read_save(addons):
    """Lit et analyse WarbandKeeper.lua (plusieurs Mo : jamais sur le thread Tk, voir App.load_save), une
    seule fois par version du fichier (cache par mtime) : (résumé WarbandKeeperDB.clientDash ou None,
    persos du compte [{ name, cls, level, money, seen }])."""
    with _save_lock:
        path, mt = _save_file(addons)
        if path is None:
            return None, []
        if _dash_cache.get("path") == path and _dash_cache.get("mt") == mt \
                and _chars_cache.get("path") == path and _chars_cache.get("mt") == mt:
            return _dash_cache["dash"], _chars_cache["list"]
        try:
            with open(path, encoding="utf-8", errors="replace") as f:
                text = f.read()
        except OSError:
            text = ""
        dash = None
        try:
            i = _top_key(text, "clientDash")
            if i is not None:
                it = _lua_tokens(text, i)
                dash = _lua_value(it, next(it))
        except Exception:
            dash = None
        out = []
        try:
            i = _top_key(text, "characters")
            if i is not None:
                it = _lua_tokens(text, i)
                chars = _lua_value(it, next(it))
                for key, c in (chars or {}).items():
                    # un perso : clé « Nom-Royaume » et une fiche (sinon ce n'est pas un perso)
                    if isinstance(c, dict) and isinstance(key, str) and "-" in key:
                        name = c.get("mailName") or c.get("fullName") or c.get("name") or str(key).split("-")[0].strip()
                        out.append({"name": name, "cls": c.get("class") or "", "level": c.get("level") or 0,
                                    "money": c.get("money") or 0, "seen": c.get("lastSeen") or 0})
        except Exception:
            out = []
        out.sort(key=lambda e: -(e["seen"] or 0))
        _dash_cache.update(path=path, mt=mt, dash=dash)
        _chars_cache.update(path=path, mt=mt, list=out)
        return dash, out


def read_characters(addons):
    """Persos du compte lus dans WarbandKeeper.lua (le plus récent). Lecture bloquante : voir save_state."""
    return read_save(addons)[1]


def read_dash(addons):
    """Résumé écrit par l'addon à la déconnexion (WarbandKeeperDB.clientDash, Modules/ClientDash.lua), ou None.
    Lecture bloquante : sur le thread Tk, passer par save_state / App.load_save."""
    return read_save(addons)[0]


def lua_list(t):
    """Liste Lua lue ({1: a, 2: b}) en liste Python, dans l'ordre."""
    if isinstance(t, list):
        return t
    if not isinstance(t, dict):
        return []
    return [t[k] for k in sorted(k for k in t if isinstance(k, int))]


def until_text(t):
    """« dans 2 j 4 h », « dans 18 h », « dans 12 min », ou « prête »."""
    d = (t or 0) - time.time()
    if d <= 0:
        return "prête"
    if d < 3600:
        return "dans %d min" % max(1, d // 60)
    if d < 86400:
        return "dans %d h" % (d // 3600)
    return "dans %d j %d h" % (d // 86400, (d % 86400) // 3600)


def notify_windows(title, text):
    """Notification Windows (toast) par PowerShell, sans dépendance ; rend True si elle est partie."""
    if not IS_WIN:
        return False
    import base64
    from xml.sax.saxutils import escape
    xml = ('<toast><visual><binding template="ToastGeneric"><text>%s</text><text>%s</text></binding></visual></toast>'
           % (escape(title), escape(text)))
    ps = ("[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null;"
          "[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] > $null;"
          "$x = New-Object Windows.Data.Xml.Dom.XmlDocument; $x.LoadXml('%s');"
          "$t = [Windows.UI.Notifications.ToastNotification]::new($x);"
          "[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("
          "'{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\\WindowsPowerShell\\v1.0\\powershell.exe').Show($t)") % xml.replace("'", "''")
    try:
        enc = base64.b64encode(ps.encode("utf-16-le")).decode("ascii")
        subprocess.Popen(["powershell", "-NoProfile", "-NonInteractive", "-WindowStyle", "Hidden", "-EncodedCommand", enc],
                         creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0), env=clean_env())
        return True
    except OSError:
        return False


def due_notifications(dash, opts, now=None):
    """Notifications à envoyer d'après le résumé : [(id, titre, texte)] ; l'id évite les doublons."""
    now = now or time.time()
    out = []
    if not isinstance(dash, dict):
        return out
    if opts.get("auctions"):
        soon = [a for a in lua_list(dash.get("auctions")) if isinstance(a, dict) and now < (a.get("exp") or 0) <= now + 86400]
        if soon:
            names = ", ".join(sorted({str(a.get("name")) for a in soon})[:3])
            chars = ", ".join(sorted({str(a.get("char")) for a in soon}))
            out.append(("auc:" + datetime.fromtimestamp(now).strftime("%Y-%m-%d"),
                        "%d enchère%s expire%s dans moins de 24 h" % (len(soon), "s" if len(soon) > 1 else "", "nt" if len(soon) > 1 else ""),
                        "%s… (%s)" % (names, chars)))
    if opts.get("cds"):
        for cd in lua_list(dash.get("cds")):
            if isinstance(cd, dict) and now - 7 * 86400 < (cd.get("readyAt") or 0) <= now:
                out.append(("cd:%s:%s:%s" % (cd.get("char"), cd.get("name"), cd.get("readyAt")),
                            "%s prête pour %s" % (cd.get("name"), cd.get("char")), "Recharge de métier terminée."))
    if opts.get("rest"):
        for r in lua_list(dash.get("rest")):
            if isinstance(r, dict) and (r.get("at") or 0) <= now:
                out.append(("rest:%s:%s" % (r.get("char"), int((r.get("at") or 0) // 86400)),
                            "Repos plein pour %s" % r.get("char"), "150 % d'XP de repos : c'est le moment de le jouer."))
    if opts.get("mail"):
        for m in lua_list(dash.get("mail")):
            if isinstance(m, dict) and 0 < (m.get("exp") or 0) - now < 3 * 86400:
                out.append(("mail:%s:%s" % (m.get("char"), m.get("exp")),
                            "Courrier de %s bientôt renvoyé" % m.get("char"),
                            "%d lettre%s non prise%s, la première expire %s." % (m.get("count") or 0, "s" if (m.get("count") or 0) > 1 else "",
                                                                                 "s" if (m.get("count") or 0) > 1 else "", until_text(m.get("exp")))))
    return out


def gh_time(s):
    """date GitHub (« 2026-11-21T04:57:24Z ») » secondes, ou 0"""
    from datetime import timezone
    try:
        return datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc).timestamp()
    except (TypeError, ValueError):
        return 0


def data_sum(entries):
    """total des quêtes ajoutées, corrigées, retirées d'une liste d'entrées du journal des données"""
    a = sum(len(e.get("add") or []) for e in entries)
    c = sum(len(e.get("chg") or []) for e in entries)
    r = sum(len(e.get("rem") or []) for e in entries)
    return a, c, r


def data_text(a, c, r):
    parts = []
    if a:
        parts.append("+%d quête%s" % (a, "s" if a > 1 else ""))
    if c:
        parts.append("%d corrigée%s" % (c, "s" if c > 1 else ""))
    if r:
        parts.append("%d retirée%s" % (r, "s" if r > 1 else ""))
    return ", ".join(parts) or "rien"


def quiet_now(now=None):
    h = datetime.fromtimestamp(now or time.time()).hour
    return h >= 23 or h < 8


CLASS_COLORS = {"WARRIOR": "#c79c6e", "PALADIN": "#f58cba", "HUNTER": "#abd473", "ROGUE": "#fff569", "PRIEST": "#ffffff",
                "SHAMAN": "#0070de", "MAGE": "#69ccf0", "WARLOCK": "#9482c9", "DRUID": "#ff7d0a"}


def short_until(t):
    """Délai court jusqu'à t : « 3 h », « 27 j » (listes étroites de l'Accueil)."""
    left = (t or 0) - time.time()
    if left <= 3600:
        return "< 1 h"
    if left < 86400:
        return "%d h" % (left // 3600)
    return "%d j" % (left // 86400)


def dur_text(sec):
    """Durée courte : « 45 s », « 12 min », « 1 h 05 »."""
    sec = int(sec or 0)
    if sec < 60:
        return "%d s" % sec
    if sec < 3600:
        return "%d min" % (sec // 60)
    return "%d h %02d" % (sec // 3600, sec % 3600 // 60)


def money_text(c):
    c = int(c or 0)
    g, s = c // 10000, (c // 100) % 100
    return ("%s po" % format(g, ",").replace(",", " ")) if g else ("%d pa" % s)


def ago_text(t):
    if not t:
        return "jamais"
    d = time.time() - t
    if d < 120:
        return "maintenant"
    if d < 3600:
        return "il y a %d min" % (d // 60)
    if d < 86400:
        return "il y a %d h" % (d // 3600)
    return "il y a %d j" % (d // 86400)


def game_exe(addons):
    """Exécutable du jeu à côté du dossier Interface (WoW Forever), ou None."""
    d = game_dir(addons)
    try:
        names = os.listdir(d)
    except OSError:
        return None
    for want in ("WowClassic.exe", "Wow.exe", "WoWForever.exe", "WowForever.exe"):
        for n in names:
            if n.lower() == want.lower():
                return os.path.join(d, n)
    for n in names:
        if n.lower().endswith(".exe") and "wow" in n.lower() and "launcher" not in n.lower():
            return os.path.join(d, n)
    return None


_running = [0.0, False]


def game_running():
    """Le jeu tourne-t-il ? (liste des processus, gardée 5 s : l'accueil la relit à chaque rafraîchissement)"""
    if not IS_WIN:
        return False
    now = time.time()
    if now - _running[0] < 5:
        return _running[1]
    try:
        out = subprocess.run(["tasklist", "/FO", "CSV", "/NH"], capture_output=True, text=True,
                             creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0)).stdout.lower()
        res = any(l.startswith('"wow') for l in out.splitlines())
    except OSError:
        res = False
    _running[0], _running[1] = now, res
    return res


def open_folder(path):
    if IS_WIN:
        os.startfile(path)  # noqa
    elif sys.platform == "darwin":
        subprocess.Popen(["open", path])
    else:
        subprocess.Popen(["xdg-open", path])


# ---------------------------------------------------------------------------
# GitHub (Releases)
# ---------------------------------------------------------------------------
class NetError(Exception):
    pass


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *a, **k):
        return None


class GitHub:
    def __init__(self, token=""):
        self.token = (token or "").strip()

    def _open(self, url, accept="application/vnd.github+json", auth=True, follow=True):
        req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": accept})
        if auth and self.token:
            req.add_header("Authorization", "Bearer " + self.token)
        opener = urllib.request.build_opener() if follow else urllib.request.build_opener(_NoRedirect)
        try:
            return opener.open(req, timeout=30)
        except urllib.error.HTTPError as e:
            if not follow and e.code in (301, 302, 303, 307, 308):
                return e
            if e.code in (401, 403) and self.token:
                raise NetError("Le jeton GitHub est refusé (expiré ou sans accès au dépôt). Vérifie-le dans Réglages.")
            if e.code == 404:
                raise NetError("Dépôt introuvable : il est privé ? Ajoute un jeton GitHub dans Réglages."
                               if not self.token else "Rien de publié pour l'instant sur GitHub.")
            raise NetError("GitHub répond %d." % e.code)
        except (urllib.error.URLError, OSError) as e:
            raise NetError("Pas de connexion à GitHub (%s)." % getattr(e, "reason", e))

    def api(self, method, path, body=None):
        """Appel de l'API du dépôt (lecture ou écriture) ; rend le JSON (ou None)."""
        data = json.dumps(body).encode("utf-8") if body is not None else None
        req = urllib.request.Request(API + path, data=data, method=method,
                                     headers={"User-Agent": UA, "Accept": "application/vnd.github+json"})
        if data is not None:
            req.add_header("Content-Type", "application/json")
        if self.token:
            req.add_header("Authorization", "Bearer " + self.token)
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                raw = r.read()
                return json.loads(raw) if raw else None
        except urllib.error.HTTPError as e:
            if e.code in (401, 403, 404) and method != "GET":
                raise NetError("Ton jeton n'a pas le droit de faire ça : il lui faut aussi « Contents : Read and write » "
                               "et « Actions : Read and write » sur le dépôt (voir le mode d'emploi).")
            if e.code in (401, 403, 404):
                raise NetError("Accès refusé : vérifie le jeton (il lui faut au moins « Actions : Read-only » pour l'état des données).")
            raise NetError("GitHub répond %d." % e.code)
        except (urllib.error.URLError, OSError) as e:
            raise NetError("Pas de connexion à GitHub (%s)." % getattr(e, "reason", e))

    def rest(self, method, path, body=None):
        """Appel de l'API GitHub hors du dépôt (chemin après api.github.com : /user, /repos/<fork>/…)."""
        data = json.dumps(body).encode("utf-8") if body is not None else None
        req = urllib.request.Request("https://api.github.com" + path, data=data, method=method,
                                     headers={"User-Agent": UA, "Accept": "application/vnd.github+json"})
        if data is not None:
            req.add_header("Content-Type", "application/json")
        if self.token:
            req.add_header("Authorization", "Bearer " + self.token)
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                raw = r.read()
                return json.loads(raw) if raw else None
        except urllib.error.HTTPError as e:
            if e.code in (401, 403):
                raise NetError("Jeton GitHub refusé (il lui faut le droit « public_repo »).")
            raise NetError("GitHub répond %d." % e.code)
        except (urllib.error.URLError, OSError) as e:
            raise NetError("Pas de connexion à GitHub (%s)." % getattr(e, "reason", e))

    def can_push(self):
        """Le jeton peut-il écrire sur le dépôt (mainteneur) ? Sinon les découvertes passent par un fork."""
        r = self.rest("GET", "/repos/" + REPO) or {}
        return bool((r.get("permissions") or {}).get("push"))

    def learned_contribute(self, data, src, what):
        """Joueur sans droit d'écriture : copie (fork) du dépôt sur son compte, une branche avec le fichier
        tools/learned/inbox/<src>-<date>.json (ses découvertes nouvelles, format .wkd) et une demande de fusion vers
        le dépôt. Rend l'adresse de la demande."""
        import base64
        login = (self.rest("GET", "/user") or {}).get("login")
        if not login:
            raise NetError("Jeton GitHub sans compte lisible.")
        fork = (self.rest("POST", "/repos/%s/forks" % REPO, {"default_branch_only": True}) or {}).get("full_name")
        if not fork:
            raise NetError("Copie du dépôt impossible sur ton compte GitHub.")
        # la copie met quelques secondes à exister ; puis elle est remise à jour avec le dépôt
        for _ in range(15):
            try:
                self.rest("GET", "/repos/%s/git/ref/heads/main" % fork)
                break
            except NetError:
                time.sleep(2)
        try:
            self.rest("POST", "/repos/%s/merge-upstream" % fork, {"branch": "main"})
        except NetError:
            pass
        head = self.api("GET", "/git/ref/heads/main")["object"]["sha"]
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        branch = "decouvertes-%s-%s" % (src, stamp)
        self.rest("POST", "/repos/%s/git/refs" % fork, {"ref": "refs/heads/" + branch, "sha": head})
        path = "%s/%s-%s.json" % (LEARNED_INBOX, src, stamp)
        self.rest("PUT", "/repos/%s/contents/%s" % (fork, path), {
            "message": "Découvertes proposées : %s (client PC)" % what, "branch": branch,
            "content": base64.b64encode(learned.export_wkd(data, src).encode("utf-8")).decode("ascii")})
        pr = self.api("POST", "/pulls", {
            "title": "Découvertes proposées : %s" % what, "head": "%s:%s" % (login, branch), "base": "main",
            "maintainer_can_modify": True,
            "body": "Découvertes d'un autre joueur, envoyées par son client PC (page Découvertes) : un seul fichier "
                    "dans %s, fusionné ensuite dans la base par le client du mainteneur." % LEARNED_INBOX})
        return pr.get("html_url")

    def learned_inbox(self):
        """Découvertes proposées par les autres joueurs (fichiers de tools/learned/inbox sur main) : [(src, data)]."""
        import base64
        try:
            files = self.api("GET", "/contents/%s?ref=main" % LEARNED_INBOX) or []
        except NetError:
            return []
        out = []
        for f in files if isinstance(files, list) else []:
            if not str(f.get("name", "")).endswith(".json") or (f.get("size") or 0) > 2000000:
                continue
            try:
                r = self.api("GET", "/git/blobs/" + f["sha"])
                src, data = learned.read_wkd(base64.b64decode(r.get("content") or "").decode("utf-8"))
                out.append((src, data))
            except (NetError, ValueError, KeyError):
                pass
        return out

    def merge_friend_prs(self, friends):
        """Mainteneur : fusionne les demandes de découvertes des joueurs de confiance (comptes GitHub de friends)
        qui n'ajoutent que des fichiers .json dans tools/learned/inbox. Rend le nombre fusionné."""
        friends = {str(f).strip().lower() for f in friends or [] if str(f).strip()}
        if not friends:
            return 0
        n = 0
        for pr in self.api("GET", "/pulls?state=open&per_page=50") or []:
            who = ((pr.get("user") or {}).get("login") or "").lower()
            if who not in friends:
                continue
            files = self.api("GET", "/pulls/%d/files?per_page=20" % pr["number"]) or []
            ok = files and all(f.get("status") == "added" and str(f.get("filename", "")).startswith(LEARNED_INBOX + "/")
                               and str(f.get("filename", "")).endswith(".json") for f in files)
            if not ok:
                continue
            try:
                self.api("PUT", "/pulls/%d/merge" % pr["number"], {"merge_method": "squash"})
                n += 1
            except NetError:
                pass
        return n

    def schedule(self):
        """Planning des données (tools/update_schedule.json) : (réglages, sha du fichier)."""
        import base64
        r = self.api("GET", "/contents/" + SCHEDULE_PATH + "?ref=main")
        return json.loads(base64.b64decode(r["content"]).decode("utf-8")), r["sha"]

    def save_schedule(self, sched, sha):
        import base64
        content = (json.dumps(sched, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
        self.api("PUT", "/contents/" + SCHEDULE_PATH, {
            "message": "Données : fréquence « %s », publication %s (client PC)" % (
                sched.get("frequence"), "automatique" if sched.get("publier") else "par PR"),
            "content": base64.b64encode(content).decode("ascii"), "sha": sha, "branch": "main"})

    def run_data_update(self):
        self.api("POST", "/actions/workflows/%s/dispatches" % DATA_WORKFLOW, {"ref": "main"})

    def data_log(self):
        """Journal des données (Modules/DataLogDB.lua sur main) : [{ t, src, total, add, chg, rem, q }], le plus récent en tête."""
        import base64
        r = self.api("GET", "/contents/" + DATALOG_PATH + "?ref=main")
        txt = base64.b64decode(r["content"]).decode("utf-8")
        for line in txt.splitlines():
            if line.startswith("-- DATA "):
                return json.loads(line[8:])
        return []

    def learned_pr(self, sources, choices, direct=False):
        """Découvertes : fusionne les sources avec la base de main (tools/learned/learned.json), pousse la nouvelle
        base et Modules/LearnedDB.lua sur une branche decouvertes-<date> et ouvre une demande de fusion (rend son
        adresse) ; direct : écrit sur main, sans demande de fusion (rend { n, base }). None s'il n'y a rien de nouveau."""
        import base64

        def get(path):
            try:
                r = self.api("GET", "/contents/%s?ref=main" % path)
            except NetError:
                return None, None
            raw = r.get("content") or ""
            # fichier de plus d'1 Mo : l'API ne donne pas son contenu ici, il se lit par son blob
            if not raw.strip() and r.get("sha"):
                raw = self.api("GET", "/git/blobs/" + r["sha"]).get("content") or ""
            return base64.b64decode(raw).decode("utf-8"), r["sha"]
        text, jsha = get(LEARNED_JSON)
        # base présente mais vide ou illisible : on s'arrête (avant, elle était remplacée par les seules sources,
        # tout le reste était effacé sur main)
        if jsha:
            try:
                json.loads(text or "")
            except ValueError:
                raise RuntimeError("base des découvertes illisible sur GitHub : rien n'a été envoyé")
        base = learned.from_json(text) if text else {}
        # découvertes proposées par les autres joueurs (fusionnées dans tools/learned/inbox) : sources « autre joueur »
        known_src = {s.get("name") for s in sources}
        for src, data in self.learned_inbox():
            if src not in known_src:
                sources = list(sources) + [{"name": src, "trusted": False, "data": data}]
                known_src.add(src)
        rows = learned.merge(sources, base, choices)
        added = [r for r in rows if r["status"] == learned.INTEGRATED]
        if not added:
            return None
        new = learned.build(base, rows)
        branch = "main"
        head = self.api("GET", "/git/ref/heads/main")["object"]["sha"]
        if not direct:
            branch = "decouvertes-" + datetime.now().strftime("%Y%m%d-%H%M%S")
            self.api("POST", "/git/refs", {"ref": "refs/heads/" + branch, "sha": head})
        per = {}
        for r in added:
            per[r["genre"]] = per.get(r["genre"], 0) + 1
        what = ", ".join("%s %d" % (learned.LABEL[g].lower(), n) for g, n in per.items())
        # les deux fichiers dans un seul commit (avant : deux écritures, la base et le .lua pouvaient se
        # désaccorder si la seconde échouait) ; main a bougé entre-temps : la mise à jour est refusée, rien n'est écrit
        tree_base = self.api("GET", "/git/commits/" + head)["tree"]["sha"]
        tree = self.api("POST", "/git/trees", {"base_tree": tree_base, "tree": [
            {"path": LEARNED_JSON, "mode": "100644", "type": "blob", "content": learned.to_json(new)},
            {"path": LEARNED_LUA, "mode": "100644", "type": "blob", "content": learned.to_lua(new)}]})["sha"]
        commit = self.api("POST", "/git/commits", {"message": "Découvertes : %s (client PC)" % what,
                                                   "tree": tree, "parents": [head]})["sha"]
        self.api("PATCH", "/git/refs/heads/" + branch, {"sha": commit, "force": False})
        if direct:
            return {"n": len(added), "base": new, "what": what,
                    # détail du dernier envoi, avec ses sources (colonnes SOURCES et CONF. de la page)
                    "items": [{"t": learned.short(r["genre"], r["key"], r["value"]), "s": list(r.get("srcs") or []),
                               "c": r.get("confirm") or len(r.get("srcs") or [])} for r in added][:60]}
        pr = self.api("POST", "/pulls", {
            "title": "Découvertes : %d ajout%s" % (len(added), "s" if len(added) > 1 else ""), "head": branch, "base": "main",
            "body": "Découvertes intégrées à l'addon, envoyées par le client PC (page Découvertes).\n\n"
                    + "\n".join("- %s : %d" % (learned.LABEL[g], n) for g, n in per.items())
                    + "\n\nSources : %s." % ", ".join(s["name"] for s in sources)})
        return pr.get("html_url")

    def last_data_run(self):
        r = self.api("GET", "/actions/workflows/%s/runs?per_page=1" % DATA_WORKFLOW)
        runs = (r or {}).get("workflow_runs") or []
        return runs[0] if runs else None

    def client_notes(self, rel):
        """Notes du client (asset WarbandKeeper-Client-notes.md de la release), ou None."""
        for a in (rel or {}).get("assets", []):
            if a["name"] == "WarbandKeeper-Client-notes.md":
                tmp = os.path.join(tempfile.gettempdir(), "wk-client-notes.md")
                self.download(a, tmp)
                with open(tmp, encoding="utf-8") as f:
                    return f.read()
        return None

    def releases(self):
        with self._open(API + "/releases?per_page=40") as r:
            data = json.load(r)
        rel = [x for x in data if not x.get("draft") and not x.get("prerelease")]
        rel.sort(key=lambda x: vtuple(x.get("tag_name")), reverse=True)
        return rel

    def download(self, asset, dest, progress=None):
        if self.token:
            r = self._open(asset["url"], accept="application/octet-stream", follow=False)
            loc = r.headers.get("Location") if getattr(r, "code", 200) in (301, 302, 303, 307, 308) else None
            if loc:  # stockage de GitHub : sans le jeton (il refuserait deux identifications)
                r = self._open(loc, accept="application/octet-stream", auth=False)
        else:
            r = self._open(asset["browser_download_url"], accept="application/octet-stream", auth=False)
        # taille attendue : Content-Length (s'il est donné) et taille de l'asset annoncée par GitHub ; une
        # connexion coupée rend une réponse plus courte sans erreur : le fichier partiel est refusé et effacé
        try:
            sent = int(r.headers.get("Content-Length") or 0)
        except (TypeError, ValueError):
            sent = 0
        try:
            size = int(asset.get("size") or 0)
        except (TypeError, ValueError):
            size = 0
        total = sent or size
        done = 0
        try:
            try:
                with open(dest, "wb") as f:
                    while True:
                        chunk = r.read(65536)
                        if not chunk:
                            break
                        f.write(chunk)
                        done += len(chunk)
                        if progress and total:
                            progress(min(1.0, done / total))
            finally:
                r.close()
            want = [n for n in (sent, size) if n]
            if not done or any(done != n for n in want):
                raise NetError("Téléchargement incomplet de %s (%d octets reçus sur %d) : connexion coupée ? Réessaie."
                               % (asset.get("name") or "fichier", done, max(want or [0])))
        except BaseException as e:
            try:
                os.remove(dest)
            except OSError:
                pass
            if isinstance(e, (urllib.error.URLError, OSError)) and not isinstance(e, NetError):
                raise NetError("Téléchargement interrompu (%s). Réessaie." % getattr(e, "reason", e))
            raise


def client_only(rel):
    """Vrai pour une version qui ne livre que le client PC : toutes les lignes des notes de l'addon commencent par
    « Rien ne change en jeu » (Core/Changelog.lua). Pas de notification de l'addon pour elle."""
    body = ((rel or {}).get("body") or "").split("\n## Client PC")[0]
    items = [l.strip()[2:] for l in body.splitlines() if l.strip().startswith("- ")]
    return bool(items) and all(i.startswith("Rien ne change en jeu") for i in items)


def parse_client_notes(text):
    """client/CHANGELOG.md » [{ tag_name, date, body }] (même forme que les releases pour fill_notes)."""
    out, cur = [], None
    for line in (text or "").splitlines():
        m = re.match(r"^## (\d+\.\d+\.\d+)\s*(?:[—-]\s*(.+))?$", line)
        if m:
            cur = {"tag_name": m.group(1), "date": (m.group(2) or "").strip(), "body": ""}
            out.append(cur)
        elif cur is not None:
            cur["body"] += line + "\n"
    return out


def bundled_client_notes():
    base = getattr(sys, "_MEIPASS", os.path.dirname(os.path.abspath(__file__)))
    try:
        with open(os.path.join(base, "CHANGELOG.md"), encoding="utf-8") as f:
            return f.read()
    except OSError:
        return ""


def addon_asset(rel):
    for a in rel.get("assets", []):
        if re.match(r"WarbandKeeper-[\d.]+\.zip$", a["name"]):
            return a
    return None


def client_asset(rel):
    for a in rel.get("assets", []):
        m = re.match(r"WarbandKeeper-Client-([\d.]+)\.exe$", a["name"])
        if m:
            return a, m.group(1)
    return None, None


def best_client(releases):
    """Client le plus récent joint à l'une des releases (pas seulement la dernière : juste après une
    nouvelle version de l'addon, la sienne n'a pas encore son exe, construit quelques minutes plus tard)."""
    best, bv = None, None
    for rel in releases or []:
        a, v = client_asset(rel)
        if a and (bv is None or vtuple(v) > vtuple(bv)):
            best, bv = a, v
    return best, bv


# ---------------------------------------------------------------------------
# Installation, sauvegardes, version précédente
# ---------------------------------------------------------------------------
def backups_dir():
    d = os.path.join(data_dir(), "sauvegardes")
    os.makedirs(d, exist_ok=True)
    return d


def previous_dir():
    d = os.path.join(data_dir(), "precedente")
    os.makedirs(d, exist_ok=True)
    return d


def backup_saved_variables(addons, version, keep=15, why="avant mise à jour"):
    files = saved_variables(addons, chars=True)
    if not files:
        return None
    root = game_dir(addons)
    name = "Reglages-%s-v%s.zip" % (datetime.now().strftime("%Y-%m-%d_%H-%M-%S"), safe_name(version))
    path = os.path.join(backups_dir(), name)
    # écrite à côté (« .tmp ») puis renommée : une sauvegarde interrompue (disque plein, fichier verrouillé)
    # ne laisse jamais un zip incomplet compté parmi les sauvegardes
    tmp = path + ".tmp"
    try:
        with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as z:
            z.writestr("_info.txt", "Warband Keeper %s · %s · %s\n" % (version, why, datetime.now().strftime("%d/%m/%Y %H:%M")))
            for f in files:
                z.write(f, os.path.relpath(f, root))
        os.replace(tmp, path)
    except BaseException:
        try:
            os.remove(tmp)
        except OSError:
            pass
        raise
    # seules les sauvegardes complètes comptent ; un « .tmp » laissé par un client fermé en pleine sauvegarde
    # (plus d'une heure) est effacé
    for n in os.listdir(backups_dir()):
        q = os.path.join(backups_dir(), n)
        try:
            if n.endswith(".zip.tmp") and time.time() - os.path.getmtime(q) > 3600:
                os.remove(q)
        except OSError:
            pass
    olds = sorted(list_backups(), key=lambda b: b["time"], reverse=True)
    for b in olds[keep:]:
        try:
            os.remove(b["path"])
        except OSError:
            pass
    return path


def list_backups():
    out = []
    for n in os.listdir(backups_dir()):
        if n.endswith(".zip"):
            p = os.path.join(backups_dir(), n)
            info = ""
            try:
                with zipfile.ZipFile(p) as z:
                    info = z.read("_info.txt").decode("utf-8", "replace").strip()
                    count = len([x for x in z.namelist() if x.endswith(".lua")])
            except (OSError, KeyError, zipfile.BadZipFile):
                continue  # zip incomplet ou abîmé : ce n'est pas une sauvegarde (ni montrée, ni comptée)
            out.append({"path": p, "name": n, "time": os.path.getmtime(p), "info": info, "count": count})
    out.sort(key=lambda b: b["time"], reverse=True)
    return out


def restore_backup(addons, path):
    """Tout est d'abord extrait à côté de chaque fichier (« .wknew ») ; les fichiers ne sont remplacés
    (os.replace) qu'une fois toute la sauvegarde lue sans erreur : une sauvegarde abîmée ou un disque plein ne
    laisse plus des réglages à moitié restaurés."""
    root = os.path.normpath(game_dir(addons))
    staged = []
    try:
        with zipfile.ZipFile(path) as z:
            for n in z.namelist():
                if n.startswith("_") or not n.endswith((".lua", ".bak")):
                    continue
                dest = os.path.normpath(os.path.join(root, n))
                if not dest.startswith(root + os.sep):
                    continue
                os.makedirs(os.path.dirname(dest), exist_ok=True)
                tmp = dest + ".wknew"
                with z.open(n) as src, open(tmp, "wb") as out:
                    shutil.copyfileobj(src, out)
                staged.append((tmp, dest))
    except Exception:
        for tmp, _ in staged:
            try:
                os.remove(tmp)
            except OSError:
                pass
        raise
    # Remplacement : chaque fichier actuel est d'abord mis de côté (« .wkold »). Si un remplacement échoue
    # (fichier bloqué par un autre programme…), ceux déjà remplacés sont remis tels qu'avant : jamais à moitié.
    done = []  # (dest, old ou None si le fichier n'existait pas)
    try:
        for tmp, dest in staged:
            old = None
            if os.path.exists(dest):
                old = dest + ".wkold"
                shutil.copy2(dest, old)
            done.append((dest, old))
            os.replace(tmp, dest)
    except Exception:
        for dest, old in reversed(done):
            try:
                if old:
                    os.replace(old, dest)
                elif os.path.exists(dest):
                    os.remove(dest)
            except OSError:
                pass
        for tmp, _ in staged:
            try:
                if os.path.exists(tmp):
                    os.remove(tmp)
            except OSError:
                pass
        raise
    for _, old in done:
        if old:
            try:
                os.remove(old)
            except OSError:
                pass


def safe_extract(zpath, dest_parent):
    with zipfile.ZipFile(zpath) as z:
        names = z.namelist()
        if not any(n == ADDON + "/" + ADDON + ".toc" for n in names):
            raise RuntimeError("Le fichier téléchargé n'est pas l'addon Warband Keeper.")
        base = os.path.normpath(dest_parent)
        keep = [n for n in names if n.startswith(ADDON + "/") or n.startswith(DATA_ADDON + "/")]
        for n in keep:
            target = os.path.normpath(os.path.join(base, n))
            if not target.startswith(base + os.sep):
                raise RuntimeError("Archive invalide.")
        z.extractall(base, keep)


def _files(folder):
    out = set()
    for d, _, fs in os.walk(folder):
        for f in fs:
            out.add(os.path.relpath(os.path.join(d, f), folder).replace(os.sep, "/").lower())
    return out


def _toc_body(folder, name=None):
    """Le .toc (de l'addon, ou de name) sans sa ligne ## Version (le reste change la liste des fichiers chargés)."""
    try:
        with open(os.path.join(folder, (name or ADDON) + ".toc"), encoding="utf-8", errors="replace") as f:
            return "\n".join(l.rstrip() for l in f if not l.startswith("## Version"))
    except OSError:
        return None


def _recover_aside(addons):
    """Dossier « .__wkold » laissé par un arrêt brutal pendant une installation (le jeu ne le charge pas) : remis
    à sa place si le vrai dossier manque, sinon effacé."""
    for name in (ADDON, DATA_ADDON):
        path = os.path.join(addons, name)
        old = path + ".__wkold"
        try:
            if os.path.isdir(old):
                if not os.path.exists(path):
                    os.rename(old, path)
                else:
                    shutil.rmtree(old, ignore_errors=True)
            fail = path + ".__wkfail"
            if os.path.isdir(fail):
                shutil.rmtree(fail, ignore_errors=True)
        except OSError:
            pass


def _undo_aside(targets, aside):
    """Retour en arrière : le morceau en place est d'abord RENOMMÉ à côté (un renommage passe même quand
    l'antivirus garde un fichier ouvert, un effacement non), puis l'original reprend son nom."""
    for path, old in reversed(aside):
        try:
            if os.path.exists(path):
                fail = path + ".__wkfail"
                if os.path.exists(fail):
                    shutil.rmtree(fail, ignore_errors=True)
                os.rename(path, fail)
            os.rename(old, path)
        except OSError:
            pass
    for path in targets:
        fail = path + ".__wkfail"
        if os.path.isdir(fail):
            shutil.rmtree(fail, ignore_errors=True)


def _keep_copy(src_main, src_data, dest):
    """Copie de secours vers « precedente » : sous un nom temporaire, renommé seulement une fois complète ;
    une copie ratée est effacée (avant, une copie incomplète restait et « Revenir » la remettait). Rend dest
    ou None."""
    tmp = dest + "-incomplet"
    try:
        if os.path.exists(tmp):
            shutil.rmtree(tmp, ignore_errors=True)
        shutil.move(src_main, tmp)
        if src_data:
            shutil.move(src_data, os.path.join(tmp, DATA_KEEP))
        if os.path.exists(dest):
            shutil.rmtree(dest, ignore_errors=True)
        os.rename(tmp, dest)
        os.utime(dest, None)
        return dest
    except OSError:
        shutil.rmtree(tmp, ignore_errors=True)
        return None


def _prune_previous(keep_first):
    """On ne garde que les 2 dernières versions, jamais celle qu'on vient de ranger ; une erreur ici ne fait
    pas échouer l'installation (elle a réussi)."""
    try:
        olds = sorted((os.path.join(previous_dir(), d) for d in os.listdir(previous_dir())
                       if not d.endswith(("-ancienne", "-retire", "-incomplet"))), key=os.path.getmtime, reverse=True)
        keep = [keep_first] if keep_first else []
        for d in olds:
            if len(keep) >= 2:
                break
            if d not in keep:
                keep.append(d)
        for d in olds:
            if d not in keep:
                shutil.rmtree(d, ignore_errors=True)
    except OSError:
        pass


def install_zip(addons, zpath, old_version):
    """Installe le zip ; rend True s'il faut redémarrer complètement le jeu (nouveaux fichiers ou .toc
    modifié : le jeu ne les charge qu'au lancement), False si un /reload suffit."""
    target = os.path.join(addons, ADDON)
    data = os.path.join(addons, DATA_ADDON)
    moved = None
    oldFiles = _files(target) if os.path.isdir(target) else None
    oldToc = _toc_body(target) if os.path.isdir(target) else None
    oldData = _files(data) if os.path.isdir(data) else None
    oldDataToc = _toc_body(data, DATA_ADDON) if os.path.isdir(data) else None
    # Transactionnel : les dossiers en place sont d'abord renommés à côté, dans AddOns (même disque : un
    # renommage est immédiat et ne peut pas s'arrêter au milieu) ; si l'extraction échoue, le morceau extrait est
    # retiré et les dossiers reprennent leur nom. La copie de secours vers « precedente » (souvent sur un autre
    # disque) n'est faite qu'après la réussite, et son échec ne casse rien.
    _recover_aside(addons)
    aside = []
    extracted = False
    try:
        for path in (target, data):
            if os.path.isdir(path):
                old = path + ".__wkold"
                if os.path.exists(old):
                    shutil.rmtree(old, ignore_errors=True)
                os.rename(path, old)
                aside.append((path, old))
        extracted = True
        safe_extract(zpath, addons)
    except Exception:
        # morceau extrait (seulement s'il y a eu extraction : un dossier pas encore renommé est l'original)
        if extracted:
            for path in (target, data):
                if os.path.isdir(path) and not any(p == path for p, _ in aside):
                    try:
                        os.rename(path, path + ".__wkfail")  # première installation : rien à remettre
                    except OSError:
                        shutil.rmtree(path, ignore_errors=True)
        _undo_aside((target, data), aside)
        raise
    olds = dict(aside)
    newVersion = None
    try:
        with open(os.path.join(target, ADDON + ".toc"), encoding="utf-8", errors="replace") as f:
            m = re.search(r"^## Version:\s*(\S+)", f.read(), re.M)
            newVersion = m.group(1) if m else None
    except OSError:
        pass
    # version gardée pour « Revenir » : celle qu'on vient de remplacer, sauf si c'est la même (« Réparer » :
    # l'ancienne copie était abîmée, elle n'est pas gardée et ne chasse pas une vraie version précédente)
    keepOld = olds.get(target) and old_version and old_version != newVersion
    if keepOld:
        moved = _keep_copy(olds[target], olds.get(data),
                           os.path.join(previous_dir(), "%s-%s" % (ADDON, safe_name(old_version))))
    for old in olds.values():
        if os.path.exists(old):
            shutil.rmtree(old, ignore_errors=True)
    for path in (target, data):
        if os.path.isdir(path + ".__wkfail"):
            shutil.rmtree(path + ".__wkfail", ignore_errors=True)
    _prune_previous(moved)
    if oldFiles is None:
        return True  # première installation : le jeu doit être lancé (ou relancé) pour la voir
    newData = _files(data) if os.path.isdir(data) else None
    if newData is not None and (oldData is None or newData - oldData):
        return True  # dossier des données nouveau, ou nouveaux fichiers dedans
    if newData is not None and _toc_body(data, DATA_ADDON) != oldDataToc:
        return True  # .toc des données changé (fichier retiré ou renommé) : lu seulement au lancement
    return bool(_files(target) - oldFiles) or _toc_body(target) != oldToc


def write_latest(addons, version):
    """Écrit dans l'addon la dernière version publiée (Core/Latest.lua) : l'en-tête de l'addon affiche
    alors « Mise à jour x.y.z » (lu au lancement du jeu et à chaque /reload)."""
    if not (addons and version and re.match(r"^[0-9.]+$", version)):
        return
    core = os.path.join(addons, ADDON, "Core")
    if not os.path.isdir(core):
        return
    path = os.path.join(core, "Latest.lua")
    body = ("local ADDON_NAME, WK = ...\n"
            "-- Écrit par le client PC Warband Keeper : dernière version publiée vue sur GitHub.\n"
            "WK.Latest = { version = \"%s\", checked = %d }\n" % (version, int(time.time())))
    try:
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(body)
    except OSError:
        pass


def previous_versions():
    out = []
    for d in os.listdir(previous_dir()):
        p = os.path.join(previous_dir(), d)
        # (mises de côté d'un retour en arrière interrompu : pas des versions à remettre)
        if os.path.isdir(p) and not d.endswith(("-ancienne", "-retire", "-incomplet")) \
                and os.path.isfile(os.path.join(p, ADDON + ".toc")):
            out.append({"path": p, "version": d.split("-", 1)[-1], "time": os.path.getmtime(p)})
    out.sort(key=lambda x: x["time"], reverse=True)
    return out


def rollback(addons, prev):
    """Remet la version gardée prev. Transactionnel : la version en place est renommée à côté (même disque),
    la version gardée est COPIÉE dans AddOns ; si quelque chose échoue, la copie est mise de côté et la
    version en place reprend son nom. Après la réussite seulement, la version quittée est rangée dans
    « precedente » (sous un nom temporaire, renommé une fois complète). Rend la version quittée."""
    target = os.path.join(addons, ADDON)
    data = os.path.join(addons, DATA_ADDON)
    if not os.path.isfile(os.path.join(prev["path"], ADDON + ".toc")):
        raise OSError("la version gardée est incomplète")
    _recover_aside(addons)
    cur = installed_version(addons)
    aside = []
    copied = False
    try:
        for path in (target, data):
            if os.path.isdir(path):
                old = path + ".__wkold"
                if os.path.exists(old):
                    shutil.rmtree(old, ignore_errors=True)
                os.rename(path, old)
                aside.append((path, old))
        copied = True
        shutil.copytree(prev["path"], target)
        kept = os.path.join(target, DATA_KEEP)
        if os.path.isdir(kept):
            os.rename(kept, data)
    except Exception:
        if copied:
            for path in (target, data):
                if os.path.isdir(path) and not any(p == path for p, _ in aside):
                    try:
                        os.rename(path, path + ".__wkfail")
                    except OSError:
                        shutil.rmtree(path, ignore_errors=True)
        _undo_aside((target, data), aside)
        raise
    olds = dict(aside)
    # version gardée remise : retirée de « precedente » ; la version quittée y est rangée à sa place
    shutil.rmtree(prev["path"], ignore_errors=True)
    dest = None
    if olds.get(target):
        dest = _keep_copy(olds[target], olds.get(data), os.path.join(previous_dir(), "%s-%s" % (ADDON, safe_name(cur))))
    for old in olds.values():
        if os.path.exists(old):
            shutil.rmtree(old, ignore_errors=True)
    return cur


def safe_name(v):
    """Morceau de nom de dossier sûr sous Windows (chiffres, lettres, points)."""
    return re.sub(r"[^0-9A-Za-z.]", "_", v or "inconnue") or "inconnue"


def clean_env():
    """Environnement pour lancer une nouvelle instance du client : sans les variables de PyInstaller héritées
    (_MEIPASS2, _PYI_*), sinon le nouvel exe cherche ses fichiers dans le dossier temporaire de l'ancien,
    effacé à sa fermeture (« Failed to load Python DLL … _MEIxxxx\\python312.dll »)."""
    env = {k: v for k, v in os.environ.items() if not (k.startswith("_PYI") or k.startswith("_MEI"))}
    env["PYINSTALLER_RESET_ENVIRONMENT"] = "1"  # PyInstaller 6.10+ : nouvelle instance indépendante
    return env


def self_update(exe_path):
    """Remplace l'exe du client par exe_path (téléchargé) à la fermeture, puis le relance (environnement propre)."""
    cur = sys.executable
    bat = os.path.join(tempfile.gettempdir(), "wk-client-update.bat")
    # en UTF-8 avec « chcp 65001 » : un chemin accentué (C:\Users\Hélène) est lu correctement par cmd.exe ;
    # au plus 60 essais (une minute) pour remplacer l'exe, puis on relance quand même l'ancien
    with open(bat, "w", encoding="utf-8") as f:
        f.write('@echo off\r\nchcp 65001 >nul\r\nset n=0\r\n:wait\r\ntimeout /t 1 /nobreak >nul\r\n'
                'set /a n+=1\r\n'
                'move /y "%s" "%s" >nul 2>&1 && goto done\r\n'
                'if %%n%% lss 60 goto wait\r\n'
                ':done\r\n'
                'timeout /t 2 /nobreak >nul\r\n'  # laisse l'ancien client finir de ranger ses fichiers temporaires
                'start "" "%s"\r\ndel "%%~f0"\r\n' % (exe_path, cur, cur))
    subprocess.Popen(["cmd", "/c", bat], env=clean_env(), creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))


# ---------------------------------------------------------------------------
# Widgets (dessinés : coins arrondis, survol)
# ---------------------------------------------------------------------------
def rounded(cv, x1, y1, x2, y2, r, **kw):
    r = max(0, min(r, (x2 - x1) / 2, (y2 - y1) / 2))
    pts = [x1 + r, y1, x2 - r, y1, x2, y1, x2, y1 + r, x2, y2 - r, x2, y2, x2 - r, y2, x1 + r, y2,
           x1, y2, x1, y2 - r, x1, y1 + r, x1, y1]
    return cv.create_polygon(pts, smooth=True, **kw)


class Button(tk.Canvas):
    STYLES = {
        "primary": ("accent", "accent2", "onAccent", None),
        "secondary": ("surface2", "hover", "text", "border"),
        "ghost": ("surface", "hover", "muted", None),
        "danger": ("surface2", "hover", "negative", "border"),
        "ok": ("positive", "positive", "bg", None),       # à jour : vert, même inactif
        "alert": ("negative", "negative", "bg", None),    # mise à jour à faire : rouge
    }

    def __init__(self, parent, text, command=None, style="secondary", width=None, height=36, font=None):
        self.f = font or App.fonts["btn"]
        w = width or (self.f.measure(text) + 36)
        super().__init__(parent, width=w, height=height, highlightthickness=0, bd=0,
                         bg=parent["bg"], cursor="hand2")
        self.text, self.command, self.style, self.enabled, self.hover = text, command, style, True, False
        self.bind("<Enter>", lambda e: self._set_hover(True))
        self.bind("<Leave>", lambda e: self._set_hover(False))
        self.bind("<Button-1>", self._click)
        self.bind("<Configure>", lambda e: self.draw())
        self.draw()

    def _set_hover(self, v):
        self.hover = v
        self.draw()

    def _click(self, _):
        if self.enabled and self.command:
            self.command()

    def set(self, text=None, enabled=None, style=None):
        if text is not None:
            self.text = text
            self.configure(width=max(int(self["width"]), self.f.measure(text) + 36))
        if enabled is not None:
            self.enabled = enabled
            self.configure(cursor="hand2" if enabled else "arrow")
        if style is not None:
            self.style = style
        self.draw()

    def draw(self):
        self.delete("all")
        w, h = self.winfo_width(), self.winfo_height()
        if w < 4:
            w, h = int(self["width"]), int(self["height"])
        bg, hv, fg, border = self.STYLES[self.style]
        fill = C[hv if (self.hover and self.enabled) else bg]
        if border:
            rounded(self, 1, 1, w - 1, h - 1, 10, fill=C[border])
            rounded(self, 2, 2, w - 2, h - 2, 9, fill=fill)
        else:
            rounded(self, 1, 1, w - 1, h - 1, 10, fill=fill)
        color = C[fg] if (self.enabled or self.style in ("ok", "alert")) else C["dim"]
        if not self.enabled and self.style == "primary":
            self.delete("all")
            rounded(self, 1, 1, w - 1, h - 1, 10, fill=C["surface2"])
        self.create_text(w / 2, h / 2, text=self.text, fill=color, font=self.f)


class Progress(tk.Canvas):
    def __init__(self, parent, height=8):
        super().__init__(parent, height=height, highlightthickness=0, bd=0, bg=parent["bg"])
        self.value = 0
        self.bind("<Configure>", lambda e: self.draw())

    def set(self, v):
        self.value = max(0.0, min(1.0, v))
        self.draw()

    def draw(self):
        self.delete("all")
        w, h = self.winfo_width(), self.winfo_height()
        rounded(self, 0, 0, w, h, h / 2, fill=C["surface2"])
        if self.value > 0:
            rounded(self, 0, 0, max(h, w * self.value), h, h / 2, fill=C["accent"])


class Chip(tk.Canvas):
    def __init__(self, parent, text="", color=None):
        super().__init__(parent, height=24, width=10, highlightthickness=0, bd=0, bg=parent["bg"])
        self.set(text, color)

    def set(self, text, color=None):
        self.delete("all")
        f = App.fonts["small"]
        w = f.measure(text) + 22
        self.configure(width=w)
        col = color or C["muted"]
        rounded(self, 0, 0, w, 24, 12, fill=C["surface2"], outline="")
        self.create_oval(9, 9, 15, 15, fill=col, outline="")
        self.create_text(18, 12, text=text, fill=col, font=f, anchor="w")


class Segmented(tk.Frame):
    """Choix exclusif en boutons côte à côte (le choisi en bleu)."""

    def __init__(self, parent, options, get, set_):
        super().__init__(parent, bg=parent["bg"])
        self.get, self.set_, self.btns = get, set_, {}
        for value, text in options:
            b = Button(self, text, lambda v=value: (self.set_(v), self.refresh()), "ghost", height=30)
            b.pack(side="left", padx=(0, 4))
            self.btns[value] = b
        self.refresh()

    def refresh(self):
        cur = self.get()
        for v, b in self.btns.items():
            b.set(style="primary" if v == cur else "ghost")


class ThinScroll(tk.Canvas):
    """Barre de défilement du thème : rail sombre, curseur arrondi fin (bleu au survol et au glisser),
    cachée quand tout le contenu se voit. S'utilise comme un tk.Scrollbar (command / set)."""

    def __init__(self, parent, command, bg=None, width=10):
        super().__init__(parent, width=width, highlightthickness=0, bd=0, bg=bg or parent["bg"], cursor="hand2")
        self.command, self.first, self.last, self.hover, self.drag = command, 0.0, 1.0, False, None
        self.bind("<Configure>", lambda e: self.draw())
        self.bind("<Enter>", lambda e: self._hover(True))
        self.bind("<Leave>", lambda e: self._hover(False))
        self.bind("<ButtonPress-1>", self._press)
        self.bind("<B1-Motion>", self._move)
        self.bind("<ButtonRelease-1>", lambda e: (setattr(self, "drag", None), self.draw()))

    def set(self, first, last):
        self.first, self.last = float(first), float(last)
        self.draw()

    def _hover(self, v):
        self.hover = v
        self.draw()

    def _press(self, e):
        h = max(1, self.winfo_height())
        if self.first * h <= e.y <= self.last * h:
            self.drag = (e.y, self.first)
        else:
            # clic sur le rail : le curseur vient se centrer sous la souris
            span = self.last - self.first
            self.command("moveto", max(0.0, min(1.0 - span, e.y / h - span / 2)))

    def _move(self, e):
        if not self.drag:
            return
        h = max(1, self.winfo_height())
        y0, f0 = self.drag
        span = self.last - self.first
        self.command("moveto", max(0.0, min(1.0 - span, f0 + (e.y - y0) / h)))

    def draw(self):
        self.delete("all")
        if self.last - self.first >= 0.999:
            return
        w, h = self.winfo_width(), self.winfo_height()
        bw = 6 if (self.hover or self.drag) else 4
        x = (w - bw) / 2
        rounded(self, x, 2, x + bw, h - 2, bw / 2, fill=C["surface2"], outline="")
        y1, y2 = 2 + self.first * (h - 4), 2 + self.last * (h - 4)
        y2 = max(y2, y1 + 24)
        rounded(self, x, y1, x + bw, y2, bw / 2, fill=C["accent"] if (self.hover or self.drag) else C["border"], outline="")


class ScrollArea(tk.Frame):
    """Contenu qui défile (molette) : on remplit self.inner."""

    def __init__(self, parent, bar=True):
        super().__init__(parent, bg=C["bg"])
        self.bar = bar
        self.cv = tk.Canvas(self, bg=C["bg"], highlightthickness=0, bd=0)
        self.sb = ThinScroll(self, self.cv.yview, C["bg"])
        self.inner = tk.Frame(self.cv, bg=C["bg"])
        self.win = self.cv.create_window(0, 0, window=self.inner, anchor="nw")
        self.cv.configure(yscrollcommand=self.sb.set)
        self.cv.pack(side="left", fill="both", expand=True)
        # barre de défilement seulement si le contenu dépasse (jamais quand bar=False : la molette suffit)
        self.inner.bind("<Configure>", lambda e: self._fit())
        self.cv.bind("<Configure>", lambda e: (self.cv.itemconfigure(self.win, width=e.width - 4), self._fit()))

    def _fit(self):
        self.cv.configure(scrollregion=self.cv.bbox("all"))
        over = self.inner.winfo_reqheight() > self.cv.winfo_height() + 2
        if self.bar and over and not self.sb.winfo_ismapped():
            self.sb.pack(side="right", fill="y", before=self.cv)
        elif (not over or not self.bar) and self.sb.winfo_ismapped():
            self.sb.pack_forget()
        if not over:
            self.cv.yview_moveto(0)
        # molette liée une seule fois (avant : à chaque redimensionnement, des centaines de liaisons en double)
        if not getattr(self, "_wheelBound", False):
            self._wheelBound = True
            self.bind_all("<MouseWheel>", self._wheel, add="+")
            self.bind_all("<Button-4>", lambda e: self._scroll(-1), add="+")
            self.bind_all("<Button-5>", lambda e: self._scroll(1), add="+")

    def _scroll(self, n):
        if self.winfo_ismapped():
            self.cv.yview_scroll(n, "units")

    def _wheel(self, e):
        self._scroll(-1 if e.delta > 0 else 1)


class Card(tk.Frame):
    """Carte : cadre arrondi dessiné derrière un Frame intérieur (self.body)."""

    def __init__(self, parent, title=None, subtitle=None):
        super().__init__(parent, bg=C["bg"])
        self.cv = tk.Canvas(self, highlightthickness=0, bd=0, bg=C["bg"])
        self.cv.place(x=0, y=0, relwidth=1, relheight=1)
        self.body = tk.Frame(self, bg=C["surface"])
        self.body.pack(fill="both", expand=True, padx=1, pady=1)
        self.body.pack_configure(padx=14, pady=12)
        self.bind("<Configure>", self._draw)
        if title:
            head = tk.Frame(self.body, bg=C["surface"])
            head.pack(fill="x", pady=(0, 8))
            tk.Label(head, text=title, bg=C["surface"], fg=C["text"], font=App.fonts["h2"]).pack(side="left")
            if subtitle:
                tk.Label(head, text="  " + subtitle, bg=C["surface"], fg=C["muted"], font=App.fonts["small"]).pack(side="left", pady=(3, 0))
            self.head = head

    def _draw(self, e):
        self.cv.delete("all")
        rounded(self.cv, 0, 0, e.width, e.height, 14, fill=C["border"])
        rounded(self.cv, 1, 1, e.width - 1, e.height - 1, 13, fill=C["surface"])


def label(parent, text="", fg="text", font="body", **kw):
    return tk.Label(parent, text=text, bg=parent["bg"], fg=C[fg], font=App.fonts[font], justify="left", anchor="w", **kw)


# ---------------------------------------------------------------------------
# Pages
# ---------------------------------------------------------------------------
PAGES = []


def page(key, title, icon):
    def deco(cls):
        cls.key, cls.title, cls.icon = key, title, icon
        PAGES.append(cls)
        return cls
    return deco


class Page(tk.Frame):
    """Page du client (maquette « mix ») : en-tête de pastilles de chiffres clés (set_pills ; sans pastilles :
    le titre), état de l'addon et du client à droite (paint_status, clic = page Addon), roue = Réglages."""

    def __init__(self, app, parent):
        super().__init__(parent, bg=C["bg"])
        self.app = app
        head = tk.Frame(self, bg=C["bg"])
        head.pack(fill="x")
        self.head = head
        # à droite : laisse la place des boutons réduire / fermer de la fenêtre sans cadre
        right = tk.Frame(head, bg=C["bg"])
        right.pack(side="right", padx=(8, 92 if IS_WIN else 0))
        gear = label(right, "⚙", fg="muted", font="h2", cursor="hand2")
        gear.pack(side="right", padx=(8, 0))
        gear.bind("<Button-1>", lambda e: app.show("settings"))
        gear.bind("<Enter>", lambda e: gear.configure(fg=C["text"]))
        gear.bind("<Leave>", lambda e: gear.configure(fg=C["muted"]))
        self.stClient = Chip(right)
        self.stClient.pack(side="right", padx=(6, 0))
        self.stAddon = Chip(right)
        self.stAddon.pack(side="right")
        for ch in (self.stAddon, self.stClient):
            ch.configure(cursor="hand2")
            ch.bind("<Button-1>", lambda e: app.show("home"))
        self.pillBox = tk.Frame(head, bg=C["bg"])
        self.pillBox.pack(side="left", fill="x", expand=True)
        self.pillBox.bind("<Configure>", lambda e: self.fit_pills())
        tk.Frame(self, bg=C["border"], height=1).pack(fill="x", pady=(8, 10))
        self.set_pills(None)

    def set_pills(self, items):
        """items = [(libellé, valeur, couleur)] ; None = le titre de la page."""
        for w in self.pillBox.winfo_children():
            w.destroy()
        if not items:
            label(self.pillBox, self.title, font="h2").pack(side="left", pady=(2, 0))
            return
        # pastille arrondie, même style que l'état addon / client à droite (avant : rectangle à angles droits)
        fl, fv = App.fonts["smallb"], App.fonts["bodyb"]
        for lab, val, col in items:
            lw, vw = fl.measure(lab), fv.measure(str(val))
            w, h = 10 + lw + 6 + vw + 11, 24
            p = tk.Canvas(self.pillBox, width=w, height=h, bg=C["bg"], highlightthickness=0, bd=0)
            p.pill = True
            # fond plein sans liseré, comme Chip (le liseré au bord de la zone était rogné par Windows : coins en biais)
            rounded(p, 0, 0, w, h, 12, fill=C["surface2"], outline="")
            p.create_text(10, h / 2, text=lab, fill=C["dim"], font=fl, anchor="w")
            p.create_text(10 + lw + 6, h / 2, text=str(val), fill=C.get(col, col) if col else C["text"], font=fv, anchor="w")
            p.pack(side="left", padx=(0, 6))
        self.after_idle(self.fit_pills)

    def fit_pills(self):
        """Pastilles qui ne tiennent pas dans la largeur : cachées en entier (avant, la dernière était rognée)."""
        box = self.pillBox
        # page cachée : rien à mesurer, <Configure> rappellera à l'affichage (avant : relance toutes les 50 ms)
        if not box.winfo_ismapped():
            return
        width = box.winfo_width()
        if width <= 1:
            return self.after(50, self.fit_pills)
        x, full = 0, False
        for p in box.winfo_children():
            if not getattr(p, "pill", False):
                continue
            w = p.winfo_reqwidth() + 6
            if full or x + w > width:
                full = True
                if p.winfo_manager():
                    p.pack_forget()
            else:
                if not p.winfo_manager():
                    p.pack(side="left", padx=(0, 6))
                x += w

    def paint_status(self):
        a = self.app
        inst, latest = a.installed, a.latest_version
        if inst:
            newer = bool(latest and vtuple(latest) > vtuple(inst))
            self.stAddon.set("Addon %s" % inst, C["warning"] if newer else C["positive"])
        else:
            self.stAddon.set("Addon non installé", C["muted"])
        asset, ver = best_client(a.releases) if a.releases else (None, None)
        cnew = bool(asset and ver and vtuple(ver) > vtuple(CLIENT_VERSION))
        self.stClient.set("Client %s" % CLIENT_VERSION, C["warning"] if cnew else C["positive"])

    def on_show(self):
        pass

    def on_state(self):
        """Appelé quand l'état change (versions, dossier, sauvegardes)."""
        pass


def card_title(parent, text, right=None, rightColor="dim"):
    """Titre de carte en petites majuscules (comme l'addon), texte optionnel à droite."""
    row = tk.Frame(parent, bg=parent["bg"])
    row.pack(fill="x", pady=(0, 4))
    label(row, text.upper(), fg="dim", font="smallb").pack(side="left")
    r = None
    if right is not None:
        r = label(row, right, fg=rightColor, font="small")
        r.pack(side="right")
    return row, r


def thin_row(parent):
    """Ligne de liste séparée par un filet (listes des cartes de l'Accueil et de la page Addon)."""
    tk.Frame(parent, bg=C["border"], height=1).pack(fill="x")
    row = tk.Frame(parent, bg=parent["bg"])
    row.pack(fill="x", pady=3)
    return row


def link(parent, text, cmd, fg="accent"):
    w = label(parent, text, fg=fg, font="small", cursor="hand2")
    w.bind("<Button-1>", lambda e: cmd())
    return w



def notes_view(parent, height=10):
    wrap = tk.Frame(parent, bg=C["surface"])
    txt = tk.Text(wrap, bg=C["surface"], fg=C["text"], bd=0, highlightthickness=0, wrap="word",
                  font=App.fonts["body"], height=height, padx=2, pady=2, cursor="arrow",
                  selectbackground=C["hover"], insertwidth=0, spacing1=2, spacing3=2)
    sb = ThinScroll(wrap, txt.yview, C["surface"])
    txt.configure(yscrollcommand=sb.set)
    sb.pack(side="right", fill="y")
    txt.pack(side="left", fill="both", expand=True)
    txt.tag_configure("ver", foreground=C["accent"], font=App.fonts["h3"], spacing1=10, spacing3=4)
    txt.tag_configure("sec", foreground=C["muted"], font=App.fonts["smallb"], spacing1=6)
    txt.tag_configure("item", lmargin1=8, lmargin2=22)
    txt.tag_configure("dot", foreground=C["accent"])
    txt.tag_configure("muted", foreground=C["muted"])
    txt.tag_configure("restart", foreground=C["warning"], font=App.fonts["smallb"], spacing3=4)
    txt.tag_configure("reload", foreground=C["muted"], font=App.fonts["small"], spacing3=4)
    return wrap, txt


def fill_notes(txt, releases, empty="Rien de nouveau."):
    txt.configure(state="normal")
    txt.delete("1.0", "end")
    if not releases:
        txt.insert("end", empty, "muted")
    for rel in releases:
        txt.insert("end", "Version %s" % rel["tag_name"].lstrip("v"), "ver")
        when = (rel.get("published_at") or "")[:10]
        if when:
            txt.insert("end", "   " + "/".join(reversed(when.split("-"))), "muted")
        elif rel.get("date"):
            txt.insert("end", "   " + rel["date"], "muted")
        txt.insert("end", "\n")
        body = (rel.get("body") or "").split("\n## Client PC")[0]
        for line in body.splitlines():
            line = line.rstrip()
            if not line or line.startswith("## "):
                continue
            if line.startswith("_") and line.endswith("_"):
                t = line.strip("_")
                txt.insert("end", ("⟳  " if "Redémarrage" in t else "↻  ") + t + "\n", "restart" if "Redémarrage" in t else "reload")
            elif line.startswith("### "):
                txt.insert("end", line[4:] + "\n", "sec")
            elif line.startswith("- "):
                txt.insert("end", "•  ", ("item", "dot"))
                txt.insert("end", line[2:] + "\n", "item")
            else:
                txt.insert("end", line + "\n", "muted")
    txt.configure(state="disabled")
    txt.yview_moveto(0)


def tile(parent, title, chip=None, chipColor=None):
    """Tuile du tableau de bord : carte avec titre (et pastille)."""
    c = Card(parent, title)
    if chip:
        Chip(c.head, chip, chipColor or C["warning"]).pack(side="left", padx=(8, 0))
    return c


def tline(parent, left, right, rightColor="muted"):
    row = tk.Frame(parent, bg=C["surface"])
    row.pack(fill="x", pady=1)
    label(row, left, font="small").pack(side="left")
    label(row, right, fg=rightColor, font="small").pack(side="right")
    return row


def plural(n, one, many=None):
    return "%d %s" % (n, one if n <= 1 else (many or one + "s"))


@page("dash", "Accueil", "▦")
class DashPage(Page):
    """Accueil (maquette « mix » 1) : pastilles (or, 24 h, courrier, envois, enchères) puis trois colonnes :
    or du compte + persos ; dernières 24 h par cause + À surveiller ; « En bref » (séance, addon, découvertes,
    sauvegarde, HV, vérification). Tiré du résumé que l'addon écrit à la déconnexion (WarbandKeeperDB.clientDash)."""

    RANGES = [(7, "7 j"), (30, "30 j"), (90, "90 j")]

    def __init__(self, app, parent):
        super().__init__(app, parent)
        self.body = tk.Frame(self, bg=C["bg"])
        self.body.pack(fill="both", expand=True)
        self.key = None

    def on_show(self):
        self.fill(True)

    def on_state(self):
        self.fill()

    def fill(self, force=False):
        # rien n'est lu ici : la sauvegarde (plusieurs Mo) est relue en arrière-plan quand elle a changé
        # (App.load_save), puis la page est remplie au retour ; en attendant, la lecture précédente reste
        dash, chars, fresh = save_state(self.app.addons)
        if not fresh:
            self.app.load_save()
        waiting = dash is None and not fresh
        a = self.app
        key = (id(dash), a.addons, a.cfg.get("dashRange", 30), id(a.dataLog), a.installed, a.latest_version, waiting,
               a.busy, str(a.cfg.get("learnedLast")), len(list_backups()), id(a.releases))
        if key == self.key and not force:
            return
        self.key = key
        for w in self.body.winfo_children():
            w.destroy()
        if waiting:
            self.set_pills(None)
            label(self.body, "Lecture de la sauvegarde de l'addon…", fg="muted").pack(anchor="w")
            return
        if not isinstance(dash, dict):
            self.set_pills(None)
            label(self.body, "Rien à montrer pour l'instant : joue un perso avec l'addon, puis déconnecte-toi "
                             "(ou /reload) ; l'accueil se remplit avec ce que l'addon sait.", fg="muted", wraplength=560).pack(anchor="w")
            return
        now = time.time()
        gold = [int(v or 0) for v in lua_list(dash.get("gold"))]
        sess = dash.get("session") or {}
        auc = [x for x in lua_list(dash.get("auctions")) if isinstance(x, dict) and (x.get("exp") or 0) > now]
        mail = [m for m in lua_list(dash.get("mail")) if isinstance(m, dict)]
        stash = [x for x in lua_list(dash.get("stash")) if isinstance(x, dict)]
        day = dash.get("day") if isinstance(dash.get("day"), dict) else None
        cur = gold[-1] if gold else 0
        if day is not None:
            net = int(day.get("net") or 0)
        else:
            net = (gold[-1] - gold[-2]) if len(gold) > 1 else 0
        letters = sum(int(m.get("count") or 0) for m in mail)
        self.set_pills([("OR", money_text(cur), "gold"), ("24 H", ("+" if net >= 0 else "-") + money_text(abs(net)),
                                                           "positive" if net >= 0 else "negative"),
                        ("COURRIER", str(letters), "warning" if letters else None),
                        ("ENVOIS", plural(len(stash), "lot") if stash else "0", "accent" if stash else None)])
        cols = tk.Frame(self.body, bg=C["bg"])
        cols.pack(fill="both", expand=True)
        for i, wgt in enumerate((5, 4, 3)):
            cols.columnconfigure(i, weight=wgt, uniform="c")
        cols.rowconfigure(0, weight=1)
        c1, c2, c3 = (tk.Frame(cols, bg=C["bg"]) for _ in range(3))
        c1.grid(row=0, column=0, sticky="nsew", padx=(0, 5))
        c2.grid(row=0, column=1, sticky="nsew", padx=5)
        c3.grid(row=0, column=2, sticky="nsew", padx=(5, 0))
        self.gold_card(c1, gold)
        self.chars_card(c1, chars, dash)
        self.day_card(c2, day, gold)
        self.watch_card(c2, dash, auc, mail, stash, now)
        self.brief_card(c3, dash, sess, auc)

    # -- or du compte : courbe 7 / 30 / 90 jours
    def gold_card(self, parent, gold):
        ch = Card(parent)
        ch.pack(fill="x")
        days = self.app.cfg.get("dashRange", 30)
        row, _ = card_title(ch.body, "Or du compte")
        for d, txt in reversed(self.RANGES):
            b = label(row, " %s " % txt, fg="text" if d == days else "muted", font="smallb" if d == days else "small",
                      cursor="hand2")
            b.pack(side="right", padx=1)
            b.bind("<Button-1>", lambda e, d=d: (self.app.cfg.__setitem__("dashRange", d), save_config(self.app.cfg), self.fill(True)))
        pts = gold[-(days + 1):] if gold else []
        top = tk.Frame(ch.body, bg=C["surface"])
        top.pack(fill="x")
        label(top, money_text(pts[-1] if pts else 0), fg="gold", font="h2").pack(side="left")
        if len(pts) > 1:
            dv = pts[-1] - pts[0]
            label(top, "  %s%s sur %d j" % ("+" if dv >= 0 else "-", money_text(abs(dv)), days),
                  fg="positive" if dv >= 0 else "negative", font="small").pack(side="left", pady=(4, 0))
        cv = tk.Canvas(ch.body, height=104, bg=C["surface"], highlightthickness=0)
        cv.pack(fill="x", pady=(4, 0))

        def draw(e, pts=pts, cv=cv):
            cv.delete("all")
            w, h = e.width, e.height
            if len(pts) < 2:
                cv.create_text(w / 2, h / 2, text="Pas encore assez de jours suivis.", fill=C["dim"], font=App.fonts["small"])
                return
            lo, hi = min(pts), max(pts)
            span = max(1, hi - lo)
            for f in (0.12, 0.9):
                cv.create_line(0, h * f, w, h * f, fill=C["border"], dash=(3, 4))
            cv.create_text(w - 2, h * 0.12 - 7, text=money_text(hi), fill=C["dim"], font=App.fonts["small"], anchor="e")
            xy = []
            for i, v in enumerate(pts):
                xy += [i * (w - 4) / (len(pts) - 1) + 2, h * 0.9 - (v - lo) / span * h * 0.78]
            cv.create_polygon(*(xy + [w - 2, h, 2, h]), fill="#2a2416", outline="")
            cv.create_line(*xy, fill=C["gold"], width=2, smooth=True)
        cv.bind("<Configure>", draw)

    # -- persos : niveau, or, repos, dernière connexion (grille : colonnes alignées)
    def chars_card(self, parent, chars, dash):
        pc = Card(parent)
        pc.pack(fill="both", expand=True, pady=(10, 0))
        card_title(pc.body, "Persos")
        rest = {r.get("char"): r for r in lua_list(dash.get("rest")) if isinstance(r, dict)}
        if not chars:
            label(pc.body, "Aucun perso lu.", fg="dim", font="small").pack(anchor="w")
            return
        grid = tk.Frame(pc.body, bg=C["surface"])
        grid.pack(fill="x")
        grid.columnconfigure(1, weight=1)
        f = App.fonts["small"]

        def cell(r, c, text, fg, anchor="e", **kw):
            w = tk.Label(grid, text=text, bg=C["surface"], fg=fg, font=f, anchor=anchor, **kw)
            w.grid(row=r, column=c, sticky="ew", padx=(0 if c < 2 else 8, 0), pady=3)
            return w
        for c, t in ((2, "NIV."), (3, "OR"), (4, "REPOS")):
            tk.Label(grid, text=t, bg=C["surface"], fg=C["dim"], font=App.fonts["smallb"], anchor="e").grid(
                row=0, column=c, sticky="ew", padx=(8, 0))
        for i, c in enumerate(chars[:6]):
            r = 2 * i + 2
            tk.Frame(grid, bg=C["border"], height=1).grid(row=r - 1, column=0, columnspan=5, sticky="ew")
            col = CLASS_COLORS.get(str(c.get("cls") or "").upper(), C["text"])
            dot = tk.Canvas(grid, width=8, height=8, bg=C["surface"], highlightthickness=0)
            dot.create_oval(1, 1, 7, 7, fill=col, outline="")
            dot.grid(row=r, column=0, padx=(0, 6))
            cell(r, 1, c.get("name") or "?", col, anchor="w")
            cell(r, 2, str(c.get("level") or "?"), C["muted"], width=3)
            cell(r, 3, money_text(int(c.get("money") or 0)), C["gold"], width=7)
            rr = rest.get(c.get("name"))
            if rr and rr.get("full"):
                rt, rc = "plein", C["positive"]
            elif rr and (rr.get("at") or 0) > time.time():
                rt, rc = "plein dans " + short_until(rr.get("at")), C["muted"]
            else:
                rt, rc = (ago_text(c.get("seen")) if c.get("seen") else ""), C["dim"]
            cell(r, 4, rt.replace("plein dans ", "dans "), rc, width=8)
        if len(chars) > 6:
            label(pc.body, "+ %d de plus" % (len(chars) - 6), fg="dim", font="small").pack(anchor="w", pady=(3, 0))

    # -- dernières 24 h par cause (journal de l'or de l'addon)
    def day_card(self, parent, day, gold):
        dc = Card(parent)
        dc.pack(fill="x")
        if day is None:
            g = (gold[-1] - gold[-2]) if len(gold) > 1 else 0
            card_title(dc.body, "Dernières 24 h", ("+" if g >= 0 else "-") + money_text(abs(g)), "positive" if g >= 0 else "negative")
            label(dc.body, "Or du compte d'hier à aujourd'hui (addon sans journal de l'or).", fg="dim", font="small",
                  wraplength=240).pack(anchor="w")
            return
        net = int(day.get("net") or 0)
        card_title(dc.body, "Dernières 24 h", ("+" if net >= 0 else "-") + money_text(abs(net)), "positive" if net >= 0 else "negative")
        by = [b for b in lua_list(day.get("by")) if isinstance(b, dict)][:5]
        if not by:
            label(dc.body, "Aucun mouvement d'or.", fg="dim", font="small").pack(anchor="w")
        mx = max([abs(int(b.get("v") or 0)) for b in by] or [1]) or 1
        for b in by:
            v = int(b.get("v") or 0)
            row = tk.Frame(dc.body, bg=C["surface"])
            row.pack(fill="x", pady=1)
            tk.Label(row, text=("+" if v >= 0 else "-") + money_text(abs(v)), bg=C["surface"],
                     fg=C["positive"] if v >= 0 else C["negative"], font=App.fonts["small"], width=9, anchor="e").pack(side="right")
            label(row, str(b.get("s") or "?"), font="small").pack(side="left")
            bar = tk.Canvas(dc.body, height=4, bg=C["surface"], highlightthickness=0)
            bar.pack(fill="x", pady=(0, 3))

            def draw(e, bar=bar, f=abs(v) / mx, col=C["positive"] if v >= 0 else C["negative"]):
                bar.delete("all")
                rounded(bar, 0, 0, e.width, 4, 2, fill=C["surface2"])
                if f > 0:
                    rounded(bar, 0, 0, max(4, e.width * f), 4, 2, fill=col)
            bar.bind("<Configure>", draw)

    # -- à surveiller, du plus urgent au moins urgent
    def watch_card(self, parent, dash, auc, mail, stash, now):
        wc = Card(parent)
        wc.pack(fill="both", expand=True, pady=(10, 0))
        card_title(wc.body, "À surveiller")
        rows = []  # (rang, couleur du point, texte, droite, couleur de droite)
        soon = [x for x in auc if (x.get("exp") or 0) <= now + 86400]
        for x in soon:
            rows.append((1, C["warning"], "Enchère : %s x%d" % (x.get("name"), x.get("qty") or 1), until_text(x.get("exp")), "warning"))
        pend = self.app.pending_data()
        if pend:
            rows.append((1, C["accent"], "Nouvelles données : %s" % data_text(*data_sum(pend)), "à installer", "accent"))
        for m in mail:
            left = (m.get("exp") or 0) - now
            urgent = 0 < left < 3 * 86400
            rows.append((0 if urgent else 3, C["negative"] if urgent else C["warning"],
                         "Courrier de %s (%d)" % (m.get("char"), int(m.get("count") or 0)),
                         ("expire " + short_until(m.get("exp"))) if left > 0 else "à prendre", "negative" if urgent else "warning"))
        for x in stash:
            rows.append((2, C["accent"], "Rangement : %s %s » %s" % (plural(int(x.get("n") or 0), "lot"),
                                                                    str(x.get("from") or "?").split(" ")[0],
                                                                    str(x.get("to") or "?").split(" ")[0]), "à envoyer", "accent"))
        cds = sorted([c for c in lua_list(dash.get("cds")) if isinstance(c, dict)], key=lambda c: c.get("readyAt") or 0)
        for c in cds[:3]:
            ready = (c.get("readyAt") or 0) <= now
            rows.append((2 if ready else 5, C["positive"] if ready else C["muted"], "%s · %s" % (c.get("name"), c.get("char")),
                         "prête" if ready else until_text(c.get("readyAt")), "positive" if ready else "muted"))
        for l in [l for l in lua_list(dash.get("lists")) if isinstance(l, dict)][:2]:
            short = int(l.get("short") or 0)
            if short:
                cost = int(l.get("cost") or 0)
                rows.append((6, C["muted"], "Liste « %s » : %s" % (l.get("name"), plural(short, "objet")),
                             ("manque " + money_text(cost)) if cost else "prix inconnu", "dim"))
        q = dash.get("queue") or {}
        if q.get("n"):
            rows.append((6, C["muted"], "File de fabrication : %s" % plural(int(q.get("n") or 0), "recette"),
                         plural(int(q.get("missing") or 0), "manquant"), "dim"))
        rows.sort(key=lambda r: r[0])
        if not rows:
            label(wc.body, "Rien d'urgent.", fg="dim", font="small").pack(anchor="w")
        for _, col, txt, right, rcol in rows[:7]:
            row = thin_row(wc.body)
            dot = tk.Canvas(row, width=8, height=8, bg=C["surface"], highlightthickness=0)
            dot.create_oval(1, 1, 7, 7, fill=col, outline="")
            dot.pack(side="left", padx=(0, 6))
            label(row, right, fg=rcol, font="small").pack(side="right", padx=(6, 0))
            label(row, txt, font="small").pack(side="left", fill="x", expand=True)
        if len(rows) > 7:
            label(wc.body, "+ %d de plus" % (len(rows) - 7), fg="dim", font="small").pack(anchor="w", pady=(3, 0))

    # -- en bref : une ligne par sujet, action au bout
    def brief_card(self, parent, dash, sess, auc):
        a = self.app
        bc = Card(parent)
        bc.pack(fill="both", expand=True)
        card_title(bc.body, "En bref")

        def item(title, value, sub="", vcol="text", action=None):
            tk.Frame(bc.body, bg=C["border"], height=1).pack(fill="x")
            box = tk.Frame(bc.body, bg=C["surface"])
            box.pack(fill="x", pady=4)
            label(box, title.upper(), fg="dim", font="smallb").pack(anchor="w")
            line = tk.Frame(box, bg=C["surface"])
            line.pack(anchor="w", fill="x")
            label(line, value, fg=vcol, font="bodyb").pack(side="left")
            if sub:
                label(line, "  " + sub, fg="muted", font="small").pack(side="left")
            # bouton sous la ligne (à droite, il mangeait le texte dans la colonne étroite)
            if action:
                Button(box, action[0], action[1], "primary", height=24, font=App.fonts["smallb"]).pack(anchor="w", pady=(4, 0))
        item("Sauvegarde du jeu", "lue " + ago_text(dash.get("at")), "", "muted")
        dur = int(sess.get("dur") or 0)
        item("Séance", str(sess.get("char") or dash.get("char") or "?"),
             "%s · %s%s" % (dur_text(dur), "+" if int(sess.get("gold") or 0) >= 0 else "-", money_text(abs(int(sess.get("gold") or 0)))))
        inst, latest = a.installed, a.latest_version
        if inst and latest and vtuple(latest) > vtuple(inst):
            item("Addon", latest, "disponible", "warning", ("Installer", a.update_addon) if not a.busy else None)
        else:
            item("Addon", inst or "non installé", "à jour" if inst else "", "positive" if inst else "muted")
        asset, ver = best_client(a.releases) if a.releases else (None, None)
        if asset and ver and vtuple(ver) > vtuple(CLIENT_VERSION):
            item("Client PC", ver, "disponible", "warning",
                 ("Installer", lambda: a.update_client(asset)) if (FROZEN and IS_WIN) else None)
        last = a.cfg.get("learnedLast") or {}
        if last.get("at"):
            item("Découvertes", plural(int(last.get("n") or 0), "ajout"),
                 "envoyés " + datetime.fromtimestamp(last["at"]).strftime("%d/%m %H:%M"), "positive")
        else:
            item("Découvertes", "envoi auto" if a.cfg.get("learnedAuto", True) else "envoi coupé", "rien envoyé pour l'instant", "muted")
        bk = list_backups()
        item("Sauvegarde", datetime.fromtimestamp(bk[0]["time"]).strftime("%d/%m %H:%M") if bk else "aucune",
             plural(len(bk), "gardée") if bk else "")
        item("HV", plural(len(auc), "enchère"), "en vente" if auc else "rien en vente")


class NotifyPanel:
    """Notifications Windows tirées du résumé de l'addon, vérifiées chaque minute tant que le client tourne
    (onglet « Notifications » des Réglages)."""

    ITEMS = [("auctions", "Enchères qui expirent", "moins de 24 h avant, une fois par jour, regroupées"),
             ("cds", "Recharges de métier prêtes", "transmutation, étoffe lunaire, sel raffiné…"),
             ("rest", "Repos plein", "un perso arrive à 150 % d'XP de repos"),
             ("mail", "Courrier qui va être renvoyé", "moins de 3 jours avant expiration"),
             ("data", "Nouvelles données", "la base de quêtes a été mise à jour (QuestieDB) : ce qui arrive"),
             ("quiet", "Heures calmes", "rien entre 23 h et 8 h (les notifications attendent le matin)")]

    def __init__(self, app, parent):
        self.app = app
        c = Card(parent, "Notifications Windows", "sans lancer le jeu")
        c.pack(fill="x")
        opts = app.cfg.setdefault("notify", dict(DEFAULTS["notify"]))
        self.vars = {}
        for key, text, sub in self.ITEMS:
            row = tk.Frame(c.body, bg=C["surface"])
            row.pack(fill="x", pady=3)
            v = tk.BooleanVar(value=bool(opts.get(key)))
            tk.Checkbutton(row, text="  " + text, variable=v, bg=C["surface"], fg=C["text"], selectcolor=C["surface2"],
                           activebackground=C["surface"], activeforeground=C["text"], bd=0, highlightthickness=0,
                           font=App.fonts["body"], anchor="w", command=lambda k=key, v=v: self.set(k, v.get())).pack(anchor="w")
            label(row, "      " + sub, fg="dim", font="small").pack(anchor="w")
            self.vars[key] = v
        label(c.body, "Le client doit tourner (réduit, ou lancé avec Windows : onglet Mises à jour). Les heures viennent de "
                      "la dernière sauvegarde de l'addon : une enchère vendue depuis ne sera connue qu'à la prochaine connexion.",
              fg="muted", font="small", wraplength=520).pack(anchor="w", pady=(8, 8))
        row = tk.Frame(c.body, bg=C["surface"])
        row.pack(fill="x")
        Button(row, "Tester une notification", self.test, "secondary", height=30).pack(side="left")
        self.info = label(row, "", fg="muted", font="small")
        self.info.pack(side="left", padx=(10, 0))

    def set(self, k, v):
        self.app.cfg.setdefault("notify", {})[k] = v
        save_config(self.app.cfg)

    def test(self):
        ok = notify_windows("Warband Keeper", "Les notifications fonctionnent.")
        self.info.configure(text="Envoyée." if ok else "Notifications Windows seulement (affichée ici).")
        if not ok:
            self.app.toast("Warband Keeper · Les notifications fonctionnent.", "positive")


@page("home", "Addon", "⟳")
class HomePage(Page):
    """Page Addon (maquette « mix » 3) : à gauche l'addon (version, état, mettre à jour / vérifier, choix du dossier,
    avancée de l'installation), le client PC, les sauvegardes et la version précédente ; à droite « Quoi de neuf »
    (notes de l'addon ou du client). Remplace les anciennes pages Mises à jour, Nouveautés et Sauvegardes."""

    def __init__(self, app, parent):
        super().__init__(app, parent)
        self.tab = "addon"
        body = tk.Frame(self, bg=C["bg"])
        body.pack(fill="both", expand=True)
        left = tk.Frame(body, bg=C["bg"], width=300)
        left.pack(side="left", fill="y")
        left.pack_propagate(False)
        # -- addon
        ac = Card(left)
        ac.pack(fill="x")
        b = ac.body
        card_title(b, "Warband Keeper", "pour WoW Forever")
        self.versions = label(b, "", font="h2")
        self.versions.pack(anchor="w")
        self.chip = Chip(b)
        self.chip.pack(anchor="w", pady=(4, 0))
        btns = tk.Frame(b, bg=C["surface"])
        btns.pack(fill="x", pady=(8, 0))
        self.action = Button(btns, "Mettre à jour", self.app.update_addon, "primary", height=30)
        self.action.pack(side="left")
        self.checkBtn = Button(btns, "Vérifier", self.app.refresh, "secondary", height=30)
        self.checkBtn.pack(side="left", padx=(6, 0))
        self.picker = tk.Frame(b, bg=C["surface"])
        self.progress = Progress(b)
        self.status = label(b, "", fg="muted", font="small", wraplength=250)
        self.status.pack(anchor="w", fill="x", pady=(6, 0))
        # -- client
        cc = Card(left)
        cc.pack(fill="x", pady=(8, 0))
        row, self.clientChip = card_title(cc.body, "Client PC", "", "positive")
        self.clientRow = tk.Frame(cc.body, bg=C["surface"])
        self.clientRow.pack(fill="x")
        # -- sauvegardes
        sc = Card(left)
        sc.pack(fill="x", pady=(8, 0))
        row, _ = card_title(sc.body, "Sauvegardes")
        link(row, "Sauvegarder", self.backup_now).pack(side="right")
        self.bkList = tk.Frame(sc.body, bg=C["surface"])
        self.bkList.pack(fill="x")
        # -- version précédente
        pv = Card(left)
        pv.pack(fill="x", pady=(8, 0))
        row, _ = card_title(pv.body, "Version précédente")
        self.prevLink = link(row, "Remettre", self.rollback)
        self.prevLink.pack(side="right")
        self.prev = label(pv.body, "", font="small", wraplength=250)
        self.prev.pack(anchor="w")
        # -- quoi de neuf
        nc = Card(body)
        nc.pack(side="left", fill="both", expand=True, padx=(10, 0))
        row, _ = card_title(nc.body, "Quoi de neuf")
        self.tabLinks = {}
        for key, txt in (("client", "Client PC"), ("addon", "Addon")):
            t = label(row, txt, fg="muted", font="small", cursor="hand2")
            t.pack(side="right", padx=(10, 0))
            t.bind("<Button-1>", lambda e, k=key: self.set_tab(k))
            self.tabLinks[key] = t
        wrap, self.txt = notes_view(nc.body, 20)
        wrap.pack(fill="both", expand=True)

    def set_tab(self, t):
        self.tab = t
        self.fill_notes()

    def fill_notes(self):
        for k, t in self.tabLinks.items():
            t.configure(fg=C["text"] if k == self.tab else C["muted"], font=App.fonts["smallb" if k == self.tab else "small"])
        if self.tab == "client":
            fill_notes(self.txt, parse_client_notes(self.app.clientNotes or bundled_client_notes()),
                       "Pas de notes du client pour l'instant.")
        else:
            fill_notes(self.txt, self.app.releases, "Aucune version trouvée pour l'instant (Vérifier).")

    def update_next(self):
        """Prochaine vérification (pastille de l'en-tête) : recalculée toutes les 20 s."""
        a = self.app
        every = {"1h": 3600, "6h": 6 * 3600}.get(a.cfg["checkEvery"])
        if not every:
            nxt = "à la main" if a.cfg["checkEvery"] == "manual" else "au démarrage"
        elif a.busy:
            nxt = "en cours"
        elif not a.lastCheck:
            nxt = "bientôt"
        else:
            nxt = datetime.fromtimestamp(a.lastCheck + every).strftime("%H:%M")
        inst, latest = a.installed, a.latest_version
        pills = [("INSTALLÉE", inst or "aucune", None)]
        if latest and inst and vtuple(latest) > vtuple(inst):
            pills.append(("DISPONIBLE", latest, "warning"))
        if a.lastCheck:
            pills.append(("VÉRIFIÉ", datetime.fromtimestamp(a.lastCheck).strftime("%H:%M"), None))
        pills.append(("PROCHAINE", nxt, "muted"))
        self.set_pills(pills)
        if getattr(self, "_nextJob", None):
            self.after_cancel(self._nextJob)
        self._nextJob = self.after(20000, self.update_next)

    def set_busy(self, text, value=None):
        if value is None:
            self.progress.pack_forget()
        else:
            if not self.progress.winfo_ismapped():
                self.progress.pack(fill="x", pady=(8, 0), before=self.status)
            self.progress.set(value)
        self.status.configure(text=text)

    def build_picker(self):
        a = self.app
        for w in self.picker.winfo_children():
            w.destroy()
        if a.addons:
            self.picker.pack_forget()
            return
        self.picker.pack(fill="x", pady=(8, 0), before=self.status)
        for inst in a.installs[:4]:
            row = tk.Frame(self.picker, bg=C["surface2"])
            row.pack(fill="x", pady=2)
            Button(row, "Ici", lambda i=inst: a.choose_install(i), "primary" if inst["forever"] else "secondary",
                   height=24).pack(side="right", padx=6, pady=4)
            label(row, inst["label"], fg="accent" if inst["forever"] else "text", font="smallb").pack(anchor="w", padx=8, pady=(4, 0))
            label(row, short_path(os.path.dirname(os.path.dirname(inst["addons"])), 30), fg="muted", font="small").pack(
                anchor="w", padx=8, pady=(0, 4))
        Button(self.picker, "Autre dossier…", a.browse_addons, "ghost", height=26).pack(anchor="w", pady=(4, 0))

    def on_state(self):
        a = self.app
        inst, latest = a.installed, a.latest_version
        self.build_picker()
        self.checkBtn.set(enabled=not a.busy)
        if not a.addons:
            n = len(a.installs)
            self.versions.configure(text="Où l'installer ?")
            self.chip.set(("%d installations trouvées" % n) if n > 1 else "WoW Forever introuvable", C["warning"])
            self.action.set("Rechercher", True, "secondary")
            self.action.command = a.rescan
        elif a.error and not latest:
            self.versions.configure(text=inst or "non installé")
            self.chip.set(a.error[:46] + ("…" if len(a.error) > 46 else ""), C["negative"])
            if "jeton" in a.error:
                self.action.set("Ajouter le jeton", True, "secondary")
                self.action.command = lambda: a.show_settings("github")
            else:
                self.action.set("Réessayer", True, "secondary")
                self.action.command = a.refresh
        elif latest is None:
            self.versions.configure(text=inst or "non installé")
            self.chip.set("Recherche des versions…", C["muted"])
            self.action.set("Vérification…", False, "secondary")
        elif not inst:
            self.versions.configure(text="Pas encore installé")
            self.chip.set("Prêt à installer · %s" % latest, C["accent"])
            self.action.set("Installer", not a.busy, "primary")
            self.action.command = a.update_addon
        # même version que la dernière Release seulement : sur une version plus récente (de développement),
        # « Réparer » aurait installé une version plus ancienne
        elif data_missing(a.addons, inst) and vtuple(inst) == vtuple(latest):
            self.versions.configure(text=inst)
            self.chip.set("Dossier des données manquant", C["warning"])
            self.action.set("Réparer", not a.busy, "alert")
            self.action.command = a.update_addon
        elif vtuple(inst) < vtuple(latest):
            self.versions.configure(text="%s  »  %s" % (inst, latest))
            n = len(a.newer())
            self.chip.set("%s de retard" % plural(n, "version"), C["warning"])
            self.action.set("Mettre à jour", not a.busy, "primary")
            self.action.command = a.update_addon
        else:
            self.versions.configure(text=inst)
            last = getattr(a, "lastInstall", None)
            # consigne seulement si le jeu tournait à l'installation et tourne encore
            live = last and last[0] == inst and last[1] is not None and game_running()
            if live and last[1]:
                self.chip.set("À jour · redémarre le jeu", C["warning"])
            elif live:
                self.chip.set("À jour · un /reload suffit", C["positive"])
            else:
                self.chip.set("À jour", C["positive"])
            self.action.set("À jour", False, "ok")
        # client PC
        for w in self.clientRow.winfo_children():
            w.destroy()
        asset, ver = best_client(a.releases) if a.releases else (None, None)
        if asset and ver and vtuple(ver) > vtuple(CLIENT_VERSION):
            self.clientChip.configure(text="%s disponible" % ver, fg=C["warning"])
            label(self.clientRow, CLIENT_VERSION, font="bodyb").pack(side="left")
            if FROZEN and IS_WIN:
                Button(self.clientRow, "Mettre à jour", lambda: a.update_client(asset), "primary", height=26).pack(side="right")
            else:
                label(self.clientRow, "sur GitHub, page Releases", fg="muted", font="small").pack(side="right")
        else:
            self.clientChip.configure(text="à jour", fg=C["positive"])
            label(self.clientRow, CLIENT_VERSION, font="bodyb").pack(side="left")
        # sauvegardes
        for w in self.bkList.winfo_children():
            w.destroy()
        items = list_backups()
        if not items:
            label(self.bkList, "Aucune pour l'instant.", fg="dim", font="small").pack(anchor="w")
        for bk in items[:4]:
            row = thin_row(self.bkList)
            link(row, "Restaurer", lambda bk=bk: self.restore(bk)).pack(side="right")
            label(row, datetime.fromtimestamp(bk["time"]).strftime("%d/%m %H:%M"), font="smallb").pack(side="left")
            parts = [x.strip() for x in bk["info"].split("·")] if bk["info"] else []
            desc = ("v" + parts[0].replace("Warband Keeper ", "") + " · " + parts[1]) if len(parts) >= 2 else ""
            label(row, "  " + desc[:26], fg="muted", font="small").pack(side="left")
        if len(items) > 4:
            label(self.bkList, "+ %d plus anciennes" % (len(items) - 4), fg="dim", font="small").pack(anchor="w")
        # version précédente
        prev = previous_versions()
        if prev:
            self.prev.configure(text="%s · gardée le %s" % (prev[0]["version"], datetime.fromtimestamp(prev[0]["time"]).strftime("%d/%m")))
            self.prevLink.configure(fg=C["accent"] if (a.addons and not a.busy) else C["dim"])
        else:
            self.prev.configure(text="Aucune : gardée à la prochaine mise à jour.")
            self.prevLink.configure(fg=C["dim"])
        self.fill_notes()
        self.update_next()

    # -- sauvegardes et retour en arrière (anciennes pages Sauvegardes)
    def backup_now(self):
        a = self.app
        if not a.addons:
            return a.toast("Choisis d'abord le dossier AddOns dans Réglages.", "warning")
        try:
            p = backup_saved_variables(a.addons, a.installed, a.cfg["keepBackups"], "manuelle")
        except Exception as e:  # disque plein, fichier bloqué… : toujours un message
            return a.toast("Sauvegarde impossible : %s" % e, "negative")
        a.toast("Réglages sauvegardés." if p else "Aucun fichier de réglages trouvé (lance le jeu une fois avec l'addon).",
                "positive" if p else "warning")
        a.state_changed()

    def restore(self, b):
        a = self.app
        if game_running():
            return a.toast("Ferme le jeu avant de restaurer (il réécrit ses réglages en quittant).", "warning")
        if not a.confirm("Restaurer la sauvegarde du %s ?\nTes réglages actuels sont d'abord sauvegardés." %
                         datetime.fromtimestamp(b["time"]).strftime("%d/%m/%Y %H:%M")):
            return
        if a.busy:
            return a.toast("Une installation est en cours : réessaie dans un instant.", "warning")
        a.busy = True
        a.state_changed()
        addons, inst, keep = a.addons, a.installed, a.cfg["keepBackups"] + 1

        # en arrière-plan (avant : la fenêtre se figeait pendant la décompression)
        def job():
            backup_saved_variables(addons, inst, keep, "avant restauration")
            restore_backup(addons, b["path"])

        def done(_res, err):
            a.busy = False
            if err:  # zip tronqué (zlib, EOFError), fichier bloqué… : toujours un message
                a.toast("Restauration impossible : %s (rien n'a été changé)." % err, "negative")
            else:
                a.toast("Sauvegarde restaurée.", "positive")
            a.state_changed()
        a.run(job, done)

    def rollback(self):
        a = self.app
        prev = previous_versions()
        if not (a.addons and prev):
            return
        # jamais pendant une installation (les mêmes dossiers seraient renommés et copiés en même temps)
        if a.busy:
            return a.toast("Une installation est en cours : réessaie dans un instant.", "warning")
        if not a.confirm("Remettre Warband Keeper %s ?" % prev[0]["version"]):
            return
        target = prev[0]
        a.busy = True
        a.state_changed()

        # en arrière-plan : la copie des grosses bases figeait la fenêtre (« Ne répond pas »)
        def job():
            return rollback(a.addons, target)

        def done(left, err):
            a.busy = False
            if err:
                a.toast("Impossible : %s" % err, "negative")
            else:
                # version quittée pas réinstallée d'office ; illisible : la dernière publiée tient lieu de repère
                skip = left if (left and vtuple(left) > (0,)) else a.latest_version
                if skip:
                    a.cfg["skipVersion"] = skip
                    save_config(a.cfg)
                a.toast("Version %s remise. Redémarre le jeu." % target["version"], "positive")
            a.state_changed()
        a.run(job, done)


# --- Découvertes : ce que l'addon a appris en jeu, intégré à l'addon pour tout le monde (client/learned.py) ---
def learned_dir():
    d = os.path.join(data_dir(), "decouvertes")
    os.makedirs(d, exist_ok=True)
    return d


def learned_files():
    """Fichiers .wkd importés (copiés dans le dossier du client) : [(chemin, src, data)] ; illisibles ignorés."""
    out = []
    for name in sorted(os.listdir(learned_dir())):
        if name.lower().endswith(".wkd"):
            p = os.path.join(learned_dir(), name)
            try:
                with open(p, encoding="utf-8") as f:
                    src, data = learned.read_wkd(f.read())
                out.append((p, src, data))
            except (OSError, ValueError):
                pass
    return out


# --- Découvertes sur le réseau local -----------------------------------------------------------------------
# Un joueur sans jeton (même réseau que le mainteneur) n'a rien à faire : son client cherche, par une annonce UDP
# sur le réseau local, le client du mainteneur (jeton qui écrit sur le dépôt) et lui passe ses découvertes
# nouvelles (format .wkd) en TCP ; le mainteneur les garde dans decouvertes/lan-<src>.wkd (source sûre) et les
# envoie sur GitHub avec les siennes. Adresses privées seulement, 8 Mo au plus, contenu vérifié (read_wkd).
LAN_PORT = 47811
LAN_ASK, LAN_ANS = b"WKLEARN?1", b"WKLEARN!1 "
LAN_MAX = 8 * 1024 * 1024


def _lan_private(ip):
    import ipaddress
    try:
        a = ipaddress.ip_address(ip)
        return a.is_private or a.is_loopback
    except ValueError:
        return False


def lan_targets():
    """Adresses d'annonce : diffusion générale et celle du sous-réseau de ce PC (réseau /24 supposé)."""
    out = ["255.255.255.255"]
    import socket
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("10.255.255.255", 1))  # aucun paquet envoyé : sert à connaître l'adresse locale
        ip = s.getsockname()[0]
        s.close()
        if _lan_private(ip) and ip.count(".") == 3:
            out.append(ip.rsplit(".", 1)[0] + ".255")
    except OSError:
        pass
    return out


def lan_find(targets=None, timeout=2.0, port=LAN_PORT):
    """Cherche le client du mainteneur sur le réseau local : (adresse, port TCP) ou None."""
    import socket
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        s.settimeout(timeout)
        for t in targets or lan_targets():
            try:
                s.sendto(LAN_ASK, (t, port))
            except OSError:
                pass
        end = time.time() + timeout
        while time.time() < end:
            try:
                data, addr = s.recvfrom(256)
            except (socket.timeout, OSError):
                return None
            if data.startswith(LAN_ANS) and _lan_private(addr[0]):
                try:
                    return addr[0], int(data[len(LAN_ANS):].strip())
                except ValueError:
                    pass
        return None
    finally:
        s.close()


def lan_send(text, targets=None, port=LAN_PORT):
    """Passe un .wkd au client du mainteneur ; vrai s'il l'a gardé."""
    import socket
    where = lan_find(targets, port=port)
    if not where:
        return False
    raw = text.encode("utf-8")
    with socket.create_connection(where, timeout=10) as c:
        c.sendall(len(raw).to_bytes(8, "big") + raw)
        return c.recv(2) == b"OK"


def lan_store(text):
    """Mainteneur : garde un .wkd reçu (fusionné avec ce que ce joueur a déjà passé) ; rend (src, nombre)."""
    src, data = learned.read_wkd(text)
    safe = re.sub(r"[^A-Za-z0-9_-]", "", src)[:40] or "inconnu"
    path = os.path.join(learned_dir(), "lan-%s.wkd" % safe)
    old = {}
    try:
        with open(path, encoding="utf-8") as f:
            old = learned.read_wkd(f.read())[1]
    except (OSError, ValueError):
        pass
    n = 0
    for g, part in data.items():
        if part:
            old.setdefault(g, {}).update(part)
            n += len(part)
    with open(path, "w", encoding="utf-8") as f:
        f.write(learned.export_wkd(old, src))
    return src, n


class LanCollector:
    """Client du mainteneur : répond aux annonces du réseau local et reçoit les découvertes (fil à part)."""

    def __init__(self, on_received, port=LAN_PORT):
        import socket
        self.on_received = on_received
        self.udp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.udp.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.udp.bind(("", port))
        self.tcp = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.tcp.bind(("", 0))
        self.tcp.listen(4)
        self.tport = self.tcp.getsockname()[1]
        threading.Thread(target=self.answer, daemon=True).start()
        threading.Thread(target=self.accept, daemon=True).start()

    def answer(self):
        while True:
            try:
                data, addr = self.udp.recvfrom(256)
            except OSError:
                return
            if data.startswith(LAN_ASK) and _lan_private(addr[0]):
                try:
                    self.udp.sendto(LAN_ANS + str(self.tport).encode(), addr)
                except OSError:
                    pass

    def accept(self):
        while True:
            try:
                c, addr = self.tcp.accept()
            except OSError:
                return
            threading.Thread(target=self.receive, args=(c, addr), daemon=True).start()

    def receive(self, c, addr):
        with c:
            try:
                c.settimeout(15)
                if not _lan_private(addr[0]):
                    return
                head = b""
                while len(head) < 8:
                    part = c.recv(8 - len(head))
                    if not part:
                        return
                    head += part
                size = int.from_bytes(head, "big")
                if size <= 0 or size > LAN_MAX:
                    return c.sendall(b"NO")
                buf = bytearray()
                while len(buf) < size:
                    part = c.recv(min(65536, size - len(buf)))
                    if not part:
                        return
                    buf += part
                src, n = lan_store(buf.decode("utf-8"))
                c.sendall(b"OK")
                self.on_received(src, n)
            except (OSError, ValueError, UnicodeDecodeError):
                try:
                    c.sendall(b"NO")
                except OSError:
                    pass

    def close(self):
        for s in (self.udp, self.tcp):
            try:
                s.close()
            except OSError:
                pass


_learn_cache = {}
_learn_lock = threading.Lock()


def read_learned(addons):
    """Ce que ta sauvegarde a appris ({ genre: { clé: valeur } }), lu une fois par version du fichier.
    Lecture bloquante (le fichier fait plusieurs Mo) : jamais sur le thread Tk. Une lecture à la fois (deux
    threads lisaient le même fichier en même temps et se croisaient dans le cache)."""
    with _learn_lock:
        path, mt = _save_file(addons)
        if path is None:
            return None
        if _learn_cache.get("path") == path and _learn_cache.get("mt") == mt:
            return _learn_cache["data"]
        with open(path, encoding="utf-8", errors="replace") as f:
            data = learned.extract(learned.read_save(f.read()))
        _learn_cache.update(path=path, mt=mt, data=data)
        return data


def installed_learned(addons):
    """Base des découvertes de l'addon installé (Modules/LearnedDB.lua), ou {}."""
    p = os.path.join(addons or "", "WarbandKeeper", "Modules", "LearnedDB.lua")
    try:
        with open(p, encoding="utf-8") as f:
            return learned.from_lua(f.read())
    except OSError:
        return {}


def learned_sources(mine, cfg):
    """Sources des découvertes : ce PC (sûr) puis les fichiers .wkd importés (sauf ceux de ce PC)."""
    out = []
    if mine:
        out.append({"name": "Ce PC", "trusted": True, "data": mine})
    me = cfg.get("learnedSrc")
    for p, src, data in learned_files():
        if src != me:
            # reçu d'un PC du réseau local (même maison) : source sûre comme ce PC
            out.append({"name": src, "trusted": os.path.basename(p).startswith("lan-"), "data": data})
    return out


def learned_choices(cfg):
    out = {}
    for k, v in (cfg.get("learnedChoices") or {}).items():
        g, _, key = k.partition("|")
        out[(g, key)] = v
    return out


def sent_learned():
    """Dernière base envoyée sur GitHub par ce client (pas encore dans l'addon installé avant la version suivante)."""
    try:
        with open(os.path.join(learned_dir(), "envoye.json"), encoding="utf-8") as f:
            return learned.from_json(f.read())
    except OSError:
        return {}


def save_sent_learned(base):
    try:
        with open(os.path.join(learned_dir(), "envoye.json"), "w", encoding="utf-8") as f:
            f.write(learned.to_json(base))
    except OSError:
        pass


def known_learned(addons):
    """Ce qui est déjà connu : l'addon installé, plus ce que ce client a déjà envoyé."""
    base = installed_learned(addons)
    for g, part in sent_learned().items():
        base.setdefault(g, {}).update(part)
    return base


@page("learned", "Découvertes", "✚")
class LearnedPage(Page):
    """Maquette « mix » : en-tête (importer, relire), trois chiffres, genres à gauche, détail filtré à droite,
    envoi en PR en bas. Ton PC est une source sûre ; les fichiers d'autres joueurs (.wkd) ont besoin d'une 2e
    confirmation pour les quêtes, chaînes et boss ; deux valeurs différentes = à vérifier (clic sur la ligne)."""
    MAX_ROWS = 150

    def __init__(self, app, parent):
        super().__init__(app, parent)
        self.mine, self.base, self.rows, self.loading = None, {}, [], False
        self.genre, self.status = None, "all"
        self.choices = {}


        body = tk.Frame(self, bg=C["bg"])
        body.pack(fill="both", expand=True)
        left = Card(body, "Genres")
        left.configure(width=205)
        left.pack_propagate(False)
        left.pack(side="left", fill="y")
        self.genres = tk.Frame(left.body, bg=C["surface"], width=200)
        self.genres.pack(fill="both", expand=True)
        right = Card(body)
        right.pack(side="left", fill="both", expand=True, padx=(10, 0))
        seg = tk.Frame(right.body, bg=C["surface"])
        seg.pack(anchor="w", pady=(0, 6))
        self.segBtns = {}
        for v, t in (("all", "Toutes"), ("integrated", "Intégrées"), ("pending", "En attente"), ("check", "À vérifier"),
                     ("rejected", "Rejetées")):
            b = Button(seg, t, lambda v=v: self.set_status(v), "ghost", height=26, font=App.fonts["small"])
            b.pack(side="left", padx=(0, 3))
            self.segBtns[v] = b
        head = tk.Frame(right.body, bg=C["surface"])
        head.pack(fill="x")
        # marge à droite = ce que la liste perd à droite (4 px, plus la barre de défilement quand elle est là)
        self.headPad = tk.Frame(head, bg=C["surface"], width=4, height=1)
        self.headPad.pack(side="right")
        self.cells(head, [(t, "dim", "smallb") for t, _ in self.COLW])
        label(head, "DÉTAIL", fg="dim", font="smallb").pack(side="left")
        self.note = label(right.body, "", fg="muted", font="small", wraplength=480)
        self.note.pack(side="bottom", anchor="w", pady=(6, 0))
        self.list = ScrollArea(right.body)
        self.list.configure(bg=C["surface"])
        self.list.cv.configure(bg=C["surface"])
        self.list.inner.configure(bg=C["surface"])
        self.list.pack(fill="both", expand=True)
        sb = self.list.sb
        for ev in ("<Map>", "<Unmap>"):
            sb.bind(ev, lambda e: self.headPad.configure(width=4 + (sb.winfo_reqwidth() if sb.winfo_ismapped() else 0)),
                    add="+")

        bot = tk.Frame(self, bg=C["bg"])
        bot.pack(fill="x", pady=(10, 0))
        self.prBtn = Button(bot, "Envoyer", self.send_pr, "primary", height=32)
        self.prBtn.pack(side="right")
        self.autoBtn = Button(bot, "Envoi auto : oui", self.toggle_auto, "secondary", height=32)
        self.autoBtn.pack(side="left")
        self.clearBtn = Button(bot, "Retirer les importés", self.clear_files, "ghost", height=32)
        self.clearBtn.pack(side="right", padx=(0, 6))
        self.exportBtn = Button(bot, "Exporter", self.export, "ghost", height=32)
        self.exportBtn.pack(side="right", padx=(0, 6))
        Button(bot, "Importer…", self.import_file, "ghost", height=32).pack(side="right", padx=(0, 6))
        Button(bot, "Relire", self.reload, "ghost", height=32).pack(side="right", padx=(0, 6))
        Button(bot, "Joueurs de confiance…", self.edit_friends, "ghost", height=32).pack(side="left", padx=(6, 0))

    # -- données
    def sources(self):
        return learned_sources(self.mine, self.app.cfg)

    def compute(self):
        self.choices = learned_choices(self.app.cfg)
        ch = self.choices
        self.rows = learned.merge(self.sources(), self.base, ch)

    def reload(self, force=True):
        a = self.app
        if self.loading:
            return
        if not a.addons:
            self.note.configure(text="Choisis d'abord le dossier AddOns dans Réglages.")
            return
        if force:
            with _learn_lock:
                _learn_cache.clear()
        self.loading = True
        self.note.configure(text="Lecture de ta sauvegarde…")
        addons = a.addons

        def done(res, err):
            self.loading = False
            if err:
                self.note.configure(text="Sauvegarde illisible : %s" % err)
                return
            self.mine, self.base = res
            # pas encore de sauvegarde (jeu jamais lancé avec l'addon) : liste vide au lieu de « Lecture… » sans fin
            if self.mine is None:
                self.mine = {}
                self.note.configure(text="Pas encore de sauvegarde : lance le jeu une fois avec l'addon.")
            self.fill()
        a.run(lambda: (read_learned(addons), known_learned(addons)), done)

    def on_show(self):
        self.reload(force=False)

    # -- affichage
    def set_status(self, s):
        self.status = s
        self.fill()

    def set_genre(self, g):
        self.genre = None if self.genre == g else g
        self.fill()

    def fill(self):
        self.compute()
        rows = self.rows
        n = {}
        for r in rows:
            n[r["status"]] = n.get(r["status"], 0) + 1
        new = n.get(learned.INTEGRATED, 0)
        src = self.sources()
        look = n.get(learned.CHECK, 0) + n.get(learned.REJECTED, 0) + n.get(learned.PENDING, 0)
        last = self.app.cfg.get("learnedLast") or {}
        pills = [("NOUVEAU", str(new), "positive" if new else None), ("CONNUES", str(n.get(learned.KNOWN, 0)), None)]
        if len(src) > 1:  # seulement s'il y a des fichiers d'autres joueurs (« ce PC » seul n'apprend rien)
            pills.append(("SOURCES", "ce PC + %d" % (len(src) - 1), None))
        # déjà dans l'addon et venu d'ailleurs (autres joueurs) : la liste ne montre que tes sources
        others = self.others_count()
        if others:
            pills.append(("AUTRES JOUEURS", str(others), "accent"))
        if look:
            pills.append(("À REGARDER", str(look), "warning"))
        if last.get("at"):
            when = datetime.fromtimestamp(last["at"])
            pills.append(("ENVOYÉ", when.strftime("%H:%M" if when.date() == datetime.now().date() else "%d/%m"), "positive"))
        self.set_pills(pills)
        # genres : nombre noté sur le PC, nouveautés en vert ; clic = filtre
        for w in self.genres.winfo_children():
            w.destroy()
        mine = self.mine or {}
        for g, title, _ in learned.GENRES:
            k = sum(1 for r in rows if r["genre"] == g and r["status"] == learned.INTEGRATED)
            have = len(mine.get(g) or {})
            if not have and not k:
                continue
            sel = self.genre == g
            row = tk.Frame(self.genres, bg=C["surface2"] if sel else C["surface"], cursor="hand2")
            row.pack(fill="x", pady=1)
            b = label(row, ("+%d  " % k if k else "") + str(have), fg="positive" if k else "dim", font="smallb")
            b.pack(side="right", padx=6)
            a = label(row, title, fg="text" if sel else "muted", font="small")
            a.pack(side="left", padx=6, pady=1)
            for w in (row, a, b):
                w.bind("<Button-1>", lambda e, g=g: self.set_genre(g))
        if not self.genres.winfo_children():
            label(self.genres, "Rien d'appris pour l'instant." if self.mine is not None else "Lecture…",
                  fg="dim", font="small").pack(anchor="w")
        for v, b in self.segBtns.items():
            b.set(style="primary" if v == self.status else "ghost")
        # détail
        for w in self.list.inner.winfo_children():
            w.destroy()
        want = None if self.status == "all" else (self.status,)
        shown = [r for r in rows if (not self.genre or r["genre"] == self.genre)
                 and (want is None or r["status"] in want) and (want is not None or r["status"] != learned.KNOWN)]
        for r in shown[:self.MAX_ROWS]:
            self.add_row(r)
        if len(shown) > self.MAX_ROWS:
            label(self.list.inner, "… et %d autres (choisis un genre à gauche)" % (len(shown) - self.MAX_ROWS),
                  fg="dim", font="small").pack(anchor="w", pady=4)
        if not shown:
            last = self.app.cfg.get("learnedLast") or {}
            if self.mine is None:
                label(self.list.inner, "Lecture de ta sauvegarde…", fg="dim", font="small").pack(anchor="w", pady=6)
            elif self.status == "all" and last.get("at"):
                # rien de nouveau : ce que contenait le dernier envoi (avant, « Rien ici » faisait croire à une perte)
                label(self.list.inner, "Rien de nouveau depuis le dernier envoi (%s, %s) :" % (
                    datetime.fromtimestamp(last["at"]).strftime("%d/%m %H:%M"), plural(int(last.get("n") or 0), "ajout")),
                    fg="muted", font="small").pack(anchor="w", pady=(2, 4))
                items = last.get("items") or []
                # sources retrouvées dans les découvertes du moment (même texte) : un envoi d'avant la 1.9.23 n'a
                # gardé que le texte, et ces lignes sont toujours dans ta sauvegarde (statut « connue »)
                bytext = {}
                for r in self.rows or []:
                    try:
                        bytext.setdefault(learned.short(r["genre"], r["key"], r["value"]), r)
                    except Exception:
                        pass
                for it in items[:self.MAX_ROWS]:
                    if isinstance(it, dict):
                        t, srcs, conf = it.get("t") or "", ", ".join(it.get("s") or []), str(it.get("c") or "")
                    else:
                        t, srcs, conf = str(it), "", ""
                    if not srcs and t in bytext:
                        r = bytext[t]
                        srcs = ", ".join(r.get("srcs") or [])
                        conf = str(r.get("confirm") or len(r.get("srcs") or []) or "")
                    row = tk.Frame(self.list.inner, bg=C["surface"])
                    row.pack(fill="x", pady=1)
                    self.cells(row, [("envoyée", "positive", "small"), (conf or "–", "muted" if conf else "dim", "small"),
                                     ((srcs if len(srcs) < 13 else srcs[:12] + "…") or "–", "dim", "small")])
                    label(row, t if len(t) < 47 else t[:46] + "…", font="small").pack(side="left", fill="x", expand=True)
                if not items:
                    label(self.list.inner, "(détail gardé à partir du prochain envoi)", fg="dim", font="small").pack(anchor="w")
            else:
                label(self.list.inner, "Rien ici.", fg="dim", font="small").pack(anchor="w", pady=6)
        can = bool(new)
        self.prBtn.set(text="Envoyer (%d)" % new if new else "Envoyer", enabled=can)
        files = len(learned_files())
        self.clearBtn.set(enabled=bool(files))
        if files:
            self.clearBtn.pack(side="right", padx=(0, 6), before=self.exportBtn)
        else:
            self.clearBtn.pack_forget()
        if not self.loading:
            cfg = self.app.cfg
            last = cfg.get("learnedLast") or {}
            when = (" Dernier envoi : %s, %s." % (datetime.fromtimestamp(last["at"]).strftime("%d/%m %H:%M"),
                                                  plural(last.get("n", 0), "ajout"))) if last.get("at") else ""
            others = self.others_count()
            otxt = (" L'addon contient aussi %s d'autres joueurs (pas listées ici : seulement tes sources)."
                    % plural(others, "découverte")) if others else ""
            if not cfg.get("token"):
                txt = ("Envoi automatique : tes découvertes passent toutes seules au PC du mainteneur sur ton réseau"
                       " local (son client ouvert), qui les envoie sur GitHub." + when + otxt)
            elif cfg.get("learnedMode") == "pr":
                txt = ("Envoi automatique : tes découvertes partent en demande de fusion vers le mainteneur et arrivent"
                       " dans l'addon une fois acceptées." + when + otxt)
            elif cfg.get("learnedAuto", True):
                txt = ("Envoi automatique : ce qui est nouveau part sur GitHub quand tu quittes le jeu, et arrive dans"
                       " l'addon à la version suivante." + when + otxt)
            else:
                txt = ("Rien de nouveau." if not new else "Envoi automatique coupé : « Envoyer » pour l'envoyer.") + when
            self.note.configure(text=txt)
        self.autoBtn.set(text="Envoi auto : %s" % ("oui" if self.app.cfg.get("learnedAuto", True) else "non"))

    # colonnes de droite, de droite à gauche : largeurs en pixels communes aux titres et aux lignes
    COLW = (("DÉCISION", 104), ("CONF.", 48), ("SOURCES", 92))

    def cells(self, row, vals):
        """Cases de largeur fixe à droite de row (titres et lignes alignés) ; vals = [(texte, couleur, police)]."""
        out = []
        for (_, w), (text, fg, font) in zip(self.COLW, vals):
            f = tk.Frame(row, bg=row["bg"], width=w, height=20)
            f.pack_propagate(False)
            f.pack(side="right")
            lab = label(f, text, fg=fg, font=font)
            lab.pack(side="left", fill="y")
            out.append(lab)
        return out

    def others_count(self):
        """Découvertes déjà dans l'addon (ou envoyées) qui ne viennent pas de ce PC : celles des autres joueurs."""
        base, mine = self.base or {}, self.mine or {}
        return sum(len(set((base.get(g) or {})) - set((mine.get(g) or {}))) for g, _, _ in learned.GENRES)

    def edit_friends(self):
        """Mainteneur : comptes GitHub dont les propositions de découvertes sont fusionnées toutes seules."""
        from tkinter import simpledialog
        cfg = self.app.cfg
        cur = ", ".join(cfg.get("learnedFriends") or [])
        v = simpledialog.askstring("Joueurs de confiance",
                                   "Comptes GitHub dont les découvertes proposées sont acceptées toutes seules\n"
                                   "(séparés par des virgules ; vide = tu les acceptes toi-même sur GitHub) :",
                                   initialvalue=cur, parent=self)
        if v is None:
            return
        cfg["learnedFriends"] = [x.strip() for x in v.replace(";", ",").split(",") if x.strip()]
        save_config(cfg)
        self.app.toast("Joueurs de confiance : %s." % (", ".join(cfg["learnedFriends"]) or "aucun"), "muted")

    COLORS = {learned.INTEGRATED: "positive", learned.PENDING: "muted", learned.CHECK: "warning",
              learned.REJECTED: "negative", learned.KNOWN: "dim"}

    def add_row(self, r):
        row = tk.Frame(self.list.inner, bg=C["surface"])
        row.pack(fill="x", pady=1)
        st = r["status"]
        dec = {learned.PENDING: "en attente ▸", learned.CHECK: "à vérifier ▸"}.get(st, learned.STATUS_LABEL[st])
        srcs = ", ".join(r["srcs"])
        c = self.cells(row, [(dec, self.COLORS[st], "small"), (str(r.get("confirm") or len(r["srcs"])), "muted", "small"),
                             (srcs if len(srcs) < 13 else srcs[:12] + "…", "dim", "small")])[0]
        v = r["value"] if r["value"] is not None else (r["values"][0] if r["values"] else {})
        try:
            text = learned.short(r["genre"], r["key"], v)
        except Exception:
            text = "%s %s" % (r["genre"], r["key"])
        if r.get("reason") and st != learned.PENDING:
            text += " · " + r["reason"]
        d = label(row, text if len(text) < 47 else text[:46] + "…", font="small")
        d.pack(side="left", fill="x", expand=True)
        if st in (learned.CHECK, learned.PENDING):
            for w in (row, c, d):
                w.configure(cursor="hand2")
                w.bind("<Button-1>", lambda e, r=r: self.decide(r, e))

    def decide(self, r, e):
        """Clic sur une ligne à vérifier : choisir la valeur ; en attente : l'intégrer quand même."""
        m = tk.Menu(self, tearoff=0, bg=C["surface2"], fg=C["text"], activebackground=C["accent"], bd=0)
        key = "%s|%s" % (r["genre"], r["key"])

        def pick(i):
            ch = dict(self.app.cfg.get("learnedChoices") or {})
            if i is None:
                ch.pop(key, None)
            elif r["status"] == learned.CHECK:
                ch[key] = {"v": r["values"][i]}  # la valeur, pas sa position dans la liste
            else:
                ch[key] = i
            self.app.cfg["learnedChoices"] = ch
            save_config(self.app.cfg)
            self.fill()
        if r["status"] == learned.CHECK:
            for i, v in enumerate(r["values"]):
                t = json.dumps(v, ensure_ascii=False)
                m.add_command(label="Garder : " + (t if len(t) < 70 else t[:69] + "…"), command=lambda i=i: pick(i))
        else:
            m.add_command(label="Intégrer quand même (1 seule confirmation)", command=lambda: pick(0))
        if key in (self.app.cfg.get("learnedChoices") or {}):
            m.add_command(label="Annuler mon choix", command=lambda: pick(None))
        m.tk_popup(e.x_root, e.y_root)

    # -- fichiers
    def import_file(self):
        paths = filedialog.askopenfilenames(title="Découvertes d'un autre joueur",
                                            filetypes=[("Découvertes Warband Keeper", "*.wkd"), ("Tous", "*.*")])
        ok, bad = 0, 0
        for p in paths or ():
            try:
                with open(p, encoding="utf-8") as f:
                    learned.read_wkd(f.read())
                shutil.copy2(p, os.path.join(learned_dir(), os.path.basename(p)))
                ok += 1
            except (OSError, ValueError):
                bad += 1
        if ok or bad:
            self.app.toast("%s importé%s%s" % (plural(ok, "fichier"), "s" if ok > 1 else "",
                                               (", %d illisible%s" % (bad, "s" if bad > 1 else "")) if bad else ""),
                           "positive" if ok else "negative")
            self.fill()

    def clear_files(self):
        files = learned_files()
        if not files or not self.app.confirm("Retirer les %s importés ?" % plural(len(files), "fichier")):
            return
        for p, _, _ in files:
            try:
                os.remove(p)
            except OSError:
                pass
        self.fill()

    def export(self):
        if not self.mine:
            return self.app.toast("Rien à exporter : ta sauvegarde n'est pas encore lue.", "warning")
        cfg = self.app.cfg
        if not cfg.get("learnedSrc"):
            import secrets
            cfg["learnedSrc"] = "wk-" + secrets.token_hex(4)
            save_config(cfg)
        docs = os.path.join(os.path.expanduser("~"), "Documents")
        p = filedialog.asksaveasfilename(title="Exporter mes découvertes", defaultextension=".wkd",
                                         initialdir=docs if os.path.isdir(docs) else None,
                                         initialfile="WarbandKeeper-decouvertes-%s.wkd" % datetime.now().strftime("%Y%m%d"),
                                         filetypes=[("Découvertes Warband Keeper", "*.wkd")])
        if not p:
            return
        try:
            with open(p, "w", encoding="utf-8") as f:
                f.write(learned.export_wkd(self.mine, cfg["learnedSrc"]))
        except OSError as e:
            return self.app.toast("Export impossible : %s" % e, "negative")
        self.app.toast("Découvertes exportées (rien de personnel : ni persos, ni or, ni sacs).", "positive")

    # -- envoi
    def toggle_auto(self):
        cfg = self.app.cfg
        cfg["learnedAuto"] = not cfg.get("learnedAuto", True)
        save_config(cfg)
        self.fill()
        if cfg["learnedAuto"]:
            self.app.auto_learned(force=True)

    def send_pr(self):
        """« Envoyer » : tout de suite, comme l'envoi automatique (sur main, sans demande de fusion)."""
        a = self.app
        self.prBtn.set(enabled=False)
        self.note.configure(text="Envoi sur GitHub…")
        a.auto_learned(force=True, manual=True)


@page("settings", "Réglages", "⚙")
class SettingsPage(Page):
    def __init__(self, app, parent):
        super().__init__(app, parent)
        cfg = app.cfg
        # un onglet par catégorie (le dernier ouvert est retenu)
        TABS = [("folder", "Dossier"), ("github", "GitHub"), ("updates", "Mises à jour"), ("notify", "Notifications"), ("data", "Données")]
        self.tabFrames = {}
        holder = tk.Frame(self, bg=C["bg"])
        self.tabBar = Segmented(self, TABS, lambda: self.app.cfg.get("settingsTab", "folder"), self.set_tab)
        self.tabBar.pack(anchor="w", pady=(0, 12))
        holder.pack(fill="both", expand=True)
        for key, _ in TABS:
            self.tabFrames[key] = tk.Frame(holder, bg=C["bg"])
        tab = self.tabFrames
        g = Card(tab["folder"], "Dossier de l'addon", "Interface\\AddOns de WoW Forever")
        g.pack(fill="x")
        row = tk.Frame(g.body, bg=C["surface"])
        row.pack(fill="x")
        self.path = tk.StringVar(value=cfg["addons"])
        e = tk.Entry(row, textvariable=self.path, bg=C["surface2"], fg=C["text"], insertbackground=C["text"], bd=0,
                     highlightthickness=1, highlightbackground=C["border"], highlightcolor=C["accent"], font=App.fonts["body"])
        e.pack(side="left", fill="x", expand=True, ipady=7, padx=(0, 8))
        e.bind("<FocusOut>", lambda _: self.apply_path(self.path.get()))
        Button(row, "Parcourir", self.browse, "secondary", height=34).pack(side="left")
        Button(row, "Détecter", self.detect, "ghost", height=34).pack(side="left", padx=(6, 0))
        self.pathInfo = label(g.body, "", fg="muted", font="small")
        self.pathInfo.pack(anchor="w", pady=(8, 0))

        t = Card(tab["github"], "Accès à GitHub", "dépôt public : jeton facultatif")
        t.pack(fill="x")
        label(t.body, "Installer l'addon : aucun jeton. Proposer tes découvertes (autre joueur) : jeton « classique »"
                      " de ton compte GitHub avec le droit « public_repo » (bouton « Jeton pour proposer »).\n"
                      "Mainteneur (régler les données, envoyer directement) : jeton fine-grained du dépôt, Contents et"
                      " Actions « Read and write ». Gardé seulement sur ce PC.",
              fg="muted", font="small", wraplength=700).pack(anchor="w")
        row2 = tk.Frame(t.body, bg=C["surface"])
        row2.pack(fill="x", pady=(8, 0))
        self.token = tk.StringVar(value=cfg["token"])
        te = tk.Entry(row2, textvariable=self.token, show="•", bg=C["surface2"], fg=C["text"], insertbackground=C["text"], bd=0,
                      highlightthickness=1, highlightbackground=C["border"], highlightcolor=C["accent"], font=App.fonts["body"])
        te.pack(side="left", fill="x", expand=True, ipady=7, padx=(0, 8))
        Button(row2, "Enregistrer", self.save_token, "secondary", height=34).pack(side="left")
        Button(row2, "Créer un jeton", lambda: webbrowser.open(TOKEN_URL), "ghost", height=34).pack(side="left", padx=(6, 0))
        Button(row2, "Jeton pour proposer", lambda: webbrowser.open(FRIEND_TOKEN_URL), "ghost",
               height=34).pack(side="left", padx=(6, 0))

        # Mises à jour de l'addon (sur ce PC)
        u = Card(tab["updates"], "Mises à jour", "de l'addon, sur ce PC")
        u.pack(fill="x")
        label(u.body, "Chercher les nouvelles versions", fg="muted", font="small").pack(anchor="w")
        Segmented(u.body, [("1h", "Toutes les heures"), ("6h", "Toutes les 6 h"), ("start", "Au démarrage seulement"), ("manual", "À la demande")],
                  lambda: self.app.cfg["checkEvery"], lambda v: self.set_opt("checkEvery", v)).pack(anchor="w", pady=(4, 2))
        label(u.body, "Le client vérifie tant qu'il est ouvert (même réduit) et te prévient : bouton qui clignote dans la barre des tâches.",
              fg="dim", font="small").pack(anchor="w", pady=(0, 8))
        self.opts = {}
        opts = [("autoInstall", "Installer automatiquement les mises à jour de l'addon"),
                ("backupBefore", "Sauvegarder mes réglages avant chaque mise à jour")]
        if IS_WIN and FROZEN:
            opts.append(("startup", "Lancer le client avec Windows, réduit (pour vérifier en arrière-plan)"))
        for key, text in opts:
            v = tk.BooleanVar(value=cfg[key])
            cb = tk.Checkbutton(u.body, text="  " + text, variable=v, bg=C["surface"], fg=C["text"], selectcolor=C["surface2"],
                                activebackground=C["surface"], activeforeground=C["text"], bd=0, highlightthickness=0,
                                font=App.fonts["body"], anchor="w", command=lambda k=key, v=v: self.set_opt(k, v.get()))
            cb.pack(anchor="w", pady=2)
            self.opts[key] = v

        # Données (sur GitHub) : planning de .github/workflows/update-data.yml
        NotifyPanel(app, tab["notify"])
        d = Card(tab["data"], "Données", "QuestieDB et wowtbc.gg, vérifiées sur GitHub")
        d.pack(fill="x")
        self.sched, self.schedSha = None, None
        label(d.body, "Fréquence de la vérification", fg="muted", font="small").pack(anchor="w")
        self.freq = Segmented(d.body, [("quotidienne", "Chaque jour"), ("hebdomadaire", "Chaque lundi"), ("manuelle", "À la demande")],
                              lambda: (self.sched or {}).get("frequence"), lambda v: self.set_sched("frequence", v))
        self.freq.pack(anchor="w", pady=(4, 10))
        self.pubVar = tk.BooleanVar(value=False)
        tk.Checkbutton(d.body, text="  Publier automatiquement (sinon une PR à valider sur GitHub)", variable=self.pubVar,
                       bg=C["surface"], fg=C["text"], selectcolor=C["surface2"], activebackground=C["surface"],
                       activeforeground=C["text"], bd=0, highlightthickness=0, font=App.fonts["body"], anchor="w",
                       command=lambda: self.set_sched("publier", self.pubVar.get())).pack(anchor="w", pady=2)
        row3 = tk.Frame(d.body, bg=C["surface"])
        row3.pack(fill="x", pady=(10, 0))
        Button(row3, "Lancer maintenant", self.run_data, "secondary", height=30).pack(side="left")
        Button(row3, "Actualiser", self.load_schedule, "ghost", height=30).pack(side="left", padx=(6, 0))
        self.dataInfo = label(d.body, "", fg="muted", font="small", wraplength=560)
        self.dataInfo.pack(anchor="w", pady=(8, 0))
        self.loaded = False
        # journal des données (Modules/DataLogDB.lua) : les dernières mises à jour, clic = leurs quêtes
        lc = Card(tab["data"], "Ajouts récents", "journal des données de la base de quêtes")
        lc.pack(fill="x", pady=(10, 0))
        self.logRows = tk.Frame(lc.body, bg=C["surface"])
        self.logRows.pack(fill="x")
        self.logOpen, self.logKey = None, None

    @staticmethod
    def tint(col, a=0.18):
        """couleur mêlée au fond des cartes (étiquettes)"""
        bg = C["surface2"]
        c = [int(col[i:i + 2], 16) for i in (1, 3, 5)]
        b = [int(bg[i:i + 2], 16) for i in (1, 3, 5)]
        return "#%02x%02x%02x" % tuple(int(b[i] + (c[i] - b[i]) * a) for i in range(3))

    def fill_log(self, force=False):
        log = self.app.dataLog or []
        key = (id(log), self.logOpen)
        if key == self.logKey and not force:
            return
        self.logKey = key
        for w in self.logRows.winfo_children():
            w.destroy()
        if not log:
            label(self.logRows, "Rien à montrer pour l'instant (jeton nécessaire, lu avec la vérification des versions).",
                  fg="muted", font="small").pack(anchor="w")
            return
        for e in log[:3]:
            row = tk.Frame(self.logRows, bg=C["surface2"], cursor="hand2")
            row.pack(fill="x", pady=2)
            when = datetime.fromtimestamp(e.get("t") or 0).strftime("%d/%m %H:%M")
            items = [label(row, when, fg="muted", font="small", width=12)]
            items[0].pack(side="left", padx=(10, 6), pady=6)
            for n, txt, col in ((len(e.get("add") or []), "+%d quêtes", C["positive"]),
                                (len(e.get("chg") or []), "%d corrigées", C["warning"]),
                                (len(e.get("rem") or []), "%d retirées", C["negative"])):
                if n:
                    t = tk.Label(row, text=txt % n, bg=self.tint(col), fg=col, font=App.fonts["smallb"], padx=7)
                    t.pack(side="left", padx=(0, 6), pady=6)
                    items.append(t)
            src = label(row, e.get("src") or "", fg="dim", font="small")
            src.pack(side="left", padx=(4, 0))
            opened = self.logOpen == e.get("t")
            arrow = label(row, "▾" if opened else "▸", fg="accent" if opened else "muted", font="small")
            arrow.pack(side="right", padx=10)
            items += [row, src, arrow]

            def toggle(_ev=None, t=e.get("t")):
                self.logOpen = None if self.logOpen == t else t
                self.fill_log()
            for w in items:
                w.bind("<Button-1>", toggle)
            if opened:
                q = e.get("q") or {}
                ids = [i for i in (e.get("add") or [])] + [c[0] for c in (e.get("chg") or [])]
                shown = 0
                for i in ids:
                    info = q.get(str(i))
                    if not info:
                        continue
                    if shown >= 5:
                        break
                    shown += 1
                    ql = tk.Frame(self.logRows, bg=C["surface"])
                    ql.pack(fill="x", padx=(96, 0))
                    label(ql, str(info[1] or ""), fg="warning", font="smallb", width=3).pack(side="left")
                    label(ql, info[0], font="small").pack(side="left", padx=(6, 0))
                    if i not in (e.get("add") or []):
                        label(ql, "corrigée", fg="warning", font="small").pack(side="left", padx=(8, 0))
                rest = len(ids) - shown
                if rest > 0:
                    label(self.logRows, "+ %d autres (détail dans l'onglet Journal de la page Quêtes, en jeu)" % rest,
                          fg="dim", font="small").pack(anchor="w", padx=(96, 0), pady=(0, 4))

    def set_tab(self, key):
        if key not in self.tabFrames:
            key = "folder"
        self.app.cfg["settingsTab"] = key
        save_config(self.app.cfg)
        for k, f in self.tabFrames.items():
            if k == key:
                f.pack(fill="both", expand=True)
            else:
                f.pack_forget()
        self.tabBar.refresh()
        if key == "data":
            self.fill_log()
            if not self.loaded:
                self.load_schedule()

    def on_show(self):
        self.set_tab(self.app.cfg.get("settingsTab", "folder"))

    def load_schedule(self):
        a = self.app
        if not a.cfg["token"]:
            self.dataInfo.configure(text="Ajoute un jeton (ci-dessus) pour régler les données depuis le client.", fg=C["warning"])
            return
        self.dataInfo.configure(text="Lecture du planning…", fg=C["muted"])
        g = GitHub(a.cfg["token"])

        def job():
            sched, sha = g.schedule()
            try:
                run = g.last_data_run()
            except NetError:
                run = None
            return sched, sha, run

        def done(res, err):
            if err:
                self.dataInfo.configure(text=str(err), fg=C["negative"])
                return
            self.loaded = True
            self.sched, self.schedSha, run = res
            self.freq.refresh()
            self.pubVar.set(bool(self.sched.get("publier")))
            self.dataInfo.configure(text=self.run_text(run), fg=C["muted"])
        a.run(job, done)

    @staticmethod
    def run_text(run):
        if not run:
            return "Pas encore de vérification enregistrée."
        t = gh_time(run.get("run_started_at") or run.get("created_at"))
        when = datetime.fromtimestamp(t).strftime("%d/%m à %H:%M") if t else "?"
        state = {"success": "réussie", "failure": "échouée", "cancelled": "annulée"}.get(run.get("conclusion"), "en cours")
        return "Dernière vérification : %s, %s." % (when, state)

    def set_sched(self, k, v):
        a = self.app
        if self.sched is None:
            self.freq.refresh()
            return a.toast("Planning pas encore lu (jeton nécessaire).", "warning")
        new = dict(self.sched)
        new[k] = v
        g = GitHub(a.cfg["token"])

        def job():
            g.save_schedule(new, self.schedSha)
            return g.schedule()

        def done(res, err):
            if err:
                a.toast(str(err), "negative")
                self.freq.refresh()
                self.pubVar.set(bool(self.sched.get("publier")))
                return
            self.sched, self.schedSha = res
            self.freq.refresh()
            self.pubVar.set(bool(self.sched.get("publier")))
            a.toast("Planning des données enregistré sur GitHub.", "positive")
        a.run(job, done)

    def run_data(self):
        a = self.app
        if not a.cfg["token"]:
            return a.toast("Ajoute d'abord un jeton.", "warning")

        def done(_, err):
            if err:
                a.toast(str(err), "negative")
            else:
                a.toast("Vérification des données lancée sur GitHub (quelques minutes).", "positive")
                self.dataInfo.configure(text="Vérification lancée : actualise dans quelques minutes.", fg=C["muted"])
        a.run(lambda: GitHub(a.cfg["token"]).run_data_update(), done)

    def set_opt(self, k, v):
        if k == "startup" and not set_startup(v):
            self.app.toast("Impossible de régler le lancement avec Windows.", "negative")
            self.opts[k].set(not v)
            return
        self.app.cfg[k] = v
        save_config(self.app.cfg)

    def browse(self):
        d = filedialog.askdirectory(title="Dossier du jeu, ou Interface\\AddOns", initialdir=self.path.get() or None)
        if d:
            self.apply_path(d)

    def detect(self):
        a = self.app
        a.installs = find_forever()
        if not a.installs:
            return a.toast("WoW Forever introuvable : choisis son dossier avec Parcourir.", "warning")
        if len(a.installs) == 1:
            a.choose_install(a.installs[0], install=False)
            self.path.set(a.addons)
            return
        inst = a.pick_dialog(a.installs)
        if inst:
            a.choose_install(inst, install=False)
            self.path.set(a.addons)

    def apply_path(self, p):
        a = normalize_addons(p.strip())
        if p.strip() and not a:
            self.pathInfo.configure(text="Ce dossier ne contient pas Interface\\AddOns.", fg=C["negative"])
            return
        if a and a != self.app.addons and not self.app.check_forever(a):
            self.path.set(self.app.addons)
            return
        self.path.set(a or "")
        self.app.set_addons(a or "")

    def save_token(self):
        self.app.cfg["token"] = self.token.get().strip()
        save_config(self.app.cfg)
        self.app.toast("Jeton enregistré.", "positive")
        self.app.lan_start()
        self.app.refresh()
        self.loaded = False
        self.load_schedule()

    def on_state(self):
        a = self.app
        if a.cfg.get("settingsTab") == "data":
            self.fill_log()
        if a.addons:
            v = installed_version(a.addons)
            self.pathInfo.configure(text=("Warband Keeper %s installé ici." % v) if v else "Addon pas encore installé ici.", fg=C["muted"])
        else:
            self.pathInfo.configure(text="Choisis le dossier du jeu (ou Interface\\AddOns).", fg=C["warning"])


# ---------------------------------------------------------------------------
# Application
# ---------------------------------------------------------------------------
class App:
    fonts = {}

    def __init__(self):
        self.root = tk.Tk()
        self.root.title("Warband Keeper")
        self.root.configure(bg=C["bg"])
        # taille par défaut : tout le Tableau de bord (six tuiles) et les Réglages visibles sans agrandir,
        # bornée à l'écran (barre des tâches comprise)
        # fenêtre fixe : chaque page tient dans 1000 × 600 sans défiler
        w, h = self.default_size()
        self.root.geometry("%dx%d" % (w, h))
        self.root.resizable(False, False)
        self.setup_fonts()
        self.set_icon()
        self.cfg = load_config()
        self.releases, self.error, self.busy = [], None, False
        self.clientNotes, self.lastCheck, self.notified = None, 0, None
        self.dataLog = []  # journal des données (GitHub.data_log), lu avec les versions
        self.q = queue.Queue()
        self.saveLoading, self.autoDash = False, False
        self.installs = []
        if not self.cfg["addons"] or not os.path.isdir(self.cfg["addons"]):
            self.installs = find_forever()
            pick = self.auto_pick(self.installs)
            self.cfg["addons"] = use_install(pick) if pick else ""
            save_config(self.cfg)
        self.build()
        self.build_chrome()
        if "--minimized" in sys.argv:
            # lancé avec Windows : réduit, il vérifie en arrière-plan
            self.root.after(150, self.minimize)
        # sauvegarde de l'addon lue en arrière-plan : le tableau de bord attend sa lecture ; s'il n'y a rien
        # à montrer, on revient sur l'accueil (sauf si le joueur a déjà changé de page)
        dash, _, fresh = save_state(self.addons)
        self.show("dash" if (isinstance(dash, dict) or not fresh) else "home")
        self.autoDash = not fresh
        self.state_changed()
        self.root.after(80, self.poll)
        if self.cfg["checkEvery"] != "manual":
            self.refresh()
        self.root.after(60000, self.tick)
        self.lan = None
        self.root.after(3000, self.lan_start)

    def lan_start(self):
        """Client du mainteneur (jeton qui écrit sur le dépôt) : reçoit les découvertes des PC du réseau local."""
        token = self.cfg.get("token")
        if self.lan or not token:
            return

        def done(ok, err):
            if err or not ok or self.lan:
                return
            try:
                self.lan = LanCollector(lambda src, n: self.q.put(("call", self.lan_received, (src, n), None)))
            except OSError as e:
                print("découvertes réseau : écoute impossible :", e)
        self.run(lambda: GitHub(token).can_push(), done)

    def lan_received(self, src, n):
        self.toast("Découvertes reçues d'un autre PC : %s." % plural(n, "ajout"), "muted")
        p = self.pages.get("learned")
        if p and self.current == "learned":
            p.reload(force=False)
        self.auto_learned()

    def lan_share(self, force=False):
        """Joueur sans jeton : passe ses découvertes nouvelles au client du mainteneur sur le réseau local."""
        cfg, addons = self.cfg, self.addons
        if getattr(self, "learnSending", False):
            return self.learn_retry(60)
        wait = 600 - (time.time() - getattr(self, "learnAt", 0))
        if not force and wait > 0:
            return self.learn_retry(wait + 1)
        self.learnSending, self.learnAt = True, time.time()
        if not cfg.get("learnedSrc"):
            import secrets
            cfg["learnedSrc"] = "wk-" + secrets.token_hex(4)
            save_config(cfg)
        src, choices = cfg["learnedSrc"], learned_choices(cfg)

        def job():
            mine = read_learned(addons)
            if not mine:
                return None
            known = known_learned(addons)
            rows = learned.merge([{"name": "Ce PC", "trusted": True, "data": mine}], known, choices)
            added = [r for r in rows if r["status"] == learned.INTEGRATED]
            if not added:
                return None
            data, per = {}, {}
            for r in added:
                data.setdefault(r["genre"], {})[r["key"]] = r["value"]
                per[r["genre"]] = per.get(r["genre"], 0) + 1
            if not lan_send(learned.export_wkd(data, src)):
                raise NetError("aucun PC du mainteneur sur le réseau")
            return {"n": len(added), "base": learned.build(known, rows),
                    "what": ", ".join("%s %d" % (learned.LABEL[g].lower(), n) for g, n in per.items()),
                    "items": [{"t": learned.short(r["genre"], r["key"], r["value"]), "s": ["Ce PC"], "c": 1}
                              for r in added][:60]}

        def done(res, err):
            self.learnSending = False
            if err:
                print("découvertes réseau :", err)
                self.learnAt = 0
                self.learn_retry(900)  # mainteneur pas là : nouvel essai dans 15 min
                return
            if res:
                save_sent_learned(res["base"])
                cfg["learnedLast"] = {"at": int(time.time()), "n": res["n"], "items": res.get("items") or []}
                cfg["learnedMode"] = "lan"
                save_config(cfg)
                self.toast("Découvertes passées au PC du mainteneur : %s." % res["what"], "muted")
            p = self.pages.get("learned")
            if p and self.current == "learned":
                p.reload(force=False)
        self.run(job, done)

    def tick(self):
        """Vérification régulière pendant que le client est ouvert (Réglages > Mises à jour)."""
        every = {"1h": 3600, "6h": 6 * 3600}.get(self.cfg["checkEvery"])
        if every and not self.busy and time.time() - self.lastCheck >= every:
            self.refresh()
        try:
            self.check_notifications()
            if self.current == "dash":
                self.pages["dash"].fill()
        except Exception as e:
            print("notifications", e)
        self.root.after(60000, self.tick)

    def pending_data(self):
        """Mises à jour de la base arrivées après la version installée : liste d'entrées du journal."""
        inst = self.installed
        if not (inst and self.dataLog):
            return []
        t0 = 0
        for r in self.releases:
            if r.get("tag_name", "").lstrip("v") == inst:
                t0 = gh_time(r.get("published_at") or r.get("created_at"))
                break
        if not t0:
            return []
        return [e for e in self.dataLog if (e.get("t") or 0) > t0 + 60]

    def check_data_notify(self, now=None):
        """Notification Windows quand une nouvelle mise à jour des données est publiée (une fois par mise à jour)."""
        opts = self.cfg.get("notify") or {}
        if not self.dataLog:
            return None
        newest = max((e.get("t") or 0) for e in self.dataLog)
        last = self.cfg.get("dataNotified") or 0
        if newest <= last:
            return None
        now = now or time.time()
        if not last or not opts.get("data") or now - newest > 3 * 86400:
            # première lecture, notifications coupées ou mise à jour ancienne : notée sans prévenir
            self.cfg["dataNotified"] = newest
            save_config(self.cfg)
            return None
        if opts.get("quiet") and quiet_now(now):
            return None  # attend le matin (prochaine vérification)
        fresh = [e for e in self.dataLog if (e.get("t") or 0) > last]
        title = "Warband Keeper · données mises à jour"
        text = data_text(*data_sum(fresh)) + ". Installe la nouvelle version depuis le client."
        self.cfg["dataNotified"] = newest
        save_config(self.cfg)
        if not notify_windows(title, text):
            self.toast("%s · %s" % (title, text), "accent")
        return title, text

    def check_notifications(self, now=None):
        """Notifications Windows dues d'après le résumé de l'addon (une seule fois chacune)."""
        opts = self.cfg.get("notify") or {}
        if not self.addons:
            return []
        dash, _, fresh = save_state(self.addons)  # jamais de lecture du fichier ici (thread Tk)
        if not fresh:
            self.load_save()
        sent = self.cfg.setdefault("notified", {})
        now = now or time.time()
        if opts.get("quiet") and quiet_now(now):
            return []
        out = []
        for nid, title, text in due_notifications(dash, opts, now):
            if nid in sent:
                continue
            sent[nid] = int(now)
            out.append((title, text))
            if not notify_windows(title, text):
                self.toast("%s · %s" % (title, text), "warning")
        if out:
            # on oublie les notifications de plus de 30 jours
            for k in [k for k, t in sent.items() if now - t > 30 * 86400]:
                del sent[k]
            save_config(self.cfg)
        return out

    # -- présentation
    def setup_fonts(self):
        fam = "Segoe UI" if IS_WIN else ("Helvetica Neue" if sys.platform == "darwin" else "DejaVu Sans")
        mk = lambda size, weight="normal": tkfont.Font(family=fam, size=size, weight=weight)
        App.fonts = {"h1": mk(18, "bold"), "h2": mk(13, "bold"), "h3": mk(11, "bold"), "body": mk(10), "bodyb": mk(10, "bold"),
                     "small": mk(9), "smallb": mk(9, "bold"), "btn": mk(10, "bold"), "btnL": mk(12, "bold"), "nav": mk(11)}

    def resource(self, name):
        base = getattr(sys, "_MEIPASS", os.path.dirname(os.path.abspath(__file__)))
        return os.path.join(base, "assets", name)

    def set_icon(self):
        self.logo = None
        try:
            self.logo = tk.PhotoImage(file=self.resource("logo.png"))
            self.root.iconphoto(True, self.logo)
            self.logoSmall = self.logo.subsample(max(1, self.logo.width() // 36))
        except tk.TclError:
            self.logoSmall = None

    RAIL = ["dash", "home", "learned"]  # rail d'icônes ; Réglages : roue de l'en-tête des pages

    def build(self):
        side = tk.Frame(self.root, bg=C["sidebar"], width=92)
        side.pack(side="left", fill="y")
        side.pack_propagate(False)
        self.side = side
        brand = tk.Frame(side, bg=C["sidebar"])
        self.brand = brand
        brand.pack(pady=(14, 14))
        if self.logoSmall:
            tk.Label(brand, image=self.logoSmall, bg=C["sidebar"]).pack()
        else:
            tk.Label(brand, text="W", bg=C["accent"], fg="#ffffff", font=App.fonts["h2"], width=2).pack()
        self.nav = {}
        order = self.RAIL + ["settings"]
        PAGES.sort(key=lambda c: order.index(c.key) if c.key in order else 99)
        for cls in PAGES:
            if cls.key not in self.RAIL:
                continue
            b = tk.Frame(side, bg=C["sidebar"], cursor="hand2")
            b.pack(fill="x", padx=7, pady=2)
            ic = tk.Label(b, text=cls.icon, bg=C["sidebar"], fg=C["muted"], font=App.fonts["h2"], cursor="hand2")
            ic.pack(pady=(7, 0))
            tx = tk.Label(b, text=cls.title, bg=C["sidebar"], fg=C["muted"], font=App.fonts["small"], cursor="hand2")
            tx.pack(pady=(0, 7))
            b.parts = (ic, tx)
            for w in (b, ic, tx):
                w.bind("<Button-1>", lambda e, k=cls.key: self.show(k))
                w.bind("<Enter>", lambda e, k=cls.key: self.paint_nav(hover=k))
                w.bind("<Leave>", lambda e: self.paint_nav())
            self.nav[cls.key] = b
        # point sur « Addon » : nombre de versions à installer (ou « C » pour le client seul)
        self.navBadge = tk.Label(side, text="", bg=C["negative"], fg="#ffffff", font=App.fonts["smallb"], padx=4, pady=0, cursor="hand2")
        self.navBadge.bind("<Button-1>", lambda e: self.show("home"))
        for w in (self.nav["home"],) + self.nav["home"].parts:
            for ev in ("<Enter>", "<Leave>", "<Button-1>"):
                w.bind(ev, lambda e: self.root.after_idle(self.navBadge.lift), add="+")
        tk.Label(side, text=CLIENT_VERSION, bg=C["sidebar"], fg=C["dim"], font=App.fonts["small"]).pack(side="bottom", pady=10)

        main = tk.Frame(self.root, bg=C["bg"])
        main.pack(side="left", fill="both", expand=True, padx=14, pady=(10, 12))
        self.pages = {}
        for cls in PAGES:
            p = cls(self, main)
            self.pages[cls.key] = p
        self.toastBar = tk.Label(self.root, text="", bg=C["surface2"], fg=C["text"], font=App.fonts["body"], padx=14, pady=8,
                                 justify="center")
        self.current = None

    # -- fenêtre sans barre de titre Windows : réduire / agrandir / fermer posés sur le fond (Windows seulement)
    def hwnd(self):
        import ctypes
        return ctypes.windll.user32.GetParent(self.root.winfo_id())

    DEFAULT_W, DEFAULT_H = 1000, 600

    def default_size(self):
        sw, sh = self.root.winfo_screenwidth(), self.root.winfo_screenheight()
        return min(self.DEFAULT_W, max(700, sw - 40)), min(self.DEFAULT_H, max(480, sh - 90))

    def build_chrome(self):
        self.frameless = IS_WIN and "--native-frame" not in sys.argv
        self.maxed, self.normalGeo = False, None
        if not self.frameless:
            return
        root = self.root
        root.update_idletasks()
        # centrée à l'écran
        w, h = self.default_size()
        x = max(0, (root.winfo_screenwidth() - w) // 2)
        y = max(0, (root.winfo_screenheight() - h) // 3)
        root.geometry("%dx%d+%d+%d" % (w, h, x, y))
        root.overrideredirect(True)
        root.configure(highlightthickness=1, highlightbackground=C["border"], highlightcolor=C["border"])
        # garder le bouton dans la barre des tâches (une fenêtre sans cadre n'en a pas d'office)
        try:
            import ctypes
            GWL_EXSTYLE, WS_EX_APPWINDOW, WS_EX_TOOLWINDOW = -20, 0x40000, 0x80
            hwnd = self.hwnd()
            st = ctypes.windll.user32.GetWindowLongW(hwnd, GWL_EXSTYLE)
            ctypes.windll.user32.SetWindowLongW(hwnd, GWL_EXSTYLE, (st & ~WS_EX_TOOLWINDOW) | WS_EX_APPWINDOW)
            root.withdraw()
            root.after(10, root.deiconify)
        except Exception:
            pass
        # icônes de Windows (Segoe MDL2 Assets) si la police existe, sinon des caractères simples
        mdl = "Segoe MDL2 Assets" in tkfont.families()
        self.glyph = {"min": "\uE921" if mdl else "–", "max": "\uE922" if mdl else "□", "restore": "\uE923" if mdl else "▫",
                      "close": "\uE8BB" if mdl else "×"}
        gfont = (("Segoe MDL2 Assets", 9) if mdl else App.fonts["body"])
        bar = tk.Frame(root, bg=C["bg"])
        bar.place(relx=1.0, x=-1, y=1, anchor="ne")
        self.chromeBtns = {}

        def btn(key, cmd, hover):
            b = tk.Label(bar, text=self.glyph[key], bg=C["bg"], fg=C["muted"], font=gfont, width=5, pady=7, cursor="hand2")
            b.pack(side="left")
            b.bind("<Button-1>", lambda e: cmd())
            b.bind("<Enter>", lambda e: b.configure(bg=hover, fg=C["text"]))
            b.bind("<Leave>", lambda e: b.configure(bg=C["bg"], fg=C["muted"]))
            self.chromeBtns[key] = b
            return b
        btn("min", self.minimize, C["hover"])
        btn("close", root.destroy, "#c42b1c")
        # glisser : le haut de la fenêtre et la colonne de gauche ; double-clic en haut : agrandir
        strip = tk.Frame(root, bg=C["bg"], height=14, cursor="fleur")
        strip.place(x=92, y=0, relwidth=1.0, width=-(92 + 100))
        drag = {}

        def start(e):
            drag["x"], drag["y"] = e.x_root - root.winfo_x(), e.y_root - root.winfo_y()

        def move(e):
            if self.maxed or "x" not in drag:
                return
            root.geometry("+%d+%d" % (e.x_root - drag["x"], e.y_root - drag["y"]))
        # la fenêtre se déplace en la saisissant n'importe où, sauf sur un bouton, un lien (curseur main), un champ
        # de saisie, une barre de défilement ou une fenêtre de dialogue
        def grabbable(w):
            try:
                if w.winfo_toplevel() is not root:
                    return False
                if isinstance(w, (Button, Segmented, ThinScroll, tk.Entry, tk.Text, tk.Scrollbar, tk.Menu)):
                    return False
                return str(w.cget("cursor")) not in ("hand2", "xterm")
            except (tk.TclError, AttributeError):
                return False

        def start_any(e):
            drag.pop("x", None)
            if grabbable(e.widget):
                start(e)

        def stop(e):
            drag.pop("x", None)
        root.bind_all("<ButtonPress-1>", start_any, add="+")
        root.bind_all("<B1-Motion>", move, add="+")
        root.bind_all("<ButtonRelease-1>", stop, add="+")
        # fenêtre fixe : ni agrandir ni redimensionner

    def minimize(self):
        if not getattr(self, "frameless", False):
            self.root.iconify()
            return
        try:
            import ctypes
            ctypes.windll.user32.ShowWindow(self.hwnd(), 6)  # SW_MINIMIZE
        except Exception:
            self.root.iconify()

    def toggle_max(self):
        if not getattr(self, "frameless", False):
            return
        root = self.root
        if self.maxed:
            root.geometry(self.normalGeo)
            self.maxed = False
        else:
            self.normalGeo = root.geometry()
            x, y, w, h = 0, 0, root.winfo_screenwidth(), root.winfo_screenheight()
            try:
                import ctypes
                from ctypes import wintypes
                r = wintypes.RECT()
                ctypes.windll.user32.SystemParametersInfoW(0x30, 0, ctypes.byref(r), 0)  # zone de travail (sans la barre des tâches)
                x, y, w, h = r.left, r.top, r.right - r.left, r.bottom - r.top
            except Exception:
                pass
            root.geometry("%dx%d+%d+%d" % (w, h, x, y))
            self.maxed = True
        if "max" in self.chromeBtns:
            self.chromeBtns["max"].configure(text=self.glyph["restore" if self.maxed else "max"])

    def show(self, key):
        self.current = key
        self.autoDash = False
        for k, p in self.pages.items():
            if k == key:
                p.pack(fill="both", expand=True)
                p.on_show()
            else:
                p.pack_forget()
        self.paint_nav()

    def paint_nav(self, hover=None):
        for k, b in self.nav.items():
            bg = C["surface2"] if k == self.current else (C["hover"] if k == hover else C["sidebar"])
            fg = C["text"] if k == self.current else C["muted"]
            b.configure(bg=bg)
            for w in b.parts:
                w.configure(bg=bg, fg=fg)

    def show_settings(self, tab):
        """Réglages, ouverts sur un onglet (folder, github, updates, notify, data)."""
        self.cfg["settingsTab"] = tab
        self.show("settings")

    def toast(self, text, kind="muted"):
        # message long : à la ligne dans la largeur de la fenêtre, et affiché plus longtemps
        wrap = max(300, self.root.winfo_width() - 80)
        self.toastBar.configure(text=text, fg=C.get(kind, C["text"]), wraplength=wrap)
        self.toastBar.place(relx=0.5, rely=1.0, y=-18, anchor="s")
        self.toastBar.lift()
        if getattr(self, "_toastJob", None):
            self.root.after_cancel(self._toastJob)
        self._toastJob = self.root.after(max(4200, 60 * len(text)), self.toastBar.place_forget)

    def pick_dialog(self, installs):
        win = tk.Toplevel(self.root, bg=C["surface"])
        win.title("Warband Keeper")
        win.transient(self.root)
        win.resizable(False, False)
        res = {"inst": None}
        tk.Label(win, text="Installations de WoW Forever trouvées", bg=C["surface"], fg=C["text"], font=App.fonts["h3"],
                 padx=18, pady=14).pack(anchor="w")

        def done(i):
            res["inst"] = i
            win.destroy()
        for inst in installs[:8]:
            row = tk.Frame(win, bg=C["surface2"])
            row.pack(fill="x", padx=14, pady=2)
            tk.Label(row, text=inst["label"], bg=C["surface2"], fg=C["accent"] if inst["forever"] else C["text"],
                     font=App.fonts["bodyb"], padx=10, pady=8).pack(side="left")
            tk.Label(row, text=short_path(os.path.dirname(os.path.dirname(inst["addons"]))) + ("   (addon %s)" % inst["version"] if inst["version"] else ""),
                     bg=C["surface2"], fg=C["muted"], font=App.fonts["small"]).pack(side="left")
            Button(row, "Choisir", lambda i=inst: done(i), "primary" if inst["forever"] else "secondary", height=28).pack(side="right", padx=8, pady=4)
        Button(win, "Annuler", lambda: done(None), "ghost", width=100, height=30).pack(anchor="e", padx=14, pady=12)
        win.update_idletasks()
        x = self.root.winfo_rootx() + (self.root.winfo_width() - win.winfo_width()) // 2
        y = self.root.winfo_rooty() + (self.root.winfo_height() - win.winfo_height()) // 3
        win.geometry("+%d+%d" % (x, y))
        win.grab_set()
        self.root.wait_window(win)
        return res["inst"]

    def rescan(self):
        self.installs = find_forever()
        pick = self.auto_pick(self.installs)
        if pick:
            self.choose_install(pick, install=False)
        else:
            self.state_changed()
            self.toast("%d installation%s trouvée%s." % (len(self.installs), "s" if len(self.installs) > 1 else "",
                                                        "s" if len(self.installs) > 1 else ""), "muted")

    def confirm(self, text):
        win = tk.Toplevel(self.root, bg=C["surface"])
        win.title("Warband Keeper")
        win.transient(self.root)
        win.resizable(False, False)
        res = {"ok": False}
        tk.Label(win, text=text, bg=C["surface"], fg=C["text"], font=App.fonts["body"], justify="left", padx=20, pady=18).pack()
        row = tk.Frame(win, bg=C["surface"])
        row.pack(fill="x", padx=16, pady=(0, 16))

        def done(v):
            res["ok"] = v
            win.destroy()
        Button(row, "Oui", lambda: done(True), "primary", width=100, height=32).pack(side="right")
        Button(row, "Annuler", lambda: done(False), "ghost", width=100, height=32).pack(side="right", padx=8)
        win.update_idletasks()
        x = self.root.winfo_rootx() + (self.root.winfo_width() - win.winfo_width()) // 2
        y = self.root.winfo_rooty() + (self.root.winfo_height() - win.winfo_height()) // 3
        win.geometry("+%d+%d" % (x, y))
        win.grab_set()
        self.root.wait_window(win)
        return res["ok"]

    # -- état
    @property
    def addons(self):
        return self.cfg["addons"] if self.cfg["addons"] and os.path.isdir(self.cfg["addons"]) else ""

    @property
    def installed(self):
        return installed_version(self.addons) if self.addons else None

    @property
    def latest(self):
        # version de l'addon à proposer : la plus récente qui change l'addon (une version « client seulement »,
        # notes « Rien ne change en jeu », n'est ni annoncée ni installée d'office pour l'addon)
        for r in self.releases:
            if addon_asset(r) and not client_only(r):
                return r
        return None

    @property
    def latest_version(self):
        r = self.latest
        return r["tag_name"].lstrip("v") if r else None

    def newer(self):
        inst = self.installed
        if not inst:
            return self.releases[:1]
        return [r for r in self.releases if vtuple(r["tag_name"]) > vtuple(inst) and not client_only(r)]

    @staticmethod
    def auto_pick(installs):
        """Installation prise d'office (WoW Forever) : celle qui a déjà l'addon, sinon la seule (bêta et PTR
        mises de côté quand il y a l'installation normale)."""
        withAddon = [i for i in installs if i["version"]]
        if withAddon:
            return withAddon[0]
        live = [i for i in installs if "(" not in i["label"]]
        if len(live) == 1:
            return live[0]
        forever = [i for i in installs if i["forever"]]
        if len(forever) == 1:
            return forever[0]
        return installs[0] if len(installs) == 1 else None

    def choose_install(self, inst, install=True):
        self.set_addons(use_install(inst))
        self.toast("Dossier choisi : %s." % inst["label"], "positive")
        if install and self.latest and not self.installed:
            self.update_addon()

    def browse_addons(self):
        d = filedialog.askdirectory(title="Dossier du jeu, ou Interface\\AddOns")
        if not d:
            return
        a = normalize_addons(d)
        if not a and os.path.isdir(os.path.join(d, "Interface")) is False and os.path.isfile(os.path.join(d, ".flavor.info")):
            a = os.path.join(d, "Interface", "AddOns")
            os.makedirs(a, exist_ok=True)
        if a:
            if not self.check_forever(a):
                return
            self.set_addons(a)
            self.toast("Dossier choisi.", "positive")
        else:
            self.toast("Ce dossier ne contient pas Interface\\AddOns.", "negative")

    def check_forever(self, addons):
        """Warband Keeper n'existe que pour WoW Forever : confirmation pour un autre dossier."""
        fdir = game_dir(addons)
        if _is_forever(fdir, os.path.basename(fdir)):
            return True
        return self.confirm("Ce dossier ne ressemble pas à WoW Forever.\n"
                            "Warband Keeper ne fonctionne que sur WoW Forever.\n\nL'utiliser quand même ?")

    def set_addons(self, path):
        self.cfg["addons"] = path
        save_config(self.cfg)
        self.state_changed()

    def state_changed(self):
        for p in self.pages.values():
            try:
                p.on_state()
            except Exception as e:  # une page ne doit pas bloquer les autres
                print("page", p.key, e)
        self.client_banner()
        self.update_badge()

    def update_badge(self):
        """Pastille rouge sur « Mises à jour » quand l'addon (ou le client) a une version plus récente."""
        n = len(self.newer()) if (self.installed and self.releases) else 0
        asset, ver = best_client(self.releases) if self.releases else (None, None)
        client = bool(asset and ver and vtuple(ver) > vtuple(CLIENT_VERSION))
        text = str(n) if n else ("C" if client else "")
        if text:
            self.navBadge.configure(text=text)
            self.navBadge.place(in_=self.nav["home"], relx=1.0, x=-4, y=4, anchor="ne")
            self.navBadge.lift()
        else:
            self.navBadge.place_forget()

    def open_addons(self):
        if self.addons:
            open_folder(self.addons)
        else:
            self.show_settings("folder")

    # -- tâches en arrière-plan (le résultat revient par la file, traité dans poll)
    def run(self, fn, done=None):
        def worker():
            try:
                res = fn()
                self.q.put(("done", done, res, None))
            except Exception as e:
                self.q.put(("done", done, None, e))
        threading.Thread(target=worker, daemon=True).start()

    def load_save(self):
        """Relit WarbandKeeper.lua en arrière-plan s'il a changé (une lecture à la fois) ; le tableau de bord
        est rempli au retour, sur le thread Tk."""
        addons = self.addons
        if not addons or self.saveLoading or save_state(addons)[2]:
            return
        self.saveLoading = True

        def done(res, err):
            self.saveLoading = False
            if err:
                print("sauvegarde de l'addon illisible :", err)
                return
            if addons != self.addons:  # dossier changé pendant la lecture : relire le nouveau
                return self.load_save()
            dash = res[0] if res else None
            if self.autoDash:
                self.autoDash = False
                if self.current == "dash" and not isinstance(dash, dict):
                    return self.show("home")
            if self.current == "dash":
                self.pages["dash"].fill()
            self.auto_learned()
        self.run(lambda: read_save(addons), done)

    def auto_learned(self, force=False, manual=False):
        """Découvertes envoyées toutes seules sur GitHub (main, sans demande de fusion) quand la sauvegarde a changé
        (déconnexion du jeu, /reload) : réglage learnedAuto (oui d'office), jeton en écriture. Au plus une fois
        toutes les 10 min, sauf « Envoyer »."""
        cfg, addons = self.cfg, self.addons
        # sans jeton : passées au client du mainteneur sur le réseau local, sans rien demander
        if addons and not cfg.get("token") and (manual or cfg.get("learnedAuto", True)):
            return self.lan_share(force)
        if not (addons and cfg.get("token")):
            return
        if not manual and not cfg.get("learnedAuto", True):
            return
        # envoi déjà en cours ou trop récent : reprogrammé au lieu d'être perdu (avant, une déconnexion moins de
        # 10 min après un envoi n'était jamais envoyée avant la suivante)
        if getattr(self, "learnSending", False):
            return self.learn_retry(60)
        wait = 600 - (time.time() - getattr(self, "learnAt", 0))
        if not force and wait > 0:
            return self.learn_retry(wait + 1)
        self.learnSending, self.learnAt = True, time.time()
        token = cfg["token"]
        choices = learned_choices(cfg)

        if not cfg.get("learnedSrc"):
            import secrets
            cfg["learnedSrc"] = "wk-" + secrets.token_hex(4)
            save_config(cfg)
        src = cfg["learnedSrc"]
        friends = list(cfg.get("learnedFriends") or [])

        def job():
            mine = read_learned(addons)
            gh = GitHub(token)
            if gh.can_push():
                # mainteneur : propositions des joueurs de confiance fusionnées, puis envoi direct sur main
                merged = gh.merge_friend_prs(friends)
                if not mine and not merged:
                    return None
                res = gh.learned_pr(learned_sources(mine or {}, cfg), choices, direct=True)
                if res is not None:
                    res["merged"] = merged
                return res
            # autre joueur : seulement ce qui est nouveau, proposé par une demande de fusion depuis sa copie
            if not mine:
                return None
            known = known_learned(addons)
            rows = learned.merge([{"name": "Ce PC", "trusted": True, "data": mine}], known, choices)
            added = [r for r in rows if r["status"] == learned.INTEGRATED]
            if not added:
                return None
            data = {}
            per = {}
            for r in added:
                data.setdefault(r["genre"], {})[r["key"]] = r["value"]
                per[r["genre"]] = per.get(r["genre"], 0) + 1
            what = ", ".join("%s %d" % (learned.LABEL[g].lower(), n) for g, n in per.items())
            url = gh.learned_contribute(data, src, what)
            return {"n": len(added), "base": learned.build(known, rows), "what": what, "pr": url,
                    "items": [{"t": learned.short(r["genre"], r["key"], r["value"]), "s": ["Ce PC"], "c": 1}
                              for r in added][:60]}

        def done(res, err):
            self.learnSending = False
            if err:
                if manual:
                    self.toast("Envoi impossible : %s" % err, "negative")
                else:
                    print("découvertes : envoi impossible :", err)
                    self.learnAt = 0
                    self.learn_retry(900)  # réseau coupé, GitHub occupé… : nouvel essai dans 15 min
            elif res:
                save_sent_learned(res["base"])
                cfg["learnedLast"] = {"at": int(time.time()), "n": res["n"], "items": res.get("items") or []}
                cfg["learnedMode"] = "pr" if res.get("pr") else "direct"
                save_config(cfg)
                if res.get("pr"):
                    self.toast("Découvertes proposées au mainteneur : %s." % res["what"], "positive")
                else:
                    self.toast("Découvertes envoyées sur GitHub : %s." % res["what"]
                               + (" (%s d'autres joueurs fusionnée%s)" % (res["merged"], "s" if res["merged"] > 1 else "")
                                  if res.get("merged") else ""), "positive")
            elif manual:
                self.toast("Rien de nouveau par rapport à GitHub.", "muted")
            p = self.pages.get("learned")
            if p and self.current == "learned":
                p.reload(force=False)
            elif p and manual:
                p.fill()
        self.run(job, done)

    def learn_retry(self, delay):
        """Un seul envoi automatique en attente à la fois (le plus proche gardé)."""
        due = time.time() + delay
        if getattr(self, "learnRetryAt", 0) and self.learnRetryAt <= due:
            return
        if getattr(self, "learnRetryJob", None):
            try:
                self.root.after_cancel(self.learnRetryJob)
            except tk.TclError:
                pass
        self.learnRetryAt = due

        def fire():
            self.learnRetryJob, self.learnRetryAt = None, 0
            self.auto_learned()
        self.learnRetryJob = self.root.after(int(delay * 1000), fire)

    def ui(self, fn, *a):
        self.q.put(("call", fn, a, None))

    def poll(self):
        # une erreur dans un rappel ne doit jamais arrêter la boucle (sinon plus aucune tâche de fond n'aboutit)
        try:
            while True:
                kind, fn, res, err = self.q.get_nowait()
                try:
                    if kind == "call":
                        fn(*res)
                    elif fn:
                        fn(res, err)
                except Exception as e:
                    try:
                        self.toast("Erreur : %s" % e, "negative")
                    except Exception:
                        pass
        except queue.Empty:
            pass
        finally:
            self.root.after(80, self.poll)

    def refresh(self):
        home = self.pages["home"]
        home.set_busy("Recherche des versions sur GitHub…")
        self.error = None
        if getattr(home, "action", None):
            home.action.set("Vérification…", False, "secondary")

        def job():
            g = GitHub(self.cfg["token"])
            rels = g.releases()
            notes = None
            try:
                # première release qui a les notes du client (la toute dernière peut ne pas encore les avoir)
                for r in rels or []:
                    if any(a["name"] == "WarbandKeeper-Client-notes.md" for a in r.get("assets", [])):
                        notes = g.client_notes(r)
                        break
            except (NetError, OSError):
                pass
            try:
                log = g.data_log()
            except (NetError, OSError, ValueError, KeyError):
                log = None
            return rels, notes, log

        def done(res, err):
            self.lastCheck = time.time()
            if err:
                self.error = str(err) if isinstance(err, NetError) else "Erreur : %s" % err
                home.set_busy(self.error)
            else:
                self.releases, notes, log = res
                self.clientNotes = notes or self.clientNotes
                if log is not None:
                    self.dataLog = log
                    self.check_data_notify()
                home.set_busy("Vérifié à %s." % datetime.now().strftime("%H:%M"))
            self.state_changed()
            inst = self.installed
            latest = self.latest_version
            if not err and inst:
                write_latest(self.addons, latest)
            newer = not err and inst and latest and vtuple(latest) > vtuple(inst)
            self.root.title("Warband Keeper · version %s disponible" % latest if newer else "Warband Keeper")
            # nouvelle version vue pour la première fois : on prévient (clignote, message), une seule fois par version
            if newer and latest != self.notified:
                self.notified = latest
                if not self.cfg["autoInstall"]:
                    self.toast("Nouvelle version %s de Warband Keeper : « Mettre à jour » dans la page Mises à jour." % latest, "warning")
                flash_taskbar(self.root)
            # installation automatique (Réglages > Mises à jour), seulement sur un addon déjà installé
            # après un retour en arrière, la version quittée n'est plus réinstallée d'office (seulement une plus
            # récente qu'elle) ; « skipVersion » est oublié à la prochaine installation faite à la main
            skip = self.cfg.get("skipVersion")
            if not err and self.cfg["autoInstall"] and inst and self.latest_version and not self.busy \
                    and vtuple(self.latest_version) > vtuple(inst) \
                    and not (skip and vtuple(self.latest_version) <= vtuple(skip)):
                self.toast("Nouvelle version %s : installation automatique…" % self.latest_version)
                self.update_addon(manual=False)
        self.run(job, done)

    def update_addon(self, manual=True):
        rel, addons = self.latest, self.addons
        if not (rel and addons) or self.busy:
            return
        if manual and self.cfg.get("skipVersion"):
            self.cfg.pop("skipVersion", None)  # installation demandée : l'installation automatique reprend
            save_config(self.cfg)
        home = self.pages["home"]
        old = self.installed
        self.busy = True
        self.state_changed()

        def job():
            if self.cfg["backupBefore"] and old:
                self.ui(home.set_busy, "Sauvegarde de tes réglages…", 0.02)
                backup_saved_variables(addons, old, self.cfg["keepBackups"])
            tmp = os.path.join(tempfile.gettempdir(), addon_asset(rel)["name"])
            self.ui(home.set_busy, "Téléchargement de la version %s…" % rel["tag_name"].lstrip("v"), 0.05)
            GitHub(self.cfg["token"]).download(addon_asset(rel), tmp,
                                               lambda f: self.ui(home.set_busy, "Téléchargement… %d %%" % (f * 100), 0.05 + f * 0.85))
            self.ui(home.set_busy, "Installation…", 0.93)
            restart = install_zip(addons, tmp, old)
            write_latest(addons, rel["tag_name"].lstrip("v"))
            try:
                os.remove(tmp)
            except OSError:
                pass
            return rel["tag_name"].lstrip("v"), restart, old is None

        def done(res, err):
            self.busy = False
            if err:
                home.set_busy(str(err) if isinstance(err, (NetError, RuntimeError)) else "Échec : %s" % err)
                self.toast("La mise à jour n'a pas abouti : rien n'a été changé.", "negative")
            else:
                ver, restart, first = res
                running = game_running()
                # jeu fermé : il chargera la nouvelle version à son lancement, rien à faire ni à dire
                if not running:
                    how = ""
                elif first:
                    how = "Relance complètement le jeu pour la charger."
                elif restart:
                    how = "Redémarrage complet du jeu nécessaire : de nouveaux fichiers sont arrivés (un /reload ne suffit pas)."
                else:
                    how = "Un /reload en jeu suffit."
                self.lastInstall = (ver, restart and not first, how) if running else (ver, None, "")
                home.set_busy(("Version %s installée. %s" % (ver, how)).strip(), 1.0)
                self.root.after(2500, lambda: home.set_busy(home.status["text"]))
                self.toast(("Installé. " + how).strip(), "warning" if (restart and running) else "positive")
            self.state_changed()
        self.run(job, done)

    # -- mise à jour du client lui-même
    def client_banner(self):
        """Ancienne bannière de la barre latérale : la mise à jour du client est maintenant dans la page Addon
        (carte Client PC) et l'Accueil (En bref) ; l'état est repeint dans l'en-tête de chaque page."""
        for p in self.pages.values():
            try:
                p.paint_status()
            except Exception as e:
                print("état", p.key, e)

    def update_client(self, asset):
        asset = dict(asset)  # copie : remplacée par l'exe du moment si celui-ci a changé sur GitHub
        dest = sys.executable + ".new"
        self.toast("Téléchargement du client…")

        def done(_, err):
            size = int(asset.get("size") or 0)
            if not err and (not os.path.isfile(dest) or (size and os.path.getsize(dest) != size)):
                err = NetError("le fichier reçu est incomplet")
            if err:
                try:
                    os.remove(dest)
                except OSError:
                    pass
                return self.toast("Échec du téléchargement du client : %s" % err, "negative")
            self_update(dest)  # seulement un exe complet : rien n'est remplacé sinon
            self.root.destroy()
        token = self.cfg["token"]

        def job():
            gh = GitHub(token)
            try:
                gh.download(asset, dest)
            except NetError:
                # l'exe vu à la dernière vérification a été remplacé entre-temps (nouvelle Release : l'ancien est
                # retiré, ou reconstruit) : son adresse ne mène plus nulle part. Releases relues, nouvel essai
                # avec le client qui y est joint maintenant.
                fresh, ver = best_client(gh.releases())
                if not fresh or fresh.get("url") == asset.get("url") or vtuple(ver) <= vtuple(CLIENT_VERSION):
                    raise NetError("le client est en cours de publication sur GitHub : réessaie dans quelques minutes")
                asset.clear()
                asset.update(fresh)  # taille attendue du nouveau fichier, pour la vérification de done
                gh.download(fresh, dest)
        self.run(job, done)

    def mainloop(self):
        self.root.mainloop()


if __name__ == "__main__":
    App().mainloop()
