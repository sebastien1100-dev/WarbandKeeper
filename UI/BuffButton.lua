local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Bouton « Buffer le suivant » (QoL > Classes, onglet « Buffer autour ») : en monde ouvert, le joueur ami le plus
-- proche qui n'a pas ton buff (toi et ton groupe d'abord, puis les plaques de nom des joueurs amis), et le buff qui
-- lui va : Marque du fauve, Robustesse, Intelligence des arcanes ; paladin : Puissance pour guerrier, voleur et
-- chasseur, Sagesse pour les autres, Rois d'abord si tu la connais (réglage). Un bouton protégé du jeu
-- (WarbandKeeperBuffButton, touche dans les raccourcis) : sort et cible posés hors combat seulement, bouton caché
-- en combat. Liseré d'accent sur la plaque de nom du joueur visé. Jamais sur un joueur en combat, ni sur un joueur
-- JcJ quand tu ne l'es pas (ça te mettrait en JcJ). Réglages par classe dans QoL:Class(classe) : buffAround,
-- kingsFirst, buffRefresh (minutes), buffInstance, buffMounted, buffPlates (plaques des amis allumées hors combat).
local BUFFS = {
    DRUID = { cast = 1126, has = { 1126, 21849 } },   -- Marque du fauve (ou Don du fauve)
    PRIEST = { cast = 1243, has = { 1243, 21562 } },  -- Robustesse (ou Prière de robustesse)
    MAGE = { cast = 1459, has = { 1459, 23028 } },    -- Intelligence des arcanes (ou Illumination)
}
local MIGHT, WISDOM, KINGS = { 19740, 25782 }, { 19742, 25894 }, { 20217, 25898 } -- simple, supérieure
local MELEE = { WARRIOR = true, ROGUE = true, HUNTER = true }
WK.BUFF_CLASSES = { DRUID = true, PRIEST = true, MAGE = true, PALADIN = true }

local function myClass() return select(2, UnitClass("player")) end
local function inCombat() return InCombatLockdown and InCombatLockdown() or false end
local function cfg() local c = myClass(); return c and WK.modules.QoL:Class(c) end
local function known(id)
    local k = (IsPlayerSpell and IsPlayerSpell(id)) or (IsSpellKnown and IsSpellKnown(id))
    return k ~= false and WK.SpellInfo(id) ~= nil
end
local function spellIcon(id)
    return (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)) or (GetSpellTexture and GetSpellTexture(id))
end

-- Buff prévu pour une unité : n° du sort à lancer, n° qui le valent
local function buffFor(unit)
    local class = myClass()
    if class == "PALADIN" then
        -- répartition des bénédictions (Modules/Blessings.lua) : ce qui m'est attribué pour ce joueur
        local BL = WK.modules.Blessings
        local bi = BL and BL:On() and BL:ForUnit(unit)
        if bi then return BL.BLESS[bi][1], BL.BLESS[bi] end
        local c = cfg() or {}
        if c.kingsFirst ~= false and known(KINGS[1]) then return KINGS[1], KINGS end
        local _, tc = UnitClass(unit)
        local set = MELEE[tc or ""] and MIGHT or WISDOM
        if known(set[1]) then return set[1], set end
        if known(MIGHT[1]) then return MIGHT[1], MIGHT end
        return nil
    end
    local b = BUFFS[class or ""]
    if b and known(b.cast) then return b.cast, b.has end
end

-- Temps restant (secondes, 0 = sans fin) du premier de ces sorts sur l'unité, nil s'il n'y est pas ;
-- 2e valeur : vrai si c'est toi qui l'as lancé (sinon un autre joueur, ou inconnu)
-- noms des sorts gardés par liste (avant : refaits pour chaque unité, chaque seconde)
local namesOf = setmetatable({}, { __mode = "k" })
local function namesFor(ids)
    local names = namesOf[ids]
    if names then return names end
    names = {}
    local all = true
    for _, id in ipairs(ids) do
        local n = WK.SpellInfo(id)
        if n then names[n] = true else all = false end
    end
    if all then namesOf[ids] = names end -- un nom pas encore chargé : redemandé la fois suivante
    return names
