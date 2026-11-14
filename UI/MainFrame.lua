local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors

-- Mise en page « Registre » : barre du haut + navigation en pilules, sans barre latérale.
local W, H = 960, 620
local TOP = 62      -- hauteur de la barre du haut
local PAD = 20      -- marge intérieure
local HEADER = 34   -- en-tête de page (titre + aide), absent sur le Résumé
UI.PAGE_W = W - 2 * PAD
UI.PAGE_FULL_H = H - TOP - 16 - PAD
UI.PAGE_H = UI.PAGE_FULL_H - HEADER

---------------------------------------------------------------------------
-- Enregistrement des pages
-- def = { key, nav, title, subtitle, icon?, order, noHeader?, count(), Build(page, frame), Refresh(page) }
---------------------------------------------------------------------------
function UI:RegisterPage(def)
    self.pages[def.key] = def
    table.insert(self.pageOrder, def)
    table.sort(self.pageOrder, function(a, b) return (a.order or 99) < (b.order or 99) end)
end

---------------------------------------------------------------------------
-- Bouton de navigation (pilule). Sélectionné : fond relevé + bordure fine.
---------------------------------------------------------------------------
local NAV_H = 30
local function NavButton(parent, def)
    local b = CreateFrame("Button", nil, parent)
    b.selBorder = UI:Rounded(b, NAV_H / 2, 0, "BACKGROUND", 2)
    b.selBorder:SetColor(unpack(C.border))
    b.selFill = UI:Rounded(b, NAV_H / 2 - 1, 1, "BACKGROUND", 3)
    b.selFill:SetColor(unpack(C.surface2))
    if def.navIcon then
        b.icon = UI:Icon(b, def.navIcon, 15)
        b.icon:SetPoint("CENTER")
        b:SetSize(NAV_H + 6, NAV_H)
    else
        b.label = UI:Text(b, 12)
        b.label:SetPoint("CENTER")
        b.label:SetText(def.nav or def.title)
        b:SetSize(b.label:GetStringWidth() + 20, NAV_H)
    end
    b.count = UI:Text(b, 9, C.dim)
    b.count:SetPoint("TOPRIGHT", -5, -3)

    function b:Refresh()
        local sel = UI.current == def.key
        self.selBorder:SetShown(sel)
        self.selFill:SetShown(sel)
        local col = (sel or self.hover) and C.text or C.muted
        if self.label then self.label:SetTextColor(unpack(col)) end
        if self.icon then
            if sel then self.icon:SetVertexColor(UI:Accent()) else self.icon:SetVertexColor(unpack(col)) end
        end
    end
    b:SetScript("OnEnter", function(self) self.hover = true; self:Refresh() end)
    b:SetScript("OnLeave", function(self) self.hover = false; self:Refresh() end)
    b:SetScript("OnClick", function() UI:ShowPage(def.key) end)
    UI:OnAccent(function() b:Refresh() end)
    return b
end

