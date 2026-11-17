local ADDON_NAME, WK = ...
local M = WK:NewModule("Fishing")
local T = function(s) return WK.T(s) end

-- Pêche : un « mode pêche » qu'on ouvre et qu'on ferme.
--   à l'ouverture : tenue de pêche équipée, sons du jeu baissés pour entendre le flotteur,
--   une touche unique qui fait tout (tenue, appât, lancer, ferrer), barre à l'écran ;
--   à la fermeture : tout est remis comme avant.
-- Réglages : WK.modules.QoL:Config().fishing ; tenue retenue par perso : WK.DB.char.fishGear.
-- Le jeu protège l'usage des objets et des sorts : appât et lancer passent par un bouton
-- protégé (UI/FishingBar.lua), jamais modifié en combat.

local FISHING = 7620
local SOFT = "softinteract"
M.BUTTON = "WarbandKeeperFishButton"

-- Appâts : bonus, compétence requise (du meilleur au moins bon)
M.LURES = {
    { id = 6533, bonus = 100, req = 100 }, -- Attracteur de poissons aquadynamique
    { id = 6532, bonus = 75, req = 100 },  -- Babioles éclatantes
    { id = 7307, bonus = 75, req = 100 },  -- Ver mangeur de chair
    { id = 6811, bonus = 50, req = 50 },   -- Lentille aquadynamique
    { id = 6530, bonus = 50, req = 50 },   -- Asticots
    { id = 6529, bonus = 25, req = 1 },    -- Babiole brillante
}
-- Cannes connues et leur bonus (une canne inconnue compte pour 0)
local POLES = { [6256] = 0, [12225] = 3, [6365] = 5, [6366] = 15, [6367] = 20, [19022] = 20, [19970] = 35 }
-- Autres pièces qui donnent de la Pêche : objet -> emplacement
local EXTRA = { [19972] = 1, [19969] = 8 } -- Chapeau de pêcheur porte-bonheur, Bottes de Nat Pagle
local MAINHAND, OFFHAND = 16, 17

local DEFAULTS = {
    autoOpen = true, autoGear = true, restoreGear = true, autoLure = true, lure = "best",
    fastLoot = true, sound = true, warn = true, minimap = true, key = "MOUSEWHEELDOWN", recap = true,
}
function M:Config()
    local q = WK.modules.QoL:Config()
    q.fishing = q.fishing or {}
    for k, v in pairs(DEFAULTS) do if q.fishing[k] == nil then q.fishing[k] = v end end
    return q.fishing
end

local function inCombat() return InCombatLockdown and InCombatLockdown() end
local function spellName() return (WK.SpellInfo(FISHING)) or "Pêche" end
M.SpellName = spellName

-- Le perso connaît-il la Pêche ? Et à quel niveau ?
function M:Skill()
    local name = spellName()
    local p = (WK.DB:Me().professions or {})[name]
    return p and p.rank or nil
end
function M:Knows() return self:Skill() ~= nil end

---------------------------------------------------------------------------
-- Objets : cannes, pièces de pêche, appâts
---------------------------------------------------------------------------
local function itemInstant(id)
    local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not f then return nil end
    local _, _, _, equipLoc, icon, classID, subClassID = f(id)
    return equipLoc, icon, classID, subClassID
end
local function isPole(id)
    if not id then return false end
    if POLES[id] then return true end
    local _, _, classID, subClassID = itemInstant(id)
    return classID == 2 and subClassID == 20
end
M.IsPole = isPole

local function equippedID(slot) return GetInventoryItemID and GetInventoryItemID("player", slot) or nil end
local function equippedLink(slot) return GetInventoryItemLink and GetInventoryItemLink("player", slot) or nil end

local function eachBagItem(fn)
    for bag = 0, 4 do
        for slot = 1, WK.Container.NumSlots(bag) or 0 do
            local id, count = WK.Container.Info(bag, slot)
            if id and fn(id, count or 1) then return end
        end
    end
end

function M:PoleEquipped() return isPole(equippedID(MAINHAND)) end

-- Meilleure canne dans les sacs (ou nil)
function M:BagPole()
    local best, bonus
    eachBagItem(function(id)
        if isPole(id) and (not best or (POLES[id] or 0) > bonus) then best, bonus = id, POLES[id] or 0 end
    end)
    return best
end
function M:HasPole() return self:PoleEquipped() or self:BagPole() ~= nil end

function M:Count(id)
    local n = 0
    eachBagItem(function(i, c) if i == id then n = n + c end end)
    return n
end

