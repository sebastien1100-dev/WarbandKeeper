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
-- micro : boutons du micro menu du jeu qui ouvrent la même fenêtre. Le raccourci clique alors ce
-- bouton par un chemin protégé : ouvrir une fenêtre du jeu depuis le code d'un addon la « contamine »,
-- et le jeu bloque ensuite ses éléments protégés en combat (ADDON_ACTION_BLOCKED).
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
      icon = function() return UI.MEDIA .. "home" end, tint = true,
      tip = function() return GetBindLocation and GetBindLocation() end },
    { key = "char", label = "Personnage", micro = { "CharacterMicroButton" },
      icon = function() return UI.MEDIA .. "person" end, tint = true,
      run = function() if ToggleCharacter then ToggleCharacter("PaperDollFrame") end end },
    { key = "spells", label = "Grimoire", micro = { "SpellbookMicroButton", "PlayerSpellsMicroButton" },
      icon = function() return UI.MEDIA .. "book" end, tint = true,
      run = function() if ToggleSpellBook then ToggleSpellBook(BOOKTYPE_SPELL or "spell") end end },
    { key = "talents", label = "Talents", micro = { "TalentMicroButton", "PlayerSpellsMicroButton" },
      icon = function() return UI.MEDIA .. "tree" end, tint = true,
      run = function() if ToggleTalentFrame then ToggleTalentFrame() end end },
    { key = "map", label = "Carte", micro = { "WorldMapMicroButton", "MiniMapWorldMapButton" },
      icon = function() return UI.MEDIA .. "map" end, tint = true,
      run = function() if ToggleWorldMap then ToggleWorldMap() end end },
    { key = "quests", label = "Journal de quêtes", micro = { "QuestLogMicroButton" },
      icon = function() return UI.MEDIA .. "bang" end, tint = true,
      run = function() if ToggleQuestLog then ToggleQuestLog() end end },
    { key = "social", label = "Amis", micro = { "SocialsMicroButton", "FriendsMicroButton" },
      icon = function() return UI.MEDIA .. "users" end, tint = true,
      run = function() if ToggleFriendsFrame then ToggleFriendsFrame() end end,
      -- amis en ligne (jeu et Battle.net)
      count = function()
          local n = 0
          if C_FriendList and C_FriendList.GetNumOnlineFriends then n = n + (tonumber(C_FriendList.GetNumOnlineFriends()) or 0) end
          if BNGetNumFriends then local _, on = BNGetNumFriends(); n = n + (tonumber(on) or 0) end
          return n
      end,
      tip = function() return T("Amis en ligne (jeu et Battle.net)") end },
    { key = "guild", label = "Guilde", micro = { "GuildMicroButton", "SocialsMicroButton" },
      icon = function() return UI.MEDIA .. "guild" end, tint = true,
      run = function() if ToggleGuildFrame then ToggleGuildFrame() elseif ToggleFriendsFrame then ToggleFriendsFrame(3) end end,
      count = function()
          if not (IsInGuild and IsInGuild() and GetNumGuildMembers) then return nil end
          local _, online = GetNumGuildMembers()
          return tonumber(online)
      end,
      tip = function() return IsInGuild and IsInGuild() and T("Membres de la guilde en ligne") or T("Pas de guilde") end },
    { key = "collect", label = "Collections du compte", micro = { "CollectionsMicroButton" },
      icon = function() return UI.MEDIA .. "collect" end, tint = true,
      run = function() if ToggleCollectionsJournal then ToggleCollectionsJournal() end end },
    { key = "heirloom", label = "Héritages", icon = function() return UI.MEDIA .. "crown" end, tint = true,
      -- onglet des héritages du journal des collections (pas de bouton du jeu pour un onglet précis)
      -- le n° d'onglet change selon le client : on ouvre le journal puis on clique l'onglet « Héritages »
      run = function()
          if CollectionsJournal_LoadUI and not CollectionsJournal then pcall(CollectionsJournal_LoadUI) end
          if not (CollectionsJournal and CollectionsJournal:IsShown()) and ToggleCollectionsJournal then ToggleCollectionsJournal() end
          C_Timer.After(0, function()
              local want = (HEIRLOOMS or "Héritages"):lower()
              for i = 1, 10 do
                  local tab = _G["CollectionsJournalTab" .. i]
                  local txt = tab and tab.GetText and tab:GetText()
                  if type(txt) == "string" and txt:lower():find(want, 1, true) then
                      if tab.Click then tab:Click() end
                      return
                  end
              end
              -- pas trouvé par le nom : l'onglet dont le panneau est celui des héritages
              if HeirloomsJournal and CollectionsJournal_SetTab and CollectionsJournal and HeirloomsJournal.GetID then
                  pcall(CollectionsJournal_SetTab, CollectionsJournal, HeirloomsJournal:GetID())
              end
          end)
      end },
    { key = "prof", label = "Métier principal", icon = function() return UI.MEDIA .. "hammer" end, tint = true,
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
    { key = "lfg", label = "LFG", icon = function() return UI.MEDIA .. "lfg" end, tint = true,
      run = function() UI:ToggleWindow("lfg") end,
      dot = function()
          for _, q in pairs(WK.modules.LFG.requests) do if q.state == "answer" then return C.positive end end
      end },
    { key = "fishing", label = "Mode pêche", icon = function() return UI.MEDIA .. "fish" end, tint = true,
      run = function() WK.modules.Fishing:Toggle() end,
      dot = function() return WK.modules.Fishing.active and C.positive or nil end },
    { key = "menu", label = "Menu du jeu", micro = { "MainMenuMicroButton", "GameMenuMicroButton" },
      icon = function() return UI.MEDIA .. "gear" end, tint = true,
      -- vérifié après le clic : si le bouton du jeu n'a rien ouvert, on ouvre le menu directement
      shown = function() return GameMenuFrame and GameMenuFrame:IsShown() or false end,
      -- pas ToggleGameMenu : c'est la touche Échap du jeu, qui interrompt aussi le sort en cours,
      -- ce que le jeu interdit à un addon (ADDON_ACTION_FORBIDDEN SpellStopCasting)
      run = function()
          if not GameMenuFrame then return end
          if GameMenuFrame:IsShown() then (HideUIPanel or GameMenuFrame.Hide)(GameMenuFrame)
          else (ShowUIPanel or GameMenuFrame.Show)(GameMenuFrame) end
      end },
}
UI.CLOCK_SHORTCUTS = SHORTCUTS

