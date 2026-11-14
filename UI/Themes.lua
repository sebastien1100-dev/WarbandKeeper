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
}

-- Applique le thème choisi : la palette est recopiée dans UI.colors (même table,
-- donc tous les fichiers qui ont gardé une référence la voient). À faire avant de
-- construire l'interface ; un changement de thème demande de recharger l'interface.
function UI:ApplyTheme()
    local cfg = WK.DB.global.settings.ui
    -- Anciennes versions : accent n°1 (or) = accent du thème Coffre-fort.
    if cfg.accent == 1 and (cfg.theme or "vault") == "vault" then cfg.accent = "theme" end
    local t = self.themeByKey[cfg.theme] or self.themes[1]
    local b = t.base()
    local p = palette(b)
    p.bg[4] = 0.98 * (cfg.opacity or 1)
    for k, v in pairs(p) do self.colors[k] = v end
    self.themeAccent = b.accent
    self.TITLE_FONT = t.titleFont or (STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF")
    for _, f in ipairs(self.fonts) do
        if f.key == cfg.font then self.FONT = f.path end
    end
    self.radiusScale = cfg.rounding or 1
    self.theme = t
end
