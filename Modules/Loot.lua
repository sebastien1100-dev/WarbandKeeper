local ADDON_NAME, WK = ...
local M = WK:NewModule("Loot")
local T = function(s) return WK.T(s) end

-- Filtres de loot par profil. À l'ouverture d'un butin, seuls les objets qui passent le
-- profil actif sont ramassés ; les autres restent sur le corps.
--
-- Profil : { name, minQuality, minValue (cuivre), cats = {[clé]=true}, always = {[id]=true},
--            never = {[id]=true}, keepRules = bool, auto = { kind, value } }
--   minQuality = 99 : aucun objet par qualité / valeur (seulement catégories et listes)
--   auto.kind : "none", "zone" (value = nom de zone), "party", "raid", "pvp", "farm"
--
-- Un objet est ramassé si : liste « jamais » -> non ; liste « toujours » -> oui ;
-- objet de quête -> oui ; objet d'une règle d'envoi ou de dépôt (si keepRules) -> oui ;
-- catégorie cochée -> oui ; sinon qualité >= minimale ET valeur >= minimale.
-- L'or et les monnaies sont toujours ramassés.

local MAX_RECENT = 40

local function db() return WK.DB.global.loot end

local function newProfile(name, opts)
    local p = { name = name, minQuality = 0, minValue = 0, cats = {}, always = {}, never = {},
        keepRules = true, auto = { kind = "none" } }
    for k, v in pairs(opts or {}) do p[k] = v end
    return p
end

-- Profils de départ.
function M:OnInit()
    local d = db()
    if not d.profiles or #d.profiles == 0 then
        d.profiles = {
            newProfile(T("Tout ramasser")),
            newProfile(T("Farm (valeur > 1 po)"), { minQuality = 1, minValue = 10000, auto = { kind = "farm" } }),
            newProfile(T("Donjon"), { minQuality = 2, auto = { kind = "party" } }),
            newProfile(T("Raid"), { minQuality = 3, auto = { kind = "raid" } }),
            newProfile(T("Or et quêtes seulement"), { minQuality = 99, keepRules = false }),
        }
        d.active = 1
    end
    d.recent = d.recent or {}
    d.left = d.left or {}          -- [itemID] = { n = quantité, times = fois, last = date, name }
    d.leftSince = d.leftSince or time()
    self.leftSession = 0
end

function M:Profiles() return db().profiles end
function M:Get(i) return db().profiles[i] end

-- Profil choisi par une activation automatique, sinon le profil chargé à la main.
function M:EffectiveIndex()
    local d = db()
    local zone = GetRealZoneText and GetRealZoneText() or ""
    local _, itype = IsInInstance and IsInInstance()
    if itype == "arena" then itype = "pvp" end
    local farming = WK.modules.Farm and WK.modules.Farm:Active()
    local best, bestRank
    for i, p in ipairs(d.profiles) do
        local a, rank = p.auto or {}, nil
        if a.kind == "zone" and a.value and a.value == zone then rank = 3
        elseif (a.kind == "party" or a.kind == "raid" or a.kind == "pvp") and a.kind == itype then rank = 2
        elseif a.kind == "farm" and farming then rank = 1 end
        if rank and (not bestRank or rank > bestRank) then best, bestRank = i, rank end
    end
    return best or d.active or 1, best ~= nil
end

function M:Effective()
    local i, auto = self:EffectiveIndex()
    return self:Get(i), i, auto
end

function M:SetActive(i)
    db().active = i
    WK:NotifyChanged()
end

function M:Add(name)
    table.insert(db().profiles, newProfile(name or T("Nouveau profil")))
    WK:NotifyChanged()
    return #db().profiles
end

function M:Duplicate(i)
    local src = self:Get(i)
    if not src then return end
    local copy = newProfile(src.name .. " " .. T("(copie)"))
    for k, v in pairs(src) do
        if type(v) == "table" then
            copy[k] = {}
            for kk, vv in pairs(v) do copy[k][kk] = vv end
        elseif k ~= "name" then
            copy[k] = v
        end
    end
    copy.auto = { kind = "none" }
    table.insert(db().profiles, copy)
    WK:NotifyChanged()
    return #db().profiles
end

function M:Remove(i)
    local d = db()
    if #d.profiles <= 1 then return end
    table.remove(d.profiles, i)
    if d.active == i then d.active = 1 elseif d.active > i then d.active = d.active - 1 end
    WK:NotifyChanged()
end

---------------------------------------------------------------------------
-- Décision pour un objet.
---------------------------------------------------------------------------
local function hasRule(itemID)
    local R = WK.modules.Rules
    return R:Resolve(WK.modules.Mail:Store(), itemID) or R:Resolve(WK.modules.BankDeposit:Store(), itemID)
end

local function inCategories(p, itemID)
    if not next(p.cats) then return false end
    local class, sub = WK.modules.Rules:ItemClass(itemID)
    for key in pairs(p.cats) do
        local c = WK.modules.Rules.byKey[key]
        if c and c.class == class and (not c.sub or c.sub == sub) then return true end
    end
    return false
end

-- true si l'objet doit être ramassé avec ce profil.
function M:Wants(p, itemID, quality, quantity, isQuest)
    if not itemID then return true end
    if p.never[itemID] then return false end
    if p.always[itemID] or isQuest then return true end
    if p.keepRules and hasRule(itemID) then return true end
    if inCategories(p, itemID) then return true end
    if (p.minQuality or 0) >= 99 then return false end
    if (quality or 1) < (p.minQuality or 0) then return false end
    if (p.minValue or 0) > 0 then
        local price = WK.modules.Value:Price(itemID) * math.max(1, quantity or 1)
        if price < p.minValue then return false end
    end
    return true
end

