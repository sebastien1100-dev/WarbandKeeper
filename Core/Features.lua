local ADDON_NAME, WK = ...

-- Modules de l'addon qu'on peut couper (carte « Modules » du Résumé).
-- Un module coupé : sa page quitte la barre latérale, ses infobulles et ce qu'il affiche à l'écran
-- disparaissent, ses actions s'arrêtent (filtre de loot, détection des rares, scan auto de l'HV, halo…).
-- Les relevés discrets (or, courrier, journal, quêtes faites) continuent : rien ne manque si on le remet.
-- Réglage : WK.DB.global.modulesOff[clé] = true (fait partie des profils).
-- Persos, Inventaire, Résumé, QoL (général), guidage et classes restent toujours actifs.
--   key, label, icon, group, page (page de la barre latérale), desc, reload (élément à l'écran :
--   proposer un /reload pour qu'il disparaisse ou revienne proprement)
WK.FEATURES = {
    { key = "stats", label = "Stats", icon = "chart", group = "ÉCONOMIE", page = "stats" },
    { key = "professions", label = "Métiers", icon = "hammer", group = "ÉCONOMIE", page = "professions", desc = "page et infobulle" },
    { key = "mail", label = "Règles d'envoi", icon = "mail", group = "ÉCONOMIE", page = "mail" },
    { key = "ah", label = "Hôtel des ventes", icon = "coin", group = "ÉCONOMIE", qol = "ah", desc = "scan et infobulle" },
    { key = "farm", label = "Session de farm", icon = "play", group = "FARM", page = "farm" },
    { key = "loot", label = "Filtre de loot", icon = "filter", group = "FARM", page = "loot" },
    { key = "journal", label = "Journal", icon = "clock", group = "FARM", page = "journal" },
    { key = "lfg", label = "LFG", icon = "lfg", group = "GROUPE", page = "lfg" },
    { key = "quests", label = "Quêtes", icon = "bang", group = "EXPLORATION", page = "quests", desc = "page et donneurs" },
    { key = "rares", label = "Rares", icon = "star", group = "EXPLORATION", page = "rares", desc = "page, carte, alerte" },
    { key = "maplayers", label = "Carte", icon = "map", group = "EXPLORATION", qol = "maplayers", desc = "lieux et trajets" },
    { key = "nodes", label = "Récolte", icon = "tree", group = "EXPLORATION", desc = "filons et plantes" },
    { key = "halo", label = "Halo", icon = "spark", group = "CONFORT", qol = "halo", reload = true },
    { key = "micro", label = "Micro menu", icon = "clock", group = "CONFORT", qol = "micro", reload = true },
    { key = "fishing", label = "Pêche", icon = "fish", group = "CONFORT", qol = "fishing", page = "fishing", reload = true },
    { key = "range", label = "Distance", icon = "crosshair", group = "CONFORT", desc = "ruban de distance du chasseur", reload = true },
}
WK.FEATURE_BY_PAGE, WK.FEATURE_BY_QOL = {}, {}
for _, f in ipairs(WK.FEATURES) do
    if f.page then WK.FEATURE_BY_PAGE[f.page] = f.key end
    if f.qol then WK.FEATURE_BY_QOL[f.qol] = f.key end
end

local function off()
    local g = WK.DB and WK.DB.global
    if not g then return {} end
    g.modulesOff = g.modulesOff or {}
    return g.modulesOff
end
-- Le module est-il actif ? (clé inconnue : oui)
function WK:FeatureOn(key)
    return not off()[key]
end
function WK:PageOn(page)
    local k = WK.FEATURE_BY_PAGE[page]
    return not k or WK:FeatureOn(k)
end
-- Active ou coupe un module, puis prévient les parties qui en dépendent
function WK:SetFeature(key, on)
    off()[key] = (not on) or nil
    if WK.UI then
        local UI = WK.UI
        if UI.layoutTop then UI.layoutTop() end
        if UI.SyncClock then UI:SyncClock() end
        if UI.SyncRange then UI:SyncRange() end
        if UI.SyncFishingBar then UI:SyncFishingBar() end
        if UI.RefreshNodePins then UI:RefreshNodePins() end
        if UI.RedrawRarePins then UI:RedrawRarePins() end
        if UI.RefreshMapLayers then UI:RefreshMapLayers() end
    end
    if key == "fishing" and not on and WK.modules.Fishing and WK.modules.Fishing.active then WK.modules.Fishing:Stop() end
    if key == "halo" and WK.modules.Glow and WK.modules.Glow.Update then pcall(WK.modules.Glow.Update, WK.modules.Glow) end
    WK:NotifyChanged()
end
function WK:FeatureCount()
    local n = 0
    for _, f in ipairs(WK.FEATURES) do if WK:FeatureOn(f.key) then n = n + 1 end end
    return n, #WK.FEATURES
end
