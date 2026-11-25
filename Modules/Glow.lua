local ADDON_NAME, WK = ...
local M = WK:NewModule("Glow")
local T = function(s) return WK.T(s) end

-- Halo (ancienne « lueur de récolte ») : fait briller l'objet que le jeu désigne pour l'interaction (plante, filon,
-- objet de quête, coffre, flotteur de pêche). Le « soft targeting » du jeu choisit l'objet
-- (unité « softinteract ») et lui donne une plaque de nom : la lueur s'y accroche.
-- Les réglages du jeu modifiés sont gardés à l'activation et rendus à l'arrêt.

local UNIT = "softinteract"
local plain
local CATEGORIES = { "ore", "herb", "quest", "chest", "bobber", "skin", "loot", "giver", "other" }
M.CATEGORIES = CATEGORIES
M.LABELS = { herb = "Plantes", ore = "Filons", quest = "Objets de quête", chest = "Coffres", bobber = "Flotteur de pêche", other = "Autres objets",
             skin = "Créatures à dépecer", loot = "Cadavres avec butin", giver = "Donneurs de quêtes" }
local DEFAULT_COLORS = {
    herb = { 0.40, 1.00, 0.42 }, ore = { 1.00, 0.60, 0.18 }, quest = { 1.00, 0.84, 0.15 },
    chest = { 0.45, 0.78, 1.00 }, bobber = { 1.00, 0.45, 0.40 }, other = { 0.92, 0.92, 0.92 },
    skin = { 0.90, 0.58, 0.36 }, loot = { 0.79, 0.71, 0.93 }, giver = { 1.00, 0.92, 0.40 },
}
M.DEFAULT_COLORS = DEFAULT_COLORS
-- Effets : halo, colonne, les deux, onde, étincelles, viseur (réglage global, ou par catégorie dans g.fx)
M.STYLES = { { "halo", "Halo" }, { "beam", "Colonne" }, { "both", "Halo et colonne" }, { "wave", "Onde" },
             { "spark", "Étincelles" }, { "cross", "Viseur" } }
-- Couleurs de difficulté (comme les métiers) : rouge (compétence trop basse), orange, jaune, vert, gris
M.DIFF_COLORS = { low = { 0.90, 0.33, 0.33 }, optimal = { 1.00, 0.55, 0.15 }, medium = { 1.00, 0.86, 0.20 },
                  easy = { 0.40, 0.85, 0.42 }, trivial = { 0.58, 0.58, 0.58 } }

-- Réglages du jeu nécessaires (valeur voulue) : soft targeting des objets et leur plaque de nom.
local CVARS = {
    SoftTargetInteract = "3",          -- toujours désigner un objet proche
    SoftTargetInteractArc = "2",       -- dans toutes les directions
    SoftTargetNameplateInteract = "1", -- plaque de nom sur l'objet désigné (support de la lueur)
    SoftTargetIconGameObject = "1",    -- sans elle, pas de plaque pour les objets
    SoftTargetInteractOnlyInRange = "0", -- désigner aussi hors de portée de main (sinon : quelques mètres seulement)
    SoftTargetInteractRangeIsHard = "0", -- la portée choisie n'écarte pas ce qui reste utilisable (flotteur…)
}
-- Distance d'affichage des plaques d'objets : au moins la portée du halo (réglage monté, jamais baissé).
local PLATE_DIST = "nameplateGameObjectMaxDistance"

