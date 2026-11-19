local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Lieux utiles sur les cartes (Modules/MapLayers.lua) :
--   carte du monde : une pastille par lieu (anneau de la couleur de sa famille, icône dedans ; survol :
--   nom et rôle ; clic : guidage), les trajets des bateaux et zeppelins en pointillés vers leur
--   destination, et une barre de filtres en haut de la carte (clic : la famille ; clic droit : le détail) ;
--   minicarte : les mêmes pastilles autour du joueur, sans capter la souris.
local L = WK.modules.MapLayers
local DOTS = 9 -- points d'un tracé

local function on() return WK:FeatureOn("maplayers") end
local function familyColor(l) return L.FAMILY[l.family].color end

---------------------------------------------------------------------------
-- Carte du monde
---------------------------------------------------------------------------
local pins, routes = {}, {}
local function getPin(i, cv)
    local p = pins[i]
    if not p then
        p = CreateFrame("Button", nil, cv)
        p.wk = true
        p.ring = p:CreateTexture(nil, "ARTWORK")
        p.ring:SetAllPoints()
        p.ring:SetTexture(UI.MEDIA .. "circle")
        p.inner = p:CreateTexture(nil, "ARTWORK", nil, 1)
        p.inner:SetPoint("CENTER")
        p.inner:SetTexture(UI.MEDIA .. "circle")
        p.icon = p:CreateTexture(nil, "OVERLAY")
        p.icon:SetPoint("CENTER")
        p:RegisterForClicks("LeftButtonUp")
        p:SetScript("OnEnter", function(s)
            WK.UI:TooltipOwner(s, "ANCHOR_RIGHT")
            local G = WK.modules.Guide
            local name, sub = G:PlaceParts({ e = s.e })
            local col = familyColor(s.layer)
            GameTooltip:SetText(name, 1, 1, 1)
            if sub then GameTooltip:AddLine(sub, 0.8, 0.8, 0.8) end
            GameTooltip:AddLine(T(s.layer.label), col[1], col[2], col[3])
            -- quai : horaires appris (Modules/BoatTimes.lua), une ligne par destination
            local BT = WK.modules.BoatTimes
            if s.docks and BT then
                for _, d in ipairs(s.docks) do
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(string.format(T("vers %s"), d.to), 1, 0.85, 0.4)
                    for _, ln in ipairs(BT:TooltipLines(d.line, d.side)) do GameTooltip:AddLine(ln[1], ln[2], ln[3], ln[4], true) end
                end
            end
            GameTooltip:AddLine(T("Clic : guider jusqu'ici"), 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        p:SetScript("OnLeave", function() GameTooltip:Hide() end)
        p:SetScript("OnClick", function(s) L:GuideTo(s.mapID, s.e, s.layer.label) end)
        pins[i] = p
    end
    p:SetParent(cv)
    return p
end
local function paintPin(p, l, size)
    local col = familyColor(l)
    p:SetSize(size, size)
    p.ring:SetVertexColor(col[1], col[2], col[3], 1)
    p.inner:SetSize(size * 0.78, size * 0.78)
    p.inner:SetVertexColor(C.bg[1], C.bg[2], C.bg[3], 0.95)
    p.icon:SetTexture(UI.MEDIA .. l.icon)
    p.icon:SetSize(size * 0.52, size * 0.52)
    p.icon:SetVertexColor(col[1], col[2], col[3], 1)
    if p.icon.SetRotation then p.icon:SetRotation(0) end
end

-- Quai d'un bateau ou d'un zeppelin : petite icône du véhicule ; les zeppelins ont leur propre couleur
local function transportLook(kind, layer)
    if kind == "zeppelin" then return "zeppelin", C.warning end
    return "boat", familyColor(layer)
end
local function paintDock(p, kind, layer)
    local icon, col = transportLook(kind, layer)
    p.ring:SetVertexColor(col[1], col[2], col[3], 1)
    p.icon:SetTexture(UI.MEDIA .. icon)
    p.icon:SetVertexColor(col[1], col[2], col[3], 1)
    if p.icon.SetRotation then p.icon:SetRotation(0) end
    return col
end

-- compte à rebours sous un quai : le départ le plus proche parmi ses destinations, vert quand le bateau est à quai
local function dockLabelTick(lb, el)
    lb.acc = (lb.acc or 0) + (el or 0)
    if lb.acc < 1 then return end
    lb.acc = 0
    local BT = WK.modules.BoatTimes
    local best, bs
    for _, d in ipairs(lb.docks or {}) do
        local txt, st
        if BT then txt, st = BT:Label(d.line, d.side) end
        if txt and st and (not bs or st.inn < bs.inn) then best, bs = txt, st end
    end
    if not best then lb.text:SetText(""); lb:SetSize(1, 1); lb.bg:Hide() return end
    lb.bg:Show()
    lb.text:SetText(best)
    local col = bs.atDock and C.positive or (bs.inn < 60 and C.gold or C.text)
    lb.text:SetTextColor(col[1], col[2], col[3])
    lb.bg:SetColor(0.04, 0.04, 0.05, 0.85)
    lb:SetSize((lb.text:GetStringWidth() or 30) + 10, 15)
end

local function getRoute(i, cv)
    local r = routes[i]
    if not r then
        r = { dots = {} }
        for k = 1, DOTS do
            local d = cv:CreateTexture(nil, "ARTWORK")
            d:SetTexture(UI.MEDIA .. "circle")
            r.dots[k] = d
        end
        r.pin = getPin(1000 + i, cv)
        r.label = CreateFrame("Frame", nil, cv)
        r.label.wk = true
        r.label.bg = UI:Rounded(r.label, 6, 0, "BACKGROUND", 1)
        r.label.text = UI:Text(r.label, 10)
        r.label.text:SetPoint("CENTER")
        routes[i] = r
    end
    for _, d in ipairs(r.dots) do d:SetParent(cv) end
    r.label:SetParent(cv)
    return r
end

-- Pastilles posées au dernier dessin mais plus montrées (masquées par autre chose)
local lastDrawn = 0
function UI:MapLayersHidden()
    if lastDrawn == 0 then return false end
    local p = pins[1]
    return p ~= nil and not p:IsShown()
end
-- Diagnostic (/wk carte) : état de la première pastille de lieu affichée
function UI:MapLayersProbe()
    local p = pins[1]
    if not p then return "aucune pastille créée" end
    local function n(v) return v and string.format("%.0f", v) or "?" end
    local cx, cy = p:GetCenter()
    local par = p:GetParent()
    local l, b, w, h
    if par then l, b, w, h = par:GetRect() end
    local ic = p.icon and p.icon:GetTexture()
    return string.format("pastille 1 : montrée %s, visible %s, alpha %.2f (effectif %.2f), taille %sx%s, échelle %.2f, centre %s/%s, parent %s/%s (%s,%s %sx%s), %s/%s, texture %s",
        tostring(p:IsShown()), tostring(p:IsVisible()), p:GetAlpha() or -1, p.GetEffectiveAlpha and p:GetEffectiveAlpha() or -1,
        n(p:GetWidth()), n(p:GetHeight()), p:GetEffectiveScale() or -1, n(cx), n(cy),
        tostring(par and par.GetName and par:GetName()), tostring(par == (WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child)),
        n(l), n(b), n(w), n(h), tostring(p:GetFrameStrata()), tostring(p:GetFrameLevel()), tostring(ic))
end

function UI:MapLayersReset() lastDrawn = 0 end -- carte fermée : rien à réparer
function UI:HideMapLayers()
    for _, p in pairs(pins) do p:Hide() end
    for _, r in ipairs(routes) do
        for _, d in ipairs(r.dots) do d:Hide() end
        if r.lines then r.lines:Reset() end
        r.label:Hide()
    end
end

function UI:DrawMapLayers(cv, mapID, w, h)
    lastDrawn = 0 -- module coupé : rien à « réparer » (sinon la carte est redessinée chaque seconde)
    if not on() then return end
    local cfg = L:Config()
    local scale = (w / 1000) * UI.MapIconScale()
    local size = math.max(10 * UI.MapIconScale(), 18 * scale * 0.9) * UI.MapIconSize()
    local lvl = (UI.mapBase or cv:GetFrameLevel() or 1) + 10 -- au-dessus des calques de la carte du jeu (UI/MapPins.lua)
    local n = 0
    local places = L:Places(mapID, "map")
    if UI.mapStats then UI.mapStats.places = #places end
    lastDrawn = math.min(#places, 400)
    for _, it in ipairs(places) do
        n = n + 1
        if n > 400 then break end
        local p = getPin(n, cv)
        p.e, p.layer, p.mapID = it.e, it.layer, mapID
        paintPin(p, it.layer, size)
        p:SetFrameLevel(lvl)
        p:ClearAllPoints()
        p:SetPoint("CENTER", cv, "TOPLEFT", it.e[1] / 100 * w, -it.e[2] / 100 * h)
        p:Show()
    end
    -- bateaux et zeppelins : quai, pointillés vers la destination, nom au bout
    local tl = L.LAYER.transport
    -- quais presque au même endroit (même genre) : une seule pastille, toutes les destinations dans l'infobulle
    local placed = {}
    for i, d in ipairs(L:Docks(mapID, "map")) do
        local r = getRoute(i, cv)
        local x0, y0 = d.x / 100 * w, d.y / 100 * h
        -- pas de trait de direction : seul le vrai tracé d'un bateau déjà pris est dessiné
        -- (UI:DrawBoatPaths, UI:DrawShips)
        for _, dot in ipairs(r.dots) do dot:Hide() end
        if r.lines then r.lines:Reset() end
        local twin
        for _, q in ipairs(placed) do
            if q.kind == (d.kind or "boat") and math.abs(q.x - d.x) < 1.5 and math.abs(q.y - d.y) < 1.5 then twin = q break end
        end
        local e = { d.x, d.y, 0, nil, nil, (d.kind == "zeppelin" and "Zeppelin" or "Bateau") .. " > " .. d.to,
                    (d.kind == "zeppelin" and T("Zeppelin") or T("Bateau")) .. " " .. string.format(T("vers %s"), d.to) }
        if twin then
            -- même quai : la destination s'ajoute à la pastille déjà posée
            table.insert(twin.docks, d)
            if not twin.dest[d.to] then
                twin.dest[d.to] = true
                twin.e[6] = twin.e[6] .. ", " .. d.to
                twin.e[7] = twin.e[7] .. ", " .. d.to
            end
        else
            placed[#placed + 1] = { x = d.x, y = d.y, kind = d.kind or "boat", e = e, dest = { [d.to] = true }, docks = { d } }
            r.pin.docks = placed[#placed].docks
        end
        r.pin.e, r.pin.layer, r.pin.mapID = e, tl, mapID
        paintPin(r.pin, tl, size)
        paintDock(r.pin, d.kind, tl)
        r.pin:SetFrameLevel(lvl + 1)
        r.pin:ClearAllPoints()
        r.pin:SetPoint("CENTER", cv, "TOPLEFT", x0, -y0)
        r.pin:SetShown(not twin)
        -- destination dans l'infobulle du quai ; sous le quai, le prochain départ appris (compte à rebours)
        r.label.docks = (not twin) and r.pin.docks or nil
        r.label:ClearAllPoints(); r.label:SetPoint("TOP", r.pin, "BOTTOM", 0, -1)
        r.label:SetFrameLevel(lvl + 2)
        r.label:SetScale(UI.MapLabelScale())
        r.label:SetShown(not twin)
        r.label.acc = 1
        r.label:SetScript("OnUpdate", dockLabelTick)
        dockLabelTick(r.label, 1)
    end
end

---------------------------------------------------------------------------
-- Barre de filtres en haut de la carte du monde
---------------------------------------------------------------------------
local bar, menu
local function familyOn(fam)
    local cfg = L:Config()
    for _, l in ipairs(L.LAYERS) do if l.family == fam and cfg.map[l.key] then return true end end
    return false
end
local function redrawMap() if WK.modules.GatherMap.Redraw then WK.modules.GatherMap.Redraw() end end

local function buildMenu()
    menu = CreateFrame("Frame", nil, bar)
    menu:SetFrameStrata("DIALOG")
    menu.edge = UI:Rounded(menu, 10, 0, "BACKGROUND", 0)
    menu.bg = UI:Rounded(menu, 9, 1, "BACKGROUND", 1)
    menu.title = UI:Text(menu, 10, C.dim)
    menu.title:SetPoint("TOPLEFT", 10, -8)
    menu.rows = {}
    menu:Hide()
    menu:SetScript("OnUpdate", function(s)
        if not s:IsMouseOver() and not bar:IsMouseOver() and IsMouseButtonDown and IsMouseButtonDown() then s:Hide() end
    end)
end
local function openMenu(btn, fam)
    if not menu then buildMenu() end
    if menu:IsShown() and menu.fam == fam then menu:Hide() return end
    menu.fam = fam
    for _, r in ipairs(menu.rows) do r:Hide() end
    local cfg = L:Config()
    local y, n = -24, 0
    for _, l in ipairs(L.LAYERS) do
        if l.family == fam then
            n = n + 1
            local r = menu.rows[n]
            if not r then
                r = CreateFrame("Button", nil, menu)
                r:SetHeight(20)
                r.boxFrame = CreateFrame("Frame", nil, r)
                r.boxFrame:SetSize(14, 14)
                r.boxFrame:SetPoint("LEFT", 0, 0)
                r.box = UI:Rounded(r.boxFrame, 4, 0, "ARTWORK", 1)
                r.text = UI:Text(r, 11)
                r.text:SetPoint("LEFT", 22, 0)
                menu.rows[n] = r
            end
            r:SetPoint("TOPLEFT", 10, y); r:SetPoint("TOPRIGHT", -10, y)
            r.text:SetText(T(l.label))
            local function paint()
                local onL = cfg.map[l.key]
                local a1, a2, a3 = UI:Accent()
                if onL then r.box:SetColor(a1, a2, a3, 1) else r.box:SetColor(unpack(C.border)) end
                r.text:SetTextColor(unpack(onL and C.text or C.muted))
            end
            r:SetScript("OnClick", function() cfg.map[l.key] = not cfg.map[l.key]; paint(); bar:Paint(); redrawMap() end)
            paint()
            r:Show()
            y = y - 22
        end
    end
    menu.title:SetText(UI:Upper(T(L.FAMILY[fam].label)))
    menu:SetSize(200, -y + 8)
    local a1, a2, a3 = UI:Accent()
    menu.edge:SetColor(unpack(C.border))
    menu.bg:SetColor(C.surface[1], C.surface[2], C.surface[3], 0.98)
    menu:ClearAllPoints()
    menu:SetPoint("TOP", btn, "BOTTOM", 0, -6)
    menu:Show()
end

local function buildBar()
    local wm = WorldMapFrame
    local host = wm.ScrollContainer or wm
    bar = CreateFrame("Frame", "WarbandKeeperMapBar", wm)
    bar:SetFrameStrata("HIGH")
    bar:SetHeight(38)
    bar.edge = UI:Rounded(bar, 12, 0, "BACKGROUND", 0)
    bar.bg = UI:Rounded(bar, 11, 1, "BACKGROUND", 1)
    bar.btns = {}
    -- poignée : glisser pour déplacer la barre sur la carte ; clic droit pour la remettre en haut
    local grip = CreateFrame("Button", nil, bar)
    grip:SetSize(22, 28)
    grip:SetPoint("LEFT", 4, 0)
    grip.icon = UI:Icon(grip, "move", 15, nil, "ARTWORK")
    grip.icon:SetPoint("CENTER")
    grip.icon:SetVertexColor(unpack(C.muted))
    grip:RegisterForDrag("LeftButton")
    grip:RegisterForClicks("RightButtonUp")
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    grip:SetScript("OnDragStart", function() bar:StartMoving() end)
    grip:SetScript("OnDragStop", function()
        bar:StopMovingOrSizing()
        -- position gardée par rapport au haut de la carte (la carte peut changer de taille)
        local cfg = L:Config()
        local bx, by = bar:GetCenter()
        local hx = host:GetCenter()
        local ht = host:GetTop()
        if bx and hx and ht then
            local s1, s2 = bar:GetEffectiveScale(), host:GetEffectiveScale()
            cfg.barX = math.floor(bx * s1 / s2 - hx + 0.5)
            cfg.barY = math.floor(by * s1 / s2 - ht + 0.5)
        end
        bar:Place()
    end)
    grip:SetScript("OnClick", function() local cfg = L:Config(); cfg.barX, cfg.barY = nil, nil; bar:Place() end)
    grip:SetScript("OnEnter", function(s)
        s.icon:SetVertexColor(UI:Accent())
        WK.UI:TooltipOwner(s, "ANCHOR_BOTTOM")
        GameTooltip:SetText(T("Glisser pour déplacer la barre"), 1, 1, 1)
        GameTooltip:AddLine(T("Clic droit : la remettre en haut de la carte"), 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function(s) s.icon:SetVertexColor(unpack(C.muted)); GameTooltip:Hide() end)
    local x = 28
    for _, f in ipairs(L.FAMILIES) do
        local b = CreateFrame("Button", nil, bar)
        b:SetSize(28, 28)
        b:SetPoint("LEFT", x, 0)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b.edge = UI:Rounded(b, 8, 0, "BACKGROUND", 2)
        b.bg = UI:Rounded(b, 7, 1, "BACKGROUND", 3)
        b.icon = UI:Icon(b, f.icon, 15, nil, "ARTWORK")
        b.icon:SetPoint("CENTER")
        b.fam = f.key
        b:SetScript("OnClick", function(s, button)
            if button == "RightButton" then openMenu(s, f.key) return end
            -- clic : toute la famille, éteinte ou allumée (au moins ses couches par défaut)
            local cfg = L:Config()
            local was = familyOn(f.key)
            for _, l in ipairs(L.LAYERS) do
                if l.family == f.key then cfg.map[l.key] = (not was) and (l.map or false) or false end
            end
            if not was and not familyOn(f.key) then
                for _, l in ipairs(L.LAYERS) do if l.family == f.key then cfg.map[l.key] = true break end end
            end
            bar:Paint(); redrawMap()
            if menu and menu:IsShown() and menu.fam == f.key then openMenu(s, f.key); openMenu(s, f.key) end
        end)
        b:SetScript("OnEnter", function(s)
            WK.UI:TooltipOwner(s, "ANCHOR_BOTTOM")
            GameTooltip:SetText(T(f.label), 1, 1, 1)
            GameTooltip:AddLine(T("Clic : afficher ou masquer · clic droit : le détail"), 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        table.insert(bar.btns, b)
        x = x + 32
    end
    -- réglages complets
    local g = UI:IconButton(bar, "gear", 24)
    g:SetPoint("LEFT", x + 2, 0)
    g:SetScript("OnClick", function()
        UI:Create():Show(); UI:ShowPage("qol")
        if UI.pages.qol.ShowSection then UI.pages.qol:ShowSection("maplayers") end
    end)
    bar:SetWidth(x + 32)
    function bar:Place()
        local cfg = L:Config()
        self:ClearAllPoints()
        if cfg.barX and cfg.barY then
            self:SetPoint("CENTER", host, "TOP", cfg.barX, cfg.barY)
        else
            self:SetPoint("TOP", host, "TOP", 0, -8)
        end
    end
    bar:Place()
    function bar:Paint()
        self.edge:SetColor(unpack(C.border))
        self.bg:SetColor(C.surface[1], C.surface[2], C.surface[3], 0.95)
        for _, b in ipairs(self.btns) do
            local col = L.FAMILY[b.fam].color
            local o = familyOn(b.fam)
            b.edge:SetColor(col[1], col[2], col[3], o and 1 or 0)
            b.bg:SetColor(unpack(o and C.surface2 or C.surface))
            if o then b.icon:SetVertexColor(col[1], col[2], col[3]) else b.icon:SetVertexColor(unpack(C.dim)) end
        end
    end
end

function UI:SyncMapBar()
    if not WorldMapFrame then return end
    local want = on() and L:Config().toolbar
    if want and not bar then buildBar() end
    if bar then
        bar:SetShown(want and true or false)
        if want then bar:Paint() end
        if menu and not want then menu:Hide() end
    end
end

---------------------------------------------------------------------------
-- Minicarte
---------------------------------------------------------------------------
local MAX_MINI = 50
local holder, mini = nil, {}
local cache, cacheMap, cacheAt
-- aides communes de la minicarte (UI/MapPins.lua)
local mapSize, viewRadius = UI.MapSize, UI.MiniViewRadius
local function miniPin(i)
    local p = mini[i]
    if not p then
        p = {}
        p.ring = holder:CreateTexture(nil, "ARTWORK")
        p.ring:SetTexture(UI.MEDIA .. "circle")
        p.inner = holder:CreateTexture(nil, "ARTWORK", nil, 1)
        p.inner:SetTexture(UI.MEDIA .. "circle")
        p.inner:SetPoint("CENTER", p.ring, "CENTER")
        p.icon = holder:CreateTexture(nil, "OVERLAY")
        p.icon:SetPoint("CENTER", p.ring, "CENTER")
        mini[i] = p
    end
    return p
end
local function updateMini()
    for _, p in ipairs(mini) do p.ring:Hide(); p.inner:Hide(); p.icon:Hide() end
    if not on() or not Minimap:IsVisible() then return end
    if IsInInstance and select(2, IsInInstance()) ~= "none" and select(2, IsInInstance()) ~= nil then return end
    local pos = WK.modules.Guide:PlayerPos()
    if not pos then return end
    local size = mapSize(pos.map)
    if not size then return end
    local now = GetTime()
    if cacheMap ~= pos.map or not cacheAt or now - cacheAt > 5 then
        cache = L:Places(pos.map, "mini")
        local seen = {}
        for _, d in ipairs(L:Docks(pos.map, "mini")) do
            local k = (d.kind or "boat") .. math.floor(d.x / 1.5) .. ":" .. math.floor(d.y / 1.5)
            if not seen[k] then
                seen[k] = true
                table.insert(cache, { e = { d.x, d.y, 0 }, layer = L.LAYER.transport, kind = d.kind or "boat" })
            end
        end
        cacheMap, cacheAt = pos.map, now
    end
    local radius = viewRadius()
    local limit = radius * 0.92
    local half = Minimap:GetWidth() / 2
    local rotate = GetCVar and GetCVar("rotateMinimap") == "1"
    local facing = rotate and GetPlayerFacing and GetPlayerFacing() or nil
    local cs, sn = facing and math.cos(facing) or 1, facing and math.sin(facing) or 0
    local n = 0
    local ps = 14
    for _, it in ipairs(cache) do
        local dx, dy = (it.e[1] / 100 - pos.x) * size[1], (pos.y - it.e[2] / 100) * size[2]
        if dx * dx + dy * dy < limit * limit then
            if facing then dx, dy = dx * cs + dy * sn, -dx * sn + dy * cs end
            n = n + 1
            local p = miniPin(n)
            local col = familyColor(it.layer)
            p.ring:SetSize(ps, ps); p.ring:SetVertexColor(col[1], col[2], col[3], 1)
            p.inner:SetSize(ps - 3, ps - 3); p.inner:SetVertexColor(C.bg[1], C.bg[2], C.bg[3], 0.95)
            p.icon:SetTexture(UI.MEDIA .. it.layer.icon); p.icon:SetSize(ps * 0.55, ps * 0.55)
            p.icon:SetVertexColor(col[1], col[2], col[3], 1)
            if it.kind then paintDock(p, it.kind, it.layer) end
            p.ring:ClearAllPoints()
            p.ring:SetPoint("CENTER", Minimap, "CENTER", dx / radius * half, dy / radius * half)
            p.ring:Show(); p.inner:Show(); p.icon:Show()
            if n >= MAX_MINI then break end
        end
    end
end

function UI:RefreshMapLayers()
    cacheAt = nil
    UI:SyncMapBar()
    redrawMap()
end

WK:On("PLAYER_LOGIN", function()
    C_Timer.After(2, function()
        if Minimap and not holder then
            holder = CreateFrame("Frame", "WarbandKeeperMapLayerPins", Minimap)
            holder:SetAllPoints(Minimap)
            holder:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 4)
            holder.acc = 0
            holder:SetScript("OnUpdate", function(s, el)
                s.acc = s.acc + el
                if s.acc < 0.2 then return end
                s.acc = 0
                updateMini()
            end)
        end
        UI:SyncMapBar()
    end)
end)
if WorldMapFrame then WorldMapFrame:HookScript("OnShow", function() UI:SyncMapBar() end) end
WK:On("ADDON_LOADED", function(name)
    if name == "Blizzard_WorldMap" and WorldMapFrame then WorldMapFrame:HookScript("OnShow", function() UI:SyncMapBar() end) end
end)
