local ADDON_NAME, WK = ...
local M = WK:NewModule("Guide")
local T = function(s) return WK.T(s) end

-- Guidage vers le lieu utile le plus proche (boîte aux lettres, banque, marchand, maître de
-- classe), d'après Modules/PlacesDB.lua (données QuestieDB). Une flèche à l'écran et un repère
-- sur la carte du monde montrent le chemin ; les alertes de QoL (sacs pleins, composants,
-- munitions, réparation) peuvent lancer le guidage d'elles-mêmes.

M.KIND = { mail = 1, bank = 2, vendor = 4, repair = 8, ammo = 16, reagent = 32, poison = 64, trainer = 128, general = 256, stable = 512, fishing = 1024 }
local KIND = M.KIND
M.LABELS = {
    mail = "Boîte aux lettres", bank = "Banque", vendor = "Marchand", repair = "Réparation",
    ammo = "Munitions", reagent = "Composants", trainer = "Maître de classe", stable = "Maître des écuries", fishing = "Fournitures de pêche", bags = "Boîte aux lettres, banque ou marchand",
}

local DEFAULTS = { auto = true, arrow = false, mapPin = true, screenPin = true, arriveSound = true, trainerOnLevel = true, route = true, routeMini = true, learn = true, dockBanner = true, shipsMap = true, corpse = true }
function M:Config()
    local q = WK.modules.QoL:Config()
    q.guide = q.guide or {}
    for k, v in pairs(DEFAULTS) do if q.guide[k] == nil then q.guide[k] = v end end
    -- 0.80.3 : l'épingle et le trajet guident ; la flèche passe en option, coupée une fois pour toutes
    if not q.guide.arrowOff1 then q.guide.arrow = false; q.guide.arrowOff1 = true end
    return q.guide
end

local function band(a, b)
    if bit and bit.band then return bit.band(a, b) end
    if bit32 and bit32.band then return bit32.band(a, b) end
    -- repli arithmétique (petits entiers positifs)
    local r, p = 0, 1
    while a > 0 and b > 0 do
        if a % 2 == 1 and b % 2 == 1 then r = r + p end
        a, b, p = math.floor(a / 2), math.floor(b / 2), p * 2
    end
    return r
end
M.band = band

function M:Count()
    local n = 0
    for _, list in pairs(WK.PlacesDB or {}) do n = n + #list end
    return n
end

---------------------------------------------------------------------------
-- Positions
---------------------------------------------------------------------------
-- Position « monde » d'un point de carte : continent, nord, ouest (en mètres du jeu).
local worldCache = {}
local function toWorld(mapID, x, y)
    if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
    local ok, cont, pos = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(x, y))
    if not ok or not cont or not pos then return nil end
    local wx, wy = pos.x, pos.y
    if pos.GetXY then wx, wy = pos:GetXY() end
    return cont, wx, wy
end

M.ToWorld = toWorld

local function entryWorld(mapID, e)
    local w = worldCache[e]
    if w == nil then
        local cont, wx, wy = toWorld(mapID, e[1] / 100, e[2] / 100)
        w = cont and { cont, wx, wy } or false
        worldCache[e] = w
    end
    return w or nil
end

-- Lue par plusieurs cadres de la mini-carte à chaque rafraîchissement : une seule lecture par image
-- (même table rendue, à ne pas modifier).
local posAt, posVal, posSrc
local readPos
function M:PlayerPos()
    local now = GetTime and GetTime()
    -- même position pendant 50 ms (avant : une table neuve à chaque image pour chaque appelant : carte,
    -- minicarte, flèche, tracé…)
    if posVal and now and posAt and now - posAt < 0.05 and posSrc == C_Map then return posVal end
    posVal, posAt, posSrc = readPos(), now, C_Map
    return posVal
end
readPos = function()
    if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
    local map = C_Map.GetBestMapForUnit("player")
    if not map then return nil end
    local pos = C_Map.GetPlayerMapPosition(map, "player")
    if not pos then return nil end
    local x, y = pos.x, pos.y
    if pos.GetXY then x, y = pos:GetXY() end
    if not x or (x == 0 and y == 0) then return nil end
    local cont, wx, wy = toWorld(map, x, y)
    return { map = map, x = x, y = y, cont = cont, wx = wx, wy = wy }
