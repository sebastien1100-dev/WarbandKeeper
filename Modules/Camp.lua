local ADDON_NAME, WK = ...
local M = WK:NewModule("Camp")
local T = function(s) return WK.T(s) end

-- Feux de camp de WoW Forever, en trois temps :
--   1. près d'un camp : effet de flamme (« Flammes pourpres »… : « augmente la durée des effets de feu de camp ») ;
--   2. assis 1 min : « Feu de camp accueillant » (compte à rebours) ;
--   3. ensuite : « Avantages du camp » pendant 2 h (selon les objets posés autour : bocal à poisson…).
-- Repérés par leur nom ou leur description (plusieurs flammes possibles) ; les n° vus sont retenus
-- (WK.DB.global.camp.seen) pour connaître les variantes. Réglages : QoL:Config().camp.
-- État (M.state) : "none" (pas de camp), "sit" (assieds-toi), "sitting" (assis, compte à rebours),
-- "done" (avantages actifs), "early" (relevé trop tôt). Affichage : UI/CampCard.lua.
local DEFAULTS = { enabled = true, renewAt = 10 } -- minutes restantes sous lesquelles on propose de renouveler

local FLAME = { "flammes pourpres" }
local SIT = { "feu de camp accueillant", "cozy campfire", "welcoming campfire" }
local PERK = { "avantages du camp", "camp benefits" }

function M:Config()
    local q = WK.modules.QoL:Config()
    q.camp = q.camp or {}
    for k, v in pairs(DEFAULTS) do if q.camp[k] == nil then q.camp[k] = v end end
    return q.camp
end
local function seen()
    local g = WK.DB.global
    g.camp = g.camp or {}
    g.camp.seen = g.camp.seen or {}
    return g.camp.seen
end

local function readable(v)
    local Q = WK.modules.QoL
    return Q and Q.Readable and Q.Readable(v) or v
end
local function has(list, s)
    for _, n in ipairs(list) do if s:find(n, 1, true) then return true end end
    return false
end
local descCache = {}
local function desc(spellId)
    if not spellId then return "" end
    local d = descCache[spellId]
    if d == nil then
        d = ""
        if C_Spell and C_Spell.GetSpellDescription then
            local ok, v = pcall(C_Spell.GetSpellDescription, spellId)
            if ok and type(v) == "string" then d = v:lower() end
        elseif GetSpellDescription then
            local ok, v = pcall(GetSpellDescription, spellId)
            if ok and type(v) == "string" then d = v:lower() end
        end
        descCache[spellId] = d
    end
    return d
end

-- Effets du joueur liés au camp : { flame, sit, perk } = { name, icon, expires, duration, spellId, instance }
local function scan()
    local out = {}
    local function consider(name, icon, duration, expires, spellId, instance)
        name, spellId = readable(name), readable(spellId)
        if type(name) ~= "string" then return end
        local n = name:lower()
        local d = desc(type(spellId) == "number" and spellId or nil)
        local kind
        if has(PERK, n) or d:find("avantages de camp suivants", 1, true) then kind = "perk"
        elseif has(SIT, n) or (d:find("avantages de camp", 1, true) and d:find("près du feu", 1, true)) then kind = "sit"
        elseif has(FLAME, n) or (d:find("feu de camp", 1, true) and (n:find("flamme", 1, true) or d:find("flamme", 1, true))) then kind = "flame" end
        if kind then
            out[kind] = { name = name, icon = readable(icon), duration = readable(duration), expires = readable(expires), spellId = spellId, instance = instance }
            if type(spellId) == "number" then seen()[spellId] = kind end
        end
    end
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 40 do
            local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
            if not ok or not a then break end
            consider(a.name, a.icon, a.duration, a.expirationTime, a.spellId, a.auraInstanceID)
        end
    elseif UnitBuff then
        for i = 1, 40 do
            local name, icon, _, _, duration, expires, _, _, _, spellId = UnitBuff("player", i)
            if not name then break end
            consider(name, icon, duration, expires, spellId)
        end
    end
    return out
end

-- Texte des avantages (lignes de l'infobulle de l'effet, sans la première phrase)
function M:PerkText()
    local p = self.auras and self.auras.perk
    if not (p and p.instance and C_TooltipInfo and C_TooltipInfo.GetUnitBuffByAuraInstanceID) then return nil end
    local ok, data = pcall(C_TooltipInfo.GetUnitBuffByAuraInstanceID, "player", p.instance)
    if not ok or not data or not data.lines then return nil end
    local parts = {}
    for i, l in ipairs(data.lines) do
        local t = readable(l.leftText)
        if i > 1 and type(t) == "string" and t ~= "" and not t:lower():find("obtention des avantages", 1, true)
            and not t:find("restantes?$") then
            table.insert(parts, t)
        end
    end
    return #parts > 0 and table.concat(parts, "\n") or nil
end

local function remaining(a) return a and type(a.expires) == "number" and a.expires > 0 and (a.expires - GetTime()) or nil end
M.Remaining = remaining

local wasSitting = false
function M:Update()
    local cfg = self:Config()
    local a = scan()
    self.auras = a
    local state = "none"
    if cfg.enabled and WK:FeatureOn("qolgeneral") then
        local perkLeft = remaining(a.perk)
        if a.sit then
            state = "sitting"
        elseif a.flame then
            if a.perk and (not perkLeft or perkLeft > (cfg.renewAt or 10) * 60) then
                state = "done"
            elseif wasSitting and not a.perk then
                state = "early"
            else
                state = "sit"
            end
        elseif a.perk and self.state == "sitting" then
            state = "done" -- vient de l'obtenir et s'éloigne : on le dit une fois
        end
    end
    if a.sit then wasSitting = true elseif a.perk or not a.flame then wasSitting = false end
    local changed = state ~= self.state
    self.state = state
    if self.OnChange then self:OnChange(changed) end
end

-- S'asseoir (hors combat)
function M:Sit()
    if InCombatLockdown and InCombatLockdown() then return end
    if DoEmote then pcall(DoEmote, "SIT") end
end

local pending = false
WK:On("UNIT_AURA", function(unit)
    if unit ~= "player" or pending then return end
    pending = true
    C_Timer.After(0.2, function() pending = false; M:Update() end)
end)
WK:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(2, function() M:Update() end) end)
