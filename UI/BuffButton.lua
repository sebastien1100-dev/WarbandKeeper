local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Bouton « Buffer le suivant » (QoL > Classes, onglet « Buffer autour ») : en monde ouvert, le joueur ami le plus
-- proche qui n'a pas ton buff (toi et ton groupe d'abord, puis les plaques de nom des joueurs amis), et le buff qui
-- lui va : Marque du fauve, Robustesse, Intelligence des arcanes ; paladin : Puissance pour guerrier, voleur et
-- chasseur, Sagesse pour les autres, Rois d'abord si tu la connais (réglage). Un bouton protégé du jeu
-- (WarbandKeeperBuffButton, touche dans les raccourcis) : sort et cible posés hors combat seulement, bouton caché
-- en combat. Liseré d'accent sur la plaque de nom du joueur visé. Jamais sur un joueur en combat, ni sur un joueur
-- JcJ quand tu ne l'es pas (ça te mettrait en JcJ). Réglages par classe dans QoL:Class(classe) : buffAround,
-- kingsFirst, buffRefresh (minutes), buffInstance, buffMounted, buffPlates (plaques des amis allumées hors combat).
local BUFFS = {
    DRUID = { cast = 1126, has = { 1126, 21849 } },   -- Marque du fauve (ou Don du fauve)
    PRIEST = { cast = 1243, has = { 1243, 21562 } },  -- Robustesse (ou Prière de robustesse)
    MAGE = { cast = 1459, has = { 1459, 23028 } },    -- Intelligence des arcanes (ou Illumination)
}
local MIGHT, WISDOM, KINGS = { 19740, 25782 }, { 19742, 25894 }, { 20217, 25898 } -- simple, supérieure
local MELEE = { WARRIOR = true, ROGUE = true, HUNTER = true }
WK.BUFF_CLASSES = { DRUID = true, PRIEST = true, MAGE = true, PALADIN = true }

local function myClass() return select(2, UnitClass("player")) end
local function inCombat() return InCombatLockdown and InCombatLockdown() or false end
local function cfg() local c = myClass(); return c and WK.modules.QoL:Class(c) end
local function known(id)
    local k = (IsPlayerSpell and IsPlayerSpell(id)) or (IsSpellKnown and IsSpellKnown(id))
    return k ~= false and WK.SpellInfo(id) ~= nil
end
local function spellIcon(id)
    return (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)) or (GetSpellTexture and GetSpellTexture(id))
end

-- Buff prévu pour une unité : n° du sort à lancer, n° qui le valent
local function buffFor(unit)
    local class = myClass()
    if class == "PALADIN" then
        local c = cfg() or {}
        if c.kingsFirst ~= false and known(KINGS[1]) then return KINGS[1], KINGS end
        local _, tc = UnitClass(unit)
        local set = MELEE[tc or ""] and MIGHT or WISDOM
        if known(set[1]) then return set[1], set end
        if known(MIGHT[1]) then return MIGHT[1], MIGHT end
        return nil
    end
    local b = BUFFS[class or ""]
    if b and known(b.cast) then return b.cast, b.has end
end

-- Temps restant (secondes, 0 = sans fin) du premier de ces sorts sur l'unité, nil s'il n'y est pas
local function auraLeft(unit, ids)
    local names = {}
    for _, id in ipairs(ids) do local n = WK.SpellInfo(id); if n then names[n] = true end end
    for i = 1, 40 do
        local name, exp
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local d = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
            if not d then break end
            name, exp = d.name, d.expirationTime
        elseif UnitBuff then
            local n, _, _, _, _, e = UnitBuff(unit, i)
            if not n then break end
            name, exp = n, e
        else break end
        if name and names[name] then
            if not exp or exp == 0 then return 0 end
            return math.max(0, exp - GetTime())
        end
    end
    return nil
end

local function inRange(spell, unit)
    if UnitIsUnit and UnitIsUnit(unit, "player") then return true end
    local r
    if C_Spell and C_Spell.IsSpellInRange then r = C_Spell.IsSpellInRange(spell, unit)
    elseif IsSpellInRange then r = IsSpellInRange(spell, unit) end
    if r == true or r == 1 then return true end
    if r == false or r == 0 then return false end
    return CheckInteractDistance and CheckInteractDistance(unit, 4) and true or false
end

