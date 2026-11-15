local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Barre de pêche (Modules/Fishing.lua) : affichée en mode pêche.
--   gros bouton « Pêcher » (protégé : tenue, appât, lancer selon le besoin ; c'est lui que la
--   touche unique clique), bouton de tenue (ou « acheter une canne »), bouton d'appât, fermer.
-- Et le petit bouton de minicarte qui ouvre et ferme le mode pêche.
local F = WK.modules.Fishing
local bar, mini

local function inCombat() return InCombatLockdown and InCombatLockdown() end
local function itemIcon(id)
    local f = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
    return f and id and f(id) or "Interface\\Icons\\INV_Misc_QuestionMark"
end
local function fishIcon() return select(2, WK.SpellInfo(7620)) or "Interface\\Icons\\Trade_Fishing" end
local function keyLabel(key)
    if not key or key == "" then return "" end
    local short = { MOUSEWHEELDOWN = "Molette bas", MOUSEWHEELUP = "Molette haut", BUTTON3 = "Clic milieu", BUTTON4 = "Souris 4", BUTTON5 = "Souris 5" }
    local mods, base = key:match("^(.-)([^%-]+)$")
    return (mods or "") .. T(short[base] or base)
end
UI.FishKeyLabel = keyLabel

local function tile(b, size)
    b:SetSize(size, size)
    b.edge = UI:Rounded(b, 9, 0, "BACKGROUND", 0)
    b.bg = UI:Rounded(b, 8, 1, "BACKGROUND", 1)
    b.icon = UI:RoundIcon(b, size - 8)
    b.icon:SetPoint("CENTER")
    b.badge = UI:Text(b, 10)
    b.badge:SetPoint("BOTTOMRIGHT", -2, 2)
    b.badge:SetFont(UI.FONT, 10, "OUTLINE")
    return b
end

