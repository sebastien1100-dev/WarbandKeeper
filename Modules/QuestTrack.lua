local ADDON_NAME, WK = ...
local T = function(s) return WK.T(s) end

-- Quête suivie : camps de ses objectifs (Modules/QuestObjDB.lua, généré par tools/gen_objectives.py) et
-- guidage. La quête cochée dans le journal du jeu (QUEST_WATCH_LIST_CHANGED) ou choisie dans l'addon devient
-- la quête suivie ; la flèche vise le camp le plus proche d'un objectif pas fini, puis le point de rendu.
-- Le guidage n'en remplace jamais un autre (boîte aux lettres, corps…) : seulement s'il n'y en a pas, ou si
-- c'est déjà le nôtre (genre « qtrack »). Arrivé au camp, le guidage s'arrête (Guide) et ne revient que si la
-- cible change (objectif fini, quête prête à rendre, « Camp suivant »).
local M = {}
WK.modules.QuestTrack = M

function M:Config()
    local g = WK.DB.global
    g.questTrack = g.questTrack or {}
    local c = g.questTrack
    c.tracked = c.tracked or {}       -- [perso] = n° de quête (donnée, hors profils)
    if c.followWatch == nil then c.followWatch = true end -- quête cochée dans le journal du jeu = suivie
    if c.hud == nil then c.hud = true end                 -- carte de quête à l'écran
    if c.guide == nil then c.guide = true end             -- flèche vers le camp puis le rendu
    if c.map == nil then c.map = "tracked" end            -- camps sur la carte : tracked / all / off
    if c.mini == nil then c.mini = true end               -- camp visé sur la minicarte
    if c.hideGame == nil then c.hideGame = true end       -- repères de quête du jeu masqués sur la carte du monde
    if c.panel == nil then c.panel = true end             -- volet « Quêtes du journal » sur la carte du monde (panelFold : replié)
    return c
end

local function on() return WK:FeatureOn("quests") end
local function G() return WK.modules.Guide end

---------------------------------------------------------------------------
-- Données : camps par objectif
---------------------------------------------------------------------------
local cache = {}
-- { objs = { { kind = "m"|"i"|"o", camps = { { map, x, y, r, n }, ... } } }, turnIn = { map, x, y } } ou nil
function M:Data(qid)
    if cache[qid] ~= nil then return cache[qid] or nil end
    local raw = WK.QuestObjRaw and WK.QuestObjRaw[qid]
    if not raw then cache[qid] = false return nil end
    local body, fin = raw:match("^([^@]*)@?(.*)$")
    local d = { objs = {} }
    for block in (body or ""):gmatch("[^|]+") do
        local kind, list = block:match("^(%a):(.*)$")
        if kind then
            local camps = {}
            for map, x, y, r, n in (list or ""):gmatch("(%d+),([%d%.]+),([%d%.]+),([%d%.]+),(%d+)") do
                table.insert(camps, { map = tonumber(map), x = tonumber(x) / 100, y = tonumber(y) / 100, r = tonumber(r) / 100, n = tonumber(n) })
            end
            table.insert(d.objs, { kind = kind, camps = camps })
        end
    end
    if fin and fin ~= "" then
        local map, x, y = fin:match("(%d+),([%d%.]+),([%d%.]+)")
        if map then d.turnIn = { map = tonumber(map), x = tonumber(x) / 100, y = tonumber(y) / 100 } end
    end
    cache[qid] = d
    return d
end

local KIND_OF = { monster = "m", item = "i", object = "o" }

-- Objectifs du journal du jeu, avec leurs camps : { text, type, done, have, need, camps }
function M:Objectives(qid)
    local out = {}
    local list = C_QuestLog and C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(qid)
    if type(list) ~= "table" then return out end
    local d = self:Data(qid)
    -- objectifs de la base rangés par genre, dans l'ordre : le n-ième « monstre » du jeu = le n-ième de la base
    local byKind, used = { m = {}, i = {}, o = {} }, { m = 0, i = 0, o = 0 }
    if d then for _, o in ipairs(d.objs) do table.insert(byKind[o.kind], o) end end
    for _, o in ipairs(list) do
        local k = KIND_OF[o.type or ""]
        local src
        if k then
            used[k] = used[k] + 1
            src = byKind[k][used[k]]
        elseif o.type == "event" then
            -- évènement (crédit de mort, objet à utiliser…) : un objectif de la base pas encore pris
            for _, kk in ipairs({ "m", "o", "i" }) do
                if byKind[kk][used[kk] + 1] then used[kk] = used[kk] + 1; src = byKind[kk][used[kk]]; break end
            end
        end
        local text = o.text or ""
        table.insert(out, {
            text = text, name = (text:gsub("%s*:%s*%d+%s*/%s*%d+%s*$", ""):gsub("^%d+%s*/%s*%d+%s*", "")),
            type = o.type, done = o.finished and true or false,
            have = o.numFulfilled or 0, need = o.numRequired or 0, camps = src and src.camps or {},
        })
    end
    return out
