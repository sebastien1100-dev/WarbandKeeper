local ADDON_NAME, WK = ...
_G.WarbandKeeper = WK

WK.version = "0.80.1"
WK.modules = {}

-- Gestion centralisée des événements : chaque module s'abonne via WK:On(event, fn).
local frame = CreateFrame("Frame")
local handlers = {}

-- Un évènement absent de ce client (ex. CRAFT_SHOW) est ignoré sans erreur.
WK.unknownEvents = {}
function WK:On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        local ok = pcall(frame.RegisterEvent, frame, event)
        if not ok then WK.unknownEvents[event] = true end
    end
    table.insert(handlers[event], fn)
end

frame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], ...)
        if not ok then WK:Print("|cffff4040Erreur (" .. event .. ")|r " .. tostring(err)) end
    end
end)

-- Prévient l'interface que les données ont changé (rafraîchissement différé).
function WK:NotifyChanged()
    if self.UI and self.UI.RequestRefresh then self.UI:RequestRefresh() end
end

-- Enregistrement d'un module : il expose éventuellement OnInit() et OnLogin().
function WK:NewModule(name)
    local m = { name = name }
    self.modules[name] = m
    return m
end

WK:On("ADDON_LOADED", function(name)
    if name ~= ADDON_NAME then return end
    WK.DB:Init()
    -- profil de réglages de ce perso, avant que quoi que ce soit ne lise les réglages
    if WK.modules.Profiles then WK.modules.Profiles:Apply() end
    if WK.UI and WK.UI.ApplyTheme then WK.UI:ApplyTheme() end
    WK.DB:CompactHistory()
    for _, m in pairs(WK.modules) do
        if m.OnInit then m:OnInit() end
    end
end)

WK:On("PLAYER_LOGIN", function()
    -- Classe et faction sont sûres ici : on réapplique pour les thèmes dynamiques.
    if WK.UI and WK.UI.ApplyTheme then WK.UI:ApplyTheme() end
    WK.DB:CompactHistory()
    for _, m in pairs(WK.modules) do
        if m.OnLogin then m:OnLogin() end
    end
    -- Message « chargé » seulement à la première installation (les mises à jour ont le leur).
    if not WK.DB.global.settings.lastSeenVersion then WK:Print(WK.L.LOADED) end
end)
