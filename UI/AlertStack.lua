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

local layout
local function build()
    anchor = CreateFrame("Frame", "WarbandKeeperAlertStack", UIParent)
    anchor:SetSize(240, 30)
    anchor:SetFrameStrata("MEDIUM")
    anchor:SetClampedToScreen(true)
    anchor:SetMovable(true)
    UI:RegisterHUD("alerts", anchor, {
        label = T("Pile d'alertes"),
        default = { 0, UIParent:GetHeight() / 2 - 250 },
        dynamicPoint = function(e) return e.growUp and "BOTTOM" or "TOP" end,
        legacy = function()
            local pos = WK.DB.global.settings.ui.alertStack -- position des versions précédentes
            if not pos then return false end
            anchor:ClearAllPoints()
            anchor:SetPoint(pos[1], UIParent, pos[1], pos[2], pos[3])
            return true
        end,
        options = {
            { type = "seg", label = "Empiler vers", items = { { false, "le bas" }, { true, "le haut" } },
              get = function(e) return e.growUp and true or false end,
              set = function(e, v)
                  if (e.growUp and true or false) == v then return end
                  local h = (anchor:GetHeight() or 30) * (e.scale or 1)
                  e.y = v and (e.y - h) or (e.y + h) -- le haut (ou le bas) de la pile reste en place
                  e.growUp = v
              end },
            { type = "toggle", label = "Icônes", get = function(e) return e.icons ~= false end, set = function(e, v) e.icons = v end },
        },
        sample = function(on)
            UI:SetAlert("demo.1", on, { text = T("Exemple : aucun aspect actif"), prio = 3 })
            UI:SetAlert("demo.2", on, { text = T("Exemple : rappel urgent"), color = C.negative, prio = 1 })
        end,
        onApply = function() if layout then layout() end end,
    })
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
    it:SetScript("OnDragStart", function() if not UI.editing then anchor:StartMoving() end end)
    it:SetScript("OnDragStop", function() anchor:StopMovingOrSizing(); UI:HUDCapture("alerts") end)
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

layout = function()
    if not anchor then return end
    local list = {}
    for key, a in pairs(active) do table.insert(list, { key = key, a = a }) end
    table.sort(list, function(x, y)
        if (x.a.prio or 5) ~= (y.a.prio or 5) then return (x.a.prio or 5) < (y.a.prio or 5) end
        return x.key < y.key
    end)
    local e = UI:HUDEntry("alerts")
    local up, icons = e.growUp, e.icons ~= false
    local maxW = 200
    for i, it in ipairs(list) do
        local item = getItem(i)
        local col = it.a.color or C.warning
        item.stripe:SetColorTexture(col[1], col[2], col[3], 1)
        item.icon:SetShown(icons and it.a.icon ~= nil)
        if it.a.icon then item.icon:SetTexture(it.a.icon) end
        item.text:ClearAllPoints()
        item.text:SetPoint("LEFT", (icons and it.a.icon) and 36 or 14, 0)
        item.text:SetPoint("RIGHT", -8, 0)
        item.text:SetText(it.a.text)
        local w = math.max(200, item.text:GetStringWidth() + ((icons and it.a.icon) and 52 or 30))
        maxW = math.max(maxW, w)
        item:SetWidth(w)
        item:ClearAllPoints()
        if up then item:SetPoint("BOTTOM", anchor, "BOTTOM", 0, (i - 1) * 34)
        else item:SetPoint("TOP", anchor, "TOP", 0, -(i - 1) * 34) end
        item:Show()
    end
    for i = #list + 1, #items do items[i]:Hide() end
    -- Le cadre couvre toute la pile (pour le mode édition)
    anchor:SetSize(maxW, math.max(30, #list * 34 - 4))
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
    if not anchor then build() end
    layout()
end

function UI:ActiveAlerts() return active end

-- La pile existe dès la connexion (vide), pour pouvoir la placer en mode édition.
WK:On("PLAYER_LOGIN", function() if not anchor then build(); layout() end end)
