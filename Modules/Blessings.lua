local ADDON_NAME, WK = ...
local M = WK:NewModule("Blessings")
local T = function(s) return WK.T(s) end

-- Bénédictions du paladin : qui donne quoi à quelle classe dans le groupe, ce qui manque, et la répartition
-- entre paladins. Compatible avec PallyPower : mêmes messages d'addon (préfixe PLPWR, format public de ses
-- messages : SELF, ASELF, ASSIGN, PASSIGN, MASSIGN, NASSIGN, AASSIGN, REQ, CLEAR, FREEASSIGN), mêmes numéros
-- de bénédiction, d'aura et de classe que sa version WoW Forever (le chaman en 9e classe, l'espace des noms
-- « Prénom Nom » transmis en « _ »). Aucun code de PallyPower n'est repris (licence « tous droits réservés ») :
-- seulement ce format d'échange, pour se répartir les bénédictions avec ceux qui l'utilisent.
-- Les paladins sous Warband Keeper se reconnaissent en plus par le préfixe WKbless (« HI »).
--   WK.DB.global.blessings = { bar, chars = { [perso] = { mode, free, mine = { [classe n°] = bénédiction n° },
--                              aura, except = { [nom] = { class = n°, b = n° } } } } }
-- Sur WoW Forever : bénédictions d'une heure, une seule bénédiction d'un même paladin par joueur, pas de
-- grandes bénédictions ni de talents qui les améliorent.

local PREFIX, WKPREFIX = "PLPWR", "WKbless"
-- n° de bénédiction (format PallyPower) : sort simple, sort supérieur
M.BLESS = {
    { 19742, 25894 }, -- 1 Sagesse
    { 19740, 25782 }, -- 2 Puissance
    { 20217, 25898 }, -- 3 Rois
    { 1038, 25895 },  -- 4 Salut
    { 19977, 25890 }, -- 5 Lumière
    { 20911, 25899 }, -- 6 Sanctuaire
}
M.SHORT = { "Sa", "Pu", "Ro", "Sl", "Lu", "Sc" }
-- n° d'aura (format PallyPower)
M.AURAS = { 465, 7294, 19746, 19876, 19888, 19891, 20218 }
-- n° de classe (format PallyPower WoW Forever)
M.CLASSES = { "WARRIOR", "ROGUE", "PRIEST", "DRUID", "PALADIN", "HUNTER", "MAGE", "WARLOCK", "SHAMAN" }
M.CLASS_ID = {}
for i, c in ipairs(M.CLASSES) do M.CLASS_ID[c] = i end
-- ordre de préférence par classe pour la répartition automatique (n° de bénédiction). Sur WoW Forever le
-- Sanctuaire n'existe plus et le Salut se cumule avec une autre bénédiction : ni l'un ni l'autre n'entre ici.
--   1 paladin : la 1re ; un 2e paladin prend la 2e, etc.
local PRIO = {
    WARRIOR = { 2, 3, 1, 5 }, ROGUE = { 2, 3, 1, 5 }, HUNTER = { 2, 3, 1, 5 },
    MAGE = { 3, 1, 2, 5 }, WARLOCK = { 3, 1, 2, 5 },
    PRIEST = { 1, 3, 2, 5 }, SHAMAN = { 1, 3, 2, 5 }, PALADIN = { 1, 3, 2, 5 }, DRUID = { 1, 3, 2, 5 },
    DEFAULT = { 1, 3, 2, 5 },
    TANK = { 3, 2, 1, 5 }, -- guerrier ou druide qui tanke : Rois d'abord
}
M.PRIO = PRIO
-- classes qui reçoivent le Salut (jamais les tanks)
M.SALUT = { WARRIOR = true, ROGUE = true, HUNTER = true, MAGE = true, WARLOCK = true }
local AURA_PRIO = { 1, 2, 3, 6, 5, 4, 7 }

local function readable(v) return WK.modules.QoL.Readable(v) end
local function inCombat() return InCombatLockdown and InCombatLockdown() or false end
local function now() return GetTime and GetTime() or 0 end
local function isPaladin() return select(2, UnitClass("player")) == "PALADIN" end

-- Nom complet d'une unité (« Prénom Nom » sur WoW Forever), sans le royaume
local function fullName(unit)
    local n = readable(GetUnitName and GetUnitName(unit, true)) or readable(UnitName(unit))
    if type(n) ~= "string" then return nil end
    return (n:gsub("%-[^%s]*$", ""))
