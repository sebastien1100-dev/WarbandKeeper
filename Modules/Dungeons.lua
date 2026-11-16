local ADDON_NAME, WK = ...
local M = WK:NewModule("Dungeons")
local T = function(s) return WK.T(s) end

-- Donjons : boss et butin (Modules/DungeonsDB.lua, généré depuis QuestieDB), donjon en cours,
-- boss tués, ce que chaque perso peut porter, liste d'envies et alertes.
--   WK.DB.global.dungeons = { wish = { [perso] = { [objet] = clé du donjon } },
--                             kills = { [perso] = { [clé] = { [boss] = date } } }, cfg = { ... } }
-- Le passage en cours (M.run) note les boss tués depuis l'entrée ; il s'efface à la sortie.
-- Affichage : UI/DungeonPanel.lua (à côté de la carte en donjon), UI/Pages/Dungeons.lua (page).

local DEFAULTS = { panel = true, alertEnter = true, alertDrop = true, filter = "me" }
local function db()
    local g = WK.DB.global
    g.dungeons = g.dungeons or {}
    local d = g.dungeons
    d.wish, d.kills = d.wish or {}, d.kills or {}
    d.cfg = d.cfg or {}
    for k, v in pairs(DEFAULTS) do if d.cfg[k] == nil then d.cfg[k] = v end end
    return d
end
function M:Config() return db().cfg end

---------------------------------------------------------------------------
-- Données
---------------------------------------------------------------------------
local byKey, byInst, byZone, bossOf
local function index()
    byKey, byInst, byZone, bossOf = {}, {}, {}, {}
    for _, d in ipairs(WK.DungeonsDB or {}) do
        byKey[d.key], byInst[d.inst] = d, d
        for _, z in ipairs(d.zones) do byZone[z] = d end
        d.list = {}
        for _, b in ipairs(d.bosses) do
            local e = { id = b[1], name = b[2], nameFR = b[3], level = b[4], loot = b[5], dungeon = d }
            table.insert(d.list, e)
            bossOf[e.id] = e
        end
    end
end
function M:All()
    if not byKey then index() end
    return WK.DungeonsDB or {}
end
function M:Get(key)
    if not byKey then index() end
    return byKey[key]
end
function M:Bosses(d)
    if not byKey then index() end
    return d and d.list or {}
end
function M:BossName(b)
    return (WK.Lang() == "frFR" and b.nameFR) or b.name
end
function M:Name(d) return T(d.name) end

-- Donjon où se trouve le perso (n° d'instance du jeu), ou nil
function M:Current()
    if not byKey then index() end
    if not GetInstanceInfo then return nil end
    local ok, _, itype, _, _, _, _, _, inst = pcall(GetInstanceInfo)
    if not ok or itype ~= "party" and itype ~= "raid" then return nil end
    return inst and byInst[inst] or nil
end

---------------------------------------------------------------------------
-- Ce qu'un perso peut porter (classe, niveau, métiers)
---------------------------------------------------------------------------
local ARMOR = { -- sous-classe d'armure la plus lourde portée (et niveau où elle s'apprend)
    WARRIOR = { 4, 40, 3 }, PALADIN = { 4, 40, 3 }, HUNTER = { 3, 40, 2 }, SHAMAN = { 3, 40, 2 },
    ROGUE = { 2 }, DRUID = { 2 }, PRIEST = { 1 }, MAGE = { 1 }, WARLOCK = { 1 },
}
local SHIELD = { WARRIOR = true, PALADIN = true, SHAMAN = true }
local WEAPONS = {
    WARRIOR = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18 }, PALADIN = { 0, 1, 4, 5, 6, 7, 8 },
    HUNTER = { 0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18 }, ROGUE = { 2, 3, 4, 7, 13, 15, 16, 18 },
    PRIEST = { 4, 10, 15, 19 }, SHAMAN = { 0, 1, 4, 5, 10, 13, 15 }, MAGE = { 7, 10, 15, 19 },
    WARLOCK = { 7, 10, 15, 19 }, DRUID = { 4, 5, 10, 13, 15 },
}
local RECIPE_PROF = { [1] = "Travail du cuir", [2] = "Couture", [3] = "Ingénierie", [4] = "Forge", [5] = "Cuisine",
                      [6] = "Alchimie", [7] = "Secourisme", [8] = "Enchantement", [9] = "Pêche" }
local weaponSet = {}
for cl, list in pairs(WEAPONS) do weaponSet[cl] = {}; for _, s in ipairs(list) do weaponSet[cl][s] = true end end