end

-- Distance (mètres du jeu) et cap (radians, sens antihoraire depuis le nord) du joueur vers le lieu.
function M:Vector(p, t)
    if p.cont and t.cont and p.cont == t.cont then
        local dn, dw = t.wx - p.wx, t.wy - p.wy
        return math.sqrt(dn * dn + dw * dw), math.atan2(dw, dn)
    end
    if p.map == t.map then
        -- repli : coordonnées de carte (sans échelle exacte)
        local dn, dw = -(t.y - p.y), -(t.x - p.x)
        return math.sqrt(dn * dn + dw * dw) * 1000, math.atan2(dw, dn)
    end
    return nil
end

---------------------------------------------------------------------------
-- Recherche du lieu le plus proche
---------------------------------------------------------------------------
local function factionOK(e, faction)
    return not e[5] or e[5] == faction
end

-- kinds : liste de bits acceptés (un seul suffit) ; class : maître de cette classe.
function M:Nearest(kinds, class)
    local p = self:PlayerPos()
    if not p then return nil end
    local fac = UnitFactionGroup("player")
    local faction = fac == "Horde" and "H" or (fac == "Alliance" and "A") or fac
    local cands = {}
    for mapID, list in pairs(WK.PlacesDB or {}) do
        for _, e in ipairs(list) do
            local ok = false
            for _, k in ipairs(kinds) do if band(e[3], k) ~= 0 then ok = true break end end
            if ok and class then ok = e[4] == class end
            if ok and factionOK(e, faction) then
                local w = entryWorld(mapID, e)
                local t = { map = mapID, x = e[1] / 100, y = e[2] / 100 }
                if w then t.cont, t.wx, t.wy = w[1], w[2], w[3] end
                local d = self:Vector(p, t)
                if d then
                    t.e, t.distance = e, d
                    table.insert(cands, t)
                end
            end
        end
    end
    if #cands == 0 then return nil end
    table.sort(cands, function(a, b) return a.distance < b.distance end)
    return cands[1]
end

-- « à 240 m », ou « à 3 min de trajet » quand le trajet est estimé (Modules/Nav.lua)
function M:DistText(t)
    if t.seconds then return string.format(T("à %d min de trajet"), math.max(1, math.floor(t.seconds / 60 + 0.5))) end
    return string.format(T("à %d m"), math.floor(t.distance or 0))
end

function M:PlaceName(t)
    local e = t and t.e
    if not e then return "?" end
    if band(e[3], KIND.mail) ~= 0 and not e[6] then return T("Boîte aux lettres") end
    local fr = WK.Lang() == "frFR"
    local name = (fr and e[7]) or e[6] or "?"
    local sub = fr and e[8] or nil
    return sub and (name .. " (" .. sub .. ")") or name
end

-- Nom et rôle séparés (flèche de guidage sur deux lignes)
function M:PlaceParts(t)
    local e = t and t.e
    if not e then return "?" end
    if band(e[3], KIND.mail) ~= 0 and not e[6] then return T("Boîte aux lettres") end
    local fr = WK.Lang() == "frFR"
    return (fr and e[7]) or e[6] or "?", fr and e[8] or nil
end

---------------------------------------------------------------------------
-- Cible courante
---------------------------------------------------------------------------
-- M.target = { map, x, y, cont, wx, wy, e, reason, kind }
-- Le point du jeu (C_Map.GetUserWaypoint) est-il encore celui qu'on a posé ? Le joueur a pu poser le sien
-- ou suivre une quête entre-temps. tracked = vrai : il faut aussi qu'il soit le point suivi (C_SuperTrack),
-- condition pour que le repère du jeu (C_Navigation.GetFrame) soit le nôtre. Gardé 0,25 s.
local function samePoint(pt, map, x, y)
    if not (pt and pt.uiMapID and pt.position) then return false end
    local px, py = pt.position.x, pt.position.y
    if not (px and py) then return false end
    if pt.uiMapID == map then return math.abs(px - x) < 0.002 and math.abs(py - y) < 0.002 end
    -- carte différente (le jeu a pu poser le point sur la carte de la zone) : comparé en coordonnées monde
    local c1, x1, y1 = M.ToWorld(pt.uiMapID, px, py)
    local c2, x2, y2 = M.ToWorld(map, x, y)
    return c1 and c1 == c2 and x1 and x2 and math.sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2) < 10 or false
