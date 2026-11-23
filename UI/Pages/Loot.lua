local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

local LEFT_W = 240
local BANNER_H = 60
local PROF_H = 192
local GAP = 12
local QUALITIES = {
    { 0, "Médiocre (gris)" }, { 1, "Commune (blanc)" }, { 2, "Inhabituelle (vert)" },
    { 3, "Rare (bleu)" }, { 4, "Épique (violet)" }, { 99, "Aucune (listes et catégories)" },
}

local function Loot() return WK.modules.Loot end

local function autoLabel(a)
    a = a or {}
    if a.kind == "zone" then return a.value or "?" end
    if a.kind == "party" then return T("donjon") end
    if a.kind == "raid" then return T("raid") end
    if a.kind == "pvp" then return T("JcJ") end
    if a.kind == "farm" then return T("session de farm") end
    return nil
end

-- Liste d'objets (« toujours » ou « jamais ») avec champ d'ajout.
local function ItemList(page, parent, title, field)
    local card = UI:Card(parent, title)
    local hint = UI:Text(card, 10, C.dim)
    hint:SetPoint("TOPRIGHT", -14, -16)
    hint:SetJustifyH("RIGHT")
    hint:SetText("Maj + clic sur un objet")
    local input = UI:Input(card, 10, 30, "Objet ou ID")
    input:SetPoint("TOPLEFT", 12, -40)
    input:SetPoint("TOPRIGHT", -50, -40)
    input.edit.acceptLinks = true
    local add = UI:IconButton(card, "plus", 30, "Ajouter")
    add:SetPoint("TOPRIGHT", -12, -40)
    local function doAdd()
        local id = WK:ParseItemID(input:GetText())
        local p = Loot():Get(page.sel)
        if id and p then
            p[field][id] = true
            if field == "always" then p.never[id] = nil else p.always[id] = nil end
            input:SetText("")
            page:Refresh()
        end
    end
    add:SetScript("OnClick", doAdd)
    input.onEnter = doAdd
    local scroll = UI:Scroll(card)
    scroll:SetPoint("TOPLEFT", 10, -78)
    scroll:SetPoint("BOTTOMRIGHT", -8, 8)
    local rows = UI:Pool(function()
        local r = CreateFrame("Frame", nil, scroll.child)
        r:SetHeight(32)
        r.bg = UI:Rounded(r, 9, 0, "BACKGROUND", 1)
        r.bg:SetColor(unpack(C.surface2))
        r.icon = UI:RoundIcon(r, 20)
        r.icon:SetPoint("LEFT", 6, 0)
        r.name = UI:Text(r, 12)
        r.name:SetPoint("LEFT", 32, 0)
        r.name:SetPoint("RIGHT", -34, 0)
        r.del = UI:IconButton(r, "trash", 24, "Retirer", true)
        r.del:SetPoint("RIGHT", -4, 0)
        r.del:SetScript("OnClick", function(b)
            local p = Loot():Get(page.sel)
            if p then p[field][b.itemID] = nil; page:Refresh() end
        end)
        return r
    end)
    local box = { card = card }
    function box:Refresh(p)
        rows:Reset()
        local ids = {}
        for id in pairs(p and p[field] or {}) do table.insert(ids, id) end
        table.sort(ids, function(a, b) return UI:ItemInfo(a) < UI:ItemInfo(b) end)
        local y = 0
        for _, id in ipairs(ids) do
            local r = rows:Get()
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -y)
            r:SetPoint("TOPRIGHT", 0, -y)
            local name, icon, qr, qg, qb = UI:ItemInfo(id)
            r.icon:SetTexture(icon)
            r.name:SetText(name)
            r.name:SetTextColor(qr, qg, qb)
            r.del.itemID = id
            y = y + 36
        end
        scroll:SetContentHeight(y)
    end
    return box
end

