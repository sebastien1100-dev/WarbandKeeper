local ADDON_NAME, WK = ...
local M = WK:NewModule("Characters")

function M:UpdateBasics()
    local c = WK.DB:Me()
    c.name = UnitName("player")
    c.realm = GetRealmName()
    c.class = select(2, UnitClass("player"))
    c.race = select(2, UnitRace("player"))
    c.faction = UnitFactionGroup("player")
    c.level = UnitLevel("player")
    c.lastSeen = time()
end

function M:UpdateMoney()
    local c, key = WK.DB:Me()
    c.money = GetMoney()
    local hist = WK.DB.global.history.gold
    hist[key] = hist[key] or {}
    WK.DB:PushHistory(hist[key], c.money)
end

function M:OnLogin()
    self:UpdateBasics()
    self:UpdateMoney()
    RequestTimePlayed()
end

WK:On("PLAYER_MONEY", function() M:UpdateMoney() end)
WK:On("PLAYER_LEVEL_UP", function() M:UpdateBasics() end)
WK:On("PLAYER_LOGOUT", function() M:UpdateBasics() end)

WK:On("TIME_PLAYED_MSG", function(total, level)
    local c = WK.DB:Me()
    c.played = total
    c.playedLevel = level
end)

-- Masque le message "/played" automatique dans le chat au login.
local hideNextPlayed = true
local origDisplay = ChatFrame_DisplayTimePlayed
if origDisplay then
    ChatFrame_DisplayTimePlayed = function(...)
        if hideNextPlayed then hideNextPlayed = false return end
        return origDisplay(...)
    end
end

-- Affichage
function M:SortedKeys()
    local keys = {}
    for k in pairs(WK.DB.global.characters) do table.insert(keys, k) end
    table.sort(keys)
    return keys
end

function M:PrintGold()
    local total = 0
    for _, key in ipairs(self:SortedKeys()) do
        local c = WK.DB.global.characters[key]
        total = total + (c.money or 0)
        WK:Print(string.format("  %s : %s", key, WK:FormatMoney(c.money)))
    end
    WK:Print(WK.L.TOTAL .. " : " .. WK:FormatMoney(total))
end

function M:PrintCharacters()
    local totalPlayed = 0
    for _, key in ipairs(self:SortedKeys()) do
        local c = WK.DB.global.characters[key]
        totalPlayed = totalPlayed + (c.played or 0)
        WK:Print(string.format("  %s - niv %s %s - %s", key, c.level or "?", c.class or "?", WK:FormatTime(c.played)))
    end
    WK:Print(WK.L.TOTAL .. " : " .. WK:FormatTime(totalPlayed))
end