local function build()
    local f = CreateFrame("Frame", "WarbandKeeperFishingBar", UIParent)
    f:SetSize(286, 60)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    UI:Panel(f, 12, { C.bg[1], C.bg[2], C.bg[3], 0.9 }, C.border)

    -- Bouton principal, protégé : la macro est préparée juste avant le clic (hors combat)
    local cast = CreateFrame("Button", F.BUTTON, f, "SecureActionButtonTemplate")
    if cast.RegisterForClicks then cast:RegisterForClicks("AnyUp", "AnyDown") end
    cast:SetAttribute("type", "macro")
    cast:SetAttribute("macrotext", "")
    cast:SetPoint("LEFT", 8, 0)
    tile(cast, 44)
    cast.icon:SetTexture(fishIcon())
    cast:SetScript("PreClick", function(s) F:PrepareClick(s) end)
    cast:SetScript("PostClick", function() C_Timer.After(0.3, function() UI:RefreshFishingBar() end) end)
    cast:SetScript("OnEnter", function(s)
        WK.UI:TooltipOwner(s, "ANCHOR_TOP")
        GameTooltip:SetText(T("Pêcher"), 1, 1, 1)
        local step = F:NextStep()
        local what = ({ gear = "Équiper la tenue de pêche", lure = "Poser un appât", cast = "Lancer la ligne", nopole = "Pas de canne à pêche" })[step]
        GameTooltip:AddLine(T("Prochain appui") .. " : " .. T(what), 0.8, 0.8, 0.8)
        local key = F:Config().key
        if key and key ~= "" then GameTooltip:AddLine(T("Touche") .. " : " .. keyLabel(key) .. " (" .. T("elle ferre aussi le flotteur") .. ")", 0.6, 0.6, 0.6) end
        GameTooltip:Show()
    end)
    cast:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.cast = cast
    f.title = UI:Text(f, 12)
    f.title:SetPoint("TOPLEFT", cast, "TOPRIGHT", 8, -8)
    f.sub = UI:Text(f, 10, C.muted)
    f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)

    -- Tenue : équiper / remettre ; sans canne nulle part : « acheter une canne » (guidage)
    local gear = tile(CreateFrame("Button", nil, f), 30)
    gear:SetPoint("RIGHT", f, "RIGHT", -64, 0)
    gear:SetScript("OnClick", function()
        if inCombat() then return end
        if not F:HasPole() then WK.modules.Guide:GoTo("fishing") return end
        if F:PoleEquipped() then F:RestoreGear() else F:EquipGear() end
    end)
    gear:SetScript("OnEnter", function(s)
        WK.UI:TooltipOwner(s, "ANCHOR_TOP")
        if not F:HasPole() then
            GameTooltip:SetText(T("Acheter une canne"), 1, 1, 1)
            GameTooltip:AddLine(T("Aucune canne équipée ni dans les sacs. Clic : guidage vers les fournitures de pêche les plus proches."), 0.8, 0.8, 0.8, true)
        else
            GameTooltip:SetText(T("Tenue de pêche"), 1, 1, 1)
            GameTooltip:AddLine(F:PoleEquipped() and T("Clic : remettre ton équipement habituel.") or T("Clic : équiper la canne et les pièces de pêche."), 0.8, 0.8, 0.8, true)
        end
        GameTooltip:Show()
    end)
    gear:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.gear = gear

    -- Appât : bouton protégé (pose l'appât choisi sur la canne)
    local lure = CreateFrame("Button", "WarbandKeeperFishLure", f, "SecureActionButtonTemplate")
    if lure.RegisterForClicks then lure:RegisterForClicks("AnyUp", "AnyDown") end
    lure:SetAttribute("type", "macro")
    lure:SetAttribute("macrotext", "")
    tile(lure, 30)
    lure:SetPoint("LEFT", gear, "RIGHT", 6, 0)
    lure:SetScript("OnEnter", function(s)
        WK.UI:TooltipOwner(s, "ANCHOR_TOP")
        GameTooltip:SetText(T("Appât"), 1, 1, 1)
        local left = F:LureLeft()
        if left then GameTooltip:AddLine(string.format(T("Appât posé : encore %s"), WK:FormatTime(left)), 0.6, 1, 0.6) end
        local id = F:PickLure()
        if id then
            GameTooltip:AddLine(string.format(T("Clic : poser %s (%d en sac)"), (WK.GetItemInfo(id)) or "?", F:Count(id)), 0.8, 0.8, 0.8, true)
        else
            GameTooltip:AddLine(T("Aucun appât utilisable dans les sacs."), 1, 0.6, 0.4, true)
        end
        GameTooltip:Show()
    end)
    lure:SetScript("OnLeave", function() GameTooltip:Hide() end)
    lure:SetScript("PostClick", function() C_Timer.After(0.5, function() UI:RefreshFishingBar() end) end)
    f.lure = lure

    f.close = UI:IconButton(f, "close", 18, nil, "accent")
    f.close:SetPoint("TOPRIGHT", -3, -3)
    f.close:SetScript("OnClick", function() F:Stop() end)

    f.acc = 0
    f:SetScript("OnUpdate", function(s, el)
        s.acc = s.acc + el
        if s.acc < 1 then return end
        s.acc = 0
        UI:RefreshFishingBar()
    end)
    f:Hide()
    UI:RegisterHUD("fishing", f, { label = T("Barre de pêche"), protected = true, default = { 0, -200 } })
    return f
end

function UI:RefreshFishingBar()
    if not bar or not bar:IsShown() then return end
    local r, g, b = UI:Accent()
    local step, lureID = F:NextStep()
    for _, t in ipairs({ bar.cast, bar.gear, bar.lure }) do
        t.edge:SetColor(unpack(C.border)); t.bg:SetColor(unpack(C.surface2))
    end
    bar.cast.edge:SetColor(r, g, b, 1)
    bar.title:SetText(T(({ gear = "Équiper la tenue", lure = "Poser l'appât", cast = "Pêcher", nopole = "Pas de canne" })[step]))
    bar.title:SetTextColor(unpack(step == "nopole" and C.negative or C.text))
    bar.sub:SetText(keyLabel(F:Config().key))
    -- tenue : canne équipée, canne en sac, ou « acheter une canne »
    local has = F:HasPole()
    bar.gear.icon:SetTexture(has and itemIcon(GetInventoryItemID and F:PoleEquipped() and GetInventoryItemID("player", 16) or F:BagPole()) or "Interface\\Icons\\INV_Misc_Coin_01")
    bar.gear.badge:SetText(has and "" or "!")
    bar.gear.badge:SetTextColor(unpack(C.negative))
    if not has then bar.gear.edge:SetColor(unpack(C.negative)) elseif F:PoleEquipped() then bar.gear.edge:SetColor(unpack(C.positive)) end
    -- appât : temps restant, sinon nombre en sac
    local pick = lureID or F:PickLure()
    local left = F:LureLeft()
    bar.lure.icon:SetTexture(itemIcon(pick or 6529))
    bar.lure.icon:SetAlpha((pick or left) and 1 or 0.35)
    if left then
        bar.lure.badge:SetText(left >= 60 and (math.floor(left / 60) .. "m") or (left .. "s"))
        bar.lure.badge:SetTextColor(unpack(C.positive))
        bar.lure.edge:SetColor(unpack(C.positive))
    else
        bar.lure.badge:SetText(pick and tostring(F:Count(pick)) or "0")
        bar.lure.badge:SetTextColor(unpack(pick and C.text or C.negative))
    end
    if not inCombat() then
        bar.lure:SetAttribute("macrotext", pick and F:MacroFor("lure", pick) or "")
    end
end

-- Affiche ou cache la barre selon le mode (hors combat : elle porte des boutons protégés).
function UI:SyncFishingBar()
    if inCombat() then return end
    if F.active then
        bar = bar or build()
        bar:Show()
        UI:RefreshFishingBar()
    elseif bar then
        bar:Hide()
    end
    UI:SyncFishingMinimap()
end

---------------------------------------------------------------------------
-- Bouton de minicarte
---------------------------------------------------------------------------
local function place(b)
    local a = math.rad(F:Config().minimapAngle or 250)
    local r = (Minimap:GetWidth() / 2) + 8
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local function buildMini()
    local b = CreateFrame("Button", "WarbandKeeperFishingMinimap", Minimap)
    b:SetSize(28, 28)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b.ring = UI:Icon(b, "circle", 28, nil, "BACKGROUND")
    b.ring:SetPoint("CENTER")
    b.icon = UI:RoundIcon(b, 22, fishIcon())
    b.icon:SetPoint("CENTER")
    function b:Paint()
        local r, g, bl = UI:Accent()
        if F.active then self.ring:SetVertexColor(C.positive[1], C.positive[2], C.positive[3], 1)
        else self.ring:SetVertexColor(r, g, bl, self.hover and 1 or 0.75) end
    end
    UI:OnAccent(function() b:Paint() end)
    b:SetScript("OnClick", function(_, button)
        if button == "RightButton" then UI:Create():Show(); UI:ShowPage("qol"); UI.pages.qol:ShowSection("fishing")
        else F:Toggle() end
    end)
    b:SetScript("OnDragStart", function(s)
        s:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local sc = Minimap:GetEffectiveScale()
            F:Config().minimapAngle = math.deg(math.atan2(cy / sc - my, cx / sc - mx))
            place(s)
        end)
    end)
    b:SetScript("OnDragStop", function(s) s:SetScript("OnUpdate", nil) end)
    b:SetScript("OnEnter", function(s)
        s.hover = true; s:Paint()
        WK.UI:TooltipOwner(s, "ANCHOR_LEFT")
        GameTooltip:AddLine(T("Pêche"))
        GameTooltip:AddLine(F.active and T("Mode pêche ouvert") or T("Mode pêche fermé"), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(T("|cffffffffClic gauche|r : ouvrir / fermer le mode pêche"), 0.6, 0.6, 0.6)
        GameTooltip:AddLine(T("|cffffffffClic droit|r : réglages"), 0.6, 0.6, 0.6)
        GameTooltip:AddLine(T("|cffffffffGlisser|r : déplacer le bouton"), 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(s) s.hover = false; s:Paint(); GameTooltip:Hide() end)
    place(b)
    return b
end

-- Affiché si l'option est cochée et que le perso connaît la Pêche.
function UI:SyncFishingMinimap()
    local want = F:Config().minimap and F:Knows() and Minimap ~= nil
    if want then
        mini = mini or buildMini()
        mini:Show()
        mini:Paint()
    elseif mini then
        mini:Hide()
    end
end

WK:On("PLAYER_LOGIN", function() C_Timer.After(1.5, function() UI:SyncFishingMinimap() end) end)
