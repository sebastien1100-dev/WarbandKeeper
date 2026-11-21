local ADDON_NAME, WK = ...
local M = WK:NewModule("AHScan")
local T = function(s) return WK.T(s) end

-- Hôtel des ventes : scan de l'HV, prix des objets et listes d'achat.
--   Scan complet en une requête quand le jeu le permet (environ toutes les 15 min), sinon page par page.
--   Deux API possibles selon le client : C_AuctionHouse.ReplicateItems (récente) ou QueryAuctionItems
--   (ancienne, celle des clients classiques). /wk hv dit laquelle ce client donne.
--   Par objet : prix unitaire le plus bas en achat immédiat, quantité en vente, date, et le plus bas de
--   chaque jour sur 14 jours.
-- Données : WK.DB.global.ah.realms["Royaume-Faction"].items[itemID] = { p, q, t, c = "jour,prix,qté;…" }
-- (historique compact : une seule chaîne par objet, du plus ancien au plus récent ; les anciennes tables
-- h = { [jour] = prix } et hq = { [jour] = qté } sont converties au premier accès)
-- Réglages : WK.DB.global.ah (tooltip, stack, auto, panel).

local DEFAULTS = { tooltip = true, stack = true, auto = false, panel = true, bagValue = true, mailValue = true, keepDays = 30 }
local HISTORY_DAYS = 14
local FULL_COOLDOWN = 15 * 60
local CHUNK = 400 -- enchères lues par image pendant le scan complet

function M:Config()
    local g = WK.DB.global
    g.ah = g.ah or {}
    for k, v in pairs(DEFAULTS) do if g.ah[k] == nil then g.ah[k] = v end end
    g.ah.realms = g.ah.realms or {}
    return g.ah
end

local function realmKey()
    return (GetRealmName and GetRealmName() or "?") .. "-" .. (UnitFactionGroup and UnitFactionGroup("player") or "?")
