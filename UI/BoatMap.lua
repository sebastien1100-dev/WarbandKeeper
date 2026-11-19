local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Navires sur les cartes : trajet du jeu de chaque ligne déjà prise (Modules/BoatLines.lua) en trait fin, et le
-- bateau ou le zeppelin là où il est maintenant (heure calée), qui avance chaque seconde. Survol : ses
-- horaires ; clic : tableau des bateaux. Minicarte : le navire quand il est à portée.
-- Réglage Guide:Config().shipsMap ; calque « Bateaux » de la carte (MapLayers:Config().map.transport).
local BL = function() return WK.modules.BoatLines end
local lines = UI:LinePool(3)
local ships = {}
local state = {} -- carte affichée : { cv, mapID, w, h }

local function on()
    local L = WK.modules.MapLayers
    return WK:FeatureOn("maplayers") and L and L:Config().map.transport and WK.modules.Guide:Config().shipsMap ~= false
end
local function onMini()
    local L = WK.modules.MapLayers
    return WK:FeatureOn("maplayers") and L and L:Config().mini.transport and WK.modules.Guide:Config().shipsMap ~= false
end
local function toMap(c, x, y, mapID)
    if not (C_Map and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return nil end
    local ok, _, pos = pcall(C_Map.GetMapPosFromWorldPos, c, CreateVector2D(x, y), mapID)
    if not (ok and pos) then return nil end
    local mx, my = pos.x, pos.y
    if pos.GetXY then mx, my = pos:GetXY() end
    return mx, my
end
local function colorOf(l)
    if l.kind == "zeppelin" then return C.warning end
    local L = WK.modules.MapLayers
    local tl = L and L.LAYER and L.LAYER.transport
    return (tl and L.FAMILY[tl.family] and L.FAMILY[tl.family].color) or C.positive
end

local function shipTooltip(s)
    local l = s.line
    if not l then return end
    UI:TooltipOwner(s, "ANCHOR_RIGHT")
    local B = BL()
    GameTooltip:SetText(T(l.vessel or "?"), 1, 1, 1)
    GameTooltip:AddLine(B:LineName(l), 0.8, 0.8, 0.8)
    local _, _, _, at, leg, f = B:ShipPos(l)
    local Clock = WK.modules.BoatTimes.Clock
    if at then
        local st = B:State(l, at)
        GameTooltip:AddLine(string.format(T("À quai à %s, départ dans %s"), B:StopName(l, at), st and Clock(st.inn) or "?"), 0.62, 0.85, 0.48)
    elseif leg then
        local nx = leg % #l.stops + 1
        local st = B:State(l, nx)
        local arriveIn = st and math.max(0, st.inn - st.w) or nil
        GameTooltip:AddLine(string.format(T("En route vers %s, arrive dans %s"), B:StopName(l, nx), arriveIn and Clock(arriveIn) or "?"), 1, 1, 1)
    end
    local st1 = B:State(l, 1)
    if st1 then
        GameTooltip:AddDoubleLine(T("Tour"), Clock(st1.P), 0.6, 0.6, 0.6, 1, 1, 1)
        GameTooltip:AddDoubleLine(T("Heure"), st1.est and T("estimée") or T("exacte"), 0.6, 0.6, 0.6, unpack(st1.est and C.gold or C.positive))
    end
    GameTooltip:AddLine(T("Clic : tableau des bateaux"), 0.6, 0.6, 0.6)
    GameTooltip:Show()
end
local function getShip(i, parent)
    local p = ships[i]
    if not p then
        p = CreateFrame("Button", nil, parent)
        p.wk = true
        p.ring = UI:Icon(p, "circle", 20, nil, "BACKGROUND")
        p.ring:SetAllPoints()
        p.icon = UI:Icon(p, "boat", 14, nil, "ARTWORK")
        p.icon:SetPoint("CENTER")
        p:SetScript("OnEnter", shipTooltip)
        p:SetScript("OnLeave", function() GameTooltip:Hide() end)
        p:SetScript("OnClick", function() if UI.ToggleBoatBoard then UI:ToggleBoatBoard(true) end end)
        ships[i] = p
    end
    if p:GetParent() ~= parent then p:SetParent(parent) end
    return p
end
local function paintShip(p, l, size)
    local col = colorOf(l)
    p:SetSize(size, size)
    p.ring:SetVertexColor(col[1], col[2], col[3], 1)
    p.icon:SetTexture(UI.MEDIA .. (l.kind == "zeppelin" and "zeppelin" or "boat"))
    p.icon:SetSize(size * 0.62, size * 0.62)
    p.icon:SetVertexColor(0.06, 0.06, 0.07, 1)
end

-- position des navires (appelé à chaque seconde quand la carte est ouverte)
local function placeShips()
    local cv, mapID, w, h = state.cv, state.mapID, state.w, state.h
    for _, p in ipairs(ships) do if p.map then p:Hide() end end
    if not (cv and on() and cv:IsVisible()) then return end
    local B = BL()
    local scale = (w / 1000) * UI.MapIconScale()
    local size = math.max(12 * UI.MapIconScale(), 16 * scale) * UI.MapIconSize()
    local n = 0
    for _, l in ipairs(B:All()) do
        if B:Mine(l) or not WK.modules.MapLayers:Config().myFaction then
            local c, x, y = B:ShipPos(l)
            if c then
                local mx, my = toMap(c, x, y, mapID)
                if mx and mx > -0.02 and mx < 1.02 and my > -0.02 and my < 1.02 then
                    n = n + 1
                    local p = getShip(n, cv)
                    p.map, p.line = true, l
                    paintShip(p, l, size)
                    p:SetFrameLevel((UI.mapBase or 2000) + 30)
                    p:ClearAllPoints(); p:SetPoint("CENTER", cv, "TOPLEFT", mx * w, -my * h)
                    p:Show()
                end
            end
        end
    end
end

-- Calque « Navires » de la carte du monde (UI/MapPins.lua)
function UI:DrawShips(cv, mapID, w, h)
    lines:Reset()
    state.cv, state.mapID, state.w, state.h = cv, mapID, w, h
    if not on() then placeShips() return end
    local B = BL()
    local scale = (w / 1000) * UI.MapIconScale()
    local thick = math.max(1.4 * UI.MapIconScale(), 2 * scale)
    for _, l in ipairs(B:All()) do
        -- tracé seulement pour les lignes déjà prises
        if B:Rode(l) and (B:Mine(l) or not WK.modules.MapLayers:Config().myFaction) then
            local col = colorOf(l)
            for _, g in ipairs(l.legs) do
                local pts = g.pts
                local px, py, pc
                for k = 1, #pts / 3 do
                    local c, x, y = pts[k * 3 - 2], pts[k * 3 - 1], pts[k * 3]
                    local mx, my = toMap(c, x, y, mapID)
                    local inside = mx and mx > -0.05 and mx < 1.05 and my > -0.05 and my < 1.05
                    if inside and px and pc == c then
                        lines:Add(cv, px * w, py * h, mx * w, my * h, thick, col[1], col[2], col[3], 0.75)
                    end
                    if inside then px, py, pc = mx, my, c else px, py, pc = nil, nil, nil end
                end
            end
        end
    end
    placeShips()
end

local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(s, el)
    s.acc = (s.acc or 0) + el
    if s.acc < 1 then return end
    s.acc = 0
    if state.cv and WorldMapFrame and WorldMapFrame:IsShown() then pcall(placeShips) end
    if Minimap and Minimap:IsVisible() then pcall(UI.RefreshMiniShips, UI) end
end)

