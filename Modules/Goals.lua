local ADDON_NAME, WK = ...
local M = WK:NewModule("Goals")

-- Objectif = une cible sur une série des statistiques :
--   "gold" (or du compte), "value" (richesse totale) ou un itemID (matériau, total du compte).
-- WK.DB.global.goals[clé] = { target = n, created = t }  (or et richesse en cuivre)

local function goals() return WK.DB.global.goals end

function M:Get(key) return goals()[key] end

function M:Set(key, target)
    if not target or target <= 0 then return self:Remove(key) end
    goals()[key] = { target = target, created = time() }
    if type(key) == "number" then WK.modules.Statistics:Track(key) end
    WK:NotifyChanged()
end

function M:Remove(key)
    goals()[key] = nil
    WK:NotifyChanged()
end

-- Valeur actuelle d'une série.
function M:Current(key)
    if key == "gold" then return WK.modules.Value:AccountGold() end
    if key == "value" then return WK.modules.Value:Wealth() end
    return WK.modules.Inventory:AccountCount(key)
end

function M:Label(key)
    if key == "gold" then return WK.T("Or du compte") end
    if key == "value" then return WK.T("Richesse totale") end
    return (WK.UI:ItemInfo(key))
end

function M:IsMoney(key) return key == "gold" or key == "value" end

-- Progression : current, target, ratio (0..1), jours restants estimés (nil si pas de progrès).
function M:Progress(key)
    local g = self:Get(key)
    if not g then return nil end
    local cur = self:Current(key)
    local ratio = g.target > 0 and math.min(1, cur / g.target) or 0
    local days
    if cur < g.target then
        local S = WK.modules.Statistics
        local past = S:SeriesAt(key, time() - 7 * 86400)
        local rate = (cur - past) / 7
        if rate > 0 and past > 0 then days = math.ceil((g.target - cur) / rate) end
    end
    return cur, g.target, ratio, days
end

-- Objectifs triés : les plus proches du but d'abord.
function M:List()
    local out = {}
    for key in pairs(goals()) do
        local cur, target, ratio, days = self:Progress(key)
        table.insert(out, { key = key, current = cur, target = target, ratio = ratio, days = days })
    end
    table.sort(out, function(a, b) return a.ratio > b.ratio end)
    return out
end