local function instant(id)
    local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not f then return nil end
    local ok, _, _, _, equipLoc, _, classID, subID = pcall(f, id)
    if not ok then return nil end
    return classID, subID, equipLoc
end
M.Instant = instant
local function hasProf(c, name)
    for p in pairs(c.professions or {}) do
        if p == name or T(p) == T(name) then return true end
    end
    return false
end
-- Le perso c peut-il s'en servir ? true / false, ou nil si le jeu ne connaît pas encore l'objet
function M:Usable(id, c)
    local classID, subID, loc = instant(id)
    if not classID then return nil end
    local cl, lvl = c.class, c.level or 1
    if classID == 4 then -- armure
        if loc == "INVTYPE_CLOAK" or loc == "INVTYPE_FINGER" or loc == "INVTYPE_NECK" or loc == "INVTYPE_TRINKET"
            or loc == "INVTYPE_HOLDABLE" or loc == "INVTYPE_BODY" or loc == "INVTYPE_TABARD" or subID == 0 then return true end
        if subID == 6 then return SHIELD[cl] or false end
        local a = ARMOR[cl]
        if not a then return true end
        local maxSub = (a[2] and lvl < a[2]) and a[3] or a[1]
        return subID <= maxSub
    elseif classID == 2 then
        return (weaponSet[cl] and weaponSet[cl][subID]) or false
    elseif classID == 9 then
        local prof = RECIPE_PROF[subID]
        return prof and hasProf(c, prof) or false
    end
    return true
end
-- L'objet est-il déjà sur le compte (sacs, banque, équipé…) ?
function M:Owned(id)
    local Inv = WK.modules.Inventory
    return Inv and Inv.AccountCount and Inv:AccountCount(id) > 0 or false
end

---------------------------------------------------------------------------
-- Liste d'envies (par perso)
---------------------------------------------------------------------------
local function wishOf(key)
    local w = db().wish
    w[key] = w[key] or {}
    return w[key]
end
function M:IsWished(id, key) return wishOf(key or WK:CharKey())[id] ~= nil end
function M:ToggleWish(id, dkey, key)
    local w = wishOf(key or WK:CharKey())
    if w[id] then w[id] = nil else w[id] = dkey or true end
    WK:NotifyChanged()
end
-- Envies : { { char, id, dungeon } } (tous les persos, ou un seul)
function M:Wishes(key)
    local out = {}
    for ck, w in pairs(db().wish) do
        if not key or ck == key then
            for id, dk in pairs(w) do table.insert(out, { char = ck, id = id, dungeon = self:Get(dk) }) end
        end
    end
    table.sort(out, function(a, b)
        local la, lb = a.dungeon and a.dungeon.min or 99, b.dungeon and b.dungeon.min or 99
        if la ~= lb then return la < lb end
        return a.id < b.id
    end)
    return out
end
function M:WishCount(key)
    local n = 0
    for _ in pairs(wishOf(key or WK:CharKey())) do n = n + 1 end
    return n
end

---------------------------------------------------------------------------
-- Boss tués : passage en cours et, pour la progression, au moins une fois par perso
---------------------------------------------------------------------------
M.run = nil -- { key, killed = { [boss] = true } }
local function npcID(guid)
    if not guid then return nil end
    local id = type(guid) == "string" and guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    return tonumber(id)
end
function M:Killed(d, bossID)
    return self.run and self.run.key == d.key and self.run.killed[bossID] or false
end
function M:KilledEver(d, bossID, key)
    local k = db().kills[key or WK:CharKey()]
    return k and k[d.key] and k[d.key][bossID] ~= nil or false
end
function M:Progress(d, key)
    local n, done = 0, 0
    for _, b in ipairs(self:Bosses(d)) do
        n = n + 1
        if self:KilledEver(d, b.id, key) then done = done + 1 end
    end
    return done, n
end
local function onDeath(guid)
    local id = npcID(guid)
    if not id then return end
    if not byKey then index() end
    local b = bossOf[id]
    if not b then return end
    local d = b.dungeon
    if not M.run or M.run.key ~= d.key then M.run = { key = d.key, killed = {} } end
    M.run.killed[id] = true
    local k = db().kills
    local me = WK:CharKey()
    k[me] = k[me] or {}
    k[me][d.key] = k[me][d.key] or {}
    k[me][d.key][id] = time()
    if M.OnChange then M:OnChange() end
    WK:NotifyChanged()
