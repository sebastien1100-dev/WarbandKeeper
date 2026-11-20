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
local LOG_W, MINI_W, LROW_H, LHEAD_H = 330, 250, 28, 26
local function QT() return WK.modules.QuestTrack end
local function QP() return WK.modules.QuestPlan end
local VIEWS = { log = true, pick = true, tour = true, zones = true }
local function G() return WK.modules.Guide end

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

-- Petite carte d'une zone (onglets Mon journal et Tournée) : fond = tuiles de la carte du jeu (comme
-- UI:ZoneMap), repères posés par la page, point du joueur
local function newMini(p, legend)
    local mc = UI:Card(p)
    mc.name = UI:Text(mc, 12)
    mc.name:SetPoint("TOPLEFT", 12, -11); mc.name:SetPoint("TOPRIGHT", -12, -11)
    mc.area = CreateFrame("Frame", nil, mc)
    mc.area:SetPoint("TOP", 0, -34)
    mc.area:SetSize(MINI_W - 16, math.floor((MINI_W - 16) * 2 / 3))
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
    mc.top:SetFrameLevel(mc.area:GetFrameLevel() + 8)
    mc.fills, mc.rings = {}, {}
    mc.me = mc.top:CreateTexture(nil, "OVERLAY")
    mc.me:SetTexture(UI.MEDIA .. "circle"); mc.me:SetSize(9, 9); mc.me:SetVertexColor(unpack(C.text))
    mc.meEdge = mc.top:CreateTexture(nil, "ARTWORK")
    mc.meEdge:SetTexture(UI.MEDIA .. "circle"); mc.meEdge:SetSize(13, 13); mc.meEdge:SetVertexColor(unpack(C.inset))
    mc.meEdge:SetPoint("CENTER", mc.me, "CENTER")
    mc.turnBg = mc.top:CreateTexture(nil, "ARTWORK")
    mc.turnBg:SetTexture(UI.MEDIA .. "circle"); mc.turnBg:SetSize(18, 18); mc.turnBg:SetVertexColor(unpack(C.inset))
    mc.turn = UI:Text(mc.top, 14, C.gold)
    mc.turn:SetPoint("CENTER", mc.turnBg, "CENTER", 0, 0)
    mc.turn:SetText("?")
    mc.none = UI:Text(mc.area, 11, C.dim)
    mc.none:SetPoint("CENTER")
    mc.legend = UI:Text(mc, 10, C.dim)
    mc.legend:SetPoint("BOTTOMLEFT", 12, 9); mc.legend:SetPoint("BOTTOMRIGHT", -12, 9)
    mc.legend:SetText(T(legend))
    mc.marks, mc.nums, mc.lines = {}, {}, {}
    return mc
end

-- Fond, nom et point du joueur ; renvoie la taille de la zone de dessin, ou nil (rien à montrer)
local function paintMiniBase(mc, map, emptyText)
    local AW, AH = mc.area:GetWidth() or 0, mc.area:GetHeight() or 0
    for _, t in ipairs(mc.fills) do t:Hide() end
    for _, t in ipairs(mc.rings) do t:Hide() end
    for _, t in ipairs(mc.marks) do t:Hide() end
    for _, t in ipairs(mc.nums) do t:Hide() end
    for _, t in ipairs(mc.lines) do t:Hide() end
    mc.me:Hide(); mc.meEdge:Hide(); mc.turn:Hide(); mc.turnBg:Hide()
    if not map or AW < 20 or AH < 20 then
        for _, t in ipairs(mc.tiles) do t:Hide() end
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
    end
    local me = G() and G():PlayerPos()
    if me and me.map == map and me.x then
        mc.me:ClearAllPoints(); mc.me:SetPoint("CENTER", mc.area, "TOPLEFT", me.x * AW, -me.y * AH)
        mc.me:Show(); mc.meEdge:Show()
    end
    return AW, AH
end

