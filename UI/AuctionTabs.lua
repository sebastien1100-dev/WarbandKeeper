local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Hôtel des ventes Warband Keeper : notre fenêtre (WarbandKeeperAH) prend la place de celle du jeu, qui reste
-- ouverte mais invisible (alpha 0) sous la nôtre. Barre de titre (scan, or, « Fenêtre du jeu » pour revenir à celle
-- du jeu le reste de la visite, fermer), barre latérale (pages avec pastilles, recherches enregistrées et récentes).
--   Parcourir  : recherche par nom et catégorie (SendBrowseQuery, AuctionCategories), filtres (utilisable,
--                niveau, bonne affaire = plus bas sous 80 % de la moyenne de 7 j), résultats triables qui défilent ;
--                objet choisi : courbe, enchères avec cumul, achat (unique : PlaceBid ; marchandise : prix puis
--                confirmation), alerte de prix.
--   Vendre     : objets des sacs vendables (liés, verrouillés à la main et objets de quête cachés) et ceux que
--                le Rangement met en vente sur ce perso ; prix proposé (plus bas des autres moins l'écart, sinon
--                prix du scan), quantité, durée, dépôt ; « Mettre en vente » puis objet suivant ; enchères en cours
--                de l'objet (la plus basse et la tienne surlignées) ; tes derniers prix et ventes.
--   Mes enchères : tes enchères (Modules/AHSell.lua), filtres, « Annuler la suivante », bilan du jour.
--   À acheter  : listes d'achat (Modules/AHScan.lua) et « File de fabrication » (ce qui manque à la file des
--                métiers de tous tes persos), « Acheter N » (demande de prix puis confirmation : le jeu l'exige).
--   Prix       : courbe du plus bas de chaque jour, objets qui bougent, alerte de prix.
--   Scan et réglages : le panneau d'avant (scan, alertes de prix, listes, ventes) et les réglages de la vente.
-- Réglage AHScan:Config().tabs (sinon la fenêtre du jeu et l'ancien panneau sur le côté).
local S = WK.modules.AHScan
local A = WK.modules.AHSell
local AH = function() return C_AuctionHouse end
local THROTTLE = 1.1

local function cfg()
    local c = S:Config()
    if c.tabs == nil then c.tabs = true end
    c.postDur = c.postDur or tonumber(WK.GetCVar("auctionHouseDurationDropdown") or "") or 2
    if c.postDur < 1 or c.postDur > 3 then c.postDur = 2 end
    c.posts = c.posts or {}
    c.sellFav, c.sellHidden, c.qtyMode = c.sellFav or {}, c.sellHidden or {}, c.qtyMode or {}
    if c.askBad == nil then c.askBad = true end
    c.searches, c.recent = c.searches or {}, c.recent or {}
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
-- Équipement : la clé exacte (niveau d'objet, suffixe) est lue sur l'exemplaire des sacs ; une clé refaite à
-- partir du seul numéro ne le trouve pas et la recherche restait sur « recherche… »
local function bagItemKey(id)
    local a = AH()
    if not (a and a.GetItemKeyFromItem and _G.ItemLocation and _G.ItemLocation.CreateFromBagAndSlot) then return nil end
    if isCommodity(id) then return nil end
    for bag = 0, 4 do
        for slot = 1, (WK.Container.NumSlots(bag) or 0) do
            if WK.Container.Info(bag, slot) == id then
                local ok, k = pcall(a.GetItemKeyFromItem, _G.ItemLocation:CreateFromBagAndSlot(bag, slot))
                if ok and k then return k end
            end
        end
    end
end
-- (la clé lue sur un exemplaire des sacs n'est plus prise d'office : le premier exemplaire trouvé pouvait être une
-- autre variante du même objet, « … de l'Ours » au lieu de « … du Singe », et un achat aurait visé la mauvaise)
UI.AHBagItemKey = bagItemKey
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
                table.insert(rows, { unit = math.floor(r.buyoutAmount / math.max(1, q)), qty = q, buyout = r.buyoutAmount, mine = r.containsOwnerItem and true or false, auctionID = r.auctionID })
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
    -- prix « sans appâts » des autres vendeurs (mêmes paliers que le scan, tes enchères à part) : avant, le plus
    -- bas brut, appât à 1 pc compris, devenait le cours du jour et faussait garde-fous et moyenne 7 j
    local r = results[id]
    if r then
        local tiers, qty = {}, 0
        for _, row in ipairs(r.rows) do
            if not row.mine and row.unit then
                qty = qty + (row.qty or 1)
                tiers[#tiers + 1] = { row.unit, row.qty or 1 }
            end
        end
        table.sort(tiers, function(a, b) return a[1] < b[1] end)
        local low = S.RobustTiers and S.RobustTiers(tiers, qty)
        if low then pcall(S.SeenToday, S, id, low, qty) end
    end
    if pending == id then pending = nil end
    if view and view:IsShown() then view:Refresh() end
end
WK:On("COMMODITY_SEARCH_RESULTS_UPDATED", function(id) onResults(id) end)
WK:On("ITEM_SEARCH_RESULTS_UPDATED", function(key) onResults(type(key) == "table" and key.itemID or key) end)
-- plus bas des autres vendeurs, sans un appât : un lot isolé (au plus 10 % de ce qui est en vente) à moins de la
-- moitié du prix suivant (1 exemplaire à 1 pc) est sauté ; avant, le prix proposé suivait l'appât
local function lowestOther(id)
    local r = results[id]
    if not r then return nil end
    -- paliers des autres vendeurs (lignes triées du moins cher), même règle que le prix du scan
    local tiers, total = {}, 0
    for _, row in ipairs(r.rows) do
        if not row.mine and row.unit then
            local q = row.qty or 1
            total = total + q
            local last = tiers[#tiers]
            if last and last[1] == row.unit then last[2] = last[2] + q
            else tiers[#tiers + 1] = { row.unit, q } end
        end
    end
    if tiers[1] then
        table.sort(tiers, function(a, b) return a[1] < b[1] end)
        return S.RobustTiers(tiers, total)
    end
    return nil, r.rows[1] and r.rows[1].mine
end
-- Achat de marchandise en deux clics (prix demandé au jeu, puis confirmation). La confirmation ne vaut que pour
-- la quantité dont le prix a été demandé : quantité changée entre-temps (200 demandés puis 2 voulus), ou autre
-- ligne cliquée, = ancienne demande annulée et nouveau prix demandé (avant, la confirmation achetait l'ancienne
-- quantité). extra : champs en plus pour S.buy (liste d'achat…). Rend vrai si quelque chose a été envoyé.
local function commodityClick(id, want, extra)
    local a = AH()
    if not (id and want and want > 0 and a and a.StartCommoditiesPurchase) then return false end
    local b = S.buy
    if b and b.id == id and b.phase == "confirm" then
        if b.qty == want then
            if not S:DearCheck(b) then return false end
            S:Stamp(b, "wait")
            if not pcall(a.ConfirmCommoditiesPurchase, id, b.qty) then b.phase = nil; WK:Print(T("Achat refusé par le jeu.")) end
            return true
        end
        if a.CancelCommoditiesPurchase then pcall(a.CancelCommoditiesPurchase) end
        S.buy, b = nil, nil
    elseif b and b.phase == "confirm" then
        -- prix en attente pour un autre objet : abandonné
        if a.CancelCommoditiesPurchase then pcall(a.CancelCommoditiesPurchase) end
        S.buy, b = nil, nil
    end
    -- réponse du jeu attendue ; restée sans réponse trop longtemps : abandonnée (avant, tout restait bloqué)
    if b and (b.phase == "quote" or b.phase == "wait") then
        if not S:Stuck(b) then return false end
        S:Unstick()
    end
    local nb = { id = id, qty = want, skip = {}, spent = 0, count = 0 }
    for k, v in pairs(extra or {}) do nb[k] = v end
    S.buy = nb
    S:Stamp(nb, "quote")
    if not pcall(a.StartCommoditiesPurchase, id, want) then S.buy = nil; WK:Print(T("Le jeu a refusé la demande de prix.")) return false end
    return true
end
UI.AHCommodityClick = commodityClick
-- achat d'une enchère unique (PlaceBid, au prix d'achat immédiat) : le 1er clic arme le bouton (« Confirmer »),
-- un 2e clic sur la même enchère dans les 5 s achète ; un clic égaré n'achète rien
local bidArm
local function bidArmed(x) return bidArm ~= nil and x ~= nil and bidArm.id == x.auctionID and GetTime() - bidArm.at < 5 end
local function armBid(x)
    if bidArmed(x) then bidArm = nil return true end
    bidArm = { id = x.auctionID, at = GetTime() }
    return false
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
    local by, list, hiddenSeen, hiddenList = {}, {}, {}, {}
    for bag = 0, 4 do
        for slot = 1, WK.Container.NumSlots(bag) or 0 do
            local id, count, _, bound = WK.Container.Info(bag, slot)
            if id and cfg().sellHidden[id] and sellable(bag, slot, id, bound) then
                if not hiddenSeen[id] then table.insert(hiddenList, { id = id, count = 0, bag = bag, slot = slot, hidden = true }) end
                hiddenSeen[id] = true
                for _, h in ipairs(hiddenList) do if h.id == id then h.count = h.count + (count or 1) end end
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
    for _, e in ipairs(hiddenList) do e.value = (S:Price(e.id) or 0) * e.count end
    return list, by, nh, hiddenList
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
local NAV = {
    { "browse", "Parcourir", "search" }, { "sell", "Vendre", "coin" }, { "cancel", "Mes enchères", "clock" },
    { "buy", "À acheter", "bag" }, { "prices", "Prix", "chart" }, { "scan", "Scan et réglages", "gear" },
}
local WIN_W, WIN_H, SIDE_W, HEAD_H = 1180, 660, 196, 46

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
    -- notre fenêtre, posée sur celle du jeu (rendue invisible tant que la nôtre est ouverte)
    local f = CreateFrame("Frame", "WarbandKeeperAH", UIParent)
    f:SetSize(WIN_W, WIN_H)
    f:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
    local strata = host:GetFrameStrata()
    f:SetFrameStrata((strata == "HIGH" or strata == "DIALOG") and "DIALOG" or "HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    UI:Panel(f, 12, { C.bg[1], C.bg[2], C.bg[3], 0.99 }, C.border)
    f:Hide()
    f.host = host
    f.views = {}

    -- barre de titre : nom, royaume, scan (barre + bouton), or, retour à la fenêtre du jeu, fermer
    local head = CreateFrame("Frame", nil, f)
    head:SetPoint("TOPLEFT"); head:SetPoint("TOPRIGHT"); head:SetHeight(HEAD_H)
    head.line = head:CreateTexture(nil, "ARTWORK")
    head.line:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
    head.line:SetPoint("BOTTOMLEFT"); head.line:SetPoint("BOTTOMRIGHT"); head.line:SetHeight(1)
    f.logo = UI:Icon(head, "coin", 18); f.logo:SetPoint("LEFT", 14, 0)
    f.head = UI:Text(head, 14); f.head:SetPoint("LEFT", f.logo, "RIGHT", 8, 0)
    f.head:SetText(T("Hôtel des ventes"))
    f.headSub = UI:Text(head, 11, C.muted); f.headSub:SetPoint("LEFT", f.head, "RIGHT", 8, 0)
    f.close = UI:IconButton(head, "close", 26, "Fermer l'hôtel des ventes")
    f.close:SetPoint("RIGHT", -10, 0)
    f.close:SetScript("OnClick", function()
        local a = AH()
        if a and a.CloseAuctionHouse then pcall(a.CloseAuctionHouse) elseif HideUIPanel then HideUIPanel(host) end
    end)
    f.game = UI:Button(head, "Fenêtre du jeu", nil, 26, "secondary")
    f.game:SetPoint("RIGHT", f.close, "LEFT", -10, 0)
    f.game.tooltip = "Revenir à l'hôtel des ventes du jeu pour le reste de cette visite."
    f.game:SetScript("OnClick", function() f.gameMode = true; f:Close() end)
    f.gold = UI:Text(head, 12, C.gold); f.gold:SetPoint("RIGHT", f.game, "LEFT", -16, 0)
    f.scanBtn = UI:Button(head, "Scanner", nil, 24, "secondary")
    f.scanBtn:SetPoint("LEFT", f.headSub, "RIGHT", 24, 0)
    f.scanBtn:SetScript("OnClick", function() S:Start() end)
    f.scanBar = CreateFrame("Frame", nil, head)
    f.scanBar:SetSize(110, 6); f.scanBar:SetPoint("LEFT", f.scanBtn, "RIGHT", 10, 0)
    f.scanBar.bg = UI:Rounded(f.scanBar, 3, 0, "BACKGROUND", 1)
    f.scanBar.bg:SetColor(C.border[1], C.border[2], C.border[3], 1)
    f.scanBar.fillF = CreateFrame("Frame", nil, f.scanBar)
    f.scanBar.fillF:SetPoint("TOPLEFT"); f.scanBar.fillF:SetPoint("BOTTOMLEFT")
    f.scanBar.fill = UI:Rounded(f.scanBar.fillF, 3, 0, "ARTWORK", 1)
    f.scanInfo = UI:Text(head, 10, C.muted); f.scanInfo:SetPoint("LEFT", f.scanBar, "RIGHT", 8, 0)

    -- barre latérale : pages, puis tes recherches (enregistrées et récentes)
    local side = CreateFrame("Frame", nil, f)
    side:SetPoint("TOPLEFT", 0, -HEAD_H); side:SetPoint("BOTTOMLEFT"); side:SetWidth(SIDE_W)
    side.line = side:CreateTexture(nil, "ARTWORK")
    side.line:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
    side.line:SetPoint("TOPRIGHT"); side.line:SetPoint("BOTTOMRIGHT"); side.line:SetWidth(1)
    f.side = side
    f.nav = {}
    for i, def in ipairs(NAV) do
        local b = CreateFrame("Button", nil, side)
        b:SetHeight(30)
        b:SetPoint("TOPLEFT", 8, -10 - (i - 1) * 32); b:SetPoint("TOPRIGHT", -8, -10 - (i - 1) * 32)
        b.bg = UI:Rounded(b, 8, 0, "BACKGROUND", 1)
        b.icon = UI:Icon(b, def[3], 14); b.icon:SetPoint("LEFT", 10, 0)
        b.text = UI:Text(b, 12); b.text:SetPoint("LEFT", 32, 0); b.text:SetText(T(def[2]))
        b.pill = CreateFrame("Frame", nil, b)
        b.pill:SetSize(20, 16); b.pill:SetPoint("RIGHT", -8, 0)
        b.pill.bg = UI:Rounded(b.pill, 8, 0, "BACKGROUND", 1)
        b.pill.t = UI:Text(b.pill, 10, C.onAccent); b.pill.t:SetPoint("CENTER")
        b.pill:Hide()
        function b:Paint()
            local r, g, bl = UI:Accent()
            local on = f.tab == def[1]
            self.bg:SetColor(r, g, bl, on and 0.16 or (self.hover and 0.07 or 0))
            self.text:SetTextColor(unpack(on and C.text or C.muted))
            self.icon:SetVertexColor(r, g, bl, on and 1 or 0.75)
        end
        function b:SetCount(n, col)
            self.pill:SetShown(n and n > 0)
            if not (n and n > 0) then return end
            self.pill.t:SetText(n)
            self.pill:SetWidth(math.max(18, self.pill.t:GetStringWidth() + 10))
            local r, g, bl = UI:Accent()
            if col then r, g, bl = col[1], col[2], col[3] end
            self.pill.bg:SetColor(r, g, bl, 1)
        end
        b:SetScript("OnEnter", function(s) s.hover = true; s:Paint() end)
        b:SetScript("OnLeave", function(s) s.hover = false; s:Paint() end)
        b:SetScript("OnClick", function() f:Open(def[1]) end)
        f.nav[def[1]] = b
    end
    f.searchHead = UI:Text(side, 9, C.dim)
    f.searchHead:SetPoint("TOPLEFT", 16, -22 - #NAV * 32)
    f.searchHead:SetText(UI:Upper(T("Recherches")))
    f.srows = {}
    for i = 1, 10 do
        local r = CreateFrame("Button", nil, side)
        r:SetHeight(22)
        r:SetPoint("TOPLEFT", 8, -38 - #NAV * 32 - (i - 1) * 23); r:SetPoint("TOPRIGHT", -8, -38 - #NAV * 32 - (i - 1) * 23)
        if r.RegisterForClicks then r:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
        r.bg = UI:Rounded(r, 6, 0, "BACKGROUND", 1); r.bg:SetColor(1, 1, 1, 0)
        r.icon = UI:Icon(r, "star", 11); r.icon:SetPoint("LEFT", 10, 0)
        r.t = UI:Text(r, 11, C.muted); r.t:SetPoint("LEFT", 28, 0); r.t:SetPoint("RIGHT", -6, 0); r.t:SetJustifyH("LEFT")
        if r.t.SetWordWrap then r.t:SetWordWrap(false) end
        r:SetScript("OnEnter", function(s)
            local ar, ag, ab = UI:Accent(); s.bg:SetColor(ar, ag, ab, 0.08)
            if not s.q then return end
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetText(s.q.name or s.q.text or "", 1, 1, 1)
            GameTooltip:AddLine(T("Clic : relancer cette recherche"), 0.6, 0.6, 0.6)
            GameTooltip:AddLine(s.saved and T("Clic droit : retirer") or T("Clic droit : enregistrer"), 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function(s) s.bg:SetColor(1, 1, 1, 0); GameTooltip:Hide() end)
        r:SetScript("OnClick", function(s, button)
            if not s.q then return end
            if button == "RightButton" then
                local c = cfg()
                if s.saved then table.remove(c.searches, s.index)
                else table.insert(c.searches, s.q) end
                f:RefreshSide()
                return
            end
            f:Open("browse")
            f.views.browse:Run(s.q)
        end)
        f.srows[i] = r
    end
    function f:RefreshSide()
        local c = cfg()
        local list = {}
        for i, q in ipairs(c.searches) do table.insert(list, { q = q, saved = true, index = i }) end
        for _, q in ipairs(c.recent) do
            local dup = false
            for _, sq in ipairs(c.searches) do if sq.key == q.key then dup = true end end
            if not dup then table.insert(list, { q = q }) end
        end
        local room = math.max(0, math.floor((side:GetHeight() - 48 - #NAV * 32) / 23))
        f.searchHead:SetShown(#list > 0)
        for i, r in ipairs(self.srows) do
            local e = i <= room and list[i]
            r.q, r.saved, r.index = e and e.q, e and e.saved, e and e.index
            if e then
                r.t:SetText(e.q.name or e.q.text ~= "" and e.q.text or T("(catégorie)"))
                r.icon:SetTexture(UI.MEDIA .. (e.saved and "star" or "refresh"))
                local ar, ag, ab = UI:Accent()
                r.icon:SetVertexColor(ar, ag, ab, e.saved and 1 or 0.6)
                r:Show()
            else r:Hide() end
        end
    end

    f.content = CreateFrame("Frame", nil, f)
    f.content:SetPoint("TOPLEFT", SIDE_W + 12, -HEAD_H - 12)
    f.content:SetPoint("BOTTOMRIGHT", -12, 12)

    function f:Open(key)
        cfg().ahTab = key
        self.tab = key
        for _, b in pairs(self.nav) do b:Paint() end
        for k, v in pairs(self.views) do v:SetShown(k == key) end
        if not self:IsShown() then
            -- la fenêtre du jeu reste ouverte (ses évènements) mais invisible, sous la nôtre
            self.hostAlpha = host:GetAlpha()
            host:SetAlpha(0)
            self:Show()
            if self.back then self.back:Hide() end
        end
        if key == "cancel" then A:Query() end
        self:Refresh()
    end
    function f:Close()
        self:Hide()
        host:SetAlpha(self.hostAlpha or 1)
        -- retour à la nôtre depuis la fenêtre du jeu
        if self.gameMode and host:IsShown() then
            if not self.back then
                self.back = UI:Button(host, "Warband Keeper", nil, 24, "primary", "coin")
                self.back:SetPoint("TOPRIGHT", host, "TOPRIGHT", -34, -2)
                self.back:SetFrameLevel(host:GetFrameLevel() + 50)
                self.back:SetScript("OnClick", function() f.gameMode = false; f:Open(cfg().ahTab or "browse") end)
            end
            self.back:Show()
        end
    end
    f:SetScript("OnSizeChanged", function() f:RefreshSide() end)

    -----------------------------------------------------------------------
    -- Courbe des prix (plus bas de chaque jour, moyenne en tirets or), commune à Parcourir et Prix
    -----------------------------------------------------------------------
    local function makeChart(parent)
        local ch = CreateFrame("Frame", nil, parent)
        ch.plot = CreateFrame("Frame", nil, ch)
        ch.plot:SetPoint("TOPLEFT", 54, -4); ch.plot:SetPoint("BOTTOMRIGHT", -6, 4)
        local ax = ch.plot:CreateTexture(nil, "BACKGROUND"); ax:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
        ax:SetPoint("BOTTOMLEFT"); ax:SetPoint("BOTTOMRIGHT"); ax:SetHeight(1)
        local ay = ch.plot:CreateTexture(nil, "BACKGROUND"); ay:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
        ay:SetPoint("TOPLEFT"); ay:SetPoint("BOTTOMLEFT"); ay:SetWidth(1)
        ch.yTop = UI:Text(ch, 9, C.dim); ch.yTop:SetPoint("TOPRIGHT", ch.plot, "TOPLEFT", -4, 0)
        ch.yBot = UI:Text(ch, 9, C.dim); ch.yBot:SetPoint("BOTTOMRIGHT", ch.plot, "BOTTOMLEFT", -4, 0)
        ch.lines = UI:LinePool(4)
        ch.dots = {}
        ch.empty = UI:Text(ch, 11, C.muted); ch.empty:SetPoint("CENTER")
        local function dot(i)
            local d = ch.dots[i]
            if not d then
                d = CreateFrame("Button", nil, ch.plot)
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
                ch.dots[i] = d
            end
            return d
        end
        ch.bars = {}
        -- days : 7, 14 ou 30 (14 par défaut) ; opts.mine = ton prix moyen de vente (pointillés verts),
        -- opts.bars = quantité en vente de chaque jour (barres bleues)
        function ch:Draw(id, days, opts)
            days = days or 14
            opts = opts or {}
            self.lines:Reset()
            for _, d in ipairs(self.dots) do d:Hide() end
            for _, b in ipairs(self.bars) do b:Hide() end
            local all = id and S:History(id) or {}
            local today0 = math.floor(time() / 86400)
            local hist = {}
            for _, h in ipairs(all) do if h[1] > today0 - days then table.insert(hist, h) end end
            local avg
            if #hist > 0 then
                local sum = 0
                for _, h in ipairs(hist) do sum = sum + h[2] end
                avg = math.floor(sum / #hist + 0.5)
            end
            self.empty:SetShown(#hist < 1)
            self.empty:SetText(id and T("Pas encore de prix relevé pour cet objet : lance un scan.") or "")
            if #hist < 1 then self.yTop:SetText(""); self.yBot:SetText(""); return hist, avg end
            local lo, hi = math.huge, 0
            for _, h in ipairs(hist) do lo = math.min(lo, h[2]); hi = math.max(hi, h[2]) end
            if avg then lo, hi = math.min(lo, avg), math.max(hi, avg) end
            if opts.mine then lo, hi = math.min(lo, opts.mine), math.max(hi, opts.mine) end
            if hi == lo then hi = lo + 1 end
            local pad = (hi - lo) * 0.1
            lo, hi = math.max(0, lo - pad), hi + pad
            self.yTop:SetText(money(math.floor(hi))); self.yBot:SetText(money(math.floor(lo)))
            local W, H = self.plot:GetWidth() or 400, self.plot:GetHeight() or 150
            local today = math.floor(time() / 86400)
            local first = today - (days - 1)
            local function px(day) return (day - first) / (days - 1) * W end
            local function py(p) return H - (p - lo) / (hi - lo) * H end
            -- quantité en vente : barres en bas (le quart de la hauteur)
            if opts.bars then
                local qmax = 0
                for _, h in ipairs(hist) do qmax = math.max(qmax, h[3] or 0) end
                for i, h in ipairs(hist) do
                    if (h[3] or 0) > 0 and qmax > 0 then
                        local b = self.bars[i]
                        if not b then b = self.plot:CreateTexture(nil, "BACKGROUND", nil, 2); self.bars[i] = b end
                        b:SetColorTexture(C.info[1], C.info[2], C.info[3], 0.3)
                        local bh = math.max(2, h[3] / qmax * H * 0.25)
                        b:ClearAllPoints()
                        b:SetPoint("BOTTOM", self.plot, "BOTTOMLEFT", px(h[1]), 1)
                        b:SetSize(math.max(3, math.min(12, W / days * 0.5)), bh)
                        b:Show()
                    end
                end
            end
            if opts.mine then
                local k, my = 0, py(opts.mine)
                while k < W do
                    self.lines:Add(self.plot, k, my, math.min(W, k + 3), my, 1.5, C.positive[1], C.positive[2], C.positive[3], 0.85)
                    k = k + 7
                end
            end
            if avg then
                local k = 0
                while k < W do
                    self.lines:Add(self.plot, k, py(avg), math.min(W, k + 8), py(avg), 1.5, C.gold[1], C.gold[2], C.gold[3], 0.8)
                    k = k + 14
                end
            end
            local ar, ag, ab = UI:Accent()
            local prevX, prevY
            for i, h in ipairs(hist) do
                if h[1] >= first then
                    local x, y = px(h[1]), py(h[2])
                    if prevX then self.lines:Add(self.plot, prevX, prevY, x, y, 2.5, ar, ag, ab, 1) end
                    prevX, prevY = x, y
                    local d = dot(i)
                    d.day, d.price, d.qty = h[1], h[2], h[3]
                    d.t:SetVertexColor(ar, ag, ab, 1)
                    d:ClearAllPoints(); d:SetPoint("CENTER", self.plot, "TOPLEFT", x, -y)
                    d:Show()
                end
            end
            return hist, avg
        end
        return ch
    end

    -----------------------------------------------------------------------
    -- Vente
    -----------------------------------------------------------------------
    local sv = CreateFrame("Frame", nil, f.content)
    sv:SetAllPoints(f.content)
    f.views.sell = sv
    -- à gauche : tes sacs en liste (nom, quantité, valeur à l'HV), filtre et pastilles Tout / Favoris / Rangement / Cachés
    sv.bags = panelBox(sv, "Tes sacs")
    sv.bags:SetPoint("TOPLEFT"); sv.bags:SetPoint("BOTTOMLEFT"); sv.bags:SetWidth(300)
    sv.filter = UI:Input(sv.bags, 280, 26, "Filtrer…", "search")
    sv.filter:SetPoint("TOPLEFT", 10, -28)
    sv.filter.onChange = function() sv.offset = 0; sv:Refresh() end
    sv.mode, sv.offset = "all", 0
    sv.modes = {}
    local mx = 10
    for _, md in ipairs({ { "all", "Tout" }, { "fav", "Favoris" }, { "stash", "Rangement" }, { "hidden", "Cachés" } }) do
        local b = UI:Button(sv.bags, md[2], nil, 22, "ghost")
        b:SetWidth(b.label:GetStringWidth() + 18)
        b:SetPoint("TOPLEFT", mx, -60)
        mx = mx + b:GetWidth() + 3
        b:SetScript("OnClick", function() sv.mode = md[1]; sv.offset = 0; sv:Refresh() end)
        sv.modes[md[1]] = b
    end
    sv.brows = {}
    local BROW = 26
    for i = 1, 18 do
        local r = textRow(sv.bags, BROW - 2)
        r:SetPoint("TOPLEFT", 6, -90 - (i - 1) * BROW); r:SetPoint("TOPRIGHT", -6, -90 - (i - 1) * BROW)
        r.a:SetPoint("RIGHT", -110, 0)
        r.b:SetPoint("RIGHT", -70, 0); r.b:SetWidth(40); r.b:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
        r.c:SetPoint("RIGHT", -6, 0); r.c:SetWidth(64)
        r.tag = UI:Icon(r, "star", 10); r.tag:SetPoint("RIGHT", r.b, "LEFT", -4, 0)
        if r.RegisterForClicks then r:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
        r:SetScript("OnClick", function(s, button)
            local e = s.e
            if not e then return end
            local c = cfg()
            if e.hidden then
                -- objet caché : clic (gauche ou droit) pour le réafficher
                c.sellHidden[e.id] = nil
                sv:Refresh()
                return
            end
            if button == "RightButton" then
                -- clic droit : favori (en tête) ; Maj + clic droit : ne plus proposer cet objet
                if IsShiftKeyDown and IsShiftKeyDown() then c.sellHidden[e.id] = true; c.sellFav[e.id] = nil
                else c.sellFav[e.id] = (not c.sellFav[e.id]) or nil end
                sv:Refresh()
                return
            end
            sv:Select(e.id)
        end)
        r:SetScript("OnEnter", function(s)
            if not s.e then return end
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            if GameTooltip.SetItemByID then GameTooltip:SetItemByID(s.e.id) end
            GameTooltip:AddLine(" ")
            if s.e.hidden then GameTooltip:AddLine(T("Clic : le proposer de nouveau"), 0.6, 0.6, 0.6)
            else
                GameTooltip:AddLine(cfg().sellFav[s.e.id] and T("Clic droit : retirer des favoris") or T("Clic droit : favori (en tête)"), 0.6, 0.6, 0.6)
                GameTooltip:AddLine(T("Maj + clic droit : ne plus proposer"), 0.6, 0.6, 0.6)
            end
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        r:Hide()
        sv.brows[i] = r
    end
    sv.bags:EnableMouseWheel(true)
    sv.bags:SetScript("OnMouseWheel", function(_, d) sv.offset = math.max(0, sv.offset - d * 3); sv:Refresh() end)
    sv.bagNote = UI:Text(sv.bags, 10, C.dim); sv.bagNote:SetPoint("BOTTOMLEFT", 10, 10); sv.bagNote:SetPoint("BOTTOMRIGHT", -10, 10)
    sv.bagNote:SetJustifyH("LEFT")
    if sv.bagNote.SetWordWrap then sv.bagNote:SetWordWrap(true) end
    sv.bagNote:SetText(T("Clic droit : favori · Maj + clic droit : cacher · étoile : à vendre d'après le Rangement · clic droit sur un objet des sacs du jeu : il arrive ici"))

    sv.right = panelBox(sv, "En vente")
    sv.right:SetPoint("TOPRIGHT"); sv.right:SetPoint("BOTTOMRIGHT"); sv.right:SetWidth(280)
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
                if armBid(x) and not pcall(a.PlaceBid, x.auctionID, x.buyout or x.unit * x.qty) then WK:Print(T("Achat refusé par le jeu.")) end
            elseif a and a.StartCommoditiesPurchase then
                commodityClick(id, x.qty)
            end
            sv:Refresh()
        end)
        sv.lrows[i] = r
    end
    -- courbe des prix de l'objet (14 jours), en bas de la colonne
    sv.chart = makeChart(sv.right)
    sv.chart:SetPoint("BOTTOMLEFT", 2, 26); sv.chart:SetPoint("BOTTOMRIGHT", -6, 26); sv.chart:SetHeight(110)
    sv.chartNote = UI:Text(sv.right, 9, C.dim); sv.chartNote:SetPoint("BOTTOMLEFT", 10, 10)
    sv.chartNote:SetText(T("14 jours · tirets : moyenne"))
    sv.hist = UI:Text(sv.right, 10, C.muted); sv.hist:SetPoint("TOPLEFT", 10, -232); sv.hist:SetPoint("TOPRIGHT", -10, -232)
    sv.hist:SetJustifyH("LEFT"); sv.hist:SetJustifyV("TOP")
    if sv.hist.SetSpacing then sv.hist:SetSpacing(3) end

    sv.mid = panelBox(sv, "")
    sv.mid:SetPoint("TOPLEFT", sv.bags, "TOPRIGHT", 8, 0); sv.mid:SetPoint("BOTTOMRIGHT", sv.right, "BOTTOMLEFT", -8, 0)
    sv.mid.title:Hide()
    sv.itemIcon = sv.mid:CreateTexture(nil, "ARTWORK"); sv.itemIcon:SetSize(36, 36); sv.itemIcon:SetPoint("TOPLEFT", 12, -12)
    sv.itemIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    sv.itemName = UI:Text(sv.mid, 13); sv.itemName:SetPoint("TOPLEFT", 56, -12); sv.itemName:SetPoint("TOPRIGHT", -12, -12)
    sv.itemName:SetJustifyH("LEFT")
    if sv.itemName.SetWordWrap then sv.itemName:SetWordWrap(false) end
    sv.itemSub = UI:Text(sv.mid, 10, C.muted); sv.itemSub:SetPoint("TOPLEFT", 56, -29); sv.itemSub:SetPoint("TOPRIGHT", -12, -29)
    sv.itemSub:SetJustifyH("LEFT")
    sv.rank = UI:Text(sv.mid, 10, C.muted); sv.rank:SetPoint("TOPLEFT", 56, -42); sv.rank:SetPoint("TOPRIGHT", -12, -42)
    sv.rank:SetJustifyH("LEFT")
    local function label(txt, y, x)
        local l = UI:Text(sv.mid, 9, C.dim); l:SetPoint("TOPLEFT", x or 12, y); l:SetText(UI:Upper(T(txt)))
        return l
    end
    label("Prix unitaire", -62)
    sv.price = UI:Input(sv.mid, 160, 28, "ex. 1po 61pa 99", nil)
    sv.price:SetPoint("TOPLEFT", 12, -74)
    sv.priceHint = UI:Text(sv.mid, 10, C.muted); sv.priceHint:SetPoint("TOPLEFT", 12, -106); sv.priceHint:SetPoint("TOPRIGHT", -12, -106)
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
    sv.total = UI:Text(sv.mid, 12); sv.total:SetPoint("TOPLEFT", 12, -214); sv.total:SetPoint("TOPRIGHT", -12, -214); sv.total:SetJustifyH("LEFT")
    sv.deposit = UI:Text(sv.mid, 10, C.muted); sv.deposit:SetPoint("TOPLEFT", 12, -232); sv.deposit:SetPoint("TOPRIGHT", -12, -232); sv.deposit:SetJustifyH("LEFT")
    -- jauge : où tombe ton prix, de bon marché à cher, face au plus bas des autres et à la moyenne de la semaine
    sv.gauge = CreateFrame("Frame", nil, sv.mid)
    sv.gauge:SetPoint("TOPLEFT", 12, -258); sv.gauge:SetPoint("TOPRIGHT", -12, -258); sv.gauge:SetHeight(8)
    sv.gauge.bg = UI:Rounded(sv.gauge, 4, 0, "BACKGROUND", 1); sv.gauge.bg:SetColor(C.border[1], C.border[2], C.border[3], 1)
    sv.gauge.fillF = CreateFrame("Frame", nil, sv.gauge); sv.gauge.fillF:SetPoint("TOPLEFT"); sv.gauge.fillF:SetPoint("BOTTOMLEFT")
    sv.gauge.fill = UI:Rounded(sv.gauge.fillF, 4, 0, "ARTWORK", 1)
    sv.gLo = UI:Text(sv.mid, 9, C.dim); sv.gLo:SetPoint("TOPLEFT", sv.gauge, "BOTTOMLEFT", 0, -4); sv.gLo:SetText(T("bon marché"))
    sv.gHi = UI:Text(sv.mid, 9, C.dim); sv.gHi:SetPoint("TOPRIGHT", sv.gauge, "BOTTOMRIGHT", 0, -4); sv.gHi:SetText(T("cher"))
    sv.gMid = UI:Text(sv.mid, 10, C.muted); sv.gMid:SetPoint("TOP", sv.gauge, "BOTTOM", 0, -16)
    sv.keys = UI:Text(sv.mid, 9, C.dim); sv.keys:SetPoint("BOTTOMLEFT", 12, 50); sv.keys:SetPoint("BOTTOMRIGHT", -12, 50); sv.keys:SetJustifyH("LEFT")
    sv.post = UI:Button(sv.mid, "Mettre en vente", nil, 32, "primary")
    sv.post:SetPoint("BOTTOMLEFT", 12, 12); sv.post:SetPoint("BOTTOMRIGHT", -96, 12)
    sv.skip = UI:Button(sv.mid, "Passer", 76, 32, "secondary"); sv.skip:SetPoint("BOTTOMRIGHT", -12, 12)
    -- garde-fou : prix très sous le cours ou sous le prix du marchand
    sv.warn = CreateFrame("Frame", nil, sv.mid)
    sv.warn:SetPoint("BOTTOMLEFT", 12, 50); sv.warn:SetPoint("BOTTOMRIGHT", -12, 50); sv.warn:SetHeight(64)
    UI:Panel(sv.warn, 8, { C.negative[1] * 0.25, C.negative[2] * 0.25, C.negative[3] * 0.25, 0.95 }, C.negative)
    sv.warn.t = UI:Text(sv.warn, 11); sv.warn.t:SetPoint("TOPLEFT", 10, -8); sv.warn.t:SetPoint("TOPRIGHT", -10, -8); sv.warn.t:SetJustifyH("LEFT")
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
        -- ce que tu touches : prix moins la commission de 5 % (le dépôt est rendu à la vente)
        local net = unit and math.floor(unit * qty * 0.95) or nil
        self.deposit:SetText((dep and (T("Dépôt") .. " : " .. money(dep) .. "  ·  ") or "") .. T("commission 5 %")
            .. (net and ("  ·  " .. T("tu touches") .. " " .. money(net)) or ""))
        local low = lowestOther(id)
        local avg = S:Average(id, 7)
        local ref = low or avg
        local show = unit ~= nil and ref ~= nil
        for _, w in ipairs({ self.gauge, self.gLo, self.gHi, self.gMid }) do w:SetShown(show) end
        if show then
            -- bon marché à moitié du cours, cher à une fois et demie
            local frac = math.max(0.03, math.min(1, (unit - ref * 0.5) / ref))
            local w = self.gauge:GetWidth() or 200
            self.gauge.fillF:SetWidth(math.max(2, w * frac))
            local col = frac < 0.35 and C.negative or frac <= 0.55 and C.positive or C.warning
            self.gauge.fill:SetColor(col[1], col[2], col[3], 1)
            local parts = {}
            if low then
                local d = unit - low
                table.insert(parts, d < 0 and string.format(T("%s sous le moins cher"), money(-d)) or d == 0 and T("au prix du moins cher") or string.format(T("%s au-dessus du moins cher"), money(d)))
            end
            if avg then table.insert(parts, T("moyenne 7 j") .. " " .. money(avg)) end
            self.gMid:SetText(table.concat(parts, "  ·  "))
        end
        local ready = not (a and a.IsThrottledMessageSystemReady) or a.IsThrottledMessageSystemReady()
        self.post:SetEnabled(unit ~= nil and unit > 0 and ready)
        self.keys:SetShown(cfg().postKeys and not self.warn:IsShown())
        self.keys:SetText(T("Touches : Espace = mettre en vente · S = passer · Haut / Bas = palier de prix"))
    end
    -- objet suivant : jamais un objet verrouillé par une règle (épique, envie, BiS, recette…), qu'on enchaînait
    -- sinon avec Espace ; il reste dans la liste pour une mise en vente voulue (clic, puis confirmation)
    local function nextItem()
        local IL = WK.modules.ItemLock
        local list = {}
        for _, x in ipairs(bagItems()) do
            if x.id == sv.id or not (IL and IL:Reason(x.id)) then list[#list + 1] = x end
        end
        for i, x in ipairs(list) do
            if x.id == sv.id then
                local n = list[i + 1] or list[1]
                if n and n.id ~= sv.id then sv:Select(n.id) else sv.id, sv.e = nil, nil; sv:Refresh() end
                return
            end
        end
        if list[1] then sv:Select(list[1].id) else sv.id, sv.e = nil, nil; sv:Refresh() end
    end
    sv.NextItem = nextItem
    sv.skip:SetScript("OnClick", nextItem)
    -- garde-fou : prix pour un, après la commission (5 %), pas plus que ce que paie le marchand ; ou, sous le
    -- prix proposé, sous une part du cours (plus bas des autres, sinon le scan) : 70 % sous 1 po, 50 % jusqu'à
    -- 50 po, 30 % au-delà ; un zéro oublié (un dixième du prix) est toujours signalé
    local function badPost(id, unit)
        local vendor = select(11, WK.GetItemInfo(id)) or 0
        if vendor > 0 and unit * 0.95 <= vendor then
            return string.format(T("Ce prix (%s) rapporte moins que le marchand (%s)."), money(unit), money(vendor))
        end
        -- cours de référence : le prix du scan (sans appât) en premier, sinon le plus bas des autres ; un prix bien
        -- sous ce cours est signalé même s'il est égal au prix proposé (appât qui serait passé au travers)
        local going = S:Price(id) or lowestOther(id)
        -- la moyenne des 7 derniers jours sert de garde-fou en plus : un scan du jour faussé ne suffit plus
        local avg = S.Average and S:Average(id, 7)
        if avg and (not going or avg > going) then going = avg end
        if going and (unit < (sv.suggested or going) or unit < going * 0.5) then
            local share = going < 10000 and 0.7 or going <= 500000 and 0.5 or 0.3
            if unit < going * share or unit <= going * 0.1 then
                return string.format(T("Prix bien sous le cours (%s) : %s. Un zéro oublié ?"), money(going), money(unit))
            end
        end
    end
    local function doPost(id, e, unit, qty)
        local a = AH()
        -- les sacs ont pu bouger depuis le choix de l'objet (rangement, autre visite) : la case doit encore
        -- contenir cet objet, sinon on le retrouve par son n°, sinon on ne poste rien
        local function holds(b, sl)
            return WK.Container.Info(b, sl) == id
        end
        if not holds(e.bag, e.slot) then
            local found
            for _, it in ipairs(bagItems()) do if it.id == id and holds(it.bag, it.slot) then found = it break end end
            if not found then WK:Print(T("Objet introuvable dans tes sacs : mise en vente annulée.")) return end
            e = found
            qty = math.min(qty, found.count or qty)
        end
        local loc = ItemLocation and ItemLocation:CreateFromBagAndSlot(e.bag, e.slot)
        local dur = cfg().postDur
        local ok, needs
        if isCommodity(id) and a and a.PostCommodity then
            ok, needs = pcall(a.PostCommodity, loc, dur, qty, unit)
            if ok and needs == true and a.ConfirmPostCommodity then pcall(a.ConfirmPostCommodity, loc, dur, qty, unit) end
        elseif a and a.PostItem then
            -- objet non marchandise : chaque exemplaire devient une enchère à ce prix (pas qty fois le prix)
            ok, needs = pcall(a.PostItem, loc, dur, qty, nil, unit)
            if ok and needs == true and a.ConfirmPostItem then pcall(a.ConfirmPostItem, loc, dur, qty, nil, unit) end
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
        -- objet verrouillé par une règle : toujours une confirmation (même garde-fou coupé)
        local IL = WK.modules.ItemLock
        local lock = IL and IL:Reason(id)
        if lock then
            local what = lock == "manual" and T("à la main") or tostring(lock)
            why = string.format(T("Objet verrouillé (%s) : le mettre en vente quand même ?"), what)
                .. (why and ("\n" .. why) or "")
        end
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
        -- en combat on ne touche pas à la propagation (réservé au jeu) : elle est toujours remise à « oui »
        -- juste après une touche gardée, donc rien n'est avalé en combat
        if InCombatLockdown and InCombatLockdown() then return end
        if s.SetPropagateKeyboardInput then
            s:SetPropagateKeyboardInput(not mine)
            if mine then C_Timer.After(0, function()
                if not (InCombatLockdown and InCombatLockdown()) then s:SetPropagateKeyboardInput(true) end
            end) end
        end
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
        local q = string.lower(self.filter:GetText() or "")
        local _, _, _, hiddenList = bagItems()
        local shown, total = {}, 0
        local src = self.mode == "hidden" and hiddenList or list
        for _, e in ipairs(src) do
            local name = WK.GetItemInfo(e.id) or ""
            local ok = q == "" or string.lower(name):find(q, 1, true)
            if ok and self.mode == "fav" then ok = fav[e.id] end
            if ok and self.mode == "stash" then ok = marked[e.id] end
            if ok then table.insert(shown, e) end
        end
        for _, e in ipairs(list) do total = total + (e.value or 0) end
        local fit = math.max(1, math.min(#self.brows, math.floor(((self.bags:GetHeight() or 500) - 140) / BROW)))
        self.offset = math.max(0, math.min(self.offset, #shown - fit))
        local br1, bg1, bb1 = UI:Accent()
        for i, r in ipairs(self.brows) do
            local e = i <= fit and shown[self.offset + i]
            r.e = e
            if e then
                r.icon:SetTexture(itemIcon(e.id))
                local name, _, quality = WK.GetItemInfo(e.id)
                r.a:SetText(name or ("#" .. e.id))
                if quality and GetItemQualityColor then r.a:SetTextColor(GetItemQualityColor(quality)) else r.a:SetTextColor(1, 1, 1) end
                r.b:SetText("x" .. e.count)
                if e.value and e.value > 0 then r.c:SetText(money(e.value)) else r.c:SetText(UI:Hex(C.dim) .. T("pas de prix") .. "|r") end
                r.tag:SetShown(fav[e.id] or marked[e.id] or false)
                if fav[e.id] then r.tag:SetVertexColor(br1, bg1, bb1, 1) else r.tag:SetVertexColor(C.rule[1], C.rule[2], C.rule[3], 1) end
                r.hl:SetColorTexture(br1, bg1, bb1, e.id == self.id and 0.14 or 0)
                r:Show()
            else r:Hide() end
        end
        for k, b in pairs(self.modes) do b:SetStyle(k == self.mode and "primary" or "ghost") end
        self.modes.hidden:SetLabel(hidden > 0 and string.format(T("Cachés (%d)"), hidden) or T("Cachés"))
        self.modes.hidden:SetWidth(self.modes.hidden.label:GetStringWidth() + 18)
        self.bags.sub:SetText(string.format(T("%d à vendre"), #list) .. (total > 0 and ("  ·  " .. money(total)) or ""))
        if self.id and not self.e then self.id = nil end
        local id = self.id
        local has = id ~= nil
        for _, w in ipairs({ self.itemIcon, self.itemName, self.itemSub, self.rank, self.price, self.priceHint, self.qty, self.dur, self.total, self.deposit, self.post, self.skip, self.chart, self.chartNote }) do w:SetShown(has) end
        if not has then for _, w in ipairs({ self.gauge, self.gLo, self.gHi, self.gMid }) do w:Hide() end end
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
        self.chart:Draw(id)
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
                    elseif b and b.id == id and b.phase == "confirm" and isCommodity(id) and b.qty == x.qty then row.act:SetLabel(string.format(T("Confirmer %s"), money(b.total)))
                    elseif bidArmed(x) then row.act:SetLabel(string.format(T("Confirmer %s"), money(x.buyout or x.unit * x.qty)))
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
        for i = 1, #log do -- le journal va du plus récent au plus ancien
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
            if not f:IsShown() then return end
            if f.tab ~= "sell" then f:Open("sell") end
            local ok, id = pcall(C_Item.GetItemID, loc)
            if ok and id then
                if C_Item.UnlockItem then pcall(C_Item.UnlockItem, loc) end
                sv:Select(id)
            end
        end)
    end

    -----------------------------------------------------------------------
    -- À acheter : listes à gauche (la « File de fabrication » en tête, « Prix surveillés »), tableau au milieu
    -- (pour qui, ce qu'il manque, plus bas, en vente, total, l'action qui va), résumé à droite (à l'HV, chez le
    -- marchand, chez tes persos, introuvable, ton or, « Tout acheter » et sa progression).
    -----------------------------------------------------------------------
    local bv = CreateFrame("Frame", nil, f.content)
    bv:SetAllPoints(f.content)
    f.views.buy = bv
    local QNAME, WATCH = "File de fabrication", "__watch"
    bv.lists = panelBox(bv, "Listes")
    bv.lists:SetPoint("TOPLEFT"); bv.lists:SetPoint("BOTTOMLEFT"); bv.lists:SetWidth(180)
    bv.lrows = {}
    for i = 1, 12 do
        local r = textRow(bv.lists, 24)
        r:SetPoint("TOPLEFT", 6, -30 - (i - 1) * 26); r:SetPoint("TOPRIGHT", -6, -30 - (i - 1) * 26)
        r.icon:Hide(); r.a:SetPoint("LEFT", 8, 0); r.a:SetPoint("RIGHT", -34, 0)
        r.pill = CreateFrame("Frame", nil, r)
        r.pill:SetSize(20, 16); r.pill:SetPoint("RIGHT", -6, 0)
        r.pill.bg = UI:Rounded(r.pill, 8, 0, "BACKGROUND", 1)
        r.pill.t = UI:Text(r.pill, 10, C.onAccent); r.pill.t:SetPoint("CENTER")
        r:SetScript("OnClick", function(s)
            if not s.name then return end
            -- autre liste : l'achat en cours (prix, objets passés, total) ne la suit pas
            if s.name ~= cfg().curList and S.buy and S.buy.list then S:CancelBuy() end
            cfg().curList = s.name; bv.search:SetText(""); bv:Refresh()
        end)
        r:Hide()
        bv.lrows[i] = r
    end
    -- ajouter un objet : n'importe quel objet de tes scans, à acheter ou à mettre dans la liste
    bv.search = UI:Input(bv.lists, 160, 26, "Ajouter un objet…", "search")
    bv.search:SetPoint("BOTTOMLEFT", 10, 10)
    bv.search.onChange = function() bv:Refresh() end

    -- résumé
    bv.sum = panelBox(bv, "Ce qu'il faut")
    bv.sum:SetPoint("TOPRIGHT"); bv.sum:SetPoint("BOTTOMRIGHT"); bv.sum:SetWidth(220)
    bv.sumLines = {}
    for i = 1, 5 do
        local l = UI:Text(bv.sum, 11, C.muted); l:SetPoint("TOPLEFT", 12, -32 - (i - 1) * 24)
        local v = UI:Text(bv.sum, 11, C.text); v:SetPoint("TOPRIGHT", -12, -32 - (i - 1) * 24); v:SetJustifyH("RIGHT")
        bv.sumLines[i] = { l, v }
    end
    bv.searchAll = UI:Button(bv.sum, "Chercher les prix", nil, 26, "secondary")
    bv.searchAll:SetPoint("TOPLEFT", 12, -160); bv.searchAll:SetPoint("TOPRIGHT", -12, -160)
    bv.buyAll = UI:Button(bv.sum, "Tout acheter", nil, 32, "primary")
    bv.buyAll:SetPoint("TOPLEFT", 12, -194); bv.buyAll:SetPoint("TOPRIGHT", -12, -194)
    bv.prog = CreateFrame("Frame", nil, bv.sum)
    bv.prog:SetPoint("TOPLEFT", 12, -236); bv.prog:SetPoint("TOPRIGHT", -12, -236); bv.prog:SetHeight(6)
    bv.prog.bg = UI:Rounded(bv.prog, 3, 0, "BACKGROUND", 1); bv.prog.bg:SetColor(C.border[1], C.border[2], C.border[3], 1)
    bv.prog.fillF = CreateFrame("Frame", nil, bv.prog); bv.prog.fillF:SetPoint("TOPLEFT"); bv.prog.fillF:SetPoint("BOTTOMLEFT")
    bv.prog.fill = UI:Rounded(bv.prog.fillF, 3, 0, "ARTWORK", 1)
    bv.progText = UI:Text(bv.sum, 10, C.dim); bv.progText:SetPoint("TOPLEFT", 12, -248); bv.progText:SetPoint("TOPRIGHT", -12, -248)
    bv.progText:SetJustifyH("LEFT")
    bv.sumNote = UI:Text(bv.sum, 10, C.dim); bv.sumNote:SetPoint("BOTTOMLEFT", 12, 10); bv.sumNote:SetPoint("BOTTOMRIGHT", -12, 10)
    bv.sumNote:SetJustifyH("LEFT")
    if bv.sumNote.SetWordWrap then bv.sumNote:SetWordWrap(true) end
    bv.sumNote:SetText(T("Un clic par objet : prix demandé, puis confirmé (le jeu l'exige). Ce qui est acheté sort de la liste."))

    -- tableau
    bv.main = panelBox(bv, "")
    bv.main:SetPoint("TOPLEFT", bv.lists, "TOPRIGHT", 8, 0); bv.main:SetPoint("BOTTOMRIGHT", bv.sum, "BOTTOMLEFT", -8, 0)
    local BCOLS = { { "Objet", 34, "LEFT" }, { "Pour", -326, "LEFT2" }, { "Il manque", -284 }, { "Plus bas", -212 }, { "En vente", -166 }, { "Total", -96 } }
    for _, cdef in ipairs(BCOLS) do
        local h = UI:Text(bv.main, 9, C.dim)
        if cdef[3] == "LEFT" then h:SetPoint("TOPLEFT", cdef[2], -30)
        elseif cdef[3] == "LEFT2" then h:SetPoint("TOPLEFT", bv.main, "TOPRIGHT", cdef[2] - 80, -30)
        else h:SetPoint("TOPRIGHT", cdef[2], -30) end
        h:SetText(UI:Upper(T(cdef[1])))
    end
    bv.irows = {}
    for i = 1, 16 do
        local r = textRow(bv.main, 26)
        r:SetPoint("TOPLEFT", 6, -44 - (i - 1) * 28); r:SetPoint("TOPRIGHT", -6, -44 - (i - 1) * 28)
        if r.RegisterForClicks then r:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
        r.a:SetPoint("RIGHT", -412, 0)
        r.who = UI:Text(r, 11, C.muted); r.who:SetPoint("RIGHT", -326, 0); r.who:SetWidth(80); r.who:SetJustifyH("LEFT")
        if r.who.SetWordWrap then r.who:SetWordWrap(false) end
        r.b:SetPoint("RIGHT", -284, 0); r.b:SetWidth(40)
        r.c:SetPoint("RIGHT", -212, 0); r.c:SetWidth(68); r.c:SetTextColor(C.text[1], C.text[2], C.text[3])
        r.d:SetPoint("RIGHT", -166, 0); r.d:SetWidth(42)
        r.tot = UI:Text(r, 11, C.gold); r.tot:SetPoint("RIGHT", -96, 0); r.tot:SetWidth(66); r.tot:SetJustifyH("RIGHT")
        r.btn = UI:Button(r, "Acheter", 88, 22, "primary"); r.btn:SetPoint("RIGHT", -2, 0)
        r.tag = UI:Badge(r, "", C.muted); r.tag:SetPoint("RIGHT", -4, 0)
        r.add = UI:IconButton(r, "plus", 22, "Ajouter à la liste d'achat")
        r.add:SetPoint("RIGHT", r.btn, "LEFT", -6, 0)
        r.add:SetScript("OnClick", function(s)
            local row = s:GetParent()
            if not row.id then return end
            local _, lists = S:Lists()
            local name = cfg().curList
            if not (name and lists[name]) or name == QNAME then name = T("Mes achats") end
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
            if s.vendor then GameTooltip:AddLine(string.format(T("Vu chez %s à %s"), s.vendor.npc or "?", money(s.vendor.p or 0)), C.rule[1], C.rule[2], C.rule[3]) end
            if s.watch then GameTooltip:AddLine(T("Clic droit : ne plus surveiller"), 0.6, 0.6, 0.6) end
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        r:SetScript("OnClick", function(s, button)
            if button == "RightButton" and s.watch and s.id then
                A.Config().alerts[s.id] = nil
                bv:Refresh()
            end
        end)
        r.btn:SetScript("OnClick", function(s)
            local row = s:GetParent()
            local id, need = row.id, row.need
            if not id then return end
            if row.watch or not isCommodity(id) then
                if not UI:AHWindowSearch(id, WK.GetItemInfo(id)) then S:SearchItem(id) end
                return
            end
            commodityClick(id, need, { list = cfg().curList })
            bv:Refresh()
        end)
        r:Hide()
        bv.irows[i] = r
    end
    bv.empty = UI:Text(bv.main, 11, C.muted); bv.empty:SetPoint("CENTER"); bv.empty:SetWidth(380)
    bv.qtyLabel = UI:Text(bv.main, 11, C.muted); bv.qtyLabel:SetPoint("TOPRIGHT", -74, -10); bv.qtyLabel:SetText(T("Quantité"))
    bv.qty = UI:NumberInput(bv.main, 56, 22, "1"); bv.qty:SetPoint("TOPRIGHT", -12, -6)
    bv.qty.edit:SetText("1")
    bv.searchAll:SetScript("OnClick", function()
        local l = S:GetList(cfg().curList)
        for _, it in ipairs(l and l.items or {}) do search(it[1]) end
        pump()
    end)
    bv.buyAll:SetScript("OnClick", function()
        local b = S.buy
        -- premier clic : ce qui va au marchand, chez un perso ou qui est introuvable est passé
        if not (b and b.list) then S.buy = { list = cfg().curList, skip = bv.skipSet or {}, spent = 0, count = 0 } end
        S:BuyStep(); bv:Refresh()
    end)

    -- résultats de la recherche « Ajouter un objet » : objets de tes scans dont le nom contient le texte
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
        self.empty:SetText(T("Aucun objet de tes scans ne porte ce nom : fais un scan, ou cherche-le dans Parcourir."))
        local qn = math.max(1, self.qty:GetNumber() > 0 and self.qty:GetNumber() or 1)
        local b = S.buy
        for i, r in ipairs(self.irows) do
            local e = list[i]
            r.watch, r.vendor = nil, nil
            if e then
                local id = e.id
                r.id, r.need = id, qn
                r.icon:SetTexture(itemIcon(id))
                local _, _, quality = WK.GetItemInfo(id)
                r.a:SetText(e.name)
                if quality and GetItemQualityColor then r.a:SetTextColor(GetItemQualityColor(quality)) end
                r.who:SetText(string.format(T("à toi : %d"), S:Have(id)))
                r.b:SetText("")
                local low = lowestOther(id) or S:Price(id)
                local av = available(id)
                r.c:SetText(low and money(low) or "-")
                r.d:SetText(av and tostring(av) or "")
                r.tot:SetText("")
                r.tag:Hide(); r.btn:Show(); r.add:Show()
                if not isCommodity(id) then r.btn:SetLabel(T("Chercher"))
                elseif b and b.id == id and b.phase == "confirm" then r.btn:SetLabel(string.format(T("Confirmer %s"), money(b.total)))
                elseif b and b.id == id and (b.phase == "quote" or b.phase == "wait") then r.btn:SetLabel("…")
                else r.btn:SetLabel(string.format(T("Acheter %d"), qn)) end
                r:Show()
            else r:Hide() end
        end
    end
    -- « File de fabrication » : ce qui manque à la file de tous tes persos (page Métiers), tenue à jour
    -- comme une liste d'achat (en tête) ; pour qui, dans bv.who
    bv.who = {}
    local function syncQueue()
        local PH = WK.modules.ProfHelp
        local _, lists = S:Lists()
        local ok, q = pcall(function() return PH and PH:Queue() or {} end)
        local need, order = {}, {}
        wipe(bv.who)
        for _, e in ipairs(ok and q or {}) do
            for _, m in ipairs(e.missing or {}) do
                if not m.where then
                    if not need[m.id] then table.insert(order, m.id) end
                    need[m.id] = (need[m.id] or 0) + m.n
                    local c = WK.DB.global.characters[e.crafter or ""]
                    bv.who[m.id] = c and WK:CharName(c, e.crafter) or nil
                end
            end
        end
        if #order == 0 then lists[QNAME] = nil return end
        local items = {}
        for _, id in ipairs(order) do table.insert(items, { id, need[id] + S:Have(id) }) end
        lists[QNAME] = { items = items, at = 2000000000, v = 2, auto = true }
    end
    -- un autre perso en a assez : son nom et combien
    local function altWith(id, need)
        local me = WK:CharKey()
        local Inv = WK.modules.Inventory
        for key, c in pairs(WK.DB.global.characters) do
            if key ~= me and Inv and Inv.CharCount then
                local n = Inv:CharCount(c, id)
                if n >= need then return WK:CharName(c, key), n end
            end
        end
    end

    function bv:Refresh()
        syncQueue()
        local q = string.lower(self.search:GetText() or "")
        self.qty:SetShown(q ~= ""); self.qtyLabel:SetShown(q ~= "")
        for _, r in ipairs(self.irows) do r.add:Hide() end
        local names, lists = S:Lists()
        -- la file en tête, les prix surveillés en dernier
        local order = {}
        if lists[QNAME] then table.insert(order, QNAME) end
        for _, n in ipairs(names) do if n ~= QNAME then table.insert(order, n) end end
        local alerts = A.Config().alerts or {}
        local nWatch = 0
        for _ in pairs(alerts) do nWatch = nWatch + 1 end
        table.insert(order, WATCH)
        local cur = cfg().curList
        if not (cur == WATCH or (cur and lists[cur])) then cur = order[1] ~= WATCH and order[1] or WATCH; cfg().curList = cur end
        local ar, ag, ab = UI:Accent()
        for i, r in ipairs(self.lrows) do
            local n = order[i]
            r.name = n
            if n then
                local count = n == WATCH and nWatch or #(lists[n].items or {})
                r.a:SetText(n == QNAME and T(QNAME) or n == WATCH and T("Prix surveillés") or n)
                r.a:SetTextColor(unpack(n == cur and C.text or C.muted))
                r.pill.t:SetText(count)
                r.pill:SetWidth(math.max(18, r.pill.t:GetStringWidth() + 10))
                r.pill.bg:SetColor(ar, ag, ab, 1)
                r.pill:SetShown(count > 0)
                r.hl:SetColorTexture(ar, ag, ab, n == cur and 0.14 or 0)
                r:Show()
            else r:Hide() end
        end
        local b = S.buy
        if q ~= "" then
            for _, sl in ipairs(self.sumLines) do sl[1]:SetText(""); sl[2]:SetText("") end
            return self:RefreshSearch(q)
        end
        if cur == WATCH then return self:RefreshWatch(alerts) end
        local l = cur and lists[cur]
        self.main.title:SetText(cur and (cur == QNAME and T(QNAME) or cur) or T("Aucune liste"))
        self.empty:SetShown(not l)
        self.empty:SetText(T("Crée une liste d'achat depuis la page Métiers (guide de montée ou recettes), ou ajoute des recettes à la file de fabrication."))
        local vseen = WK.DB.global.vendorSeen or {}
        self.skipSet = {}
        local sAH, nAH, sVendor, nVendor, nAlt, nNone, noneName, n = 0, 0, 0, 0, 0, 0, nil, 0
        f.buyCount = 0
        for i, r in ipairs(self.irows) do
            local it = l and l.items[i]
            r.watch = nil
            if it then
                local id = it[1]
                local have = S:Have(id)
                local need = math.max(0, it[2] - have)
                r.id, r.need = id, need
                r.icon:SetTexture(itemIcon(id))
                local name, _, quality = WK.GetItemInfo(id)
                r.a:SetText(name or ("#" .. id))
                if quality and GetItemQualityColor then r.a:SetTextColor(GetItemQualityColor(quality)) end
                r.who:SetText(cur == QNAME and self.who[id] or "")
                r.b:SetText(need > 0 and tostring(need) or (UI:Hex(C.positive) .. T("ok") .. "|r"))
                local low = lowestOther(id) or (results[id] == nil and S:Price(id)) or nil
                local av = available(id)
                local none = results[id] ~= nil and not lowestOther(id)
                r.c:SetText(none and (UI:Hex(C.negative) .. T("aucun") .. "|r") or (low and money(low) or "-"))
                r.d:SetText(av and tostring(av) or "")
                local v = vseen[id]
                r.vendor = v
                local alt, altN = nil, nil
                if need > 0 then alt, altN = altWith(id, need) end
                -- l'action qui va : au marchand (moins cher qu'à l'HV), chez un perso, introuvable, sinon acheter
                r.tag:Hide(); r.btn:Hide(); r.tot:SetText("")
                if need > 0 then
                    f.buyCount = f.buyCount + 1
                    if v and (not low or v.p <= low) then
                        r.tag:Set(T("au marchand"), C.rule); r.tag:Show()
                        r.tot:SetText(money(v.p * need))
                        sVendor, nVendor = sVendor + v.p * need, nVendor + 1
                        self.skipSet[id] = true
                    elseif alt then
                        r.tag:Set(string.format(T("%s en a %d"), alt, altN), C.info); r.tag:Show()
                        nAlt = nAlt + 1
                        self.skipSet[id] = true
                    elseif none then
                        r.tag:Set(T("introuvable"), C.negative); r.tag:Show()
                        nNone = nNone + 1; noneName = noneName or name
                        self.skipSet[id] = true
                    else
                        r.tot:SetText(low and money(low * need) or "")
                        if low then sAH = sAH + low * need end
                        nAH = nAH + 1
                        r.btn:Show()
                        if not isCommodity(id) then r.btn:SetLabel(T("Chercher"))
                        elseif b and b.id == id and b.phase == "confirm" then r.btn:SetLabel(string.format(T("Confirmer %s"), money(b.total)))
                        elseif b and b.id == id and (b.phase == "quote" or b.phase == "wait") then r.btn:SetLabel("…")
                        else r.btn:SetLabel(string.format(T("Acheter %d"), need)) end
                    end
                end
                n = n + 1
                r:Show()
            else r:Hide() end
        end
        self.main.sub:SetText(l and string.format(T("%d objets"), n) or "")
        -- résumé
        local lines = {
            { string.format(T("À l'HV (%d)"), nAH), nAH > 0 and money(sAH) or "-" },
            { string.format(T("Chez le marchand (%d)"), nVendor), nVendor > 0 and money(sVendor) or "-" },
            { string.format(T("Chez tes persos (%d)"), nAlt), nAlt > 0 and (UI:Hex(C.info) .. T("par courrier") .. "|r") or "-" },
            { string.format(T("Introuvable (%d)"), nNone), nNone > 0 and (UI:Hex(C.negative) .. (noneName or "") .. "|r") or "-" },
            { T("Ton or"), UI:GoldText(GetMoney and GetMoney() or 0) },
        }
        for i, sl in ipairs(self.sumLines) do sl[1]:SetText(lines[i][1]); sl[2]:SetText(lines[i][2]) end
        local inBuy = b and b.list == cur
        self.buyAll:SetEnabled(cur ~= nil and nAH > 0 or (inBuy and b.phase == "confirm"))
        self.searchAll:SetEnabled(cur ~= nil)
        self.buyAll:SetLabel((b and b.phase == "confirm") and string.format(T("Confirmer %s"), money(b.total)) or string.format(T("Tout acheter à l'HV (%d)"), nAH))
        local done = inBuy and (b.count or 0) or 0
        local totalSteps = done + nAH
        self.prog.fill:SetColor(ar, ag, ab, 1)
        self.prog.fillF:SetWidth(math.max(1, (self.prog:GetWidth() or 190) * (totalSteps > 0 and done / totalSteps or 0)))
        self.prog:SetShown(inBuy or false); self.progText:SetShown(inBuy or false)
        if inBuy then self.progText:SetText(string.format(T("%d / %d acheté(s) · %s dépensés"), done, totalSteps, money(b.spent or 0))) end
    end

    -- Prix surveillés (alertes de prix) : seuil, plus bas, « ça y est »
    function bv:RefreshWatch(alerts)
        self.main.title:SetText(T("Prix surveillés"))
        local list = {}
        for id, max in pairs(alerts) do table.insert(list, { id = id, max = max, name = WK.GetItemInfo(id) or ("#" .. id) }) end
        table.sort(list, function(x, y) return x.name < y.name end)
        self.main.sub:SetText(string.format(T("%d objets"), #list))
        self.empty:SetShown(#list == 0)
        self.empty:SetText(T("Aucun prix surveillé : « Surveiller » dans Parcourir ou Prix."))
        for i, r in ipairs(self.irows) do
            local e = list[i]
            r.watch, r.vendor = e and true or nil, nil
            if e then
                r.id, r.need = e.id, 1
                r.icon:SetTexture(itemIcon(e.id))
                r.a:SetText(e.name); r.a:SetTextColor(1, 1, 1)
                r.who:SetText(T("sous") .. " " .. money(e.max))
                r.b:SetText("")
                local low = lowestOther(e.id) or S:Price(e.id)
                r.c:SetText(low and money(low) or "-")
                local av = available(e.id)
                r.d:SetText(av and tostring(av) or "")
                r.tot:SetText("")
                r.tag:Hide()
                r.btn:Show(); r.btn:SetLabel(T("Chercher"))
                if low and low <= e.max then r.tot:SetText(UI:Hex(C.positive) .. T("ça y est") .. "|r") end
                r:Show()
            else r:Hide() end
        end
        for i, sl in ipairs(self.sumLines) do sl[1]:SetText(i == 1 and T("Ton or") or ""); sl[2]:SetText(i == 1 and UI:GoldText(GetMoney and GetMoney() or 0) or "") end
        self.buyAll:SetEnabled(false); self.searchAll:SetEnabled(false)
        self.prog:Hide(); self.progText:Hide()
    end

    -----------------------------------------------------------------------
    -- Mes enchères : tableau, une ligne se déplie (file des vendeurs, ta place, « Reposter à »),
    -- à droite le bilan du jour et, par objet, vendus et expirés sur 7 jours (factures du courrier).
    -- « Reposter » : annule l'enchère, puis la page Vendre s'ouvre sur l'objet revenu, au bon prix (2e clic).
    -----------------------------------------------------------------------
    local cv = CreateFrame("Frame", nil, f.content)
    cv:SetAllPoints(f.content)
    f.views.cancel = cv
    cv.show = "all"
    cv.filter = UI:Input(cv, 210, 28, "Filtrer…", "search")
    cv.filter:SetPoint("TOPLEFT", 0, 0)
    cv.filter.onChange = function() cv:Refresh() end
    cv.seg = UI:Segmented(cv, { { "all", "Toutes" }, { "under", "Sous-cotées" }, { "soon", "Bientôt finies" } },
        function(v) cv.show = v; cv:Refresh() end, 28)
    cv.seg:SetPoint("LEFT", cv.filter, "RIGHT", 10, 0)
    cv.seg:Select("all")
    cv.check = UI:Button(cv, "Revérifier", nil, 28, "secondary"); cv.check:SetPoint("TOPRIGHT", 0, 0)
    cv.check:SetScript("OnClick", function() A:Check() end)
    cv.next = UI:Button(cv, "Reposter la suivante sous-cotée", nil, 28, "primary"); cv.next:SetPoint("RIGHT", cv.check, "LEFT", -8, 0)

    -- à droite : aujourd'hui, puis tes objets sur 7 jours
    cv.side = CreateFrame("Frame", nil, cv)
    cv.side:SetPoint("TOPRIGHT", 0, -40); cv.side:SetPoint("BOTTOMRIGHT"); cv.side:SetWidth(290)
    cv.dayBox = panelBox(cv.side, "Aujourd'hui")
    cv.dayBox:SetPoint("TOPLEFT"); cv.dayBox:SetPoint("TOPRIGHT"); cv.dayBox:SetHeight(150)
    cv.dayBox.sub:SetText(T("factures du courrier"))
    cv.day = UI:Text(cv.dayBox, 11, C.muted); cv.day:SetPoint("TOPLEFT", 12, -32); cv.day:SetPoint("TOPRIGHT", -12, -32)
    cv.day:SetJustifyH("LEFT"); cv.day:SetJustifyV("TOP")
    if cv.day.SetSpacing then cv.day:SetSpacing(5) end
    cv.itemsBox = panelBox(cv.side, "Tes objets")
    cv.itemsBox:SetPoint("TOPLEFT", cv.dayBox, "BOTTOMLEFT", 0, -10); cv.itemsBox:SetPoint("BOTTOMRIGHT")
    cv.itemsBox.sub:SetText(T("7 jours"))
    for _, hd in ipairs({ { "Objet", "LEFT", 12 }, { "Vendus", "RIGHT", -70 }, { "Expirés", "RIGHT", -12 } }) do
        local t = UI:Text(cv.itemsBox, 9, C.dim)
        if hd[2] == "LEFT" then t:SetPoint("TOPLEFT", hd[3], -30) else t:SetPoint("TOPRIGHT", hd[3], -30) end
        t:SetText(UI:Upper(T(hd[1])))
    end
    cv.irows = {}
    for i = 1, 12 do
        local r = textRow(cv.itemsBox, 20)
        r:SetPoint("TOPLEFT", 4, -44 - (i - 1) * 21); r:SetPoint("TOPRIGHT", -4, -44 - (i - 1) * 21)
        r.icon:Hide(); r.a:SetPoint("LEFT", 8, 0); r.a:SetPoint("RIGHT", -120, 0)
        r.b:SetPoint("RIGHT", -66, 0); r.b:SetWidth(50)
        r.c:SetPoint("RIGHT", -8, 0); r.c:SetWidth(50)
        r:Hide()
        cv.irows[i] = r
    end
    cv.itemsNote = UI:Text(cv.itemsBox, 10, C.dim); cv.itemsNote:SetPoint("BOTTOMLEFT", 12, 10); cv.itemsNote:SetPoint("BOTTOMRIGHT", -12, 10)
    cv.itemsNote:SetJustifyH("LEFT")
    if cv.itemsNote.SetWordWrap then cv.itemsNote:SetWordWrap(true) end
    cv.itemsNote:SetText(T("Un objet qui expire souvent : baisse son prix ou garde-le."))

    -- tableau
    cv.main = panelBox(cv, "Mes enchères")
    cv.main:SetPoint("TOPLEFT", 0, -40); cv.main:SetPoint("BOTTOMRIGHT", cv.side, "BOTTOMLEFT", -10, 0)
    local ccols = { { "Objet", 34 }, { "Qté", -330 }, { "Ton prix", -250 }, { "Plus bas", -170 }, { "Reste", -110 } }
    for _, cdef in ipairs(ccols) do
        local h = UI:Text(cv.main, 9, C.dim)
        if cdef[2] > 0 then h:SetPoint("TOPLEFT", cdef[2], -32) else h:SetPoint("TOPRIGHT", cdef[2], -32) end
        h:SetText(UI:Upper(T(cdef[1])))
    end
    local CROW, DET_H = 28, 96
    cv.rows = {}
    for i = 1, 18 do
        local r = textRow(cv.main, 26)
        r.a:SetPoint("RIGHT", -360, 0)
        r.b:SetPoint("RIGHT", -330, 0); r.b:SetWidth(30)
        r.c:SetPoint("RIGHT", -250, 0); r.c:SetWidth(80); r.c:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
        r.d:SetPoint("RIGHT", -170, 0); r.d:SetWidth(80)
        r.left = UI:Text(r, 11, C.muted); r.left:SetPoint("RIGHT", -110, 0); r.left:SetWidth(50); r.left:SetJustifyH("RIGHT")
        r.state = UI:Badge(r, "", C.muted); r.state:SetPoint("RIGHT", -4, 0)
        r:SetScript("OnClick", function(s)
            if not s.o then return end
            cv.open = (cv.open ~= s.o.auctionID) and s.o.auctionID or nil
            if cv.open then search(s.o.id, true); pump() end
            cv:Refresh()
        end)
        r:SetScript("OnEnter", function(s)
            if not s.o then return end
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            if GameTooltip.SetItemByID then GameTooltip:SetItemByID(s.o.id) end
            GameTooltip:AddLine(T("Clic : où tu en es, reposter ou annuler"), 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        r:Hide()
        cv.rows[i] = r
    end
    cv.empty = UI:Text(cv.main, 11, C.muted); cv.empty:SetPoint("CENTER")
    cv.empty:SetText(T("Aucune enchère en cours."))

    -- détail d'une enchère : file des vendeurs (ta place), et les actions
    cv.det = CreateFrame("Frame", nil, cv.main)
    cv.det:SetHeight(DET_H - 6)
    UI:Panel(cv.det, 8, { C.bg[1], C.bg[2], C.bg[3], 1 }, C.border)
    cv.det.label = UI:Text(cv.det, 10, C.dim); cv.det.label:SetPoint("TOPLEFT", 12, -12); cv.det.label:SetText(T("Où tu en es"))
    cv.track = cv.det:CreateTexture(nil, "ARTWORK")
    cv.track:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
    cv.track:SetPoint("TOPLEFT", 100, -18); cv.track:SetPoint("TOPRIGHT", -16, -18); cv.track:SetHeight(2)
    cv.marks = {}
    for i = 1, 7 do
        local m = CreateFrame("Frame", nil, cv.det)
        m:SetSize(70, 30)
        m.dot = m:CreateTexture(nil, "OVERLAY"); m.dot:SetTexture(UI.MEDIA .. "circle"); m.dot:SetSize(8, 8); m.dot:SetPoint("TOP", 0, 3)
        m.p = UI:Text(m, 10, C.gold); m.p:SetPoint("TOP", m.dot, "BOTTOM", 0, -2)
        m.q = UI:Text(m, 9, C.dim); m.q:SetPoint("TOP", m.p, "BOTTOM", 0, -1)
        m:Hide()
        cv.marks[i] = m
    end
    cv.det.info = UI:Text(cv.det, 11, C.muted); cv.det.info:SetPoint("BOTTOMLEFT", 12, 12); cv.det.info:SetPoint("BOTTOMRIGHT", -230, 12)
    cv.det.info:SetJustifyH("LEFT")
    if cv.det.info.SetWordWrap then cv.det.info:SetWordWrap(true) end
    cv.det.cancel = UI:Button(cv.det, "Annuler", nil, 24, "secondary"); cv.det.cancel:SetPoint("BOTTOMRIGHT", -10, 8)
    cv.det.repost = UI:Button(cv.det, "Reposter", nil, 24, "primary"); cv.det.repost:SetPoint("RIGHT", cv.det.cancel, "LEFT", -6, 0)
    cv.det:Hide()

    local function under() return (A.Config and A.Config().undercut) or 1 end
    -- prix de remise en vente : le moins cher des autres moins l'écart
    local function repostPrice(o)
        local low = lowestOther(o.id) or o.lowest
        return low and math.max(1, low - under()) or nil
    end
    -- annule, puis (objet revenu dans les sacs) la page Vendre s'ouvre dessus, au prix voulu
    local function repost(o)
        if not o then return end
        -- combien on en a déjà : la page Vendre ne s'ouvre que quand l'objet annulé est revenu (en plus)
        local okB, _, by = pcall(bagItems)
        local have = okB and by and by[o.id] and by[o.id].count or 0
        f.repost = { id = o.id, price = repostPrice(o), at = GetTime(), have = have }
        A:Cancel(o.auctionID)
        cv.open = nil
        WK:Print(T("Enchère annulée : l'objet revient par le courrier. La page Vendre s'ouvrira dessus, au bon prix, dès qu'il sera dans tes sacs."))
    end
    cv.det.cancel:SetScript("OnClick", function() local o = cv.openO; if o then A:Cancel(o.auctionID); cv.open = nil; cv:Refresh() end end)
    cv.det.repost:SetScript("OnClick", function() repost(cv.openO); cv:Refresh() end)
    cv.next:SetScript("OnClick", function()
        for _, o in ipairs(A.owned or {}) do
            if o.state == "under" then repost(o) return end
        end
    end)

    -- ventes, achats, expirées et dépôts du jour ; par objet sur 7 jours
    local function readLog()
        local log = WK.DB.global.auction and WK.DB.global.auction.log or {}
        local t0 = time() - (tonumber(date("%H")) * 3600 + tonumber(date("%M")) * 60 + tonumber(date("%S")))
        local week = time() - 7 * 86400
        local d = { sold = 0, n = 0, bought = 0, expired = 0 }
        local byItem, order = {}, {}
        for _, l in ipairs(log) do
            local t = l.t or 0
            if t >= t0 then
                if l.kind == "sale" then d.sold = d.sold + (l.net or 0); d.n = d.n + 1
                elseif l.kind == "buy" then d.bought = d.bought + (l.gross or 0)
                elseif l.kind == "expired" then d.expired = d.expired + 1 end
            end
            if t >= week and (l.kind == "sale" or l.kind == "expired") and l.item then
                local b = byItem[l.item]
                if not b then b = { name = l.item, sold = 0, exp = 0, gross = 0 }; byItem[l.item] = b; table.insert(order, b) end
                if l.kind == "sale" then b.sold = b.sold + (l.count or 1); b.gross = b.gross + (l.gross or 0)
                else b.exp = b.exp + (l.count or 1) end
            end
        end
        table.sort(order, function(x, y) return (x.sold + x.exp) > (y.sold + y.exp) end)
        return d, order, byItem
    end

    function cv:Refresh()
        local all = A.owned or {}
        local q = string.lower(self.filter:GetText() or "")
        local owned, nUnder, nSoon = {}, 0, 0
        for _, o in ipairs(all) do
            local soon = o.timeLeft and o.timeLeft < 2 * 3600
            if o.state == "under" then nUnder = nUnder + 1 end
            if soon then nSoon = nSoon + 1 end
            local name = WK.GetItemInfo(o.id) or ""
            local okName = q == "" or string.lower(name):find(q, 1, true)
            local okShow = self.show == "all" or (self.show == "under" and o.state == "under") or (self.show == "soon" and soon)
            if okName and okShow then table.insert(owned, o) end
        end
        self.seg.buttons.all:SetLabel(string.format(T("Toutes (%d)"), #all))
        self.seg.buttons.under:SetLabel(string.format(T("Sous-cotées (%d)"), nUnder))
        self.seg.buttons.soon:SetLabel(string.format(T("Bientôt finies (%d)"), nSoon))
        -- libellés avec nombres : largeurs recalculées
        local sx = 3
        for _, k in ipairs({ "all", "under", "soon" }) do
            local bt = self.seg.buttons[k]
            bt:SetWidth(bt.label:GetStringWidth() + 28)
            bt:ClearAllPoints(); bt:SetPoint("LEFT", sx, 0)
            sx = sx + bt:GetWidth() + 2
        end
        self.seg:SetWidth(sx + 1)
        self.next:SetEnabled(nUnder > 0)
        local done, total = A:Progress()
        local listed = 0
        for _, o in ipairs(all) do listed = listed + (o.unit or 0) * (o.qty or 1) end
        self.main.sub:SetText(string.format(T("%d en cours"), #all) .. "  ·  " .. money(listed)
            .. (A.checking and ("  ·  " .. string.format(T("vérification %d/%d"), done, total)) or ""))
        self.empty:SetShown(#owned == 0)
        -- lignes, et le détail glissé sous la ligne ouverte
        local y = 46
        local maxY = (self.main:GetHeight() or 500) - 10
        self.openO = nil
        self.det:Hide()
        for i, r in ipairs(self.rows) do
            local o = owned[i]
            r.o = o
            if o and y + CROW <= maxY then
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", 6, -y); r:SetPoint("TOPRIGHT", -6, -y)
                r.icon:SetTexture(itemIcon(o.id))
                local name, _, quality = WK.GetItemInfo(o.id)
                r.a:SetText(name or ("#" .. o.id))
                if quality and GetItemQualityColor then r.a:SetTextColor(GetItemQualityColor(quality)) end
                r.b:SetText(tostring(o.qty or 1))
                r.c:SetText(money(o.unit))
                r.d:SetText(o.lowest and money(o.lowest) or "-")
                local col = o.state == "under" and C.negative or C.positive
                r.d:SetTextColor(col[1], col[2], col[3])
                local tl = o.timeLeft
                r.left:SetText(tl and (tl >= 3600 and string.format(T("env. %d h"), math.floor(tl / 3600)) or string.format(T("env. %d min"), math.max(1, math.floor(tl / 60)))) or "")
                local lc = (tl and tl < 2 * 3600) and C.warning or C.muted
                r.left:SetTextColor(lc[1], lc[2], lc[3])
                local st = o.state
                if st == "under" then r.state:Set(T("sous-cotée"), C.negative)
                elseif st == "ok" then r.state:Set(T("la plus basse"), C.positive)
                elseif st == "alone" then r.state:Set(T("seule en vente"), C.positive)
                else r.state:Set(T("à vérifier"), C.muted) end
                local ar, ag, ab = UI:Accent()
                local isOpen = self.open == o.auctionID
                r.hl:SetColorTexture(ar, ag, ab, isOpen and 0.14 or 0)
                r:Show()
                y = y + CROW
                if isOpen then
                    self.openO = o
                    self.det:ClearAllPoints()
                    self.det:SetPoint("TOPLEFT", 36, -y); self.det:SetPoint("TOPRIGHT", -8, -y)
                    self:FillDetail(o)
                    self.det:Show()
                    y = y + DET_H
                end
            else r:Hide() end
        end
        -- côté droit
        local d, items = readLog()
        self.day:SetText(table.concat({
            T("Vendu") .. (d.n > 0 and (" (" .. d.n .. ")") or "") .. " : " .. UI:Hex(C.positive) .. "+" .. money(d.sold) .. "|r",
            T("Acheté") .. " : " .. UI:Hex(C.negative) .. "-" .. money(d.bought) .. "|r",
            T("Expirées") .. " : " .. d.expired,
            T("En vente") .. " : " .. money(listed),
        }, "\n"))
        for i, r in ipairs(self.irows) do
            local b = items[i]
            if b then
                r.a:SetText(b.name)
                r.b:SetText(tostring(b.sold)); r.b:SetTextColor(unpack(b.sold > 0 and C.positive or C.muted))
                r.c:SetText(tostring(b.exp)); r.c:SetTextColor(unpack(b.exp > b.sold and C.negative or C.muted))
                r:Show()
            else r:Hide() end
        end
    end

    function cv:FillDetail(o)
        local r = results[o.id]
        for _, m in ipairs(self.marks) do m:Hide() end
        local ar, ag, ab = UI:Accent()
        local name = WK.GetItemInfo(o.id)
        local _, _, byItem = readLog()
        local b = name and byItem[name]
        local avg = b and b.sold > 0 and math.floor(b.gross / b.sold) or nil
        if not r then
            self.det.info:SetText(T("recherche…"))
        else
            -- les enchères des autres et la tienne, de la moins chère à la plus chère (7 au plus)
            local pts, before, ahead = {}, 0, 0
            for _, x in ipairs(r.rows) do
                if not x.mine then
                    table.insert(pts, { unit = x.unit, qty = x.qty })
                    if x.unit < o.unit then before = before + x.qty; ahead = ahead + 1 end
                end
            end
            table.insert(pts, { unit = o.unit, qty = o.qty or 1, me = true })
            table.sort(pts, function(x, y) return x.unit < y.unit end)
            -- garder ta place visible : autour d'elle
            local mi = 1
            for i, p in ipairs(pts) do if p.me then mi = i end end
            local from = math.max(1, math.min(mi - 3, #pts - 6))
            local shown = {}
            for i = from, math.min(#pts, from + 6) do table.insert(shown, pts[i]) end
            local w = (self.det:GetWidth() or 500) - 116
            for i, p in ipairs(shown) do
                local m = self.marks[i]
                local frac = #shown > 1 and (i - 1) / (#shown - 1) or 0.5
                m:ClearAllPoints(); m:SetPoint("TOP", self.track, "TOPLEFT", frac * w, 0)
                m.p:SetText(p.me and (T("toi") .. " " .. money(p.unit)) or money(p.unit))
                m.q:SetText("x" .. p.qty)
                if p.me then m.dot:SetVertexColor(ar, ag, ab, 1); m.p:SetTextColor(ar, ag, ab)
                else m.dot:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 1); m.p:SetTextColor(C.gold[1], C.gold[2], C.gold[3]) end
                m:Show()
            end
            local parts = {}
            if ahead > 0 then table.insert(parts, string.format(T("%d moins chers que toi (%d objets)"), ahead, before))
            else table.insert(parts, T("tu es le moins cher")) end
            if avg then table.insert(parts, string.format(T("vendu %s en moyenne cette semaine"), money(avg))) end
            self.det.info:SetText(table.concat(parts, "  ·  "))
        end
        local p = repostPrice(o)
        self.det.repost:SetShown(o.state == "under" and p ~= nil)
        if p then self.det.repost:SetLabel(string.format(T("Reposter à %s"), plain(p))) end
        self.det.repost:SetWidth(self.det.repost.label:GetStringWidth() + 28)
    end

    -----------------------------------------------------------------------
    -- Parcourir : recherche par nom et catégorie (la nôtre, à la place de l'onglet Acheter du jeu),
    -- filtres, résultats triables qui défilent ; à droite l'objet choisi : courbe, enchères, achat.
    -----------------------------------------------------------------------
    local bw = CreateFrame("Frame", nil, f.content)
    bw:SetAllPoints(f.content)
    f.views.browse = bw
    bw.q = { text = "" }
    bw.sortKey, bw.sortRev = "low", false
    bw.offset = 0
    -- haut : recherche, filtres, chercher, enregistrer
    bw.search = UI:Input(bw, 210, 30, "Chercher un objet…", "search")
    bw.search:SetPoint("TOPLEFT", 0, 0)
    bw.search.onEnter = function() bw:Run() end
    local function chip(label, tip)
        local b = UI:Button(bw, label, nil, 26, "ghost")
        b.tooltip = tip
        return b
    end
    bw.usable = chip("Utilisable par moi", "Seulement ce que ce perso peut utiliser.")
    bw.usable:SetPoint("LEFT", bw.search, "RIGHT", 8, 0)
    bw.usable:SetScript("OnClick", function() cfg().browseUsable = not cfg().browseUsable; bw:PaintChips() end)
    bw.deal = chip("Bonne affaire", "Plus bas sous 80 % de la moyenne des 7 derniers jours.")
    bw.deal:SetPoint("LEFT", bw.usable, "RIGHT", 4, 0)
    bw.deal:SetScript("OnClick", function() bw.dealOnly = not bw.dealOnly; bw:PaintChips(); bw:RefreshResults() end)
    bw.minL = UI:NumberInput(bw, 52, 26, "niv."); bw.minL:SetPoint("LEFT", bw.deal, "RIGHT", 10, 0)
    bw.maxL = UI:NumberInput(bw, 52, 26, "max"); bw.maxL:SetPoint("LEFT", bw.minL, "RIGHT", 4, 0)
    bw.minL.onEnter = function() bw:Run() end
    bw.maxL.onEnter = function() bw:Run() end
    -- qualité minimale (filtre des résultats) : toutes, inhabituel, rare, épique
    local QUALS = { { nil, "Qualité : toutes" }, { 2, "Inhabituel +" }, { 3, "Rare +" }, { 4, "Épique +" } }
    bw.qual = UI:Button(bw, QUALS[1][2], nil, 26, "ghost"); bw.qual:SetPoint("LEFT", bw.maxL, "RIGHT", 8, 0)
    bw.qual:SetScript("OnClick", function()
        local i = 1
        for k, qd in ipairs(QUALS) do if qd[1] == bw.minQ then i = k end end
        local nx = QUALS[i % #QUALS + 1]
        bw.minQ = nx[1]
        bw.qual:SetLabel(T(nx[2])); bw.qual:SetWidth(bw.qual.label:GetStringWidth() + 28)
        bw:PaintChips(); bw.offset = 0; bw:RefreshResults()
    end)
    bw.go = UI:Button(bw, "Chercher", nil, 28, "primary"); bw.go:SetPoint("LEFT", bw.qual, "RIGHT", 8, 0)
    bw.go:SetScript("OnClick", function() bw:Run() end)
    bw.save = UI:IconButton(bw, "star", 28, "Garder cette recherche dans la barre de gauche.")
    bw.save:SetPoint("LEFT", bw.go, "RIGHT", 6, 0)
    bw.save:SetScript("OnClick", function()
        local q = bw.last
        if not q then return end
        for _, sq in ipairs(cfg().searches) do if sq.key == q.key then return end end
        table.insert(cfg().searches, q)
        f:RefreshSide()
    end)
    function bw:PaintChips()
        self.usable:SetStyle(cfg().browseUsable and "primary" or "ghost")
        self.deal:SetStyle(self.dealOnly and "primary" or "ghost")
        self.qual:SetStyle(self.minQ and "primary" or "ghost")
    end

    -- gauche : catégories du jeu (AuctionCategories), une dépliée à la fois
    bw.cats = panelBox(bw, "Catégories")
    bw.cats:SetPoint("TOPLEFT", 0, -40); bw.cats:SetPoint("BOTTOMLEFT"); bw.cats:SetWidth(156)
    bw.crows = {}
    for i = 1, 24 do
        local r = textRow(bw.cats, 20)
        r:SetPoint("TOPLEFT", 4, -28 - (i - 1) * 20); r:SetPoint("TOPRIGHT", -4, -28 - (i - 1) * 20)
        r.icon:Hide(); r.a:SetPoint("RIGHT", -4, 0)
        r.ci = UI:Icon(r, "chevron", 12); r.ci:SetPoint("LEFT", 6, 0)
        r:SetScript("OnClick", function(s)
            if not s.path then return end
            local same = bw.cat and table.concat(bw.cat, ".") == table.concat(s.path, ".")
            bw.cat = (same and #s.path == 1) and nil or s.path
            bw:RefreshCats()
            bw:Run()
        end)
        bw.crows[i] = r
    end
    local function catAt(path)
        local list, node = _G.AuctionCategories, nil
        for _, i in ipairs(path or {}) do
            node = list and list[i]
            list = node and node.subCategories
        end
        return node
    end
    -- icône d'une catégorie, d'après la classe d'objet de son premier filtre
    local CAT_ICON = { [0] = "fire", [1] = "bag", [2] = "crosshair", [3] = "star", [4] = "safe", [5] = "spark", [7] = "hammer",
        [9] = "book", [12] = "notes", [15] = "menu", [16] = "notes", [17] = "users" }
    local function catIcon(node)
        local fl = node and node.filters and node.filters[1]
        return (fl and CAT_ICON[fl.classID]) or "menu"
    end
    function bw:RefreshCats()
        local cats = _G.AuctionCategories or {}
        local rows, open = {}, self.cat and self.cat[1]
        for i, c in ipairs(cats) do
            -- le jeton WoW n'existe pas sur WoW Forever : sa catégorie est retirée
            local token = c.name and (c.name == _G.TOKEN_FILTER_LABEL or c.name:find("[Jj]eton") or c.name:find("[Tt]oken"))
            if c.name and not c.implicitFilter and not token then
                table.insert(rows, { path = { i }, name = c.name, depth = 0, icon = catIcon(c) })
                if open == i then
                    for j, sc in ipairs(c.subCategories or {}) do
                        if sc.name then table.insert(rows, { path = { i, j }, name = sc.name, depth = 1 }) end
                    end
                end
            end
        end
        local key = self.cat and table.concat(self.cat, ".")
        local ar, ag, ab = UI:Accent()
        for i, r in ipairs(self.crows) do
            local e = rows[i]
            r.path = e and e.path
            if e then
                local on = key == table.concat(e.path, ".")
                -- une icône par catégorie ; la sous-catégorie choisie marquée d'un chevron
                r.ci:SetShown(e.depth == 0 or on)
                r.ci:ClearAllPoints(); r.ci:SetPoint("LEFT", e.depth == 0 and 6 or 16, 0)
                r.ci:SetTexture(UI.MEDIA .. (e.depth == 0 and e.icon or "chevron"))
                if r.ci.SetRotation then r.ci:SetRotation(e.depth == 0 and 0 or math.pi / 2) end
                r.ci:SetVertexColor(ar, ag, ab, (on or (self.cat and self.cat[1] == e.path[1])) and 1 or 0.6)
                r.a:SetPoint("LEFT", e.depth == 0 and 24 or 30, 0)
                r.a:SetText(e.name)
                r.a:SetTextColor(unpack((on or e.depth == 0) and C.text or C.muted))
                r.hl:SetColorTexture(ar, ag, ab, on and 0.16 or 0)
                r:Show()
            else r:Hide() end
        end
        self.cats.sub:SetText(#cats == 0 and T("indisponibles") or "")
    end

    -- milieu : résultats
    bw.res = panelBox(bw, "Résultats")
    bw.res:SetPoint("TOPLEFT", bw.cats, "TOPRIGHT", 8, 0); bw.res:SetPoint("BOTTOM"); bw.res:SetPoint("RIGHT", -318, 0)
    local RCOLS = { { "name", "Objet", 30, "LEFT" }, { "qty", "En vente", -248, "RIGHT" }, { "low", "Plus bas", -174, "RIGHT" }, { "delta", "vs 7 j", -126, "RIGHT" } }
    bw.heads = {}
    for _, cdef in ipairs(RCOLS) do
        local h = CreateFrame("Button", nil, bw.res)
        h:SetSize(80, 16)
        if cdef[4] == "LEFT" then h:SetPoint("TOPLEFT", cdef[3], -28) else h:SetPoint("TOPRIGHT", cdef[3], -28) end
        h.t = UI:Text(h, 9, C.dim); h.t:SetPoint(cdef[4]); h.t:SetText(UI:Upper(T(cdef[2])))
        h:SetScript("OnClick", function()
            if bw.sortKey == cdef[1] then bw.sortRev = not bw.sortRev else bw.sortKey, bw.sortRev = cdef[1], false end
            bw.offset = 0
            bw:RefreshResults()
        end)
        bw.heads[cdef[1]] = h
    end
    bw.rrows = {}
    local RROW = 24
    for i = 1, 22 do
        local r = textRow(bw.res, RROW)
        r:SetPoint("TOPLEFT", 6, -46 - (i - 1) * RROW); r:SetPoint("TOPRIGHT", -6, -46 - (i - 1) * RROW)
        r.a:SetPoint("RIGHT", -300, 0)
        r.b:SetPoint("RIGHT", -248, 0); r.b:SetWidth(48)
        r.c:SetPoint("RIGHT", -174, 0); r.c:SetWidth(72); r.c:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
        r.d:SetPoint("RIGHT", -126, 0); r.d:SetWidth(46)
        -- petite courbe des 7 derniers jours, puis l'étiquette (affaire, à toi, liste)
        r.spark = CreateFrame("Frame", nil, r)
        r.spark:SetSize(46, 14); r.spark:SetPoint("RIGHT", -74, 0)
        r.tag = UI:Badge(r, "", C.muted); r.tag:SetPoint("RIGHT", -2, 0)
        r:SetScript("OnClick", function(s) if s.e then bw:Pick(s.e.id, s.e.key) end end)
        r:SetScript("OnEnter", function(s)
            if not s.e then return end
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            if GameTooltip.SetItemByID then GameTooltip:SetItemByID(s.e.id) end
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        r:Hide()
        bw.rrows[i] = r
    end
    bw.sparks = UI:LinePool(3)
    -- courbe de 7 jours dans une ligne : verte en baisse, rouge en hausse, grise sinon
    local function drawSpark(fr, id)
        local all = S:History(id)
        local today = math.floor(time() / 86400)
        local pts = {}
        for _, h in ipairs(all) do if h[1] > today - 7 then table.insert(pts, h) end end
        if #pts < 2 then return end
        local lo, hi = math.huge, 0
        for _, h in ipairs(pts) do lo = math.min(lo, h[2]); hi = math.max(hi, h[2]) end
        if hi == lo then hi = lo + 1 end
        local W, H = 46, 14
        local d = pts[#pts][2] - pts[1][2]
        local col = (d < -pts[1][2] * 0.05) and C.positive or (d > pts[1][2] * 0.05) and C.negative or C.muted
        for i = 2, #pts do
            local a, b = pts[i - 1], pts[i]
            bw.sparks:Add(fr, (a[1] - (today - 6)) / 6 * W, H - (a[2] - lo) / (hi - lo) * H,
                (b[1] - (today - 6)) / 6 * W, H - (b[2] - lo) / (hi - lo) * H, 1.5, col[1], col[2], col[3], 1)
        end
    end
    bw.res:EnableMouseWheel(true)
    bw.res:SetScript("OnMouseWheel", function(_, d)
        bw.offset = math.max(0, bw.offset - d * 3)
        bw:RefreshResults()
    end)
    bw.status = UI:Text(bw.res, 10, C.dim); bw.status:SetPoint("BOTTOMLEFT", 10, 8); bw.status:SetPoint("BOTTOMRIGHT", -10, 8); bw.status:SetJustifyH("LEFT")
    bw.empty = UI:Text(bw.res, 11, C.muted); bw.empty:SetPoint("CENTER"); bw.empty:SetWidth(320)
    bw.empty:SetText(T("Tape un nom ou choisis une catégorie, puis « Chercher »."))

    -- droite : l'objet choisi
    bw.det = panelBox(bw, "")
    bw.det:SetPoint("TOPRIGHT", 0, -40); bw.det:SetPoint("BOTTOMRIGHT"); bw.det:SetWidth(310)
    bw.det.title:Hide()
    bw.dIcon = bw.det:CreateTexture(nil, "ARTWORK"); bw.dIcon:SetSize(30, 30); bw.dIcon:SetPoint("TOPLEFT", 10, -10)
    bw.dIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    bw.dName = UI:Text(bw.det, 13); bw.dName:SetPoint("TOPLEFT", 48, -10); bw.dName:SetPoint("TOPRIGHT", -10, -10); bw.dName:SetJustifyH("LEFT")
    if bw.dName.SetWordWrap then bw.dName:SetWordWrap(false) end
    bw.dSub = UI:Text(bw.det, 10, C.muted); bw.dSub:SetPoint("TOPLEFT", 48, -28); bw.dSub:SetPoint("TOPRIGHT", -10, -28); bw.dSub:SetJustifyH("LEFT")
    -- onglets du détail : Enchères, Courbe, Infos
    bw.dtab = "list"
    bw.tabs = UI:Segmented(bw.det, { { "list", "Enchères" }, { "chart", "Courbe" }, { "info", "Infos" } },
        function(v) bw.dtab = v; bw:RefreshDetail() end, 24)
    bw.tabs:SetPoint("TOPLEFT", 10, -46)
    bw.tabs:Select("list")
    bw.chart = makeChart(bw.det)
    bw.chart:SetPoint("TOPLEFT", 4, -80); bw.chart:SetPoint("TOPRIGHT", -6, -80); bw.chart:SetHeight(190)
    bw.chartNote = UI:Text(bw.det, 10, C.dim); bw.chartNote:SetPoint("TOPLEFT", 12, -278); bw.chartNote:SetPoint("TOPRIGHT", -12, -278)
    bw.chartNote:SetJustifyH("LEFT")
    bw.info = UI:Text(bw.det, 11, C.muted); bw.info:SetPoint("TOPLEFT", 12, -84); bw.info:SetPoint("TOPRIGHT", -12, -84)
    bw.info:SetJustifyH("LEFT"); bw.info:SetJustifyV("TOP")
    if bw.info.SetSpacing then bw.info:SetSpacing(6) end
    bw.lhead = CreateFrame("Frame", nil, bw.det)
    bw.lhead:SetPoint("TOPLEFT", 6, -82); bw.lhead:SetPoint("TOPRIGHT", -6, -82); bw.lhead:SetHeight(12)
    for _, hd in ipairs({ { "Prix", "LEFT", 6 }, { "Qté", "RIGHT", 140 }, { "Cumul", "LEFT", 154 } }) do
        local t = UI:Text(bw.lhead, 9, C.dim)
        t:SetPoint(hd[2], bw.lhead, "LEFT", hd[3], 0); t:SetText(UI:Upper(T(hd[1])))
    end
    bw.lrows = {}
    for i = 1, 10 do
        local r = textRow(bw.det, 22)
        r:SetPoint("TOPLEFT", 6, -96 - (i - 1) * 22); r:SetPoint("TOPRIGHT", -6, -96 - (i - 1) * 22)
        r.icon:Hide(); r.a:SetPoint("LEFT", 6, 0); r.a:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
        r.b:SetPoint("RIGHT", r, "LEFT", 140, 0); r.b:SetWidth(50)
        r.c:SetPoint("LEFT", 154, 0); r.c:SetWidth(56); r.c:SetJustifyH("LEFT")
        r.act = UI:Button(r, "Acheter", 76, 18, "secondary"); r.act:SetPoint("RIGHT", -2, 0)
        r.act:SetScript("OnClick", function(s)
            local row = s:GetParent()
            if row.x and bw.id then bw:BuyRow(row.x) end
        end)
        bw.lrows[i] = r
    end
    -- quantité : pastilles 1, une pile, cinq piles, tout ce qui est en vente ; ou à la main
    bw.qchips = {}
    local qx = 12
    for _, qd in ipairs({ { "one", "1" }, { "stack", "Pile" }, { "five", "5 piles" }, { "max", "Max" } }) do
        local b = UI:Button(bw.det, qd[2], nil, 22, "ghost")
        b:SetWidth(b.label:GetStringWidth() + 18)
        b:SetPoint("BOTTOMLEFT", qx, 126)
        qx = qx + b:GetWidth() + 4
        b:SetScript("OnClick", function()
            local id = bw.id
            if not id then return end
            local st = stackOf(id)
            local n = qd[1] == "one" and 1 or qd[1] == "stack" and st or qd[1] == "five" and st * 5 or (available(id) or 1)
            bw.qty:SetText(tostring(math.max(1, n)))
        end)
        bw.qchips[qd[1]] = b
    end
    bw.qLabel = UI:Text(bw.det, 11, C.muted); bw.qLabel:SetPoint("BOTTOMLEFT", 12, 98); bw.qLabel:SetText(T("Quantité"))
    bw.qty = UI:NumberInput(bw.det, 64, 26, "1"); bw.qty:SetPoint("LEFT", bw.qLabel, "RIGHT", 8, 0)
    bw.qty.onChange = function() bw:RefreshDetail() end
    bw.sum = UI:Text(bw.det, 11, C.muted); bw.sum:SetPoint("BOTTOMLEFT", 12, 70); bw.sum:SetPoint("BOTTOMRIGHT", -12, 70); bw.sum:SetJustifyH("LEFT")
    bw.buy = UI:Button(bw.det, "Acheter", nil, 32, "primary")
    bw.buy:SetPoint("BOTTOMLEFT", 12, 30); bw.buy:SetPoint("BOTTOMRIGHT", -12, 30)
    bw.buy:SetScript("OnClick", function() bw:BuyQty() end)
    bw.watchIn = UI:Input(bw.det, 96, 22, "ex. 45pa", nil); bw.watchIn:SetPoint("BOTTOMLEFT", 12, 4)
    bw.watch = UI:Button(bw.det, "Surveiller", nil, 22, "ghost"); bw.watch:SetPoint("LEFT", bw.watchIn, "RIGHT", 6, 0)
    bw.watch.tooltip = "Alerte de prix : prévenu après un scan quand le plus bas passe sous ce prix."
    bw.watch:SetScript("OnClick", function()
        local v = A.ParsePrice(bw.watchIn:GetText())
        if bw.id and v then A:AddAlert(bw.id, v); WK:Print(string.format(T("Alerte de prix : %s sous %s."), WK.GetItemInfo(bw.id) or "?", money(v))); bw:RefreshDetail() end
    end)
    -- « + Liste » : la quantité voulue dans la liste d'achat choisie (sinon « Mes achats »)
    bw.toList = UI:Button(bw.det, "+ Liste", nil, 22, "ghost"); bw.toList:SetPoint("LEFT", bw.watch, "RIGHT", 4, 0)
    bw.toList.tooltip = "Ajouter la quantité voulue à ta liste d'achat (page À acheter)."
    bw.toList:SetScript("OnClick", function()
        local id = bw.id
        if not id then return end
        local _, lists = S:Lists()
        local name = cfg().curList
        if not (name and lists[name]) or (lists[name] and lists[name].auto) then name = T("Mes achats") end
        local l = lists[name] or { items = {}, at = time(), v = 2 }
        lists[name] = l
        local q = math.max(1, bw.qty:GetNumber())
        local found
        for _, it in ipairs(l.items) do if it[1] == id then it[2] = it[2] + q; found = true end end
        if not found then table.insert(l.items, { id, q + S:Have(id) }) end
        cfg().curList = name
        WK:Print(string.format(T("%s ajouté à la liste « %s »."), WK.GetItemInfo(id) or "?", name))
    end)
    bw.dEmpty = UI:Text(bw.det, 11, C.muted); bw.dEmpty:SetPoint("CENTER"); bw.dEmpty:SetWidth(280)
    bw.dEmpty:SetText(T("Choisis un objet dans les résultats : ses enchères, sa courbe et l'achat."))

    -- recherche envoyée au jeu (une à la fois ; la file des recherches d'objets attend)
    local browse = { rows = {}, busy = false }
    function bw:Query()
        local q = { text = self.search:GetText() or "", usable = cfg().browseUsable or nil,
                    minL = self.minL:GetNumber() > 0 and self.minL:GetNumber() or nil,
                    maxL = self.maxL:GetNumber() > 0 and self.maxL:GetNumber() or nil, cat = self.cat }
        local node = catAt(q.cat)
        local parts = { q.text }
        if node and node.name then table.insert(parts, 1, node.name) end
        q.name = table.concat(parts, " · "):gsub("^ · ", ""):gsub(" · $", "")
        q.key = table.concat({ q.text, table.concat(q.cat or {}, "."), tostring(q.usable), tostring(q.minL), tostring(q.maxL) }, "|")
        return q, node
    end
    function bw:Run(q)
        if q then
            -- recherche enregistrée ou récente : elle remplit les champs
            self.search:SetText(q.text or "")
            self.minL:SetText(q.minL and tostring(q.minL) or ""); self.maxL:SetText(q.maxL and tostring(q.maxL) or "")
            cfg().browseUsable = q.usable or nil
            self.cat = q.cat
            self:PaintChips(); self:RefreshCats()
        end
        local query, node = self:Query()
        if query.text == "" and not node then return end
        local a = AH()
        if not (a and a.SendBrowseQuery) then WK:Print(T("Ce client ne permet pas la recherche depuis l'addon.")) return end
        local filters = {}
        if query.usable and Enum and Enum.AuctionHouseFilter and Enum.AuctionHouseFilter.UsableOnly then
            table.insert(filters, Enum.AuctionHouseFilter.UsableOnly)
        end
        local po = Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price or 0
        local sq = { searchString = query.text, sorts = { { sortOrder = po, reverseSort = false } }, filters = filters,
                     itemClassFilters = node and node.filters or {} }
        if query.minL then sq.minLevel = query.minL end
        if query.maxL then sq.maxLevel = query.maxL end
        pending, pendingAt = "browse", GetTime()
        browse = { rows = {}, busy = true, at = GetTime() }
        self.offset = 0
        if not pcall(a.SendBrowseQuery, sq) then browse.busy = false; pending = nil end
        self.last = query
        -- récentes : la dernière en tête, six au plus
        local rec = cfg().recent
        for i = #rec, 1, -1 do if rec[i].key == query.key then table.remove(rec, i) end end
        table.insert(rec, 1, query)
        while #rec > 6 do table.remove(rec) end
        f:RefreshSide()
        self:RefreshResults()
    end
    local function readBrowse()
        local a = AH()
        if not (a and a.GetBrowseResults) then return end
        local ok, list = pcall(a.GetBrowseResults)
        if not ok or type(list) ~= "table" then return end
        local rows = {}
        for _, r in ipairs(list) do
            local key = r.itemKey
            local id = key and key.itemID
            if id then
                table.insert(rows, { id = id, key = key, qty = r.totalQuantity or 0, low = r.minPrice, mine = r.containsOwnerItem })
                -- (Parcourir ne donne qu'un plus bas brut, appâts, tes enchères et variantes compris : il ne compte
                -- plus pour la courbe du jour ; seule la recherche d'un objet, sans appâts, y entre)
            end
        end
        browse.rows, browse.busy = rows, false
        browse.full = not (a.HasFullBrowseResults and not a.HasFullBrowseResults())
        if pending == "browse" then pending = nil end
        if bw:IsShown() then bw:RefreshResults() end
    end
    WK:On("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", function() readBrowse() end)
    WK:On("AUCTION_HOUSE_BROWSE_RESULTS_ADDED", function() readBrowse() end)

    local function inLists()
        local set = {}
        local _, lists = S:Lists()
        for _, l in pairs(lists) do for _, it in ipairs(l.items or {}) do set[it[1]] = true end end
        return set
    end
    function bw:RefreshResults()
        local list = {}
        for _, e in ipairs(browse.rows) do
            local avg = S:Average(e.id, 7)
            e.delta = (avg and avg > 0 and e.low) and (e.low - avg) / avg or nil
            e.name = e.name or WK.GetItemInfo(e.id)
            local q = self.minQ and select(3, WK.GetItemInfo(e.id))
            if (not self.dealOnly or (e.delta and e.delta <= -0.2)) and (not self.minQ or (q and q >= self.minQ)) then table.insert(list, e) end
        end
        local k, rev = self.sortKey, self.sortRev
        table.sort(list, function(x, y)
            local vx, vy
            if k == "name" then vx, vy = x.name or "", y.name or ""
            elseif k == "qty" then vx, vy = x.qty or 0, y.qty or 0
            elseif k == "delta" then vx, vy = x.delta or 9, y.delta or 9
            else vx, vy = x.low or math.huge, y.low or math.huge end
            if vx == vy then return x.id < y.id end
            if rev then return vx > vy end
            return vx < vy
        end)
        local rows = #self.rrows
        local fit = math.max(1, math.floor(((self.res:GetHeight() or 400) - 76) / RROW))
        fit = math.min(fit, rows)
        self.offset = math.max(0, math.min(self.offset, #list - fit))
        -- on arrive au bout : la suite des résultats
        local a = AH()
        if not browse.full and not browse.busy and self.offset + fit >= #list - 2 and a and a.RequestMoreBrowseResults and #list > 0 then
            browse.busy = true
            pcall(a.RequestMoreBrowseResults)
        end
        local listed = inLists()
        local ar, ag, ab = UI:Accent()
        self.sparks:Reset()
        for i, r in ipairs(self.rrows) do
            local e = i <= fit and list[self.offset + i]
            r.e = e
            if e then
                r.icon:SetTexture(itemIcon(e.id))
                local name, _, quality = WK.GetItemInfo(e.id)
                r.a:SetText(name or ("#" .. e.id))
                if quality and GetItemQualityColor then r.a:SetTextColor(GetItemQualityColor(quality)) else r.a:SetTextColor(1, 1, 1) end
                r.b:SetText(tostring(e.qty or 0))
                r.c:SetText(e.low and money(e.low) or "-")
                if e.delta then
                    local pc = math.floor(e.delta * 100 + 0.5)
                    r.d:SetText((pc > 0 and "+" or "") .. pc .. " %")
                    local col = pc <= -20 and C.positive or pc >= 20 and C.negative or C.muted
                    r.d:SetTextColor(col[1], col[2], col[3])
                else r.d:SetText("-"); r.d:SetTextColor(C.dim[1], C.dim[2], C.dim[3]) end
                -- étiquette : affaire (sous 80 % de la moyenne), dans une liste d'achat, ou combien tes persos en ont
                local have = S:Have(e.id)
                if e.delta and e.delta <= -0.2 then r.tag:Set(T("affaire"), C.positive); r.tag:Show()
                elseif listed[e.id] then r.tag:Set(T("liste"), { ar, ag, ab }); r.tag:Show()
                elseif have > 0 then r.tag:Set(string.format(T("à toi : %d"), have), C.rule); r.tag:Show()
                else r.tag:Hide() end
                drawSpark(r.spark, e.id)
                r.hl:SetColorTexture(ar, ag, ab, e.id == self.id and 0.14 or 0)
                r:Show()
            else r:Hide() end
        end
        self.empty:SetShown(#list == 0)
        if browse.busy and #list == 0 then self.empty:SetText(T("Recherche…"))
        elseif self.last and #list == 0 then self.empty:SetText(T("Rien en vente pour cette recherche."))
        else self.empty:SetText(T("Tape un nom ou choisis une catégorie, puis « Chercher ».")) end
        self.res.sub:SetText(#list > 0 and string.format(T("%d objets"), #list) .. (browse.full and "" or "+") or "")
        self.status:SetText(#list > fit and string.format(T("%d-%d sur %d · molette pour défiler · clic sur un titre : trier"), self.offset + 1, math.min(#list, self.offset + fit), #list) or "")
        for key, h in pairs(self.heads) do
            local on = key == self.sortKey
            if on then h.t:SetTextColor(ar, ag, ab) else h.t:SetTextColor(C.dim[1], C.dim[2], C.dim[3]) end
        end
    end

    function bw:Pick(id)
        self.id = id
        self.qty:SetText("")
        search(id, true); pump()
        self:RefreshResults()
        self:RefreshDetail()
    end
    -- achat d'une ligne : objet unique au prix d'achat immédiat ; marchandise : la quantité de la ligne
    function bw:BuyRow(x)
        local id, a = self.id, AH()
        if not (id and a) then return end
        if not isCommodity(id) and x.auctionID and a.PlaceBid then
            if not armBid(x) then self:RefreshDetail() return end
            if not pcall(a.PlaceBid, x.auctionID, x.buyout or x.unit * x.qty) then WK:Print(T("Achat refusé par le jeu.")) end
            C_Timer.After(1, function() search(id, true) end)
            return
        end
        self.qty:SetText(tostring(x.qty))
        self:BuyQty()
    end
    -- marchandise : 1er clic = prix demandé au jeu, 2e clic = confirmation (le jeu l'exige)
    function bw:BuyQty()
        local id = self.id
        if not id then return end
        commodityClick(id, math.max(1, self.qty:GetNumber()))
        self:RefreshDetail()
    end
    function bw:RefreshDetail()
        local id = self.id
        local has = id ~= nil
        local tab = self.dtab
        for _, w in ipairs({ self.dIcon, self.dName, self.dSub, self.tabs, self.watchIn, self.watch, self.toList }) do w:SetShown(has) end
        self.chart:SetShown(has and tab == "chart"); self.chartNote:SetShown(has and tab == "chart")
        self.info:SetShown(has and tab == "info"); self.lhead:SetShown(has and tab == "list")
        self.dEmpty:SetShown(not has)
        local commodity = has and isCommodity(id)
        for _, w in ipairs({ self.qLabel, self.qty, self.sum, self.buy }) do w:SetShown(has and commodity) end
        for _, b in pairs(self.qchips) do b:SetShown(has and commodity) end
        for _, r in ipairs(self.lrows) do r:Hide() end
        if not has then return end
        local name, _, quality = WK.GetItemInfo(id)
        self.dIcon:SetTexture(itemIcon(id))
        self.dName:SetText(name or ("#" .. id))
        if quality and GetItemQualityColor then self.dName:SetTextColor(GetItemQualityColor(quality)) end
        local avg = S:Average(id, 7)
        local alert = (A.Config().alerts or {})[id]
        self.dSub:SetText((commodity and T("marchandise") or T("objet unique")) .. (avg and ("  ·  " .. T("moyenne") .. " " .. money(avg)) or ""))
        self.watch:SetLabel(alert and string.format(T("Alerte sous %s"), money(alert)) or T("Surveiller"))
        self.watch:SetWidth(self.watch.label:GetStringWidth() + 24)
        if tab == "chart" then
            local hist, cavg = self.chart:Draw(id, 14, { bars = true })
            local last = hist[#hist]
            self.chartNote:SetText((last and (T("dernier") .. " " .. money(last[2]) .. "  ·  ") or "") .. (cavg and (T("moyenne") .. " " .. money(cavg)) or "")
                .. "\n" .. T("14 jours · tirets : moyenne · barres : quantité en vente"))
        elseif tab == "info" then
            local vendor = select(11, WK.GetItemInfo(id)) or 0
            local nSold, gross = 0, 0
            local log = WK.DB.global.auction and WK.DB.global.auction.log or {}
            for _, l in ipairs(log) do
                if (l.t or 0) >= time() - 7 * 86400 and l.kind == "sale" and l.item == name then nSold = nSold + (l.count or 1); gross = gross + (l.gross or 0) end
            end
            local e = S:Entry(id)
            local lines = {
                T("À toi (compte)") .. " : " .. UI:Hex(C.text) .. S:Have(id) .. "|r",
                T("Moyenne") .. " : " .. (avg and money(avg) or "-"),
                T("Marchand") .. " : " .. (vendor > 0 and money(vendor) or "-"),
                T("Tes ventes (7 j)") .. " : " .. (nSold > 0 and (nSold .. "  ·  " .. money(math.floor(gross / nSold))) or "-"),
                T("Alerte de prix") .. " : " .. (alert and money(alert) or "-"),
                T("Dernier relevé") .. " : " .. ((e and e.t) and UI:Ago(e.t) or "-"),
            }
            self.info:SetText(table.concat(lines, "\n"))
        end
        local r = results[id]
        local want = math.max(1, self.qty:GetNumber())
        local b = S.buy
        if tab == "list" then
            if not r then
                local row = self.lrows[1]
                row.x = nil; row.act:Hide(); row.a:SetText(UI:Hex(C.muted) .. T("recherche…") .. "|r"); row.b:SetText(""); row.c:SetText("")
                row.hl:SetColorTexture(0, 0, 0, 0); row:Show()
            end
        end
        if not r then self.sum:SetText(""); self.buy:SetEnabled(false); return end
        -- enchères : prix, quantité, cumul ; celles qu'il faut pour la quantité voulue sont surlignées
        local cum, cost, got = 0, 0, 0
        local ar, ag, ab = UI:Accent()
        for i, row in ipairs(self.lrows) do
            local x = r.rows[i]
            row.x = x
            if x then
                cum = cum + x.qty
                local inQty = commodity and got < want and not x.mine
                if inQty then
                    local take = math.min(x.qty, want - got)
                    got = got + take; cost = cost + take * x.unit
                end
                if tab == "list" then
                    row.a:SetText(money(x.unit))
                    row.b:SetText(tostring(x.qty))
                    row.c:SetText(x.mine and (UI:Hex(C.info) .. T("toi") .. "|r") or tostring(cum))
                    row.hl:SetColorTexture(ar, ag, ab, inQty and 0.12 or 0)
                    row.act:SetShown(not x.mine)
                    row.act:SetLabel(commodity and string.format(T("Prendre %d"), x.qty)
                        or (bidArmed(x) and string.format(T("Confirmer %s"), money(x.buyout or x.unit * x.qty))) or T("Acheter"))
                    row:Show()
                end
            end
        end
        if #r.rows == 0 and tab == "list" then
            local row = self.lrows[1]
            row.x = nil; row.act:Hide(); row.a:SetText(UI:Hex(C.muted) .. T("personne n'en vend") .. "|r"); row.b:SetText(""); row.c:SetText("")
            row.hl:SetColorTexture(0, 0, 0, 0); row:Show()
        end
        if commodity then
            local last = r.rows[math.min(#r.rows, #self.lrows)]
            if got < want and last then cost = cost + (want - got) * last.unit; got = want end
            self.sum:SetText(got > 0 and string.format(T("Environ %s l'unité · total %s"), money(math.floor(cost / math.max(1, got))), money(cost)) or "")
            local busy = b and b.id == id and (b.phase == "quote" or b.phase == "wait")
            if b and b.id == id and b.phase == "confirm" then self.buy:SetLabel(string.format(T("Confirmer %d pour %s"), b.qty or 0, money(b.total)))
            elseif busy then self.buy:SetLabel("…")
            else self.buy:SetLabel(string.format(T("Acheter %d"), want)) end
            self.buy:SetEnabled(not busy and #r.rows > 0)
            -- pastille de quantité qui correspond
            local st = stackOf(id)
            local av = available(id)
            for k, bt in pairs(self.qchips) do
                local n = k == "one" and 1 or k == "stack" and st or k == "five" and st * 5 or av
                bt:SetStyle(n == want and "primary" or "ghost")
            end
        end
    end
    function bw:Refresh()
        self:PaintChips()
        if not self.catsDone then self.catsDone = true; self:RefreshCats() end
        self:RefreshResults()
        self:RefreshDetail()
    end
    bw:SetScript("OnSizeChanged", function() if bw:IsVisible() then bw:RefreshResults() end end)

    -----------------------------------------------------------------------
    -- Prix : la fiche d'un objet. À gauche la liste (recherche, Ça bouge, Mes sacs, Mes ventes, Surveillés) ;
    -- au milieu la courbe 7 / 14 / 30 jours (plus bas, moyenne, ton prix moyen de vente, quantité en vente),
    -- six chiffres clés, combien tu en as, Vendre les miens / Surveiller / Chercher.
    -----------------------------------------------------------------------
    local pv = CreateFrame("Frame", nil, f.content)
    pv:SetAllPoints(f.content)
    f.views.prices = pv
    pv.mode, pv.days = "movers", 14
    pv.left = panelBox(pv, "Objets")
    pv.left:SetPoint("TOPLEFT"); pv.left:SetPoint("BOTTOMLEFT"); pv.left:SetWidth(260)
    pv.search = UI:Input(pv.left, 238, 26, "Chercher un objet scanné…", "search")
    pv.search:SetPoint("TOPLEFT", 10, -30)
    pv.search.onChange = function() pv:Refresh() end
    pv.modes = {}
    local px0, py0 = 10, -62
    for _, md in ipairs({ { "movers", "Ça bouge" }, { "bags", "Mes sacs" }, { "sales", "Mes ventes" }, { "watch", "Surveillés" } }) do
        local b = UI:Button(pv.left, md[2], nil, 22, "ghost")
        b:SetWidth(b.label:GetStringWidth() + 18)
        if px0 + b:GetWidth() > 250 then px0, py0 = 10, py0 - 26 end
        b:SetPoint("TOPLEFT", px0, py0)
        px0 = px0 + b:GetWidth() + 4
        b:SetScript("OnClick", function() pv.mode = md[1]; pv.search:SetText(""); pv:Refresh() end)
        pv.modes[md[1]] = b
    end
    local LTOP = py0 - 30
    pv.rows = {}
    for i = 1, 18 do
        local r = textRow(pv.left, 22)
        r:SetPoint("TOPLEFT", 6, LTOP - (i - 1) * 23); r:SetPoint("TOPRIGHT", -6, LTOP - (i - 1) * 23)
        r.a:SetPoint("RIGHT", -64, 0)
        r.b:SetPoint("RIGHT", -6, 0); r.b:SetWidth(58)
        r:SetScript("OnClick", function(s) if s.id then pv.id = s.id; pv:Refresh() end end)
        -- survol : l'infobulle de l'objet (avec nos lignes : persos, prix…)
        r:SetScript("OnEnter", function(s)
            if not s.id then return end
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            if GameTooltip.SetItemByID then GameTooltip:SetItemByID(s.id) end
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        r:Hide()
        pv.rows[i] = r
    end
    pv.lempty = UI:Text(pv.left, 11, C.muted); pv.lempty:SetPoint("TOP", 0, LTOP - 20); pv.lempty:SetWidth(220)

    -- courbe
    pv.main = panelBox(pv, "")
    pv.main:SetPoint("TOPLEFT", pv.left, "TOPRIGHT", 8, 0); pv.main:SetPoint("TOPRIGHT"); pv.main:SetHeight(330)
    pv.icon = pv.main:CreateTexture(nil, "ARTWORK"); pv.icon:SetSize(20, 20); pv.icon:SetPoint("TOPLEFT", 10, -7)
    pv.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    pv.main.title:ClearAllPoints(); pv.main.title:SetPoint("LEFT", pv.icon, "RIGHT", 8, 0)
    pv.range = UI:Segmented(pv.main, { { 7, "7 j" }, { 14, "14 j" }, { 30, "30 j" } }, function(v) pv.days = v; pv:Refresh() end, 24)
    pv.range:SetPoint("TOPRIGHT", -10, -6)
    pv.range:Select(14)
    pv.chart = makeChart(pv.main)
    pv.chart:SetPoint("TOPLEFT", 6, -40); pv.chart:SetPoint("BOTTOMRIGHT", -16, 30)
    pv.legend = UI:Text(pv.main, 10, C.dim); pv.legend:SetPoint("BOTTOMLEFT", 16, 10)
    pv.empty = UI:Text(pv.main, 11, C.muted); pv.empty:SetPoint("CENTER")

    -- six chiffres
    pv.tiles = {}
    for i = 1, 6 do
        local t = CreateFrame("Frame", nil, pv)
        UI:Panel(t, 8, C.surface, C.border)
        t:SetHeight(50)
        t.l = UI:Text(t, 9, C.dim); t.l:SetPoint("TOPLEFT", 10, -8)
        t.v = UI:Text(t, 14, C.text); t.v:SetPoint("TOPLEFT", 10, -24)
        pv.tiles[i] = t
    end
    local function layoutTiles()
        local w = (pv.main:GetWidth() or 680)
        local tw = math.floor((w - 5 * 8) / 6)
        for i, t in ipairs(pv.tiles) do
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", pv.main, "BOTTOMLEFT", (i - 1) * (tw + 8), -10)
            t:SetWidth(tw)
        end
    end
    pv.main:SetScript("OnSizeChanged", layoutTiles)

    -- combien tu en as, actions
    pv.have = UI:Text(pv, 11, C.muted)
    pv.have:SetPoint("TOPLEFT", pv.main, "BOTTOMLEFT", 4, -80)
    pv.find = UI:Button(pv, "Chercher", nil, 26, "secondary")
    pv.find:SetPoint("TOPRIGHT", pv.main, "BOTTOMRIGHT", 0, -74)
    pv.find:SetScript("OnClick", function() if pv.id then UI:AHWindowSearch(pv.id, WK.GetItemInfo(pv.id)) end end)
    pv.watchBtn = UI:Button(pv, "Surveiller", nil, 26, "secondary"); pv.watchBtn:SetPoint("RIGHT", pv.find, "LEFT", -6, 0)
    pv.watch = UI:Input(pv, 110, 26, "ex. 45pa", nil); pv.watch:SetPoint("RIGHT", pv.watchBtn, "LEFT", -6, 0)
    pv.watchBtn:SetScript("OnClick", function()
        local v = A.ParsePrice(pv.watch:GetText())
        if pv.id and v then A:AddAlert(pv.id, v); WK:Print(string.format(T("Alerte de prix : %s sous %s."), WK.GetItemInfo(pv.id) or "?", money(v))); pv:Refresh() end
    end)
    pv.sellBtn = UI:Button(pv, "Vendre les miens", nil, 26, "primary"); pv.sellBtn:SetPoint("RIGHT", pv.watch, "LEFT", -10, 0)
    pv.sellBtn:SetScript("OnClick", function() if pv.id then f:Open("sell"); f.views.sell:Select(pv.id) end end)
    pv.note = UI:Text(pv, 10, C.dim); pv.note:SetPoint("TOPLEFT", pv.main, "BOTTOMLEFT", 4, -112); pv.note:SetPoint("RIGHT", pv, "RIGHT", 0, 0)
    pv.note:SetJustifyH("LEFT")
    pv.note:SetText(T("Survol d'un point : prix et quantité en vente ce jour. La courbe se remplit à chaque scan et à chaque recherche de l'objet."))

    -- tes ventes d'un objet sur 7 jours (factures du courrier) : nombre, prix moyen
    local function mySales(name, days)
        local log = WK.DB.global.auction and WK.DB.global.auction.log or {}
        local since = time() - (days or 7) * 86400
        local n, gross = 0, 0
        for _, l in ipairs(log) do
            if (l.t or 0) >= since and l.kind == "sale" and l.item == name then n = n + (l.count or 1); gross = gross + (l.gross or 0) end
        end
        return n, n > 0 and math.floor(gross / n) or nil
    end
    -- objets de la liste selon le mode
    local function listFor(mode, q)
        local list = {}
        if q ~= "" then
            for id in pairs(S:Data().items) do
                local name = WK.GetItemInfo(id)
                if name and string.lower(name):find(q, 1, true) then table.insert(list, { id }) end
                if #list >= 40 then break end
            end
        elseif mode == "bags" then
            local okB, items = pcall(bagItems)
            for _, e in ipairs(okB and items or {}) do if S:Price(e.id) then table.insert(list, { e.id, nil, e.count }) end end
        elseif mode == "sales" then
            local seen = {}
            local log = WK.DB.global.auction and WK.DB.global.auction.log or {}
            local byName = {}
            for id in pairs(S:Data().items) do local n = WK.GetItemInfo(id); if n then byName[n] = id end end
            for _, l in ipairs(log) do
                local id = l.kind == "sale" and l.item and byName[l.item]
                if id and not seen[id] then seen[id] = true; table.insert(list, { id }) end
            end
        elseif mode == "watch" then
            for id in pairs(A.Config().alerts or {}) do table.insert(list, { id }) end
        else
            for _, m in ipairs(S:Movers(18)) do table.insert(list, { m[1], m[2] }) end
        end
        return list
    end

    function pv:Refresh()
        local q = string.lower(self.search:GetText() or "")
        for k, b in pairs(self.modes) do b:SetStyle((q == "" and k == self.mode) and "primary" or "ghost") end
        local list = listFor(self.mode, q)
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
                else
                    local p = S:Price(it[1])
                    r.b:SetText(p and money(p) or ""); r.b:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
                end
                r.hl:SetColorTexture(ar, ag, ab, it[1] == self.id and 0.14 or 0)
                r:Show()
            else r:Hide() end
        end
        self.lempty:SetShown(#list == 0)
        self.lempty:SetText(T("Rien ici pour l'instant."))
        -- fiche
        local id = self.id
        local has = id ~= nil
        local name = id and WK.GetItemInfo(id)
        self.icon:SetShown(has)
        if has then self.icon:SetTexture(itemIcon(id)) end
        self.main.title:SetText(name or "")
        self.main.sub:SetText(has and T("plus bas de chaque jour") or "")
        local nSold, myAvg = 0, nil
        if name then nSold, myAvg = mySales(name, 7) end
        local hist, avg = self.chart:Draw(id, self.days, { mine = myAvg, bars = true })
        self.empty:SetShown(not has)
        self.empty:SetText(T("Choisis un objet dans la liste, ou cherche-le."))
        self.legend:SetText(has and (UI:Hex(C.text) .. "—|r " .. T("plus bas") .. "    " .. UI:Hex(C.gold) .. "- -|r " .. T("moyenne")
            .. (myAvg and ("    " .. UI:Hex(C.positive) .. "..|r " .. T("ton prix moyen de vente")) or "") .. "    " .. UI:Hex(C.info) .. "|||r " .. T("quantité en vente")) or "")
        -- chiffres clés
        local lo, hi
        for _, h in ipairs(hist) do lo = lo and math.min(lo, h[2]) or h[2]; hi = hi and math.max(hi, h[2]) or h[2] end
        local last = hist[#hist]
        local today = lowestOther(id or 0) or (last and last[2])
        local qty = available(id or 0) or (last and last[3])
        local vendor = id and select(11, WK.GetItemInfo(id)) or 0
        local tiles = {
            { T("Aujourd'hui"), today and money(today) or "-" },
            { string.format(T("Moyenne %d j"), self.days), avg and money(avg) or "-" },
            { T("Min / max"), lo and (money(lo) .. " / " .. money(hi)) or "-" },
            { T("En vente"), qty and tostring(qty) or "-" },
            { T("Tes ventes (7 j)"), nSold > 0 and (nSold .. " · " .. money(myAvg)) or "-" },
            { T("Marchand"), vendor > 0 and money(vendor) or "-" },
        }
        for i, t in ipairs(self.tiles) do
            t.l:SetText(UI:Upper(tiles[i][1])); t.v:SetText(tiles[i][2])
            t.v:SetTextColor(unpack(i == 5 and nSold > 0 and C.positive or C.text))
            t:SetShown(has)
        end
        layoutTiles()
        -- combien tu en as
        if has then
            local Inv = WK.modules.Inventory
            local total, b, k = 0, 0, 0
            if Inv and Inv.CharCount then total, b, k = Inv:CharCount(WK.DB:Me(), id) end
            local acc = S:Have(id)
            self.have:SetText(string.format(T("Tu en as %d (sacs %d, banque %d)"), total, b, k) .. (acc > total and ("  ·  " .. string.format(T("%d sur le compte"), acc)) or ""))
            local alert = (A.Config().alerts or {})[id]
            self.watchBtn:SetLabel(alert and string.format(T("Alerte sous %s"), money(alert)) or T("Surveiller"))
            self.watchBtn:SetWidth(self.watchBtn.label:GetStringWidth() + 28)
            self.sellBtn:SetEnabled(b > 0)
        end
        for _, w in ipairs({ self.have, self.find, self.watchBtn, self.watch, self.sellBtn, self.note }) do w:SetShown(has) end
    end

    -----------------------------------------------------------------------
    -- Scan et réglages : le scan à gauche (bouton, barre, chiffres, derniers scans), les réglages de l'HV
    -- à droite en trois cartes (Vente, Fenêtre, Données). Mêmes réglages que la page Hôtel des ventes de
    -- l'addon (ils changent ensemble).
    -----------------------------------------------------------------------
    local scv = CreateFrame("Frame", nil, f.content)
    scv:SetAllPoints(f.content)
    f.views.scan = scv
    local LW = 470
    scv.scan = panelBox(scv, "Scan des prix")
    scv.scan:SetPoint("TOPLEFT"); scv.scan:SetPoint("BOTTOMLEFT"); scv.scan:SetWidth(LW)
    scv.scan.sub:SetText(T("tout l'hôtel des ventes"))
    scv.go = UI:Button(scv.scan, "Scanner maintenant", 170, 34, "primary"); scv.go:SetPoint("TOPLEFT", 12, -34)
    scv.go:SetScript("OnClick", function() S:Start() end)
    scv.bar = CreateFrame("Frame", nil, scv.scan)
    scv.bar:SetPoint("TOPLEFT", 196, -40); scv.bar:SetPoint("TOPRIGHT", -12, -40); scv.bar:SetHeight(8)
    scv.bar.bg = UI:Rounded(scv.bar, 4, 0, "BACKGROUND", 1); scv.bar.bg:SetColor(C.border[1], C.border[2], C.border[3], 1)
    scv.bar.fillF = CreateFrame("Frame", nil, scv.bar); scv.bar.fillF:SetPoint("TOPLEFT"); scv.bar.fillF:SetPoint("BOTTOMLEFT")
    scv.bar.fill = UI:Rounded(scv.bar.fillF, 4, 0, "ARTWORK", 1)
    scv.info = UI:Text(scv.scan, 10, C.muted); scv.info:SetPoint("TOPLEFT", 196, -54); scv.info:SetPoint("TOPRIGHT", -12, -54)
    scv.info:SetJustifyH("LEFT")
    if scv.info.SetWordWrap then scv.info:SetWordWrap(true) end
    scv.tiles = {}
    local TW = math.floor((LW - 24 - 3 * 8) / 4)
    for i = 1, 4 do
        local t = CreateFrame("Frame", nil, scv.scan)
        UI:Panel(t, 8, C.bg, C.border)
        t:SetSize(TW, 52); t:SetPoint("TOPLEFT", 12 + (i - 1) * (TW + 8), -86)
        t.l = UI:Text(t, 9, C.dim); t.l:SetPoint("TOPLEFT", 8, -8); t.l:SetPoint("TOPRIGHT", -6, -8); t.l:SetJustifyH("LEFT")
        t.v = UI:Text(t, 14, C.text); t.v:SetPoint("BOTTOMLEFT", 8, 8)
        scv.tiles[i] = t
    end
    scv.histHead = UI:Text(scv.scan, 12); scv.histHead:SetPoint("TOPLEFT", 12, -154); scv.histHead:SetText(T("Derniers scans"))
    scv.hrows = {}
    for i = 1, 6 do
        local r = CreateFrame("Frame", nil, scv.scan)
        r:SetHeight(22); r:SetPoint("TOPLEFT", 12, -174 - (i - 1) * 24); r:SetPoint("TOPRIGHT", -12, -174 - (i - 1) * 24)
        r.line = r:CreateTexture(nil, "BACKGROUND"); r.line:SetColorTexture(C.border[1], C.border[2], C.border[3], 0.6)
        r.line:SetPoint("TOPLEFT"); r.line:SetPoint("TOPRIGHT"); r.line:SetHeight(1)
        r.a = UI:Text(r, 11, C.muted); r.a:SetPoint("LEFT", 2, 0)
        r.b = UI:Text(r, 11); r.b:SetPoint("LEFT", 170, 0)
        r.c = UI:Text(r, 11); r.c:SetPoint("RIGHT", -60, 0); r.c:SetJustifyH("RIGHT")
        r.d = UI:Text(r, 11, C.muted); r.d:SetPoint("RIGHT", -2, 0); r.d:SetJustifyH("RIGHT")
        r:Hide()
        scv.hrows[i] = r
    end
    scv.note = UI:Text(scv.scan, 10, C.dim); scv.note:SetPoint("BOTTOMLEFT", 12, 12); scv.note:SetPoint("BOTTOMRIGHT", -12, 12)
    scv.note:SetJustifyH("LEFT")
    if scv.note.SetWordWrap then scv.note:SetWordWrap(true) end
    scv.note:SetText(T("Le scan relève le prix de tout l'HV (un scan complet toutes les 15 minutes au plus). Ces prix servent partout : infobulles, valeur du compte, Rangement, prix proposé à la vente, alertes de prix."))

    -- cartes de réglages : une ligne = libellé, description, commande à droite
    local function settingsCard(title, rowsN, anchor)
        local c = panelBox(scv, title)
        if anchor then c:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10); c:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -10)
        else c:SetPoint("TOPLEFT", scv.scan, "TOPRIGHT", 10, 0); c:SetPoint("TOPRIGHT") end
        c:SetHeight(34 + rowsN * 44)
        c.y = -32
        function c:Row(label, desc, ctl, w)
            local l = UI:Text(self, 12); l:SetPoint("TOPLEFT", 12, self.y - 4); l:SetText(T(label))
            local d
            if desc then
                d = UI:Text(self, 10, C.muted); d:SetPoint("TOPLEFT", l, "BOTTOMLEFT", 0, -3); d:SetText(T(desc))
                d:SetPoint("RIGHT", self, "RIGHT", -((w or 60) + 20), 0); d:SetJustifyH("LEFT")
            end
            ctl:SetParent(self); ctl:ClearAllPoints(); ctl:SetPoint("TOPRIGHT", -12, self.y - 2)
            self.y = self.y - 44
            return ctl, d
        end
        return c
    end
    scv.toggles = {}
    local function tog(parent, get, set)
        local t = UI:Toggle(parent, get, function(v) set(v); WK:NotifyChanged() end)
        table.insert(scv.toggles, t)
        return t
    end
    -- Vente
    local cv1 = settingsCard("Vente", 4)
    cv1:Row("Mettre en vente au clavier", "Espace, S, Haut / Bas sur la page Vendre",
        tog(cv1, function() return cfg().postKeys end, function(v) cfg().postKeys = v end))
    cv1:Row("Demander avant une vente à perte", "Sous le marchand ou un zéro oublié",
        tog(cv1, function() return cfg().askBad ~= false end, function(v) cfg().askBad = v end))
    scv.under = UI:NumberInput(cv1, 60, 24, "1")
    scv.under.onChange = function(txt, user) if user then A.Config().undercut = math.max(1, tonumber(txt) or 1) end end
    cv1:Row("Marge sous le plus bas", "En pièces de cuivre", scv.under, 60)
    local DUR2 = { { 1, _G.AUCTION_DURATION_ONE or "2 h" }, { 2, _G.AUCTION_DURATION_TWO or "8 h" }, { 3, _G.AUCTION_DURATION_THREE or "24 h" } }
    scv.dur = UI:Segmented(cv1, DUR2, function(v) cfg().postDur = v end, 24)
    cv1:Row("Durée par défaut", nil, scv.dur, 160)
    -- Fenêtre
    local cv2 = settingsCard("Fenêtre", 3, cv1)
    cv2:Row("Fenêtre Warband Keeper", "Remplace celle du jeu chez l'encanteur",
        tog(cv2, function() return S:Config().tabs ~= false end, function(v) S:Config().tabs = v end))
    scv.openOn = UI:Segmented(cv2, { { "last", "Dernière page" }, { "browse", "Parcourir" }, { "sell", "Vendre" } }, function(v) cfg().openOn = v end, 24)
    cv2:Row("Ouvrir sur", nil, scv.openOn, 240)
    cv2:Row("Scan complet à l'ouverture", "Dès que le serveur l'autorise",
        tog(cv2, function() return S:Config().auto end, function(v) S:Config().auto = v end))
    -- Données
    local cv3 = settingsCard("Données", 3, cv2)
    scv.wipe = UI:Button(cv3, "Repartir de zéro", nil, 24, "secondary")
    scv.wipe:SetScript("OnClick", function(b)
        -- deux clics : le premier demande confirmation
        if not b.armed then
            b.armed = true; b:SetLabel(T("Sûr ? Clique encore")); b:SetWidth(b.label:GetStringWidth() + 28)
            C_Timer.After(4, function() b.armed = nil; b:SetLabel(T("Repartir de zéro")); b:SetWidth(b.label:GetStringWidth() + 28) end)
            return
        end
        b.armed = nil
        local d = S:Data(); d.items = {}; d.last, d.lastFull, d.lastCount, d.scans = nil, nil, nil, nil
        b:SetLabel(T("Repartir de zéro")); b:SetWidth(b.label:GetStringWidth() + 28)
        WK:NotifyChanged(); f:Refresh()
    end)
    local _, dataDesc = cv3:Row("Prix relevés", " ", scv.wipe, 150)
    scv.dataDesc = dataDesc
    scv.keep = UI:Segmented(cv3, { { 14, "14 j" }, { 30, "30 j" }, { 90, "90 j" } }, function(v) S:Config().keepDays = v end, 24)
    cv3:Row("Garder l'historique", "Courbes des prix (pages Prix et Parcourir)", scv.keep, 150)
    cv3:Row("Valeur des sacs et du courrier", "Sous les sacs du jeu et au survol d'un courrier",
        tog(cv3, function() return S:Config().bagValue ~= false end, function(v) S:Config().bagValue = v; S:Config().mailValue = v end))

    function scv:Refresh()
        local d = S:Data()
        local sc = S.scan
        local r, g, b = UI:Accent()
        self.bar.fill:SetColor(r, g, b, 1)
        local frac = sc and ((sc.total and sc.total > 0) and math.min(1, (sc.done or 0) / sc.total) or 0.05)
            or (d.last and math.max(0.05, 1 - math.min(1, (time() - d.last) / 86400)) or 0)
        self.bar.fillF:SetWidth(math.max(1, (self.bar:GetWidth() or 240) * frac))
        local cd = S:FullCooldown()
        self.info:SetText(sc and T("scan en cours…") or ((d.lastFull and string.format(T("dernier scan complet %s"), UI:Ago(d.lastFull)) or T("pas encore de scan complet"))
            .. "  ·  " .. (cd > 0 and string.format(T("prochain possible dans %d min"), math.ceil(cd / 60)) or T("possible maintenant"))))
        self.go:SetEnabled(sc == nil)
        -- chiffres
        local today = math.floor(time() / 86400)
        local nToday = 0
        for _, e in pairs(d.items) do if S:HasDay(e, today) then nToday = nToday + 1 end end
        local nAlert = 0
        for id, max in pairs(A.Config().alerts or {}) do
            local p = S:Price(id)
            if p and p <= max then nAlert = nAlert + 1 end
        end
        local last = d.scans and d.scans[1]
        local vals = {
            { T("Objets connus"), tostring(S:Count()) },
            { T("Relevés aujourd'hui"), tostring(nToday) },
            { T("Alertes déclenchées"), tostring(nAlert) },
            { T("Durée du scan"), (last and last.dur) and (last.dur >= 60 and string.format("%d min", math.floor(last.dur / 60)) or (last.dur .. " s")) or "-" },
        }
        for i, t in ipairs(self.tiles) do
            t.l:SetText(UI:Upper(vals[i][1])); t.v:SetText(vals[i][2])
            t.v:SetTextColor(unpack((i == 3 and nAlert > 0) and C.positive or C.text))
        end
        for i, row in ipairs(self.hrows) do
            local e = d.scans and d.scans[i]
            if e then
                row.a:SetText(date("%d/%m %H:%M", e.at))
                row.b:SetText(e.full and T("complet") or T("pages"))
                row.c:SetText(string.format(T("%d objets"), e.n or 0))
                row.d:SetText(e.dur and (e.dur >= 60 and string.format("%d min", math.floor(e.dur / 60)) or (e.dur .. " s")) or "")
                row:Show()
            else row:Hide() end
        end
        self.histHead:SetText(d.scans and T("Derniers scans") or T("Derniers scans : aucun pour l'instant"))
        -- réglages
        for _, t in ipairs(self.toggles) do t:Refresh() end
        if not self.under.edit:HasFocus() then self.under:SetText(tostring((A.Config and A.Config().undercut) or 1)) end
        self.dur:Select(cfg().postDur)
        self.openOn:Select(cfg().openOn or "last")
        self.keep:Select(S:Config().keepDays or 30)
        if self.dataDesc and self.dataDesc.SetText then
            local realm = GetRealmName and GetRealmName() or ""
            local fac = UnitFactionGroup and UnitFactionGroup("player") or ""
            self.dataDesc:SetText(string.format(T("%d objets · %s · %s"), S:Count(), realm, fac))
        end
    end

    function f:Refresh()
        if not self:IsShown() then return end
        -- « Reposter » : l'objet annulé est revenu dans les sacs : la page Vendre s'ouvre dessus, au prix voulu
        local rp = self.repost
        if rp and GetTime() - rp.at < 900 then
            local okB, _, by = pcall(bagItems)
            if okB and by and by[rp.id] and by[rp.id].count > (rp.have or 0) then
                self.repost = nil
                self:Open("sell")
                local sv2 = self.views.sell
                sv2:Select(rp.id)
                if rp.price then
                    sv2.userPrice = true
                    sv2.price:SetText((WK:FormatMoney(rp.price):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")))
                    sv2:Update()
                end
                return
            end
        elseif rp then self.repost = nil end
        local d = S:Data()
        local sc = S.scan
        local r, g, b = UI:Accent()
        self.scanBar.fill:SetColor(r, g, b, 1)
        local frac = 1
        if sc then
            frac = (sc.total and sc.total > 0) and math.min(1, (sc.done or 0) / sc.total) or 0.05
            self.scanInfo:SetText(T("scan en cours…"))
        else
            frac = d.last and math.max(0.05, 1 - math.min(1, (time() - d.last) / 86400)) or 0
            local n = S:Count()
            self.scanInfo:SetText((d.last and string.format(T("scanné %s"), UI:Ago(d.last)) or T("jamais scanné"))
                .. (n > 0 and ("  ·  " .. string.format(T("%s objets"), BreakUpLargeNumbers and BreakUpLargeNumbers(n) or tostring(n))) or ""))
        end
        self.scanBar.fillF:SetWidth(math.max(1, 110 * frac))
        self.scanBtn:SetEnabled(sc == nil)
        -- type de serveur seulement (PvE, PvP, JdR…), le nom complet au survol
        local realm = GetRealmName and GetRealmName() or ""
        local kind = realm:match("[Rr][Pp]%-?[Pp][Vv][Pp]%s*$") or realm:match("[Pp][Vv][PpEe]%s*$") or realm:match("%f[%a][Rr][Pp]%s*$")
        self.headSub:SetText(kind and kind:upper():gsub("%s", "") or realm)
        self.gold:SetText(UI:GoldText(GetMoney and GetMoney() or 0))
        -- pastilles : objets à vendre, enchères sous-cotées (rouge), objets qui manquent dans la liste choisie
        local okB, list = pcall(bagItems)
        self.nav.sell:SetCount(okB and #list or 0)
        self.nav.cancel:SetCount(A:UnderCount(), C.negative)
        self.nav.buy:SetCount(self.buyCount or 0)
        for _, nb in pairs(self.nav) do nb:Paint() end
        self:RefreshSide()
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
-- Notre fenêtre à la place de celle du jeu (réglage AHScan:Config().tabs ; sinon le panneau d'avant)
---------------------------------------------------------------------------
local function attach()
    if not (cfg().tabs and WK:FeatureOn("ah")) then return end
    local host = AuctionHouseFrame
    if not host or not host:IsShown() then return end
    if not view then view = build(host) end
    -- pas plus grande que l'écran
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    view:SetSize(math.min(WIN_W, sw - 20), math.min(WIN_H, sh - 40))
    view.gameMode = false
    -- page d'ouverture : la dernière, ou celle choisie (Scan et réglages > Fenêtre)
    local o = cfg().openOn
    local key = (o == "browse" or o == "sell") and o or (cfg().ahTab and view.views[cfg().ahTab] and cfg().ahTab) or "browse"
    view:Open(key)
end
WK:On("AUCTION_HOUSE_SHOW", function() C_Timer.After(0.15, attach) end)
WK:On("AUCTION_HOUSE_CLOSED", function()
    if view then view.gameMode = false; view:Close() end
    -- les prix vus ne valent que pour cette visite : à la prochaine, le prix proposé et le garde-fou
    -- attendent une recherche fraîche
    wipe(queue); wipe(results); pending = nil
end)
WK:On("PLAYER_MONEY", function() if view and view:IsShown() then view.gold:SetText(UI:GoldText(GetMoney())) end end)
WK:On("BAG_UPDATE_DELAYED", function() if view and view:IsShown() and view.tab ~= "scan" then view:Refresh() end end)
WK:On("OWNED_AUCTIONS_UPDATED", function() C_Timer.After(0.1, function() if view and view:IsShown() then view:Refresh() end end) end)
local prevProgress = S.OnProgress
-- pendant un scan, la progression arrive à chaque image : la page n'est redessinée qu'une fois par demi-seconde
local progAt = 0
S.OnProgress = function(...)
    if prevProgress then prevProgress(...) end
    if not (view and view:IsShown()) then return end
    local t = GetTime()
    if S.scan and t - progAt < 0.5 then return end
    progAt = t
    view:Refresh()
end
local prevChange = A.OnChange
A.OnChange = function(...)
    if prevChange then prevChange(...) end
    if view and view:IsShown() then view:Refresh() end
end
-- recherche d'un objet (listes d'achat, « Chercher ») : dans Parcourir quand notre fenêtre est ouverte
function UI:AHWindowSearch(_, name)
    if not (view and view:IsShown() and name) then return false end
    view:Open("browse")
    local bw = view.views.browse
    bw.cat = nil
    bw.search:SetText(name)
    bw:Run()
    return true
end
function UI:AuctionTabs() return view end

-- Objets vus chez les marchands (prix, nom du PNJ) : « au marchand » dans la page À acheter
WK:On("MERCHANT_SHOW", function()
    C_Timer.After(0.3, function()
        local g = WK.DB.global
        g.vendorSeen = g.vendorSeen or {}
        local n = GetMerchantNumItems and GetMerchantNumItems() or 0
        local npc = UnitName and UnitName("npc")
        for i = 1, n do
            local link = GetMerchantItemLink and GetMerchantItemLink(i)
            local id = link and WK:ParseItemID(link)
            local _, _, price, stack = WK.MerchantItemInfo(i)
            if id and price and price > 0 then
                g.vendorSeen[id] = { p = math.floor(price / math.max(1, stack or 1)), npc = npc, at = time() }
            end
        end
    end)
end)
