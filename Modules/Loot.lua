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
    d.left = d.left or {}          -- [itemID] = { n = quantité, times = fois, last = date, name, full, fullN,
                                   --   zones = { [zone] = fois }, prof = { [profil] = fois } }
    d.leftHide = d.leftHide or {}  -- [itemID] = true : « ne plus lister » (jamais noté ni montré)
    d.fullAt = d.fullAt or {}      -- dates des objets laissés faute de place (sacs pleins), 200 au plus
    d.leftSince = d.leftSince or time()
    self.leftSession = 0
end

function M:Profiles() return db().profiles end
function M:Get(i) return db().profiles[i] end

-- Profil choisi par une activation automatique, sinon le profil chargé à la main.
function M:EffectiveIndex()
    local d = db()
    local zone = GetRealZoneText and GetRealZoneText() or ""
    local itype
    if IsInInstance then itype = select(2, IsInInstance()) end
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
    return WK.GetCVarBool("autoLootDefault")
end

function M:DisableGameAutoLoot()
    WK.SetCVar("autoLootDefault", "0")
    WK:NotifyChanged()
end

-- Liste cumulée des objets laissés au sol, avec leur prix (unitaire et total).
-- sort : "value" (valeur totale), "count" (quantité) ou "recent".
-- filter (facultatif) : { reason = "filter" | "full", prof = nom du profil } ; le total et le nombre
-- rendus sont ceux de la liste filtrée
function M.LeftList(_, sort, filter)
    local d = db()
    local V = WK.modules.Value
    local list, total, count = {}, 0, 0
    filter = filter or {}
    for id, e in pairs(d.left or {}) do
        local fullN = e.full or 0
        local keep = not (d.leftHide or {})[id]
        if keep and filter.reason == "full" then keep = fullN > 0 end
        if keep and filter.reason == "filter" then keep = (e.n or 0) > fullN end
        if keep and filter.prof then keep = e.prof ~= nil and (e.prof[filter.prof] or 0) > 0 end
        if keep then
            local unit, src = V:Price(id)
            local n = e.n
            if filter.reason == "full" then n = fullN elseif filter.reason == "filter" then n = e.n - fullN end
            local item = { id = id, n = n, times = e.times, last = e.last, name = e.name, full = e.full,
                fullN = e.fullN, zones = e.zones, prof = e.prof,
                unit = unit or 0, src = src, value = (unit or 0) * n }
            total, count = total + item.value, count + n
            table.insert(list, item)
        end
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
    -- la colonne « Laissés au sol récemment » et le compteur de la séance repartent aussi de zéro
    d.left, d.leftSince, d.fullAt, d.recent = {}, _G.time(), {}, {}
    M.leftSession = 0
    WK:NotifyChanged()
end

