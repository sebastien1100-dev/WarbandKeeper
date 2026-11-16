local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Alerte « Rare en vue » (Modules/Rares.lua), deux styles au choix (Rares:Config().alertStyle) :
--   « banner »  : bandeau en haut de l'écran, portrait, niveau, butin notable, s'il a déjà été tué,
--                 et deux boutons : Cibler (bouton protégé, hors combat) et Guider ;
--   « compact » : une seule ligne, sans bouton ; un clic dessus lance le guidage.
-- Disparaît seule après 25 s. Chaque style se place en mode édition.
-- UI:RareAlertPreview(parent) fabrique un aperçu (sans bouton protégé) pour la colonne de réglages de la page Rares.
local R = WK.modules.Rares
local banner, compact

-- Texte de la ligne de détail : butin notable, puis tué / jamais tué
local function detail(info, short)
    local parts = {}
    if not short and info.id then
        for _, l in ipairs(R:Loot(info.id)) do
            local nm = WK.GetItemInfo(l.id) or ("#" .. l.id)
            if l.prof and #l.who > 0 then table.insert(parts, 1, nm .. " (" .. T(l.prof) .. ")") else table.insert(parts, nm) end
            if #parts >= 2 then break end
        end
    end
    local k = info.killedAt
    if k == nil and info.id then k = R:Killed(info.id, WK:CharKey()) end
    if short then
        table.insert(parts, 1, (info.level and (T("Niveau") .. " " .. info.level) or "") .. " · " .. T(info.elite and "Rare élite" or "Rare"))
        table.insert(parts, k and ("|cff9ed17a" .. T("déjà tué") .. "|r") or T("jamais tué"))
    else
        table.insert(parts, k and string.format(T("déjà tué il y a %s"), WK:FormatTime(time() - k)) or T("jamais tué par ce perso"))
    end
    return table.concat(parts, " · ")
end

local function portrait(tex, info)
    tex:SetTexture("Interface\\Icons\\INV_Misc_Head_Dragon_01")
    if info.unit and SetPortraitTexture then pcall(SetPortraitTexture, tex, info.unit) end
end

---------------------------------------------------------------------------
-- Fabrication (secure : bouton Cibler protégé, seulement pour le vrai bandeau)
---------------------------------------------------------------------------
local function makeBanner(parent, name, secure)
    local f = CreateFrame("Frame", name, parent)
    f:SetSize(460, 74)
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
    f.sub = UI:Text(f, 11, C.muted)
    f.sub:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -4)
    f.sub:SetPoint("RIGHT", -110, 0)
    f.sub:SetJustifyH("LEFT")
    local tgt
    if secure then
        tgt = CreateFrame("Button", "WarbandKeeperRareTarget", f, "SecureActionButtonTemplate")
        if tgt.RegisterForClicks then tgt:RegisterForClicks("AnyUp", "AnyDown") end
        tgt:SetAttribute("type", "macro")
    else
        tgt = CreateFrame("Button", nil, f)
    end
    tgt:SetSize(86, 24)
    tgt:SetPoint("TOPRIGHT", -14, -12)
    tgt.bg = UI:Rounded(tgt, 12, 0, "BACKGROUND", 1)
    tgt.label = UI:Text(tgt, 12)
    tgt.label:SetPoint("CENTER")
    tgt.label:SetText(T("Cibler"))
    f.target = tgt
    f.guide = UI:Button(f, "Guider", 86, 24, "secondary")
    f.guide:SetPoint("TOPRIGHT", tgt, "BOTTOMRIGHT", 0, -6)
    f.close = UI:IconButton(f, "close", 16, nil, "accent")
    f.close:SetPoint("TOPRIGHT", f, "TOPLEFT", 458, -2)
    f.close:SetFrameLevel(tgt:GetFrameLevel() + 2)
    f.close:SetScript("OnClick", function() f:Hide() end)

    function f:Fill(info)
        local col = info.elite and C.gold or C.rare
        self.edge:SetColor(unpack(col))
        self.bg:SetColor(C.bg[1], C.bg[2], C.bg[3], 0.96)
        self.ring:SetVertexColor(unpack(col))
        self.kicker:SetText(info.elite and T("RARE ÉLITE EN VUE") or T("RARE EN VUE"))
        self.kicker:SetTextColor(unpack(col))
        self.name:SetText(info.name .. (info.level and ("  |cff999999" .. T("niv.") .. " " .. info.level .. "|r") or ""))
        portrait(self.portrait, info)
        self.sub:SetText(detail(info))
        local inCombat = InCombatLockdown and InCombatLockdown()
        if secure and not inCombat then
            self.target:SetAttribute("macrotext", "/targetexact " .. (info.unitName or info.name))
        end
        self.target:SetAlpha((secure and inCombat) and 0.4 or 1)
        local r, g, b = UI:Accent()
        self.target.bg:SetColor(r, g, b, 1)
        self.target.label:SetTextColor(unpack(C.onAccent))
        self.guide:SetShown(info.rare ~= nil)
        self.guide:SetScript("OnClick", function() if info.rare then R:GuideTo(info.rare) end end)
    end
    return f
end

