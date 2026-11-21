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

CLIENT_VERSION = "1.9.8"
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
    "positive": "#9ed17a", "warning": "#f2a84d", "negative": "#e86b6b",
}

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


def read_characters(addons):
    """Persos du compte lus dans WarbandKeeper.lua (le plus récent) : [{ name, cls, level, money, seen }]."""
    files = [p for p in saved_variables(addons) if p.endswith(".lua")]
    if not files:
        return []
    path = max(files, key=os.path.getmtime)
    mt = os.path.getmtime(path)
    if _chars_cache.get("path") == path and _chars_cache.get("mt") == mt:
        return _chars_cache["list"]
    out = []
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            text = f.read()
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
    _chars_cache.update(path=path, mt=mt, list=out)
    return out


_dash_cache = {}


def read_dash(addons):
    """Résumé écrit par l'addon à la déconnexion (WarbandKeeperDB.clientDash, Modules/ClientDash.lua), ou None."""
    files = [p for p in saved_variables(addons) if p.endswith(".lua")] if addons else []
    if not files:
        return None
    path = max(files, key=os.path.getmtime)
    mt = os.path.getmtime(path)
    if _dash_cache.get("path") == path and _dash_cache.get("mt") == mt:
        return _dash_cache["dash"]
    dash = None
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            text = f.read()
        i = _top_key(text, "clientDash")
        if i is not None:
            it = _lua_tokens(text, i)
            dash = _lua_value(it, next(it))
    except Exception:
        dash = None
    _dash_cache.update(path=path, mt=mt, dash=dash)
    return dash


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
        total = int(r.headers.get("Content-Length") or asset.get("size") or 0)
        done = 0
        with open(dest, "wb") as f:
            while True:
                chunk = r.read(65536)
                if not chunk:
                    break
                f.write(chunk)
                done += len(chunk)
                if progress and total:
                    progress(done / total)
        r.close()


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
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("_info.txt", "Warband Keeper %s · %s · %s\n" % (version, why, datetime.now().strftime("%d/%m/%Y %H:%M")))
        for f in files:
            z.write(f, os.path.relpath(f, root))
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
                count = 0
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
    for tmp, dest in staged:
        os.replace(tmp, dest)


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
    def __init__(self, app, parent):
        super().__init__(parent, bg=C["bg"])
        self.app = app
        label(self, self.title, font="h1").pack(anchor="w", pady=(0, 8))

    def on_show(self):
        pass

    def on_state(self):
        """Appelé quand l'état change (versions, dossier, sauvegardes)."""
        pass


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