-- Appât à poser : celui choisi, ou le meilleur utilisable à ce niveau de Pêche. nil s'il n'y en a pas.
function M:PickLure()
    local o = self:Config()
    local skill = self:Skill() or 0
    if o.lure ~= "best" then
        local id = tonumber(o.lure)
        if id and self:Count(id) > 0 then return id end
        return nil
    end
    for _, l in ipairs(M.LURES) do
        if skill >= l.req and self:Count(l.id) > 0 then return l.id end
    end
    return nil
end

-- Un appât est-il posé sur la canne ? Renvoie aussi les secondes restantes.
function M:LureLeft()
    if not GetWeaponEnchantInfo then return nil end
    local has, ms = GetWeaponEnchantInfo()
    if has then return math.floor((ms or 0) / 1000) end
    return nil
end

---------------------------------------------------------------------------
-- Tenue
---------------------------------------------------------------------------
local function equip(item, slot)
    local f = (C_Item and C_Item.EquipItemByName) or EquipItemByName
    if f and item then pcall(f, item, slot) end
end

-- Équipe la canne et les pièces de pêche ; retient ce qu'elles remplacent.
function M:EquipGear()
    if inCombat() then return false end
    local saved = WK.DB.char.fishGear or {}
    WK.DB.char.fishGear = saved
    local done = false
    if not self:PoleEquipped() then
        local pole = self:BagPole()
        if pole then
            -- une canne se tient à deux mains : on retient les deux armes
            if saved[MAINHAND] == nil then saved[MAINHAND] = equippedLink(MAINHAND) or false end
            if saved[OFFHAND] == nil then saved[OFFHAND] = equippedLink(OFFHAND) or false end
            equip(pole, MAINHAND)
            done = true
        end
    end
    for id, slot in pairs(EXTRA) do
        if equippedID(slot) ~= id and self:Count(id) > 0 then
            if saved[slot] == nil then saved[slot] = equippedLink(slot) or false end
            equip(id, slot)
            done = true
        end
    end
    return done
end

-- Remet l'équipement retenu.
function M:RestoreGear()
    if inCombat() then self.pendingRestore = true return end
    local saved = WK.DB.char.fishGear
    if not saved then return end
    for _, slot in ipairs({ MAINHAND, OFFHAND, 1, 8 }) do
        local link = saved[slot]
        if link then equip(link, slot) end
    end
    WK.DB.char.fishGear = nil
end

---------------------------------------------------------------------------
-- Sons : baisser musique et ambiance pour entendre le flotteur
---------------------------------------------------------------------------
-- niveaux (QoL > Pêche > Confort, réglage soundLevel) : léger, fort (musique et ambiance coupées),
-- maximum (en plus : voix coupées, volume général au maximum, son gardé quand le jeu est en arrière-plan)
local SOUND_LEVELS = {
    light = { Sound_MusicVolume = "0.15", Sound_AmbienceVolume = "0.15", Sound_SFXVolume = "1" },
    strong = { Sound_MusicVolume = "0", Sound_AmbienceVolume = "0", Sound_SFXVolume = "1" },
    max = { Sound_MusicVolume = "0", Sound_AmbienceVolume = "0", Sound_DialogVolume = "0", Sound_SFXVolume = "1",
            Sound_MasterVolume = "1", Sound_EnableSFX = "1", Sound_EnableSoundWhenGameIsInBG = "1" },
}
M.SOUND_LEVELS = SOUND_LEVELS
local function getCVar(n) if C_CVar and C_CVar.GetCVar then return C_CVar.GetCVar(n) end return GetCVar and GetCVar(n) end
local function setCVar(n, v)
    if getCVar(n) == nil then return end
    if C_CVar and C_CVar.SetCVar then pcall(C_CVar.SetCVar, n, v) elseif SetCVar then pcall(SetCVar, n, v) end
end

function M:FocusSound(on)
    local o = self:Config()
    if on then
        if not o.sound or o.savedSound then return end
        o.savedSound = {}
        for name, value in pairs(SOUND_LEVELS[o.soundLevel or "strong"] or SOUND_LEVELS.strong) do
            o.savedSound[name] = getCVar(name)
            setCVar(name, value)
        end
    elseif o.savedSound then
        for name, value in pairs(o.savedSound) do setCVar(name, value) end
        o.savedSound = nil
    end
end

---------------------------------------------------------------------------
-- Désignation du flotteur : la touche unique ferre avec « Interagir avec la cible »
---------------------------------------------------------------------------
local SOFT_CVARS = { SoftTargetInteract = "3", SoftTargetInteractArc = "2", SoftTargetInteractRange = "60",
                     SoftTargetInteractOnlyInRange = "0", SoftTargetInteractRangeIsHard = "0" }