-- Joueurs à buffer, dans l'ordre : toi, ton groupe, puis les plaques de nom des joueurs amis
local function candidates()
    local c = cfg() or {}
    local units, seen, out = { "player" }, {}, {}
    if IsInGroup and IsInGroup() and not (IsInRaid and IsInRaid()) then
        for i = 1, 4 do table.insert(units, "party" .. i) end
    end
    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
            if plate.namePlateUnitToken then table.insert(units, plate.namePlateUnitToken) end
        end
    end
    local refresh = (c.buffRefresh or 3) * 60
    local mePvp = UnitIsPVP and UnitIsPVP("player")
    for _, u in ipairs(units) do
        local guid = UnitExists(u) and UnitGUID(u)
        if guid and not seen[guid] and UnitIsPlayer(u) and UnitCanAssist("player", u) and not UnitIsDeadOrGhost(u)
            and UnitIsConnected(u) and (u == "player" or not UnitAffectingCombat(u))
            and (mePvp or not (UnitIsPVP and UnitIsPVP(u))) then
            seen[guid] = true
            local id, has = buffFor(u)
            local name = id and WK.SpellInfo(id)
            if name then
                local left = auraLeft(u, has)
                if (not left or (left > 0 and left < refresh)) and inRange(name, u) then
                    table.insert(out, { unit = u, id = id, spell = name, who = UnitName(u), class = select(2, UnitClass(u)) })
                end
            end
        end
    end
    return out
end

