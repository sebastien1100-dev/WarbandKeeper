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
    if st == "closed" then return C.dim, T("plus proposée") end
    return C.tank, T("plus tard")
end
local KIND = { d = "Donjon", c = "Classe" }

local BIG_W, BIG_H = 240, 46   -- grands onglets
local function QT() return WK.modules.QuestTrack end
local VIEWS = { zones = true, journal = true }

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

        -- Deux grands onglets : « Zones de quêtes » et « Journal ». Onglet retenu dans settings.ui.questTab
        -- (zones par défaut ; l'ancien « Ma progression » revient aux zones)
        local ui = WK.DB.global.settings.ui
        self.view = ui.questTab == "journal" and "journal" or "zones"
        self.bigZones = self:BigTab(p, "map", "Zones de quêtes", function() self:ShowTab("zones") end)
        self.bigZones:SetPoint("TOPLEFT", 0, 0)
        -- journal des données (UI/DataLog.lua) : ce qui arrive dans la base (QuestieDB, appris en jeu)
        self.bigJournal = self:BigTab(p, "notes", "Journal", function() self:ShowTab("journal") end, "journal")
        self.bigJournal:SetPoint("TOPLEFT", self.bigZones, "TOPRIGHT", 12, 0)
        self.bigJournal.sub:SetText(T("ce qui arrive dans la base"))
        self.journal = UI:BuildDataJournal(p)
        self.journal:Hide()

        -- Barre de commandes ---------------------------------------------------------
        local of = UI:Text(p, 11, C.muted)
        of:SetPoint("TOPLEFT", self.bigJournal, "TOPRIGHT", 14, -17)
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
        self.lscroll:SetPoint("TOPLEFT", 4, -40)
        self.lscroll:SetPoint("BOTTOMRIGHT", -4, 28)
        -- légende des couleurs d'état, sous la liste
        self.lLegend = UI:Text(list, 10, C.muted)
        self.lLegend:SetPoint("BOTTOMLEFT", 14, 9); self.lLegend:SetPoint("BOTTOMRIGHT", -14, 9)
        self.lLegend:SetJustifyH("LEFT")
        if self.lLegend.SetWordWrap then self.lLegend:SetWordWrap(false) end
        local function paintLegend()
            local parts = {}
            for _, st in ipairs({ "avail", "log", "done", "high", "locked", "closed" }) do
                local col, label = stateInfo(st)
                parts[#parts + 1] = UI:Hex(col) .. "•|r " .. label
            end
            self.lLegend:SetText(table.concat(parts, "   "))
        end
        paintLegend()
        self.qrows = UI:Pool(function()
            local r = CreateFrame("Button", nil, self.lscroll.child)
            r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            r:SetScript("OnClick", function(s, btn) if s.q then UI:QuestClick(btn, s.q.id) end end)
            r:SetHeight(ROW_H)
            r.line = r:CreateTexture(nil, "BACKGROUND")
            r.line:SetPoint("BOTTOMLEFT", 8, 0); r.line:SetPoint("BOTTOMRIGHT", -8, 0); r.line:SetHeight(1)
            r.lv = UI:Text(r, 12)
            r.lv:SetPoint("LEFT", 10, 0)
            r.lv:SetWidth(26)
            r.lv:SetJustifyH("RIGHT")
            r.med = UI:Icon(r, "ring", 22, nil, "ARTWORK")
            r.med:SetPoint("LEFT", 44, 0)
            r.mark = UI:Icon(r, "bang", 12, nil, "OVERLAY")
            r.mark:SetPoint("CENTER", r.med, "CENTER")
            r.name = UI:Text(r, 13)
            r.name:SetPoint("TOPLEFT", 76, -6)
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
                GameTooltip:AddLine(UI:QuestClickHint(), 0.6, 0.6, 0.6, true)
                GameTooltip:Show()
            end)
            r:SetScript("OnLeave", function() GameTooltip:Hide() end)
            return r
        end)
        self.empty = UI:Text(self.lscroll.child, 12, C.muted)


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
        -- cartes rangées par Layout (PlaceSide) : une colonne, ou deux quand la fenêtre est large
        -- (colonne 1 : suivi des quêtes ; colonne 2 : quêtes automatiques)
        self.sideCards = {}
        local function card(title, h, subtitle, col)
            local c = UI:Card(root, title, subtitle)
            c:SetHeight(h)
            table.insert(self.sideCards, { c = c, col = col or 1 })
            y = y + h + GAP
            return c
        end
        local function toggle(parent, field)
            local t = UI:Toggle(parent, function() return qc[field] end,
                function(v) qc[field] = v; WK:NotifyChanged(); self:Refresh() end)
            table.insert(self.toggles, t)
            return t
        end

        -- repères des plaques de nom (UI/QuestTracker.lua) : monstres des quêtes du journal
        if QT() then
            local tcard = card("Plaques de nom", 40 + 36 + 16, "monstres des quêtes du journal")
            local t = UI:Toggle(tcard, function() return QT():Config().plateMarks end,
                function(v)
                    QT():Config().plateMarks = v
                    if UI.UpdateQuestPlateMarks then UI.UpdateQuestPlateMarks() end
                end)
            table.insert(self.toggles, t)
            UI:SettingRow(tcard, -40, "Repère sur les plaques de nom",
                "Pastille au-dessus des monstres des quêtes du journal (plaques de nom affichées).", t, 50)
            local mcard = card("Suivi des quêtes", 40 + 36 + 16, "EllesmereUI ou le suivi du jeu")
            local mt = UI:Toggle(mcard, function() return QT():Config().trackerMenu end,
                function(v)
                    QT():Config().trackerMenu = v
                    if v and UI.ScanQuestTrackers then UI.ScanQuestTrackers() end
                end)
            table.insert(self.toggles, mt)
            UI:SettingRow(mcard, -40, "Alt + clic : menu de la quête",
                "Dans le suivi des quêtes (EllesmereUI ou celui du jeu) : guider, lien wowhead, chercher un groupe, "
                    .. "jamais d'automatique. Les autres clics restent ceux du suivi.", mt, 50)
        end

        local lcard = card("Quêtes montrées", 40 + 4 * 36 + 6, "d'après QuestieDB")
        UI:SettingRow(lcard, -40, "Quêtes de donjon", nil, toggle(lcard, "dungeons"), 50)
        UI:SettingRow(lcard, -76, "Quêtes trop hautes", nil, toggle(lcard, "high"), 50)
        UI:SettingRow(lcard, -112, "Métier : si le perso l'a", nil, toggle(lcard, "profOnly"), 50)
        UI:SettingRow(lcard, -148, "Classe : celles du perso", nil, toggle(lcard, "classOnly"), 50)

        -- journal des données (UI/DataLog.lua) : pastilles, durée, message après une mise à jour
        local jcard = card("Journal des données", 40 + 3 * 48 + 48, "ce qui arrive dans la base")
        self.dataLogSync = UI:BuildDataLogCard(jcard, self.toggles)
        -- liens wowhead (UI/Wowhead.lua) : langue du site
        local wcard = card("Liens wowhead", 40 + 48 + 8, "Maj + clic sur une quête")
        local wseg = UI:Segmented(wcard, { { "fr", "Français" }, { "en", "Anglais" } },
            function(v) WK.DB.global.settings.ui.wowheadLang = v end, 24)
        wseg:Select(UI:WowheadLang())
        UI:SettingRow(wcard, -40, "Langue du site", "Maj + clic sur une quête (listes, fenêtre du donjon, journal) : son lien wowhead (WoW Forever) à copier ; clic droit : petit menu.", wseg, 200)
        -- message « Chercher un groupe » du menu des quêtes (UI/Wowhead.lua)
        local gcard2 = card("Message de groupe", 40 + 30 + 46 + 30, "clic droit sur une quête » Chercher un groupe")
        local inp = UI:Input(gcard2, 300, 28, UI.QUEST_LFG_DEFAULT)
        inp:SetPoint("TOPLEFT", 16, -42); inp:SetPoint("TOPRIGHT", -16, -42)
        local eb = inp.edit
        eb:SetText(UI:QuestLfgTemplate())
        local function saveLfg()
            local v = eb:GetText()
            WK.DB.global.settings.ui.questLfgText = (v ~= "" and v ~= UI.QUEST_LFG_DEFAULT) and v or nil
        end
        inp.onEnter = saveLfg
        eb:HookScript("OnEditFocusLost", saveLfg)
        local hint = UI:Text(gcard2, 10, C.muted)
        hint:SetPoint("TOPLEFT", 16, -78); hint:SetPoint("RIGHT", -150, 0); hint:SetJustifyH("LEFT")
        hint:SetText(T("{quest} lien, {name} nom, {level} niveau, {zone} zone ; choisis le canal puis Entrée."))
        if hint.SetWordWrap then hint:SetWordWrap(true) end
        local reset = UI:Button(gcard2, T("Par défaut"), 120, 24, "ghost")
        reset:SetPoint("TOPRIGHT", -16, -78)
        reset:SetScript("OnClick", function()
            WK.DB.global.settings.ui.questLfgText = nil
            eb:SetText(UI.QUEST_LFG_DEFAULT)
        end)


        -- Quêtes automatiques (Modules/AutoQuest.lua) : trois modes d'un clic, ce qui s'est passé, puis les
        -- détails (prendre, rendre, exceptions) repliés dans leur propre carte
        do
            local AQ = WK.modules.AutoQuest
            if AQ then
                local ac = AQ:Config()
                local mcard = card("Quêtes automatiques", 40 + 74 + 14 + 18 + 5 * 17 + 36, "prendre et rendre en parlant au PNJ", 2)
                local MODES = {
                    { "manual", "Manuel", "Rien d'automatique." },
                    { "assist", "Assisté", "Prend les quêtes de ton niveau, rend les quêtes ; tu choisis la récompense." },
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
                local dcard = card("Quêtes automatiques : détails", 40 + 13 * 36 + 40 + 60 + 50 + 94, "prendre, rendre, acheter, exceptions", 2)
                local function at(field, after)
                    local t = UI:Toggle(dcard, function() return ac[field] end,
                        function(v) ac[field] = v; if after then after(v) end WK:NotifyChanged() end)
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
                self.aboveSeg = UI:Segmented(dcard, { { 0, "0" }, { 1, "1" }, { 2, "2" }, { 3, "3" } },
                    function(v) ac.maxAbove = v; WK:NotifyChanged() end, 24)
                row("Niveaux au-dessus du tien", "Mode assisté : quêtes prises jusqu'à ce niveau au-dessus du tien ; mode automatique : avec « Pas les quêtes trop hautes ».",
                    self.aboveSeg, self.aboveSeg:GetWidth())
                self.aboveSeg:Select(ac.maxAbove or 2)
                row("Pas les quêtes trop hautes", "Mode automatique : au-delà de « Niveaux au-dessus du tien ».", at("noHigh"))
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
                head("Acheter")
                row("Acheter les objets de quête", "Chez un marchand qui vend un objet demandé par une quête du journal : la quantité qui manque, sans clic (sinon un bouton sous sa fenêtre).", at("buy"))
                row("Sans confirmer jusqu'à", "Au-delà, le bouton sous la fenêtre du marchand attend ton clic.",
                    UI:Slider(dcard, 200, 0, 100, 1, function() return math.floor((ac.buyCap or 10000) / 100) end, function(v) ac.buyCap = v * 100 end, "%d pa"), 220)
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
                -- une quête : clic droit sur elle (menu des quêtes) » « Jamais d'automatique »
                dcard.bn = UI:Button(dcard, "Exclure le PNJ ciblé", nil, 24, "secondary")
                dcard.bn:SetPoint("TOPLEFT", 14, dy - 40)
                dcard.bn:SetScript("OnClick", function()
                    local id, name = AQ:TargetNpc()
                    if id then AQ:BlockNpc(id, name, true) else WK:Print(T("Cible un PNJ d'abord.")) end
                    paintList()
                end)
                dcard.clear = UI:Button(dcard, "Tout réautoriser", nil, 24, "ghost")
                dcard.clear:SetPoint("LEFT", dcard.bn, "RIGHT", 8, 0)
                dcard.clear:SetScript("OnClick", function() wipe(ac.quests); wipe(ac.npcs); paintList(); WK:NotifyChanged() end)
                -- repli des détails (fermés au départ)
                dcard.wkFoldable = true
                dcard.keepHidden = function() return not self.autoOpen end
                local function fold(open)
                    dcard:SetShown(open)
                    mcard.more:SetLabel(open and T("Masquer les détails") or T("Détails"))
                    mcard.more:SetWidth(mcard.more.label:GetStringWidth() + 28)
                    if self.Layout then self:Layout() end
                end
                mcard.more:SetScript("OnClick", function() self.autoOpen = not self.autoOpen; fold(self.autoOpen) end)
                self.autoFold = fold
                C_Timer.After(0, function() fold(self.autoOpen and true or false) end)
            end
        end
    end,

    -- recherche de la barre latérale : un réglage des quêtes ouvre la roue
    RevealSetting = function(self, row)
        local f = row
        while f do
            if self.qct and f:GetParent() == self.side.child then self.qct:Reveal(f) end
            if f == self.side then self.settingsOpen = true; self:Layout(); self:Refresh() return end
            f = f:GetParent()
        end
    end,

    -- cartes des réglages, en sous-onglets de catégories (UI:CardTabs) : deux colonnes (largeur ≥ 1000,
    -- chaque carte sous la plus courte) ou une seule ; cartes repliées sautées
    PlaceSide = function(self, w)
        local all = {}
        for _, e in ipairs(self.sideCards or {}) do table.insert(all, e.c) end
        if not self.qct then
            self.qct = UI:CardTabs(self.side.child, "quests", {
                { "list", T("Quêtes montrées"),
                  titles = { "Quêtes montrées", "Plaques de nom", "Suivi des quêtes", "Journal des données", "Liens wowhead", "Message de groupe" } },
                { "auto", T("Quêtes automatiques"),
                  titles = { "Quêtes automatiques", "Quêtes automatiques : détails" } },
            }, function() self:Layout() end)
        end
        local cards = self.qct:Filter(all)
        local top = 0
        if self.qct.bar then
            self.qct.bar:ClearAllPoints(); self.qct.bar:SetPoint("TOPLEFT", 0, 0); top = self.qct:Height()
        end
        local two = w >= 1000
        local colW = two and math.min(560, math.floor((w - 10 - GAP) / 2)) or math.min(w - 10, 560)
        local ys = { top, top }
        for _, c in ipairs(cards) do
            if c:IsShown() then
                local col = (two and ys[2] < ys[1]) and 2 or 1
                c:ClearAllPoints()
                c:SetPoint("TOPLEFT", (col - 1) * (colW + GAP), -ys[col])
                c:SetWidth(colW)
                ys[col] = ys[col] + c:GetHeight() + GAP
            end
        end
        local total = math.max(ys[1], ys[2])
        self.side.child:SetSize(two and (2 * colW + GAP) or colW, math.max(total, 10))
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
        else self.ofLabel:SetPoint("TOPLEFT", self.bigJournal, "TOPRIGHT", 14, -17) end
        local open = self.settingsOpen == true
        local top
        -- réglages ouverts : pas de barre « Quêtes de » (elle ne sert pas aux réglages)
        if open then top = BIG_H + GAP
        elseif zonesView then top = BIG_H + GAP + (second and (30 + GAP) or 0)
        else top = BIG_H + GAP end
        self.bigZones:Paint(); self.bigJournal:Paint()
        -- journal des données : toute la place sous les grands onglets
        local journalView = not open and self.view == "journal"
        self.journal:SetShown(journalView)
        if journalView then
            self.journal:ClearAllPoints()
            self.journal:SetPoint("TOPLEFT", 0, -top); self.journal:SetPoint("BOTTOMRIGHT")
            self.journal:Layout(w, h - top)
        end
        self.side:ClearAllPoints()
        self.gear:SetActive(open)
        self.side:SetShown(open)
        -- réglages : sur toute la largeur, sous la barre
        self.side:SetPoint("TOPLEFT", 0, -top)
        self.side:SetPoint("BOTTOMRIGHT")
        self:PlaceSide(w)
        if self.side.UpdateBar then self.side:UpdateBar() end
        -- onglet affiché : zones (barre « Quêtes de », filtre) ou journal
        self.ofLabel:SetShown(zonesView and not open); self.charDd:SetShown(zonesView and not open); self.filterSeg:SetShown(zonesView and not open)
        UI:ZoneLayout(self, p, top, w, h, open or not zonesView)
    end,

    -- Grand onglet : icône dans un carré arrondi, titre et sous-titre ; plein à la couleur d'accent quand il
    -- est actif, sinon fond C.surface et liseré C.border
    BigTab = function(self, p, icon, title, onClick, key)
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
        b.key = key or "zones"
        function b.Paint(s2)
            local r, g, bl = UI:Accent()
            local v = self.view
            local on = s2.key == v
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

    -- sous-titre de « Zones de quêtes » : zones et quêtes disponibles du perso choisi
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
        self.settingsOpen = false
        self:Layout()
        self:Refresh()
        if UI.RefreshChips then UI:RefreshChips() end
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
        if not self.zoneSum then self:ZoneSummary() end
        if self.view == "journal" then self.journal:Refresh() return end
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
            local zn = z.near or 0 -- compté avec la liste des zones (Quests:Zones)
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
                local st, need, why = Q:State(q, c)
                local keep = (cfg.filter == "all" or (cfg.filter == "done" and st == "done")
                    or (cfg.filter == "todo" and st ~= "done" and st ~= "closed"))
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
                    row.name:SetText(UI.GroupTag(q.id) .. Q:Name(q)
                        .. (WK.modules.DataLog and WK.modules.DataLog:Badge(q.id) or ""))
                    row.name:SetTextColor(unpack(st == "done" and C.dim or C.text))
                    local parts = {}
                    if q.skill then table.insert(parts, UI:Hex(C.positive) .. T(q.skill) .. "|r")
                    elseif KIND[q.kind] then table.insert(parts, T(KIND[q.kind])) end
                    if st == "locked" and why == "notoffered" then
                        table.insert(parts, T("pas encore proposée par le PNJ"))
                    end
                    if st == "locked" and need and Q:Get(need) then table.insert(parts, string.format(T("après « %s »"), Q:Name(Q:Get(need))))
                    elseif st == "high" then table.insert(parts, string.format(T("niveau %d requis"), q.req)) end
                    if (q.xp or 0) > 0 then table.insert(parts, q.xp .. " XP") end
                    row.sub:SetText(table.concat(parts, "  ·  "))
                    row.state:Set(label, col)
                    row.guide:SetShown(q.x ~= nil and st ~= "done")
                    if q.grp == 1 then table.insert(parts, 1, UI:Hex(C.warning) .. T("groupe") .. "|r"); row.sub:SetText(table.concat(parts, "  ·  ")) end
                    row.guide:SetScript("OnClick", function() Q:GuideTo(q) end)
                    ly = ly + ROW_H
                end
            end
        end
        -- quêtes du journal rangées par le jeu sous cette zone mais absentes de la base (propres à WoW Forever)
        if key == WK:CharKey() and self.zone and QT() then
            local zn = (WK.modules.Rares:ZoneName(self.zone) or ""):lower()
            local known = {}
            for _, q in ipairs(all) do known[q.id] = true end
            for _, l in ipairs(QT():LogQuests()) do
                if not known[l.id] and l.zone and l.zone:lower() == zn then
                    total = total + 1; shown = shown + 1
                    local row = self.qrows:Get()
                    row.q = nil
                    row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -ly); row:SetWidth(LW - 14)
                    row.line:SetColorTexture(C.border[1], C.border[2], C.border[3], 0.6)
                    row.lv:SetText(l.level and tostring(l.level) or "-")
                    row.lv:SetTextColor(unpack(l.level and levelColor(l.level, myLevel) or C.muted))
                    local col, label = stateInfo("log")
                    row.med:SetVertexColor(unpack(col)); row.mark:SetVertexColor(unpack(col))
                    row.name:SetText(l.title or ("#" .. l.id))
                    row.name:SetTextColor(unpack(C.text))
                    row.sub:SetText(l.complete and T("à rendre") or T("absente de la base · position donnée par le jeu"))
                    row.state:Set(label, col)
                    row.guide:SetShown(true)
                    row.guide:SetScript("OnClick", function() QT():GuideQuest(l.id) end)
                    ly = ly + ROW_H
                end
            end
            self.lscroll.child:SetSize(LW - 14, math.max(ly, 30))
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
