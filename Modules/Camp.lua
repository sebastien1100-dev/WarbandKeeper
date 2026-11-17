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
-- Objets de camp par métier (bêta de WoW Forever, d'après les infobulles relevées par les joueurs ; à
-- vérifier en jeu). Paliers de compétence 20 / 140 / 300 (les objets 140 et 300 demandent un plan).
-- { métier, { objet 20, effet, ne se cumule pas avec }, objet 140, objet 300 }
M.ITEMS = {
    { "Forge", { "Meule à aiguiser", "Force (selon le niveau)", "Totem de Force de la Terre" }, "Enclume", "Forge magistrale" },
    { "Couture", { "Bannière de faction", "Esprit", "Esprit divin" }, "Atelier de couture", "Atelier de couture avancé" },
    { "Herboristerie", { "Bougie d'encens", "Intelligence", "Intelligence des arcanes" }, "Serre", "Hybrideur de graines" },
    { "Alchimie", { "Puits de mana", "Régénération de mana", "Bénédiction de sagesse" }, "Fermenteur", "Laboratoire d'alchimie" },
    { "Travail du cuir", { "Tente de campement", "Repos porté à 5 % d'un niveau", nil }, "Chevalet de tannage", "Machine à coudre" },
    { "Dépeçage", { "Chaise de campement", "Coup critique +2 %", "Aura de sélénien" }, "Guide de terrain", "Établi du trappeur" },
    { "Ingénierie", { "Robot de composants", "Vendeur de composants", nil }, "Robot réparateur", "Établi de l'anarchiste" },
    { "Enchantement", { "Luth enchanté", "Armure, caractéristiques, résistances", "Marque du fauve" }, "Récupérateur arcanique", "Forge arcanique" },
    { "Minage", { "Magnétite", "Puissance d'attaque en mêlée", "Bénédiction de puissance" }, "Jardin de pierres", "Fonderie en fusion" },
    { "Secourisme", { "Trousse de premiers secours", "Endurance", "Mot de pouvoir : Robustesse" }, "Étude des toxines", "Laboratoire du médecin de peste" },
    { "Pêche", { "Bocal à poisson", "Toutes les caractéristiques", "Bénédiction des rois" }, "Râtelier de pêche", "Cabane de pêche" },
}
-- Feux de camp (Cuisine) : { nom, compétence, objets en plus, bois }
M.FIRES = {
    { "Kit de feu de camp basique", 1, 3, "1 bois simple + silex avec amadou (outil)" },
    { "Kit de feu de camp de compagnon", 90, 5, "1 bois étoilé (plan)" },
    { "Kit de feu de camp d'expert", 200, 10, "1 bûches épaisses (plan)" },
}
-- Début de la suite de quêtes du Sac de couchage douillet (dès le niveau 14) : carte, x, y (%)
M.BAG_QUEST = { Alliance = { 1436, 37, 50, "Marche de l'Ouest, débris d'un chariot" }, Horde = { 1413, 46, 74, "Tarides, tour incendiée" } }

-- Ce que chaque perso peut apporter : { { key, c, prof, rank, item, effect, tier } }
function M:Contributions()
    local out = {}
    for key, c in pairs(WK.DB.global.characters) do
        for _, it in ipairs(M.ITEMS) do
            local p = c.professions and c.professions[it[1]]
            local rank = p and p.rank or 0
            if rank >= 20 then
                local item, tier = it[2][1], 1
                if rank >= 300 then item, tier = it[4], 3 elseif rank >= 140 then item, tier = it[3], 2 end
                table.insert(out, { key = key, c = c, prof = it[1], rank = rank, item = item, effect = it[2][2], tier = tier })
            end
        end
        local cook = c.professions and c.professions["Cuisine"]
        if cook then
            local fire
            for _, f in ipairs(M.FIRES) do if (cook.rank or 0) >= f[2] then fire = f end end
            if fire then table.insert(out, { key = key, c = c, prof = "Cuisine", rank = cook.rank or 0, item = fire[1], effect = string.format(T("feu de camp, %d objets en plus"), fire[3]), tier = 0 }) end
        end
    end
    table.sort(out, function(a, b)
        if a.key ~= b.key then return WK:CharName(a.c, a.key) < WK:CharName(b.c, b.key) end
        return a.prof < b.prof
    end)
    return out
end

function M:GuideToBag()
    local fac = UnitFactionGroup and UnitFactionGroup("player")
    local q = M.BAG_QUEST[fac or ""]
    if not q then return end
    local G = WK.modules.Guide
    local t = { map = q[1], x = q[2] / 100, y = q[3] / 100 }
    t.cont, t.wx, t.wy = G.ToWorld(t.map, t.x, t.y)
    local p = G:PlayerPos()
    t.distance = p and G:Vector(p, t) or nil
    t.e = { q[2], q[3], 0, nil, nil, "Cozy Sleeping Bag", T("Sac de couchage douillet"), T(q[4]) }
    G:Start(t, "Sac de couchage douillet", "camp")
end

local DEFAULTS = { enabled = true, renewAt = 10, sound = false, doneSecs = 8 } -- minutes restantes sous lesquelles on propose de renouveler

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
    if cfg.enabled and WK:FeatureOn("campfire") then
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
    if changed then WK:NotifyChanged() end -- section Feu de camp de QoL (en direct)
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