end

function M:InLog(qid)
    return qid and C_QuestLog and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(qid) ~= nil
end
function M:IsComplete(qid)
    if C_QuestLog and C_QuestLog.ReadyForTurnIn and C_QuestLog.ReadyForTurnIn(qid) then return true end
    return C_QuestLog and C_QuestLog.IsComplete and C_QuestLog.IsComplete(qid) and true or false
end
function M:Title(qid)
    local t = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(qid)
    return t or ("#" .. tostring(qid))
end
function M:Level(qid)
    local i = C_QuestLog and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(qid)
    local info = i and C_QuestLog.GetInfo and C_QuestLog.GetInfo(i)
    return info and info.level
end

-- Quêtes du journal (sans les en-têtes) : { { id, title, level, complete } }
function M:LogQuests()
    local out = {}
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo) then return out end
    local header
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info then
            if info.isHeader then header = info.title
            elseif info.questID and info.questID > 0 then
                table.insert(out, { id = info.questID, title = info.title, level = info.level, zone = header,
                    complete = self:IsComplete(info.questID) })
            end
        end
    end
    return out
end

---------------------------------------------------------------------------
-- Quête suivie
---------------------------------------------------------------------------
function M:Tracked()
    local qid = self:Config().tracked[WK:CharKey()]
    if qid and not self:InLog(qid) then qid = nil end
    return qid
end

function M:Track(qid)
    local c = self:Config()
    c.tracked[WK:CharKey()] = qid
    self.skip, self.lastKey = 0, nil
    self:Retarget(true)
    self:Changed()
end

function M:Untrack()
    local c = self:Config()
    c.tracked[WK:CharKey()] = nil
    local g = G()
    if g.target and g.target.kind == "qtrack" then g:Stop() end
    self.lastKey = nil
    self:Changed()
end

function M:Changed()
    if WK.UI.RefreshQuestTracker then WK.UI:RefreshQuestTracker() end
    if WK.UI.RefreshQuestCamps then WK.UI:RefreshQuestCamps() end
    WK:NotifyChanged()
end

---------------------------------------------------------------------------
-- Cible : camp le plus proche (ou le n-ième avec « Camp suivant »), sinon le rendu
---------------------------------------------------------------------------
local function worldOf(p)
    if p.cont == nil then
        local c, wx, wy = G().ToWorld(p.map, p.x, p.y)
        p.cont, p.wx, p.wy = c or false, wx, wy
    end
    return p.cont and p or nil
end

-- Camps des objectifs pas finis, du plus proche au plus loin : { { camp, obj, d } }
function M:CampList(qid)
    local list = {}
    local me = G():PlayerPos()
    for _, o in ipairs(self:Objectives(qid)) do
        if not o.done then
            for _, c in ipairs(o.camps) do
                local w = worldOf(c)
                local d = (me and w and me.cont == w.cont) and math.sqrt((w.wx - me.wx) ^ 2 + (w.wy - me.wy) ^ 2) or math.huge
                table.insert(list, { camp = c, obj = o, d = d })
            end
        end
    end
    table.sort(list, function(a, b)
        if a.d ~= b.d then return a.d < b.d end
        return (a.camp.n or 0) > (b.camp.n or 0)
    end)
    return list
end

function M:TurnIn(qid)
    if C_QuestLog and C_QuestLog.GetNextWaypoint then
        local ok, map, x, y = pcall(C_QuestLog.GetNextWaypoint, qid)
        if ok and map and x and (x ~= 0 or y ~= 0) then return { map = map, x = x, y = y } end
    end
    local d = self:Data(qid)
    return d and d.turnIn and { map = d.turnIn.map, x = d.turnIn.x, y = d.turnIn.y } or nil
