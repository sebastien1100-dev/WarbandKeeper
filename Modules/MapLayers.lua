local ADDON_NAME, WK = ...
local M = WK:NewModule("MapLayers")
local T = function(s) return WK.T(s) end

-- Lieux utiles sur la carte du monde et la minicarte (QoL > Carte) : services, marchands, maîtres,
-- voyage. Les lieux viennent de Modules/PlacesDB.lua (QuestieDB) ; les bateaux et zeppelins de la
-- liste TRANSPORTS ci-dessous (zeppelins et bateaux gobelins : positions de leurs maîtres dans
-- QuestieDB ; bateaux de l'Alliance : quais relevés à la main, à vérifier en jeu).
-- Dessin : UI/MapLayers.lua (pastilles, tracés des trajets, barre de filtres sur la carte du monde).
-- Réglages : WK.DB.global.mapLayers (map[couche], mini[couche], filtres).

M.FAMILIES = {
    { key = "svc", label = "Services", icon = "mail", color = { 0.45, 0.78, 1.00 } },
    { key = "shop", label = "Marchands", icon = "bag", color = { 1.00, 0.84, 0.15 } },
    { key = "mast", label = "Maîtres", icon = "person", color = { 0.79, 0.71, 0.93 } },
    { key = "trav", label = "Voyage", icon = "map", color = { 0.56, 0.82, 0.54 } },
    { key = "misc", label = "Divers", icon = "spark", color = { 1.00, 0.60, 0.18 } },
}
M.FAMILY = {}
for _, f in ipairs(M.FAMILIES) do M.FAMILY[f.key] = f end

-- Couches : bit de PlacesDB, famille, icône, filtre (« class » : classes concernées, « prof » : métiers du perso)
M.LAYERS = {
    { key = "mail", bit = 1, family = "svc", icon = "mail", label = "Boîtes aux lettres", map = true, mini = true },
    { key = "auction", bit = 2048, family = "svc", icon = "coin", label = "Hôtel des ventes", map = true },
    { key = "bank", bit = 2, family = "svc", icon = "bag", label = "Banque", map = true },
    { key = "inn", bit = 4096, family = "svc", icon = "home", label = "Auberges", map = true },
    { key = "reagent", bit = 32, family = "shop", icon = "spark", label = "Composants", map = true },
    { key = "ammo", bit = 16, family = "shop", icon = "crosshair", label = "Munitions", class = { HUNTER = true } },
    { key = "poison", bit = 64, family = "shop", icon = "filter", label = "Poisons", class = { ROGUE = true } },
    { key = "general", bit = 256, family = "shop", icon = "bag", label = "Fournitures générales" },
    { key = "fishing", bit = 1024, family = "shop", icon = "fish", label = "Fournitures de pêche" },
    { key = "repair", bit = 8, family = "shop", icon = "hammer", label = "Réparation", map = true, mini = true },
    { key = "trainer", bit = 128, family = "mast", icon = "person", label = "Maître de classe", map = true, mini = true, classTrainer = true },
    { key = "prof", bit = 16384, family = "mast", icon = "hammer", label = "Maîtres de métier", map = true, prof = true },
    { key = "stable", bit = 512, family = "mast", icon = "users", label = "Maître des écuries", class = { HUNTER = true } },
    { key = "pet", bit = 65536, family = "mast", icon = "star", label = "Familiers et démons", classTrainer = true },
    { key = "flight", bit = 8192, family = "trav", icon = "griffon", label = "Maîtres de vol", map = true },
    { key = "transport", family = "trav", icon = "boat", label = "Bateaux et zeppelins", map = true, mini = true },
    { key = "battle", bit = 32768, family = "misc", icon = "lfg", label = "Maîtres de guerre" },
}
M.LAYER = {}
for _, l in ipairs(M.LAYERS) do M.LAYER[l.key] = l end

-- Trajets : deux quais (carte, x, y en 0-100, nom), faction ("A", "H" ou nil : tout le monde)
M.TRANSPORTS = {
    { kind = "zeppelin", side = "H", a = { 1411, 50.82, 13.54, "Orgrimmar" }, b = { 1420, 60.74, 58.87, "Fossoyeuse" } },
    { kind = "zeppelin", side = "H", a = { 1411, 50.69, 12.89, "Orgrimmar" }, b = { 1434, 31.43, 29.91, "Grom'gol" } },
    { kind = "zeppelin", side = "H", a = { 1420, 61.78, 59.18, "Fossoyeuse" }, b = { 1434, 31.54, 29.36, "Grom'gol" } },
    { kind = "boat", a = { 1413, 63.54, 38.61, "Cabestan" }, b = { 1434, 26.08, 73.35, "Baie-du-Butin" } },
    { kind = "boat", side = "A", a = { 1437, 5.0, 63.4, "Port de Menethil" }, b = { 1445, 71.5, 56.2, "Theramore" } },
    { kind = "boat", side = "A", a = { 1437, 4.6, 57.1, "Port de Menethil" }, b = { 1439, 32.4, 43.8, "Auberdine" } },
    { kind = "boat", side = "A", a = { 1439, 33.2, 40.1, "Auberdine" }, b = { 1438, 54.9, 96.8, "Rut'theran" } },
}

-- Trajets connus : ceux de la liste + les bateaux appris en les prenant (Modules/Nav.lua)
-- Lignes : celles des fichiers du jeu (Modules/BoatLines.lua : quais, tour, horaires), puis les quais relevés
-- à la main et les bateaux appris en jeu qui n'y sont pas déjà (même quai à 300 m près)
function M:AllTransports()
    local out = {}
    local BL = WK.modules.BoatLines
    local G = WK.modules.Guide
    local game = BL and BL:Pairs() or {}
    for _, r in ipairs(game) do out[#out + 1] = r end
    local function covered(pt)
        if not (BL and G and G.ToWorld and pt) then return false end
        local c, x, y = G.ToWorld(pt[1], pt[2] / 100, pt[3] / 100)
        return c ~= nil and BL:StopNear(c, x, y, 300) ~= nil
    end
    for _, r in ipairs(M.TRANSPORTS) do
        if not (#game > 0 and covered(r.a) and covered(r.b)) then out[#out + 1] = r end
    end
    local Nv = WK.modules.Nav
    for _, b in ipairs(Nv and Nv.Boats and Nv:Boats() or {}) do
        local e = { kind = b.kind or "boat", learned = true, path = b.path,
                    a = { b.a.map, b.a.x, b.a.y, b.a.name }, b = { b.b.map, b.b.x, b.b.y, b.b.name } }
        if not (#game > 0 and covered(e.a) and covered(e.b)) then out[#out + 1] = e end
    end
    return out
end

local DEFAULTS = { myFaction = true, myClass = true, myProfs = true, toolbar = true, size = 18, reveal = true, revealTint = true }
function M:Config()
    local g = WK.DB.global
    g.mapLayers = g.mapLayers or {}
    local c = g.mapLayers
    for k, v in pairs(DEFAULTS) do if c[k] == nil then c[k] = v end end
    c.map = c.map or {}
    c.mini = c.mini or {}
    -- une fois : réparation (carte et minicarte) et maître de classe (minicarte) affichés par défaut
    if not c.v2 then
        c.v2 = true
        c.map.repair, c.mini.repair, c.mini.trainer = true, true, true
    end
    for _, l in ipairs(M.LAYERS) do
        if c.map[l.key] == nil then c.map[l.key] = l.map and true or false end
        if c.mini[l.key] == nil then c.mini[l.key] = l.mini and true or false end
    end
    return c
end

local function factionLetter()
    local f = UnitFactionGroup and UnitFactionGroup("player")
    return f == "Alliance" and "A" or f == "Horde" and "H" or nil
end
local function band(a, b) return WK.modules.Guide.band(a, b) end

-- La couche concerne-t-elle ce lieu et ce perso ? (filtres de faction, de classe, de métier)
function M:Allowed(l, e, cfg, me)
    if cfg.myFaction and e[5] and e[5] ~= me.fac then return false end
    if cfg.myClass then
        if l.class and not l.class[me.class or ""] then return false end
        if l.classTrainer and e[4] and e[4] ~= me.class then return false end
    end
    if l.prof and cfg.myProfs and not (me.profs[e[4] or ""]) then return false end
    return true
end

-- Lieux à dessiner sur une carte : { { e, layer } } (un lieu, une seule couche : la première cochée)
function M:Places(mapID, which)
    local cfg = self:Config()
    local on = cfg[which or "map"]
    local c = WK.DB:Me()
    local me = { fac = factionLetter(), class = c.class, profs = c.professions or {} }
    local out = {}
    for _, e in ipairs((WK.PlacesDB or {})[mapID] or {}) do
        for _, l in ipairs(M.LAYERS) do
            if l.bit and on[l.key] and band(e[3], l.bit) ~= 0 and self:Allowed(l, e, cfg, me) then
                -- même genre de lieu à deux pas (trois banquiers côte à côte) : une seule pastille
                local near = false
                for _, o in ipairs(out) do
                    if o.layer == l and math.abs(o.e[1] - e[1]) < 1.2 and math.abs(o.e[2] - e[2]) < 1.2 then near = true break end
                end
                if not near then table.insert(out, { e = e, layer = l }) end
                break
            end
        end
    end
    return out
end

-- Quais d'une carte : { { x, y, to (nom), kind, other = { carte, x, y } } }
function M:Docks(mapID, which)
    local cfg = self:Config()
    if not cfg[which or "map"].transport then return {} end
    local fac = factionLetter()
    local out = {}
    for _, r in ipairs(M:AllTransports()) do
        if not (cfg.myFaction and r.side and r.side ~= fac) then
            if r.a[1] == mapID then table.insert(out, { x = r.a[2], y = r.a[3], to = r.b[4], kind = r.kind, other = r.b, here = r.a, path = r.path, line = r, side = "a" }) end
            -- ligne du jeu à plus de 2 quais : le bateau qui part du quai b va au quai suivant, pas à a
            local loop = r.game and r.game.stops and #r.game.stops > 2
            if r.b[1] == mapID and not loop then table.insert(out, { x = r.b[2], y = r.b[3], to = r.a[4], kind = r.kind, other = r.a, here = r.b, path = r.path, line = r, side = "b" }) end
        end
    end
    return out
end

-- Direction d'un quai vers sa destination, à l'écran (dx vers l'est, dy vers le bas), normalisée
function M:Heading(here, other)
    local G = WK.modules.Guide
    local R = WK.modules.Rares
    local c1, n1, w1 = G.ToWorld(here[1], here[2] / 100, here[3] / 100)
    local c2, n2, w2 = G.ToWorld(other[1], other[2] / 100, other[3] / 100)
    if c1 and c2 and c1 == c2 and n1 and n2 then
        local dx, dy = -(w2 - w1), -(n2 - n1)
        local d = math.sqrt(dx * dx + dy * dy)
        if d > 0 then return dx / d, dy / d end
    end
    -- autre continent : Kalimdor (instance 1, carte 1414) est à l'ouest des Royaumes de l'Est
    local kal = c1 == 1
    if c1 == nil then
        local ok, k1 = pcall(R.Continent, R, here[1])
        kal = ok and k1 == 1414
    end
    return kal and 1 or -1, 0
end

-- Guidage vers un lieu de la carte
function M:GuideTo(mapID, e, label)
    local G = WK.modules.Guide
    local t = { map = mapID, x = e[1] / 100, y = e[2] / 100, e = e }
    t.cont, t.wx, t.wy = G.ToWorld(mapID, t.x, t.y)
    local p = G:PlayerPos()
    t.distance = p and G:Vector(p, t) or nil
    G:Start(t, label or "Carte", "place")
end
