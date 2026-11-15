local ADDON_NAME, WK = ...
local M = WK:NewModule("Glow")
local T = function(s) return WK.T(s) end

-- Halo (ancienne « lueur de récolte ») : fait briller l'objet que le jeu désigne pour l'interaction (plante, filon,
-- objet de quête, coffre, flotteur de pêche). Le « soft targeting » du jeu choisit l'objet
-- (unité « softinteract ») et lui donne une plaque de nom : la lueur s'y accroche.
-- Les réglages du jeu modifiés sont gardés à l'activation et rendus à l'arrêt.

local UNIT = "softinteract"
local plain
local CATEGORIES = { "herb", "ore", "skin", "quest", "chest", "bobber", "other" }
M.CATEGORIES = CATEGORIES
M.LABELS = { herb = "Plantes", ore = "Filons", quest = "Objets de quête", chest = "Coffres", bobber = "Flotteur de pêche", other = "Autres objets",
             skin = "Créatures à dépecer" }
local DEFAULT_COLORS = {
    herb = { 0.40, 1.00, 0.42 }, ore = { 1.00, 0.60, 0.18 }, quest = { 1.00, 0.84, 0.15 },
    chest = { 0.45, 0.78, 1.00 }, bobber = { 1.00, 0.45, 0.40 }, other = { 0.92, 0.92, 0.92 },
    skin = { 0.90, 0.58, 0.36 },
}

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
    for _, k in ipairs(CATEGORIES) do
        if g.cats[k] == nil then g.cats[k] = true end
        g.colors[k] = g.colors[k] or { unpack(DEFAULT_COLORS[k]) }
    end
    -- le jeu perd l'objet désigné vers 15 m, quelle que soit la portée demandée
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
local function setCVar(name, value)
    if getCVar(name) == nil then return end -- réglage absent de ce client
    if C_CVar and C_CVar.SetCVar then pcall(C_CVar.SetCVar, name, value)
    elseif SetCVar then pcall(SetCVar, name, value) end
end

function M:ApplyCVars()
    local g = self:Config()
    g.saved = g.saved or {}
    for name, value in pairs(CVARS) do
        if g.saved[name] == nil then g.saved[name] = getCVar(name) end
        setCVar(name, value)
    end
    if g.saved.SoftTargetInteractRange == nil then g.saved.SoftTargetInteractRange = getCVar("SoftTargetInteractRange") end
    setCVar("SoftTargetInteractRange", tostring(g.range or 15))
    if g.saved[PLATE_DIST] == nil then g.saved[PLATE_DIST] = getCVar(PLATE_DIST) end
    local dist = math.max(tonumber(g.saved[PLATE_DIST]) or 0, g.range or 15)
    setCVar(PLATE_DIST, tostring(dist))
end

