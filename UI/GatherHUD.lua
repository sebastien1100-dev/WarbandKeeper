local ADDON_NAME, WK = ...
local UI = WK.UI
local T = function(s) return WK.T(s) end

-- HUD de récolte : la minicarte du jeu est déplacée au centre de l'écran, agrandie et transparente,
-- dézoomée au maximum et tournée avec le perso. Les points jaunes du pistage (filons, plantes),
-- que le jeu ne donne à aucun addon, se voient ainsi de bien plus loin ; nos pastilles (nœuds
-- récoltés, trajet) suivent la minicarte. Tout ce qui est changé (parent, place, taille, opacité,
-- zoom, rotation, souris) est gardé et rendu à la fermeture.
-- Réglages : settings.ui.gatherHUD = { size (% de la hauteur de l'écran), alpha, combatHide }.
-- Raccourci : Bindings.xml (WARBANDKEEPER_HUD) ; /wk hud.
local saved
local holder

function UI.GatherHUDConfig()
    local ui = WK.DB.global.settings.ui
    ui.gatherHUD = ui.gatherHUD or {}
    local c = ui.gatherHUD
    c.size = c.size or 70
    c.alpha = c.alpha or 0.55
    if c.combatHide == nil then c.combatHide = true end
    return c
end

function UI:GatherHUDShown() return saved ~= nil end

function UI:ApplyGatherHUD()
    if not saved or not Minimap then return end
    local c = UI.GatherHUDConfig()
    local size = math.floor(UIParent:GetHeight() * c.size / 100)
    Minimap:SetSize(size, size)
    Minimap:SetAlpha(c.alpha)
end

local function show()
    if saved or not Minimap then return end
    if InCombatLockdown and InCombatLockdown() and UI.GatherHUDConfig().combatHide then return end
    holder = holder or CreateFrame("Frame", "WarbandKeeperGatherHUD", UIParent)
    holder:SetAllPoints(UIParent)
    holder:SetFrameStrata("BACKGROUND")
    local pts = {}
    for i = 1, (Minimap.GetNumPoints and Minimap:GetNumPoints() or 1) do
        local p = { Minimap:GetPoint(i) }
        if p[1] then pts[#pts + 1] = p end
    end
    saved = {
        parent = Minimap:GetParent(), points = pts, w = Minimap:GetWidth(), h = Minimap:GetHeight(),
        alpha = Minimap:GetAlpha(), zoom = Minimap.GetZoom and Minimap:GetZoom() or 0,
        rotate = WK.GetCVar("rotateMinimap"), mouse = (Minimap.IsMouseEnabled == nil) or Minimap:IsMouseEnabled(),
        strata = Minimap:GetFrameStrata(),
    }
    Minimap:SetParent(holder)
    Minimap:ClearAllPoints()
    Minimap:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    Minimap:SetFrameStrata("BACKGROUND")
    Minimap:EnableMouse(false) -- les clics passent au travers (on joue « à travers » le HUD)
    if Minimap.SetZoom then Minimap:SetZoom(0) end -- le plus loin possible
    WK.SetCVar("rotateMinimap", "1") -- le haut du HUD = devant le perso
    holder:Show()
    UI:ApplyGatherHUD()
end

local function hide()
    if not saved or not Minimap then return end
    local s = saved
    saved = nil
    Minimap:SetParent(s.parent)
    Minimap:ClearAllPoints()
    for _, p in ipairs(s.points) do Minimap:SetPoint(unpack(p)) end
    Minimap:SetSize(s.w, s.h)
    Minimap:SetAlpha(s.alpha or 1)
    Minimap:SetFrameStrata(s.strata or "LOW")
    Minimap:EnableMouse(s.mouse ~= false)
    if Minimap.SetZoom then Minimap:SetZoom(s.zoom or 0) end
    if s.rotate then WK.SetCVar("rotateMinimap", s.rotate) end
    if holder then holder:Hide() end
end

local closedByCombat -- fermé par « Fermer en combat » : rouvert à la sortie du combat

function UI:ToggleGatherHUD(on)
    if on == nil then on = not saved end
    closedByCombat = nil -- choix du joueur : on ne rouvre rien de soi-même
    if on then show() else hide() end
end
-- pour le raccourci du jeu (Bindings.xml)
function WarbandKeeper_ToggleGatherHUD() UI:ToggleGatherHUD() end
WK.BindingName("BINDING_NAME_WARBANDKEEPER_HUD", "HUD de récolte (afficher / masquer)")

WK:On("PLAYER_REGEN_DISABLED", function()
    if saved and UI.GatherHUDConfig().combatHide then hide(); closedByCombat = true end
end)
WK:On("PLAYER_REGEN_ENABLED", function()
    if closedByCombat then closedByCombat = nil; show() end
end)
WK:On("PLAYER_LOGOUT", function() hide() end)
