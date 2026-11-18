local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Indicateur de distance (chasseur) : une règle compacte aux quatre zones, avec un curseur.
--   orange : corps à corps ; jaune : zone morte (5 à 8 m, option) ; vert : à portée des tirs ;
--   rouge : trop loin ; règle estompée : pas de cible attaquable.
-- Portée de mêlée et de tir : test du jeu (C_SwingTimer sur WoW Forever), sinon Tir automatique.
-- Zone morte : hors de portée de tir mais à moins de 10 m (distance de duel), quand le jeu le dit.
-- Réglages : WK.modules.QoL:Class("HUNTER").range
local ring
local AUTO_SHOT = 75
local DEFAULTS = { enabled = true, combatOnly = false, deadZone = true, numbers = true, hideNoTarget = false, width = 150, backdrop = true }

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

-- Fourchette de distance estimée (bibliothèque LibRangeCheck-3.0, licence MIT) : elle teste la
-- portée de sorts et d'objets connus et rend « entre min et max ». nil si elle ne sait pas.
local rc = LibStub and LibStub("LibRangeCheck-3.0", true)
local function estimate()
    if not rc then return nil end
    local ok, a, b = pcall(rc.GetRange, rc, "target")
    if not ok then return nil end
    a, b = readable(a), readable(b)
    return type(a) == "number" and a or nil, type(b) == "number" and b or nil
end

-- État de la cible : "none", "melee", "dead", "ranged", "far", "unknown" ; puis la fourchette.
function UI:RangeState()
    if not UnitExists("target") or UnitIsDead("target") or not UnitCanAttack("player", "target") then return "none" end
    local minR, maxR = estimate()
    local melee = swingRange(SWING.MainHand)
    if melee == nil and maxR then melee = maxR <= 5 end -- pas de test de mêlée : d'après la distance
    local ranged = swingRange(SWING.Ranged)
    if ranged == nil then ranged = spellInRange(AUTO_SHOT) end
    if melee then return "melee", minR, maxR end
    if ranged then return "ranged", minR, maxR end
    -- zone morte : plus au corps à corps, pas encore à portée de tir (entre 5 et 8 m)
    if (maxR and maxR <= 8) or (minR and minR < 8 and ranged == false) then return "dead", minR, maxR end
    if ranged == false then
        if not minR then -- sans estimation : le test de proximité du jeu (moins de 10 m)
            local ok, close = pcall(CheckInteractDistance, "target", 3)
            if ok and readable(close) then return "dead" end
        end
        return "far", minR, maxR
    end
    if minR and minR >= 35 then return "far", minR, maxR end
    return "unknown", minR, maxR
end

local LABEL = { none = "Sans cible", unknown = "Distance inconnue", melee = "Corps à corps", dead = "Zone morte",
                ranged = "À portée", far = "Trop loin" }
-- Zones de la règle, en mètres : corps à corps, zone morte, tir, trop loin
local ZONES = { { "melee", 0, 5 }, { "dead", 5, 8 }, { "ranged", 8, 35 }, { "far", 35, 41 } }
local SPAN = 41
local MID = { melee = 2.5, dead = 6.5, ranged = 21, far = 39 } -- place du curseur sans estimation
local function zoneColor(state)
    -- zone morte : jaune doré du thème
    return ({ melee = C.warning, dead = C.gold, ranged = C.positive, far = C.negative })[state] or C.muted
end

