local ADDON_NAME, WK = ...
local M = WK:NewModule("BoatLines")
local T = function(s) return WK.T(s) end

-- Lignes de bateaux et de zeppelins tirées des fichiers du jeu (Modules/BoatLinesDB.lua, généré par
-- tools/gen_boats.py) : quais, temps à quai, tracé, tour (mesuré, Nauticus). Chaque bateau fait sa boucle
-- sans fin : il suffit d'un départ vu (traversée, « Il part » / « Il arrive », partage) pour caler l'heure.
--   WK.DB.global.nav.lines[clé] = { obs = { { s = quai, t = départ (heure du serveur) } }, P = tour affiné }
-- Calendrier d'un tour (t = 0 : départ du quai 1) : trajet puis arrêt à chaque quai ; le temps de trajet
-- total (tour - arrêts) est partagé entre les étapes selon leur longueur (plus un départ et un arrêt).
local ACCEL = 600     -- même valeur que tools/gen_boats.py
local KEEP = 16       -- départs gardés par ligne
local FRESH = 12 * 3600   -- au-delà, l'heure calée est dite « estimée »
local WINDOW = 4 * 86400  -- départs plus vieux : oubliés (redémarrages du serveur)
local CONTMAP = { [0] = 1415, [1] = 1414 } -- cartes des continents : Royaumes de l'Est, Kalimdor

local function now() return (GetServerTime and GetServerTime()) or time() end
M.Now = now
local function dist(ax, ay, bx, by) local dx, dy = ax - bx, ay - by; return math.sqrt(dx * dx + dy * dy) end
local function store()
    local g = WK.DB.global
    g.nav = g.nav or {}
    g.nav.lines = g.nav.lines or {}
    return g.nav.lines
end

function M:All() return WK.BoatLines or {} end
local byKey
function M:Get(key)
    if not byKey then byKey = {}; for _, l in ipairs(self:All()) do byKey[l.key] = l end end
    return byKey[key]
end
-- ligne de ma faction (ou neutre)
function M:Mine(l)
    local fac = UnitFactionGroup and UnitFactionGroup("player")
    fac = fac == "Alliance" and "A" or fac == "Horde" and "H" or nil
    return not l.side or not fac or l.side == fac
end
function M:StopName(l, s) return T(l.stops[s] and l.stops[s].name or "?") end
function M:LineName(l)
    local parts = {}
    for i = 1, #l.stops do parts[i] = self:StopName(l, i) end
    return table.concat(parts, " » ")
end

---------------------------------------------------------------------------
-- Calendrier
---------------------------------------------------------------------------
local function sched(l)
    local e = store()[l.key]
    return e
end
-- tour utilisé : affiné en jeu, sinon celui des données
local function period(l)
    local e = sched(l)
    return (e and e.P) or l.period
end
-- décalages dans le tour (t = 0 : départ du quai 1) : départ et arrivée de chaque quai
local function offsets(l, P)
    local n = #l.stops
    local dwell, w = 0, 0
    for i = 1, n do dwell = dwell + (l.stops[i].dwell or 60); w = w + (l.legs[i].len or 0) + ACCEL end
    local travel = math.max(10 * n, P - dwell)
    local dep, arr, leg = { [1] = 0 }, {}, {}
    local t = 0
    for i = 1, n do
        local tr = travel * ((l.legs[i].len or 0) + ACCEL) / w
        leg[i] = tr
        local j = i % n + 1
        t = t + tr
        arr[j] = t
        if j ~= 1 then t = t + (l.stops[j].dwell or 60); dep[j] = t end
    end
    arr[1] = P - (l.stops[1].dwell or 60)
    return dep, arr, leg
end
M.Offsets = offsets

