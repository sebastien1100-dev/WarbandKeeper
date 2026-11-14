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
    key = "loot", order = 5.7, nav = "Loot",
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
        local bt = UI:Text(banner, 14)
        bt:SetPoint("TOPLEFT", 52, -12)
        bt:SetText("Filtre de loot")
        self.bannerState = UI:Text(banner, 11, C.muted)
        self.bannerState:SetPoint("TOPLEFT", bt, "BOTTOMLEFT", 0, -4)
        self.bannerState:SetPoint("TOPRIGHT", banner, "TOPRIGHT", -150, -30)
        self.enable = UI:Toggle(banner, function() return d.enabled end, function(v) d.enabled = v; L:CheckAuto(); self:Refresh() end)
        self.enable:SetPoint("RIGHT", -16, 0)
        self.enableLbl = UI:Text(banner, 12)
        self.enableLbl:SetPoint("RIGHT", self.enable, "LEFT", -10, 0)
        local TOP = -(BANNER_H + GAP)

        -- Colonne de gauche : profils + objets laissés au sol --------------------------
        local left = UI:Card(p, "Profils")
        left:SetWidth(LEFT_W)
        left:SetPoint("TOPLEFT", 0, TOP)
        left:SetPoint("BOTTOMLEFT")
        local addBtn = UI:IconButton(left, "plus", 26, "Nouveau profil")
        addBtn:SetPoint("TOPRIGHT", -10, -8)
        addBtn:SetScript("OnClick", function() self.sel = L:Add(); self:Refresh() end)
        self.profileRows = UI:Pool(function()
            local b = CreateFrame("Button", nil, left)
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
            b:SetScript("OnClick", function(s) self.sel = s.index; self:Refresh() end)
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
                GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
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

        -- Liste de tous les objets laissés au sol, avec leur prix (par-dessus la colonne de droite).
        local lp = UI:Card(p, "Objets laissés au sol")
        lp:SetPoint("TOPLEFT", x0, TOP)
        lp:SetPoint("BOTTOMRIGHT")
        lp:SetFrameLevel(p:GetFrameLevel() + 40)
        lp:EnableMouse(true)
        lp:Hide()
        self.leftPanel = lp
        local close = UI:IconButton(lp, "close", 26, "Fermer la liste")
        close:SetPoint("TOPRIGHT", -10, -8)
        close:SetScript("OnClick", function() lp:Hide() end)
        self.lpSummary = UI:Text(lp, 11, C.muted)
        self.lpSummary:SetPoint("TOPLEFT", 16, -36)
        self.lpSummary:SetPoint("TOPRIGHT", -16, -36)
        self.lpSort = "value"
        local sortSeg = UI:Segmented(lp, { { "value", "Valeur" }, { "count", "Quantité" }, { "recent", "Récents" } },
            function(k) self.lpSort = k; self:RefreshLeft() end, 30)
        sortSeg:SetPoint("TOPLEFT", 12, -56)
        sortSeg:Select("value")
        local clear = UI:Button(lp, "Vider la liste", nil, 28, "ghost", "trash")
        clear:SetPoint("TOPRIGHT", -12, -57)
        clear.tooltip = "Maj + clic : remet la liste à zéro."
        clear:SetScript("OnClick", function()
            if IsShiftKeyDown() then L:ClearLeft(); self:RefreshLeft() end
        end)
        local lscroll = UI:Scroll(lp)
        lscroll:SetPoint("TOPLEFT", 10, -96)
        lscroll:SetPoint("BOTTOMRIGHT", -8, 10)
        self.lpScroll = lscroll
        self.lpEmpty = UI:Text(lp, 12, C.muted)
        self.lpEmpty:SetPoint("TOP", lscroll, "TOP", 0, -40)
        self.lpEmpty:SetText("Aucun objet laissé au sol pour l'instant.")
        self.lpRows = UI:Pool(function()
            local r = CreateFrame("Button", nil, lscroll.child)
            r:SetHeight(42)
            r.bg = UI:Rounded(r, 10, 0, "BACKGROUND", 1)
            r.bg:SetColor(unpack(C.surface2))
            r.icon = UI:RoundIcon(r, 26)
            r.icon:SetPoint("LEFT", 10, 0)
            r.add = UI:IconButton(r, "plus", 26, "Toujours ramasser cet objet (profil sélectionné)")
            r.add:SetPoint("RIGHT", -8, 0)
            r.add:SetScript("OnClick", function(b)
                local prof = L:Get(self.sel)
                if prof and b.itemID then prof.always[b.itemID] = true; prof.never[b.itemID] = nil; self:Refresh() end
            end)
            r.value = UI:Text(r, 13)
            r.value:SetPoint("TOPRIGHT", -44, -7)
            r.value:SetJustifyH("RIGHT")
            r.unit = UI:Text(r, 10, C.muted)
            r.unit:SetPoint("TOPRIGHT", r.value, "BOTTOMRIGHT", 0, -3)
            r.unit:SetJustifyH("RIGHT")
            r.name = UI:Text(r, 12)
            r.name:SetPoint("TOPLEFT", 46, -7)
            r.name:SetPoint("TOPRIGHT", -200, -7)
            r.sub = UI:Text(r, 10, C.muted)
            r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
            r.sub:SetPoint("TOPRIGHT", r.name, "BOTTOMRIGHT", 0, -3)
            r:SetScript("OnEnter", function(s)
                if not s.itemID then return end
                GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                if GameTooltip.SetItemByID then GameTooltip:SetItemByID(s.itemID)
                else GameTooltip:SetHyperlink("item:" .. s.itemID) end
                GameTooltip:Show()
            end)
            r:SetScript("OnLeave", function() GameTooltip:Hide() end)
            r:SetScript("OnClick", function(s)
                if IsShiftKeyDown() and s.itemID then
                    local _, link = WK.GetItemInfo(s.itemID)
                    if link then WK.InsertChatLink(link) end
                end
            end)
            return r
        end)

        function self:RefreshLeft()
            if not lp:IsShown() then return end
            local list, total, count, since = L:LeftList(self.lpSort)
            self.lpSummary:SetText(string.format(T("%d objets laissés · valeur %s · depuis le %s  (%s)"),
                count, UI:PlainMoney(total), date("%d/%m", since or time()), WK.modules.Value:SourceLabel()))
            self.lpRows:Reset()
            local y = 0
            for _, e in ipairs(list) do
                local r = self.lpRows:Get()
                r.itemID = e.id
                r.add.itemID = e.id
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", 0, -y)
                r:SetPoint("TOPRIGHT", 0, -y)
                local name, icon, qr, qg, qb = UI:ItemInfo(e.id)
                r.icon:SetTexture(icon)
                r.name:SetText(e.name or name)
                r.name:SetTextColor(qr or 1, qg or 1, qb or 1)
                r.sub:SetText(string.format(T("x%d  ·  %d fois  ·  dernière fois %s"), e.n, e.times or 1, UI:Ago(e.last or time())))
                if e.unit > 0 then
                    r.value:SetText(UI:GoldText(e.value))
                    r.unit:SetText(string.format(T("%s l'unité"), UI:PlainMoney(e.unit)))
                else
                    r.value:SetText(UI:Hex(C.dim) .. "-|r")
                    r.unit:SetText(T("pas de prix"))
                end
                y = y + 46
            end
            self.lpScroll:SetContentHeight(y)
            self.lpEmpty:SetShown(#list == 0)
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

        local ql = UI:Text(prof, 12, C.muted)
        ql:SetPoint("TOPLEFT", 16, -66)
        ql:SetText("Qualité minimale")
        self.quality = UI:Dropdown(prof, 200, 30, QUALITIES, function(v)
            local pr = L:Get(self.sel); if pr then pr.minQuality = v; self:Refresh() end
        end)
        self.quality:SetPoint("TOPLEFT", 150, -58)
        local vl = UI:Text(prof, 12, C.muted)
        vl:SetPoint("LEFT", self.quality, "RIGHT", 20, 0)
        vl:SetText("Valeur minimale")
        self.value = UI:NumberInput(prof, 90, 30, "0")
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
        self.keepRules:SetPoint("TOPLEFT", 16, -142)
        local kl = UI:Text(prof, 12)
        kl:SetPoint("LEFT", self.keepRules, "RIGHT", 10, 0)
        kl:SetText("Toujours les objets de mes règles d'envoi et de dépôt")
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
        self.autoDd:SetPoint("TOPLEFT", 150, -98)
        local al = UI:Text(prof, 12, C.muted)
        al:SetPoint("TOPLEFT", 16, -106)
        al:SetText("Se charge tout seul")
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
        local y = -40
        for i, pr in ipairs(profiles) do
            local b = self.profileRows:Get()
            b.index = i
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", 8, y)
            b:SetPoint("TOPRIGHT", -8, y)
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

        -- Laissés au sol
        self.recentRows:Reset()
        self.leftCount:SetText(string.format(T("Session : %d laissés"), L.leftSession or 0))
        local room = math.floor((UI.PAGE_H - BANNER_H - GAP + y - 122) / 24)
        local recent = d.recent or {}
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
