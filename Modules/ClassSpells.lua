local ADDON_NAME, WK = ...
local T = function(s) return WK.T(s) end

-- Sorts de classe : ce que chaque perso a à apprendre (maintenant, au prochain niveau, plus tard) et ce que
-- ça coûte. Liste et niveau : Modules/ClassSpellsDB.lua (tables du jeu, généré par tools/gen_classspells.py),
-- noms et rangs relus en jeu (traduits par le jeu). Prix : relevés chez le maître de classe (remise de
-- réputation comprise) et partagés entre les persos de la même classe ; inconnus avant une visite.
-- Sorts connus : relevés sur le perso connecté (IsPlayerSpell), gardés pour les autres persos.
-- Réglages et données : WK.DB.global.classSpells (prices[CLASSE]["nom|rang"] = { coût, niveau },
-- known[perso][sort] = true, skip[perso][nom] = true, alert, panel, autoLearn).
local M = {}
WK.modules.ClassSpells = M

function M:Config()
    local g = WK.DB.global
    g.classSpells = g.classSpells or {}
    local c = g.classSpells
    c.prices = c.prices or {}
    c.known = c.known or {}
    c.skip = c.skip or {}
    if c.alert == nil then c.alert = true end         -- rappel au passage de niveau
    if c.panel == nil then c.panel = true end         -- panneau chez le maître
    if c.autoLearn == nil then c.autoLearn = false end -- tout apprendre à l'ouverture du maître
    return c
end
local function on() return WK:FeatureOn("classes") end

local function charOf(key) return WK.DB.global.characters[key or WK:CharKey()] or {} end
local function classOf(key)
    local c = charOf(key)
    if c.class then return c.class end
    if not key or key == WK:CharKey() then return select(2, UnitClass("player")) end
end

local function subtext(id)
    if C_Spell and C_Spell.GetSpellSubtext then
        local ok, s = pcall(C_Spell.GetSpellSubtext, id)
        if ok and s and s ~= "" then return s end
    end
    if GetSpellSubtext then
        local ok, s = pcall(GetSpellSubtext, id)
        if ok and s and s ~= "" then return s end
    end
    return ""
end

---------------------------------------------------------------------------
-- Catalogue d'une classe : { { id, name, rank, level, talent, icon } } trié par niveau
---------------------------------------------------------------------------
local catalog = {}
function M:Catalog(class)
    if not class then return {} end
    local cat = catalog[class]
    if cat and cat.complete then return cat end
    local raw = WK.ClassSpellsRaw and WK.ClassSpellsRaw[class]
    if not raw then return {} end
    cat = { complete = true }
    for lvl, id, t in raw:gmatch("(%d+),(%d+),(%d)") do
        id = tonumber(id)
        local name, icon = WK.SpellInfo(id)
        if not name then cat.complete = false end
        local level = tonumber(lvl)
        if GetSpellLevelLearned then
            local ok, l = pcall(GetSpellLevelLearned, id)
            if ok and type(l) == "number" and l > 0 then level = l end
        end
        table.insert(cat, { id = id, name = name or ("#" .. id), rank = name and subtext(id) or "", level = level, talent = t == "1", icon = icon })
    end
    table.sort(cat, function(a, b) if a.level ~= b.level then return a.level < b.level end return a.id < b.id end)
    catalog[class] = cat
    return cat
end

function M:Price(class, e)
    local p = self:Config().prices[class]
    local r = p and p[e.name .. "|" .. (e.rank or "")]
    return r and r[1] or nil
end

---------------------------------------------------------------------------
-- Sorts connus
---------------------------------------------------------------------------
local function playerKnows(id)
    return (IsPlayerSpell and IsPlayerSpell(id)) or (IsSpellKnown and IsSpellKnown(id)) or false
end

-- Relève les sorts de classe connus du perso connecté
function M:Record()
    local class = classOf()
    local cfg = self:Config()
    local key = WK:CharKey()
    local set = {}
    for _, e in ipairs(self:Catalog(class)) do
        if playerKnows(e.id) then set[e.id] = true end
    end
    cfg.known[key] = set