-- Règle compacte : une ligne de texte (zone · fourchette) et une barre aux quatre zones, avec un
-- curseur blanc à la distance de la cible.
local PADX, BAR_H = 8, 5
local function build()
    local f = CreateFrame("Frame", "WarbandKeeperRange", UIParent)
    f:SetSize(150, 30)
    f:SetFrameStrata("MEDIUM")
    UI:Panel(f, 8, { C.bg[1], C.bg[2], C.bg[3], 0.85 }, C.border)
    f.text = UI:Text(f, 10)
    f.text:SetPoint("TOP", 0, -5)
    f.text:SetJustifyH("CENTER")
    f.bar = CreateFrame("Frame", nil, f)
    f.bar:SetHeight(BAR_H)
    f.bar:SetPoint("BOTTOMLEFT", PADX, 6)
    f.bar:SetPoint("BOTTOMRIGHT", -PADX, 6)
    f.segs = {}
    for i, z in ipairs(ZONES) do
        local t = f.bar:CreateTexture(nil, "ARTWORK")
        t:SetPoint("TOP"); t:SetPoint("BOTTOM")
        f.segs[i] = t
    end
    f.cursor = f.bar:CreateTexture(nil, "OVERLAY")
    f.cursor:SetSize(3, BAR_H + 8)
    f.cursor:SetColorTexture(1, 1, 1, 1)
    f.acc = 0
    f:SetScript("OnUpdate", function(s, el)
        s.acc = s.acc + el
        if s.acc < 0.1 then return end
        s.acc = 0
        if s.sample then return end
        s:Paint(UI:RangeState())
    end)
    function f:Paint(state, minR, maxR)
        local o = cfg()
        local w = math.max(90, math.min(320, o.width or 150))
        if math.abs((self:GetWidth() or 0) - w) > 0.5 then self:SetWidth(w) end
        self:SetHeight(o.numbers and 30 or 17)
        self.bg:SetShown(o.backdrop ~= false)
        if self.border then self.border:SetShown(o.backdrop ~= false) end
        local none = state == "none"
        local shown = (state == "dead" and not o.deadZone) and "melee" or state
        -- zones : la zone morte prend la couleur du corps à corps si l'option est décochée
        local bw = w - PADX * 2
        for i, z in ipairs(ZONES) do
            local t = self.segs[i]
            local col = zoneColor((z[1] == "dead" and not o.deadZone) and "melee" or z[1])
            local x0, x1 = bw * z[2] / SPAN, bw * z[3] / SPAN
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", self.bar, "TOPLEFT", x0 + (i > 1 and 1 or 0), 0)
            t:SetPoint("BOTTOMLEFT", self.bar, "BOTTOMLEFT", x0 + (i > 1 and 1 or 0), 0)
            t:SetWidth(math.max(1, x1 - x0 - (i > 1 and 1 or 0)))
            local active = (z[1] == state) or (state == "dead" and z[1] == "dead")
            t:SetColorTexture(col[1], col[2], col[3], none and 0.3 or ((active or state == "unknown") and 1 or 0.45))
        end
        -- curseur : milieu de la fourchette estimée, sinon milieu de la zone
        local pos
        if not none then
            if minR and maxR then pos = (minR + maxR) / 2
            elseif minR then pos = minR + 2
            else pos = MID[state] end
            -- le curseur reste dans la zone que le jeu annonce
            for _, z in ipairs(ZONES) do
                if z[1] == state and pos then pos = math.max(z[2] + 0.3, math.min(z[3] - 0.3, pos)) end
            end
        end
        self.cursor:SetShown(pos ~= nil)
        if pos then
            self.cursor:ClearAllPoints()
            self.cursor:SetPoint("CENTER", self.bar, "LEFT", bw * math.max(0, math.min(SPAN, pos)) / SPAN, 0)
        end
        -- texte : la zone à sa couleur, puis la fourchette
        local col = zoneColor(shown)
        local label = T(LABEL[shown] or "?")
        local range
        if not none then
            if minR and maxR then range = string.format("%d-%d m", minR, maxR)
            elseif minR then range = string.format("%d+ m", minR)
            elseif state == "melee" then range = "0-5 m" elseif state == "dead" then range = "5-8 m" end
        end
        self.text:SetShown(o.numbers and true or false)
        self.text:SetText(UI:Hex(col) .. label .. "|r" .. (range and (" · " .. range) or ""))
        self.text:SetTextColor(unpack(C.text))
        local hide = (o.combatOnly and not (InCombatLockdown and InCombatLockdown()) and not self.sample)
            or (o.hideNoTarget and none and not self.sample)
        self:SetAlpha(hide and 0 or (UI:HUDEntry("range").alpha or 1))
    end
    f:Hide()
    UI:RegisterHUD("range", f, {
        label = T("Indicateur de distance"), default = { 0, -120 },
        -- réglage coupé : absent du mode édition
        enabled = function() return UI:RangeWanted() end,
        sample = function(on)
            f.sample = on or nil
            if on then f:Show(); f:Paint("ranged", 22, 25) else UI:SyncRange() end
        end,
    })
    return f
end

function UI:RangeWanted()
    return WK.DB:Me().class == "HUNTER" and cfg().enabled and WK:FeatureOn("range") and true or false
end

function UI:SyncRange()
    local want = self:RangeWanted()
    if want then
        ring = ring or build()
        if not ring.sample then ring:Show() end
    elseif ring then
        ring:Hide()
    end
end

WK:On("PLAYER_LOGIN", function() C_Timer.After(1, function() UI:SyncRange() end) end)