end
M.FullName = fullName
local function bare(name)
    if type(name) ~= "string" then return nil end
    if Ambiguate then name = Ambiguate(name, "none") end
    return (name:gsub("%-[^%s]*$", ""))
end
local function wire(n) return (n:gsub(" ", "_")) end
local function unwire(n) return (n:gsub("_", " ")) end

function M:Config()
    local g = WK.DB.global
    g.blessings = g.blessings or {}
    local d = g.blessings
    if d.bar == nil then d.bar = true end
    if d.salut == nil then d.salut = true end
    if d.barSolo == nil then d.barSolo = false end -- barre affichée quand on est seul
    d.chars = d.chars or {}
    return d
end
-- réglages de ce paladin
function M:Me()
    local d = self:Config()
    local key = WK:CharKey()
    local c = d.chars[key] or {}
    d.chars[key] = c
    c.mode = c.mode or "auto"
    if c.free == nil then c.free = true end
    c.mine = c.mine or {}
    c.except = c.except or {}
    c.aura = c.aura or 0
    return c
end
function M:On() return isPaladin() and WK:FeatureOn("classes") end

local function known(id)
    local k = (IsPlayerSpell and IsPlayerSpell(id)) or (IsSpellKnown and IsSpellKnown(id))
    if k then return true end
    -- un rang supérieur peut remplacer le rang 1 dans le grimoire : on cherche aussi le sort par son nom
    local name = WK.SpellInfo(id)
    if name and C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, name)
        if ok and type(info) == "table" and info.spellID then
            local ok2, k2 = pcall(IsPlayerSpell or function() return false end, info.spellID)
            if ok2 and k2 then return true end
        end
    end
    return false
end
function M:Known(i) return self.BLESS[i] and known(self.BLESS[i][1]) end
function M:KnownAura(i) return self.AURAS[i] and known(self.AURAS[i]) end
function M:Name(i) return self.BLESS[i] and WK.SpellInfo(self.BLESS[i][1]) end
function M:AuraName(i) return self.AURAS[i] and WK.SpellInfo(self.AURAS[i]) end
function M.Icon(id)
    return (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)) or (GetSpellTexture and GetSpellTexture(id))
end

---------------------------------------------------------------------------
-- Paladins du groupe : pallys[nom] = { wk, known = { [n°] = true }, assign = { [classe] = n° }, aura,
-- normal = { [classe] = { [joueur] = n° } }, free, me }
---------------------------------------------------------------------------
local pallys = {}
M.pallys = pallys
local myName
local function me()
    myName = myName or fullName("player")
    return myName
end
local function groupUnits()
    local out = { "player" }
    if IsInRaid and IsInRaid() then
        out = {}
        for i = 1, 40 do table.insert(out, "raid" .. i) end
    elseif IsInGroup and IsInGroup() then
        for i = 1, 4 do table.insert(out, "party" .. i) end
    end
    return out
end
M.GroupUnits = groupUnits
local function isLeader(name)
    if not name then return false end
    for _, u in ipairs(groupUnits()) do
        if UnitExists(u) and fullName(u) == name then
            return (UnitIsGroupLeader and UnitIsGroupLeader(u)) or (UnitIsGroupAssistant and UnitIsGroupAssistant(u)) or false
        end
    end
    return false
end
M.IsLeader = isLeader

-- ma ligne, telle que les autres la voient
local function myEntry()
    local c = M:Me()
    local e = pallys[me()] or {}
    pallys[me()] = e
    e.me, e.wk, e.free = true, true, c.free
    e.known = {}
    for i = 1, #M.BLESS do if M:Known(i) then e.known[i] = true end end
    e.assign = {}
    for i = 1, #M.CLASSES do e.assign[i] = c.mine[i] or 0 end
    e.aura = c.aura or 0
    e.normal = {}
    for name, x in pairs(c.except) do
        e.normal[x.class] = e.normal[x.class] or {}
        e.normal[x.class][name] = x.b
    end
    return e
end

-- les paladins qui ne sont plus dans le groupe sont oubliés
local scannedAt, auraDirty = {}, {} -- relevés des effets par membre (M:Left plus bas)
local function prune()
    local present = {}
    for _, u in ipairs(groupUnits()) do
        if UnitExists(u) then local n = fullName(u); if n then present[n] = select(2, UnitClass(u)) end end
    end
    for name, e in pairs(pallys) do if not present[name] and not e.demo then pallys[name] = nil end end
    -- relevés des effets : seulement les membres présents (les tables ne grossissent plus sur toute la séance)
    for key in pairs(scannedAt) do
        local n = key:match("^(.*):%d+$")
        if n and not present[n] then scannedAt[key] = nil; auraDirty[n] = nil end
    end
    myEntry()
    return present
