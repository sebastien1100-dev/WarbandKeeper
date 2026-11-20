local ADDON_NAME, WK = ...
local UI = WK.UI
local T = function(s) return WK.T(s) end

-- Coins de récolte sur la carte du monde : une pastille par coin (Modules/GatherMap.lua),
-- de la couleur de ce qui s'y récolte le plus, plus grosse quand on y a souvent récolté.
local MAX_PINS = 80
local pins = {}

---------------------------------------------------------------------------
-- Aides communes aux pastilles de la minicarte (UI/NodePins.lua, UI/MapLayers.lua, UI/MapNotes.lua,
-- UI/NavRoute.lua, chargés après ce fichier)
---------------------------------------------------------------------------
-- Zoom de la carte du monde : les pastilles et les tracés gardent à peu près leur taille à l'écran
-- (sans ça, tout grossit avec la carte et devient illisible). Facteur à multiplier aux tailles sur la toile.
-- Taille choisie des icônes de la carte du monde (MapLayers:Config().iconScale, en %, 100 = taille d'origine)
function UI.MapIconSize()
    local L = WK.modules.MapLayers
    local v = L and L.Config and L:Config().iconScale or 100
    return math.max(0.5, math.min(2, (tonumber(v) or 100) / 100))
end
-- Échelle des étiquettes posées sur la toile (comptes à rebours, noms, « mort · … ») : suit le zoom et
-- le réglage de taille des icônes, pour rester à la mesure de l'icône qu'elles accompagnent
function UI.MapLabelScale()
    return math.max(0.4, UI.MapIconScale() * UI.MapIconSize())
end
function UI.MapIconScale()
    local sc = WorldMapFrame and WorldMapFrame.ScrollContainer
    if not (sc and sc.GetCanvasScale) then return 1 end
    local ok, cur = pcall(sc.GetCanvasScale, sc)
    if not (ok and type(cur) == "number" and cur > 0) then return 1 end
    local min
    if sc.GetScaleForMinZoom then
        local ok2, v = pcall(sc.GetScaleForMinZoom, sc)
        if ok2 and type(v) == "number" and v > 0 then min = v end
    end
    min = min or (sc.zoomLevels and sc.zoomLevels[1] and sc.zoomLevels[1].scale) or cur
    local z = cur / min
    if z <= 1.01 then return 1 end
    return 1 / z ^ 0.85 -- grossit un tout petit peu, pour garder la sensation de zoom
end

-- Rayon de la minicarte en mètres du jeu, par niveau de zoom (dehors, dedans)
local RADIUS_OUT = { [0] = 233.3, 200, 166.7, 133.3, 100, 66.7 }
local RADIUS_IN = { [0] = 150, 120, 90, 60, 40, 25 }
function UI.MiniViewRadius()
    if C_Minimap and C_Minimap.GetViewRadius then
        local ok, r = pcall(C_Minimap.GetViewRadius)
        if ok and type(r) == "number" and r > 0 then return r end
    end
    local zoom = Minimap.GetZoom and Minimap:GetZoom() or 0
    return ((IsIndoors and IsIndoors()) and RADIUS_IN or RADIUS_OUT)[zoom] or 233.3
end
-- Taille d'une carte en mètres du jeu : { largeur, hauteur }, ou false (gardée en cache)
local scaleCache = {}
function UI.MapSize(mapID)
    local s = scaleCache[mapID]
    if s == nil then
        local G = WK.modules.Guide
        local c0, n0, w0 = G.ToWorld(mapID, 0, 0)
        local c1, n1, w1 = G.ToWorld(mapID, 1, 1)
        s = (c0 and c1 and n0 and n1) and { math.abs(w1 - w0), math.abs(n1 - n0) } or false
        scaleCache[mapID] = s
    end
    return s
end

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
                    if pin then
                        pin:SetAlpha(a)
                        -- masqué, il ne répond plus à la souris : son infobulle ne passe plus devant la nôtre
                        if pin.EnableMouse then pcall(pin.EnableMouse, pin, a > 0) end
                    end
                end
            end)
        end
    end
end
-- Repères de quête du jeu (point d'exclamation, rendu, zone d'objectif) masqués sur la carte du monde
-- tant que notre calque « Quêtes » est affiché (QuestTrack:Config().hideGame) ; rendus sinon
local QUEST_PIN_TEMPLATES = { "QuestPinTemplate", "QuestBlobPinTemplate", "QuestOfferPinTemplate", "QuestHubPinTemplate",
    "StorylineQuestPinTemplate", "BonusObjectivePinTemplate", "ThreatObjectivePinTemplate" }
local QUEST_TPL = {}
for _, t in ipairs(QUEST_PIN_TEMPLATES) do QUEST_TPL[t] = true end
local function hideGameQuests()
    if not WK:FeatureOn("quests") then return false end
    local QT = WK.modules.QuestTrack
    local c = QT and QT:Config()
    return c and c.hideGame and c.map ~= "off" or false
