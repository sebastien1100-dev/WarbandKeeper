local ADDON_NAME, WK = ...
local M = WK:NewModule("GatherMap")

-- Coins de récolte : à chaque butin qui contient une plante, un minerai ou un cuir connu
-- (Modules/Gathering.lua), on note la position du joueur sur la carte. Les points voisins
-- sont regroupés en « coins », affichés sur la carte du monde.
-- WK.DB.global.gatherSpots[mapID] = { { x, y, k = "herb"|"ore"|"skin", i = itemID, n, t }, ... }
local MAX_PER_MAP = 3000
local CELL = 0.025 -- taille d'un coin (fraction de la carte)
local COLORS = {
    herb = { 0.40, 1.00, 0.42 }, ore = { 1.00, 0.60, 0.18 }, skin = { 0.85, 0.62, 0.42 },
}
M.COLORS = COLORS

local kindOf -- [itemID] = "herb" | "ore" | "skin"
local function buildKinds()
    kindOf = {}
    local D = WK.modules.Gathering.DATA
    for _, d in ipairs(D.herb) do kindOf[d.id] = "herb" end
    for _, d in ipairs(D.mining) do kindOf[d.id] = "ore" end
    for _, d in ipairs(D.skin) do kindOf[d.id] = "skin" end
end

local function cfg() return WK.DB.global.gatherMap end
local function spots() return WK.DB.global.gatherSpots end
local NODE = 0.006 -- même nœud (fraction de la carte, ~10 à 20 m ; comme MERGE de Modules/Nodes.lua)
function M.Round(v) return math.floor(v * 10000 + 0.5) / 10000 end
function M.FindSpot(list, k, i, x, y)
    for j = #list, 1, -1 do
        local p = list[j]
        if p.k == k and p.i == i and math.abs(p.x - x) < NODE and math.abs(p.y - y) < NODE then return p end
    end
end
-- Points déjà notés : un seul par nœud (purge « Récoltes » de Modules/Maintenance.lua) ; rend le nombre retiré
function M.Compact(dry)
    local removed = 0
    for mapID, list in pairs(spots() or {}) do
        local out = {}
        for _, p in ipairs(list) do
            local q = M.FindSpot(out, p.k, p.i, p.x, p.y)
            if q then
                q.c, q.n, q.t = (q.c or 1) + (p.c or 1), (q.n or 0) + (p.n or 0), math.max(q.t or 0, p.t or 0)
                removed = removed + 1
            else
                out[#out + 1] = { x = M.Round(p.x), y = M.Round(p.y), k = p.k, i = p.i, n = p.n, t = p.t, c = p.c }
            end
        end
        if not dry then spots()[mapID] = out end
    end
    if not dry then M.rebuild = M.rebuild + 1; M.version = M.version + 1 end
    return removed
end

-- Position du joueur sur la carte de sa zone : mapID, x, y (0-1), ou nil.
local function playerPos()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
    local map = C_Map.GetBestMapForUnit("player")
    if not map then return nil end
    local pos = C_Map.GetPlayerMapPosition(map, "player")
    if not pos then return nil end
    local x, y = pos.x, pos.y
    if pos.GetXY then x, y = pos:GetXY() end
    if not x or not y or (x == 0 and y == 0) then return nil end
    return map, x, y
end

-- Une fenêtre de butin peut déclencher deux évènements : on ne compte qu'une fois.
local lastKey, lastAt = nil, 0
-- Version des récoltes : montée à chaque relevé et à l'effacement (cache de Modules/Nodes.lua)
M.version = 0
-- monte quand des points sont retirés (liste pleine, effacement) : les caches qui ajoutent les nouveaux
-- points au fur et à mesure (Nodes:All) repartent alors de zéro
M.rebuild = 0

local function onLoot()
    if not WK:FeatureOn("nodes") or not cfg().record then return end
    if not kindOf then buildKinds() end
    local found = {}
    for i = 1, (GetNumLootItems and GetNumLootItems() or 0) do
        local id = WK:ParseItemID(GetLootSlotLink and GetLootSlotLink(i))
        if id and kindOf[id] then
            local _, _, qty = GetLootSlotInfo(i)
            table.insert(found, { id = id, k = kindOf[id], n = qty or 1 })
        end
    end
    if #found == 0 then return end
    local map, x, y = playerPos()
    if not map then return end
    local key = string.format("%d:%.3f:%.3f:%d", map, x, y, found[1].id)
    if key == lastKey and GetTime() - lastAt < 5 then return end
    lastKey, lastAt = key, GetTime()
    local list = spots()[map] or {}
    spots()[map] = list
    -- même nœud déjà noté (même genre, même objet, à moins de NODE de la carte) : compté sur ce point (c = récoltes)
    -- au lieu d'une ligne de plus ; coordonnées arrondies (avant : une ligne de ~190 octets par butin, jusqu'à
    -- 3000 par carte, presque toutes redondantes)
    local merged = false
    for _, f in ipairs(found) do
        local p = M.FindSpot(list, f.k, f.id, x, y)
        if p then
            p.c, p.n, p.t = (p.c or 1) + 1, (p.n or 0) + (f.n or 1), _G.time()
            merged = true
        else
            table.insert(list, { x = M.Round(x), y = M.Round(y), k = f.k, i = f.id, n = f.n, t = _G.time() })
        end
    end
    if merged then M.rebuild = M.rebuild + 1 end
    -- élagage par lots : redescendu à 90 % du plafond, pour qu'un regroupement complet (Nodes:All) reste rare
    -- (avant, chaque butin d'une carte pleine retirait un point et forçait tout le regroupement)
    if #list > MAX_PER_MAP then
        local keep = math.floor(MAX_PER_MAP * 0.9)
        local drop = #list - keep
        for i = 1, keep do list[i] = list[i + drop] end
        for i = #list, keep + 1, -1 do list[i] = nil end
        M.rebuild = M.rebuild + 1
    end
    M.version = M.version + 1
    if M.Redraw then M:Redraw() end
end
WK:On("LOOT_OPENED", onLoot)
WK:On("LOOT_READY", onLoot)

-- Coins d'une carte : points regroupés par case. { x, y, count, kind, items = {[id]=n}, last }
function M:Clusters(mapID)
    local cells = {}
    for _, p in ipairs(spots()[mapID] or {}) do
        local cx, cy = math.floor(p.x / CELL), math.floor(p.y / CELL)
        local key = cx .. ":" .. cy
        local c = cells[key]
        if not c then
            c = { sx = 0, sy = 0, count = 0, kinds = {}, items = {}, last = 0 }
            cells[key] = c
        end
        c.sx, c.sy, c.count = c.sx + p.x, c.sy + p.y, c.count + 1
        c.kinds[p.k] = (c.kinds[p.k] or 0) + 1
        c.items[p.i] = (c.items[p.i] or 0) + (p.n or 1)
        if p.t > c.last then c.last = p.t end
    end
    local list = {}
    for _, c in pairs(cells) do
        c.x, c.y = c.sx / c.count, c.sy / c.count
        local best, bestN = nil, 0
        for k, n in pairs(c.kinds) do if n > bestN then best, bestN = k, n end end
        c.kind = best
        table.insert(list, c)
    end
    table.sort(list, function(a, b) return a.count > b.count end)
    return list
end

function M:Clear()
    wipe(spots())
    M.version = M.version + 1
    M.rebuild = M.rebuild + 1
    if self.Redraw then self:Redraw() end
end

function M:Count()
    local n = 0
    for _, list in pairs(spots()) do n = n + #list end
    return n
end
