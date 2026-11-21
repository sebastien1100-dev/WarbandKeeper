local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors

local LEFT_W = 230
local GAP = 12
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
        self:BuildJournal(page)
        self:BuildSpend(page)
        self.tabs:Select(self.view)
    end,

    -- Journal de l'or : chaque mouvement (heure, perso, cause, montant), filtré par période et par perso
    BuildJournal = function(self, page)
        local card = UI:Card(page)
        card:SetPoint("TOPLEFT", 0, -42); card:SetPoint("BOTTOMRIGHT")
        card:Hide()
        self.jCard = card
        self.jDays, self.jMe = 7, false
        local title = UI:Text(card, 13, C.muted); title:SetPoint("TOPLEFT", 18, -16); title:SetText(WK.T("Journal de l'or"))
        self.jSum = UI:Text(card, 12); self.jSum:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
        local seg = UI:Segmented(card, { { 1, "24 h" }, { 7, "7 j" }, { 30, "30 j" } }, function(d) self.jDays = d; self:Refresh() end, 28)
        seg:SetPoint("TOPRIGHT", -14, -14); seg:Select(7)
        local who = UI:Segmented(card, { { false, "Tous les persos" }, { true, "Ce perso" } }, function(m) self.jMe = m; self:Refresh() end, 28)
        who:SetPoint("RIGHT", seg, "LEFT", -8, 0); who:Select(false)
        local head = CreateFrame("Frame", nil, card)
        head:SetPoint("TOPLEFT", 18, -72); head:SetPoint("TOPRIGHT", -24, -72); head:SetHeight(14)
        local function h(text, x, right)
            local t = UI:Text(head, 9, C.dim); t:SetText(UI:Upper(WK.T(text)))
            if right then t:SetPoint("RIGHT", 0, 0) else t:SetPoint("LEFT", x, 0) end
        end
        h("Quand", 0); h("Perso", 110); h("Cause", 260); h("Montant", 0, true)
        local scroll = UI:Scroll(card)
        scroll:SetPoint("TOPLEFT", 12, -90); scroll:SetPoint("BOTTOMRIGHT", -8, 12)
        self.jScroll = scroll
        self.jRows = UI:Pool(function()
            local r = CreateFrame("Frame", nil, scroll.child)
            r:SetHeight(24)
            r.bg = UI:Rounded(r, 6, 0, "BACKGROUND", 1); r.bg:SetColor(unpack(C.surface2))
            r.when = UI:Text(r, 11, C.muted); r.when:SetPoint("LEFT", 6, 0)
            r.who = UI:Text(r, 11); r.who:SetPoint("LEFT", 116, 0); r.who:SetWidth(140); r.who:SetJustifyH("LEFT")
            r.dot = UI:Icon(r, "circle", 8, nil, "ARTWORK"); r.dot:SetPoint("LEFT", 266, 0)
            r.cause = UI:Text(r, 11); r.cause:SetPoint("LEFT", 280, 0)
            r.amount = UI:Text(r, 11); r.amount:SetPoint("RIGHT", -8, 0); r.amount:SetJustifyH("RIGHT")
            return r
        end)
        self.jEmpty = UI:Text(card, 12, C.muted); self.jEmpty:SetPoint("CENTER")
        self.jEmpty:SetText(WK.T("Aucun mouvement d'or noté sur cette période (le journal commence avec la version 1.83.0)."))
    end,
    RefreshJournal = function(self)
        local list = moneyEntries(self.jDays, self.jMe)
        local gain, spent = 0, 0
        for _, e in ipairs(list) do if e.d >= 0 then gain = gain + e.d else spent = spent - e.d end end
        self.jSum:SetText(string.format(WK.T("%d mouvements · gagné %s · dépensé %s · total %s"), #list,
            WK:FormatMoney(gain), WK:FormatMoney(spent), signedMoney(gain - spent)))
        self.jRows:Reset()
        local y = 0
        for i, e in ipairs(list) do
            if i > 400 then break end
            local r = self.jRows:Get()
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:SetPoint("RIGHT", self.jScroll.child, "RIGHT", 0, 0)
            r.bg:SetShown(i % 2 == 0)
            r.when:SetText(date("%d/%m %H:%M", e.t))
            r.who:SetText(charLabel(e.c))
            local col = causeColor(e.s)
            r.dot:SetVertexColor(col[1], col[2], col[3], 1)
            r.cause:SetText(WK.T(e.s or "Autre"))
            r.amount:SetText(signedMoney(e.d))
            y = y + 26
        end
        self.jScroll.child:SetWidth(math.max(1, self.jScroll:GetWidth() - 14))
        self.jScroll:SetContentHeight(y)
        self.jEmpty:SetShown(#list == 0)
    end,

    -- Dépenses : répartition par cause (barres), gains par cause, total par perso
    BuildSpend = function(self, page)
        local card = UI:Card(page)
        card:SetPoint("TOPLEFT", 0, -42); card:SetPoint("BOTTOMRIGHT")
        card:Hide()
        self.sCard = card
        self.sDays = 7
        local title = UI:Text(card, 13, C.muted); title:SetPoint("TOPLEFT", 18, -16); title:SetText(WK.T("Répartition des dépenses"))
        self.sSum = UI:Text(card, 12); self.sSum:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
        local seg = UI:Segmented(card, { { 1, "24 h" }, { 7, "7 j" }, { 30, "30 j" } }, function(d) self.sDays = d; self:Refresh() end, 28)
        seg:SetPoint("TOPRIGHT", -14, -14); seg:Select(7)
        local function column(x0, x1, label)
            local col = CreateFrame("Frame", nil, card)
            col:SetPoint("TOPLEFT", card, "TOP", x0, -76); col:SetPoint("BOTTOMRIGHT", card, "BOTTOM", x1, 16)
            col.title = UI:Text(col, 10, C.dim); col.title:SetPoint("TOPLEFT", 0, 0); col.title:SetText(UI:Upper(WK.T(label)))
            col.rows = {}
            return col
        end
        -- deux colonnes : dépenses à gauche, gains et persos à droite (ancrées au milieu de la carte)
        self.sLeft = column(-0, 0, "Dépenses par cause")
        self.sLeft:ClearAllPoints(); self.sLeft:SetPoint("TOPLEFT", 18, -76); self.sLeft:SetPoint("BOTTOMRIGHT", card, "BOTTOM", -12, 16)
        self.sRight = column(0, 0, "Gains par cause")
        self.sRight:ClearAllPoints(); self.sRight:SetPoint("TOPLEFT", card, "TOP", 12, -76); self.sRight:SetPoint("BOTTOMRIGHT", -18, 16)
        self.sEmpty = UI:Text(card, 12, C.muted); self.sEmpty:SetPoint("CENTER")
        self.sEmpty:SetText(WK.T("Aucun mouvement d'or noté sur cette période (le journal commence avec la version 1.83.0)."))
    end,
    -- barres d'une colonne : { { label, valeur, couleur } }, à partir de y ; renvoie le bas
    Bars = function(self, col, items, y, total)
        local k0 = col.used or 0
        for _, it in ipairs(items) do
            k0 = k0 + 1
            local r = col.rows[k0]
            if not r then
                r = CreateFrame("Frame", nil, col)
                r:SetHeight(30)
                r.dot = UI:Icon(r, "circle", 8, nil, "ARTWORK"); r.dot:SetPoint("TOPLEFT", 0, -3)
                r.name = UI:Text(r, 11); r.name:SetPoint("TOPLEFT", 14, 0); r.name:SetPoint("RIGHT", -110, 0); r.name:SetJustifyH("LEFT")
                r.val = UI:Text(r, 11); r.val:SetPoint("TOPRIGHT", 0, 0); r.val:SetJustifyH("RIGHT")
                r.track = r:CreateTexture(nil, "BACKGROUND"); r.track:SetHeight(6)
                r.track:SetPoint("TOPLEFT", 14, -17); r.track:SetPoint("TOPRIGHT", 0, -17)
                r.fill = r:CreateTexture(nil, "ARTWORK"); r.fill:SetHeight(6); r.fill:SetPoint("TOPLEFT", r.track, "TOPLEFT")
                col.rows[k0] = r
            end
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:SetPoint("RIGHT", col, "RIGHT", 0, 0)
            local c = it[3] or C.muted
            r.dot:SetVertexColor(c[1], c[2], c[3], 1)
            r.name:SetText(it[1])
            local pct = total > 0 and math.floor(it[2] / total * 100 + 0.5) or 0
            r.val:SetText(WK:FormatMoney(it[2]) .. "  " .. UI:Hex(C.dim) .. pct .. " %|r")
            r.track:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
            r.fill:SetColorTexture(c[1], c[2], c[3], 0.9)
            local w = math.max(1, (col:GetWidth() - 14) * (total > 0 and it[2] / total or 0))
            r.fill:SetWidth(w)
            r:Show()
            y = y + 34
        end
        col.used = k0
        return y
    end,
    RefreshSpend = function(self)
        local list = moneyEntries(self.sDays, false)
        local spentBy, gainBy, byChar = {}, {}, {}
        local spent, gain = 0, 0
        for _, e in ipairs(list) do
            local s = e.s or "Autre"
            if e.d < 0 then spentBy[s] = (spentBy[s] or 0) - e.d; spent = spent - e.d
            else gainBy[s] = (gainBy[s] or 0) + e.d; gain = gain + e.d end
            byChar[e.c] = (byChar[e.c] or 0) + e.d
        end
        self.sSum:SetText(string.format(WK.T("Dépensé %s · gagné %s · total %s"), WK:FormatMoney(spent), WK:FormatMoney(gain), signedMoney(gain - spent)))
        local function sorted(t)
            local out = {}
            for k, v in pairs(t) do table.insert(out, { WK.T(k), v, causeColor(k) }) end
            table.sort(out, function(a, b) return a[2] > b[2] end)
            return out
        end
        for _, col in ipairs({ self.sLeft, self.sRight }) do
            col.used = 0
            for _, r in ipairs(col.rows) do r:Hide() end
        end
        self:Bars(self.sLeft, sorted(spentBy), 20, spent)
        local y = self:Bars(self.sRight, sorted(gainBy), 20, gain)
        -- par perso : ce que chacun a gagné ou perdu (barres à la couleur de sa classe, sur la valeur absolue)
        if next(byChar) then
            self.sRight.charTitle = self.sRight.charTitle or UI:Text(self.sRight, 10, C.dim)
            local t = self.sRight.charTitle
            t:ClearAllPoints(); t:SetPoint("TOPLEFT", 0, -(y + 10)); t:SetText(UI:Upper(WK.T("Par perso (total)"))); t:Show()
            local items, tot = {}, 0
            for ck, v in pairs(byChar) do
                local c = WK.DB.global.characters[ck]
                local r, g, b = UI:ClassColor(c and c.class)
                table.insert(items, { WK:CharName(c, ck) .. "  " .. signedMoney(v), math.abs(v), { r, g, b } })
                tot = tot + math.abs(v)
            end
            table.sort(items, function(a, b) return a[2] > b[2] end)
            self:Bars(self.sRight, items, y + 30, tot)
        elseif self.sRight.charTitle then self.sRight.charTitle:Hide() end
        self.sEmpty:SetShown(#list == 0)
        self.sLeft:SetShown(#list > 0); self.sRight:SetShown(#list > 0)
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
        self.jCard:SetShown(view == "journal")
        self.sCard:SetShown(view == "spend")
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
