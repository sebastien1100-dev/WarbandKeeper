local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

local GAP = 12
local TOP = -46
local MAX_RECIPES = 150

local function colored(key)
    local c = WK.DB.global.characters[key]
    local name = c and c.name or key:match("^[^%-]+")
    local r, g, b = UI:ClassColor(c and c.class)
    return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, name)
end

---------------------------------------------------------------------------
-- Onglet Niveaux : une carte par personnage.
---------------------------------------------------------------------------
local function Levels(parent)
    local tab = {}
    local scroll = UI:Scroll(parent)
    scroll:SetPoint("TOPLEFT", 0, TOP)
    scroll:SetPoint("BOTTOMRIGHT")
    local colW = (UI.PAGE_W - 12 - GAP) / 2
    local cards = UI:Pool(function()
        local card = UI:Card(scroll.child, " ")
        card:SetWidth(colW)
        card.icon = UI:RoundIcon(card, 20)
        card.icon:SetPoint("TOPLEFT", 14, -12)
        card.title:ClearAllPoints()
        card.title:SetPoint("LEFT", card.icon, "RIGHT", 8, 0)
        card.recipes = UI:Text(card, 11, C.muted)
        card.recipes:SetPoint("TOPRIGHT", -16, -16)
        card.recipes:SetJustifyH("RIGHT")
        card.empty = UI:Text(card, 11, C.dim)
        card.empty:SetPoint("TOPLEFT", 16, -46)
        card.empty:SetText("Aucun métier enregistré")
        card.lines = {}
        return card
    end)

    function tab:Refresh()
        cards:Reset()
        local colY = { 0, 0 }
        for _, e in ipairs(UI:SortedCharacters()) do
            local card = cards:Get()
            local c = e.c
            UI:SetClassIcon(card.icon, c.class)
            card.title:SetText(c.name or e.key)
            card.title:SetTextColor(UI:ClassColor(c.class))
            local nr = 0
            for _ in pairs(c.recipes or {}) do nr = nr + 1 end
            card.recipes:SetText(nr > 0 and string.format(T("%d recettes"), nr) or "")

            local names = {}
            for name in pairs(c.professions or {}) do table.insert(names, name) end
            table.sort(names)
            for _, l in ipairs(card.lines) do l:Hide() end
            for i, name in ipairs(names) do
                local l = card.lines[i]
                if not l then
                    l = CreateFrame("Frame", nil, card)
                    l:SetHeight(30)
                    l.name = UI:Text(l, 12)
                    l.name:SetPoint("TOPLEFT")
                    l.rank = UI:Text(l, 11, C.muted)
                    l.rank:SetPoint("TOPRIGHT")
                    l.rank:SetJustifyH("RIGHT")
                    l.bar = UI:Progress(l, 6)
                    l.bar:SetPoint("BOTTOMLEFT", 0, 2)
                    l.bar:SetPoint("BOTTOMRIGHT", 0, 2)
                    card.lines[i] = l
                end
                local pr = c.professions[name]
                l:ClearAllPoints()
                l:SetPoint("TOPLEFT", 16, -44 - (i - 1) * 38)
                l:SetPoint("TOPRIGHT", -16, -44 - (i - 1) * 38)
                l.name:SetText(name)
                l.rank:SetText(string.format("%d / %d", pr.rank or 0, pr.max or 0))
                l.bar:SetValue((pr.max or 0) > 0 and (pr.rank or 0) / pr.max or 0)
                l:Show()
            end
            card.empty:SetShown(#names == 0)
            local h = 52 + math.max(1, #names) * 38 - (#names == 0 and 14 or 0)
            card:SetHeight(h)
            local col = colY[1] <= colY[2] and 1 or 2
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", (col - 1) * (colW + GAP), -colY[col])
            colY[col] = colY[col] + h + GAP
        end
        scroll:SetContentHeight(math.max(colY[1], colY[2]))
    end
    return tab
end

---------------------------------------------------------------------------
-- Onglet Recettes : qui peut fabriquer quoi, et combien avec le stock du compte.
---------------------------------------------------------------------------
local function Recipes(page, parent)
    local tab = { query = "", sort = "name" }
    local search = UI:Input(parent, 300, 34, "Rechercher une recette ou un objet...", "search")
    search:SetPoint("TOPLEFT", 0, TOP)
    search.onChange = function(t) tab.query = string.lower(t or ""); tab:Refresh() end
    local sortSeg = UI:Segmented(parent, { { "name", "Nom" }, { "profit", "Bénéfice" }, { "craftable", "Possibles" } },
        function(k) tab.sort = k; tab:Refresh() end, 34)
    sortSeg:SetPoint("TOPRIGHT", 0, TOP)
    sortSeg:Select("name")
    local sortLbl = UI:Text(parent, 11, C.muted)
    sortLbl:SetPoint("RIGHT", sortSeg, "LEFT", -10, 0)
    sortLbl:SetText("Trier :")
    local info = UI:Text(parent, 11, C.muted)
    info:SetPoint("LEFT", search, "RIGHT", 14, 0)
    local scroll = UI:Scroll(parent)
    scroll:SetPoint("TOPLEFT", 0, TOP - 46)
    scroll:SetPoint("BOTTOMRIGHT")
    local empty = UI:Text(parent, 12, C.muted)
    empty:SetPoint("CENTER", scroll, "CENTER")

    local rows = UI:Pool(function()
        local r = CreateFrame("Button", nil, scroll.child)
        r:SetHeight(46)
        UI:Panel(r, 12, C.surface, C.border)
        r.icon = UI:RoundIcon(r, 28)
        r.icon:SetPoint("LEFT", 12, 0)
        r.name = UI:Text(r, 12)
        r.name:SetPoint("TOPLEFT", 52, -9)
        r.name:SetPoint("TOPRIGHT", -240, -9)
        r.who = UI:Text(r, 10, C.muted)
        r.who:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -4)
        r.who:SetPoint("TOPRIGHT", r.name, "BOTTOMRIGHT", 0, -4)
        r.profit = UI:Text(r, 13)
        r.profit:SetPoint("TOPRIGHT", -50, -8)
        r.profit:SetJustifyH("RIGHT")
        r.eco = UI:Text(r, 10, C.muted)
        r.eco:SetPoint("TOPRIGHT", r.profit, "BOTTOMRIGHT", 0, -4)
        r.eco:SetJustifyH("RIGHT")
        r.add = UI:IconButton(r, "plus", 28, "Ajouter à la liste de courses")
        r.add:SetPoint("RIGHT", -10, 0)
        r.add:SetScript("OnClick", function(b) WK.modules.Recipes:AddToList(b.recipeKey, 1); page:Refresh() end)
        r:SetScript("OnEnter", function(row)
            row.bg:SetColor(unpack(C.surface2))
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            GameTooltip:SetText(row.rec.name, 1, 1, 1)
            local cost, sale, profit = WK.modules.Recipes:Economics(row.rec)
            GameTooltip:AddDoubleLine(WK.T("Coût des composants"), WK:FormatMoney(cost), 0.7, 0.7, 0.7, 1, 1, 1)
            if sale then
                GameTooltip:AddDoubleLine(WK.T("Prix de vente"), WK:FormatMoney(sale), 0.7, 0.7, 0.7, 1, 1, 1)
                GameTooltip:AddDoubleLine(WK.T("Bénéfice"), WK:FormatMoney(profit), 0.7, 0.7, 0.7,
                    profit >= 0 and 0.6 or 1, profit >= 0 and 1 or 0.4, profit >= 0 and 0.5 or 0.4)
            end
            GameTooltip:AddLine(" ")
            for _, rg in ipairs(row.rec.reagents or {}) do
                local have = WK.modules.Inventory:AccountCount(rg[1])
                local ok = have >= rg[2]
                GameTooltip:AddDoubleLine((UI:ItemInfo(rg[1])), string.format("%d / %d", have, rg[2]),
                    0.85, 0.85, 0.85, ok and 0.6 or 1, ok and 1 or 0.4, ok and 0.5 or 0.4)
            end
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function(row) row.bg:SetColor(unpack(C.surface)); GameTooltip:Hide() end)
        return r
    end)

    function tab:Refresh()
        local all = WK.modules.Recipes:All()
        local list = {}
        for _, rec in ipairs(all) do
            local outName = rec.out and UI:ItemInfo(rec.out) or ""
            if self.query == "" or string.find(string.lower(rec.name), self.query, 1, true)
                or string.find(string.lower(outName), self.query, 1, true) then
                table.insert(list, rec)
            end
        end
        -- Tri : nom, bénéfice (inconnus à la fin) ou nombre de fabrications possibles.
        local R = WK.modules.Recipes
        local eco = {}
        for _, rec in ipairs(list) do
            local cost, sale, profit = R:Economics(rec)
            eco[rec] = { cost = cost, sale = sale, profit = profit, can = R:Craftable(rec) or 0 }
        end
        if self.sort == "profit" then
            table.sort(list, function(a, b)
                local pa, pb = eco[a].profit, eco[b].profit
                if (pa == nil) ~= (pb == nil) then return pa ~= nil end
                if pa and pa ~= pb then return pa > pb end
                return a.name < b.name
            end)
        elseif self.sort == "craftable" then
            table.sort(list, function(a, b)
                if eco[a].can ~= eco[b].can then return eco[a].can > eco[b].can end
                return a.name < b.name
            end)
        end

        rows:Reset()
        local y = 0
        for i, rec in ipairs(list) do
            if i > MAX_RECIPES then break end
            local r = rows:Get()
            r.rec = rec
            r.add.recipeKey = rec.key
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -y)
            r:SetPoint("TOPRIGHT", 0, -y)
            local icon, qr, qg, qb = rec.icon, 1, 1, 1
            if rec.out then
                local _, oicon, r1, g1, b1 = UI:ItemInfo(rec.out)
                icon = icon or oicon
                qr, qg, qb = r1, g1, b1
            end
            r.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            r.name:SetText(rec.name)
            r.name:SetTextColor(qr, qg, qb)
            local who = {}
            for _, k in ipairs(rec.crafters) do table.insert(who, colored(k)) end
            local e = eco[rec]
            local canTxt = e.can > 0 and (UI:Hex(C.positive) .. string.format(T("x%d possibles"), e.can) .. "|r")
                or T("composants manquants")
            r.who:SetText((rec.prof and (rec.prof .. "  ·  ") or "") .. table.concat(who, ", ") .. "  ·  " .. canTxt)
            if e.profit then
                if e.profit >= 0 then
                    r.profit:SetText("+" .. UI:GoldText(e.profit))
                else
                    r.profit:SetText(UI:Hex(C.negative) .. UI:PlainMoney(e.profit) .. "|r")
                end
                r.eco:SetText(string.format(T("coût %s · vente %s"), UI:PlainMoney(e.cost), UI:PlainMoney(e.sale)))
            else
                r.profit:SetText(UI:Hex(C.dim) .. "-|r")
                r.eco:SetText(string.format(T("coût %s · pas de prix de vente"), UI:PlainMoney(e.cost)))
            end
            y = y + 52
        end
        scroll:SetContentHeight(y)
        empty:SetShown(#list == 0)
        empty:SetText(#all == 0 and T("Ouvre la fenêtre de chaque métier une fois pour enregistrer ses recettes.")
            or T("Aucune recette ne correspond à la recherche."))
        info:SetText(string.format(T("%d recettes"), #list))
    end
    return tab
end

---------------------------------------------------------------------------
-- Onglet Liste de courses : fabrications prévues -> composants manquants et coût.
---------------------------------------------------------------------------
local function Shopping(page, parent)
    local tab = {}
    local leftW = math.floor(UI.PAGE_W * 0.38)
    local h = UI.PAGE_H + TOP

    local planned = UI:Card(parent, "Fabrications prévues")
    planned:SetSize(leftW, h)
    planned:SetPoint("TOPLEFT", 0, TOP)
    local pEmpty = UI:Text(planned, 11, C.muted)
    pEmpty:SetPoint("TOPLEFT", 16, -46)
    pEmpty:SetPoint("TOPRIGHT", -16, -46)
    if pEmpty.SetWordWrap then pEmpty:SetWordWrap(true) end
    pEmpty:SetJustifyV("TOP")
    pEmpty:SetText("Ajoute des recettes depuis l'onglet Recettes (bouton +).")
    local ps = UI:Scroll(planned)
    ps:SetPoint("TOPLEFT", 10, -40)
    ps:SetPoint("BOTTOMRIGHT", -8, 52)
    local clear = UI:Button(planned, "Vider la liste", nil, 28, "ghost", "trash")
    clear:SetPoint("BOTTOMLEFT", 12, 12)
    clear:SetScript("OnClick", function() WK.modules.Recipes:ClearList(); page:Refresh() end)

    local pRows = UI:Pool(function()
        local r = CreateFrame("Frame", nil, ps.child)
        r:SetHeight(40)
        r.bg = UI:Rounded(r, 10, 0, "BACKGROUND", 1)
        r.bg:SetColor(unpack(C.surface2))
        r.icon = UI:RoundIcon(r, 22)
        r.icon:SetPoint("LEFT", 8, 0)
        r.name = UI:Text(r, 12)
        r.name:SetPoint("LEFT", 38, 0)
        r.name:SetPoint("RIGHT", -100, 0)
        r.plus = UI:IconButton(r, "plus", 24, "Une fabrication de plus")
        r.plus:SetPoint("RIGHT", -6, 0)
        r.qty = UI:Text(r, 13)
        r.qty:SetPoint("RIGHT", r.plus, "LEFT", -6, 0)
        r.qty:SetJustifyH("RIGHT")
        r.minus = UI:IconButton(r, "minus", 24, "Une fabrication de moins")
        r.minus:SetPoint("RIGHT", r.qty, "LEFT", -6, 0)
        r.plus:SetScript("OnClick", function(b) WK.modules.Recipes:AddToList(b.recipeKey, 1); page:Refresh() end)
        r.minus:SetScript("OnClick", function(b) WK.modules.Recipes:AddToList(b.recipeKey, -1); page:Refresh() end)
        return r
    end)

    local need = UI:Card(parent, "Composants")
    need:SetSize(UI.PAGE_W - leftW - GAP, h)
    need:SetPoint("TOPRIGHT", 0, TOP)
    local cols = { { "Besoin", -250 }, { "Possédé", -180 }, { "Manquant", -110 }, { "Coût", -16 } }
    for _, col in ipairs(cols) do
        local t = UI:Text(need, 10, C.dim)
        t:SetPoint("TOPRIGHT", col[2], -18)
        t:SetJustifyH("RIGHT")
        t:SetText(UI:Upper(T(col[1])))
    end
    local ns = UI:Scroll(need)
    ns:SetPoint("TOPLEFT", 10, -40)
    ns:SetPoint("BOTTOMRIGHT", -8, 52)
    local nEmpty = UI:Text(need, 12, C.muted)
    nEmpty:SetPoint("CENTER", ns, "CENTER")
    nEmpty:SetText("Rien à fabriquer pour l'instant.")
    local total = UI:Text(need, 13)
    total:SetPoint("BOTTOMLEFT", 16, 20)
    local export = UI:Button(need, "Créer la liste Auctionator", nil, 30, "primary", "plus")
    export:SetPoint("BOTTOMRIGHT", -12, 12)
    export:SetScript("OnClick", function() WK.modules.Recipes:ExportToAuctionator() end)
    export.tooltip = "Crée une liste de courses « Warband Keeper » dans Auctionator avec les composants manquants."

    local nRows = UI:Pool(function()
        local r = CreateFrame("Frame", nil, ns.child)
        r:SetHeight(34)
        r.bg = UI:Rounded(r, 9, 0, "BACKGROUND", 1)
        r.bg:SetColor(unpack(C.surface2))
        r.icon = UI:RoundIcon(r, 20)
        r.icon:SetPoint("LEFT", 8, 0)
        r.name = UI:Text(r, 12)
        r.name:SetPoint("LEFT", 34, 0)
        r.name:SetPoint("RIGHT", -270, 0)
        r.cells = {}
        for i, col in ipairs(cols) do
            local t = UI:Text(r, 12)
            t:SetPoint("RIGHT", col[2] + 8, 0)
            t:SetJustifyH("RIGHT")
            r.cells[i] = t
        end
        return r
    end)

    function tab:Refresh()
        local _, index = WK.modules.Recipes:All()
        pRows:Reset()
        local y = 0
        local keys = {}
        for k in pairs(WK.DB.global.shopping) do table.insert(keys, k) end
        table.sort(keys)
        for _, k in ipairs(keys) do
            local rec = index[k]
            local r = pRows:Get()
            r.plus.recipeKey, r.minus.recipeKey = k, k
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -y)
            r:SetPoint("TOPRIGHT", 0, -y)
            local icon = rec and rec.icon or (rec and rec.out and select(2, UI:ItemInfo(rec.out)))
            r.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            r.name:SetText(rec and rec.name or k)
            r.qty:SetText("x" .. WK.DB.global.shopping[k])
            y = y + 46
        end
        ps:SetContentHeight(y)
        pEmpty:SetShown(#keys == 0)

        local needs, cost = WK.modules.Recipes:Needs()
        nRows:Reset()
        y = 0
        for _, e in ipairs(needs) do
            local r = nRows:Get()
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -y)
            r:SetPoint("TOPRIGHT", 0, -y)
            local name, icon, qr, qg, qb = UI:ItemInfo(e.itemID)
            r.icon:SetTexture(icon)
            r.name:SetText(name)
            r.name:SetTextColor(qr, qg, qb)
            r.cells[1]:SetText(tostring(e.need))
            r.cells[2]:SetText(tostring(e.have))
            r.cells[3]:SetText(e.missing > 0 and tostring(e.missing) or "-")
            r.cells[3]:SetTextColor(unpack(e.missing > 0 and C.negative or C.positive))
            r.cells[4]:SetText(e.cost > 0 and UI:GoldText(e.cost) or "")
            y = y + 40
        end
        ns:SetContentHeight(y)
        nEmpty:SetShown(#needs == 0)
        total:SetText(string.format(T("Coût des composants manquants : %s"), UI:GoldText(cost)))
        local hasAH = Auctionator and Auctionator.API and Auctionator.API.v1 and Auctionator.API.v1.CreateShoppingList
        export:SetShown(hasAH and #needs > 0)
    end
    return tab
end

UI:RegisterPage({
    key = "professions", order = 4, nav = "Métiers",
    title = "Métiers",
    subtitle = "Niveaux, recettes connues par perso et liste de courses des composants.",

    Build = function(self, p)
        self.tab = "levels"
        local frames, tabs = {}, {}
        for _, k in ipairs({ "levels", "recipes", "shopping" }) do
            local f = CreateFrame("Frame", nil, p)
            f:SetAllPoints()
            f:SetShown(k == "levels")
            frames[k] = f
        end
        tabs.levels = Levels(frames.levels)
        tabs.recipes = Recipes(self, frames.recipes)
        tabs.shopping = Shopping(self, frames.shopping)
        self.tabs = tabs
        local function setTab(k)
            self.tab = k
            for key, f in pairs(frames) do f:SetShown(key == k) end
            self:Refresh()
        end
        local seg = UI:Segmented(p, { { "levels", "Niveaux" }, { "recipes", "Recettes" }, { "shopping", "Liste de courses" } }, setTab, 32)
        seg:SetPoint("TOPLEFT")
        seg:Select("levels")
        function self:SetTab(k) seg:Select(k); setTab(k) end
    end,

    Refresh = function(self)
        self.tabs[self.tab]:Refresh()
    end,
})
