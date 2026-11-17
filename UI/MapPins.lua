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
        p.wk = true
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

local GAME_PIN_TEMPLATES = { "WaypointLocationPinTemplate", "SuperTrackedWaypointPinTemplate" }
local function gamePinAlpha(a)
    local wm = WorldMapFrame
    if not (wm and wm.EnumeratePinsByTemplate) then return end
    for _, tpl in ipairs(GAME_PIN_TEMPLATES) do
        -- l'énumération du jeu renvoie un itérateur complet (fonction, table, départ), comme pairs()
        local ok, f, st, k0 = pcall(wm.EnumeratePinsByTemplate, wm, tpl)
        if ok and type(f) == "function" then
            pcall(function()
                for k, v in f, st, k0 do
                    local pin = (type(k) == "table" and k.SetAlpha and k) or (type(v) == "table" and v.SetAlpha and v)
                    if pin then pin:SetAlpha(a) end
                end
            end)
        end
    end
end
-- Journal (/wk carte) : redessins et masquages de la carte, pour comprendre une pastille disparue
UI.mapLog = UI.mapLog or {}
local function note(ev)
    local wm = WorldMapFrame
    table.insert(UI.mapLog, string.format("%.1f %s (carte %s)", GetTime(), ev, tostring(wm and wm:IsShown())))
    while #UI.mapLog > 10 do table.remove(UI.mapLog, 1) end
end
UI.MapNote = note
local targetPin
local function hideAll()
    for _, p in ipairs(pins) do p:Hide() end
    if targetPin then targetPin:Hide() end
    gamePinAlpha(1)
    if UI.HideNodePins then UI:HideNodePins() end
    if UI.HideRarePins then UI:HideRarePins() end
    if UI.HideMapLayers then UI:HideMapLayers() end
    if UI.HideNavRoute then UI:HideNavRoute() end
    if UI.HideBoatPaths then UI:HideBoatPaths() end
    if UI.HideMapNotes then UI:HideMapNotes() end
end

