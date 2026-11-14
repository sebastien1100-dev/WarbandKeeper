local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors

local LEFT_W = 230
local GAP = 12
local RANGES = { { 7, "7 j" }, { 30, "30 j" }, { 90, "90 j" }, { 365, "1 an" } }

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

        -- Liste des séries ---------------------------------------------------
        local list = UI:Card(p, "Séries")
        list:SetSize(LEFT_W, UI.PAGE_H)
        list:SetPoint("TOPLEFT")
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
            b.del = UI:IconButton(b, "trash", 22, "Ne plus suivre", true)
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
        local chartW = UI.PAGE_W - LEFT_W - GAP
        local card = UI:Card(p)
        card:SetSize(chartW, UI.PAGE_H)
        card:SetPoint("TOPRIGHT")
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
        for i = 1, 60 do
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
            return self.series == "gold" and WK:FormatMoney(pt.v) or ("x" .. pt.v)
        end)
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
        local r, g, b = UI:Accent()
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
                e.del:SetShown(tracked[key] == "manual")
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
        local cur, target, ratio, gdays = G:Progress(key)
        self.goalDel:SetShown(goal ~= nil)
        self.goalBtn:SetLabel(goal and WK.T("Modifier") or WK.T("Définir"))
        if goal then
            local fmt = isGold and UI:ShortGold(target) or tostring(target)
            local txt = string.format(WK.T("objectif %s · %d %%"), fmt, math.floor(ratio * 100))
            if ratio >= 1 then txt = txt .. " · " .. WK.T("atteint !")
            elseif gdays then txt = txt .. " · " .. string.format(WK.T("dans ~%d j"), gdays) end
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
                lg.text:SetText(string.format("%s %d", c and c.name or ck, series[ck][n]))
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
