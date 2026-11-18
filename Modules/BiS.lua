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
