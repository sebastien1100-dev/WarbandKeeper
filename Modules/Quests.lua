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

local CLASS_BIT = { WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16, SHAMAN = 64, MAGE = 128,
                    WARLOCK = 256, DRUID = 1024 }

-- Index : quête par numéro, quêtes par donneur. Pas de copie des lignes de la base : chaque ligne reçoit une
-- métatable qui lit ses champs par nom (q.name = ligne[2]…), la carte venant d'une petite table à part.
local byID, byStarter
local FIELD = { id = 1, name = 2, nameFR = 3, lvl = 4, req = 5, side = 6, cls = 7, kind = 8, skill = 9, x = 10, y = 11,
    sid = 12, xp = 13, pre = 14, preAll = 15, nxt = 16, smap = 17, grp = 18 }
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
function M:Reindex() byID = nil end
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
    if ok then c.quests.done = done end
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
    local cfg = self:Config()
    if q.cls and cfg.classOnly then
        local bit = CLASS_BIT[c.class or ""]
        if bit and (math.floor(q.cls / bit) % 2) == 0 then return false end
    end
    if q.kind == "d" and not cfg.dungeons and not anyKind then return false end
    if q.skill and cfg.profOnly and not hasProf(c, q.skill) then return false end
    return true
end

-- "done", "log", "avail", "high" (niveau trop bas), "locked" (quête d'avant pas faite)
function M:State(q, c)
    local qs = c.quests or {}
    if qs.done and qs.done[q.id] then return "done" end
    if qs.log and qs.log[q.id] then return "log" end
    if (q.req or 0) > (c.level or 1) then return "high" end
    local done = qs.done or {}
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
    return "avail"
end
function M:Known(key) return charOf(key).quests and charOf(key).quests.done ~= nil end

---------------------------------------------------------------------------
-- Zones (page Quêtes)
---------------------------------------------------------------------------
-- { { map, name, total, done, avail, xp (dispo), min, max } } pour un perso
function M:Zones(key)
    local c = charOf(key)
    local R = WK.modules.Rares
    local out = {}
    for mapID in pairs(WK.QuestsDB or {}) do
        local z = { map = mapID, name = R:ZoneName(mapID), total = 0, done = 0, avail = 0, xp = 0, min = 99, max = 0 }
        for _, q in ipairs(self:OnMap(mapID)) do
            if self:ForChar(q, c) then
                z.total = z.total + 1
                local st = self:State(q, c)
                if st == "done" then z.done = z.done + 1
                elseif st == "avail" or st == "log" then z.avail = z.avail + 1; z.xp = z.xp + (q.xp or 0) end
                if q.kind ~= "d" and (q.lvl or 0) > 0 then z.min, z.max = math.min(z.min, q.lvl), math.max(z.max, q.lvl) end
            end
        end
        if z.min > z.max then z.min, z.max = z.max, z.max end
        if z.total > 0 then table.insert(out, z) end
    end
    table.sort(out, function(a, b) if a.min ~= b.min then return a.min < b.min end return a.name < b.name end)
    return out
end
function M:Totals(key)
    local c = charOf(key)
    if not byID then index() end
    local total, done, avail = 0, 0, 0
    for _, q in pairs(byID) do
        if self:ForChar(q, c) then
            total = total + 1
            local st = self:State(q, c)
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
    local c = charOf(key)
    local lvl = c.level or 1
    local best, bestXP
    for _, z in ipairs(self:Zones(key)) do
        local xp = 0
        for _, q in ipairs(self:OnMap(z.map)) do
            if self:ForChar(q, c) and q.lvl >= lvl - 3 and q.lvl <= lvl + 3 and self:State(q, c) == "avail" then xp = xp + (q.xp or 0) end
        end
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
            if st ~= "done" then
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
local learnedRows = {}
function M.AddLearned(byID_, byStarter_, mapOf_, meta)
    for id, e in pairs(learnStore()) do
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
    if not id or inBase(id) then return end
    C_Timer.After(0.5, function()
        local e = entry(id, true)
        if not e then return end
        local idx = C_QuestLog and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(id)
        local info = idx and C_QuestLog.GetInfo and C_QuestLog.GetInfo(idx)
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
