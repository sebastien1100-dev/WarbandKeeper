local ADDON_NAME, WK = ...

-- Thème visuel : couleurs, polices, formes arrondies.
local UI = { pages = {}, pageOrder = {}, inputs = {}, accentHooks = {} }
WK.UI = UI

UI.MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"
UI.FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
UI.TITLE_FONT = "Fonts\\MORPHEUS.TTF" -- police médiévale du jeu (titre uniquement)

-- Palette par défaut (« Coffre-fort ») ; remplacée par UI:ApplyTheme (UI/Themes.lua).
UI.colors = {
    frame    = { 0.431, 0.329, 0.188, 1 },   -- bordure extérieure de la fenêtre
    inset    = { 0.102, 0.071, 0.043, 1 },   -- liseré sombre entre les deux bordures
    trim     = { 0.231, 0.173, 0.094, 1 },   -- bordure intérieure
    bg       = { 0.086, 0.063, 0.043, 0.98 },
    glow     = { 0.235, 0.165, 0.090 },      -- halo chaud en haut de la fenêtre
    sidebar  = { 0.070, 0.050, 0.032, 1 },
    surface  = { 0.129, 0.094, 0.059, 1 },
    surface2 = { 0.169, 0.125, 0.078, 1 },
    hover    = { 0.205, 0.153, 0.094, 1 },
    border   = { 0.290, 0.220, 0.125, 1 },
    text     = { 0.945, 0.902, 0.812, 1 },
    muted    = { 0.706, 0.627, 0.478, 1 },
    dim      = { 0.490, 0.420, 0.300, 1 },
    onAccent = { 0.165, 0.110, 0.043, 1 },
    positive = { 0.62, 0.82, 0.48, 1 },
    negative = { 0.91, 0.42, 0.42, 1 },
    gold     = { 0.878, 0.741, 0.447, 1 },
}

-- Couleurs d'accent proposées dans les options, en plus de « Thème » et « Classe ».
UI.accents = {
    { 0.878, 0.741, 0.447 }, -- or
    { 0.850, 0.560, 0.310 }, -- cuivre
    { 0.640, 0.850, 0.420 }, -- vert
    { 0.200, 0.800, 0.620 }, -- émeraude
    { 0.400, 0.760, 1.000 }, -- bleu
    { 0.700, 0.560, 1.000 }, -- violet
}

-- Dégradé sur une texture (API moderne SetGradient, ancienne SetGradientAlpha).
-- c1 = couleur min (gauche / bas), c2 = couleur max (droite / haut), {r,g,b,a}.
function UI:SetGradient(tex, orient, c1, c2)
    tex:SetColorTexture(1, 1, 1, 1)
    if CreateColor and tex.SetGradient then
        local ok = pcall(tex.SetGradient, tex, orient, CreateColor(unpack(c1)), CreateColor(unpack(c2)))
        if ok then return end
    end
    if tex.SetGradientAlpha then
        tex:SetGradientAlpha(orient, c1[1], c1[2], c1[3], c1[4], c2[1], c2[2], c2[3], c2[4])
        return
    end
    tex:SetColorTexture(c2[1], c2[2], c2[3], (c1[4] + c2[4]) / 2)
end

-- Accent : "theme" (celui du thème), "class" (couleur de classe) ou un index de UI.accents.
function UI:Accent()
    local choice = WK.DB.global.settings.ui.accent
    local a
    if choice == "class" then
        local _, class = UnitClass("player")
        local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if c then return c.r, c.g, c.b end
    elseif type(choice) == "number" then
        a = self.accents[choice]
    end
    a = a or self.themeAccent or self.accents[1]
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
    radius = math.max(1, radius * (UI.radiusScale or 1))
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
    -- Les textes fixes sont traduits à l'affichage (clé = texte français).
    local set = fs.SetText
    fs.SetText = function(self, t) return set(self, WK.T(t)) end
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
    local dec = WK.Lang() == "frFR" and "," or "."
    return (neg and "-" or "") .. s:gsub("%.", dec) .. " " .. WK.T("po")
end

