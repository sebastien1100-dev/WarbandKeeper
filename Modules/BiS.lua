local ADDON_NAME, WK = ...
local M = WK:NewModule("BiS")
local T = function(s) return WK.T(s) end

-- Ma liste BiS (onglet « BiS » de la fiche, UI/CharacterSheet.lua) : un objet choisi à la main par emplacement
-- et par perso. Source de l'objet (donjon, boss, %) lue dans les données des donjons ; ligne dans l'infobulle.

-- Emplacements affichés : { n° d'emplacement, libellé, groupe }
M.SLOTS = {
    { 1, "Tête", "head" }, { 2, "Cou", "neck" }, { 3, "Épaules", "shoulder" }, { 15, "Dos", "back" },
    { 5, "Torse", "chest" }, { 9, "Poignets", "wrist" }, { 10, "Mains", "hands" }, { 6, "Taille", "waist" },
    { 7, "Jambes", "legs" }, { 8, "Pieds", "feet" }, { 11, "Doigt", "finger" }, { 12, "Doigt", "finger" },
    { 13, "Bijou", "trinket" }, { 14, "Bijou", "trinket" }, { 16, "Main droite", "main" }, { 17, "Main gauche", "off" },
    { 18, "Distance", "ranged" },
}
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

---------------------------------------------------------------------------
-- Tous les objets portables du jeu (Modules/ItemsDB.lua, généré) : candidats d'un emplacement, avec filtres
---------------------------------------------------------------------------
-- emplacement » groupes de WK.ItemsDB
local GROUPS = {
    [1] = { "head" }, [2] = { "neck" }, [3] = { "shoulder" }, [15] = { "back" }, [5] = { "chest" }, [9] = { "wrist" },
    [10] = { "hands" }, [6] = { "waist" }, [7] = { "legs" }, [8] = { "feet" }, [11] = { "finger" }, [12] = { "finger" },
    [13] = { "trinket" }, [14] = { "trinket" }, [16] = { "main", "one", "two" }, [17] = { "off" }, [18] = { "ranged" },
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
