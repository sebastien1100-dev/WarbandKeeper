local ADDON_NAME, WK = ...
local M = WK:NewModule("BoatTimes")
local T = function(s) return WK.T(s) end

-- Horaires des bateaux et zeppelins, appris en les prenant (Modules/Nav.lua appelle Learn à chaque
-- traversée : heure de départ du quai, durée du trajet). Les fichiers du jeu ne donnent pas le tour
-- des bateaux : il se déduit des départs vus (un tour = trajet aller + attente + retour + attente).
--   WK.DB.global.nav.sched[ligne] = { a = { départs du quai a }, b = { départs du quai b }, ta, tb (trajets) }
-- Ligne : une entrée de MapLayers:AllTransports() (a et b = { carte, x, y, nom }), clé tirée des quais.
local DWELL = 45      -- attente à quai supposée tant qu'un seul départ est connu
local KEEP = 12       -- départs gardés par quai
local WINDOW = 36 * 3600 -- départs comptés : 36 h autour du plus récent (un redémarrage du serveur décale tout)

local function now() return (GetServerTime and GetServerTime()) or time() end
M.Now = now
local function store()
    local g = WK.DB.global
    g.nav = g.nav or {}
    g.nav.sched = g.nav.sched or {}
    return g.nav.sched
end
local function dist(ax, ay, bx, by) local dx, dy = ax - bx, ay - by; return math.sqrt(dx * dx + dy * dy) end
local function world(pt)
    local G = WK.modules.Guide
    if not (G and G.ToWorld and pt) then return nil end
    return G.ToWorld(pt[1], pt[2] / 100, pt[3] / 100)
end
function M.Key(l)
    return string.format("%d:%d:%d>%d:%d:%d", l.a[1], math.floor(l.a[2] + 0.5), math.floor(l.a[3] + 0.5),
        l.b[1], math.floor(l.b[2] + 0.5), math.floor(l.b[3] + 0.5))
end

-- Ligne d'un trajet fait (quais { c, wx, wy }) et côté du départ ("a" : parti du quai a de la ligne)
function M:Match(from, to)
    local L = WK.modules.MapLayers
    for _, l in ipairs(L and L:AllTransports() or {}) do
        local ca, ax, ay = world(l.a)
        local cb, bx, by = world(l.b)
        if ax and bx then
            if ca == from.c and cb == to.c and dist(ax, ay, from.wx, from.wy) < 300 and dist(bx, by, to.wx, to.wy) < 300 then return l, "a" end
            if cb == from.c and ca == to.c and dist(bx, by, from.wx, from.wy) < 300 and dist(ax, ay, to.wx, to.wy) < 300 then return l, "b" end
        end
    end
end

local models = {}
-- Traversée faite : départ (heure du serveur) et arrivée
function M:Learn(from, to, dep, arr)
    -- ligne des fichiers du jeu (Modules/BoatLines.lua) : départ noté là-bas
    local BL = WK.modules.BoatLines
    if BL and dep and BL:Learn(from, to, dep, arr) then return true end
    local l, side = self:Match(from, to)
    if not (l and dep) then return nil end
    local key = M.Key(l)
    local tr = arr and (arr - dep)
    if not (tr and tr > 15 and tr < 1500) then tr = nil end
    if M.AddObs(key, side, dep, tr) then M:Broadcast(key, side, dep, tr) end
    return l
end
-- Ajoute un départ (et la durée du trajet) à une ligne ; false si déjà connu (même départ à 20 s près)
function M.AddObs(key, side, dep, tr, weight)
    local s = store()
    local e = s[key] or { a = {}, b = {} }
    s[key] = e
    e.a, e.b = e.a or {}, e.b or {}
    local list = e[side]
    for _, t in ipairs(list) do if math.abs(t - dep) < 20 then return false end end
    table.insert(list, dep)
    table.sort(list)
    while #list > KEEP do table.remove(list, 1) end
    -- départs vus par ce joueur (weight absent) : seuls renvoyés à la connexion
    if not weight then
        e.mine = e.mine or {}
        e.mine[side .. dep] = true
    end
    if tr then
        local f = side == "a" and "ta" or "tb"
        local wgt = weight or 0.4
        e[f] = e[f] and math.floor(e[f] * (1 - wgt) + tr * wgt + 0.5) or tr
    end
    e.n = (e.n or 0) + 1
    e.at = now()
    models[key] = nil
    return true
end

