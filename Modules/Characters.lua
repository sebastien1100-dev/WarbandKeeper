local ADDON_NAME, WK = ...
local M = WK:NewModule("Characters")

-- Nom complet (« Prénom Nom ») si une fonction du jeu le donne avec l'espace.
function M:DetectFullName()
    local cands = { (UnitName("player")) }
    if GetUnitName then table.insert(cands, (GetUnitName("player", false))) end
    if UnitFullName then table.insert(cands, (UnitFullName("player"))) end
    for _, n in ipairs(cands) do
        if type(n) == "string" and string.find(n, "%S %S") then return n end
    end
end

function M:UpdateBasics()
    local c = WK.DB:Me()
    c.name = UnitName("player")
    c.fullName = M:DetectFullName()
    c.realm = GetRealmName()
    c.class = select(2, UnitClass("player"))
    c.race = select(2, UnitRace("player"))
    c.sex = UnitSex and UnitSex("player") or c.sex -- 2 = homme, 3 = femme
    c.faction = UnitFactionGroup("player")
    c.level = UnitLevel("player")
    c.lastSeen = time()
end

function M:UpdateMoney()
    local c, key = WK.DB:Me()
    local money = GetMoney()
    if c.money and money ~= c.money then
        if WK.modules.Journal then WK.modules.Journal:Gold(money - c.money) end
        if WK.modules.Farm then WK.modules.Farm:OnMoney(money - c.money) end
    end
    c.money = money
    local hist = WK.DB.global.history.gold
    hist[key] = hist[key] or {}
    WK.DB:PushHistory(hist[key], c.money)
    WK:NotifyChanged()
end

function M:OnLogin()
    self:UpdateBasics()
    self:UpdateMoney()
    RequestTimePlayed()
end

WK:On("PLAYER_MONEY", function() M:UpdateMoney() end)
WK:On("PLAYER_LEVEL_UP", function() M:UpdateBasics() end)
-- Portrait du perso connecté (changement d'apparence, de forme…).
WK:On("UNIT_PORTRAIT_UPDATE", function(unit) if unit == "player" then WK:NotifyChanged() end end)
WK:On("PLAYER_LOGOUT", function() M:UpdateBasics() end)

WK:On("TIME_PLAYED_MSG", function(total, level)
    local c = WK.DB:Me()
    c.played = total
    c.playedLevel = level
    WK:NotifyChanged()
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

-- Supprime un personnage (et son historique) des données.
function M:Delete(key)
    WK.DB.global.characters[key] = nil
    WK.DB.global.history.gold[key] = nil
    WK:NotifyChanged()
end

function M:PrintGold()
    local total = 0
    for _, key in ipairs(self:SortedKeys()) do
        local c = WK.DB.global.characters[key]
        total = total + (c.money or 0)
        WK:Print(string.format("  %s : %s", WK:CharName(c, key), WK:FormatMoney(c.money)))
    end
    WK:Print(WK.L.TOTAL .. " : " .. WK:FormatMoney(total))
end

function M:PrintCharacters()
    local totalPlayed = 0
    for _, key in ipairs(self:SortedKeys()) do
        local c = WK.DB.global.characters[key]
        totalPlayed = totalPlayed + (c.played or 0)
        WK:Print(string.format("  %s - niv %s %s - %s", WK:CharName(c, key), c.level or "?", c.class or "?", WK:FormatTime(c.played)))
    end
    WK:Print(WK.L.TOTAL .. " : " .. WK:FormatTime(totalPlayed))
end
