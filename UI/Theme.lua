local ADDON_NAME, WK = ...

-- Thème visuel : couleurs, polices, formes arrondies.
local UI = { pages = {}, pageOrder = {}, inputs = {}, accentHooks = {} }
WK.UI = UI

UI.MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"
UI.FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

UI.colors = {
    bg       = { 0.055, 0.060, 0.068, 0.97 },
    sidebar  = { 0.035, 0.038, 0.044, 1 },
    surface  = { 0.090, 0.097, 0.108, 1 },
    surface2 = { 0.135, 0.145, 0.160, 1 },
    hover    = { 0.175, 0.185, 0.205, 1 },
    border   = { 0.180, 0.190, 0.210, 1 },
    text     = { 0.93, 0.94, 0.95, 1 },
    muted    = { 0.60, 0.62, 0.66, 1 },
    dim      = { 0.40, 0.42, 0.46, 1 },
    onAccent = { 0.05, 0.06, 0.07, 1 },
    positive = { 0.50, 0.85, 0.45, 1 },
    negative = { 0.95, 0.42, 0.45, 1 },
    gold     = { 1.00, 0.82, 0.30, 1 },
}

-- Couleurs d'accent proposées dans les options (comme HunterSuite).
UI.accents = {
    { 0.64, 0.85, 0.42 }, -- vert
    { 0.20, 0.80, 0.62 }, -- émeraude
    { 1.00, 0.72, 0.28 }, -- ambre
    { 0.40, 0.76, 1.00 }, -- bleu
    { 0.70, 0.56, 1.00 }, -- violet
    { 1.00, 0.46, 0.56 }, -- rose
}

function UI:Accent()
    local a = self.accents[WK.DB.global.settings.ui.accent] or self.accents[1]
    return a[1], a[2], a[3]
end

-- Les widgets qui utilisent l'accent s'enregistrent ici pour se mettre à jour en direct.
function UI:OnAccent(fn)
    table.insert(self.accentHooks, fn)
    fn()
end

function UI:SetAccent(index)
    WK.DB.global.settings.ui.accent = index
    for _, fn in ipairs(self.accentHooks) do fn() end
end

---------------------------------------------------------------------------
-- Rectangle arrondi : 4 quarts de cercle + 3 bandes (aucun chevauchement,
-- donc la transparence reste uniforme). Teinté via SetColor.
---------------------------------------------------------------------------
local Rounded = {}
Rounded.__index = Rounded

function UI:Rounded(parent, radius, inset, layer, sublevel)
    inset, layer, sublevel = inset or 0, layer or "BACKGROUND", sublevel or 0
    local r = setmetatable({ t = {} }, Rounded)
    local function tex()
        local t = parent:CreateTexture(nil, layer, nil, sublevel)
        table.insert(r.t, t)
        return t
    end

    local corners = {
        { "TOPLEFT",     0,   0.5, 0,   0.5, inset,  -inset },
        { "TOPRIGHT",    0.5, 1,   0,   0.5, -inset, -inset },
        { "BOTTOMLEFT",  0,   0.5, 0.5, 1,   inset,  inset },
        { "BOTTOMRIGHT", 0.5, 1,   0.5, 1,   -inset, inset },
    }
    for _, c in ipairs(corners) do
        local t = tex()
        t:SetTexture(UI.MEDIA .. "circle")
        t:SetTexCoord(c[2], c[3], c[4], c[5])
        t:SetSize(radius, radius)
        t:SetPoint(c[1], parent, c[1], c[6], c[7])
    end

    local mid = tex()
    mid:SetColorTexture(1, 1, 1, 1)
    mid:SetPoint("TOPLEFT", parent, "TOPLEFT", inset + radius, -inset)
    mid:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset - radius, inset)

    local left = tex()
    left:SetColorTexture(1, 1, 1, 1)
    left:SetPoint("TOPLEFT", parent, "TOPLEFT", inset, -inset - radius)
    left:SetPoint("BOTTOMRIGHT", parent, "BOTTOMLEFT", inset + radius, inset + radius)

    local right = tex()
    right:SetColorTexture(1, 1, 1, 1)
    right:SetPoint("TOPLEFT", parent, "TOPRIGHT", -inset - radius, -inset - radius)
    right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset, inset + radius)

    return r
end

function Rounded:SetColor(r, g, b, a)
    for _, t in ipairs(self.t) do t:SetVertexColor(r, g, b, a or 1) end
