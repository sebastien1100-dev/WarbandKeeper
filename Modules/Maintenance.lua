local ADDON_NAME, WK = ...
local M = WK:NewModule("Maintenance")

-- Fiabilité : journal des erreurs de l'addon et nettoyage des sauvegardes.
--   WK.DB.global.errors = { list = { { m (message), s (pile, nos fichiers seulement), n (fois), first, last, v } },
--                           seen = date de la dernière consultation }  (hors profils) ; new = pas encore vue
-- Les erreurs arrivent par le gestionnaire d'erreurs du jeu (enrobé, l'ancien est toujours appelé), par les
-- évènements de WK:On (déjà protégés par pcall dans Core/Init.lua) et par ADDON_ACTION_BLOCKED / FORBIDDEN.
-- Chargé tôt (juste après Core) pour noter aussi les erreurs du chargement ; gardées en mémoire tant que
-- la sauvegarde n'est pas prête.
local MAX = 50
local pending = {}

local function data()
    local g = WK.DB and WK.DB.global
    if not g then return nil end
    g.errors = g.errors or {}
    local d = g.errors
    d.list = d.list or {}
    d.seen = d.seen or 0
    return d
end
M.Data = data

-- garde le chemin à partir de notre dossier : « UI/BlessingBar.lua:412 »
local function short(s)
    s = tostring(s or "")
    s = s:gsub("Interface[/\\]AddOns[/\\]" .. ADDON_NAME .. "[/\\]", "")
    s = s:gsub("%[string \"@?[^\"]*" .. ADDON_NAME .. "[/\\]([^\"]*)\"%]", "%1")
    s = s:gsub("\\", "/")
    return s
end
local function ours(s) return type(s) == "string" and s:find(ADDON_NAME, 1, true) ~= nil end

local function store(e)
    local d = data()
    if not d then
        if #pending < MAX then table.insert(pending, e) end
        return
    end
    for _, x in ipairs(d.list) do
        if x.m == e.m then
            x.n = (x.n or 1) + (e.n or 1)
            x.last, x.v, x.new = e.last, e.v, true
            if e.s and e.s ~= "" then x.s = e.s end
            if M.OnChange then pcall(M.OnChange) end
            return
        end
    end
    e.new = true
    table.insert(d.list, 1, e)
    while #d.list > MAX do table.remove(d.list) end
    if M.OnChange then pcall(M.OnChange) end
end

function M.Record(msg, stack, event)
    msg = short(msg)
    if event then msg = msg .. " · " .. tostring(event) end
    if msg == "" then return end
    local lines = {}
    for line in tostring(stack or ""):gmatch("[^\n]+") do
        if ours(line) and not line:find("Maintenance.lua", 1, true) then
            table.insert(lines, (short(line):gsub("^%s+", "")))
            if #lines >= 4 then break end
        end
    end
    local now = time and time() or 0
    store({ m = msg:sub(1, 300), s = table.concat(lines, "\n"), n = 1, first = now, last = now, v = WK.version })
end
WK.RecordError = M.Record

-- gestionnaire d'erreurs du jeu : on note les nôtres, puis on laisse faire l'ancien
if geterrorhandler and seterrorhandler then
    local old = geterrorhandler()
    seterrorhandler(function(msg, ...)
        local stack = debugstack and debugstack(2) or ""
        if ours(msg) or ours(stack) then pcall(M.Record, msg, stack) end
        if old then return old(msg, ...) end
    end)
end
local function blocked(kind)
    return function(addon, func)
        if addon ~= ADDON_NAME then return end
        local inCombat = InCombatLockdown and InCombatLockdown()
        M.Record(string.format("%s : %s%s", kind, tostring(func or "?"), inCombat and " (en combat)" or ""), "")
    end
end
WK:On("ADDON_ACTION_BLOCKED", blocked("Action bloquée"))
WK:On("ADDON_ACTION_FORBIDDEN", blocked("Action interdite"))

function M:OnInit()
    local p = pending
    pending = {}
    for _, e in ipairs(p) do store(e) end
end

