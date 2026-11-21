local ADDON_NAME, WK = ...
local T = function(s) return WK.T(s) end

-- Compétences d'armes : niveau de chaque arme apprise par perso, armes que la classe peut encore
-- apprendre, prix et maître d'armes le plus proche qui les enseigne. Armes par classe, prix de base et
-- maîtres : Modules/ClassPricesDB.lua (What's Training, licence MIT, généré par tools/gen_trainprices.py).
-- Relevé sur le perso connecté (GetSkillLineInfo) dans characters[perso].weapons = { [sort] = { rang, max } }.
local M = {}
WK.modules.WeaponSkills = M

-- Baguettes : apprises d'office par les lanceurs de sorts, affichées seulement si le perso les a
local WAND = 5009
-- Sous-classe d'objet arme du jeu » sort de compétence
local SUBCLASS = { [0] = 196, [1] = 197, [2] = 264, [3] = 266, [4] = 198, [5] = 199, [6] = 200, [7] = 201, [8] = 202,
    [10] = 227, [13] = 15590, [15] = 1180, [16] = 2567, [18] = 5011, [19] = WAND }
-- Ordre d'affichage : mêlée deux mains, une main, puis distance
local ORDER = { 202, 197, 199, 200, 227, 201, 196, 198, 1180, 15590, 264, 266, 5011, 2567, WAND }

local function db() return WK.WeaponSkillsDB or {} end

-- nom du jeu de la compétence (nom du sort), gardé
local names = {}
function M:Name(id)
    if names[id] then return names[id] end
    local n, icon = WK.SpellInfo(id)
    if n then names[id] = n end
    return n or ("#" .. id), icon
end
function M:Icon(id)
    local _, icon = WK.SpellInfo(id)
    return icon or 135274
end

-- Armes que cette classe peut apprendre
function M:ClassWeapons(class)
    local out = {}
    for _, id in ipairs(ORDER) do
        local d = db()[id]
        if d and class and ("," .. d.classes .. ","):find("," .. class .. ",", 1, true) then table.insert(out, id) end
    end
    return out
end

---------------------------------------------------------------------------
-- Relevé sur le perso connecté
---------------------------------------------------------------------------
function M:Record()
    if not (GetNumSkillLines and GetSkillLineInfo) then return end
    local byName = {}
    for _, id in ipairs(ORDER) do
        local n = WK.SpellInfo(id)
        if n then byName[n] = id end
    end
    local out, any = {}, false
    for i = 1, GetNumSkillLines() do
        local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
        local id = not isHeader and name and byName[name]
        if id then out[id] = { rank or 0, maxRank or 0 }; any = true end
    end
    if not any then return end
    local c = WK.DB:Me()
    c.weapons = out
    c.weaponsAt = time()
    WK:NotifyChanged()
end

---------------------------------------------------------------------------
-- Ce qu'un perso a et peut apprendre
---------------------------------------------------------------------------
-- Armes portées : sorts de compétence des armes en main (perso connecté : lu en jeu ; autres : liens relevés)
local function equipped(key)
    local set = {}
    local mine = key == WK:CharKey()
    local c = WK.DB.global.characters[key] or {}
    for _, slot in ipairs({ 16, 17, 18 }) do
        -- perso connecté : lu en jeu (emplacement vide = rien, pas l'ancien relevé de c.gear)
        local item
        if mine and GetInventoryItemID then item = GetInventoryItemID("player", slot)
        else item = c.gear and c.gear[slot] end
        if item and C_Item and C_Item.GetItemInfoInstant then
            local ok, _, _, _, _, _, classID, subID = pcall(C_Item.GetItemInfoInstant, item)
            if ok and classID == 2 and SUBCLASS[subID] then set[SUBCLASS[subID]] = true end
        end
    end
    return set
end

-- { level, max, learned = { { id, name, icon, rank, max, equipped } }, toLearn = { { id, name, icon, cost, level, soon } },
--   recorded }
function M:ForChar(key)
    key = key or WK:CharKey()
    local c = WK.DB.global.characters[key] or {}
    local class = c.class or (key == WK:CharKey() and select(2, UnitClass("player"))) or nil
    local lvl = (key == WK:CharKey() and UnitLevel and UnitLevel("player")) or c.level or 1
    local have = c.weapons or {}
    local eq = equipped(key)
    local r = { level = lvl, max = lvl * 5, learned = {}, toLearn = {}, recorded = c.weapons ~= nil }
    for _, id in ipairs(ORDER) do
        local h = have[id]
        if h then
            table.insert(r.learned, { id = id, name = self:Name(id), icon = self:Icon(id), rank = h[1], max = h[2] > 0 and h[2] or r.max,
                equipped = eq[id] or false })
        end
    end
    for _, id in ipairs(self:ClassWeapons(class)) do
        if not have[id] then
            local d = db()[id]
            table.insert(r.toLearn, { id = id, name = self:Name(id), icon = self:Icon(id), cost = d.cost or 1000,
                level = d.level or 0, soon = (d.level or 0) > lvl })
        end
    end
    return r
end

-- Retard d'une arme : rang de couleur (ok / warn / bad)
function M:Lag(e)
    local gap = (e.max or 0) - (e.rank or 0)
    if gap <= 0 then return "ok" end
    if gap <= 25 then return "warn" end
    return "bad"
end

---------------------------------------------------------------------------
-- Maîtres d'armes
---------------------------------------------------------------------------
-- Maîtres de ta faction (qui enseignent cette arme si id), du plus proche au plus loin :
-- { { name, map, x, y, distance, teaches = { [sort] = true }, target } }
function M:Masters(id)
    local G = WK.modules.Guide
    local fac = UnitFactionGroup and UnitFactionGroup("player")
    local p = G and G:PlayerPos()
    local fr = WK.Lang and WK.Lang() == "frFR"
    local out = {}
    for _, m in ipairs(WK.WeaponMasters or {}) do
        local teaches = {}
        for s in m[6]:gmatch("%d+") do teaches[tonumber(s)] = true end
        if (not fac or m[2] == fac) and (not id or teaches[id]) then
            local name = fr and m[8] or m[7]
            -- cible de guidage au format des lieux (Modules/Guide.lua : e = { x, y, genre, classe, faction, nom, nom fr, rôle })
            local e = { m[4] * 100, m[5] * 100, 0, nil, m[2] == "Horde" and "H" or "A", m[7], m[8], T("Maître d'armes") }
            local t = { map = m[3], x = m[4], y = m[5], e = e }
            if G then
                local cont, wx, wy = G.ToWorld(m[3], m[4], m[5])
                t.cont, t.wx, t.wy = cont, wx, wy
                t.distance = p and G:Vector(p, t) or nil
            end
            table.insert(out, { name = name, map = m[3], x = m[4], y = m[5], distance = t.distance, teaches = teaches, target = t })
        end
    end
    table.sort(out, function(a, b) return (a.distance or 1e12) < (b.distance or 1e12) end)
    return out
end

-- Nom de la ville d'un maître
function M:Zone(m)
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(m.map)
    return info and info.name or ""
end

function M:GuideTo(master)
    if not master then return end
    WK.modules.Guide:Start(master.target, "Maître d'armes", "weapon")
end

---------------------------------------------------------------------------
-- Évènements
---------------------------------------------------------------------------
local pending
local function soon()
    if pending then return end
    pending = true
    C_Timer.After(1, function() pending = false; M:Record() end)
end
WK:On("PLAYER_LOGIN", function() C_Timer.After(4, function() M:Record() end) end)
WK:On("SKILL_LINES_CHANGED", soon)
WK:On("CHAT_MSG_SKILL", soon)
WK:On("PLAYER_EQUIPMENT_CHANGED", function() WK:NotifyChanged() end)
