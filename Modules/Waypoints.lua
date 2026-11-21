local ADDON_NAME, WK = ...
local T = function(s) return WK.T(s) end

-- Points /way, à la manière de TomTom (aucun code de TomTom repris : seulement la syntaxe de /way et les
-- noms de son interface publique, pour que les guides et les autres addons marchent tels quels).
--   /way 32.35 48.55 [nom] · /way <zone> x y [nom] (nom anglais ou français, début du nom) · /way #<carte> x y
--   /way (seul) = ta position · /way list · /way reset · /way undo ; virgules acceptées (« 32,35 48,55 »).
-- Les points forment une file (WK.DB.global.waypoints[perso].list, hors profils) : on guide vers le 1er,
-- arrivé (moins de 12 m) on passe au suivant. Guidage : Modules/Guide.lua, genre « way » (flèche, épingle,
-- repère et trajet existants). Le guidage d'avant (tournée, quête suivie…) revient quand la file est vide.
-- TomTom installé : il garde /way (la nôtre devient /wkway) ; option « suivre ses points ». TomTom absent :
-- un petit TomTom (AddWaypoint, RemoveWaypoint…) reçoit les points que les autres addons lui envoient.
-- Liens du chat (« /way … » et « 32.35, 48.55 » écrits par les joueurs) et partage au groupe (texte /way et
-- message d'addon « WKway »). Réglages QoL:Config().way (QoL > Carte et guidage, onglet Guidage).
local M = WK:NewModule("Waypoints")
local PREFIX = "WKway"
local MAX = 50

function M:Config()
    local q = WK.modules.QoL:Config()
    q.way = q.way or {}
    local c = q.way
    if c.cmd == nil then c.cmd = "auto" end            -- auto / way / wkway
    if c.queue == nil then c.queue = true end          -- plusieurs /way = une file
    if c.order == nil then c.order = "typed" end       -- typed / near
    if c.tomtomApi == nil then c.tomtomApi = true end  -- répondre aux addons qui parlent à TomTom
    if c.followTomTom == nil then c.followTomTom = false end
    if c.chatLinks == nil then c.chatLinks = true end
    if c.keep == nil then c.keep = true end            -- garder la file après un /reload
    if c.sideList == nil then c.sideList = true end    -- liste sur la carte du monde
    if c.share == nil then c.share = true end          -- accepter les points partagés par le groupe
    return c
end

local function G() return WK.modules.Guide end
local function db()
    local g = WK.DB.global
    g.waypoints = g.waypoints or {}
    local key = WK:CharKey()
    g.waypoints[key] = g.waypoints[key] or { list = {} }
    return g.waypoints[key]
end
function M:List() return db().list end

---------------------------------------------------------------------------
-- Zones : noms anglais et français (Modules/WayZonesDB.lua), début du nom accepté
---------------------------------------------------------------------------
local ACCENTS = { ["à"] = "a", ["â"] = "a", ["ä"] = "a", ["é"] = "e", ["è"] = "e", ["ê"] = "e", ["ë"] = "e",
    ["î"] = "i", ["ï"] = "i", ["ô"] = "o", ["ö"] = "o", ["ù"] = "u", ["û"] = "u", ["ü"] = "u", ["ç"] = "c",
    ["À"] = "a", ["Â"] = "a", ["É"] = "e", ["È"] = "e", ["Ê"] = "e", ["Î"] = "i", ["Ô"] = "o", ["Û"] = "u", ["Ç"] = "c" }
local function norm(s)
    s = tostring(s or ""):gsub("[\195][\128-\191]", function(ch) return ACCENTS[ch] or ch end)
    s = s:lower():gsub("’", "'"):gsub("[%s%-'_%.]", "")
    return s
end
M.Norm = norm
function M:ZoneName(map)
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
    if info and info.name then return info.name end
    for _, z in ipairs(WK.WayZones or {}) do if z[1] == map then return WK.Lang() == "frFR" and z[3] or z[2] end end
    return "#" .. tostring(map)
end
local function englishName(map)
    for _, z in ipairs(WK.WayZones or {}) do if z[1] == map then return z[2] end end
    return nil
end
-- carte d'une zone nommée (nil si inconnue)
function M:FindZone(text)
    local want = norm(text)
    if want == "" then return nil end
    local zones = WK.WayZones or {}
    local function names(z)
        local out = { z[2], z[3] }
        local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(z[1])
        if info and info.name then out[3] = info.name end
        return out
    end
    for pass = 1, 3 do
        for _, z in ipairs(zones) do
            for _, n in ipairs(names(z)) do
                local nn = norm(n)
                -- « The Barrens » / « Les Tarides » : l'article est facultatif
                local bare = nn:gsub("^the", ""):gsub("^les", ""):gsub("^la", ""):gsub("^le", "")
                if pass == 1 and (nn == want or bare == want) then return z[1] end
                if pass == 2 and (nn:sub(1, #want) == want or bare:sub(1, #want) == want) then return z[1] end
                if pass == 3 and #want >= 4 and nn:find(want, 1, true) then return z[1] end
            end
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- Lecture d'une commande /way
---------------------------------------------------------------------------
local function playerMap()
    local p = G():PlayerPos()
    if p and p.map then return p.map, p end
    local m = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    return m, nil
end
local function num(s)
    if not s then return nil end
    s = s:gsub(",", ".")
    if not s:match("^%d+%.?%d*$") then return nil end
    return tonumber(s)
end
-- rend { map, x, y (0-1), title } ou nil, message d'erreur
function M:Parse(msg)
    msg = tostring(msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    -- « 32.35, 48.55 » : virgule séparatrice suivie d'une espace ; « 32,35 48,55 » : virgule décimale
    msg = msg:gsub("(%d)%s*[,;/]%s+(%d)", "%1 %2")
    local toks = {}
    for t in msg:gmatch("%S+") do toks[#toks + 1] = t end
    local i
    for k = 1, #toks - 1 do
        if num(toks[k]) and num(toks[k + 1]) then i = k break end
    end
    if not i then return nil, T("Coordonnées introuvables. Exemple : /way 32.35 48.55 Nom") end
    local x, y = num(toks[i]), num(toks[i + 1])
    if x > 100 or y > 100 then return nil, T("Coordonnées hors de la carte (de 0 à 100).") end
    local zoneText = table.concat(toks, " ", 1, i - 1)
    local title = (i + 2 <= #toks) and table.concat(toks, " ", i + 2) or nil
    local map
    if zoneText ~= "" then
        local id = zoneText:match("^#(%d+)$")
        map = id and tonumber(id) or self:FindZone(zoneText)
        if not map then return nil, string.format(T("Zone inconnue : %s"), zoneText) end
    else
        map = playerMap()
        if not map then return nil, T("Position inconnue pour l'instant.") end
    end
    return { map = map, x = x / 100, y = y / 100, title = title }
end

---------------------------------------------------------------------------
-- File de points et guidage
---------------------------------------------------------------------------
local prevTarget
local function short(v)
    local s = string.format("%.2f", v):gsub("0+$", ""):gsub("%.$", "")
    return s
end
local function coordsText(w) return short((w.x or 0) * 100) .. ", " .. short((w.y or 0) * 100) end
M.CoordsText = coordsText
local function label(w) return (w.title and w.title ~= "") and w.title or coordsText(w) end
M.Label = label
local function worldOf(w)
    if w.cont == nil then
        local c, wx, wy = G().ToWorld(w.map, w.x, w.y)
        w.cont, w.wx, w.wy = c or false, wx, wy
    end
    return w.cont and w or nil
end
function M:Distance(w)
    local p = G():PlayerPos()
    local ww = worldOf(w)
    if not (p and ww) then return nil end
    return G():Vector(p, ww)
end
local function changed()
    local t = G().target
    if t and t.kind == "way" and t.way and t.e then t.e[8] = M:Role(t.way) end
    if WK.UI.RedrawWorldMap then WK.UI.RedrawWorldMap("points /way") end
    if WK.UI.RefreshWaypointList then WK.UI:RefreshWaypointList() end
    WK:NotifyChanged()
end
local function sortNear(list)
    local p = G():PlayerPos()
    if not p then return end
    local cur = p
    local rest, out = {}, {}
    for _, w in ipairs(list) do rest[#rest + 1] = w end
    while #rest > 0 do
        local best, bd = 1, math.huge
        for k, w in ipairs(rest) do
            local ww = worldOf(w)
            local d = (ww and cur.cont == ww.cont) and math.sqrt((ww.wx - cur.wx) ^ 2 + (ww.wy - cur.wy) ^ 2) or 1e9
            if d < bd then best, bd = k, d end
        end
        local w = table.remove(rest, best)
        out[#out + 1] = w
        cur = worldOf(w) or cur
    end
    for k = 1, #list do list[k] = out[k] end
end

-- 2e ligne de l'épingle : zone, coordonnées et points qui restent
function M:Role(w)
    local n = #self:List()
    local role = self:ZoneName(w.map) .. " " .. coordsText(w)
    if n > 1 then role = role .. " · " .. string.format(T("encore %d"), n - 1) end
    return role
end

-- Lance le guidage vers le 1er point de la file
function M:Go()
    local w = self:List()[1]
    if not w then return end
    db().paused = nil -- un point relancé reprend la file
    local g = G()
    -- guidage d'avant gardé seulement si on a mieux (un retour au corps ou rien de gardable n'écrase plus celui
    -- gardé avant le premier /way)
    if g.target and g.target.kind ~= "way" then
        local kept = g:Keep(g.target)
        if kept or not prevTarget then prevTarget = kept or prevTarget end
    end
    local t = { map = w.map, x = w.x, y = w.y,
        e = { w.x * 100, w.y * 100, 0, nil, nil, label(w), label(w), self:Role(w) } }
    t.cont, t.wx, t.wy = g.ToWorld(w.map, w.x, w.y)
    t.way = w
    g:Start(t, "Point /way", "way")
    changed()
end

-- Ajoute un point. opts.now = en tête et guidé tout de suite ; opts.silent ; opts.src (tomtom, chat, map…)
function M:Add(map, x, y, title, opts)
    opts = opts or {}
    if not (map and x and y) then return nil end
    local cfg = self:Config()
    local list = self:List()
    -- même point déjà dans la file (lien cliqué deux fois, point partagé reçu aussi en texte, TomTom qui
    -- recharge ses points) : pas de doublon ; « maintenant » le remet en tête
    for k, v in ipairs(list) do
        if v.map == map and math.abs(v.x - x) < 0.0015 and math.abs(v.y - y) < 0.0015 then
            if title and title ~= "" and not v.title then v.title = title end
            -- « maintenant » : remis en tête et guidé, aussi s'il était déjà en tête mais pas guidé (autre
            -- guidage en cours entre-temps)
            local g = G()
            local guided = g.target and g.target.kind == "way" and g.target.way == v
            if opts.now and (k > 1 or not guided) then
                if k > 1 then table.remove(list, k); table.insert(list, 1, v) end
                self:Go()
            else
                changed()
            end
            if not opts.silent then
                WK:Print(string.format(T("Point déjà dans la file (n° %d) : %s"), opts.now and 1 or k, label(v)))
            end
            return v
        end
    end
    local w = { map = map, x = x, y = y, title = (title and title ~= "") and title or nil, src = opts.src, at = time() }
    if not cfg.queue then wipe(list) end
    if opts.now then table.insert(list, 1, w) else table.insert(list, w) end
    while #list > MAX do table.remove(list) end
    db().last = w
    if cfg.order == "near" and #list > 1 and not opts.now then sortNear(list) end
    local first = list[1] == w
    local g = G()
    if first or not (g.target and g.target.kind == "way") then self:Go()
    else
        changed() -- point ajouté derrière : seul le compteur de l'épingle change
    end
    if not opts.silent then
        local d = self:Distance(w)
        local idx
        for k, v in ipairs(list) do if v == w then idx = k end end
        WK:Print(string.format(T("Point %d : %s (%s %s)"), idx or 1, label(w), self:ZoneName(map), coordsText(w))
            .. (d and (" · " .. string.format(T("%d m"), math.floor(d + 0.5))) or ""))
    end
    return w
end

function M:Remove(w)
    local list = self:List()
    for k, v in ipairs(list) do
        if v == w then
            table.remove(list, k)
            if k == 1 then
                -- (file en pause : le point suivant n'est pas relancé tout seul)
                if list[1] then if not self:IsPaused() then self:Go() end else self:Ended() end
            end
            changed()
            return true
        end
    end
    return false
end
-- en tête de la file et guidé
function M:Focus(w)
    local list = self:List()
    for k, v in ipairs(list) do
        if v == w then table.remove(list, k); table.insert(list, 1, w); self:Go(); return end
    end
end
function M:Rename(w, title)
    w.title = (title and title ~= "") and title or nil
    if self:List()[1] == w then self:Go() else changed() end
end
function M:Clear(quiet)
    wipe(self:List())
    self:Ended()
    changed()
    if not quiet then WK:Print(T("Points /way effacés.")) end
end
function M:Undo()
    local last = db().last
    if last and self:Remove(last) then
        WK:Print(string.format(T("Point retiré : %s"), label(last)))
        db().last = nil
        return
    end
    WK:Print(T("Rien à annuler."))
end
-- File en pause : arrêtée à la main ; plus relancée par une reprise (fin d'un détour, résurrection) tant que le
-- joueur n'en relance pas un point (Add, Focus, clic sur la carte…)
function M.IsPaused(_) return db().paused == true end
function M.Paused(_)
    db().paused = true
    local g = G()
    local p = prevTarget
    prevTarget = nil
    if not g.target then g:Restore(p) end
end
-- arrêt de notre propre guidage (pas une pause)
local function quietStop(g)
    g.quietStop = true
    g:Stop()
    g.quietStop = nil
end
-- file vide : on arrête notre guidage et le guidage d'avant revient
function M:Ended()
    local g = G()
    db().paused = nil
    if g.target and g.target.kind == "way" then quietStop(g) end
    -- guidage d'avant rendu tout de suite (Guide ne relance plus rien de lui-même après un /way)
    local p = prevTarget
    prevTarget = nil
    if not g.target or g.target.kind == "qtour" or g.target.kind == "qtrack" then g:Restore(p) end
end
function M:PrintList()
    local list = self:List()
    if #list == 0 then WK:Print(T("Aucun point /way.")) return end
    local parts = {}
    for k, w in ipairs(list) do parts[#parts + 1] = k .. " " .. label(w) end
    WK:Print(T("Points /way :") .. " " .. table.concat(parts, " · "))
end
-- garder une note de carte (Modules/MapNotes.lua)
function M:ToNote(w)
    local N = WK.modules.MapNotes
    if not N then return end
    N:Save({ map = w.map, x = w.x, y = w.y, title = label(w), icon = "star", color = "accent", mini = true })
    WK:Print(string.format(T("Note de carte ajoutée : %s"), label(w)))
end

-- arrivée (moins de 12 m) : point retiré, le suivant est guidé ; le dernier laisse l'épingle finir (bandeau)
local ticker = CreateFrame("Frame")
ticker.acc = 0
ticker:SetScript("OnUpdate", function(s, el)
    s.acc = s.acc + el
    if s.acc < 0.5 then return end
    s.acc = 0
    local list = WK.DB and M:List()
    local g = G()
    if not (list and list[1] and g.target and g.target.kind == "way" and g.target.way == list[1]) then
        if list and #list == 0 and prevTarget and not g.target then M:Ended() end
        return
    end
    local d = M:Distance(list[1])
    if d and d < 12 then
        local done = table.remove(list, 1)
        if list[1] then
            WK:Print(string.format(T("Arrivé : %s · suivant : %s"), label(done), label(list[1])))
            M:Go()
        else
            changed()
            C_Timer.After(2, function() if #M:List() == 0 then M:Ended() end end)
        end
    end
end)

---------------------------------------------------------------------------
-- Commande /way
---------------------------------------------------------------------------
function M:Command(msg)
    msg = tostring(msg or "")
    local low = msg:lower():gsub("^%s+", ""):gsub("%s+$", "")
    if low == "list" or low == "liste" then return self:PrintList() end
    if low == "reset" or low == "clear" or low == "effacer" or low == "reset all" then return self:Clear() end
    if low == "undo" or low == "annuler" then return self:Undo() end
    if low == "" then
        local map, p = playerMap()
        if not (map and p) then WK:Print(T("Position inconnue pour l'instant.")) return end
        return self:Add(map, p.x, p.y, nil, { src = "me" })
    end
    local w, err = self:Parse(msg)
    if not w then WK:Print(err) return end
    return self:Add(w.map, w.x, w.y, w.title, { src = "cmd" })
end

local function tomtomPresent()
    local fn = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    local ok, loaded = pcall(fn or function() return false end, "TomTom")
    return ok and loaded and true or false
end
M.TomTomPresent = tomtomPresent
-- /way si on la prend (réglage, TomTom absent), /wkway toujours
function M:RegisterCommands()
    local cfg = self:Config()
    local takeWay = cfg.cmd == "way" or (cfg.cmd == "auto" and not tomtomPresent())
    SLASH_WKWAY1 = "/wkway"
    if takeWay then SLASH_WKWAY2 = "/way" end
    SlashCmdList.WKWAY = function(msg) M:Command(msg) end
    self.ownsWay = takeWay
end

---------------------------------------------------------------------------
-- Compatibilité TomTom
---------------------------------------------------------------------------
-- TomTom absent : petit TomTom qui reçoit les points des autres addons (posé à la connexion, si le réglage
-- le permet : les addons le cherchent au moment d'envoyer un point)
local function tomtomEnabled()
    local st = C_AddOns and C_AddOns.GetAddOnEnableState
    if st then
        local ok, v = pcall(st, "TomTom", UnitName and UnitName("player"))
        if not ok then ok, v = pcall(st, nil, "TomTom") end
        if ok and v and v > 0 then return true end
    end
    return false
end
function M.MakeShim(_)
    if _G.TomTom or tomtomEnabled() or not M:Config().tomtomApi then return end
    local shim = { wk = true, version = "WarbandKeeper", waydb = {} }
    local uidN = 0
    local function on() return WK.DB and M:Config().tomtomApi end
    -- AddWaypoint(carte, x, y, { title = …, from = … }) : x, y de 0 à 1
    function shim:AddWaypoint(map, x, y, opts)
        if not on() or not (map and x and y) then return nil end
        opts = type(opts) == "table" and opts or {}
        local w = M:Add(map, x, y, opts.title or opts.desc, { src = "tomtom", silent = opts.silent })
        if not w then return nil end
        -- point déjà dans la file : même identifiant (sinon l'addon qui gardait l'ancien ne pouvait plus le
        -- retirer ni le suivre)
        if w.uid then return w.uid end
        uidN = uidN + 1
        w.uid = { uidN, map, x, y, title = opts.title }
        return w.uid
    end
    -- ancienne forme : AddMFWaypoint(carte, étage, x, y, opts)
    function shim:AddMFWaypoint(map, _, x, y, opts) return self:AddWaypoint(map, x, y, opts) end
    function shim:AddZWaypoint(_, _, x, y, desc) local map = playerMap(); return self:AddWaypoint(map, x / 100, y / 100, { title = desc }) end
    function shim:RemoveWaypoint(uid)
        for _, w in ipairs(M:List()) do if w.uid == uid then M:Remove(w) return true end end
        return false
    end
    function shim:ClearAllWaypoints() if on() then M:Clear(true) end end
    function shim:SetClosestWaypoint()
        if not on() then return end
        local best, bd
        for _, w in ipairs(M:List()) do
            local d = M:Distance(w)
            if d and (not bd or d < bd) then best, bd = w, d end
        end
        if best then M:Focus(best) end
    end
    function shim:SetCrazyArrow(uid)
        for _, w in ipairs(M:List()) do if w.uid == uid then M:Focus(w) return end end
    end
    function shim:WaypointExists(map, x, y, title)
        for _, w in ipairs(M:List()) do
            if w.map == map and math.abs(w.x - x) < 0.0005 and math.abs(w.y - y) < 0.0005 and (not title or w.title == title) then return true end
        end
        return false
    end
    function shim:IsValidWaypoint(uid)
        for _, w in ipairs(M:List()) do if w.uid == uid then return true end end
        return false
    end
    function shim:GetDistanceToWaypoint(uid)
        for _, w in ipairs(M:List()) do if w.uid == uid then return M:Distance(w) end end
        return nil
    end
    function shim:GetKeyArgs(map, x, y, title) return string.format("%s:%s:%s:%s", tostring(map), tostring(x), tostring(y), tostring(title)) end
    _G.TomTom = shim
    M.shim = shim
end
M.TomTomEnabled = tomtomEnabled

-- TomTom installé : ses points suivis aussi par notre guidage (option)
local followHooked
function M:HookTomTom()
    local tt = _G.TomTom
    if followHooked or not tt or tt.wk or type(tt.AddWaypoint) ~= "function" then return end
    followHooked = true
    hooksecurefunc(tt, "AddWaypoint", function(_, map, x, y, opts)
        if not M:Config().followTomTom then return end
        local title = type(opts) == "table" and (opts.title or opts.desc) or nil
        M:Add(map, x, y, title, { src = "tomtom", silent = true })
    end)
end

---------------------------------------------------------------------------
-- Partage au groupe : texte /way (lisible par tous) et message d'addon (ajout en un clic)
---------------------------------------------------------------------------
local function groupChannel()
    if IsInGroup and IsInGroup(LE_PARTY_CATEGORY_INSTANCE or 2) then return "INSTANCE_CHAT" end
    if IsInRaid and IsInRaid() then return "RAID" end
    if IsInGroup and IsInGroup() then return "PARTY" end
    return nil
end
function M:WayText(w)
    local zone = englishName(w.map) or self:ZoneName(w.map)
    return string.format("/way %s %.2f %.2f%s", zone, w.x * 100, w.y * 100, w.title and (" " .. w.title) or "")
end
function M:Share(w)
    local ch = groupChannel()
    if not ch then WK:Print(T("Tu n'es pas en groupe : le texte /way est dans la boîte de discussion.")) end
    local text = self:WayText(w)
    if ch then
        SendChatMessage(text, ch)
        local payload = string.format("%d:%.4f:%.4f:%s", w.map, w.x, w.y, (w.title or ""):gsub("[:|]", " "))
        if C_ChatInfo and C_ChatInfo.SendAddonMessage then pcall(C_ChatInfo.SendAddonMessage, PREFIX, payload, ch) end
    elseif ChatFrame_OpenChat then
        ChatFrame_OpenChat(text)
    end
end

---------------------------------------------------------------------------
-- Liens du chat : « /way … » et « 32.35, 48.55 » cliquables
---------------------------------------------------------------------------
local LINK_COLOR = "|cff71d5ff"
local function esc(s) return (tostring(s or ""):gsub("[:|%[%]]", " ")) end
-- lien « addon:wkway:carte:x:y:nom » (carte 0 = la carte de celui qui clique)
function M:Link(map, x, y, title, text)
    return string.format("%s|Haddon:wkway:%d:%.4f:%.4f:%s|h[%s]|h|r", LINK_COLOR, map or 0, x, y, esc(title), text)
end
local function linkify(msg)
    if type(msg) ~= "string" or msg:find("|H", 1, true) then return msg end
    local changedAny = false
    -- « /way [zone] x y [nom] » jusqu'à la fin du message
    local s = msg:find("/way%s")
    if s then
        local cmd = msg:sub(s)
        local w = M:Parse(cmd:sub(6))
        if w then
            msg = msg:sub(1, s - 1) .. M:Link(w.map, w.x, w.y, w.title, cmd)
            return msg, true
        end
    end
    -- coordonnées seules « 32.35, 48.55 » / « 32,35 48,55 »
    msg = msg:gsub("(%f[%d]%d%d?[%.,]%d+)(%s*[,/ ]%s*)(%d%d?[%.,]%d+%f[^%d])", function(a, sep, b)
        local x, y = tonumber((a:gsub(",", "."))), tonumber((b:gsub(",", ".")))
        if not (x and y) or x > 100 or y > 100 then return nil end
        changedAny = true
        return M:Link(0, x / 100, y / 100, nil, a .. sep .. b)
    end)
    return msg, changedAny
end
M.Linkify = linkify
local CHAT_EVENTS = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID",
    "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_WHISPER",
    "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_CHANNEL", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM" }
local function chatFilter(_, _, msg, ...)
    if not (WK.DB and M:Config().chatLinks) then return false end
    local out, did = linkify(msg)
    if did then return false, out, ... end
    return false
end
-- clic sur un lien : guider (en tête), Maj = ajouter à la file, clic droit = note de carte
function M:OpenLink(data, button)
    local map, x, y, title = data:match("^(%d+):([%d%.]+):([%d%.]+):?(.*)$")
    map, x, y = tonumber(map), tonumber(x), tonumber(y)
    if not (map and x and y) then return end
    if map == 0 then map = playerMap() end
    if not map then WK:Print(T("Position inconnue pour l'instant.")) return end
    title = (title and title:match("%S")) and title or nil
    if button == "RightButton" then return self:ToNote({ map = map, x = x, y = y, title = title }) end
    local shift = IsShiftKeyDown and IsShiftKeyDown()
    self:Add(map, x, y, title, { src = "chat", now = not shift })
end
-- Clic sur nos liens « addon:wkway:… ». SetItemRef n'est JAMAIS remplacé (le jeu entier passerait par du code
-- de l'addon et des actions en combat tapées dans le chat seraient bloquées) : on écoute l'évènement « SetItemRef »
-- que le jeu envoie pour les liens « addon: », et, s'il ne l'envoie pas sur ce client, un hooksecurefunc qui
-- referme la bulle d'objet ouverte pour ce lien inconnu. Un même clic n'est traité qu'une fois.
local lastLink, lastAt = nil, 0
local function onLink(link, button)
    local data = type(link) == "string" and link:match("^addon:wkway:(.*)$")
    if not data then return false end
    local now = GetTime and GetTime() or 0
    if link == lastLink and now - lastAt < 0.3 then return true end
    lastLink, lastAt = link, now
    M:OpenLink(data, button)
    return true
end
local function hookLinks()
    if M.linksHooked then return end
    M.linksHooked = true
    local reg = _G.EventRegistry
    if reg and reg.RegisterCallback then
        pcall(reg.RegisterCallback, reg, "SetItemRef", function(_, link, _, button) onLink(link, button) end, M)
    end
    if _G.hooksecurefunc and _G.SetItemRef then
        _G.hooksecurefunc("SetItemRef", function(link, _, button)
            if onLink(link, button) or (type(link) == "string" and link:find("^addon:wkway:")) then
                local tip = _G.ItemRefTooltip
                if tip and tip.IsShown and tip:IsShown() and tip.Hide then tip:Hide() end
            end
        end)
    end
end

---------------------------------------------------------------------------
-- Évènements
---------------------------------------------------------------------------
WK:On("PLAYER_LOGIN", function()
    M:RegisterCommands()
    M:MakeShim()
    M:HookTomTom()
    hookLinks()
    if ChatFrame_AddMessageEventFilter then
        for _, ev in ipairs(CHAT_EVENTS) do ChatFrame_AddMessageEventFilter(ev, chatFilter) end
    end
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end
    -- file gardée d'une session à l'autre (réglage), reprise un peu après la connexion
    if not M:Config().keep then wipe(M:List()) end
    C_Timer.After(4, function()
        local g = G()
        if #M:List() > 0 and not g.target then M:Go() end
    end)
end)
WK:On("ADDON_LOADED", function(name) if name == "TomTom" then M:HookTomTom() end end)
WK:On("CHAT_MSG_ADDON", function(prefix, msg, _, sender)
    if prefix ~= PREFIX or not M:Config().share then return end
    local me = UnitName and UnitName("player")
    if sender and me and (sender == me or sender:match("^([^%-]+)") == me) then return end
    local map, x, y, title = tostring(msg):match("^(%d+):([%d%.]+):([%d%.]+):?(.*)$")
    map, x, y = tonumber(map), tonumber(x), tonumber(y)
    if not (map and x and y) then return end
    title = (title and title:match("%S")) and title or nil
    local who = sender and sender:match("^([^%-]+)") or "?"
    WK:Print(string.format(T("%s partage un point : %s"), who,
        M:Link(map, x, y, title, (title or coordsText({ x = x, y = y })) .. " · " .. M:ZoneName(map))))
end)
