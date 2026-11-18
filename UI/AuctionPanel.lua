local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Panneau collé à droite de la fenêtre de l'hôtel des ventes (logique : Modules/AHScan.lua), deux onglets :
--   « Scan »   : nombre de prix connus, dernier scan, prochain scan complet, bouton Scanner l'HV ;
--   « Listes » : listes d'achat créées depuis les métiers ; par objet, ce qu'on a sur le compte, ce qu'il
--                faut, le prix relevé, et « Chercher » qui lance la recherche dans la fenêtre de l'HV du jeu
--                (l'achat se fait avec ses boutons).
--   « Ventes » : tes enchères en cours, vérification du plus bas prix (sous-cotée ou non), Annuler ;
--                état de la vente rapide (Modules/AHSell.lua).
-- L'onglet Scan montre aussi les alertes de prix déclenchées par le dernier scan.
local S = WK.modules.AHScan
local A = WK.modules.AHSell
local panel
local W, H_SCAN, H_LIST, ROW_H = 300, 182, 450, 38
local ALERT_ROWS = 4
local SELL_H = 42

local function ago(t)
    if not t then return T("jamais") end
    local s = time() - t
    if s < 3600 then return string.format(T("il y a %d min"), math.max(1, math.floor(s / 60))) end
    if s < 86400 then return string.format(T("il y a %d h"), math.floor(s / 3600)) end
    return string.format(T("il y a %d j"), math.floor(s / 86400))
end
local function spaced(n)
    local s = tostring(n):reverse():gsub("(%d%d%d)", "%1 "):reverse()
    return (s:gsub("^ ", ""))
end
local function itemIcon(id)
    local f = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
    return f and f(id) or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function build()
    local f = CreateFrame("Frame", "WarbandKeeperAHPanel", UIParent)
    f:SetSize(W, H_SCAN)
    f:EnableMouse(true)
    UI:Panel(f, 12, C.surface, C.border)
    f.logo = UI:Icon(f, "logo", 16, nil, "ARTWORK")
    f.logo:SetPoint("TOPLEFT", 14, -12)
    f.title = UI:Text(f, 12)
    f.title:SetPoint("LEFT", f.logo, "RIGHT", 6, 0)
    f.title:SetText("Warband Keeper")
    f.close = UI:IconButton(f, "close", 16)
    f.close:SetPoint("TOPRIGHT", -10, -10)
    -- fermé pour cette visite seulement : il revient à la prochaine ouverture de l'HV
    f.close:SetScript("OnClick", function() f:Hide() end)
    f.tab = S:Config().panelTab or "scan"
    f.seg = UI:Segmented(f, { { "scan", "Scan" }, { "lists", "Listes d'achat" }, { "sell", "Ventes" } }, function(v)
        f.tab = v; S:Config().panelTab = v; f:Layout(); f:Refresh()
    end, 24)
    f.seg:SetPoint("TOPLEFT", 14, -36)
    f.seg:Select(f.tab)

    -- Onglet Scan -------------------------------------------------------------------
    local sb = CreateFrame("Frame", nil, f)
    sb:SetPoint("TOPLEFT", 0, -66)
    sb:SetPoint("BOTTOMRIGHT")
    f.scanBox = sb
    f.count = UI:Text(sb, 18)
    f.count:SetPoint("TOPLEFT", 14, -6)
    f.countL = UI:Text(sb, 11, C.muted)
    f.countL:SetPoint("BOTTOMLEFT", f.count, "BOTTOMRIGHT", 6, 2)
    f.when = UI:Text(sb, 11, C.muted)
    f.when:SetPoint("TOPLEFT", 14, -32)
    f.when:SetPoint("RIGHT", -14, 0)
    f.when:SetJustifyH("LEFT")
    f.next = UI:Text(sb, 11, C.muted)
    f.next:SetPoint("TOPLEFT", 14, -48)
    f.next:SetPoint("RIGHT", -14, 0)
    f.next:SetJustifyH("LEFT")
    f.bar = UI:Progress(sb, 4)
    f.bar:SetPoint("TOPLEFT", 14, -54)
    f.bar:SetPoint("TOPRIGHT", -14, -54)
    f.btn = UI:Button(sb, "Scanner l'HV", W - 28, 28, "primary")
    f.btn:SetPoint("BOTTOM", 0, 12)
    f.btn:SetScript("OnClick", function()
        if S.scan then S:Stop() else S:Start() end
    end)
    f.btn:HookScript("OnEnter", function(b)
        WK.UI:TooltipOwner(b, "ANCHOR_RIGHT")
        local _, all = S:CanQuery()
        GameTooltip:SetText(T("Scan de l'hôtel des ventes"), 1, 1, 1)
        GameTooltip:AddLine(all and T("Scan complet possible maintenant : toute l'HV en une fois.")
            or T("Le serveur n'accepte qu'un scan complet toutes les 15 minutes environ."), 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(T("Les prix servent aux infobulles, à la valeur des stocks, aux métiers et aux listes d'achat."), 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    f.btn:HookScript("OnLeave", function() GameTooltip:Hide() end)
    -- alertes de prix déclenchées (sous les chiffres du scan)
    f.alertH = UI:Text(sb, 10, C.dim)
    f.alertH:SetPoint("TOPLEFT", 14, -72)
    f.alertH:SetText(T("ALERTES DE PRIX"))
    f.alertRows = {}
    for i = 1, ALERT_ROWS do
        local r = CreateFrame("Frame", nil, sb)
        r:SetHeight(26)
        r:SetPoint("TOPLEFT", 8, -86 - (i - 1) * 28)
        r:SetPoint("RIGHT", -8, 0)
        r.icon = UI:RoundIcon(r, 20)
        r.icon:SetPoint("LEFT", 6, 0)
        r.name = UI:Text(r, 11)
        r.name:SetPoint("LEFT", 32, 0)
        r.name:SetPoint("RIGHT", -74, 0)
        r.name:SetJustifyH("LEFT")
        r.go = UI:Button(r, "Chercher", 66, 22, "secondary")
        r.go:SetPoint("RIGHT", -4, 0)
        f.alertRows[i] = r
    end

    -- Onglet Listes d'achat ----------------------------------------------------------
    local lb = CreateFrame("Frame", nil, f)
    lb:SetPoint("TOPLEFT", 0, -66)
    lb:SetPoint("BOTTOMRIGHT")
    f.listBox = lb
    f.listDd = UI:Dropdown(lb, W - 28 - 64, 28, {}, function(v) S:CancelBuy(); S:Config().curList = v; f:Refresh() end)
    f.listDd:SetPoint("TOPLEFT", 14, -4)
    f.del = UI:IconButton(lb, "trash", 26, "Supprimer cette liste")
    f.del:SetPoint("TOPRIGHT", -12, -5)
    f.del:SetScript("OnClick", function(b)
        local name = S:Config().curList
        if not name then return end
        if not b.armed then
            b.armed = true
            WK:Print(string.format(T("Clique encore sur la corbeille pour supprimer la liste « %s »."), name))
            C_Timer.After(3, function() b.armed = nil end)
            return
        end
        b.armed = nil
        S:DeleteList(name)
        f:Refresh()
    end)
    f.prune = UI:IconButton(lb, "minus", 26, "Retirer de la liste ce qui est déjà sur le compte")
    f.prune:SetPoint("RIGHT", f.del, "LEFT", -4, 0)
    f.prune:SetScript("OnClick", function()
        local n = S:PruneList(S:Config().curList)
        WK:Print(string.format(T("%d objet(s) retiré(s) de la liste : déjà sur le compte."), n))
        f:Refresh()
    end)
    f.empty = UI:Text(lb, 11, C.muted)
    f.empty:SetPoint("TOPLEFT", 16, -10)
    f.empty:SetPoint("RIGHT", -16, 0)
    f.empty:SetJustifyH("LEFT")
    f.empty:SetText(T("Pas encore de liste. Dans Métiers, « Liste d'achat » ou « Créer la liste d'achat » en prépare une avec les composants qui manquent."))
    f.lscroll = UI:Scroll(lb)
    f.lscroll:SetPoint("TOPLEFT", 6, -40)
    f.lscroll:SetPoint("BOTTOMRIGHT", -6, 82)
    f.rows = UI:Pool(function()
        local r = CreateFrame("Frame", nil, f.lscroll.child)
        r:SetHeight(ROW_H)
        r.line = r:CreateTexture(nil, "BACKGROUND")
        r.line:SetPoint("BOTTOMLEFT", 8, 0); r.line:SetPoint("BOTTOMRIGHT", -8, 0); r.line:SetHeight(1)
        r.icon = UI:RoundIcon(r, 24)
        r.icon:SetPoint("LEFT", 8, 0)
        r.name = UI:Text(r, 12)
        r.name:SetPoint("TOPLEFT", 40, -4)
        r.name:SetPoint("RIGHT", -78, 0)
        r.name:SetJustifyH("LEFT")
        r.sub = UI:Text(r, 10, C.muted)
        r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
        r.sub:SetPoint("RIGHT", -78, 0)
        r.sub:SetJustifyH("LEFT")
        r.go = UI:Button(r, "Chercher", 66, 24, "secondary")
        r.go:SetPoint("RIGHT", -6, 0)
        r:EnableMouse(true)
        r:SetScript("OnEnter", function(s)
            if not s.id then return end
            WK.UI:TooltipOwner(s, "ANCHOR_LEFT")
            if GameTooltip.SetItemByID then GameTooltip:SetItemByID(s.id) else GameTooltip:SetText(WK.GetItemInfo(s.id) or "?") end
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return r
    end)
    -- achat de la liste, pas à pas (un clic pour le prix, un clic pour confirmer)
    f.buyBtn = UI:Button(lb, "Acheter la liste", W - 28 - 32, 30, "primary")
    f.buyBtn:SetPoint("BOTTOMLEFT", 14, 12)
    f.buyBtn:SetScript("OnClick", function() S:BuyStep() end)
    f.buyBtn:HookScript("OnEnter", function(b)
        WK.UI:TooltipOwner(b, "ANCHOR_RIGHT")
        GameTooltip:SetText(T("Acheter la liste au prix le plus bas"), 1, 1, 1)
        GameTooltip:AddLine(T("Le jeu exige un clic du joueur pour chaque achat : impossible de tout acheter d'un seul clic. Le 1er clic demande le prix ; ensuite, un seul clic par objet : après chaque achat, le prix du suivant est demandé tout seul."), 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(T("Les objets achetés sont retirés de la liste."), 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    f.buyBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)
    f.cancel = UI:IconButton(lb, "close", 26, "Annuler cet achat")
    f.cancel:SetPoint("LEFT", f.buyBtn, "RIGHT", 4, 0)
    f.cancel:SetScript("OnClick", function() S:CancelBuy() end)
    f.total = UI:Text(lb, 12)
    f.total:SetPoint("BOTTOMLEFT", 16, 54)
    f.total:SetPoint("RIGHT", -16, 0)
    f.total:SetJustifyH("LEFT")

    -- Onglet Ventes ---------------------------------------------------------------
    local vb = CreateFrame("Frame", nil, f)
    vb:SetPoint("TOPLEFT", 0, -66)
    vb:SetPoint("BOTTOMRIGHT")
    f.sellBox = vb
    f.sellSum = UI:Text(vb, 12)
    f.sellSum:SetPoint("TOPLEFT", 14, -6)
    f.sellSum:SetPoint("RIGHT", -14, 0)
    f.sellSum:SetJustifyH("LEFT")
    f.quick = UI:Text(vb, 10, C.muted)
    f.quick:SetPoint("TOPLEFT", 14, -24)
    f.quick:SetPoint("RIGHT", -14, 0)
    f.quick:SetJustifyH("LEFT")
    f.sscroll = UI:Scroll(vb)
    f.sscroll:SetPoint("TOPLEFT", 6, -44)
    f.sscroll:SetPoint("BOTTOMRIGHT", -6, 52)
    f.sempty = UI:Text(vb, 11, C.muted)
    f.sempty:SetPoint("TOPLEFT", 16, -50)
    f.sempty:SetPoint("RIGHT", -16, 0)
    f.sempty:SetJustifyH("LEFT")
    f.srows = UI:Pool(function()
        local r = CreateFrame("Frame", nil, f.sscroll.child)
        r:SetHeight(SELL_H)
        r.line = r:CreateTexture(nil, "BACKGROUND")
        r.line:SetPoint("BOTTOMLEFT", 8, 0); r.line:SetPoint("BOTTOMRIGHT", -8, 0); r.line:SetHeight(1)
        r.icon = UI:RoundIcon(r, 24)
        r.icon:SetPoint("LEFT", 8, 0)
        r.name = UI:Text(r, 12)
        r.name:SetPoint("TOPLEFT", 40, -4)
        r.name:SetPoint("RIGHT", -70, 0)
        r.name:SetJustifyH("LEFT")
        r.sub = UI:Text(r, 10, C.muted)
        r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -4)
        r.sub:SetPoint("RIGHT", -8, 0)
        r.sub:SetJustifyH("LEFT")
        r.cancel = UI:Button(r, "Annuler", 60, 20, "secondary")
        r.cancel:SetPoint("TOPRIGHT", -6, -3)
        r.cancel:HookScript("OnEnter", function(b)
            WK.UI:TooltipOwner(b, "ANCHOR_RIGHT")
            GameTooltip:SetText(T("Annuler cette enchère"), 1, 1, 1)
            GameTooltip:AddLine(T("L'objet revient par courrier ; le dépôt n'est pas rendu. Tu pourras le remettre en vente moins cher."), 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        r.cancel:HookScript("OnLeave", function() GameTooltip:Hide() end)
        r:EnableMouse(true)
        r:SetScript("OnEnter", function(s)
            if not s.id then return end
            WK.UI:TooltipOwner(s, "ANCHOR_LEFT")
            if GameTooltip.SetItemByID then GameTooltip:SetItemByID(s.id) else GameTooltip:SetText(WK.GetItemInfo(s.id) or "?") end
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return r
    end)
    f.checkBtn = UI:Button(vb, "Vérifier les prix", W - 28, 30, "primary")
    f.checkBtn:SetPoint("BOTTOMLEFT", 14, 12)
    f.checkBtn:SetScript("OnClick", function()
        if A.checking then return end
        if #A.owned == 0 then A:Query() else A:Check() end
    end)
    f.checkBtn:HookScript("OnEnter", function(b)
        WK.UI:TooltipOwner(b, "ANCHOR_RIGHT")
        GameTooltip:SetText(T("Vérifier les prix de mes enchères"), 1, 1, 1)
        GameTooltip:AddLine(T("Cherche le plus bas prix actuel de chaque objet que tu vends (un objet toutes les 1,2 s) : « sous-cotée » quand un autre vendeur est moins cher que toi."), 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    f.checkBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

    f:SetScript("OnUpdate", function(s, el)
        s.acc = (s.acc or 0) + el
        if s.acc > 1 then s.acc = 0; if s.tab == "scan" or S.scan or (s.tab == "sell" and A.checking) then s:Refresh() end end
    end)

    function f:Layout()
        local tab = self.tab
        self.scanBox:SetShown(tab ~= "lists" and tab ~= "sell")
        self.listBox:SetShown(tab == "lists")
        self.sellBox:SetShown(tab == "sell")
        if tab == "lists" or tab == "sell" then
            self:SetHeight(H_LIST)
        else
            local n = math.min(ALERT_ROWS, #(A.triggered or {}))
            self:SetHeight(H_SCAN + (n > 0 and (24 + n * 28) or 0))
        end
    end

    function f:RefreshScan()
        local d = S:Data()
        self.count:SetText(spaced(S:Count()))
        self.countL:SetText(T("objets avec un prix"))
        local sc = S.scan
        if sc then
            local frac = (sc.total and sc.total > 0) and (sc.done or 0) / sc.total or 0
            self.bar:Show(); self.bar:SetValue(frac)
            self.next:Hide()
            if sc.phase == "wait" then self.when:SetText(T("Scan : réponse du serveur..."))
            elseif sc.pages then self.when:SetText(string.format(T("Scan page par page : %s / %s"), spaced(sc.done or 0), spaced(sc.total or 0)))
            else self.when:SetText(string.format(T("Scan complet : %s / %s"), spaced(sc.done or 0), spaced(sc.total or 0))) end
            self.btn:SetLabel(T("Arrêter"))
            self.btn:SetStyle("secondary")
        else
            self.bar:Hide()
            local _, all = S:CanQuery()
            local cd = S:FullCooldown()
            self.when:SetText(T("Dernier scan") .. " " .. ago(d.last))
            self.next:Show()
            if all then
                self.next:SetText(T("Scan complet possible maintenant"))
                self.next:SetTextColor(unpack(C.positive))
            elseif cd > 0 then
                self.next:SetText(string.format(T("Prochain scan complet dans %d min"), math.ceil(cd / 60)))
                self.next:SetTextColor(unpack(C.muted))
            else
                self.next:SetText(T("Scan page par page (plus lent)"))
                self.next:SetTextColor(unpack(C.muted))
            end
            self.btn:SetLabel(T("Scanner l'HV"))
            self.btn:SetStyle((all or cd == 0) and "primary" or "secondary")
        end
        -- alertes de prix déclenchées
        local hits = A.triggered or {}
        self.alertH:SetShown(#hits > 0)
        for i, r in ipairs(self.alertRows) do
            local a = hits[i]
            r:SetShown(a ~= nil)
            if a then
                r.icon:SetTexture(itemIcon(a.id))
                r.name:SetText((WK.GetItemInfo(a.id) or ("#" .. a.id)) .. "  " .. UI:Hex(C.gold) .. UI:ExactMoney(a.price) .. "|r")
                r.go:SetScript("OnClick", function() S:SearchItem(a.id) end)
            end
        end
        local want = H_SCAN + (#hits > 0 and (24 + math.min(ALERT_ROWS, #hits) * 28) or 0)
        if math.abs((self:GetHeight() or 0) - want) > 1 then self:SetHeight(want) end
    end

    function f:RefreshSell()
        local owned = A.owned or {}
        local under = A:UnderCount()
        if not A:Available() then
            self.sellSum:SetText(T("Ce client ne donne pas la liste de tes enchères."))
        else
            self.sellSum:SetText(string.format(T("%d enchère(s) en cours"), #owned) .. (under > 0 and ("  ·  " .. UI:Hex(C.negative) .. string.format(T("%d sous-cotée(s)"), under) .. "|r") or ""))
        end
        local c = A.Config()
        local q = A.lastQuick
        if not c.quickSell then
            self.quick:SetText(T("Vente rapide coupée (QoL > Hôtel des ventes)."))
        elseif q then
            self.quick:SetText(string.format(T("Vente rapide : %s mis à %s (%s - %d pc)"), WK.GetItemInfo(q.id) or "?", UI:ExactMoney(q.price), q.why or "", c.undercut))
        else
            self.quick:SetText(string.format(T("Vente rapide : pose un objet dans la fenêtre de vente, son prix est mis au plus bas - %d pc."), c.undercut))
        end
        self.srows:Reset()
        local LW = self.sscroll:GetWidth() or (W - 12)
        if LW < 100 then LW = W - 12 end
        local y = 0
        for _, o in ipairs(owned) do
            local r = self.srows:Get()
            r.id = o.id
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:SetWidth(LW - 10)
            r.line:SetColorTexture(C.border[1], C.border[2], C.border[3], 0.6)
            r.icon:SetTexture(itemIcon(o.id))
            r.name:SetText((WK.GetItemInfo(o.id) or ("#" .. o.id)) .. (o.qty > 1 and ("  x" .. o.qty) or ""))
            local mine = o.unit and UI:ExactMoney(o.unit) or "?"
            local st
            if o.state == "under" then st = UI:Hex(C.negative) .. T("plus bas") .. " " .. UI:ExactMoney(o.lowest) .. "|r"
            elseif o.state == "ok" then st = UI:Hex(C.positive) .. T("au plus bas") .. "|r"
            elseif o.state == "alone" then st = UI:Hex(C.positive) .. T("seul en vente") .. "|r"
            else st = T("à vérifier") end
            r.sub:SetText(mine .. "  ·  " .. st)
            r.cancel:SetShown(o.state == "under")
            r.cancel:SetStyle(o.state == "under" and "primary" or "secondary")
            r.cancel:SetScript("OnClick", function() A:Cancel(o.auctionID) end)
            y = y + SELL_H
        end
        self.sscroll.child:SetSize(LW - 10, math.max(y, 10))
        if self.sscroll.UpdateBar then self.sscroll:UpdateBar() end
        self.sempty:SetShown(#owned == 0)
        self.sempty:SetText(T("Aucune enchère en cours (ou liste pas encore reçue : « Vérifier les prix » la redemande)."))
        if A.checking then
            local done, total = A:Progress()
            self.checkBtn:SetLabel(string.format(T("Vérification %d / %d..."), done, total))
            self.checkBtn:SetStyle("secondary")
        else
            self.checkBtn:SetLabel(T("Vérifier les prix"))
            self.checkBtn:SetStyle("primary")
        end
    end

    function f:RefreshLists()
        local names = S:Lists()
        local cfg = S:Config()
        if cfg.curList and not S:GetList(cfg.curList) then cfg.curList = nil end
        cfg.curList = cfg.curList or names[1]
        local opts = {}
        for _, n in ipairs(names) do table.insert(opts, { n, n }) end
        self.listDd:SetOptions(opts)
        if cfg.curList then self.listDd:Select(cfg.curList) end
        self.listDd:SetShown(#names > 0)
        self.del:SetShown(#names > 0)
        self.prune:SetShown(#names > 0)
        self.empty:SetShown(#names == 0)
        self.rows:Reset()
        local list = S:GetList(cfg.curList)
        local Inv = WK.modules.Inventory
        local y, cost, unknown = 0, 0, 0
        local LW = self.lscroll:GetWidth() or (W - 12)
        if LW < 100 then LW = W - 12 end
        for _, it in ipairs(list and list.items or {}) do
            local id, want = it[1], it[2]
            local have = S:Have(id)
            local r = self.rows:Get()
            r.id = id
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:SetWidth(LW - 10)
            r.line:SetColorTexture(C.border[1], C.border[2], C.border[3], 0.6)
            r.icon:SetTexture(itemIcon(id))
            r.name:SetText(WK.GetItemInfo(id) or ("#" .. id))
            local done = have >= want
            r.name:SetTextColor(unpack(done and C.dim or C.text))
            local price = S:Price(id)
            local missing = math.max(0, want - have)
            if price then cost = cost + price * missing elseif missing > 0 then unknown = unknown + 1 end
            local hv = done and (UI:Hex(C.positive) .. T("tout est là") .. "|r") or (price and (T("HV") .. " " .. UI:GoldText(price)) or T("pas vu à l'HV"))
            r.sub:SetText(string.format("%d / %d", math.min(have, want), want) .. "  ·  " .. hv)
            r.go:SetShown(not done)
            r.go:SetScript("OnClick", function() S:SearchItem(id) end)
            y = y + SELL_H
        end
        self.lscroll.child:SetSize(LW - 10, math.max(y, 10))
        if self.lscroll.UpdateBar then self.lscroll:UpdateBar() end
        self.total:SetShown(list ~= nil)
        self:PaintBuy(list)
        self.total:SetText(T("Reste à acheter :") .. " " .. UI:GoldText(cost) .. (unknown > 0 and ("  " .. UI:Hex(C.muted) .. string.format(T("(+%d sans prix)"), unknown) .. "|r") or ""))
    end

    -- Bouton d'achat : ce que fera le prochain clic
    function f:PaintBuy(list)
        local b = S.buy
        local canBuy = list ~= nil and S:CanBuy()
        self.buyBtn:SetShown(canBuy)
        self.cancel:SetShown(canBuy and b ~= nil and b.phase == "confirm")
        if not canBuy then return end
        local function nm(id) return WK.GetItemInfo(id) or ("#" .. id) end
        if b and b.phase == "quote" then
            self.buyBtn:SetLabel(T("Prix demandé au serveur..."))
            self.buyBtn:SetStyle("secondary")
        elseif b and b.phase == "confirm" then
            -- garde-fou : prix bien au-dessus du prix relevé par le scan
            local ref = S:Price(b.id)
            local high = ref and b.unit and b.unit > ref * 2.5
            self.buyBtn:SetLabel(string.format(T("Confirmer %d %s : %s"), b.qty, nm(b.id), UI:PlainMoney(b.total or 0)) .. (high and ("  " .. UI:Hex(C.negative) .. T("(cher !)") .. "|r") or ""))
            self.buyBtn:SetStyle("primary")
        elseif b and b.phase == "wait" then
            self.buyBtn:SetLabel(T("Achat en cours..."))
            self.buyBtn:SetStyle("secondary")
        else
            local id, qty = S:NextToBuy(S:Config().curList)
            if id then
                self.buyBtn:SetLabel(string.format(T("Acheter %d %s"), qty, nm(id)))
                self.buyBtn:SetStyle("primary")
            else
                self.buyBtn:SetLabel(T("Il ne manque plus rien"))
                self.buyBtn:SetStyle("secondary")
            end
        end
    end

    function f:Refresh()
        local r, g, b = UI:Accent()
        self.logo:SetVertexColor(r, g, b)
        if self.tab == "lists" then self:RefreshLists() elseif self.tab == "sell" then self:RefreshSell() else self:RefreshScan() end
    end
    f:Layout()
    return f
end

local function host() return AuctionHouseFrame or AuctionFrame end

-- Onglet « Scan » des onglets de l'HV (UI/AuctionTabs.lua) : le panneau y est posé, à gauche
function UI:AHPanelEmbed(parent)
    panel = panel or build()
    panel:SetParent(parent)
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    panel:SetFrameLevel(parent:GetFrameLevel() + 2)
    panel.embedded = true
    panel:Show()
    panel:Layout()
    panel:Refresh()
end
local function show()
    if not S:Config().panel or not WK:FeatureOn("ah") then return end
    -- onglets de l'HV actifs (UI/AuctionTabs.lua) : le panneau vit dans l'onglet Scan, plus sur le côté
    if S:Config().tabs ~= false then return end
    local h = host()
    if not h then return end
    panel = panel or build()
    panel:SetParent(UIParent)
    panel.embedded = nil
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", h, "TOPRIGHT", 6, -12)
    panel:SetFrameStrata(h:GetFrameStrata() or "MEDIUM")
    panel:Show()
    panel:Layout()
    panel:Refresh()
end

S.OnProgress = function() if panel and panel:IsShown() then panel:Refresh() end end
A.OnChange = function() if panel and panel:IsShown() then panel:Layout(); panel:Refresh() end end
WK:On("AUCTION_HOUSE_SHOW", function() C_Timer.After(0.1, show) end)
WK:On("AUCTION_HOUSE_CLOSED", function() if panel then panel:Hide() end end)
-- objets achetés : les compteurs de la liste se mettent à jour
WK:On("BAG_UPDATE_DELAYED", function() if panel and panel:IsShown() and panel.tab == "lists" then panel:Refresh() end end)
-- nom d'objet reçu du serveur après coup : la liste se repeint (une fois par seconde au plus)
WK:On("GET_ITEM_INFO_RECEIVED", function()
    if not (panel and panel:IsShown() and panel.tab == "lists") or panel.pendingInfo then return end
    panel.pendingInfo = true
    C_Timer.After(1, function() panel.pendingInfo = nil; if panel:IsShown() then panel:Refresh() end end)
end)
