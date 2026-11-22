local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Page « QoL » (qualité de vie) : colonne à gauche (Général puis les 9 classes, grisées quand
-- aucun perso ne les joue), réglages à droite. Une fiche de classe commence par les persos de
-- cette classe, puis les composants, les munitions et les aides propres à la classe.
local GAP = 12
local NAV_W = 230

local function Q() return WK.modules.QoL end

-- Nombre affiché sans décimales, avec espace des milliers (« 1 840 »).
local function num(n)
    local s = tostring(math.floor(n or 0))
    local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse()
    return (out:gsub("^ ", ""))
end

local function classColor(class)
    local r, g, b = UI:ClassColor(class)
    return { r, g, b, 1 }
end

local function minutes(sec)
    if not sec then return "-" end
    if sec <= 0 then return T("prête") end
    if sec < 3600 then return string.format(T("%d min"), math.ceil(sec / 60)) end
    return string.format(T("%d h %02d"), math.floor(sec / 3600), math.floor(sec % 3600 / 60))
end

-- Colonnes de la tuile d'un perso : jusqu'à trois chiffres clés propres à sa classe.
-- { icon, value, label, color, ratio (0-1, petite jauge) }
local ICONS = {
    clock = "Interface\\Icons\\INV_Misc_PocketWatch_01",
    repair = "Interface\\Icons\\Trade_BlackSmithing",
    unknown = "Interface\\Icons\\INV_Misc_QuestionMark",
}
local function itemIcon(id)
    local f = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
    return (f and id and f(id)) or ICONS.unknown
end
local function spellIcon(id) return select(2, WK.SpellInfo(id)) or ICONS.unknown end
local function stat(icon, value, label, color, ratio)
    return { icon = icon, value = value, label = label, color = color, ratio = ratio }
end

local function reagentStat(c, r, cc)
    local n = Q():Count(c, r)
    local s = cc.reag[r.key] or {}
    local low = (s.min or 0) > 0 and n < s.min
    local target = ((s.buy or 0) > 0 and s.buy) or ((s.min or 0) > 0 and s.min * 2) or nil
    return stat(itemIcon(r.id or (r.ids and r.ids[1])), num(n), Q():ReagentName(r),
        low and (n == 0 and C.negative or C.warning) or C.text, target and math.min(1, n / target) or nil)
end

local function durabilityStat(c)
    local d = c.durability
    local g = Q():General()
    local col = (d and (g.durability or 0) > 0 and d < g.durability) and C.negative or C.text
    return stat(ICONS.repair, d and (d .. " %") or "-", T("équipement"), col, d and d / 100 or nil)
end

local function charStats(c)
    local QoL, class = Q(), c.class
    local cc = QoL:Class(class)
    local out = {}
    local function add(st) if #out < 3 then table.insert(out, st) end end
    local reags = {}
    for _, r in ipairs(QoL.REAGENTS[class] or {}) do
        if QoL:Relevant(r, c.level) then reags[r.key] = r end
    end
    -- Munitions et minutes de tir (chasseur, guerrier, voleur)
    if QoL.AMMO[class] and c.ammo and c.ammo.id then
        local n = c.ammo.n or 0
        local mins = c.ammo.speed and math.floor(n * c.ammo.speed / 60) or nil
        local lowN = (cc.ammo.min or 0) > 0 and n < cc.ammo.min
        local lowM = mins and (cc.ammo.minMinutes or 0) > 0 and mins < cc.ammo.minMinutes
        local col = (lowN or lowM) and (n == 0 and C.negative or C.warning) or C.text
        add(stat(itemIcon(c.ammo.id), num(n), T("munitions"), col, (cc.ammo.buy or 0) > 0 and math.min(1, n / cc.ammo.buy) or nil))
        if mins then
            add(stat(ICONS.clock, mins >= 1 and string.format(T("%d min"), mins) or T("moins d'1 min"), T("de tir restantes"),
                lowM and C.warning or C.positive))
        end
    end
    if class == "HUNTER" then
        local h = c.pet and c.pet.happy
        local label = ({ T("Mécontent"), T("Content"), T("Heureux") })[h or 0]
        local col = ({ C.negative, C.warning, C.positive })[h or 0] or C.dim
        add(stat(spellIcon(883), label or "-", (c.pet and c.pet.name) and (c.pet.name .. " · " .. T("familier")) or T("familier"), col))
    elseif class == "ROGUE" then
        if reags.poisons then add(reagentStat(c, reags.poisons, cc)) end
        add(stat(spellIcon(1804), c.lockpick and tostring(c.lockpick) or "-", T("crochetage")))
    elseif class == "WARLOCK" then
        local n = (c.bags or {})[6265] or 0
        local max = cc.shardMax or 20
        add(stat(itemIcon(6265), n .. " / " .. max, T("fragments d'âme"), n == 0 and C.negative or C.text, math.min(1, n / max)))
        for _, k in ipairs({ "healthstone", "soulstone" }) do
            local r = reags[k]
            if r then
                local has = QoL:Count(c, r) > 0
                add(stat(itemIcon(r.ids[1]), has and T("Oui") or T("Non"), QoL:ReagentName(r), has and C.positive or C.dim))
            end
        end
    elseif class == "SHAMAN" then
        local have, total = 0, 0
        for _, r in ipairs(QoL.REAGENTS.SHAMAN) do
            if r.totem and reags[r.key] then total = total + 1; if QoL:Count(c, r) > 0 then have = have + 1 end end
        end
        if total > 0 then
            add(stat(itemIcon(5175), have .. " / " .. total, T("totems"), have < total and C.warning or C.positive, have / total))
        end
        if reags["17030"] then add(reagentStat(c, reags["17030"], cc)) end
        if (c.level or 0) >= 30 then
            local left = c.reincarnation and (c.reincarnation - time())
            add(stat(spellIcon(20608), left and minutes(left) or "-", T("réincarnation"), (left and left <= 0) and C.positive or C.text))
        end
    else
        -- Mage, prêtre, paladin, druide, guerrier : composants utiles à son niveau
        for _, r in ipairs(QoL.REAGENTS[class] or {}) do
            local s = cc.reag[r.key] or {}
            if reags[r.key] and ((s.min or 0) > 0 or r.buy or r.conjured) then add(reagentStat(c, r, cc)) end
        end
    end
    if c.durability then add(durabilityStat(c)) end
    return out
end

-- Sections de QoL, affichées sous « QoL » dans la barre latérale (UI/MainFrame.lua) : clé, libellé, icône.
UI.QOL_SECTIONS = {
    { "general", "Général", "gear" }, { "halo", "Halo", "spark" }, { "micro", "Micro menu", "menu" },
    { "maplayers", "Carte et guidage", "map" },
    { "cursor", "Curseur", "crosshair" }, { "campfire", "Feu de camp", "fire" }, { "xp", "Expérience", "chart" }, { "classes", "Classes", "users" },
}
-- Pastille d'une section dans la barre latérale : alertes générales (Général) ou des classes (Classes).
function UI:QoLSectionCount(key)
    if key ~= "general" and key ~= "classes" then return "" end
    local n = 0
    for _, a in ipairs(Q():Alerts()) do
        if (key == "general") == (a.class == nil) then n = n + 1 end
    end
    return n > 0 and tostring(n) or ""
end
-- Alertes d'une section (Général : sacs, banque, réparation ; Classes : composants, munitions, familier)
function UI:QoLSectionAlerts(key)
    local out = {}
    if key ~= "general" and key ~= "classes" then return out end
    for _, a in ipairs(Q():Alerts()) do
        if (key == "general") == (a.class == nil) then table.insert(out, a) end
    end
    return out
end
-- Ouvre QoL > Général, onglet Alertes (seuils et rappels).
function UI:OpenQoLAlerts()
    UI:ShowPage("qol")
    local d = UI.pages.qol
    if d and d.ShowSection then d:ShowSection("general") end
    local sec = d and d.sections and d.sections.general
    if sec and sec.tabs and sec.showTab then
        for _, t in ipairs(sec.tabs) do if t.label == "Alertes" and t.index then sec.showTab(t.index) end end
    end
end
-- Réglages de la barre « Sacs, marchand et maître » : QoL > Général > onglet Marchand
function UI:OpenBagBarSettings()
    UI:ShowPage("qol")
    local d = UI.pages.qol
    if d and d.ShowSection then d:ShowSection("general") end
    local sec = d and d.sections and d.sections.general
    if sec and sec.tabs and sec.showTab then
        for _, t in ipairs(sec.tabs) do if t.label == "Marchand" and t.index then sec.showTab(t.index) end end
    end
end
-- Section affichée (« classes » pour une classe), pour la barre latérale.
function UI:QoLCurrentSection()
    local s = WK.DB.global.settings.ui.qolSection or "general"
    for _, sec in ipairs(UI.QOL_SECTIONS) do if sec[1] == s then return s end end
    return "classes"
end

