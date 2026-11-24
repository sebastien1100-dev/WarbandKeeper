local ADDON_NAME, WK = ...
local M = WK:NewModule("ProfHelp")
local T = function(s) return WK.T(s) end

-- Aides de métiers (idées du module Professions de Naowh ; aucun code ni donnée repris) :
--   désenchanter ou vendre (tables du jeu, puis tes propres désenchantements), enchantements proposés
--   à l'échange, file de fabrication (WK.DB.global.shopping, décomptée à chaque fabrication) et alertes
--   de recharge, favoris chez le maître, consommables conseillés (carte « Avant de partir » de QoL > Général).
-- Réglages : WK.DB.global.profHelp. Fenêtres : UI/ProfPanels.lua.

local DEFAULTS = { craftTip = true, deTip = true, dePanel = true, trade = true, queueHud = true, queueAuto = true,
    cdAlert = true, trainer = true, prepAlert = false, prepMode = "dungeon",
    -- barre de fabrication (UI/ProfPanels.lua) : temps total d'une série
    craftBar = true, craftBarWhere = "screen", craftBarMin = 3, craftBarQueue = true, craftBarEnd = true, craftBarSound = false }
local PREP_MIN = { heal = 5, mana = 5, food = 10, drink = 10, bandage = 5, elixir = 2 }

function M:Config()
    local g = WK.DB.global
    g.profHelp = g.profHelp or {}
    local c = g.profHelp
    for k, v in pairs(DEFAULTS) do if c[k] == nil then c[k] = v end end
    c.fav = c.fav or {}          -- recettes favorites (nom) : maître, échange
    c.deLog = c.deLog or {}      -- désenchantements faits : [palier] = { n = fois, items = { [id] = total } }
    c.deMark = c.deMark or {}    -- objets marqués « toujours désenchanter » (clic droit dans la fenêtre) : [id] = true
    c.prepMin = c.prepMin or {}
    for k, v in pairs(PREP_MIN) do if c.prepMin[k] == nil then c.prepMin[k] = v end end
    return c
end

local function me() return WK.DB:Me() or {} end
local function profRank(c, names)
    for _, n in ipairs(names) do
        local p = c.professions and c.professions[n]
        if p then return p.rank or 0, n end
    end
end
local ENCH = { "Enchantement", "Enchanting" }
local FIRSTAID = { "Secourisme", "First Aid" }
M.ENCH_NAMES = { ["Enchantement"] = true, ["Enchanting"] = true }
function M:EnchantRank(c) return profRank(c or me(), ENCH) end

---------------------------------------------------------------------------
-- Désenchantement
---------------------------------------------------------------------------
M.DE_SPELL = 13262
-- Résultats moyens par palier de niveau d'objet (données du jeu) : { max, compétence, { { objet, chance, min, max } } }.
-- Armes vertes : poussière et essence inversées (20 % / 75 %).
local DE = {
    [2] = {
        { 15, 1, { { 10940, 80, 1, 2 }, { 10938, 20, 1, 2 } } },
        { 20, 1, { { 10940, 75, 2, 3 }, { 10939, 20, 1, 2 }, { 10978, 5, 1, 1 } } },
        { 25, 25, { { 10940, 75, 4, 6 }, { 10998, 15, 1, 2 }, { 10978, 10, 1, 1 } } },
        { 30, 50, { { 11083, 75, 1, 2 }, { 11082, 20, 1, 2 }, { 11084, 5, 1, 1 } } },
        { 35, 75, { { 11083, 75, 2, 5 }, { 11134, 20, 1, 2 }, { 11138, 5, 1, 1 } } },
        { 40, 100, { { 11137, 75, 1, 2 }, { 11135, 20, 1, 2 }, { 11139, 5, 1, 1 } } },
        { 45, 125, { { 11137, 75, 2, 5 }, { 11174, 20, 1, 2 }, { 11177, 5, 1, 1 } } },
        { 50, 150, { { 11176, 75, 1, 2 }, { 11175, 20, 1, 2 }, { 11178, 5, 1, 1 } } },
        { 55, 175, { { 11176, 75, 2, 5 }, { 16202, 20, 1, 2 }, { 14343, 5, 1, 1 } } },
        { 60, 200, { { 16204, 75, 1, 2 }, { 16203, 20, 1, 2 }, { 14344, 5, 1, 1 } } },
        { 999, 225, { { 16204, 75, 2, 5 }, { 16203, 20, 2, 3 }, { 14344, 5, 1, 1 } } },
    },
    [3] = {
        { 25, 25, { { 10978, 100, 1, 1 } } },
        { 30, 50, { { 11084, 100, 1, 1 } } },
        { 35, 75, { { 11138, 100, 1, 1 } } },
        { 40, 100, { { 11139, 100, 1, 1 } } },
        { 45, 125, { { 11177, 100, 1, 1 } } },
        { 50, 150, { { 11178, 100, 1, 1 } } },
        { 55, 175, { { 14343, 100, 1, 1 } } },
        { 999, 200, { { 14344, 99.5, 1, 1 }, { 20725, 0.5, 1, 1 } } },
    },
    [4] = {
        { 45, 125, { { 11177, 100, 2, 4 } } },
        { 50, 150, { { 11178, 100, 2, 4 } } },
        { 55, 175, { { 14343, 100, 2, 4 } } },
        { 60, 200, { { 20725, 100, 1, 1 } } },
        { 999, 225, { { 20725, 100, 1, 2 } } },
    },
}
local NO_DE = { INVTYPE_BODY = true, INVTYPE_TABARD = true, INVTYPE_BAG = true, INVTYPE_QUIVER = true, INVTYPE_AMMO = true }

