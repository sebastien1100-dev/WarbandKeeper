local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

local TOP_H = 250
local TODO_W = 420

-- Liste « À faire » : actions utiles maintenant, les plus urgentes d'abord.
-- { prio (petit = urgent), icon, text, color?, go = function(), gicon, short, group, n }
-- gicon : icône du jeu (fenêtre de rappels à la connexion), short : libellé court de sa pastille,
-- group + n : les éléments du même groupe ne font qu'une pastille (n additionnés)
local GI = "Interface\\Icons\\"
local function todoItems()
    local items = {}
    local function add(prio, icon, text, go, color, x)
        x = x or {}
        table.insert(items, { prio = prio, icon = icon, text = text, go = go, color = color,
            gicon = x.g and (GI .. x.g) or nil, short = x.short, group = x.group, n = x.n })
    end
    local now = time()
    local mailDays = WK.DB.global.settings.alerts.mailDays or 3
    local me = select(2, WK.DB:Me())
    for _, e in ipairs(UI:SortedCharacters()) do
        local c, name = e.c, WK:CharName(e.c, e.key)
        -- Courrier en attente
        local box = c.mailbox
        if box and (box.count or 0) > 0 then
            local d = box.expiresAt and math.max(0, math.floor((box.expiresAt - now) / 86400))
            local soon = d and d <= mailDays
            local txt = string.format(box.count > 1 and WK.T("%d lettres à récupérer sur %s") or WK.T("%d lettre à récupérer sur %s"), box.count, name)
            if d then txt = txt .. "  ·  " .. string.format(WK.T("expire dans %d j"), d) end
            add(soon and 1 or 6, "mail", txt, function() UI:ShowPage("mail"); UI.pages.mail:SetTab("receive") end, soon and C.negative or nil,
                { g = "INV_Letter_15", group = "letters", n = box.count })
        end
        -- Métier bloqué au plafond de son rang (75, 150, 225…)
        for prof, pr in pairs(c.professions or {}) do
            if (pr.max or 0) > 0 and pr.max < 300 and (pr.rank or 0) >= pr.max
                and not WK.modules.Gathering:Kind(prof) and prof ~= "Pêche" and prof ~= "Fishing" then
                add(3, "hammer", string.format(WK.T("%s : %s au plafond %d, va voir le maître"), name, prof, pr.max),
                    function() UI:ShowPage("professions"); UI.pages.professions:ShowDetail(e.key, prof) end, C.warning,
                    { g = "INV_Misc_Book_09", short = WK.T("plafond") })
            end
        end
        -- Fabrications à recharge de nouveau prêtes (transmutation, étoffe lunaire…)
        for _, cd in ipairs(WK.modules.Recipes:Cooldowns(c)) do
            if cd.ready then
                add(4, "clock", string.format(WK.T("%s : %s de nouveau disponible"), name, cd.key),
                    function() UI:ShowPage("professions"); UI.pages.professions:ShowDetail(e.key, cd.prof) end, C.positive,
                    { g = "INV_Misc_PocketWatch_01", group = "cd", n = 1 })
            end
        end
        -- Banque pas vue (alertes)
        for _, a in ipairs(WK.modules.Alerts:For(c, e.key)) do
            if a.kind == "bank" then
                add(5, "home", name .. " : " .. a.text, function() UI:ShowPage("characters") end, nil,
                    { g = "INV_Box_02", short = WK.T("banque") })
            end
        end
    end
    -- Qualité de vie : durabilité, sacs presque pleins, composants et munitions, familier
    local ICON = { durability = "hammer", bags = "bag", reagent = "spark", ammo = "spark", pet = "spark" }
    local GAME = { durability = { "Trade_BlackSmithing", "réparer" }, bags = { "INV_Misc_Bag_08", "pleins" },
        reagent = { "INV_Misc_Dust_02", "composants" }, ammo = { "INV_Ammo_Arrow_02", "munitions" },
        pet = { "Ability_Hunter_BeastTraining", "familier" }, poison = { "Ability_Poisons", "poisons" } }
    for _, a in ipairs(WK.modules.QoL:Alerts()) do
        local section = a.class or "general"
        local gm = GAME[a.kind] or { "INV_Misc_QuestionMark", nil }
        if a.kind == "bags" and a.bank then gm = { "INV_Box_02", "pleine" } end
        add(a.urgent and 2 or 5, (a.kind == "bags" and a.bank) and "home" or ICON[a.kind] or "spark", a.text, function()
            UI:ShowPage("qol"); UI.pages.qol:ShowSection(section)
        end, a.urgent and C.negative or C.warning, { g = gm[1], short = gm[2] and WK.T(gm[2]) })
    end
    -- Butin automatique du jeu actif : le filtre de loot ne peut pas choisir
    local L = WK.modules.Loot
    if WK.DB.global.loot.enabled and L:GameAutoLoot() then
        add(2, "filter", WK.T("Butin automatique du jeu activé : le filtre de loot ne peut pas choisir"),
            function() UI:ShowPage("loot") end, C.negative, { g = "INV_Misc_Bag_11", short = WK.T("butin auto") })
    end
    -- Objets à envoyer / à déposer depuis les sacs du perso connecté
    if WK.DB.global.mail.enabled then
        local n = WK.modules.Mail:PendingCount()
        if n > 0 then
            add(4, "mail", string.format(WK.T("%d objets à envoyer à la prochaine boîte aux lettres"), n),
                function() UI:ShowPage("mail"); UI.pages.mail:SetTab("send") end, nil, { g = "INV_Crate_02", group = "send", n = n })
        end
    end
    if WK.DB.global.bank.enabled then
        local n = 0
        for _, e in ipairs(WK.modules.BankDeposit:Plan()) do for _, op in ipairs(e.ops) do n = n + op.count end end
        if n > 0 then
            add(4, "bag", string.format(WK.T("%d objets à déposer à la prochaine banque"), n),
                function() UI:ShowPage("mail"); UI.pages.mail:SetTab("bank") end, nil, { g = "INV_Misc_Bag_10", group = "deposit", n = n })
        end
    end
    -- Session de farm en pause
    local F = WK.modules.Farm
    if F:Active() and F:Current().paused then
        add(4, "pause", WK.T("Session de farm en pause"), function() UI:ShowPage("farm") end, C.warning, { g = "Spell_Nature_TimeStop", short = WK.T("pause") })
    end
    -- Liste de courses : composants manquants
    if next(WK.DB.global.shopping) then
        local missing = 0
        for _, m in ipairs((WK.modules.Recipes:Needs())) do if m.missing > 0 then missing = missing + 1 end end
        if missing > 0 then
            add(7, "search", string.format(WK.T("Liste de courses : %d composant(s) manquant(s)"), missing),
                function() UI:ShowPage("professions"); UI.pages.professions:SetTab("shopping") end, nil, { g = "INV_Scroll_03", group = "shop", n = missing })
        end
    end
    table.sort(items, function(a, b) if a.prio ~= b.prio then return a.prio < b.prio end return a.text < b.text end)
    return items
