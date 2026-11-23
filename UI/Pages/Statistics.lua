local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local CreateFrame, date, time = _G.CreateFrame, _G.date, _G.time

local LEFT_W = 230
local GAP = 12
local KPI_H, FLOW_H = 72, 112
local RANGES = { { 7, "7 j" }, { 30, "30 j" }, { 90, "90 j" }, { 365, "1 an" } }

-- Journal de l'or (Modules/ClientDash.lua : WK.DB.global.moneyLog) : couleur de chaque cause
local CAUSE_COL = {
    ["Réparations"] = "warning", ["Vols"] = "info", ["Achats chez le marchand"] = "gold", ["Ventes au marchand"] = "positive",
    ["Hôtel des ventes"] = "rare", ["Courrier"] = "mint", ["Maître (apprentissage)"] = "plan", ["Quêtes"] = "positive",
    ["Butin"] = "tank", ["Échange"] = "silver", ["Autre"] = "muted",
}
local function causeColor(s) return C[CAUSE_COL[s] or "muted"] or C.muted end
-- mouvements des `days` derniers jours, du plus récent au plus ancien (perso connecté seulement si `me`)
local function moneyEntries(days, me)
    local out, cut, ck = {}, time() - days * 86400, WK:CharKey()
    local log = WK.DB.global.moneyLog or {}
    for i = #log, 1, -1 do
        local e = log[i]
        if (e.t or 0) < cut then break end
        if not me or e.c == ck then table.insert(out, e) end
    end
    return out
end
local function charLabel(ck)
    local c = WK.DB.global.characters[ck]
    local r, g, b = UI:ClassColor(c and c.class)
    return UI:Hex({ r, g, b }) .. WK:CharName(c, ck) .. "|r"
