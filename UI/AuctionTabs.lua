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
    c.postDur = c.postDur or tonumber(GetCVar and GetCVar("auctionHouseDurationDropdown") or "") or 2
    if c.postDur < 1 or c.postDur > 3 then c.postDur = 2 end
    c.posts = c.posts or {}
    c.sellFav, c.sellHidden, c.qtyMode = c.sellFav or {}, c.sellHidden or {}, c.qtyMode or {}
    if c.askBad == nil then c.askBad = true end
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
    -- le plus bas vu compte aussi pour la courbe des prix du jour
    local r = results[id]
    if r then
        local low, qty = nil, 0
        for _, row in ipairs(r.rows) do low = low and math.min(low, row.unit) or row.unit; qty = qty + row.qty end
        if low then pcall(S.SeenToday, S, id, low, qty) end
    end
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
    local by, list, hiddenSeen = {}, {}, {}
    for bag = 0, 4 do
        for slot = 1, WK.Container.NumSlots(bag) or 0 do
            local id, count, _, bound = WK.Container.Info(bag, slot)
            if id and cfg().sellHidden[id] and sellable(bag, slot, id, bound) then
                hiddenSeen[id] = true
            elseif id and sellable(bag, slot, id, bound) then
                local e = by[id]
                if not e then e = { id = id, count = 0, bag = bag, slot = slot }; by[id] = e; table.insert(list, e) end
                e.count = e.count + (count or 1)
            end
        end
    end
    local fav = cfg().sellFav
    for _, e in ipairs(list) do e.value = (S:Price(e.id) or 0) * e.count end
    -- favoris d'abord, puis les plus précieux
    table.sort(list, function(x, y)
        local fx, fy = fav[x.id] and 1 or 0, fav[y.id] and 1 or 0
        if fx ~= fy then return fx > fy end
        if x.value ~= y.value then return x.value > y.value end
        return x.id < y.id
    end)
    local nh = 0
    for _ in pairs(hiddenSeen) do nh = nh + 1 end
    return list, by, nh
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
local TABS = { { "buy", "Achat" }, { "sell", "Vente" }, { "cancel", "Annulation" }, { "prices", "Prix" }, { "scan", "Scan" } }

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

    -- onglets à nous, après ceux du jeu et dans leur style : texte, trait de séparation, soulignés quand
    -- choisis ; même hauteur et même police que le dernier onglet du jeu, sur un fond de la barre d'onglets
    f.tabs = {}
    local gameTabs = host.Tabs
    local anchor = gameTabs and gameTabs[#gameTabs]
    local fontObj = anchor and anchor.GetFontString and anchor:GetFontString()
    local tabH = (anchor and anchor.GetHeight and anchor:GetHeight()) or 28
    if not tabH or tabH < 18 then tabH = 28 end
    local strip = CreateFrame("Frame", nil, host)
    strip:SetHeight(tabH)
    if anchor then strip:SetPoint("LEFT", anchor, "RIGHT", 0, 0) else strip:SetPoint("TOPLEFT", host, "BOTTOMLEFT", 300, 0) end
    strip:SetFrameLevel(math.min(9000, host:GetFrameLevel() + 305))
    strip.bg = strip:CreateTexture(nil, "BACKGROUND")
    strip.bg:SetAllPoints()
    strip.bg:SetColorTexture(C.bg[1], C.bg[2], C.bg[3], 0.96)
    f.strip = strip
    local x = 0
    for i, def in ipairs(TABS) do
        local b = CreateFrame("Button", nil, strip)
        b.key = def[1]
        b:SetHeight(tabH)
        b.sep = b:CreateTexture(nil, "ARTWORK")
        b.sep:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
        b.sep:SetSize(1, tabH * 0.5); b.sep:SetPoint("LEFT", 0, 0)
        b.text = b:CreateFontString(nil, "OVERLAY")
        local font, size, flags = fontObj and fontObj:GetFont()
        if font then b.text:SetFont(font, size or 12, flags or "") else b.text:SetFont(UI.FONT, 12, "") end
        b.text:SetPoint("CENTER", 0, 0)
        b.text:SetText(T(def[2]))
        b.line = b:CreateTexture(nil, "OVERLAY")
        b.line:SetHeight(2); b.line:SetPoint("BOTTOMLEFT", 8, 1); b.line:SetPoint("BOTTOMRIGHT", -8, 1)
        b.hl = b:CreateTexture(nil, "BACKGROUND")
        b.hl:SetAllPoints(); b.hl:SetColorTexture(1, 1, 1, 0.05); b.hl:Hide()
        local w = (b.text:GetStringWidth() or 50) + 36
        b:SetWidth(w)
        b:SetPoint("LEFT", strip, "LEFT", x, 0)
        x = x + w
        function b:Paint(on)
            local r, g, bb = UI:Accent()
            self.on = on
            self.line:SetColorTexture(r, g, bb, 1)
            self.line:SetShown(on)
            if on then self.text:SetTextColor(1, 1, 1) else self.text:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end
        end
        b:SetScript("OnEnter", function(s) s.hl:Show(); if not s.on then s.text:SetTextColor(C.text[1], C.text[2], C.text[3]) end end)
        b:SetScript("OnLeave", function(s) s.hl:Hide(); s:Paint(s.on) end)
        b:SetScript("OnClick", function() f:Open(def[1]) end)
        b:Paint(false)
        f.tabs[def[1]] = b
    end
    strip:SetWidth(x + 8)

    function f:Open(key)
        cfg().ahTab = key
        self.tab = key
        for k, b in pairs(self.tabs) do b:Paint(k == key) end
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
        for _, b in pairs(self.tabs) do b:Paint(false) end
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
        if b.RegisterForClicks then b:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
        b.edge = UI:Rounded(b, 6, 0, "BACKGROUND", 1)
        b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetPoint("TOPLEFT", 2, -2); b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.n = UI:Text(b, 10, C.text, "OVERLAY"); b.n:SetFont(UI.FONT, 10, "OUTLINE"); b.n:SetPoint("BOTTOMRIGHT", -1, 1)
        b.tag = UI:Text(b, 8, C.gold, "OVERLAY"); b.tag:SetFont(UI.FONT, 8, "OUTLINE"); b.tag:SetPoint("TOPLEFT", 2, -1)
        b:SetScript("OnClick", function(s, button)
            if not s.e then return end
            if button == "RightButton" then
                -- clic droit : favori (en tête de liste) ; Maj + clic droit : ne plus proposer cet objet
                local c = cfg()
                if IsShiftKeyDown and IsShiftKeyDown() then c.sellHidden[s.e.id] = true; c.sellFav[s.e.id] = nil
                else c.sellFav[s.e.id] = (not c.sellFav[s.e.id]) or nil end
                sv:Refresh()
                return
            end
            sv:Select(s.e.id)
        end)
        b:SetScript("OnEnter", function(s)
            if not s.e then return end
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            if GameTooltip.SetItemByID then GameTooltip:SetItemByID(s.e.id) end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(cfg().sellFav[s.e.id] and T("Clic droit : retirer des favoris") or T("Clic droit : favori (en tête)"), 0.6, 0.6, 0.6)
            GameTooltip:AddLine(T("Maj + clic droit : ne plus proposer"), 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:Hide()
        sv.slots[i] = b
    end
    sv.hiddenBtn = CreateFrame("Button", nil, sv.bags)
    sv.hiddenBtn:SetHeight(16); sv.hiddenBtn:SetPoint("BOTTOMLEFT", 10, 52); sv.hiddenBtn:SetPoint("RIGHT", -10, 0)
    sv.hiddenBtn.t = UI:Text(sv.hiddenBtn, 10); sv.hiddenBtn.t:SetPoint("LEFT")
    sv.hiddenBtn:SetScript("OnClick", function() wipe(cfg().sellHidden); sv:Refresh() end)
    sv.bagNote = UI:Text(sv.bags, 10, C.dim); sv.bagNote:SetPoint("BOTTOMLEFT", 10, 10); sv.bagNote:SetPoint("RIGHT", -10, 0)
    sv.bagNote:SetJustifyH("LEFT")
    if sv.bagNote.SetWordWrap then sv.bagNote:SetWordWrap(true) end
    sv.bagNote:SetText(T("Liés, verrouillés à la main et objets de quête cachés · « HV » : prix connu · étoile : à vendre d'après le Rangement · clic droit sur un objet de tes sacs du jeu : il arrive ici"))

    sv.right = panelBox(sv, "En vente")
    sv.right:SetPoint("TOPRIGHT"); sv.right:SetPoint("BOTTOMRIGHT"); sv.right:SetWidth(260)
    sv.right.sub:SetText(T("clic : prendre ce prix"))
    sv.lrows = {}
    for i = 1, 9 do
        local r = textRow(sv.right, 22)
        r:SetPoint("TOPLEFT", 6, -28 - (i - 1) * 22); r:SetPoint("TOPRIGHT", -6, -28 - (i - 1) * 22)
        r.icon:Hide(); r.a:SetPoint("LEFT", 6, 0)
        r.b:SetPoint("RIGHT", -110, 0); r.b:SetWidth(40)
        r.c:SetPoint("RIGHT", -74, 0); r.c:SetWidth(36)
        r.act = UI:Button(r, "Acheter", 66, 18, "ghost"); r.act:SetPoint("RIGHT", -2, 0)
        r:SetScript("OnClick", function(s)
            -- clic : ce prix (le tien tel quel, celui d'un autre moins l'écart)
            if not (s.x and sv.id) then return end
            local under = (A.Config and A.Config().undercut) or 1
            local p = s.x.mine and s.x.unit or math.max(1, s.x.unit - under)
            sv.userPrice = true
            sv.price:SetText(WK:FormatMoney(p):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
            sv:Update()
        end)
        r.act:SetScript("OnClick", function(s)
            local row = s:GetParent()
            local x, id = row.x, sv.id
            if not (x and id) then return end
            local a = AH()
            if x.mine then
                -- ta propre enchère : annuler (la première qui a ce prix)
                for _, o in ipairs(A.owned or {}) do
                    if o.id == id and o.unit == x.unit then A:Cancel(o.auctionID) return end
                end
                A:Query()
                WK:Print(T("Enchère pas encore relevée : réessaie dans un instant."))
            elseif not isCommodity(id) and x.auctionID and a and a.PlaceBid then
                if not pcall(a.PlaceBid, x.auctionID, x.unit * x.qty) then WK:Print(T("Achat refusé par le jeu.")) end
            elseif a and a.StartCommoditiesPurchase then
                local b = S.buy
                if b and b.id == id and b.phase == "confirm" then
                    b.phase = "wait"
                    if not pcall(a.ConfirmCommoditiesPurchase, id, b.qty) then b.phase = nil; WK:Print(T("Achat refusé par le jeu.")) end
                else
                    S.buy = { id = id, qty = x.qty, phase = "quote", skip = {}, spent = 0, count = 0 }
                    if not pcall(a.StartCommoditiesPurchase, id, x.qty) then S.buy = nil end
                end
            end
            sv:Refresh()
        end)
        sv.lrows[i] = r
    end
    sv.hist = UI:Text(sv.right, 10, C.muted); sv.hist:SetPoint("TOPLEFT", 10, -232); sv.hist:SetPoint("RIGHT", -10, 0)
    sv.hist:SetJustifyH("LEFT"); sv.hist:SetJustifyV("TOP")
    if sv.hist.SetSpacing then sv.hist:SetSpacing(3) end

    sv.mid = panelBox(sv, "")
    sv.mid:SetPoint("TOPLEFT", sv.bags, "TOPRIGHT", 8, 0); sv.mid:SetPoint("BOTTOMRIGHT", sv.right, "BOTTOMLEFT", -8, 0)
    sv.mid.title:Hide()
    sv.itemIcon = sv.mid:CreateTexture(nil, "ARTWORK"); sv.itemIcon:SetSize(36, 36); sv.itemIcon:SetPoint("TOPLEFT", 12, -12)
    sv.itemIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    sv.itemName = UI:Text(sv.mid, 13); sv.itemName:SetPoint("TOPLEFT", 56, -12); sv.itemName:SetPoint("RIGHT", -12, 0)
    sv.itemName:SetJustifyH("LEFT")
    if sv.itemName.SetWordWrap then sv.itemName:SetWordWrap(false) end
    sv.itemSub = UI:Text(sv.mid, 10, C.muted); sv.itemSub:SetPoint("TOPLEFT", 56, -29); sv.itemSub:SetPoint("RIGHT", -12, 0)
    sv.itemSub:SetJustifyH("LEFT")
    sv.rank = UI:Text(sv.mid, 10, C.muted); sv.rank:SetPoint("TOPLEFT", 56, -42); sv.rank:SetPoint("RIGHT", -12, 0)
    sv.rank:SetJustifyH("LEFT")
    local function label(txt, y, x)
        local l = UI:Text(sv.mid, 9, C.dim); l:SetPoint("TOPLEFT", x or 12, y); l:SetText(UI:Upper(T(txt)))
        return l
    end
    label("Prix unitaire", -62)
    sv.price = UI:Input(sv.mid, 160, 28, "ex. 1po 61pa 99", nil)
    sv.price:SetPoint("TOPLEFT", 12, -74)
    sv.priceHint = UI:Text(sv.mid, 10, C.muted); sv.priceHint:SetPoint("TOPLEFT", 12, -106); sv.priceHint:SetPoint("RIGHT", -12, 0)
    sv.priceHint:SetJustifyH("LEFT")
    label("Quantité", -124)
    sv.qty = UI:Input(sv.mid, 60, 26, "1", nil)
    sv.qty:SetPoint("TOPLEFT", 12, -136)
    -- pastilles : 1, une pile, tout ; le choix est retenu pour ce genre d'objet
    sv.qbtn = {}
    local qprev = sv.qty
    for _, q in ipairs({ { "one", "1" }, { "stack", "pile" }, { "all", "tout" } }) do
        local b = UI:Button(sv.mid, q[2], nil, 22, "ghost")
        b:SetPoint("LEFT", qprev, "RIGHT", 6, 0)
        b:SetScript("OnClick", function() sv:SetQtyMode(q[1]) end)
        sv.qbtn[q[1]] = b
        qprev = b
    end
    label("Durée", -170)
    -- durées du jeu (sur WoW Forever : 2, 8 et 24 h), libellés lus dans le jeu
    local DUR = { { 1, _G.AUCTION_DURATION_ONE or "2 h" }, { 2, _G.AUCTION_DURATION_TWO or "8 h" }, { 3, _G.AUCTION_DURATION_THREE or "24 h" } }
    sv.dur = UI:Segmented(sv.mid, DUR, function(v) cfg().postDur = v; sv:Update() end, 24)
    sv.dur:SetPoint("TOPLEFT", 12, -182)
    sv.total = UI:Text(sv.mid, 12); sv.total:SetPoint("TOPLEFT", 12, -214); sv.total:SetPoint("RIGHT", -12, 0); sv.total:SetJustifyH("LEFT")
    sv.deposit = UI:Text(sv.mid, 10, C.muted); sv.deposit:SetPoint("TOPLEFT", 12, -232)
    sv.keys = UI:Text(sv.mid, 9, C.dim); sv.keys:SetPoint("BOTTOMLEFT", 12, 50); sv.keys:SetPoint("RIGHT", -12, 0); sv.keys:SetJustifyH("LEFT")
    sv.post = UI:Button(sv.mid, "Mettre en vente", nil, 32, "primary")
    sv.post:SetPoint("BOTTOMLEFT", 12, 12); sv.post:SetPoint("BOTTOMRIGHT", -96, 12)
    sv.skip = UI:Button(sv.mid, "Passer", 76, 32, "secondary"); sv.skip:SetPoint("BOTTOMRIGHT", -12, 12)
    -- garde-fou : prix très sous le cours ou sous le prix du marchand
    sv.warn = CreateFrame("Frame", nil, sv.mid)
    sv.warn:SetPoint("BOTTOMLEFT", 12, 50); sv.warn:SetPoint("BOTTOMRIGHT", -12, 50); sv.warn:SetHeight(64)
    UI:Panel(sv.warn, 8, { C.negative[1] * 0.25, C.negative[2] * 0.25, C.negative[3] * 0.25, 0.95 }, C.negative)
    sv.warn.t = UI:Text(sv.warn, 11); sv.warn.t:SetPoint("TOPLEFT", 10, -8); sv.warn.t:SetPoint("RIGHT", -10, 0); sv.warn.t:SetJustifyH("LEFT")
    if sv.warn.t.SetWordWrap then sv.warn.t:SetWordWrap(true) end
    sv.warn.yes = UI:Button(sv.warn, "Vendre quand même", nil, 22, "primary"); sv.warn.yes:SetPoint("BOTTOMLEFT", 10, 8)
    sv.warn.no = UI:Button(sv.warn, "Corriger", nil, 22, "secondary"); sv.warn.no:SetPoint("LEFT", sv.warn.yes, "RIGHT", 6, 0)
    sv.warn:SetFrameLevel(sv.mid:GetFrameLevel() + 5)
    sv.warn:Hide()
    sv.empty = UI:Text(sv.mid, 11, C.muted); sv.empty:SetPoint("CENTER")
    sv.empty:SetText(T("Choisis un objet dans tes sacs."))

    local function priceValue() return A.ParsePrice(sv.price:GetText()) end
    local function qtyValue() return math.max(1, math.floor(tonumber(sv.qty:GetText()) or 1)) end
    local function plain(p) return (WK:FormatMoney(p):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
    -- prix tapé à la main : on n'y touche plus (jusqu'à l'objet suivant)
    sv.price.onChange = function(_, user) if user then sv.userPrice = true end sv.warn:Hide(); sv:Update() end
    sv.qty.onChange = function() sv.warn:Hide(); sv:Update() end

    local function stackOf(id)
        local n = C_Item and C_Item.GetItemMaxStackSizeByID and C_Item.GetItemMaxStackSizeByID(id)
        return n or select(8, WK.GetItemInfo(id)) or 1
    end
    local function classOf(id) return select(12, WK.GetItemInfo(id)) or 0 end
    function sv:SetQtyMode(mode, keep)
        local e = self.e
        if not e then return end
        if not keep then cfg().qtyMode[classOf(e.id)] = mode end
        local n = mode == "one" and 1 or mode == "stack" and math.min(e.count, stackOf(e.id)) or e.count
        self.qty:SetText(tostring(n))
        for k, b in pairs(self.qbtn) do if b.SetStyle then b:SetStyle(k == mode and "primary" or "ghost") end end
        self:Update()
    end

    function sv:Select(id)
        local _, by = bagItems()
        local e = by[id]
        self.e = e
        self.id = id
        self.userPrice = false
        self.warn:Hide()
        if e then
            self:SetQtyMode(cfg().qtyMode[classOf(id)] or "all", true)
            search(id, true)
            pump()
        end
        self:Refresh()
    end
    -- prix proposé : plus bas des autres moins l'écart ; tu es déjà le plus bas : ton prix ; sinon le scan
    function sv:Suggest()
        local id = self.id
        if not id then return end
        local low, mineFirst = lowestOther(id)
        local c = A.Config and A.Config() or {}
        local under = c.undercut or 1
        local p, why
        if low then p, why = math.max(1, low - under), string.format(T("plus bas %s moins %s"), money(low), money(under))
        elseif mineFirst then p, why = results[id].rows[1].unit, T("tu es déjà le moins cher")
        elseif S:Price(id) then p, why = math.max(1, S:Price(id) - under), T("prix du scan")
        end
        self.suggested = p
        self.why = why or T("aucun prix connu : à toi de le fixer")
        if self.userPrice then return end
        if p then
            local txt = plain(p)
            if txt ~= self.price:GetText() then self.price:SetText(txt) end
        end
    end
    -- où ton prix arrive parmi les enchères des autres
    function sv:Rank(unit)
        local r = self.id and results[self.id]
        if not (r and unit) then return nil end
        local pos, n = 1, 0
        for _, x in ipairs(r.rows) do
            if not x.mine then
                n = n + 1
                if x.unit < unit then pos = pos + 1 end
            end
        end
        return pos, n + 1
    end
    function sv:Update()
        local id, e = self.id, self.e
        if not (id and e) then return end
        local unit, qty = priceValue(), math.min(qtyValue(), e.count)
        self.priceHint:SetText((unit and money(unit) .. "  ·  " or "") .. (self.why or ""))
        self.total:SetText(unit and (T("Total") .. " : " .. money(unit * qty)) or "")
        local pos, n = self:Rank(unit)
        self.rank:SetText(pos and string.format(T("ton prix arrive %s sur %d"), pos == 1 and (UI:Hex(C.positive) .. T("1er") .. "|r") or (pos .. T("e")), n) or "")
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
        local ready = not (a and a.IsThrottledMessageSystemReady) or a.IsThrottledMessageSystemReady()
        self.post:SetEnabled(unit ~= nil and unit > 0 and ready)
        self.keys:SetShown(cfg().postKeys and not self.warn:IsShown())
        self.keys:SetText(T("Touches : Espace = mettre en vente · S = passer · Haut / Bas = palier de prix"))
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
    -- garde-fou : prix pour un, après la commission (5 %), pas plus que ce que paie le marchand ; ou, sous le
    -- prix proposé, sous une part du cours (plus bas des autres, sinon le scan) : 70 % sous 1 po, 50 % jusqu'à
    -- 50 po, 30 % au-delà ; un zéro oublié (un dixième du prix) est toujours signalé
    local function badPost(id, unit)
        local vendor = select(11, WK.GetItemInfo(id)) or 0
        if vendor > 0 and unit * 0.95 <= vendor then
            return string.format(T("Ce prix (%s) rapporte moins que le marchand (%s)."), money(unit), money(vendor))
        end
        local going = lowestOther(id) or S:Price(id)
        if going and unit < (sv.suggested or going) then
            local share = going < 10000 and 0.7 or going <= 500000 and 0.5 or 0.3
            if unit < going * share or unit <= going * 0.1 then
                return string.format(T("Prix bien sous le cours (%s) : %s. Un zéro oublié ?"), money(going), money(unit))
            end
        end
    end
    local function doPost(id, e, unit, qty)
        local a = AH()
        local loc = ItemLocation and ItemLocation:CreateFromBagAndSlot(e.bag, e.slot)
        local dur = cfg().postDur
        local ok, needs
        if isCommodity(id) and a and a.PostCommodity then
            ok, needs = pcall(a.PostCommodity, loc, dur, qty, unit)
            if ok and needs == true and a.ConfirmPostCommodity then pcall(a.ConfirmPostCommodity, loc, dur, qty, unit) end
        elseif a and a.PostItem then
            ok, needs = pcall(a.PostItem, loc, dur, qty, nil, unit * qty)
            if ok and needs == true and a.ConfirmPostItem then pcall(a.ConfirmPostItem, loc, dur, qty, nil, unit * qty) end
        end
        if not ok then WK:Print(T("Mise en vente refusée par le jeu.") .. (needs and (" (" .. tostring(needs) .. ")") or "")) return end
        -- la fenêtre de vente du jeu ne suit pas les sacs : on la vide (comme le jeu après sa propre vente)
        for _, sf in ipairs({ host.CommoditiesSellFrame, host.ItemSellFrame }) do
            if type(sf) == "table" and sf.ClearPostItem then pcall(sf.ClearPostItem, sf) end
        end
        local posts = cfg().posts
        posts[id] = posts[id] or {}
        table.insert(posts[id], 1, { at = time(), unit = unit, qty = qty })
        while #posts[id] > 5 do table.remove(posts[id]) end
        WK:Print(string.format(T("Mis en vente : %d %s à %s l'unité."), qty, WK.GetItemInfo(id) or "?", money(unit)))
        C_Timer.After(0.6, nextItem)
    end
    function sv:TryPost()
        local id, e = self.id, self.e
        local unit, qty = priceValue(), qtyValue()
        if not (id and e and unit) then return end
        local a = AH()
        if a and a.IsThrottledMessageSystemReady and not a.IsThrottledMessageSystemReady() then
            WK:Print(T("L'hôtel des ventes est occupé : réessaie dans un instant.")) return
        end
        qty = math.min(qty, e.count)
        local why = cfg().askBad ~= false and badPost(id, unit)
        if why then
            self.warn.t:SetText(why)
            self.warn.pending = { id = id, e = e, unit = unit, qty = qty }
            self.warn:Show()
            self:Update()
            return
        end
        doPost(id, e, unit, qty)
    end
    sv.post:SetScript("OnClick", function() sv:TryPost() end)
    sv.warn.yes:SetScript("OnClick", function()
        local p = sv.warn.pending
        sv.warn:Hide()
        if p then doPost(p.id, p.e, p.unit, p.qty) end
    end)
    sv.warn.no:SetScript("OnClick", function() sv.warn:Hide(); sv.price.edit:SetFocus(); sv:Update() end)
    -- palier de prix : Haut = l'enchère suivante (plus chère) moins l'écart, Bas = la précédente
    function sv:Step(dir)
        local r = self.id and results[self.id]
        local unit = priceValue()
        if not (r and unit) then return end
        local under = (A.Config and A.Config().undercut) or 1
        local cands = {}
        for _, x in ipairs(r.rows) do if not x.mine then table.insert(cands, math.max(1, x.unit - under)) end end
        local pick
        if dir > 0 then for _, p in ipairs(cands) do if p > unit then pick = p break end end
        else for i = #cands, 1, -1 do if cands[i] < unit then pick = cands[i] break end end end
        if pick then self.userPrice = true; self.price:SetText(plain(pick)); self:Update() end
    end
    -- touches (réglage postKeys) : Espace, S, Haut, Bas ; jamais en combat ni pendant une saisie
    sv:EnableKeyboard(false)
    sv:SetScript("OnKeyDown", function(s, key)
        local typing = s.price.edit:HasFocus() or s.qty.edit:HasFocus()
        local mine = not typing and not (InCombatLockdown and InCombatLockdown()) and s.id ~= nil
            and (key == "SPACE" or key == "S" or key == "UP" or key == "DOWN" or (key == "ENTER" and s.warn:IsShown()))
        if s.SetPropagateKeyboardInput then s:SetPropagateKeyboardInput(not mine) end
        if not mine then return end
        if s.warn:IsShown() then
            if key == "ENTER" then s.warn.yes:GetScript("OnClick")(s.warn.yes) end
            return
        end
        if key == "SPACE" then s:TryPost()
        elseif key == "S" then nextItem()
        elseif key == "UP" then s:Step(1)
        elseif key == "DOWN" then s:Step(-1) end
    end)

    function sv:Refresh()
        self:EnableKeyboard(cfg().postKeys and true or false)
        local list, _, hidden = bagItems()
        local marked = stashSell()
        local fav = cfg().sellFav
        for i, b in ipairs(self.slots) do
            local e = list[i]
            b.e = e
            if e then
                b.icon:SetTexture(itemIcon(e.id))
                b.n:SetText(e.count > 1 and e.count or "")
                b.tag:SetText(fav[e.id] and "+" or marked[e.id] and "*" or (S:Price(e.id) and "HV" or ""))
                local r1, g1, b1 = UI:Accent()
                if e.id == self.id then b.edge:SetColor(r1, g1, b1, 1) else b.edge:SetColor(C.border[1], C.border[2], C.border[3], 1) end
                b:Show()
            else
                b:Hide()
            end
        end
        self.bags.sub:SetText(string.format(T("%d à vendre"), #list))
        self.hiddenBtn:SetShown(hidden > 0)
        self.hiddenBtn.t:SetText(string.format(T("%d objet(s) caché(s) : clic pour les réafficher"), hidden))
        self.hiddenBtn.t:SetTextColor(UI:Accent())
        if self.id and not self.e then self.id = nil end
        local id = self.id
        local has = id ~= nil
        for _, w in ipairs({ self.itemIcon, self.itemName, self.itemSub, self.rank, self.price, self.priceHint, self.qty, self.dur, self.total, self.deposit, self.post, self.skip }) do w:SetShown(has) end
        for _, b in pairs(self.qbtn) do b:SetShown(has) end
        if not has then self.warn:Hide(); self.keys:Hide() end
        self.empty:SetShown(not has)
        for _, r in ipairs(self.lrows) do r:Hide() end
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
        -- enchères en cours : la plus basse des autres en vert, les tiennes à la couleur d'accent ; ton prix
        local r = results[id]
        local unit = priceValue()
        local b = S.buy
        if not r then
            local row = self.lrows[1]
            row.x = nil; row.act:Hide()
            row.a:SetText(UI:Hex(C.muted) .. T("recherche…") .. "|r"); row.b:SetText(""); row.c:SetText(""); row.hl:SetColorTexture(0, 0, 0, 0); row:Show()
        else
            local firstOther = true
            local ar, ag, ab = UI:Accent()
            for i, row in ipairs(self.lrows) do
                local x = r.rows[i]
                row.x = x
                if x then
                    row.a:SetText(money(x.unit))
                    row.b:SetText(tostring(x.qty))
                    row.c:SetText(x.mine and T("toi") or "")
                    if x.mine then row.hl:SetColorTexture(ar, ag, ab, 0.12); row.c:SetTextColor(ar, ag, ab)
                    elseif firstOther then row.hl:SetColorTexture(C.positive[1], C.positive[2], C.positive[3], 0.10); firstOther = false
                    else row.hl:SetColorTexture(0, 0, 0, 0) end
                    row.act:Show()
                    if x.mine then row.act:SetLabel(T("Annuler"))
                    elseif b and b.id == id and b.phase == "confirm" and isCommodity(id) then row.act:SetLabel(string.format(T("Confirmer %s"), money(b.total)))
                    else row.act:SetLabel(T("Acheter")) end
                    row:Show()
                end
            end
            if #r.rows == 0 then
                local row = self.lrows[1]
                row.x = nil; row.act:Hide()
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

    -- clic droit sur un objet des sacs du jeu, HV ouvert : il arrive dans notre Vente (le jeu le prend aussi)
    if hooksecurefunc and host.SetPostItem then
        hooksecurefunc(host, "SetPostItem", function(_, loc)
            if not (f:IsShown() and f.tab == "sell") then return end
            local ok, id = pcall(C_Item.GetItemID, loc)
            if ok and id then
                if C_Item.UnlockItem then pcall(C_Item.UnlockItem, loc) end
                sv:Select(id)
            end
        end)
    end

    -----------------------------------------------------------------------
    -- Achat
    -----------------------------------------------------------------------
    local bv = CreateFrame("Frame", nil, f)
    bv:SetPoint("TOPLEFT", 8, -34); bv:SetPoint("BOTTOMRIGHT", -8, 8)
    f.views.buy = bv
    bv.lists = panelBox(bv, "Listes d'achat")
    bv.lists:SetPoint("TOPLEFT"); bv.lists:SetPoint("BOTTOMLEFT"); bv.lists:SetWidth(230)
    -- recherche : n'importe quel objet de tes scans, à acheter ou à mettre dans la liste
    bv.search = UI:Input(bv.lists, 208, 26, "Acheter un objet…", "search")
    bv.search:SetPoint("TOPLEFT", 10, -28)
    bv.search.onChange = function() bv:Refresh() end
    bv.lrows = {}
    for i = 1, 9 do
        local r = textRow(bv.lists, 24)
        r:SetPoint("TOPLEFT", 6, -62 - (i - 1) * 26); r:SetPoint("TOPRIGHT", -6, -62 - (i - 1) * 26)
        r.icon:Hide(); r.a:SetPoint("LEFT", 8, 0); r.a:SetPoint("RIGHT", -40, 0)
        r.b:SetPoint("RIGHT", -8, 0)
        r:SetScript("OnClick", function(s) if s.name then cfg().curList = s.name; bv.search:SetText(""); bv:Refresh() end end)
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
        r.add = UI:IconButton(r, "plus", 22, "Ajouter à la liste d'achat")
        r.add:SetPoint("RIGHT", r.btn, "LEFT", -6, 0)
        r.add:SetScript("OnClick", function(s)
            local row = s:GetParent()
            if not row.id then return end
            local _, lists = S:Lists()
            local name = cfg().curList
            if not (name and lists[name]) then name = T("Mes achats") end
            local l = lists[name] or { items = {}, at = time(), v = 2 }
            lists[name] = l
            local q = math.max(1, bv.qty:GetNumber() > 0 and bv.qty:GetNumber() or 1)
            local found
            for _, it in ipairs(l.items) do if it[1] == row.id then it[2] = it[2] + q; found = true end end
            if not found then table.insert(l.items, { row.id, q + S:Have(row.id) }) end
            cfg().curList = name
            WK:Print(string.format(T("%s ajouté à la liste « %s »."), WK.GetItemInfo(row.id) or "?", name))
            bv:Refresh()
        end)
        r.add:Hide()
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
    bv.qtyLabel = UI:Text(bv.main, 11, C.muted); bv.qtyLabel:SetPoint("TOPRIGHT", -74, -10); bv.qtyLabel:SetText(T("Quantité"))
    bv.qty = UI:NumberInput(bv.main, 56, 22, "1"); bv.qty:SetPoint("TOPRIGHT", -12, -6)
    bv.qty.edit:SetText("1")
    bv.searchAll:SetScript("OnClick", function()
        local l = S:GetList(cfg().curList)
        for _, it in ipairs(l and l.items or {}) do search(it[1]) end
        pump()
    end)
    bv.buyAll:SetScript("OnClick", function() S:BuyStep(); bv:Refresh() end)
    -- résultats de la recherche : objets de tes scans dont le nom contient le texte
    function bv:RefreshSearch(q)
        local list = {}
        for id in pairs(S:Data().items) do
            local name = WK.GetItemInfo(id)
            if name and string.lower(name):find(q, 1, true) then table.insert(list, { id = id, name = name }) end
        end
        table.sort(list, function(a, b) return a.name < b.name end)
        self.main.title:SetText(T("Résultats"))
        self.main.sub:SetText(string.format(T("%d objets"), #list))
        self.empty:SetShown(#list == 0)
        self.empty:SetText(T("Aucun objet de tes scans ne porte ce nom : fais un scan, ou cherche-le dans la fenêtre du jeu."))
        local qn = math.max(1, self.qty:GetNumber() > 0 and self.qty:GetNumber() or 1)
        local b = S.buy
        for i, r in ipairs(self.irows) do
            local e = list[i]
            if e then
                local id = e.id
                r.id, r.need = id, qn
                r.icon:SetTexture(itemIcon(id))
                local _, _, quality = WK.GetItemInfo(id)
                r.a:SetText(e.name)
                if quality and GetItemQualityColor then r.a:SetTextColor(GetItemQualityColor(quality)) end
                r.b:SetText(UI:Hex(C.dim) .. S:Have(id) .. "|r")
                local low = lowestOther(id) or S:Price(id)
                local av = available(id)
                r.c:SetText(low and money(low) or "-")
                r.d:SetText(av and tostring(av) or "")
                r.btn:Show(); r.add:Show()
                if not isCommodity(id) then r.btn:SetLabel(T("Chercher"))
                elseif b and b.id == id and b.phase == "confirm" then r.btn:SetLabel(string.format(T("Confirmer %s"), money(b.total)))
                elseif b and b.id == id and (b.phase == "quote" or b.phase == "wait") then r.btn:SetLabel("…")
                else r.btn:SetLabel(string.format(T("Acheter %d"), qn)) end
                r:Show()
            else r:Hide() end
        end
        self.total:SetText("")
    end
    function bv:Refresh()
        local q = string.lower(self.search:GetText() or "")
        self.qty:SetShown(q ~= ""); self.qtyLabel:SetShown(q ~= "")
        for _, r in ipairs(self.irows) do r.add:Hide() end
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
        if q ~= "" then return self:RefreshSearch(q) end
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
    -- Prix : courbe du plus bas de chaque jour sur 14 jours, objets qui ont le plus bougé
    -----------------------------------------------------------------------
    local pv = CreateFrame("Frame", nil, f)
    pv:SetPoint("TOPLEFT", 8, -34); pv:SetPoint("BOTTOMRIGHT", -8, 8)
    f.views.prices = pv
    pv.left = panelBox(pv, "Objets")
    pv.left:SetPoint("TOPLEFT"); pv.left:SetPoint("BOTTOMLEFT"); pv.left:SetWidth(250)
    pv.left.sub:SetText(T("de tes scans"))
    pv.search = UI:Input(pv.left, 228, 26, "Rechercher…", "search")
    pv.search:SetPoint("TOPLEFT", 10, -30)
    pv.search.onChange = function() pv:Refresh() end
    pv.head = UI:Text(pv.left, 9, C.dim); pv.head:SetPoint("TOPLEFT", 12, -66)
    pv.rows = {}
    for i = 1, 12 do
        local r = textRow(pv.left, 22)
        r:SetPoint("TOPLEFT", 6, -80 - (i - 1) * 23); r:SetPoint("TOPRIGHT", -6, -80 - (i - 1) * 23)
        r.a:SetPoint("RIGHT", -60, 0)
        r.b:SetPoint("RIGHT", -6, 0); r.b:SetWidth(54)
        r:SetScript("OnClick", function(s) if s.id then pv.id = s.id; pv:Refresh() end end)
        pv.rows[i] = r
    end
    pv.main = panelBox(pv, "")
    pv.main:SetPoint("TOPLEFT", pv.left, "TOPRIGHT", 8, 0); pv.main:SetPoint("BOTTOMRIGHT")
    pv.stats = UI:Text(pv.main, 11, C.muted); pv.stats:SetPoint("TOPRIGHT", -12, -10)
    pv.chart = CreateFrame("Frame", nil, pv.main)
    pv.chart:SetPoint("TOPLEFT", 60, -40); pv.chart:SetPoint("BOTTOMRIGHT", -16, 80)
    pv.axis = pv.chart:CreateTexture(nil, "BACKGROUND"); pv.axis:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
    pv.axis:SetPoint("BOTTOMLEFT"); pv.axis:SetPoint("BOTTOMRIGHT"); pv.axis:SetHeight(1)
    pv.axisY = pv.chart:CreateTexture(nil, "BACKGROUND"); pv.axisY:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
    pv.axisY:SetPoint("TOPLEFT"); pv.axisY:SetPoint("BOTTOMLEFT"); pv.axisY:SetWidth(1)
    pv.yTop = UI:Text(pv.main, 9, C.dim); pv.yTop:SetPoint("TOPRIGHT", pv.chart, "TOPLEFT", -4, 0)
    pv.yBot = UI:Text(pv.main, 9, C.dim); pv.yBot:SetPoint("BOTTOMRIGHT", pv.chart, "BOTTOMLEFT", -4, 0)
    pv.lines = UI:LinePool(4)
    pv.dots = {}
    pv.empty = UI:Text(pv.main, 11, C.muted); pv.empty:SetPoint("CENTER")
    pv.note = UI:Text(pv.main, 10, C.dim); pv.note:SetPoint("BOTTOMLEFT", 16, 50); pv.note:SetPoint("RIGHT", -16, 0); pv.note:SetJustifyH("LEFT")
    pv.note:SetText(T("Survol d'un point : prix et quantité en vente ce jour · trait or : moyenne · la courbe se remplit à chaque scan et à chaque recherche de l'objet"))
    pv.watchLabel = UI:Text(pv.main, 11); pv.watchLabel:SetPoint("BOTTOMLEFT", 16, 18)
    pv.watchLabel:SetText(T("Me prévenir sous"))
    pv.watch = UI:Input(pv.main, 130, 26, "ex. 45pa", nil); pv.watch:SetPoint("LEFT", pv.watchLabel, "RIGHT", 8, 0)
    pv.watchBtn = UI:Button(pv.main, "Surveiller", nil, 26, "primary"); pv.watchBtn:SetPoint("LEFT", pv.watch, "RIGHT", 6, 0)
    pv.watchBtn:SetScript("OnClick", function()
        local v = A.ParsePrice(pv.watch:GetText())
        if pv.id and v then A:AddAlert(pv.id, v); WK:Print(string.format(T("Alerte de prix : %s sous %s."), WK.GetItemInfo(pv.id) or "?", money(v))); pv:Refresh() end
    end)
    pv.sellBtn = UI:Button(pv.main, "Vendre", nil, 26, "secondary"); pv.sellBtn:SetPoint("LEFT", pv.watchBtn, "RIGHT", 6, 0)
    pv.sellBtn:SetScript("OnClick", function() if pv.id then f:Open("sell"); f.views.sell:Select(pv.id) end end)
    local function dot(i)
        local d = pv.dots[i]
        if not d then
            d = CreateFrame("Button", nil, pv.chart)
            d:SetSize(12, 12)
            d.t = d:CreateTexture(nil, "OVERLAY"); d.t:SetTexture(UI.MEDIA .. "circle"); d.t:SetSize(7, 7); d.t:SetPoint("CENTER")
            d:SetScript("OnEnter", function(s)
                UI:TooltipOwner(s, "ANCHOR_TOP")
                GameTooltip:SetText(date("%d/%m", s.day * 86400 + 43200), 1, 1, 1)
                GameTooltip:AddDoubleLine(T("Plus bas"), money(s.price), 0.7, 0.7, 0.7, 1, 1, 1)
                if s.qty and s.qty > 0 then GameTooltip:AddDoubleLine(T("En vente"), tostring(s.qty), 0.7, 0.7, 0.7, 1, 1, 1) end
                GameTooltip:Show()
            end)
            d:SetScript("OnLeave", function() GameTooltip:Hide() end)
            pv.dots[i] = d
        end
        return d
    end
    function pv:Refresh()
        local q = string.lower(self.search:GetText() or "")
        local list = {}
        if q ~= "" then
            self.head:SetText(UI:Upper(T("Résultats")))
            for id in pairs(S:Data().items) do
                local name = WK.GetItemInfo(id)
                if name and string.lower(name):find(q, 1, true) then table.insert(list, { id, nil }) end
                if #list >= 12 then break end
            end
        else
            self.head:SetText(UI:Upper(T("Ont le plus bougé (7 j)")))
            for _, m in ipairs(S:Movers(12)) do table.insert(list, { m[1], m[2] }) end
        end
        if not self.id and list[1] then self.id = list[1][1] end
        local ar, ag, ab = UI:Accent()
        for i, r in ipairs(self.rows) do
            local it = list[i]
            r.id = it and it[1]
            if it then
                r.icon:SetTexture(itemIcon(it[1]))
                local name, _, quality = WK.GetItemInfo(it[1])
                r.a:SetText(name or ("#" .. it[1]))
                if quality and GetItemQualityColor then r.a:SetTextColor(GetItemQualityColor(quality)) end
                if it[2] then
                    local pc = math.floor(it[2] * 100 + 0.5)
                    r.b:SetText((pc > 0 and "+" or "") .. pc .. " %")
                    local col = pc >= 0 and C.positive or C.negative
                    r.b:SetTextColor(col[1], col[2], col[3])
                else r.b:SetText("") end
                r.hl:SetColorTexture(ar, ag, ab, it[1] == self.id and 0.14 or 0)
                r:Show()
            else r:Hide() end
        end
        -- courbe
        self.lines:Reset()
        for _, d in ipairs(self.dots) do d:Hide() end
        local id = self.id
        local hist = id and S:History(id) or {}
        local name = id and WK.GetItemInfo(id)
        self.main.title:SetText(name or "")
        self.main.sub:SetText(id and T("plus bas de chaque jour · 14 jours") or "")
        self.empty:SetShown(#hist < 1)
        self.empty:SetText(id and T("Pas encore de prix relevé pour cet objet : lance un scan.") or T("Choisis un objet : il a le plus bougé, ou cherche-le."))
        local avg = id and S:Average(id)
        local alert = id and (A.Config().alerts or {})[id]
        self.stats:SetText(id and ((hist[#hist] and (T("dernier") .. " " .. money(hist[#hist][2]) .. "  ·  ") or "") .. (avg and (T("moyenne") .. " " .. money(avg)) or "") .. (alert and ("  ·  " .. T("alerte sous") .. " " .. money(alert)) or "")) or "")
        for _, w in ipairs({ self.watchLabel, self.watch, self.watchBtn, self.sellBtn, self.note }) do w:SetShown(id ~= nil) end
        if #hist < 1 then self.yTop:SetText(""); self.yBot:SetText(""); return end
        local lo, hi = math.huge, 0
        for _, h in ipairs(hist) do lo = math.min(lo, h[2]); hi = math.max(hi, h[2]) end
        if avg then lo, hi = math.min(lo, avg), math.max(hi, avg) end
        if hi == lo then hi = lo + 1 end
        local pad = (hi - lo) * 0.1
        lo, hi = math.max(0, lo - pad), hi + pad
        self.yTop:SetText(money(math.floor(hi))); self.yBot:SetText(money(math.floor(lo)))
        local W, H = self.chart:GetWidth() or 400, self.chart:GetHeight() or 150
        local today = math.floor(time() / 86400)
        local first = today - 13
        local function px(day) return (day - first) / 13 * W end
        local function py(p) return H - (p - lo) / (hi - lo) * H end
        if avg then
            -- moyenne en tirets or
            local k = 0
            while k < W do
                self.lines:Add(self.chart, k, py(avg), math.min(W, k + 8), py(avg), 1.5, C.gold[1], C.gold[2], C.gold[3], 0.8)
                k = k + 14
            end
        end
        local prevX, prevY
        for i, h in ipairs(hist) do
            if h[1] >= first then
                local x, y = px(h[1]), py(h[2])
                if prevX then self.lines:Add(self.chart, prevX, prevY, x, y, 2.5, ar, ag, ab, 1) end
                prevX, prevY = x, y
                local d = dot(i)
                d.day, d.price, d.qty = h[1], h[2], h[3]
                d.t:SetVertexColor(ar, ag, ab, 1)
                d:ClearAllPoints(); d:SetPoint("CENTER", self.chart, "TOPLEFT", x, -y)
                d:Show()
            end
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
    -- réglages de la vente
    scv.opts = panelBox(scv, "Vente")
    scv.opts:SetPoint("TOPLEFT", 330, -96); scv.opts:SetPoint("RIGHT", -10, 0); scv.opts:SetHeight(120)
    local function opt(y, label, desc, get, set)
        local t = UI:Toggle(scv.opts, get, set)
        t:SetPoint("TOPLEFT", 12, y)
        local l = UI:Text(scv.opts, 12); l:SetPoint("LEFT", t, "RIGHT", 10, 6); l:SetText(T(label))
        local d = UI:Text(scv.opts, 10, C.muted); d:SetPoint("TOPLEFT", l, "BOTTOMLEFT", 0, -2); d:SetPoint("RIGHT", scv.opts, "RIGHT", -12, 0)
        d:SetJustifyH("LEFT"); d:SetText(T(desc))
        return t
    end
    scv.t1 = opt(-34, "Mettre en vente au clavier", "Onglet Vente : Espace met en vente, S passe, Haut / Bas changent de palier de prix.",
        function() return cfg().postKeys end, function(v) cfg().postKeys = v end)
    scv.t2 = opt(-78, "Demander avant une vente à perte", "Un prix sous le prix du marchand, ou bien sous le cours (un zéro oublié), demande confirmation.",
        function() return cfg().askBad ~= false end, function(v) cfg().askBad = v end)
    function scv:Refresh() self.t1:Refresh(); self.t2:Refresh() end

    function f:Refresh()
        if not self:IsShown() then return end
        local d = S:Data()
        self.scanInfo:SetText(d.last and string.format(T("dernier scan : %s"), date("%d/%m %H:%M", d.last)) or T("jamais scanné"))
        local titles = { buy = "Achat", sell = "Vente", cancel = "Annulation", prices = "Prix", scan = "Scan" }
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
    view.strip:Show()
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