function M:List() local d = data(); return d and d.list or {} end
function M:Unseen()
    local d = data()
    if not d then return 0 end
    local n = 0
    for _, e in ipairs(d.list) do if e.new then n = n + 1 end end
    return n
end
function M:MarkSeen()
    local d = data()
    if not d then return end
    d.seen = time()
    for _, e in ipairs(d.list) do e.new = nil end
end
function M:Clear()
    local d = data()
    if d then d.list = {}; d.seen = time() end
    if M.OnChange then pcall(M.OnChange) end
end
-- plus ancienne version touchée par les erreurs du journal
function M:Since()
    local v
    for _, e in ipairs(self:List()) do v = e.v or v end
    return v
end
function M:Report()
    local out = { string.format("Warband Keeper %s · WoW %s · %s", tostring(WK.version),
        tostring(select(4, GetBuildInfo and GetBuildInfo() or nil) or "?"), tostring(GetLocale and GetLocale() or "?")) }
    for _, e in ipairs(self:List()) do
        table.insert(out, string.format("[x%d] %s (%s, %s)", e.n or 1, e.m, e.v or "?", date and date("%d/%m %H:%M", e.last or 0) or ""))
        if e.s and e.s ~= "" then
            for line in e.s:gmatch("[^\n]+") do table.insert(out, "    " .. line) end
        end
    end
    if #out == 1 then table.insert(out, "Aucune erreur notée.") end
    return table.concat(out, "\n")
end

