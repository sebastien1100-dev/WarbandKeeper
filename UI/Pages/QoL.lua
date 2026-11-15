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

-- Résumé d'un perso pour sa tuile : texte, et part du stock (0-1) pour la barre.
local function charSummary(c)
    local class = c.class
    local cc = Q():Class(class)
    local parts, ratio = {}, nil
    local function track(n, target)
        if target and target > 0 then
            local r = math.min(1, n / target)
            ratio = ratio and math.min(ratio, r) or r
        end
    end
    if Q().AMMO[class] and c.ammo and c.ammo.id then
        table.insert(parts, string.format(T("Munitions %s"), num(c.ammo.n)))
        track(c.ammo.n or 0, cc.ammo.buy)
    end
    if class == "HUNTER" and c.pet and c.pet.happy then
        local st = ({ T("mécontent"), T("content"), T("heureux") })[c.pet.happy] or "?"
        table.insert(parts, string.format(T("Familier : %s"), st))
    elseif class == "ROGUE" and c.lockpick then
        table.insert(parts, string.format(T("Crochetage %d"), c.lockpick))
    elseif class == "SHAMAN" and c.reincarnation then
        table.insert(parts, string.format(T("Réincarnation : %s"), minutes(c.reincarnation - time())))
    end
    local shown = 0
    for _, r in ipairs(Q().REAGENTS[class] or {}) do
        if Q():Relevant(r, c.level) then
            local n = Q():Count(c, r)
            local s = cc.reag[r.key]
            if shown < 3 then
                table.insert(parts, Q():ReagentName(r) .. " " .. num(n))
                shown = shown + 1
            end
            track(n, (s and s.buy and s.buy > 0) and s.buy or (s and s.min and s.min > 0 and s.min * 2) or nil)
        end
    end
    if #parts == 0 then table.insert(parts, T("Rien à suivre à ce niveau")) end
    return table.concat(parts, " · "), ratio
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

        local function section(key)
            if current then current.scroll:SetContentHeight(y) end
            local sc = UI:Scroll(host)
            sc:SetAllPoints()
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

        function self:ShowSection(key)
            if not self.sections[key] then key = "general" end
            ui.qolSection = key
            for k, sec in pairs(self.sections) do sec.scroll:SetShown(k == key) end
            for k, b in pairs(self.navButtons) do b.selected = (k == key); b:Paint() end
        end

        -- Colonne : Général puis les classes ---------------------------------------
        local function navButton(key, label, y0, class)
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
                b.icon = UI:Icon(b, "gear", 14, C.onAccent, "OVERLAY")
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
        local sep = navCard:CreateTexture(nil, "ARTWORK")
        sep:SetColorTexture(unpack(C.border))
        sep:SetPoint("TOPLEFT", 14, -61)
        sep:SetPoint("TOPRIGHT", -14, -61)
        sep:SetHeight(1)
        local classButtons = {}
        for i, cl in ipairs(QoL.CLASSES) do
            classButtons[i] = navButton(cl[1], cl[2], -66 - (i - 1) * 50, cl[1])
        end
        -- Fenêtre basse : les lignes se resserrent pour garder une marge sous la dernière classe.
        UI:OnResize(navCard, function(_, h)
            if not h or h <= 0 then return end
            local step = math.max(40, math.min(50, math.floor((h - 66 - 14) / #classButtons)))
            for i, b in ipairs(classButtons) do
                b:SetHeight(step - 2)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", 8, -66 - (i - 1) * step)
                b:SetPoint("TOPRIGHT", -8, -66 - (i - 1) * step)
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
        local guide = card("Guidage", 300)
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
            local b = UI:Button(goBar, it[2], nil, 28, "secondary")
            b:SetScript("OnClick", function() G:GoTo(it[1]) end)
            table.insert(goButtons, b)
        end
        local stop = UI:Button(goBar, "Arrêter", nil, 28, "ghost")
        stop:SetScript("OnClick", function() G:Stop() end)
        table.insert(goButtons, stop)
        UI:OnResize(goBar, function(w)
            local x, row = 0, 0
            for _, b in ipairs(goButtons) do
                local bw = b.GetStringWidth and (b:GetStringWidth() + 6) or b:GetWidth()
                if x > 0 and x + bw > w then x, row = 0, row + 1 end
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", x, -row * 34 - (b.GetStringWidth and 8 or 0))
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

        local comfort = card("Confort", 236)
        UI:SettingRow(comfort, -40, "Libérer l'esprit en champ de bataille", "Automatiquement à la mort (pas avec une pierre d'âme).",
            toggle(comfort, function() return g.releaseBG end, function(v) g.releaseBG = v end), 80)
        UI:SettingRow(comfort, -88, "Confirmer le butin lié quand ramassé", "Seulement quand tu es seul.",
            toggle(comfort, function() return g.confirmBoP end, function(v) g.confirmBoP = v end), 80)
        UI:SettingRow(comfort, -136, "Descendre de monture ou se lever", "Quand une action l'exige (sort, maître de vol, butin…).",
            toggle(comfort, function() return g.dismount end, function(v) g.dismount = v end), 80)
        UI:SettingRow(comfort, -184, "Passer les cinématiques", nil,
            toggle(comfort, function() return g.skipCinematics end, function(v) g.skipCinematics = v end), 80)

        -----------------------------------------------------------------------
        -- Fiches de classe
        -----------------------------------------------------------------------
        self.tiles = {}
        for _, cl in ipairs(QoL.CLASSES) do
            local class = cl[1]
            local cc = q.classes[class]
            section(class)

            -- Persos de la classe (tuiles)
            local list = QoL:CharsOf(class)
            if #list == 0 then
                local empty = card(nil, 64)
                local t = UI:Text(empty, 12, C.muted)
                t:SetPoint("LEFT", 16, 0)
                t:SetPoint("RIGHT", -16, 0)
                t:SetText(string.format(T("Aucun %s pour l'instant : ces réglages serviront dès que tu en joueras un."), string.lower(T(cl[2]))))
            else
                local perRow = math.min(3, #list)
                local rows = math.ceil(#list / perRow)
                local holder = CreateFrame("Frame", nil, root)
                holder:SetSize(W, rows * 66 - 8)
                holder:SetPoint("TOPLEFT", 0, -y)
                holder:SetPoint("TOPRIGHT", 0, -y)
                y = y + rows * 66 - 8 + GAP
                local tiles = {}
                for _, e in ipairs(list) do
                    local tile = CreateFrame("Frame", nil, holder)
                    tile:SetHeight(58)
                    UI:Panel(tile, 10, C.surface2, C.border)
                    tile.icon = UI:RoundIcon(tile, 34)
                    tile.icon:SetPoint("LEFT", 12, 0)
                    tile.name = UI:Text(tile, 12)
                    tile.name:SetPoint("TOPLEFT", 56, -10)
                    tile.line = UI:Text(tile, 11, C.muted)
                    tile.line:SetPoint("TOPLEFT", tile.name, "BOTTOMLEFT", 0, -4)
                    tile.line:SetPoint("RIGHT", tile, "RIGHT", -10, 0)
                    tile.bar = UI:Progress(tile, 4)
                    tile.bar:SetPoint("TOPLEFT", tile.line, "BOTTOMLEFT", 0, -6)
                    tile.bar:SetWidth(150)
                    tile.e = e
                    table.insert(tiles, tile)
                    table.insert(self.tiles, tile)
                end
                UI:OnResize(holder, function(w)
                    local tw = (w - (perRow - 1) * 10) / perRow
                    for i, tile in ipairs(tiles) do
                        local col, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
                        tile:ClearAllPoints()
                        tile:SetPoint("TOPLEFT", col * (tw + 10), -row * 66)
                        tile:SetWidth(tw)
                    end
                end)
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
                local am = card("Munitions", 140, class == "HUNTER" and nil or "si tu tires à l'arc, au fusil ou à l'arbalète")
                UI:SettingRow(am, -40, "Alerte quand il en reste peu", "Type de munitions équipé, compté dans les sacs.",
                    UI:Slider(am, 240, 0, 2000, 100, function() return cc.ammo.min or 0 end, function(v) cc.ammo.min = v; WK:NotifyChanged() end, "%d"), 260)
                local ctl = CreateFrame("Frame", nil, am)
                ctl:SetSize(320, 22)
                local sl = UI:Slider(ctl, 260, 200, 4000, 200, function() return cc.ammo.buy or 2000 end, function(v) cc.ammo.buy = v end, "%d")
                sl:SetPoint("LEFT")
                local tg = toggle(ctl, function() return cc.ammo.auto end, function(v) cc.ammo.auto = v end)
                tg:SetPoint("RIGHT")
                UI:SettingRow(am, -88, "Achat automatique chez le marchand", "Complète jusqu'à cette quantité, avec le même type de munitions.", ctl, 320)
            end

            -- Aides propres à la classe
            if class == "HUNTER" then
                local pet = card("Familier", 184)
                UI:SettingRow(pet, -40, "Alerte si le familier n'est plus heureux", "À l'écran quand il change d'humeur, et dans « À faire ».",
                    toggle(pet, function() return cc.petAlert end, function(v) cc.petAlert = v end), 80)
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
                    foodRow.desc:SetText(#names > 0 and table.concat(names, " · ")
                        or T("Rien de connu dans les sacs. Nourris-le une fois à la main : ce qu'il mange est retenu."))
                end)
                local macro = UI:Button(pet, "Macro « Nourrir »", nil, 28, "primary")
                macro:SetPoint("BOTTOMRIGHT", -12, 12)
                macro.tooltip = "Crée la macro du perso et la met sur le curseur : pose-la dans une barre d'action. Elle choisit toute seule la nourriture."
                macro:SetScript("OnClick", function() QoL:PickupFeedMacro() end)
                local note = UI:Text(pet, 11, C.muted)
                note:SetPoint("BOTTOMLEFT", 16, 20)
                note:SetText("La macro se met à jour quand le contenu des sacs change.")
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
            else
                local n = #QoL:CharsOf(key)
                b.played = played[key] or false
                b.desc:SetText(n == 0 and T("Aucun perso") or string.format(n > 1 and T("%d persos") or T("%d perso"), n))
                b.count:SetText((byClass[key] or 0) > 0 and tostring(byClass[key]) or "")
            end
            b:Paint()
        end
        local alerted = {}
        for _, a in ipairs(alerts) do if a.class then alerted[a.key] = true end end
        for _, tile in ipairs(self.tiles) do
            local e = tile.e
            UI:SetCharIcon(tile.icon, e.c, e.key)
            tile.name:SetText(WK:CharName(e.c, e.key) .. "  |cffb6a27e" .. (e.c.level or "?") .. "|r")
            local txt, ratio = charSummary(e.c)
            tile.line:SetText(txt)
            tile.line:SetTextColor(unpack(alerted[e.key] and C.warning or C.muted))
            tile.bar:SetShown(ratio ~= nil)
            tile.bar.color = alerted[e.key] and C.warning or C.positive
            tile.bar:SetValue(ratio or 0)
        end
        for _, t in ipairs(self.toggles) do t:Refresh() end
        for _, inp in ipairs(self.inputs) do
            if not inp.box.edit:HasFocus() then inp.box:SetText(tostring(inp.get())) end
        end
        for _, fn in ipairs(self.dyn) do fn() end
    end,
})