---------------------------------------------------------------------------
-- Bouton
---------------------------------------------------------------------------
local btn, mark, list
local SIZE = 48
local function build()
    btn = CreateFrame("Button", "WarbandKeeperBuffButton", UIParent, "SecureActionButtonTemplate")
    btn:SetSize(SIZE, SIZE)
    btn:SetFrameStrata("MEDIUM")
    btn:SetClampedToScreen(true)
    if btn.RegisterForClicks then btn:RegisterForClicks("AnyUp", "AnyDown") end
    btn:SetAttribute("type", "spell")
    btn.edge = UI:Rounded(btn, 11, 0, "BACKGROUND", 1)
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("TOPLEFT", 3, -3); btn.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.hl = btn:CreateTexture(nil, "HIGHLIGHT"); btn.hl:SetAllPoints(btn.icon); btn.hl:SetColorTexture(1, 1, 1, 0.15)
    btn.pill = CreateFrame("Frame", nil, btn)
    btn.pill:SetSize(20, 16); btn.pill:SetPoint("CENTER", btn, "TOPRIGHT", -3, -3)
    btn.pill:SetFrameLevel(btn:GetFrameLevel() + 3)
    btn.pill.bg = UI:Rounded(btn.pill, 8, 0, "BACKGROUND", 1)
    btn.pill.t = UI:Text(btn.pill, 10, C.onAccent); btn.pill.t:SetPoint("CENTER")
    btn:SetScript("OnEnter", function(s)
        local l = list or {}
        local e = l[1]
        UI:TooltipOwner(s, "ANCHOR_TOP")
        if not e then GameTooltip:SetText(T("Buffer autour"), 1, 1, 1); GameTooltip:Show() return end
        GameTooltip:SetText(e.spell, 1, 1, 1)
        local cr, cg, cb = UI:ClassColor(e.class)
        GameTooltip:AddLine(string.format(T("sur %s"), e.who or "?"), cr, cg, cb)
        if #l > 1 then
            local nxt = {}
            for i = 2, math.min(4, #l) do table.insert(nxt, (l[i].who or "?") .. " (" .. l[i].spell .. ")") end
            GameTooltip:AddLine(T("Ensuite") .. " : " .. table.concat(nxt, ", "), 0.7, 0.7, 0.7, true)
        end
        GameTooltip:AddLine(T("Clic ou touche : lancer"), 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:HookScript("PostClick", function() C_Timer.After(0.4, function() UI:RefreshBuffButton() end) end)
    -- liseré sur la plaque de nom du joueur visé
    mark = CreateFrame("Frame", nil, UIParent)
    mark:SetFrameStrata("LOW")
    mark.edges = {}
    for i = 1, 4 do mark.edges[i] = mark:CreateTexture(nil, "OVERLAY") end
    mark.edges[1]:SetPoint("TOPLEFT"); mark.edges[1]:SetPoint("TOPRIGHT"); mark.edges[1]:SetHeight(2)
    mark.edges[2]:SetPoint("BOTTOMLEFT"); mark.edges[2]:SetPoint("BOTTOMRIGHT"); mark.edges[2]:SetHeight(2)
    mark.edges[3]:SetPoint("TOPLEFT"); mark.edges[3]:SetPoint("BOTTOMLEFT"); mark.edges[3]:SetWidth(2)
    mark.edges[4]:SetPoint("TOPRIGHT"); mark.edges[4]:SetPoint("BOTTOMRIGHT"); mark.edges[4]:SetWidth(2)
    mark:Hide()
    local function paint(icon, n)
        local r, g, b = UI:Accent()
        btn.edge:SetColor(r, g, b, 1)
        btn.pill.bg:SetColor(r, g, b, 1)
        btn.icon:SetTexture(icon or "Interface\\Icons\\Spell_Nature_Regeneration")
        btn.pill.t:SetText(n or "")
        btn.pill:SetShown((n or 0) > 0)
        btn.pill:SetWidth(math.max(16, btn.pill.t:GetStringWidth() + 10))
    end
    btn.paint = paint
    UI:RegisterHUD("buffButton", btn, {
        label = T("Buffer autour"), default = { 220, -140 },
        enabled = function() local c = cfg(); return WK.BUFF_CLASSES[myClass() or ""] and c and c.buffAround ~= false and WK:FeatureOn("classes") end,
        sample = function(on)
            btn.sample = on
            if on then
                local id = buffFor("player") or (BUFFS[myClass() or ""] or {}).cast or 1126
                paint(spellIcon(id), 3)
                if not inCombat() then btn:Show() end
            else UI:RefreshBuffButton() end
        end,
    })
    btn:Hide()
end

local function shouldShow()
    local c = cfg()
    if not (c and WK.BUFF_CLASSES[myClass() or ""] and c.buffAround ~= false and WK:FeatureOn("classes")) then return false end
    if UnitIsDeadOrGhost("player") or (UnitOnTaxi and UnitOnTaxi("player")) then return false end
    local inInst = IsInInstance and select(1, IsInInstance())
    if inInst and not c.buffInstance then return false end
    if IsMounted and IsMounted() and not c.buffMounted then return false end
    return true
end

function UI:RefreshBuffButton()
    if not btn then
        if not WK.BUFF_CLASSES[myClass() or ""] then return end
        build()
    end
    if btn.sample or inCombat() then return end
    list = shouldShow() and candidates() or {}
    local e = list[1]
    if e then
        btn:SetAttribute("spell", e.spell)
        btn:SetAttribute("unit", e.unit)
        btn.paint(spellIcon(e.id), #list)
        btn:Show()
        local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(e.unit)
        if plate and not UnitIsUnit(e.unit, "player") then
            local r, g, b = UI:Accent()
            for _, t in ipairs(mark.edges) do t:SetColorTexture(r, g, b, 0.95) end
            mark:ClearAllPoints()
            mark:SetPoint("TOPLEFT", plate, "TOPLEFT", -2, 2); mark:SetPoint("BOTTOMRIGHT", plate, "BOTTOMRIGHT", 2, -2)
            mark:Show()
        else mark:Hide() end
    else
        btn:Hide(); mark:Hide()
    end
end

-- Plaques de nom des joueurs amis : allumées hors combat quand le bouton sert (valeur d'avant rendue sinon)
function UI:SyncBuffPlates()
    local c = cfg()
    if inCombat() or not (GetCVar and SetCVar) then return end
    local want = c and WK.BUFF_CLASSES[myClass() or ""] and c.buffAround ~= false and c.buffPlates ~= false and WK:FeatureOn("classes")
    local g = WK.DB.global
    if want then
        if GetCVar("nameplateShowFriends") ~= "1" then
            g.buffPlatesOld = GetCVar("nameplateShowFriends")
            pcall(SetCVar, "nameplateShowFriends", "1")
        end
    elseif g.buffPlatesOld then
        pcall(SetCVar, "nameplateShowFriends", g.buffPlatesOld)
        g.buffPlatesOld = nil
    end
end

-- juste avant le combat (encore permis) : bouton et liseré cachés
WK:On("PLAYER_REGEN_DISABLED", function() if btn and not btn.sample then btn:Hide(); mark:Hide() end end)
WK:On("PLAYER_REGEN_ENABLED", function() C_Timer.After(0.5, function() UI:RefreshBuffButton() end) end)
WK:On("PLAYER_LOGIN", function()
    if not WK.BUFF_CLASSES[myClass() or ""] then return end
    C_Timer.After(3, function()
        UI:SyncBuffPlates()
        UI:RefreshBuffButton()
        if C_Timer.NewTicker then C_Timer.NewTicker(1, function() if not inCombat() then UI:RefreshBuffButton() end end) end
    end)
end)

BINDING_HEADER_WARBANDKEEPER = "Warband Keeper"
_G["BINDING_NAME_CLICK WarbandKeeperBuffButton:LeftButton"] = T("Buffer le suivant")
