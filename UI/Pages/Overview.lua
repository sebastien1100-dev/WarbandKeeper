local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors

local LEFT_W = 276
local TOP_H = 232
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

-- Tuile chiffre-clé (libellé + valeur) avec liseré doré.
local function Tile(parent, label)
    local t = UI:Card(parent, nil, nil, true)
    t.label = UI:Text(t, 11, C.muted)
    t.label:SetPoint("TOPLEFT", 12, -10)
    t.label:SetText(label)
    t.value = UI:Text(t, 15)
    t.value:SetPoint("BOTTOMLEFT", 12, 10)
    t.value:SetPoint("BOTTOMRIGHT", -8, 10)
    return t
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

        -- Bloc de gauche : or total + chiffres clés ---------------------------------
        local k = UI:Text(p, 11, C.dim)
        k:SetPoint("TOPLEFT", 2, -2)
        k:SetText("OR DU COMPTE")
        self.total = UI:Text(p, 30)
        self.total:SetPoint("TOPLEFT", 0, -22)
        self.po = UI:Text(p, 18)
        self.po:SetPoint("BOTTOMLEFT", self.total, "BOTTOMRIGHT", 6, 2)
        self.po:SetText(WK.T("po"))
        UI:OnAccent(function() self.po:SetTextColor(UI:Accent()) end)
        self.delta = UI:Badge(p, "", C.positive)
        self.delta:SetPoint("TOPLEFT", 0, -66)
        self.deltaLabel = UI:Text(p, 11, C.muted)
        self.deltaLabel:SetPoint("LEFT", self.delta, "RIGHT", 8, 0)
        self.stock = UI:Text(p, 11, C.muted)
        self.stock:SetPoint("TOPLEFT", 2, -88)
        self.stock:SetWidth(LEFT_W)

        local tw = (LEFT_W - 10) / 2
        self.tiles = {}
        local labels = { "Personnages", "Temps de jeu", "Règles courrier", "À envoyer" }
        for i, l in ipairs(labels) do
            local t = Tile(p, l)
            t:SetSize(tw, 58)
            t:SetPoint("TOPLEFT", ((i - 1) % 2) * (tw + 10), -106 - math.floor((i - 1) / 2) * 68)
            self.tiles[i] = t
        end
        self.tiles[3]:EnableMouse(true)
        self.tiles[3]:SetScript("OnMouseUp", function() UI:ShowPage("mail") end)

        -- Courbe d'évolution -----------------------------------------------------------
        local card = UI:Card(p, nil, nil, true)
        card:SetPoint("TOPLEFT", LEFT_W + GAP, 0)
        card:SetSize(UI.PAGE_W - LEFT_W - GAP, TOP_H)
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
        tableBox:SetPoint("BOTTOMRIGHT")
        for _, col in ipairs(COLS) do
            local t = UI:Text(tableBox, 10, C.dim)
            if col[3] == "RIGHT" then
                t:SetPoint("TOPRIGHT", tableBox, "TOPLEFT", col[2] + 12, 0)
                t:SetJustifyH("RIGHT")
            else
                t:SetPoint("TOPLEFT", col[2], 0)
            end
            t:SetText(UI:Upper(WK.T(col[1])))
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
            r.icon:SetPoint("LEFT", COLS[1][2], 0)
            r.name = UI:Text(r, 13)
            r.name:SetPoint("LEFT", r.icon, "RIGHT", 10, 0)
            r.here = UI:Badge(r, "ici")
            r.here:SetPoint("LEFT", r.name, "RIGHT", 8, 0)
            r.level = UI:Text(r, 12)
            r.level:SetPoint("LEFT", COLS[2][2], 0)
            r.gold = UI:Text(r, 12)
            r.gold:SetPoint("RIGHT", r, "LEFT", COLS[3][2] + 12, 0)
            r.gold:SetJustifyH("RIGHT")
            r.diff = UI:Text(r, 12)
            r.diff:SetPoint("RIGHT", r, "LEFT", COLS[4][2] + 12, 0)
            r.diff:SetJustifyH("RIGHT")
            r.spark = UI:LineChart(r, 1.5, false)
            r.spark:SetSize(84, 18)
            r.spark:SetPoint("LEFT", COLS[5][2], 0)
            r.bags = UI:Text(r, 12, C.muted)
            r.bags:SetPoint("LEFT", COLS[6][2], 0)
            r.seen = UI:Text(r, 12, C.muted)
            r.seen:SetPoint("LEFT", COLS[7][2], 0)
            return r
        end)
    end,

    Refresh = function(self)
        local S = WK.modules.Statistics
        local now = time()
        local chars = UI:SortedCharacters()

        -- Chiffres clés
        local gold, played = 0, 0
        for _, e in ipairs(chars) do
            gold = gold + (e.c.money or 0)
            played = played + (e.c.played or 0)
        end
        self.total:SetText(plainGold(gold))
        local diff = S:AccountGoldAt(now) - S:AccountGoldAt(now - 7 * 86400)
        self.delta:Set((diff >= 0 and "+" or "") .. UI:ShortGold(diff), diff >= 0 and C.positive or C.negative)
        self.deltaLabel:SetText("sur 7 jours")
        local V = WK.modules.Value
        self.stock:SetText(string.format(WK.T("+ %s de stocks (%s)"), UI:GoldText(V:StockValue()), V:SourceLabel()))

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
            elseif e.days then g.eta:SetText(string.format(WK.T("dans ~%d j"), e.days))
            else g.eta:SetText("") end
        end
        self.tableBox:ClearAllPoints()
        self.tableBox:SetPoint("TOPLEFT", 0, -(TOP_H + GAP + 4) - (shown > 0 and (GOAL_H + 12) or 0))
        self.tableBox:SetPoint("BOTTOMRIGHT")
        local rules = 0
        for _ in pairs(WK.DB.global.mail.rules) do rules = rules + 1 end
        for _ in pairs(WK.DB.global.mail.cats) do rules = rules + 1 end
        self.tiles[1].value:SetText(tostring(#chars))
        self.tiles[2].value:SetText(WK:FormatTime(played))
        self.tiles[3].value:SetText(tostring(rules))
        self.tiles[4].value:SetText(tostring(WK.modules.Mail:PendingCount()))

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
            UI:SetClassIcon(r.icon, c.class)
            r.name:SetText(c.name or e.key)
            r.name:SetTextColor(UI:ClassColor(c.class))
            r.here:SetShown(isMe)
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
