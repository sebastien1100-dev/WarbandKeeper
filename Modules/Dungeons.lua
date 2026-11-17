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
-- Boss sans n° de PNJ connu (nouveau contenu, absent de QuestieDB) : identifiés en jeu par leur nom
-- (client anglais) ou par leur butin (un objet de leur table trouvé sur le corps), puis le n° est
-- retenu dans dungeons.bossIds[clé:nom]. Même chose pour un n° d'instance inconnu (dungeons.inst).
local byKey, byInst, byZone, bossOf, byName
local function norm(s) return s and s:lower():gsub("^the ", ""):gsub("[%s%p]", "") or "" end
local function index()
    local g = db()
    g.bossIds, g.inst, g.names = g.bossIds or {}, g.inst or {}, g.names or {}
    byKey, byInst, byZone, bossOf, byName = {}, {}, {}, {}, {}
    for _, d in ipairs(WK.DungeonsDB or {}) do
        byKey[d.key] = d
        if d.inst then byInst[d.inst] = d end
        for _, z in ipairs(d.zones) do byZone[z] = d end
        d.list = {}
        for _, b in ipairs(d.bosses) do
            local id = b[1]
            if id == 0 then id = g.bossIds[d.key .. ":" .. b[2]] or ("n:" .. b[2]) end
            local e = { id = id, name = b[2], nameFR = b[3], level = b[4], loot = b[5], wing = b[6], dungeon = d }
            table.insert(d.list, e)
            if type(id) == "number" then bossOf[id] = e end
            byName[norm(b[2])] = byName[norm(b[2])] or e
            if b[3] then byName[norm(b[3])] = byName[norm(b[3])] or e end
        end
        -- butin des monstres du donjon : affiché comme un « boss » de plus, jamais compté
        d.groups = {}
        for _, e in ipairs(d.list) do table.insert(d.groups, e) end
        if d.trash and #d.trash > 0 then
            table.insert(d.groups, { id = "trash", trash = true, name = "Trash", nameFR = "Monstres du donjon", level = 0, loot = d.trash, dungeon = d })
        end
    end
    for inst, key in pairs(g.inst) do if byKey[key] and not byInst[inst] then byInst[inst] = byKey[key] end end
end
M.Reindex = function() byKey = nil end
function M:All()
    if not byKey then index() end
    return WK.DungeonsDB or {}
end
function M:Get(key)
    if not byKey then index() end
    return byKey[key]
end
-- Boss (pour la progression et les boss tués)
function M:Bosses(d)
    if not byKey then index() end
    return d and d.list or {}