end

-- Paladins du groupe, moi d'abord puis par nom
function M:Pallys()
    prune()
    local out = {}
    for name, e in pairs(pallys) do table.insert(out, { name = name, e = e }) end
    table.sort(out, function(a, b)
        if a.e.me ~= b.e.me then return a.e.me and true or false end
        return a.name < b.name
    end)
    return out
end

---------------------------------------------------------------------------
-- Répartition automatique : les choix des autres (PallyPower, ou à la main) sont fixes ; les paladins en
-- automatique (sous Warband Keeper) prennent, par ordre de nom, la 1re bénédiction de la classe que personne
-- n'a encore prise et qu'ils connaissent. Chacun calcule le même résultat de son côté.
---------------------------------------------------------------------------
function M:AutoAssign()
    local c = self:Me()
    local manual = c.mode ~= "auto"
    -- à la main, ma ligne reste telle quelle (seuls les paladins simulés du test se répartissent encore)
    if manual and not self.demo then return end
    prune()
    local list, fixed = {}, {}
    for name, e in pairs(pallys) do
        if (e.me and not manual) or (not e.me and e.wk and e.auto) then table.insert(list, name) else table.insert(fixed, e) end
    end
    table.sort(list)
    local mine, takenAura = {}, {}
    for _, e in ipairs(fixed) do if (e.aura or 0) > 0 then takenAura[e.aura] = true end end
    for ci, cl in ipairs(self.CLASSES) do
        local taken = {}
        for _, e in ipairs(fixed) do local b = e.assign and e.assign[ci]; if b and b > 0 then taken[b] = true end end
        for _, name in ipairs(list) do
            local e = pallys[name]
            local pick = 0
            for _, b in ipairs(PRIO[cl] or PRIO.DEFAULT) do
                if not taken[b] and (e.known or {})[b] then pick = b break end
            end
            if pick > 0 then taken[pick] = true end
            if e.me then mine[ci] = pick end
            if e.demo then e.assign = e.assign or {}; e.assign[ci] = pick end
        end
    end
    -- aura : la 1re de la liste que personne d'autre n'a prise
    local myAura = 0
    for _, name in ipairs(list) do
        local e = pallys[name]
        local pick = 0
        for _, a in ipairs(AURA_PRIO) do
            if not takenAura[a] and (e.me and self:KnownAura(a) or (not e.me)) then pick = a break end
        end
        if pick > 0 then takenAura[pick] = true end
        if e.me then myAura = pick end
        if e.demo then e.aura = pick end
    end
    if manual then return end
    local changed = false
    for ci = 1, #self.CLASSES do if (c.mine[ci] or 0) ~= (mine[ci] or 0) then changed = true end end
    if changed or c.aura ~= myAura then
        c.mine, c.aura = mine, myAura
        myEntry()
        self:SendSelf()
    end
end

---------------------------------------------------------------------------
-- Ce que je dois donner : n° de bénédiction pour une classe ou un joueur
---------------------------------------------------------------------------
function M:ForClass(class)
    local ci = self.CLASS_ID[class or ""]
    local b = ci and self:Me().mine[ci]
    if b and b > 0 and self:Known(b) then return b end
end
-- vrai si je donne déjà cette bénédiction à une classe (alors pas de ligne Salut à part)
function M:ForClassUses(b)
    for _, v in pairs(self:Me().mine) do if v == b then return true end end
    return false
end
local function isTank(unit)
    if not UnitGroupRolesAssigned then return false end
    local ok, r = pcall(UnitGroupRolesAssigned, unit)
    return ok and readable(r) == "TANK"
end
M.IsTank = isTank
function M:ForUnit(unit)
    local name = fullName(unit)
    local x = name and self:Me().except[name]
    if x and x.b and x.b > 0 and self:Known(x.b) then return x.b end
    local cl = select(2, UnitClass(unit))
    local b = self:ForClass(cl)
    -- un tank prend Rois si aucun autre paladin ne la donne déjà à sa classe
    if b and isTank(unit) then
        local want = PRIO.TANK[1]
        local ci = self.CLASS_ID[cl or ""]
        if b ~= want and ci and self:Known(want) then
            local covered = false
            for _, e in pairs(pallys) do
                if not e.me and e.assign and e.assign[ci] == want then covered = true end
            end
            if not covered then return want, true end
        end
    end
    return b
