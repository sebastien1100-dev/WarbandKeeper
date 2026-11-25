local ADDON_NAME, WK = ...
local M = WK:NewModule("FishingLog")
local T = function(s) return WK.T(s) end

-- Carnet de pêche : chaque butin de pêche est noté (objets, zone, heure, perso). Appelé par
-- Modules/Fishing.lua à l'ouverture du butin, avant le butin rapide.
--   WK.DB.global.fishLog = { total, time (s de pêche), items[id] = { n, first, by }, zones[map] = { n, time, items[id] = n },
--                            log = { { t, c (perso), m (carte), it = { { id, q } } } } (les plus récents d'abord) }
-- Session : du mode pêche ouvert à sa fermeture (M.session), récapitulée par UI/FishingRecap.lua.
local MAX_LOG = 1500
local GAP = 120 -- au-delà de 2 min sans prise, le temps ne compte plus comme du temps de pêche

function M:Data()
    local g = WK.DB.global
    g.fishLog = g.fishLog or {}
    local d = g.fishLog
    d.total, d.time = d.total or 0, d.time or 0
    d.items, d.zones, d.log = d.items or {}, d.zones or {}, d.log or {}
    return d
end

local function zoneOf()
    local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    -- carte de zone plutôt que sous-zone (port, île…) : on remonte jusqu'à une zone
    local guard = 0
    while map and guard < 4 and C_Map.GetMapInfo do
        local ok, info = pcall(C_Map.GetMapInfo, map)
        if not ok or not info or (info.mapType or 3) <= 3 then break end
        map, guard = info.parentMapID, guard + 1
    end
    return map
end
function M:ZoneName(map)
    if not map then return T("Zone inconnue") end
    local R = WK.modules.Rares
    return R and R:ZoneName(map) or ("#" .. map)
end
local function price(id)
    local V = WK.modules.Value
    return V and V:Price(id) or 0
end

-- Lit le butin de pêche ouvert ; une seule fois par fenêtre de butin
local handled = false
function M:Record()
    if handled then return end
    if not (IsFishingLoot and IsFishingLoot()) then return end
    if not (GetNumLootItems and GetLootSlotLink) then return end
    local items = {}
    for i = 1, GetNumLootItems() do
        local isMoney = GetLootSlotType and Enum and Enum.LootSlotType and GetLootSlotType(i) == Enum.LootSlotType.Money
        if not isMoney then
            local id = WK:ParseItemID(GetLootSlotLink(i))
            local q = select(3, GetLootSlotInfo(i)) or 1
            if id then table.insert(items, { id, q }) end
        end
    end
    if #items == 0 then return end
    handled = true
    local d = self:Data()
    local now = time()
    local map = zoneOf()
    local key = WK:CharKey()
    -- temps de pêche : écart avec la prise précédente s'il est court
    local dt = (d.lastAt and now - d.lastAt < GAP) and (now - d.lastAt) or 0
    d.lastAt = now
    d.total = d.total + 1
    d.time = d.time + dt
    local z
    if map then
        d.zones[map] = d.zones[map] or { n = 0, time = 0, items = {} }
        z = d.zones[map]
        z.n, z.time = z.n + 1, z.time + dt
        -- dernier coin de pêche de la zone (pour y guider depuis la collection)
        local pos = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
        if pos then
            local x, y = pos.x, pos.y
            if pos.GetXY then x, y = pos:GetXY() end
            if x and y and (x > 0 or y > 0) then z.pos = { math.floor(x * 10000) / 10000, math.floor(y * 10000) / 10000 } end
        end
    end
    local new = {}
    for _, it in ipairs(items) do
        local id, q = it[1], it[2]
        if not d.items[id] then d.items[id] = { n = 0, first = now, by = key }; new[id] = true end
        d.items[id].n = d.items[id].n + q
        if z then z.items[id] = (z.items[id] or 0) + q end
    end
    table.insert(d.log, 1, { t = now, c = key, m = map, it = items, new = next(new) and new or nil })
    while #d.log > MAX_LOG do table.remove(d.log) end
    -- session en cours (mode pêche ouvert)
    local s = self.session
    if s then
        s.catches = s.catches + 1
        s.zone = s.zone or map
        for _, it in ipairs(items) do
            s.items[it[1]] = (s.items[it[1]] or 0) + it[2]
            s.value = s.value + price(it[1]) * it[2]
            if new[it[1]] then s.new[it[1]] = true end
        end
        local b = math.floor((GetTime() - s.start) / 120) + 1 -- prises par tranche de 2 minutes
        s.buckets[b] = (s.buckets[b] or 0) + 1
    end
    if self.OnCatch then self:OnCatch() end
    WK:NotifyChanged()
end
WK:On("LOOT_CLOSED", function() handled = false end)

-- Session : ouverte avec le mode pêche, récapitulée à sa fermeture
function M:StartSession()
    local F = WK.modules.Fishing
    self.session = { start = GetTime(), catches = 0, items = {}, value = 0, new = {}, buckets = {}, skill0 = F and F:Skill() }
end
function M:EndSession()
    local s = self.session
    self.session = nil
    if not s or s.catches == 0 then return end
    local F = WK.modules.Fishing
    s.duration = GetTime() - s.start
    -- compétence relue au moment de fermer (l'évènement des compétences peut ne pas avoir suivi)
    local P = WK.modules.Professions
    if P and P.Scan then pcall(P.Scan, P) end
    s.skill1 = F and F:Skill()
    if s.skillMax and (not s.skill1 or s.skillMax > s.skill1) then s.skill1 = s.skillMax end
    if WK.UI.ShowFishingRecap then WK.UI:ShowFishingRecap(s) end
end
-- Point de compétence gagné pendant la session (message « Votre compétence en Pêche augmente… »)
WK:On("CHAT_MSG_SKILL", function()
    local P = WK.modules.Professions
    if P and P.Scan then pcall(P.Scan, P) end
    local s, F = M.session, WK.modules.Fishing
    local sk = s and F and F:Skill()
    if sk and (not s.skillMax or sk > s.skillMax) then s.skillMax = sk end
end)

-- Rythme (prises par heure) d'une session ou d'un total
function M.Rate(n, seconds)
    if not seconds or seconds < 60 then return nil end
    return math.floor(n * 3600 / seconds + 0.5)
end

-- Zones triées par nombre de prises : { { map, n, time, top = { id, id } } }
function M:Zones()
    local out = {}
    for map, z in pairs(self:Data().zones) do
        local top = {}
        for id, n in pairs(z.items) do table.insert(top, { id, n }) end
        table.sort(top, function(a, b) return a[2] > b[2] end)
        table.insert(out, { map = map, n = z.n, time = z.time, top = { top[1] and top[1][1], top[2] and top[2][1] } })
    end
    table.sort(out, function(a, b) return a.n > b.n end)
    return out
end
function M:Species()
    local n = 0
    for _ in pairs(self:Data().items) do n = n + 1 end
    return n
end
function M:Value()
    local v = 0
    for id, e in pairs(self:Data().items) do v = v + price(id) * e.n end
    return v
end

---------------------------------------------------------------------------
-- Collection (album et atlas) : référence Modules/FishDB.lua + prises du carnet
---------------------------------------------------------------------------
local REF_BY_ID
local function ref()
    if not REF_BY_ID then
        REF_BY_ID = {}
        for i, sp in ipairs(WK.FishDB.species) do REF_BY_ID[sp[1]] = { id = sp[1], cat = sp[2], tier = sp[3], order = i } end
    end
    return REF_BY_ID
end
-- Zones de pêche : celles de ForeverDB (Modules/ForeverGatherDB.lua) d'abord, sinon la référence de FishDB.
-- { [carte] = { sans fuite, { poissons }, chance = { [objet] = % }, pools = { n° de FishDB.POOLS }, min, seen,
-- fdb } } :
-- [1] = compétence à partir de laquelle plus rien ne s'échappe (comme la référence), min = celle de la zone.
-- « Data from ForeverDB.net (https://foreverdb.net) » : mention `M.CREDIT` partout où c'est montré.
M.CREDIT = "foreverdb.net"
local ZONES
local function zonesRef()
    if ZONES then return ZONES end
    if not WK.FFish then ZONES = WK.FishDB.zones; return ZONES end
    local R = ref()
    ZONES = {}
    for map, z in pairs(WK.FFish) do
        local e = { z[2], {}, chance = {}, pools = {}, min = z[1], seen = {}, fdb = true }
        for id, c in (z[3] or ""):gmatch("(%d+):(%d+)") do
            id, c = tonumber(id), tonumber(c) / 100
            e.chance[id] = c
            local sp = R[id]
            if (sp and sp.cat == "fish") or (not sp and c >= 5) then table.insert(e[2], id) end
        end
        for n in (z[4] or ""):gmatch("%d+") do table.insert(e.pools, tonumber(n)) end
        for id, c in (z[5] or ""):gmatch("(%d+):(%d+)") do e.seen[tonumber(id)] = tonumber(c) end
        ZONES[map] = e
    end
    for map, z in pairs(WK.FishDB.zones) do if not ZONES[map] then ZONES[map] = z end end
    return ZONES
end
M.Zones = zonesRef
-- pourcentage court : 58, 7.5, 0.06
function M.Pct(p)
    if p >= 10 then return tostring(math.floor(p + 0.5)) end
    if p >= 1 then return (string.format("%.1f", p):gsub("%.0$", "")) end
    return (string.format("%.2f", p):gsub("0+$", ""):gsub("%.$", ""))
end
-- Zone de pêche où se trouve le perso (ou nil) et sa carte
function M.HereZone(_)
    local map = zoneOf()
    return map and zonesRef()[map], map
end
M.NEW_DAYS = 7 -- point « nouveau » sur les espèces pêchées pour la première fois depuis moins d'une semaine

-- Espèces : { { id, cat, tier, n, first, by, ref } } ; les prises hors référence sont en « other »
-- (dans le palier de compétence de la zone où elles ont mordu, sinon sans palier).
function M:Collection()
    local d, R = self:Data(), ref()
    local out = {}
    for _, sp in ipairs(WK.FishDB.species) do
        local e = d.items[sp[1]]
        table.insert(out, { id = sp[1], cat = sp[2], tier = sp[3], ref = true, n = e and e.n or 0, first = e and e.first, by = e and e.by })
    end
    local extra = {}
    for id, e in pairs(d.items) do
        if not R[id] then
            local tier
            for map, z in pairs(d.zones) do
                local zr = z.items[id] and zonesRef()[map]
                if zr then
                    local t = zr[1] >= 205 and 4 or zr[1] >= 130 and 3 or zr[1] >= 55 and 2 or 1
                    if not tier or t < tier then tier = t end
                end
            end
            table.insert(extra, { id = id, cat = "other", tier = tier or 0, n = e.n, first = e.first, by = e.by })
        end
    end
    table.sort(extra, function(a, b) return a.id < b.id end)
    for _, e in ipairs(extra) do table.insert(out, e) end
    return out
end
function M:CollectionCount()
    local have, total = 0, 0
    for _, e in ipairs(self:Collection()) do
        total = total + 1
        if e.n > 0 then have = have + 1 end
    end
    return have, total
end

-- Où une espèce a mordu : { { map, n, pct } } (tes prises), puis les zones de la référence où elle mord
function M:SpeciesZones(id)
    local out, sum = {}, 0
    for map, z in pairs(self:Data().zones) do
        local n = z.items[id]
        if n and n > 0 then table.insert(out, { map = map, n = n }); sum = sum + n end
    end
    table.sort(out, function(a, b) return a.n > b.n end)
    for _, r in ipairs(out) do r.pct = math.floor(r.n * 100 / sum + 0.5) end
    local refZones = {}
    for map, zr in pairs(zonesRef()) do
        local seen = false
        for _, r in ipairs(out) do if r.map == map then seen = true end end
        if not seen then
            for _, f in ipairs(zr[2]) do
                if f == id then
                    table.insert(refZones, { map = map, skill = zr[1], chance = zr.chance and zr.chance[id] })
                end
            end
        end
    end
    -- là où ça mord le mieux d'abord (chance de ForeverDB), puis la compétence la plus basse
    table.sort(refZones, function(a, b)
        if (a.chance or 0) ~= (b.chance or 0) then return (a.chance or 0) > (b.chance or 0) end
        if a.skill ~= b.skill then return a.skill < b.skill end
        return a.map < b.map
    end)
    return out, refZones
end

-- Atlas : une ligne par zone (référence + zones où tu as pêché) :
-- { map, skill, fish = { ids }, have = { [id] = true }, n, time, pos }
function M:Atlas()
    local d, R = self:Data(), ref()
    local rows = {}
    local function row(map)
        local zr = zonesRef()[map]
        local z = d.zones[map]
        local r = { map = map, skill = zr and zr[1], fish = {}, have = {}, n = z and z.n or 0, time = z and z.time or 0,
            pos = z and z.pos, ref = zr }
        local seen = {}
        if zr then for _, id in ipairs(zr[2]) do table.insert(r.fish, id); seen[id] = true end end
        if z then
            for id in pairs(z.items) do
                r.have[id] = true
                local sp = R[id]
                if not seen[id] and (not sp or sp.cat == "fish") then table.insert(r.fish, id); seen[id] = true end
            end
        end
        return r
    end
    for map in pairs(zonesRef()) do table.insert(rows, row(map)) end
    for map in pairs(d.zones) do if not zonesRef()[map] then table.insert(rows, row(map)) end end
    table.sort(rows, function(a, b)
        local sa, sb = a.skill or 999, b.skill or 999
        if sa ~= sb then return sa < sb end
        return self:ZoneName(a.map) < self:ZoneName(b.map)
    end)
    return rows
end

-- Guidage vers le dernier coin de pêche connu d'une zone
function M:GuideZone(map)
    local z = self:Data().zones[map]
    if not (z and z.pos) then return false end
    local G = WK.modules.Guide
    local t = { map = map, x = z.pos[1], y = z.pos[2] }
    t.cont, t.wx, t.wy = G.ToWorld(map, t.x, t.y)
    local p = G:PlayerPos()
    t.distance = p and G:Vector(p, t) or nil
    t.e = { t.x * 100, t.y * 100, 0, nil, nil, self:ZoneName(map), self:ZoneName(map), T("Coin de pêche") }
    G:Start(t, "Pêche", "fishing")
    return true
end
-- Vers la zone où une espèce mord le plus (parmi celles où tu as un coin connu)
function M:GuideSpecies(id)
    local zs = self:SpeciesZones(id)
    for _, r in ipairs(zs) do if self:GuideZone(r.map) then return true end end
    return false
end
