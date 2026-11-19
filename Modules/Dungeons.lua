local ADDON_NAME, WK = ...
local M = WK:NewModule("Dungeons")
local T = function(s) return WK.T(s) end

-- Donjons : boss et butin (Modules/DungeonsDB.lua, généré depuis QuestieDB), donjon en cours,
-- boss tués, ce que chaque perso peut porter, liste d'envies et alertes.
--   WK.DB.global.dungeons = { wish = { [perso] = { [objet] = clé du donjon } },
--                             kills = { [perso] = { [clé] = { [boss] = date } } }, cfg = { ... } }
-- Le passage en cours (M.run) note les boss tués depuis l'entrée ; gardé dans dungeons.runs[perso], repris si
-- on revient dans le même donjon moins d'1 h après en être sorti.
-- Affichage : UI/DungeonPanel.lua (à côté de la carte en donjon), UI/Pages/Dungeons.lua (page).

local DEFAULTS = { panel = true, alertEnter = true, alertDrop = true, filter = "me", timer = false,
    capAlert = true, summary = "me", real = true }
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
local byKey, byInst, byZone, bossOf, byName, byEncounter
local function norm(s) return s and s:lower():gsub("^the ", ""):gsub("[%s%p]", "") or "" end
local function index()
    local g = db()
    g.bossIds, g.inst, g.names, g.bossNames = g.bossIds or {}, g.inst or {}, g.names or {}, g.bossNames or {}
    byKey, byInst, byZone, bossOf, byName, byEncounter = {}, {}, {}, {}, {}, {}
    for _, d in ipairs(WK.DungeonsDB or {}) do
        byKey[d.key] = d
        if d.inst then byInst[d.inst] = d end
        for _, z in ipairs(d.zones) do byZone[z] = d end
        d.list = {}
        for _, b in ipairs(d.bosses) do
            local id = b[1]
            if id == 0 then id = g.bossIds[d.key .. ":" .. b[2]] or ("n:" .. b[2]) end
            local e = { id = id, name = b[2], nameFR = b[3] or g.bossNames[d.key .. ":" .. b[2]], level = b[4], loot = b[5],
                        wing = b[6], encounter = (b[7] or 0) ~= 0 and b[7] or nil, dungeon = d }
            table.insert(d.list, e)
            if e.encounter then byEncounter[e.encounter] = e end
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
    local info = { quality = i[1], ilvl = i[2], req = i[3], drop = i[4], undiscovered = i[5] or false }
    -- pas de taux sur wowtbc.gg : taux observé par les joueurs (Everloot), meilleure source
    local ev = WK.EverDrops and WK.EverDrops[id]
    if not info.drop and ev then
        info.drop = ev[2] / 10
        info.observed = ev[3]
    end
    return info
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
    if self.run and self.run.killed[old] then self.run.killed[id] = self.run.killed[old]; self.run.killed[old] = nil end
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
    local L = WK.modules.ItemLock
    if L and L.Changed then L.Changed() else WK:NotifyChanged() end
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
M.run = nil -- { key, start = date, wait = vrai tant que le chrono attend le 1er combat, killed = { [boss] = date du kill }, skipped = { [boss] = true } }
-- le chrono part au premier combat dans le donjon (réglage timerStart = "pull", par défaut), ou dès l'entrée ("enter")
local function newRun(key)
    local wait = (M:Config().timerStart or "pull") == "pull" or nil
    return { key = key, start = time(), wait = wait, killed = {}, skipped = {} }
