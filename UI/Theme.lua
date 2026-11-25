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
    { 0.960, 0.550, 0.730 }, -- rose
    { 1.000, 0.420, 0.420 }, -- rouge
    { 0.860, 0.870, 0.900 }, -- argent
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
-- Choix d'accent en place : celui de ce perso (accent par perso, Options > Apparence), sinon le général
function UI:AccentChoice()
    local cfg = WK.DB.global.settings.ui
    if cfg.accentPerChar and type(cfg.charAccent) == "table" then
        local c = cfg.charAccent[WK:CharKey()]
        if c ~= nil then return c end
    end
    return cfg.accent
end
-- 2e couleur du dégradé d'accent (jauges), ou nil
function UI:Accent2()
    local i = WK.DB.global.settings.ui.accent2
    local a = type(i) == "number" and self.accents[i]
    if a then return a[1], a[2], a[3] end
end
function UI:Accent()
    local choice = self:AccentChoice()
    local a
    if choice == "class" then
        local _, class = UnitClass("player")
        local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if c then return c.r, c.g, c.b end
    elseif type(choice) == "number" then
        a = self.accents[choice]
    elseif choice == "custom" then
        -- ta couleur (Options > Apparence : code #RRGGBB)
        local c = WK.DB.global.settings.ui.accentRGB
        if type(c) == "table" and c[1] then a = c end
    end
    a = a or self.themeAccent or self.accents[1]
    return a[1], a[2], a[3]
end

-- Les widgets qui utilisent l'accent s'enregistrent ici pour se mettre à jour en direct.
-- owner (facultatif, sinon la portée en cours, voir InAccentScope) : propriétaire du crochet,
-- pour ne retirer que ceux d'une partie reconstruite (« window » : la fenêtre principale).
UI.accentOwners = setmetatable({}, { __mode = "k" })
function UI:OnAccent(fn, owner)
    table.insert(self.accentHooks, fn)
    owner = owner or self.accentScope
    if owner then self.accentOwners[fn] = owner end
    fn()
end

-- Exécute fn(...) : les crochets d'accent posés pendant ce temps appartiennent à owner.
function UI:InAccentScope(owner, fn, ...)
    local prev = self.accentScope
    self.accentScope = owner
    local ok, res = pcall(fn, ...)
    self.accentScope = prev
    if not ok then error(res, 0) end
    return res
end

-- Retire les crochets d'accent d'un propriétaire (les autres éléments à l'écran gardent les leurs).
function UI:DropAccentHooks(owner)
    local keep = {}
    for _, fn in ipairs(self.accentHooks) do
        if self.accentOwners[fn] == owner then self.accentOwners[fn] = nil else table.insert(keep, fn) end
    end
    wipe(self.accentHooks)
    for i, fn in ipairs(keep) do self.accentHooks[i] = fn end
end

-- Tous les éléments repeints à la couleur d'accent du moment : un élément construit avant que le perso soit
-- connu (accent par perso, couleur de classe) gardait l'accent général jusqu'à son survol. Appelé à l'entrée
-- en jeu et à chaque ouverture de la fenêtre, seulement si l'accent a changé depuis le dernier passage.
function UI.RefreshAccentAll(force)
    local r, g, b = UI:Accent()
    local sig = string.format("%.3f:%.3f:%.3f:%s", r, g, b, tostring(UI.skin))
    if not force and sig == UI.accentSig then return end
    UI.accentSig = sig
    for _, fn in ipairs(UI.accentHooks) do pcall(fn) end
end
WK:On("PLAYER_ENTERING_WORLD", function() UI.accentSig = nil; UI.RefreshAccentAll() end)

function UI:SetAccent(index)
    local cfg = WK.DB.global.settings.ui
    if cfg.accentPerChar then
        cfg.charAccent = cfg.charAccent or {}
        cfg.charAccent[WK:CharKey()] = index
    else
        cfg.accent = index
    end
    for _, fn in ipairs(self.accentHooks) do fn() end
    UI.accentSig = nil
    -- halo teinté par l'accent (styles prêts, UI:ApplyTheme) : il n'est recalculé qu'en reconstruisant
    if cfg.glowTint and self.Rebuild then self:Rebuild() end
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

-- Fond commun des fenêtres et cadres à l'écran (un seul fond pour tout l'addon) : graphite du thème (C.bg) et
-- liseré gris fin (C.border), coins de 10 px. kind = "window" (grandes fenêtres) ou "hud" (cadres posés sur le
-- jeu). Opacité réglable pour tous (settings.ui.hudOpacity, Options > Apparence > Fenêtre ; les grandes fenêtres
-- un peu plus opaques), pleine au survol de la souris. Fond et contour : frame.bg et frame.border (ou frame.edge).
UI.HUD_ALPHA, UI.WINDOW_ALPHA = 0.92, 0.96
UI.hudFrames, UI.hudAlphaFrames = {}, {}
function UI.HudAlpha(_, frame, kind)
    if frame and frame.hudHover then return 1 end
    local ui = WK.DB and WK.DB.global and WK.DB.global.settings and WK.DB.global.settings.ui
    local a = ui and ui.hudOpacity or UI.HUD_ALPHA
    kind = kind or (frame and frame.hudKind)
    if kind == "window" then a = math.min(1, a + 0.04) end
    return a
end
function UI.HudPaint(_, frame, kind, alpha)
    local C = UI.colors
    local a = alpha or UI:HudAlpha(frame, kind)
    if frame.bg then frame.bg:SetColor(C.bg[1], C.bg[2], C.bg[3], a) end
    local edge = frame.border or frame.edge
    if edge then edge:SetColor(C.border[1], C.border[2], C.border[3], math.min(1, a + 0.15)) end
end
-- cadre qui a déjà son fond (frame.bg + frame.border / frame.edge) : suivi du survol et de l'opacité réglée
function UI.HudRegister(_, frame, kind)
    if frame.hudKind then return frame end
    frame.hudKind = kind or "hud"
    table.insert(UI.hudFrames, frame)
    return frame
end
-- Options > Apparence > Fenêtre (réglage d'opacité des cadres), depuis un renvoi d'une autre page
function UI.OpenLookWindow()
    local ui = WK.DB.global.settings.ui
    ui.optSection, ui.lookTab = "look", "window"
    UI:ShowPage("options")
    if UI.lookShow then UI.lookShow("window") end
end
function UI.HudBackground(_, frame, kind, radius)
    UI:Panel(frame, radius or 10, { 0, 0, 0, 1 }, UI.colors.border)
    UI:HudRegister(frame, kind)
    UI:HudPaint(frame, kind)
    return frame
end
-- tous les cadres : réglage changé (Options) ou survol de la souris (10 fois par seconde, cadres affichés seulement)
function UI.HudRefreshAll()
    for _, f in ipairs(UI.hudFrames) do
        if not f.hudCustom then UI:HudPaint(f) end
        if f.OnHudPaint then pcall(f.OnHudPaint, f) end
    end
end
do
    local watcher = _G.CreateFrame("Frame")
    local acc = 0
    watcher:SetScript("OnUpdate", function(_, el)
        acc = acc + el
        if acc < 0.1 then return end
        acc = 0
        for _, f in ipairs(UI.hudFrames) do
            if f:IsVisible() then
                local over = f:IsMouseOver() and true or false
                if over ~= (f.hudHover or false) then
                    f.hudHover = over
                    if not f.hudCustom then UI:HudPaint(f) end
                    if f.OnHudPaint then pcall(f.OnHudPaint, f) end
                end
            elseif f.hudHover then
                f.hudHover = false
            end
        end
        -- cadres du mode édition dont l'opacité est baissée : pleine au survol
        local fight = _G.InCombatLockdown and _G.InCombatLockdown()
        for _, f in ipairs(UI.hudAlphaFrames) do
            if f:IsVisible() and not UI.editing and not (f.hudProtected and fight) then
                local e = UI:HUDEntry(f.hudEditKey)
                local base = e and e.alpha or 1
                if base < 1 and f.hudNoHoverFull then
                    -- cadre qui ne veut pas redevenir opaque au survol (réglage de la mini-fenêtre « À faire »)
                    if f.hudAlphaOver then f.hudAlphaOver = false; f:SetAlpha(base) end
                elseif base < 1 then
                    local over = f:IsMouseOver() and true or false
                    if over ~= (f.hudAlphaOver or false) then
                        f.hudAlphaOver = over
                        f:SetAlpha(over and 1 or base)
                    end
                elseif f.hudAlphaOver then
                    f.hudAlphaOver = nil
                end
            end
        end
    end)
end

-- Fenêtre collée à une fenêtre du jeu (talents, marchand, HV, courrier, sacs, métiers, carte…) : même strate
-- que celle-ci et juste au-dessus de son niveau, pour passer devant ou derrière les autres fenêtres avec elle
-- (la fenêtre de l'addon, au-dessus, la couvre comme elle couvre la fenêtre du jeu).
function UI:MatchHost(f, host, add)
    if not (f and host and host.GetFrameStrata and f.SetFrameStrata) then return end
    if InCombatLockdown and InCombatLockdown() and f.IsProtected and f:IsProtected() then return end
    f:SetFrameStrata(host:GetFrameStrata() or "MEDIUM")
    if host.GetFrameLevel and f.SetFrameLevel then f:SetFrameLevel(math.min(9000, (host:GetFrameLevel() or 1) + (add or 5))) end
end

-- cadres dont les textes sont agrandis (fenêtre de l'HV : UI.textBoost[cadre] = 1.15), cherchés parmi les parents
UI.textBoost = setmetatable({}, { __mode = "k" })
local function boostOf(parent)
    if not next(UI.textBoost) then return 1 end
    local p, n = parent, 0
    while p and n < 14 do
        local b = UI.textBoost[p]
        if b then return b end
        p = p.GetParent and p:GetParent() or nil
        n = n + 1
    end
    return 1
end
UI.MIN_TEXT = 10
function UI:Text(parent, size, color, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    -- taille 10 au moins : en-têtes de colonnes et légendes en 8-9 étaient trop petits (audit du design)
    size = math.max(size or 12, UI.MIN_TEXT)
    fs:SetFont(UI.FONT, math.floor(size * (UI.textScale or 1) * boostOf(parent) + 0.5), "")
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
    -- moins d'une pièce d'argent : en cuivre (sinon « 0 pa »)
    if copper ~= 0 and math.abs(copper) < 100 then
        return "|cffeda55f" .. (copper < 0 and "-" or "") .. math.floor(math.abs(copper)) .. "|r " .. WK.T("pc")
    end
    if copper ~= 0 and math.abs(copper) < 10000 then
        local sv = math.floor(math.abs(copper) / 100)
        return "|cffc7c7cf" .. (copper < 0 and "-" or "") .. sv .. "|r " .. WK.T("pa")
    end
    -- valeur absolue arrondie vers le bas, puis le signe (math.floor d'un négatif arrondissait vers le haut)
    local g = math.floor(math.abs(copper) / 10000)
    local s = tostring(g):reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
    return "|cffffd24d" .. ((copper < 0 and g > 0) and "-" or "") .. s .. "|r " .. WK.T("po")
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
-- un objet inconnu du serveur (success faux) ne redessine qu'une fois : chaque dessin le redemande et la réponse
-- « échec » relançait le dessin, sans fin (ex. le perso en 3D de l'onglet BiS qui clignotait)
local itemFailed = {}
WK:On("GET_ITEM_INFO_RECEIVED", function(itemID, success)
    if success == false and itemID then
        if itemFailed[itemID] then return end
        itemFailed[itemID] = true
    end
    WK:NotifyChanged()
end)

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

-- « Alliance · JcE » : faction et type du royaume (lu dans son nom : PvE, PvP, RP, RPPvP), sinon le royaume
function UI:FactionRealm(c)
    local fac = c.faction and ((c.faction == "Alliance" and WK.T("Alliance")) or (c.faction == "Horde" and WK.T("Horde")) or c.faction) or nil
    local r = (c.realm or ""):lower()
    local kind
    if r:find("rp%s*%-?%s*pvp") or r:find("rppvp") then kind = WK.T("JdR-JcJ")
    elseif r:find("pvp") then kind = WK.T("JcJ")
    elseif r:find("rp") and (r:find("%f[%a]rp%f[%A]") or r:find("roleplay")) then kind = WK.T("JdR")
    elseif r:find("pve") or r:find("normal") then kind = WK.T("JcE") end
    local parts = {}
    if fac then table.insert(parts, fac) end
    table.insert(parts, kind or c.realm or "")
    return table.concat(parts, "  ·  ")
end

-- Durée écoulée courte : « il y a 12 min », « il y a 2 h 05 » (bare : « 12 min », « 2 h 05 »)
function UI:AgoShort(sec, bare)
    sec = math.max(0, sec or 0)
    local t
    if sec < 60 then t = WK.T("< 1 min")
    elseif sec < 3600 then t = string.format(WK.T("%d min"), math.floor(sec / 60))
    else t = string.format("%d h %02d", math.floor(sec / 3600), math.floor(sec % 3600 / 60)) end
    if bare then return t end
    return string.format(WK.T("il y a %s"), t) -- phrase entière : l'anglais met « ago » après
end


-- Infobulles de comparaison du jeu (« Équipé ») : cachées pour les cadres marqués wkNoCompare (objet déjà porté)
function UI:HideCompare()
    for i = 1, 3 do
        local t = _G["ShoppingTooltip" .. i]
        if t and t:IsShown() then t:Hide() end
    end
end
for i = 1, 3 do
    local t = _G["ShoppingTooltip" .. i]
    if t and t.HookScript then
        t:HookScript("OnShow", function(s)
            local owner = GameTooltip and GameTooltip:IsShown() and GameTooltip:GetOwner()
            if owner and owner.wkNoCompare then s:Hide() end
        end)
    end
end
