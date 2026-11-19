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

CLIENT_VERSION = "1.5.0"
REPO = "sebastien1100-dev/WarbandKeeper"
ADDON = "WarbandKeeper"
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
            "startup": False}
RUN_KEY = r"Software\Microsoft\Windows\CurrentVersion\Run"
RUN_NAME = "WarbandKeeperClient"
SCHEDULE_PATH = "tools/update_schedule.json"
DATA_WORKFLOW = "update-data.yml"


def load_config():
    cfg = dict(DEFAULTS)
    try:
        with open(CONFIG_PATH, encoding="utf-8") as f:
            cfg.update(json.load(f))
    except (OSError, ValueError):
        pass
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
    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=1)


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


def installed_version(addons):
    try:
        with open(os.path.join(addons, ADDON, ADDON + ".toc"), encoding="utf-8", errors="replace") as f:
            m = re.search(r"^## Version:\s*(\S+)", f.read(), re.M)
            return m.group(1) if m else "?"
    except OSError:
        return None


def game_dir(addons):
    return os.path.dirname(os.path.dirname(addons))


def saved_variables(addons):
    """Fichiers de réglages de l'addon : WTF/Account/*/SavedVariables/WarbandKeeper.lua (+ .bak)."""
    out = []
    wtf = os.path.join(game_dir(addons), "WTF", "Account")
    if os.path.isdir(wtf):
        for acc in os.listdir(wtf):
            sv = os.path.join(wtf, acc, "SavedVariables")
            for n in (ADDON + ".lua", ADDON + ".lua.bak"):
                p = os.path.join(sv, n)
                if os.path.isfile(p):
                    out.append(p)
    return out


# --- Lecture des réglages de l'addon (hors du jeu) : persos du compte -------------------------------
_LUA_TOKEN = re.compile(r'\s+|--\[\[.*?\]\]|--[^\n]*|"(?:\\.|[^"\\])*"|-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?|[A-Za-z_][A-Za-z0-9_]*|[{}\[\]=,;]', re.S)


def _lua_tokens(text, start):
    pos, n = start, len(text)
    while pos < n:
        m = _LUA_TOKEN.match(text, pos)
        if not m:
            pos += 1
            continue
        tok = m.group(0)
        pos = m.end()
        if tok[0].isspace() or tok.startswith("--"):
            continue
        yield tok


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
            else:
                nxt = next(it)
                if nxt == "=":
                    out[t] = _lua_value(it, next(it))
                else:
                    out[arr] = _lua_value(it, t); arr += 1
                    if nxt == "}":
                        return out
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
        i = text.find('["characters"] = {')
        if i >= 0:
            it = _lua_tokens(text, text.index("{", i))
            chars = _lua_value(it, next(it))
            for key, c in (chars or {}).items():
                if isinstance(c, dict):
                    name = c.get("mailName") or c.get("fullName") or c.get("name") or str(key).split("-")[0].strip()
                    out.append({"name": name, "cls": c.get("class") or "", "level": c.get("level") or 0,
                                "money": c.get("money") or 0, "seen": c.get("lastSeen") or 0})
    except Exception:
        out = []
    out.sort(key=lambda e: -(e["seen"] or 0))
    _chars_cache.update(path=path, mt=mt, list=out)
    return out


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


def game_running():
    if not IS_WIN:
        return False
    try:
        out = subprocess.run(["tasklist", "/FO", "CSV", "/NH"], capture_output=True, text=True,
                             creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0)).stdout.lower()
        return any(l.startswith('"wow') for l in out.splitlines())
    except OSError:
        return False


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
    files = saved_variables(addons)
    if not files:
        return None
    root = game_dir(addons)
    name = "Reglages-%s-v%s.zip" % (datetime.now().strftime("%Y-%m-%d_%H-%M-%S"), version or "inconnue")
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
    root = game_dir(addons)
    with zipfile.ZipFile(path) as z:
        for n in z.namelist():
            if n.startswith("_") or not n.endswith((".lua", ".bak")):
                continue
            dest = os.path.normpath(os.path.join(root, n))
            if not dest.startswith(os.path.normpath(root)):
                continue
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            with z.open(n) as src, open(dest, "wb") as out:
                shutil.copyfileobj(src, out)


def safe_extract(zpath, dest_parent):
    with zipfile.ZipFile(zpath) as z:
        names = z.namelist()
        if not any(n == ADDON + "/" + ADDON + ".toc" for n in names):
            raise RuntimeError("Le fichier téléchargé n'est pas l'addon Warband Keeper.")
        base = os.path.normpath(dest_parent)
        for n in names:
            if not n.startswith(ADDON + "/"):
                continue
            target = os.path.normpath(os.path.join(base, n))
            if not target.startswith(base + os.sep):
                raise RuntimeError("Archive invalide.")
        z.extractall(base, [n for n in names if n.startswith(ADDON + "/")])


