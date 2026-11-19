local ADDON_NAME, WK = ...
local M = WK:NewModule("AHSell")
local T = function(s) return WK.T(s) end

-- Hôtel des ventes, côté vente (système d'HV récent, C_AuctionHouse) :
--   Mes enchères : liste de tes enchères en cours (QueryOwnedAuctions), et vérification une par une du
--     prix le plus bas actuel (recherche du jeu, une toutes les 1,2 s) : « sous-cotée » quand quelqu'un
--     vend moins cher que toi. Annuler passe par un clic du joueur (le jeu l'exige).
--   Vente rapide : quand tu poses un objet dans la fenêtre de vente du jeu, le prix est rempli au plus bas
--     des autres vendeurs moins 1 pc (sinon au prix relevé par le scan moins 1 pc).
--   Alertes de prix : objets suivis avec un prix maximum ; après chaque scan, ceux qui sont en vente à ce
--     prix ou moins sont signalés (chat, rappel à l'écran, onglet Scan du panneau).
-- Réglages dans AHScan:Config() : quickSell, undercut (pc), alerts = { [itemID] = prix max à l'unité }.
local S = WK.modules.AHScan
local AH = function() return C_AuctionHouse end
local THROTTLE = 1.2

local function cfg()
    local c = S:Config()
    if c.quickSell == nil then c.quickSell = true end
    c.undercut = c.undercut or 1
    c.alerts = c.alerts or {}
    return c
end
M.Config = cfg
local function notify() if M.OnChange then M:OnChange() end end

local function isCommodity(id)
    local A = AH()
    if A and A.GetItemCommodityStatus and Enum and Enum.ItemCommodityStatus then
        local ok, st = pcall(A.GetItemCommodityStatus, id)
        if ok and st == Enum.ItemCommodityStatus.Item then return false end
    end
    return true
end
local function itemKeyOf(id)
    local A = AH()
    if A and A.MakeItemKey then
        local ok, k = pcall(A.MakeItemKey, id)
        if ok then return k end
    end
    return { itemID = id, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = 0 }
end
local function sorts()
    local po = Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price or 0
    return { { sortOrder = po, reverseSort = false } }
end

-- Plus bas prix à l'unité chez les autres vendeurs, d'après les résultats de recherche affichés par le jeu.
-- Renvoie prix, ou nil si aucun résultat lisible ; mine = le plus bas est à toi.
local function lowestOther(id)
    local A = AH()
    if not A then return nil end
    if isCommodity(id) then
        if not (A.GetNumCommoditySearchResults and A.GetCommoditySearchResultInfo) then return nil end
        local okn, n = pcall(A.GetNumCommoditySearchResults, id)
        if not okn or not n or n == 0 then return nil end
        local first
        for i = 1, math.min(n, 20) do
            local ok, r = pcall(A.GetCommoditySearchResultInfo, id, i)
            if ok and r and r.unitPrice then
                first = first or r
                if not r.containsOwnerItem then return r.unitPrice, first.containsOwnerItem end
            end
        end
        return nil, first and first.containsOwnerItem
    else
        if not (A.GetNumItemSearchResults and A.GetItemSearchResultInfo) then return nil end
        local key = itemKeyOf(id)
        local okn, n = pcall(A.GetNumItemSearchResults, key)
        if not okn or not n or n == 0 then return nil end
        local first
        for i = 1, math.min(n, 20) do
            local ok, r = pcall(A.GetItemSearchResultInfo, key, i)
            if ok and r and r.buyoutAmount then
                first = first or r
                if not r.containsOwnerItem then return math.floor(r.buyoutAmount / math.max(1, r.quantity or 1)), first.containsOwnerItem end
            end
        end
        return nil, first and first.containsOwnerItem
    end
end
M.LowestOther = lowestOther

---------------------------------------------------------------------------
-- Mes enchères
---------------------------------------------------------------------------
-- M.owned = { { auctionID, id, link, qty, unit, timeLeft, lowest, mine, state = "?"|"ok"|"under"|"alone" } }
M.owned = {}
M.queue, M.checking = {}, false
local SOLD = Enum and Enum.AuctionStatus and Enum.AuctionStatus.Sold or 1

function M:Available()
    local A = AH()
    return A and A.QueryOwnedAuctions and A.GetNumOwnedAuctions and A.GetOwnedAuctionInfo and true or false
end
function M:Query()
    if not self:Available() then return false end
    local ok = pcall(AH().QueryOwnedAuctions, sorts())
    return ok
end
local function readOwned()
    local A = AH()
    local prev = {}
    for _, o in ipairs(M.owned) do prev[o.auctionID] = o end
    local out = {}
    local okn, n = pcall(A.GetNumOwnedAuctions)
    for i = 1, (okn and n or 0) do
        local ok, info = pcall(A.GetOwnedAuctionInfo, i)
        if ok and info and info.status ~= SOLD and info.itemKey then
            local id = info.itemKey.itemID
            local qty = info.quantity or 1
            local unit = info.buyoutAmount
            -- marchandises : prix déjà à l'unité ; objets : prix de l'enchère
            if unit and not isCommodity(id) and qty > 1 then unit = math.floor(unit / qty) end
            local p = prev[info.auctionID]
            table.insert(out, { auctionID = info.auctionID, id = id, link = info.itemLink, qty = qty, unit = unit,
                timeLeft = info.timeLeftSeconds, lowest = p and p.lowest, mine = p and p.mine, state = p and p.state or "?" })
        end
    end
    table.sort(out, function(a, b)
        local ra, rb = a.state == "under" and 0 or 1, b.state == "under" and 0 or 1
        if ra ~= rb then return ra < rb end
        return (a.id or 0) < (b.id or 0)
    end)
    M.owned = out
    -- relevé gardé pour le client PC (enchères qui expirent, Modules/ClientDash.lua)
    local c = WK.DB:Me()
    if c then
        local list, now = {}, time()
        for _, o in ipairs(out) do
            if o.timeLeft then table.insert(list, { id = o.id, qty = o.qty, exp = now + o.timeLeft }) end
        end
        c.auctionsSeen = { at = now, list = list }
    end
    notify()
end
WK:On("OWNED_AUCTIONS_UPDATED", function() pcall(readOwned) end)
WK:On("AUCTION_CANCELED", function() M:Query() end)
WK:On("AUCTION_HOUSE_AUCTION_CREATED", function() M:Query() end)

local function setState(id, lowest, mine)
    for _, o in ipairs(M.owned) do
        if o.id == id then
            o.lowest, o.mine = lowest, mine
            if not lowest then o.state = mine and "alone" or "ok"
            elseif o.unit and lowest < o.unit then o.state = "under"
            else o.state = "ok" end
        end
    end
end

-- Vérifie le plus bas prix de chaque objet en vente, un par un
local pendingCheck, pendingAt
local ticker
local RESULT_TIMEOUT = 6 -- secondes d'attente au plus pour les résultats d'une recherche
local function nextCheck()
    if #M.queue == 0 then
        M.checking = false
        if ticker then ticker:Cancel(); ticker = nil end
        table.sort(M.owned, function(a, b)
            local ra, rb = a.state == "under" and 0 or 1, b.state == "under" and 0 or 1
            if ra ~= rb then return ra < rb end
            return (a.id or 0) < (b.id or 0)
        end)
        notify()
        return
    end
    local id = table.remove(M.queue, 1)
    pendingCheck, pendingAt = id, GetTime()
    local A = AH()
    local ok = pcall(A.SendSearchQuery, itemKeyOf(id), sorts(), true)
    if not ok then
        -- pas de recherche possible : on compare au prix du scan
        local p = S:Price(id)
        setState(id, p, false)
        pendingCheck = nil
    end
    notify()
end
function M:Check()
    if not (AH() and AH().SendSearchQuery) then
        -- client sans recherche : comparaison au scan
        for _, o in ipairs(self.owned) do setState(o.id, S:Price(o.id), false) end
        notify()
        return
    end
    local seen = {}
    self.queue = {}
    for _, o in ipairs(self.owned) do
        if not seen[o.id] then seen[o.id] = true; table.insert(self.queue, o.id) end
    end
    self.total = #self.queue
    self.checking = #self.queue > 0
    if ticker then ticker:Cancel() end
    pendingCheck = nil
    -- recherche suivante seulement quand les résultats de la précédente sont arrivés (ou après un délai)
    if C_Timer.NewTicker then
        ticker = C_Timer.NewTicker(THROTTLE, function()
            if pendingCheck and GetTime() - (pendingAt or 0) < RESULT_TIMEOUT then return end
            if pendingCheck then
                -- pas de réponse : comparaison au prix du scan
                local p = S:Price(pendingCheck)
                if p then setState(pendingCheck, p, false) end
                pendingCheck = nil
            end
            nextCheck()
        end)
    end
    nextCheck()
end
function M:Progress()
    return (self.total or 0) - #self.queue, self.total or 0
end
local function onResults(id)
    if pendingCheck and id == pendingCheck then
        local low, mine = lowestOther(id)
        setState(id, low, mine)
        pendingCheck = nil
        notify()
    end
    if M.sellPending and M.sellPending.id == id then M:ApplyQuickSell() end
end
WK:On("COMMODITY_SEARCH_RESULTS_UPDATED", function(id) onResults(id) end)
WK:On("ITEM_SEARCH_RESULTS_UPDATED", function(key) onResults(type(key) == "table" and key.itemID or key) end)

-- Annuler une enchère (appelé depuis un clic du joueur)
function M:Cancel(auctionID)
    local A = AH()
    if not (A and A.CancelAuction) then return false end
    local ok, err = pcall(A.CancelAuction, auctionID)
    if not ok then WK:Print(T("Annulation refusée par le jeu.")) end
    return ok
end
function M:UnderCount()
    local n = 0
    for _, o in ipairs(self.owned) do if o.state == "under" then n = n + 1 end end
    return n
end

---------------------------------------------------------------------------
-- Vente rapide : prix rempli au plus bas moins 1 pc
---------------------------------------------------------------------------
local function sellFrames()
    local f = AuctionHouseFrame
    if not f then return {} end
    return { f.CommoditiesSellFrame, f.ItemSellFrame }
end
local function priceInput(sf)
    return sf and (sf.PriceInput or (sf.GetPriceInput and sf:GetPriceInput()))
end
function M:ApplyQuickSell()
    local p = self.sellPending
    if not p then return end
    local low, mine = lowestOther(p.id)
    local c = cfg()
    local price, why
    if low then
        price, why = math.max(1, low - c.undercut), T("plus bas")
    elseif mine then
        self.sellPending = nil
        return -- tu es seul au plus bas : on laisse le prix du jeu
    elseif S:Price(p.id) then
        price, why = math.max(1, S:Price(p.id) - c.undercut), T("prix du scan")
    end
    self.sellPending = nil
    if not price then return end
    local pi = priceInput(p.frame)
    if not (pi and pi.SetAmount) then return end
    -- après le jeu, qui remplit aussi son prix à l'arrivée des résultats
    C_Timer.After(0.15, function()
        pcall(pi.SetAmount, pi, price)
        for _, fn in ipairs({ "OnPriceChanged", "UpdateTotalPrice", "UpdatePostState", "MarkDirty" }) do
            if p.frame[fn] then pcall(p.frame[fn], p.frame) end
        end
        self.lastQuick = { id = p.id, price = price, low = low, why = why }
        notify()
    end)
end
local hooked = false
local function hookSell()
    if hooked or not hooksecurefunc then return end
    for _, sf in ipairs(sellFrames()) do
        if sf and sf.SetItem then
            hooked = true
            hooksecurefunc(sf, "SetItem", function(frame, itemLocation)
                if not cfg().quickSell or not WK:FeatureOn("ah") then return end
                local id
                if itemLocation and C_Item and C_Item.GetItemID then
                    local ok, v = pcall(C_Item.GetItemID, itemLocation)
                    if ok then id = v end
                end
                if not id then return end
                M.sellPending = { id = id, frame = frame }
                -- résultats déjà là (objet déjà cherché) : tout de suite ; sinon à leur arrivée
                if lowestOther(id) then M:ApplyQuickSell() end
                C_Timer.After(2, function() if M.sellPending and M.sellPending.id == id then M:ApplyQuickSell() end end)
            end)
        end
    end
end

---------------------------------------------------------------------------
-- Alertes de prix
---------------------------------------------------------------------------
M.triggered = {}
-- « 2.5 » (po), « 2po50pa », « 2po 50pa 3pc », « 75pa », « 30pc » -> pièces de cuivre
function M.ParsePrice(txt)
    txt = string.lower((txt or ""):gsub(",", "."))
    local n = tonumber(txt)
    if n then return math.floor(n * 10000 + 0.5) end
    local total, any = 0, false
    for v, u in txt:gmatch("([%d%.]+)%s*([%a]+)") do
        local x = tonumber(v)
        if not x then return nil end
        if u == "po" or u == "g" then total = total + x * 10000
        elseif u == "pa" or u == "s" then total = total + x * 100
        elseif u == "pc" or u == "c" then total = total + x
        else return nil end
        any = true
    end
    return any and math.floor(total + 0.5) or nil
end
function M:AddAlert(id, maxPrice)
    if not id or not maxPrice or maxPrice <= 0 then return false end
    cfg().alerts[id] = math.floor(maxPrice)
    self:CheckAlerts(true)
    notify()
    return true
end
function M:RemoveAlert(id)
    cfg().alerts[id] = nil
    self:CheckAlerts(true)
    notify()
end
function M:Alerts()
    local out = {}
    for id, max in pairs(cfg().alerts) do
        local e = S:Entry(id)
        table.insert(out, { id = id, max = max, price = e and e.p, qty = e and e.q, hit = e and e.p and (e.q or 0) > 0 and e.p <= max })
    end
    table.sort(out, function(a, b)
        if (a.hit and 1 or 0) ~= (b.hit and 1 or 0) then return a.hit end
        return a.id < b.id
    end)
    return out
end
-- Après un scan : objets suivis en vente à leur prix max ou moins (silent : sans message)
function M:CheckAlerts(silent)
    local hits = {}
    for _, a in ipairs(self:Alerts()) do if a.hit then table.insert(hits, a) end end
    self.triggered = hits
    if silent or #hits == 0 then return end
    for _, a in ipairs(hits) do
        WK:Print(string.format(T("Alerte de prix : %s à %s (ton prix : %s)"), WK.GetItemInfo(a.id) or ("#" .. a.id), WK.UI:ExactMoney(a.price), WK.UI:ExactMoney(a.max)))
    end
    local Q = WK.modules.QoL
    if Q and Q.Remind then
        Q:Remind("ahprice", #hits > 1 and string.format(T("%d alertes de prix à l'HV"), #hits)
            or string.format(T("Alerte de prix : %s"), WK.GetItemInfo(hits[1].id) or "?"), 1, 0.82, 0.2)
    end
    if PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.AUCTION_WINDOW_OPEN or 5274) end
end

---------------------------------------------------------------------------
-- Ouverture de l'HV
---------------------------------------------------------------------------
WK:On("AUCTION_HOUSE_SHOW", function()
    if not WK:FeatureOn("ah") then return end
    C_Timer.After(0.3, function()
        hookSell()
        M:Query()
    end)
end)
WK:On("AUCTION_HOUSE_CLOSED", function()
    M.queue, M.checking, pendingCheck, M.sellPending = {}, false, nil, nil
    if ticker then ticker:Cancel(); ticker = nil end
end)

-- /wk hv : ce que ce client permet côté vente
function M:Report()
    local A = AH()
    local function yn(v) return v and T("oui") or T("non") end
    WK:Print("  " .. T("mes enchères") .. " : " .. yn(self:Available()) .. " · " .. T("recherche") .. " : " .. yn(A and A.SendSearchQuery)
        .. " · " .. T("annuler") .. " : " .. yn(A and A.CancelAuction))
    local sf = sellFrames()
    WK:Print("  " .. T("vente rapide") .. " : " .. yn(sf[1] and sf[1].SetItem) .. "/" .. yn(sf[2] and sf[2].SetItem)
        .. " · " .. T("prix") .. " : " .. yn(priceInput(sf[1]) and priceInput(sf[1]).SetAmount))
end
