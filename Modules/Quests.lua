local ADDON_NAME, WK = ...
local M = WK:NewModule("Quests")
local T = function(s) return WK.T(s) end

-- Quêtes (données Modules/QuestsDB.lua, tirées de QuestieDB) : quêtes de chaque zone pour chaque
-- perso (faites, dans le journal, disponibles, à venir), meilleure zone pour monter, guidage vers
-- le donneur, infobulle du donneur.
-- Quêtes faites et journal : WK.DB.global.characters[perso].quests = { done = {[id]=true}, log = {[id]=true} },
-- relus à la connexion et à chaque quête rendue.
-- Réglages : WK.DB.global.quests.

local DEFAULTS = { dungeons = true, profOnly = true, high = true, classOnly = true, tooltip = true }
function M:Config()
    local g = WK.DB.global
    g.quests = g.quests or {}
    for k, v in pairs(DEFAULTS) do if g.quests[k] == nil then g.quests[k] = v end end
    return g.quests
end

local RACE_BIT = { Human = 1, Orc = 2, Dwarf = 4, NightElf = 8, Scourge = 16, Tauren = 32, Gnome = 64, Troll = 128 }
local CLASS_BIT = { WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16, SHAMAN = 64, MAGE = 128,
                    WARLOCK = 256, DRUID = 1024 }

-- Index : quête par numéro, quêtes par donneur. Pas de copie des lignes de la base : chaque ligne reçoit une
-- métatable qui lit ses champs par nom (q.name = ligne[2]…), la carte venant d'une petite table à part.
local byID, byStarter
local FIELD = { id = 1, name = 2, nameFR = 3, lvl = 4, req = 5, side = 6, cls = 7, kind = 8, skill = 9, x = 10, y = 11,
    sid = 12, xp = 13, pre = 14, preAll = 15, nxt = 16, smap = 17, grp = 18,
    -- excl = fermée si une de ces quêtes est prise ou faite (exclusives, suite, quête annoncée), maxLvl, rep =
    -- { faction, réputation min }, prev = une de ces quêtes avant (tirée de la chaîne),
    -- races = masque (sinon toute la faction)
    excl = 19, maxLvl = 20, rep = 21, prev = 22, races = 23 }
