local ADDON_NAME, WK = ...
local M = WK:NewModule("Hunter")
local T = function(s) return WK.T(s) end

-- Aides du chasseur : rappels dans la pile d'alertes (aspect, Guépard ou Meute en combat,
-- Grondement, pistage) et bouton « familier absent ou mort ».
-- Sur WoW Forever, les auras sont masquées en combat : l'aspect actif est lu hors combat et
-- suivi en combat par les sorts que le joueur lance.

local ASPECTS = { monkey = 13163, hawk = 13165, cheetah = 5118, pack = 13159, beast = 13161, wild = 20043 }
local RISKY = { cheetah = true, pack = true } -- hébétement si on est touché
M.ASPECTS = ASPECTS
M.ASPECT_ORDER = { "hawk", "monkey", "cheetah", "pack", "beast", "wild" }
local GROWL = 2649
local TRACK_HUMANOIDS = 19883
local CALL_PET, REVIVE_PET = 883, 982

local function cfg() return WK.modules.QoL:Class("HUNTER") end
-- Classe lue au jeu : à la connexion, Characters n'a pas forcément encore noté c.class
local function isHunter() return UnitClass and select(2, UnitClass("player")) == "HUNTER" end
local readable = function(v) return WK.modules.QoL.Readable(v) end

-- HunterSuite (l'addon d'un autre auteur) fait déjà tout ça : on lui laisse la place.
function M:HunterSuiteLoaded()
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    return loaded and loaded("HunterSuite") and true or false
end
-- En retrait quand HunterSuite est là, sauf si le joueur veut garder les deux.
function M:OtherAddonLoaded()
    return self:HunterSuiteLoaded() and not WK.modules.QoL:Class("HUNTER").keepWithHunterSuite
end

local function spellName(id) return (WK.SpellInfo(id)) end
local function spellIcon(id) return select(2, WK.SpellInfo(id)) end

---------------------------------------------------------------------------
-- Aspect actif
---------------------------------------------------------------------------
local aspectByName -- [nom localisé] = clé
local function aspectNames()
    if not aspectByName then
        aspectByName = {}
        for key, id in pairs(ASPECTS) do
            local n = spellName(id)
            if n then aspectByName[n] = key end
        end
    end
    return aspectByName
end

-- Auras du joueur lisibles (hors combat) : { [nom] = true }, ou nil si le jeu les masque.
local function playerAuras()
    if InCombatLockdown and InCombatLockdown() then return nil end
    local set = {}
    for i = 1, 40 do
        local name
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
            if not ok or not a then break end
            name = readable(a.name)
        elseif UnitBuff then
            name = readable((UnitBuff("player", i)))
            if not name then break end
        else
            return nil
        end
        if name then set[name] = true end
    end
    return set
end

M.aspect = nil -- clé de l'aspect actif (ou nil)
function M:ReadAspect()
    local auras = playerAuras()
    if not auras then return end
    self.aspect = nil
    for name, key in pairs(aspectNames()) do
        if auras[name] then self.aspect = key break end
    end
    self.tracking = auras[spellName(TRACK_HUMANOIDS) or ""] and true or false
end

---------------------------------------------------------------------------
-- Grondement du familier : renvoie true / false (lancer automatique), ou nil sans Grondement.
---------------------------------------------------------------------------
function M:GrowlAutocast()
    if not (UnitExists and UnitExists("pet")) or not GetPetActionInfo then return nil end
    local growl = spellName(GROWL)
    for i = 1, (NUM_PET_ACTION_SLOTS or 10) do
        local r = { GetPetActionInfo(i) }
        if r[1] and r[1] == growl then
            -- client moderne : ..., autoCastAllowed (5), autoCastEnabled (6), spellID (7) ;
            -- ancien client : ..., autoCastAllowed (6), autoCastEnabled (7)
            if type(r[7]) == "boolean" then return readable(r[7]) end
            return readable(r[6])
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- Rappels
---------------------------------------------------------------------------
local function groupInstance()
    local inInst, kind
    if IsInInstance then inInst, kind = IsInInstance() end
    return inInst and (kind == "party" or kind == "raid")
end

