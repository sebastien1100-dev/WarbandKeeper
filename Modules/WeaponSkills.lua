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
-- Nom de la ligne de compétence quand il diffère du nom du sort (anglais et français) : sur ce client, la
-- fenêtre des compétences dit « Haches », « Épées », « Masses » pour les armes à une main, alors que le sort
-- s'appelle « Haches à une main »… Avant, ces armes n'étaient jamais reconnues : l'onglet Armes disait tout à
-- apprendre.
local SKILL_NAMES = {
    [196] = { "Axes", "One-Handed Axes", "Haches", "Haches à une main" },
    [197] = { "Two-Handed Axes", "Haches à deux mains" },
    [198] = { "Maces", "One-Handed Maces", "Masses", "Masses à une main" },
    [199] = { "Two-Handed Maces", "Masses à deux mains" },
    [200] = { "Polearms", "Armes d'hast" },
    [201] = { "Swords", "One-Handed Swords", "Épées", "Épées à une main" },
    [202] = { "Two-Handed Swords", "Épées à deux mains" },
    [227] = { "Staves", "Bâtons" },
    [264] = { "Bows", "Arcs" },
    [266] = { "Guns", "Armes à feu" },
    [1180] = { "Daggers", "Dagues" },
    [2567] = { "Thrown", "Armes de jet" },
    [5009] = { "Wands", "Baguettes" },
    [5011] = { "Crossbows", "Arbalètes" },
    [15590] = { "Fist Weapons", "Armes de pugilat" },
}
M.SKILL_NAMES = SKILL_NAMES

-- Clé de comparaison : minuscules, sans accents ni apostrophe courbe, sans « s » final de chaque mot (le jeu
-- écrit « Epées » sans accent et « Masse » au singulier : avant, ces armes n'étaient pas reconnues)
local ACCENTS = { ["é"] = "e", ["è"] = "e", ["ê"] = "e", ["ë"] = "e", ["É"] = "e", ["È"] = "e", ["Ê"] = "e",
    ["à"] = "a", ["â"] = "a", ["À"] = "a", ["î"] = "i", ["ï"] = "i", ["ô"] = "o", ["û"] = "u", ["ù"] = "u",
    ["ç"] = "c", ["’"] = "'" }
local function nameKey(n)
    if not n then return nil end
    n = n:gsub("[\195\226][\128-\191]+", function(c) return ACCENTS[c] or c end):lower()
    n = n:gsub("(%a)s%f[%A]", "%1")
    return n
end
M.NameKey = nameKey

-- Arme connue comme sort (onglet Général du grimoire) : repli quand la fenêtre des compétences n'est pas
-- lisible (API absente sur ce client) ; le rang n'est alors pas connu (-1)
local function knownSpell(id)
    local ok, v = pcall(function()
        if _G.IsPlayerSpell then return _G.IsPlayerSpell(id) end
        if _G.IsSpellKnown then return _G.IsSpellKnown(id) end
    end)
    return ok and v or false
end

-- N° de ligne de compétence du jeu par sort de compétence d'arme (C_SkillInfo de WoW Forever)
local SKILL_LINE = { [196] = 44, [197] = 172, [198] = 54, [199] = 160, [200] = 229, [201] = 43, [202] = 55,
    [227] = 136, [264] = 45, [266] = 46, [1180] = 173, [2567] = 176, [5009] = 228, [5011] = 226, [15590] = 473 }
-- rang et max d'une entrée de C_SkillInfo (noms de champs lus avec prudence : ce client n'en documente aucun)
local function skillRank(d)
    if type(d) ~= "table" then return nil end
    local r = d.rank or d.skillRank or d.currentRank or d.skillLineRank or d.currentLevel or d.skillLevel
    local mx = d.maxRank or d.skillMaxRank or d.maxLevel or d.skillLineMaxRank or 0
    if r == nil then
        -- autre nom de champ : un nombre dont le nom parle de rang ou de niveau (pas le max ni un n°)
        for k, v in pairs(d) do
            local lk = type(k) == "string" and k:lower() or ""
            if type(v) == "number" and not lk:find("max") and not lk:find("id")
                and (lk:find("rank") or lk:find("level") or lk:find("current") or lk:find("value")) then
                r = v
                break
            end
        end
    end
    return tonumber(r), tonumber(mx) or 0
end

