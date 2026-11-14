local ADDON_NAME, WK = ...
_G.WarbandKeeper = WK

WK.version = "0.14.0"
WK.modules = {}

-- Gestion centralisée des événements : chaque module s'abonne via WK:On(event, fn).
local frame = CreateFrame("Frame")
local handlers = {}

function WK:On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        frame:RegisterEvent(event)
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
    if WK.UI and WK.UI.ApplyTheme then WK.UI:ApplyTheme() end
    for _, m in pairs(WK.modules) do
        if m.OnInit then m:OnInit() end
    end
end)

WK:On("PLAYER_LOGIN", function()
    -- Classe et faction sont sûres ici : on réapplique pour les thèmes dynamiques.
    if WK.UI and WK.UI.ApplyTheme then WK.UI:ApplyTheme() end
    for _, m in pairs(WK.modules) do
        if m.OnLogin then m:OnLogin() end
    end
    WK:Print(WK.L.LOADED)
end)