UI:RegisterPage({
    key = "loot", order = 5.7, nav = "Filtre de loot",
    title = "Loot",
    subtitle = "Filtres de ramassage par situation. Maj en ouvrant un butin : tout est laissé à ta main.",

    Build = function(self, p)
        local L = Loot()
        self.sel = self.sel or L:EffectiveIndex()
        local d = WK.DB.global.loot

        -- Bandeau du haut : filtre activé ou non (le réglage le plus important) ---------
        local banner = UI:Card(p)
        banner:SetHeight(BANNER_H)
        banner:SetPoint("TOPLEFT")
        banner:SetPoint("TOPRIGHT")
        self.banner = banner
        self.bannerIcon = UI:Icon(banner, "filter", 22)
        self.bannerIcon:SetPoint("LEFT", 18, 0)
        self.enable = UI:Toggle(banner, function() return d.enabled end, function(v) d.enabled = v; L:CheckAuto(); self:Refresh() end)
        -- Ligne de réglage (trouvable par la recherche) : son libellé sert de titre au bandeau.
        local bt = UI:SettingRow(banner, -12, "Filtre de loot", nil, self.enable).label
        bt:SetFont(UI.FONT, 14, "")
        bt:ClearAllPoints()
        bt:SetPoint("TOPLEFT", banner, "TOPLEFT", 52, -12)
        self.enable:ClearAllPoints()
        self.enable:SetPoint("RIGHT", banner, "RIGHT", -16, 0)
        self.bannerState = UI:Text(banner, 11, C.muted)
        self.bannerState:SetPoint("TOPLEFT", bt, "BOTTOMLEFT", 0, -4)
        self.bannerState:SetPoint("TOPRIGHT", banner, "TOPRIGHT", -210, -30)
        self.enableLbl = UI:Text(banner, 12)
        self.enableLbl:SetPoint("RIGHT", self.enable, "LEFT", -10, 0)
        -- roue : réglages du butin à l'écran (UI/LootToast.lua), volet posé sous le bandeau
        local ltCard = UI.BuildLootToastCard and UI:BuildLootToastCard(p)
        if ltCard then
            self.gp = UI:PageGear(p, { title = "Butin à l'écran", top = BANNER_H + GAP, columns = 1, size = 28,
                cards = function() return { ltCard } end }, self)
            self.gp.gear:SetPoint("RIGHT", self.enableLbl, "LEFT", -16, 0)
            self.gp.gear:SetFrameLevel(banner:GetFrameLevel() + 5)
        end
        local TOP = -(BANNER_H + GAP)

        -- Colonne de gauche : profils + objets laissés au sol --------------------------
        local left = UI:Card(p, "Profils")
        left:SetWidth(LEFT_W)
        left:SetPoint("TOPLEFT", 0, TOP)
        left:SetPoint("BOTTOMLEFT")
        local addBtn = UI:IconButton(left, "plus", 26, "Nouveau profil")
        addBtn:SetPoint("TOPRIGHT", -10, -8)
        addBtn:SetScript("OnClick", function() self.sel = L:Add(); self:Refresh() end)
        -- Liste des profils : défile quand elle dépasse la place laissée par « Laissés au sol ».
        local ps = UI:Scroll(left)
        ps:SetPoint("TOPLEFT", 8, -40)
        ps:SetPoint("TOPRIGHT", -2, -40)
        ps:SetHeight(42)
        self.profScroll = ps
        self.leftCard = left
        self.profileRows = UI:Pool(function()
            local b = CreateFrame("Button", nil, ps.child)
            b:SetHeight(38)
            b.bg = UI:Rounded(b, 10, 0, "BACKGROUND", 1)
            b.bar = CreateFrame("Frame", nil, b)
            b.bar:SetSize(3, 18)
            b.bar:SetPoint("LEFT")
            b.barTex = UI:Rounded(b.bar, 1.5, 0, "ARTWORK", 1)
            b.name = UI:Text(b, 12)
            b.name:SetPoint("TOPLEFT", 12, -7)
            b.name:SetPoint("TOPRIGHT", -56, -7)
            b.auto = UI:Text(b, 10, C.dim)
            b.auto:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -3)
            b.active = UI:Badge(b, "actif")
            b.active:SetPoint("RIGHT", -8, 0)
            function b:Paint()
                self.bg:SetColor(unpack(self.selected and C.surface2 or C.hover))
                self.bg:SetShown(self.selected or self.hover)
                self.bar:SetShown(self.selected)
                self.barTex:SetColor(UI:Accent())
            end
            b:SetScript("OnEnter", function(s) s.hover = true; s:Paint() end)
            b:SetScript("OnLeave", function(s) s.hover = false; s:Paint() end)
            -- un profil choisi : la liste des objets laissés au sol se referme (on revient au profil)
            b:SetScript("OnClick", function(s)
                self.sel = s.index
                if self.leftPanel and self.leftPanel:IsShown() then self.leftPanel:Hide() end
                self:Refresh()
            end)
            return b
        end)

        -- Bas de colonne : objets laissés au sol.
        self.leftCount = UI:Text(left, 11, C.muted)
        self.leftCount:SetPoint("BOTTOMLEFT", 14, 14)
        local listBtn = UI:Button(left, "Voir la liste", nil, 24, "secondary", "notes")
        listBtn:SetPoint("BOTTOMLEFT", 10, 34)
        listBtn:SetPoint("BOTTOMRIGHT", -10, 34)
        listBtn.tooltip = "Tous les objets laissés au sol, avec leur prix."
        listBtn:SetScript("OnClick", function()
            self.leftPanel:SetShown(not self.leftPanel:IsShown())
            self:RefreshLeft()
        end)
        self.recentRows = UI:Pool(function()
            local r = CreateFrame("Button", nil, left)
            r:SetHeight(24)
            r.icon = UI:RoundIcon(r, 16)
            r.icon:SetPoint("LEFT", 4, 0)
            r.name = UI:Text(r, 11, C.muted)
            r.name:SetPoint("LEFT", 26, 0)
            r.name:SetPoint("RIGHT", -4, 0)
            r:SetScript("OnEnter", function(s)
                s.name:SetTextColor(unpack(C.text))
                WK.UI:TooltipOwner(s, "ANCHOR_RIGHT")
                GameTooltip:SetText(WK.T("Clique pour toujours ramasser cet objet"), 1, 1, 1)
                GameTooltip:Show()
            end)
            r:SetScript("OnLeave", function(s) s.name:SetTextColor(unpack(C.muted)); GameTooltip:Hide() end)
            r:SetScript("OnClick", function(s)
                local prof = L:Get(self.sel)
                if prof and s.itemID then prof.always[s.itemID] = true; prof.never[s.itemID] = nil; self:Refresh() end
            end)
            return r
        end)
        self.recentTitle = UI:Text(left, 10, C.dim)
        self.recentTitle:SetText(UI:Upper(T("Laissés au sol récemment")))

        -- Colonne de droite ---------------------------------------------------------------
        local x0 = LEFT_W + GAP

        -- Avertissement : butin automatique du jeu.
        self.warn = UI:Card(p)
        self.warn:SetHeight(44)
        self.warn:SetPoint("TOPLEFT", x0, TOP)
        self.warn:SetPoint("TOPRIGHT", 0, TOP)
        self.warn.bg:SetColor(C.negative[1] * 0.25, C.negative[2] * 0.2, C.negative[3] * 0.2, 1)
        local wt = UI:Text(self.warn, 11)
        wt:SetPoint("LEFT", 14, 0)
        wt:SetPoint("RIGHT", -190, 0)
        wt:SetText("Le butin automatique du jeu est activé : le filtre ne peut pas choisir.")
        local wb = UI:Button(self.warn, "Le désactiver", nil, 28, "primary")
        wb:SetPoint("RIGHT", -10, 0)
        wb:SetScript("OnClick", function() L:DisableGameAutoLoot(); self:Refresh() end)

        local body = CreateFrame("Frame", nil, p)
        self.body = body
        body:SetPoint("TOPLEFT", x0, TOP)
        body:SetPoint("BOTTOMRIGHT")

        -- Objets laissés au sol (maquette A + fiche de B) : bilan, conseils en un clic, filtres, liste et fiche
        -- de l'objet choisi, par-dessus la colonne de droite.
        local lp = UI:Card(p, "Objets laissés au sol")
        lp:SetPoint("TOPLEFT", x0, TOP)
        lp:SetPoint("BOTTOMRIGHT")
        lp:SetFrameLevel(p:GetFrameLevel() + 40)
        lp:EnableMouse(true)
        lp:Hide()
        self.leftPanel = lp
        local close = UI:IconButton(lp, "close", 26, nil, "accent")
        close:SetPoint("TOPRIGHT", -10, -8)
        close:SetScript("OnClick", function() lp:Hide() end)
        self.lpSummary = UI:Text(lp, 11, C.muted)
        self.lpSummary:SetPoint("TOPLEFT", 16, -36)
        self.lpSummary:SetPoint("TOPRIGHT", -50, -36)
        -- chiffres clés
        self.lpKpi = UI:KpiRow(lp, 4, 74)
        self.lpKpi:SetPoint("TOPLEFT", 12, -56)
        self.lpKpi:SetPoint("TOPRIGHT", -12, -56)
        -- conseils (cachés quand il n'y a rien à proposer)
        local function tip(col)
            local f = _G.CreateFrame("Frame", nil, lp)
            f:SetHeight(44)
            f.edge = UI:Rounded(f, 10, 0, "BACKGROUND", 1)
            f.bg = UI:Rounded(f, 9, 1, "BACKGROUND", 2)
            f.edge:SetColor(col[1], col[2], col[3], 0.45)
            f.bg:SetColor(col[1] * 0.18, col[2] * 0.18, col[3] * 0.18, 1)
            f.t = UI:Text(f, 12); f.t:SetPoint("TOPLEFT", 12, -8); f.t:SetJustifyH("LEFT")
            f.s = UI:Text(f, 10, C.muted); f.s:SetPoint("TOPLEFT", f.t, "BOTTOMLEFT", 0, -3); f.s:SetJustifyH("LEFT")
            f.btn = UI:Button(f, "", nil, 26, "primary")
            f.btn:SetPoint("RIGHT", -9, 0)
            f.t:SetPoint("RIGHT", f.btn, "LEFT", -10, 0); f.s:SetPoint("RIGHT", f.btn, "LEFT", -10, 0)
            return f
        end
        self.lpTipWorth = tip(UI.colors.positive)
        self.lpTipWorth.edge:SetColor(UI:Accent())
        self.lpTipFull = tip(C.warning)
        self.lpTipFull.btn:SetStyle("secondary")
        self.lpTipWorth.btn:SetScript("OnClick", function()
            local prof = L:Get(self.sel)
            if prof and self.lpWorth and #self.lpWorth > 0 then L:AlwaysLoot(self.lpWorth, prof); self:Refresh() end
        end)
        self.lpTipFull.btn:SetScript("OnClick", function()
            if UI.OpenBagBarSettings then UI:OpenBagBarSettings() end
        end)
        -- filtres
        self.lpSort, self.lpReason, self.lpProf = "value", "all", "all"
        local sortSeg = UI:Segmented(lp, { { "value", "Valeur" }, { "count", "Quantité" }, { "recent", "Récents" } },
            function(k) self.lpSort = k; self:RefreshLeft() end, 26)
        sortSeg:Select("value")
        self.lpSortSeg = sortSeg
        local reasonSeg = UI:Segmented(lp, { { "all", "Toutes raisons" }, { "filter", "Filtre" },
            { "full", "Sacs pleins" } }, function(k) self.lpReason = k; self:RefreshLeft() end, 26)
        reasonSeg:SetPoint("LEFT", sortSeg, "RIGHT", 12, 0)
        reasonSeg:Select("all")
        self.lpProfDd = UI:Dropdown(lp, 170, 26, { { "all", "Tous profils" } }, function(k)
            self.lpProf = k; self:RefreshLeft()
        end)
        self.lpProfDd:SetPoint("LEFT", reasonSeg, "RIGHT", 12, 0)
        local clear = UI:Button(lp, "Vider la liste", nil, 26, "ghost", "trash")
        clear.tooltip = "Maj + clic : remet la liste à zéro."
        clear:SetScript("OnClick", function()
            if _G.IsShiftKeyDown() then L:ClearLeft(); self.lpSel = nil; self:RefreshLeft() end
        end)
        self.lpClear = clear
        -- fiche de l'objet choisi (à droite)
        local FW = 280
        local fc = _G.CreateFrame("Frame", nil, lp)
        fc:SetWidth(FW)
        fc.edge = UI:Rounded(fc, 10, 0, "BACKGROUND", 1)
        fc.bg = UI:Rounded(fc, 9, 1, "BACKGROUND", 2)
        fc.edge:SetColor(unpack(C.border)); fc.bg:SetColor(unpack(C.surface))
        self.lpFiche = fc
        fc.icon = UI:RoundIcon(fc, 36); fc.icon:SetPoint("TOPLEFT", 12, -12)
        fc.name = UI:Text(fc, 13); fc.name:SetPoint("TOPLEFT", 58, -13); fc.name:SetPoint("RIGHT", -10, 0)
        fc.name:SetJustifyH("LEFT")
        fc.cat = UI:Text(fc, 10, C.muted); fc.cat:SetPoint("TOPLEFT", fc.name, "BOTTOMLEFT", 0, -4)
        fc.cat:SetPoint("RIGHT", -10, 0); fc.cat:SetJustifyH("LEFT")
        local function mini(x)
            local m = _G.CreateFrame("Frame", nil, fc)
            m:SetSize((FW - 34) / 2, 54); m:SetPoint("TOPLEFT", x, -60)
            local b = UI:Rounded(m, 8, 0, "BACKGROUND", 3); b:SetColor(unpack(C.surface2))
            m.l = UI:Text(m, 10, C.muted); m.l:SetPoint("TOPLEFT", 10, -8)
            m.v = UI:Text(m, 15); m.v:SetPoint("TOPLEFT", m.l, "BOTTOMLEFT", 0, -3)
            m.s = UI:Text(m, 10, C.muted); m.s:SetPoint("TOPLEFT", m.v, "BOTTOMLEFT", 0, -2)
            return m
        end
        fc.k1, fc.k2 = mini(12), mini(12 + (FW - 34) / 2 + 10)
        fc.k1.l:SetText(UI:Upper(T("Laissé"))); fc.k2.l:SetText(UI:Upper(T("Valeur")))
        local function sect(title, y)
            local h = UI:Text(fc, 10, C.dim); h:SetPoint("TOPLEFT", 12, y); h:SetText(UI:Upper(T(title)))
            local t = UI:Text(fc, 11); t:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -4)
            t:SetPoint("RIGHT", fc, "RIGHT", -12, 0)
            t:SetJustifyH("LEFT"); t:SetJustifyV("TOP")
            if t.SetWordWrap then t:SetWordWrap(true) end
            return h, t
        end
        fc.whereH, fc.where = sect("Où", -128)
        fc.whyH, fc.why = sect("Pourquoi", -128)
        fc.bAlways = UI:Button(fc, "", nil, 26, "primary")
        fc.bAll = UI:Button(fc, "Toujours ramasser (tous les profils)", nil, 26, "secondary")
        fc.bHide = UI:Button(fc, "Ne plus lister", nil, 26, "ghost")
        for i, b in ipairs({ fc.bAlways, fc.bAll, fc.bHide }) do
            b:SetPoint("BOTTOMLEFT", 12, 12 + (3 - i) * 32); b:SetPoint("BOTTOMRIGHT", -12, 12 + (3 - i) * 32)
        end
        fc.bAlways:SetScript("OnClick", function()
            local prof = L:Get(self.sel)
            if prof and self.lpSel then L:AlwaysLoot({ self.lpSel }, prof); self:Refresh() end
        end)
        fc.bAll:SetScript("OnClick", function()
            if self.lpSel then L:AlwaysLoot({ self.lpSel }); self:Refresh() end
        end)
        fc.bHide:SetScript("OnClick", function()
            if self.lpSel then L:HideLeft(self.lpSel); self.lpSel = nil; self:RefreshLeft() end
        end)
        fc.empty = UI:Text(fc, 11, C.muted); fc.empty:SetPoint("CENTER")
        fc.empty:SetText(T("Choisis un objet de la liste."))
        -- liste
        local lscroll = UI:Scroll(lp)
        lscroll:SetPoint("BOTTOMLEFT", 10, 10)
        lscroll:SetPoint("RIGHT", fc, "LEFT", -10, 0)
        self.lpScroll = lscroll
        self.lpEmpty = UI:Text(lp, 12, C.muted)
        self.lpEmpty:SetPoint("TOP", lscroll, "TOP", 0, -40)
        self.lpEmpty:SetText("Aucun objet laissé au sol pour l'instant.")
        self.lpRows = UI:Pool(function()
            local r = CreateFrame("Button", nil, lscroll.child)
            r:SetHeight(42)
            r.bg = UI:Rounded(r, 10, 0, "BACKGROUND", 1)
            r.edge = UI:Rounded(r, 10, 0, "BACKGROUND", 0)
            r.icon = UI:RoundIcon(r, 26)
            r.icon:SetPoint("LEFT", 10, 0)
            r.hide = UI:IconButton(r, "close", 22, "Ne plus lister cet objet (le profil ne change pas)")
            r.hide:SetPoint("RIGHT", -8, 0)
            r.hide:SetScript("OnClick", function(b)
                if b.itemID then
                    L:HideLeft(b.itemID)
                    if self.lpSel == b.itemID then self.lpSel = nil end
                    self:RefreshLeft()
                end
            end)
            r.add = UI:IconButton(r, "plus", 22, "Toujours ramasser cet objet (profil sélectionné)")
            r.add:SetPoint("RIGHT", r.hide, "LEFT", -4, 0)
            r.add:SetScript("OnClick", function(b)
                local prof = L:Get(self.sel)
                if prof and b.itemID then L:AlwaysLoot({ b.itemID }, prof); self:Refresh() end
            end)
            r.value = UI:Text(r, 13)
            r.value:SetPoint("TOPRIGHT", -64, -7)
            r.value:SetJustifyH("RIGHT")
            r.unit = UI:Text(r, 10, C.muted)
            r.unit:SetPoint("TOPRIGHT", r.value, "BOTTOMRIGHT", 0, -3)
            r.unit:SetJustifyH("RIGHT")
            r.name = UI:Text(r, 12)
            r.name:SetPoint("TOPLEFT", 46, -7)
            r.name:SetPoint("TOPRIGHT", -150, -7)
            r.sub = UI:Text(r, 10, C.muted)
            r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
            r.sub:SetPoint("TOPRIGHT", r.name, "BOTTOMRIGHT", 0, -3)
            r:SetScript("OnEnter", function(s)
                if not s.itemID then return end
                WK.UI:TooltipOwner(s, "ANCHOR_RIGHT")
                if GameTooltip.SetItemByID then GameTooltip:SetItemByID(s.itemID)
                else GameTooltip:SetHyperlink("item:" .. s.itemID) end
                GameTooltip:Show()
            end)
            r:SetScript("OnLeave", function() GameTooltip:Hide() end)
            r:SetScript("OnClick", function(s)
                if IsShiftKeyDown() and s.itemID then
                    local _, link = WK.GetItemInfo(s.itemID)
                    if link then WK.InsertChatLink(link) end
                    return
                end
                self.lpSel = s.itemID
                self:RefreshLeft()
            end)
            return r
        end)

        -- fiche : où, pourquoi, prix
        local function paintFiche(e)
            fc.empty:SetShown(e == nil)
            for _, w in ipairs({ fc.icon, fc.name, fc.cat, fc.k1, fc.k2, fc.whereH, fc.where, fc.whyH, fc.why,
                fc.bAlways, fc.bAll, fc.bHide }) do w:SetShown(e ~= nil) end
            if not e then return end
            local name, icon, qr, qg, qb = UI:ItemInfo(e.id)
            fc.icon:SetTexture(icon)
            fc.name:SetText(e.name or name or "?"); fc.name:SetTextColor(qr or 1, qg or 1, qb or 1)
            local _, _, _, ilvl, _, itype, isub = WK.GetItemInfo(e.id)
            local bits = {}
            if itype then bits[#bits + 1] = itype end
            if isub and isub ~= itype then bits[#bits + 1] = isub end
            if ilvl and ilvl > 1 then bits[#bits + 1] = string.format(T("niv. %d"), ilvl) end
            fc.cat:SetText(table.concat(bits, " · "))
            fc.k1.v:SetText("x" .. (e.n or 0)); fc.k1.s:SetText(string.format(T("%d fois"), e.times or 1))
            if e.unit > 0 then
                fc.k2.v:SetText(UI:GoldText(e.value))
                fc.k2.s:SetText(string.format(T("%s l'unité"), UI:PlainMoney(e.unit)))
            else
                fc.k2.v:SetText(UI:Hex(C.dim) .. "-|r"); fc.k2.s:SetText(T("pas de prix"))
            end
            -- où : zones les plus fréquentes
            local zl = {}
            for z, n in pairs(e.zones or {}) do zl[#zl + 1] = { z, n } end
            table.sort(zl, function(a, b) return a[2] > b[2] end)
            local lines = {}
            for i = 1, math.min(4, #zl) do lines[#lines + 1] = string.format(T("%s · %d fois"), zl[i][1], zl[i][2]) end
            fc.where:SetText(#lines > 0 and table.concat(lines, "\n")
                or (UI:Hex(C.muted) .. T("pas encore noté (objets laissés avant cette version)") .. "|r"))
            -- pourquoi : profils, sacs pleins, règle du profil, prix du marchand
            local why = {}
            for pn, n in pairs(e.prof or {}) do
                local pr
                for _, x in ipairs(L:Profiles()) do if x.name == pn then pr = x end end
                local rule = pr and L:WhyLeft(pr, e.id)
                why[#why + 1] = string.format(T("Profil « %s »%s"), pn, rule and (" : " .. rule) or "")
                    .. (n > 1 and string.format(" (%d)", n) or "")
            end
            if (e.fullN or 0) > 0 or (e.full or 0) > 0 then
                why[#why + 1] = UI:Hex(C.warning) .. string.format(T("Sacs pleins : %d fois"), e.fullN or 1) .. "|r"
            end
            if #why == 0 then
                local rule = L:WhyLeft(L:Get(self.sel), e.id)
                why[#why + 1] = rule and string.format(T("Profil choisi : %s"), rule) or T("Laissé par le filtre")
            end
            local sell = select(11, WK.GetItemInfo(e.id))
            if sell and sell > 0 then
                why[#why + 1] = UI:Hex(C.muted) .. string.format(T("vendu %s chez le marchand"), UI:PlainMoney(sell))
                    .. "|r"
            end
            fc.why:SetText(table.concat(why, "\n"))
            -- « Pourquoi » sous le texte de « Où », d'après sa hauteur réelle (texte sur plusieurs lignes)
            fc.whyH:ClearAllPoints()
            fc.whyH:SetPoint("TOPLEFT", 12, -128 - 16 - math.ceil(fc.where:GetStringHeight() or 14) - 12)
            local prof = L:Get(self.sel)
            fc.bAlways:SetLabel(string.format(T("Toujours ramasser (%s)"), prof and prof.name or "-"))
        end

        function self:RefreshLeft()
            if not lp:IsShown() then return end
            local prof = L:Get(self.sel)
            -- bilan et conseils
            local st = L:LeftStats(prof, 2000)
            local _, _, count, since = L:LeftList("value")
            self.lpSummary:SetText(string.format(T("%d objets laissés · depuis le %s  (%s)"),
                count, _G.date("%d/%m", since or _G.time()), WK.modules.Value:SourceLabel()))
            local now = _G.time()
            local days = math.max(1, math.floor((now - (since or now)) / 86400 + 0.5))
            self.lpKpi:Set(1, { label = UI:Upper(T("Valeur laissée")), value = UI:PlainMoney(st.total), color = C.gold,
                sub = string.format(T("%d objets en %d jour(s)"), st.count, days) })
            self.lpKpi:Set(2, { label = UI:Upper(T("Par le filtre")), value = UI:PlainMoney(st.filter),
                sub = string.format(T("profil « %s »"), prof and prof.name or "-") })
            self.lpKpi:Set(3, { label = UI:Upper(T("Sacs pleins")), value = UI:PlainMoney(st.full), color = C.warning,
                sub = string.format(T("%d fois cette semaine"), st.fullWeek) })
            local best = st.best
            local bname = best and (best.name or (UI:ItemInfo(best.id))) or "-"
            self.lpKpi:Set(4, { label = UI:Upper(T("Plus cher oublié")),
                value = best and UI:PlainMoney(best.value) or "-", color = C.info, sub = bname })
            self.lpWorth = st.worth
            local y = -138
            local showW, showF = #st.worth > 0, st.fullWeek >= 3
            self.lpTipWorth:SetShown(showW); self.lpTipFull:SetShown(showF)
            if showW or showF then
                local half = showW and showF
                self.lpTipWorth:ClearAllPoints(); self.lpTipFull:ClearAllPoints()
                if showW then
                    self.lpTipWorth:SetPoint("TOPLEFT", 12, y)
                    if half then self.lpTipWorth:SetPoint("RIGHT", lp, "CENTER", -5, 0)
                    else self.lpTipWorth:SetPoint("TOPRIGHT", -12, y) end
                    self.lpTipWorth.t:SetText(string.format(T("%d objet(s) à plus de %s l'unité"), #st.worth,
                        UI:PlainMoney(2000)))
                    self.lpTipWorth.s:SetText(string.format(T("%s laissés"), UI:PlainMoney(st.worthValue)))
                    self.lpTipWorth.btn:SetLabel(T("Toujours les ramasser"))
                end
                if showF then
                    if half then self.lpTipFull:SetPoint("TOPLEFT", lp, "TOP", 5, y)
                    else self.lpTipFull:SetPoint("TOPLEFT", 12, y) end
                    self.lpTipFull:SetPoint("TOPRIGHT", -12, y)
                    self.lpTipFull.t:SetText(string.format(T("Sacs pleins %d fois cette semaine"), st.fullWeek))
                    self.lpTipFull.s:SetText(string.format(T("%s perdus faute de place"), UI:PlainMoney(st.full)))
                    self.lpTipFull.btn:SetLabel(T("Barre des sacs"))
                end
                y = y - 52
            end
            -- filtres
            self.lpSortSeg:ClearAllPoints(); self.lpSortSeg:SetPoint("TOPLEFT", 12, y)
            -- « Vider la liste » en haut, à gauche de la croix (la ligne des filtres est pleine)
            self.lpClear:ClearAllPoints(); self.lpClear:SetPoint("TOPRIGHT", -44, -8)
            local opts = { { "all", "Tous profils" } }
            for _, pr in ipairs(L:Profiles()) do opts[#opts + 1] = { pr.name, pr.name } end
            self.lpProfDd:SetOptions(opts)
            if self.lpProf ~= "all" then
                local found = false
                for _, o in ipairs(opts) do if o[1] == self.lpProf then found = true end end
                if not found then self.lpProf = "all" end
            end
            self.lpProfDd:Select(self.lpProf)
            y = y - 36
            fc:ClearAllPoints(); fc:SetPoint("TOPRIGHT", -12, y); fc:SetPoint("BOTTOMRIGHT", -12, 10)
            lscroll:SetPoint("TOPLEFT", 10, y)
            -- liste
            local filter = { reason = self.lpReason ~= "all" and self.lpReason or nil,
                prof = self.lpProf ~= "all" and self.lpProf or nil }
            local list = L:LeftList(self.lpSort, filter)
            local selE
            self.lpRows:Reset()
            local ry = 0
            for _, e in ipairs(list) do
                local r = self.lpRows:Get()
                r.itemID, r.add.itemID, r.hide.itemID = e.id, e.id, e.id
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", 0, -ry)
                r:SetPoint("TOPRIGHT", 0, -ry)
                local sel = self.lpSel == e.id
                if sel then selE = e end
                r.bg:SetColor(unpack(sel and C.hover or C.surface2))
                local ar, ag, ab = UI:Accent()
                r.edge:SetColor(ar, ag, ab, sel and 0.8 or 0)
                local name, icon, qr, qg, qb = UI:ItemInfo(e.id)
                r.icon:SetTexture(icon)
                r.name:SetText(e.name or name)
                r.name:SetTextColor(qr or 1, qg or 1, qb or 1)
                local sub = string.format(T("x%d  ·  %d fois  ·  dernière fois %s"), e.n, e.times or 1, UI:Ago(e.last or time()))
                if (e.full or 0) > 0 then
                    sub = sub .. "  ·  " .. UI:Hex(C.warning) .. string.format(T("%d sacs pleins"), e.full) .. "|r"
                end
                r.sub:SetText(sub)
                if e.unit > 0 then
                    r.value:SetText(UI:GoldText(e.value))
                    r.unit:SetText(string.format(T("%s l'unité"), UI:PlainMoney(e.unit)))
                else
                    r.value:SetText(UI:Hex(C.dim) .. "-|r")
                    r.unit:SetText(T("pas de prix"))
                end
                ry = ry + 46
            end
            -- rien de choisi (ou plus dans la liste) : le premier objet
            if not selE and list[1] then self.lpSel = list[1].id; return self:RefreshLeft() end
            self.lpScroll:SetContentHeight(ry)
            self.lpEmpty:SetShown(#list == 0)
            paintFiche(selE)
        end

        -- Réglages du profil
        local prof = UI:Card(body)
        prof:SetHeight(PROF_H)
        prof:SetPoint("TOPLEFT")
        prof:SetPoint("TOPRIGHT")
        self.nameInput = UI:Input(prof, 240, 32, "Nom du profil")
        self.nameInput:SetPoint("TOPLEFT", 14, -14)
        self.nameInput.onEnter = function(t)
            local pr = L:Get(self.sel)
            if pr and t and t ~= "" and t ~= pr.name then pr.name = t; self:Refresh() end
        end
        self.nameInput.edit:HookScript("OnEditFocusLost", function() self.nameInput.onEnter(self.nameInput:GetText()) end)
        local del = UI:IconButton(prof, "trash", 30, "Supprimer ce profil", true)
        del:SetPoint("TOPRIGHT", -12, -15)
        del:SetScript("OnClick", function()
            L:Remove(self.sel); self.sel = WK.DB.global.loot.active or 1; self:Refresh()
        end)
        local dup = UI:Button(prof, "Dupliquer", nil, 30, "secondary")
        dup:SetPoint("RIGHT", del, "LEFT", -6, 0)
        dup:SetScript("OnClick", function() self.sel = L:Duplicate(self.sel) or self.sel; self:Refresh() end)
        self.loadBtn = UI:Button(prof, "Charger", nil, 30, "primary", "play")
        self.loadBtn:SetPoint("RIGHT", dup, "LEFT", -6, 0)
        self.loadBtn:SetScript("OnClick", function() L:SetActive(self.sel); L:CheckAuto(); self:Refresh() end)

        -- Réglages en lignes UI:SettingRow (trouvables par la recherche), commandes replacées à la main.
        self.quality = UI:Dropdown(prof, 200, 30, QUALITIES, function(v)
            local pr = L:Get(self.sel); if pr then pr.minQuality = v; self:Refresh() end
        end)
        local ql = UI:SettingRow(prof, -57, "Qualité minimale", nil, self.quality).label
        ql:SetTextColor(unpack(C.muted))
        self.quality:ClearAllPoints()
        self.quality:SetPoint("TOPLEFT", prof, "TOPLEFT", 150, -58)
        self.value = UI:NumberInput(prof, 90, 30, "0")
        local vl = UI:SettingRow(prof, -57, "Valeur minimale", nil, self.value).label
        vl:SetTextColor(unpack(C.muted))
        vl:ClearAllPoints()
        vl:SetPoint("LEFT", self.quality, "RIGHT", 20, 0)
        self.value:ClearAllPoints()
        self.value:SetPoint("LEFT", vl, "RIGHT", 10, 0)
        self.value.onEnter = function()
            local pr = L:Get(self.sel); if pr then pr.minValue = self.value:GetNumber() * 100; self:Refresh() end
        end
        self.value.edit:HookScript("OnEditFocusLost", function() self.value.onEnter() end)
        local vu = UI:Text(prof, 11, C.dim)
        vu:SetPoint("LEFT", self.value, "RIGHT", 6, 0)
        vu:SetText(T("pa"))

        self.keepRules = UI:Toggle(prof, function()
            local pr = L:Get(self.sel); return pr and pr.keepRules
        end, function(v)
            local pr = L:Get(self.sel); if pr then pr.keepRules = v end
        end)
        local kl = UI:SettingRow(prof, -137, "Toujours les objets de mes règles d'envoi et de dépôt", nil, self.keepRules).label
        self.keepRules:ClearAllPoints()
        self.keepRules:SetPoint("TOPLEFT", prof, "TOPLEFT", 16, -142)
        kl:ClearAllPoints()
        kl:SetPoint("LEFT", self.keepRules, "RIGHT", 10, 0)
        local qn = UI:Text(prof, 10, C.dim)
        qn:SetPoint("TOPLEFT", 16, -172)
        qn:SetText("L'or, les monnaies et les objets de quête sont toujours ramassés.")

        -- « Se charge tout seul » : situation dans laquelle ce profil remplace le profil chargé.
        local function autoOptions()
            local zone = GetRealZoneText and GetRealZoneText() or "?"
            return {
                { "none", T("Jamais (bouton Charger)") }, { "zone", T("Dans cette zone : ") .. zone },
                { "party", T("En donjon") }, { "raid", T("En raid") }, { "pvp", T("En JcJ") },
                { "farm", T("Pendant une session de farm") },
            }
        end
        self.autoOptions = autoOptions
        self.autoDd = UI:Dropdown(prof, 260, 30, autoOptions(), function(k)
            local pr = L:Get(self.sel)
            if pr then pr.auto = { kind = k, value = k == "zone" and (GetRealZoneText and GetRealZoneText()) or nil } end
            L:CheckAuto()
            self:Refresh()
        end)
        local al = UI:SettingRow(prof, -97, "Se charge tout seul", nil, self.autoDd).label
        al:SetTextColor(unpack(C.muted))
        self.autoDd:ClearAllPoints()
        self.autoDd:SetPoint("TOPLEFT", prof, "TOPLEFT", 150, -98)
        self.autoHelp = UI:Text(prof, 10, C.dim)
        self.autoHelp:SetPoint("TOPLEFT", self.autoDd, "TOPRIGHT", 12, -2)
        self.autoHelp:SetPoint("TOPRIGHT", prof, "TOPRIGHT", -16, -100)
        self.autoHelp:SetJustifyH("LEFT")
        if self.autoHelp.SetWordWrap then self.autoHelp:SetWordWrap(true) end

        -- Catégories
        local cats = UI:Card(body, "Catégories toujours ramassées")
        self.catCard = cats
        cats:SetPoint("TOPLEFT", 0, -PROF_H - GAP)
        cats:SetPoint("TOPRIGHT", 0, -PROF_H - GAP)
        self.catButtons = {}
        local catOrder = {}
        for _, c in ipairs(WK.modules.Rules.CATEGORIES) do
            local b = UI:Button(cats, c.label, nil, 26, "ghost")
            table.insert(catOrder, b)
            b:SetScript("OnClick", function()
                local pr = L:Get(self.sel)
                if pr then pr.cats[c.key] = (not pr.cats[c.key]) or nil; self:Refresh() end
            end)
            self.catButtons[c.key] = b
        end
        -- Listes sous les catégories, côte à côte.
        self.always = ItemList(self, body, "Toujours ramasser", "always")
        self.always.card:SetPoint("TOPLEFT", cats, "BOTTOMLEFT", 0, -GAP)
        self.always.card:SetPoint("BOTTOMLEFT")
        self.never = ItemList(self, body, "Jamais ramasser", "never")
        self.never.card:SetPoint("TOPRIGHT", cats, "BOTTOMRIGHT", 0, -GAP)
        self.never.card:SetPoint("BOTTOMRIGHT")

        -- Élastique : pastilles des catégories remises en lignes, listes à moitié de largeur.
        UI:OnResize(body, function(w)
            local cx, cy = 14, -40
            for _, b in ipairs(catOrder) do
                if cx + b:GetWidth() > w - 14 then cx, cy = 14, cy - 32 end
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", cats, "TOPLEFT", cx, cy)
                cx = cx + b:GetWidth() + 6
            end
            cats:SetHeight(-cy + 40)
            local half = (w - GAP) / 2
            self.always.card:SetWidth(half)
            self.never.card:SetWidth(half)
        end)
        -- Hauteur de la colonne de gauche : profils et « Laissés au sol » recalculés.
        UI:OnResize(left, function() if self.profN then self:LayoutLeft() end end)
    end,

    -- Colonne de gauche : la liste des profils prend sa hauteur (défile au-delà), le reste
    -- va aux objets laissés au sol récemment (au moins trois lignes quand il y en a).
    LayoutLeft = function(self)
        local L = Loot()
        local d = WK.DB.global.loot
        local H = self.leftCard:GetHeight()
        if not H or H <= 0 then H = UI.PAGE_H - BANNER_H - GAP end
        local recent = d.recent or {}
        local want = self.profN * 42
        local free = H - 40 - 122
        local ph = math.max(42, math.min(want, free - math.min(#recent, 3) * 24))
        self.profScroll:SetHeight(ph)
        self.profScroll:SetContentHeight(want)

        self.recentRows:Reset()
        self.leftCount:SetText(string.format(T("Session : %d laissés"), L.leftSession or 0))
        local room = math.floor((free - ph) / 24)
        local shown = math.max(0, math.min(#recent, room))
        self.recentTitle:ClearAllPoints()
        self.recentTitle:SetPoint("BOTTOMLEFT", 14, 70 + shown * 24)
        self.recentTitle:SetShown(shown > 0)
        for i = 1, shown do
            local e = recent[i]
            local r = self.recentRows:Get()
            r.itemID = e.id
            r:ClearAllPoints()
            r:SetPoint("BOTTOMLEFT", 10, 66 + (shown - i) * 24)
            r:SetPoint("BOTTOMRIGHT", -10, 66 + (shown - i) * 24)
            local name, icon = UI:ItemInfo(e.id or 0)
            r.icon:SetTexture(icon)
            r.name:SetText((e.name or name) .. "  x" .. (e.n or 1))
        end
    end,

    Refresh = function(self)
        local L = Loot()
        local d = WK.DB.global.loot
        local profiles = L:Profiles()
        if not profiles[self.sel] then self.sel = 1 end
        local _, effIndex, isAuto = L:Effective()

        -- Avertissement butin automatique
        local warn = L:GameAutoLoot() and d.enabled
        self.warn:SetShown(warn)
        self.body:ClearAllPoints()
        self.body:SetPoint("TOPLEFT", LEFT_W + GAP, -(BANNER_H + GAP) - (warn and (44 + GAP) or 0))
        self.body:SetPoint("BOTTOMRIGHT")

        -- Profils
        self.profileRows:Reset()
        local y = 0
        for i, pr in ipairs(profiles) do
            local b = self.profileRows:Get()
            b.index = i
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", 0, y)
            b:SetPoint("TOPRIGHT", 0, y)
            b.name:SetText(pr.name)
            local a = autoLabel(pr.auto)
            b.auto:SetText(a and (T("auto : ") .. a) or "")
            b.active:SetShown(i == effIndex)
            b.active:Set(isAuto and i == effIndex and T("auto") or T("actif"))
            b.selected = (i == self.sel)
            b:Paint()
            y = y - 42
        end
        self.enable:Refresh()
        -- Bandeau : état du filtre et profil chargé
        local eff = profiles[effIndex]
        if d.enabled then
            self.bannerIcon:SetVertexColor(UI:Accent())
            self.enableLbl:SetText(UI:Hex(C.positive) .. T("Activé") .. "|r")
            self.bannerState:SetText(string.format(T("Profil chargé : %s%s"), eff and eff.name or "-",
                isAuto and ("  ·  " .. T("choisi automatiquement")) or ""))
        else
            self.bannerIcon:SetVertexColor(unpack(C.dim))
            self.enableLbl:SetText(UI:Hex(C.dim) .. T("Désactivé") .. "|r")
            self.bannerState:SetText(T("Le butin est ramassé normalement par le jeu."))
        end

        -- Laissés au sol (et hauteur de la liste des profils)
        self.profN = #profiles
        self:LayoutLeft()

        -- Profil sélectionné
        local pr = profiles[self.sel]
        self.nameInput:SetText(pr.name)
        self.quality:Select(pr.minQuality or 0)
        self.value:SetText(tostring(math.floor((pr.minValue or 0) / 100)))
        self.keepRules:Refresh()
        self.autoDd:SetOptions(self.autoOptions()) -- zone actuelle à jour
        local kind = (pr.auto and pr.auto.kind) or "none"
        self.autoDd:Select(kind)
        if kind == "zone" and pr.auto.value then
            self.autoDd.label:SetText(T("Dans la zone : ") .. pr.auto.value)
        end
        local HELP = {
            none = "Se charge seulement avec le bouton « Charger ».",
            zone = "Se charge en entrant dans cette zone, puis le profil chargé à la main revient en la quittant.",
            party = "Se charge en entrant en donjon, puis le profil chargé à la main revient à la sortie.",
            raid = "Se charge en entrant en raid, puis le profil chargé à la main revient à la sortie.",
            pvp = "Se charge en champ de bataille ou en arène, puis le profil chargé à la main revient à la sortie.",
            farm = "Se charge au début d'une session de farm, puis le profil chargé à la main revient à la fin.",
        }
        self.autoHelp:SetText(T(HELP[kind] or HELP.none))
        self.loadBtn:SetLabel(d.active == self.sel and T("Chargé") or T("Charger"))
        for key, b in pairs(self.catButtons) do b:SetStyle(pr.cats[key] and "primary" or "ghost") end
        self.always:Refresh(pr)
        self.never:Refresh(pr)
        self:RefreshLeft()
    end,
})