-- WoW Forever : la fenêtre « Comp. » passe par C_SkillInfo (pas par l'ancien GetSkillLineInfo, absent) ;
-- avant, l'onglet Armes ne trouvait donc jamais le niveau et disait seulement « apprise »
local function readSkillInfo(out)
    local SI = _G.C_SkillInfo
    if not (SI and (SI.GetSkillLineInfoByID or SI.GetSkillLineInfo)) then return false end
    local any = false
    local byName = {}
    for _, id in ipairs(ORDER) do
        local line = SKILL_LINE[id]
        local ok, d = false, nil
        if line and SI.GetSkillLineInfoByID then ok, d = pcall(SI.GetSkillLineInfoByID, line) end
        local r, mx = skillRank(ok and d or nil)
        if r and (r > 0 or mx > 0) and not out[id] then
            out[id] = { r, mx }; any = true
            M.lastRead.matched[#M.lastRead.matched + 1] = id
        end
        local n = WK.SpellInfo(id)
        if n then byName[nameKey(n)] = id end
        for _, alt in ipairs(SKILL_NAMES[id] or {}) do byName[nameKey(alt)] = id end
    end
    -- par la liste, au cas où les n° différeraient : rapproché par le nom
    if SI.GetNumSkillLines and SI.GetSkillLineInfo then
        local okN, n = pcall(SI.GetNumSkillLines)
        for i = 1, (okN and tonumber(n) or 0) do
            local ok, d = pcall(SI.GetSkillLineInfo, i)
            if ok and type(d) == "table" and d.name then
                if i == 1 or not M.lastRead.fields then
                    local keys = {}
                    for k in pairs(d) do keys[#keys + 1] = tostring(k) end
                    table.sort(keys)
                    M.lastRead.fields = table.concat(keys, ",")
                end
                local r, mx = skillRank(d)
                M.lastRead.seen[#M.lastRead.seen + 1] = d.name .. " " .. tostring(r)
                local id = not d.isHeader and byName[nameKey(d.name)]
                if id and not out[id] and r then
                    out[id] = { r, mx }; any = true
                    M.lastRead.matched[#M.lastRead.matched + 1] = id
                end
            end
        end
    end
    return any
end

function M:Record()
    local skillApi = _G.GetNumSkillLines and _G.GetSkillLineInfo
    M.lastRead = { api = skillApi and true or false, seen = {}, matched = {}, spells = {} }
    if not skillApi then
        local out = {}
        local any = readSkillInfo(out)
        if any then M.lastRead.api = "C_SkillInfo" end
        for _, id in ipairs(ORDER) do
            if not out[id] and knownSpell(id) then
                out[id] = { -1, 0 }; any = true; M.lastRead.spells[#M.lastRead.spells + 1] = id
            end
        end
        if not any then return end
        local c = WK.DB:Me()
        c.weapons = out
        c.weaponsAt = _G.time()
        WK:NotifyChanged()
        return
    end
    local byName = {}
    for _, id in ipairs(ORDER) do
        local n = WK.SpellInfo(id)
        if n then byName[nameKey(n)] = id end
        for _, alt in ipairs(SKILL_NAMES[id] or {}) do byName[nameKey(alt)] = id end
    end
    -- rubriques repliées dans la fenêtre des compétences : leurs lignes ne sont pas listées. Elles sont
    -- dépliées le temps de la lecture, puis repliées comme avant (de la fin vers le début : les index restent bons)
    local folded = {}
    if _G.ExpandSkillHeader then
        for i = _G.GetNumSkillLines(), 1, -1 do
            local name, isHeader, isExpanded = _G.GetSkillLineInfo(i)
            if isHeader and isExpanded == false and pcall(_G.ExpandSkillHeader, i) then folded[name] = true end
        end
    end
    if next(folded) then M.readAt = _G.GetTime() end
    local out, any = {}, false
    for i = 1, _G.GetNumSkillLines() do
        local name, isHeader, _, rank, _, _, maxRank = _G.GetSkillLineInfo(i)
        local id = not isHeader and name and byName[nameKey(name)]
        if name and not isHeader then M.lastRead.seen[#M.lastRead.seen + 1] = name .. " " .. tostring(rank) end
        if id then out[id] = { rank or 0, maxRank or 0 }; any = true; M.lastRead.matched[#M.lastRead.matched + 1] = id end
    end
    -- armes absentes de l'ancienne liste : C_SkillInfo de ce client
    if readSkillInfo(out) then any = true end
    -- armes absentes de la fenêtre mais connues comme sort : apprises, rang inconnu
    for _, id in ipairs(ORDER) do
        if not out[id] and knownSpell(id) then
            out[id] = { -1, 0 }; any = true; M.lastRead.spells[#M.lastRead.spells + 1] = id
        end
    end
    if next(folded) and _G.CollapseSkillHeader then
        for i = _G.GetNumSkillLines(), 1, -1 do
            local name, isHeader = _G.GetSkillLineInfo(i)
            if isHeader and folded[name] then pcall(_G.CollapseSkillHeader, i) end
        end
    end
    if not any then return end
    local c = WK.DB:Me()
    c.weapons = out
    c.weaponsAt = _G.time()
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
            local unknown = (h[1] or 0) < 0
            table.insert(r.learned, { id = id, name = self:Name(id), icon = self:Icon(id), rank = unknown and 0 or h[1],
                max = h[2] > 0 and h[2] or r.max, equipped = eq[id] or false, unknown = unknown })
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
    if e.unknown then return "ok" end
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

-- /wk armes : ce qui a été lu au dernier relevé
function M:Diag()
    self:Record()
    local d = self.lastRead or {}
    WK:Print(string.format(T("Armes : fenêtre des compétences %s."), d.api == "C_SkillInfo" and "C_SkillInfo"
        or d.api and T("lisible") or T("absente")))
    if d.fields then WK:Print(T("Champs : ") .. d.fields) end
    if d.seen and #d.seen > 0 then WK:Print(T("Lignes vues : ") .. table.concat(d.seen, ", ")) end
    local found = {}
    for _, id in ipairs(d.matched or {}) do found[#found + 1] = self:Name(id) end
    WK:Print(T("Armes reconnues : ") .. (#found > 0 and table.concat(found, ", ") or T("aucune")))
    found = {}
    for _, id in ipairs(d.spells or {}) do found[#found + 1] = self:Name(id) end
    if #found > 0 then WK:Print(T("Connues par le grimoire (rang inconnu) : ") .. table.concat(found, ", ")) end
end

---------------------------------------------------------------------------
-- Évènements
---------------------------------------------------------------------------
local pending
local function soon()
    -- le dépliage des rubriques par Record relance SKILL_LINES_CHANGED : ignoré juste après une lecture
    if M.readAt and _G.GetTime() - M.readAt < 2 then return end
    if pending then return end
    pending = true
    C_Timer.After(1, function() pending = false; M:Record() end)
end
WK:On("PLAYER_LOGIN", function() C_Timer.After(4, function() M:Record() end) end)
WK:On("SKILL_LINES_CHANGED", soon)
WK:On("CHAT_MSG_SKILL", soon)
WK:On("PLAYER_EQUIPMENT_CHANGED", function() WK:NotifyChanged() end)
