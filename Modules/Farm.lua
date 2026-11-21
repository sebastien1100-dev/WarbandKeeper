local ADDON_NAME, WK = ...
local M = WK:NewModule("Farm")
local T = function(s) return WK.T(s) end

-- Session de farm : chrono, or ramassé, butin et valeur marchande estimée.
-- Les gains pendant une interaction (courrier, banque, marchand, échange, hôtel des ventes)
-- ne comptent pas comme du butin.
local MAX_HISTORY = 50
local busy = {}

local function farm() return WK.DB.global.farm end
function M:Current() return farm().current end
function M:Active() return farm().current ~= nil end

-- fenêtre fermée depuis moins de 3 s : encore « occupé » (le relevé des sacs arrive 0,5 s après BAG_UPDATE ; un
-- courrier relevé puis fermé tout de suite était sinon compté comme butin de farm)
local closedAt = -10
local function interacting()
    if next(busy) ~= nil then return true end
    local now = _G.GetTime and _G.GetTime() or 0
    return now - closedAt < 3 and now >= closedAt
end
local function setBusy(key, on)
    if not on and busy[key] then closedAt = _G.GetTime and _G.GetTime() or 0 end
    busy[key] = on or nil
end
for _, pair in ipairs({
    { "MAIL_SHOW", "MAIL_CLOSED", "mail" }, { "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "bank" },
    { "MERCHANT_SHOW", "MERCHANT_CLOSED", "merchant" }, { "TRADE_SHOW", "TRADE_CLOSED", "trade" },
    { "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "ah" },
}) do
    WK:On(pair[1], function() setBusy(pair[3], true) end)
    WK:On(pair[2], function() setBusy(pair[3], false) end)
end

-- Sécurité : si un événement de fermeture a été manqué, on repart de zéro à chaque chargement.
WK:On("PLAYER_ENTERING_WORLD", function() wipe(busy) end)

-- Durée écoulée (pauses exclues), en secondes.
function M:Elapsed(s)
    s = s or self:Current()
    if not s then return 0 end
    if s.duration then return s.duration end -- session terminée
    local run = (s.paused or not s.resumedAt) and 0 or (time() - s.resumedAt)
    return (s.acc or 0) + run
end

function M:Start()
    if self:Active() or not WK:FeatureOn("farm") then return end
    farm().current = {
        start = time(), resumedAt = time(), acc = 0, paused = false,
        char = WK:CharKey(), zone = GetRealZoneText and GetRealZoneText() or "",
        gold = 0, items = {},
    }
    WK:Print(T("Session de farm démarrée."))
    if WK.modules.Loot then WK.modules.Loot:CheckAuto() end
    self:UpdateMini()
    WK:NotifyChanged()
end

function M:TogglePause()
    local s = self:Current()
    if not s then return end
    if s.paused then
        s.paused = false
        s.resumedAt = time()
    else
        s.acc = self:Elapsed(s)
        s.paused = true
    end
    self:UpdateMini()
    WK:NotifyChanged()
end

-- Valeur du butin : prix HV relevé par le scan si disponible, sinon prix marchand.
function M:VendorValue(items)
    return WK.modules.Value:ValueOf(items)
end

function M:ItemCount(items)
    local n = 0
    for _, k in pairs(items) do n = n + k end
    return n
end

function M:Stop()
    local s = self:Current()
    if not s then return end
    s.duration = self:Elapsed(s)
    s.stop = time()
    s.paused, s.resumedAt, s.acc = nil, nil, nil
    farm().current = nil
    if WK.modules.Loot then C_Timer.After(0, function() WK.modules.Loot:CheckAuto() end) end
    if s.duration >= 60 or s.gold > 0 or next(s.items) then
        table.insert(farm().history, 1, s)
        while #farm().history > MAX_HISTORY do table.remove(farm().history) end
        if WK.modules.Journal then WK.modules.Journal:Farm(s) end
        WK:Print(string.format(T("Session terminée : %s, %s, %d objet(s)."),
            WK:FormatTime(s.duration), WK:FormatMoney(s.gold), self:ItemCount(s.items)))
    end
    self:UpdateMini()
    WK:NotifyChanged()
end

-- Classement des spots : sessions terminées regroupées par zone, or/h recalculé au prix actuel
-- (or ramassé + valeur du butin). Chaque spot ressemble à une session (pour l'afficher pareil).
function M:Spots()
    local byZone = {}
    for _, h in ipairs(farm().history) do
        local z = (h.zone and h.zone ~= "") and h.zone or "?"
        local s = byZone[z]
        if not s then
            s = { zone = z, spot = true, sessions = 0, duration = 0, gold = 0, items = {}, start = h.start, chars = {} }
            byZone[z] = s
        end
        s.sessions = s.sessions + 1
        s.duration = s.duration + (h.duration or 0)
        s.gold = s.gold + (h.gold or 0)
        for id, n in pairs(h.items or {}) do s.items[id] = (s.items[id] or 0) + n end
        if h.start > s.start then s.start = h.start end
        s.chars[h.char] = true
        -- Meilleure session de la zone (or/h)
        local rate = self:PerHour((h.gold or 0) + self:VendorValue(h.items), h)
        if not s.bestRate or rate > s.bestRate then s.bestRate, s.char = rate, h.char end
    end
    local list = {}
    for _, s in pairs(byZone) do
        s.rate = self:PerHour(s.gold + self:VendorValue(s.items), s)
        table.insert(list, s)
    end
    table.sort(list, function(a, b) return a.rate > b.rate end)
    return list
end

-- Meilleur spot des N derniers jours (sessions terminées regroupées par zone) : zone et total/h.
function M:BestSpot(days)
    local since = time() - (days or 7) * 86400
    local byZone = {}
    for _, h in ipairs(farm().history) do
        if (h.stop or h.start or 0) >= since and (h.duration or 0) >= 300 then
            local z = (h.zone and h.zone ~= "") and h.zone or "?"
            local s = byZone[z] or { zone = z, duration = 0, value = 0 }
            s.duration = s.duration + h.duration
            s.value = s.value + (h.gold or 0) + self:VendorValue(h.items or {})
            byZone[z] = s
        end
    end
    local best
    for _, s in pairs(byZone) do
        s.rate = s.value * 3600 / s.duration
        if not best or s.rate > best.rate then best = s end
    end
    return best
end

function M:Toggle()
    if self:Active() then self:Stop() else self:Start() end
end

-- Or par heure (or ramassé + valeur marchande si withVendor).
function M:PerHour(amount, s)
    local d = self:Elapsed(s)
    if d < 60 then return 0 end
    return amount * 3600 / d
end

-- Appelé par l'inventaire à chaque scan des sacs : les hausses comptent comme butin.
function M:OnBags(old, new)
    local s = self:Current()
    if not s or s.paused or s.char ~= WK:CharKey() or interacting() or not old or not WK:FeatureOn("farm") then return end
    for id, n in pairs(new) do
        local diff = n - (old[id] or 0)
        if diff > 0 then s.items[id] = (s.items[id] or 0) + diff end
    end
    s.tick = time()
    WK:NotifyChanged()
end

-- Appelé à chaque variation d'or.
function M:OnMoney(delta)
    local s = self:Current()
    if not s or s.paused or s.char ~= WK:CharKey() or interacting() or delta <= 0 or not WK:FeatureOn("farm") then return end
    s.gold = s.gold + delta
    s.tick = time()
end

-- Dernière activité connue d'une session en cours (pour une déconnexion brutale).
function M:Tick()
    local s = self:Current()
    if s and not s.paused then s.tick = time() end
end

function M:OnLogin()
    -- Une session restée en cours (crash, déconnexion) reprend en pause, avec le temps
    -- compté jusqu'à la dernière activité connue.
    local s = self:Current()
    if s and not s.paused then
        local last = math.max(s.tick or s.resumedAt or 0, s.resumedAt or 0)
        s.acc = (s.acc or 0) + math.max(0, last - (s.resumedAt or last))
        s.paused = true
    end
    self:UpdateMini()
end

WK:On("PLAYER_LOGOUT", function()
    local s = M:Current()
    if s and not s.paused then s.acc = M:Elapsed(s); s.paused = true end
end)

function M:UpdateMini()
    if WK.UI and WK.UI.UpdateFarmMini then WK.UI:UpdateFarmMini() end
end
