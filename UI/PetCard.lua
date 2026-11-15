local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Carte du familier (chasseur) : nom, vie, humeur, nourriture prévue, boutons Nourrir et Soigner.
-- Les boutons (et la carte elle-même : clic gauche nourrir, clic droit soigner) sont protégés :
-- ils marchent en combat, mais leur disposition ne change qu'hors combat.
-- Réglages : WK.modules.QoL:Class("HUNTER").petCard
local card
local SPELL_FEED, SPELL_MEND, SPELL_REVIVE = 6991, 136, 982
local DEFAULTS = {
    enabled = true, width = 300, barH = 12, numbers = "full", color = "mood", mood = "both",
    food = "iconName", buttons = true, name = true, show = "always", needHealth = 60, oocAlpha = 1,
}

local function cfg()
    local cc = WK.modules.QoL:Class("HUNTER")
    cc.petCard = cc.petCard or {}
    for k, v in pairs(DEFAULTS) do if cc.petCard[k] == nil then cc.petCard[k] = v end end
    return cc.petCard
end
UI.PetCardConfig = cfg

local function inCombat() return InCombatLockdown and InCombatLockdown() end
local readable = function(v) return WK.modules.QoL.Readable(v) end
local function spellName(id) return (WK.SpellInfo(id)) end

local function wanted()
    local me = WK.DB:Me()
    return me.class == "HUNTER" and cfg().enabled and not WK.modules.Hunter:OtherAddonLoaded()
end

local function visibility()
    local s = cfg().show
    -- Familier mort : la carte reste là, « Soigner » devient « Ressusciter ».
    if s == "ooc" then return "[combat] hide; [@pet,dead] show; [nopet] hide; show" end
    return "[@pet,dead] show; [nopet] hide; show"
end

local function secureButton(parent, name)
    local b = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
    if b.RegisterForClicks then b:RegisterForClicks("AnyUp", "AnyDown") end
    return b
end