@page("dash", "Tableau de bord", "▦")
class DashPage(Page):
    """Tiré du résumé que l'addon écrit à la déconnexion : quatre chiffres clés, la courbe de l'or
    (7 / 30 / 90 jours) et « À surveiller », une liste triée par urgence. Tout tient dans la fenêtre fixe."""

    RANGES = [(7, "7 j"), (30, "30 j"), (90, "90 j")]

    def __init__(self, app, parent):
        super().__init__(app, parent)
        # sous-titre à côté du titre de la page
        self.when = label(self, "", fg="dim", font="small")
        self.when.place(in_=self, x=190, y=8)
        self.body = tk.Frame(self, bg=C["bg"])
        self.body.pack(fill="both", expand=True)
        self.key = None

    def on_show(self):
        self.fill(True)

    def on_state(self):
        self.fill()

    def fill(self, force=False):
        dash = read_dash(self.app.addons)
        key = (id(dash), self.app.addons, self.app.cfg.get("dashRange", 30), id(self.app.dataLog), self.app.installed)
        if key == self.key and not force:
            return
        self.key = key
        for w in self.body.winfo_children():
            w.destroy()
        if not isinstance(dash, dict):
            self.when.configure(text="")
            label(self.body, "Rien à montrer pour l'instant : joue un perso avec l'addon 1.69 ou plus récent, puis déconnecte-toi "
                             "(ou /reload) ; le tableau de bord se remplit avec ce que l'addon sait.", fg="muted", wraplength=520).pack(anchor="w")
            return
        now = time.time()
        self.when.configure(text="sauvegarde lue %s · déconnexion de %s" % (ago_text(dash.get("at")), dash.get("char") or "?"))
        gold = [int(v or 0) for v in lua_list(dash.get("gold"))]
        sess = dash.get("session") or {}
        auc = [a for a in lua_list(dash.get("auctions")) if isinstance(a, dict) and (a.get("exp") or 0) > now]
        mail = [m for m in lua_list(dash.get("mail")) if isinstance(m, dict)]
        chars = read_characters(self.app.addons)

        # -- quatre chiffres clés
        kp = tk.Frame(self.body, bg=C["bg"])
        kp.pack(fill="x")
        for i in range(4):
            kp.columnconfigure(i, weight=1, uniform="k")

        def kpi(col, title, value, color, sub, subColor="dim"):
            c = Card(kp)
            c.grid(row=0, column=col, sticky="nsew", padx=(0 if col == 0 else 5, 0 if col == 3 else 5))
            label(c.body, title, fg="muted", font="small").pack(anchor="w")
            label(c.body, value, fg=color, font="h2").pack(anchor="w", pady=(1, 1))
            label(c.body, sub, fg=subColor, font="small").pack(anchor="w")
        cur = gold[-1] if gold else 0
        dv = cur - gold[-8] if len(gold) > 7 else 0
        kpi(0, "Or du compte", money_text(cur), "warning", "%s%s sur 7 jours" % ("+" if dv >= 0 else "-", money_text(abs(dv))),
            "positive" if dv >= 0 else "negative")
        day = dash.get("day") if isinstance(dash.get("day"), dict) else None
        if day is not None:
            # or des dernières 24 h, tous persos, avec ce qui a le plus pesé (journal de l'or de l'addon)
            g = int(day.get("net") or 0)
            by = [b for b in lua_list(day.get("by")) if isinstance(b, dict)]
            if by:
                top = by[0]
                v = int(top.get("v") or 0)
                sub = "surtout %s (%s%s)" % (str(top.get("s") or "?").lower(), "+" if v >= 0 else "-", money_text(abs(v)))
            else:
                sub = "aucun mouvement d'or"
            kpi(1, "Dernières 24 h", ("+" if g >= 0 else "-") + money_text(abs(g)), "positive" if g >= 0 else "negative", sub)
        else:
            # sauvegarde d'un addon sans journal de l'or : écart de l'or du compte sur 24 h (courbe journalière)
            g = (gold[-1] - gold[-2]) if len(gold) > 1 else 0
            kpi(1, "Dernières 24 h", ("+" if g >= 0 else "-") + money_text(abs(g)), "positive" if g >= 0 else "negative",
                "or du compte, d'hier à aujourd'hui")
        soon = [a for a in auc if (a.get("exp") or 0) <= now + 86400]
        kpi(2, "Enchères en vente", str(len(auc)), "text",
            (plural(len(soon), "expire", "expirent") + " sous 24 h") if soon else ("aucune n'expire" if auc else "dernier passage à l'HV"),
            "warning" if soon else "dim")
        letters = sum(int(m.get("count") or 0) for m in mail)
        first = min([m.get("exp") or 0 for m in mail if (m.get("exp") or 0) > now] or [0])
        kpi(3, "Courrier à prendre", plural(letters, "lettre"), "text",
            ("%s · la 1re %s" % (plural(len(mail), "perso"), until_text(first))) if mail else "rien en attente")

        # -- courbe de l'or et « À surveiller »
        low = tk.Frame(self.body, bg=C["bg"])
        low.pack(fill="both", expand=True, pady=(10, 0))
        low.columnconfigure(0, weight=5, uniform="l")
        low.columnconfigure(1, weight=4, uniform="l")
        low.rowconfigure(0, weight=1)
        ch = Card(low, "Or du compte")
        ch.grid(row=0, column=0, sticky="nsew", padx=(0, 5))
        days = self.app.cfg.get("dashRange", 30)
        seg = tk.Frame(ch.head, bg=C["surface"])
        seg.pack(side="right")
        for d, txt in self.RANGES:
            b = label(seg, " %s " % txt, fg="text" if d == days else "muted", font="small", cursor="hand2")
            b.configure(bg=C["surface2"] if d == days else C["surface"])
            b.pack(side="left", padx=2)
            b.bind("<Button-1>", lambda e, d=d: (self.app.cfg.__setitem__("dashRange", d), save_config(self.app.cfg), self.fill(True)))
        pts = gold[-(days + 1):] if gold else []
        cv = tk.Canvas(ch.body, height=150, bg=C["surface"], highlightthickness=0)
        cv.pack(fill="both", expand=True, pady=(4, 6))

        def draw(e, pts=pts, cv=cv):
            cv.delete("all")
            w, h = e.width, e.height
            if len(pts) < 2:
                cv.create_text(w / 2, h / 2, text="Pas encore assez de jours suivis.", fill=C["dim"], font=App.fonts["small"])
                return
            lo, hi = min(pts), max(pts)
            span = max(1, hi - lo)
            for f in (0.15, 0.5, 0.85):
                cv.create_line(0, h * f, w, h * f, fill=C["border"])
            cv.create_text(2, h * 0.15 - 8, text=money_text(hi), fill=C["dim"], font=App.fonts["small"], anchor="w")
            cv.create_text(2, h * 0.85 - 8, text=money_text(lo), fill=C["dim"], font=App.fonts["small"], anchor="w")
            xy = []
            for i, v in enumerate(pts):
                xy += [i * (w - 4) / (len(pts) - 1) + 2, h * 0.85 - (v - lo) / span * h * 0.7]
            cv.create_polygon(*(xy + [w - 2, h, 2, h]), fill="#2a2416", outline="")
            cv.create_line(*xy, fill=C["warning"], width=2, smooth=True)
        cv.bind("<Configure>", draw)
        foot = tk.Frame(ch.body, bg=C["surface"])
        foot.pack(fill="x")
        for k, v in (("Plus haut", money_text(max(pts) if pts else 0)), ("Ventes HV (séance)", money_text(sess.get("ah") or 0)),
                     ("Persos", str(len(chars)))):
            label(foot, k + " ", fg="muted", font="small").pack(side="left")
            label(foot, v, font="smallb").pack(side="left", padx=(0, 14))

        wc = Card(low, "À surveiller", "du plus urgent au moins urgent")
        wc.grid(row=0, column=1, sticky="nsew", padx=(5, 0))
        rows = []  # (rang, couleur du point, texte, droite, couleur de droite)
        for a in soon:
            rows.append((1, C["warning"], "Enchère : %s x%d (%s)" % (a.get("name"), a.get("qty") or 1, a.get("char")), until_text(a.get("exp")), "warning"))
        pend = self.app.pending_data()
        if pend:
            rows.append((1, C["accent"], "Nouvelles données : %s" % data_text(*data_sum(pend)), "à installer", "accent"))
        for m in mail:
            left = (m.get("exp") or 0) - now
            urgent = 0 < left < 3 * 86400
            rows.append((0 if urgent else 3, C["negative"] if urgent else C["warning"],
                         "Courrier de %s (%s)" % (m.get("char"), plural(int(m.get("count") or 0), "lettre")),
                         ("expire " + until_text(m.get("exp"))) if left > 0 else "à prendre", "negative" if urgent else "warning"))
        for x in [x for x in lua_list(dash.get("stash")) if isinstance(x, dict)]:
            rows.append((2, C["accent"], "Rangement : %s de %s pour %s" % (plural(int(x.get("n") or 0), "lot"), x.get("from"), x.get("to")),
                         "à envoyer", "accent"))
        cds = sorted([c for c in lua_list(dash.get("cds")) if isinstance(c, dict)], key=lambda c: c.get("readyAt") or 0)
        for c in cds[:3]:
            ready = (c.get("readyAt") or 0) <= now
            rows.append((2 if ready else 5, C["positive"] if ready else C["muted"], "%s · %s" % (c.get("name"), c.get("char")),
                         "prête" if ready else until_text(c.get("readyAt")), "positive" if ready else "muted"))
        for r in [r for r in lua_list(dash.get("rest")) if isinstance(r, dict) and r.get("full")][:2]:
            rows.append((4, C["positive"], "Repos plein : %s" % r.get("char"), "150 %", "positive"))
        lists = [l for l in lua_list(dash.get("lists")) if isinstance(l, dict)]
        for l in lists[:2]:
            short = int(l.get("short") or 0)
            if short:
                cost = int(l.get("cost") or 0)
                rows.append((6, C["muted"], "Liste « %s » : %s" % (l.get("name"), plural(short, "objet manque", "objets manquent")),
                             ("~ " + money_text(cost)) if cost else "prix inconnu", "muted"))
        q = dash.get("queue") or {}
        if q.get("n"):
            rows.append((6, C["muted"], "File de fabrication : %s" % plural(int(q.get("n") or 0), "recette"),
                         plural(int(q.get("missing") or 0), "composant manquant", "composants manquants"), "muted"))
        if not cds:
            rows.append((9, C["dim"], "Recharges de métier", "aucune suivie", "dim"))
        if not auc:
            rows.append((9, C["dim"], "Enchères", "rien en vente", "dim"))
        rows.sort(key=lambda r: r[0])
        for _, col, txt, right, rcol in rows[:9]:
            row = tk.Frame(wc.body, bg=C["surface"])
            row.pack(fill="x", pady=3)
            dot = tk.Canvas(row, width=10, height=10, bg=C["surface"], highlightthickness=0)
            dot.create_oval(1, 1, 9, 9, fill=col, outline="")
            dot.pack(side="left", padx=(0, 8))
            label(row, right, fg=rcol, font="small").pack(side="right", padx=(8, 0))
            lt = label(row, txt, font="small")
            lt.pack(side="left", fill="x", expand=True)
        if len(rows) > 9:
            label(wc.body, "+ %d de plus" % (len(rows) - 9), fg="dim", font="small").pack(anchor="w", pady=(4, 0))


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


