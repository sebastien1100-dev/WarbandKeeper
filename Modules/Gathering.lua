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

-- Niveau des monstres de chaque zone (pour les tuiles « Où aller »).
local LV = {
    elwynn = "1-10", dunmorogh = "1-10", durotar = "1-10", mulgore = "1-10", tirisfal = "1-10", teldrassil = "1-10",
    darkshore = "10-20", westfall = "10-20", lochmodan = "10-20", silverpine = "10-20", barrens = "10-25",
    redridge = "15-25", duskwood = "18-30", ashenvale = "18-30", stonetalon = "15-27", hillsbrad = "20-30",
    wetlands = "20-30", arathi = "30-40", stv = "30-45", swamp = "35-45", desolace = "30-40", needles = "25-35",
    dustwallow = "35-45", hinterlands = "40-50", badlands = "35-45", alterac = "30-40", searing = "43-50",
    feralas = "40-50", tanaris = "40-50", azshara = "45-55", felwood = "48-55", ungoro = "48-55",
    burning = "50-58", blasted = "45-55", winterspring = "53-60", silithus = "55-60", wpl = "51-58", epl = "53-60",
}
M.ZONE_LEVELS = {}
for k, name in pairs(Z) do M.ZONE_LEVELS[name] = LV[k] end

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
    -- règle du jeu : jusqu'à 100, niveau = compétence / 10 + 10 ; au-delà, compétence / 5
    if rank < 100 then return math.floor(rank / 10) + 10 end
    return math.floor(rank / 5)
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

---------------------------------------------------------------------------
-- Aides de métiers (idées de Professions de Naowh, aucun code repris) :
--   rang suivant : un métier au plafond de son rang (75, 150, 225…) le signale une fois ;
--   nouvelles ressources : une montée d'Herboristerie ou de Minage qui débloque une ressource la nomme ;
--   pistage : récolte connue mais pistage des herbes / minerais éteint, rappel en changeant de zone ;
--   infobulle de la minicarte : sous le nom d'une herbe ou d'un filon, la compétence requise et la tienne.
-- Réglages WK.DB.global.gatherHelp (QoL > Carte, carte « Métiers et récolte »).
---------------------------------------------------------------------------
local T = function(s) return WK.T(s) end
local HELP_DEFAULTS = { rankAlert = true, nodeToast = true, trackRemind = true, nodeTip = true }
function M:HelpConfig()
    local g = WK.DB.global
    g.gatherHelp = g.gatherHelp or {}
    local c = g.gatherHelp
    for k, v in pairs(HELP_DEFAULTS) do if c[k] == nil then c[k] = v end end
    c.rankSeen = c.rankSeen or {}
    c.lastRank = c.lastRank or {}
    return c
end
local RANK_CAP = 300
local NEXT_RANK = { [75] = "Compagnon", [150] = "Expert", [225] = "Artisan" }
local function myProfs() return (WK.DB:Me() or {}).professions or {} end
-- compétence du perso pour une sorte de récolte (« herb », « mining »)
function M:SkillFor(kind)
    for name, p in pairs(myProfs()) do
        if KIND[name] == kind and type(p) == "table" then return p.rank or 0, name end
    end
    return nil
end

local function onSkills()
    if not WK.modules.Gathering then return end
    local c = M:HelpConfig()
    for name, p in pairs(myProfs()) do
        if type(p) == "table" and p.rank and p.max then
            -- rang suivant à apprendre chez le maître
            if c.rankAlert and p.max < RANK_CAP and p.rank >= p.max and c.rankSeen[name] ~= p.max then
                c.rankSeen[name] = p.max
                local msg = string.format(T("%s %d/%d : va voir un maître de %s pour apprendre le rang suivant%s."),
                    T(name), p.rank, p.max, T(name):lower(), NEXT_RANK[p.max] and (" (" .. T(NEXT_RANK[p.max]) .. ")") or "")
                WK:Print(msg)
                WK.modules.QoL:Remind("rank" .. name, msg, 1, 0.82, 0.3)
            end
            -- ressources débloquées par cette montée
            local kind = KIND[name]
            local last = c.lastRank[name]
            if c.nodeToast and last and p.rank > last and (kind == "herb" or kind == "mining") then
                local names = {}
                for _, d in ipairs(M.DATA[kind] or {}) do
                    if d.req and d.req > last and d.req <= p.rank then
                        local n = WK.GetItemInfo(d.id)
                        if n then table.insert(names, n .. (d.suffix and (" (" .. T(d.suffix) .. ")") or "")) end
                    end
                end
                if #names > 0 then
                    local msg = string.format(T("%s %d : tu peux maintenant récolter %s."), T(name), p.rank, table.concat(names, ", "))
                    WK:Print(msg)
                    WK.modules.QoL:Remind("nodes" .. name, msg, 0.6, 0.9, 0.5)
                end
            end
            c.lastRank[name] = p.rank
        end
    end