-- Taille de la petite carte : largeur de la carte, hauteur de la zone de dessin (proportions 3:2)
local function sizeMini(mc, mapW, maxAH)
    local AW = mapW - 16
    if maxAH then AW = math.min(AW, math.floor(maxAH * 1.5)) end
    local AH = math.floor(AW * 2 / 3)
    mc.area:SetSize(AW, AH)
    mc:SetHeight(34 + AH + 30)
    mc.artKey = nil
    return 34 + AH + 30
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

        -- Onglets : Mon journal / Carte des zones (retenu dans settings.ui.questTab) -----------
        local ui = WK.DB.global.settings.ui
        self.view = VIEWS[ui.questTab or ""] and ui.questTab or "log"
        self.tabSeg = UI:Segmented(p, { { "log", "Mon journal" }, { "pick", "À prendre" }, { "tour", "Tournée" },
            { "zones", "Carte des zones" } },
            function(v) self:ShowTab(v) end, 30)
        self.tabSeg:SetPoint("TOPLEFT")
        self.tabSeg:Select(self.view)

        -- Barre de commandes ---------------------------------------------------------
        local of = UI:Text(p, 11, C.muted)
        of:SetPoint("TOPLEFT", self.tabSeg, "TOPRIGHT", 14, -9)
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
        gear:SetPoint("TOPRIGHT")
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
            local tcard = card("Quête suivie", 40 + (QP() and 6 or 4) * 36 + 6, "journal, flèche et carte")
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
            UI:SettingRow(tcard, -112, "Flèche vers les camps", nil, qtoggle("guide", function(v)
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
            UI:SettingRow(tcard, -148, "Camps sur la carte", nil, self.campSeg, self.campSeg:GetWidth())
            self.campSeg:Select(QT():Config().map)
            -- plan de quêtes (Modules/QuestPlan.lua) : alerte près d'un donneur, niveau des quêtes proposées
            if QP() then
                local nt = UI:Toggle(tcard, function() return QP():Config().nearAlert end,
                    function(v) QP():Config().nearAlert = v; WK:NotifyChanged() end)
                table.insert(self.toggles, nt)
                UI:SettingRow(tcard, -184, "Prévenir près d'un donneur utile", nil, nt, 50)
                self.maxSeg = UI:Segmented(tcard, { { 0, "0" }, { 1, "1" }, { 2, "2" }, { 3, "3" } },
                    function(v) QP():Config().maxAbove = v; WK:NotifyChanged() end, 26)
                UI:SettingRow(tcard, -220, "Quêtes au-dessus de ton niveau", nil, self.maxSeg, self.maxSeg:GetWidth())
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
        -- « Quêtes de » et le filtre (onglet zones) : à côté des onglets, ou dessous si la place manque
        local zonesView = self.view == "zones"
        local barW = (self.tabSeg:GetWidth() or 400) + 14 + 70 + 8 + 190 + 8 + (self.filterSeg:GetWidth() or 230) + 44
        local second = zonesView and w < barW
        self.ofLabel:ClearAllPoints()
        if second then self.ofLabel:SetPoint("TOPLEFT", 0, -(30 + GAP + 9))
        else self.ofLabel:SetPoint("TOPLEFT", self.tabSeg, "TOPRIGHT", 14, -9) end
        local top = 30 + GAP + (second and (30 + GAP) or 0)
        self.side:ClearAllPoints()
        local open = self.settingsOpen == true
        self.gear:SetActive(open)
        self.side:SetShown(open)
        -- réglages : sur toute la largeur, sous la barre
        self.side:SetPoint("TOPLEFT", 0, -top)
        self.side:SetPoint("BOTTOMRIGHT")
        self.side.child:SetSize(math.min(w - 10, 560), self.sideH or 400)
        if self.side.UpdateBar then self.side:UpdateBar() end
        -- onglet affiché : zones (barre « Quêtes de », filtre) ou journal
        self.ofLabel:SetShown(zonesView); self.charDd:SetShown(zonesView); self.filterSeg:SetShown(zonesView)
        UI:ZoneLayout(self, p, top, w, h, open or not zonesView)
        self:LayoutLog(top, w, h, open or self.view ~= "log")
        self:LayoutPick(top, w, h, open or self.view ~= "pick")
        self:LayoutTour(top, w, h, open or self.view ~= "tour")
    end,

    -- onglet choisi (boutons d'onglet, pastille « Suivie » de l'en-tête)
    ShowTab = function(self, v)
        self.view = VIEWS[v or ""] and v or "log"
        WK.DB.global.settings.ui.questTab = self.view
        self.tabSeg:Select(self.view)
        self.settingsOpen = false
        self:Layout()
        self:Refresh()
        if UI.RefreshChips then UI:RefreshChips() end
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
                if s.title then
                    UI:TooltipOwner(s, "ANCHOR_RIGHT")
                    GameTooltip:SetText(s.title, 1, 1, 1)
                    GameTooltip:Show()
                end
            end)
            r:SetScript("OnLeave", function(s) s.hover = false; paintRow(s); GameTooltip:Hide() end)
            UI:OnAccent(function() paintRow(r) end)
            return r
        end)

        -- détail de la quête choisie --------------------------------------------------------
        local dc = UI:Card(p)
        self.jDet = dc
        self.dTitle = UI:Text(dc, 17)
        self.dTitle:SetPoint("TOPLEFT", 16, -14); self.dTitle:SetPoint("TOPRIGHT", -16, -14)
        self.dSub = UI:Text(dc, 11, C.muted)
        self.dSub:SetPoint("TOPLEFT", self.dTitle, "BOTTOMLEFT", 0, -5); self.dSub:SetPoint("TOPRIGHT", self.dTitle, "BOTTOMRIGHT", 0, -5)
        self.dscroll = UI:Scroll(dc)
        self.dscroll:SetPoint("TOPLEFT", 4, -60)
        self.dscroll:SetPoint("BOTTOMRIGHT", -4, 54)
        self.trackBtn = UI:Button(dc, "Suivre cette quête", 170, 30, "primary")
        self.trackBtn:SetPoint("BOTTOMLEFT", 14, 12)
        self.trackBtn:SetScript("OnClick", function()
            local qt = QT()
            if not (qt and self.sel) then return end
            if qt:Tracked() == self.sel then qt:Untrack() else qt:Track(self.sel) end
            self:RefreshLog()
        end)
        self.mapBtn = UI:Button(dc, "Voir sur la carte", nil, 30, "secondary", "map")
        self.mapBtn:SetPoint("BOTTOMLEFT", self.trackBtn, "BOTTOMRIGHT", 8, 0)
        self.mapBtn:SetScript("OnClick", function() openWorldMap(self.miniMap) end)
        self.dEmpty = UI:Text(dc, 12, C.muted)
        self.dEmpty:SetPoint("TOPLEFT", 16, -18); self.dEmpty:SetPoint("TOPRIGHT", -16, -18)
        self.dEmpty:SetJustifyH("LEFT")
        if self.dEmpty.SetWordWrap then self.dEmpty:SetWordWrap(true) end
        local child = self.dscroll.child
        self.dheads = UI:Pool(function() return UI:Text(child, 10, C.muted) end)
        self.dobjs = UI:Pool(function()
            local f = CreateFrame("Frame", nil, child)
            f.check = f:CreateTexture(nil, "ARTWORK")
            f.check:SetSize(14, 14); f.check:SetPoint("TOPLEFT", 12, -1)
            f.name = UI:Text(f, 12)
            f.name:SetPoint("TOPLEFT", 34, -2); f.name:SetPoint("TOPRIGHT", -70, -2)
            f.count = UI:Text(f, 11, C.muted)
            f.count:SetPoint("TOPRIGHT", -12, -2); f.count:SetJustifyH("RIGHT")
            f.bar = UI:Progress(f, 5)
            f.bar:SetPoint("TOPLEFT", 34, -22); f.bar:SetPoint("TOPRIGHT", -12, -22)
            f.info = UI:Text(f, 11, C.muted)
            f.info:SetPoint("TOPLEFT", 34, -40); f.info:SetPoint("TOPRIGHT", -104, -40)
            f.go = UI:Button(f, "Guider", 86, 24, "secondary", "guide")
            f.go:SetPoint("TOPRIGHT", -12, -34)
            return f
        end)
        local tf = CreateFrame("Frame", nil, child)
        tf:SetHeight(44)
        tf.mark = UI:Text(tf, 20, C.gold)
        tf.mark:SetPoint("TOPLEFT", 14, -2)
        tf.mark:SetText("?")
        tf.zone = UI:Text(tf, 12)
        tf.zone:SetPoint("TOPLEFT", 34, -2); tf.zone:SetPoint("TOPRIGHT", -104, -2)
        tf.dist = UI:Text(tf, 11, C.muted)
        tf.dist:SetPoint("TOPLEFT", 34, -20); tf.dist:SetPoint("TOPRIGHT", -104, -20)
        tf.go = UI:Button(tf, "Guider", 86, 24, "secondary", "guide")
        tf.go:SetPoint("TOPRIGHT", -12, -6)
        self.dTurn = tf
        -- distances et point du joueur tenus à jour pendant que l'onglet est affiché
        local acc = 0
        dc:SetScript("OnUpdate", function(_, el)
            acc = acc + (el or 0)
            if acc < 1.5 then return end
            acc = 0
            if self.view == "log" and not self.settingsOpen then self:RefreshLog() end
        end)

        -- petite carte de la zone
        self.jMap = newMini(p, "cercles : camps · ? : rendu · point : toi")
    end,

    -- Disposition de l'onglet journal : large = liste | détail | carte ; étroit = carte sous la liste
    LayoutLog = function(self, top, w, h, hide)
        for _, f in ipairs({ self.jList, self.jDet, self.jMap }) do f:SetShown(not hide); f:ClearAllPoints() end
        if hide then return end
        w = (w and w > 100) and w or 800
        local wide = w >= 1060
        local mapW = wide and MINI_W or LOG_W
        local mc = self.jMap
        mc:SetWidth(mapW)
        local mapH = sizeMini(mc, mapW, (not wide) and math.max(160, (h - top) * 0.36) or nil)
        self.jList:SetWidth(LOG_W)
        self.jList:SetPoint("TOPLEFT", 0, -top)
        if wide then
            self.jList:SetPoint("BOTTOMLEFT", 0, 0)
            mc:SetPoint("TOPRIGHT", 0, -top)
            self.jDet:SetPoint("TOPLEFT", LOG_W + GAP, -top)
            self.jDet:SetPoint("BOTTOMRIGHT", -(mapW + GAP), 0)
        else
            self.jList:SetHeight(math.max(140, h - top - mapH - GAP))
            mc:SetPoint("BOTTOMLEFT", 0, 0)
            self.jDet:SetPoint("TOPLEFT", LOG_W + GAP, -top)
            self.jDet:SetPoint("BOTTOMRIGHT", 0, 0)
        end
    end,

    -- Petite carte : fond de la zone (tuiles du jeu, comme UI:ZoneMap), camps, rendu, joueur
    PaintMini = function(self, map, objs, turn)
        local mc = self.jMap
        local AW, AH = paintMiniBase(mc, map, "Pas de lieu connu pour cette quête.")
        if not AW then return end
        -- camps : cercle plein teinté + anneau en pointillés (vert si l'objectif est fait)
        local ar, ag, ab = UI:Accent()
        local n = 0
        for _, o in ipairs(objs or {}) do
            local col = o.done and C.positive or { ar, ag, ab }
            for _, c in ipairs(o.camps or {}) do
                if c.map == map then
                    n = n + 1
                    local fill, ring = mc.fills[n], mc.rings[n]
                    if not fill then
                        fill = mc.pins:CreateTexture(nil, "ARTWORK"); fill:SetTexture(UI.MEDIA .. "circle"); mc.fills[n] = fill
                        ring = mc.pins:CreateTexture(nil, "OVERLAY"); ring:SetTexture(UI.MEDIA .. "ring_dash"); mc.rings[n] = ring
                    end
                    local size = math.max(12, math.min(90, (c.r or 0.02) * 2 * AW))
                    fill:SetSize(size, size); ring:SetSize(size, size)
                    fill:ClearAllPoints(); fill:SetPoint("CENTER", mc.area, "TOPLEFT", c.x * AW, -c.y * AH)
                    ring:ClearAllPoints(); ring:SetPoint("CENTER", fill, "CENTER")
                    fill:SetVertexColor(col[1], col[2], col[3], 0.25)
                    ring:SetVertexColor(col[1], col[2], col[3], 0.9)
                    fill:Show(); ring:Show()
                end
            end
        end
        if turn and turn.map == map then
            mc.turnBg:ClearAllPoints(); mc.turnBg:SetPoint("CENTER", mc.area, "TOPLEFT", turn.x * AW, -turn.y * AH)
            mc.turnBg:Show(); mc.turn:Show()
        end
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
            self.dEmpty:SetText(T("Ton journal est vide. Prends des quêtes : elles s'afficheront ici avec les camps de leurs objectifs et leur point de rendu."))
            self.miniMap = nil
            self:PaintMini(nil)
            return
        end
        local qid = selQ.id
        local title = selQ.title or qt:Title(qid)
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
        if #objs == 0 then
            local hd = self.dheads:Get()
            hd:ClearAllPoints(); hd:SetPoint("TOPLEFT", 34, -dy)
            hd:SetTextColor(unpack(C.dim))
            hd:SetText(T("Aucun objectif à suivre : va rendre la quête."))
            dy = dy + 24
        end
        for _, o in ipairs(objs) do
            local f = self.dobjs:Get()
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
                        txt = d and string.format(T("1 camp · à %d m"), math.floor(d + 0.5)) or T("1 camp · dans une autre zone")
                    else
                        txt = d and string.format(T("%d camps · le plus proche à %d m"), n, math.floor(d + 0.5))
                            or string.format(T("%d camps · dans une autre zone"), n)
                    end
                    f.info:SetText(txt); f.info:Show()
                    f.go.tooltip = "Guider jusqu'au camp le plus proche de cet objectif"
                    f.go:SetScript("OnClick", function() guideTo(camp.map, camp.x, camp.y, name, title, "Quête suivie", qid) end)
                    f.go:Show()
                else
                    f.info:SetText(T("Pas de camp connu pour cet objectif.")); f.info:Show()
                end
                h = 64
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
        self:PaintMini(map, objs, turn)
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
        self.tHead = UI:Text(tc, 14)
        self.tHead:SetPoint("TOPLEFT", 16, -14); self.tHead:SetPoint("TOPRIGHT", -16, -14)
        self.tSub = UI:Text(tc, 11, C.muted)
        self.tSub:SetPoint("TOPLEFT", self.tHead, "BOTTOMLEFT", 0, -5); self.tSub:SetPoint("TOPRIGHT", self.tHead, "BOTTOMRIGHT", 0, -5)
        self.tscroll = UI:Scroll(tc)
        self.tscroll:SetPoint("TOPLEFT", 4, -58)
        self.tscroll:SetPoint("BOTTOMRIGHT", -4, 54)
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
        self.tMap = newMini(p, "numéros : étapes · point : toi")
        -- point du joueur tenu à jour sur la petite carte
        local acc = 0
        tc:SetScript("OnUpdate", function(_, el)
            acc = acc + (el or 0)
            if acc < 2 then return end
            acc = 0
            if self.view == "tour" and not self.settingsOpen then self:PaintTourMap() end
        end)
    end,

    LayoutTour = function(self, top, w, h, hide)
        for _, f in ipairs({ self.tList, self.tMap }) do f:SetShown(not hide); f:ClearAllPoints() end
        if hide then return end
        w = (w and w > 100) and w or 800
        local mc = self.tMap
        self.tList:SetPoint("TOPLEFT", 0, -top)
        if w >= 1060 then
            mc:SetWidth(MINI_W)
            sizeMini(mc, MINI_W)
            mc:SetPoint("TOPRIGHT", 0, -top)
            self.tList:SetPoint("BOTTOMRIGHT", -(MINI_W + GAP), 0)
        else
            -- étroit : carte sous la liste, sur toute la largeur
            local mapH = sizeMini(mc, w, math.max(120, (h - top) * 0.32))
            mc:SetPoint("BOTTOMLEFT", 0, 0); mc:SetPoint("BOTTOMRIGHT", 0, 0)
            self.tList:SetPoint("BOTTOMRIGHT", 0, mapH + GAP)
        end
    end,

    -- sous-ligne d'une étape
    StepSub = function(self, P, s)
        local txt
        if s.kind == "pick" then txt = T("parler au donneur")
        elseif s.kind == "turn" then txt = T("rendre au PNJ")
        else
            local objs = P:StepObjectives(s)
            local left = {}
            for _, o in ipairs(objs) do if not o.done then table.insert(left, o) end end
            if #left >= 3 then txt = string.format(T("%d objectifs au même camp"), #left)
            elseif #left > 0 then
                local parts = {}
                for _, o in ipairs(left) do
                    table.insert(parts, (o.name or "") .. ((o.need or 0) > 0 and (" " .. (o.have or 0) .. "/" .. o.need) or ""))
                end
                txt = table.concat(parts, " · ")
            elseif #objs > 0 then txt = T("objectifs faits")
            else txt = T("objectifs connus une fois la quête prise") end
        end
        if (s.secs or 0) >= 30 then txt = txt .. "  ·  " .. string.format(T("~%d min"), math.max(1, math.floor(s.secs / 60 + 0.5))) end
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
        self.tHead:SetText(string.format(T("Tournée · %d étapes · ~%d min · %s km"), #steps, math.max(1, math.floor(secs / 60 + 0.5)), km))
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
            local col = (past and C.dim) or (s.kind == "pick" and C.gold) or (s.kind == "turn" and C.positive) or { ar, ag, ab }
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
        self.tEmpty:SetText(T("Aucune étape : coche des quêtes dans « À prendre »."))
        self.tscroll.child:SetSize(W - 14, math.max(y, 30))
        if self.tscroll.UpdateBar then self.tscroll:UpdateBar() end
        -- boutons
        self.tStart:SetShown(not tour); self.tStart:SetEnabled(#steps > 0)
        for _, b in ipairs({ self.tSkip, self.tPause, self.tReorder, self.tStop }) do b:SetShown(tour ~= nil) end
        self.tPause:SetLabel(tour and tour.paused and "Reprendre" or "Pause")
        self.tourSteps, self.tourIdx = steps, idx
        self:PaintTourMap()
    end,

    -- Petite carte de la tournée : étapes numérotées de la zone, reliées, et point du joueur
    PaintTourMap = function(self)
        local mc = self.tMap
        local steps, idx = self.tourSteps or {}, self.tourIdx or 0
        local cur = steps[idx] or steps[1]
        local map = cur and cur.map
        if not map then local me = G() and G():PlayerPos(); map = me and me.map end
        local AW, AH = paintMiniBase(mc, map, "Aucune étape à montrer.")
        if not AW then return end
        local ar, ag, ab = UI:Accent()
        local n, nl, prev = 0, 0, nil
        for i, s in ipairs(steps) do
            if s.map == map and s.x then
                n = n + 1
                local x, y = s.x * AW, s.y * AH
                if prev and mc.pins.CreateLine then
                    nl = nl + 1
                    local ln = mc.lines[nl]
                    if not ln then ln = mc.pins:CreateLine(nil, "ARTWORK"); mc.lines[nl] = ln end
                    if ln then
                        ln:SetThickness(2)
                        ln:SetColorTexture(ar, ag, ab, 0.7)
                        ln:SetStartPoint("TOPLEFT", mc.area, prev[1], -prev[2])
                        ln:SetEndPoint("TOPLEFT", mc.area, x, -y)
                        ln:Show()
                    end
                end
                prev = { x, y }
                local mk, num = mc.marks[n], mc.nums[n]
                if not mk then
                    mk = mc.top:CreateTexture(nil, "ARTWORK"); mk:SetTexture(UI.MEDIA .. "circle"); mk:SetSize(18, 18); mc.marks[n] = mk
                    num = UI:Text(mc.top, 10); mc.nums[n] = num
                    num:SetPoint("CENTER", mk, "CENTER", 0, 0)
                end
                local past = idx > 0 and i < idx
                local col = (past and C.dim) or (s.kind == "pick" and C.gold) or (s.kind == "turn" and C.positive) or { ar, ag, ab }
                mk:ClearAllPoints(); mk:SetPoint("CENTER", mc.area, "TOPLEFT", x, -y)
                mk:SetVertexColor(col[1], col[2], col[3], 1)
                num:SetText(tostring(i)); num:SetTextColor(unpack(past and C.text or C.onAccent))
                mk:Show(); num:Show()
            end
        end
    end,

    Refresh = function(self)
        local cfg = Q:Config()
        -- menu des persos à jour (perso renommé ou supprimé : retour au premier)
        self.charDd:SetOptions(charOptions())
        if self.charDd.selected ~= self.viewKey then
            if WK.DB.global.characters[self.viewKey] then self.charDd:Select(self.viewKey) else self.viewKey = self.charDd.selected end
        end
        for _, t in ipairs(self.toggles) do t:Refresh() end
        if self.campSeg and QT() then self.campSeg:Select(QT():Config().map) end
        if self.maxSeg and QP() then self.maxSeg:Select(QP():Config().maxAbove) end
        if self.view == "log" then self:RefreshLog() return end
        if self.view == "pick" then self:RefreshPick() return end
        if self.view == "tour" then self:RefreshTour() return end
        local key = self.viewKey or WK:CharKey()
        local c = WK.DB.global.characters[key] or {}
        local myLevel = c.level or 1
        local zones = Q:Zones(key)
        local playerZone = key == WK:CharKey() and Q:PlayerZone() or nil
        local best = Q:BestZone(key)
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
