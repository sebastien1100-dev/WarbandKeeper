local ADDON_NAME, WK = ...
local UI = WK.UI

-- Thèmes : chaque thème donne quelques couleurs de base, le reste de la palette est dérivé
-- pour rester cohérent (surfaces, survol, bordures…).
--   bg     : fond de la fenêtre        line  : bordures et teinte des surfaces
--   frame  : bordure extérieure        glow  : halo en haut de la fenêtre
--   text / muted : textes              accent : couleur d'accent par défaut
-- Les thèmes dynamiques (classe, faction) calculent leurs couleurs au chargement.

local function mix(a, b, t)
    return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end
local function scale(a, k) return { a[1] * k, a[2] * k, a[3] * k } end
local function rgba(c, a) return { c[1], c[2], c[3], a or 1 } end

local function classColor()
    local _, class = UnitClass("player")
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return { c.r, c.g, c.b } end
    return { 0.80, 0.80, 0.80 }
end

-- Construit la palette complète à partir des couleurs de base.
local function palette(b)
    local p = {
        frame    = rgba(b.frame),
        inset    = rgba(scale(b.bg, 0.75)),
        trim     = rgba(mix(b.bg, b.line, 0.45)),
        bg       = rgba(b.bg, 0.98),
        glow     = b.glow,
        sidebar  = rgba(scale(b.bg, 0.8)),
        surface  = rgba(mix(b.bg, b.line, 0.25)),
        surface2 = rgba(mix(b.bg, b.line, 0.40)),
        hover    = rgba(mix(b.bg, b.line, 0.55)),
        border   = rgba(b.line),
        text     = rgba(b.text),
        muted    = rgba(b.muted),
        dim      = rgba(mix(b.muted, b.bg, 0.38)),
        onAccent = rgba(b.onAccent or scale(b.bg, 0.6)),
        positive = { 0.62, 0.82, 0.48, 1 },
        negative = { 0.91, 0.42, 0.42, 1 },
        warning  = { 0.95, 0.66, 0.30, 1 },
        gold     = { 0.878, 0.741, 0.447, 1 },
        -- couleurs de sens, communes à tous les thèmes (à utiliser au lieu de valeurs en dur dans les pages)
        info     = { 0.30, 0.58, 1.00, 1 },  -- bleu : repos, information
        rule     = { 0.31, 0.82, 0.77, 1 },  -- turquoise : automatique, par règle
        plan     = { 0.71, 0.49, 0.95, 1 },  -- violet : mode plan, prévu
        silver   = { 0.72, 0.74, 0.78, 1 },  -- argent : secondaire (autre perso)
        mint     = { 0.66, 0.88, 0.71, 1 },  -- menthe : pastille de compte
        -- rôles de groupe (onglet LFG)
        tank     = { 0.48, 0.65, 0.86, 1 },
        heal     = { 0.56, 0.82, 0.54, 1 },
        dps      = { 0.88, 0.54, 0.49, 1 },
        -- monstres rares (alerte, carte)
        rare     = { 0.79, 0.71, 0.93, 1 },
    }
    return p
end