---------------------------------------------------------------------------
-- Butin
---------------------------------------------------------------------------
function M:GameAutoLoot()
    return GetCVarBool and GetCVarBool("autoLootDefault")
end

function M:DisableGameAutoLoot()
    if SetCVar then SetCVar("autoLootDefault", "0") end
    WK:NotifyChanged()
end

-- Liste cumulée des objets laissés au sol, avec leur prix (unitaire et total).
-- sort : "value" (valeur totale), "count" (quantité) ou "recent".
function M:LeftList(sort)
    local d = db()
    local V = WK.modules.Value
    local list, total, count = {}, 0, 0
    for id, e in pairs(d.left or {}) do
        local unit, src = V:Price(id)
        local item = { id = id, n = e.n, times = e.times, last = e.last, name = e.name,
            unit = unit or 0, src = src, value = (unit or 0) * e.n }
        total, count = total + item.value, count + e.n
        table.insert(list, item)
    end
    table.sort(list, function(a, b)
        if sort == "count" and a.n ~= b.n then return a.n > b.n end
        if sort == "recent" and a.last ~= b.last then return (a.last or 0) > (b.last or 0) end
        if a.value ~= b.value then return a.value > b.value end
        return (a.name or "") < (b.name or "")
    end)
    return list, total, count, d.leftSince
end

function M:ClearLeft()
    local d = db()
    d.left, d.leftSince = {}, time()
    WK:NotifyChanged()
end

local handled, lootOpen = false, false

-- Emplacements encore pleins de la fenêtre de butin : total, et ceux que le profil veut.
local function remaining(p)
    local total, wanted = 0, {}
    for i = 1, (GetNumLootItems() or 0) do
        local _, name, quantity, currencyID, quality, locked, isQuest = GetLootSlotInfo(i)
        local slotType = GetLootSlotType and GetLootSlotType(i) or 1
        local filled = (name and name ~= "") or (quantity and quantity > 0)
        if filled and slotType ~= 0 then
            total = total + 1
            if not locked then
                if slotType ~= 1 or currencyID then
                    table.insert(wanted, i)
                elseif p and M:Wants(p, WK:ParseItemID(GetLootSlotLink(i)), quality, quantity, isQuest) then
                    table.insert(wanted, i)
                end
            end
        end
    end
    return total, wanted
end

-- Vérification juste après le passage du filtre : fenêtre vide -> fermée ; objet voulu encore
-- là -> nouvel essai (puis message si les sacs sont pleins) ; plus que des objets laissés -> fermée.
local function verify(p, attempt)
    if not lootOpen then return end
    local total, wanted = remaining(p)
    if total == 0 then return CloseLoot() end
    if #wanted > 0 then
        if attempt < 2 then
            for k = #wanted, 1, -1 do LootSlot(wanted[k]) end
            C_Timer.After(0.4, function() verify(p, attempt + 1) end)
        else
            WK:Print(T("Butin : des objets voulus n'ont pas pu être ramassés (sacs pleins ?)."))
        end
        return
    end
    if db().closeAfter then CloseLoot() end
end

local function onLoot()
    local d = db()
    if not d.enabled or handled then return end
    -- Maj maintenue (ou touche de bascule du butin auto) : on laisse faire le joueur.
    if IsShiftKeyDown() or (IsModifiedClick and IsModifiedClick("AUTOLOOTTOGGLE")) then return end
    -- Le contenu n'est pas toujours prêt au premier évènement : on attend le suivant.
    if (GetNumLootItems() or 0) == 0 then
        if lootOpen then C_Timer.After(0.3, function() if lootOpen and (GetNumLootItems() or 0) == 0 then CloseLoot() end end) end
        return
    end
    handled = true
    local p = M:Effective()
    if not p then return end
    local left = 0
    for i = GetNumLootItems(), 1, -1 do
        local _, name, quantity, currencyID, quality, locked, isQuest = GetLootSlotInfo(i)
        local slotType = GetLootSlotType and GetLootSlotType(i) or 1
        if not locked then
            if slotType ~= 1 or currencyID then
                LootSlot(i) -- or et monnaies
            else
                local link = GetLootSlotLink(i)
                local id = WK:ParseItemID(link)
                if M:Wants(p, id, quality, quantity, isQuest) then
                    LootSlot(i)
                else
                    left = left + (quantity or 1)
                    M.leftSession = M.leftSession + (quantity or 1)
                    table.insert(d.recent, 1, { id = id, n = quantity or 1, t = time(), name = name })
                    while #d.recent > MAX_RECENT do table.remove(d.recent) end
                    if id then
                        local e = d.left[id] or { n = 0, times = 0 }
                        e.n, e.times, e.last, e.name = e.n + (quantity or 1), e.times + 1, time(), name or e.name
                        d.left[id] = e
                    end
                end
            end
        end
    end
    if left > 0 then WK:NotifyChanged() end
    C_Timer.After(0.3, function() verify(p, 1) end)
end

WK:On("LOOT_READY", onLoot)
WK:On("LOOT_OPENED", function() lootOpen = true; onLoot() end)
WK:On("LOOT_CLOSED", function() handled = false; lootOpen = false end)

-- Prévient quand une activation automatique change le profil.
local lastEffective
local function checkAuto()
    if not db().enabled then return end
    local p, i, auto = M:Effective()
    if p and i ~= lastEffective then
        if lastEffective and auto then WK:Print(string.format(T("Profil de loot : %s"), p.name)) end
        lastEffective = i
        WK:NotifyChanged()
    end
end
WK:On("ZONE_CHANGED_NEW_AREA", function() C_Timer.After(1, checkAuto) end)
WK:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(2, checkAuto) end)
function M:CheckAuto() checkAuto() end
