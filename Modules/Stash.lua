local ADDON_NAME, WK = ...
local M = WK:NewModule("Stash")
local T = function(s) return WK.T(s) end

-- Rangement intelligent : chaque composant va au perso qui s'en sert, d'après ses métiers.
--   Besoins d'un perso (Needs) : composants de ses guides de montée jusqu'au palier visé (Recipes:GuidePlan),
--   composants de ses recettes connues, recettes de ses métiers qu'il ne connaît pas encore (RecipeDB).
--   Ce dont personne n'a besoin : au perso HV (WK.DB.global.stash.ahChar) si le lot vaut au moins minAH à l'HV,
--   sinon au marchand. Jamais : objets verrouillés à la main, objets déjà pris par une règle d'envoi,
--   autre chose que des composants, recettes, réactifs et gemmes.
-- Route() rend { dest = { [perso] = { list = { { id, count, from = { [perso] = n }, why } } } },
--               ah = { list }, sell = { list } (déjà sur le perso HV), vendor = { list } }.
local DEFAULTS = { ahChar = nil, minAH = 5000, price = "lowest", duration = 24, reserve = 0, mailPanel = true }
-- classes d'objets concernées : réactifs (5), composants d'artisanat (7), recettes (9), gemmes (3)
local ROUTE_CLASS = { [3] = true, [5] = true, [7] = true, [9] = true }

function M:Config()
    local g = WK.DB.global
    g.stash = g.stash or {}
    for k, v in pairs(DEFAULTS) do if g.stash[k] == nil then g.stash[k] = v end end
    if g.stash.ahChar and not g.characters[g.stash.ahChar] then g.stash.ahChar = nil end
    return g.stash
end

local function instant(id)
    local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not f then return nil end
    local ok, _, _, _, _, _, classID, subID = pcall(f, id)
    if ok then return classID, subID end
end

-- objet de recette » { prof, l (niveau), o (objet fabriqué), s (sort) } d'après RecipeDB
local recipeIndex
local function recipeOf(id)
    if not recipeIndex then
        if not WK:NeedData("rangement") then return nil end
        recipeIndex = {}
        for prof, list in pairs(WK.RecipeDB or {}) do
            for _, r in ipairs(list) do if r.r then recipeIndex[r.r] = { prof = prof, l = r.l or 1, o = r.o, s = r.s } end end
        end
    end
    return recipeIndex[id]
end
M.RecipeOf = function(_, id) return recipeOf(id) end

local function guideEnd(g)
    local last = 0
    for _, st in ipairs(g and g.steps or {}) do last = math.max(last, st.to or 0) end
    return last
end

