local ADDON_NAME, WK = ...
local M = WK:NewModule("BagHelp")
local T = function(s) return WK.T(s) end

-- Aides des sacs (idées de Polestar, aucun code repris) :
--   * place dans les sacs : cases libres des sacs ordinaires, objet gris le moins cher à jeter (UI/BagHelp.lua) ;
--   * réassort chez le marchand : boissons, nourriture et objets choisis complétés jusqu'aux quantités voulues
--     par perso, sur un clic (rien n'est acheté sans lui) ; munitions et composants de classe : déjà achetés
--     par QoL (onglets des classes), pas ici ;
--   * amélioration à porter : un objet qui arrive dans les sacs (butin, récompense, achat) et vaut mieux que
--     celui porté (poids des caractéristiques de la classe, UI.StatWeights) est proposé, jamais équipé d'office.
-- Réglages WK.DB.global.bagHelp (dans les profils, sauf dismissed) : space, low (seuil de cases libres),
-- restock, rs[perso] = { drink, food, items = { [objet] = quantité } }, wear, dismissed[perso][objet].
-- Nombre d'un objet dans les sacs : C_Item.GetItemCount sur ce client (avant, le GetItemCount global, absent ici,
-- valait toujours 0 : le Réassort rachetait tout à chaque clic et « Amélioration à porter » ne s'affichait jamais)
local function itemCount(id)
    local f = (_G.C_Item and _G.C_Item.GetItemCount) or _G.GetItemCount
    return (f and id and f(id)) or 0
end
local DEFAULTS = { space = true, low = 3, restock = true, wear = true, autoOpen = false, openMode = "list",
    barBg = true, barSeps = true, buffAlert = true }

function M:Config()
    local g = WK.DB.global
    g.bagHelp = g.bagHelp or {}
    local c = g.bagHelp
    for k, v in pairs(DEFAULTS) do if c[k] == nil then c[k] = v end end
    c.rs = c.rs or {}
    c.dismissed = c.dismissed or {}
    -- sens des listes déroulées de la barre (kit, buffs) : un seul réglage, repris de l'ancien réglage du kit
    if c.dir == nil then
        local camp = g.qol and g.qol.camp
        c.dir = (type(camp) == "table" and camp.kitDir == "up") and "up" or "down"
    end
    return c
end
-- quantités de réassort du perso connecté
function M:Restock()
    local c = self:Config()
    local k = WK:CharKey()
    c.rs[k] = c.rs[k] or { drink = 0, food = 0, items = {} }
    c.rs[k].items = c.rs[k].items or {}
    return c.rs[k]
end

---------------------------------------------------------------------------
-- Place dans les sacs
---------------------------------------------------------------------------
-- cases libres et total des sacs ordinaires (pas les carquois, sacs d'âmes ou de métier)
function M:FreeSlots()
    local free, total = 0, 0
    local Cc = C_Container
    for _, bag in ipairs(WK.modules.Inventory:BagList()) do
        local n, family
        if Cc and Cc.GetContainerNumFreeSlots then n, family = Cc.GetContainerNumFreeSlots(bag)
        elseif GetContainerNumFreeSlots then n, family = GetContainerNumFreeSlots(bag) end
        if (family or 0) == 0 then
            free = free + (n or 0)
            total = total + (WK.Container.NumSlots(bag) or 0)
        end
    end
    return free, total
end
-- objet gris le moins cher des sacs : { bag, slot, price, id } ou nil (jamais un objet verrouillé)
function M:CheapestGrey()
    local best
    for _, it in ipairs(WK.modules.QoL:GreyItems()) do
        if not best or it.price < best.price then best = it end
    end
    if best then best.id = WK.Container.Info(best.bag, best.slot) end
    return best
end
-- jette l'objet gris le moins cher (clic du joueur) ; true si fait
function M:DeleteCheapest()
    if InCombatLockdown and InCombatLockdown() then return false end
    local g = self:CheapestGrey()
    if not (g and DeleteCursorItem) then return false end
    local id = WK.Container.Info(g.bag, g.slot)
    if id ~= g.id then return false end -- la case a changé entre-temps
    local _, link, quality = WK.GetItemInfo(id)
    if quality ~= 0 then return false end
    ClearCursor()
    WK.Container.Pickup(g.bag, g.slot)
    if not (CursorHasItem and CursorHasItem()) then return false end
    DeleteCursorItem()
    WK:Print(string.format(T("Jeté pour faire de la place : %s (%s)"), link or ("#" .. id), WK:FormatMoney(g.price)))
    return true
end

---------------------------------------------------------------------------
-- Réassort
---------------------------------------------------------------------------
local DRINK_WORDS = { "boisson", "boire", "drink" }
local FOOD_WORDS = { "nourriture", "manger", "food", "rafraîchissement", "refreshment" }
local function hasWord(s, words)
    s = (s or ""):lower()
    for _, w in ipairs(words) do if s:find(w, 1, true) then return true end end
    return false
end
-- genre d'un objet : "drink", "food" ou nil (d'après le sort de l'objet : « Boisson », « Nourriture »)
function M:Kind(id)
    if not (id and C_Item and C_Item.GetItemInfoInstant) then return nil end
    local _, _, _, _, _, classID, subID = C_Item.GetItemInfoInstant(id)
    if classID == 0 and subID == 5 then
        local spell = GetItemSpell and GetItemSpell(id)
        if hasWord(spell, DRINK_WORDS) then return "drink" end
        if hasWord(spell, FOOD_WORDS) then return "food" end
    end
    return nil
end
-- nombre en sacs de chaque genre
local function haveByKind()
    local have = { drink = 0, food = 0 }
    for _, bag in ipairs(WK.modules.Inventory:BagList()) do
        for slot = 1, (WK.Container.NumSlots(bag) or 0) do
            local id, count = WK.Container.Info(bag, slot)
            local k = id and M:Kind(id)
            if k then have[k] = have[k] + (count or 1) end
        end
    end
    return have
end
-- Ce que le réassort achèterait ici : { { id, need, stock = { index, price, batch, available }, label } }
function M:RestockPlan(stock)
    local rs = self:Restock()
    local lvl = UnitLevel and UnitLevel("player") or 60
    local plan = {}
    -- genres : le meilleur objet que ce marchand vend pour ton niveau
    local best = {}
    for id, s in pairs(stock or {}) do
        local k = self:Kind(id)
        if k and (rs[k] or 0) > 0 then
            local _, _, _, _, minLvl = WK.GetItemInfo(id)
            minLvl = minLvl or 0
            if minLvl <= lvl then
                local b = best[k]
                if not b or minLvl > b.lvl or (minLvl == b.lvl and s.price > b.stock.price) then best[k] = { id = id, lvl = minLvl, stock = s } end
            end
        end
    end
    local have = haveByKind()
    for _, k in ipairs({ "drink", "food" }) do
        local b = best[k]
        local need = (rs[k] or 0) - (have[k] or 0)
        if b and need > 0 then table.insert(plan, { id = b.id, need = need, stock = b.stock, kind = k }) end
    end
    -- objets choisis
    for id, want in pairs(rs.items) do
        local s = stock and stock[id]
        local need = want - itemCount(id)
        if s and need > 0 then table.insert(plan, { id = id, need = need, stock = s }) end
    end
    return plan
end
-- prix de tout le plan
function M:PlanCost(plan)
    local total = 0
    for _, p in ipairs(plan) do total = total + math.ceil(p.stock.price / math.max(1, p.stock.batch) * p.need) end
    return total
end

---------------------------------------------------------------------------
-- Ouvrir tout seul certains objets des sacs (palourdes…) : réglages autoOpen, openMode (« list » : la liste
-- openList ; « all » : tout ce qui s'ouvre, sauf les coffrets fermés à clé). Un objet à la fois, jamais en combat,
-- en lançant un sort, avec une fenêtre de butin ouverte, sans case libre, ni chez un marchand, à la banque, à la
-- boîte aux lettres, à l'échange ou à l'hôtel des ventes (un clic droit y vendrait, déposerait ou joindrait l'objet)
---------------------------------------------------------------------------
-- palourdes : petite palourde couverte de bernaches, palourde à coquille épaisse, palourde à grande bouche,
-- palourde à coquille molle
M.OPEN_DEFAULT = { [5523] = true, [5524] = true, [7973] = true, [15874] = true }
local BUSY_FRAMES = { "MerchantFrame", "BankFrame", "TradeFrame", "MailFrame", "AuctionFrame", "AuctionHouseFrame",
    "GuildBankFrame", "LootFrame" }
function M:OpenList()
    local c = self:Config()
    if not c.openList then
        c.openList = {}
        for id in pairs(self.OPEN_DEFAULT) do c.openList[id] = true end
    end
    return c.openList
end
local function lockedBox(bag, slot)
    if not (C_TooltipInfo and C_TooltipInfo.GetBagItem) then return false end
    local ok, d = pcall(C_TooltipInfo.GetBagItem, bag, slot)
    local want = _G.LOCKED or "Locked"
    for _, l in ipairs(ok and d and d.lines or {}) do
        if l.leftText == want then return true end
    end
    return false
end
local function lootable(bag, slot)
    local Cn = C_Container
    if Cn and Cn.GetContainerItemInfo then
        local info = Cn.GetContainerItemInfo(bag, slot)
        return info and info.hasLoot or false
    end
    if GetContainerItemInfo then return select(6, GetContainerItemInfo(bag, slot)) and true or false end
    return false
end
-- pourquoi on n'ouvre pas maintenant (nil : on peut)
function M:OpenBusy()
    if InCombatLockdown and InCombatLockdown() then return "combat" end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return "mort" end
    if (UnitCastingInfo and UnitCastingInfo("player")) or (UnitChannelInfo and UnitChannelInfo("player")) then return "sort" end
    -- sort qui attend sa cible (enchantement, pierre à aiguiser…) ou objet sur le curseur : ouvrir une
    -- palourde appliquerait le sort à cet objet, ou le poserait dessus
    if _G.SpellIsTargeting and _G.SpellIsTargeting() then return "ciblage" end
    if _G.CursorHasItem and _G.CursorHasItem() then return "curseur" end
    for _, n in ipairs(BUSY_FRAMES) do
        local f = _G[n]
        if f and f.IsShown and f:IsShown() == true then return n end
    end
    if (self:FreeSlots() or 0) < 1 then return "sacs pleins" end
    return nil
end
-- prochain objet à ouvrir : bag, slot, id
function M:NextToOpen()
    local c = self:Config()
    local list = self:OpenList()
    for _, bag in ipairs(WK.modules.Inventory:BagList()) do
        for slot = 1, (WK.Container.NumSlots(bag) or 0) do
            local id, _, isLocked = WK.Container.Info(bag, slot)
            if id and not isLocked and (list[id] or (c.openMode == "all" and lootable(bag, slot) and not lockedBox(bag, slot))) then
                return bag, slot, id
            end
        end
    end
end
local lastOpen = 0
function M:OpenNext()
    local c = self:Config()
    if not c.autoOpen or not WK:FeatureOn("inventory") then return false end
    if GetTime() - lastOpen < 1 then return false end
    if self:OpenBusy() then return false end
    local bag, slot = self:NextToOpen()
    if not bag then return false end
    lastOpen = GetTime()
    local use = (C_Container and C_Container.UseContainerItem) or UseContainerItem
    if use then pcall(use, bag, slot) end
    return true
end
local openPending
local function openSoon(delay)
    if openPending then return end
    openPending = true
    C_Timer.After(delay or 0.6, function() openPending = nil; M:OpenNext() end)
end
WK:On("BAG_UPDATE_DELAYED", function() openSoon(0.6) end)
WK:On("LOOT_CLOSED", function() openSoon(0.8) end)
WK:On("PLAYER_REGEN_ENABLED", function() openSoon(1.5) end)
for _, ev in ipairs({ "MERCHANT_CLOSED", "BANKFRAME_CLOSED", "MAIL_CLOSED", "TRADE_CLOSED", "AUCTION_HOUSE_CLOSED" }) do
    WK:On(ev, function() openSoon(1) end)
end

---------------------------------------------------------------------------
-- Amélioration à porter
---------------------------------------------------------------------------
local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
    INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
    INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}
M.SLOTS = SLOTS
local STAT_KEYS = {
    ITEM_MOD_STRENGTH_SHORT = "str", ITEM_MOD_AGILITY_SHORT = "agi", ITEM_MOD_STAMINA_SHORT = "sta",
    ITEM_MOD_INTELLECT_SHORT = "int", ITEM_MOD_SPIRIT_SHORT = "spi",
}
local function statsOf(link)
    local f = (C_Item and C_Item.GetItemStats) or GetItemStats
    if not f then return {} end
    local ok, st = pcall(f, link)
    return ok and type(st) == "table" and st or {}
end
-- valeur d'un objet pour la classe : caractéristiques pondérées, puissance, dégâts de l'arme, armure
function M:Score(link, class)
    if not link then return 0 end
    local w = (WK.UI.StatWeights or {})[class or ""] or { str = 0.5, agi = 0.5, sta = 0.6, int = 0.5, spi = 0.3 }
    local st = statsOf(link)
    local s = 0
    for key, v in pairs(st) do
        local k = STAT_KEYS[key]
        if k then s = s + (w[k] or 0) * v end
    end
    local phys = math.max(w.str or 0, w.agi or 0)
    local caster = w.int or 0
    s = s + (st.ITEM_MOD_ATTACK_POWER_SHORT or 0) * phys * 0.5
    s = s + (st.ITEM_MOD_SPELL_POWER_SHORT or st.ITEM_MOD_SPELL_DAMAGE_DONE_SHORT or 0) * caster * 1.2
    s = s + (st.ITEM_MOD_DAMAGE_PER_SECOND_SHORT or 0) * phys * 4
    s = s + (st.RESISTANCE0_NAME or 0) * 0.01
    return s
end
-- Le perso peut-il porter cet objet (classe, armure, niveau requis) ?
local function wearable(id, link)
    local c = WK.DB:Me()
    local D = WK.modules.Dungeons
    if D and D.Usable and D:Usable(id, c) == false then return false end
    local _, _, _, _, minLvl = WK.GetItemInfo(link or id)
    if minLvl and minLvl > (UnitLevel and UnitLevel("player") or 60) then return false end
    return true
end
-- Meilleure place pour cet objet : slot, gain (score nouveau - ancien), lien porté ; nil si pas mieux
function M:Upgrade(link)
    local id = WK:ParseItemID(link)
    if not id then return nil end
    if not (C_Item and C_Item.GetItemInfoInstant) then return nil end
    local _, _, _, loc, _, classID, subClassID = _G.C_Item.GetItemInfoInstant(id)
    local slots = loc and SLOTS[loc]
    if not slots or not wearable(id, link) then return nil end
    -- arme dont la compétence n'est pas apprise : rien à proposer
    local WS = WK.modules.WeaponSkills
    if classID == 2 and WS and WS.Knows and WS:Knows(subClassID) == false then return nil end
    -- arme de main gauche : seulement pour qui sait se battre à deux armes
    if loc == "INVTYPE_WEAPONOFFHAND" and _G.CanDualWield and not _G.CanDualWield() then return nil end
    -- main gauche (arme, bouclier, objet tenu) avec une arme à deux mains en main : l'équiper retire l'arme à
    -- deux mains ; comparée à elle (avant, la main gauche vide comptait pour 0 et tout semblait un gain)
    local invLink = _G.GetInventoryItemLink
    local mainLink = invLink and invLink("player", 16)
    local mainLoc = mainLink and select(4, _G.C_Item.GetItemInfoInstant(mainLink))
    local offWithTwoHand = mainLoc == "INVTYPE_2HWEAPON" and (slots[1] == 17)
    local class = select(2, UnitClass("player"))
    local new = self:Score(link, class)
    if new <= 0 then return nil end
    local bestSlot, bestOld, oldLink
    for _, slot in ipairs(slots) do
        local cur = GetInventoryItemLink and GetInventoryItemLink("player", slot)
        local old = self:Score(cur, class)
        -- arme à deux mains : comparée à l'arme et à la main gauche ensemble
        if loc == "INVTYPE_2HWEAPON" then old = old + self:Score(GetInventoryItemLink and GetInventoryItemLink("player", 17), class) end
        if offWithTwoHand and slot == 17 then old = old + self:Score(mainLink, class) end
        if not bestOld or old < bestOld then bestSlot, bestOld, oldLink = slot, old, cur end
    end
    if bestOld and new > bestOld * 1.05 + 0.5 then return bestSlot, new - bestOld, oldLink, new, bestOld end
    return nil
end
function M:Dismiss(id)
    local d = self:Config().dismissed
    local k = WK:CharKey()
    d[k] = d[k] or {}
    d[k][id] = true
end
function M:Dismissed(id)
    local d = self:Config().dismissed[WK:CharKey()]
    return d and d[id] or false
end
-- objets arrivés dans les sacs depuis le dernier relevé : nouveaux exemplaires d'objets portables
local counts
local function bagCounts()
    local out, links = {}, {}
    for _, bag in ipairs(WK.modules.Inventory:BagList()) do
        for slot = 1, (WK.Container.NumSlots(bag) or 0) do
            local id, count = WK.Container.Info(bag, slot)
            if id then
                out[id] = (out[id] or 0) + (count or 1)
                local link = C_Container and C_Container.GetContainerItemLink and C_Container.GetContainerItemLink(bag, slot)
                    or (GetContainerItemLink and GetContainerItemLink(bag, slot))
                links[id] = links[id] or link
            end
        end
    end
    return out, links
end
M.queue = {}
function M:CheckNewItems()
    local now, links = bagCounts()
    if not counts then counts = now return end
    if self:Config().wear then
        for id, n in pairs(now) do
            if n > (counts[id] or 0) and links[id] and not self:Dismissed(id) then
                local slot, gain, old = self:Upgrade(links[id])
                if slot then
                    local dup = false
                    for _, q in ipairs(self.queue) do if q.id == id then dup = true end end
                    if not dup then table.insert(self.queue, { id = id, link = links[id], slot = slot, gain = gain, old = old }) end
                end
            end
        end
    end
    counts = now
    if WK.UI.RefreshWearOffer then WK.UI:RefreshWearOffer() end
end
-- proposition en tête de file encore valable (objet toujours en sac et toujours meilleur)
function M:Offer()
    while #self.queue > 0 do
        local q = self.queue[1]
        local have = itemCount(q.id)
        local slot, gain, old
        if have > 0 and not self:Dismissed(q.id) then slot, gain, old = self:Upgrade(q.link) end
        if slot then q.slot, q.gain, q.old = slot, gain, old return q end
        table.remove(self.queue, 1)
    end
    return nil
end
function M:Wear(q)
    if not q or (InCombatLockdown and InCombatLockdown()) then return false end
    local ok = WK.EquipItem(q.link, q.slot)
    table.remove(self.queue, 1)
    return ok
end
function M:Skip(q)
    if q then self:Dismiss(q.id) end
    table.remove(self.queue, 1)
end

local pending
WK:On("BAG_UPDATE_DELAYED", function()
    if pending then return end
    pending = true
    C_Timer.After(0.5, function()
        pending = nil
        M:CheckNewItems()
        if WK.UI.RefreshBagSpace then WK.UI:RefreshBagSpace() end
    end)
end)
WK:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(3, function() M:CheckNewItems(); if WK.UI.RefreshBagSpace then WK.UI:RefreshBagSpace() end end) end)
WK:On("PLAYER_REGEN_ENABLED", function() if WK.UI.RefreshWearOffer then WK.UI:RefreshWearOffer() end end)