end

-- { map, x, y, name, sub, key, camp?, obj?, turnIn? } : ce que la flèche vise
function M:Goal(qid)
    qid = qid or self:Tracked()
    if not qid then return nil end
    local title = self:Title(qid)
    if not self:IsComplete(qid) and not self.forceTurnIn then
        local list = self:CampList(qid)
        if #list > 0 then
            local pick = list[((self.skip or 0) % #list) + 1]
            local c = pick.camp
            return { map = c.map, x = c.x, y = c.y, name = pick.obj.name, sub = title, camp = c, obj = pick.obj, d = pick.d,
                key = qid .. ":" .. c.map .. ":" .. c.x .. ":" .. c.y, count = #list }
        end
    end
    local p = self:TurnIn(qid)
    if p then
        return { map = p.map, x = p.x, y = p.y, name = T("Rendre la quête"), sub = title, turnIn = true,
            key = qid .. ":rendu:" .. p.map }
    end
    return nil
end

-- Lance (ou change) le guidage vers la cible, sans prendre la place d'un autre guidage.
function M:Retarget(force)
    local cfg = self:Config()
    if not on() or not cfg.guide then return end
    -- une tournée de quêtes en cours (Modules/QuestPlan.lua) a la main sur le guidage
    if WK.modules.QuestPlan and WK.modules.QuestPlan:Active() then return end
    local g = G()
    local mine = g.target and g.target.kind == "qtrack"
    if g.target and not mine then return end
    local goal = self:Goal()
    if not goal then
        if mine then g:Stop() end
        self.lastKey = nil
        return
    end
    -- arrivé au camp (guidage arrêté par le Guide) : pas relancé tant que la cible ne change pas
    if not force and goal.key == self.lastKey then return end
    self.lastKey = goal.key
    local t = { map = goal.map, x = goal.x, y = goal.y,
        e = { goal.x * 100, goal.y * 100, 0, nil, nil, goal.name, goal.name, goal.sub } }
    t.cont, t.wx, t.wy = g.ToWorld(goal.map, goal.x, goal.y)
    t.qid = self:Tracked()
    g:Start(t, goal.turnIn and "Quête à rendre" or "Quête suivie", "qtrack")
end

function M:NextCamp()
    self.forceTurnIn = nil
    self.skip = (self.skip or 0) + 1
    self:Retarget(true)
    self:Changed()
end

function M:GoTurnIn()
    self.forceTurnIn = true
    self:Retarget(true)
    self.forceTurnIn = nil
    self:Changed()
end

---------------------------------------------------------------------------
-- Évènements
---------------------------------------------------------------------------
local pending
local function soon()
    if pending then return end
    pending = true
    C_Timer.After(0.4, function()
        pending = nil
        if not on() then return end
        local qid = M:Tracked()
        if not qid and M:Config().tracked[WK:CharKey()] then M:Config().tracked[WK:CharKey()] = nil end
        -- objectif fini ou quête prête : nouvelle cible (le camp suivant repart du plus proche)
        local state = qid and (M:IsComplete(qid) and "c" or "") or ""
        if qid then for _, o in ipairs(M:Objectives(qid)) do state = state .. (o.done and "1" or "0") end end
        if state ~= M.lastState then M.lastState = state; M.skip = 0 end
        M:Retarget()
        M:Changed()
    end)
end

-- quête cochée dans le journal du jeu : elle devient la quête suivie
WK:On("QUEST_WATCH_LIST_CHANGED", function(qid, added)
    if not on() or not M:Config().followWatch then return end
    if qid and added then M:Track(qid) end
end)
WK:On("QUEST_LOG_UPDATE", soon)
WK:On("QUEST_TURNED_IN", function(qid)
    if qid and qid == M:Config().tracked[WK:CharKey()] then M:Untrack() end
end)
WK:On("QUEST_REMOVED", function(qid)
    if qid and qid == M:Config().tracked[WK:CharKey()] then M:Untrack() end
end)
WK:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(3, soon) end)
WK:On("ZONE_CHANGED_NEW_AREA", function() M.skip = 0; soon() end)
