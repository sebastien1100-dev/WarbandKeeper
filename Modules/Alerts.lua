local ADDON_NAME, WK = ...
local M = WK:NewModule("Alerts")
local T = function(s) return WK.T(s) end

-- Alertes d'un personnage : { { kind = "bank"|"mail", days = n, text = "..." }, ... }
function M:For(c, key)
    local cfg = WK.DB.global.settings.alerts
    local out = {}
    if not cfg.enabled then return out end
    local now = time()
    -- Banque jamais vue ou pas vue depuis cfg.bankDays jours (persos niveau 10+).
    if (c.level or 0) >= 10 then
        if not c.bankScanned then
            table.insert(out, { kind = "bank", text = T("banque jamais ouverte") })
        else
            local d = math.floor((now - c.bankScanned) / 86400)
            if d >= cfg.bankDays then
                table.insert(out, { kind = "bank", days = d, text = string.format(T("banque vue il y a %d j"), d) })
            end
        end
    end
    -- Courrier qui expire bientôt (les objets reviennent à l'expéditeur ou sont perdus).
    local box = c.mailbox
    if box and (box.count or 0) > 0 and box.expiresAt then
        local d = math.max(0, math.floor((box.expiresAt - now) / 86400))
        if d <= cfg.mailDays then
            table.insert(out, { kind = "mail", days = d,
                text = d == 0 and T("courrier expire aujourd'hui") or string.format(T("courrier expire dans %d j"), d) })
        end
    end
    return out
end

-- Toutes les alertes du compte : { { key, c, alert }, ... }
function M:All()
    local out = {}
    for key, c in pairs(WK.DB.global.characters) do
        for _, a in ipairs(self:For(c, key)) do table.insert(out, { key = key, c = c, alert = a }) end
    end
    table.sort(out, function(a, b) return (a.alert.days or -1) < (b.alert.days or -1) end)
    return out
end

-- Rappel dans le chat quelques secondes après la connexion.
function M:OnLogin()
    C_Timer.After(6, function()
        local all = self:All()
        if #all == 0 then return end
        WK:Print(string.format(T("%d alerte(s) :"), #all))
        for i, e in ipairs(all) do
            if i > 5 then WK:Print("  ..."); break end
            WK:Print(string.format("  %s : %s", e.c.name or e.key, e.alert.text))
        end
    end)
end
