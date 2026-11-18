local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Hôtel des ventes façon Auctionator : quatre onglets ajoutés en bas de la fenêtre de l'HV du jeu
-- (AuctionHouseFrame), à côté des siens. Un onglet à nous recouvre le contenu de la fenêtre ; un onglet
-- du jeu le referme.
--   Vente      : objets des sacs vendables (liés, verrouillés à la main et objets de quête cachés) et ceux que
--                le Rangement met en vente sur ce perso ; prix proposé (plus bas des autres moins l'écart, sinon
--                prix du scan), quantité, durée, dépôt ; « Mettre en vente » puis objet suivant ; enchères en cours
--                de l'objet (la plus basse et la tienne surlignées) ; tes derniers prix et ventes.
--   Achat      : listes d'achat (Modules/AHScan.lua) cherchées d'un coup, plus bas et quantité en vente par objet,
--                « Acheter N » (demande de prix puis confirmation, un clic chacun : le jeu l'exige).
--   Annulation : tes enchères (Modules/AHSell.lua), sous-cotées en rouge, « Annuler la suivante ».
--   Scan       : le panneau d'avant (scan, alertes de prix, listes, ventes), posé dans l'onglet.
-- Réglage AHScan:Config().tabs (sinon l'ancien panneau sur le côté).
local S = WK.modules.AHScan
local A = WK.modules.AHSell
local AH = function() return C_AuctionHouse end
local THROTTLE = 1.1

local function cfg()
    local c = S:Config()
    if c.tabs == nil then c.tabs = true end
    c.postDur = c.postDur or 2
    c.posts = c.posts or {}
    return c
end
local function money(v) return v and WK:FormatMoney(v) or "-" end
local function itemIcon(id)
    local f = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
    return (f and f(id)) or "Interface\\Icons\\INV_Misc_QuestionMark"
end
local function isCommodity(id)
    local a = AH()
    if a and a.GetItemCommodityStatus and Enum and Enum.ItemCommodityStatus then
        local ok, st = pcall(a.GetItemCommodityStatus, id)
        if ok and st == Enum.ItemCommodityStatus.Item then return false end
    end
    return true
end
local function itemKeyOf(id)
    local a = AH()
    if a and a.MakeItemKey then
        local ok, k = pcall(a.MakeItemKey, id)
        if ok then return k end
    end
    return { itemID = id, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = 0 }
end
local function sorts()
    local po = Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price or 0
    return { { sortOrder = po, reverseSort = false } }
end

---------------------------------------------------------------------------
-- Recherches : une file commune (vente, achat), une recherche toutes les THROTTLE s
-- results[id] = { at, rows = { { unit, qty, mine } } } (prix à l'unité, du moins cher au plus cher)
---------------------------------------------------------------------------
local results, queue, pending, pendingAt = {}, {}, nil, 0
local view -- fenêtre des onglets (pour repeindre à l'arrivée des résultats)
local function readResults(id)
    local a = AH()
    if not a then return end
    local rows = {}
    if isCommodity(id) then
        local okn, n = pcall(a.GetNumCommoditySearchResults, id)
        for i = 1, math.min(okn and n or 0, 40) do
            local ok, r = pcall(a.GetCommoditySearchResultInfo, id, i)
            if ok and r and r.unitPrice then table.insert(rows, { unit = r.unitPrice, qty = r.quantity or 1, mine = r.containsOwnerItem and true or false }) end
        end
    else
        local key = itemKeyOf(id)
        local okn, n = pcall(a.GetNumItemSearchResults, key)
        for i = 1, math.min(okn and n or 0, 40) do
            local ok, r = pcall(a.GetItemSearchResultInfo, key, i)
            if ok and r and r.buyoutAmount then
                local q = r.quantity or 1
                table.insert(rows, { unit = math.floor(r.buyoutAmount / math.max(1, q)), qty = q, mine = r.containsOwnerItem and true or false, auctionID = r.auctionID })
            end
        end
    end
    table.sort(rows, function(x, y) return x.unit < y.unit end)
    results[id] = { at = GetTime(), rows = rows }
end
local function pump()
    if pending and GetTime() - pendingAt < 5 then return end
    pending = nil
    local id = table.remove(queue, 1)
    if not id then return end
    local a = AH()
    if not (a and a.SendSearchQuery) then return end
    pending, pendingAt = id, GetTime()
    if not pcall(a.SendSearchQuery, itemKeyOf(id), sorts(), true) then pending = nil end
end
local function search(id, first)
    if not id then return end
    for i = #queue, 1, -1 do if queue[i] == id then table.remove(queue, i) end end
    if first then table.insert(queue, 1, id) else table.insert(queue, id) end
end
local function onResults(id)
    if not id then return end
    pcall(readResults, id)
    if pending == id then pending = nil end
    if view and view:IsShown() then view:Refresh() end
end
WK:On("COMMODITY_SEARCH_RESULTS_UPDATED", function(id) onResults(id) end)
WK:On("ITEM_SEARCH_RESULTS_UPDATED", function(key) onResults(type(key) == "table" and key.itemID or key) end)
local function lowestOther(id)
    local r = results[id]
    if not r then return nil end
    for _, row in ipairs(r.rows) do if not row.mine then return row.unit end end
    return nil, r.rows[1] and r.rows[1].mine
end
local function available(id)
    local r = results[id]
    if not r then return nil end
    local n = 0
    for _, row in ipairs(r.rows) do if not row.mine then n = n + row.qty end end
    return n
end

---------------------------------------------------------------------------
-- Sacs : objets vendables
---------------------------------------------------------------------------
local function sellable(bag, slot, id, bound)
    if bound then return false end
    local IL = WK.modules.ItemLock
    if IL and IL:Reason(id) == "manual" then return false end
    local _, _, q, _, _, _, _, _, _, _, _, classID = WK.GetItemInfo(id)
    if q == 0 or classID == 12 then return false end
    local a = AH()
    if a and a.IsSellItemValid and ItemLocation and ItemLocation.CreateFromBagAndSlot then
        local ok, v = pcall(a.IsSellItemValid, ItemLocation:CreateFromBagAndSlot(bag, slot), false)
        if ok and v == false then return false end
    end
    return true
end
local function bagItems()
    local by, list = {}, {}
    for bag = 0, 4 do
        for slot = 1, WK.Container.NumSlots(bag) or 0 do
            local id, count, _, bound = WK.Container.Info(bag, slot)
            if id and sellable(bag, slot, id, bound) then
                local e = by[id]
                if not e then e = { id = id, count = 0, bag = bag, slot = slot }; by[id] = e; table.insert(list, e) end
                e.count = e.count + (count or 1)
            end
        end
    end
    for _, e in ipairs(list) do e.value = (S:Price(e.id) or 0) * e.count end
    table.sort(list, function(x, y)
        if x.value ~= y.value then return x.value > y.value end
        return x.id < y.id
    end)
    return list, by
end
-- objets que le Rangement met en vente sur ce perso (perso HV)
local function stashSell()
    local St = WK.modules.Stash
    if not St then return {} end
    local ok, r = pcall(St.Route, St)
    local me = WK:CharKey()
    local out = {}
    if ok and r and r.sell then
        for _, e in ipairs(r.sell.list or {}) do if (e.from or {})[me] then out[e.id] = true end end
    end
    return out
end

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------
local TABS = { { "buy", "Achat" }, { "sell", "Vente" }, { "cancel", "Annulation" }, { "scan", "Scan" } }

local function panelBox(parent, title)
    local b = CreateFrame("Frame", nil, parent)
    UI:Panel(b, 10, C.surface, C.border)
    b.title = UI:Text(b, 12); b.title:SetPoint("TOPLEFT", 10, -9)
    b.title:SetText(T(title))
    b.sub = UI:Text(b, 10, C.muted); b.sub:SetPoint("LEFT", b.title, "RIGHT", 8, 0)
    return b
end
local function textRow(parent, h)
    local r = CreateFrame("Button", nil, parent)
    r:SetHeight(h or 22)
    r.hl = r:CreateTexture(nil, "BACKGROUND"); r.hl:SetAllPoints()
    r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(18, 18); r.icon:SetPoint("LEFT", 4, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.a = UI:Text(r, 11); r.a:SetPoint("LEFT", 28, 0); r.a:SetJustifyH("LEFT")
    if r.a.SetWordWrap then r.a:SetWordWrap(false) end
    r.b = UI:Text(r, 11); r.b:SetJustifyH("RIGHT")
    r.c = UI:Text(r, 11, C.muted); r.c:SetJustifyH("RIGHT")
    r.d = UI:Text(r, 11, C.muted); r.d:SetJustifyH("RIGHT")
    return r
end

local function build(host)
    local f = CreateFrame("Frame", "WarbandKeeperAHTabs", host)
    f:SetPoint("TOPLEFT", host, "TOPLEFT", 6, -24)
    f:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -6, 4)
    -- au-dessus de tout le contenu de la fenêtre du jeu (certains de ses cadres sont très hauts)
    f:SetFrameLevel(math.min(9000, host:GetFrameLevel() + 300))
    f:EnableMouse(true)
    UI:Panel(f, 8, { C.bg[1], C.bg[2], C.bg[3], 0.99 }, C.border)
    f:Hide()
    f.head = UI:Text(f, 13); f.head:SetPoint("TOPLEFT", 14, -10)
    f.headSub = UI:Text(f, 10, C.muted); f.headSub:SetPoint("LEFT", f.head, "RIGHT", 10, 0)
    f.scanBtn = UI:Button(f, "Scanner", 90, 22, "secondary")
    f.scanBtn:SetPoint("TOPRIGHT", -10, -6)
    f.scanBtn:SetScript("OnClick", function() S:Start() end)
    f.scanInfo = UI:Text(f, 10, C.muted); f.scanInfo:SetPoint("RIGHT", f.scanBtn, "LEFT", -8, 0)
    f.views = {}

    -- onglets à nous, après ceux du jeu
    f.tabs = {}
    local last
    for i, def in ipairs(TABS) do
        local b = UI:Button(host, def[2], nil, 24, "secondary")
        b.key = def[1]
        if i == 1 then
            local gameTabs = host.Tabs
            local anchor = gameTabs and gameTabs[#gameTabs]
            if anchor then b:SetPoint("LEFT", anchor, "RIGHT", 18, 0) else b:SetPoint("TOPLEFT", host, "BOTTOMLEFT", 300, 2) end
        else
            b:SetPoint("LEFT", last, "RIGHT", 4, 0)
        end
        b:SetFrameLevel(math.min(9000, host:GetFrameLevel() + 310))
        b:SetScript("OnClick", function() f:Open(def[1]) end)
        f.tabs[def[1]] = b
        last = b
    end

    function f:Open(key)
        cfg().ahTab = key
        self.tab = key
        for k, b in pairs(self.tabs) do if b.SetStyle then b:SetStyle(k == key and "primary" or "secondary") end end
        for k, v in pairs(self.views) do v:SetShown(k == key) end
        -- les onglets du jeu ne paraissent plus choisis
        if PanelTemplates_DeselectTab then
            for _, tb in ipairs(host.Tabs or {}) do pcall(PanelTemplates_DeselectTab, tb) end
        end
        -- onglet Scan : le panneau a déjà son bouton et son heure
        self.scanBtn:SetShown(key ~= "scan"); self.scanInfo:SetShown(key ~= "scan")
        self:Show()
        if key == "cancel" then A:Query() end
        if key == "scan" and UI.AHPanelEmbed then UI:AHPanelEmbed(self.views.scan) end
        self:Refresh()
    end
    function f:Close()
        self:Hide()
        -- l'onglet du jeu en cours reprend son air choisi
        if PanelTemplates_SetTab and host.selectedTab then pcall(PanelTemplates_SetTab, host, host.selectedTab) end
        for _, b in pairs(self.tabs) do if b.SetStyle then b:SetStyle("secondary") end end
    end

    -----------------------------------------------------------------------
    -- Vente
    -----------------------------------------------------------------------
    local sv = CreateFrame("Frame", nil, f)
    sv:SetPoint("TOPLEFT", 8, -34); sv:SetPoint("BOTTOMRIGHT", -8, 8)
    f.views.sell = sv
    sv.bags = panelBox(sv, "Mes sacs")
    sv.bags:SetPoint("TOPLEFT"); sv.bags:SetPoint("BOTTOMLEFT"); sv.bags:SetWidth(262)
    sv.bags.sub:SetText(T("à vendre"))
    sv.slots = {}
    local SLOT, GAP, COLS = 32, 4, 7
    for i = 1, 42 do
        local b = CreateFrame("Button", nil, sv.bags)
        b:SetSize(SLOT, SLOT)
        b:SetPoint("TOPLEFT", 10 + ((i - 1) % COLS) * (SLOT + GAP), -30 - math.floor((i - 1) / COLS) * (SLOT + GAP))
        b.edge = UI:Rounded(b, 6, 0, "BACKGROUND", 1)
        b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetPoint("TOPLEFT", 2, -2); b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.n = UI:Text(b, 10, C.text, "OVERLAY"); b.n:SetFont(UI.FONT, 10, "OUTLINE"); b.n:SetPoint("BOTTOMRIGHT", -1, 1)
        b.tag = UI:Text(b, 8, C.gold, "OVERLAY"); b.tag:SetFont(UI.FONT, 8, "OUTLINE"); b.tag:SetPoint("TOPLEFT", 2, -1)
        b:SetScript("OnClick", function(s) if s.e then sv:Select(s.e.id) end end)
        b:SetScript("OnEnter", function(s)
            if not s.e then return end
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            if GameTooltip.SetItemByID then GameTooltip:SetItemByID(s.e.id) end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:Hide()
        sv.slots[i] = b
    end
    sv.bagNote = UI:Text(sv.bags, 10, C.dim); sv.bagNote:SetPoint("BOTTOMLEFT", 10, 10); sv.bagNote:SetPoint("RIGHT", -10, 0)
    sv.bagNote:SetJustifyH("LEFT")
    if sv.bagNote.SetWordWrap then sv.bagNote:SetWordWrap(true) end
    sv.bagNote:SetText(T("Liés, verrouillés à la main et objets de quête cachés · « HV » : prix connu · étoile : à vendre d'après le Rangement"))

    sv.right = panelBox(sv, "En vente")
    sv.right:SetPoint("TOPRIGHT"); sv.right:SetPoint("BOTTOMRIGHT"); sv.right:SetWidth(250)
    sv.lrows = {}
    for i = 1, 9 do
        local r = textRow(sv.right, 20)
        r:SetPoint("TOPLEFT", 6, -28 - (i - 1) * 20); r:SetPoint("TOPRIGHT", -6, -28 - (i - 1) * 20)
        r.icon:Hide(); r.a:SetPoint("LEFT", 6, 0)
        r.b:SetPoint("RIGHT", -60, 0); r.c:SetPoint("RIGHT", -6, 0); r.c:SetWidth(50)
        sv.lrows[i] = r
    end
    sv.hist = UI:Text(sv.right, 10, C.muted); sv.hist:SetPoint("TOPLEFT", 10, -220); sv.hist:SetPoint("RIGHT", -10, 0)
    sv.hist:SetJustifyH("LEFT"); sv.hist:SetJustifyV("TOP")
    if sv.hist.SetSpacing then sv.hist:SetSpacing(3) end

    sv.mid = panelBox(sv, "")
    sv.mid:SetPoint("TOPLEFT", sv.bags, "TOPRIGHT", 8, 0); sv.mid:SetPoint("BOTTOMRIGHT", sv.right, "BOTTOMLEFT", -8, 0)
    sv.mid.title:Hide()
    sv.itemIcon = sv.mid:CreateTexture(nil, "ARTWORK"); sv.itemIcon:SetSize(36, 36); sv.itemIcon:SetPoint("TOPLEFT", 12, -12)
    sv.itemIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    sv.itemName = UI:Text(sv.mid, 13); sv.itemName:SetPoint("TOPLEFT", 56, -14); sv.itemName:SetPoint("RIGHT", -12, 0)
    sv.itemName:SetJustifyH("LEFT")
    if sv.itemName.SetWordWrap then sv.itemName:SetWordWrap(false) end
    sv.itemSub = UI:Text(sv.mid, 10, C.muted); sv.itemSub:SetPoint("TOPLEFT", 56, -32)
    local function label(txt, y)
        local l = UI:Text(sv.mid, 9, C.dim); l:SetPoint("TOPLEFT", 12, y); l:SetText(UI:Upper(T(txt)))
        return l
    end
    label("Prix unitaire", -62)
    sv.price = UI:Input(sv.mid, 160, 28, "ex. 1po 61pa 99", nil)
    sv.price:SetPoint("TOPLEFT", 12, -74)
    sv.priceHint = UI:Text(sv.mid, 10, C.muted); sv.priceHint:SetPoint("TOPLEFT", 12, -106); sv.priceHint:SetPoint("RIGHT", -12, 0)
    sv.priceHint:SetJustifyH("LEFT")
    label("Quantité", -126)
    sv.qty = UI:Input(sv.mid, 70, 28, "1", nil)
    sv.qty:SetPoint("TOPLEFT", 12, -138)
    sv.max = UI:Button(sv.mid, "max", 46, 24, "ghost"); sv.max:SetPoint("LEFT", sv.qty, "RIGHT", 6, 0)
    label("Durée", -176)
    sv.dur = UI:Segmented(sv.mid, { { 1, "12 h" }, { 2, "24 h" }, { 3, "48 h" } }, function(v) cfg().postDur = v; sv:Update() end, 24)
    sv.dur:SetPoint("TOPLEFT", 12, -188)
    sv.total = UI:Text(sv.mid, 12); sv.total:SetPoint("TOPLEFT", 12, -222); sv.total:SetPoint("RIGHT", -12, 0); sv.total:SetJustifyH("LEFT")
    sv.deposit = UI:Text(sv.mid, 10, C.muted); sv.deposit:SetPoint("TOPLEFT", 12, -240)
    sv.post = UI:Button(sv.mid, "Mettre en vente", nil, 32, "primary")
    sv.post:SetPoint("BOTTOMLEFT", 12, 12); sv.post:SetPoint("BOTTOMRIGHT", -96, 12)
    sv.skip = UI:Button(sv.mid, "Passer", 76, 32, "secondary"); sv.skip:SetPoint("BOTTOMRIGHT", -12, 12)
    sv.empty = UI:Text(sv.mid, 11, C.muted); sv.empty:SetPoint("CENTER")
    sv.empty:SetText(T("Choisis un objet dans tes sacs."))

    local function priceValue() return A.ParsePrice(sv.price:GetText()) end
    local function qtyValue() return math.max(1, math.floor(tonumber(sv.qty:GetText()) or 1)) end
    -- prix tapé à la main : on n'y touche plus (jusqu'à l'objet suivant)
    sv.price.onChange = function(_, user) if user then sv.userPrice = true end sv:Update() end
    sv.qty.onChange = function() sv:Update() end
    sv.max:SetScript("OnClick", function() if sv.e then sv.qty:SetText(tostring(sv.e.count)); sv:Update() end end)

    function sv:Select(id)
        local _, by = bagItems()
        local e = by[id]
        self.e = e
        self.id = id
        self.userPrice = false
        if e then
            self.qty:SetText(tostring(e.count))
            search(id, true)
            pump()
        end
        self:Refresh()
    end
    -- prix proposé : plus bas des autres moins l'écart ; tu es déjà le plus bas : ton prix ; sinon le scan
    function sv:Suggest()
        local id = self.id
        if not id or self.userPrice then return end
        local low, mineFirst = lowestOther(id)
        local c = A.Config and A.Config() or {}
        local under = c.undercut or 1
        local p, why
        if low then p, why = math.max(1, low - under), string.format(T("plus bas %s moins %s"), money(low), money(under))
        elseif mineFirst then p, why = results[id].rows[1].unit, T("tu es déjà le moins cher")
        elseif S:Price(id) then p, why = math.max(1, S:Price(id) - under), T("prix du scan")
        end
        if p then
            local txt = WK:FormatMoney(p):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            if txt ~= self.price:GetText() then self.price:SetText(txt) end
        end
        self.why = why or T("aucun prix connu : à toi de le fixer")
    end
    function sv:Update()
        local id, e = self.id, self.e
        if not (id and e) then return end
        local unit, qty = priceValue(), math.min(qtyValue(), e.count)
        self.priceHint:SetText((unit and money(unit) .. "  ·  " or "") .. (self.why or ""))
        self.total:SetText(unit and (T("Total") .. " : " .. money(unit * qty)) or "")
        local dep
        local a = AH()
        if a then
            if isCommodity(id) and a.CalculateCommodityDeposit then
                local ok, v = pcall(a.CalculateCommodityDeposit, id, cfg().postDur, qty); if ok then dep = v end
            elseif a.CalculateItemDeposit and ItemLocation then
                local ok, v = pcall(a.CalculateItemDeposit, ItemLocation:CreateFromBagAndSlot(e.bag, e.slot), cfg().postDur, qty); if ok then dep = v end
            end
        end
        self.deposit:SetText(dep and (T("Dépôt") .. " : " .. money(dep)) or "")
        self.post:SetEnabled(unit ~= nil and unit > 0)
    end
    local function nextItem()
        local list = bagItems()
        for i, x in ipairs(list) do
            if x.id == sv.id then
                local n = list[i + 1] or list[1]
                if n and n.id ~= sv.id then sv:Select(n.id) else sv.id, sv.e = nil, nil; sv:Refresh() end
                return
            end
        end
        if list[1] then sv:Select(list[1].id) else sv.id, sv.e = nil, nil; sv:Refresh() end
    end
    sv.skip:SetScript("OnClick", nextItem)
    sv.post:SetScript("OnClick", function()
        local id, e = sv.id, sv.e
        local unit, qty = priceValue(), qtyValue()
        if not (id and e and unit) then return end
        qty = math.min(qty, e.count)
        local a = AH()
        local loc = ItemLocation and ItemLocation:CreateFromBagAndSlot(e.bag, e.slot)
        local ok, err
        if isCommodity(id) and a and a.PostCommodity then
            ok, err = pcall(a.PostCommodity, loc, cfg().postDur, qty, unit)
        elseif a and a.PostItem then
            ok, err = pcall(a.PostItem, loc, cfg().postDur, qty, nil, unit * qty)
        end
        if not ok then WK:Print(T("Mise en vente refusée par le jeu.") .. (err and (" (" .. tostring(err) .. ")") or "")) return end
        local posts = cfg().posts
        posts[id] = posts[id] or {}
        table.insert(posts[id], 1, { at = time(), unit = unit, qty = qty })
        while #posts[id] > 5 do table.remove(posts[id]) end
        WK:Print(string.format(T("Mis en vente : %d %s à %s l'unité."), qty, WK.GetItemInfo(id) or "?", money(unit)))
        C_Timer.After(0.6, nextItem)
    end)

    function sv:Refresh()
        local list = bagItems()
        local marked = stashSell()
        for i, b in ipairs(self.slots) do
            local e = list[i]
            b.e = e
            if e then
                b.icon:SetTexture(itemIcon(e.id))
                b.n:SetText(e.count > 1 and e.count or "")
                b.tag:SetText(marked[e.id] and "*" or (S:Price(e.id) and "HV" or ""))
                local r1, g1, b1 = UI:Accent()
                if e.id == self.id then b.edge:SetColor(r1, g1, b1, 1) else b.edge:SetColor(C.border[1], C.border[2], C.border[3], 1) end
                b:Show()
            else
                b:Hide()
            end
        end
        self.bags.sub:SetText(string.format(T("%d à vendre"), #list))
        if self.id and not self.e then self.id = nil end
        local id = self.id
        local has = id ~= nil
        for _, w in ipairs({ self.itemIcon, self.itemName, self.itemSub, self.price, self.priceHint, self.qty, self.max, self.dur, self.total, self.deposit, self.post, self.skip }) do w:SetShown(has) end
        self.empty:SetShown(not has)
        for _, r in ipairs(self.lrows) do r:Hide() end
        self.right.sub:SetText(has and (WK.GetItemInfo(id) or "") or "")
        if not has then self.hist:SetText(""); return end
        local name, _, quality = WK.GetItemInfo(id)
        self.itemIcon:SetTexture(itemIcon(id))
        local qr, qg, qb = 1, 1, 1
        if quality and GetItemQualityColor then qr, qg, qb = GetItemQualityColor(quality) end
        self.itemName:SetText(name or ("#" .. id)); self.itemName:SetTextColor(qr, qg, qb)
        self.itemSub:SetText(string.format(T("%d dans tes sacs"), self.e.count) .. (marked[id] and ("  ·  " .. T("à vendre d'après le Rangement")) or ""))
        self.dur:Select(cfg().postDur)
        self:Suggest()
        self:Update()
        -- enchères en cours
        local r = results[id]
        if not r then
            local row = self.lrows[1]
            row.a:SetText(UI:Hex(C.muted) .. T("recherche…") .. "|r"); row.b:SetText(""); row.c:SetText(""); row.hl:SetColorTexture(0, 0, 0, 0); row:Show()
        else
            local firstOther = true
            for i, row in ipairs(self.lrows) do
                local x = r.rows[i]
                if x then
                    row.a:SetText(money(x.unit))
                    row.b:SetText(tostring(x.qty))
                    row.c:SetText(x.mine and T("toi") or "")
                    local ar, ag, ab = UI:Accent()
                    if x.mine then row.hl:SetColorTexture(ar, ag, ab, 0.12); row.c:SetTextColor(ar, ag, ab)
                    elseif firstOther then row.hl:SetColorTexture(C.positive[1], C.positive[2], C.positive[3], 0.10); firstOther = false
                    else row.hl:SetColorTexture(0, 0, 0, 0) end
                    row:Show()
                end
            end
            if #r.rows == 0 then
                local row = self.lrows[1]
                row.a:SetText(UI:Hex(C.muted) .. T("personne n'en vend") .. "|r"); row.b:SetText(""); row.c:SetText(""); row.hl:SetColorTexture(0, 0, 0, 0); row:Show()
            end
        end
        -- tes derniers prix (mises en vente) et ventes (factures du courrier, Modules/Auction.lua)
        local lines = { UI:Hex(C.text) .. T("Tes prix") .. "|r" }
        for _, p in ipairs(cfg().posts[id] or {}) do
            table.insert(lines, string.format("%s  ·  %s  ·  x%d", date("%d/%m", p.at), money(p.unit), p.qty))
        end
        local log = WK.DB.global.auction and WK.DB.global.auction.log or {}
        local sold = 0
        for i = #log, 1, -1 do
            local l = log[i]
            if l.kind == "sale" and l.item == name and sold < 3 then
                sold = sold + 1
                table.insert(lines, string.format(T("vendu %s  ·  %s  ·  x%d"), date("%d/%m", l.t), money(math.floor((l.gross or 0) / math.max(1, l.count or 1))), l.count or 1))
            end
        end
        if #lines == 1 then table.insert(lines, T("pas encore vendu par l'addon")) end
        self.hist:SetText(table.concat(lines, "\n"))
    end

    -----------------------------------------------------------------------
    -- Achat
    -----------------------------------------------------------------------
    local bv = CreateFrame("Frame", nil, f)
    bv:SetPoint("TOPLEFT", 8, -34); bv:SetPoint("BOTTOMRIGHT", -8, 8)
    f.views.buy = bv
    bv.lists = panelBox(bv, "Listes")
    bv.lists:SetPoint("TOPLEFT"); bv.lists:SetPoint("BOTTOMLEFT"); bv.lists:SetWidth(230)
    bv.lrows = {}
    for i = 1, 10 do
        local r = textRow(bv.lists, 24)
        r:SetPoint("TOPLEFT", 6, -28 - (i - 1) * 26); r:SetPoint("TOPRIGHT", -6, -28 - (i - 1) * 26)
        r.icon:Hide(); r.a:SetPoint("LEFT", 8, 0); r.a:SetPoint("RIGHT", -40, 0)
        r.b:SetPoint("RIGHT", -8, 0)
        r:SetScript("OnClick", function(s) if s.name then cfg().curList = s.name; bv:Refresh() end end)
        bv.lrows[i] = r
    end
    bv.searchAll = UI:Button(bv.lists, "Tout chercher", nil, 28, "primary")
    bv.searchAll:SetPoint("BOTTOMLEFT", 10, 44); bv.searchAll:SetPoint("BOTTOMRIGHT", -10, 44)
    bv.buyAll = UI:Button(bv.lists, "Tout acheter", nil, 28, "secondary")
    bv.buyAll:SetPoint("BOTTOMLEFT", 10, 10); bv.buyAll:SetPoint("BOTTOMRIGHT", -10, 10)
    bv.main = panelBox(bv, "")
    bv.main:SetPoint("TOPLEFT", bv.lists, "TOPRIGHT", 8, 0); bv.main:SetPoint("BOTTOMRIGHT")
    bv.total = UI:Text(bv.main, 11, C.muted); bv.total:SetPoint("TOPRIGHT", -12, -10)
    local cols = { { "Objet", 34 }, { "Besoin", -260 }, { "Plus bas", -180 }, { "Dispo", -110 } }
    for _, cdef in ipairs(cols) do
        local h = UI:Text(bv.main, 9, C.dim)
        if cdef[2] > 0 then h:SetPoint("TOPLEFT", cdef[2], -30) else h:SetPoint("TOPRIGHT", cdef[2], -30) end
        h:SetText(UI:Upper(T(cdef[1])))
    end
    bv.irows = {}
    for i = 1, 12 do
        local r = textRow(bv.main, 26)
        r:SetPoint("TOPLEFT", 6, -44 - (i - 1) * 28); r:SetPoint("TOPRIGHT", -6, -44 - (i - 1) * 28)
        r.a:SetPoint("RIGHT", -300, 0)
        r.b:SetPoint("RIGHT", -260, 0); r.b:SetWidth(60)
        r.c:SetPoint("RIGHT", -180, 0); r.c:SetWidth(90); r.c:SetTextColor(C.text[1], C.text[2], C.text[3])
        r.d:SetPoint("RIGHT", -110, 0); r.d:SetWidth(60)
        r.btn = UI:Button(r, "Acheter", 100, 22, "primary"); r.btn:SetPoint("RIGHT", -2, 0)
        r:SetScript("OnEnter", function(s)
            if not s.id then return end
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            if GameTooltip.SetItemByID then GameTooltip:SetItemByID(s.id) end
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        r.btn:SetScript("OnClick", function(s)
            local row = s:GetParent()
            local id, need = row.id, row.need
            if not id then return end
            if not isCommodity(id) then S:SearchItem(id) return end
            local b = S.buy
            local a = AH()
            if b and b.id == id and b.phase == "confirm" then
                b.phase = "wait"
                if not pcall(a.ConfirmCommoditiesPurchase, id, b.qty) then b.phase = nil; WK:Print(T("Achat refusé par le jeu.")) end
            elseif not (b and (b.phase == "quote" or b.phase == "wait")) then
                S.buy = { list = cfg().curList, id = id, qty = need, phase = "quote", skip = {}, spent = 0, count = 0 }
                if not pcall(a.StartCommoditiesPurchase, id, need) then S.buy = nil; WK:Print(T("Le jeu a refusé la demande de prix.")) end
            end
            bv:Refresh()
        end)
        bv.irows[i] = r
    end
    bv.empty = UI:Text(bv.main, 11, C.muted); bv.empty:SetPoint("CENTER")
    bv.searchAll:SetScript("OnClick", function()
        local l = S:GetList(cfg().curList)
        for _, it in ipairs(l and l.items or {}) do search(it[1]) end
        pump()
    end)
    bv.buyAll:SetScript("OnClick", function() S:BuyStep(); bv:Refresh() end)
    function bv:Refresh()
        local names, lists = S:Lists()
        local cur = cfg().curList
        if not (cur and lists[cur]) then cur = names[1]; cfg().curList = cur end
        local ar, ag, ab = UI:Accent()
        for i, r in ipairs(self.lrows) do
            local n = names[i]
            r.name = n
            if n then
                r.a:SetText(n); r.b:SetText(tostring(#(lists[n].items or {})))
                r.hl:SetColorTexture(ar, ag, ab, n == cur and 0.14 or 0)
                r:Show()
            else r:Hide() end
        end
        self.searchAll:SetEnabled(cur ~= nil); self.buyAll:SetEnabled(cur ~= nil)
        local b = S.buy
        self.buyAll:SetLabel((b and b.phase == "confirm") and string.format(T("Confirmer %s"), money(b.total)) or T("Tout acheter"))
        local l = cur and lists[cur]
        self.main.title:SetText(cur or T("Aucune liste"))
        self.empty:SetShown(not l)
        self.empty:SetText(T("Crée une liste d'achat depuis la page Métiers (guide de montée ou recettes)."))
        local total, n = 0, 0
        for i, r in ipairs(self.irows) do
            local it = l and l.items[i]
            if it then
                local id = it[1]
                local have = S:Have(id)
                local need = math.max(0, it[2] - have)
                r.id, r.need = id, need
                r.icon:SetTexture(itemIcon(id))
                local name, _, quality = WK.GetItemInfo(id)
                r.a:SetText(name or ("#" .. id))
                if quality and GetItemQualityColor then r.a:SetTextColor(GetItemQualityColor(quality)) end
                r.b:SetText(need > 0 and (need .. UI:Hex(C.dim) .. " (" .. have .. ")|r") or (UI:Hex(C.positive) .. T("ok") .. "|r"))
                local low = lowestOther(id) or (results[id] == nil and S:Price(id)) or nil
                local av = available(id)
                r.c:SetText(results[id] and (low and money(low) or (UI:Hex(C.negative) .. T("aucune") .. "|r")) or (low and (UI:Hex(C.dim) .. money(low) .. "|r") or "-"))
                r.d:SetText(av and tostring(av) or "")
                if low and need > 0 then total = total + low * need end
                n = n + 1
                if need <= 0 then r.btn:Hide()
                else
                    r.btn:Show()
                    if not isCommodity(id) then r.btn:SetLabel(T("Chercher"))
                    elseif b and b.id == id and b.phase == "confirm" then r.btn:SetLabel(string.format(T("Confirmer %s"), money(b.total)))
                    elseif b and b.id == id and (b.phase == "quote" or b.phase == "wait") then r.btn:SetLabel("…")
                    else r.btn:SetLabel(string.format(T("Acheter %d"), need)) end
                end
                r:Show()
            else r:Hide() end
        end
        self.main.sub:SetText(l and string.format(T("%d objets"), n) or "")
        self.total:SetText(total > 0 and (T("total") .. " ~ " .. money(total)) or "")
    end

    -----------------------------------------------------------------------
    -- Annulation
    -----------------------------------------------------------------------
    local cv = CreateFrame("Frame", nil, f)
    cv:SetPoint("TOPLEFT", 8, -34); cv:SetPoint("BOTTOMRIGHT", -8, 8)
    f.views.cancel = cv
    cv.side = panelBox(cv, "Sous-cotées")
    cv.side:SetPoint("TOPRIGHT"); cv.side:SetPoint("BOTTOMRIGHT"); cv.side:SetWidth(230)
    cv.next = UI:Button(cv.side, "Annuler la suivante", nil, 32, "primary")
    cv.next:SetPoint("TOPLEFT", 10, -36); cv.next:SetPoint("TOPRIGHT", -10, -36)
    cv.note = UI:Text(cv.side, 10, C.muted); cv.note:SetPoint("TOPLEFT", 10, -78); cv.note:SetPoint("RIGHT", -10, 0)
    cv.note:SetJustifyH("LEFT")
    if cv.note.SetWordWrap then cv.note:SetWordWrap(true) end
    cv.note:SetText(T("Un clic par enchère (le jeu l'exige). Elle revient dans tes sacs : remets-la en vente depuis l'onglet Vente, au bon prix."))
    cv.main = panelBox(cv, "Mes enchères")
    cv.main:SetPoint("TOPLEFT"); cv.main:SetPoint("BOTTOMRIGHT", cv.side, "BOTTOMLEFT", -8, 0)
    cv.check = UI:Button(cv.main, "Vérifier les prix", nil, 22, "secondary"); cv.check:SetPoint("TOPRIGHT", -8, -6)
    cv.check:SetScript("OnClick", function() A:Check() end)
    local ccols = { { "Objet", 34 }, { "Qté", -330 }, { "Mon prix", -250 }, { "Plus bas", -170 }, { "Reste", -110 } }
    for _, cdef in ipairs(ccols) do
        local h = UI:Text(cv.main, 9, C.dim)
        if cdef[2] > 0 then h:SetPoint("TOPLEFT", cdef[2], -32) else h:SetPoint("TOPRIGHT", cdef[2], -32) end
        h:SetText(UI:Upper(T(cdef[1])))
    end
    cv.rows = {}
    for i = 1, 12 do
        local r = textRow(cv.main, 26)
        r:SetPoint("TOPLEFT", 6, -46 - (i - 1) * 28); r:SetPoint("TOPRIGHT", -6, -46 - (i - 1) * 28)
        r.a:SetPoint("RIGHT", -360, 0)
        r.b:SetPoint("RIGHT", -330, 0); r.b:SetWidth(30)
        r.c:SetPoint("RIGHT", -250, 0); r.c:SetWidth(80); r.c:SetTextColor(C.text[1], C.text[2], C.text[3])
        r.d:SetPoint("RIGHT", -170, 0); r.d:SetWidth(80)
        r.left = UI:Text(r, 11, C.muted); r.left:SetPoint("RIGHT", -110, 0); r.left:SetWidth(50); r.left:SetJustifyH("RIGHT")
        r.state = UI:Badge(r, "", C.muted); r.state:SetPoint("RIGHT", -4, 0)
        r:SetScript("OnClick", function(s) if s.o then A:Cancel(s.o.auctionID) end end)
        r:SetScript("OnEnter", function(s)
            if not s.o then return end
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            if GameTooltip.SetItemByID then GameTooltip:SetItemByID(s.o.id) end
            GameTooltip:AddLine(T("Clic : annuler cette enchère"), 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        cv.rows[i] = r
    end
    cv.empty = UI:Text(cv.main, 11, C.muted); cv.empty:SetPoint("CENTER")
    cv.empty:SetText(T("Aucune enchère en cours."))
    cv.next:SetScript("OnClick", function()
        for _, o in ipairs(A.owned or {}) do
            if o.state == "under" then A:Cancel(o.auctionID) return end
        end
    end)
    function cv:Refresh()
        local owned = A.owned or {}
        local under = A:UnderCount()
        self.side.title:SetText(string.format(T("Sous-cotées : %d"), under))
        self.next:SetEnabled(under > 0)
        local done, total = A:Progress()
        self.main.sub:SetText(string.format(T("%d en cours"), #owned) .. (A.checking and ("  ·  " .. string.format(T("vérification %d/%d"), done, total)) or ""))
        self.empty:SetShown(#owned == 0)
        for i, r in ipairs(self.rows) do
            local o = owned[i]
            r.o = o
            if o then
                r.icon:SetTexture(itemIcon(o.id))
                local name, _, quality = WK.GetItemInfo(o.id)
                r.a:SetText(name or ("#" .. o.id))
                if quality and GetItemQualityColor then r.a:SetTextColor(GetItemQualityColor(quality)) end
                r.b:SetText(tostring(o.qty or 1))
                r.c:SetText(money(o.unit))
                r.d:SetText(o.lowest and money(o.lowest) or "-")
                local tl = o.timeLeft
                r.left:SetText(tl and (tl >= 3600 and string.format("~ %d h", math.floor(tl / 3600)) or string.format("~ %d min", math.max(1, math.floor(tl / 60)))) or "")
                local st = o.state
                if st == "under" then r.state:Set(T("sous-cotée"), C.negative)
                elseif st == "ok" or st == "alone" then r.state:Set(T("plus bas"), C.positive)
                else r.state:Set(T("à vérifier"), C.muted) end
                r:Show()
            else r:Hide() end
        end
    end

    -----------------------------------------------------------------------
    -- Scan : le panneau d'avant, posé dans l'onglet
    -----------------------------------------------------------------------
    local scv = CreateFrame("Frame", nil, f)
    scv:SetPoint("TOPLEFT", 8, -34); scv:SetPoint("BOTTOMRIGHT", -8, 8)
    f.views.scan = scv
    scv.note = UI:Text(scv, 11, C.muted); scv.note:SetPoint("TOPLEFT", 330, -10); scv.note:SetPoint("RIGHT", -10, 0)
    scv.note:SetJustifyH("LEFT")
    if scv.note.SetWordWrap then scv.note:SetWordWrap(true) end
    scv.note:SetText(T("Le scan relève le prix de tout l'HV (un scan complet toutes les 15 minutes au plus). Ces prix servent partout : infobulles, valeur du compte, Rangement, prix proposé à la vente. Les alertes de prix préviennent quand un objet suivi passe sous ton prix."))
    function scv:Refresh() end

    function f:Refresh()
        if not self:IsShown() then return end
        local d = S:Data()
        self.scanInfo:SetText(d.last and string.format(T("dernier scan : %s"), date("%d/%m %H:%M", d.last)) or T("jamais scanné"))
        local titles = { buy = "Achat", sell = "Vente", cancel = "Annulation", scan = "Scan" }
        self.head:SetText(T(titles[self.tab] or ""))
        local v = self.views[self.tab]
        if v and v.Refresh then v:Refresh() end
    end
    f:SetScript("OnUpdate", function(s, el)
        s.acc = (s.acc or 0) + el
        if s.acc < THROTTLE then return end
        s.acc = 0
        pump()
        if s.tab == "cancel" and A.checking then s:Refresh() end
    end)
    return f
end

---------------------------------------------------------------------------
-- Accroche à la fenêtre de l'HV du jeu
---------------------------------------------------------------------------
local function attach()
    if not (cfg().tabs and WK:FeatureOn("ah")) then return end
    local host = AuctionHouseFrame
    if not host then return end
    if not view then
        view = build(host)
        -- un onglet du jeu choisi : nos onglets se referment
        if host.SetDisplayMode and hooksecurefunc then
            hooksecurefunc(host, "SetDisplayMode", function() if view and view:IsShown() and not view.opening then view:Close() end end)
        end
        for _, tb in ipairs(host.Tabs or {}) do
            if tb.HookScript then tb:HookScript("OnClick", function() if view then view:Close() end end) end
        end
    end
    for _, b in pairs(view.tabs) do b:Show() end
end
WK:On("AUCTION_HOUSE_SHOW", function() C_Timer.After(0.15, attach) end)
WK:On("AUCTION_HOUSE_CLOSED", function()
    if view then view:Close() end
    wipe(queue); pending = nil
end)
WK:On("BAG_UPDATE_DELAYED", function() if view and view:IsShown() and view.tab ~= "scan" then view:Refresh() end end)
WK:On("OWNED_AUCTIONS_UPDATED", function() C_Timer.After(0.1, function() if view and view:IsShown() then view:Refresh() end end) end)
local prevProgress = S.OnProgress
S.OnProgress = function(...)
    if prevProgress then prevProgress(...) end
    if view and view:IsShown() then view:Refresh() end
end
local prevChange = A.OnChange
A.OnChange = function(...)
    if prevChange then prevChange(...) end
    if view and view:IsShown() then view:Refresh() end
end
function UI:AuctionTabs() return view end
