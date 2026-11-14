local ADDON_NAME, WK = ...
local M = WK:NewModule("Gathering")

-- Métiers de récolte : où trouver chaque ressource et à quel niveau de métier.
-- Les noms des ressources viennent du jeu (itemID) ; les zones sont celles du jeu d'origine
-- (à corriger ici si WoW Forever diffère).

-- Zones (noms français ; traduction anglaise dans Locales/enUS.lua).
local Z = {
    elwynn = "Forêt d'Elwynn", dunmorogh = "Dun Morogh", durotar = "Durotar", mulgore = "Mulgore",
    tirisfal = "Clairières de Tirisfal", teldrassil = "Teldrassil", darkshore = "Sombrivage",
    westfall = "Marche de l'Ouest", lochmodan = "Loch Modan", silverpine = "Forêt des Pins-Argentés",
    barrens = "Les Tarides", redridge = "Les Carmines", duskwood = "Bois de la Pénombre",
    ashenvale = "Orneval", stonetalon = "Les Serres-Rocheuses", hillsbrad = "Contreforts de Hautebrande",
    wetlands = "Les Paluns", arathi = "Hautes-terres d'Arathi", stv = "Vallée de Strangleronce",
    swamp = "Marais des Chagrins", desolace = "Désolace", needles = "Mille pointes",
    dustwallow = "Marécage d'Âprefange", hinterlands = "Les Hinterlands", badlands = "Terres ingrates",
    alterac = "Montagnes d'Alterac", searing = "Gorge des Vents brûlants", feralas = "Feralas",
    tanaris = "Tanaris", azshara = "Azshara", felwood = "Gangrebois", ungoro = "Cratère d'Un'Goro",
    burning = "Steppes ardentes", blasted = "Terres foudroyées", winterspring = "Berceau-de-l'Hiver",
    silithus = "Silithus", wpl = "Maleterres de l'Ouest", epl = "Maleterres de l'Est",
}
M.ZONES = Z

local function zones(...)
    local t = {}
    for _, k in ipairs({ ... }) do table.insert(t, Z[k] or k) end
    return t
end

