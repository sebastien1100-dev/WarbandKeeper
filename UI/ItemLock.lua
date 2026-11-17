local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Objets verrouillés (Modules/ItemLock.lua), côté écran :
--   sacs du jeu : cadenas sur la case (rose : à la main ; turquoise : par règle), Alt + clic pour (dé)verrouiller ;
--   chez le marchand : un cache sur la case bloque le clic (objet verrouillé) ou demande confirmation (vente chère) ;
--   infobulle : « Verrouillé… ».
local L = WK.modules.ItemLock
local RULE = { 0.31, 0.82, 0.77 } -- turquoise des verrous par règle (donnée, pas une couleur du thème)

local function inCombat() return InCombatLockdown and InCombatLockdown() end
local function modDown()
    local k = L:Config().key
    if k == "ctrl" then return IsControlKeyDown() and not IsAltKeyDown() end
    if k == "shiftalt" then return IsAltKeyDown() and IsShiftKeyDown() end
    return IsAltKeyDown() and not IsShiftKeyDown() and not IsControlKeyDown()
end
local function bagSlot(btn)
    local bag = (btn.GetBagID and btn:GetBagID()) or (btn:GetParent() and btn:GetParent():GetID())
    return bag, btn:GetID()
end
local function itemAt(bag, slot)
    if not bag or not slot then return nil end
    return (WK.Container.Info(bag, slot))
end

---------------------------------------------------------------------------
-- Confirmation d'une vente chère
---------------------------------------------------------------------------
local dlg
local function sellNow(bag, slot)
    if C_Container and C_Container.UseContainerItem then C_Container.UseContainerItem(bag, slot)
    elseif UseContainerItem then UseContainerItem(bag, slot) end
end
local function confirm(bag, slot, id, ah, vendor)
    if not dlg then
        dlg = CreateFrame("Frame", "WarbandKeeperSellConfirm", UIParent)
        dlg:SetSize(330, 190)
        dlg:SetPoint("CENTER", 0, 120)
        dlg:SetFrameStrata("DIALOG")
        dlg:EnableMouse(true)
        UI:Panel(dlg, 12, C.bg, C.border)
        if UISpecialFrames then table.insert(UISpecialFrames, "WarbandKeeperSellConfirm") end
        dlg.title = UI:Text(dlg, 14)
        dlg.title:SetPoint("TOPLEFT", 16, -14)
        dlg.title:SetText(T("Vendre au marchand ?"))
        dlg.rows = {}
        for i, lab in ipairs({ "Objet", "Marchand", "Hôtel des ventes (scan)" }) do
            local l = UI:Text(dlg, 12, C.muted)
            l:SetPoint("TOPLEFT", 16, -40 - (i - 1) * 22)
            l:SetText(T(lab))
            local v = UI:Text(dlg, 12)
            v:SetPoint("TOPRIGHT", -16, -40 - (i - 1) * 22)
            v:SetJustifyH("RIGHT")
            dlg.rows[i] = v
        end
        dlg.keep = UI:Button(dlg, "Garder", 92, 28, "secondary")
        dlg.keep:SetPoint("BOTTOMLEFT", 16, 40)
        dlg.keep:SetScript("OnClick", function() dlg:Hide() end)
        dlg.lock = UI:Button(dlg, "Verrouiller", 100, 28, "secondary")
        dlg.lock:SetPoint("LEFT", dlg.keep, "RIGHT", 8, 0)
        dlg.lock:SetScript("OnClick", function() L:Toggle(dlg.id); dlg:Hide() end)
        dlg.sell = UI:Button(dlg, "Vendre", 92, 28, "primary")
        dlg.sell:SetPoint("LEFT", dlg.lock, "RIGHT", 8, 0)
        dlg.sell:SetScript("OnClick", function()
            if dlg.never then L:Never(dlg.id) end
            if itemAt(dlg.bag, dlg.slot) == dlg.id and L:MerchantOpen() then sellNow(dlg.bag, dlg.slot) end
            dlg:Hide()
        end)
        dlg.neverBtn = CreateFrame("Button", nil, dlg)
        dlg.neverBtn:SetSize(260, 18)
        dlg.neverBtn:SetPoint("BOTTOMLEFT", 16, 12)
        dlg.neverText = UI:Text(dlg.neverBtn, 11, C.muted)
        dlg.neverText:SetPoint("LEFT")
        dlg.neverBtn:SetScript("OnClick", function()
            dlg.never = not dlg.never
            dlg.neverText:SetText((dlg.never and "[x] " or "[ ] ") .. T("Ne plus demander pour cet objet"))
        end)
    end
    dlg.bag, dlg.slot, dlg.id, dlg.never = bag, slot, id, false
    local name, _, r, g, b = UI:ItemInfo(id)
    dlg.rows[1]:SetText(name); dlg.rows[1]:SetTextColor(r, g, b)
    dlg.rows[2]:SetText(WK:FormatMoney(vendor))
    dlg.rows[3]:SetText(WK:FormatMoney(ah)); dlg.rows[3]:SetTextColor(unpack(C.gold))
    dlg.neverText:SetText("[ ] " .. T("Ne plus demander pour cet objet"))
    dlg:Show()