function M:SoftTarget(on)
    local o = self:Config()
    if on then
        if o.savedSoft then return end
        o.savedSoft = {}
        for name, value in pairs(SOFT_CVARS) do
            o.savedSoft[name] = getCVar(name) or false
            -- la portée n'est jamais réduite (le halo peut l'avoir montée)
            if name ~= "SoftTargetInteractRange" or (tonumber(getCVar(name)) or 0) < 60 then setCVar(name, value) end
        end
    elseif o.savedSoft then
        local G = WK.modules.Glow
        local glowOn = G and G:Config().enabled and not G:OtherAddonLoaded()
        for name, value in pairs(o.savedSoft) do
            if value and not glowOn then setCVar(name, value) end
        end
        o.savedSoft = nil
        if glowOn then G:ApplyCVars() end -- le halo garde ses propres réglages
    end
end

local function channeling()
    if not UnitChannelInfo then return false end
    local name = UnitChannelInfo("player")
    return name ~= nil and name == spellName()
end
M.Channeling = channeling

-- Un flotteur est-il désigné ? (ligne à l'eau et objet du décor désigné par le jeu)
function M:BobberReady()
    if not channeling() then return false end
    local G = WK.modules.Glow
    return G and G.SoftExists and G.SoftExists(SOFT) or false
end

---------------------------------------------------------------------------
-- Touche unique
---------------------------------------------------------------------------
-- Hors combat seulement. Flotteur prêt : la touche ferre ; sinon elle clique le bouton de pêche.
function M:UpdateBinding()
    local btn = _G[M.BUTTON]
    if not btn or inCombat() then return end
    ClearOverrideBindings(btn)
    local key = self:Config().key
    if not self.active or not key or key == "" then return end
    if self:BobberReady() then
        SetOverrideBinding(btn, true, key, "INTERACTTARGET")
    else
        SetOverrideBindingClick(btn, true, key, M.BUTTON, "LeftButton")
    end
end

-- Ce que fera le prochain appui : "gear", "lure", "cast" ou "nopole". Avec l'appât à poser.
function M:NextStep()
    local o = self:Config()
    if not self:PoleEquipped() then
        if o.autoGear and self:BagPole() then return "gear" end
        return "nopole"
    end
    if o.autoLure and not self:LureLeft() then
        local lure = self:PickLure()
        if lure then return "lure", lure end
    end
    return "cast"
end

-- Texte de macro du bouton pour l'étape (le bouton protégé l'exécute au clic).
function M:MacroFor(step, lure)
    if step == "lure" and lure then return "/use item:" .. lure .. "\n/use " .. MAINHAND end
    if step == "cast" then return "/cast " .. spellName() end
    return ""
end

-- Appelé juste avant le clic du bouton (hors combat) : prépare l'étape.
function M:PrepareClick(btn)
    if inCombat() then return end
    local step, lure = self:NextStep()
    btn:SetAttribute("macrotext", self:MacroFor(step, lure))
    if step == "gear" then self:EquipGear()
    elseif step == "nopole" then self:Warn() end
end

---------------------------------------------------------------------------
-- Avertissements à l'écran (pile d'alertes)
---------------------------------------------------------------------------
function M:FreeSlots()
    local n = 0
    for bag = 0, 4 do n = n + (WK.Container.NumFree(bag) or 0) end
    return n
end

function M:Warn()
    local UI = WK.UI
    if not UI or not UI.SetAlert then return end
    local o = self:Config()
    local on = self.active and o.warn
    local C = UI.colors
    local icon = select(2, WK.SpellInfo(FISHING))
    local noPole = on and not self:HasPole()
    UI:SetAlert("fish.pole", noPole, { text = T("Pas de canne à pêche : achète-en une (fournitures de pêche)"), color = C.negative, prio = 1, icon = icon })
    local needGear = on and not noPole and not self:PoleEquipped() and not o.autoGear
    UI:SetAlert("fish.gear", needGear, { text = T("Canne non équipée : équipe ta tenue de pêche"), color = C.warning, prio = 2, icon = icon })
    local noLure = on and self:PoleEquipped() and not self:LureLeft() and not self:PickLure() and (self:Skill() or 0) < 300
    UI:SetAlert("fish.lure", noLure and o.autoLure, { text = T("Plus d'appât dans les sacs"), color = C.warning, prio = 3, icon = icon })
    UI:SetAlert("fish.bags", on and self:FreeSlots() == 0, { text = T("Sacs pleins : la prise ne pourra pas être ramassée"), color = C.negative, prio = 1, icon = icon })
end

