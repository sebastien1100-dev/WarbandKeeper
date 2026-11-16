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

-- Index : quête par numéro, quêtes par donneur
local byID, byStarter
local function index()
    byID, byStarter = {}, {}
    for mapID, list in pairs(WK.QuestsDB or {}) do
        for _, e in ipairs(list) do
            local q = { id = e[1], name = e[2], nameFR = e[3], lvl = e[4], req = e[5], side = e[6], cls = e[7],
                        kind = e[8], skill = e[9], x = e[10], y = e[11], sid = e[12], xp = e[13] or 0,
                        pre = e[14], preAll = e[15], nxt = e[16], map = mapID, smap = e[17] }
            byID[q.id] = q
            if q.sid then
                byStarter[q.sid] = byStarter[q.sid] or {}
                table.insert(byStarter[q.sid], q)
            end
        end
    end
end
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
    for _, e in ipairs((WK.QuestsDB or {})[mapID] or {}) do table.insert(out, byID[e[1]]) end
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
function M:ForChar(q, c)
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
    if q.kind == "d" and not cfg.dungeons then return false end
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
local STATE_COL = { avail = "ffd200", log = "9ed17a", high = "999999", locked = "999999" }
local function onUnitTooltip(tooltip)
    if tooltip ~= GameTooltip or not M:Config().tooltip then return end
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
    tooltip:AddLine("|cff33ccffWarband Keeper|r  " .. string.format(T("%d quêtes"), #lines))
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
