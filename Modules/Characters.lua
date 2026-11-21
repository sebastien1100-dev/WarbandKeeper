local ADDON_NAME, WK = ...
local M = WK:NewModule("Characters")
local T = function(s) return WK.T(s) end

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

-- Le /played demandé à la connexion ne s'affiche pas dans le chat : les fenêtres de chat cessent d'écouter
-- TIME_PLAYED_MSG le temps de la réponse (sans remplacer la fonction du jeu, ce qui le corromprait).
local muted -- fenêtres de chat qui écoutaient l'évènement
local function unmutePlayed()
    if not muted then return end
    for _, f in ipairs(muted) do pcall(f.RegisterEvent, f, "TIME_PLAYED_MSG") end
    muted = nil
end
local function mutePlayed()
    if muted then return end
    muted = {}
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local f = _G["ChatFrame" .. i]
        if f and f.IsEventRegistered and f:IsEventRegistered("TIME_PLAYED_MSG") then
            f:UnregisterEvent("TIME_PLAYED_MSG")
            table.insert(muted, f)
        end
    end
    -- sans réponse, les fenêtres retrouvent l'évènement quand même
    if C_Timer and C_Timer.After then C_Timer.After(10, unmutePlayed) end
end

-- Même perso rangé sous deux clés (nom ou royaume lus autrement par le jeu d'une connexion à l'autre) : la vieille
-- fiche est fondue dans la fiche courante (ce qui manque y est recopié, ce qui est rangé à son nom ailleurs dans les
-- données passe au nouveau nom), puis effacée. Reconnu par le GUID du perso, sinon nom complet, classe, race, faction.
local function sameChar(a, b)
    if not (a and b) then return false end
    if a.guid and b.guid then return a.guid == b.guid end
    local na, nb = a.fullName or a.name, b.fullName or b.name
    return na ~= nil and na == nb and a.class ~= nil and a.class == b.class and a.race == b.race and a.faction == b.faction
        and math.abs((a.level or 0) - (b.level or 0)) <= 2
end
local function fill(dst, src, depth)
    for k, v in pairs(src) do
        if dst[k] == nil then dst[k] = v
        elseif depth > 0 and type(v) == "table" and type(dst[k]) == "table" then fill(dst[k], v, depth - 1) end
    end
end
local function moveKey(t, old, new, depth, seen)
    if type(t) ~= "table" or seen[t] then return end
    seen[t] = true
    if t[old] ~= nil then
        if t[new] == nil then t[new] = t[old]
        elseif type(t[new]) == "table" and type(t[old]) == "table" then fill(t[new], t[old], 2) end
        t[old] = nil
    end
    if depth <= 0 then return end
    for _, v in pairs(t) do if type(v) == "table" then moveKey(v, old, new, depth - 1, seen) end end
end
function M:MergeDuplicates()
    local g = WK.DB.global
    local me, key = WK.DB:Me()
    if UnitGUID then me.guid = UnitGUID("player") or me.guid end
    local merged = 0
    for k, c in pairs(g.characters) do
        if k ~= key and sameChar(c, me) then
            fill(me, c, 3)
            local seen = { [g.characters] = true }
            for name, t in pairs(g) do
                if name ~= "characters" and type(t) == "table" then moveKey(t, k, key, 3, seen) end
            end
            g.characters[k] = nil
            merged = merged + 1
        end
    end
    if merged > 0 then
        WK:Print(string.format(T("Fiche en double de %s fusionnée (même perso rangé sous deux noms)."), WK:CharName(me, key)))
        WK:NotifyChanged()
    end
    return merged
end

function M:OnLogin()
    self:UpdateBasics()
    pcall(self.MergeDuplicates, self)
    self:UpdateMoney()
    mutePlayed()
    RequestTimePlayed()
end

WK:On("PLAYER_MONEY", function() M:UpdateMoney() end)
WK:On("PLAYER_LEVEL_UP", function(level)
    M:UpdateBasics()
    -- UnitLevel peut encore rendre l'ancien niveau à cet instant : le niveau de l'évènement fait foi
    level = tonumber(level)
    if level and level > 0 then WK.DB:Me().level = level end
end)
-- Portrait du perso connecté (changement d'apparence, de forme…).
WK:On("UNIT_PORTRAIT_UPDATE", function(unit) if unit == "player" then WK:NotifyChanged() end end)
WK:On("PLAYER_LOGOUT", function() M:UpdateBasics() end)

WK:On("TIME_PLAYED_MSG", function(total, level)
    local c = WK.DB:Me()
    c.played = total
    c.playedLevel = level
    WK:NotifyChanged()
    -- réponse reçue : les fenêtres de chat réécoutent (après cet évènement, pour ne pas l'afficher)
    if muted and C_Timer and C_Timer.After then C_Timer.After(0, unmutePlayed) end
end)

-- Affichage
function M:SortedKeys()
    local keys = {}
    for k in pairs(WK.DB.global.characters) do table.insert(keys, k) end
    table.sort(keys)
    return keys
end

-- Supprime un personnage et tout ce qui est rangé à son nom (historique, builds, listes, règles propres…).
function M:Delete(key)
    if not key then return end
    local g = WK.DB.global
    g.characters[key] = nil
    local h = g.history or {}
    if h.gold then h.gold[key] = nil end
    if h.charItems then h.charItems[key] = nil end
    for _, name in ipairs({ "talentBuilds", "talentPlans", "bisLists", "bisList", "weaponSets" }) do
        if type(g[name]) == "table" then g[name][key] = nil end
    end
    if g.profiles and g.profiles.byChar then g.profiles.byChar[key] = nil end
    local d = g.dungeons
    if d then
        for _, name in ipairs({ "wish", "kills", "runs" }) do
            if type(d[name]) == "table" then d[name][key] = nil end
        end
    end
    local gh = g.gatherHelp
    if gh then
        for _, name in ipairs({ "rankSeen", "lastRank" }) do
            if type(gh[name]) == "table" then gh[name][key] = nil end
        end
    end
    for _, per in pairs((g.rares and g.rares.kills) or {}) do
        if type(per) == "table" then per[key] = nil end
    end
    -- règles d'envoi et de dépôt propres à ce perso (clé « objet@Perso-Royaume »)
    local R = WK.modules.Rules
    if R and R.SplitKey then
        local mail, bank = g.mail or {}, g.bank or {}
        for _, store in pairs({ mail.rules or {}, mail.cats or {}, bank.items or {}, bank.cats or {} }) do
            for k in pairs(store) do
                local _, from = R:SplitKey(k)
                if from == key then store[k] = nil end
            end
        end
    end
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
