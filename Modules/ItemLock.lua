local ADDON_NAME, WK = ...
local M = WK:NewModule("ItemLock")
local T = function(s) return WK.T(s) end

-- Objets verrouillés : jamais vendus au marchand.
--   à la main (Alt + clic dans les sacs) : WK.DB.global.itemLock.items[objet] = { at, by }
--   par règle : épiques et plus, liste d'envies, recettes d'un métier de tes persos, objets de quête,
--               valeur HV au-dessus d'un seuil
-- Protection : clic chez le marchand bloqué sur la case (UI/ItemLock.lua), rachat automatique d'un objet
-- verrouillé vendu quand même, confirmation avant une vente chère (objet non verrouillé), et la vente
-- automatique des objets gris, l'envoi par courrier (verrou à la main) le respectent.
-- Hors profils : ce sont des données (sauf les réglages, dans itemLock.cfg).
-- touche pour (dé)verrouiller dans les sacs (UI/ItemLock.lua) : Alt + clic molette par défaut, rarement prise ailleurs
M.KEY_OPTIONS = {
    { "altmid", "Alt + clic molette" }, { "mid", "Clic molette" }, { "ctrlmid", "Ctrl + clic molette" },
    { "alt", "Alt + clic" }, { "ctrl", "Ctrl + clic" }, { "shiftalt", "Maj + Alt + clic" },
    { "ctrlalt", "Ctrl + Alt + clic" }, { "ctrlshift", "Ctrl + Maj + clic" },
}
local DEFAULTS = { key = "altmid", rebuy = true, confirm = true, ratio = 5, confirmMin = 10000,
    rules = { epic = true, wish = true, recipes = true, quest = true, value = false }, valueMin = 50000 }
-- Recettes : sous-classe d'objet » métier. c.professions est rangé par nom dans la langue du jeu :
-- on compare au nom français, au nom anglais et au n° de ligne de compétence (skillLine) quand il est noté.
local RECIPE_PROF = { [1] = "Travail du cuir", [2] = "Couture", [3] = "Ingénierie", [4] = "Forge", [5] = "Cuisine",
    [6] = "Alchimie", [7] = "Secourisme", [8] = "Enchantement", [9] = "Pêche", [10] = "Joaillerie" }
local RECIPE_PROF_EN = { [1] = "Leatherworking", [2] = "Tailoring", [3] = "Engineering", [4] = "Blacksmithing", [5] = "Cooking",
    [6] = "Alchemy", [7] = "First Aid", [8] = "Enchanting", [9] = "Fishing", [10] = "Jewelcrafting" }
local RECIPE_SKILL = { [1] = 165, [2] = 197, [3] = 202, [4] = 164, [5] = 185, [6] = 171, [7] = 129, [8] = 333, [9] = 356, [10] = 755 }

local function db()
    local g = WK.DB.global
    g.itemLock = g.itemLock or {}
    local d = g.itemLock
    d.items, d.never = d.items or {}, d.never or {}
    d.cfg = d.cfg or {}
    for k, v in pairs(DEFAULTS) do
        if d.cfg[k] == nil then
            if type(v) == "table" then d.cfg[k] = {}; for a, b in pairs(v) do d.cfg[k][a] = b end else d.cfg[k] = v end
        end
    end
    for k, v in pairs(DEFAULTS.rules) do if d.cfg.rules[k] == nil then d.cfg.rules[k] = v end end
    -- une fois : les objets de quête protégés par défaut (objets demandés par le journal de quêtes en plus)
    if not d.cfg.questV2 then d.cfg.rules.quest = true; d.cfg.questV2 = true end
    -- une fois : l'ancien défaut (Alt + clic, pris par d'autres addons) passe à Alt + clic molette
    if not d.cfg.keyV2 then
        if d.cfg.key == "alt" then d.cfg.key = "altmid" end
        d.cfg.keyV2 = true
    end
    return d
end
function M:Config() return db().cfg end
function M:Manual() return db().items end

-- Cache des règles : vidé à chaque changement connu, et de toute façon toutes les 5 s
-- (liste d'envies, scan de l'HV, nouveau métier : les règles en dépendent)
local cache, cacheAt = {}, 0
local function changed()
    wipe(cache); cacheAt = GetTime()
    if WK.UI and WK.UI.RefreshItemLocks then WK.UI:RefreshItemLocks() end
    WK:NotifyChanged()
