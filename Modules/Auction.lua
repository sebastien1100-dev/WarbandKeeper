local ADDON_NAME, WK = ...
local M = WK:NewModule("Auction")

-- Ventes et achats à l'hôtel des ventes, lus sur les factures des courriers de l'HV
-- au moment où on en prend l'or (vente) ou l'objet (achat), à la main ou par « Tout prendre ».
-- WK.DB.global.auction.log = { { t, kind = "sale"|"buy", char, item, count, gross, net }, ... }
local MAX_LOG = 1000

local function log() return WK.DB.global.auction.log end

-- Un courrier peut être lu plusieurs fois (prise répétée en attendant le serveur) : on ne le compte qu'une fois.
local seen = {}

local function record(index)
    if not GetInboxInvoiceInfo or not index then return end
    local invoiceType, itemName, _, bid, _, deposit, consignment, _, _, _, count = GetInboxInvoiceInfo(index)
    if invoiceType ~= "seller" and invoiceType ~= "buyer" then return end
    local _, _, sender, subject, money, _, daysLeft = GetInboxHeaderInfo(index)
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
        else
            buys, nBuys = buys + (e.gross or 0), nBuys + 1
        end
    end
    local top = {}
    for _, b in pairs(byItem) do table.insert(top, b) end
    table.sort(top, function(a, b) return a.net > b.net end)
    return { sales = sales, buys = buys, balance = sales - buys, nSales = nSales, nBuys = nBuys, top = top }
end