-- Palier de désenchantement d'un objet : clé, compétence requise, résultats ; nil si l'objet ne se désenchante pas.
function M:DETier(itemID)
    local _, _, q, ilvl, _, _, _, _, loc, _, _, classID = WK.GetItemInfo(itemID)
    if not q or not DE[q] or not loc or loc == "" or NO_DE[loc] then return nil end
    if classID and classID ~= 2 and classID ~= 4 then return nil end
    ilvl = ilvl or 0
    for i, tier in ipairs(DE[q]) do
        if ilvl <= tier[1] then
            local weapon = classID == 2 and q == 2
            return q .. ":" .. i .. (weapon and "w" or ""), tier[2], tier[3], weapon
        end
    end
end

local function price(id) return WK.modules.Value:Price(id) or 0 end

-- Valeur attendue d'un désenchantement (cuivre), ce qu'il donne { { id, moyenne } } et la source
-- (« mine » quand 5 désenchantements de ce palier au moins ont été notés).
function M:DEValue(itemID)
    local key, skill, out, weapon = self:DETier(itemID)
    if not key then return nil end
    local log = self:Config().deLog[key]
    local list, value = {}, 0
    if log and (log.n or 0) >= 5 then
        for id, total in pairs(log.items) do
            local avg = total / log.n
            table.insert(list, { id, avg }); value = value + avg * price(id)
        end
        table.sort(list, function(a, b) return a[2] * price(a[1]) > b[2] * price(b[1]) end)
        return value, list, skill, "mine", log.n
    end
    for i, o in ipairs(out) do
        local pct = o[2]
        -- armes vertes : la poussière (1re) et l'essence (2e) échangent leurs chances
        if weapon and i == 1 then pct = out[2][2] elseif weapon and i == 2 then pct = out[1][2] end
        local avg = pct / 100 * (o[3] + o[4]) / 2
        table.insert(list, { o[1], avg }); value = value + avg * price(o[1])
    end
    table.sort(list, function(a, b) return a[2] * price(a[1]) > b[2] * price(b[1]) end)
    return value, list, skill, "game"
end

