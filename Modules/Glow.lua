local ADDON_NAME, WK = ...
local M = WK:NewModule("Glow")
local T = function(s) return WK.T(s) end

-- Halo (ancienne « lueur de récolte ») : fait briller l'objet que le jeu désigne pour l'interaction (plante, filon,
-- objet de quête, coffre, flotteur de pêche). Le « soft targeting » du jeu choisit l'objet
-- (unité « softinteract ») et lui donne une plaque de nom : la lueur s'y accroche.
-- Les réglages du jeu modifiés sont gardés à l'activation et rendus à l'arrêt.

local UNIT = "softinteract"
local CATEGORIES = { "herb", "ore", "quest", "chest", "bobber" }
M.CATEGORIES = CATEGORIES
M.LABELS = { herb = "Plantes", ore = "Filons", quest = "Objets de quête", chest = "Coffres", bobber = "Flotteur de pêche" }
local DEFAULT_COLORS = {
    herb = { 0.40, 1.00, 0.42 }, ore = { 1.00, 0.60, 0.18 }, quest = { 1.00, 0.84, 0.15 },
    chest = { 0.45, 0.78, 1.00 }, bobber = { 1.00, 0.45, 0.40 },
}

-- Réglages du jeu nécessaires (valeur voulue) : soft targeting des objets et leur plaque de nom.
local CVARS = {
    SoftTargetInteract = "3",          -- toujours désigner un objet proche
    SoftTargetInteractArc = "2",       -- dans toutes les directions
    SoftTargetNameplateInteract = "1", -- plaque de nom sur l'objet désigné (support de la lueur)
    SoftTargetIconGameObject = "1",    -- sans elle, pas de plaque pour les objets
}

function M:Config()
    local g = WK.DB.global.glow
    g.colors = g.colors or {}
    g.cats = g.cats or {}
    for _, k in ipairs(CATEGORIES) do
        if g.cats[k] == nil then g.cats[k] = true end
        g.colors[k] = g.colors[k] or { unpack(DEFAULT_COLORS[k]) }
    end
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
        local t = string.lower(line.leftText or "")
        if string.find(t, "herboristerie", 1, true) or string.find(t, "herbalism", 1, true) then return "herb" end
        if string.find(t, "minage", 1, true) or string.find(t, "mining", 1, true) then return "ore" end
    end
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
        if i > 1 and string.find(line.leftText or "", "%d+%s*/%s*%d+") then return true end
    end
    return false
end

function M:Classify(unit)
    if not UnitExists or not UnitExists(unit) then return nil end
    if UnitIsGameObject and not UnitIsGameObject(unit) then return nil end
    local name = UnitName(unit) or ""
    if contains(name, BOBBER_WORDS) then return "bobber", name end
    if C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest then
        local ok, related = pcall(C_QuestLog.UnitIsRelatedToActiveQuest, unit)
        if ok and related then return "quest", name end
    end
    if tooltipQuest(unit) then return "quest", name end
    local prof = tooltipProfession(unit)
    if prof then return prof, name end
    if isHerbName(name) then return "herb", name end
    if contains(name, ORE_WORDS) then return "ore", name end
    if contains(name, CHEST_WORDS) then return "chest", name end
    return nil, name
end

-- Le perso a-t-il le métier qui récolte cette catégorie ?
local function hasProfession(cat)
    local c = WK.DB:Me()
    for prof in pairs(c.professions or {}) do
        local kind = WK.modules.Gathering:Kind(prof)
        if (cat == "herb" and kind == "herb") or (cat == "ore" and kind == "mining") then return true end
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
        local inRange = UnitIsInInteractRange and UnitIsInInteractRange(UNIT)
        -- respiration lente hors de portée, plus vive à portée
        local speed = inRange and 4 or 2
        local breath = 0.5 + 0.5 * math.sin(self.t * speed)
        local base = inRange and 0.85 or 0.45
        self.halo:SetSize(size * (0.9 + 0.1 * breath), size * (0.9 + 0.1 * breath))
        self.halo:SetAlpha(math.min(1, (base + 0.15 * breath) * power))
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
                    if ok2 and same then return plate end
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
    if (cat == "herb" or cat == "ore") and g.onlyTrained ~= false and not hasProfession(cat) then return self:Hide() end
    local plate = findPlate()
    if not plate then
        -- la plaque arrive souvent un instant après la désignation : on réessaie quelques fois
        self:Hide()
        self.retry = (self.retry or 0) + 1
        if self.retry <= 8 and C_Timer and C_Timer.After then C_Timer.After(0.15, function() M:Update() end) end
        return
    end
    self.retry = 0
    if not glow then buildGlow() end
    local col = g.colors[cat]
    glow.halo:SetVertexColor(col[1], col[2], col[3])
    glow.ring:SetVertexColor(col[1], col[2], col[3])
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
    WK:Print("  " .. T("réglages du jeu") .. " : " .. table.concat(parts, ", "))
    if WK.unknownEvents and WK.unknownEvents.PLAYER_SOFT_INTERACT_CHANGED then
        WK:Print("  " .. T("ce client ne signale pas l'objet désigné (évènement absent)"))
    end
    local exists = UnitExists and UnitExists(UNIT)
    if not exists then
        WK:Print("  " .. T("aucun objet désigné par le jeu : approche-toi d'un objet et relance la commande"))
        return
    end
    local cat, name = self:Classify(UNIT)
    WK:Print("  " .. T("objet désigné") .. " : " .. tostring(name) .. " · " .. T("catégorie") .. " : " .. (cat and T(M.LABELS[cat]) or T("inconnue (pas de halo)")))
    if cat and not g.cats[cat] then WK:Print("  " .. T("cette catégorie est décochée dans les réglages")) end
    WK:Print("  " .. T("plaque de nom trouvée") .. " : " .. yn(findPlate() ~= nil))
end

-- Les évènements de plaque donnent « nameplateN », jamais « softinteract » : on revérifie à chaque fois.
local function refresh() M.retry = 0; M:Update() end
WK:On("PLAYER_SOFT_INTERACT_CHANGED", refresh)
WK:On("NAME_PLATE_UNIT_ADDED", refresh)
WK:On("NAME_PLATE_UNIT_REMOVED", function() if M.current then refresh() end end)
WK:On("QUEST_LOG_UPDATE", function() if M.current or (UnitExists and UnitExists(UNIT)) then M:Update() end end)
WK:On("PLAYER_REGEN_DISABLED", refresh)
WK:On("PLAYER_REGEN_ENABLED", refresh)
WK:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(1, function()
    local g = M:Config()
    -- certains clients remettent ces réglages à zéro au chargement d'une zone
    if g.enabled and not M:OtherAddonLoaded() then M:ApplyCVars() end
    refresh()
end) end)
