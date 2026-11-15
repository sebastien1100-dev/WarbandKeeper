local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Indicateur de distance (chasseur) : un anneau coloré selon la position de la cible.
--   vert : à portée des tirs ; orange : corps à corps ; jaune : zone morte (5 à 8 m, option) ;
--   rouge : trop loin ; gris : pas de cible attaquable.
-- Portée de mêlée et de tir : test du jeu (C_SwingTimer sur WoW Forever), sinon Tir automatique.
-- Zone morte : hors de portée de tir mais à moins de 10 m (distance de duel), quand le jeu le dit.
-- Réglages : WK.modules.QoL:Class("HUNTER").range
local ring
local AUTO_SHOT = 75
local DEFAULTS = { enabled = true, combatOnly = false, deadZone = true, numbers = true, hideNoTarget = false }

local function cfg()
    local cc = WK.modules.QoL:Class("HUNTER")
    cc.range = cc.range or {}
    for k, v in pairs(DEFAULTS) do if cc.range[k] == nil then cc.range[k] = v end end
    return cc.range
end
UI.RangeConfig = cfg

local readable = function(v) return WK.modules.QoL.Readable(v) end
local SWING = (Enum and Enum.PlayerSwingType) or { MainHand = 0, Ranged = 2 }
local armedAt = {}
local function swingRange(kind)
    if not (C_SwingTimer and C_SwingTimer.IsTargetWithinSwingRange) then return nil end
    local ok, res = pcall(C_SwingTimer.IsTargetWithinSwingRange, kind)
    res = ok and readable(res) or nil
    -- le test ne répond qu'une fois activé (et un autre addon peut le couper) : on le réarme
    if res == nil and C_SwingTimer.EnableRangeCheck and GetTime() - (armedAt[kind] or -10) > 2 then
        armedAt[kind] = GetTime()
        pcall(C_SwingTimer.EnableRangeCheck, kind, true)
        ok, res = pcall(C_SwingTimer.IsTargetWithinSwingRange, kind)
        res = ok and readable(res) or nil
    end
    return res
end

local function spellInRange(id)
    if C_Spell and C_Spell.IsSpellInRange then
        local ok, r = pcall(C_Spell.IsSpellInRange, id, "target")
        if ok and readable(r) ~= nil then return r == true or r == 1 end
    end
    if IsSpellInRange then
        local name = WK.SpellInfo(id)
        local r = name and IsSpellInRange(name, "target")
        if r ~= nil then return r == 1 end
    end
    return nil
end

-- État de la cible : "none", "melee", "dead", "ranged", "far"
function UI:RangeState()
    if not UnitExists("target") or UnitIsDead("target") or not UnitCanAttack("player", "target") then return "none" end
    local melee = swingRange(SWING.MainHand)
    if melee then return "melee" end
    local ranged = swingRange(SWING.Ranged)
    if ranged == nil then ranged = spellInRange(AUTO_SHOT) end
    if ranged then return "ranged" end
    -- hors de portée de tir : trop près (zone morte) ou trop loin ?
    local ok, close = pcall(CheckInteractDistance, "target", 3)
    if ok and readable(close) then return "dead" end
    return "far"
end

local LABEL = { melee = "cac", dead = "5-8 m", ranged = "8-35 m", far = "35+ m" }

local function build()
    local f = CreateFrame("Frame", "WarbandKeeperRange", UIParent)
    f:SetSize(64, 64)
    f:SetFrameStrata("MEDIUM")
    f.glow = f:CreateTexture(nil, "BACKGROUND")
    f.glow:SetTexture(UI.MEDIA .. "fxhalo")
    f.glow:SetBlendMode("ADD")
    f.glow:SetPoint("CENTER")
    f.glow:SetSize(96, 96)
    f.disc = UI:Icon(f, "circle", 56, nil, "BORDER")
    f.disc:SetPoint("CENTER")
    f.ring = UI:Icon(f, "ring", 64, nil, "ARTWORK")
    f.ring:SetPoint("CENTER")
    f.cross = UI:Icon(f, "crosshair", 26, nil, "OVERLAY")
    f.cross:SetPoint("CENTER")
    f.text = UI:Text(f, 10)
    f.text:SetPoint("CENTER")
    f.text:SetJustifyH("CENTER")
    f.acc = 0
    f:SetScript("OnUpdate", function(s, el)
        s.acc = s.acc + el
        if s.acc < 0.1 then return end
        s.acc = 0
        if s.sample then return end
        s:Paint(UI:RangeState())
    end)
    function f:Paint(state)
        local o = cfg()
        if state == "dead" and not o.deadZone then state = "melee" end
        -- Sans cible : anneau beige en pointillés avec un viseur au centre, sans texte
        local col = ({ melee = C.warning, dead = { 0.91, 0.83, 0.29, 1 }, ranged = C.positive, far = C.negative })[state]
            or C.muted
        self.ring:SetVertexColor(col[1], col[2], col[3], 1)
        self.glow:SetVertexColor(col[1], col[2], col[3], state == "none" and 0.15 or 0.35)
        self.disc:SetVertexColor(0, 0, 0, state == "none" and 0.65 or 0.35)
        self.text:SetTextColor(col[1], col[2], col[3], 1)
        local none = state == "none"
        self.ring:SetTexture(UI.MEDIA .. (none and "ring_dash" or "ring"))
        self.cross:SetShown(none)
        self.cross:SetVertexColor(col[1], col[2], col[3], 1)
        self.text:SetFont(UI.FONT, 10, "OUTLINE")
        self.text:SetText((o.numbers and not none) and T(LABEL[state]) or "")
        local hide = (o.combatOnly and not (InCombatLockdown and InCombatLockdown()) and not self.sample)
            or (o.hideNoTarget and state == "none" and not self.sample)
        self:SetAlpha(hide and 0 or (UI:HUDEntry("range").alpha or 1))
    end
    f:Hide()
    UI:RegisterHUD("range", f, {
        label = T("Indicateur de distance"), default = { 0, -120 },
        sample = function(on)
            f.sample = on or nil
            if on then f:Show(); f:Paint("ranged") elseif not cfg().enabled then f:Hide() end
        end,
    })
    return f
end

function UI:SyncRange()
    local want = WK.DB:Me().class == "HUNTER" and cfg().enabled
    if want then
        ring = ring or build()
        ring:Show()
    elseif ring then
        ring:Hide()
    end
end

WK:On("PLAYER_LOGIN", function() C_Timer.After(1, function() UI:SyncRange() end) end)