local mapOf = {}
-- quête de groupe (monstre élite à tuer, d'après le rang des monstres de QuestieDB ; tools/gen_quests.py)
function WK.QuestIsGroup(qid)
    local Q = WK.modules.Quests
    local q = Q and Q:Get(qid)
    return q ~= nil and q.grp == 1
end
local QMETA = { __index = function(t, k)
    if k == "map" then return mapOf[rawget(t, 1)] end
    if k == "xp" then return rawget(t, 13) or 0 end
    local i = FIELD[k]
    return i and rawget(t, i) or nil
end }
local function index()
    byID, byStarter = {}, {}
    for mapID, list in pairs(WK.QuestsDB or {}) do
        for _, q in ipairs(list) do
            setmetatable(q, QMETA)
            local id = q[1]
            mapOf[id] = mapID
            byID[id] = q
            local sid = q[12]
            if sid then
                byStarter[sid] = byStarter[sid] or {}
                table.insert(byStarter[sid], q)
            end
        end
    end
    -- quêtes sans zone connue (tools/gen_quests.py) : dans l'index (totaux, état, infobulles), sur aucune carte
    for _, q in ipairs(WK.QuestsOther or {}) do
        setmetatable(q, QMETA)
        if not byID[q[1]] then byID[q[1]] = q end
    end
    if M.AddLearned then M.AddLearned(byID, byStarter, mapOf, QMETA) end
end
-- l'index sera refait au prochain accès (quête apprise en jeu)
local memo = { zones = {}, totals = {}, at = -10 } -- zones et totaux gardés 1 s (M:Zones, M:Totals)
function M:Reindex() byID = nil; memo.at = -10 end
function M:Get(id)
    if not byID then index() end
    return byID[id]
end
function M:Name(q)
    if not q then return "?" end
    return (WK.Lang() == "frFR" and q.nameFR) or q.name
end
function M:OnMap(mapID)
    if not byID then index() end
    local out = {}
    for _, e in ipairs((WK.QuestsDB or {})[mapID] or {}) do table.insert(out, byID[e[1]] or e) end
    return out
end
function M:ByStarter(sid)
    if not byID then index() end
    return byStarter[sid] or {}
end

---------------------------------------------------------------------------
-- Quêtes faites et journal du perso connecté
---------------------------------------------------------------------------
local function store()
    local c = WK.DB:Me()
    if not c then return end
    memo.at = -10 -- quêtes faites ou journal relus : zones et totaux recalculés
    c.quests = c.quests or {}
    local done = {}
    local ok = false
    if C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs then
        local okC, ids = pcall(C_QuestLog.GetAllCompletedQuestIDs)
        if okC and type(ids) == "table" then
            for _, id in ipairs(ids) do done[id] = true end
            ok = true
        end
    end
    if not ok and GetQuestsCompleted then
        local okC, t = pcall(GetQuestsCompleted)
        if okC and type(t) == "table" then
            for id in pairs(t) do done[id] = true end
            ok = true
        end
    end
    if ok then
        c.quests.done = done
        local n = 0
        for _ in pairs(done) do n = n + 1 end
        c.quests.doneN = n -- quêtes faites : une de plus = les quêtes « pas proposées » sont retentées
    end
    local log = {}
    local n = (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries())
              or (GetNumQuestLogEntries and GetNumQuestLogEntries()) or 0
    for i = 1, n do
        local id
        if C_QuestLog and C_QuestLog.GetInfo then
            local info = C_QuestLog.GetInfo(i)
            if info and not info.isHeader then id = info.questID end
        elseif GetQuestLogTitle then
            local _, _, _, isHeader, _, _, _, qid = GetQuestLogTitle(i)
            if not isHeader then id = qid end
        end
        if id and id > 0 then log[id] = true end
    end
    c.quests.log = log
    c.quests.at = time()
    if M.OnChange then M:OnChange() end
    WK:NotifyChanged()
end
M.Store = store
local pending
local function storeSoon()
    if pending then return end
    pending = true
    C_Timer.After(1, function() pending = nil; pcall(store) end)
end
WK:On("PLAYER_LOGIN", function() C_Timer.After(3, function() pcall(store) end) end)
WK:On("QUEST_TURNED_IN", storeSoon)
WK:On("QUEST_ACCEPTED", storeSoon)
WK:On("QUEST_REMOVED", storeSoon)

---------------------------------------------------------------------------
-- État d'une quête pour un perso
---------------------------------------------------------------------------
local function charOf(key)
    return WK.DB.global.characters[key or WK:CharKey()] or {}
end
local function hasProf(c, prof)
    return c.professions and c.professions[prof] ~= nil
end

-- La quête concerne-t-elle ce perso ? (faction, classe, métier selon les réglages)
-- anyKind : quête de donjon gardée même si « Quêtes de donjon » est coupé (onglet LFG, donjon choisi)
function M:ForChar(q, c, anyKind)
    if q.side then
        local f = c.faction
        if f == "Alliance" and q.side ~= 1 then return false end
        if f == "Horde" and q.side ~= 2 then return false end
    end
    -- variante réservée à d'autres races (Appel de la Terre, Dompter la bête…)
    if q.races and c.race then
        local bit = RACE_BIT[c.race]
        if bit and (math.floor(q.races / bit) % 2) == 0 then return false end
    end
    local cfg = self:Config()
    if q.cls and cfg.classOnly then
        local bit = CLASS_BIT[c.class or ""]
        if bit and (math.floor(q.cls / bit) % 2) == 0 then return false end
    end
    if q.kind == "d" and not cfg.dungeons and not anyKind then return false end
    if q.skill and cfg.profOnly and not hasProf(c, q.skill) then return false end
    return true
end

-- réputation du perso connecté avec une faction (valeur absolue du jeu, nil si inconnue)
local function repValue(faction)
    local fn = GetFactionInfoByID
    if not fn then return nil end
    local ok, name, _, _, _, _, value = pcall(fn, faction)
    if ok and name and type(value) == "number" then return value end
    return nil
end
-- "done", "log", "avail", "high" (niveau trop bas), "locked" (quête d'avant pas faite),
-- "closed" (plus proposée : autre variante ou suite prise, niveau max dépassé, réputation trop basse ;
-- 2e valeur : "excl" + quête, "maxlvl", "rep")
function M:State(q, c)
    local qs = c.quests or {}
    if qs.done and qs.done[q.id] then return "done" end
    if qs.log and qs.log[q.id] then return "log" end
    local done = qs.done or {}
    if q.excl then
        local log = qs.log or {}
        for _, x in ipairs(q.excl) do
            if done[x] or log[x] then return "closed", "excl", x end
        end
    end
    if q.maxLvl and (c.level or 1) > q.maxLvl then return "closed", "maxlvl" end
    if q.rep and c == WK.DB:Me() then
        local v = repValue(q.rep[1])
        if v and v < (q.rep[2] or 0) then return "closed", "rep" end
    end
    if (q.req or 0) > (c.level or 1) then return "high" end
    -- le donneur ne l'a pas proposée (appris en jeu) : prérequis inconnu de la base, retentée au niveau suivant
    -- ou dès qu'une autre quête est rendue
    local no = qs.notOffered and qs.notOffered[q.id]
    if no and no.lvl == (c.level or 1) and no.n == (qs.doneN or 0) then return "locked", nil, "notoffered" end
    if q.preAll then
        for _, p in ipairs(q.preAll) do if not done[p] and self:Get(p) then return "locked", p end end
    end
    if q.pre then
        local any, first = false, nil
        for _, p in ipairs(q.pre) do
            if done[p] or not self:Get(p) then any = true break end
            first = first or p
        end
        if not any then return "locked", first end
    end
    -- quête d'avant apprise en jeu (WK.DB.global.questChains) quand la base n'en donne aucune
    if not (q.pre or q.preAll or q.prev) then
        local ch = WK.DB.global.questChains and WK.DB.global.questChains[q.id]
        -- « follow » (quête proposée juste après un rendu) : seulement après 2 confirmations, une seule pouvant venir
        -- d'un PNJ qui donne plusieurs quêtes sans lien entre elles
        local sure = ch and (ch.how ~= "follow" or (ch.n or 1) >= 2)
        if sure and ch.pre and not done[ch.pre] and self:Get(ch.pre) then return "locked", ch.pre, "learned" end
    end
    if q.prev then
        local any, first = false, nil
        for _, p in ipairs(q.prev) do
            if done[p] or not self:Get(p) then any = true break end
            first = first or p
        end
        if not any then return "locked", first end
    end
    return "avail"
end
function M:Known(key) return charOf(key).quests and charOf(key).quests.done ~= nil end

---------------------------------------------------------------------------
-- Zones (page Quêtes)
---------------------------------------------------------------------------
-- { { map, name, total, done, avail, xp (dispo), min, max } } pour un perso
-- Zones et totaux gardés 1 s par perso : un rafraîchissement de page les demande plusieurs fois (liste des zones,
-- meilleure zone, chiffres du bandeau) ; vidés à chaque changement d'index (M:Reindex)
local function memoFresh()
    local now = _G.GetTime and _G.GetTime() or 0
    if now - memo.at > 1 or now < memo.at then
        memo.zones, memo.totals, memo.at = {}, {}, now
    end
end
function M:Zones(key)
    memoFresh()
    local mk = key or WK:CharKey()
    if memo.zones[mk] then return memo.zones[mk] end
    local out = self:ZonesNow(key)
    memo.zones[mk] = out
    return out
end
function M:ZonesNow(key)
    local c = charOf(key)
    local R = WK.modules.Rares
    local lvl = c.level or 1
    local out = {}
    for mapID in pairs(WK.QuestsDB or {}) do
        -- near / nearXP : quêtes à prendre à ton niveau (± 3), pour la meilleure zone et le bandeau de la page
        local z = { map = mapID, name = R:ZoneName(mapID), total = 0, done = 0, avail = 0, xp = 0, min = 99, max = 0,
            near = 0, nearXP = 0 }
        for _, q in ipairs(self:OnMap(mapID)) do
            if self:ForChar(q, c) then
                local st = self:State(q, c)
                if st ~= "closed" then z.total = z.total + 1 end
                if st == "done" then z.done = z.done + 1
                elseif st == "avail" or st == "log" then z.avail = z.avail + 1; z.xp = z.xp + (q.xp or 0) end
                if st == "avail" and (q.lvl or 0) >= lvl - 3 and (q.lvl or 0) <= lvl + 3 then
                    z.near, z.nearXP = z.near + 1, z.nearXP + (q.xp or 0)
                end
                if q.kind ~= "d" and (q.lvl or 0) > 0 then
                    z.min, z.max = math.min(z.min, q.lvl), math.max(z.max, q.lvl)
                end
            end
        end
        if z.min > z.max then z.min, z.max = z.max, z.max end
        if z.total > 0 then table.insert(out, z) end
    end
    table.sort(out, function(a, b) if a.min ~= b.min then return a.min < b.min end return a.name < b.name end)
    return out
end
function M:Totals(key)
    memoFresh()
    local mk = key or WK:CharKey()
    local m = memo.totals[mk]
    if m then return m[1], m[2], m[3], m[4], m[5] end
    local r = { self:TotalsNow(key) }
    memo.totals[mk] = r
    return r[1], r[2], r[3], r[4], r[5]
end
function M:TotalsNow(key)
    local c = charOf(key)
    if not byID then index() end
    local total, done, avail = 0, 0, 0
    for _, q in pairs(byID) do
        if self:ForChar(q, c) then
            local st = self:State(q, c)
            if st ~= "closed" then total = total + 1 end
            if st == "done" then done = done + 1 elseif st == "avail" then avail = avail + 1 end
        end
    end
    -- quêtes faites absentes de la base (propres à WoW Forever, ou d'une autre zone que la base ne range pas) :
    -- comptées dans les faites et dans le total, comme le jeu les compte
    local qs = c.quests and c.quests.done
    if qs then
        for id in pairs(qs) do
            if not byID[id] then done = done + 1; total = total + 1 end
        end
    end
    return done, total, avail
end
-- Zone du joueur qui a des quêtes (ou sa carte parente)
function M:PlayerZone()
    if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
    local id, guard = C_Map.GetBestMapForUnit("player"), 0
    while id and guard < 5 do
        if (WK.QuestsDB or {})[id] then return id end
        local ok, i = pcall(C_Map.GetMapInfo, id)
        id, guard = ok and i and i.parentMapID, guard + 1
    end
    return nil
end
-- Meilleure zone pour monter : celle qui a le plus d'XP disponible à son niveau
function M:BestZone(key)
    local best, bestXP
    for _, z in ipairs(self:Zones(key)) do
        local xp = z.nearXP or 0 -- calculé avec la liste des zones (au lieu d'un second parcours de la base)
        if xp > 0 and (not bestXP or xp > bestXP) then best, bestXP = z, xp end
    end
    return best, bestXP
end

---------------------------------------------------------------------------
-- Guidage vers le donneur
---------------------------------------------------------------------------
function M:GuideTo(q)
    if not q.x then return end
    local G = WK.modules.Guide
    local map = q.smap or q.map
    local t = { map = map, x = q.x / 100, y = q.y / 100 }
    t.cont, t.wx, t.wy = G.ToWorld(map, t.x, t.y)
    local p = G:PlayerPos()
    t.distance = p and G:Vector(p, t) or nil
    t.e = { q.x, q.y, 0, nil, nil, q.name, q.nameFR or q.name, T("Quête") }
    G:Start(t, "Quête", "quest")
end

---------------------------------------------------------------------------
-- Infobulle d'un donneur de quêtes : ses quêtes pas encore faites par ce perso
---------------------------------------------------------------------------
local STATE_COL = { avail = "ffd200", log = "9ed17a", high = "e06666", locked = "7aa6db" }
local function onUnitTooltip(tooltip)
    if tooltip ~= GameTooltip or not M:Config().tooltip or not WK:FeatureOn("quests") then return end
    local R = WK.modules.Rares
    local unit = R.Readable(select(2, tooltip:GetUnit()))
    if not unit then return end
    local id = R.NpcID(unit)
    if not id then return end
    local list = M:ByStarter(id)
    if #list == 0 then return end
    local c = charOf()
    local lines = {}
    for _, q in ipairs(list) do
        if M:ForChar(q, c) then
            local st = M:State(q, c)
            -- « closed » (quête exclusive, niveau max, réputation) : pas proposée, et pas de couleur (sans ce test,
            -- l'erreur faisait disparaître tout le bloc des quêtes de l'infobulle)
            if st ~= "done" and st ~= "closed" and STATE_COL[st] then
                local tag = st == "log" and (" · " .. T("dans le journal")) or st == "high" and (" · " .. string.format(T("niveau %d"), q.req))
                            or st == "locked" and (" · " .. T("plus tard")) or ""
                table.insert(lines, "|cff" .. STATE_COL[st] .. "[" .. q.lvl .. "] " .. M:Name(q) .. tag .. "|r")
            end
        end
    end
    if #lines == 0 then return end
    tooltip:AddLine(" ")
    tooltip:AddLine(WK:Tag() .. "  " .. string.format(T("%d quêtes"), #lines))
    for i, l in ipairs(lines) do
        if i > 5 then tooltip:AddLine("|cff999999+" .. (#lines - 5) .. "|r") break end
        tooltip:AddLine(l)
    end
    tooltip:Show()
end
if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tt) pcall(onUnitTooltip, tt) end)
elseif GameTooltip then
    GameTooltip:HookScript("OnTooltipSetUnit", function(tt) pcall(onUnitTooltip, tt) end)
end

---------------------------------------------------------------------------
-- Quêtes apprises en jeu : celles que la base ne connaît pas (nouvelles quêtes de WoW Forever) sont notées
-- quand tu les vois chez un PNJ ou les prends : nom, niveau, donneur et sa position, donneur de rendu,
-- donjon. Elles entrent dans l'index comme les autres (cartes, totaux, tournée, quêtes du donjon).
--   WK.DB.global.questLearn[n°] = { n = nom, l = niveau, s = camp (1 Alliance, 2 Horde), k = "d" (donjon),
--     z = carte de la zone, g = { npc, map, x, y } (donneur ; npc < 0 = objet), t = { npc, map, x, y } (rendu), at }
-- (hors profils ; quelques milliers au plus : une par quête du jeu)
---------------------------------------------------------------------------
local function learnStore()
    local g = WK.DB.global
    g.questLearn = g.questLearn or {}
    return g.questLearn
end
M.LearnStore = learnStore
-- Quêtes répétables : absentes de la base générée, elles ne doivent jamais être « apprises » comme nouvelles
-- (sinon proposées pour toujours et prises par l'acceptation auto). Liste de la base (WK.QuestRepeatable,
-- générée par gen_quests.py), sinon ce que dit le jeu.
local repSet
function M.IsRepeatable(_, id)
    if not repSet then
        repSet = {}
        for n in (WK.QuestRepeatable or ""):gmatch("%d+") do repSet[tonumber(n)] = true end
    end
    if repSet[id] then return true end
    local ql = _G.C_QuestLog
    if ql and ql.IsRepeatableQuest then
        local ok, r = pcall(ql.IsRepeatableQuest, id)
        if ok and r then return true end
    end
    return false
end
local learnedRows = {}
function M.AddLearned(byID_, byStarter_, mapOf_, meta)
    local learned = learnStore()
    -- répétables notées par erreur avant cette correction : retirées
    for id in pairs(learned) do
        if M:IsRepeatable(id) then learned[id] = nil end
    end
    -- quête apprise supprimée depuis (répétable, purge) : sa ligne sort aussi de la liste de sa zone (avant, elle
    -- restait affichée jusqu'au /reload)
    for id, row in pairs(learnedRows) do
        if not learned[id] then
            local list = row.inList and WK.QuestsDB and WK.QuestsDB[row.inList]
            for k = #(list or {}), 1, -1 do if list[k] == row then table.remove(list, k) end end
            learnedRows[id] = nil
        end
    end
    for id, e in pairs(learned) do
        local base = byID_[id]
        if e.n and (not base or base.learned) then
            local g = e.g or {}
            local row = learnedRows[id]
            if not row then
                row = setmetatable({ learned = true }, meta)
                learnedRows[id] = row
            end
            row[1], row[2], row[4], row[6], row[8] = id, e.n, e.l or 0, e.s, e.k
            -- position du donneur : seulement si elle est sur la carte de la zone
            if g.x and g.map == e.z then row[10], row[11] = g.x * 100, g.y * 100 else row[10], row[11] = nil, nil end
            row[12], row[13] = g.npc, 0
            byID_[id] = row
            local map = e.z
            if map and WK.QuestsDB then
                local list = WK.QuestsDB[map]
                if not list then list = {}; WK.QuestsDB[map] = list end
                if not row.inList then table.insert(list, row); row.inList = map end
                mapOf_[id] = map
            end
            if g.npc then
                byStarter_[g.npc] = byStarter_[g.npc] or {}
                local found = false
                for _, q in ipairs(byStarter_[g.npc]) do if q == row then found = true end end
                if not found then table.insert(byStarter_[g.npc], row) end
            end
        end
    end
end
-- vrai si la quête est dans la base générée (pas seulement apprise)
local function inBase(id)
    local q = M:Get(id)
    return q ~= nil and not q.learned
end
-- carte de la zone (on remonte des sous-zones, grottes, quartiers) et position du joueur dessus
local function zonePos()
    if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
    local map = C_Map.GetBestMapForUnit("player")
    local info = map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
    local guard = 0
    while info and (info.mapType or 3) > 3 and info.mapType ~= 4 and (info.parentMapID or 0) > 0 and guard < 4 do
        map = info.parentMapID
        info = C_Map.GetMapInfo(map)
        guard = guard + 1
    end
    local pos = map and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
    local x, y
    if pos and pos.GetXY then x, y = pos:GetXY() end
    if type(x) ~= "number" or type(y) ~= "number" or (x == 0 and y == 0) then x, y = nil, nil end
    return map, x, y
end
local function unitNpc(unit)
    local guid = UnitGUID and UnitGUID(unit)
    if type(guid) ~= "string" then return nil end
    local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    id = tonumber(id)
    if not id then return nil end
    if kind == "GameObject" then return -id end
    if kind == "Creature" then return id end
    return nil
end
local function where()
    local npc = unitNpc("questnpc") or unitNpc("npc")
    local Dg = WK.modules.Dungeons
    local d = Dg and Dg.Current and Dg:Current()
    if d then return { npc = npc }, d end
    local map, x, y = zonePos()
    return { npc = npc, map = map, x = x and math.floor(x * 10000 + 0.5) / 10000, y = y and math.floor(y * 10000 + 0.5) / 10000 }, nil
end
local function side()
    local f = UnitFactionGroup and UnitFactionGroup("player")
    return f == "Alliance" and 1 or f == "Horde" and 2 or nil
end
local function entry(id, create)
    local st = learnStore()
    local e = st[id]
    if not e and create then
        local n = 0
        for _ in pairs(st) do n = n + 1 end
        if n >= 4000 then return nil end
        e = { at = time(), s = side() }
        st[id] = e
    end
    return e
end
local function changed() M:Reindex(); WK:NotifyChanged() end
-- quête montrée par un PNJ (ou un objet) : nom, donneur, position
local function learnGiver()
    local id = GetQuestID and GetQuestID()
    if type(id) ~= "number" or id <= 0 or inBase(id) then return end
    local daily = (_G.QuestIsDaily and _G.QuestIsDaily()) or (_G.QuestIsWeekly and _G.QuestIsWeekly())
    if daily or M:IsRepeatable(id) then
        if learnStore()[id] then learnStore()[id] = nil; changed() end
        return
    end
    local e = entry(id, true)
    if not e then return end
    local title = GetTitleText and GetTitleText()
    if type(title) == "string" and title ~= "" then e.n = title end
    local g, d = where()
    if g.npc or g.map then e.g = g end
    if d then e.k, e.z = "d", d.entry and d.entry[1] or nil
    elseif g.map then e.z = e.z or g.map end
    changed()
end
WK:On("QUEST_DETAIL", function() pcall(learnGiver) end)
-- quête prise : niveau et nom lus dans le journal
WK:On("QUEST_ACCEPTED", function(a, b)
    local id = (type(b) == "number" and b) or (type(a) == "number" and a > 100 and a) or nil
    if not id or inBase(id) or M:IsRepeatable(id) then return end
    C_Timer.After(0.5, function()
        local idx = C_QuestLog and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(id)
        local info = idx and C_QuestLog.GetInfo and C_QuestLog.GetInfo(idx)
        -- quête journalière ou hebdomadaire d'après le journal : pas notée
        if type(info) == "table" and ((tonumber(info.frequency) or 0) > 0 or info.isRepeatable) then
            if learnStore()[id] then learnStore()[id] = nil; changed() end
            return
        end
        local e = entry(id, true)
        if not e then return end
        if type(info) == "table" then
            if type(info.level) == "number" and info.level > 0 then e.l = info.level end
            if type(info.title) == "string" and info.title ~= "" then e.n = e.n or info.title end
        end
        if not e.n and C_QuestLog and C_QuestLog.GetTitleForQuestID then
            local t = C_QuestLog.GetTitleForQuestID(id)
            if type(t) == "string" and t ~= "" then e.n = t end
        end
        local fresh = not e.told
        e.told = true
        changed()
        if fresh and e.n then WK:Print(string.format(T("Quête notée : %s (nouvelle, absente de la base de quêtes)."), e.n)) end
    end)
end)
-- quête rendue : PNJ et position du rendu
local function learnTurnIn()
    local id = GetQuestID and GetQuestID()
    if type(id) ~= "number" or id <= 0 or inBase(id) then return end
    local e = entry(id, false)
    if not e then return end
    local t = where()
    if t.npc or t.map then e.t = t; changed() end
end
WK:On("QUEST_COMPLETE", function() pcall(learnTurnIn) end)
function M:LearnedCount()
    local n = 0
    for _, e in pairs(learnStore()) do if e.n then n = n + 1 end end
    return n
end

---------------------------------------------------------------------------
-- Quêtes que le donneur ne propose pas (prérequis absents de la base, fréquent pour le nouveau contenu de
-- WoW Forever) : à l'ouverture du dialogue d'un PNJ (GOSSIP_SHOW, QUEST_GREETING), ses quêtes que la base dit
-- disponibles mais qu'il ne montre pas sont notées dans characters[perso].quests.notOffered[n°] = { lvl, n, at }
-- (niveau et nombre de quêtes faites du moment) ; State les dit « locked » tant que ni le niveau ni le nombre
-- de quêtes faites n'ont changé. La tournée les retire (elles reviennent d'elles-mêmes quand elles sont proposées).
---------------------------------------------------------------------------
local function npcOf(guid)
    if type(guid) ~= "string" then return nil end
    local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    if kind ~= "Creature" then return nil end
    return tonumber(id)
end
-- offered = { [n°] = true }, titles = { [titre en minuscules] = true } : ce que le PNJ montre
local offeredBy = {} -- [PNJ] = { at, ids = { [n°] = true } } : dernière liste vue chez ce PNJ (chaînes « follow »)
function M:NoteOffered(npc, offered, titles)
    if not npc or not WK:FeatureOn("quests") then return {} end
    memo.at = -10
    local seen = {}
    for id in pairs(offered or {}) do seen[id] = true end
    offeredBy[npc] = { at = _G.GetTime and _G.GetTime() or 0, ids = seen }
    local c = WK.DB:Me()
    if not c then return {} end
    c.quests = c.quests or {}
    local qs = c.quests
    qs.notOffered = qs.notOffered or {}
    local lvl = (_G.UnitLevel and _G.UnitLevel("player")) or c.level or 1
    local newly = {}
    for _, q in ipairs(self:ByStarter(npc)) do
        local shown = offered[q.id] or (q.name and titles[q.name:lower()]) or (q.nameFR and titles[q.nameFR:lower()])
        if shown then
            -- pas proposée avant, proposée maintenant, au même niveau, après un rendu : ce rendu la débloquait
            local was = qs.notOffered[q.id]
            local last = M.lastTurnIn
            -- un seul rendu depuis la note (sinon la quête d'avant retenue, le dernier rendu, pouvait être autre)
            local oneTurnIn = was and ((qs.doneN or 0) - (was.n or 0)) == 1
            if was and was.lvl == lvl and oneTurnIn and last and last.at >= (was.at or 0) and last.id ~= q.id then
                local tok = WK:CharKey() .. ":" .. tostring(last.at) .. ":" .. tostring(last.id)
                self:LearnChain(q.id, last.id, "unlock", tok)
            end
            qs.notOffered[q.id] = nil
        elseif self:ForChar(q, c) then
            local was = qs.notOffered[q.id]
            qs.notOffered[q.id] = nil
            -- quête grise (bien sous ton niveau) : le jeu la cache si le suivi des quêtes de bas niveau est coupé ;
            -- pas notée « pas proposée » (elle disparaissait de la tournée « Compléter la zone »)
            local green = (_G.GetQuestGreenRange and _G.GetQuestGreenRange()) or 8
            local grey = (q.lvl or 0) > 0 and (q.lvl or 0) < lvl - green
            if not grey and self:State(q, c) == "avail" then
                qs.notOffered[q.id] = { lvl = lvl, n = qs.doneN or 0, at = _G.time() }
                if not was or was.lvl ~= lvl or was.n ~= (qs.doneN or 0) then table.insert(newly, q) end
            end
        end
    end
    if #newly > 0 then
        local P = WK.modules.QuestPlan
        if P then
            P:Invalidate()
            if P:Tour() and P.Reorder then pcall(P.Reorder, P) end
        end
        local names = {}
        for _, q in ipairs(newly) do names[#names + 1] = self:Name(q) end
        WK:Print(string.format(
            T("Pas encore proposée par ce PNJ : %s (une quête d'avant doit manquer) ; retirée de la tournée."),
            table.concat(names, ", ")))
        WK:NotifyChanged()
    end
    return newly
end
WK:On("GOSSIP_SHOW", function()
    local G = _G.C_GossipInfo
    if not (G and G.GetAvailableQuests) then return end
    local ok, avail = pcall(G.GetAvailableQuests)
    if not ok or type(avail) ~= "table" then return end
    local offered, titles = {}, {}
    for _, q in ipairs(avail) do
        if q.questID then offered[q.questID] = true end
        if q.title then titles[q.title:lower()] = true end
    end
    M:NoteOffered(npcOf(_G.UnitGUID and _G.UnitGUID("npc")), offered, titles)
end)
WK:On("QUEST_GREETING", function()
    local offered, titles = {}, {}
    for i = 1, (_G.GetNumAvailableQuests and _G.GetNumAvailableQuests() or 0) do
        local qid = _G.GetAvailableQuestInfo and select(5, _G.GetAvailableQuestInfo(i))
        if qid then offered[qid] = true end
        local t = _G.GetAvailableTitle and _G.GetAvailableTitle(i)
        if t then titles[t:lower()] = true end
    end
    M:NoteOffered(npcOf(_G.UnitGUID and _G.UnitGUID("npc")), offered, titles)
end)

---------------------------------------------------------------------------
-- Chaînes apprises en jeu (point 3) : quand la base ne connaît pas la quête d'avant, l'addon la déduit de ce
-- que tu fais. WK.DB.global.questChains[n°] = { pre = n°, n = confirmations, at, how } (hors profils, tout le
-- compte : un perso apprend pour les autres). Deux indices :
--   « follow » : juste après avoir rendu une quête à un PNJ (moins de 30 s), ce même PNJ propose une quête ;
--   « unlock » : une quête notée « pas proposée » devient proposée au même niveau après un rendu.
-- State la dit « locked » (3e valeur « learned ») tant que la quête d'avant n'est pas faite. /wk chaines liste
-- ce qui a été appris (à envoyer pour l'ajouter aux corrections de la base).
---------------------------------------------------------------------------
local MAXCH = 1500
-- tok (facultatif) : identifiant du rendu qui a donné l'indice ; un même rendu ne compte qu'une fois (rouvrir
-- deux fois le détail de la quête donnait sinon les 2 confirmations à lui seul)
function M:LearnChain(qid, pre, how, tok)
    memo.at = -10
    local q = self:Get(qid)
    if not q or q.pre or q.preAll or q.prev or not pre or pre == qid then return end
    local g = WK.DB.global
    g.questChains = g.questChains or {}
    local ch = g.questChains[qid]
    if ch and ch.pre == pre then
        if tok and ch.tok == tok then return end
        ch.n = (ch.n or 1) + 1; ch.at = _G.time(); ch.tok = tok
    elseif not ch or (ch.n or 1) <= 1 then
        g.questChains[qid] = { pre = pre, n = 1, at = _G.time(), how = how, tok = tok }
        local pq = self:Get(pre)
        WK:Print(string.format(T("Chaîne apprise : « %s » vient après « %s »."), self:Name(q),
            pq and self:Name(pq) or ("#" .. pre)))
    end
    local n = 0
    for _ in pairs(g.questChains) do n = n + 1 end
    if n > MAXCH then
        local oldK, oldT
        for k, v in pairs(g.questChains) do if not oldT or (v.at or 0) < oldT then oldK, oldT = k, v.at or 0 end end
        if oldK then g.questChains[oldK] = nil end
    end
    local P = WK.modules.QuestPlan
    if P then P:Invalidate() end
end
function M.ChainList(_)
    local out = {}
    for qid, ch in pairs(WK.DB.global.questChains or {}) do
        table.insert(out, { id = qid, pre = ch.pre, n = ch.n or 1, how = ch.how })
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end
local function npcNow()
    local guid = _G.UnitGUID and _G.UnitGUID("npc")
    if type(guid) ~= "string" then return nil end
    local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    return kind == "Creature" and tonumber(id) or nil
end
-- PNJ du rendu noté à la fenêtre de récompense (le PNJ est encore là), quête rendue à QUEST_TURNED_IN ; avec la
-- liste des quêtes que ce PNJ proposait déjà avant le rendu (une quête déjà proposée n'en est pas la suite)
local rewardNpc
WK:On("QUEST_COMPLETE", function() rewardNpc = npcNow() end)
WK:On("QUEST_TURNED_IN", function(qid)
    local before = rewardNpc and offeredBy[rewardNpc]
    local fresh = before and (_G.GetTime and _G.GetTime() or 0) - before.at < 300
    M.lastTurnIn = { id = qid, at = _G.time(), t = _G.GetTime and _G.GetTime() or 0, npc = rewardNpc,
        before = fresh and before.ids or nil }
end)
WK:On("QUEST_DETAIL", function()
    local last = M.lastTurnIn
    if not last or not last.npc then return end
    local now = _G.GetTime and _G.GetTime() or 0
    if now - (last.t or 0) > 30 then return end
    local qid = _G.GetQuestID and _G.GetQuestID()
    if not qid or qid == last.id or npcNow() ~= last.npc then return end
    if last.before and last.before[qid] then return end -- déjà proposée avant le rendu : pas une suite
    M:LearnChain(qid, last.id, "follow", WK:CharKey() .. ":" .. tostring(last.at) .. ":" .. tostring(last.id))
end)
