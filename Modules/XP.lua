local ADDON_NAME, WK = ...
local M = WK:NewModule("XP")
local T = function(s) return WK.T(s) end

-- Expérience (QoL > Expérience, UI/XPBar.lua) :
--   perso connecté : niveau, XP, repos, en auberge ou non (relevés dans c.xp, pour l'estimation des autres) ;
--   quêtes terminées à rendre : XP de chacune, point de rendu (C_QuestLog.GetNextWaypoint) ;
--   rythme de la session : XP gagnée, par heure, et d'où elle vient (monstres, quêtes, découverte) ;
--   repos estimé des autres persos depuis leur déconnexion (5 % d'un niveau par 8 h en auberge, 4 fois moins
--   dehors, au plus 150 %).
-- Réglages : QoL:Config().xp
local DEFAULTS = { bar = true, compact = false, noBg = false, textHover = false, textPos = "above", levelAlert = true, restAlert = true, width = 520, thick = 8 }
local REST_PER_8H = 0.05   -- part d'un niveau gagnée en 8 h de repos en auberge
local REST_MAX = 1.5       -- 150 % d'un niveau

function M:Config()
    local q = WK.modules.QoL:Config()
    q.xp = q.xp or {}
    for k, v in pairs(DEFAULTS) do if q.xp[k] == nil then q.xp[k] = v end end
    return q.xp
end

local function readable(v)
    local Q = WK.modules.QoL
    return Q and Q.Readable and Q.Readable(v) or v
end
local function num(v) v = readable(v); return type(v) == "number" and v or nil end

function M:MaxLevel()
    return (GetMaxPlayerLevel and num(GetMaxPlayerLevel())) or (MAX_PLAYER_LEVEL and num(MAX_PLAYER_LEVEL)) or 60
end

-- Perso connecté : { level, cur, max, rested, resting }
function M:Me()
    local level = num(UnitLevel("player")) or 1
    return {
        level = level,
        cur = num(UnitXP and UnitXP("player")) or 0,
        max = math.max(1, num(UnitXPMax and UnitXPMax("player")) or 1),
        rested = num(GetXPExhaustion and GetXPExhaustion()) or 0,
        resting = IsResting and IsResting() and true or false,
        maxed = level >= self:MaxLevel(),
    }
end

-- XP d'un niveau (1 à 59), comme le jeu : sert quand le relevé d'un perso n'a pas son maximum
local LEVEL_XP = { 400, 900, 1400, 2100, 2800, 3600, 4500, 5400, 6500, 7600, 8800, 10100, 11400, 12900, 14400,
    16000, 17700, 19400, 21300, 23200, 25200, 27300, 29400, 31700, 34000, 36400, 38900, 41400, 44300, 47400, 50800,
    54500, 58600, 62800, 67100, 71600, 76100, 80800, 85700, 90700, 95800, 101000, 106300, 111800, 117500, 123200,
    129000, 135000, 141000, 147500, 154000, 163000, 173000, 184000, 196000, 208000, 220000, 232000, 245000 }
function M.LevelXP(_, level) return LEVEL_XP[level or 0] end

local function save()
    local c = WK.DB:Me()
    if not c then return end
    local x = M:Me()
    -- XP pas encore (ou plus) lisible (connexion, déconnexion : le jeu rend 0) : on garde le dernier bon relevé
    if x.max <= 1 and not x.maxed then return end
    c.xp = { level = x.level, cur = x.cur, max = x.max, rested = x.rested, resting = x.resting, at = time() }
end

---------------------------------------------------------------------------
-- Quêtes terminées à rendre
---------------------------------------------------------------------------
local function questXP(questID, index)
    if GetQuestLogRewardXP then
        local ok, v = pcall(GetQuestLogRewardXP, questID)
        if ok and num(v) and v > 0 then return v end
    end
    return 0
end

-- quêtes rendues il y a peu : le journal du jeu les garde encore un instant après la remise
local turnedIn = {}
-- { { id, title, xp, map, x, y } } (triées par XP décroissante)
function M:Pending()
    local out = {}
    local n = (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries())
              or (GetNumQuestLogEntries and GetNumQuestLogEntries()) or 0
    for i = 1, n do
        local id, title, complete
        if C_QuestLog and C_QuestLog.GetInfo then
            local info = C_QuestLog.GetInfo(i)
            if info and not info.isHeader then
                id, title = info.questID, info.title
                complete = C_QuestLog.IsComplete and C_QuestLog.IsComplete(id)
            end
        elseif GetQuestLogTitle then
            local t, _, _, isHeader, _, isComplete, _, qid = GetQuestLogTitle(i)
            if not isHeader then id, title, complete = qid, t, isComplete == 1 or isComplete == true end
        end
        if id and id > 0 and complete and not (turnedIn[id] and GetTime() - turnedIn[id] < 120) then
            local e = { id = id, title = readable(title) or ("#" .. id), xp = questXP(id, i) }
            if C_QuestLog and C_QuestLog.GetNextWaypoint then
                local ok, map, x, y = pcall(C_QuestLog.GetNextWaypoint, id)
                if ok and num(map) and num(x) then e.map, e.x, e.y = map, x, y end
            end
            -- à défaut, le donneur (souvent le même PNJ)
            if not e.map then
                local q = WK.modules.Quests and WK.modules.Quests:Get(id)
                if q and q.x then e.map, e.x, e.y, e.giver = (q.smap or q.map), q.x / 100, q.y / 100, true end
            end
            table.insert(out, e)
        end
    end
    table.sort(out, function(a, b) return a.xp > b.xp end)
    return out
end
function M:PendingXP()
    local total = 0
    for _, e in ipairs(self:Pending()) do total = total + e.xp end
    return total
end

-- Distance (m) et cible de guidage d'une quête à rendre
local function target(e)
    if not e.map then return nil end
    local G = WK.modules.Guide
    local t = { map = e.map, x = e.x, y = e.y }
    t.cont, t.wx, t.wy = G.ToWorld(e.map, e.x, e.y)
    local p = G:PlayerPos()
    t.distance = p and G:Vector(p, t) or nil
    t.e = { e.x * 100, e.y * 100, 0, nil, nil, e.title, e.title, T("Quête à rendre") }
    t.qid = e.id
    return t
end
function M:GuideTo(e)
    local t = target(e)
    if t then WK.modules.Guide:Start(t, "Quête à rendre", "quest") end
end
function M:GuideNearest()
    local best, bd
    for _, e in ipairs(self:Pending()) do
        local t = target(e)
        if t and t.distance and (not bd or t.distance < bd) then best, bd = e, t.distance end
    end
    if best then self:GuideTo(best) return true end
    return false
end

---------------------------------------------------------------------------
-- Rythme de la session
---------------------------------------------------------------------------
M.session = { start = time(), gained = 0, mobs = 0, quests = 0, explore = 0, lastKill = nil }
local last -- { level, cur, max }
local function onXP()
    local x = M:Me()
    if last and last.max > 1 then
        local d
        if x.level > last.level then d = (last.max - last.cur) + x.cur else d = x.cur - last.cur end
        if d > 0 then M.session.gained = M.session.gained + d end
    end
    last = { level = x.level, cur = x.cur, max = x.max }
    save()
    WK:NotifyChanged()
end
function M:ResetSession()
    self.session = { start = time(), gained = 0, mobs = 0, quests = 0, explore = 0, lastKill = nil }
end
-- Persos (hors connecté) au repos plein : { { key, c } }
function M:RestFull()
    local out = {}
    for key, c in pairs(WK.DB.global.characters) do
        if key ~= WK:CharKey() then
            local frac = self:RestOf(key)
            if frac and frac >= REST_MAX - 0.001 then table.insert(out, { key = key, c = c }) end
        end
    end
    return out
end
-- XP par heure et temps jusqu'au niveau suivant (nil tant qu'on n'a rien gagné)
function M:Rate()
    local s = self.session
    local hours = math.max(1 / 60, (time() - s.start) / 3600)
    if s.gained <= 0 then return nil end
    local perHour = s.gained / hours
    local x = self:Me()
    local need = x.max - x.cur
    return perHour, need / perHour * 3600, s.lastKill and s.lastKill > 0 and math.ceil(need / s.lastKill) or nil
end

-- sources : monstres (message d'XP de combat), quêtes (QUEST_TURNED_IN), découverte (message système)
local function firstNumber(s)
    local d = type(s) == "string" and s:match("(%d[%d%s%.]*)")
    if not d then return nil end
    return tonumber((d:gsub("[^%d]", "")))
end
WK:On("CHAT_MSG_COMBAT_XP_GAIN", function(msg)
    msg = readable(msg)
    if type(msg) ~= "string" then return end
    local n = firstNumber(msg)
    if n then M.session.mobs = M.session.mobs + n; M.session.lastKill = n end
end)
WK:On("QUEST_TURNED_IN", function(questID, xp)
    xp = num(xp)
    if xp and xp > 0 then M.session.quests = M.session.quests + xp end
    questID = num(questID)
    if not questID then return end
    turnedIn[questID] = GetTime()
    -- guidé vers cette quête : on passe à la suivante à rendre (ou on arrête le guidage)
    local G = WK.modules.Guide
    local t = G and G.target
    if t and t.kind == "quest" and t.qid == questID then
        C_Timer.After(0.5, function()
            if G.target ~= t then return end
            if not M:GuideNearest() then G:Stop() end
        end)
    end
    WK:NotifyChanged()
end)
WK:On("CHAT_MSG_SYSTEM", function(msg)
    msg = readable(msg)
    if type(msg) ~= "string" then return end
    local low = msg:lower()
    if low:find("découvert", 1, true) or low:find("discovered", 1, true) then
        local n = firstNumber(msg)
        if n then M.session.explore = M.session.explore + n end
    end
end)

---------------------------------------------------------------------------
-- Repos estimé d'un perso (part d'un niveau, 0-1,5) et s'il est plein
---------------------------------------------------------------------------
function M:RestOf(key)
    local c = WK.DB.global.characters[key]
    local x = c and c.xp
    if not x then return nil end
    if key == WK:CharKey() then local me = self:Me(); return me.rested / me.max, me end
    if (c.level or x.level or 1) >= self:MaxLevel() then return nil end
    local mx = ((x.max or 0) > 1) and x.max or LEVEL_XP[x.level or 0] or 1
    local frac = (x.rested or 0) / mx
    local hours = math.max(0, (time() - (x.at or time())) / 3600)
    frac = frac + REST_PER_8H * (hours / 8) * (x.resting and 1 or 0.25)
    return math.min(REST_MAX, frac), x
end
function M:RestFullIn(frac, resting)
    local left = math.max(0, REST_MAX - frac)
    return left / REST_PER_8H * 8 * 3600 * (resting and 1 or 4)
end
M.REST_MAX = REST_MAX

---------------------------------------------------------------------------
-- Alerte : rendre ses quêtes ferait passer un niveau
---------------------------------------------------------------------------
local function checkLevelAlert()
    local UI = WK.UI
    if not (UI and UI.SetAlert) then return end
    local cfg = M:Config()
    local x = M:Me()
    local on = cfg.levelAlert and WK:FeatureOn("xp") and not x.maxed and (x.cur + M:PendingXP()) >= x.max
    UI:SetAlert("xp.levelup", on, { text = T("Rendre tes quêtes terminées te fait passer un niveau"), color = UI.colors.positive, prio = 3,
        icon = "Interface\\Icons\\INV_Misc_Note_01" })
end

M.CheckLevelAlert = function() checkLevelAlert() end

local pending = false
local function later()
    if pending then return end
    pending = true
    C_Timer.After(0.5, function() pending = false; checkLevelAlert(); if M.OnChange then M:OnChange() end; WK:NotifyChanged() end)
end
WK:On("PLAYER_XP_UPDATE", function(unit) if unit == nil or unit == "player" then onXP(); later() end end)
WK:On("PLAYER_LEVEL_UP", function() C_Timer.After(0.5, function() onXP(); later() end) end)
WK:On("UPDATE_EXHAUSTION", function() save(); later() end)
WK:On("PLAYER_UPDATE_RESTING", function() save(); later() end)
WK:On("QUEST_LOG_UPDATE", later)
WK:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(2, function() onXP(); later() end) end)
WK:On("PLAYER_LOGOUT", save)
