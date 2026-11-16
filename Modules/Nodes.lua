local ADDON_NAME, WK = ...
local M = WK:NewModule("Nodes")

-- Emplacements des filons et des plantes : ceux que tes persos ont réellement récoltés
-- (WK.DB.global.gatherSpots, notés par Modules/GatherMap.lua à chaque récolte), regroupés par nœud.
-- Les points d'apparition de QuestieDB ne correspondaient pas aux nœuds de WoW Forever : retirés.
-- Le pistage du jeu reste le signal en direct (agrandi par le HUD de récolte, UI/GatherHUD.lua).
-- Affichage : UI/NodePins.lua (minicarte et carte du monde).
-- Réglages : WK.DB.global.gatherMap.nodes

local DEFAULTS = { minimap = true, map = true, onlyMine = true, onlyUsable = false, size = 14 }
function M:Config()
    local g = WK.DB.global.gatherMap
    g.nodes = g.nodes or {}
    for k, v in pairs(DEFAULTS) do if g.nodes[k] == nil then g.nodes[k] = v end end
    return g.nodes
end

-- [objet récolté] = { kind = "herb" | "mining", req = compétence requise }
local info
local function buildInfo()
    info = {}
    local D = WK.modules.Gathering.DATA
    for _, d in ipairs(D.herb) do info[d.id] = { kind = "herb", req = d.req or 1 } end
    for _, d in ipairs(D.mining) do info[d.id] = { kind = "mining", req = d.req or 1 } end
end
function M:Info(id)
    if not info then buildInfo() end
    return info[id]
end

-- Niveau du perso dans chaque métier de récolte : { herb = 120, mining = nil }
function M:Ranks()
    local r = {}
    local G = WK.modules.Gathering
    for name, p in pairs(WK.DB:Me().professions or {}) do
        local k = G:Kind(name)
        if k == "herb" or k == "mining" then r[k] = p.rank or 0 end
    end
    return r
end

-- Couleur d'un emplacement selon la compétence (comme les couleurs de difficulté du jeu).
local COLORS = {
    none = { 0.62, 0.62, 0.62 }, low = { 0.90, 0.25, 0.20 }, optimal = { 1.00, 0.55, 0.20 },
    medium = { 1.00, 0.90, 0.25 }, easy = { 0.35, 0.85, 0.35 }, trivial = { 0.62, 0.62, 0.62 },
}
function M:Color(node, ranks)
    local rank = ranks[node.kind]
    if not rank then return COLORS.none end
    return COLORS[WK.modules.Gathering:Color(node.req, rank)] or COLORS.none
end

-- Tous les emplacements d'une carte : { { x, y (0-1), id, kind, req, n }, ... }.
-- Les récoltes à moins de MERGE (fraction de la carte, ~10 à 20 m) du même nœud n'en font qu'un.
-- Gardé en mémoire tant que le nombre de récoltes de la carte ne change pas.
local MERGE = 0.006
local cache = {}
function M:All(mapID)
    local spots = (WK.DB.global.gatherSpots or {})[mapID] or {}
    local c = cache[mapID]
    if c and c.n == #spots then return c.list end
    local list = {}
    for _, p in ipairs(spots) do
        local i = (p.k == "herb" or p.k == "ore") and self:Info(p.i)
        if i then
            local found
            for _, e in ipairs(list) do
                if e.kind == i.kind and math.abs(e.x - p.x) < MERGE and math.abs(e.y - p.y) < MERGE then found = e break end
            end
            if found then
                found.n = found.n + 1
                if i.req > found.req then found.req, found.id = i.req, p.i end
            else
                list[#list + 1] = { x = p.x, y = p.y, id = p.i, kind = i.kind, req = i.req, n = 1 }
            end
        end
    end
    cache[mapID] = { n = #spots, list = list }
    return list
end

-- Emplacements à montrer, selon les réglages et les métiers du perso.
function M:Visible(mapID)
    local o, ranks = self:Config(), self:Ranks()
    local out = {}
    for _, n in ipairs(self:All(mapID)) do
        local rank = ranks[n.kind]
        if (not o.onlyMine or rank) and (not o.onlyUsable or (rank or 0) >= n.req) then out[#out + 1] = n end
    end
    return out, ranks
end