end
---------------------------------------------------------------------------
-- Historique compact : lecture { { jour, prix, qté } } (triée), écriture, ajout d'un relevé
---------------------------------------------------------------------------
local function hread(e)
    local out = {}
    if not e then return out end
    if e.c then
        for d, p, q in e.c:gmatch("(%d+),(%d+),(%d*);") do
            out[#out + 1] = { tonumber(d), tonumber(p), tonumber(q) }
        end
    elseif e.h then
        for d, p in pairs(e.h) do out[#out + 1] = { d, p, e.hq and e.hq[d] } end
        table.sort(out, function(a, b) return a[1] < b[1] end)
    end
    return out
end
local function hwrite(e, list)
    local parts = {}
    for i, x in ipairs(list) do
        parts[i] = string.format("%d,%d,%s;", x[1], x[2], x[3] and tostring(math.floor(x[3])) or "")
    end
    e.c = #parts > 0 and table.concat(parts) or nil
    e.h, e.hq = nil, nil
end
-- relevé du jour : plus bas prix et plus grande quantité vus ; les jours plus vieux que keep jours partent
local function hput(e, day, low, qty, keep)
    local list = hread(e)
    local found
    for _, x in ipairs(list) do
        if x[1] == day then
            found = x
            if low < x[2] then x[2] = low end
            if qty then x[3] = math.max(x[3] or 0, qty) end
        end
    end
    if not found then list[#list + 1] = { day, low, qty } end
    if keep then
        local kept = {}
        for _, x in ipairs(list) do if x[1] > day - keep then kept[#kept + 1] = x end end
        list = kept
    end
    hwrite(e, list)
end
M.HistRead = hread
-- vrai si l'objet a un relevé ce jour-là
function M:HasDay(e, day)
    if not e then return false end
    if e.c then return e.c:find("^" .. day .. ",") ~= nil or e.c:find(";" .. day .. ",") ~= nil end
    return e.h ~= nil and e.h[day] ~= nil
end

function M:Data()
    local r = self:Config().realms
    local k = realmKey()
    r[k] = r[k] or { items = {} }
    local d = r[k]
    -- une fois : les anciennes tables d'historique passent au format compact (bien plus léger)
    if not d.compact then
        for _, e in pairs(d.items) do if type(e) == "table" and e.h then hwrite(e, hread(e)) end end
        d.compact = 1
    end
    return d
end

---------------------------------------------------------------------------
-- Prix
---------------------------------------------------------------------------
function M:Entry(itemID) return itemID and self:Data().items[itemID] end
function M:Price(itemID)
    local e = self:Entry(itemID)
    return e and e.p or nil
end
-- Jours depuis le dernier relevé
function M:Age(itemID)
    local e = self:Entry(itemID)
    if not e or not e.t then return nil end
    return math.floor((time() - e.t) / 86400)
end
-- Moyenne des plus bas de chaque jour et nombre de jours relevés ; days = seulement les derniers jours
-- (« moyenne 7 j »), sinon tout l'historique gardé (keepDays)
function M:Average(itemID, days)
    local e = self:Entry(itemID)
    if not e or not (e.c or e.h) then return nil, 0 end
    local sum, n = 0, 0
    local from = days and (math.floor(time() / 86400) - days) or nil
    for _, x in ipairs(hread(e)) do
        if not from or x[1] > from then sum, n = sum + x[2], n + 1 end
    end
    if n == 0 then return nil, 0 end
    return math.floor(sum / n + 0.5), n
end
-- Plus bas vu ailleurs que dans un scan (recherche d'un objet à l'HV) : compte pour la courbe du jour
function M:SeenToday(itemID, low, qty)
    if not (itemID and low and low > 0) then return end
    local d = self:Data()
    local e = d.items[itemID] or {}
    d.items[itemID] = e
    local day = math.floor(time() / 86400)
    hput(e, day, low, qty, self:Config().keepDays or HISTORY_DAYS) -- élagué comme l'historique du scan
    -- (jamais le cours e.p : il ne vient que d'un scan, sans appâts ; une recherche ne compte que pour la courbe)
end
-- Courbe : { { day, price, qty } } des 14 derniers jours, du plus ancien au plus récent
function M:History(itemID)
    return hread(self:Entry(itemID))
end
-- Objets qui ont le plus bougé sur 7 jours : { { id, change (fraction), now, before } }, du plus fort au plus faible
function M:Movers(limit)
    local today = math.floor(time() / 86400)
    local out = {}
    for id, e in pairs(self:Data().items) do
        if (e.c or e.h) and (e.p or 0) >= 100 then
            local recent, rd, older, sum, n = nil, -1, nil, 0, 0
            for _, x in ipairs(hread(e)) do
                local day, p = x[1], x[2]
                if day > rd then recent, rd = p, day end
                if day < today - 1 and day >= today - 7 then sum, n = sum + p, n + 1 end
            end
            older = n >= 2 and sum / n or nil
            if recent and older and rd >= today - 1 and older > 0 then
                table.insert(out, { id, (recent - older) / older, recent, older })
            end
        end
    end
    table.sort(out, function(a, b) return math.abs(a[2]) > math.abs(b[2]) end)
    local res = {}
    for i = 1, math.min(limit or 6, #out) do res[i] = out[i] end
    return res
end
function M:Count()
    local n = 0
    for _ in pairs(self:Data().items) do n = n + 1 end
    return n
end
function M:HasData() return next(self:Data().items) ~= nil end

---------------------------------------------------------------------------
-- API du jeu
---------------------------------------------------------------------------
local function modern() return C_AuctionHouse and C_AuctionHouse.ReplicateItems and C_AuctionHouse.GetNumReplicateItems end
local function legacy() return QueryAuctionItems and GetNumAuctionItems and GetAuctionItemInfo end
function M:Available() return modern() ~= nil or legacy() ~= nil end
-- canQuery, canFull
function M:CanQuery()
    -- système récent : un scan complet toutes les 15 minutes environ (le serveur ignore les autres)
    if modern() then return true, M:FullCooldown() == 0 end
    if CanSendAuctionQuery then
        local ok, q, all = pcall(CanSendAuctionQuery)
        if ok then return q and true or false, all and true or false end
    end
    return legacy() ~= nil, false
end
-- Lecture d'une enchère : itemID, quantité, prix d'achat immédiat (total)
local function readModern(i)
    local _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = C_AuctionHouse.GetReplicateItemInfo(i)
    return itemID, count, buyout
end
local function readLegacy(i)
    local _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = GetAuctionItemInfo("list", i)
    if not itemID and GetAuctionItemLink then itemID = WK:ParseItemID(GetAuctionItemLink("list", i)) end
    return itemID, count, buyout
end

---------------------------------------------------------------------------
-- Scan
---------------------------------------------------------------------------
-- M.scan = { kind = "full" | "pages", page, pages, done, total, seen = {[id] = {p, q}}, started }
local driver = CreateFrame("Frame")
local function notify() if M.OnProgress then M:OnProgress() end end

-- seen[id] = { plus bas, quantité totale, quantité au plus bas, 2e prix distinct, paliers }
-- paliers = les DEPTH prix distincts les plus bas avec leur quantité : { { prix, qté }, … } du moins cher
local DEPTH = 12
local function record(seen, itemID, count, buyout)
    if not itemID or not buyout or buyout <= 0 or not count or count <= 0 then return end
    local unit = math.floor(buyout / count)
    local s = seen[itemID]
    if not s then
        seen[itemID] = { unit, count, count, nil, { { unit, count } } }
        return
    end
    if unit < s[1] then
        s[4] = s[1]; s[1] = unit; s[3] = count
    elseif unit == s[1] then
        s[3] = (s[3] or 0) + count
    elseif not s[4] or unit < s[4] then
        s[4] = unit
    end
    s[2] = s[2] + count
    local tiers = s[5]
    if tiers then
        local placed = false
        for k, t in ipairs(tiers) do
            if t[1] == unit then t[2] = t[2] + count; placed = true break end
            if unit < t[1] then table.insert(tiers, k, { unit, count }); placed = true break end
        end
        if not placed and #tiers < DEPTH then tiers[#tiers + 1] = { unit, count } end
        if #tiers > DEPTH then tiers[#tiers] = nil end
    end
end
-- Prix sans appâts, sur des paliers { { prix, qté }, … } triés : prix « de fond » = celui où la quantité cumulée
-- dépasse 10 % de ce qui est en vente (au moins 1) ; tout lot à moins de la moitié de ce prix est un appât (1 pc,
-- erreur de frappe), écarté. Avant, un seul appât était reconnu : deux petits lots à deux prix différents
-- passaient (1 à 2 pa, 1 à 3 pa, 200 à 50 po donnait un cours de 2 pa).
local function robustTiers(tiers, total)
    if not tiers or not tiers[1] then return nil end
    total = total or 0
    if total <= 0 then for _, t in ipairs(tiers) do total = total + t[2] end end
    local limit = math.max(1, total * 0.1)
    local cum, ref = 0, nil
    for _, t in ipairs(tiers) do
        cum = cum + t[2]
        if cum > limit then ref = t[1] break end
    end
    ref = ref or tiers[#tiers][1]
    for _, t in ipairs(tiers) do
        if t[1] >= ref * 0.5 then return t[1] end
    end
    return ref
end
M.RobustTiers = robustTiers
-- Prix retenu pour les garde-fous et les conseils (voir robustTiers) ; le plus bas brut reste dans e.pmin (alertes
-- de prix). Ancien relevé sans paliers : un seul lot isolé à moins de la moitié du prix suivant est sauté.
local function robust(s)
    if s[5] then return robustTiers(s[5], s[2]) or s[1] end
    local p1, total, c1, p2 = s[1], s[2] or 0, s[3] or 0, s[4]
    if p2 and p1 < p2 * 0.5 and c1 <= math.max(1, total * 0.1) then return p2 end
    return p1
end
M.RobustPrice = robust

-- Fin du scan : on remplace les prix des objets vus ; un scan complet remet à zéro la quantité des autres
local function finish(ok, why)
    local sc = M.scan
    M.scan = nil
    driver:SetScript("OnUpdate", nil)
    driver:UnregisterAllEvents()
    if not sc then return end
    if ok then
        local d = M:Data()
        local now = time()
        local day = math.floor(now / 86400)
        -- historique gardé : réglage keepDays (14, 30 ou 90 jours)
        local keep = M:Config().keepDays or HISTORY_DAYS
        local n = 0
        for id, s in pairs(sc.seen) do
            n = n + 1
            local e = d.items[id] or {}
            local rp = robust(s)
            e.p, e.pmin, e.q, e.t = rp, (s[1] < rp) and s[1] or nil, s[2], now
            -- prix du jour (sans appât) et quantité en vente (la plus grande vue), pour la courbe des prix
            hput(e, day, rp, s[2] or 0, keep)
            d.items[id] = e
        end
        if sc.full then
            for id, e in pairs(d.items) do if not sc.seen[id] then e.q = 0 end end
        end
        d.last = now
        if sc.full then d.lastFull = now end
        d.lastCount = n
        -- derniers scans (page Scan et réglages de la fenêtre d'HV) : date, complet ou non, objets, durée
        d.scans = d.scans or {}
        table.insert(d.scans, 1, { at = now, full = sc.full and true or false, n = n, dur = sc.started and math.floor(GetTime() - sc.started + 0.5) or nil })
        while #d.scans > 6 do table.remove(d.scans) end
        WK:Print(string.format(T("Scan de l'HV terminé : %d objets, %d enchères."), n, sc.done or 0))
        if WK.modules.AHSell then pcall(WK.modules.AHSell.CheckAlerts, WK.modules.AHSell) end -- alertes de prix
        WK:NotifyChanged()
    else
        WK:Print(why or T("Scan de l'HV interrompu."))
    end
    notify()
end
function M:Stop() if self.scan then finish(false) end end

-- Lecture par morceaux (pour ne pas figer le jeu)
local function readAll(total, reader)
    local sc = M.scan
    sc.total, sc.done = total, 0
    driver:SetScript("OnUpdate", function()
        local s = M.scan
        if not s then driver:SetScript("OnUpdate", nil) return end
        local last = math.min(s.total, s.done + CHUNK)
        for i = s.done + 1, last do
            local ok, id, count, buyout = pcall(reader, i)
            if ok then record(s.seen, id, count, buyout) end
        end
        s.done = last
        notify()
        if s.done >= s.total then finish(true) end
    end)
end

local function startModern()
    M.scan = { full = true, seen = {}, started = GetTime(), phase = "wait" }
    -- sans réponse du serveur (scan refusé, trop tôt après le précédent) : on n'attend pas indéfiniment
    driver:SetScript("OnUpdate", function()
        local s = M.scan
        if s and s.phase == "wait" and GetTime() - s.started > 90 then
            finish(false, T("Le serveur n'a pas envoyé l'HV : un scan complet n'est accepté qu'environ toutes les 15 minutes. Réessaie plus tard."))
        end
    end)
    driver:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE")
    driver:SetScript("OnEvent", function()
        driver:UnregisterEvent("REPLICATE_ITEM_LIST_UPDATE")
        if M.scan then M.scan.phase = "read"; readAll(C_AuctionHouse.GetNumReplicateItems() or 0, readModern) end
    end)
    C_AuctionHouse.ReplicateItems()
end

local function startFull()
    M.scan = { full = true, seen = {}, started = GetTime(), phase = "wait" }
    driver:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
    driver:SetScript("OnEvent", function()
        driver:UnregisterEvent("AUCTION_ITEM_LIST_UPDATE")
        if not M.scan then return end
        local _, total = GetNumAuctionItems("list")
        M.scan.phase = "read"
        readAll(total or 0, readLegacy)
    end)
    QueryAuctionItems("", nil, nil, 0, false, 0, true, false, nil)
end

-- Page par page (50 enchères), à chaque fois que le jeu accepte une nouvelle requête
local function startPages()
    M.scan = { full = true, pages = true, seen = {}, started = GetTime(), page = 0, done = 0, total = 0, phase = "wait" }
    local waiting = false
    local function ask()
        local s = M.scan
        if not s then return end
        waiting = true
        QueryAuctionItems("", nil, nil, s.page, false, 0, false, false, nil)
    end
    driver:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
    driver:SetScript("OnEvent", function()
        local s = M.scan
        if not s or not waiting then return end
        waiting = false
        local n, total = GetNumAuctionItems("list")
        s.total = total or 0
        for i = 1, n or 0 do
            local ok, id, count, buyout = pcall(readLegacy, i)
            if ok then record(s.seen, id, count, buyout) end
        end
        s.done = s.done + (n or 0)
        s.page = s.page + 1
        s.phase = "read"
        notify()
        if (n or 0) == 0 or s.done >= s.total then finish(true) end
    end)
    driver:SetScript("OnUpdate", function()
        if not M.scan or waiting then return end
        local q = M:CanQuery()
        if q then ask() end
    end)
end

-- Lance un scan : complet si possible, sinon page par page (full = false force page par page)
function M:Start(mode)
    if self.scan then return end
    if not self.open then WK:Print(T("Ouvre l'hôtel des ventes pour lancer un scan.")) return end
    if modern() then
        local cd = self:FullCooldown()
        if cd > 0 and mode ~= "force" then
            WK:Print(string.format(T("Scan complet possible dans environ %d min (le serveur n'en accepte qu'un toutes les 15 minutes). /wk hv scan force pour essayer quand même."), math.ceil(cd / 60)))
            return
        end
        startModern() notify() return
    end
    if not legacy() then WK:Print(T("Ce client ne donne pas accès à l'hôtel des ventes.")) return end
    local q, all = self:CanQuery()
    if mode ~= "pages" and all then startFull()
    elseif mode == "full" and not all then
        WK:Print(T("Scan complet pas encore possible : le jeu ne l'autorise qu'environ toutes les 15 minutes."))
        return
    else startPages() end
    notify()
end
-- Prochain scan complet possible (secondes), d'après le dernier fait par l'addon
function M:FullCooldown()
    local last = self:Data().lastFull
    if not last then return 0 end
    return math.max(0, FULL_COOLDOWN - (time() - last))
end

WK:On("AUCTION_HOUSE_SHOW", function()
    M.open = true
    notify()
    if M:Config().auto and WK:FeatureOn("ah") then
        C_Timer.After(1.5, function()
            local _, all = M:CanQuery()
            if M.open and not M.scan and all then M:Start("full") end
        end)
    end
end)
WK:On("AUCTION_HOUSE_CLOSED", function()
    M.open = false
    if M.scan then finish(false) end
    notify()
end)

---------------------------------------------------------------------------
-- Infobulle d'un objet (appelée par Modules/Inventory.lua)
---------------------------------------------------------------------------
function M:AddTooltip(tooltip, itemID, header)
    if not self:Config().tooltip or not WK:FeatureOn("ah") then return false end
    local e = self:Entry(itemID)
    if not e or not e.p then return false end
    header()
    local age = self:Age(itemID) or 0
    local when = age == 0 and T("aujourd'hui") or string.format(T("il y a %d j"), age)
    tooltip:AddDoubleLine(T("Prix HV (unité)"), WK:FormatMoney(e.p), 0.8, 0.8, 0.8, 1, 1, 1)
    local avg, n = self:Average(itemID)
    if avg and n > 1 then tooltip:AddDoubleLine(string.format(T("Moyenne sur %d j"), n), WK:FormatMoney(avg), 0.6, 0.6, 0.6, 0.8, 0.8, 0.8) end
    if self:Config().stack then
        local _, _, _, _, _, _, _, stack = WK.GetItemInfo(itemID)
        if stack and stack > 1 then
            tooltip:AddDoubleLine(string.format(T("Pile de %d"), stack), WK:FormatMoney(e.p * stack), 0.6, 0.6, 0.6, 0.8, 0.8, 0.8)
        end
    end
    tooltip:AddDoubleLine(T("En vente"), (e.q and e.q > 0) and (e.q .. "  ·  " .. when) or (T("aucun") .. "  ·  " .. when), 0.6, 0.6, 0.6, 0.6, 0.6, 0.6)
    return true
end

---------------------------------------------------------------------------
-- Diagnostic (/wk hv)
---------------------------------------------------------------------------
function M:Report()
    WK:Print(T("Hôtel des ventes : diagnostic"))
    WK:Print("  C_AuctionHouse.ReplicateItems : " .. tostring(modern() ~= nil))
    WK:Print("  " .. T("achat depuis la liste") .. " : " .. tostring(M:CanBuy()))
    WK:Print("  QueryAuctionItems : " .. tostring(QueryAuctionItems ~= nil) .. " · GetAuctionItemInfo : " .. tostring(GetAuctionItemInfo ~= nil))
    local q, all = self:CanQuery()
    WK:Print("  CanSendAuctionQuery : " .. tostring(CanSendAuctionQuery ~= nil) .. " (" .. tostring(q) .. ", " .. T("complet") .. " " .. tostring(all) .. ")")
    WK:Print("  " .. T("HV ouvert") .. " : " .. tostring(self.open and true or false) .. " · AuctionFrame : " .. tostring(AuctionFrame ~= nil) .. " · AuctionHouseFrame : " .. tostring(AuctionHouseFrame ~= nil))
    local d = self:Data()
    WK:Print("  " .. string.format(T("%d objets avec un prix"), self:Count()) .. (d.last and (" · " .. T("dernier scan") .. " " .. date("%d/%m %H:%M", d.last)) or ""))
end

---------------------------------------------------------------------------
-- Listes d'achat (remplacent les listes de courses d'Auctionator)
-- WK.DB.global.ah.lists[nom] = { items = { { id, qty } }, at = date } ; liste choisie : ah.curList
---------------------------------------------------------------------------
function M:Lists()
    local cfg = self:Config()
    cfg.lists = cfg.lists or {}
    -- anciennes listes (v1) : la quantité était « ce qui manque » ; on la convertit en quantité à avoir
    for _, l in pairs(cfg.lists) do
        if not l.v then
            for _, it in ipairs(l.items or {}) do it[2] = (it[2] or 0) + self:Have(it[1]) end
            l.v = 2
        end
    end
    local names = {}
    for name in pairs(cfg.lists) do table.insert(names, name) end
    table.sort(names, function(a, b) return (cfg.lists[a].at or 0) > (cfg.lists[b].at or 0) end)
    return names, cfg.lists
end
function M:GetList(name)
    local _, lists = self:Lists()
    return name and lists[name]
end
-- entries : { { itemID, missing } } ; renvoie le nombre d'objets gardés.
-- La liste retient la quantité à AVOIR sur le compte (manquant + déjà possédé), pas ce qui manque :
-- l'achat, l'élagage et le panneau comparent tous à ce qu'il y a sur le compte (M:Have).
function M:SaveList(name, entries)
    local _, lists = self:Lists()
    local items = {}
    for _, e in ipairs(entries or {}) do
        if (e.missing or 0) > 0 and e.itemID then table.insert(items, { e.itemID, e.missing + self:Have(e.itemID) }) end
    end
    if #items == 0 then return 0 end
    lists[name] = { items = items, at = time(), v = 2 }
    self:Config().curList = name
    if self.OnProgress then self:OnProgress() end
    WK:NotifyChanged()
    return #items
end
function M:DeleteList(name)
    local _, lists = self:Lists()
    lists[name] = nil
    local cfg = self:Config()
    if cfg.curList == name then cfg.curList = (self:Lists())[1] end
    if self.OnProgress then self:OnProgress() end
end
-- Cherche un objet dans la fenêtre de l'HV du jeu (on achète ensuite avec ses boutons)
function M:SearchItem(itemID)
    if not self.open then WK:Print(T("Ouvre l'hôtel des ventes pour chercher cet objet.")) return false end
    local name = WK.GetItemInfo(itemID)
    if not name then
        if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, itemID) end
        WK:Print(T("Objet pas encore chargé par le jeu : réessaie dans un instant."))
        return false
    end
    -- notre fenêtre d'HV ouverte : la recherche se fait dans sa page Parcourir
    if WK.UI.AHWindowSearch and WK.UI:AHWindowSearch(itemID, name) then return true end
    local f = AuctionHouseFrame
    local bar = f and f.SearchBar
    if bar then
        if f.SetDisplayMode and AuctionHouseFrameDisplayMode and AuctionHouseFrameDisplayMode.Buy then
            pcall(f.SetDisplayMode, f, AuctionHouseFrameDisplayMode.Buy)
        end
        if bar.SetSearchText then pcall(bar.SetSearchText, bar, name)
        elseif bar.SearchBox then bar.SearchBox:SetText(name) end
        if bar.StartSearch then pcall(bar.StartSearch, bar) return true end
    end
    if BrowseName and AuctionFrameBrowse_Search then -- ancienne fenêtre de l'HV
        BrowseName:SetText(name)
        pcall(AuctionFrameBrowse_Search)
        return true
    end
    return false
end

---------------------------------------------------------------------------
-- Achat de la liste, au prix le plus bas (système d'HV récent : objets « marchandises »).
-- Le jeu exige un clic du joueur pour chaque achat : le bouton du panneau avance pas à pas.
--   1er clic : demande du prix pour l'objet suivant (tout ce qui manque) -> COMMODITY_PRICE_UPDATED
--   2e clic  : confirmation -> COMMODITY_PURCHASE_SUCCEEDED / _FAILED ; la quantité achetée est
--              retirée de la liste, et l'objet disparaît de la liste quand il ne manque plus rien.
-- Un objet qui n'est pas une marchandise (équipement, recette) : recherche dans la fenêtre de l'HV.
-- M.buy = { list, id, qty, phase = "quote" | "confirm" | "wait", unit, total, skip = { [id] = true } }
---------------------------------------------------------------------------
local AH = function() return C_AuctionHouse end
function M:CanBuy()
    local A = AH()
    return A and A.StartCommoditiesPurchase and A.ConfirmCommoditiesPurchase and true or false
end
-- Achats faits mais pas encore vus dans les sacs (le relevé du compte arrive un peu après) : { [id] = { base, qty, at } }
local pendingBuy = {}
local function have(id)
    local Inv = WK.modules.Inventory
    local n = (Inv and Inv.AccountCount and Inv:AccountCount(id)) or 0
    local p = pendingBuy[id]
    if p then
        if n >= p.base + p.qty or GetTime() - p.at > 30 then pendingBuy[id] = nil
        else n = math.max(n, p.base + p.qty) end
    end
    return n
end
M.Have = function(_, id) return have(id) end
-- Objet suivant à acheter dans la liste : id, quantité
function M:NextToBuy(name)
    local list = self:GetList(name)
    if not list then return nil end
    local skip = (self.buy and self.buy.skip) or {}
    for _, it in ipairs(list.items) do
        local miss = it[2] - have(it[1])
        if miss > 0 and not skip[it[1]] then return it[1], miss end
    end
    return nil
end
local function isCommodity(id)
    local A = AH()
    if A and A.GetItemCommodityStatus and Enum and Enum.ItemCommodityStatus then
        local ok, st = pcall(A.GetItemCommodityStatus, id)
        if ok and st == Enum.ItemCommodityStatus.Item then return false end
    end
    return true
end
-- Achat réussi : compté tout de suite comme possédé (la liste est élaguée juste après par PruneList)
local function consume(name, id, qty)
    if not (id and qty and qty > 0) then return end
    local Inv = WK.modules.Inventory
    local base = (Inv and Inv.AccountCount and Inv:AccountCount(id)) or 0
    local p = pendingBuy[id]
    pendingBuy[id] = { base = p and p.base or base, qty = (p and p.qty or 0) + qty, at = GetTime() }
end
function M:PruneList(name)
    local list = self:GetList(name)
    if not list then return 0 end
    local n = 0
    for i = #list.items, 1, -1 do
        if have(list.items[i][1]) >= list.items[i][2] then table.remove(list.items, i); n = n + 1 end
    end
    if self.OnProgress then self:OnProgress() end
    return n
end
function M:CancelBuy()
    local A = AH()
    if self.buy and self.buy.phase == "confirm" and A and A.CancelCommoditiesPurchase then pcall(A.CancelCommoditiesPurchase) end
    self.buy = nil
    if self.OnProgress then self:OnProgress() end
end
-- Un clic sur « Acheter » : avance d'un pas
function M:BuyStep()
    if not self.open then WK:Print(T("Ouvre l'hôtel des ventes pour acheter.")) return end
    if not self:CanBuy() then WK:Print(T("Ce client ne permet pas l'achat depuis l'addon : utilise « Chercher ».")) return end
    local name = self:Config().curList
    local A = AH()
    local b = self.buy
    if b and b.phase == "confirm" then
        if not self:DearCheck(b) then return end
        b.phase = "wait"
        local ok = pcall(A.ConfirmCommoditiesPurchase, b.id, b.qty)
        if not ok then b.phase = nil; WK:Print(T("Achat refusé par le jeu.")) end
        if self.OnProgress then self:OnProgress() end
        return
    end
    if b and (b.phase == "quote" or b.phase == "wait") then return end -- réponse du serveur attendue
    self:QuoteNext(name, true)
end

-- Demande le prix de l'objet suivant de la liste. Appelée par un clic, ou toute seule juste après
-- un achat réussi : il ne reste alors qu'un clic par objet (la confirmation, que le jeu réserve au joueur).
function M:QuoteNext(name, fromClick)
    local A = AH()
    local prev = self.buy
    local skip = prev and prev.skip or {}
    self.buy = { list = name, skip = skip, spent = prev and prev.spent or 0, count = prev and prev.count or 0 }
    local id, qty = self:NextToBuy(name)
    while id and not isCommodity(id) do
        -- équipement, recette : pas d'achat groupé ; au clic, on le montre dans la fenêtre de l'HV
        skip[id] = true
        if fromClick then
            self:SearchItem(id)
            WK:Print(string.format(T("%s n'est pas une marchandise : choisis l'enchère dans la fenêtre de l'HV."), WK.GetItemInfo(id) or ("#" .. id)))
            if self.OnProgress then self:OnProgress() end
            return
        end
        id, qty = self:NextToBuy(name)
    end
    if not id then
        local done = self.buy
        self.buy = nil
        if (done.count or 0) > 0 then
            WK:Print(string.format(T("Liste d'achat terminée : %d achat(s) pour %s."), done.count, WK:FormatMoney(done.spent or 0)))
        elseif fromClick then
            WK:Print(T("Liste d'achat : il ne manque plus rien."))
        end
        self:PruneList(name)
        if self.OnProgress then self:OnProgress() end
        return
    end
    self.buy.id, self.buy.qty, self.buy.phase = id, qty, "quote"
    local ok = pcall(A.StartCommoditiesPurchase, id, qty)
    if not ok then
        self.buy.phase = nil
        if fromClick then WK:Print(T("Le jeu a refusé la demande de prix.")) end
    end
    if self.OnProgress then self:OnProgress() end
end
WK:On("COMMODITY_PRICE_UPDATED", function(unit, total)
    local b = M.buy
    if not b or not (b.phase == "quote" or b.phase == "confirm" or b.phase == "wait") then return end
    -- prix changé après la demande (ou pendant la confirmation : le serveur attend alors une nouvelle
    -- confirmation) : nouveau prix affiché, et il faut recliquer pour l'accepter
    if b.phase ~= "quote" and b.total and total and total ~= b.total then
        WK:Print(string.format(T("Le prix a changé : %s pour %d %s. Reclique pour confirmer."), WK:FormatMoney(total), b.qty or 0, WK.GetItemInfo(b.id) or "?"))
    end
    b.unit, b.total, b.phase = unit, total, "confirm"
    -- prix à l'unité bien au-dessus du cours connu (plus de 3 fois le scan) : un clic de plus est demandé
    -- cours : le scan, sinon la moyenne des 30 derniers jours ; sans aucune référence, un achat d'au moins 100 po
    -- ou d'un dixième de ton or demande aussi un clic de plus (avant, aucun garde-fou sans prix de scan)
    local ref = M:Price(b.id) or (M.Average and M:Average(b.id, 30))
    b.noRef = nil
    b.dear = (ref and unit and ref > 0 and unit > ref * 3) and math.floor(unit / ref + 0.5) or nil
    if not ref and total then
        local money = _G.GetMoney and _G.GetMoney() or 0
        if total >= 1000000 or total >= money * 0.1 then b.dear, b.noRef = 0, true end
    end
    b.dearOk = nil
    if M.OnProgress then M:OnProgress() end
end)
-- Vrai si la confirmation peut partir. Prix très au-dessus du cours : le 1er clic prévient, le suivant achète
-- (avant, « Tout acheter » demandait seul le prix suivant et le clic d'après confirmait n'importe quel prix).
function M.DearCheck(_, b)
    if not (b and b.dear) or b.dearOk then return true end
    b.dearOk = true
    if b.noRef then
        WK:Print(string.format(T("Attention : aucun cours connu pour %s (%s)."), WK.GetItemInfo(b.id) or "?",
            WK:FormatMoney(b.total or 0)) .. " " .. T("Reclique pour acheter quand même."))
        return false
    end
    WK:Print(string.format(T("Attention : %s coûte %d fois son cours (%s)."), WK.GetItemInfo(b.id) or "?", b.dear,
        WK:FormatMoney(b.total or 0)) .. " " .. T("Reclique pour acheter quand même."))
    return false
end
WK:On("COMMODITY_PRICE_UNAVAILABLE", function()
    local b = M.buy
    if not b then return end
    WK:Print(string.format(T("Pas assez de %s en vente pour cette quantité : objet passé."), WK.GetItemInfo(b.id) or "?"))
    b.skip[b.id] = true
    b.phase = nil
    M:QuoteNext(b.list, false)
end)
WK:On("COMMODITY_PURCHASE_SUCCEEDED", function()
    local b = M.buy
    if not b then return end
    WK:Print(string.format(T("Acheté : %d %s pour %s."), b.qty, WK.GetItemInfo(b.id) or "?", WK:FormatMoney(b.total or 0)))
    -- achat isolé (Parcourir, Vendre) : pas de liste, donc ni décompte ni objet suivant
    if not b.list then
        M.buy = nil
        WK:NotifyChanged()
        if M.OnProgress then M:OnProgress() end
        return
    end
    consume(b.list, b.id, b.qty)
    M:PruneList(b.list)
    b.spent, b.count = (b.spent or 0) + (b.total or 0), (b.count or 0) + 1
    WK:NotifyChanged()
    -- prix de l'objet suivant demandé tout de suite : le prochain clic confirme directement
    M:QuoteNext(b.list, false)
end)
WK:On("COMMODITY_PURCHASE_FAILED", function()
    local b = M.buy
    if not b then return end
    WK:Print(T("Achat échoué (prix changé ou plus assez en vente) : reclique pour redemander le prix."))
    M.buy = { list = b.list, skip = b.skip, spent = b.spent, count = b.count }
    if M.OnProgress then M:OnProgress() end
end)
WK:On("AUCTION_HOUSE_CLOSED", function() M.buy = nil end)
