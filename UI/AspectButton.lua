local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Bouton d'aspect (chasseur) : icône de l'aspect actif. Clic gauche : aspect suivant de la liste
-- choisie (le jeu enchaîne les sorts avec /castsequence) ; clic droit : aspect principal.
-- Raccourcis : Options du jeu > Raccourcis > AddOns > Warband Keeper (Bindings.xml).
-- Réglages : WK.modules.QoL:Class("HUNTER").aspectBtn
local btn
local DEFAULTS = { enabled = true, list = { hawk = true, cheetah = true }, main = "hawk" }

local function cfg()
    local cc = WK.modules.QoL:Class("HUNTER")
    cc.aspectBtn = cc.aspectBtn or {}
    for k, v in pairs(DEFAULTS) do
        if cc.aspectBtn[k] == nil then cc.aspectBtn[k] = type(v) == "table" and { hawk = true, cheetah = true } or v end
    end
    return cc.aspectBtn
end
UI.AspectButtonConfig = cfg

local function H() return WK.modules.Hunter end
local function inCombat() return InCombatLockdown and InCombatLockdown() end

local function known(id)
    if IsPlayerSpell and IsPlayerSpell(id) then return true end
    if IsSpellKnown and IsSpellKnown(id) then return true end
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, r = pcall(C_SpellBook.IsSpellKnown, id)
        if ok and r then return true end
    end
    -- Sans fonction fiable : un nom de sort trouvé dans le grimoire suffit.
    return not (IsPlayerSpell or IsSpellKnown or C_SpellBook) and WK.SpellInfo(id) ~= nil
end

-- Aspects connus, dans l'ordre affiché : { { key, id, name, icon } }
function UI:KnownAspects()
    local out = {}
    for _, key in ipairs(H().ASPECT_ORDER) do
        local id = H().ASPECTS[key]
        if known(id) then
            local name, icon = WK.SpellInfo(id)
            if name then table.insert(out, { key = key, id = id, name = name, icon = icon }) end
        end
    end
    return out
end

local function wanted()
    return WK.DB:Me().class == "HUNTER" and cfg().enabled and not H():OtherAddonLoaded() and #UI:KnownAspects() > 0
end

local function build()
    local b = CreateFrame("Button", "WarbandKeeperAspectButton", UIParent, "SecureActionButtonTemplate")
    b:SetSize(44, 44)
    b:SetFrameStrata("MEDIUM")
    b:SetClampedToScreen(true)
    if b.RegisterForClicks then b:RegisterForClicks("AnyUp", "AnyDown") end
    b.ring = UI:Icon(b, "circle", 44, nil, "BACKGROUND")
    b.ring:SetPoint("CENTER")
    b.icon = UI:RoundIcon(b, 38)
    b.icon:SetPoint("CENTER")
    b.next = UI:RoundIcon(b, 18)
    b.next:SetPoint("BOTTOMRIGHT", 6, -6)
    b.nextRing = UI:Icon(b, "circle", 21, nil, "BORDER")
    b.nextRing:SetPoint("CENTER", b.next, "CENTER")
    b.nextRing:SetDrawLayer("OVERLAY", -1)
    b.next:SetDrawLayer("OVERLAY", 1)
    b:SetScript("OnEnter", function(s)
        WK.UI:TooltipOwner(s, "ANCHOR_TOP")
        GameTooltip:SetText(T("Aspects"), 1, 1, 1)
        GameTooltip:AddLine(T("Clic : aspect suivant de ta liste"), 0.85, 0.85, 0.85)
        GameTooltip:AddLine(T("Clic droit : aspect principal"), 0.85, 0.85, 0.85)
        GameTooltip:AddLine(T("Raccourcis : Options > Raccourcis > AddOns"), 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    UI:RegisterHUD("aspect", b, { label = T("Bouton d'aspect"), protected = true, default = { -200, -260 } })
    return b
end

-- Attributs protégés : séquence des aspects choisis (clic gauche), aspect principal (clic droit).
function UI:AspectButtonSetup()
    if not btn or inCombat() then return end
    local o = cfg()
    local names, mainName = {}, nil
    for _, a in ipairs(UI:KnownAspects()) do
        if o.list[a.key] then table.insert(names, a.name) end
        if a.key == o.main then mainName = a.name end
    end
    if #names == 0 and mainName then names = { mainName } end
    btn:SetAttribute("type1", "macro")
    btn:SetAttribute("macrotext1", #names > 1 and ("/castsequence " .. table.concat(names, ", ")) or ("/cast " .. (names[1] or "")))
    btn:SetAttribute("type2", "spell")
    btn:SetAttribute("spell2", mainName or names[1])
    btn.sequence = names
    self:AspectButtonPaint()
end

function UI:AspectButtonPaint()
    if not btn then return end
    local cur = H().aspect
    local list, icons = {}, {}
    for _, a in ipairs(UI:KnownAspects()) do
        icons[a.key] = a.icon
        if cfg().list[a.key] then table.insert(list, a.key) end
    end
    local r, g, b = UI:Accent()
    btn.ring:SetVertexColor(r, g, b, 1)
    btn.nextRing:SetVertexColor(unpack(C.bg))
    btn.icon:SetTexture(icons[cur or ""] or icons[cfg().main] or "Interface\\Icons\\INV_Misc_QuestionMark")
    btn.icon:SetDesaturated(cur == nil)
    -- aspect qui viendra au prochain clic
    local nextKey
    for i, k in ipairs(list) do if k == cur then nextKey = list[i % #list + 1] end end
    nextKey = nextKey or list[1]
    btn.next:SetShown(nextKey ~= nil and #list > 1)
    btn.nextRing:SetShown(nextKey ~= nil and #list > 1)
    if nextKey then btn.next:SetTexture(icons[nextKey]) end
end

function UI:SyncAspectButton()
    if inCombat() then return end
    if wanted() then
        btn = btn or build()
        if RegisterStateDriver then RegisterStateDriver(btn, "visibility", "[dead] hide; show") end
        self:AspectButtonSetup()
    elseif btn then
        if UnregisterStateDriver then UnregisterStateDriver(btn, "visibility") end
        btn:Hide()
    end
end

-- Noms des raccourcis dans les options du jeu (Bindings.xml)
BINDING_HEADER_WARBANDKEEPER = "Warband Keeper"
_G["BINDING_NAME_CLICK WarbandKeeperAspectButton:LeftButton"] = T("Aspect suivant")
_G["BINDING_NAME_CLICK WarbandKeeperAspectButton:RightButton"] = T("Aspect principal")
_G["BINDING_NAME_CLICK WarbandKeeperPetCardClick:LeftButton"] = T("Nourrir le familier")
_G["BINDING_NAME_CLICK WarbandKeeperPetCardClick:RightButton"] = T("Soigner le familier")

WK:On("PLAYER_LOGIN", function() C_Timer.After(1, function() UI:SyncAspectButton() end) end)
WK:On("PLAYER_REGEN_ENABLED", function() if btn then UI:AspectButtonSetup() end end)
WK:On("LEARNED_SPELL_IN_TAB", function() C_Timer.After(0.5, function() UI:SyncAspectButton() end) end)
WK:On("SPELLS_CHANGED", function() if not inCombat() then UI:SyncAspectButton() end end)
