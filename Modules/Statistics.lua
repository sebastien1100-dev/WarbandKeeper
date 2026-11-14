local ADDON_NAME, WK = ...
local M = WK:NewModule("Statistics")

-- Dernière valeur connue d'une série à l'instant t.
local function valueAt(series, t)
    local v
    for _, p in ipairs(series or {}) do
        if p.t <= t then v = p.v else break end
    end
    return v
end

-- Objets suivis = suivis manuellement + objets ayant une règle d'envoi.
function M:TrackedItems()
    local t = {}
    for id in pairs(WK.DB.global.settings.trackedItems) do t[id] = "manual" end
    for key in pairs(WK.DB.global.mail.rules) do
        local id = WK.modules.Rules:SplitKey(key)
        t[id] = t[id] or "mail"
    end
    return t
end

-- Met à jour l'historique des matériaux suivis (total sur le compte) et de la richesse.
function M:UpdateItems()
    if WK.modules.Value then WK.modules.Value:Record() end
    local hist = WK.DB.global.history.items
    local me, key = WK.DB:Me()
    local all = WK.DB.global.history.charItems
    all[key] = all[key] or {}
    local mine = all[key]
    for id in pairs(self:TrackedItems()) do
        hist[id] = hist[id] or {}
        WK.DB:PushHistory(hist[id], WK.modules.Inventory:AccountCount(id))
        -- Le perso connecté est le seul dont le stock change : on enregistre sa part.
        local n = WK.modules.Inventory:CharCount(me, id)
        if n > 0 or mine[id] then
            mine[id] = mine[id] or {}
            WK.DB:PushHistory(mine[id], n)
        end
    end
end

function M:Track(itemID)
    WK.DB.global.settings.trackedItems[itemID] = true
    self:UpdateItems()
    WK:NotifyChanged()
end

function M:Untrack(itemID)
    WK.DB.global.settings.trackedItems[itemID] = nil
    WK:NotifyChanged()
end

-- Or total du compte à un instant t (dernière valeur connue de chaque perso).
function M:AccountGoldAt(t)
    local total = 0
    for _, series in pairs(WK.DB.global.history.gold) do
        total = total + (valueAt(series, t) or 0)
    end
    return total
end

function M:CharGoldAt(key, t)
    return valueAt(WK.DB.global.history.gold[key], t) or 0
end

function M:CharItemAt(key, itemID, t)
    local s = WK.DB.global.history.charItems[key]
    return valueAt(s and s[itemID], t) or 0
end

-- Personnages ayant un historique pour cet objet.
function M:CharsWithItem(itemID)
    local out = {}
    for key, s in pairs(WK.DB.global.history.charItems) do
        if s[itemID] and #s[itemID] > 0 then table.insert(out, key) end
    end
    table.sort(out)
    return out
end

function M:ItemAt(itemID, t)
    return valueAt(WK.DB.global.history.items[itemID], t) or 0
end

-- key = "gold" ou un itemID.
function M:SeriesAt(key, t)
    if key == "gold" then return self:AccountGoldAt(t) end
    if key == "value" then return valueAt(WK.DB.global.history.value, t) or 0 end
    return self:ItemAt(key, t)
end

-- Résumé de l'évolution sur N jours, un point par jour (commande /wk stats).
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
    WK:Print(string.format(WK.T("Évolution sur %d jours : %s"), days, WK:FormatMoney(current - start)))
end
