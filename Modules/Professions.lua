local ADDON_NAME, WK = ...
local M = WK:NewModule("Professions")

-- Enregistre les métiers et note les progrès dans le journal.
function M:Store(c, profs, partial)
    local old = c.professions or {}
    -- lecture vide (le jeu n'a pas encore ses données, liste repliée…) : on garde ce qu'on sait
    if next(profs) == nil and next(old) ~= nil then return end
    -- lecture partielle (en-tête des métiers replié dans la fenêtre des compétences) : les métiers pas lus
    -- sont gardés, au lieu de disparaître de la fiche
    if partial then
        for name, o in pairs(old) do if profs[name] == nil then profs[name] = o end end
    end
    for name, p in pairs(profs) do
        local o = old[name]
        if o and (p.rank or 0) > (o.rank or 0) and WK.modules.Journal then
            WK.modules.Journal:Skill(name, o.rank, p.rank)
        end
    end
    c.professions = profs
    WK:NotifyChanged()
end

-- Lecture des métiers via les compétences (API Classic : GetSkillLineInfo).
function M:Scan()
    if GetProfessions and GetProfessionInfo then return self:ScanModern() end
    if not GetNumSkillLines then return end
    local c = WK.DB:Me()
    local profs = {}
    local inProfSection, partial = false, false
    for i = 1, GetNumSkillLines() do
        local name, isHeader, isExpanded, rank, _, _, maxRank = GetSkillLineInfo(i)
        if isHeader then
            inProfSection = (name == TRADE_SKILLS or name == SECONDARY_SKILLS
                or name == "Métiers" or name == "Compétences secondaires"
                or name == "Professions" or name == "Secondary Skills")
            if inProfSection and isExpanded == false then partial = true end
        elseif inProfSection and name then
            profs[name] = { rank = rank, max = maxRank }
        end
    end
    M:Store(c, profs, partial)
end

-- Client moderne : GetProfessions() renvoie jusqu'à 5 index (peuvent être nil).
function M:ScanModern()
    local c = WK.DB:Me()
    local profs = {}
    local p1, p2, arch, fish, cook = GetProfessions()
    for _, idx in pairs({ p1, p2, arch, fish, cook }) do
        local name, icon, rank, maxRank, _, _, skillLine = GetProfessionInfo(idx)
        if name then profs[name] = { rank = rank, max = maxRank, icon = icon, skillLine = skillLine } end
    end
    M:Store(c, profs)
end

-- Sort qui ouvre la fenêtre d'un métier (le minage ouvre la fonte).
local OPEN_SPELL = { ["Minage"] = "Fondre", ["Mining"] = "Smelting" }
function M:OpenSpell(prof) return OPEN_SPELL[prof] or prof end

-- Ouvre la fenêtre du métier du perso connecté par l'API, si le client le permet.
-- Renvoie false si le bouton doit lancer le sort du métier à la place.
function M:OpenDirect(prof)
    local c = WK.DB:Me()
    local p = c.professions and c.professions[prof]
    if p and p.skillLine and C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill then
        local ok = pcall(C_TradeSkillUI.OpenTradeSkill, p.skillLine)
        if ok then return true end
    end
    return false
end

function M:OnLogin() self:Scan() end
-- regroupé : TRADE_SKILL_LIST_UPDATE arrive en rafales quand la fenêtre d'un métier est ouverte
local scanSoon = false
local function soonScan()
    if scanSoon then return end
    scanSoon = true
    _G.C_Timer.After(0.5, function() scanSoon = false; M:Scan() end)
end
WK:On("SKILL_LINES_CHANGED", soonScan)
WK:On("TRADE_SKILL_LIST_UPDATE", soonScan)

function M:Print()
    for key, c in pairs(WK.DB.global.characters) do
        local parts = {}
        for name, p in pairs(c.professions or {}) do
            table.insert(parts, string.format("%s %d/%d", name, p.rank or 0, p.max or 0))
        end
        table.sort(parts)
        WK:Print(string.format("  %s : %s", WK:CharName(c, key), #parts > 0 and table.concat(parts, ", ") or "-"))
    end
end
