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
local DEFAULTS = { key = "alt", rebuy = true, confirm = true, ratio = 5, confirmMin = 10000,
    rules = { epic = true, wish = true, recipes = true, quest = false, value = false }, valueMin = 50000 }
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
    if r.recipes and classID == 9 and RECIPE_PROF[subID] and profHeld(subID) then
        why = string.format(T("recette de %s"), T(RECIPE_PROF[subID]):lower())
    elseif r.quest and classID == 12 then
        why = T("objet de quête")
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
function M:UnlockAll() wipe(db().items); changed() end
function M:Never(id) db().never[id] = true end
function M:IsNever(id) return db().never[id] == true end
function M:RuleChanged() changed() end

-- Objets verrouillés présents sur le compte (sacs, banque, courrier, bataillon) ou posés à la main :
-- { { id, reason, who = { noms } } }
function M:List()
    local seen, out = {}, {}
    local function add(id, who)
        local e = seen[id]
        if not e then
            local why = self:Reason(id)
            if not why then return end
            e = { id = id, reason = why, who = {}, whoSet = {} }
            seen[id] = e
            table.insert(out, e)
        end
        if who and not e.whoSet[who] then e.whoSet[who] = true; table.insert(e.who, who) end
    end
    for id in pairs(db().items) do add(id) end
    for key, c in pairs(WK.DB.global.characters) do
        local nm = WK:CharName(c, key)
        for _, where in ipairs({ "bags", "bank" }) do for id in pairs(c[where] or {}) do add(id, nm) end end
        for id in pairs(c.mailbox and c.mailbox.items or {}) do add(id, nm) end
    end
    for id in pairs(WK.DB.global.warbank and WK.DB.global.warbank.items or {}) do add(id, T("Bataillon")) end
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
            local price = select(3, GetBuybackItemInfo(i)) or 0
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
