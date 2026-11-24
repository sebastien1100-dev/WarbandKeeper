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
            local key = bag .. ":" .. slot
            local r = reserved[key]
            -- objet arrivé (case remplie, plus verrouillée par le jeu) : sa quantité est déjà dans le compte de la
            -- case, la réservation est libérée (avant, elle était comptée deux fois : piles en trop, banque dite
            -- pleine trop tôt)
            -- (arrivé = le compte de la case a monté de ce qui est en route, ou 2 s passées : une pile partielle visée
            -- n'est plus libérée avant même l'arrivée du dépôt)
            local now = _G.GetTime and _G.GetTime() or 0
            if r and id and not locked and ((count or 0) >= (r.base or 0) + r.n or now - (r.at or 0) > 2) then
                reserved[key] = nil; r = nil
            end
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
-- n° du passage en cours : une étape d'un ancien passage (banque fermée puis rouverte très vite, son minuteur
-- encore en route) s'arrête net au lieu de déposer en même temps que le nouveau
local gen = 0

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
    -- « Ranger » : après le dépôt, sortir ce dont le perso a besoin
    if M.thenWithdraw then
        M.thenWithdraw = nil
        _G.C_Timer.After(0.5, function() M:Withdraw() end)
    end
end

local step
local function stepOf(g) return function() step(g) end end
step = function(g)
    if not running or g ~= gen then return end
    local job = table.remove(queue, 1)
    if not job then return finish() end
    if full[job.target] then return step(g) end
    -- la case doit encore contenir l'objet prévu (sacs bougés depuis le plan) : sinon on la passe
    local cur, n, locked = WK.Container.Info(job.op.bag, job.op.slot)
    if cur ~= job.itemID or locked then return step(g) end
    -- pile changée depuis le plan : jamais plus que prévu, et le décompte suit ce qui part vraiment
    if not WK.modules.Rules:AdjustOp(job.op, n) then return step(g) end
    local bag, slot = destination(job.target, job.itemID, job.op.count)
    if not bag then
        full[job.target] = true
        return step(g)
    end
    -- nombre dans la case visée lu AVANT d'y poser la pile (avant : lu juste après, il comptait déjà le dépôt et
    -- la case était libérée trop tôt)
    local key = bag .. ":" .. slot
    local r = reserved[key]
    local same = r and r.id == job.itemID
    local base = same and r.base or select(2, WK.Container.Info(bag, slot)) or 0
    WK.modules.Rules:PickUp(job.op)
    WK.Container.Pickup(bag, slot)
    ClearCursor()
    reserved[key] = { id = job.itemID, n = (same and r.n or 0) + job.op.count, base = base,
        at = _G.GetTime and _G.GetTime() or 0 }
    done[job.target] = done[job.target] or {}
    done[job.target][job.itemID] = (done[job.target][job.itemID] or 0) + job.op.count
    C_Timer.After(STEP_DELAY, stepOf(g))
end

-- Nombre d'objets des sacs qui seraient déposés.
function M:Plan()
    -- mode fabrication des sacs, dépôt en banque en pause : les composants de la file restent dans les sacs
    local PH = WK.modules.ProfHelp
    local keep = PH and PH.CraftKeep and PH:CraftKeep("bank")
    return WK.modules.Rules:Plan(self:Store(), function(rule, id, bound)
        if keep and keep[id] then return false end
        -- un verrou protège de la vente et de la destruction, pas du rangement (avant : un objet verrouillé à la main
        -- restait dans les sacs)
        if rule.target == "warband" and bound then return false end
        return true
    end)
end

-- Nombre d'objets à déposer, pour l'affichage (Résumé) : gardé tant que les sacs relevés sont les mêmes et au
-- plus 5 s (le dépôt lui-même refait toujours son plan)
local pendingMemo
function M:PendingCount()
    local bags = WK.DB:Me().bags
    local now = _G.GetTime and _G.GetTime() or 0
    local pm = pendingMemo
    if pm and pm.bags == bags and now - pm.at < 5 then return pm.n end
    local n = 0
    for _, e in ipairs(self:Plan()) do for _, op in ipairs(e.ops) do n = n + op.count end end
    pendingMemo = { bags = bags, at = now, n = n }
    return n
end

function M:Run(force)
    if running or not (force or WK.DB.global.bank.enabled) then return end
    local plan = self:Plan()
    if #plan == 0 then
        if M.thenWithdraw then M.thenWithdraw = nil; M:Withdraw() end
        return
    end
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
    gen = gen + 1
    step(gen)
end

WK:On("BANKFRAME_OPENED", function() C_Timer.After(0.6, function() M:Run() end) end)
WK:On("BANKFRAME_CLOSED", function() running = false; gen = gen + 1; M.thenWithdraw = nil; M.tidyMerge = nil end)