UI.themes = {
    {
        key = "vault", label = "Coffre-fort", desc = "Bois sombre, parchemin et or.",
        titleFont = "Fonts\\MORPHEUS.TTF",
        base = function() return {
            bg = { 0.086, 0.063, 0.043 }, line = { 0.290, 0.220, 0.125 }, frame = { 0.431, 0.329, 0.188 },
            glow = { 0.235, 0.165, 0.090 }, text = { 0.945, 0.902, 0.812 }, muted = { 0.706, 0.627, 0.478 },
            accent = { 0.878, 0.741, 0.447 }, onAccent = { 0.165, 0.110, 0.043 },
        } end,
    },
    {
        key = "frost", label = "Givre", desc = "Bleu nuit et cyan, net et lumineux.",
        base = function() return {
            bg = { 0.040, 0.070, 0.090 }, line = { 0.140, 0.250, 0.310 }, frame = { 0.160, 0.330, 0.420 },
            glow = { 0.050, 0.200, 0.280 }, text = { 0.900, 0.950, 0.970 }, muted = { 0.560, 0.670, 0.730 },
            accent = { 0.050, 0.760, 1.000 }, onAccent = { 0.020, 0.080, 0.110 },
        } end,
    },
    {
        key = "graphite", label = "Graphite", desc = "Gris neutre, sobre, couleur de ta classe en accent.",
        base = function() return {
            bg = { 0.060, 0.064, 0.070 }, line = { 0.190, 0.200, 0.220 }, frame = { 0.240, 0.250, 0.270 },
            glow = { 0.140, 0.150, 0.170 }, text = { 0.930, 0.940, 0.950 }, muted = { 0.600, 0.620, 0.660 },
            accent = classColor(), onAccent = { 0.050, 0.050, 0.060 },
        } end,
    },
    {
        key = "class", label = "Héraldique", desc = "Fenêtre aux couleurs de la classe du perso connecté.",
        base = function()
            local c = classColor()
            local bg = mix({ 0.055, 0.058, 0.064 }, c, 0.05)
            return {
                bg = bg, line = mix({ 0.17, 0.18, 0.20 }, c, 0.22), frame = mix({ 0.12, 0.12, 0.13 }, c, 0.55),
                glow = mix({ 0.08, 0.08, 0.09 }, c, 0.35), text = { 0.94, 0.94, 0.95 }, muted = mix({ 0.60, 0.62, 0.66 }, c, 0.15),
                accent = c, onAccent = { 0.05, 0.05, 0.06 },
            }
        end,
    },
    {
        key = "faction", label = "Faction", desc = "Alliance : bleu et or. Horde : rouge et fer.",
        base = function()
            if UnitFactionGroup("player") == "Horde" then
                return {
                    bg = { 0.085, 0.045, 0.040 }, line = { 0.300, 0.140, 0.110 }, frame = { 0.470, 0.140, 0.110 },
                    glow = { 0.260, 0.070, 0.050 }, text = { 0.950, 0.910, 0.880 }, muted = { 0.720, 0.600, 0.560 },
                    accent = { 0.900, 0.280, 0.200 }, onAccent = { 0.120, 0.030, 0.020 },
                }
            end
            return {
                bg = { 0.045, 0.060, 0.105 }, line = { 0.170, 0.220, 0.340 }, frame = { 0.620, 0.500, 0.250 },
                glow = { 0.080, 0.140, 0.300 }, text = { 0.930, 0.940, 0.970 }, muted = { 0.600, 0.650, 0.760 },
                accent = { 0.960, 0.780, 0.320 }, onAccent = { 0.060, 0.070, 0.120 },
            }
        end,
    },
    {
        key = "fel", label = "Gangrefeu", desc = "Noir profond et vert gangrené.",
        base = function() return {
            bg = { 0.040, 0.060, 0.040 }, line = { 0.150, 0.250, 0.110 }, frame = { 0.250, 0.450, 0.130 },
            glow = { 0.100, 0.260, 0.050 }, text = { 0.920, 0.960, 0.880 }, muted = { 0.600, 0.700, 0.540 },
            accent = { 0.560, 1.000, 0.250 }, onAccent = { 0.040, 0.080, 0.020 },
        } end,
    },
    {
        key = "void", label = "Néant", desc = "Violet et ombre, façon magie du Vide.",
        base = function() return {
            bg = { 0.065, 0.045, 0.100 }, line = { 0.230, 0.160, 0.340 }, frame = { 0.400, 0.260, 0.620 },
            glow = { 0.200, 0.100, 0.360 }, text = { 0.950, 0.930, 0.990 }, muted = { 0.680, 0.620, 0.780 },
            accent = { 0.730, 0.520, 1.000 }, onAccent = { 0.080, 0.050, 0.130 },
        } end,
    },
}
-- Thème personnalisé : couleurs choisies dans les Options (départ : Coffre-fort).
UI.CUSTOM_KEYS = {
    { "bg", "Fond" }, { "line", "Bordures" }, { "frame", "Cadre" }, { "glow", "Halo" },
    { "text", "Texte" }, { "muted", "Texte secondaire" }, { "accent", "Accent" },
}
table.insert(UI.themes, {
    key = "custom", label = "Personnalisé", desc = "Tes propres couleurs, réglables dans la carte « Thème personnalisé ».",
    base = function()
        local saved = WK.DB and WK.DB.global.settings.ui.custom
        local b = UI.themes[1].base()
        if saved then
            for _, k in ipairs(UI.CUSTOM_KEYS) do
                local c = saved[k[1]]
                if c then b[k[1]] = { c[1], c[2], c[3] } end
            end
            b.onAccent = nil
        end
        return b
    end,
})