end
local function userPointIs(map, x, y)
    local CM = _G.C_Map
    if not (CM and CM.GetUserWaypoint) then return false end
    local ok, pt = pcall(CM.GetUserWaypoint)
    return ok and samePoint(pt, map, x, y) or false
end
local ownCache = { at = -10 }
function M:OwnsWaypoint(tracked)
    local pos = self.placedWaypoint and self.placedPos
    if not pos then return false end
    local now = _G.GetTime and _G.GetTime() or 0
    local c = ownCache
    if now - c.at > 0.25 or now < c.at then
        c.at = now
        c.own = userPointIs(pos.map, pos.x, pos.y)
        c.tracked = true
        local ST = _G.C_SuperTrack
        if c.own and ST and ST.IsSuperTrackingUserWaypoint then
            local ok, v = pcall(ST.IsSuperTrackingUserWaypoint)
            c.tracked = not ok or v ~= false
        end
    end
    return c.own and (not tracked or c.tracked) or false
end

-- Repère du jeu déplacé sur une étape du trajet (station, maître de vol) puis rendu à la cible finale : seulement
-- s'il est encore le nôtre ; la position retenue suit, pour que l'addon le reconnaisse toujours comme le sien
function M:AimWaypoint(pt)
    if not (pt and pt.map and self.placedWaypoint) then return end
    local p = self.placedPos
    if p and p.map == pt.map and math.abs(p.x - pt.x) < 0.0005 and math.abs(p.y - pt.y) < 0.0005 then return end
    local CM, UMP, ST = _G.C_Map, _G.UiMapPoint, _G.C_SuperTrack
    if not (CM and CM.SetUserWaypoint and UMP and UMP.CreateFromCoordinates) then return end
    pcall(CM.SetUserWaypoint, UMP.CreateFromCoordinates(pt.map, pt.x, pt.y))
    if ST and ST.SetSuperTrackedUserWaypoint then pcall(ST.SetSuperTrackedUserWaypoint, true) end
    self.placedPos = { map = pt.map, x = pt.x, y = pt.y }
    if WK.DB and WK.DB.global then WK.DB.global.guideWp = { pt.map, pt.x, pt.y } end
    ownCache.at = -10
end

function M:Start(target, reason, kind)
    if not target then return false end
    target.reason, target.kind = reason, kind
    self.target = target
    local cfg = self:Config()
    -- point suivi du jeu : repère sur la carte et position à l'écran pour l'épingle (UI/NavPin.lua)
    if (cfg.mapPin or cfg.screenPin) and C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
        pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(target.map, target.x, target.y))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true) end
        self.placedWaypoint = true
        -- position posée, retenue aussi dans la sauvegarde : après un /reload en plein guidage, le point du jeu
        -- resté là est retiré à la connexion s'il n'a pas bougé (avant, il restait sur la carte)
        self.placedPos = { map = target.map, x = target.x, y = target.y }
        if WK.DB and WK.DB.global then WK.DB.global.guideWp = { target.map, target.x, target.y } end
        ownCache.at = -10
    end
    -- trajet qui suit les chemins connus (Modules/Nav.lua), calculé en arrière-plan ; nouveaux essais remis à
    -- zéro (une cible rendue après un /way ou le retour au corps gardait ses essais déjà comptés)
    target.navTries = nil
    if WK.modules.Nav then WK.modules.Nav:Plan(target) end
    if self.OnTarget then self:OnTarget() end
    if self.Redraw then self:Redraw() end
    WK:NotifyChanged()
    return true
end