end

---------------------------------------------------------------------------
-- Temps restant de ma bénédiction sur un joueur (lu hors combat ; en combat, la dernière valeur lue continue
-- de décompter : le jeu y cache les auras)
---------------------------------------------------------------------------
local seen = {} -- [nom..":"..n°] = expiration (GetTime), 0 = sans fin
local blessNames = {}
local function scanLeft(unit, b)
    local ids = M.BLESS[b]
    if not ids then return nil end
    -- noms gardés par bénédiction (avant : refaits pour chaque membre, chaque seconde)
    local names = blessNames[b]
    if not names then
        names = {}
        local all = true
        for _, id in ipairs(ids) do local n = WK.SpellInfo(id); if n then names[n] = true else all = false end end
        if all then blessNames[b] = names end
    end
    for i = 1, 40 do
        local name, exp, src
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local ok, d = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
            if not ok or not d then break end
            name, exp, src = readable(d.name), readable(d.expirationTime), readable(d.sourceUnit)
        elseif UnitBuff then
            local n, _, _, _, _, e, s = UnitBuff(unit, i)
            if not n then break end
            name, exp, src = readable(n), readable(e), readable(s)
        else break end
        if name and names[name] and (src == nil or src == "player" or (UnitIsUnit and UnitIsUnit(src, "player"))) then
            return (not exp or exp == 0) and 0 or exp
        end
    end
    return false
end
-- membre relu seulement si ses effets ont changé (UNIT_AURA) ou au plus toutes les 10 s : avant, jusqu'à
-- 40 membres × 2 bénédictions × 40 effets relus chaque seconde hors combat
-- paladin seulement, et membres du groupe seulement (pas les plaques de nom ni la cible) : avant, chaque
-- effet de chaque unité vue passait ici, pour toutes les classes
WK:On("UNIT_AURA", function(unit)
    if type(unit) ~= "string" or not (unit == "player" or unit:find("^party") or unit:find("^raid")) then return end
    if not M:On() then return end
    local n = fullName(unit)
    if n then auraDirty[n] = now() end
end)
function M:Left(unit, b)
    local name = fullName(unit)
    if not name then return nil end
    local key = name .. ":" .. b
    if not inCombat() and UnitIsVisible and UnitIsVisible(unit) then
        local t = now()
        local last = scannedAt[key]
        -- relu si ses effets ont changé depuis la dernière lecture de cette bénédiction, ou toutes les 10 s
        if not last or (auraDirty[name] or 0) >= last or t - last > 10 then
            local exp = scanLeft(unit, b)
            if exp ~= nil then seen[key] = exp or nil end
            scannedAt[key] = t + 0.001
        end
    end
    local exp = seen[key]
    if exp == nil then return nil end
    if exp == 0 then return math.huge end
    local left = exp - now()
    if left <= 0 then seen[key] = nil return nil end
    return left
end