def _files(folder):
    out = set()
    for d, _, fs in os.walk(folder):
        for f in fs:
            out.add(os.path.relpath(os.path.join(d, f), folder).replace(os.sep, "/").lower())
    return out


def _toc_body(folder):
    """Le .toc sans sa ligne ## Version (le reste change la liste des fichiers chargés)."""
    try:
        with open(os.path.join(folder, ADDON + ".toc"), encoding="utf-8", errors="replace") as f:
            return "\n".join(l.rstrip() for l in f if not l.startswith("## Version"))
    except OSError:
        return None


def install_zip(addons, zpath, old_version):
    """Installe le zip ; rend True s'il faut redémarrer complètement le jeu (nouveaux fichiers ou .toc
    modifié : le jeu ne les charge qu'au lancement), False si un /reload suffit."""
    target = os.path.join(addons, ADDON)
    moved = None
    oldFiles = _files(target) if os.path.isdir(target) else None
    oldToc = _toc_body(target) if os.path.isdir(target) else None
    if os.path.isdir(target):
        moved = os.path.join(previous_dir(), "%s-%s" % (ADDON, old_version or "inconnue"))
        if os.path.exists(moved):
            shutil.rmtree(moved, ignore_errors=True)
        shutil.move(target, moved)
        # on ne garde que les 2 dernières versions
        olds = sorted((os.path.join(previous_dir(), d) for d in os.listdir(previous_dir())), key=os.path.getmtime, reverse=True)
        for d in olds[2:]:
            shutil.rmtree(d, ignore_errors=True)
    try:
        safe_extract(zpath, addons)
    except Exception:
        if moved and not os.path.isdir(target):
            shutil.move(moved, target)
        raise
    if oldFiles is None:
        return True  # première installation : le jeu doit être lancé (ou relancé) pour la voir
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
        if os.path.isdir(p):
            out.append({"path": p, "version": d.split("-", 1)[-1], "time": os.path.getmtime(p)})
    out.sort(key=lambda x: x["time"], reverse=True)
    return out


