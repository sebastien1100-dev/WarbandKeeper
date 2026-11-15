local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Horloge en haut de l'écran : au repos, l'heure et deux points (FPS, latence). Au survol, les
-- raccourcis glissent de chaque côté avec un effet loupe façon dock (réglable), et se replient
-- quand la souris s'en va. Hors combat seulement pour le dépliage (la pierre de foyer est un
-- bouton protégé que le jeu interdit de bouger en combat).
-- Réglages : WK.modules.QoL:Config().clock

local BASE = 28        -- taille d'une icône au repos (déplié)
local GAP = 6
local bar

-- Raccourcis disponibles. secure : bouton protégé (objet ou sort) ; sinon une fonction.
local SHORTCUTS = {
    { key = "wk", label = "Warband Keeper", icon = function() return UI.MEDIA .. "logo" end, tint = true,
      run = function() UI:ToggleWindow() end },
    { key = "mail", label = "Courrier", icon = function() return UI.MEDIA .. "mail" end, tint = true,
      run = function() UI:Create():Show(); UI:ShowPage("mail") end,
      dot = function()
          for _, c in pairs(WK.DB.global.characters) do
              if c.mailbox and (c.mailbox.count or 0) > 0 then return C.gold end
          end
      end },
    { key = "hearth", label = "Pierre de foyer", secure = { type = "item", item = "item:6948" },
      icon = function() return (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(6948)) or (GetItemIcon and GetItemIcon(6948)) or "Interface\\Icons\\INV_Misc_Rune_01" end,
      tip = function() return GetBindLocation and GetBindLocation() end },
    { key = "char", label = "Personnage", icon = function() return "Interface\\Icons\\INV_Chest_Chain_05" end,
      run = function() if ToggleCharacter then ToggleCharacter("PaperDollFrame") end end },
    { key = "spells", label = "Grimoire", icon = function() return "Interface\\Icons\\INV_Misc_Book_09" end,
      run = function() if ToggleSpellBook then ToggleSpellBook(BOOKTYPE_SPELL or "spell") end end },
    { key = "talents", label = "Talents", icon = function() return "Interface\\Icons\\Ability_Marksmanship" end,
      run = function() if ToggleTalentFrame then ToggleTalentFrame() end end },
    { key = "map", label = "Carte", icon = function() return "Interface\\Icons\\INV_Misc_Map_01" end,
      run = function() if ToggleWorldMap then ToggleWorldMap() end end },
    { key = "quests", label = "Journal de quêtes", icon = function() return "Interface\\Icons\\INV_Misc_Book_08" end,
      run = function() if ToggleQuestLog then ToggleQuestLog() end end },
    { key = "social", label = "Social et guilde", icon = function() return "Interface\\Icons\\INV_Misc_Note_02" end,
      run = function() if ToggleFriendsFrame then ToggleFriendsFrame() end end },
    { key = "prof", label = "Métier principal", icon = function()
          local me = WK.DB:Me()
          for _, p in pairs(me.professions or {}) do if p.icon then return p.icon end end
          return "Interface\\Icons\\Trade_BlackSmithing"
      end,
      run = function()
          local me = WK.DB:Me()
          for name in pairs(me.professions or {}) do
              local k = WK.modules.Gathering:Kind(name)
              if k ~= "herb" and k ~= "skin" then WK.modules.Professions:OpenDirect(name) return end
          end
      end },
    { key = "farm", label = "Session de farm", icon = function() return UI.MEDIA .. "play" end, tint = true,
      run = function() local F = WK.modules.Farm; if F:Active() then F:Stop() else F:Start() end end,
      dot = function() return WK.modules.Farm:Active() and C.positive or nil end },
    { key = "menu", label = "Menu du jeu", icon = function() return "Interface\\Icons\\INV_Misc_Gear_01" end,
      run = function() if ToggleGameMenu then ToggleGameMenu() end end },
}
UI.CLOCK_SHORTCUTS = SHORTCUTS