---------------------------------------------------------------------------
-- Mode pêche
---------------------------------------------------------------------------
function M:Start(fromEquip)
    if self.active then return end
    if not WK:FeatureOn("fishing") then if not fromEquip then WK:Print(T("Le module Pêche est coupé (Résumé > Modules).")) end return end
    if inCombat() then WK:Print(T("Pas en combat.")) return end
    if not self:Knows() then WK:Print(T("Ce perso ne connaît pas la Pêche.")) return end
    local o = self:Config()
    self.active = true
    self.hadPole = self:PoleEquipped() or nil
    if not fromEquip and o.autoGear then self:EquipGear() end
    self:FocusSound(true)
    self:SoftTarget(true)
    if WK.UI.SyncFishingBar then WK.UI:SyncFishingBar() end
    self:UpdateBinding()
    self:Warn()
    if WK.modules.FishingLog then WK.modules.FishingLog:StartSession() end
    WK:NotifyChanged()
end

function M:Stop(keepGear)
    if not self.active then return end
    self.active = false
    self.hadPole = nil
    self:FocusSound(false)
    self:SoftTarget(false)
    if inCombat() then
        self.pendingStop = true -- barre et touche : à la sortie du combat
    else
        local btn = _G[M.BUTTON]
        if btn then ClearOverrideBindings(btn) end
        if WK.UI.SyncFishingBar then WK.UI:SyncFishingBar() end
    end
    if not keepGear and self:Config().restoreGear then self:RestoreGear() end
    self:Warn()
    if WK.modules.FishingLog then WK.modules.FishingLog:EndSession() end
    WK:NotifyChanged()
end

function M:Toggle() if self.active then self:Stop() else self:Start() end end

---------------------------------------------------------------------------
-- Butin rapide
---------------------------------------------------------------------------
local function fastLoot()
    -- carnet de pêche : la prise est notée avant d'être ramassée
    if WK.modules.FishingLog then pcall(WK.modules.FishingLog.Record, WK.modules.FishingLog) end
    if not M.active or not M:Config().fastLoot then return end
    if IsFishingLoot and not IsFishingLoot() then return end
    if M:FreeSlots() == 0 then return end -- sacs pleins : on laisse faire le jeu
    for i = (GetNumLootItems and GetNumLootItems() or 0), 1, -1 do LootSlot(i) end
end

---------------------------------------------------------------------------
-- Évènements
---------------------------------------------------------------------------
WK:On("LOOT_READY", fastLoot)
WK:On("LOOT_OPENED", fastLoot)
WK:On("PLAYER_SOFT_INTERACT_CHANGED", function() if M.active then M:UpdateBinding() end end)
local function castChanged(unit) if unit == "player" and M.active then M:UpdateBinding() end end
WK:On("UNIT_SPELLCAST_CHANNEL_START", castChanged)
WK:On("UNIT_SPELLCAST_CHANNEL_STOP", castChanged)
-- En combat, la touche retrouve son rôle normal ; elle revient après.
WK:On("PLAYER_REGEN_DISABLED", function()
    local btn = _G[M.BUTTON]
    if btn and M.active then pcall(ClearOverrideBindings, btn) end
end)
WK:On("PLAYER_REGEN_ENABLED", function()
    if M.pendingStop then
        M.pendingStop = nil
        local btn = _G[M.BUTTON]
        if btn then ClearOverrideBindings(btn) end
        if WK.UI.SyncFishingBar then WK.UI:SyncFishingBar() end
    end
    if M.pendingRestore then M.pendingRestore = nil; M:RestoreGear() end
    if M.active then M:UpdateBinding() end
end)
-- Canne équipée : le mode s'ouvre tout seul (option) ; canne retirée : il se ferme.
WK:On("PLAYER_EQUIPMENT_CHANGED", function(slot)
    if slot and slot ~= MAINHAND then return end
    if inCombat() then return end
    if M:PoleEquipped() then
        M.hadPole = true
        if not M.active and M:Config().autoOpen and M:Knows() then M:Start(true) end
    elseif M.active and M.hadPole then
        -- la canne a été retirée à la main : on ferme sans toucher à l'équipement
        M:Stop(true)
        WK.DB.char.fishGear = nil
    end
    if M.active then M:Warn(); if WK.UI.RefreshFishingBar then WK.UI:RefreshFishingBar() end end
end)
WK:On("BAG_UPDATE_DELAYED", function()
    if M.active then M:Warn(); if WK.UI.RefreshFishingBar then WK.UI:RefreshFishingBar() end end
end)

function M:OnLogin()
    local o = self:Config()
    -- sons ou réglages restés modifiés après une déconnexion en mode pêche : on les rend
    if o.savedSound then self:FocusSound(false) end
    if o.savedSoft then self:SoftTarget(false) end
    C_Timer.After(2, function()
        if not inCombat() and M:PoleEquipped() and M:Config().autoOpen and M:Knows() then M:Start(true) end
    end)
end
