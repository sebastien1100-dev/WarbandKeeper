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
    -- catalogue incomplet (sort au nom pas encore chargé, ou absent de ce client) : seuls les sorts sans nom
    -- sont relus (avant, les ~300 sorts étaient relus à chaque appel, plusieurs fois par seconde)
    if cat then
        local missing = false
        for _, e in ipairs(cat) do
            if e.noName then
                local name, icon = WK.SpellInfo(e.id)
                if name then
                    e.name, e.icon, e.noName = name, icon, nil
                    e.rank = subtext(e.id)
                else
                    missing = true
                end
            end
        end
        cat.complete = not missing
        return cat
    end
    local now = _G.GetTime and _G.GetTime() or 0
    local raw = WK.ClassSpellsRaw and WK.ClassSpellsRaw[class]
    if not raw then return {} end
    cat = { complete = true, at = now }
    for lvl, id, t in raw:gmatch("(%d+),(%d+),(%d)") do
        id = tonumber(id)
        local name, icon = WK.SpellInfo(id)
        if not name then cat.complete = false end
        local level = tonumber(lvl)
        if GetSpellLevelLearned then
            local ok, l = pcall(GetSpellLevelLearned, id)
            if ok and type(l) == "number" and l > 0 then level = l end
        end
        table.insert(cat, { id = id, name = name or ("#" .. id), rank = name and subtext(id) or "", level = level, talent = t == "1", icon = icon,
            noName = not name or nil })
    end
    table.sort(cat, function(a, b) if a.level ~= b.level then return a.level < b.level end return a.id < b.id end)
    catalog[class] = cat
    return cat
end