-- Repère du guidage sur la carte du monde (Modules/Guide.lua) : épingle de la couleur d'accent avec
-- l'icône de ce qu'on suit, et dessous le nom et la distance restante (même style que l'épingle à
-- l'écran, UI/NavPin.lua). Le losange du point suivi du jeu est masqué sur la carte pendant ce temps.
-- nom et distance sous l'épingle (rappelé chaque seconde par UI/NavRoute.lua quand la carte est ouverte)
function UI:RefreshGuidePinLabel()
    local G = WK.modules.Guide
    local t = G.target
    if not (t and targetPin) then return end
    if G:Config().mapPin then gamePinAlpha(0) end -- le jeu peut réafficher son losange en rafraîchissant la carte
    local d = UI.GuideDistance and UI:GuideDistance(t)
    targetPin.label:SetText(G:PlaceName(t) .. (d and ("  ·  |cff" .. WK:AccentHex() .. string.format(T("%d m"), math.floor(d)) .. "|r") or ""))
    targetPin.pill:SetSize((targetPin.label:GetStringWidth() or 60) + 16, 18)
end
local function drawTarget(cv, mapID, w, h)
    local G = WK.modules.Guide
    local t = G and G.target
    gamePinAlpha(t and G:Config().mapPin and 0 or 1)
    if not t or not G:Config().mapPin or t.map ~= mapID then return end
    if not targetPin then
        targetPin = CreateFrame("Button", nil, cv)
        targetPin.wk = true
        targetPin.shadow = targetPin:CreateTexture(nil, "BACKGROUND")
        targetPin.shadow:SetTexture(UI.MEDIA .. "pin")
        targetPin.shadow:SetVertexColor(0, 0, 0, 0.5)
        targetPin.body = targetPin:CreateTexture(nil, "ARTWORK")
        targetPin.body:SetTexture(UI.MEDIA .. "pin")
        targetPin.body:SetAllPoints()
        targetPin.icon = targetPin:CreateTexture(nil, "OVERLAY")
        targetPin.pill = CreateFrame("Frame", nil, targetPin)
        targetPin.pill.bg = UI:Rounded(targetPin.pill, 9, 0, "BACKGROUND", 1)
        targetPin.label = UI:Text(targetPin.pill, 11)
        targetPin.label:SetPoint("CENTER")
        targetPin:SetScript("OnEnter", function(s)
            WK.UI:TooltipOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetText(G:PlaceName(G.target), 1, 1, 1)
            if G.target and G.target.reason then GameTooltip:AddLine(T(G.target.reason), 0.8, 0.8, 0.8) end
            GameTooltip:AddLine(T("Guidage Warband Keeper · clic droit pour arrêter"), 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        targetPin:SetScript("OnLeave", function() GameTooltip:Hide() end)
        targetPin:SetScript("OnMouseUp", function(_, b) if b == "RightButton" then G:Stop() end end)
    end
    targetPin:SetParent(cv)
    local size = 30 * (w / 1000)
    targetPin:SetSize(size, size)
    targetPin.shadow:SetSize(size * 1.06, size * 1.06)
    targetPin.shadow:ClearAllPoints()
    targetPin.shadow:SetPoint("CENTER", size * 0.03, -size * 0.06)
    targetPin.icon:SetSize(size * 0.44, size * 0.44)
    targetPin.icon:ClearAllPoints()
    targetPin.icon:SetPoint("CENTER", targetPin, "TOP", 0, -size * 0.38)
    targetPin.icon:SetTexture(UI.MEDIA .. (UI.GuideIcon and UI:GuideIcon(t) or "guide"))
    local C = UI.colors
    targetPin.icon:SetVertexColor(C.bg[1], C.bg[2], C.bg[3], 1)
    local r, g, b = UI:Accent()
    targetPin.body:SetVertexColor(r, g, b, 1)
    UI:RefreshGuidePinLabel()
    targetPin.pill:ClearAllPoints()
    targetPin.pill:SetPoint("TOP", targetPin, "BOTTOM", 0, -2)
    targetPin.pill.bg:SetColor(C.bg[1], C.bg[2], C.bg[3], 0.85)
    targetPin:SetFrameLevel((UI.mapBase or cv:GetFrameLevel() or 1) + 40)
    targetPin:ClearAllPoints()
    targetPin:SetPoint("BOTTOM", cv, "TOPLEFT", t.x * w, -t.y * h) -- la pointe de l'épingle sur le lieu
    targetPin:Show()
end

local function redraw(src)
    note("redessin" .. (type(src) == "string" and (" · " .. src) or ""))
    hideAll()
    local cfg = WK.DB.global.gatherMap
    local wm, cv = WorldMapFrame, canvas()
    if not wm or not cv or not wm:IsShown() then return end
    local mapID = wm.GetMapID and wm:GetMapID()
    if not mapID then return end
    local cw, ch = cv:GetWidth(), cv:GetHeight()
    if cw and cw > 0 then
        -- chaque calque à part : une erreur dans l'un n'empêche pas les autres de s'afficher
        -- (elle est notée une fois dans le chat, avec le nom du calque)
        UI.mapStats = { map = mapID, w = cw, h = ch, level = cv:GetFrameLevel(), strata = cv.GetFrameStrata and cv:GetFrameStrata() }
        -- plus haut niveau des cadres du jeu sur la toile (calques de la carte, pastilles de quête…) :
        -- nos pastilles se placent au-dessus (UI.mapBase), quel que soit le client
        local top = cv:GetFrameLevel() or 1
        if cv.GetChildren then
            for _, ch2 in ipairs({ cv:GetChildren() }) do
                if not ch2.wk and ch2.GetFrameLevel then
                    local lv = ch2:GetFrameLevel() or 0
                    if lv > top then top = lv end
                end
            end
        end
        UI.mapBase = math.min(top + 5, 9000)
        UI.mapStats.gameTop = top
        local function layer(name, fn)
            if not fn then return end
            local ok, err = pcall(fn, UI, cv, mapID, cw, ch)
            UI.mapStats[name] = ok and "ok" or "erreur"
            if not ok then
                UI.mapErrors = UI.mapErrors or {}
                if not UI.mapErrors[name] then
                    UI.mapErrors[name] = tostring(err)
                    WK:Print(string.format(T("Carte : le calque « %s » a rencontré une erreur (/wk carte pour le détail)."), T(name)))
                end
            end
        end
        layer("Lieux", UI.DrawMapLayers)        -- lieux utiles (UI/MapLayers.lua)
        layer("Filons et plantes", UI.DrawNodePins) -- nœuds récoltés (UI/NodePins.lua)
        layer("Rares", UI.DrawRarePins)         -- rares (UI/RarePins.lua)
        layer("Bateaux", UI.DrawBoatPaths)      -- bateaux appris (UI/NavRoute.lua)
        layer("Trajet", UI.DrawNavRoute)        -- trajet du guidage (UI/NavRoute.lua)
        layer("Notes", UI.DrawMapNotes)         -- notes de carte perso (UI/MapNotes.lua)
        layer("Repère", function(_, ...) drawTarget(...) end)
    end
    if not cfg.showMap then return end
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
        p:SetFrameLevel((UI.mapBase or cv:GetFrameLevel() or 1) + 5)
        p:ClearAllPoints()
        p:SetPoint("CENTER", cv, "TOPLEFT", c.x * w, -c.y * h)
        p:Show()
    end
end
WK.modules.GatherMap.Redraw = function() redraw("récolte") end
WK.modules.Guide.Redraw = function() redraw("guidage") end
UI.RedrawWorldMap = redraw

-- La carte du monde se charge parfois après l'addon : on s'y accroche dès qu'elle existe.
local hooked = false
local function hook()
    if hooked or not WorldMapFrame then return end
    hooked = true
    WorldMapFrame:HookScript("OnShow", function() redraw("ouverture") end)
    WorldMapFrame:HookScript("OnHide", function()
        note("fermeture"); hideAll()
        if UI.MapLayersReset then UI:MapLayersReset() end
    end)
    if WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", function() redraw("changement de carte") end) end
end
WK:On("PLAYER_LOGIN", hook)
WK:On("ADDON_LOADED", function(name) if name == "Blizzard_WorldMap" then hook() end end)