end
-- Lectures gardées par joueur (GUID) jusqu'à un changement de ses effets (UNIT_AURA) ou 10 s : avant, jusqu'à
-- 40 effets de chaque membre du raid et de chaque plaque étaient relus chaque seconde (druide, prêtre, mage)
local auraCache, auraCount = {}, 0
local function scanAura(unit, ids)
    local names = namesFor(ids)
    for i = 1, 40 do
        local name, exp, src
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local d = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
            if not d then break end
            name, exp, src = d.name, d.expirationTime, d.sourceUnit
        elseif UnitBuff then
            local n, _, _, _, _, e, s = UnitBuff(unit, i)
            if not n then break end
            name, exp, src = n, e, s
        else break end
        if name and names[name] then
            local mine = src ~= nil and UnitIsUnit and UnitIsUnit(src, "player") or false
            return (not exp or exp == 0) and 0 or exp, mine -- expiration absolue (0 = sans fin)
        end
    end
    return false
end
local function auraLeft(unit, ids)
    local guid = _G.UnitGUID and _G.UnitGUID(unit)
    local now = GetTime()
    local c = guid and auraCache[guid]
    if c and (c.dirty or now - c.at > 10) then c = nil end
    if guid and not c then
        if auraCount > 300 then auraCache, auraCount = {}, 0 end
        c = { at = now, res = {} }
        auraCache[guid] = c
        auraCount = auraCount + 1
    end
    local r = c and c.res[ids]
    if r == nil then
        local exp, mine = scanAura(unit, ids)
        r = exp and { exp, mine } or false
        if c then c.res[ids] = r end
    end
    if not r then return nil end
    if r[1] == 0 then return 0, r[2] end
    return math.max(0, r[1] - now), r[2]
end
WK:On("UNIT_AURA", function(unit)
    local guid = type(unit) == "string" and _G.UnitGUID and _G.UnitGUID(unit)
    local c = guid and auraCache[guid]
    if c then c.dirty = true end
end)
UI.BuffAuraCache = auraCache

-- Joueurs que le jeu a refusé de buffer juste après un clic (« un sort plus puissant est déjà actif »,
-- hors de vue…) : passés pendant 2 min, le bouton va au suivant
local refused = {}
UI.buffRefused = refused

local function inRange(spell, unit)
    if UnitIsUnit and UnitIsUnit(unit, "player") then return true end
    local r
    if C_Spell and C_Spell.IsSpellInRange then r = C_Spell.IsSpellInRange(spell, unit)
    elseif IsSpellInRange then r = IsSpellInRange(spell, unit) end
    if r == true or r == 1 then return true end
    if r == false or r == 0 then return false end
    return CheckInteractDistance and CheckInteractDistance(unit, 4) and true or false
end

