local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors

-- Disposition « barre latérale groupée » : groupes de pages à gauche (repliable en icônes),
-- en-tête de page et contenu à droite. Fenêtre redimensionnable par la poignée en bas à droite.
local DEFAULT_W, DEFAULT_H = 1120, 660
local SIDE_W, RAIL_W = 196, 60     -- barre latérale dépliée / repliée en icônes
local PAD = 18
local TOP = 64                      -- hauteur de l'en-tête de page (titre + boutons)
local MIN_PAGE_W = 840              -- largeur minimale de contenu (les pages sont conçues pour ça)
local MIN_H = 600

-- Groupes de la barre latérale (clés de pages) et icônes.
-- Résumé (HOME_PAGE) est à part, tout en haut, jamais replié ; puis les groupes (titre, icône, pages).
local HOME_PAGE = "overview"
local GROUPS = {
    -- « qol:<section> » : une section de la page QoL, rangée avec le thème qui va avec
    { "MES PERSOS", { "characters", "inventory", "qol:classes", "qol:xp" }, "logo" },
    { "ARGENT", { "stats", "mail", "auction", "journal" }, "coin" },
    { "ARTISANAT", { "professions", "fishing", "qol:campfire" }, "hammer" },
    { "FARM", { "farm", "loot" }, "bag" },
    { "AVENTURE", { "quests", "rares", "dungeons", "lfg", "qol:maplayers" }, "map" },
    { "INTERFACE", { "qol:general", "qol:halo", "qol:cursor", "qol:micro" }, "gear" },
}
local BOTTOM = { "options" }
local ICONS = {
    overview = "home", characters = "users", inventory = "bag", stats = "chart", professions = "hammer",
    mail = "mail", auction = "coin", farm = "play", loot = "filter", journal = "clock", notes = "notes", options = "gear", qol = "spark", lfg = "lfg", profiles = "users", rares = "star", quests = "bang", fishing = "fish", dungeons = "skull",
}
local LABELS = { notes = "Patch notes", options = "Options", farm = "Session de farm" }

local function sideWidth()
    local g = WK.DB and WK.DB.global -- pas encore chargé au chargement du fichier
    return (g and g.settings.ui.collapsed) and RAIL_W or SIDE_W
end

-- Dimensions de la zone de page, recalculées à chaque mise en page.
local function computePageSize(w, h)
    UI.PAGE_W = w - sideWidth() - 2 * PAD
    UI.PAGE_FULL_H = h - TOP - PAD
    UI.PAGE_H = UI.PAGE_FULL_H
end
computePageSize(DEFAULT_W, DEFAULT_H)

---------------------------------------------------------------------------
-- Enregistrement des pages
-- def = { key, nav, title, subtitle, order, count(), Build(page, frame), Refresh(page) }
---------------------------------------------------------------------------
function UI:RegisterPage(def)
    self.pages[def.key] = def
    table.insert(self.pageOrder, def)
    table.sort(self.pageOrder, function(a, b) return (a.order or 99) < (b.order or 99) end)
end

