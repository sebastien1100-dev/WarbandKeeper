local ADDON_NAME, WK = ...
local M = WK:NewModule("BoatTimes")
local T = function(s) return WK.T(s) end

-- Bateaux et zeppelins sans horaires : ce module ne garde que la fin de traversée (ligne du jeu notée comme
-- prise, Modules/BoatLines.lua), l'infobulle d'un quai (navire et destination) et le format des durées.

-- Durée « 1:05 » ou « 1:02:03 » (aussi utilisée par d'autres bandeaux)
function M.Clock(sec)
    sec = math.max(0, math.floor(sec or 0))
    if sec >= 3600 then return string.format("%d:%02d:%02d", sec / 3600, (sec % 3600) / 60, sec % 60) end
    return string.format("%d:%02d", sec / 60, sec % 60)
end

-- Traversée faite (Modules/Nav.lua) : la ligne du jeu est notée comme prise
function M:Learn(from, to)
    local BL = WK.modules.BoatLines
    return BL and BL:Learn(from, to) or nil
end


-- Lignes de l'infobulle d'un quai : le navire et où il va depuis ce quai
function M:TooltipLines(l, side)
    local out = {}
    if l.game then
        local BL = WK.modules.BoatLines
        local g = l.game
        local s = side == "a" and l.si or l.sj
        table.insert(out, { T(g.vessel or ""), 0.75, 0.75, 0.75 })
        table.insert(out, { string.format(T("Vers %s"), table.concat(BL:Destinations(g, s), " » ")), 1, 1, 1 })
        return out
    end
    local to = side == "a" and l.b or l.a
    table.insert(out, { string.format(T("Vers %s"), to and to[4] or "?"), 1, 1, 1 })
    return out
end
