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
local GROUPS = {
    { "COMPTE", { "overview", "characters", "inventory" } },
    { "ÉCONOMIE", { "stats", "professions", "mail" } },
    { "FARM", { "farm", "loot", "journal" } },
}
local BOTTOM = { "notes", "options" }
local ICONS = {
    overview = "home", characters = "users", inventory = "bag", stats = "chart", professions = "hammer",
    mail = "mail", farm = "play", loot = "filter", journal = "clock", notes = "notes", options = "gear",
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
    b.count = UI:Text(b, 10, C.dim)
    b.count:SetPoint("RIGHT", -10, 0)
    b.count:SetJustifyH("RIGHT")

    function b:Refresh()
        local sel = UI.current == def.key
        self.bg:SetColor(unpack(sel and C.surface2 or C.hover))
        self.bg:SetShown(sel or self.hover)
        self.bar:SetShown(sel)
        self.barTex:SetColor(UI:Accent())
        if sel then self.icon:SetVertexColor(UI:Accent()) else self.icon:SetVertexColor(unpack(C.muted)) end
        self.label:SetTextColor(unpack((sel or self.hover) and C.text or C.muted))
        local collapsed = WK.DB.global.settings.ui.collapsed
        self.label:SetShown(not collapsed)
        self.count:SetShown(not collapsed)
    end
    b:SetScript("OnEnter", function(self)
        self.hover = true; self:Refresh()
        if WK.DB.global.settings.ui.collapsed then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
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
-- Construction de la fenêtre
---------------------------------------------------------------------------
function UI:Create()
    if self.frame then return self.frame end
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
    table.insert(UISpecialFrames, "WarbandKeeperFrame") -- fermeture avec Échap

    -- Cadre : bordure dorée, liseré, bordure intérieure, fond.
    UI:Rounded(f, 16, 0, "BACKGROUND", -8):SetColor(unpack(C.frame))
    UI:Rounded(f, 15, 1, "BACKGROUND", -7):SetColor(unpack(C.inset))
    UI:Rounded(f, 12, 4, "BACKGROUND", -6):SetColor(unpack(C.trim))
    UI:Rounded(f, 11, 5, "BACKGROUND", -5):SetColor(unpack(C.bg))
    -- Halo en haut, qui suit les coins arrondis.
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
    sideBg:SetColorTexture(0, 0, 0, 0.18)
    local sep = side:CreateTexture(nil, "BORDER")
    sep:SetColorTexture(unpack(C.border))
    sep:SetWidth(1)
    sep:SetPoint("TOPRIGHT"); sep:SetPoint("BOTTOMRIGHT")

    local tile = CreateFrame("Frame", nil, side)
    tile:SetSize(36, 36)
    tile:SetPoint("TOPLEFT", 9, -12)
    local tileBg = UI:Rounded(tile, 11, 0, "BACKGROUND", 1)
    local logo = UI:Icon(tile, "logo", 24, C.onAccent)
    logo:SetPoint("CENTER")
    UI:OnAccent(function() tileBg:SetColor(UI:Accent()) end)
    local title = side:CreateFontString(nil, "OVERLAY")
    title:SetFont(UI.TITLE_FONT, 15, "")
    title:SetText("Warband Keeper")
    title:SetPoint("TOPLEFT", tile, "TOPRIGHT", 10, 0)
    UI:OnAccent(function() title:SetTextColor(UI:Accent()) end)
    local ver = UI:Text(side, 10, C.muted)
    ver:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    ver:SetText("v" .. WK.version)
    self.sideTitle, self.sideVer = title, ver

    self.nav, self.groupLabels = {}, {}
    local y = -64
    for _, g in ipairs(GROUPS) do
        local lbl = UI:Text(side, 10, C.dim)
        lbl:SetPoint("TOPLEFT", 16, y - 8)
        lbl:SetText(g[1])
        table.insert(self.groupLabels, lbl)
        y = y - 26
        for _, key in ipairs(g[2]) do
            local def = self.pages[key]
            if def then
                local item = NavItem(side, def)
                item:SetPoint("TOPLEFT", 8, y)
                item:SetPoint("TOPRIGHT", -8, y)
                self.nav[key] = item
                y = y - 36
            end
        end
        y = y - 4
    end

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
    local by = 44
    for i = #BOTTOM, 1, -1 do
        local def = self.pages[BOTTOM[i]]
        if def then
            local item = NavItem(side, def)
            item:SetPoint("BOTTOMLEFT", 8, by)
            item:SetPoint("BOTTOMRIGHT", -8, by)
            self.nav[def.key] = item
            by = by + 36
        end
    end

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
                GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
                GameTooltip:SetText(s.tip, 1, 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        c:SetScript("OnLeave", function(s) s.border:SetColor(unpack(C.border)); GameTooltip:Hide() end)
        c:SetScript("OnClick", function(s)
            if s.page then
                UI:ShowPage(s.page)
                if s.after then s.after() end
            end
        end)
        return c
    end)
    local close = UI:IconButton(header, "close", 30, "Fermer")
    close:SetPoint("RIGHT", -(PAD - 9), 0)
    close:SetScript("OnClick", function() f:Hide() end)
    local scan = UI:IconButton(header, "refresh", 30, "Scanner ce personnage (sacs, or, métiers)")
    scan:SetPoint("RIGHT", close, "LEFT", -4, 0)
    scan:SetScript("OnClick", function()
        WK.modules.Characters:UpdateBasics()
        WK.modules.Characters:UpdateMoney()
        WK.modules.Inventory:ScanBags()
        WK.modules.Professions:Scan()
        UI:Refresh()
    end)

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
        GameTooltip:SetOwner(grip, "ANCHOR_TOP")
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

    f:SetScript("OnShow", function() UI:Refresh() end)
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
    for _, l in ipairs(self.groupLabels) do l:SetShown(not collapsed) end
    self.collapseBtn.label:SetShown(not collapsed)
    self.collapseBtn.label:SetText(WK.T("Réduire le menu"))
    self.collapseBtn.icon:SetTexture(UI.MEDIA .. (collapsed and "arrow" or "back"))
    self.header:SetPoint("TOPLEFT", w + 5, -5)
    self.pageHost:ClearAllPoints()
    self.pageHost:SetPoint("TOPLEFT", w + PAD, -TOP)
    self.pageHost:SetPoint("BOTTOMRIGHT", -PAD, PAD)
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
        local l = { { T("Persos"), tostring(count(WK.DB.global.characters)) },
                    { T("Niveau 60"), tostring(maxLvl) },
                    { T("Temps de jeu"), WK:FormatTime(played) } }
        local n = #(WK.modules.Alerts:All() or {})
        if n > 0 then table.insert(l, { T("Alertes"), tostring(n), C.warning }) end
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
                     or ((WK.DB.global.settings.value.source ~= "vendor" and V:HasAuctionator()) and "Auctionator" or T("marchand")),
                   nil, "options", T("Source des prix (Options > Prix)"), function() UI.pages.options:ShowSection("prices") end } }
    end,
    professions = function()
        local profs, recipes = 0, 0
        for _, c in pairs(WK.DB.global.characters) do
            profs = profs + count(c.professions); recipes = recipes + count(c.recipes)
        end
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
        return { { T("Richesse totale"), UI:PlainMoney(V:Wealth()), C.gold },
                 { T("Or"), UI:PlainMoney(V:AccountGold()), C.gold },
                 { T("Or sur 7 jours"), (d >= 0 and "+" or "") .. UI:PlainMoney(d), d >= 0 and C.positive or C.negative } }
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
    journal = function()
        local today, n = date("%Y%m%d"), 0
        for _, e in ipairs(WK.DB.global.journal or {}) do if date("%Y%m%d", e.t) == today then n = n + 1 end end
        return { { T("Événements"), tostring(#(WK.DB.global.journal or {})) }, { T("Aujourd'hui"), tostring(n) } }
    end,
    notes = function()
        return { { T("Version"), WK.version, C.gold }, { T("À venir"), tostring(#(WK.Roadmap or {})) } }
    end,
    options = function()
        return { { T("Version"), WK.version, C.gold } }
    end,
}

function UI:RefreshChips()
    if not self.chips then return end
    self.chips:Reset()
    local f = UI.CHIPS[self.current]
    local ok, list = true, {}
    if f then ok, list = pcall(f) end
    if not ok or type(list) ~= "table" then list = {} end
    local x = PAD - 5
    local maxX = (self.header:GetWidth() or 600) - 80
    for _, ch in ipairs(list) do
        local c = self.chips:Get()
        c.label:SetText(ch[1])
        c.value:SetText(ch[2] or "")
        c.value:SetTextColor(unpack(ch[3] or C.text))
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
    if f:IsShown() and (not page or page == self.current) then
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

-- Option « Fermer la fenêtre en combat » : seulement la fenêtre principale,
-- la mini-fenêtre de farm reste. (Cet évènement arrive juste avant le verrouillage du combat.)
WK:On("PLAYER_REGEN_DISABLED", function()
    local cfg = WK.DB and WK.DB.global and WK.DB.global.settings.ui
    if cfg and cfg.closeInCombat and UI.frame and UI.frame:IsShown() then UI.frame:Hide() end
end)