-- État pour la barre : une ligne par classe présente (et une par exception), membres, manquants, plus court
-- Lignes gardées 0,9 s : la barre des bénédictions et le bouton Buffer les demandaient chacun chaque seconde
-- (jusqu'à 40 auras lues par membre en raid) ; effacées à chaque changement (groupe, répartition)
local statusCache, statusAt = nil, -10
function M.StatusDirty() statusCache = nil end
-- groupe changé, ou sort lancé par toi (bénédiction posée) : lignes refaites au prochain appel
WK:On("GROUP_ROSTER_UPDATE", function() statusCache = nil end)
if WK.OnUnit then WK:OnUnit("UNIT_SPELLCAST_SUCCEEDED", "player", function() statusCache = nil end) end
function M:Status()
    local t = _G.GetTime and _G.GetTime() or 0
    if statusCache and t - statusAt < 0.9 and t >= statusAt then return statusCache end
    statusCache, statusAt = self:StatusNow(), t
    return statusCache
end
function M:StatusNow()
    local rows, byClass = {}, {}
    local c = self:Me()
    -- le Salut n'est pas affecté par classe : une ligne à part, pour qui le connaît
    local salut = (self:Config().salut ~= false and self:Known(4) and not self:ForClassUses(4))
        and { b = 4, salut = true, members = {}, missing = 0 } or nil
    for _, u in ipairs(groupUnits()) do
        if UnitExists(u) and UnitIsPlayer(u) then
            local name = fullName(u)
            local cl = select(2, UnitClass(u))
            local b, tank = self:ForUnit(u)
            if name and cl and b then
                local ex = c.except[name] ~= nil
                local key = ex and ("x:" .. name) or (cl .. ":" .. b)
                local r = byClass[key]
                if not r then
                    r = { class = cl, b = b, members = {}, missing = 0, except = ex and name or nil, tank = tank or nil }
                    byClass[key] = r
                    table.insert(rows, r)
                end
                local dead = UnitIsDeadOrGhost(u) or not UnitIsConnected(u)
                local left = (not dead) and self:Left(u, b) or nil
                table.insert(r.members, { unit = u, name = name, left = left, dead = dead })
                if not dead and not left then r.missing = r.missing + 1 end
                if left and (not r.min or left < r.min) then r.min = left end
            end
            -- Salut : se cumule avec la bénédiction de classe, pour les classes prévues, jamais les tanks
            if name and cl and salut and self.SALUT[cl] and not isTank(u) then
                local dead = UnitIsDeadOrGhost(u) or not UnitIsConnected(u)
                local left = (not dead) and self:Left(u, 4) or nil
                table.insert(salut.members, { unit = u, name = name, left = left, dead = dead })
                if not dead and not left then salut.missing = salut.missing + 1 end
                if left and (not salut.min or left < salut.min) then salut.min = left end
            end
        end
    end
    table.sort(rows, function(a, b2)
        if (a.except ~= nil) ~= (b2.except ~= nil) then return a.except == nil end
        local ca, cb = self.CLASS_ID[a.class] or 99, self.CLASS_ID[b2.class] or 99
        if ca ~= cb then return ca < cb end
        return (a.tank and 1 or 0) > (b2.tank and 1 or 0)
    end)
    if salut and #salut.members > 0 then table.insert(rows, salut) end
    return rows
end

-- Prochain joueur à bénir dans une ligne (ou dans toutes) : sans ma bénédiction, puis le plus court
function M:NextTarget(row, refresh)
    refresh = refresh or 300
    local best, bestLeft
    for _, r in ipairs(row and { row } or self:Status()) do
        for _, m in ipairs(r.members) do
            if not m.dead and not (UnitAffectingCombat(m.unit) and not UnitIsUnit(m.unit, "player")) then
                local l = m.left or -1
                if l < refresh and (not bestLeft or l < bestLeft) then best, bestLeft = { unit = m.unit, b = r.b, name = m.name }, l end
            end
        end
    end
    return best
end

---------------------------------------------------------------------------
-- Messages (format PallyPower)
---------------------------------------------------------------------------
local queue, sending, lastMsg = {}, false, {}
local function channel()
    if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and IsInInstance and select(1, IsInInstance()) then
        return "INSTANCE_CHAT"
    end
    if IsInRaid and IsInRaid() then return "RAID" end
    if IsInGroup and IsInGroup() then return "PARTY" end
end
local function pump()
    local q = table.remove(queue, 1)
    if not q then sending = false return end
    sending = true
    local ch = q.target and "WHISPER" or channel()
    if ch and C_ChatInfo and C_ChatInfo.SendAddonMessage then
        pcall(C_ChatInfo.SendAddonMessage, q.prefix, q.msg, ch, q.target)
    end
    C_Timer.After(0.25, pump)
end
local function msgKind(msg)
    local cmd = msg:match("^(%S+)")
    if not cmd or cmd == "NASSIGN" or cmd == "CLEAR" then return nil end -- jamais sautés
    if cmd == "ASSIGN" then
        local n, ci = msg:match("^ASSIGN (.+) (%d+) %d+$")
        return "ASSIGN:" .. tostring(n) .. ":" .. tostring(ci)
    end
    if cmd == "PASSIGN" then return "PASSIGN:" .. tostring(msg:match("^PASSIGN (.+)@")) end
    if cmd == "MASSIGN" or cmd == "AASSIGN" then return cmd .. ":" .. tostring(msg:match("^%S+ (.+) %d+$")) end
    return cmd -- SELF, ASELF, FREEASSIGN, REQ, HI…
end
local function send(msg, target, prefix)
    if not channel() then return end
    -- un même message au groupe n'est pas renvoyé avant 15 s (avant, seul le dernier envoyé était comparé : un
    -- « SELF » identique repartait à chaque changement du groupe, en plus du « HI »). Un changement de répartition
    -- donne un autre message et part tout de suite ; une réponse chuchotée part toujours
    if not target then
        -- par genre de message (commande + nom visé, + classe pour ASSIGN) : seul un message identique au DERNIER de
        -- son genre est sauté (avant : identique à n'importe quel message des 15 s, un retour A, B, A perdait le
        -- dernier A et PallyPower gardait B)
        local kind = msgKind(msg)
        if kind then
            local t = _G.GetTime and _G.GetTime() or 0
            local last = lastMsg[kind]
            if last and last.msg == msg and t - last.at < 15 then return end
            lastMsg[kind] = { msg = msg, at = t }
        end
    end
    if #queue > 40 then return end
    table.insert(queue, { msg = msg, target = target, prefix = prefix or PREFIX })
    if not sending then pump() end
