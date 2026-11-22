local ADDON_NAME, WK = ...
local M = WK:NewModule("Auction")

-- Ventes et achats à l'hôtel des ventes, lus sur les factures des courriers de l'HV
-- au moment où on en prend l'or (vente) ou l'objet (achat), à la main ou par « Tout prendre ».
-- WK.DB.global.auction.log = { { t, kind = "sale"|"buy"|"expired", char, item, count, gross, net }, ... }
-- (« expired » : enchère revenue par courrier, sujet AUCTION_EXPIRED_MAIL_SUBJECT, notée quand on prend l'objet)
local MAX_LOG = 1000

local function log() return WK.DB.global.auction.log end

-- Un courrier peut être lu plusieurs fois (prise répétée en attendant le serveur) : on ne le compte qu'une fois.
local seen = {}

local function record(index)
    if not GetInboxInvoiceInfo or not index then return end
    local invoiceType, itemName, _, bid, _, deposit, consignment, _, _, _, count = GetInboxInvoiceInfo(index)
    local _, _, sender, subject, money, _, daysLeft = GetInboxHeaderInfo(index)
    if invoiceType ~= "seller" and invoiceType ~= "buyer" then
        -- enchère expirée : « Enchère expirée : <objet> »
        local fmt = _G.AUCTION_EXPIRED_MAIL_SUBJECT
        if not (fmt and subject) then return end
        local pat = "^" .. fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%s", "(.+)") .. "$"
        local name = subject:match(pat)
        if not name then return end
        local key = "exp|" .. tostring(subject) .. "|" .. math.floor((time() + (daysLeft or 0) * 86400) / 3 + 0.5)
        if seen[key] then return end
        seen[key] = true
        local n = 1
        if GetInboxItem then local _, _, _, c = GetInboxItem(index, 1); n = c or 1 end
        local l = log()
        table.insert(l, 1, { t = time(), kind = "expired", char = select(2, WK.DB:Me()), item = name, count = n, gross = 0, net = 0 })
        while #l > MAX_LOG do table.remove(l) end
        WK:NotifyChanged()
        return
    end
    -- date d'expiration du courrier (fixe pour un même courrier, à la seconde près) : deux ventes identiques
    -- arrivées à quelques secondes d'écart restent deux ventes
    local expires = math.floor((time() + (daysLeft or 0) * 86400) / 3 + 0.5)
    local key = table.concat({ tostring(sender), tostring(subject), tostring(money), tostring(expires) }, "|")
    if seen[key] then return end
    seen[key] = true
    local entry = { t = time(), char = select(2, WK.DB:Me()), item = itemName, count = count or 1 }
    if invoiceType == "seller" then
        entry.kind = "sale"
        entry.gross = bid or 0
        -- Ce qui arrive vraiment : prix de vente + caution rendue - commission de l'HV.
        entry.net = money or ((bid or 0) + (deposit or 0) - (consignment or 0))
    else
        entry.kind = "buy"
        entry.gross = bid or 0
        entry.net = -(bid or 0)
        if GetInboxItemLink then entry.itemID = WK:ParseItemID(GetInboxItemLink(index, 1)) end
    end
    local l = log()
    table.insert(l, 1, entry)
    while #l > MAX_LOG do table.remove(l) end
    if WK.modules.Journal then WK.modules.Journal:Auction(entry) end
    WK:NotifyChanged()
end

M.Record = record -- (pour les tests)

function M:OnInit()
    WK.DB.global.auction = WK.DB.global.auction or { log = {} }
    WK.DB.global.auction.log = WK.DB.global.auction.log or {}
    -- en plus des 1000 lignes au plus (MAX_LOG) : rien de plus vieux que 180 jours (ordre gardé, récent d'abord)
    do
        local lg, lim, keep = WK.DB.global.auction.log, time() - 180 * 86400, {}
        for _, e in ipairs(lg) do if (e.t or 0) >= lim then keep[#keep + 1] = e end end
        if #keep ~= #lg then WK.DB.global.auction.log = keep end
    end
    -- La facture est lue juste après la demande de prise, avant que le serveur ne retire le courrier.
    if hooksecurefunc then
        if TakeInboxMoney then hooksecurefunc("TakeInboxMoney", function(i) record(i) end) end
        if TakeInboxItem then hooksecurefunc("TakeInboxItem", function(i) record(i) end) end
        if AutoLootMailItem then hooksecurefunc("AutoLootMailItem", function(i) record(i) end) end
    end
end
WK:On("MAIL_CLOSED", function() wipe(seen) end)

-- Bilan sur les N derniers jours : ventes nettes, achats, bilan, et objets les plus vendus.
function M:Summary(days)
    local since = time() - (days or 7) * 86400
    local sales, buys, nSales, nBuys = 0, 0, 0, 0
    local byItem = {}
    for _, e in ipairs(log()) do
        if e.t < since then break end
        if e.kind == "sale" then
            sales, nSales = sales + (e.net or 0), nSales + 1
            local b = byItem[e.item or "?"] or { item = e.item or "?", count = 0, net = 0 }
            b.count, b.net = b.count + (e.count or 1), b.net + (e.net or 0)
            byItem[e.item or "?"] = b
        elseif e.kind == "buy" then
            buys, nBuys = buys + (e.gross or 0), nBuys + 1
        end
    end
    local top = {}
    for _, b in pairs(byItem) do table.insert(top, b) end
    table.sort(top, function(a, b) return a.net > b.net end)
    return { sales = sales, buys = buys, balance = sales - buys, nSales = nSales, nBuys = nBuys, top = top }
end

-- Nom d'objet (les factures n'ont que le nom) -> n° d'objet : cache du jeu, sinon objets scannés à l'HV
local idByName = {}
local function idOf(name)
    if idByName[name] ~= nil then return idByName[name] or nil end
    local f = (_G.C_Item and _G.C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant
    local id
    if f then
        local ok, v = pcall(f, name)
        if ok and type(v) == "number" then id = v end
    end
    if not id then
        local S = WK.modules.AHScan
        for i in pairs(S and S:Data().items or {}) do
            if WK.GetItemInfo(i) == name then id = i break end
        end
    end
    idByName[name] = id or false
    return id
end
M.IdOf = function(_, name) return idOf(name) end

-- Ventes par objet sur les N derniers jours (nil : tout le journal) : vendus (unités), prix brut et net,
-- prix moyen par unité, enchères revenues (expirées), part vendue (ventes / (ventes + expirées)).
-- Rend rows (triées par montant), byName, totaux. Gardé en cache tant que le journal ne change pas.
local cache = {}
function M.ItemStats(_, days)
    local l = log()
    local key = (days or 0) .. ":" .. #l .. ":" .. tostring(l[1] and l[1].t)
    local c = cache[days or 0]
    if c and c.key == key then return c.rows, c.byName, c.tot end
    local since = days and (_G.time() - days * 86400) or 0
    local rows, byName = {}, {}
    local tot = { gross = 0, net = 0, sales = 0, expired = 0, sold = 0 }
    for _, e in ipairs(l) do
        if (e.t or 0) < since then break end
        if e.item and (e.kind == "sale" or e.kind == "expired") then
            local r = byName[e.item]
            if not r then
                r = { name = e.item, sold = 0, gross = 0, net = 0, sales = 0, expired = 0 }
                byName[e.item] = r
                rows[#rows + 1] = r
            end
            if e.kind == "sale" then
                r.sold, r.sales = r.sold + (e.count or 1), r.sales + 1
                r.gross, r.net = r.gross + (e.gross or 0), r.net + (e.net or 0)
                tot.sales, tot.sold = tot.sales + 1, tot.sold + (e.count or 1)
                tot.gross, tot.net = tot.gross + (e.gross or 0), tot.net + (e.net or 0)
            else
                r.expired, tot.expired = r.expired + 1, tot.expired + 1
            end
        end
    end
    for _, r in ipairs(rows) do
        r.avg = r.sold > 0 and math.floor(r.gross / r.sold + 0.5) or nil
        r.rate = (r.sales + r.expired) > 0 and (r.sales / (r.sales + r.expired)) or nil
        r.id = idOf(r.name)
    end
    table.sort(rows, function(a, b)
        if a.gross ~= b.gross then return a.gross > b.gross end
        return a.name < b.name
    end)
    cache[days or 0] = { key = key, rows = rows, byName = byName, tot = tot }
    return rows, byName, tot
end

-- Ventes d'un objet (tout le journal) : la ligne de ItemStats, ou nil s'il n'a jamais été vendu
function M.SoldInfo(_, itemID)
    local name = itemID and WK.GetItemInfo(itemID)
    if not name then return nil end
    local _, byName = M:ItemStats(nil)
    local r = byName[name]
    return (r and r.sales > 0) and r or nil
end

-- Infobulle : prix réellement obtenu à l'HV (si l'objet a déjà été vendu), sous le prix du scan
function M.AddSoldTooltip(_, tooltip, itemID, header)
    local S = WK.modules.AHScan
    if not (S and S:Config().tooltip and WK:FeatureOn("ah")) then return false end
    local r = M:SoldInfo(itemID)
    if not (r and r.avg) then return false end
    header()
    tooltip:AddDoubleLine(WK.T("Tu le vends"),
        WK:FormatMoney(r.avg) .. "  ·  " .. string.format(WK.T("%d vendu(s)"), r.sold),
        0.8, 0.8, 0.8, 1, 1, 1)
    if r.rate then
        tooltip:AddDoubleLine(WK.T("Part vendue"), math.floor(r.rate * 100 + 0.5) .. " %", 0.6, 0.6, 0.6, 0.8, 0.8, 0.8)
    end
    return true
end
