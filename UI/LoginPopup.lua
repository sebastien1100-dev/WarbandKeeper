local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Fenêtre de rappels à la connexion : les tâches du moment (les mêmes que « À faire » du
-- Résumé), chacune cliquable. Seulement à une vraie connexion (pas après un /reload), s'il y a
-- quelque chose à faire, et désactivable dans Options > Général.
local MAX_ROWS = 8
local popup

local function build()
    local f = CreateFrame("Frame", "WarbandKeeperLoginPopup", UIParent)
    f:SetSize(400, 120)
    f:SetPoint("TOP", 0, -160)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    UI:Panel(f, 14, C.bg, C.frame)
    f.logo = UI:Icon(f, "logo", 20)
    f.logo:SetPoint("TOPLEFT", 16, -15)
    f.logo:SetVertexColor(UI:Accent())
    f.title = UI:Text(f, 14)
    f.title:SetPoint("LEFT", f.logo, "RIGHT", 8, 0)
    f.sub = UI:Text(f, 11, C.muted)
    f.sub:SetPoint("TOPLEFT", 16, -42)
    local close = UI:IconButton(f, "close", 26, nil, "accent")
    close:SetPoint("TOPRIGHT", -10, -10)
    close:SetScript("OnClick", function() f:Hide() end)
    f.rows = UI:Pool(function()
        local r = CreateFrame("Button", nil, f)
        r:SetHeight(30)
        r.hl = CreateFrame("Frame", nil, r)
        r.hl:SetAllPoints()
        UI:Rounded(r.hl, 8, 0, "BACKGROUND", 1):SetColor(unpack(C.hover))
        r.hl:Hide()
        r.icon = UI:Icon(r, "mail", 14)
        r.icon:SetPoint("LEFT", 8, 0)
        r.text = UI:Text(r, 11)
        r.text:SetPoint("LEFT", 30, 0)
        r.text:SetPoint("RIGHT", -6, 0)
        r.text:SetJustifyH("LEFT")
        r:SetScript("OnEnter", function(s) s.hl:Show() end)
        r:SetScript("OnLeave", function(s) s.hl:Hide() end)
        r:SetScript("OnClick", function(s)
            UI:Create():Show()
            UI:ShowPage("overview")
            if s.go then s.go() end
            f:Hide()
        end)
        return r
    end)
    f.more = UI:Text(f, 10, C.dim)
    f.openBtn = UI:Button(f, "Ouvrir Warband Keeper", nil, 28, "primary")
    f.openBtn:SetPoint("BOTTOMRIGHT", -12, 12)
    f.openBtn:SetScript("OnClick", function() UI:ToggleWindow("overview"); f:Hide() end)
    f.hint = UI:Text(f, 10, C.dim)
    f.hint:SetPoint("BOTTOMLEFT", 16, 20)
    f.hint:SetText("Désactivable dans Options > Général")
    return f
end

function UI:ShowLoginPopup(force)
    local items = UI.TodoItems and UI.TodoItems() or {}
    if #items == 0 and not force then return end
    popup = popup or build()
    local me = WK.DB:Me()
    popup.title:SetText(string.format(T("Bonjour %s"), WK:CharName(me, select(2, WK.DB:Me()))))
    popup.sub:SetText(#items > 0 and string.format(#items > 1 and T("%d choses à faire") or T("%d chose à faire"), #items)
        or T("Rien à faire : tout est à jour."))
    popup.rows:Reset()
    local y = -64
    for i, it in ipairs(items) do
        if i > MAX_ROWS then break end
        local r = popup.rows:Get()
        r.go = it.go
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 8, y)
        r:SetPoint("TOPRIGHT", -8, y)
        r.icon:SetTexture(UI.MEDIA .. it.icon)
        r.icon:SetVertexColor(unpack(it.color or C.muted))
        r.text:SetText(it.text)
        r.text:SetTextColor(unpack(it.color or C.text))
        y = y - 32
    end
    popup.more:ClearAllPoints()
    popup.more:SetPoint("TOPLEFT", 16, y - 2)
    popup.more:SetText(#items > MAX_ROWS and string.format(T("+ %d autre(s) dans le Résumé"), #items - MAX_ROWS) or "")
    if #items > MAX_ROWS then y = y - 18 end
    popup:SetHeight(-y + 56)
    popup:Show()
end

WK:On("PLAYER_ENTERING_WORLD", function(isInitialLogin, isReload)
    if not isInitialLogin or isReload then return end
    if WK.DB.global.settings.ui.loginPopup == false then return end
    -- Laisser le temps aux scans (sacs, courrier connu, métiers) de se faire
    C_Timer.After(5, function() UI:ShowLoginPopup() end)
end)