function M:RestoreCVars()
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
local function cursorCategory(unit)
    if not SetUnitCursorTexture then return nil end
    if not probe then
        probe = UIParent:CreateTexture(nil, "BACKGROUND")
        probe:SetSize(1, 1); probe:SetAlpha(0)
        cursorIDs = {}
        if GetFileIDFromPath then
            for name, cat in pairs(CURSOR_FILES) do
                for _, prefix in ipairs({ "", "Unable" }) do
                    local ok, id = pcall(GetFileIDFromPath, "Interface\\Cursor\\" .. prefix .. name)
                    if ok and id then cursorIDs[id] = cat end
                end
            end
        end
    end
    local ok, has = pcall(SetUnitCursorTexture, probe, unit, nil, true)
    if not ok or not plain(has) then return nil end
    local tex = plain(probe:GetTexture())
    local atlas = probe.GetAtlas and plain(probe:GetAtlas()) or nil
    local shown = tostring(atlas or tex)
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
        -- une créature : seul un cadavre à dépecer reçoit le halo (pas les PNJ ni les joueurs)
        local name = plain(UnitName(unit))
        if not name then return nil end -- nom masqué (donjon, combat) : on ne peut rien en dire
        local ok, dead = pcall(UnitIsDead, unit)
        if ok and plain(dead) == true and skinnable(unit) then return "skin", name end
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
    -- objet utilisable que rien ne range ailleurs
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
-- La lueur
---------------------------------------------------------------------------
local glow -- cadre unique, posé sur la plaque de l'objet désigné
local function buildGlow()
    glow = CreateFrame("Frame", "WarbandKeeperGlow", UIParent)
    glow:SetFrameStrata("BACKGROUND")
    glow:Hide()
    glow.halo = glow:CreateTexture(nil, "ARTWORK")
    glow.halo:SetTexture(WK.UI.MEDIA .. "fxhalo")
    glow.halo:SetBlendMode("ADD")
    glow.halo:SetPoint("CENTER")
    -- colonne de lumière (effet au choix) : son pied est posé sur l'objet
    glow.beam = glow:CreateTexture(nil, "ARTWORK")
    glow.beam:SetTexture(WK.UI.MEDIA .. "fxbeam")
    glow.beam:SetBlendMode("ADD")
    glow.beam:SetPoint("BOTTOM", glow, "CENTER", 0, -6)
    glow.ring = glow:CreateTexture(nil, "OVERLAY")
    glow.ring:SetTexture(WK.UI.MEDIA .. "fxring")
    glow.ring:SetBlendMode("ADD")
    glow.ring:SetPoint("CENTER")
    glow.t = 0
    glow:SetScript("OnUpdate", function(self, elapsed)
        self.t = self.t + elapsed
        local g = M:Config()
        local size = g.size or 110
        local power = (g.intensity or 100) / 100
        local inRange = UnitIsInInteractRange and plain(UnitIsInInteractRange(UNIT))
        -- respiration lente hors de portée, plus vive à portée
        local speed = inRange and 4 or 2
        local breath = 0.5 + 0.5 * math.sin(self.t * speed)
        local base = inRange and 0.85 or 0.45
        -- effet : "halo" (défaut), "beam" (colonne de lumière) ou "both"
        local style = g.style or "halo"
        local beamOn = style == "beam" or style == "both"
        local hs = (style == "beam") and size * 0.55 or size -- avec la colonne seule : une petite lueur au pied
        self.halo:SetSize(hs * (0.9 + 0.1 * breath), hs * (0.9 + 0.1 * breath))
        self.halo:SetAlpha(math.min(1, (base + 0.15 * breath) * power))
        self.beam:SetShown(beamOn)
        if beamOn then
            -- hauteur réglable (en multiples de la taille) ; bien visible même hors de portée
            self.beam:SetSize(size * (0.42 + 0.05 * breath), size * (g.beamHeight or 4.5))
            self.beam:SetAlpha(math.min(1, (math.max(base, 0.7) + 0.1 + 0.2 * breath) * power))
        end
        -- anneau qui s'élargit en boucle quand l'objet est à portée
        if inRange then
            local k = (self.t * 0.8) % 1
            self.ring:SetSize(size * (0.5 + 0.8 * k), size * (0.5 + 0.8 * k))
            self.ring:SetAlpha((1 - k) * 0.8 * power)
            self.ring:Show()
        else
            self.ring:Hide()
        end
    end)
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
            for _, plate in ipairs(plates) do
                local token = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
                if token then
                    local ok2, same = pcall(UnitIsUnit, token, UNIT)
                    if ok2 and plain(same) == true then return plate end
                    -- une plaque d'objet du décor : c'est celle de l'objet désigné
                    if UnitIsGameObject then
                        local ok3, obj = pcall(UnitIsGameObject, token)
                        if ok3 and plain(obj) == true then return plate end
                    end
                end
            end
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
    if not g.enabled or self:OtherAddonLoaded() then return self:Hide() end
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
    glow.halo:SetVertexColor(col[1], col[2], col[3])
    glow.ring:SetVertexColor(col[1], col[2], col[3])
    glow.beam:SetVertexColor(col[1], col[2], col[3])
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
    if g.enabled and not self:OtherAddonLoaded() then self:ApplyCVars() end
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
    WK:Print("  " .. T("plaque de nom trouvée") .. " : " .. yn(findPlate() ~= nil))
end

-- Les évènements de plaque donnent « nameplateN », jamais « softinteract » : on revérifie à chaque fois.
-- Jamais d'erreur dans le chat pour le halo : une valeur masquée par le jeu éteint simplement le halo.
local function refresh() M.retry = 0; if not pcall(M.Update, M) then M:Hide() end end
WK:On("PLAYER_SOFT_INTERACT_CHANGED", refresh)
WK:On("NAME_PLATE_UNIT_ADDED", refresh)
WK:On("NAME_PLATE_UNIT_REMOVED", function() if M.current then refresh() end end)
WK:On("QUEST_LOG_UPDATE", function() if M.current or M.SoftExists() then refresh() end end)
WK:On("PLAYER_REGEN_DISABLED", refresh)
WK:On("PLAYER_REGEN_ENABLED", refresh)
WK:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(1, function()
    local g = M:Config()
    -- certains clients remettent ces réglages à zéro au chargement d'une zone
    if g.enabled and not M:OtherAddonLoaded() then M:ApplyCVars() end
    refresh()
end) end)