function M:Stop()
    local was = self.target
    self.target = nil
    -- point /way arrêté à la main (croix, clic droit, /wk) : la file est mise en pause (pas relancée par une
    -- reprise) et le guidage d'avant revient ; Waypoints arrête lui-même son guidage avec quietStop
    if was and was.kind == "way" and not self.quietStop then
        local W = WK.modules.Waypoints
        if W and W.Paused then _G.C_Timer.After(0, function() W:Paused() end) end
    end
    if WK.modules.Nav then WK.modules.Nav:Clear() end
    -- avant, le point du jeu était toujours effacé, même quand le joueur en avait posé un autre (ou suivait une
    -- quête) entre-temps : il n'est effacé que s'il est encore le nôtre
    ownCache.at = -10
    if self.placedWaypoint and C_Map and C_Map.ClearUserWaypoint and self:OwnsWaypoint() then
        pcall(C_Map.ClearUserWaypoint)
    end
    self.placedWaypoint, self.placedPos = nil, nil
    if WK.DB and WK.DB.global then WK.DB.global.guideWp = nil end
    if self.OnTarget then self:OnTarget() end
    -- (Nav:Clear redessine déjà la carte via RefreshNavRoute : pas un second redessin complet)
    if self.Redraw and not (WK.modules.Nav and WK.UI.RefreshNavRoute) then self:Redraw() end
    WK:NotifyChanged()
    -- détour fini (marchand, boîte aux lettres, maître…) : une file /way pas finie reprend la main.
    -- Points /way et retour au corps : jamais ici, ils rendent eux-mêmes le guidage d'avant (M:Restore)
    local own = was and (was.kind == "way" or was.kind == "corpse")
    if was and not own and C_Timer then
        C_Timer.After(0.5, function() M:Resume() end)
    end
end
-- Guidage à garder pour plus tard (avant un /way ou le retour au corps) : un retour au corps ou un /way n'est
-- jamais gardé
function M.Keep(_, t)
    if not t or t.kind == "corpse" or t.kind == "way" then return nil end
    return t
end
-- Rend un guidage gardé par Keep (ou, sans rien de gardé, laisse une file /way reprendre)
local function ghost() return _G.UnitIsGhost and _G.UnitIsGhost("player") end
function M:Restore(kept)
    if self.target then return end
    -- fantôme : rien ne reprend, le retour au corps revient (UI/CorpseBanner) ; stopGuide rendra le reste
    if ghost() then
        if WK.UI.CorpseRestart then WK.UI.CorpseRestart(kept) end
        return
    end
    if kept then self:Start(kept, kept.reason, kept.kind) else self:Resume() end
end
function M:Resume()
    if self.target or ghost() then return end
    -- file /way pas finie (interrompue par un détour ou un retour au corps) : elle repasse en premier
    local W = WK.modules.Waypoints
    if W and W.List and W:List()[1] and W.Go and not (W.IsPaused and W:IsPaused()) then W:Go() end
end

-- Aller au plus proche d'un genre : "mail", "bank", "repair", "vendor", "ammo", "trainer", "bags", ou
-- un composant (r = définition de QoL.REAGENTS). Renvoie la cible ou nil (et le dit dans le chat).
local REAGENT_KINDS = {
    poisons = { KIND.poison }, ["5140"] = { KIND.poison, KIND.reagent }, ["5060"] = { KIND.general },
    ["5175"] = { KIND.reagent, KIND.general }, ["5176"] = { KIND.reagent, KIND.general },
    ["5177"] = { KIND.reagent, KIND.general }, ["5178"] = { KIND.reagent, KIND.general },
}
function M:KindsFor(what, r)
    if what == "bags" then return { KIND.mail, KIND.bank, KIND.vendor } end
    if what == "reagent" then return REAGENT_KINDS[r and r.key or ""] or { KIND.reagent } end
    return { KIND[what] or KIND.vendor }
end