-- Prix de base (Modules/ClassPricesDB.lua, What's Training) : { [sort] = cuivre }, lu une fois
local basePrice
local function baseOf(id)
    if not basePrice then
        basePrice = {}
        for sid, cost in (WK.ClassBasePrice or ""):gmatch("(%d+):(%d+)") do basePrice[tonumber(sid)] = tonumber(cost) end
    end
    return id and basePrice[id]
end

-- Prix de base médian des sorts d'une classe à un niveau : estimation d'un sort sans prix connu
local levelMedian = {}
local function estimate(class, level)
    local byLvl = levelMedian[class]
    if not byLvl then
        byLvl, levelMedian[class] = {}, {}
        local lists = {}
        for _, e in ipairs(M:Catalog(class)) do
            local b = baseOf(e.id)
            if b then lists[e.level] = lists[e.level] or {}; table.insert(lists[e.level], b) end
        end
        for lvl, l in pairs(lists) do table.sort(l); byLvl[lvl] = l[math.floor((#l + 1) / 2)] end
        levelMedian[class] = byLvl
    end
    for d = 0, 4 do
        local v = byLvl[level - d] or byLvl[level + d]
        if v then return v end
    end
end

-- Prix d'un sort et sa provenance : celui relevé chez le maître (remise comprise, « exact »), sinon le
-- prix de base (« base »), sinon une estimation d'après les sorts du même niveau (« est »)
function M:Price(class, e)
    local p = self:Config().prices[class]
    local r = p and p[e.name .. "|" .. (e.rank or "")]
    if r and r[1] then return r[1], "exact" end
    local b = baseOf(e.id)
    if b then return b, "base" end
    if (e.level or 0) > 1 then
        local v = estimate(class, e.level)
        if v then return v, "est" end
    end
    return nil
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
    -- rang le plus haut connu de chaque sort : le jeu ne dit plus « connu » pour un rang remplacé par le
    -- suivant (auras du paladin…), les rangs en dessous comptent donc comme appris
    local hasName, topKnown = {}, {}
    for _, e in ipairs(cat) do
        if self:Known(key, e.id) then
            hasName[e.name] = true
            if (topKnown[e.name] or 0) < e.level then topKnown[e.name] = e.level end
        end
    end
    local r = { now = {}, next = {}, later = {}, skipped = {}, costNow = 0, costNext = 0, costAll = 0, unknownPrice = 0 }
    local nextLevel
    for _, e in ipairs(cat) do
        local learned = self:Known(key, e.id) or (topKnown[e.name] and e.level < topKnown[e.name])
        if not learned and (not e.talent or hasName[e.name]) then
            local cost, src = self:Price(class, e)
            local item = { id = e.id, name = e.name, rank = e.rank, level = e.level, icon = e.icon, cost = cost, src = src, talent = e.talent }
            if skip[e.name] then
                table.insert(r.skipped, item)
            else
                if not cost then r.unknownPrice = r.unknownPrice + 1 elseif src == "est" then r.estimated = (r.estimated or 0) + 1 end
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
-- Noms des sorts de la classe (catalogue) : un maître d'armes, de familiers ou de monte n'en enseigne aucun
local function classNames()
    local set = {}
    for _, e in ipairs(M:Catalog(classOf())) do
        if e.name and not e.name:find("^#") then set[e.name] = true end
    end
    return set
end
local function isClassTrainer()
    if _G.IsTradeskillTrainer and _G.IsTradeskillTrainer() then return false end
    if not (_G.GetNumTrainerServices and _G.GetTrainerServiceInfo) then return false end
    local set = classNames()
    -- noms des sorts pas encore chargés par le jeu : on ne peut pas trier, on garde l'ancien comportement
    if not next(set) then return true end
    local visible = 0
    for i = 1, _G.GetNumTrainerServices() do
        local name, _, category = _G.GetTrainerServiceInfo(i)
        if name and category ~= "header" then
            visible = visible + 1
            if set[name] then return true end
        end
    end
    -- aucun service visible (filtre de la fenêtre : « indisponible » décoché et rien à apprendre) : on ne
    -- peut pas trier, ancien comportement (pas un maître de métier = maître de classe)
    return visible == 0
end
function M.IsClassTrainer() return isClassTrainer() end

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
-- compétence d'arme (le maître de classe en propose parfois) : jamais dans la liste des sorts
local function weaponName(name)
    local WS = WK.modules.WeaponSkills
    for _, alts in pairs(WS and WS.SKILL_NAMES or {}) do
        for _, a in ipairs(alts) do if a == name then return true end end
    end
    return false
end
-- Services du maître : disponibles (et, avec `later`, ceux de plus haut niveau : `later` = vrai, `level`).
-- Un nom absent du catalogue n'est plus caché (un nom du jeu qui ne correspondait pas au catalogue cachait le
-- sort : le panneau n'avait plus que « Tout apprendre ») ; seules les compétences d'armes sont écartées.
function M:TrainerAvailable(later)
    local out = {}
    if not isClassTrainer() then return out end
    local set = classNames()
    local LR = _G.GetTrainerServiceLevelReq
    for i = 1, _G.GetNumTrainerServices() do
        local name, rank, category = _G.GetTrainerServiceInfo(i)
        if name and (category == "available" or (later and category == "unavailable"))
            and (set[name] or not weaponName(name)) then
            local lvl
            if LR then local ok, v = pcall(LR, i); if ok then lvl = v end end
            table.insert(out, { index = i, name = name, rank = rank or "", later = category ~= "available", level = lvl,
                cost = _G.GetTrainerServiceCost and (_G.GetTrainerServiceCost(i)) or 0,
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

-- name (facultatif) : nom attendu à ce n° ; relu avant l'achat (un double clic rapide, la liste décalée par
-- le sort qui vient d'être appris, achetait sinon un autre sort)
function M:LearnOne(index, name, rank)
    if InCombatLockdown and InCombatLockdown() then return false end
    if name and _G.GetTrainerServiceInfo then
        local cur, curRank = _G.GetTrainerServiceInfo(index)
        if cur ~= name or (rank and (curRank or "") ~= rank) then return false end
    end
    if BuyTrainerService then BuyTrainerService(index) return true end
    return false
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
    if not cfg.alert or n == 0 then return end
    -- dans le chat (les rappels à l'écran ont été retirés) : une fois par niveau et par perso
    cfg.told = cfg.told or {}
    local key = WK:CharKey()
    if cfg.told[key] == r.level then return end
    cfg.told[key] = r.level
    WK:Print(string.format(T("Niveau %d : %d sort(s) à apprendre (%s)"), r.level, n,
        r.costNow > 0 and self:Money(r.costNow) or T("prix connus chez le maître")) .. " " .. T("(/wk guide maitre)"))
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
        -- (catalogue incomplet gardé : Catalog relit lui-même les seuls sorts sans nom ; le vider ici refaisait les
        -- ~300 sorts à chaque changement de forme ou de monture)
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
