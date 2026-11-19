local ADDON_NAME, WK = ...
_G.WarbandKeeper = WK

WK.version = "1.77.8"
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
    -- /wk perf : temps passé par évènement (Modules/Maintenance.lua)
    local perf = WK.perf
    local t0 = perf and debugprofilestop and debugprofilestop()
    for i = 1, #list do
        local ok, err = pcall(list[i], ...)
        if not ok then
            WK:Print("|cffff4040Erreur (" .. event .. ")|r " .. tostring(err))
            if WK.RecordError then pcall(WK.RecordError, err, "", event) end
        end
    end
    if t0 then perf.add("évènement " .. event, debugprofilestop() - t0) end
end)

-- Évènement d'unité écouté pour quelques unités seulement (le jeu ne prévient que pour elles) : bien moins
-- d'appels que WK:On pour des évènements très fréquents comme UNIT_HEALTH en groupe ou en raid.
function WK:OnUnit(event, units, fn)
    local f = CreateFrame("Frame")
    local list = type(units) == "table" and units or { units }
    local ok = f.RegisterUnitEvent and #list <= 2 and pcall(f.RegisterUnitEvent, f, event, list[1], list[2])
    local filter
    if not ok then
        pcall(f.RegisterEvent, f, event)
        filter = {}
        for _, u in ipairs(list) do filter[u] = true end
    end
    f:SetScript("OnEvent", function(_, ev, unit, ...)
        if filter and not filter[unit] then return end
        local perf = WK.perf
        local t0 = perf and debugprofilestop and debugprofilestop()
        local okc, err = pcall(fn, unit, ...)
        if not okc and WK.RecordError then pcall(WK.RecordError, err, "", ev) end
        if t0 then perf.add("évènement " .. ev, debugprofilestop() - t0) end
    end)
    return f
end

-- Évènement interne de l'addon (« WK_… ») : appelle ses abonnés comme un évènement du jeu
function WK:Fire(event, ...)
    local f = frame:GetScript("OnEvent")
    f(frame, event, ...)
end

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
    for _, m in pairs(WK.modules) do
        if m.OnInit then m:OnInit() end
    end
end)

WK:On("PLAYER_LOGIN", function()
    -- Classe et faction sont sûres ici : on réapplique pour les thèmes dynamiques.
    if WK.UI and WK.UI.ApplyTheme then WK.UI:ApplyTheme() end
    -- compactage de l'historique : une fois par session, après l'arrivée en jeu (connexion plus fluide)
    C_Timer.After(6, function() pcall(WK.DB.CompactHistory, WK.DB) end)
    for _, m in pairs(WK.modules) do
        if m.OnLogin then m:OnLogin() end
    end
    -- Message « chargé » seulement à la première installation (les mises à jour ont le leur).
    if not WK.DB.global.settings.lastSeenVersion then WK:Print(WK.L.LOADED) end
end)
