local ADDON_NAME, WK = ...
local UI = WK.UI
local T = function(s) return WK.T(s) end

-- Coins de récolte sur la carte du monde : une pastille par coin (Modules/GatherMap.lua),
-- de la couleur de ce qui s'y récolte le plus, plus grosse quand on y a souvent récolté.

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
-- Repères de quête du jeu : nos zones de quête (ancien calque « Quêtes ») ont été retirées ; les réglages du jeu
-- que l'addon avait mis à « 0 » pour la minicarte (QuestTrack:Config().gameCVars) sont rendus une fois
WK:On("PLAYER_LOGIN", function()
    local QT = WK.modules.QuestTrack
    local c = QT and QT:Config()
    if not (c and c.gameCVars) then return end
    for name, v in pairs(c.gameCVars) do WK.SetCVar(name, v) end
    c.gameCVars = nil
    if Minimap then
        for _, fn in ipairs({ "SetQuestBlobInsideAlpha", "SetQuestBlobOutsideAlpha", "SetQuestBlobRingAlpha" }) do
            if Minimap[fn] then pcall(Minimap[fn], Minimap, 1) end
        end
    end
end)

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
    -- épingle pas posée sur cette carte (continent, zone parente) : le losange du jeu reste visible
    if not (t and targetPin and targetPin:IsShown()) then return end
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
    -- repère du jeu masqué seulement là où notre épingle est posée : sur une autre carte (continent, zone
    -- parente), il reste visible (avant, la destination n'apparaissait plus du tout)
    -- sur une autre carte (continent, zone parente) : notre épingle y est posée aussi (position du monde
    -- projetée sur la carte affichée) et le losange du jeu est masqué ; avant, il restait visible à côté
    if not (t and G:Config().mapPin) then gamePinAlpha(1); if targetPin then targetPin:Hide() end return end
    local px, py = t.x, t.y
    if t.map ~= mapID then
        px, py = nil, nil
        local cont, wx, wy = G.ToWorld(t.map, t.x, t.y)
        if cont and UI.WorldToMap then px, py = UI.WorldToMap(cont, wx, wy, mapID) end
        if not (px and py and px >= 0 and px <= 1 and py >= 0 and py <= 1) then
            gamePinAlpha(1); if targetPin then targetPin:Hide() end return
        end
    end
    gamePinAlpha(0)
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
            if G.target and G.target.reason then GameTooltip:AddLine(T(G.target.reason), UI.RGB(UI.colors.muted)) end
            local d = G.target and UI.GuideDistance and UI:GuideDistance(G.target)
            if d then GameTooltip:AddLine(string.format(T("%d m"), math.floor(d)), UI:Accent()) end
            GameTooltip:AddLine(T("Guidage Warband Keeper · clic droit pour arrêter"), UI.RGB(UI.colors.dim))
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
    -- pas d'étiquette sous l'épingle (elle chargeait la carte) : nom et distance dans l'infobulle au survol
    targetPin.pill:Hide()
    targetPin:SetFrameLevel((UI.mapBase or cv:GetFrameLevel() or 1) + 40)
    targetPin:ClearAllPoints()
    targetPin:SetPoint("BOTTOM", cv, "TOPLEFT", px * w, -py * h) -- la pointe de l'épingle sur le lieu
    targetPin:Show()
end

local function redraw(src)
    note("redessin" .. (type(src) == "string" and (" · " .. src) or ""))
    hideAll()
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
        layer("Bateaux", UI.DrawBoatPaths)      -- bateaux appris (UI/NavRoute.lua)
        layer("Navires", UI.DrawShips)          -- lignes du jeu et navires en route (UI/BoatMap.lua)
        layer("Trajet", UI.DrawNavRoute)        -- trajet du guidage (UI/NavRoute.lua)
        layer("Notes", UI.DrawMapNotes)         -- notes de carte perso (UI/MapNotes.lua)
        layer("Points /way", UI.DrawWaypoints)  -- file des points /way (UI/Waypoints.lua)
        layer("Repère", function(_, ...) drawTarget(...) end)
        layer("Quêtes de la zone", UI.DrawMapQuestCount) -- étiquettes faites / en cours / à prendre
    end
    -- Les récoltes ne sont plus dessinées ici : un seul affichage, le calque « Filons et plantes »
    -- (UI/NodePins.lua, filtré par métier et compétence), qui lit les mêmes coins notés par GatherMap.
end
WK.modules.GatherMap.Redraw = function() redraw("récolte") end
WK.modules.Guide.Redraw = function() redraw("guidage") end
UI.RedrawWorldMap = redraw

-- Quêtes de la zone affichée (maquette C) : étiquettes en haut à droite de la carte, « 18 / 42 faites »,
-- « 5 en cours », « 7 à prendre » ; une seule étiquette verte « tout fait » quand la zone est finie. Perso
-- connecté, mêmes comptes que la page Quêtes (Quests:Zones). Opacité réglée dans la roue de la page Quêtes
-- (questTrack.mapCountAlpha), pleine au survol ; survol = quêtes à prendre, clic = page Quêtes sur la zone.
local qcount
-- étiquette compacte : une icône et le nombre (le détail est dans l'infobulle)
local function qtag(parent)
    local t = _G.CreateFrame("Frame", nil, parent)
    t:SetHeight(20)
    UI:Panel(t, 6, { 0, 0, 0, 1 }, UI.colors.border)
    t.icon = UI:Icon(t, "bang", 12)
    t.icon:SetPoint("LEFT", 6, 0)
    t.text = UI:Text(t, 11)
    t.text:SetPoint("LEFT", t.icon, "RIGHT", 4, 0)
    return t
end
local function paintTag(t, txt, col, fill, icon)
    local C = UI.colors
    t.text:SetText(txt)
    t.text:SetTextColor(col[1], col[2], col[3])
    t.icon:SetShown(icon ~= nil)
    if icon then t.icon:SetTexture(UI.MEDIA .. icon); t.icon:SetVertexColor(col[1], col[2], col[3]) end
    t.text:ClearAllPoints()
    if icon then t.text:SetPoint("LEFT", t.icon, "RIGHT", 4, 0) else t.text:SetPoint("LEFT", 8, 0) end
    t:SetWidth(math.floor((t.text:GetStringWidth() or 20) + (icon and 30 or 16)))
    if fill then
        local function mix(k) return col[k] * 0.25 + C.bg[k] * 0.75 end
        t.bg:SetColor(mix(1), mix(2), mix(3), 0.95)
        t.border:SetColor(col[1], col[2], col[3], 0.75)
    else
        t.bg:SetColor(C.bg[1], C.bg[2], C.bg[3], 0.95)
        t.border:SetColor(C.border[1], C.border[2], C.border[3], 1)
    end
    t:Show()
end
local function buildQCount(host)
    local f = _G.CreateFrame("Button", "WarbandKeeperMapQuests", host)
    f.wk = true
    f:SetSize(10, 22)
    f.tags = { qtag(f), qtag(f), qtag(f) }
    -- opacité réglée, pleine au survol (registre commun de UI/Theme.lua)
    UI:HudRegister(f).hudCustom = true
    f.OnHudPaint = function(s)
        local QT = WK.modules.QuestTrack
        s:SetAlpha(s.hudHover and 1 or (QT and QT:Config().mapCountAlpha or 0.92))
    end
    f:SetScript("OnEnter", function(s)
        local Q = WK.modules.Quests
        if not (s.zone and Q) then return end
        UI:TooltipOwner(s, "ANCHOR_BOTTOMLEFT")
        _G.GameTooltip:SetText(s.zone.name or "?", 1, 1, 1)
        local C = UI.colors
        local z = s.zone
        _G.GameTooltip:AddLine(string.format(T("%d / %d quêtes faites"), z.done, z.total),
            C.text[1], C.text[2], C.text[3])
        if (z.log or 0) > 0 then
            _G.GameTooltip:AddLine(string.format(T("%d en cours"), z.log), C.gold[1], C.gold[2], C.gold[3])
        end
        local nAvail = (z.avail or 0) - (z.log or 0)
        if nAvail > 0 then
            local ar, ag, ab = UI:Accent()
            _G.GameTooltip:AddLine(string.format(T("%d à prendre"), nAvail), ar, ag, ab)
        end
        local avail = {}
        local c = WK.DB:Me()
        for _, q in ipairs(Q:OnMap(z.map)) do
            if Q:ForChar(q, c) and Q:State(q, c) == "avail" then avail[#avail + 1] = q end
        end
        table.sort(avail, function(a, b) return (a.lvl or 0) < (b.lvl or 0) end)
        if #avail > 0 then
            _G.GameTooltip:AddLine(" ")
            _G.GameTooltip:AddLine(T("À prendre :"), C.muted[1], C.muted[2], C.muted[3])
            for i = 1, math.min(10, #avail) do
                local q = avail[i]
                _G.GameTooltip:AddLine(string.format("[%d] %s", q.lvl or 0, Q:Name(q) or "?"), 0.9, 0.9, 0.9)
            end
            if #avail > 10 then
                _G.GameTooltip:AddLine(string.format(T("et %d de plus"), #avail - 10), C.dim[1], C.dim[2], C.dim[3])
            end
        end
        _G.GameTooltip:AddLine(" ")
        _G.GameTooltip:AddLine(T("Clic : page Quêtes sur cette zone"), 0.6, 0.6, 0.6)
        _G.GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() _G.GameTooltip:Hide() end)
    f:SetScript("OnClick", function(s)
        if not s.zone then return end
        local def = UI:EnsurePage("quests")
        if def then def.zone = s.zone.map end
        UI:ShowPage("quests")
        if def and def.Refresh then pcall(def.Refresh, def) end
    end)
    return f
end
function UI.DrawMapQuestCount(_, _, mapID)
    local QT, Q = WK.modules.QuestTrack, WK.modules.Quests
    local host = _G.WorldMapFrame and (_G.WorldMapFrame.ScrollContainer or _G.WorldMapFrame)
    if not (QT and Q and host) then return end
    local z
    if QT:Config().mapCount and WK:PageOn("quests") then
        for _, e in ipairs(Q:Zones()) do if e.map == mapID then z = e break end end
    end
    if not z then if qcount then qcount:Hide() end return end
    qcount = qcount or buildQCount(host)
    qcount.zone = z
    qcount:SetFrameLevel(((host.GetFrameLevel and host:GetFrameLevel()) or 1) + 620)
    local C = UI.colors
    local tags = qcount.tags
    for _, t in ipairs(tags) do t:Hide(); t:ClearAllPoints() end
    local shown = {}
    if z.done >= z.total then
        paintTag(tags[1], tostring(z.total), C.positive, true, "star")
        shown[1] = tags[1]
    else
        paintTag(tags[1], z.done .. "/" .. z.total, C.text, false, "notes")
        shown[1] = tags[1]
        if (z.log or 0) > 0 then
            paintTag(tags[2], tostring(z.log), C.gold, true, "clock"); shown[#shown + 1] = tags[2]
        end
        local avail = (z.avail or 0) - (z.log or 0)
        if avail > 0 then
            local ar, ag, ab = UI:Accent()
            paintTag(tags[3], tostring(avail), { ar, ag, ab }, true, "bang")
            shown[#shown + 1] = tags[3]
        end
    end
    local w = 0
    for i, t in ipairs(shown) do
        if i == 1 then t:SetPoint("LEFT", qcount, "LEFT", 0, 0)
        else t:SetPoint("LEFT", shown[i - 1], "RIGHT", 4, 0) end
        w = w + t:GetWidth() + (i > 1 and 4 or 0)
    end
    qcount:SetWidth(math.max(10, w))
    -- en haut à droite ; à gauche de la liste des rares quand elle y est
    qcount:ClearAllPoints()
    local rare = _G.WarbandKeeperRareList
    if rare and rare:IsShown() and rare:GetParent() == host then
        qcount:SetPoint("TOPRIGHT", rare, "TOPLEFT", -6, 0)
    else
        qcount:SetPoint("TOPRIGHT", host, "TOPRIGHT", -10, -10)
    end
    qcount:OnHudPaint()
    qcount:Show()
end

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