-- Unités des plaques de nom affichées : « nameplate1 » à « nameplate40 » (marche sur tous les clients ;
-- le champ namePlateUnitToken des cadres de plaque n'existe pas partout)
local function plateUnits(into)
    for i = 1, 40 do
        local u = "nameplate" .. i
        if UnitExists(u) then table.insert(into, u) end
    end
    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
            local tok = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
            if tok then table.insert(into, tok) end
        end
    end
    return into
end

-- Paladin en groupe, raid ou donjon : le bouton prend le relais du panneau des bénédictions
-- (Modules/Blessings.lua, Status) : chaque membre reçoit la bénédiction que la répartition lui donne (et le
-- Salut), les joueurs sans ta bénédiction d'abord, puis ceux dont elle finit le plus tôt
local function groupBlessings(seenGuid)
    local BL = WK.modules.Blessings
    if not (myClass() == "PALADIN" and BL and BL:On() and IsInGroup and IsInGroup()) then return nil end
    local c = cfg() or {}
    local refresh = (c.buffRefresh or 3) * 60
    local mePvp = UnitIsPVP and UnitIsPVP("player")
    local out = {}
    for _, r in ipairs(BL:Status()) do
        local spell = BL:Name(r.b)
        local id = BL.BLESS[r.b] and BL.BLESS[r.b][1]
        for _, m in ipairs(r.members) do
            local u = m.unit
            local guid = UnitExists(u) and UnitGUID(u)
            if guid then seenGuid[guid] = true end
            if guid and spell and not m.dead and (UnitIsUnit(u, "player") or not UnitAffectingCombat(u))
                and (mePvp or not (UnitIsPVP and UnitIsPVP(u)))
                and not (refused[guid] and GetTime() - refused[guid] < 120)
                and (not m.left or m.left < refresh) and inRange(spell, u) then
                table.insert(out, { unit = u, id = id, spell = spell, who = UnitName(u), class = select(2, UnitClass(u)),
                    left = m.left or -1, b = r.b })
            end
        end
    end
    table.sort(out, function(a, b) return a.left < b.left end)
    return out
end
UI.BuffGroupBlessings = groupBlessings

-- Joueurs à buffer, dans l'ordre : toi, ton groupe, puis les plaques de nom des joueurs amis
local function candidates()
    local seenGroup = {}
    local grouped = groupBlessings(seenGroup)
    -- en instance : seulement le groupe ; dehors, les autres joueurs autour viennent après
    if grouped and IsInInstance and select(1, IsInInstance()) then return grouped end
    local c = cfg() or {}
    -- toi, puis ta cible, le joueur survolé et ta focalisation (marche même sans plaques de nom)
    -- (pas « mouseover » : le joueur survolé disparaît dès que la souris va sur le bouton)
    local units, seen, out = { "player", "target", "focus" }, {}, grouped or {}
    if grouped then
        -- membres du groupe déjà traités par la répartition
        for g in pairs(seenGroup) do seen[g] = true end
    elseif IsInRaid and IsInRaid() then
        for i = 1, 40 do table.insert(units, "raid" .. i) end
    elseif IsInGroup and IsInGroup() then
        for i = 1, 4 do table.insert(units, "party" .. i) end
    end
    plateUnits(units)
    local refresh = (c.buffRefresh or 3) * 60
    local mePvp = UnitIsPVP and UnitIsPVP("player")
    for _, u in ipairs(units) do
        local guid = UnitExists(u) and UnitGUID(u)
        if guid and not seen[guid] and UnitIsPlayer(u) and UnitCanAssist("player", u) and not UnitIsDeadOrGhost(u)
            and UnitIsConnected(u) and (u == "player" or not UnitAffectingCombat(u))
            and (mePvp or not (UnitIsPVP and UnitIsPVP(u))) then
            seen[guid] = true
            local id, has = buffFor(u)
            local name = id and WK.SpellInfo(id)
            if name and not (refused[guid] and GetTime() - refused[guid] < 120) then
                local left, mine = auraLeft(u, has)
                -- buff d'un autre lanceur encore actif : on ne le remplace pas (le jeu refuserait un sort plus
                -- faible) ; seul ton propre buff est rafraîchi avant la fin
                if (not left or (mine and left > 0 and left < refresh)) and inRange(name, u) then
                    table.insert(out, { unit = u, id = id, spell = name, who = UnitName(u), class = select(2, UnitClass(u)) })
                end
            end
        end
    end
    return out
end

-- Macro du bouton. WoW Forever ignore les unités de plaque de nom (@nameplate1…) dans /cast, sans message :
-- un joueur pris sur sa plaque est ciblé par son nom (/targetexact), le sort part sur la cible, puis la cible
-- d'avant revient (/targetlasttarget, ou /cleartarget s'il n'y en avait pas). Toi, ta cible, ta focalisation
-- et ton groupe : directement (@unité).
function UI.BuffMacro(e)
    local u = e.unit
    if type(u) ~= "string" or not u:find("^nameplate") then return "/cast [@" .. tostring(u) .. ",help,nodead] " .. e.spell end
    if UnitIsUnit(u, "target") then return "/cast [@target,help,nodead] " .. e.spell end
    if UnitIsUnit(u, "focus") then return "/cast [@focus,help,nodead] " .. e.spell end
    local name = (GetUnitName and GetUnitName(u, true)) or UnitName(u)
    if not name then return "/cast [@" .. u .. ",help,nodead] " .. e.spell end
    local back = UnitExists("target") and "/targetlasttarget" or "/cleartarget"
    return "/targetexact " .. name .. "\n/cast [@target,help,nodead] " .. e.spell .. "\n" .. back
end