end
M.Send = send

-- Mon état : bénédictions connues, attribution par classe, aura, exceptions, assignation libre
function M:SendSelf(target)
    if not (self:On() and channel()) then return end
    local e = myEntry()
    local s = ""
    for i = 1, 6 do s = s .. (e.known[i] and "10" or "nn") end
    s = s .. "@"
    for i = 1, #self.CLASSES do local b = e.assign[i] or 0; s = s .. (b > 0 and tostring(b) or "n") end
    send("SELF " .. s, target)
    local a = ""
    for i = 1, #self.AURAS do a = a .. (self:KnownAura(i) and "10" or "nn") end
    send("ASELF " .. a .. "@" .. (e.aura or 0), target)
    local list = {}
    for name, x in pairs(self:Me().except) do
        table.insert(list, string.format("%s %d %s %d", wire(me()), x.class, wire(name), x.b))
    end
    for i = 1, #list, 5 do send("NASSIGN " .. table.concat(list, "@", i, math.min(i + 4, #list)), target) end
    send("FREEASSIGN " .. (self:Me().free and "YES" or "NO") .. " | SYMCOUNT 0 | COOLDOWNS:n:n:n:n", target)
    send("HI " .. (self:Me().mode == "auto" and "auto" or "hand"), target, WKPREFIX)
end
function M:Request()
    if channel() then send("REQ") end
end

-- Changer une case : la mienne, ou celle d'un autre si je mène le groupe ou s'il laisse faire
function M:CanEdit(name)
    if name == me() then return true end
    local e = pallys[name]
    return isLeader(me()) or (e and e.free) or false
end
function M:SetAssign(name, ci, b)
    if not self:CanEdit(name) then return false end
    if name == me() then
        local c = self:Me()
        c.mine[ci] = b
        c.mode = "hand"
        myEntry()
        self:SendSelf()
    else
        local e = pallys[name]
        if e then e.assign = e.assign or {}; e.assign[ci] = b; e.auto = false end
        if not (e and e.demo) then send(string.format("ASSIGN %s %d %d", wire(name), ci, b)) end
    end
    statusCache = nil -- répartition changée : lignes de la barre à refaire tout de suite
    if self.OnChange then self:OnChange() end
    return true
end
function M:SetAura(name, a)
    if not self:CanEdit(name) then return false end
    if name == me() then
        local c = self:Me()
        c.aura = a
        c.mode = "hand"
        myEntry()
        self:SendSelf()
    else
        local e = pallys[name]
        if e then e.aura = a; e.auto = false end
        if not (e and e.demo) then send(string.format("AASSIGN %s %d", wire(name), a)) end
    end
    statusCache = nil -- répartition changée : lignes de la barre à refaire tout de suite
    if self.OnChange then self:OnChange() end
    return true
end
function M:SetMode(mode)
    local c = self:Me()
    c.mode = mode
    if mode == "auto" then self:AutoAssign() end
    self:SendSelf()
    statusCache = nil -- répartition changée : lignes de la barre à refaire tout de suite
    if self.OnChange then self:OnChange() end
end
function M:SetFree(on)
    self:Me().free = on and true or false
    self:SendSelf()
end
-- Exception pour un joueur (sa classe, la bénédiction) ; b = 0 pour la retirer
function M:SetException(name, class, b)
    local c = self:Me()
    local ci = self.CLASS_ID[class or ""]
    if not (name and ci) then return end
    c.except[name] = (b and b > 0) and { class = ci, b = b } or nil
    if not c.except[name] then send(string.format("NASSIGN %s %d %s 0", wire(me()), ci, wire(name))) end
    myEntry()
    self:SendSelf()
    statusCache = nil -- répartition changée : lignes de la barre à refaire tout de suite
    if self.OnChange then self:OnChange() end
