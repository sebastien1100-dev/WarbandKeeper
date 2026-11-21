local ADDON_NAME, WK = ...
local M = WK:NewModule("QoL")
local T = function(s) return WK.T(s) end

-- WoW Forever peut masquer des valeurs en combat (« secret values ») : une valeur masquée est
-- traitée comme inconnue.
local function readable(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end
M.Readable = readable

-- Qualité de vie : petites automatisations générales (marchand, groupe, confort) et aides
-- propres à chaque classe (composants, munitions, familier, poisons, totems…).
-- Réglages : WK.DB.global.qol = { general = {...}, classes = { [CLASSE] = {...} } }

---------------------------------------------------------------------------
-- Données
---------------------------------------------------------------------------
M.CLASSES = {
    { "WARRIOR", "Guerrier" }, { "PALADIN", "Paladin" }, { "HUNTER", "Chasseur" },
    { "ROGUE", "Voleur" }, { "PRIEST", "Prêtre" }, { "SHAMAN", "Chaman" },
    { "MAGE", "Mage" }, { "WARLOCK", "Démoniste" }, { "DRUID", "Druide" },
}
M.CLASS_LABEL = {}
for _, c in ipairs(M.CLASSES) do M.CLASS_LABEL[c[1]] = c[2] end

-- Composants par classe. key : clé des réglages ; id ou ids (groupe d'objets comptés ensemble) ;
-- lvl / maxLvl : niveaux où le composant sert ; min : alerte en dessous ; buy : achat auto jusqu'à
-- (nil = ne s'achète pas) ; label : nom affiché si le jeu n'a pas encore le nom de l'objet.
M.REAGENTS = {
    MAGE = {
        { key = "17020", id = 17020, lvl = 56, min = 20, buy = 40, label = "Poudre des arcanes" },
        { key = "17031", id = 17031, lvl = 20, min = 2, buy = 10, label = "Rune de téléportation" },
        { key = "17032", id = 17032, lvl = 40, min = 2, buy = 10, label = "Rune des portails" },
        { key = "17056", id = 17056, lvl = 12, min = 0, buy = 20, label = "Plume légère" },
        { key = "water", ids = { 5350, 2288, 2136, 3772, 8077, 8078, 8079 }, lvl = 4, min = 0, label = "Eau invoquée", conjured = true },
        { key = "food", ids = { 5349, 1113, 1114, 1487, 8075, 8076, 22895 }, lvl = 6, min = 0, label = "Nourriture invoquée", conjured = true },
    },
    PRIEST = {
        { key = "17028", id = 17028, lvl = 48, maxLvl = 59, min = 5, buy = 20, label = "Bougie sacrée" },
        { key = "17029", id = 17029, lvl = 60, min = 5, buy = 20, label = "Chandelle sacrée" },
        { key = "17056", id = 17056, lvl = 34, min = 0, buy = 10, label = "Plume légère" },
    },
    PALADIN = {
        { key = "21177", id = 21177, lvl = 52, min = 20, buy = 100, label = "Symbole des rois" },
        { key = "17033", id = 17033, lvl = 30, min = 0, buy = 5, label = "Symbole de divinité" },
    },
    SHAMAN = {
        { key = "17030", id = 17030, lvl = 30, min = 1, buy = 5, label = "Ankh" },
        { key = "5175", id = 5175, lvl = 4, min = 1, buy = 1, label = "Totem de terre", totem = true },
        { key = "5176", id = 5176, lvl = 10, min = 1, buy = 1, label = "Totem de feu", totem = true },
        { key = "5177", id = 5177, lvl = 20, min = 1, buy = 1, label = "Totem d'eau", totem = true },
        { key = "5178", id = 5178, lvl = 30, min = 1, buy = 1, label = "Totem d'air", totem = true },
    },
    DRUID = {
        { key = "17034", id = 17034, lvl = 20, maxLvl = 29, min = 1, buy = 5, label = "Graine d'érable" },
        { key = "17035", id = 17035, lvl = 30, maxLvl = 39, min = 1, buy = 5, label = "Graine de Strangleronce" },
        { key = "17036", id = 17036, lvl = 40, maxLvl = 49, min = 1, buy = 5, label = "Graine de frêne" },
        { key = "17037", id = 17037, lvl = 50, maxLvl = 59, min = 1, buy = 5, label = "Graine de charme" },
        { key = "17038", id = 17038, lvl = 60, min = 1, buy = 5, label = "Graine de bois de fer" },
        { key = "17021", id = 17021, lvl = 50, maxLvl = 59, min = 0, buy = 20, label = "Baies sauvages" },
        { key = "17026", id = 17026, lvl = 60, min = 0, buy = 20, label = "Racine épineuse sauvage" },
    },
    ROGUE = {
        { key = "poisons", ids = { 6947, 6949, 6950, 8926, 8927, 8928, 2892, 2893, 8984, 8985, 20844,
            3775, 3776, 5237, 6951, 9186, 10918, 10920, 10921, 10922 }, lvl = 20, min = 5, buy = 20, label = "Poisons" },
        { key = "5140", id = 5140, lvl = 22, min = 2, buy = 20, label = "Poudre éclipsante" },
        { key = "5060", id = 5060, lvl = 16, min = 0, buy = 1, label = "Outils de voleur" },
    },
    WARLOCK = {
        { key = "6265", id = 6265, lvl = 10, min = 5, label = "Fragment d'âme" },
        { key = "healthstone", ids = { 5512, 19004, 19005, 5511, 19006, 19007, 5509, 19008, 19009, 5510, 19010, 19011,
            9421, 19012, 19013 }, lvl = 10, min = 1, label = "Pierre de soins", conjured = true },
        { key = "soulstone", ids = { 5232, 16892, 16893, 16895, 16896 }, lvl = 18, min = 0, label = "Pierre d'âme", conjured = true },
    },
}

-- Classes qui tirent avec des munitions (arc, fusil, arbalète).
M.AMMO = { HUNTER = true, WARRIOR = true, ROGUE = true }

-- Coffres à crocheter : compétence de Crochetage demandée.
M.LOCKBOXES = {
    [4632] = 1, [4633] = 25, [4634] = 70, [4636] = 125, [4637] = 175, [4638] = 225,
    [5758] = 225, [5759] = 225, [5760] = 225,
    [16882] = 1, [16883] = 70, [16884] = 175, [16885] = 250,
}

-- Villes des portails de mage, par faction.
M.PORTALS = {
    Alliance = { "Hurlevent", "Forgefer", "Darnassus" },
    Horde = { "Orgrimmar", "Fossoyeuse", "Les Pitons-du-Tonnerre" },
}

local SPELL_FEED_PET = 6991
local SPELL_REINCARNATION = 20608
local FORTITUDE = { 1243, 21562 }      -- Mot de pouvoir : Robustesse, Prière de robustesse
local MARK_OF_WILD = { 1126, 21849 }   -- Marque du fauve, Don du fauve
local FEED_MACRO = "WK Nourrir"

---------------------------------------------------------------------------
-- Réglages
---------------------------------------------------------------------------
local GENERAL_DEFAULTS = {
    repair = true, repairCap = 0, repairGuild = false, sellGrey = true, closeAfterRepair = true,
    durability = 30, freeSlots = 4,
    acceptInvites = false, declineDuels = false, duelFriends = true,
    releaseBG = false, confirmBoP = false, dismount = true, skipCinematics = false,
}
local CLASS_DEFAULTS = {
    alerts = true,
    ammo = { min = 400, buy = 2000, auto = false, minMinutes = 0 },
    -- Chasseur
    petAlert = true, petButton = true,
    remAspect = true, remCheetah = true, remGrowl = true, remTrack = false,
    -- Voleur
    poisonAlert = true, poisonMin = 5,
    -- Démoniste
    shardMax = 20,
    -- Prêtre, Paladin, Druide : rappels de buffs
    buffReminder = true,
    -- Druide, Prêtre, Mage, Paladin : bouton « Buffer le suivant » (UI/BuffButton.lua)
    buffAround = true, kingsFirst = true, buffRefresh = 3, buffInstance = false, buffMounted = false, buffPlates = true,
    -- Mage
    portalText = "Portail vers %s, chuchote-moi !",
}

-- Appelé très souvent (plusieurs fois par image par les cadres animés) : les valeurs par défaut ne sont
-- posées qu'une fois par table (un profil chargé en pose une nouvelle, contrôlée à son tour).
local ready
function M:Config()
    local q = WK.DB.global.qol
    if q and q == ready and q.general and q.classes and q.petFoods then return q end
    if not q then q = {}; WK.DB.global.qol = q end
    q.general = q.general or {}
    for k, v in pairs(GENERAL_DEFAULTS) do if q.general[k] == nil then q.general[k] = v end end
    q.classes = q.classes or {}
    q.petFoods = q.petFoods or {}
    for _, cl in ipairs(M.CLASSES) do
        local c = q.classes[cl[1]] or {}
        q.classes[cl[1]] = c
        for k, v in pairs(CLASS_DEFAULTS) do
            if c[k] == nil then c[k] = type(v) == "table" and { min = v.min, buy = v.buy, auto = v.auto, minMinutes = v.minMinutes } or v end
        end
        c.reag = c.reag or {}
        for _, r in ipairs(M.REAGENTS[cl[1]] or {}) do
            local s = c.reag[r.key] or {}
            c.reag[r.key] = s
            if s.min == nil then s.min = r.min end
            if s.buy == nil then s.buy = r.buy end
            if s.auto == nil then s.auto = false end
        end
        c.sets = c.sets or {}
    end
    ready = q
    return q
end
function M:General() return self:Config().general end
function M:Class(class) return self:Config().classes[class] end

---------------------------------------------------------------------------
-- Comptages
---------------------------------------------------------------------------
function M:ReagentName(r)
    local id = r.id or (r.ids and r.ids[1])
    if r.id then
        local n = WK.GetItemInfo(r.id)
        if n then return n end
    end
    return T(r.label)
end

-- Quantité d'un composant dans les sacs d'un perso.
function M:Count(c, r)
    local bags = c.bags or {}
    if r.id then return bags[r.id] or 0 end
    local n = 0
    for _, id in ipairs(r.ids or {}) do n = n + (bags[id] or 0) end
    return n
end

function M:Relevant(r, level)
    level = level or 0
    return level >= (r.lvl or 1) and level <= (r.maxLvl or 999)
end

-- Persos d'une classe : { { key, c }, ... } (perso connecté d'abord).
function M:CharsOf(class)
    local list = {}
    for _, e in ipairs(WK.UI and WK.UI.SortedCharacters and WK.UI:SortedCharacters() or {}) do
        if e.c.class == class then table.insert(list, e) end
    end
    return list
end

function M:PlayedClasses()
    local set, n = {}, 0
    for _, c in pairs(WK.DB.global.characters) do
        if c.class and M.CLASS_LABEL[c.class] and not set[c.class] then set[c.class] = true; n = n + 1 end
    end
    return set, n
end

---------------------------------------------------------------------------
-- Alertes (pour « À faire », l'en-tête et les fiches)
-- { key = clé du perso, c, kind = "reagent"|"ammo"|"durability"|"bags"|"pet"|"poison", text, class, urgent }
---------------------------------------------------------------------------
function M:Alerts()
    local out = {}
    local q = self:Config()
    local g = q.general
    local me = WK:CharKey()
    local now = time()
    for key, c in pairs(WK.DB.global.characters) do
        local name = WK:CharName(c, key)
        local cc = c.class and q.classes[c.class]
        -- Durabilité
        if (g.durability or 0) > 0 and c.durability and c.durability < g.durability then
            table.insert(out, { key = key, c = c, kind = "durability", urgent = c.durability < 10,
                text = string.format(T("%s : équipement à %d %%, à réparer"), name, c.durability) })
        end
        -- Sacs presque pleins
        if (g.freeSlots or 0) > 0 and c.freeSlots and (c.totalSlots or 0) > 0 and c.freeSlots < g.freeSlots then
            table.insert(out, { key = key, c = c, kind = "bags", urgent = c.freeSlots == 0,
                text = c.freeSlots == 0 and string.format(T("%s : sacs pleins"), name)
                    or string.format(c.freeSlots > 1 and T("%s : plus que %d places dans les sacs") or T("%s : plus que %d place dans les sacs"), name, c.freeSlots) })
        end
        -- Banque presque pleine (relevée à la dernière visite)
        if (g.freeSlots or 0) > 0 and c.bankFree and (c.bankSlots or 0) > 0 and c.bankFree < g.freeSlots then
            table.insert(out, { key = key, c = c, kind = "bags", bank = true,
                text = c.bankFree == 0 and string.format(T("%s : banque pleine"), name)
                    or string.format(c.bankFree > 1 and T("%s : plus que %d places en banque") or T("%s : plus que %d place en banque"), name, c.bankFree) })
        end
        if cc and cc.alerts then
            -- Composants
            for _, r in ipairs(M.REAGENTS[c.class] or {}) do
                local s = cc.reag[r.key]
                if s and (s.min or 0) > 0 and M:Relevant(r, c.level) then
                    local n = M:Count(c, r)
                    if n < s.min then
                        table.insert(out, { key = key, c = c, kind = "reagent", class = c.class, urgent = n == 0, reagent = r,
                            text = n == 0 and string.format(T("%s : %s, il n'en reste plus"), name, M:ReagentName(r))
                                or string.format(T("%s : %s bas (%d)"), name, M:ReagentName(r), n) })
                    end
                end
            end
            -- Munitions
            -- Seuil en nombre, ou en minutes de tir (d'après la vitesse de tir du perso)
            if M.AMMO[c.class] and c.ammo and c.ammo.id then
                local n = c.ammo.n or 0
                local mins = c.ammo.speed and (n * c.ammo.speed / 60) or nil
                local low = ((cc.ammo.min or 0) > 0 and n < cc.ammo.min)
                    or ((cc.ammo.minMinutes or 0) > 0 and mins ~= nil and mins < cc.ammo.minMinutes)
                if low then
                    local txt = mins and (mins >= 1 and string.format(T("%s : munitions basses (%d, env. %d min de tir)"), name, n, math.floor(mins))
                        or string.format(T("%s : munitions basses (%d, moins d'une minute de tir)"), name, n))
                        or string.format(T("%s : munitions basses (%d)"), name, n)
                    table.insert(out, { key = key, c = c, kind = "ammo", class = c.class, urgent = n == 0 or (mins ~= nil and mins < 1), text = txt })
                end
            end
            -- Familier pas heureux (perso connecté seulement : l'état change vite)
            if c.class == "HUNTER" and key == me and cc.petAlert and c.pet and c.pet.happy and c.pet.happy < 3
                and now - (c.pet.t or 0) < 600 then
                table.insert(out, { key = key, c = c, kind = "pet", class = c.class, urgent = c.pet.happy == 1,
                    text = string.format(c.pet.happy == 1 and T("%s : %s est mécontent, nourris-le") or T("%s : %s n'est plus heureux"),
                        name, c.pet.name or T("le familier")) })
            end
        end
    end
    -- consommables sous le seuil (Modules/ProfHelp.lua, carte « Avant de partir »)
    if WK.modules.ProfHelp then WK.modules.ProfHelp:AddAlerts(out) end
    table.sort(out, function(a, b)
        if (a.urgent and 1 or 0) ~= (b.urgent and 1 or 0) then return a.urgent end
        return a.text < b.text
    end)
    return out
end

function M:AlertsFor(filter)
    local n, list = 0, {}
    for _, a in ipairs(self:Alerts()) do
        if filter(a) then n = n + 1; table.insert(list, a) end
    end
    return n, list
end

---------------------------------------------------------------------------
-- Rappels : retirés à la demande du joueur (pile, pastilles, messages éclair, texte rouge).
-- Remind / ClearRemind restent pour les modules qui les appellent, sans rien afficher ;
-- ce qui compte (envie tombée, alerte de prix…) passe toujours par le chat de ces modules.
---------------------------------------------------------------------------
function M:Remind() end
function M:ClearRemind() end

---------------------------------------------------------------------------
-- Relevés sur le perso connecté
---------------------------------------------------------------------------
function M:ScanDurability()
    if not GetInventoryItemDurability then return end
    local c = WK.DB:Me()
    local low, any = 100, false
    for slot = 1, 18 do
        local cur, max = GetInventoryItemDurability(slot)
        if cur and max and max > 0 then
            any = true
            low = math.min(low, math.floor(cur / max * 100 + 0.5))
        end
    end
    c.durability = any and low or nil
    WK:NotifyChanged()
end

-- Classe du perso connecté, lue au jeu : à la connexion, Characters n'a pas forcément encore noté c.class
local function myClass() return UnitClass and select(2, UnitClass("player")) or WK.DB:Me().class end

function M:ScanAmmo()
    local c = WK.DB:Me()
    if not M.AMMO[myClass() or ""] or not GetInventoryItemID then return end
    local id = GetInventoryItemID("player", 0)
    if id then
        -- Vitesse de tir (secondes entre deux tirs) : pour estimer les minutes de tir restantes.
        local speed = UnitRangedDamage and readable((UnitRangedDamage("player")))
        c.ammo = { id = id, n = GetInventoryItemCount and GetInventoryItemCount("player", 0) or 0,
                   speed = (speed and speed > 0) and speed or (c.ammo and c.ammo.speed) }
    else
        c.ammo = nil
    end
end

-- WoW Forever range les fonctions du familier dans C_PetInfo.
function M:PetHappiness()
    local h
    if C_PetInfo and C_PetInfo.GetPetHappiness then h = C_PetInfo.GetPetHappiness()
    elseif GetPetHappiness then h = GetPetHappiness() end
    return readable(h)
end
-- Régime du familier : { "Viande", "Poisson", ... } (vide si inconnu).
function M:PetDiet()
    local out = {}
    if C_PetInfo and C_PetInfo.GetPetFoodTypes then
        local list = C_PetInfo.GetPetFoodTypes()
        if type(list) == "table" then for _, v in ipairs(list) do table.insert(out, v) end end
    elseif GetPetFoodTypes then
        for _, v in ipairs({ GetPetFoodTypes() }) do
            for name in tostring(v):gmatch("[^,]+") do table.insert(out, (name:gsub("^%s+", ""):gsub("%s+$", ""))) end
        end
    end
    return out
end
-- true / false si le jeu sait dire si le familier mange cet objet, nil sinon.
function M:CanPetEat(itemID)
    if C_PetInfo and C_PetInfo.CanPetEatItem then
        local ok, res = pcall(C_PetInfo.CanPetEatItem, itemID)
        if ok then return readable(res) end
    end
    return nil
end

function M:ScanPet()
    local c = WK.DB:Me()
    if myClass() ~= "HUNTER" then return end
    local hasPet = UnitExists and UnitExists("pet")
    local happy = hasPet and self:PetHappiness()
    if hasPet and happy then
        local old = c.pet and c.pet.happy
        c.pet = { happy = happy, name = UnitName("pet"), family = UnitCreatureFamily and UnitCreatureFamily("pet"),
                  diet = self:PetDiet(), t = time() }
        local cc = M:Class("HUNTER")
        if cc.petAlert and happy and old and happy < old and happy < 3 then
            M:Remind("pet", string.format(happy == 1 and T("%s est mécontent : nourris-le") or T("%s n'est plus heureux"), c.pet.name or T("Le familier")),
                nil, nil, nil, nil, { action = M:FeedAction() })
        end
        if happy >= 3 then M:ClearRemind("pet") end
    elseif not hasPet then
        c.pet = nil
        M:ClearRemind("pet")
    end
    WK:NotifyChanged()
end

function M:ScanLockpicking()
    local c = WK.DB:Me()
    if myClass() ~= "ROGUE" or not GetNumSkillLines then return end
    for i = 1, GetNumSkillLines() do
        local name, header, _, rank = GetSkillLineInfo(i)
        if not header and name then
            local l = string.lower(name)
            if string.find(l, "crochetage", 1, true) or string.find(l, "lockpicking", 1, true) then
                c.lockpick = rank
                return
            end
        end
    end
end

function M:ScanReincarnation()
    local c = WK.DB:Me()
    if myClass() ~= "SHAMAN" then return end
    local start, duration = WK.SpellCooldown(SPELL_REINCARNATION)
    if start and duration and duration > 1.5 then
        c.reincarnation = time() + math.floor(start + duration - GetTime())
    elseif start then
        c.reincarnation = 0
    end
end

---------------------------------------------------------------------------
-- Marchand : réparation, vente des objets gris, achat des composants
---------------------------------------------------------------------------
local merchantOpen = false
-- Bilan du passage chez le marchand, écrit en une seule ligne.
local shopLog = {}
local function shopNote(text) table.insert(shopLog, text) end
local function shopFlush()
    if #shopLog > 0 then WK:Print(T("Marchand : ") .. table.concat(shopLog, " · ")) end
    wipe(shopLog)
end

function M:Repair()
    local g = self:General()
    if not g.repair or not CanMerchantRepair or not CanMerchantRepair() then return end
    local cost, can = GetRepairAllCost()
    if not cost or cost <= 0 or can == false then return end
    if (g.repairCap or 0) > 0 and cost > g.repairCap * 10000 then
        WK:Print(string.format(T("Réparation non faite : %s dépasse le plafond (Options QoL)."), WK:FormatMoney(cost)))
        return
    end
    if g.repairGuild and CanGuildBankRepair and CanGuildBankRepair() then
        RepairAllItems(true)
        shopNote(string.format(T("réparé (or de guilde) %s"), WK:FormatMoney(cost)))
        C_Timer.After(0.5, function() M:ScanDurability() end)
        return true
    end
    if cost > GetMoney() then return end
    RepairAllItems()
    shopNote(string.format(T("réparé %s"), WK:FormatMoney(cost)))
    C_Timer.After(0.5, function() M:ScanDurability() end)
    return true, cost
end

local function useContainerItem(bag, slot)
    if C_Container and C_Container.UseContainerItem then return C_Container.UseContainerItem(bag, slot) end
    if UseContainerItem then return UseContainerItem(bag, slot) end
end

-- Objets gris vendables des sacs : { {bag, slot, price} }.
function M:GreyItems()
    local list = {}
    for _, bag in ipairs(WK.modules.Inventory:BagList()) do
        for slot = 1, (WK.Container.NumSlots(bag) or 0) do
            local id, count, locked = WK.Container.Info(bag, slot)
            if id and not locked and not (WK.modules.ItemLock and WK.modules.ItemLock:IsLocked(id)) then
                local _, _, quality, _, _, _, _, _, _, _, price = WK.GetItemInfo(id)
                if quality == 0 and (price or 0) > 0 then
                    table.insert(list, { bag = bag, slot = slot, price = price * (count or 1) })
                end
            end
        end
    end
    return list
end

-- onDone() est appelé quand la vente est finie (tout de suite s'il n'y a rien à vendre).
function M:SellGrey(onDone)
    onDone = onDone or function() end
    if not self:General().sellGrey then return onDone() end
    local list = self:GreyItems()
    if #list == 0 then return onDone() end
    local total = 0
    for _, it in ipairs(list) do total = total + it.price end
    -- Par paquets : le serveur n'aime pas cent ventes dans la même image.
    local i = 0
    local function step()
        if not merchantOpen then return end
        for _ = 1, 10 do
            i = i + 1
            local it = list[i]
            if not it then
                shopNote(string.format(T("gris vendus %s"), WK:FormatMoney(total)))
                return onDone()
            end
            useContainerItem(it.bag, it.slot)
        end
        C_Timer.After(0.2, step)
    end
    step()
end

local function merchantIndex(ids)
    if not GetMerchantNumItems then return nil end
    local want = {}
    for _, id in ipairs(ids) do want[id] = true end
    local found
    for i = 1, GetMerchantNumItems() do
        local id = GetMerchantItemID and GetMerchantItemID(i) or WK:ParseItemID(GetMerchantItemLink and GetMerchantItemLink(i))
        if id and want[id] then
            -- On préfère le dernier de la liste (rang le plus élevé chez les poisons) sauf objet déjà en sac.
            local inBags = (WK.DB:Me().bags or {})[id] or 0
            if not found or inBags >= found.inBags then found = { index = i, id = id, inBags = inBags } end
        end
    end
    return found
end

-- Achète `need` unités de l'objet au rang `index` (par lots si le marchand vend par paquets).
-- GetMoney() ne baisse pas dans la même image : `budget.left` (argent restant) est décompté à chaque achat.
local function buy(index, need, budget)
    local _, _, price, batch, available = WK.MerchantItemInfo(index)
    batch = math.max(1, batch or 1)
    price = price or 0
    if available and available >= 0 and available == 0 then return 0 end
    budget = budget or { left = GetMoney() }
    local bought = 0
    if batch > 1 then
        local clicks = math.ceil(need / batch)
        for _ = 1, math.min(clicks, 40) do
            if price > budget.left then break end
            BuyMerchantItem(index)
            budget.left = budget.left - price
            bought = bought + batch
        end
    else
        local maxStack = math.max(1, tonumber(GetMerchantItemMaxStack and GetMerchantItemMaxStack(index)) or 20)
        local left = need
        while left > 0 do
            local n = math.min(left, maxStack)
            if price * n > budget.left then break end
            BuyMerchantItem(index, n)
            budget.left = budget.left - price * n
            bought, left = bought + n, left - n
        end
    end
    return bought
end

-- Munitions : arc et arbalète tirent des flèches, fusil des balles (classe d'objet 6 « Projectile »).
local function itemClass(id)
    local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not f or not id then return nil end
    local _, _, _, _, _, classID, subID = f(id)
    return classID, subID
end
function M:AmmoKind()
    local weapon = GetInventoryItemID and GetInventoryItemID("player", 18)
    local cls, sub = itemClass(weapon)
    if cls ~= 2 then return nil end
    if sub == 3 then return 3 end                 -- fusil : balles
    if sub == 2 or sub == 18 then return 2 end    -- arc, arbalète : flèches
    return nil
end

-- La meilleure munition que ce marchand vend pour l'arme du perso et à son niveau :
-- { index, id }, ou nil. À qualité égale, celle déjà équipée.
function M:BestMerchantAmmo(c)
    local want = self:AmmoKind()
    if not want or not GetMerchantNumItems then return nil end
    local level = c.level or (UnitLevel and UnitLevel("player")) or 1
    local best
    for i = 1, GetMerchantNumItems() do
        local id = GetMerchantItemID and GetMerchantItemID(i) or WK:ParseItemID(GetMerchantItemLink and GetMerchantItemLink(i))
        local cls, sub = itemClass(id)
        if cls == 6 and sub == want then
            local _, _, _, ilvl, minLevel = WK.GetItemInfo(id)
            local _, _, _, _, available = WK.MerchantItemInfo(i)
            if (minLevel or 0) <= level and available ~= 0 then
                local score = (ilvl or 0) + ((c.ammo and c.ammo.id == id) and 0.5 or 0)
                if not best or score > best.score then best = { index = i, id = id, score = score } end
            end
        end
    end
    return best
end

function M:AutoBuy(spent)
    local c = WK.DB:Me()
    local cc = c.class and self:Class(c.class)
    if not cc then return end
    local bought = {}
    -- argent restant, décompté à chaque achat (GetMoney ne compte pas encore la réparation de cette image)
    local budget = { left = math.max(0, GetMoney() - (spent or 0)) }
    for _, r in ipairs(M.REAGENTS[c.class] or {}) do
        local s = cc.reag[r.key]
        if s and s.auto and r.buy and (s.buy or 0) > 0 and M:Relevant(r, c.level) then
            local need = s.buy - M:Count(c, r)
            if need > 0 then
                local m = merchantIndex(r.ids or { r.id })
                if m then
                    local n = buy(m.index, need, budget)
                    if n > 0 then table.insert(bought, n .. " " .. (WK.GetItemInfo(m.id) or M:ReagentName(r))) end
                end
            end
        end
    end
    if M.AMMO[c.class] and cc.ammo.auto then
        local best = M:BestMerchantAmmo(c)
        if best then
            local have = (c.bags or {})[best.id] or 0
            local need = (cc.ammo.buy or 0) - have
            if need > 0 then
                local n = buy(best.index, need, budget)
                if n > 0 then
                    table.insert(bought, n .. " " .. (WK.GetItemInfo(best.id) or T("munitions")))
                    -- Meilleure que celle équipée : on l'équipe (hors combat).
                    if best.id ~= (c.ammo and c.ammo.id) then
                        C_Timer.After(0.8, function()
                            if not (InCombatLockdown and InCombatLockdown()) then WK.EquipItem(best.id) end
                        end)
                    end
                end
            end
        end
    end
    if #bought > 0 then shopNote(T("acheté ") .. table.concat(bought, ", ")) end
end

-- Fermer la fenêtre après une réparation (réglage) ; Maj enfoncée à l'ouverture : elle reste ouverte.
WK:On("MERCHANT_SHOW", function()
    merchantOpen = true
    local keepOpen = IsShiftKeyDown and IsShiftKeyDown()
    C_Timer.After(0.2, function()
        if not merchantOpen then return end
        local repaired, spent = M:Repair()
        M:AutoBuy(spent)
        M:SellGrey(function()
            shopFlush()
            if repaired and M:General().closeAfterRepair and not keepOpen then
                C_Timer.After(0.5, function()
                    -- rien ne se ferme s'il y a quelque chose à acheter ici (réassort, objets de quête, métiers)
                    local offers = WK.UI.MerchantHasOffers and WK.UI.MerchantHasOffers()
                    if merchantOpen and CloseMerchant and not offers then CloseMerchant() end
                end)
            end
        end)
    end)
end)
WK:On("MERCHANT_CLOSED", function() merchantOpen = false end)

---------------------------------------------------------------------------
-- Groupe, duels, confort
---------------------------------------------------------------------------
local function sameName(a, b)
    if not a or not b then return false end
    a, b = string.lower(a), string.lower(b)
    return a == b or string.gsub(a, "%-.*$", "") == string.gsub(b, "%-.*$", "")
end

function M:IsFriendOrGuild(name)
    if C_FriendList and C_FriendList.GetNumFriends then
        for i = 1, C_FriendList.GetNumFriends() do
            local info = C_FriendList.GetFriendInfoByIndex(i)
            if info and sameName(info.name, name) then return true end
        end
    elseif GetNumFriends then
        for i = 1, GetNumFriends() do if sameName((GetFriendInfo(i)), name) then return true end end
    end
    if IsInGuild and IsInGuild() and GetNumGuildMembers then
        for i = 1, GetNumGuildMembers() do
            if sameName((GetGuildRosterInfo(i)), name) then return true end
        end
    end
    return false
end

local function hidePopup(which)
    if StaticPopup_Hide then C_Timer.After(0, function() StaticPopup_Hide(which) end) end
end

WK:On("PARTY_INVITE_REQUEST", function(name)
    if not M:General().acceptInvites or not M:IsFriendOrGuild(name) then return end
    if AcceptGroup then AcceptGroup() end
    hidePopup("PARTY_INVITE")
end)

WK:On("DUEL_REQUESTED", function(name)
    local g = M:General()
    if not g.declineDuels then return end
    if g.duelFriends and M:IsFriendOrGuild(name) then return end
    if CancelDuel then CancelDuel() end
    hidePopup("DUEL_REQUESTED")
end)

WK:On("PLAYER_DEAD", function()
    if not M:General().releaseBG then return end
    local _, kind = IsInInstance()
    if kind ~= "pvp" then return end
    if HasSoulstone and HasSoulstone() then return end
    C_Timer.After(0.5, function() if RepopMe then RepopMe() end end)
end)

WK:On("LOOT_BIND_CONFIRM", function(slot)
    if not M:General().confirmBoP or (IsInGroup and IsInGroup()) then return end
    if ConfirmLootSlot then ConfirmLootSlot(slot) end
    hidePopup("LOOT_BIND")
end)

-- Messages d'erreur du jeu qui demandent de descendre de monture ou de se lever.
local function errorMatches(msg, names)
    for _, n in ipairs(names) do
        local s = _G[n]
        if s and msg == s then return true end
    end
    return false
end
local MOUNTED_ERRORS = { "ERR_ATTACK_MOUNTED", "ERR_NOT_WHILE_MOUNTED", "SPELL_FAILED_NOT_MOUNTED", "ERR_TAXIPLAYERALREADYMOUNTED",
    "ERR_MOUNT_ALREADYMOUNTED", "SPELL_FAILED_NO_MOUNTS_ALLOWED" }
local STAND_ERRORS = { "SPELL_FAILED_NOT_STANDING", "ERR_CANTATTACK_NOTSTANDING", "ERR_LOOT_NOTSTANDING", "ERR_TAXINOTSTANDING" }
WK:On("UI_ERROR_MESSAGE", function(a, b)
    if not M:General().dismount then return end
    local msg = type(b) == "string" and b or a
    if type(msg) ~= "string" then return end
    if errorMatches(msg, MOUNTED_ERRORS) and IsMounted and IsMounted() and Dismount then
        Dismount()
    elseif errorMatches(msg, STAND_ERRORS) and DoEmote then
        DoEmote("STAND")
    end
end)
WK:On("TAXIMAP_OPENED", function()
    if M:General().dismount and IsMounted and IsMounted() and Dismount then Dismount() end
end)

WK:On("CINEMATIC_START", function()
    if not M:General().skipCinematics then return end
    C_Timer.After(0.1, function()
        if CinematicFrame_CancelCinematic then CinematicFrame_CancelCinematic()
        elseif StopCinematic then StopCinematic() end
    end)
end)
WK:On("PLAY_MOVIE", function()
    if not M:General().skipCinematics then return end
    if MovieFrame and MovieFrame.StopMovie then pcall(MovieFrame.StopMovie, MovieFrame) end
end)

---------------------------------------------------------------------------
-- Classes : chasseur (familier)
---------------------------------------------------------------------------
-- Nourriture qu'un familier a acceptée, par famille (loup, chat…) : apprise quand on le nourrit.
function M:PetFoods(family)
    local q = self:Config()
    q.petFoods[family or "?"] = q.petFoods[family or "?"] or {}
    return q.petFoods[family or "?"]
end

-- Nourriture connue pour le familier actuel, présente dans les sacs, la plus abondante d'abord.
-- Liste du perso connecté gardée jusqu'au prochain changement de sacs ou de familier : la carte du familier la
-- demandait à chaque changement de sa vie (plusieurs fois par seconde en combat), avec un appel au jeu par objet
local foodCache, foodKey, foodAt = nil, nil, -10
local function foodDirty() foodCache = nil end
WK:On("BAG_UPDATE_DELAYED", foodDirty)
WK:On("UNIT_PET", function(unit) if unit == "player" then foodCache = nil end end)
WK:On("PET_BAR_UPDATE", foodDirty)
function M:FoodInBags(c)
    local me = WK.DB:Me()
    c = c or me
    if c == me then
        local key = tostring(c.pet and c.pet.family) .. (_G.UnitExists and _G.UnitExists("pet") and "1" or "0")
        -- 5 s au plus : le relevé des sacs (c.bags) arrive un peu après BAG_UPDATE_DELAYED
        local now = _G.GetTime and _G.GetTime() or 0
        if foodCache and foodKey == key and now - foodAt < 5 and now >= foodAt then return foodCache end
        foodCache, foodKey, foodAt = self:FoodInBagsNow(c), key, now
        return foodCache
    end
    return self:FoodInBagsNow(c)
end
function M:FoodInBagsNow(c)
    local family = c.pet and c.pet.family
    local list, seen = {}, {}
    local isMe = c == WK.DB:Me() and UnitExists and UnitExists("pet")
    for id, n in pairs(c.bags or {}) do
        local ok = isMe and self:CanPetEat(id)
        if ok == nil then ok = self:PetFoods(family)[id] end -- le jeu ne sait pas : ce qu'on a appris
        if ok and n > 0 and not seen[id] then
            seen[id] = true
            table.insert(list, { id = id, n = n })
        end
    end
    table.sort(list, function(a, b) return a.n > b.n end)
    return list
end

local pendingFood
local function noteFood(id) if id and SpellIsTargeting and SpellIsTargeting() then pendingFood = id end end
if hooksecurefunc then
    if C_Container and C_Container.UseContainerItem then
        hooksecurefunc(C_Container, "UseContainerItem", function(bag, slot) noteFood((WK.Container.Info(bag, slot))) end)
    elseif UseContainerItem then
        hooksecurefunc("UseContainerItem", function(bag, slot) noteFood((WK.Container.Info(bag, slot))) end)
    end
    if C_Container and C_Container.PickupContainerItem then
        hooksecurefunc(C_Container, "PickupContainerItem", function(bag, slot) noteFood((WK.Container.Info(bag, slot))) end)
    end
end

WK:On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
    if unit ~= "player" or spellID ~= SPELL_FEED_PET then return end
    local c = WK.DB:Me()
    if pendingFood then
        M:PetFoods(c.pet and c.pet.family)[pendingFood] = true
        pendingFood = nil
        M:UpdateFeedMacro()
    end
end)

function M:MacroIndex()
    return GetMacroIndexByName and GetMacroIndexByName(FEED_MACRO) or 0
end

function M:FeedMacroBody()
    local spell = WK.SpellInfo(SPELL_FEED_PET) or "Nourrir le familier"
    local food = self:FoodInBags()[1]
    local foodName = food and WK.GetItemInfo(food.id)
    if not foodName then return "#showtooltip\n/cast " .. spell end
    return "#showtooltip\n/cast " .. spell .. "\n/use " .. foodName
end

-- Bouton « Nourrir » de la pile d'alertes : même texte que la macro.
function M:FeedAction()
    return { label = T("Nourrir"), attrs = { type = "macro", macrotext = self:FeedMacroBody() } }
end

-- Crée (create = true) ou met à jour la macro « WK Nourrir » du perso. Hors combat seulement.
function M:UpdateFeedMacro(create)
    if WK.DB:Me().class ~= "HUNTER" or not CreateMacro then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    local idx = self:MacroIndex()
    local body = self:FeedMacroBody()
    if idx == 0 then
        if not create then return false end
        local ok = pcall(CreateMacro, FEED_MACRO, "INV_MISC_QUESTIONMARK", body, true)
        if not ok then WK:Print(T("Impossible de créer la macro : plus de place pour les macros de ce perso.")) return false end
        return true
    end
    pcall(EditMacro, idx, FEED_MACRO, nil, body)
    return true
end

function M:PickupFeedMacro()
    if not self:UpdateFeedMacro(true) then return end
    local idx = self:MacroIndex()
    if idx > 0 and PickupMacro then PickupMacro(idx) end
end

---------------------------------------------------------------------------
-- Classes : voleur (poisons sur les armes, vol à la tire)
---------------------------------------------------------------------------
-- Temps restant (secondes) des poisons sur l'arme principale et la main gauche (nil = rien).
function M:PoisonTimes()
    if not GetWeaponEnchantInfo then return nil, nil end
    local hasMain, mainExp, _, _, hasOff, offExp = GetWeaponEnchantInfo()
    return hasMain and math.floor((mainExp or 0) / 1000) or nil, hasOff and math.floor((offExp or 0) / 1000) or nil
end

local warnedPoison = {}
-- Bouton « Poser » : le poison le plus fort des sacs sur l'arme (16 = principale, 17 = main gauche).
function M:PoisonAction(slot)
    local count = (C_Item and C_Item.GetItemCount) or GetItemCount
    if not count then return nil end
    local ids = {}
    for _, r in ipairs(M.REAGENTS.ROGUE or {}) do if r.key == "poisons" then ids = r.ids end end
    for i = #ids, 1, -1 do
        if (count(ids[i]) or 0) > 0 then
            return { label = T("Poser"), tip = (WK.GetItemInfo(ids[i])) or nil,
                     attrs = { type = "macro", macrotext = "/use item:" .. ids[i] .. "\n/use " .. (slot == "main" and 16 or 17) } }
        end
    end
    return nil
end
local function checkPoisons()
    local c = WK.DB:Me()
    if c.class ~= "ROGUE" then return end
    local cc = M:Class("ROGUE")
    if not cc.poisonAlert then return end
    local main, off = M:PoisonTimes()
    local limit = (cc.poisonMin or 5) * 60
    for slot, left in pairs({ main = main or false, off = off or false }) do
        if left and left > 0 and left <= limit then
            -- dans le chat, une fois par poison qui s'achève (les rappels à l'écran ont été retirés)
            if not warnedPoison[slot] then
                WK:Print(string.format(T("%s : encore %d min."), slot == "main" and T("Poison de l'arme principale")
                    or T("Poison de la main gauche"), math.ceil(left / 60)))
            end
            warnedPoison[slot] = true
        elseif not left or left > limit then
            warnedPoison[slot] = nil
        end
    end
end

-- Or volé à la tire : butin d'une cible encore vivante.
local pickpocketing, moneyBefore = false, 0
WK:On("LOOT_OPENED", function()
    local c = WK.DB:Me()
    if c.class ~= "ROGUE" then return end
    pickpocketing = UnitExists("target") and not UnitIsDead("target") and (not UnitCanAttack or UnitCanAttack("player", "target")) or false
    moneyBefore = GetMoney()
end)
WK:On("LOOT_CLOSED", function()
    if not pickpocketing then return end
    C_Timer.After(0.5, function()
        local gain = GetMoney() - moneyBefore
        pickpocketing = false
        if gain > 0 then
            local c = WK.DB:Me()
            c.pickpocket = (c.pickpocket or 0) + gain
            WK:NotifyChanged()
        end
    end)
end)

-- Coffres à crocheter dans les sacs de tous les persos : { { id, n, skill, where = nom } }.
function M:Lockboxes()
    local list = {}
    for key, c in pairs(WK.DB.global.characters) do
        for id, skill in pairs(M.LOCKBOXES) do
            local n = (c.bags or {})[id] or 0
            if n > 0 then table.insert(list, { id = id, n = n, skill = skill, where = WK:CharName(c, key), key = key }) end
        end
    end
    table.sort(list, function(a, b) if a.skill ~= b.skill then return a.skill < b.skill end return a.where < b.where end)
    return list
end

---------------------------------------------------------------------------
-- Classes : démoniste (fragments d'âme en trop)
---------------------------------------------------------------------------
function M:DeleteExtraShards()
    local c = WK.DB:Me()
    if c.class ~= "WARLOCK" or not DeleteCursorItem then return 0 end
    if InCombatLockdown and InCombatLockdown() then return 0 end
    local keep = self:Class("WARLOCK").shardMax or 20
    local slots = {}
    for _, bag in ipairs(WK.modules.Inventory:BagList()) do
        for slot = 1, (WK.Container.NumSlots(bag) or 0) do
            local id, count = WK.Container.Info(bag, slot)
            if id == 6265 then table.insert(slots, { bag = bag, slot = slot, n = count or 1 }) end
        end
    end
    local total = 0
    for _, s in ipairs(slots) do total = total + s.n end
    local deleted = 0
    for i = #slots, 1, -1 do
        if total - deleted <= keep then break end
        local s = slots[i]
        if s.n <= total - deleted - keep then
            ClearCursor()
            WK.Container.Pickup(s.bag, s.slot)
            if CursorHasItem and CursorHasItem() then
                DeleteCursorItem()
                deleted = deleted + s.n
            end
        end
    end
    if deleted > 0 then WK:Print(string.format(T("%d fragment(s) d'âme supprimé(s)."), deleted)) end
    return deleted
end

---------------------------------------------------------------------------
-- Classes : guerrier (deux équipements d'armes)
---------------------------------------------------------------------------
-- sets[clé du perso] = { two = { main = lien }, shield = { main = lien, off = lien } }
-- Armes enregistrées par perso : données, hors profils (WK.DB.global.weaponSets ; reprend qol.classes.WARRIOR.sets)
function M:WeaponSets(key)
    key = key or WK:CharKey()
    local g = WK.DB.global
    g.weaponSets = g.weaponSets or {}
    if not g.weaponSets[key] then
        local cc = self:Class("WARRIOR")
        g.weaponSets[key] = (cc.sets and cc.sets[key]) or {}
        if cc.sets then cc.sets[key] = nil end
    end
    return g.weaponSets[key]
end

function M:SaveWeaponSet(which)
    local sets = self:WeaponSets()
    sets[which] = { main = GetInventoryItemLink("player", 16), off = GetInventoryItemLink("player", 17) }
    WK:Print(string.format(T("Équipement « %s » enregistré."), which == "two" and T("Deux mains") or T("Arme et bouclier")))
end

function M:EquipWeaponSet(which)
    if InCombatLockdown and InCombatLockdown() then WK:Print(T("Pas en combat.")) return end
    local s = self:WeaponSets()[which]
    if not s or not s.main then WK:Print(T("Équipement pas encore enregistré.")) return end
    WK.EquipItem(s.main, 16)
    if s.off then C_Timer.After(0.3, function() WK.EquipItem(s.off, 17) end) end
end

---------------------------------------------------------------------------
-- Classes : prêtre, paladin, druide (rappels de buffs)
---------------------------------------------------------------------------
local function buffNames(ids)
    local set = {}
    for _, id in ipairs(ids) do local n = WK.SpellInfo(id); if n then set[n] = true end end
    return set
end

-- Temps restant du premier buff trouvé parmi `names` sur `unit` (0 = sans durée), nil s'il manque.
-- Le jeu peut masquer les auras (« secret ») : la lecture passe par pcall et une aura illisible
-- rend 0 (« présent ») pour ne jamais lancer de rappel à tort.
local function buffLeft(unit, names, contains)
    for i = 1, 40 do
        local name, expires
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
            if not ok then return 0 end
            if not a then break end
            name, expires = readable(a.name), readable(a.expirationTime)
            if name == nil then return 0 end
        elseif UnitBuff then
            local ok, n, _, _, _, _, exp = pcall(UnitBuff, unit, i)
            if not ok then return 0 end
            if n == nil then break end
            name, expires = readable(n), readable(exp)
            if name == nil then return 0 end
        else
            break
        end
        local hit = names[name]
        if not hit and contains then
            local l = string.lower(name or "")
            for _, w in ipairs(contains) do if string.find(l, w, 1, true) then hit = true break end end
        end
        if hit then
            if not expires or expires == 0 then return 0 end
            return math.max(0, expires - GetTime())
        end
    end
    return nil
end

local function groupUnits()
    local units = {}
    if IsInRaid and IsInRaid() then
        for i = 1, GetNumGroupMembers() do table.insert(units, "raid" .. i) end
    elseif IsInGroup and IsInGroup() then
        table.insert(units, "player")
        for i = 1, GetNumSubgroupMembers() do table.insert(units, "party" .. i) end
    end
    return units
end

local function canRemind()
    if InCombatLockdown and InCombatLockdown() then return false end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return false end
    if UnitOnTaxi and UnitOnTaxi("player") then return false end
    return true
end

-- Icônes de la pile : un bouton par sort connu de la liste (bénédictions, auras…), lancé sur l'unité donnée.
local BLESSINGS = { 19740, 19742, 20217, 1038, 19977, 20911 } -- Puissance, Sagesse, Rois, Salut, Lumière, Sanctuaire
local AURAS = { 465, 7294, 19746, 19876, 19888, 19891, 20218 } -- Dévotion, Vindicte, Concentration, Ombre, Givre, Feu, Sainteté
local function spellIcons(ids, unit)
    local out = {}
    for _, id in ipairs(ids) do
        local known = (IsPlayerSpell and IsPlayerSpell(id)) or (IsSpellKnown and IsSpellKnown(id))
        local name = WK.SpellInfo(id)
        if known ~= false and name then
            local tex = (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)) or (GetSpellTexture and GetSpellTexture(id))
            table.insert(out, { icon = tex, tip = name, attrs = { type = "spell", spell = name, unit = unit or "player" } })
        end
    end
    return #out > 0 and out or nil
end
M.BLESSINGS, M.AURAS, M.SpellIcons = BLESSINGS, AURAS, spellIcons

local function checkBuffs()
    local c = WK.DB:Me()
    local cc = c.class and M:Class(c.class)
    if not cc or not cc.buffReminder or not canRemind() then return end
    if c.class == "PRIEST" and (c.level or 0) >= 1 then
        local names, missing, firstUnit = buffNames(FORTITUDE), {}, nil
        for _, u in ipairs(groupUnits()) do
            if UnitExists(u) and UnitIsConnected(u) and not UnitIsDeadOrGhost(u) then
                local left = buffLeft(u, names)
                if not left or (left > 0 and left < 60) then
                    table.insert(missing, readable((UnitName(u))) or "?")
                    firstUnit = firstUnit or u
                end
            end
        end
        if #missing > 0 then
            M:Remind("fort", string.format(T("Robustesse à remettre : %s"), table.concat(missing, ", ")), 0.9, 0.9, 1, true,
                { icons = spellIcons(FORTITUDE, firstUnit) })
        else
            M:ClearRemind("fort")
        end
    elseif c.class == "PALADIN" then
        local noAura = GetShapeshiftForm and GetNumShapeshiftForms and GetNumShapeshiftForms() > 0 and GetShapeshiftForm() == 0
        local noBless = not noAura and not buffLeft("player", {}, { "bénédiction", "blessing" })
        if noAura then M:Remind("aura", T("Aucune aura active"), 0.96, 0.55, 0.73, true, { icons = spellIcons(AURAS) }) else M:ClearRemind("aura") end
        if noBless then M:Remind("bless", T("Pas de bénédiction sur toi"), 0.96, 0.55, 0.73, true, { icons = spellIcons(BLESSINGS) }) else M:ClearRemind("bless") end
    elseif c.class == "DRUID" then
        local names = buffNames(MARK_OF_WILD)
        if not buffLeft("player", names) then
            M:Remind("motw", T("Marque du fauve absente"), 1, 0.49, 0.04, true, { icons = spellIcons(MARK_OF_WILD, "player") })
        else
            M:ClearRemind("motw")
        end
    end
end

---------------------------------------------------------------------------
-- Évènements et minuteries
---------------------------------------------------------------------------
function M:OnInit() self:Config() end

function M:OnLogin()
    self:ScanDurability()
    self:ScanAmmo()
    self:ScanPet()
    self:ScanLockpicking()
    self:ScanReincarnation()
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(15, function() checkPoisons(); checkBuffs() end)
    end
end

local bagPending = false
WK:On("BAG_UPDATE", function()
    if bagPending then return end
    bagPending = true
    C_Timer.After(1, function()
        bagPending = false
        M:ScanAmmo()
        if WK.DB:Me().class == "HUNTER" and M:MacroIndex() > 0 then M:UpdateFeedMacro() end
    end)
end)
WK:On("UPDATE_INVENTORY_DURABILITY", function() M:ScanDurability() end)
WK:On("UNIT_INVENTORY_CHANGED", function(unit) if unit == "player" then M:ScanAmmo() end end)
WK:On("UNIT_HAPPINESS", function() M:ScanPet() end)
WK:On("UNIT_PET", function(unit) if unit == "player" then M:ScanPet() end end)
WK:On("PET_UI_UPDATE", function() M:ScanPet() end)
WK:On("SKILL_LINES_CHANGED", function() M:ScanLockpicking() end)
WK:On("SPELL_UPDATE_COOLDOWN", function() M:ScanReincarnation() end)
WK:On("PLAYER_REGEN_ENABLED", function() C_Timer.After(2, checkBuffs) end)
