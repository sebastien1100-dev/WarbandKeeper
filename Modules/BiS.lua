local ADDON_NAME, WK = ...
local M = WK:NewModule("BiS")
local T = function(s) return WK.T(s) end

-- Ma liste BiS (onglet « BiS » de la fiche, UI/CharacterSheet.lua) : un objet choisi à la main par emplacement
-- et par perso. Source de l'objet (donjon, boss, %) lue dans les données des donjons ; ligne dans l'infobulle.

-- Emplacements affichés : { n° d'emplacement, libellé, groupe }
M.SLOTS = {
    { 1, "Tête", "head" }, { 2, "Cou", "neck" }, { 3, "Épaules", "shoulder" }, { 15, "Dos", "back" },
    { 5, "Torse", "chest" }, { 4, "Chemise", "shirt" }, { 19, "Tabard", "tabard" }, { 9, "Poignets", "wrist" }, { 10, "Mains", "hands" }, { 6, "Taille", "waist" },
    { 7, "Jambes", "legs" }, { 8, "Pieds", "feet" }, { 11, "Doigt", "finger" }, { 12, "Doigt", "finger" },
    { 13, "Bijou", "trinket" }, { 14, "Bijou", "trinket" }, { 16, "Main droite", "main" }, { 17, "Main gauche", "off" },
    { 18, "Distance", "ranged" },
}
---------------------------------------------------------------------------
-- Listes BiS : plusieurs par perso, une affichée (« active »), objets choisis à la main par emplacement.
--   WK.DB.global.bisLists[perso] = { lists = { { name, items = { [emplacement] = objet } } }, active = n° }
-- (reprend l'ancienne liste unique WK.DB.global.bisList[perso] à la première lecture)
---------------------------------------------------------------------------
local function store(key)
    local g = WK.DB.global
    g.bisLists = g.bisLists or {}
    local s = g.bisLists[key]
    if not s then
        s = { lists = {} }
        local old = g.bisList and g.bisList[key]
        if old and next(old) then table.insert(s.lists, { name = T("Ma liste BiS"), items = old }) end
        if g.bisList then g.bisList[key] = nil end
        if #s.lists == 0 then table.insert(s.lists, { name = T("Ma liste BiS"), items = {} }) end
        s.active = 1
        g.bisLists[key] = s
    end
    if not s.lists[s.active or 0] then s.active = 1 end
    if #s.lists == 0 then table.insert(s.lists, { name = T("Ma liste BiS"), items = {} }) end
    return s
end
function M:Lists(key) return store(key).lists end
function M:ActiveIndex(key) return store(key).active end
function M:SetActiveList(key, i) store(key).active = i; WK:NotifyChanged() end
-- Objets de la liste affichée : [emplacement] = objet
function M:List(key)
    local s = store(key)
    return s.lists[s.active].items
end
function M:Set(key, slot, id)
    self:List(key)[slot] = id
    WK:NotifyChanged()
end
function M:ClearList(key)
    local s = store(key)
    s.lists[s.active].items = {}
    WK:NotifyChanged()
end
function M:NewList(key, name, items)
    local s = store(key)
    local copy = {}
    for k, v in pairs(items or {}) do copy[k] = v end
    table.insert(s.lists, { name = name, items = copy })
    s.active = #s.lists
    WK:NotifyChanged()
    return s.active
end
function M:RenameList(key, i, name)
    local l = store(key).lists[i]
    if l and name and name ~= "" then l.name = name; WK:NotifyChanged() end
end
function M:DeleteList(key, i)
    local s = store(key)
    table.remove(s.lists, i)
    if #s.lists == 0 then table.insert(s.lists, { name = T("Ma liste BiS"), items = {} }) end
    if s.active >= i then s.active = math.max(1, s.active - 1) end
    WK:NotifyChanged()
end
-- Code de partage : WKB1:emplacement=objet,…
function M:ExportList(key, i)
    local l = store(key).lists[i]
    if not l then return nil end
    local parts = {}
    for _, sl in ipairs(M.SLOTS) do
        local id = l.items[sl[1]]
        if id then table.insert(parts, sl[1] .. "=" .. id) end
    end
    return "WKB1:" .. table.concat(parts, ",")
end
function M:ImportList(key, code, name)
    local body = (code or ""):match("^%s*WKB1:([%d=,]*)%s*$")
    if not body then return nil, T("code non reconnu") end
    local items = {}
    for slot, id in body:gmatch("(%d+)=(%d+)") do items[tonumber(slot)] = tonumber(id) end
    if not next(items) then return nil, T("code vide") end
    return self:NewList(key, name or T("Liste importée"), items)
end
-- Équipe les objets de la liste affichée déjà dans les sacs (perso connecté, hors combat) ; rend le nombre
function M:EquipOwned()
    if InCombatLockdown and InCombatLockdown() then return 0, T("pas en combat") end
    local key = WK:CharKey()
    local c = WK.DB:Me()
    local f = (C_Item and C_Item.EquipItemByName) or EquipItemByName
    if not f then return 0, T("le jeu ne permet pas à l'addon d'équiper") end
    local worn = {}
    for _, l in pairs(c.gear or {}) do local id = WK:ParseItemID(l); if id then worn[id] = true end end
    local n = 0
    for slot, id in pairs(self:List(key)) do
        local gearId = c.gear and c.gear[slot] and WK:ParseItemID(c.gear[slot])
        if gearId ~= id and c.bags and c.bags[id] then
            if pcall(f, id, slot) then n = n + 1 end
        end
    end
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
-- Persos dont une liste BiS contient l'objet : « Perso (nom de la liste) »
function M:Holders(id)
    local out = {}
    for key, st in pairs(WK.DB.global.bisLists or {}) do
        local c = WK.DB.global.characters[key]
        for _, l in ipairs(st.lists or {}) do
            for _, v in pairs(l.items or {}) do
                if v == id and c then
                    table.insert(out, WK:CharName(c, key) .. (#st.lists > 1 and (" (" .. (l.name or "") .. ")") or ""))
                    break
                end
            end
        end
    end
    table.sort(out)
    return out
end

-- Repère dans les sacs : « mine » (une liste du perso connecté), « other » (liste d'un autre perso), nil
-- (ensemble recalculé au plus une fois par seconde : appelé pour chaque case des sacs ouverts)
local markSet, markAt = nil, -10
function M:Mark(id)
    if not id then return nil end
    local now = GetTime and GetTime() or 0
    if not markSet or now - markAt > 1 or now < markAt then
        markSet, markAt = {}, now
        local me = WK:CharKey()
        for key, st in pairs(WK.DB.global.bisLists or {}) do
            local mine = key == me
            if WK.DB.global.characters[key] then
                for _, l in ipairs(st.lists or {}) do
                    for _, v in pairs(l.items or {}) do
                        if mine then markSet[v] = "mine" elseif not markSet[v] then markSet[v] = "other" end
                    end
                end
            end
        end
    end
    return markSet[id]
end

---------------------------------------------------------------------------
-- Tous les objets portables du jeu (Modules/ItemsDB.lua, généré) : candidats d'un emplacement, avec filtres
---------------------------------------------------------------------------
-- emplacement » groupes de WK.ItemsDB
local GROUPS = {
    [1] = { "head" }, [2] = { "neck" }, [3] = { "shoulder" }, [15] = { "back" }, [5] = { "chest" }, [9] = { "wrist" },
    [10] = { "hands" }, [6] = { "waist" }, [7] = { "legs" }, [8] = { "feet" }, [11] = { "finger" }, [12] = { "finger" },
    [13] = { "trinket" }, [14] = { "trinket" }, [16] = { "main", "one", "two" }, [17] = { "off" }, [18] = { "ranged" },
    [4] = { "shirt" }, [19] = { "tabard" },
}
local DUAL = { WARRIOR = true, ROGUE = true, HUNTER = true, SHAMAN = true }
local PROF = { [164] = "Forge", [165] = "Travail du cuir", [171] = "Alchimie", [197] = "Couture", [202] = "Ingénierie",
    [333] = "Enchantement", [185] = "Cuisine", [129] = "Secourisme", [755] = "Joaillerie" }
M.ARMOR = { [1] = "Tissu", [2] = "Cuir", [3] = "Mailles", [4] = "Plaques" }
local byGroup, byId
local function index()
    byGroup, byId = {}, {}
    for _, e in ipairs(WK.ItemsDB or {}) do
        byGroup[e[2]] = byGroup[e[2]] or {}
        table.insert(byGroup[e[2]], e)
        byId[e[1]] = e
    end
end
function M:Info(id)
    if not byId then index() end
    return byId[id]
end
-- Source d'un objet : genre ("dungeon", "raid", "craft", "quest", "other") et texte
function M:SourceOf(id)
    local d, boss, drop = self:Source(id)
    if d then
        local D = WK.modules.Dungeons
        local txt = (d.raid and (T("Raid") .. " · ") or "") .. D:Name(d) .. " · " .. (boss.trash and T("monstres") or D:BossName(boss))
        if drop then txt = txt .. string.format(" · %s %%", string.format("%.0f", drop)) end
        return d.raid and "raid" or "dungeon", txt
    end
    local e = self:Info(id)
    local src = e and e[10] or ""
    local skill, rank = src:match("^c(%d+):(%d+)$")
    if skill then return "craft", string.format(T("Artisanat · %s %s"), T(PROF[tonumber(skill)] or "?"), rank) end
    local q = src:match("^q(%d+)$")
    if q then
        local Q = WK.modules.Quests
        local qq = Q and Q.Get and Q:Get(tonumber(q))
        local name = qq and Q:Name(qq)
        return "quest", T("Quête") .. " · " .. (type(name) == "string" and name or ("n° " .. q))
    end
    return "other", T("autre source")
end
-- Objets pour un emplacement : f = { query, source, armor, quality, level }, c = perso (classe)
function M:Candidates(slot, c, f)
    if not byGroup then index() end
    f = f or {}
    local D = WK.modules.Dungeons
    local view = setmetatable({ level = 60 }, { __index = c })
    local groups = {}
    for _, g in ipairs(GROUPS[slot] or {}) do groups[#groups + 1] = g end
    if slot == 17 and DUAL[c.class or ""] then groups[#groups + 1] = "one" end
    local q = f.query and f.query ~= "" and f.query:lower() or nil
    local out = {}
    for _, g in ipairs(groups) do
        for _, e in ipairs(byGroup[g] or {}) do
            local ok = (not q or e[8]:lower():find(q, 1, true))
                and (not f.quality or e[5] >= f.quality)
                and (not f.level or (e[7] >= f.level[1] and e[7] <= f.level[2]))
                and (not f.armor or (e[3] == 4 and e[4] == f.armor) or (e[3] == 4 and e[4] == 0))
            if ok and D:Usable(e[1], view) then
                if f.source and f.source ~= "all" then ok = self:SourceOf(e[1]) == f.source end
                if ok then out[#out + 1] = e end
            end
        end
    end
    table.sort(out, function(a, b) if a[6] ~= b[6] then return a[6] > b[6] end return a[8] < b[8] end)
    return out
end
-- Types d'armure que la classe peut porter au niveau 60 (filtres de la fenêtre de choix)
function M:ArmorTypes(c)
    local D = WK.modules.Dungeons
    local out = {}
    local view = setmetatable({ level = 60 }, { __index = c })
    for sub = 1, 4 do
        -- un objet d'armure de ce type, pour demander à Dungeons:Usable
        if not byGroup then index() end
        for _, e in ipairs(byGroup.chest or {}) do
            if e[3] == 4 and e[4] == sub then
                if D:Usable(e[1], view) then out[#out + 1] = sub end
                break
            end
        end
    end
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
