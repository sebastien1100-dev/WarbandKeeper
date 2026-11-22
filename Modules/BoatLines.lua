local ADDON_NAME, WK = ...
local M = WK:NewModule("BoatLines")
local T = function(s) return WK.T(s) end

-- Lignes de bateaux et de zeppelins tirées des fichiers du jeu (Modules/BoatLinesDB.lua, généré par
-- tools/gen_boats.py) : quais, tracé de chaque étape, navire. Aucun horaire : l'addon dit seulement où va
-- chaque navire (bandeau du quai et à bord, tableau, carte, guidage).
--   WK.DB.global.nav.rode[clé] = true : lignes déjà prises (tracé plus marqué sur la carte)
local CONTMAP = { [0] = 1415, [1] = 1414 } -- cartes des continents : Royaumes de l'Est, Kalimdor

local function dist(ax, ay, bx, by) local dx, dy = ax - bx, ay - by; return math.sqrt(dx * dx + dy * dy) end

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
-- escales après le quai s, dans l'ordre du trajet (« Austrivage », puis « Auberdine »)
function M:Destinations(l, s)
    local out = {}
    local n = #l.stops
    for k = 1, n - 1 do out[k] = self:StopName(l, (s + k - 1) % n + 1) end
    return out
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

-- Lignes déjà prises : leur tracé est plus marqué sur la carte
local function rode()
    local g = WK.DB.global
    g.nav = g.nav or {}
    g.nav.rode = g.nav.rode or {}
    return g.nav.rode
end
function M:Rode(l) return l and rode()[l.key] == true end

