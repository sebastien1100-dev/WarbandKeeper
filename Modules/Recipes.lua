local ADDON_NAME, WK = ...
local M = WK:NewModule("Recipes")
local T = function(s) return WK.T(s) end

-- Recettes connues de chaque personnage, lues à l'ouverture de la fenêtre de métier.
-- c.recipes[clé] = { name, icon, prof, out = itemID produit, qty = quantité produite,
--                    reagents = { { itemID, count }, ... } }
-- La clé d'une recette est son nom (identique d'un perso à l'autre).

local function keyOf(name) return name end

-- Client moderne (C_TradeSkillUI).
local function scanModern()
    local api = C_TradeSkillUI
    if (api.IsTradeSkillLinked and api.IsTradeSkillLinked()) or (api.IsTradeSkillGuild and api.IsTradeSkillGuild()) then
        return nil
    end
    local prof
    if api.GetBaseProfessionInfo then
        local info = api.GetBaseProfessionInfo()
        prof = info and info.professionName
    end
    if not prof and api.GetTradeSkillLine then prof = select(2, api.GetTradeSkillLine()) end
    local out = {}
    for _, id in ipairs(api.GetAllRecipeIDs() or {}) do
        local r = api.GetRecipeInfo(id)
        if r and r.learned and r.name then
            local rec = { name = r.name, icon = r.icon, prof = prof, qty = 1, reagents = {} }
            local sch = api.GetRecipeSchematic and api.GetRecipeSchematic(id, false)
            if sch then
                rec.out = sch.outputItemID
                rec.qty = sch.quantityMin or 1
                for _, slot in ipairs(sch.reagentSlotSchematics or {}) do
                    local basic = (slot.required ~= false) and (slot.reagentType == nil or slot.reagentType == 1)
                    local first = slot.reagents and slot.reagents[1]
                    if basic and first and first.itemID then
                        table.insert(rec.reagents, { first.itemID, slot.quantityRequired or 1 })
                    end
                end
            end
            out[keyOf(r.name)] = rec
        end
    end
    return out, prof
end

-- Ancien client (GetTradeSkillInfo).
local function scanClassic()
    if not GetNumTradeSkills then return nil end
    local prof = GetTradeSkillLine and GetTradeSkillLine() or nil
    local out = {}
    for i = 1, GetNumTradeSkills() do
        local name, kind = GetTradeSkillInfo(i)
        if name and kind ~= "header" and kind ~= "subheader" then
            local link = GetTradeSkillItemLink and GetTradeSkillItemLink(i)
            local rec = { name = name, icon = GetTradeSkillIcon and GetTradeSkillIcon(i), prof = prof,
                out = WK:ParseItemID(link), qty = 1, reagents = {} }
            for j = 1, (GetTradeSkillNumReagents(i) or 0) do
                local _, _, count = GetTradeSkillReagentInfo(i, j)
                local id = WK:ParseItemID(GetTradeSkillReagentItemLink and GetTradeSkillReagentItemLink(i, j))
                if id then table.insert(rec.reagents, { id, count or 1 }) end
            end
            out[keyOf(name)] = rec
        end
    end
    return out, prof
end

function M:Scan()
    local recipes, prof
    if C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs then
        recipes, prof = scanModern()
    else
        recipes, prof = scanClassic()
    end
    if not recipes or not next(recipes) then return end
    local c = WK.DB:Me()
    c.recipes = c.recipes or {}
    -- On remplace les recettes de ce métier seulement.
    for k, r in pairs(c.recipes) do
        if prof and r.prof == prof then c.recipes[k] = nil end
    end
    for k, r in pairs(recipes) do c.recipes[k] = r end
    WK:NotifyChanged()
end

local pending = false
local function schedule()
    if pending then return end
    pending = true
    C_Timer.After(1, function() pending = false; M:Scan() end)
end
WK:On("TRADE_SKILL_SHOW", schedule)
WK:On("TRADE_SKILL_LIST_UPDATE", schedule)
WK:On("TRADE_SKILL_DATA_SOURCE_CHANGED", schedule)