local DEFAULTS = {
    enabled = true, server = false, h12 = false, magnify = 0.8, stats = true, size = 28,
    always = false, clockAlways = true, -- raccourcis toujours dépliés ; horloge toujours visible
    bold = false, timeSize = 0, timeFont = "ui", -- heure : gras, taille (0 = suit la taille des raccourcis), police
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
    -- le raccourci « Mode pêche » arrive à droite une fois, puis reste où tu le mets
    if not q.clock.lfgAdded then
        q.clock.lfgAdded = true
        if q.clock.side.lfg == nil then q.clock.side.lfg = "R" end
    end
    if not q.clock.fishAdded then
        q.clock.fishAdded = true
        if q.clock.side.fishing == nil then q.clock.side.fishing = "R" end
    end
    return q.clock
end
UI.ClockConfig = cfg

-- Polices proposées pour l'heure (polices du jeu, présentes sur tous les clients)
local TIME_FONTS = {
    { "ui", "Police de l'interface" },
    { "friz", "Friz Quadrata", "Fonts\\FRIZQT__.TTF" },
    { "arialn", "Arial Narrow", "Fonts\\ARIALN.TTF" },
    { "morpheus", "Morpheus", "Fonts\\MORPHEUS.TTF" },
    { "skurri", "Skurri", "Fonts\\SKURRI.TTF" },
}
UI.CLOCK_FONTS = TIME_FONTS
local function timeFont(key)
    for _, f in ipairs(TIME_FONTS) do if f[1] == key and f[3] then return f[3] end end
    return UI.FONT
end

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
-- Bouton du micro menu du jeu qui ouvre la même fenêtre que le raccourci (ou nil), et son nom.
function UI.ClockMicroButton(def)
    for _, name in ipairs(def.micro or {}) do
        local mb = _G[name]
        if type(mb) == "table" and mb.Click then return mb, name end
    end
    return nil
end

-- Diagnostic (/wk micro) : par quel chemin chaque raccourci ouvre sa fenêtre.
function UI:ClockReport()
    WK:Print(T("Micro menu : diagnostic"))
    for _, def in ipairs(SHORTCUTS) do
        if def.micro then
            local _, name = UI.ClockMicroButton(def)
            WK:Print("  " .. T(def.label) .. " : " .. (name and (T("bouton du jeu") .. " " .. name) or T("aucun bouton du jeu trouvé (ouverture directe)")))
        end
    end
    WK:Print("  ToggleGameMenu : " .. tostring(ToggleGameMenu ~= nil) .. " · GameMenuFrame : " .. tostring(GameMenuFrame ~= nil))
end

local function makeIcon(def)
    local b
    local target = UI.ClockMicroButton(def)
    if target then
        b = CreateFrame("Button", "WarbandKeeperClock_" .. def.key, bar, "SecureActionButtonTemplate")
        if b.RegisterForClicks then b:RegisterForClicks("AnyUp", "AnyDown") end
        b:SetAttribute("type", "click")
        b:SetAttribute("clickbutton", target)
        if def.shown then
            -- le clic part à l'appui et au relâchement : on ne vérifie qu'une fois par clic
            b:SetScript("PreClick", function(s)
                local now = GetTime()
                if s.checkAt and now - s.checkAt < 0.4 then return end
                s.checkAt = now
                local before = def.shown()
                C_Timer.After(0.25, function()
                    if def.shown() == before and not inCombat() then def.run() end
                end)
            end)
        end
    elseif def.secure then
        b = CreateFrame("Button", "WarbandKeeperClock_" .. def.key, bar, "SecureActionButtonTemplate")
        if b.RegisterForClicks then b:RegisterForClicks("AnyUp", "AnyDown") end
        b:SetAttribute("type", def.secure.type)
        b:SetAttribute(def.secure.type, def.secure.item)
    else
        b = CreateFrame("Button", nil, bar)
        b:SetScript("OnClick", function()
            -- fenêtre du jeu sans bouton protégé trouvé : jamais en combat, pour limiter la casse
            if def.micro and inCombat() then return end
            def.run()
        end)
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
    -- nombre en ligne (guilde, amis) : pastille en bas à droite
    b.numBg = UI:Icon(b, "circle", 15, nil, "OVERLAY")
    b.numBg:SetPoint("BOTTOMRIGHT", 3, -3)
    b.num = UI:Text(b, 9, nil, "OVERLAY")
    b.num:SetPoint("CENTER", b.numBg, "CENTER", 0, 0)
    b.numBg:Hide(); b.num:Hide()
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
    -- gras : le jeu n'a pas de police grasse, on double le texte décalé d'un pixel
    bar.timeBold = UI:Text(bar.clockBtn, 18)
    bar.timeBold:SetPoint("CENTER", bar.time, "CENTER", 1, 0)
    bar.timeBold:SetJustifyH("CENTER")
    bar.timeBold:Hide()
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
    -- (placées par Layout : sous l'heure, calées sur la largeur du texte)
    function bar:Meter(m, frac, col)
        m.frac, m.col = frac, col
        -- fond de barre bien visible : sinon la partie vide disparaît et l'ensemble paraît décentré
        m.track:SetColor(C.muted[1], C.muted[2], C.muted[3], 0.35)
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
        for _, def in ipairs(UI.ClockOrdered()) do
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
            local txt = clockText()
            self.time:SetText(txt)
            self.timeBold:SetText(txt)
            if txt ~= self.lastTxt then self.lastTxt = txt; self.relayout = true end
            local fps, ms, fc, mc = stats()
            self:Meter(self.fpsBar, fps / 60, fc)
            self:Meter(self.msBar, 1 - ms / 400, mc)
            self.fpsBar:SetShown(o.stats); self.msBar:SetShown(o.stats)
            self.time:SetTextColor(UI:Accent())
            self.timeBold:SetTextColor(UI:Accent())
            self.timeBold:SetShown(o.bold and true or false)
        end
        -- dépliage au survol (hors combat), repli 0,4 s après le départ de la souris
        local over = self:Over()
        if over then self.leftAt = nil elseif not self.leftAt then self.leftAt = GetTime() end
        local want = (o.always or over or (self.leftAt and GetTime() - self.leftAt < 0.4)) and 1 or 0
        -- horloge masquée au repos (option) : elle revient au survol de son emplacement
        local ca = (o.clockAlways ~= false or over or (not o.always and self.open > 0)) and 1 or 0
        self.clockA = self.clockA or 1
        if self.clockA ~= ca then
            self.clockA = self.clockA < ca and math.min(1, self.clockA + el * 6) or math.max(0, self.clockA - el * 6)
            self.bg:SetAlpha(self.clockA); self.clockBtn:SetAlpha(self.clockA)
        end
        if inCombat() then want = self.open > 0.5 and 1 or 0 end
        local before = self.open
        if self.open < want then self.open = math.min(1, self.open + el * 6)
        elseif self.open > want then self.open = math.max(0, self.open - el * 6) end
        if self.open ~= before or self.open > 0 or self.relayout then self.relayout = nil; self:Layout() end
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
        local fs = (o.timeSize or 0) > 0 and o.timeSize or math.floor(18 * k + 0.5)
        local font = timeFont(o.timeFont)
        local fkey = font .. fs
        if self.fontKey ~= fkey then
            self.fontKey = fkey
            for _, t in ipairs({ self.time, self.timeBold }) do
                t:SetFont(font, fs, "")
                if not t:GetFont() then t:SetFont(UI.FONT, fs, "") end -- police absente : celle de l'interface
            end
            self.time:SetText(clockText()); self.timeBold:SetText(clockText())
        end
        -- le fond de l'heure s'élargit et grandit avec le texte
        local tw = (self.time:GetStringWidth() or 0) + (o.bold and 1 or 0)
        local clockW = math.max(math.floor(96 * k + 0.5), math.floor(tw + 28))
        local h = math.max(base + PAD * 2, fs + 18)
        -- heure et barres forment un bloc centré dans le fond : le texte au milieu (le double du
        -- gras est réparti des deux côtés), les deux barres dessous, d'un bord du texte à l'autre
        local yoff = o.stats and 3 or 0
        -- centrage sur l'encre : avec des chiffres à largeur fixe, le « 1 » laisse un vide à sa
        -- gauche (et un peu à sa droite) ; on décale le texte et on cale les barres sur les chiffres
        if not self.probe then
            self.probe = self.clockBtn:CreateFontString(nil, "BACKGROUND")
            self.probe:Hide()
        end
        self.probe:SetFont(font, fs, "")
        self.probe:SetText("0")
        local cell = self.probe:GetStringWidth() or 0
        self.probe:SetText("1")
        local one = self.probe:GetStringWidth() or 0
        local txt = self.time:GetText() or ""
        local lead, trail = 0, 0
        if cell > 0 and one > cell * 0.8 then -- chiffres tabulaires
            lead = (txt:sub(1, 1) == "1") and cell * 0.39 or 0
            trail = (txt:sub(-1) == "1") and cell * 0.12 or 0
        end
        local shift = (lead - trail) / 2
        self.time:ClearAllPoints()
        self.time:SetPoint("CENTER", self.clockBtn, "CENTER", (o.bold and -0.5 or 0) - shift, yoff)
        local half = math.max(20, tw - lead - trail) / 2
        local by = yoff - fs * 0.42 - 2
        local mw = math.floor(half - 2)
        for _, m in ipairs({ self.fpsBar, self.msBar }) do
            m:ClearAllPoints()
            m:SetWidth(mw)
            if m.frac then self:Meter(m, m.frac, m.col) end
        end
        self.fpsBar:SetPoint("TOPLEFT", self.clockBtn, "CENTER", -half, by)
        self.msBar:SetPoint("TOPRIGHT", self.clockBtn, "CENTER", half, by)
        self.bg:SetSize(clockW, h)
        self:SetHeight(h)
        local left = self:GetLeft() or 0
        local mid = (self:GetWidth() or 120) / 2
        local top = PAD + math.floor((h - base - PAD * 2) / 2) -- icônes centrées sur la hauteur de l'heure
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
                ic:SetPoint("TOPLEFT", self, "TOPLEFT", x0, -top)
                x = x + dir * (sz + IGAP)
                maxH = math.max(maxH, sz)
                ic:SetShown(open > 0.05); ic:SetAlpha(open)
            end
            local outer = x - dir * IGAP + dir * PAD
            panel:ClearAllPoints()
            panel:SetPoint("TOPLEFT", self, "TOPLEFT", math.min(edge, outer), -(top - PAD))
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
        UI:ClockCounts()
        -- largeur du cadre : place pour tous les raccourcis (stable, pour le mode édition)
        local n = #L > #R and #L or #R
        self:SetWidth(math.max(120, n * (base + IGAP) * 2 + clockW + 2 * (GAP + PAD) + 20))
    end

    UI:RegisterHUD("clock", bar, { label = T("Micro menu"), protected = true, point = "TOP",
        default = { 0, UIParent:GetHeight() / 2 - 6 } })
    return bar
end

-- Nombres en ligne sur les icônes (texte seulement : possible en combat)
function UI:ClockCounts()
    if not bar then return end
    for _, def in ipairs(SHORTCUTS) do
        local ic = bar.icons[def.key]
        local n = def.count and def.count()
        local show = ic and n ~= nil and n > 0
        if ic then
            ic.num:SetShown(show); ic.numBg:SetShown(show)
            if show then
                ic.num:SetText(n > 99 and "99" or tostring(n))
                ic.numBg:SetVertexColor(UI:Accent())
                ic.num:SetTextColor(unpack(C.onAccent))
            end
        end
    end
end
local function countsSoon() if bar then C_Timer.After(0.2, function() UI:ClockCounts() end) end end
for _, ev in ipairs({ "GUILD_ROSTER_UPDATE", "FRIENDLIST_UPDATE", "BN_FRIEND_ACCOUNT_ONLINE", "BN_FRIEND_ACCOUNT_OFFLINE", "PLAYER_GUILD_UPDATE" }) do
    WK:On(ev, countsSoon)
end
-- la liste de la guilde n'arrive que sur demande : une fois par minute
local function askRoster()
    if bar and IsInGuild and IsInGuild() then
        if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) elseif GuildRoster then pcall(GuildRoster) end
    end
end
if C_Timer.NewTicker then C_Timer.NewTicker(60, askRoster) end
WK:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(5, function() askRoster(); UI:ClockCounts() end) end)

