local _, WK = ...
local M = WK:NewModule("Layer")
local T = function(s) return WK.T(s) end

-- Changer de couche (raccourci « Couche » du micro menu, UI/ClockBar.lua ; maquettes A + B).
-- Le jeu change la couche d'un joueur qui rejoint le groupe d'un joueur d'une autre couche. Sur un clic :
--   1. recherche des joueurs de la zone (/who, toutes couches) ;
--   2. demande « ASK:<zone> » à chacun en message d'addon caché (préfixe WKlayer : rien dans le chat) ;
--   3. un joueur de Warband Keeper qui a coché « Aider les autres » (coupé par défaut), dans la même zone, hors
--      groupe, combat et instance, invite ; l'invitation d'un joueur contacté est acceptée toute seule ;
--   4. le groupe est quitté LEAVE_AFTER s après ; SHARD_TRANSFER dit si la couche a changé (sinon : même couche,
--      cet hôte est mis de côté SAME_FOR s).
-- Idées de LayerSwap (aucune licence fournie) : aucun code repris, protocole à nous (pas compatible LayerSwap).
-- Réglages et données : WK.DB.global.layer = { help, line, moves[perso] = { dates }, hostSent = { dates } }
-- (hors profils). Limite du jeu : CAP changements par heure glissante.
local PREFIX = "WKlayer"
M.CAP, M.CAP_FOR = 10, 3600
M.HOST_CAP, M.HOST_WINDOW, M.HOST_COOLDOWN = 6, 600, 60
M.LEAVE_AFTER, M.WAIT_FOR, M.SAME_FOR = 4, 25, 600
M.BURST, M.MAX_ASK = 8, 40
M.STATE_FOR = 60 -- une étape reste affichée une minute sous l'heure

local function issecret(v) return _G.issecretvalue and _G.issecretvalue(v) end
local function now() return _G.GetTime and _G.GetTime() or 0 end
local function inCombat() return _G.InCombatLockdown and _G.InCombatLockdown() end

function M.Config(_)
    local g = WK.DB.global
    g.layer = g.layer or {}
    local c = g.layer
    if c.help == nil then c.help = false end
    if c.line == nil then c.line = true end
    c.moves = c.moves or {}
    c.hostSent = c.hostSent or {}
    return c
end

-- nom comparable (« Prénom Nom », sans royaume ni casse)
local function norm(name)
    if type(name) ~= "string" or issecret(name) then return nil end
    return (name:gsub("%-.*$", "")):lower()
end

-- zone du joueur (carte de niveau zone : un bâtiment ou une grotte compte pour sa zone)
local function zoneHere()
    local CM = _G.C_Map
    if not (CM and CM.GetBestMapForUnit) then return nil end
    local id = CM.GetBestMapForUnit("player")
    local guard = 0
    while id and guard < 6 do
        local info = CM.GetMapInfo and CM.GetMapInfo(id)
        if not info then break end
        if (info.mapType or 0) <= 3 or not info.parentMapID or info.parentMapID == 0 then return id, info.name end
        id = info.parentMapID
        guard = guard + 1
    end
    local info = id and CM.GetMapInfo and CM.GetMapInfo(id)
    return id, info and info.name
end
M.ZoneHere = zoneHere

---------------------------------------------------------------------------
-- Changements de l'heure (limite du jeu)
---------------------------------------------------------------------------
local function moves()
    local c = M:Config()
    local key = WK:CharKey()
    c.moves[key] = c.moves[key] or {}
    local list, cut = c.moves[key], time() - M.CAP_FOR
    while #list > 0 and list[1] < cut do table.remove(list, 1) end
    return list
