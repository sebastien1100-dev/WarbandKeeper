local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Curseur : anneau autour de la souris (retrouver le curseur d'un coup d'œil, temps global et
-- incantation en balayage, rouge quand la cible est hors de portée) et curseur gardé dans la
-- fenêtre du jeu pendant les combats (réglage ClipCursor du jeu, rendu à la sortie du combat).
-- Réglages : WK.modules.QoL:Config().cursor ; section « Curseur » de QoL.
local DEFAULTS = {
    ring = false, combatOnly = false, size = 56, alpha = 0.85, sweep = true, range = true,
    fadeIdle = true, hideMouselook = true, clip = false,
}
local GCD_SPELL = 61304
-- portée retenue pour « hors de portée » : mêlée pour les classes au contact, sinon distance des sorts
local MELEE = { WARRIOR = true, ROGUE = true, PALADIN = true, DRUID = false }
local readable = function(v) return WK.modules.QoL.Readable(v) end

local function cfg()
    local q = WK.modules.QoL:Config()
    q.cursor = q.cursor or {}
    for k, v in pairs(DEFAULTS) do if q.cursor[k] == nil then q.cursor[k] = v end end
    return q.cursor
end
UI.CursorConfig = cfg

local function on() return WK:FeatureOn("cursor") end
local function inCombat() return InCombatLockdown and InCombatLockdown() or false end

---------------------------------------------------------------------------
-- Anneau
---------------------------------------------------------------------------
local ring
local rc = LibStub and LibStub("LibRangeCheck-3.0", true)

local function rangeLimit()
    local _, class = UnitClass("player")
    if class == "HUNTER" then return 35 end
    if MELEE[class] then return 5 end
    return 30
end

-- true : cible attaquable hors de portée ; false : à portée ; nil : pas de cible ou inconnu
local function outOfRange()
    if not (rc and UnitExists("target") and UnitCanAttack("player", "target")) then return nil end
    if UnitIsDeadOrGhost("target") then return nil end
    local ok, lo = pcall(rc.GetRange, rc, "target")
    lo = ok and readable(lo) or nil
    if type(lo) ~= "number" then return nil end
    return lo >= rangeLimit()
end

local function paint()
    if not ring then return end
    local c = cfg()
    local r, g, b = UI:Accent()
    if c.range and ring.far then r, g, b = C.negative[1], C.negative[2], C.negative[3] end -- hors de portée
    ring.tex:SetVertexColor(r, g, b, 1)
    ring.cd:SetSwipeColor(r, g, b, 0.9)
end

local function setSize()
    local s = cfg().size or 56
    ring:SetSize(s, s)
end

local function build()
    if ring then return ring end
    ring = CreateFrame("Frame", "WarbandKeeperCursorRing", UIParent)
    ring:SetFrameStrata("TOOLTIP")
    ring:SetFrameLevel(50)
    ring:EnableMouse(false)
    ring.tex = ring:CreateTexture(nil, "ARTWORK")
    ring.tex:SetAllPoints()
    ring.tex:SetTexture(UI.MEDIA .. "ring")
    -- balayage (temps global, incantation) posé sur l'anneau
    ring.cd = CreateFrame("Cooldown", nil, ring, "CooldownFrameTemplate")
    ring.cd:SetPoint("TOPLEFT", -3, 3)
    ring.cd:SetPoint("BOTTOMRIGHT", 3, -3)
    ring.cd:EnableMouse(false)
    if ring.cd.SetSwipeTexture then ring.cd:SetSwipeTexture(UI.MEDIA .. "ring") end
    if ring.cd.SetDrawEdge then ring.cd:SetDrawEdge(false) end
    if ring.cd.SetDrawBling then ring.cd:SetDrawBling(false) end
    if ring.cd.SetHideCountdownNumbers then ring.cd:SetHideCountdownNumbers(true) end
    if ring.cd.SetUseCircularEdge then ring.cd:SetUseCircularEdge(true) end
    if ring.cd.SetReverse then ring.cd:SetReverse(true) end
    setSize()
    paint()
    UI:OnAccent(paint)

    local lastX, lastY, still, tick = 0, 0, 0, 0
    ring:SetScript("OnUpdate", function(self, el)
        local c = cfg()
        local x, y = GetCursorPosition()
        local sc = UIParent:GetEffectiveScale()
        if x ~= lastX or y ~= lastY then still = 0; lastX, lastY = x, y else still = still + el end
        local hide = c.hideMouselook and ((IsMouselooking and IsMouselooking()) or (IsMouseButtonDown and IsMouseButtonDown("RightButton")))
        self.tex:SetShown(not hide)
        self.cd:SetShown(not hide and c.sweep)
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / sc, y / sc)
        local a = c.alpha or 0.85
        if c.fadeIdle and still > 3 and not inCombat() then a = a * 0.25 end
        self:SetAlpha(a)
        tick = tick + el
        if tick > 0.2 then
            tick = 0
            local far = outOfRange() == true
            if far ~= self.far then self.far = far; paint() end
        end
    end)
    return ring