end

function M:Known(key, id)
    if (key or WK:CharKey()) == WK:CharKey() then return playerKnows(id) end
    local s = self:Config().known[key]
    return s and s[id] or false
end

---------------------------------------------------------------------------
-- Ce qu'un perso a à apprendre
---------------------------------------------------------------------------
-- { now, next, later, skipped (listes d'entrées + cost), costNow, costNext, costAll, nextLevel, unknownPrice }
function M:ForChar(key)
    key = key or WK:CharKey()
    local class = classOf(key)
    local c = charOf(key)
    local lvl = (key == WK:CharKey() and UnitLevel and UnitLevel("player")) or c.level or 1
    local cfg = self:Config()
    local skip = cfg.skip[key] or {}
    local cat = self:Catalog(class)
    -- sorts de talent : seulement si le perso en connaît un rang (il a le talent)
    local hasName = {}
    for _, e in ipairs(cat) do if self:Known(key, e.id) then hasName[e.name] = true end end
    local r = { now = {}, next = {}, later = {}, skipped = {}, costNow = 0, costNext = 0, costAll = 0, unknownPrice = 0 }
    local nextLevel
    for _, e in ipairs(cat) do
        if not self:Known(key, e.id) and (not e.talent or hasName[e.name]) then
            local cost = self:Price(class, e)
            local item = { id = e.id, name = e.name, rank = e.rank, level = e.level, icon = e.icon, cost = cost, talent = e.talent }
            if skip[e.name] then
                table.insert(r.skipped, item)
            else
                if not cost then r.unknownPrice = r.unknownPrice + 1 end
                r.costAll = r.costAll + (cost or 0)
                if e.level <= lvl then
                    table.insert(r.now, item); r.costNow = r.costNow + (cost or 0)
                elseif not nextLevel or e.level == nextLevel then
                    nextLevel = e.level
                    table.insert(r.next, item); r.costNext = r.costNext + (cost or 0)
                else
                    table.insert(r.later, item)
                end
            end
        end
    end
    r.nextLevel = nextLevel
    r.level = lvl
    -- perso pas connecté depuis l'arrivée de cette fonction : ses sorts connus ne sont pas encore relevés
    r.notRecorded = key ~= WK:CharKey() and not cfg.known[key]
    return r
end

-- Coût par niveau jusqu'au 60 : { [niveau] = coût } (sorts pas écartés)
function M:CostByLevel(key)
    local r = self:ForChar(key)
    local out = {}
    for _, list in ipairs({ r.now, r.next, r.later }) do
        for _, e in ipairs(list) do out[e.level] = (out[e.level] or 0) + (e.cost or 0) end
    end
    return out
end

function M:Skip(key, name, v)
    local cfg = self:Config()
    key = key or WK:CharKey()
    cfg.skip[key] = cfg.skip[key] or {}
    cfg.skip[key][name] = v and true or nil
    self:Changed()
end
function M:Skipped(key, name)
    local s = self:Config().skip[key or WK:CharKey()]
    return s and s[name] or false
end

---------------------------------------------------------------------------
-- Chez le maître de classe
---------------------------------------------------------------------------
local function isClassTrainer()
    if IsTradeskillTrainer and IsTradeskillTrainer() then return false end
    return GetNumTrainerServices ~= nil
end

-- Relève les prix et niveaux de toute la liste du maître (sorts disponibles et futurs)
function M:ReadTrainer()
    if not isClassTrainer() then return end
    local class = classOf()
    local cfg = self:Config()
    cfg.prices[class] = cfg.prices[class] or {}
    local p = cfg.prices[class]
    for i = 1, GetNumTrainerServices() do
        local name, rank, category = GetTrainerServiceInfo(i)
        if name and category ~= "header" then
            local cost = GetTrainerServiceCost and (GetTrainerServiceCost(i)) or nil
            local lvl = GetTrainerServiceLevelReq and GetTrainerServiceLevelReq(i) or nil
            if cost then p[name .. "|" .. (rank or "")] = { cost, lvl } end
        end
    end
end

-- Sorts disponibles chez le maître : { { index, name, rank, cost, skipped } }
function M:TrainerAvailable()
    local out = {}
    if not isClassTrainer() then return out end
    for i = 1, GetNumTrainerServices() do
        local name, rank, category = GetTrainerServiceInfo(i)
        if name and category == "available" then
            table.insert(out, { index = i, name = name, rank = rank or "", cost = GetTrainerServiceCost and (GetTrainerServiceCost(i)) or 0,
                skipped = self:Skipped(nil, name) })
        end
    end
    return out
end

-- Apprend les sorts disponibles pas écartés, les moins chers d'abord, sans dépasser l'or. Renvoie n, coût.
function M:LearnAll()
    if InCombatLockdown and InCombatLockdown() then return 0, 0 end
    local list = {}
    for _, e in ipairs(self:TrainerAvailable()) do if not e.skipped then table.insert(list, e) end end
    table.sort(list, function(a, b) return a.cost < b.cost end)
    local money, pick, spent = GetMoney and GetMoney() or 0, {}, 0
    for _, e in ipairs(list) do
        if spent + e.cost <= money then table.insert(pick, e); spent = spent + e.cost end
    end
    -- du dernier au premier : les numéros des services ne bougent pas
    table.sort(pick, function(a, b) return a.index > b.index end)
    for _, e in ipairs(pick) do if BuyTrainerService then BuyTrainerService(e.index) end end
    return #pick, spent
end

function M:LearnOne(index)
    if InCombatLockdown and InCombatLockdown() then return end
    if BuyTrainerService then BuyTrainerService(index) end
end

---------------------------------------------------------------------------
-- Rappel
---------------------------------------------------------------------------
function M:Money(c)
    if not c then return "?" end
    return WK.FormatMoney and WK:FormatMoney(c) or tostring(c)
end

function M:CheckAlert()
    if not on() then return end
    local cfg = self:Config()
    local r = self:ForChar()
    local n = #r.now
    if not cfg.alert or n == 0 then WK.modules.QoL:ClearRemind("cspells") return end
    local text = string.format(T("Niveau %d : %d sort(s) à apprendre (%s)"), r.level, n,
        r.costNow > 0 and self:Money(r.costNow) or T("prix connus chez le maître"))
    WK.modules.QoL:Remind("cspells", text, 0.30, 0.58, 1.0, nil, {
        action = { label = T("Guider"), ghost = true, onClick = function() WK.modules.Guide:GoTo("trainer") end } })
end

function M:Changed()
    if WK.UI.RefreshClassTrainer then WK.UI:RefreshClassTrainer() end
    WK:NotifyChanged()
end

---------------------------------------------------------------------------
-- Évènements
---------------------------------------------------------------------------
local pending
local function soon(d)
    if pending then return end
    pending = true
    C_Timer.After(d or 1.5, function()
        pending = nil
        local cl = classOf()
        if catalog[cl] and not catalog[cl].complete then catalog[cl] = nil end
        M:Record(); M:CheckAlert(); M:Changed()
    end)
end
WK:On("PLAYER_ENTERING_WORLD", function() soon(5) end)
WK:On("PLAYER_LEVEL_UP", function() soon(2) end)
WK:On("LEARNED_SPELL_IN_TAB", function() soon(0.5) end)
WK:On("SPELLS_CHANGED", function() soon(1) end)
WK:On("TRAINER_SHOW", function()
    if not isClassTrainer() then return end
    M:ReadTrainer()
    if M:Config().autoLearn then C_Timer.After(0.3, function() M:LearnAll() end) end
    M:Changed()
end)
WK:On("TRAINER_UPDATE", function() if isClassTrainer() then M:ReadTrainer(); M:Changed() end end)
