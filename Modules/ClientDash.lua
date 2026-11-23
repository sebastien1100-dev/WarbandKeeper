local ADDON_NAME, WK = ...
local M = WK:NewModule("ClientDash")

-- Résumé pour le client PC (tableau de bord hors jeu et notifications Windows) : recalculé à la
-- déconnexion et au /reload, juste avant que le jeu n'écrive la sauvegarde. Le client lit seulement ce
-- résumé, sans refaire les calculs de l'addon. Hors profils ; toutes les dates en secondes (time()).
--   WK.DB.global.clientDash = {
--     at, char,                               -- quand et sur quel perso
--     gold = { or du compte, 91 jours, du plus ancien à aujourd'hui },
--     session = { char, start, dur, gold, ah },
--     day = { net, spent, earned, by = { { s = cause, v = somme } } }, -- or des dernières 24 h, tous persos

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

---------------------------------------------------------------------------
-- Journal de l'or : chaque mouvement avec sa cause (fenêtre ouverte à ce moment), pour dire d'où vient une
-- perte ou un gain. WK.DB.global.moneyLog = { { t, c = perso, d = écart, s = cause, x = détail?, n = nombre? } },
-- 35 jours, 1500 au plus. Détail noté quand on le sait (quête rendue, trajet de vol, sort appris, expéditeur,
-- objet acheté) ; n = mouvements regroupés (même cause, même perso, même sens, moins d'une minute).
-- Sans fenêtre ouverte, l'or vient des monstres : cause « Butin » (l'ancien « Autre », converti une fois).
---------------------------------------------------------------------------
local GetTime, hooksecurefunc = _G.GetTime, _G.hooksecurefunc
local open, lastMoney, repairAt, questAt, taxiAt = {}, nil, 0, 0, 0
local function flag(on, off, key)
    WK:On(on, function() open[key] = true end)
    WK:On(off, function() C_Timer.After(1, function() open[key] = nil end) end)
end
flag("MERCHANT_SHOW", "MERCHANT_CLOSED", "merchant")
flag("MAIL_SHOW", "MAIL_CLOSED", "mail")
flag("AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "ah")
flag("TRAINER_SHOW", "TRAINER_CLOSED", "trainer")
flag("LOOT_OPENED", "LOOT_CLOSED", "loot")
flag("TRADE_SHOW", "TRADE_CLOSED", "trade")
flag("TAXIMAP_OPENED", "TAXIMAP_CLOSED", "taxi")
-- détail du prochain mouvement (gardé 3 s) : { s = cause attendue, x = texte, at }
local detail
local function note(s, x) if x and x ~= "" then detail = { s = s, x = x, at = GetTime() } end end
WK:On("QUEST_TURNED_IN", function(qid)
    questAt = GetTime()
    local Q = WK.modules.Quests
    local q = Q and Q.Get and Q:Get(tonumber(qid))
    local name = (q and Q.Name and Q:Name(q))
    if not name and _G.C_QuestLog and _G.C_QuestLog.GetTitleForQuestID then
        local ok, t = pcall(_G.C_QuestLog.GetTitleForQuestID, qid); if ok then name = t end
    end
    note("Quêtes", name)
end)
if hooksecurefunc then
    if RepairAllItems then hooksecurefunc("RepairAllItems", function() repairAt = GetTime() end) end
    if _G.TakeTaxiNode then hooksecurefunc("_G.TakeTaxiNode", function(i)
        taxiAt = GetTime()
        local ok, n = pcall(_G.TaxiNodeName, i)
        if ok and type(n) == "string" then note("Vols", (n:match("^([^,]+)") or n)) end
    end) end
    if _G.BuyTrainerService then hooksecurefunc("_G.BuyTrainerService", function(i)
        local ok, n, sub = pcall(_G.GetTrainerServiceInfo, i)
        if ok and n then note("Maître (apprentissage)", (sub and sub ~= "") and (n .. " (" .. sub .. ")") or n) end
    end) end
    if _G.TakeInboxMoney then hooksecurefunc("_G.TakeInboxMoney", function(i)
        local ok, _, _, from = pcall(_G.GetInboxHeaderInfo, i)
        if ok and type(from) == "string" then note("Courrier", string.format(WK.T("de %s"), from)) end
    end) end
    if _G.BuyMerchantItem then hooksecurefunc("_G.BuyMerchantItem", function(i)
        local n = WK.MerchantItemInfo and WK.MerchantItemInfo(i)
        if n then note("Achats chez le marchand", n) end
    end) end
end
local function cause(d)
    local now = GetTime()
    if now - repairAt < 3 and d < 0 then return "Réparations" end
    if now - taxiAt < 3 or open.taxi then return "Vols" end
    if now - questAt < 3 then return "Quêtes" end
    if open.trainer then return "Maître (apprentissage)" end
    if open.ah then return "Hôtel des ventes" end
    if open.mail then return "Courrier" end
    if open.merchant then return d < 0 and "Achats chez le marchand" or "Ventes au marchand" end
    if open.trade then return "Échange" end
    -- sans fenêtre : or ramassé sur les monstres (« Butin »)
    return "Butin"
end
local function moneyLog()
    local g = WK.DB.global
    g.moneyLog = g.moneyLog or {}
    return g.moneyLog
end
WK:On("PLAYER_MONEY", function()
    local m = GetMoney and GetMoney() or 0
    if not lastMoney then lastMoney = m return end
    local d = m - lastMoney
    lastMoney = m
    if d == 0 then return end
    local log = moneyLog()
    local t, c, s = time(), WK:CharKey(), cause(d)
    local x = detail and detail.s == s and GetTime() - detail.at < 3 and detail.x or nil
    if x then detail = nil end
    local last = log[#log]
    -- même cause, même perso, même sens, même détail, moins d'une minute : une seule ligne (achats en série, butin)
    if last and last.c == c and last.s == s and t - last.t < 60 and (last.d < 0) == (d < 0) and last.x == x then
        last.d, last.t, last.n = last.d + d, t, (last.n or 1) + 1
    else
        table.insert(log, { t = t, c = c, d = d, s = s, x = x })
    end
    local cut = t - 35 * DAY
    while #log > 0 and (#log > 1500 or log[1].t < cut) do table.remove(log, 1) end
end)
M.MoneyCause = cause

WK:On("PLAYER_LOGIN", function()
    -- l'ancien « Autre » (aucune fenêtre ouverte) était de l'or ramassé : « Butin », une fois
    local g = WK.DB.global
    if not g.moneyAutreButin then
        for _, e in ipairs(g.moneyLog or {}) do if e.s == "Autre" then e.s = "Butin" end end
        g.moneyAutreButin = true
    end
    login.at = time()
    login.money = GetMoney and GetMoney() or 0
    lastMoney = login.money
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
    -- or des dernières 24 h (tous les persos), par cause
    local day = { net = 0, spent = 0, earned = 0, by = {} }
    local byS = {}
    for _, e in ipairs(g.moneyLog or {}) do
        if (e.t or 0) >= now - DAY then
            day.net = day.net + e.d
            if e.d < 0 then day.spent = day.spent - e.d else day.earned = day.earned + e.d end
            byS[e.s] = (byS[e.s] or 0) + e.d
        end
    end
    for k, v in pairs(byS) do table.insert(day.by, { s = k, v = v }) end
    table.sort(day.by, function(a, b) return math.abs(a.v) > math.abs(b.v) end)
    while #day.by > 4 do table.remove(day.by) end
    d.day = day
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
