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

-- Sacs par catégorie (vue principale) : { clé, libellé } dans l'ordre d'affichage
local CATS = {
    { "ammo", "Munitions" }, { "metal", "Métaux et pierres" }, { "cook", "Viande et poisson" },
    { "cloth", "Étoffes et cuir" }, { "herb", "Herbes" }, { "ench", "Enchantement" }, { "parts", "Autres composants" },
    { "cons", "Consommables" }, { "gear", "Équipement" }, { "recipe", "Recettes" }, { "quest", "Objets de quête" },
    { "misc", "Divers" },
}
local function catOf(id)
    local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    local classID, subID
    if f then
        local ok, _, _, _, _, _, cl, sub = pcall(f, id)
        if ok then classID, subID = cl, sub end
    end
    if classID == 6 or classID == 11 then return "ammo" end
    if classID == 7 then
        if subID == 7 then return "metal" elseif subID == 8 then return "cook" elseif subID == 5 or subID == 6 then return "cloth"
        elseif subID == 9 then return "herb" elseif subID == 12 then return "ench" end
        return "parts"
    end
    if classID == 5 then return "parts" end
    if classID == 0 then return "cons" end
    if classID == 2 or classID == 4 then return "gear" end
    if classID == 9 then return "recipe" end
    if classID == 12 then return "quest" end
    return "misc"