local function build()
    local f = CreateFrame("Frame", "WarbandKeeperPetCard", UIParent)
    f:SetSize(300, 90)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    UI:Panel(f, 10, { C.bg[1], C.bg[2], C.bg[3], 0.92 }, C.border)
    -- Zone de clic de toute la carte : gauche nourrir, droite soigner
    f.click = secureButton(f, "WarbandKeeperPetCardClick")
    f.click:SetAllPoints()
    f.click:SetFrameLevel(f:GetFrameLevel() + 1)
    f.name = UI:Text(f, 12)
    f.hp = CreateFrame("Frame", nil, f)
    f.hpTrack = UI:Rounded(f.hp, 4, 0, "BACKGROUND", 1)
    f.hpFillF = CreateFrame("Frame", nil, f.hp)
    f.hpFillF:SetPoint("TOPLEFT"); f.hpFillF:SetPoint("BOTTOMLEFT")
    f.hpFill = UI:Rounded(f.hpFillF, 4, 0, "ARTWORK", 1)
    -- Chiffres au-dessus du remplissage (un cadre enfant passe devant les textes de son parent)
    f.hpTop = CreateFrame("Frame", nil, f.hp)
    f.hpTop:SetAllPoints()
    f.hpTop:SetFrameLevel(f.hpFillF:GetFrameLevel() + 2)
    f.hpText = UI:Text(f.hpTop, 10, C.text)
    if f.hpText.SetShadowOffset then f.hpText:SetShadowOffset(1, -1); f.hpText:SetShadowColor(0, 0, 0, 1) end
    f.hpText:SetPoint("RIGHT", -6, 0)
    f.hpText:SetJustifyH("RIGHT")
    f.segs = {}
    for i = 1, 3 do
        local sF = CreateFrame("Frame", nil, f)
        sF:SetSize(22, 6)
        sF.tex = UI:Rounded(sF, 3, 0, "ARTWORK", 1)
        f.segs[i] = sF
    end
    f.moodText = UI:Text(f, 10)
    f.food = f:CreateTexture(nil, "ARTWORK")
    f.food:SetSize(28, 28)
    f.food:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.foodCount = UI:Text(f, 10, C.gold)
    f.foodCount:SetPoint("BOTTOMRIGHT", f.food, "BOTTOMRIGHT", 4, -4)
    f.foodName = UI:Text(f, 9, C.muted)
    f.foodName:SetPoint("TOP", f.food, "BOTTOM", 0, -3)
    f.foodName:SetJustifyH("CENTER")
    -- Boutons protégés Nourrir / Soigner (visuel de nos boutons, clic protégé par-dessus)
    local function makeBtn(label, style)
        -- largeur fixe, assez grande pour « Ressusciter » (le bouton protégé ne change pas de taille en combat)
        local vis = UI:Button(f, label, 92, 22, style)
        local sec = secureButton(f)
        sec:SetAllPoints(vis)
        sec:SetFrameLevel(f:GetFrameLevel() + 5)
        sec:SetScript("OnEnter", function() vis.hover = true; if vis.Refresh then vis:Refresh() end end)
        sec:SetScript("OnLeave", function() vis.hover = false; if vis.Refresh then vis:Refresh() end end)
        return vis, sec
    end
    f.feedVis, f.feedSec = makeBtn("Nourrir", "primary")
    f.mendVis, f.mendSec = makeBtn("Soigner", "secondary")
    f.click:SetScript("OnEnter", function(s)
        WK.UI:TooltipOwner(s, "ANCHOR_TOP")
        GameTooltip:SetText(T("Familier"), 1, 1, 1)
        GameTooltip:AddLine(T("Clic : nourrir · Clic droit : soigner, ou ressusciter s'il est mort"), 0.85, 0.85, 0.85)
        GameTooltip:Show()
    end)
    f.click:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f:Hide()
    UI:RegisterHUD("petCard", f, {
        label = T("Carte du familier"), protected = true, default = { 0, -260 },
        sample = function(on)
            f.sample = on or nil
            if on then f:Paint(true) end
        end,
    })
    return f
end

-- Attributs protégés : macro de nourriture et sort de soin (hors combat).
local function setActions()
    if not card or inCombat() then return end
    local feed, mend = spellName(SPELL_FEED) or "Nourrir le familier", spellName(SPELL_MEND) or "Guérison du familier"
    local food = WK.modules.QoL:FoodInBags()[1]
    local foodName = food and WK.GetItemInfo(food.id)
    local macro = "/cast " .. feed .. (foodName and ("\n/use " .. foodName) or "")
    for _, b in ipairs({ card.click, card.feedSec }) do
        b:SetAttribute("type1", "macro"); b:SetAttribute("macrotext1", macro)
    end
    -- Soigner, ou ressusciter si le familier est mort (aussi pour le clic droit et le raccourci)
    local revive = spellName(SPELL_REVIVE) or "Ressusciter le familier"
    local heal = "/cast [@pet,dead][nopet] " .. revive .. "; [@pet] " .. mend
    card.click:SetAttribute("type2", "macro"); card.click:SetAttribute("macrotext2", heal)
    card.mendSec:SetAttribute("type1", "macro"); card.mendSec:SetAttribute("macrotext1", heal)
end