end
-- Détection sans le journal de combat (réservé au jeu sur ce client : s'y inscrire est interdit aux
-- addons) : mort d'une unité visible (cible, focus, boss1-5, plaques de nom) et butin d'un corps.
-- Toute valeur que le jeu masque est ignorée.
local readable = function(v) return WK.modules.QoL.Readable(v) end
local function checkUnit(unit)
    if not M.run or not unit then return end
    local okE, ex = pcall(UnitExists, unit)
    if not (okE and readable(ex)) then return end
    local okD, dead = pcall(UnitIsDead, unit)
    if not (okD and readable(dead)) then return end
    local okG, guid = pcall(UnitGUID, unit)
    guid = okG and readable(guid) or nil
    if guid then pcall(onDeath, guid) end
end
local WATCH = { target = true, focus = true, mouseover = true }
WK:On("UNIT_HEALTH", function(unit)
    if not M.run or type(unit) ~= "string" then return end
    if WATCH[unit] or unit:find("^boss%d") or unit:find("^nameplate%d") then checkUnit(unit) end
end)
WK:On("PLAYER_TARGET_CHANGED", function() checkUnit("target") end)
WK:On("LOOT_OPENED", function()
    if not (M.run and GetNumLootItems and GetLootSourceInfo) then return end
    for i = 1, GetNumLootItems() do
        local ok, guid = pcall(GetLootSourceInfo, i)
        guid = ok and readable(guid) or nil
        if guid then pcall(onDeath, guid) end
    end
end)

-- Entrée et sortie de donjon : passage remis à zéro, alerte des envies
local lastKey
local function onZone()
    local d = M:Current()
    if d then
        if lastKey ~= d.key then
            M.run = { key = d.key, killed = {} }
            lastKey = d.key
            if M:Config().alertEnter and WK:FeatureOn("dungeons") then
                local n = 0
                for _, e in ipairs(M:Wishes(WK:CharKey())) do if e.dungeon == d then n = n + 1 end end
                if n > 0 then
                    local msg = string.format(n > 1 and T("%s : %d objets de ta liste d'envies ici") or T("%s : %d objet de ta liste d'envies ici"), M:Name(d), n)
                    WK:Print(msg)
                    WK.modules.QoL:Remind("dungeonWish", msg, 0.96, 0.55, 0.73)
                end
            end
        end
    else
        lastKey, M.run = nil, nil
    end
    if M.OnChange then M:OnChange() end
end
WK:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(1, onZone) end)
WK:On("ZONE_CHANGED_NEW_AREA", function() C_Timer.After(1, onZone) end)

-- Un objet d'une liste d'envies tombe (message de butin du groupe)
WK:On("CHAT_MSG_LOOT", function(msg)
    if not (M:Config().alertDrop and WK:FeatureOn("dungeons")) or type(msg) ~= "string" then return end
    if issecretvalue and issecretvalue(msg) then return end
    for idStr in msg:gmatch("item:(%d+)") do
        local id = tonumber(idStr)
        for ck, w in pairs(db().wish) do
            if w[id] then
                local c = WK.DB.global.characters[ck]
                local who = c and WK:CharName(c, ck) or "?"
                local txt = string.format(T("Liste d'envies : %s est tombé (voulu par %s) !"), WK.GetItemInfo(id) or ("#" .. id), who)
                WK:Print(txt)
                WK.modules.QoL:Remind("dungeonDrop" .. id, txt, 1, 0.82, 0.2)
                if PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.UI_EPICLOOT_TOAST or SOUNDKIT.RAID_WARNING or 8959) end
            end
        end
    end
end)

---------------------------------------------------------------------------
-- Guidage vers l'entrée, quêtes du donjon
---------------------------------------------------------------------------
function M:GuideTo(d)
    if not d.entry then return false end
    local G = WK.modules.Guide
    local map, x, y = d.entry[1], d.entry[2] / 100, d.entry[3] / 100
    local t = { map = map, x = x, y = y }
    t.cont, t.wx, t.wy = G.ToWorld(map, x, y)
    local p = G:PlayerPos()
    t.distance = p and G:Vector(p, t) or nil
    t.e = { d.entry[2], d.entry[3], 0, nil, nil, d.name, T(d.name), T("Entrée du donjon") }
    G:Start(t, "Donjon", "dungeon")
    return true
end
-- Quêtes de donjon de la zone de l'entrée, à peu près au niveau du donjon
function M:Quests(d, c)
    local Q = WK.modules.Quests
    if not (Q and d.entry) then return {} end
    local out = {}
    for _, q in ipairs(Q:OnMap(d.entry[1])) do
        if q.kind == "d" and (q.lvl or 0) >= d.min - 4 and (q.lvl or 0) <= d.max + 2 and (not c or Q:ForChar(q, c)) then
            table.insert(out, q)
        end
    end
    return out
end