end

---------------------------------------------------------------------------
-- Cases des sacs du jeu
---------------------------------------------------------------------------
local function blockMsg(id)
    local msg = string.format(T("Verrouillé : %s n'a pas été vendu (%s pour le déverrouiller)."),
        WK.GetItemInfo(id) or ("#" .. id), L:Config().key == "ctrl" and T("Ctrl + clic") or L:Config().key == "shiftalt" and T("Maj + Alt + clic") or T("Alt + clic"))
    if UIErrorsFrame then UIErrorsFrame:AddMessage(msg, 0.96, 0.55, 0.73) end
end

local function decorate(btn)
    if btn.wkLock then return btn.wkLock end
    if inCombat() then return nil end
    local o = CreateFrame("Frame", nil, btn)
    o:SetAllPoints()
    o:SetFrameLevel(btn:GetFrameLevel() + 3)
    o.badge = o:CreateTexture(nil, "OVERLAY", nil, 6)
    o.badge:SetTexture(UI.MEDIA .. "circle")
    o.badge:SetSize(15, 15)
    o.badge:SetPoint("TOPRIGHT", 3, 3)
    o.ring = o:CreateTexture(nil, "OVERLAY", nil, 5)
    o.ring:SetTexture(UI.MEDIA .. "circle")
    o.ring:SetSize(17, 17)
    o.ring:SetPoint("CENTER", o.badge, "CENTER")
    o.ring:SetVertexColor(0, 0, 0, 0.9)
    o.icon = o:CreateTexture(nil, "OVERLAY", nil, 7)
    o.icon:SetTexture(UI.MEDIA .. "lock")
    o.icon:SetSize(9, 9)
    o.icon:SetPoint("CENTER", o.badge, "CENTER")
    o.icon:SetVertexColor(0.08, 0.06, 0.07, 1)
    -- cache chez le marchand : prend le clic à la place de la case
    o.block = CreateFrame("Button", nil, btn)
    o.block:SetAllPoints()
    o.block:SetFrameLevel(btn:GetFrameLevel() + 4)
    o.block:RegisterForClicks("AnyUp")
    o.block:RegisterForDrag("LeftButton")
    o.block:SetScript("OnClick", function(s, button)
        local bag, slot = bagSlot(btn)
        local id = itemAt(bag, slot)
        if not id then return end
        if modDown() and button == "LeftButton" then L:Toggle(id) return end
        if L:IsLocked(id) then blockMsg(id) return end
        local exp, ah, vendor = L:Expensive(id)
        if exp and button == "RightButton" then confirm(bag, slot, id, ah, vendor) end
    end)
    o.block:SetScript("OnDragStart", function()
        local id = itemAt(bagSlot(btn))
        if id then blockMsg(id) end
    end)
    o.block:SetScript("OnEnter", function(s)
        local bag, slot = bagSlot(btn)
        WK.UI:TooltipOwner(s, "ANCHOR_RIGHT")
        if GameTooltip.SetBagItem then pcall(GameTooltip.SetBagItem, GameTooltip, bag, slot) end
        GameTooltip:Show()
    end)
    o.block:SetScript("OnLeave", function() GameTooltip:Hide() end)
    o.block:Hide()
    -- Alt + clic sur la case (hors marchand) : verrouiller / déverrouiller
    btn:HookScript("OnClick", function(b, button)
        if button ~= "LeftButton" or not modDown() then return end
        local id = itemAt(bagSlot(b))
        if id then
            if CursorHasItem and CursorHasItem() and ClearCursor then ClearCursor() end
            L:Toggle(id)
        end
    end)
    btn.wkLock = o
    return o
