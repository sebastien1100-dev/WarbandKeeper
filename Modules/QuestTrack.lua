local ADDON_NAME, WK = ...
local T = function(s) return WK.T(s) end

-- Quêtes du journal et quête suivie : camps des objectifs (Data/QuestObjDB.lua, généré par
-- tools/gen_objectives.py), dessinés sur la carte (UI/QuestCamps.lua). La quête cochée dans le journal du jeu
-- (QUEST_WATCH_LIST_CHANGED) ou choisie dans l'addon devient la quête suivie. Plus de flèche automatique :
-- un clic « guider » (camp, rendu, donneur) lance un guidage ordinaire (genre « qtrack »).
local M = {}
WK.modules.QuestTrack = M

function M:Config()
    local g = WK.DB.global
    g.questTrack = g.questTrack or {}
    local c = g.questTrack
    c.tracked = c.tracked or {}       -- [perso] = n° de quête (donnée, hors profils)
    -- réglages de la carte de quête, de la flèche, de la barre « Quête » et des pastilles du suivi (retirés)
    c.hud, c.hudSolo, c.guide, c.actButtons, c.targetSkull, c.trackPins, c.tourBg = nil, nil, nil, nil, nil, nil, nil
    if c.followWatch == nil then c.followWatch = true end -- quête cochée dans le journal du jeu = suivie
    if c.map == nil then c.map = "tracked" end            -- camps sur la carte : tracked / all / off
    if c.zoneStyle == nil then c.zoneStyle = "heat" end   -- zones sur la carte du monde : heat / points / circles
    if c.miniStyle == nil then c.miniStyle = "heat" end   -- quête suivie sur la minicarte : heat / points / off
    if c.heat == nil then c.heat = 100 end                -- intensité des zones de chaleur (%)
    if c.hideGame == nil then c.hideGame = true end       -- repères de quête du jeu masqués sur la carte du monde
    -- volet « Quêtes du journal » sur la carte du monde (panelFold : replié)
    if c.panel == nil then c.panel = true end
    if c.plateMarks == nil then c.plateMarks = true end   -- repères des monstres de la quête sur les plaques de nom
    return c
end

local function on() return WK:FeatureOn("quests") end
local function G() return WK.modules.Guide end