M.DATA = {
    mining = {
        { id = 2770, req = 1, zones = zones("elwynn", "dunmorogh", "durotar", "mulgore", "tirisfal", "darkshore", "westfall", "lochmodan", "silverpine", "barrens", "redridge") },
        { id = 2771, req = 65, zones = zones("westfall", "lochmodan", "redridge", "duskwood", "silverpine", "barrens", "darkshore", "ashenvale", "stonetalon", "hillsbrad", "wetlands", "needles") },
        { id = 2775, req = 75, zones = zones("redridge", "duskwood", "barrens", "ashenvale", "stonetalon", "hillsbrad", "wetlands") },
        { id = 2772, req = 125, zones = zones("arathi", "stv", "alterac", "desolace", "needles", "dustwallow", "badlands", "swamp", "hillsbrad", "feralas", "stonetalon") },
        { id = 2776, req = 155, zones = zones("arathi", "stv", "desolace", "badlands", "dustwallow", "swamp", "hinterlands", "tanaris", "feralas", "alterac") },
        { id = 3858, req = 175, zones = zones("hinterlands", "badlands", "searing", "tanaris", "feralas", "azshara", "felwood", "ungoro", "burning", "blasted", "stv", "swamp", "wpl") },
        { id = 7911, req = 230, zones = zones("searing", "burning", "ungoro", "azshara", "felwood", "tanaris", "hinterlands", "blasted", "wpl", "epl", "winterspring") },
        { id = 11370, req = 230, zones = zones("searing", "burning") },
        { id = 10620, req = 245, zones = zones("ungoro", "felwood", "azshara", "burning", "searing", "blasted", "winterspring", "silithus", "wpl", "epl", "tanaris") },
        { id = 10620, req = 275, suffix = "filon riche", zones = zones("ungoro", "winterspring", "burning", "epl", "silithus", "azshara", "felwood", "blasted") },
    },
    herb = {
        { id = 2447, req = 1, zones = zones("elwynn", "dunmorogh", "durotar", "mulgore", "tirisfal", "teldrassil", "darkshore", "westfall", "lochmodan", "silverpine", "barrens") },
        { id = 765, req = 1, zones = zones("elwynn", "dunmorogh", "durotar", "mulgore", "tirisfal", "teldrassil", "darkshore", "westfall", "lochmodan", "silverpine", "barrens") },
        { id = 2449, req = 15, zones = zones("elwynn", "dunmorogh", "durotar", "mulgore", "tirisfal", "teldrassil", "darkshore", "westfall", "lochmodan", "silverpine", "barrens") },
        { id = 785, req = 50, zones = zones("westfall", "lochmodan", "darkshore", "barrens", "silverpine", "redridge", "duskwood", "mulgore", "durotar") },
        { id = 2450, req = 70, zones = zones("westfall", "darkshore", "barrens", "silverpine", "redridge", "duskwood", "ashenvale", "stonetalon", "hillsbrad", "lochmodan") },
        { id = 3820, req = 85, zones = zones("wetlands", "darkshore", "westfall", "hillsbrad", "stv", "desolace", "swamp") },
        { id = 2453, req = 100, zones = zones("redridge", "duskwood", "ashenvale", "stonetalon", "hillsbrad", "wetlands", "barrens", "needles", "arathi", "desolace", "stv") },
        { id = 3355, req = 115, zones = zones("arathi", "stv", "stonetalon", "needles", "badlands", "hillsbrad", "wetlands", "ashenvale") },
        { id = 3369, req = 120, zones = zones("duskwood", "wetlands", "arathi", "desolace", "dustwallow") },
        { id = 3356, req = 125, zones = zones("ashenvale", "hillsbrad", "wetlands", "arathi", "stv", "swamp", "needles", "desolace", "stonetalon", "dustwallow", "barrens") },
        { id = 3357, req = 150, zones = zones("arathi", "stv", "swamp", "hinterlands", "dustwallow", "wetlands", "feralas", "ashenvale") },
        { id = 3818, req = 160, zones = zones("stv", "swamp", "dustwallow", "hinterlands", "badlands", "feralas", "needles", "arathi", "alterac") },
        { id = 3821, req = 170, zones = zones("arathi", "stv", "hinterlands", "dustwallow", "feralas", "badlands", "swamp", "tanaris", "azshara", "alterac") },
        { id = 3358, req = 185, zones = zones("arathi", "stv", "hinterlands", "swamp", "dustwallow", "feralas", "azshara", "alterac", "badlands") },
        { id = 3819, req = 195, zones = zones("alterac") },
        { id = 4625, req = 205, zones = zones("searing", "badlands", "blasted", "tanaris", "burning", "ungoro") },
        { id = 8831, req = 210, zones = zones("badlands", "feralas", "tanaris", "hinterlands", "stv", "azshara", "felwood", "searing", "ashenvale") },
        { id = 8836, req = 220, zones = zones("wpl", "epl", "felwood", "feralas") },
        { id = 8838, req = 230, zones = zones("feralas", "hinterlands", "azshara", "felwood", "ungoro", "burning", "wpl", "epl", "silithus", "winterspring") },
        { id = 8839, req = 235, zones = zones("swamp", "ungoro") },
        { id = 8845, req = 245, zones = zones("hinterlands", "feralas", "desolace") },
        { id = 8846, req = 250, zones = zones("felwood", "desolace", "blasted", "ashenvale") },
        { id = 13464, req = 260, zones = zones("feralas", "azshara", "felwood", "ungoro", "burning", "silithus", "epl", "winterspring") },
        { id = 13463, req = 270, zones = zones("ungoro", "felwood", "azshara", "burning", "silithus", "winterspring", "wpl", "epl") },
        { id = 13465, req = 280, zones = zones("azshara", "felwood", "ungoro", "burning", "silithus", "winterspring", "wpl", "epl", "blasted") },
        { id = 13466, req = 285, zones = zones("wpl", "epl", "felwood") },
        { id = 13467, req = 290, zones = zones("winterspring") },
        { id = 13468, req = 300, zones = zones("burning", "epl", "silithus", "winterspring") },
    },
    -- Dépeçage : niveau des monstres (min-max) et cuir obtenu.
    skin = {
        { id = 2318, min = 1, max = 20, zones = zones("elwynn", "dunmorogh", "durotar", "mulgore", "tirisfal", "teldrassil", "darkshore", "westfall", "lochmodan", "silverpine", "barrens", "redridge") },
        { id = 2319, min = 20, max = 30, zones = zones("duskwood", "ashenvale", "stonetalon", "hillsbrad", "wetlands", "barrens", "redridge", "needles") },
        { id = 4234, min = 30, max = 40, zones = zones("arathi", "stv", "desolace", "dustwallow", "alterac", "swamp", "needles", "badlands") },
        { id = 4304, min = 40, max = 50, zones = zones("tanaris", "feralas", "hinterlands", "badlands", "searing", "azshara", "stv") },
        { id = 8170, min = 50, max = 60, zones = zones("ungoro", "felwood", "burning", "winterspring", "wpl", "epl", "silithus", "blasted", "azshara") },
    },
}