---------------------------------------------------------------------------
-- Nettoyage : taille estimée (octets que la sauvegarde occupe à peu près sur le disque) et purges
---------------------------------------------------------------------------
local function sizeOf(v, depth)
    local t = type(v)
    if t == "string" then return #v + 3 end
    if t == "number" then return 8 end
    if t == "boolean" then return 5 end
    if t ~= "table" or (depth or 0) > 30 then return 0 end
    local n = 4
    for k, x in pairs(v) do
        n = n + 4 + (type(k) == "string" and #k + 4 or 6) + sizeOf(x, (depth or 0) + 1)
    end
    return n
end
M.SizeOf = sizeOf

function M:Total()
    return sizeOf(WK.DB.global) + sizeOf(_G.WarbandKeeperCharDB)
end

local DAY = 86400
-- Chaque purge : clé, titre, cochée d'office, détail (texte) et gain (octets) estimés, Run
M.PURGES = {
    {
        key = "ah", on = true, label = "Prix de l'HV : objets pas vus depuis 30 jours",
        scan = function()
            local realms = WK.DB.global.ah and WK.DB.global.ah.realms or {}
            local n, bytes, nr = 0, 0, 0
            local lim = time() - 30 * DAY
            for _, r in pairs(realms) do
                nr = nr + 1
                for _, e in pairs(r.items or {}) do
                    if type(e) == "table" and (e.t or 0) < lim then n, bytes = n + 1, bytes + sizeOf(e) + 14 end
                end
            end
            return n, bytes, string.format(WK.T("%d objets sur %d royaumes"), n, nr)
        end,
        run = function()
            local lim = time() - 30 * DAY
            for _, r in pairs(WK.DB.global.ah and WK.DB.global.ah.realms or {}) do
                for id, e in pairs(r.items or {}) do
                    if type(e) == "table" and (e.t or 0) < lim then r.items[id] = nil end
                end
            end
        end,
    },
    {
        key = "sales", on = true, label = "Journal des ventes : plus vieux que 90 jours",
        scan = function()
            local log = WK.DB.global.auction and WK.DB.global.auction.log or {}
            local lim, n, bytes = time() - 90 * DAY, 0, 0
            for _, e in ipairs(log) do if (e.t or 0) < lim then n, bytes = n + 1, bytes + sizeOf(e) + 6 end end
            return n, bytes, string.format(WK.T("%d lignes"), n)
        end,
        run = function()
            local a = WK.DB.global.auction
            if not (a and a.log) then return end
            local lim, keep = time() - 90 * DAY, {}
            for _, e in ipairs(a.log) do if (e.t or 0) >= lim then table.insert(keep, e) end end
            a.log = keep
        end,
    },
    {
        key = "fish", on = true, label = "Carnet de pêche : garder les 500 dernières prises",
        hint = "les totaux et la collection restent",
        scan = function()
            local log = WK.DB.global.fishLog and WK.DB.global.fishLog.log or {}
            local n, bytes = 0, 0
            for i = 501, #log do n, bytes = n + 1, bytes + sizeOf(log[i]) + 6 end
            return n, bytes, string.format(WK.T("%d prises de trop"), n)
        end,
        run = function()
            local log = WK.DB.global.fishLog and WK.DB.global.fishLog.log
            if log then for i = #log, 501, -1 do log[i] = nil end end
        end,
    },
    {
        key = "trails", on = false, label = "Chemins appris : tout oublier",
        hint = "la navigation réapprendra en jouant",
        scan = function()
            local tr = WK.DB.global.nav and WK.DB.global.nav.trails or {}
            local n = 0
            for _, list in pairs(tr) do n = n + #list end
            return n, sizeOf(tr) - 4, string.format(WK.T("%d tronçons"), n)
        end,
        run = function()
            local Nav = WK.modules.Nav
            if Nav and Nav.Forget then Nav:Forget()
            elseif WK.DB.global.nav then WK.DB.global.nav.trails = {} end
        end,
    },
    {
        key = "chars", on = false, label = "Persos pas connectés depuis 180 jours",
        scan = function()
            local lim, n, bytes, names = time() - 180 * DAY, 0, 0, {}
            local me = WK:CharKey()
            for key, c in pairs(WK.DB.global.characters or {}) do
                if key ~= me and type(c) == "table" and (c.lastSeen or 0) > 0 and c.lastSeen < lim then
                    n, bytes = n + 1, bytes + sizeOf(c) + #key + 8
                    table.insert(names, (key:match("^(.-)%-") or key))
                end
            end
            table.sort(names)
            local txt = n == 0 and WK.T("aucun") or (string.format(WK.T("%d persos"), n) .. " : " .. table.concat(names, ", ", 1, math.min(#names, 4)) .. (#names > 4 and "…" or ""))
            return n, bytes, txt
        end,
        run = function()
            local lim, me = time() - 180 * DAY, WK:CharKey()
            local chars = WK.DB.global.characters or {}
            for key, c in pairs(chars) do
                if key ~= me and type(c) == "table" and (c.lastSeen or 0) > 0 and c.lastSeen < lim then chars[key] = nil end
            end
        end,
    },
}

-- état coché (pas une donnée : réinitialisé à chaque session)
M.checked = {}
for _, p in ipairs(M.PURGES) do M.checked[p.key] = p.on end

function M:Scan()
    local out = {}
    for _, p in ipairs(self.PURGES) do
        local ok, n, bytes, txt = pcall(p.scan)
        if not ok then n, bytes, txt = 0, 0, "?" end
        out[p.key] = { n = n or 0, bytes = math.max(0, bytes or 0), text = txt }
    end
    return out
end
-- lance les purges cochées ; rend les octets libérés (estimés avant)
function M:Clean(scan)
    scan = scan or self:Scan()
    local freed = 0
    for _, p in ipairs(self.PURGES) do
        if self.checked[p.key] and (scan[p.key].n or 0) > 0 then
            local ok, err = pcall(p.run)
            if ok then freed = freed + scan[p.key].bytes else M.Record(err, debugstack and debugstack() or "") end
        end
    end
    if WK.modules.Stash and WK.modules.Stash.Invalidate then pcall(WK.modules.Stash.Invalidate, WK.modules.Stash) end
    WK:NotifyChanged()
    return freed
end

function M.Bytes(b)
    b = b or 0
    if b >= 1024 * 1024 then return (string.format("%.1f Mo", b / 1048576):gsub("%.", ",")) end
    if b >= 1024 then return string.format("%d Ko", math.floor(b / 1024 + 0.5)) end
    return string.format("%d o", b)
end