-- « Ne plus lister » : retiré de la liste et plus jamais noté (le profil n'est pas touché)
function M.HideLeft(_, id)
    local d = db()
    if not id then return end
    d.leftHide = d.leftHide or {}
    d.leftHide[id] = true
    if d.left then d.left[id] = nil end
    WK:NotifyChanged()
end

-- Bilan de la liste (maquette A) : valeur totale, part du filtre et des sacs pleins, sacs pleins sur 7 jours,
-- objet le plus cher, et objets qui valent le coup (prix unitaire >= minUnit) pas encore « toujours » dans p
function M.LeftStats(_, p, minUnit)
    local d = db()
    local V = WK.modules.Value
    local st = { total = 0, filter = 0, full = 0, count = 0, fullWeek = 0, worth = {}, worthValue = 0 }
    local week = _G.time() - 7 * 86400
    for _, t in ipairs(d.fullAt or {}) do if t >= week then st.fullWeek = st.fullWeek + 1 end end
    for id, e in pairs(d.left or {}) do
        if not (d.leftHide or {})[id] then
            local unit = V:Price(id) or 0
            local fullN = e.full or 0
            local v = unit * (e.n or 0)
            st.total, st.count = st.total + v, st.count + (e.n or 0)
            st.full = st.full + unit * fullN
            st.filter = st.filter + unit * ((e.n or 0) - fullN)
            if not st.best or v > st.best.value then st.best = { id = id, name = e.name, value = v } end
            if unit >= (minUnit or 2000) and not (p and (p.always[id] or p.never[id])) then
                st.worth[#st.worth + 1] = id
                st.worthValue = st.worthValue + v
            end
        end
    end
    return st
end

-- Toujours ramasser une liste d'objets dans un profil (ou dans tous : p = nil)
function M:AlwaysLoot(ids, p)
    local list = p and { p } or self:Profiles()
    for _, pr in ipairs(list) do
        for _, id in ipairs(ids) do pr.always[id] = true; pr.never[id] = nil end
    end
    WK:NotifyChanged()
end

-- Pourquoi un objet a été laissé avec ce profil (texte court), d'après ses réglages actuels
function M.WhyLeft(_, p, id)
    if not (p and id) then return nil end
    if p.never[id] then return T("dans sa liste « jamais »") end
    if p.always[id] then return T("maintenant dans sa liste « toujours »") end
    if (p.minQuality or 0) >= 99 then return T("ne ramasse que l'or et les objets de quête") end
    local q = select(3, WK.GetItemInfo(id))
    if q and q < (p.minQuality or 0) then
        local names = { [0] = T("Grise"), T("Blanche"), T("Verte"), T("Bleue"), T("Épique") }
        return string.format(T("qualité minimale : %s"), names[p.minQuality] or tostring(p.minQuality))
    end
    if (p.minValue or 0) > 0 then
        return string.format(T("valeur minimale : %s"), WK.UI:PlainMoney(p.minValue))
    end
    return nil
end

local handled, lootOpen = false, false

-- Note un objet resté au sol (filtre, ou sacs pleins quand full = true).
local function recordLeft(id, qty, name, full)
    local d = db()
    qty = qty or 1
    if id and d.leftHide and d.leftHide[id] then return end -- « ne plus lister »
    M.leftSession = M.leftSession + qty
    table.insert(d.recent, 1, { id = id, n = qty, t = time(), name = name, full = full or nil })
    while #d.recent > MAX_RECENT do table.remove(d.recent) end
    if full then
        d.fullAt = d.fullAt or {}
        table.insert(d.fullAt, _G.time())
        while #d.fullAt > 200 do table.remove(d.fullAt, 1) end
    end
    if id then
        local e = d.left[id] or { n = 0, times = 0 }
        e.n, e.times, e.last, e.name = e.n + qty, e.times + 1, time(), name or e.name
        if full then e.full = (e.full or 0) + qty; e.fullN = (e.fullN or 0) + 1 end
        -- où (zone) et avec quel profil : pour la fiche de l'objet
        local zone = _G.GetRealZoneText and _G.GetRealZoneText() or nil
        if zone and zone ~= "" and not (_G.issecretvalue and _G.issecretvalue(zone)) then
            e.zones = e.zones or {}
            e.zones[zone] = (e.zones[zone] or 0) + 1
        end
        local p = M:Effective()
        if p and p.name then
            e.prof = e.prof or {}
            e.prof[p.name] = (e.prof[p.name] or 0) + 1
        end
        d.left[id] = e
    end
end

-- En groupe, les objets au-dessus du seuil de butin se tirent aux dés (ou passent par le maître du
-- butin) : ils partent chez le gagnant, ce n'est ni au filtre de les prendre ni « laissé au sol ».
local METHOD = { [0] = "freeforall", [1] = "roundrobin", [2] = "master", [3] = "group", [4] = "needbeforegreed", [5] = "personalloot" }
local function lootMethod()
    local m
    if GetLootMethod then m = GetLootMethod()
    elseif C_PartyInfo and C_PartyInfo.GetLootMethod then m = C_PartyInfo.GetLootMethod() end
    return METHOD[m] or m
end
local function isRolled(quality)
    if not (IsInGroup and IsInGroup()) then return false end
    local m = lootMethod()
    if m == "freeforall" or m == "personalloot" or m == "personal" then return false end
    local th = GetLootThreshold and GetLootThreshold() or 2
    return (quality or 0) >= (th or 2)
end
M.IsRolled = isRolled

-- Emplacements encore pleins de la fenêtre de butin : total, et ceux que le profil veut.
local function remaining(p)
    local total, wanted, rolled = 0, {}, 0
    for i = 1, (GetNumLootItems() or 0) do
        local _, name, quantity, currencyID, quality, locked, isQuest = GetLootSlotInfo(i)
        local slotType = GetLootSlotType and GetLootSlotType(i) or 1
        local filled = (name and name ~= "") or (quantity and quantity > 0)
        if filled and slotType ~= 0 then
            total = total + 1
            if slotType == 1 and not currencyID and isRolled(quality) then
                rolled = rolled + 1
            elseif not locked then
                if slotType ~= 1 or currencyID then
                    table.insert(wanted, i)
                elseif p and M:Wants(p, WK:ParseItemID(GetLootSlotLink(i)), quality, quantity, isQuest) then
                    table.insert(wanted, i)
                end
            end
        end
    end
    return total, wanted, rolled
end

-- Vérification juste après le passage du filtre : fenêtre vide -> fermée ; objet voulu encore
-- là -> nouvel essai (puis message si les sacs sont pleins) ; plus que des objets laissés -> fermée.
-- Objet « lié quand ramassé » : le jeu attend une confirmation du joueur (LOOT_BIND_CONFIRM) ;
-- on ne conclut pas « sacs pleins » et on ne ferme pas la fenêtre pendant ce temps
local bindPending = false
local function waitingConfirm()
    if bindPending then return true end
    return StaticPopup_Visible and (StaticPopup_Visible("LOOT_BIND") or StaticPopup_Visible("CONFIRM_LOOT_ROLL")) and true or false
end
local function verify(p, attempt)
    if not lootOpen then return end
    if waitingConfirm() then return end
    local total, wanted, rolled = remaining(p)
    if total == 0 then return CloseLoot() end
    -- Maître du butin avec des objets à attribuer : la fenêtre reste ouverte.
    local keepOpen = rolled > 0 and lootMethod() == "master"
    if #wanted > 0 then
        if attempt < 2 then
            for k = #wanted, 1, -1 do LootSlot(wanted[k]) end
            C_Timer.After(0.4, function() verify(p, attempt + 1) end)
        else
            -- Sacs pleins : les objets voulus restent au sol, on les compte aussi.
            for _, i in ipairs(wanted) do
                local slotType = GetLootSlotType and GetLootSlotType(i) or 1
                if slotType == 1 then
                    local _, name, quantity = GetLootSlotInfo(i)
                    recordLeft(WK:ParseItemID(GetLootSlotLink(i)), quantity, name, true)
                end
            end
            WK:NotifyChanged()
            WK:Print(T("Butin : des objets voulus n'ont pas pu être ramassés (sacs pleins ?)."))
            if db().closeAfter and not keepOpen then CloseLoot() end
        end
        return
    end
    if db().closeAfter and not keepOpen then CloseLoot() end
end

local function onLoot()
    local d = db()
    if not d.enabled or handled or not WK:FeatureOn("loot") then return end
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
        if slotType == 1 and not currencyID and isRolled(quality) then
            -- tiré aux dés : le jeu s'en occupe (fenêtre de lancer), rien à compter
        elseif not locked then
            if slotType ~= 1 or currencyID then
                LootSlot(i) -- or et monnaies
            else
                local link = GetLootSlotLink(i)
                local id = WK:ParseItemID(link)
                if M:Wants(p, id, quality, quantity, isQuest) then
                    LootSlot(i)
                else
                    left = left + (quantity or 1)
                    recordLeft(id, quantity, name)
                end
            end
        end
    end
    if left > 0 then WK:NotifyChanged() end
    C_Timer.After(0.3, function() verify(p, 1) end)
end

WK:On("LOOT_READY", onLoot)
WK:On("LOOT_OPENED", function() lootOpen = true; onLoot() end)
WK:On("LOOT_CLOSED", function() handled = false; lootOpen = false; bindPending = false end)
WK:On("LOOT_BIND_CONFIRM", function() bindPending = true end)
WK:On("LOOT_SLOT_CLEARED", function() bindPending = false end)

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