end

local function paint(btn)
    local o = decorate(btn)
    if not o then return end
    local id = itemAt(bagSlot(btn))
    local why = id and L:Reason(id)
    local r1, g1, b1 = UI:Accent()
    o.badge:SetShown(why ~= nil); o.ring:SetShown(why ~= nil); o.icon:SetShown(why ~= nil)
    if why then
        if why == "manual" then o.badge:SetVertexColor(r1, g1, b1, 1) else o.badge:SetVertexColor(RULE[1], RULE[2], RULE[3], 1) end
    end
    if not inCombat() then
        local guard = L:MerchantOpen() and id ~= nil and (why ~= nil or L:Expensive(id))
        o.block:SetShown(guard and true or false)
    end
end

local function eachButton(fn)
    local function frameItems(f)
        if not (f and f:IsShown()) then return end
        if f.EnumerateValidItems then
            for _, b in f:EnumerateValidItems() do fn(b) end
        elseif f.GetName and f:GetName() then
            for j = 1, 40 do
                local b = _G[f:GetName() .. "Item" .. j]
                if b and b:IsShown() then fn(b) end
            end
        end
    end
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do frameItems(_G["ContainerFrame" .. i]) end
    frameItems(_G.ContainerFrameCombinedBags)
end

function UI:RefreshItemLocks()
    if not WK:FeatureOn("inventory") then return end
    eachButton(paint)
end

-- Sacs ouverts : on repeint (contenu qui bouge, objets qui arrivent en cache)
local driver = CreateFrame("Frame")
driver.acc = 0
driver:SetScript("OnUpdate", function(s, el)
    s.acc = s.acc + el
    if s.acc < 0.3 then return end
    s.acc = 0
    local any = false
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do local f = _G["ContainerFrame" .. i]; if f and f:IsShown() then any = true break end end
    if not any and _G.ContainerFrameCombinedBags and _G.ContainerFrameCombinedBags:IsShown() then any = true end
    if any then UI:RefreshItemLocks() end
end)
WK:On("PLAYER_REGEN_ENABLED", function() UI:RefreshItemLocks() end)

---------------------------------------------------------------------------
-- Infobulle
---------------------------------------------------------------------------
local function onTooltip(tt, data)
    if tt ~= GameTooltip and tt ~= ItemRefTooltip then return end
    local id = data and data.id
    if not id and tt.GetItem then local _, link = tt:GetItem(); id = link and WK:ParseItemID(link) end
    local why = id and L:Reason(id)
    if not why then return end
    if why == "manual" then
        local r, g, b = UI:Accent()
        tt:AddLine(T("Verrouillé : ne sera pas vendu (Alt + clic)"), r, g, b)
    else
        tt:AddLine(string.format(T("Verrouillé par règle : %s"), why), RULE[1], RULE[2], RULE[3])
    end
    tt:Show()
end
if TooltipDataProcessor and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data) pcall(onTooltip, tt, data) end)
end