---------------------------------------------------------------------------
-- Bouton
---------------------------------------------------------------------------
local btn, mark, list
local SIZE = 48
local function build()
    btn = CreateFrame("Button", "WarbandKeeperBuffButton", UIParent, "SecureActionButtonTemplate")
    btn:SetSize(SIZE, SIZE)
    btn:SetFrameStrata("MEDIUM")
    btn:SetClampedToScreen(true)
    if btn.RegisterForClicks then btn:RegisterForClicks("AnyUp", "AnyDown") end
    -- macro « /cast [@unité] sort » : le jeu résout le nom et l'unité au moment du clic
    btn:SetAttribute("type", "macro")
    btn.edge = UI:Rounded(btn, 11, 0, "BACKGROUND", 1)
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("TOPLEFT", 3, -3); btn.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.hl = btn:CreateTexture(nil, "HIGHLIGHT"); btn.hl:SetAllPoints(btn.icon); btn.hl:SetColorTexture(1, 1, 1, 0.15)
    btn.pill = CreateFrame("Frame", nil, btn)
    btn.pill:SetSize(20, 16); btn.pill:SetPoint("CENTER", btn, "TOPRIGHT", -3, -3)
    btn.pill:SetFrameLevel(btn:GetFrameLevel() + 3)
    btn.pill.bg = UI:Rounded(btn.pill, 8, 0, "BACKGROUND", 1)
    btn.pill.t = UI:Text(btn.pill, 10, C.onAccent); btn.pill.t:SetPoint("CENTER")
    btn:SetScript("OnEnter", function(s)
        local l = list or {}
        local e = l[1]
        UI:TooltipOwner(s, "ANCHOR_TOP")
        if not e then GameTooltip:SetText(T("Buffer autour"), 1, 1, 1); GameTooltip:Show() return end
        GameTooltip:SetText(e.spell, 1, 1, 1)
        local cr, cg, cb = UI:ClassColor(e.class)
        GameTooltip:AddLine(string.format(T("sur %s"), e.who or "?"), cr, cg, cb)
        if #l > 1 then
            local nxt = {}
            for i = 2, math.min(4, #l) do table.insert(nxt, (l[i].who or "?") .. " (" .. l[i].spell .. ")") end
            GameTooltip:AddLine(T("Ensuite") .. " : " .. table.concat(nxt, ", "), 0.7, 0.7, 0.7, true)
        end
        GameTooltip:AddLine(T("Clic ou touche : lancer"), 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(s)
        GameTooltip:Hide()
        -- clavier : l'action suit de nouveau le réglage du jeu (appui ou relâché)
        if not inCombat() then s:SetAttribute("useOnKeyDown", nil) end
    end)
    -- souris : le bouton protégé agit à l'appui ou au relâché selon le réglage du jeu ; sous la souris, au
    -- relâché seulement (une seule action, quel que soit le réglage)
    btn:HookScript("OnEnter", function(s) if not inCombat() then s:SetAttribute("useOnKeyDown", false) end end)
    btn:HookScript("PostClick", function(s, button, down)
        local e = list and list[1]
        UI.buffLastClick = { at = GetTime(), button = button, down = down, macro = s:GetAttribute("macrotext"),
            guid = e and e.unit and UnitGUID(e.unit),
            unit = e and e.unit, who = e and e.unit and UnitName(e.unit), exists = e and e.unit and UnitExists(e.unit),
            type = s:GetAttribute("type"), keyDown = WK.GetCVar("ActionButtonUseKeyDown"), useOnKeyDown = s:GetAttribute("useOnKeyDown"),
            events = {} }
    end)
    btn:HookScript("PostClick", function() C_Timer.After(0.4, function() UI:RefreshBuffButton() end) end)
    -- liseré sur la plaque de nom du joueur visé
    -- repère au-dessus de la plaque de nom du joueur visé : l'icône du sort qui va partir dans un rond à la
    -- couleur d'accent, une pointe vers le nom, un halo qui bat quand le sort est prêt (taille : buffMarkSize)
    mark = CreateFrame("Frame", nil, UIParent)
    mark:SetFrameStrata("LOW")
    mark.glow = UI:Icon(mark, "circle", 40, nil, "BACKGROUND"); mark.glow:SetPoint("CENTER")
    mark.tail = mark:CreateTexture(nil, "BORDER")
    mark.ring = UI:Icon(mark, "circle", 36, nil, "BORDER"); mark.ring:SetPoint("CENTER")
    mark.ring:SetDrawLayer("BORDER", 1)
    mark.icon = UI:RoundIcon(mark, 30); mark.icon:SetPoint("CENTER")
    mark.icon:SetDrawLayer("ARTWORK", 1)
    function mark:Layout(size)
        self:SetSize(size + 12, size + 12)
        self.glow:SetSize(size + 14, size + 14)
        self.ring:SetSize(size + 6, size + 6)
        self.icon:SetSize(size, size)
        local tw = math.max(6, math.floor(size / 4))
        self.tail:SetSize(tw, tw)
        self.tail:ClearAllPoints(); self.tail:SetPoint("CENTER", self.ring, "BOTTOM", 0, 1)
        if self.tail.SetRotation then self.tail:SetRotation(math.pi / 4) end
    end
    function mark:Paint(icon)
        local r, g, b = UI:Accent()
        self.ring:SetVertexColor(r, g, b, 1)
        self.glow:SetVertexColor(r, g, b, 0.3)
        self.tail:SetColorTexture(r, g, b, 1)
        self.icon:SetTexture(icon)
    end
    mark:SetScript("OnUpdate", function(m)
        -- le sort est prêt (hors temps de recharge global) : le halo bat doucement
        local ready = true
        if m.spell and WK.SpellCooldown then
            local st, dur = WK.SpellCooldown(m.spell)
            ready = not (st and dur and dur > 0 and st + dur > GetTime())
        end
        local a = ready and (0.25 + 0.2 * math.sin(GetTime() * 4)) or 0.12
        local r, g, b = UI:Accent()
        m.glow:SetVertexColor(r, g, b, a)
    end)
    mark:Layout(30)
    mark:Hide()
    local function paint(icon, n)
        local r, g, b = UI:Accent()
        btn.edge:SetColor(r, g, b, 1)
        btn.pill.bg:SetColor(r, g, b, 1)
        btn.icon:SetTexture(icon or "Interface\\Icons\\Spell_Nature_Regeneration")
        btn.pill.t:SetText(n or "")
        btn.pill:SetShown((n or 0) > 0)
        btn.pill:SetWidth(math.max(16, btn.pill.t:GetStringWidth() + 10))
    end
    btn.paint = paint
    UI:RegisterHUD("buffButton", btn, {
        label = T("Buffer autour"), default = { 220, -140 }, protected = true,
        enabled = function() local c = cfg(); return WK.BUFF_CLASSES[myClass() or ""] and c and c.buffAround ~= false and WK:FeatureOn("classes") end,
        sample = function(on)
            btn.sample = on
            -- aperçu : macro vidée, un clic ou le raccourci ne lance rien (remise par RefreshBuffButton à la fin)
            if on and not inCombat() then btn:SetAttribute("macrotext", nil) end
            if on then
                local id = buffFor("player") or (BUFFS[myClass() or ""] or {}).cast or 1126
                paint(spellIcon(id), 3)
                if not inCombat() then btn:Show() end
            else UI:RefreshBuffButton() end
        end,
        -- « Tester » : un buff part toutes les 2 s, le nombre de joueurs à buffer descend
        test = function()
            btn.sample = true
            if not inCombat() then btn:SetAttribute("macrotext", nil) end
            local id = buffFor("player") or (BUFFS[myClass() or ""] or {}).cast or 1126
            local n = 4
            paint(spellIcon(id), n)
            if not inCombat() then btn:Show() end
            btn.testTicker = C_Timer.NewTicker and C_Timer.NewTicker(2, function()
                n = n > 1 and n - 1 or 4
                paint(spellIcon(id), n)
            end)
        end,
        testStop = function()
            if btn.testTicker then btn.testTicker:Cancel(); btn.testTicker = nil end
            btn.sample = nil
            UI:RefreshBuffButton()
        end,
    })
    btn:Hide()
end

local function shouldShow()
    local c = cfg()
    if not (c and WK.BUFF_CLASSES[myClass() or ""] and c.buffAround ~= false and WK:FeatureOn("classes")) then return false end
    if UnitIsDeadOrGhost("player") or (UnitOnTaxi and UnitOnTaxi("player")) then return false end
    local inInst = IsInInstance and select(1, IsInInstance())
    -- en groupe (donjon, raid), le bouton sert à buffer tout le monde : affiché même si « En instance » est coupé
    if inInst and not c.buffInstance and not (IsInGroup and IsInGroup()) then return false end
    if IsMounted and IsMounted() and not c.buffMounted then return false end
    return true
end

function UI:RefreshBuffButton()
    if not btn then
        if not WK.BUFF_CLASSES[myClass() or ""] then return end
        if inCombat() then return end -- bouton protégé : construit hors combat (rappelé à PLAYER_REGEN_ENABLED)
        build()
    end
    if btn.sample or inCombat() then return end
    list = shouldShow() and candidates() or {}
    local e = list[1]
    if e then
        local macro = UI.BuffMacro(e)
        if btn:GetAttribute("macrotext") ~= macro then btn:SetAttribute("macrotext", macro) end -- seulement si elle change
        btn.paint(spellIcon(e.id), #list)
        btn:Show()
        -- plaque de nom : le jeu refuse ici les unités de groupe (party1, raid3…) ; on prend l'unité de plaque
        -- (nameplateN) ou la cible / le focus, et l'appel reste protégé
        local plate
        if C_NamePlate and C_NamePlate.GetNamePlateForUnit and type(e.unit) == "string"
            and (e.unit:find("^nameplate") or e.unit == "target" or e.unit == "focus") then
            local ok, p = pcall(C_NamePlate.GetNamePlateForUnit, e.unit)
            plate = ok and p or nil
        elseif C_NamePlate and C_NamePlate.GetNamePlates then
            -- membre du groupe : sa plaque, retrouvée parmi celles affichées
            local ok, plates = pcall(C_NamePlate.GetNamePlates)
            for _, p in ipairs(ok and plates or {}) do
                local tok = p.namePlateUnitToken or (p.UnitFrame and p.UnitFrame.unit)
                if tok and UnitIsUnit(tok, e.unit) then plate = p break end
            end
        end
        if plate and not UnitIsUnit(e.unit, "player") then
            mark:Layout((cfg() or {}).buffMarkSize or 30)
            mark:Paint(spellIcon(e.id))
            mark.spell = e.id
            mark:ClearAllPoints()
            mark:SetPoint("BOTTOM", plate, "TOP", 0, 2)
            mark:Show()
        else mark:Hide() end
    else
        -- rien à buffer : macro vidée, sinon le raccourci clavier (qui clique aussi un bouton caché) rejouerait
        -- la dernière (cible changée ou effacée)
        btn:SetAttribute("macrotext", nil)
        btn:Hide(); mark:Hide()
    end
end

-- Nom du réglage des plaques de nom des joueurs amis : il change selon les clients ; le premier qui existe
local PLATE_CVARS = { "nameplateShowFriends", "nameplateShowFriendlyPlayers" }
local function plateCVar()
    for _, n in ipairs(PLATE_CVARS) do
        if WK.GetCVar(n) ~= nil then return n end
    end
end
UI.BuffPlateCVar = plateCVar

-- Plaques de nom des joueurs amis : allumées hors combat quand le bouton sert (valeur d'avant rendue sinon)
function UI:SyncBuffPlates()
    local c = cfg()
    if inCombat() then return end
    local want = c and WK.BUFF_CLASSES[myClass() or ""] and c.buffAround ~= false and c.buffPlates ~= false and WK:FeatureOn("classes")
    local g = WK.DB.global
    if want then
        local cv = plateCVar()
        local cur = cv and WK.GetCVar(cv)
        if cv and cur ~= "1" then
            g.buffPlatesOld = g.buffPlatesOld or cur or "0"
            g.buffPlatesCVar = cv
            UI.buffPlatesSet = WK.SetCVar(cv, "1")
        end
    elseif g.buffPlatesOld then
        WK.SetCVar(g.buffPlatesCVar or plateCVar() or "nameplateShowFriends", g.buffPlatesOld)
        g.buffPlatesOld = nil
    end
end

-- juste avant le combat (encore permis) : bouton et liseré cachés
WK:On("PLAYER_REGEN_DISABLED", function()
    if not btn then return end
    -- dernier moment permis : macro vidée (aussi pendant l'aperçu), sinon le raccourci clavier changerait ou
    -- effacerait la cible en plein combat (/targetexact puis /cleartarget ou /targetlasttarget)
    btn:SetAttribute("macrotext", nil)
    if not btn.sample then btn:Hide(); mark:Hide() end
end)
-- la macro dépend de la cible (cible d'avant rendue ou effacée) : remise à jour quand elle change
WK:On("PLAYER_TARGET_CHANGED", function() if btn and btn:IsShown() and not inCombat() then UI:RefreshBuffButton() end end)
WK:On("PLAYER_REGEN_ENABLED", function() C_Timer.After(0.5, function() UI:SyncBuffPlates(); UI:RefreshBuffButton() end) end)
WK:On("PLAYER_LOGIN", function()
    -- toutes les classes : un perso qui ne buffe pas rend la valeur d'avant des plaques amies
    if not WK.BUFF_CLASSES[myClass() or ""] then C_Timer.After(3, function() UI:SyncBuffPlates() end) return end
    C_Timer.After(3, function()
        UI:SyncBuffPlates()
        UI:RefreshBuffButton()
        -- (rien à faire tant que le bouton est coupé dans ses réglages ou le module éteint)
        if C_Timer.NewTicker then C_Timer.NewTicker(1, function()
            local c = cfg()
            if inCombat() or not (c and c.buffAround ~= false and WK:FeatureOn("classes")) then
                if btn and btn:IsShown() and not inCombat() then UI:RefreshBuffButton() end
                return
            end
            UI:RefreshBuffButton()
        end) end
    end)
end)

-- Ce que le jeu fait juste après un clic (2 s) : sort envoyé, raté, message d'erreur, action bloquée
local function noteClickEvent(txt)
    local lc = UI.buffLastClick
    if lc and GetTime() - lc.at < 2 and #lc.events < 6 then table.insert(lc.events, txt) end
end
local function spellName(id) return tostring(id and WK.SpellInfo(id) or id or "?") end
WK:OnUnit("UNIT_SPELLCAST_SENT", "player", function(_, target, _, spellID) noteClickEvent("sort envoyé " .. spellName(spellID) .. " » " .. tostring(target)) end)
WK:OnUnit("UNIT_SPELLCAST_SUCCEEDED", "player", function(_, _, spellID) noteClickEvent("réussi " .. spellName(spellID)) end)
-- Erreurs qui viennent de nous, pas du joueur visé (sort pas prêt, temps de recharge global, mana, en
-- mouvement, autre action en cours…) : on réessaie le même joueur au clic suivant au lieu de l'écarter
local SELF_ERRORS = {
    "SPELL_FAILED_NOT_READY", "ERR_SPELL_COOLDOWN", "ERR_ABILITY_COOLDOWN", "ERR_ITEM_COOLDOWN",
    "SPELL_FAILED_SPELL_IN_PROGRESS", "ERR_SPELL_IN_PROGRESS", "SPELL_FAILED_NO_POWER", "ERR_OUT_OF_MANA",
    "SPELL_FAILED_MOVING", "SPELL_FAILED_INTERRUPTED", "SPELL_FAILED_STUNNED", "SPELL_FAILED_SILENCED",
    "SPELL_FAILED_PACIFIED", "SPELL_FAILED_NOT_MOUNTED", "SPELL_FAILED_NOT_SHAPESHIFT", "SPELL_FAILED_REAGENTS",
    "ERR_NOT_WHILE_MOVING", "SPELL_FAILED_AFFECTING_COMBAT", "SPELL_FAILED_CASTER_DEAD", "ERR_USE_LOCKED",
}
local function isSelfError(msg)
    if msg == nil then return false end
    for _, k in ipairs(SELF_ERRORS) do
        if _G[k] == msg then return true end
    end
    return false
end
UI.BuffSelfError = isSelfError

-- refus du jeu juste après notre clic : ce joueur est passé 2 min, le bouton va au suivant. La décision
-- attend 0,15 s : le message d'erreur et l'échec du sort arrivent ensemble, dans un ordre quelconque, et une
-- erreur qui vient de nous annule l'exclusion
local function refuse(selfErr)
    local lc = UI.buffLastClick
    if not (lc and lc.guid and GetTime() - lc.at < 1.5 and not lc.refused) then return end
    if selfErr then lc.selfErr = true end
    if lc.pending then return end
    lc.pending = true
    C_Timer.After(0.15, function()
        lc.pending = nil
        if lc.selfErr or lc.refused then return end
        lc.refused = true
        refused[lc.guid] = GetTime()
        if not inCombat() then UI:RefreshBuffButton() end
    end)
end
UI.BuffRefuse = refuse
WK:OnUnit("UNIT_SPELLCAST_FAILED", "player", function(_, _, spellID) noteClickEvent("raté " .. spellName(spellID)); refuse() end)
WK:On("UI_ERROR_MESSAGE", function(a, b)
    -- (type, message) sur les clients récents, message seul sur les anciens
    local msg = type(b) == "string" and b or (type(a) == "string" and a) or nil
    noteClickEvent("erreur : " .. tostring(msg)); refuse(isSelfError(msg))
end)
WK:On("ADDON_ACTION_BLOCKED", function(addon, fn) noteClickEvent("action bloquée : " .. tostring(addon) .. " " .. tostring(fn)) end)
WK:On("ADDON_ACTION_FORBIDDEN", function(addon, fn) noteClickEvent("action interdite : " .. tostring(addon) .. " " .. tostring(fn)) end)

-- /wk buff : pourquoi le bouton est (ou n'est pas) affiché, joueur par joueur
function UI:BuffDiag()
    local out = {}
    local c = cfg()
    local cls = myClass() or "?"
    local function yn(v) return v and "oui" or "non" end
    table.insert(out, string.format("classe %s (buffe : %s) · réglage « Buffer autour » : %s · module Classes : %s · plaques amies : %s (réglage %s)",
        cls, yn(WK.BUFF_CLASSES[cls]), yn(c and c.buffAround ~= false), yn(WK:FeatureOn("classes")),
        (plateCVar() and (plateCVar() .. " = " .. tostring(WK.GetCVar(plateCVar()))) or "réglage introuvable (Maj+V pour les montrer)"), yn(c and c.buffPlates ~= false))
        .. (UI.buffPlatesSet == false and " · le jeu a refusé de les allumer" or ""))
    local inInst = IsInInstance and select(1, IsInInstance())
    table.insert(out, string.format("en combat : %s · monture : %s (permis : %s) · instance : %s (permis : %s) · mort : %s · JcJ : %s",
        yn(inCombat()), yn(IsMounted and IsMounted()), yn(c and c.buffMounted), yn(inInst), yn(c and c.buffInstance),
        yn(UnitIsDeadOrGhost("player")), yn(UnitIsPVP and UnitIsPVP("player"))))
    table.insert(out, "affichage permis : " .. yn(shouldShow()) .. " · bouton : " .. yn(btn and btn:IsShown())
        .. (btn and (" · macro : " .. tostring((btn:GetAttribute("macrotext")))) or ""))
    local lc = UI.buffLastClick
    table.insert(out, lc and string.format("dernier clic : il y a %ds (%s, %s) · %s · cible %s (%s)",
        math.floor(GetTime() - lc.at), tostring(lc.button), lc.down and "appui" or "relâché", tostring(lc.macro),
        tostring(lc.who or lc.unit), lc.exists and "visible" or "introuvable") or "dernier clic : aucun depuis le chargement")
    if lc then
        table.insert(out, string.format("  type %s · ActionButtonUseKeyDown = %s · useOnKeyDown = %s · le jeu a répondu : %s",
            tostring(lc.type), tostring(lc.keyDown), tostring(lc.useOnKeyDown), #lc.events > 0 and table.concat(lc.events, " ; ") or "rien"))
    end
    -- joueurs vus, avec la raison quand ils sont écartés
    local units = { "player", "target", "focus" }
    if IsInGroup and IsInGroup() and not (IsInRaid and IsInRaid()) then for i = 1, 4 do table.insert(units, "party" .. i) end end
    local nplates = C_NamePlate and C_NamePlate.GetNamePlates and #(C_NamePlate.GetNamePlates() or {}) or 0
    local before = #units
    plateUnits(units)
    local players = 0
    for k = before + 1, #units do if UnitIsPlayer(units[k]) then players = players + 1 end end
    table.insert(out, string.format("plaques de nom à l'écran : %d (unités lues : %d, dont joueurs : %d)", nplates, #units - before, players))
    local refresh = ((c and c.buffRefresh) or 3) * 60
    local mePvp = UnitIsPVP and UnitIsPVP("player")
    local shown, seen = 0, {}
    for _, u in ipairs(units) do
        if UnitExists(u) and shown < 10 then
            local guid = UnitGUID(u)
            if guid and not seen[guid] then
                seen[guid] = true
                local why
                if not UnitIsPlayer(u) then why = nil -- PNJ : on ne les liste pas
                elseif not UnitCanAssist("player", u) then why = "pas aidable"
                elseif UnitIsDeadOrGhost(u) then why = "mort"
                elseif u ~= "player" and UnitAffectingCombat(u) then why = "en combat"
                elseif not mePvp and UnitIsPVP and UnitIsPVP(u) then why = "JcJ (pas toi)"
                else
                    local id, has = buffFor(u)
                    local name = id and WK.SpellInfo(id)
                    if not name then why = "aucun buff prévu"
                    else
                        local left = auraLeft(u, has)
                        if left and (left == 0 or left >= refresh) then why = name .. " déjà là"
                        elseif not inRange(name, u) then why = name .. " hors de portée"
                        else why = "OK : " .. name end
                    end
                end
                if why then
                    shown = shown + 1
                    table.insert(out, "  " .. (UnitName(u) or u) .. " : " .. why)
                end
            end
        end
    end
    return out
end


BINDING_HEADER_WARBANDKEEPER = "Warband Keeper"
WK.BindingName("BINDING_NAME_CLICK WarbandKeeperBuffButton:LeftButton", "Buffer le suivant")
