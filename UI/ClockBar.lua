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
---------------------------------------------------------------------------
-- Infobulles Amis (liste simple) et Guilde (par rang)
---------------------------------------------------------------------------
local classByName
local function classColor(token, localized)
    if not token and localized then
        if not classByName then
            classByName = {}
            for k, v in pairs(LOCALIZED_CLASS_NAMES_MALE or {}) do classByName[v] = k end
            for k, v in pairs(LOCALIZED_CLASS_NAMES_FEMALE or {}) do classByName[v] = k end
        end
        token = classByName[localized]
    end
    local c = token and RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
    if c then return string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255) end
    return "|cffd0d0d0"
end
-- point de faction (bleu Alliance, rouge Horde, gris inconnu) : texture en ligne
local function dot(faction)
    local r, g, b = 110, 110, 110
    if faction == "Alliance" then r, g, b = 63, 143, 240 elseif faction == "Horde" then r, g, b = 224, 80, 80 end
    return string.format("|T%scircle:8:8:0:0:64:64:0:64:0:64:%d:%d:%d|t", UI.MEDIA, r, g, b)
end
local function tag(afk, dnd)
    if dnd then return "  |cffe26060" .. T("occupé") .. "|r" end
    if afk then return "  |cfff5d76e" .. T("absent") .. "|r" end
    return ""
end
local function short(n)
    if Ambiguate then return Ambiguate(n, "short") end
    return (n:gsub("%-.*$", ""))
end
local MAX_LINES = 15
local function friendsTooltip(tt)
    local myFac = UnitFactionGroup and UnitFactionGroup("player")
    local lines, bn = {}, {}
    -- amis du jeu
    local n = 0
    if C_FriendList and C_FriendList.GetNumFriends then n = C_FriendList.GetNumFriends() or 0 elseif GetNumFriends then n = GetNumFriends() or 0 end
    for i = 1, n do
        local name, level, class, area, connected, afk, dnd
        if C_FriendList and C_FriendList.GetFriendInfoByIndex then
            local f = C_FriendList.GetFriendInfoByIndex(i)
            if f then name, level, class, area, connected, afk, dnd = f.name, f.level, f.className, f.area, f.connected, f.afk, f.dnd end
        elseif GetFriendInfo then
            local st
            name, level, class, area, connected, st = GetFriendInfo(i)
            afk, dnd = st == CHAT_FLAG_AFK, st == CHAT_FLAG_DND
        end
        if connected and name then
            table.insert(lines, { level = level, left = dot(myFac) .. " " .. classColor(nil, class) .. short(name) .. "|r" .. tag(afk, dnd), right = area or "" })
        end
    end
    -- Battle.net
    if BNGetNumFriends and C_BattleNet and C_BattleNet.GetFriendAccountInfo then
        local total = BNGetNumFriends() or 0
        for i = 1, total do
            local a = C_BattleNet.GetFriendAccountInfo(i)
            local g = a and a.gameAccountInfo
            if g and g.isOnline then
                local acct = a.accountName or ""
                if g.clientProgram == "WoW" and g.characterName then
                    table.insert(bn, { level = g.characterLevel, left = dot(g.factionName) .. " " .. classColor(nil, g.className) .. g.characterName .. "|r  |cff5cc8ff" .. acct .. "|r" .. tag(a.isAFK, a.isDND),
                                       right = g.areaName or g.richPresence or "" })
                else
                    table.insert(bn, { left = dot(nil) .. " |cffd0d0d0" .. acct .. "|r" .. tag(a.isAFK, a.isDND), right = T("Battle.net") })
                end
            end
        end
    end
    local total = #lines + #bn
    tt:SetText(T("Amis"), 1, 1, 1)
    tt:AddLine(string.format(total > 1 and T("%d en ligne") or T("%d en ligne"), total), 0.49, 0.85, 0.34)
    local shown = 0
    local function put(e)
        if shown >= MAX_LINES then return end
        shown = shown + 1
        tt:AddDoubleLine((e.level and e.level > 0 and ("|cffc9ccd2" .. e.level .. "|r  ") or "      ") .. e.left, e.right, 1, 1, 1, 0.55, 0.57, 0.6)
    end
    for _, e in ipairs(lines) do put(e) end
    if #bn > 0 and shown < MAX_LINES then
        tt:AddLine(" ")
        tt:AddLine("BATTLE.NET", 0.55, 0.57, 0.6)
        for _, e in ipairs(bn) do put(e) end
    end
    if total > shown then tt:AddLine(string.format(T("+ %d autre(s)"), total - shown), 0.55, 0.57, 0.6) end
    if total == 0 then tt:AddLine(T("Personne en ligne."), 0.55, 0.57, 0.6) end
    tt:AddLine(" ")
    tt:AddLine(T("Clic : liste d'amis"), 0.42, 0.44, 0.47)
