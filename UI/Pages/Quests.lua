local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Page Quêtes (Modules/Quests.lua), sur le modèle de la page Rares : une tuile par zone avec un
-- anneau de progression (ta zone en premier), les quêtes de la zone choisie en dessous, et à droite
-- les réglages et la légende. Collection par perso (« Quêtes de »).
local Q = WK.modules.Quests
local GAP, SIDE_W, ROW_H = 12, 300, 44

local function levelColor(lvl, me)
    local d = (lvl or 0) - (me or 1)
    if d >= 5 then return C.negative end
    if d >= 3 then return C.warning end
    if d >= -2 then return C.gold end
    if d >= -8 then return C.positive end
    return C.dim
end

-- Couleur et texte de chaque état
local function stateInfo(st)
    if st == "done" then return C.dim, T("faite") end
    if st == "log" then return C.positive, T("dans le journal") end
    if st == "avail" then return C.gold, T("disponible") end
    if st == "high" then return C.negative, T("trop haute") end
    return C.tank, T("plus tard")
end
local KIND = { d = "Donjon", c = "Classe" }

---------------------------------------------------------------------------
-- Onglet « Mon journal » : quêtes du journal du perso connecté (Modules/QuestTrack.lua), détail de la
-- quête choisie (objectifs, camps, rendu) et petite carte de la zone.
---------------------------------------------------------------------------
local LOG_W, LROW_H, LHEAD_H = 330, 28, 26
local COL_W, COL_W_NARROW = 270, 230      -- colonne de gauche de Mon journal et Tournée (la carte prend le reste)
local BIG_W, BIG_H, SUB_H = 240, 46, 28   -- grands onglets, rangée des sous-onglets
local SUBS = { { "montee", "Montée en niveaux" }, { "log", "Mon journal" }, { "pick", "Quêtes de ma zone" }, { "tour", "Tournée de quêtes" } }
local function QT() return WK.modules.QuestTrack end
local function QP() return WK.modules.QuestPlan end
local function LG() return WK.modules.LevelGuide end
local VIEWS = { montee = true, log = true, pick = true, tour = true, zones = true }
local function G() return WK.modules.Guide end

local MZONE_H = 214
-- couleur du rond d'une étape du guide de montée, par genre (nil = accent)
local STEP_COL = { trainer = "info", flight = "gold", zone = "gold", dungeon = "warning", item = "rule", hearth = "rule" }
-- durée lisible : « ~45 min », « ~1 h 20 »
local function fmtDur(s)
    local m = math.max(1, math.floor((s or 0) / 60 + 0.5))
    if m < 60 then return string.format(T("env. %d min"), m) end
    return string.format(T("env. %d h %02d"), math.floor(m / 60), m % 60)
end

-- petites capitales d'un nom de zone : ASCII et lettres accentuées (é » É…) en UTF-8
local function smallCaps(s)
    s = string.upper(s or "")
    return (s:gsub("\195([\160-\190])", function(b)
        if b == "\183" then return nil end -- ÷
        return "\195" .. string.char(b:byte() - 32)
    end))
end

local function mapName(map)
    if not (map and C_Map and C_Map.GetMapInfo) then return nil end
    local ok, info = pcall(C_Map.GetMapInfo, map)
    return ok and info and info.name or nil
end

-- distance (m) du joueur à un point, nil s'il est sur un autre continent ou sans position
local function distTo(map, x, y)
    local g = G()
    local me = g and g:PlayerPos()
    if not (me and me.cont and map and x) then return nil end
    local c, wx, wy = g.ToWorld(map, x, y)
    if not c or c ~= me.cont then return nil end
    return math.sqrt((wx - me.wx) ^ 2 + (wy - me.wy) ^ 2)
end

-- camp le plus proche d'une liste (sinon le premier) et sa distance
local function nearestCamp(camps)
    local best, bd
    for _, c in ipairs(camps or {}) do
        local d = distTo(c.map, c.x, c.y)
        if d and (not bd or d < bd) then best, bd = c, d end
    end
    return best or (camps and camps[1]), bd
end