end
function M.Used(_) return #moves() end
function M.Left(_) return math.max(0, M.CAP - #moves()) end
-- heure à laquelle un changement se libère (si la limite est atteinte)
function M.FreeAt(_)
    local list = moves()
    return #list >= M.CAP and list[#list - M.CAP + 1] + M.CAP_FOR or nil
end
local function noteMove()
    table.insert(moves(), time())
end

---------------------------------------------------------------------------
-- Étape en cours : { kind, text, sub, at } (search, invited, moved, same, cap, none, blocked)
---------------------------------------------------------------------------
M.state = nil
local function setState(kind, text, sub)
    M.state = { kind = kind, text = text, sub = sub, at = now() }
    if WK.UI and WK.UI.ClockLayerChanged then WK.UI:ClockLayerChanged() end
end
function M.Current(_)
    local s = M.state
    if s and now() - s.at < M.STATE_FOR then return s end
end
function M.Busy(_)
    local s = M.state
    return s and (s.kind == "search" or s.kind == "invited") and now() - s.at < M.WAIT_FOR + 10 or false
end

---------------------------------------------------------------------------
-- Demande (perso qui veut changer)
---------------------------------------------------------------------------
local ask = nil -- { zone, names = { [norm] = nom }, sent, at, accepted, moved, host }
local sameUntil = {}
local mutedWho = {}

local function muteWhoFrames(on)
    for _, n in ipairs({ "FriendsFrame", "LFGWhoListFrame" }) do
        local f = _G[n]
        if f and f.IsEventRegistered and f.UnregisterEvent then
            if on and f:IsEventRegistered("WHO_LIST_UPDATE") then
                pcall(f.UnregisterEvent, f, "WHO_LIST_UPDATE"); mutedWho[n] = f
            elseif not on and mutedWho[n] then
                pcall(mutedWho[n].RegisterEvent, mutedWho[n], "WHO_LIST_UPDATE"); mutedWho[n] = nil
            end
        end
    end
end

local function send(msg, target)
    local CI = _G.C_ChatInfo
    if not (CI and CI.SendAddonMessage) or not target then return false end
    return pcall(CI.SendAddonMessage, PREFIX, msg, "WHISPER", target)
end

-- Pourquoi on ne peut pas demander maintenant (nil = possible)
function M.Blocked(_)
    if inCombat() then return T("pas en combat") end
    local inst, kind = false, nil
    if _G.IsInInstance then inst, kind = _G.IsInInstance() end
    if inst or (kind and kind ~= "none") then return T("pas en instance") end
    if _G.IsInGroup and _G.IsInGroup() then return T("quitte ton groupe d'abord") end
    if not (_G.C_FriendList and _G.C_FriendList.SendWho) then return T("recherche de joueurs indisponible") end
end

-- Clic sur le raccourci : lance une demande (doit être appelé dans le clic : la recherche /who l'exige)
function M:Swap()
    if self:Busy() then return false end
    local why = self:Blocked()
    if why then setState("blocked", T("Impossible pour l'instant"), why); return false end
    if self:Left() == 0 then
        local at = self:FreeAt()
        setState("cap", T("Limite de l'heure atteinte"), string.format(T("%d changements : de nouveau possible à %s"),
            M.CAP, at and date("%H:%M", at) or "?"))
        return false
    end
    local zone, zname = zoneHere()
    if not zone or not zname then
        setState("blocked", T("Impossible pour l'instant"), T("zone inconnue"))
        return false
    end
    ask = { zone = zone, names = {}, sent = 0, at = now() }
    local FL = _G.C_FriendList
    if FL.SetWhoToUi then pcall(FL.SetWhoToUi, true) end
    muteWhoFrames(true)
    local ok = pcall(FL.SendWho, 'z-"' .. zname .. '"')
    if not ok then
        muteWhoFrames(false); ask = nil
        setState("blocked", T("Impossible pour l'instant"), T("recherche refusée par le jeu"))
        return false
    end
    setState("search", T("Recherche d'un hôte..."), string.format(T("joueurs de %s"), zname))
    _G.C_Timer.After(5, function() muteWhoFrames(false) end)
    local mine = ask
    _G.C_Timer.After(M.WAIT_FOR, function()
        if ask == mine and not mine.accepted then
            ask = nil
            local whyNone = T("personne avec Warband Keeper et « Aider les autres » sur une autre couche dans la zone ; "
                .. "réessaie plus tard")
            setState("none", T("Aucun hôte trouvé"), whyNone)
        end
    end)
    return true
end

-- Résultats de /who : demande à chacun, 8 d'un coup puis un par seconde
local function onWho()
    if not ask or ask.listed then return end
    ask.listed = true
    muteWhoFrames(false)
    local FL = _G.C_FriendList
    local n = FL.GetNumWhoResults and FL.GetNumWhoResults() or 0
    local me = norm(WK:CharName(WK.DB:Me() or {}, WK:CharKey())) or norm(_G.UnitName and _G.UnitName("player"))
    local list = {}
    for i = 1, math.min(n or 0, 50) do
        local ok, info = pcall(FL.GetWhoInfo, i)
        local name = ok and type(info) == "table" and (info.fullName or info.name) or nil
        local k = norm(name)
        if k and k ~= me and not (sameUntil[k] and sameUntil[k] > now()) then
            list[#list + 1] = name
            ask.names[k] = name
        end
    end
    if #list == 0 then
        ask = nil
        setState("none", T("Aucun hôte trouvé"), T("personne d'autre dans la zone"))
        return
    end
    local mine = ask
    local i = 0
    local function burst(k)
        for _ = 1, k do
            i = i + 1
            if ask ~= mine or mine.accepted or i > math.min(#list, M.MAX_ASK) then return end
            if send("ASK:" .. mine.zone, list[i]) then mine.sent = mine.sent + 1 end
        end
        if ask == mine then
            local sub = string.format(T("%d joueurs de la zone contactés"), mine.sent)
            setState("search", T("Recherche d'un hôte..."), sub)
        end
        _G.C_Timer.After(1, function() burst(1) end)
    end
    burst(M.BURST)
end

-- Invitation d'un joueur contacté : acceptée, puis groupe quitté LEAVE_AFTER s après
local function finish(mine)
    if ask ~= mine then return end
    ask = nil
    if _G.IsInGroup and _G.IsInGroup() then
        local leave = (_G.C_PartyInfo and _G.C_PartyInfo.LeaveParty) or _G.LeaveParty
        if leave then pcall(leave) end
    end
    if mine.moved then
        local fmt = T("invité par %s · %d changement(s) restant(s) cette heure")
        setState("moved", T("Couche changée"), string.format(fmt, mine.host or "?", M:Left()))
    else
        if mine.hostKey then sameUntil[mine.hostKey] = now() + M.SAME_FOR end
        local why = T("l'hôte était déjà sur ta couche : clique de nouveau pour en chercher un autre")
        setState("same", T("Même couche"), why)
    end
end

local function onInvite(name)
    if not ask or ask.accepted then return end
    local k = norm(name)
    if not (k and ask.names[k]) then return end
    ask.accepted, ask.host, ask.hostKey = now(), name, k
    if _G.AcceptGroup then pcall(_G.AcceptGroup) end
    if _G.StaticPopup_Hide then pcall(_G.StaticPopup_Hide, "PARTY_INVITE") end
    setState("invited", string.format(T("Invitation de %s"), name), T("acceptée : le jeu te déplace en env. 1 s"))
    local mine = ask
    _G.C_Timer.After(M.LEAVE_AFTER, function() finish(mine) end)
end

---------------------------------------------------------------------------
-- Hôte (« Aider les autres ») : invite qui demande, avec retenue
---------------------------------------------------------------------------
local lastInvited = {}
local function hostCanInvite()
    local c = M:Config()
    local cut, keep = time() - M.HOST_WINDOW, {}
    for _, t in ipairs(c.hostSent) do if t >= cut then keep[#keep + 1] = t end end
    c.hostSent = keep
    return #keep < M.HOST_CAP
end
function M.HostLeft(_)
    hostCanInvite()
    return math.max(0, M.HOST_CAP - #M:Config().hostSent)
end

local function onAsk(sender, zone)
    local c = M:Config()
    if not c.help or inCombat() then return end
    if _G.IsInGroup and _G.IsInGroup() then return end
    if _G.IsInInstance and _G.IsInInstance() then return end
    local here = zoneHere()
    if not here or tostring(here) ~= tostring(zone) then return end
    local k = norm(sender)
    if not k or (lastInvited[k] and now() - lastInvited[k] < M.HOST_COOLDOWN) then return end
    if not hostCanInvite() then return end
    local inv = (_G.C_PartyInfo and _G.C_PartyInfo.InviteUnit) or _G.InviteUnit
    if not inv or not pcall(inv, sender) then return end
    lastInvited[k] = now()
    table.insert(c.hostSent, time())
    send("INV", sender)
end

---------------------------------------------------------------------------
-- Évènements
---------------------------------------------------------------------------
WK:On("PLAYER_LOGIN", function()
    local CI = _G.C_ChatInfo
    if CI and CI.RegisterAddonMessagePrefix then pcall(CI.RegisterAddonMessagePrefix, PREFIX) end
end)
WK:On("CHAT_MSG_ADDON", function(prefix, msg, _, sender)
    if prefix ~= PREFIX or issecret(msg) or issecret(sender) or type(msg) ~= "string" then return end
    local zone = msg:match("^ASK:(%d+)")
    if zone then onAsk(sender, zone) return end
    if msg == "INV" and ask then
        local k = norm(sender)
        if k then ask.names[k] = ask.names[k] or sender end
    end
end)
WK:On("WHO_LIST_UPDATE", onWho)
WK:On("PARTY_INVITE_REQUEST", function(name) onInvite(name) end)
-- changement de couche fait par le jeu : compté (limite de l'heure), et réussite d'une demande en cours
WK:On("SHARD_TRANSFER", function()
    noteMove()
    if ask and ask.accepted then ask.moved = true
    elseif M.state and M.state.kind == "same" and now() - M.state.at < 15 then
        setState("moved", T("Couche changée"), string.format(T("%d changement(s) restant(s) cette heure"), M:Left()))
    end
    if WK.UI and WK.UI.ClockLayerChanged then WK.UI:ClockLayerChanged() end
end)

-- (tests)
M._onWho, M._onInvite, M._onAsk, M._finish = onWho, onInvite, onAsk, finish
function M._ask() return ask end
