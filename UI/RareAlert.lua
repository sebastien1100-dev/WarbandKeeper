local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Un cadre protégé ne se cache pas en combat : il devient transparent et sera caché à la sortie du combat
-- (le bandeau n'est jamais protégé : le bouton de ciblage est à part, voir tbCover).
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

---------------------------------------------------------------------------
-- Cibler le rare d'un clic (le ciblage est protégé) : un seul bouton protégé `WarbandKeeperRareTarget`, enfant
-- d'UIParent, posé par ses coordonnées sur le bandeau survolé, hors combat (jamais enfant ni ancré au bandeau, qui
-- s'affiche aussi en combat). Macro : /targetexact <nom>, puis tête de mort si c'est bien lui (réglage skull).
-- Retiré en partant et à l'entrée en combat. Bandeau : toute la surface sauf Guider et la croix ; compact : tout,
-- et le clic lance aussi le guidage.
---------------------------------------------------------------------------
local TB
local function macroFor(info)
    local name = info.unitName or info.name
    if not name or name == "" or name:find("[\n\r]") then return nil end
    local m = "/targetexact " .. name
    if R:Config().skull ~= false then
        local q = name:gsub("\\", "\\\\"):gsub("\"", "\\\"")
        m = m .. "\n/run if UnitName(\"target\")==\"" .. q .. "\" and GetRaidTargetIndex(\"target\")~=8 then"
            .. " SetRaidTarget(\"target\",8) end"
    end
    return #m <= 255 and m or ("/targetexact " .. name)
end
local function tbHide()
    if not TB or inCombat() then return end
    TB.owner, TB.info = nil, nil
    TB:SetAttribute("type", nil)
    TB:Hide()
end
local function tbButton()
    if TB then return TB end
    local ok, b = pcall(_G.CreateFrame, "Button", "WarbandKeeperRareTarget", _G.UIParent, "SecureActionButtonTemplate")
    if not ok or not b then return nil end
    TB = b
    b:Hide()
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetScript("PostClick", function(s, _, down)
        if down then return end
        local f, info, post = s.owner, s.info, s.post
        if f and post and info then post(info, f) end
    end)
    b:SetScript("OnEnter", function(s)
        -- cadre dessous qui a sa propre infobulle (médaillon de la carte, ligne de liste) : elle est reprise
        if s.enter and s.owner then s.enter(s.owner) return end
        UI:TooltipOwner(s, "ANCHOR_BOTTOM")
        local tt = _G.GameTooltip
        tt:SetText(T("Clic : cibler ce rare"), 1, 1, 1)
        if R:Config().skull ~= false then tt:AddLine(T("et le marquer d'une tête de mort"), 0.8, 0.8, 0.8) end
        if s.post then tt:AddLine(T("et lancer le guidage"), 0.8, 0.8, 0.8) end
        tt:Show()
    end)
    b:SetScript("OnLeave", function(s)
        local o, leave = s.owner, s.leave
        _G.GameTooltip:Hide(); tbHide()
        if leave and o then leave(o) end
    end)
    b:SetScript("OnUpdate", function(s)
        local o = s.owner
        if not o or not o:IsVisible() or o:GetAlpha() == 0 or (s.lastL and o:GetLeft() ~= s.lastL) then tbHide() end
    end)
    return b
end
-- pose le bouton sur le cadre f (survolé) ; right = largeur laissée libre à droite (Guider, croix) ;
-- opts = { post(info, f) après le clic, enter(f) / leave(f) = infobulle du cadre dessous }
local function tbCover(f, right, info, opts)
    info = info or f.info
    if inCombat() or f.sample or f.preview or not info then return end
    if TB and TB:IsShown() and TB.owner == f then return end
    local m = macroFor(info)
    if not m then return end
    local b = tbButton()
    if not b then return end
    local l, bt, w, h = f:GetRect()
    if not l then return end
    local k = f:GetEffectiveScale() / _G.UIParent:GetEffectiveScale()
    b:SetAttribute("type", "macro")
    b:SetAttribute("macrotext", m)
    b.owner, b.info, b.lastL = f, info, f:GetLeft()
    b.post, b.enter, b.leave = opts and opts.post, opts and opts.enter, opts and opts.leave
    b:ClearAllPoints()
    b:SetPoint("BOTTOMLEFT", _G.UIParent, "BOTTOMLEFT", l * k, bt * k)
    b:SetSize(math.max(10, (w - (right or 0)) * k), h * k)
    b:SetFrameStrata(f:GetFrameStrata())
    b:SetFrameLevel(f:GetFrameLevel() + 20)
    b:Show()
end
WK:On("PLAYER_REGEN_DISABLED", function()
    if not TB then return end
    -- dernier moment permis : en combat, le bouton ne pourrait plus être caché ni déplacé
    TB.owner, TB.info = nil, nil
    TB:SetAttribute("type", nil)
    TB:Hide()
end)
-- aussi pour la carte du monde (UI/RarePins.lua : médaillons et liste des rares)
UI.RareTargetCover = tbCover
UI.RareTargetOwner = function() return TB and TB:IsShown() and TB.owner or nil end

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
    -- survol : bouton protégé posé dessus pour cibler le rare (hors combat)
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(s)
        if inCombat() then
            UI:TooltipOwner(s, "ANCHOR_BOTTOM")
            _G.GameTooltip:SetText(T("En combat : le jeu ne permet pas de cibler d'un clic"), 1, 1, 1)
            _G.GameTooltip:Show()
            return
        end
        tbCover(s, 64)
    end)
    f:SetScript("OnLeave", function() _G.GameTooltip:Hide() end)

    function f:Fill(info)
        self.info = info
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
    f.compactStyle = true
    f:SetScript("OnEnter", function(s)
        if not inCombat() and s.info then
            tbCover(s, 0, nil, { post = function(info, fr)
                if info.rare then R:GuideTo(info.rare) end
                R:MarkSkull(info)
                tbHide(); safeHide(fr)
            end })
        end
        if TB and TB:IsShown() and TB.owner == s then return end
        WK.UI:TooltipOwner(s, "ANCHOR_BOTTOM")
        GameTooltip:SetText(T("Clic : guidage vers ce rare"), 1, 1, 1)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    function f:Fill(info)
        self.info = info
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
    holder.banner.preview = true
    holder.banner:SetPoint("CENTER")
    holder.banner.close:Hide()
    holder.compact = makeCompact(holder, nil)
    holder.compact.preview = true
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
