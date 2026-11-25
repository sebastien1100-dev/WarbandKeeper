local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Horloge en haut de l'écran : au repos, l'heure et deux petites barres dessous (FPS, latence).
-- Au survol, les raccourcis apparaissent de chaque côté de l'heure (chaque icône a sa tuile, infobulle
-- au survol), sans animation ni effet loupe : rien n'est redessiné tant que rien ne change. Repli quand
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
    -- avant, couleurs de ce fichier en dur (gris, rouge, jaune, bleu, vert) : celles du thème maintenant
    return UI:Hex(C.muted)
end
-- point de faction (bleu Alliance, rouge Horde, gris inconnu) : texture en ligne
local function dot(faction)
    local r, g, b = 110, 110, 110
    if faction == "Alliance" then r, g, b = 63, 143, 240 elseif faction == "Horde" then r, g, b = 224, 80, 80 end
    return string.format("|T%scircle:8:8:0:0:64:64:0:64:0:64:%d:%d:%d|t", UI.MEDIA, r, g, b)
end
local function tag(afk, dnd)
    if dnd then return "  " .. UI:Hex(C.negative) .. T("occupé") .. "|r" end
    if afk then return "  " .. UI:Hex(C.warning) .. T("absent") .. "|r" end
    return ""
end
-- avant, les noms en cyrillique des infobulles Amis / Guilde s'affichaient en carrés : transcrits par WK.Latin
local function short(n)
    if Ambiguate then n = Ambiguate(n, "short") else n = (n:gsub("%-.*$", "")) end
    return WK.Latin and WK.Latin(n) or n
end
local function latin(n) return WK.Latin and WK.Latin(n) or n end
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
                    -- en jeu sur WoW : en haut, avec les amis du jeu
                    table.insert(lines, { level = g.characterLevel, left = dot(g.factionName) .. " " .. classColor(nil, g.className) .. latin(g.characterName) .. "|r  " .. UI:Hex(C.info) .. latin(acct) .. "|r" .. tag(a.isAFK, a.isDND),
                                       right = g.areaName or g.richPresence or "" })
                else
                    table.insert(bn, { left = dot(nil) .. " " .. UI:Hex(C.muted) .. latin(acct) .. "|r" .. tag(a.isAFK, a.isDND), right = T("Battle.net") })
                end
            end
        end
    end
    local total = #lines + #bn
    tt:SetText(T("Amis"), 1, 1, 1)
    tt:AddLine(string.format(total > 1 and T("%d en ligne") or T("%d en ligne"), total), UI.RGB(C.positive))
    local shown = 0
    local function put(e)
        if shown >= MAX_LINES then return end
        shown = shown + 1
        tt:AddDoubleLine((e.level and e.level > 0 and (UI:Hex(C.muted) .. e.level .. "|r  ") or "      ") .. e.left, e.right, 1, 1, 1, UI.RGB(C.muted))
    end
    for _, e in ipairs(lines) do put(e) end
    if #bn > 0 and shown < MAX_LINES then
        tt:AddLine(" ")
        tt:AddLine(T("BATTLE.NET · HORS DE WOW"), UI.RGB(C.muted))
        for _, e in ipairs(bn) do put(e) end
    end
    if total > shown then tt:AddLine(string.format(T("+ %d autre(s)"), total - shown), UI.RGB(C.muted)) end
    if total == 0 then tt:AddLine(T("Personne en ligne."), UI.RGB(C.muted)) end
    tt:AddLine(" ")
    tt:AddLine(T("Clic : liste d'amis"), UI.RGB(C.dim))
