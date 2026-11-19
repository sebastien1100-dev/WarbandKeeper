local ADDON_NAME, WK = ...
local M = WK:NewModule("Blessings")
local T = function(s) return WK.T(s) end

-- Bénédictions du paladin : qui donne quoi à quelle classe dans le groupe, ce qui manque, et la répartition
-- entre paladins. Compatible avec PallyPower : mêmes messages d'addon (préfixe PLPWR, format public de ses
-- messages : SELF, ASELF, ASSIGN, PASSIGN, MASSIGN, NASSIGN, AASSIGN, REQ, CLEAR, FREEASSIGN), mêmes numéros
-- de bénédiction, d'aure et de classe que sa version WoW Forever (le chaman en 9e classe, l'espace des noms
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
-- n° d'aure (format PallyPower)
M.AURAS = { 465, 7294, 19746, 19876, 19888, 19891, 20218 }
-- n° de classe (format PallyPower WoW Forever)
M.CLASSES = { "WARRIOR", "ROGUE", "PRIEST", "DRUID", "PALADIN", "HUNTER", "MAGE", "WARLOCK", "SHAMAN" }
M.CLASS_ID = {}
for i, c in ipairs(M.CLASSES) do M.CLASS_ID[c] = i end
-- ordre de préférence par classe pour la répartition automatique (n° de bénédiction)
local PRIO = {
    WARRIOR = { 2, 3, 5, 6, 4, 1 }, ROGUE = { 2, 3, 4, 5, 6, 1 }, HUNTER = { 2, 1, 3, 4, 5, 6 },
    DEFAULT = { 1, 3, 4, 5, 6, 2 },
}
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
    return k and true or false
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
local function leaderName()
    for _, u in ipairs(groupUnits()) do
        if UnitExists(u) and UnitIsGroupLeader and UnitIsGroupLeader(u) then return fullName(u) end
    end
end
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
local function prune()
    local present = {}
    for _, u in ipairs(groupUnits()) do
        if UnitExists(u) then local n = fullName(u); if n then present[n] = select(2, UnitClass(u)) end end
    end
    for name in pairs(pallys) do if not present[name] then pallys[name] = nil end end
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
    if c.mode ~= "auto" then return end
    prune()
    local list, fixed = {}, {}
    for name, e in pairs(pallys) do
        if e.me or (e.wk and e.auto) then table.insert(list, name) else table.insert(fixed, e) end
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
        end
    end
    -- aure : la 1re de la liste que personne d'autre n'a prise
    local myAura = 0
    for _, name in ipairs(list) do
        local e = pallys[name]
        local pick = 0
        for _, a in ipairs(AURA_PRIO) do
            if not takenAura[a] and (e.me and self:KnownAura(a) or (not e.me)) then pick = a break end
        end
        if pick > 0 then takenAura[pick] = true end
        if e.me then myAura = pick end
    end
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
function M:ForUnit(unit)
    local name = fullName(unit)
    local x = name and self:Me().except[name]
    if x and x.b and x.b > 0 and self:Known(x.b) then return x.b end
    return self:ForClass(select(2, UnitClass(unit)))
end

---------------------------------------------------------------------------
-- Temps restant de ma bénédiction sur un joueur (lu hors combat ; en combat, la dernière valeur lue continue
-- de décompter : le jeu y cache les auras)
---------------------------------------------------------------------------
local seen = {} -- [nom..":"..n°] = expiration (GetTime), 0 = sans fin
local function scanLeft(unit, b)
    local ids = M.BLESS[b]
    if not ids then return nil end
    local names = {}
    for _, id in ipairs(ids) do local n = WK.SpellInfo(id); if n then names[n] = true end end
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
function M:Left(unit, b)
    local name = fullName(unit)
    if not name then return nil end
    local key = name .. ":" .. b
    if not inCombat() and UnitIsVisible and UnitIsVisible(unit) then
        local exp = scanLeft(unit, b)
        if exp ~= nil then seen[key] = exp or nil end
    end
    local exp = seen[key]
    if exp == nil then return nil end
    if exp == 0 then return math.huge end
    local left = exp - now()
    if left <= 0 then seen[key] = nil return nil end
    return left
end

