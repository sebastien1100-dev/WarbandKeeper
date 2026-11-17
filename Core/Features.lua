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
    -- groupes = ceux de la barre latérale (UI/MainFrame.lua), chacun d'un seul tenant (une ligne de la carte Modules)
    { key = "stats", label = "Stats", icon = "chart", group = "TRÉSORERIE", page = "stats" },
    { key = "mail", label = "Règles d'envoi", icon = "mail", group = "TRÉSORERIE", page = "mail" },
    { key = "ah", label = "Hôtel des ventes", icon = "coin", group = "TRÉSORERIE", qol = "ah", desc = "scan et infobulle" },
    { key = "professions", label = "Métiers", icon = "hammer", group = "ARTISANAT", page = "professions", desc = "page et infobulle" },
    { key = "fishing", label = "Pêche", icon = "fish", group = "ARTISANAT", qol = "fishing", page = "fishing", reload = true },
    { key = "farm", label = "Session de farm", icon = "play", group = "BUTIN", page = "farm" },
    { key = "loot", label = "Filtre de loot", icon = "filter", group = "BUTIN", page = "loot" },
    { key = "journal", label = "Journal", icon = "clock", group = "BUTIN", page = "journal" },
    { key = "quests", label = "Quêtes", icon = "bang", group = "AVENTURE", page = "quests", desc = "page et donneurs" },
    { key = "rares", label = "Rares", icon = "star", group = "AVENTURE", page = "rares", desc = "page, carte, alerte" },
    { key = "dungeons", label = "Donjons", icon = "skull", group = "AVENTURE", page = "dungeons", desc = "boss, butin, envies" },
    { key = "lfg", label = "LFG", icon = "lfg", group = "AVENTURE", page = "lfg" },
    { key = "maplayers", label = "Carte", icon = "map", group = "AVENTURE", qol = "maplayers", desc = "lieux et trajets" },
    { key = "nodes", label = "Récolte", icon = "tree", group = "AVENTURE", desc = "filons et plantes" },
    { key = "halo", label = "Halo", icon = "spark", group = "RÉGLAGES QOL", qol = "halo", reload = true },
    { key = "micro", label = "Micro menu", icon = "clock", group = "RÉGLAGES QOL", qol = "micro", reload = true },
    { key = "cursor", label = "Curseur", icon = "crosshair", group = "RÉGLAGES QOL", qol = "cursor", desc = "anneau et curseur gardé en combat", reload = true },
    { key = "range", label = "Distance", icon = "crosshair", group = "RÉGLAGES QOL", desc = "ruban de distance du chasseur", reload = true },
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