end
-- Boss puis butin des monstres du donjon (pour l'affichage du butin)
function M:LootGroups(d)
    if not byKey then index() end
    return d and d.groups or {}
end
function M:BossName(b)
    return (WK.Lang() == "frFR" and b.nameFR) or b.name
end
-- Nom du donjon : nom français connu, sinon celui que le jeu affiche dans l'instance (retenu), sinon anglais
function M:Name(d)
    local learned = db().names and db().names[d.key]
    if d.name ~= d.en or not learned then return T(d.name) end
    return learned
end
-- Infos de la table de butin : qualité, niveau d'objet, niveau requis, % de drop, pas encore vu tomber
function M:ItemInfo(id)
    local i = WK.DungeonItems and WK.DungeonItems[id]
    if not i then return nil end
    return { quality = i[1], ilvl = i[2], req = i[3], drop = i[4], undiscovered = i[5] or false }
end

-- Donjon où se trouve le perso (n° d'instance du jeu, sinon nom de l'instance), ou nil
function M:Current()
    if not byKey then index() end
    if not GetInstanceInfo then return nil end
    local ok, iname, itype, _, _, _, _, _, inst = pcall(GetInstanceInfo)
    if not ok or itype ~= "party" and itype ~= "raid" then return nil end
    local d = inst and byInst[inst]
    if not d and iname then
        local n = norm(iname)
        for _, x in ipairs(WK.DungeonsDB or {}) do
            if norm(x.name) == n or norm(x.en) == n then d = x break end
        end
        if d and inst then self:LearnInstance(inst, d) end
    end
    if d and iname and d.name == d.en then db().names[d.key] = iname end
    return d
end
function M:LearnInstance(inst, d)
    if not (inst and d) or byInst[inst] then return end
    db().inst[inst] = d.key
    byInst[inst] = d
end
-- Instance où l'on est (party / raid), même inconnue : n° et nom
local function instanceNow()
    if not GetInstanceInfo then return nil end
    local ok, iname, itype, _, _, _, _, _, inst = pcall(GetInstanceInfo)
    if not ok or (itype ~= "party" and itype ~= "raid") then return nil end
    return inst, iname
end
M.InstanceNow = instanceNow
M.Norm = norm
function M:BossByName(name)
    if not byKey then index() end
    return name and byName[norm(name)] or nil
end
function M:BossOf(id)
    if not byKey then index() end
    return bossOf[id]
end
-- Le PNJ n° id est le boss e (boss sans n° connu) : retenu pour la suite
function M:LearnBoss(e, id)
    if type(e.id) == "number" or type(id) ~= "number" then return end
    local d = e.dungeon
    local old = e.id
    db().bossIds[d.key .. ":" .. e.name] = id
    e.id = id
    bossOf[id] = e
    -- les boss tués notés sous l'ancien nom passent au n°
    for _, k in pairs(db().kills) do
        if k[d.key] and k[d.key][old] then k[d.key][id] = k[d.key][old]; k[d.key][old] = nil end
    end
    if self.run and self.run.killed[old] then self.run.killed[id] = true; self.run.killed[old] = nil end
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
local function record(b)
    local d = b.dungeon
    local inst = instanceNow()
    if inst then M:LearnInstance(inst, d) end
    if not M.run or M.run.key ~= d.key then M.run = { key = d.key, killed = {} } end
    if M.run.killed[b.id] then return end
    M.run.killed[b.id] = true
    local k = db().kills
    local me = WK:CharKey()
    k[me] = k[me] or {}
    k[me][d.key] = k[me][d.key] or {}
    k[me][d.key][b.id] = time()
    if M.OnChange then M:OnChange() end
    WK:NotifyChanged()
end
-- Le boss b sans n° appartient-il au donjon où l'on est (ou à un donjon pas encore reconnu) ?
local function plausible(b)
    local cur = M:Current()
    if cur then return b.dungeon == cur end
    return b.dungeon.inst == nil or not byInst[b.dungeon.inst]
end
-- PNJ mort (n° tiré de son GUID) ; name : son nom, pour un boss pas encore identifié
local function onDeath(guid, name)
    local id = npcID(guid)
    if not id then return end
    if not byKey then index() end
    local b = bossOf[id]
    if not b and name then
        local e = byName[norm(name)]
        if e and type(e.id) ~= "number" and plausible(e) then M:LearnBoss(e, id); b = e end
    end
    if b then record(b) end
end
-- Objet trouvé sur le corps du PNJ id : s'il n'est dans la table que d'un seul boss pas encore
-- identifié du donjon, ce PNJ est ce boss
local function learnFromLoot(id, itemID)
    if not (id and itemID) or bossOf[id] then return end
    local found
    for _, d in ipairs(WK.DungeonsDB or {}) do
        for _, e in ipairs(d.list or {}) do
            if type(e.id) ~= "number" and plausible(e) then
                for _, x in ipairs(e.loot) do
                    if x == itemID then
                        if found and found ~= e then return end
                        found = e
                    end
                end
            end
        end
    end
    if found then M:LearnBoss(found, id); record(found) end
end
-- Détection sans le journal de combat (réservé au jeu sur ce client : s'y inscrire est interdit aux
-- addons) : mort d'une unité visible (cible, focus, boss1-5, plaques de nom) et butin d'un corps.
-- Toute valeur que le jeu masque est ignorée.
local readable = function(v) return WK.modules.QoL.Readable(v) end
local function active() return M.run ~= nil or instanceNow() ~= nil end
local function checkUnit(unit)
    if not unit or not active() then return end
    local okE, ex = pcall(UnitExists, unit)
    if not (okE and readable(ex)) then return end
    local okD, dead = pcall(UnitIsDead, unit)
    if not (okD and readable(dead)) then return end
    local okG, guid = pcall(UnitGUID, unit)
    guid = okG and readable(guid) or nil
    local okN, name = pcall(UnitName, unit)
    name = okN and readable(name) or nil
    if guid then pcall(onDeath, guid, type(name) == "string" and name or nil) end
end
local WATCH = { target = true, focus = true, mouseover = true }
WK:On("UNIT_HEALTH", function(unit)
    if type(unit) ~= "string" or not active() then return end
    if WATCH[unit] or unit:find("^boss%d") or unit:find("^nameplate%d") then checkUnit(unit) end
end)
WK:On("PLAYER_TARGET_CHANGED", function() checkUnit("target") end)
WK:On("LOOT_OPENED", function()
    if not (active() and GetNumLootItems and GetLootSourceInfo) then return end
    if not byKey then index() end
    for i = 1, GetNumLootItems() do
        local ok, guid = pcall(GetLootSourceInfo, i)
        guid = ok and readable(guid) or nil
        if guid then
            pcall(onDeath, guid)
            local link = GetLootSlotLink and GetLootSlotLink(i)
            local item = link and WK:ParseItemID(link)
            if item then pcall(learnFromLoot, npcID(guid), item) end
        end
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
