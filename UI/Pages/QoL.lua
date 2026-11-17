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
    { "fishing", "Pêche", "fish" }, { "maplayers", "Carte", "map" }, { "ah", "Hôtel des ventes", "coin" },
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
        local function section(key, top)
            if current then current.tailY = y; current.scroll:SetContentHeight(y + (current.extraY and current.extraY() or 0)) end
            local sc = UI:Scroll(host)
            sc:SetPoint("TOPLEFT", 0, -(top or 0))
            sc:SetPoint("BOTTOMRIGHT")
            sc:Hide()
            current = { scroll = sc }
            self.sections[key] = current
            root, y = sc.child, 0
        end
        local function card(title, h, subtitle)
            local c = UI:Card(root, title, subtitle)
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
        local mapBtn = navButton("maplayers", "Carte", -208, nil, "map")
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
        local NAV_ORDER = { "general", "halo", "micro", "fishing", "maplayers", "ah", "cursor", "campfire", "xp", "classes" }
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
        for _, cl in ipairs(QoL.CLASSES) do
            local key = cl[1]
            local t = CreateFrame("Button", nil, classBar)
            t:SetHeight(48)
            t.bg = UI:Rounded(t, 10, 0, "BACKGROUND", 1)
            t.icon = UI:RoundIcon(t, 24)
            UI:SetClassIcon(t.icon, key)
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

        local shop = card("Marchand", 322)
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
        UI:SettingRow(shop, -274, "Composants de métier à côté du marchand", "Ce qui manque pour monter tes métiers jusqu'au palier choisi dans le guide (75, 150… ou Max), avec Acheter et Tout acheter. Seulement chez un marchand qui en vend.",
            toggle(shop, function() return ui.merchantPanel ~= false end, function(v) ui.merchantPanel = v end), 80)

        -- État des persos : seuils puis une ligne par perso
        local chars = UI:SortedCharacters()
        local state = card("État des persos", 172 + #chars * 30)
        UI:SettingRow(state, -40, "Alerte de durabilité", "Quand la pièce la plus abîmée passe sous ce seuil (0 : pas d'alerte).",
            UI:Slider(state, 240, 0, 90, 5, function() return g.durability or 0 end, function(v) g.durability = v; WK:NotifyChanged() end, "%d %%"), 260)
        UI:SettingRow(state, -88, "Sacs et banque presque pleins", "Quand il reste moins de places libres que ça (0 : pas d'alerte). La banque est relevée à chaque visite.",
            UI:Slider(state, 240, 0, 20, 1, function() return g.freeSlots or 0 end, function(v) g.freeSlots = v; WK:NotifyChanged() end, "%d"), 260)
        local hdrY = -142
        local h1 = UI:Text(state, 10, C.dim); h1:SetPoint("TOPLEFT", 16, hdrY); h1:SetText("PERSO")
        local h2 = UI:Text(state, 10, C.dim); h2:SetPoint("TOPRIGHT", -210, hdrY); h2:SetText("DURABILITÉ")
        local h3 = UI:Text(state, 10, C.dim); h3:SetPoint("TOPRIGHT", -16, hdrY); h3:SetText("SACS · BANQUE")
        for i, e in ipairs(chars) do
            local ry = hdrY - 18 - (i - 1) * 30
            local icon = UI:RoundIcon(state, 18)
            icon:SetPoint("TOPLEFT", 16, ry)
            UI:SetCharIcon(icon, e.c, e.key)
            local n = UI:Text(state, 12, classColor(e.c.class))
            n:SetPoint("TOPLEFT", 42, ry - 2)
            n:SetText(WK:CharName(e.c, e.key))
            dynText(state, 12, C.text, function(t)
                local d = e.c.durability
                t:SetTextColor(unpack((d and d < (g.durability or 0)) and C.negative or C.text))
                return d and (d .. " %") or "-"
            end):SetPoint("TOPRIGHT", -210, ry - 2)
            dynText(state, 12, C.text, function(t)
                local f = e.c.freeSlots
                t:SetTextColor(unpack((f and f < (g.freeSlots or 0)) and C.warning or C.text))
                local bf = e.c.bankFree
                local warn = (f and f < (g.freeSlots or 0)) or (bf and bf < (g.freeSlots or 0))
                t:SetTextColor(unpack(warn and C.warning or C.text))
                return (f and string.format("%d / %d", f, e.c.totalSlots or 0) or "-") .. "  ·  "
                    .. (bf and string.format("%d / %d", bf, e.c.bankSlots or 0) or "-")
            end):SetPoint("TOPRIGHT", -16, ry - 2)
        end

        -- Guidage vers le lieu utile le plus proche (Modules/Guide.lua)
        local G = WK.modules.Guide
        local gcfg = G:Config()
        local guide = card("Guidage", 410)
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

        local grp = card("Groupe et duels", 184)
        UI:SettingRow(grp, -40, "Accepter les invitations", "De tes amis et des membres de ta guilde.",
            toggle(grp, function() return g.acceptInvites end, function(v) g.acceptInvites = v end), 80)
        UI:SettingRow(grp, -88, "Refuser les duels", nil,
            toggle(grp, function() return g.declineDuels end, function(v) g.declineDuels = v end), 80)
        UI:SettingRow(grp, -130, "Sauf ceux des amis et de la guilde", nil,
            toggle(grp, function() return g.duelFriends end, function(v) g.duelFriends = v end), 80)

        local comfort = card("Confort", 284)
        UI:SettingRow(comfort, -40, "Libérer l'esprit en champ de bataille", "Automatiquement à la mort (pas avec une pierre d'âme).",
            toggle(comfort, function() return g.releaseBG end, function(v) g.releaseBG = v end), 80)
        UI:SettingRow(comfort, -88, "Confirmer le butin lié quand ramassé", "Seulement quand tu es seul.",
            toggle(comfort, function() return g.confirmBoP end, function(v) g.confirmBoP = v end), 80)
        UI:SettingRow(comfort, -136, "Descendre de monture ou se lever", "Quand une action l'exige (sort, maître de vol, butin…).",
            toggle(comfort, function() return g.dismount end, function(v) g.dismount = v end), 80)
        UI:SettingRow(comfort, -184, "Passer les cinématiques", nil,
            toggle(comfort, function() return g.skipCinematics end, function(v) g.skipCinematics = v end), 80)
        UI:SettingRow(comfort, -226, "Barre de vol", "Trajet, temps restant et bouton « Atterrir » pendant un vol. Se place en mode édition.",
            toggle(comfort, function() return WK.modules.Flight:Config().enabled end, function(v) WK.modules.Flight:Config().enabled = v end), 80)

        -----------------------------------------------------------------------
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
            catToggle:Refresh(); diffToggle:Refresh(); infoToggle:Refresh()
            catFx:Select(gcfg.fx[selCat] or "")
            for _, sb in ipairs(swatches) do
                local same = math.abs(sb.col[1] - col[1]) < 0.02 and math.abs(sb.col[2] - col[2]) < 0.02 and math.abs(sb.col[3] - col[3]) < 0.02
                sb.ring:SetColor(1, 1, 1, same and 1 or 0)
            end
            diffRow:SetAlpha(diffable and 1 or 0.4)
        end
        UI:OnResize(acard, function(w) layoutChips(w) end)
        layoutChips(acard:GetWidth())
        table.insert(self.dyn, function() haloPaint() end)
        haloPaint()


        local gmain = card("Halo", 354)
        UI:SettingRow(gmain, -40, "Halo sur l'objet visé",
            "Plantes, filons, coffres, objets de quête et flotteur brillent à ton approche. À éteindre avant de désinstaller l'addon.",
            gtoggle(gmain, function() return gcfg.enabled end, function(v) Gm:SetEnabled(v) end), 80)
        UI:SettingRow(gmain, -92, "Portée", "Distance à laquelle le jeu désigne un objet. Le jeu ne va pas au-delà de 15 m environ.",
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
        local clockCard = card("Horloge et raccourcis", 40 + 11 * 46 + 30 + 128, "les raccourcis se déplient au survol de l'heure")
        -- en haut : les raccourcis (barre telle qu'à l'écran) ; les réglages en dessous
        local TOPBOX = 40 + 26 + 56 + 8 + 34 + 26
        local cy = -TOPBOX
        local function crow(label, desc, ctl, w) UI:SettingRow(clockCard, cy, label, desc, ctl, w); cy = cy - 46 end
        local function csync() UI:SyncClock() end
        crow("Afficher l'horloge", "En haut de l'écran ; se place en mode édition.",
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
        crow("Effet loupe", "Grossissement des raccourcis sous la souris (0 : aucun).",
            UI:Slider(clockCard, 220, 0, 150, 10, function() return math.floor((ck.magnify or 0) * 100 + 0.5) end,
                function(v) ck.magnify = v / 100 end, "%d %%"), 240)
        crow("FPS et latence", "Deux petites barres sous l'heure (vert, orange, rouge).",
            toggle(clockCard, function() return ck.stats end, function(v) ck.stats = v end), 80)
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
        local nRows, nFam = #ML.LAYERS, #ML.FAMILIES
        local lcard = card("Sur les cartes", 40 + 22 + nFam * 26 + nRows * 36 + 8, "une pastille par lieu ; sur la carte du monde, clic pour guider")
        local hdr1 = UI:Text(lcard, 10, C.dim)
        hdr1:SetPoint("TOPRIGHT", -78, -44)
        hdr1:SetText(T("CARTE"))
        local hdr2 = UI:Text(lcard, 10, C.dim)
        hdr2:SetPoint("TOPRIGHT", -16, -44)
        hdr2:SetText(T("MINICARTE"))
        local ly = -62
        for _, fam in ipairs(ML.FAMILIES) do
            local fl = UI:Text(lcard, 10, C.dim)
            fl:SetPoint("TOPLEFT", 16, ly - 8)
            fl:SetText(UI:Upper(T(fam.label)))
            ly = ly - 26
            for _, l in ipairs(ML.LAYERS) do
                if l.family == fam.key then
                    local ctl = CreateFrame("Frame", nil, lcard)
                    ctl:SetSize(130, 24)
                    local t1 = toggle(ctl, function() return mlc.map[l.key] end, function(v) mlc.map[l.key] = v; mlRefresh() end)
                    t1:SetPoint("RIGHT", -72, 0)
                    local t2 = toggle(ctl, function() return mlc.mini[l.key] end, function(v) mlc.mini[l.key] = v; mlRefresh() end)
                    t2:SetPoint("RIGHT", -8, 0)
                    local row = UI:SettingRow(lcard, ly, l.label, nil, ctl, 130)
                    local dot = UI:Icon(row, "circle", 18, nil, "ARTWORK")
                    dot:SetPoint("LEFT", 0, 0)
                    dot:SetVertexColor(fam.color[1], fam.color[2], fam.color[3])
                    local ic = UI:Icon(row, l.icon, 10, nil, "OVERLAY")
                    ic:SetPoint("CENTER", dot, "CENTER")
                    ic:SetVertexColor(unpack(C.bg))
                    row.label:ClearAllPoints(); row.label:SetPoint("LEFT", 28, 0)
                    ly = ly - 36
                end
            end
        end
        local fcard = card("Filtres et affichage", 40 + 5 * 46 + 8)
        UI:SettingRow(fcard, -40, "Seulement ma faction", "Pas les lieux ni les trajets réservés à l'autre faction.",
            toggle(fcard, function() return mlc.myFaction end, function(v) mlc.myFaction = v; mlRefresh() end), 80)
        UI:SettingRow(fcard, -86, "Seulement ma classe", "Maître de classe, familiers et démons, munitions (chasseur), poisons (voleur), écuries.",
            toggle(fcard, function() return mlc.myClass end, function(v) mlc.myClass = v; mlRefresh() end), 80)
        UI:SettingRow(fcard, -132, "Seulement mes métiers", "Les maîtres des métiers que ce perso a appris.",
            toggle(fcard, function() return mlc.myProfs end, function(v) mlc.myProfs = v; mlRefresh() end), 80)
        UI:SettingRow(fcard, -178, "Barre de filtres sur la carte du monde", "En haut de la carte : clic sur une famille pour l'afficher ou la masquer, clic droit pour le détail.",
            toggle(fcard, function() return mlc.toolbar end, function(v) mlc.toolbar = v; mlRefresh() end), 80)
        UI:SettingRow(fcard, -224, "Taille des pastilles", nil,
            UI:Slider(fcard, 220, 12, 30, 1, function() return mlc.size or 18 end, function(v) mlc.size = v; mlRefresh() end, "%d"), 240)
        -- Navigation : trajet en pointillé qui suit les chemins connus, appris en jouant (Modules/Nav.lua)
        local GD, NV = WK.modules.Guide, WK.modules.Nav
        local gdc = GD:Config()
        local function replan() if GD.target then NV:Plan(GD.target) end; if UI.RefreshNavRoute then UI:RefreshNavRoute() end end
        local rcard = card("Navigation", 40 + 4 * 46 + 44, "trajet du guidage, appris en jouant")
        UI:SettingRow(rcard, -40, "Trajet sur la carte du monde", "Pointillés de ta couleur, de toi jusqu'au lieu guidé, en suivant les chemins connus (vols compris).",
            toggle(rcard, function() return gdc.route end, function(v) gdc.route = v; replan() end), 80)
        UI:SettingRow(rcard, -86, "Trajet sur la minicarte", nil,
            toggle(rcard, function() return gdc.routeMini end, function(v) gdc.routeMini = v; replan() end), 80)
        UI:SettingRow(rcard, -132, "Apprendre les chemins", "Note les chemins que tu parcours à pied ou à monture (hors vol et instances), sur tous tes persos : les trajets les suivent ensuite.",
            toggle(rcard, function() return gdc.learn end, function(v) gdc.learn = v; if not v then NV:EndTrail() end end), 80)
        local forget = UI:Button(rcard, "Oublier les chemins appris", nil, 28, "ghost")
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
        -- Points de vol à apprendre (Modules/Flight.lua) : maîtres de vol du continent pas encore appris
        do
            local FL = WK.modules.Flight
            local flc = FL.Config()
            local FPR = 6
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
        local hcard = card("Hôtel des ventes", 40 + 4 * 46 + 8, "scan, prix et listes d'achat")
        UI:SettingRow(hcard, -40, "Panneau à côté de l'HV", "Nombre de prix connus, dernier scan et bouton « Scanner l'HV ».", atoggle(hcard, "panel"), 80)
        UI:SettingRow(hcard, -86, "Scan complet à l'ouverture", "Dès que le jeu l'autorise (environ toutes les 15 minutes).", atoggle(hcard, "auto"), 80)
        UI:SettingRow(hcard, -132, "Prix dans l'infobulle", "Prix le plus bas à l'unité, moyenne sur 14 jours, quantité en vente et date du relevé.", atoggle(hcard, "tooltip"), 80)
        UI:SettingRow(hcard, -178, "Prix de la pile", "Ajoute le prix d'une pile entière pour les objets qui s'empilent.", atoggle(hcard, "stack"), 80)
        local scard = card("Prix relevés", 40 + 2 * 46 + 8, "pour ce royaume et cette faction")
        local stat = dynText(scard, 12, C.text, function()
            local d = AS:Data()
            return string.format(T("%d objets avec un prix"), AS:Count()) .. "  ·  " ..
                (d.last and (T("dernier scan le") .. " " .. date("%d/%m %H:%M", d.last)) or T("aucun scan pour l'instant"))
        end)
        UI:SettingRow(scard, -40, "État", nil, stat, 420)
        local wipe = UI:Button(scard, "Effacer les prix", 150, 28, "ghost")
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
            r.del = UI:IconButton(r, "trash", 24, "Retirer cette alerte")
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
                    r.info:SetText(T("max") .. " " .. UI:ExactMoney(a.max) .. "  ·  " .. (a.hit and ("|cff9ed17a" .. now .. "|r") or now))
                    r.del:SetScript("OnClick", function() AV:RemoveAlert(a.id); WK:NotifyChanged() end)
                end
            end
        end)

        -----------------------------------------------------------------------
        -- Pêche (Modules/Fishing.lua, UI/FishingBar.lua)
        -----------------------------------------------------------------------
        section("fishing")
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
            -- en ce moment
            local now = card("En ce moment", 40 + 70 + 44, "mis à jour en direct")
            local nowText = dynText(now, 12, C.text, function()
                local a = Cp.auras or {}
                local st = Cp.state or "none"
                local lines = {}
                if a.flame then table.insert(lines, string.format(T("Près d'un camp : %s"), a.flame.name)) else table.insert(lines, T("Pas de feu de camp à proximité.")) end
                if a.sit then table.insert(lines, string.format(T("Assis : avantages dans %d s"), math.ceil(Cp.Remaining(a.sit) or 0))) end
                if a.perk then
                    local left = Cp.Remaining(a.perk)
                    table.insert(lines, string.format(T("Avantages du camp actifs%s"), left and (" · " .. string.format(T("%s restantes"), UI:AgoShort(left, true))) or ""))
                    local txt = Cp:PerkText()
                    if txt then table.insert(lines, "|cff9ca3ab" .. txt:gsub("\n", " · ") .. "|r") end
                elseif not a.sit then
                    table.insert(lines, "|cff9ca3ab" .. T("Pas d'avantages du camp en ce moment.") .. "|r")
                end
                if st == "early" then table.insert(lines, "|cfff5d76e" .. T("Relevé trop tôt : rassieds-toi 1 min.") .. "|r") end
                return table.concat(lines, "\n")
            end)
            nowText:SetPoint("TOPLEFT", 16, -42); nowText:SetPoint("RIGHT", -150, 0)
            nowText:SetJustifyH("LEFT")
            if nowText.SetWordWrap then nowText:SetWordWrap(true) end
            local sitBtn = UI:Button(now, "S'asseoir", 120, 28, "primary")
            sitBtn:SetPoint("TOPRIGHT", -16, -42)
            sitBtn:SetScript("OnClick", function() Cp:Sit() end)
            table.insert(self.dyn, function() sitBtn:SetEnabled(Cp.auras ~= nil and Cp.auras.flame ~= nil and not Cp.auras.sit) end)
            -- rappel
            local rem = card("Rappel à l'écran", 40 + 6 * 46 + 8, "icône et encart près du camp")
            UI:SettingRow(rem, -270, "Icône près d'un feu de camp", "Une flamme qui apparaît près d'un camp : clic pour s'asseoir, un cercle décompte la minute. Se place en mode édition.",
                toggle(rem, function() return campCfg.icon end, function(v) campCfg.icon = v; cupdate() end), 80)
            UI:SettingRow(rem, -40, "Encart près d'un feu de camp", "« Assieds-toi » avec un bouton, compte à rebours assis, avantages obtenus.",
                toggle(rem, function() return campCfg.enabled end, function(v) campCfg.enabled = v; cupdate() end), 80)
            UI:SettingRow(rem, -86, "Proposer de renouveler", "Quand il reste moins que ce temps sur les avantages du camp (0 : seulement quand ils sont finis).",
                UI:Slider(rem, 240, 0, 60, 5, function() return campCfg.renewAt or 10 end, function(v) campCfg.renewAt = v; cupdate() end, "%d min"), 260)
            UI:SettingRow(rem, -132, "Son au rappel", "Un petit son quand l'encart propose de s'asseoir.",
                toggle(rem, function() return campCfg.sound end, function(v) campCfg.sound = v end), 80)
            UI:SettingRow(rem, -178, "Avantages affichés pendant", "Une fois obtenus, l'encart les montre puis s'efface (0 : il reste jusqu'à ce que tu le fermes).",
                UI:Slider(rem, 240, 0, 30, 2, function() return campCfg.doneSecs or 8 end, function(v) campCfg.doneSecs = v end, "%d s"), 260)
            local placeBtn = UI:Button(rem, "Placer l'encart", 150, 28, "secondary")
            placeBtn:SetScript("OnClick", function() UI:EnterEditMode() end)
            UI:SettingRow(rem, -224, "Position et taille", "En mode édition, avec les autres éléments à l'écran (« Tester » le joue en vrai).", placeBtn, 150)
            -- comment ça marche, et effets rencontrés
            local how = card("Comment ça marche", 40 + 4 * 22 + 30 + 8 * 18 + 8)
            local howText = UI:Text(how, 11, C.muted)
            howText:SetPoint("TOPLEFT", 16, -42); howText:SetPoint("RIGHT", -16, 0)
            howText:SetJustifyH("LEFT")
            if howText.SetWordWrap then howText:SetWordWrap(true) end
            howText:SetText(T("1. Près d'un camp, une flamme t'affecte (par exemple « Flammes pourpres ») : elle allonge la durée des effets de camp.") .. "\n"
                .. T("2. Assieds-toi (ou allonge-toi, agenouille-toi, dors, ou fabrique à côté) : « Feu de camp accueillant » compte 1 min.") .. "\n"
                .. T("3. Tu obtiens « Avantages du camp », selon les objets posés autour du feu ; ils restent quand tu pars.") .. "\n"
                .. T("4. Un camp dure environ 15 min ; poser un feu : recharge de 5 min ; poser un objet de métier : recharge commune d'1 h."))
            local seenHead = UI:Text(how, 10, C.dim)
            seenHead:SetPoint("TOPLEFT", 16, -42 - 4 * 22 - 6)
            seenHead:SetText(UI:Upper(T("Effets de camp rencontrés")))
            local seenText = dynText(how, 11, C.text, function()
                local g = WK.DB.global.camp and WK.DB.global.camp.seen or {}
                local KIND = { flame = T("flamme"), sit = T("assis"), perk = T("avantages") }
                local out = {}
                for id, kind in pairs(g) do
                    local name = (WK.SpellInfo and WK.SpellInfo(id)) or ("#" .. id)
                    table.insert(out, string.format("%s  |cff9ca3ab· %s · n° %d|r", name, KIND[kind] or kind, id))
                end
                table.sort(out)
                if #out == 0 then return "|cff9ca3ab" .. T("Aucun pour l'instant : approche-toi d'un camp.") .. "|r" end
                local shown = {}
                for i = 1, math.min(#out, 8) do shown[i] = out[i] end
                return table.concat(shown, "\n")
            end)
            seenText:SetPoint("TOPLEFT", seenHead, "BOTTOMLEFT", 0, -6); seenText:SetPoint("RIGHT", -16, 0)
            seenText:SetJustifyH("LEFT")
            if seenText.SetWordWrap then seenText:SetWordWrap(true) end

            -- ce que tes persos peuvent apporter (selon leurs métiers)
            local CROWS = 10
            local contrib = card("Ce que tes persos peuvent apporter", 40 + CROWS * 20 + 30, "un objet par joueur et par camp")
            local ctext = dynText(contrib, 11, C.text, function()
                local list = Cp:Contributions()
                if #list == 0 then return "|cff9ca3ab" .. T("Aucun : il faut 20 dans un métier (ou la Cuisine pour poser le feu).") .. "|r" end
                local lines, last = {}, nil
                for i, e in ipairs(list) do
                    if i > CROWS then table.insert(lines, string.format("|cff9ca3ab" .. T("+ %d autre(s)") .. "|r", #list - CROWS)) break end
                    local r, g, b = UI:ClassColor(e.c.class)
                    local who = e.key ~= last and string.format("|cff%02x%02x%02x%s|r  ", r * 255, g * 255, b * 255, WK:CharName(e.c, e.key)) or "      "
                    last = e.key
                    table.insert(lines, who .. e.item .. "  |cff9ca3ab· " .. T(e.prof) .. " " .. e.rank .. " · " .. e.effect
                        .. (e.tier >= 2 and (" · " .. T("plan requis")) or "") .. "|r")
                end
                return table.concat(lines, "\n")
            end)
            ctext:SetPoint("TOPLEFT", 16, -42); ctext:SetPoint("RIGHT", -16, 0)
            ctext:SetJustifyH("LEFT")
            if ctext.SetWordWrap then ctext:SetWordWrap(false) end

            -- objets de camp par métier (premier objet, à 20 de compétence)
            local tbl = card("Objets de camp par métier", 40 + 20 + #Cp.ITEMS * 20 + 4 * 20 + 16, "premier objet à 20 ; 140 et 300 avec un plan")
            local function col(x, y, txt, color)
                local t = UI:Text(tbl, 11, color)
                t:SetPoint("TOPLEFT", x, y)
                t:SetText(txt)
                return t
            end
            local XS = { 16, 130, 300, 500 }
            local hy = -42
            for i, h in ipairs({ "Métier", "Objet", "Effet", "Ne se cumule pas avec" }) do col(XS[i], hy, UI:Upper(T(h)), C.dim) end
            for i, it in ipairs(Cp.ITEMS) do
                local y = hy - 20 * i
                col(XS[1], y, T(it[1]), C.muted)
                col(XS[2], y, it[2][1], C.text)
                col(XS[3], y, it[2][2], C.text)
                col(XS[4], y, it[2][3] or "-", C.muted)
            end
            local fy = hy - 20 * (#Cp.ITEMS + 1) - 6
            col(16, fy, UI:Upper(T("Feux de camp (Cuisine)")), C.dim)
            for i, f in ipairs(Cp.FIRES) do
                col(16, fy - 20 * i, f[1], C.text)
                col(XS[3], fy - 20 * i, string.format(T("Cuisine %d · %d objets en plus · %s"), f[2], f[3], f[4]), C.muted)
            end

            -- bon à savoir : repos, sac de couchage
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
        -- Expérience (en préparation)
        -----------------------------------------------------------------------
        section("xp")
        do
            local soon = card("Expérience", 40 + 7 * 20 + 16, "bientôt")
            local st = UI:Text(soon, 12, C.muted)
            st:SetPoint("TOPLEFT", 16, -42); st:SetPoint("RIGHT", -16, 0)
            st:SetJustifyH("LEFT")
            if st.SetWordWrap then st:SetWordWrap(true) end
            st:SetText(T("Cette section accueillera l'expérience de tes persos : barre d'expérience, repos, quêtes terminées à rendre, rythme et temps jusqu'au prochain niveau.") .. "\n\n"
                .. T("Elle est en préparation."))
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
                            if QoL:Relevant(r, e.c.level) then
                                local n = QoL:Count(e.c, r)
                                local col = (s.min or 0) > 0 and n < s.min and "|cffe8a849" or "|cffffffff"
                                table.insert(stock, (e.c.name or "?") .. " " .. col .. num(n) .. "|r")
                            end
                        end
                        row.desc:SetText(lv .. (#stock > 0 and ("  ·  " .. table.concat(stock, ", ")) or ""))
                    end)
                end
            end

            -- Munitions
            if QoL.AMMO[class] then
                local am = card("Munitions", 186, class == "HUNTER" and nil or "si tu tires à l'arc, au fusil ou à l'arbalète")
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
                local lock = card("Crochetage et vol à la tire", 196)
                local lt = dynText(lock, 12, C.text, function()
                    local boxes = QoL:Lockboxes()
                    local best = 0
                    for _, e in ipairs(list) do best = math.max(best, e.c.lockpick or 0) end
                    local lines = {}
                    for i, b in ipairs(boxes) do
                        if i > 5 then break end
                        local ok = best >= b.skill
                        table.insert(lines, string.format("%s%s|r x%d  ·  %s  ·  %s", ok and "|cff9fd27c" or "|cffb6a27e",
                            WK.GetItemInfo(b.id) or ("#" .. b.id), b.n, b.where,
                            string.format(T("Crochetage %d"), b.skill)))
                    end
                    if #boxes == 0 then table.insert(lines, T("Aucun coffre à crocheter dans les sacs de tes persos.")) end
                    local gold = {}
                    for _, e in ipairs(list) do
                        if (e.c.pickpocket or 0) > 0 then table.insert(gold, (e.c.name or "?") .. " " .. WK:FormatMoney(e.c.pickpocket)) end
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
                local sh = card("Fragments d'âme", 140)
                UI:SettingRow(sh, -40, "Garder au maximum", "Le bouton supprime ceux en trop (Maj + clic, perso connecté).",
                    UI:Slider(sh, 240, 3, 40, 1, function() return cc.shardMax or 20 end, function(v) cc.shardMax = v; WK:NotifyChanged() end, "%d"), 260)
                local cur = dynText(sh, 11, C.muted, function()
                    local c = WK.DB:Me()
                    if c.class ~= "WARLOCK" then return T("Connecte un démoniste pour supprimer ses fragments en trop.") end
                    return string.format(T("Dans les sacs : %d / %d"), (c.bags or {})[6265] or 0, cc.shardMax or 20)
                end)
                cur:SetPoint("BOTTOMLEFT", 16, 20)
                local del = UI:Button(sh, "Supprimer le surplus", nil, 28, "ghost", "trash")
                del:SetPoint("BOTTOMRIGHT", -12, 12)
                del.tooltip = "Maj + clic : supprime les fragments au-delà du maximum."
                del:SetScript("OnClick", function() if IsShiftKeyDown() then QoL:DeleteExtraShards() end end)
            elseif class == "MAGE" then
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
                local rc = card("Réincarnation", 52 + math.max(1, #list) * 22 + 12)
                local t = dynText(rc, 12, C.text, function()
                    if #list == 0 then return T("Aucun chaman pour l'instant.") end
                    local lines = {}
                    for _, e in ipairs(list) do
                        local left = e.c.reincarnation and (e.c.reincarnation - time())
                        table.insert(lines, (e.c.name or "?") .. "  ·  " .. ((e.c.level or 0) < 30 and T("à partir du niveau 30")
                            or (left and minutes(left)) or T("pas encore vue")))
                    end
                    return table.concat(lines, "\n")
                end)
                t:SetPoint("TOPLEFT", 16, -42)
                t:SetJustifyV("TOP")
                if t.SetWordWrap then t:SetWordWrap(true) end
                t:SetSpacing(8)
            end
            if class == "HUNTER" then
                local H = WK.modules.Hunter
                -- Cadre du familier (UI/PetCard.lua)
                local pc = UI.PetCardConfig()
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

                local rm = card("Rappels", 232, "dans la pile d'alertes, déplaçable")
                local function rt(field)
                    return toggle(rm, function() return cc[field] end, function(v) cc[field] = v; H:UpdateAlerts() end)
                end
                UI:SettingRow(rm, -40, "Aucun aspect actif", "Hors combat, à partir du niveau 10.", rt("remAspect"), 80)
                UI:SettingRow(rm, -88, "Guépard ou Meute en combat", "Tout de suite, même en combat : tu vas être hébété.", rt("remCheetah"), 80)
                UI:SettingRow(rm, -136, "Grondement du familier", "Désactivé en donjon et raid, activé en solo.", rt("remGrowl"), 80)
                UI:SettingRow(rm, -184, "Pistage en champ de bataille", "Pister les humanoïdes.", rt("remTrack"), 80)
            end
            local REMIND = {
                PRIEST = { "Robustesse du groupe", "À l'écran, hors combat, quand un membre du groupe n'a plus Robustesse (ou presque plus)." },
                PALADIN = { "Aura et bénédiction", "À l'écran, hors combat, quand tu n'as pas d'aura ou pas de bénédiction." },
                DRUID = { "Marque du fauve", "À l'écran, hors combat, quand tu n'as plus la Marque ou le Don du fauve." },
            }
            if REMIND[class] then
                local rm = card("Rappels", 96)
                UI:SettingRow(rm, -40, REMIND[class][1], REMIND[class][2],
                    toggle(rm, function() return cc.buffReminder end, function(v) cc.buffReminder = v end), 80)
            end
        end
        current.tailY = y
        current.scroll:SetContentHeight(y + (current.extraY and current.extraY() or 0))
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
            local n = #QoL:CharsOf(key)
            t.played = played[key] or false
            t.tip = n == 0 and T("Aucun perso") or string.format(n > 1 and T("%d persos") or T("%d perso"), n)
            local a = byClass[key] or 0
            t.count:SetShown(a > 0)
            if a > 0 then t.count:Set(tostring(a), C.warning) end
            t:Paint()
        end
        for _, tile in ipairs(self.tiles) do
            local e = tile.e
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
    end,
})
