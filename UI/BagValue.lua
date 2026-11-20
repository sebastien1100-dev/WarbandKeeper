local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Valeur à l'HV (idée de The Market, rien de repris) : bandeau sous les sacs du jeu (sacs du perso,
-- prix de notre scan, sinon rien ; marchand à côté) et ligne dans l'infobulle d'un courrier de la boîte
-- aux lettres (pièces jointes). Réglages : AHScan:Config().bagValue, mailValue (page Hôtel des ventes).
local function S() return WK.modules.AHScan end
local function V() return WK.modules.Value end
local banner

-- { ah = total HV, vendor = total marchand, top = { { id, n, v } }, unpriced = nombre d'objets sans prix }
local function bagValues()
    local c = WK.DB:Me()
    local ah, vendor, unpriced, items = 0, 0, 0, {}
    for id, n in pairs(c.bags or {}) do
        local a, v = V():Prices(id)
        vendor = vendor + (v or 0) * n
        if a then
            ah = ah + a * n
            table.insert(items, { id = id, n = n, v = a * n })
        elseif (v or 0) > 0 then
            unpriced = unpriced + 1 -- vendable mais sans prix HV (objet lié ou de quête : ni l'un ni l'autre)
        end
    end
    table.sort(items, function(a, b) return a.v > b.v end)
    return { ah = ah, vendor = vendor, top = items, unpriced = unpriced }
end
UI.BagValues = bagValues

local function bagFrame()
    if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then return ContainerFrameCombinedBags end
    if ContainerFrame1 and ContainerFrame1:IsShown() then return ContainerFrame1 end
end

local function build()
    local f = CreateFrame("Frame", "WarbandKeeperBagValue", UIParent)
    f:SetSize(220, 26)
    f:SetFrameStrata("HIGH")
    UI:Panel(f, 9, { C.bg[1], C.bg[2], C.bg[3], 0.94 }, C.border)
    f.ah = UI:Text(f, 12); f.ah:SetPoint("LEFT", 10, 0)
    f.vendor = UI:Text(f, 10, C.muted); f.vendor:SetPoint("RIGHT", -10, 0); f.vendor:SetJustifyH("RIGHT")
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(s)
        local d = bagValues()
        UI:TooltipOwner(s, "ANCHOR_TOP")
        GameTooltip:SetText(T("Valeur de tes sacs à l'HV"), 1, 1, 1)
        for i = 1, math.min(5, #d.top) do
            local e = d.top[i]
            local name, _, qr, qg, qb = UI:ItemInfo(e.id)
            GameTooltip:AddDoubleLine((name or "?") .. " x" .. e.n, WK:FormatMoney(math.floor(e.v)), qr or 1, qg or 1, qb or 1, 1, 1, 1)
        end
        if d.unpriced > 0 then GameTooltip:AddLine(string.format(T("%d objet(s) sans prix HV (scan) : comptés au marchand seulement."), d.unpriced), 0.6, 0.6, 0.6, true) end
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f:Hide()
    return f
end

function UI:RefreshBagValue()
    local bf = bagFrame()
    local on = S():Config().bagValue and WK:FeatureOn("ah") and S():HasData()
    if not (bf and on) then if banner then banner:Hide() end return end
    if not banner then banner = build() end
    local d = bagValues()
    banner:ClearAllPoints()
    banner:SetPoint("TOPRIGHT", bf, "BOTTOMRIGHT", 0, -4)
    UI:MatchHost(banner, bf)
    banner.ah:SetText(UI:GoldText(math.floor(d.ah)) .. " " .. UI:Hex(C.muted) .. T("à l'HV") .. "|r")
    banner.vendor:SetText(string.format(T("marchand %s"), WK:FormatMoney(math.floor(d.vendor))))
    banner:SetWidth(math.max(200, (banner.ah:GetStringWidth() or 80) + (banner.vendor:GetStringWidth() or 80) + 36))
    banner:Show()
end

local pending
local function soon()
    if pending then return end
    pending = true
    C_Timer.After(0.4, function() pending = false; UI:RefreshBagValue() end)
end
WK:On("BAG_UPDATE_DELAYED", soon)
WK:On("PLAYER_LOGIN", function()
    for _, n in ipairs({ "ContainerFrameCombinedBags", "ContainerFrame1" }) do
        local bf = _G[n]
        if bf and bf.HookScript then
            bf:HookScript("OnShow", soon)
            bf:HookScript("OnHide", function() C_Timer.After(0, function() if banner and not bagFrame() then banner:Hide() end end) end)
        end
    end
    -- infobulle d'un courrier : valeur des pièces jointes
    for i = 1, (INBOXITEMS_TO_DISPLAY or 7) do
        local b = _G["MailItem" .. i .. "Button"] or _G["InboxFrameItem" .. i]
        if b and b.HookScript then
            b:HookScript("OnEnter", function(s)
                if not (S():Config().mailValue and WK:FeatureOn("ah") and GetInboxItem) then return end
                local index = s.index
                if not index then return end
                local total, n = 0, 0
                for a = 1, (ATTACHMENTS_MAX_RECEIVE or 16) do
                    local _, itemID, _, count = GetInboxItem(index, a)
                    if not itemID and GetInboxItemLink then itemID = WK:ParseItemID(GetInboxItemLink(index, a)) end
                    if itemID then
                        local ah = V():Prices(itemID)
                        if ah then total = total + ah * (count or 1); n = n + 1 end
                    end
                end
                if n > 0 and GameTooltip:IsShown() then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddDoubleLine(T("Valeur à l'HV"), WK:FormatMoney(math.floor(total)), 0.62, 0.82, 0.48, 1, 1, 1)
                    GameTooltip:Show()
                end
            end)
        end
    end
end)