function UI:Ago(t)
    if not t then return "-" end
    local d = time() - t
    if d < 3600 then return WK.T("à l'instant") end
    if d < 86400 then return string.format(WK.T("il y a %d h"), math.floor(d / 3600)) end
    return string.format(WK.T("il y a %d j"), math.floor(d / 86400))
end

-- Or entier avec séparateur de milliers : "12 345 po".
function UI:GoldText(copper)
    copper = copper or 0
    if copper ~= 0 and math.abs(copper) < 10000 then
        local sv = math.floor(math.abs(copper) / 100)
        return "|cffc7c7cf" .. (copper < 0 and "-" or "") .. sv .. "|r " .. WK.T("pa")
    end
    local g = math.floor(copper / 10000)
    local s = tostring(math.abs(g)):reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
    return "|cffffd24d" .. (g < 0 and "-" or "") .. s .. "|r " .. WK.T("po")
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
    return name or (WK.T("Objet #") .. itemID), icon, r, g, b, link
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

-- Portrait d'un perso : le vrai portrait pour le perso connecté (le jeu ne le donne que
-- pour lui), l'icône de race et de sexe pour les autres, l'icône de classe sinon ou si
-- l'option « Portraits » est désactivée.
local RACE_FILE = { Scourge = "Undead", NightElf = "Nightelf", BloodElf = "Bloodelf" }
local function atlasExists(name)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end
function UI:SetCharIcon(tex, c, key)
    local cfg = WK.DB and WK.DB.global and WK.DB.global.settings.ui
    if not c or (cfg and cfg.portraits == false) then return UI:SetClassIcon(tex, c and c.class) end
    if key and key == select(2, WK.DB:Me()) and SetPortraitTexture then
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        SetPortraitTexture(tex, "player")
        return
    end
    if c.race then
        local race = RACE_FILE[c.race] or c.race
        local female = c.sex == 3
        local atlas = "raceicon-" .. string.lower(race) .. "-" .. (female and "female" or "male")
        if tex.SetAtlas and atlasExists(atlas) then
            tex:SetTexCoord(0, 1, 0, 1)
            tex:SetAtlas(atlas)
            return
        end
        tex:SetTexture("Interface\\Icons\\Achievement_Character_" .. race .. "_" .. (female and "Female" or "Male"))
        tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        return
    end
    UI:SetClassIcon(tex, c.class)
end

-- Majuscules avec les lettres accentuées (string.upper ne traite que l'ASCII).
local ACCENTS = {
    ["à"] = "À", ["â"] = "Â", ["ä"] = "Ä", ["ç"] = "Ç", ["é"] = "É", ["è"] = "È", ["ê"] = "Ê", ["ë"] = "Ë",
    ["î"] = "Î", ["ï"] = "Ï", ["ô"] = "Ô", ["ö"] = "Ö", ["ù"] = "Ù", ["û"] = "Û", ["ü"] = "Ü", ["œ"] = "Œ",
}
function UI:Upper(s)
    s = string.upper(s or "")
    return (s:gsub("[\195\197][\128-\191]", function(c) return ACCENTS[c] or c end))
end

-- Code couleur "|cffRRGGBB" d'une couleur {r, g, b} (pour colorer une partie d'un texte).
function UI:Hex(c)
    return string.format("|cff%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end

-- Montant lisible sans couleur : or au-dessus d'1 po (format court), argent en dessous.
-- Montant exact, pour les prix d'enchères : « 2 po 50 pa 3 pc » (les zéros sont omis)
function UI:ExactMoney(copper)
    copper = math.floor(copper or 0)
    local neg = copper < 0
    copper = math.abs(copper)
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    if g > 0 then table.insert(parts, tostring(g):reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "") .. " " .. WK.T("po")) end
    if s > 0 then table.insert(parts, s .. " " .. WK.T("pa")) end
    if c > 0 or #parts == 0 then table.insert(parts, c .. " " .. WK.T("pc")) end
    return (neg and "-" or "") .. table.concat(parts, " ")
end

function UI:PlainMoney(copper)
    copper = copper or 0
    if copper ~= 0 and math.abs(copper) < 10000 then
        return (copper < 0 and "-" or "") .. math.floor(math.abs(copper) / 100) .. " " .. WK.T("pa")
    end
    return self:ShortGold(copper)
end
