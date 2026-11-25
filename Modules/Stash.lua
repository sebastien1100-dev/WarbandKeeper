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
local DEFAULTS = { ahChar = nil, minAH = 5000, reserve = 0, mailPanel = true }
-- classes d'objets concernées : réactifs (5), composants d'artisanat (7), recettes (9), gemmes (3)
local ROUTE_CLASS = { [3] = true, [5] = true, [7] = true, [9] = true }

function M:Config()
    local g = WK.DB.global
    g.stash = g.stash or {}
    for k, v in pairs(DEFAULTS) do if g.stash[k] == nil then g.stash[k] = v end end
    g.stash.price, g.stash.duration = nil, nil -- anciens réglages (prix proposé, durée), plus lus
    if g.stash.ahChar and not g.characters[g.stash.ahChar] then g.stash.ahChar = nil end
    for _, k in ipairs({ "cons", "fam", "chars", "items" }) do
        if type(g.stash[k]) ~= "table" then g.stash[k] = {} end
    end
    if g.stash.main and not g.characters[g.stash.main] then g.stash.main = nil end
    if g.stash.bank and not g.characters[g.stash.bank] then g.stash.bank = nil end
    return g.stash
end

---------------------------------------------------------------------------
-- Répartition par famille (maquettes A + B) : qui reçoit quoi, d'office d'après les métiers, avec des exceptions.
-- Réglages (dans WK.DB.global.stash) :
--   main = perso principal (reçoit nourriture, boisson, bandages, potions de son niveau tant qu'il monte)
--   cons[perso] = { food, drink, bandage, potion } stocks voulus (le perso principal a ceux de CONS_MAIN d'office)
--   fam[famille][perso] = { mode = "recv" | "prio" | "pause" | "stock", cap = piles }
--   chars[perso] = { keep = garde ses récoltes, none = ne reçoit rien }
--   items[objet] = { to = perso } | { never = true } | { ah = true }
-- La règle la plus précise gagne : objet » famille » métier » perso ; les verrous restent prioritaires.
---------------------------------------------------------------------------
M.FAMILIES = {
    { key = "cloth", label = "Tissus", sub = "lin, laine, soie, tisse-mage, étoffe runique", raw = true },
    { key = "metal", label = "Minerais, barres, pierres", raw = true },
    { key = "leather", label = "Peaux, cuirs, écailles", raw = true },
    { key = "herb", label = "Herbes", raw = true },
    { key = "ench", label = "Poussières, essences, éclats" },
    { key = "gem", label = "Gemmes et pierres", sub = "pierres précieuses, gemmes taillées" },
    { key = "meat", label = "Viande, poisson cru", raw = true },
    { key = "food", label = "Nourriture et boisson", cons = { "food", "drink" } },
    { key = "heal", label = "Bandages et potions", cons = { "bandage", "potion" } },
    { key = "gear", label = "Équipement à lier" },
}
local FAM = {}
for _, f in ipairs(M.FAMILIES) do FAM[f.key] = f end
-- sous-classes des composants d'artisanat (classe 7)
local TRADE_FAM = { [5] = "cloth", [7] = "metal", [6] = "leather", [9] = "herb", [12] = "ench", [8] = "meat",
    [4] = "gem" }
-- métiers qui consomment une famille : "all" = reçoit tout, "guide" = seulement ce que demande son guide
local PROF_FAM = {
    ["Couture"] = { cloth = "all" }, ["Tailoring"] = { cloth = "all" },
    ["Secourisme"] = { cloth = "guide" }, ["First Aid"] = { cloth = "guide" },
    ["Forge"] = { metal = "all" }, ["Blacksmithing"] = { metal = "all" },
    ["Ingénierie"] = { metal = "all" }, ["Engineering"] = { metal = "all" },
    ["Minage"] = { metal = "all" }, ["Mining"] = { metal = "all" },
    ["Travail du cuir"] = { leather = "all" }, ["Leatherworking"] = { leather = "all" },
    ["Alchimie"] = { herb = "all" }, ["Alchemy"] = { herb = "all" },
    ["Enchantement"] = { ench = "all", gear = "all" }, ["Enchanting"] = { ench = "all", gear = "all" },
    ["Joaillerie"] = { gem = "all" }, ["Jewelcrafting"] = { gem = "all" },
    ["Cuisine"] = { meat = "all" }, ["Cooking"] = { meat = "all" },
}
M.PROF_FAM = PROF_FAM
local CONS_MAIN = { food = 40, drink = 40, bandage = 20, potion = 10 }
M.CONS_MAIN = CONS_MAIN
local CONS_LABEL = { food = "repas", drink = "boissons", bandage = "bandages", potion = "potions" }
M.CONS_LABEL = CONS_LABEL

local function instant(id)
    local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not f then return nil end
    local ok, _, _, _, _, _, classID, subID = pcall(f, id)
    if ok then return classID, subID end
end

-- famille d'un objet (nil = hors répartition par famille)
function M.FamilyOf(_, id)
    local classID, subID = instant(id)
    if classID == 7 then return TRADE_FAM[subID] end
    if classID == 3 then return "gem" end
    if classID == 0 then
        if subID == 5 then return "food" end
        if subID == 7 or subID == 1 then return "heal" end
    end
    if classID == 2 or classID == 4 then
        local bind = select(14, WK.GetItemInfo(id))
        if bind == 2 then return "gear" end
    end
end
-- genre d'un consommable : food / drink / bandage / potion
local function consKind(id)
    local classID, subID = instant(id)
    if classID ~= 0 then return nil end
    if subID == 7 then return "bandage" end
    if subID == 1 then return "potion" end
    if subID == 5 then
        local BH = WK.modules.BagHelp
        return BH and BH.Kind and BH:Kind(id) or nil
    end
end
M.ConsKind = function(_, id) return consKind(id) end
local function maxLevel()
    local XP = WK.modules.XP
    return XP and XP.MaxLevel and XP:MaxLevel() or 60
end
-- stocks voulus d'un perso (le perso principal a ceux par défaut tant qu'il n'est pas au niveau max)
function M:ConsTargets(key)
    local cfg = self:Config()
    local t = cfg.cons[key]
    local c = WK.DB.global.characters[key]
    if key == cfg.main and c and (c.level or 1) < maxLevel() then
        local out = {}
        for k, v in pairs(CONS_MAIN) do out[k] = v end
        for k, v in pairs(t or {}) do out[k] = v end
        return out, true
    end
    return t, false
end
-- réglage d'une case famille × perso
function M:FamRule(fam, key)
    local f = self:Config().fam[fam]
    return f and f[key] or nil
end
function M:SetFamRule(fam, key, mode, cap)
    local cfg = self:Config()
    cfg.fam[fam] = cfg.fam[fam] or {}
    if not mode and not cap then cfg.fam[fam][key] = nil
    else cfg.fam[fam][key] = { mode = mode, cap = cap } end
    self:Invalidate(); WK:NotifyChanged()
end
function M:CharFlags(key) return self:Config().chars[key] or {} end
function M:SetCharFlag(key, flag, on)
    local cfg = self:Config()
    cfg.chars[key] = cfg.chars[key] or {}
    cfg.chars[key][flag] = on or nil
    if not next(cfg.chars[key]) then cfg.chars[key] = nil end
    self:Invalidate(); WK:NotifyChanged()
end
function M:ItemRule(id) return self:Config().items[id] end
function M:SetItemRule(id, rule)
    self:Config().items[id] = rule
    self:Invalidate(); WK:NotifyChanged()
end
function M:SetCons(key, kind, n)
    local cfg = self:Config()
    cfg.cons[key] = cfg.cons[key] or {}
    cfg.cons[key][kind] = n
    self:Invalidate(); WK:NotifyChanged()
end
-- persos qui reçoivent une famille d'office : { { key, how = "all" | "guide", prof, rank } }, du plus avancé au moins
function M.FamReceivers(_, fam)
    local out = {}
    for key, c in pairs(WK.DB.global.characters) do
        local best
        for prof, p in pairs(c.professions or {}) do
            local how = PROF_FAM[prof] and PROF_FAM[prof][fam]
            local rank = type(p) == "table" and p.rank or 0
            if how and (not best or (how == "all" and best.how ~= "all") or (how == best.how and rank > best.rank)) then
                best = { key = key, how = how, prof = prof, rank = rank }
            end
        end
        if best then out[#out + 1] = best end
    end
    table.sort(out, function(a, b)
        if a.how ~= b.how then return a.how == "all" end
        if a.rank ~= b.rank then return a.rank > b.rank end
        return a.key < b.key
    end)
    return out
end

-- Case du tableau Répartition : { text, col (clé de couleur), mode } pour la famille et le perso
function M:Cell(fam, key)
    local c = WK.DB.global.characters[key]
    if not c then return { text = "-", col = "dim" } end
    local fl = self:CharFlags(key)
    if fl.none then return { text = T("ne reçoit rien"), col = "negative", mode = "none" } end
    local r = self:FamRule(fam, key)
    local capTxt = r and r.cap and (" · " .. string.format(T("plafond %d piles"), r.cap)) or ""
    if r and r.mode == "pause" then return { text = T("Pause"), col = "negative", mode = "pause" } end
    if r and r.mode == "prio" then
        return { text = T("Prioritaire") .. capTxt, col = "rule", mode = "prio", fill = true }
    end
    if r and r.mode == "stock" then return { text = T("Stock") .. capTxt, col = "gold", mode = "stock" } end
    local f = FAM[fam]
    if f and f.cons then
        local t, isMain = self:ConsTargets(key)
        local parts = {}
        for _, k in ipairs(f.cons) do
            if t and t[k] and t[k] > 0 then parts[#parts + 1] = t[k] .. " " .. T(CONS_LABEL[k]) end
        end
        if #parts > 0 then
            return { text = table.concat(parts, " · "), col = isMain and "accent" or "info", mode = "cons" }
        end
        return { text = "-", col = "dim" }
    end
    for _, rv in ipairs(self:FamReceivers(fam)) do
        if rv.key == key then
            if rv.how == "all" then
                return { text = T("Reçoit") .. " · " .. rv.prof .. capTxt, col = "positive", mode = "auto" }
            end
            return { text = string.format(T("%s · palier visé"), rv.prof) .. capTxt, col = "info", mode = "guide" }
        end
    end
    if r and r.mode == "recv" then return { text = T("Reçoit") .. capTxt, col = "positive", mode = "recv" } end
    if fl.keep and f and f.raw then return { text = T("garde ses récoltes"), col = "rule", mode = "keep" } end
    if key == self:Config().bank then return { text = T("Surplus · perso banque"), col = "gold", mode = "bank" } end
    return { text = "-", col = "dim" }
end

local stackOf -- défini plus bas (piles)
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
                            n[m.itemID] = { n = m.need, prio = 1, prof = prof,
                                why = string.format(T("guide : %d jusqu'à %d"), m.need, upTo) }
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
-- Seulement une règle qui envoie vraiment quelque chose depuis ce perso : un destinataire qui n'est pas lui et plus
-- que la quantité gardée (avant : toute règle comptait, même vers lui-même ou qui garde tout, et l'objet ne bougeait
-- plus jamais : « Reste ici : une règle d'envoi s'en occupe »)
local function hasMailRule(id, who, cnt)
    local Rl, Ml = WK.modules.Rules, WK.modules.Mail
    if not (Rl and Ml) then return false end
    local ok, r = pcall(Rl.Resolve, Rl, Ml:Store(), id, who)
    if not (ok and type(r) == "table" and type(r.to) == "string" and r.to ~= "") then return false end
    local okR, _, toKey = pcall(Ml.Resolve, Ml, r.to)
    if okR and toKey and toKey == who then return false end
    if cnt and cnt <= (r.keep or 0) then return false end
    return true
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
    local chars = WK.DB.global.characters
    -- keep[objet][perso] = raison pour laquelle ce perso garde l'objet (fiche des sacs : « Reste ici : … »)
    local out = { dest = {}, ah = { list = {}, value = 0 }, sell = { list = {}, value = 0 },
        vendor = { list = {}, value = 0 }, keep = {} }
    local function kept(id, key, why)
        if not why or why == "" then return end
        out.keep[id] = out.keep[id] or {}
        out.keep[id][key] = out.keep[id][key] or why
    end
    local function addTo(group, id, count, from, why, unit, exc)
        local e = { id = id, count = count, from = from, why = why, unit = unit, exc = exc }
        table.insert(group.list, e)
        if unit then group.value = (group.value or 0) + unit * count end
    end
    local function send(to, id, mv, from, why, exc)
        local d = out.dest[to] or { list = {} }
        out.dest[to] = d
        for _, e in ipairs(d.list) do
            if e.id == id then e.count = e.count + mv; e.from[from] = (e.from[from] or 0) + mv; return end
        end
        addTo(d, id, mv, { [from] = mv }, why, nil, exc)
    end
    local flags = cfg.chars
    local function noRecv(key, fam)
        if flags[key] and flags[key].none then return true end
        local r = fam and cfg.fam[fam] and cfg.fam[fam][key]
        return r and r.mode == "pause" or false
    end
    -- ce perso garde ses récoltes : ses matières premières ne partent pas
    local function keeps(key, fam) return flags[key] and flags[key].keep and fam and FAM[fam] and FAM[fam].raw end
    -- receveurs d'office de chaque famille (calculés une fois)
    local famRecv = {}
    for _, f in ipairs(M.FAMILIES) do famRecv[f.key] = self:FamReceivers(f.key) end
    local consItems = {}
    for id, byChar in pairs(all) do
        local classID = instant(id)
        local rule = cfg.items[id]
        local fam = classID and self:FamilyOf(id)
        -- un verrou protège de la vente et de la destruction, pas du rangement : l'objet verrouillé part au perso
        -- qui s'en sert comme les autres (avant : un verrou à la main l'empêchait de bouger)
        if rule and rule.never then -- luacheck: ignore 542
            -- ne bouge jamais
        elseif rule and rule.to and chars[rule.to] then
            -- exception par objet : tout va à ce perso
            for key, cnt in pairs(byChar) do
                if key ~= rule.to and cnt > 0 and not hasMailRule(id, key, cnt) then
                    local who = WK:CharName(chars[rule.to], rule.to)
                    send(rule.to, id, cnt, key, string.format(T("exception : toujours à %s"), who), "always")
                end
            end
        elseif rule and rule.ah and cfg.ahChar then
            for key, cnt in pairs(byChar) do
                if cnt > 0 then
                    local ah = prices(id)
                    local grp = key == cfg.ahChar and out.sell or out.ah
                    addTo(grp, id, cnt, { [key] = cnt }, T("exception : toujours à l'HV"), ah)
                end
            end
        elseif fam == "food" or fam == "heal" then
            consItems[#consItems + 1] = id
        elseif fam == "gear" and IL and IL:Reason(id) then -- luacheck: ignore 542
            -- équipement verrouillé par règle (épique, envie, BiS) : il ne part pas chez l'enchanteur
        elseif classID and (ROUTE_CLASS[classID] or fam == "gear") then
            -- qui en a besoin : liste triée (priorité, puis le plus gros besoin restant)
            local needers, seen = {}, {}
            local stack = stackOf(id)
            for key, n in pairs(needs) do
                local e = n[id]
                if e and not noRecv(key, fam) then
                    table.insert(needers, { key = key, need = e.n, prio = e.prio, why = e.why, prof = e.prof })
                    seen[key] = #needers
                end
            end
            if fam then
                -- réception d'office d'après les métiers, puis les réglages de la case (prioritaire, stock…)
                for i, r in ipairs(famRecv[fam]) do
                    if r.how == "all" and not noRecv(r.key, fam) and not seen[r.key] then
                        local why = string.format(T("%s : reçoit"), r.prof)
                        table.insert(needers, { key = r.key, prio = 3 + i / 100, why = why })
                        seen[r.key] = #needers
                    end
                end
                for key, fr in pairs(cfg.fam[fam] or {}) do
                    if chars[key] and not noRecv(key, fam) then
                        local nd = seen[key] and needers[seen[key]]
                        if not nd and (fr.mode == "recv" or fr.mode == "prio" or fr.mode == "stock") then
                            nd = { key = key, why = T("reçoit (réglage)") }
                            table.insert(needers, nd); seen[key] = #needers
                        end
                        if nd then
                            if fr.mode == "prio" then
                                nd.prio, nd.exc, nd.why = 0, "prio", T("prioritaire") .. " · " .. (nd.why or "")
                            elseif fr.mode == "stock" then
                                nd.prio, nd.need, nd.exc, nd.why = 5, nil, "stock", T("stock de la famille")
                            elseif not nd.prio then nd.prio = 3 end
                            if fr.cap then
                                nd.need = math.min(nd.need or math.huge, fr.cap * stack)
                                nd.exc = nd.exc or "cap"
                                nd.why = (nd.why or "") .. " · " .. string.format(T("plafond %d piles"), fr.cap)
                            end
                        end
                    end
                end
            end
            -- perso banque : le surplus de chaque famille (après les métiers), sauf l'équipement
            local bankKey = cfg.bank and chars[cfg.bank] and cfg.bank
            if fam and fam ~= "gear" and bankKey and not seen[bankKey] and not noRecv(bankKey, fam) then
                table.insert(needers, { key = bankKey, prio = 6, why = T("perso banque : surplus"), exc = "bank" })
                seen[bankKey] = #needers
            end
            if classID == 9 and #needers == 0 then
                local who, why = self.recipeNeeds(id)
                if who and not noRecv(who) then table.insert(needers, { key = who, need = 1, prio = 2, why = why }) end
            end
            table.sort(needers, function(x, y)
                if x.prio ~= y.prio then return x.prio < y.prio end
                local na, nb = x.need or math.huge, y.need or math.huge
                if na ~= nb then return na > nb end
                return x.key < y.key -- toujours le même ordre : pas d'aller-retour entre deux persos
            end)
            -- besoin restant de chaque perso, une fois son propre stock compté
            local left = {}
            for _, nd in ipairs(needers) do
                left[nd.key] = nd.need and math.max(0, nd.need - (byChar[nd.key] or 0)) or math.huge
            end
            local isNeeder = {}
            for _, nd in ipairs(needers) do isNeeder[nd.key] = isNeeder[nd.key] or nd end
            -- ce que chaque détenteur peut céder : tout s'il n'en a pas besoin, sinon le surplus. Un receveur
            -- « tout » garde tout (il en fera ce qu'il veut) ; un perso qui garde ses récoltes ne cède rien.
            local spare = {}
            for key, cnt in pairs(byChar) do
                if hasMailRule(id, key, cnt) then kept(id, key, T("une règle d'envoi s'en occupe"))
                elseif keeps(key, fam) then kept(id, key, T("garde ses récoltes"))
                else
                    local nd = isNeeder[key]
                    local keep = nd and (nd.need or math.huge) or 0
                    -- un receveur de plus bas rang cède au premier de la liste (pas d'échange en boucle)
                    local first = needers[1]
                    if nd and first and first.key ~= key and nd.need == nil and first.need == nil then keep = 0 end
                    local sp = math.max(0, cnt - keep)
                    if sp > 0 then spare[key] = sp end
                    if keep > 0 and cnt > 0 and nd then
                        kept(id, key, nd.prof and (nd.prof .. " · " .. (nd.why or "")) or nd.why)
                    end
                end
            end
            -- vers ceux qui en ont besoin
            for _, nd in ipairs(needers) do
                for from, sp in pairs(spare) do
                    if from ~= nd.key and left[nd.key] > 0 and sp > 0 then
                        local mv = math.min(sp, left[nd.key])
                        spare[from] = sp - mv
                        left[nd.key] = left[nd.key] - mv
                        send(nd.key, id, mv, from, nd.why, nd.exc)
                    end
                end
            end
            -- personne n'en a besoin et objet verrouillé : jamais vendu, mais rangé chez le perso banque
            local lockedWhy = #needers == 0 and IL and IL:Reason(id)
            if lockedWhy and bankKey then
                for key, sp in pairs(spare) do
                    if key ~= bankKey and sp > 0 then
                        send(bankKey, id, sp, key, T("perso banque : verrouillé, gardé au chaud"), "bank")
                    end
                end
            end
            -- personne n'en a besoin : HV ou marchand (jamais un objet verrouillé par règle)
            if #needers == 0 and fam ~= "gear" and not (IL and IL:Reason(id)) then
                local total, from = 0, {}
                for key, sp in pairs(spare) do if sp > 0 then total = total + sp; from[key] = sp end end
                total = math.max(0, total - (cfg.reserve or 0))
                if total > 0 then
                    local ah, vendor = prices(id)
                    if cfg.ahChar and (not ah or ah * total >= (cfg.minAH or 0)) then
                        local onAH = from[cfg.ahChar]
                        if onAH and onAH > 0 then
                            addTo(out.sell, id, math.min(onAH, total), { [cfg.ahChar] = onAH },
                                ah and T("à vendre") or T("à vérifier : pas de prix"), ah)
                        end
                        local rest = total - (onAH or 0)
                        if rest > 0 then
                            local fr = {}
                            for k, v in pairs(from) do if k ~= cfg.ahChar then fr[k] = v end end
                            addTo(out.ah, id, rest, fr, ah and T("personne n'en a besoin") or T("à vérifier : pas de prix"), ah)
                        end
                    elseif bankKey then
                        -- perso banque : il garde ce qui ne vaut pas la vente à l'HV (au lieu du marchand)
                        for key, sp in pairs(from) do
                            if key ~= bankKey and sp > 0 then
                                send(bankKey, id, sp, key, T("perso banque : personne n'en a besoin"), "bank")
                            end
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
    self:RouteConsumables(consItems, all, send, noRecv)
    local function byName(x, y) return (WK.GetItemInfo(x.id) or "") < (WK.GetItemInfo(y.id) or "") end
    for _, d in pairs(out.dest) do table.sort(d.list, byName) end
    for _, g in ipairs({ out.ah, out.sell, out.vendor }) do table.sort(g.list, byName) end
    return out
end

-- Consommables : nourriture et boisson de son niveau, bandages, potions, vers les persos qui ont un stock voulu
-- (le perso principal d'office). Un détenteur qui a lui-même un stock voulu de ce genre garde le sien.
local function reqLevel(id) return select(5, WK.GetItemInfo(id)) end
local function suits(kind, id, lvl)
    local rl = reqLevel(id)
    if not rl then return false end
    if kind == "bandage" then return true end
    if kind == "potion" then return rl <= lvl end
    return rl <= lvl and rl >= math.max(0, lvl - 15)
end
function M:RouteConsumables(ids, all, send, noRecv)
    local chars = WK.DB.global.characters
    local wants = {}
    for key, c in pairs(chars) do
        local t = self:ConsTargets(key)
        if t and not noRecv(key) then
            wants[#wants + 1] = { key = key, t = t, lvl = c.level or 1, main = key == self:Config().main }
        end
    end
    if #wants == 0 then return end
    table.sort(wants, function(x, y) if x.main ~= y.main then return x.main end return x.key < y.key end)
    local byKind = {}
    for _, id in ipairs(ids) do
        local k = consKind(id)
        if k then byKind[k] = byKind[k] or {}; table.insert(byKind[k], id) end
    end
    local taken = {} -- taken[objet][perso] = déjà cédé
    for _, w in ipairs(wants) do
        for kind, target in pairs(w.t) do
            local fam = (kind == "food" or kind == "drink") and "food" or "heal"
            if type(target) == "number" and target > 0 and not noRecv(w.key, fam) then
                local list = {}
                for _, id in ipairs(byKind[kind] or {}) do if suits(kind, id, w.lvl) then list[#list + 1] = id end end
                table.sort(list, function(x, y) return (reqLevel(x) or 0) > (reqLevel(y) or 0) end)
                local have = 0
                for _, id in ipairs(list) do have = have + (all[id][w.key] or 0) end
                local need = target - have
                local fmt = w.main and T("perso principal : %d %s") or T("stock voulu : %d %s")
                local why = string.format(fmt, target, T(CONS_LABEL[kind]))
                for _, id in ipairs(list) do
                    if need <= 0 then break end
                    for from, cnt in pairs(all[id]) do
                        local ft = self:ConsTargets(from)
                        if from ~= w.key and not (ft and ft[kind]) and need > 0 then
                            taken[id] = taken[id] or {}
                            local sp = cnt - (taken[id][from] or 0)
                            if sp > 0 then
                                local mv = math.min(sp, need)
                                taken[id][from] = (taken[id][from] or 0) + mv
                                need = need - mv
                                send(w.key, id, mv, from, why, w.main and "main" or "cons")
                            end
                        end
                    end
                end
            end
        end
    end
end


-- Envois du perso connecté (objets dans ses sacs) : { { id, count, to = perso, why, ah? } }
-- Pourquoi ce perso (le perso connecté par défaut) garde cet objet au lieu de l'envoyer, ou nil
function M:KeepReason(id, key)
    local k = self:Route().keep
    local e = k and k[id]
    return e and e[key or WK:CharKey()] or nil
end

function M:MyShipments()
    local me = WK:CharKey()
    local r = self:Route()
    local c = WK.DB.global.characters[me]
    local inBags = c and c.bags or {}
    -- objets liés (lié quand ramassé, ou équipé une fois) : le jeu refuse de les poster ; seuls les exemplaires libres
    -- sont proposés (avant : « Cotte d'anneaux » proposée, puis « Rien à envoyer : objets liés… » au clic)
    -- mode fabrication des sacs, envoi au courrier en pause : les composants de la file ne sont pas proposés
    local PH = WK.modules.ProfHelp
    local keepCraft = PH and PH.CraftKeep and PH:CraftKeep("mail")
    local boundN = {}
    local Inv = WK.modules.Inventory
    for _, bag in ipairs(Inv and Inv:BagList() or {}) do
        for slot = 1, (WK.Container.NumSlots(bag) or 0) do
            local id, count, _, bound = WK.Container.Info(bag, slot)
            if id and bound then boundN[id] = (boundN[id] or 0) + (count or 1) end
        end
    end
    local out = {}
    local function take(list, to, ah)
        for _, e in ipairs(list) do
            local n = math.min(e.from[me] or 0, (inBags[e.id] or 0) - (boundN[e.id] or 0))
            if keepCraft and keepCraft[e.id] then n = 0 end
            if n > 0 and to ~= me then
                table.insert(out, { id = e.id, count = n, to = to, why = e.why, ah = ah, exc = e.exc })
            end
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
function stackOf(id)
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
