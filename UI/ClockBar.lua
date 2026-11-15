local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Horloge en haut de l'écran : au repos, l'heure et deux petites barres dessous (FPS, latence).
-- Au survol, les raccourcis glissent de chaque côté de l'heure, sans fond (chaque icône a sa
-- tuile) ; effet loupe façon dock (réglable). Des zones invisibles suivent les icônes pour le survol. Repli quand
-- la souris s'en va. Hors combat seulement pour le dépliage (la pierre de foyer est un
-- bouton protégé que le jeu interdit de bouger en combat).
-- Réglages : WK.modules.QoL:Config().clock

local BASE = 28        -- taille d'une icône au repos (déplié), réglable (clock.size)
local GAP = 6          -- écart entre les trois fonds
local IGAP = 4         -- écart entre deux icônes
local PAD = 4          -- marge intérieure des fonds
local bar

-- Raccourcis disponibles. secure : bouton protégé (objet ou sort) ; sinon une fonction.
local SHORTCUTS = {
    { key = "wk", label = "Warband Keeper", icon = function() return UI.MEDIA .. "mm_wk" end, tint = true,
      run = function() UI:ToggleWindow() end },
    { key = "mail", label = "Courrier", icon = function() return UI.MEDIA .. "mm_mail" end, tint = true,
      run = function() UI:Create():Show(); UI:ShowPage("mail") end,
      dot = function()
          for _, c in pairs(WK.DB.global.characters) do
              if c.mailbox and (c.mailbox.count or 0) > 0 then return C.gold end
          end
      end },
    { key = "hearth", label = "Pierre de foyer", secure = { type = "item", item = "item:6948" },
      icon = function() return UI.MEDIA .. "mm_hearth" end, tint = true,
      tip = function() return GetBindLocation and GetBindLocation() end },
    { key = "char", label = "Personnage", icon = function() return UI.MEDIA .. "mm_char" end, tint = true,
      run = function() if ToggleCharacter then ToggleCharacter("PaperDollFrame") end end },
    { key = "spells", label = "Grimoire", icon = function() return UI.MEDIA .. "mm_book" end, tint = true,
      run = function() if ToggleSpellBook then ToggleSpellBook(BOOKTYPE_SPELL or "spell") end end },
    { key = "talents", label = "Talents", icon = function() return UI.MEDIA .. "mm_talents" end, tint = true,
      run = function() if ToggleTalentFrame then ToggleTalentFrame() end end },
    { key = "map", label = "Carte", icon = function() return UI.MEDIA .. "mm_map" end, tint = true,
      run = function() if ToggleWorldMap then ToggleWorldMap() end end },
    { key = "quests", label = "Journal de quêtes", icon = function() return UI.MEDIA .. "mm_quest" end, tint = true,
      run = function() if ToggleQuestLog then ToggleQuestLog() end end },
    { key = "social", label = "Social et guilde", icon = function() return UI.MEDIA .. "mm_social" end, tint = true,
      run = function() if ToggleFriendsFrame then ToggleFriendsFrame() end end },
    { key = "prof", label = "Métier principal", icon = function() return UI.MEDIA .. "mm_prof" end, tint = true,
      run = function()
          local me = WK.DB:Me()
          for name in pairs(me.professions or {}) do
              local k = WK.modules.Gathering:Kind(name)
              if k ~= "herb" and k ~= "skin" then WK.modules.Professions:OpenDirect(name) return end
          end
      end },
    { key = "farm", label = "Session de farm", icon = function() return UI.MEDIA .. "mm_farm" end, tint = true,
      run = function() local F = WK.modules.Farm; if F:Active() then F:Stop() else F:Start() end end,
      dot = function() return WK.modules.Farm:Active() and C.positive or nil end },
    { key = "menu", label = "Menu du jeu", icon = function() return UI.MEDIA .. "mm_menu" end, tint = true,
      run = function() if ToggleGameMenu then ToggleGameMenu() end end },
}
UI.CLOCK_SHORTCUTS = SHORTCUTS

local DEFAULTS = {
    enabled = true, server = false, h12 = false, magnify = 0.8, stats = true, size = 28,
    side = { wk = "L", mail = "L", hearth = "L", char = "R", spells = "R", talents = "R", map = "R" },
}
local function cfg()
    local q = WK.modules.QoL:Config()
    q.clock = q.clock or {}
    for k, v in pairs(DEFAULTS) do
        if q.clock[k] == nil then
            if type(v) == "table" then q.clock[k] = {}; for a, b in pairs(v) do q.clock[k][a] = b end else q.clock[k] = v end
        end
    end
    return q.clock
