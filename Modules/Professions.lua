local ADDON_NAME, WK = ...
local M = WK:NewModule("Professions")

-- Lecture des métiers via les compétences (API Classic : GetSkillLineInfo).
function M:Scan()
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
    c.professions = profs
end

function M:OnLogin() self:Scan() end
WK:On("SKILL_LINES_CHANGED", function() M:Scan() end)

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