---------------------------------------------------------------------------
-- Sortir de la banque ce dont le perso connecté a besoin (bouton « Ranger » de notre banque) :
-- composants de ses guides de métier (Stash:Needs, jusqu'au palier visé) et consommables sous le seuil
-- d'« Avant de partir » (ProfHelp:Prep). Jamais plus que le manque dans les sacs.
---------------------------------------------------------------------------
local function bagCounts()
    local t = {}
    for _, bag in ipairs(WK.modules.Inventory:BagList()) do
        for slot = 1, (WK.Container.NumSlots(bag) or 0) do
            local id, n = WK.Container.Info(bag, slot)
            if id then t[id] = (t[id] or 0) + (n or 1) end
        end
    end
    return t
end

function M.WithdrawPlan(_)
    local ck = WK:CharKey()
    local want = {}
    local S = WK.modules.Stash
    local ok, needs = pcall(S.Needs, S, ck)
    for id, e in pairs(ok and type(needs) == "table" and needs[ck] or {}) do
        if (e.n or 0) > 0 then want[id] = { n = e.n, why = e.why } end
    end
    local PH = WK.modules.ProfHelp
    local ok2, rows = pcall(PH.Prep, PH, ck)
    for _, r in ipairs(ok2 and type(rows) == "table" and rows or {}) do
        if r.low and r.best and (r.min or 0) > 0 then
            local w = want[r.best]
            if not w or w.n < r.min then want[r.best] = { n = r.min, why = T(r.label or "") } end
        end
    end
    local have = bagCounts()
    local plan = {}
    for id, w in pairs(want) do
        local need = w.n - (have[id] or 0)
        if need > 0 then
            local ops = {}
            for _, bag in ipairs(WK.modules.Inventory:BankList()) do
                for slot = 1, (WK.Container.NumSlots(bag) or 0) do
                    if need <= 0 then break end
                    local sid, count, locked = WK.Container.Info(bag, slot)
                    if sid == id and not locked then
                        local take = math.min(count or 1, need)
                        ops[#ops + 1] = { bag = bag, slot = slot, count = take,
                            split = take < (count or 1) and take or nil }
                        need = need - take
                    end
                end
            end
            if #ops > 0 then plan[#plan + 1] = { itemID = id, ops = ops, why = w.why } end
        end
    end
    return plan
end

function M:WithdrawCount()
    local n = 0
    for _, e in ipairs(self:WithdrawPlan()) do for _, op in ipairs(e.ops) do n = n + op.count end end
    return n
end

-- case des sacs du perso pour un objet sorti : pile du même objet avec de la place, sinon case vide
local takenTo = {}
local function bagDest(itemID, amount)
    local empty
    for _, bag in ipairs(WK.modules.Inventory:BagList()) do
        for slot = 1, (WK.Container.NumSlots(bag) or 0) do
            local key = bag .. ":" .. slot
            local id, count, locked = WK.Container.Info(bag, slot)
            if not id and not takenTo[key] then empty = empty or { bag, slot }
            elseif id == itemID and not locked and not takenTo[key] and (count or 0) + amount <= maxStack(itemID) then
                return bag, slot
            end
        end
    end
    if empty then return empty[1], empty[2] end
end

local wQueue, wDone, wGen = nil, nil, 0
-- fin de « Ranger » : piles réunies dans la banque puis dans les sacs (Modules/Stash.lua)
local function tidyEnd()
    if not M.tidyMerge then return end
    M.tidyMerge = nil
    local St = WK.modules.Stash
    if St and St.MergeStacks then _G.C_Timer.After(0.4, function() St:MergeStacks({ "bank", "bags" }) end) end
end
local function wStep(g)
    if g ~= wGen then return end
    local job = table.remove(wQueue, 1)
    if not job then
        local list = {}
        for id, n in pairs(wDone) do list[#list + 1] = n .. " " .. (WK.UI and WK.UI:ItemInfo(id) or WK:ItemName(id)) end
        if #list > 0 then WK:Print(T("Sorti de la banque : ") .. table.concat(list, ", ")) end
        tidyEnd()
        return
    end
    local cur, n, locked = WK.Container.Info(job.op.bag, job.op.slot)
    if cur ~= job.itemID or locked or (n or 0) < job.op.count then return wStep(g) end
    local bag, slot = bagDest(job.itemID, job.op.count)
    if not bag then
        WK:Print(T("Sacs pleins : sortie de la banque incomplète."))
        tidyEnd()
        return
    end
    WK.modules.Rules:PickUp(job.op)
    WK.Container.Pickup(bag, slot)
    _G.ClearCursor()
    takenTo[bag .. ":" .. slot] = true
    wDone[job.itemID] = (wDone[job.itemID] or 0) + job.op.count
    _G.C_Timer.After(STEP_DELAY, function() wStep(g) end)
end

function M:Withdraw()
    if _G.InCombatLockdown and _G.InCombatLockdown() then return end
    local plan = self:WithdrawPlan()
    wQueue, wDone = {}, {}
    for k in pairs(takenTo) do takenTo[k] = nil end
    for _, e in ipairs(plan) do
        for _, op in ipairs(e.ops) do wQueue[#wQueue + 1] = { itemID = e.itemID, op = op } end
    end
    if #wQueue == 0 then tidyEnd() return end
    wGen = wGen + 1
    wStep(wGen)
end

-- Bouton « Ranger » : dépôt d'après les règles (même si le dépôt automatique est coupé), puis sortie
function M:Tidy()
    if running or (_G.InCombatLockdown and _G.InCombatLockdown()) then return end
    M.thenWithdraw = true
    M.tidyMerge = true
    self:Run(true)
end
WK:On("BANKFRAME_CLOSED", function() wGen = wGen + 1 end)

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
