local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Points /way sur la carte du monde (Modules/Waypoints.lua) : pastilles numérotées de la file (calque
-- « Points /way » de UI/MapPins.lua), petite liste sur le côté de la carte, Ctrl + clic droit pour poser un
-- point (comme TomTom), clic droit sur un point : guider, renommer, garder en note de carte, partager,
-- supprimer. Fenêtre de renommage. Réglages : carte « Points /way » de QoL > Carte et guidage > Guidage.
local function W() return WK.modules.Waypoints end
local CreateFrame = CreateFrame

---------------------------------------------------------------------------
-- Menu du clic droit et fenêtre de renommage
---------------------------------------------------------------------------
local menu, blocker
local function buildMenu()
    blocker = CreateFrame("Button", nil, UIParent)
    blocker:SetAllPoints(UIParent); blocker:SetFrameStrata("FULLSCREEN_DIALOG"); blocker:SetFrameLevel(1)
    blocker:RegisterForClicks("AnyUp")
    blocker:SetScript("OnClick", function() menu:Hide() end)
    blocker:Hide()
    local f = CreateFrame("Frame", "WarbandKeeperWayMenu", UIParent)
    f:SetFrameStrata("FULLSCREEN_DIALOG"); f:SetFrameLevel(50); f:SetClampedToScreen(true)
    UI:Panel(f, 8, C.surface, C.border)
    f.items = {}
    f:SetScript("OnHide", function() blocker:Hide() end)
    if UISpecialFrames then table.insert(UISpecialFrames, "WarbandKeeperWayMenu") end
    f:Hide()
    return f
end
local function menuItem(i)
    local b = menu.items[i]
    if not b then
        b = CreateFrame("Button", nil, menu); b:SetHeight(24)
        b.hl = UI:Rounded(b, 5, 0, "BACKGROUND", 2); b.hl:Hide()
        b.t = UI:Text(b, 12); b.t:SetPoint("LEFT", 10, 0); b.t:SetPoint("RIGHT", -10, 0)
        b:SetScript("OnEnter", function(s)
            local r, g, bl = UI:Accent()
            s.hl:SetColor(r, g, bl, 0.14); s.hl:Show()
        end)
        b:SetScript("OnLeave", function(s) s.hl:Hide() end)
        b:SetScript("OnClick", function(s) menu:Hide(); if s.fn then s.fn() end end)
        menu.items[i] = b
    end
    return b
end

local ask
function UI:AskWayName(w)
    if not ask then
        local f = CreateFrame("Frame", "WarbandKeeperWayName", UIParent)
        f:SetSize(320, 112); f:SetPoint("CENTER", 0, 120)
        f:SetFrameStrata("FULLSCREEN_DIALOG"); f:EnableMouse(true); f:SetClampedToScreen(true)
        UI:Panel(f, 10, C.surface, C.border)
        f.title = UI:Text(f, 13); f.title:SetPoint("TOPLEFT", 14, -12)
        local eb = CreateFrame("EditBox", nil, f)
        eb:SetPoint("TOPLEFT", 14, -38); eb:SetPoint("TOPRIGHT", -14, -38); eb:SetHeight(26)
        eb:SetAutoFocus(true); eb:SetMaxLetters(60)
        eb:SetFontObject(ChatFontNormal or GameFontHighlight); eb:SetTextInsets(8, 8, 0, 0)
        eb.bg = UI:Rounded(eb, 6, 0, "BACKGROUND", 1); eb.bg:SetColor(C.bg[1], C.bg[2], C.bg[3], 1)
        f.eb = eb
        local ok = UI:Button(f, T("Renommer"), 110, 24, "primary"); ok:SetPoint("BOTTOMRIGHT", -12, 10)
        local cancel = UI:Button(f, T("Annuler"), 90, 24, "ghost"); cancel:SetPoint("RIGHT", ok, "LEFT", -8, 0)
        local function apply() if f.w then W():Rename(f.w, eb:GetText()) end f:Hide() end
        ok:SetScript("OnClick", apply)
        cancel:SetScript("OnClick", function() f:Hide() end)
        eb:SetScript("OnEnterPressed", apply)
        eb:SetScript("OnEscapePressed", function() f:Hide() end)
        if UISpecialFrames then table.insert(UISpecialFrames, "WarbandKeeperWayName") end
        ask = f
    end
    ask.w = w
    ask.title:SetText(T("Nom du point"))
    ask.eb:SetText(w.title or "")
    ask:Show(); ask.eb:SetFocus(); ask.eb:HighlightText()
