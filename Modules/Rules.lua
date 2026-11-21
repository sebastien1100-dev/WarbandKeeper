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
    key = self:SplitKey(key)
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

-- Clé d'une règle : l'objet (itemID) ou la catégorie, suivi de « @Perso-Royaume » si la
-- règle ne vaut que pour un perso. Sans suffixe, elle vaut pour tous les persos.
function M:MakeKey(base, from)
    if from and from ~= "" then return base .. "@" .. from end
    return base
end

-- Renvoie la base (itemID en nombre, ou clé de catégorie) et le perso (nil = tous).
function M:SplitKey(k)
    if type(k) == "number" then return k, nil end
    local base, from = string.match(k, "^(.-)@(.+)$")
    base = base or k
    return tonumber(base) or base, from
end

-- Règle applicable à un objet dans un magasin { items = {...}, cats = {...} }, pour le perso
-- « who » (le perso connecté par défaut). Par ordre : règle d'objet > catégorie précise
-- (sous-classe) > objets LQE > catégorie large (classe). À égalité, la règle propre au perso
-- passe avant la règle « tous les persos ».
function M:Resolve(store, itemID, who)
    who = who or select(2, WK.DB:Me())
    for _, k in ipairs({ itemID .. "@" .. who, itemID }) do
        local r = store.items[k]
        if type(r) == "string" then -- ancien format (nom du destinataire seul)
            r = { to = r, keep = 0 }
            store.items[k] = r
        end
        if r then return r, "item" end
    end
    local class, sub = self:ItemClass(itemID)
    local checked, isBoE, quality = false, false, 0
    local best, bestScore
    for k, rule in pairs(store.cats) do
        local base, from = self:SplitKey(k)
        local c = self.byKey[base]
        if c and (not from or from == who) then
            local score
            if c.boe then
                if not checked then isBoE, quality = self:BoE(itemID); checked = true end
                if isBoE and quality >= c.boe then score = 20 + c.boe end
            elseif class and c.class == class then
                if c.sub then
                    if c.sub == sub then score = 30 end
                else
                    score = 10
                end
            end
            if score then
                if from then score = score + 0.5 end
                if not bestScore or score > bestScore then best, bestScore = { rule, k }, score end
            end
        end
    end
    if best then return best[1], best[2] end
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
    -- règle créée par un guide de métier : l'expéditeur garde ce que son propre guide demande (sinon un autre
    -- artisan qui monte avec le même composant enverrait tout son stock)
    local myNeeds
    local function ownGuideNeed(id)
        if myNeeds == nil then
            local S = WK.modules.Stash
            local all = S and S.Needs and S:Needs(WK:CharKey())
            myNeeds = all and all[WK:CharKey()] or false
        end
        local e = myNeeds and myNeeds[id]
        return (e and e.prio == 1 and e.n) or 0
    end
    local plan = {}
    for id, e in pairs(byItem) do
        local keep = e.rule.keep or 0
        if e.rule.guide then keep = math.max(keep, ownGuideNeed(id)) end
        local toMove = e.total - keep
        if toMove > 0 then
            table.sort(e.slots, function(a, b) return a.count > b.count end)
            local ops = {}
            -- Piles entières qui tiennent dans la quantité à déplacer.
            for _, s in ipairs(e.slots) do
                if toMove <= 0 then break end
                if s.count <= toMove then
                    table.insert(ops, { bag = s.bag, slot = s.slot, count = s.count, id = id })
                    toMove = toMove - s.count
                    s.used = true
                end
            end
            -- Reste : on partage une pile.
            if toMove > 0 then
                for _, s in ipairs(e.slots) do
                    if not s.used and s.count > toMove then
                        -- orig : taille de la pile au plan (pour garder la même part si elle fond d'ici l'envoi)
                        table.insert(ops, { bag = s.bag, slot = s.slot, count = toMove, split = toMove, id = id,
                            orig = s.count })
                        break
                    end
                end
            end
            if #ops > 0 then table.insert(plan, { itemID = id, rule = e.rule, ops = ops }) end
        end
    end
    return plan
end

-- Pile changée depuis le plan : jamais plus que prévu, et la part à garder reste gardée. Rend faux si rien ne
-- doit partir de cette case. (Avant, une pile qui avait fondu partait entière, malgré « garder ».)
function M.AdjustOp(_, op, n)
    n = n or 1
    local want = op.split or op.count
    if not want then return true end
    if op.split and op.orig and n < op.orig then
        local keep = op.orig - op.split
        local send = n - keep
        if send <= 0 then return false end
        op.split, op.count = send, send
    elseif n > want then
        op.split, op.count = want, want
    elseif n < want then
        op.split, op.count = nil, n
    end
    return true
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
