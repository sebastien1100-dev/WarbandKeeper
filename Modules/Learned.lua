local _, WK = ...
local M = WK:NewModule("Learned")

-- Découvertes intégrées : ce que l'addon a appris en jeu chez ses joueurs (Modules/LearnedDB.lua, généré par
-- tools/gen_learned.py ou la page Découvertes du client PC) est ajouté à la sauvegarde au démarrage, seulement
-- là où rien n'est noté : une installation neuve n'a plus à tout réapprendre, et ce que tu as noté toi-même
-- n'est jamais remplacé. Appelé par Core/Init.lua juste après DB:Init (avant les OnInit des modules).
-- Une base déjà appliquée (WK.DB.global.learnedV = WK.LearnedDB.v) ne l'est plus : ce que tu effaces
-- (chemins, récoltes) ne revient pas à chaque connexion ; et chaque entrée appliquée est notée
-- (WK.DB.global.learnedDone[genre][clé]) : effacée ou purgée, elle ne revient pas non plus avec la base suivante.

local function sub(t, k)
    t[k] = t[k] or {}
    return t[k]
end

-- Points de récolte : un point déjà noté (même genre, même objet, à moins de 0,5 % de la carte) n'est pas
-- ajouté deux fois.
local function nearSpot(list, e)
    for _, s in ipairs(list) do
        if s.k == e.k and s.i == e.i and math.abs(s.x - e.x) < 0.005 and math.abs(s.y - e.y) < 0.005 then
            return true
        end
    end
    return false
end

-- Chemins : un chemin déjà connu (même premier point, même longueur) n'est pas ajouté deux fois.
local function sameTrail(list, pts)
    for _, t in ipairs(list) do
        if #t == #pts and t[1] == pts[1] and t[2] == pts[2] then return true end
    end
    return false
end

-- Ajoute ce qui manque ; rend le nombre d'ajouts par genre ({ genre = n }).
function M.Fill(_, g, db, force)
    db = db or WK.LearnedDB
    g = g or (WK.DB and WK.DB.global)
    if type(db) ~= "table" or type(g) ~= "table" then return {} end
    if not force and db.v and g.learnedV == db.v then return {} end
    local added = {}
    -- ce qui a déjà été appliqué une fois n'est plus jamais remis (avant : une purge ou un effacement revenait à la
    -- base suivante) ; « force » (bouton « tout réappliquer ») passe outre
    local doneAll = sub(g, "learnedDone")
    local function seen(genre, k)
        local d = sub(doneAll, genre)
        if d[k] and not force then return true end
        d[k] = true
    end
    local function put(genre, t, k, v)
        if seen(genre, k) then return end
        if t[k] == nil then
            t[k] = v
            added[genre] = (added[genre] or 0) + 1
        end
    end
    for id, e in pairs(db.quests or {}) do
        put("quests", sub(g, "questLearn"), id, { n = e.n, l = e.l, s = e.s, k = e.k, z = e.z, g = e.g, t = e.t })
    end
    for id, e in pairs(db.chains or {}) do
        put("chains", sub(g, "questChains"), id, { pre = e.pre, how = e.how, n = 2 })
    end
    local dg = sub(g, "dungeons")
    for k, v in pairs(db.bossIds or {}) do put("bossIds", sub(dg, "bossIds"), k, v) end
    for k, v in pairs(db.bossNames or {}) do put("bossNames", sub(dg, "bossNames"), k, v) end
    for k, v in pairs(db.instNames or {}) do put("instNames", sub(dg, "names"), k, v) end
    for k, v in pairs(db.inst or {}) do put("inst", sub(dg, "inst"), k, v) end
    local fl = sub(g, "flights")
    for k, v in pairs(db.flightTimes or {}) do put("flightTimes", sub(fl, "routes"), k, v) end
    for k, v in pairs(db.flightPaths or {}) do put("flightPaths", sub(fl, "paths"), k, { c = v.c, pts = v.pts }) end
    local nav = sub(g, "nav")
    local st = sub(nav, "tramSt")
    for tk, s in pairs(db.tram or {}) do
        local near = seen("tram", tk) or false
        for _, o in ipairs(st) do
            if o[1] == s[1] and math.abs(o[2] - s[2]) < 40 and math.abs(o[3] - s[3]) < 40 then near = true end
        end
        if not near then
            st[#st + 1] = { s[1], s[2], s[3] }
            added.tram = (added.tram or 0) + 1
        end
    end
    local trails = sub(nav, "trails")
    for tk, t in pairs(db.trails or {}) do
        local list = sub(trails, t.c)
        if not seen("trails", tk) and not sameTrail(list, t.pts) then
            list[#list + 1] = t.pts
            added.trails = (added.trails or 0) + 1
        end
    end
    local camp = sub(g, "camp")
    for k, v in pairs(db.camp or {}) do put("camp", sub(camp, "seen"), k, v) end
    for k, v in pairs(db.campIcons or {}) do put("campIcons", sub(camp, "icons"), k, v) end
    local prices = sub(sub(g, "classSpells"), "prices")
    for key, v in pairs(db.trainerPrices or {}) do
        local cls, rest = key:match("^([^|]+)|(.+)$")
        if cls then put("trainerPrices", sub(prices, cls), rest, { v[1], v[2] }) end
    end
    for id, v in pairs(db.vendorPrices or {}) do
        put("vendorPrices", sub(g, "vendorSeen"), id, { p = v.p, npc = v.npc, at = 0 })
    end
    local spots = sub(g, "gatherSpots")
    for gk, e in pairs(db.gather or {}) do
        local list = sub(spots, e.m)
        if not seen("gather", gk) and not nearSpot(list, e) then
            list[#list + 1] = { x = e.x, y = e.y, k = e.k, i = e.i, n = 1, t = 0 }
            added.gather = (added.gather or 0) + 1
        end
    end
    g.learnedV = db.v
    M.last = added
    return added
end