end

function UI:WayMenu(w)
    if not w then return end
    menu = menu or buildMenu()
    local Wm = W()
    local entries = {
        { T("Guider ici"), function() Wm:Focus(w) end },
        { T("Renommer"), function() UI:AskWayName(w) end },
        { T("Garder en note de carte"), function() Wm:ToNote(w) end },
        { T("Partager au groupe"), function() Wm:Share(w) end },
        { T("Supprimer"), function() Wm:Remove(w) end, true },
        { T("Tout effacer"), function() Wm:Clear() end, true },
    }
    local width = 200
    for i, e in ipairs(entries) do
        local b = menuItem(i)
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", 5, -5 - (i - 1) * 24); b:SetPoint("TOPRIGHT", -5, -5 - (i - 1) * 24)
        b.t:SetText(e[1]); b.t:SetTextColor(unpack(e[3] and C.negative or C.text)); b.fn = e[2]
        b:Show()
        width = math.max(width, (b.t:GetStringWidth() or 0) + 40)
    end
    for i = #entries + 1, #menu.items do menu.items[i]:Hide() end
    menu:SetSize(width, 10 + #entries * 24)
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    menu:ClearAllPoints(); menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s + 2, y / s - 2)
    blocker:Show(); menu:Show(); menu:Raise()
end

---------------------------------------------------------------------------
-- Calque de la carte du monde : pastilles numérotées
---------------------------------------------------------------------------
local pins = {}
local function pin(i, cv)
    local p = pins[i]
    if not p then
        p = CreateFrame("Button", nil, cv)
        p.wk = true
        p:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        p.edge = p:CreateTexture(nil, "ARTWORK", nil, 0); p.edge:SetTexture(UI.MEDIA .. "circle"); p.edge:SetAllPoints()
        p.dot = p:CreateTexture(nil, "ARTWORK", nil, 1); p.dot:SetTexture(UI.MEDIA .. "circle")
        p.dot:SetPoint("TOPLEFT", 2, -2); p.dot:SetPoint("BOTTOMRIGHT", -2, 2)
        p.num = UI:Text(p, 11, C.bg); p.num:SetPoint("CENTER", 0, 0)
        p:SetScript("OnEnter", function(s)
            local w = s.w
            if not w then return end
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetText(W().Label(w), 1, 1, 1)
            GameTooltip:AddLine(W():ZoneName(w.map) .. " " .. W().CoordsText(w), C.muted[1], C.muted[2], C.muted[3])
            local d = W():Distance(w)
            if d then GameTooltip:AddLine(string.format(T("%d m"), math.floor(d + 0.5)), C.text[1], C.text[2], C.text[3]) end
            GameTooltip:AddLine(T("Clic : guider ici · clic droit : menu"), C.dim[1], C.dim[2], C.dim[3])
            GameTooltip:Show()
        end)
        p:SetScript("OnLeave", function() GameTooltip:Hide() end)
        p:SetScript("OnClick", function(s, btn)
            if not s.w then return end
            if btn == "RightButton" then UI:WayMenu(s.w) else W():Focus(s.w) end
        end)
        pins[i] = p
    end
    if p:GetParent() ~= cv then p:SetParent(cv) end
    return p