-- Tour affiné à partir des départs vus (lignes « approx » ou sans tour) : celui qui explique le mieux
-- tous les départs, cherché près du tour connu (ou dans une plage large s'il manque)
local function refine(l, e)
    local obs = e.obs
    if #obs < 2 then return end
    local span = obs[#obs].t - obs[1].t
    local P0 = l.period
    local lo, hi, step
    if P0 and l.prec == "exact" then return end
    if P0 then lo, hi, step = P0 - 1.5, P0 + 1.5, 0.002
    else
        local base = 0
        for i = 1, #l.stops do base = base + (l.stops[i].dwell or 60) + ((l.legs[i].len or 0) + ACCEL) / 40 end
        lo, hi, step = base * 0.5, base * 1.8, 0.05
    end
    if span < (P0 or lo) * 0.9 then return end
    -- il faut deux départs du même quai à plusieurs tours d'écart pour affiner (sinon le partage du trajet
    -- entre étapes, approximatif, fausserait le tour)
    local ref0 = obs[#obs]
    local same = false
    for k = 1, #obs - 1 do if obs[k].s == ref0.s and ref0.t - obs[k].t > (P0 or lo) * 2.5 then same = true end end
    if not same then return end
    local best, bestS
    local p = lo
    while p <= hi do
        local dep = offsets(l, p)
        local sc = 0
        local ref = obs[#obs]
        local t0 = ref.t - dep[ref.s]
        for k = 1, #obs - 1 do
            local o = obs[k]
            local d = (o.t - dep[o.s] - t0) % p
            if d > p / 2 then d = p - d end
            -- un départ d'un autre quai dépend du partage du trajet entre étapes : il compte moins
            sc = sc + d * d * (o.s == ref.s and 1 or 0.2)
        end
        if not bestS or sc < bestS then best, bestS = p, sc end
        p = p + step
    end
    e.P = best
end

-- Ajoute un départ vu (quai s, heure du serveur t) ; false si déjà connu à 15 s près
function M:AddObs(l, s, t)
    local st = store()
    local e = st[l.key] or { obs = {} }
    st[l.key] = e
    e.obs = e.obs or {}
    for _, o in ipairs(e.obs) do if o.s == s and math.abs(o.t - t) < 15 then return false end end
    table.insert(e.obs, { s = s, t = t })
    table.sort(e.obs, function(a, b) return a.t < b.t end)
    local cut = now() - WINDOW
    while #e.obs > 0 and (e.obs[1].t < cut or #e.obs > KEEP) do table.remove(e.obs, 1) end
    e.at = now()
    refine(l, e)
    return true
end

-- Calage : départ du quai 1 de référence, et départ de référence propre à chaque quai vu récemment
local function anchor(l)
    local e = sched(l)
    if not (e and e.obs and #e.obs > 0) then return nil end
    local P = period(l)
    local last = e.obs[#e.obs]
    if not P then
        -- pas de tour connu : il faut deux départs du même quai
        return nil
    end
    local dep = offsets(l, P)
    local t0 = last.t - dep[last.s]
    local per = {}
    for _, o in ipairs(e.obs) do
        if last.t - o.t < FRESH then per[o.s] = o.t end
    end
    return { P = P, t0 = t0, per = per, at = last.t, dep = dep }
end

-- État du quai s : secondes avant le prochain départ, à quai ?, départ suivant, quai suivant…
-- nil si l'heure n'est pas calée (aucun départ vu)
function M:State(l, s, t)
    local a = anchor(l)
    if not a then return nil end
    t = t or now()
    local base = a.per[s] or (a.t0 + a.dep[s])
    local k = math.ceil((t - base) / a.P)
    local inn = base + k * a.P - t
    local dwell = l.stops[s].dwell or 60
    local _, _, leg = offsets(l, a.P)
    local stale = (now() - a.at) > FRESH
    local est = stale or (l.prec ~= "exact" and not (sched(l) and sched(l).P)) or not l.period
    return { inn = inn, following = inn + a.P, atDock = inn <= dwell, est = est, P = a.P, w = dwell,
             travel = leg[s], next = s % #l.stops + 1, exactStop = a.per[s] ~= nil }
end
-- Prochains départs de ce quai : { { inn, arrive (secondes avant l'arrivée au quai suivant), to } }
function M:Departures(l, s, count)
    local st = self:State(l, s)
    if not st then return {} end
    local out = {}
    for k = 0, (count or 3) - 1 do
        local inn = st.inn + k * st.P
        table.insert(out, { inn = inn, arrive = inn + st.travel, to = self:StopName(l, st.next), est = st.est })
    end
    return out
end

-- Position du bateau maintenant : c, x, y (monde), quai où il est (ou nil), étape en cours et avancée (0..1)
function M:ShipPos(l, t)
    local a = anchor(l)
    if not a then return nil end
    t = t or now()
    local P = a.P
    local dep, arr, leg = offsets(l, P)
    local x = (t - a.t0) % P
    local n = #l.stops
    for i = 1, n do
        local j = i % n + 1
        local d0 = dep[i]
        local a1 = (j == 1) and (P - (l.stops[1].dwell or 60)) or arr[j]
        if x >= d0 and x < a1 then
            local f = (x - d0) / math.max(1, a1 - d0)
            local g = l.legs[i]
            -- position le long du tracé (parts à vitesse constante, sauts de continent instantanés)
            local pts, total = g.pts, g.len or 0
            local want, acc = f * total, 0
            for k = 1, #pts / 3 - 1 do
                local c1, x1, y1 = pts[k * 3 - 2], pts[k * 3 - 1], pts[k * 3]
                local c2, x2, y2 = pts[k * 3 + 1], pts[k * 3 + 2], pts[k * 3 + 3]
                if c1 == c2 then
                    local sl = dist(x1, y1, x2, y2)
                    if acc + sl >= want and sl > 0 then
                        local u = (want - acc) / sl
                        return c1, x1 + (x2 - x1) * u, y1 + (y2 - y1) * u, nil, i, f, math.atan2(y2 - y1, x2 - x1)
                    end
                    acc = acc + sl
                end
            end
            local sj = l.stops[j]
            return sj.c, sj.x, sj.y, nil, i, f
        end
    end
    -- à quai : celui dont l'arrêt contient x
    for i = 1, n do
        local a1 = (i == 1) and (P - (l.stops[1].dwell or 60)) or arr[i]
        local d1 = (i == 1) and P or dep[i]
        if x >= a1 and x < d1 then local si = l.stops[i]; return si.c, si.x, si.y, i, nil, nil end
    end
    local s1 = l.stops[1]
    return s1.c, s1.x, s1.y, 1, nil, nil
end

-- Quai d'une ligne à moins de range m d'une position monde (c, x, y)
function M:StopNear(c, x, y, range)
    local best, bl, bs
    for _, l in ipairs(self:All()) do
        for s, st in ipairs(l.stops) do
            if st.c == c then
                local d = dist(st.x, st.y, x, y)
                if d < (range or 300) and (not best or d < best) then best, bl, bs = d, l, s end
            end
        end
    end
    return bl, bs, best
end

-- Lignes déjà prises (WK.DB.global.nav.rode[clé]) : seul leur tracé est dessiné sur la carte
local function rode()
    local g = WK.DB.global
    g.nav = g.nav or {}
    g.nav.rode = g.nav.rode or {}
    return g.nav.rode
end
function M:Rode(l) return l and rode()[l.key] == true end

-- Traversée faite (départ { c, wx, wy } » arrivée) : départ noté au quai de départ. true si la ligne est connue.
function M:Learn(from, to, dep)
    for _, l in ipairs(self:All()) do
        for s, st in ipairs(l.stops) do
            local nx = l.stops[s % #l.stops + 1]
            if st.c == from.c and dist(st.x, st.y, from.wx, from.wy) < 300 and nx.c == to.c and dist(nx.x, nx.y, to.wx, to.wy) < 400 then
                rode()[l.key] = true
                if self:AddObs(l, s, dep) then self:Broadcast(l, s, dep) end
                return true
            end
        end
    end
    return false
end
-- Vu du quai : « leave » = il part maintenant, « arrive » = il arrive maintenant (départ = maintenant + arrêt)
function M:Observe(l, s, kind)
    local t = now()
    if kind == "arrive" then t = t + (l.stops[s].dwell or 60) end
    if self:AddObs(l, s, t) then self:Broadcast(l, s, t) end
    return true
end

---------------------------------------------------------------------------
-- Position sur les cartes du jeu (carte de zone, x et y en %) d'un point monde
---------------------------------------------------------------------------
local zoneCache = {}
function M:ToMap(c, x, y)
    local key = c .. ":" .. math.floor(x) .. ":" .. math.floor(y)
    local z = zoneCache[key]
    if z ~= nil then return z and z[1], z and z[2], z and z[3] end
    local cm = CONTMAP[c]
    if not (cm and C_Map and C_Map.GetMapPosFromWorldPos and CreateVector2D) then zoneCache[key] = false return nil end
    local ok, _, pos = pcall(C_Map.GetMapPosFromWorldPos, c, CreateVector2D(x, y), cm)
    if not (ok and pos) then zoneCache[key] = false return nil end
    local px, py = pos.x, pos.y
    if pos.GetXY then px, py = pos:GetXY() end
    local zone = cm
    if C_Map.GetMapInfoAtPosition then
        local ok2, info = pcall(C_Map.GetMapInfoAtPosition, cm, px, py)
        if ok2 and info and info.mapID then zone = info.mapID end
    end
    local ok3, _, zp = pcall(C_Map.GetMapPosFromWorldPos, c, CreateVector2D(x, y), zone)
    if ok3 and zp then
        local zx, zy = zp.x, zp.y
        if zp.GetXY then zx, zy = zp:GetXY() end
        zoneCache[key] = { zone, zx * 100, zy * 100 }
    else
        zoneCache[key] = { cm, px * 100, py * 100 }
    end
    z = zoneCache[key]
    return z[1], z[2], z[3]
end

-- Paires de quais pour MapLayers:AllTransports() (une par étape), quais placés sur les cartes de zone
local pairsCache
function M:Pairs()
    if pairsCache then return pairsCache end
    local out = {}
    for _, l in ipairs(self:All()) do
        local n = #l.stops
        for i = 1, n do
            local j = i % n + 1
            local A, B = l.stops[i], l.stops[j]
            local am, ax, ay = self:ToMap(A.c, A.x, A.y)
            local bm, bx, by = self:ToMap(B.c, B.x, B.y)
            if am and bm then
                -- une ligne à deux quais : une seule paire (aller et retour)
                if n > 2 or i == 1 then
                    table.insert(out, { kind = l.kind, side = l.side, game = l, si = i, sj = j,
                        a = { am, ax, ay, self:StopName(l, i) }, b = { bm, bx, by, self:StopName(l, j) } })
                end
            end
        end
    end
    if #out > 0 then pairsCache = out end
    return out
end

---------------------------------------------------------------------------
-- Partage (message d'addon « WKboat », type « G ») : départ vu d'un quai d'une ligne du jeu
---------------------------------------------------------------------------
function M:Broadcast(l, s, t)
    local BT = WK.modules.BoatTimes
    if BT and BT.Send then BT.Send(string.format("G;%s;%d;%d", l.key, s, math.floor(t))) end
end
function M:Receive(msg, sender)
    local key, s, t = msg:match("^G;([^;]+);(%d+);(%d+)$")
    s, t = tonumber(s), tonumber(t)
    local l = key and self:Get(key)
    if not (l and s and t and l.stops[s]) then return false end
    local n = now()
    if t > n + 120 or n - t > WINDOW then return false end
    return self:AddObs(l, s, t)
end
-- départs récents à envoyer à la connexion (au plus 2 par ligne)
function M:Recent()
    local out = {}
    for key, e in pairs(store()) do
        local l = self:Get(key)
        if l and e.obs then
            for i = #e.obs, math.max(1, #e.obs - 1), -1 do
                if now() - e.obs[i].t < FRESH then table.insert(out, { l, e.obs[i].s, e.obs[i].t }) end
            end
        end
    end
    return out
end

-- Texte à partager dans le chat : « Hurlevent » Auberdine : départ dans 2:10 (à quai) »
function M:ChatText(l, s)
    local st = self:State(l, s)
    local name = self:StopName(l, s) .. " » " .. self:StopName(l, st and st.next or (s % #l.stops + 1))
    local vessel = T(l.vessel or "")
    if not st then return string.format(T("%s (%s) : horaires pas encore connus"), name, vessel) end
    local Clock = WK.modules.BoatTimes.Clock
    local pre = st.est and T("env. ") or ""
    return string.format(st.atDock and T("%s (%s) : à quai, départ dans %s") or T("%s (%s) : départ dans %s, puis toutes les %s"),
        name, vessel, pre .. Clock(st.inn), Clock(st.P))
end

---------------------------------------------------------------------------
-- Annonces des maîtres de quai (« Le … à destination de … vient d'arriver ») : quand tu es près d'un quai,
-- l'arrivée annoncée cale l'heure de la ligne sans la prendre. La ligne est celle du quai le plus proche
-- dont l'autre quai est nommé dans l'annonce (ou la seule ligne de ce quai).
---------------------------------------------------------------------------
local ARRIVED = { "vient d'arriver", "vient d'accoster", "est arriv", "est à quai", "just arrived", "has arrived", "now docked" }
local function lower(s) return (s or ""):lower() end
local lastAnnounce = {}
local function onAnnounce(msg)
    if type(msg) ~= "string" or (issecretvalue and issecretvalue(msg)) then return end
    local m = lower(msg)
    local hit = false
    for _, w in ipairs(ARRIVED) do if m:find(w, 1, true) then hit = true break end end
    if not hit then return end
    local G = WK.modules.Guide
    local p = G and G:PlayerPos()
    if not (p and p.cont) then return end
    local cands = {}
    for _, l in ipairs(M:All()) do
        for s, st in ipairs(l.stops) do
            if st.c == p.cont and dist(st.x, st.y, p.wx, p.wy) < 250 then table.insert(cands, { l = l, s = s }) end
        end
    end
    if #cands == 0 then return end
    local pick
    if #cands == 1 then pick = cands[1]
    else
        for _, c in ipairs(cands) do
            for k = 1, #c.l.stops do
                if k ~= c.s then
                    local fr = lower(c.l.stops[k].name)
                    local tr = lower(T(c.l.stops[k].name))
                    if m:find(fr, 1, true) or m:find(tr, 1, true) then pick = c break end
                end
            end
            if pick then break end
        end
    end
    if not pick then return end
    local key = pick.l.key .. pick.s
    if lastAnnounce[key] and GetTime() - lastAnnounce[key] < 60 then return end
    lastAnnounce[key] = GetTime()
    M:Observe(pick.l, pick.s, "arrive")
    if WK.modules.Nav and WK.modules.Nav.BoatLog then
        WK.modules.Nav.BoatLog(string.format("arrivée annoncée au quai : %s", M:LineName(pick.l)))
    end
end
WK:On("CHAT_MSG_MONSTER_SAY", onAnnounce)
WK:On("CHAT_MSG_MONSTER_YELL", onAnnounce)
