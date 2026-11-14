local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors

local M = WK:NewModule("MinimapButton")

local function position(b)
    local cfg = WK.DB.global.settings.ui.minimap
    local a = math.rad(cfg.angle or 215)
    local r = (Minimap:GetWidth() / 2) + 8
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local function onDragUpdate(b)
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local s = Minimap:GetEffectiveScale()
    cx, cy = cx / s, cy / s
    WK.DB.global.settings.ui.minimap.angle = math.deg(math.atan2(cy - my, cx - mx))
    position(b)
end

function M:Create()
    if self.button then return self.button end
    local b = CreateFrame("Button", "WarbandKeeperMinimapButton", Minimap)
    self.button = b
    b:SetSize(32, 32)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")

    -- Anneau d'accent + disque sombre + logo : entièrement rond.
    local ring = UI:Icon(b, "circle", 32, nil, "BACKGROUND")
    ring:SetPoint("CENTER")
    local disc = UI:Icon(b, "circle", 28, C.sidebar, "BORDER")
    disc:SetPoint("CENTER")
    local logo = UI:Icon(b, "logo", 18, nil, "ARTWORK")
    logo:SetPoint("CENTER")

    local function refresh()
        local r, g, bl = UI:Accent()
        ring:SetVertexColor(r, g, bl, b.hover and 1 or 0.75)
        if b.hover then logo:SetVertexColor(1, 1, 1, 1) else logo:SetVertexColor(r, g, bl, 1) end
    end
    UI:OnAccent(refresh)

    b:SetScript("OnClick", function(_, button)
        if button == "RightButton" then UI:ToggleWindow("options") else UI:ToggleWindow() end
    end)
    b:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", onDragUpdate) end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    b:SetScript("OnEnter", function(self)
        self.hover = true; refresh()
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Warband Keeper")
        local total = 0
        for _, c in pairs(WK.DB.global.characters) do total = total + (c.money or 0) end
        GameTooltip:AddDoubleLine(WK.T("Or du compte"), WK:FormatMoney(total), 0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(WK.T("|cffffffffClic gauche|r : ouvrir / fermer"), 0.6, 0.6, 0.6)
        GameTooltip:AddLine(WK.T("|cffffffffClic droit|r : options"), 0.6, 0.6, 0.6)
        GameTooltip:AddLine(WK.T("|cffffffffGlisser|r : déplacer le bouton"), 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self) self.hover = false; refresh(); GameTooltip:Hide() end)

    position(b)
    return b
end

function M:Update()
    local hide = WK.DB.global.settings.ui.minimap.hide
    if hide then
        if self.button then self.button:Hide() end
    else
        self:Create():Show()
    end
end

function M:OnLogin() self:Update() end

-- Menu "compartiment d'addons" du client (si disponible).
function WarbandKeeper_OnAddonCompartmentClick() UI:ToggleWindow() end