---------------------------------------------------------------------------
-- Données : camps par objectif
---------------------------------------------------------------------------
local cache = {}
-- { objs = { { kind = "m"|"i"|"o"|"e"|"x", idx?, camps = { { map, x, y, r, n }, ... }, refs? } },
--   turnIn = { map, x, y } } ou nil
-- e = zone à explorer, x = objectif caché de Questie (idx = n° de l'objectif du jeu auquel il se rattache)
function M:Data(qid)
    if cache[qid] ~= nil then return cache[qid] or nil end
    -- base des objectifs dans le dossier chargé à la demande : pas encore là (combat, dossier absent) = rien,
    -- sans le retenir
    if not WK:NeedData("quêtes") then return nil end
    local raw = WK.QuestObjRaw and WK.QuestObjRaw[qid]
    if not raw then cache[qid] = false return nil end
    local body, fin = raw:match("^([^@]*)@?(.*)$")
    local d = { objs = {} }
    for block in (body or ""):gmatch("[^|]+") do
        local kind, idx, list = block:match("^(%a)(%d*):(.*)$")
        if kind then
            local camps = {}
            for map, x, y, r, n in (list or ""):gmatch("(%d+),([%d%.]+),([%d%.]+),([%d%.]+),(%d+)") do
                table.insert(camps, { map = tonumber(map), x = tonumber(x) / 100, y = tonumber(y) / 100,
                    r = tonumber(r) / 100, n = tonumber(n) })
            end
            table.insert(d.objs, { kind = kind, idx = tonumber(idx), camps = camps })
        end
    end
    -- points exacts (WK.QuestPtsRaw, même ordre que les blocs) : clés de WK.SpawnPts ou points de l'objectif
    local praw = WK.QuestPtsRaw and WK.QuestPtsRaw[qid]
    if praw then
        local i = 0
        for part in (praw .. "|"):gmatch("([^|]*)|") do
            i = i + 1
            if d.objs[i] and part ~= "" then d.objs[i].refs = { part } end
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
-- textOnly : l'appelant ne veut que le texte et l'avancée du jeu (fenêtre des quêtes du donjon, pastilles du
-- suivi) : la base des camps n'est lue que si elle est déjà chargée, jamais chargée pour ça
function M:Objectives(qid, textOnly)
    local out = {}
    local list = C_QuestLog and C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(qid)
    if type(list) ~= "table" then return out end
    local d
    if not textOnly or WK.dataLoaded then d = self:Data(qid) end
    -- objectifs de la base rangés par genre, dans l'ordre : le n-ième « monstre » du jeu = le n-ième de la base
    local byKind, used = { m = {}, i = {}, o = {}, e = {}, x = {} }, { m = 0, i = 0, o = 0, e = 0, x = 0 }
    if d then for _, o in ipairs(d.objs) do if byKind[o.kind] then table.insert(byKind[o.kind], o) end end end
    for _, o in ipairs(list) do
        local k = KIND_OF[o.type or ""]
        local src
        if k then
            used[k] = used[k] + 1
            src = byKind[k][used[k]]
        elseif o.type == "event" then
            -- évènement : la zone à explorer d'abord, sinon un objectif de la base pas encore pris
            -- (crédit de mort, objet à utiliser…)
            for _, kk in ipairs({ "e", "m", "o", "i" }) do
                if byKind[kk][used[kk] + 1] then used[kk] = used[kk] + 1; src = byKind[kk][used[kk]]; break end
            end
        end
        local text = o.text or ""
        table.insert(out, {
            text = text, name = (text:gsub("%s*:%s*%d+%s*/%s*%d+%s*$", ""):gsub("^%d+%s*/%s*%d+%s*", "")),
            type = o.type, done = o.finished and true or false,
            have = o.numFulfilled or 0, need = o.numRequired or 0, camps = src and src.camps or {},
            refs = src and src.refs,
        })
    end
    -- objectifs cachés de Questie : rattachés à leur objectif du jeu (lieu plus précis en tête), sinon en plus
    local complete = #out > 0 and self:IsComplete(qid)
    for _, x in ipairs(byKind.x) do
        local o = x.idx and x.idx >= 1 and out[x.idx]
        if o then
            local merged = {}
            for _, c in ipairs(x.camps) do table.insert(merged, c) end
            for _, c in ipairs(o.camps) do table.insert(merged, c) end
            o.camps = merged
            if x.refs then
                local r = {}
                for _, v in ipairs(x.refs) do table.insert(r, v) end
                for _, v in ipairs(o.refs or {}) do table.insert(r, v) end
                o.refs = r
            end
        elseif #x.camps > 0 then
            local label = T("Lieu de l'objectif caché")
            table.insert(out, { text = label, name = label, type = "extra",
                done = complete, have = 0, need = 0, camps = x.camps, refs = x.refs })
        end
    end
    -- zone à explorer que le jeu ne range pas en « évènement » : ajoutée tant que la quête n'est pas finie
    if byKind.e[1] and used.e == 0 and #byKind.e[1].camps > 0 and #out > 0 then
        table.insert(out, { text = T("Lieu à explorer"), name = T("Lieu à explorer"), type = "explore",
            done = complete, have = 0, need = 0, camps = byKind.e[1].camps, refs = byKind.e[1].refs })
    end
    return out
end

-- Points exacts d'un objectif (rendu par Objectives ou un objectif de Data) sur une carte :
-- { x1, y1, x2, y2, … } (0-1), décodés à la demande et gardés par chaîne et par carte
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64I = {}
for i = 1, #B64 do B64I[B64:byte(i)] = i - 1 end
local ptCache = {}
local function decode(str, mapID)
    local key = mapID .. "#" .. str
    local hit = ptCache[key]
    if hit then return hit end
    local out = {}
    for m, codes in str:gmatch("(%d+):([^;]+)") do
        if tonumber(m) == mapID then
            for i = 1, #codes - 2, 3 do
                local a, b, c = B64I[codes:byte(i)], B64I[codes:byte(i + 1)], B64I[codes:byte(i + 2)]
                if a and b and c then
                    local v = a * 4096 + b * 64 + c
                    out[#out + 1] = math.floor(v / 201) / 200
                    out[#out + 1] = (v % 201) / 200
                end
            end
        end
    end
    ptCache[key] = out
    return out
end
function M:Points(o, mapID)
    local out = {}
    if not (o and o.refs and mapID) then return out end
    local seen = {}
    for _, part in ipairs(o.refs) do
        local list
        if part:sub(1, 1) == "*" then list = { part:sub(2) }
        else
            list = {}
            for k in part:gmatch("[^,]+") do
                if not seen[k] then seen[k] = true; list[#list + 1] = WK.SpawnPts and WK.SpawnPts[k] end
            end
        end
        for _, str in ipairs(list) do
            local pts = decode(str, mapID)
            for i = 1, #pts do out[#out + 1] = pts[i] end
        end
    end
    return out
end

-- Monstres d'un objectif (n° de PNJ tirés des clés « n… » de WK.QuestPtsRaw) et leur nom (WK.QuestNpcNames,
-- « anglais|français ») : bouton Cibler et repères des plaques de nom
function M.ObjectiveNpcs(_, o)
    local out, seen = {}, {}
    for _, part in ipairs(o and o.refs or {}) do
        if part:sub(1, 1) ~= "*" then
            for id in part:gmatch("n(%d+)") do
                id = tonumber(id)
                if id and not seen[id] then seen[id] = true; out[#out + 1] = id end
            end
        end
    end
    return out
end
function M.NpcName(_, id)
    if not WK:NeedData("quêtes") then return nil end
    local raw = WK.QuestNpcNames and WK.QuestNpcNames[id]
    if not raw then return nil end
    local en, fr = raw:match("^(.-)|(.*)$")
    if not en then return raw end
    return (WK.Lang and WK.Lang() == "frFR" and fr ~= "" and fr) or en
end
-- Nom à donner à /targetexact : celui du jeu, donc dans la langue du client (pas celle choisie pour l'addon) ;
-- nil pour un client ni français ni anglais (nom inconnu : pas de bouton Cibler)
function M.NpcTargetName(_, id)
    if not WK:NeedData("quêtes") then return nil end
    local raw = WK.QuestNpcNames and WK.QuestNpcNames[id]
    if not raw then return nil end
    local en, fr = raw:match("^(.-)|(.*)$")
    if not en then en, fr = raw, nil end
    local loc = _G.GetLocale and _G.GetLocale() or "enUS"
    if loc == "frFR" then return (fr and fr ~= "" and fr) or nil end
    if loc == "enUS" or loc == "enGB" then return en end
    return nil
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

---------------------------------------------------------------------------
-- Objets de quête à acheter (Modules/QuestObjDB.lua : WK.QuestBuy, WK.QuestVendors, tirés de QuestieDB)
---------------------------------------------------------------------------
local buyCache, vendCache = {}, {}
-- marchands d'un objet : { { map, x, y (0-1), fac = "A"|"H"|"AH", name } }
function M:Vendors(item)
    if vendCache[item] then return vendCache[item] end
    -- base dans le dossier chargé à la demande : pas encore là = liste vide, sans la retenir
    if not WK:NeedData("objets de quête") then return {} end
    local out = {}
    local raw = WK.QuestVendors and WK.QuestVendors[item]
    for e in (raw or ""):gmatch("[^;]+") do
        local map, x, y, fac, name = e:match("^(%d+),([%d%.]+),([%d%.]+),(%a+),(.*)$")
        if map then
            table.insert(out, { map = tonumber(map), x = tonumber(x) / 100, y = tonumber(y) / 100, fac = fac, name = name })
        end
    end
    vendCache[item] = out
    return out
end
-- objets à acheter pour une quête : { n° d'objet, … }
function M:BuyItems(qid)
    if buyCache[qid] then return buyCache[qid] end
    if not WK:NeedData("objets de quête") then return {} end
    local out = {}
    local raw = WK.QuestBuy and WK.QuestBuy[qid]
    for id in (raw or ""):gmatch("%d+") do table.insert(out, tonumber(id)) end
    buyCache[qid] = out
    return out
end
-- nom d'un marchand (français quand Modules/PlacesDB.lua le connaît) et son rôle
function M:VendorName(v)
    local fr = WK.Lang and WK.Lang() == "frFR"
    for _, p in ipairs(WK.PlacesDB and WK.PlacesDB[v.map] or {}) do
        if p[6] == v.name and math.abs(p[1] / 100 - v.x) < 0.006 and math.abs(p[2] / 100 - v.y) < 0.006 then
            return (fr and p[7]) or p[6], p[8]
        end
    end
    return v.name, nil
end
-- quantité demandée d'un objet (objectif du journal quand la quête y est, sinon 1)
function M:BuyNeed(qid, item)
    if not self:InLog(qid) then return 1 end
    local name = WK.GetItemInfo and WK.GetItemInfo(item)
    local objs = self:Objectives(qid)
    local items = {}
    for _, o in ipairs(objs) do if o.type == "item" then table.insert(items, o) end end
    for _, o in ipairs(items) do
        if name and o.name == name then return math.max(1, o.need or 1) end
    end
    if #items == 1 and #self:BuyItems(qid) == 1 then return math.max(1, items[1].need or 1) end
    return 1
end
function M:ItemCount(item)
    local f = (C_Item and C_Item.GetItemCount) or GetItemCount
    return f and (f(item) or 0) or 0
end
-- objets qui manquent encore pour une quête : { { id, n } } (n = combien en acheter)
function M:BuyMissing(qid)
    local out = {}
    if self:InLog(qid) and self:IsComplete(qid) then return out end
    for _, id in ipairs(self:BuyItems(qid)) do
        local need = self:BuyNeed(qid, id)
        local miss = need - self:ItemCount(id)
        if miss > 0 then table.insert(out, { id = id, n = miss }) end
    end
    return out
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
    self:Changed()
end

function M:Untrack()
    local c = self:Config()
    c.tracked[WK:CharKey()] = nil
    self:Changed()
end

function M:Changed()
    if WK.UI.RefreshQuestCamps then WK.UI:RefreshQuestCamps() end
    if WK.UI.RefreshQuestMini then WK.UI:RefreshQuestMini() end
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

---------------------------------------------------------------------------
-- Évènements
---------------------------------------------------------------------------
-- Empreinte du journal : quêtes, prêtes ou non, avancée de chaque objectif. QUEST_LOG_UPDATE arrive très souvent
-- sans que rien change (ciblage, entrée en zone, autre joueur) : sans changement, rien n'est redessiné.
local function logSignature()
    local ql = _G.C_QuestLog
    if not (ql and ql.GetNumQuestLogEntries and ql.GetInfo) then return nil end
    local parts = {}
    for i = 1, (ql.GetNumQuestLogEntries() or 0) do
        local info = ql.GetInfo(i)
        local id = type(info) == "table" and not info.isHeader and info.questID
        if id then
            local s = id .. (ql.IsComplete and ql.IsComplete(id) and "c" or "")
            local objs = ql.GetQuestObjectives and ql.GetQuestObjectives(id)
            for _, o in ipairs(type(objs) == "table" and objs or {}) do
                s = s .. ":" .. tostring(o.numFulfilled or (o.finished and 1 or 0))
            end
            parts[#parts + 1] = s
        end
    end
    return table.concat(parts, ",")
end
M.LogSignature = logSignature
local pending
-- une demande forcée qui arrive pendant l'attente d'une demande ordinaire n'est plus perdue (QUEST_LOG_UPDATE
-- arrive souvent avec ZONE_CHANGED_NEW_AREA : la flèche gardait l'ancien camp en changeant de zone)
local pendingForce = false
local function soon(force)
    if force == true then pendingForce = true end
    if pending then return end
    pending = true
    _G.C_Timer.After(0.4, function()
        pending = nil
        local forced = pendingForce
        pendingForce = false
        if not on() then return end
        local sig = logSignature()
        local track = M:Config().tracked[WK:CharKey()]
        if not forced and sig and sig == M.lastSig and track == M.lastSigTrack then return end
        M.lastSig, M.lastSigTrack = sig, track
        local qid = M:Tracked()
        if not qid and M:Config().tracked[WK:CharKey()] then M:Config().tracked[WK:CharKey()] = nil end
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
WK:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(3, function() soon(true) end) end)
WK:On("ZONE_CHANGED_NEW_AREA", function() soon(true) end)

-- données à la demande arrivées (après un combat, ou au premier besoin) : ce qui a été calculé sans elles est
-- refait (camps, objets à acheter)
WK:OnDataLoaded(function()
    for k in pairs(buyCache) do buyCache[k] = nil end
    for k in pairs(vendCache) do vendCache[k] = nil end
    M.lastSig = nil
    if _G.C_Timer then _G.C_Timer.After(0, function() soon(true) end) end
end)