def rollback(addons, prev):
    target = os.path.join(addons, ADDON)
    cur = installed_version(addons)
    tmp = None
    if os.path.isdir(target):
        tmp = os.path.join(previous_dir(), "%s-%s" % (ADDON, cur or "inconnue"))
        if os.path.exists(tmp) and os.path.normpath(tmp) != os.path.normpath(prev["path"]):
            shutil.rmtree(tmp, ignore_errors=True)
        if os.path.normpath(tmp) == os.path.normpath(prev["path"]):
            tmp = tmp + "-courante"
        shutil.move(target, tmp)
    shutil.move(prev["path"], target)


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
    with open(bat, "w", encoding="mbcs" if IS_WIN else "utf-8") as f:
        f.write('@echo off\r\n:wait\r\ntimeout /t 1 /nobreak >nul\r\n'
                'move /y "%s" "%s" >nul 2>&1 || goto wait\r\n'
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


class ScrollArea(tk.Frame):
    """Contenu qui défile (molette) : on remplit self.inner."""

    def __init__(self, parent):
        super().__init__(parent, bg=C["bg"])
        self.cv = tk.Canvas(self, bg=C["bg"], highlightthickness=0, bd=0)
        self.sb = tk.Scrollbar(self, command=self.cv.yview, bg=C["bg"], troughcolor=C["bg"], bd=0,
                               activebackground=C["hover"], highlightthickness=0, width=10, elementborderwidth=0)
        self.inner = tk.Frame(self.cv, bg=C["bg"])
        self.win = self.cv.create_window(0, 0, window=self.inner, anchor="nw")
        self.cv.configure(yscrollcommand=self.sb.set)
        self.cv.pack(side="left", fill="both", expand=True)
        self.sb.pack(side="right", fill="y")
        self.inner.bind("<Configure>", lambda e: self.cv.configure(scrollregion=self.cv.bbox("all")))
        self.cv.bind("<Configure>", lambda e: self.cv.itemconfigure(self.win, width=e.width - 4))
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
        label(self, self.title, font="h1").pack(anchor="w", pady=(0, 12))

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
    sb = tk.Scrollbar(wrap, command=txt.yview, bg=C["surface"], troughcolor=C["surface"], bd=0,
                      activebackground=C["hover"], highlightthickness=0, width=10, elementborderwidth=0)
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


@page("home", "Accueil", "⌂")
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
        self.check = Button(right, "Vérifier maintenant", self.app.refresh, "secondary", width=190, height=34)
        self.check.pack(anchor="e", pady=(8, 0))
        self.picker = tk.Frame(b, bg=C["surface"])
        self.progress = Progress(b)
        self.status = label(b, "", fg="muted", font="small", wraplength=600)
        self.status.pack(anchor="w", fill="x", pady=(10, 0))
        b.bind("<Configure>", lambda e: self.status.configure(wraplength=max(300, e.width - 10)), add="+")

        # (les nouveautés sont dans leur page, plus sur l'accueil)
        # Dessous : tes persos (lus dans tes réglages) à gauche ; sauvegarde, vérification et raccourcis à droite
        low = tk.Frame(self, bg=C["bg"])
        low.pack(fill="both", expand=True, pady=(12, 0))
        side = tk.Frame(low, bg=C["bg"], width=210)
        side.pack(side="right", fill="y", padx=(12, 0))
        side.pack_propagate(False)
        pc = Card(low, "Tes persos")
        pc.pack(side="left", fill="both", expand=True)
        self.persos = pc.body
        sc = Card(side)
        sc.pack(fill="x")
        label(sc.body, "SAUVEGARDE", fg="dim", font="smallb").pack(anchor="w")
        self.sv = label(sc.body, "", font="body")
        self.sv.pack(anchor="w", pady=(2, 2))
        save = label(sc.body, "Sauvegarder maintenant", fg="accent", font="small", cursor="hand2")
        save.pack(anchor="w")
        save.bind("<Button-1>", lambda e: self.app.pages["backups"].backup_now())
        vc = Card(side)
        vc.pack(fill="x", pady=(8, 0))
        label(vc.body, "PROCHAINE VÉRIFICATION", fg="dim", font="smallb").pack(anchor="w")
        self.nextCheck = label(vc.body, "", font="body")
        self.nextCheck.pack(anchor="w", pady=(2, 0))
        self.launch = Button(side, "▶  Lancer WoW Forever", self.launch_game, "secondary", width=210, height=32)
        self.launch.pack(fill="x", pady=(8, 0))
        Button(side, "Dossier AddOns", self.app.open_addons, "secondary", width=210, height=32).pack(fill="x", pady=(6, 0))

    def launch_game(self):
        exe = game_exe(self.app.addons) if self.app.addons else None
        if not exe:
            return self.app.toast("Jeu introuvable à côté du dossier AddOns.", "warning")
        try:
            if IS_WIN:
                os.startfile(exe)
            else:
                subprocess.Popen([exe])
            self.app.toast("Lancement de WoW Forever…", "positive")
        except OSError as e:
            self.app.toast("Impossible de lancer le jeu : %s" % e, "negative")

    def fill_persos(self):
        for w in self.persos.winfo_children():
            w.destroy()
        chars = read_characters(self.app.addons) if self.app.addons else []
        if not chars:
            label(self.persos, "Lance le jeu une fois avec l'addon : tes persos apparaîtront ici.", fg="muted", font="small",
                  wraplength=320).pack(anchor="w")
            return
        total = sum(int(c["money"] or 0) for c in chars)
        label(self.persos, "%d perso%s · %s au total" % (len(chars), "s" if len(chars) > 1 else "", money_text(total)),
              fg="muted", font="small").pack(anchor="w", pady=(0, 4))
        for c in chars[:8]:
            row = tk.Frame(self.persos, bg=C["surface"])
            row.pack(fill="x", pady=1)
            dot = tk.Canvas(row, width=10, height=10, bg=C["surface"], highlightthickness=0)
            dot.create_oval(1, 1, 9, 9, fill=CLASS_COLORS.get(c["cls"], C["muted"]), outline="")
            dot.pack(side="left", padx=(0, 6))
            label(row, c["name"], font="body").pack(side="left")
            label(row, "  %s" % (c["level"] or "?"), fg="dim", font="small").pack(side="left")
            label(row, ago_text(c["seen"]), fg="dim", font="small").pack(side="right")
            label(row, money_text(c["money"]) + "   ", fg="muted", font="small").pack(side="right")

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
                self.action.command = lambda: a.show("settings")
            else:
                self.action.set("Réessayer", True, "secondary")
                self.action.command = a.refresh
        elif latest is None:
            self.versions.configure(text="Installée : %s" % (inst or "non installée"))
            self.chip.set("Recherche des versions…", C["muted"])
            self.action.set("Mettre à jour", False, "primary")
        elif not inst:
            self.versions.configure(text="Pas encore installé dans %s · dernière version %s" % (flavor_label(a.addons), latest))
            self.chip.set("Prêt à installer", C["accent"])
            self.action.set("Installer", not a.busy, "primary")
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
            if last and last[0] == inst and last[1]:
                self.chip.set("À jour · redémarre complètement le jeu", C["warning"])
            elif last and last[0] == inst:
                self.chip.set("À jour · un /reload suffit", C["positive"])
            else:
                self.chip.set("À jour", C["positive"])
            self.action.set("✓  À jour", False, "ok")
        last = list_backups()
        self.sv.configure(text=datetime.fromtimestamp(last[0]["time"]).strftime("le %d/%m à %H:%M") if last else "aucune pour l'instant")
        every = {"1h": 3600, "6h": 6 * 3600}.get(a.cfg["checkEvery"])
        if not every:
            self.nextCheck.configure(text="à la main (Réglages)")
        elif not a.lastCheck:
            self.nextCheck.configure(text="bientôt")
        else:
            left = max(0, every - (time.time() - a.lastCheck))
            self.nextCheck.configure(text="dans %d min" % (left // 60 + 1) if left < 3600 else "dans %d h" % (left // 3600 + 1))
        self.launch.set(enabled=bool(a.addons and game_exe(a.addons)))
        self.fill_persos()


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
        backup_saved_variables(a.addons, a.installed, a.cfg["keepBackups"] + 1, "avant restauration")
        restore_backup(a.addons, b["path"])
        a.toast("Sauvegarde restaurée.", "positive")
        a.state_changed()

    def rollback(self):
        a = self.app
        prev = previous_versions()
        if not (a.addons and prev):
            return
        if not a.confirm("Remettre Warband Keeper %s ?" % prev[0]["version"]):
            return
        try:
            rollback(a.addons, prev[0])
            a.toast("Version %s remise. Redémarre le jeu." % prev[0]["version"], "positive")
        except OSError as e:
            a.toast("Impossible : %s" % e, "negative")
        a.state_changed()

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
            self.prevBtn.set(enabled=bool(self.app.addons))
        else:
            self.prev.configure(text="Aucune : elle est gardée à la prochaine mise à jour.")
            self.prevBtn.set(enabled=False)


@page("settings", "Réglages", "⚙")
class SettingsPage(Page):
    def __init__(self, app, parent):
        super().__init__(app, parent)
        cfg = app.cfg
        area = ScrollArea(self)
        area.pack(fill="both", expand=True)
        host = area.inner
        g = Card(host, "Dossier de l'addon", "Interface\\AddOns de WoW Forever")
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

        t = Card(host, "Accès à GitHub", "dépôt privé : jeton fine-grained")
        t.pack(fill="x", pady=(12, 0))
        label(t.body, "Limité au dépôt WarbandKeeper. Pour installer l'addon : Contents « Read-only ».\n"
                      "Pour régler les données (plus bas) : Contents et Actions « Read and write ». Gardé seulement sur ce PC.",
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
        u = Card(host, "Mises à jour", "de l'addon, sur ce PC")
        u.pack(fill="x", pady=(12, 0))
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
        d = Card(host, "Données", "QuestieDB et wowtbc.gg, vérifiées sur GitHub")
        d.pack(fill="x", pady=(12, 0))
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

    def on_show(self):
        if not self.loaded:
            self.load_schedule()

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
        when = (run.get("run_started_at") or run.get("created_at") or "")[:16].replace("T", " à ")
        if when:
            dt = when.split(" à ")
            when = "/".join(reversed(dt[0].split("-"))) + " à " + dt[1] + " (UTC)"
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
        self.root.geometry("780x480")
        self.root.minsize(680, 420)
        self.setup_fonts()
        self.set_icon()
        self.cfg = load_config()
        self.releases, self.error, self.busy = [], None, False
        self.clientNotes, self.lastCheck, self.notified = None, 0, None
        self.q = queue.Queue()
        self.installs = []
        if not self.cfg["addons"] or not os.path.isdir(self.cfg["addons"]):
            self.installs = find_forever()
            pick = self.auto_pick(self.installs)
            self.cfg["addons"] = use_install(pick) if pick else ""
            save_config(self.cfg)
        self.build()
        if "--minimized" in sys.argv:
            self.root.iconify()  # lancé avec Windows : réduit, il vérifie en arrière-plan
        self.show("home")
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
        self.root.after(60000, self.tick)

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
        brand = tk.Frame(side, bg=C["sidebar"])
        brand.pack(fill="x", padx=14, pady=(18, 22))
        if self.logoSmall:
            tk.Label(brand, image=self.logoSmall, bg=C["sidebar"]).pack(side="left", padx=(0, 8))
        tb = tk.Frame(brand, bg=C["sidebar"])
        tb.pack(side="left")
        tk.Label(tb, text="Warband Keeper", bg=C["sidebar"], fg=C["accent"], font=App.fonts["h3"]).pack(anchor="w")
        tk.Label(tb, text="Client " + CLIENT_VERSION, bg=C["sidebar"], fg=C["dim"], font=App.fonts["small"]).pack(anchor="w")
        self.nav = {}
        for cls in PAGES:
            b = tk.Label(side, text="  %s   %s" % (cls.icon, cls.title), bg=C["sidebar"], fg=C["muted"], font=App.fonts["nav"],
                         anchor="w", padx=14, pady=9, cursor="hand2")
            b.pack(fill="x", padx=10, pady=1)
            b.bind("<Button-1>", lambda e, k=cls.key: self.show(k))
            b.bind("<Enter>", lambda e, b=b, k=cls.key: b.configure(bg=C["hover"] if k != self.current else C["surface2"]))
            b.bind("<Leave>", lambda e, b=b, k=cls.key: b.configure(bg=C["surface2"] if k == self.current else C["sidebar"]))
            self.nav[cls.key] = b
        self.clientBanner = tk.Frame(side, bg=C["sidebar"])
        self.clientBanner.pack(side="bottom", fill="x", padx=12, pady=12)

        main = tk.Frame(self.root, bg=C["bg"])
        main.pack(side="left", fill="both", expand=True, padx=22, pady=18)
        self.pages = {}
        for cls in PAGES:
            p = cls(self, main)
            self.pages[cls.key] = p
        self.toastBar = tk.Label(self.root, text="", bg=C["surface2"], fg=C["text"], font=App.fonts["body"], padx=14, pady=8)
        self.current = None

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

    def toast(self, text, kind="muted"):
        self.toastBar.configure(text=text, fg=C.get(kind, C["text"]))
        self.toastBar.place(relx=0.5, rely=1.0, y=-18, anchor="s")
        self.toastBar.lift()
        if getattr(self, "_toastJob", None):
            self.root.after_cancel(self._toastJob)
        self._toastJob = self.root.after(4200, self.toastBar.place_forget)

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

    def open_addons(self):
        if self.addons:
            open_folder(self.addons)
        else:
            self.show("settings")

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
        try:
            while True:
                kind, fn, res, err = self.q.get_nowait()
                if kind == "call":
                    fn(*res)
                elif fn:
                    fn(res, err)
        except queue.Empty:
            pass
        self.root.after(80, self.poll)

    def refresh(self):
        home = self.pages["home"]
        home.set_busy("Recherche des versions sur GitHub…")
        self.error = None

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
            return rels, notes

        def done(res, err):
            self.lastCheck = time.time()
            if err:
                self.error = str(err) if isinstance(err, NetError) else "Erreur : %s" % err
                home.set_busy(self.error)
            else:
                self.releases, notes = res
                self.clientNotes = notes or self.clientNotes
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
                    self.toast("Nouvelle version %s de Warband Keeper : « Mettre à jour » sur l'Accueil." % latest, "warning")
                flash_taskbar(self.root)
            # installation automatique (Réglages > Mises à jour), seulement sur un addon déjà installé
            if not err and self.cfg["autoInstall"] and inst and self.latest_version and not self.busy \
                    and vtuple(self.latest_version) > vtuple(inst):
                self.toast("Nouvelle version %s : installation automatique…" % self.latest_version)
                self.update_addon()
        self.run(job, done)

    def update_addon(self):
        rel, addons = self.latest, self.addons
        if not (rel and addons) or self.busy:
            return
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
                if first:
                    how = "Relance complètement le jeu pour la charger." if running else "Elle se chargera au lancement du jeu."
                elif restart:
                    how = ("Redémarrage complet du jeu nécessaire : de nouveaux fichiers sont arrivés (un /reload ne suffit pas)."
                           if running else "Elle se chargera au prochain lancement du jeu (nouveaux fichiers : un /reload ne suffirait pas).")
                else:
                    how = "Un /reload en jeu suffit." if running else "Un /reload suffit (ou au prochain lancement du jeu)."
                self.lastInstall = (ver, restart and not first, how)
                home.set_busy("Version %s installée. %s" % (ver, how), 1.0)
                self.root.after(2500, lambda: home.set_busy(home.status["text"]))
                self.toast("Installé. " + how, "warning" if (restart and running) else "positive")
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
