local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

local LEFT_W = 240
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

        -- Colonne de gauche : profils + objets laissés au sol --------------------------
        local left = UI:Card(p, "Profils")
        left:SetWidth(LEFT_W)
        left:SetPoint("TOPLEFT")
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

        -- Bas de colonne : filtre activé, laissés au sol.
        self.enable = UI:Toggle(left, function() return d.enabled end, function(v) d.enabled = v; L:CheckAuto() end)
        self.enable:SetPoint("BOTTOMRIGHT", -12, 12)
        local enl = UI:Text(left, 12)
        enl:SetPoint("RIGHT", self.enable, "LEFT", -10, 0)
        enl:SetText("Filtre activé")
        self.leftCount = UI:Text(left, 11, C.muted)
        self.leftCount:SetPoint("BOTTOMLEFT", 14, 46)
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
        self.warn:SetPoint("TOPLEFT", x0, 0)
        self.warn:SetPoint("TOPRIGHT")
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
        body:SetPoint("TOPLEFT", x0, 0)
        body:SetPoint("BOTTOMRIGHT")

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

        local zone = GetRealZoneText and GetRealZoneText() or "?"
        self.autoDd = UI:Dropdown(prof, 230, 30, {
            { "none", "Activation manuelle" }, { "zone", T("Zone : ") .. zone }, { "party", "En donjon" },
            { "raid", "En raid" }, { "pvp", "En JcJ" }, { "farm", "Pendant une session de farm" },
        }, function(k)
            local pr = L:Get(self.sel)
            if pr then pr.auto = { kind = k, value = k == "zone" and (GetRealZoneText and GetRealZoneText()) or nil } end
            L:CheckAuto()
            self:Refresh()
        end)
        self.autoDd:SetPoint("TOPLEFT", 150, -98)
        local al = UI:Text(prof, 12, C.muted)
        al:SetPoint("TOPLEFT", 16, -106)
        al:SetText("Activation auto")

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
        self.body:SetPoint("TOPLEFT", LEFT_W + GAP, warn and -(44 + GAP) or 0)
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

        -- Laissés au sol
        self.recentRows:Reset()
        self.leftCount:SetText(string.format(T("Laissés au sol (session) : %d"), L.leftSession or 0))
        local room = math.floor((UI.PAGE_H + y - 120) / 24)
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
        self.autoDd:Select((pr.auto and pr.auto.kind) or "none")
        if pr.auto and pr.auto.kind == "zone" and pr.auto.value then
            self.autoDd.label:SetText(T("Zone : ") .. pr.auto.value)
        end
        self.loadBtn:SetLabel(d.active == self.sel and T("Chargé") or T("Charger"))
        for key, b in pairs(self.catButtons) do b:SetStyle(pr.cats[key] and "primary" or "ghost") end
        self.always:Refresh(pr)
        self.never:Refresh(pr)
    end,
})