end
function UI:DrawWaypoints(cv, mapID, w, h)
    for _, p in ipairs(pins) do p:Hide() end
    if not (WK:FeatureOn("maplayers") and W()) then return end
    local lvl = (UI.mapBase or cv:GetFrameLevel() or 1) + 34
    local r, g, b = UI:Accent()
    local n = 0
    for i, wp in ipairs(W():List()) do
        local x, y
        if wp.map == mapID then x, y = wp.x, wp.y
        elseif UI.WorldToMap then
            -- avant, GetMapPosFromWorldPos était appelé directement : faux sur la carte d'Azeroth (points mal
            -- placés). UI.WorldToMap (UI/NavRoute.lua) gère cette carte, comme le repère du guidage
            local cont, wx, wy = WK.modules.Guide.ToWorld(wp.map, wp.x, wp.y)
            if cont then x, y = UI.WorldToMap(cont, wx, wy, mapID) end
            if x and y and (x < 0 or x > 1 or y < 0 or y > 1) then x = nil end
            if not y then x = nil end
        end
        if x then
            n = n + 1
            local p = pin(n, cv)
            -- même échelle que les autres calques (taille de la toile, échelle des icônes de la carte) : avant, une
            -- taille fixe devenait énorme quand on zoomait
            local base = i == 1 and 22 or 18
            local sc = UI.MapIconScale and UI.MapIconScale() or 1
            local size = math.max(base * 0.6 * sc, base * (w / 1000) * sc) * (UI.MapIconSize and UI.MapIconSize() or 1)
            p:SetSize(size, size)
            p.edge:SetVertexColor(C.bg[1], C.bg[2], C.bg[3], 1)
            p.dot:SetVertexColor(r, g, b, i == 1 and 1 or 0.85)
            p.num:SetText(tostring(i))
            if p.num.SetScale then pcall(p.num.SetScale, p.num, math.max(0.5, math.min(1.6, size / 20))) end
            p.w = wp
            p:SetFrameLevel(lvl)
            p:ClearAllPoints(); p:SetPoint("CENTER", cv, "TOPLEFT", x * w, -y * h)
            p:Show()
        end
    end
    UI:RefreshWaypointList()
end

---------------------------------------------------------------------------
-- Liste sur le côté de la carte
---------------------------------------------------------------------------
local list
local ROWS = 8
local function buildList()
    local host = WorldMapFrame and (WorldMapFrame.ScrollContainer or WorldMapFrame)
    if not host then return nil end
    local f = CreateFrame("Frame", "WarbandKeeperWayList", host)
    f.wk = true
    f:SetSize(210, 40)
    f:SetPoint("TOPRIGHT", host, "TOPRIGHT", -10, -40)
    f:SetFrameLevel(((host.GetFrameLevel and host:GetFrameLevel()) or 1) + 600)
    UI:Panel(f, 10, { C.bg[1], C.bg[2], C.bg[3], 0.94 }, C.border)
    f.head = UI:Text(f, 10, C.muted); f.head:SetPoint("TOPLEFT", 10, -8)
    f.clear = UI:IconButton(f, "close", 16, "Tout effacer")
    f.clear:SetPoint("TOPRIGHT", -6, -5)
    f.clear:SetScript("OnClick", function() W():Clear() end)
    f.rows = {}
    for i = 1, ROWS do
        local r = CreateFrame("Button", nil, f)
        r:SetHeight(20)
        r:SetPoint("TOPLEFT", 8, -24 - (i - 1) * 21); r:SetPoint("TOPRIGHT", -8, -24 - (i - 1) * 21)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r.dot = r:CreateTexture(nil, "ARTWORK"); r.dot:SetTexture(UI.MEDIA .. "circle"); r.dot:SetSize(16, 16); r.dot:SetPoint("LEFT", 0, 0)
        r.num = UI:Text(r, 9, C.bg); r.num:SetPoint("CENTER", r.dot, "CENTER")
        r.d = UI:Text(r, 10, C.dim); r.d:SetPoint("RIGHT", 0, 0); r.d:SetJustifyH("RIGHT")
        r.t = UI:Text(r, 11, C.text); r.t:SetPoint("LEFT", 22, 0); r.t:SetPoint("RIGHT", r.d, "LEFT", -6, 0); r.t:SetJustifyH("LEFT")
        if r.t.SetWordWrap then r.t:SetWordWrap(false) end
        r:SetScript("OnClick", function(s, btn)
            if not s.w then return end
            if btn == "RightButton" then UI:WayMenu(s.w) else W():Focus(s.w) end
        end)
        r:Hide()
        f.rows[i] = r
    end
    f:Hide()
    return f