end
UI.ClockConfig = cfg

local function inCombat() return InCombatLockdown and InCombatLockdown() end

local function clockText()
    local o = cfg()
    local h, m
    if o.server and GetGameTime then h, m = GetGameTime() else h, m = tonumber(date("%H")), tonumber(date("%M")) end
    if o.h12 then
        local suf = h >= 12 and "pm" or "am"
        h = h % 12; if h == 0 then h = 12 end
        return string.format("%d:%02d%s", h, m, suf)
    end
    return string.format("%02d:%02d", h, m)
end

local function stats()
    local fps = GetFramerate and math.floor(GetFramerate() + 0.5) or 0
    local ms = 0
    if GetNetStats then local _, _, home, world = GetNetStats(); ms = math.max(home or 0, world or 0) end
    local fc = fps >= 50 and C.positive or (fps >= 30 and C.warning or C.negative)
    local mc = ms < 100 and C.positive or (ms < 200 and C.warning or C.negative)
    return fps, ms, fc, mc
end

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------
local function makeIcon(def)
    local b
    if def.secure then
        b = CreateFrame("Button", "WarbandKeeperClock_" .. def.key, bar, "SecureActionButtonTemplate")
        if b.RegisterForClicks then b:RegisterForClicks("AnyUp", "AnyDown") end
        b:SetAttribute("type", def.secure.type)
        b:SetAttribute(def.secure.type, def.secure.item)
    else
        b = CreateFrame("Button", nil, bar)
        b:SetScript("OnClick", function() def.run() end)
    end
    b:SetFrameLevel(bar.bg:GetFrameLevel() + 4)
    b.def = def
    -- tuile sombre arrondie, bordure fine, pictogramme au trait teinté à l'accent
    b.edge = UI:Rounded(b, 8, 0, "BACKGROUND", 0)
    b.bg = UI:Rounded(b, 7, 1, "BACKGROUND", 1)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetPoint("TOPLEFT", 6, -6)
    b.tex:SetPoint("BOTTOMRIGHT", -6, 6)
    b.dot = UI:Icon(b, "circle", 7, nil, "OVERLAY")
    b.dot:SetPoint("TOPRIGHT", -2, -2)
    b:SetScript("OnEnter", function(s)
        WK.UI:TooltipOwner(s, "ANCHOR_BOTTOM")
        GameTooltip:SetText(T(def.label), 1, 1, 1)
        local extra = def.tip and def.tip()
        if extra then GameTooltip:AddLine(extra, 0.8, 0.8, 0.8) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:Hide()
    return b
end

local function build()
    bar = CreateFrame("Frame", "WarbandKeeperClock", UIParent)
    bar:SetSize(120, 34)
    bar:SetFrameStrata("MEDIUM")
    bar:SetClampedToScreen(true)
    -- Seul le fond visible capte la souris : la place réservée aux raccourcis ne bloque pas le jeu.
    bar:EnableMouse(false)
    local function panel(visible)
        local p = CreateFrame("Frame", nil, bar)
        p:EnableMouse(true)
        p:SetSize(120, 34)
        if visible then UI:Panel(p, 12, { C.bg[1], C.bg[2], C.bg[3], 0.88 }, C.border) end
        return p
    end
    bar.bg = panel(true)       -- milieu : l'heure, sur son fond
    bar.bg:SetPoint("TOP")
    bar.lp = panel(false)      -- gauche : zone de survol invisible (pas de fond)
    bar.rp = panel(false)      -- droite
    bar.lp:Hide(); bar.rp:Hide()
    -- Heure (bouton : clic = calendrier si le jeu en a un, sinon Warband Keeper)
    bar.clockBtn = CreateFrame("Button", nil, bar)
    bar.clockBtn:SetAllPoints(bar.bg)
    bar.clockBtn:SetFrameLevel(bar.bg:GetFrameLevel() + 3)
    bar.time = UI:Text(bar.clockBtn, 18)
    bar.time:SetPoint("CENTER", 0, 3)
    bar.time:SetJustifyH("CENTER")
    -- FPS et latence : deux petites barres côte à côte sous l'heure (remplies selon la valeur)
    local function meter()
        local m = CreateFrame("Frame", nil, bar.clockBtn)
        m:SetSize(24, 3)
        m.track = UI:Rounded(m, 2, 0, "ARTWORK", 0)
        m.fill = m:CreateTexture(nil, "ARTWORK", nil, 1)
        m.fill:SetPoint("TOPLEFT"); m.fill:SetPoint("BOTTOMLEFT")
        return m
    end
    bar.fpsBar = meter()
    bar.msBar = meter()
    bar.fpsBar:SetPoint("BOTTOMRIGHT", bar.clockBtn, "BOTTOM", -2, 5)
    bar.msBar:SetPoint("BOTTOMLEFT", bar.clockBtn, "BOTTOM", 2, 5)
    function bar:Meter(m, frac, col)
        m.track:SetColor(C.border[1], C.border[2], C.border[3], 1)
        m.fill:SetWidth(math.max(1, (m:GetWidth() or 24) * math.max(0.08, math.min(1, frac))))
        m.fill:SetColorTexture(col[1], col[2], col[3], 1)
    end
    bar.clockBtn:SetScript("OnClick", function()
        if ToggleCalendar then ToggleCalendar() elseif GameTimeFrame and GameTimeFrame.Click then GameTimeFrame:Click() else UI:ToggleWindow() end
    end)
    bar.clockBtn:SetScript("OnEnter", function(s)
        WK.UI:TooltipOwner(s, "ANCHOR_BOTTOM")
        local d = date("*t")
        local DAYS = { "dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi" }
        local MONTHS = { "janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre" }
        GameTooltip:SetText(string.format("%s %d %s", T(DAYS[d.wday]), d.day, T(MONTHS[d.month])), 1, 1, 1)
        if GetGameTime then local h, m = GetGameTime(); GameTooltip:AddDoubleLine(T("Heure du serveur"), string.format("%02d:%02d", h, m), 0.8, 0.8, 0.8, 1, 1, 1) end
        GameTooltip:AddDoubleLine(T("Session de jeu"), WK:FormatTime(time() - (bar.loginAt or time())), 0.8, 0.8, 0.8, 1, 1, 1)
        local fps, ms = stats()
        GameTooltip:AddDoubleLine(T("FPS · latence"), fps .. " · " .. ms .. " ms", 0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:Show()
    end)
    bar.clockBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    bar.loginAt = time()
    bar.icons = {}
    for _, def in ipairs(SHORTCUTS) do bar.icons[def.key] = makeIcon(def) end
    bar.open = 0 -- 0 replié, 1 déplié (animé)
    bar.acc = 0
    bar:SetScript("OnUpdate", function(s, el) s:Tick(el) end)

    function bar:Lists()
        local o = cfg()
        local L, R = {}, {}
        for _, def in ipairs(SHORTCUTS) do
            local side = o.side[def.key]
            if side == "L" then table.insert(L, self.icons[def.key]) elseif side == "R" then table.insert(R, self.icons[def.key]) end
        end
        return L, R
    end

    function bar:Tick(el)
        local o = cfg()
        -- heure et points (2 fois par seconde)
        self.acc = self.acc + el
        if self.acc > 0.5 then
            self.acc = 0
            self.time:SetText(clockText())
            local fps, ms, fc, mc = stats()
            self:Meter(self.fpsBar, fps / 60, fc)
            self:Meter(self.msBar, 1 - ms / 400, mc)
            self.fpsBar:SetShown(o.stats); self.msBar:SetShown(o.stats)
            self.time:SetTextColor(UI:Accent())
        end
        -- dépliage au survol (hors combat), repli 0,4 s après le départ de la souris
        local over = self:Over()
        if over then self.leftAt = nil elseif not self.leftAt then self.leftAt = GetTime() end
        local want = (over or (self.leftAt and GetTime() - self.leftAt < 0.4)) and 1 or 0
        if inCombat() then want = self.open > 0.5 and 1 or 0 end
        local before = self.open
        if self.open < want then self.open = math.min(1, self.open + el * 6)
        elseif self.open > want then self.open = math.max(0, self.open - el * 6) end
        if self.open ~= before or self.open > 0 then self:Layout() end
    end

    -- Souris sur l'un des trois fonds (les côtés seulement quand ils sont dépliés)
    function bar:Over()
        if self.bg:IsMouseOver(4, -4, -4, 4) then return true end
        if self.open > 0.05 then
            if self.lp:IsShown() and self.lp:IsMouseOver(4, -4, -4, 4) then return true end
            if self.rp:IsShown() and self.rp:IsMouseOver(4, -4, -4, 4) then return true end
        end
        return false
    end

    -- Place les raccourcis : effet loupe selon la distance du curseur (hors combat). Chaque fond de
    -- côté épouse ses icônes : il grandit avec elles.
    function bar:Layout()
        if inCombat() then return end
        local o = cfg()
        local base = math.max(20, math.min(48, o.size or BASE))
        local k = base / BASE
        local L, R = self:Lists()
        local open = self.open
        local scale = self:GetEffectiveScale()
        local cx = (GetCursorPosition()) / scale
        local over = open > 0.05 and self:Over()
        local function sizeOf(x)
            if not over then return base end
            local d = math.abs(cx - x)
            local f = math.max(0, 1 - d / (base * 3))
            return math.floor(base * (1 + (o.magnify or 0) * f * f) + 0.5)
        end
        local clockW = math.floor(96 * k + 0.5)
        local h = base + PAD * 2
        local fs = math.floor(18 * k + 0.5)
        if self.fontSize ~= fs then self.fontSize = fs; self.time:SetFont(UI.FONT, fs, "") end
        local mw = math.floor(24 * k + 0.5)
        self.fpsBar:SetWidth(mw); self.msBar:SetWidth(mw)
        self.bg:SetSize(clockW, h)
        self:SetHeight(h)
        local left = self:GetLeft() or 0
        local mid = (self:GetWidth() or 120) / 2
        local slide = (1 - open) * 14 -- les côtés glissent depuis l'heure
        local function side(list, panel, dir)
            panel:SetShown(#list > 0 and open > 0.05)
            if #list == 0 then return end
            local edge = mid + dir * (clockW / 2 + GAP + slide) -- bord du fond côté heure
            local x = edge + dir * PAD
            local maxH = 0
            for _, ic in ipairs(list) do
                local sz = sizeOf(left + x + dir * base / 2)
                local x0 = dir > 0 and x or x - sz
                ic:SetSize(sz, sz)
                ic:ClearAllPoints()
                ic:SetPoint("TOPLEFT", self, "TOPLEFT", x0, -PAD)
                x = x + dir * (sz + IGAP)
                maxH = math.max(maxH, sz)
                ic:SetShown(open > 0.05); ic:SetAlpha(open)
            end
            local outer = x - dir * IGAP + dir * PAD
            panel:ClearAllPoints()
            panel:SetPoint("TOPLEFT", self, "TOPLEFT", math.min(edge, outer), 0)
            panel:SetSize(math.abs(outer - edge), maxH + PAD * 2)
            panel:SetAlpha(open)
        end
        side(L, self.lp, -1)
        side(R, self.rp, 1)
        for _, def in ipairs(SHORTCUTS) do
            local ic = self.icons[def.key]
            if not o.side[def.key] then ic:Hide() end
            ic.tex:SetTexture(def.icon())
            if def.tint then ic.tex:SetVertexColor(UI:Accent()) end
            ic.bg:SetColor(unpack(C.surface2))
            ic.edge:SetColor(unpack(C.border))
            local dc = def.dot and def.dot()
            ic.dot:SetShown(dc ~= nil)
            if dc then ic.dot:SetVertexColor(unpack(dc)) end
        end
        -- largeur du cadre : place pour tous les raccourcis (stable, pour le mode édition)
        local n = #L > #R and #L or #R
        self:SetWidth(math.max(120, n * (base + IGAP) * 2 + clockW + 2 * (GAP + PAD) + 20))
    end

    UI:RegisterHUD("clock", bar, { label = T("Micro menu"), protected = true, point = "TOP",
        default = { 0, UIParent:GetHeight() / 2 - 6 } })
    return bar
end

function UI:SyncClock()
    if inCombat() then return end
    if cfg().enabled then
        bar = bar or build()
        bar:Show()
        bar.open = 0
        bar:Layout()
    elseif bar then
        bar:Hide()
    end
end

WK:On("PLAYER_LOGIN", function() C_Timer.After(0.5, function() UI:SyncClock() end) end)
