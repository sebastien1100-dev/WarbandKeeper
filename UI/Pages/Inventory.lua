local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

local MAX_ROWS = 150
local TABS_W = 214
local GAP = 12
local WHERE = { "bags", "bank", "mailbox" }
local WHERE_LABEL = { bags = "Sacs", bank = "Banque", mailbox = "Courrier" }

-- Contenu d'un emplacement ("bags", "bank", "mailbox") d'un personnage.
local function listOf(c, where)
    if where == "mailbox" then return c.mailbox and c.mailbox.items end
    return c[where]
end

local function countItems(t)
    local n, kinds = 0, 0
    for _, k in pairs(t or {}) do n = n + k; kinds = kinds + 1 end
    return n, kinds
end

UI:RegisterPage({
    key = "inventory", order = 3, nav = "Inventaire",
    title = "Inventaire",
    subtitle = "Sacs, banques et courrier, par personnage ou pour tout le compte. Maj + clic sur une ligne pour lier l'objet.",

    Build = function(self, p)
        self.where = "all"
        self.query = ""
        local cfg = WK.DB.global.settings.ui
        self.char = cfg.invChar or "all"

        -- Onglets (colonne de gauche) ------------------------------------------
        local tabsCard = UI:Card(p)
        tabsCard:SetWidth(TABS_W)
        tabsCard:SetPoint("TOPLEFT")
        tabsCard:SetPoint("BOTTOMLEFT")
        local ts = UI:Scroll(tabsCard)
        ts:SetPoint("TOPLEFT", 8, -8)
        ts:SetPoint("BOTTOMRIGHT", -6, 8)
        self.tabScroll = ts
        self.tabs = UI:Pool(function()
            local b = CreateFrame("Button", nil, ts.child)
            b:SetHeight(42)
            b.bg = UI:Rounded(b, 10, 0, "BACKGROUND", 1)
            b.bar = CreateFrame("Frame", nil, b)
            b.bar:SetSize(3, 18)
            b.bar:SetPoint("LEFT", 0, 0)
            b.barTex = UI:Rounded(b.bar, 1.5, 0, "ARTWORK", 1)
            b.icon = UI:RoundIcon(b, 24)
            b.icon:SetPoint("LEFT", 10, 0)
            b.glyph = UI:Icon(b, "users", 16)
            b.glyph:SetPoint("CENTER", b.icon, "CENTER")
            b.name = UI:Text(b, 12)
            b.name:SetPoint("TOPLEFT", 42, -7)
            b.name:SetPoint("TOPRIGHT", -8, -7)
            b.sub = UI:Text(b, 10, C.muted)
            b.sub:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -3)
            b.sub:SetPoint("TOPRIGHT", b.name, "BOTTOMRIGHT", 0, -3)
            function b:Paint()
                local sel = self.selected
                self.bg:SetColor(unpack(sel and C.surface2 or C.hover))
                self.bg:SetShown(sel or self.hover)
                self.bar:SetShown(sel)
                self.barTex:SetColor(UI:Accent())
            end
            b:SetScript("OnEnter", function(s) s.hover = true; s:Paint() end)
            b:SetScript("OnLeave", function(s) s.hover = false; s:Paint() end)
            b:SetScript("OnClick", function(s)
                self.char = s.key
                cfg.invChar = s.key
                self:Refresh()
            end)
            return b
        end)

        -- Barre d'outils (droite) ----------------------------------------------------
        local x0 = TABS_W + GAP
        local search = UI:Input(p, 280, 34, "Rechercher un objet...", "search")
        search:SetPoint("TOPLEFT", x0, 0)
        self.search = search
        search.onChange = function(text) self.query = string.lower(text or ""); self:Refresh() end

        self.whereSeg = UI:Segmented(p, { { "all", "Tout" }, { "bags", "Sacs" }, { "bank", "Banque" }, { "mailbox", "Courrier" } },
            function(key) self.where = key; self:Refresh() end, 34)
        self.whereSeg:SetPoint("TOPRIGHT")
        self.whereSeg:Select("all")
        -- Objets oubliés : depuis combien de jours
        self.oldDays = 14
        self.oldSeg = UI:Segmented(p, { { 7, "7 j" }, { 14, "14 j" }, { 30, "30 j" } },
            function(d) self.oldDays = d; self:Refresh() end, 34)
        self.oldSeg:SetPoint("TOPRIGHT")
        self.oldSeg:Select(14)
        self.oldSeg:Hide()

        self.header = UI:Text(p, 14)
        self.header:SetPoint("TOPLEFT", x0 + 2, -48)
        self.info = UI:Text(p, 11, C.muted)
        self.info:SetPoint("BOTTOMLEFT", self.header, "BOTTOMRIGHT", 10, 1)
        self.countText = UI:Text(p, 11, C.muted)
        self.countText:SetPoint("TOPRIGHT", -4, -50)
        self.countText:SetJustifyH("RIGHT")

        local scroll = UI:Scroll(p)
        scroll:SetPoint("TOPLEFT", x0, -74)
        scroll:SetPoint("BOTTOMRIGHT")
        self.scroll = scroll
        self.empty = UI:Text(p, 12, C.muted)
        self.empty:SetPoint("CENTER", scroll, "CENTER")

        self.rows = UI:Pool(function()
            local r = CreateFrame("Button", nil, scroll.child)
            r:SetHeight(46)
            UI:Panel(r, 12, C.surface, C.border)
            r.icon = UI:RoundIcon(r, 28)
            r.icon:SetPoint("LEFT", 12, 0)
            r.name = UI:Text(r, 12)
            r.name:SetPoint("TOPLEFT", 52, -9)
            r.name:SetPoint("TOPRIGHT", -210, -9)
            r.detail = UI:Text(r, 10, C.muted)
            r.detail:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -4)
            r.detail:SetPoint("TOPRIGHT", r.name, "BOTTOMRIGHT", 0, -4)
            r.total = UI:Text(r, 15)
            r.total:SetPoint("TOPRIGHT", -16, -8)
            r.total:SetJustifyH("RIGHT")
            r.value = UI:Text(r, 10, C.muted)
            r.value:SetPoint("TOPRIGHT", r.total, "BOTTOMRIGHT", 0, -3)
            r.value:SetJustifyH("RIGHT")
            -- « Regrouper » (vue des objets dispersés)
            r.action = UI:Button(r, "Regrouper", nil, 26, "secondary", "mail")
            r.action:SetPoint("RIGHT", -96, 0)
            r.action:Hide()
            r.action:SetScript("OnClick", function(b)
                local e = b.entry
                if not e then return end
                local tc = WK.DB.global.characters[e.target]
                if WK.modules.Mail:AddRule(e.itemID, WK.modules.Mail:MailName(tc), 0) then self:Refresh() end
            end)
            r:SetScript("OnEnter", function(row)
                row.bg:SetColor(unpack(C.surface2))
                WK.UI:TooltipOwner(row, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(row.itemID)
                GameTooltip:Show()
            end)
            r:SetScript("OnLeave", function(row)
                row.bg:SetColor(unpack(C.surface))
                GameTooltip:Hide()
            end)
            r:SetScript("OnClick", function(row)
                local _, _, _, _, _, link = UI:ItemInfo(row.itemID)
                if IsModifiedClick("CHATLINK") and link then WK.InsertChatLink(link) end
            end)
            return r
        end)
    end,

    -- Vues d'aide au rangement : objets dispersés (à regrouper) et objets oubliés en banque.
    RefreshHelp = function(self, sel)
        local Inv, V = WK.modules.Inventory, WK.modules.Value
        local chars = WK.DB.global.characters
        local function who(key)
            if key == "warband" then return T("Bataillon") end
            local c = chars[key]
            local r, g, b = UI:ClassColor(c and c.class)
            return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, WK:CharName(c, key))
        end
        local list, trackedSince
        if sel == "spread" then
            list = Inv:Spread()
            self.header:SetText(T("À regrouper"))
            self.info:SetText(T("le même objet chez plusieurs persos"))
        else
            list, trackedSince = Inv:Forgotten(self.oldDays)
            self.header:SetText(T("Oubliés en banque"))
            self.info:SetText(trackedSince and string.format(T("suivi depuis le %s"), date("%d/%m", trackedSince))
                or T("suivi à partir de la prochaine ouverture des banques"))
        end
        self.header:SetTextColor(unpack(C.text))
        self.rows:Reset()
        local y, total = 0, 0
        for i, e in ipairs(list) do
            if i > MAX_ROWS then break end
            if self.query == "" or string.find(string.lower((UI:ItemInfo(e.itemID)) or ""), self.query, 1, true) then
                local r = self.rows:Get()
                r.itemID = e.itemID
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", 0, -y)
                r:SetPoint("TOPRIGHT", 0, -y)
                local name, icon, qr, qg, qb = UI:ItemInfo(e.itemID)
                r.icon:SetTexture(icon)
                r.name:SetText(name)
                r.name:SetTextColor(qr, qg, qb)
                if sel == "spread" then
                    local parts = {}
                    for _, h in ipairs(e.holders) do table.insert(parts, who(h.key) .. " " .. h.n) end
                    r.detail:SetText(table.concat(parts, "  ·  "))
                    r.total:SetText(tostring(e.total))
                    if e.rule then
                        r.value:SetText(string.format(T("déjà envoyé à %s"), who(e.target)))
                        r.action:Hide()
                    else
                        r.value:SetText(string.format(T("vers %s"), who(e.target)))
                        r.action.entry = e
                        r.action.tooltip = string.format(T("Crée une règle d'envoi : tes autres persos posteront cet objet à %s."), WK:CharName(chars[e.target], e.target))
                        r.action:Show()
                    end
                else
                    r.action:Hide()
                    r.detail:SetText(string.format(T("%s · depuis %s"), who(e.key), UI:Ago(e.since)))
                    r.total:SetText(tostring(e.n))
                    r.value:SetText("~ " .. UI:GoldText(e.value))
                    total = total + e.value
                end
                y = y + 52
            end
        end
        self.scroll:SetContentHeight(y)
        self.empty:SetShown(y == 0)
        self.empty:SetText(sel == "spread" and T("Rien à regrouper : chaque objet est chez un seul perso.")
            or T("Rien d'oublié : aucun objet de valeur ne dort en banque depuis aussi longtemps."))
        if sel == "old" and total > 0 then
            self.countText:SetText(string.format(T("%d objets · ~ %s à revendre"), #list, UI:GoldText(total)))
        else
            self.countText:SetText(string.format(#list > 1 and T("%d objets") or T("%d objet"), #list))
        end
    end,

    -- Onglets : tout le compte, chaque personnage, banque de bataillon.
    RefreshTabs = function(self)
        local chars = WK.DB.global.characters
        local special = { spread = true, old = true }
        if self.char ~= "all" and self.char ~= "warband" and not special[self.char] and not chars[self.char] then self.char = "all" end
        -- Tout le compte, puis les vues d'aide au rangement, puis chaque perso et le bataillon.
        local entries = { { key = "all" }, { key = "spread" }, { key = "old" } }
        for _, e in ipairs(UI:SortedCharacters()) do table.insert(entries, { key = e.key, c = e.c }) end
        local wb = WK.DB.global.warbank
        if wb then table.insert(entries, { key = "warband" }) end

        self.tabs:Reset()
        local y = 0
        local accountTotal = 0
        for _, e in ipairs(entries) do
            local b = self.tabs:Get()
            b.key = e.key
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", 0, -y)
            b:SetPoint("TOPRIGHT", 0, -y)
            if e.c then
                local n = 0
                for _, where in ipairs(WHERE) do n = n + countItems(listOf(e.c, where)) end
                accountTotal = accountTotal + n
                b.icon:Show(); b.glyph:Hide()
                UI:SetCharIcon(b.icon, e.c, e.key)
                b.name:SetText(WK:CharName(e.c, e.key))
                b.name:SetTextColor(UI:ClassColor(e.c.class))
                b.sub:SetText(string.format(T("%d objets"), n))
                e.button = b
            else
                b.icon:Hide(); b.glyph:Show()
                local glyphs = { all = "users", warband = "bag", spread = "mail", old = "clock" }
                b.glyph:SetTexture(UI.MEDIA .. glyphs[e.key])
                b.glyph:SetVertexColor(UI:Accent())
                local names = { all = "Tout le compte", warband = "Banque de bataillon", spread = "À regrouper", old = "Oubliés en banque" }
                b.name:SetText(T(names[e.key]))
                b.name:SetTextColor(unpack(C.text))
                if e.key == "warband" then
                    local n = countItems(wb.items)
                    b.sub:SetText(string.format(T("%d objets"), n))
                elseif e.key == "spread" then
                    local n = #WK.modules.Inventory:Spread()
                    b.sub:SetText(string.format(T("%d objets dispersés"), n))
                elseif e.key == "old" then
                    local n = #WK.modules.Inventory:Forgotten(self.oldDays)
                    b.sub:SetText(string.format(T("%d depuis %d j"), n, self.oldDays))
                end
                e.button = b
            end
            b.selected = (self.char == e.key)
            b:Paint()
            y = y + 46
        end
        -- Total du compte sous « Tout le compte ».
        local all = entries[1].button
        local wbn = wb and countItems(wb.items) or 0
        all.sub:SetText(string.format(T("%d objets"), accountTotal + wbn))
        self.tabScroll:SetContentHeight(y)
    end,

    Refresh = function(self)
        self:RefreshTabs()
        local chars = WK.DB.global.characters
        local sel = self.char
        self.oldSeg:SetShown(sel == "old")
        if sel == "spread" or sel == "old" then
            self.whereSeg:Hide()
            return self:RefreshHelp(sel)
        end
        for _, r in ipairs(self.rows.items) do r.action:Hide() end
        local items = {}
        local function add(id, n, label)
            local it = items[id]
            if not it then it = { id = id, total = 0, per = {} }; items[id] = it end
            it.total = it.total + n
            it.per[label] = (it.per[label] or 0) + n
        end

        -- Filtres d'emplacement : pas de sacs ni de courrier pour la banque de bataillon.
        self.whereSeg:SetShown(sel ~= "warband")
        local wb = WK.DB.global.warbank
        if sel == "warband" then
            for id, n in pairs(wb and wb.items or {}) do add(id, n, T("Bataillon")) end
        elseif sel == "all" then
            for key, c in pairs(chars) do
                for _, where in ipairs(WHERE) do
                    if self.where == "all" or self.where == where then
                        for id, n in pairs(listOf(c, where) or {}) do add(id, n, WK:CharName(c, key)) end
                    end
                end
            end
            if wb and (self.where == "all" or self.where == "bank") then
                for id, n in pairs(wb.items) do add(id, n, T("Bataillon")) end
            end
        else
            -- Un personnage : le détail indique où se trouve l'objet.
            local c = chars[sel]
            for _, where in ipairs(WHERE) do
                if self.where == "all" or self.where == where then
                    for id, n in pairs(listOf(c, where) or {}) do add(id, n, T(WHERE_LABEL[where])) end
                end
            end
        end

        -- En-tête de l'onglet
        if sel == "all" then
            self.header:SetText(T("Tout le compte"))
            self.header:SetTextColor(unpack(C.text))
            self.info:SetText("")
        elseif sel == "warband" then
            self.header:SetText(T("Banque de bataillon"))
            self.header:SetTextColor(unpack(C.text))
            self.info:SetText(wb and wb.scanned and UI:Ago(wb.scanned) or "")
        else
            local c = chars[sel]
            self.header:SetText(WK:CharName(c, sel))
            self.header:SetTextColor(UI:ClassColor(c.class))
            local parts = {}
            if c.totalSlots and c.totalSlots > 0 then
                table.insert(parts, string.format(T("sacs %d / %d"), c.totalSlots - (c.freeSlots or 0), c.totalSlots))
            end
            table.insert(parts, c.bankScanned and (T("banque") .. " " .. UI:Ago(c.bankScanned)) or T("banque jamais ouverte"))
            local box = c.mailbox
            if box and (box.count or 0) > 0 then
                table.insert(parts, string.format(box.count > 1 and T("%d lettres") or T("%d lettre"), box.count))
            end
            self.info:SetText(table.concat(parts, "  ·  "))
        end

        local list = {}
        for id, it in pairs(items) do
            local name, icon, r, g, b = UI:ItemInfo(id)
            if self.query == "" or string.find(string.lower(name), self.query, 1, true) then
                it.name, it.icon, it.color = name, icon, { r, g, b }
                table.insert(list, it)
            end
        end
        table.sort(list, function(a, b)
            if a.total ~= b.total then return a.total > b.total end
            return a.name < b.name
        end)

        self.rows:Reset()
        local y = 0
        local listValue = 0
        for _, it in ipairs(list) do listValue = listValue + WK.modules.Value:Price(it.id) * it.total end
        for i, it in ipairs(list) do
            if i > MAX_ROWS then break end
            local r = self.rows:Get()
            r.itemID = it.id
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -y)
            r:SetPoint("TOPRIGHT", 0, -y)
            r.icon:SetTexture(it.icon)
            r.name:SetText(it.name)
            r.name:SetTextColor(unpack(it.color))
            local parts = {}
            for who, n in pairs(it.per) do table.insert(parts, { who, n }) end
            table.sort(parts, function(a, b) return a[2] > b[2] end)
            for k, v in ipairs(parts) do parts[k] = v[1] .. " " .. v[2] end
            r.detail:SetText(table.concat(parts, "  ·  "))
            r.total:SetText(tostring(it.total))
            local V = WK.modules.Value
            if V:ShowBoth() then
                local ah, vendor = V:Prices(it.id)
                local parts = {}
                if ah then table.insert(parts, T("HV") .. " " .. UI:GoldText(ah * it.total)) end
                if vendor > 0 then table.insert(parts, T("marchand") .. " " .. UI:GoldText(vendor * it.total)) end
                r.value:SetText(table.concat(parts, "  ·  "))
            else
                local price = V:Price(it.id)
                r.value:SetText(price > 0 and ("~ " .. UI:GoldText(price * it.total)) or "")
            end
            y = y + 52
        end
        self.scroll:SetContentHeight(y)
        self.empty:SetShown(#list == 0)
        self.empty:SetText(self.query ~= "" and T("Aucun objet ne correspond à la recherche.") or T("Rien ici pour l'instant."))

        if #list > MAX_ROWS then
            self.countText:SetText(string.format(T("%d objets (affichage limité à %d, affine ta recherche)"), #list, MAX_ROWS))
        else
            self.countText:SetText(string.format(#list > 1 and T("%d objets") or T("%d objet"), #list)
                .. (listValue > 0 and ("  ·  ~ " .. UI:GoldText(listValue)) or ""))
        end
    end,
})
