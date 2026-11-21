local ADDON_NAME, WK = ...
local M = WK:NewModule("BankDeposit")
local T = function(s) return WK.T(s) end

-- Dépôt automatique à l'ouverture de la banque.
-- Règle : { target = "bank" | "warband", keep = n } par objet ou par catégorie.
local STEP_DELAY = 0.3

function M:Store()
    local b = WK.DB.global.bank
    return { items = b.items, cats = b.cats }
end

local function targetBags(target)
    local inv = WK.modules.Inventory
    return target == "warband" and inv:WarbandList() or inv:BankList()
end

local function maxStack(itemID)
    local n = select(8, WK.GetItemInfo(itemID))
    return n or 1
end

-- Cases visées pendant la passe : un dépôt met un moment à arriver ; sans ça, la case vide choisie juste
-- avant était reprise (le jeu échangeait les deux objets) et le décompte était faux.
-- reserved["sac:case"] = { id, n } (objet et quantité en route)
local reserved = {}
M.reserved = reserved -- (tests)

-- Emplacement d'arrivée : pile du même objet avec assez de place, sinon emplacement vide.
local function destination(target, itemID, amount)
    local empty
    for _, bag in ipairs(targetBags(target)) do
        for slot = 1, (WK.Container.NumSlots(bag) or 0) do
            local id, count, locked = WK.Container.Info(bag, slot)
            local r = reserved[bag .. ":" .. slot]
            if r and not id then
                -- case vide visée par un dépôt en route : pleine pour nous (même objet : pile à compléter)
                id, count = r.id, 0
            end
            local pending = (r and r.id == itemID) and r.n or 0
            if not id then
                empty = empty or { bag, slot }
            elseif id == itemID and not locked and (count or 0) + pending + amount <= maxStack(itemID) then
                return bag, slot
            end
        end
    end
    if empty then return empty[1], empty[2] end
end
M.Destination = destination

local running = false
local queue, done, full

local function finish()
    running = false
    local parts = {}
    for target, items in pairs(done) do
        local list = {}
        for id, n in pairs(items) do table.insert(list, n .. " " .. (WK.UI and WK.UI:ItemInfo(id) or WK:ItemName(id))) end
        if #list > 0 then
            local where = target == "warband" and T("banque de bataillon") or T("banque")
            table.insert(parts, table.concat(list, ", ") .. " (" .. where .. ")")
            if WK.modules.Journal then WK.modules.Journal:Deposit(target, items) end
        end
    end
    if #parts > 0 then
        WK:Print(T("Déposé : ") .. table.concat(parts, " ; "))
        if WK.DB.global.bank.sortAfter ~= false then
            C_Timer.After(0.5, function() WK.modules.Inventory:SortBags() end)
        end
    end
    for target in pairs(full) do
        WK:Print(target == "warband" and T("Banque de bataillon pleine : dépôt incomplet.") or T("Banque pleine : dépôt incomplet."))
    end
end

local function step()
    if not running then return end
    local job = table.remove(queue, 1)
    if not job then return finish() end
    if full[job.target] then return step() end
    -- la case doit encore contenir l'objet prévu (sacs bougés depuis le plan) : sinon on la passe
    local cur, n, locked = WK.Container.Info(job.op.bag, job.op.slot)
    if cur ~= job.itemID or locked then return step() end
    -- pile changée depuis le plan : jamais plus que prévu, et le décompte suit ce qui part vraiment
    n = n or 1
    local want = job.op.split or job.op.count
    if want and n > want then job.op.split, job.op.count = want, want
    elseif want and n < want then job.op.split, job.op.count = nil, n end
    local bag, slot = destination(job.target, job.itemID, job.op.count)
    if not bag then
        full[job.target] = true
        return step()
    end
    WK.modules.Rules:PickUp(job.op)
    WK.Container.Pickup(bag, slot)
    ClearCursor()
    local key = bag .. ":" .. slot
    local r = reserved[key]
    reserved[key] = { id = job.itemID, n = ((r and r.id == job.itemID) and r.n or 0) + job.op.count }
    done[job.target] = done[job.target] or {}
    done[job.target][job.itemID] = (done[job.target][job.itemID] or 0) + job.op.count
    C_Timer.After(STEP_DELAY, step)
end

-- Nombre d'objets des sacs qui seraient déposés.
function M:Plan()
    return WK.modules.Rules:Plan(self:Store(), function(rule, id, bound)
        -- objet verrouillé à la main (Modules/ItemLock.lua) : il reste dans les sacs, comme pour le courrier
        local IL = WK.modules.ItemLock
        if IL and IL:Manual()[id] then return false end
        if rule.target == "warband" and bound then return false end
        return true
    end)
end

function M:Run()
    if running or not WK.DB.global.bank.enabled then return end
    local plan = self:Plan()
    if #plan == 0 then return end
    queue, done, full = {}, {}, {}
    for k in pairs(reserved) do reserved[k] = nil end
    -- Pas de banque de bataillon sur ce client : on dépose dans la banque du perso.
    local hasWarband = false
    for _, bag in ipairs(WK.modules.Inventory:WarbandList()) do
        if (WK.Container.NumSlots(bag) or 0) > 0 then hasWarband = true break end
    end
    for _, e in ipairs(plan) do
        local target = (e.rule.target == "warband" and hasWarband) and "warband" or "bank"
        for _, op in ipairs(e.ops) do
            table.insert(queue, { itemID = e.itemID, op = op, target = target })
        end
    end
    running = true
    step()
end

WK:On("BANKFRAME_OPENED", function() C_Timer.After(0.6, function() M:Run() end) end)
WK:On("BANKFRAME_CLOSED", function() running = false end)

-- Gestion des règles
-- from : clé du perso qui dépose (nil = tous les persos).
function M:AddRule(itemArg, target, keep, from)
    local id = WK:ParseItemID(itemArg)
    if not id then return false end
    WK.DB.global.bank.items[WK.modules.Rules:MakeKey(id, from)] = { target = target or "bank", keep = keep or 0 }
    WK:NotifyChanged()
    return true
end

function M:AddCategoryRule(key, target, keep, from)
    if not WK.modules.Rules.byKey[key] then return false end
    WK.DB.global.bank.cats[WK.modules.Rules:MakeKey(key, from)] = { target = target or "bank", keep = keep or 0 }
    WK:NotifyChanged()
    return true
end

function M:RemoveRule(id) WK.DB.global.bank.items[id] = nil; WK:NotifyChanged() end
function M:RemoveCategoryRule(key) WK.DB.global.bank.cats[key] = nil; WK:NotifyChanged() end