end
local SLOT, SGAP = 40, 4

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
        self:BuildLocks(p, x0)

        -- sacs par catégorie et leurs cases
        self.bags = UI:Pool(function()
            local b = CreateFrame("Frame", nil, scroll.child)
            UI:Panel(b, 10, C.surface, C.border)
            b.title = UI:Text(b, 12)
            b.title:SetPoint("TOPLEFT", 12, -10)
            b.sub = UI:Text(b, 10, C.muted)
            b.sub:SetPoint("TOPRIGHT", -12, -11)
            b.sub:SetJustifyH("RIGHT")
            return b
        end)
        self.slots = UI:Pool(function()
            local b = CreateFrame("Button", nil, scroll.child)
            b:SetSize(SLOT, SLOT)
            b:SetFrameLevel(scroll.child:GetFrameLevel() + 5)
            b.edge = b:CreateTexture(nil, "BACKGROUND")
            b.edge:SetTexture("Interface\\Buttons\\WHITE8X8")
            b.edge:SetAllPoints()
            b.icon = b:CreateTexture(nil, "ARTWORK")
            b.icon:SetPoint("TOPLEFT", 2, -2); b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
            b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            b.hl = b:CreateTexture(nil, "HIGHLIGHT")
            b.hl:SetTexture("Interface\\Buttons\\WHITE8X8")
            b.hl:SetAllPoints(b.icon)
            b.hl:SetVertexColor(1, 1, 1, 0.15)
            b.n = b:CreateFontString(nil, "OVERLAY")
            b.n:SetFont(UI.FONT, 11, "OUTLINE")
            b.n:SetPoint("BOTTOMRIGHT", -2, 3)
            -- repère BiS : étoile en bas à gauche (or : liste du perso connecté, gris : autre perso)
            b.bisRing = b:CreateTexture(nil, "OVERLAY", nil, 5)
            b.bisRing:SetTexture(UI.MEDIA .. "circle"); b.bisRing:SetSize(17, 17); b.bisRing:SetPoint("BOTTOMLEFT", -3, -3)
            b.bisRing:SetVertexColor(0, 0, 0, 0.9)
            b.bisBadge = b:CreateTexture(nil, "OVERLAY", nil, 6)
            b.bisBadge:SetTexture(UI.MEDIA .. "circle"); b.bisBadge:SetSize(15, 15); b.bisBadge:SetPoint("CENTER", b.bisRing, "CENTER")
            b.bisStar = b:CreateTexture(nil, "OVERLAY", nil, 7)
            b.bisStar:SetTexture(UI.MEDIA .. "star"); b.bisStar:SetSize(10, 10); b.bisStar:SetPoint("CENTER", b.bisRing, "CENTER")
            b.bisStar:SetVertexColor(0.08, 0.06, 0.07, 1)
            b:SetScript("OnEnter", function(s)
                local it = s.it
                if not it then return end
                WK.UI:TooltipOwner(s, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(it.id)
                GameTooltip:AddLine(" ")
                GameTooltip:AddDoubleLine(T("Total"), tostring(it.total), 0.8, 0.8, 0.8, 1, 1, 1)
                local parts = {}
                for who, n in pairs(it.per) do table.insert(parts, { who, n }) end
                table.sort(parts, function(a, c) return a[2] > c[2] end)
                for i, v in ipairs(parts) do
                    if i > 8 then GameTooltip:AddLine(string.format(T("+ %d autre(s)"), #parts - 8), 0.6, 0.6, 0.6) break end
                    GameTooltip:AddDoubleLine(v[1], tostring(v[2]), 0.62, 0.64, 0.67, 1, 1, 1)
                end
                local price = WK.modules.Value:Price(it.id)
                if price > 0 then
                    GameTooltip:AddDoubleLine(T("Valeur"), string.format(T("%s l'unité · %s"), UI:GoldText(price), UI:GoldText(price * it.total)), 0.8, 0.8, 0.8, 1, 0.82, 0.3)
                end
                GameTooltip:AddLine(T("Maj+clic : lien dans le chat"), 0.5, 0.5, 0.5)
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            b:SetScript("OnClick", function(s)
                local _, _, _, _, _, link = UI:ItemInfo(s.it and s.it.id)
                if IsModifiedClick("CHATLINK") and link then WK.InsertChatLink(link) end
            end)
            return b
        end)
        UI:OnResize(scroll, function() if self.lastList and scroll:IsVisible() then self:LayoutBags() end end)

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
                    r.value:SetText(T("env.") .. " " .. UI:GoldText(e.value))
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
            self.countText:SetText(string.format(T("%d objets · env. %s à revendre"), #list, UI:GoldText(total)))
        else
            self.countText:SetText(string.format(#list > 1 and T("%d objets") or T("%d objet"), #list))
        end
    end,

    -- Objets verrouillés (Modules/ItemLock.lua) : liste, règles automatiques, réglages
    BuildLocks = function(self, p, x0)
        local IL = WK.modules.ItemLock
        local cfg = IL:Config()
        local pane = UI:Scroll(p)
        pane:SetPoint("TOPLEFT", x0, 0)
        pane:SetPoint("BOTTOMRIGHT")
        pane:Hide()
        self.lockPane = pane
        local root = pane.child
        -- liste
        local list = UI:Card(root, T("Objets verrouillés"), " ")
        self.lockList = list
        local all = UI:Button(list, "Tout déverrouiller", nil, 24, "ghost")
        all:SetPoint("TOPRIGHT", -10, -9)
        all.tooltip = "Maj + clic : enlève tous les verrous posés à la main (les règles restent)."
        all:SetScript("OnClick", function() if IsShiftKeyDown() then IL:UnlockAll() else WK:Print(T("Maj + clic pour tout déverrouiller.")) end end)
        self.lockRows = UI:Pool(function()
            local r = CreateFrame("Button", nil, list)
            r:SetHeight(32)
            r.icon = UI:RoundIcon(r, 22)
            r.icon:SetPoint("LEFT", 4, 0)
            r.name = UI:Text(r, 12)
            r.name:SetPoint("LEFT", 34, 0)
            r.tag = UI:Badge(r, "")
            r.tag:SetPoint("LEFT", r.name, "RIGHT", 8, 0)
            r.del = UI:IconButton(r, "close", 22, "Déverrouiller", "accent")
            r.del:SetPoint("RIGHT", -2, 0)
            r.who = UI:Text(r, 10, C.muted)
            r.who:SetPoint("RIGHT", r.del, "LEFT", -10, 0)
            r.who:SetJustifyH("RIGHT")
            r.line = r:CreateTexture(nil, "BACKGROUND")
            r.line:SetHeight(1)
            r.line:SetPoint("BOTTOMLEFT"); r.line:SetPoint("BOTTOMRIGHT")
            r:SetScript("OnEnter", function(s)
                WK.UI:TooltipOwner(s, "ANCHOR_RIGHT")
                if GameTooltip.SetItemByID then GameTooltip:SetItemByID(s.id) end
                GameTooltip:Show()
            end)
            r:SetScript("OnLeave", function() GameTooltip:Hide() end)
            return r
        end)
        self.lockEmpty = UI:Text(list, 11, C.muted)
        self.lockEmpty:SetPoint("TOPLEFT", 16, -46)
        self.lockEmpty:SetText(string.format(T("Aucun objet verrouillé. %s sur un objet dans tes sacs pour le verrouiller."),
            UI.ItemLockKeyLabel and UI.ItemLockKeyLabel() or T("Alt + clic")))
        -- règles
        local rules = UI:Card(root, T("Règles automatiques"))
        self.lockRules = rules
        local y = -40
        local function rule(label, desc, key)
            UI:SettingRow(rules, y, label, desc, UI:Toggle(rules, function() return cfg.rules[key] end,
                function(v) cfg.rules[key] = v; IL:RuleChanged() end), 80)
            y = y - 46
        end
        rule("Objets épiques et plus", nil, "epic")
        rule("Objets de ma liste d'envies", "Donjons > Mes envies, tous les persos.", "wish")
        rule("Recettes", "Celles d'un métier qu'un de tes persos a appris.", "recipes")
        rule("Objets de quête", nil, "quest")
        rule("Valeur HV au-dessus d'un seuil", "Prix relevé par le scan de l'hôtel des ventes.", "value")
        UI:SettingRow(rules, y, "Seuil de valeur HV", nil, UI:Slider(rules, 220, 1, 100, 1,
            function() return math.floor((cfg.valueMin or 50000) / 10000) end,
            function(v) cfg.valueMin = v * 10000; IL:RuleChanged() end, "%d po"), 240)
        y = y - 46
        rules:SetHeight(-y + 8)
        -- réglages
        local sets = UI:Card(root, T("Protection"))
        self.lockSets = sets
        local keyDd = UI:Dropdown(sets, 200, 30, { { "alt", T("Alt + clic") }, { "ctrl", T("Ctrl + clic") }, { "shiftalt", T("Maj + Alt + clic") },
            { "ctrlalt", T("Ctrl + Alt + clic") }, { "ctrlshift", T("Ctrl + Maj + clic") },
            { "mid", T("Clic molette") }, { "altmid", T("Alt + clic molette") }, { "ctrlmid", T("Ctrl + clic molette") } },
            function(v)
                cfg.key = v
                if self.lockEmpty and UI.ItemLockKeyLabel then
                    self.lockEmpty:SetText(string.format(T("Aucun objet verrouillé. %s sur un objet dans tes sacs pour le verrouiller."), UI.ItemLockKeyLabel()))
                end
            end)
        keyDd:Select(cfg.key or "alt")
        UI:SettingRow(sets, -40, "Touche pour verrouiller", "Sur un objet dans les sacs du jeu.", keyDd, 200)
        UI:SettingRow(sets, -86, "Racheter un objet verrouillé vendu par erreur", "Aussitôt, chez le marchand (onglet de rachat).",
            UI:Toggle(sets, function() return cfg.rebuy end, function(v) cfg.rebuy = v end), 80)
        UI:SettingRow(sets, -132, "Confirmer une vente chère", "Objet non verrouillé qui vaut bien plus à l'HV qu'au marchand.",
            UI:Toggle(sets, function() return cfg.confirm end, function(v) cfg.confirm = v end), 80)
        UI:SettingRow(sets, -178, "Écart HV / marchand", "Demander si le prix HV vaut au moins ce multiple du prix marchand.",
            UI:Slider(sets, 220, 2, 20, 1, function() return cfg.ratio or 5 end, function(v) cfg.ratio = v end, "x %d"), 240)
        sets:SetHeight(232)
        UI:OnResize(pane, function() if self.char == "locks" then self:RefreshLocks() end end)
    end,

    RefreshLocks = function(self)
        local IL = WK.modules.ItemLock
        local W = math.max(400, (self.lockPane:GetWidth() or 600) - 14)
        self.lockPane.child:SetWidth(W)
        local list = IL:List()
        local n = 0
        for _, e in ipairs(list) do if e.reason == "manual" then n = n + 1 end end
        if self.lockList.subtitle then self.lockList.subtitle:SetText(string.format(T("%d objets · %d à la main"), #list, n)) end
        self.lockRows:Reset()
        local y = 44
        local r1, g1, b1 = UI:Accent()
        for _, e in ipairs(list) do
            local r = self.lockRows:Get()
            r.id = e.id
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 12, -y); r:SetPoint("TOPRIGHT", -12, -y)
            local name, icon, qr, qg, qb = UI:ItemInfo(e.id)
            r.icon:SetTexture(icon)
            r.name:SetText(name); r.name:SetTextColor(qr, qg, qb)
            if e.reason == "manual" then r.tag:Set(T("à la main")) else r.tag:Set(e.reason, C.rule) end
            r.who:SetText(#e.who > 0 and table.concat(e.who, ", ") or T("pas sur le compte"))
            r.del:SetShown(e.reason == "manual")
            r.del:SetScript("OnClick", function() IL:Unlock(e.id) end)
            r.line:SetColorTexture(unpack(C.border))
            y = y + 34
        end
        self.lockEmpty:SetShown(#list == 0)
        if #list == 0 then y = y + 24 end
        self.lockList:ClearAllPoints(); self.lockList:SetPoint("TOPLEFT", 0, 0); self.lockList:SetSize(W, y + 10)
        local ly = y + 10 + 12
        self.lockRules:ClearAllPoints(); self.lockRules:SetPoint("TOPLEFT", 0, -ly); self.lockRules:SetWidth(W)
        ly = ly + self.lockRules:GetHeight() + 12
        self.lockSets:ClearAllPoints(); self.lockSets:SetPoint("TOPLEFT", 0, -ly); self.lockSets:SetWidth(W)
        ly = ly + self.lockSets:GetHeight() + 10
        self.lockPane:SetContentHeight(ly)
    end,

    -- Onglets : tout le compte, chaque personnage, banque de bataillon.
    RefreshTabs = function(self)
        local chars = WK.DB.global.characters
        local special = { spread = true, old = true, locks = true }
        if self.char ~= "all" and self.char ~= "warband" and not special[self.char] and not chars[self.char] then self.char = "all" end
        -- Tout le compte, puis les vues d'aide au rangement, puis chaque perso et le bataillon.
        local entries = { { key = "all" }, { key = "spread" }, { key = "old" }, { key = "locks" } }
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
                local glyphs = { all = "users", warband = "bag", spread = "mail", old = "clock", locks = "lock" }
                b.glyph:SetTexture(UI.MEDIA .. glyphs[e.key])
                b.glyph:SetVertexColor(UI:Accent())
                local names = { all = "Tout le compte", warband = "Banque de bataillon", spread = "À regrouper", old = "Oubliés en banque", locks = "Objets verrouillés" }
                b.name:SetText(T(names[e.key]))
                b.name:SetTextColor(unpack(C.text))
                if e.key == "warband" then
                    local n = countItems(wb.items)
                    b.sub:SetText(string.format(T("%d objets"), n))
                elseif e.key == "spread" then
                    local n = #WK.modules.Inventory:Spread()
                    b.sub:SetText(string.format(T("%d objets dispersés"), n))
                elseif e.key == "locks" then
                    local n = 0
                    for _ in pairs(WK.modules.ItemLock:Manual()) do n = n + 1 end
                    b.sub:SetText(string.format(T("%d à la main"), n))
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
        self.bags:Reset(); self.slots:Reset(); self.lastList = nil
        local chars = WK.DB.global.characters
        local sel = self.char
        self.oldSeg:SetShown(sel == "old")
        -- objets verrouillés : leur propre panneau à la place de la liste
        local locks = sel == "locks"
        self.lockPane:SetShown(locks)
        for _, w in ipairs({ self.search, self.scroll, self.header, self.info, self.countText }) do w:SetShown(not locks) end
        if locks then
            self.whereSeg:Hide(); self.empty:Hide()
            return self:RefreshLocks()
        end
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
        local listValue = 0
        for _, it in ipairs(list) do listValue = listValue + WK.modules.Value:Price(it.id) * it.total end
        self.lastList = list
        self:LayoutBags()
        self.empty:SetShown(#list == 0)
        self.empty:SetText(self.query ~= "" and T("Aucun objet ne correspond à la recherche.") or T("Rien ici pour l'instant."))

        self.countText:SetText(string.format(#list > 1 and T("%d objets") or T("%d objet"), #list)
            .. (listValue > 0 and ("  ·  " .. T("env.") .. " " .. UI:GoldText(listValue)) or ""))
    end,

    -- Sacs par catégorie, posés en colonnes (le sac va dans la colonne la moins haute)
    LayoutBags = function(self)
        local list = self.lastList
        if not list then return end
        self.bags:Reset(); self.slots:Reset()
        local groups = {}
        for _, it in ipairs(list) do
            local k = catOf(it.id)
            groups[k] = groups[k] or {}
            table.insert(groups[k], it)
        end
        local W = math.max(400, self.scroll:GetWidth() or 800)
        self.scroll.child:SetWidth(W)
        local ncol = W >= 1000 and 3 or 2
        local bw = math.floor((W - (ncol - 1) * GAP) / ncol)
        local per = math.max(4, math.floor((bw - 24 + SGAP) / (SLOT + SGAP)))
        local heights = {}
        for i = 1, ncol do heights[i] = 0 end
        local V = WK.modules.Value
        for _, cat in ipairs(CATS) do
            local g = groups[cat[1]]
            if g then
                local rows = math.ceil(#g / per)
                local h = 36 + rows * SLOT + (rows - 1) * SGAP + 12
                local col = 1
                for i = 2, ncol do if heights[i] < heights[col] then col = i end end
                local x, y = (col - 1) * (bw + GAP), heights[col]
                heights[col] = y + h + GAP
                local bag = self.bags:Get()
                bag:ClearAllPoints(); bag:SetPoint("TOPLEFT", x, -y); bag:SetSize(bw, h)
                bag.title:SetText(T(cat[2]))
                local val = 0
                for _, it in ipairs(g) do val = val + V:Price(it.id) * it.total end
                bag.sub:SetText(#g .. (val > 0 and ("  ·  " .. T("env.") .. " " .. UI:GoldText(val)) or ""))
                for i, it in ipairs(g) do
                    local sl = self.slots:Get()
                    local r, c = math.floor((i - 1) / per), (i - 1) % per
                    sl:ClearAllPoints()
                    sl:SetPoint("TOPLEFT", x + 12 + c * (SLOT + SGAP), -(y + 36 + r * (SLOT + SGAP)))
                    sl.it = it
                    sl.icon:SetTexture(it.icon)
                    local q = it.color or { 0.4, 0.4, 0.4 }
                    local plain = q[1] > 0.95 and q[2] > 0.95 and q[3] > 0.95
                    sl.edge:SetVertexColor(plain and C.border[1] or q[1], plain and C.border[2] or q[2], plain and C.border[3] or q[3], 1)
                    local mark = WK:FeatureOn("characters") and WK.modules.BiS and WK.modules.BiS:Mark(it.id)
                    sl.bisRing:SetShown(mark and true or false); sl.bisBadge:SetShown(mark and true or false); sl.bisStar:SetShown(mark and true or false)
                    if mark == "mine" then sl.bisBadge:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 1) elseif mark then sl.bisBadge:SetVertexColor(C.silver[1], C.silver[2], C.silver[3], 1) end
                    sl.n:SetText(it.total > 1 and (it.total > 9999 and "9999+" or tostring(it.total)) or "")
                end
            end
        end
        local maxH = 0
        for i = 1, ncol do maxH = math.max(maxH, heights[i]) end
        self.scroll:SetContentHeight(maxH)
    end,
})