end
-- départ du chrono (premier combat, premier boss, ou chrono d'un membre du groupe)
function M:Begin(t)
    local run = self.run
    if not (run and run.wait) then return end
    run.wait = nil
    run.start = t or time()
    self:SyncHistory(run)
    if self.OnChange then pcall(self.OnChange, self) end
end
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
-- Parcours : le passage en cours concerne-t-il ce donjon ?
function M:InRun(d)
    return self.run ~= nil and d ~= nil and self.run.key == d.key
end
-- Boss facultatif (rare, boss caché) : sans n° de rencontre dans un donjon qui en a pour ses autres boss
function M:Optional(d, b)
    if b.encounter then return false end
    for _, x in ipairs(self:Bosses(d)) do if x.encounter then return true end end
    return false
end
-- Prochain boss du parcours : dans le donjon, le premier pas tué ni passé pendant ce passage ;
-- dehors, le premier que le perso n'a jamais tué (sinon le premier)
function M:Next(d, key)
    local inRun = self:InRun(d)
    local first
    for _, b in ipairs(self:Bosses(d)) do
        if not self:Optional(d, b) then
            first = first or b
            if inRun then
                if not self.run.killed[b.id] and not self.run.skipped[b.id] then return b end
            elseif not self:KilledEver(d, b.id, key) then
                return b
            end
        end
    end
    if inRun then return nil end
    return first
end
-- Passer un boss (ou le reprendre) pour ce passage
function M:Skip(d, b)
    if not self:InRun(d) then return end
    self.run.skipped[b.id] = (not self.run.skipped[b.id]) or nil
    if self.OnChange then self:OnChange() end
    WK:NotifyChanged()
end
function M:Skipped(d, b)
    return self:InRun(d) and self.run.skipped[b.id] or false
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
    if not M.run or M.run.key ~= d.key then
        M.run = newRun(d.key)
        local st = db(); st.runs = st.runs or {}; st.runs[WK:CharKey()] = M.run
    end
    if M.run.killed[b.id] then return end
    M:Begin()
    M.run.killed[b.id] = time()
    M.run.lastBoss, M.run.lastAt = b.id, time()
    M:SyncHistory(M.run)
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
-- Fin de rencontre réussie (ENCOUNTER_END, n° de rencontre des fichiers du jeu) : le boss est tué ;
-- le nom que donne le jeu (dans sa langue) devient le nom français du boss s'il manquait
WK:On("ENCOUNTER_END", function(encounterID, encounterName, _, _, success)
    if not WK:FeatureOn("dungeons") then return end
    local readable = WK.modules.QoL.Readable
    encounterID, success = readable(encounterID), readable(success)
    if type(encounterID) ~= "number" or (success ~= 1 and success ~= true) then return end
    if not byKey then index() end
    local b = byEncounter[encounterID]
    if not b then return end
    encounterName = readable(encounterName)
    if type(encounterName) == "string" and encounterName ~= "" and WK.Lang() == "frFR" and not b.nameFR then
        db().bossNames[b.dungeon.key .. ":" .. b.name] = encounterName
        b.nameFR = encounterName
    end
    record(b)
    M:RealBoss(b)
end)

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
-- module coupé : ni détection ni apprentissage des boss
local function active() return WK:FeatureOn("dungeons") and (M.run ~= nil or instanceNow() ~= nil) end
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
-- UNIT_HEALTH (très fréquent en groupe) : écouté seulement en instance, sur un cadre à part
local healthFrame = CreateFrame("Frame")
healthFrame:SetScript("OnEvent", function(_, _, unit)
    if type(unit) ~= "string" or not active() then return end
    if WATCH[unit] or unit:find("^boss%d") or unit:find("^nameplate%d") then
        local perf = WK.perf
        local t0 = perf and debugprofilestop and debugprofilestop()
        local ok, err = pcall(checkUnit, unit)
        if not ok and WK.RecordError then pcall(WK.RecordError, err, "", "UNIT_HEALTH") end
        if t0 then perf.add("évènement UNIT_HEALTH (donjon)", debugprofilestop() - t0) end
    end
end)
local function watchHealth()
    local inside = IsInInstance and select(2, IsInInstance())
    local want = WK:FeatureOn("dungeons") and (inside == "party" or inside == "raid" or M.run ~= nil)
    if want then pcall(healthFrame.RegisterEvent, healthFrame, "UNIT_HEALTH") else pcall(healthFrame.UnregisterEvent, healthFrame, "UNIT_HEALTH") end
end
M.WatchHealth = watchHealth
WK:On("PLAYER_ENTERING_WORLD", function() watchHealth() end)
WK:On("ZONE_CHANGED_NEW_AREA", function() C_Timer.After(1, watchHealth) end)
WK:On("PLAYER_TARGET_CHANGED", function() checkUnit("target") end)
WK:On("LOOT_OPENED", function()
    if not (active() and GetNumLootItems and GetLootSourceInfo) then return end
    if not byKey then index() end
    for i = 1, GetNumLootItems() do
        local ok, guid = pcall(GetLootSourceInfo, i)
        guid = ok and readable(guid) or nil
        -- corps du boss du Réal ouvert : le rappel s'arrête
        if guid and M.realPending and npcID(guid) == M.realPending.boss then M:OnRealClear() end
        if guid then
            pcall(onDeath, guid)
            local link = GetLootSlotLink and GetLootSlotLink(i)
            local item = link and WK:ParseItemID(link)
            if item then pcall(learnFromLoot, npcID(guid), item) end
        end
    end
end)

-- Entrée et sortie de donjon : alerte des envies ; le passage en cours est gardé (par perso, dans les données)
-- si on revient dans le même donjon moins d'1 h après en être sorti (wipe, cimetière dehors, /reload)
local lastKey
local RUN_KEEP = 3600
local function onZone()
    local d = M:Current()
    local store = db()
    store.runs = store.runs or {}
    local me = WK:CharKey()
    if d then
        if lastKey ~= d.key then
            local saved = store.runs[me]
            -- même copie : retour moins d'1 h après, sans réinitialisation entre-temps
            if saved and saved.key == d.key and (not saved.left or time() - saved.left < RUN_KEEP)
                and not (store.resetAt and (saved.left or saved.start) < store.resetAt) then
                saved.left = nil
                M.run = saved
            else
                M.run = newRun(d.key)
                M.run.st = M.Snapshot()
                store.runs[me] = M.run
                M:SyncHistory(M.run)
                M:CountEntry(d)
            end
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
        if M.run then
            M.run.left = time()
            M:LeaveSummary(M.run)
        end
        lastKey, M.run = nil, nil
        if M.OnRealClear then M:OnRealClear() end
    end
    if M.OnChange then M:OnChange() end
end

---------------------------------------------------------------------------
-- Limite d'instances : 10 nouvelles instances par heure glissante, pour tout le compte
-- (dungeons.entries = { { t, key, char } } ; une réinitialisation annoncée par le jeu ouvre une nouvelle copie)
---------------------------------------------------------------------------
M.CAP = 10
function M:Entries()
    local st = db()
    st.entries = st.entries or {}
    local now, keep = time(), {}
    for _, e in ipairs(st.entries) do if now - e.t < 3600 then table.insert(keep, e) end end
    st.entries = keep
    return keep
end
-- nombre cette heure, et secondes avant la prochaine place libre
function M:HourCount()
    local list = self:Entries()
    local free
    if #list > 0 then free = 3600 - (time() - list[1].t) end
    return #list, free
end
function M:CountEntry(d)
    local list = self:Entries()
    table.insert(list, { t = time(), key = d.key, char = WK:CharKey() })
    local n = #list
    if self:Config().capAlert and n >= self.CAP - 1 then
        local _, free = self:HourCount()
        local msg = n >= self.CAP and string.format(T("Limite d'instances atteinte (%d / %d) : prochaine place dans %d min."), n, self.CAP, math.ceil((free or 0) / 60))
            or string.format(T("Attention : %d / %d instances cette heure ; la prochaine place se libère dans %d min."), n, self.CAP, math.ceil((free or 0) / 60))
        WK:Print(msg)
        WK.modules.QoL:Remind("instCap", msg, 0.9, 0.4, 0.4, nil, { urgent = true, ttl = math.max(60, free or 0) })
    end
end
WK:On("CHAT_MSG_SYSTEM", function(msg)
    if type(msg) ~= "string" or not INSTANCE_RESET_SUCCESS then return end
    -- le « % » du format est échappé aussi, puis « %%s » (format échappé) devient une capture
    local pat = "^" .. INSTANCE_RESET_SUCCESS:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", "(.+)") .. "$"
    if msg:match(pat) then db().resetAt = time() end
end)

---------------------------------------------------------------------------
-- Résumé de sortie : expérience, argent, morts, réputation et groupe, depuis l'entrée dans la copie
---------------------------------------------------------------------------
function M.Snapshot()
    return { xp = UnitXP and UnitXP("player") or 0, xpMax = UnitXPMax and UnitXPMax("player") or 1,
        lvl = UnitLevel and UnitLevel("player") or 1, money = GetMoney and GetMoney() or 0, deaths = 0, rep = {} }
end
WK:On("PLAYER_DEAD", function() if M.run and M.run.st then M.run.st.deaths = (M.run.st.deaths or 0) + 1 end end)
WK:On("CHAT_MSG_COMBAT_FACTION_CHANGE", function(msg)
    local st = M.run and M.run.st
    if not st or type(msg) ~= "string" or not FACTION_STANDING_INCREASED then return end
    local pat = "^" .. FACTION_STANDING_INCREASED:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", "(.+)"):gsub("%%%%d", "(%%d+)") .. "$"
    local f, n = msg:match(pat)
    n = tonumber(n)
    if f and n then st.rep[f] = (st.rep[f] or 0) + n end
end)
function M:SummaryText(run)
    local st = run and run.st
    if not st then return nil end
    local d = self:Get(run.key)
    local lvl = (UnitLevel and UnitLevel("player")) or st.lvl
    local xp = (UnitXP and UnitXP("player")) or 0
    local gained = lvl == st.lvl and (xp - st.xp) or ((st.xpMax - st.xp) + xp)
    local money = ((GetMoney and GetMoney()) or 0) - st.money
    local parts = { string.format("%s %s", d and self:Name(d) or "?", self.Clock and self.Clock(time() - run.start) or "") }
    if gained > 0 and lvl < (GetMaxPlayerLevel and GetMaxPlayerLevel() or 60) then table.insert(parts, string.format(T("+%d XP"), gained)) end
    if money ~= 0 then table.insert(parts, WK:FormatMoney(math.abs(money)) .. (money < 0 and (" " .. T("dépensés")) or "")) end
    if (st.deaths or 0) > 0 then table.insert(parts, string.format(T("%d mort(s)"), st.deaths)) end
    local bestF, bestN
    for f, n in pairs(st.rep) do if not bestN or n > bestN then bestF, bestN = f, n end end
    if bestF then table.insert(parts, string.format("+%d %s", bestN, bestF)) end
    return table.concat(parts, " · ")
end
function M:LeaveSummary(run)
    local mode = self:Config().summary
    if mode == "off" or not run or not run.st or time() - run.start < 120 then return end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return end -- mort : on reviendra
    local txt = self:SummaryText(run)
    if not txt then return end
    WK:Print(txt)
    if mode == "group" and IsInGroup and IsInGroup() and SendChatMessage then
        -- message aux autres joueurs : sans codes de couleur
        local plain = txt:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        pcall(SendChatMessage, plain:sub(1, 250), IsInRaid and IsInRaid() and "RAID" or "PARTY")
    end
end

---------------------------------------------------------------------------
-- Réal de Terremine terni (objet 226404) : un par boss et par jour dans BRD, Pic Rochenoire, Hache-Tripes,
-- Scholomance et Stratholme. Après la 1re victoire du jour sur un de ces boss, rappel jusqu'au butin du corps.
---------------------------------------------------------------------------
M.REAL_ITEM = 226404
M.REAL_DUNGEONS = { [1584] = true, [1583] = true, [2557] = true, [2057] = true, [2017] = true }
M.realPending = nil -- { boss = n° de PNJ, name, at }
local function dayKey()
    local left = C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset and C_DateAndTime.GetSecondsUntilDailyReset()
    return left and math.floor((time() + left) / 3600) or date("%Y%m%d")
end
function M:RealBoss(b)
    if not (self:Config().real and b and b.dungeon and self.REAL_DUNGEONS[b.dungeon.key]) then return end
    local c = WK.DB:Me()
    c.realKills = c.realKills or {}
    local day = dayKey()
    if c.realKills.day ~= day then c.realKills = { day = day } end
    if c.realKills[b.id] then return end
    c.realKills[b.id] = true
    self.realPending = { boss = b.id, name = self:BossName(b), at = time() }
    if self.OnReal then self:OnReal(self.realPending) end
end
function M:OnRealClear() self.realPending = nil; if self.OnReal then self:OnReal(nil) end end
WK:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(1, onZone) end)
WK:On("ZONE_CHANGED_NEW_AREA", function() C_Timer.After(1, onZone) end)