end
-- « Samedi 22 novembre » (« Aujourd'hui », « Hier »)
local DAYS = { "Dimanche", "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi" }
local MONTHS = { "janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre",
    "novembre", "décembre" }
local function dayLabel(t)
    local today = date("%Y%m%d")
    local d = date("%Y%m%d", t)
    local lab = WK.T(DAYS[tonumber(date("%w", t)) + 1]) .. " " .. tonumber(date("%d", t)) .. " "
        .. WK.T(MONTHS[tonumber(date("%m", t))])
    if d == today then return WK.T("Aujourd'hui") .. " · " .. lab end
    if d == date("%Y%m%d", time() - 86400) then return WK.T("Hier") .. " · " .. lab end
    return lab
end
local function signedMoney(v)
    return (v >= 0 and (UI:Hex(C.positive) .. "+") or (UI:Hex(C.negative) .. "-")) .. WK:FormatMoney(math.abs(v)) .. "|r"
end

-- Nombre de points de la courbe selon la période.
local function buckets(days)
    if days <= 7 then return 28 end
    if days <= 30 then return 30 end
    if days <= 90 then return 45 end
    return 52
end

UI:RegisterPage({
    key = "stats", order = 5, nav = "Stats",
    title = "Statistiques",
    subtitle = "Évolution de l'or du compte et des matériaux suivis.",

    Build = function(self, p)
        self.series = "gold"
        self.days = 7
        -- onglets : courbes, journal de l'or, répartition des dépenses (retenu dans settings.ui.statsTab)
        local ui = WK.DB.global.settings.ui
        self.view = ui.statsTab or "curves"
        local page = p
        self.tabs = UI:Segmented(page, { { "curves", "Courbes" }, { "journal", "Journal de l'or" }, { "spend", "Dépenses" } },
            function(v) self.view = v; ui.statsTab = v; self:Refresh() end, 30)
        self.tabs:SetPoint("TOPLEFT")
        local host = CreateFrame("Frame", nil, page)
        host:SetPoint("TOPLEFT", 0, -42); host:SetPoint("BOTTOMRIGHT")
        self.curvesHost = host
        p = host

        -- Liste des séries ---------------------------------------------------
        local list = UI:Card(p, "Séries")
        list:SetWidth(LEFT_W)
        list:SetPoint("TOPLEFT")
        list:SetPoint("BOTTOMLEFT")
        self.list = list

        local add = UI:Input(list, LEFT_W - 72, 30, "Maj+clic objet / ID")
        add:SetPoint("BOTTOMLEFT", 12, 12)
        add.edit.acceptLinks = true
        local plus = UI:Button(list, "", 40, 30, "primary", "plus")
        plus.icon:ClearAllPoints(); plus.icon:SetPoint("CENTER")
        plus:SetPoint("BOTTOMRIGHT", -12, 12)
        plus.tooltip = "Suivre cet objet dans les statistiques"
        local function doAdd()
            local id = WK:ParseItemID(add:GetText())
            if id then WK.modules.Statistics:Track(id); add:SetText(""); self.series = id; self:Refresh() end
        end
        plus:SetScript("OnClick", doAdd)
        add.onEnter = doAdd

        local scroll = UI:Scroll(list)
        scroll:SetPoint("TOPLEFT", 8, -40)
        scroll:SetPoint("BOTTOMRIGHT", -6, 52)
        self.listScroll = scroll

        self.entries = UI:Pool(function()
            local b = CreateFrame("Button", nil, scroll.child)
            b:SetHeight(40)
            b.bg = UI:Rounded(b, 10, 0, "BACKGROUND", 1)
            b.icon = UI:RoundIcon(b, 22)
            b.icon:SetPoint("LEFT", 8, 0)
            b.glyph = UI:Icon(b, "coin", 16)
            b.glyph:SetPoint("CENTER", b.icon, "CENTER")
            b.name = UI:Text(b, 12)
            b.name:SetPoint("TOPLEFT", 38, -7)
            b.name:SetPoint("TOPRIGHT", -28, -7)
            b.value = UI:Text(b, 10, C.muted)
            b.value:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -3)
            b.del = UI:IconButton(b, "trash", 22, "Retirer des statistiques (la règle d'envoi reste)", true)
            b.del:SetPoint("RIGHT", -2, 0)
            b.del:SetScript("OnClick", function(btn)
                WK.modules.Statistics:Untrack(btn.key)
                if self.series == btn.key then self.series = "gold" end
                self:Refresh()
            end)
            b:SetScript("OnEnter", function(btn) btn.hover = true; btn:Paint() end)
            b:SetScript("OnLeave", function(btn) btn.hover = false; btn:Paint() end)
            b:SetScript("OnClick", function(btn) self.series = btn.key; self:Refresh() end)
            function b:Paint()
                local sel = self.selected
                self.bg:SetColor(unpack(sel and C.surface2 or C.hover))
                self.bg:SetShown(sel or self.hover)
            end
            return b
        end)

        -- Graphique ------------------------------------------------------------
        local card = UI:Card(p)
        card:SetPoint("TOPLEFT", list, "TOPRIGHT", GAP, 0)
        card:SetPoint("BOTTOMRIGHT")
        self.card = card

        self.seriesTitle = UI:Text(card, 13, C.muted)
        self.seriesTitle:SetPoint("TOPLEFT", 18, -16)
        self.seriesValue = UI:Text(card, 22)
        self.seriesValue:SetPoint("TOPLEFT", self.seriesTitle, "BOTTOMLEFT", 0, -8)
        self.delta = UI:Badge(card, "")
        self.delta:SetPoint("LEFT", self.seriesValue, "RIGHT", 10, 0)

        local seg = UI:Segmented(card, (function()
            local t = {}
            for _, r in ipairs(RANGES) do table.insert(t, { r[1], r[2] }) end
            return t
        end)(), function(d) self.days = d; self:Refresh() end, 30)
        seg:SetPoint("TOPRIGHT", -14, -14)
        seg:Select(7)

        -- Matériaux : total du compte ou une courbe par personnage.
        self.mode = "total"
        self.modeSeg = UI:Segmented(card, { { "total", "Compte" }, { "chars", "Par perso" } },
            function(m) self.mode = m; self:Refresh() end, 30)
        self.modeSeg:SetPoint("RIGHT", seg, "LEFT", -8, 0)
        self.modeSeg:Select("total")
        self.legend = UI:Pool(function()
            local f = CreateFrame("Frame", nil, card)
            f:SetHeight(16)
            f.dot = UI:Icon(f, "circle", 8, nil, "ARTWORK")
            f.dot:SetPoint("LEFT")
            f.text = UI:Text(f, 11, C.muted)
            f.text:SetPoint("LEFT", 13, 0)
            return f
        end)
        self.charCharts = {}

        -- Objectif sur la série affichée (or et richesse en po, matériaux en quantité).
        self.goalBtn = UI:Button(card, "Définir", 84, 28, "secondary", "plus")
        self.goalBtn:SetPoint("TOPRIGHT", -14, -52)
        self.goalInput = UI:NumberInput(card, 110, 28, "Objectif")
        self.goalInput:SetPoint("RIGHT", self.goalBtn, "LEFT", -6, 0)
        self.goalDel = UI:IconButton(card, "trash", 26, "Retirer l'objectif", true)
        self.goalDel:SetPoint("RIGHT", self.goalInput, "LEFT", -4, 0)
        local function setGoal()
            local n = self.goalInput:GetNumber()
            if n <= 0 then return end
            local money = self.series == "gold" or self.series == "value"
            WK.modules.Goals:Set(self.series, money and n * 10000 or n)
            self.goalInput:SetText("")
            self:Refresh()
        end
        self.goalBtn:SetScript("OnClick", setGoal)
        self.goalInput.onEnter = setGoal
        self.goalDel:SetScript("OnClick", function() WK.modules.Goals:Remove(self.series); self:Refresh() end)
        self.goalInfo = UI:Text(card, 11, C.muted)
        self.goalInfo:SetPoint("LEFT", self.delta, "RIGHT", 10, 0)


        local area = CreateFrame("Frame", nil, card)
        area:SetPoint("TOPLEFT", 70, -104)
        area:SetPoint("BOTTOMRIGHT", -18, 40)
        self.area = area

        -- Ligne pointillée de l'objectif.
        self.goalDash = {}
        for i = 1, 200 do -- assez pour une fenêtre très large
            local d = self.area:CreateTexture(nil, "ARTWORK", nil, 4)
            d:SetSize(6, 1.5)
            d:Hide()
            self.goalDash[i] = d
        end
        self.goalLabel = UI:Text(self.area, 10)

        self.grid = {}
        for i = 0, 3 do
            local line = area:CreateTexture(nil, "BACKGROUND", nil, 2)
            line:SetColorTexture(unpack(C.border))
            line:SetHeight(1)
            local lbl = UI:Text(card, 10, C.dim)
            lbl:SetJustifyH("RIGHT")
            self.grid[i] = { line = line, label = lbl }
        end
        self.xLabels = {}
        for i = 1, 3 do
            self.xLabels[i] = UI:Text(card, 10, C.dim)
        end
        self.empty = UI:Text(card, 12, C.muted)
        self.empty:SetPoint("CENTER", area, "CENTER")
        self.empty:SetText("Pas encore assez de données : reviens après quelques sessions de jeu.")

        self.chart = UI:LineChart(area, 2.5, true)
        self.chart:SetAllPoints()
        UI:ChartHover(area, self.chart, function(pt)
            return (self.series == "gold" or self.series == "value") and WK:FormatMoney(pt.v) or ("x" .. pt.v)
        end)
        UI:OnResize(p, function() if self.chart then UI:RefreshSoon() end end)
        self:BuildGold(page)
        self:BuildJournal()
        self:BuildSpend()
        self.tabs:Select(self.view)
    end,

    -- Haut commun au Journal et aux Dépenses : filtres (persos, période), chiffres clés
    BuildGold = function(self, page)
        local ui = WK.DB.global.settings.ui
        self.gDays, self.gMe = ui.goldDays or 7, ui.goldMe or false
        self.gSeg = UI:Segmented(page, { { 1, "24 h" }, { 7, "7 j" }, { 30, "30 j" } }, function(d)
            self.gDays = d; ui.goldDays = d; self:Refresh()
        end, 30)
        self.gSeg:SetPoint("TOPRIGHT"); self.gSeg:Select(self.gDays)
        self.gWho = UI:Segmented(page, { { false, "Tous les persos" }, { true, "Ce perso" } }, function(m)
            self.gMe = m; ui.goldMe = m or nil; self:Refresh()
        end, 30)
        self.gWho:SetPoint("RIGHT", self.gSeg, "LEFT", -8, 0); self.gWho:Select(self.gMe)
        local host = CreateFrame("Frame", nil, page)
        host:SetPoint("TOPLEFT", 0, -42); host:SetPoint("BOTTOMRIGHT")
        self.gHost = host
        -- 4 chiffres clés
        self.kpis = {}
        for i = 1, 4 do
            local k = CreateFrame("Frame", nil, host)
            k:SetHeight(KPI_H)
            UI:Panel(k, 10, C.surface, C.border)
            k.label = UI:Text(k, 10, C.dim); k.label:SetPoint("TOPLEFT", 14, -10)
            k.value = UI:Text(k, 17); k.value:SetPoint("TOPLEFT", 14, -26)
            k.sub = UI:Text(k, 11, C.muted); k.sub:SetPoint("TOPLEFT", 14, -50); k.sub:SetPoint("RIGHT", -10, 0)
            k.sub:SetJustifyH("LEFT"); if k.sub.SetWordWrap then k.sub:SetWordWrap(false) end
            self.kpis[i] = k
        end
        UI:OnResize(host, function(w)
            local kw = (w - 3 * GAP) / 4
            for i, k in ipairs(self.kpis) do
                k:ClearAllPoints(); k:SetPoint("TOPLEFT", (i - 1) * (kw + GAP), 0); k:SetWidth(kw)
            end
        end)
        self.gEmpty = UI:Text(host, 12, C.muted); self.gEmpty:SetPoint("CENTER")
        self.gEmpty:SetText(WK.T("Aucun mouvement d'or noté sur cette période (le journal commence avec la version 1.83.0)."))
    end,
    SetKpi = function(self, i, label, value, sub, col)
        local k = self.kpis[i]
        k.label:SetText(UI:Upper(WK.T(label)))
        k.value:SetText(value)
        col = col or C.text
        k.value:SetTextColor(col[1], col[2], col[3])
        k.sub:SetText(sub or "")
    end,
    -- chiffres de la période (et de la période d'avant, pour l'écart)
    GoldTotals = function(self)
        local list = moneyEntries(self.gDays, self.gMe)
        local gain, spent, by = 0, 0, {}
        for _, e in ipairs(list) do
            if e.d >= 0 then gain = gain + e.d else spent = spent - e.d end
            if e.d < 0 then by[e.s or "Butin"] = (by[e.s or "Butin"] or 0) - e.d end
        end
        local prevGain = 0
        local older = moneyEntries(self.gDays * 2, self.gMe)
        local cut = time() - self.gDays * 86400
        for _, e in ipairs(older) do if e.t < cut and e.d > 0 then prevGain = prevGain + e.d end end
        return list, gain, spent, by, prevGain
    end,
    PeriodLabel = function(self)
        return self.gDays == 1 and WK.T("24 dernières heures") or string.format(WK.T("%d jours"), self.gDays)
    end,

    -- Journal de l'or (maquette A) : chiffres clés, filtres par cause (pastilles), recherche ; liste rangée par jour
    -- (total sur l'en-tête), détail de chaque mouvement ; ramassages d'or à la suite regroupés (dépliables)
    BuildJournal = function(self)
        local host = self.gHost
        local f = CreateFrame("Frame", nil, host)
        f:SetPoint("TOPLEFT", 0, -(KPI_H + GAP)); f:SetPoint("BOTTOMRIGHT")
        f:Hide()
        self.jCard = f
        self.jCauses, self.jQuery, self.jOpen = {}, "", {}
        self.chips = UI:Pool(function()
            local b = CreateFrame("Button", nil, f)
            b:SetHeight(24)
            b.bg = UI:Rounded(b, 12, 0, "BACKGROUND", 1)
            b.edge = UI:Rounded(b, 12, 0, "BACKGROUND", 0)
            b.dot = UI:Icon(b, "circle", 8, nil, "ARTWORK"); b.dot:SetPoint("LEFT", 10, 0)
            b.t = UI:Text(b, 11); b.t:SetPoint("LEFT", 22, 0)
            b:SetScript("OnClick", function(s2)
                if s2.cause == nil then self.jCauses = {} else
                    self.jCauses[s2.cause] = (not self.jCauses[s2.cause]) or nil
                end
                self:Refresh()
            end)
            return b
        end)
        self.jSearch = UI:Input(f, 220, 28, "Rechercher...", "search")
        self.jSearch:SetPoint("TOPRIGHT", 0, 0)
        self.jSearch.onChange = function(t) self.jQuery = string.lower(t or ""); self:Refresh() end
        local list = UI:Card(f)
        list:SetPoint("TOPLEFT", 0, -38); list:SetPoint("BOTTOMRIGHT")
        self.jList = list
        local scroll = UI:Scroll(list)
        scroll:SetPoint("TOPLEFT", 8, -8); scroll:SetPoint("BOTTOMRIGHT", -8, 8)
        self.jScroll = scroll
        self.jHeads = UI:Pool(function()
            local h = CreateFrame("Frame", nil, scroll.child)
            h:SetHeight(28)
            h.bg = UI:Rounded(h, 7, 0, "BACKGROUND", 1); h.bg:SetColor(unpack(C.surface2))
            h.t = UI:Text(h, 13); h.t:SetPoint("LEFT", 10, 0)
            h.right = UI:Text(h, 11, C.muted); h.right:SetPoint("RIGHT", -10, 0)
            return h
        end)
        self.jRows = UI:Pool(function()
            local r = CreateFrame("Button", nil, scroll.child)
            r:SetHeight(24)
            r.bg = UI:Rounded(r, 6, 0, "BACKGROUND", 1)
            r.when = UI:Text(r, 11, C.muted); r.when:SetPoint("LEFT", 10, 0)
            r.who = UI:Text(r, 11); r.who:SetPoint("LEFT", 64, 0); r.who:SetWidth(130); r.who:SetJustifyH("LEFT")
            if r.who.SetWordWrap then r.who:SetWordWrap(false) end
            r.dot = UI:Icon(r, "circle", 8, nil, "ARTWORK"); r.dot:SetPoint("LEFT", 202, 0)
            r.cause = UI:Text(r, 11); r.cause:SetPoint("LEFT", 216, 0)
            r.cause:SetWidth(170); r.cause:SetJustifyH("LEFT")
            r.amount = UI:Text(r, 11); r.amount:SetPoint("RIGHT", -10, 0); r.amount:SetJustifyH("RIGHT")
            r.detail = UI:Text(r, 11, C.dim); r.detail:SetPoint("LEFT", 392, 0)
            r.detail:SetPoint("RIGHT", r.amount, "LEFT", -12, 0)
            r.detail:SetJustifyH("LEFT"); if r.detail.SetWordWrap then r.detail:SetWordWrap(false) end
            r:SetScript("OnEnter", function(s2) if s2.group then s2.bg:SetColor(unpack(C.hover)); s2.bg:Show() end end)
            r:SetScript("OnLeave", function(s2)
                if s2.group then s2.bg:SetShown(s2.zebra or false); s2.bg:SetColor(unpack(C.surface2)) end
            end)
            r:SetScript("OnClick", function(s2)
                if s2.group then self.jOpen[s2.group] = (not self.jOpen[s2.group]) or nil; self:Refresh() end
            end)
            return r
        end)
    end,
    RefreshJournal = function(self)
        local list, gain, spent = self:GoldTotals()
        local net = gain - spent
        self:SetKpi(1, "Mouvements", tostring(#list), self:PeriodLabel())
        self:SetKpi(2, "Gagné", WK:FormatMoney(gain), nil)
        self:SetKpi(3, "Dépensé", WK:FormatMoney(spent), nil)
        self:SetKpi(4, "Bilan", signedMoney(net), nil, net >= 0 and C.positive or C.negative)
        -- pastilles des causes présentes (Toutes + chaque cause, plusieurs à la fois)
        self.chips:Reset()
        local seen, causes = {}, {}
        for _, e in ipairs(list) do
            local s = e.s or "Butin"
            if not seen[s] then seen[s] = true; causes[#causes + 1] = s end
        end
        table.sort(causes, function(a, b) return WK.T(a) < WK.T(b) end)
        local x, cy = 0, 2
        -- les pastilles passent à la ligne avant la recherche (à droite sur la 1re ligne)
        local avail = math.max(200, (self.jCard:GetWidth() or 800) - 236)
        local none = next(self.jCauses) == nil
        local function chip(cause, label)
            local b = self.chips:Get()
            b.cause = cause
            b.t:SetText(label)
            b:SetWidth((b.t:GetStringWidth() or 40) + 32)
            if x > 0 and x + b:GetWidth() > avail then x, cy = 0, cy + 30; avail = (self.jCard:GetWidth() or 800) end
            b:ClearAllPoints(); b:SetPoint("TOPLEFT", x, -cy); x = x + b:GetWidth() + 6
            local on = (cause == nil and none) or (cause and self.jCauses[cause])
            local col = cause and causeColor(cause) or C.text
            b.dot:SetVertexColor(col[1], col[2], col[3], 1); b.dot:SetShown(cause ~= nil)
            if cause == nil then
                b.t:ClearAllPoints(); b.t:SetPoint("CENTER", 0, 0)
                b:SetWidth((b.t:GetStringWidth() or 40) + 20); x = x - 12
            end
            b.edge:SetColor(C.border[1], C.border[2], C.border[3], 1)
            b.bg:SetColor(C.surface2[1], C.surface2[2], C.surface2[3], on and 1 or 0)
            b.t:SetTextColor(unpack(on and C.text or C.muted))
        end
        chip(nil, WK.T("Toutes"))
        for _, s in ipairs(causes) do chip(s, WK.T(s)) end
        self.jList:ClearAllPoints(); self.jList:SetPoint("TOPLEFT", 0, -(cy + 36)); self.jList:SetPoint("BOTTOMRIGHT")
        -- filtre (causes, recherche) puis jours et regroupement du butin
        local q = self.jQuery or ""
        local rows = {}
        for _, e in ipairs(list) do
            local s = e.s or "Butin"
            if none or self.jCauses[s] then
                local c = WK.DB.global.characters[e.c]
                local hay = string.lower(WK.T(s) .. " " .. (e.x or "") .. " " .. WK:CharName(c, e.c))
                if q == "" or hay:find(q, 1, true) then rows[#rows + 1] = e end
            end
        end
        self.jHeads:Reset(); self.jRows:Reset()
        local y, zebra = 0, false
        local W = math.max(1, self.jScroll:GetWidth() - 14)
        self.jScroll.child:SetWidth(W)
        local function line(e, opts)
            local r = self.jRows:Get()
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:SetPoint("TOPRIGHT", self.jScroll.child, "TOPRIGHT", 0, -y)
            zebra = not zebra
            r.zebra = zebra; r.group = opts and opts.group or nil
            r.bg:SetColor(unpack(C.surface2)); r.bg:SetShown(zebra)
            r.when:SetText(date("%H:%M", e.t))
            r.who:SetText(charLabel(e.c))
            local col = causeColor(e.s or "Butin")
            r.dot:SetVertexColor(col[1], col[2], col[3], 1)
            r.cause:SetText(WK.T(e.s or "Butin"))
            r.detail:SetText(opts and opts.detail or e.x or ((e.n or 1) > 1 and string.format(WK.T("%d mouvements"), e.n) or ""))
            r.amount:SetText(signedMoney(opts and opts.sum or e.d))
            y = y + 26
        end
        local i, shown = 1, 0
        local curDay
        while i <= #rows and shown < 500 do
            local e = rows[i]
            local day = date("%Y%m%d", e.t)
            if day ~= curDay then
                curDay = day
                -- en-tête du jour : total de ses mouvements (après filtres)
                local dg, ds = 0, 0
                for j = i, #rows do
                    if date("%Y%m%d", rows[j].t) ~= day then break end
                    if rows[j].d >= 0 then dg = dg + rows[j].d else ds = ds - rows[j].d end
                end
                local h = self.jHeads:Get()
                h:ClearAllPoints(); h:SetPoint("TOPLEFT", 0, -(y + (y > 0 and 6 or 0))); h:SetPoint("TOPRIGHT", self.jScroll.child, "TOPRIGHT", 0, -(y + (y > 0 and 6 or 0)))
                y = y + (y > 0 and 6 or 0)
                h.t:SetText(dayLabel(e.t))
                h.right:SetText(string.format(WK.T("gagné %s · dépensé %s · %s"),
                    UI:Hex(C.positive) .. "+" .. WK:FormatMoney(dg) .. "|r", UI:Hex(C.negative) .. "-" .. WK:FormatMoney(ds) .. "|r", signedMoney(dg - ds)))
                y = y + 32
                zebra = false
            end
            -- ramassages d'or (Butin) à la suite, même perso, même jour : une ligne dépliable
            local j = i
            if (e.s or "Butin") == "Butin" and e.d > 0 then
                while j + 1 <= #rows and (rows[j + 1].s or "Butin") == "Butin" and rows[j + 1].c == e.c and rows[j + 1].d > 0
                    and date("%Y%m%d", rows[j + 1].t) == day do j = j + 1 end
            end
            if j - i + 1 >= 3 then
                local sum, n = 0, 0
                for k = i, j do sum = sum + rows[k].d; n = n + (rows[k].n or 1) end
                local key = e.c .. ":" .. e.t
                local open = self.jOpen[key]
                line(e, { group = key, sum = sum, detail = string.format(open and WK.T("%d ramassages (clic pour replier)")
                    or WK.T("%d ramassages regroupés (clic pour déplier)"), n) })
                shown = shown + 1
                if open then for k = i, j do line(rows[k]); shown = shown + 1 end end
                i = j + 1
            else
                line(e); shown = shown + 1
                i = i + 1
            end
        end
        self.jScroll:SetContentHeight(y)
    end,

    -- Dépenses (maquette A) : chiffres clés, bande « où part l'or / d'où il vient », puis trois cartes : dépenses
    -- par cause, gains par cause, bilan par perso (barre : gagné en plein, dépensé en pâle) ; clic sur une cause :
    -- le Journal filtré sur elle
    BuildSpend = function(self)
        local host = self.gHost
        local f = CreateFrame("Frame", nil, host)
        f:SetPoint("TOPLEFT", 0, -(KPI_H + GAP)); f:SetPoint("BOTTOMRIGHT")
        f:Hide()
        self.sCard = f
        local flow = UI:Card(f, WK.T("Où part l'or, d'où il vient"))
        flow:SetPoint("TOPLEFT"); flow:SetPoint("TOPRIGHT"); flow:SetHeight(FLOW_H)
        self.sFlow = flow
        flow.lab = {}
        flow.segs = UI:Pool(function()
            local b = CreateFrame("Button", nil, flow)
            b:SetHeight(14)
            b.t = b:CreateTexture(nil, "ARTWORK"); b.t:SetAllPoints()
            b:SetScript("OnEnter", function(s2)
                UI:TooltipOwner(s2, "ANCHOR_TOP")
                GameTooltip:SetText(WK.T(s2.cause), 1, 1, 1)
                GameTooltip:AddLine(WK:FormatMoney(s2.v) .. "  ·  " .. s2.pct .. " %", 0.8, 0.8, 0.8)
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            b:SetScript("OnClick", function(s2) self:OpenJournalFor(s2.cause) end)
            return b
        end)
        for i, l in ipairs({ "Dépenses", "Gains" }) do
            local t = UI:Text(flow, 10, C.dim); t:SetText(UI:Upper(WK.T(l)))
            t:SetPoint("TOPLEFT", 16, -40 - (i - 1) * 34)
            flow.lab[i] = t
        end
        local function col(title)
            local c = UI:Card(f, WK.T(title))
            c.rows = {}
            return c
        end
        self.sLeft = col("Dépenses par cause")
        self.sRight = col("Gains par cause")
        self.sChars = col("Par perso (bilan)")
        self.sChars.note = UI:Text(self.sChars, 10, C.dim)
        self.sChars.note:SetPoint("BOTTOMLEFT", 16, 12); self.sChars.note:SetPoint("BOTTOMRIGHT", -16, 12)
        self.sChars.note:SetJustifyH("LEFT")
        self.sChars.note:SetText(WK.T("Barre : ce qui a fait gagner (plein) et dépenser (pâle)."))
        self.sCharRows = UI:Pool(function()
            local r = CreateFrame("Frame", nil, self.sChars)
            r:SetHeight(34)
            r.line = r:CreateTexture(nil, "BACKGROUND"); r.line:SetHeight(1)
            r.line:SetPoint("TOPLEFT"); r.line:SetPoint("TOPRIGHT")
            r.line:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
            r.name = UI:Text(r, 11); r.name:SetPoint("TOPLEFT", 0, -6)
            r.val = UI:Text(r, 11); r.val:SetPoint("TOPRIGHT", 0, -6)
            r.segs = {}
            return r
        end)
        UI:OnResize(f, function(w)
            local cw = (w - 2 * GAP) / 2.8
            self.sLeft:ClearAllPoints(); self.sLeft:SetPoint("TOPLEFT", 0, -(FLOW_H + GAP)); self.sLeft:SetPoint("BOTTOM"); self.sLeft:SetWidth(cw)
            self.sRight:ClearAllPoints(); self.sRight:SetPoint("TOPLEFT", self.sLeft, "TOPRIGHT", GAP, 0); self.sRight:SetPoint("BOTTOM"); self.sRight:SetWidth(cw)
            self.sChars:ClearAllPoints(); self.sChars:SetPoint("TOPLEFT", self.sRight, "TOPRIGHT", GAP, 0)
            self.sChars:SetPoint("BOTTOMRIGHT")
            if self.sCard:IsShown() then self:RefreshSpend() end
        end)
    end,
    OpenJournalFor = function(self, cause)
        self.jCauses = { [cause] = true }
        self.view = "journal"; WK.DB.global.settings.ui.statsTab = "journal"
        self.tabs:Select("journal")
        self:Refresh()
    end,
    -- barres d'une carte : { { cause, valeur } }, total ; clic : le Journal filtré
    Bars = function(self, card, items, total)
        for _, r in ipairs(card.rows) do r:Hide() end
        local y = 44
        for k, it in ipairs(items) do
            local r = card.rows[k]
            if not r then
                r = CreateFrame("Button", nil, card)
                r:SetHeight(30)
                r.dot = UI:Icon(r, "circle", 8, nil, "ARTWORK"); r.dot:SetPoint("TOPLEFT", 0, -3)
                r.name = UI:Text(r, 11); r.name:SetPoint("TOPLEFT", 14, 0)
                r.name:SetPoint("TOPRIGHT", -130, 0); r.name:SetJustifyH("LEFT")
                r.val = UI:Text(r, 11); r.val:SetPoint("TOPRIGHT", 0, 0); r.val:SetJustifyH("RIGHT")
                r.track = r:CreateTexture(nil, "BACKGROUND"); r.track:SetHeight(6)
                r.track:SetPoint("TOPLEFT", 14, -17); r.track:SetPoint("TOPRIGHT", 0, -17)
                r.fill = r:CreateTexture(nil, "ARTWORK"); r.fill:SetHeight(6); r.fill:SetPoint("TOPLEFT", r.track, "TOPLEFT")
                r:SetScript("OnClick", function(s2) if s2.cause then self:OpenJournalFor(s2.cause) end end)
                card.rows[k] = r
            end
            r.cause = it[1]
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 16, -y); r:SetPoint("TOPRIGHT", card, "TOPRIGHT", -16, -y)
            local c = causeColor(it[1])
            r.dot:SetVertexColor(c[1], c[2], c[3], 1)
            r.name:SetText(WK.T(it[1]))
            local pct = total > 0 and math.floor(it[2] / total * 100 + 0.5) or 0
            r.val:SetText(WK:FormatMoney(it[2]) .. "  " .. UI:Hex(C.dim) .. pct .. " %|r")
            r.track:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
            r.fill:SetColorTexture(c[1], c[2], c[3], 0.9)
            r.fill:SetWidth(math.max(1, ((card:GetWidth() or 300) - 46) * (total > 0 and it[2] / total or 0)))
            r:Show()
            y = y + 36
        end
    end,
    RefreshSpend = function(self)
        local list, gain, spent, _, prevGain = self:GoldTotals()
        local spentBy, gainBy, byChar = {}, {}, {}
        for _, e in ipairs(list) do
            local s = e.s or "Butin"
            if e.d < 0 then spentBy[s] = (spentBy[s] or 0) - e.d else gainBy[s] = (gainBy[s] or 0) + e.d end
            local bc = byChar[e.c] or { net = 0, by = {} }
            byChar[e.c] = bc
            bc.net = bc.net + e.d
            bc.by[s] = (bc.by[s] or 0) + e.d
        end
        local function sorted(t)
            local out = {}
            for k, v in pairs(t) do out[#out + 1] = { k, v } end
            table.sort(out, function(a, b) return a[2] > b[2] end)
            return out
        end
        local sp, ga = sorted(spentBy), sorted(gainBy)
        -- chiffres clés
        local net = gain - spent
        self:SetKpi(1, "Dépensé", WK:FormatMoney(spent), string.format(WK.T("%d mouvements, %s"), #list, self:PeriodLabel()))
        local ev = ""
        if prevGain > 0 then
            local pct = math.floor((gain - prevGain) / prevGain * 100 + 0.5)
            ev = string.format(WK.T("%s%d %% par rapport à la période d'avant"), pct >= 0 and "+" or "", pct)
        end
        self:SetKpi(2, "Gagné", WK:FormatMoney(gain), ev)
        self:SetKpi(3, "Bilan", signedMoney(net), self.gDays > 1 and string.format(WK.T("env. %s par jour"), signedMoney(math.floor(net / self.gDays))) or "",
            net >= 0 and C.positive or C.negative)
        if sp[1] then
            local c = causeColor(sp[1][1])
            self:SetKpi(4, "Plus gros poste", WK.T(sp[1][1]), string.format(WK.T("%s · %d %% des dépenses"), WK:FormatMoney(sp[1][2]),
                spent > 0 and math.floor(sp[1][2] / spent * 100 + 0.5) or 0), c)
        else
            self:SetKpi(4, "Plus gros poste", "-", "")
        end
        -- bande : une barre par sens, une part par cause
        local flow = self.sFlow
        flow.segs:Reset()
        local FW = math.max(100, (flow:GetWidth() or 600) - 32 - 80)
        for i, set in ipairs({ { sp, spent }, { ga, gain } }) do
            local x = 96
            for _, it in ipairs(set[1]) do
                local w = set[2] > 0 and FW * it[2] / set[2] or 0
                if w >= 1 then
                    local b = flow.segs:Get()
                    b.cause, b.v = it[1], it[2]
                    b.pct = math.floor(it[2] / set[2] * 100 + 0.5)
                    local c = causeColor(it[1])
                    b.t:SetColorTexture(c[1], c[2], c[3], 0.95)
                    b:ClearAllPoints(); b:SetPoint("TOPLEFT", x, -38 - (i - 1) * 34); b:SetWidth(math.max(1, w - 2))
                    x = x + w
                end
            end
        end
        self:Bars(self.sLeft, sp, spent)
        self:Bars(self.sRight, ga, gain)
        -- par perso : bilan, et une barre des causes (gains pleins, dépenses pâles)
        self.sCharRows:Reset()
        local chars = {}
        for ck, v in pairs(byChar) do chars[#chars + 1] = { ck, v } end
        table.sort(chars, function(a, b) return math.abs(a[2].net) > math.abs(b[2].net) end)
        local y = 44
        local CW = math.max(80, (self.sChars:GetWidth() or 300) - 32)
        for _, ce in ipairs(chars) do
            local r = self.sCharRows:Get()
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 16, -y); r:SetPoint("TOPRIGHT", self.sChars, "TOPRIGHT", -16, -y)
            r.name:SetText(charLabel(ce[1]))
            r.val:SetText(signedMoney(ce[2].net))
            for _, s in ipairs(r.segs) do s:Hide() end
            local parts, tot = {}, 0
            for s, v in pairs(ce[2].by) do parts[#parts + 1] = { s, v }; tot = tot + math.abs(v) end
            table.sort(parts, function(a, b) return a[2] > b[2] end)
            local x = 0
            for k, pt in ipairs(parts) do
                local t = r.segs[k]
                if not t then t = r:CreateTexture(nil, "ARTWORK"); t:SetHeight(6); r.segs[k] = t end
                local w = tot > 0 and CW * math.abs(pt[2]) / tot or 0
                local c = causeColor(pt[1])
                t:SetColorTexture(c[1], c[2], c[3], pt[2] >= 0 and 1 or 0.45)
                t:ClearAllPoints(); t:SetPoint("TOPLEFT", x, -24); t:SetWidth(math.max(1, w - 2)); t:Show()
                x = x + w
            end
            y = y + 40
        end
        self.gEmpty:SetShown(#list == 0)
    end,

    RefreshList = function(self)
        local S = WK.modules.Statistics
        local now = time()
        local tracked = S:TrackedItems()
        local keys = { "gold", "value" }
        local ids = {}
        for id in pairs(tracked) do table.insert(ids, id) end
        table.sort(ids, function(a, b) return UI:ItemInfo(a) < UI:ItemInfo(b) end)
        for _, id in ipairs(ids) do table.insert(keys, id) end
        if self.series ~= "gold" and self.series ~= "value" and not tracked[self.series] then self.series = "gold" end

        self.entries:Reset()
        local y = 0
        for _, key in ipairs(keys) do
            local e = self.entries:Get()
            e.key, e.del.key = key, key
            e:ClearAllPoints()
            e:SetPoint("TOPLEFT", 0, -y)
            e:SetPoint("TOPRIGHT", 0, -y)
            if key == "gold" or key == "value" then
                e.icon:Hide(); e.glyph:Show()
                e.glyph:SetTexture(UI.MEDIA .. (key == "gold" and "coin" or "chart"))
                e.glyph:SetVertexColor(unpack(C.gold))
                e.name:SetText(key == "gold" and "Or du compte" or "Richesse totale")
                e.name:SetTextColor(unpack(C.text))
                e.value:SetText(UI:GoldText(key == "gold" and S:AccountGoldAt(now) or WK.modules.Value:Wealth()))
                e.del:Hide()
            else
                local name, icon, qr, qg, qb = UI:ItemInfo(key)
                e.glyph:Hide(); e.icon:Show()
                e.icon:SetTexture(icon)
                e.name:SetText(name)
                e.name:SetTextColor(qr, qg, qb)
                local suffix = tracked[key] == "mail" and ("  ·  " .. WK.T("règle d'envoi")) or ""
                e.value:SetText("x" .. WK.modules.Inventory:AccountCount(key) .. suffix)
                e.del:SetShown(true)
            end
            local _, _, ratio = WK.modules.Goals:Progress(key)
            if ratio then e.value:SetText(e.value:GetText() .. "  ·  " .. math.floor(ratio * 100) .. " %") end
            e.selected = (key == self.series)
            e:Paint()
            y = y + 44
        end
        self.listScroll:SetContentHeight(y)
    end,

    Refresh = function(self)
        -- onglet affiché : courbes, journal ou dépenses
        local view = self.view or "curves"
        self.curvesHost:SetShown(view == "curves")
        local gold = view == "journal" or view == "spend"
        self.gHost:SetShown(gold); self.gSeg:SetShown(gold); self.gWho:SetShown(gold)
        self.jCard:SetShown(view == "journal")
        self.sCard:SetShown(view == "spend")
        if gold then self.gEmpty:Hide() end
        if view == "journal" then return self:RefreshJournal() end
        if view == "spend" then return self:RefreshSpend() end
        self:RefreshList()
        local S = WK.modules.Statistics
        local key, days = self.series, self.days
        local now = time()
        local n = buckets(days)
        local step = days * 86400 / n
        local isGold = key == "gold" or key == "value"

        if key == "value" then
            self.seriesTitle:SetText(WK.T("Richesse totale") .. " · " .. WK.modules.Value:SourceLabel())
        elseif isGold then
            self.seriesTitle:SetText("Or du compte")
        else
            self.seriesTitle:SetText((UI:ItemInfo(key)))
        end

        local values, maxV = {}, 0
        for i = 1, n do
            local t = now - (n - i) * step
            local v = S:SeriesAt(key, t)
            values[i] = { t = t, v = v }
            if v > maxV then maxV = v end
        end
        local first, last = values[1].v, values[n].v
        self.seriesValue:SetText(isGold and UI:GoldText(last) or ("x" .. last))
        local diff = last - first
        local txt = (diff >= 0 and "+" or "") .. (isGold and UI:ShortGold(diff) or tostring(diff))
        self.delta:Set(txt, diff >= 0 and C.positive or C.negative)

        local area = self.area
        local h = area:GetHeight()

        -- Mode « Par perso » (matériaux uniquement) : une série par personnage.
        local perChar = not isGold and self.mode == "chars"
        self.modeSeg:SetShown(not isGold)
        local minV = math.huge
        local series, keys = {}, {}
        if perChar then
            keys = S:CharsWithItem(key)
            maxV = 0
            for _, ck in ipairs(keys) do
                local vs = {}
                for i = 1, n do
                    local v = S:CharItemAt(ck, key, values[i].t)
                    vs[i] = v
                    if v > maxV then maxV = v end
                    if v < minV then minV = v end
                end
                series[ck] = vs
            end
        else
            for _, pt in ipairs(values) do if pt.v < minV then minV = pt.v end end
        end
        self.empty:SetShown(maxV == 0)

        -- Échelle : on cadre sur la plage des valeurs pour voir les variations.
        local pad = math.max((maxV - minV) * 0.15, maxV * 0.02, 1)
        local lo, hi = math.max(0, minV - pad), maxV + pad

        -- Objectif : progression, échelle étendue pour voir la cible, ligne pointillée.
        local G = WK.modules.Goals
        local goal = G:Get(key)
        local _, target, ratio, gdays = G:Progress(key)
        self.goalDel:SetShown(goal ~= nil)
        self.goalBtn:SetLabel(goal and WK.T("Modifier") or WK.T("Définir"))
        if goal then
            local fmt = isGold and UI:ShortGold(target) or tostring(target)
            local txt = string.format(WK.T("objectif %s · %d %%"), fmt, math.floor(ratio * 100))
            if ratio >= 1 then txt = txt .. " · " .. WK.T("atteint !")
            elseif gdays then txt = txt .. " · " .. string.format(WK.T("dans env. %d j"), gdays) end
            self.goalInfo:SetText(txt)
            if not perChar and maxV > 0 then hi = math.max(hi, target * 1.05) end
        else
            self.goalInfo:SetText("")
        end
        for _, d in ipairs(self.goalDash) do d:Hide() end
        self.goalLabel:Hide()
        if goal and not perChar and maxV > 0 and hi > lo then
            local gy = (target - lo) / (hi - lo) * h
            local w = area:GetWidth()
            local r, g, b = UI:Accent()
            for i, d in ipairs(self.goalDash) do
                local x = (i - 1) * 12
                if x + 6 > w then break end
                d:SetColorTexture(r, g, b, 0.9)
                d:ClearAllPoints()
                d:SetPoint("LEFT", area, "BOTTOMLEFT", x, gy)
                d:Show()
            end
            self.goalLabel:ClearAllPoints()
            self.goalLabel:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", 0, gy + 4)
            self.goalLabel:SetTextColor(r, g, b, 1)
            self.goalLabel:SetText(WK.T("Objectif"))
            self.goalLabel:Show()
        end

        -- Grille + libellés de l'axe vertical
        for i = 0, 3 do
            local gy = h * i / 3
            local gl = self.grid[i]
            gl.line:ClearAllPoints()
            gl.line:SetPoint("BOTTOMLEFT", area, "BOTTOMLEFT", 0, gy)
            gl.line:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", 0, gy)
            gl.label:ClearAllPoints()
            gl.label:SetPoint("RIGHT", area, "BOTTOMLEFT", -10, gy)
            local v = lo + (hi - lo) * i / 3
            gl.label:SetText(maxV == 0 and "" or (isGold and UI:ShortGold(v) or tostring(math.floor(v + 0.5))))
        end

        -- Courbes par personnage + légende
        for _, ch in ipairs(self.charCharts) do ch:SetData({}, C.text) end
        self.legend:Reset()
        if perChar then
            local x = 0
            for i, ck in ipairs(keys) do
                local ch = self.charCharts[i]
                if not ch then
                    ch = UI:LineChart(area, 2, false)
                    ch:SetAllPoints()
                    self.charCharts[i] = ch
                end
                local c = WK.DB.global.characters[ck]
                local col = { UI:ClassColor(c and c.class) }
                ch:SetData(series[ck], col, lo, hi)
                local lg = self.legend:Get()
                lg.dot:SetVertexColor(col[1], col[2], col[3], 1)
                lg.text:SetText(string.format("%s %d", WK:CharName(c, ck), series[ck][n]))
                lg:SetWidth(lg.text:GetStringWidth() + 14)
                lg:ClearAllPoints()
                lg:SetPoint("TOPLEFT", self.card, "TOPLEFT", 18 + x, -80)
                x = x + lg:GetWidth() + 14
            end
        end

        -- Courbe du total (masquée en mode « Par perso »)
        local vals = {}
        for i, pt in ipairs(values) do vals[i] = pt.v end
        if maxV > 0 and not perChar then
            self.chart:SetData(vals, { UI:Accent() }, lo, hi)
            for i, pt in ipairs(self.chart.points) do pt.t = values[i].t end
        else
            self.chart:SetData({}, { UI:Accent() })
        end

        -- Dates sur l'axe horizontal (début, milieu, fin)
        local w = area:GetWidth()
        local idx = { 1, math.ceil(n / 2), n }
        local anchors = { "TOPLEFT", "TOP", "TOPRIGHT" }
        for i = 1, 3 do
            local l = self.xLabels[i]
            l:ClearAllPoints()
            local x = ({ 0, w / 2, w })[i]
            l:SetPoint(anchors[i], area, "BOTTOMLEFT", x, -10)
            l:SetText(date("%d/%m", values[idx[i]].t))
        end
    end,
})