end
local function guildTooltip(tt)
    if not (IsInGuild and IsInGuild() and GetNumGuildMembers and GetGuildRosterInfo) then
        tt:SetText(T("Guilde"), 1, 1, 1)
        tt:AddLine(T("Pas de guilde"), UI.RGB(C.muted))
        return
    end
    local gname = GetGuildInfo and GetGuildInfo("player") or T("Guilde")
    local total, online = GetNumGuildMembers()
    tt:SetText(gname, 1, 1, 1)
    tt:AddLine(string.format(T("%d / %d en ligne"), online or 0, total or 0), UI.RGB(C.positive))
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
        tt:AddDoubleLine(UI:Upper(r.name), tostring(#r.list), C.muted[1], C.muted[2], C.muted[3], UI.RGB(C.muted))
        table.sort(r.list, function(a, b) return (a.level or 0) > (b.level or 0) end)
        for _, e in ipairs(r.list) do
            if shown >= MAXG then break end
            shown = shown + 1
            tt:AddDoubleLine(UI:Hex(C.muted) .. (e.level or "") .. "|r  " .. e.left, e.right, 1, 1, 1, UI.RGB(C.muted))
        end
    end
    if (online or 0) > shown then tt:AddLine(string.format(T("+ %d autre(s)"), online - shown), UI.RGB(C.muted)) end
    local motd = GetGuildRosterMOTD and GetGuildRosterMOTD()
    if motd and motd ~= "" then
        tt:AddLine(" ")
        tt:AddLine("« " .. motd .. " »", C.muted[1], C.muted[2], C.muted[3], true)
    end
    tt:AddLine(" ")
    tt:AddLine(T("Clic : fenêtre de guilde"), UI.RGB(C.dim))
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
      run = function()
          -- le journal des collections est protégé en combat (ouverture et changement d'onglet refusés)
          if _G.InCombatLockdown and _G.InCombatLockdown() then WK:Print(WK.T("Après le combat.")) return end
          if CollectionsJournal_LoadUI and not CollectionsJournal then pcall(CollectionsJournal_LoadUI) end
          -- (pas de COLLECTIONS_JOURNAL_TAB_INDEX_HEIRLOOMS : sur WoW Forever ce n° n'est pas un onglet et la
          -- fenêtre du jeu plantait ; l'ancienne recherche par le nom ratait « Objets en héritage » et ouvrait les
          -- Apparences). Journal ouvert, puis l'onglet reconnu par son texte, dans sa barre d'onglets.
          if not (CollectionsJournal and CollectionsJournal:IsShown()) and ToggleCollectionsJournal then ToggleCollectionsJournal() end
          C_Timer.After(0, function()
              local cj = CollectionsJournal
              if not cj then return end
              local function isHeirloom(txt)
                  if type(txt) ~= "string" then return false end
                  local l = txt:lower()
                  local h = _G.HEIRLOOMS and _G.HEIRLOOMS:lower()
                  return (h and l == h) or l:find("ritage", 1, true) or l:find("heirloom", 1, true)
              end
              local function textOf(b)
                  local t = b.GetText and b:GetText()
                  if not t and b.Text and b.Text.GetText then t = b.Text:GetText() end
                  if not t and b.GetRegions then
                      for _, r in ipairs({ b:GetRegions() }) do
                          if r.GetText and r:GetText() then t = r:GetText() break end
                      end
                  end
                  return t
              end
              local tabs = {}
              for i = 1, 10 do local t = _G["CollectionsJournalTab" .. i]; if t then tabs[#tabs + 1] = t end end
              if type(cj.TabContainer) == "table" and cj.TabContainer.GetChildren then
                  for _, t in ipairs({ cj.TabContainer:GetChildren() }) do tabs[#tabs + 1] = t end
              end
              -- page des héritages affichée ? (HeirloomsJournal, ou un cadre enfant du journal nommé « Heirloom »)
              local function onHeirlooms()
                  local hj = _G.HeirloomsJournal
                  if hj and hj.IsVisible and hj:IsVisible() then return true end
                  for _, c in ipairs({ cj:GetChildren() }) do
                      local n = c.GetName and c:GetName()
                      if n and n:find("Heirloom", 1, true) and c:IsVisible() then return true end
                  end
                  return false
              end
              local function pick(t)
                  if t.Click then pcall(t.Click, t) end
                  local sel = _G.PanelTemplates_GetSelectedTab and _G.PanelTemplates_GetSelectedTab(cj)
                  if t.GetID and sel ~= t:GetID() and _G.CollectionsJournal_SetTab then
                      pcall(_G.CollectionsJournal_SetTab, cj, t:GetID())
                  end
              end
              -- 1) l'onglet reconnu par son texte : on le clique et on s'arrête là (avant, si la page n'était pas
              -- reconnue juste après le clic, on cliquait tous les onglets l'un après l'autre et on finissait sur le
              -- dernier, avec le message « introuvable »)
              for _, t in ipairs(tabs) do
                  if t.IsShown and t:IsShown() and isHeirloom(textOf(t)) then pick(t) return end
              end
              -- 2) sinon chaque onglet, jusqu'à la page des héritages
              local names = {}
              for _, t in ipairs(tabs) do
                  if t.IsShown and t:IsShown() then
                      names[#names + 1] = tostring(textOf(t))
                      pick(t)
                      if onHeirlooms() then return end
                  end
              end
              if tabs[1] then pick(tabs[1]) end
              WK:Print(WK.T("Onglet des héritages introuvable dans le journal des collections.")
                  .. " (" .. table.concat(names, ", ") .. ")")
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
    { key = "boats", label = "Destinations", icon = function() return UI.MEDIA .. "compass" end, tint = true,
      tip = function() return T("bateaux, zeppelins et vols") end,
      run = function() if UI.ToggleBoatBoard then UI:ToggleBoatBoard() end end,
      -- pastille verte : un quai d'une ligne de ta faction est près de toi
      dot = function()
          local B, G = WK.modules.BoatLines, WK.modules.Guide
          local p = G and G:PlayerPos()
          if not (B and p and p.cont) then return nil end
          local l = B:StopNear(p.cont, p.wx, p.wy, 200)
          return l and B:Mine(l) and C.positive or nil
      end },
    -- /reload : bouton protégé qui lance la commande (ReloadUI() est bloqué pour les addons sur ce client)
    { key = "reload", label = "Recharger l'interface", icon = function() return UI.MEDIA .. "refresh" end, tint = true,
      secure = { type = "macro", macrotext = "/reload" } },
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
    enabled = true, server = false, h12 = false, size = 28,
    always = false, clockAlways = true, -- raccourcis toujours dépliés ; horloge toujours visible
    bold = false, timeSize = 0, timeFont = "ui", -- heure : gras, taille (0 = suit la taille des raccourcis), police
    -- survol de l'heure : addons et mémoire (style barres / simple, nombre, tri, FPS, hausse, seuil en Mo, clic droit)
    perf = true, perfStyle = "bars", perfCount = 8, perfSort = "mem", perfFps = true, perfDelta = true, perfWarn = 50, perfGC = false,
    side = { wk = "L", mail = "L", hearth = "L", char = "R", spells = "R", talents = "R", map = "R" },
}
local cfgReady
local function cfg()
    local q = WK.modules.QoL:Config()
    if q.clock and q.clock == cfgReady and q.clock.side then return q.clock end
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
    if not q.clock.boatsAdded then
        q.clock.boatsAdded = true
        if q.clock.side.boats == nil then q.clock.side.boats = "R" end
    end
    -- changement de couche retiré (1.128.181) : raccourci « layer » ôté une fois de l'ordre et des côtés
    if not q.clock.layerGone then
        q.clock.layerGone = true
        q.clock.side.layer = nil
        local order = {}
        for _, k in ipairs(q.clock.order or {}) do if k ~= "layer" then order[#order + 1] = k end end
        if q.clock.order then q.clock.order = order end
        WK.DB.global.layer = nil
    end
    if not q.clock.reloadAdded then
        q.clock.reloadAdded = true
        if q.clock.side.reload == nil then q.clock.side.reload = "R" end
    end
    if not q.clock.fishAdded then
        q.clock.fishAdded = true
        if q.clock.side.fishing == nil then q.clock.side.fishing = "R" end
    end
    cfgReady = q.clock
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
-- Survol de l'heure : addons et mémoire. Mémoire relue à chaque survol seulement (UpdateAddOnMemoryUsage
-- coûte quelques millisecondes) ; processeur seulement si le profilage du jeu est actif (scriptProfile).
---------------------------------------------------------------------------
-- fonctions des addons (C_AddOns sur les clients récents), cherchées à l'appel
local function numAddOns() local f = (C_AddOns and C_AddOns.GetNumAddOns) or GetNumAddOns; return f and f() or 0 end
local function addOnInfo(i) local f = (C_AddOns and C_AddOns.GetAddOnInfo) or GetAddOnInfo; if f then return f(i) end end
local function addOnLoaded(i) local f = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded; return f and f(i) end
local memBase -- mémoire totale des addons un peu après la connexion (hausse depuis la connexion)
local function profiling() return WK.GetCVarBool("scriptProfile") and GetAddOnCPUUsage ~= nil end
local function perfData()
    local out = { list = {}, total = 0, loaded = 0, count = 0 }
    out.fps = GetFramerate and math.floor(GetFramerate() + 0.5) or 0
    if GetNetStats then local _, _, h, w = GetNetStats(); out.home, out.world = h or 0, w or 0 end
    if UpdateAddOnMemoryUsage then pcall(UpdateAddOnMemoryUsage) end
    local cpu = profiling()
    if cpu and UpdateAddOnCPUUsage then pcall(UpdateAddOnCPUUsage) end
    out.cpu = cpu
    local n = numAddOns()
    out.count = n
    for i = 1, n do
        local ok, loaded = pcall(addOnLoaded, i)
        if ok and loaded then
            out.loaded = out.loaded + 1
            local name, title = addOnInfo(i)
            local kb = GetAddOnMemoryUsage and GetAddOnMemoryUsage(i) or 0
            title = type(title) == "string" and title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") or name
            local e = { name = (title and title ~= "") and title or name or "?", kb = kb }
            if cpu then local okc, c = pcall(GetAddOnCPUUsage, i); e.cpu = okc and c or 0 end
            out.total = out.total + kb
            table.insert(out.list, e)
        end
    end
    return out
end
local function memText(kb)
    if kb >= 1024 then return (string.format("%.1f Mo", kb / 1024):gsub("%.", ",")) end
    return string.format("%d Ko", math.floor(kb + 0.5))
end
WK:On("PLAYER_LOGIN", function()
    C_Timer.After(10, function()
        if UpdateAddOnMemoryUsage then pcall(UpdateAddOnMemoryUsage) end
        local t = 0
        for i = 1, numAddOns() do t = t + (GetAddOnMemoryUsage and GetAddOnMemoryUsage(i) or 0) end
        memBase = t
    end)
end)

local perfTip
local function buildPerfTip()
    local f = CreateFrame("Frame", "WarbandKeeperPerfTip", UIParent)
    f:SetFrameStrata("TOOLTIP")
    f:SetSize(360, 200)
    UI:Panel(f, 10, { C.bg[1], C.bg[2], C.bg[3], 0.97 }, C.border)
    f.title = UI:Text(f, 13, C.text); f.title:SetPoint("TOPLEFT", 14, -12)
    f.when = UI:Text(f, 10, C.dim); f.when:SetPoint("TOPRIGHT", -14, -14)
    f.tiles = {}
    for i = 1, 3 do
        local t = CreateFrame("Frame", nil, f)
        t:SetHeight(40)
        t.bg = UI:Rounded(t, 7, 0, "BACKGROUND", 2); t.bg:SetColor(unpack(C.surface2))
        t.l = UI:Text(t, 9, C.dim); t.l:SetPoint("TOPLEFT", 8, -6)
        t.v = UI:Text(t, 14, C.text); t.v:SetPoint("TOPLEFT", t.l, "BOTTOMLEFT", 0, -2)
        f.tiles[i] = t
    end
    f.rows = {}
    function f:Row(i)
        local r = self.rows[i]
        if r then return r end
        r = CreateFrame("Frame", nil, self)
        r:SetHeight(18)
        r.name = UI:Text(r, 11, C.text); r.name:SetPoint("LEFT"); r.name:SetWidth(120); r.name:SetJustifyH("LEFT")
        if r.name.SetWordWrap then r.name:SetWordWrap(false) end
        r.val = UI:Text(r, 11, C.text); r.val:SetPoint("RIGHT"); r.val:SetJustifyH("RIGHT")
        r.track = r:CreateTexture(nil, "ARTWORK"); r.track:SetHeight(5)
        r.track:SetPoint("LEFT", 128, 0); r.track:SetPoint("RIGHT", -70, 0)
        r.track:SetColorTexture(C.surface2[1], C.surface2[2], C.surface2[3], 1)
        r.fill = r:CreateTexture(nil, "OVERLAY"); r.fill:SetHeight(5); r.fill:SetPoint("LEFT", r.track, "LEFT")
        self.rows[i] = r
        return r
    end
    f.foot = UI:Text(f, 11, C.muted); f.foot:SetJustifyH("LEFT")
    f.hint = UI:Text(f, 10, C.dim); f.hint:SetJustifyH("LEFT")
    f:Hide()
    return f
end

-- remplit l'infobulle du jeu (style simple) ou notre panneau (style barres) ; anchor = le bouton de l'heure
local function showPerf(anchor, showDate)
    local o = cfg()
    local d = perfData()
    local key = o.perfSort == "cpu" and d.cpu and "cpu" or (o.perfSort == "name" and "name" or "kb")
    table.sort(d.list, function(a, b)
        if key == "name" then return a.name:lower() < b.name:lower() end
        return (a[key] or 0) > (b[key] or 0)
    end)
    local count = o.perfCount == 0 and #d.list or math.min(#d.list, o.perfCount or 8)
    local warnKb = (o.perfWarn or 50) * 1024
    local function val(e) return key == "cpu" and string.format("%d ms", math.floor((e.cpu or 0) + 0.5)) or memText(e.kb) end
    if o.perfStyle ~= "bars" then
        showDate()
        if o.perfFps then
            GameTooltip:AddDoubleLine(T("FPS · latence"), string.format("%d · %d / %d ms", d.fps, d.home or 0, d.world or 0), 0.8, 0.8, 0.8, 1, 1, 1)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(T("Addons"), memText(d.total), 1, 1, 1, 1, 1, 1)
        local rest, restKb = 0, 0
        for i, e in ipairs(d.list) do
            if i <= count then
                local w = e.kb >= warnKb
                GameTooltip:AddDoubleLine(e.name, val(e), 0.85, 0.85, 0.85, w and C.warning[1] or 1, w and C.warning[2] or 1, w and C.warning[3] or 1)
            else rest, restKb = rest + 1, restKb + e.kb end
        end
        if rest > 0 then GameTooltip:AddDoubleLine(string.format(T(rest > 1 and "… %d autres" or "… %d autre"), rest), memText(restKb), 0.5, 0.5, 0.5, 0.5, 0.5, 0.5) end
        if o.perfDelta and memBase then
            local dv = d.total - memBase
            GameTooltip:AddLine(string.format(T("Depuis la connexion : %s%s"), dv >= 0 and "+" or "-", memText(math.abs(dv))), 0.6, 0.6, 0.6)
        end
        if o.perfGC then GameTooltip:AddLine(T("Clic droit : libérer la mémoire"), 0.5, 0.5, 0.5) end
        GameTooltip:Show()
        return
    end
    perfTip = perfTip or buildPerfTip()
    local f = perfTip
    local r1, g1, b1 = UI:Accent()
    if f.border then f.border:SetColor(r1, g1, b1, 0.5) end
    local dt = date("*t")
    f.title:SetText(T("Performances"))
    f.when:SetText(string.format("%02d:%02d", dt.hour, dt.min) .. (GetGameTime and string.format("  ·  " .. T("serveur %02d:%02d"), GetGameTime()) or ""))
    local y = -36
    local W = 360
    if o.perfFps then
        local tw = (W - 28 - 12) / 3
        local lat = math.max(d.home or 0, d.world or 0)
        local vals = { { T("FPS"), tostring(d.fps), d.fps >= 50 and C.positive or (d.fps >= 30 and C.warning or C.negative) },
            { T("LATENCE"), lat .. " ms", lat < 100 and C.positive or (lat < 200 and C.warning or C.negative) },
            { T("MÉMOIRE"), memText(d.total), C.text } }
        for i, t in ipairs(f.tiles) do
            t:ClearAllPoints(); t:SetPoint("TOPLEFT", 14 + (i - 1) * (tw + 6), y); t:SetWidth(tw)
            t.l:SetText(vals[i][1]); t.v:SetText(vals[i][2]); t.v:SetTextColor(unpack(vals[i][3])); t:Show()
        end
        y = y - 48
    else
        for _, t in ipairs(f.tiles) do t:Hide() end
    end
    local maxv = 0
    for i = 1, count do local e = d.list[i]; maxv = math.max(maxv, key == "cpu" and (e.cpu or 0) or e.kb) end
    for i, r in ipairs(f.rows) do if i > count + 1 then r:Hide() end end
    local restN, restKb = 0, 0
    for i = count + 1, #d.list do restN, restKb = restN + 1, restKb + d.list[i].kb end
    for i = 1, count + (restN > 0 and 1 or 0) do
        local r = f:Row(i)
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", 14, y); r:SetPoint("TOPRIGHT", -14, y)
        if i <= count then
            local e = d.list[i]
            local v = key == "cpu" and (e.cpu or 0) or e.kb
            local w = e.kb >= warnKb
            r.name:SetText(e.name); r.name:SetTextColor(unpack(C.text))
            r.val:SetText(val(e)); r.val:SetTextColor(unpack(w and C.warning or C.text))
            local tw = math.max(1, (r.track:GetWidth() or (W - 28 - 198)))
            r.fill:SetWidth(math.max(1, tw * (maxv > 0 and v / maxv or 0)))
            if w then r.fill:SetColorTexture(C.warning[1], C.warning[2], C.warning[3], 1) else r.fill:SetColorTexture(r1, g1, b1, 1) end
            r.track:Show(); r.fill:Show()
        else
            r.name:SetText(string.format(T(restN > 1 and "… %d autres" or "… %d autre"), restN)); r.name:SetTextColor(unpack(C.dim))
            r.val:SetText(memText(restKb)); r.val:SetTextColor(unpack(C.dim))
            r.track:Hide(); r.fill:Hide()
        end
        r:Show()
        y = y - 20
    end
    y = y - 6
    local foot = {}
    if o.perfDelta and memBase then
        local dv = d.total - memBase
        table.insert(foot, string.format(T("Depuis la connexion : %s"), UI:Hex(dv > 0 and C.warning or C.positive) .. (dv >= 0 and "+" or "-") .. memText(math.abs(dv)) .. "|r"))
    end
    table.insert(foot, string.format(T("%d addons chargés sur %d"), d.loaded, d.count))
    f.foot:ClearAllPoints(); f.foot:SetPoint("TOPLEFT", 14, y); f.foot:SetText(table.concat(foot, "  ·  "))
    y = y - 16
    local hints = { T("Clic : calendrier") }
    if o.perfGC then table.insert(hints, T("clic droit : libérer la mémoire")) end
    if o.perfSort == "cpu" and not d.cpu then table.insert(hints, T("processeur : profilage du jeu coupé")) end
    f.hint:ClearAllPoints(); f.hint:SetPoint("TOPLEFT", 14, y); f.hint:SetText(table.concat(hints, "  ·  "))
    y = y - 22
    f:SetSize(W, -y)
    f:ClearAllPoints()
    local _, cy = anchor:GetCenter()
    if cy and cy > (UIParent:GetHeight() or 800) / 2 then f:SetPoint("TOP", anchor, "BOTTOM", 0, -6)
    else f:SetPoint("BOTTOM", anchor, "TOP", 0, 6) end
    f:Show()
end
function UI:HidePerfTip() if perfTip then perfTip:Hide() end end
function UI:PerfTip() return perfTip end

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
        -- clic de souris : au relâchement, quel que soit le réglage « touche enfoncée » du jeu (comme
        -- UI:SecureReload : avec ce réglage, un clic sur le bouton protégé ne partait pas)
        b:SetAttribute("useOnKeyDown", false)
        -- attributs du bouton protégé : type + item (pierre de foyer) ou macrotext (/reload)
        for k, v in pairs(def.secure) do b:SetAttribute(k, v) end
    else
        b = CreateFrame("Button", nil, bar)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetScript("OnClick", function(_, button)
            -- fenêtre du jeu sans bouton protégé trouvé : jamais en combat, pour limiter la casse
            if def.micro and inCombat() then return end
            def.run(button)
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
    UI:Panel(b.badge, 8, C.mint) -- vert menthe pastel du thème
    b.num = b.badge:CreateFontString(nil, "OVERLAY")
    b.num:SetFont(UI.FONT, 11, "")
    b.num:SetPoint("CENTER", 0, 0)
    b.num:SetTextColor(C.mint[1] * 0.2, C.mint[2] * 0.25, C.mint[3] * 0.2) -- menthe très sombre, lisible sur la gélule
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
    bar.clockBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    bar.clockBtn:SetScript("OnClick", function(_, button)
        -- clic droit (réglage) : libérer la mémoire inutilisée des addons, hors combat
        if button == "RightButton" then
            -- jamais muet : on dit pourquoi rien ne se passe (réglage coupé, combat)
            if not cfg().perfGC then
                WK:Print(T("Clic droit sur l'heure : coche « Clic droit sur l'heure : libérer la mémoire » dans Interface > Micro menu (carte Survol de l'heure)."))
            elseif InCombatLockdown and InCombatLockdown() then
                WK:Print(T("Pas en combat : la mémoire sera libérable à la sortie du combat."))
            else
                local before = collectgarbage("count")
                collectgarbage("collect")
                local after = collectgarbage("count")
                WK:Print(string.format(T("Mémoire libérée : %s (addons : %s maintenant)."), memText(math.max(0, before - after)), memText(after)))
                if UI.HidePerfTip then UI:HidePerfTip() end
            end
            return
        end
        if ToggleCalendar then ToggleCalendar() elseif GameTimeFrame and GameTimeFrame.Click then GameTimeFrame:Click() else UI:ToggleWindow() end
    end)
    local function showDate()
        WK.UI:TooltipOwner(bar.clockBtn, "ANCHOR_BOTTOM")
        local d = date("*t")
        local DAYS = { "dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi" }
        local MONTHS = { "janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre" }
        GameTooltip:SetText(string.format("%s %d %s", T(DAYS[d.wday]), d.day, T(MONTHS[d.month])), 1, 1, 1)
        if GetGameTime then local h, m = GetGameTime(); GameTooltip:AddDoubleLine(T("Heure du serveur"), string.format("%02d:%02d", h, m), 0.8, 0.8, 0.8, 1, 1, 1) end
        GameTooltip:AddDoubleLine(T("Session de jeu"), WK:FormatTime(time() - (bar.loginAt or time())), 0.8, 0.8, 0.8, 1, 1, 1)
    end
    bar.clockBtn:SetScript("OnEnter", function(s)
        -- addons et mémoire (réglage) ; sinon la date, la session et FPS · latence comme avant
        if cfg().perf and not (InCombatLockdown and InCombatLockdown()) then
            local ok = pcall(showPerf, s, showDate)
            if ok then return end
        end
        showDate()
        local fps, ms = stats()
        GameTooltip:AddDoubleLine(T("FPS · latence"), fps .. " · " .. ms .. " ms", 0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:Show()
    end)
    bar.clockBtn:SetScript("OnLeave", function() GameTooltip:Hide(); UI:HidePerfTip() end)
    bar.loginAt = time()
    bar.icons = {}
    for _, def in ipairs(SHORTCUTS) do bar.icons[def.key] = makeIcon(def) end
    bar.open = 0 -- 0 replié, 1 déplié
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
        -- 20 fois par seconde au plus (avant : survol et état relus à chaque image)
        self.tAcc = (self.tAcc or 0) + el
        if self.tAcc < 0.05 then return end
        el, self.tAcc = self.tAcc, 0
        local o = cfg()
        -- heure et points (2 fois par seconde)
        self.acc = self.acc + el
        if self.acc > 0.5 then
            self.acc = 0
            local txt = clockText()
            self.time:SetText(txt)
            self.timeBold:SetText(txt)
            if txt ~= self.lastTxt then self.lastTxt = txt; self.relayout = true end
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
        if self.clockA ~= ca then
            self.clockA = ca
            self.bg:SetAlpha(ca); self.clockBtn:SetAlpha(ca)
        end
        if inCombat() then want = self.open > 0.5 and 1 or 0 end
        -- dépliage d'un coup, sans animation ; on ne replace que si l'état change (ou toutes les 5 s déplié)
        local now = GetTime()
        if self.open ~= want or self.relayout or (self.open > 0 and now - (self.lastLayout or 0) > 5) then
            self.open = want
            self.relayout = nil
            self.lastLayout = now
            self:Layout()
        end
        -- icônes, pastilles et compteurs : une fois par seconde, et seulement si la barre est dépliée
        if self.open > 0 and (self.decorAt == nil or now - self.decorAt > 1) then
            self.decorAt = now
            self:Decor()
        end
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

    -- Place les raccourcis (hors combat). Chaque fond de côté épouse ses icônes.
    function bar:Layout()
        if inCombat() then return end
        local o = cfg()
        local base = math.max(20, math.min(48, o.size or BASE))
        local k = base / BASE
        local L, R = self:Lists()
        local open = self.open
        local function sizeOf() return base end
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
        if self.probeKey ~= fkey then
            self.probeKey = fkey
            self.probe:SetFont(font, fs, "")
            self.probe:SetText("0")
            self.cell = self.probe:GetStringWidth() or 0
            self.probe:SetText("1")
            self.one = self.probe:GetStringWidth() or 0
        end
        local cell, one = self.cell, self.one
        local txt = self.time:GetText() or ""
        local lead, trail = 0, 0
        if cell > 0 and one > cell * 0.8 then -- chiffres tabulaires
            lead = (txt:sub(1, 1) == "1") and cell * 0.39 or 0
            trail = (txt:sub(-1) == "1") and cell * 0.12 or 0
        end
        local shift = (lead - trail) / 2
        self.time:ClearAllPoints()
        self.time:SetPoint("CENTER", self.clockBtn, "CENTER", (o.bold and -0.5 or 0) - shift, yoff)
        self.bg:SetSize(clockW, h)
        self:SetHeight(h)
        local mid = (self:GetWidth() or 120) / 2
        local top = PAD + math.floor((h - base - PAD * 2) / 2) -- icônes centrées sur la hauteur de l'heure
        local slide = 0
        local function side(list, panel, dir)
            panel:SetShown(#list > 0 and open > 0.05)
            if #list == 0 then return end
            local edge = mid + dir * (clockW / 2 + GAP + slide) -- bord du fond côté heure
            local x = edge + dir * PAD
            local maxH = 0
            for _, ic in ipairs(list) do
                local sz = sizeOf()
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
            if not o.side[def.key] then self.icons[def.key]:Hide() end
        end
        self:Decor()
        -- largeur du cadre : place pour tous les raccourcis (stable, pour le mode édition)
        local n = #L > #R and #L or #R
        self:SetWidth(math.max(120, n * (base + IGAP) * 2 + clockW + 2 * (GAP + PAD) + 20))
    end

    -- Icônes, couleurs, pastilles et compteurs (rien ne bouge : possible sans tout replacer)
    function bar:Decor()
        self.decorAt = GetTime()
        for _, def in ipairs(SHORTCUTS) do
            local ic = self.icons[def.key]
            ic.tex:SetTexture(def.icon())
            if def.tint then ic.tex:SetVertexColor(UI:Accent()) end
            ic.bg:SetColor(unpack(C.surface2))
            ic.edge:SetColor(unpack(C.border))
            local dc = def.dot and def.dot()
            ic.dot:SetShown(dc ~= nil)
            if dc then ic.dot:SetVertexColor(unpack(dc)) end
        end
        UI:ClockCounts()
    end

    UI:RegisterHUD("clock", bar, { label = T("Micro menu"), protected = true, point = "TOP",
        default = { 0, UIParent:GetHeight() / 2 - 6 },
        -- coupé dans ses réglages : absent du mode édition
        enabled = function() return cfg().enabled and WK:FeatureOn("micro") and true or false end,
        -- aperçu : la barre telle qu'en jeu (hors combat seulement : cadre protégé)
        sample = function() if not inCombat() then UI:SyncClock() end end })
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
            if show and def.badgeAccent and not ic.badgeAcc then
                -- pastille d'accent en haut à droite (raccourci « Couche »)
                ic.badgeAcc = true
                ic.badge:ClearAllPoints(); ic.badge:SetPoint("CENTER", ic, "TOPRIGHT", -2, -2)
            end
            if show and def.badgeAccent then
                local r, g, b = UI:Accent()
                ic.badge.bg:SetColor(r, g, b, 1)
                ic.num:SetTextColor(C.bg[1], C.bg[2], C.bg[3])
            end
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
-- micro menu affiché : chaque minute (compteurs) ; sinon toutes les 5 min seulement, car la liste sert aussi à
-- reconnaître un membre de la guilde (acceptation des invitations, refus des duels : Modules/QoL.lua)
local rosterTicks = 0
local function askRoster(force)
    rosterTicks = rosterTicks + 1
    local shown = bar and bar:IsShown()
    if (force or shown or rosterTicks % 5 == 0) and IsInGuild and IsInGuild() then
        if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) elseif GuildRoster then pcall(GuildRoster) end
    end
end
if C_Timer.NewTicker then C_Timer.NewTicker(60, function() askRoster() end) end
WK:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(5, function() askRoster(true); UI:ClockCounts() end) end)

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

local clockPending -- SyncClock demandé en combat
function UI:SyncClock()
    if UI.SyncFishingMinimap then UI:SyncFishingMinimap() end -- le bouton de minicarte de la pêche en dépend
    -- en combat : rien ne bouge (cadre protégé), appliqué à la sortie du combat
    if inCombat() then clockPending = true return end
    clockPending = nil
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
WK:On("PLAYER_REGEN_ENABLED", function() if clockPending then UI:SyncClock() end end)
