local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Bénédictions du paladin (Modules/Blessings.lua) :
--  · barre à l'écran (HUD « blessBar », mode édition) : en tête ton aura (clic = la lancer) et ton sceau,
--    puis une ligne par classe présente (et une par exception) : ta bénédiction, le temps restant le plus
--    court, le nombre de joueurs sans. Clic gauche = bénir le prochain joueur de la ligne qui en a besoin
--    (bouton protégé : sort et cible posés hors combat), clic droit = tableau de répartition, survol = détail.
--  · tableau de répartition (QoL > Classes > Paladin, onglet « Bénédictions ») : une ligne par paladin du
--    groupe (pastille Warband Keeper ou PallyPower), une colonne par classe + l'aura ; clic = suivante,
--    clic droit = aucune ; exceptions par joueur.
local B = function() return WK.modules.Blessings end
local function inCombat() return InCombatLockdown and InCombatLockdown() or false end
local MAXROWS, ROWH, W = 13, 26, 230

local function className(token)
    for _, c in ipairs(WK.modules.QoL.CLASSES or {}) do if c[1] == token then return T(c[2]) end end
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token]) or token or "?"
end
local function classColor(token)
    local c = token and RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
    return c and { c.r, c.g, c.b } or C.text
end
local function short(sec)
    if not sec then return "" end
    if sec == math.huge then return "" end
    if sec >= 60 then return string.format(T("%d min"), math.floor(sec / 60)) end
    return string.format("%d s", math.floor(sec))
end
local function firstName(n) return n and (n:match("^(%S+)") or n) or "?" end

-- Sceau actif (lu hors combat)
local SEALS = { 21084, 20375, 20164, 20165, 20166, 21082, 1311656 }
local function sealInfo()
    local names = {}
    for _, id in ipairs(SEALS) do local n = WK.SpellInfo(id); if n then names[n] = true end end
    for i = 1, 40 do
        local ok, d = pcall(C_UnitAuras and C_UnitAuras.GetAuraDataByIndex or function() end, "player", i, "HELPFUL")
        if not ok or not d then break end
        local name = WK.modules.QoL.Readable(d.name)
        if name and names[name] then return name, WK.modules.QoL.Readable(d.expirationTime) end
    end
end
-- libellé d'une ligne de la barre : joueur à part, Salut, classe (tank)
local function rowLabel(d)
    if d.except then return firstName(d.except) .. " *" end
    if d.salut then return T("Salut") end
    return className(d.class) .. (d.tank and (" · " .. T("tank")) or "")
end

-- clé d'une ligne (classe et bénédiction, exception ou Salut) : retrouve sa ligne en combat
local function rowKey(d)
    if d.except then return "x:" .. d.except end
    if d.salut then return "salut" end
    return tostring(d.class) .. ":" .. tostring(d.b)
end

