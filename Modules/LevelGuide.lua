local ADDON_NAME, WK = ...
local T = function(s) return WK.T(s) end

-- Guide de montée calculé en direct (pas de parcours écrit d'avance) :
--  A · BestZones : meilleures zones pour le niveau du perso, d'où il est (XP des quêtes faisables, temps de
--      quête et de trajet estimés, niveau atteint).
--  B · Steps : suite d'étapes recalculée à chaque changement : objet qui démarre une quête, maître de classe,
--      point de vol à apprendre, pierre de foyer, tournée de la zone (QuestPlan), donjon à ton niveau, zone
--      suivante. « Suivre ce guide » lance l'étape en cours ; une tournée finie enchaîne la suivante.
--  C · la carte de quête à l'écran (UI/QuestTracker.lua) montre l'étape du guide quand il est suivi.
-- Temps réel de chaque quête noté (prise » rendue) pour affiner les durées (QuestPlan l'utilise).
-- Réglages et état : WK.DB.global.levelGuide (follow[perso], noDungeons, noProf, times[quête] = s,
-- acc[perso][quête] = date de prise, trainer[perso] = niveau de la dernière visite, told = objets signalés).
local M = {}
WK.modules.LevelGuide = M

-- XP pour passer au niveau suivant (niveaux 1 à 59), pour estimer le niveau atteint
local XP_LEVEL = { 400, 900, 1400, 2100, 2800, 3600, 4500, 5400, 6500, 7600, 8800, 10100, 11400, 12900, 14400, 16000,
    17700, 19400, 21300, 23200, 25200, 27300, 29400, 31700, 34000, 36400, 38900, 41400, 44300, 47400, 50800, 54500,
    58600, 62800, 67100, 71600, 76100, 80800, 85700, 90700, 95800, 101000, 106300, 111800, 117500, 123200, 129100,
    135100, 141200, 147500, 153900, 160400, 167100, 173900, 180800, 187900, 195000, 202300, 209800 }
local QUEST_SECS = 7 * 60   -- temps moyen d'une quête quand on n'a pas mieux
local ZONE_LOW = 3          -- moins de 3 quêtes faisables : zone finie pour toi

function M:Config()
    local g = WK.DB.global
    g.levelGuide = g.levelGuide or {}
    local c = g.levelGuide
    c.follow = c.follow or {}
    c.times = c.times or {}
    c.acc = c.acc or {}
    c.trainer = c.trainer or {}
    c.told = c.told or {}
    return c
end
local function on() return WK:FeatureOn("quests") end
local function Qs() return WK.modules.Quests end
local function P() return WK.modules.QuestPlan end
local function G() return WK.modules.Guide end
local function level() return (UnitLevel and UnitLevel("player")) or (WK.DB:Me() or {}).level or 1 end

-- Temps réel moyen pour une quête (s) : le sien s'il a été noté, sinon la moyenne notée, sinon nil
function M:QuestTime(qid)
    local t = self:Config().times
    if t[qid] then return t[qid] end
    return nil
end
function M:AvgQuestTime()
    local s, n = 0, 0
    for _, v in pairs(self:Config().times) do s, n = s + v, n + 1 end
    if n >= 5 then return s / n end
    return QUEST_SECS
end

-- Niveau atteint (avec décimale de progression) en ajoutant xp à l'XP actuelle
function M:LevelAfter(xp)
    local lvl = level()
    local cur = (UnitXP and UnitXP("player")) or 0
    local total = cur + (xp or 0)
    while lvl < 60 and XP_LEVEL[lvl] and total >= XP_LEVEL[lvl] do
        total = total - XP_LEVEL[lvl]
        lvl = lvl + 1
    end
    return lvl + (XP_LEVEL[lvl] and total / XP_LEVEL[lvl] or 0)
end

---------------------------------------------------------------------------
-- A · Où monter maintenant
---------------------------------------------------------------------------
local function zoneCenter(map)
    local c, wx, wy = G().ToWorld(map, 0.5, 0.5)
    return c, wx, wy
end

-- { { map, name, xp, count, min, max, secs (quêtes), travel (s), here, flightMissing, reach, score } }
local zmemo = {}
function M:BestZones(n)
    -- toutes les zones du jeu sont parcourues : résultat gardé 5 s
    local now = GetTime and GetTime() or time()
    local cf = self:Config()
    local sig = tostring(cf.noDungeons) .. tostring(cf.noProf) .. WK:CharKey()
    if zmemo.list and zmemo.sig == sig and now - zmemo.at < 5 then
        local out = {}
        for i = 1, math.min(n or #zmemo.list, #zmemo.list) do out[i] = zmemo.list[i] end
        return out
    end
    zmemo.list, zmemo.at, zmemo.sig = self:BestZonesNow(), now, sig
    return self:BestZones(n)
end
function M:BestZonesNow(n)
    local Q = Qs()
    local me = WK.DB:Me() or {}
    local lvl = level()
    local cfg = self:Config()
    local above = P() and P():Config().maxAbove or 2
    local here = Q:PlayerZone()
    local pos = G():PlayerPos()
    local avg = self:AvgQuestTime()
    local out = {}
    for map in pairs(WK.QuestsDB or {}) do
        local xp, count, zmin, zmax = 0, 0, 99, 0
        for _, q in ipairs(Q:OnMap(map)) do
            if Q:ForChar(q, me) and q.lvl and q.lvl > 0 then
                if q.lvl < zmin then zmin = q.lvl end
                if q.lvl > zmax then zmax = q.lvl end
                local st = Q:State(q, me)
                if (st == "avail" or st == "log") and q.lvl >= lvl - 3 and q.lvl <= lvl + above + 1
                    and not (cfg.noDungeons and q.kind == "d") and not (cfg.noProf and q.skill) then
                    xp = xp + (q.xp or 0); count = count + 1
                end
            end
        end
        if count >= ZONE_LOW and xp > 0 then
            local travel = 0
            if map ~= here then
                local c, wx, wy = zoneCenter(map)
                if pos and c and pos.cont == c then
                    travel = math.sqrt((wx - pos.wx) ^ 2 + (wy - pos.wy) ^ 2) / 14   -- vols et course mêlés
                else
                    travel = 15 * 60                                               -- autre continent
                end
            end
            local secs = count * avg
            local fm = WK.modules.Flight and WK.modules.Flight.MissingFlightPoints and WK.modules.Flight:MissingFlightPoints(map) or {}
            table.insert(out, { map = map, name = WK.modules.Rares:ZoneName(map), xp = xp, count = count, min = zmin, max = zmax,
                secs = secs, travel = travel, here = map == here, flightMissing = #fm > 0, reach = self:LevelAfter(xp),
                score = xp / ((secs + travel) / 3600) })
        end
    end
    table.sort(out, function(a, b) return a.score > b.score end)
    while n and #out > n do table.remove(out) end
    return out
end

-- Guider vers une zone : le donneur faisable le plus proche de son centre, sinon son centre
function M:GoToZone(z)
    local Q = Qs()
    local me = WK.DB:Me() or {}
    local lvl = level()
    local best, bd
    for _, q in ipairs(Q:OnMap(z.map)) do
        if q.x and Q:ForChar(q, me) and Q:State(q, me) == "avail" and (q.lvl or 0) <= lvl + 2 then
            local d = (q.x / 100 - 0.5) ^ 2 + (q.y / 100 - 0.5) ^ 2
            if not bd or d < bd then best, bd = q, d end
        end
    end
    if best then Q:GuideTo(best) return end
    local t = { map = z.map, x = 0.5, y = 0.5, e = { 50, 50, 0, nil, nil, z.name, z.name, T("Zone conseillée") } }
    t.cont, t.wx, t.wy = G().ToWorld(z.map, 0.5, 0.5)
    G():Start(t, "Zone conseillée", "zone")
end

---------------------------------------------------------------------------
-- B · Étapes du guide
---------------------------------------------------------------------------
-- Objets en sac qui démarrent une quête pas encore faite
function M:QuestItems()
    local out = {}
    if not WK:NeedData("guide de montée") or not WK.QuestItemStart then return out end
    local me = WK.DB:Me() or {}
    local done = (me.quests and me.quests.done) or {}
    for bag = 0, 4 do
        for slot = 1, (WK.Container.NumSlots(bag) or 0) do
            local id = WK.Container.Info(bag, slot)
            local qid = id and WK.QuestItemStart[id]
            if qid and not done[qid] and not WK.modules.QuestTrack:InLog(qid) then
                table.insert(out, { item = id, qid = qid, bag = bag, slot = slot })
            end
        end
    end
    return out
end

local skipped = {}   -- étapes passées pendant la session : [clé] = true
local smemo = {}
function M:Invalidate() smemo = {}; zmemo = {} end
function M:Skip(key)
    -- « Tournée en cours » : c'est l'étape de la tournée qui est passée (avant, la ligne du guide était cachée pour
    -- toute la séance, et les tournées suivantes avec elle, pendant que la tournée continuait)
    if key == "tour" and P() and P():Tour() then P():Skip() self:Changed() return end
    skipped[key] = true; smemo = {}; WK:NotifyChanged(); self:Changed()
end

-- { { key, kind, title, sub, act = fonction, auto (lancée seule quand on suit le guide) } }
function M:Steps()
    -- lue par la carte à l'écran chaque seconde : gardée 2 s
    local now = GetTime and GetTime() or time()
    local cf = self:Config()
    local sig = tostring(cf.noDungeons) .. tostring(cf.noProf) .. WK:CharKey()
    if smemo.steps and smemo.sig == sig and now - smemo.at < 2 then return smemo.steps, smemo.zones end
    local st, zs = self:StepsNow()
    smemo.steps, smemo.zones, smemo.at, smemo.sig = st, zs, now, sig
    return st, zs
end
function M:StepsNow()
    local steps = {}
    local function add(s) if not skipped[s.key] then table.insert(steps, s) end end
    local lvl = level()
    local cfg = self:Config()
    local key = WK:CharKey()
    local Q = Qs()
    local here = Q:PlayerZone()
    -- objets qui démarrent une quête
    for _, it in ipairs(self:QuestItems()) do
        local name = (WK.GetItemInfo and WK.GetItemInfo(it.item)) or ("#" .. it.item)
        add({ key = "item:" .. it.item, kind = "item", title = string.format(T("Lancer la quête de l'objet : %s"), name),
            sub = T("clic droit sur l'objet dans tes sacs") })
    end
    -- tournée en cours
    local tour = P() and P():Tour()
    if tour and tour.steps[tour.idx] then
        add({ key = "tour", kind = "tour", title = string.format(T("Tournée en cours : étape %d / %d"), tour.idx, #tour.steps),
            sub = P():StepTitle(tour.steps[tour.idx]) })
    end
    -- maître de classe : les sorts à apprendre maintenant (Modules/ClassSpells.lua) ; sinon tous les deux niveaux
    local CS = WK.modules.ClassSpells
    -- option « Maître de classe » coupée (trainerTour = false) : pas d'étape de maître
    local trainerOn = cfg.trainerTour ~= false
    local cr = CS and trainerOn and CS:ForChar() or nil
    -- maître déjà vu à ce niveau (sorts pas tous pris : or, sort donné par une quête) : plus d'étape ; avant,
    -- elle restait en tête et le guide suivi ne passait plus jamais à la tournée ni au changement de zone
    local visited = (cfg.trainer[key] or 0) >= lvl
    if trainerOn and cr and #cr.now > 0 and not visited then
        add({ key = "trainer:" .. lvl, kind = "trainer",
            title = string.format(T("Maître de classe : %d sort(s) à apprendre"), #cr.now),
            sub = cr.costNow > 0 and CS:Money(cr.costNow) or T("le maître le plus proche"), auto = true,
            act = function() G():GoTo("trainer") end })
    elseif trainerOn and not cr then
        local seen = cfg.trainer[key] or 0
        if lvl >= 2 and lvl % 2 == 0 and seen < lvl then
            add({ key = "trainer:" .. lvl, kind = "trainer", title = string.format(T("Maître de classe : nouveaux sorts (niveau %d)"), lvl),
                sub = T("le maître le plus proche"), auto = true, act = function() G():GoTo("trainer") end })
        end
    end
    -- point de vol de la zone pas encore appris
    local F = WK.modules.Flight
    local fm = here and F and F.MissingFlightPoints and F:MissingFlightPoints(here) or {}
    if fm[1] then
        local t = fm[1]
        add({ key = "flight:" .. here, kind = "flight", title = T("Apprendre le point de vol de la zone"),
            sub = t.distance and string.format(T("à %d m"), math.floor(t.distance)) or nil, auto = true,
            act = function() F:GuideToFlightPoint(t) end })
    end
    -- zone conseillée et pierre de foyer
    local zones = self:BestZones(3)
    local best = zones[1]
    local hereZ
    for _, z in ipairs(zones) do if z.here then hereZ = z end end
    local me = WK.DB:Me() or {}
    local inn = G():Nearest({ 4096 })
    if hereZ and inn and inn.distance and inn.distance < 400 and me.hearth then
        local h = me.hearth
        local far = not (h.cont and inn.cont and h.cont == inn.cont and math.sqrt((h.wx - inn.wx) ^ 2 + (h.wy - inn.wy) ^ 2) < 500)
        if far then
            add({ key = "hearth:" .. here, kind = "hearth", title = T("Lier ta pierre de foyer à l'auberge d'ici"),
                sub = string.format(T("à %d m · tu montes dans cette zone"), math.floor(inn.distance)),
                act = function() G():Start(inn, "Auberge", "inn") end })
        end
    end
    -- tournée de la zone
    if not tour and P() then
        local plan = P():Build()
        if #plan.steps > 0 then
            local xp = 0
            local coins = P():Coins()
            local labels = {}
            for _, k in ipairs(coins) do
                for _, e in ipairs(k.quests) do if e.picked then xp = xp + (e.xp or 0) end end
                if #labels < 2 then table.insert(labels, k.label) end
            end
            add({ key = "tour:" .. (here or 0), kind = "tour", auto = true, -- clé stable : passée, elle ne revient pas pour une quête cochée de plus
                title = string.format(T("Tournée de la zone : %d étapes"), #plan.steps),
                sub = string.format(T("env. %d min · +%d XP · niveau %.1f à la fin"), math.max(1, math.floor(plan.secs / 60 + 0.5)), xp, self:LevelAfter(xp)),
                -- lancée par le guide : les étapes passées à la main pendant la tournée d'avant restent passées
                act = function() P():Start({ keepSkipped = true }) end })
        end
    end
    -- donjon à ton niveau
    if not cfg.noDungeons and WK.modules.Dungeons then
        -- quêtes du donjon encore à faire pour ce perso (un donjon dont toutes les quêtes sont faites est écarté)
        local Dg, Qm = WK.modules.Dungeons, Qs()
        local function questsLeft(d)
            if not (Dg.Quests and Qm and Qm.State) then return nil, 0 end
            local list = Dg:Quests(d, me)
            local left = 0
            for _, q in ipairs(list) do
                local ok, st = pcall(Qm.State, Qm, q, me)
                if ok and st ~= "done" then left = left + 1 end
            end
            return left, #list
        end
        local pick, pd, pickLeft
        for _, d in ipairs(Dg:All()) do
            if not d.raid and d.min and d.max and lvl >= d.min and lvl <= d.max - 2 then
                local left, total = questsLeft(d)
                if not (total > 0 and left == 0) then
                    local mid = (d.min + d.max) / 2
                    local dd = math.abs(mid - lvl)
                    if not pd or dd < pd then pick, pd, pickLeft = d, dd, left end
                end
            end
        end
        if pick then
            add({ key = "dungeon:" .. pick.key, kind = "dungeon", title = string.format(T("Donjon à ton niveau : %s"), pick.name),
                sub = string.format(T("niveau %d à %d · cherche un groupe (page LFG)"), pick.min, pick.max)
                    .. ((pickLeft or 0) > 0 and (" · " .. string.format(T("%d quête(s) à faire"), pickLeft)) or ""),
                act = function() WK.modules.Dungeons:GuideTo(pick) end })
        end
    end
    -- zone suivante : la meilleure si ce n'est pas celle-ci (ou celle-ci épuisée)
    if best and not best.here then
        add({ key = "zone:" .. best.map, kind = "zone", auto = true,
            title = string.format(T("Changer de zone : %s (niveau %d à %d)"), best.name or "?", best.min, best.max),
            sub = string.format(T("+%d XP · %d quêtes%s"), best.xp, best.count, best.flightMissing and (" · " .. T("point de vol à apprendre en arrivant")) or ""),
            act = function() M:GoToZone(best) end })
    end
    return steps, zones
end

function M:Following() return self:Config().follow[WK:CharKey()] and true or false end

-- Lance l'étape en cours (ou la n-ième)
function M:Run(i)
    local steps = self:Steps()
    local s = steps[i or 1]
    if s and s.act then s.act() end
    self:Changed()
end

function M:Follow(v)
    self:Invalidate()
    self:Config().follow[WK:CharKey()] = v and true or nil
    self.lastAuto = nil
    if v then self:Run(1) end
    self:Changed()
end

-- Quand on suit le guide : une étape « auto » se lance seule si rien n'est en cours (tournée, guidage)
function M:Tick()
    if not on() or not self:Following() then return end
    if InCombatLockdown and InCombatLockdown() then return end
    if P() and P():Tour() then return end
    if G().target and G().target.kind ~= "qtrack" then return end
    -- seule la 1re étape compte ; objet, pierre de foyer et donjon se font soi-même
    local s = self:Steps()[1]
    -- une étape n'est relancée que si elle a changé, ou si sa tournée est allée au bout (Finish vide lastAuto) :
    -- une étape arrêtée par le joueur (tournée arrêtée, flèche fermée) ne repart plus d'elle-même
    local now = _G.GetTime and _G.GetTime() or 0
    if s and s.auto and s.act and s.key ~= self.lastAuto then
        self.lastAuto, self.lastAutoAt = s.key, now
        s.act()
        self:Changed()
    end
end

function M:Changed()
    if WK.UI.RefreshQuestTracker then WK.UI:RefreshQuestTracker() end
    WK:NotifyChanged()
end

---------------------------------------------------------------------------
-- Évènements
---------------------------------------------------------------------------
local pending
local function soon(delay)
    M:Invalidate()
    if pending then return end
    pending = true
    C_Timer.After(delay or 2, function() pending = nil; M:Tick() end)
end
WK:On("QUEST_ACCEPTED", function(a, b)
    -- (index du journal, n°) sur certains clients, (n°) sur d'autres : même lecture que Modules/Quests.lua
    local qid = (type(b) == "number" and b) or (type(a) == "number" and (b == nil or a > 100) and a) or nil
    if not qid then return end
    local c = M:Config()
    local k = WK:CharKey()
    c.acc[k] = c.acc[k] or {}
    c.acc[k][qid] = time()
end)
WK:On("QUEST_TURNED_IN", function(qid)
    local c = M:Config()
    local k = WK:CharKey()
    local at = c.acc[k] and c.acc[k][qid]
    if at then
        local d = time() - at
        if d > 20 and d < 2 * 3600 then c.times[qid] = d end
        c.acc[k][qid] = nil
    end
    -- (suite de quête dans le coin : QuestPlan refait déjà la tournée après un rendu ; le second recalcul d'ici,
    -- qui ne regardait ni la pause ni les coches, est retiré)
    soon(3)
end)
WK:On("TRAINER_SHOW", function()
    if IsTradeskillTrainer and IsTradeskillTrainer() then return end
    -- maître de classe seulement (un maître d'armes, de familiers ou de monte cachait sinon l'étape « Maître de
    -- classe » et le nœud de la tournée) ; un peu plus tard : la liste du maître arrive après l'ouverture
    _G.C_Timer.After(0.5, function()
        local CS = WK.modules.ClassSpells
        if CS and CS.IsClassTrainer and not CS.IsClassTrainer() then return end
        M:Config().trainer[WK:CharKey()] = level()
        if P() and P().Invalidate then P():Invalidate() end
        M:Invalidate()
        M:Changed()
    end)
end)
WK:On("PLAYER_LEVEL_UP", function() soon(4) end)
WK:On("ZONE_CHANGED_NEW_AREA", function() soon(3) end)
-- journal changé pour de vrai (quêtes, prêtes, avancée) seulement : cet évènement arrive sans arrêt en combat
-- et au butin, et refaisait le guide (toutes les zones + la tournée) environ chaque seconde
local lastLogSig
WK:On("QUEST_LOG_UPDATE", function()
    if not M:Following() then return end
    local QT = WK.modules.QuestTrack
    local sig = QT and QT.LogSignature and QT.LogSignature()
    if sig and sig == lastLogSig then return end
    lastLogSig = sig
    soon(3)
end)
-- objet qui démarre une quête, ramassé : rappel une fois par objet
WK:On("BAG_UPDATE_DELAYED", function()
    -- base des objets qui démarrent une quête : dans le dossier chargé à la demande, pas chargé pour ce rappel
    if not on() or not WK.dataLoaded then return end
    local c = M:Config()
    for _, it in ipairs(M:QuestItems()) do
        if not c.told[it.item] then
            c.told[it.item] = true
            local _, link = WK.GetItemInfo(it.item)
            local name = link or (WK.GetItemInfo(it.item)) or ("#" .. it.item)
            -- dans le chat (les rappels à l'écran ont été retirés : avant, rien ne s'affichait)
            WK:Print(string.format(T("%s démarre une quête : clic droit dessus dans tes sacs."), name))
        end
    end
end)
-- fin d'une tournée suivie : la suite du guide
local oldFinish
WK:On("PLAYER_LOGIN", function()
    local QP = P()
    if QP and QP.Finish and not oldFinish then
        oldFinish = QP.Finish
        QP.Finish = function(self, ...)
            oldFinish(self, ...)
            M.lastAuto = nil -- la suite peut relancer la même étape (tournée de la zone)
            soon(4)
        end
    end
end)
