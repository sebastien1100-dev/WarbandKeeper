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
    UI:RegisterHUD("aspect", b, { label = T("Bouton d'aspect"), protected = true, default = { -200, -260 },
        -- coupé dans ses réglages : absent du mode édition
        enabled = function() return wanted() and true or false end,
        -- aperçu : le bouton tel qu'en jeu (hors combat seulement : bouton protégé)
        sample = function() if not inCombat() then UI:SyncAspectButton() end end })
    return b
end

-- Attributs protégés : séquence des aspects choisis (clic gauche), aspect principal (clic droit).
-- La séquence commence à l'aspect qui suit l'aspect actif ; réécrite hors combat à chaque changement
-- d'aspect (ce qui remet /castsequence au début). En combat, on suit le pas de la séquence nous-mêmes
-- (UNIT_SPELLCAST_SUCCEEDED) : la petite icône montre ce que le prochain clic lancera.
function UI:AspectButtonSetup()
    if not btn or inCombat() then return end
    -- bouton coupé : sorts vidés, sinon les raccourcis (qui cliquent le bouton caché) lançaient encore un aspect
    if not wanted() then
        btn:SetAttribute("type1", nil); btn:SetAttribute("macrotext1", nil)
        btn:SetAttribute("type2", nil); btn:SetAttribute("spell2", nil)
        btn.sequence, btn.seqKeys, btn.setupFor = nil, nil, nil
        return
    end
    local o = cfg()
    local cur = H().aspect
    local keys, names, mainName = {}, {}, nil
    for _, a in ipairs(UI:KnownAspects()) do
        if o.list[a.key] then table.insert(keys, a.key); names[a.key] = a.name end
        if a.key == o.main then mainName = a.name end
    end
    if #keys == 0 and mainName then keys = { o.main }; names[o.main] = mainName end
    -- rotation : d'abord l'aspect après l'actif
    local start = 1
    for i, k in ipairs(keys) do if k == cur then start = i % #keys + 1 end end
    local seq, seqNames = {}, {}
    for i = 0, #keys - 1 do
        local k = keys[(start - 1 + i) % #keys + 1]
        table.insert(seq, k)
        table.insert(seqNames, names[k])
    end
    btn:SetAttribute("type1", "macro")
    btn:SetAttribute("macrotext1", #seqNames > 1 and ("/castsequence " .. table.concat(seqNames, ", ")) or ("/cast " .. (seqNames[1] or "")))
    btn:SetAttribute("type2", "spell")
    btn:SetAttribute("spell2", mainName or seqNames[1])
    btn.sequence = seqNames
    btn.seqKeys = seq
    btn.step = 1
    btn.setupFor = cur or false
    self:AspectButtonPaint()
end

function UI:AspectButtonPaint()
    if not btn then return end
    local cur = H().aspect
    -- aspect changé hors combat : la séquence repart de l'aspect suivant
    if not inCombat() and btn.setupFor ~= nil and btn.setupFor ~= (cur or false) then
        self:AspectButtonSetup()
        return
    end
    local icons = {}
    for _, a in ipairs(UI:KnownAspects()) do icons[a.key] = a.icon end
    local r, g, b = UI:Accent()
    btn.ring:SetVertexColor(r, g, b, 1)
    btn.nextRing:SetVertexColor(unpack(C.bg))
    btn.icon:SetTexture(icons[cur or ""] or icons[cfg().main] or "Interface\\Icons\\INV_Misc_QuestionMark")
    btn.icon:SetDesaturated(cur == nil)
    -- aspect que lancera le prochain clic (pas actuel de la séquence)
    local seq = btn.seqKeys or {}
    local nextKey = seq[btn.step or 1]
    btn.next:SetShown(nextKey ~= nil and #seq > 1)
    btn.nextRing:SetShown(nextKey ~= nil and #seq > 1)
    if nextKey then btn.next:SetTexture(icons[nextKey]) end
end

-- /castsequence avance quand le sort attendu réussit : on avance avec lui
WK:OnUnit("UNIT_SPELLCAST_SUCCEEDED", "player", function(unit, _, spellID)
    if unit ~= "player" or not btn or not btn.seqKeys or #btn.seqKeys < 2 then return end
    local name = WK.SpellInfo(spellID)
    local step = btn.step or 1
    if name and name == btn.sequence[step] then
        btn.step = step % #btn.seqKeys + 1
        UI:AspectButtonPaint()
    end
end)

function UI:SyncAspectButton()
    if inCombat() then return end
    if wanted() then
        btn = btn or build()
        if RegisterStateDriver then RegisterStateDriver(btn, "visibility", "[dead] hide; show") end
        self:AspectButtonSetup()
    elseif btn then
        if UnregisterStateDriver then UnregisterStateDriver(btn, "visibility") end
        btn:Hide()
        self:AspectButtonSetup()
    end
end

-- Noms des raccourcis dans les options du jeu (Bindings.xml)
BINDING_HEADER_WARBANDKEEPER = "Warband Keeper"
WK.BindingName("BINDING_NAME_CLICK WarbandKeeperAspectButton:LeftButton", "Aspect suivant")
WK.BindingName("BINDING_NAME_CLICK WarbandKeeperAspectButton:RightButton", "Aspect principal")
WK.BindingName("BINDING_NAME_CLICK WarbandKeeperPetCardClick:LeftButton", "Nourrir le familier")
WK.BindingName("BINDING_NAME_CLICK WarbandKeeperPetCardClick:RightButton", "Soigner (ou ressusciter) le familier")

WK:On("PLAYER_LOGIN", function() C_Timer.After(1, function() UI:SyncAspectButton() end) end)
WK:On("PLAYER_REGEN_ENABLED", function() if btn then UI:AspectButtonSetup() end end)
WK:On("LEARNED_SPELL_IN_TAB", function() C_Timer.After(0.5, function() UI:SyncAspectButton() end) end)
WK:On("SPELLS_CHANGED", function() if not inCombat() then UI:SyncAspectButton() end end)