-- Disposition selon les réglages (hors combat : la carte contient des boutons protégés).
function UI:PetCardLayout()
    if not card then return end
    if inCombat() then card.pendingLayout = true return end
    card.pendingLayout = nil
    local o = cfg()
    local f = card
    local foodW = o.food == "hidden" and 0 or (o.food == "iconName" and 60 or 36)
    local y = -9
    f.name:ClearAllPoints()
    f.name:SetShown(o.name)
    if o.name then f.name:SetPoint("TOPLEFT", 12, y); y = y - 19 end
    f.hp:ClearAllPoints()
    f.hp:SetPoint("TOPLEFT", 12, y)
    f.hp:SetPoint("TOPRIGHT", -(12 + foodW), y)
    f.hp:SetHeight(o.barH)
    f.hpText:SetFont(UI.FONT, math.max(8, math.min(12, o.barH - 2)), "")
    y = y - o.barH - 6
    local showSegs = o.mood == "both" or o.mood == "segments"
    local showText = o.mood == "both" or o.mood == "text"
    for i, sF in ipairs(f.segs) do
        sF:ClearAllPoints()
        sF:SetPoint("TOPLEFT", 12 + (i - 1) * 25, y - 2)
        sF:SetShown(showSegs)
    end
    f.moodText:ClearAllPoints()
    f.moodText:SetPoint("TOPLEFT", showSegs and 92 or 12, y + 1)
    f.moodText:SetShown(showText)
    if o.mood ~= "hidden" then y = y - 14 end
    f.feedVis:ClearAllPoints(); f.mendVis:ClearAllPoints()
    f.feedVis:SetShown(o.buttons); f.mendVis:SetShown(o.buttons)
    f.feedSec:SetShown(o.buttons); f.mendSec:SetShown(o.buttons)
    if o.buttons then
        y = y - 4
        f.feedVis:SetPoint("TOPLEFT", 12, y)
        f.mendVis:SetPoint("LEFT", f.feedVis, "RIGHT", 6, 0)
        y = y - 24
    end
    f.food:ClearAllPoints()
    f.food:SetShown(o.food ~= "hidden"); f.foodCount:SetShown(o.food ~= "hidden")
    f.foodName:SetShown(o.food == "iconName")
    f.food:SetPoint("TOPRIGHT", -(12 + (foodW - 28) / 2 - (o.food == "iconName" and 0 or 4)), -10)
    local h = math.max(-y + 8, o.food == "iconName" and 58 or 44)
    f:SetSize(o.width, h)
    setActions()
    if RegisterStateDriver and wanted() then RegisterStateDriver(f, "visibility", visibility()) end
    UI:HUDApply("petCard")
    f:Paint()
end

local MOOD = { "Mécontent", "Content", "Heureux" }
function UI:PetCardPaint() if card then card:Paint() end end