end
M.Changed = changed

local function instant(id)
    local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not f then return nil end
    local ok, _, _, _, _, _, classID, subID = pcall(f, id)
    if not ok then return nil end
    return classID, subID
end
local function quality(id)
    if C_Item and C_Item.GetItemQualityByID then
        local ok, q = pcall(C_Item.GetItemQualityByID, id)
        if ok and q then return q end
    end
    return select(3, WK.GetItemInfo(id))
end
local function wished(id)
    local w = WK.DB.global.dungeons and WK.DB.global.dungeons.wish
    for _, list in pairs(w or {}) do if list[id] then return true end end
    return false
end
-- Un perso du compte a-t-il le métier de cette sous-classe de recette ?
local function profHeld(sub)
    local fr, en, line = RECIPE_PROF[sub], RECIPE_PROF_EN[sub], RECIPE_SKILL[sub]
    local tr = fr and WK.T(fr)
    for _, c in pairs(WK.DB.global.characters) do
        local profs = c.professions
        if profs then
            if (fr and profs[fr]) or (en and profs[en]) or (tr and profs[tr]) then return true end
            for _, p in pairs(profs) do
                if type(p) == "table" and line and p.skillLine == line then return true end
            end
        end
    end
    return false
end

-- Recette déjà apprise par un de tes persos (RecipeDB : objet fabriqué ou sort) ? Inconnue de RecipeDB : non.
local learned, learnedAt = nil, -10
local function knownByAnyone(id)
    local S = WK.modules.Stash
    local rec = S and S.RecipeOf and S:RecipeOf(id)
    if not rec then return false end
    if not learned or GetTime() - learnedAt > 5 then
        learned, learnedAt = { names = {} }, GetTime()
        local R = WK.modules.Recipes
        for _, c in pairs(WK.DB.global.characters) do
            local k = R and R:KnownOutputs(c) or { names = {} }
            for out in pairs(k) do if out ~= "names" then learned[out] = true end end
            for nm in pairs(k.names or {}) do learned.names[nm] = true end
        end
    end
    if rec.o and learned[rec.o] then return true end
    local name = rec.s and WK.SpellInfo and WK.SpellInfo(rec.s)
    return name ~= nil and learned.names[name] == true
end
M.KnownByAnyone = function(_, id) return knownByAnyone(id) end

