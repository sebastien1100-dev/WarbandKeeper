local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Notre fenêtre de courrier, posée sur celle du jeu (rendue invisible, jamais cachée : ses évènements et
-- ses fonctions restent actifs), comme notre hôtel des ventes. Barre latérale : Reçus, Envoyer, Rangement,
-- Règles d'envoi, Historique, puis les destinataires récents. Réglage WK.DB.global.mail.window (défaut vrai) ;
-- « Fenêtre du jeu » revient à celle du jeu pour cette visite (bouton « Warband Keeper » pour revenir).
--   mail.tab = dernière page, mail.recent = { noms } (8 derniers destinataires de notre fenêtre)
local WIN_W, WIN_H, SIDE_W, HEAD_H = 900, 580, 190, 46
local ROW_H = 46
local MAX_SEND = ATTACHMENTS_MAX_SEND or 12
local MAX_RECEIVE = ATTACHMENTS_MAX_RECEIVE or 16
local view

local function Ml() return WK.modules.Mail end
local function cfg()
    local m = WK.DB.global.mail
    if m.window == nil then m.window = true end
    m.recent = m.recent or {}
    return m
end
local function inCombat() return InCombatLockdown and InCombatLockdown() or false end
local function freeSlots()
    local n = 0
    for _, bag in ipairs(WK.modules.Inventory:BagList()) do n = n + (WK.Container.NumFree(bag) or 0) end
    return n
end
local function gameTab(i)
    if MailFrameTab_OnClick then pcall(MailFrameTab_OnClick, nil, i) end
end
local function myName()
    local c = WK.DB:Me()
    return WK:CharName(c, WK:CharKey())
end

local NAV = {
    { "inbox", "Reçus", "mail" }, { "send", "Envoyer", "send" }, { "stash", "Rangement", "bag" },
    { "rules", "Règles d'envoi", "filter" }, { "history", "Historique", "clock" },
}

---------------------------------------------------------------------------
-- Lecture de la boîte de réception : { i, sender, subject, money, cod, days, items = { {id, n, icon, name} }, ah }
---------------------------------------------------------------------------
local function inbox()
    local out = {}
    if not GetInboxNumItems then return out end
    for i = 1, GetInboxNumItems() or 0 do
        local _, _, sender, subject, money, cod, days, hasItem, wasRead = GetInboxHeaderInfo(i)
        local e = { i = i, sender = sender or "?", subject = subject or "", money = money or 0, cod = cod or 0,
            days = days or 30, read = wasRead, items = {}, ah = Ml().IsAHLetter(i) }
        if hasItem then
            for a = 1, MAX_RECEIVE do
                local name, itemID, tex, count = GetInboxItem(i, a)
                if not itemID and name and GetInboxItemLink then itemID = WK:ParseItemID(GetInboxItemLink(i, a)) end
                if name or itemID then table.insert(e.items, { id = itemID, n = count or 1, icon = tex, name = name }) end
            end
        end
        table.insert(out, e)
    end
    return out
