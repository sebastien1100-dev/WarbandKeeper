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

UI:RegisterPage({
    key = "qol", order = 8, nav = "QoL",

    Build = function(self, p)
        local QoL = Q()
        local q = QoL:Config()
        local ui = WK.DB.global.settings.ui
        local W = UI.PAGE_W - NAV_W - GAP - 12

        local navCard = UI:Card(p)
        navCard:SetWidth(NAV_W)
        navCard:SetPoint("TOPLEFT")
        navCard:SetPoint("BOTTOMLEFT")
        local host = CreateFrame("Frame", nil, p)
        host:SetPoint("TOPLEFT", NAV_W + GAP, 0)
        host:SetPoint("BOTTOMRIGHT")

        self.sections, self.navButtons = {}, {}
        self.toggles, self.inputs, self.dyn = {}, {}, {}
        local root, y, current

        local CLASSBAR_H = 64
        local function section(key, top)
            if current then current.scroll:SetContentHeight(y) end
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
        local micro = navButton("micro", "Micro menu", -108, nil, "clock")
        micro.desc:SetText("Horloge et raccourcis")
        local fishBtn = navButton("fishing", "Pêche", -158, nil, "fish")
        fishBtn.desc:SetText("Tenue, appâts, touche unique")
        local ahBtn = navButton("ah", "Hôtel des ventes", -208, nil, "coin")
        ahBtn.desc:SetText("Scan et prix")
        local classesBtn = navButton("classes", "Classes", -258, nil, "users")
        classesBtn.desc:SetText("Réglages par classe")
        -- modules coupés (Core/Features.lua) : leur entrée disparaît, les autres se resserrent
        local NAV_ORDER = { "general", "halo", "micro", "fishing", "ah", "classes" }
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
        local guide = card("Guidage", 318)
        UI:SettingRow(guide, -40, "Guider quand une alerte se déclenche",
            "Sacs pleins, réparation, composants ou munitions : guidage vers le lieu le plus proche (hors combat).",
            toggle(guide, function() return gcfg.auto end, function(v) gcfg.auto = v end), 80)
        UI:SettingRow(guide, -96, "Flèche à l'écran", "Déplaçable ; clic droit ou croix pour arrêter.",
            toggle(guide, function() return gcfg.arrow end, function(v) gcfg.arrow = v; if G.OnTarget then G:OnTarget() end end), 80)
        UI:SettingRow(guide, -144, "Repère sur la carte du monde", nil,
            toggle(guide, function() return gcfg.mapPin end, function(v) gcfg.mapPin = v; if G.Redraw then G:Redraw() end end), 80)
        UI:SettingRow(guide, -186, "Maître de classe à chaque niveau pair", "Nouveaux sorts tous les deux niveaux : guidage vers le maître de ta classe le plus proche.",
            toggle(guide, function() return gcfg.trainerOnLevel end, function(v) gcfg.trainerOnLevel = v end), 80)
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
        local haloPaint -- aperçu de l'atelier, repeint quand l'effet global change
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
        local diffRow = UI:SettingRow(right, -126, "Couleur selon la difficulté", "Filons, plantes et dépeçage : orange, jaune, vert, gris (rouge si la compétence manque).", diffToggle, 60)
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
            local shown = col
            if diffable and gcfg.diffColor and sample then shown = Gm.DIFF_COLORS[sample[4]] end
            stage.icon:SetTexture(CAT_ICON[selCat])
            stage.fx:Set(gcfg.fx[selCat] or gcfg.style or "halo", shown, 110, (gcfg.intensity or 100) / 100, 2.2)
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


        -----------------------------------------------------------------------
        -- Micro menu : horloge et raccourcis (UI/ClockBar.lua)
        -----------------------------------------------------------------------
        section("micro")
        local ck = UI.ClockConfig()
        local SC = UI.CLOCK_SHORTCUTS
        local clockCard = card("Horloge et raccourcis", 40 + 11 * 46 + 30 + 128, "les raccourcis se déplient au survol de l'heure")
        local cy = -40
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
        hdr:SetPoint("TOPLEFT", 16, cy - 6)
        hdr:SetText(T("RACCOURCIS") .. "  ·  " .. T("clic : gauche > droite > masqué"))
        cy = cy - 26
        local box = CreateFrame("Frame", nil, clockCard)
        box:SetPoint("TOPLEFT", 16, cy)
        box:SetPoint("TOPRIGHT", -16, cy)
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
        hint:SetText(T("Maj + clic gauche ou droit : décaler d'un cran  ·  clic droit : masquer"))
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
            b:SetScript("OnLeave", function(s2) s2.hover = nil; layoutBar(); GameTooltip:Hide() end)
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
        -- Hôtel des ventes (Modules/AHScan.lua, UI/AuctionPanel.lua)
        -----------------------------------------------------------------------
        section("ah")
        local AS = WK.modules.AHScan
        local ac = AS:Config()
        local function atoggle(parent, field)
            return toggle(parent, function() return ac[field] end, function(v) ac[field] = v end)
        end
        local hcard = card("Hôtel des ventes", 40 + 4 * 46 + 8, "scan de l'HV, sans Auctionator")
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

        -----------------------------------------------------------------------
        -- Pêche (Modules/Fishing.lua, UI/FishingBar.lua)
        -----------------------------------------------------------------------
        section("fishing")
        local Fi = WK.modules.Fishing
        local fo = Fi:Config()
        local function ftoggle(parent, field, after)
            return toggle(parent, function() return fo[field] end, function(v) fo[field] = v; if after then after() end end)
        end
        local fmode = card("Mode pêche", 40 + 3 * 46 + 8, "tenue, sons, touche et barre à l'écran, le temps de pêcher")
        local modeBtn = UI:Button(fmode, "Ouvrir", 150, 28, "primary")
        modeBtn:SetScript("OnClick", function() Fi:Toggle() end)
        table.insert(self.dyn, function()
            modeBtn.label:SetText(Fi.active and T("Fermer le mode pêche") or T("Ouvrir le mode pêche"))
        end)
        UI:SettingRow(fmode, -40, "Mode pêche", "À la fermeture, équipement, sons et touche redeviennent comme avant. Aussi : /wk peche.", modeBtn, 170)
        UI:SettingRow(fmode, -86, "Ouvrir quand une canne est équipée", "Y compris à la connexion.", ftoggle(fmode, "autoOpen"), 80)
        UI:SettingRow(fmode, -132, "Bouton de minicarte", "Ouvre et ferme le mode pêche. Seulement sur les persos qui ont la Pêche, et masqué si le raccourci est dans le micro menu.",
            ftoggle(fmode, "minimap", function() UI:SyncFishingMinimap() end), 80)

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
        UI:SettingRow(fcomfort, -86, "Son du flotteur mis en avant", "Musique et ambiance coupées, effets au maximum, le temps de pêcher.", ftoggle(fcomfort, "sound"), 80)
        UI:SettingRow(fcomfort, -132, "Avertissements à l'écran", "Pas de canne, plus d'appât, sacs pleins.", ftoggle(fcomfort, "warn", function() Fi:Warn() end), 80)

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
        current.scroll:SetContentHeight(y)
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
