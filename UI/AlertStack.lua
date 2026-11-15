local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Pile d'alertes : petites vignettes (icône, texte, liseré de couleur) empilées dans un cadre
-- déplaçable. Une alerte reste affichée tant que sa condition est vraie.
--   UI:SetAlert(key, shown, { icon = texture, text = "...", color = {r,g,b}, prio = 1 })
-- Glisser une vignette déplace la pile (position gardée).
local anchor, items = nil, {}
local active = {} -- [key] = { icon, text, color, prio }

local function savePos()
    local p, _, _, x, y = anchor:GetPoint(1)
    WK.DB.global.settings.ui.alertStack = { p, x, y }
end

local function build()
    anchor = CreateFrame("Frame", "WarbandKeeperAlertStack", UIParent)
    anchor:SetSize(240, 30)
    local pos = WK.DB.global.settings.ui.alertStack
    if pos then anchor:SetPoint(pos[1], UIParent, pos[1], pos[2], pos[3]) else anchor:SetPoint("TOP", 0, -200) end
    anchor:SetFrameStrata("MEDIUM")
    anchor:SetClampedToScreen(true)
    anchor:SetMovable(true)
end

local function getItem(i)
    local it = items[i]
    if it then return it end
    it = CreateFrame("Frame", nil, anchor)
    it:SetSize(240, 30)
    UI:Panel(it, 8, { C.bg[1], C.bg[2], C.bg[3], 0.9 }, C.border)
    it.stripe = it:CreateTexture(nil, "ARTWORK")
    it.stripe:SetPoint("TOPLEFT", 1, -1)
    it.stripe:SetPoint("BOTTOMLEFT", 1, 1)
    it.stripe:SetWidth(3)
    it.icon = UI:RoundIcon(it, 20)
    it.icon:SetPoint("LEFT", 10, 0)
    it.text = UI:Text(it, 11, C.text)
    it.text:SetPoint("LEFT", 36, 0)
    it.text:SetPoint("RIGHT", -8, 0)
    it:EnableMouse(true)
    it:RegisterForDrag("LeftButton")
    it:SetScript("OnDragStart", function() anchor:StartMoving() end)
    it:SetScript("OnDragStop", function() anchor:StopMovingOrSizing(); savePos() end)
    it:SetScript("OnEnter", function(s)
        WK.UI:TooltipOwner(s, "ANCHOR_BOTTOM")
        GameTooltip:SetText(T("Rappel Warband Keeper"), 1, 1, 1)
        GameTooltip:AddLine(T("Glisser pour déplacer la pile."), 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    it:SetScript("OnLeave", function() GameTooltip:Hide() end)
    items[i] = it
    return it
end

local function layout()
    local list = {}
    for key, a in pairs(active) do table.insert(list, { key = key, a = a }) end
    table.sort(list, function(x, y)
        if (x.a.prio or 5) ~= (y.a.prio or 5) then return (x.a.prio or 5) < (y.a.prio or 5) end
        return x.key < y.key
    end)
    if #list == 0 and not anchor then return end
    if not anchor then build() end
    for i, e in ipairs(list) do
        local it = getItem(i)
        local col = e.a.color or C.warning
        it.stripe:SetColorTexture(col[1], col[2], col[3], 1)
        if e.a.icon then it.icon:SetTexture(e.a.icon); it.icon:Show() else it.icon:Hide() end
        it.text:SetText(e.a.text)
        it:SetWidth(math.max(200, it.text:GetStringWidth() + 52))
        it:ClearAllPoints()
        it:SetPoint("TOP", anchor, "TOP", 0, -(i - 1) * 34)
        it:Show()
    end
    for i = #list + 1, #items do items[i]:Hide() end
end

function UI:SetAlert(key, shown, data)
    local cur = active[key]
    if shown then
        if cur and cur.text == data.text and cur.icon == data.icon then return end
        active[key] = data
    else
        if not cur then return end
        active[key] = nil
    end
    layout()
end

function UI:ActiveAlerts() return active end