end

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------
local function build(host)
    local f = CreateFrame("Frame", "WarbandKeeperMail", UIParent)
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
    -- la fenêtre du jeu se ferme (on s'éloigne de la boîte, Échap, fin d'interaction) : la nôtre aussi.
    -- Sur ce client, MAIL_CLOSED n'arrive pas toujours : on suit aussi la fenêtre du jeu elle-même.
    host:HookScript("OnHide", function()
        f.gameMode = false
        if f:IsShown() then f:Close() end
        if f.back then f.back:Hide() end
    end)
    f:SetScript("OnUpdate", function(s, el)
        s.chk = (s.chk or 0) + el
        if s.chk < 0.5 then return end
        s.chk = 0
        if not host:IsShown() then s.gameMode = false; s:Close() end
    end)
    -- Échap (ou toute autre fermeture) : la fenêtre du jeu redevient visible ; sans « Fenêtre du jeu »
    -- demandée, la boîte aux lettres se ferme aussi
    f:HookScript("OnHide", function()
        host:SetAlpha(f.hostAlpha or 1)
        if not f.gameMode and host:IsShown() then
            if CloseMail then pcall(CloseMail) end
            if host:IsShown() and HideUIPanel then pcall(HideUIPanel, host) end
        end
    end)
    if UISpecialFrames then table.insert(UISpecialFrames, "WarbandKeeperMail") end

    -- barre de titre
    local head = CreateFrame("Frame", nil, f)
    head:SetPoint("TOPLEFT"); head:SetPoint("TOPRIGHT"); head:SetHeight(HEAD_H)
    head.line = head:CreateTexture(nil, "ARTWORK")
    head.line:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
    head.line:SetPoint("BOTTOMLEFT"); head.line:SetPoint("BOTTOMRIGHT"); head.line:SetHeight(1)
    f.logo = UI:Icon(head, "mail", 18); f.logo:SetPoint("LEFT", 14, 0)
    f.head = UI:Text(head, 14); f.head:SetPoint("LEFT", f.logo, "RIGHT", 8, 0)
    f.toTake = UI:Badge(head, "", C.gold); f.toTake:SetPoint("LEFT", f.head, "RIGHT", 10, 0)
    f.close = UI:IconButton(head, "close", 26, "Fermer la boîte aux lettres")
    f.close:SetPoint("RIGHT", -10, 0)
    f.close:SetScript("OnClick", function()
        -- fermer la boîte aux lettres du jeu (et notre fenêtre avec, quoi qu'il arrive)
        if CloseMail then pcall(CloseMail) end
        if host:IsShown() and HideUIPanel then pcall(HideUIPanel, host) end
        f.gameMode = false
        f:Close()
        if f.back then f.back:Hide() end
    end)
    f.game = UI:Button(head, "Fenêtre du jeu", nil, 26, "secondary")
    f.game:SetPoint("RIGHT", f.close, "LEFT", -10, 0)
    f.game.tooltip = "Revenir à la boîte aux lettres du jeu pour le reste de cette visite."
    f.game:SetScript("OnClick", function() f.gameMode = true; f:Close() end)
    f.gold = UI:Text(head, 12, C.gold); f.gold:SetPoint("RIGHT", f.game, "LEFT", -16, 0)

    -- barre latérale
    local side = CreateFrame("Frame", nil, f)
    side:SetPoint("TOPLEFT", 0, -HEAD_H); side:SetPoint("BOTTOMLEFT"); side:SetWidth(SIDE_W)
    side.line = side:CreateTexture(nil, "ARTWORK")
    side.line:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
    side.line:SetPoint("TOPRIGHT"); side.line:SetPoint("BOTTOMRIGHT"); side.line:SetWidth(1)
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
    -- destinataires récents : clic = Envoyer avec le nom déjà mis
    f.recentHead = UI:Text(side, 9, C.dim)
    f.recentHead:SetPoint("TOPLEFT", 16, -22 - #NAV * 32)
    f.recentHead:SetText(UI:Upper(T("Destinataires récents")))
    f.rrows = {}
    for i = 1, 8 do
        local r = CreateFrame("Button", nil, side)
        r:SetHeight(22)
        r:SetPoint("TOPLEFT", 8, -38 - #NAV * 32 - (i - 1) * 23); r:SetPoint("TOPRIGHT", -8, -38 - #NAV * 32 - (i - 1) * 23)
        r.bg = UI:Rounded(r, 6, 0, "BACKGROUND", 1); r.bg:SetColor(1, 1, 1, 0)
        r.icon = UI:Icon(r, "person", 11); r.icon:SetPoint("LEFT", 10, 0)
        r.t = UI:Text(r, 11, C.muted); r.t:SetPoint("LEFT", 28, 0); r.t:SetPoint("RIGHT", -6, 0); r.t:SetJustifyH("LEFT")
        if r.t.SetWordWrap then r.t:SetWordWrap(false) end
        r:SetScript("OnEnter", function(s) local ar, ag, ab = UI:Accent(); s.bg:SetColor(ar, ag, ab, 0.08) end)
        r:SetScript("OnLeave", function(s) s.bg:SetColor(1, 1, 1, 0) end)
        r:SetScript("OnClick", function(s)
            if not s.name then return end
            f:Open("send")
            f.views.send.to:SetText(s.name)
            f.views.send:Refresh()
        end)
        f.rrows[i] = r
    end
    function f:RefreshSide()
        local list = cfg().recent
        local room = math.max(0, math.floor((side:GetHeight() - 48 - #NAV * 32) / 23))
        self.recentHead:SetShown(#list > 0)
        for i, r in ipairs(self.rrows) do
            local n = i <= room and list[i]
            r.name = n or nil
            if n then
                r.t:SetText(n); r.icon:SetVertexColor(UI:Accent())
                -- un de tes persos : couleur de sa classe
                local oc = Ml():Resolve(n)
                if oc and oc.class then r.t:SetTextColor(UI:ClassColor(oc.class)) else r.t:SetTextColor(unpack(C.muted)) end
                r:Show()
            else r:Hide() end
        end
    end

    f.content = CreateFrame("Frame", nil, f)
    f.content:SetPoint("TOPLEFT", SIDE_W + 12, -HEAD_H - 12)
    f.content:SetPoint("BOTTOMRIGHT", -12, 12)

    function f:Open(key)
        if not self.views[key] then key = "inbox" end
        cfg().tab = key
        self.tab = key
        for _, b in pairs(self.nav) do b:Paint() end
        for k, v in pairs(self.views) do v:SetShown(k == key) end
        if not self:IsShown() then
            self.hostAlpha = host:GetAlpha()
            host:SetAlpha(0)
            self:Show()
            if self.back then self.back:Hide() end
        end
        -- l'onglet du jeu suit le nôtre : clic droit sur un objet des sacs = pièce jointe en page Envoyer
        gameTab(key == "send" and 2 or 1)
        self:Refresh()
    end
    function f:Close()
        self:Hide()
        host:SetAlpha(self.hostAlpha or 1)
        if self.gameMode and host:IsShown() then
            if not self.back then
                self.back = UI:Button(host, "Warband Keeper", nil, 24, "primary", "mail")
                self.back:SetPoint("TOPRIGHT", host, "TOPRIGHT", -34, -2)
                self.back:SetFrameLevel(host:GetFrameLevel() + 50)
                self.back:SetScript("OnClick", function() f.gameMode = false; f:Open(cfg().tab or "inbox") end)
            end
            self.back:Show()
        end
    end
    f:SetScript("OnSizeChanged", function() f:RefreshSide() end)

    -----------------------------------------------------------------------
    -- Reçus
    -----------------------------------------------------------------------
    do
        local v = CreateFrame("Frame", nil, f.content)
        v:SetAllPoints()
        f.views.inbox = v
        v.all = UI:Button(v, "Tout prendre", 150, 28, "primary")
        v.all:SetPoint("TOPLEFT")
        v.all.tooltip = "Or et objets de toutes les lettres, sauf contre-remboursement ; s'arrête si les sacs sont pleins."
        v.all:SetScript("OnClick", function() Ml():TakeAll() end)
        v.money = UI:Button(v, "Or seulement", 120, 28, "secondary")
        v.money:SetPoint("LEFT", v.all, "RIGHT", 8, 0)
        v.money:SetScript("OnClick", function() Ml():TakeAll({ money = true }) end)
        v.ah = UI:Button(v, "Ventes HV", 110, 28, "secondary")
        v.ah:SetPoint("LEFT", v.money, "RIGHT", 8, 0)
        v.ah.tooltip = "Seulement les lettres de l'hôtel des ventes (ventes, achats, enchères expirées)."
        v.ah:SetScript("OnClick", function() Ml():TakeAll({ ah = true }) end)
        v.search = UI:Input(v, 220, 28, T("Rechercher…"), "search")
        v.search:SetPoint("TOPRIGHT")
        v.search.onChange = function() v:Refresh() end
        v.scroll = UI:Scroll(v)
        v.scroll:SetPoint("TOPLEFT", 0, -40); v.scroll:SetPoint("BOTTOMRIGHT", 0, 24)
        v.empty = UI:Text(v, 12, C.muted); v.empty:SetPoint("TOP", 0, -90)
        v.empty:SetText(T("Boîte vide."))
        v.foot = UI:Text(v, 11, C.muted); v.foot:SetPoint("BOTTOMLEFT", 2, 2)
        v.rows = UI:Pool(function()
            local r = CreateFrame("Button", nil, v.scroll.child)
            r:SetHeight(ROW_H)
            r.bg = UI:Rounded(r, 8, 0, "BACKGROUND", 1); r.bg:SetColor(unpack(C.surface2))
            r.edge = r:CreateTexture(nil, "ARTWORK"); r.edge:SetWidth(3)
            r.edge:SetPoint("TOPLEFT", 0, -8); r.edge:SetPoint("BOTTOMLEFT", 0, 8)
            r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(30, 30); r.icon:SetPoint("LEFT", 10, 0)
            r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            r.title = UI:Text(r, 12, C.text); r.title:SetPoint("TOPLEFT", 50, -8); r.title:SetJustifyH("LEFT")
            if r.title.SetWordWrap then r.title:SetWordWrap(false) end
            r.sub = UI:Text(r, 10, C.dim); r.sub:SetPoint("TOPLEFT", r.title, "BOTTOMLEFT", 0, -3); r.sub:SetJustifyH("LEFT")
            if r.sub.SetWordWrap then r.sub:SetWordWrap(false) end
            r.btn = UI:Button(r, "Prendre", 84, 26, "secondary")
            r.btn:SetPoint("RIGHT", -10, 0)
            r.exp = UI:Text(r, 11, C.muted); r.exp:SetPoint("RIGHT", r.btn, "LEFT", -14, 0); r.exp:SetJustifyH("RIGHT")
            r.amount = UI:Text(r, 12, C.gold); r.amount:SetPoint("RIGHT", r.exp, "LEFT", -18, 0); r.amount:SetJustifyH("RIGHT")
            r.cod = UI:Badge(r, "", C.negative); r.cod:SetPoint("RIGHT", r.exp, "LEFT", -18, 0)
            r.btn:SetScript("OnClick", function()
                local e = r.e
                if not e then return end
                if e.cod > 0 then
                    -- contre-remboursement : la confirmation de paiement est celle du jeu
                    f.gameMode = true; f:Close()
                    WK:Print(T("Contre-remboursement : ouvre la lettre dans la fenêtre du jeu pour payer."))
                    return
                end
                -- expéditeur et objet de la ligne cliquée : refusé si la lettre à ce rang a changé (liste pas encore
                -- repeinte après une suppression : la lettre voisine était prise)
                Ml():TakeAll({ index = e.i, expectSender = e.sender, expectSubject = e.subject })
            end)
            r:SetScript("OnEnter", function(s)
                local e = s.e
                if not e then return end
                UI:TooltipOwner(s, "ANCHOR_RIGHT")
                local tt = _G.GameTooltip
                -- maquette A : une ligne par objet (icône, nom en couleur de qualité, quantité, prix HV de la pile
                -- et à l'unité ; sinon le prix du marchand), puis l'or joint et ce que vaut la lettre
                local exp = (e.days or 30) >= 1 and string.format(T("expire dans %d j"), math.floor(e.days))
                    or string.format(T("expire dans %d h"), math.max(1, math.floor((e.days or 0) * 24)))
                tt:AddDoubleLine(e.sender, exp, 1, 1, 1, 0.6, 0.6, 0.6)
                if e.subject ~= "" then tt:AddLine(e.subject, 0.7, 0.7, 0.7, true) end
                local Val = WK.modules.Value
                local worth = e.cod == 0 and e.money or 0
                if #e.items > 0 then tt:AddLine(" ") end
                for _, it in ipairs(e.items) do
                    local name, _, q, _, _, _, _, _, _, icon = WK.GetItemInfo(it.id or 0)
                    name = it.name or name or "?"
                    icon = it.icon or icon
                    local qc = q and _G.ITEM_QUALITY_COLORS and _G.ITEM_QUALITY_COLORS[q]
                    local left = (icon and ("|T" .. icon .. ":20:20:0:0:64:64:5:59:5:59|t ") or "") .. name
                        .. (it.n > 1 and ("  |cff999999x" .. it.n .. "|r") or "")
                    local ah, vendor
                    if Val and Val.Prices and it.id then ah, vendor = Val:Prices(it.id) end
                    local right, sub
                    if ah and ah > 0 then
                        right = UI:GoldText(ah * it.n)
                        if it.n > 1 then sub = string.format(T("%s l'unité"), WK:FormatMoney(ah)) end
                        worth = worth + ah * it.n
                    else
                        right = UI:Hex(C.muted) .. T("pas en vente") .. "|r"
                        if vendor and vendor > 0 then
                            sub = string.format(T("marchand %s"), WK:FormatMoney(vendor * it.n))
                            worth = worth + vendor * it.n
                        end
                    end
                    tt:AddDoubleLine(left, right, qc and qc.r or 1, qc and qc.g or 1, qc and qc.b or 1, 1, 1, 1)
                    if sub then tt:AddDoubleLine(" ", sub, 1, 1, 1, 0.55, 0.55, 0.55) end
                end
                tt:AddLine(" ")
                if e.money > 0 then
                    if e.cod > 0 then
                        tt:AddDoubleLine(T("Contre-remboursement"), UI:GoldText(e.cod), 1, 0.45, 0.45, 1, 1, 1)
                    else
                        tt:AddDoubleLine(T("Or joint"), UI:GoldText(e.money), 0.6, 0.6, 0.6, 1, 1, 1)
                    end
                elseif e.cod > 0 then
                    tt:AddDoubleLine(T("Contre-remboursement"), UI:GoldText(e.cod), 1, 0.45, 0.45, 1, 1, 1)
                end
                if worth > 0 then tt:AddDoubleLine(T("Valeur de la lettre"), UI:GoldText(worth), 1, 1, 1, 1, 1, 1) end
                tt:AddLine(T("« Prendre » : tout récupérer"), 0.5, 0.5, 0.5)
                tt:Show()
            end)
            r:SetScript("OnLeave", function() GameTooltip:Hide() end)
            return r
        end)
        function v:Refresh()
            self.rows:Reset()
            local list = inbox()
            local q = (self.search:GetText() or ""):lower()
            local y, total, n = 0, 0, 0
            local taking = Ml():IsTaking() or Ml():IsSending()
            for _, e in ipairs(list) do
                total = total + (e.cod == 0 and e.money or 0)
                local hay = (e.sender .. " " .. e.subject):lower()
                for _, it in ipairs(e.items) do hay = hay .. " " .. ((it.name or "")):lower() end
                if q == "" or hay:find(q, 1, true) then
                    n = n + 1
                    local r = self.rows:Get()
                    r.e = e
                    r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:SetPoint("TOPRIGHT", -14, -y)
                    local first = e.items[1]
                    r.icon:SetTexture((first and first.icon) or (e.money > 0 and "Interface\\Icons\\INV_Misc_Coin_01") or "Interface\\Icons\\INV_Letter_15")
                    r.title:SetText(e.ah and (T("Hôtel des ventes") .. " · " .. e.subject) or (e.sender .. ((e.subject ~= "") and (" · " .. e.subject) or "")))
                    local parts = {}
                    for k, it in ipairs(e.items) do
                        if k > 3 then table.insert(parts, "…") break end
                        table.insert(parts, string.format("%s x%d", it.name or "?", it.n))
                    end
                    r.sub:SetText(#parts > 0 and table.concat(parts, ", ") or (e.money > 0 and T("or") or T("lettre")))
                    local urgent = e.days < 3
                    r.exp:SetText(string.format(T("expire %d j"), math.max(0, math.floor(e.days))))
                    r.exp:SetTextColor(unpack(urgent and C.negative or C.muted))
                    r.edge:SetColorTexture(C.negative[1], C.negative[2], C.negative[3], urgent and 1 or 0)
                    r.cod:SetShown(e.cod > 0)
                    if e.cod > 0 then r.cod:Set(T("C.R.") .. " " .. UI:ShortGold(e.cod), C.negative) end
                    r.amount:SetShown(e.cod == 0)
                    r.amount:SetText(e.money > 0 and UI:GoldText(e.money) or (#e.items > 0 and string.format(T(#e.items > 1 and "%d objets" or "%d objet"), #e.items) or ""))
                    r.amount:SetTextColor(unpack(e.money > 0 and C.gold or C.muted))
                    r.btn.label:SetText(T(e.cod > 0 and "Payer…" or "Prendre"))
                    r.btn:SetEnabled(not taking and (e.money > 0 or #e.items > 0))
                    local w = (r:GetWidth() or 600) - 50 - 300
                    r.title:SetWidth(math.max(120, w)); r.sub:SetWidth(math.max(120, w))
                    y = y + ROW_H + 4
                end
            end
            self.scroll:SetContentHeight(y)
            self.empty:SetShown(n == 0)
            self.all.label:SetText(string.format(T("Tout prendre (%d)"), #list))
            self.all:SetEnabled(not taking and #list > 0)
            self.money:SetEnabled(not taking and total > 0)
            self.ah:SetEnabled(not taking)
            self.foot:SetText(string.format(T("Sacs : %d places libres"), freeSlots()) .. "  ·  " .. T("le courrier pris est noté (journal des ventes, Rangement)."))
            f.toTakeMoney = total
        end
    end

    -----------------------------------------------------------------------
    -- Envoyer
    -----------------------------------------------------------------------
    do
        local v = CreateFrame("Frame", nil, f.content)
        v:SetAllPoints()
        f.views.send = v
        local function label(text, y)
            local t = UI:Text(v, 11, C.muted); t:SetPoint("TOPLEFT", 0, y); t:SetText(T(text))
            return t
        end
        label("À", 0)
        v.to = UI:Input(v, 320, 30, T("Nom complet du destinataire"), "person")
        v.to:SetPoint("TOPLEFT", 0, -16)
        v.to.onChange = function() v:Suggest() end
        -- suggestions : liste déroulante sous le champ (tes persos d'abord, à la couleur de leur classe,
        -- puis les destinataires récents) ; jusqu'à SUGG noms, la place ne manque plus
        local SUGG, SROW = 10, 24
        v.suggBox = CreateFrame("Frame", nil, v)
        v.suggBox:SetPoint("TOPLEFT", v.to, "BOTTOMLEFT", 0, -2)
        v.suggBox:SetWidth(320)
        v.suggBox:SetFrameLevel(v:GetFrameLevel() + 30)
        UI:Panel(v.suggBox, 8, C.surface2, C.border)
        v.suggBox:Hide()
        v.sugg = {}
        for i = 1, SUGG do
            local b = CreateFrame("Button", nil, v.suggBox)
            b:SetHeight(SROW)
            b:SetPoint("TOPLEFT", 4, -4 - (i - 1) * SROW); b:SetPoint("TOPRIGHT", -4, -4 - (i - 1) * SROW)
            b.hl = b:CreateTexture(nil, "BACKGROUND"); b.hl:SetAllPoints(); b.hl:SetColorTexture(1, 1, 1, 0.06); b.hl:Hide()
            b.label = UI:Text(b, 12); b.label:SetPoint("LEFT", 8, 0)
            b.tag = UI:Text(b, 10, C.dim); b.tag:SetPoint("RIGHT", -8, 0); b.tag:SetJustifyH("RIGHT")
            b:SetScript("OnEnter", function(s) s.hl:Show() end)
            b:SetScript("OnLeave", function(s) s.hl:Hide() end)
            b:SetScript("OnClick", function(s) v.to:SetText(s.name); v.to.edit:ClearFocus(); v:Suggest(true) end)
            b:Hide()
            v.sugg[i] = b
        end
        label("Objet", -62)
        v.subject = UI:Input(v, 320, 30, T("Facultatif : nom de la 1re pièce jointe"))
        v.subject:SetPoint("TOPLEFT", 0, -78)
        label("Pièces jointes (clic droit sur un objet des sacs, ou glisse-le ici ; clic droit sur une case : retirer)", -122)
        v.slots = {}
        for i = 1, MAX_SEND do
            local b = CreateFrame("Button", nil, v)
            b:SetSize(42, 42)
            local col, row = (i - 1) % 6, math.floor((i - 1) / 6)
            b:SetPoint("TOPLEFT", col * 48, -140 - row * 48)
            b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            b:RegisterForDrag("LeftButton")
            b.bg = UI:Rounded(b, 7, 0, "BACKGROUND", 1); b.bg:SetColor(unpack(C.surface2))
            b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetPoint("TOPLEFT", 3, -3); b.icon:SetPoint("BOTTOMRIGHT", -3, 3)
            b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            b.count = UI:Text(b, 10, C.text); b.count:SetPoint("BOTTOMRIGHT", -3, 3)
            b.i = i
            b:SetScript("OnClick", function(s, btn)
                if inCombat() or Ml():IsSending() then return end
                if btn == "RightButton" then
                    if GetSendMailItem and GetSendMailItem(s.i) then ClickSendMailItemButton(s.i, true) end
                else
                    ClickSendMailItemButton(s.i)
                end
            end)
            b:SetScript("OnReceiveDrag", function(s) if not Ml():IsSending() then ClickSendMailItemButton(s.i) end end)
            b:SetScript("OnEnter", function(s)
                if not (GetSendMailItemLink and GetSendMailItemLink(s.i)) then return end
                UI:TooltipOwner(s, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(GetSendMailItemLink(s.i))
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            v.slots[i] = b
        end
        label("Argent", -246)
        v.po = UI:Input(v, 90, 30, "0"); v.po:SetPoint("TOPLEFT", 0, -262)
        v.poT = UI:Text(v, 11, C.gold); v.poT:SetPoint("LEFT", v.po, "RIGHT", 4, 0); v.poT:SetText(T("po"))
        v.pa = UI:Input(v, 60, 30, "0"); v.pa:SetPoint("LEFT", v.poT, "RIGHT", 10, 0)
        v.paT = UI:Text(v, 11, C.silver or C.muted); v.paT:SetPoint("LEFT", v.pa, "RIGHT", 4, 0); v.paT:SetText(T("pa"))
        v.mode = UI:Segmented(v, { { "send", "Envoyer de l'or" }, { "cod", "Contre-remboursement" } }, function(k) v.cod = (k == "cod"); v:Refresh() end, 28)
        v.mode:SetPoint("LEFT", v.paT, "RIGHT", 20, 0)
        v.mode:Select("send")
        for _, inp in ipairs({ v.po, v.pa }) do
            inp.edit:SetNumeric(true)
            inp.onChange = function() v:Refresh() end
        end
        v.post = UI:Text(v, 11, C.muted); v.post:SetPoint("TOPLEFT", 0, -306)
        v.send = UI:Button(v, "Envoyer", 140, 32, "primary", "send")
        v.send:SetPoint("TOPLEFT", 0, -330)
        v.clear = UI:Button(v, "Vider", 90, 32, "secondary")
        v.clear:SetPoint("LEFT", v.send, "RIGHT", 8, 0)
        v.clear:SetScript("OnClick", function()
            if inCombat() or Ml():IsSending() then return end
            for i = 1, MAX_SEND do if GetSendMailItem and GetSendMailItem(i) then ClickSendMailItemButton(i, true) end end
            v.po:SetText(""); v.pa:SetText(""); v.subject:SetText("")
            v:Refresh()
        end)
        v.warn = UI:Text(v, 11, C.warning); v.warn:SetPoint("LEFT", v.clear, "RIGHT", 12, 0)
        local function money()
            return (tonumber(v.po:GetText()) or 0) * 10000 + (tonumber(v.pa:GetText()) or 0) * 100
        end
        local function attached()
            local n, first = 0, nil
            for i = 1, MAX_SEND do
                local name = GetSendMailItem and GetSendMailItem(i)
                if name then n = n + 1; first = first or name end
            end
            return n, first
        end
        v.send:SetScript("OnClick", function()
            if inCombat() or Ml():IsSending() then return end
            local to = Ml():Recipient(v.to:GetText() or "")
            if to == "" then v.warn:SetText(T("Indique un destinataire.")) return end
            local n, first = attached()
            local m = money()
            if n == 0 and m == 0 and (v.subject:GetText() or "") == "" then v.warn:SetText(T("Rien à envoyer.")) return end
            if v.cod and n == 0 then v.warn:SetText(T("Un contre-remboursement demande une pièce jointe.")) return end
            -- de l'or part (pas un contre-remboursement) : la fenêtre du jeu le fait confirmer, nous aussi
            -- (deuxième clic dans les 8 s, même destinataire et même montant)
            if not v.cod and m > 0 then
                local key = to .. "|" .. m
                if v.confirmKey ~= key or GetTime() - (v.confirmAt or 0) > 8 then
                    v.confirmKey, v.confirmAt = key, GetTime()
                    v.warn:SetText(string.format(T("Envoyer %s à %s ? Clique encore sur Envoyer pour confirmer."), UI:GoldText(m), to))
                    return
                end
            end
            v.confirmKey = nil
            if v.cod then SetSendMailCOD(m); SetSendMailMoney(0) else SetSendMailCOD(0); SetSendMailMoney(m) end
            local subject = v.subject:GetText() or ""
            if subject == "" then subject = first or T("Courrier") end
            v.pendingTo = to
            local send = SendMail or (C_Mail and C_Mail.SendMail)
            send(to, subject, "")
        end)
        function v:Suggest(hide)
            local q = (self.to:GetText() or ""):lower()
            local names, seen = {}, {}
            -- classe d'un nom : celle de ton perso qui le porte (les autres destinataires restent en blanc)
            local classOf = {}
            for key, c in pairs(WK.DB.global.characters) do
                local mn = Ml():MailName(c)
                if mn and key ~= WK:CharKey() then classOf[mn:lower()] = c.class end
            end
            local function add(n, mine)
                if n and n ~= "" and not seen[n:lower()] and (q == "" or n:lower():find(q, 1, true)) and n:lower() ~= q then
                    seen[n:lower()] = true; table.insert(names, { n = n, mine = mine })
                end
            end
            if not hide and self.to.edit:HasFocus() then
                local mineList = {}
                for key, c in pairs(WK.DB.global.characters) do
                    if key ~= WK:CharKey() then table.insert(mineList, Ml():MailName(c)) end
                end
                table.sort(mineList, function(a, b) return (a or "") < (b or "") end)
                for _, n in ipairs(mineList) do add(n, true) end
                for _, n in ipairs(cfg().recent) do add(n, classOf[n:lower()] ~= nil) end
            end
            local shown = 0
            for i, b in ipairs(self.sugg) do
                local e = names[i]
                b.name = e and e.n
                if e then
                    shown = i
                    b.label:SetText(e.n)
                    local cl = classOf[e.n:lower()]
                    if cl then b.label:SetTextColor(UI:ClassColor(cl)) else b.label:SetTextColor(unpack(C.text)) end
                    b.tag:SetText(e.mine and T("mon perso") or T("récent"))
                    b:Show()
                else b:Hide() end
            end
            self.suggBox:SetHeight(shown * SROW + 8)
            self.suggBox:SetShown(shown > 0)
        end
        v.to.edit:HookScript("OnEditFocusGained", function() v:Suggest() end)
        v.to.edit:HookScript("OnEditFocusLost", function() C_Timer.After(0.2, function() v:Suggest(true) end) end)
        function v:Refresh()
            local n = 0
            for i, b in ipairs(self.slots) do
                local name, _, tex, count
                if GetSendMailItem then name, _, tex, count = GetSendMailItem(i) end
                b.icon:SetTexture(name and tex or nil)
                b.count:SetText((name and (count or 1) > 1) and tostring(count) or "")
                local r1, g1, b1 = UI:Accent()
                b.bg:SetColor(name and r1 or C.surface2[1], name and g1 or C.surface2[2], name and b1 or C.surface2[3], name and 0.22 or 1)
                if name then n = n + 1 end
            end
            local price = GetSendMailPrice and GetSendMailPrice() or 0
            local me = Ml():Resolve(self.to:GetText() or "")
            self.post:SetText(string.format(T("Port : %s"), UI:GoldText(price)) .. (me and ("  ·  " .. T("arrivée immédiate (perso du compte)")) or ""))
            self.send:SetEnabled(not Ml():IsSending())
            -- (la demande de confirmation de l'or reste affichée tant qu'elle vaut)
            local asking = not self.cod and self.confirmKey and GetTime() - (self.confirmAt or 0) <= 8
                and self.confirmKey == (Ml():Recipient(self.to:GetText() or "") .. "|" .. money())
            if Ml():IsSending() or not asking then self.warn:SetText(Ml():IsSending() and T("Envoi automatique en cours…") or "") end
        end
    end

    -----------------------------------------------------------------------
    -- Rangement : le panneau de UI/StashMail.lua, posé dans la page
    -----------------------------------------------------------------------
    do
        local v = CreateFrame("Frame", nil, f.content)
        v:SetAllPoints()
        f.views.stash = v
        function v:Refresh()
            local p = UI.StashMailPanel and UI:StashMailPanel()
            if not p then return end
            if p:GetParent() ~= self then
                p:SetParent(self); p:ClearAllPoints(); p:SetAllPoints(self)
                p:SetFrameStrata(f:GetFrameStrata())
                if p.close then p.close:Hide() end
            end
            p:Refresh(); p:Show()
        end
    end

    -----------------------------------------------------------------------
    -- Règles d'envoi
    -----------------------------------------------------------------------
    do
        local v = CreateFrame("Frame", nil, f.content)
        v:SetAllPoints()
        f.views.rules = v
        v.run = UI:Button(v, "Envoyer maintenant", 200, 28, "primary", "send")
        v.run:SetPoint("TOPLEFT")
        v.run:SetScript("OnClick", function()
            local M = Ml()
            if M:IsSending() then return end
            local was = WK.DB.global.mail.enabled
            WK.DB.global.mail.enabled = true
            M:Run()
            WK.DB.global.mail.enabled = was
            C_Timer.After(0.5, function() if f:IsShown() then f:Refresh() end end)
        end)
        v.auto = UI:Toggle(v, function() return WK.DB.global.mail.enabled end, function(on) WK.DB.global.mail.enabled = on; WK:NotifyChanged() end)
        v.auto:SetPoint("LEFT", v.run, "RIGHT", 16, 0)
        v.autoT = UI:Text(v, 11, C.muted); v.autoT:SetPoint("LEFT", v.auto, "RIGHT", 8, 0)
        v.autoT:SetText(T("Envoi automatique à l'ouverture"))
        v.manage = UI:Button(v, "Gérer les règles", 140, 28, "secondary")
        v.manage:SetPoint("TOPRIGHT")
        v.manage.tooltip = "Ouvre la page Courrier de Warband Keeper (nouvelle règle, catégories, à garder)."
        v.manage:SetScript("OnClick", function() UI:Create():Show(); UI:ShowPage("mail") end)
        v.scroll = UI:Scroll(v)
        v.scroll:SetPoint("TOPLEFT", 0, -40); v.scroll:SetPoint("BOTTOMRIGHT")
        v.empty = UI:Text(v, 12, C.muted); v.empty:SetPoint("TOP", 0, -90)
        v.empty:SetText(T("Aucune règle d'envoi : crée-les dans la page Courrier de Warband Keeper."))
        v.rows = UI:Pool(function()
            local r = CreateFrame("Frame", nil, v.scroll.child)
            r:SetHeight(34)
            r.bg = UI:Rounded(r, 7, 0, "BACKGROUND", 1); r.bg:SetColor(unpack(C.surface2))
            r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(22, 22); r.icon:SetPoint("LEFT", 8, 0)
            r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            r.what = UI:Text(r, 12); r.what:SetPoint("LEFT", 38, 0); r.what:SetJustifyH("LEFT")
            if r.what.SetWordWrap then r.what:SetWordWrap(false) end
            r.to = UI:Text(r, 12, C.text); r.to:SetJustifyH("LEFT")
            r.keep = UI:Text(r, 11, C.muted); r.keep:SetJustifyH("RIGHT")
            r.del = UI:IconButton(r, "trash", 22, "Retirer la règle", true)
            r.del:SetPoint("RIGHT", -6, 0)
            r.del:SetScript("OnClick", function()
                if r.cat then Ml():RemoveCategoryRule(r.key) else Ml():RemoveRule(r.key) end
                v:Refresh()
            end)
            return r
        end)
        function v:Refresh()
            self.rows:Reset()
            local R = WK.modules.Rules
            local list = {}
            for key, r in pairs(WK.DB.global.mail.rules or {}) do
                local id, from = R:SplitKey(key)
                local name, icon = UI:ItemInfo(id)
                table.insert(list, { key = key, label = name or ("#" .. tostring(id)), icon = icon, to = r.to, keep = r.keep, from = from })
            end
            for key, r in pairs(WK.DB.global.mail.cats or {}) do
                local _, from = R:SplitKey(key)
                table.insert(list, { key = key, cat = true, label = "[" .. R:CategoryLabel(key) .. "]", icon = "Interface\\Icons\\INV_Misc_Bag_10", to = r.to, keep = r.keep, from = from })
            end
            table.sort(list, function(a, b) if a.to ~= b.to then return (a.to or "") < (b.to or "") end return a.label < b.label end)
            local y, w = 0, self.scroll:GetWidth() or 600
            for _, e in ipairs(list) do
                local r = self.rows:Get()
                r.key, r.cat = e.key, e.cat
                r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:SetPoint("TOPRIGHT", -14, -y)
                r.icon:SetTexture(e.icon)
                r.what:SetText(e.label); r.what:SetWidth(math.max(120, w * 0.45))
                r.to:ClearAllPoints(); r.to:SetPoint("LEFT", 38 + w * 0.45 + 12, 0)
                r.to:SetText("» " .. tostring(e.to or "?") .. (e.from and ("  " .. UI:Hex(C.dim) .. string.format(T("(depuis %s)"), tostring(e.from)) .. "|r") or ""))
                r.keep:ClearAllPoints(); r.keep:SetPoint("RIGHT", r.del, "LEFT", -12, 0)
                r.keep:SetText((e.keep or 0) > 0 and string.format(T("garder %d"), e.keep) or "")
                y = y + 38
            end
            self.scroll:SetContentHeight(y)
            self.empty:SetShown(#list == 0)
            local n = Ml():PendingCount()
            self.run.label:SetText(n > 0 and string.format(T("Envoyer maintenant (%d)"), n) or T("Rien à envoyer"))
            self.run:SetEnabled(n > 0 and not Ml():IsSending())
            self.auto:Refresh()
        end
    end

    -----------------------------------------------------------------------
    -- Historique : courriers envoyés (journal) et ventes de l'HV encaissées
    -----------------------------------------------------------------------
    do
        local v = CreateFrame("Frame", nil, f.content)
        v:SetAllPoints()
        f.views.history = v
        v.scroll = UI:Scroll(v)
        v.scroll:SetAllPoints()
        v.empty = UI:Text(v, 12, C.muted); v.empty:SetPoint("TOP", 0, -90)
        v.empty:SetText(T("Rien pour l'instant."))
        v.rows = UI:Pool(function()
            local r = CreateFrame("Frame", nil, v.scroll.child)
            r:SetHeight(30)
            r.when = UI:Text(r, 11, C.dim); r.when:SetPoint("LEFT", 6, 0); r.when:SetWidth(90); r.when:SetJustifyH("LEFT")
            r.icon = UI:Icon(r, "send", 14); r.icon:SetPoint("LEFT", 100, 0)
            r.t = UI:Text(r, 12); r.t:SetPoint("LEFT", 124, 0); r.t:SetPoint("RIGHT", -120, 0); r.t:SetJustifyH("LEFT")
            if r.t.SetWordWrap then r.t:SetWordWrap(false) end
            r.v = UI:Text(r, 12, C.gold); r.v:SetPoint("RIGHT", -8, 0)
            r.line = r:CreateTexture(nil, "ARTWORK"); r.line:SetHeight(1)
            r.line:SetPoint("BOTTOMLEFT"); r.line:SetPoint("BOTTOMRIGHT"); r.line:SetColorTexture(unpack(C.border))
            return r
        end)
        function v:Refresh()
            self.rows:Reset()
            local list = {}
            local J = WK.modules.Journal
            for _, e in ipairs(J and J:Entries("mail") or {}) do
                if e.kind == "mail" then
                    local n = 0
                    for _, k in pairs(e.items or {}) do n = n + k end
                    table.insert(list, { t = e.t, icon = "send", text = string.format(T("Envoyé à %s : %d objet(s), %d lettre(s)"), tostring(e.to), n, e.letters or 1) })
                end
            end
            for _, e in ipairs(WK.DB.global.auction and WK.DB.global.auction.log or {}) do
                if e.kind == "sale" and (e.t or 0) > time() - 30 * 86400 then
                    local name = e.item and (WK.GetItemInfo(e.item) or e.item) or "?"
                    table.insert(list, { t = e.t, icon = "coin", text = string.format(T("Vente HV : %s x%d"), name, e.count or 1), v = e.net })
                end
            end
            table.sort(list, function(a, b) return (a.t or 0) > (b.t or 0) end)
            local y = 0
            for i = 1, math.min(#list, 80) do
                local e = list[i]
                local r = self.rows:Get()
                r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:SetPoint("TOPRIGHT", -14, -y)
                r.when:SetText(date("%d/%m %H:%M", e.t or 0))
                r.icon:SetTexture(UI.MEDIA .. e.icon); r.icon:SetVertexColor(UI:Accent())
                r.t:SetText(e.text)
                r.v:SetText(e.v and UI:GoldText(e.v) or "")
                y = y + 30
            end
            self.scroll:SetContentHeight(y)
            self.empty:SetShown(#list == 0)
        end
    end

    function f:Refresh()
        self.head:SetText(T("Courrier") .. " · " .. myName())
        self.gold:SetText(UI:GoldText(GetMoney and GetMoney() or 0))
        local list = inbox()
        local money = 0
        for _, e in ipairs(list) do if e.cod == 0 then money = money + e.money end end
        self.toTake:SetShown(money > 0)
        if money > 0 then self.toTake:Set(string.format(T("%s à prendre"), UI:ShortGold(money)), C.gold) end
        self.nav.inbox:SetCount(#list)
        local okS, ships = pcall(function() return WK.modules.Stash:MyShipments() end)
        self.nav.stash:SetCount(okS and #ships or 0, C.rule)
        local okP, pend = pcall(Ml().PendingCount, Ml())
        self.nav.rules:SetCount(okP and pend or 0, C.muted)
        for _, nb in pairs(self.nav) do nb:Paint() end
        self:RefreshSide()
        local v = self.views[self.tab]
        if v and v.Refresh then v:Refresh() end
    end
    return f
end

---------------------------------------------------------------------------
-- Ouverture : notre fenêtre à la place de celle du jeu
---------------------------------------------------------------------------
local function attach()
    if not (cfg().window and WK:FeatureOn("mail")) then return end
    local host = MailFrame
    if not host or not host:IsShown() then return end
    if not view then view = build(host) end
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    view:SetSize(math.min(WIN_W, sw - 20), math.min(WIN_H, sh - 40))
    view.gameMode = false
    view:Open(cfg().tab or "inbox")
end
function UI:MailWindowShown() return view ~= nil and view:IsShown() end
function UI:MailWindow() return view end

WK:On("MAIL_SHOW", function() C_Timer.After(0.15, attach) end)
WK:On("MAIL_CLOSED", function()
    if view then view.gameMode = false; view:Close(); if view.back then view.back:Hide() end end
end)
-- fin d'interaction avec la boîte aux lettres (clients récents : MAIL_CLOSED n'arrive pas toujours)
WK:On("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(kind)
    local mailKind = Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.MailInfo or 17
    if kind == mailKind and view then view.gameMode = false; view:Close(); if view.back then view.back:Hide() end end
end)
local function soon()
    if not (view and view:IsShown()) or view.pending then return end
    view.pending = true
    C_Timer.After(0.2, function() view.pending = nil; if view:IsShown() then view:Refresh() end end)
end
WK:On("MAIL_INBOX_UPDATE", soon)
WK:On("MAIL_SEND_INFO_UPDATE", soon)
WK:On("BAG_UPDATE_DELAYED", soon)
WK:On("PLAYER_MONEY", soon)
WK:On("MAIL_SEND_SUCCESS", function()
    if not view then return end
    local sv = view.views.send
    if sv and sv.pendingTo then
        -- destinataire mis en tête des récents ; champs vidés pour la lettre suivante
        local rec = cfg().recent
        for i = #rec, 1, -1 do if rec[i]:lower() == sv.pendingTo:lower() then table.remove(rec, i) end end
        table.insert(rec, 1, sv.pendingTo)
        while #rec > 8 do table.remove(rec) end
        sv.pendingTo = nil
        sv.po:SetText(""); sv.pa:SetText(""); sv.subject:SetText("")
        WK:Print(T("Courrier envoyé."))
    end
    soon()
end)
WK:On("MAIL_FAILED", function() if view and view.views.send then view.views.send.pendingTo = nil end end)
