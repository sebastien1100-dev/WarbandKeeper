local ADDON_NAME, WK = ...
local M = WK:NewModule("BiS")
local T = function(s) return WK.T(s) end

-- Meilleur objet trouvable en donjon, par emplacement, pour un perso (onglet « BiS » de la fiche, UI/CharacterSheet.lua).
-- Candidats : butin des donjons (WK.DungeonsDB, sans les raids), niveau requis <= niveau visé, portable par la
-- classe (Dungeons:Usable). Score : caractéristiques de l'objet (GetItemStats) pondérées par classe, armure et
-- dégâts par seconde des armes. Les objets pas encore en cache sont demandés au jeu ; le calcul est refait quand
-- ils arrivent (GET_ITEM_INFO_RECEIVED).

-- Poids par classe (caractéristiques principales, armure, dégâts par seconde des armes)
M.WEIGHTS = {
    WARRIOR = { str = 1, agi = 0.7, sta = 0.8, int = 0, spi = 0.1, armor = 0.03, dps = 2.2 },
    ROGUE   = { str = 0.5, agi = 1, sta = 0.6, int = 0, spi = 0.1, armor = 0.02, dps = 2.2 },
    HUNTER  = { str = 0.1, agi = 1, sta = 0.6, int = 0.4, spi = 0.2, armor = 0.02, dps = 1.0, rangedDps = 2.4 },
    MAGE    = { str = 0, agi = 0, sta = 0.6, int = 1, spi = 0.5, armor = 0.01, dps = 0.2 },
    PRIEST  = { str = 0, agi = 0, sta = 0.5, int = 1, spi = 0.9, armor = 0.01, dps = 0.2 },
    WARLOCK = { str = 0, agi = 0, sta = 0.9, int = 0.9, spi = 0.4, armor = 0.01, dps = 0.2 },
    PALADIN = { str = 1, agi = 0.4, sta = 0.7, int = 0.6, spi = 0.3, armor = 0.03, dps = 2.0 },
    SHAMAN  = { str = 0.6, agi = 0.5, sta = 0.6, int = 0.8, spi = 0.4, armor = 0.02, dps = 1.6 },
    DRUID   = { str = 0.6, agi = 0.6, sta = 0.6, int = 0.8, spi = 0.5, armor = 0.02, dps = 0.8 },
}
local STAT = { ITEM_MOD_STRENGTH_SHORT = "str", ITEM_MOD_AGILITY_SHORT = "agi", ITEM_MOD_STAMINA_SHORT = "sta",
    ITEM_MOD_INTELLECT_SHORT = "int", ITEM_MOD_SPIRIT_SHORT = "spi", RESISTANCE0_NAME = "armor",
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "dps" }