end
local questPinsHidden, acquireHooked = false, false
local function gameQuestPins()
    local wm = WorldMapFrame
    if not (wm and wm.EnumeratePinsByTemplate) then return end
    -- une pastille de quête reprise par le jeu (journal mis à jour) : masquée à l'image suivante
    if not acquireHooked and wm.AcquirePin then
        acquireHooked = true
        hooksecurefunc(wm, "AcquirePin", function(_, tpl)
            if QUEST_TPL[tpl] and hideGameQuests() then C_Timer.After(0, gameQuestPins) end
        end)
    end
    local hide = hideGameQuests()
    if not hide and not questPinsHidden then return end
    questPinsHidden = hide
    for _, tpl in ipairs(QUEST_PIN_TEMPLATES) do
        local ok, f, st, k0 = pcall(wm.EnumeratePinsByTemplate, wm, tpl)
        if ok and type(f) == "function" then
            pcall(function()
                for k, v in f, st, k0 do
                    local pin = (type(k) == "table" and k.SetAlpha and k) or (type(v) == "table" and v.SetAlpha and v)
                    if pin then
                        pin:SetAlpha(hide and 0 or 1)
                        if pin.EnableMouse then pcall(pin.EnableMouse, pin, not hide) end
                    end
                end
            end)
        end
    end
end
UI.GameQuestPins = gameQuestPins

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
    if UI.HideShips then UI:HideShips() end
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
    -- trois lignes : nom, ce que c'est (« Maître des gryphons »), distance
    local name, sub = G:PlaceParts(t)
    if not name or name == "?" then name, sub = G:PlaceName(t), nil end
    local lines = { name }
    if sub and sub ~= "" then table.insert(lines, UI:Hex(UI.colors.muted) .. sub .. "|r") end
    if d then table.insert(lines, "|cff" .. WK:AccentHex() .. string.format(T("%d m"), math.floor(d)) .. "|r") end
    -- largeur de la ligne la plus longue, mesurée ligne par ligne (la largeur du texte entier, sur plusieurs
    -- lignes, ne correspond à aucune et coupait la destination)
    local wMax = 40
    targetPin.measure = targetPin.measure or UI:Text(targetPin.pill, 11)
    targetPin.measure:Hide()
    for _, ln in ipairs(lines) do
        targetPin.measure:SetText(ln)
        wMax = math.max(wMax, math.ceil(targetPin.measure:GetStringWidth() or 0))
    end
    targetPin.label:SetWidth(wMax + 2)
    if targetPin.label.SetWordWrap then targetPin.label:SetWordWrap(true) end -- garde les retours à la ligne
    targetPin.label:SetText(table.concat(lines, "\n"))
    local hText = math.max(#lines * 13, math.ceil(targetPin.label:GetStringHeight() or 0))
    targetPin.label:SetHeight(hText)
    targetPin.pill:SetSize(wMax + 20, hText + 10)
    targetPin.pill:SetScale(UI.MapLabelScale())
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
        targetPin.label:SetJustifyH("CENTER")
        if targetPin.label.SetSpacing then targetPin.label:SetSpacing(2) end
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
    local size = 24 * ((w / 1000) * UI.MapIconScale()) * UI.MapIconSize()
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
    gameQuestPins()
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
        layer("Brouillard", UI.DrawMapReveal)   -- zones pas encore découvertes (UI/MapReveal.lua)
        layer("Lieux", UI.DrawMapLayers)        -- lieux utiles (UI/MapLayers.lua)
        layer("Filons et plantes", UI.DrawNodePins) -- nœuds récoltés (UI/NodePins.lua)
        layer("Rares", UI.DrawRarePins)         -- rares (UI/RarePins.lua)
        layer("Quêtes", UI.DrawQuestCamps)      -- camps des objectifs de quête (UI/QuestCamps.lua)
        layer("Bateaux", UI.DrawBoatPaths)      -- bateaux appris (UI/NavRoute.lua)
        layer("Navires", UI.DrawShips)          -- lignes du jeu et navires en route (UI/BoatMap.lua)
        layer("Trajet", UI.DrawNavRoute)        -- trajet du guidage (UI/NavRoute.lua)
        layer("Notes", UI.DrawMapNotes)         -- notes de carte perso (UI/MapNotes.lua)
        layer("Repère", function(_, ...) drawTarget(...) end)
    end
    -- Les récoltes ne sont plus dessinées ici : un seul affichage, le calque « Filons et plantes »
    -- (UI/NodePins.lua, filtré par métier et compétence), qui lit les mêmes coins notés par GatherMap.
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
    -- zoom : on redessine aux nouvelles tailles (regroupé : le zoom s'anime sur plusieurs images)
    local zoomPending
    local function onZoom()
        if zoomPending then return end
        zoomPending = true
        C_Timer.After(0.08, function() zoomPending = nil; if WorldMapFrame:IsShown() then redraw("zoom") end end)
    end
    if WorldMapFrame.OnCanvasScaleChanged then hooksecurefunc(WorldMapFrame, "OnCanvasScaleChanged", onZoom) end
    local sc = WorldMapFrame.ScrollContainer
    if sc and sc.SetZoomTarget then hooksecurefunc(sc, "SetZoomTarget", onZoom) end
end
WK:On("PLAYER_LOGIN", hook)
WK:On("ADDON_LOADED", function(name) if name == "Blizzard_WorldMap" then hook() end end)