-- Un objet d'une liste d'envies tombe (message de butin du groupe)
local dropSeen = {}
WK:On("CHAT_MSG_LOOT", function(msg)
    if not (M:Config().alertDrop and WK:FeatureOn("dungeons")) or type(msg) ~= "string" then return end
    if issecretvalue and issecretvalue(msg) then return end
    -- en donjon seulement (pas les achats chez un marchand), une fois par objet : un même butin donne
    -- plusieurs messages (Besoin, jet, gagné, reçu)
    if not (IsInInstance and IsInInstance()) then return end
    for idStr in msg:gmatch("item:(%d+)") do
        local id = tonumber(idStr)
        local last = dropSeen[id]
        if last and GetTime() - last < 120 then return end
        local wanted = false
        for _, w in pairs(db().wish) do if w[id] then wanted = true end end
        if wanted then dropSeen[id] = GetTime() end
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
-- Chrono, records, historique des loots, partage avec le groupe
--   dungeons.history[clé] = { { id, at (début), char, dur (passage complet, en s), splits = { [boss] = s depuis
--                               le début }, n, total, loot = { { id, who, at, boss } } } } (30 derniers)
--   dungeons.seen[objet] = nombre de fois vu tomber (messages de butin en donjon)
-- Les temps commencent à l'entrée dans le donjon ; rien avant cette version.
---------------------------------------------------------------------------
local HIST_MAX = 30
local function mainBosses(d)
    local out = {}
    for _, b in ipairs(M:Bosses(d)) do if not M:Optional(d, b) then table.insert(out, b) end end
    return out
end
function M:History(key)
    local st = db()
    st.history = st.history or {}
    st.history[key] = st.history[key] or {}
    return st.history[key]
end
-- recopie le passage dans l'historique (les tables des données ne se partagent pas d'une session à l'autre)
function M:SyncHistory(run)
    if not (run and run.key and run.start) then return end
    local d = self:Get(run.key)
    if not d then return end
    local list = self:History(run.key)
    local me = WK:CharKey()
    -- identifiant fixé une fois pour toutes : un partage qui recale le début ne crée pas de doublon
    run.hid = run.hid or (run.start .. ":" .. me)
    local id = run.hid
    local e
    for _, x in ipairs(list) do if x.id == id then e = x break end end
    if not e then
        -- pas d'entrée pour un passage sans boss ni butin (entré pour vendre, ressorti…)
        if not next(run.killed) and not (run.loot and #run.loot > 0) then return end
        e = { id = id, at = run.start, char = me, loot = {} }
        table.insert(list, 1, e)
        while #list > HIST_MAX do table.remove(list) end
    end
    e.splits = {}
    local n, total, last, complete = 0, 0, 0, true
    for _, b in ipairs(mainBosses(d)) do
        total = total + 1
        local k = run.killed[b.id]
        if k then
            n = n + 1
            e.splits[tostring(b.id)] = k - run.start
            last = math.max(last, k - run.start)
        else
            complete = false
        end
    end
    e.n, e.total = n, total
    e.dur = (complete and total > 0) and last or nil
    e.loot = run.loot or e.loot or {}
end
-- record (passage complet le plus rapide), moyenne des passages complets
-- exceptCurrent : sans le passage en cours (chrono, écarts, annonce : sinon, une fois le record battu, il se
-- compare à lui-même et tout affiche « -0:00 »)
function M:Record(d, exceptCurrent)
    local best, sum, cnt
    local cur = exceptCurrent and self.run and self.run.key == d.key and self.run.hid or nil
    for _, e in ipairs(self:History(d.key)) do
        if e.dur and e.id ~= cur then
            cnt = (cnt or 0) + 1; sum = (sum or 0) + e.dur
            if not best or e.dur < best.dur then best = e end
        end
    end
    return best, cnt and math.floor(sum / cnt) or nil, cnt or 0
end
-- temps depuis le début du passage en cours
function M:Elapsed()
    if not (self.run and self.run.start) then return nil end
    if self.run.wait then return 0 end
    local stop
    local d = self:Get(self.run.key)
    if d and not self:Next(d) then
        for _, t in pairs(self.run.killed) do stop = math.max(stop or 0, t) end
    end
    return (stop or time()) - self.run.start
end
-- écart avec le record à ce boss (secondes, négatif = en avance) ; nil sans record ou sans temps
function M:Delta(d, bossID)
    local rec = self:Record(d, true)
    if not (rec and self.run and self.run.key == d.key) then return nil end
    local k = self.run.killed[bossID]
    local r = rec.splits and rec.splits[tostring(bossID)]
    if not (k and r) then return nil end
    return (k - self.run.start) - r
end
function M:Seen(id) local s = db().seen; return s and s[id] or 0 end
function M.Clock(sec)
    if not sec then return "-" end
    sec = math.max(0, math.floor(sec))
    if sec >= 3600 then return string.format("%d:%02d:%02d", sec / 3600, (sec % 3600) / 60, sec % 60) end
    return string.format("%d:%02d", sec / 60, sec % 60)
end
function M.ClockDelta(sec)
    if not sec then return "" end
    return (sec <= 0 and "-" or "+") .. M.Clock(math.abs(sec))
end
-- tout ce qui est tombé dans ce donjon (tous passages), le plus récent d'abord
function M:LootHistory(d)
    local out = {}
    for _, e in ipairs(self:History(d.key)) do
        for _, l in ipairs(e.loot or {}) do table.insert(out, l) end
    end
    table.sort(out, function(a, b) return (a.at or 0) > (b.at or 0) end)
    return out
end

-- Butin reçu (message du jeu « X reçoit le butin : [objet] ») : historique et « vu tomber »
local function lootPattern(fmt)
    if type(fmt) ~= "string" then return nil end
    local p = fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    p = p:gsub("%%%%s", "(.+)"):gsub("%%%%d", "%%d+")
    return "^" .. p
end
local lootSeen = {}
WK:On("CHAT_MSG_LOOT", function(msg)
    if not (WK:FeatureOn("dungeons") and M.run) or type(msg) ~= "string" then return end
    if issecretvalue and issecretvalue(msg) then return end
    if not (IsInInstance and IsInInstance()) then return end
    local id = tonumber(msg:match("item:(%d+)"))
    if not (id and WK.DungeonItems and WK.DungeonItems[id]) then return end
    local who
    for _, g in ipairs({ "LOOT_ITEM_SELF", "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF" }) do
        local p = lootPattern(_G[g])
        if p and msg:match(p) then who = WK:CharKey() break end
    end
    if not who then
        for _, g in ipairs({ "LOOT_ITEM", "LOOT_ITEM_MULTIPLE" }) do
            local p = lootPattern(_G[g])
            local name = p and msg:match(p)
            if name then who = name break end
        end
    end
    if not who then return end
    local k = id .. ":" .. who
    if lootSeen[k] and GetTime() - lootSeen[k] < 5 then return end
    lootSeen[k] = GetTime()
    local run = M.run
    run.loot = run.loot or {}
    local boss = (run.lastAt and time() - run.lastAt < 180) and run.lastBoss or nil
    table.insert(run.loot, { id = id, who = who, at = time(), boss = boss and tostring(boss) or nil })
    local st = db()
    st.seen = st.seen or {}
    st.seen[id] = (st.seen[id] or 0) + 1
    M:SyncHistory(run)
    if M.OnChange then M:OnChange() end
    WK:NotifyChanged()
end)

-- Annonce dans le canal du groupe (clic du joueur)
local function groupChannel()
    if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInRaid and IsInRaid() then return "RAID" end
    if IsInGroup and IsInGroup() then return "PARTY" end
    return nil
end
function M:AnnounceText(d)
    if not self:InRun(d) then return nil end
    local main = mainBosses(d)
    local n, last = 0, nil
    for _, b in ipairs(main) do if self.run.killed[b.id] then n = n + 1; last = b end end
    local txt = string.format(T("%s : %d/%d boss en %s"), self:Name(d), n, #main, M.Clock(self:Elapsed()))
    local rec = self:Record(d, true)
    if rec then
        local dl = last and self:Delta(d, last.id)
        txt = txt .. string.format(T(" (record %s%s)"), M.Clock(rec.dur), dl and (", " .. M.ClockDelta(dl)) or "")
    end
    local nb = self:Next(d)
    if nb then txt = txt .. string.format(T(". Prochain : %s."), self:BossName(nb)) else txt = txt .. "." end
    return txt
end
function M:Announce(d)
    local ch, txt = groupChannel(), self:AnnounceText(d)
    if not txt then return false end
    if not ch then WK:Print(txt) return false end
    pcall(SendChatMessage, txt, ch)
    return true
end
-- Partage du parcours aux membres qui ont l'addon : boss tués (secondes depuis le début), temps écoulé
local SHARE = "WKrun"
function M:Share(d)
    local ch = groupChannel()
    if not (ch and self:InRun(d) and C_ChatInfo and C_ChatInfo.SendAddonMessage) or self.run.wait then return false end
    local parts = {}
    for b, t in pairs(self.run.killed) do table.insert(parts, tostring(b) .. "=" .. (t - self.run.start)) end
    local msg = "R:" .. d.key .. ":" .. self:Elapsed() .. ":" .. table.concat(parts, ";")
    if #msg > 250 then msg = msg:sub(1, 250) end
    local ok = pcall(C_ChatInfo.SendAddonMessage, SHARE, msg, ch)
    return ok
end
WK:On("PLAYER_LOGIN", function()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, SHARE) end
end)
-- déconnexion en plein passage : l'heure est notée, le passage n'est repris que dans l'heure (pas le lendemain)
WK:On("PLAYER_LOGOUT", function()
    local store = db()
    local saved = store.runs and store.runs[WK:CharKey()]
    if saved and not saved.left then saved.left = time() end
end)
local SHARE_CHANNELS = { PARTY = true, RAID = true, INSTANCE_CHAT = true }
WK:On("CHAT_MSG_ADDON", function(prefix, msg, channel, sender)
    local rd = WK.modules.QoL.Readable
    prefix, msg, channel, sender = rd(prefix), rd(msg), rd(channel), rd(sender)
    if prefix ~= SHARE or type(msg) ~= "string" then return end
    -- seulement le groupe (pas un chuchotement d'addon), et un chrono plausible (au plus 6 h)
    if not SHARE_CHANNELS[channel] then return end
    local key, elapsed, list = msg:match("^R:([^:]+):(%d+):(.*)$")
    elapsed = tonumber(elapsed)
    if not (key and elapsed and elapsed <= 6 * 3600 and M.run and tostring(M.run.key) == key) then return end
    local me = UnitName and UnitName("player")
    if type(sender) == "string" and me and sender:match("^[^%-]+") == me then return end
    local d = M:Get(M.run.key)
    if not d then return end
    -- son chrono a commencé plus tôt : on le reprend
    local start = time() - elapsed
    if M.run.wait then M:Begin(start) elseif start < M.run.start then M.run.start = start end
    local n = 0
    for bid, sec in list:gmatch("([^=;]+)=(%d+)") do
        for _, b in ipairs(M:Bosses(d)) do
            if tostring(b.id) == bid and not M.run.killed[b.id] then
                M.run.killed[b.id] = start + tonumber(sec); n = n + 1
            end
        end
    end
    M:SyncHistory(M.run)
    WK:Print(string.format(T("%s a partagé son parcours : %d boss en plus, chrono %s."), (function(n) n = tostring(n):match("^[^%-]+") or tostring(n); return WK.Latin and WK.Latin(n) or n end)(sender), n, M.Clock(elapsed)))
    if M.OnChange then M:OnChange() end
    WK:NotifyChanged()
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

-- premier combat dans le donjon du passage en cours : le chrono démarre
WK:On("PLAYER_REGEN_DISABLED", function()
    local run = M.run
    if not (run and run.wait) then return end
    local d = M:Current()
    if d and d.key == run.key then M:Begin() end
end)