-- Conseil pour un objet : "de" (désenchanter), "ah" (vendre à l'HV), "vendor" ; et les valeurs.
function M:DEAdvice(itemID)
    local v, list, skill, src, n = self:DEValue(itemID)
    if not v then return nil end
    local ah, vendor = WK.modules.Value:Prices(itemID)
    local advice
    if v >= (ah or 0) * 0.9 and v > vendor then advice = "de"
    elseif ah and ah > vendor then advice = "ah"
    else advice = "vendor" end
    -- marqué à la main : toujours désenchanté, quel que soit le prix
    local marked = self:Config().deMark[itemID] and true or nil
    if marked then advice = "de" end
    return { value = v, list = list, skill = skill, src = src, n = n, ah = ah, vendor = vendor, advice = advice,
        marked = marked }
end

-- Marque (ou démarque) un objet « toujours désenchanter »
function M:ToggleDEMark(itemID)
    local m = self:Config().deMark
    m[itemID] = not m[itemID] or nil
    return m[itemID] == true
end
-- Objets des sacs du perso qui se désenchantent : { { bag, slot, id, link, a = conseil, high = compétence trop basse } }
function M:DEBagItems()
    local out = {}
    local rank = self:EnchantRank() or 0
    local IL = WK.modules.ItemLock
    for _, bag in ipairs(WK.modules.Inventory:BagList()) do
        for slot = 1, (WK.Container.NumSlots(bag) or 0) do
            local id = WK.Container.Info(bag, slot)
            if id and not (IL and IL:IsLocked(id)) then
                local a = self:DEAdvice(id)
                if a then
                    local link = C_Container and C_Container.GetContainerItemLink and C_Container.GetContainerItemLink(bag, slot)
                        or (GetContainerItemLink and GetContainerItemLink(bag, slot))
                    table.insert(out, { bag = bag, slot = slot, id = id, link = link, a = a, high = a.skill > rank })
                end
            end
        end
    end
    local order = { de = 1, ah = 2, vendor = 3 }
    table.sort(out, function(x, y)
        if x.high ~= y.high then return not x.high end
        if order[x.a.advice] ~= order[y.a.advice] then return order[x.a.advice] < order[y.a.advice] end
        return x.a.value > y.a.value
    end)
    return out
end

-- Infobulle : valeur attendue du désenchantement (enchanteurs du compte seulement).
local anyEnchanter
function M:AnyEnchanter()
    if anyEnchanter == nil then
        anyEnchanter = false
        for _, c in pairs(WK.DB.global.characters) do if self:EnchantRank(c) then anyEnchanter = true end end
    end
    return anyEnchanter
end
WK:On("SKILL_LINES_CHANGED", function() anyEnchanter = nil end)

function M:AddTooltip(tooltip, itemID, header)
    local any = false
    -- fabriquer ou vendre : une recette d'un de tes persos en tire nettement plus
    if self:Config().craftTip then
        local r = self:CraftOrSell(itemID)
        if r and r.best.perUnit > r.raw * 1.1 and r.best.perUnit - r.raw >= 1 then
            header(); any = true
            local c = WK.DB.global.characters[r.best.crafter]
            local pct = r.raw > 0 and math.floor((r.best.perUnit / r.raw - 1) * 100 + 0.5) or nil
            tooltip:AddDoubleLine(string.format(T("Mieux fabriqué : %s"), r.best.rec.name) .. (c and (" (" .. WK:CharName(c, r.best.crafter) .. ")") or ""),
                WK:FormatMoney(math.floor(r.best.perUnit)) .. (pct and (" (+" .. pct .. " %)") or ""), 0.62, 0.82, 0.48, 1, 1, 1)
        end
    end
    if not self:Config().deTip or not self:AnyEnchanter() then return any end
    local a = self:DEAdvice(itemID)
    if not a or a.value <= 0 then return any end
    header()
    local first = a.list[1]
    local what = first and string.format("%s %s", (first[2] >= 10 or first[2] == math.floor(first[2])) and string.format("%d", first[2]) or string.format("%.1f", first[2]):gsub("%.", ","),
        (WK.UI and WK.UI.ItemInfo and WK.UI:ItemInfo(first[1])) or "?") or ""
    tooltip:AddDoubleLine(string.format(T("Désenchanter : %s"), what), WK:FormatMoney(math.floor(a.value)), 0.62, 0.82, 0.48, 1, 1, 1)
    local rank = self:EnchantRank() or 0
    if a.skill > rank then tooltip:AddLine(string.format(T("  Enchantement %d requis"), a.skill), 0.9, 0.4, 0.4) end
    return true
end

-- Désenchantements faits avec notre bouton : l'objet visé est noté au clic, le butin à l'ouverture.
local pendingDE
function M:ExpectDE(itemID)
    local key = itemID and self:DETier(itemID)
    pendingDE = key and { key = key, t = GetTime and GetTime() or 0 } or nil
end
-- le butin ne compte que si le désenchantement a vraiment abouti (sinon un cadavre fouillé juste après
-- serait noté comme résultat) ; un sort raté ou interrompu oublie l'objet visé
local DE_SPELL = 13262
WK:OnUnit("UNIT_SPELLCAST_SUCCEEDED", "player", function(unit, _, spellID)
    if unit == "player" and spellID == DE_SPELL and pendingDE then pendingDE.ok = true end
end)
for _, ev in ipairs({ "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED" }) do
    WK:On(ev, function(unit, _, spellID) if unit == "player" and spellID == DE_SPELL then pendingDE = nil end end)
end
WK:On("LOOT_OPENED", function()
    if not pendingDE or not pendingDE.ok or ((GetTime and GetTime() or 0) - pendingDE.t) > 12 then return end
    local items = {}
    for i = 1, (GetNumLootItems and GetNumLootItems() or 0) do
        local id = WK:ParseItemID(GetLootSlotLink and GetLootSlotLink(i))
        local _, _, qty = GetLootSlotInfo(i)
        if id then items[id] = (items[id] or 0) + (qty or 1) end
    end
    if not next(items) then return end
    local log = M:Config().deLog
    local e = log[pendingDE.key] or { n = 0, items = {} }
    e.n = e.n + 1
    for id, n in pairs(items) do e.items[id] = (e.items[id] or 0) + n end
    log[pendingDE.key] = e
    pendingDE = nil
end)

---------------------------------------------------------------------------
-- Enchantements à l'échange
---------------------------------------------------------------------------
-- Mots des noms d'enchantement par emplacement (anglais et français)
local SLOT_WORDS = {
    INVTYPE_FEET = { "boots", "bottes" }, INVTYPE_WRIST = { "bracer", "brassard", "bracelet" },
    INVTYPE_CHEST = { "chest", "plastron", "torse" }, INVTYPE_ROBE = { "chest", "plastron", "torse" },
    INVTYPE_CLOAK = { "cloak", "cape" }, INVTYPE_HAND = { "gloves", "gants" }, INVTYPE_SHIELD = { "shield", "bouclier" },
    INVTYPE_2HWEAPON = { "weapon", "arme" }, INVTYPE_WEAPON = { "weapon", "arme" }, INVTYPE_WEAPONMAINHAND = { "weapon", "arme" },
    INVTYPE_WEAPONOFFHAND = { "weapon", "arme" },
}
local TWO_H = { "2h", "deux mains", "2m" }
local function has(s, words) for _, w in ipairs(words) do if s:find(w, 1, true) then return true end end end

-- Enchantements que le perso connaît (sans objet fabriqué), pour un emplacement (nil = tous) :
-- { { key, name, reagents, have = tous les composants dans les sacs, missing, fav } }
function M:Enchants(equipLoc)
    local c = me()
    local fav = self:Config().fav
    local out = {}
    for k, r in pairs(c.recipes or {}) do
        if M.ENCH_NAMES[r.prof or ""] and not r.out and r.name then
            local low = r.name:lower()
            local ok = true
            if equipLoc then
                local words = SLOT_WORDS[equipLoc]
                ok = words ~= nil and has(low, words)
                if ok and equipLoc ~= "INVTYPE_2HWEAPON" and has(low, TWO_H) then ok = false end
            end
            if ok then
                local missing = 0
                for _, rg in ipairs(r.reagents or {}) do
                    local n = (c.bags or {})[rg[1]] or 0
                    if n < rg[2] then missing = missing + (rg[2] - n) end
                end
                table.insert(out, { key = k, name = r.name, icon = r.icon, reagents = r.reagents, have = missing == 0, missing = missing, fav = fav[r.name] == true })
            end
        end
    end
    table.sort(out, function(a, b)
        if a.fav ~= b.fav then return a.fav end
        if a.have ~= b.have then return a.have end
        return a.name < b.name
    end)
    return out
end

function M:ToggleFav(name)
    local f = self:Config().fav
    f[name] = (not f[name]) or nil
    WK:NotifyChanged()
end

-- Texte d'annonce : favoris d'abord, sans dépasser une ligne de chat.
function M:EnchantAd()
    local list = self:Enchants(nil)
    local names = {}
    local txt = T("J'enchante : ")
    for _, e in ipairs(list) do
        if #txt + #e.name + 2 > 240 then break end
        table.insert(names, e.name)
        txt = T("J'enchante : ") .. table.concat(names, ", ")
    end
    return #names > 0 and txt or nil
end

---------------------------------------------------------------------------
-- File de fabrication (liste de courses) : décomptée à chaque fabrication réussie
---------------------------------------------------------------------------
M.session = {} -- fabrications faites depuis la connexion : [clé] = n

local function recipeForSpell(spellID)
    local c = me()
    local name = WK.SpellInfo(spellID)
    for k, r in pairs(c.recipes or {}) do
        if r.spell == spellID or (name and r.name == name) then return k, r end
    end
end
M.RecipeForSpell = recipeForSpell

WK:OnUnit("UNIT_SPELLCAST_SUCCEEDED", "player", function(unit, _, spellID)
    if unit ~= "player" or not spellID then return end
    if spellID == M.DE_SPELL then return end
    local list = WK.DB.global.shopping
    if not next(list) then return end
    local k = recipeForSpell(spellID)
    if k and list[k] then
        M.session[k] = (M.session[k] or 0) + 1
        if M:Config().queueAuto then WK.modules.Recipes:AddToList(k, -1) end
        if WK.UI and WK.UI.RefreshCraftHUD then WK.UI:RefreshCraftHUD() end
    end
end)

-- Fenêtre du métier ouverte : le métier et les recettes du perso qu'elle peut fabriquer.
function M:OpenProfession()
    if C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo then
        local ok, info = pcall(C_TradeSkillUI.GetBaseProfessionInfo)
        if ok and info and info.professionName then return info.professionName end
    end
    if GetTradeSkillLine then
        local n = GetTradeSkillLine()
        if n and n ~= "UNKNOWN" then return n end
    end
end

-- Entrées de la file : { key, rec, qty, crafter = clé du perso, mine, can = fabrications possibles avec ses sacs,
--   missing = { { id, n, where } }, cd = recharge (secondes restantes) }
function M:Queue()
    local _, index = WK.modules.Recipes:All()
    local chars = WK.DB.global.characters
    local myKey = WK:CharKey()
    local out = {}
    for k, qty in pairs(WK.DB.global.shopping) do
        local rec = index[k]
        local e = { key = k, rec = rec, qty = qty, missing = {} }
        if rec then
            local crafter = rec.crafters[1]
            for _, ck in ipairs(rec.crafters) do if ck == myKey then crafter = ck end end
            e.crafter, e.mine = crafter, crafter == myKey
            local c = chars[crafter] or {}
            local can = math.huge
            for _, rg in ipairs(rec.reagents or {}) do
                local inBags = (c.bags or {})[rg[1]] or 0
                can = math.min(can, math.floor(inBags / math.max(1, rg[2])))
                local need = rg[2] * qty - inBags
                if need > 0 then
                    -- ailleurs sur le compte ?
                    local where
                    for ok2, oc in pairs(chars) do
                        if ok2 ~= crafter and WK.modules.Inventory:CharCount(oc, rg[1]) >= need then where = ok2; break end
                    end
                    table.insert(e.missing, { id = rg[1], n = need, where = where })
                end
            end
            e.can = can == math.huge and qty or can
            local cd = c.cooldowns and c.cooldowns[k]
            if cd and cd.readyAt > time() then e.cd = cd.readyAt - time() end
        end
        table.insert(out, e)
    end
    table.sort(out, function(a, b)
        if (a.mine or false) ~= (b.mine or false) then return a.mine end
        return (a.rec and a.rec.name or a.key) < (b.rec and b.rec.name or b.key)
    end)
    return out
end

-- Lance n fabrications d'une recette dans la fenêtre du métier ouverte. Renvoie true si c'est parti.
function M:Craft(key, n)
    local c = me()
    local r = c.recipes and c.recipes[key]
    if not r then return false end
    n = math.max(1, n or 1)
    if C_TradeSkillUI and C_TradeSkillUI.CraftRecipe and r.spell then
        return (pcall(C_TradeSkillUI.CraftRecipe, r.spell, n))
    end
    if GetNumTradeSkills and DoTradeSkill then
        for i = 1, GetNumTradeSkills() do
            if GetTradeSkillInfo(i) == r.name then DoTradeSkill(i, n); return true end
        end
    end
    return false
end

-- Recharges de tout le compte : { { key, c, ck, name, readyAt, ready, total } }
function M:AllCooldowns()
    local out = {}
    local now = time()
    for ck, c in pairs(WK.DB.global.characters) do
        for k, cd in pairs(c.cooldowns or {}) do
            table.insert(out, { key = k, ck = ck, c = c, name = (c.recipes and c.recipes[k] and c.recipes[k].name) or k,
                readyAt = cd.readyAt, ready = cd.readyAt <= now, prof = cd.prof })
        end
    end
    table.sort(out, function(a, b) return a.readyAt < b.readyAt end)
    return out
end

-- Alerte quand une recharge se termine (une fois par recharge, sur n'importe quel perso)
local function checkCooldowns()
    if not M:Config().cdAlert then return end
    local now = time()
    for ck, c in pairs(WK.DB.global.characters) do
        for k, cd in pairs(c.cooldowns or {}) do
            if cd.readyAt <= now and not cd.told and now - cd.readyAt < 7 * 86400 then
                cd.told = true
                local name = (c.recipes and c.recipes[k] and c.recipes[k].name) or k
                local msg = string.format(T("%s : %s est de nouveau prête."), WK:CharName(c, ck), name)
                WK:Print(msg)
                if WK.modules.QoL and WK.modules.QoL.Remind then WK.modules.QoL:Remind("cd" .. ck .. k, msg, 0.62, 0.82, 0.48) end
            end
        end
    end
end
function M:OnLogin()
    self:Config()
    -- recharges déjà finies à la connexion : prévenues une seule fois
    C_Timer.After(20, checkCooldowns)
    if C_Timer.NewTicker then C_Timer.NewTicker(60, checkCooldowns) end
end

---------------------------------------------------------------------------
-- Maître de métier : recettes à apprendre ici
---------------------------------------------------------------------------
-- { { index, name, cost, fav, guideTo, knownBy = clé d'un autre perso } }
function M:TrainerList()
    if not GetNumTrainerServices then return {} end
    local fav = self:Config().fav
    local _, index = WK.modules.Recipes:All()
    local myKey = WK:CharKey()
    -- étapes des guides : nom de recette » palier atteint
    local guideTo = {}
    for _, g in pairs(WK.Guides or {}) do
        for _, st in ipairs(g.steps or {}) do
            local n = st.spell and WK.SpellInfo(st.spell)
            if not n and st.out then n = (WK.GetItemInfo(st.out)) end
            if n then guideTo[n] = math.max(guideTo[n] or 0, st.to or 0) end
        end
    end
    local out = {}
    for i = 1, GetNumTrainerServices() do
        local name, _, category = GetTrainerServiceInfo(i)
        if name and category == "available" then
            local e = { index = i, name = name, cost = GetTrainerServiceCost and (GetTrainerServiceCost(i)) or 0, fav = fav[name] == true, guideTo = guideTo[name] }
            local rec = index[name]
            if rec then for _, ck in ipairs(rec.crafters) do if ck ~= myKey then e.knownBy = ck; break end end end
            table.insert(out, e)
        end
    end
    table.sort(out, function(a, b)
        if a.fav ~= b.fav then return a.fav end
        if (a.guideTo ~= nil) ~= (b.guideTo ~= nil) then return a.guideTo ~= nil end
        return a.index < b.index
    end)
    return out
end

-- Apprend les favoris disponibles (du dernier au premier : les numéros ne bougent pas). Renvoie le nombre appris.
-- Achat d'une recette du maître, seulement si la ligne porte toujours ce nom (un double clic rapide, la liste
-- décalée par l'achat précédent, achetait sinon une autre recette) ; jamais en combat
function M.BuyService(_, index, name)
    if (_G.InCombatLockdown and _G.InCombatLockdown()) or not BuyTrainerService then return false end
    if name and _G.GetTrainerServiceInfo and _G.GetTrainerServiceInfo(index) ~= name then return false end
    BuyTrainerService(index)
    return true
end
function M:LearnFavs()
    local list = self:TrainerList()
    table.sort(list, function(a, b) return a.index > b.index end)
    local n, money = 0, GetMoney and GetMoney() or 0
    for _, e in ipairs(list) do
        if e.fav and e.cost <= money and self:BuyService(e.index, e.name) then
            money = money - e.cost; n = n + 1
        end
    end
    return n
end

---------------------------------------------------------------------------
-- Consommables conseillés (carte « Avant de partir »)
---------------------------------------------------------------------------
-- { objet, niveau requis } du moins bon au meilleur ; bandages : compétence de Secourisme.
M.CONSUMABLES = {
    heal = { label = "Soins", list = { { 118, 1 }, { 858, 3 }, { 929, 12 }, { 1710, 21 }, { 3928, 35 }, { 13446, 45 } } },
    mana = { label = "Mana", mana = true, list = { { 2455, 5 }, { 3385, 14 }, { 3827, 22 }, { 6149, 31 }, { 13443, 41 }, { 13444, 49 } } },
    food = { label = "Nourriture", list = { { 4540, 1 }, { 4541, 5 }, { 4542, 15 }, { 4544, 25 }, { 4601, 35 }, { 8950, 45 } } },
    drink = { label = "Boisson", mana = true, list = { { 159, 1 }, { 1179, 5 }, { 1205, 15 }, { 1708, 25 }, { 1645, 35 }, { 8766, 45 } } },
    bandage = { label = "Bandages", skill = true, list = { { 1251, 1 }, { 2581, 40 }, { 3530, 80 }, { 3531, 115 }, { 6450, 150 },
        { 6451, 180 }, { 8544, 210 }, { 8545, 240 }, { 14529, 260 }, { 14530, 290 } } },
}
local ELIXIRS = {
    agi = { label = "Agilité", list = { { 2457, 2 }, { 3390, 18 }, { 8949, 27 }, { 9187, 38 }, { 13452, 46 } } },
    str = { label = "Force", list = { { 2454, 1 }, { 3391, 20 }, { 9206, 48 } } },
    int = { label = "Intelligence", list = { { 3383, 10 }, { 9179, 37 }, { 13447, 38 } } },
    spell = { label = "Puissance des sorts", list = { { 3383, 10 }, { 9155, 37 }, { 13454, 47 } } },
}
local CLASS_ELIXIR = { HUNTER = "agi", ROGUE = "agi", WARRIOR = "str", PALADIN = "str", MAGE = "spell", WARLOCK = "spell",
    PRIEST = "int", SHAMAN = "int", DRUID = "int" }
local NO_MANA = { WARRIOR = true, ROGUE = true }
M.PREP_ORDER = { "heal", "mana", "elixir", "food", "drink", "bandage" }
-- Seuil selon le mode : donjon x1, raid x2, JcJ (pas d'élixir, moitié de nourriture)
local MODE_MUL = { dungeon = {}, raid = { all = 2 }, pvp = { elixir = 0, food = 0.5, drink = 0.5 } }

-- Lignes de la carte pour un perso : { { cat, label, best, bags, elsewhere = { { ck, n } }, min, low, how, howKind } }
function M:Prep(ck)
    local cfg = self:Config()
    local chars = WK.DB.global.characters
    local c = chars[ck] or {}
    local lvl = c.level or 1
    local mul = MODE_MUL[cfg.prepMode] or {}
    local _, index = WK.modules.Recipes:All()
    local byOut = {}
    for _, rec in pairs(index) do if rec.out then byOut[rec.out] = rec end end
    local rows = {}
    for _, cat in ipairs(self.PREP_ORDER) do
        local def = self.CONSUMABLES[cat]
        if cat == "elixir" then def = ELIXIRS[CLASS_ELIXIR[c.class or ""] or "agi"] end
        local skip = def.mana and NO_MANA[c.class or ""]
        local level = lvl
        if def.skill then
            level = profRank(c, FIRSTAID)
            if not level then skip = true end
        end
        local m = mul.all or mul[cat] or 1
        local min = math.floor((cfg.prepMin[cat] or 0) * m + 0.5)
        if not skip and min > 0 then
            local best, bags, other = nil, 0, {}
            for _, it in ipairs(def.list) do
                if it[2] <= (level or 0) then
                    best = it[1]
                    bags = bags + ((c.bags or {})[it[1]] or 0)
                end
            end
            if best then
                -- ce qui reste ailleurs : banque du perso, puis les autres persos (meilleur objet seulement)
                local bank = (c.bank or {})[best] or 0
                if bank > 0 then table.insert(other, { ck, bank, bank = true }) end
                for ok2, oc in pairs(chars) do
                    if ok2 ~= ck then
                        local n = WK.modules.Inventory:CharCount(oc, best)
                        if n > 0 then table.insert(other, { ok2, n }) end
                    end
                end
                local how, kind
                local rec = byOut[best]
                if rec then
                    how, kind = rec.crafters, "craft"
                else
                    local ah, vendor = WK.modules.Value:Prices(best)
                    if ah then how, kind = ah, "ah" elseif vendor > 0 then how, kind = vendor, "vendor" end
                end
                table.insert(rows, { cat = cat, label = def.label, best = best, bags = bags, elsewhere = other,
                    min = min, low = bags < min, how = how, howKind = kind })
            end
        end
    end
    return rows
end

-- Alertes « À faire » (QoL:Alerts) : perso connecté, consommables sous le seuil.
function M:AddAlerts(out)
    if not self:Config().prepAlert then return end
    local ck = WK:CharKey()
    local c = WK.DB.global.characters[ck]
    if not c or (c.level or 0) < 10 then return end
    for _, r in ipairs(self:Prep(ck)) do
        if r.low then
            local name = (WK.UI and WK.UI.ItemInfo and WK.UI:ItemInfo(r.best)) or T(r.label)
            table.insert(out, { key = ck, c = c, kind = "reagent", urgent = false,
                text = string.format(T("%s : %s bas (%d sur %d)"), WK:CharName(c, ck), name, r.bags, r.min) })
        end
    end
end

---------------------------------------------------------------------------
-- Fabriquer ou vendre ? (idée de The Market, rien de repris) : pour un composant, la meilleure recette
-- connue d'un de tes persos, ramenée à l'unité du composant : (prix de l'objet fabriqué x quantité
-- - prix des autres composants) / nombre de ce composant. Comparée à la vente brute.
---------------------------------------------------------------------------
local usesCache, usesAt
local function uses()
    if usesCache and usesAt and time() - usesAt < 30 then return usesCache end
    local list = WK.modules.Recipes:All()
    usesCache, usesAt = {}, time()
    for _, rec in ipairs(list) do
        if rec.out then
            for _, rg in ipairs(rec.reagents or {}) do
                usesCache[rg[1]] = usesCache[rg[1]] or {}
                table.insert(usesCache[rg[1]], rec)
            end
        end
    end
    return usesCache
end
-- { raw = prix brut, best = { rec, perUnit, crafter } } ou nil
function M:CraftOrSell(itemID)
    local recs = uses()[itemID]
    if not recs then return nil end
    local V = WK.modules.Value
    local raw = V:Price(itemID) or 0
    local best
    for _, rec in ipairs(recs) do
        local outP = V:Price(rec.out) or 0
        if outP > 0 then
            local mine, others = 0, 0
            for _, rg in ipairs(rec.reagents or {}) do
                if rg[1] == itemID then mine = mine + rg[2] else others = others + (V:Price(rg[1]) or 0) * rg[2] end
            end
            if mine > 0 then
                local per = (outP * (rec.qty or 1) - others) / mine
                if not best or per > best.perUnit then best = { rec = rec, perUnit = per, crafter = rec.crafters[1], need = mine } end
            end
        end
    end
    if not best then return nil end
    return { raw = raw, best = best }
end
-- composants du compte qui rapportent plus fabriqués : { { id, count, raw, best, gain } }, du plus gros gain
function M:CraftOrSellList()
    local Inv = WK.modules.Inventory
    local out = {}
    for id in pairs(uses()) do
        local n = Inv:AccountCount(id)
        if n > 0 then
            local r = self:CraftOrSell(id)
            if r then
                local crafts = math.floor(n / math.max(1, r.best.need))
                local gain = (r.best.perUnit - r.raw) * crafts * r.best.need
                table.insert(out, { id = id, count = n, raw = r.raw * n, best = r.best, gain = gain, crafts = crafts })
            end
        end
    end
    table.sort(out, function(a, b) return a.gain > b.gain end)
    return out
end

---------------------------------------------------------------------------
-- Conseil de métier : parmi les recettes que le perso connaît, l'orange (un point sûr) puis la jaune la
-- moins chère au prix du jour ; et combien il peut en faire avec ce qu'il a (sacs, banque, courrier).
---------------------------------------------------------------------------
function M:Advice(c, prof)
    if not c or not prof then return nil end
    local R, Inv = WK.modules.Recipes, WK.modules.Inventory
    local best
    for _, rec in ipairs(R:ForProfession(c, prof)) do
        if (rec.diff == "optimal" or rec.diff == "medium") and rec.reagents and #rec.reagents > 0 then
            local cost = R:Economics(rec)
            local can = math.huge
            for _, rg in ipairs(rec.reagents) do
                can = math.min(can, math.floor(Inv:CharCount(c, rg[1]) / math.max(1, rg[2])))
            end
            local rank = rec.diff == "optimal" and 1 or 2
            if not best or rank < best.rank or (rank == best.rank and cost < best.cost) then
                best = { rec = rec, cost = cost, can = can == math.huge and 0 or can, rank = rank, color = rec.diff }
            end
        end
    end
    return best
end

---------------------------------------------------------------------------
-- Mode fabrication (sacs, maquette A) : les composants de la file de fabrication du perso connecté restent dans
-- ses sacs. Réglages WK.DB.global.craftMode = { on, mail, bank, autoOff } : mail / bank = vrai si l'envoi au
-- courrier / le dépôt en banque restent actifs pendant le mode (faux d'office : en pause) ; autoOff = le mode se
-- coupe en fermant la fenêtre du métier.
---------------------------------------------------------------------------
function M.CraftMode(_)
    local g = WK.DB.global
    g.craftMode = g.craftMode or {}
    local c = g.craftMode
    if c.mail == nil then c.mail = false end
    if c.bank == nil then c.bank = false end
    if c.autoOff == nil then c.autoOff = true end
    return c
end
-- Composants à garder (n° d'objet » vrai) ; kind = "mail" ou "bank" : nil si cet envoi reste actif ; nil hors mode
function M:CraftKeep(kind)
    local c = self:CraftMode()
    if not c.on then return nil end
    if kind and c[kind] then return nil end
    local keep, any = {}, false
    local ok, q = pcall(self.Queue, self)
    for _, e in ipairs(ok and q or {}) do
        if e.mine and e.rec then
            for _, rg in ipairs(e.rec.reagents or {}) do keep[rg[1]] = true; any = true end
        end
    end
    return any and keep or {}
end
function M:SetCraftMode(on)
    self:CraftMode().on = on and true or nil
    local St = WK.modules.Stash
    if St and St.Invalidate then St:Invalidate() end
    WK:NotifyChanged()
    -- les sacs ne suivent pas le rafraîchissement de la fenêtre principale : repeints ici (bouton, bandeau, tri)
    local Bags = WK.UI and WK.UI.Bags
    if Bags and Bags.Refresh then Bags.Refresh() end
end
WK:On("TRADE_SKILL_CLOSE", function()
    local c = M:CraftMode()
    if c.on and c.autoOff then M:SetCraftMode(false) end
end)
