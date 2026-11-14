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

local function interacting()
    for _ in pairs(busy) do return true end
    return false
end
local function setBusy(key, on) busy[key] = on or nil end
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
    if self:Active() then return end
    farm().current = {
        start = time(), resumedAt = time(), acc = 0, paused = false,
        char = WK:CharKey(), zone = GetRealZoneText and GetRealZoneText() or "",
        gold = 0, items = {},
    }
    WK:Print(T("Session de farm démarrée."))
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

-- Valeur du butin : prix Auctionator si disponible, sinon prix marchand.
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
    if not s or s.paused or s.char ~= WK:CharKey() or interacting() or not old then return end
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
    if not s or s.paused or s.char ~= WK:CharKey() or interacting() or delta <= 0 then return end
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