local DEFAULTS = {
    enabled = true, server = false, h12 = false, magnify = 0.8, stats = true,
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
    b.bg = UI:Rounded(b, 8, 0, "BACKGROUND", 1)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetPoint("TOPLEFT", 3, -3)
    b.tex:SetPoint("BOTTOMRIGHT", -3, 3)
    if not def.tint then b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    b.dot = UI:Icon(b, "circle", 7, nil, "OVERLAY")
    b.dot:SetPoint("TOP", b, "BOTTOM", 0, -2)
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
    bar.bg = CreateFrame("Frame", nil, bar)
    bar.bg:EnableMouse(true)
    bar.bg:SetPoint("TOP")
    bar.bg:SetSize(120, 34)
    UI:Panel(bar.bg, 12, { C.bg[1], C.bg[2], C.bg[3], 0.88 }, C.border)
    -- Heure (bouton : clic = calendrier si le jeu en a un, sinon Warband Keeper)
    bar.clockBtn = CreateFrame("Button", nil, bar)
    bar.clockBtn:SetSize(90, 30)
    bar.clockBtn:SetPoint("TOP", 0, -2)
    bar.clockBtn:SetFrameLevel(bar.bg:GetFrameLevel() + 3)
    bar.time = UI:Text(bar.clockBtn, 18)
    bar.time:SetPoint("CENTER", -8, 0)
    bar.fpsDot = UI:Icon(bar.clockBtn, "circle", 7)
    bar.msDot = UI:Icon(bar.clockBtn, "circle", 7)
    bar.fpsDot:SetPoint("LEFT", bar.time, "RIGHT", 6, 0)
    bar.msDot:SetPoint("LEFT", bar.fpsDot, "RIGHT", 3, 0)
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
            local _, _, fc, mc = stats()
            self.fpsDot:SetVertexColor(unpack(fc)); self.msDot:SetVertexColor(unpack(mc))
            self.fpsDot:SetShown(o.stats); self.msDot:SetShown(o.stats)
            self.time:SetTextColor(UI:Accent())
        end
        -- dépliage au survol (hors combat), repli 0,4 s après le départ de la souris
        local over = self.bg:IsMouseOver(4, -4, -4, 4)
        if over then self.leftAt = nil elseif not self.leftAt then self.leftAt = GetTime() end
        local want = (over or (self.leftAt and GetTime() - self.leftAt < 0.4)) and 1 or 0
        if inCombat() then want = self.open > 0.5 and 1 or 0 end
        local before = self.open
        if self.open < want then self.open = math.min(1, self.open + el * 6)
        elseif self.open > want then self.open = math.max(0, self.open - el * 6) end
        if self.open ~= before or self.open > 0 then self:Layout() end
    end

    -- Place les raccourcis : effet loupe selon la distance du curseur (hors combat).
    function bar:Layout()
        if inCombat() then return end
        local o = cfg()
        local L, R = self:Lists()
        local open = self.open
        local scale = self:GetEffectiveScale()
        local cx = (GetCursorPosition()) / scale
        local over = self.bg:IsMouseOver(4, -4, -4, 4)
        local function sizeOf(icon, x)
            if not over then return BASE end
            local d = math.abs(cx - x)
            local k = math.max(0, 1 - d / (BASE * 3))
            return BASE * (1 + (o.magnify or 0) * k * k)
        end
        local clockW = 96
        local left = self:GetLeft() or 0
        local mid = (self:GetWidth() or 120) / 2
        -- côté gauche : du centre vers l'extérieur
        local x = mid - clockW / 2 - GAP
        local maxH = BASE
        for _, ic in ipairs(L) do
            local sz = sizeOf(ic, left + x - BASE / 2)
            x = x - sz
            ic:SetSize(sz, sz)
            ic:ClearAllPoints()
            ic:SetPoint("TOPLEFT", self, "TOPLEFT", x, -3)
            x = x - GAP
            maxH = math.max(maxH, sz)
        end
        local leftEdge = x
        x = mid + clockW / 2 + GAP
        for _, ic in ipairs(R) do
            local sz = sizeOf(ic, left + x + BASE / 2)
            ic:SetSize(sz, sz)
            ic:ClearAllPoints()
            ic:SetPoint("TOPLEFT", self, "TOPLEFT", x, -3)
            x = x + sz + GAP
            maxH = math.max(maxH, sz)
        end
        local rightEdge = x
        -- fond : de la largeur de l'heure (replié) à celle des raccourcis (déplié)
        local fullW = math.max(rightEdge - leftEdge + 12, clockW)
        local w = clockW + (fullW - clockW) * open
        self.bg:SetSize(w, 34 + (maxH - BASE) * open)
        for _, ic in ipairs(L) do ic:SetShown(open > 0.05); ic:SetAlpha(open) end
        for _, ic in ipairs(R) do ic:SetShown(open > 0.05); ic:SetAlpha(open) end
        for _, def in ipairs(SHORTCUTS) do
            local ic = self.icons[def.key]
            if not o.side[def.key] then ic:Hide() end
            ic.tex:SetTexture(def.icon())
            if def.tint then ic.tex:SetVertexColor(UI:Accent()) end
            ic.bg:SetColor(unpack(C.surface2))
            local dc = def.dot and def.dot()
            ic.dot:SetShown(dc ~= nil)
            if dc then ic.dot:SetVertexColor(unpack(dc)) end
        end
        -- largeur du cadre : place pour tous les raccourcis (stable, pour le mode édition)
        self:SetWidth(math.max(120, (#L > #R and #L or #R) * (BASE + GAP) * 2 + clockW + 40))
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
