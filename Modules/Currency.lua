local _, WK = ...
local M = WK:NewModule("Currency")

-- Monnaies du jeu, par perso et pour tout le compte (page Inventaire > Monnaies, UI/Currency.lua).
-- Deux sources :
--   * les monnaies qui sont des objets (marques de champ de bataille, insignes, pièces de Zul'Gurub, scarabées
--     d'Ahn'Qiraj, tickets de la foire) : comptées dans les sacs, la banque et le courrier déjà relevés
--     (Inventory:CharCount) ;
--   * l'onglet Monnaies du jeu, quand le client en a un (C_CurrencyInfo ou GetCurrencyListInfo) : relevé à
--     chaque connexion et à chaque changement dans c.currencies = { [nom] = { q = quantité, icon = icône } }.
-- List(cat) rend { { key, item?, name, icon, cat, per = { [perso] = n }, total } } triée par catégorie puis nom.

-- catégories : pvp (champs de bataille), rep (réputation), raid (raids), event (évènements)
M.CATS = { { "pvp", "JcJ" }, { "rep", "Réputations" }, { "raid", "Raids" }, { "event", "Évènements" },
    { "game", "Jeu" } }
M.WHERE = {
    pvp = "S'échangent chez les intendants des champs de bataille et servent aux quêtes de marques,"
        .. " dans les capitales.",
    rep = "À rendre à l'Aube d'argent contre de la réputation et des jetons.",
    raid = "À rendre contre de la réputation et des récompenses de raid.",
    event = "Foire de Sombrelune : à échanger contre des prix quand elle est ouverte.",
    game = "Onglet Monnaies du jeu.",
}
local ITEMS = {
    { 20560, "pvp" }, { 20559, "pvp" }, { 20558, "pvp" },              -- marques d'Alterac, d'Arathi, des Chanteguerres
    { 12844, "rep" }, { 12840, "rep" }, { 12841, "rep" }, { 12843, "rep" }, -- jeton de valeur, pierres du Fléau
    { 19698, "raid" }, { 19699, "raid" }, { 19700, "raid" }, { 19701, "raid" }, { 19702, "raid" }, -- pièces de ZG
    { 19703, "raid" }, { 19704, "raid" }, { 19705, "raid" }, { 19706, "raid" },
    { 20858, "raid" }, { 20859, "raid" }, { 20860, "raid" }, { 20861, "raid" }, -- scarabées d'Ahn'Qiraj
    { 20862, "raid" }, { 20863, "raid" }, { 20864, "raid" }, { 20865, "raid" },
    { 19182, "event" },                                                 -- ticket de la foire de Sombrelune
}
M.ITEMS = ITEMS
local ORDER = {}
for i, c in ipairs(M.CATS) do ORDER[c[1]] = i end

-- Relevé de l'onglet Monnaies du jeu (rien si le client n'en a pas)
function M.Scan(_)
    local c = WK.DB:Me()
    local out, n = {}, 0
    local CI = _G.C_CurrencyInfo
    if CI and CI.GetCurrencyListSize and CI.GetCurrencyListInfo then
        local ok, size = pcall(CI.GetCurrencyListSize)
        for i = 1, (ok and size or 0) do
            local ok2, info = pcall(CI.GetCurrencyListInfo, i)
            if ok2 and type(info) == "table" and not info.isHeader and info.name and (info.quantity or 0) > 0 then
                out[info.name] = { q = info.quantity, icon = info.iconFileID }
                n = n + 1
            end
        end
    elseif _G.GetCurrencyListSize and _G.GetCurrencyListInfo then
        local ok, size = pcall(_G.GetCurrencyListSize)
        for i = 1, (ok and size or 0) do
            local ok2, name, isHeader, _, _, _, count, icon = pcall(_G.GetCurrencyListInfo, i)
            if ok2 and name and not isHeader and (count or 0) > 0 then
                out[name] = { q = count, icon = icon }
                n = n + 1
            end
        end
    else
        return
    end
    c.currencies = out
    return n
end

function M:OnLogin() self:Scan() end
do
    local f = _G.CreateFrame("Frame")
    pcall(f.RegisterEvent, f, "CURRENCY_DISPLAY_UPDATE")
    pcall(f.RegisterEvent, f, "PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function() if WK.DB and WK.DB.global then M:Scan() end end)
end

-- Toutes les monnaies présentes sur le compte (cat : une catégorie, ou nil pour tout)
function M.List(_, cat)
    local chars = WK.DB.global.characters
    local Inv = WK.modules.Inventory
    local rows = {}
    for _, d in ipairs(ITEMS) do
        local id, ccat = d[1], d[2]
        if not cat or cat == ccat then
            local r = { key = "i" .. id, item = id, cat = ccat, per = {}, total = 0 }
            for key, c in pairs(chars) do
                local n = Inv:CharCount(c, id)
                if n > 0 then r.per[key] = n; r.total = r.total + n end
            end
            if r.total > 0 then
                local name, _, _, _, _, _, _, _, _, icon = WK.GetItemInfo(id)
                r.name, r.icon = name or ("#" .. id), icon
                rows[#rows + 1] = r
            end
        end
    end
    if not cat or cat == "game" then
        local byName = {}
        for key, c in pairs(chars) do
            for name, v in pairs(c.currencies or {}) do
                local r = byName[name]
                if not r then
                    r = { key = "c" .. name, name = name, icon = v.icon, cat = "game", per = {}, total = 0 }
                    byName[name] = r
                    rows[#rows + 1] = r
                end
                r.per[key] = (r.per[key] or 0) + (v.q or 0)
                r.total = r.total + (v.q or 0)
            end
        end
    end
    table.sort(rows, function(a, b)
        if a.cat ~= b.cat then return (ORDER[a.cat] or 9) < (ORDER[b.cat] or 9) end
        return a.name < b.name
    end)
    return rows
end

-- Détail d'une monnaie objet pour un perso : total, sacs, banque, courrier
function M.Split(_, key, itemID)
    local c = WK.DB.global.characters[key]
    if not c or not itemID then return nil end
    return WK.modules.Inventory:CharCount(c, itemID)
end