end

local function chars9(s)
    local out = {}
    for i = 1, #M.CLASSES do
        local ch = s:sub(i, i)
        out[i] = (ch == "" or ch == "n") and 0 or (tonumber(ch) or 0)
    end
    return out
end
local function entryOf(name)
    local e = pallys[name]
    if not e then e = { known = {}, assign = {}, aura = 0, normal = {} }; pallys[name] = e end
    return e
end
local function allowed(sender, target)
    if target == sender then return true end
    if isLeader(sender) then return true end
    return target ~= me() or M:Me().free
end
-- Une attribution d'un autre sur ma ligne (chef ou assignation libre) : elle devient la mienne, à la main
local function applyMine(ci, b)
    local c = M:Me()
    if ci then c.mine[ci] = b end
    c.mode = "hand"
    myEntry()
end

function M:Receive(sender, msg)
    if sender == me() then return end
    if msg == "REQ" then self:SendSelf(sender) return end
    -- ligne du paladin qui écrit : créée seulement par ses propres messages (pas par un REQ ou un CLEAR)
    local e = pallys[sender] or ((msg:find("^A?SELF ") or msg:find("FREEASSIGN")) and entryOf(sender)) or {}
    local numbers, assign = msg:match("^SELF ([0-9a-fn]*)@([0-9n]*)")
    if numbers then
        e.known = {}
        for i = 1, 6 do
            local r = numbers:sub((i - 1) * 2 + 1, (i - 1) * 2 + 1)
            if r ~= "" and r ~= "n" then e.known[i] = true end
        end
        e.assign = chars9(assign or "")
        e.normal = e.normal or {}
        return true
    end
    local an, aa = msg:match("^ASELF ([0-9a-fn]*)@([0-9n]*)")
    if an then e.aura = tonumber(aa) or 0 return true end
    local name, ci, b = msg:match("^ASSIGN (.+) (%d+) (%d+)$")
    if name then
        name, ci, b = bare(unwire(name)), tonumber(ci), tonumber(b)
        if not allowed(sender, name) then return end
        if name == me() then applyMine(ci, b) else entryOf(name).assign[ci] = b end
        return true
    end
    local pn, p9 = msg:match("^PASSIGN (.+)@([0-9n]*)$")
    if pn then
        pn = bare(unwire(pn))
        if not allowed(sender, pn) then return end
        local list = chars9(p9)
        if pn == me() then for i, v in ipairs(list) do self:Me().mine[i] = v end applyMine() else entryOf(pn).assign = list end
        return true
    end
    local mn, mb = msg:match("^MASSIGN (.+) (%d+)$")
    if mn then
        mn, mb = bare(unwire(mn)), tonumber(mb)
        if not allowed(sender, mn) then return end
        for i = 1, #self.CLASSES do
            if mn == me() then self:Me().mine[i] = mb else entryOf(mn).assign[i] = mb end
        end
        if mn == me() then applyMine() end
        return true
    end
    if msg:find("^NASSIGN ") then
        for pn2, c2, tn, b2 in msg:sub(9):gmatch("([^@ ]+) ([^@ ]+) ([^@ ]+) ([^@ ]+)") do
            pn2, tn = bare(unwire(pn2)), unwire(tn)
            c2, b2 = tonumber(c2), tonumber(b2)
            if c2 and b2 and allowed(sender, pn2) then
                if pn2 == me() then
                    self:Me().except[tn] = b2 > 0 and { class = c2, b = b2 } or nil
                    applyMine()
                else
                    local pe = entryOf(pn2)
                    pe.normal[c2] = pe.normal[c2] or {}
                    pe.normal[c2][tn] = b2 > 0 and b2 or nil
                end
            end
        end
        return true
    end
    local aun, aua = msg:match("^AASSIGN (.+) (%d+)$")
    if aun then
        aun, aua = bare(unwire(aun)), tonumber(aua)
        if not allowed(sender, aun) then return end
        if aun == me() then self:Me().aura = aua; applyMine() else entryOf(aun).aura = aua end
        return true
    end
    -- seulement un message reconnu demande une nouvelle répartition (un message inconnu ne coûte plus rien)
    if msg:find("FREEASSIGN YES") then e.free = true return true end
    if msg:find("FREEASSIGN NO") then e.free = false return true end
    if msg:find("^CLEAR") and isLeader(sender) then
        for _, pe in pairs(pallys) do pe.assign = {} end
        local c = self:Me()
        c.mine = {}
        if not msg:find("SKIP") then c.aura = 0 end
        applyMine()
        return true
    end
