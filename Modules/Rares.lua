local ADDON_NAME, WK = ...
local M = WK:NewModule("Rares")
local T = function(s) return WK.T(s) end

-- Rares (données Modules/RaresDB.lua, tirées de QuestieDB) :
--   carte du monde (UI/RarePins.lua), alerte quand un rare apparaît (UI/RareAlert.lua),
--   infobulle d'un rare (butin notable, rares tués par tes persos).
-- Un rare est reconnu par son numéro de PNJ (dans son GUID) ; un rare absent des données mais
-- que le jeu dit « rare » déclenche quand même l'alerte.
-- Réglages : WK.DB.global.rares ; rares tués : WK.DB.global.rares.kills[npcID][perso] = date.

local DEFAULTS = { map = true, list = true, alert = true, sound = true, tooltip = true,
                   hideKilled = false, alertStyle = "banner", skull = true, paths = false }
function M:Config()
    local g = WK.DB.global
    g.rares = g.rares or {}
    for k, v in pairs(DEFAULTS) do if g.rares[k] == nil then g.rares[k] = v end end
    g.rares.kills = g.rares.kills or {}
    return g.rares
end

local function readable(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end
M.Readable = readable

-- Index des rares par numéro : { id, map, name, nameFR, min, max, elite, spawns, path }
local byID
local function index()
    byID = {}
    for mapID, list in pairs(WK.RaresDB or {}) do
        for _, e in ipairs(list) do
            local r = byID[e[1]]
            if not r then
                r = { id = e[1], name = e[2], nameFR = e[3], min = e[4], max = e[5], elite = e[6], maps = {} }
                byID[e[1]] = r
            end
            r.maps[mapID] = { spawns = e[7], path = e[8] }
        end
    end
end
function M:Get(id)
    if not byID then index() end
    return byID[id]
end
function M:Name(r)
    if not r then return "?" end
    return (WK.Lang() == "frFR" and r.nameFR) or r.name
end
-- Rares d'une carte (liste triée par niveau)
function M:OnMap(mapID)
    if not byID then index() end
    local out = {}
    for _, e in ipairs((WK.RaresDB or {})[mapID] or {}) do table.insert(out, byID[e[1]]) end
    return out
end

-- Numéro de PNJ d'une unité (Creature-0-serveur-instance-zone-PNJ-exemplaire)
function M.NpcID(unit)
    if not UnitGUID then return nil end
    local ok, guid = pcall(UnitGUID, unit)
    guid = ok and readable(guid) or nil
    if type(guid) ~= "string" then return nil end
    local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
    return tonumber(id)
end

---------------------------------------------------------------------------
-- Zones et progression (page Rares)
---------------------------------------------------------------------------
local mapInfo = {}
local function info(mapID)
    local i = mapInfo[mapID]
    if i == nil then
        local ok, mi = false, nil
        if C_Map and C_Map.GetMapInfo then ok, mi = pcall(C_Map.GetMapInfo, mapID) end
        i = ok and mi or false
        mapInfo[mapID] = i
    end
    return i or nil
end
-- Continent d'une carte : { id, name } (en remontant les cartes parentes)
function M:Continent(mapID)
    local id, guard = mapID, 0
    while id and guard < 8 do
        local i = info(id)
        if not i then break end
        if i.mapType == 2 then return id, i.name end
        id, guard = i.parentMapID, guard + 1
    end
    return 0, T("Autres")
end
function M:ZoneName(mapID)
    local i = info(mapID)
    return i and i.name or ("#" .. mapID)
end
-- Zones qui ont des rares : { { map, name, cont, contName, total, killed, min, max } } pour un perso
function M:Zones(key)
    key = key or WK:CharKey()
    local out = {}
    for mapID, list in pairs(WK.RaresDB or {}) do
        local z = { map = mapID, name = self:ZoneName(mapID), total = 0, killed = 0, min = 99, max = 0 }
        z.cont, z.contName = self:Continent(mapID)
        for _, e in ipairs(list) do
            z.total = z.total + 1
            if self:Killed(e[1], key) then z.killed = z.killed + 1 end
            z.min, z.max = math.min(z.min, e[4] or 0), math.max(z.max, e[5] or 0)
        end
        table.insert(out, z)
    end
    table.sort(out, function(a, b) if a.contName ~= b.contName then return a.contName < b.contName end return a.name < b.name end)
    return out
end
-- Nombre de rares (uniques) et tués par un perso
function M:Totals(key)
    key = key or WK:CharKey()
    if not byID then index() end
    local total, killed = 0, 0
    for id in pairs(byID) do
        total = total + 1
        if self:Killed(id, key) then killed = killed + 1 end
    end
    return killed, total
end
-- Zone du joueur qui a des rares (ou sa carte parente)
function M:PlayerZone()
    if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
    local id, guard = C_Map.GetBestMapForUnit("player"), 0
    while id and guard < 5 do
        if (WK.RaresDB or {})[id] then return id end
        local i = info(id)
        id, guard = i and i.parentMapID, guard + 1
    end
    return nil
end

---------------------------------------------------------------------------
-- Butin notable
---------------------------------------------------------------------------
-- Sous-classe de recette -> métier (noms en jeu)
local RECIPE_PROF = { [1] = "Travail du cuir", [2] = "Couture", [3] = "Ingénierie", [4] = "Forge", [5] = "Cuisine",
                      [6] = "Alchimie", [7] = "Secourisme", [8] = "Enchantement", [9] = "Pêche" }
M.RECIPE_PROF = RECIPE_PROF

-- { { id, prof? (métier de la recette), who = { noms de tes persos qui ont ce métier } } }
function M:Loot(id)
    local out = {}
    for _, item in ipairs((WK.RaresLoot or {})[id] or {}) do
        local sub = WK.RaresRecipe and WK.RaresRecipe[item]
        local prof = sub and RECIPE_PROF[sub]
        local who = {}
        if prof then
            for key, c in pairs(WK.DB.global.characters) do
                if c.professions and c.professions[prof] then table.insert(who, WK:CharName(c, key)) end
            end
        end
        table.insert(out, { id = item, prof = prof, who = who })
    end
    return out
end

---------------------------------------------------------------------------
-- Rares tués
---------------------------------------------------------------------------
function M:Killed(id, key)
    local k = self:Config().kills[id]
    if not k then return nil end
    if key then return k[key] end
    return k
end
function M:MarkKilled(id)
    if not id or not self:Get(id) then return end
    local cfg = self:Config()
    cfg.kills[id] = cfg.kills[id] or {}
    cfg.kills[id][WK:CharKey()] = time()
    if self.OnChange then self:OnChange() end
    WK:NotifyChanged()
end

-- Butin ouvert sur un cadavre : si c'est un rare, il est tué (par ce perso)
WK:On("LOOT_OPENED", function()
    if not (GetNumLootItems and GetLootSourceInfo) then return end
    for i = 1, GetNumLootItems() do
        local guid = readable(GetLootSourceInfo(i))
        if type(guid) == "string" then
            local id = tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)"))
            if id and M:Get(id) then M:MarkKilled(id) end
        end
    end
end)
-- Rare ciblé qui meurt (pas toujours de butin : déjà ramassé par un autre, etc.)
WK:On("UNIT_HEALTH", function(unit)
    if unit ~= "target" then return end
    local ok, dead = pcall(UnitIsDead, "target")
    if not (ok and readable(dead) == true) then return end
    local id = M.NpcID("target")
    if id and M:Get(id) then
        local tapOk, denied = pcall(UnitIsTapDenied, "target")
        if not (tapOk and readable(denied) == true) then M:MarkKilled(id) end
    end
end)

