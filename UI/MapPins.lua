local ADDON_NAME, WK = ...
local UI = WK.UI
local T = function(s) return WK.T(s) end

-- Coins de récolte sur la carte du monde : une pastille par coin (Modules/GatherMap.lua),
-- de la couleur de ce qui s'y récolte le plus, plus grosse quand on y a souvent récolté.
local MAX_PINS = 80
local pins = {}

local function canvas()
    local wm = WorldMapFrame
    return wm and wm.ScrollContainer and wm.ScrollContainer.Child
end

local function getPin(i, parent)
    local p = pins[i]
    if not p then
        p = CreateFrame("Button", nil, parent)
        p.glow = p:CreateTexture(nil, "ARTWORK")
        p.glow:SetAllPoints()
        p.glow:SetTexture(UI.MEDIA .. "fxhalo")
        p.glow:SetBlendMode("ADD")
        p.dot = p:CreateTexture(nil, "OVERLAY")
        p.dot:SetPoint("CENTER")
        p.dot:SetTexture(UI.MEDIA .. "circle")
        p:SetScript("OnEnter", function(s)
            local c = s.cluster
            if not c then return end
            WK.UI:TooltipOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetText(T("Coin de récolte"), 1, 1, 1)
            local items = {}
            for id, n in pairs(c.items) do table.insert(items, { id = id, n = n }) end
            table.sort(items, function(a, b) return a.n > b.n end)
            for _, it in ipairs(items) do
                GameTooltip:AddDoubleLine((UI:ItemInfo(it.id)) or "?", "x" .. it.n, 0.9, 0.9, 0.9, 1, 1, 1)
            end
            GameTooltip:AddLine(string.format(T("%d récolte(s) ici · dernière %s"), c.count, UI:Ago(c.last)), 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        p:SetScript("OnLeave", function() GameTooltip:Hide() end)
        pins[i] = p
    end
    p:SetParent(parent)
    return p
end

local function hideAll() for _, p in ipairs(pins) do p:Hide() end end

local function redraw()
    hideAll()
    local cfg = WK.DB.global.gatherMap
    local wm, cv = WorldMapFrame, canvas()
    if not cfg.showMap or not wm or not cv or not wm:IsShown() then return end
    local mapID = wm.GetMapID and wm:GetMapID()
    if not mapID then return end
    local list = WK.modules.GatherMap:Clusters(mapID)
    local w, h = cv:GetWidth(), cv:GetHeight()
    if not w or w <= 0 then return end
    local maxCount = list[1] and list[1].count or 1
    local scale = (w / 1000) -- taille des pastilles relative à la toile de la carte
    for i, c in ipairs(list) do
        if i > MAX_PINS then break end
        local p = getPin(i, cv)
        p.cluster = c
        local size = (14 + 18 * math.sqrt(c.count / maxCount)) * scale
        p:SetSize(size * 1.8, size * 1.8)
        p.dot:SetSize(size * 0.45, size * 0.45)
        local col = WK.modules.GatherMap.COLORS[c.kind] or { 1, 1, 1 }
        p.glow:SetVertexColor(col[1], col[2], col[3], 0.9)
        p.dot:SetVertexColor(col[1], col[2], col[3], 1)
        p:SetFrameLevel((cv:GetFrameLevel() or 1) + 20)
        p:ClearAllPoints()
        p:SetPoint("CENTER", cv, "TOPLEFT", c.x * w, -c.y * h)
        p:Show()
    end
end
WK.modules.GatherMap.Redraw = function() redraw() end

-- La carte du monde se charge parfois après l'addon : on s'y accroche dès qu'elle existe.
local hooked = false
local function hook()
    if hooked or not WorldMapFrame then return end
    hooked = true
    WorldMapFrame:HookScript("OnShow", redraw)
    WorldMapFrame:HookScript("OnHide", hideAll)
    if WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", redraw) end
end
WK:On("PLAYER_LOGIN", hook)
WK:On("ADDON_LOADED", function(name) if name == "Blizzard_WorldMap" then hook() end end)