---------------------------------------------------------------------------
-- Index du compte : qui sait fabriquer quoi.
---------------------------------------------------------------------------
function M:All()
    local index = {}
    for key, c in pairs(WK.DB.global.characters) do
        for k, r in pairs(c.recipes or {}) do
            local e = index[k]
            if not e then
                e = { key = k, name = r.name, icon = r.icon, prof = r.prof, out = r.out, qty = r.qty or 1,
                    reagents = r.reagents, crafters = {} }
                index[k] = e
            end
            table.insert(e.crafters, key)
        end
    end
    local list = {}
    for _, e in pairs(index) do table.insert(list, e) end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list, index
end

-- Nombre de fabrications possibles avec le stock de tout le compte.
function M:Craftable(rec)
    if not rec.reagents or #rec.reagents == 0 then return nil end
    local n = math.huge
    for _, rg in ipairs(rec.reagents) do
        local have = WK.modules.Inventory:AccountCount(rg[1])
        n = math.min(n, math.floor(have / math.max(1, rg[2])))
    end
    return n
end

-- Rentabilité d'une recette au prix actuel (Auctionator, sinon marchand) :
-- cost = prix des composants, sale = prix de l'objet fabriqué x quantité produite,
-- profit = sale - cost (nil si l'objet fabriqué n'a pas de prix connu).
function M:Economics(rec)
    local V = WK.modules.Value
    local cost = 0
    for _, rg in ipairs(rec.reagents or {}) do cost = cost + V:Price(rg[1]) * rg[2] end
    local sale
    if rec.out then
        local p = V:Price(rec.out)
        if p and p > 0 then sale = p * (rec.qty or 1) end
    end
    return cost, sale, sale and (sale - cost) or nil
end

---------------------------------------------------------------------------
-- Liste de courses : WK.DB.global.shopping[clé de recette] = nombre de fabrications.
---------------------------------------------------------------------------
function M:AddToList(key, n)
    local list = WK.DB.global.shopping
    list[key] = math.max(0, (list[key] or 0) + (n or 1))
    if list[key] == 0 then list[key] = nil end
    WK:NotifyChanged()
end

function M:ClearList()
    wipe(WK.DB.global.shopping)
    WK:NotifyChanged()
end

-- Composants nécessaires : { { itemID, need, have, missing, cost }, ... } et coût total manquant.
function M:Needs()
    local _, index = self:All()
    local need = {}
    for key, crafts in pairs(WK.DB.global.shopping) do
        local rec = index[key]
        if rec then
            for _, rg in ipairs(rec.reagents or {}) do
                need[rg[1]] = (need[rg[1]] or 0) + rg[2] * crafts
            end
        end
    end
    local out, total = {}, 0
    for id, n in pairs(need) do
        local have = WK.modules.Inventory:AccountCount(id)
        local missing = math.max(0, n - have)
        local cost = missing * WK.modules.Value:Price(id)
        total = total + cost
        table.insert(out, { itemID = id, need = n, have = have, missing = missing, cost = cost })
    end
    table.sort(out, function(a, b)
        if (a.missing > 0) ~= (b.missing > 0) then return a.missing > 0 end
        return a.cost > b.cost
    end)
    return out, total
end

-- Crée une liste de courses Auctionator avec les composants manquants.
function M:ExportToAuctionator()
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if not api or not api.CreateShoppingList then
        WK:Print(T("Auctionator n'est pas disponible."))
        return false
    end
    local terms, unknown = {}, 0
    for _, e in ipairs((self:Needs())) do
        if e.missing > 0 then
            local name = WK.GetItemInfo(e.itemID)
            if not name then
                unknown = unknown + 1
                if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(e.itemID) end
            else
                local term = name
                if api.ConvertToSearchString then
                    local ok, s = pcall(api.ConvertToSearchString, ADDON_NAME,
                        { searchString = name, isExact = true, quantity = e.missing })
                    if ok and s then term = s end
                end
                table.insert(terms, term)
            end
        end
    end
    if unknown > 0 then
        WK:Print(string.format(T("%d objet(s) pas encore chargés par le jeu : réessaie dans un instant."), unknown))
        if #terms == 0 then return false end
    end
    if #terms == 0 then
        WK:Print(T("Rien à acheter : tu as déjà tous les composants."))
        return false
    end
    local ok, err = pcall(api.CreateShoppingList, ADDON_NAME, "Warband Keeper", terms)
    if ok then
        WK:Print(string.format(T("Liste « Warband Keeper » créée dans Auctionator (%d objet(s))."), #terms))
    else
        WK:Print(T("Auctionator a refusé la liste : ") .. tostring(err))
    end
    return ok
end