-- État pour la barre : une ligne par classe présente (et une par exception), membres, manquants, plus court
function M:Status()
    local rows, byClass = {}, {}
    local c = self:Me()
    for _, u in ipairs(groupUnits()) do
        if UnitExists(u) and UnitIsPlayer(u) then
            local name = fullName(u)
            local cl = select(2, UnitClass(u))
            local b = self:ForUnit(u)
            if name and cl and b then
                local ex = c.except[name] ~= nil
                local key = ex and ("x:" .. name) or cl
                local r = byClass[key]
                if not r then
                    r = { class = cl, b = b, members = {}, missing = 0, except = ex and name or nil }
                    byClass[key] = r
                    table.insert(rows, r)
                end
                local dead = UnitIsDeadOrGhost(u) or not UnitIsConnected(u)
                local left = (not dead) and self:Left(u, b) or nil
                table.insert(r.members, { unit = u, name = name, left = left, dead = dead })
                if not dead and not left then r.missing = r.missing + 1 end
                if left and (not r.min or left < r.min) then r.min = left end
            end
        end
    end
    table.sort(rows, function(a, b2)
        if (a.except ~= nil) ~= (b2.except ~= nil) then return a.except == nil end
        return (self.CLASS_ID[a.class] or 99) < (self.CLASS_ID[b2.class] or 99)
    end)
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
local queue, sending, lastMsg = {}, false, nil
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
local function send(msg, target, prefix)
    if not channel() then return end
    if not target and msg == lastMsg then return end
    lastMsg = not target and msg or lastMsg
    if #queue > 40 then return end
    table.insert(queue, { msg = msg, target = target, prefix = prefix or PREFIX })
    if not sending then pump() end
end
M.Send = send

-- Mon état : bénédictions connues, attribution par classe, aure, exceptions, assignation libre
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
        if e then e.assign = e.assign or {}; e.assign[ci] = b end
        send(string.format("ASSIGN %s %d %d", name, ci, b))
    end
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
        if e then e.aura = a end
        send(string.format("AASSIGN %s %d", name, a))
    end
    if self.OnChange then self:OnChange() end
    return true
end
function M:SetMode(mode)
    local c = self:Me()
    c.mode = mode
    if mode == "auto" then self:AutoAssign() end
    self:SendSelf()
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
    local e = entryOf(sender)
    if msg == "REQ" then self:SendSelf(sender) return end
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
        name, ci, b = bare(name), tonumber(ci), tonumber(b)
        if not allowed(sender, name) then return end
        if name == me() then applyMine(ci, b) else entryOf(name).assign[ci] = b end
        return true
    end
    local pn, p9 = msg:match("^PASSIGN (.+)@([0-9n]*)$")
    if pn then
        pn = bare(pn)
        if not allowed(sender, pn) then return end
        local list = chars9(p9)
        if pn == me() then for i, v in ipairs(list) do self:Me().mine[i] = v end applyMine() else entryOf(pn).assign = list end
        return true
    end
    local mn, mb = msg:match("^MASSIGN (.+) (%d+)$")
    if mn then
        mn, mb = bare(mn), tonumber(mb)
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
        aun, aua = bare(aun), tonumber(aua)
        if not allowed(sender, aun) then return end
        if aun == me() then self:Me().aura = aua; applyMine() else entryOf(aun).aura = aua end
        return true
    end
    if msg:find("FREEASSIGN YES") then e.free = true end
    if msg:find("FREEASSIGN NO") then e.free = false end
    if msg:find("^CLEAR") and isLeader(sender) then
        for _, pe in pairs(pallys) do pe.assign = {} end
        local c = self:Me()
        c.mine = {}
        if not msg:find("SKIP") then c.aura = 0 end
        applyMine()
    end
    return true
end

---------------------------------------------------------------------------
-- Évènements
---------------------------------------------------------------------------
local function changed()
    if M.OnChange then M:OnChange() end
end
local rosterPending
local function onRoster()
    if rosterPending then return end
    rosterPending = true
    C_Timer.After(1.5, function()
        rosterPending = false
        if not M:On() then return end
        prune()
        M:AutoAssign()
        if channel() then M:SendSelf(); M:Request() end
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
WK:On("GROUP_ROSTER_UPDATE", onRoster)
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
        if mode then local e = entryOf(sender); e.wk = true; e.auto = mode == "auto" end
        M:AutoAssign()
        changed()
        return
    end
    local ok = M:Receive(sender, msg)
    if ok then M:AutoAssign(); changed() end
end)

-- Pour les tests
M._reset = function() for k in pairs(pallys) do pallys[k] = nil end; myName = nil; wipe(seen) end
