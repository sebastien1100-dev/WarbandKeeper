local ADDON_NAME, WK = ...
local M = WK:NewModule("Inventory")

local BI = Enum and Enum.BagIndex
-- Sacs équipés : sac à dos (0) + 4 sacs (+ sac de composants sur le client moderne).
local NUM_BAGS = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4

-- Agrège le contenu d'une liste de conteneurs en { [itemID] = quantité }.
local function scan(bags)
    local result = {}
    for _, bag in ipairs(bags) do
        local n = WK.Container.NumSlots(bag) or 0
        for slot = 1, n do
            local id, count = WK.Container.Info(bag, slot)
            if id then result[id] = (result[id] or 0) + (count or 1) end
        end
    end
    return result
end

function M:BagList()
    local t = {}
    for b = 0, NUM_BAGS do table.insert(t, b) end
    return t
end

-- Banque du personnage : onglets (client récent) ou banque + sacs de banque (ancien).
function M:BankList()
    local t = {}
    if BI and BI.CharacterBankTab_1 then
        for i = 1, 6 do
            local b = BI["CharacterBankTab_" .. i]
            if b then table.insert(t, b) end
        end
        return t
    end
    table.insert(t, BANK_CONTAINER or (BI and BI.Bank) or -1)
    if BI and BI.Reagentbank then table.insert(t, BI.Reagentbank) end
    for b = NUM_BAGS + 1, NUM_BAGS + (NUM_BANKBAGSLOTS or 7) do table.insert(t, b) end
    return t
end

-- Banque de bataillon (commune au compte), si le client la propose.
function M:WarbandList()
    local t = {}
    if BI and BI.AccountBankTab_1 then
        for i = 1, 5 do
            local b = BI["AccountBankTab_" .. i]
            if b then table.insert(t, b) end
        end
    end
    return t
end

local function totalSlots(bags)
    local n = 0
    for _, b in ipairs(bags) do n = n + (WK.Container.NumSlots(b) or 0) end
    return n
end

function M:ScanBags()
    local c = WK.DB:Me()
    c.bags = scan(self:BagList())
    local free, total = 0, 0
    for _, bag in ipairs(self:BagList()) do
        free = free + (WK.Container.NumFree(bag) or 0)
        total = total + (WK.Container.NumSlots(bag) or 0)
    end
    c.freeSlots, c.totalSlots = free, total
    WK.modules.Statistics:UpdateItems()
    WK:NotifyChanged()
end

local bankOpen = false
function M:ScanBank()
    if not bankOpen then return end
    local c = WK.DB:Me()
    -- On n'écrase pas les données si la banque n'est pas réellement accessible.
    local bank = self:BankList()
    if totalSlots(bank) > 0 then
        c.bank = scan(bank)
        c.bankScanned = time()
    end
    local wb = self:WarbandList()
    if #wb > 0 and totalSlots(wb) > 0 then
        WK.DB.global.warbank = { items = scan(wb), scanned = time() }
    end
    WK.modules.Statistics:UpdateItems()
    WK:NotifyChanged()
end

-- Regroupe les BAG_UPDATE rafales en un seul scan.
local pending = false
local function scheduleScan()
    if pending then return end
    pending = true
    C_Timer.After(0.5, function()
        pending = false
        M:ScanBags()
        M:ScanBank()
    end)
end

function M:OnLogin() self:ScanBags() end

WK:On("BAG_UPDATE", scheduleScan)
WK:On("BANKFRAME_OPENED", function() bankOpen = true; M:ScanBank() end)
WK:On("BANKFRAME_CLOSED", function() bankOpen = false end)
WK:On("PLAYERBANKSLOTS_CHANGED", scheduleScan)

-- Total d'un objet sur tout le compte.
function M:AccountCount(itemID)
    local total = 0
    for _, c in pairs(WK.DB.global.characters) do
        total = total + ((c.bags or {})[itemID] or 0) + ((c.bank or {})[itemID] or 0)
    end
    local wb = WK.DB.global.warbank
    if wb then total = total + (wb.items[itemID] or 0) end
    return total
end

-- Recherche par nom (partiel, insensible à la casse) ou itemID.
function M:Find(query)
    local id = WK:ParseItemID(query)
    local q = query and string.lower(query)
    local found = false
    for key, c in pairs(WK.DB.global.characters) do
        for _, where in ipairs({ "bags", "bank" }) do
            for itemID, count in pairs(c[where] or {}) do
                local match = (id and itemID == id)
                if not match and not id then
                    local name = WK.GetItemInfo(itemID)
                    match = name and string.find(string.lower(name), q, 1, true)
                end
                if match then
                    found = true
                    WK:Print(string.format("  %s x%d - %s (%s)", WK:ItemName(itemID), count, key,
                        where == "bags" and WK.L.BAGS or WK.L.BANK))
                end
            end
        end
    end
    if not found then WK:Print(WK.L.NOT_FOUND .. " \"" .. tostring(query) .. "\"") end
end

-- Info-bulle : quantité par personnage.
local function onTooltip(tooltip)
    local _, link = tooltip:GetItem()
    local itemID = WK:ParseItemID(link)
    if not itemID then return end
    local any = false
    for key, c in pairs(WK.DB.global.characters) do
        local b, k = (c.bags or {})[itemID] or 0, (c.bank or {})[itemID] or 0
        if b + k > 0 then
            if not any then tooltip:AddLine(" "); tooltip:AddLine("|cff33ccffWarband Keeper|r"); any = true end
            tooltip:AddDoubleLine(key, string.format("%d (%s %d, %s %d)", b + k, WK.L.BAGS, b, WK.L.BANK, k), 1, 1, 1, 1, 1, 1)
        end
    end
    local wb = WK.DB.global.warbank
    local w = wb and wb.items[itemID] or 0
    if w > 0 then
        if not any then tooltip:AddLine(" "); tooltip:AddLine("|cff33ccffWarband Keeper|r"); any = true end
        tooltip:AddDoubleLine("Banque de bataillon", tostring(w), 1, 1, 1, 1, 1, 1)
    end
    if any then tooltip:Show() end
end

if TooltipDataProcessor and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, onTooltip)
else
    GameTooltip:HookScript("OnTooltipSetItem", onTooltip)
    if ItemRefTooltip then ItemRefTooltip:HookScript("OnTooltipSetItem", onTooltip) end
end