@page("home", "Mises à jour", "⟳")
class HomePage(Page):
    def __init__(self, app, parent):
        super().__init__(app, parent)
        hero = Card(self)
        hero.pack(fill="x")
        b = hero.body
        top = tk.Frame(b, bg=C["surface"])
        top.pack(fill="x")
        left = tk.Frame(top, bg=C["surface"])
        left.pack(side="left", fill="x", expand=True)
        tl = tk.Frame(left, bg=C["surface"])
        tl.pack(anchor="w")
        label(tl, "Warband Keeper", font="h2").pack(side="left")
        label(tl, "  pour WoW Forever", fg="muted", font="small").pack(side="left", pady=(4, 0))
        self.versions = label(left, "", fg="muted")
        self.versions.pack(anchor="w", pady=(2, 8))
        self.chip = Chip(left)
        self.chip.pack(anchor="w")
        right = tk.Frame(top, bg=C["surface"])
        right.pack(side="right")
        self.action = Button(right, "Mettre à jour", self.app.update_addon, "primary", width=190, height=44, font=App.fonts["btnL"])
        self.action.pack(anchor="e")
        # un seul bouton : « Mettre à jour » quand une version attend, sinon « Vérifier maintenant »
        self.picker = tk.Frame(b, bg=C["surface"])
        self.progress = Progress(b)
        self.status = label(b, "", fg="muted", font="small", wraplength=600)
        self.status.pack(anchor="w", fill="x", pady=(10, 0))
        b.bind("<Configure>", lambda e: self.status.configure(wraplength=max(300, e.width - 10)), add="+")

        # Dessous : trois tuiles (sauvegarde, prochaine vérification, dossier). Les nouveautés ont leur page,
        # les persos sont dans le Tableau de bord.
        tiles = tk.Frame(self, bg=C["bg"])
        tiles.pack(fill="x", pady=(12, 0))
        for i in range(3):
            tiles.columnconfigure(i, weight=1, uniform="t")

        def tile(col, title, link, cmd):
            c = Card(tiles)
            c.grid(row=0, column=col, sticky="nsew", padx=(0 if col == 0 else 6, 0 if col == 2 else 6))
            label(c.body, title, fg="dim", font="smallb").pack(anchor="w")
            v = label(c.body, "", font="bodyb")
            v.pack(anchor="w", pady=(2, 2))
            ln = label(c.body, link, fg="accent", font="small", cursor="hand2")
            ln.pack(anchor="w")
            ln.bind("<Button-1>", lambda e: cmd())
            return v
        self.sv = tile(0, "DERNIÈRE SAUVEGARDE", "Sauvegarder maintenant", lambda: self.app.pages["backups"].backup_now())
        self.nextCheck = tile(1, "PROCHAINE VÉRIFICATION", "Changer dans Réglages", lambda: self.app.show_settings("updates"))
        self.folder = tile(2, "DOSSIER DE L'ADDON", "Ouvrir le dossier", self.app.open_addons)

    def update_next(self):
        """Prochaine vérification : recalculée toutes les 20 s (le compte à rebours avance tout seul)."""
        a = self.app
        every = {"1h": 3600, "6h": 6 * 3600}.get(a.cfg["checkEvery"])
        if not every:
            txt = "à la main (Réglages)" if a.cfg["checkEvery"] == "manual" else "au prochain démarrage"
        elif a.busy:
            txt = "en cours…"
        elif not a.lastCheck:
            txt = "bientôt"
        else:
            left = max(0, every - (time.time() - a.lastCheck))
            if left < 60:
                txt = "dans moins d'une minute"
            elif left < 3600:
                txt = "dans %d min" % -(-left // 60)
            else:
                h, m = int(left // 3600), int(left % 3600 // 60)
                txt = "dans %d h %02d" % (h, m)
            txt += " (à %s)" % datetime.fromtimestamp(a.lastCheck + every).strftime("%H:%M")
        self.nextCheck.configure(text=txt)
        if getattr(self, "_nextJob", None):
            self.after_cancel(self._nextJob)
        self._nextJob = self.after(20000, self.update_next)

    def set_busy(self, text, value=None):
        if value is None:
            self.progress.pack_forget()
        else:
            if not self.progress.winfo_ismapped():
                self.progress.pack(fill="x", pady=(12, 0), before=self.status)
            self.progress.set(value)
        self.status.configure(text=text)

    def build_picker(self):
        a = self.app
        for w in self.picker.winfo_children():
            w.destroy()
        if a.addons:
            self.picker.pack_forget()
            return
        self.picker.pack(fill="x", pady=(12, 0), before=self.status)
        for inst in a.installs[:6]:
            row = tk.Frame(self.picker, bg=C["surface2"])
            row.pack(fill="x", pady=2)
            inner = tk.Frame(row, bg=C["surface2"])
            inner.pack(fill="x", padx=10, pady=6)
            Button(inner, "Installer ici", lambda i=inst: a.choose_install(i), "primary" if inst["forever"] else "secondary", height=28).pack(side="right")
            label(inner, inst["label"], fg="accent" if inst["forever"] else "text", font="bodyb").pack(side="left")
            label(inner, "   " + short_path(os.path.dirname(os.path.dirname(inst["addons"]))), fg="muted", font="small").pack(side="left")
        other = tk.Frame(self.picker, bg=C["surface"])
        other.pack(fill="x", pady=(6, 0))
        Button(other, "Autre dossier…", a.browse_addons, "ghost", height=28).pack(side="left")
        label(other, "  le dossier du jeu, ou son Interface\\AddOns", fg="dim", font="small").pack(side="left")

    def on_state(self):
        a = self.app
        inst, latest = a.installed, a.latest_version
        self.build_picker()
        if not a.addons:
            n = len(a.installs)
            self.versions.configure(text=("%d installations de WoW Forever trouvées : choisis la tienne." % n) if n > 1 else
                                    "WoW Forever introuvable automatiquement : indique son dossier.")
            self.chip.set("Où installer Warband Keeper ?", C["warning"])
            self.action.set("Rechercher", True, "secondary")
            self.action.command = a.rescan
        elif a.error and not latest:
            self.versions.configure(text="Installée : %s" % (inst or "non installée"))
            self.chip.set(a.error, C["negative"])
            if "jeton" in a.error:
                self.action.set("Ajouter le jeton", True, "secondary")
                self.action.command = lambda: a.show_settings("github")
            else:
                self.action.set("Réessayer", True, "secondary")
                self.action.command = a.refresh
        elif latest is None:
            self.versions.configure(text="Installée : %s" % (inst or "non installée"))
            self.chip.set("Recherche des versions…", C["muted"])
            self.action.set("Vérification…", False, "secondary")
        elif not inst:
            self.versions.configure(text="Pas encore installé dans %s · dernière version %s" % (flavor_label(a.addons), latest))
            self.chip.set("Prêt à installer", C["accent"])
            self.action.set("Installer", not a.busy, "primary")
            self.action.command = a.update_addon
        # même version que la dernière Release seulement : sur une version plus récente (de développement),
        # « Réparer » aurait installé une version plus ancienne
        elif data_missing(a.addons, inst) and vtuple(inst) == vtuple(latest):
            # même version, mais le dossier des données à la demande manque : réinstaller la répare
            self.versions.configure(text="Installée : %s (dossier WarbandKeeper_Data manquant)" % inst)
            self.chip.set("À réparer : dossier des données manquant", C["warning"])
            self.action.set("Réparer", not a.busy, "alert")
            self.action.command = a.update_addon
        elif vtuple(inst) < vtuple(latest):
            self.versions.configure(text="Installée : %s   »   disponible : %s" % (inst, latest))
            n = len(a.newer())
            self.chip.set("%d nouvelle%s version%s" % (n, "s" if n > 1 else "", "s" if n > 1 else ""), C["negative"])
            self.action.set("Mettre à jour", not a.busy, "alert")
            self.action.command = a.update_addon
        else:
            self.versions.configure(text="Installée : %s" % inst)
            last = getattr(a, "lastInstall", None)
            # consigne seulement si le jeu tournait à l'installation et tourne encore
            live = last and last[0] == inst and last[1] is not None and game_running()
            if live and last[1]:
                self.chip.set("À jour · redémarre complètement le jeu", C["warning"])
            elif live:
                self.chip.set("À jour · un /reload suffit", C["positive"])
            else:
                self.chip.set("À jour", C["positive"])
            self.action.set("Vérifier maintenant", not a.busy, "secondary")
            self.action.command = a.refresh
        last = list_backups()
        self.sv.configure(text=datetime.fromtimestamp(last[0]["time"]).strftime("le %d/%m à %H:%M") if last else "aucune pour l'instant")
        self.update_next()
        self.folder.configure(text=short_path(game_dir(a.addons), 34) if a.addons else "pas choisi")



@page("notes", "Nouveautés", "✦")
class NotesPage(Page):
    def __init__(self, app, parent):
        super().__init__(app, parent)
        self.tab = "addon"
        self.seg = Segmented(self, [("addon", "Addon"), ("client", "Client PC")], lambda: self.tab, self.set_tab)
        self.seg.pack(anchor="w", pady=(0, 10))
        c = Card(self)
        c.pack(fill="both", expand=True)
        self.sub = label(c.body, "", fg="muted", font="small")
        self.sub.pack(anchor="w", pady=(0, 6))
        wrap, self.txt = notes_view(c.body, 20)
        wrap.pack(fill="both", expand=True)

    def set_tab(self, t):
        self.tab = t
        self.on_state()

    def on_state(self):
        self.seg.refresh()
        if self.tab == "client":
            self.sub.configure(text="Notes du client PC (installé : %s)" % CLIENT_VERSION)
            fill_notes(self.txt, parse_client_notes(self.app.clientNotes or bundled_client_notes()),
                       "Pas de notes du client pour l'instant.")
        else:
            self.sub.configure(text="Notes de l'addon, version par version (publiées sur GitHub)")
            fill_notes(self.txt, self.app.releases, "Aucune version trouvée pour l'instant.")


@page("backups", "Sauvegardes", "⟲")
class BackupsPage(Page):
    def __init__(self, app, parent):
        super().__init__(app, parent)
        c = Card(self, "Tes réglages", "persos, listes, envies… (SavedVariables de l'addon)")
        c.pack(fill="both", expand=True)
        bar = tk.Frame(c.body, bg=C["surface"])
        bar.pack(fill="x", pady=(0, 8))
        Button(bar, "Sauvegarder", self.backup_now, "secondary", height=30).pack(side="right")
        label(bar, "Sauvegardés avant chaque mise à jour. Restaurer : jeu fermé.", fg="muted", font="small").pack(side="left")
        self.list = tk.Frame(c.body, bg=C["surface"])
        self.list.pack(fill="both", expand=True)

        p = Card(self, "Version précédente de l'addon", "si une mise à jour pose problème")
        p.pack(fill="x", pady=(12, 0))
        row = tk.Frame(p.body, bg=C["surface"])
        row.pack(fill="x")
        self.prev = label(row, "", fg="muted")
        self.prev.pack(side="left")
        self.prevBtn = Button(row, "Revenir à cette version", self.rollback, "secondary", height=30)
        self.prevBtn.pack(side="right")

    def backup_now(self):
        a = self.app
        if not a.addons:
            return a.toast("Choisis d'abord le dossier AddOns dans Réglages.", "warning")
        p = backup_saved_variables(a.addons, a.installed, a.cfg["keepBackups"], "manuelle")
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
        try:
            backup_saved_variables(a.addons, a.installed, a.cfg["keepBackups"] + 1, "avant restauration")
            restore_backup(a.addons, b["path"])
        except Exception as e:  # zip tronqué (zlib, EOFError), fichier bloqué… : toujours un message
            a.toast("Restauration impossible : %s (rien n'a été changé)." % e, "negative")
            return
        a.toast("Sauvegarde restaurée.", "positive")
        a.state_changed()

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

    def on_state(self):
        for w in self.list.winfo_children():
            w.destroy()
        items = list_backups()
        if not items:
            label(self.list, "Aucune sauvegarde pour l'instant.", fg="dim").pack(anchor="w", pady=6)
        for b in items[:12]:
            row = tk.Frame(self.list, bg=C["surface2"])
            row.pack(fill="x", pady=2)
            inner = tk.Frame(row, bg=C["surface2"])
            inner.pack(fill="x", padx=10, pady=6)
            label(inner, datetime.fromtimestamp(b["time"]).strftime("%d/%m/%Y  %H:%M"), font="bodyb").pack(side="left")
            parts = [x.strip() for x in b["info"].split("·")] if b["info"] else []
            desc = ("v" + parts[0].replace("Warband Keeper ", "") + "  ·  " + parts[1]) if len(parts) >= 2 else b["name"]
            label(inner, "   " + desc, fg="muted", font="small").pack(side="left")
            Button(inner, "Restaurer", lambda b=b: self.restore(b), "ghost", height=26).pack(side="right")
        prev = previous_versions()
        if prev:
            self.prev.configure(text="Warband Keeper %s, gardée le %s" % (prev[0]["version"], datetime.fromtimestamp(prev[0]["time"]).strftime("%d/%m/%Y")))
            self.prevBtn.set(enabled=bool(self.app.addons) and not self.app.busy)
        else:
            self.prev.configure(text="Aucune : elle est gardée à la prochaine mise à jour.")
            self.prevBtn.set(enabled=False)


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

        t = Card(tab["github"], "Accès à GitHub", "dépôt privé : jeton fine-grained")
        t.pack(fill="x")
        label(t.body, "Limité au dépôt WarbandKeeper. Pour installer l'addon : Contents « Read-only ».\n"
                      "Pour régler les données (onglet Données) : Contents et Actions « Read and write ». Gardé seulement sur ce PC.",
              fg="muted", font="small").pack(anchor="w")
        row2 = tk.Frame(t.body, bg=C["surface"])
        row2.pack(fill="x", pady=(8, 0))
        self.token = tk.StringVar(value=cfg["token"])
        te = tk.Entry(row2, textvariable=self.token, show="•", bg=C["surface2"], fg=C["text"], insertbackground=C["text"], bd=0,
                      highlightthickness=1, highlightbackground=C["border"], highlightcolor=C["accent"], font=App.fonts["body"])
        te.pack(side="left", fill="x", expand=True, ipady=7, padx=(0, 8))
        Button(row2, "Enregistrer", self.save_token, "secondary", height=34).pack(side="left")
        Button(row2, "Créer un jeton", lambda: webbrowser.open(TOKEN_URL), "ghost", height=34).pack(side="left", padx=(6, 0))

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
        self.show("dash" if read_dash(self.cfg["addons"]) else "home")
        self.state_changed()
        self.root.after(80, self.poll)
        if self.cfg["checkEvery"] != "manual":
            self.refresh()
        self.root.after(60000, self.tick)

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
        dash = read_dash(self.addons)
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

    def build(self):
        side = tk.Frame(self.root, bg=C["sidebar"], width=220)
        side.pack(side="left", fill="y")
        side.pack_propagate(False)
        self.side = side
        brand = tk.Frame(side, bg=C["sidebar"])
        self.brand = brand
        brand.pack(fill="x", padx=14, pady=(18, 22))
        if self.logoSmall:
            tk.Label(brand, image=self.logoSmall, bg=C["sidebar"]).pack(side="left", padx=(0, 8))
        tb = tk.Frame(brand, bg=C["sidebar"])
        tb.pack(side="left")
        tk.Label(tb, text="Warband Keeper", bg=C["sidebar"], fg=C["accent"], font=App.fonts["h3"]).pack(anchor="w")
        tk.Label(tb, text="Client " + CLIENT_VERSION, bg=C["sidebar"], fg=C["dim"], font=App.fonts["small"]).pack(anchor="w")
        self.nav = {}
        # ordre de la barre latérale (les pages sont déclarées dans un autre ordre)
        order = ["dash", "home", "notes", "backups", "settings"]
        PAGES.sort(key=lambda c: order.index(c.key) if c.key in order else 99)
        for cls in PAGES:
            b = tk.Label(side, text="  %s   %s" % (cls.icon, cls.title), bg=C["sidebar"], fg=C["muted"], font=App.fonts["nav"],
                         anchor="w", padx=14, pady=9, cursor="hand2")
            b.pack(fill="x", padx=10, pady=1)
            b.bind("<Button-1>", lambda e, k=cls.key: self.show(k))
            b.bind("<Enter>", lambda e, b=b, k=cls.key: b.configure(bg=C["hover"] if k != self.current else C["surface2"]))
            b.bind("<Leave>", lambda e, b=b, k=cls.key: b.configure(bg=C["surface2"] if k == self.current else C["sidebar"]))
            self.nav[cls.key] = b
        # pastille sur « Mises à jour » : nombre de versions à installer (ou « client » pour le client seul)
        # (sœur de l'entrée, posée par-dessus : redessiner l'entrée au survol ne l'efface plus)
        self.navBadge = tk.Label(side, text="", bg=C["negative"], fg="#ffffff", font=App.fonts["smallb"], padx=6, pady=0, cursor="hand2")
        self.navBadge.bind("<Button-1>", lambda e: self.show("home"))
        for ev in ("<Enter>", "<Leave>", "<Button-1>"):
            self.nav["home"].bind(ev, lambda e: self.root.after_idle(self.navBadge.lift), add="+")
        self.clientBanner = tk.Frame(side, bg=C["sidebar"])
        self.clientBanner.pack(side="bottom", fill="x", padx=12, pady=12)

        main = tk.Frame(self.root, bg=C["bg"])
        main.pack(side="left", fill="both", expand=True, padx=22, pady=(14, 14))
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
        strip.place(x=220, y=0, relwidth=1.0, width=-(220 + 100))
        drag = {}

        def start(e):
            drag["x"], drag["y"] = e.x_root - root.winfo_x(), e.y_root - root.winfo_y()

        def move(e):
            if self.maxed or "x" not in drag:
                return
            root.geometry("+%d+%d" % (e.x_root - drag["x"], e.y_root - drag["y"]))
        for wdg in (strip, self.side, self.brand) + tuple(self.brand.winfo_children()):
            wdg.bind("<ButtonPress-1>", start, add="+")
            wdg.bind("<B1-Motion>", move, add="+")
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
        for k, p in self.pages.items():
            if k == key:
                p.pack(fill="both", expand=True)
                p.on_show()
            else:
                p.pack_forget()
        for k, b in self.nav.items():
            b.configure(bg=C["surface2"] if k == key else C["sidebar"], fg=C["text"] if k == key else C["muted"])

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
        for r in self.releases:
            if addon_asset(r):
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
        return [r for r in self.releases if vtuple(r["tag_name"]) > vtuple(inst)]

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
        text = str(n) if n else ("client" if client else "")
        if text:
            self.navBadge.configure(text=text)
            self.navBadge.place(in_=self.nav["home"], relx=1.0, rely=0.5, x=-10, anchor="e")
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
        for w in self.clientBanner.winfo_children():
            w.destroy()
        asset, ver = best_client(self.releases)
        if not (asset and vtuple(ver) > vtuple(CLIENT_VERSION)):
            return
        box = tk.Frame(self.clientBanner, bg=C["surface2"])
        box.pack(fill="x")
        tk.Label(box, text="Client %s disponible" % ver, bg=C["surface2"], fg=C["accent"], font=App.fonts["smallb"]).pack(anchor="w", padx=10, pady=(8, 2))
        see = tk.Label(box, text="Voir les nouveautés", bg=C["surface2"], fg=C["muted"], font=App.fonts["small"], cursor="hand2")
        see.pack(anchor="w", padx=10)
        see.bind("<Button-1>", lambda e: (setattr(self.pages["notes"], "tab", "client"), self.show("notes"), self.pages["notes"].on_state()))
        if FROZEN and IS_WIN:
            Button(box, "Mettre à jour le client", lambda: self.update_client(asset), "primary", height=30).pack(fill="x", padx=10, pady=(4, 10))
        else:
            tk.Label(box, text="À télécharger sur GitHub, page Releases.", bg=C["surface2"], fg=C["muted"], font=App.fonts["small"],
                     wraplength=170, justify="left").pack(anchor="w", padx=10, pady=(0, 8))

    def update_client(self, asset):
        dest = sys.executable + ".new"
        self.toast("Téléchargement du client…")

        def done(_, err):
            if err:
                return self.toast("Échec du téléchargement du client.", "negative")
            self_update(dest)
            self.root.destroy()
        self.run(lambda: GitHub(self.cfg["token"]).download(asset, dest), done)

    def mainloop(self):
        self.root.mainloop()


if __name__ == "__main__":
    App().mainloop()