end
WK:On("SKILL_LINES_CHANGED", function() C_Timer.After(0.5, function() pcall(onSkills) end) end)
WK:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(6, function() pcall(onSkills) end) end)

-- Pistage : Découverte d'herbes (2383) / de gisements (2580)
local FIND = { herb = 2383, mining = 2580 }
local function trackingActive()
    if C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo then
        local okn, n = pcall(C_Minimap.GetNumTrackingTypes)
        for i = 1, (okn and n or 0) do
            local ok, info = pcall(C_Minimap.GetTrackingInfo, i)
            if ok and type(info) == "table" and info.active and (info.spellID == 2383 or info.spellID == 2580) then return true end
        end
        return false
    end
    if GetTrackingTexture then
        local tex = GetTrackingTexture()
        return tex ~= nil
    end
    return true
end
local function checkTracking()
    local c = M:HelpConfig()
    if not c.trackRemind then return end
    if (IsInInstance and IsInInstance()) or (IsResting and IsResting()) or (InCombatLockdown and InCombatLockdown()) then return end
    local spell
    for kind, id in pairs(FIND) do
        if M:SkillFor(kind) and IsPlayerSpell and IsPlayerSpell(id) then spell = id break end
    end
    if not spell or trackingActive() then return end
    local name = (WK.SpellInfo and WK.SpellInfo(spell)) or T("pistage")
    WK.modules.QoL:Remind("tracking", string.format(T("Pistage éteint : active « %s » pour voir les ressources sur la minicarte."), name), 1, 0.82, 0.3, true)
end
WK:On("ZONE_CHANGED_NEW_AREA", function() C_Timer.After(4, function() pcall(checkTracking) end) end)

-- Infobulle de la minicarte : compétence requise d'une herbe ou d'un filon, et la tienne (même couleurs que le jeu)
local ORE_WORDS = { -- du plus précis au plus général (« vrai-argent » avant « argent », « sombrefer » avant « fer »)
    { "vrai-argent", 230 }, { "truesilver", 230 }, { "sombrefer", 230 }, { "dark iron", 230 },
    { "thorium", 245 }, { "mithril", 175 }, { "cuivre", 1 }, { "copper", 1 }, { "étain", 65 }, { "tin ", 65 },
    { "argent", 75 }, { "silver", 75 }, { "fer", 125 }, { "iron", 125 }, { "or", 155 }, { "gold", 155 },
}
local herbNames
local function herbReq(name)
    if not herbNames then
        herbNames = {}
        for _, d in ipairs(M.DATA.herb or {}) do
            local n = WK.GetItemInfo(d.id)
            if n then herbNames[n:lower()] = d.req end
        end
        -- noms pas encore chargés : on réessaiera
        if not next(herbNames) then herbNames = nil; return nil end
    end
    return herbNames[name]
end
local function oreReq(name)
    if not (name:find("filon") or name:find("gisement") or name:find("veine") or name:find("vein") or name:find("deposit")) then return nil end
    local riche = name:find("riche") or name:find("rich ")
    for _, w in ipairs(ORE_WORDS) do
        local pat = w[1] == "or" and "%f[%a]or%f[%A]" or w[1]
        if (w[1] == "or" and name:find(pat)) or (w[1] ~= "or" and name:find(pat, 1, true)) then
            if w[2] == 245 and riche then return 275 end
            return w[2]
        end
    end
    return nil
end
local COLORS = { low = { 1, 0.25, 0.25 }, optimal = { 1, 0.5, 0.25 }, medium = { 1, 1, 0 }, easy = { 0.25, 0.75, 0.25 }, trivial = { 0.5, 0.5, 0.5 } }
local function annotate(tt)
    local c = M:HelpConfig()
    if not c.nodeTip or not tt or not tt.NumLines then return end
    local add = {}
    for i = 1, tt:NumLines() do
        local fs = _G[tt:GetName() .. "TextLeft" .. i]
        local txt = fs and fs:GetText()
        if txt and not (issecretvalue and issecretvalue(txt)) then
            local plain = txt:gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
            local req, kind = herbReq(plain), "herb"
            if not req then req, kind = oreReq(plain), "mining" end
            if req then
                local rank, prof = M:SkillFor(kind)
                local label = kind == "herb" and T("Herboristerie") or T("Minage")
                local col = rank and COLORS[M:Color(req, rank)] or { 0.7, 0.7, 0.7 }
                table.insert(add, { string.format("%s %d%s", label, req, rank and string.format(T(" · toi %d"), rank) or ""), col })
            end
        end
    end
    for _, a in ipairs(add) do tt:AddLine(a[1], a[2][1], a[2][2], a[2][3]) end
    if #add > 0 then tt:Show() end
end
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.MinimapMouseover then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.MinimapMouseover, function(tt) if tt == GameTooltip then pcall(annotate, tt) end end)
elseif GameTooltip and GameTooltip.HookScript then
    GameTooltip:HookScript("OnShow", function(tt)
        if tt:GetOwner() == Minimap then pcall(annotate, tt) end
    end)
end