---------------------------------------------------------------------------
-- Élément de la barre latérale (icône + libellé + compteur).
---------------------------------------------------------------------------
-- Pastille de nombre (comme dans l'échelle du LFG) : fond d'accent, chiffre foncé ; cachée si vide.
local function CountPill(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(22, 16)
    p:SetPoint("RIGHT", -10, 0)
    p.bg = UI:Rounded(p, 8, 0, "ARTWORK", 1)
    p.t = UI:Text(p, 10, C.onAccent)
    p.t:SetPoint("CENTER", 0, 0)
    p.val = ""
    function p:SetText(v)
        self.val = v or ""
        self.t:SetText(self.val)
        self:SetWidth(math.max(22, (self.t:GetStringWidth() or 8) + 12))
        local r, g, b = UI:Accent()
        self.bg:SetColor(r, g, b, 1)
        self:SetShown(self.val ~= "" and not self.off)
    end
    function p:Allow(on)
        self.off = not on
        self:SetShown(self.val ~= "" and on)
    end
    UI:OnAccent(function() local r, g, b = UI:Accent(); p.bg:SetColor(r, g, b, 1) end)
    return p
end

-- Entrée de la barre latérale selon l'habillage : Héraldique (barre pleine, entrée choisie de la couleur de la
-- page), Encre (pas de fond, trait d'accent), sinon fond en relief
local WHITE, WHITE_DIM = { 1, 1, 1, 1 }, { 1, 1, 1, 0.72 }
local function paintNav(self, sel)
    local skin = UI.skin
    if skin == "heraldic" then
        self.bg:SetColor(unpack(sel and C.bg or { 1, 1, 1, 0.10 }))
        self.bg:SetShown(sel or self.hover)
        self.bar:SetShown(false)
        if sel then self.icon:SetVertexColor(UI:Accent()) else self.icon:SetVertexColor(unpack(WHITE_DIM)) end
        self.label:SetTextColor(unpack((sel or self.hover) and WHITE or WHITE_DIM))
        return
    end
    self.bg:SetColor(unpack(sel and C.surface2 or C.hover))
    self.bg:SetShown((sel and skin ~= "ink") or self.hover)
    self.bar:SetShown(sel)
    self.barTex:SetColor(UI:Accent())
    if sel then self.icon:SetVertexColor(UI:Accent()) else self.icon:SetVertexColor(unpack(C.muted)) end
    self.label:SetTextColor(unpack((sel or self.hover) and C.text or C.muted))
end

local function NavItem(parent, def)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(34)
    b.bg = UI:Rounded(b, 10, 0, "BACKGROUND", 2)
    b.bar = CreateFrame("Frame", nil, b)
    b.bar:SetSize(3, 18)
    b.bar:SetPoint("LEFT")
    b.barTex = UI:Rounded(b.bar, 1.5, 0, "ARTWORK", 1)
    b.icon = UI:Icon(b, ICONS[def.key] or "circle", 16)
    b.icon:SetPoint("LEFT", 14, 0)
    b.label = UI:Text(b, 13)
    b.label:SetPoint("LEFT", 40, 0)
    b.label:SetPoint("RIGHT", -24, 0)
    b.label:SetText(LABELS[def.key] or def.nav or def.title)
    b.count = CountPill(b)

    function b:Refresh()
        local sel = UI.current == def.key or (def.key == "characters" and UI.current == "charsheet")
        paintNav(self, sel)
        local collapsed = WK.DB.global.settings.ui.collapsed
        self.label:SetShown(not collapsed)
        self.count:Allow(not collapsed)
    end
    b:SetScript("OnEnter", function(self)
        self.hover = true; self:Refresh()
        if WK.DB.global.settings.ui.collapsed then
            WK.UI:TooltipOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.label:GetText(), 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self) self.hover = false; self:Refresh(); GameTooltip:Hide() end)
    b:SetScript("OnClick", function() UI:ShowPage(def.key) end)
    UI:OnAccent(function() b:Refresh() end)
    return b
end

---------------------------------------------------------------------------
-- Titre de groupe cliquable : replie ou déplie le groupe (settings.ui.navClosed[groupe]) ;
-- replié, il montre le total des pastilles de ses pages.
---------------------------------------------------------------------------
local function GroupHead(parent, name, icon)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(20)
    b.name = name
    -- petite icône de la couleur de l'apparence devant le titre
    b.gicon = UI:Icon(b, icon or "circle", 11)
    b.gicon:SetPoint("LEFT", 9, 0)
    b.label = UI:Text(b, 10, C.dim)
    b.label:SetPoint("LEFT", 26, 0)
    b.label:SetText(WK.T(name))
    b.chev = UI:Icon(b, "chevron", 11)
    b.chev:SetPoint("RIGHT", -12, 0)
    b.sum = CountPill(b)
    b.sum:ClearAllPoints()
    b.sum:SetPoint("RIGHT", b.chev, "LEFT", -6, 0)
    function b:Refresh()
        local closed = WK.DB.global.settings.ui.navClosed[name]
        local r, g, bl = UI:Accent()
        self.gicon:SetVertexColor(r, g, bl, 1)
        self.chev:SetVertexColor(r, g, bl, self.hover and 1 or 0.8)
        if self.chev.SetRotation then self.chev:SetRotation(closed and math.pi / 2 or 0) end
        if UI.skin == "heraldic" then
            self.gicon:SetVertexColor(1, 1, 1, 0.6); self.chev:SetVertexColor(1, 1, 1, self.hover and 1 or 0.6)
            self.label:SetTextColor(1, 1, 1, self.hover and 0.95 or 0.55)
        elseif self.hover then self.label:SetTextColor(r, g, bl, 1) else self.label:SetTextColor(unpack(closed and C.muted or C.dim)) end
    end
    b:SetScript("OnEnter", function(s) s.hover = true; s:Refresh() end)
    b:SetScript("OnLeave", function(s) s.hover = false; s:Refresh() end)
    b:SetScript("OnClick", function(s)
        local nc = WK.DB.global.settings.ui.navClosed
        nc[name] = not nc[name] or nil
        if UI.layoutTop then UI.layoutTop() end
        UI:Refresh()
    end)
    UI:OnAccent(function() b:Refresh() end)
    return b
end

-- Sous-entrée de « QoL » : une section de la page (Général, Halo, … Classes).
local function SubItem(parent, sec)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(34)
    b.key = sec[1]
    b.bg = UI:Rounded(b, 10, 0, "BACKGROUND", 2)
    b.bar = CreateFrame("Frame", nil, b)
    b.bar:SetSize(3, 18)
    b.bar:SetPoint("LEFT")
    b.barTex = UI:Rounded(b.bar, 1.5, 0, "ARTWORK", 1)
    b.icon = UI:Icon(b, sec[3] or "circle", 16)
    b.icon:SetPoint("LEFT", 14, 0)
    b.label = UI:Text(b, 13)
    b.label:SetPoint("LEFT", 40, 0)
    b.label:SetPoint("RIGHT", -24, 0)
    b.label:SetText(WK.T(sec[2]))
    b.count = UI:Text(b, 10, C.warning)
    b.count:SetPoint("RIGHT", -10, 0)
    -- alertes de la section : une petite icône par genre (coffre-fort = banque pleine, sac = sacs
    -- pleins, marteau = réparer…), rouge si urgent, orange sinon ; le détail en infobulle
    local KIND_ICON = { durability = "hammer", reagent = "spark", ammo = "spark", poison = "spark", pet = "star" }
    b.alerts = {}
    for i = 1, 3 do
        local t = UI:Icon(b, "safe", 14, nil, "OVERLAY")
        t:SetPoint("RIGHT", -8 - (i - 1) * 17, 0)
        t:Hide()
        b.alerts[i] = t
    end
    function b:PaintAlerts(rail)
        local list = UI.QoLSectionAlerts and UI:QoLSectionAlerts(self.key) or {}
        local kinds, seen = {}, {}
        for _, a in ipairs(list) do
            local ic = (a.kind == "bags" and a.bank) and "safe" or (a.kind == "bags" and "bag") or KIND_ICON[a.kind] or "bang"
            if not seen[ic] then seen[ic] = { icon = ic, urgent = a.urgent or (a.kind == "bags" and a.bank and true) }; table.insert(kinds, seen[ic])
            elseif a.urgent then seen[ic].urgent = true end
        end
        self.alertList = list
        for i, t in ipairs(self.alerts) do
            local k = kinds[i]
            t:SetShown(false) -- plus d'icônes d'alerte dans le menu (coffre, sac…) : détail au survol seulement
            if k then
                t:SetTexture(UI.MEDIA .. k.icon)
                t:SetVertexColor(unpack(k.urgent and C.negative or C.warning))
            end
        end
    end
    function b:Refresh()
        local sel = UI.current == "qol" and UI.QoLCurrentSection and UI:QoLCurrentSection() == self.key
        paintNav(self, sel)
        local rail = WK.DB.global.settings.ui.collapsed
        self.label:SetShown(not rail)
        self.count:Hide()
        self:PaintAlerts(rail)
    end
    b:SetScript("OnEnter", function(s)
        s.hover = true; s:Refresh()
        local rail = WK.DB.global.settings.ui.collapsed
        if rail or (s.alertList and #s.alertList > 0) then
            WK.UI:TooltipOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetText(s.label:GetText(), 1, 1, 1)
            for _, a in ipairs(s.alertList or {}) do
                local col = a.urgent and C.negative or C.warning
                GameTooltip:AddLine(a.text, col[1], col[2], col[3], true)
            end
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(s) s.hover = false; s:Refresh(); GameTooltip:Hide() end)
    b:SetScript("OnClick", function(s)
        UI:ShowPage("qol")
        local P = UI.pages.qol
        if P and P.ShowSection then P:ShowSection(s.key) end
        UI:Refresh()
    end)
    UI:OnAccent(function() b:Refresh() end)
    return b
end

---------------------------------------------------------------------------
-- Construction de la fenêtre
---------------------------------------------------------------------------
local createWindow
function UI:Create()
    if self.frame then return self.frame end
    -- crochets d'accent de la fenêtre : retirés par UI:Rebuild (pas ceux des éléments à l'écran)
    return self:InAccentScope("window", createWindow, self)
end
createWindow = function(self)
    local cfg = WK.DB.global.settings.ui

    local f = CreateFrame("Frame", "WarbandKeeperFrame", UIParent)
    self.frame = f
    local minW = MIN_PAGE_W + SIDE_W + 2 * PAD
    local size = cfg.size or { DEFAULT_W, DEFAULT_H }
    f:SetSize(math.max(minW, size[1]), math.max(MIN_H, size[2]))
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:SetResizable(true)
    local maxW, maxH = (UIParent:GetWidth() or 1920), (UIParent:GetHeight() or 1080)
    if f.SetResizeBounds then
        f:SetResizeBounds(minW, MIN_H, math.max(minW, maxW), math.max(MIN_H, maxH))
    elseif f.SetMinResize then
        f:SetMinResize(minW, MIN_H)
        if f.SetMaxResize then f:SetMaxResize(math.max(minW, maxW), math.max(MIN_H, maxH)) end
    end
    f:EnableMouse(true)
    f:SetScale(cfg.scale or 1)
    if cfg.point then
        f:SetPoint(cfg.point[1], UIParent, cfg.point[2], cfg.point[3], cfg.point[4])
    else
        f:SetPoint("CENTER")
    end
    f:Hide()
    -- fermeture avec Échap (une seule fois : la fenêtre est refaite à chaque UI:Rebuild)
    local listed = false
    for _, n in ipairs(UISpecialFrames) do if n == "WarbandKeeperFrame" then listed = true end end
    if not listed then table.insert(UISpecialFrames, "WarbandKeeperFrame") end

    -- Cadre : bordure dorée, liseré, bordure intérieure, fond.
    UI:Rounded(f, 16, 0, "BACKGROUND", -8):SetColor(unpack(C.frame))
    UI:Rounded(f, 15, 1, "BACKGROUND", -7):SetColor(unpack(C.inset))
    UI:Rounded(f, 12, 4, "BACKGROUND", -6):SetColor(unpack(C.trim))
    UI:Rounded(f, 11, 5, "BACKGROUND", -5):SetColor(unpack(C.bg))
    -- Halo en haut, qui suit les coins arrondis.
    -- halo : intensité réglable (Options > Apparence, settings.ui.glow, 0 à 2 ; 1 = d'origine)
    local GH, GA, R = 220, 0.65 * math.max(0, math.min(2, cfg.glow or 1)), 11
    local gr, gg, gb = C.glow[1], C.glow[2], C.glow[3]
    local glow = f:CreateTexture(nil, "BACKGROUND", nil, -4)
    glow:SetPoint("TOPLEFT", 5 + R, -5)
    glow:SetPoint("TOPRIGHT", -5 - R, -5)
    glow:SetHeight(GH)
    UI:SetGradient(glow, "VERTICAL", { gr, gg, gb, 0 }, { gr, gg, gb, GA })
    local topA = GA * (GH - R) / GH
    for _, side in ipairs({ "LEFT", "RIGHT" }) do
        local strip = f:CreateTexture(nil, "BACKGROUND", nil, -4)
        strip:SetPoint("TOP" .. side, side == "LEFT" and 5 or -5, -5 - R)
        strip:SetSize(R, GH - R)
        UI:SetGradient(strip, "VERTICAL", { gr, gg, gb, 0 }, { gr, gg, gb, topA })
        local corner = f:CreateTexture(nil, "BACKGROUND", nil, -4)
        corner:SetTexture(UI.MEDIA .. "circle")
        corner:SetTexCoord(side == "LEFT" and 0 or 0.5, side == "LEFT" and 0.5 or 1, 0, 0.5)
        corner:SetSize(R, R)
        corner:SetPoint("TOP" .. side, side == "LEFT" and 5 or -5, -5)
        corner:SetVertexColor(gr, gg, gb, GA)
    end

    -- fond texturé (Options > Apparence) : texture du jeu très discrète par-dessus le fond uni
    local BG_TEX = {
        grain = "Interface\\DialogFrame\\UI-DialogBox-Background",
        stone = "Interface\\FrameGeneral\\UI-Background-Rock",
        parchment = "Interface\\QuestFrame\\QuestBG",
    }
    if BG_TEX[cfg.bgTexture or ""] then
        local tx = f:CreateTexture(nil, "BORDER", nil, -8)
        tx:SetTexture(BG_TEX[cfg.bgTexture])
        tx:SetPoint("TOPLEFT", 9, -9); tx:SetPoint("BOTTOMRIGHT", -9, 9)
        if tx.SetDesaturated then tx:SetDesaturated(true) end
        tx:SetVertexColor(1, 1, 1, cfg.bgTexture == "parchment" and 0.07 or 0.12)
    end

    local function startMove() f:StartMoving() end
    local function stopMove()
        f:StopMovingOrSizing()
        local p, _, rp, x, y = f:GetPoint()
        cfg.point = { p, rp, x, y }
    end

    -- Barre latérale ----------------------------------------------------------------
    local side = CreateFrame("Frame", nil, f)
    self.side = side
    side:SetPoint("TOPLEFT", 5, -5)
    side:SetPoint("BOTTOMLEFT", 5, 5)
    side:EnableMouse(true)
    side:RegisterForDrag("LeftButton")
    side:SetScript("OnDragStart", startMove)
    side:SetScript("OnDragStop", stopMove)
    local sideBg = side:CreateTexture(nil, "BACKGROUND", nil, -3)
    sideBg:SetAllPoints()
    if UI.skin == "heraldic" then
        -- Héraldique : barre latérale pleine, couleur de l'accent assombrie
        UI:OnAccent(function()
            local r, g, b = UI:Accent()
            sideBg:SetColorTexture(1, 1, 1, 1)
            UI:SetGradient(sideBg, "VERTICAL", { r * 0.32, g * 0.32, b * 0.32, 1 }, { r * 0.5, g * 0.5, b * 0.5, 1 })
        end)
    elseif UI.skin == "ink" then
        sideBg:SetColorTexture(0, 0, 0, 0)
    else
        sideBg:SetColorTexture(0, 0, 0, 0.18)
    end
    local sep = side:CreateTexture(nil, "BORDER")
    sep:SetColorTexture(unpack(C.border))
    sep:SetWidth(1)
    sep:SetPoint("TOPRIGHT"); sep:SetPoint("BOTTOMRIGHT")
    self.sideSep = sep

    local tile = CreateFrame("Frame", nil, side)
    tile:SetSize(36, 36)
    tile:SetPoint("TOPLEFT", 9, -12)
    local tileBg = UI:Rounded(tile, 11, 0, "BACKGROUND", 1)
    local logo = UI:Icon(tile, "logo", 24, C.onAccent)
    logo:SetPoint("CENTER")
    UI:OnAccent(function() if UI.skin == "heraldic" then tileBg:SetColor(unpack(C.bg)) else tileBg:SetColor(UI:Accent()) end end)
    local title = side:CreateFontString(nil, "OVERLAY")
    title:SetFont(UI.TITLE_FONT, 15, "")
    title:SetText("Warband Keeper")
    title:SetPoint("TOPLEFT", tile, "TOPRIGHT", 10, 0)
    UI:OnAccent(function() if UI.skin == "heraldic" then title:SetTextColor(1, 1, 1) else title:SetTextColor(UI:Accent()) end end)
    local ver = UI:Text(side, 10, C.muted)
    if UI.skin == "heraldic" then ver:SetTextColor(1, 1, 1, 0.6) end
    ver:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    ver:SetText("v" .. WK.version)
    self.sideTitle, self.sideVer = title, ver
    if UI.BuildSideSearch then UI:BuildSideSearch(side) end -- recherche (UI/Search.lua)

    self.nav, self.groupLabels, self.navSubs = {}, {}, {}
    cfg.navClosed = cfg.navClosed or {}
    -- Haut de la barre : groupes et pages. Placés par layoutTop() : l'espacement se resserre
    -- quand la fenêtre est basse, pour ne jamais chevaucher le bas (notes, options, repli).
    -- Zone du haut : coupée au-dessus du bas de la barre (notes, profils, options) ; si la liste reste
    -- trop longue une fois resserrée, elle défile à la molette au lieu de chevaucher le bas.
    local navScroll = CreateFrame("ScrollFrame", nil, side)
    local navChild = CreateFrame("Frame", nil, navScroll)
    navChild:SetSize(1, 1)
    navScroll:SetScrollChild(navChild)
    navScroll:EnableMouseWheel(true)
    navScroll:SetScript("OnMouseWheel", function(s, delta)
        local max = s.maxScroll or 0
        s:SetVerticalScroll(math.max(0, math.min(max, (s:GetVerticalScroll() or 0) - delta * 36)))
    end)
    self.navScroll = navScroll
    local topList = {}
    -- Résumé : à part, en haut, puis un trait
    if self.pages[HOME_PAGE] then
        local item = NavItem(navChild, self.pages[HOME_PAGE])
        self.nav[HOME_PAGE] = item
        table.insert(topList, { item = item, key = HOME_PAGE })
        local sep = navChild:CreateTexture(nil, "ARTWORK")
        sep:SetHeight(1)
        sep:SetColorTexture(unpack(C.border))
        table.insert(topList, { sep = sep })
    end
    for _, g in ipairs(GROUPS) do
        local lbl = GroupHead(navChild, g[1], g[3])
        table.insert(self.groupLabels, lbl)
        local head = { label = lbl, items = {}, name = g[1] }
        table.insert(topList, head)
        for _, key in ipairs(g[2]) do
            local secKey = key:match("^qol:(.+)$")
            local def = self.pages[secKey and "qol" or key]
            if def and secKey then
                -- section de la page QoL, comme une entrée du groupe
                local sec
                for _, s2 in ipairs(UI.QOL_SECTIONS or {}) do if s2[1] == secKey then sec = s2 end end
                if sec then
                    table.insert(head.items, { key = "qol" })
                    local sub = SubItem(navChild, sec)
                    self.navSubs[sec[1]] = sub
                    table.insert(topList, { item = sub, key = "qol", section = sec[1], group = head, sub = true })
                end
            elseif def then
                local item = NavItem(navChild, def)
                self.nav[key] = item
                local e = { item = item, key = key, group = head }
                table.insert(head.items, e)
                table.insert(topList, e)
            end
        end
    end
    local function layoutTop(h)
        -- modules coupés (Core/Features.lua) : leur page et, s'il est vide, leur groupe disparaissent
        local nLabels, nItems = 0, 0
        local rail = WK.DB.global.settings.ui.collapsed -- menu réduit en icônes : tout reste visible
        for _, e in ipairs(topList) do
            if e.sep then
                e.hidden = rail
                e.sep:SetShown(not rail)
            elseif e.label then
                e.hidden = true
                for _, it in ipairs(e.items) do if WK:PageOn(it.key) then e.hidden = false end end
                e.label.wkHidden = e.hidden
                e.label:SetShown(not e.hidden and not rail)
                if not e.hidden then nLabels = nLabels + 1 end
            else
                -- groupe replié : ses pages sont cachées (sauf celle qui est affichée)
                local closed = not rail and e.group and cfg.navClosed[e.group.name] and UI.current ~= e.key
                if e.sub then
                    -- section de QoL : cachée si son module est coupé, ou groupe replié (sauf la section affichée)
                    local fk = WK.FEATURE_BY_QOL and WK.FEATURE_BY_QOL[e.section]
                    local shownNow = UI.current == "qol" and UI.QoLCurrentSection and UI:QoLCurrentSection() == e.section
                    e.hidden = not WK:PageOn("qol") or (fk and not WK:FeatureOn(fk))
                        or (not rail and cfg.navClosed[e.group.name] and not shownNow)
                else
                    e.hidden = not WK:PageOn(e.key) or closed
                end
                e.item:SetShown(not e.hidden)
                if not e.hidden then nItems = nItems + 1 end
            end
        end
        local bottomH = 42                              -- bouton de repli (notes, profils, options : dans l'en-tête)
        local avail = (h or 600) - ((WK.DB.global.settings.ui.collapsed or not UI.sideSearch) and 64 or 98) - bottomH
        local labelStep, itemStep, gap = 26, 36, 4
        local need = nLabels * (labelStep + gap) + nItems * itemStep
        if need > avail then
            -- les titres de groupe se resserrent plus que les entrées (qui restent cliquables)
            local k = math.max(0.4, avail / need)
            -- (au-delà, la liste défile à la molette : les titres de groupe restent lisibles et cliquables)
            labelStep, itemStep, gap = math.max(18, math.floor(26 * k)), math.max(26, math.floor(36 * k)), math.max(2, math.floor(4 * k))
        end
        -- sous la recherche quand la barre est dépliée
        local topY = (WK.DB.global.settings.ui.collapsed or not UI.sideSearch) and 64 or 98
        navScroll:ClearAllPoints()
        navScroll:SetPoint("TOPLEFT", side, "TOPLEFT", 0, -topY)
        navScroll:SetPoint("BOTTOMRIGHT", side, "BOTTOMRIGHT", 0, bottomH)
        navChild:SetWidth(math.max(1, side:GetWidth() or 1))
        local y, first = 0, true
        for _, e in ipairs(topList) do
            if e.hidden then
                -- rien
            elseif e.sep then
                e.sep:ClearAllPoints()
                e.sep:SetPoint("TOPLEFT", 14, y - 5)
                e.sep:SetPoint("TOPRIGHT", -14, y - 5)
                y = y - 10
            elseif e.label then
                if not first then y = y - gap end
                first = false
                e.label:ClearAllPoints()
                e.label:SetPoint("TOPLEFT", 8, y - math.floor(labelStep * 0.3) + 4)
                e.label:SetPoint("TOPRIGHT", -8, y - math.floor(labelStep * 0.3) + 4)
                y = y - labelStep
            else
                e.item:SetHeight(math.min(34, itemStep - 2))
                e.item:ClearAllPoints()
                e.item:SetPoint("TOPLEFT", 8, y)
                e.item:SetPoint("TOPRIGHT", -8, y)
                e.top, e.h = -y, itemStep
                y = y - itemStep
            end
        end
        navChild:SetHeight(math.max(1, -y))
        navScroll.maxScroll = math.max(0, -y - math.max(0, avail))
        -- l'entrée affichée (page, ou section de QoL) reste dans la partie visible de la liste
        local scroll = math.min(navScroll:GetVerticalScroll() or 0, navScroll.maxScroll)
        local curSec = UI.current == "qol" and UI.QoLCurrentSection and UI:QoLCurrentSection()
        for _, e in ipairs(topList) do
            if not e.hidden and e.top and ((e.sub and e.section == curSec) or (not e.sub and not curSec and e.key == UI.current)) then
                if e.top + e.h > scroll + avail then scroll = math.min(navScroll.maxScroll, e.top + e.h - avail + 4) end
                if e.top < scroll then scroll = math.max(0, e.top - 4) end
            end
        end
        navScroll:SetVerticalScroll(scroll)
    end
    side:HookScript("OnSizeChanged", function(_, _, h) layoutTop(h) end)
    self.layoutTop = function() layoutTop(side:GetHeight()) end
    UI.layoutTop = self.layoutTop
    layoutTop(side:GetHeight())

    -- Bas de la barre : notes, options, repli.
    local collapse = CreateFrame("Button", nil, side)
    collapse:SetHeight(28)
    collapse:SetPoint("BOTTOMLEFT", 8, 10)
    collapse:SetPoint("BOTTOMRIGHT", -8, 10)
    collapse.icon = UI:Icon(collapse, "arrow", 14, C.dim)
    collapse.icon:SetPoint("LEFT", 15, 0)
    collapse.label = UI:Text(collapse, 11, C.dim)
    collapse.label:SetPoint("LEFT", 40, 0)
    collapse:SetScript("OnClick", function()
        cfg.collapsed = not cfg.collapsed
        UI:Relayout()
    end)
    collapse:SetScript("OnEnter", function(s) s.label:SetTextColor(unpack(C.text)) end)
    collapse:SetScript("OnLeave", function(s) s.label:SetTextColor(unpack(C.dim)) end)
    self.collapseBtn = collapse

    -- En-tête de page -----------------------------------------------------------------
    local header = CreateFrame("Frame", nil, f)
    self.header = header
    header:SetPoint("TOPRIGHT", -5, -5)
    header:SetHeight(TOP - 10)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", startMove)
    header:SetScript("OnDragStop", stopMove)
    -- Pastilles d'infos utiles de la page (voir UI.CHIPS plus bas).
    self.chips = UI:Pool(function()
        local c = CreateFrame("Button", nil, header)
        c:SetHeight(26)
        UI:Panel(c, 13, C.surface, C.border)
        c.label = UI:Text(c, 11, C.muted)
        c.label:SetPoint("LEFT", 12, 0)
        c.value = UI:Text(c, 12)
        c.value:SetPoint("LEFT", c.label, "RIGHT", 6, 0)
        c:SetScript("OnEnter", function(s)
            if s.page then s.border:SetColor(UI:Accent()) end
            if s.tip then
                WK.UI:TooltipOwner(s, "ANCHOR_BOTTOM")
                GameTooltip:SetText(s.tip, 1, 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        c:SetScript("OnLeave", function(s) s.border:SetColor(unpack(C.border)); GameTooltip:Hide() end)
        c:SetScript("OnClick", function(s)
            if s.page then
                UI:ShowPage(s.page)
                if s.after and UI.current == s.page then s.after() end
            end
        end)
        return c
    end)
    local close = UI:IconButton(header, "close", 30, nil, "accent")
    close:SetPoint("RIGHT", -(PAD - 9), 0)
    close:SetScript("OnClick", function() f:Hide() end)
    -- Recharger l'interface (/reload)
    local reload = UI:IconButton(header, "power", 30, "Recharger l'interface (/reload)")
    reload:SetPoint("RIGHT", close, "LEFT", -4, 0)
    -- /reload par un bouton protégé posé dessus (ReloadUI est bloqué pour les addons sur ce client)
    UI:SecureReload(reload)
    -- Patch notes, Profils, Options : icônes à droite, avec recharger et fermer (point = notes pas encore lues)
    self.headIcons = {}
    local prevIcon = reload
    for i = #BOTTOM, 1, -1 do
        local def = self.pages[BOTTOM[i]]
        if def then
            local ib = UI:IconButton(header, ICONS[def.key] or "circle", 30, LABELS[def.key] or def.nav or def.title)
            ib:SetPoint("RIGHT", prevIcon, "LEFT", -4, 0)
            -- point allumé : le clic mène droit à ce qu'il signale (patch notes non lues, erreur pas vue)
            ib:SetScript("OnClick", function()
                local n = def.count and def.count() or ""
                if def.key == "options" and n == "!" then
                    WK.DB.global.settings.ui.optSection = "maint"; UI:ShowPage("options")
                    local od = UI.pages.options
                    if od and od.ShowSection then od:ShowSection("maint") end
                elseif def.key == "options" and n ~= "" then
                    UI:ShowPage("notes")
                else
                    UI:ShowPage(def.key)
                end
            end)
            ib.baseTip = LABELS[def.key] or def.nav or def.title
            ib.dot = UI:Icon(ib, "circle", 7, nil, "OVERLAY")
            ib.dot:SetPoint("TOPRIGHT", -4, -4)
            ib.dot:Hide()
            ib.def = def
            self.headIcons[def.key] = ib
            prevIcon = ib
        end
    end
    -- puis le bouton Éditer (mode édition, sur toutes les pages) ; plus de bouton Scan : le perso est
    -- relu tout seul (connexion, sacs, or, métiers)
    local editBtn = UI:Button(header, "Éditer", nil, 28, "primary")
    editBtn:SetPoint("RIGHT", prevIcon, "LEFT", -10, 0)
    editBtn.tooltip = "Placer et redimensionner les éléments à l'écran (aussi : /wk edit)."
    editBtn:SetScript("OnClick", function() UI:EnterEditMode() end)
    self.editBtn = editBtn
    self.headLeft = editBtn
    -- Mise à jour disponible (client PC ou version vue chez un autre joueur) : bouton à gauche des icônes
    local upd = UI:Button(header, "Mise à jour", nil, 28, "secondary", "refresh")
    upd:SetPoint("RIGHT", editBtn, "LEFT", -8, 0)
    upd:HookScript("OnEnter", function(s)
        local v, src = WK.modules.Version:Available()
        if not v then return end
        UI:TooltipOwner(s, "ANCHOR_BOTTOM")
        GameTooltip:SetText(string.format(WK.T("Warband Keeper %s est sortie"), v), 1, 1, 1)
        GameTooltip:AddLine(string.format(WK.T("Tu as la version %s."), WK.version), 0.8, 0.8, 0.8)
        local from = src == "client" and WK.T("Vue par le client PC Warband Keeper.")
            or src == "guild" and WK.T("Vue chez un joueur de ta guilde.") or WK.T("Vue chez un joueur de ton groupe.")
        GameTooltip:AddLine(from, 0.6, 0.6, 0.6)
        GameTooltip:AddLine(WK.T("Installe-la avec le client PC (Accueil > Mettre à jour), puis relance le jeu."), 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    upd:HookScript("OnLeave", function() GameTooltip:Hide() end)
    upd:SetScript("OnClick", function()
        local v = WK.modules.Version:Available()
        if v then WK:Print(string.format(WK.T("Version %s disponible : installe-la avec le client PC Warband Keeper, puis relance le jeu."), v)) end
    end)
    upd:Hide()
    self.updBtn = upd

    self.pageHost = CreateFrame("Frame", nil, f)
    -- Les pages sont élastiques : elles suivent la taille en direct (UI:OnResize).
    self.pageHost:SetScript("OnSizeChanged", function(_, w, h)
        if w and w > 0 then UI.PAGE_W, UI.PAGE_FULL_H, UI.PAGE_H = w, h, h end
        UI:RefreshChips() -- pastilles de l'en-tête : autant qu'il en tient
    end)

    -- Poignée de redimensionnement ---------------------------------------------------------
    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(18, 18)
    grip:SetPoint("BOTTOMRIGHT", -7, 7)
    grip:SetFrameLevel(f:GetFrameLevel() + 20)
    local gt = UI:Icon(grip, "grip", 16, C.dim)
    gt:SetPoint("CENTER")
    grip:SetScript("OnEnter", function()
        gt:SetVertexColor(UI:Accent())
        WK.UI:TooltipOwner(grip, "ANCHOR_TOP")
        GameTooltip:SetText(WK.T("Glisser pour redimensionner"), 1, 1, 1)
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function() gt:SetVertexColor(unpack(C.dim)); GameTooltip:Hide() end)
    grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        cfg.size = { math.floor(f:GetWidth() + 0.5), math.floor(f:GetHeight() + 0.5) }
        local p, _, rp, x, y = f:GetPoint()
        cfg.point = { p, rp, x, y }
        UI:Refresh()
    end)

    f:SetScript("OnShow", function(s)
        UI:Refresh()
        -- animation (Options > Apparence) : fondu à l'ouverture, 0,15 s
        if WK.DB.global.settings.ui.anim ~= "none" then
            s:SetAlpha(0)
            s.fadeT = 0
            s:SetScript("OnUpdate", function(x, el)
                x.fadeT = x.fadeT + el
                local a = math.min(1, x.fadeT / 0.15)
                x:SetAlpha(a)
                if a >= 1 then x:SetScript("OnUpdate", nil) end
            end)
        end
    end)
    self:ApplySide()
    self:ShowPage("overview")
    return f
end

-- Barre latérale dépliée ou en icônes, et zones qui en dépendent.
function UI:ApplySide()
    local collapsed = WK.DB.global.settings.ui.collapsed
    local w = sideWidth()
    self.side:SetWidth(w)
    self.sideTitle:SetShown(not collapsed)
    self.sideVer:SetShown(not collapsed)
    if self.sideSearch then self.sideSearch:SetShown(not collapsed) end
    if self.layoutTop then self.layoutTop() end
    for _, l in ipairs(self.groupLabels) do l:SetShown(not collapsed and not l.wkHidden) end
    self.collapseBtn.label:SetShown(not collapsed)
    self.collapseBtn.label:SetText(WK.T("Réduire le menu"))
    self.collapseBtn.icon:SetTexture(UI.MEDIA .. (collapsed and "arrow" or "back"))
    -- barre latérale à gauche (défaut) ou à droite (Options > Apparence, settings.ui.sideRight)
    local right = WK.DB.global.settings.ui.sideRight
    self.side:ClearAllPoints(); self.header:ClearAllPoints(); self.pageHost:ClearAllPoints()
    if right then
        self.side:SetPoint("TOPRIGHT", -5, -5); self.side:SetPoint("BOTTOMRIGHT", -5, 5)
        self.header:SetPoint("TOPLEFT", 5, -5); self.header:SetPoint("TOPRIGHT", -(w + 5), -5)
        self.pageHost:SetPoint("TOPLEFT", PAD, -TOP)
        self.pageHost:SetPoint("BOTTOMRIGHT", -(w + PAD), PAD)
    else
        self.side:SetPoint("TOPLEFT", 5, -5); self.side:SetPoint("BOTTOMLEFT", 5, 5)
        self.header:SetPoint("TOPLEFT", w + 5, -5); self.header:SetPoint("TOPRIGHT", -5, -5)
        self.pageHost:SetPoint("TOPLEFT", w + PAD, -TOP)
        self.pageHost:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    end
    if self.sideSep then
        self.sideSep:ClearAllPoints()
        local e = right and "LEFT" or "RIGHT"
        self.sideSep:SetPoint("TOP" .. e); self.sideSep:SetPoint("BOTTOM" .. e)
    end
    computePageSize(self.frame:GetWidth(), self.frame:GetHeight())
    for _, item in pairs(self.nav) do item:Refresh() end
end

-- Barre latérale repliée ou dépliée : les pages suivent d'elles-mêmes (elles sont élastiques).
function UI:Relayout()
    if not self.frame then return end
    self:ApplySide()
    self:Refresh()
end

-- Mise en page élastique : fn(largeur, hauteur) est appelée tout de suite puis à chaque
-- changement de taille du cadre (redimensionnement en direct, repli du menu).
function UI:OnResize(frame, fn)
    frame:HookScript("OnSizeChanged", function(_, w, h) if w and w > 0 then fn(w, h) end end)
    fn(frame:GetWidth(), frame:GetHeight())
end

-- Rafraîchissement rapide et regroupé (graphiques à redessiner pendant un redimensionnement).
local soonPending = false
function UI:RefreshSoon()
    if soonPending then return end
    soonPending = true
    C_Timer.After(0.05, function() soonPending = false; UI:Refresh() end)
end

function UI:ShowPage(key)
    -- les patch notes sont une section des Options
    local sub
    if key == "notes" then key, sub = "options", "notes"; WK.DB.global.settings.ui.optSection = "notes" end
    if key and not WK:PageOn(key) then key = "overview" end -- module coupé
    local def = self.pages[key] or self.pages.overview
    if not self.frame then self:Create() end
    local changed = self.current ~= def.key
    self.current = def.key
    if changed and self.layoutTop then self.layoutTop() end -- groupe replié : la page affichée reste visible
    WK.DB.global.settings.ui.lastPage = def.key
    for k, d in pairs(self.pages) do
        if d.frame then d.frame:SetShown(k == def.key) end
    end
    self:EnsurePage(def.key)
    if sub and def.ShowSection then def:ShowSection(sub) end
    self:Refresh()
end

-- Construit une page sans l'afficher (une page qui en emprunte une autre : Pêche prend les cartes
-- de réglages de QoL). Renvoie la définition de la page.
function UI:EnsurePage(key)
    local def = self.pages[key]
    if not def then return nil end
    if not self.frame then self:Create() end
    if not def.frame then
        def.frame = CreateFrame("Frame", nil, self.pageHost)
        def.frame:SetAllPoints()
        def.frame:SetShown(self.current == key)
        self:InAccentScope("window", def.Build, def, def.frame)
    end
    return def
end

-- Sous-entrées de QoL (section affichée, pastilles).
function UI:RefreshNavSubs()
    for _, sub in pairs(self.navSubs or {}) do sub:Refresh() end
    -- section changée depuis la page (onglets des classes…) : la garder visible dans la liste
    local sec = self.current == "qol" and self.QoLCurrentSection and self:QoLCurrentSection()
    if sec ~= self.lastNavSec then
        self.lastNavSec = sec
        if self.layoutTop then self.layoutTop() end
    end
end

-- Met à jour la page affichée et la navigation.
function UI:Refresh()
    if not self.frame or not self.frame:IsShown() then return end
    for key, item in pairs(self.nav) do
        local def = self.pages[key]
        item.count:SetText(def.count and def.count() or "")
        item:Refresh()
    end
    -- titres de groupe : total des pastilles de leurs pages quand le groupe est replié
    local closedMap = WK.DB.global.settings.ui.navClosed or {}
    for _, head in ipairs(self.groupLabels or {}) do
        local sum = 0
        if closedMap[head.name] then
            for _, g in ipairs(GROUPS) do
                if g[1] == head.name then
                    for _, k in ipairs(g[2]) do
                        local secKey = k:match("^qol:(.+)$")
                        if secKey then
                            -- section de QoL : sa pastille
                            local n = UI.QoLSectionCount and tonumber(UI:QoLSectionCount(secKey))
                            if n and WK:PageOn("qol") then sum = sum + n end
                        else
                            local def = self.pages[k]
                            local n = def and def.count and tonumber(def.count())
                            if n and WK:PageOn(k) then sum = sum + n end
                        end
                    end
                end
            end
        end
        head.sum:SetText(sum > 0 and tostring(sum) or "")
        head:Refresh()
    end
    self:RefreshNavSubs()
    local def = self.pages[self.current]
    if def and def.frame and def.Refresh then def:Refresh() end
    self:RefreshChips()
end

---------------------------------------------------------------------------
-- Pastilles de l'en-tête : chiffres clés de chaque page.
-- Chaque fonction renvoie une liste { label, valeur, couleur?, page?, tip?, after? }.
---------------------------------------------------------------------------
local T = function(s) return WK.T(s) end
local function count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end
local function waitingMail()
    local letters, chars, soon = 0, 0, false
    local limit = WK.DB.global.settings.alerts.mailDays or 3
    for _, c in pairs(WK.DB.global.characters) do
        local box = c.mailbox
        if box and (box.count or 0) > 0 then
            letters, chars = letters + box.count, chars + 1
            if box.expiresAt and (box.expiresAt - time()) / 86400 <= limit then soon = true end
        end
    end
    return letters, chars, soon
end
local function farmChip()
    local F = WK.modules.Farm
    if F:Active() then
        local cur = F:Current()
        return { T("Session de farm"), WK:FormatTime(F:Elapsed(cur)) .. (cur.paused and (" · " .. T("en pause")) or ""),
            cur.paused and C.warning or C.positive, "farm" }
    end
end
local function mailChip()
    local letters, chars, soon = waitingMail()
    if letters > 0 then
        return { T("Courrier en attente"), string.format("%d", letters), soon and C.negative or C.text, "mail",
            string.format(T("%d lettre(s) sur %d perso(s)"), letters, chars),
            function() UI.pages.mail:SetTab("receive") end }
    end
end
local function add(list, chip) if chip then table.insert(list, chip) end end

UI.CHIPS = {
    overview = function()
        local V = WK.modules.Value
        local l = { { T("Or"), UI:PlainMoney(V:AccountGold()), C.gold },
                    { T("Richesse totale"), UI:PlainMoney(V:Wealth()), C.gold, "stats", T("Or + valeur des stocks") },
                    { T("Persos"), tostring(count(WK.DB.global.characters)), nil, "characters" } }
        add(l, mailChip()); add(l, farmChip())
        return l
    end,
    characters = function()
        local played, maxLvl = 0, 0
        for _, c in pairs(WK.DB.global.characters) do
            played = played + (c.played or 0)
            if (c.level or 0) >= 60 then maxLvl = maxLvl + 1 end
        end
        local l = { { T("Temps de jeu total"), WK:FormatTime(played), C.gold, nil, T("Tous les persos du compte") },
                    { T("Persos"), tostring(count(WK.DB.global.characters)) },
                    { T("Niveau 60"), tostring(maxLvl) } }
        local alerts = WK.modules.Alerts:All() or {}
        if #alerts > 0 then
            -- Survol : le détail des alertes (banque pas vue, courrier qui expire).
            local lines = { T("Alertes") }
            for _, e in ipairs(alerts) do
                table.insert(lines, "|cffffffff" .. WK:CharName(e.c, e.key) .. "|r : " .. e.alert.text)
            end
            table.insert(lines, "|cff999999" .. T("Réglages : QoL > Général > Alertes") .. "|r")
            table.insert(l, { T("Alertes"), tostring(#alerts), C.warning, "qol", table.concat(lines, "\n"),
                function() UI:OpenQoLAlerts() end })
        end
        return l
    end,
    inventory = function()
        local total = 0
        for _, c in pairs(WK.DB.global.characters) do
            for _, list in ipairs({ c.bags, c.bank, c.mailbox and c.mailbox.items }) do
                for _, n in pairs(list or {}) do total = total + n end
            end
        end
        local wb = WK.DB.global.warbank
        for _, n in pairs(wb and wb.items or {}) do total = total + n end
        local V = WK.modules.Value
        return { { T("Objets"), tostring(total) },
                 { T("Valeur des stocks"), UI:PlainMoney(V:StockValue()), C.gold },
                 { T("Prix"), V:ShowBoth() and T("HV / marchand")
                     or ((WK.DB.global.settings.value.source ~= "vendor" and V:HasAHPrices()) and T("HV") or T("marchand")),
                   nil, "auction", T("Source des prix (Hôtel des ventes)") } }
    end,
    professions = function()
        -- Chaque métier et chaque recette comptés une seule fois, même si plusieurs persos les ont.
        local profSet, recSet = {}, {}
        for _, c in pairs(WK.DB.global.characters) do
            for name in pairs(c.professions or {}) do profSet[name] = true end
            for key in pairs(c.recipes or {}) do recSet[key] = true end
        end
        local profs, recipes = count(profSet), count(recSet)
        local l = { { T("Métiers"), tostring(profs) }, { T("Recettes connues"), tostring(recipes) } }
        local n = count(WK.DB.global.shopping)
        if n > 0 then table.insert(l, { T("Liste de courses"), tostring(n), nil, "professions", nil,
            function() UI.pages.professions:SetTab("shopping") end }) end
        return l
    end,
    stats = function()
        local V = WK.modules.Value
        local now = time()
        local d = V:AccountGold() - WK.modules.Statistics:AccountGoldAt(now - 7 * 86400)
        local l = { { T("Richesse totale"), UI:PlainMoney(V:Wealth()), C.gold },
                    { T("Or"), UI:PlainMoney(V:AccountGold()), C.gold },
                    { T("Or sur 7 jours"), (d >= 0 and "+" or "") .. UI:PlainMoney(d), d >= 0 and C.positive or C.negative } }
        -- Bilan de l'hôtel des ventes sur 7 jours (ventes nettes - achats)
        local A = WK.modules.Auction
        if A then
            local sm = A:Summary(7)
            if sm.nSales + sm.nBuys > 0 then
                local lines = { T("Hôtel des ventes, 7 derniers jours"),
                    string.format(T("Ventes : %d · %s (après commission)"), sm.nSales, UI:PlainMoney(sm.sales)),
                    string.format(T("Achats : %d · %s"), sm.nBuys, UI:PlainMoney(sm.buys)) }
                if #sm.top > 0 then table.insert(lines, " "); table.insert(lines, T("Meilleures ventes :")) end
                for i, b in ipairs(sm.top) do
                    if i > 5 then break end
                    table.insert(lines, string.format("  %d %s : %s", b.count, b.item, UI:PlainMoney(b.net)))
                end
                table.insert(l, { T("Bilan HV 7 j"), (sm.balance >= 0 and "+" or "") .. UI:PlainMoney(sm.balance),
                    sm.balance >= 0 and C.positive or C.negative, "journal", table.concat(lines, "\n"),
                    function() UI.pages.journal.filter = "ah"; if UI.pages.journal.jseg then UI.pages.journal.jseg:Select("ah") end; UI:Refresh() end })
            end
        end
        return l
    end,
    auction = function()
        local S = WK.modules.AHScan
        local nl = 0
        for _ in pairs(S:Config().lists or {}) do nl = nl + 1 end
        local l = { { T("Prix connus"), tostring(S:Count()), S:HasData() and nil or C.dim },
                    { T("Listes d'achat"), tostring(nl) } }
        local na = 0
        for _ in pairs(S:Config().alerts or {}) do na = na + 1 end
        if na > 0 then table.insert(l, { T("Alertes de prix"), tostring(na) }) end
        return l
    end,
    mail = function()
        local m, b = WK.DB.global.mail, WK.DB.global.bank
        local l = { { T("Règles d'envoi"), tostring(count(m.rules) + count(m.cats)) },
                    { T("Règles de dépôt"), tostring(count(b.items) + count(b.cats)) } }
        local pending = WK.modules.Mail:PendingCount()
        if pending > 0 then table.insert(l, { T("À envoyer"), tostring(pending), C.positive, nil,
            T("Objets des sacs qui partiront à la prochaine boîte aux lettres") }) end
        add(l, mailChip())
        return l
    end,
    farm = function()
        local l = {}
        add(l, farmChip())
        if #l == 0 then table.insert(l, { T("Session de farm"), T("aucune"), C.dim }) end
        local h = WK.DB.global.farm.history or {}
        local gold = 0
        for _, s in ipairs(h) do gold = gold + (s.gold or 0) end
        local best = WK.modules.Farm:BestSpot(7)
        if best and best.rate > 0 then
            table.insert(l, { T("Meilleur spot 7 j"), best.zone .. " · " .. UI:PlainMoney(best.rate) .. T("/h"), C.gold })
        end
        table.insert(l, { T("Sessions enregistrées"), tostring(#h) })
        if gold > 0 then table.insert(l, { T("Or farmé"), UI:PlainMoney(gold), C.gold }) end
        return l
    end,
    loot = function()
        local L = WK.modules.Loot
        local _, total, n = L:LeftList()
        local function openList()
            local pg = UI.pages.loot
            if pg.leftPanel then pg.leftPanel:Show(); pg:RefreshLeft() end
        end
        return { { T("Profils"), tostring(#L:Profiles()) },
                 { T("Laissés au sol (session)"), tostring(L.leftSession or 0) },
                 { T("Valeur laissée au sol"), UI:PlainMoney(total), C.gold, "loot",
                   string.format(T("%d objets depuis la dernière remise à zéro"), n), openList } }
    end,
    lfg = function()
        local L = WK.modules.LFG
        local groups, mine, solos, asked = 0, 0, 0, 0
        for _, r in ipairs(L.results) do
            if r.solo then solos = solos + 1
            elseif not r.delisted then groups = groups + 1; if L:FitRole(r) then mine = mine + 1 end end
        end
        for _ in pairs(L.requests) do asked = asked + 1 end
        return { { T("Groupes"), tostring(groups) }, { T("Une place pour toi"), tostring(mine), mine > 0 and C.positive or nil },
                 { T("Joueurs seuls"), tostring(solos) }, { T("Demandes"), tostring(asked) } }
    end,
    dungeons = function()
        local D = WK.modules.Dungeons
        local key = WK:CharKey()
        local full, n = 0, 0
        for _, d in ipairs(D:All()) do
            n = n + 1
            local done, total = D:Progress(d, key)
            if total > 0 and done >= total then full = full + 1 end
        end
        local cur = D:Current()
        local chips = { { T("Donjons finis"), full .. " / " .. n }, { T("Envies"), tostring(D:WishCount(key)) } }
        if cur then table.insert(chips, { T("En ce moment"), D:Name(cur), C.positive }) end
        return chips
    end,
    fishing = function()
        local FL = WK.modules.FishingLog
        local have, total = FL:CollectionCount()
        local d = FL:Data()
        return { { T("Espèces"), have .. " / " .. total }, { T("Prises"), tostring(d.total or 0) },
                 { T("Valeur"), UI:PlainMoney(FL:Value()), C.gold } }
    end,
    journal = function()
        local today, n = date("%Y%m%d"), 0
        for _, e in ipairs(WK.DB.global.journal or {}) do if date("%Y%m%d", e.t) == today then n = n + 1 end end
        return { { T("Événements"), tostring(#(WK.DB.global.journal or {})) }, { T("Aujourd'hui"), tostring(n) } }
    end,
    qol = function()
        local Q = WK.modules.QoL
        local function n(kind) return (Q:AlertsFor(function(a) return a.kind == kind end)) end
        local reag = n("reagent") + n("ammo")
        local rep, bags = n("durability"), n("bags")
        local _, played = Q:PlayedClasses()
        local function tip(kind, title)
            local _, list = Q:AlertsFor(function(a) return a.kind == kind or (kind == "reagent" and a.kind == "ammo") end)
            if #list == 0 then return nil end
            local lines = { title }
            for i, a in ipairs(list) do if i <= 12 then table.insert(lines, a.text) end end
            return table.concat(lines, "\n")
        end
        return { { T("Composants bas"), tostring(reag), reag > 0 and C.warning or C.positive, nil, tip("reagent", T("Composants bas")) },
                 { T("À réparer"), tostring(rep), rep > 0 and C.negative or C.positive, nil, tip("durability", T("À réparer")) },
                 { T("Sacs pleins"), tostring(bags), bags > 0 and C.warning or C.positive, nil, tip("bags", T("Sacs presque pleins")) },
                 { T("Classes jouées"), played .. " / 9" } }
    end,
    notes = function()
        return { { T("Version"), WK.version, C.gold }, { T("À venir"), tostring(#(WK.Roadmap or {})) } }
    end,
    options = function()
        return { { T("Version"), WK.version, C.gold } }
    end,
    rares = function()
        local R = WK.modules.Rares
        local pg = UI.pages.rares
        local key = (pg and pg.viewKey) or WK:CharKey()
        local killed, total = R:Totals(key)
        local out = { { T("Rares tués"), killed .. " / " .. total, C.gold } }
        local pz = R:PlayerZone()
        if pz then
            local n, k = 0, 0
            for _, r in ipairs(R:OnMap(pz)) do n = n + 1; if R:Killed(r.id, key) then k = k + 1 end end
            table.insert(out, { R:ZoneName(pz), k .. " / " .. n })
        end
        -- rares de ton niveau pas encore tués, toutes zones
        local c = WK.DB.global.characters[key] or {}
        local lvl, left, seen = c.level or 1, 0, {}
        for _, list in pairs(WK.RaresDB or {}) do
            for _, e in ipairs(list) do
                if not seen[e[1]] then
                    seen[e[1]] = true
                    if (e[4] or 0) >= lvl - 2 and (e[4] or 0) <= lvl + 3 and not R:Killed(e[1], key) then left = left + 1 end
                end
            end
        end
        table.insert(out, { T("À ton niveau"), string.format(T("%d restants"), left), left > 0 and C.positive or nil })
        return out
    end,
    quests = function()
        local Q = WK.modules.Quests
        local pg = UI.pages.quests
        local key = (pg and pg.viewKey) or WK:CharKey()
        local done, total, avail = Q:Totals(key)
        local out = { { T("Quêtes faites"), done .. " / " .. total, C.gold } }
        local best, xp = Q:BestZone(key)
        if best then
            table.insert(out, { T("Pour monter"), best.name, C.positive, nil,
                string.format(T("%s XP de quêtes disponibles à ton niveau"), tostring(xp)) })
        end
        table.insert(out, { T("Disponibles"), tostring(avail) })
        return out
    end,
}

-- Bouton « Mise à jour x.y.z » de l'en-tête
function UI:RefreshUpdate()
    for key, ib in pairs(self.headIcons or {}) do
        local n = ib.def.count and ib.def.count() or ""
        ib.dot:SetShown(n ~= nil and n ~= "")
        -- point rouge : une erreur de l'addon pas encore vue (Options > Fiabilité)
        if n == "!" then ib.dot:SetVertexColor(unpack(C.negative)) else ib.dot:SetVertexColor(UI:Accent()) end
        -- l'infobulle dit ce que signale le point, et où mène le clic
        local tip = T(ib.baseTip or "")
        if key == "options" and n == "!" then
            tip = tip .. "\n" .. UI:Hex(C.negative) .. T("Point rouge : une erreur de l'addon pas encore vue. Clic : Fiabilité.") .. "|r"
        elseif key == "options" and n ~= nil and n ~= "" then
            tip = tip .. "\n" .. UI:Hex(C.muted) .. T("Point : des nouveautés pas encore lues. Clic : Patch notes.") .. "|r"
        end
        ib.tooltip = tip
    end
    local b = self.updBtn
    if not b then return end
    local V = WK.modules.Version
    local v = V and V:Available()
    if v then b:SetLabel(string.format(T("Mise à jour %s"), v)); b:SetWidth(b.label:GetStringWidth() + 52) end
    b:SetShown(v ~= nil)
end

function UI:RefreshChips()
    if not self.chips then return end
    self:RefreshUpdate()
    self.chips:Reset()
    local f = UI.CHIPS[self.current]
    local ok, list = true, {}
    if f then ok, list = pcall(f) end
    if not ok or type(list) ~= "table" then list = {} end
    local x = PAD - 5
    local maxX = (self.header:GetWidth() or 600) - 80 - (self.editBtn and (self.editBtn:GetWidth() + 10) or 0) - 70 - #BOTTOM * 34
        - ((self.updBtn and self.updBtn:IsShown()) and (self.updBtn:GetWidth() + 8) or 0)
    for i, ch in ipairs(list) do
        local c = self.chips:Get()
        c.label:SetText(ch[1])
        c.value:SetText(ch[2] or "")
        c.value:SetTextColor(unpack(ch[3] or C.text))
        -- habillages : Héraldique = 1re pastille pleine ; Encre = pastilles sans cadre
        local skin = UI.skin
        c.label:SetTextColor(unpack(C.muted))
        c.bg:SetShown(skin ~= "ink"); c.border:SetShown(skin ~= "ink")
        c.bg:SetColor(unpack(C.surface))
        if skin == "heraldic" and i == 1 then
            local r, g, b = UI:Accent2()
            if not r then r, g, b = UI:Accent() end
            c.bg:SetColor(r, g, b, 1)
            c.label:SetTextColor(C.onAccent[1], C.onAccent[2], C.onAccent[3], 0.8); c.value:SetTextColor(unpack(C.onAccent))
        end
        c.page, c.tip, c.after = ch[4], ch[5], ch[6]
        local w = c.label:GetStringWidth() + c.value:GetStringWidth() + 30
        c:SetWidth(w)
        if x + w > maxX then c:Hide() else
            c:ClearAllPoints()
            c:SetPoint("LEFT", self.header, "LEFT", x, -2)
            x = x + w + 8
        end
    end
end

-- Rafraîchissement différé (évite de reconstruire 20 fois pendant un BAG_UPDATE).
local pending = false
function UI:RequestRefresh()
    if pending or not self.frame or not self.frame:IsShown() then return end
    pending = true
    C_Timer.After(0.3, function() pending = false; UI:Refresh() end)
end

function UI:ToggleWindow(page)
    local f = self:Create()
    local cur = page == "notes" and "options" or page
    if f:IsShown() and (not page or (cur == self.current and (page ~= "notes" or WK.DB.global.settings.ui.optSection == "notes"))) then
        f:Hide()
    else
        f:Show()
        -- À l'ouverture : toujours le Résumé, sauf si une page précise est demandée.
        self:ShowPage(page or "overview")
    end
end

function UI:ApplyScale(s)
    WK.DB.global.settings.ui.scale = s
    if self.frame then self.frame:SetScale(s) end
end

-- Reconstruit toute l'interface avec le thème, la police, l'arrondi et la langue actuels,
-- sans recharger le jeu. Les anciens cadres sont masqués et remplacés (WoW ne permet pas
-- de les détruire) ; la page ouverte et la position de la fenêtre sont conservées.
local rebuildPending = false
function UI:Rebuild()
    if rebuildPending then return end
    rebuildPending = true
    C_Timer.After(0.05, function()
        rebuildPending = false
        local wasShown = self.frame and self.frame:IsShown()
        local page = self.current
        UI:ApplyTheme()
        -- police des infobulles du jeu : la nouvelle (UI.FONT n'est à jour qu'après ApplyTheme)
        if self.ApplyGameTooltipFonts then self:ApplyGameTooltipFonts() end
        -- Les widgets masqués de la fenêtre n'ont plus besoin des mises à jour de l'accent
        -- (les éléments à l'écran qui ne sont pas reconstruits gardent les leurs).
        self:DropAccentHooks("window")
        if self.ResetSearchIndex then self:ResetSearchIndex(self.frame) end
        wipe(self.inputs)
        if self.frame then self.frame:Hide() end
        self.frame = nil
        for _, def in pairs(self.pages) do def.frame = nil end
        if self.farmMini then self.farmMini:Hide(); self.farmMini = nil end
        local mm = WK.modules.MinimapButton
        if mm and mm.button then mm.button:Hide(); mm.button = nil end
        if mm then mm:Update() end
        self:UpdateFarmMini()
        if wasShown then
            self:Create():Show()
            self:ShowPage(page or "overview")
        end
    end)
end

-- Option « Fermer la fenêtre en combat » : seulement la fenêtre principale,
-- la mini-fenêtre de farm reste. (Cet évènement arrive juste avant le verrouillage du combat.)
WK:On("PLAYER_REGEN_DISABLED", function()
    local cfg = WK.DB and WK.DB.global and WK.DB.global.settings.ui
    if cfg and cfg.closeInCombat and UI.frame and UI.frame:IsShown() then UI.frame:Hide() end
end)