function M:GoTo(what, r, quiet)
    local class = what == "trainer" and select(2, UnitClass("player")) or nil
    local t = self:Nearest(self:KindsFor(what, r), class)
    if not t then
        if not quiet then WK:Print(string.format(T("Aucun lieu connu pour : %s"), T(M.LABELS[what] or what))) end
        return nil
    end
    self:Start(t, M.LABELS[what] or what, what)
    if not quiet and not self:Config().arrow and not self:Config().screenPin then
        local label, place = T(M.LABELS[what] or what), self:PlaceName(t)
        if place == label then
            WK:Print(string.format(T("Au plus près · %s, %s"), label, self:DistText(t)))
        else
            WK:Print(string.format(T("Au plus près · %s : %s, %s"), label, place, self:DistText(t)))
        end
    end
    return t
end

---------------------------------------------------------------------------
-- Alertes qui guident : besoins du perso connecté
---------------------------------------------------------------------------
local lastNeed = {}
local function shouldWarn(key)
    local now = GetTime and GetTime() or 0
    if lastNeed[key] and now - lastNeed[key] < 600 then return false end
    lastNeed[key] = now
    return true
end

-- Besoins actuels : { { key, what, r, text } } dans l'ordre d'urgence.
function M:Needs()
    local out = {}
    local Q = WK.modules.QoL
    local key = WK:CharKey()
    for _, a in ipairs(Q:Alerts()) do
        if a.key == key then
            if a.kind == "durability" then table.insert(out, { key = "repair", what = "repair", text = a.text })
            elseif a.kind == "bags" and not a.bank then table.insert(out, { key = "bags", what = "bags", text = a.text })
            elseif a.kind == "ammo" then table.insert(out, { key = "ammo", what = "ammo", text = a.text })
            elseif a.kind == "reagent" and a.reagent and a.reagent.buy then
                table.insert(out, { key = "reagent" .. a.reagent.key, what = "reagent", r = a.reagent, text = a.text })
            end
        end
    end
    return out
end

local function canGuide()
    if InCombatLockdown and InCombatLockdown() then return false end
    if IsInInstance and select(2, IsInInstance()) ~= "none" and select(2, IsInInstance()) ~= nil then return false end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return false end
    if UnitOnTaxi and UnitOnTaxi("player") then return false end
    return true
end

function M:Check()
    local cfg = self:Config()
    if not cfg.auto or not canGuide() then return end
    for _, need in ipairs(self:Needs()) do
        if shouldWarn(need.key) then
            local t = self:Nearest(self:KindsFor(need.what, need.r))
            local msg = need.text
            local act
            if t then
                act = { label = T("Guider"), ghost = true, onClick = function() M:Start(t, M.LABELS[need.what], need.what) end }
                msg = msg .. " · " .. self:PlaceName(t) .. " " .. self:DistText(t)
                if not self.target then self:Start(t, M.LABELS[need.what], need.what) end
            end
            WK.modules.QoL:Remind("guide" .. need.key, msg, 1, 0.82, 0.2, nil, { action = act })
            return -- un besoin à la fois
        end
    end
end

-- Arrivé : le guidage s'arrête à l'ouverture du lieu visé (ou tout près de lui).
local function arrived(kinds)
    local t = M.target
    if not t then return end
    for _, k in ipairs(kinds) do
        if band(t.e[3], k) ~= 0 then M:Stop() return end
    end
end
WK:On("MAIL_SHOW", function() arrived({ KIND.mail }) end)
WK:On("BANKFRAME_OPENED", function() arrived({ KIND.bank }) end)
WK:On("MERCHANT_SHOW", function() arrived({ KIND.vendor, KIND.repair }) end)
WK:On("TRAINER_SHOW", function() arrived({ KIND.trainer }) end)

-- Nouveaux sorts tous les deux niveaux : le maître de classe le plus proche.
WK:On("PLAYER_LEVEL_UP", function(level)
    local cfg = M:Config()
    level = tonumber(level)
    if not cfg.trainerOnLevel or not level or level % 2 ~= 0 then return end
    C_Timer.After(2, function()
        if not canGuide() then return end
        -- un guidage en cours n'est pas remplacé : le rappel suffit
        local t
        if M.target then
            local class = select(2, UnitClass("player"))
            t = M:Nearest(M:KindsFor("trainer"), class)
        else
            t = M:GoTo("trainer", nil, true)
        end
        local msg = string.format(T("Niveau %d : nouveaux sorts chez ton maître de classe"), level)
        if t then msg = msg .. " · " .. M:PlaceName(t) .. " " .. M:DistText(t) end
        WK.modules.QoL:Remind("trainer", msg, 0.4, 0.85, 1, nil,
            { action = t and { label = T("Guider"), ghost = true, onClick = function() M:Start(t, M.LABELS.trainer, "trainer") end } or nil })
    end)
end)