function M:UpdateAlerts()
    local UI = WK.UI
    if not UI or not UI.SetAlert then return end
    local on = isHunter() and not self:OtherAddonLoaded()
    local c, cc = WK.DB:Me(), cfg()
    local inCombat = InCombatLockdown and InCombatLockdown()
    local busy = (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) or (UnitOnTaxi and UnitOnTaxi("player")) or (IsMounted and IsMounted())
    local level = c.level or 0
    -- Aucun aspect (hors combat)
    UI:SetAlert("hunter.aspect", on and cc.remAspect and not inCombat and not busy and level >= 10 and self.aspect == nil, {
        icon = spellIcon(ASPECTS.hawk), text = T("Aucun aspect actif"), prio = 3 })
    -- Guépard ou Meute en combat
    UI:SetAlert("hunter.risky", on and cc.remCheetah and inCombat and RISKY[self.aspect or ""] == true, {
        icon = spellIcon(ASPECTS[self.aspect or "cheetah"] or ASPECTS.cheetah),
        text = string.format(T("%s en combat : tu vas être hébété"), spellName(ASPECTS[self.aspect or "cheetah"]) or T("Aspect")),
        color = WK.UI.colors.negative, prio = 1 })
    -- Grondement : désactivé en groupe (donjon, raid), activé en solo
    local growl = on and cc.remGrowl and self:GrowlAutocast()
    local grouped = groupInstance()
    UI:SetAlert("hunter.growl", on and cc.remGrowl and grouped and growl == true, {
        icon = spellIcon(GROWL), text = T("Grondement activé en donjon"), prio = 2 })
    UI:SetAlert("hunter.growlSolo", on and cc.remGrowl and not grouped and not (IsInGroup and IsInGroup())
        and growl == false and UnitExists and UnitExists("pet"), {
        icon = spellIcon(GROWL), text = T("Grondement désactivé en solo"), prio = 4 })
    -- Pistage des humanoïdes en champ de bataille
    local kind
    if IsInInstance then kind = select(2, IsInInstance()) end
    UI:SetAlert("hunter.track", on and cc.remTrack and kind == "pvp" and not inCombat and self.tracking == false, {
        icon = spellIcon(TRACK_HUMANOIDS), text = T("Pistage des humanoïdes inactif"), prio = 4 })
end

---------------------------------------------------------------------------
-- Bouton « familier absent ou mort » (bouton protégé : marche en combat)
---------------------------------------------------------------------------
local petBtn
local VISIBILITY = "[dead][mounted] hide; [@pet,dead] show; [nopet] show; hide"