local function paint(self, demo)
    local o = cfg()
    local mood = { C.negative, C.warning, C.positive }
    local name, family, level, hp, hpMax, happy, foodId, foodN
    if demo then
        name, family, level, hp, hpMax, happy, foodId, foodN = "Croc", T("Loup"), 22, 696, 720, 3, 2672, 14
    else
        name = UnitName and UnitName("pet")
        family = UnitCreatureFamily and UnitCreatureFamily("pet")
        level = UnitLevel and UnitLevel("pet")
        hp, hpMax = readable(UnitHealth and UnitHealth("pet")), readable(UnitHealthMax and UnitHealthMax("pet"))
        self.dead = UnitIsDead and UnitIsDead("pet") or false
        if hp then self.lastHp, self.lastMax = hp, hpMax else hp, hpMax = self.lastHp, self.lastMax end
        happy = WK.modules.QoL:PetHappiness() or self.lastHappy
        self.lastHappy = happy
        local food = WK.modules.QoL:FoodInBags()[1]
        foodId, foodN = food and food.id, food and food.n
    end
    self.name:SetText((name or "?") .. "  |cffb6a27e" .. (family and (family .. " ") or "") .. (level or "") .. "|r")
    local ratio = (hp and hpMax and hpMax > 0) and hp / hpMax or 0
    local col
    if o.color == "health" then col = ratio > 0.5 and C.positive or (ratio > 0.25 and C.warning or C.negative)
    elseif o.color == "theme" then local r, g, b = UI:Accent(); col = { r, g, b, 1 }
    else col = mood[happy or 2] end
    self.hpTrack:SetColor(unpack(C.surface2))
    self.hpFill:SetColor(col[1], col[2], col[3], 1)
    local w = self.hp:GetWidth() or 200
    self.hpFillF:SetWidth(math.max(4, w * ratio))
    local txt = ""
    if hp and hpMax then
        if o.numbers == "value" then txt = tostring(hp)
        elseif o.numbers == "full" then txt = hp .. " / " .. hpMax
        elseif o.numbers == "pct" then txt = math.floor(ratio * 100 + 0.5) .. " %" end
    end
    self.hpText:SetText(txt)
    local mc = mood[happy or 2]
    for i, sF in ipairs(self.segs) do
        if i <= (happy or 0) then sF.tex:SetColor(mc[1], mc[2], mc[3], 1) else sF.tex:SetColor(unpack(C.surface2)) end
    end
    self.moodText:SetText(T(MOOD[happy or 2]))
    self.moodText:SetTextColor(mc[1], mc[2], mc[3], 1)
    -- Mort : « Ressusciter » mis en avant, « Nourrir » estompé
    local dead = not demo and self.dead
    self.mendVis.label:SetText(dead and T("Ressusciter") or T("Soigner"))
    self.mendVis.style = dead and "primary" or "secondary"
    self.feedVis.style = dead and "secondary" or "primary"
    if self.mendVis.Refresh then self.mendVis:Refresh() end
    if self.feedVis.Refresh then self.feedVis:Refresh() end
    self.feedVis:SetAlpha(dead and 0.45 or 1)
    if dead then
        self.hpText:SetText(T("Mort"))
        self.moodText:SetText(T("Mort"))
        self.moodText:SetTextColor(unpack(C.negative))
    end
    if foodId then
        local icon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(foodId)) or (GetItemIcon and GetItemIcon(foodId))
        self.food:SetTexture(icon or "Interface\\Icons\\INV_Misc_Food_14")
        self.food:SetDesaturated(false)
        self.foodCount:SetText(foodN or "")
        local fn = WK.GetItemInfo(foodId)
        self.foodName:SetText(fn and (string.len(fn) > 12 and (string.sub(fn, 1, 11) .. ".") or fn) or "")
    else
        self.food:SetTexture("Interface\\Icons\\INV_Misc_Food_14")
        self.food:SetDesaturated(true)
        self.foodCount:SetText("0")
        self.foodName:SetText(T("rien"))
    end
    -- « Si besoin » : effacée tant que tout va bien (elle reste à sa place, le jeu interdit de la
    -- cacher en combat) ; opacité hors combat.
    local e = UI:HUDEntry("petCard")
    local alpha = e.alpha or 1
    if not inCombat() then alpha = alpha * (o.oocAlpha or 1) end
    if o.show == "need" and not demo then
        local fine = (happy == 3) and ratio * 100 >= (o.needHealth or 60)
        if fine then alpha = 0 end
    end
    self:SetAlpha(alpha)
end

function UI:SyncPetCard()
    if inCombat() then return end
    if wanted() then
        card = card or build()
        card.Paint = paint
        self:PetCardLayout()
    elseif card then
        if UnregisterStateDriver then UnregisterStateDriver(card, "visibility") end
        card:Hide()
    end
end

local function refresh() if card then card:Paint() end end
WK:On("PLAYER_LOGIN", function() C_Timer.After(1, function() UI:SyncPetCard() end) end)
WK:On("UNIT_HEALTH", function(u) if u == "pet" then refresh() end end)
WK:On("UNIT_MAXHEALTH", function(u) if u == "pet" then refresh() end end)
WK:On("UNIT_HAPPINESS", refresh)
WK:On("UNIT_PET", function(u) if u == "player" then refresh(); if not inCombat() then setActions() end end end)
WK:On("BAG_UPDATE_DELAYED", function() refresh(); if not inCombat() then setActions() end end)
WK:On("PLAYER_REGEN_DISABLED", refresh)
WK:On("PLAYER_REGEN_ENABLED", function()
    if card and card.pendingLayout then UI:PetCardLayout() end
    setActions(); refresh()
end)
WK:On("PLAYER_LEVEL_UP", function() C_Timer.After(1, function() UI:SyncPetCard() end) end)