---------------------------------------------------------------------------
-- Minicarte : le navire quand il est à portée de vue
---------------------------------------------------------------------------
local mini = {}
function UI:RefreshMiniShips()
    for _, p in ipairs(mini) do p:Hide() end
    if not onMini() then return end
    local G = WK.modules.Guide
    local pl = G and G:PlayerPos()
    if not (pl and pl.cont) then return end
    local radius = UI.MiniViewRadius()
    local half = Minimap:GetWidth() / 2
    local rotate = GetCVar and GetCVar("rotateMinimap") == "1"
    local facing = rotate and GetPlayerFacing and GetPlayerFacing() or nil
    local cs, sn = facing and math.cos(facing) or 1, facing and math.sin(facing) or 0
    local B = BL()
    local n = 0
    for _, l in ipairs(B:All()) do
        if B:Mine(l) then
            local c, x, y = B:ShipPos(l)
            if c == pl.cont then
                local dx, dy = -(y - pl.wy), x - pl.wx
                if dx * dx + dy * dy < (radius * 0.92) ^ 2 then
                    if facing then dx, dy = dx * cs + dy * sn, -dx * sn + dy * cs end
                    n = n + 1
                    local p = mini[n]
                    if not p then
                        p = CreateFrame("Frame", nil, Minimap)
                        p:SetFrameLevel(Minimap:GetFrameLevel() + 8)
                        p.ring = UI:Icon(p, "circle", 16, nil, "BACKGROUND"); p.ring:SetAllPoints()
                        p.icon = UI:Icon(p, "boat", 10, nil, "ARTWORK"); p.icon:SetPoint("CENTER")
                        mini[n] = p
                    end
                    paintShip(p, l, 16)
                    p:ClearAllPoints(); p:SetPoint("CENTER", Minimap, "CENTER", dx / radius * half, dy / radius * half)
                    p:Show()
                end
            end
        end
    end
end