end

function Rounded:SetShown(shown)
    for _, t in ipairs(self.t) do t:SetShown(shown) end
end
function Rounded:Show() self:SetShown(true) end
function Rounded:Hide() self:SetShown(false) end

-- Fond arrondi avec bordure d'1 pixel.
function UI:Panel(frame, radius, bg, border)
    if border then
        frame.border = UI:Rounded(frame, radius, 0, "BACKGROUND", 0)
        frame.border:SetColor(unpack(border))
    end
    frame.bg = UI:Rounded(frame, border and radius - 1 or radius, border and 1 or 0, "BACKGROUND", 1)
    frame.bg:SetColor(unpack(bg))
    return frame
end

function UI:Text(parent, size, color, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetFont(UI.FONT, size or 12, "")
    fs:SetTextColor(unpack(color or UI.colors.text))
    fs:SetJustifyH("LEFT")
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    return fs
end

function UI:Icon(parent, name, size, color, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetTexture(UI.MEDIA .. name)
    t:SetSize(size, size)
    if color then t:SetVertexColor(unpack(color)) end
    return t
end

-- Texture d'objet / de jeu découpée en cercle ou carré arrondi (masque).
function UI:RoundIcon(parent, size, texture)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetSize(size, size)
    if texture then t:SetTexture(texture) end
    if parent.CreateMaskTexture then
        local m = parent:CreateMaskTexture()
        m:SetTexture(UI.MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        m:SetAllPoints(t)
        t:AddMaskTexture(m)
        t:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end
    return t
end

-- Couleur de classe "r,g,b".
function UI:ClassColor(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return unpack(UI.colors.text)
end

-- Format court de l'or pour les axes et cartes : "12,3k po".
function UI:ShortGold(copper)
    local g = (copper or 0) / 10000
    local neg = g < 0
    g = math.abs(g)
    local s
    if g >= 1e6 then s = string.format("%.1fM", g / 1e6)
    elseif g >= 1e4 then s = string.format("%.1fk", g / 1e3)
    else s = string.format("%d", math.floor(g)) end
    return (neg and "-" or "") .. s:gsub("%.", ",") .. " po"
end

function UI:Ago(t)
    if not t then return "-" end
    local d = time() - t
    if d < 3600 then return "à l'instant" end
    if d < 86400 then return string.format("il y a %d h", math.floor(d / 3600)) end
    return string.format("il y a %d j", math.floor(d / 86400))
end

-- Or entier avec séparateur de milliers : "12 345 po".
function UI:GoldText(copper)
    local g = math.floor((copper or 0) / 10000)
    local s = tostring(math.abs(g)):reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
    return "|cffffd24d" .. (g < 0 and "-" or "") .. s .. "|r po"
end

-- Infos d'objet avec demande de chargement si l'objet n'est pas en cache.
function UI:ItemInfo(itemID)
    local name, link, quality = WK.GetItemInfo(itemID)
    if not name and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
    local icon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID))
        or (GetItemIcon and GetItemIcon(itemID)) or "Interface\\Icons\\INV_Misc_QuestionMark"
    local r, g, b = 1, 1, 1
    local qc = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if qc then r, g, b = qc.r, qc.g, qc.b end
    return name or ("Objet #" .. itemID), icon, r, g, b, link
end

-- Les noms d'objets arrivent du serveur en différé : on rafraîchit l'écran.
WK:On("GET_ITEM_INFO_RECEIVED", function() WK:NotifyChanged() end)

-- Personnages triés : perso connecté en premier, puis par or décroissant.
function UI:SortedCharacters()
    local me = WK:CharKey()
    local list = {}
    for key, c in pairs(WK.DB.global.characters) do table.insert(list, { key = key, c = c }) end
    table.sort(list, function(a, b)
        if a.key == me then return true end
        if b.key == me then return false end
        return (a.c.money or 0) > (b.c.money or 0)
    end)
    return list
end

-- Icône de classe ronde.
local CLASS_TEX = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
function UI:SetClassIcon(tex, class)
    local co = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    if co then
        tex:SetTexture(CLASS_TEX)
        local dx, dy = (co[2] - co[1]) * 0.08, (co[4] - co[3]) * 0.08
        tex:SetTexCoord(co[1] + dx, co[2] - dx, co[3] + dy, co[4] - dy)
    else
        tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end
end