-- Couleurs de base d'un thème (pour copier un thème dans le thème personnalisé).
function UI:ThemeBase(key)
    local t = self.themeByKey[key] or self.themes[1]
    return t.base()
end

UI.themeByKey = {}
for _, t in ipairs(UI.themes) do UI.themeByKey[t.key] = t end

-- Palette d'un thème (pour les aperçus des options).
function UI:ThemePalette(key)
    local t = self.themeByKey[key] or self.themes[1]
    local b = t.base()
    return palette(b), b.accent
end

-- Polices proposées pour le texte de l'interface.
UI.fonts = {
    { key = "friz", label = "Friz Quadrata", path = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF" },
    { key = "arialn", label = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
    { key = "morpheus", label = "Morpheus", path = "Fonts\\MORPHEUS.TTF" },
    { key = "skurri", label = "Skurri", path = "Fonts\\SKURRI.TTF" },
}
-- Teinte du fond (Options > Apparence) : décalage léger du graphite vers le bleu ou le brun
-- (froid / chaud : réglage « Teinte du fond » ; les autres, plus marquées, viennent des styles prêts)
local TINTS = {
    cold = { -0.008, 0.002, 0.020 }, warm = { 0.020, 0.008, -0.010 },
    night = { -0.012, 0.014, 0.060 }, forest = { -0.006, 0.030, 0.002 }, gold = { 0.046, 0.026, -0.012 },
    violet = { 0.026, -0.006, 0.056 }, ember = { 0.056, -0.006, -0.012 },
}
UI.TINTS = TINTS
-- habillages : heraldic (barre latérale pleine, titres de cartes sur un bandeau), ink (cartes sans fond ni
-- bordure, trait d'accent à gauche, grands titres), leather (cuir et or : titres centrés soulignés d'un filet)
UI.SKINS = {
    heraldic = { base = { bg = { 0.066, 0.070, 0.080 } } },
    ink = { base = { bg = { 0.058, 0.062, 0.070 } } },
    leather = { base = { bg = { 0.100, 0.070, 0.043 }, line = { 0.330, 0.235, 0.125 }, frame = { 0.400, 0.290, 0.150 },
        glow = { 0.200, 0.140, 0.075 }, text = { 0.945, 0.902, 0.812 }, muted = { 0.720, 0.625, 0.470 } } },
}
-- fond et bordure d'un style (vignettes des styles prêts) : graphite + teinte
function UI:TintedBase(tint, skin)
    local b = (self.themeByKey.graphite or self.themes[1]).base()
    local sk = skin and self.SKINS[skin]
    if sk and sk.base then
        for k, v in pairs(sk.base) do b[k] = v end
        if sk.base.line then tint = nil end
    end
    local t = TINTS[tint or ""] or { 0, 0, 0 }
    local function sh(c) return { math.max(0, c[1] + t[1]), math.max(0, c[2] + t[2]), math.max(0, c[3] + t[3]) } end
    return sh(b.bg), sh(b.line), sh(mix(b.bg, b.line, 0.25))
end

-- Applique le thème choisi : la palette est recopiée dans UI.colors (même table,
-- donc tous les fichiers qui ont gardé une référence la voient). À faire avant de
-- construire l'interface ; un changement de thème demande de recharger l'interface.
function UI:ApplyTheme()
    local cfg = WK.DB.global.settings.ui
    -- Anciennes versions : accent n°1 (or) = accent du thème Coffre-fort.
    if cfg.accent == 1 and (cfg.theme or "vault") == "vault" then cfg.accent = "theme" end
    -- un seul thème proposé : Graphite (les autres et le thème personnalisé ne sont plus dans les Options)
    cfg.theme = "graphite"
    -- réglages d'Apparence retirés (accent par perso, contraste, style des cartes, animation, teinte, halo) : remis
    -- d'origine une fois ; dégradé, police des titres, arrondi et fond restent ceux du style choisi
    if not cfg.lookTrim then
        cfg.lookTrim = true
        cfg.accentPerChar, cfg.charAccent, cfg.contrast, cfg.cardStyle, cfg.anim = nil, nil, nil, nil, nil
        cfg.bgTint, cfg.glow, cfg.glowTint = nil, nil, nil
    end
    local t = self.themeByKey[cfg.theme] or self.themes[1]
    local b = t.base()
    local tint = TINTS[cfg.bgTint or ""]
    if tint then
        for _, k in ipairs({ "bg", "line", "frame", "glow" }) do
            local c = b[k]
            if c then b[k] = { math.max(0, c[1] + tint[1]), math.max(0, c[2] + tint[2]), math.max(0, c[3] + tint[3]) } end
        end
    end
    -- habillage (styles prêts) : change la forme des cartes, de la barre latérale et des pastilles ; certains
    -- donnent aussi leurs couleurs de base (le cuir ignore la teinte du fond)
    local skin = UI.SKINS[cfg.skin or ""]
    self.skin = skin and cfg.skin or nil
    if skin and skin.base then for k, v in pairs(skin.base) do b[k] = v end end
    -- contraste des textes secondaires (doux : plus proches du fond ; fort : plus proches du texte)
    if cfg.contrast == "strong" then
        b.muted = mix(b.muted, b.text, 0.35)
    elseif cfg.contrast == "soft" then
        b.muted = mix(b.muted, b.bg, 0.22)
    end
    local p = palette(b)
    p.bg[4] = 0.98 * (cfg.opacity or 1)
    for k, v in pairs(p) do self.colors[k] = v end
    self.themeAccent = b.accent
    -- halo teinté par l'accent (styles prêts)
    if cfg.glowTint then
        local r, g, bl = self:Accent()
        local gl = p.glow
        p.glow = { gl[1] + (r - gl[1]) * 0.4, gl[2] + (g - gl[2]) * 0.4, gl[3] + (bl - gl[3]) * 0.4, gl[4] }
        self.colors.glow = p.glow
    end
    self.TITLE_FONT = t.titleFont or (STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF")
    self.FONT = self.fonts[1].path
    for _, f in ipairs(self.fonts) do
        if f.key == cfg.font then self.FONT = f.path end
    end
    self.radiusScale = cfg.rounding or 1
    -- taille du texte (tous les textes de l'addon créés par UI:Text) et style des cartes (plat, liseré, halo)
    self.textScale = math.max(0.8, math.min(1.3, cfg.textScale or 1))
    self.cardStyle = cfg.cardStyle or "line"
    -- police des titres des cartes (nil : celle du texte)
    self.CARD_TITLE_FONT = nil
    for _, f in ipairs(self.fonts) do if f.key == cfg.titleFont then self.CARD_TITLE_FONT = f.path end end
    self.theme = t
end
