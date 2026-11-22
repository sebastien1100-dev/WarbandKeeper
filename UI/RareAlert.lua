local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Un cadre protégé ne se cache pas en combat : il devient transparent et sera caché à la sortie du combat
-- (le bandeau n'a plus de bouton protégé, garde-fou pour la suite).
local pendingHide = {}
local function inCombat() return InCombatLockdown and InCombatLockdown() end
local function safeHide(f)
    if f:IsProtected() and inCombat() then
        f:SetAlpha(0)
        pendingHide[f] = true
        return
    end
    pendingHide[f] = nil
    f:Hide()
end
WK:On("PLAYER_REGEN_ENABLED", function()
    for f in pairs(pendingHide) do pendingHide[f] = nil; f:Hide(); f:SetAlpha(1) end
end)

-- Alerte « Rare en vue » (Modules/Rares.lua), deux styles au choix (Rares:Config().alertStyle) :
--   « banner »  : bandeau en haut de l'écran, portrait, niveau, butin notable, s'il a déjà été tué,
--                 et la flèche Guider (icône ronde, pose la tête de mort) ;
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
        table.insert(parts, k and (UI:Hex(C.positive) .. T("déjà tué") .. "|r") or T("jamais tué"))
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
-- Fabrication (plus de bouton Cibler protégé : seulement la flèche de guidage)
---------------------------------------------------------------------------
local function makeBanner(parent, name)
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
    f.name:SetPoint("RIGHT", -60, 0)
    f.name:SetJustifyH("LEFT")
    f.sub = UI:Text(f, 11, C.muted)
    f.sub:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -4)
    f.sub:SetPoint("TOPRIGHT", f.name, "BOTTOMRIGHT", 0, -4)
    f.sub:SetJustifyH("LEFT")
    -- Guider : icône ronde (comme les listes Rares et Quêtes) ; pose aussi la tête de mort sur le rare
    f.guide = UI:GuideButton(f, 32, "Guider vers ce rare (et marquer d'une tête de mort)")
    f.guide:SetPoint("RIGHT", -16, -4)
    f.close = UI:IconButton(f, "close", 16, nil, "accent")
    f.close:SetPoint("TOPRIGHT", f, "TOPLEFT", 458, -2)
    f.close:SetFrameLevel(f.guide:GetFrameLevel() + 2)
    f.close:SetScript("OnClick", function() safeHide(f) end)

    function f:Fill(info)
        local col = info.elite and C.gold or C.rare
        self.edge:SetColor(unpack(col))
        self.bg:SetColor(C.bg[1], C.bg[2], C.bg[3], 0.96)
        self.ring:SetVertexColor(unpack(col))
        self.kicker:SetText(info.elite and T("RARE ÉLITE EN VUE") or T("RARE EN VUE"))
        self.kicker:SetTextColor(unpack(col))
        self.name:SetText(info.name .. (info.level and ("  " .. UI:Hex(C.muted) .. T("niv.") .. " " .. info.level .. "|r") or ""))
        portrait(self.portrait, info)
        self.sub:SetText(detail(info))
        self.guide:SetShown(info.rare ~= nil)
        self.guide:SetScript("OnClick", function()
            if info.rare then R:GuideTo(info.rare) end
            R:MarkSkull(info)
        end)
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
    f.name:SetPoint("TOPRIGHT", -30, -9)
    f.name:SetJustifyH("LEFT")
    f.sub = UI:Text(f, 10, C.muted)
    f.sub:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -3)
    f.sub:SetPoint("TOPRIGHT", f.name, "BOTTOMRIGHT", 0, -3)
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
        self:SetScript("OnClick", function() if info.rare then R:GuideTo(info.rare) end; R:MarkSkull(info); safeHide(self) end)
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
        if s.until_ and GetTime() > s.until_ then s.until_ = nil; safeHide(s) end
    end)
    f:Hide()
    -- exemple : nom dans la langue de l'addon (avant, toujours en anglais)
    local function demo()
        local r = R:Get(100)
        return { name = (r and R:Name(r)) or "Gruff Swiftbite", level = 12, id = 100, rare = r }
    end
    local style = key == "rareCompact" and "compact" or "banner"
    UI:RegisterHUD(key, f, {
        label = label, default = { 0, UIParent:GetHeight() / 2 - 110 },
        -- montré en mode édition seulement si l'alerte est active et que ce style est choisi
        enabled = function()
            local cfg = R:Config()
            return cfg.alert ~= false and (cfg.alertStyle or "banner") == style and WK:FeatureOn("rares")
        end,
        sample = function(on)
            f.sample = on or nil
            if on then f:Fill(demo()); f:Show() else safeHide(f) end
        end,
        -- test : comme une vraie apparition (minuterie et son)
        test = function()
            f.sample = nil
            f:Fill(demo())
            f.until_ = GetTime() + 25
            f:Show()
            if R:Config().sound and PlaySound then pcall(PlaySound, (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959, "Master") end
        end,
        testStop = function() f.until_ = nil; safeHide(f) end,
    })
end

local function show(info)
    local cfg = R:Config()
    local f
    if cfg.alertStyle == "compact" then
        if not compact then compact = makeCompact(UIParent, "WarbandKeeperRareCompact"); arm(compact, "rareCompact", T("Alerte de rare (compacte)")) end
        f = compact
    else
        if not banner then banner = makeBanner(UIParent, "WarbandKeeperRareAlert"); arm(banner, "rareAlert", T("Alerte de rare")) end
        f = banner
    end
    f:Fill(info)
    f.until_ = GetTime() + 25
    pendingHide[f] = nil
    f:SetAlpha(1)
    f:Show()
    if cfg.sound and PlaySound then pcall(PlaySound, (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959, "Master") end
end

R.OnSpotted = function(_, info)
    if R:Config().alert then show(info) end
end

-- Test depuis les réglages
function UI:TestRareAlert(state)
    local r = R:Get(100)
    show({ name = (r and R:Name(r)) or "Gruff Swiftbite", level = 12, id = 100, rare = r, elite = state == "elite",
           killedAt = state == "killed" and (time() - 2 * 86400) or (state and false) })
end

-- Aperçu pour la page de réglages : { Fill(state, style) }
function UI:RareAlertPreview(parent)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(460, 74)
    holder.banner = makeBanner(holder, nil)
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
        if not banner then banner = makeBanner(UIParent, "WarbandKeeperRareAlert"); arm(banner, "rareAlert", T("Alerte de rare")) end
        if not compact then compact = makeCompact(UIParent, "WarbandKeeperRareCompact"); arm(compact, "rareCompact", T("Alerte de rare (compacte)")) end
    end)
end)