end
function UI:RefreshWaypointList()
    if not (W() and WorldMapFrame and WorldMapFrame:IsShown()) then if list then list:Hide() end return end
    local items = W():List()
    if #items == 0 or not W():Config().sideList or not WK:FeatureOn("maplayers") then if list then list:Hide() end return end
    list = list or buildList()
    if not list then return end
    local r, g, b = UI:Accent()
    list.head:SetText(UI:Upper(T("Points /way")) .. "  " .. #items)
    for i, row in ipairs(list.rows) do
        local wp = items[i]
        if wp then
            row.w = wp
            row.dot:SetVertexColor(r, g, b, i == 1 and 1 or 0.8)
            row.num:SetText(tostring(i))
            row.t:SetText(W().Label(wp))
            local d = W():Distance(wp)
            row.d:SetText(d and (d >= 1000 and string.format("%.1f km", d / 1000) or string.format(T("%d m"), math.floor(d + 0.5))) or "")
            row:Show()
        else
            row:Hide(); row.w = nil
        end
    end
    list:SetHeight(30 + math.min(#items, ROWS) * 21)
    list:Show()
end

---------------------------------------------------------------------------
-- Ctrl + clic droit sur la carte : poser un point
---------------------------------------------------------------------------
local hooked
local function hookMap()
    if hooked or not (WorldMapFrame and WorldMapFrame.ScrollContainer) then return end
    hooked = true
    -- carte et curseur relevés à l'appui : au relâchement, le jeu a déjà pu changer de carte (le clic droit
    -- remonte à la carte parente), et le point serait posé ailleurs
    local down
    _G.WorldMapFrame.ScrollContainer:HookScript("OnMouseDown", function(sc, button)
        down = nil
        if button ~= "RightButton" or not sc.GetNormalizedCursorPosition then return end
        local x, y = sc:GetNormalizedCursorPosition()
        down = { map = _G.WorldMapFrame.GetMapID and _G.WorldMapFrame:GetMapID(), x = x, y = y, at = _G.GetTime() }
    end)
    _G.WorldMapFrame.ScrollContainer:HookScript("OnMouseUp", function(sc, button)
        local d = down
        down = nil
        if button ~= "RightButton" or not (IsControlKeyDown and IsControlKeyDown()) or not W() then return end
        local mapID, x, y
        if d and _G.GetTime() - d.at < 1 then
            mapID, x, y = d.map, d.x, d.y
        else
            mapID = _G.WorldMapFrame.GetMapID and _G.WorldMapFrame:GetMapID()
            if sc.GetNormalizedCursorPosition then x, y = sc:GetNormalizedCursorPosition() end
        end
        if not mapID or not x or x < 0 or x > 1 or y < 0 or y > 1 then return end
        W():Add(mapID, x, y, nil, { src = "map" })
    end)
    if _G.WorldMapFrame.HookScript then _G.WorldMapFrame:HookScript("OnHide", function() if list then list:Hide() end end) end
end
WK:On("PLAYER_LOGIN", hookMap)
WK:On("ADDON_LOADED", function(name) if name == "Blizzard_WorldMap" then hookMap() end end)