-- guidage vers un point précis (camp d'un objectif, rendu)
local function guideTo(map, x, y, name, sub, reason, qid)
    local g = G()
    if not (g and map and x and y) then return end
    -- la quête guidée devient la suivie : sans quoi QuestTrack arrêterait ce guidage « qtrack » au
    -- prochain QUEST_LOG_UPDATE (pas de quête suivie) ou le remplacerait par celui d'une autre quête
    local qt = QT()
    if qt and qid and qt:Tracked() ~= qid then qt:Track(qid) end
    local t ={ map = map, x = x, y = y, e = { x * 100, y * 100, 0, nil, nil, name, name, sub } }
    t.cont, t.wx, t.wy = g.ToWorld(map, x, y)
    t.qid = qid
    g:Start(t, reason, "qtrack")
end

local function openWorldMap(map)
    if not map then return end
    if OpenWorldMap then
        if pcall(OpenWorldMap, map) then return end
    end
    if WorldMapFrame then
        if ShowUIPanel then pcall(ShowUIPanel, WorldMapFrame) else WorldMapFrame:Show() end
        if WorldMapFrame.SetMapID then pcall(WorldMapFrame.SetMapID, WorldMapFrame, map) end
    end
end

-- Carte d'une zone (onglets Mon journal et Tournée), à côté de la colonne de gauche : fond = tuiles de la
-- carte du jeu (comme UI:ZoneMap), proportions 3:2 gardées et centrées (fond C.inset autour) ; repères posés
-- par la page (camps et étapes cliquables), point du joueur
local function newMini(p, legend)
    local mc = UI:Card(p)
    mc.name = UI:Text(mc, 12)
    mc.name:SetPoint("TOPLEFT", 12, -11); mc.name:SetPoint("TOPRIGHT", -12, -11)
    mc.well = mc:CreateTexture(nil, "BACKGROUND", nil, 5)
    mc.well:SetPoint("TOPLEFT", 8, -34); mc.well:SetPoint("BOTTOMRIGHT", -8, 28)
    mc.well:SetColorTexture(unpack(C.inset))
    mc.area = CreateFrame("Frame", nil, mc)
    mc.area:SetPoint("CENTER", 0, -3)
    mc.area:SetSize(300, 200)
    if mc.area.SetClipsChildren then mc.area:SetClipsChildren(true) end
    mc.areaBg = mc.area:CreateTexture(nil, "BACKGROUND")
    mc.areaBg:SetAllPoints()
    mc.areaBg:SetColorTexture(unpack(C.inset))
    mc.tiles = {}
    mc.pins = CreateFrame("Frame", nil, mc.area)
    mc.pins:SetAllPoints()
    mc.pins:SetFrameLevel(mc.area:GetFrameLevel() + 5)
    mc.top = CreateFrame("Frame", nil, mc.area)
    mc.top:SetAllPoints()
    mc.top:SetFrameLevel(mc.area:GetFrameLevel() + 30)
    mc.camps, mc.steps, mc.lines, mc.labels = {}, {}, {}, {}
    mc.me = mc.top:CreateTexture(nil, "OVERLAY")
    mc.me:SetTexture(UI.MEDIA .. "circle"); mc.me:SetSize(9, 9); mc.me:SetVertexColor(unpack(C.text))
    mc.meEdge = mc.top:CreateTexture(nil, "ARTWORK")
    mc.meEdge:SetTexture(UI.MEDIA .. "circle"); mc.meEdge:SetSize(13, 13); mc.meEdge:SetVertexColor(unpack(C.inset))
    mc.meEdge:SetPoint("CENTER", mc.me, "CENTER")
    -- repère de rendu : médaillon doré (UI:TurnInMarker)
    mc.turnBg = CreateFrame("Frame", nil, mc.top); mc.turnBg:SetSize(18, 18)
    UI:TurnInMarker(mc.turnBg)
    mc.turn = mc.turnBg.q
    mc.none = UI:Text(mc.area, 11, C.dim)
    mc.none:SetPoint("CENTER")
    mc.legend = UI:Text(mc, 10, C.dim)
    mc.legend:SetPoint("BOTTOMLEFT", 12, 9); mc.legend:SetPoint("BOTTOMRIGHT", -12, 9)
    mc.legend:SetText(T(legend))
    return mc
end

-- Taille de la zone de dessin dans l'espace donné (largeur W, hauteur H de la carte) : 3:2, centrée
local function fitMini(mc, W, H)
    local AW = math.max(60, math.min(W - 16, (H - 62) * 1.5))
    local AH = math.floor(AW * 2 / 3)
    AW = math.floor(AW)
    mc.area:SetSize(AW, AH)
    mc.artKey = nil
end

-- Camp cliquable (cercle teinté + anneau en pointillés + anneau plein quand il est mis en avant)
local function campPin(mc, i)
    local b = mc.camps[i]
    if b then return b end
    b = CreateFrame("Button", nil, mc.pins)
    b.fill = b:CreateTexture(nil, "ARTWORK"); b.fill:SetAllPoints(); b.fill:SetTexture(UI.MEDIA .. "circle")
    b.ring = b:CreateTexture(nil, "OVERLAY"); b.ring:SetAllPoints(); b.ring:SetTexture(UI.MEDIA .. "ring_dash")
    b.hot = b:CreateTexture(nil, "OVERLAY", nil, 1); b.hot:SetPoint("CENTER"); b.hot:SetTexture(UI.MEDIA .. "ring"); b.hot:Hide()
    b:SetScript("OnEnter", function(s) if mc.onCamp then mc.onCamp(s, true) end end)
    b:SetScript("OnLeave", function(s) if mc.onCamp then mc.onCamp(s, false) end end)
    b:SetScript("OnClick", function(s) if mc.onCampClick then mc.onCampClick(s) end end)
    mc.camps[i] = b
    return b
end

-- Étape numérotée cliquable
local function stepPin(mc, i)
    local b = mc.steps[i]
    if b then return b end
    b = CreateFrame("Button", nil, mc.top)
    b.dot = b:CreateTexture(nil, "ARTWORK"); b.dot:SetAllPoints(); b.dot:SetTexture(UI.MEDIA .. "circle")
    b.edge = b:CreateTexture(nil, "BACKGROUND"); b.edge:SetPoint("CENTER"); b.edge:SetTexture(UI.MEDIA .. "circle")
    b.edge:SetVertexColor(unpack(C.inset))
    b.num = UI:Text(b, 11); b.num:SetPoint("CENTER", 0, 0)
    b:SetScript("OnEnter", function(s) if mc.onStep then mc.onStep(s, true) end end)
    b:SetScript("OnLeave", function(s) if mc.onStep then mc.onStep(s, false) end end)
    b:SetScript("OnClick", function(s) if mc.onStepClick then mc.onStepClick(s) end end)
    mc.steps[i] = b
    return b
end

-- Fond, nom et point du joueur ; renvoie la taille de la zone de dessin, ou nil (rien à montrer)
local function paintMiniBase(mc, map, emptyText)
    local AW, AH = mc.area:GetWidth() or 0, mc.area:GetHeight() or 0
    for _, t in ipairs(mc.camps) do t:Hide() end
    for _, t in ipairs(mc.steps) do t:Hide() end
    for _, t in ipairs(mc.lines) do t:Hide() end
    for _, t in ipairs(mc.labels) do t:Hide() end
    mc.me:Hide(); mc.meEdge:Hide(); mc.turn:Hide(); mc.turnBg:Hide()
    if not map or AW < 20 or AH < 20 then
        for _, t in ipairs(mc.tiles) do t:Hide() end
        for _, t in ipairs(mc.overlays or {}) do t:Hide() end
        mc.artKey = nil
        mc.name:SetText(T("Carte"))
        mc.none:SetText(T(emptyText)); mc.none:Show()
        return nil
    end
    mc.none:Hide()
    mc.name:SetText(mapName(map) or ("#" .. map))
    -- fond : tuiles de la carte de la zone, sinon le fond uni
    local key = map .. ":" .. math.floor(AW) .. "x" .. math.floor(AH)
    if mc.artKey ~= key then
        mc.artKey = key
        for _, t in ipairs(mc.tiles) do t:Hide() end
        local okL, layers = pcall(C_Map.GetMapArtLayers, map)
        local L = okL and type(layers) == "table" and layers[1]
        local okT, files = pcall(C_Map.GetMapArtLayerTextures, map, 1)
        if L and okT and type(files) == "table" then
            local tw, th = L.tileWidth or 256, L.tileHeight or 256
            local lw, lh = L.layerWidth or tw, L.layerHeight or th
            local cols = math.max(1, math.ceil(lw / tw))
            for idx, file in ipairs(files) do
                local col, row = (idx - 1) % cols, math.floor((idx - 1) / cols)
                local t = mc.tiles[idx]
                if not t then t = mc.area:CreateTexture(nil, "BACKGROUND", nil, 1); mc.tiles[idx] = t end
                t:SetTexture(file)
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", mc.area, "TOPLEFT", col * tw / lw * AW, -(row * th / lh * AH))
                t:SetSize(tw / lw * AW, th / lh * AH)
                t:Show()
            end
        end
        -- carte entière : toutes les zones dessinées, découvertes ou pas (morceaux de Modules/MapRevealDB.lua)
        mc.overlays = mc.overlays or {}
        if UI.PaintMapOverlays then UI:PaintMapOverlays(mc.area, mc.overlays, map, AW, AH) end
    end
    -- tailles à l'échelle de la carte
    local k = math.max(1, AW / 360)
    mc.me:SetSize(7 * k, 7 * k); mc.meEdge:SetSize(10 * k, 10 * k)
    mc.turnBg:SetSize(13 * k, 13 * k)
    local me = G() and G():PlayerPos()
    if me and me.map == map and me.x then
        mc.me:ClearAllPoints(); mc.me:SetPoint("CENTER", mc.area, "TOPLEFT", me.x * AW, -me.y * AH)
        mc.me:Show(); mc.meEdge:Show()
    end
    return AW, AH
end

-- Ligne du tracé entre deux points de la carte (si le client sait dessiner des lignes)
local function mapLine(mc, i, x1, y1, x2, y2, col, thick)
    if not mc.pins.CreateLine then return end
    local ln = mc.lines[i]
    if not ln then ln = mc.pins:CreateLine(nil, "ARTWORK"); mc.lines[i] = ln end
    if not ln then return end
    ln:SetThickness(thick or 2)
    ln:SetColorTexture(col[1], col[2], col[3], 0.75)
    ln:SetStartPoint("TOPLEFT", mc.area, x1, -y1)
    ln:SetEndPoint("TOPLEFT", mc.area, x2, -y2)
    ln:Show()
end

-- Étiquette posée sous un repère (texte sur un fond C.inset, lisible sur les tuiles)
local function mapLabel(mc, i)
    local l = mc.labels[i]
    if not l then
        l = CreateFrame("Frame", nil, mc.top)
        l:SetHeight(16)
        l.bg = l:CreateTexture(nil, "BACKGROUND"); l.bg:SetAllPoints()
        l.bg:SetColorTexture(C.inset[1], C.inset[2], C.inset[3], 0.8)
        l.t = UI:Text(l, 10, C.text); l.t:SetPoint("CENTER", 0, 0)
        function l:Set(txt)
            self.t:SetText(txt)
            self:SetWidth(math.min(200, (self.t:GetStringWidth() or 60) + 10))
            self.t:SetWidth(self:GetWidth() - 8)
        end
        mc.labels[i] = l
    end
    return l
end

-- Choix du menu des persos (rebâti à chaque rafraîchissement : persos renommés ou supprimés).
local function charOptions()
    local opts = {}
    for key, c in pairs(WK.DB.global.characters) do table.insert(opts, { key, WK:CharName(c, key), { UI:ClassColor(c.class) } }) end
    table.sort(opts, function(a, b) return a[2] < b[2] end)
    return opts
end

UI:RegisterPage({
    key = "quests", order = 8.9, nav = "Quêtes",

    Build = function(self, p)
        local cfg = Q:Config()
        self.viewKey = WK:CharKey()
        self.zone = Q:PlayerZone()
        cfg.filter = cfg.filter or "all"

        -- Onglets à deux niveaux : « Carte des zones » et « Ma progression » (grands boutons), puis sous
        -- « Ma progression » les sous-onglets Montée / Mon journal / À prendre / Tournée. Onglet retenu dans
        -- settings.ui.questTab (zones par défaut) ---------------------------------------------------
        local ui = WK.DB.global.settings.ui
        self.view = VIEWS[ui.questTab or ""] and ui.questTab or "zones"
        self.lastSub = self.view ~= "zones" and self.view or "montee"
        self.bigZones = self:BigTab(p, "map", "Carte des zones", function() self:ShowTab("zones") end)
        self.bigZones:SetPoint("TOPLEFT", 0, 0)
        self.bigProg = self:BigTab(p, "chart", "Ma progression", function() self:ShowTab(self.lastSub or "montee") end)
        self.bigProg:SetPoint("TOPLEFT", self.bigZones, "TOPRIGHT", 12, 0)
        self.bigProg.sub:SetText(T("montée, journal, tournée"))
        self.subTabs = {}
        local prev
        for _, t in ipairs(SUBS) do
            local b = CreateFrame("Button", nil, p)
            b:SetHeight(SUB_H - 2)
            b.label = UI:Text(b, 12)
            b.label:SetPoint("CENTER", 0, 1)
            b.label:SetText(T(t[2]))
            b:SetWidth((b.label:GetStringWidth() or 60) + 28)
            b.under = b:CreateTexture(nil, "OVERLAY")
            b.under:SetHeight(2)
            b.under:SetPoint("BOTTOMLEFT", 0, -1); b.under:SetPoint("BOTTOMRIGHT", 0, -1)
            if prev then b:SetPoint("TOPLEFT", prev, "TOPRIGHT", 4, 0) else b:SetPoint("TOPLEFT", 4, -(BIG_H + 8)) end
            prev = b
            function b.Paint(s2)
                local sel = self.view == t[1]
                local r, g, bl = UI:Accent()
                if sel then s2.label:SetTextColor(unpack(C.text)) else s2.label:SetTextColor(r, g, bl, s2.hover and 1 or 0.85) end
                s2.under:SetColorTexture(r, g, bl, 1)
                s2.under:SetShown(sel)
            end
            b:SetScript("OnEnter", function(s2) s2.hover = true; s2:Paint() end)
            b:SetScript("OnLeave", function(s2) s2.hover = false; s2:Paint() end)
            b:SetScript("OnClick", function() self:ShowTab(t[1]) end)
            UI:OnAccent(function() b:Paint() end)
            self.subTabs[t[1]] = b
        end
        self.subLine = p:CreateTexture(nil, "ARTWORK")
        self.subLine:SetHeight(1)
        self.subLine:SetPoint("TOPLEFT", 0, -(BIG_H + 8 + SUB_H))
        self.subLine:SetPoint("TOPRIGHT", 0, -(BIG_H + 8 + SUB_H))
        self.subLine:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)

        -- Barre de commandes ---------------------------------------------------------
        local of = UI:Text(p, 11, C.muted)
        of:SetPoint("TOPLEFT", self.bigProg, "TOPRIGHT", 14, -17)
        of:SetText(T("Quêtes de"))
        self.ofLabel = of
        local charOpts = charOptions()
        self.charDd = UI:Dropdown(p, 190, 30, charOpts, function(v) self.viewKey = v; self.zone = nil; self:Refresh() end)
        self.charDd:SetPoint("TOPLEFT", of, "TOPRIGHT", 8, 9)
        self.charDd:Select(self.viewKey)
        self.filterSeg = UI:Segmented(p, { { "all", "Toutes" }, { "todo", "À faire" }, { "done", "Faites" } },
            function(v) cfg.filter = v; self:Refresh() end, 30)
        self.filterSeg:SetPoint("TOPLEFT", self.charDd, "TOPRIGHT", 8, 0)
        self.filterSeg:Select(cfg.filter)

        self:BuildSettings(p)
        -- roue dentée : réglages (quêtes montrées, légende) à la place des tuiles et de la liste
        local gear = UI:IconButton(p, "gear", 30, "Réglages des quêtes")
        gear:SetPoint("TOPRIGHT", 0, -8)
        gear:SetScript("OnClick", function() self.settingsOpen = not self.settingsOpen; self:Layout(); self:Refresh() end)
        self.gear = gear

        -- Bandeau de chiffres, carte du continent et liste des zones --------------------
        self.kpi = UI:KpiRow(p, 4, 74)
        self.map = UI:ZoneMap(p)
        self.zcard = UI:Card(p)
        self.zTitle = UI:Text(self.zcard, 12); self.zTitle:SetPoint("TOPLEFT", 14, -10)
        self.zscroll = UI:Scroll(self.zcard)
        self.zscroll:SetPoint("TOPLEFT", 4, -32); self.zscroll:SetPoint("BOTTOMRIGHT", -4, 6)
        self.zrows = UI:Pool(function() return UI:ZoneRow(self.zscroll.child, function(map) self.zone = map; self:Refresh() end) end)

        -- Quêtes de la zone choisie ------------------------------------------------------
        local list = UI:Card(p)
        self.list = list
        self.lTitle = UI:Text(list, 14)
        self.lTitle:SetPoint("TOPLEFT", 14, -12)
        self.lSub = UI:Text(list, 11, C.muted)
        self.lSub:SetPoint("TOPRIGHT", -14, -14)
        self.lscroll = UI:Scroll(list)
        self.lscroll:SetPoint("TOPLEFT", 4, -38)
        self.lscroll:SetPoint("BOTTOMRIGHT", -4, 6)
        self.qrows = UI:Pool(function()
            local r = CreateFrame("Frame", nil, self.lscroll.child)
            r:SetHeight(ROW_H)
            r.line = r:CreateTexture(nil, "BACKGROUND")
            r.line:SetPoint("BOTTOMLEFT", 8, 0); r.line:SetPoint("BOTTOMRIGHT", -8, 0); r.line:SetHeight(1)
            r.lv = UI:Text(r, 12)
            r.lv:SetPoint("LEFT", 8, 0)
            r.lv:SetWidth(26)
            r.lv:SetJustifyH("RIGHT")
            r.med = UI:Icon(r, "ring", 22, nil, "ARTWORK")
            r.med:SetPoint("LEFT", 42, 0)
            r.mark = UI:Icon(r, "bang", 12, nil, "OVERLAY")
            r.mark:SetPoint("CENTER", r.med, "CENTER")
            r.name = UI:Text(r, 13)
            r.name:SetPoint("TOPLEFT", 74, -6)
            r.name:SetPoint("RIGHT", -190, 0)
            r.name:SetJustifyH("LEFT")
            r.sub = UI:Text(r, 11, C.muted)
            r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
            r.sub:SetPoint("RIGHT", -190, 0)
            r.sub:SetJustifyH("LEFT")
            r.guide = UI:GuideButton(r, 28, "Guider jusqu'au donneur de la quête")
            r.guide:SetPoint("RIGHT", -10, 0)
            r.state = UI:Badge(r, "")
            r.state:SetPoint("RIGHT", r.guide, "LEFT", -8, 0)
            r:EnableMouse(true)
            r:SetScript("OnEnter", function(s)
                if not s.q then return end
                local q = s.q
                WK.UI:TooltipOwner(s, "ANCHOR_RIGHT")
                GameTooltip:SetText(Q:Name(q), 1, 0.82, 0)
                GameTooltip:AddDoubleLine(T("Niveau"), q.lvl .. (q.req and q.req > 0 and ("  (" .. T("requis") .. " " .. q.req .. ")") or ""), 0.6, 0.6, 0.6, 1, 1, 1)
                if (q.xp or 0) > 0 then GameTooltip:AddDoubleLine(T("Expérience"), tostring(q.xp), 0.6, 0.6, 0.6, 1, 1, 1) end
                -- persos qui l'ont faite
                local who = {}
                for key, c in pairs(WK.DB.global.characters) do
                    if c.quests and c.quests.done and c.quests.done[q.id] then table.insert(who, WK:CharName(c, key)) end
                end
                if #who > 0 then GameTooltip:AddLine(T("Faite par") .. " " .. table.concat(who, ", "), 0.56, 0.82, 0.54, true) end
                if q.nxt and Q:Get(q.nxt) then GameTooltip:AddLine(T("Suite :") .. " " .. Q:Name(Q:Get(q.nxt)), 0.6, 0.6, 0.6, true) end
                GameTooltip:Show()
            end)
            r:SetScript("OnLeave", function() GameTooltip:Hide() end)
            return r
        end)
        self.empty = UI:Text(self.lscroll.child, 12, C.muted)

        self:BuildMontee(p)
        self:BuildLog(p)
        self:BuildPick(p)
        self:BuildTour(p)

        UI:OnResize(p, function() self:Layout(); self:Refresh() end)
        Q.OnChange = function() if p:IsVisible() then self:Refresh() end end
        self:Layout()
    end,

    -- Colonne de droite : réglages et légende
    BuildSettings = function(self, p)
        local qc = Q:Config()
        self.toggles = {}
        local side = UI:Scroll(p)
        self.side = side
        local root = side.child
        local y = 0
        local function card(title, h, subtitle)
            local c = UI:Card(root, title, subtitle)
            c:SetHeight(h)
            c:SetPoint("TOPLEFT", 0, -y)
            c:SetPoint("TOPRIGHT", 0, -y)
            y = y + h + GAP
            return c
        end
        local function toggle(parent, field)
            local t = UI:Toggle(parent, function() return qc[field] end,
                function(v) qc[field] = v; WK:NotifyChanged(); self:Refresh() end)
            table.insert(self.toggles, t)
            return t
        end

        -- quête suivie (Modules/QuestTrack.lua) : journal du jeu, carte à l'écran, flèche, camps sur la carte
        if QT() then
            local tcard = card("Quête suivie", 40 + (QP() and 8 or 6) * 36 + 6, "journal, flèche et carte")
            local function qtoggle(field, after)
                local t = UI:Toggle(tcard, function() return QT():Config()[field] end,
                    function(v)
                        QT():Config()[field] = v
                        if after then after(v) end
                        QT():Changed()
                    end)
                table.insert(self.toggles, t)
                return t
            end
            UI:SettingRow(tcard, -40, "Suivre la quête cochée dans le journal", nil, qtoggle("followWatch"), 50)
            UI:SettingRow(tcard, -76, "Carte de quête à l'écran", nil, qtoggle("hud", function()
                if UI.RefreshQuestTracker then UI:RefreshQuestTracker() end
            end), 50)
            UI:SettingRow(tcard, -112, "Flèche vers les zones de quête", nil, qtoggle("guide", function(v)
                local g = G()
                if v then QT():Retarget(true)
                elseif g and g.target and g.target.kind == "qtrack" then g:Stop() end
            end), 50)
            self.campSeg = UI:Segmented(tcard, { { "tracked", "Suivie" }, { "all", "Toutes" }, { "off", "Aucune" } },
                function(v)
                    QT():Config().map = v
                    if UI.RedrawWorldMap then UI.RedrawWorldMap("quêtes") end
                    QT():Changed()
                end, 26)
            UI:SettingRow(tcard, -148, "Zones de quête sur la carte", nil, self.campSeg, self.campSeg:GetWidth())
            self.campSeg:Select(QT():Config().map)
            UI:SettingRow(tcard, -184, "Masquer les repères de quête du jeu", "Sur la carte du monde, tant que nos zones de quête y sont affichées.",
                qtoggle("hideGame", function() if UI.RedrawWorldMap then UI.RedrawWorldMap("quêtes") end end), 50)
            UI:SettingRow(tcard, -220, "Volet des quêtes sur la carte", "Petite liste des quêtes du journal en bas à gauche de la carte du monde (clic : suivre une quête).",
                qtoggle("panel", function() if UI.RefreshQuestMapPanel then UI:RefreshQuestMapPanel() end end), 50)
            -- plan de quêtes (Modules/QuestPlan.lua) : alerte près d'un donneur, niveau des quêtes proposées
            if QP() then
                local nt = UI:Toggle(tcard, function() return QP():Config().nearAlert end,
                    function(v) QP():Config().nearAlert = v; WK:NotifyChanged() end)
                table.insert(self.toggles, nt)
                UI:SettingRow(tcard, -256, "Prévenir près d'un donneur utile", nil, nt, 50)
                self.maxSeg = UI:Segmented(tcard, { { 0, "0" }, { 1, "1" }, { 2, "2" }, { 3, "3" } },
                    function(v) QP():Config().maxAbove = v; WK:NotifyChanged() end, 26)
                UI:SettingRow(tcard, -292, "Quêtes au-dessus de ton niveau", nil, self.maxSeg, self.maxSeg:GetWidth())
                self.maxSeg:Select(QP():Config().maxAbove)
            end
        end

        local lcard = card("Quêtes montrées", 40 + 4 * 36 + 6, "d'après QuestieDB")
        UI:SettingRow(lcard, -40, "Quêtes de donjon", nil, toggle(lcard, "dungeons"), 50)
        UI:SettingRow(lcard, -76, "Quêtes trop hautes", nil, toggle(lcard, "high"), 50)
        UI:SettingRow(lcard, -112, "Métier : si le perso l'a", nil, toggle(lcard, "profOnly"), 50)
        UI:SettingRow(lcard, -148, "Classe : celles du perso", nil, toggle(lcard, "classOnly"), 50)

        local states = { "avail", "log", "done", "high", "locked" }
        local gcard = card("Légende", 40 + #states * 24 + 8)
        for i, st in ipairs(states) do
            local col, label = stateInfo(st)
            local d = UI:Icon(gcard, "circle", 8, nil, "ARTWORK")
            d:SetPoint("TOPLEFT", 18, -44 - (i - 1) * 24)
            d:SetVertexColor(unpack(col))
            local l = UI:Text(gcard, 12)
            l:SetPoint("LEFT", d, "RIGHT", 10, 0)
            local txt = { avail = "Disponible", log = "Dans le journal", done = "Faite",
                          high = "Trop haute pour le perso", locked = "Après une autre quête" }
            l:SetText(T(txt[st]))
        end

        -- Quêtes automatiques (Modules/AutoQuest.lua) : trois modes d'un clic, ce qui s'est passé, puis les
        -- détails (prendre, rendre, exceptions) repliés dans leur propre carte
        do
            local AQ = WK.modules.AutoQuest
            if AQ then
                local ac = AQ:Config()
                local mcard = card("Quêtes automatiques", 40 + 74 + 14 + 18 + 5 * 17 + 36, "prendre et rendre en parlant au PNJ")
                local MODES = {
                    { "manual", "Manuel", "Rien d'automatique." },
                    { "assist", "Assisté", "Prend les quêtes cochées, rend les quêtes ; tu choisis la récompense." },
                    { "auto", "Automatique", "Prend et rend tout, choisit la récompense." },
                }
                mcard.tiles = {}
                local function paintTiles()
                    local r, g, b = UI:Accent()
                    for _, t in ipairs(mcard.tiles) do
                        local on = ac.mode == t.key
                        t.edge:SetColor(r, g, b, on and 1 or 0)
                        t.name:SetTextColor(unpack(on and C.text or C.muted))
                    end
                end
                for i, m in ipairs(MODES) do
                    local t = CreateFrame("Button", nil, mcard)
                    t.key = m[1]
                    t.edge = UI:Rounded(t, 9, 0, "BACKGROUND", 0)
                    t.bgr = UI:Rounded(t, 8, 1, "BACKGROUND", 1); t.bgr:SetColor(unpack(C.surface2))
                    t.name = UI:Text(t, 12); t.name:SetPoint("TOPLEFT", 10, -9); t.name:SetText(T(m[2]))
                    t.desc = UI:Text(t, 10, C.muted); t.desc:SetPoint("TOPLEFT", 10, -27); t.desc:SetPoint("RIGHT", -8, 0)
                    t.desc:SetJustifyH("LEFT"); if t.desc.SetWordWrap then t.desc:SetWordWrap(true) end
                    t.desc:SetText(T(m[3]))
                    t:SetHeight(70)
                    t:SetScript("OnClick", function() ac.mode = m[1]; paintTiles(); WK:NotifyChanged() end)
                    mcard.tiles[i] = t
                end
                UI:OnResize(mcard, function(w)
                    local tw = math.floor(((w or 400) - 28 - 16) / 3)
                    for i, t in ipairs(mcard.tiles) do
                        t:ClearAllPoints(); t:SetPoint("TOPLEFT", 14 + (i - 1) * (tw + 8), -40); t:SetWidth(tw)
                    end
                end)
                UI:OnAccent(paintTiles)
                paintTiles()
                -- ce qui s'est passé (5 dernières)
                mcard.logHead = UI:Text(mcard, 10, C.muted); mcard.logHead:SetPoint("TOPLEFT", 14, -(40 + 74 + 10))
                mcard.logHead:SetText(UI:Upper(T("Ce qui s'est passé")))
                mcard.lines = {}
                for i = 1, 5 do
                    local l = UI:Text(mcard, 11, C.text); l:SetPoint("TOPLEFT", 14, -(40 + 74 + 28 + (i - 1) * 17)); l:SetPoint("RIGHT", -14, 0)
                    l:SetJustifyH("LEFT"); if l.SetWordWrap then l:SetWordWrap(false) end
                    mcard.lines[i] = l
                end
                function self.PaintAutoLog()
                    for i, l in ipairs(mcard.lines) do
                        local e = ac.log[i]
                        if e then
                            local col = e.k == "turn" and C.positive or { UI:Accent() }
                            l:SetText(UI:Hex(col) .. (e.k == "turn" and T("Rendue") or T("Prise")) .. "|r  " .. (e.s or ""))
                        else
                            l:SetText(i == 1 and (UI:Hex(C.dim) .. T("Rien pour l'instant.") .. "|r") or "")
                        end
                    end
                end
                self.PaintAutoLog()
                mcard.more = UI:Button(mcard, "Détails", nil, 24, "ghost")
                mcard.more:SetPoint("BOTTOMLEFT", 10, 8)

                -- détails : Prendre, Rendre, Exceptions
                local yBefore = y
                local dcard = card("Quêtes automatiques : détails", 40 + 12 * 36 + 40 + 60 + 50, "prendre, rendre, exceptions")
                local function at(field, after)
                    local t = UI:Toggle(dcard, function() return ac[field] end, function(v) ac[field] = v; if after then after(v) end WK:NotifyChanged() end)
                    table.insert(self.toggles, t)
                    return t
                end
                local dy = -40
                local function head(text)
                    local h = UI:Text(dcard, 10, C.muted); h:SetPoint("TOPLEFT", 14, dy - 4); h:SetText(UI:Upper(T(text)))
                    dy = dy - 22
                end
                local function row(label, desc, ctrl, w)
                    UI:SettingRow(dcard, dy, label, desc, ctrl, w or 50)
                    dy = dy - 36
                end
                head("Prendre")
                row("Pas les quêtes trop hautes", "Mode automatique : au-delà de « Quêtes au-dessus de ton niveau ».", at("noHigh"))
                row("Pas les quêtes de groupe", "Quêtes conseillées à plusieurs (élites).", at("noGroup"))
                row("Sauter le dialogue du PNJ", "Ouvre directement la quête à prendre ou à rendre.", at("skipGossip"))
                row("Partager avec le groupe", "Chaque quête prise est partagée aux membres du groupe.", at("share"))
                head("Rendre")
                self.rewardSeg = UI:Segmented(dcard, { { "me", "Pour moi" }, { "price", "Plus chère" } },
                    function(v) ac.reward = v; WK:NotifyChanged() end, 24)
                row("Récompense (mode automatique)", "Pour moi : l'amélioration pour ton perso ; sinon la plus chère à vendre.", self.rewardSeg, self.rewardSeg:GetWidth())
                self.rewardSeg:Select(ac.reward)
                row("Si rien ne sert : la plus chère", nil, at("fallbackPrice"))
                row("Pas les quêtes qui coûtent de l'or", nil, at("noGold"))
                head("Exceptions")
                row("Maj enfoncée : manuel", "Garde la main sur une quête en tenant Maj en parlant au PNJ.", at("shift"))
                row("Récapitulatif dans le chat", "« Prise : … » · « Rendue : … »", at("chat"))
                dcard.list = UI:Text(dcard, 11, C.muted); dcard.list:SetPoint("TOPLEFT", 14, dy - 2); dcard.list:SetPoint("RIGHT", -14, 0)
                dcard.list:SetJustifyH("LEFT"); if dcard.list.SetWordWrap then dcard.list:SetWordWrap(true) end
                local function paintList()
                    local names = {}
                    for qid in pairs(ac.quests) do
                        local qq = WK.modules.Quests and WK.modules.Quests:Get(qid)
                        table.insert(names, (qq and WK.modules.Quests:Name(qq)) or ("#" .. qid))
                    end
                    for _, n in pairs(ac.npcs) do table.insert(names, T("PNJ :") .. " " .. n) end
                    dcard.list:SetText(#names > 0 and (T("Jamais d'automatique pour :") .. " " .. table.concat(names, " · "))
                        or T("Aucune exception."))
                end
                paintList()
                dcard.bq = UI:Button(dcard, "Exclure la quête suivie", nil, 24, "secondary")
                dcard.bq:SetPoint("TOPLEFT", 14, dy - 40)
                dcard.bq:SetScript("OnClick", function()
                    local qid = QT() and QT():Tracked()
                    if qid then AQ:BlockQuest(qid, true) else WK:Print(T("Aucune quête suivie.")) end
                    paintList()
                end)
                dcard.bn = UI:Button(dcard, "Exclure le PNJ ciblé", nil, 24, "secondary")
                dcard.bn:SetPoint("LEFT", dcard.bq, "RIGHT", 8, 0)
                dcard.bn:SetScript("OnClick", function()
                    local id, name = AQ:TargetNpc()
                    if id then AQ:BlockNpc(id, name, true) else WK:Print(T("Cible un PNJ d'abord.")) end
                    paintList()
                end)
                dcard.clear = UI:Button(dcard, "Tout réautoriser", nil, 24, "ghost")
                dcard.clear:SetPoint("LEFT", dcard.bn, "RIGHT", 8, 0)
                dcard.clear:SetScript("OnClick", function() wipe(ac.quests); wipe(ac.npcs); paintList(); WK:NotifyChanged() end)
                local yAfter = y
                -- repli des détails (fermés au départ)
                local function fold(open)
                    dcard:SetShown(open)
                    mcard.more:SetLabel(open and T("Masquer les détails") or T("Détails"))
                    mcard.more:SetWidth(mcard.more.label:GetStringWidth() + 28)
                    self.sideH = open and yAfter or yBefore
                    if self.Layout then self:Layout() end
                end
                mcard.more:SetScript("OnClick", function() self.autoOpen = not self.autoOpen; fold(self.autoOpen) end)
                self.autoFold = fold
                y = yAfter
                C_Timer.After(0, function() fold(self.autoOpen and true or false) end)
            end
        end
        self.sideH = y
    end,

    -- recherche de la barre latérale : un réglage des quêtes ouvre la roue
    RevealSetting = function(self, row)
        local f = row
        while f do
            if f == self.side then self.settingsOpen = true; self:Layout(); self:Refresh() return end
            f = f:GetParent()
        end
    end,

    Layout = function(self)
        local p = self.list:GetParent()
        local h = p:GetHeight() or 500
        if h < 100 then h = 500 end
        local w = p:GetWidth() or 800
        if w < 100 then w = 800 end
        -- « Quêtes de » et le filtre (onglet zones) : à côté des grands onglets, ou dessous si la place manque
        local zonesView = self.view == "zones"
        local barW = 2 * BIG_W + 12 + 14 + 70 + 8 + 190 + 8 + (self.filterSeg:GetWidth() or 230) + 44
        local second = zonesView and w < barW
        self.ofLabel:ClearAllPoints()
        if second then self.ofLabel:SetPoint("TOPLEFT", 0, -(BIG_H + GAP + 9))
        else self.ofLabel:SetPoint("TOPLEFT", self.bigProg, "TOPRIGHT", 14, -17) end
        local open = self.settingsOpen == true
        local top
        -- réglages ouverts : pas de sous-onglets ni de barre « Quêtes de » (ils ne servent pas aux réglages)
        if open then top = BIG_H + GAP
        elseif zonesView then top = BIG_H + GAP + (second and (30 + GAP) or 0)
        else top = BIG_H + 8 + SUB_H + GAP end
        -- grands onglets et sous-onglets
        self.bigZones:Paint(); self.bigProg:Paint()
        for _, b in pairs(self.subTabs) do b:SetShown(not zonesView and not open); b:Paint() end
        self.subLine:SetShown(not zonesView and not open)
        self.side:ClearAllPoints()
        self.gear:SetActive(open)
        self.side:SetShown(open)
        -- réglages : sur toute la largeur, sous la barre
        self.side:SetPoint("TOPLEFT", 0, -top)
        self.side:SetPoint("BOTTOMRIGHT")
        self.side.child:SetSize(math.min(w - 10, 560), self.sideH or 400)
        if self.side.UpdateBar then self.side:UpdateBar() end
        -- onglet affiché : zones (barre « Quêtes de », filtre) ou journal
        self.ofLabel:SetShown(zonesView and not open); self.charDd:SetShown(zonesView and not open); self.filterSeg:SetShown(zonesView and not open)
        UI:ZoneLayout(self, p, top, w, h, open or not zonesView)
        self:LayoutMontee(top, w, h, open or self.view ~= "montee")
        self:LayoutLog(top, w, h, open or self.view ~= "log")
        self:LayoutPick(top, w, h, open or self.view ~= "pick")
        self:LayoutTour(top, w, h, open or self.view ~= "tour")
    end,

    -- Grand onglet : icône dans un carré arrondi, titre et sous-titre ; plein à la couleur d'accent quand il
    -- est actif, sinon fond C.surface et liseré C.border
    BigTab = function(self, p, icon, title, onClick)
        local b = CreateFrame("Button", nil, p)
        b:SetSize(BIG_W, BIG_H)
        b.edge = UI:Rounded(b, 12, 0, "BACKGROUND", 0)
        b.bg = UI:Rounded(b, 11, 1, "BACKGROUND", 1)
        b.box = CreateFrame("Frame", nil, b)
        b.box:SetSize(32, 32); b.box:SetPoint("TOPLEFT", 8, -7)
        b.boxBg = UI:Rounded(b.box, 8, 0, "BACKGROUND", 2)
        b.icon = UI:Icon(b.box, icon, 18)
        b.icon:SetPoint("CENTER")
        b.title = UI:Text(b, 13)
        b.title:SetPoint("TOPLEFT", 50, -8); b.title:SetPoint("TOPRIGHT", -10, -8)
        b.title:SetText(title)
        b.sub = UI:Text(b, 10, C.muted)
        b.sub:SetPoint("TOPLEFT", 50, -27); b.sub:SetPoint("TOPRIGHT", -10, -27)
        b.key = icon == "map" and "zones" or "prog"
        function b.Paint(s2)
            local r, g, bl = UI:Accent()
            local on = (s2.key == "zones") == (self.view == "zones")
            if on then
                s2.edge:SetColor(r, g, bl, 1); s2.bg:SetColor(r, g, bl, 1)
                s2.boxBg:SetColor(C.onAccent[1], C.onAccent[2], C.onAccent[3], 0.16)
                s2.icon:SetVertexColor(unpack(C.onAccent))
                s2.title:SetTextColor(unpack(C.onAccent))
                s2.sub:SetTextColor(C.onAccent[1], C.onAccent[2], C.onAccent[3], 0.75)
            else
                if s2.hover then s2.edge:SetColor(r, g, bl, 1) else s2.edge:SetColor(unpack(C.border)) end
                s2.bg:SetColor(unpack(C.surface))
                s2.boxBg:SetColor(r, g, bl, 0.16)
                s2.icon:SetVertexColor(r, g, bl, 1)
                s2.title:SetTextColor(unpack(C.text))
                s2.sub:SetTextColor(unpack(C.muted))
            end
        end
        b:SetScript("OnEnter", function(s2) s2.hover = true; s2:Paint() end)
        b:SetScript("OnLeave", function(s2) s2.hover = false; s2:Paint() end)
        b:SetScript("OnClick", onClick)
        UI:OnAccent(function() b:Paint() end)
        return b
    end,

    -- sous-titre de « Carte des zones » : zones et quêtes disponibles du perso choisi
    ZoneSummary = function(self, zones)
        if not zones then
            local ok, z = pcall(Q.Zones, Q, self.viewKey or WK:CharKey())
            zones = ok and z or {}
        end
        local avail = 0
        for _, z in ipairs(zones) do avail = avail + (z.avail or 0) end
        self.zoneSum = true
        self.bigZones.sub:SetText(string.format(T("%d zones · %d quêtes disponibles"), #zones, avail))
    end,

    -- onglet choisi (boutons d'onglet, pastille « Suivie » de l'en-tête)
    ShowTab = function(self, v)
        self.view = VIEWS[v or ""] and v or "zones"
        WK.DB.global.settings.ui.questTab = self.view
        if self.view ~= "zones" then self.lastSub = self.view end
        self.settingsOpen = false
        self:Layout()
        self:Refresh()
        if UI.RefreshChips then UI:RefreshChips() end
    end,

    ---------------------------------------------------------------------------
    -- Onglet « Montée » (Modules/LevelGuide.lua) : meilleures zones, puis étapes du guide
    ---------------------------------------------------------------------------
    BuildMontee = function(self, p)
        local hold = CreateFrame("Frame", nil, p)
        self.mHold = hold
        self.mscroll = UI:Scroll(hold)
        self.mscroll:SetAllPoints()
        local child = self.mscroll.child
        self.mEmpty = UI:Text(child, 12, C.muted)
        self.mEmpty:SetJustifyH("LEFT")
        if self.mEmpty.SetWordWrap then self.mEmpty:SetWordWrap(true) end
        -- 3 cartes de zone
        self.mzones = {}
        for i = 1, 3 do
            local cd = UI:Card(child)
            cd:SetHeight(MZONE_H)
            cd.name = UI:Text(cd, 14)
            cd.name:SetPoint("TOPLEFT", 16, -14); cd.name:SetPoint("TOPRIGHT", -120, -14)
            cd.tag = UI:Badge(cd, "")
            cd.tag:SetPoint("TOPRIGHT", -14, -12)
            cd.lv = UI:Text(cd, 11, C.muted)
            cd.lv:SetPoint("TOPLEFT", 16, -36)
            cd.reco = UI:Badge(cd, "conseillée")
            cd.reco:SetPoint("TOPLEFT", cd.lv, "TOPRIGHT", 8, 3)
            cd.xp = UI:Text(cd, 22, C.positive)
            cd.xp:SetPoint("TOPLEFT", 16, -58)
            cd.lines = {}
            for j = 1, 4 do
                local l = UI:Text(cd, 11, C.muted)
                l:SetPoint("TOPLEFT", 16, -92 - (j - 1) * 20)
                local v = UI:Text(cd, 11)
                v:SetPoint("TOPRIGHT", -16, -92 - (j - 1) * 20); v:SetJustifyH("RIGHT")
                cd.lines[j] = { l, v }
            end
            cd.btn = UI:Button(cd, "Y aller", 120, 30, "secondary")
            cd.btn:SetPoint("BOTTOMLEFT", 14, 12); cd.btn:SetPoint("BOTTOMRIGHT", -14, 12)
            self.mzones[i] = cd
        end
        -- carte « Montée · niveau N » : XP du niveau, étapes, commandes
        local sc = UI:Card(child)
        self.mSteps = sc
        sc.head = UI:Text(sc, 14)
        sc.head:SetPoint("TOPLEFT", 16, -14)
        sc.xpt = UI:Text(sc, 11, C.muted)
        sc.xpt:SetPoint("TOPRIGHT", -16, -15); sc.xpt:SetJustifyH("RIGHT")
        sc.bar = UI:Progress(sc, 8)
        sc.bar:SetPoint("TOPLEFT", 16, -40); sc.bar:SetPoint("TOPRIGHT", -16, -40)
        sc.empty = UI:Text(sc, 12, C.muted)
        sc.empty:SetPoint("TOPLEFT", 16, -62); sc.empty:SetPoint("TOPRIGHT", -16, -62)
        sc.empty:SetJustifyH("LEFT")
        sc.rows = UI:Pool(function()
            local r = CreateFrame("Frame", nil, sc)
            r:SetHeight(46)
            r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints()
            r.bar = r:CreateTexture(nil, "ARTWORK"); r.bar:SetPoint("TOPLEFT"); r.bar:SetPoint("BOTTOMLEFT"); r.bar:SetWidth(3)
            r.dot = r:CreateTexture(nil, "ARTWORK")
            r.dot:SetTexture(UI.MEDIA .. "circle"); r.dot:SetSize(12, 12); r.dot:SetPoint("TOPLEFT", 16, -11)
            r.title = UI:Text(r, 12)
            r.title:SetPoint("TOPLEFT", 40, -8); r.title:SetPoint("TOPRIGHT", -190, -8)
            r.sub = UI:Text(r, 11, C.muted)
            r.sub:SetPoint("TOPLEFT", 40, -26); r.sub:SetPoint("TOPRIGHT", -190, -26)
            r.skip = UI:Button(r, "Passer", 70, 24, "ghost")
            r.skip:SetPoint("TOPRIGHT", -14, -11)
            r.go = UI:Button(r, "Y aller", 90, 24, "secondary")
            r.go:SetPoint("TOPRIGHT", r.skip, "TOPLEFT", -6, 0)
            return r
        end)
        -- commandes sous la liste
        sc.follow = UI:Button(sc, "Suivre ce guide", 160, 30, "primary")
        sc.follow:SetScript("OnClick", function()
            local lg = LG()
            if lg then lg:Follow(not lg:Following()) end
            self.lgAt = nil; self:RefreshMontee()
        end)
        local function cfgToggle(field, label)
            local t = UI:Toggle(sc, function() return LG() and LG():Config()[field] and true or false end,
                function(v) if LG() then LG():Config()[field] = v or nil end; self.lgAt = nil; self:RefreshMontee() end)
            local l = UI:Text(sc, 12)
            l:SetPoint("LEFT", t, "RIGHT", 8, 0)
            l:SetText(label)
            t.label = l
            table.insert(self.toggles or {}, t)
            return t
        end
        sc.noDgn = cfgToggle("noDungeons", "Sans donjons")
        -- maître de classe dans la tournée (oui par défaut : réglage trainerTour ~= false)
        sc.trainer = UI:Toggle(sc, function() return not (LG() and LG():Config().trainerTour == false) end,
            function(v)
                if LG() then LG():Config().trainerTour = v and nil or false end
                if QP() then QP():Invalidate() end
                self.lgAt = nil; self:RefreshMontee()
            end)
        sc.trainer.label = UI:Text(sc, 12); sc.trainer.label:SetPoint("LEFT", sc.trainer, "RIGHT", 8, 0)
        sc.trainer.label:SetText(T("Maître de classe dans la tournée"))
        sc.trainer.tooltip = "Quand des sorts sont à apprendre, la tournée de quêtes passe par le maître de classe le plus proche."
        table.insert(self.toggles or {}, sc.trainer)
        sc.noProf = cfgToggle("noProf", "Sans métiers")
        sc.recalc = UI:Button(sc, "Recalculer", nil, 30, "secondary", "refresh")
        sc.recalc:SetScript("OnClick", function() self.lgAt = nil; self:RefreshMontee() end)
        -- recalcul toutes les 3 s tant que l'onglet est affiché
        local acc = 0
        hold:SetScript("OnUpdate", function(_, el)
            acc = acc + (el or 0)
            if acc < 3 then return end
            acc = 0
            if self.view == "montee" and not self.settingsOpen then self:RefreshMontee() end
        end)
    end,

    LayoutMontee = function(self, top, w, h, hide)
        self.mHold:ClearAllPoints()
        self.mHold:SetShown(not hide)
        if hide then return end
        self.mHold:SetPoint("TOPLEFT", 0, -top)
        self.mHold:SetPoint("BOTTOMRIGHT", 0, 0)
    end,

    RefreshMontee = function(self, force)
        local lg = LG()
        if not (lg and self.mHold) then return end
        -- zones et étapes : gardées 3 s (BestZones parcourt toutes les zones)
        local now = (GetTime and GetTime()) or time()
        if force or not self.lgAt or now - self.lgAt >= 3 or now < self.lgAt then
            local ok, steps, zones = pcall(lg.Steps, lg)
            if not ok then steps, zones = {}, {} end
            self.lgSteps, self.lgZones, self.lgAt = steps or {}, zones or {}, now
        end
        local steps, zones = self.lgSteps, self.lgZones
        local W = self.mscroll:GetWidth() or 800
        if W < 100 then W = 800 end
        W = W - 14
        local cols = W >= 900 and 3 or (W >= 560 and 2 or 1)
        local cw = math.floor((W - (cols - 1) * GAP) / cols)
        local ar, ag, ab = UI:Accent()
        local y = 0
        for i, cd in ipairs(self.mzones) do
            local z = zones[i]
            cd:SetShown(z ~= nil)
            if z then
                local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
                cd:ClearAllPoints(); cd:SetPoint("TOPLEFT", col * (cw + GAP), -(row * (MZONE_H + GAP))); cd:SetWidth(cw)
                if cd.border then
                    if i == 1 then cd.border:SetColor(ar, ag, ab, 1) else cd.border:SetColor(unpack(UI.cardStyle == "flat" and C.surface or C.border)) end
                end
                cd.name:SetText(z.name or ("#" .. z.map))
                cd.lv:SetText(string.format(T("niveau %d à %d"), z.min or 0, z.max or 0))
                cd.reco:SetShown(i == 1)
                if z.here then cd.tag:Set(T("tu es ici"))
                elseif (z.travel or 0) >= 900 then cd.tag:Set(T("autre continent"), C.warning)
                else cd.tag:Set(string.format(T("à %d min"), math.max(1, math.floor((z.travel or 0) / 60 + 0.5))), C.muted) end
                cd.xp:SetText("+" .. (BreakUpLargeNumbers and BreakUpLargeNumbers(z.xp or 0) or tostring(z.xp or 0)) .. " XP")
                local lines = {
                    { T("Quêtes à ton niveau"), tostring(z.count or 0) },
                    { T("Temps estimé"), fmtDur(z.secs) },
                    { T("Te mène au niveau"), tostring(math.floor(z.reach or 0)) },
                }
                if z.flightMissing then table.insert(lines, { T("Point de vol"), T("pas appris"), C.warning }) end
                for j, l in ipairs(cd.lines) do
                    local e = lines[j]
                    l[1]:SetShown(e ~= nil); l[2]:SetShown(e ~= nil)
                    if e then l[1]:SetText(e[1]); l[2]:SetText(e[2]); l[2]:SetTextColor(unpack(e[3] or C.text)) end
                end
                if z.here then
                    cd.btn:SetLabel("Préparer la tournée"); cd.btn:SetStyle("primary")
                    cd.btn:SetScript("OnClick", function() self:ShowTab("tour") end)
                else
                    cd.btn:SetLabel("Y aller"); cd.btn:SetStyle("secondary")
                    cd.btn:SetScript("OnClick", function() lg:GoToZone(z) end)
                end
                y = math.max(y, (row + 1) * (MZONE_H + GAP))
            end
        end
        self.mEmpty:SetShown(#zones == 0)
        if #zones == 0 then
            self.mEmpty:ClearAllPoints(); self.mEmpty:SetPoint("TOPLEFT", 16, -8); self.mEmpty:SetWidth(W - 32)
            self.mEmpty:SetText(T("Aucune zone n'a assez de quêtes à ton niveau. Regarde la « Carte des zones » ou fais un donjon."))
            y = 44
        end

        -- étapes du guide
        local sc = self.mSteps
        sc:ClearAllPoints(); sc:SetPoint("TOPLEFT", 0, -y); sc:SetWidth(W)
        local lvl = UnitLevel and UnitLevel("player") or 1
        sc.head:SetText(string.format(T("Montée en niveaux · niveau %d"), lvl))
        local cur, max = (UnitXP and UnitXP("player")) or 0, (UnitXPMax and UnitXPMax("player")) or 0
        sc.bar:SetValue(max > 0 and cur / max or 0)
        sc.xpt:SetText(max > 0 and string.format(T("%s / %s XP"), BreakUpLargeNumbers and BreakUpLargeNumbers(cur) or cur,
            BreakUpLargeNumbers and BreakUpLargeNumbers(max) or max) or "")
        sc.rows:Reset()
        local ry = 58
        for i, s in ipairs(steps) do
            local r = sc.rows:Get()
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -ry); r:SetPoint("TOPRIGHT", 0, -ry)
            local col = STEP_COL[s.kind] and C[STEP_COL[s.kind]] or { ar, ag, ab }
            r.dot:SetVertexColor(col[1], col[2], col[3], 1)
            r.title:SetText(s.title or "")
            r.sub:SetText(s.sub or "")
            if i == 1 then
                r.bg:SetColorTexture(unpack(C.surface2)); r.bg:Show()
                r.bar:SetColorTexture(ar, ag, ab, 1); r.bar:Show()
            else r.bg:Hide(); r.bar:Hide() end
            r.go:SetShown(s.act ~= nil)
            r.go:SetScript("OnClick", function()
                if s.act then s.act() end
                lg:Changed()
                self.lgAt = nil; self:RefreshMontee()
            end)
            r.skip:SetScript("OnClick", function() lg:Skip(s.key); self.lgAt = nil; self:RefreshMontee() end)
            ry = ry + 48
        end
        sc.empty:SetShown(#steps == 0)
        sc.empty:SetText(T("Rien à faire pour l'instant : une étape apparaît dès qu'elle devient utile."))
        if #steps == 0 then ry = ry + 30 end
        ry = ry + 10
        local following = lg:Following()
        sc.follow:SetLabel(following and "Ne plus suivre" or "Suivre ce guide")
        sc.follow:SetStyle(following and "secondary" or "primary")
        sc.follow:ClearAllPoints(); sc.follow:SetPoint("TOPLEFT", 16, -ry)
        sc.noDgn:ClearAllPoints(); sc.noDgn:SetPoint("TOPLEFT", sc.follow, "TOPRIGHT", 20, -4)
        sc.noProf:ClearAllPoints(); sc.noProf:SetPoint("TOPLEFT", sc.noDgn.label, "TOPRIGHT", 20, 4)
        sc.recalc:ClearAllPoints(); sc.recalc:SetPoint("TOPRIGHT", -16, -ry)
        sc.trainer:ClearAllPoints(); sc.trainer:SetPoint("TOPLEFT", sc.noProf.label, "TOPRIGHT", 20, 4)
        sc.noDgn:Refresh(); sc.noProf:Refresh(); sc.trainer:Refresh()
        sc:SetHeight(ry + 30 + 16)
        self.mscroll.child:SetSize(W, y + ry + 46 + 8)
        if self.mscroll.UpdateBar then self.mscroll:UpdateBar() end
        if UI.RefreshChips and UI.current == "quests" then UI:RefreshChips() end
    end,

    ---------------------------------------------------------------------------
    -- Onglet « Mon journal »
    ---------------------------------------------------------------------------
    BuildLog = function(self, p)
        -- liste du journal, rangée par zone ----------------------------------------------
        local lc = UI:Card(p)
        self.jList = lc
        self.jCount = UI:Text(lc, 12)
        self.jCount:SetPoint("TOPLEFT", 14, -12)
        self.jscroll = UI:Scroll(lc)
        self.jscroll:SetPoint("TOPLEFT", 4, -36)
        self.jscroll:SetPoint("BOTTOMRIGHT", -4, 6)
        self.jheads = UI:Pool(function() return UI:Text(self.jscroll.child, 10, C.muted) end)
        local function paintRow(r)
            local ar, ag, ab = UI:Accent()
            if r.sel then
                r.bg:SetColorTexture(unpack(C.surface2)); r.bg:Show()
                r.bar:SetColorTexture(ar, ag, ab, 1); r.bar:Show()
            else
                r.bar:Hide()
                if r.hover then r.bg:SetColorTexture(C.surface2[1], C.surface2[2], C.surface2[3], 0.5); r.bg:Show() else r.bg:Hide() end
            end
        end
        self.jrows = UI:Pool(function()
            local r = CreateFrame("Button", nil, self.jscroll.child)
            r:SetHeight(LROW_H)
            r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints()
            r.bar = r:CreateTexture(nil, "ARTWORK"); r.bar:SetPoint("TOPLEFT"); r.bar:SetPoint("BOTTOMLEFT"); r.bar:SetWidth(3)
            r.lv = UI:Badge(r, "")
            r.lv:SetPoint("LEFT", 10, 0)
            r.name = UI:Text(r, 12)
            r.name:SetPoint("LEFT", 46, 0)
            r.name:SetPoint("RIGHT", -74, 0)
            r.tag = UI:Badge(r, "")
            r.tag:SetPoint("RIGHT", -8, 0)
            r.right = UI:Text(r, 11, C.muted)
            r.right:SetPoint("RIGHT", -10, 0)
            r.right:SetJustifyH("RIGHT")
            r.Paint = paintRow
            r:SetScript("OnClick", function(s) if s.qid then self.sel = s.qid; self:RefreshLog() end end)
            r:SetScript("OnEnter", function(s)
                s.hover = true; paintRow(s)
                self.hoverQid = s.qid; self:TintCamps()
                if s.title then
                    UI:TooltipOwner(s, "ANCHOR_RIGHT")
                    GameTooltip:SetText(s.title, 1, 1, 1)
                    GameTooltip:Show()
                end
            end)
            r:SetScript("OnLeave", function(s)
                s.hover = false; paintRow(s); GameTooltip:Hide()
                if self.hoverQid == s.qid then self.hoverQid = nil; self:TintCamps() end
            end)
            UI:OnAccent(function() paintRow(r) end)
            return r
        end)

        -- détail de la quête choisie --------------------------------------------------------
        local dc = UI:Card(p)
        self.jDet = dc
        self.dTitle = UI:Text(dc, 15)
        self.dTitle:SetPoint("TOPLEFT", 16, -14); self.dTitle:SetPoint("TOPRIGHT", -16, -14)
        self.dSub = UI:Text(dc, 11, C.muted)
        self.dSub:SetPoint("TOPLEFT", self.dTitle, "BOTTOMLEFT", 0, -5); self.dSub:SetPoint("TOPRIGHT", self.dTitle, "BOTTOMRIGHT", 0, -5)
        self.dscroll = UI:Scroll(dc)
        self.dscroll:SetPoint("TOPLEFT", 4, -60)
        self.dscroll:SetPoint("BOTTOMRIGHT", -4, 90)
        self.trackBtn = UI:Button(dc, "Suivre cette quête", 170, 30, "primary")
        self.trackBtn:SetPoint("BOTTOMLEFT", 12, 12); self.trackBtn:SetPoint("BOTTOMRIGHT", -12, 12)
        self.trackBtn:SetScript("OnClick", function()
            local qt = QT()
            if not (qt and self.sel) then return end
            if qt:Tracked() == self.sel then qt:Untrack() else qt:Track(self.sel) end
            self:RefreshLog()
        end)
        self.mapBtn = UI:Button(dc, "Voir sur la carte", nil, 30, "secondary", "map")
        self.mapBtn:SetPoint("BOTTOMLEFT", 12, 48); self.mapBtn:SetPoint("BOTTOMRIGHT", -12, 48)
        self.mapBtn:SetScript("OnClick", function() openWorldMap(self.miniMap) end)
        self.dEmpty = UI:Text(dc, 12, C.muted)
        self.dEmpty:SetPoint("TOPLEFT", 16, -18); self.dEmpty:SetPoint("TOPRIGHT", -16, -18)
        self.dEmpty:SetJustifyH("LEFT")
        if self.dEmpty.SetWordWrap then self.dEmpty:SetWordWrap(true) end
        local child = self.dscroll.child
        self.dheads = UI:Pool(function() return UI:Text(child, 10, C.muted) end)
        self.dobjs = UI:Pool(function()
            local f = CreateFrame("Frame", nil, child)
            f.hl = f:CreateTexture(nil, "BACKGROUND"); f.hl:SetAllPoints()
            f.hl:SetColorTexture(unpack(C.surface2)); f.hl:Hide()
            f.check = f:CreateTexture(nil, "ARTWORK")
            f.check:SetSize(14, 14); f.check:SetPoint("TOPLEFT", 12, -1)
            f.name = UI:Text(f, 12)
            f.name:SetPoint("TOPLEFT", 34, -2); f.name:SetPoint("TOPRIGHT", -70, -2)
            f.count = UI:Text(f, 11, C.muted)
            f.count:SetPoint("TOPRIGHT", -12, -2); f.count:SetJustifyH("RIGHT")
            f.bar = UI:Progress(f, 5)
            f.bar:SetPoint("TOPLEFT", 34, -22); f.bar:SetPoint("TOPRIGHT", -12, -22)
            f.info = UI:Text(f, 11, C.muted)
            f.info:SetPoint("TOPLEFT", 34, -34); f.info:SetPoint("TOPRIGHT", -40, -34)
            f.info:SetJustifyH("LEFT")
            if f.info.SetWordWrap then f.info:SetWordWrap(true) end
            f.go = UI:GuideButton(f, 24, "Guider jusqu'à la zone la plus proche de cet objectif")
            f.go:SetPoint("TOPRIGHT", -10, -32)
            return f
        end)
        local tf = CreateFrame("Frame", nil, child)
        tf:SetHeight(44)
        tf.mark = CreateFrame("Frame", nil, tf); tf.mark:SetSize(18, 18)
        tf.mark:SetPoint("TOPLEFT", 10, -1)
        UI:TurnInMarker(tf.mark)
        tf.zone = UI:Text(tf, 12)
        tf.zone:SetPoint("TOPLEFT", 34, -2); tf.zone:SetPoint("TOPRIGHT", -40, -2)
        tf.dist = UI:Text(tf, 11, C.muted)
        tf.dist:SetPoint("TOPLEFT", 34, -20); tf.dist:SetPoint("TOPRIGHT", -40, -20)
        tf.go = UI:GuideButton(tf, 24, "Guider jusqu'au point de rendu")
        tf.go:SetPoint("TOPRIGHT", -10, -6)
        self.dTurn = tf
        -- distances et point du joueur tenus à jour pendant que l'onglet est affiché
        local acc = 0
        dc:SetScript("OnUpdate", function(_, el)
            acc = acc + (el or 0)
            if acc < 1.5 then return end
            acc = 0
            if self.view == "log" and not self.settingsOpen then self:RefreshLog() end
        end)

        -- carte de la zone : camps de toutes les quêtes du journal (la choisie en avant), cliquables
        local mc = newMini(p, "cercles : zones de quête · ? : rendu · point : toi")
        self.jMap = mc
        mc.onCamp = function(b, on)
            b.hoverSelf = on
            self:TintCamps()
            -- objectif correspondant mis en avant dans le détail
            local f = b.sel and self.objFrame and self.objFrame[b.oi]
            if f then f.hl:SetShown(on) end
            if on then
                UI:TooltipOwner(b, "ANCHOR_RIGHT")
                GameTooltip:SetText(b.qtitle or "", 1, 1, 1)
                if b.oname then
                    GameTooltip:AddLine(b.oname .. ((b.need or 0) > 0 and ("  " .. (b.have or 0) .. "/" .. b.need) or ""), 0.8, 0.8, 0.8, true)
                end
                GameTooltip:AddLine(T("Clic : guider jusqu'à cette zone de quête"), 0.6, 0.6, 0.6, true)
                GameTooltip:Show()
            else
                GameTooltip:Hide()
            end
        end
        mc.onCampClick = function(b)
            local c = b.camp
            if c then guideTo(c.map, c.x, c.y, b.oname or b.qtitle, b.qtitle, "Quête suivie", b.qid) end
        end
    end,

    -- Mise en avant des camps : quête choisie, quête survolée dans la liste, camp survolé
    TintCamps = function(self)
        local mc = self.jMap
        if not mc then return end
        local ar, ag, ab = UI:Accent()
        for _, b in ipairs(mc.camps) do
            if b:IsShown() then
                local hot = b.hoverSelf or (self.hoverQid ~= nil and b.qid == self.hoverQid)
                local col = b.done and C.positive or ((b.sel or hot) and { ar, ag, ab } or C.muted)
                local fa, ra
                if b.sel then fa, ra = hot and 0.42 or 0.25, 0.95
                else fa, ra = hot and 0.32 or 0.08, hot and 0.95 or 0.35 end
                b.fill:SetVertexColor(col[1], col[2], col[3], fa)
                b.ring:SetVertexColor(col[1], col[2], col[3], ra)
                b.hot:SetVertexColor(col[1], col[2], col[3], 1)
                b.hot:SetSize((b:GetWidth() or 20) + 4, (b:GetHeight() or 20) + 4)
                b.hot:SetShown(hot and true or false)
                b:SetFrameLevel(mc.pins:GetFrameLevel() + (hot and 3 or (b.sel and 2 or 1)))
            end
        end
    end,

    -- Disposition de l'onglet journal : colonne de gauche (liste puis détail, chacun défile), la carte prend
    -- tout le reste (largeur et hauteur)
    LayoutLog = function(self, top, w, h, hide)
        for _, f in ipairs({ self.jList, self.jDet, self.jMap }) do f:SetShown(not hide); f:ClearAllPoints() end
        if hide then return end
        w = (w and w > 100) and w or 800
        local colW = w >= 900 and COL_W or COL_W_NARROW
        local avail = math.max(300, h - top)
        local listH = math.max(150, math.floor(avail * 0.42))
        self.jList:SetWidth(colW); self.jList:SetHeight(listH)
        self.jList:SetPoint("TOPLEFT", 0, -top)
        self.jDet:SetWidth(colW)
        self.jDet:SetPoint("TOPLEFT", 0, -(top + listH + GAP)); self.jDet:SetPoint("BOTTOMLEFT", 0, 0)
        local mc = self.jMap
        mc:SetPoint("TOPLEFT", colW + GAP, -top); mc:SetPoint("BOTTOMRIGHT", 0, 0)
        fitMini(mc, w - colW - GAP, avail)
    end,

    -- Carte du journal : fond de la zone, camps des quêtes du journal (la choisie en avant, avec une
    -- étiquette « objectif · 3/8 » sur son plus grand camp par objectif), rendu, joueur
    PaintMini = function(self, map, objs, turn, others)
        local mc = self.jMap
        local AW, AH = paintMiniBase(mc, map, "Pas de lieu connu pour cette quête.")
        if not AW then return end
        local n, nl = 0, 0
        local function put(qid, qtitle, oi, o, sel)
            local best
            for _, c in ipairs(o.camps or {}) do
                if c.map == map then
                    n = n + 1
                    local b = campPin(mc, n)
                    local size = math.max(10, math.min(120, (c.r or 0.02) * 1.6 * AW))
                    b:SetSize(size, size)
                    b:ClearAllPoints(); b:SetPoint("CENTER", mc.area, "TOPLEFT", c.x * AW, -c.y * AH)
                    b.qid, b.qtitle, b.oi, b.oname, b.have, b.need, b.done, b.sel, b.camp = qid, qtitle, oi,
                        (o.name and o.name ~= "") and o.name or o.text, o.have, o.need, o.done, sel, c
                    b.hoverSelf = nil
                    b:Show()
                    if not best or (c.n or 0) > (best.c.n or 0) then best = { c = c, b = b } end
                end
            end
            -- étiquette sur le plus grand camp de chaque objectif de la quête choisie
            if sel and best then
                nl = nl + 1
                local l = mapLabel(mc, nl)
                local o2 = (o.name and o.name ~= "") and o.name or o.text or ""
                l:Set(o2 .. ((o.need or 0) > 0 and (" · " .. (o.have or 0) .. "/" .. o.need) or ""))
                l:ClearAllPoints(); l:SetPoint("TOP", best.b, "BOTTOM", 0, -2)
                l:Show()
            end
        end
        -- les autres quêtes d'abord (en dessous), puis la quête choisie
        for _, e in ipairs(others or {}) do
            for oi, o in ipairs(e.objs) do if not o.done then put(e.id, e.title, oi, o, false) end end
        end
        for oi, o in ipairs(objs or {}) do put(self.sel, self.selTitle, oi, o, true) end
        if turn and turn.map == map then
            mc.turnBg:ClearAllPoints(); mc.turnBg:SetPoint("CENTER", mc.area, "TOPLEFT", turn.x * AW, -turn.y * AH)
            mc.turnBg:Show(); mc.turn:Show()
        end
        self:TintCamps()
    end,

    RefreshLog = function(self)
        local qt = QT()
        if not qt or not self.jList then return end
        local quests = qt:LogQuests()
        local tracked = qt:Tracked()
        local myLevel = UnitLevel and UnitLevel("player") or 1
        local maxQ = 25
        if C_QuestLog and C_QuestLog.GetMaxNumQuestsCanAccept then
            local ok, m = pcall(C_QuestLog.GetMaxNumQuestsCanAccept)
            if ok and type(m) == "number" and m > 0 then maxQ = m end
        end
        -- quête choisie : celle d'avant si elle est encore là, sinon la suivie, sinon la première
        local selQ
        for _, q in ipairs(quests) do if q.id == self.sel then selQ = q end end
        if not selQ then
            self.sel = tracked or (quests[1] and quests[1].id)
            for _, q in ipairs(quests) do if q.id == self.sel then selQ = q end end
        end

        -- liste, rangée par zone (ordre du journal) ------------------------------------------
        self.jCount:SetText(T("Mon journal") .. "  " .. UI:Hex(#quests >= maxQ and C.warning or C.muted) .. #quests .. " / " .. maxQ .. "|r")
        self.jheads:Reset(); self.jrows:Reset()
        local others = {}
        local LW = self.jscroll:GetWidth() or 300
        if LW < 100 then LW = LOG_W - 8 end
        local y, lastZone = 0, false
        for _, q in ipairs(quests) do
            if q.zone ~= lastZone then
                lastZone = q.zone
                local hd = self.jheads:Get()
                hd:ClearAllPoints(); hd:SetPoint("TOPLEFT", 12, -(y + 10))
                hd:SetText(smallCaps(q.zone or T("Autres")))
                y = y + LHEAD_H
            end
            local r = self.jrows:Get()
            r.qid, r.title, r.sel = q.id, q.title, q.id == self.sel
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:SetWidth(LW - 14)
            r.lv:Set(q.level and tostring(q.level) or "?", q.level and levelColor(q.level, myLevel) or C.muted)
            r.name:SetText(q.title or ("#" .. q.id))
            r.name:SetTextColor(unpack(r.sel and C.text or (q.complete and C.positive or C.text)))
            r.tag:Hide(); r.right:Hide()
            if q.id == tracked then
                r.tag:Set(T("suivie")); r.tag:Show()
            elseif q.complete then
                r.right:SetText(T("à rendre")); r.right:SetTextColor(unpack(C.positive)); r.right:Show()
            else
                local objs = qt:Objectives(q.id)
                local done = 0
                for _, o in ipairs(objs) do if o.done then done = done + 1 end end
                if #objs > 0 then r.right:SetText(done .. "/" .. #objs); r.right:SetTextColor(unpack(C.muted)); r.right:Show() end
                if q.id ~= self.sel then table.insert(others, { id = q.id, title = q.title, objs = objs }) end
            end
            r:Paint()
            y = y + LROW_H
        end
        self.jscroll.child:SetSize(LW - 14, math.max(y + 6, 30))
        if self.jscroll.UpdateBar then self.jscroll:UpdateBar() end

        -- détail ------------------------------------------------------------------------------
        self.dheads:Reset(); self.dobjs:Reset()
        local has = selQ ~= nil
        self.dTitle:SetShown(has); self.dSub:SetShown(has); self.dscroll:SetShown(has)
        self.trackBtn:SetShown(has); self.mapBtn:SetShown(has)
        self.dEmpty:SetShown(not has)
        if not has then
            self.dEmpty:SetText(T("Ton journal est vide. Prends des quêtes : elles s'afficheront ici avec les zones de leurs objectifs et leur point de rendu."))
            self.miniMap = nil
            self:PaintMini(nil)
            return
        end
        local qid = selQ.id
        local title = selQ.title or qt:Title(qid)
        self.selTitle = title
        local complete = qt:IsComplete(qid)
        self.dTitle:SetText(title)
        local lvl = selQ.level or qt:Level(qid)
        local sub = string.format(T("niveau %s · %s"), lvl and tostring(lvl) or "?", selQ.zone or "-")
        if complete then sub = sub .. "  " .. UI:Hex(C.positive) .. "· " .. T("prête à rendre") .. "|r" end
        self.dSub:SetText(sub)

        local child = self.dscroll.child
        local DW = self.dscroll:GetWidth() or 400
        if DW < 100 then DW = 400 end
        local dy = 4
        local function head(text)
            local hd = self.dheads:Get()
            hd:ClearAllPoints(); hd:SetPoint("TOPLEFT", 12, -dy)
            hd:SetTextColor(unpack(C.muted))
            hd:SetText(text)
            dy = dy + 22
        end
        head(T("OBJECTIFS"))
        local objs = qt:Objectives(qid)
        self.objFrame = {}
        if #objs == 0 then
            local hd = self.dheads:Get()
            hd:ClearAllPoints(); hd:SetPoint("TOPLEFT", 34, -dy)
            hd:SetTextColor(unpack(C.dim))
            hd:SetText(T("Aucun objectif à suivre : va rendre la quête."))
            dy = dy + 24
        end
        for oi, o in ipairs(objs) do
            local f = self.dobjs:Get()
            self.objFrame[oi] = f
            f.hl:Hide()
            f:ClearAllPoints(); f:SetPoint("TOPLEFT", 0, -dy); f:SetWidth(DW - 14)
            if o.done then
                f.check:SetTexture(UI.MEDIA .. "circle"); f.check:SetVertexColor(unpack(C.positive))
            else
                f.check:SetTexture(UI.MEDIA .. "ring"); f.check:SetVertexColor(unpack(C.muted))
            end
            local name = (o.name and o.name ~= "") and o.name or o.text
            f.name:SetText(name)
            f.name:SetTextColor(unpack(o.done and C.muted or C.text))
            f.count:SetText((o.need or 0) > 0 and ((o.have or 0) .. "/" .. o.need) or "")
            f.count:SetTextColor(unpack(o.done and C.positive or C.muted))
            f.bar.color = o.done and C.positive or nil
            f.bar:SetValue((o.need or 0) > 0 and (o.have or 0) / o.need or (o.done and 1 or 0))
            local h = 32
            f.info:Hide(); f.go:Hide()
            if not o.done then
                local n = #(o.camps or {})
                if n > 0 then
                    local camp, d = nearestCamp(o.camps)
                    local txt
                    if n == 1 then
                        txt = d and string.format(T("1 zone · à %d m"), math.floor(d + 0.5)) or T("1 zone · sur une autre carte")
                    else
                        txt = d and string.format(T("%d zones · la plus proche à %d m"), n, math.floor(d + 0.5))
                            or string.format(T("%d zones · sur une autre carte"), n)
                    end
                    f.info:SetText(txt); f.info:Show()
                    f.go.tooltip = "Guider jusqu'à la zone la plus proche de cet objectif"
                    f.go:SetScript("OnClick", function() guideTo(camp.map, camp.x, camp.y, name, title, "Quête suivie", qid) end)
                    f.go:Show()
                else
                    f.info:SetText(T("Pas de zone connue pour cet objectif.")); f.info:Show()
                end
                h = math.max(60, 34 + math.max(14, f.info:GetStringHeight() or 14) + 10)
            end
            f:SetHeight(h)
            dy = dy + h + 8
        end

        dy = dy + 6
        head(T("RENDU"))
        local turn = qt:TurnIn(qid)
        local tf = self.dTurn
        tf:ClearAllPoints(); tf:SetPoint("TOPLEFT", 0, -dy); tf:SetWidth(DW - 14); tf:Show()
        if turn then
            tf.zone:SetText(mapName(turn.map) or ("#" .. turn.map)); tf.zone:SetTextColor(unpack(C.text))
            local d = distTo(turn.map, turn.x, turn.y)
            local dt = d and string.format(T("à %d m"), math.floor(d + 0.5)) or T("dans une autre zone")
            if complete then dt = UI:Hex(C.positive) .. T("prête à rendre") .. "|r · " .. dt end
            tf.dist:SetText(dt)
            tf.go.tooltip = "Guider jusqu'au point de rendu"
            tf.go:SetScript("OnClick", function() guideTo(turn.map, turn.x, turn.y, T("Rendre la quête"), title, "Quête à rendre", qid) end)
            tf.go:Show()
        else
            tf.zone:SetText(T("Point de rendu inconnu")); tf.zone:SetTextColor(unpack(C.muted))
            tf.dist:SetText("")
            tf.go:Hide()
        end
        dy = dy + 44
        child:SetSize(DW - 14, dy + 8)
        if self.dscroll.UpdateBar then self.dscroll:UpdateBar() end

        -- boutons
        local isTracked = tracked == qid
        self.trackBtn:SetLabel(isTracked and "Ne plus suivre" or "Suivre cette quête")
        self.trackBtn:SetStyle(isTracked and "secondary" or "primary")

        -- carte : zone du camp le plus proche (quête pas finie), sinon du rendu, sinon la tienne
        local map
        if not complete then
            local bd
            for _, o in ipairs(objs) do
                if not o.done then
                    for _, c in ipairs(o.camps or {}) do
                        local d = distTo(c.map, c.x, c.y) or math.huge
                        if not map or d < bd then map, bd = c.map, d end
                    end
                end
            end
        end
        if not map and turn then map = turn.map end
        if not map then local me = G() and G():PlayerPos(); map = me and me.map end
        self.miniMap = map
        self.mapBtn:SetEnabled(map ~= nil)
        self:PaintMini(map, objs, turn, others)
    end,

    ---------------------------------------------------------------------------
    -- Onglet « À prendre » : quêtes autour de toi par coin (Modules/QuestPlan.lua), à cocher
    ---------------------------------------------------------------------------
    BuildPick = function(self, p)
        local hold = CreateFrame("Frame", nil, p)
        self.pHold = hold
        self.pscroll = UI:Scroll(hold)
        self.pscroll:SetPoint("TOPLEFT", 0, 0)
        self.pscroll:SetPoint("BOTTOMRIGHT", 0, 46)
        self.pEmpty = UI:Text(hold, 12, C.muted)
        self.pEmpty:SetPoint("TOPLEFT", 16, -16); self.pEmpty:SetPoint("TOPRIGHT", -16, -16)
        self.pEmpty:SetJustifyH("LEFT")
        if self.pEmpty.SetWordWrap then self.pEmpty:SetWordWrap(true) end
        self.pGuideBtn = UI:Button(hold, string.format(T("Guider vers les donneurs (%d)"), 0), 230, 30, "secondary", "guide")
        self.pGuideBtn:SetPoint("BOTTOMLEFT", 0, 6)
        self.pGuideBtn:SetScript("OnClick", function() self:GuideGivers() end)
        self.pTourBtn = UI:Button(hold, "Créer la tournée", 160, 30, "primary")
        self.pTourBtn:SetPoint("BOTTOMLEFT", self.pGuideBtn, "BOTTOMRIGHT", 8, 0)
        self.pTourBtn:SetScript("OnClick", function() self:ShowTab("tour") end)

        local child = self.pscroll.child
        local function paintBox(box, on)
            local ar, ag, ab = UI:Accent()
            box.border:SetColor(ar, ag, ab, on and 1 or 0.7)
            box.fill:SetColor(ar, ag, ab, 1)
            box.fill:SetShown(on)
        end
        local function newRow(cd)
            local r = CreateFrame("Button", nil, cd)
            r:SetHeight(28)
            r.hl = r:CreateTexture(nil, "BACKGROUND"); r.hl:SetAllPoints(); r.hl:SetColorTexture(C.surface2[1], C.surface2[2], C.surface2[3], 0.5); r.hl:Hide()
            r.box = CreateFrame("Frame", nil, r)
            r.box:SetSize(16, 16); r.box:SetPoint("LEFT", 16, 0)
            UI:Panel(r.box, 4, C.surface, C.border)
            r.box.fill = UI:Rounded(r.box, 3, 3, "ARTWORK", 1)
            r.lv = UI:Badge(r, "")
            r.lv:SetPoint("LEFT", 42, 0)
            r.name = UI:Text(r, 12)
            r.name:SetPoint("LEFT", 80, 0); r.name:SetPoint("RIGHT", -200, 0)
            r.info = UI:Text(r, 11, C.muted)
            r.info:SetPoint("RIGHT", -16, 0); r.info:SetWidth(180); r.info:SetJustifyH("RIGHT")
            r:SetScript("OnClick", function(s)
                if not (s.e and QP()) then return end
                QP():SetPicked(s.e.id, not s.e.picked)
                self:RefreshPick()
            end)
            r:SetScript("OnEnter", function(s)
                s.hl:Show()
                if not s.e then return end
                UI:TooltipOwner(s, "ANCHOR_RIGHT")
                GameTooltip:SetText(s.e.title or "", 1, 1, 1)
                GameTooltip:AddDoubleLine(T("Niveau"), tostring(s.e.lvl or "?"), 0.6, 0.6, 0.6, 1, 1, 1)
                if (s.e.xp or 0) > 0 then GameTooltip:AddDoubleLine(T("Expérience"), tostring(s.e.xp), 0.6, 0.6, 0.6, 1, 1, 1) end
                GameTooltip:AddLine(T("Clic : cocher ou décocher pour la tournée"), 0.6, 0.6, 0.6, true)
                GameTooltip:Show()
            end)
            r:SetScript("OnLeave", function(s) s.hl:Hide(); GameTooltip:Hide() end)
            r.PaintBox = function(s) paintBox(s.box, s.e and s.e.picked) end
            UI:OnAccent(function() r:PaintBox() end)
            return r
        end
        self.pcards = UI:Pool(function()
            local cd = UI:Card(child)
            cd.head = UI:Text(cd, 13)
            cd.head:SetPoint("TOPLEFT", 16, -13)
            cd.tag = UI:Badge(cd, "")
            cd.tag:SetPoint("LEFT", cd.head, "RIGHT", 10, 0)
            cd.dist = UI:Text(cd, 11, C.muted)
            cd.dist:SetPoint("LEFT", cd.tag, "RIGHT", 8, 0)
            cd.xp = UI:Text(cd, 13, C.positive)
            cd.xp:SetPoint("TOPRIGHT", -16, -13)
            cd.rows = UI:Pool(function() return newRow(cd) end)
            return cd
        end)
    end,

    LayoutPick = function(self, top, w, h, hide)
        self.pHold:ClearAllPoints()
        self.pHold:SetShown(not hide)
        if hide then return end
        self.pHold:SetPoint("TOPLEFT", 0, -top)
        self.pHold:SetPoint("BOTTOMRIGHT", 0, 0)
    end,

    -- donneurs cochés pas encore pris : { e, d }, du plus proche au plus loin
    PickGivers = function(self, list)
        local out = {}
        for _, e in ipairs(list or {}) do
            if e.picked and not e.inLog and e.giver then
                table.insert(out, { e = e, d = distTo(e.giver.map, e.giver.x, e.giver.y) or math.huge })
            end
        end
        table.sort(out, function(a, b) return a.d < b.d end)
        return out
    end,

    GuideGivers = function(self)
        local P, g = QP(), G()
        if not (P and g) then return end
        local _, _, list = P:Coins()
        local first = self:PickGivers(list)[1]
        if not first then return end
        local e, gv = first.e, first.e.giver
        local t = { map = gv.map, x = gv.x, y = gv.y, e = { gv.x * 100, gv.y * 100, 0, nil, nil, e.title, e.title, T("Donneur de quête") } }
        t.cont, t.wx, t.wy = g.ToWorld(gv.map, gv.x, gv.y)
        g:Start(t, "Quête", "quest")
    end,

    RefreshPick = function(self)
        local P = QP()
        if not (P and self.pHold) then return end
        local coins, zone, list = P:Coins()
        local myLevel = UnitLevel and UnitLevel("player") or 1
        local here, inLog, xp = 0, 0, 0
        for _, e in ipairs(list or {}) do
            if e.inLog then inLog = inLog + 1 else here = here + 1 end
            if e.picked then xp = xp + (e.xp or 0) end
        end
        local build = P:Build()
        self.pickStats = { here = here, inLog = inLog, xp = xp, secs = build and build.secs or 0, steps = build and #build.steps or 0 }
        local givers = self:PickGivers(list)
        self.pGuideBtn:SetLabel(string.format(T("Guider vers les donneurs (%d)"), #givers))
        self.pGuideBtn:SetEnabled(#givers > 0)
        self.pTourBtn:SetEnabled(self.pickStats.steps > 0)

        self.pcards:Reset()
        local W = self.pscroll:GetWidth() or 600
        if W < 100 then W = 600 end
        local y = 0
        for _, k in ipairs(coins or {}) do
            local cd = self.pcards:Get()
            cd:ClearAllPoints(); cd:SetPoint("TOPLEFT", 0, -y); cd:SetWidth(W - 14)
            cd.head:SetText(string.format(T("Coin %s"), k.label or ""))
            local n = #k.quests
            cd.tag:Set(n == 1 and T("1 quête") or string.format(T("%d quêtes au même endroit"), n))
            cd.dist:SetText((k.d and k.d < 100000) and string.format(T("à %d m"), math.floor(k.d + 0.5)) or "")
            cd.xp:SetText((k.xp or 0) > 0 and ("+" .. k.xp .. " XP") or "")
            cd.rows:Reset()
            local ry = 44
            for _, e in ipairs(k.quests) do
                local r = cd.rows:Get()
                r.e = e
                r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -ry); r:SetPoint("TOPRIGHT", 0, -ry)
                r:PaintBox()
                r.lv:Set(e.lvl and tostring(e.lvl) or "?", e.lvl and levelColor(e.lvl, myLevel) or C.muted)
                r.name:SetText(e.title or ("#" .. e.id))
                r.name:SetTextColor(unpack((e.hard and not e.inLog) and C.muted or C.text))
                local info
                if e.inLog then info = e.complete and T("à rendre") or T("dans le journal")
                elseif e.hard then info = T("trop dur pour l'instant")
                elseif e.giver then
                    local d = distTo(e.giver.map, e.giver.x, e.giver.y)
                    info = d and string.format(T("donneur · %d m"), math.floor(d + 0.5)) or T("donneur")
                else info = "" end
                r.info:SetText(info)
                ry = ry + 28
            end
            cd:SetHeight(ry + 10)
            y = y + ry + 10 + GAP
        end
        local none = #(coins or {}) == 0
        self.pEmpty:SetShown(none)
        if none then
            self.pEmpty:SetText(zone and T("Rien à prendre ou à faire autour de toi pour ton niveau. Essaie la zone conseillée dans « Carte des zones ».")
                or T("Zone inconnue : la liste se remplit une fois en jeu, dans une zone qui a des quêtes."))
        end
        self.pscroll.child:SetSize(W - 14, math.max(y, 30))
        if self.pscroll.UpdateBar then self.pscroll:UpdateBar() end
        if UI.RefreshChips and UI.current == "quests" then UI:RefreshChips() end
    end,

    ---------------------------------------------------------------------------
    -- Onglet « Tournée » : étapes de la tournée en cours (ou l'aperçu) et petite carte
    ---------------------------------------------------------------------------
    BuildTour = function(self, p)
        local tc = UI:Card(p)
        self.tList = tc
        self.tHead = UI:Text(tc, 13)
        self.tHead:SetPoint("TOPLEFT", 14, -12); self.tHead:SetPoint("TOPRIGHT", -14, -12)
        self.tHead:SetJustifyH("LEFT")
        if self.tHead.SetWordWrap then self.tHead:SetWordWrap(true) end
        self.tSub = UI:Text(tc, 11, C.muted)
        self.tSub:SetPoint("TOPLEFT", self.tHead, "BOTTOMLEFT", 0, -5); self.tSub:SetPoint("TOPRIGHT", self.tHead, "BOTTOMRIGHT", 0, -5)
        self.tscroll = UI:Scroll(tc)
        self.tscroll:SetPoint("TOPLEFT", 4, -74)
        self.tscroll:SetPoint("BOTTOMRIGHT", -4, 90)
        self.tEmpty = UI:Text(self.tscroll.child, 12, C.muted)
        self.tEmpty:SetPoint("TOPLEFT", 12, -8)
        local function act(fn)
            return function()
                local P = QP()
                if P then fn(P) end
                self:RefreshTour()
            end
        end
        self.tStart = UI:Button(tc, "Lancer la tournée", 170, 30, "primary", "play")
        self.tStart:SetPoint("BOTTOMLEFT", 14, 12)
        self.tStart:SetScript("OnClick", act(function(P) P:Start() end))
        self.tSkip = UI:Button(tc, "Passer l'étape", nil, 30, "secondary")
        self.tSkip:SetPoint("BOTTOMLEFT", 14, 12)
        self.tSkip:SetScript("OnClick", act(function(P) P:Skip() end))
        self.tPause = UI:Button(tc, "Reprendre", 110, 30, "secondary")
        self.tPause:SetPoint("BOTTOMLEFT", self.tSkip, "BOTTOMRIGHT", 8, 0)
        self.tPause:SetScript("OnClick", act(function(P) local t = P:Tour(); P:Pause(not (t and t.paused)) end))
        self.tReorder = UI:Button(tc, "Réordonner", nil, 30, "secondary", "refresh")
        self.tReorder:SetPoint("BOTTOMLEFT", self.tPause, "BOTTOMRIGHT", 8, 0)
        self.tReorder:SetScript("OnClick", act(function(P) P:Reorder() end))
        self.tStop = UI:Button(tc, "Arrêter", nil, 30, "danger")
        self.tStop:SetPoint("BOTTOMLEFT", self.tReorder, "BOTTOMRIGHT", 8, 0)
        self.tStop:SetScript("OnClick", act(function(P) P:Stop() end))
        self.tsteps = UI:Pool(function()
            local r = CreateFrame("Frame", nil, self.tscroll.child)
            r:SetHeight(48)
            r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints()
            r.bar = r:CreateTexture(nil, "ARTWORK"); r.bar:SetPoint("TOPLEFT"); r.bar:SetPoint("BOTTOMLEFT"); r.bar:SetWidth(3)
            r.dot = r:CreateTexture(nil, "ARTWORK")
            r.dot:SetTexture(UI.MEDIA .. "circle"); r.dot:SetSize(24, 24); r.dot:SetPoint("TOPLEFT", 12, -12)
            r.num = UI:Text(r, 11)
            r.num:SetPoint("CENTER", r.dot, "CENTER", 0, 0)
            r.title = UI:Text(r, 12)
            r.title:SetPoint("TOPLEFT", 46, -8); r.title:SetPoint("TOPRIGHT", -12, -8)
            r.sub = UI:Text(r, 11, C.muted)
            r.sub:SetPoint("TOPLEFT", 46, -27); r.sub:SetPoint("TOPRIGHT", -12, -27)
            return r
        end)
        local mc = newMini(p, "numéros : étapes · point : toi")
        self.tMap = mc
        mc.onStep = function(b, on)
            if not on then GameTooltip:Hide() return end
            local P = QP()
            if not (P and b.step) then return end
            UI:TooltipOwner(b, "ANCHOR_RIGHT")
            GameTooltip:SetText(string.format(T("Étape %d"), b.idx), 1, 1, 1)
            GameTooltip:AddLine(P:StepTitle(b.step), 0.85, 0.85, 0.85, true)
            GameTooltip:AddLine(self:StepSub(P, b.step), 0.6, 0.6, 0.6, true)
            GameTooltip:AddLine(T("Clic : guider jusqu'à cette étape"), 0.6, 0.6, 0.6, true)
            GameTooltip:Show()
        end
        mc.onStepClick = function(b)
            local P, g = QP(), G()
            local st = b.step
            if not (P and g and st and st.map and st.x) then return end
            local title = P:StepTitle(st)
            local t = { map = st.map, x = st.x, y = st.y, e = { st.x * 100, st.y * 100, 0, nil, nil, title, title,
                string.format(T("Étape %d"), b.idx) } }
            t.cont, t.wx, t.wy = g.ToWorld(st.map, st.x, st.y)
            -- tournée en cours : genre « qtour » (QuestPlan reprend la main à l'étape suivante)
            g:Start(t, "Tournée de quêtes", P:Tour() and "qtour" or "quest")
        end
        -- point du joueur tenu à jour sur la petite carte
        local acc = 0
        tc:SetScript("OnUpdate", function(_, el)
            acc = acc + (el or 0)
            if acc < 2 then return end
            acc = 0
            if self.view == "tour" and not self.settingsOpen then self:PaintTourMap() end
        end)
    end,

    -- Disposition de l'onglet tournée : colonne de gauche (étapes et boutons), la carte prend le reste
    LayoutTour = function(self, top, w, h, hide)
        for _, f in ipairs({ self.tList, self.tMap }) do f:SetShown(not hide); f:ClearAllPoints() end
        if hide then return end
        w = (w and w > 100) and w or 800
        local colW = w >= 900 and COL_W or COL_W_NARROW
        self.tList:SetWidth(colW)
        self.tList:SetPoint("TOPLEFT", 0, -top); self.tList:SetPoint("BOTTOMLEFT", 0, 0)
        local mc = self.tMap
        mc:SetPoint("TOPLEFT", colW + GAP, -top); mc:SetPoint("BOTTOMRIGHT", 0, 0)
        fitMini(mc, w - colW - GAP, math.max(300, h - top))
        -- boutons : « Lancer » sur toute la largeur, sinon deux par ligne
        local bw = math.floor((colW - 24 - 8) / 2)
        self.tStart:ClearAllPoints(); self.tStart:SetPoint("BOTTOMLEFT", 12, 12); self.tStart:SetPoint("BOTTOMRIGHT", -12, 12)
        local grid = { { self.tSkip, 0, 48 }, { self.tPause, 1, 48 }, { self.tReorder, 0, 12 }, { self.tStop, 1, 12 } }
        for _, g in ipairs(grid) do
            g[1]:ClearAllPoints(); g[1]:SetWidth(bw)
            g[1]:SetPoint("BOTTOMLEFT", 12 + g[2] * (bw + 8), g[3])
        end
    end,

    -- sous-ligne d'une étape
    StepSub = function(self, P, s)
        local txt
        if s.kind == "pick" then txt = T("parler au donneur")
        elseif s.kind == "turn" then txt = T("rendre au PNJ")
        elseif s.kind == "trainer" then txt = (s.title and (s.title .. " · ") or "") .. T("apprendre tes sorts")
        else
            local objs = P:StepObjectives(s)
            local left = {}
            for _, o in ipairs(objs) do if not o.done then table.insert(left, o) end end
            if #left >= 3 then txt = string.format(T("%d objectifs dans la même zone"), #left)
            elseif #left > 0 then
                local parts = {}
                for _, o in ipairs(left) do
                    table.insert(parts, (o.name or "") .. ((o.need or 0) > 0 and (" " .. (o.have or 0) .. "/" .. o.need) or ""))
                end
                txt = table.concat(parts, " · ")
            elseif #objs > 0 then txt = T("objectifs faits")
            else txt = T("objectifs connus une fois la quête prise") end
        end
        if (s.secs or 0) >= 30 then txt = txt .. "  ·  " .. string.format(T("env. %d min"), math.max(1, math.floor(s.secs / 60 + 0.5))) end
        return txt
    end,

    RefreshTour = function(self)
        local P = QP()
        if not (P and self.tList) then return end
        local tour = P:Tour()
        local data = tour or P:Build() or { steps = {} }
        local steps = data.steps or {}
        local idx = tour and tour.idx or 0
        local secs = tour and P:Remaining() or (data.secs or 0)
        local km = (string.format("%.1f", (data.meters or 0) / 1000):gsub("%.", ","))
        self.tHead:SetText(string.format(T("Tournée · %d étapes · env. %d min · %s km"), #steps, math.max(1, math.floor(secs / 60 + 0.5)), km))
        if not tour then
            self.tSub:SetText(#steps > 0 and T("Aperçu : la tournée n'est pas lancée.") or "")
        elseif tour.paused then
            self.tSub:SetText(UI:Hex(C.warning) .. T("En pause") .. "|r  ·  " .. string.format(T("étape %d / %d"), idx, #steps))
        else
            self.tSub:SetText(string.format(T("En cours · étape %d / %d"), idx, #steps))
        end
        self.tsteps:Reset()
        local W = self.tscroll:GetWidth() or 500
        if W < 100 then W = 500 end
        local ar, ag, ab = UI:Accent()
        local y = 0
        for i, s in ipairs(steps) do
            local r = self.tsteps:Get()
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:SetWidth(W - 14)
            local past = tour and i < idx
            local cur = tour and i == idx
            local col = (past and C.dim) or (s.kind == "pick" and C.gold) or (s.kind == "turn" and C.positive) or (s.kind == "trainer" and C.info) or { ar, ag, ab }
            r.dot:SetVertexColor(col[1], col[2], col[3], 1)
            r.num:SetText(tostring(i))
            r.num:SetTextColor(unpack(past and C.text or C.onAccent))
            r.title:SetText(P:StepTitle(s))
            r.title:SetTextColor(unpack(past and C.muted or C.text))
            r.sub:SetText(self:StepSub(P, s))
            if cur then
                r.bg:SetColorTexture(unpack(C.surface2)); r.bg:Show()
                r.bar:SetColorTexture(ar, ag, ab, 1); r.bar:Show()
            else r.bg:Hide(); r.bar:Hide() end
            y = y + 50
        end
        self.tEmpty:SetShown(#steps == 0)
        self.tEmpty:SetText(T("Aucune étape : coche des quêtes dans « Quêtes de ma zone »."))
        self.tscroll.child:SetSize(W - 14, math.max(y, 30))
        if self.tscroll.UpdateBar then self.tscroll:UpdateBar() end
        -- boutons
        self.tStart:SetShown(not tour); self.tStart:SetEnabled(#steps > 0)
        for _, b in ipairs({ self.tSkip, self.tPause, self.tReorder, self.tStop }) do b:SetShown(tour ~= nil) end
        self.tPause:SetLabel(tour and tour.paused and "Reprendre" or "Pause")
        self.tourSteps, self.tourIdx = steps, idx
        self:PaintTourMap()
    end,

    -- Carte de la tournée : étapes numérotées de la zone (cliquables : guidage), reliées, et point du joueur
    PaintTourMap = function(self)
        local mc = self.tMap
        local steps, idx = self.tourSteps or {}, self.tourIdx or 0
        local cur = steps[idx] or steps[1]
        local map = cur and cur.map
        if not map then local me = G() and G():PlayerPos(); map = me and me.map end
        local AW, AH = paintMiniBase(mc, map, "Aucune étape à montrer.")
        if not AW then return end
        local ar, ag, ab = UI:Accent()
        local size = math.max(14, math.min(22, AW / 34))
        local n, nl, prev = 0, 0, nil
        for i, s in ipairs(steps) do
            if s.map == map and s.x then
                n = n + 1
                local x, y = s.x * AW, s.y * AH
                local past = idx > 0 and i < idx
                if prev then
                    nl = nl + 1
                    mapLine(mc, nl, prev[1], prev[2], x, y, past and C.dim or { ar, ag, ab }, math.max(2, size / 10))
                end
                prev = { x, y }
                local b = stepPin(mc, n)
                b.step, b.idx = s, i
                b:SetSize(size, size); b.edge:SetSize(size + 4, size + 4)
                local col = (past and C.dim) or (s.kind == "pick" and C.gold) or (s.kind == "turn" and C.positive) or (s.kind == "trainer" and C.info) or { ar, ag, ab }
                b:ClearAllPoints(); b:SetPoint("CENTER", mc.area, "TOPLEFT", x, -y)
                b.dot:SetVertexColor(col[1], col[2], col[3], 1)
                b.num:SetText(tostring(i)); b.num:SetTextColor(unpack(past and C.text or C.onAccent))
                -- étape en cours au-dessus des autres
                b:SetFrameLevel(mc.top:GetFrameLevel() + (i == idx and 3 or 1))
                b:Show()
            end
        end
    end,

    Refresh = function(self)
        local cfg = Q:Config()
        if self.PaintAutoLog and self.settingsOpen then self.PaintAutoLog() end
        -- menu des persos à jour (perso renommé ou supprimé : retour au premier)
        self.charDd:SetOptions(charOptions())
        if self.charDd.selected ~= self.viewKey then
            if WK.DB.global.characters[self.viewKey] then self.charDd:Select(self.viewKey) else self.viewKey = self.charDd.selected end
        end
        for _, t in ipairs(self.toggles) do t:Refresh() end
        if self.campSeg and QT() then self.campSeg:Select(QT():Config().map) end
        if self.maxSeg and QP() then self.maxSeg:Select(QP():Config().maxAbove) end
        if not self.zoneSum then self:ZoneSummary() end
        if self.view == "montee" then self:RefreshMontee() return end
        if self.view == "log" then self:RefreshLog() return end
        if self.view == "pick" then self:RefreshPick() return end
        if self.view == "tour" then self:RefreshTour() return end
        local key = self.viewKey or WK:CharKey()
        local c = WK.DB.global.characters[key] or {}
        local myLevel = c.level or 1
        local zones = Q:Zones(key)
        local playerZone = key == WK:CharKey() and Q:PlayerZone() or nil
        local best = Q:BestZone(key)
        self:ZoneSummary(zones)
        self.zone = self.zone or playerZone or (best and best.map) or (zones[1] and zones[1].map)
        local r1, g1, b1 = UI:Accent()

        -- bandeau
        local qDone, qTotal = Q:Totals(key)
        local accent = { r1, g1, b1 }
        self.kpi:Set(1, { label = string.format(T("QUÊTES FAITES · %s"), WK:CharName(c, key)), value = qDone .. UI:Hex(C.muted) .. " / " .. qTotal .. "|r",
            sub = qTotal > 0 and string.format(T("%d %% du total pour ce perso"), math.floor(qDone / qTotal * 100 + 0.5)) or "",
            frac = qTotal > 0 and qDone / qTotal or 0, color = accent })
        local X = WK.modules.XP
        local pend = key == WK:CharKey() and X and X.Pending and X:Pending() or {}
        local pxp = 0
        for _, e in ipairs(pend) do pxp = pxp + (e.xp or 0) end
        self.kpi:Set(2, { label = T("À RENDRE"), value = tostring(#pend), color = #pend > 0 and C.positive or C.muted,
            sub = #pend > 0 and string.format(T("%s XP · clic : guider"), BreakUpLargeNumbers and BreakUpLargeNumbers(pxp) or pxp) or T("rien à rendre"),
            onClick = #pend > 0 and function() X:GuideNearest() end or nil })
        local near, nearZones = 0, 0
        for _, z in ipairs(zones) do
            local zn = 0
            for _, q in ipairs(Q:OnMap(z.map)) do
                if (q.lvl or 0) >= myLevel - 3 and (q.lvl or 0) <= myLevel + 3 and Q:ForChar(q, c) and Q:State(q, c) == "avail" then zn = zn + 1 end
            end
            near = near + zn
            if zn > 0 then nearZones = nearZones + 1 end
        end
        self.kpi:Set(3, { label = string.format(T("POUR TON NIVEAU (%d)"), myLevel), value = tostring(near), color = C.gold,
            sub = string.format(T("quêtes disponibles dans %d zones"), nearZones) })
        self.kpi:Set(4, { label = T("ZONE CONSEILLÉE"), value = best and best.name or "-", color = C.positive,
            sub = best and string.format(T("%d à faire · niveaux %d-%d"), best.avail, best.min, best.max) or T("aucune pour l'instant"),
            onClick = best and function() self.zone = best.map; self:Refresh() end or nil })

        -- carte du continent : une bulle par zone, couleur et taille = avancement
        for _, z in ipairs(zones) do z.frac = z.total > 0 and z.done / z.total or 0 end
        self.map:SetData(zones, {
            selected = self.zone, player = playerZone, best = best and best.map,
            color = function(z)
                if z.frac >= 1 then return C.positive end
                if z.frac >= 0.5 then return C.positive end
                if z.frac >= 0.15 then return C.gold end
                if z.frac > 0 then return accent end
                return C.dim
            end,
            onClick = function(map) self.zone = map; self:Refresh() end,
            tip = function(z, tt)
                tt:AddDoubleLine(T("Quêtes faites"), z.done .. " / " .. z.total, 0.7, 0.7, 0.7, 1, 1, 1)
                tt:AddDoubleLine(T("Niveaux"), z.min .. "-" .. z.max, 0.7, 0.7, 0.7, 1, 1, 1)
                if z.avail > 0 then tt:AddDoubleLine(T("Disponibles"), tostring(z.avail), 0.7, 0.7, 0.7, 1, 1, 1) end
            end,
        })
        self.map.legend:SetText(T("taille et couleur = avancement · clic : voir la zone"))

        -- liste des zones (ta zone, la conseillée, puis par niveau)
        local ordered = {}
        for _, z in ipairs(zones) do if z.map == playerZone then table.insert(ordered, z) end end
        for _, z in ipairs(zones) do if best and z.map == best.map and z.map ~= playerZone then table.insert(ordered, z) end end
        for _, z in ipairs(zones) do if z.map ~= playerZone and not (best and z.map == best.map) then table.insert(ordered, z) end end
        self.zrows:Reset()
        local ZW = (self.zscroll:GetWidth() or 400)
        if ZW < 100 then ZW = 400 end
        for i, z in ipairs(ordered) do
            local r = self.zrows:Get()
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -(i - 1) * UI.ZONE_ROW_H); r:SetWidth(ZW - 14)
            local tag
            if z.map == playerZone then tag = { T("ta zone"), accent }
            elseif best and z.map == best.map then tag = { T("conseillée"), C.positive } end
            r:Fill(z, { selected = z.map == self.zone, frac = z.frac, color = accent, tag = tag, level = myLevel,
                right = z.avail > 0 and string.format(T("%d à faire"), z.avail) or (z.done >= z.total and T("finie") or "") })
        end
        self.zTitle:SetText(string.format(T("Zones · %d"), #ordered))
        self.zscroll.child:SetSize(ZW - 14, #ordered * UI.ZONE_ROW_H)
        if self.zscroll.UpdateBar then self.zscroll:UpdateBar() end

        -- quêtes de la zone choisie
        self.qrows:Reset()
        local all = self.zone and Q:OnMap(self.zone) or {}
        local LW = (self.lscroll:GetWidth() or 600)
        if LW < 100 then LW = 600 end
        local ly, shown, total = 0, 0, 0
        for _, q in ipairs(all) do
            if Q:ForChar(q, c) then
                total = total + 1
                local st, need = Q:State(q, c)
                local keep = (cfg.filter == "all" or (cfg.filter == "done" and st == "done") or (cfg.filter == "todo" and st ~= "done"))
                if st == "high" and not cfg.high then keep = false end
                if keep then
                    shown = shown + 1
                    local row = self.qrows:Get()
                    row.q = q
                    row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -ly); row:SetWidth(LW - 14)
                    row.line:SetColorTexture(C.border[1], C.border[2], C.border[3], 0.6)
                    row.lv:SetText(q.lvl > 0 and tostring(q.lvl) or "-")
                    row.lv:SetTextColor(unpack(st == "done" and C.dim or levelColor(q.lvl, myLevel)))
                    local col, label = stateInfo(st)
                    row.med:SetVertexColor(unpack(col)); row.mark:SetVertexColor(unpack(col))
                    row.name:SetText(Q:Name(q))
                    row.name:SetTextColor(unpack(st == "done" and C.dim or C.text))
                    local parts = {}
                    if q.skill then table.insert(parts, UI:Hex(C.positive) .. T(q.skill) .. "|r")
                    elseif KIND[q.kind] then table.insert(parts, T(KIND[q.kind])) end
                    if st == "locked" and need and Q:Get(need) then table.insert(parts, string.format(T("après « %s »"), Q:Name(Q:Get(need))))
                    elseif st == "high" then table.insert(parts, string.format(T("niveau %d requis"), q.req)) end
                    if (q.xp or 0) > 0 then table.insert(parts, q.xp .. " XP") end
                    row.sub:SetText(table.concat(parts, "  ·  "))
                    row.state:Set(label, col)
                    row.guide:SetShown(q.x ~= nil and st ~= "done")
                    row.guide:SetScript("OnClick", function() Q:GuideTo(q) end)
                    ly = ly + ROW_H
                end
            end
        end
        local zname = self.zone and WK.modules.Rares:ZoneName(self.zone) or ""
        self.lTitle:SetText(zname .. "  " .. UI:Hex(C.muted) .. "· " .. string.format(T("%d quêtes"), total) .. "|r")
        self.lSub:SetText(Q:Known(key) and T("triées par niveau") or T("connecte ce perso pour lire ses quêtes faites"))
        self.empty:SetShown(shown == 0)
        self.empty:ClearAllPoints(); self.empty:SetPoint("TOPLEFT", 14, -10)
        self.empty:SetText(total == 0 and T("Choisis une zone.") or T("Aucune quête pour ce filtre."))
        self.lscroll.child:SetSize(LW - 14, math.max(ly, 30))
        if self.lscroll.UpdateBar then self.lscroll:UpdateBar() end
    end,
})
