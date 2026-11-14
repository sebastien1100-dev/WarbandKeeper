local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors

local W, H, SIDE = 960, 620, 220
local HEADER = 96
UI.PAGE_W = W - SIDE - 28 - 24
UI.PAGE_H = H - HEADER - 22

-- Sections de la barre latérale (dans l'ordre d'affichage).
local SECTIONS = {
    { key = "compte", label = "COMPTE" },
    { key = "outils", label = "OUTILS" },
}

---------------------------------------------------------------------------
-- Enregistrement des pages
-- def = { key, title, subtitle, icon, section, order, count(), Build(page, frame), Refresh(page) }
---------------------------------------------------------------------------
function UI:RegisterPage(def)
    self.pages[def.key] = def
    table.insert(self.pageOrder, def)
    table.sort(self.pageOrder, function(a, b) return (a.order or 99) < (b.order or 99) end)
end

---------------------------------------------------------------------------
-- Élément de navigation
---------------------------------------------------------------------------
local function NavItem(parent, def)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(SIDE - 24, 34)
    b.bg = UI:Rounded(b, 10, 0, "BACKGROUND", 1)
    b.bar = CreateFrame("Frame", nil, b)
    b.bar:SetSize(3, 16)
    b.bar:SetPoint("LEFT", 0, 0)
    b.barTex = UI:Rounded(b.bar, 1.5, 0, "ARTWORK", 1)
    b.icon = UI:Icon(b, def.icon, 16)
    b.icon:SetPoint("LEFT", 14, 0)
    b.label = UI:Text(b, 13)
    b.label:SetPoint("LEFT", b.icon, "RIGHT", 12, 0)
    b.label:SetText(def.title)
    b.count = UI:Text(b, 12, C.muted)
    b.count:SetPoint("RIGHT", -12, 0)
    b.count:SetJustifyH("RIGHT")

    function b:Refresh()
        local sel = UI.current == def.key
        local r, g, bl = UI:Accent()
        self.bg:SetColor(unpack(sel and C.surface2 or C.surface))
        self.bg:SetShown(sel or self.hover)
        self.barTex:SetColor(r, g, bl, 1)
        self.bar:SetShown(sel)
        if sel then self.icon:SetVertexColor(r, g, bl, 1) else self.icon:SetVertexColor(unpack(C.muted)) end
        self.label:SetTextColor(unpack((sel or self.hover) and C.text or C.muted))
        self.count:SetText(def.count and def.count() or "")
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

    UI:Panel(f, 14, C.bg, C.border)

    local function startMove() f:StartMoving() end
    local function stopMove()
        f:StopMovingOrSizing()
        local p, _, rp, x, y = f:GetPoint()
        cfg.point = { p, rp, x, y }
    end

    -- Barre latérale ---------------------------------------------------------
    local side = CreateFrame("Frame", nil, f)
    side:SetPoint("TOPLEFT", 1, -1)
    side:SetPoint("BOTTOMLEFT", 1, 1)
    side:SetWidth(SIDE)
    UI:Rounded(side, 13, 0, "BACKGROUND", 2):SetColor(unpack(C.sidebar))
    local square = side:CreateTexture(nil, "BACKGROUND", nil, 2) -- coins droits côté contenu
    square:SetColorTexture(unpack(C.sidebar))
    square:SetPoint("TOPRIGHT"); square:SetPoint("BOTTOMRIGHT"); square:SetWidth(14)
    local sep = side:CreateTexture(nil, "BORDER")
    sep:SetColorTexture(unpack(C.border))
    sep:SetPoint("TOPRIGHT"); sep:SetPoint("BOTTOMRIGHT"); sep:SetWidth(1)
    side:EnableMouse(true)
    side:RegisterForDrag("LeftButton")
    side:SetScript("OnDragStart", startMove)
    side:SetScript("OnDragStop", stopMove)

    -- Logo + titre
    local logoBg = CreateFrame("Frame", nil, side)
    logoBg:SetSize(38, 38)
    logoBg:SetPoint("TOPLEFT", 18, -20)
    local logoRound = UI:Rounded(logoBg, 12, 0, "BACKGROUND", 3)
    local logo = UI:Icon(logoBg, "logo", 24)
    logo:SetPoint("CENTER")
    UI:OnAccent(function()
        local r, g, b = UI:Accent()
        logoRound:SetColor(r, g, b, 0.15)
        logo:SetVertexColor(r, g, b, 1)
    end)
    local title = UI:Text(side, 16)
    title:SetPoint("TOPLEFT", logoBg, "TOPRIGHT", 12, -3)
    title:SetText("Warband Keeper")
    local sub = UI:Text(side, 11, C.muted)
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    sub:SetText("v" .. WK.version .. " · WoW Forever")

    -- Navigation par sections
    self.nav = {}
    local y = -84
    for _, sec in ipairs(SECTIONS) do
        local lbl = UI:Text(side, 10, C.dim)
        lbl:SetPoint("TOPLEFT", 26, y - 10)
        lbl:SetText(sec.label)
        y = y - 30
        for _, def in ipairs(self.pageOrder) do
            if def.section == sec.key then
                local item = NavItem(side, def)
                item:SetPoint("TOPLEFT", 12, y)
                self.nav[def.key] = item
                y = y - 38
            end
        end
        y = y - 6
    end
    -- Pages du bas (options)
    local by = 96
    for _, def in ipairs(self.pageOrder) do
        if def.section == "bas" then
            local item = NavItem(side, def)
            item:SetPoint("BOTTOMLEFT", 12, by)
            self.nav[def.key] = item
            by = by + 38
        end
    end

    -- Pied de barre latérale : statut + bouton principal
    local status = CreateFrame("Frame", nil, side)
    status:SetPoint("BOTTOMLEFT", 12, 54)
    status:SetPoint("BOTTOMRIGHT", -12, 54)
    status:SetHeight(28)
    UI:Panel(status, 14, C.surface, C.border)
    local dot = UI:Icon(status, "circle", 8, nil, "ARTWORK")
    dot:SetPoint("LEFT", 12, 0)
    UI:OnAccent(function() dot:SetVertexColor(UI:Accent()) end)
    self.statusText = UI:Text(status, 11, C.muted)
    self.statusText:SetPoint("LEFT", dot, "RIGHT", 8, 0)

    local scanBtn = UI:Button(side, "Scanner ce personnage", SIDE - 24, 32, "primary")
    scanBtn:SetPoint("BOTTOMLEFT", 12, 14)
    scanBtn.tooltip = "Relit les sacs, l'or et les métiers du personnage connecté. La banque est lue quand tu l'ouvres."
    scanBtn:SetScript("OnClick", function()
        WK.modules.Characters:UpdateBasics()
        WK.modules.Characters:UpdateMoney()
        WK.modules.Inventory:ScanBags()
        WK.modules.Professions:Scan()
        UI:Refresh()
    end)

    -- Zone de contenu ----------------------------------------------------------
    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", SIDE, 0)
    header:SetPoint("TOPRIGHT")
    header:SetHeight(HEADER - 8)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", startMove)
    header:SetScript("OnDragStop", stopMove)

    self.titleText = UI:Text(header, 24)
    self.titleText:SetPoint("TOPLEFT", 28, -26)
    self.subtitleText = UI:Text(header, 12, C.muted)
    self.subtitleText:SetPoint("TOPLEFT", self.titleText, "BOTTOMLEFT", 0, -8)

    local close = UI:IconButton(header, "close", 30, "Fermer")
    close:SetPoint("TOPRIGHT", -14, -14)
    close:SetScript("OnClick", function() f:Hide() end)

    self.pageHost = CreateFrame("Frame", nil, f)
    self.pageHost:SetPoint("TOPLEFT", SIDE + 28, -HEADER)
    self.pageHost:SetSize(UI.PAGE_W, UI.PAGE_H)

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
        def.frame:SetAllPoints()
        def:Build(def.frame)
    end
    self.titleText:SetText(def.title)
    self.subtitleText:SetText(def.subtitle or "")
    self:Refresh()
end

-- Met à jour la page affichée et la barre latérale.
function UI:Refresh()
    if not self.frame or not self.frame:IsShown() then return end
    for _, item in pairs(self.nav) do item:Refresh() end
    local n, gold = 0, 0
    for _, c in pairs(WK.DB.global.characters) do n = n + 1; gold = gold + (c.money or 0) end
    self.statusText:SetText(string.format("%d personnage%s · %s", n, n > 1 and "s" or "", UI:ShortGold(gold)))
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
