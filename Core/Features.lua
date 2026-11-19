local ADDON_NAME, WK = ...

-- Modules de l'addon qu'on peut couper (carte « Modules » du Résumé).
-- Un module coupé : sa page quitte la barre latérale, ses infobulles et ce qu'il affiche à l'écran
-- disparaissent, ses actions s'arrêtent (filtre de loot, détection des rares, scan auto de l'HV, halo…).
-- Les relevés discrets (or, courrier, journal, quêtes faites) continuent : rien ne manque si on le remet.
-- Réglage : WK.DB.global.modulesOff[clé] = true (fait partie des profils).
-- Résumé et guidage restent toujours actifs ; Persos, Inventaire, Général et Classes ne font que masquer leur entrée.
--   key, label, icon, group, page (page de la barre latérale), desc, reload (élément à l'écran :
--   proposer un /reload pour qu'il disparaisse ou revienne proprement)
WK.FEATURES = {
    -- miroir de la barre latérale (UI/MainFrame.lua) : chaque entrée y a son interrupteur, dans le même groupe,
    -- et chaque groupe est d'un seul tenant (une ligne de la carte Modules) ; en plus : Récolte et Distance
    { key = "characters", label = "Persos", icon = "users", group = "MES PERSOS", page = "characters", desc = "page et fiches" },
    { key = "inventory", label = "Inventaire", icon = "bag", group = "MES PERSOS", page = "inventory", desc = "page" },
    { key = "classes", label = "Classes", icon = "users", group = "MES PERSOS", qol = "classes", desc = "section des réglages" },
    { key = "xp", label = "Expérience", icon = "chart", group = "MES PERSOS", qol = "xp", desc = "barre, repos, quêtes à rendre" },
    { key = "range", label = "Distance", icon = "arrow", group = "MES PERSOS", desc = "ruban de distance du chasseur", reload = true },
    { key = "stats", label = "Stats", icon = "chart", group = "ARGENT", page = "stats" },
    { key = "mail", label = "Courrier", icon = "mail", group = "ARGENT", page = "mail" },
    { key = "ah", label = "Hôtel des ventes", icon = "coin", group = "ARGENT", page = "auction", desc = "prix, scan, vente, alertes" },
    { key = "journal", label = "Journal", icon = "clock", group = "ARGENT", page = "journal" },
    { key = "professions", label = "Métiers", icon = "hammer", group = "ARTISANAT", page = "professions", desc = "page et infobulle" },
    { key = "fishing", label = "Pêche", icon = "fish", group = "ARTISANAT", qol = "fishing", page = "fishing", desc = "collection, carnet et réglages", reload = true },
    { key = "campfire", label = "Feu de camp", icon = "fire", group = "ARTISANAT", qol = "campfire", desc = "rappel pour s'asseoir près d'un camp", reload = true },
    { key = "nodes", label = "Récolte", icon = "tree", group = "ARTISANAT", desc = "filons et plantes" },
    { key = "farm", label = "Session de farm", icon = "play", group = "FARM", page = "farm" },
    { key = "loot", label = "Filtre de loot", icon = "filter", group = "FARM", page = "loot" },
    { key = "quests", label = "Quêtes", icon = "bang", group = "AVENTURE", page = "quests", desc = "page et donneurs" },
    { key = "rares", label = "Rares", icon = "star", group = "AVENTURE", page = "rares", desc = "page, carte, alerte" },
    { key = "dungeons", label = "Donjons", icon = "skull", group = "AVENTURE", page = "dungeons", desc = "boss, butin, envies" },
    { key = "lfg", label = "LFG", icon = "lfg", group = "AVENTURE", page = "lfg" },
    { key = "maplayers", label = "Carte et guidage", icon = "map", group = "AVENTURE", qol = "maplayers", desc = "lieux, guidage, trajets" },
    { key = "qolgeneral", label = "Général", icon = "gear", group = "INTERFACE", qol = "general", desc = "section des réglages" },
    { key = "halo", label = "Halo", icon = "spark", group = "INTERFACE", qol = "halo", reload = true },
    { key = "cursor", label = "Curseur", icon = "crosshair", group = "INTERFACE", qol = "cursor", desc = "anneau et curseur gardé en combat", reload = true },
    { key = "micro", label = "Micro menu", icon = "menu", group = "INTERFACE", qol = "micro", reload = true },
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