end

---------------------------------------------------------------------------
-- Évènements
---------------------------------------------------------------------------
local function changed()
    statusCache = nil
    if M.OnChange then M:OnChange() end
end
-- Messages des paladins regroupés : en raid, plusieurs addons en envoient plusieurs par seconde ; une seule
-- nouvelle répartition (et un seul rafraîchissement de la barre) toutes les 0,3 s au plus
local reassignPending
function M.Reassign()
    if reassignPending then return end
    reassignPending = true
    _G.C_Timer.After(0.3, function()
        reassignPending = false
        M:AutoAssign()
        changed()
    end)
end
local rosterPending
local function onRoster()
    if rosterPending then return end
    rosterPending = true
    C_Timer.After(1.5, function()
        rosterPending = false
        if not M:On() then return end
        local present = prune()
        M:AutoAssign()
        if channel() then
            M:SendSelf()
            -- demande d'état seulement quand un paladin du groupe nous est encore inconnu (avant : à chaque
            -- changement du groupe, et chaque paladin répondait par plusieurs chuchotements)
            local unknown = false
            for name, cls in pairs(present or {}) do
                if cls == "PALADIN" and name ~= me() and not pallys[name] then unknown = true break end
            end
            if unknown then M:Request() end
        end
        changed()
    end)
end
WK:On("PLAYER_LOGIN", function()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
        pcall(C_ChatInfo.RegisterAddonMessagePrefix, WKPREFIX)
    end
    C_Timer.After(4, function() myName = nil; onRoster() end)
end)
---------------------------------------------------------------------------
-- Test hors groupe : deux paladins simulés (un sous Warband Keeper en automatique, un sous PallyPower qui
-- donne Rois partout) pour voir la répartition ; rien n'est envoyé pour eux, arrêté en rejoignant un groupe
---------------------------------------------------------------------------
M.DEMO = { "Aerin Lune", "Brann Fer" }
function M:Demo(on)
    for _, n in ipairs(self.DEMO) do pallys[n] = nil end
    self.demo = nil
    if on then
        if IsInGroup and IsInGroup() then return false end
        self.demo = true
        pallys["Aerin Lune"] = { demo = true, wk = true, auto = true, free = true,
            known = { [1] = true, [2] = true, [3] = true, [5] = true }, assign = {}, aura = 0, normal = {} }
        local kings = {}
        for i = 1, #self.CLASSES do kings[i] = 3 end
        pallys["Brann Fer"] = { demo = true, free = true, known = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true },
            assign = kings, aura = 3, normal = {} }
    end
    self:AutoAssign()
    statusCache = nil -- répartition changée : lignes de la barre à refaire tout de suite
    if self.OnChange then self:OnChange() end
    return true
end

WK:On("GROUP_ROSTER_UPDATE", function(...)
    if M.demo and IsInGroup and IsInGroup() then M:Demo(false) end
    return onRoster(...)
end)
WK:On("SPELLS_CHANGED", function() if M:On() then myEntry(); onRoster() end end)
WK:On("CHAT_MSG_ADDON", function(prefix, msg, ch, sender)
    prefix, msg, ch, sender = readable(prefix), readable(msg), readable(ch), readable(sender)
    if (prefix ~= PREFIX and prefix ~= WKPREFIX) or type(msg) ~= "string" or not M:On() then return end
    if not (ch == "PARTY" or ch == "RAID" or ch == "INSTANCE_CHAT" or ch == "WHISPER") then return end
    sender = bare(sender)
    if not sender or sender == me() then return end
    if #msg > 250 then return end
    if prefix == WKPREFIX then
        local mode = msg:match("^HI (%a+)")
        if mode then local e = entryOf(sender); e.wk = true; e.auto = mode == "auto"; M:Reassign() end
        return
    end
    if M:Receive(sender, msg) then M:Reassign() end
end)

-- Pour les tests
M._reset = function()
    for k in pairs(pallys) do pallys[k] = nil end
    myName = nil; wipe(seen); M.demo = nil
    for k in pairs(lastMsg) do lastMsg[k] = nil end
end