---------------------------------------------------------------------------
-- Détection : plaque de nom ou cible d'un monstre rare
---------------------------------------------------------------------------
local seen = {} -- [id ou nom] = date de la dernière alerte (une alerte par rare toutes les 5 minutes)
local function check(unit)
    local cfg = M:Config()
    if not cfg.alert or not WK:FeatureOn("rares") then return end
    local okE, exists = pcall(UnitExists, unit)
    if not (okE and readable(exists)) then return end
    local okC, cls = pcall(UnitClassification, unit)
    cls = okC and readable(cls) or nil
    local id = M.NpcID(unit)
    local r = id and M:Get(id)
    if not r and cls ~= "rare" and cls ~= "rareelite" then return end
    local okD, dead = pcall(UnitIsDead, unit)
    if okD and readable(dead) == true then return end
    local okN, name = pcall(UnitName, unit)
    name = okN and readable(name) or nil
    local key = id or name
    if not key then return end
    local now = GetTime()
    if seen[key] and now - seen[key] < 300 then return end
    seen[key] = now
    local okL, level = pcall(UnitLevel, unit)
    if M.OnSpotted then
        M:OnSpotted({ id = id, rare = r, name = (r and M:Name(r)) or name or "?", unitName = name,
                      level = okL and readable(level) or nil, elite = (r and r.elite) or cls == "rareelite", unit = unit })
    end
end
WK:On("NAME_PLATE_UNIT_ADDED", function(unit) pcall(check, unit) end)
WK:On("PLAYER_TARGET_CHANGED", function() pcall(check, "target") end)

---------------------------------------------------------------------------
-- Guidage vers le point d'apparition le plus proche
---------------------------------------------------------------------------
-- Marqueur tête de mort du jeu sur le rare vu (unité de sa plaque de nom ou cible), s'il est encore là
function M:MarkSkull(info)
    if not (info and info.unit) or self:Config().skull == false then return end
    if not (SetRaidTarget and UnitExists) then return end
    local okE, ex = pcall(UnitExists, info.unit)
    if not okE or not ex then return end
    -- la plaque a pu passer à un autre monstre : on vérifie le nom
    local okN, nm = pcall(UnitName, info.unit)
    nm = okN and readable(nm) or nil
    if nm and info.unitName and nm ~= info.unitName then return end
    local okI, idx = pcall(GetRaidTargetIndex, info.unit)
    if okI and readable(idx) == 8 then return end
    pcall(SetRaidTarget, info.unit, 8)
end

function M:GuideTo(r)
    local G = WK.modules.Guide
    local p = G:PlayerPos()
    local best, bestD
    for mapID, m in pairs(r.maps) do
        for k = 1, #m.spawns, 2 do
            local t = { map = mapID, x = m.spawns[k] / 100, y = m.spawns[k + 1] / 100 }
            local cont, wx, wy = G.ToWorld(mapID, t.x, t.y)
            t.cont, t.wx, t.wy = cont, wx, wy
            local d = p and G:Vector(p, t) or (mapID == (p and p.map) and 0 or nil)
            if not best or (d and (not bestD or d < bestD)) then best, bestD = t, d end
        end
    end
    if not best then return end
    -- fiche lisible par le guidage : nom, et « Rare » comme métier
    best.e = { best.x * 100, best.y * 100, 0, nil, nil, r.name, r.nameFR or r.name, T(r.elite and "Rare élite" or "Rare") }
    best.distance = bestD
    G:Start(best, "Rare", "rare")
end
