local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

local GAP = 12

local function count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local function categoryOptions()
    local opts = {}
    for _, c in ipairs(WK.modules.Rules.CATEGORIES) do table.insert(opts, { c.key, c.label }) end
    return opts
end

local TARGETS = { { "bank", "Banque du perso" }, { "warband", "Banque de bataillon" } }
local function targetLabel(t) return t == "warband" and T("Banque de bataillon") or T("Banque du perso") end

---------------------------------------------------------------------------
-- Éditeur de règles partagé par l'envoi (mode "mail") et le dépôt (mode "bank").
---------------------------------------------------------------------------
local function RuleEditor(page, parent, mode, top)
    local ed = {}
    local isMail = mode == "mail"

    local cfg = isMail and WK.DB.global.mail or WK.DB.global.bank
    -- Les réglages (envoi / dépôt automatique, fermeture, tri) sont dans Options > Courrier.
    -- Nouvelle règle
    local ADD_H = 132
    local add = UI:Card(parent, "Nouvelle règle")
    add:SetHeight(ADD_H)
    add:SetPoint("TOPLEFT", 0, top)
    add:SetPoint("TOPRIGHT", 0, top)
    local kind = "item"
    local item = UI:Input(add, 220, 34, "Maj + clic ou ID d'objet", "bag")
    item.edit.acceptLinks = true
    local cat = UI:Dropdown(add, 220, 34, categoryOptions())
    cat:Hide()
    local typeDd = UI:Dropdown(add, 130, 34, { { "item", "Objet" }, { "cat", "Catégorie" } }, function(k)
        kind = k
        item:SetShown(k == "item")
        cat:SetShown(k == "cat")
    end)
    typeDd:SetPoint("TOPLEFT", 16, -42)
    item:SetPoint("LEFT", typeDd, "RIGHT", 10, 0)
    cat:SetPoint("LEFT", typeDd, "RIGHT", 10, 0)
    local arrow = UI:Icon(add, "arrow", 16, C.muted)
    arrow:SetPoint("LEFT", item, "RIGHT", 12, 0)
    local dest, pick
    if isMail then
        dest = UI:Input(add, 160, 34, "Destinataire", "users")
        -- Petit bouton liste : choisir un de ses persos (nom complet). Le champ reste libre
        -- pour écrire le nom d'un autre joueur.
        pick = UI:Dropdown(add, 34, 34, { { "", "" } }, function(v) if v ~= "" then dest:SetText(v) end end)
        pick.label:Hide()
        pick.list:SetWidth(230)
        pick.arrow:ClearAllPoints()
        pick.arrow:SetPoint("CENTER")
        ed.pick = pick
    else
        dest = UI:Dropdown(add, 170, 34, TARGETS)
    end
    dest:SetPoint("LEFT", arrow, "RIGHT", 12, 0)
    if pick then pick:SetPoint("LEFT", dest, "RIGHT", 6, 0) end
    local keep = UI:NumberInput(add, 84, 34, "Garder")
    keep:SetPoint("LEFT", pick or dest, "RIGHT", 10, 0)
    keep.tooltip = "Quantité à garder dans les sacs"
    local btn = UI:Button(add, "Ajouter", nil, 34, "primary", "plus")
    btn:SetPoint("TOPRIGHT", -16, -42)

    -- Perso concerné par la règle : celui qui envoie / dépose, ou tous.
    local fromLbl = UI:Text(add, 12, C.muted)
    fromLbl:SetPoint("TOPLEFT", 16, -96)
    fromLbl:SetText(isMail and "Envoyé par :" or "Déposé par :")
    local fromDd = UI:Dropdown(add, 240, 30, { { "", "Tous les persos" } })
    fromDd:SetPoint("TOPLEFT", 16 + fromLbl:GetStringWidth() + 10, -86)
    ed.fromDd = fromDd

    local function doAdd()
        local n = keep:GetNumber()
        local from = (fromDd.selected and fromDd.selected ~= "") and fromDd.selected or nil
        local ok
        if isMail then
            local name = (dest:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if kind == "item" then ok = WK.modules.Mail:AddRule(item:GetText(), name, n, from)
            else ok = WK.modules.Mail:AddCategoryRule(cat.selected, name, n, from) end
        else
            if kind == "item" then ok = WK.modules.BankDeposit:AddRule(item:GetText(), dest.selected, n, from)
            else ok = WK.modules.BankDeposit:AddCategoryRule(cat.selected, dest.selected, n, from) end
        end
        if ok then
            item:SetText(""); keep:SetText("")
            page:Refresh()
        else
            WK:Print(isMail and T("Indique un objet (Maj + clic) et un destinataire.") or T("Indique un objet (Maj + clic)."))
        end
    end
    btn:SetScript("OnClick", doAdd)
    if isMail then dest.onEnter = doAdd end

    -- Liste
    local listTop = top - ADD_H - GAP
    local list = UI:Card(parent, "Règles")
    list:SetPoint("TOPLEFT", 0, listTop)
    list:SetPoint("BOTTOMRIGHT")
    ed.empty = UI:Text(list, 12, C.muted)
    ed.empty:SetPoint("CENTER")
    ed.empty:SetText("Aucune règle pour l'instant.")
    local scroll = UI:Scroll(list)
    scroll:SetPoint("TOPLEFT", 10, -40)
    scroll:SetPoint("BOTTOMRIGHT", -8, 10)
    ed.scroll = scroll
    ed.rows = UI:Pool(function()
        local r = CreateFrame("Frame", nil, scroll.child)
        r:SetHeight(40)
        r.bg = UI:Rounded(r, 10, 0, "BACKGROUND", 1)
        r.bg:SetColor(unpack(C.surface2))
        r.icon = UI:RoundIcon(r, 24)
        r.icon:SetPoint("LEFT", 10, 0)
        r.glyph = UI:Icon(r, "bag", 16)
        r.glyph:SetPoint("CENTER", r.icon, "CENTER")
        r.name = UI:Text(r, 12)
        r.name:SetPoint("LEFT", 44, 0)
        r.name:SetWidth(250)
        r.badge = UI:Badge(r, "catégorie")
        r.badge:SetPoint("LEFT", 44, 0)
        r.arrow = UI:Icon(r, "arrow", 14, C.muted)
        r.arrow:SetPoint("LEFT", 310, 0)
        r.to = UI:Text(r, 12)
        r.to:SetPoint("LEFT", r.arrow, "RIGHT", 12, 0)
        r.info = UI:Text(r, 11, C.muted)
        r.info:SetPoint("RIGHT", -44, 0)
        r.info:SetJustifyH("RIGHT")
        r.keep = UI:Text(r, 11, C.muted)
        r.keep:SetPoint("LEFT", 520, 0)
        r.keep:SetPoint("RIGHT", r.info, "LEFT", -12, 0)
        r.keep:SetJustifyH("LEFT")
        r.del = UI:IconButton(r, "trash", 26, "Supprimer la règle", true)
        r.del:SetPoint("RIGHT", -8, 0)
        r.del:SetScript("OnClick", function(b)
            local mod = isMail and WK.modules.Mail or WK.modules.BankDeposit
            if b.cat then mod:RemoveCategoryRule(b.ruleKey) else mod:RemoveRule(b.ruleKey) end
            page:Refresh()
        end)
        return r
    end)

    function ed:Refresh()
        local opts = { { "", T("Tous les persos") } }
        for _, e in ipairs(UI:SortedCharacters()) do
            table.insert(opts, { e.key, WK:CharName(e.c, e.key), { UI:ClassColor(e.c.class) } })
        end
        self.fromDd:SetOptions(opts)
        local me = WK.DB:Me()

        -- Liste des persos du royaume courant pour le destinataire (nom complet)
        if self.pick then
            local realm = GetRealmName()
            local list = {}
            for _, e in ipairs(UI:SortedCharacters()) do
                if e.c.realm == realm and e.c.name then
                    table.insert(list, { WK.modules.Mail:MailName(e.c), WK:CharName(e.c, e.key), { UI:ClassColor(e.c.class) } })
                end
            end
            if #list == 0 then list = { { "", T("Aucun perso enregistré") } } end
            self.pick:SetOptions(list)
            self.pick.selected = nil
        end

        local store = isMail and WK.modules.Mail:Store() or WK.modules.BankDeposit:Store()
        local entries = {}
        local Rl = WK.modules.Rules
        for key, rule in pairs(store.cats) do
            local base, from = Rl:SplitKey(key)
            table.insert(entries, { cat = base, key = key, from = from, rule = rule,
                sort = "0" .. Rl:CategoryLabel(base) .. "\1" .. (from or "") })
        end
        for key, rule in pairs(store.items) do
            local id, from = Rl:SplitKey(key)
            table.insert(entries, { itemID = id, key = key, from = from, rule = rule,
                sort = "1" .. (UI:ItemInfo(id) or "") .. "\1" .. (from or "") })
        end
        table.sort(entries, function(a, b) return a.sort < b.sort end)

        self.rows:Reset()
        local y = 0
        for _, e in ipairs(entries) do
            local r = self.rows:Get()
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -y)
            r:SetPoint("TOPRIGHT", 0, -y)
            r.del.cat, r.del.itemID, r.del.ruleKey = e.cat, e.itemID, e.key
            if e.cat then
                r.icon:Hide(); r.glyph:Show()
                r.glyph:SetVertexColor(UI:Accent())
                r.badge:Show()
                r.badge:Set(T("catégorie"))
                r.name:ClearAllPoints()
                r.name:SetPoint("LEFT", r.badge, "RIGHT", 8, 0)
                r.name:SetWidth(250 - r.badge:GetWidth() - 8)
                r.name:SetText(WK.modules.Rules:CategoryLabel(e.cat))
                r.name:SetTextColor(unpack(C.text))
            else
                local name, icon, qr, qg, qb = UI:ItemInfo(e.itemID)
                r.glyph:Hide(); r.icon:Show()
                r.icon:SetTexture(icon)
                r.badge:Hide()
                r.name:ClearAllPoints()
                r.name:SetPoint("LEFT", 44, 0)
                r.name:SetWidth(250)
                r.name:SetText(name)
                r.name:SetTextColor(qr, qg, qb)
            end
            if isMail then
                -- Nom réellement utilisé à l'envoi (nom complet d'un perso du compte).
                local tc = WK.modules.Mail:Resolve(e.rule.to)
                r.to:SetText(WK.modules.Mail:Recipient(e.rule.to))
                r.to:SetTextColor(UI:ClassColor(tc and tc.class))
            else
                r.to:SetText(targetLabel(e.rule.target))
                r.to:SetTextColor(unpack(C.text))
            end
            -- Perso concerné (ou tous) et quantité gardée.
            local who
            if e.from then
                local fc = WK.DB.global.characters[e.from]
                local cr, cg, cb = UI:ClassColor(fc and fc.class)
                who = string.format(T("par %s"), string.format("|cff%02x%02x%02x%s|r", cr * 255, cg * 255, cb * 255,
                    WK:CharName(fc, e.from)))
            else
                who = T("tous les persos")
            end
            if (e.rule.keep or 0) > 0 then who = who .. "  ·  " .. string.format(T("garder %d"), e.rule.keep) end
            r.keep:SetText(who)
            if e.itemID then
                local n = (me.bags or {})[e.itemID] or 0
                if isMail and WK.modules.Mail:IsMe(e.rule.to) then
                    r.info:SetText(T("c'est ce personnage"))
                else
                    r.info:SetText(n > 0 and string.format(T("x%d dans les sacs"), n) or "")
                end
            else
                r.info:SetText("")
            end
            y = y + 46
        end
        self.scroll:SetContentHeight(y)
        self.empty:SetShown(#entries == 0)
    end
    return ed
end

---------------------------------------------------------------------------
-- Onglet Réception : prise automatique + boîtes aux lettres du compte.
---------------------------------------------------------------------------
local function Reception(page, parent, top)
    local rc = {}
    local list = UI:Card(parent, "Boîtes aux lettres du compte")
    list:SetPoint("TOPLEFT", 0, top)
    list:SetPoint("BOTTOMRIGHT")
    local scroll = UI:Scroll(list)
    scroll:SetPoint("TOPLEFT", 10, -40)
    scroll:SetPoint("BOTTOMRIGHT", -8, 10)
    rc.scroll = scroll
    rc.rows = UI:Pool(function()
        local r = CreateFrame("Frame", nil, scroll.child)
        r:SetHeight(40)
        r.bg = UI:Rounded(r, 10, 0, "BACKGROUND", 1)
        r.bg:SetColor(unpack(C.surface2))
        r.icon = UI:RoundIcon(r, 24)
        r.icon:SetPoint("LEFT", 10, 0)
        r.name = UI:Text(r, 12)
        r.name:SetPoint("LEFT", 44, 0)
        r.letters = UI:Text(r, 12, C.muted)
        r.letters:SetPoint("LEFT", 230, 0)
        r.items = UI:Text(r, 12, C.muted)
        r.items:SetPoint("LEFT", 360, 0)
        r.gold = UI:Text(r, 12)
        r.gold:SetPoint("LEFT", 500, 0)
        r.exp = UI:Text(r, 12, C.muted)
        r.exp:SetPoint("LEFT", 660, 0)
        return r
    end)

    function rc:Refresh()
        self.rows:Reset()
        local y = 0
        for _, e in ipairs(UI:SortedCharacters()) do
            local box = e.c.mailbox
            if box and (box.count or 0) > 0 then
                local r = self.rows:Get()
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", 0, -y)
                r:SetPoint("TOPRIGHT", 0, -y)
                UI:SetCharIcon(r.icon, e.c, e.key)
                r.name:SetText(WK:CharName(e.c, e.key))
                r.name:SetTextColor(UI:ClassColor(e.c.class))
                r.letters:SetText(string.format(box.count > 1 and T("%d lettres") or T("%d lettre"), box.count))
                r.items:SetText(string.format(T("%d objet(s)"), WK.modules.Farm:ItemCount(box.items or {})))
                r.gold:SetText((box.money or 0) > 0 and UI:GoldText(box.money) or "")
                if box.expiresAt then
                    local d = math.max(0, math.floor((box.expiresAt - time()) / 86400))
                    r.exp:SetText(string.format(T("expire dans %d j"), d))
                    r.exp:SetTextColor(unpack(d <= WK.DB.global.settings.alerts.mailDays and C.warning or C.muted))
                else
                    r.exp:SetText("")
                end
                y = y + 46
            end
        end
        self.scroll:SetContentHeight(y)
    end
    return rc
end

UI:RegisterPage({
    key = "mail", order = 7, nav = "Courrier",
    title = "Courrier et banque",
    subtitle = "Envoi du farm à tes persos, dépôt en banque et récupération du courrier.",
    count = function()
        local n = count(WK.DB.global.mail.rules) + count(WK.DB.global.mail.cats)
        return n > 0 and tostring(n) or ""
    end,

    Build = function(self, p)
        self.tab = "send"
        self.tabs = {}
        local frames = {}
        local function setTab(k)
            self.tab = k
            for key, f in pairs(frames) do f:SetShown(key == k) end
            self:Refresh()
        end
        local seg = UI:Segmented(p, { { "send", "Envoi" }, { "bank", "Dépôt banque" }, { "receive", "Réception" } }, setTab, 32)
        function self:SetTab(k) seg:Select(k); setTab(k) end
        seg:SetPoint("TOPLEFT")
        seg:Select("send")
        for _, key in ipairs({ "send", "bank", "receive" }) do
            local f = CreateFrame("Frame", nil, p)
            f:SetAllPoints()
            f:SetShown(key == "send")
            frames[key] = f
        end
        -- Raccourci vers les réglages (Options > Courrier) et état de l'automatisme de l'onglet.
        local settings = UI:Button(p, "Réglages", nil, 30, "secondary", "gear")
        settings:SetPoint("TOPRIGHT", 0, -1)
        settings.tooltip = "Envoi, réception et dépôt automatiques : Options > Courrier."
        settings:SetScript("OnClick", function()
            UI:ShowPage("options")
            UI.pages.options:ShowSection("mail")
        end)
        self.status = UI:Text(p, 11, C.muted)
        self.status:SetPoint("RIGHT", settings, "LEFT", -12, 0)
        self.status:SetJustifyH("RIGHT")
        self.tabs.send = RuleEditor(self, frames.send, "mail", -46)
        self.tabs.bank = RuleEditor(self, frames.bank, "bank", -46)
        self.tabs.receive = Reception(self, frames.receive, -46)
        UI:OnResize(p, function() UI:RefreshSoon() end) -- raccourcis « Mes persos »
    end,

    Refresh = function(self)
        local t = self.tabs[self.tab]
        if t then t:Refresh() end
        local mail, bank = WK.DB.global.mail, WK.DB.global.bank
        local on = UI:Hex(C.positive) .. T("activé") .. "|r"
        local off = UI:Hex(C.dim) .. T("désactivé") .. "|r"
        if self.tab == "send" then
            self.status:SetText(T("Envoi automatique : ") .. (mail.enabled and on or off))
        elseif self.tab == "bank" then
            self.status:SetText(T("Dépôt automatique : ") .. (bank.enabled and on or off))
        else
            self.status:SetText(T("Prise automatique : ") .. (mail.autoTake and on or off))
        end
    end,
})