end
local function guildTooltip(tt)
    if not (IsInGuild and IsInGuild() and GetNumGuildMembers and GetGuildRosterInfo) then
        tt:SetText(T("Guilde"), 1, 1, 1)
        tt:AddLine(T("Pas de guilde"), 0.55, 0.57, 0.6)
        return
    end
    local gname = GetGuildInfo and GetGuildInfo("player") or T("Guilde")
    local total, online = GetNumGuildMembers()
    tt:SetText(gname, 1, 1, 1)
    tt:AddLine(string.format(T("%d / %d en ligne"), online or 0, total or 0), 0.49, 0.85, 0.34)
    local ranks, order = {}, {}
    for i = 1, total or 0 do
        local name, rankName, rankIndex, level, class, zone, _, _, isOnline, status, classFile = GetGuildRosterInfo(i)
        if isOnline and name then
            local r = ranks[rankIndex or 99]
            if not r then r = { name = rankName or "", list = {} }; ranks[rankIndex or 99] = r; table.insert(order, rankIndex or 99) end
            local afk = status == 1 or status == "<AFK>" or status == CHAT_FLAG_AFK
            local dnd = status == 2 or status == "<DND>" or status == CHAT_FLAG_DND
            table.insert(r.list, { level = level, left = classColor(classFile, class) .. short(name) .. "|r" .. tag(afk, dnd), right = zone or "" })
        end
    end
    table.sort(order)
    local shown, MAXG = 0, 20
    for _, idx in ipairs(order) do
        local r = ranks[idx]
        if shown >= MAXG then break end
        tt:AddDoubleLine(UI:Upper(r.name), tostring(#r.list), 0.55, 0.57, 0.6, 0.55, 0.57, 0.6)
        table.sort(r.list, function(a, b) return (a.level or 0) > (b.level or 0) end)
        for _, e in ipairs(r.list) do
            if shown >= MAXG then break end
            shown = shown + 1
            tt:AddDoubleLine("|cffc9ccd2" .. (e.level or "") .. "|r  " .. e.left, e.right, 1, 1, 1, 0.55, 0.57, 0.6)
        end
    end
    if (online or 0) > shown then tt:AddLine(string.format(T("+ %d autre(s)"), online - shown), 0.55, 0.57, 0.6) end
    local motd = GetGuildRosterMOTD and GetGuildRosterMOTD()
    if motd and motd ~= "" then
        tt:AddLine(" ")
        tt:AddLine("« " .. motd .. " »", 0.62, 0.64, 0.68, true)
    end
    tt:AddLine(" ")
    tt:AddLine(T("Clic : fenêtre de guilde"), 0.42, 0.44, 0.47)
end

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
      tooltip = friendsTooltip },
    { key = "guild", label = "Guilde", micro = { "GuildMicroButton", "SocialsMicroButton" },
      icon = function() return UI.MEDIA .. "guild" end, tint = true,
      run = function() if ToggleGuildFrame then ToggleGuildFrame() elseif ToggleFriendsFrame then ToggleFriendsFrame(3) end end,
      count = function()
          if not (IsInGuild and IsInGuild() and GetNumGuildMembers) then return nil end
          local total, online = GetNumGuildMembers()
          online = tonumber(online)
          -- certains clients ne donnent pas le nombre en ligne : on compte dans la liste de guilde
          if (not online or online == 0) and GetGuildRosterInfo then
              online = 0
              for i = 1, tonumber(total) or 0 do
                  local _, _, _, _, _, _, _, _, isOnline = GetGuildRosterInfo(i)
                  if isOnline == true or isOnline == 1 then online = online + 1 end
              end
          end
          return online
      end,
      tooltip = guildTooltip },
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
    -- nombre en ligne (guilde, amis) : gélule menthe centrée sous l'icône, dans son propre cadre (au-dessus des voisins)
    b.badge = CreateFrame("Frame", nil, b)
    b.badge:SetFrameLevel(b:GetFrameLevel() + 6)
    b.badge:SetSize(18, 16)
    b.badge:SetPoint("CENTER", b, "BOTTOM", 0, 1)
    UI:Panel(b.badge, 8, { 0.66, 0.88, 0.71, 1 }) -- vert menthe pastel
    b.num = b.badge:CreateFontString(nil, "OVERLAY")
    b.num:SetFont(UI.FONT, 11, "")
    b.num:SetPoint("CENTER", 0, 0)
    b.num:SetTextColor(0.11, 0.23, 0.15)
    b.badge:Hide()
    b:SetScript("OnEnter", function(s)
        WK.UI:TooltipOwner(s, "ANCHOR_BOTTOM")
        if def.tooltip then
            local ok = pcall(def.tooltip, GameTooltip)
            if not ok then GameTooltip:SetText(T(def.label), 1, 1, 1) end
            GameTooltip:Show()
            return
        end
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
    -- FPS et latence : deux barres côte à côte sous le cadre de l'heure (remplies selon la valeur),
    -- valeurs au survol
    local function meter(kind)
        local m = CreateFrame("Frame", nil, bar.clockBtn)
        m:SetSize(24, 5)
        m.track = UI:Rounded(m, 2.5, 0, "ARTWORK", 0)
        m.fill = m:CreateTexture(nil, "ARTWORK", nil, 1)
        m.fill:SetPoint("TOPLEFT"); m.fill:SetPoint("BOTTOMLEFT")
        -- zone de survol un peu plus haute que la barre
        m.hit = CreateFrame("Frame", nil, m)
        m.hit:SetPoint("TOPLEFT", -2, 4); m.hit:SetPoint("BOTTOMRIGHT", 2, -4)
        m.hit:EnableMouse(true)
        m.hit:SetScript("OnEnter", function(s)
            WK.UI:TooltipOwner(s, "ANCHOR_BOTTOM")
            local fps, ms, fc, mc = stats()
            if kind == "fps" then
                GameTooltip:SetText(T("Images par seconde"), 1, 1, 1)
                GameTooltip:AddDoubleLine(T("FPS"), tostring(fps), 0.8, 0.8, 0.8, fc[1], fc[2], fc[3])
                GameTooltip:AddLine(T("Vert au-delà de 50, orange au-delà de 30."), 0.55, 0.57, 0.6, true)
            else
                GameTooltip:SetText(T("Latence"), 1, 1, 1)
                local home, world = ms, ms
                if GetNetStats then local _, _, h, w = GetNetStats(); home, world = h or ms, w or ms end
                GameTooltip:AddDoubleLine(T("Domicile"), home .. " ms", 0.8, 0.8, 0.8, 1, 1, 1)
                GameTooltip:AddDoubleLine(T("Monde"), world .. " ms", 0.8, 0.8, 0.8, mc[1], mc[2], mc[3])
                GameTooltip:AddLine(T("Vert sous 100 ms, orange sous 200 ms."), 0.55, 0.57, 0.6, true)
            end
            GameTooltip:Show()
        end)
        m.hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return m
    end
    bar.fpsBar = meter("fps")
    bar.msBar = meter("ms")
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
        local yoff = 0 -- les barres sont sous le cadre : l'heure reste centrée
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
        -- sous le cadre de l'heure, sur sa largeur (moins les arrondis), un petit écart au milieu
        local mw = math.floor((clockW - 16 - 6) / 2)
        for _, m in ipairs({ self.fpsBar, self.msBar }) do
            m:ClearAllPoints()
            m:SetWidth(mw)
            if m.frac then self:Meter(m, m.frac, m.col) end
        end
        self.fpsBar:SetPoint("TOPLEFT", self.bg, "BOTTOMLEFT", 8, -4)
        self.msBar:SetPoint("TOPRIGHT", self.bg, "BOTTOMRIGHT", -8, -4)
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
            ic.badge:SetShown(show)
            if show then
                ic.num:SetText(n > 99 and "99+" or tostring(n))
                ic.badge:SetWidth(math.max(18, math.ceil(ic.num:GetStringWidth() or 0) + 10))
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
