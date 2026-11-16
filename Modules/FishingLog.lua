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
    s.skill1 = F and F:Skill()
    if WK.UI.ShowFishingRecap then WK.UI:ShowFishingRecap(s) end
end
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
