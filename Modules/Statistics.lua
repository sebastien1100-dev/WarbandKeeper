local ADDON_NAME, WK = ...
local M = WK:NewModule("Statistics")

-- Met à jour l'historique des matériaux suivis (total sur le compte).
-- Les objets ayant une règle d'envoi sont suivis automatiquement.
function M:UpdateItems()
    local tracked = {}
    for id in pairs(WK.DB.global.settings.trackedItems) do tracked[id] = true end
    for id in pairs(WK.DB.global.mail.rules) do tracked[id] = true end
    local hist = WK.DB.global.history.items
    for id in pairs(tracked) do
        hist[id] = hist[id] or {}
        WK.DB:PushHistory(hist[id], WK.modules.Inventory:AccountCount(id))
    end
end

-- Or total du compte à un instant t (dernière valeur connue de chaque perso).
function M:AccountGoldAt(t)
    local total = 0
    for _, series in pairs(WK.DB.global.history.gold) do
        local v
        for _, p in ipairs(series) do
            if p.t <= t then v = p.v else break end
        end
        total = total + (v or 0)
    end
    return total
end

-- Résumé de l'évolution sur N jours, un point par jour.
function M:PrintGold(days)
    days = tonumber(days) or 7
    local now = time()
    local start = self:AccountGoldAt(now - days * 86400)
    local current = self:AccountGoldAt(now)
    if start == 0 and current == 0 then WK:Print(WK.L.STATS_NO_DATA) return end
    for d = days, 0, -1 do
        local t = now - d * 86400
        WK:Print(string.format("  %s : %s", date("%d/%m", t), WK:FormatMoney(self:AccountGoldAt(t))))
    end
    WK:Print(string.format("Évolution sur %d jours : %s", days, WK:FormatMoney(current - start)))
end
