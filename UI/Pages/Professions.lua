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
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(WK.T("Maj + clic : lien dans le chat"), 0.6, 0.6, 0.6)
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
            t:SetScript("OnClick", function(s)
                -- Maj + clic : lien du métier dans le chat (même lien que « Link tchat »)
                if IsShiftKeyDown() then
                    WK.modules.Recipes:LinkToChat(WK.DB.global.characters[s.charKey], s.charKey, s.prof)
                    return
                end
                page:ShowDetail(s.charKey, s.prof)
            end)
            t:SetScript("OnEnter", function(s)
                if not s.warn then s.border:SetColor(UI:Accent()) end
                WK.UI:TooltipOwner(s, "ANCHOR_TOP")
                GameTooltip:SetText(WK.T("Clic : recettes et détail du métier"), 1, 1, 1)
                GameTooltip:AddLine(WK.T("Maj + clic : lien du métier dans le chat"), 0.7, 0.7, 0.7)
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
    local search = UI:Input(parent, 240, 34, "Rechercher une recette...", "search")
    search:SetPoint("TOPLEFT", 0, TOP)
    search.onChange = function(t) tab.query = string.lower(t or ""); tab:Refresh() end
    local sortSeg = UI:Segmented(parent, { { "name", "Nom" }, { "profit", "Bénéfice" }, { "craftable", "Possibles" } },
        function(k) tab.sort = k; tab:Refresh() end, 34)
    sortSeg:SetPoint("TOPRIGHT", 0, TOP)
    sortSeg:Select("name")
    local sortLbl = UI:Text(parent, 11, C.muted)
    sortLbl:SetPoint("RIGHT", sortSeg, "LEFT", -10, 0)
    -- « Rentables maintenant » : bénéfice positif et composants déjà sur le compte.
    local profitBtn = UI:Button(parent, "Rentables maintenant", nil, 34, "secondary", "coin")
    profitBtn:SetPoint("RIGHT", sortLbl, "LEFT", -14, 0)
    profitBtn.tooltip = "Seulement les recettes rentables que tu peux fabriquer tout de suite avec les composants du compte, triées par gain total possible."
    profitBtn:SetScript("OnClick", function()
        tab.onlyProfit = not tab.onlyProfit
        profitBtn:SetStyle(tab.onlyProfit and "primary" or "secondary")
        tab:Refresh()
    end)
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
        r:SetScript("OnClick", function(row) if IsShiftKeyDown() and row.rec then WK.modules.Recipes:LinkRecipe(row.rec) end end)
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
        if self.onlyProfit then
            local keep = {}
            for _, rec in ipairs(list) do
                local e = eco[rec]
                if e.profit and e.profit > 0 and e.can > 0 then keep[#keep + 1] = rec end
            end
            list = keep
            table.sort(list, function(a, b)
                local ga, gb = eco[a].profit * eco[a].can, eco[b].profit * eco[b].can
                if ga ~= gb then return ga > gb end
                return a.name < b.name
            end)
        elseif self.sort == "profit" then
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
                if self.onlyProfit then
                    r.eco:SetText(string.format(T("x%d possibles · gain total %s"), e.can, UI:PlainMoney(e.profit * e.can)))
                else
                    r.eco:SetText(string.format(T("coût %s · vente %s"), UI:PlainMoney(e.cost), UI:PlainMoney(e.sale)))
                end
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

    local planned = UI:Card(parent, "File de fabrication")
    planned:SetWidth(leftW)
    planned:SetPoint("TOPLEFT", 0, TOP)
    planned:SetPoint("BOTTOMLEFT", 0, 116)
    -- recharges de tout le compte (transmutations, étoffe lunaire…) : Modules/ProfHelp.lua
    local cds = UI:Card(parent, "Recharges", "prévenu quand c'est prêt, sur n'importe quel perso")
    cds:SetPoint("TOPLEFT", planned, "BOTTOMLEFT", 0, -10)
    cds:SetPoint("BOTTOMLEFT")
    cds:SetWidth(leftW)
    local cdEmpty = UI:Text(cds, 11, C.muted)
    cdEmpty:SetPoint("TOPLEFT", 16, -44)
    cdEmpty:SetText("Aucune recette à temps de recharge connue.")
    local cdTiles = {}
    local function cdTile(i)
        if cdTiles[i] then return cdTiles[i] end
        local t = CreateFrame("Frame", nil, cds)
        t:SetHeight(52)
        t.bg = UI:Rounded(t, 9, 0, "BACKGROUND", 1); t.bg:SetColor(unpack(C.surface2))
        t.name = UI:Text(t, 11); t.name:SetPoint("TOPLEFT", 10, -7); t.name:SetPoint("RIGHT", -8, 0)
        t.who = UI:Text(t, 10, C.muted); t.who:SetPoint("TOPLEFT", 10, -22); t.who:SetPoint("RIGHT", -8, 0)
        t.bar = UI:Progress(t, 4); t.bar:SetPoint("BOTTOMLEFT", 10, 8); t.bar:SetPoint("RIGHT", -10, 0)
        cdTiles[i] = t
        return t
    end
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
        local r = CreateFrame("Button", nil, ps.child)
        r:SetHeight(40)
        r.bg = UI:Rounded(r, 10, 0, "BACKGROUND", 1)
        r.bg:SetColor(unpack(C.surface2))
        r.icon = UI:RoundIcon(r, 22)
        r.icon:SetPoint("LEFT", 8, 0)
        r.name = UI:Text(r, 12)
        r.name:SetPoint("TOPLEFT", 38, -6)
        r.name:SetPoint("RIGHT", -100, 0)
        r.sub = UI:Text(r, 10, C.muted)
        r.sub:SetPoint("TOPLEFT", 38, -22)
        r.sub:SetPoint("RIGHT", -100, 0)
        r.make = UI:Button(r, "Fabriquer", nil, 22, "primary")
        r.make:SetScript("OnClick", function(b) WK.modules.ProfHelp:Craft(b.recipeKey, b.n) end)
        r.plus = UI:IconButton(r, "plus", 24, "Une fabrication de plus")
        r.plus:SetPoint("RIGHT", -6, 0)
        r.qty = UI:Text(r, 13)
        r.qty:SetPoint("RIGHT", r.plus, "LEFT", -6, 0)
        r.qty:SetJustifyH("RIGHT")
        r.minus = UI:IconButton(r, "minus", 24, "Une fabrication de moins")
        r.minus:SetPoint("RIGHT", r.qty, "LEFT", -6, 0)
        r.make:SetPoint("RIGHT", r.minus, "LEFT", -6, 0)
        r.plus:SetScript("OnClick", function(b) WK.modules.Recipes:AddToList(b.recipeKey, 1); page:Refresh() end)
        r.minus:SetScript("OnClick", function(b) WK.modules.Recipes:AddToList(b.recipeKey, -1); page:Refresh() end)
        r:SetScript("OnClick", function(row) if IsShiftKeyDown() and row.rec then WK.modules.Recipes:LinkRecipe(row.rec) end end)
        r:SetScript("OnEnter", function(row)
            if not row.rec then return end
            WK.UI:TooltipOwner(row, "ANCHOR_RIGHT")
            GameTooltip:SetText(row.rec.name, 1, 1, 1)
            GameTooltip:AddLine(WK.T("Maj + clic : lien dans le chat"), 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return r
    end)

    local need = UI:Card(parent, "Composants")
    need:SetPoint("TOPLEFT", planned, "TOPRIGHT", GAP, 0)
    need:SetPoint("BOTTOMRIGHT")
    UI:OnResize(parent, function(w) planned:SetWidth(math.floor(w * 0.38)); cds:SetWidth(math.floor(w * 0.38)) end)
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
    local export = UI:Button(need, "Créer la liste d'achat", nil, 30, "primary", "plus")
    export:SetPoint("BOTTOMRIGHT", -12, 12)
    export:SetScript("OnClick", function() WK.modules.Recipes:ExportToList() end)
    export.tooltip = "Crée une liste d'achat avec les composants manquants ; à l'hôtel des ventes, onglet « Achat » de Warband Keeper (en bas de la fenêtre)."

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
        local PH = WK.modules.ProfHelp
        local chars = WK.DB.global.characters
        local openProf = PH:OpenProfession()
        pRows:Reset()
        local y = 0
        local queue = PH:Queue()
        for _, e in ipairs(queue) do
            local k, rec = e.key, e.rec
            local r = pRows:Get()
            r.plus.recipeKey, r.minus.recipeKey, r.make.recipeKey = k, k, k
            r.rec = rec
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -y)
            r:SetPoint("TOPRIGHT", 0, -y)
            local icon = rec and rec.icon or (rec and rec.out and select(2, UI:ItemInfo(rec.out)))
            r.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            r.name:SetText(rec and rec.name or k)
            r.qty:SetText("x" .. e.qty)
            -- qui la fabrique, et où en sont ses composants
            local status
            local c = e.crafter and chars[e.crafter]
            local who = c and (UI:Hex({ UI:ClassColor(c.class) }) .. WK:CharName(c, e.crafter) .. "|r") or UI:Hex(C.negative) .. T("personne ne la connaît") .. "|r"
            if not rec then status = ""
            elseif e.cd then status = string.format(T("prête dans %s"), WK:FormatTime(e.cd))
            elseif #e.missing == 0 then status = UI:Hex(C.positive) .. T("tout est là") .. "|r"
            else
                local m = e.missing[1]
                local oc = m.where and chars[m.where]
                status = UI:Hex(C.negative) .. string.format(T("manque %d %s"), m.n, (UI:ItemInfo(m.id)) or "?")
                    .. (oc and (" " .. string.format(T("(chez %s)"), WK:CharName(oc, m.where))) or "") .. "|r"
            end
            r.sub:SetText(who .. "  ·  " .. status)
            local n = math.min(e.qty, e.can or 0)
            local canMake = e.mine and rec and openProf and rec.prof == openProf and n > 0 and not e.cd
            r.make.n = n
            r.make:SetShown(canMake and true or false)
            if canMake then r.make:SetLabel(string.format(T("Fabriquer %d"), n)); r.make:SetWidth(r.make.label:GetStringWidth() + 24) end
            r.name:SetPoint("RIGHT", canMake and -(110 + r.make:GetWidth()) or -100, 0)
            y = y + 46
        end
        ps:SetContentHeight(y)
        pEmpty:SetShown(#queue == 0)
        -- recharges
        local list = PH:AllCooldowns()
        local tw = math.floor(((cds:GetWidth() or 300) - 32 - 2 * 8) / 3)
        for i = 1, 3 do
            local t = cdTile(i)
            local e = list[i]
            if e then
                t:ClearAllPoints(); t:SetPoint("TOPLEFT", 16 + (i - 1) * (tw + 8), -40); t:SetWidth(tw)
                t.name:SetText(e.name)
                local left = e.readyAt - time()
                t.who:SetText(WK:CharName(e.c, e.ck) .. "  ·  " .. (e.ready and (UI:Hex(C.positive) .. T("prête") .. "|r") or WK:FormatTime(left)))
                t.bar:SetValue(e.ready and 1 or math.max(0.02, 1 - left / (3 * 86400)))
                t:Show()
            else t:Hide() end
        end
        cdEmpty:SetShown(#list == 0)

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
        export:SetShown(#needs > 0)
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

-- Recette à l'hôtel des ventes (prix relevé par le scan) : texte court et couleur.
local function recipeAH(itemID)
    local V = WK.modules.Value
    if not itemID or not V:HasAHPrices() then return nil end
    local ah = V:Prices(itemID)
    if ah then
        local age = V:AuctionAge(itemID)
        local when = age and (age == 0 and T("vu aujourd'hui") or string.format(T("vu il y a %d j"), age)) or nil
        -- Prix précis pour une recette (« 1 po 50 pa » plutôt que « 1 po »)
        local g, sv = math.floor(ah / 10000), math.floor((ah % 10000) / 100)
        local price = (g > 0 and g < 100 and sv > 0) and string.format("%d %s %d %s", g, T("po"), sv, T("pa")) or UI:PlainMoney(ah)
        return string.format(T("HV : %s"), price) .. (when and (" (" .. when .. ")") or ""), C.positive
    end
    return T("pas vu à l'HV"), C.dim
end

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
    title:SetPoint("TOPRIGHT", -400, -14)
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
    local tierNums = {}
    for i, rk in ipairs(RANKS) do
        rankLabels[i] = UI:Text(head, 10, C.muted)
        rankLabels[i]:SetText(rk[1])
        -- palier sous la barre (75, 150, 225, 300)
        tierNums[i] = UI:Text(head, 9, C.dim)
        tierNums[i]:SetText(tostring(rk[2]))
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
        local mx = math.max(10, math.min(w - 10, w * math.min(rank, 300) / 300))
        for i, rk in ipairs(RANKS) do
            local tx = w * i / #RANKS
            local n = tierNums[i]
            n:ClearAllPoints()
            if i == #RANKS then n:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -4)
            else n:SetPoint("TOP", bar, "BOTTOMLEFT", tx, -4) end
            -- palier atteint : couleur d'accent ; masqué s'il gêne la valeur du perso
            if rank >= rk[2] then n:SetTextColor(UI:Accent()) else n:SetTextColor(unpack(C.dim)) end
            n:SetShown(math.abs(tx - mx) > 28)
        end
        marker:ClearAllPoints()
        marker:SetPoint("TOP", bar, "BOTTOMLEFT", mx, -4)
        marker:SetText(tostring(rank))
        marker:SetTextColor(UI:Accent())
        bar:SetValue(math.min(rank, 300) / 300)
    end

    -- « Ouvrir le métier ». Par l'API si le client l'a ; sinon un bouton sécurisé lance le sort
    -- du métier. Ce bouton sécurisé n'est PAS dans la fenêtre (sinon le jeu bloquerait sa
    -- fermeture en combat) : il est posé par-dessus, hors combat seulement.
    -- Lien du métier dans le chat (+ texte personnalisé), pour tous les métiers.
    local linkBtn = UI:Button(head, "Link tchat", nil, 32, "secondary")
    linkBtn:SetPoint("TOPRIGHT", -16, -18)
    linkBtn.tooltip = "Colle dans le chat le lien de la fenêtre du métier, suivi de ton texte s'il est activé. Le lien est lu à l'ouverture du métier : la première fois, l'addon ouvre et referme la fenêtre tout seul (perso connecté)."
    linkBtn:SetScript("OnClick", function()
        local c = WK.DB.global.characters[tab.key]
        WK.modules.Recipes:LinkToChat(c, tab.key, tab.prof)
    end)

    local open = UI:Button(head, "Ouvrir le métier", 170, 32, "primary", "play")
    open:SetPoint("TOPRIGHT", linkBtn, "TOPLEFT", -8, 0)
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
    note:SetPoint("TOPRIGHT", -16, -58)
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
    local modeSeg = UI:Segmented(parent, { { "recipes", "Recettes" }, { "guide", "Guide" }, { "missing", "Manquantes" } },
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
        r:SetScript("OnClick", function(row) if IsShiftKeyDown() and row.rec then WK.modules.Recipes:LinkRecipe(row.rec) end end)
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
    local TILE_H = 90
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
        -- valeur à l'heure (tes sessions de farm) et tournée guidée par les coins déjà récoltés
        t.rate = UI:Text(t, 11)
        t.rate:SetPoint("TOPLEFT", 12, -46)
        t.tour = UI:Button(t, "Tournée", nil, 20, "secondary", "map")
        t.tour:SetPoint("TOPRIGHT", -8, -42)
        t.tour:SetScript("OnClick", function(b) WK.modules.Gathering:StartTour(b.kind, b.zone, b.items) end)
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
        -- valeur à l'heure mesurée sur tes sessions : les zones mesurées d'abord, la meilleure en tête
        local rates = G:ZoneRates(kind)
        local rateOf = function(z) local e = rates[z] or rates[T(z)]; return e and e.rate or nil end
        table.sort(best, function(a, b)
            local ra, rb = rateOf(a), rateOf(b)
            if (ra ~= nil) ~= (rb ~= nil) then return ra ~= nil end
            if ra and rb and ra ~= rb then return ra > rb end
            return false
        end)
        for i, z in ipairs(best) do
            if z == here or T(z) == here then table.remove(best, i); table.insert(best, 1, z); break end
        end
        local goodItems = {}
        for _, d in ipairs(list) do if d.good then goodItems[d.id] = true end end
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
            local e = rates[z] or rates[T(z)]
            if e then
                t.rate:SetText(UI:GoldText(math.floor(e.rate)) .. UI:Hex(C.muted) .. " " .. T("par heure") .. "  ·  "
                    .. string.format(T("%d session(s)"), e.sessions) .. "|r")
            else
                t.rate:SetText(UI:Hex(C.dim) .. T("pas encore mesuré (session de farm)") .. "|r")
            end
            local spots = kind ~= "skin" and G:ZoneSpots(kind, z, goodItems) or {}
            t.tour.kind, t.tour.zone, t.tour.items = kind, z, goodItems
            t.tour:SetShown(#spots >= 2)
            if #spots >= 2 then t.tour:SetLabel(string.format(T("Tournée (%d)"), #spots)); t.tour:SetWidth(t.tour.label:GetStringWidth() + 40) end
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
    -- jusqu'où compter les matériaux : 75, 150, 225 ou tout le guide (Max = 300, retenu par métier)
    local function targets()
        local ui = WK.DB.global.settings.ui
        ui.guideTarget = ui.guideTarget or {}
        return ui.guideTarget
    end
    function tab:Target()
        local t = targets()[self.prof or ""]
        if t == "max" or not t or t >= 300 then return nil end -- 300 = bout du guide = Max
        return t
    end
    local tgtSeg = UI:Segmented(matsCard, { { 75, "75" }, { 150, "150" }, { 225, "225" }, { "max", "Max" } },
        function(v)
            targets()[tab.prof or ""] = v
            if tab.lastC and tab.lastPr then tab:RefreshGuide(tab.lastC, tab.lastPr) end
        end, 24)
    tgtSeg:SetPoint("TOPLEFT", 12, -36)
    tab.tgtSeg = tgtSeg
    local matsSum = UI:Text(matsCard, 11, C.muted)
    matsSum:SetPoint("TOPLEFT", 16, -68)
    matsSum:SetPoint("TOPRIGHT", -16, -68)
    matsSum:SetJustifyH("LEFT")
    local ahBtn = UI:Button(matsCard, "Liste d'achat", nil, 28, "primary", "search")
    ahBtn:SetPoint("BOTTOMLEFT", 12, 46)
    ahBtn:SetPoint("BOTTOMRIGHT", -12, 46)
    local matsTotal = UI:Text(matsCard, 13)
    matsTotal:SetPoint("BOTTOMRIGHT", -16, 84)
    matsTotal:SetJustifyH("RIGHT")
    ahBtn.tooltip = "Crée une liste d'achat avec les composants qui manquent sur le compte ; à l'hôtel des ventes, onglet « Achat » de Warband Keeper (en bas de la fenêtre)."
    ahBtn:SetScript("OnClick", function() WK.modules.Recipes:GuideToList(tab.prof, tab.rank, tab.known, tab.effTarget) end)
    local mailBtn = UI:Button(matsCard, "Envoyer à ce perso", nil, 28, "secondary", "mail")
    mailBtn:SetPoint("BOTTOMLEFT", 12, 12)
    mailBtn:SetPoint("BOTTOMRIGHT", -12, 12)
    mailBtn.tooltip = "Crée des règles d'envoi pour que tes autres persos lui postent ces composants (les règles existantes ne sont pas modifiées)."
    mailBtn:SetScript("OnClick", function()
        local added, skipped = WK.modules.Recipes:GuideMailRules(tab.prof, tab.key)
        WK:Print(string.format(T("Guide : %d règle(s) d'envoi ajoutée(s), %d déjà existante(s)."), added, skipped))
    end)
    local mscroll = UI:Scroll(matsCard)
    mscroll:SetPoint("TOPLEFT", 10, -90)
    mscroll:SetPoint("BOTTOMRIGHT", -8, 122)
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
                local ahText, ahCol = recipeAH(s.m.itemID)
                if ahText then GameTooltip:AddLine(ahText, ahCol[1], ahCol[2], ahCol[3]) end
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
                local ahText, ahCol = recipeAH(st.learn)
                if ahText then GameTooltip:AddLine(ahText, ahCol[1], ahCol[2], ahCol[3]) end
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
        self.lastC, self.lastPr = c, pr
        local target = self:Target()
        -- cible déjà atteinte : on passe au palier suivant
        if target and rank >= target then
            target = nil
            for _, t in ipairs({ 75, 150, 225 }) do if t > rank then target = t break end end
        end
        self.effTarget = target
        self.tgtSeg:Select(target or "max")
        matsCard.title:SetText(target and string.format(T("Matériaux jusqu'à %d"), target) or T("Matériaux jusqu'au max"))
        local steps, mats, total, g = R:GuidePlan(self.prof, rank, self.known, target)
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
                    local ahText, ahCol = recipeAH(st.learn)
                    if ahText then src = src .. "  ·  " .. UI:Hex(ahCol) .. ahText .. "|r" end
                end
            else
                src = T("Maître")
            end
            r.sub:SetText(src .. "  ·  " .. table.concat(reag, ", "))
            -- coût de l'étape (composants au prix choisi, sinon prix du guide)
            local stepCost = 0
            if e.status ~= "done" then
                for _, rg in ipairs(st.reagents or {}) do stepCost = stepCost + R:GuidePrice(rg[1]) * rg[2] * n end
                for _, f in ipairs(st.first or {}) do
                    for _, rg in ipairs(f.reagents or {}) do stepCost = stepCost + R:GuidePrice(rg[1]) * rg[2] * f.crafts end
                end
            end
            local costTxt = stepCost > 0 and ("  " .. UI:GoldText(stepCost)) or ""
            if e.status == "done" then
                r.state:SetText(UI:Hex(C.positive) .. T("fait") .. "|r")
                r:SetAlpha(0.5)
                r.bg:SetColor(unpack(C.surface)); r.border:SetColor(unpack(C.border))
            elseif e.status == "current" then
                r.state:SetText(UI:Hex(C.gold) .. T("en cours") .. "|r" .. costTxt)
                r:SetAlpha(1)
                r.bg:SetColor(unpack(C.surface2)); r.border:SetColor(UI:Accent())
            else
                r.state:SetText(costTxt)
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
        -- ce que les persos ont déjà : économisé sur le total
        local saved = 0
        for _, m in ipairs(mats or {}) do saved = saved + math.min(m.have, m.need) * (m.unit or 0) end
        matsTotal:SetText(T("Total à acheter : ") .. UI:GoldText(total)
            .. (saved > 0 and ("\n" .. UI:Hex(C.muted) .. string.format(T("déjà sur tes persos : %s"), WK:FormatMoney(saved)) .. "|r") or ""))
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

    -----------------------------------------------------------------------
    -- Recettes manquantes : celles que le perso n'a pas, où les obtenir, prix à l'HV.
    -----------------------------------------------------------------------
    local missing = CreateFrame("Frame", nil, parent)
    missing:SetPoint("TOPLEFT", 0, fTop)
    missing:SetPoint("BOTTOMRIGHT")
    missing:Hide()
    tab.missFilter = "now"
    local missSeg = UI:Segmented(missing, { { "now", "Apprenables" }, { "all", "Toutes" } },
        function(k) tab.missFilter = k; tab:Refresh() end, 34)
    missSeg:SetPoint("TOPRIGHT")
    missSeg:Select("now")
    local missInfo = UI:Text(missing, 11, C.muted)
    missInfo:SetPoint("RIGHT", missSeg, "LEFT", -12, 0)
    missInfo:SetJustifyH("RIGHT")
    local mlist = UI:Scroll(missing)
    mlist:SetPoint("TOPLEFT", 0, -46)
    mlist:SetPoint("BOTTOMRIGHT")
    local missEmpty = UI:Text(missing, 12, C.muted)
    missEmpty:SetPoint("TOPLEFT", mlist, "TOPLEFT", 20, -40)
    missEmpty:SetPoint("TOPRIGHT", mlist, "TOPRIGHT", -20, -40)
    missEmpty:SetJustifyH("CENTER")
    if missEmpty.SetWordWrap then missEmpty:SetWordWrap(true) end
    local missRows = UI:Pool(function()
        local r = CreateFrame("Button", nil, mlist.child)
        r:SetHeight(46)
        UI:Panel(r, 12, C.surface, C.border)
        r.icon = UI:RoundIcon(r, 28)
        r.icon:SetPoint("LEFT", 12, 0)
        r.level = UI:Text(r, 12)
        r.level:SetPoint("TOPRIGHT", -14, -9)
        r.level:SetJustifyH("RIGHT")
        r.state = UI:Text(r, 10)
        r.state:SetPoint("TOPRIGHT", r.level, "BOTTOMRIGHT", 0, -4)
        r.state:SetJustifyH("RIGHT")
        r.name = UI:Text(r, 12)
        r.name:SetPoint("TOPLEFT", 52, -9)
        r.name:SetPoint("TOPRIGHT", -130, -9)
        r.sub = UI:Text(r, 10, C.muted)
        r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -4)
        r.sub:SetPoint("TOPRIGHT", r.name, "BOTTOMRIGHT", 0, -4)
        r:SetScript("OnEnter", function(s)
            local d = s.data
            if not d then return end
            WK.UI:TooltipOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetText(s.title or "?", 1, 1, 1)
            GameTooltip:AddLine(string.format(T("Niveau requis : %d"), d.l), 0.8, 0.8, 0.8)
            if d.t then
                GameTooltip:AddLine(T("S'apprend chez le maître."), 0.6, 1, 0.5)
            elseif d.r then
                GameTooltip:AddLine(string.format(T("Recette : %s"), (UI:ItemInfo(d.r)) or "?"), 1, 0.82, 0)
                local ahText, ahCol = recipeAH(d.r)
                if ahText then GameTooltip:AddLine(ahText, ahCol[1], ahCol[2], ahCol[3]) end
                if d.p then GameTooltip:AddDoubleLine(T("Prix chez le vendeur"), WK:FormatMoney(d.p), 0.8, 0.8, 0.8, 1, 1, 1) end
                if d.v then
                    GameTooltip:AddLine(T("Vendeurs :"), 0.8, 0.8, 0.8)
                    for _, v in ipairs(d.v) do GameTooltip:AddDoubleLine("  " .. v[1], v[2] and T(v[2]) or "", 1, 1, 1, 0.7, 0.7, 0.7) end
                else
                    GameTooltip:AddLine(T("Pas vendue : à trouver (butin, quête ou hôtel des ventes)."), 0.8, 0.8, 0.8, true)
                end
            end
            if d.t then GameTooltip:AddLine(T("Clic droit : favori (mis en avant chez le maître)"), 0.6, 0.6, 0.6) end
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        if r.RegisterForClicks then r:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
        r:SetScript("OnClick", function(s, btn)
            if btn == "RightButton" and s.favName then
                WK.modules.ProfHelp:ToggleFav(s.favName); tab:Refresh() return
            end
            if IsShiftKeyDown() and s.data then
                local _, link = WK.GetItemInfo(s.data.r or s.data.o or 0)
                if link then WK.InsertChatLink(link) end
            end
        end)
        return r
    end)

    function tab:RefreshMissing(c, pr)
        local rank = pr.rank or 0
        local list, total = WK.modules.Recipes:Missing(c, self.prof)
        list = list or {}
        local shown = {}
        for _, d in ipairs(list) do
            if self.missFilter == "all" or d.l <= rank then table.insert(shown, d) end
        end
        -- Apprenables : les plus hautes d'abord (les plus utiles maintenant) ; puis les autres par niveau.
        table.sort(shown, function(a, b)
            local la, lb = a.l <= rank, b.l <= rank
            if la ~= lb then return la end
            if la then return a.l > b.l end
            return a.l < b.l
        end)
        local learnable = 0
        for _, d in ipairs(list) do if d.l <= rank then learnable = learnable + 1 end end
        missInfo:SetText(string.format(T("%d manquantes sur %d · %d apprenables"), #list, total or 0, learnable))
        missRows:Reset()
        local y = 0
        for i, d in ipairs(shown) do
            if i > 250 then break end
            local r = missRows:Get()
            r.data = d
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -y)
            r:SetPoint("TOPRIGHT", 0, -y)
            local name, ic, qr, qg, qb = stepInfo({ out = d.o, spell = d.s })
            r.title = name
            r.icon:SetTexture(ic)
            -- favori chez le maître : nom du sort de la recette (celui que le maître affiche)
            r.favName = d.t and (WK.SpellInfo(d.s) or name) or nil
            local fav = r.favName and WK.modules.ProfHelp:Config().fav[r.favName]
            r.name:SetText((fav and (UI:Hex(C.gold) .. "*|r ") or "") .. (name or "?"))
            r.name:SetTextColor(qr or 1, qg or 1, qb or 1)
            local src
            if d.t then
                src = T("Maître")
            elseif d.r then
                src = T("Recette : ") .. ((UI:ItemInfo(d.r)) or "?")
                if d.v then src = src .. " " .. T("chez") .. " " .. vendorText(d.v, 2)
                else src = src .. " " .. UI:Hex(C.dim) .. T("(à trouver)") .. "|r" end
                local ahText, ahCol = recipeAH(d.r)
                if ahText then src = src .. "  ·  " .. UI:Hex(ahCol) .. ahText .. "|r" end
            else
                src = T("À trouver")
            end
            r.sub:SetText(src)
            r.level:SetText(string.format(T("Niv. %d"), d.l))
            local ok = d.l <= rank
            r.state:SetText(ok and (UI:Hex(C.positive) .. T("apprenable") .. "|r") or (UI:Hex(C.dim) .. string.format(T("encore %d pts"), d.l - rank) .. "|r"))
            y = y + 52
        end
        mlist:SetContentHeight(y)
        missEmpty:SetShown(#shown == 0)
        local scanned = false
        for _ in pairs(c.recipes or {}) do scanned = true; break end
        if not scanned then
            missEmpty:SetText(T("Ouvre la fenêtre de ce métier sur ce perso pour savoir quelles recettes il connaît."))
            missEmpty:Show()
        elseif #list == 0 then
            missEmpty:SetText(T("Toutes les recettes sont connues !"))
        else
            missEmpty:SetText(T("Aucune recette apprenable pour l'instant : choisis « Toutes »."))
        end
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
            self.missFilter = "now"
            missSeg:Select("now")
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

        -- Herboristerie, Dépeçage, Pêche : pas de fenêtre de métier, donc pas de lien à coller.
        local gk = WK.modules.Gathering:Kind(self.prof)
        local noLink = gk == "herb" or gk == "skin" or self.prof == "Pêche" or self.prof == "Fishing"
        linkBtn:SetShown(not noLink)
        open:ClearAllPoints()
        if noLink then open:SetPoint("TOPRIGHT", -16, -18) else open:SetPoint("TOPRIGHT", linkBtn, "TOPLEFT", -8, 0) end

        -- Ouverture : seulement pour le perso connecté et un métier qui a une fenêtre.
        local canOpen = isMe and #all > 0
        open:SetShown(canOpen)
        -- « Recettes lues le… » : sur la ligne des boutons (place libre quand « Ouvrir » est caché),
        -- pour ne pas tomber sur les libellés des rangs.
        note:ClearAllPoints()
        if noLink then note:SetPoint("RIGHT", head, "TOPRIGHT", -16, -34)
        else note:SetPoint("RIGHT", linkBtn, "LEFT", -12, 0) end
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
            modeSeg:Hide(); guide:Hide(); missing:Hide()
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
        local showMissing = hasGuide and self.mode == "missing"
        guide:SetShown(showGuide)
        missing:SetShown(showMissing)
        local recipesMode = not showGuide and not showMissing
        filter:SetShown(recipesMode); search:SetShown(recipesMode); scroll:SetShown(recipesMode)
        if showGuide then
            empty:Hide()
            self:RefreshGuide(c, pr)
            return
        end
        if showMissing then
            empty:Hide()
            self:RefreshMissing(c, pr)
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
            -- Temps de recharge
            local cd = c.cooldowns and c.cooldowns[rec.key]
            if cd then
                local left = cd.readyAt - time()
                table.insert(bits, left > 0 and (UI:Hex(C.warning) .. string.format(T("recharge : %s"), WK:FormatTime(left)) .. "|r")
                    or (UI:Hex(C.positive) .. T("prête") .. "|r"))
            end
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

---------------------------------------------------------------------------
-- Fabriquer ou vendre : composants du compte qu'une recette d'un de tes persos valorise mieux
-- que la vente brute (Modules/ProfHelp.lua : CraftOrSellList). « File » : fabrications ajoutées à la file.
---------------------------------------------------------------------------
local function CraftSell(page, parent)
    local tab = {}
    local card = UI:Card(parent, "Fabriquer ou vendre ?", "composants de tes sacs, banques et courriers · prix HV du jour, sinon marchand")
    card:SetPoint("TOPLEFT", 0, TOP)
    card:SetPoint("BOTTOMRIGHT")
    local cols = { { "VENDRE BRUT", -360 }, { "GAIN", -150 } }
    local hName = UI:Text(card, 10, C.dim); hName:SetPoint("TOPLEFT", 16, -44); hName:SetText(T("COMPOSANT"))
    local hRec = UI:Text(card, 10, C.dim); hRec:SetPoint("TOPRIGHT", -200, -44); hRec:SetText(T("MEILLEURE RECETTE"))
    hRec:Hide()
    for _, c in ipairs(cols) do
        local h = UI:Text(card, 10, C.dim); h:SetPoint("TOPRIGHT", c[2], -44); h:SetJustifyH("RIGHT"); h:SetText(T(c[1]))
    end
    local sc = UI:Scroll(card)
    sc:SetPoint("TOPLEFT", 10, -62)
    sc:SetPoint("BOTTOMRIGHT", -8, 10)
    local empty = UI:Text(card, 12, C.muted)
    empty:SetPoint("TOPLEFT", 16, -70); empty:SetPoint("RIGHT", -16, 0); empty:SetJustifyH("LEFT")
    if empty.SetWordWrap then empty:SetWordWrap(true) end
    empty:SetText(T("Rien à fabriquer de plus rentable pour l'instant : il faut des prix HV (scan) et des recettes lues à l'ouverture des métiers."))
    local rows = UI:Pool(function()
        local r = CreateFrame("Frame", nil, sc.child)
        r:SetHeight(40)
        r.bg = UI:Rounded(r, 9, 0, "BACKGROUND", 1); r.bg:SetColor(unpack(C.surface2))
        r.icon = UI:RoundIcon(r, 22); r.icon:SetPoint("LEFT", 8, 0)
        r.name = UI:Text(r, 12); r.name:SetPoint("TOPLEFT", 38, -5); r.name:SetPoint("RIGHT", -400, 0)
        r.rec = UI:Text(r, 10, C.muted); r.rec:SetPoint("TOPLEFT", 38, -22); r.rec:SetPoint("RIGHT", -400, 0)
        r.raw = UI:Text(r, 12); r.raw:SetPoint("RIGHT", -352, 0); r.raw:SetJustifyH("RIGHT")
        r.gain = UI:Text(r, 12); r.gain:SetPoint("RIGHT", -142, 0); r.gain:SetJustifyH("RIGHT")
        r.add = UI:Button(r, "File", nil, 24, "primary", "plus")
        r.add:SetPoint("RIGHT", -10, 0)
        r.add:SetScript("OnClick", function(b)
            if b.key and b.n and b.n > 0 then
                WK.modules.Recipes:AddToList(b.key, b.n)
                WK:Print(string.format(T("%d x %s ajouté(s) à la file de fabrication."), b.n, b.recName or "?"))
            end
        end)
        return r
    end)
    function tab:Refresh()
        rows:Reset()
        local list = WK.modules.ProfHelp:CraftOrSellList()
        local y, shown = 0, 0
        for _, e in ipairs(list) do
            if e.gain > 0 and shown < 60 then
                shown = shown + 1
                local r = rows:Get()
                r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:SetPoint("TOPRIGHT", 0, -y)
                local name, icon, qr, qg, qb = UI:ItemInfo(e.id)
                r.icon:SetTexture(icon)
                r.name:SetText((name or "?") .. "  " .. UI:Hex(C.muted) .. "x" .. e.count .. "|r")
                r.name:SetTextColor(qr or 1, qg or 1, qb or 1)
                local c = WK.DB.global.characters[e.best.crafter]
                r.rec:SetText(string.format(T("%d x %s"), e.crafts, e.best.rec.name) .. (c and ("  ·  " .. WK:CharName(c, e.best.crafter)) or ""))
                r.raw:SetText(UI:GoldText(math.floor(e.raw)))
                r.gain:SetText(UI:Hex(C.positive) .. "+" .. WK:FormatMoney(math.floor(e.gain)) .. "|r")
                r.add.key, r.add.n, r.add.recName = e.best.rec.key, e.crafts, e.best.rec.name
                r.add:SetShown(e.crafts > 0)
                y = y + 44
            end
        end
        sc:SetContentHeight(y)
        empty:SetShown(shown == 0)
    end
    return tab
end

---------------------------------------------------------------------------
-- Réglages des métiers (roue dentée du bandeau) : ce métier (au choix), infobulles,
-- fenêtres du jeu, file et recharges, récolte, désenchantements notés. Deux colonnes.
---------------------------------------------------------------------------
local function Settings(page, parent)
    -----------------------------------------------------------------------
    -- Réglages des métiers (roue dentée) : ce métier, infobulles, fenêtres du jeu,
    -- file et recharges, récolte, désenchantements notés. Cartes sur deux colonnes.
    -----------------------------------------------------------------------
    local tab = {}
    local function targets()
        local ui = WK.DB.global.settings.ui
        ui.guideTarget = ui.guideTarget or {}
        return ui.guideTarget
    end
    local settings = UI:Scroll(parent)
    settings:SetPoint("TOPLEFT", 0, TOP)
    settings:SetPoint("BOTTOMRIGHT")
    local sroot = settings.child
    local scards = {}
    local function scard(title, sub, nRows, extra)
        local cd = UI:Card(sroot, title, sub)
        cd.h = 40 + nRows * 46 + (extra or 0) + 8
        cd:SetHeight(cd.h)
        table.insert(scards, cd)
        return cd
    end
    local stoggles = {}
    local function stoggle(cd, i, label, desc, get, set)
        local tg = UI:Toggle(cd, get, set)
        table.insert(stoggles, tg)
        return UI:SettingRow(cd, -40 - (i - 1) * 46, label, desc, tg, 80)
    end
    local PHc = function() return WK.modules.ProfHelp:Config() end
    local GHc = function() return WK.modules.Gathering:HelpConfig() end
    local uic = function() return WK.DB.global.settings.ui end

    -- Ce métier : lien dans le chat, palier visé, composants envoyés
    local mine = scard("Ce métier", nil, 1, 150)
    -- choix du métier (et du perso) que règle cette carte
    local profPick = UI:Dropdown(mine, 260, 26, {}, function(k)
        local key, prof = k:match("^(.-)\001(.*)$")
        tab.key, tab.prof = key, prof
        tab:RefreshSettings()
    end)
    profPick:SetPoint("TOPRIGHT", -14, -9)
    local linkRow = stoggle(mine, 1, "Lien du métier dans le chat", "Texte ajouté après le lien (bouton « Link tchat », ou Maj + clic sur le métier).",
        function() return tab.prof and WK.modules.Recipes:LinkSettings(tab.prof).on end,
        function(v) if tab.prof then WK.modules.Recipes:LinkSettings(tab.prof).on = v; tab:RefreshSettings() end end)
    local linkInput = UI:Input(mine, 300, 30, "Ex. : je fabrique gratuitement, apportez les composants")
    linkInput:SetPoint("TOPLEFT", 16, -88)
    linkInput:SetPoint("RIGHT", -16, 0)
    linkInput.onChange = function(t)
        if tab.prof and not tab.fillingLink then WK.modules.Recipes:LinkSettings(tab.prof).text = t or ""; tab:RefreshLinkPreview() end
    end
    local linkPreview = UI:Text(mine, 10, C.muted)
    linkPreview:SetPoint("TOPLEFT", 16, -124)
    linkPreview:SetPoint("RIGHT", -16, 0)
    linkPreview:SetJustifyH("LEFT")
    if linkPreview.SetWordWrap then linkPreview:SetWordWrap(true) end
    local tgtRow = CreateFrame("Frame", nil, mine)
    tgtRow:SetPoint("TOPLEFT", 16, -158); tgtRow:SetPoint("RIGHT", -16, 0); tgtRow:SetHeight(32)
    local tgtLbl = UI:Text(tgtRow, 12); tgtLbl:SetPoint("TOPLEFT", 0, -2); tgtLbl:SetText("Palier visé du guide")
    local tgtDesc = UI:Text(tgtRow, 10, C.muted); tgtDesc:SetPoint("TOPLEFT", 0, -18); tgtDesc:SetText("Matériaux comptés jusque-là (guide, marchand).")
    local tgtSeg2 = UI:Segmented(tgtRow, { { 75, "75" }, { 150, "150" }, { 225, "225" }, { "max", "Max" } },
        function(v) targets()[tab.prof or ""] = v end, 24)
    tgtSeg2:SetPoint("TOPRIGHT", 0, -2)
    local mailRow = CreateFrame("Frame", nil, mine)
    mailRow:SetPoint("TOPLEFT", 16, -196); mailRow:SetPoint("RIGHT", -16, 0); mailRow:SetHeight(32)
    local mailLbl = UI:Text(mailRow, 12); mailLbl:SetPoint("TOPLEFT", 0, -2); mailLbl:SetText("Recevoir les composants")
    local mailDesc = UI:Text(mailRow, 10, C.muted); mailDesc:SetPoint("TOPLEFT", 0, -18); mailDesc:SetText("Règles d'envoi : tes autres persos postent ce qui manque.")
    local mailBtn2 = UI:Button(mailRow, "Créer les règles", nil, 26, "secondary", "mail")
    mailBtn2:SetPoint("TOPRIGHT", 0, -2)
    mailBtn2:SetScript("OnClick", function()
        local added, skipped = WK.modules.Recipes:GuideMailRules(tab.prof, tab.key)
        WK:Print(string.format(T("Guide : %d règle(s) d'envoi ajoutée(s), %d déjà existante(s)."), added, skipped))
    end)
    local mineNote = UI:Text(mine, 11, C.muted)
    mineNote:SetPoint("TOPLEFT", 16, -44); mineNote:SetPoint("RIGHT", -16, 0); mineNote:SetJustifyH("LEFT")
    if mineNote.SetWordWrap then mineNote:SetWordWrap(true) end
    function tab:RefreshLinkPreview()
        if not self.prof then return end
        local c = WK.DB.global.characters[self.key]
        local text, real = WK.modules.Recipes:LinkText(c, self.key, self.prof)
        local saved = c and c.profLinks and c.profLinks[self.prof]
        linkPreview:SetText(T("Aperçu : ") .. UI:Hex(C.text) .. text .. "|r" ..
            (real and ("  ·  " .. string.format(T("Lien enregistré le %s"), date("%d/%m à %H:%M", saved.t)))
                or ("\n" .. T("Pas encore de lien : ouvre la fenêtre du métier sur ce perso."))))
    end

    local wins = scard("Fenêtres du jeu", "panneaux collés aux fenêtres", 4)
    stoggle(wins, 1, "Marchand", "Ce qui manque pour monter tes métiers jusqu'au palier visé, avec Acheter et Tout acheter.",
        function() return uic().merchantPanel ~= false end, function(v) uic().merchantPanel = v end)
    stoggle(wins, 2, "Sacs : désenchanter ou vendre", "Enchanteur : objets à désenchanter ou à vendre, et un bouton pour enchaîner (/wk de).",
        function() return PHc().dePanel end, function(v) PHc().dePanel = v end)
    stoggle(wins, 3, "Échange : enchantements", "Tes enchantements pour l'objet posé, et l'annonce de ce que tu sais faire.",
        function() return PHc().trade end, function(v) PHc().trade = v end)
    stoggle(wins, 4, "Maître de métier", "Recettes à apprendre ici : favoris, utiles pour le guide, déjà connues d'un autre perso.",
        function() return PHc().trainer end, function(v) PHc().trainer = v end)

    local queue = scard("File et recharges", nil, 3)
    stoggle(queue, 1, "File à l'écran", "Fenêtre du métier ouverte : la prochaine recette de ta file et un bouton pour la fabriquer.",
        function() return PHc().queueHud end, function(v) PHc().queueHud = v; if UI.RefreshCraftHUD then UI:RefreshCraftHUD() end end)
    stoggle(queue, 2, "Décompter en fabriquant", "Chaque fabrication réussie retire une ligne de la file.",
        function() return PHc().queueAuto end, function(v) PHc().queueAuto = v end)
    stoggle(queue, 3, "Recharge terminée", "Transmutation, étoffe lunaire… : un message quand elle est de nouveau prête, sur n'importe quel perso.",
        function() return PHc().cdAlert end, function(v) PHc().cdAlert = v end)

    local gath = scard("Récolte", "Herboristerie, Minage", 4)
    stoggle(gath, 1, "Rang suivant à apprendre", "Un métier au plafond de son rang (75, 150, 225) : un message te dit d'aller voir un maître.",
        function() return GHc().rankAlert end, function(v) GHc().rankAlert = v end)
    stoggle(gath, 2, "Nouvelles ressources", "Une montée d'Herboristerie ou de Minage qui débloque une herbe ou un filon le nomme.",
        function() return GHc().nodeToast end, function(v) GHc().nodeToast = v end)
    stoggle(gath, 3, "Rappel du pistage", "Herboristerie ou Minage connus mais pistage éteint : rappel en changeant de zone (hors ville et donjon).",
        function() return GHc().trackRemind end, function(v) GHc().trackRemind = v end)
    stoggle(gath, 4, "Compétence sur la minicarte", "Au survol d'une herbe ou d'un filon : la compétence requise et la tienne, aux couleurs du jeu.",
        function() return GHc().nodeTip end, function(v) GHc().nodeTip = v end)

    local delog = scard("Désenchantements notés", "affinent les moyennes", 0, 56)
    local deInfo = UI:Text(delog, 11, C.muted); deInfo:SetPoint("TOPLEFT", 16, -44); deInfo:SetPoint("RIGHT", -16, 0); deInfo:SetJustifyH("LEFT")
    local deClear = UI:Button(delog, "Effacer", nil, 26, "danger", "trash")
    deClear:SetPoint("TOPLEFT", 16, -68)
    deClear:SetScript("OnClick", function() wipe(PHc().deLog); tab:RefreshSettings() end)

    -- deux colonnes : chaque carte sous la précédente de sa colonne
    local function layoutSettings()
        local W = math.max(400, (settings:GetWidth() or 800) - 10)
        sroot:SetWidth(W)
        local cw = math.floor((W - GAP) / 2)
        local colY = { 0, 0 }
        for _, cd in ipairs(scards) do
            if cd:IsShown() then
                local col = colY[1] <= colY[2] and 1 or 2
                cd:ClearAllPoints()
                cd:SetPoint("TOPLEFT", (col - 1) * (cw + GAP), -colY[col])
                cd:SetWidth(cw)
                colY[col] = colY[col] + cd.h + GAP
            end
        end
        settings:SetContentHeight(math.max(colY[1], colY[2]))
    end
    UI:OnResize(settings, function() if settings:IsShown() then layoutSettings() end end)

    -- Récolte d'Options (coins de récolte, filons récoltés, HUD) : reprise ici, après la carte Récolte
    local function adoptGather()
        if tab.gatherAdopted then return end
        tab.gatherAdopted = true
        local at = #scards + 1
        for i, cd in ipairs(scards) do if cd == gath then at = i + 1 end end
        for _, oc in ipairs(UI:SectionCards("options", "glow")) do
            oc:SetParent(sroot); oc:Show()
            oc.h = oc:GetHeight()
            table.insert(scards, at, oc); at = at + 1
        end
    end
    function tab:RefreshSettings()
        adoptGather()
        local c = WK.DB.global.characters[self.key]
        local gk = WK.modules.Gathering:Kind(self.prof)
        local noLink = gk == "herb" or gk == "skin" or self.prof == "Pêche" or self.prof == "Fishing"
        local hasGuide = WK.modules.Recipes:Guide(self.prof) ~= nil
        -- métiers du compte : le perso connecté d'abord
        local opts, myKey = {}, WK:CharKey()
        for _, e in ipairs(UI:SortedCharacters()) do
            local names = {}
            for prof in pairs(e.c.professions or {}) do table.insert(names, prof) end
            table.sort(names)
            for _, prof in ipairs(names) do
                local o = { e.key .. "\001" .. prof, prof .. "  ·  " .. WK:CharName(e.c, e.key) }
                if e.key == myKey then table.insert(opts, 1, o) else table.insert(opts, o) end
            end
        end
        if not self.prof and opts[1] then self.key, self.prof = opts[1][1]:match("^(.-)\001(.*)$") end
        profPick:SetOptions(opts)
        if self.prof then profPick:Select(self.key .. "\001" .. self.prof) end
        profPick:SetShown(#opts > 0)
        c = WK.DB.global.characters[self.key]
        gk = WK.modules.Gathering:Kind(self.prof)
        noLink = (not self.prof) or gk == "herb" or gk == "skin" or self.prof == "Pêche" or self.prof == "Fishing"
        hasGuide = self.prof ~= nil and WK.modules.Recipes:Guide(self.prof) ~= nil
        -- lignes de la carte « Ce métier » selon ce qui s'applique
        local y = -40
        linkRow:SetShown(not noLink)
        linkInput:SetShown(not noLink); linkPreview:SetShown(not noLink)
        if not noLink then
            local cfg = WK.modules.Recipes:LinkSettings(self.prof)
            if not linkInput.edit:HasFocus() then
                self.fillingLink = true; linkInput:SetText(cfg.text or ""); self.fillingLink = nil
            end
            self:RefreshLinkPreview()
            y = -40 - 118
        end
        tgtRow:SetShown(hasGuide); mailRow:SetShown(hasGuide)
        if hasGuide then
            tgtRow:ClearAllPoints(); tgtRow:SetPoint("TOPLEFT", 16, y); tgtRow:SetPoint("RIGHT", -16, 0)
            local tv = targets()[self.prof or ""]
            tgtSeg2:Select((tv == nil or tv == "max" or (tonumber(tv) or 0) >= 300) and "max" or tv)
            mailRow:ClearAllPoints(); mailRow:SetPoint("TOPLEFT", 16, y - 40); mailRow:SetPoint("RIGHT", -16, 0)
            y = y - 80
        end
        mineNote:SetShown(noLink and not hasGuide)
        mineNote:SetText(T("Rien à régler pour ce métier : les réglages ci-dessous valent pour tous."))
        if noLink and not hasGuide then y = y - 30 end
        mine.h = -y + 10
        mine:SetHeight(mine.h)
        local n, tiers = 0, 0
        for _, e in pairs(PHc().deLog) do n = n + (e.n or 0); tiers = tiers + 1 end
        deInfo:SetText(string.format(T("%d désenchantement(s) sur %d palier(s)."), n, tiers))
        deClear:SetShown(n > 0)
        for _, tg in ipairs(stoggles) do tg:Refresh() end
        local od = UI.pages and UI.pages.options
        if od and od.frame and od.Refresh then pcall(od.Refresh, od) end
        layoutSettings()
    end
    function tab:Refresh() settings:Show(); self:RefreshSettings() end
    function tab:Pick(key, prof) self.key, self.prof = key, prof end
    adoptGather() -- dès la construction : la recherche trouve ces réglages ici
    return tab
end


UI:RegisterPage({
    key = "professions", order = 4, nav = "Métiers",
    title = "Métiers",
    subtitle = "Niveaux, recettes connues par perso et liste de courses des composants.",

    Build = function(self, p)
        self.tab = "levels"
        local frames, tabs = {}, {}
        for _, k in ipairs({ "levels", "recipes", "shopping", "craftsell", "detail", "settings" }) do
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
        tabs.settings = Settings(self, frames.settings)
        tabs.craftsell = CraftSell(self, frames.craftsell)
        UI:OnResize(p, function() UI:RefreshSoon() end) -- cartes des niveaux
        self.tabs = tabs
        local seg
        local gear
        local function setTab(k)
            self.tab = k
            self.detailOpen = nil
            if seg then seg:Show() end
            if gear then gear:Show(); gear:SetActive(k == "settings") end
            for key, f in pairs(frames) do f:SetShown(key == k) end
            self:Refresh()
        end
        seg = UI:Segmented(p, { { "levels", "Niveaux" }, { "recipes", "Recettes" }, { "shopping", "File de fabrication" }, { "craftsell", "Fabriquer ou vendre" } }, setTab, 32)
        seg:SetPoint("TOPLEFT")
        seg:Select("levels")
        -- Roue dentée : tous les réglages des métiers ; un second clic revient à l'onglet d'avant
        gear = UI:IconButton(p, "gear", 32, "Réglages des métiers")
        gear:SetPoint("TOPRIGHT", 0, 0)
        function gear:SetActive(on)
            self.active = on
            local r, g, b = UI:Accent()
            if on then
                self.bg:SetColor(r, g, b, 1); self.bg:Show()
                self.icon:SetVertexColor(unpack(C.onAccent))
            else
                self.bg:Hide(); self.icon:SetVertexColor(r, g, b, 0.8)
            end
        end
        gear:HookScript("OnLeave", function(s) if s.active then s:SetActive(true) end end)
        gear:HookScript("OnEnter", function(s) if s.active then s:SetActive(true) end end)
        gear:SetScript("OnClick", function()
            if self.tab == "settings" then
                local back = self.beforeSettings or "levels"
                self.beforeSettings = nil
                if back == "detail" and self.detailKey then self:ShowDetail(self.detailKey, self.detailProf) else self:SetTab(back) end
            else
                self.beforeSettings = self.tab
                if self.tab == "detail" then tabs.settings:Pick(tabs.detail.key, tabs.detail.prof) end
                seg:Select(nil)
                setTab("settings")
            end
        end)
        self.gear = gear
        function self:SetTab(k) seg:Select(k); setTab(k) end
        -- recherche de la barre latérale : un réglage des métiers ouvre la roue
        function self:RevealSetting(row)
            local f = row
            while f do
                if f == frames.settings then
                    if self.tab ~= "settings" then gear:GetScript("OnClick")(gear) end
                    return
                end
                f = f:GetParent()
            end
        end
        -- Fiche d'un métier (dans l'onglet Niveaux) ; ShowDetail(nil) revient aux niveaux.
        function self:ShowDetail(key, prof)
            if not key then self:SetTab("levels") return end
            seg:Select("levels")
            seg:Hide() -- les onglets ne servent que sur la liste des métiers
            gear:Hide() -- la roue est dans le bandeau des onglets, caché sur la fiche
            self.detailKey, self.detailProf = key, prof
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

-- Ouvre les réglages des métiers (roue dentée du bandeau de la page Métiers), réglés sur un métier
-- du perso connecté. Appelé par les renvois de QoL et d'Options.
function UI:OpenProfSettings()
    UI:ShowPage("professions")
    local pg = UI.pages and UI.pages.professions
    if not (pg and pg.gear) then return end
    if pg.tab ~= "settings" then pg.gear:GetScript("OnClick")(pg.gear) end
end
