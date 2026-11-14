local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

local GAP = 12
local TOP = -46
local MAX_RECIPES = 150

-- Nom et icône d'une étape de guide : l'objet fabriqué, sinon la recette (enchantements).
local function stepInfo(st)
    if st.out then
        local name, icon, r, g, b = UI:ItemInfo(st.out)
        if name and name ~= "" then return name, icon, r, g, b end
    end
    local name, icon = WK.SpellInfo(st.spell)
    return name or "?", icon, 1, 1, 1
end

local function colored(key)
    local c = WK.DB.global.characters[key]
    local name = WK:CharName(c, key)
    local r, g, b = UI:ClassColor(c and c.class)
    return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, name)
end

-- Infobulle d'une recette : coût, vente, bénéfice et composants possédés sur le compte.
local function recipeTooltip(row)
    WK.UI:TooltipOwner(row, "ANCHOR_RIGHT")
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
end

---------------------------------------------------------------------------
-- Onglet Niveaux : une carte par personnage.
---------------------------------------------------------------------------
local function Levels(page, parent)
    local tab = {}
    local scroll = UI:Scroll(parent)
    scroll:SetPoint("TOPLEFT", 0, TOP)
    scroll:SetPoint("BOTTOMRIGHT")
    local TILE_H, TILE_MIN = 74, 230

    -- Ligne d'état d'une tuile : ce qu'il y a à faire ensuite pour ce métier.
    local function status(c, key, prof, pr)
        local rank, max = pr.rank or 0, pr.max or 0
        local G, R = WK.modules.Gathering, WK.modules.Recipes
        local kind = G:Kind(prof)
        if max > 0 and max < 300 and rank >= max and not kind and prof ~= "Pêche" and prof ~= "Fishing" then
            return T("Plafond atteint : va voir le maître"), true
        end
        if kind then
            local rows = G:Rows(prof, rank)
            local best = G:BestZones(rows)
            local res
            for _, d in ipairs(rows) do if d.good then res = d; break end end
            local zone = best[1] and T(best[1]) or nil
            if kind == "skin" then
                return string.format(T("Monstres jusqu'au niv. %d"), G:SkinMaxLevel(rank)) .. (zone and ("  ·  " .. zone) or "")
            end
            if res then return ((UI:ItemInfo(res.id)) or "?") .. (zone and ("  ·  " .. zone) or "") end
            return ""
        end
        if R:Guide(prof) then
            local steps = R:GuidePlan(prof, rank, R:KnownOutputs(c))
            for _, e in ipairs(steps or {}) do
                if e.status == "current" or (e.status == "todo" and rank < e.step.from) then
                    return string.format(T("Guide : %d-%d  ·  %d %s"), e.step.from, e.step.to,
                        e.status == "current" and e.left or e.step.crafts, (stepInfo(e.step)))
                end
            end
            return T("Guide terminé")
        end
        local n = 0
        for _, r in pairs(c.recipes or {}) do if r.prof == prof then n = n + 1 end end
        return n > 0 and string.format(n > 1 and T("%d recettes") or T("%d recette"), n) or ""
    end

    local cards = UI:Pool(function()
        local card = UI:Card(scroll.child, " ")
        card.icon = UI:RoundIcon(card, 22)
        card.icon:SetPoint("TOPLEFT", 14, -11)
        card.title:ClearAllPoints()
        card.title:SetPoint("LEFT", card.icon, "RIGHT", 8, 0)
        card.recipes = UI:Text(card, 11, C.muted)
        card.recipes:SetPoint("TOPRIGHT", -16, -16)
        card.recipes:SetJustifyH("RIGHT")
        card.empty = UI:Text(card, 11, C.dim)
        card.empty:SetPoint("TOPLEFT", 16, -46)
        card.empty:SetText("Aucun métier enregistré")
        card.tiles = UI:Pool(function()
            local t = CreateFrame("Button", nil, card)
            t:SetHeight(TILE_H)
            UI:Panel(t, 10, C.surface2, C.border)
            t.icon = UI:RoundIcon(t, 20)
            t.icon:SetPoint("TOPLEFT", 10, -9)
            t.rank = UI:Text(t, 11, C.muted)
            t.rank:SetPoint("TOPRIGHT", -12, -12)
            t.rank:SetJustifyH("RIGHT")
            t.name = UI:Text(t, 12)
            t.name:SetPoint("TOPLEFT", 36, -11)
            t.name:SetPoint("TOPRIGHT", -80, -11)
            t.bar = UI:Progress(t, 6)
            t.bar:SetPoint("TOPLEFT", 12, -38)
            t.bar:SetPoint("TOPRIGHT", -12, -38)
            t.bar.track:SetColor(unpack(C.hover)) -- visible sur le fond de la tuile
            -- séparations des rangs (75, 150, 225) au-dessus du remplissage
            local holder = CreateFrame("Frame", nil, t.bar)
            holder:SetAllPoints()
            holder:SetFrameLevel(t.bar:GetFrameLevel() + 5)
            t.ticks = {}
            for i = 1, 3 do
                local tk = holder:CreateTexture(nil, "OVERLAY")
                tk:SetSize(2, 10)
                t.ticks[i] = tk
            end
            t.state = UI:Text(t, 10, C.muted)
            t.state:SetPoint("BOTTOMLEFT", 12, 10)
            t.state:SetPoint("BOTTOMRIGHT", -12, 10)
            t.state:SetJustifyH("LEFT")
            t:SetScript("OnClick", function(s) page:ShowDetail(s.charKey, s.prof) end)
            t:SetScript("OnEnter", function(s)
                if not s.warn then s.border:SetColor(UI:Accent()) end
                WK.UI:TooltipOwner(s, "ANCHOR_TOP")
                GameTooltip:SetText(WK.T("Clic : recettes et détail du métier"), 1, 1, 1)
                GameTooltip:Show()
            end)
            t:SetScript("OnLeave", function(s)
                s.border:SetColor(unpack(s.warn and C.warning or C.border))
                GameTooltip:Hide()
            end)
            return t
        end)
        return card
    end)

    function tab:Refresh()
        cards:Reset()
        local w = (UI.PAGE_W or 840) - 12
        local perRow = math.max(2, math.min(5, math.floor((w - 32 + 8) / (TILE_MIN + 8))))
        local tw = (w - 32 - (perRow - 1) * 8) / perRow
        local y = 0
        for _, e in ipairs(UI:SortedCharacters()) do
            local card = cards:Get()
            local c = e.c
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", 0, -y)
            card:SetPoint("TOPRIGHT", 0, -y)
            UI:SetCharIcon(card.icon, c, e.key)
            card.title:SetText(WK:CharName(c, e.key))
            card.title:SetTextColor(UI:ClassColor(c.class))
            local nr = 0
            for _ in pairs(c.recipes or {}) do nr = nr + 1 end
            card.recipes:SetText(nr > 0 and string.format(T("%d recettes"), nr) or "")

            local names = {}
            for name in pairs(c.professions or {}) do table.insert(names, name) end
            table.sort(names)
            card.tiles:Reset()
            for i, name in ipairs(names) do
                local pr = c.professions[name]
                local t = card.tiles:Get()
                t.charKey, t.prof = e.key, name
                t:SetWidth(tw)
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", 16 + ((i - 1) % perRow) * (tw + 8), -44 - math.floor((i - 1) / perRow) * (TILE_H + 8))
                if pr.icon then t.icon:SetTexture(pr.icon) else t.icon:SetTexture(UI.MEDIA .. "hammer") end
                t.name:SetText(name)
                t.rank:SetText(string.format("%d / %d", pr.rank or 0, pr.max or 0))
                t.bar:SetValue(math.min(pr.rank or 0, 300) / 300)
                local bw = tw - 24
                for k = 1, 3 do
                    t.ticks[k]:ClearAllPoints()
                    t.ticks[k]:SetPoint("CENTER", t.bar, "LEFT", bw * k / 4, 0)
                    t.ticks[k]:SetColorTexture(unpack(C.surface2))
                end
                local txt, warn = status(c, e.key, name, pr)
                t.warn = warn
                t.state:SetText(txt or "")
                t.state:SetTextColor(unpack(warn and C.warning or C.muted))
                t.border:SetColor(unpack(warn and C.warning or C.border))
            end
            card.empty:SetShown(#names == 0)
            local rowsN = math.max(1, math.ceil(#names / perRow))
            local h = #names == 0 and 72 or (52 + rowsN * (TILE_H + 8))
            card:SetHeight(h)
            y = y + h + GAP
        end
        scroll:SetContentHeight(y)
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
            recipeTooltip(row)
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
    planned:SetWidth(leftW)
    planned:SetPoint("TOPLEFT", 0, TOP)
    planned:SetPoint("BOTTOMLEFT")
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
    need:SetPoint("TOPLEFT", planned, "TOPRIGHT", GAP, 0)
    need:SetPoint("BOTTOMRIGHT")
    UI:OnResize(parent, function(w) planned:SetWidth(math.floor(w * 0.38)) end)
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

---------------------------------------------------------------------------
-- Fiche d'un métier (clic dans l'onglet Niveaux) : recettes d'un perso avec
-- leur couleur, composants du compte, rentabilité, et ouverture du métier.
---------------------------------------------------------------------------
-- Couleurs de difficulté du jeu (comme les couleurs de qualité, elles ne dépendent pas du thème).
local DIFF = {
    optimal = { color = { 1, 0.5, 0.25 }, label = "Orange" },
    medium  = { color = { 1, 0.82, 0 }, label = "Jaune" },
    easy    = { color = { 0.25, 0.75, 0.25 }, label = "Vert" },
    trivial = { color = { 0.55, 0.55, 0.55 }, label = "Gris" },
}

-- Vendeurs d'une recette : « Nom (zone) », les premiers puis « +N ».
local function vendorText(vendors, limit)
    local out = {}
    for i, v in ipairs(vendors or {}) do
        if limit and i > limit then
            table.insert(out, "+" .. (#vendors - limit))
            break
        end
        table.insert(out, v[2] and (v[1] .. " (" .. T(v[2]) .. ")") or v[1])
    end
    return table.concat(out, ", ")
end

-- Remarque de guide : {n:id} = « n Objet », {id} = « Objet » (nom pris dans le jeu).
local function renderNote(note)
    note = T(note)
    note = note:gsub("{(%d+):(%d+)}", function(n, id) return n .. " " .. (UI:ItemInfo(tonumber(id)) or "?") end)
    note = note:gsub("{(%d+)}", function(id) return (UI:ItemInfo(tonumber(id)) or "?") end)
    return note
end

local function Detail(page, parent)
    local tab = { query = "", filter = "all", mode = "recipes" }

    -- En-tête : retour, perso, métier, ouverture, puis la barre des rangs de 1 à 300.
    local HEAD_H = 118
    local head = UI:Card(parent)
    head:SetHeight(HEAD_H)
    head:SetPoint("TOPLEFT", 0, TOP)
    head:SetPoint("TOPRIGHT", 0, TOP)
    local back = UI:Button(head, "Niveaux", 104, 30, "secondary", "back")
    back:SetPoint("TOPLEFT", 14, -16)
    back.tooltip = "Retour à la liste des métiers"
    back:SetScript("OnClick", function() page:ShowDetail(nil) end)
    local icon = UI:RoundIcon(head, 36)
    icon:SetPoint("TOPLEFT", 132, -13)
    local title = UI:Text(head, 16)
    title:SetPoint("TOPLEFT", 180, -14)
    title:SetPoint("TOPRIGHT", -200, -14)
    local sub = UI:Text(head, 11, C.muted)
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    sub:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -4)

    -- Barre des rangs : Apprenti (75), Compagnon (150), Expert (225), Artisan (300).
    local RANKS = { { "Apprenti", 75 }, { "Compagnon", 150 }, { "Expert", 225 }, { "Artisan", 300 } }
    local bar = UI:Progress(head, 8)
    bar:SetPoint("BOTTOMLEFT", 16, 28)
    bar:SetPoint("BOTTOMRIGHT", -16, 28)
    local rankLabels, ticks = {}, {}
    -- Séparations au-dessus du remplissage de la barre
    local tickHolder = CreateFrame("Frame", nil, bar)
    tickHolder:SetAllPoints()
    tickHolder:SetFrameLevel(bar:GetFrameLevel() + 5)
    for i, rk in ipairs(RANKS) do
        rankLabels[i] = UI:Text(head, 10, C.muted)
        rankLabels[i]:SetText(rk[1])
        if i < #RANKS then
            local t = tickHolder:CreateTexture(nil, "OVERLAY")
            t:SetSize(3, 14)
            ticks[i] = t
        end
    end
    local marker = UI:Text(head, 10)
    local function placeRanks(rank)
        local w = bar:GetWidth()
        if not w or w < 50 then w = (UI.PAGE_W or 840) - 32 end
        local cur = 1
        for i, rk in ipairs(RANKS) do if rank >= rk[2] and i < #RANKS then cur = i + 1 end end
        for i = 1, #RANKS do
            local l = rankLabels[i]
            l:ClearAllPoints()
            l:SetPoint("BOTTOM", bar, "TOPLEFT", w * (i - 0.5) / #RANKS, 6)
            l:SetTextColor(unpack(i == cur and C.text or C.dim))
            if ticks[i] then
                ticks[i]:ClearAllPoints()
                ticks[i]:SetPoint("CENTER", bar, "LEFT", w * i / #RANKS, 0)
                ticks[i]:SetColorTexture(unpack(C.bg))
            end
        end
        marker:ClearAllPoints()
        marker:SetPoint("TOP", bar, "BOTTOMLEFT", math.max(10, math.min(w - 10, w * math.min(rank, 300) / 300)), -4)
        marker:SetText(tostring(rank))
        marker:SetTextColor(UI:Accent())
        bar:SetValue(math.min(rank, 300) / 300)
    end

    -- « Ouvrir le métier ». Par l'API si le client l'a ; sinon un bouton sécurisé lance le sort
    -- du métier. Ce bouton sécurisé n'est PAS dans la fenêtre (sinon le jeu bloquerait sa
    -- fermeture en combat) : il est posé par-dessus, hors combat seulement.
    local open = UI:Button(head, "Ouvrir le métier", 170, 32, "primary", "play")
    open:SetPoint("TOPRIGHT", -16, -26)
    open:SetScript("OnClick", function() WK.modules.Professions:OpenDirect(tab.prof) end)
    local secure
    local function needSecure()
        return not (C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill)
    end
    function tab:SyncSecure()
        if InCombatLockdown and InCombatLockdown() then return end
        local want = needSecure() and open:IsVisible() and self.prof ~= nil
        if want and not secure then
            secure = CreateFrame("Button", "WarbandKeeperOpenProfession", UIParent, "SecureActionButtonTemplate")
            if secure.RegisterForClicks then secure:RegisterForClicks("AnyUp", "AnyDown") end
            secure:SetAttribute("type", "spell")
            secure:SetScript("OnEnter", function() open:GetScript("OnEnter")(open) end)
            secure:SetScript("OnLeave", function() open:GetScript("OnLeave")(open) end)
        end
        if not secure then return end
        if want then
            secure:SetAttribute("spell", WK.modules.Professions:OpenSpell(self.prof))
            secure:ClearAllPoints()
            secure:SetAllPoints(open)
            secure:SetFrameStrata(open:GetFrameStrata() or "HIGH")
            secure:SetFrameLevel((open:GetFrameLevel() or 1) + 5)
            secure:Show()
        else
            secure:Hide()
        end
    end
    open:HookScript("OnShow", function() tab:SyncSecure() end)
    open:HookScript("OnHide", function() tab:SyncSecure() end)
    WK:On("PLAYER_REGEN_DISABLED", function() if secure then secure:Hide() end end)
    WK:On("PLAYER_REGEN_ENABLED", function() tab:SyncSecure() end)
    local note = UI:Text(head, 10, C.dim)
    note:SetPoint("TOPRIGHT", -16, -32)
    note:SetJustifyH("RIGHT")

    -- Filtres
    local fTop = TOP - HEAD_H - GAP
    local filter = UI:Segmented(parent, { { "all", "Toutes" }, { "up", "Font monter" }, { "craft", "Possibles" } },
        function(k) tab.filter = k; tab:Refresh() end, 34)
    filter:SetPoint("TOPLEFT", 0, fTop)
    filter:Select("all")
    local search = UI:Input(parent, 220, 34, "Rechercher une recette...", "search")
    search:SetPoint("TOPRIGHT", 0, fTop)
    search.onChange = function(t) tab.query = string.lower(t or ""); tab:Refresh() end
    local info = UI:Text(parent, 11, C.muted)
    info:SetPoint("LEFT", filter, "RIGHT", 14, 0)
    -- Recettes ou guide de montée (quand un guide existe pour ce métier)
    local modeSeg = UI:Segmented(parent, { { "recipes", "Recettes" }, { "guide", "Guide de montée" } },
        function(k) tab.mode = k; tab.scrollToCurrent = (k == "guide"); tab:Refresh() end, 34)
    modeSeg:SetPoint("TOPLEFT", 0, fTop)
    modeSeg:Select("recipes")

    local scroll = UI:Scroll(parent)
    scroll:SetPoint("TOPLEFT", 0, fTop - 46)
    scroll:SetPoint("BOTTOMRIGHT")
    local empty = UI:Text(parent, 12, C.muted)
    empty:SetPoint("TOPLEFT", scroll, "TOPLEFT", 20, -40)
    empty:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", -20, -40)
    empty:SetJustifyH("CENTER")
    if empty.SetWordWrap then empty:SetWordWrap(true) end

    local rows = UI:Pool(function()
        local r = CreateFrame("Button", nil, scroll.child)
        r:SetHeight(46)
        UI:Panel(r, 12, C.surface, C.border)
        -- Petite barre à gauche : couleur de la recette (orange, jaune, vert, gris).
        local df = CreateFrame("Frame", nil, r)
        df:SetPoint("TOPLEFT", 7, -10)
        df:SetPoint("BOTTOMLEFT", 7, 10)
        df:SetWidth(4)
        r.diff = UI:Rounded(df, 2, 0, "ARTWORK", 1)
        r.icon = UI:RoundIcon(r, 28)
        r.icon:SetPoint("LEFT", 18, 0)
        r.name = UI:Text(r, 12)
        r.name:SetPoint("TOPLEFT", 58, -9)
        r.name:SetPoint("TOPRIGHT", -240, -9)
        r.sub = UI:Text(r, 10, C.muted)
        r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -4)
        r.sub:SetPoint("TOPRIGHT", r.name, "BOTTOMRIGHT", 0, -4)
        r.profit = UI:Text(r, 13)
        r.profit:SetPoint("TOPRIGHT", -50, -8)
        r.profit:SetJustifyH("RIGHT")
        r.eco = UI:Text(r, 10, C.muted)
        r.eco:SetPoint("TOPRIGHT", r.profit, "BOTTOMRIGHT", 0, -4)
        r.eco:SetJustifyH("RIGHT")
        r.add = UI:IconButton(r, "plus", 28, "Ajouter à la liste de courses")
        r.add:SetPoint("RIGHT", -10, 0)
        r.add:SetScript("OnClick", function(b) WK.modules.Recipes:AddToList(b.recipeKey, 1); page:Refresh() end)
        r:SetScript("OnEnter", function(row) row.bg:SetColor(unpack(C.surface2)); recipeTooltip(row) end)
        r:SetScript("OnLeave", function(row) row.bg:SetColor(unpack(C.surface)); GameTooltip:Hide() end)
        return r
    end)

    -----------------------------------------------------------------------
    -- Métiers de récolte : zones et niveau de chaque ressource, mises en valeur
    -- pour le niveau du perso (pas de recettes).
    -----------------------------------------------------------------------
    local gather = CreateFrame("Frame", nil, parent)
    gather:SetPoint("TOPLEFT", 0, fTop)
    gather:SetPoint("BOTTOMRIGHT")
    gather:Hide()
    local where = UI:Card(gather, "Où aller à ton niveau")
    where:SetHeight(86)
    where:SetPoint("TOPLEFT")
    where:SetPoint("TOPRIGHT")
    local whereText = UI:Text(where, 12, C.muted)
    whereText:SetPoint("TOPLEFT", 16, -40)
    whereText:SetPoint("TOPRIGHT", -16, -40)
    whereText:SetJustifyH("LEFT")
    if whereText.SetWordWrap then whereText:SetWordWrap(true) end
    -- Tuiles de zones : nom, niveau des monstres, ressources utiles (pastille de couleur).
    local TILE_H = 66
    local tiles = UI:Pool(function()
        local t = CreateFrame("Frame", nil, where)
        t:SetHeight(TILE_H)
        UI:Panel(t, 10, C.surface2, C.border)
        t.name = UI:Text(t, 12)
        t.name:SetPoint("TOPLEFT", 12, -9)
        t.name:SetPoint("TOPRIGHT", -12, -9)
        t.level = UI:Text(t, 10, C.muted)
        t.level:SetPoint("TOPLEFT", t.name, "BOTTOMLEFT", 0, -3)
        t.res = UI:Text(t, 10, C.muted)
        t.res:SetPoint("BOTTOMLEFT", 12, 9)
        t.res:SetPoint("BOTTOMRIGHT", -12, 9)
        t.res:SetJustifyH("LEFT")
        t.here = UI:Badge(t, "tu y es", C.positive)
        t.here:SetPoint("TOPRIGHT", -8, -8)
        return t
    end)
    local gscroll = UI:Scroll(gather)
    gscroll:SetPoint("TOPLEFT", 0, -86 - GAP)
    gscroll:SetPoint("BOTTOMRIGHT")
    local GOOD_BG = C.surface2
    local grows = UI:Pool(function()
        local r = CreateFrame("Button", nil, gscroll.child)
        r:SetHeight(50)
        UI:Panel(r, 12, C.surface, C.border)
        local df = CreateFrame("Frame", nil, r)
        df:SetPoint("TOPLEFT", 7, -10)
        df:SetPoint("BOTTOMLEFT", 7, 10)
        df:SetWidth(4)
        r.diff = UI:Rounded(df, 2, 0, "ARTWORK", 1)
        r.icon = UI:RoundIcon(r, 30)
        r.icon:SetPoint("LEFT", 18, 0)
        r.level = UI:Text(r, 13)
        r.level:SetPoint("TOPRIGHT", -16, -9)
        r.level:SetJustifyH("RIGHT")
        r.state = UI:Text(r, 10)
        r.state:SetPoint("TOPRIGHT", r.level, "BOTTOMRIGHT", 0, -4)
        r.state:SetJustifyH("RIGHT")
        r.name = UI:Text(r, 12)
        r.name:SetPoint("TOPLEFT", 60, -9)
        r.name:SetPoint("TOPRIGHT", -190, -9)
        r.zones = UI:Text(r, 10, C.muted)
        r.zones:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -5)
        r.zones:SetPoint("TOPRIGHT", r.name, "BOTTOMRIGHT", 0, -5)
        r:SetScript("OnEnter", function(s)
            if not s.data then return end
            WK.UI:TooltipOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetText(s.title or "", 1, 1, 1)
            for _, z in ipairs(s.data.zones) do GameTooltip:AddLine(WK.T(z), 0.85, 0.85, 0.85) end
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return r
    end)

    function tab:RefreshGather(pr)
        local G = WK.modules.Gathering
        local rank = pr.rank or 0
        local list, kind = G:Rows(self.prof, rank)
        local here = GetRealZoneText and GetRealZoneText() or ""
        -- Zones conseillées en tuiles (ta zone actuelle d'abord)
        local best = G:BestZones(list)
        local perZone = {}
        for _, d in ipairs(list) do
            if d.good then
                for _, z in ipairs(d.zones) do
                    perZone[z] = perZone[z] or {}
                    table.insert(perZone[z], d)
                end
            end
        end
        for i, z in ipairs(best) do
            if z == here or T(z) == here then table.remove(best, i); table.insert(best, 1, z); break end
        end
        tiles:Reset()
        local w = (where:GetWidth() or 0) > 100 and where:GetWidth() or (UI.PAGE_W or 840)
        local perRow = math.max(2, math.min(4, math.floor((w - 32 + 10) / 210)))
        local tw = (w - 32 - (perRow - 1) * 10) / perRow
        local shown = math.min(#best, perRow * 2)
        whereText:SetShown(#best == 0)
        whereText:SetText(T("Plus rien ne fait monter ce métier : il est au maximum pour ces ressources."))
        for i = 1, shown do
            local z = best[i]
            local t = tiles:Get()
            t:SetWidth(tw)
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", 16 + ((i - 1) % perRow) * (tw + 10), -40 - math.floor((i - 1) / perRow) * (TILE_H + 8))
            local isHere = z == here or T(z) == here
            t.name:SetText(T(z))
            t.name:SetPoint("TOPRIGHT", isHere and -70 or -12, -9)
            t.level:SetText(G.ZONE_LEVELS[z] and string.format(T("Niv. %s"), G.ZONE_LEVELS[z]) or "")
            local parts = {}
            for _, d in ipairs(perZone[z] or {}) do
                local col = DIFF[d.color] and DIFF[d.color].color or C.text
                table.insert(parts, UI:Hex(col) .. "•|r " .. ((UI:ItemInfo(d.id)) or "?"))
            end
            t.res:SetText(table.concat(parts, "   "))
            t.here:SetShown(isHere)
            t.border:SetColor(unpack(isHere and { UI:Accent() } or C.border))
        end
        local rowsN = math.max(1, math.ceil(shown / perRow))
        local cardH = 40 + rowsN * (TILE_H + 8) + 6
        if #best == 0 then cardH = 86 end
        where:SetHeight(cardH)
        gscroll:ClearAllPoints()
        gscroll:SetPoint("TOPLEFT", 0, -cardH - GAP)
        gscroll:SetPoint("BOTTOMRIGHT")
        -- Ressources
        grows:Reset()
        local y = 0
        for _, d in ipairs(list) do
            local r = grows:Get()
            r.data = d
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -y)
            r:SetPoint("TOPRIGHT", 0, -y)
            local name, ic, qr, qg, qb = UI:ItemInfo(d.id)
            r.title = (name or "?") .. (d.suffix and (" (" .. T(d.suffix) .. ")") or "")
            r.icon:SetTexture(ic)
            r.name:SetText(r.title)
            r.name:SetTextColor(qr or 1, qg or 1, qb or 1)
            local zs = {}
            for _, z in ipairs(d.zones) do
                local zn = T(z)
                if z == here or zn == here then zn = UI:Hex(C.positive) .. zn .. "|r" end
                table.insert(zs, zn)
            end
            r.zones:SetText(table.concat(zs, ", "))
            if kind == "skin" then
                r.level:SetText(string.format(T("Monstres niv. %d-%d"), d.min, d.max))
            else
                r.level:SetText(string.format(T("Niv. %d"), d.req))
            end
            local col = d.color == "low" and C.negative or (DIFF[d.color] and DIFF[d.color].color) or C.border
            r.diff:SetColor(unpack(col))
            local label = d.color == "low" and T("Trop bas") or T(DIFF[d.color].label)
            r.state:SetText(UI:Hex(col) .. label .. (d.good and ("  ·  " .. T("pour ton niveau")) or "") .. "|r")
            r.bg:SetColor(unpack(d.good and GOOD_BG or C.surface))
            r.border:SetColor(unpack(d.good and { UI:Accent() } or C.border))
            r:SetAlpha((d.color == "low" or d.color == "trivial") and 0.6 or 1)
            y = y + 56
        end
        gscroll:SetContentHeight(y)
        local maxL = kind == "skin" and G:SkinMaxLevel(rank)
        return maxL
    end

    -----------------------------------------------------------------------
    -- Guide de montée : étapes (celle en cours mise en avant) et matériaux
    -- jusqu'au niveau max, avec ce qui manque sur le compte.
    -----------------------------------------------------------------------
    local MATS_W = 320
    local guide = CreateFrame("Frame", nil, parent)
    guide:SetPoint("TOPLEFT", 0, fTop - 46)
    guide:SetPoint("BOTTOMRIGHT")
    guide:Hide()
    local gsteps = UI:Scroll(guide)
    gsteps:SetPoint("TOPLEFT")
    gsteps:SetPoint("BOTTOMRIGHT", -(MATS_W + GAP), 0)
    local matsCard = UI:Card(guide, "Matériaux jusqu'au max")
    matsCard:SetWidth(MATS_W)
    matsCard:SetPoint("TOPRIGHT")
    matsCard:SetPoint("BOTTOMRIGHT")
    local matsSum = UI:Text(matsCard, 11, C.muted)
    matsSum:SetPoint("TOPLEFT", 16, -36)
    matsSum:SetPoint("TOPRIGHT", -16, -36)
    matsSum:SetJustifyH("LEFT")
    local ahBtn = UI:Button(matsCard, "Liste Auctionator", nil, 28, "primary", "search")
    ahBtn:SetPoint("BOTTOMLEFT", 12, 46)
    ahBtn:SetPoint("BOTTOMRIGHT", -12, 46)
    local matsTotal = UI:Text(matsCard, 13)
    matsTotal:SetPoint("BOTTOMRIGHT", -16, 84)
    matsTotal:SetJustifyH("RIGHT")
    ahBtn.tooltip = "Crée une liste de courses Auctionator avec les composants qui manquent sur le compte."
    ahBtn:SetScript("OnClick", function() WK.modules.Recipes:GuideToAuctionator(tab.prof, tab.rank, tab.known) end)
    local mailBtn = UI:Button(matsCard, "Envoyer à ce perso", nil, 28, "secondary", "mail")
    mailBtn:SetPoint("BOTTOMLEFT", 12, 12)
    mailBtn:SetPoint("BOTTOMRIGHT", -12, 12)
    mailBtn.tooltip = "Crée des règles d'envoi pour que tes autres persos lui postent ces composants (les règles existantes ne sont pas modifiées)."
    mailBtn:SetScript("OnClick", function()
        local added, skipped = WK.modules.Recipes:GuideMailRules(tab.prof, tab.key)
        WK:Print(string.format(T("Guide : %d règle(s) d'envoi ajoutée(s), %d déjà existante(s)."), added, skipped))
    end)
    local mscroll = UI:Scroll(matsCard)
    mscroll:SetPoint("TOPLEFT", 10, -60)
    mscroll:SetPoint("BOTTOMRIGHT", -8, 108)
    local mrows = UI:Pool(function()
        local r = CreateFrame("Button", nil, mscroll.child)
        r:SetHeight(30)
        r.icon = UI:RoundIcon(r, 20)
        r.icon:SetPoint("LEFT", 4, 0)
        r.price = UI:Text(r, 11)
        r.price:SetPoint("RIGHT", -4, 0)
        r.price:SetJustifyH("RIGHT")
        r.price:SetWidth(70)
        r.count = UI:Text(r, 11)
        r.count:SetPoint("RIGHT", r.price, "LEFT", -6, 0)
        r.count:SetJustifyH("RIGHT")
        r.count:SetWidth(64)
        r.name = UI:Text(r, 11)
        r.name:SetPoint("LEFT", 30, 0)
        r.name:SetPoint("RIGHT", r.count, "LEFT", -6, 0)
        r:SetScript("OnEnter", function(s)
            if not s.m then return end
            WK.UI:TooltipOwner(s, "ANCHOR_LEFT")
            GameTooltip:SetText((UI:ItemInfo(s.m.itemID)) or "?", 1, 1, 1)
            GameTooltip:AddDoubleLine(T("Nécessaire"), tostring(s.m.need), 0.7, 0.7, 0.7, 1, 1, 1)
            GameTooltip:AddDoubleLine(T("Sur le compte"), tostring(s.m.have), 0.7, 0.7, 0.7, 1, 1, 1)
            if s.m.recipe then
                local info = s.m.recipe
                GameTooltip:AddLine(string.format(T("Recette pour l'étape %d-%d, à acheter chez :"), info.from or 0, info.to or 0), 0.6, 0.8, 1, true)
                for _, v in ipairs(info.vendors or {}) do
                    GameTooltip:AddDoubleLine("  " .. v[1], v[2] and T(v[2]) or "", 1, 1, 1, 0.7, 0.7, 0.7)
                end
            end
            GameTooltip:AddDoubleLine(T("Prix unitaire"), WK:FormatMoney(s.m.unit or 0), 0.7, 0.7, 0.7, 1, 1, 1)
            if s.m.missing > 0 then
                GameTooltip:AddDoubleLine(T("Manquant"), tostring(s.m.missing), 0.7, 0.7, 0.7, 1, 0.5, 0.4)
                GameTooltip:AddDoubleLine(T("Coût du manquant"), WK:FormatMoney(s.m.cost), 0.7, 0.7, 0.7, 1, 1, 1)
            end
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return r
    end)
    -- Lignes d'étapes et en-têtes de rang
    local sheads = UI:Pool(function()
        local h = CreateFrame("Frame", nil, gsteps.child)
        h:SetHeight(40)
        h.title = UI:Text(h, 12)
        h.title:SetPoint("TOPLEFT", 4, -6)
        h.info = UI:Text(h, 10, C.muted)
        h.info:SetPoint("TOPLEFT", h.title, "BOTTOMLEFT", 0, -3)
        h.info:SetPoint("TOPRIGHT", h, "TOPRIGHT", -4, -21)
        h.info:SetJustifyH("LEFT")
        return h
    end)
    local srows = UI:Pool(function()
        local r = CreateFrame("Button", nil, gsteps.child)
        r:SetHeight(50)
        UI:Panel(r, 12, C.surface, C.border)
        r.range = UI:Text(r, 11, C.muted)
        r.range:SetPoint("LEFT", 12, 0)
        r.range:SetWidth(58)
        r.icon = UI:RoundIcon(r, 28)
        r.icon:SetPoint("LEFT", 72, 0)
        r.state = UI:Text(r, 10)
        r.state:SetPoint("TOPRIGHT", -12, -9)
        r.state:SetJustifyH("RIGHT")
        r.name = UI:Text(r, 12)
        r.name:SetPoint("TOPLEFT", 110, -9)
        r.name:SetPoint("TOPRIGHT", -90, -9)
        r.sub = UI:Text(r, 10, C.muted)
        r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -5)
        r.sub:SetPoint("TOPRIGHT", r, "TOPRIGHT", -12, -28)
        r:SetScript("OnEnter", function(s)
            if not s.e then return end
            local st = s.e.step
            WK.UI:TooltipOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetText(s.title or "", 1, 1, 1)
            GameTooltip:AddLine(string.format(T("Niveaux %d à %d · %d fabrications"), st.from, st.to, st.crafts), 0.8, 0.8, 0.8)
            for _, f in ipairs(st.first or {}) do
                GameTooltip:AddLine(string.format(T("D'abord : %d x %s"), f.crafts, (stepInfo(f))), 0.6, 0.8, 1)
            end
            if st.tools then
                local names = {}
                for _, tool in ipairs(st.tools) do table.insert(names, (UI:ItemInfo(tool)) or "?") end
                GameTooltip:AddLine(T("Outils : ") .. table.concat(names, ", "), 0.8, 0.8, 0.8, true)
            end
            for _, rg in ipairs(st.reagents or {}) do
                local have = WK.modules.Inventory:AccountCount(rg[1])
                local need = rg[2] * math.max(s.e.left, 0)
                GameTooltip:AddDoubleLine((UI:ItemInfo(rg[1])) or "?", string.format("%d / %d", have, need),
                    0.85, 0.85, 0.85, have >= need and 0.6 or 1, have >= need and 1 or 0.5, have >= need and 0.5 or 0.4)
            end
            if st.src == "recipe" then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(string.format(T("Recette : %s"), (st.learn and UI:ItemInfo(st.learn)) or "?"), 1, 0.82, 0)
                if st.vendors then
                    GameTooltip:AddLine(T("Vendeurs :"), 0.8, 0.8, 0.8)
                    for _, v in ipairs(st.vendors) do
                        GameTooltip:AddDoubleLine("  " .. v[1], v[2] and T(v[2]) or "", 1, 1, 1, 0.7, 0.7, 0.7)
                    end
                end
            end
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return r
    end)

    function tab:RefreshGuide(c, pr)
        local R = WK.modules.Recipes
        self.currentY = nil
        local rank = pr.rank or 0
        self.rank = rank
        self.known = R:KnownOutputs(c)
        local steps, mats, total, g = R:GuidePlan(self.prof, rank, self.known)
        local faction = c.faction == "Horde" and "horde" or "alliance"
        sheads:Reset(); srows:Reset()
        local y, si = 0, 1
        local sections = g.sections or {}
        for _, e in ipairs(steps) do
            local st = e.step
            -- En-tête de rang quand on entre dans une nouvelle tranche
            while sections[si] and st.from >= sections[si].from do
                local sec = sections[si]
                local h = sheads:Get()
                h:ClearAllPoints()
                h:SetPoint("TOPLEFT", 0, -y)
                h:SetPoint("TOPRIGHT", 0, -y)
                h.title:SetText(string.format("%s  %s", T(sec.rank), UI:Hex(C.muted) .. sec.from .. "-" .. sec.to .. "|r"))
                local bits = {}
                local tr = sec[faction]
                if tr then
                    local names = {}
                    for _, n in ipairs(tr) do table.insert(names, n[1] .. " (" .. T(n[2]) .. ")") end
                    table.insert(bits, T("Maître : ") .. table.concat(names, ", "))
                end
                if sec.note then table.insert(bits, UI:Hex(C.warning) .. renderNote(sec.note) .. "|r") end
                h.info:SetText(table.concat(bits, "  ·  "))
                y = y + (#bits > 0 and 44 or 28)
                si = si + 1
            end
            local r = srows:Get()
            r.e = e
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -y)
            r:SetPoint("TOPRIGHT", 0, -y)
            r.range:SetText(st.from .. "-" .. st.to)
            local name, ic, qr, qg, qb = stepInfo(st)
            r.title = name or "?"
            r.icon:SetTexture(ic)
            local n = e.status == "current" and e.left or st.crafts
            r.name:SetText((name or "?") .. "  " .. UI:Hex(C.muted) .. "x" .. n .. "|r")
            r.name:SetTextColor(qr or 1, qg or 1, qb or 1)
            local reag = {}
            for _, f in ipairs(st.first or {}) do
                table.insert(reag, UI:Hex(C.muted) .. T("d'abord") .. " " .. f.crafts .. " " .. (stepInfo(f)) .. "|r")
            end
            for _, rg in ipairs(st.reagents or {}) do
                table.insert(reag, (rg[2] * n) .. " " .. ((UI:ItemInfo(rg[1])) or "?"))
            end
            local src
            if st.src == "recipe" then
                if WK.modules.Recipes:StepKnown(st, self.known) then
                    src = UI:Hex(C.positive) .. T("Recette connue") .. "|r"
                else
                    src = UI:Hex(C.warning) .. T("Recette à acheter") .. "|r"
                    if st.vendors then src = src .. " " .. T("chez") .. " " .. vendorText(st.vendors, 2) end
                end
            else
                src = T("Maître")
            end
            r.sub:SetText(src .. "  ·  " .. table.concat(reag, ", "))
            if e.status == "done" then
                r.state:SetText(UI:Hex(C.positive) .. T("fait") .. "|r")
                r:SetAlpha(0.5)
                r.bg:SetColor(unpack(C.surface)); r.border:SetColor(unpack(C.border))
            elseif e.status == "current" then
                r.state:SetText(UI:Hex(C.gold) .. T("en cours") .. "|r")
                r:SetAlpha(1)
                r.bg:SetColor(unpack(C.surface2)); r.border:SetColor(UI:Accent())
            else
                r.state:SetText("")
                r:SetAlpha(1)
                r.bg:SetColor(unpack(C.surface)); r.border:SetColor(unpack(C.border))
            end
            if e.status == "current" then self.currentY = y end
            y = y + 56
        end
        gsteps:SetContentHeight(y)
        -- À l'ouverture du guide : on fait défiler jusqu'à l'étape en cours.
        if self.scrollToCurrent then
            self.scrollToCurrent = false
            local target = math.max(0, (self.currentY or 0) - 60)
            gsteps:SetVerticalScroll(math.min(target, gsteps:MaxScroll()))
            gsteps:UpdateBar()
        end

        -- Matériaux
        local missing = 0
        for _, m in ipairs(mats) do if m.missing > 0 then missing = missing + 1 end end
        matsTotal:SetText(T("Total à acheter : ") .. UI:GoldText(total))
        if #mats == 0 then
            matsSum:SetText(T("Plus rien à fabriquer : le guide est terminé."))
        else
            matsSum:SetText(string.format(T("%d manquant(s) · coût %s"), missing, UI:PlainMoney(total)))
        end
        mrows:Reset()
        local my = 0
        for _, m in ipairs(mats) do
            local r = mrows:Get()
            r.m = m
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -my)
            r:SetPoint("TOPRIGHT", 0, -my)
            local name, ic, qr, qg, qb = UI:ItemInfo(m.itemID)
            r.icon:SetTexture(ic)
            r.name:SetText(name or "?")
            r.name:SetTextColor(qr or 1, qg or 1, qb or 1)
            if m.missing > 0 then
                r.count:SetText(string.format("%s%d|r / %d", UI:Hex(C.negative), m.have, m.need))
                r.price:SetText(m.cost > 0 and UI:GoldText(m.cost) or (UI:Hex(C.dim) .. "?|r"))
            else
                r.count:SetText(string.format("%s%d|r / %d", UI:Hex(C.positive), m.have, m.need))
                r.price:SetText(UI:Hex(C.positive) .. T("ok") .. "|r")
            end
            my = my + 32
        end
        mscroll:SetContentHeight(my)
    end

    function tab:Show(key, prof)
        if self.key ~= key or self.prof ~= prof then
            self.query, self.filter = "", "all"
            -- Guide de montée par défaut quand il existe et que le métier n'est pas au max.
            self.mode = WK.modules.Recipes:Guide(prof) and "guide" or "recipes"
            modeSeg:Select(self.mode)
            self.scrollToCurrent = true
            search:SetText("")
            filter:Select("all")
        end
        self.key, self.prof = key, prof
    end

    function tab:Refresh()
        local c = WK.DB.global.characters[self.key]
        if not c then return end
        local pr = c.professions and c.professions[self.prof] or {}
        local isMe = self.key == select(2, WK.DB:Me())
        local R = WK.modules.Recipes

        if pr.icon then icon:SetTexture(pr.icon) else UI:SetClassIcon(icon, c.class) end
        local r, g, b = UI:ClassColor(c.class)
        title:SetText(string.format("%s  |cff%02x%02x%02x%s|r", self.prof, r * 255, g * 255, b * 255, WK:CharName(c, self.key)))
        placeRanks(pr.rank or 0)

        local all = R:ForProfession(c, self.prof)
        local counts = { optimal = 0, medium = 0, easy = 0, trivial = 0 }
        for _, rec in ipairs(all) do if rec.diff then counts[rec.diff] = counts[rec.diff] + 1 end end
        local parts = { string.format("%d / %d", pr.rank or 0, pr.max or 0), string.format(T("%d recettes"), #all) }
        for _, k in ipairs({ "optimal", "medium", "easy" }) do
            if counts[k] > 0 then
                table.insert(parts, UI:Hex(DIFF[k].color) .. counts[k] .. " " .. string.lower(T(DIFF[k].label)) .. "|r")
            end
        end
        sub:SetText(table.concat(parts, "  ·  "))

        -- Ouverture : seulement pour le perso connecté et un métier qui a une fenêtre.
        local canOpen = isMe and #all > 0
        open:SetShown(canOpen)
        self:SyncSecure()
        local scan = c.recipeScans and c.recipeScans[self.prof]
        if canOpen then
            note:SetText("")
        elseif scan then
            note:SetText(string.format(T("Recettes lues le %s"), date("%d/%m à %H:%M", scan.t)))
        else
            note:SetText("")
        end

        -- Métier de récolte : zones et ressources au lieu des recettes.
        local gkind = WK.modules.Gathering:Kind(self.prof)
        gather:SetShown(gkind ~= nil)
        filter:SetShown(not gkind); search:SetShown(not gkind); info:SetShown(not gkind); scroll:SetShown(not gkind)
        if gkind then
            modeSeg:Hide(); guide:Hide()
            empty:Hide()
            local maxL = self:RefreshGather(pr)
            local p2 = { string.format("%d / %d", pr.rank or 0, pr.max or 0) }
            if maxL then table.insert(p2, string.format(T("dépeçage des monstres jusqu'au niveau %d"), maxL)) end
            sub:SetText(table.concat(p2, "  ·  "))
            return
        end

        -- Guide de montée : sélecteur Recettes / Guide quand un guide existe.
        local hasGuide = WK.modules.Recipes:Guide(self.prof) ~= nil
        modeSeg:SetShown(hasGuide)
        filter:ClearAllPoints()
        if hasGuide then filter:SetPoint("LEFT", modeSeg, "RIGHT", 12, 0) else filter:SetPoint("TOPLEFT", 0, fTop) end
        info:SetShown(not hasGuide)
        local showGuide = hasGuide and self.mode == "guide"
        guide:SetShown(showGuide)
        filter:SetShown(not showGuide); search:SetShown(not showGuide); scroll:SetShown(not showGuide)
        if showGuide then
            empty:Hide()
            self:RefreshGuide(c, pr)
            return
        end

        -- Liste filtrée
        local list = {}
        for _, rec in ipairs(all) do
            local ok = self.query == "" or string.find(string.lower(rec.name), self.query, 1, true)
            if ok and self.filter == "up" then ok = rec.diff == "optimal" or rec.diff == "medium" or rec.diff == "easy" end
            if ok and self.filter == "craft" then ok = (R:Craftable(rec) or 0) > 0 end
            if ok then table.insert(list, rec) end
        end

        rows:Reset()
        local y = 0
        for i, rec in ipairs(list) do
            if i > MAX_RECIPES then break end
            local row = rows:Get()
            row.rec = rec
            row.add.recipeKey = rec.key
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", 0, -y)
            local d = DIFF[rec.diff]
            row.diff:SetColor(unpack(d and d.color or C.border))
            local ic, qr, qg, qb = rec.icon, 1, 1, 1
            if rec.out then
                local _, oicon, r1, g1, b1 = UI:ItemInfo(rec.out)
                ic = ic or oicon
                qr, qg, qb = r1, g1, b1
            end
            row.icon:SetTexture(ic or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.name:SetText(rec.name)
            row.name:SetTextColor(qr, qg, qb)
            local can = R:Craftable(rec) or 0
            local reag = {}
            for _, rg in ipairs(rec.reagents or {}) do
                table.insert(reag, string.format("%d %s", rg[2], (UI:ItemInfo(rg[1]))))
            end
            local bits = {}
            if d then table.insert(bits, UI:Hex(d.color) .. T(d.label) .. "|r") end
            table.insert(bits, can > 0 and (UI:Hex(C.positive) .. string.format(T("x%d possibles"), can) .. "|r")
                or T("composants manquants"))
            if #reag > 0 then table.insert(bits, table.concat(reag, ", ")) end
            row.sub:SetText(table.concat(bits, "  ·  "))
            local cost, sale, profit = R:Economics(rec)
            if profit then
                if profit >= 0 then row.profit:SetText("+" .. UI:GoldText(profit))
                else row.profit:SetText(UI:Hex(C.negative) .. UI:PlainMoney(profit) .. "|r") end
                row.eco:SetText(string.format(T("coût %s · vente %s"), UI:PlainMoney(cost), UI:PlainMoney(sale)))
            else
                row.profit:SetText(UI:Hex(C.dim) .. "-|r")
                row.eco:SetText(string.format(T("coût %s · pas de prix de vente"), UI:PlainMoney(cost)))
            end
            y = y + 52
        end
        scroll:SetContentHeight(y)
        self.shown = #list
        info:SetText(string.format(T("%d recettes"), #list))
        empty:SetShown(#list == 0)
        if #all == 0 then
            empty:SetText(string.format(T("Aucune recette enregistrée pour ce métier. Ouvre la fenêtre de %s sur %s pour les lire (un métier de récolte n'en a pas)."),
                self.prof, WK:CharName(c, self.key)))
        else
            empty:SetText(T("Aucune recette ne correspond au filtre."))
        end
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
        for _, k in ipairs({ "levels", "recipes", "shopping", "detail" }) do
            local f = CreateFrame("Frame", nil, p)
            f:SetAllPoints()
            f:SetShown(k == "levels")
            frames[k] = f
        end
        tabs.levels = Levels(self, frames.levels)
        tabs.detail = Detail(self, frames.detail)
        -- La fiche prend la place des onglets (masqués) : on la remonte d'autant.
        frames.detail:ClearAllPoints()
        frames.detail:SetPoint("TOPLEFT", 0, -TOP)
        frames.detail:SetPoint("BOTTOMRIGHT")
        tabs.recipes = Recipes(self, frames.recipes)
        tabs.shopping = Shopping(self, frames.shopping)
        UI:OnResize(p, function() UI:RefreshSoon() end) -- cartes des niveaux
        self.tabs = tabs
        local seg
        local function setTab(k)
            self.tab = k
            self.detailOpen = nil
            if seg then seg:Show() end
            for key, f in pairs(frames) do f:SetShown(key == k) end
            self:Refresh()
        end
        seg = UI:Segmented(p, { { "levels", "Niveaux" }, { "recipes", "Recettes" }, { "shopping", "Liste de courses" } }, setTab, 32)
        seg:SetPoint("TOPLEFT")
        seg:Select("levels")
        function self:SetTab(k) seg:Select(k); setTab(k) end
        -- Fiche d'un métier (dans l'onglet Niveaux) ; ShowDetail(nil) revient aux niveaux.
        function self:ShowDetail(key, prof)
            if not key then self:SetTab("levels") return end
            seg:Select("levels")
            seg:Hide() -- les onglets ne servent que sur la liste des métiers
            self.tab = "detail"
            self.detailOpen = true
            for k, f in pairs(frames) do f:SetShown(k == "detail") end
            tabs.detail:Show(key, prof)
            self:Refresh()
        end
    end,

    Refresh = function(self)
        self.tabs[self.tab]:Refresh()
    end,
})