-- Modèle d'une ligne : tour P, trajets, attente w (supposée égale aux deux quais), départ de référence du quai a
function M:Model(l)
    local key = M.Key(l)
    local e = store()[key]
    if not e then return nil end
    local m = models[key]
    if m and m.at == e.at then return m end
    local ta, tb = e.ta or e.tb, e.tb or e.ta
    if not ta then return nil end
    local obs, last = {}, 0
    for _, side in ipairs({ "a", "b" }) do for _, t in ipairs(e[side] or {}) do last = math.max(last, t) end end
    for _, side in ipairs({ "a", "b" }) do
        for _, t in ipairs(e[side] or {}) do if last - t < WINDOW then table.insert(obs, { side, t }) end end
    end
    if #obs == 0 then return nil end
    local base = ta + tb
    local P, est
    local function offB(p) return (p + ta - tb) / 2 end -- départ du quai b après celui du quai a
    local guess = false
    if #obs < 2 then
        -- un seul départ vu : le tour n'est pas connu, pas de compte à rebours affiché (deviné seulement)
        P, est, guess = base + 2 * DWELL, true, true
    else
        local function score(p)
            local sc, off = 0, offB(p)
            for i = 1, #obs do
                for j = i + 1, #obs do
                    local d = obs[j][2] - obs[i][2]
                    if obs[i][1] ~= obs[j][1] then d = d - (obs[i][1] == "a" and off or -off) end
                    local r = d % p
                    if r > p / 2 then r = p - r end
                    sc = sc + r * r
                end
            end
            return sc
        end
        local best, bestS
        local scores = {}
        for p = base + 10, base + 600, 0.5 do
            local sc = score(p)
            scores[#scores + 1] = { p, sc }
            if not bestS or sc < bestS then best, bestS = p, sc end
        end
        P = best
        local pairsN = #obs * (#obs - 1) / 2
        local tol = math.max(bestS * 2, pairsN * 16)
        est = bestS / pairsN > 36
        for _, ps in ipairs(scores) do
            if math.abs(ps[1] - best) > 6 and ps[2] <= tol then est = true break end
        end
    end
    local w = math.max(5, (P - ta - tb) / 2)
    local ref = obs[1]
    for _, o in ipairs(obs) do if o[2] > ref[2] then ref = o end end
    local tA = ref[1] == "a" and ref[2] or (ref[2] - offB(P))
    m = { P = P, ta = ta, tb = tb, w = w, tA = tA, est = est, guess = guess, n = #obs, at = e.at }
    models[key] = m
    return m
end
function M:Known(l) return self:Model(l) ~= nil end

-- État au quai side ("a" ou "b") : secondes avant le départ, à quai ?, départ suivant, estimation ?
-- quai d'une paire de ligne du jeu (MapLayers:AllTransports) : côté a = quai si, côté b = quai sj
local function gameStop(l, side) return l.game and (side == "a" and l.si or l.sj) end
function M:State(l, side, t)
    if l.game then return WK.modules.BoatLines:State(l.game, gameStop(l, side), t) end
    local m = self:Model(l)
    if not m then return nil end
    t = t or now()
    local dep0 = m.tA + (side == "a" and 0 or (m.ta + m.w))
    local k = math.ceil((t - dep0) / m.P)
    local inn = dep0 + k * m.P - t
    return { inn = inn, following = inn + m.P, atDock = inn <= m.w, est = m.est, guess = m.guess, P = m.P, w = m.w,
             travel = side == "a" and m.ta or m.tb, n = m.n }
end
-- Où est le bateau : fraction du trajet a » b (0 = quai a, 1 = quai b) et sens ("ab", "ba" ou nil à quai)
function M:ShipPos(l, t)
    local m = self:Model(l)
    if not m then return nil end
    local x = ((t or now()) - m.tA) % m.P
    if x < m.ta then return x / m.ta, "ab" end
    x = x - m.ta
    if x < m.w then return 1, nil end
    x = x - m.w
    if x < m.tb then return 1 - x / m.tb, "ba" end
    return 0, nil
end

function M.Clock(sec)
    sec = math.max(0, math.floor(sec or 0))
    if sec >= 3600 then return string.format("%d:%02d:%02d", sec / 3600, (sec % 3600) / 60, sec % 60) end
    return string.format("%d:%02d", sec / 60, sec % 60)
end
-- Attente moyenne d'une ligne sans heure calée (lignes du jeu au tour connu) : « attente moy. ~2:45 »
function M:AvgText(l)
    local avg = l and l.game and WK.modules.BoatLines:AvgWait(l.game)
    return avg and string.format(T("attente moy. ~%s"), M.Clock(avg)) or nil
end
-- Texte court sous un quai : « à quai · 0:42 », « dans 3:10 » (« env. » : tour encore estimé)
function M:Label(l, side)
    local s = self:State(l, side)
    if not s or s.guess then return nil end
    local pre = s.est and T("env. ") or ""
    if s.atDock then return string.format(T("à quai · %s"), pre .. M.Clock(s.inn)), s end
    return string.format(T("dans %s"), pre .. M.Clock(s.inn)), s
end
-- Côté d'un quai donné ({ carte, x, y }) sur la ligne
function M.SideOf(l, here)
    if here == l.a then return "a" end
    if here == l.b then return "b" end
    if here and here[1] == l.a[1] and math.abs(here[2] - l.a[2]) < 0.01 and math.abs(here[3] - l.a[3]) < 0.01 then return "a" end
    return "b"
end
-- Lignes de l'infobulle d'un quai
function M:TooltipLines(l, side)
    local out = {}
    local s = self:State(l, side)
    if l.game then
        local BL = WK.modules.BoatLines
        local g = l.game
        table.insert(out, { T(g.vessel or ""), 0.75, 0.75, 0.75 })
        if not s then
            local avg = BL:AvgWait(g)
            if avg then table.insert(out, { string.format(T("Attente moyenne : ~%s (un départ toutes les %s)"), M.Clock(avg), M.Clock(avg * 2)), 0.85, 0.85, 0.85 }) end
            table.insert(out, { T("Heure pas encore calée : elle se cale toute seule (traversée, annonce du maître de quai, partage)."), 0.6, 0.6, 0.6, true })
            return out
        end
        local pre = s.est and T("env. ") or ""
        local to = BL:StopName(g, s.next)
        if s.atDock then table.insert(out, { string.format(T("À quai, départ vers %s dans %s"), to, pre .. M.Clock(s.inn)), 0.62, 0.85, 0.48 })
        else table.insert(out, { string.format(T("Départ vers %s dans %s"), to, pre .. M.Clock(s.inn)), 1, 1, 1 }) end
        table.insert(out, { string.format(T("Suivant dans %s · trajet %s · tour %s"), pre .. M.Clock(s.following), M.Clock(s.travel), M.Clock(s.P)), 0.75, 0.75, 0.75 })
        if s.est then table.insert(out, { T("Heure estimée : elle se précise à chaque départ vu ou partagé."), 0.6, 0.6, 0.6, true }) end
        return out
    end
    if not s then
        table.insert(out, { T("Horaires pas encore connus : prends-le une fois pour les apprendre."), 0.6, 0.6, 0.6 })
        return out
    end
    if s.guess then
        table.insert(out, { T("Horaires en cours d'apprentissage : prends-le encore une fois, ou signale son départ depuis le bandeau du quai."), 0.6, 0.6, 0.6 })
        return out
    end
    local pre = s.est and T("env. ") or ""
    if s.atDock then table.insert(out, { string.format(T("À quai, départ dans %s"), pre .. M.Clock(s.inn)), 0.62, 0.85, 0.48 })
    else table.insert(out, { string.format(T("Départ dans %s"), pre .. M.Clock(s.inn)), 1, 1, 1 }) end
    table.insert(out, { string.format(T("Suivant dans %s · trajet %s · tour %s"), pre .. M.Clock(s.following), M.Clock(s.travel), M.Clock(s.P)), 0.75, 0.75, 0.75 })
    if s.est then table.insert(out, { T("Tour encore estimé : il se précise à chaque traversée."), 0.6, 0.6, 0.6 }) end
    return out
end

-- Vu du quai, sans le prendre : « il part » (départ de ce quai maintenant) ou « il arrive » (il vient
-- de l'autre quai : départ de là-bas = maintenant - durée du trajet). Il faut la durée du trajet (une traversée faite).
function M:Observe(l, side, kind)
    if l.game then return WK.modules.BoatLines:Observe(l.game, gameStop(l, side), kind) end
    local key = M.Key(l)
    local e = store()[key]
    if not e then return false end
    local t = now()
    local s2, dep = side, t
    if kind == "arrive" then
        s2 = side == "a" and "b" or "a"
        local tr = s2 == "a" and (e.ta or e.tb) or (e.tb or e.ta)
        if not tr then return false end
        dep = t - tr
    end
    if M.AddObs(key, s2, dep) then M:Broadcast(key, s2, dep, nil) end
    return true
end

---------------------------------------------------------------------------
-- Partage avec le groupe et la guilde (joueurs qui ont Warband Keeper) : chaque départ appris ou signalé
-- est envoyé (message d'addon « WKboat », « S;ligne;côté;départ;trajet »), et à la connexion les départs
-- des 36 dernières heures. Reçu : ajouté s'il concerne une ligne connue ici. Jamais renvoyé plus loin.
-- Réglage Guide:Config().boatShare. Heure du serveur : la même pour tous les joueurs du royaume.
---------------------------------------------------------------------------
local PREFIX = "WKboat"
local queue, sending = {}, false
M.received = 0
local function shareOn()
    local G = WK.modules.Guide
    return G and G:Config().boatShare ~= false
end
local function channels()
    local out = {}
    if IsInGuild and IsInGuild() then table.insert(out, "GUILD") end
    if IsInRaid and IsInRaid() then table.insert(out, "RAID")
    elseif IsInGroup and IsInGroup() and not (LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and not IsInGroup(LE_PARTY_CATEGORY_HOME)) then
        table.insert(out, "PARTY")
    end
    return out
end
local function pump()
    if #queue == 0 then sending = false return end
    sending = true
    local msg = table.remove(queue, 1)
    if not ((InCombatLockdown and InCombatLockdown()) or (IsInInstance and select(1, IsInInstance()))) then
        for _, ch in ipairs(channels()) do pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, ch) end
    end
    C_Timer.After(0.4, pump)
end
local function send(msg)
    if not (shareOn() and C_ChatInfo and C_ChatInfo.SendAddonMessage) then return end
    if #queue > 60 then return end
    table.insert(queue, msg)
    if not sending then pump() end
end
M.Send = send
function M:Broadcast(key, side, dep, tr)
    send(string.format("S;%s;%s;%d;%d", key, side, math.floor(dep), tr and math.floor(tr) or 0))
end
-- lignes connues ici (quais d'avance et bateaux appris), par clé
local function knownKeys()
    local L = WK.modules.MapLayers
    local out = {}
    for _, l in ipairs(L and L:AllTransports() or {}) do out[M.Key(l)] = true end
    return out
end
WK:On("PLAYER_LOGIN", function()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end
    -- à la connexion : les départs récents de chaque ligne (les plus récents d'abord, au plus 3 par quai)
    C_Timer.After(25, function()
        local t = now()
        local BL = WK.modules.BoatLines
        for _, r in ipairs(BL and BL:Recent() or {}) do BL:Broadcast(r[1], r[2], r[3]) end
        for key, e in pairs(store()) do
            -- ménage : ne garder que les marques des départs encore notés
            local keep = {}
            for _, side in ipairs({ "a", "b" }) do
                for _, d in ipairs(e[side] or {}) do if e.mine and e.mine[side .. d] then keep[side .. d] = true end end
            end
            e.mine = next(keep) and keep or nil
            for _, side in ipairs({ "a", "b" }) do
                local list = e[side] or {}
                for i = #list, math.max(1, #list - 2), -1 do
                    if t - list[i] < WINDOW and e.mine and e.mine[side .. list[i]] then
                        M:Broadcast(key, side, list[i], side == "a" and e.ta or e.tb)
                    end
                end
            end
        end
    end)
end)
WK:On("CHAT_MSG_ADDON", function(prefix, msg, _, sender)
    local rd = WK.modules.QoL and WK.modules.QoL.Readable or function(v) return v end
    prefix, msg, sender = rd(prefix), rd(msg), rd(sender)
    if prefix ~= PREFIX or type(msg) ~= "string" or not shareOn() then return end
    local me = UnitName and UnitName("player")
    if type(sender) == "string" and me and sender:match("^[^%-]+") == me then return end
    if msg:sub(1, 2) == "G;" then
        local BL = WK.modules.BoatLines
        if BL and BL:Receive(msg, sender) then
            M.received = M.received + 1
            if WK.modules.Nav and WK.modules.Nav.BoatLog then
                WK.modules.Nav.BoatLog(string.format("horaire reçu de %s", tostring(sender):match("^[^%-]+") or "?"))
            end
        end
        return
    end
    local key, side, dep, tr = msg:match("^S;([^;]+);([ab]);(%d+);(%d+)$")
    dep, tr = tonumber(dep), tonumber(tr)
    if not (key and dep) then return end
    local t = now()
    if dep > t + 60 or t - dep > WINDOW then return end
    if not knownKeys()[key] then return end
    if tr and (tr <= 15 or tr >= 1500) then tr = nil end
    -- durée reçue : prise si on n'en a pas, à peine mélangée sinon
    if M.AddObs(key, side, dep, tr, 0.2) then
        M.received = M.received + 1
        if WK.modules.Nav and WK.modules.Nav.BoatLog then
            WK.modules.Nav.BoatLog(string.format("horaire reçu de %s", tostring(sender):match("^[^%-]+") or "?"))
        end
    end
end)
