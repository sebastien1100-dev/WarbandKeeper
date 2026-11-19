local ADDON_NAME, WK = ...
local M = WK:NewModule("ClientDash")

-- Résumé pour le client PC (tableau de bord hors jeu et notifications Windows) : recalculé à la
-- déconnexion et au /reload, juste avant que le jeu n'écrive la sauvegarde. Le client lit seulement ce
-- résumé, sans refaire les calculs de l'addon. Hors profils ; toutes les dates en secondes (time()).
--   WK.DB.global.clientDash = {
--     at, char,                               -- quand et sur quel perso
--     gold = { or du compte, 91 jours, du plus ancien à aujourd'hui },
--     session = { char, start, dur, gold, ah },
--     auctions = { { char, name, qty, exp } },  -- enchères vues au dernier passage à l'HV
--     cds = { { char, name, readyAt } },        -- recharges de métier
--     lists = { { name, need, missing, items, short, cost } }, -- listes d'achat : unités voulues / manquantes,
--                                               -- objets différents, objets qui manquent encore, coût estimé (HV)
--     queue = { n, missing },                   -- file de fabrication
--     stash = { { from, to, n } },              -- envois du Rangement en attente
--     mail = { { char, count, money, exp } },   -- courrier non pris
--     rest = { { char, full, at } },            -- repos : plein, ou heure où il le sera
--   }
local DAY = 86400
local login = { at = 0, money = 0 }

WK:On("PLAYER_LOGIN", function()
    login.at = time()
    login.money = GetMoney and GetMoney() or 0
end)

local function name(key)
    local c = WK.DB.global.characters[key]
    return c and WK:CharName(c, key) or (tostring(key):match("^(.-)%-") or tostring(key))
end

function M:Build()
    local g = WK.DB.global
    local now = time()
    local d = { at = now, char = name(WK:CharKey()) }
    -- or du compte, un point par jour
    local S = WK.modules.Statistics
    d.gold = {}
    for i = 90, 0, -1 do
        local ok, v = pcall(S.AccountGoldAt, S, now - i * DAY)
        table.insert(d.gold, ok and math.floor(v or 0) or 0)
    end
    -- séance qui se termine
    local ah = 0
    for _, e in ipairs(g.auction and g.auction.log or {}) do
        if e.kind == "sale" and (e.t or 0) >= login.at then ah = ah + (e.net or 0) end
    end
    d.session = { char = d.char, start = login.at, dur = math.max(0, now - login.at),
        gold = (GetMoney and GetMoney() or 0) - login.money, ah = ah }
    -- enchères (dernier relevé de chaque perso)
    d.auctions = {}
    for key, c in pairs(g.characters) do
        local seen = c.auctionsSeen
        for _, a in ipairs(seen and seen.list or {}) do
            if (a.exp or 0) > now then
                table.insert(d.auctions, { char = name(key), name = (a.id and WK.GetItemInfo(a.id)) or a.name or "?", qty = a.qty or 1, exp = a.exp })
            end
        end
    end
    table.sort(d.auctions, function(a, b) return a.exp < b.exp end)
    -- recharges
    d.cds = {}
    local PH = WK.modules.ProfHelp
    local okC, cds = pcall(PH.AllCooldowns, PH)
    for _, cd in ipairs(okC and cds or {}) do
        table.insert(d.cds, { char = name(cd.ck), name = cd.name or cd.key, readyAt = cd.readyAt })
    end
    -- listes d'achat
    d.lists = {}
    local A = WK.modules.AHScan
    local okL, _, lists = pcall(A.Lists, A)
    for lname, l in pairs(okL and lists or {}) do
        local need, missing, items, short, cost = 0, 0, 0, 0, 0
        for _, it in ipairs(l.items or {}) do
            items = items + 1
            need = need + (it[2] or 0)
            local okH, have = pcall(A.Have, A, it[1])
            local miss = math.max(0, (it[2] or 0) - (okH and have or 0))
            missing = missing + miss
            if miss > 0 then
                short = short + 1
                local okP, price = pcall(A.Price, A, it[1])
                if okP and type(price) == "number" then cost = cost + price * miss end
            end
        end
        table.insert(d.lists, { name = lname, need = need, missing = missing, items = items, short = short, cost = math.floor(cost) })
    end
    local okQ, q = pcall(PH.Queue, PH)
    if okQ then
        local miss = 0
        for _, e in ipairs(q) do for _ in pairs(e.missing or {}) do miss = miss + 1 end end
        d.queue = { n = #q, missing = miss }
    end
    -- Rangement : lots en attente d'envoi, d'un perso à l'autre
    d.stash = {}
    local St = WK.modules.Stash
    local okR, r = pcall(St.Route, St)
    if okR and r then
        local pairsN = {}
        for to, dest in pairs(r.dest or {}) do
            for _, e in ipairs(dest.list or {}) do
                for from, n in pairs(e.from or {}) do
                    if from ~= to and (n or 0) > 0 then
                        local k = from .. "\t" .. to
                        pairsN[k] = (pairsN[k] or 0) + 1
                    end
                end
            end
        end
        for k, n in pairs(pairsN) do
            local from, to = k:match("^(.-)\t(.*)$")
            table.insert(d.stash, { from = name(from), to = name(to), n = n })
        end
        table.sort(d.stash, function(a, b) return a.n > b.n end)
    end
    -- courrier et repos
    d.mail, d.rest = {}, {}
    local X = WK.modules.XP
    for key, c in pairs(g.characters) do
        local box = c.mailbox
        if box and (box.count or 0) > 0 then
            table.insert(d.mail, { char = name(key), count = box.count, money = box.money or 0, exp = box.expiresAt or 0 })
        end
        if X and X.RestOf then
            local okX, frac, x = pcall(X.RestOf, X, key)
            if okX and frac then
                local full = frac >= (X.REST_MAX or 1.5) - 0.001
                table.insert(d.rest, { char = name(key), full = full,
                    at = full and now or math.floor(now + X:RestFullIn(frac, x and x.resting)) })
            end
        end
    end
    g.clientDash = d
    return d
end

WK:On("PLAYER_LOGOUT", function() pcall(M.Build, M) end)