local function makeCompact(parent, name)
    local f = CreateFrame("Button", name, parent)
    f:SetSize(320, 52)
    f.edge = UI:Rounded(f, 12, 0, "BACKGROUND", 0)
    f.bg = UI:Rounded(f, 11, 1, "BACKGROUND", 1)
    f.portrait = UI:RoundIcon(f, 36)
    f.portrait:SetPoint("LEFT", 9, 0)
    f.ring = UI:Icon(f, "ring", 40, nil, "OVERLAY")
    f.ring:SetPoint("CENTER", f.portrait, "CENTER")
    f.name = UI:Text(f, 13)
    f.name:SetPoint("TOPLEFT", 54, -9)
    f.name:SetPoint("RIGHT", -30, 0)
    f.name:SetJustifyH("LEFT")
    f.sub = UI:Text(f, 10, C.muted)
    f.sub:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -3)
    f.sub:SetPoint("RIGHT", -30, 0)
    f.sub:SetJustifyH("LEFT")
    f.pin = UI:Icon(f, "guide", 14, nil, "OVERLAY")
    f.pin:SetPoint("RIGHT", -12, 0)
    f:SetScript("OnEnter", function(s)
        WK.UI:TooltipOwner(s, "ANCHOR_BOTTOM")
        GameTooltip:SetText(T("Clic : guidage vers ce rare"), 1, 1, 1)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    function f:Fill(info)
        local col = info.elite and C.gold or C.rare
        self.edge:SetColor(unpack(col))
        self.bg:SetColor(C.bg[1], C.bg[2], C.bg[3], 0.96)
        self.ring:SetVertexColor(unpack(col))
        self.pin:SetVertexColor(UI:Accent())
        self.name:SetText(info.name)
        portrait(self.portrait, info)
        self.sub:SetText(detail(info, true))
        self:SetScript("OnClick", function() if info.rare then R:GuideTo(info.rare) end; self:Hide() end)
    end
    return f
end

---------------------------------------------------------------------------
-- Alertes à l'écran
---------------------------------------------------------------------------
local function arm(f, key, label)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetScript("OnUpdate", function(s)
        if s.sample then return end
        if s.until_ and GetTime() > s.until_ then s:Hide() end
    end)
    f:Hide()
    UI:RegisterHUD(key, f, {
        label = label, protected = key == "rareAlert", default = { 0, UIParent:GetHeight() / 2 - 110 },
        sample = function(on)
            f.sample = on or nil
            if on then f:Fill({ name = "Gruff Swiftbite", level = 12, id = 100, rare = R:Get(100) }); f:Show() else f:Hide() end
        end,
    })
end

local function show(info)
    local cfg = R:Config()
    local f
    if cfg.alertStyle == "compact" then
        if not compact then compact = makeCompact(UIParent, "WarbandKeeperRareCompact"); arm(compact, "rareCompact", T("Alerte de rare (compacte)")) end
        f = compact
    else
        if not banner then
            if InCombatLockdown and InCombatLockdown() then
                -- premier rare en combat : le bandeau (qui porte un bouton protégé) se crée à la sortie
                WK:Print(string.format(T("Rare en vue : %s"), info.name))
                return
            end
            banner = makeBanner(UIParent, "WarbandKeeperRareAlert", true); arm(banner, "rareAlert", T("Alerte de rare"))
        end
        f = banner
    end
    f:Fill(info)
    f.until_ = GetTime() + 25
    f:Show()
    if cfg.sound and PlaySound then pcall(PlaySound, (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959, "Master") end
end

R.OnSpotted = function(_, info)
    if R:Config().alert then show(info) end
end

-- Test depuis les réglages
function UI:TestRareAlert(state)
    if InCombatLockdown and InCombatLockdown() then return end
    local r = R:Get(100)
    show({ name = (r and R:Name(r)) or "Gruff Swiftbite", level = 12, id = 100, rare = r, elite = state == "elite",
           killedAt = state == "killed" and (time() - 2 * 86400) or (state and false) or nil })
end

-- Aperçu pour la page de réglages : { Fill(state, style) }
function UI:RareAlertPreview(parent)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(460, 74)
    holder.banner = makeBanner(holder, nil, false)
    holder.banner:SetPoint("CENTER")
    holder.banner.close:Hide()
    holder.compact = makeCompact(holder, nil)
    holder.compact:SetPoint("CENTER")
    function holder:Fill(state, style)
        local r = R:Get(100)
        local info = { name = (r and R:Name(r)) or "Gruff Swiftbite", level = 12, id = 100, rare = r, elite = state == "elite",
                       killedAt = state == "killed" and (time() - 2 * 86400) or false }
        self.banner:SetShown(style ~= "compact")
        self.compact:SetShown(style == "compact")
        local f = style == "compact" and self.compact or self.banner
        f:Fill(info)
        if style == "compact" then f:SetScript("OnClick", nil) end
    end
    return holder
end

WK:On("PLAYER_LOGIN", function()
    C_Timer.After(1, function()
        if not (InCombatLockdown and InCombatLockdown()) and not banner then
            banner = makeBanner(UIParent, "WarbandKeeperRareAlert", true); arm(banner, "rareAlert", T("Alerte de rare"))
        end
        if not compact then compact = makeCompact(UIParent, "WarbandKeeperRareCompact"); arm(compact, "rareCompact", T("Alerte de rare (compacte)")) end
    end)
end)