---------------------------------------------------------------------------
-- Ordre et côté des raccourcis (réglages : barre en direct de QoL > Micro menu)
---------------------------------------------------------------------------
-- Raccourcis dans l'ordre choisi (cfg().order), les autres ensuite dans l'ordre d'origine.
-- À gauche, le premier est le plus près de l'heure.
function UI.ClockOrdered()
    local o, out, seen = cfg(), {}, {}
    local byKey = {}
    for _, def in ipairs(SHORTCUTS) do byKey[def.key] = def end
    for _, k in ipairs(o.order or {}) do
        if byKey[k] and not seen[k] then seen[k] = true; table.insert(out, byKey[k]) end
    end
    for _, def in ipairs(SHORTCUTS) do if not seen[def.key] then table.insert(out, def) end end
    return out
end
-- Ordre à l'écran d'un côté : { clés de gauche à droite }
function UI.ClockVisual(side)
    local o, out = cfg(), {}
    for _, def in ipairs(UI.ClockOrdered()) do
        if o.side[def.key] == side then
            if side == "L" then table.insert(out, 1, def.key) else table.insert(out, def.key) end
        end
    end
    return out
end
local function saveVisual(VL, VR)
    local o = cfg()
    local order = {}
    for i = #VL, 1, -1 do table.insert(order, VL[i]) end
    for _, k in ipairs(VR) do table.insert(order, k) end
    for _, def in ipairs(SHORTCUTS) do
        local found = false
        for _, k in ipairs(order) do if k == def.key then found = true break end end
        if not found then table.insert(order, def.key) end
    end
    o.order = order
    UI:SyncClock()