-- Traversée faite (départ { c, wx, wy } » arrivée) : ligne notée comme prise. true si la ligne est connue.
function M:Learn(from, to)
    for _, l in ipairs(self:All()) do
        for s, st in ipairs(self:Mine(l) and l.stops or {}) do
            local nx = l.stops[s % #l.stops + 1]
            if st.c == from.c and dist(st.x, st.y, from.wx, from.wy) < 300 and nx.c == to.c and dist(nx.x, nx.y, to.wx, to.wy) < 400 then
                rode()[l.key] = true
                return true
            end
        end
    end
    return false
end

---------------------------------------------------------------------------
-- À bord : quelle ligne et quelle étape. Chaque position relevée par Nav (toutes les 0,5 s) est posée sur le
-- tracé des lignes de ta faction ; l'étape retenue est celle que la position suit le mieux sur au moins 30 s
-- (avancée régulière le long du tracé), nettement devant la 2e (deux lignes qui partagent un bout de chemin).
---------------------------------------------------------------------------
local NEAR = 45          -- m : distance au tracé pour qu'une position compte
local FIT_N, FIT_SPAN = 10, 30   -- au moins 10 positions sur 30 s
local LEAD = 1.25        -- avance nécessaire sur la 2e ligne candidate
local MAX_RMS = 40       -- m : écart moyen toléré à la droite (avancée régulière)
-- tronçons d'une étape : { c, x1, y1, x2, y2, d0 (distance depuis le quai), len }
local function segsOf(l, i)
    l._segs = l._segs or {}
    if l._segs[i] then return l._segs[i] end
    local pts, out, acc = l.legs[i].pts, {}, 0
    for k = 1, #pts / 3 - 1 do
        local c1, x1, y1 = pts[k * 3 - 2], pts[k * 3 - 1], pts[k * 3]
        local c2, x2, y2 = pts[k * 3 + 1], pts[k * 3 + 2], pts[k * 3 + 3]
        if c1 == c2 then
            local sl = dist(x1, y1, x2, y2)
            if sl > 0 then table.insert(out, { c1, x1, y1, x2, y2, acc, sl }) end
            acc = acc + sl
        end
    end
    l._segs[i] = out
    return out
end
-- distance parcourue depuis le quai de départ de l'étape i pour une position (nil : trop loin du tracé)
local function along(l, i, c, x, y)
    local best, bd
    for _, g in ipairs(segsOf(l, i)) do
        if g[1] == c then
            local dx, dy = g[4] - g[2], g[5] - g[3]
            local u = ((x - g[2]) * dx + (y - g[3]) * dy) / (g[7] * g[7])
            u = math.max(0, math.min(1, u))
            local d = dist(x, y, g[2] + dx * u, g[3] + dy * u)
            if d <= NEAR and (not bd or d < bd) then bd, best = d, g[6] + u * g[7] end
        end
    end
    return best
end
-- droite d = v (t - t1) + b par moindres carrés : vitesse et écart moyen
local function line(ts, ds)
    local n = #ts
    local t1 = ts[1]
    local st, sd, stt, std = 0, 0, 0, 0
    for k = 1, n do
        local t = ts[k] - t1
        st, sd, stt, std = st + t, sd + ds[k], stt + t * t, std + t * ds[k]
    end
    local den = n * stt - st * st
    if den <= 0 then return nil end
    local v = (n * std - st * sd) / den
    local b = (sd - v * st) / n
    local e2 = 0
    for k = 1, n do local r = ds[k] - (b + v * (ts[k] - t1)); e2 = e2 + r * r end
    return v, math.sqrt(e2 / n)
end

local onboard  -- { cand = { [clé] = { l, i, ts, ds } }, fit = { l, i, key, n, v } }
function M:RideBegin() onboard = { cand = {} } end
function M:RideSample(c, x, y)
    if not onboard then self:RideBegin() end
    local gt = GetTime()
    for _, l in ipairs(self:All()) do
        -- seulement les lignes de ta faction (un zeppelin de l'autre faction peut passer près d'un bateau)
        for i = 1, (self:Mine(l) and #l.legs or 0) do
            local d = along(l, i, c, x, y)
            if d then
                local key = l.key .. ":" .. i
                local cd = onboard.cand[key]
                if not cd then cd = { l = l, i = i, ts = {}, ds = {} }; onboard.cand[key] = cd end
                if #cd.ts < 400 then table.insert(cd.ts, gt); table.insert(cd.ds, d) end
                cd.last = d
            end
        end
    end
    -- reconnue une fois pour toutes (sauf si une autre étape passe nettement devant)
    local fits = {}
    for key, cd in pairs(onboard.cand) do
        local n = #cd.ts
        if n >= FIT_N and cd.ts[n] - cd.ts[1] >= FIT_SPAN then
            local v, rms = line(cd.ts, cd.ds)
            if v and v > 4 and v < 60 and rms <= MAX_RMS then fits[#fits + 1] = { key = key, cd = cd, n = n, v = v } end
        end
    end
    table.sort(fits, function(a, b) return a.n > b.n end)
    local best, second = fits[1], fits[2]
    if not best or (second and best.n < LEAD * second.n) then return end
    if onboard.fit and onboard.fit.key == best.key then return end
    onboard.fit = { l = best.cd.l, i = best.cd.i, key = best.key, n = best.n, v = best.v }
    rode()[best.cd.l.key] = true
    if WK.modules.Nav and WK.modules.Nav.BoatLog then
        WK.modules.Nav.BoatLog(string.format("à bord : %s, étape %d reconnue (%d positions, %.0f m/s)", self:LineName(best.cd.l), best.cd.i, best.n, best.v))
    end
end
-- ligne et étape repérées à bord : { l, i (quai de départ) } ou nil
function M:RideFit() return onboard and onboard.fit end
-- avancement de la traversée reconnue, de 0 (quai de départ) à 1 (escale suivante), d'après la dernière
-- position posée sur le tracé de l'étape ; nil tant que l'étape n'est pas reconnue
function M:RideProgress()
    local f = onboard and onboard.fit
    local cd = f and onboard.cand[f.key]
    if not (cd and cd.last) then return nil end
    local segs = segsOf(f.l, f.i)
    local g = segs[#segs]
    local total = g and (g[6] + g[7]) or 0
    if total <= 0 then return nil end
    return math.max(0, math.min(1, cd.last / total))
end
function M:RideEnd() onboard = nil end

---------------------------------------------------------------------------
-- Tram des profondeurs : son bandeau s'affiche dans l'instance du tram (n° 369), sans horaire
---------------------------------------------------------------------------
local TRAM_MAP = 369
-- reconnu par le n° d'instance, sinon par le nom de la zone (WoW Forever peut donner un autre n°)
local TRAM_NAMES = { ["tram des profondeurs"] = true, ["deeprun tram"] = true }
local function plain(v)
    if v == nil or (_G.issecretvalue and _G.issecretvalue(v)) then return nil end
    return v
end
function M.TramInfo(_)
    local name, _, _, _, _, _, _, id = nil, nil, nil, nil, nil, nil, nil, nil
    if GetInstanceInfo then name, _, _, _, _, _, _, id = GetInstanceInfo() end
    local zone = plain(_G.GetRealZoneText and _G.GetRealZoneText()) or ""
    local sub = plain(_G.GetSubZoneText and _G.GetSubZoneText()) or ""
    return plain(id), plain(name) or "", zone, sub
end
function M:InTram()
    local id, name, zone, sub = self:TramInfo()
    if id == TRAM_MAP then return true end
    return TRAM_NAMES[string.lower(name)] or TRAM_NAMES[string.lower(zone)] or TRAM_NAMES[string.lower(sub)] or false
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

-- /wk bateau : lignes déjà prises et ligne reconnue à bord
function M:Diag()
    local out = {}
    local taken = {}
    for _, l in ipairs(self:All()) do if self:Rode(l) then taken[#taken + 1] = self:LineName(l) end end
    table.insert(out, #taken > 0 and ("lignes déjà prises : " .. table.concat(taken, " · ")) or "aucune ligne prise pour l'instant")
    if onboard then
        local f = onboard.fit
        local nc = 0
        for _ in pairs(onboard.cand) do nc = nc + 1 end
        table.insert(out, f and string.format("à bord : %s, étape %d (vers %s ; %d positions, %.0f m/s)", self:LineName(f.l), f.i,
            self:StopName(f.l, f.i % #f.l.stops + 1), f.n, f.v) or string.format("à bord : ligne pas encore reconnue (%d tracés proches)", nc))
    end
    return out
end

-- Ménage, une fois : les horaires notés par les versions d'avant (départs, tours, tram) sont effacés
WK:On("PLAYER_LOGIN", function()
    local g = WK.DB.global
    g.nav = g.nav or {}
    g.nav.lines, g.nav.sched, g.nav.tram = nil, nil, nil
end)
