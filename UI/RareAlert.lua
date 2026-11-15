local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Alerte « Rare en vue » (Modules/Rares.lua) : bandeau en haut de l'écran, avec le portrait du rare,
-- son niveau, son butin notable, s'il a déjà été tué, et deux boutons : Cibler (bouton protégé, hors
-- combat) et Guider. Disparaît seul après 25 s. Se place en mode édition.
local R = WK.modules.Rares
local frame
local W, H = 460, 74

local function build()
    local f = CreateFrame("Frame", "WarbandKeeperRareAlert", UIParent)
    f:SetSize(W, H)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f.edge = UI:Rounded(f, 16, 0, "BACKGROUND", 0)
    f.bg = UI:Rounded(f, 15, 1, "BACKGROUND", 1)
    f.portrait = UI:RoundIcon(f, 48)
    f.portrait:SetPoint("LEFT", 14, 0)
    f.ring = UI:Icon(f, "ring", 54, nil, "OVERLAY")
    f.ring:SetPoint("CENTER", f.portrait, "CENTER")
    f.kicker = UI:Text(f, 10)
    f.kicker:SetPoint("TOPLEFT", 76, -12)
    f.name = UI:Text(f, 15)
    f.name:SetPoint("TOPLEFT", f.kicker, "BOTTOMLEFT", 0, -3)
    f.name:SetPoint("RIGHT", -110, 0)
    f.name:SetJustifyH("LEFT")
    f.name:SetWordWrap(false)
    f.sub = UI:Text(f, 11, C.muted)
    f.sub:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -4)
    f.sub:SetPoint("RIGHT", -110, 0)
    f.sub:SetJustifyH("LEFT")
    f.sub:SetWordWrap(false)
    -- Cibler : bouton protégé (la macro est posée hors combat, à l'apparition de l'alerte)
    local tgt = CreateFrame("Button", "WarbandKeeperRareTarget", f, "SecureActionButtonTemplate")
    tgt:SetSize(86, 24)
    tgt:SetPoint("TOPRIGHT", -14, -12)
    if tgt.RegisterForClicks then tgt:RegisterForClicks("AnyUp", "AnyDown") end
    tgt:SetAttribute("type", "macro")
    tgt.bg = UI:Rounded(tgt, 12, 0, "BACKGROUND", 1)
    tgt.label = UI:Text(tgt, 12)
    tgt.label:SetPoint("CENTER")
    tgt.label:SetText(T("Cibler"))
    f.target = tgt
    f.guide = UI:Button(f, "Guider", 86, 24, "secondary")
    f.guide:SetPoint("TOPRIGHT", tgt, "BOTTOMRIGHT", 0, -6)
    f.close = UI:IconButton(f, "close", 16, nil, "accent")
    f.close:SetPoint("TOPRIGHT", f, "TOPLEFT", W - 2, -2)
    f.close:SetFrameLevel(tgt:GetFrameLevel() + 2)
    f.close:SetScript("OnClick", function() f:Hide() end)
    f:SetScript("OnUpdate", function(s)
        if s.sample then return end
        if s.until_ and GetTime() > s.until_ then s:Hide() end
    end)

    function f:Show2(info)
        local col = info.elite and C.gold or C.rare
        self.edge:SetColor(unpack(col))
        self.bg:SetColor(C.bg[1], C.bg[2], C.bg[3], 0.96)
        self.ring:SetVertexColor(unpack(col))
        self.kicker:SetText(info.elite and T("RARE ÉLITE EN VUE") or T("RARE EN VUE"))
        self.kicker:SetTextColor(unpack(col))
        self.name:SetText(info.name .. (info.level and ("  |cff999999" .. T("niv.") .. " " .. info.level .. "|r") or ""))
        -- portrait de l'unité, sinon icône neutre
        self.portrait:SetTexture("Interface\\Icons\\INV_Misc_Head_Dragon_01")
        if info.unit and SetPortraitTexture then pcall(SetPortraitTexture, self.portrait, info.unit) end
        -- ligne : butin notable, puis tué / jamais tué
        local parts = {}
        if info.id then
            for _, l in ipairs(R:Loot(info.id)) do
                local nm = WK.GetItemInfo(l.id) or ("#" .. l.id)
                if l.prof and #l.who > 0 then table.insert(parts, 1, nm .. " (" .. T(l.prof) .. ")")
                else table.insert(parts, nm) end
                if #parts >= 2 then break end
            end
            local k = R:Killed(info.id, WK:CharKey())
            table.insert(parts, k and string.format(T("déjà tué il y a %s"), WK:FormatTime(time() - k)) or T("jamais tué par ce perso"))
        end
        self.sub:SetText(table.concat(parts, " · "))
        -- Cibler : hors combat seulement (le jeu protège le ciblage)
        local inCombat = InCombatLockdown and InCombatLockdown()
        if not inCombat then
            self.target:SetAttribute("macrotext", "/targetexact " .. (info.unitName or info.name))
        end
        self.target:SetAlpha(inCombat and 0.4 or 1)
        local r, g, b = UI:Accent()
        self.target.bg:SetColor(r, g, b, 1)
        self.target.label:SetTextColor(unpack(C.onAccent))
        self.guide:SetShown(info.rare ~= nil)
        self.guide:SetScript("OnClick", function() if info.rare then R:GuideTo(info.rare) end end)
        self.until_ = GetTime() + 25
        self:Show()
    end

    f:Hide()
    UI:RegisterHUD("rareAlert", f, {
        label = T("Alerte de rare"), protected = true, default = { 0, UIParent:GetHeight() / 2 - 110 },
        sample = function(on)
            f.sample = on or nil
            if on then f:Show2({ name = "Gruff Swiftbite", level = 12, id = 100, rare = R:Get(100) }) else f:Hide() end
        end,
    })
    return f
end

R.OnSpotted = function(_, info)
    local cfg = R:Config()
    if not cfg.alert then return end
    if not frame then
        if InCombatLockdown and InCombatLockdown() then
            -- premier rare en combat : le bandeau (qui porte un bouton protégé) se crée à la sortie
            WK:Print(string.format(T("Rare en vue : %s"), info.name))
            return
        end
        frame = build()
    end
    frame:Show2(info)
    if cfg.sound and PlaySound then pcall(PlaySound, (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959, "Master") end
end

-- Test depuis les réglages
function UI:TestRareAlert()
    if InCombatLockdown and InCombatLockdown() then return end
    frame = frame or build()
    frame:Show2({ name = R:Name(R:Get(100)) ~= "?" and R:Name(R:Get(100)) or "Gruff Swiftbite", level = 12, id = 100, rare = R:Get(100) })
end

WK:On("PLAYER_LOGIN", function()
    C_Timer.After(1, function() if not (InCombatLockdown and InCombatLockdown()) then frame = frame or build() end end)
end)
