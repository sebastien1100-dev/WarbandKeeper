local ADDON_NAME, WK = ...
local M = WK:NewModule("AHScan")
local T = function(s) return WK.T(s) end

-- Hôtel des ventes sans Auctionator : scan de l'HV et prix des objets.
--   Scan complet en une requête quand le jeu le permet (environ toutes les 15 min), sinon page par page.
--   Deux API possibles selon le client : C_AuctionHouse.ReplicateItems (récente) ou QueryAuctionItems
--   (ancienne, celle des clients classiques). /wk hv dit laquelle ce client donne.
--   Par objet : prix unitaire le plus bas en achat immédiat, quantité en vente, date, et le plus bas de
--   chaque jour sur 14 jours.
-- Données : WK.DB.global.ah.realms["Royaume-Faction"].items[itemID] = { p, q, t, h = { [jour] = prix } }
-- Réglages : WK.DB.global.ah (tooltip, stack, auto, panel).

local DEFAULTS = { tooltip = true, stack = true, auto = false, panel = true }
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
function M:Data()
    local r = self:Config().realms
    local k = realmKey()
    r[k] = r[k] or { items = {} }
    return r[k]
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
-- Moyenne des plus bas de chaque jour (14 jours) et nombre de jours relevés
function M:Average(itemID)
    local e = self:Entry(itemID)
    if not e or not e.h then return nil, 0 end
    local sum, n = 0, 0
    for _, p in pairs(e.h) do sum, n = sum + p, n + 1 end
    if n == 0 then return nil, 0 end
    return math.floor(sum / n + 0.5), n
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
    if modern() then return true, true end
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

local function record(seen, itemID, count, buyout)
    if not itemID or not buyout or buyout <= 0 or not count or count <= 0 then return end
    local unit = math.floor(buyout / count)
    local s = seen[itemID]
    if not s then seen[itemID] = { unit, count }
    else
        if unit < s[1] then s[1] = unit end
        s[2] = s[2] + count
    end
end

-- Fin du scan : on remplace les prix des objets vus ; un scan complet remet à zéro la quantité des autres
local function finish(ok)
    local sc = M.scan
    M.scan = nil
    driver:SetScript("OnUpdate", nil)
    driver:UnregisterAllEvents()
    if not sc then return end
    if ok then
        local d = M:Data()
        local now = time()
        local day = math.floor(now / 86400)
        local n = 0
        for id, s in pairs(sc.seen) do
            n = n + 1
            local e = d.items[id] or {}
            e.p, e.q, e.t = s[1], s[2], now
            e.h = e.h or {}
            if not e.h[day] or s[1] < e.h[day] then e.h[day] = s[1] end
            for dd in pairs(e.h) do if dd <= day - HISTORY_DAYS then e.h[dd] = nil end end
            d.items[id] = e
        end
        if sc.full then
            for id, e in pairs(d.items) do if not sc.seen[id] then e.q = 0 end end
        end
        d.last = now
        if sc.full then d.lastFull = now end
        d.lastCount = n
        WK:Print(string.format(T("Scan de l'HV terminé : %d objets, %d enchères."), n, sc.done or 0))
        WK:NotifyChanged()
    else
        WK:Print(T("Scan de l'HV interrompu."))
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
    if modern() then startModern() notify() return end
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
    WK:Print("  QueryAuctionItems : " .. tostring(QueryAuctionItems ~= nil) .. " · GetAuctionItemInfo : " .. tostring(GetAuctionItemInfo ~= nil))
    local q, all = self:CanQuery()
    WK:Print("  CanSendAuctionQuery : " .. tostring(CanSendAuctionQuery ~= nil) .. " (" .. tostring(q) .. ", " .. T("complet") .. " " .. tostring(all) .. ")")
    WK:Print("  " .. T("HV ouvert") .. " : " .. tostring(self.open and true or false) .. " · AuctionFrame : " .. tostring(AuctionFrame ~= nil) .. " · AuctionHouseFrame : " .. tostring(AuctionHouseFrame ~= nil))
    local d = self:Data()
    WK:Print("  " .. string.format(T("%d objets avec un prix"), self:Count()) .. (d.last and (" · " .. T("dernier scan") .. " " .. date("%d/%m %H:%M", d.last)) or ""))
end