-- Besoins de chaque perso : needs[perso][objet] = { n (nil = sans limite), why, prio (1 guide, 2 recette, 3 composant) }
-- onlyKey (facultatif) : seulement ce perso (le plan du courrier et de la banque n'a besoin que du perso
-- connecté ; avant, les guides de tous les persos et de tous leurs métiers étaient recalculés à chaque plan)
function M:Needs(onlyKey)
    local R = WK.modules.Recipes
    local ui = WK.DB.global.settings.ui
    local targets = ui and ui.guideTarget or {}
    local needs = {}
    for key, c in pairs(WK.DB.global.characters) do
      if not onlyKey or key == onlyKey then
        local n = {}
        needs[key] = n
        local known = R:KnownOutputs(c)
        for prof, p in pairs(c.professions or {}) do
            local rank = type(p) == "table" and p.rank or 0
            local guide = R:Guide(prof)
            if guide then
                local target = targets[prof]
                if type(target) ~= "number" or target >= 300 then target = nil end -- « max » (ou 300) : jusqu'au bout du guide
                local _, mats = R:GuidePlan(prof, rank, known, target)
                local upTo = target or guideEnd(guide)
                for _, m in ipairs(mats or {}) do
                    if not m.recipe and m.need > 0 then
                        local e = n[m.itemID]
                        if not e or (e.prio or 9) > 1 then
                            n[m.itemID] = { n = m.need, prio = 1, why = string.format(T("guide : %d jusqu'à %d"), m.need, upTo) }
                        end
                    end
                end
            end
        end
        -- composants des recettes connues (sans limite : il en fera ce qu'il veut)
        local uses = {}
        for _, r in pairs(c.recipes or {}) do
            for _, rg in ipairs(r.reagents or {}) do uses[rg[1]] = (uses[rg[1]] or 0) + 1 end
        end
        for id, k in pairs(uses) do
            if not n[id] then n[id] = { prio = 3, why = string.format(k > 1 and T("composant de %d recettes") or T("composant de %d recette"), k) } end
        end
      end
    end
    -- objets de recette : au perso du métier qui ne la connaît pas encore (le plus avancé)
    self.recipeNeeds = function(id)
        local rec = recipeOf(id)
        if not rec then return nil end
        local best, bestRank
        for key, c in pairs(WK.DB.global.characters) do
            local p = c.professions and c.professions[rec.prof]
            local rank = type(p) == "table" and p.rank or nil
            if rank then
                local known = R:KnownOutputs(c)
                local isKnown = (rec.o and known[rec.o]) or (rec.s and WK.SpellInfo and known.names[WK.SpellInfo(rec.s) or ""])
                if not isKnown and (not bestRank or rank > bestRank) then best, bestRank = key, rank end
            end
        end
        if not best then return nil end
        local why = (bestRank or 0) >= rec.l and T("recette à apprendre")
            or string.format(T("recette à apprendre au niveau %d"), rec.l)
        return best, why
    end
    return needs
end

-- Où sont les objets : holdings[objet][perso] = quantité (sacs, banque, courrier) ; bags[objet][perso] = dans les sacs
local function holdings()
    local all, bags = {}, {}
    for key, c in pairs(WK.DB.global.characters) do
        for _, src in ipairs({ c.bags or {}, c.bank or {}, c.mailbox and c.mailbox.items or {} }) do
            for id, cnt in pairs(src) do
                if type(cnt) == "number" and cnt > 0 then
                    all[id] = all[id] or {}
                    all[id][key] = (all[id][key] or 0) + cnt
                end
            end
        end
        for id, cnt in pairs(c.bags or {}) do
            if type(cnt) == "number" and cnt > 0 then bags[id] = bags[id] or {}; bags[id][key] = cnt end
        end
    end
    return all, bags
end

-- Règle d'envoi existante pour cet objet (tes règles passent avant le rangement)
local function hasMailRule(id, who)
    local Rl, Ml = WK.modules.Rules, WK.modules.Mail
    if not (Rl and Ml) then return false end
    local ok, r = pcall(Rl.Resolve, Rl, Ml:Store(), id, who)
    return ok and r ~= nil
end

-- Prix d'un objet : HV (scan), marchand
local function prices(id)
    local V = WK.modules.Value
    local ah, vendor = V:Prices(id)
    return ah, vendor or 0
end

-- résultat gardé 3 s : la page et la boîte aux lettres le demandent souvent
local routeCache, routeAt = nil, -10
function M:Invalidate() routeCache = nil end
function M:Route()
    if routeCache and GetTime() - routeAt < 3 then return routeCache end
    routeCache, routeAt = self:Compute(), GetTime()
    return routeCache
end
function M:Compute()
    local cfg = self:Config()
    local needs = self:Needs()
    local all = holdings()
    local IL = WK.modules.ItemLock
    local out = { dest = {}, ah = { list = {}, value = 0 }, sell = { list = {}, value = 0 }, vendor = { list = {}, value = 0 } }
    local function addTo(group, id, count, from, why, unit)
        local e = { id = id, count = count, from = from, why = why, unit = unit }
        table.insert(group.list, e)
        if unit then group.value = (group.value or 0) + unit * count end
    end
    for id, byChar in pairs(all) do
        local classID = instant(id)
        if classID and ROUTE_CLASS[classID] and not (IL and IL:Manual()[id]) then
            -- qui en a besoin : liste triée (priorité, puis le plus gros besoin restant)
            local needers = {}
            for key, n in pairs(needs) do
                local e = n[id]
                if e then table.insert(needers, { key = key, need = e.n, prio = e.prio, why = e.why }) end
            end
            if classID == 9 and #needers == 0 then
                local who, why = self.recipeNeeds(id)
                if who then table.insert(needers, { key = who, need = 1, prio = 2, why = why }) end
            end
            table.sort(needers, function(a, b)
                if a.prio ~= b.prio then return a.prio < b.prio end
                local na, nb = a.need or math.huge, b.need or math.huge
                if na ~= nb then return na > nb end
                return a.key < b.key -- toujours le même ordre : pas d'aller-retour entre deux persos
            end)
            -- besoin restant de chaque perso, une fois son propre stock compté
            local left = {}
            for _, nd in ipairs(needers) do
                left[nd.key] = nd.need and math.max(0, nd.need - (byChar[nd.key] or 0)) or math.huge
            end
            local isNeeder = {}
            for _, nd in ipairs(needers) do isNeeder[nd.key] = nd end
            -- ce que chaque détenteur peut céder : tout s'il n'en a pas besoin, sinon le surplus
            local spare = {}
            for key, cnt in pairs(byChar) do
                if not hasMailRule(id, key) then
                    local nd = isNeeder[key]
                    local keep = nd and (nd.need or math.huge) or 0
                    local s = math.max(0, cnt - keep)
                    if s > 0 then spare[key] = s end
                end
            end
            -- vers ceux qui en ont besoin
            for _, nd in ipairs(needers) do
                for from, s in pairs(spare) do
                    if from ~= nd.key and left[nd.key] > 0 and s > 0 then
                        local mv = math.min(s, left[nd.key])
                        spare[from] = s - mv
                        left[nd.key] = left[nd.key] - mv
                        local d = out.dest[nd.key] or { list = {} }
                        out.dest[nd.key] = d
                        local ex
                        for _, e in ipairs(d.list) do if e.id == id then ex = e end end
                        if ex then ex.count = ex.count + mv; ex.from[from] = (ex.from[from] or 0) + mv
                        else addTo(d, id, mv, { [from] = mv }, nd.why) end
                    end
                end
            end
            -- personne n'en a besoin : HV ou marchand (jamais un objet verrouillé par règle)
            if #needers == 0 and not (IL and IL:Reason(id)) then
                local total, from = 0, {}
                for key, s in pairs(spare) do if s > 0 then total = total + s; from[key] = s end end
                total = math.max(0, total - (cfg.reserve or 0))
                if total > 0 then
                    local ah, vendor = prices(id)
                    if cfg.ahChar and (not ah or ah * total >= (cfg.minAH or 0)) then
                        local onAH = from[cfg.ahChar]
                        if onAH and onAH > 0 then addTo(out.sell, id, math.min(onAH, total), { [cfg.ahChar] = onAH }, ah and T("à vendre") or T("à vérifier : pas de prix"), ah) end
                        local rest = total - (onAH or 0)
                        if rest > 0 then
                            local fr = {}
                            for k, v in pairs(from) do if k ~= cfg.ahChar then fr[k] = v end end
                            addTo(out.ah, id, rest, fr, ah and T("personne n'en a besoin") or T("à vérifier : pas de prix"), ah)
                        end
                    elseif vendor > 0 and ah ~= nil then
                        addTo(out.vendor, id, total, from, string.format(T("vaut %s à l'HV"), WK:FormatMoney(ah)), vendor)
                    elseif vendor > 0 and not cfg.ahChar then
                        addTo(out.vendor, id, total, from, T("personne n'en a besoin"), vendor)
                    end
                end
            end
        end
    end
    local function byName(a, b) return (WK.GetItemInfo(a.id) or "") < (WK.GetItemInfo(b.id) or "") end
    for _, d in pairs(out.dest) do table.sort(d.list, byName) end
    for _, g in ipairs({ out.ah, out.sell, out.vendor }) do table.sort(g.list, byName) end
    return out
end

-- Envois du perso connecté (objets dans ses sacs) : { { id, count, to = perso, why, ah? } }
function M:MyShipments()
    local me = WK:CharKey()
    local r = self:Route()
    local c = WK.DB.global.characters[me]
    local inBags = c and c.bags or {}
    local out = {}
    local function take(list, to, ah)
        for _, e in ipairs(list) do
            local n = math.min(e.from[me] or 0, inBags[e.id] or 0)
            if n > 0 and to ~= me then table.insert(out, { id = e.id, count = n, to = to, why = e.why, ah = ah }) end
        end
    end
    for key, d in pairs(r.dest) do take(d.list, key) end
    local cfg = self:Config()
    if cfg.ahChar then take(r.ah.list, cfg.ahChar, true) end
    return out
end

---------------------------------------------------------------------------
-- Place : cases libres de chaque perso et ce qui en libèrerait le plus (camelote, envois, ventes, piles à
-- réunir) ; piles à réunir dans les sacs ou la banque ; objets « au marchand » du perso connecté.
---------------------------------------------------------------------------
local function stackOf(id)
    local n = select(8, WK.GetItemInfo(id))
    return (type(n) == "number" and n > 0) and n or 1
end
local function slotsFor(id, n) return math.ceil((n or 0) / stackOf(id)) end
M.slotsFor = slotsFor

-- Déplacements qui réunissent les piles incomplètes d'un même objet dans ces sacs :
-- { { id, from = { sac, case }, to = { sac, case }, n } }, cases libérées
function M.MergePlan(_, bagList)
    local by = {}
    for _, bag in ipairs(bagList or {}) do
        for slot = 1, (WK.Container.NumSlots(bag) or 0) do
            local id, n, locked = WK.Container.Info(bag, slot)
            if id and not locked then
                local mx = stackOf(id)
                if mx > 1 and (n or 1) < mx then
                    by[id] = by[id] or {}
                    table.insert(by[id], { bag = bag, slot = slot, n = n or 1, mx = mx })
                end
            end
        end
    end
    local moves, freed = {}, 0
    for id, list in pairs(by) do
        if #list > 1 then
            table.sort(list, function(a, b)
                if a.n ~= b.n then return a.n > b.n end
                if a.bag ~= b.bag then return a.bag < b.bag end
                return a.slot < b.slot
            end)
            local i, j = 1, #list
            while i < j do
                local dst, src = list[i], list[j]
                local room = dst.mx - dst.n
                if room <= 0 then
                    i = i + 1
                else
                    local mv = math.min(room, src.n)
                    moves[#moves + 1] = { id = id, from = { src.bag, src.slot }, to = { dst.bag, dst.slot }, n = mv }
                    dst.n, src.n = dst.n + mv, src.n - mv
                    if src.n == 0 then freed = freed + 1; j = j - 1 end
                end
            end
        end
    end
    table.sort(moves, function(a, b) return a.id < b.id end)
    return moves, freed
end

local bankOpen = false
WK:On("BANKFRAME_OPENED", function() bankOpen = true end)
WK:On("BANKFRAME_CLOSED", function() bankOpen = false end)
function M.BankOpen() return bankOpen end

-- Réunit les piles, une par une (0,35 s entre deux), hors combat ; scopes = { "bags" } / { "bank", "bags" }
local merging
function M.Merging(_) return merging ~= nil end
function M:MergeStacks(scopes, onDone)
    if merging or (_G.InCombatLockdown and _G.InCombatLockdown()) then return false end
    if _G.CursorHasItem and _G.CursorHasItem() then return false end
    local Inv = WK.modules.Inventory
    local lists = {}
    for _, s in ipairs(scopes or { "bags" }) do
        if s == "bank" then
            if bankOpen then lists[#lists + 1] = Inv:BankList() end
        else
            lists[#lists + 1] = Inv:BagList()
        end
    end
    local function freeNow()
        local f = 0
        for _, l in ipairs(lists) do for _, b in ipairs(l) do f = f + (WK.Container.NumFree(b) or 0) end end
        return f
    end
    merging = { moved = 0, freed = 0, free0 = freeNow() }
    local li, steps = 1, 0
    local CC = _G.C_Container
    local function finish()
        local m = merging
        merging = nil
        if m then m.freed = math.max(0, freeNow() - m.free0) end
        if m and m.moved > 0 then
            WK:Print(string.format(T("Piles réunies : %d case(s) libérée(s)."), m.freed))
        end
        WK:NotifyChanged()
        if onDone then onDone(m) end
    end
    local step
    step = function()
        if not merging then return end
        if (_G.InCombatLockdown and _G.InCombatLockdown()) or steps >= 150 then return finish() end
        local list = lists[li]
        if not list then return finish() end
        local moves = self:MergePlan(list)
        local mv = moves[1]
        if not mv then li = li + 1; return step() end
        steps = steps + 1
        local _, n = WK.Container.Info(mv.from[1], mv.from[2])
        if (n or 0) > mv.n and CC and CC.SplitContainerItem then
            CC.SplitContainerItem(mv.from[1], mv.from[2], mv.n)
        else
            WK.Container.Pickup(mv.from[1], mv.from[2])
        end
        WK.Container.Pickup(mv.to[1], mv.to[2])
        if _G.CursorHasItem and _G.CursorHasItem() then _G.ClearCursor() end
        merging.moved = merging.moved + 1
        _G.C_Timer.After(0.35, step)
    end
    step()
    return true
end

-- Place de chaque perso, de la moins libre à la plus libre :
-- { key, c, free, total, bankFree, bankSlots, junk, junkValue, send, sell, merge (perso connecté seulement), gain }
function M:Space()
    local chars = WK.DB.global.characters
    local r = self:Route()
    local me = WK:CharKey()
    local send, sell = {}, {}
    local function add(t, e)
        for key, n in pairs(e.from or {}) do
            local inBags = chars[key] and chars[key].bags and chars[key].bags[e.id] or 0
            local k = math.min(n, inBags)
            if k > 0 then t[key] = (t[key] or 0) + slotsFor(e.id, k) end
        end
    end
    for _, d in pairs(r.dest) do for _, e in ipairs(d.list) do add(send, e) end end
    for _, e in ipairs(r.ah.list) do add(send, e) end
    for _, e in ipairs(r.vendor.list) do add(sell, e) end
    local Q, IL = WK.modules.QoL, WK.modules.ItemLock
    local out = {}
    for key, c in pairs(chars) do
        if type(c) == "table" and c.totalSlots and c.totalSlots > 0 then
            local junk, junkValue = 0, 0
            for id, n in pairs(c.bags or {}) do
                if type(n) == "number" and n > 0 and Q and Q.IsJunk and Q:IsJunk(id)
                    and not (IL and IL.Reason and IL:Reason(id)) then
                    junk = junk + slotsFor(id, n)
                    junkValue = junkValue + (select(11, WK.GetItemInfo(id)) or 0) * n
                end
            end
            local merge
            if key == me then
                local _, f = self:MergePlan(WK.modules.Inventory:BagList())
                merge = f
            end
            local e = { key = key, c = c, free = c.freeSlots or 0, total = c.totalSlots, bankFree = c.bankFree,
                bankSlots = c.bankSlots, junk = junk, junkValue = junkValue, send = send[key] or 0,
                sell = sell[key] or 0, merge = merge }
            e.gain = e.junk + e.send + e.sell + (merge or 0)
            out[#out + 1] = e
        end
    end
    table.sort(out, function(a, b)
        local fa, fb = a.free / math.max(1, a.total), b.free / math.max(1, b.total)
        if fa ~= fb then return fa < fb end
        return a.key < b.key
    end)
    return out
end

-- Objets du perso connecté dont personne n'a besoin et que le rangement envoie au marchand : { { id, count, unit } }
function M:MyVendorItems()
    local me = WK:CharKey()
    local c = WK.DB.global.characters[me]
    local inBags = c and c.bags or {}
    local out = {}
    for _, e in ipairs(self:Route().vendor.list) do
        local n = math.min(e.from and e.from[me] or 0, inBags[e.id] or 0)
        if n > 0 then out[#out + 1] = { id = e.id, count = n, unit = e.unit } end
    end
    return out
end
