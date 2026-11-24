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
    table.insert(t, M.BankMain())
    if BI and BI.Reagentbank then table.insert(t, BI.Reagentbank) end
    for _, b in ipairs(M.BankExtra()) do table.insert(t, b) end
    for _, b in ipairs(M:BankBagIDs()) do table.insert(t, b) end
    return t
end

-- N° de conteneur des sacs de banque, dans l'ordre des emplacements de la banque. Retrouvés par l'emplacement
-- d'inventaire de chaque sac de banque (comme la banque du jeu) : le nombre de sacs du perso varie selon le client.
-- N° de la banque de base (sans sac) : celui du jeu (Enum.BagIndex.Bank) d'abord, il n'est pas toujours -1
function M.BankMain()
    return (BI and BI.Bank) or BANK_CONTAINER or -1
end

-- /wk banque : n° des conteneurs de la banque tels que le jeu les donne (à lancer banque ouverte)
function M.BankDiag()
    local CC = _G.C_Container
    local toInv = (CC and CC.ContainerIDToInventoryID) or _G.ContainerIDToInventoryID
    local nslots = (CC and CC.GetContainerNumSlots) or _G.GetContainerNumSlots
    local out = {}
    out[#out + 1] = string.format("base = %s  ·  sacs du perso = %s  ·  emplacements = %s  ·  achetés = %s",
        tostring(M.BankMain()), tostring(NUM_BAGS), tostring(_G.NUM_BANKBAGSLOTS),
        tostring(_G.GetNumBankSlots and select(1, pcall(_G.GetNumBankSlots)) and _G.GetNumBankSlots()))
    out[#out + 1] = "sacs de banque : " .. table.concat(M.BankBagIDs(), ", ")
    for b = -1, 14 do
        local okN, n = pcall(function() return nslots and nslots(b) end)
        local okI, inv = pcall(function() return toInv and toInv(b) end)
        local tex = okI and inv and _G.GetInventoryItemTexture and _G.GetInventoryItemTexture("player", inv)
        if (okN and n and n > 0) or tex then
            out[#out + 1] = string.format("  %d : %s cases  ·  emplacement %s%s", b, tostring(okN and n or "?"),
                tostring(okI and inv or "-"), tex and "  ·  sac posé" or "")
        end
    end
    for i = 1, 8 do
        local ok, inv = pcall(function() return _G.BankButtonIDToInvSlotID and _G.BankButtonIDToInvSlotID(i, 1) end)
        out[#out + 1] = string.format("  emplacement de banque %d : %s", i, tostring(ok and inv or "?"))
    end
    return out
end

-- Rangement fixe de la banque, sans emplacement de sac (WoW Forever : la « caisse » de 48 cases juste après les
-- sacs du perso, quand le client a le sac de composants et pas BankButtonIDToInvSlotID) : lu avec la banque,
-- jamais montré dans la barre des sacs
function M.BankExtra()
    if not _G.BankButtonIDToInvSlotID and NUM_BAGS >= 5 then return { NUM_BAGS + 1 } end
    return {}
end

local bankBagIDs
function M.BankBagIDs()
    if bankBagIDs then return bankBagIDs end
    local n = NUM_BANKBAGSLOTS or 7
    local CC = _G.C_Container
    local toInv = (CC and CC.ContainerIDToInventoryID) or _G.ContainerIDToInventoryID
    local toSlot = _G.BankButtonIDToInvSlotID
    local out
    if toSlot and toInv then
        -- seulement après les sacs du perso (sac de composants compris) : sur ce client, l'emplacement d'un sac du
        -- perso peut répondre pour le 1er sac de banque
        local byInv = {}
        local main = M.BankMain()
        for b = NUM_BAGS + 1, 20 do
            local ok, inv = pcall(toInv, b)
            if ok and inv and b ~= main then byInv[inv] = b end
        end
        -- autant d'emplacements que la banque du jeu en affiche (la constante du client peut être plus petite)
        local shown = 0
        local slots = _G.BankSlotsFrame
        for i = 1, 12 do
            if _G["BankFrameBag" .. i] or (slots and slots["Bag" .. i]) then shown = i else break end
        end
        if shown > 0 then n = shown end
        out = {}
        for i = 1, n do
            local ok, inv = pcall(toSlot, i, 1)
            local b = ok and inv and byInv[inv]
            if not b then break end
            out[#out + 1] = b
        end
        if #out == 0 then out = nil end
    end
    if out then bankBagIDs = out return out end -- gardé seulement si la correspondance a marché
    -- sans correspondance : à la suite des sacs du perso et du rangement fixe ; 8 emplacements comme la banque
    -- du jeu sur WoW Forever quand le client ne donne pas le nombre
    if not _G.NUM_BANKBAGSLOTS and not _G.BankButtonIDToInvSlotID then n = math.max(n, 8) end
    out = {}
    local main, extra = M.BankMain(), {}
    for _, e in ipairs(M.BankExtra()) do extra[e] = true end
    local b = NUM_BAGS + 1
    while #out < n and b <= 20 do
        if b ~= main and not extra[b] then out[#out + 1] = b end
        b = b + 1
    end
    return out
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
    local old = c.bags
    c.bags = scan(self:BagList())
    if WK.modules.Farm then WK.modules.Farm:OnBags(old, c.bags) end
    local free, total = 0, 0
    for _, bag in ipairs(self:BagList()) do
        free = free + (WK.Container.NumFree(bag) or 0)
        total = total + (WK.Container.NumSlots(bag) or 0)
    end
    c.freeSlots, c.totalSlots = free, total
    WK.modules.Statistics:UpdateItems()
    -- sacs relus (c.bags à jour) : ce qui dépend du contenu des sacs se refait (nourriture du familier…)
    if WK.Fire then WK:Fire("WK_BAGS_SCANNED") end
    WK:NotifyChanged()
end

local bankOpen = false
-- Depuis quand chaque objet dort en banque : date depuis laquelle sa quantité n'a pas changé.
local function trackAges(ages, items)
    local now = time()
    for id, n in pairs(items) do
        local e = ages[id]
        if not e or e.n ~= n then ages[id] = { n = n, since = now } end
    end
    for id in pairs(ages) do if not items[id] then ages[id] = nil end end
end

function M:ScanBank()
    if not bankOpen then return end
    local c = WK.DB:Me()
    -- On n'écrase pas les données si la banque n'est pas réellement accessible.
    local bank = self:BankList()
    if totalSlots(bank) > 0 then
        c.bank = scan(bank)
        c.bankScanned = time()
        local free = 0
        for _, b in ipairs(bank) do free = free + (WK.Container.NumFree(b) or 0) end
        c.bankFree, c.bankSlots = free, totalSlots(bank)
        c.bankAges = c.bankAges or {}
        trackAges(c.bankAges, c.bank)
    end
    local wb = self:WarbandList()
    if #wb > 0 and totalSlots(wb) > 0 then
        local old = WK.DB.global.warbank
        local ages = old and old.ages or {}
        WK.DB.global.warbank = { items = scan(wb), scanned = time(), ages = ages }
        trackAges(ages, WK.DB.global.warbank.items)
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

-- Quantité d'un objet chez un personnage : sacs, banque, boîte aux lettres.
function M:CharCount(c, itemID)
    local b = (c.bags or {})[itemID] or 0
    local k = (c.bank or {})[itemID] or 0
    local m = (c.mailbox and c.mailbox.items[itemID]) or 0
    return b + k + m, b, k, m
end

-- Total d'un objet sur tout le compte.
function M:AccountCount(itemID)
    local total = 0
    for _, c in pairs(WK.DB.global.characters) do
        total = total + (self:CharCount(c, itemID))
    end
    local wb = WK.DB.global.warbank
    if wb then total = total + (wb.items[itemID] or 0) end
    return total
end

-- Recherche par nom (partiel, insensible à la casse) ou itemID.
function M:Find(query)
    -- recherche vide : tout le compte correspondrait, on rappelle l'usage
    if type(query) ~= "string" or not query:find("%S") then
        WK:Print(WK.L.HELP_FIND or "/wk cherche <nom>")
        return
    end
    local id = WK:ParseItemID(query)
    local q = query and string.lower(query)
    local found = false
    for key, c in pairs(WK.DB.global.characters) do
        for _, where in ipairs({ "bags", "bank", "mailbox" }) do
            local list = where == "mailbox" and (c.mailbox and c.mailbox.items) or c[where]
            for itemID, count in pairs(list or {}) do
                local match = (id and itemID == id)
                if not match and not id then
                    local name = WK.GetItemInfo(itemID)
                    match = name and string.find(string.lower(name), q, 1, true)
                end
                if match then
                    found = true
                    WK:Print(string.format("  %s x%d - %s (%s)", WK:ItemName(itemID), count, WK:CharName(c, key),
                        where == "bags" and WK.L.BAGS or where == "bank" and WK.L.BANK or WK.L.MAILBOX))
                end
            end
        end
    end
    if not found then WK:Print(WK.L.NOT_FOUND .. " \"" .. tostring(query) .. "\"") end
end

-- Retrouve l'ID de l'objet affiché, quelle que soit la version de l'API.
local function tooltipItemID(tooltip, data)
    if data and type(data.id) == "number" then return data.id end
    if TooltipUtil and TooltipUtil.GetDisplayedItem then
        local _, link, id = TooltipUtil.GetDisplayedItem(tooltip)
        if id then return id end
        if link then return WK:ParseItemID(link) end
    end
    if tooltip.GetItem then
        local _, link = tooltip:GetItem()
        return WK:ParseItemID(link)
    end
end

-- Objets que tous les persos ont (le détail par perso n'apporte rien) : pas d'ajout à l'infobulle.
local NO_TOOLTIP = {
    [6948] = true, -- Pierre de foyer
}

-- Icônes des lignes de l'infobulle (taille du texte)
local ICON_BAG = "|TInterface\\Icons\\INV_Misc_Bag_08:0|t"
local ICON_BANK = "|TInterface\\Icons\\INV_Box_02:0|t"
local ICON_MAIL = "|TInterface\\Icons\\INV_Letter_15:0|t"
local ICON_WARBANK = "|TInterface\\Icons\\INV_Misc_Bag_10_Blue:0|t"
local ICON_PROF = "Interface\\Icons\\INV_Misc_Note_01"
local DIM, NEED = "|cff8a8f98", "|cfff5a742"

-- Info-bulle : quantité par personnage (pas sur les infobulles de comparaison).
local function onTooltip(tooltip, data)
    if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
    -- case de notre inventaire avec la fiche : ces infos y sont déjà (UI/Bags.lua, réglage lightTip)
    local owner = tooltip.GetOwner and tooltip:GetOwner()
    if owner and owner.wkOurs and WK.UI.Bags and WK.UI.Bags.LightTip() then return end
    local itemID = tooltipItemID(tooltip, data)
    if not itemID or NO_TOOLTIP[itemID] then return end
    local any = false
    -- Une ligne par perso : sacs, banque (courrier s'il y en a) en icônes, puis ce qu'il lui reste à
    -- utiliser pour monter ses métiers (icône du métier + nombre) ; total du compte sur la ligne de titre.
    local R = WK.modules.Recipes
    local needs = R and R.TooltipNeeds and R:TooltipNeeds(itemID)
    local rows, account = {}, 0
    for key, c in pairs(WK.DB.global.characters) do
        local total, b, k, m = M:CharCount(c, itemID)
        account = account + total
        local need = needs and needs[key]
        if total > 0 or need then
            table.insert(rows, { key = key, c = c, total = total, b = b, k = k, m = m, need = need })
        end
    end
    table.sort(rows, function(a, b)
        if a.total ~= b.total then return a.total > b.total end
        return a.key < b.key
    end)
    local wb = WK.DB.global.warbank
    local w = wb and wb.items[itemID] or 0
    account = account + w
    if #rows > 0 or w > 0 then
        any = true
        tooltip:AddLine(" ")
        tooltip:AddDoubleLine(WK:Tag(), account > 0 and (DIM .. WK.T("total") .. "|r " .. account) or "", 1, 1, 1, 1, 1, 1)
        for _, row in ipairs(rows) do
            local c = row.c
            local r, g, bl = 1, 1, 1
            local cc = c.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.class]
            if cc then r, g, bl = cc.r, cc.g, cc.b end
            local parts = {}
            if row.total > 0 then
                table.insert(parts, ICON_BAG .. " " .. row.b .. "  " .. ICON_BANK .. " " .. row.k)
                if row.m > 0 then table.insert(parts, ICON_MAIL .. " " .. row.m) end
            end
            for i, n in ipairs(row.need or {}) do
                if i > 2 then break end
                local icon = R.PROF_ICONS[n.en or ""] or ICON_PROF
                table.insert(parts, (#parts > 0 and (DIM .. "·|r ") or "") .. "|T" .. icon .. ":0|t " .. NEED .. n.left .. "|r")
            end
            local name = WK:CharName(c, row.key)
            if row.need then name = name .. DIM .. " (" .. row.need[1].rank .. ")|r" end
            tooltip:AddDoubleLine(name, table.concat(parts, "  "), r, g, bl, 1, 1, 1)
        end
        if w > 0 then tooltip:AddDoubleLine(WK.L.WARBANK, ICON_WARBANK .. " " .. w, 0.8, 0.8, 0.8, 1, 1, 1) end
    end
    -- à quoi sert encore l'objet pour monter les métiers (recettes, outils, métiers que personne ne monte)
    if R and R.AddTooltip then
        if R:AddTooltip(tooltip, itemID, function()
            if not any then tooltip:AddLine(" "); tooltip:AddLine(WK:Tag()); any = true end
        end, true) then any = true end
    end
    -- désenchantement : valeur attendue (Modules/ProfHelp.lua)
    local PH = WK.modules.ProfHelp
    if PH and PH:AddTooltip(tooltip, itemID, function()
        if not any then tooltip:AddLine(" "); tooltip:AddLine(WK:Tag()); any = true end
    end) then any = true end
    -- butin observé par les joueurs (Modules/EverlootDB.lua : PNJ, taux, nombre de butins relevés)
    local drops = WK.EverDrops and WK.EverDrops[itemID]
    local ui = WK.DB.global.settings.ui
    if drops and ui.tooltipDrops ~= false then
        if not any then tooltip:AddLine(" "); tooltip:AddLine(WK:Tag()); any = true end
        tooltip:AddLine(string.format(WK.T("Butin observé (%s)"), WK.EverlootAsOf and WK.EverlootAsOf:gsub("(%d+)-(%d+)-(%d+)", "%3/%2") or "Everloot"), 0.8, 0.8, 0.8)
        local fr = WK.Lang() == "frFR"
        for i = 1, math.min(#drops, 9), 3 do
            local n = WK.EverNpcs and WK.EverNpcs[drops[i]]
            local name = n and ((fr and n[2]) or n[1]) or ("#" .. drops[i])
            local pct = drops[i + 1] / 10
            local txt = pct >= 10 and tostring(math.floor(pct + 0.5)) or string.format("%.1f", pct)
            tooltip:AddDoubleLine("  " .. name, string.format(WK.T("%s %% · %d butins"), txt, drops[i + 2]),
                1, 1, 1, 1, 1, 1)
        end
    end
    -- marchands qui le vendent dans WoW Forever (Modules/Vendors.lua, données ForeverDB)
    local Vd = WK.modules.Vendors
    if Vd and Vd.AddTooltip and ui.tooltipVendors ~= false and #Vd:Sources(itemID) > 0 then
        if not any then tooltip:AddLine(" "); tooltip:AddLine(WK:Tag()); any = true end
        Vd:AddTooltip(tooltip, itemID)
    end
    -- prix relevés par notre scan de l'HV (Modules/AHScan.lua)
    local S = WK.modules.AHScan
    local scanned = false
    if S and S.AddTooltip then
        scanned = S:AddTooltip(tooltip, itemID, function()
            if not any then tooltip:AddLine(" "); tooltip:AddLine(WK:Tag()); any = true end
        end)
    end
    -- prix réellement obtenu à l'HV (Modules/Auction.lua, d'après les factures)
    local Au = WK.modules.Auction
    if Au and Au.AddSoldTooltip and Au:AddSoldTooltip(tooltip, itemID, function()
        if not any then tooltip:AddLine(" "); tooltip:AddLine(WK:Tag()); any = true end
    end) then any = true end
    -- recettes de tes persos : qui peut le fabriquer, à quoi il sert (Modules/Recipes.lua)
    if R and R.AddCraftTooltip and R:AddCraftTooltip(tooltip, itemID, function()
        if not any then tooltip:AddLine(" "); tooltip:AddLine(WK:Tag()); any = true end
    end) then any = true end
    local V = WK.modules.Value
    if V and V:ShowBoth() then
        local ah, vendor = V:Prices(itemID)
        if ah or vendor > 0 then
            if not any then tooltip:AddLine(" "); tooltip:AddLine(WK:Tag()); any = true end
            if ah and not scanned then tooltip:AddDoubleLine(WK.T("Prix HV (unité)"), WK:FormatMoney(ah), 0.8, 0.8, 0.8, 1, 1, 1) end
            if vendor > 0 then tooltip:AddDoubleLine(WK.T("Prix marchand (unité)"), WK:FormatMoney(vendor), 0.8, 0.8, 0.8, 1, 1, 1) end
        end
    end
    if any then tooltip:Show() end
end

-- Numéro de l'objet (et du sort, plus bas) en bas de l'infobulle (Options > Infobulles > Objets,
-- « Numéro de l'objet ou du sort », coupé d'office)
local function onTooltipId(tooltip, data)
    if tooltip ~= _G.GameTooltip and tooltip ~= _G.ItemRefTooltip then return end
    if not WK.DB.global.settings.ui.tooltipItemId then return end
    local itemID = tooltipItemID(tooltip, data)
    if not itemID then return end
    tooltip:AddLine(DIM .. "ID : " .. itemID .. "|r")
    tooltip:Show()
end

if TooltipDataProcessor and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, onTooltip)
    _G.TooltipDataProcessor.AddTooltipPostCall(_G.Enum.TooltipDataType.Item,
        function(tt, d) pcall(onTooltipId, tt, d) end)
    -- même option pour les sorts et les effets (buffs) : « ID du sort »
    local function onSpellId(tooltip, data)
        if tooltip ~= _G.GameTooltip and tooltip ~= _G.ItemRefTooltip then return end
        if not WK.DB.global.settings.ui.tooltipItemId then return end
        local id = data and data.id
        if type(id) ~= "number" or (_G.issecretvalue and _G.issecretvalue(id)) then return end
        tooltip:AddLine(DIM .. WK.T("ID du sort : ") .. id .. "|r")
        tooltip:Show()
    end
    local TT = _G.Enum.TooltipDataType
    for _, k in ipairs({ "Spell", "UnitAura" }) do
        if TT[k] then _G.TooltipDataProcessor.AddTooltipPostCall(TT[k], function(tt, d) pcall(onSpellId, tt, d) end) end
    end
else
    GameTooltip:HookScript("OnTooltipSetItem", onTooltip)
    if ItemRefTooltip then ItemRefTooltip:HookScript("OnTooltipSetItem", onTooltip) end
end

-- Tri des sacs par la fonction du jeu (comme le bouton de tri des sacs).
local sortWarned = false
function M:SortBags()
    local f = (C_Container and C_Container.SortBags) or SortBags
    if f then
        local ok = pcall(f)
        return ok
    end
    if not sortWarned then
        sortWarned = true
        WK:Print(WK.T("Le tri des sacs n'existe pas sur ce client."))
    end
    return false
end

---------------------------------------------------------------------------
-- Objets oubliés en banque : qui dorment depuis au moins N jours et ont de la valeur.
-- Renvoie la liste { itemID, n, since, key ("warband" pour la banque de bataillon), value }
-- et la date du plus ancien suivi (avant, on ne sait pas).
---------------------------------------------------------------------------
function M:Forgotten(days)
    local limit = time() - (days or 14) * 86400
    local V = WK.modules.Value
    local out, trackedSince = {}, nil
    local function scanAges(ages, key)
        for id, e in pairs(ages or {}) do
            if not trackedSince or e.since < trackedSince then trackedSince = e.since end
            if e.since <= limit then
                local value = V:Price(id) * e.n
                if value > 0 then table.insert(out, { itemID = id, n = e.n, since = e.since, key = key, value = value }) end
            end
        end
    end
    for key, c in pairs(WK.DB.global.characters) do scanAges(c.bankAges, key) end
    local wb = WK.DB.global.warbank
    if wb then scanAges(wb.ages, "warband") end
    table.sort(out, function(a, b) return a.value > b.value end)
    return out, trackedSince
end

---------------------------------------------------------------------------
-- Objets dispersés : composants, consommables, gemmes et recettes présents chez plusieurs persos
-- (sacs, banque, courrier). Perso conseillé : celui d'une règle d'envoi existante, sinon celui
-- qui en a le plus. { itemID, total, holders = { {key, n} }, target, rule }
---------------------------------------------------------------------------
local GROUPABLE = { [0] = true, [3] = true, [5] = true, [7] = true, [9] = true }
function M:Spread()
    local byItem = {}
    for key, c in pairs(WK.DB.global.characters) do
        local own = {}
        for _, list in ipairs({ c.bags, c.bank, c.mailbox and c.mailbox.items }) do
            for id, n in pairs(list or {}) do own[id] = (own[id] or 0) + n end
        end
        for id, n in pairs(own) do
            local e = byItem[id] or { itemID = id, total = 0, holders = {} }
            e.total = e.total + n
            table.insert(e.holders, { key = key, n = n })
            byItem[id] = e
        end
    end
    local Mail, Rules = WK.modules.Mail, WK.modules.Rules
    local out = {}
    for id, e in pairs(byItem) do
        local class = Rules:ItemClass(id)
        if #e.holders >= 2 and class and GROUPABLE[class] and not NO_TOOLTIP[id] then
            table.sort(e.holders, function(a, b) return a.n > b.n end)
            local rule = WK.DB.global.mail.rules[id]
            local ruleChar = rule and select(2, Mail:Resolve(rule.to))
            e.rule = rule
            e.target = ruleChar or e.holders[1].key
            table.insert(out, e)
        end
    end
    table.sort(out, function(a, b)
        if #a.holders ~= #b.holders then return #a.holders > #b.holders end
        return a.total > b.total
    end)
    return out
end
