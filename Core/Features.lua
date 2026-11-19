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
    { key = "characters", label = "Persos", icon = "users", group = "BATAILLON", page = "characters", desc = "page et fiches" },
    { key = "inventory", label = "Inventaire", icon = "bag", group = "BATAILLON", page = "inventory", desc = "page" },
    { key = "stats", label = "Stats", icon = "chart", group = "TRÉSORERIE", page = "stats" },
    { key = "mail", label = "Règles d'envoi", icon = "mail", group = "TRÉSORERIE", page = "mail" },
    { key = "professions", label = "Métiers", icon = "hammer", group = "ARTISANAT", page = "professions", desc = "page et infobulle" },
    { key = "fishing", label = "Pêche", icon = "fish", group = "ARTISANAT", qol = "fishing", page = "fishing", desc = "collection, carnet et réglages", reload = true },
    { key = "farm", label = "Session de farm", icon = "play", group = "BUTIN", page = "farm" },
    { key = "loot", label = "Filtre de loot", icon = "filter", group = "BUTIN", page = "loot" },
    { key = "journal", label = "Journal", icon = "clock", group = "BUTIN", page = "journal" },
    { key = "quests", label = "Quêtes", icon = "bang", group = "AVENTURE", page = "quests", desc = "page et donneurs" },
    { key = "rares", label = "Rares", icon = "star", group = "AVENTURE", page = "rares", desc = "page, carte, alerte" },
    { key = "dungeons", label = "Donjons", icon = "skull", group = "AVENTURE", page = "dungeons", desc = "boss, butin, envies" },
    { key = "lfg", label = "LFG", icon = "lfg", group = "AVENTURE", page = "lfg" },
    { key = "nodes", label = "Récolte", icon = "tree", group = "AVENTURE", desc = "filons et plantes" },
    { key = "qolgeneral", label = "Général", icon = "gear", group = "RÉGLAGES QOL", qol = "general", desc = "section des réglages" },
    { key = "halo", label = "Halo", icon = "spark", group = "RÉGLAGES QOL", qol = "halo", reload = true },
    { key = "micro", label = "Micro menu", icon = "menu", group = "RÉGLAGES QOL", qol = "micro", reload = true },
    { key = "maplayers", label = "Carte", icon = "map", group = "RÉGLAGES QOL", qol = "maplayers", desc = "lieux et trajets" },
    { key = "ah", label = "Hôtel des ventes", icon = "coin", group = "RÉGLAGES QOL", qol = "ah", desc = "scan et infobulle" },
    { key = "cursor", label = "Curseur", icon = "crosshair", group = "RÉGLAGES QOL", qol = "cursor", desc = "anneau et curseur gardé en combat", reload = true },
    { key = "campfire", label = "Feu de camp", icon = "fire", group = "RÉGLAGES QOL", qol = "campfire", desc = "rappel pour s'asseoir près d'un camp", reload = true },
    { key = "xp", label = "Expérience", icon = "chart", group = "RÉGLAGES QOL", qol = "xp", desc = "barre, repos, quêtes à rendre" },
    { key = "classes", label = "Classes", icon = "users", group = "RÉGLAGES QOL", qol = "classes", desc = "section des réglages" },
    { key = "range", label = "Distance", icon = "arrow", group = "RÉGLAGES QOL", desc = "ruban de distance du chasseur", reload = true },
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