-- Emplacements affichés : { n° d'emplacement, libellé, groupe }
M.SLOTS = {
    { 1, "Tête", "head" }, { 2, "Cou", "neck" }, { 3, "Épaules", "shoulder" }, { 15, "Dos", "back" },
    { 5, "Torse", "chest" }, { 9, "Poignets", "wrist" }, { 10, "Mains", "hands" }, { 6, "Taille", "waist" },
    { 7, "Jambes", "legs" }, { 8, "Pieds", "feet" }, { 11, "Doigt", "finger" }, { 12, "Doigt", "finger" },
    { 13, "Bijou", "trinket" }, { 14, "Bijou", "trinket" }, { 16, "Main droite", "main" }, { 17, "Main gauche", "off" },
    { 18, "Distance", "ranged" },
}
local LOC = {
    INVTYPE_HEAD = "head", INVTYPE_NECK = "neck", INVTYPE_SHOULDER = "shoulder", INVTYPE_CLOAK = "back",
    INVTYPE_CHEST = "chest", INVTYPE_ROBE = "chest", INVTYPE_WRIST = "wrist", INVTYPE_HAND = "hands",
    INVTYPE_WAIST = "waist", INVTYPE_LEGS = "legs", INVTYPE_FEET = "feet", INVTYPE_FINGER = "finger",
    INVTYPE_TRINKET = "trinket", INVTYPE_WEAPON = "main", INVTYPE_2HWEAPON = "main", INVTYPE_WEAPONMAINHAND = "main",
    INVTYPE_WEAPONOFFHAND = "off", INVTYPE_SHIELD = "off", INVTYPE_HOLDABLE = "off",
    INVTYPE_RANGED = "ranged", INVTYPE_RANGEDRIGHT = "ranged", INVTYPE_THROWN = "ranged", INVTYPE_RELIC = "ranged",
}
-- Classes qui manient une arme dans chaque main
local DUAL = { WARRIOR = 20, ROGUE = 10, HUNTER = 20 }

local function stats(link)
    local f = (C_Item and C_Item.GetItemStats) or GetItemStats
    if not f then return nil end
    local ok, s = pcall(f, link)
    if ok and type(s) == "table" then return s end
    return nil
end
local requested = {}
local function request(id)
    if requested[id] then return end
    requested[id] = true
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
end

-- Score d'un objet (lien ou n°) pour une classe ; nil tant que l'objet n'est pas en cache
function M:Score(item, class, slotGroup)
    local link = type(item) == "number" and ("item:" .. item) or item
    if type(item) == "number" and not WK.GetItemInfo(item) then request(item) return nil end
    local s = stats(link)
    if not s then return nil end
    local w = M.WEIGHTS[class or ""] or M.WEIGHTS.WARRIOR
    local total = 0
    for k, v in pairs(s) do
        local key = STAT[k]
        if key and type(v) == "number" then
            local wt = w[key] or 0
            if key == "dps" and slotGroup == "ranged" and w.rangedDps then wt = w.rangedDps end
            total = total + v * wt
        end
    end
    return total
end

local function groupOf(id)
    local _, _, loc = WK.modules.Dungeons.Instant(id)
    return loc and LOC[loc], loc
end

-- Candidats par groupe d'emplacement : { group = { { id, score, d, boss, drop }, ... triés } }
local cache = {}
function M:Candidates(c, level)
    local ck = (c.key or "") .. ":" .. level
    local hit = cache[ck]
    if hit and hit.at == M.stamp then return hit.list end
    local D = WK.modules.Dungeons
    local view = setmetatable({ level = level }, { __index = c })
    local out, seen = {}, {}
    for _, d in ipairs(D:All()) do
        if not d.raid then
            for _, g in ipairs(D:LootGroups(d)) do
                for _, id in ipairs(g.loot or {}) do
                    local info = D:ItemInfo(id)
                    if info and (info.req or 0) <= level and not seen[id] then
                        local grp, loc = groupOf(id)
                        if grp and (grp ~= "off" or loc ~= "INVTYPE_WEAPONOFFHAND" or DUAL[c.class or ""]) and D:Usable(id, view) then
                            local sc = self:Score(id, c.class, grp)
                            if sc and sc > 0 then
                                seen[id] = true
                                out[grp] = out[grp] or {}
                                table.insert(out[grp], { id = id, score = sc, d = d, boss = g, drop = info.drop, quality = info.quality })
                            end
                        end
                    end
                end
            end
        end
    end
    for _, list in pairs(out) do table.sort(list, function(a, b) return a.score > b.score end) end
    cache[ck] = { at = M.stamp, list = out }
    return out
end

-- Lignes de l'onglet : { { slot, label, worn = lien, wornScore, best = candidat ou nil, gain } }
function M:Rows(c, level)
    local cands = self:Candidates(c, level)
    local gear = c.gear or {}
    local rows, used = {}, {}
    for _, s in ipairs(M.SLOTS) do
        local slot, label, grp = s[1], s[2], s[3]
        local worn = gear[slot]
        local ws = worn and self:Score(worn, c.class, grp) or 0
        local best
        for _, e in ipairs(cands[grp] or {}) do
            -- deux anneaux / deux bijoux : pas deux fois le même ; pas l'objet déjà porté
            local wornId = worn and WK:ParseItemID(worn)
            if not used[e.id] and e.id ~= wornId then best = e break end
        end
        if best then used[best.id] = true end
        local gain = best and (best.score - ws) or 0
        if gain < 0.5 then best = nil; gain = 0 end
        table.insert(rows, { slot = slot, label = label, worn = worn, wornScore = ws, best = best, gain = gain })
    end
    return rows
end

M.stamp = 0
local pending = false
WK:On("GET_ITEM_INFO_RECEIVED", function()
    if pending then return end
    pending = true
    C_Timer.After(1, function() pending = false; M.stamp = M.stamp + 1; WK:NotifyChanged() end)
end)

---------------------------------------------------------------------------
-- Ma liste BiS : objets choisis à la main, par perso et par emplacement (WK.DB.global.bisList[perso][emplacement])
---------------------------------------------------------------------------
local function store()
    local g = WK.DB.global
    g.bisList = g.bisList or {}
    return g.bisList
end
function M:List(key)
    local s = store()
    s[key] = s[key] or {}
    return s[key]
end
function M:Set(key, slot, id)
    self:List(key)[slot] = id
    WK:NotifyChanged()
end
function M:ClearList(key)
    store()[key] = {}
    WK:NotifyChanged()
end
-- Remplit les emplacements vides avec le meilleur trouvable au niveau 60
function M:FillFromBest(c)
    local list = self:List(c.key)
    local n = 0
    for _, row in ipairs(self:Rows(c, 60)) do
        if row.best and not list[row.slot] then list[row.slot] = row.best.id; n = n + 1 end
    end
    WK:NotifyChanged()
    return n
end
-- Où tombe un objet : donjon et boss (ou monstres), % de drop
local sourceOf
function M:Source(id)
    if not sourceOf then
        sourceOf = {}
        local D = WK.modules.Dungeons
        for _, d in ipairs(D:All()) do
            for _, g in ipairs(D:LootGroups(d)) do
                for _, i in ipairs(g.loot or {}) do if not sourceOf[i] then sourceOf[i] = { d = d, boss = g } end end
            end
        end
    end
    local s = sourceOf[id]
    if not s then return nil end
    local info = WK.modules.Dungeons:ItemInfo(id)
    return s.d, s.boss, info and info.drop
end
-- Persos dont la liste BiS contient l'objet (noms)
function M:Holders(id)
    local out = {}
    for key, list in pairs(store()) do
        for _, v in pairs(list) do
            if v == id then
                local c = WK.DB.global.characters[key]
                if c then table.insert(out, WK:CharName(c, key)) end
                break
            end
        end
    end
    table.sort(out)
    return out
end

-- Infobulle : « Dans la liste BiS de … »
local function onTooltip(tt, data)
    if tt ~= GameTooltip and tt ~= ItemRefTooltip then return end
    local id = data and data.id
    if not id then return end
    local who = M:Holders(id)
    if #who == 0 then return end
    local r, g, b = WK.UI:Accent()
    tt:AddLine(string.format(T("Liste BiS de %s"), table.concat(who, ", ")), r, g, b, true)
    tt:Show()
end
if TooltipDataProcessor and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data) pcall(onTooltip, tt, data) end)
end