-- Objets demandés par les quêtes du journal (objectifs de type objet, faits ou pas : il faut encore les
-- rendre) : { [nom de l'objet en minuscules] = titre de la quête } ; relu après chaque QUEST_LOG_UPDATE
local questItems, questDirty = {}, true
local function objectiveName(text)
    if type(text) ~= "string" then return nil end
    local name = text:match("^(.-)%s*:%s*%d+%s*/%s*%d+") or text:match("^%d+%s*/%s*%d+%s+(.+)$") or text
    name = name:gsub("%s+$", "")
    return name ~= "" and name:lower() or nil
end
local function readQuestItems()
    questDirty = false
    wipe(questItems)
    local QL = C_QuestLog
    if not (QL and QL.GetNumQuestLogEntries and QL.GetInfo and QL.GetQuestObjectives) then return end
    local n = QL.GetNumQuestLogEntries() or 0
    for i = 1, n do
        local info = QL.GetInfo(i)
        if info and not info.isHeader and info.questID then
            for _, o in ipairs(QL.GetQuestObjectives(info.questID) or {}) do
                if o.type == "item" then
                    local nm = objectiveName(o.text)
                    if nm then questItems[nm] = info.title or "?" end
                end
            end
        end
    end
end
-- titre de la quête qui demande cet objet (nil si aucune)
function M:QuestFor(id)
    if questDirty then readQuestItems() end
    local name = id and WK.GetItemInfo(id)
    return name and questItems[name:lower()] or nil
end
WK:On("QUEST_LOG_UPDATE", function() questDirty = true; wipe(cache) end)

-- Raison du verrou : "manual", ou le libellé de la règle ; nil si l'objet n'est pas verrouillé
function M:Reason(id)
    if not id then return nil end
    local d = db()
    if d.items[id] then return "manual" end
    if GetTime() - cacheAt > 5 then wipe(cache); cacheAt = GetTime() end
    local c = cache[id]
    if c ~= nil then return c or nil end
    local r = d.cfg.rules
    local why = false
    local classID, subID = instant(id)
    if r.recipes and classID == 9 and RECIPE_PROF[subID] and profHeld(subID) and not knownByAnyone(id) then
        why = string.format(T("recette de %s"), T(RECIPE_PROF[subID]):lower())
    elseif r.quest and (classID == 12 or M:QuestFor(id)) then
        local q = M:QuestFor(id)
        why = q and string.format(T("quête : %s"), q) or T("objet de quête")
    elseif r.wish and wished(id) then
        why = T("liste d'envies")
    else
        local q = quality(id)
        if r.epic and q and q >= 4 then
            why = T("épique ou plus")
        elseif r.value then
            local S = WK.modules.AHScan
            local p = S and S.Price and S:Price(id)
            if type(p) == "number" and p >= (d.cfg.valueMin or 0) then why = T("valeur HV") end
        end
    end
    -- qualité pas encore connue (objet pas en cache) : pas de mise en cache du « non »
    if why or quality(id) then cache[id] = why end
    return why or nil
end
function M:IsLocked(id) return self:Reason(id) ~= nil end

function M:Toggle(id, name)
    if not id then return end
    local d = db()
    if d.items[id] then
        d.items[id] = nil
        WK:Print(string.format(T("Déverrouillé : %s"), name or WK.GetItemInfo(id) or ("#" .. id)))
    else
        d.items[id] = { at = time(), by = WK:CharKey() }
        WK:Print(string.format(T("Verrouillé : %s ne sera pas vendu."), name or WK.GetItemInfo(id) or ("#" .. id)))
    end
    changed()
end
function M:Unlock(id) db().items[id] = nil; changed() end

-- Verrous à la main d'objets qui ne sont plus nulle part sur le compte (recette apprise, objet vendu, utilisé,
-- donné) : retirés. Jamais marchand ouvert ni objet dans le rachat (le rachat automatique en a besoin).
local function inBuyback(id)
    if not (GetNumBuybackItems and GetBuybackItemLink) then return false end
    for i = 1, GetNumBuybackItems() or 0 do
        if WK:ParseItemID(GetBuybackItemLink(i)) == id then return true end
    end
    return false
end
function M:Prune()
    if M:MerchantOpen() or not next(db().items) then return 0 end
    local present = {}
    for _, e in ipairs(self:List()) do if #e.who > 0 then present[e.id] = true end end
    -- objets portés (équipement relevé de chaque perso, et celui du perso connecté lu tout de suite) :
    -- un objet verrouillé puis équipé n'est plus dans les sacs, mais il garde son verrou
    for _, c in pairs(WK.DB.global.characters) do
        for _, link in pairs(c.gear or {}) do
            local id = type(link) == "string" and WK:ParseItemID(link) or (type(link) == "number" and link) or nil
            if id then present[id] = true end
        end
    end
    if GetInventoryItemID then
        for slot = 1, 19 do
            local id = GetInventoryItemID("player", slot)
            if id then present[id] = true end
        end
    end
    local n = 0
    for id in pairs(db().items) do
        if not present[id] and not inBuyback(id) then db().items[id] = nil; n = n + 1 end
    end
    if n > 0 then changed() end
    return n
end
local pruneAt
local function prunesoon(delay)
    pruneAt = GetTime() + (delay or 3)
    C_Timer.After((delay or 3) + 0.1, function() if pruneAt and GetTime() >= pruneAt then pruneAt = nil; M:Prune() end end)
end
WK:On("PLAYER_ENTERING_WORLD", function() prunesoon(10) end)
WK:On("BAG_UPDATE_DELAYED", function() prunesoon(3) end)
WK:On("MERCHANT_CLOSED", function() prunesoon(5) end)
function M:UnlockAll() wipe(db().items); changed() end
function M:Never(id) db().never[id] = true end
function M:IsNever(id) return db().never[id] == true end
function M:RuleChanged() changed() end

-- Objets verrouillés présents sur le compte (sacs, banque, courrier, bataillon) ou posés à la main :
-- { { id, reason, who = { noms } } }
-- Verrous présents : { id, reason, cat ("manual", "quest", "recipe", "other"), prof (recette), count, who = { persos } }
function M:List()
    local seen, out = {}, {}
    local function add(id, who, n)
        local e = seen[id]
        if not e then
            local why = self:Reason(id)
            if not why then return end
            local classID, subID = instant(id)
            e = { id = id, reason = why, who = {}, whoSet = {}, count = 0,
                  cat = why == "manual" and "manual" or (classID == 12 and "quest") or (classID == 9 and "recipe") or "other",
                  prof = classID == 9 and RECIPE_PROF[subID] or nil }
            seen[id] = e
            table.insert(out, e)
        end
        if type(n) == "number" then e.count = e.count + n end
        if who and not e.whoSet[who] then e.whoSet[who] = true; table.insert(e.who, who) end
    end
    for id in pairs(db().items) do add(id) end
    for key, c in pairs(WK.DB.global.characters) do
        local nm = WK:CharName(c, key)
        for _, where in ipairs({ "bags", "bank" }) do for id, n in pairs(c[where] or {}) do add(id, nm, n) end end
        for id, n in pairs(c.mailbox and c.mailbox.items or {}) do add(id, nm, n) end
    end
    for id, n in pairs(WK.DB.global.warbank and WK.DB.global.warbank.items or {}) do add(id, T("Bataillon"), n) end
    table.sort(out, function(a, b)
        if (a.reason == "manual") ~= (b.reason == "manual") then return a.reason == "manual" end
        return (WK.GetItemInfo(a.id) or "") < (WK.GetItemInfo(b.id) or "")
    end)
    return out
end

-- Vente chère (objet non verrouillé) : prix HV bien au-dessus du marchand, ou au-dessus du seuil
function M:Expensive(id)
    local cfg = db().cfg
    if not cfg.confirm or db().never[id] then return false end
    local S = WK.modules.AHScan
    local ah = S and S.Price and S:Price(id)
    if type(ah) ~= "number" or ah < (cfg.confirmMin or 0) then return false end
    local vendor = select(11, WK.GetItemInfo(id)) or 0
    if vendor <= 0 then return false end
    return ah >= vendor * (cfg.ratio or 5), ah, vendor
end

---------------------------------------------------------------------------
-- Rachat automatique : un objet verrouillé apparaît dans le rachat du marchand
---------------------------------------------------------------------------
local merchantOpen = false
local lastBuy = -10
local function checkBuyback()
    if not merchantOpen or not db().cfg.rebuy then return end
    if not (GetNumBuybackItems and GetBuybackItemLink and BuybackItem) then return end
    if GetTime() - lastBuy < 0.5 then return end
    for i = GetNumBuybackItems(), 1, -1 do
        local link = GetBuybackItemLink(i)
        local id = link and WK:ParseItemID(link)
        if id and M:IsLocked(id) then
            local price = (GetBuybackItemInfo and select(3, GetBuybackItemInfo(i))) or 0
            if price > GetMoney() then return end
            lastBuy = GetTime()
            BuybackItem(i)
            local msg = string.format(T("Racheté : %s (objet verrouillé vendu par erreur)"), link)
            WK:Print(msg)
            if UIErrorsFrame then UIErrorsFrame:AddMessage(msg, 0.31, 0.82, 0.77) end
            return
        end
    end
end
WK:On("MERCHANT_SHOW", function() merchantOpen = true; if WK.UI.RefreshItemLocks then WK.UI:RefreshItemLocks() end end)
WK:On("MERCHANT_CLOSED", function() merchantOpen = false; if WK.UI.RefreshItemLocks then WK.UI:RefreshItemLocks() end end)
WK:On("MERCHANT_UPDATE", function() C_Timer.After(0.1, checkBuyback) end)
WK:On("BAG_UPDATE_DELAYED", function() if merchantOpen then C_Timer.After(0.2, checkBuyback) end end)
function M:MerchantOpen() return merchantOpen end
M.CheckBuyback = checkBuyback