---------------------------------------------------------------------------
-- Barre à l'écran
---------------------------------------------------------------------------
local bar
local function build()
    local f = CreateFrame("Frame", "WarbandKeeperBlessBar", UIParent)
    f:SetSize(W, 40)
    f:SetFrameStrata("MEDIUM")
    f.bg = UI:Rounded(f, 10, 0, "BACKGROUND", 1)
    f.bg:SetColor(C.bg[1], C.bg[2], C.bg[3], 0.92)
    -- en tête : aura (bouton protégé), nom de l'aura, sceau et son temps
    f.aura = CreateFrame("Button", "WarbandKeeperBlessAura", f, "SecureActionButtonTemplate")
    f.aura:SetSize(22, 22); f.aura:SetPoint("TOPLEFT", 8, -8)
    f.aura:RegisterForClicks("AnyUp", "AnyDown")
    -- macro « /cast » (comme le bouton « Buffer le suivant ») : le type « spell » restait sans effet sur WoW Forever
    f.aura:SetAttribute("type", "macro")
    f.aura.icon = f.aura:CreateTexture(nil, "ARTWORK"); f.aura.icon:SetAllPoints()
    f.aura:SetScript("OnEnter", function(s) if not inCombat() then s:SetAttribute("useOnKeyDown", false) end end)
    f.aura:SetScript("OnLeave", function(s) if not inCombat() then s:SetAttribute("useOnKeyDown", nil) end end)
    f.auraName = UI:Text(f, 12, C.text); f.auraName:SetPoint("LEFT", f.aura, "RIGHT", 6, 0)
    f.seal = UI:Text(f, 10, C.muted); f.seal:SetPoint("TOPRIGHT", -8, -13); f.seal:SetJustifyH("RIGHT")
    f.line = f:CreateTexture(nil, "ARTWORK"); f.line:SetHeight(1)
    f.line:SetPoint("TOPLEFT", 8, -36); f.line:SetPoint("TOPRIGHT", -8, -36); f.line:SetColorTexture(unpack(C.border))
    f.rows = {}
    for i = 1, MAXROWS do
        local r = CreateFrame("Button", "WarbandKeeperBlessRow" .. i, f, "SecureActionButtonTemplate")
        r:SetHeight(ROWH)
        r:SetPoint("TOPLEFT", 6, -40 - (i - 1) * (ROWH + 2)); r:SetPoint("TOPRIGHT", -6, -40 - (i - 1) * (ROWH + 2))
        r:RegisterForClicks("AnyUp", "AnyDown")
        r:SetAttribute("type1", "macro")
        r.hl = UI:Rounded(r, 7, 0, "BACKGROUND", 2)
        r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(22, 22); r.icon:SetPoint("LEFT", 2, 0)
        r.name = UI:Text(r, 12, C.text); r.name:SetPoint("LEFT", r.icon, "RIGHT", 7, 0); r.name:SetWidth(96); r.name:SetJustifyH("LEFT")
        if r.name.SetWordWrap then r.name:SetWordWrap(false) end
        r.miss = UI:Badge(r, "", C.negative); r.miss:SetPoint("LEFT", r.name, "RIGHT", 2, 0)
        r.time = UI:Text(r, 11, C.muted); r.time:SetPoint("RIGHT", -4, 0); r.time:SetJustifyH("RIGHT")
        r:HookScript("OnClick", function(_, btn) if btn == "RightButton" and UI.OpenBlessings then UI:OpenBlessings() end end)
        r:SetScript("OnEnter", function(s)
            if not s.data then return end
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            GameTooltip:AddLine(rowLabel(s.data) .. " · " .. (B():Name(s.data.b) or "?"), 1, 1, 1)
            for _, m in ipairs(s.data.members) do
                local txt = m.dead and T("mort ou absent") or (m.left and (m.left == math.huge and T("sans fin") or short(m.left)) or T("sans"))
                local col = m.dead and C.dim or (m.left and (m.left < 300 and C.warning or C.positive) or C.negative)
                GameTooltip:AddDoubleLine(firstName(m.name), txt, 0.85, 0.85, 0.85, col[1], col[2], col[3])
            end
            GameTooltip:AddLine(T("Clic : bénir le suivant · clic droit : répartition"), 0.6, 0.6, 0.6)
            GameTooltip:AddLine(T("En groupe, le bouton « Buffer le suivant » bénit tout le monde selon cette répartition."), 0.6, 0.6, 0.6, true)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function(s)
            GameTooltip:Hide()
            if not inCombat() then s:SetAttribute("useOnKeyDown", nil) end
        end)
        -- souris : une seule action, au relâché, quel que soit le réglage « lancer à l'appui » du jeu
        r:HookScript("OnEnter", function(s) if not inCombat() then s:SetAttribute("useOnKeyDown", false) end end)
        r:HookScript("PostClick", function() C_Timer.After(0.4, function() if not inCombat() then UI:RefreshBlessBar() end end) end)
        r:Hide()
        f.rows[i] = r
    end
    f:Hide()

    -- Paint : textes (permis en combat) ; Arm : attributs, nombre de lignes, taille (hors combat seulement)
    function f:Paint(rows)
        local r1, g1, b1 = UI:Accent()
        -- en combat, les attributs (sort, cible) restent ceux d'avant : chaque ligne garde sa bénédiction
        local byKey
        if inCombat() then byKey = {}; for _, d in ipairs(rows) do byKey[rowKey(d)] = d end end
        for i, r in ipairs(self.rows) do
            local d = rows[i]
            if byKey then d = r.armKey and byKey[r.armKey] or nil end
            r.data = d
            if d and r:IsShown() then
                local id = B().BLESS[d.b] and B().BLESS[d.b][1]
                r.icon:SetTexture(id and B().Icon(id))
                r.name:SetText(rowLabel(d))
                r.name:SetTextColor(unpack(d.salut and C.text or classColor(d.class)))
                r.miss:SetShown(d.missing > 0)
                if d.missing > 0 then r.miss:Set(string.format(T("%d sans"), d.missing), C.negative) end
                local soon = d.min and d.min < 300
                r.time:SetText(d.missing > 0 and "" or short(d.min))
                r.time:SetTextColor(unpack(soon and C.warning or C.positive))
                r.hl:SetColor(d.missing > 0 and C.negative[1] or r1, d.missing > 0 and C.negative[2] or g1, d.missing > 0 and C.negative[3] or b1,
                    d.missing > 0 and 0.16 or (soon and 0.08 or 0))
            end
        end
        local M = B()
        local c = M:Me()
        local an = M:AuraName(c.aura or 0)
        self.auraName:SetText(an or T("Aucune aura"))
        self.aura.icon:SetTexture(M.AURAS[c.aura or 0] and M.Icon(M.AURAS[c.aura]) or "Interface\\Icons\\INV_Misc_QuestionMark")
        if not inCombat() then
            local sn, exp = sealInfo()
            self.sealTxt = sn and (sn .. ((exp and exp > 0) and (" · " .. short(exp - GetTime())) or "")) or ""
        end
        self.seal:SetText(self.sealTxt or "")
    end
    function f:Arm(rows)
        if inCombat() then return end
        local M = B()
        local c = M:Me()
        local an = M:AuraName(c.aura or 0)
        local amt = an and ("/cast " .. an) or nil
        if self.aura.armMacro ~= amt then self.aura.armMacro = amt; self.aura:SetAttribute("macrotext", amt) end
        local n = math.min(#rows, MAXROWS)
        for i, r in ipairs(self.rows) do
            local d = rows[i]
            if d and i <= n then
                -- le joueur de la ligne qui en a besoin, sinon celui dont la bénédiction finit le plus tôt
                local tgt = M:NextTarget(d, 300) or M:NextTarget(d, math.huge)
                local spell = M:Name(d.b)
                local mt = (tgt and spell) and UI.BuffMacro({ unit = tgt.unit, spell = spell }) or nil
                -- attribut posé seulement s'il change (avant : 13 boutons réécrits chaque seconde)
                if r.armMacro ~= mt then r.armMacro = mt; r:SetAttribute("macrotext1", mt) end
                r.armKey = rowKey(d)
                r:Show()
            else
                if r.armMacro ~= nil then r.armMacro = nil; r:SetAttribute("macrotext1", nil) end
                r.armKey = nil
                r:Hide()
            end
        end
        self:SetHeight(44 + n * (ROWH + 2) + 4)
    end
    return f
end

-- barre voulue (réglage) ; wanted() : et affichée maintenant (seul : cachée sauf réglage)
local function enabled()
    local M = B()
    return M and M:On() and M:Config().bar ~= false
end
local function wanted()
    local M = B()
    if not enabled() then return false end
    -- seul (pas de groupe) : barre cachée, sauf réglage « Aussi quand je suis seul »
    if not M:Config().barSolo and not (IsInGroup and IsInGroup()) then return false end
    return true
end
function UI:RefreshBlessBar()
    if not bar then
        if inCombat() or not enabled() then return end
        bar = build()
        UI:RegisterHUD("blessBar", bar, {
            label = T("Bénédictions"), default = { -300, 60 }, protected = true,
            enabled = function() return enabled() end,
            sample = function(on)
                bar.sample = on or nil
                if inCombat() then return end
                if on then
                    local M = B()
                    local demo = {
                        { class = "WARRIOR", b = 2, missing = 0, min = 3120, members = {} },
                        { class = "PRIEST", b = 1, missing = 2, members = {} },
                        { class = "ROGUE", b = 2, missing = 0, min = 180, members = {} },
                        { class = "SHAMAN", b = 1, missing = 0, min = 2460, members = {} },
                        { b = 4, salut = true, missing = 1, members = {} },
                    }
                    for i, r in ipairs(bar.rows) do r:SetShown(i <= #demo); r:SetAttribute("macrotext1", nil); r.armMacro = nil end
                    bar:SetHeight(44 + #demo * (ROWH + 2) + 4)
                    bar:Paint(demo)
                    bar:Show()
                    if M then bar.aura:SetAttribute("macrotext", nil); bar.aura.armMacro = nil end
                else
                    UI:RefreshBlessBar()
                end
            end,
        })
    end
    if bar.sample then return end
    if not wanted() then
        if not inCombat() then bar:Hide() end
        return
    end
    local rows = B():Status()
    if not inCombat() then
        bar:Arm(rows)
        bar:Show()
    end
    bar:Paint(rows)
end

local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(s, el)
    s.acc = (s.acc or 0) + el
    if s.acc < 1 then return end
    s.acc = 0
    if bar and bar:IsShown() and not bar.sample then pcall(UI.RefreshBlessBar, UI) end
end)
WK:On("PLAYER_REGEN_ENABLED", function() C_Timer.After(0.3, function() UI:RefreshBlessBar() end) end)
-- groupe rejoint ou quitté : la barre apparaît ou se cache (seul : cachée sauf réglage)
WK:On("GROUP_ROSTER_UPDATE", function() C_Timer.After(0.5, function() if not (InCombatLockdown and InCombatLockdown()) then UI:RefreshBlessBar() end end) end)
WK:On("PLAYER_LOGIN", function() C_Timer.After(5, function() UI:RefreshBlessBar() end) end)

---------------------------------------------------------------------------
-- Tableau de répartition et réglages (cartes construites par la section Paladin de QoL)
---------------------------------------------------------------------------
local MAXP = 6
function UI:BuildBlessingCards(card, toggle, dyn)
    local M = B()
    -- réglages
    local sc = card("Bénédictions", 40 + 5 * 46 + 8, "barre à l'écran et répartition entre paladins")
    UI:SettingRow(sc, -40, "Barre des bénédictions", "Se place en mode édition. Une ligne par classe du groupe : ta bénédiction, le temps restant, qui n'en a pas ; clic = bénir le suivant.",
        toggle(sc, function() return M:Config().bar ~= false end, function(v) M:Config().bar = v; UI:RefreshBlessBar() end), 80)
    UI:SettingRow(sc, -86, "Aussi quand je suis seul", "Sinon, la barre n'apparaît qu'en groupe, en raid ou en donjon.",
        toggle(sc, function() return M:Config().barSolo end, function(v) M:Config().barSolo = v; UI:RefreshBlessBar() end), 80)
    local mode = UI:Segmented(sc, { { "auto", "Automatique" }, { "hand", "À la main" } }, function(v) M:SetMode(v) end, 26)
    UI:SettingRow(sc, -132, "Répartition", "Automatique : Puissance puis Rois pour guerriers, voleurs et chasseurs ; Rois puis Sagesse pour mages et démonistes ; Sagesse puis Rois pour les soigneurs et le mana ; Rois pour les tanks. Chaque paladin prend ce que les autres n'ont pas. Compatible avec PallyPower.", mode, 230)
    UI:SettingRow(sc, -178, "Les autres peuvent changer ma ligne", "Sinon, seul le chef du groupe (ou ses assistants) le peut.",
        toggle(sc, function() return M:Me().free end, function(v) M:SetFree(v) end), 80)
    UI:SettingRow(sc, -224, "Salut collectif", "Le Salut se cumule avec la bénédiction de classe : une ligne à part dans la barre pour les guerriers, voleurs, chasseurs, mages et démonistes, jamais les tanks.",
        toggle(sc, function() return M:Config().salut ~= false end, function(v) M:Config().salut = v; M.StatusDirty(); UI:RefreshBlessBar() end), 80)
    table.insert(dyn, function() mode:Select(M:Me().mode) end)

    -- tableau couché : une ligne par paladin du groupe (toi d'abord, bande à gauche : accent = Warband Keeper,
    -- gris = PallyPower), une colonne par classe (icône, nom au survol ; grisée si absente du groupe) puis l'aura
    local NCOLS = #M.CLASSES + 1
    local RH, TOPY, IC, LABW = 58, 124, 44, 150
    local function cardH(n) return TOPY + math.max(1, n) * (RH + 6) + 48 end
    local tc = card("Répartition du groupe", cardH(3))
    UI.blessTable = tc
    -- test hors groupe : deux paladins simulés ajoutent leurs lignes
    tc.test = UI:Button(tc, "Tester", 130, 24, "secondary")
    tc.test:SetPoint("TOPRIGHT", -16, -9)
    tc.test.tooltip = "Simule deux autres paladins (un sous Warband Keeper en automatique, un sous PallyPower) pour voir la répartition. Seulement hors groupe ; rien n'est envoyé."
    tc.test:SetScript("OnClick", function()
        if not M:Demo(not M.demo) then WK:Print(T("Le test se lance hors groupe.")) end
        UI:RefreshBlessCard(); UI:RefreshBlessBar()
    end)
    tc.banner = CreateFrame("Frame", nil, tc)
    tc.banner:SetPoint("TOPLEFT", 16, -40); tc.banner:SetPoint("TOPRIGHT", -16, -40); tc.banner:SetHeight(30)
    tc.banner.bg = UI:Rounded(tc.banner, 8, 0, "BACKGROUND", 1)
    tc.banner.t = UI:Text(tc.banner, 11, C.muted); tc.banner.t:SetPoint("LEFT", 12, 0); tc.banner.t:SetPoint("RIGHT", -12, 0)
    tc.banner.t:SetJustifyH("LEFT")
    -- en-têtes de colonnes : icône de la classe, « Aura » pour la dernière
    tc.heads = {}
    for k = 1, NCOLS do
        local h = CreateFrame("Frame", nil, tc)
        h:SetHeight(40)
        h.ci = k <= #M.CLASSES and k or nil
        h.icon = h:CreateTexture(nil, "ARTWORK"); h.icon:SetSize(36, 36); h.icon:SetPoint("CENTER")
        h.label = UI:Text(h, 14, C.text); h.label:SetPoint("CENTER") -- lisible comme les icônes de classe
        if h.ci then
            UI:SetClassIcon(h.icon, M.CLASSES[h.ci])
            h.label:Hide()
            h:EnableMouse(true)
            h:SetScript("OnEnter", function(s)
                UI:TooltipOwner(s, "ANCHOR_TOP")
                GameTooltip:AddLine(className(M.CLASSES[h.ci]), unpack(classColor(M.CLASSES[h.ci])))
                GameTooltip:Show()
            end)
            h:SetScript("OnLeave", function() GameTooltip:Hide() end)
        else
            h.icon:Hide()
            h.label:SetText(T("Aura"))
        end
        tc.heads[k] = h
    end
    tc.rows = {}
    for p = 1, MAXP do
        local r = CreateFrame("Frame", nil, tc)
        r:SetHeight(RH)
        r.edge = UI:Rounded(r, 10, 0, "BACKGROUND", 1)
        r.fill = UI:Rounded(r, 10, 1, "BACKGROUND", 2); r.fill:SetColor(C.surface2[1], C.surface2[2], C.surface2[3], 1)
        r.stripe = r:CreateTexture(nil, "ARTWORK"); r.stripe:SetWidth(3)
        r.stripe:SetPoint("TOPLEFT", 1, -10); r.stripe:SetPoint("BOTTOMLEFT", 1, 10)
        r.name = UI:Text(r, 12, C.text); r.name:SetPoint("TOPLEFT", 14, -14); r.name:SetWidth(LABW - 20); r.name:SetJustifyH("LEFT")
        if r.name.SetWordWrap then r.name:SetWordWrap(false) end
        r.tag = UI:Text(r, 10, C.muted); r.tag:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
        r.cells = {}
        for k = 1, NCOLS do
            local b = CreateFrame("Button", nil, r)
            b:SetHeight(RH - 6)
            b:EnableMouse(true)
            b:SetFrameLevel(r:GetFrameLevel() + 3)
            b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            b.hl = b:CreateTexture(nil, "BACKGROUND"); b.hl:SetAllPoints(); b.hl:SetColorTexture(1, 1, 1, 0.05); b.hl:Hide()
            -- icône seule de la bénédiction ; cadre orange et « ! » si pas encore apprise ; cercle pointillé si aucune
            b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(IC, IC); b.icon:SetPoint("CENTER")
            b.empty = UI:Icon(b, "ring_dash", IC - 8, C.dim, "ARTWORK"); b.empty:SetPoint("CENTER", b.icon, "CENTER")
            -- pas apprise : cadre orange autour de l'icône et « ! » sur une pastille sombre, bien visibles
            -- (plaque orange un peu plus grande, posée sous la case : seul un bord de 3 px dépasse de l'icône)
            b.warnBox = CreateFrame("Frame", nil, r)
            b.warnBox:SetSize(IC + 6, IC + 6); b.warnBox:SetPoint("CENTER", b.icon, "CENTER")
            UI:Panel(b.warnBox, 8, C.warning)
            b.warnBox:SetFrameLevel(r:GetFrameLevel() + 2)
            b.warnDot = UI:Icon(b, "circle", 20, { C.bg[1], C.bg[2], C.bg[3], 0.95 }, "OVERLAY")
            b.warnDot:SetPoint("CENTER", b.icon, "BOTTOMRIGHT", -1, 3)
            b.warn = UI:Icon(b, "bang", 14, C.warning, "OVERLAY"); b.warn:SetPoint("CENTER", b.warnDot, "CENTER")
            b.warn:SetDrawLayer("OVERLAY", 7)
            b.txt = UI:Text(b, 12, C.text); b.txt:Hide()
            b:SetScript("OnEnter", function(s)
                s.hl:Show()
                if not s.tip then return end
                UI:TooltipOwner(s, "ANCHOR_RIGHT")
                GameTooltip:AddLine(s.tip, 1, 1, 1)
                if s.tipWarn then GameTooltip:AddLine(T("pas apprise"), C.warning[1], C.warning[2], C.warning[3]) end
                GameTooltip:AddLine(T("Clic : bénédiction suivante · clic droit : aucune"), 0.6, 0.6, 0.6)
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function(s) s.hl:Hide(); GameTooltip:Hide() end)
            local ci = k <= #M.CLASSES and k or nil
            b:SetScript("OnClick", function(_, btn)
                local who = tc.rowWho and tc.rowWho[p]
                if not who then return end
                local e = M.pallys[who] or {}
                if ci then
                    -- toutes les bénédictions défilent, puis « aucune » (une pas encore apprise est marquée)
                    local cur = (e.assign and e.assign[ci]) or 0
                    local nxt = (btn ~= "RightButton") and ((cur + 1) % (#M.BLESS + 1)) or 0
                    if not M:SetAssign(who, ci, nxt) then WK:Print(T("Seul le chef du groupe peut changer la ligne de ce paladin.")) end
                else
                    local cur = e.aura or 0
                    local nxt = (btn ~= "RightButton") and ((cur + 1) % (#M.AURAS + 1)) or 0
                    if not M:SetAura(who, nxt) then WK:Print(T("Seul le chef du groupe peut changer la ligne de ce paladin.")) end
                end
                UI:RefreshBlessCard()
                UI:RefreshBlessBar()
            end)
            r.cells[k] = b
        end
        tc.rows[p] = r
    end
    -- exceptions (ma ligne)
    tc.exHead = UI:Text(tc, 11, C.muted); tc.exHead:SetText(T("Exceptions :"))
    tc.addEx = UI:Button(tc, "+ Cible actuelle", nil, 24, "secondary")
    tc.addEx.tooltip = "Cible un joueur du groupe : il reçoit une autre bénédiction que celle de sa classe (clic sur la pastille pour changer, clic droit pour la retirer)."
    tc.addEx:SetScript("OnClick", function()
        if not (UnitExists("target") and UnitIsPlayer("target") and UnitCanAssist("player", "target")) then
            WK:Print(T("Cible d'abord un joueur ami.")) return
        end
        local name = M.FullName("target")
        local cl = select(2, UnitClass("target"))
        local b = 5
        if not M:Known(b) then for k = 1, #M.BLESS do if M:Known(k) then b = k break end end end
        M:SetException(name, cl, b)
        UI:RefreshBlessCard(); UI:RefreshBlessBar()
    end)
    tc.exChips = {}
    local function chip(i)
        local b = tc.exChips[i]
        if b then return b end
        b = UI:Button(tc, "", nil, 24, "ghost")
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetScript("OnClick", function(s, btn)
            local x = M:Me().except[s.who]
            if not x then return end
            if btn == "RightButton" then M:SetException(s.who, M.CLASSES[x.class], 0)
            else
                local nxt = x.b
                for k = 1, #M.BLESS do local cand = (x.b + k - 1) % #M.BLESS + 1; if M:Known(cand) then nxt = cand break end end
                M:SetException(s.who, M.CLASSES[x.class], nxt)
            end
            UI:RefreshBlessCard(); UI:RefreshBlessBar()
        end)
        tc.exChips[i] = b
        return b
    end

    local function layout(w)
        w = w or tc:GetWidth() or 800
        local n = math.max(1, tc.nRows or 1)
        local cw = math.floor((w - 32 - LABW) / NCOLS)
        for k, h in ipairs(tc.heads) do
            h:ClearAllPoints(); h:SetPoint("TOPLEFT", 16 + LABW + (k - 1) * cw, -(TOPY - 44)); h:SetWidth(cw)
        end
        for p, r in ipairs(tc.rows) do
            local y = TOPY + (p - 1) * (RH + 6)
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 16, -y); r:SetPoint("TOPRIGHT", -16, -y)
            for k, b in ipairs(r.cells) do
                b:ClearAllPoints(); b:SetPoint("TOPLEFT", LABW + (k - 1) * cw, -3); b:SetWidth(cw)
            end
        end
        local y = TOPY + n * (RH + 6) + 6
        tc.exHead:ClearAllPoints(); tc.exHead:SetPoint("TOPLEFT", 16, -(y + 5))
        tc.exY = y
    end
    UI:OnResize(tc, layout)

    UI.RefreshBlessCard = function()
        if not tc:IsVisible() then return end
        local list = M:Pallys()
        local r1, g1, b1 = UI:Accent()
        local n = math.min(#list, MAXP)
        if tc.nRows ~= n then tc.nRows = n; tc:SetHeight(cardH(n)); layout() end
        tc.rowWho = {}
        -- classes présentes dans le groupe (toutes quand tu es seul)
        local present, alone = {}, not (IsInGroup and IsInGroup())
        for _, u in ipairs(M.GroupUnits()) do
            if UnitExists(u) then local cl = select(2, UnitClass(u)); if cl then present[cl] = true end end
        end
        tc.banner.bg:SetColor(r1, g1, b1, 0.10)
        tc.test.label:SetText(T(M.demo and "Arrêter le test" or "Tester"))
        if M.demo then
            tc.banner.t:SetText(UI:Hex(C.warning) .. T("Test : Aerin et Brann sont simulés, rien n'est envoyé.") .. "|r  " .. UI:Hex(C.dim) .. T("Clic : bénédiction suivante · clic droit : aucune") .. "|r")
        elseif alone or n <= 1 then
            tc.banner.t:SetText(T("Seul pour l'instant : en groupe, chaque autre paladin (Warband Keeper ou PallyPower) ajoute une ligne.") .. "  " .. UI:Hex(C.dim) .. T("Clic : bénédiction suivante · clic droit : aucune") .. "|r")
        else
            tc.banner.t:SetText(string.format(T("%d paladins dans le groupe"), n) .. "  " .. UI:Hex(C.dim) .. T("Clic : bénédiction suivante · clic droit : aucune") .. "|r")
        end
        for _, h in ipairs(tc.heads) do
            local here = not h.ci or alone or present[M.CLASSES[h.ci]]
            h.icon:SetAlpha(here and 1 or 0.3)
            if h.icon.SetDesaturated then h.icon:SetDesaturated(not here) end
        end
        for p, r in ipairs(tc.rows) do
            local it = list[p]
            r:SetShown(it ~= nil and p <= n)
            if it then
                local e = it.e
                tc.rowWho[p] = it.name
                r.name:SetText(string.upper(e.me and T("Toi") or firstName(it.name)))
                local col = e.wk and { r1, g1, b1 } or C.muted
                r.tag:SetText(e.wk and "Warband Keeper" or "PallyPower")
                r.tag:SetTextColor(unpack(col))
                r.stripe:SetColorTexture(col[1], col[2], col[3], 1)
                if e.me then r.edge:SetColor(r1, g1, b1, 0.6) else r.edge:SetColor(C.border[1], C.border[2], C.border[3], 1) end
                local editable = M:CanEdit(it.name)
                for k, b in ipairs(r.cells) do
                    local ci = k <= #M.CLASSES and k or nil
                    local here = not ci or alone or present[M.CLASSES[ci]]
                    local v, id, label
                    local learned = true
                    if ci then
                        v = e.assign and e.assign[ci] or 0
                        id = M.BLESS[v] and M.BLESS[v][1]
                        label = id and M:Name(v)
                        if id and e.me then learned = M:Known(v) end
                    else
                        v = e.aura or 0
                        id = M.AURAS[v]
                        label = id and M:AuraName(v)
                        if id and e.me then learned = M:KnownAura(v) end
                    end
                    b.icon:SetTexture(id and M.Icon(id) or nil)
                    b.icon:SetShown(id ~= nil)
                    -- pas apprise : icône en couleur, signalée par le cadre orange et le « ! » seulement
                    if b.icon.SetDesaturated then b.icon:SetDesaturated(false) end
                    b.icon:SetAlpha(here and 1 or 0.5)
                    local unl = id ~= nil and not learned
                    b.warn:SetShown(unl); b.warnDot:SetShown(unl); b.warnBox:SetShown(unl)
                    b.empty:SetShown(id == nil)
                    b.tip, b.tipWarn = label or T("aucune"), (id ~= nil and not learned)
                    b.txt:SetText(label or T("aucune"))
                    b:SetAlpha(editable and 1 or 0.6)
                end
            end
        end
        -- exceptions
        local x = 16 + (tc.exHead:GetStringWidth() or 70) + 10
        local i = 0
        local names = {}
        for name in pairs(M:Me().except) do table.insert(names, name) end
        table.sort(names)
        for _, name in ipairs(names) do
            i = i + 1
            local ex = M:Me().except[name]
            local c = chip(i)
            c.who = name
            c:SetLabel(firstName(name) .. " : " .. (M:Name(ex.b) or "?"))
            c:SetWidth(c.label:GetStringWidth() + 24)
            c:ClearAllPoints(); c:SetPoint("TOPLEFT", x, -tc.exY); c:Show()
            x = x + c:GetWidth() + 6
        end
        for k = i + 1, #tc.exChips do tc.exChips[k]:Hide() end
        tc.addEx:ClearAllPoints(); tc.addEx:SetPoint("TOPLEFT", x, -tc.exY)
    end
    tc:HookScript("OnShow", function() C_Timer.After(0, function() UI:RefreshBlessCard() end) end)
    table.insert(dyn, function() UI:RefreshBlessCard() end)
    M.OnChange = function()
        if UI.RefreshBlessCard then UI:RefreshBlessCard() end
        UI:RefreshBlessBar()
    end
end

-- Ouvre l'onglet « Bénédictions » de QoL > Classes > Paladin
function UI:OpenBlessings()
    if not (UI.frame and UI.frame:IsShown()) then UI:ToggleWindow("qol") end
    UI:ShowPage("qol")
    local d = UI.pages.qol
    if d and d.ShowSection then d:ShowSection("PALADIN") end
    local sec = d and d.sections and d.sections.PALADIN
    if sec and sec.tabs and sec.showTab then
        for _, t in ipairs(sec.tabs) do if t.label == "Bénédictions" and t.index then sec.showTab(t.index) end end
    end
end
WK:On("PLAYER_LOGIN", function()
    local M = B()
    if M and not M.OnChange then
        M.OnChange = function()
            if UI.RefreshBlessCard then UI:RefreshBlessCard() end
            UI:RefreshBlessBar()
        end
    end
end)