end
UI.TodoItems = todoItems -- aussi pour la fenêtre de rappels à la connexion (UI/LoginPopup.lua)
local GAP = 16
local GOAL_H = 54
local RANGES = { { 7, "7 j" }, { 30, "30 j" }, { 90, "90 j" }, { 365, "1 an" } }

-- Colonnes du tableau : x de départ (ou de fin pour "RIGHT").
-- Positions prévues pour 924 px de large, mises à l'échelle à la construction.
local BASE_COLS = {
    { "Personnage", 16, "LEFT" },
    { "Niv.", 300, "LEFT" },
    { "Or", 470, "RIGHT" },
    { "7 jours", 580, "RIGHT" },
    { "Tendance", 612, "LEFT" },
    { "Sacs", 730, "LEFT" },
    { "Vu", 812, "LEFT" },
}
local COLS = {}

local function points(days)
    if days <= 7 then return 28 end -- un point toutes les 6 h
    if days <= 30 then return 30 end
    if days <= 90 then return 45 end
    return 52
end

-- "12 345 po" en couleur -> "12 345" sans codes couleur.
local function plainGold(copper)
    local s = UI:GoldText(copper):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub(" " .. WK.T("po") .. "$", "")
    return s
end

UI:RegisterPage({
    key = "overview", order = 1, nav = "Résumé",
    title = "Résumé",
    subtitle = "Vue d'ensemble du compte : or, évolution et personnages.",

    Build = function(self, p)
        self.days = 7
        local k = UI.PAGE_W / 924
        for i, c in ipairs(BASE_COLS) do COLS[i] = { c[1], math.floor(c[2] * k), c[3] } end

        -- À faire (moitié gauche) : groupes Urgent / Bientôt / À noter ---------------------
        local todo = UI:Card(p, "À faire")
        todo:SetPoint("TOPLEFT")
        todo:SetSize(TODO_W, TOP_H)
        self.todo = todo
        -- compteur en pastille d'accent à côté du titre
        self.todoBadge = CreateFrame("Frame", nil, todo)
        self.todoBadge:SetSize(24, 18)
        self.todoBadge.bg = UI:Rounded(self.todoBadge, 9, 0, "BACKGROUND", 2)
        self.todoBadge.text = UI:Text(self.todoBadge, 11)
        self.todoBadge.text:SetPoint("CENTER")
        if todo.title then self.todoBadge:SetPoint("LEFT", todo.title, "RIGHT", 8, 0) else self.todoBadge:SetPoint("TOPLEFT", 80, -14) end
        local tscroll = UI:Scroll(todo)
        tscroll:SetPoint("TOPLEFT", 8, -42)
        tscroll:SetPoint("BOTTOMRIGHT", -6, 8)
        self.todoScroll = tscroll
        self.todoEmpty = UI:Text(todo, 13, C.muted)
        self.todoEmpty:SetPoint("CENTER", 0, -10)
        self.todoEmpty:SetText("Rien à faire : tout est à jour.")
        self.todoHeads = UI:Pool(function()
            local t = UI:Text(tscroll.child, 10)
            return t
        end)
        self.todoRows = UI:Pool(function()
            local r = CreateFrame("Button", nil, tscroll.child)
            r:SetHeight(46)
            r.hl = CreateFrame("Frame", nil, r)
            r.hl:SetAllPoints()
            r.hl:SetFrameLevel(math.max(0, r:GetFrameLevel() - 1))
            UI:Rounded(r.hl, 9, 0, "BACKGROUND", 1):SetColor(unpack(C.hover))
            r.hl:Hide()
            r.box = CreateFrame("Frame", nil, r)
            r.box:SetSize(30, 30)
            r.box:SetPoint("LEFT", 8, 0)
            r.box.edge = UI:Rounded(r.box, 8, 0, "BACKGROUND", 2)
            r.box.bg = UI:Rounded(r.box, 7, 1, "BACKGROUND", 3)
            r.icon = UI:Icon(r.box, "mail", 15, nil, "ARTWORK")
            r.icon:SetPoint("CENTER")
            r.text = UI:Text(r, 13)
            r.text:SetPoint("TOPLEFT", 48, -7)
            r.text:SetPoint("RIGHT", -80, 0)
            r.text:SetJustifyH("LEFT")
            if r.text.SetWordWrap then r.text:SetWordWrap(true) end
            if r.text.SetMaxLines then r.text:SetMaxLines(2) end
            r.sub = UI:Text(r, 11, C.muted)
            r.sub:SetPoint("TOPLEFT", r.text, "BOTTOMLEFT", 0, -3)
            r.sub:SetPoint("RIGHT", -80, 0)
            r.sub:SetJustifyH("LEFT")
            r.go2 = UI:Button(r, "Ouvrir", 66, 24, "secondary")
            r.go2:SetPoint("RIGHT", -8, 0)
            r.go2:Hide()
            r.go2:SetScript("OnClick", function() if r.go then r.go() end end)
            r.go2:HookScript("OnLeave", function() if not r:IsMouseOver() then r.hl:Hide(); r.go2:Hide() end end)
            r:SetScript("OnEnter", function(s) s.hl:Show(); s.go2:Show() end)
            r:SetScript("OnLeave", function(s) if not s.go2:IsMouseOver() then s.hl:Hide(); s.go2:Hide() end end)
            r:SetScript("OnClick", function(s) if s.go then s.go() end end)
            return r
        end)

        -- Courbe d'évolution -----------------------------------------------------------
        local card = UI:Card(p, nil, nil, true)
        self.chartCard = card
        card:SetPoint("TOPLEFT", todo, "TOPRIGHT", GAP, 0)
        card:SetPoint("TOPRIGHT", 0, 0)
        card:SetHeight(TOP_H)
        local ct = UI:Text(card, 12, C.muted)
        ct:SetPoint("TOPLEFT", 16, -16)
        ct:SetText("Évolution de l'or")
        local seg = UI:Segmented(card, RANGES, function(d) self.days = d; self:Refresh() end, 28)
        seg:SetPoint("TOPRIGHT", -12, -10)
        seg:Select(7)

        local areaH = TOP_H - 52 - 30
        local area = CreateFrame("Frame", nil, card)
        area:SetPoint("TOPLEFT", 16, -52)
        area:SetPoint("BOTTOMRIGHT", -16, 30)
        self.area = area
        for i = 1, 3 do
            local g = area:CreateTexture(nil, "BACKGROUND", nil, 2)
            g:SetColorTexture(unpack(C.border))
            g:SetHeight(1)
            g:SetPoint("LEFT", area, "BOTTOMLEFT", 0, areaH * (i - 1) / 2)
            g:SetPoint("RIGHT", area, "BOTTOMRIGHT", 0, areaH * (i - 1) / 2)
        end
        self.chart = UI:LineChart(area, 2.5, true)
        self.chart:SetAllPoints()
        self.xLabels = {}
        local anchors = {
            { "TOPLEFT", "BOTTOMLEFT" }, { "TOP", "BOTTOM" }, { "TOPRIGHT", "BOTTOMRIGHT" },
        }
        for i, a in ipairs(anchors) do
            local l = UI:Text(card, 10, C.dim)
            l:SetPoint(a[1], area, a[2], 0, -8)
            self.xLabels[i] = l
        end
        self.empty = UI:Text(card, 12, C.muted)
        self.empty:SetPoint("CENTER", area)
        self.empty:SetText("L'historique se remplit au fil de tes sessions.")

        UI:ChartHover(area, self.chart, function(pt) return WK:FormatMoney(pt.v) end)

        -- Objectifs (bandeau affiché seulement s'il y en a) ---------------------------
        self.goalTop = -(TOP_H + GAP)
        self.goalCards = UI:Pool(function()
            local g = CreateFrame("Button", nil, p)
            g:SetHeight(GOAL_H)
            UI:Panel(g, 12, C.surface, C.border)
            g.label = UI:Text(g, 11, C.muted)
            g.label:SetPoint("TOPLEFT", 12, -9)
            g.label:SetPoint("TOPRIGHT", -60, -9)
            g.pct = UI:Text(g, 12)
            g.pct:SetPoint("TOPRIGHT", -12, -9)
            g.pct:SetJustifyH("RIGHT")
            g.bar = UI:Progress(g, 6)
            g.bar:SetPoint("BOTTOMLEFT", 12, 12)
            g.bar:SetPoint("BOTTOMRIGHT", -12, 12)
            g.eta = UI:Text(g, 10, C.dim)
            g.eta:SetPoint("BOTTOMRIGHT", g.bar, "TOPRIGHT", 0, 4)
            g.eta:SetJustifyH("RIGHT")
            g:SetScript("OnClick", function(b)
                UI:ShowPage("stats")
                UI.pages.stats.series = b.key
                UI:Refresh()
            end)
            return g
        end)

        -- Tableau des personnages ---------------------------------------------------
        local tableBox = CreateFrame("Frame", nil, p)
        self.tableBox = tableBox
        tableBox:SetPoint("TOPLEFT", 0, -(TOP_H + GAP + 4))
        tableBox:SetPoint("BOTTOMRIGHT", 0, 56 + GAP)
        self.colHeaders = {}
        for i, col in ipairs(BASE_COLS) do
            local t = UI:Text(tableBox, 10, C.dim)
            if col[3] == "RIGHT" then t:SetJustifyH("RIGHT") end
            t:SetText(UI:Upper(WK.T(col[1])))
            self.colHeaders[i] = t
        end
        local scroll = UI:Scroll(tableBox)
        scroll:SetPoint("TOPLEFT", 0, -20)
        scroll:SetPoint("BOTTOMRIGHT")
        self.scroll = scroll

        self.rows = UI:Pool(function()
            local r = CreateFrame("Frame", nil, scroll.child)
            r:SetHeight(42)
            r.border = UI:Rounded(r, 12, 0, "BACKGROUND", 0)
            r.border:SetColor(unpack(C.border))
            r.bg = UI:Rounded(r, 11, 1, "BACKGROUND", 1)
            r.icon = UI:RoundIcon(r, 24)
            r.name = UI:Text(r, 13)
            r.name:SetPoint("LEFT", r.icon, "RIGHT", 10, 0)
            r.here = UI:Badge(r, "ici")
            r.here:SetPoint("LEFT", r.name, "RIGHT", 8, 0)
            -- Enveloppe : courrier en attente (rouge quand il expire bientôt).
            r.mail = CreateFrame("Frame", nil, r)
            r.mail:SetSize(18, 18)
            r.mail:EnableMouse(true)
            r.mail.icon = UI:Icon(r.mail, "mail", 14)
            r.mail.icon:SetPoint("CENTER")
            r.mail:SetScript("OnEnter", function(s)
                WK.UI:TooltipOwner(s, "ANCHOR_TOP")
                GameTooltip:SetText(s.tip or "", 1, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            r.mail:SetScript("OnLeave", function() GameTooltip:Hide() end)
            r.level = UI:Text(r, 12)
            r.gold = UI:Text(r, 12)
            r.gold:SetJustifyH("RIGHT")
            r.diff = UI:Text(r, 12)
            r.diff:SetJustifyH("RIGHT")
            r.spark = UI:LineChart(r, 1.5, false)
            r.spark:SetSize(84, 18)
            r.bags = UI:Text(r, 12, C.muted)
            r.seen = UI:Text(r, 12, C.muted)
            self:PlaceRow(r)
            return r
        end)

        self:BuildModules(p)

        -- Élastique : colonnes recalculées et graphique redessiné quand la taille change.
        UI:OnResize(p, function(w)
            -- « À faire » et la courbe se partagent la largeur à moitié
            if self.todo and w and w > 100 then self.todo:SetWidth(math.floor((w - GAP) / 2)) end
            self:PlaceColumns(w)
            self:LayoutModules(w)
            if self.chart then UI:RefreshSoon() end
        end)
    end,

    -- Carte « Modules » (Core/Features.lua) en bas du Résumé : repliée, une ligne d'icônes ;
    -- dépliée, une ligne par groupe avec une tuile par module (icône, nom, chiffre, interrupteur).
    BuildModules = function(self, p)
        local ui = WK.DB.global.settings.ui
        local card = CreateFrame("Frame", nil, p)
        UI:Panel(card, 12, C.surface, C.border)
        self.modCard = card
        local title = UI:Text(card, 13)
        title:SetPoint("TOPLEFT", 16, -20)
        title:SetText(T("Modules"))
        self.modCount = UI:Text(card, 11, C.muted)
        self.modCount:SetPoint("LEFT", title, "RIGHT", 8, -1)
        self.modToggle = UI:Button(card, "Gérer", 90, 24, "ghost")
        self.modToggle:SetPoint("TOPRIGHT", -12, -16)
        self.modToggle:SetScript("OnClick", function()
            ui.modulesOpen = not ui.modulesOpen
            self:LayoutModules(); self:Refresh()
        end)
        self.modReload = UI:Button(card, "Recharger", 110, 24, "primary", "power")
        self.modReload:SetPoint("RIGHT", self.modToggle, "LEFT", -8, 0)
        self.modReload:SetScript("OnClick", function()
            if not (InCombatLockdown and InCombatLockdown()) then ReloadUI() end
        end)
        self.modReload:Hide()
        self.modReloadHint = UI:Text(card, 10, C.muted)
        self.modReloadHint:SetPoint("RIGHT", self.modReload, "LEFT", -8, 0)
        self.modReloadHint:SetText(T("un /reload termine le changement"))
        self.modReloadHint:Hide()
        -- ligne d'icônes (repliée)
        self.modDots = {}
        for i, f in ipairs(WK.FEATURES) do
            local d = UI:Icon(card, f.icon, 22, nil, "ARTWORK")
            self.modDots[i] = d
        end
        -- tuiles (dépliée)
        self.modLabels, self.modTiles = {}, {}
        local groups = {}
        for _, f in ipairs(WK.FEATURES) do
            if not groups[f.group] then
                groups[f.group] = true
                local l = UI:Text(card, 10, C.dim)
                l:SetText(T(f.group))
                table.insert(self.modLabels, { label = l, group = f.group })
            end
            local t = CreateFrame("Button", nil, card)
            t:SetHeight(40)
            t.edge = UI:Rounded(t, 10, 0, "BACKGROUND", 0)
            t.bg = UI:Rounded(t, 9, 1, "BACKGROUND", 1)
            t.icon = UI:Icon(t, f.icon, 16, nil, "ARTWORK")
            t.icon:SetPoint("LEFT", 12, 0)
            t.name = UI:Text(t, 12)
            t.name:SetPoint("TOPLEFT", 38, -6)
            t.name:SetPoint("RIGHT", -50, 0)
            t.name:SetJustifyH("LEFT")
            t.name:SetText(T(f.label))
            t.sub = UI:Text(t, 10, C.muted)
            t.sub:SetPoint("TOPLEFT", t.name, "BOTTOMLEFT", 0, -2)
            t.sub:SetPoint("RIGHT", -50, 0)
            t.sub:SetJustifyH("LEFT")
            t.toggle = UI:Toggle(t, function() return WK:FeatureOn(f.key) end, function(v)
                WK:SetFeature(f.key, v)
                if f.reload then self.needReload = true end
                self:Refresh()
            end)
            t.toggle:SetPoint("RIGHT", -10, 0)
            t.f = f
            -- un clic sur la tuile ouvre la page du module (ou sa section de QoL)
            t:SetScript("OnClick", function()
                if not WK:FeatureOn(f.key) then return end
                if f.page then UI:ShowPage(f.page)
                elseif f.qol then UI:ShowPage("qol"); if UI.pages.qol.ShowSection then UI.pages.qol:ShowSection(f.qol) end end
            end)
            t:SetScript("OnEnter", function(s)
                WK.UI:TooltipOwner(s, "ANCHOR_TOP")
                GameTooltip:SetText(T(f.label), 1, 1, 1)
                if f.desc then GameTooltip:AddLine(T(f.desc), 0.7, 0.7, 0.7, true) end
                GameTooltip:AddLine(T("Couper un module masque sa page, ses infobulles et ce qu'il affiche, et arrête ses actions ; ses données sont gardées."), 0.5, 0.5, 0.5, true)
                GameTooltip:Show()
            end)
            t:SetScript("OnLeave", function() GameTooltip:Hide() end)
            table.insert(self.modTiles, t)
        end
        self:LayoutModules()
    end,

    LayoutModules = function(self, w)
        if not self.modCard then return end
        local open = WK.DB.global.settings.ui.modulesOpen
        local W = w or (self.modCard:GetParent():GetWidth()) or UI.PAGE_W or 900
        if not W or W < 100 then W = UI.PAGE_W or 900 end
        local LABEL_W, TG, ROW = 88, 8, 46
        self.modToggle:SetLabel(open and T("Replier") or T("Gérer"))
        for _, d in ipairs(self.modDots) do d:SetShown(not open) end
        for _, l in ipairs(self.modLabels) do l.label:SetShown(open) end
        for _, t in ipairs(self.modTiles) do t:SetShown(open) end
        if not open then
            local x = 16
            for i, d in ipairs(self.modDots) do
                d:ClearAllPoints(); d:SetPoint("LEFT", self.modCard, "TOPLEFT", 190 + (i - 1) * 34, -28)
            end
            self.modH = 56
        else
            -- colonnes d'au moins 220 px (noms lisibles), entre 2 et 4
            local NC = math.max(2, math.min(4, math.floor((W - 32 - LABEL_W + TG) / (220 + TG))))
            local tw = math.floor((W - 32 - LABEL_W - (NC - 1) * TG) / NC)
            local y, col, lastGroup = -50, 0, nil
            for _, t in ipairs(self.modTiles) do
                if t.f.group ~= lastGroup then
                    if lastGroup then y = y - ROW end
                    lastGroup, col = t.f.group, 0
                    for _, l in ipairs(self.modLabels) do
                        if l.group == t.f.group then l.label:ClearAllPoints(); l.label:SetPoint("TOPLEFT", self.modCard, "TOPLEFT", 16, y - 15) end
                    end
                end
                if col >= NC then col = 0; y = y - ROW end -- groupe de plus de 4 modules : ligne suivante
                t:SetWidth(tw)
                t:ClearAllPoints(); t:SetPoint("TOPLEFT", self.modCard, "TOPLEFT", 16 + LABEL_W + col * (tw + TG), y)
                col = col + 1
            end
            self.modH = -y + ROW + 4
        end
        -- repliée : une ligne sous le tableau ; dépliée : elle prend la place du tableau et des objectifs
        self.modCard:ClearAllPoints()
        if open then
            -- dépliée : toute la page (les cartes du haut se cachent le temps de gérer les modules)
            self.modCard:SetPoint("TOPLEFT", 0, 0)
            self.modCard:SetPoint("BOTTOMRIGHT")
        else
            self.modCard:SetPoint("BOTTOMLEFT"); self.modCard:SetPoint("BOTTOMRIGHT")
            self.modCard:SetHeight(self.modH)
        end
        if self.tableBox then self.tableBox:SetShown(not open) end
        if self.todo then self.todo:SetShown(not open) end
        if self.chartCard then self.chartCard:SetShown(not open) end
        for _, g in ipairs(self.goalCards and self.goalCards.items or {}) do if open then g:Hide() end end
    end,

    -- Chiffre du moment d'un module
    ModuleStat = function(self, f)
        if not WK:FeatureOn(f.key) then return T("coupé") end
        local ok, v = pcall(function()
            local k = f.key
            if k == "ah" then local n = WK.modules.AHScan:Count(); return n > 0 and string.format(T("%d prix"), n) or T("aucun scan") end
            if k == "quests" then local _, _, a = WK.modules.Quests:Totals(); return string.format(T("%d disponibles"), a) end
            if k == "rares" then local a, b = WK.modules.Rares:Totals(); return a .. " / " .. b end
            if k == "mail" then
                local n = 0
                for _, c in pairs(WK.DB.global.characters) do n = n + ((c.mailbox and c.mailbox.count) or 0) end
                return string.format(T("%d lettres"), n)
            end
            if k == "halo" then return WK.modules.Glow:Config().enabled and T("activé") or T("désactivé dans QoL") end
            if k == "micro" then return UI.ClockConfig().enabled and T("activé") or T("désactivé dans QoL") end
            if k == "fishing" then local s = WK.modules.Fishing:Skill(); return s and string.format(T("compétence %d"), s) or T("pas appris") end
            if k == "range" then return T("chasseur") end
            return f.desc and T(f.desc) or T("page")
        end)
        return ok and v or ""
    end,

    RefreshModules = function(self)
        if not self.modCard then return end
        local n, total = WK:FeatureCount()
        self.modCount:SetText(string.format(T("%d / %d actifs"), n, total))
        local r, g, b = UI:Accent()
        for i, f in ipairs(WK.FEATURES) do
            local on = WK:FeatureOn(f.key)
            if on then self.modDots[i]:SetVertexColor(r, g, b) else self.modDots[i]:SetVertexColor(unpack(C.dim)) end
        end
        for _, t in ipairs(self.modTiles) do
            local on = WK:FeatureOn(t.f.key)
            t.toggle:Refresh()
            t.edge:SetColor(unpack(C.border))
            t.bg:SetColor(unpack(C.surface2))
            if on then t.icon:SetVertexColor(r, g, b) else t.icon:SetVertexColor(unpack(C.dim)) end
            t.name:SetTextColor(unpack(on and C.text or C.dim))
            t.sub:SetText(self:ModuleStat(t.f))
        end
        self.modReload:SetShown(self.needReload and true or false)
        self.modReloadHint:SetShown(self.needReload and true or false)
    end,

    -- Colonnes du tableau proportionnelles à la largeur (prévues pour 924 px).
    PlaceColumns = function(self, w)
        local k = (w or UI.PAGE_W) / 924
        for i, c in ipairs(BASE_COLS) do COLS[i] = { c[1], math.floor(c[2] * k), c[3] } end
        for i, t in ipairs(self.colHeaders) do
            t:ClearAllPoints()
            if COLS[i][3] == "RIGHT" then
                t:SetPoint("TOPRIGHT", self.tableBox, "TOPLEFT", COLS[i][2] + 12, 0)
            else
                t:SetPoint("TOPLEFT", self.tableBox, "TOPLEFT", COLS[i][2], 0)
            end
        end
        for _, r in ipairs(self.rows.items) do self:PlaceRow(r) end
    end,

    PlaceRow = function(self, r)
        local function at(region, point, x, rel)
            region:ClearAllPoints()
            region:SetPoint(point, r, rel or "LEFT", x, 0)
        end
        at(r.icon, "LEFT", COLS[1][2])
        at(r.level, "LEFT", COLS[2][2])
        at(r.gold, "RIGHT", COLS[3][2] + 12)
        at(r.diff, "RIGHT", COLS[4][2] + 12)
        at(r.spark, "LEFT", COLS[5][2])
        at(r.bags, "LEFT", COLS[6][2])
        at(r.seen, "LEFT", COLS[7][2])
    end,

    Refresh = function(self)
        local S = WK.modules.Statistics
        local now = time()
        local chars = UI:SortedCharacters()

        -- À faire : groupes par urgence (Urgent, Bientôt, À noter), texte sur deux lignes
        self.todoRows:Reset(); self.todoHeads:Reset()
        local items = todoItems()
        local GROUPS = { { "URGENT", C.negative }, { "BIENTÔT", C.warning }, { "À NOTER", C.muted } }
        local function groupOf(it) if it.prio <= 2 then return 1 elseif it.prio <= 5 then return 2 end return 3 end
        local ty, lastG = 0, nil
        for _, it in ipairs(items) do
            local gi = groupOf(it)
            local gcol = GROUPS[gi][2]
            if gi ~= lastG then
                lastG = gi
                local hd = self.todoHeads:Get()
                hd:ClearAllPoints(); hd:SetPoint("TOPLEFT", 10, -(ty + (ty > 0 and 8 or 2)))
                hd:SetText(WK.T(GROUPS[gi][1])); hd:SetTextColor(unpack(gcol)); hd:Show()
                ty = ty + (ty > 0 and 26 or 20)
            end
            local r = self.todoRows:Get()
            r.go = it.go
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -ty)
            r:SetPoint("TOPRIGHT", 0, -ty)
            local col = it.color or gcol
            r.box.edge:SetColor(col[1], col[2], col[3], 1)
            r.box.bg:SetColor(unpack(C.surface2))
            r.icon:SetTexture(UI.MEDIA .. it.icon)
            r.icon:SetVertexColor(col[1], col[2], col[3])
            -- « titre  ·  détail » : le détail passe sur la deuxième ligne
            local main, rest = it.text:match("^(.-)%s+·%s+(.+)$")
            r.text:SetText(main or it.text)
            r.text:SetTextColor(unpack(C.text))
            r.sub:SetText(rest or "")
            local th = math.min(34, r.text:GetStringHeight() or 15)
            local h = math.max(36, math.ceil(th + (rest and 17 or 0) + 16))
            r:SetHeight(h)
            ty = ty + h + 2
        end
        self.todoScroll:SetContentHeight(ty)
        self.todoEmpty:SetShown(#items == 0)
        local r1, g1, b1 = UI:Accent()
        self.todoBadge:SetShown(#items > 0)
        self.todoBadge.bg:SetColor(r1, g1, b1, 1)
        self.todoBadge.text:SetText(tostring(#items))
        self.todoBadge.text:SetTextColor(unpack(C.onAccent))
        self.todoBadge:SetWidth(math.max(22, (self.todoBadge.text:GetStringWidth() or 8) + 14))

        -- Objectifs
        self.goalCards:Reset()
        local goals = WK.modules.Goals:List()
        local G = WK.modules.Goals
        local shown = math.min(#goals, 4)
        local gw = shown > 0 and (UI.PAGE_W - (shown - 1) * 10) / shown or 0
        for i = 1, shown do
            local e = goals[i]
            local g = self.goalCards:Get()
            g.key = e.key
            g:SetWidth(gw)
            g:ClearAllPoints()
            g:SetPoint("TOPLEFT", (i - 1) * (gw + 10), self.goalTop)
            local fmt = function(v) return G:IsMoney(e.key) and UI:ShortGold(v) or tostring(v) end
            g.label:SetText(G:Label(e.key) .. "  ·  " .. fmt(e.current) .. " / " .. fmt(e.target))
            g.pct:SetText(math.floor(e.ratio * 100) .. " %")
            g.bar:SetValue(e.ratio)
            if e.ratio >= 1 then g.eta:SetText(WK.T("atteint !"))
            elseif e.days then g.eta:SetText(string.format(WK.T("dans env. %d j"), e.days))
            else g.eta:SetText("") end
        end
        self.tableBox:ClearAllPoints()
        self.tableBox:SetPoint("TOPLEFT", 0, -(TOP_H + GAP + 4) - (shown > 0 and (GOAL_H + 12) or 0))
        self.tableBox:SetPoint("BOTTOMRIGHT", 0, 56 + GAP)
        self:LayoutModules()
        self:RefreshModules()
        -- Courbe
        local n = points(self.days)
        local step = self.days * 86400 / n
        local vals, maxV, minV = {}, 0, math.huge
        for i = 1, n do
            local v = S:AccountGoldAt(now - (n - i) * step)
            vals[i] = v
            if v > maxV then maxV = v end
            if v < minV then minV = v end
        end
        self.empty:SetShown(maxV == 0)
        if maxV > 0 then
            local pad = math.max((maxV - minV) * 0.15, maxV * 0.02)
            self.chart:SetData(vals, { UI:Accent() }, math.max(0, minV - pad), maxV + pad)
            for i, pt in ipairs(self.chart.points) do pt.t = now - (n - i) * step end
        else
            self.chart:SetData({}, { UI:Accent() })
        end
        local fmt = self.days <= 90 and "%d/%m" or "%m/%Y"
        self.xLabels[1]:SetText(date(fmt, now - self.days * 86400))
        self.xLabels[2]:SetText(date(fmt, now - self.days * 43200))
        self.xLabels[3]:SetText(date(fmt, now))

        -- Tableau
        self.rows:Reset()
        local me = WK:CharKey()
        local y = 0
        for _, e in ipairs(chars) do
            local c = e.c
            local r = self.rows:Get()
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -y)
            r:SetPoint("TOPRIGHT", 0, -y)
            local isMe = e.key == me
            r.bg:SetColor(unpack(isMe and C.surface2 or C.surface))
            UI:SetCharIcon(r.icon, c, e.key)
            r.name:SetText(WK:CharName(c, e.key))
            r.name:SetTextColor(UI:ClassColor(c.class))
            r.here:SetShown(isMe)
            local box = c.mailbox
            if box and (box.count or 0) > 0 then
                r.mail:ClearAllPoints()
                r.mail:SetPoint("LEFT", isMe and r.here or r.name, "RIGHT", 6, 0)
                local days = box.expiresAt and math.floor((box.expiresAt - time()) / 86400)
                local soon = days and days <= (WK.DB.global.settings.alerts.mailDays or 3)
                r.mail.icon:SetVertexColor(unpack(soon and C.negative or C.muted))
                local parts = { string.format(box.count > 1 and T("%d lettres") or T("%d lettre"), box.count) }
                local n = WK.modules.Farm:ItemCount(box.items or {})
                if n > 0 then table.insert(parts, string.format(T("%d objet(s)"), n)) end
                if (box.money or 0) > 0 then table.insert(parts, WK:FormatMoney(box.money)) end
                if days then
                    table.insert(parts, (soon and UI:Hex(C.negative) or "") ..
                        string.format(T("expire dans %d j"), math.max(0, days)) .. (soon and "|r" or ""))
                end
                r.mail.tip = T("Courrier en attente") .. "\n" .. table.concat(parts, "  ·  ")
                r.mail:Show()
            else
                r.mail:Hide()
            end
            r.level:SetText(tostring(c.level or "-"))
            r.gold:SetText(UI:GoldText(c.money))

            local spark = {}
            for i = 1, 8 do spark[i] = S:CharGoldAt(e.key, now - (8 - i) * 86400) end
            local d = spark[8] - spark[1]
            r.diff:SetText(d == 0 and "-" or ((d > 0 and "+" or "") .. plainGold(d)))
            local col = d > 0 and C.positive or (d < 0 and C.negative or C.dim)
            r.diff:SetTextColor(unpack(col))
            r.spark:SetData(spark, col)

            local free, total = c.freeSlots, c.totalSlots
            r.bags:SetText(total and total > 0 and string.format("%d / %d", total - (free or 0), total) or "-")
            r.seen:SetText(isMe and "maintenant" or UI:Ago(c.lastSeen))
            y = y + 48
        end
        self.scroll:SetContentHeight(y)
    end,
})
