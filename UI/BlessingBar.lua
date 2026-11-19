local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Bénédictions du paladin (Modules/Blessings.lua) :
--  · barre à l'écran (HUD « blessBar », mode édition) : en tête ton aure (clic = la lancer) et ton sceau,
--    puis une ligne par classe présente (et une par exception) : ta bénédiction, le temps restant le plus
--    court, le nombre de joueurs sans. Clic gauche = bénir le prochain joueur de la ligne qui en a besoin
--    (bouton protégé : sort et cible posés hors combat), clic droit = tableau de répartition, survol = détail.
--  · tableau de répartition (QoL > Classes > Paladin, onglet « Bénédictions ») : une ligne par paladin du
--    groupe (pastille Warband Keeper ou PallyPower), une colonne par classe + l'aure ; clic = suivante,
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
    -- en tête : aure (bouton protégé), nom de l'aure, sceau et son temps
    f.aura = CreateFrame("Button", "WarbandKeeperBlessAura", f, "SecureActionButtonTemplate")
    f.aura:SetSize(22, 22); f.aura:SetPoint("TOPLEFT", 8, -8)
    f.aura:RegisterForClicks("AnyUp", "AnyDown")
    f.aura:SetAttribute("type", "spell")
    f.aura.icon = f.aura:CreateTexture(nil, "ARTWORK"); f.aura.icon:SetAllPoints()
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
        r:SetAttribute("type1", "spell")
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
            GameTooltip:AddLine((s.data.except and firstName(s.data.except) or className(s.data.class)) .. " · " .. (B():Name(s.data.b) or "?"), 1, 1, 1)
            for _, m in ipairs(s.data.members) do
                local txt = m.dead and T("mort ou absent") or (m.left and (m.left == math.huge and T("sans fin") or short(m.left)) or T("sans"))
                local col = m.dead and C.dim or (m.left and (m.left < 300 and C.warning or C.positive) or C.negative)
                GameTooltip:AddDoubleLine(firstName(m.name), txt, 0.85, 0.85, 0.85, col[1], col[2], col[3])
            end
            GameTooltip:AddLine(T("Clic : bénir le suivant · clic droit : répartition"), 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        r:Hide()
        f.rows[i] = r
    end
    f:Hide()

    -- Paint : textes (permis en combat) ; Arm : attributs, nombre de lignes, taille (hors combat seulement)
    function f:Paint(rows)
        local r1, g1, b1 = UI:Accent()
        for i, r in ipairs(self.rows) do
            local d = rows[i]
            r.data = d
            if d and r:IsShown() then
                local id = B().BLESS[d.b] and B().BLESS[d.b][1]
                r.icon:SetTexture(id and B().Icon(id))
                r.name:SetText(d.except and (firstName(d.except) .. " *") or className(d.class))
                r.name:SetTextColor(unpack(classColor(d.class)))
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
        self.auraName:SetText(an or T("Aucune aure"))
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
        self.aura:SetAttribute("spell", an)
        local n = math.min(#rows, MAXROWS)
        for i, r in ipairs(self.rows) do
            local d = rows[i]
            if d and i <= n then
                local tgt = M:NextTarget(d, 300)
                r:SetAttribute("spell1", M:Name(d.b))
                r:SetAttribute("unit1", tgt and tgt.unit or nil)
                r:Show()
            else
                r:SetAttribute("unit1", nil)
                r:Hide()
            end
        end
        self:SetHeight(44 + n * (ROWH + 2) + 4)
    end
    return f
end

local function wanted()
    local M = B()
    return M and M:On() and M:Config().bar ~= false
end
function UI:RefreshBlessBar()
    if not bar then
        if inCombat() or not wanted() then return end
        bar = build()
        UI:RegisterHUD("blessBar", bar, {
            label = T("Bénédictions"), default = { -300, 60 }, protected = true,
            enabled = function() return wanted() end,
            sample = function(on)
                bar.sample = on or nil
                if inCombat() then return end
                if on then
                    local M = B()
                    local demo = {
                        { class = "WARRIOR", b = 3, missing = 0, min = 3120, members = {} },
                        { class = "PRIEST", b = 1, missing = 2, members = {} },
                        { class = "ROGUE", b = 2, missing = 0, min = 180, members = {} },
                        { class = "SHAMAN", b = 1, missing = 0, min = 2460, members = {} },
                    }
                    for i, r in ipairs(bar.rows) do r:SetShown(i <= #demo); r:SetAttribute("unit1", nil); r:SetAttribute("spell1", nil) end
                    bar:SetHeight(44 + #demo * (ROWH + 2) + 4)
                    bar:Paint(demo)
                    bar:Show()
                    if M then bar.aura:SetAttribute("spell", nil) end
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
WK:On("PLAYER_LOGIN", function() C_Timer.After(5, function() UI:RefreshBlessBar() end) end)

---------------------------------------------------------------------------
-- Tableau de répartition et réglages (cartes construites par la section Paladin de QoL)
---------------------------------------------------------------------------
local MAXP = 6
function UI:BuildBlessingCards(card, toggle, dyn)
    local M = B()
    -- réglages
    local sc = card("Bénédictions", 40 + 3 * 46 + 8, "barre à l'écran et répartition entre paladins")
    UI:SettingRow(sc, -40, "Barre des bénédictions", "Se place en mode édition. Une ligne par classe du groupe : ta bénédiction, le temps restant, qui n'en a pas ; clic = bénir le suivant.",
        toggle(sc, function() return M:Config().bar ~= false end, function(v) M:Config().bar = v; UI:RefreshBlessBar() end), 80)
    local mode = UI:Segmented(sc, { { "auto", "Automatique" }, { "hand", "À la main" } }, function(v) M:SetMode(v) end, 26)
    UI:SettingRow(sc, -86, "Répartition", "Automatique : chaque paladin prend une bénédiction que les autres n'ont pas (Rois, Sagesse, Puissance…). Compatible avec les paladins sous PallyPower.", mode, 230)
    UI:SettingRow(sc, -132, "Les autres peuvent changer ma ligne", "Sinon, seul le chef du groupe (ou ses assistants) le peut.",
        toggle(sc, function() return M:Me().free end, function(v) M:SetFree(v) end), 80)
    table.insert(dyn, function() mode:Select(M:Me().mode) end)

    -- tableau
    local tc = card("Répartition du groupe", 40 + 24 + MAXP * 36 + 64, "clic : bénédiction suivante · clic droit : aucune")
    tc.empty = UI:Text(tc, 11, C.muted); tc.empty:SetPoint("TOPLEFT", 16, -70)
    tc.heads = {}
    local cols = {}
    for i, cl in ipairs(M.CLASSES) do cols[i] = cl end
    for i = 1, #cols + 1 do
        local h = UI:Text(tc, 9, C.dim)
        h:SetText(i <= #cols and string.upper(className(cols[i])) or T("AURE"))
        h:SetJustifyH("CENTER")
        tc.heads[i] = h
    end
    tc.rows = {}
    local function cellButton(parent)
        local b = CreateFrame("Button", nil, parent)
        b:SetSize(28, 28)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b.bg = UI:Rounded(b, 7, 0, "BACKGROUND", 1); b.bg:SetColor(C.surface2[1], C.surface2[2], C.surface2[3], 1)
        b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetPoint("TOPLEFT", 2, -2); b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        b.txt = UI:Text(b, 10, C.dim); b.txt:SetPoint("CENTER"); b.txt:SetText("-")
        return b
    end
    for p = 1, MAXP do
        local r = CreateFrame("Frame", nil, tc)
        r:SetHeight(32)
        r.name = UI:Text(r, 12, C.text); r.name:SetPoint("LEFT", 0, 6); r.name:SetWidth(120); r.name:SetJustifyH("LEFT")
        if r.name.SetWordWrap then r.name:SetWordWrap(false) end
        r.tag = UI:Text(r, 9, C.muted); r.tag:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
        r.cells = {}
        for i = 1, #cols + 1 do
            local b = cellButton(r)
            b.col = i
            b:SetScript("OnClick", function(s, btn)
                local who = r.who
                if not who then return end
                local e = M.pallys[who] or {}
                if s.col <= #cols then
                    local cur = (e.assign and e.assign[s.col]) or 0
                    local nxt = 0
                    if btn ~= "RightButton" then
                        for k = 1, #M.BLESS do
                            local cand = (cur + k - 1) % #M.BLESS + 1
                            local ok = e.me and M:Known(cand) or (not e.me and (not e.known or not next(e.known) or e.known[cand]))
                            if ok then nxt = cand break end
                        end
                    end
                    if not M:SetAssign(who, s.col, nxt) then WK:Print(T("Seul le chef du groupe peut changer la ligne de ce paladin.")) end
                else
                    local cur = e.aura or 0
                    local nxt = 0
                    if btn ~= "RightButton" then
                        for k = 1, #M.AURAS do
                            local cand = (cur + k - 1) % #M.AURAS + 1
                            if not e.me or M:KnownAura(cand) then nxt = cand break end
                        end
                    end
                    if not M:SetAura(who, nxt) then WK:Print(T("Seul le chef du groupe peut changer la ligne de ce paladin.")) end
                end
                UI:RefreshBlessCard()
                UI:RefreshBlessBar()
            end)
            r.cells[i] = b
        end
        r:Hide()
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
        local nameW = 140
        local cw = math.max(30, math.floor((w - 32 - nameW) / (#cols + 1)))
        for i, h in ipairs(tc.heads) do
            h:ClearAllPoints(); h:SetPoint("TOPLEFT", 16 + nameW + (i - 1) * cw, -44); h:SetWidth(cw)
        end
        for p, r in ipairs(tc.rows) do
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 16, -64 - (p - 1) * 36); r:SetPoint("TOPRIGHT", -16, -64 - (p - 1) * 36)
            for i, b in ipairs(r.cells) do
                b:ClearAllPoints(); b:SetPoint("LEFT", nameW + (i - 1) * cw + (cw - 28) / 2, 0)
            end
        end
        local y = 64 + MAXP * 36 + 8
        tc.exHead:ClearAllPoints(); tc.exHead:SetPoint("TOPLEFT", 16, -(y + 5))
        tc.exY = y
    end
    UI:OnResize(tc, layout)

    UI.RefreshBlessCard = function()
        if not tc:IsVisible() then return end
        local list = M:Pallys()
        local r1, g1, b1 = UI:Accent()
        for p, r in ipairs(tc.rows) do
            local it = list[p]
            r.who = it and it.name
            r:SetShown(it ~= nil)
            if it then
                local e = it.e
                r.name:SetText(it.e.me and T("Toi") or firstName(it.name))
                r.tag:SetText(e.me and "Warband Keeper" or (e.wk and "Warband Keeper" or "PallyPower"))
                r.tag:SetTextColor(e.wk and r1 or C.muted[1], e.wk and g1 or C.muted[2], e.wk and b1 or C.muted[3])
                local editable = M:CanEdit(it.name)
                for i, b in ipairs(r.cells) do
                    local v, id
                    if i <= #cols then
                        v = e.assign and e.assign[i] or 0
                        id = M.BLESS[v] and M.BLESS[v][1]
                    else
                        v = e.aura or 0
                        id = M.AURAS[v]
                    end
                    b.icon:SetTexture(id and M.Icon(id) or nil)
                    b.icon:SetShown(id ~= nil)
                    b.txt:SetShown(id == nil)
                    b:SetAlpha(editable and 1 or 0.6)
                end
            end
        end
        tc.empty:SetShown(#list <= 1 and not IsInGroup())
        tc.empty:SetText(T("Seul pour l'instant : en groupe, les autres paladins (Warband Keeper ou PallyPower) apparaissent ici."))
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