---------------------------------------------------------------------------
-- Construction de la fenêtre (une seule fois, au premier affichage)
---------------------------------------------------------------------------
function UI:Create()
    if self.frame then return self.frame end
    local cfg = WK.DB.global.settings.ui

    local f = CreateFrame("Frame", "WarbandKeeperFrame", UIParent)
    self.frame = f
    f:SetSize(W, H)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetScale(cfg.scale or 1)
    if cfg.point then
        f:SetPoint(cfg.point[1], UIParent, cfg.point[2], cfg.point[3], cfg.point[4])
    else
        f:SetPoint("CENTER")
    end
    f:Hide()
    table.insert(UISpecialFrames, "WarbandKeeperFrame") -- fermeture avec Échap

    -- Cadre : bordure dorée, liseré sombre, bordure intérieure, fond.
    UI:Rounded(f, 16, 0, "BACKGROUND", -8):SetColor(unpack(C.frame))
    UI:Rounded(f, 15, 1, "BACKGROUND", -7):SetColor(unpack(C.inset))
    UI:Rounded(f, 12, 4, "BACKGROUND", -6):SetColor(unpack(C.trim))
    UI:Rounded(f, 11, 5, "BACKGROUND", -5):SetColor(unpack(C.bg))
    -- Halo chaud en haut (comme une lueur de chandelle).
    -- Le centre suit les coins arrondis : bandes latérales sous les coins + quarts de cercle.
    local GH, GA, R = 220, 0.65, 11
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

    -- Barre du haut -------------------------------------------------------------
    local top = CreateFrame("Frame", nil, f)
    top:SetPoint("TOPLEFT", 5, -5)
    top:SetPoint("TOPRIGHT", -5, -5)
    top:SetHeight(TOP - 5)
    top:EnableMouse(true)
    top:RegisterForDrag("LeftButton")
    top:SetScript("OnDragStart", function() f:StartMoving() end)
    top:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local p, _, rp, x, y = f:GetPoint()
        cfg.point = { p, rp, x, y }
    end)
    local sep = f:CreateTexture(nil, "BORDER")
    sep:SetColorTexture(unpack(C.border))
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", 5, -TOP)
    sep:SetPoint("TOPRIGHT", -5, -TOP)

    -- Logo : tuile dorée arrondie avec l'étendard en creux.
    local tile = CreateFrame("Frame", nil, top)
    tile:SetSize(36, 36)
    tile:SetPoint("LEFT", PAD - 5, 0)
    local tileBg = UI:Rounded(tile, 11, 0, "BACKGROUND", 1)
    local logo = UI:Icon(tile, "logo", 24, C.onAccent)
    logo:SetPoint("CENTER")
    UI:OnAccent(function() tileBg:SetColor(UI:Accent()) end)

    local title = top:CreateFontString(nil, "OVERLAY")
    title:SetFont(UI.TITLE_FONT, 19, "")
    title:SetText("Warband Keeper")
    title:SetPoint("TOPLEFT", tile, "TOPRIGHT", 12, 1)
    UI:OnAccent(function() title:SetTextColor(UI:Accent()) end)
    local sub = UI:Text(top, 10, C.muted)
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    sub:SetText(WK.T("Registre du compte") .. " · v" .. WK.version)

    -- Boutons à droite : fermer, scanner, rechercher.
    local close = UI:IconButton(top, "close", 30, "Fermer")
    close:SetPoint("RIGHT", -(PAD - 9), 0)
    close:SetScript("OnClick", function() f:Hide() end)
    local scan = UI:IconButton(top, "refresh", 30, "Scanner ce personnage (sacs, or, métiers)")
    scan:SetPoint("RIGHT", close, "LEFT", -4, 0)
    scan:SetScript("OnClick", function()
        WK.modules.Characters:UpdateBasics()
        WK.modules.Characters:UpdateMoney()
        WK.modules.Inventory:ScanBags()
        WK.modules.Professions:Scan()
        UI:Refresh()
    end)

    -- Navigation : pilules dans un conteneur arrondi, centrée dans l'espace libre.
    local nav = CreateFrame("Frame", nil, top)
    UI:Panel(nav, (NAV_H + 8) / 2, C.inset, C.border)
    self.nav = {}
    local x = 4
    for _, def in ipairs(self.pageOrder) do
        local b = NavButton(nav, def)
        b:SetPoint("LEFT", x, 0)
        x = x + b:GetWidth() + 1
        self.nav[def.key] = b
    end
    nav:SetSize(x + 2, NAV_H + 8)
    local left = PAD + 36 + 12 + math.max(title:GetStringWidth(), sub:GetStringWidth()) + 16
    local right = W - (PAD - 4) - 2 * 34 - 12
    nav:SetPoint("CENTER", top, "LEFT", math.max(left + nav:GetWidth() / 2, (left + right) / 2) - 5, 0)

    -- Zone de page --------------------------------------------------------------
    self.pageHost = CreateFrame("Frame", nil, f)
    self.pageHost:SetPoint("TOPLEFT", PAD, -(TOP + 16))
    self.pageHost:SetSize(UI.PAGE_W, UI.PAGE_FULL_H)

    self.titleText = UI:Text(self.pageHost, 15)
    self.titleText:SetPoint("TOPLEFT", 2, -2)
    UI:OnAccent(function() UI.titleText:SetTextColor(UI:Accent()) end)
    self.subtitleText = UI:Text(self.pageHost, 11, C.muted)
    self.subtitleText:SetPoint("BOTTOMLEFT", self.titleText, "BOTTOMRIGHT", 12, 1)

    f:SetScript("OnShow", function() UI:Refresh() end)
    self:ShowPage(cfg.lastPage or "overview")
    return f
end

function UI:ShowPage(key)
    local def = self.pages[key] or self.pages.overview
    if not self.frame then self:Create() end
    self.current = def.key
    WK.DB.global.settings.ui.lastPage = def.key
    for k, d in pairs(self.pages) do
        if d.frame then d.frame:SetShown(k == def.key) end
    end
    if not def.frame then
        def.frame = CreateFrame("Frame", nil, self.pageHost)
        def.frame:SetPoint("BOTTOMRIGHT")
        def.frame:SetPoint("TOPLEFT", 0, def.noHeader and 0 or -HEADER)
        def:Build(def.frame)
    end
    self.titleText:SetShown(not def.noHeader)
    self.subtitleText:SetShown(not def.noHeader)
    self.titleText:SetText(def.title)
    self.subtitleText:SetText(def.subtitle or "")
    self.subtitleText:SetWidth(math.max(50, UI.PAGE_W - self.titleText:GetStringWidth() - 20))
    self:Refresh()
end

-- Met à jour la page affichée et la navigation.
function UI:Refresh()
    if not self.frame or not self.frame:IsShown() then return end
    for key, item in pairs(self.nav) do
        local def = self.pages[key]
        item.count:SetText(def.count and def.count() or "")
        item:Refresh()
    end
    local def = self.pages[self.current]
    if def and def.frame and def.Refresh then def:Refresh() end
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
    if f:IsShown() and (not page or page == self.current) then
        f:Hide()
    else
        f:Show()
        if page then self:ShowPage(page) end
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
        -- Les widgets masqués n'ont plus besoin des mises à jour de l'accent.
        wipe(self.accentHooks)
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