end

local function sweepCast()
    if not ring then return false end
    for _, fn in ipairs({ UnitCastingInfo, UnitChannelInfo }) do
        if fn then
            local ok, name, _, _, startMS, endMS = pcall(fn, "player")
            if ok and name then
                local ok2 = pcall(function()
                    ring.cd:SetCooldown(startMS / 1000, (endMS - startMS) / 1000)
                end)
                if ok2 then return true end
            end
        end
    end
    return false
end

local function sweepGCD()
    if not ring or sweepCast() then return end
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, info = pcall(C_Spell.GetSpellCooldown, GCD_SPELL)
        if ok and type(info) == "table" then
            pcall(ring.cd.SetCooldown, ring.cd, info.startTime, info.duration)
            return
        end
    end
    if GetSpellCooldown then
        local ok, s, d = pcall(GetSpellCooldown, GCD_SPELL)
        if ok and s then pcall(ring.cd.SetCooldown, ring.cd, s, d) end
    end
end

-- combat : à PLAYER_REGEN_DISABLED, InCombatLockdown() est encore faux ; l'évènement passe l'état voulu
function UI:SyncCursorRing(combat)
    local c = cfg()
    if combat == nil then combat = inCombat() or (UnitAffectingCombat and UnitAffectingCombat("player")) end
    local want = on() and c.ring and (not c.combatOnly or combat)
    if want then
        build()
        setSize()
        paint()
        ring:Show()
    elseif ring then
        ring:Hide()
    end
end

WK:On("PLAYER_ENTERING_WORLD", function() UI:SyncCursorRing() end)
WK:On("PLAYER_REGEN_DISABLED", function() UI:SyncCursorRing(true) end)
WK:On("PLAYER_REGEN_ENABLED", function() UI:SyncCursorRing(false) end)
WK:On("SPELL_UPDATE_COOLDOWN", function()
    if ring and ring:IsShown() and cfg().sweep then sweepGCD() end
end)
for _, ev in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_UPDATE" }) do
    WK:On(ev, function(unit)
        if unit == "player" and ring and ring:IsShown() and cfg().sweep then sweepCast() end
    end)
end
for _, ev in ipairs({ "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED" }) do
    WK:On(ev, function(unit)
        if unit == "player" and ring and ring.cd then ring.cd:Clear() end
    end)
end

---------------------------------------------------------------------------
-- Curseur gardé dans la fenêtre pendant les combats (réglage ClipCursor du jeu)
---------------------------------------------------------------------------
local function getCVar(name)
    if C_CVar and C_CVar.GetCVar then
        local ok, v = pcall(C_CVar.GetCVar, name)
        if ok then return v end
    end
    if GetCVar then
        local ok, v = pcall(GetCVar, name)
        if ok then return v end
    end
end
local function setCVar(name, v)
    if C_CVar and C_CVar.SetCVar then return pcall(C_CVar.SetCVar, name, v) end
    if SetCVar then return pcall(SetCVar, name, v) end
end
function UI:CursorClipSupported() return getCVar("ClipCursor") ~= nil end

local function clipStore()
    local g = WK.DB.global
    g.cursorClip = g.cursorClip or {}
    return g.cursorClip
end
local function restoreClip()
    local s = clipStore()
    if s.saved ~= nil then
        setCVar("ClipCursor", s.saved)
        s.saved = nil
    end
end
WK:On("PLAYER_REGEN_DISABLED", function()
    if not (on() and cfg().clip) then return end
    local cur = getCVar("ClipCursor")
    if cur == nil or cur == "1" then return end
    clipStore().saved = cur
    setCVar("ClipCursor", "1")
end)
WK:On("PLAYER_REGEN_ENABLED", restoreClip)
-- partie en plein combat (déconnexion, crash) : réglage rendu à la connexion suivante
WK:On("PLAYER_ENTERING_WORLD", function()
    if not inCombat() then restoreClip() end
end)
function UI:CursorClipOff()
    if not inCombat() then restoreClip() end
end
