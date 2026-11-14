local ADDON_NAME, WK = ...
local M = WK:NewModule("Professions")

-- Enregistre les métiers et note les progrès dans le journal.
function M:Store(c, profs)
    local old = c.professions or {}
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
    local inProfSection = false
    for i = 1, GetNumSkillLines() do
        local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
        if isHeader then
            inProfSection = (name == TRADE_SKILLS or name == SECONDARY_SKILLS
                or name == "Métiers" or name == "Compétences secondaires"
                or name == "Professions" or name == "Secondary Skills")
        elseif inProfSection and name then
            profs[name] = { rank = rank, max = maxRank }
        end
    end
    M:Store(c, profs)
end

-- Client moderne : GetProfessions() renvoie jusqu'à 5 index (peuvent être nil).
function M:ScanModern()
    local c = WK.DB:Me()
    local profs = {}
    local p1, p2, arch, fish, cook = GetProfessions()
    for _, idx in pairs({ p1, p2, arch, fish, cook }) do
        local name, _, rank, maxRank = GetProfessionInfo(idx)
        if name then profs[name] = { rank = rank, max = maxRank } end
    end
    M:Store(c, profs)
end

function M:OnLogin() self:Scan() end
WK:On("SKILL_LINES_CHANGED", function() M:Scan() end)
WK:On("TRADE_SKILL_LIST_UPDATE", function() M:Scan() end)

function M:Print()
    for key, c in pairs(WK.DB.global.characters) do
        local parts = {}
        for name, p in pairs(c.professions or {}) do
            table.insert(parts, string.format("%s %d/%d", name, p.rank or 0, p.max or 0))
        end
        table.sort(parts)
        WK:Print(string.format("  %s : %s", key, #parts > 0 and table.concat(parts, ", ") or "-"))
    end
end