function M:OnLogin()
    self:Config()
    if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(10, function() M:Check() end) end
    -- /reload en plein guidage : le point posé par l'addon restait sur la carte du jeu. Quelques secondes après
    -- la connexion (après la reprise d'une file /way), il est effacé s'il est encore à la même place et
    -- qu'aucun guidage n'a repris
    if _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(6, function()
            local g = WK.DB and WK.DB.global
            local w = g and g.guideWp
            if not w or M.target then return end
            g.guideWp = nil
            if type(w) == "table" and w[1] and w[2] and w[3] and userPointIs(w[1], w[2], w[3])
                and _G.C_Map and _G.C_Map.ClearUserWaypoint then
                pcall(_G.C_Map.ClearUserWaypoint)
            end
        end)
    end
end

---------------------------------------------------------------------------
-- Diagnostic (/wk nav) : ce que ce client donne pour un repère de navigation à l'écran
-- (marqueur de point de passage). Le jeu dessine son repère quand un point de la carte est suivi ;
-- un addon peut alors lire sa place à l'écran et la distance.
---------------------------------------------------------------------------
function M:NavReport()
    local function yn(v) return v and T("oui") or T("non") end
    local function call(fn, ...) if not fn then return "absent" end local ok, a, b = pcall(fn, ...); if not ok then return "erreur" end return tostring(a) .. (b ~= nil and (", " .. tostring(b)) or "") end
    local N, ST = C_Navigation, C_SuperTrack
    WK:Print(T("Repère de navigation : diagnostic"))
    WK:Print("  C_Navigation : " .. yn(N) .. (N and (" · GetFrame " .. yn(N.GetFrame) .. " · GetDistance " .. yn(N.GetDistance)
        .. " · HasValidScreenPosition " .. yn(N.HasValidScreenPosition) .. " · WasClampedToScreen " .. yn(N.WasClampedToScreen)) or ""))
    WK:Print("  C_SuperTrack : " .. yn(ST) .. (ST and (" · SetSuperTrackedUserWaypoint " .. yn(ST.SetSuperTrackedUserWaypoint)
        .. " · IsSuperTrackingUserWaypoint " .. yn(ST.IsSuperTrackingUserWaypoint)) or ""))
    WK:Print("  C_Map.SetUserWaypoint : " .. yn(C_Map and C_Map.SetUserWaypoint) .. " · HasUserWaypoint : " .. call(C_Map and C_Map.HasUserWaypoint))
    WK:Print("  SuperTrackedFrame : " .. yn(SuperTrackedFrame))
    if WK.modules.Nav then WK.modules.Nav:Report() end
    WK:Print("  " .. T("point suivi") .. " : " .. call(ST and ST.IsSuperTrackingUserWaypoint) .. " · " .. T("guidage Warband Keeper") .. " : " .. yn(self.target))
    if N then
        WK:Print("  " .. T("distance") .. " : " .. call(N.GetDistance) .. " · " .. T("à l'écran") .. " : " .. call(N.HasValidScreenPosition)
            .. " · " .. T("au bord") .. " : " .. call(N.WasClampedToScreen))
        local ok, f = pcall(N.GetFrame or function() end)
        if ok and f and f.GetCenter then
            local x, y = f:GetCenter()
            WK:Print("  " .. T("repère du jeu à l'écran") .. " : " .. string.format("%.0f, %.0f", x or -1, y or -1))
        else
            WK:Print("  " .. T("repère du jeu à l'écran") .. " : " .. T("aucun (lance un guidage, puis relance /wk nav)"))
        end
    end
end
