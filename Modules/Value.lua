local ADDON_NAME, WK = ...
local M = WK:NewModule("Value")

-- Prix des objets : Auctionator (prix de l'hôtel des ventes) si présent, sinon prix de vente
-- aux marchands. Richesse totale = or + valeur des stocks (sacs, banques, courrier, bataillon).
local CACHE_SECONDS = 30

function M:HasAuctionator()
    return Auctionator and Auctionator.API and Auctionator.API.v1
        and Auctionator.API.v1.GetAuctionPriceByItemID ~= nil
end

local function vendorPrice(itemID)
    return select(11, WK.GetItemInfo(itemID)) or 0
end

local function ahPrice(itemID)
    if not M:HasAuctionator() then return nil end
    local ok, price = pcall(Auctionator.API.v1.GetAuctionPriceByItemID, ADDON_NAME, itemID)
    if ok and type(price) == "number" and price > 0 then return price end
end

-- Prix unitaire en cuivre et sa source ("ah" ou "vendor").
function M:Price(itemID)
    if WK.DB.global.settings.value.source ~= "vendor" then
        local p = ahPrice(itemID)
        if p then return p, "ah" end
    end
    return vendorPrice(itemID), "vendor"
end

-- Valeur d'une liste { [itemID] = quantité }.
function M:ValueOf(items)
    local v = 0
    for id, n in pairs(items or {}) do v = v + self:Price(id) * n end
    return v
end

-- Valeur des stocks d'un personnage (sacs + banque + courrier).
function M:CharValue(c)
    return self:ValueOf(c.bags) + self:ValueOf(c.bank) + self:ValueOf(c.mailbox and c.mailbox.items)
end

-- Valeur des stocks du compte (mise en cache quelques secondes).
local cache, cacheAt = 0, -1000
function M:StockValue(force)
    local now = GetTime and GetTime() or time()
    if not force and now - cacheAt < CACHE_SECONDS then return cache end
    local v = 0
    for _, c in pairs(WK.DB.global.characters) do v = v + self:CharValue(c) end
    local wb = WK.DB.global.warbank
    if wb then v = v + self:ValueOf(wb.items) end
    cache, cacheAt = v, now
    return v
end

function M:AccountGold()
    local g = 0
    for _, c in pairs(WK.DB.global.characters) do g = g + (c.money or 0) end
    return g
end

-- Richesse totale (or + stocks) et enregistrement dans l'historique.
function M:Wealth(force)
    return self:AccountGold() + self:StockValue(force)
end

function M:Record()
    local h = WK.DB.global.history
    h.value = h.value or {}
    WK.DB:PushHistory(h.value, self:Wealth(true))
end

function M:SourceLabel()
    if WK.DB.global.settings.value.source ~= "vendor" and self:HasAuctionator() then
        return WK.T("prix Auctionator")
    end
    return WK.T("prix marchand")
end

-- Les prix d'Auctionator arrivent après le chargement : on enregistre un peu plus tard.
function M:OnLogin()
    C_Timer.After(15, function() M:Record(); WK:NotifyChanged() end)
end