end
-- Glisser-déposer (réglages) : nouvelle disposition { gauche de g. à d. }, { droite }, côté de chacun
function UI:ClockSetLayout(VL, VR)
    local o = cfg()
    for _, def in ipairs(SHORTCUTS) do o.side[def.key] = nil end
    for _, k in ipairs(VL) do o.side[k] = "L" end
    for _, k in ipairs(VR) do o.side[k] = "R" end
    saveVisual(VL, VR)
end
-- Clic : gauche > droite > masqué > gauche (au bout le plus éloigné de l'heure)
function UI:ClockCycle(key)
    local o = cfg()
    local VL, VR = UI.ClockVisual("L"), UI.ClockVisual("R")
    local function drop(t) for i = #t, 1, -1 do if t[i] == key then table.remove(t, i) end end end
    drop(VL); drop(VR)
    local cur = o.side[key]
    if cur == "L" then o.side[key] = "R"; table.insert(VR, key)
    elseif cur == "R" then o.side[key] = nil
    else o.side[key] = "L"; table.insert(VL, 1, key) end
    saveVisual(VL, VR)
end
function UI:ClockHide(key)
    cfg().side[key] = nil
    UI:SyncClock()
end
-- Décale d'un cran à l'écran (dir -1 : vers la gauche, 1 : vers la droite), sans changer de côté
function UI:ClockMove(key, dir)
    local o = cfg()
    local side = o.side[key]
    if not side then return end
    local VL, VR = UI.ClockVisual("L"), UI.ClockVisual("R")
    local t = side == "L" and VL or VR
    for i, k in ipairs(t) do
        if k == key then
            local j = i + dir
            if j >= 1 and j <= #t then t[i], t[j] = t[j], t[i] end
            break
        end
    end
    saveVisual(VL, VR)
end

function UI:SyncClock()
    if UI.SyncFishingMinimap then UI:SyncFishingMinimap() end -- le bouton de minicarte de la pêche en dépend
    if inCombat() then return end
    if cfg().enabled and WK:FeatureOn("micro") then
        bar = bar or build()
        bar:Show()
        bar.open = 0
        bar:Layout()
    elseif bar then
        bar:Hide()
    end
end

WK:On("PLAYER_LOGIN", function() C_Timer.After(0.5, function() UI:SyncClock() end) end)