function M:Config()
    local g = WK.DB.global.glow
    g.colors = g.colors or {}
    g.cats = g.cats or {}
    g.fx = g.fx or {}           -- effet propre à une catégorie (absent : effet global)
    g.fxNode = nil              -- forme par filon ou par plante (0.83.0) : retirée
    if g.diffColor == nil then g.diffColor = true end
    if g.info == nil then g.info = true end
    for _, k in ipairs(CATEGORIES) do
        if g.cats[k] == nil then g.cats[k] = (k ~= "other") end
        g.colors[k] = g.colors[k] or { unpack(DEFAULT_COLORS[k]) }
    end
    -- « Autres objets » éclairait le mobilier (chaises…) : décochée une fois par défaut
    if not g.otherOff then g.otherOff = true; g.cats.other = false end
    -- portée du halo : 15 m au plus (le jeu perd l'objet désigné au-delà) ; seul le mode pêche monte à 60 m
    if (g.range or 15) > 15 then g.range = 15 end
    return g
end

-- Lueur (l'addon d'un autre auteur) gère déjà ces réglages : on lui laisse la place.
function M:OtherAddonLoaded()
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    return loaded and loaded("Lueur") and true or false
end

---------------------------------------------------------------------------
-- Réglages du jeu
---------------------------------------------------------------------------
local function getCVar(name)
    if C_CVar and C_CVar.GetCVar then return C_CVar.GetCVar(name) end
    if GetCVar then return GetCVar(name) end
end
-- En combat, le jeu refuse ces réglages (ADDON_ACTION_BLOCKED) : rien n'est changé, tout est repris à la sortie
-- du combat (pendingCVars). Une valeur déjà en place n'est pas réécrite.
local pendingCVars
local function inCombat() return _G.InCombatLockdown and _G.InCombatLockdown() end
local function setCVar(name, value)
    local cur = getCVar(name)
    if cur == nil then return end -- réglage absent de ce client
    if tostring(cur) == tostring(value) then return end
    if inCombat() then return end
    if C_CVar and C_CVar.SetCVar then pcall(C_CVar.SetCVar, name, value)
    elseif SetCVar then pcall(SetCVar, name, value) end
end

function M:ApplyCVars()
    if inCombat() then pendingCVars = "apply" return end
    local g = self:Config()
    g.saved = g.saved or {}
    for name, value in pairs(CVARS) do
        if g.saved[name] == nil then g.saved[name] = getCVar(name) end
        setCVar(name, value)
    end
    if g.saved.SoftTargetInteractRange == nil then g.saved.SoftTargetInteractRange = getCVar("SoftTargetInteractRange") end
    -- pendant que le mode pêche tient la désignation (flotteur au loin) : 60 m ; sinon la portée du halo
    local range = g.range or 15
    local F = WK.modules.Fishing
    if F and F.Config and F:Config().savedSoft then range = math.max(range, 60) end
    setCVar("SoftTargetInteractRange", tostring(range))
    if g.saved[PLATE_DIST] == nil then g.saved[PLATE_DIST] = getCVar(PLATE_DIST) end
    local dist = math.max(tonumber(g.saved[PLATE_DIST]) or 0, g.range or 15)
    setCVar(PLATE_DIST, tostring(dist))
end

function M:RestoreCVars()
    if inCombat() then pendingCVars = "restore" return end
    local g = self:Config()
    for name, value in pairs(g.saved or {}) do
        if value ~= nil then setCVar(name, value) end
    end
    g.saved = nil
end

---------------------------------------------------------------------------
-- Ce qu'est l'objet désigné
---------------------------------------------------------------------------
local CHEST_WORDS = { "coffre", "caisse", "tonneau", "malle", "chest", "crate", "barrel", "footlocker", "strongbox" }
local BOBBER_WORDS = { "flotteur", "bobber" }
-- Mobilier : on peut s'y asseoir, le jeu le désigne, mais il n'a rien à récolter
local SEAT_WORDS = { "chaise", "banc", "tabouret", "fauteuil", "trône", "trone", "siège", "siege", "canapé", "sofa",
                     "chair", "bench", "stool", "throne", "seat", "couch", "pew" }
local ORE_WORDS = { "filon", "gisement", "vein", "deposit" }

-- Noms des plantes = noms des objets qu'elles donnent (dans la langue du client). Le cache
-- d'objets du jeu peut être incomplet au début : la liste se refait tant qu'il en manque.
local herbNames, herbComplete
local function isHerbName(name)
    if not herbComplete then
        herbNames, herbComplete = {}, true
        for _, d in ipairs(WK.modules.Gathering.DATA.herb) do
            local n = WK.GetItemInfo(d.id)
            if n then herbNames[string.lower(n)] = true else herbComplete = false end
        end
    end
    return herbNames[string.lower(name)] == true
end

local function requestHerbItems()
    if not (C_Item and C_Item.RequestLoadItemDataByID) then return end
    for _, d in ipairs(WK.modules.Gathering.DATA.herb) do pcall(C_Item.RequestLoadItemDataByID, d.id) end
end

local function contains(s, words)
    s = string.lower(s or "")
    for _, w in ipairs(words) do
        if string.find(s, w, 1, true) then return true end
    end
    return false
end

-- Métier demandé, lu dans l'infobulle de l'objet (« Herboristerie », « Minage »).
local function tooltipProfession(unit)
    if not (C_TooltipInfo and C_TooltipInfo.GetUnit) then return nil end
    local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
    for _, line in ipairs(data.lines) do
        local t = string.lower(plain(line.leftText) or "")
        if string.find(t, "herboristerie", 1, true) or string.find(t, "herbalism", 1, true) then return "herb" end
        if string.find(t, "minage", 1, true) or string.find(t, "mining", 1, true) then return "ore" end
    end
end

-- Valeur lisible (certaines réponses du jeu sont masquées en combat)
plain = function(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

-- Y a-t-il un objet désigné ? Un objet du décor n'« existe » pas au sens de UnitExists :
-- il faut demander si c'est un objet (UnitIsGameObject).
function M.SoftExists(unit)
    unit = unit or UNIT
    if UnitIsGameObject then
        local ok, obj = pcall(UnitIsGameObject, unit)
        if ok and plain(obj) == true then return true end
    end
    if UnitExists then
        local ok, ex = pcall(UnitExists, unit)
        if ok and plain(ex) == true then return true end
    end
    return false
end

-- Objet de quête d'après son infobulle : le jeu y met le titre et les objectifs de la quête.
local function tooltipQuest(unit)
    if not (C_TooltipInfo and C_TooltipInfo.GetUnit) then return false end
    local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return false end
    local LT = Enum and Enum.TooltipDataLineType or {}
    for i, line in ipairs(data.lines) do
        local ty = line.type
        if ty ~= nil and (ty == LT.QuestTitle or ty == LT.QuestObjective or ty == LT.QuestPlayer) then return true end
        -- repli : une ligne d'objectif « 2/5 … » ou « … : 2/5 » sous le nom
        if i > 1 and string.find(plain(line.leftText) or "", "%d+%s*/%s*%d+") then return true end
    end
    return false
end

-- Curseur que le jeu montrerait sur l'objet (pioche, fleur, « ! » de quête, main…) : il dit
-- ce qu'est l'objet. Le jeu renvoie un numéro de fichier, un chemin ou un nom d'atlas.
local CURSOR_FILES = { -- fichiers Interface\Cursor\ du jeu -> catégorie (false : service, pas de halo)
    Mine = "ore", GatherHerbs = "herb", Fishing = "bobber", Skin = "skin",
    Quest = "quest", QuestRepeatable = "quest", QuestTurnIn = "quest", QuestInteract = "quest",
    Pickup = "chest", LootAll = "chest", PickLock = "chest",
    Interact = "other", Inspect = "other",
    Mail = false, Speak = false, Buy = false, Trainer = false, Taxi = false, Innkeeper = false, Repair = false,
}
local CURSOR_WORDS = { -- dans l'ordre : le premier mot trouvé l'emporte
    { "gather", "herb" }, { "herb", "herb" }, { "mine", "ore" }, { "mining", "ore" }, { "fish", "bobber" }, { "skin", "skin" },
    { "quest", "quest" }, { "lootall", "chest" }, { "pickup", "chest" }, { "picklock", "chest" },
    { "mail", false }, { "speak", false }, { "buy", false }, { "trainer", false }, { "taxi", false },
    { "innkeeper", false }, { "repair", false }, { "stable", false },
    { "interact", "other" }, { "inspect", "other" },
}
local probe, cursorIDs
local turnInIDs = {} -- curseur « rendre une quête » (point d'interrogation)
local lastTurnIn = false
local function cursorCategory(unit)
    lastTurnIn = false
    if not SetUnitCursorTexture then return nil end
    if not probe then
        probe = UIParent:CreateTexture(nil, "BACKGROUND")
        probe:SetSize(1, 1); probe:SetAlpha(0)
        cursorIDs = {}
        if GetFileIDFromPath then
            for name, cat in pairs(CURSOR_FILES) do
                for _, prefix in ipairs({ "", "Unable" }) do
                    local ok, id = pcall(GetFileIDFromPath, "Interface\\Cursor\\" .. prefix .. name)
                    if ok and id then
                        cursorIDs[id] = cat
                        if name == "QuestTurnIn" then turnInIDs[id] = true end
                    end
                end
            end
        end
    end
    local ok, has = pcall(SetUnitCursorTexture, probe, unit, nil, true)
    if not ok or not plain(has) then return nil end
    local tex = plain(probe:GetTexture())
    local atlas = probe.GetAtlas and plain(probe:GetAtlas()) or nil
    local shown = tostring(atlas or tex)
    lastTurnIn = (type(tex) == "number" and turnInIDs[tex]) or string.find(string.lower(shown), "turnin", 1, true) ~= nil
    if type(tex) == "number" and cursorIDs[tex] ~= nil then return cursorIDs[tex], shown end
    for _, src in ipairs({ tex, atlas }) do
        if type(src) == "string" then
            local low = string.lower(src)
            for _, w in ipairs(CURSOR_WORDS) do
                if string.find(low, w[1], 1, true) then return w[2], shown end
            end
        end
    end
    return "other", shown -- le jeu a un curseur pour lui : on peut interagir avec
end
M.CursorCategory = cursorCategory

-- L'objet porte-t-il le nom d'un objectif de quête en cours (« Bois de construction : 0/4 ») ?
local function questObjective(name)
    if not name or name == "" then return false end
    local low = string.lower(name)
    local function match(text)
        text = plain(text)
        return type(text) == "string" and string.find(string.lower(text), low, 1, true) ~= nil
    end
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo and C_QuestLog.GetQuestObjectives then
        local ok, n = pcall(C_QuestLog.GetNumQuestLogEntries)
        for i = 1, (ok and n or 0) do
            local ok2, info = pcall(C_QuestLog.GetInfo, i)
            if ok2 and info and not info.isHeader and info.questID then
                local ok3, objs = pcall(C_QuestLog.GetQuestObjectives, info.questID)
                for _, o in ipairs(ok3 and objs or {}) do
                    if not o.finished and match(o.text) then return true end
                end
            end
        end
    elseif GetNumQuestLogEntries and GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
        for i = 1, GetNumQuestLogEntries() do
            for j = 1, (GetNumQuestLeaderBoards(i) or 0) do
                local text, _, done = GetQuestLogLeaderBoard(j, i)
                if not done and match(text) then return true end
            end
        end
    end
    return false
end

-- Cadavre à dépecer : le jeu l'écrit dans l'infobulle (« Dépeçable ») ou lui donne le curseur du dépeçage.
local function skinnable(unit)
    local cur = cursorCategory(unit)
    if cur == "skin" then return true end
    if not (C_TooltipInfo and C_TooltipInfo.GetUnit) then return false end
    local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return false end
    local want = string.lower(UNIT_SKINNABLE_LEATHER or "")
    for _, line in ipairs(data.lines) do
        local t = string.lower(plain(line.leftText) or "")
        if (want ~= "" and t == want) or string.find(t, "dépeçable", 1, true) or string.find(t, "skinnable", 1, true) then return true end
    end
    return false
end

function M:Classify(unit)
    if not M.SoftExists(unit) then return nil end
    if UnitIsGameObject and plain(UnitIsGameObject(unit)) == false then
        -- une créature : cadavre avec butin, cadavre à dépecer, ou PNJ qui a une quête pour ce perso
        local name = plain(UnitName(unit))
        if not name then return nil end -- nom masqué (donjon, combat) : on ne peut rien en dire
        local okP, isPlayer = pcall(UnitIsPlayer, unit)
        if okP and plain(isPlayer) == true then return nil, name end
        local ok, dead = pcall(UnitIsDead, unit)
        local cur = cursorCategory(unit)
        if ok and plain(dead) == true then
            if cur == "skin" then return "skin", name end
            if cur == "chest" then return "loot", name end -- curseur « tout ramasser »
            if CanLootUnit and UnitGUID then
                local okG, guid = pcall(UnitGUID, unit)
                local okL, has = pcall(CanLootUnit, plain(okG and guid or nil))
                if okL and plain(has) == true then return "loot", name end
            end
            if skinnable(unit) then return "skin", name end
            return nil, name
        end
        -- « seulement ton journal » : PNJ où rendre une quête du journal, ou lié à une quête en cours ;
        -- pas ceux qui proposent une nouvelle quête
        if M:Config().giverLog then
            if cur == "quest" and lastTurnIn then return "giver", name end
            -- une créature hostile liée à une quête est une cible à tuer, pas un donneur
            local okA, hostile = pcall(UnitCanAttack, "player", unit)
            if okA and plain(hostile) == true then return nil, name end
            if C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest then
                local okR, related = pcall(C_QuestLog.UnitIsRelatedToActiveQuest, unit)
                if okR and plain(related) == true then return "giver", name end
            end
            if tooltipQuest(unit) then return "giver", name end
            return nil, name
        end
        if cur == "quest" then return "giver", name end
        local Q = WK.modules.Quests
        local R = WK.modules.Rares
        local id = R and R.NpcID(unit)
        if Q and id then
            local c = WK.DB:Me()
            for _, q in ipairs(Q:ByStarter(id)) do
                if Q:ForChar(q, c) and Q:State(q, c) == "avail" then return "giver", name end
            end
        end
        return nil, name
    end
    -- en donjon ou en combat, le jeu masque le nom : pas de halo plutôt qu'une erreur
    local name = plain(UnitName(unit))
    if not name then return nil end
    if contains(name, BOBBER_WORDS) then return "bobber", name end
    if C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest then
        local ok, related = pcall(C_QuestLog.UnitIsRelatedToActiveQuest, unit)
        if ok and related then return "quest", name end
    end
    if tooltipQuest(unit) or questObjective(name) then return "quest", name end
    local cur = cursorCategory(unit)
    if cur == false then return nil, name end -- boîte aux lettres, PNJ de service : pas de halo
    if cur and cur ~= "other" then return cur, name end
    local prof = tooltipProfession(unit)
    if prof then return prof, name end
    if isHerbName(name) then return "herb", name end
    if contains(name, ORE_WORDS) then return "ore", name end
    if contains(name, CHEST_WORDS) then return "chest", name end
    -- objet utilisable que rien ne range ailleurs, sauf le mobilier (chaises, bancs…)
    if contains(name, SEAT_WORDS) then return nil, name end
    if cur == "other" then return "other", name end
    if UnitIsInteractable then
        local ok, can = pcall(UnitIsInteractable, unit)
        if ok and plain(can) == true then return "other", name end
    end
    return nil, name
end

-- Le perso a-t-il le métier qui récolte cette catégorie ?
local function hasProfession(cat)
    local c = WK.DB:Me()
    for prof in pairs(c.professions or {}) do
        local kind = WK.modules.Gathering:Kind(prof)
        if (cat == "herb" and kind == "herb") or (cat == "ore" and kind == "mining") or (cat == "skin" and kind == "skin") then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- Difficulté de la récolte : compétence demandée et couleur (comme les métiers)
---------------------------------------------------------------------------
-- Filons : nom de l'objet du décor (français ou anglais) -> compétence demandée. Le plus précis d'abord.
local ORE_REQ = {
    { "vrai-argent", 230 }, { "truesilver", 230 }, { "sombrefer", 230 }, { "dark iron", 230 },
    { "riche filon de thorium", 275 }, { "rich thorium", 275 }, { "thorium", 245 },
    { "mithril", 175 }, { "filon d'or", 155 }, { "gold", 155 }, { "fer", 125 }, { "iron", 125 },
    { "argent", 75 }, { "silver", 75 }, { "étain", 65 }, { "etain", 65 }, { "tin", 65 }, { "cuivre", 1 }, { "copper", 1 },
}
local herbReq, herbReqComplete -- refaite tant que des noms de plantes manquent au cache d'objets

-- Effet à utiliser : celui de la catégorie, sinon l'effet global
function M:StyleFor(cat)
    local g = self:Config()
    return g.fx[cat] or g.style or "halo"
end

local function rankOf(kind)
    local G = WK.modules.Gathering
    for prof, p in pairs(WK.DB:Me().professions or {}) do
        if G:Kind(prof) == kind then return p.rank or 0, prof end
    end
end
-- Compétence demandée, métier (nom affiché) et clé de couleur (low, optimal, medium, easy, trivial)
function M:Difficulty(cat, name, unit)
    local G = WK.modules.Gathering
    local req, kind
    if cat == "ore" then
        kind = "mining"
        local low = string.lower(name or "")
        for _, e in ipairs(ORE_REQ) do if string.find(low, e[1], 1, true) then req = e[2] break end end
    elseif cat == "herb" then
        kind = "herb"
        if not herbReqComplete then
            herbReq, herbReqComplete = {}, true
            for _, d in ipairs(G.DATA.herb) do
                local n = WK.GetItemInfo(d.id)
                if n then
                    local low = string.lower(n)
                    if not herbReq[low] or (d.req or 1) < herbReq[low] then herbReq[low] = d.req or 1 end
                else
                    herbReqComplete = false
                end
            end
        end
        req = herbReq[string.lower(name or "")]
    elseif cat == "skin" then
        kind = "skin"
        local ok, lvl = pcall(UnitLevel, unit)
        lvl = ok and plain(lvl) or nil
        if lvl and lvl > 0 then req = lvl <= 10 and 1 or (lvl <= 20 and (lvl - 10) * 10 or lvl * 5) end
    end
    if not req then return nil end
    local rank, prof = rankOf(kind)
    if not rank then return req, nil, "low" end
    return req, prof, G:Color(req, rank)
end

---------------------------------------------------------------------------
-- Effets (le halo en jeu et l'aperçu des réglages utilisent le même dessin)
---------------------------------------------------------------------------
local SPARKS = { { 0.0, 0.42 }, { 1.1, 0.30 }, { 2.0, 0.48 }, { 2.9, 0.26 }, { 3.9, 0.44 }, { 4.8, 0.34 }, { 5.6, 0.50 } }
function M.NewFx(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(1, 1)
    local function tex(file, layer)
        local t = f:CreateTexture(nil, layer or "ARTWORK")
        t:SetTexture(WK.UI.MEDIA .. file)
        t:SetBlendMode("ADD")
        t:SetPoint("CENTER")
        return t
    end
    f.halo = tex("fxhalo")
    f.beam = tex("fxbeam")
    f.beam:ClearAllPoints()
    f.beam:SetPoint("BOTTOM", f, "CENTER", 0, -6) -- pied de la colonne posé sur l'objet
    f.ring = tex("fxring", "OVERLAY")
    f.waves = { tex("fxring", "OVERLAY"), tex("fxring", "OVERLAY"), tex("fxring", "OVERLAY") }
    f.sparks = {}
    for i = 1, #SPARKS do f.sparks[i] = tex("fxspark", "OVERLAY") end
    f.dash = tex("ring_dash", "OVERLAY")
    f.t = 0
    f.style, f.size, f.power, f.beamH = "halo", 110, 1, 4.5
    -- style, couleur {r,g,b}, taille, intensité (1 = 100 %), hauteur de colonne
    function f:Set(style, col, size, power, beamH)
        self.style, self.size, self.power, self.beamH = style or "halo", size or 110, power or 1, beamH or 4.5
        for _, t in ipairs({ self.halo, self.beam, self.ring, self.dash }) do t:SetVertexColor(col[1], col[2], col[3]) end
        for _, t in ipairs(self.waves) do t:SetVertexColor(col[1], col[2], col[3]) end
        for _, t in ipairs(self.sparks) do t:SetVertexColor(col[1], col[2], col[3]) end
    end
    function f:Draw(inRange)
        local t, size, power, style = self.t, self.size, self.power, self.style
        local speed = inRange and 4 or 2
        local breath = 0.5 + 0.5 * math.sin(t * speed)
        local base = inRange and 0.85 or 0.45
        local classic = style == "halo" or style == "beam" or style == "both"
        -- halo : plein pour « halo », petite lueur au pied pour les autres effets
        local hs = style == "halo" and size or (style == "both" and size or size * 0.55)
        local ha = (style == "halo" or style == "both") and 1 or 0.55
        self.halo:SetSize(hs * (0.9 + 0.1 * breath), hs * (0.9 + 0.1 * breath))
        self.halo:SetAlpha(math.min(1, (base + 0.15 * breath) * power * ha))
        local beamOn = style == "beam" or style == "both"
        self.beam:SetShown(beamOn)
        if beamOn then
            self.beam:SetSize(size * (0.42 + 0.05 * breath), size * self.beamH)
            self.beam:SetAlpha(math.min(1, (math.max(base, 0.7) + 0.1 + 0.2 * breath) * power))
        end
        -- anneau qui s'élargit à portée (halo, colonne)
        if classic and inRange then
            local k = (t * 0.8) % 1
            self.ring:SetSize(size * (0.5 + 0.8 * k), size * (0.5 + 0.8 * k))
            self.ring:SetAlpha((1 - k) * 0.8 * power)
            self.ring:Show()
        else
            self.ring:Hide()
        end
        -- onde : trois cercles qui s'élargissent l'un après l'autre
        for i, w in ipairs(self.waves) do
            w:SetShown(style == "wave")
            if style == "wave" then
                local k = (t * (inRange and 0.7 or 0.45) + (i - 1) / 3) % 1
                w:SetSize(size * (0.3 + 1.0 * k), size * (0.3 + 1.0 * k))
                w:SetAlpha((1 - k) * 0.95 * power)
            end
        end
        -- étincelles : petites étoiles qui scintillent en tournant doucement autour de l'objet
        for i, sp in ipairs(self.sparks) do
            sp:SetShown(style == "spark")
            if style == "spark" then
                local e = SPARKS[i]
                local a = e[1] + t * 0.35
                local tw = math.max(0, math.sin(t * (inRange and 3.2 or 2.2) + i * 1.7))
                local r = size * e[2]
                sp:ClearAllPoints()
                sp:SetPoint("CENTER", self, "CENTER", math.cos(a) * r, math.sin(a) * r * 0.6 + size * 0.12)
                local s = size * (0.16 + 0.14 * tw)
                sp:SetSize(s, s)
                sp:SetAlpha(math.min(1, (0.25 + 0.85 * tw) * power))
            end
        end
        -- viseur : anneau en pointillés qui tourne lentement
        self.dash:SetShown(style == "cross")
        if style == "cross" then
            local s = size * (0.7 + 0.05 * breath)
            self.dash:SetSize(s, s)
            if self.dash.SetRotation then self.dash:SetRotation(t * (inRange and 1.2 or 0.6)) end
            self.dash:SetAlpha(math.min(1, (inRange and 1 or 0.75) * power))
        end
    end
    f:SetScript("OnUpdate", function(self, el)
        self.t = self.t + el
        local ir = self.inRangeFn and self.inRangeFn() or self.inRange
        self:Draw(ir)
    end)
    return f
end

---------------------------------------------------------------------------
-- La lueur
---------------------------------------------------------------------------
local glow -- cadre unique, posé sur la plaque de l'objet désigné
local function buildGlow()
    glow = CreateFrame("Frame", "WarbandKeeperGlow", UIParent)
    glow:SetFrameStrata("BACKGROUND")
    glow:SetSize(1, 1)
    glow:Hide()
    glow.fx = M.NewFx(glow)
    glow.fx:SetPoint("CENTER")
    glow.fx.inRangeFn = function() return UnitIsInInteractRange and plain(UnitIsInInteractRange(UNIT)) end
    -- ligne d'info sous l'objet : nom, compétence demandée (couleur de difficulté)
    glow.info = glow:CreateFontString(nil, "OVERLAY")
    glow.info:SetFont(WK.UI.FONT or STANDARD_TEXT_FONT, 11, "OUTLINE")
    glow.info:SetPoint("TOP", glow, "CENTER", 0, -22)
end

-- Plaque de nom de l'objet désigné. Selon le client, la demande directe peut échouer : on
-- cherche alors parmi les plaques affichées celle qui porte la même unité.
local function findPlate()
    if not C_NamePlate then return nil end
    if C_NamePlate.GetNamePlateForUnit then
        local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, UNIT)
        if ok and plate then return plate end
    end
    if C_NamePlate.GetNamePlates and UnitIsUnit then
        local ok, plates = pcall(C_NamePlate.GetNamePlates)
        if ok and type(plates) == "table" then
            local objPlate, objCount = nil, 0
            for _, plate in ipairs(plates) do
                local token = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
                if token then
                    local ok2, same = pcall(UnitIsUnit, token, UNIT)
                    if ok2 and plain(same) == true then return plate end
                    if UnitIsGameObject then
                        local ok3, obj = pcall(UnitIsGameObject, token)
                        if ok3 and plain(obj) == true then objPlate, objCount = plate, objCount + 1 end
                    end
                end
            end
            -- une plaque d'objet du décor n'est celle de l'objet désigné que si elle est la seule (plusieurs
            -- plantes ou filons proches : le halo se posait sur le premier venu)
            if objCount == 1 then return objPlate end
        end
    end
    return nil
end
M.FindPlate = findPlate

function M:Hide()
    if glow then glow:Hide() end
    self.current = nil
end

function M:Update()
    local g = self:Config()
    if not g.enabled or not WK:FeatureOn("halo") or self:OtherAddonLoaded() then return self:Hide() end
    if g.hideInCombat and InCombatLockdown and InCombatLockdown() then return self:Hide() end
    if g.hideInInstance and IsInInstance and select(2, IsInInstance()) ~= "none" and select(2, IsInInstance()) ~= nil then
        return self:Hide()
    end
    local cat, name = self:Classify(UNIT)
    if not cat or not g.cats[cat] then return self:Hide() end
    if (cat == "herb" or cat == "ore" or cat == "skin") and g.onlyTrained ~= false and not hasProfession(cat) then return self:Hide() end
    local plate = findPlate()
    if not plate then
        -- la plaque arrive souvent un instant après la désignation : on réessaie quelques fois
        self:Hide()
        self.retry = (self.retry or 0) + 1
        if self.retry <= 8 and C_Timer and C_Timer.After then C_Timer.After(0.15, function() pcall(M.Update, M) end) end
        return
    end
    self.retry = 0
    if not glow then buildGlow() end
    local col = g.colors[cat]
    -- compétence demandée (filons, plantes, dépeçage) : la couleur de difficulté colore la ligne d'info,
    -- le halo garde la couleur choisie pour la catégorie
    local req, prof, diff = self:Difficulty(cat, name, UNIT)
    local textCol = col
    if req and g.diffColor then textCol = M.DIFF_COLORS[diff] or col end
    glow.fx:Set(self:StyleFor(cat), col, g.size or 110, (g.intensity or 100) / 100, g.beamHeight or 4.5)
    local info
    if g.info then
        if req then info = name .. "  ·  " .. (prof or T(cat == "ore" and "Minage" or cat == "herb" and "Herboristerie" or "Dépeçage")) .. " " .. req
        elseif cat == "giver" then info = name end
    end
    glow.info:SetText(info or "")
    glow.info:SetTextColor(textCol[1], textCol[2], textCol[3])
    glow.info:ClearAllPoints()
    glow.info:SetPoint("TOP", glow, "CENTER", 0, -((g.size or 110) * 0.32))
    glow:ClearAllPoints()
    glow:SetPoint("CENTER", plate, "CENTER", 0, g.offsetY or -45)
    glow:SetSize(1, 1)
    glow:Show()
    self.current = { cat = cat, name = name }
end

-- Activer / désactiver (réglages du jeu compris)
function M:SetEnabled(on)
    local g = self:Config()
    g.enabled = on
    if on and not self:OtherAddonLoaded() then self:ApplyCVars() else self:RestoreCVars(); self:Hide() end
    self:Update()
end

function M:OnLogin()
    requestHerbItems()
    local g = self:Config()
    if g.enabled and WK:FeatureOn("halo") and not self:OtherAddonLoaded() then self:ApplyCVars() end
end

-- Diagnostic (/wk halo) : dit pourquoi le halo s'affiche ou non sur l'objet désigné.
function M:Report()
    local g = self:Config()
    local function yn(v) return v and T("oui") or T("non") end
    WK:Print(T("Halo : diagnostic"))
    WK:Print("  " .. T("activé") .. " : " .. yn(g.enabled) .. " · " .. T("addon Lueur chargé") .. " : " .. yn(self:OtherAddonLoaded()))
    local parts = {}
    for name in pairs(CVARS) do table.insert(parts, name .. "=" .. tostring(getCVar(name))) end
    table.sort(parts)
    table.insert(parts, "SoftTargetInteractRange=" .. tostring(getCVar("SoftTargetInteractRange")))
    table.insert(parts, PLATE_DIST .. "=" .. tostring(getCVar(PLATE_DIST)))
    WK:Print("  " .. T("réglages du jeu") .. " : " .. table.concat(parts, ", "))
    if WK.unknownEvents and WK.unknownEvents.PLAYER_SOFT_INTERACT_CHANGED then
        WK:Print("  " .. T("ce client ne signale pas l'objet désigné (évènement absent)"))
    end
    local function show(fn) if not fn then return "absent" end local ok, v = pcall(fn, UNIT); return ok and tostring(plain(v)) or "erreur" end
    WK:Print("  UnitIsGameObject : " .. show(UnitIsGameObject) .. " · UnitExists : " .. show(UnitExists) .. " · UnitIsDead : " .. show(UnitIsDead) .. " · UnitName : " .. show(UnitName))
    if not M.SoftExists() then
        WK:Print("  " .. T("aucun objet désigné par le jeu : approche-toi d'un objet et relance la commande"))
        return
    end
    local cat, name = self:Classify(UNIT)
    WK:Print("  " .. T("objet désigné") .. " : " .. tostring(name) .. " · " .. T("catégorie") .. " : " .. (cat and T(M.LABELS[cat]) or T("inconnue (pas de halo)")))
    local _, cursor = cursorCategory(UNIT)
    WK:Print("  " .. T("curseur du jeu") .. " : " .. tostring(cursor or (SetUnitCursorTexture and "aucun" or "absent")))
    if cat and not g.cats[cat] then WK:Print("  " .. T("cette catégorie est décochée dans les réglages")) end
    local req, prof, diff = self:Difficulty(cat, name, UNIT)
    if req then WK:Print("  " .. T("compétence demandée") .. " : " .. req .. " · " .. tostring(prof or T("métier non appris")) .. " · " .. tostring(diff)) end
    if cat then WK:Print("  " .. T("effet") .. " : " .. tostring(g.fx[cat] or g.style or "halo")) end
    WK:Print("  " .. T("plaque de nom trouvée") .. " : " .. yn(findPlate() ~= nil))
end

-- Les évènements de plaque donnent « nameplateN », jamais « softinteract » : on revérifie à chaque fois.
-- Jamais d'erreur dans le chat pour le halo : une valeur masquée par le jeu éteint simplement le halo.
local function softGUID()
    if not UnitGUID then return nil end
    local ok, g = pcall(UnitGUID, UNIT)
    return ok and plain(g) or nil
end
local lastGUID, lastAt, queued = nil, 0, false
local function refresh()
    -- relances remises à zéro seulement pour un nouvel objet (sinon chaque évènement relançait une chaîne
    -- de 8 relances)
    local guid = softGUID()
    if guid ~= lastGUID then M.retry = 0 end
    lastGUID, lastAt = guid, GetTime()
    if not pcall(M.Update, M) then M:Hide() end
end
-- Évènements fréquents (plaques, journal de quêtes) : une relecture toutes les 0,25 s au plus
local THROTTLE = 0.25
local function refreshSoon()
    if queued then return end
    local wait = THROTTLE - (GetTime() - lastAt)
    if wait <= 0 or not (C_Timer and C_Timer.After) then return refresh() end
    queued = true
    C_Timer.After(wait, function() queued = false; refresh() end)
end
WK:On("PLAYER_SOFT_INTERACT_CHANGED", refresh)
-- une plaque de plus : rien à refaire si le même objet est déjà éclairé
WK:On("NAME_PLATE_UNIT_ADDED", function()
    if M.current and softGUID() == lastGUID then return end
    refreshSoon()
end)
WK:On("NAME_PLATE_UNIT_REMOVED", function() if M.current then refresh() end end)
WK:On("QUEST_LOG_UPDATE", function() if M.current or M.SoftExists() then refreshSoon() end end)
WK:On("PLAYER_REGEN_DISABLED", refresh)
WK:On("PLAYER_REGEN_ENABLED", function()
    local p = pendingCVars
    pendingCVars = nil
    if p == "apply" then M:ApplyCVars() elseif p == "restore" then M:RestoreCVars() end
    refresh()
end)
WK:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(1, function()
    local g = M:Config()
    -- certains clients remettent ces réglages à zéro au chargement d'une zone
    if g.enabled and WK:FeatureOn("halo") and not M:OtherAddonLoaded() then M:ApplyCVars() end
    refresh()
end) end)

---------------------------------------------------------------------------
-- Barre de nom d'un PNJ ami désigné : le halo allume la plaque de nom de ce qui est désigné (support de la
-- lueur des objets), et le jeu en donnait une aussi aux PNJ amis proches (garde, marchand…) avec une barre de
-- vie. Elle est rendue invisible quand le joueur n'a pas demandé les plaques des PNJ amis.
---------------------------------------------------------------------------
local npcHidden -- plaque rendue invisible (rendue visible au prochain changement)
local function friendlyNpc(unit)
    local function ask(fn)
        if not fn then return nil end
        local ok, v = pcall(fn, unit)
        return ok and plain(v) or nil
    end
    if not ask(_G.UnitExists) then return false end
    if ask(_G.UnitIsGameObject) == true then return false end
    if ask(_G.UnitIsPlayer) == true then return false end
    local atk = _G.UnitCanAttack and select(2, pcall(_G.UnitCanAttack, "player", unit))
    return plain(atk) ~= true
end
function M.HideNpcPlate()
    if npcHidden then pcall(npcHidden.SetAlpha, npcHidden, 1); npcHidden = nil end
    local g = M:Config()
    if not (g.enabled and WK:FeatureOn("halo")) or M:OtherAddonLoaded() then return end
    if getCVar("nameplateShowFriendlyNPCs") == "1" then return end -- plaques des PNJ voulues par le joueur
    if not friendlyNpc(UNIT) then return end
    local plate = findPlate()
    if plate then
        local ok = pcall(plate.SetAlpha, plate, 0)
        if ok then npcHidden = plate end
    end
end
WK:On("PLAYER_SOFT_INTERACT_CHANGED", function() M.HideNpcPlate() end)
WK:On("NAME_PLATE_UNIT_ADDED", function() M.HideNpcPlate() end)
WK:On("NAME_PLATE_UNIT_REMOVED", function() M.HideNpcPlate() end)