UI:RegisterPage({
    key = "qol", order = 8, nav = "QoL",

    Build = function(self, p)
        local QoL = Q()
        local q = QoL:Config()
        local ui = WK.DB.global.settings.ui
        local W = UI.PAGE_W - 12

        -- Les sections se choisissent dans la barre latérale (sous « QoL ») : la colonne de la page
        -- reste construite (état des boutons) mais n'est plus affichée ; le contenu prend la largeur.
        local navCard = UI:Card(p)
        navCard:SetWidth(NAV_W)
        navCard:SetPoint("TOPLEFT")
        navCard:SetPoint("BOTTOMLEFT")
        navCard:Hide()
        local host = CreateFrame("Frame", nil, p)
        host:SetPoint("TOPLEFT", 0, 0)
        host:SetPoint("BOTTOMRIGHT")

        self.sections, self.navButtons = {}, {}
        self.toggles, self.inputs, self.dyn = {}, {}, {}
        local root, y, current

        local CLASSBAR_H = 64
        local TABS_H = 46
        ui.qolTabs = ui.qolTabs or {}
        -- Onglets d'une section : subtab(nom, ordre) range les cartes qui suivent dans un onglet
        -- (un nom déjà vu reprend son onglet). Ce qui précède le premier onglet reste au-dessus.
        -- La barre est posée à la fin de la section ; un onglet sans carte n'y figure pas.
        local function subtab(label, order)
            local sec = current
            if not sec.tabs then sec.tabs, sec.byLabel, sec.base = {}, {}, y end
            if sec.cur then sec.cur.h = y end
            local t = sec.byLabel[label]
            if not t then
                local pane = CreateFrame("Frame", nil, sec.scroll.child)
                pane:SetPoint("TOPLEFT", 0, -(sec.base + TABS_H))
                pane:SetPoint("TOPRIGHT", 0, -(sec.base + TABS_H))
                pane:SetHeight(1)
                t = { label = label, pane = pane, h = 0, order = order or (#sec.tabs + 1) }
                sec.byLabel[label] = t
                table.insert(sec.tabs, t)
            end
            sec.cur = t
            root, y = t.pane, t.h
        end
        local function closeSection()
            local sec = current
            if not sec then return end
            if not sec.tabs then
                sec.tailY = y
                sec.scroll:SetContentHeight(y + (sec.extraY and sec.extraY() or 0))
                return
            end
            sec.cur.h = y
            local shown = {}
            for _, t in ipairs(sec.tabs) do
                if t.h > 0 then table.insert(shown, t) else t.pane:Hide() end
            end
            table.sort(shown, function(a, b) return a.order < b.order end)
            local items = {}
            for i, t in ipairs(shown) do t.index = i; table.insert(items, { i, t.label }) end
            local key = sec.key
            function sec.showTab(i)
                if not shown[i] then i = 1 end
                ui.qolTabs[key] = shown[i] and shown[i].label
                for j, t in ipairs(shown) do t.pane:SetShown(j == i) end
                if sec.seg then sec.seg:Select(i) end
                sec.scroll:SetContentHeight(sec.base + TABS_H + (shown[i] and shown[i].h or 0))
                if sec.scroll.SetVerticalScroll then sec.scroll:SetVerticalScroll(0) end
            end
            function sec.tabOf(frame)
                local f = frame
                while f do
                    for i, t in ipairs(shown) do if f == t.pane then return i end end
                    f = f:GetParent()
                end
            end
            if #shown > 1 then
                sec.seg = UI:Segmented(sec.scroll.child, items, function(i) sec.showTab(i) end, 32)
                sec.seg:SetPoint("TOPLEFT", 0, -sec.base)
            else
                -- un seul onglet : pas de barre, son contenu remonte
                for _, t in ipairs(shown) do
                    t.pane:ClearAllPoints()
                    t.pane:SetPoint("TOPLEFT", 0, -sec.base); t.pane:SetPoint("TOPRIGHT", 0, -sec.base)
                end
                sec.base = sec.base - TABS_H
            end
            local want = 1
            for i, t in ipairs(shown) do if t.label == ui.qolTabs[key] then want = i end end
            sec.showTab(want)
        end
        local function section(key, top)
            closeSection()
            local sc = UI:Scroll(host)
            sc:SetPoint("TOPLEFT", 0, -(top or 0))
            sc:SetPoint("BOTTOMRIGHT")
            sc:Hide()
            current = { scroll = sc, key = key }
            self.sections[key] = current
            root, y = sc.child, 0
        end
        local function card(title, h, subtitle)
            local c = UI:Card(root, title, subtitle)
            current.cards = current.cards or {}
            table.insert(current.cards, c)
            c.cardKey = title
            c:SetSize(W, h)
            c:SetPoint("TOPLEFT", 0, -y)
            c:SetPoint("TOPRIGHT", 0, -y)
            y = y + h + GAP
            return c
        end
        local function toggle(parent, get, set)
            local t = UI:Toggle(parent, get, function(v) set(v); WK:NotifyChanged() end)
            table.insert(self.toggles, t)
            return t
        end
        -- Texte recalculé à chaque rafraîchissement.
        local function dynText(parent, size, color, fn)
            local t = UI:Text(parent, size, color)
            table.insert(self.dyn, function() t:SetText(fn(t) or "") end)
            return t
        end

        local isClass = {}
        for _, cl in ipairs(QoL.CLASSES) do isClass[cl[1]] = true end
        isClass.CLASSGEN = true -- onglet « Général » des classes (réglages communs : sorts de classe)
        -- « classes » ouvre la dernière classe vue (sinon celle du perso joué)
        function self:ShowSection(key)
            if key == "classes" then
                key = ui.qolClass
                if not isClass[key or ""] then key = WK.DB:Me().class end
                if not isClass[key or ""] then key = QoL.CLASSES[1][1] end
            end
            if not self.sections[key] then key = "general" end
            ui.qolSection = key
            local cls = isClass[key]
            if cls then ui.qolClass = key end
            for k, sec in pairs(self.sections) do sec.scroll:SetShown(k == key) end
            local navKey = cls and "classes" or key
            for k, b in pairs(self.navButtons) do b.selected = (k == navKey); b:Paint() end
            self.classBar:SetShown(cls or false)
            for k, t in pairs(self.classTabs) do t.selected = (k == key); t:Paint() end
            if UI.RefreshNavSubs then UI:RefreshNavSubs() end
        end

        -- Colonne : Général puis les classes ---------------------------------------
        local function navButton(key, label, y0, class, iconName)
            local b = CreateFrame("Button", nil, navCard)
            b:SetHeight(48)
            b:SetPoint("TOPLEFT", 8, y0)
            b:SetPoint("TOPRIGHT", -8, y0)
            b.bg = UI:Rounded(b, 10, 0, "BACKGROUND", 1)
            b.bar = CreateFrame("Frame", nil, b)
            b.bar:SetSize(3, 20)
            b.bar:SetPoint("LEFT")
            b.barTex = UI:Rounded(b.bar, 1.5, 0, "ARTWORK", 1)
            if class then
                b.icon = UI:RoundIcon(b, 26)
                UI:SetClassIcon(b.icon, class)
                b.icon:SetPoint("LEFT", 12, 0)
            else
                b.iconBg = UI:Icon(b, "circle", 26, nil, "ARTWORK")
                b.iconBg:SetPoint("LEFT", 12, 0)
                b.icon = UI:Icon(b, iconName or "gear", 14, C.onAccent, "OVERLAY")
                b.icon:SetPoint("CENTER", b.iconBg, "CENTER")
            end
            b.label = UI:Text(b, 13)
            b.label:SetPoint("TOPLEFT", 48, -8)
            b.label:SetText(label)
            b.desc = UI:Text(b, 10, C.muted)
            b.desc:SetPoint("TOPLEFT", b.label, "BOTTOMLEFT", 0, -4)
            b.count = UI:Text(b, 11, C.warning)
            b.count:SetPoint("RIGHT", -10, 0)
            function b:Paint()
                local sel, played = self.selected, self.played ~= false
                self.bg:SetColor(unpack(sel and C.surface2 or C.hover))
                self.bg:SetShown(sel or self.hover)
                self.bar:SetShown(sel)
                self.barTex:SetColor(UI:Accent())
                if self.iconBg then self.iconBg:SetVertexColor(UI:Accent()) end
                self.label:SetTextColor(unpack((sel or self.hover) and C.text or (played and C.text or C.dim)))
                if class then
                    if self.icon.SetDesaturated then self.icon:SetDesaturated(not played) end
                    self.icon:SetAlpha(played and 1 or 0.45)
                end
                self.desc:SetTextColor(unpack(played and C.muted or C.dim))
            end
            b:SetScript("OnEnter", function(s) s.hover = true; s:Paint() end)
            b:SetScript("OnLeave", function(s) s.hover = false; s:Paint() end)
            b:SetScript("OnClick", function() self:ShowSection(key) end)
            UI:OnAccent(function() b:Paint() end)
            self.navButtons[key] = b
            return b
        end
        local gen = navButton("general", "Général", -8)
        gen.desc:SetText("Marchand, groupe, confort")
        local halo = navButton("halo", "Halo", -58, nil, "spark")
        halo.desc:SetText("L'objet visé brille")
        local micro = navButton("micro", "Micro menu", -108, nil, "menu")
        micro.desc:SetText("Horloge et raccourcis")
        local fishBtn = navButton("fishing", "Pêche", -158, nil, "fish")
        fishBtn.desc:SetText("Tenue, appâts, touche unique")
        local mapBtn = navButton("maplayers", "Carte et guidage", -208, nil, "map")
        mapBtn.desc:SetText("Lieux utiles et trajets")
        local ahBtn = navButton("ah", "Hôtel des ventes", -208, nil, "coin")
        ahBtn.desc:SetText("Scan et prix")
        local curBtn = navButton("cursor", "Curseur", -258, nil, "crosshair")
        curBtn.desc:SetText("Anneau, curseur en combat")
        local campBtn = navButton("campfire", "Feu de camp", -258, nil, "fire")
        campBtn.desc:SetText("S'asseoir près d'un camp")
        local xpBtn = navButton("xp", "Expérience", -258, nil, "chart")
        xpBtn.desc:SetText("Barre, repos, quêtes à rendre")
        local classesBtn = navButton("classes", "Classes", -258, nil, "users")
        classesBtn.desc:SetText("Réglages par classe")
        -- modules coupés (Core/Features.lua) : leur entrée disparaît, les autres se resserrent
        local NAV_ORDER = { "general", "halo", "micro", "maplayers", "cursor", "campfire", "xp", "classes" }
        function self:LayoutNav()
            local y = -8
            for _, k in ipairs(NAV_ORDER) do
                local b = self.navButtons[k]
                local fk = WK.FEATURE_BY_QOL[k]
                local on = not fk or WK:FeatureOn(fk)
                if b then
                    b:SetShown(on)
                    if on then
                        b:ClearAllPoints()
                        b:SetPoint("TOPLEFT", 8, y); b:SetPoint("TOPRIGHT", -8, y)
                        y = y - 50
                    end
                end
            end
            local cur = WK.DB.global.settings.ui.qolSection
            local fk = cur and WK.FEATURE_BY_QOL[cur]
            -- une section de classe (« HUNTER »…) dépend du module « classes »
            if not fk and isClass[cur or ""] then fk = "classes" end
            if fk and not WK:FeatureOn(fk) and self.ShowSection then self:ShowSection("general") end
        end

        -- Onglets des classes (en haut de la zone, quand « Classes » est choisi) ----------
        local classBar = UI:Card(host)
        classBar:SetPoint("TOPLEFT")
        classBar:SetPoint("TOPRIGHT")
        classBar:SetHeight(CLASSBAR_H - 8)
        classBar:Hide()
        self.classBar, self.classTabs = classBar, {}
        local tabList = {}
        local tabDefs = { { "CLASSGEN", "Général" } }
        for _, cl in ipairs(QoL.CLASSES) do table.insert(tabDefs, cl) end
        for _, cl in ipairs(tabDefs) do
            local key = cl[1]
            local t = CreateFrame("Button", nil, classBar)
            t:SetHeight(48)
            t.bg = UI:Rounded(t, 10, 0, "BACKGROUND", 1)
            if key == "CLASSGEN" then
                -- icône : les 9 logos de classe en mosaïque 3 × 3
                t.icon = CreateFrame("Frame", nil, t); t.icon:SetSize(24, 24)
                t.icon.parts = {}
                for i, c2 in ipairs(QoL.CLASSES) do
                    local part = t.icon:CreateTexture(nil, "ARTWORK")
                    part:SetSize(7.5, 7.5)
                    part:SetPoint("TOPLEFT", ((i - 1) % 3) * 8.25, -math.floor((i - 1) / 3) * 8.25)
                    UI:SetClassIcon(part, c2[1])
                    t.icon.parts[i] = part
                end
                t.icon.SetDesaturated = function(fr, v) for _, part in ipairs(fr.parts) do part:SetDesaturated(v) end end
                t.played = true
            else
                t.icon = UI:RoundIcon(t, 24)
                UI:SetClassIcon(t.icon, key)
            end
            t.icon:SetPoint("TOP", 0, -5)
            t.label = UI:Text(t, 10)
            t.label:SetPoint("TOP", t.icon, "BOTTOM", 0, -3)
            t.label:SetJustifyH("CENTER")
            t.label:SetText(T(cl[2]))
            t.line = CreateFrame("Frame", nil, t)
            t.line:SetHeight(2)
            t.line:SetPoint("BOTTOMLEFT", 10, 0)
            t.line:SetPoint("BOTTOMRIGHT", -10, 0)
            t.lineTex = UI:Rounded(t.line, 1, 0, "ARTWORK", 1)
            t.count = UI:Badge(t, "", C.warning)
            t.count:SetPoint("TOPRIGHT", -2, -2)
            t.count:Hide()
            function t:Paint()
                local sel, played = self.selected, self.played ~= false
                self.bg:SetColor(unpack(sel and C.surface2 or C.hover))
                self.bg:SetShown(sel or self.hover)
                self.line:SetShown(sel)
                self.lineTex:SetColor(UI:Accent())
                if self.icon.SetDesaturated then self.icon:SetDesaturated(not played) end
                self.icon:SetAlpha(played and 1 or 0.45)
                self.label:SetTextColor(unpack((sel or self.hover or played) and C.text or C.dim))
            end
            t:SetScript("OnEnter", function(s2)
                s2.hover = true; s2:Paint()
                WK.UI:TooltipOwner(s2, "ANCHOR_BOTTOM")
                GameTooltip:SetText(T(cl[2]), 1, 1, 1)
                if s2.tip then GameTooltip:AddLine(s2.tip, 0.8, 0.8, 0.8) end
                GameTooltip:Show()
            end)
            t:SetScript("OnLeave", function(s2) s2.hover = false; s2:Paint(); GameTooltip:Hide() end)
            t:SetScript("OnClick", function() self:ShowSection(key) end)
            UI:OnAccent(function() t:Paint() end)
            self.classTabs[key] = t
            table.insert(tabList, t)
        end
        -- les 9 onglets se partagent la largeur
        UI:OnResize(classBar, function(w)
            if not w or w <= 0 then return end
            local tw = (w - 12) / #tabList
            for i, t in ipairs(tabList) do
                t:ClearAllPoints()
                t:SetWidth(tw - 4)
                t:SetPoint("TOPLEFT", 6 + (i - 1) * tw + 2, -4)
            end
        end)

        -----------------------------------------------------------------------
        -- Général
        -----------------------------------------------------------------------
        section("general")
        local g = q.general

        subtab("Marchand")
        local shop = card("Marchand", 276)
        UI:SettingRow(shop, -40, "Réparation automatique", "Chez un marchand qui répare, tout l'équipement.",
            toggle(shop, function() return g.repair end, function(v) g.repair = v end), 80)
        UI:SettingRow(shop, -88, "Plafond de réparation", "Pas de réparation automatique au-delà (0 : sans limite).",
            UI:Slider(shop, 240, 0, 50, 1, function() return g.repairCap or 0 end, function(v) g.repairCap = v end, "%d po"), 260)
        UI:SettingRow(shop, -134, "Avec l'or de la guilde d'abord", "Si la guilde le permet.",
            toggle(shop, function() return g.repairGuild end, function(v) g.repairGuild = v end), 80)
        UI:SettingRow(shop, -178, "Vendre les objets gris", "Le total gagné est écrit dans le chat.",
            toggle(shop, function() return g.sellGrey end, function(v) g.sellGrey = v end), 80)
        UI:SettingRow(shop, -226, "Fermer la fenêtre après la réparation", "Après la vente des gris et les achats automatiques. Maj enfoncée en parlant au marchand : elle reste ouverte.",
            toggle(shop, function() return g.closeAfterRepair end, function(v) g.closeAfterRepair = v end), 80)

        -- barre à l'écran sacs / marchand / maître (UI/BagHelp.lua, HUD bagSpace) : un seul endroit pour ses réglages
        do
            local bcfg = WK.modules.BagHelp:Config()
            local function bref() if UI.RefreshBagSpace then UI:RefreshBagSpace() end end
            local bar = card("Barre sacs, marchand et maître", 40 + 12 * 46 + 3 * 22 + 8,
                "tous ses réglages ici ; position en mode édition")
            local hud = function() return UI:HUDEntry("bagSpace") end
            local function happly() if UI.HUDApply then UI:HUDApply("bagSpace") end; bref() end
            local campCfg0 = WK.modules.Camp:Config()
            local SB = WK.modules.SelfBuffs
            local function lists()
                bref()
                if UI.RefreshCampKit then UI:RefreshCampKit() end
                if UI.RefreshSelfBuffs then UI:RefreshSelfBuffs() end
            end
            local yy = -40
            local function head(txt)
                local h = UI:Text(bar, 10, C.dim)
                h:SetPoint("TOPLEFT", 16, yy - 4)
                h:SetText(string.upper(T(txt)))
                yy = yy - 22
            end
            local function row(name, desc, ctrl, w)
                UI:SettingRow(bar, yy, name, desc, ctrl, w)
                yy = yy - 46
            end
            head("Apparence")
            row("Taille", "Taille de toute la barre (la même que le curseur du mode édition).",
                UI:Slider(bar, 220, 0.5, 2, 0.05, function() return hud().scale or 1 end,
                    function(v) hud().scale = v; happly() end, "%.2fx"), 240)
            row("Opacité", "Transparence de toute la barre.",
                UI:Slider(bar, 220, 0.3, 1, 0.05, function() return hud().alpha or 1 end,
                    function(v) hud().alpha = v; happly() end, "%.2f"), 240)
            row("Fond", "Sans fond : seulement les icônes et les chiffres, cernés de noir pour rester lisibles.",
                toggle(bar, function() return bcfg.barBg ~= false end, function(v) bcfg.barBg = v; bref() end), 80)
            row("Traits entre les cases", "Un trait fin sépare deux cases.",
                toggle(bar, function() return bcfg.barSeps ~= false end, function(v) bcfg.barSeps = v; bref() end), 80)
            head("Cases")
            row("Afficher la barre", "Cases libres (clic : jeter le gris le moins cher), marchand et maître de classe"
                    .. " les plus proches (clic : guider). Rouge quand c'est pressé.",
                toggle(bar, function() return bcfg.space end, function(v) bcfg.space = v; bref() end), 80)
            row("Seuil de cases libres", "En dessous, le sac passe en orange et le marchand en rouge.",
                UI:Slider(bar, 220, 0, 12, 1, function() return bcfg.low or 3 end, function(v) bcfg.low = v; bref() end, "%d"), 240)
            row("Case du marchand", "Clic droit : le forgeron le plus proche, pour réparer.",
                toggle(bar, function() return bcfg.vendorTile ~= false end, function(v) bcfg.vendorTile = v; bref() end), 80)
            row("Case du maître de classe", "Le nombre de sorts à apprendre, sinon la distance.",
                toggle(bar, function() return bcfg.trainerTile ~= false end, function(v) bcfg.trainerTile = v; bref() end), 80)
            row("Case du kit de camp", "Temps restant des avantages du camp ; un clic déroule le kit (hors combat)."
                    .. " Coupée : colonne près de la flamme. Contenu du kit : QoL > Feu de camp.",
                toggle(bar, function() return campCfg0.kitInBar ~= false end, function(v)
                    campCfg0.kitInBar = v
                    if WK.modules.Camp.Update then pcall(WK.modules.Camp.Update, WK.modules.Camp) end
                    if UI.RefreshCampChips then UI:RefreshCampChips() end
                    lists()
                end), 80)
            row("Case des buffs", "Buffs absents selon le lieu ; un clic déroule la liste, un clic sur une ligne lance"
                    .. " le sort (hors combat). Buffs et lieux : QoL > Classes > Général.",
                toggle(bar, function() return SB:Config().bar end, function(v) SB:Config().bar = v; lists() end), 80)
            row("Mettre en avant un buff absent", "Fond rouge et liseré qui respire sur la case des buffs tant qu'il en"
                    .. " manque un (hors combat et hors des villes).",
                toggle(bar, function() return bcfg.buffAlert ~= false end,
                    function(v) bcfg.buffAlert = v; bref() end), 80)
            head("Listes déroulées")
            local dseg = UI:Segmented(bar, { { "down", "Vers le bas" }, { "up", "Vers le haut" } },
                function(v) bcfg.dir = v; lists() end, 24)
            row("Sens des listes", "Le kit de camp et les buffs s'ouvrent sous la barre ou au-dessus.", dseg, 200)
            dseg:Select(bcfg.dir == "up" and "up" or "down")
        end

        -- État des persos : seuils puis une ligne par perso
        local chars = UI:SortedCharacters()
        subtab("Alertes")
        local state = card("État des persos", 172 + #chars * 30)
        UI:SettingRow(state, -40, "Alerte de durabilité", "Quand la pièce la plus abîmée passe sous ce seuil (0 : pas d'alerte).",
            UI:Slider(state, 240, 0, 90, 5, function() return g.durability or 0 end, function(v) g.durability = v; WK:NotifyChanged() end, "%d %%"), 260)
        UI:SettingRow(state, -88, "Sacs et banque presque pleins", "Quand il reste moins de places libres que ça (0 : pas d'alerte). La banque est relevée à chaque visite.",
            UI:Slider(state, 240, 0, 20, 1, function() return g.freeSlots or 0 end, function(v) g.freeSlots = v; WK:NotifyChanged() end, "%d"), 260)
        local hdrY = -142
        local h1 = UI:Text(state, 10, C.dim); h1:SetPoint("TOPLEFT", 16, hdrY); h1:SetText("PERSO")
        local h2 = UI:Text(state, 10, C.dim); h2:SetPoint("TOPRIGHT", -210, hdrY); h2:SetText("DURABILITÉ")
        local h3 = UI:Text(state, 10, C.dim); h3:SetPoint("TOPRIGHT", -16, hdrY); h3:SetText("SACS · BANQUE")
        -- Lignes gardées pour suivre les persos supprimés ou renommés (bloc : limite de 200 locales).
        do
            local rows = {}
            local function place(r, ry)
                r.icon:ClearAllPoints(); r.icon:SetPoint("TOPLEFT", 16, ry)
                r.name:ClearAllPoints(); r.name:SetPoint("TOPLEFT", 42, ry - 2)
                r.dur:ClearAllPoints(); r.dur:SetPoint("TOPRIGHT", -210, ry - 2)
                r.slots:ClearAllPoints(); r.slots:SetPoint("TOPRIGHT", -16, ry - 2)
            end
            for i, e in ipairs(chars) do
                local r = { key = e.key }
                r.icon = UI:RoundIcon(state, 18)
                UI:SetCharIcon(r.icon, e.c, e.key)
                r.name = UI:Text(state, 12, classColor(e.c.class))
                r.name:SetText(WK:CharName(e.c, e.key))
                r.dur = dynText(state, 12, C.text, function(t)
                    local d = e.c.durability
                    t:SetTextColor(unpack((d and d < (g.durability or 0)) and C.negative or C.text))
                    return d and (d .. " %") or "-"
                end)
                r.slots = dynText(state, 12, C.text, function(t)
                    local f = e.c.freeSlots
                    local bf = e.c.bankFree
                    local warn = (f and f < (g.freeSlots or 0)) or (bf and bf < (g.freeSlots or 0))
                    t:SetTextColor(unpack(warn and C.warning or C.text))
                    return (f and string.format("%d / %d", f, e.c.totalSlots or 0) or "-") .. "  ·  "
                        .. (bf and string.format("%d / %d", bf, e.c.bankSlots or 0) or "-")
                end)
                place(r, hdrY - 18 - (i - 1) * 30)
                table.insert(rows, r)
            end
            -- perso supprimé : sa ligne disparaît et les suivantes remontent ; nom renommé à jour
            table.insert(self.dyn, function()
                local i = 0
                for _, r in ipairs(rows) do
                    local c = WK.DB.global.characters[r.key]
                    r.icon:SetShown(c ~= nil); r.name:SetShown(c ~= nil)
                    r.dur:SetShown(c ~= nil); r.slots:SetShown(c ~= nil)
                    if c then
                        r.name:SetText(WK:CharName(c, r.key))
                        place(r, hdrY - 18 - i * 30)
                        i = i + 1
                    end
                end
            end)
        end

        subtab("Groupe et confort")
        local grp = card("Groupe et duels", 184)
        UI:SettingRow(grp, -40, "Accepter les invitations", "De tes amis et des membres de ta guilde.",
            toggle(grp, function() return g.acceptInvites end, function(v) g.acceptInvites = v end), 80)
        UI:SettingRow(grp, -88, "Refuser les duels", nil,
            toggle(grp, function() return g.declineDuels end, function(v) g.declineDuels = v end), 80)
        UI:SettingRow(grp, -130, "Sauf ceux des amis et de la guilde", nil,
            toggle(grp, function() return g.duelFriends end, function(v) g.duelFriends = v end), 80)

        local comfort = card("Confort", 232)
        UI:SettingRow(comfort, -40, "Libérer l'esprit en champ de bataille", "Automatiquement à la mort (pas avec une pierre d'âme).",
            toggle(comfort, function() return g.releaseBG end, function(v) g.releaseBG = v end), 80)
        UI:SettingRow(comfort, -88, "Confirmer le butin lié quand ramassé", "Seulement quand tu es seul.",
            toggle(comfort, function() return g.confirmBoP end, function(v) g.confirmBoP = v end), 80)
        UI:SettingRow(comfort, -136, "Descendre de monture ou se lever", "Quand une action l'exige (sort, maître de vol, butin…).",
            toggle(comfort, function() return g.dismount end, function(v) g.dismount = v end), 80)
        UI:SettingRow(comfort, -184, "Passer les cinématiques", nil,
            toggle(comfort, function() return g.skipCinematics end, function(v) g.skipCinematics = v end), 80)

        -----------------------------------------------------------------------
        -- Alertes : les seuils et rappels d'Options (banque, courrier, rappels à la connexion) rejoignent
        -- l'onglet Alertes, sous l'état des persos (un seul endroit pour toutes les alertes).
        subtab("Alertes")
        for _, oc in ipairs(UI:SectionCards("options", "alerts")) do
            oc:SetParent(root); oc:ClearAllPoints()
            oc:SetPoint("TOPLEFT", 0, -y); oc:SetPoint("TOPRIGHT", 0, -y)
            y = y + oc:GetHeight() + GAP
        end

        -- Halo : l'objet visé (plante, filon, coffre, flotteur…) brille (Modules/Glow.lua)
        -----------------------------------------------------------------------
        section("halo")
        local Gm = WK.modules.Glow
        local gcfg = Gm:Config()
        local gtoggle = toggle
        local haloPaint -- aperçu de l'atelier, repeint quand l'effet global change
        -- Atelier : une catégorie à la fois (pastilles), aperçu en direct à gauche, réglages à droite
        local CAT_ICON = {
            ore = "Interface\\Icons\\INV_Ore_Copper_01", herb = "Interface\\Icons\\INV_Misc_Flower_02",
            quest = "Interface\\Icons\\INV_Misc_Note_01", chest = "Interface\\Icons\\INV_Box_01",
            bobber = "Interface\\Icons\\INV_Fishingpole_02", skin = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
            loot = "Interface\\Icons\\INV_Misc_Bag_10", giver = "Interface\\Icons\\INV_Misc_Head_Human_01",
            other = "Interface\\Icons\\INV_Misc_Gear_01",
        }
        local SAMPLE = { ore = { "Filon de cuivre", 65, "Minage", "optimal" }, herb = { "Pacifique", 1, "Herboristerie", "medium" },
                         skin = { "Loup des bois", 50, "Dépeçage", "easy" }, giver = { "Maréchal Dughan" } }
        local SWATCHES = { { 1, 0.6, 0.18 }, { 1, 0.84, 0.15 }, { 0.4, 1, 0.42 }, { 0.45, 0.78, 1 }, { 0.79, 0.71, 0.93 },
                           { 1, 0.45, 0.4 }, { 0.96, 0.55, 0.73 }, { 0.95, 0.95, 0.95 } }
        local STAGE_H = 230
        local acard = card("Atelier", 40 + 3 * 32 + 8 + STAGE_H + 16, "une catégorie à la fois : effet, couleur et aperçu")
        local selCat = ui.haloCat or "ore"
        local chips = {}
        for _, key in ipairs(Gm.CATEGORIES) do
            local b = CreateFrame("Button", nil, acard)
            b:SetHeight(26)
            b.edge = UI:Rounded(b, 13, 0, "BACKGROUND", 0)
            b.bg = UI:Rounded(b, 12, 1, "BACKGROUND", 1)
            b.dot = UI:Icon(b, "circle", 10, nil, "ARTWORK")
            b.dot:SetPoint("LEFT", 9, 0)
            b.label = UI:Text(b, 11)
            b.label:SetPoint("LEFT", 24, 0)
            b.label:SetText(T(Gm.LABELS[key]))
            b:SetWidth(math.floor((b.label:GetStringWidth() or 80) + 36))
            b.key = key
            b:SetScript("OnClick", function() selCat = key; ui.haloCat = key; haloPaint() end)
            table.insert(chips, b)
        end
        local stage, right
        local function layoutChips(w)
            w = (w and w > 100) and w or 600
            local x, y = 16, -40
            for _, b in ipairs(chips) do
                local bw = b:GetWidth()
                if x + bw > w - 16 then x, y = 16, y - 32 end
                b:ClearAllPoints(); b:SetPoint("TOPLEFT", x, y)
                x = x + bw + 6
            end
            -- aperçu et réglages sous la dernière ligne de pastilles (la carte garde la place de trois lignes)
            if stage then
                local top = -y + 32 + 8
                stage:ClearAllPoints(); stage:SetPoint("TOPLEFT", 16, -top)
                right:ClearAllPoints()
                right:SetPoint("TOPLEFT", stage, "TOPRIGHT", 0, 0)
                right:SetPoint("TOPRIGHT", acard, "TOPRIGHT", 0, -top)
            end
        end
        stage = CreateFrame("Frame", nil, acard)
        stage:SetPoint("TOPLEFT", 16, -(40 + 3 * 32 + 8))
        stage:SetSize(260, STAGE_H)
        stage.bg = UI:Rounded(stage, 12, 0, "BACKGROUND", 1)
        stage.bg:SetColor(unpack(C.inset))
        stage.icon = UI:RoundIcon(stage, 34)
        stage.icon:SetPoint("BOTTOM", 0, 62)
        stage.fx = Gm.NewFx(stage)
        stage.fx:SetPoint("CENTER", stage.icon, "CENTER")
        stage.fx.inRange = true
        stage.info = UI:Text(stage, 11)
        stage.info:SetPoint("TOP", stage.icon, "BOTTOM", 0, -18)
        stage.off = UI:Text(stage, 11, C.muted)
        stage.off:SetPoint("TOP", 0, -14)
        if stage.SetClipsChildren then stage:SetClipsChildren(true) end
        -- réglages de la catégorie choisie
        right = CreateFrame("Frame", nil, acard)
        right:SetPoint("TOPLEFT", stage, "TOPRIGHT", 0, 0)
        right:SetPoint("TOPRIGHT", acard, "TOPRIGHT", 0, -(40 + 3 * 32 + 8))
        right:SetHeight(STAGE_H)
        local catToggle = gtoggle(right, function() return gcfg.cats[selCat] end, function(v) gcfg.cats[selCat] = v; Gm:Update(); haloPaint() end)
        UI:SettingRow(right, 0, "Halo sur cette catégorie", nil, catToggle, 60)
        local catOpts = { { "", T("Comme les autres") } }
        for _, st in ipairs(Gm.STYLES) do table.insert(catOpts, { st[1], T(st[2]) }) end
        local catFx = UI:Dropdown(right, 200, 28, catOpts, function(v) gcfg.fx[selCat] = (v ~= "" and v) or nil; Gm:Update(); haloPaint() end)
        UI:SettingRow(right, -40, "Effet", nil, catFx, 210)
        local swRow = CreateFrame("Frame", nil, right)
        swRow:SetSize(8 * 26 + 30, 24)
        local swatches = {}
        for i, col in ipairs(SWATCHES) do
            local sb = CreateFrame("Button", nil, swRow)
            sb:SetSize(22, 22)
            sb:SetPoint("LEFT", (i - 1) * 26, 0)
            sb.ring = UI:Rounded(sb, 8, 0, "BACKGROUND", 0)
            sb.fill = UI:Rounded(sb, 6, 2, "BACKGROUND", 1)
            sb.fill:SetColor(col[1], col[2], col[3], 1)
            sb.col = col
            sb:SetScript("OnClick", function() gcfg.colors[selCat] = { col[1], col[2], col[3] }; Gm:Update(); haloPaint() end)
            swatches[i] = sb
        end
        local pick = UI:IconButton(swRow, "plus", 22)
        pick:SetPoint("LEFT", 8 * 26, 0)
        pick:SetScript("OnClick", function()
            local c0 = gcfg.colors[selCat]
            UI:PickColor(c0[1], c0[2], c0[3], function(r, g, b) gcfg.colors[selCat] = { r, g, b }; Gm:Update(); haloPaint() end)
        end)
        UI:SettingRow(right, -84, "Couleur", nil, swRow, 8 * 26 + 30)
        local diffToggle = gtoggle(right, function() return gcfg.diffColor end, function(v) gcfg.diffColor = v; Gm:Update(); haloPaint() end)
        local diffRow = UI:SettingRow(right, -126, "Texte selon la difficulté", "Filons, plantes et dépeçage : le nom sous l'objet en orange, jaune, vert, gris (rouge si la compétence manque). Le halo garde ta couleur.", diffToggle, 60)
        -- donneurs de quêtes : à la même place, seulement les quêtes du journal
        local giverToggle = gtoggle(right, function() return gcfg.giverLog end, function(v) gcfg.giverLog = v; Gm:Update(); haloPaint() end)
        local giverRow = UI:SettingRow(right, -126, "Seulement les quêtes de ton journal", "Le PNJ où rendre une quête de ton journal, ou lié à une quête en cours ; pas ceux qui proposent une nouvelle quête.", giverToggle, 60)
        local infoToggle = gtoggle(right, function() return gcfg.info end, function(v) gcfg.info = v; Gm:Update(); haloPaint() end)
        UI:SettingRow(right, -180, "Ligne d'info sous l'objet", "Nom et compétence demandée.", infoToggle, 60)

        haloPaint = function()
            local r1, g1, b1 = UI:Accent()
            for _, b in ipairs(chips) do
                local on, sel = gcfg.cats[b.key], b.key == selCat
                local col = gcfg.colors[b.key]
                b.dot:SetVertexColor(col[1], col[2], col[3])
                b.edge:SetColor(unpack(sel and { r1, g1, b1, 1 } or C.border))
                b.bg:SetColor(unpack(sel and C.surface2 or C.surface))
                b.label:SetTextColor(unpack(sel and C.text or (on and C.muted or C.dim)))
                b:SetAlpha(on and 1 or 0.55)
            end
            local col = gcfg.colors[selCat]
            local sample = SAMPLE[selCat]
            local diffable = selCat == "ore" or selCat == "herb" or selCat == "skin"
            local shown = col -- texte : couleur de difficulté ; halo : couleur choisie
            if diffable and gcfg.diffColor and sample then shown = Gm.DIFF_COLORS[sample[4]] end
            stage.icon:SetTexture(CAT_ICON[selCat])
            stage.fx:Set(gcfg.fx[selCat] or gcfg.style or "halo", col, 110, (gcfg.intensity or 100) / 100, 2.2)
            stage.fx:SetShown(gcfg.cats[selCat] and true or false)
            stage.off:SetText(gcfg.cats[selCat] and "" or T("catégorie coupée"))
            local info = ""
            if gcfg.info and sample then
                info = sample[2] and (T(sample[1]) .. "  ·  " .. T(sample[3]) .. " " .. sample[2]) or T(sample[1])
            end
            stage.info:SetText(info)
            stage.info:SetTextColor(shown[1], shown[2], shown[3])
            catToggle:Refresh(); diffToggle:Refresh(); infoToggle:Refresh(); giverToggle:Refresh()
            catFx:Select(gcfg.fx[selCat] or "")
            for _, sb in ipairs(swatches) do
                local same = math.abs(sb.col[1] - col[1]) < 0.02 and math.abs(sb.col[2] - col[2]) < 0.02 and math.abs(sb.col[3] - col[3]) < 0.02
                sb.ring:SetColor(1, 1, 1, same and 1 or 0)
            end
            diffRow:SetAlpha(diffable and 1 or 0.4)
            diffRow:SetShown(selCat ~= "giver"); giverRow:SetShown(selCat == "giver")
        end
        UI:OnResize(acard, function(w) layoutChips(w) end)
        layoutChips(acard:GetWidth())
        table.insert(self.dyn, function() haloPaint() end)
        haloPaint()


        local gmain = card("Halo", 354)
        UI:SettingRow(gmain, -40, "Halo sur l'objet visé",
            "Plantes, filons, coffres, objets de quête et flotteur brillent à ton approche. À éteindre avant de désinstaller l'addon.",
            gtoggle(gmain, function() return gcfg.enabled end, function(v) Gm:SetEnabled(v) end), 80)
        UI:SettingRow(gmain, -92, "Portée", "Distance à laquelle le jeu désigne un objet (15 m au plus). Le mode pêche la monte à 60 m le temps de pêcher, puis la rend.",
            UI:Slider(gmain, 240, 5, 15, 1, function() return gcfg.range or 15 end,
                function(v) gcfg.range = v; if gcfg.enabled then Gm:ApplyCVars() end end, "%d m"), 260)
        UI:SettingRow(gmain, -138, "Taille", "Taille du halo.",
            UI:Slider(gmain, 240, 60, 220, 10, function() return gcfg.size or 110 end, function(v) gcfg.size = v end, "%d"), 260)
        UI:SettingRow(gmain, -184, "Intensité", "Luminosité du halo.",
            UI:Slider(gmain, 240, 30, 150, 10, function() return gcfg.intensity or 100 end, function(v) gcfg.intensity = v end, "%d %%"), 260)
        local styleOpts = {}
        for _, st in ipairs(Gm.STYLES) do table.insert(styleOpts, { st[1], T(st[2]) }) end
        local fxDd = UI:Dropdown(gmain, 220, 30, styleOpts, function(v) gcfg.style = v; Gm:Update(); if haloPaint then haloPaint() end end)
        fxDd:Select(gcfg.style or "halo")
        UI:SettingRow(gmain, -230, "Effet", "Pour toutes les catégories ; chacune peut avoir le sien dans l'atelier.", fxDd, 240)
        UI:SettingRow(gmain, -276, "Hauteur de la colonne", "En multiples de la taille du halo.",
            UI:Slider(gmain, 240, 2, 10, 0.5, function() return gcfg.beamHeight or 4.5 end, function(v) gcfg.beamHeight = v end, "%.1fx"), 260)
        local diag = UI:Text(gmain, 11, C.muted)
        diag:SetPoint("TOPLEFT", 16, -326)
        diag:SetPoint("TOPRIGHT", -16, -326)
        diag:SetJustifyH("LEFT")
        diag:SetText(T("Pour comprendre pourquoi un objet ne brille pas : approche-toi de lui et tape /wk halo."))
        local glowNote = dynText(gmain, 11, C.warning, function()
            return WK.modules.Glow:OtherAddonLoaded() and T("L'addon Lueur est chargé : il s'en occupe, le halo reste éteint.") or ""
        end)
        glowNote:SetPoint("TOPLEFT", 16, -16)
        glowNote:SetPoint("TOPRIGHT", -16, -16)
        glowNote:SetJustifyH("RIGHT")

        local ghide = card("Quand ne pas l'afficher", 184)
        UI:SettingRow(ghide, -40, "Seulement si le perso a le métier", "Pas de halo sur une plante sans Herboristerie, ni sur un filon sans Minage.",
            gtoggle(ghide, function() return gcfg.onlyTrained ~= false end, function(v) gcfg.onlyTrained = v; Gm:Update() end), 80)
        UI:SettingRow(ghide, -88, "Pas en combat", nil,
            gtoggle(ghide, function() return gcfg.hideInCombat end, function(v) gcfg.hideInCombat = v; Gm:Update() end), 80)
        UI:SettingRow(ghide, -130, "Pas en donjon, raid ou champ de bataille", nil,
            gtoggle(ghide, function() return gcfg.hideInInstance end, function(v) gcfg.hideInInstance = v; Gm:Update() end), 80)

        -----------------------------------------------------------------------
        -- Micro menu : horloge et raccourcis (UI/ClockBar.lua)
        -----------------------------------------------------------------------
        section("micro")
        local ck = UI.ClockConfig()
        local SC = UI.CLOCK_SHORTCUTS
        local clockCard = card("Horloge et raccourcis", 40 + 9 * 46 + 30 + 128, "les raccourcis se déplient au survol de l'heure")
        -- survol de l'heure : addons et mémoire (UI/ClockBar.lua)
        do
            local pc = card("Survol de l'heure", 40 + 8 * 46 + 8, "addons, mémoire, FPS et latence")
            local py = -40
            local function prow(label, desc, ctl, w) UI:SettingRow(pc, py, label, desc, ctl, w); py = py - 46 end
            prow("Addons et mémoire au survol", "Au survol de l'heure : les addons les plus gourmands et la mémoire de tous (relue à chaque survol).",
                toggle(pc, function() return ck.perf ~= false end, function(v) ck.perf = v end), 80)
            local st = UI:Segmented(pc, { { "simple", "Simple" }, { "bars", "Barres" } }, function(v) ck.perfStyle = v end, 26)
            st:Select(ck.perfStyle or "bars")
            prow("Style", "Simple : texte dans l'infobulle. Barres : panneau avec FPS, latence, mémoire et une barre par addon.", st, 180)
            local nb = UI:Segmented(pc, { { 5, "5" }, { 8, "8" }, { 12, "12" }, { 0, "Tous" } }, function(v) ck.perfCount = v end, 26)
            nb:Select(ck.perfCount or 8)
            prow("Nombre d'addons", "Les autres sont regroupés en une ligne.", nb, 220)
            local so = UI:Segmented(pc, { { "mem", "Mémoire" }, { "cpu", "Processeur" }, { "name", "Nom" } }, function(v) ck.perfSort = v end, 26)
            so:Select(ck.perfSort or "mem")
            prow("Trier par", "Le processeur seulement si le profilage du jeu est actif (il ralentit un peu le jeu).", so, 270)
            prow("FPS et latence", "En tête du panneau.", toggle(pc, function() return ck.perfFps ~= false end, function(v) ck.perfFps = v end), 80)
            prow("Hausse depuis la connexion", "Combien la mémoire des addons a grossi depuis ton arrivée.",
                toggle(pc, function() return ck.perfDelta ~= false end, function(v) ck.perfDelta = v end), 80)
            local wa = UI:Segmented(pc, { { 20, "20 Mo" }, { 50, "50 Mo" }, { 100, "100 Mo" } }, function(v) ck.perfWarn = v end, 26)
            wa:Select(ck.perfWarn or 50)
            prow("Seuil d'alerte", "Un addon au-dessus passe en orange.", wa, 240)
            prow("Clic droit sur l'heure : libérer la mémoire", "Nettoie la mémoire inutilisée des addons (hors combat).",
                toggle(pc, function() return ck.perfGC end, function(v) ck.perfGC = v end), 80)
        end
        -- en haut : les raccourcis (barre telle qu'à l'écran) ; les réglages en dessous
        local TOPBOX = 40 + 26 + 56 + 8 + 34 + 26
        local cy = -TOPBOX
        local function crow(label, desc, ctl, w) UI:SettingRow(clockCard, cy, label, desc, ctl, w); cy = cy - 46 end
        local function csync() UI:SyncClock() end
        crow("Afficher le micro menu", "Barre en haut de l'écran (horloge et raccourcis) ; se place en mode édition.",
            toggle(clockCard, function() return ck.enabled end, function(v) ck.enabled = v; csync() end), 80)
        crow("Horloge toujours affichée", "Sinon, elle apparaît au survol de son emplacement.",
            toggle(clockCard, function() return ck.clockAlways ~= false end, function(v) ck.clockAlways = v; csync() end), 80)
        crow("Raccourcis toujours affichés", "Sinon, ils se déplient au survol de l'heure.",
            toggle(clockCard, function() return ck.always end, function(v) ck.always = v; csync() end), 80)
        local segSrv = UI:Segmented(clockCard, { { false, "Locale" }, { true, "Serveur" } }, function(v) ck.server = v end, 26)
        segSrv:Select(ck.server and true or false)
        crow("Heure", nil, segSrv, 200)
        local segFmt = UI:Segmented(clockCard, { { false, "24 h" }, { true, "12 h" } }, function(v) ck.h12 = v end, 26)
        segFmt:Select(ck.h12 and true or false)
        crow("Format", nil, segFmt, 160)
        crow("Taille", "Taille des raccourcis et de l'heure (le fond suit).",
            UI:Slider(clockCard, 220, 20, 48, 2, function() return ck.size or 28 end,
                function(v) ck.size = v; csync() end, "%d px"), 240)
        local fontOpts = {}
        for _, f in ipairs(UI.CLOCK_FONTS) do table.insert(fontOpts, { f[1], T(f[2]) }) end
        local fontDd = UI:Dropdown(clockCard, 220, 30, fontOpts, function(v) ck.timeFont = v; csync() end)
        fontDd:Select(ck.timeFont or "ui")
        crow("Police de l'heure", "Indépendante de la police de l'interface.", fontDd, 220)
        crow("Taille de l'heure", "0 : suit la taille des raccourcis.",
            UI:Slider(clockCard, 220, 0, 40, 1, function() return ck.timeSize or 0 end,
                function(v) ck.timeSize = v; csync() end, "%d"), 240)
        crow("Heure en gras", nil,
            toggle(clockCard, function() return ck.bold end, function(v) ck.bold = v; csync() end), 80)
        -- Raccourcis : la barre telle qu'à l'écran. Clic : gauche > droite > masqué ;
        -- Maj + clic gauche / droit : décaler d'un cran ; clic droit : masquer.
        local hdr = UI:Text(clockCard, 10, C.dim)
        hdr:SetPoint("TOPLEFT", 16, -46)
        hdr:SetText(T("RACCOURCIS") .. "  ·  " .. T("glisser-déposer pour les ranger, ou les masquer en bas"))
        local box = CreateFrame("Frame", nil, clockCard)
        box:SetPoint("TOPLEFT", 16, -66)
        box:SetPoint("TOPRIGHT", -16, -66)
        box:SetHeight(56)
        box.bg = UI:Rounded(box, 12, 0, "BACKGROUND", 1)
        box.bg:SetColor(unpack(C.inset))
        UI.settingIndex = UI.settingIndex or {}
        table.insert(UI.settingIndex, { row = box, label = "Raccourcis du micro menu", desc = "Gauche, droite, masqué, ordre." })
        local hid = CreateFrame("Frame", nil, clockCard)
        hid:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -8)
        hid:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", 0, -8)
        hid:SetHeight(34)
        local hl = UI:Text(hid, 10, C.dim)
        hl:SetPoint("LEFT", 4, 0)
        hl:SetText(T("MASQUÉS"))
        local hint = UI:Text(clockCard, 10, C.muted)
        hint:SetPoint("TOPLEFT", hid, "BOTTOMLEFT", 4, -6)
        hint:SetText(T("Clic : gauche > droite > masqué  ·  Maj + clic gauche ou droit : décaler d'un cran  ·  clic droit : masquer"))
        local clockTxt = UI:Text(box, 18)
        local sepL = box:CreateTexture(nil, "ARTWORK"); sepL:SetSize(1, 26)
        local sepR = box:CreateTexture(nil, "ARTWORK"); sepR:SetSize(1, 26)
        local SZ, IG = 32, 4
        local btns = {}
        local function sideText(k)
            local sd = ck.side[k]
            return sd == "L" and T("à gauche") or sd == "R" and T("à droite") or T("masqué")
        end
        local function nextText(k)
            local sd = ck.side[k]
            return sd == "L" and T("clic : à droite") or sd == "R" and T("clic : masquer") or T("clic : à gauche")
        end
        local layoutBar
        for _, def in ipairs(SC) do
            local b = CreateFrame("Button", nil, box)
            b:SetSize(SZ, SZ)
            b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            b.edge = UI:Rounded(b, 9, 0, "BACKGROUND", 1)
            b.tex = b:CreateTexture(nil, "ARTWORK")
            b.tex:SetSize(18, 18)
            b.tex:SetPoint("CENTER")
            b.def = def
            b:SetScript("OnClick", function(_, button)
                if IsShiftKeyDown() then
                    UI:ClockMove(def.key, button == "RightButton" and 1 or -1)
                elseif button == "RightButton" then
                    UI:ClockHide(def.key)
                else
                    UI:ClockCycle(def.key)
                end
                layoutBar()
                if GameTooltip:IsOwned(b) then b:GetScript("OnEnter")(b) end
            end)
            b:SetScript("OnEnter", function(s2)
                local ar, ag, ab = UI:Accent(); s2.edge:SetColor(ar, ag, ab, 1)
                WK.UI:TooltipOwner(s2, "ANCHOR_BOTTOM")
                GameTooltip:SetText(T(def.label), 1, 1, 1)
                GameTooltip:AddLine(sideText(def.key) .. "  ·  " .. nextText(def.key), 0.6, 0.6, 0.6)
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function(s2) s2.hover = nil; if not s2.dragging then layoutBar() end; GameTooltip:Hide() end)
            -- glisser-déposer : l'icône suit la souris ; lâchée sur la barre, elle se range à cet endroit
            -- (à gauche ou à droite de l'heure) ; lâchée sur « Masqués », elle est masquée
            b:RegisterForDrag("LeftButton")
            b:SetScript("OnDragStart", function(s2)
                s2.dragging = true
                GameTooltip:Hide()
                s2:SetParent(clockCard)
                s2:SetFrameLevel(clockCard:GetFrameLevel() + 20)
                s2:SetScript("OnUpdate", function(s3)
                    local cx, cyy = GetCursorPosition()
                    local sc = s3:GetEffectiveScale()
                    s3:ClearAllPoints()
                    s3:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx / sc, cyy / sc)
                end)
            end)
            b:SetScript("OnDragStop", function(s2)
                s2:SetScript("OnUpdate", nil)
                s2.dragging = nil
                local cx = GetCursorPosition() / box:GetEffectiveScale()
                if hid:IsMouseOver() then
                    UI:ClockHide(def.key)
                elseif box:IsMouseOver(10, -10, 0, 0) then
                    local VL, VR = UI.ClockVisual("L"), UI.ClockVisual("R")
                    local function drop(t) for i = #t, 1, -1 do if t[i] == def.key then table.remove(t, i) end end end
                    drop(VL); drop(VR)
                    local mid = clockTxt:GetLeft() and (clockTxt:GetLeft() + clockTxt:GetRight()) / 2 or (box:GetLeft() + box:GetRight()) / 2
                    local list = cx < mid and VL or VR
                    local pos = #list + 1
                    for i, k in ipairs(list) do
                        local o = btns[k]
                        local ox = o:GetLeft() and (o:GetLeft() + o:GetRight()) / 2
                        if ox and cx < ox then pos = i break end
                    end
                    table.insert(list, pos, def.key)
                    UI:ClockSetLayout(VL, VR)
                end
                layoutBar()
            end)
            btns[def.key] = b
        end
        layoutBar = function()
            local VL, VR = UI.ClockVisual("L"), UI.ClockVisual("R")
            local W = box:GetWidth() or 600
            if W < 100 then W = 600 end
            clockTxt:SetText(date(ck.h12 and "%I:%M" or "%H:%M"))
            clockTxt:SetTextColor(UI:Accent())
            sepL:SetColorTexture(unpack(C.border)); sepR:SetColorTexture(unpack(C.border))
            local cw = 80
            local total = #VL * (SZ + IG) + #VR * (SZ + IG) + cw + 24
            local x = math.floor((W - total) / 2)
            for _, k in ipairs(VL) do
                local b = btns[k]
                b:ClearAllPoints(); b:SetParent(box); b:SetPoint("LEFT", box, "LEFT", x, 0); x = x + SZ + IG
            end
            sepL:ClearAllPoints(); sepL:SetPoint("LEFT", box, "LEFT", x + 6, 0)
            clockTxt:ClearAllPoints(); clockTxt:SetPoint("CENTER", box, "LEFT", x + 12 + cw / 2, 0)
            sepR:ClearAllPoints(); sepR:SetPoint("LEFT", box, "LEFT", x + 18 + cw, 0)
            x = x + cw + 24
            for _, k in ipairs(VR) do
                local b = btns[k]
                b:ClearAllPoints(); b:SetParent(box); b:SetPoint("LEFT", box, "LEFT", x, 0); x = x + SZ + IG
            end
            local hx = 70
            for _, def in ipairs(SC) do
                local b = btns[def.key]
                local shown = ck.side[def.key] ~= nil
                b.tex:SetTexture(def.icon())
                if shown then
                    if def.tint then b.tex:SetVertexColor(UI:Accent()) else b.tex:SetVertexColor(unpack(C.text)) end
                    b:SetAlpha(1)
                else
                    b:ClearAllPoints(); b:SetParent(hid); b:SetPoint("LEFT", hid, "LEFT", hx, 0); hx = hx + SZ + IG
                    b.tex:SetVertexColor(unpack(C.muted))
                    b:SetAlpha(0.6)
                end
                local ar, ag, ab = UI:Accent()
                b.edge:SetColor(unpack(b:IsMouseOver() and { ar, ag, ab, 1 } or C.surface2))
            end
        end
        UI:OnResize(box, function() layoutBar() end)
        table.insert(self.dyn, function() layoutBar() end)
        layoutBar()

        -----------------------------------------------------------------------
        -- Carte : lieux utiles et trajets (Modules/MapLayers.lua, UI/MapLayers.lua)
        -----------------------------------------------------------------------
        section("maplayers")
        -- Mes notes de carte (Modules/MapNotes.lua, UI/MapNotes.lua) : réglages, recherche, liste par zone
        do
            local MN = WK.modules.MapNotes
            local nc = MN:Config()
            local LIST_H = 250
            subtab("Mes notes", 2)
            local ncard = card("Mes notes de carte", 40 + 3 * 46 + 44 + LIST_H + 12, "perso : vues par tous tes persos, jamais envoyées")
            local placeDd = UI:Dropdown(ncard, 220, 30, { { "alt", T("Alt + clic") }, { "ctrl", T("Ctrl + clic") }, { "shiftalt", T("Maj + Alt + clic") } },
                function(v) nc.place = v end)
            placeDd:Select(nc.place or "alt")
            UI:SettingRow(ncard, -40, "Poser une note", "Sur la carte du monde, à l'endroit cliqué. Clic sur une note : la modifier ; Maj + clic : y aller.", placeDd, 220)
            UI:SettingRow(ncard, -86, "Taille des pastilles", nil,
                UI:Slider(ncard, 220, 12, 32, 2, function() return nc.size or 18 end, function(v) nc.size = v; UI:RefreshMapNotes() end, "%d px"), 240)
            UI:SettingRow(ncard, -132, "Noms toujours affichés", "Pour toutes les notes (sinon au survol, ou note par note).",
                toggle(ncard, function() return nc.labels end, function(v) nc.labels = v; UI:RefreshMapNotes() end), 80)
            local search = UI:Input(ncard, 260, 30, T("Rechercher une note…"), "search")
            search:SetPoint("TOPLEFT", 16, -184)
            local count = UI:Text(ncard, 11, C.muted)
            count:SetPoint("LEFT", search, "RIGHT", 12, 0)
            local lsc = UI:Scroll(ncard)
            lsc:SetPoint("TOPLEFT", 12, -222)
            lsc:SetPoint("TOPRIGHT", -8, -222)
            lsc:SetHeight(LIST_H)
            local heads = UI:Pool(function() return UI:Text(lsc.child, 10, C.muted) end)
            local rows = UI:Pool(function()
                local r = CreateFrame("Button", nil, lsc.child)
                r:SetHeight(34)
                r.hl = UI:Rounded(r, 8, 0, "BACKGROUND", 1)
                r.icon = UI:Icon(r, "star", 15, nil, "ARTWORK")
                r.icon:SetPoint("LEFT", 8, 0)
                r.name = UI:Text(r, 12)
                r.name:SetPoint("TOPLEFT", 32, -4)
                r.name:SetPoint("RIGHT", -150, 0)
                r.name:SetJustifyH("LEFT")
                r.sub = UI:Text(r, 10, C.dim)
                r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
                r.sub:SetPoint("RIGHT", -150, 0)
                r.sub:SetJustifyH("LEFT")
                r.del = UI:IconButton(r, "trash", 24, "Maj + clic : supprimer la note", true)
                r.del:SetPoint("RIGHT", -4, 0)
                r.del:SetScript("OnClick", function() if IsShiftKeyDown() and r.note then MN:Delete(r.note.id) end end)
                r.go = UI:Button(r, "Guider", nil, 24, "ghost", "guide")
                r.go:SetPoint("RIGHT", r.del, "LEFT", -6, 0)
                r.go:SetScript("OnClick", function() if r.note then MN:GuideTo(r.note) end end)
                r:SetScript("OnEnter", function(s) s.hl:SetColor(unpack(C.hover)) end)
                r:SetScript("OnLeave", function(s) s.hl:SetColor(0, 0, 0, 0) end)
                r:SetScript("OnClick", function(s) if s.note then UI:EditMapNote(s.note) end end)
                return r
            end)
            local empty = UI:Text(lsc.child, 11, C.muted)
            empty:SetPoint("TOPLEFT", 6, -8)
            local function refreshList()
                heads:Reset(); rows:Reset()
                local w = math.max(200, (lsc:GetWidth() or 600) - 14)
                lsc.child:SetWidth(w)
                local groups = MN:Grouped(search:GetText())
                local y, n = 0, 0
                for _, g in ipairs(groups) do
                    local h = heads:Get()
                    h:ClearAllPoints(); h:SetPoint("TOPLEFT", 6, -(y + 8))
                    h:SetText(UI:Upper(g.zone) .. "  ·  " .. #g.notes)
                    y = y + 26
                    for _, note in ipairs(g.notes) do
                        local r = rows:Get()
                        r.note = note
                        r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:SetWidth(w)
                        r.hl:SetColor(0, 0, 0, 0)
                        local col = MN:Color(note.color)
                        r.icon:SetTexture(UI.MEDIA .. (note.icon or "star"))
                        r.icon:SetVertexColor(col[1], col[2], col[3], 1)
                        r.name:SetText(note.title or T("Note"))
                        r.sub:SetText((note.text and note.text ~= "" and (note.text:gsub("\n", " ") .. "  ·  ") or "") .. MN:Coords(note))
                        y = y + 36; n = n + 1
                    end
                end
                empty:SetShown(n == 0)
                empty:SetText(#MN:List() == 0 and T("Pas encore de note : Alt + clic sur la carte du monde pour en poser une.") or T("Aucune note ne correspond."))
                count:SetText(string.format(#MN:List() > 1 and T("%d notes") or T("%d note"), #MN:List()))
                lsc:SetContentHeight(math.max(y, 30))
            end
            search.onChange = function() refreshList() end
            self.RefreshNotesList = function() refreshList() end
            table.insert(self.dyn, refreshList)
            UI:OnResize(lsc, function() refreshList() end)
        end
        local ML = WK.modules.MapLayers
        local mlc = ML:Config()
        local function mlRefresh() if UI.RefreshMapLayers then UI:RefreshMapLayers() end end
        -- grille de puces (3 colonnes) : pastille du lieu, nom, puis deux boutons carte / minicarte
        local COLS, CH, CG = 3, 34, 6
        local famRows, lh = {}, 40
        for _, fam in ipairs(ML.FAMILIES) do
            local n = 0
            for _, l in ipairs(ML.LAYERS) do if l.family == fam.key then n = n + 1 end end
            famRows[fam.key] = math.ceil(n / COLS)
            if n > 0 then lh = lh + 22 + famRows[fam.key] * (CH + CG) end
        end
        subtab("Lieux", 1)
        local lcard = card("Sur les cartes", lh + 8, "une pastille par lieu ; carte du monde et minicarte, clic pour allumer")
        local chips = {}
        local function chipToggle(chip, icon, tip, get, set)
            local b = CreateFrame("Button", nil, chip)
            b:SetSize(24, 24)
            b.bg = UI:Rounded(b, 6, 0, "BACKGROUND", 2)
            b.ic = UI:Icon(b, icon, 12, nil, "ARTWORK"); b.ic:SetPoint("CENTER")
            function b:Refresh()
                local on = get()
                local r, g, bl = UI:Accent()
                if on then
                    self.bg:SetColor(r, g, bl, 1); self.ic:SetVertexColor(unpack(C.onAccent))
                else
                    self.bg:SetColor(C.hover[1], C.hover[2], C.hover[3], self.hover and 1 or 0.6); self.ic:SetVertexColor(r, g, bl, 0.55)
                end
            end
            b:SetScript("OnClick", function(s) set(not get()); s:Refresh(); WK:NotifyChanged() end)
            b:SetScript("OnEnter", function(s)
                s.hover = true; s:Refresh()
                WK.UI:TooltipOwner(s, "ANCHOR_TOP"); GameTooltip:SetText(T(tip), 1, 1, 1); GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function(s) s.hover = false; s:Refresh(); GameTooltip:Hide() end)
            UI:OnAccent(function() b:Refresh() end)
            table.insert(self.toggles, b)
            b:Refresh()
            return b
        end
        local ly = -40
        for _, fam in ipairs(ML.FAMILIES) do
            local list = {}
            for _, l in ipairs(ML.LAYERS) do if l.family == fam.key then table.insert(list, l) end end
            if #list > 0 then
                local fl = UI:Text(lcard, 10, C.dim)
                fl:SetPoint("TOPLEFT", 16, ly - 6)
                fl:SetText(UI:Upper(T(fam.label)))
                ly = ly - 22
                for i, l in ipairs(list) do
                    local chip = CreateFrame("Frame", nil, lcard)
                    chip:SetHeight(CH)
                    chip.bg = UI:Rounded(chip, 8, 0, "BACKGROUND", 1); chip.bg:SetColor(unpack(C.surface2))
                    local dot = UI:Icon(chip, "circle", 18, nil, "ARTWORK"); dot:SetPoint("LEFT", 8, 0)
                    dot:SetVertexColor(fam.color[1], fam.color[2], fam.color[3])
                    local ic = UI:Icon(chip, l.icon, 10, nil, "OVERLAY"); ic:SetPoint("CENTER", dot, "CENTER")
                    ic:SetVertexColor(unpack(C.bg))
                    local t2 = chipToggle(chip, "ring", "Minicarte", function() return mlc.mini[l.key] end, function(v) mlc.mini[l.key] = v; mlRefresh() end)
                    t2:SetPoint("RIGHT", -5, 0)
                    local t1 = chipToggle(chip, "map", "Carte du monde", function() return mlc.map[l.key] end, function(v) mlc.map[l.key] = v; mlRefresh() end)
                    t1:SetPoint("RIGHT", t2, "LEFT", -4, 0)
                    chip.label = UI:Text(chip, 12); chip.label:SetPoint("LEFT", 32, 0); chip.label:SetPoint("RIGHT", t1, "LEFT", -6, 0)
                    chip.label:SetText(l.label)
                    chip.col, chip.row, chip.y = (i - 1) % COLS, math.floor((i - 1) / COLS), ly
                    table.insert(chips, chip)
                    -- trouvable par la recherche de la barre latérale
                    UI.settingIndex = UI.settingIndex or {}
                    table.insert(UI.settingIndex, { row = chip, label = l.label })
                end
                ly = ly - famRows[fam.key] * (CH + CG)
            end
        end
        UI:OnResize(lcard, function(w)
            if not w or w <= 0 then return end
            local cw = math.floor((w - 32 - (COLS - 1) * CG) / COLS)
            for _, chip in ipairs(chips) do
                chip:ClearAllPoints()
                chip:SetPoint("TOPLEFT", 16 + chip.col * (cw + CG), chip.y - chip.row * (CH + CG))
                chip:SetWidth(cw)
            end
        end)
        local fcard = card("Filtres et affichage", 40 + 7 * 46 + 8)
        UI:SettingRow(fcard, -40, "Seulement ma faction", "Pas les lieux ni les trajets réservés à l'autre faction.",
            toggle(fcard, function() return mlc.myFaction end, function(v) mlc.myFaction = v; mlRefresh() end), 80)
        UI:SettingRow(fcard, -86, "Seulement ma classe", "Maître de classe, familiers et démons, munitions (chasseur), poisons (voleur), écuries.",
            toggle(fcard, function() return mlc.myClass end, function(v) mlc.myClass = v; mlRefresh() end), 80)
        UI:SettingRow(fcard, -132, "Seulement mes métiers", "Les maîtres des métiers que ce perso a appris.",
            toggle(fcard, function() return mlc.myProfs end, function(v) mlc.myProfs = v; mlRefresh() end), 80)
        UI:SettingRow(fcard, -178, "Barre de filtres sur la carte du monde", "En haut de la carte : clic sur une famille pour l'afficher ou la masquer, clic droit pour le détail.",
            toggle(fcard, function() return mlc.toolbar end, function(v) mlc.toolbar = v; mlRefresh() end), 80)
        UI:SettingRow(fcard, -224, "Taille des icônes sur la carte", "Lieux, quais, navires, rares, notes, filons et repère de la carte du monde. 100 % : taille par défaut.",
            UI:Slider(fcard, 220, 50, 200, 10, function() return mlc.iconScale or 100 end, function(v)
                mlc.iconScale = v; mlRefresh(); if UI.RedrawWorldMap then UI.RedrawWorldMap("taille") end
            end, "%d %%"), 240)
        UI:SettingRow(fcard, -270, "Carte sans brouillard", "Les zones que ce perso n'a pas encore découvertes sont dessinées quand même sur la carte du monde.",
            toggle(fcard, function() return mlc.reveal ~= false end, function(v) mlc.reveal = v; if UI.RedrawWorldMap then UI.RedrawWorldMap("brouillard") end end), 80)
        UI:SettingRow(fcard, -316, "Zones pas découvertes plus sombres", "Pour voir d'un coup d'œil ce qui reste à explorer.",
            toggle(fcard, function() return mlc.revealTint ~= false end, function(v) mlc.revealTint = v; if UI.RedrawWorldMap then UI.RedrawWorldMap("brouillard") end end), 80)
        -- Navigation : trajet en pointillé qui suit les chemins connus, appris en jouant (Modules/Nav.lua)
        local GD, NV = WK.modules.Guide, WK.modules.Nav
        local gdc = GD:Config()
        local function replan() if GD.target then NV:Plan(GD.target) end; if UI.RefreshNavRoute then UI:RefreshNavRoute() end end
        -- Guidage vers le lieu utile le plus proche (Modules/Guide.lua) : onglet Guidage de la carte
        do
            subtab("Guidage", 3)
            local G = WK.modules.Guide
            local gcfg = G:Config()
            local guide = card("Guidage", 456)
            UI:SettingRow(guide, -40, "Guider quand une alerte se déclenche",
                "Sacs pleins, réparation, composants ou munitions : guidage vers le lieu le plus proche (hors combat).",
                toggle(guide, function() return gcfg.auto end, function(v) gcfg.auto = v end), 80)
            UI:SettingRow(guide, -96, "Flèche à l'écran", "En plus de l'épingle et du trajet : flèche déplaçable vers le point suivant du chemin ; clic droit ou croix pour arrêter.",
                toggle(guide, function() return gcfg.arrow end, function(v) gcfg.arrow = v; if G.OnTarget then G:OnTarget() end end), 80)
            UI:SettingRow(guide, -144, "Repère sur la carte du monde", nil,
                toggle(guide, function() return gcfg.mapPin end, function(v) gcfg.mapPin = v; if G.Redraw then G:Redraw() end end), 80)
            UI:SettingRow(guide, -186, "Maître de classe à chaque niveau pair", "Nouveaux sorts tous les deux niveaux : guidage vers le maître de ta classe le plus proche.",
                toggle(guide, function() return gcfg.trainerOnLevel end, function(v) gcfg.trainerOnLevel = v end), 80)
            UI:SettingRow(guide, -232, "Épingle à l'écran", "Au-dessus du lieu guidé : épingle à l'icône de ce que tu suis, avec le nom et la distance restante.",
                toggle(guide, function() return gcfg.screenPin end, function(v) gcfg.screenPin = v; if G.target then G:Start(G.target, G.target.reason, G.target.kind) end end), 80)
            UI:SettingRow(guide, -278, "Son à l'arrivée", "Un bandeau « Arrivé » s'affiche et le guidage s'arrête ; avec un son si activé.",
                toggle(guide, function() return gcfg.arriveSound end, function(v) gcfg.arriveSound = v end), 80)
            UI:SettingRow(guide, -324, "Retour au corps", "Mort : bandeau avec la distance et le temps jusqu'au corps, ce que coûte l'ange gardien, et guidage vers le corps.",
                toggle(guide, function() return gcfg.corpse ~= false end, function(v) gcfg.corpse = v; if UI.RefreshCorpse then UI:RefreshCorpse() end end), 80)
            -- Boutons « le plus proche » : passent à la ligne si la fenêtre est étroite (2 lignes prévues).
            local goBar = CreateFrame("Frame", nil, guide)
            goBar:SetPoint("BOTTOMLEFT", 16, 12)
            goBar:SetPoint("BOTTOMRIGHT", -12, 12)
            goBar:SetHeight(62)
            local goLbl = UI:Text(goBar, 11, C.muted)
            goLbl:SetText("Le plus proche :")
            local goButtons = { goLbl }
            for _, it in ipairs({ { "mail", "Boîte aux lettres" }, { "bank", "Banque" }, { "repair", "Réparation" },
                                  { "vendor", "Marchand" }, { "trainer", "Maître de classe" } }) do
                local b = UI:Button(goBar, it[2], nil, 28, "primary")
                b:SetScript("OnClick", function() G:GoTo(it[1]) end)
                table.insert(goButtons, b)
            end
            UI:OnResize(goBar, function(w)
                local x, row = 0, 0
                for _, b in ipairs(goButtons) do
                    local isLabel = b == goLbl
                    local bw = isLabel and (goLbl:GetStringWidth() + 6) or b:GetWidth()
                    if x > 0 and x + bw > w then x, row = 0, row + 1 end
                    b:ClearAllPoints()
                    b:SetPoint("TOPLEFT", x, -row * 34 - (isLabel and 8 or 0))
                    x = x + bw + 6
                end
            end)
            dynText(guide, 10, C.dim, function()
                return string.format(T("%d lieux de WoW Forever (données QuestieDB)"), G:Count())
            end):SetPoint("TOPRIGHT", -16, -16)
            -- points /way à la manière de TomTom (Modules/Waypoints.lua, UI/Waypoints.lua)
            local WP = WK.modules.Waypoints
            if WP then
                local wc = WP:Config()
                local way = card("Points /way", 40 + 8 * 46 + 34, "commande, file, compatibilité TomTom")
                local cmdSeg = UI:Segmented(way, { { "auto", "Auto" }, { "way", "/way" }, { "wkway", "/wkway" } },
                    function(v)
                        wc.cmd = v
                        UI:AskReload(T("La commande /way change au prochain rechargement."))
                    end, 26)
                cmdSeg:Select(wc.cmd)
                UI:SettingRow(way, -40, "Commande /way",
                    "Auto : la nôtre, sauf si TomTom est là (elle devient /wkway). /wkway marche toujours.",
                    cmdSeg, cmdSeg:GetWidth())
                UI:SettingRow(way, -86, "Plusieurs /way : file de points",
                    "Arrivé à un point, on passe au suivant. Coupé : un nouveau point remplace l'ancien.",
                    toggle(way, function() return wc.queue end, function(v) wc.queue = v end), 80)
                local ordSeg = UI:Segmented(way, { { "typed", "Ordre tapé" }, { "near", "Plus proche" } },
                    function(v) wc.order = v end, 26)
                ordSeg:Select(wc.order)
                UI:SettingRow(way, -132, "Ordre de la file",
                    "Plus proche : file réordonnée à chaque ajout pour le trajet le plus court.",
                    ordSeg, ordSeg:GetWidth())
                UI:SettingRow(way, -178, "Répondre aux addons qui parlent à TomTom",
                    "Sans TomTom : les guides qui « envoient vers TomTom » posent leurs points ici.",
                    toggle(way, function() return wc.tomtomApi end, function(v) wc.tomtomApi = v end), 80)
                UI:SettingRow(way, -224, "Suivre les points de TomTom",
                    "TomTom installé : ses points sont aussi guidés par notre épingle et notre trajet.",
                    toggle(way, function() return wc.followTomTom end, function(v) wc.followTomTom = v end), 80)
                UI:SettingRow(way, -270, "Coordonnées cliquables dans le chat",
                    "Clic = guider, Maj + clic = ajouter à la file, clic droit = note de carte.",
                    toggle(way, function() return wc.chatLinks end, function(v) wc.chatLinks = v end), 80)
                UI:SettingRow(way, -316, "Points partagés par le groupe",
                    "Un membre qui a Warband Keeper partage un point : lien cliquable dans le chat.",
                    toggle(way, function() return wc.share end, function(v) wc.share = v end), 80)
                UI:SettingRow(way, -362, "Liste des points sur la carte",
                    "File affichée sur le côté de la carte ; Ctrl + clic droit y pose un point.",
                    toggle(way, function() return wc.sideList end, function(v)
                        wc.sideList = v
                        if UI.RefreshWaypointList then UI:RefreshWaypointList() end
                    end), 80)
                UI:SettingRow(way, -408, "Garder les points après un rechargement", "Par perso.",
                    toggle(way, function() return wc.keep end, function(v) wc.keep = v end), 80)
                dynText(way, 10, C.dim, function()
                    local n = #WP:List()
                    local tt = T("TomTom absent")
                    if WP.TomTomPresent() then tt = T("TomTom installé")
                    elseif WP.shim then tt = T("TomTom absent : ses appels arrivent ici") end
                    return string.format(T("%d point(s) dans la file · %s"), n, tt)
                end):SetPoint("BOTTOMLEFT", 16, 12)
            end
        end
        local rcard = card("Navigation", 40 + 4 * 46 + 44, "trajet du guidage, appris en jouant")
        UI:SettingRow(rcard, -40, "Trajet sur la carte du monde", "Pointillés de ta couleur, de toi jusqu'au lieu guidé, en suivant les chemins connus (vols compris).",
            toggle(rcard, function() return gdc.route end, function(v) gdc.route = v; replan() end), 80)
        UI:SettingRow(rcard, -86, "Trajet sur la minicarte", nil,
            toggle(rcard, function() return gdc.routeMini end, function(v) gdc.routeMini = v; replan() end), 80)
        UI:SettingRow(rcard, -132, "Apprendre les chemins", "Note les chemins que tu parcours à pied ou à monture (hors vol et instances), sur tous tes persos : les trajets les suivent ensuite.",
            toggle(rcard, function() return gdc.learn end, function(v) gdc.learn = v; if not v then NV:EndTrail() end end), 80)
        local forget = UI:Button(rcard, "Oublier les chemins appris", nil, 28, "danger")
        forget:SetScript("OnClick", function(b)
            if not b.armed then
                b.armed = true; b:SetLabel(T("Confirmer"))
                C_Timer.After(3, function() b.armed = nil; b:SetLabel(T("Oublier les chemins appris")) end)
                return
            end
            b.armed = nil; b:SetLabel(T("Oublier les chemins appris"))
            NV:Forget(); WK:NotifyChanged()
        end)
        UI:SettingRow(rcard, -178, "Chemins appris", nil, forget, 240)
        dynText(rcard, 11, C.muted, function()
            local learned, roads = NV:Stats()
            return string.format(T("%.1f km appris · %.1f km de chemins de base (patrouilles des PNJ, QuestieDB)"), learned / 1000, roads / 1000)
        end):SetPoint("TOPLEFT", 16, -232)
        -- Bateaux et zeppelins (Modules/BoatLines.lua, UI/DockBanner.lua, UI/BoatMap.lua, UI/BoatBoard.lua)
        do
            subtab("Bateaux", 4)
            local bcard = card("Bateaux et zeppelins", 40 + 3 * 46 + 46, "lignes, quais et trajets tirés des fichiers du jeu")
            UI:SettingRow(bcard, -40, "Bandeau au quai et à bord", "Près d'un quai : le navire de ton ponton et toutes ses escales ; à bord : sa prochaine escale ; dans le tram : ses deux stations.",
                toggle(bcard, function() return gdc.dockBanner end, function(v) gdc.dockBanner = v; if UI.RefreshDockBanner then UI:RefreshDockBanner() end end), 80)
            UI:SettingRow(bcard, -86, "Tracés des lignes sur la carte", "Le trajet de chaque ligne sur la carte du monde, plus marqué pour celles déjà prises.",
                toggle(bcard, function() return gdc.shipsMap ~= false end, function(v) gdc.shipsMap = v; if UI.RedrawWorldMap then UI.RedrawWorldMap("navires") end end), 80)
            UI:SettingRow(bcard, -132, "Distance d'apparition du bandeau", "Le bandeau s'affiche quand tu es à moins de cette distance du point d'arrêt du navire (55 m : dès que tu avances sur le ponton ; 30 m : au bout). « /wk bateau » donne ta distance aux quais proches.",
                UI:Slider(bcard, 240, 10, 100, 5, function() return gdc.dockRange or 55 end, function(v) gdc.dockRange = v; if UI.RefreshDockBanner then UI:RefreshDockBanner() end end, "%d m"), 260)
            local open = UI:Button(bcard, "Ouvrir les destinations", nil, 28, "primary")
            open:SetPoint("TOPLEFT", 16, -182)
            open:SetScript("OnClick", function() UI:ToggleBoatBoard(true) end)
        end
        -- Points de vol à apprendre (Modules/Flight.lua) : maîtres de vol du continent pas encore appris
        do
            local FL = WK.modules.Flight
            local flc = FL.Config()
            local FPR = 6
            subtab("Vols", 5)
            -- pendant le vol : barre, statistiques (déplacés d'Interface > Général > Confort)
            local flyc = card("Pendant le vol", 40 + 3 * 46 + 8)
            UI:SettingRow(flyc, -40, "Barre de vol", "Trajet, temps restant et bouton « Atterrir » pendant un vol. Se place en mode édition.",
                toggle(flyc, function() return flc.enabled end, function(v) flc.enabled = v end), 80)
            UI:SettingRow(flyc, -86, "Statistiques en vol à la place de la carte", "En vol, la touche de la carte (M) ouvre les statistiques du compte à la place de la carte. Décoché : M ouvre la carte.",
                toggle(flyc, function() return flc.stats ~= false end, function(v) flc.stats = v end), 80)
            UI:SettingRow(flyc, -132, "Ouvrir les statistiques au décollage", "Elles s'ouvrent seules à chaque vol et se ferment à l'atterrissage.",
                toggle(flyc, function() return flc.statsAuto end, function(v) flc.statsAuto = v end), 80)
            local fpcard = card("Points de vol à apprendre", 40 + 46 + 22 + FPR * 30 + 16, "maîtres de vol de ta faction sur ce continent, du plus proche au plus loin")
            UI:SettingRow(fpcard, -40, "Rappel en arrivant dans une zone", "Une fois par zone et par session, si un maître de vol de la zone n'est pas encore appris. /wk vol guide au plus proche.",
                toggle(fpcard, function() return flc.fpRemind end, function(v) flc.fpRemind = v end), 80)
            local fpInfo = UI:Text(fpcard, 11, C.muted)
            fpInfo:SetPoint("TOPLEFT", 16, -92)
            fpInfo:SetPoint("RIGHT", -16, 0)
            fpInfo:SetJustifyH("LEFT")
            local fpRows = {}
            for i = 1, FPR do
                local r = CreateFrame("Frame", nil, fpcard)
                r:SetHeight(26)
                r:SetPoint("TOPLEFT", 16, -112 - (i - 1) * 30)
                r:SetPoint("RIGHT", -16, 0)
                r.name = UI:Text(r, 12)
                r.name:SetPoint("LEFT")
                r.name:SetPoint("RIGHT", -230, 0)
                r.name:SetJustifyH("LEFT")
                r.info = UI:Text(r, 11, C.muted)
                r.info:SetPoint("RIGHT", -96, 0)
                r.go = UI:Button(r, "Guider", 86, 24, "ghost")
                r.go:SetPoint("RIGHT")
                r.go:SetScript("OnClick", function() if r.target then FL:GuideToFlightPoint(r.target) end end)
                fpRows[i] = r
            end
            local function fpRefresh()
                local p = WK.modules.Guide:PlayerPos()
                local list = (p and p.cont and FL:KnowsAnyTaxi()) and FL:MissingFlightPoints(nil, p.cont) or {}
                if not FL:KnowsAnyTaxi() then
                    fpInfo:SetText(T("Ouvre une fois la carte d'un maître de vol avec ce perso : ses points de vol connus seront notés."))
                elseif #list == 0 then
                    fpInfo:SetText(T("Tous les points de vol de ce continent sont appris."))
                else
                    fpInfo:SetText(string.format(T("%d à apprendre sur ce continent."), #list))
                end
                local G = WK.modules.Guide
                for i, r in ipairs(fpRows) do
                    local t = list[i]
                    r.target = t
                    r:SetShown(t ~= nil)
                    if t then
                        r.name:SetText(G:PlaceName(t))
                        local zone = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(t.map)
                        r.info:SetText((zone and zone.name or "") .. (t.distance and string.format("  ·  %d m", t.distance) or ""))
                    end
                end
            end
            table.insert(self.dyn, fpRefresh)
            function UI:RefreshFlightPoints() pcall(fpRefresh) end
        end


        -----------------------------------------------------------------------
        -- Curseur (UI/CursorRing.lua) : anneau autour de la souris, curseur gardé dans la fenêtre en combat
        -----------------------------------------------------------------------
        section("cursor")
        do
            local cc = UI.CursorConfig()
            local function sync() UI:SyncCursorRing() end
            local function ctoggle(parent, field, after)
                return toggle(parent, function() return cc[field] end, function(v) cc[field] = v; if after then after() end end)
            end
            local rgc = card("Anneau autour de la souris", 40 + 8 * 46 + 8, "le curseur se repère d'un coup d'œil")
            UI:SettingRow(rgc, -40, "Anneau autour de la souris", "De ta couleur, au-dessus de tout le reste.", ctoggle(rgc, "ring", sync), 80)
            UI:SettingRow(rgc, -86, "Seulement en combat", nil, ctoggle(rgc, "combatOnly", sync), 80)
            UI:SettingRow(rgc, -132, "Taille", nil,
                UI:Slider(rgc, 220, 24, 120, 2, function() return cc.size end, function(v) cc.size = v; sync() end, "%d px"), 240)
            UI:SettingRow(rgc, -178, "Opacité", nil,
                UI:Slider(rgc, 220, 20, 100, 5, function() return math.floor((cc.alpha or 0.85) * 100 + 0.5) end, function(v) cc.alpha = v / 100 end, "%d %%"), 240)
            UI:SettingRow(rgc, -224, "Balayage du temps global et des incantations", "L'anneau se remplit pendant le temps de recharge global et pendant tes incantations.", ctoggle(rgc, "sweep"), 80)
            UI:SettingRow(rgc, -270, "Rouge hors de portée", "Quand ta cible attaquable est trop loin (mêlée pour guerrier, voleur et paladin ; 35 m pour le chasseur ; 30 m sinon).", ctoggle(rgc, "range"), 80)
            UI:SettingRow(rgc, -316, "Estomper quand la souris ne bouge pas", "Après 3 secondes, hors combat.", ctoggle(rgc, "fadeIdle"), 80)
            UI:SettingRow(rgc, -362, "Masquer en tournant la caméra", "Pendant que le clic droit est enfoncé.", ctoggle(rgc, "hideMouselook"), 80)
            -- traînée scintillante (UI/CursorTrail.lua)
            local function tsync() if UI.SyncCursorTrail then UI:SyncCursorTrail() end end
            local trc = card("Traînée", 40 + 6 * 46 + 8, "scintille derrière la souris quand elle bouge")
            UI:SettingRow(trc, -40, "Traînée scintillante", "Derrière le curseur quand la souris bouge ; ne prend jamais la souris. Bouton « Tester » du mode édition pour la voir tourner.",
                ctoggle(trc, "trail", tsync), 80)
            local styleSeg = UI:Segmented(trc, { { "sparks", T("Étincelles") }, { "comet", T("Comète") }, { "dust", T("Poussière") } },
                function(v) cc.trailStyle = v end, 26)
            styleSeg:Select(cc.trailStyle or "sparks")
            UI:SettingRow(trc, -86, "Style", "Étincelles : petites étoiles qui scintillent. Comète : ruban lumineux qui s'affine. Poussière : paillettes qui tombent.", styleSeg, 280)
            local colDd = UI:Dropdown(trc, 200, 30, { { "accent", T("Couleur d'accent") }, { "class", T("Couleur de classe") },
                { "gold", T("Or") }, { "rainbow", T("Arc-en-ciel") }, { "white", T("Blanc") } }, function(v) cc.trailColor = v end)
            colDd:Select(cc.trailColor or "accent")
            UI:SettingRow(trc, -132, "Couleur", nil, colDd, 200)
            UI:SettingRow(trc, -178, "Longueur", "Temps avant que la traînée s'éteigne.",
                UI:Slider(trc, 220, 200, 1500, 100, function() return cc.trailLen or 600 end, function(v) cc.trailLen = v end, "%d ms"), 240)
            UI:SettingRow(trc, -224, "Densité", nil,
                UI:Slider(trc, 220, 20, 100, 10, function() return cc.trailDensity or 60 end, function(v) cc.trailDensity = v end, "%d %%"), 240)
            UI:SettingRow(trc, -270, "Pas en combat", "La traînée s'arrête pendant les combats.", ctoggle(trc, "trailNoCombat"), 80)
            local clc = card("Curseur en combat", 40 + 46 + 30, "pour ne pas cliquer hors du jeu sur un deuxième écran")
            UI:SettingRow(clc, -40, "Garder le curseur dans la fenêtre en combat", "Le curseur ne sort plus de la fenêtre du jeu pendant un combat ; ton réglage revient à la sortie du combat.",
                ctoggle(clc, "clip", function() if not cc.clip then UI:CursorClipOff() end end), 80)
            dynText(clc, 11, C.muted, function()
                return UI:CursorClipSupported() and "" or T("Ce client du jeu n'a pas le réglage nécessaire : l'option n'a pas d'effet.")
            end):SetPoint("TOPLEFT", 16, -90)
        end

        -----------------------------------------------------------------------
        -- Hôtel des ventes (Modules/AHScan.lua, UI/AuctionPanel.lua)
        -----------------------------------------------------------------------
        section("ah")
        local AS = WK.modules.AHScan
        local ac = AS:Config()
        local function atoggle(parent, field)
            return toggle(parent, function() return ac[field] end, function(v) ac[field] = v end)
        end
        local hcard = card("Hôtel des ventes", 40 + 5 * 46 + 8, "scan et listes d'achat ; prix dans l'infobulle : Options > Infobulles")
        UI:SettingRow(hcard, -40, "Fenêtre Warband Keeper", "À l'encanteur, notre fenêtre remplace celle du jeu (Parcourir, Vendre, Mes enchères, À acheter, Prix). Sinon : la fenêtre du jeu et le panneau ci-dessous.",
            toggle(hcard, function() return ac.tabs ~= false end, function(v) ac.tabs = v end), 80)
        UI:SettingRow(hcard, -86, "Panneau à côté de l'HV", "Avec la fenêtre du jeu : nombre de prix connus, dernier scan et bouton « Scanner l'HV ».", atoggle(hcard, "panel"), 80)
        UI:SettingRow(hcard, -132, "Scan complet à l'ouverture", "Dès que le jeu l'autorise (environ toutes les 15 minutes).", atoggle(hcard, "auto"), 80)
        UI:SettingRow(hcard, -178, "Valeur des sacs à l'HV", "Sous les sacs du jeu : ce que valent tes sacs à l'HV (et chez le marchand) ; au survol, les objets qui valent le plus.",
            toggle(hcard, function() return ac.bagValue end, function(v) ac.bagValue = v; if UI.RefreshBagValue then UI:RefreshBagValue() end end), 80)
        UI:SettingRow(hcard, -224, "Valeur des courriers", "Au survol d'un courrier de la boîte aux lettres : la valeur à l'HV de ses pièces jointes.", atoggle(hcard, "mailValue"), 80)
        local scard = card("Prix relevés", 40 + 2 * 46 + 8, "pour ce royaume et cette faction")
        local stat = dynText(scard, 12, C.text, function()
            local d = AS:Data()
            return string.format(T("%d objets avec un prix"), AS:Count()) .. "  ·  " ..
                (d.last and (T("dernier scan le") .. " " .. date("%d/%m %H:%M", d.last)) or T("aucun scan pour l'instant"))
        end)
        UI:SettingRow(scard, -40, "État", nil, stat, 420)
        local wipe = UI:Button(scard, "Effacer les prix", 150, 28, "danger")
        wipe:SetScript("OnClick", function(b)
            if not b.armed then
                b.armed = true; b:SetLabel(T("Confirmer"))
                C_Timer.After(3, function() b.armed = nil; b:SetLabel(T("Effacer les prix")) end)
                return
            end
            b.armed = nil; b:SetLabel(T("Effacer les prix"))
            local d = AS:Data(); d.items = {}; d.last, d.lastFull, d.lastCount = nil, nil, nil
            WK:NotifyChanged()
        end)
        UI:SettingRow(scard, -86, "Repartir de zéro", "Efface les prix relevés sur ce royaume (deux clics).", wipe, 160)

        -- Vente (Modules/AHSell.lua) : vente rapide, mes enchères, alertes de prix
        local AV = WK.modules.AHSell
        AV.Config()
        local vcard = card("Vente", 40 + 2 * 46 + 8, "onglet « Ventes » du panneau : tes enchères, sous-cotées ou non")
        UI:SettingRow(vcard, -40, "Vente rapide", "Quand tu poses un objet dans la fenêtre de vente du jeu, son prix est mis au plus bas des autres vendeurs moins la marge ci-dessous (sinon au prix du scan).", atoggle(vcard, "quickSell"), 80)
        UI:SettingRow(vcard, -86, "Marge sous le plus bas", "En pièces de cuivre.",
            UI:Slider(vcard, 220, 1, 100, 1, function() return ac.undercut or 1 end, function(v) ac.undercut = v end, "%d pc"), 240)
        local ALR = 6
        local alcard = card("Alertes de prix", 40 + 22 + ALR * 30 + 30, "signalées après chaque scan de l'HV")
        local alHelp = UI:Text(alcard, 11, C.muted)
        alHelp:SetPoint("TOPLEFT", 16, -40)
        alHelp:SetPoint("RIGHT", -16, 0)
        alHelp:SetJustifyH("LEFT")
        alHelp:SetText(T("Ajouter : /wk alerte puis Maj+clic sur l'objet et le prix max à l'unité (ex. /wk alerte [Étoffe de soie] 75pa). Sans prix : retire l'alerte."))
        local alRows = {}
        for i = 1, ALR do
            local r = CreateFrame("Frame", nil, alcard)
            r:SetHeight(26)
            r:SetPoint("TOPLEFT", 16, -64 - (i - 1) * 30)
            r:SetPoint("RIGHT", -16, 0)
            r.icon = UI:RoundIcon(r, 20)
            r.icon:SetPoint("LEFT")
            r.name = UI:Text(r, 12)
            r.name:SetPoint("LEFT", 28, 0)
            r.name:SetPoint("RIGHT", -260, 0)
            r.name:SetJustifyH("LEFT")
            r.info = UI:Text(r, 11, C.muted)
            r.info:SetPoint("RIGHT", -36, 0)
            r.del = UI:IconButton(r, "trash", 24, "Retirer cette alerte", true)
            r.del:SetPoint("RIGHT")
            alRows[i] = r
        end
        local alEmpty = UI:Text(alcard, 11, C.dim)
        alEmpty:SetPoint("TOPLEFT", 16, -70)
        alEmpty:SetText(T("Aucune alerte pour l'instant."))
        table.insert(self.dyn, function()
            local list = AV:Alerts()
            alEmpty:SetShown(#list == 0)
            for i, r in ipairs(alRows) do
                local a = list[i]
                r:SetShown(a ~= nil)
                if a then
                    local _, icon = UI:ItemInfo(a.id)
                    r.icon:SetTexture(icon)
                    r.name:SetText(WK.GetItemInfo(a.id) or ("#" .. a.id))
                    local now = a.price and ((a.qty or 0) > 0) and (T("à l'HV") .. " " .. UI:ExactMoney(a.price)) or T("pas en vente")
                    r.info:SetText(T("max") .. " " .. UI:ExactMoney(a.max) .. "  ·  " .. (a.hit and (UI:Hex(C.positive) .. now .. "|r") or now))
                    r.del:SetScript("OnClick", function() AV:RemoveAlert(a.id); WK:NotifyChanged() end)
                end
            end
        end)

        -----------------------------------------------------------------------
        -- Pêche (Modules/Fishing.lua, UI/FishingBar.lua)
        -----------------------------------------------------------------------
        -- Pêche : ces cartes sont construites ici (aides de la page QoL) mais montrées dans la page
        -- Pêche (UI/Pages/FishCollection.lua : roue dentée et onglet Carnet), qui les reprend.
        section("fishing")
        self.fishSection = current
        local Fi = WK.modules.Fishing
        local fo = Fi:Config()
        local function ftoggle(parent, field, after)
            return toggle(parent, function() return fo[field] end, function(v) fo[field] = v; if after then after() end end)
        end
        local fmode = card("Mode pêche", 40 + 3 * 46 + 8)
        local modeBtn = UI:Button(fmode, "Ouvrir", 150, 28, "primary")
        modeBtn:SetScript("OnClick", function() Fi:Toggle() end)
        table.insert(self.dyn, function()
            modeBtn.label:SetText(Fi.active and T("Fermer le mode pêche") or T("Ouvrir le mode pêche"))
        end)
        UI:SettingRow(fmode, -40, "Mode pêche", "À la fermeture, équipement, sons et touche redeviennent comme avant. Aussi : /wk peche.", modeBtn, 170)
        UI:SettingRow(fmode, -86, "Ouvrir quand une canne est équipée", "Y compris à la connexion.", ftoggle(fmode, "autoOpen"), 80)
        UI:SettingRow(fmode, -132, "Bouton de minicarte", "Ouvre et ferme le mode pêche. Seulement sur les persos qui ont la Pêche, et masqué si le raccourci est dans le micro menu.",
            ftoggle(fmode, "minimap", function() UI:SyncFishingMinimap() end), 80)

        -- Carnet de pêche (Modules/FishingLog.lua) : chiffres du compte, zones, dernières prises
        local FL = WK.modules.FishingLog
        local ZROWS, JROWS = 6, 10
        local fbook = card("Carnet de pêche", 40 + 30 + 22 + ZROWS * 34 + 8, "relevé à chaque prise, sur tout le compte")
        fbook.journal = true
        local fsum = dynText(fbook, 12, C.text, function()
            local d = FL:Data()
            local rate = FL.Rate(d.total, d.time)
            local h = math.floor(d.time / 3600)
            return string.format(T("%d prises"), d.total) .. "  ·  " .. string.format(T("%d h %02d de pêche"), h, math.floor(d.time % 3600 / 60))
                .. (rate and ("  ·  " .. rate .. "/h") or "") .. "  ·  " .. UI:GoldText(FL:Value()) .. "  ·  " .. string.format(T("%d espèces"), FL:Species())
        end)
        fsum:SetPoint("TOPLEFT", 16, -42)
        fsum:SetPoint("RIGHT", -16, 0)
        fsum:SetJustifyH("LEFT")
        local zh = UI:Text(fbook, 10, C.dim)
        zh:SetPoint("TOPLEFT", 16, -72)
        zh:SetText(T("ZONES, PAR NOMBRE DE PRISES"))
        local zrows = {}
        for i = 1, ZROWS do
            local r = CreateFrame("Frame", nil, fbook)
            r:SetHeight(30)
            r:SetPoint("TOPLEFT", 16, -90 - (i - 1) * 34)
            r:SetPoint("RIGHT", -16, 0)
            r.name = UI:Text(r, 12)
            r.name:SetPoint("TOPLEFT", 0, -1)
            r.top = UI:Text(r, 10, C.muted)
            r.top:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
            r.top:SetPoint("RIGHT", -170, 0)
            r.top:SetJustifyH("LEFT")
            r.bar = UI:Progress(r, 5)
            r.bar:SetPoint("RIGHT", -96, 0)
            r.bar:SetWidth(70)
            r.n = UI:Text(r, 11, C.muted)
            r.n:SetPoint("RIGHT", -48, 0)
            r.rate = UI:Text(r, 11, C.muted)
            r.rate:SetPoint("RIGHT", 0, 0)
            zrows[i] = r
        end
        local zempty = UI:Text(fbook, 11, C.muted)
        zempty:SetPoint("TOPLEFT", 16, -92)
        zempty:SetText(T("Pas encore de prise : elles se notent toutes seules quand tu pêches."))
        table.insert(self.dyn, function()
            local zs = FL:Zones()
            local maxN = zs[1] and zs[1].n or 1
            zempty:SetShown(#zs == 0)
            for i, r in ipairs(zrows) do
                local z = zs[i]
                r:SetShown(z ~= nil)
                if z then
                    r.name:SetText(FL:ZoneName(z.map))
                    local names = {}
                    for _, id in ipairs(z.top) do if id then table.insert(names, WK.GetItemInfo(id) or ("#" .. id)) end end
                    r.top:SetText(table.concat(names, "  ·  "))
                    r.bar:SetValue(z.n / maxN)
                    r.n:SetText(tostring(z.n))
                    local rate = FL.Rate(z.n, z.time)
                    r.rate:SetText(rate and (rate .. "/h") or "")
                end
            end
        end)
        local fj = card("Dernières prises", 40 + JROWS * 26 + 8, "« nouveau » : première prise de cette espèce sur le compte")
        fj.journal = true
        local jrows = {}
        for i = 1, JROWS do
            local r = CreateFrame("Frame", nil, fj)
            r:SetHeight(24)
            r:SetPoint("TOPLEFT", 16, -40 - (i - 1) * 26)
            r:SetPoint("RIGHT", -16, 0)
            r.t = UI:Text(r, 10, C.dim)
            r.t:SetPoint("LEFT")
            r.t:SetWidth(78)
            r.t:SetJustifyH("LEFT")
            r.what = UI:Text(r, 11)
            r.what:SetPoint("LEFT", 82, 0)
            r.what:SetPoint("RIGHT", -110, 0)
            r.what:SetJustifyH("LEFT")
            r.who = UI:Text(r, 10, C.muted)
            r.who:SetPoint("RIGHT")
            r.who:SetJustifyH("RIGHT")
            jrows[i] = r
        end
        table.insert(self.dyn, function()
            local log = FL:Data().log
            local r1, g1, b1 = UI:Accent()
            local hex = string.format("%02x%02x%02x", r1 * 255, g1 * 255, b1 * 255)
            for i, r in ipairs(jrows) do
                local e = log[i]
                r:SetShown(e ~= nil)
                if e then
                    r.t:SetText(date((time() - e.t) < 86400 and "%H:%M" or "%d/%m %H:%M", e.t))
                    local parts = {}
                    for _, it in ipairs(e.it) do
                        local nm = (WK.GetItemInfo(it[1]) or ("#" .. it[1])) .. (it[2] > 1 and (" x" .. it[2]) or "")
                        if e.new and e.new[it[1]] then nm = nm .. "  |cff" .. hex .. T("nouveau") .. "|r" end
                        table.insert(parts, nm)
                    end
                    r.what:SetText(table.concat(parts, ", "))
                    local c = WK.DB.global.characters[e.c]
                    r.who:SetText((c and WK:CharName(c, e.c) or "?") .. "  ·  " .. FL:ZoneName(e.m))
                end
            end
        end)
        local frec = card("Récapitulatif de session", 40 + 2 * 46 + 8)
        UI:SettingRow(frec, -40, "À la fermeture du mode pêche", "Prises, rythme, valeur, ce qui a le plus mordu, compétence gagnée. Se place en mode édition.", ftoggle(frec, "recap"), 80)
        UI:SettingRow(frec, -86, "Temps d'affichage", "Une barre en bas se vide jusqu'à la fermeture ; en pause sous la souris. 0 : reste ouvert (clic pour fermer).",
            UI:Slider(frec, 240, 0, 60, 5, function() local v = fo.recapTime; if v == nil then v = 10 end; return v end,
                function(v) fo.recapTime = v end, "%d s"), 260)

        -- Touche unique : capture d'une touche, de la molette ou d'un bouton de souris
        local fkey = card("Une seule touche pour tout", 40 + 46 + 44, "active seulement en mode pêche, hors combat")
        local keyBtn = UI:Button(fkey, "", 170, 28, "secondary")
        local capture
        local function keyText() keyBtn.label:SetText(fo.key and fo.key ~= "" and UI.FishKeyLabel(fo.key) or T("Aucune")) end
        local function setKey(k)
            fo.key = k
            if capture then capture:Hide() end
            keyText()
            Fi:UpdateBinding()
            UI:RefreshFishingBar()
        end
        local function mods()
            return (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "")
        end
        keyBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        keyBtn:SetScript("OnClick", function(_, button)
            if InCombatLockdown and InCombatLockdown() then return end
            if button == "RightButton" then setKey("") return end
            if not capture then
                capture = CreateFrame("Frame", nil, UIParent)
                capture:SetAllPoints(UIParent)
                capture:SetFrameStrata("FULLSCREEN_DIALOG")
                capture:EnableMouse(true)
                capture:EnableKeyboard(true)
                capture:EnableMouseWheel(true)
                local shade = capture:CreateTexture(nil, "BACKGROUND")
                shade:SetAllPoints()
                shade:SetColorTexture(0, 0, 0, 0.6)
                local msg = UI:Text(capture, 16)
                msg:SetPoint("CENTER")
                msg:SetJustifyH("CENTER")
                msg:SetText(T("Appuie sur une touche, tourne la molette ou clique un bouton de souris (milieu, 4, 5).") .. "\n" .. T("Échap pour annuler."))
                capture:SetScript("OnKeyDown", function(_, key)
                    if key == "ESCAPE" then capture:Hide() return end
                    if key:find("SHIFT") or key:find("CTRL") or key:find("ALT") or key == "UNKNOWN" then return end
                    setKey(mods() .. key)
                end)
                capture:SetScript("OnMouseWheel", function(_, delta) setKey(mods() .. (delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")) end)
                capture:SetScript("OnMouseDown", function(_, button)
                    local map = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }
                    if map[button] then setKey(mods() .. map[button]) else capture:Hide() end
                end)
            end
            capture:Show()
        end)
        keyText()
        UI:SettingRow(fkey, -40, "Touche de pêche", "Clic : choisir une touche. Clic droit : aucune.", keyBtn, 190)
        local keyNote = UI:Text(fkey, 11, C.muted)
        keyNote:SetPoint("TOPLEFT", 16, -90)
        keyNote:SetPoint("TOPRIGHT", -16, -90)
        keyNote:SetJustifyH("LEFT")
        if keyNote.SetWordWrap then keyNote:SetWordWrap(true) end
        keyNote:SetText(T("Chaque appui fait ce qu'il faut : équiper la tenue, poser un appât, lancer la ligne, puis ferrer quand le flotteur est désigné. Hors du mode pêche, la touche garde son rôle habituel."))

        local fgear = card("Tenue et appâts", 40 + 4 * 46 + 8)
        UI:SettingRow(fgear, -40, "Équiper la tenue de pêche", "La meilleure canne des sacs, et les pièces qui donnent de la Pêche.", ftoggle(fgear, "autoGear"), 80)
        UI:SettingRow(fgear, -86, "Remettre l'équipement à la fermeture", "Les armes et pièces remplacées par la tenue de pêche.", ftoggle(fgear, "restoreGear"), 80)
        UI:SettingRow(fgear, -132, "Poser un appât", "Quand il n'y en a pas sur la canne, ou qu'il a expiré.", ftoggle(fgear, "autoLure"), 80)
        local lureOpts = { { "best", T("Le meilleur disponible") } }
        for _, l in ipairs(Fi.LURES) do
            table.insert(lureOpts, { tostring(l.id), ((WK.GetItemInfo(l.id)) or ("#" .. l.id)) .. " (+" .. l.bonus .. ")" })
        end
        local lureDd = UI:Dropdown(fgear, 240, 30, lureOpts, function(v) fo.lure = v; UI:RefreshFishingBar() end)
        lureDd:Select(fo.lure or "best")
        UI:SettingRow(fgear, -178, "Appât utilisé", "« Le meilleur » suit ta compétence et tes sacs.", lureDd, 240)

        local fcomfort = card("Confort", 40 + 3 * 46 + 8)
        UI:SettingRow(fcomfort, -40, "Butin rapide", "Ramasse la prise dès que le butin est prêt (sauf sacs pleins).", ftoggle(fcomfort, "fastLoot"), 80)
        local soundDd = UI:Dropdown(fcomfort, 240, 30, {
            { "off", T("Non") }, { "light", T("Léger : musique et ambiance baissées") }, { "strong", T("Fort : musique et ambiance coupées") },
            { "max", T("Maximum : tout coupé sauf les effets") } }, function(v)
            local was = Fi.active and fo.sound
            if was then Fi:FocusSound(false) end
            fo.sound = v ~= "off"
            if v ~= "off" then fo.soundLevel = v end
            if Fi.active and fo.sound then Fi:FocusSound(true) end
        end)
        soundDd:Select(fo.sound and (fo.soundLevel or "strong") or "off")
        UI:SettingRow(fcomfort, -86, "Son du flotteur mis en avant", "Le temps de pêcher ; tout redevient comme avant à la fermeture. Maximum : voix coupées, volume général au maximum, son gardé quand le jeu est en arrière-plan.", soundDd, 240)
        UI:SettingRow(fcomfort, -132, "Avertissements à l'écran", "Pas de canne, plus d'appât, sacs pleins.", ftoggle(fcomfort, "warn", function() Fi:Warn() end), 80)

        -----------------------------------------------------------------------
        -- Feu de camp (Modules/Camp.lua, UI/CampCard.lua)
        -----------------------------------------------------------------------
        section("campfire")
        do
            local Cp = WK.modules.Camp
            local campCfg = Cp:Config()
            local function cupdate() Cp:Update() end
            -- objets de camp par métier, en tête de l'onglet : une tuile par métier (3 colonnes), puis les feux
            local TH, FH, TG = 136, 52, 10
            local nrows = math.ceil(#Cp.OBJECTS / 3)
            subtab("Objets par métier", 2)
            local tbl = card("Objets de camp par métier", 40 + nrows * (TH + TG) + 24 + FH + 16,
                "effet à ton niveau · en clair : palier atteint par un de tes persos")
            local function txt(parent, size, color) local t = UI:Text(parent, size, color); t:SetJustifyH("LEFT"); return t end
            local tiles, fires = {}, {}
            for i, o in ipairs(Cp.OBJECTS) do
                local t = CreateFrame("Frame", nil, tbl)
                t:SetHeight(TH)
                UI:Panel(t, 8, C.surface2, C.border)
                t.icon = UI:RoundIcon(t, 30)
                t.icon:SetPoint("TOPLEFT", 12, -10)
                local first = o.ids[1] or o.ids[2]
                t.icon:SetTexture((C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(first)) or "Interface\\Icons\\INV_Misc_QuestionMark")
                t.title = txt(t, 13, C.text); t.title:SetPoint("TOPLEFT", 52, -10); t.title:SetText(T(o.prof))
                t.eff = txt(t, 12); t.eff:SetPoint("TOPLEFT", 52, -27); t.eff:SetPoint("TOPRIGHT", -10, -27)
                if t.eff.SetWordWrap then t.eff:SetWordWrap(false) end
                t.excl = txt(t, 10, C.dim); t.excl:SetPoint("TOPLEFT", 12, -50); t.excl:SetPoint("TOPRIGHT", -10, -50)
                if t.excl.SetWordWrap then t.excl:SetWordWrap(false) end
                t.line = t:CreateTexture(nil, "ARTWORK")
                t.line:SetTexture("Interface\\Buttons\\WHITE8X8")
                t.line:SetVertexColor(C.border[1], C.border[2], C.border[3], 0.8)
                t.line:SetHeight(1)
                t.line:SetPoint("TOPLEFT", 12, -66); t.line:SetPoint("TOPRIGHT", -12, -66)
                t.tiers = {}
                for k = 1, 3 do
                    local y = -72 - (k - 1) * 19
                    -- surlignage du palier atteint, pastille d'état à droite (« à toi », « Forge 132/140 », « 300 requis »)
                    local thl = t:CreateTexture(nil, "BORDER")
                    thl:SetTexture("Interface\\Buttons\\WHITE8X8")
                    thl:SetPoint("TOPLEFT", 6, y + 2); thl:SetPoint("TOPRIGHT", -6, y + 2); thl:SetHeight(17)
                    local rk = txt(t, 11, C.gold); rk:SetPoint("TOPLEFT", 12, y); rk:SetWidth(30); rk:SetText(Cp.RANKS[k])
                    local nm = txt(t, 11, C.text); nm:SetPoint("TOPLEFT", 44, y); nm:SetPoint("TOPRIGHT", -104, y)
                    if nm.SetWordWrap then nm:SetWordWrap(false) end
                    local pill = CreateFrame("Frame", nil, t)
                    pill:SetHeight(15); pill:SetPoint("TOPRIGHT", -10, y + 1)
                    pill.edge = UI:Rounded(pill, 5, 0, "BACKGROUND", 0)
                    pill.bg = UI:Rounded(pill, 5, 1, "BACKGROUND", 1)
                    pill.t = UI:Text(pill, 10); pill.t:SetPoint("CENTER", 0, 0)
                    t.tiers[k] = { rk = rk, nm = nm, hl = thl, pill = pill }
                end
                tiles[i] = t
            end
            local fhead = txt(tbl, 10, C.dim)
            fhead:SetText(UI:Upper(T("Feux de camp (Cuisine)")))
            for i in ipairs(Cp.FIRES) do
                local f = CreateFrame("Frame", nil, tbl)
                f:SetHeight(FH)
                UI:Panel(f, 8, C.surface2, C.border)
                f.icon = UI:RoundIcon(f, 26)
                f.icon:SetPoint("LEFT", 12, 0)
                f.icon:SetTexture((C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(Cp.FIRES[i][1])) or "Interface\\Icons\\INV_Misc_QuestionMark")
                f.name = txt(f, 12, C.text); f.name:SetPoint("TOPLEFT", 46, -10); f.name:SetPoint("TOPRIGHT", -10, -10)
                if f.name.SetWordWrap then f.name:SetWordWrap(false) end
                f.sub = txt(f, 10, C.muted); f.sub:SetPoint("TOPLEFT", 46, -29)
                f.sub:SetText(string.format(T("Cuisine %d · %d objets de camp en plus"), Cp.FIRES[i][3], Cp.FIRES[i][4]))
                fires[i] = f
            end
            UI:OnResize(tbl, function(w)
                local tw = (w - 32 - 2 * TG) / 3
                for i, t in ipairs(tiles) do
                    local c, r = (i - 1) % 3, math.floor((i - 1) / 3)
                    t:ClearAllPoints()
                    t:SetPoint("TOPLEFT", 16 + c * (tw + TG), -42 - r * (TH + TG))
                    t:SetWidth(tw)
                end
                local fy = -42 - nrows * (TH + TG) - 4
                fhead:ClearAllPoints(); fhead:SetPoint("TOPLEFT", 16, fy)
                for i, f in ipairs(fires) do
                    f:ClearAllPoints()
                    f:SetPoint("TOPLEFT", 16 + (i - 1) * (tw + TG), fy - 18)
                    f:SetWidth(tw)
                end
            end)
            -- rappel
            subtab("Rappels", 1)
            local rem = card("Rappel à l'écran", 40 + 5 * 46 + 8, "icône et encart près du camp")
            UI:SettingRow(rem, -224, "Icône près d'un feu de camp", "Une flamme qui apparaît près d'un camp : clic pour s'asseoir, un cercle décompte la minute. Se place en mode édition.",
                toggle(rem, function() return campCfg.icon end, function(v) campCfg.icon = v; cupdate() end), 80)
            UI:SettingRow(rem, -40, "Encart près d'un feu de camp", "« Assieds-toi » avec un bouton, compte à rebours assis, avantages obtenus.",
                toggle(rem, function() return campCfg.enabled end, function(v) campCfg.enabled = v; cupdate() end), 80)
            UI:SettingRow(rem, -86, "Proposer de renouveler", "Quand il reste moins que ce temps sur les avantages du camp (0 : seulement quand ils sont finis).",
                UI:Slider(rem, 240, 0, 60, 5, function() return campCfg.renewAt or 10 end, function(v) campCfg.renewAt = v; cupdate() end, "%d min"), 260)
            UI:SettingRow(rem, -132, "Son au rappel", "Un petit son quand l'encart propose de s'asseoir.",
                toggle(rem, function() return campCfg.sound end, function(v) campCfg.sound = v end), 80)
            UI:SettingRow(rem, -178, "Avantages affichés pendant", "Une fois obtenus, l'encart les montre puis s'efface (0 : il reste jusqu'à ce que tu le fermes).",
                UI:Slider(rem, 240, 0, 30, 2, function() return campCfg.doneSecs or 8 end, function(v) campCfg.doneSecs = v end, "%d s"), 260)
            -- kit de camp et rappels
            local kc = card("Kit de camp", 40 + 4 * 46 + 8, "dans la barre des sacs, ou colonne près de la flamme")
            UI:SettingRow(kc, -40, "Kit de camp", "Une colonne de boutons : ton feu, tes objets de camp (meilleur palier en sac), ton sac de couchage, ta nourriture « Bien nourri » et ta boisson. Clic : utiliser (hors combat).",
                toggle(kc, function() return campCfg.kit end, function(v) campCfg.kit = v; cupdate() end), 80)
            UI:SettingRow(kc, -86, "Toujours visible", "Sinon, le kit n'apparaît que près d'un feu de camp.",
                toggle(kc, function() return campCfg.kitAlways end, function(v) campCfg.kitAlways = v; cupdate() end), 80)
            UI:SettingRow(kc, -132, "Pastilles sous la flamme",
                "Avantages restants, recharge des objets de camp, « Bien nourri »"
                    .. " (seulement hors de la barre des sacs).",
                toggle(kc, function() return campCfg.chips end, function(v) campCfg.chips = v; cupdate() end), 80)
            -- case « kit » de la barre des sacs et sens du déroulé : carte de la barre (QoL > Général > Marchand)
            local kgo = UI:Button(kc, T("Réglages de la barre"), nil, 24, "secondary")
            kgo:SetWidth(kgo.label:GetStringWidth() + 28)
            kgo:SetScript("OnClick", function() UI:OpenBagBarSettings() end)
            UI:SettingRow(kc, -178, "Dans la barre des sacs",
                "La case « kit » et le sens du déroulé se règlent avec la barre"
                    .. " « Sacs, marchand et maître ».",
                kgo, 200)

            -- comment ça marche, et effets rencontrés
            -- 4 étapes en tuiles (gros numéro à la couleur d'accent, titre, texte), puis les effets rencontrés
            local STH, SG = 92, 10
            subtab("Comment ça marche", 4)
            local how = card("Comment ça marche", 40 + 2 * (STH + SG) + 36 + 8 * 18 + 8)
            local STEPS = {
                { "Approche-toi du feu", "1. Près d'un camp, une flamme t'affecte (par exemple « Flammes pourpres ») : elle allonge la durée des effets de camp." },
                { "Assieds-toi 1 min", "2. Assieds-toi (ou allonge-toi, agenouille-toi, dors, ou fabrique à côté) : « Feu de camp accueillant » compte 1 min." },
                { "Récupère les avantages", "3. Tu obtiens « Avantages du camp », selon les objets posés autour du feu ; ils restent quand tu pars." },
                { "Durées et recharges", "4. Un camp dure environ 15 min ; poser un feu : recharge de 5 min ; poser un objet de métier : recharge commune d'1 h." },
            }
            local steps = {}
            for i, st in ipairs(STEPS) do
                local t = CreateFrame("Frame", nil, how)
                t:SetHeight(STH)
                UI:Panel(t, 9, C.surface2, C.border)
                t.badge = CreateFrame("Frame", nil, t)
                t.badge:SetSize(26, 26); t.badge:SetPoint("TOPLEFT", 12, -12)
                UI:Panel(t.badge, 13, { 1, 1, 1, 1 })
                t.num = UI:Text(t.badge, 14, C.onAccent); t.num:SetPoint("CENTER", 0, 0); t.num:SetText(tostring(i))
                t.title = UI:Text(t, 13, C.text); t.title:SetPoint("LEFT", t.badge, "RIGHT", 10, 0); t.title:SetPoint("RIGHT", -12, 0)
                t.title:SetText(T(st[1]))
                t.body = UI:Text(t, 11, C.text)
                t.body:SetPoint("TOPLEFT", 12, -46); t.body:SetPoint("BOTTOMRIGHT", -12, 8)
                t.body:SetJustifyH("LEFT"); t.body:SetJustifyV("TOP")
                if t.body.SetWordWrap then t.body:SetWordWrap(true) end
                local body = WK.T(st[2]):gsub("^%d+%.%s*", "")
                t.body:SetText(body)
                steps[i] = t
            end
            local stepRows = 2
            local function layoutSteps()
                local Wc = how:GetWidth() or 840
                local cols = Wc >= 1000 and 4 or 2
                stepRows = math.ceil(#steps / cols)
                local tw = (Wc - 32 - (cols - 1) * SG) / cols
                local r1, g1, b1 = UI:Accent()
                for i, t in ipairs(steps) do
                    local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
                    t:ClearAllPoints(); t:SetPoint("TOPLEFT", 16 + col * (tw + SG), -42 - row * (STH + SG)); t:SetWidth(tw)
                    if t.badge.bg and t.badge.bg.SetColor then t.badge.bg:SetColor(r1, g1, b1, 1) end
                end
                how.seenY = -42 - stepRows * (STH + SG) - 6
                if how.seenHead then how.seenHead:ClearAllPoints(); how.seenHead:SetPoint("TOPLEFT", 16, how.seenY) end
            end
            UI:OnResize(how, function() layoutSteps() end)
            table.insert(self.dyn, layoutSteps)
            local seenHead = UI:Text(how, 11, C.muted)
            how.seenHead = seenHead
            seenHead:SetPoint("TOPLEFT", 16, -42 - 2 * (STH + SG) - 6)
            seenHead:SetText(UI:Upper(T("Effets de camp rencontrés")))
            local seenText = dynText(how, 12, C.text, function()
                local g = WK.DB.global.camp and WK.DB.global.camp.seen or {}
                local KIND = { flame = T("flamme"), sit = T("assis"), perk = T("avantages") }
                local out = {}
                local ah = "|cff" .. WK:AccentHex()
                for id, kind in pairs(g) do
                    local name = (WK.SpellInfo and WK.SpellInfo(id)) or ("#" .. id)
                    table.insert(out, string.format("%s  " .. ah .. "%s|r  " .. UI:Hex(C.dim) .. "n° %d|r", name, KIND[kind] or kind, id))
                end
                table.sort(out)
                if #out == 0 then return UI:Hex(C.muted) .. T("Aucun pour l'instant : approche-toi d'un camp.") .. "|r" end
                local shown = {}
                for i = 1, math.min(#out, 8) do shown[i] = out[i] end
                return table.concat(shown, "\n")
            end)
            if seenText.SetSpacing then seenText:SetSpacing(4) end
            seenText:SetPoint("TOPLEFT", seenHead, "BOTTOMLEFT", 0, -6); seenText:SetPoint("RIGHT", -16, 0)
            seenText:SetJustifyH("LEFT")
            if seenText.SetWordWrap then seenText:SetWordWrap(true) end

            -- ce que tes persos peuvent apporter (selon leurs métiers)
            local CROWS = 10
            subtab("Objets par métier", 2)
            local contrib = card("Ce que tes persos peuvent apporter", 40 + CROWS * 20 + 30, "un objet par joueur et par camp")
            local ctext = dynText(contrib, 11, C.text, function()
                local list = Cp:Contributions()
                if #list == 0 then return UI:Hex(C.muted) .. T("Aucun : il faut 20 dans un métier (ou la Cuisine pour poser le feu).") .. "|r" end
                local lines, last = {}, nil
                for i, e in ipairs(list) do
                    if i > CROWS then table.insert(lines, string.format(UI:Hex(C.muted) .. T("+ %d autre(s)") .. "|r", #list - CROWS)) break end
                    local r, g, b = UI:ClassColor(e.c.class)
                    local who = e.key ~= last and string.format("|cff%02x%02x%02x%s|r  ", r * 255, g * 255, b * 255, WK:CharName(e.c, e.key)) or "      "
                    last = e.key
                    table.insert(lines, who .. e.item .. "  " .. UI:Hex(C.muted) .. "· " .. T(e.prof) .. " " .. e.rank .. " · " .. e.effect
                        .. (e.tier >= 2 and (" · " .. T("plan requis")) or "") .. "|r")
                end
                return table.concat(lines, "\n")
            end)
            ctext:SetPoint("TOPLEFT", 16, -42); ctext:SetPoint("RIGHT", -16, 0)
            ctext:SetJustifyH("LEFT")
            if ctext.SetWordWrap then ctext:SetWordWrap(false) end

            table.insert(self.dyn, function()
                local level = (UnitLevel and UnitLevel("player")) or 1
                local r1, g1, b1 = UI:Accent()
                -- meilleure compétence de tes persos dans chaque métier
                -- et compétence du perso connecté : « à toi » seulement s'il a le palier, sinon le nom du perso qui l'a
                local best, bestWho, bestClass, mine = {}, {}, {}, {}
                local meKey = WK:CharKey()
                for key, c in pairs(WK.DB.global.characters) do
                    for prof, p in pairs(c.professions or {}) do
                        local rk = type(p) == "table" and p.rank or 0
                        if rk > (best[prof] or 0) or (rk == best[prof] and key == meKey) then
                            best[prof] = rk
                            bestWho[prof] = c.name or string.match(key, "^([^%-]+)") or key
                            bestClass[prof] = c.class
                        end
                        if key == meKey then mine[prof] = rk end
                    end
                end
                for i, o in ipairs(Cp.OBJECTS) do
                    local t = tiles[i]
                    local has = Cp:Cancelled(o)
                    local eff = Cp:Effect(o, 1, level)
                    if not eff and type(o.text) == "table" then eff = T("pas d'effet de camp : nourriture et four") end
                    t.eff:SetText(eff or "")
                    -- couleur du perso qui apporte l'objet : accent si c'est toi, sinon sa couleur de classe
                    local oc = { r1, g1, b1 }
                    if (mine[o.prof] or 0) < Cp.RANKS[1] and (best[o.prof] or 0) >= Cp.RANKS[1] then oc = { UI:ClassColor(bestClass[o.prof]) } end
                    local function rowColor(need)
                        if (mine[o.prof] or 0) >= need then return r1, g1, b1 end
                        return UI:ClassColor(bestClass[o.prof])
                    end
                    if has then t.eff:SetTextColor(C.negative[1], C.negative[2], C.negative[3])
                    elseif o.steps or o.enchant or type(o.text) == "string" then t.eff:SetTextColor(oc[1], oc[2], oc[3])
                    else t.eff:SetTextColor(C.text[1], C.text[2], C.text[3]) end
                    t.excl:SetText(has and (UI:Hex(C.negative) .. string.format(T("annulé : tu as %s"), has) .. "|r")
                        or (o.exclLabel and string.format(T("ne se cumule pas avec %s"), T(o.exclLabel)) or T("se cumule avec tout")))
                    local rank = best[o.prof] or 0
                    for k = 1, 3 do
                        local row = t.tiers[k]
                        local name = Cp:Name(o, k)
                        if not name then name = k == 1 and o.prof == "Cuisine" and T("le feu de camp (ci-dessous)") or "-" end
                        local need = Cp.RANKS[k]
                        local reach = o.ids[k] and rank >= need
                        row.nm:SetText(name)
                        row.nm:SetTextColor(C.text[1], C.text[2], C.text[3])
                        local hr, hg, hb = rowColor(need)
                        row.rk:SetText(reach and string.format("|cff%02x%02x%02x%d|r", hr * 255, hg * 255, hb * 255, need) or need)
                        row.rk:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
                        row.hl:SetVertexColor(hr, hg, hb, reach and 0.12 or 0)
                        -- pastille : à toi / où en est ton meilleur perso / compétence requise / personne dans le métier
                        local label
                        if not o.ids[k] then label = nil
                        elseif reach and (mine[o.prof] or 0) >= need then label = T("à toi")
                        elseif reach then label = WK.Latin and WK.Latin(bestWho[o.prof] or "?") or bestWho[o.prof]
                        elseif rank <= 0 then label = T("aucun perso")
                        elseif k == 1 or rank >= Cp.RANKS[k - 1] then label = string.format("%s %d/%d", T(o.prof), rank, need)
                        else label = string.format(T("%d requis"), need) end
                        local pl = row.pill
                        pl:SetShown(label ~= nil)
                        if label then
                            pl.t:SetText(label)
                            pl:SetWidth(math.min(96, (pl.t:GetStringWidth() or 30) + 12))
                            if reach and (mine[o.prof] or 0) < need then
                                -- palier tenu par un autre de tes persos : son nom et le contour à sa couleur de classe
                                local cr, cg, cb = UI:ClassColor(bestClass[o.prof])
                                pl.bg:SetColor(C.surface[1], C.surface[2], C.surface[3], 1); pl.edge:SetColor(cr, cg, cb, 1)
                                pl.t:SetTextColor(cr, cg, cb)
                            elseif reach then
                                pl.bg:SetColor(r1, g1, b1, 1); pl.edge:SetColor(r1, g1, b1, 1)
                                pl.t:SetTextColor(C.onAccent[1], C.onAccent[2], C.onAccent[3])
                            else
                                pl.bg:SetColor(C.surface[1], C.surface[2], C.surface[3], 1); pl.edge:SetColor(C.border[1], C.border[2], C.border[3], 1)
                                pl.t:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
                            end
                        end
                    end
                end
                for i, f in ipairs(fires) do
                    f.name:SetText(Cp:FireName(i))
                    local reach = (best["Cuisine"] or 0) >= Cp.FIRES[i][3]
                    f.name:SetTextColor(C.text[1], C.text[2], C.text[3])
                    f.sub:SetText(string.format(reach and T("Cuisine %d · %d objets de camp en plus") or T("Cuisine %d requis · %d objets de camp en plus"),
                        Cp.FIRES[i][3], Cp.FIRES[i][4]))
                    if reach then f.sub:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) else f.sub:SetTextColor(C.gold[1], C.gold[2], C.gold[3]) end
                end
            end)

            -- bon à savoir : repos, sac de couchage
            subtab("Repos", 3)
            local bag = card("Repos et Sac de couchage douillet", 40 + 4 * 18 + 46 + 8)
            local bt = UI:Text(bag, 11, C.muted)
            bt:SetPoint("TOPLEFT", 16, -42); bt:SetPoint("RIGHT", -16, 0)
            bt:SetJustifyH("LEFT")
            if bt.SetWordWrap then bt:SetWordWrap(true) end
            bt:SetText(T("Tente de campement (Travail du cuir 20) : ton repos est porté à 5 % d'un niveau s'il est plus bas (une fois par heure).") .. "\n"
                .. T("Sac de couchage douillet : en t'y reposant, +1 % d'expérience gagnée par minute, jusqu'à 3 %. Les deux se cumulent.") .. "\n"
                .. T("Les effets de caractéristiques ne se cumulent pas avec le buff de classe équivalent : choisis plutôt un autre objet."))
            local bagBtn = UI:Button(bag, "Guider vers la quête du sac", nil, 28, "secondary", "guide")
            bagBtn:SetPoint("BOTTOMLEFT", 16, 12)
            bagBtn:SetScript("OnClick", function() Cp:GuideToBag() end)
            local bagWhere = dynText(bag, 10, C.dim, function()
                local q = Cp.BAG_QUEST[UnitFactionGroup and UnitFactionGroup("player") or ""]
                return q and string.format(T("Dès le niveau 14 · %s (%d, %d)"), T(q[4]), q[2], q[3]) or ""
            end)
            bagWhere:SetPoint("LEFT", bagBtn, "RIGHT", 12, 0)
        end

        -----------------------------------------------------------------------
        -- Expérience (Modules/XP.lua, UI/XPBar.lua)
        -----------------------------------------------------------------------
        section("xp")
        do
            local X = WK.modules.XP
            local xcfg = X:Config()
            local fmt, xdur = UI.FormatXP, UI.XPDuration
            local xsec = current
            local function xrefresh() if UI.RefreshXPBar then UI:RefreshXPBar() end end
            -- barre
            local xb = card("Barre d'expérience", 40 + 9 * 46 + 8, "XP, repos et quêtes à rendre")
            UI:SettingRow(xb, -40, "Afficher la barre", "Accent : ton XP ; bleu : ton repos ; jaune : l'XP des quêtes terminées à rendre (un trait marque où tu arriverais). Cachée au niveau maximum.",
                toggle(xb, function() return xcfg.bar end, function(v) xcfg.bar = v; xrefresh() end), 80)
            UI:SettingRow(xb, -86, "Compacte", "Juste la barre, sans les libellés (tout reste dans l'infobulle).",
                toggle(xb, function() return xcfg.compact end, function(v) xcfg.compact = v; xrefresh() end), 80)
            UI:SettingRow(xb, -132, "Sans fond", "Retire le cadre sombre autour de la barre : il ne reste que la barre et ses libellés (ombrés pour rester lisibles).",
                toggle(xb, function() return xcfg.noBg end, function(v) xcfg.noBg = v; xrefresh() end), 80)
            do
                local seg = UI:Segmented(xb, { { "above", "Au-dessus" }, { "below", "En dessous" } }, function(v) xcfg.textPos = v; xrefresh() end, 26)
                seg:Select(xcfg.textPos == "below" and "below" or "above")
                UI:SettingRow(xb, -224, "Place du texte", "Libellés (niveau, repos, à rendre) au-dessus ou en dessous de la barre.", seg, 200)
            end
            UI:SettingRow(xb, -178, "Texte au survol", "Les libellés (niveau, repos, à rendre) n'apparaissent qu'au survol de la barre ; leur place est gardée.",
                toggle(xb, function() return xcfg.textHover end, function(v) xcfg.textHover = v; xrefresh() end), 80)
            UI:SettingRow(xb, -270, "Largeur", "Élargis la barre jusqu'à toute la largeur de l'écran.",
                UI:Slider(xb, 240, 200, 1600, 20, function() return xcfg.width or 520 end, function(v) xcfg.width = v; xrefresh() end, "%d px"), 260)
            UI:SettingRow(xb, -316, "Épaisseur", "Hauteur de la barre elle-même.",
                UI:Slider(xb, 240, 4, 24, 1, function() return xcfg.thick or 8 end, function(v) xcfg.thick = v; xrefresh() end, "%d px"), 260)
            UI:SettingRow(xb, -362, "Prévenir d'un niveau à rendre", "Dans « À faire » : rendre tes quêtes terminées te ferait passer un niveau.",
                toggle(xb, function() return xcfg.levelAlert end, function(v)
                    xcfg.levelAlert = v
                    local XPm = WK.modules.XP
                    if XPm and XPm.CheckLevelAlert then XPm.CheckLevelAlert() end
                end), 80)
            UI:SettingRow(xb, -408, "Prévenir d'un repos plein", "Dans « À faire » : un de tes persos a fait le plein de repos (150 %), il gaspille du temps d'auberge.",
                toggle(xb, function() return xcfg.restAlert end, function(v) xcfg.restAlert = v end), 80)


            -- rythme de la session
            local xs = card("Rythme de la session", 40 + 5 * 20 + 44, "depuis la connexion")
            local xsText = dynText(xs, 12, C.text, function()
                local s = X.session
                local perHour, secs, mobs = X:Rate()
                if not perHour then return UI:Hex(C.muted) .. T("Pas encore d'XP gagnée pendant cette session.") .. "|r" end
                local lines = {
                    string.format(T("%s XP gagnée en %s  ·  %s / h"), fmt(s.gained), xdur(time() - s.start), fmt(perHour)),
                    string.format(T("Niveau suivant dans %s à ce rythme"), xdur(secs)),
                }
                if mobs then table.insert(lines, string.format(T("Environ %d monstre(s) comme le dernier (%s XP)"), mobs, fmt(s.lastKill))) end
                table.insert(lines, UI:Hex(C.muted) .. string.format(T("Monstres %s  ·  quêtes %s  ·  découverte %s"), fmt(s.mobs), fmt(s.quests), fmt(s.explore)) .. "|r")
                return table.concat(lines, "\n")
            end)
            xsText:SetPoint("TOPLEFT", 16, -42); xsText:SetPoint("RIGHT", -16, 0)
            xsText:SetJustifyH("LEFT")
            local xreset = UI:Button(xs, "Remettre à zéro", nil, 28, "secondary")
            xreset:SetPoint("BOTTOMLEFT", 16, 12)
            xreset:SetScript("OnClick", function() X:ResetSession(); WK:NotifyChanged() end)

            -- tous tes persos : une carte par perso (3 par ligne, 2 en fenêtre étroite) : niveau, barre XP + repos,
            -- XP restante, repos, plein dans combien de temps
            local AMAX, TH2, TG2 = 18, 116, 10
            local acols = 3
            local function aHeight(n) return 40 + math.max(1, math.ceil(n / acols)) * (TH2 + TG2) + 4 end
            local xa = card("Tous tes persos", aHeight(0), "repos estimé depuis leur déconnexion")
            local aempty = UI:Text(xa, 11, C.muted)
            aempty:SetPoint("TOPLEFT", 16, -44)
            aempty:SetText(T("Connecte tes persos une fois pour relever leur expérience."))
            local atiles = {}
            local function kv(t, y)
                local l = UI:Text(t, 11, C.muted); l:SetPoint("TOPLEFT", 12, y)
                local v = UI:Text(t, 11, C.text); v:SetPoint("TOPRIGHT", -12, y); v:SetJustifyH("RIGHT")
                return l, v
            end
            for i = 1, AMAX do
                local t = CreateFrame("Frame", nil, xa)
                t:SetHeight(TH2)
                UI:Panel(t, 9, C.surface2, C.border)
                t.icon = UI:RoundIcon(t, 28); t.icon:SetPoint("TOPLEFT", 12, -10)
                t.name = UI:Text(t, 12); t.name:SetPoint("TOPLEFT", 48, -10); t.name:SetPoint("TOPRIGHT", -52, -10); t.name:SetJustifyH("LEFT")
                if t.name.SetWordWrap then t.name:SetWordWrap(false) end
                t.sub = UI:Text(t, 10, C.muted); t.sub:SetPoint("TOPLEFT", 48, -27); t.sub:SetPoint("TOPRIGHT", -52, -27); t.sub:SetJustifyH("LEFT")
                if t.sub.SetWordWrap then t.sub:SetWordWrap(false) end
                t.lvl = UI:Text(t, 20); t.lvl:SetPoint("TOPRIGHT", -12, -10)
                -- barre comme celle du jeu : XP à la couleur d'accent, repos en bleu juste devant
                t.track = t:CreateTexture(nil, "ARTWORK")
                t.track:SetTexture("Interface\\Buttons\\WHITE8X8")
                t.track:SetVertexColor(C.border[1], C.border[2], C.border[3], 0.7)
                t.track:SetPoint("TOPLEFT", 12, -48); t.track:SetPoint("TOPRIGHT", -12, -48); t.track:SetHeight(8)
                t.xfill = t:CreateTexture(nil, "OVERLAY", nil, 1); t.xfill:SetTexture("Interface\\Buttons\\WHITE8X8")
                t.xfill:SetPoint("TOPLEFT", t.track, "TOPLEFT"); t.xfill:SetHeight(8)
                t.rfill = t:CreateTexture(nil, "OVERLAY", nil, 0); t.rfill:SetTexture("Interface\\Buttons\\WHITE8X8")
                t.rfill:SetHeight(8)
                t.l1, t.v1 = kv(t, -64); t.l1:SetText(T("XP"))
                t.l2, t.v2 = kv(t, -80); t.l2:SetText(T("Repos"))
                t.l3, t.v3 = kv(t, -96); t.l3:SetText(T("Plein dans"))
                t.full = CreateFrame("Frame", nil, t)
                t.full:SetSize(40, 15)
                UI:Panel(t.full, 7, { C.positive[1] * 0.3, C.positive[2] * 0.3, C.positive[3] * 0.3, 0.9 })
                t.full.t = UI:Text(t.full, 10, C.positive); t.full.t:SetPoint("CENTER")
                t.full.t:SetText(T("plein"))
                t:Hide()
                atiles[i] = t
            end
            local function ago(sec)
                if sec < 3600 then return string.format(T("il y a %d min"), math.max(1, math.floor(sec / 60))) end
                if sec < 86400 then return string.format(T("il y a %d h"), math.floor(sec / 3600)) end
                return string.format(T("il y a %d j"), math.floor(sec / 86400))
            end

            -- « Rythme de la session » et « Tous tes persos » sont des données : la page Persos les reprend
            -- (bouton Expérience) ; QoL > Expérience ne garde que la barre.
            xs.xpData, xa.xpData = true, true
            local extra = 0
            xsec.extraY = function() return extra end

            local function layoutTiles()
                local me = X:Me()
                local rows = {}
                for _, e in ipairs(UI:SortedCharacters()) do
                    if e.c.xp or e.c.level then table.insert(rows, e) end
                end
                local na = math.min(#rows, AMAX)
                aempty:SetShown(na == 0)
                local W = xa:GetWidth() or 840
                acols = W >= 900 and 3 or 2
                local tw = (W - 32 - (acols - 1) * TG2) / acols
                local bw = tw - 24
                local ar, ag, ab = UI:Accent()
                for i, t in ipairs(atiles) do
                    local e = rows[i]
                    if not e or i > na then t:Hide() else
                        local c, x = e.c, e.c.xp
                        local mine = e.key == WK:CharKey()
                        if mine then x = { level = me.level, cur = me.cur, max = me.max, rested = me.rested, resting = me.resting, at = time() } end
                        local col, row = (i - 1) % acols, math.floor((i - 1) / acols)
                        t:ClearAllPoints(); t:SetPoint("TOPLEFT", 16 + col * (tw + TG2), -40 - row * (TH2 + TG2)); t:SetWidth(tw)
                        UI:SetClassIcon(t.icon, c.class)
                        local cr, cg, cb = UI:ClassColor(c.class)
                        t.name:SetText(WK:CharName(c, e.key)); t.name:SetTextColor(cr, cg, cb)
                        local cls = T(WK.modules.QoL.CLASS_LABEL[c.class or ""] or "")
                        local seen = mine and T("maintenant") or (x and x.at and (ago(time() - x.at) .. " · " .. (x.resting and T("auberge") or T("dehors")))) or T("pas encore relevé")
                        t.sub:SetText(cls ~= "" and (cls .. " · " .. seen) or seen)
                        local lvl = (x and x.level) or c.level or 0
                        t.lvl:SetText(lvl)
                        local maxed = lvl >= X:MaxLevel()
                        t.xfill:SetVertexColor(ar, ag, ab, 1)
                        t.rfill:SetVertexColor(C.info[1], C.info[2], C.info[3], 0.85)
                        t.full:Hide()
                        if maxed or not x then
                            t.xfill:SetWidth(maxed and bw or 0.01); t.rfill:Hide()
                            t.v1:SetText(maxed and T("niveau maximum") or "?")
                            t.v2:SetText("-"); t.v3:SetText("-")
                            t.v2:SetTextColor(C.muted[1], C.muted[2], C.muted[3]); t.v3:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
                        else
                            local mx = math.max(1, x.max or 1)
                            local pc = math.max(0, math.min(1, (x.cur or 0) / mx))
                            local frac = X:RestOf(e.key) or 0
                            t.xfill:SetWidth(math.max(0.01, bw * pc))
                            local rw = math.min(1 - pc, frac) * bw
                            t.rfill:ClearAllPoints(); t.rfill:SetPoint("TOPLEFT", t.track, "TOPLEFT", bw * pc, 0)
                            t.rfill:SetWidth(math.max(0.01, rw)); t.rfill:SetShown(rw > 0.5)
                            t.v1:SetText(string.format(T("%d %% · %s restants"), math.floor(pc * 100), fmt(mx - (x.cur or 0))))
                            t.v2:SetText(string.format(T("%d %% d'un niveau"), math.floor(frac * 100)))
                            t.v2:SetTextColor(C.info[1], C.info[2], C.info[3])
                            local full = frac >= X.REST_MAX - 0.001
                            if full then
                                t.full:ClearAllPoints(); t.full:SetPoint("RIGHT", t.v2, "LEFT", -6, 0); t.full:Show()
                                t.v3:SetText(T("déjà plein")); t.v3:SetTextColor(C.positive[1], C.positive[2], C.positive[3])
                            else
                                t.v3:SetText(T("env.") .. " " .. xdur(X:RestFullIn(frac, x.resting)) .. " " .. (x.resting and T("en auberge") or T("dehors")))
                                t.v3:SetTextColor(C.text[1], C.text[2], C.text[3])
                            end
                        end
                        t:Show()
                    end
                end
                xa:SetHeight(aHeight(na))
                -- hauteur de la section
                local e2 = aHeight(na) - aHeight(0)
                if e2 ~= extra then
                    extra = e2
                    if xsec.tailY then xsec.scroll:SetContentHeight(xsec.tailY + extra) end
                end
            end
            table.insert(self.dyn, layoutTiles)
            UI:OnResize(xa, function() if xa:IsVisible() then layoutTiles() end end)
        end

        -----------------------------------------------------------------------
        -- Classes > Général : réglages communs à toutes les classes
        -----------------------------------------------------------------------
        do
            section("CLASSGEN", CLASSBAR_H)
            local CSc = function() local M = WK.modules.ClassSpells; return M and M:Config() or {} end
            local sp = card("Sorts de classe", 3 * 48 + 56)
            local rows = {
                { "Rappel au passage de niveau", "Dans le chat, une fois par niveau : les sorts à apprendre.",
                    function() return CSc().alert end,
                    function(v) CSc().alert = v; local M = WK.modules.ClassSpells; if M then M:CheckAlert() end end },
                { "Panneau chez le maître de classe", "À côté de la fenêtre du maître : ce qui est à apprendre, écartés compris.",
                    function() return CSc().panel end,
                    function(v) CSc().panel = v; if UI.RefreshClassTrainer then UI:RefreshClassTrainer() end end },
                { "Tout apprendre en ouvrant le maître", "Les sorts pas écartés, les moins chers d'abord, sans dépasser ton or.",
                    function() return CSc().autoLearn end, function(v) CSc().autoLearn = v end },
            }
            for i, r in ipairs(rows) do
                UI:SettingRow(sp, -44 - (i - 1) * 48, r[1], r[2], toggle(sp, r[3], r[4]), 80)
            end

            -- buffs à ne pas oublier (Modules/SelfBuffs.lua) : case de la barre des sacs, sens, et lieux par buff
            -- (entrées du perso connecté : classe, race, pistages de métier)
            local SB = WK.modules.SelfBuffs
            local ents = SB:Entries()
            local RH = 32
            local bc = card("Buffs à ne pas oublier", 44 + 48 + 26 + #ents * RH + 10,
                "case « buffs » de la barre des sacs : ce qui manque selon le lieu")
            local function bupdate()
                if UI.RefreshBagSpace then UI:RefreshBagSpace() end
                if UI.RefreshSelfBuffs then UI:RefreshSelfBuffs() end
            end
            local bgo = UI:Button(bc, T("Réglages de la barre"), nil, 24, "secondary")
            bgo:SetWidth(bgo.label:GetStringWidth() + 28)
            bgo:SetScript("OnClick", function() UI:OpenBagBarSettings() end)
            UI:SettingRow(bc, -44, "Case dans la barre des sacs",
                "La case « buffs » et le sens du déroulé se règlent avec la barre"
                    .. " « Sacs, marchand et maître ».",
                bgo, 200)
            local PL = { { "w", "Monde" }, { "d", "Donjon" }, { "r", "Raid" } }
            local hy = -44 - 48 - 6
            for j, pl in ipairs(PL) do
                local h = UI:Text(bc, 10, C.muted)
                h:SetPoint("TOPRIGHT", bc, "TOPRIGHT", -16 - (3 - j) * 56, hy)
                h:SetWidth(48); h:SetJustifyH("CENTER")
                h:SetText(T(pl[2]))
            end
            for i, it in ipairs(ents) do
                local ry = hy - 18 - (i - 1) * RH
                local nm = UI:Text(bc, 12)
                nm:SetPoint("TOPLEFT", bc, "TOPLEFT", 16, ry - 5)
                local knownId
                for _, id in ipairs(it.e.ids) do
                    if _G.IsPlayerSpell and _G.IsPlayerSpell(id) then knownId = id break end
                end
                local miss = knownId and "" or ("  " .. UI:Hex(C.muted) .. T("(pas encore appris)") .. "|r")
                nm:SetText(T(it.e.label) .. miss)
                for j, pl in ipairs(PL) do
                    local tg = toggle(bc, function() return SB:Places(it.rk, it.e):find(pl[1], 1, true) ~= nil end,
                        function(v) SB:SetPlace(it.rk, it.e, pl[1], v); bupdate() end)
                    tg:SetPoint("TOPRIGHT", bc, "TOPRIGHT", -20 - (3 - j) * 56, ry)
                end
            end
        end

        -----------------------------------------------------------------------
        -- Fiches de classe
        -----------------------------------------------------------------------
        self.tiles = {}
        for _, cl in ipairs(QoL.CLASSES) do
            local class = cl[1]
            local cc = q.classes[class]
            section(class, CLASSBAR_H)

            -- Persos de la classe (tuiles)
            local list = QoL:CharsOf(class)
            if #list == 0 then
                local empty = card(nil, 64)
                local t = UI:Text(empty, 12, C.muted)
                t:SetPoint("LEFT", 16, 0)
                t:SetPoint("RIGHT", -16, 0)
                t:SetText(string.format(T("Aucun %s pour l'instant : ces réglages serviront dès que tu en joueras un."), string.lower(T(cl[2]))))
            else
                -- Une tuile par perso sur toute la largeur : liseré et portrait à la couleur de classe,
                -- nom, puis trois colonnes (icône, valeur, libellé, petite jauge).
                local TILE_H, STEP = 64, 72
                local holder = CreateFrame("Frame", nil, root)
                holder:SetSize(W, #list * STEP - 8)
                holder:SetPoint("TOPLEFT", 0, -y)
                holder:SetPoint("TOPRIGHT", 0, -y)
                y = y + #list * STEP - 8 + GAP
                local tiles = {}
                local cr, cg, cb = UI:ClassColor(class)
                for i, e in ipairs(list) do
                    local tile = CreateFrame("Frame", nil, holder)
                    tile:SetHeight(TILE_H)
                    tile:SetPoint("TOPLEFT", 0, -(i - 1) * STEP)
                    tile:SetPoint("TOPRIGHT", 0, -(i - 1) * STEP)
                    UI:Panel(tile, 10, C.surface2, C.border)
                    tile.stripe = tile:CreateTexture(nil, "ARTWORK")
                    tile.stripe:SetColorTexture(cr, cg, cb, 1)
                    tile.stripe:SetPoint("TOPLEFT", 1, -6)
                    tile.stripe:SetPoint("BOTTOMLEFT", 1, 6)
                    tile.stripe:SetWidth(3)
                    tile.ring = UI:Icon(tile, "circle", 46, { cr, cg, cb, 1 })
                    tile.ring:SetPoint("LEFT", 16, 0)
                    tile.icon = UI:RoundIcon(tile, 42)
                    tile.icon:SetPoint("CENTER", tile.ring, "CENTER")
                    tile.name = UI:Text(tile, 13)
                    tile.name:SetPoint("TOPLEFT", 78, -15)
                    tile.sub = UI:Text(tile, 11, { cr, cg, cb, 1 })
                    tile.sub:SetPoint("TOPLEFT", tile.name, "BOTTOMLEFT", 0, -5)
                    tile.cols = {}
                    for k = 1, 3 do
                        local col = CreateFrame("Frame", nil, tile)
                        col:SetHeight(TILE_H - 16)
                        col.sep = col:CreateTexture(nil, "ARTWORK")
                        col.sep:SetColorTexture(unpack(C.border))
                        col.sep:SetPoint("TOPLEFT", 0, -4)
                        col.sep:SetPoint("BOTTOMLEFT", 0, 4)
                        col.sep:SetWidth(1)
                        col.iconBg = CreateFrame("Frame", nil, col)
                        col.iconBg:SetSize(32, 32)
                        col.iconBg:SetPoint("LEFT", 16, 0)
                        col.iconBgTex = UI:Rounded(col.iconBg, 8, 0, "BACKGROUND", 1)
                        col.icon = col.iconBg:CreateTexture(nil, "ARTWORK")
                        col.icon:SetPoint("TOPLEFT", 4, -4)
                        col.icon:SetPoint("BOTTOMRIGHT", -4, 4)
                        col.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                        col.value = UI:Text(col, 15)
                        col.value:SetPoint("TOPLEFT", col.iconBg, "TOPRIGHT", 12, 2)
                        col.label = UI:Text(col, 10, C.muted)
                        col.label:SetPoint("TOPLEFT", col.value, "BOTTOMLEFT", 0, -4)
                        col.label:SetPoint("RIGHT", col, "RIGHT", -8, 0)
                        col.bar = UI:Progress(col, 4)
                        col.bar:SetPoint("TOPLEFT", col.label, "BOTTOMLEFT", 0, -5)
                        col.bar:SetWidth(100)
                        tile.cols[k] = col
                    end
                    tile.e = e
                    tile.holder, tile.step = holder, STEP
                    table.insert(tiles, tile)
                    table.insert(self.tiles, tile)
                end
                UI:OnResize(holder, function(w)
                    local x0 = 250
                    local cw = math.max(110, (w - x0 - 8) / 3)
                    for _, tile in ipairs(tiles) do
                        for k, col in ipairs(tile.cols) do
                            col:ClearAllPoints()
                            col:SetPoint("TOPLEFT", tile, "TOPLEFT", x0 + (k - 1) * cw, -8)
                            col:SetWidth(cw)
                        end
                    end
                end)
            end

            -- HunterSuite chargé : nos aides de chasseur se mettent en retrait (désactivable)
            if class == "HUNTER" and WK.modules.Hunter:HunterSuiteLoaded() then
                local hs = card("HunterSuite est chargé", 96)
                hs.title:SetTextColor(unpack(C.warning))
                UI:SettingRow(hs, -40, "Garder aussi les aides de Warband Keeper",
                    "Sinon, cadre et bouton du familier, bouton d'aspect et rappels restent masqués pour ne pas faire doublon.",
                    toggle(hs, function() return cc.keepWithHunterSuite end, function(v)
                        cc.keepWithHunterSuite = v
                        UI:SyncPetCard(); UI:SyncAspectButton(); WK.modules.Hunter:SyncPetButton(); WK.modules.Hunter:UpdateAlerts()
                    end), 80)
            end

            -- Composants
            local reags = QoL.REAGENTS[class]
            if reags then
                subtab("Composants", 1)
                local rc = card("Composants", 92 + #reags * 46)
                local colA = UI:Text(rc, 10, C.dim); colA:SetPoint("TOPRIGHT", -176, -18); colA:SetText("ALERTE SOUS")
                local colB = UI:Text(rc, 10, C.dim); colB:SetPoint("TOPRIGHT", -84, -18); colB:SetText("ACHAT JUSQU'À")
                local colC = UI:Text(rc, 10, C.dim); colC:SetPoint("TOPRIGHT", -16, -18); colC:SetText("AUTO")
                UI:SettingRow(rc, -40, "Alertes", "Composants bas : dans « À faire », la fenêtre de connexion et l'en-tête.",
                    toggle(rc, function() return cc.alerts end, function(v) cc.alerts = v end), 80)
                for i, r in ipairs(reags) do
                    local s = cc.reag[r.key]
                    local ctl = CreateFrame("Frame", nil, rc)
                    ctl:SetSize(236, 28)
                    local inMin = UI:NumberInput(ctl, 60, 26, "0")
                    inMin:SetPoint("RIGHT", -176, 0)
                    inMin.onChange = function(text, user) if user then s.min = tonumber(text) or 0; WK:NotifyChanged() end end
                    table.insert(self.inputs, { box = inMin, get = function() return s.min or 0 end })
                    if r.buy then
                        local inBuy = UI:NumberInput(ctl, 60, 26, "0")
                        inBuy:SetPoint("RIGHT", -84, 0)
                        inBuy.onChange = function(text, user) if user then s.buy = tonumber(text) or 0 end end
                        table.insert(self.inputs, { box = inBuy, get = function() return s.buy or 0 end })
                        local tg = toggle(ctl, function() return s.auto end, function(v) s.auto = v end)
                        tg:SetPoint("RIGHT")
                    else
                        local na = UI:Text(ctl, 11, C.dim)
                        na:SetPoint("RIGHT", 0, 0)
                        na:SetText(r.conjured and "invoqué" or "pas en vente")
                    end
                    local row = UI:SettingRow(rc, -86 - (i - 1) * 46, QoL:ReagentName(r), " ", ctl, 236)
                    -- Nom de l'objet (peut arriver en différé) et stock de chaque perso.
                    table.insert(self.dyn, function()
                        row.label:SetText(QoL:ReagentName(r))
                        local lv = r.maxLvl and string.format(T("Niveaux %d à %d"), r.lvl, r.maxLvl) or string.format(T("Niveau %d+"), r.lvl or 1)
                        local stock = {}
                        for _, e in ipairs(list) do
                            if QoL:Relevant(r, e.c.level) and WK.DB.global.characters[e.key] then
                                local n = QoL:Count(e.c, r)
                                local col = (s.min or 0) > 0 and n < s.min and UI:Hex(C.warning) or UI:Hex(C.text)
                                table.insert(stock, WK:CharName(e.c, e.key) .. " " .. col .. num(n) .. "|r")
                            end
                        end
                        row.desc:SetText(lv .. (#stock > 0 and ("  ·  " .. table.concat(stock, ", ")) or ""))
                    end)
                end
            end

            -- Munitions
            if QoL.AMMO[class] then
                subtab("Munitions", 2)
                local am = card("Munitions", 186, class ~= "HUNTER" and "si tu tires à l'arc, au fusil ou à l'arbalète" or nil)
                UI:SettingRow(am, -40, "Alerte quand il en reste peu", "Type de munitions équipé, compté dans les sacs (0 : pas d'alerte au nombre).",
                    UI:Slider(am, 240, 0, 2000, 100, function() return cc.ammo.min or 0 end, function(v) cc.ammo.min = v; WK:NotifyChanged() end, "%d"), 260)
                UI:SettingRow(am, -88, "Ou en minutes de tir", "Alerte quand il reste moins de ce temps de tir, d'après ta vitesse de tir (0 : pas d'alerte en minutes).",
                    UI:Slider(am, 240, 0, 30, 1, function() return cc.ammo.minMinutes or 0 end, function(v) cc.ammo.minMinutes = v; WK:NotifyChanged() end, "%d min"), 260)
                local ctl = CreateFrame("Frame", nil, am)
                ctl:SetSize(320, 22)
                local sl = UI:Slider(ctl, 260, 200, 4000, 200, function() return cc.ammo.buy or 2000 end, function(v) cc.ammo.buy = v end, "%d")
                sl:SetPoint("LEFT")
                local tg = toggle(ctl, function() return cc.ammo.auto end, function(v) cc.ammo.auto = v end)
                tg:SetPoint("RIGHT")
                UI:SettingRow(am, -136, "Achat automatique chez le marchand", "Complète jusqu'à cette quantité avec la meilleure munition vendue pour ton arme et ton niveau.", ctl, 320)
            end

            -- Aides propres à la classe
            if class == "HUNTER" then
                subtab("Familier", 3)
                local pet = card("Familier", 232)
                UI:SettingRow(pet, -40, "Alerte si le familier n'est plus heureux", "À l'écran quand il change d'humeur, et dans « À faire ».",
                    toggle(pet, function() return cc.petAlert end, function(v) cc.petAlert = v end), 80)
                UI:SettingRow(pet, -136, "Bouton si le familier est absent ou mort", "Gros bouton rond qui apparaît tout seul, même en combat : clic pour appeler ou ressusciter. Maj + glisser pour le déplacer.",
                    toggle(pet, function() return cc.petButton ~= false end, function(v) cc.petButton = v; WK.modules.Hunter:SyncPetButton() end), 80)
                local foodRow = UI:SettingRow(pet, -88, "Nourriture qu'il accepte", " ", nil)
                table.insert(self.dyn, function()
                    local c = WK.DB:Me()
                    if c.class ~= "HUNTER" then
                        foodRow.desc:SetText(T("Connecte un chasseur pour voir la nourriture de son familier."))
                        return
                    end
                    local foods, names = QoL:FoodInBags(c), {}
                    for i, f in ipairs(foods) do
                        if i > 4 then break end
                        table.insert(names, (WK.GetItemInfo(f.id) or "?") .. " x" .. f.n)
                    end
                    local diet = c.pet and c.pet.diet or {}
                    local dietTxt = #diet > 0 and (table.concat(diet, ", ") .. "  ·  ") or ""
                    foodRow.desc:SetText(dietTxt .. (#names > 0 and table.concat(names, " · ")
                        or T("Rien qu'il accepte dans les sacs.")))
                end)
                local stable = UI:Button(pet, "Maître des écuries", nil, 28, "primary")
                stable:SetPoint("BOTTOMRIGHT", -12, 12)
                stable.tooltip = "Guide vers le maître des écuries le plus proche (aussi : /wk guide ecurie)."
                stable:SetScript("OnClick", function() WK.modules.Guide:GoTo("stable") end)
            elseif class == "ROGUE" then
                subtab("Poisons", 3)
                local po = card("Poisons", 184)
                UI:SettingRow(po, -40, "Alerte avant la fin des poisons", "Sur l'arme principale et la main gauche.",
                    toggle(po, function() return cc.poisonAlert end, function(v) cc.poisonAlert = v end), 80)
                UI:SettingRow(po, -88, "Prévenir à", "Minutes restantes.",
                    UI:Slider(po, 240, 1, 15, 1, function() return cc.poisonMin or 5 end, function(v) cc.poisonMin = v end, "%d min"), 260)
                local now = UI:SettingRow(po, -134, "Sur tes armes", " ", nil)
                table.insert(self.dyn, function()
                    if WK.DB:Me().class ~= "ROGUE" then now.desc:SetText(T("Connecte un voleur pour voir ses poisons.")) return end
                    local main, off = QoL:PoisonTimes()
                    now.desc:SetText(string.format(T("Arme principale : %s · Main gauche : %s"),
                        main and minutes(main) or T("rien"), off and minutes(off) or T("rien")))
                end)
                subtab("Crochetage", 4)
                local lock = card("Crochetage et vol à la tire", 196)
                local lt = dynText(lock, 12, C.text, function()
                    local boxes = QoL:Lockboxes()
                    local best = 0
                    for _, e in ipairs(list) do best = math.max(best, e.c.lockpick or 0) end
                    local lines = {}
                    for i, b in ipairs(boxes) do
                        if i > 5 then break end
                        local ok = best >= b.skill
                        table.insert(lines, string.format("%s%s|r x%d  ·  %s  ·  %s", ok and UI:Hex(C.positive) or UI:Hex(C.muted),
                            WK.GetItemInfo(b.id) or ("#" .. b.id), b.n, b.where,
                            string.format(T("Crochetage %d"), b.skill)))
                    end
                    if #boxes == 0 then table.insert(lines, T("Aucun coffre à crocheter dans les sacs de tes persos.")) end
                    local gold = {}
                    for _, e in ipairs(list) do
                        if (e.c.pickpocket or 0) > 0 and WK.DB.global.characters[e.key] then table.insert(gold, WK:CharName(e.c, e.key) .. " " .. WK:FormatMoney(e.c.pickpocket)) end
                    end
                    table.insert(lines, " ")
                    table.insert(lines, T("Or volé à la tire : ") .. (#gold > 0 and table.concat(gold, " · ") or "-"))
                    return table.concat(lines, "\n")
                end)
                lt:SetPoint("TOPLEFT", 16, -42)
                lt:SetPoint("TOPRIGHT", -16, -42)
                lt:SetJustifyV("TOP")
                if lt.SetWordWrap then lt:SetWordWrap(true) end
                lt:SetSpacing(5)
            elseif class == "WARLOCK" then
                subtab("Fragments d'âme", 3)
                local sh = card("Fragments d'âme", 140)
                UI:SettingRow(sh, -40, "Garder au maximum", "Le bouton supprime ceux en trop (Maj + clic, perso connecté).",
                    UI:Slider(sh, 240, 3, 40, 1, function() return cc.shardMax or 20 end, function(v) cc.shardMax = v; WK:NotifyChanged() end, "%d"), 260)
                local cur = dynText(sh, 11, C.muted, function()
                    local c = WK.DB:Me()
                    if c.class ~= "WARLOCK" then return T("Connecte un démoniste pour supprimer ses fragments en trop.") end
                    return string.format(T("Dans les sacs : %d / %d"), (c.bags or {})[6265] or 0, cc.shardMax or 20)
                end)
                cur:SetPoint("BOTTOMLEFT", 16, 20)
                local del = UI:Button(sh, "Supprimer le surplus", nil, 28, "danger", "trash")
                del:SetPoint("BOTTOMRIGHT", -12, 12)
                del.tooltip = "Maj + clic : supprime les fragments au-delà du maximum."
                del:SetScript("OnClick", function() if IsShiftKeyDown() then QoL:DeleteExtraShards() end end)
            elseif class == "MAGE" then
                subtab("Portails", 3)
                local pt = card("Annonce de portail", 140)
                local input = UI:Input(pt, 320, 28, "Portail vers %s, chuchote-moi !")
                input:SetText(cc.portalText or "")
                input.onChange = function(text, user) if user then cc.portalText = text end end
                UI:SettingRow(pt, -40, "Texte", "%s est remplacé par la ville.", input, 320)
                local holder = CreateFrame("Frame", nil, pt)
                holder:SetPoint("BOTTOMLEFT", 16, 12)
                holder:SetPoint("BOTTOMRIGHT", -12, 12)
                holder:SetHeight(28)
                self.portalButtons = UI:Pool(function()
                    local b = UI:Button(holder, "", 150, 28, "secondary")
                    b:SetScript("OnClick", function(s)
                        local txt = (cc.portalText and cc.portalText ~= "") and cc.portalText or T("Portail vers %s, chuchote-moi !")
                        WK.ChatInsert(string.format(txt:find("%%s") and txt or (txt .. " %s"), T(s.city)))
                    end)
                    return b
                end)
                local lbl = UI:Text(holder, 11, C.muted)
                lbl:SetPoint("LEFT")
                lbl:SetText("Mettre dans le chat :")
                table.insert(self.dyn, function()
                    local faction = UnitFactionGroup("player")
                    if WK.DB:Me().class ~= "MAGE" and list[1] then faction = list[1].c.faction or faction end
                    self.portalButtons:Reset()
                    local x = lbl:GetStringWidth() + 12
                    for _, city in ipairs(QoL.PORTALS[faction] or QoL.PORTALS.Alliance) do
                        local b = self.portalButtons:Get()
                        b.city = city
                        b.label:SetText(city)
                        b:SetWidth(b.label:GetStringWidth() + 28)
                        b:ClearAllPoints()
                        b:SetPoint("LEFT", x, 0)
                        x = x + b:GetWidth() + 8
                    end
                end)
            elseif class == "WARRIOR" then
                subtab("Armes", 3)
                local wp = card("Changement d'armes", 140)
                local function setRow(yy, which, label)
                    local ctl = CreateFrame("Frame", nil, wp)
                    ctl:SetSize(220, 28)
                    local eq = UI:Button(ctl, "Équiper", nil, 28, "primary")
                    eq:SetPoint("RIGHT")
                    eq:SetScript("OnClick", function() QoL:EquipWeaponSet(which) end)
                    local sv = UI:Button(ctl, "Enregistrer", nil, 28, "secondary")
                    sv:SetPoint("RIGHT", eq, "LEFT", -8, 0)
                    sv.tooltip = "Enregistre les armes portées maintenant par ce perso."
                    sv:SetScript("OnClick", function() QoL:SaveWeaponSet(which); WK:NotifyChanged() end)
                    local row = UI:SettingRow(wp, yy, label, " ", ctl, 220)
                    table.insert(self.dyn, function()
                        if WK.DB:Me().class ~= "WARRIOR" then row.desc:SetText(T("Connecte un guerrier pour enregistrer ses armes.")) return end
                        local s = QoL:WeaponSets()[which]
                        if not s or not s.main then row.desc:SetText(T("Pas encore enregistré.")) return end
                        local a = s.main and (WK.GetItemInfo(s.main) or "?")
                        local b = s.off and (WK.GetItemInfo(s.off))
                        row.desc:SetText(b and (a .. " + " .. b) or a)
                    end)
                end
                setRow(-40, "two", "Deux mains")
                setRow(-88, "shield", "Arme et bouclier")
            elseif class == "SHAMAN" then
                subtab("Réincarnation", 3)
                local rc = card("Réincarnation", 52 + math.max(1, #list) * 22 + 12)
                local t = dynText(rc, 12, C.text, function()
                    if #list == 0 then return T("Aucun chaman pour l'instant.") end
                    local lines = {}
                    for _, e in ipairs(list) do
                        local left = e.c.reincarnation and (e.c.reincarnation - time())
                        if WK.DB.global.characters[e.key] then table.insert(lines, WK:CharName(e.c, e.key) .. "  ·  " .. ((e.c.level or 0) < 30 and T("à partir du niveau 30")
                            or (left and minutes(left)) or T("pas encore vue"))) end
                    end
                    return table.concat(lines, "\n")
                end)
                t:SetPoint("TOPLEFT", 16, -42)
                t:SetJustifyV("TOP")
                if t.SetWordWrap then t:SetWordWrap(true) end
                t:SetSpacing(8)
            end
            if class == "HUNTER" then
                -- Cadre du familier (UI/PetCard.lua)
                local pc = UI.PetCardConfig()
                subtab("Familier", 3)
                local pcard = card("Cadre du familier", 40 + 12 * 46 + 8, "position et taille en mode édition")
                local py = -40
                local function prow(label, desc, ctl, w)
                    UI:SettingRow(pcard, py, label, desc, ctl, w)
                    py = py - 46
                end
                local function relayout() UI:PetCardLayout() end
                local function pseg(field, items)
                    local sg = UI:Segmented(pcard, items, function(v) pc[field] = v; relayout() end, 26)
                    sg:Select(pc[field])
                    return sg
                end
                local function pslider(field, mn, mx, st, fmtS)
                    return UI:Slider(pcard, 220, mn, mx, st, function() return pc[field] end, function(v) pc[field] = v; relayout() end, fmtS)
                end
                prow("Afficher le cadre", "Tant qu'un familier est là. Clic : nourrir · clic droit : soigner.",
                    toggle(pcard, function() return pc.enabled end, function(v) pc.enabled = v; UI:SyncPetCard() end), 80)
                prow("Largeur du cadre", nil, pslider("width", 200, 420, 10, "%d"), 240)
                prow("Hauteur de la barre de vie", nil, pslider("barH", 6, 24, 1, "%d px"), 240)
                prow("Chiffres sur la barre", nil, pseg("numbers", { { "none", "Aucun" }, { "value", "696" }, { "full", "696 / 720" }, { "pct", "97 %" } }), 300)
                prow("Couleur de la barre", nil, pseg("color", { { "mood", "Humeur" }, { "health", "Vie" }, { "theme", "Thème" } }), 240)
                prow("Humeur", nil, pseg("mood", { { "segments", "Segments" }, { "text", "Texte" }, { "both", "Les deux" }, { "hidden", "Masquée" } }), 320)
                prow("Nourriture", nil, pseg("food", { { "icon", "Icône et nombre" }, { "hidden", "Masquée" } }), 240)
                prow("Boutons Nourrir et Soigner", "Sinon : clic gauche et clic droit sur la carte.",
                    toggle(pcard, function() return pc.buttons end, function(v) pc.buttons = v; relayout() end), 80)
                prow("Nom et niveau du familier", nil, toggle(pcard, function() return pc.name end, function(v) pc.name = v; relayout() end), 80)
                prow("Afficher", "« Si besoin » : vie sous le seuil ci-dessous, ou humeur pas « heureux ».",
                    pseg("show", { { "always", "Toujours" }, { "ooc", "Hors combat" }, { "need", "Si besoin" } }), 280)
                prow("« Si besoin » : vie sous", nil, pslider("needHealth", 10, 100, 5, "%d %%"), 240)
                prow("Opacité hors combat", nil, pslider("oocAlpha", 0.3, 1, 0.05, "%.2f"), 240)

                -- Indicateur de distance (UI/RangeRing.lua)
                local rg = UI.RangeConfig()
                subtab("Distance", 4)
                local rcard = card("Indicateur de distance", 40 + 7 * 46 + 8, "position et taille en mode édition")
                local ry = -40
                local function rrow(label, desc, field, after)
                    UI:SettingRow(rcard, ry, label, desc, toggle(rcard, function() return rg[field] end,
                        function(v) rg[field] = v; if after then after() end end), 80)
                    ry = ry - 46
                end
                rrow("Afficher la règle", "Orange : corps à corps · jaune : zone morte · vert : à portée de tir · rouge : trop loin. Un curseur blanc montre la distance.", "enabled", function() UI:SyncRange() end)
                UI:SettingRow(rcard, ry, "Largeur", "Pour l'aligner sur une barre de vie.",
                    UI:Slider(rcard, 220, 90, 320, 5, function() return rg.width or 150 end, function(v) rg.width = v end, "%d px"), 240)
                ry = ry - 46
                rrow("Texte au-dessus", "La zone et la fourchette estimée, par exemple « À portée · 22-25 m ».", "numbers")
                rrow("Fond sombre", nil, "backdrop")
                rrow("Seulement en combat", nil, "combatOnly")
                rrow("Masquer sans cible", "Sinon, la règle reste affichée, estompée.", "hideNoTarget")
                rrow("Zone morte en jaune", "Entre 5 et 8 m, ni tir ni corps à corps (sinon en orange).", "deadZone")

                -- Bouton d'aspect (UI/AspectButton.lua)
                local ab = UI.AspectButtonConfig()
                local H = WK.modules.Hunter
                subtab("Aspects", 5)
                local acard = card("Bouton d'aspect", 40 + (2 + #H.ASPECT_ORDER) * 44 + 8, "raccourcis : Options > Raccourcis > AddOns")
                local ay = -40
                local function arow(label, desc, ctl, w) UI:SettingRow(acard, ay, label, desc, ctl, w); ay = ay - 44 end
                arow("Afficher le bouton", "Clic : aspect suivant de la liste · clic droit : aspect principal.",
                    toggle(acard, function() return ab.enabled end, function(v) ab.enabled = v; UI:SyncAspectButton() end), 80)
                local opts = {}
                for _, key in ipairs(H.ASPECT_ORDER) do table.insert(opts, { key, WK.SpellInfo(H.ASPECTS[key]) or key }) end
                local dd = UI:Dropdown(acard, 220, 28, opts, function(v) ab.main = v; UI:AspectButtonSetup() end)
                dd:Select(ab.main)
                arow("Aspect principal (clic droit)", nil, dd, 240)
                for _, key in ipairs(H.ASPECT_ORDER) do
                    local name = WK.SpellInfo(H.ASPECTS[key]) or key
                    arow(name, nil, toggle(acard, function() return ab.list[key] end,
                        function(v) ab.list[key] = v or nil; UI:AspectButtonSetup() end), 80)
                end

            end
            -- Bénédictions du paladin : barre, répartition entre paladins (UI/BlessingBar.lua)
            if class == "PALADIN" and UI.BuildBlessingCards then
                subtab("Bénédictions", 8)
                UI:BuildBlessingCards(card, toggle, self.dyn)
            end
            -- Buffer les joueurs autour (UI/BuffButton.lua)
            if WK.BUFF_CLASSES and WK.BUFF_CLASSES[class] then
                subtab("Buffer autour", 7)
                local pal = class == "PALADIN"
                local bb = card("Buffer autour de toi", 40 + (pal and 7 or 6) * 46 + 8, "un bouton : le joueur proche qui n'a pas ton buff, un clic ou une touche")
                local function bt(field) return toggle(bb, function() return cc[field] ~= false end, function(v)
                    cc[field] = v; UI:SyncBuffPlates(); UI:RefreshBuffButton() end) end
                local by = -40
                UI:SettingRow(bb, by, "Bouton « Buffer le suivant »", "Se place en mode édition. Touche : Options du jeu > Raccourcis > Warband Keeper. Jamais en combat, ni sur un joueur en combat ou JcJ (sauf si tu l'es). Paladin en groupe, raid ou donjon : il bénit tout le monde selon la répartition des bénédictions.", bt("buffAround"), 80)
                by = by - 46
                if pal then
                    UI:SettingRow(bb, by, "Rois d'abord", "Si tu connais Rois ; sinon Puissance pour guerrier, voleur et chasseur, Sagesse pour les autres.", bt("kingsFirst"), 80)
                    by = by - 46
                end
                local seg = UI:Segmented(bb, { { 1, "1 min" }, { 3, "3 min" }, { 0, "jamais" } }, function(v) cc.buffRefresh = v end, 26)
                table.insert(self.dyn, function() seg:Select(cc.buffRefresh or 3) end)
                UI:SettingRow(bb, by, "Remettre un buff qui finit dans moins de", nil, seg, 220)
                by = by - 46
                UI:SettingRow(bb, by, "En instance", nil, toggle(bb, function() return cc.buffInstance end, function(v) cc.buffInstance = v end), 80)
                by = by - 46
                UI:SettingRow(bb, by, "Sur une monture", nil, toggle(bb, function() return cc.buffMounted end, function(v) cc.buffMounted = v end), 80)
                by = by - 46
                UI:SettingRow(bb, by, "Plaques de nom des joueurs amis", "Allumées par l'addon hors combat : il en a besoin pour savoir qui est autour (rendues comme avant si tu coupes le bouton).", bt("buffPlates"), 80)
                by = by - 46
                UI:SettingRow(bb, by, "Taille du repère au-dessus du joueur", "L'icône du sort qui va partir, au-dessus de la plaque de nom du joueur à buffer.",
                    UI:Slider(bb, 220, 20, 48, 2, function() return cc.buffMarkSize or 30 end, function(v) cc.buffMarkSize = v; UI:RefreshBuffButton() end, "%d"), 240)
            end
        end
        closeSection()
        self:ShowSection(ui.qolSection or "general")
    end,

    Refresh = function(self)
        if self.LayoutNav then self:LayoutNav() end
        local QoL = Q()
        local played = QoL:PlayedClasses()
        local alerts = QoL:Alerts()
        local byClass, general = {}, 0
        for _, a in ipairs(alerts) do
            if a.class then byClass[a.class] = (byClass[a.class] or 0) + 1 else general = general + 1 end
        end
        for key, b in pairs(self.navButtons) do
            if key == "general" then
                b.count:SetText(general > 0 and tostring(general) or "")
            elseif key == "maplayers" then
                local n = 0
                for _, v in pairs(WK.modules.MapLayers:Config().map) do if v then n = n + 1 end end
                b.desc:SetText(string.format(T("%d types de lieux affichés"), n))
                b.count:SetText("")
            elseif key == "ah" then
                local n = WK.modules.AHScan:Count()
                b.desc:SetText(n > 0 and string.format(T("%d prix connus"), n) or T("Pas encore de scan"))
                b.count:SetText("")
            elseif key == "fishing" then
                local F2 = WK.modules.Fishing
                local sk = F2:Skill()
                b.desc:SetText(F2.active and T("Mode pêche ouvert") or (sk and string.format(T("Compétence %d"), sk) or T("Pas appris sur ce perso")))
                b.count:SetText("")
            elseif key == "micro" then
                b.desc:SetText(UI.ClockConfig().enabled and T("Activé") or T("Désactivé"))
                b.count:SetText("")
            elseif key == "halo" then
                local G = WK.modules.Glow
                local on = G:Config().enabled and not G:OtherAddonLoaded()
                b.desc:SetText(on and T("Activé") or T("Désactivé"))
                b.count:SetText("")
            elseif key == "classes" then
                local total, kinds = 0, 0
                for _, cl in ipairs(QoL.CLASSES) do
                    total = total + (byClass[cl[1]] or 0)
                    if played[cl[1]] then kinds = kinds + 1 end
                end
                b.desc:SetText(string.format(kinds > 1 and T("%d classes jouées") or T("%d classe jouée"), kinds))
                b.count:SetText(total > 0 and tostring(total) or "")
            end
            b:Paint()
        end
        for key, t in pairs(self.classTabs) do
          if key ~= "CLASSGEN" then
            local n = #QoL:CharsOf(key)
            t.played = played[key] or false
            t.tip = n == 0 and T("Aucun perso") or string.format(n > 1 and T("%d persos") or T("%d perso"), n)
            local a = byClass[key] or 0
            t.count:SetShown(a > 0)
            if a > 0 then t.count:Set(tostring(a), C.warning) end
            t:Paint()
          end
        end
        -- tuiles de classe : perso supprimé masqué, les suivantes remontent
        local slot = {}
        for _, tile in ipairs(self.tiles) do
            local e = tile.e
            local alive = WK.DB.global.characters[e.key] ~= nil
            tile:SetShown(alive)
            if alive then
                local n = slot[tile.holder] or 0
                slot[tile.holder] = n + 1
                tile:ClearAllPoints()
                tile:SetPoint("TOPLEFT", 0, -n * tile.step)
                tile:SetPoint("TOPRIGHT", 0, -n * tile.step)
            end
            UI:SetCharIcon(tile.icon, e.c, e.key)
            tile.name:SetText(WK:CharName(e.c, e.key))
            tile.sub:SetText(T(QoL.CLASS_LABEL[e.c.class] or "?") .. " · " .. string.format(T("niveau %s"), tostring(e.c.level or "?")))
            local stats = charStats(e.c)
            for k, col in ipairs(tile.cols) do
                local st = stats[k]
                col:SetShown(st ~= nil)
                if st then
                    local sc = st.color or C.text
                    col.icon:SetTexture(st.icon)
                    col.iconBgTex:SetColor(sc[1], sc[2], sc[3], 0.18)
                    col.value:SetText(st.value)
                    col.value:SetTextColor(unpack(sc))
                    col.label:SetText(st.label)
                    col.bar:SetShown(st.ratio ~= nil)
                    col.bar.color = (sc == C.text) and C.positive or sc
                    col.bar:SetValue(st.ratio or 0)
                end
            end
        end
        for _, t in ipairs(self.toggles) do t:Refresh() end
        for _, inp in ipairs(self.inputs) do
            if not inp.box.edit:HasFocus() then inp.box:SetText(tostring(inp.get())) end
        end
        for _, fn in ipairs(self.dyn) do fn() end
        -- cartes reprises d'Options (onglet Alertes) : leurs interrupteurs sont tenus par Options
        local od = UI.pages.options
        if od and od.frame and od.Refresh then pcall(od.Refresh, od) end
    end,
})