function M:BuildPetButton()
    if petBtn or not CreateFrame or (InCombatLockdown and InCombatLockdown()) then return end
    local UI = WK.UI
    local C = UI.colors
    petBtn = CreateFrame("Button", "WarbandKeeperPetButton", UIParent, "SecureActionButtonTemplate")
    petBtn:SetSize(54, 54)
    petBtn:SetFrameStrata("MEDIUM")
    petBtn:SetClampedToScreen(true)
    if petBtn.RegisterForClicks then petBtn:RegisterForClicks("AnyUp", "AnyDown") end
    local call, revive = spellName(CALL_PET) or "Appel du familier", spellName(REVIVE_PET) or "Ressusciter le familier"
    petBtn:SetAttribute("type1", "macro")
    petBtn:SetAttribute("macrotext1", "/cast [@pet,dead] " .. revive .. "; " .. call)
    petBtn:SetAttribute("type2", "spell")
    petBtn:SetAttribute("spell2", revive)
    -- Visuel : anneau qui pulse, icône ronde, texte dessous
    petBtn.glow = petBtn:CreateTexture(nil, "BACKGROUND")
    petBtn.glow:SetTexture(UI.MEDIA .. "fxhalo")
    petBtn.glow:SetBlendMode("ADD")
    petBtn.glow:SetPoint("CENTER")
    petBtn.glow:SetSize(96, 96)
    petBtn.ring = petBtn:CreateTexture(nil, "BORDER")
    petBtn.ring:SetTexture(UI.MEDIA .. "circle")
    petBtn.ring:SetAllPoints()
    petBtn.icon = UI:RoundIcon(petBtn, 46)
    petBtn.icon:SetPoint("CENTER")
    petBtn.label = UI:Text(petBtn, 11, C.text)
    petBtn.label:SetPoint("TOP", petBtn, "BOTTOM", 0, -4)
    petBtn.label:SetJustifyH("CENTER")
    local ag = petBtn.glow.CreateAnimationGroup and petBtn.glow:CreateAnimationGroup()
    local a = ag and ag:CreateAnimation("Alpha")
    if a then
        ag:SetLooping("BOUNCE")
        a:SetFromAlpha(0.25); a:SetToAlpha(0.9); a:SetDuration(0.8)
        ag:Play()
    end
    -- Maj + glisser pour déplacer (hors combat : un bouton protégé ne bouge pas en combat)
    petBtn:SetMovable(true)
    petBtn:RegisterForDrag("LeftButton")
    petBtn:SetScript("OnDragStart", function(s) if IsShiftKeyDown() and not InCombatLockdown() then s:StartMoving() end end)
    petBtn:SetScript("OnDragStop", function(s) s:StopMovingOrSizing(); WK.UI:HUDCapture("petButton") end)
    petBtn:SetScript("OnEnter", function(s)
        WK.UI:TooltipOwner(s, "ANCHOR_TOP")
        GameTooltip:SetText(T("Familier"), 1, 1, 1)
        GameTooltip:AddLine(T("Clic : appeler, ou ressusciter s'il est mort"), 0.85, 0.85, 0.85)
        GameTooltip:AddLine(T("Clic droit : ressusciter"), 0.85, 0.85, 0.85)
        GameTooltip:AddLine(T("Maj + glisser : déplacer"), 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    petBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    if RegisterStateDriver then RegisterStateDriver(petBtn, "visibility", VISIBILITY) end
    self:PaintPetButton()
    WK.UI:RegisterHUD("petButton", petBtn, {
        label = T("Bouton du familier"), protected = true, default = { 0, -180 },
        -- coupé dans ses réglages : absent du mode édition
        enabled = function() return isHunter() and cfg().petButton ~= false and not M:OtherAddonLoaded() end,
        -- aperçu : le bouton montré même avec un familier (le pilote d'état le cache), rendu au retour
        sample = function(on)
            if InCombatLockdown and InCombatLockdown() then return end
            if on then
                if UnregisterStateDriver then UnregisterStateDriver(petBtn, "visibility") end
                M:PaintPetButton()
                petBtn:Show()
            else
                M:SyncPetButton()
            end
        end,
        legacy = function()
            local pos = cfg().petButtonPos -- position des versions précédentes
            if not pos then return false end
            petBtn:ClearAllPoints()
            petBtn:SetPoint(pos[1], UIParent, pos[1], pos[2], pos[3])
            return true
        end,
        -- Le bouton n'apparaît que sans familier : en mode édition, un rond le représente.
        preview = function(box)
            local t = box:CreateTexture(nil, "ARTWORK")
            t:SetTexture(WK.UI.MEDIA .. "circle")
            t:SetPoint("TOPLEFT", 4, -4)
            t:SetPoint("BOTTOMRIGHT", -4, 4)
            t:SetVertexColor(WK.UI.colors.warning[1], WK.UI.colors.warning[2], WK.UI.colors.warning[3], 0.5)
        end,
    })
end

-- Texte et couleurs (non protégés : se mettent à jour même en combat).
function M:PaintPetButton()
    if not petBtn then return end
    local C = WK.UI.colors
    local dead = UnitExists and UnitExists("pet") and UnitIsDead and UnitIsDead("pet")
    local col = dead and C.negative or C.warning
    petBtn.glow:SetVertexColor(col[1], col[2], col[3], 1)
    petBtn.ring:SetVertexColor(col[1], col[2], col[3], 1)
    petBtn.icon:SetTexture(spellIcon(dead and REVIVE_PET or CALL_PET) or "Interface\\Icons\\Ability_Hunter_BeastCall")
    local name = UnitName and UnitName("pet")
    if dead then
        petBtn.label:SetText(string.format(T("%s est mort · clic : ressusciter"), name or T("Le familier")))
    else
        petBtn.label:SetText(T("Familier absent · clic : appeler"))
    end
end

-- Active ou retire le bouton selon le réglage (hors combat seulement).
function M:SyncPetButton()
    if InCombatLockdown and InCombatLockdown() then return end
    local want = isHunter() and cfg().petButton ~= false and not self:OtherAddonLoaded() and (WK.DB:Me().level or 0) >= 10
    if want then
        if not petBtn then self:BuildPetButton() elseif RegisterStateDriver then RegisterStateDriver(petBtn, "visibility", VISIBILITY) end
    elseif petBtn then
        if UnregisterStateDriver then UnregisterStateDriver(petBtn, "visibility") end
        petBtn:Hide()
    end
end

---------------------------------------------------------------------------
-- Évènements
---------------------------------------------------------------------------
function M:OnLogin()
    if not isHunter() then return end
    self:ReadAspect()
    self:SyncPetButton()
    self:UpdateAlerts()
    -- (plus de minuterie de 2 s : les rappels à l'écran sont retirés, UpdateAlerts sortait aussitôt)
end

local function refresh()
    if not isHunter() then return end
    M:ReadAspect()
    M:UpdateAlerts()
    if WK.UI.AspectButtonPaint then WK.UI:AspectButtonPaint() end
end
WK:OnUnit("UNIT_AURA", "player", function() refresh() end)
WK:On("PLAYER_REGEN_ENABLED", function() refresh(); M:SyncPetButton() end)
WK:On("PLAYER_REGEN_DISABLED", function() M:UpdateAlerts() end)
WK:On("PET_BAR_UPDATE", function() M:UpdateAlerts() end)
WK:On("GROUP_ROSTER_UPDATE", function() M:UpdateAlerts() end)
WK:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(1, refresh) end)
WK:On("PLAYER_LEVEL_UP", function() C_Timer.After(1, function() M:SyncPetButton() end) end)
WK:On("UNIT_PET", function(unit) if unit == "player" then M:PaintPetButton(); M:UpdateAlerts() end end)
WK:OnUnit("UNIT_HEALTH", "pet", function() M:PaintPetButton() end)
WK:OnUnit("UNIT_SPELLCAST_SUCCEEDED", "player", function(unit, _, spellID)
    if unit ~= "player" or not isHunter() then return end
    -- En combat, les auras sont masquées : l'aspect lancé devient l'aspect actif.
    local key = aspectNames()[spellName(spellID) or ""]
    if key then M.aspect = key; M:UpdateAlerts(); if WK.UI.AspectButtonPaint then WK.UI:AspectButtonPaint() end end
end)
