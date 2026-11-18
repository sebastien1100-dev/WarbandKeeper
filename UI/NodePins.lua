local ADDON_NAME, WK = ...
local UI = WK.UI
local N = WK.modules.Nodes

-- Emplacements connus des filons et des plantes (Modules/Nodes.lua) : petites icônes sur la
-- minicarte autour du joueur, et sur la carte du monde. L'anneau dit la difficulté pour la
-- compétence du perso. Les icônes de la minicarte ne captent pas la souris.

local function itemIcon(id)
    local f = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
    return f and f(id) or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function makePool(parent, sub)
    local pool = { items = {}, used = 0 }
    function pool:Get()
        self.used = self.used + 1
        local p = self.items[self.used]
        if not p then
            p = {}
            p.ring = parent:CreateTexture(nil, "ARTWORK", nil, sub or 0)
            p.ring:SetTexture(UI.MEDIA .. "circle")
            p.icon = UI:RoundIcon(parent, 12)
            p.icon:SetDrawLayer("OVERLAY", sub or 0)
            p.icon:SetPoint("CENTER", p.ring, "CENTER")
            self.items[self.used] = p
        end
        p.ring:Show(); p.icon:Show()
        return p
    end
    function pool:Reset()
        for i = 1, #self.items do self.items[i].ring:Hide(); self.items[i].icon:Hide() end
        self.used = 0
    end
    return pool
end

local function paint(p, node, ranks, size, alpha)
    local col = N:Color(node, ranks)
    p.ring:SetSize(size, size)
    p.ring:SetVertexColor(col[1], col[2], col[3], alpha)
    p.icon:SetSize(size - 3, size - 3)
    p.icon:SetTexture(itemIcon(node.id))
    p.icon:SetAlpha(alpha)
end

---------------------------------------------------------------------------
-- Minicarte
---------------------------------------------------------------------------
local MAX_MINI = 60
local holder, pool
local visible, visibleMap, visibleAt, ranks
-- aides communes de la minicarte (UI/MapPins.lua)
local mapSize, viewRadius = UI.MapSize, UI.MiniViewRadius

local function updateMini()
    pool:Reset()
    local o = N:Config()
    if not o.minimap or not WK:FeatureOn("nodes") or not Minimap:IsVisible() then return end
    if IsInInstance and select(2, IsInInstance()) ~= "none" and select(2, IsInInstance()) ~= nil then return end
    local p = WK.modules.Guide:PlayerPos()
    if not p then return end
    local size = mapSize(p.map)
    if not size then return end
    -- liste filtrée : refaite au changement de carte, puis toutes les 5 s (compétence, réglages)
    local now = GetTime()
    if visibleMap ~= p.map or not visibleAt or now - visibleAt > 5 then
        visible, ranks = N:Visible(p.map)
        visibleMap, visibleAt = p.map, now
    end
    if #visible == 0 then return end
    local radius = viewRadius()
    local limit = radius * 0.93
    local half = Minimap:GetWidth() / 2
    local rotate = GetCVar and GetCVar("rotateMinimap") == "1"
    local facing = rotate and GetPlayerFacing and GetPlayerFacing() or nil
    local cs, sn = facing and math.cos(facing) or 1, facing and math.sin(facing) or 0
    local w, h = size[1], size[2]
    local px, py = p.x, p.y
    for i = 1, #visible do
        local n = visible[i]
        local dx, dy = (n.x - px) * w, (py - n.y) * h -- est et nord, en mètres
        if dx < limit and dx > -limit and dy < limit and dy > -limit then
            local d2 = dx * dx + dy * dy
            if d2 < limit * limit then
                if facing then dx, dy = dx * cs + dy * sn, -dx * sn + dy * cs end
                local pin = pool:Get()
                -- plus discret vers le bord
                local edge = math.sqrt(d2) / limit
                paint(pin, n, ranks, o.size or 14, edge > 0.85 and 0.55 or 1)
                pin.ring:ClearAllPoints()
                pin.ring:SetPoint("CENTER", Minimap, "CENTER", dx / radius * half, dy / radius * half)
                if pool.used >= MAX_MINI then break end
            end
        end
    end
end

local function buildMini()
    holder = CreateFrame("Frame", "WarbandKeeperNodePins", Minimap)
    holder:SetAllPoints(Minimap)
    holder:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 4)
    pool = makePool(holder)
    holder.acc = 0
    holder:SetScript("OnUpdate", function(s, el)
        s.acc = s.acc + el
        if s.acc < 0.1 then return end
        s.acc = 0
        updateMini()
    end)
end

-- À appeler quand un réglage change.
function UI:RefreshNodePins()
    visibleAt = nil
    if holder then updateMini() end
    if WK.modules.GatherMap.Redraw then WK.modules.GatherMap.Redraw() end
end

WK:On("PLAYER_LOGIN", function()
    C_Timer.After(2, function() if Minimap and not holder then buildMini() end end)
end)

---------------------------------------------------------------------------
-- Carte du monde (appelé par UI/MapPins.lua)
---------------------------------------------------------------------------
local MAX_MAP = 500
local mapHolder, mapPool

function UI:HideNodePins()
    if mapPool then mapPool:Reset() end
end

function UI:DrawNodePins(cv, mapID, w, h)
    local o = N:Config()
    if not o.map or not WK:FeatureOn("nodes") then return end
    local list, rk = N:Visible(mapID)
    if #list == 0 then return end
    if not mapHolder then
        mapHolder = CreateFrame("Frame", nil, cv)
        mapPool = makePool(mapHolder)
    end
    mapHolder:SetParent(cv)
    mapHolder:SetAllPoints(cv)
    mapHolder.wk = true
    mapHolder:SetFrameLevel((UI.mapBase or cv:GetFrameLevel() or 1) + 2)
    -- une icône par case et par ressource : la carte reste lisible dans les zones très fournies
    local cell = #list > MAX_MAP and 0.02 or 0.008
    local seen = {}
    local size = (o.size or 14) * (w / 1000) * 1.1
    for _, n in ipairs(list) do
        local key = n.id * 1000000 + math.floor(n.x / cell) * 1000 + math.floor(n.y / cell)
        if not seen[key] then
            seen[key] = true
            local pin = mapPool:Get()
            paint(pin, n, rk, size, 1)
            pin.ring:ClearAllPoints()
            pin.ring:SetPoint("CENTER", cv, "TOPLEFT", n.x * w, -n.y * h)
            if mapPool.used >= MAX_MAP then break end
        end
    end
end