local KIND = {
    ["Minage"] = "mining", ["Mining"] = "mining",
    ["Herboristerie"] = "herb", ["Herbalism"] = "herb",
    ["Dépeçage"] = "skin", ["Skinning"] = "skin",
}
function M:Kind(prof) return KIND[prof] end

-- Couleur d'une ressource pour un niveau de métier (comme dans le jeu) :
-- trop bas, orange (jusqu'à +25), jaune (+50), vert (+100), puis gris.
function M:Color(req, rank)
    if rank < req then return "low" end
    if rank < req + 25 then return "optimal" end
    if rank < req + 50 then return "medium" end
    if rank < req + 100 then return "easy" end
    return "trivial"
end

-- Niveau maximal des monstres qu'on peut dépecer avec ce niveau de métier.
function M:SkinMaxLevel(rank)
    if rank < 100 then return math.max(10, math.floor(rank / 5)) end
    return math.floor(rank / 10) + 10
end

function M:SkinColor(tier, rank)
    local maxL = self:SkinMaxLevel(rank)
    if tier.min > maxL then return "low" end
    if tier.max >= maxL and tier.min <= maxL then return "optimal" end
    if tier.max >= maxL - 10 then return "medium" end
    if tier.max >= maxL - 20 then return "easy" end
    return "trivial"
end

-- Lignes à afficher : { id, suffix, req (ou min/max), zones, color, good }, triées par niveau.
function M:Rows(prof, rank)
    local kind = self:Kind(prof)
    if not kind then return nil end
    rank = rank or 0
    local rows = {}
    for _, d in ipairs(self.DATA[kind]) do
        local color = kind == "skin" and self:SkinColor(d, rank) or self:Color(d.req, rank)
        table.insert(rows, { id = d.id, suffix = d.suffix, req = d.req, min = d.min, max = d.max,
            zones = d.zones, color = color, good = color == "optimal" or color == "medium", kind = kind })
    end
    return rows, kind
end

-- Zones conseillées : celles des ressources orange et jaunes, les plus fournies d'abord.
function M:BestZones(rows)
    local score, order = {}, {}
    for _, r in ipairs(rows or {}) do
        if r.good then
            for _, z in ipairs(r.zones) do
                if not score[z] then table.insert(order, z) end
                score[z] = (score[z] or 0) + (r.color == "optimal" and 2 or 1)
            end
        end
    end
    table.sort(order, function(a, b)
        if score[a] ~= score[b] then return score[a] > score[b] end
        return a < b
    end)
    return order, score
end
