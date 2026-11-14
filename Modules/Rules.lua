local ADDON_NAME, WK = ...
local M = WK:NewModule("Rules")

-- Catégories d'objets proposées pour les règles (classe / sous-classe du jeu).
-- 7 = Composants d'artisanat, 3 = Gemmes, 0 = Consommables, 9 = Recettes.
M.CATEGORIES = {
    { key = "tradegoods", label = "Tous les composants d'artisanat", class = 7 },
    { key = "cloth", label = "Étoffes", class = 7, sub = 5 },
    { key = "leather", label = "Cuirs", class = 7, sub = 6 },
    { key = "metal", label = "Métaux et pierres", class = 7, sub = 7 },
    { key = "cooking", label = "Viandes et cuisine", class = 7, sub = 8 },
    { key = "herb", label = "Herbes", class = 7, sub = 9 },
    { key = "elemental", label = "Éléments", class = 7, sub = 10 },
    { key = "enchanting", label = "Enchantement", class = 7, sub = 12 },
    { key = "jewelcrafting", label = "Joaillerie", class = 7, sub = 4 },
    { key = "parts", label = "Pièces d'ingénierie", class = 7, sub = 1 },
    { key = "gems", label = "Gemmes", class = 3 },
    { key = "consumables", label = "Consommables", class = 0 },
    { key = "recipes", label = "Recettes", class = 9 },
    -- Objets « lié quand équipé » (encore libres) à partir d'une qualité : 2 vert, 3 bleu, 4 épique.
    { key = "boe", label = "Objets LQE (vert et +)", boe = 2 },
    { key = "boe_rare", label = "Objets LQE (bleu et +)", boe = 3 },
    { key = "boe_epic", label = "Objets LQE (épiques)", boe = 4 },
}
M.byKey = {}
for _, c in ipairs(M.CATEGORIES) do M.byKey[c.key] = c end

function M:CategoryLabel(key)
    local c = self.byKey[key]
    return c and WK.T(c.label) or key
end

-- Classe et sous-classe d'un objet (fonctionne même si l'objet n'est pas en cache).
function M:ItemClass(itemID)
    local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not f then return nil end
    local _, _, _, _, _, classID, subclassID = f(itemID)
    return classID, subclassID
end

-- Objet « lié quand équipé » ? Renvoie aussi sa qualité. (bindType 2 = LQE)
function M:BoE(itemID)
    local _, _, quality, _, _, _, _, _, _, _, _, _, _, bindType = WK.GetItemInfo(itemID)
    return bindType == 2, quality or 0
end

-- Règle applicable à un objet dans un magasin { items = {[id]=règle}, cats = {[clé]=règle} } :
-- règle d'objet > catégorie précise (sous-classe) > objets LQE > catégorie large (classe).
function M:Resolve(store, itemID)
    local r = store.items[itemID]
    if type(r) == "string" then -- ancien format (nom du destinataire seul)
        r = { to = r, keep = 0 }
        store.items[itemID] = r
    end
    if r then return r, "item" end
    local class, sub = self:ItemClass(itemID)
    if not class then return nil end
    local broad
    for key, rule in pairs(store.cats) do
        local c = self.byKey[key]
        if c and c.class == class then
            if c.sub then
                if c.sub == sub then return rule, key end
            else
                broad = broad or { rule, key }
            end
        end
    end
    -- LQE : la catégorie la plus exigeante qui correspond (épique avant bleu avant vert).
    local checked, isBoE, quality, best = false, false, 0, nil
    for key, rule in pairs(store.cats) do
        local c = self.byKey[key]
        if c and c.boe then
            if not checked then isBoE, quality = self:BoE(itemID); checked = true end
            if isBoE and quality >= c.boe and (not best or c.boe > best[3]) then best = { rule, key, c.boe } end
        end
    end
    if best then return best[1], best[2] end
    if broad then return broad[1], broad[2] end
end

-- Plan de transfert depuis les sacs : pour chaque objet concerné, on garde rule.keep
-- exemplaires et on prend le reste, piles entières d'abord puis une pile partagée.
-- accept(rule, itemID, bound) dit si la règle s'applique. Renvoie une liste
-- { itemID, rule, ops = { {bag, slot, count, split} } }.
function M:Plan(store, accept)
    local byItem = {}
    for _, bag in ipairs(WK.modules.Inventory:BagList()) do
        for slot = 1, (WK.Container.NumSlots(bag) or 0) do
            local id, count, locked, bound = WK.Container.Info(bag, slot)
            if id and not locked then
                local rule = self:Resolve(store, id)
                if rule and accept(rule, id, bound) then
                    local e = byItem[id]
                    if not e then e = { itemID = id, rule = rule, slots = {}, total = 0 }; byItem[id] = e end
                    table.insert(e.slots, { bag = bag, slot = slot, count = count or 1 })
                    e.total = e.total + (count or 1)
                end
            end
        end
    end
    local plan = {}
    for id, e in pairs(byItem) do
        local toMove = e.total - (e.rule.keep or 0)
        if toMove > 0 then
            table.sort(e.slots, function(a, b) return a.count > b.count end)
            local ops = {}
            -- Piles entières qui tiennent dans la quantité à déplacer.
            for _, s in ipairs(e.slots) do
                if toMove <= 0 then break end
                if s.count <= toMove then
                    table.insert(ops, { bag = s.bag, slot = s.slot, count = s.count })
                    toMove = toMove - s.count
                    s.used = true
                end
            end
            -- Reste : on partage une pile.
            if toMove > 0 then
                for _, s in ipairs(e.slots) do
                    if not s.used and s.count > toMove then
                        table.insert(ops, { bag = s.bag, slot = s.slot, count = toMove, split = toMove })
                        break
                    end
                end
            end
            if #ops > 0 then table.insert(plan, { itemID = id, rule = e.rule, ops = ops }) end
        end
    end
    return plan
end

-- Prend l'objet (ou une partie de la pile) sur le curseur.
function M:PickUp(op)
    ClearCursor()
    if op.split then
        local split = (C_Container and C_Container.SplitContainerItem) or SplitContainerItem
        split(op.bag, op.slot, op.split)
    else
        WK.Container.Pickup(op.bag, op.slot)
    end
end

-- Ancien format : mail.rules[id] = "Nom" -> { to = "Nom", keep = 0 }.
function M:OnInit()
    local mail = WK.DB.global.mail
    for id, r in pairs(mail.rules) do
        if type(r) == "string" then mail.rules[id] = { to = r, keep = 0 } end
    end
end
