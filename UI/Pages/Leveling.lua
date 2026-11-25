local _, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Page Leveling (maquette A) : barre des 9 classes, puis le plan de montée de la classe choisie
-- (Modules/ClassPlan.lua) en deux colonnes : à gauche les arbres de talents avec l'ordre des points
-- (clic = point suivant, clic droit = retirer le dernier), à droite les sorts du maître rangés par niveau
-- (clic = acheter / écarter). Tous les persos de la classe suivent le plan actif (pastilles « Suivi par »).
local CreateFrame = _G.CreateFrame
local CLASSES = { { "WARRIOR", "Guerrier" }, { "PALADIN", "Paladin" }, { "HUNTER", "Chasseur" },
    { "ROGUE", "Voleur" }, { "PRIEST", "Prêtre" }, { "SHAMAN", "Chaman" }, { "MAGE", "Mage" },
    { "WARLOCK", "Démoniste" }, { "DRUID", "Druide" } }
local CLASS_LABEL = {}
for _, c in ipairs(CLASSES) do CLASS_LABEL[c[1]] = c[2] end

local function CP() return WK.modules.ClassPlan end
local function cfg() return WK.DB.global.settings.ui end

UI:RegisterPage({
    key = "leveling", order = 3, nav = "Plans de montée",

    Build = function(self, p)
        local me = WK.DB.global.characters[WK:CharKey()]
        self.class = cfg().levelClass or (me and me.class) or "WARRIOR"

        -- barre des classes --------------------------------------------------------------------------------
        local bar = CreateFrame("Frame", nil, p)
        bar:SetPoint("TOPLEFT"); bar:SetPoint("TOPRIGHT"); bar:SetHeight(58)
        UI:Panel(bar, 12, C.surface, C.border)
        self.classBtns = {}
        for i, cl in ipairs(CLASSES) do
            local b = CreateFrame("Button", nil, bar)
            b.bg = UI:Rounded(b, 9, 0, "BACKGROUND", 1)
            b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(24, 24); b.icon:SetPoint("TOP", 0, -6)
            UI:SetClassIcon(b.icon, cl[1])
            b.label = UI:Text(b, 11, C.muted); b.label:SetPoint("TOP", b.icon, "BOTTOM", 0, -2)
            b.label:SetText(T(cl[2]))
            b.line = b:CreateTexture(nil, "OVERLAY"); b.line:SetHeight(2)
            b.line:SetPoint("BOTTOMLEFT", 8, 0); b.line:SetPoint("BOTTOMRIGHT", -8, 0)
            b:SetScript("OnClick", function() self.class = cl[1]; cfg().levelClass = cl[1]; self:Refresh() end)
            b:SetScript("OnEnter", function(s) s.hover = true; self:PaintClasses() end)
            b:SetScript("OnLeave", function(s) s.hover = false; self:PaintClasses() end)
            b.key = cl[1]
            self.classBtns[i] = b
        end
        UI:OnResize(bar, function(w)
            local cw = (w - 12) / #CLASSES
            for i, b in ipairs(self.classBtns) do
                b:ClearAllPoints(); b:SetSize(cw - 4, 52); b:SetPoint("TOPLEFT", 6 + (i - 1) * cw + 2, -3)
            end
        end)
        self.PaintClasses = function(pg)
            local ar, ag, ab = UI:Accent()
            for _, b in ipairs(pg.classBtns) do
                local on = b.key == pg.class
                b.bg:SetColor(unpack((on or b.hover) and C.surface2 or C.surface))
                b.line:SetColorTexture(ar, ag, ab, on and 1 or 0)
                b.icon:SetAlpha(on and 1 or 0.55)
                b.label:SetTextColor(unpack(on and C.text or C.muted))
            end
        end

        -- bandeau (maquette 1) : menu déroulant du plan (nom, répartition, points), persos qui suivent ----------
        local head = CreateFrame("Frame", nil, p)
        head:SetPoint("TOPLEFT", 0, -58 - 8); head:SetPoint("TOPRIGHT", 0, -58 - 8); head:SetHeight(40)
        self.head = head
        local dd = CreateFrame("Button", nil, head)
        dd:SetHeight(36); dd:SetPoint("LEFT", 0, 0); dd:SetWidth(330)
        dd.bg = UI:Rounded(dd, 9, 0, "BACKGROUND", 1)
        dd.edge = UI:Rounded(dd, 9, 0, "BACKGROUND", 0)
        dd.lab = UI:Text(dd, 11, C.muted); dd.lab:SetPoint("LEFT", 12, 0); dd.lab:SetText(T("Plan"))
        dd.name = UI:Text(dd, 14, C.text); dd.name:SetPoint("LEFT", dd.lab, "RIGHT", 8, 0)
        dd.name:SetWidth(150); dd.name:SetJustifyH("LEFT")
        if dd.name.SetWordWrap then dd.name:SetWordWrap(false) end
        dd.car = UI:Icon(dd, "chevron", 12); dd.car:SetPoint("RIGHT", -10, 0)
        if dd.car.SetRotation then dd.car:SetRotation(-math.pi / 2) end
        dd.split = {}
        for k = 1, 3 do
            local t = dd:CreateTexture(nil, "ARTWORK"); t:SetHeight(6)
            dd.split[k] = t
        end
        dd.splitBg = dd:CreateTexture(nil, "BORDER"); dd.splitBg:SetHeight(6)
        dd.splitBg:SetPoint("RIGHT", dd.car, "LEFT", -10, 0); dd.splitBg:SetWidth(110)
        dd:SetScript("OnClick", function(b) self:OpenPlanMenu(b) end)
        dd:SetScript("OnEnter", function(b) b.hover = true; self:PaintDD() end)
        dd:SetScript("OnLeave", function(b) b.hover = false; self:PaintDD() end)
        self.dd = dd
        self.nums = UI:Text(head, 12, C.muted); self.nums:SetPoint("LEFT", dd, "RIGHT", 12, 0)
        -- « + plan » quand la classe n'en a aucun (sinon : dans le menu)
        self.newBtn = UI:Button(head, "+ plan", nil, 30, "primary")
        self.newBtn:SetPoint("LEFT", 0, 0)
        self.newBtn:SetScript("OnClick", function() self:NewPlan() end)
        -- saisie du nom (Renommer) et des codes (Partager / Importer), sur la ligne
        self.nameIn = UI:Input(head, 220, 30, "Nom du plan")
        self.nameIn:SetPoint("LEFT", self.nums, "RIGHT", 14, 0)
        self.nameIn:Hide()
        self.nameIn.onEnter = function()
            local _, ai = CP():Active(self.class)
            local txt = self.nameIn:GetText()
            if self.inMode == "rename" and ai then CP():Rename(self.class, ai, txt)
            elseif self.inMode == "import" then
                local ok, why = CP():Import(self.class, txt)
                if not ok then WK:Print(why) end
            end
            self.inMode = nil; self.nameIn:Hide(); self:Refresh()
        end
        self.delOk = UI:Button(head, "Confirmer la suppression", nil, 28, "danger")
        self.delOk:SetPoint("LEFT", self.nums, "RIGHT", 14, 0); self.delOk:Hide()
        self.delOk:SetScript("OnClick", function()
            local _, ai = CP():Active(self.class)
            if ai then CP():Delete(self.class, ai) end
            self.delOk:Hide(); self:Refresh()
        end)
        self.follow = UI:Text(head, 11, C.muted)
        self.followBtns = {}

        -- onglets Talents / Sorts du maître (maquette A) -----------------------------------------------------
        local body = CreateFrame("Frame", nil, p)
        body:SetPoint("TOPLEFT", 0, -58 - 8 - 40 - 8); body:SetPoint("BOTTOMRIGHT")
        self.tab = cfg().levelTab or "talents"
        self.tabs = UI:UnderTabs(body, { { "talents", "Talents" }, { "spells", "Sorts du maître" } }, function(k)
            self.tab = k; cfg().levelTab = k; self:Refresh()
        end, 30)
        self.tabs:SetPoint("TOPLEFT", 0, 0); self.tabs:SetPoint("TOPRIGHT", 0, 0)
        self.tabs:Select(self.tab)
        self.tabSum = UI:Text(body, 12, C.muted); self.tabSum:SetPoint("TOPRIGHT", -4, -8)
        self.tabSum:SetJustifyH("RIGHT")
        self.left = UI:Card(body, T("Talents"), " ")
        self.right = UI:Card(body, T("Achats chez le maître"), " ")
        for _, c in ipairs({ self.left, self.right }) do
            c:SetPoint("TOPLEFT", 0, -30 - 8); c:SetPoint("BOTTOMRIGHT")
        end
        UI:OnResize(body, function() UI:RefreshSoon() end)
        -- arbres
        self.treeHost = CreateFrame("Frame", nil, self.left)
        self.treeHost:SetPoint("TOPLEFT", 16, -44); self.treeHost:SetPoint("BOTTOMRIGHT", -16, 50)
        self.treeHeads, self.nodes, self.links, self.rowLabs = {}, {}, {}, {}
        self.leftMsg = UI:Text(self.left, 12, C.muted); self.leftMsg:SetPoint("TOPLEFT", 16, -44)
        self.leftMsg:SetPoint("TOPRIGHT", -16, -44); self.leftMsg:SetJustifyH("LEFT")
        if self.leftMsg.SetWordWrap then self.leftMsg:SetWordWrap(true) end
        self.undo = UI:Button(self.left, "Annuler le dernier point", nil, 26, "secondary")
        self.undo:SetPoint("BOTTOMLEFT", 14, 14)
        self.undo:SetScript("OnClick", function()
            local _, ai = CP():Active(self.class)
            if ai then CP():RemoveLast(self.class, ai); self:Refresh() end
        end)
        self.leftFoot = UI:Text(self.left, 11, C.dim); self.leftFoot:SetPoint("LEFT", self.undo, "RIGHT", 12, 0)
        self.leftFoot:SetPoint("RIGHT", -14, 0); self.leftFoot:SetJustifyH("LEFT")
        -- achats
        self.spells = UI:Scroll(self.right)
        self.spells:SetPoint("TOPLEFT", 8, -40); self.spells:SetPoint("BOTTOMRIGHT", -8, 34)
        self.lvRows, self.chips = {}, {}
        self.rightFoot = UI:Text(self.right, 10, C.dim); self.rightFoot:SetPoint("BOTTOMLEFT", 14, 12)
        -- coût de la sélection (sorts gardés) en haut à droite de la carte
        self.selCost = UI:Text(self.right, 14, C.text); self.selCost:SetPoint("TOPRIGHT", -16, -16)
        self.selCost:SetJustifyH("RIGHT")
        self.rightFoot:SetPoint("BOTTOMRIGHT", -14, 12); self.rightFoot:SetJustifyH("LEFT")
        self.rightFoot:SetText(T("Clic sur un sort : l'acheter ou l'écarter chez le maître. Bordure violette : sort"
            .. " d'un talent du plan."))
    end,

    -- répartition des points d'un plan par arbre (« 23 / 0 / 28 »)
    Split = function(_, plan)
        local out = { 0, 0, 0 }
        for _, st in ipairs(plan and plan.steps or {}) do out[st[1]] = (out[st[1]] or 0) + 1 end
        return out
    end,
    PaintDD = function(self)
        local dd = self.dd
        local ar, ag, ab = UI:Accent()
        dd.bg:SetColor(unpack(dd.hover and C.surface2 or C.surface))
        dd.edge:SetColor(ar, ag, ab, 0.9)
        dd.car:SetVertexColor(ar, ag, ab, 1)
    end,
    NewPlan = function(self)
        local n = #CP():Plans(self.class) + 1
        local i = CP():New(self.class, string.format(T("Plan %d"), n))
        CP():SetActive(self.class, i)
        self:Refresh()
    end,
    -- menu du plan : les plans de la classe (répartition, points), puis les actions
    OpenPlanMenu = function(self, anchor)
        local cp = CP()
        local plans = cp:Plans(self.class)
        local _, ai = cp:Active(self.class)
        local list = {}
        for i, pl in ipairs(plans) do
            local sp = self:Split(pl)
            list[#list + 1] = { label = pl.name, on = i == ai,
                desc = string.format("%d / %d / %d  ·  %d / 51", sp[1], sp[2], sp[3], #pl.steps),
                fn = function() cp:SetActive(self.class, i); self:Refresh() end }
        end
        list[#list + 1] = { sep = true }
        list[#list + 1] = { label = T("+ Nouveau plan"), fn = function() self:NewPlan() end }
        if ai then
            list[#list + 1] = { label = T("Dupliquer ce plan"), fn = function()
                local n = cp:Duplicate(self.class, ai)
                if n then cp:SetActive(self.class, n) end
                self:Refresh()
            end }
            list[#list + 1] = { label = T("Renommer"), fn = function() self:AskLine("rename", plans[ai].name) end }
        end
        local myKey = WK:CharKey()
        local mine = WK.DB.global.characters[myKey]
        local own = mine and mine.class == self.class and WK.modules.TalentPlan:Active(myKey)
        if own then
            list[#list + 1] = { label = T("Copier le plan de ce perso"), desc = own.name, fn = function()
                local i = cp:New(self.class, own.name, own.steps)
                cp:SetActive(self.class, i); self:Refresh()
            end }
        end
        if ai then
            list[#list + 1] = { label = T("Partager (code)"), desc = T("Le code s'affiche, prêt à copier (Ctrl+C)"),
                fn = function() self:AskLine("share", cp:Export(self.class, ai)) end }
        end
        list[#list + 1] = { label = T("Importer un code"), fn = function() self:AskLine("import", "") end }
        if ai then
            list[#list + 1] = { sep = true }
            list[#list + 1] = { label = T("Supprimer ce plan…"), col = C.negative, fn = function()
                self.nameIn:Hide(); self.delOk:Show()
                _G.C_Timer.After(5, function() if self.delOk then self.delOk:Hide() end end)
            end }
        end
        UI.StashPopMenu():Open(anchor, T(CLASS_LABEL[self.class] or self.class), T("Plans de montée"), list, 330)
    end,
    -- ligne de saisie : renommer, code à copier, code à coller
    AskLine = function(self, mode, text)
        self.inMode = mode; self.delOk:Hide()
        self.nameIn:SetText(text or ""); self.nameIn:Show()
        local eb = self.nameIn.edit or self.nameIn.EditBox or self.nameIn
        if eb.SetFocus then pcall(eb.SetFocus, eb) end
        if eb.HighlightText then pcall(eb.HighlightText, eb) end
    end,

    -- un nœud de talent (bouton réutilisé) : icône, liseré (or = rang max, accent = en cours), rang dessous,
    -- niveaux où les points sont pris en or au coin haut droit
    Node = function(self, i)
        local n = self.nodes[i]
        if n then return n end
        n = CreateFrame("Button", nil, self.treeHost)
        n:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        n:SetFrameLevel(self.treeHost:GetFrameLevel() + 3)
        n.edge = n:CreateTexture(nil, "BACKGROUND"); n.edge:SetAllPoints()
        n.icon = n:CreateTexture(nil, "ARTWORK"); n.icon:SetPoint("TOPLEFT", 2, -2)
        n.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        n.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        -- pastilles : rang (sous l'icône) et niveaux (coin haut droit), chacune dans son petit cadre arrondi
        n.rkF = CreateFrame("Frame", nil, n); n.rkF:SetHeight(14); n.rkF:SetPoint("CENTER", n, "BOTTOM", 0, -1)
        n.rkF:SetFrameLevel(n:GetFrameLevel() + 2)
        n.rkBg = UI:Rounded(n.rkF, 5, 0, "BACKGROUND", 1)
        n.rk = UI:Text(n.rkF, 10, C.text); n.rk:SetPoint("CENTER", 0, 0)
        n.lvF = CreateFrame("Frame", nil, n); n.lvF:SetHeight(14); n.lvF:SetPoint("CENTER", n, "TOPRIGHT", -2, 0)
        n.lvF:SetFrameLevel(n:GetFrameLevel() + 2)
        n.lvBg = UI:Rounded(n.lvF, 5, 0, "BACKGROUND", 1)
        n.lv = UI:Text(n.lvF, 10, { 0.14, 0.1, 0 }); n.lv:SetPoint("CENTER", 0, 0)
        n:SetScript("OnClick", function(s, btn)
            local _, ai = CP():Active(self.class)
            if not ai then return end
            if btn == "RightButton" then CP():RemoveLast(self.class, ai)
            else
                local ok, why = CP():AddStep(self.class, ai, s.ti, s.j)
                if not ok and why then WK:Print(why) end
            end
            self:Refresh()
        end)
        n:SetScript("OnEnter", function(s)
            local GT = _G.GameTooltip
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            if s.d and s.d[7] and GT.SetSpellByID then pcall(GT.SetSpellByID, GT, s.d[7])
            else GT:SetText(s.d and s.d[1] or "", 1, 1, 1) end
            GT:AddLine(" ")
            GT:AddLine(string.format(T("Rang %d / %d"), s.r or 0, s.d and s.d[6] or 1), 1, 1, 1)
            if s.when then GT:AddLine(string.format(T("Niveaux : %s"), s.when), C.gold[1], C.gold[2], C.gold[3]) end
            if s.why then GT:AddLine(s.why, C.negative[1], C.negative[2], C.negative[3], true) end
            GT:AddLine(T("Clic : point suivant du plan · clic droit : retirer le dernier"), 0.6, 0.6, 0.6)
            GT:Show()
        end)
        n:SetScript("OnLeave", function() _G.GameTooltip:Hide() end)
        self.nodes[i] = n
        return n
    end,
    -- trait de prérequis (textures réutilisées : segments droits)
    Link = function(self, i)
        local t = self.links[i]
        if t then return t end
        t = self.treeHost:CreateTexture(nil, "BORDER")
        self.links[i] = t
        return t
    end,

    -- une puce de sort (bouton réutilisé)
    Chip = function(self, i)
        local b = self.chips[i]
        if b then return b end
        b = CreateFrame("Button", nil, self.spells.child)
        b:SetHeight(22)
        b.bg = UI:Rounded(b, 6, 0, "BACKGROUND", 1)
        b.edge = UI:Rounded(b, 6, 1, "BORDER", 1)
        b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(16, 16); b.icon:SetPoint("LEFT", 4, 0)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.t = UI:Text(b, 11, C.text); b.t:SetPoint("LEFT", 24, 0)
        if b.t.SetWordWrap then b.t:SetWordWrap(false) end
        -- clic : ce rang et les suivants écartés (ou ce rang et ceux d'avant remis) ; Maj + clic : ce rang seul
        b:SetScript("OnClick", function(s)
            local cp = CP()
            local plan, ai = cp:Active(self.class)
            if not (ai and s.e) then return end
            local base = s.e.skipKey or s.e.name
            local function rn(e) return tonumber((tostring(e.rank or ""):gsub("%D", ""))) end
            local mine = rn(s.e)
            local v = not s.skipped
            if not mine or (_G.IsShiftKeyDown and _G.IsShiftKeyDown()) then
                cp:SetSkip(self.class, ai, base, v, s.e.rank)
            else
                for _, e in ipairs(self.allSpells or {}) do
                    local r = rn(e)
                    if (e.skipKey or e.name) == base and r and ((v and r >= mine) or (not v and r <= mine)) then
                        if cp:Skipped(plan, base, e.rank) ~= v then cp:SetSkip(self.class, ai, base, v, e.rank) end
                    end
                end
            end
            self:Refresh()
        end)
        b:SetScript("OnEnter", function(s)
            if not s.e then return end
            local GT = _G.GameTooltip
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            if GT.SetSpellByID then pcall(GT.SetSpellByID, GT, s.e.id) else GT:SetText(s.e.name, 1, 1, 1) end
            GT:AddLine(" ")
            if s.e.pet then
                GT:AddLine(string.format(T("Familier de niveau %d"), s.e.level), 1, 0.82, 0)
                if s.e.fams and #s.e.fams > 0 then
                    GT:AddLine(table.concat(s.e.fams, ", "), 0.85, 0.85, 0.85, true)
                end
                local hint = s.skipped and T("Écarté du plan · clic : le garder")
                    or T("Dans le plan · clic : l'écarter")
                GT:AddLine(hint, 0.6, 0.6, 0.6)
            else
                local back = T("Écarté : pas acheté chez le maître · clic : le reprendre, avec les rangs d'avant")
                local how = s.skipped and back or T("Acheté chez le maître · clic : l'écarter, avec les rangs suivants")
                GT:AddLine(how, 0.6, 0.6, 0.6, true)
                GT:AddLine(T("Maj + clic : ce rang seul"), 0.6, 0.6, 0.6)
            end
            GT:Show()
        end)
        b:SetScript("OnLeave", function() _G.GameTooltip:Hide() end)
        self.chips[i] = b
        return b
    end,

    Refresh = function(self)
        if not self.classBtns then return end
        local class = self.class
        local cp = CP()
        self:PaintClasses()
        local plan = cp:Active(class)
        -- bandeau : menu du plan (ou « + plan » si la classe n'en a aucun)
        self.dd:SetShown(plan ~= nil); self.nums:SetShown(plan ~= nil); self.newBtn:SetShown(plan == nil)
        if not plan then self.nameIn:Hide(); self.delOk:Hide() end
        if plan then
            self:PaintDD()
            self.dd.name:SetText(plan.name)
            local sp = self:Split(plan)
            local cols = { C.gold, C.info, C.negative }
            local x = 0
            for k = 1, 3 do
                local t = self.dd.split[k]
                local w = 110 * sp[k] / 51
                t:ClearAllPoints(); t:SetPoint("LEFT", self.dd.splitBg, "LEFT", x, 0); t:SetWidth(math.max(0.01, w))
                t:SetColorTexture(cols[k][1], cols[k][2], cols[k][3], 1); t:SetShown(w > 0)
                x = x + w
            end
            self.dd.splitBg:SetColorTexture(C.surface2[1], C.surface2[2], C.surface2[3], 1)
            self.nums:SetText(string.format("%s%d / %d / %d|r  ·  %d / 51", UI:Hex(C.text), sp[1], sp[2], sp[3],
                #plan.steps))
        end
        -- persos de la classe : pastille par perso (accent = suit le plan, clic = suivre ou non)
        local chars = cp:Chars(class)
        local fx = 0
        for i = 1, math.max(#chars, #self.followBtns) do
            local b = self.followBtns[i]
            local e = chars[i]
            if not b and e then
                b = UI:Button(self.head, "", nil, 26, "ghost")
                b:SetScript("OnClick", function(s) cp:SetFollow(s.key, not cp:Follows(s.key)); self:Refresh() end)
                b.tooltip = "Clic : ce perso suit le plan de sa classe, ou n'en suit aucun (sauf un ancien plan à lui)."
                self.followBtns[i] = b
            end
            if b then
                if e and i <= 4 then
                    b.key = e.key
                    b:SetLabel(string.format("%s (%d)", WK:CharName(e.c, e.key), e.c.level or 1))
                    b:SetStyle(cp:Follows(e.key) and "secondary" or "ghost")
                    b:ClearAllPoints(); b:SetPoint("RIGHT", self.head, "RIGHT", -fx, 0); b:Show()
                    fx = fx + b:GetWidth() + 6
                else b:Hide() end
            end
        end
        self.follow:ClearAllPoints(); self.follow:SetPoint("RIGHT", self.head, "RIGHT", -fx - 4, 0)
        self.follow:SetText(#chars > 0 and T("Suivi par") or T("Aucun perso de cette classe pour l'instant"))
        -- onglet affiché
        self.tabs:Select(self.tab)
        self.left:SetShown(self.tab == "talents"); self.right:SetShown(self.tab == "spells")
        self:RefreshTalents(plan)
        self:RefreshSpells(plan)
        local sp = self:Split(plan)
        self.tabSum:SetText(plan and (self.tab == "talents" and string.format(T("Talents %d / %d / %d"), sp[1], sp[2],
            sp[3]) or (self.selCost:GetText() or "")) or "")
    end,

    RefreshTalents = function(self, plan)
        local cp = CP()
        local trees = cp:Trees(self.class)
        for _, n in ipairs(self.nodes) do n:Hide() end
        for _, h in ipairs(self.treeHeads) do h:Hide() end
        for _, l in ipairs(self.links) do l:Hide() end
        for _, l in ipairs(self.rowLabs) do l:Hide() end
        local msg
        if not plan then msg = T("Pas encore de plan pour cette classe : « + plan » pour en créer un.")
        elseif not trees then msg = T("Arbres de talents introuvables pour cette classe.") end
        self.leftMsg:SetText(msg or ""); self.leftMsg:SetShown(msg ~= nil)
        self.undo:SetShown(plan ~= nil and trees ~= nil)
        self.left.subtitle:SetText(plan and string.format(T("%d / 51 points prévus"), #plan.steps) or "")
        local foot = T("Chiffre doré : niveaux où le point est pris. Rangée fermée : 5 points par rangée dans"
            .. " l'arbre. Trait : prérequis (au rang max).")
        if trees and not trees.static and not cp:HasEdges(trees) then
            foot = UI:Hex(C.warning) .. T("Prérequis pas encore relevés : connecte un perso de cette classe (ils sont"
                .. " lus dans la fenêtre des talents du jeu).") .. "|r"
        end
        self.leftFoot:SetText(plan and trees and foot or "")
        if msg then return end
        local TP = WK.modules.TalentPlan
        local labels = TP:LevelLabels(plan)
        local ranks = TP:Ranks(plan)
        local W, H = self.treeHost:GetWidth() or 600, self.treeHost:GetHeight() or 400
        local nT = #trees
        local tw = (W - (nT - 1) * 24) / math.max(1, nT)
        local idx, li, ri = 0, 0, 0
        local ar, ag, ab = UI:Accent()
        local function seg(x1, y1, x2, y2, col)
            li = li + 1
            local t = self:Link(li)
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", math.min(x1, x2) - 1.5, -(math.min(y1, y2) - 1.5))
            t:SetSize(math.abs(x2 - x1) + 3, math.abs(y2 - y1) + 3)
            t:SetColorTexture(col[1], col[2], col[3], col[4] or 1); t:Show()
        end
        for ti, t in ipairs(trees) do
            local h = self.treeHeads[ti]
            if not h then h = UI:Text(self.treeHost, 13, C.text); self.treeHeads[ti] = h end
            local inTree = 0
            for k, v in pairs(ranks) do if k:match("^(%d+):") == tostring(ti) then inTree = inTree + v end end
            local maxCol, maxRow = 4, 1
            for _, d in ipairs(t.list or {}) do
                if (d[4] or 1) > maxCol then maxCol = d[4] end
                if (d[3] or 1) > maxRow then maxRow = d[3] end
            end
            -- case : remplit la largeur de l'arbre et la hauteur disponible (icônes de 34 à 52 px)
            local cell = math.floor(math.min((tw - 22) / maxCol, (H - 30) / maxRow, 64))
            local size = math.max(24, math.min(52, cell - 14))
            local x0 = (ti - 1) * (tw + 24) + 22 + ((tw - 22) - cell * maxCol) / 2
            h:ClearAllPoints(); h:SetPoint("TOPLEFT", self.treeHost, "TOPLEFT", x0, 0)
            h:SetText(string.format("%s  %s%d|r", t.name or "", UI:Hex(C.gold), inTree)); h:Show()
            local pos = {}
            -- rangées : chiffre des points demandés à gauche, rouge tant que la rangée est fermée
            for row = 2, maxRow do
                ri = ri + 1
                local l = self.rowLabs[ri]
                if not l then l = UI:Text(self.treeHost, 10, C.dim); self.rowLabs[ri] = l end
                local need = (row - 1) * 5
                l:SetTextColor(unpack(inTree >= need and C.dim or C.negative))
                l:SetText(need)
                local ly = 24 + (row - 1) * cell + cell / 2 - 6
                l:ClearAllPoints(); l:SetPoint("CENTER", self.treeHost, "TOPLEFT", x0 - 14, -ly)
                l:Show()
            end
            for j, d in ipairs(t.list or {}) do
                idx = idx + 1
                local n = self:Node(idx)
                local r = ranks[ti .. ":" .. j] or 0
                local max = d[6] or 1
                local open = inTree >= ((d[3] or 1) - 1) * 5
                local pj, pmax, pd = cp:Prereq(self.class, trees, ti, j)
                local preOk = not pj or (ranks[ti .. ":" .. pj] or 0) >= pmax
                n.ti, n.j, n.d, n.r = ti, j, d, r
                n.when = labels[ti .. ":" .. j]
                local needRow = ((d[3] or 1) - 1) * 5
                n.why = (not open and string.format(T("Rangée fermée : %d points dans %s (%d)."), needRow,
                    t.name or "", inTree))
                    or (not preOk and string.format(T("Il faut d'abord %s au rang %d."), pd and pd[1] or "?", pmax))
                    or nil
                n:SetSize(size, size)
                local x = x0 + ((d[4] or 1) - 1) * cell + (cell - size) / 2
                local y = 24 + ((d[3] or 1) - 1) * cell + (cell - size) / 2 - 6
                pos[j] = { x + size / 2, y, y + size, size / 2 }
                n:ClearAllPoints(); n:SetPoint("TOPLEFT", x, -y)
                n.icon:SetTexture(d[2] or 134400)
                local locked = r == 0 and (not open or not preOk)
                if n.icon.SetDesaturated then n.icon:SetDesaturated(r == 0) end
                n.icon:SetAlpha(r > 0 and 1 or (locked and 0.25 or 0.6))
                if r >= max then n.edge:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 1)
                elseif r > 0 then n.edge:SetColorTexture(ar, ag, ab, 1)
                else n.edge:SetColorTexture(C.border[1], C.border[2], C.border[3], locked and 0.5 or 1) end
                n.rk:SetText(r .. "/" .. max)
                n.rk:SetTextColor(unpack(r > 0 and C.text or C.muted))
                n.rkF:SetWidth((n.rk:GetStringWidth() or 18) + 10)
                n.rkBg:SetColor(C.bg[1], C.bg[2], C.bg[3], 0.95)
                -- niveaux (or) : « 21 · 22 · 23 », ou « 21…25 » au-delà de deux
                local lv = n.when
                if lv then
                    local nums = {}
                    for v in lv:gmatch("%d+") do nums[#nums + 1] = v end
                    lv = #nums > 2 and (nums[1] .. "…" .. nums[#nums]) or table.concat(nums, " · ")
                end
                n.lv:SetText(lv or "")
                n.lvF:SetWidth((n.lv:GetStringWidth() or 10) + 8)
                n.lvBg:SetColor(C.gold[1], C.gold[2], C.gold[3], 1)
                n.lvF:SetShown(lv ~= nil and lv ~= "")
                n:Show()
            end
            -- traits de prérequis : du bas du talent demandé au haut du talent visé (coude à mi-hauteur)
            for j in ipairs(t.list or {}) do
                local pj, pmax = cp:Prereq(self.class, trees, ti, j)
                if pj and pos[pj] and pos[j] then
                    local ok = (ranks[ti .. ":" .. pj] or 0) >= pmax
                    local col = ok and { C.gold[1], C.gold[2], C.gold[3], 1 }
                        or { C.muted[1], C.muted[2], C.muted[3], 0.6 }
                    local a, b = pos[pj], pos[j]
                    if math.abs(a[2] - b[2]) < 1 then
                        -- même rangée : trait horizontal entre les deux bords, à mi-hauteur
                        local dir = b[1] > a[1] and 1 or -1
                        local ym = (a[2] + a[3]) / 2
                        seg(a[1] + dir * a[4], ym, b[1] - dir * b[4], ym, col)
                    else
                        local xa, ya, xb, yb = a[1], a[3] + 6, b[1], b[2] - 1
                        local ym = (ya + yb) / 2
                        seg(xa, ya, xa, ym, col); seg(xa, ym, xb, ym, col); seg(xb, ym, xb, yb, col)
                    end
                end
            end
        end
    end,

    RefreshSpells = function(self, plan)
        local cp, CS = CP(), WK.modules.ClassSpells
        for _, r in ipairs(self.lvRows) do r:Hide() end
        for _, b in ipairs(self.chips) do b:Hide() end
        if self.petHead then self.petHead:Hide(); self.petNote:Hide() end
        if not plan then
            self.right.subtitle:SetText(""); self.selCost:SetText(""); self.spells:SetContentHeight(1)
            return
        end
        local tal = cp:TalentNames(plan)
        local byLvl, levels = {}, {}
        for _, e in ipairs(CS:Catalog(self.class)) do
            if not e.talent or tal[e.name] then
                if not byLvl[e.level] then byLvl[e.level] = {}; levels[#levels + 1] = e.level end
                table.insert(byLvl[e.level], e)
            end
        end
        table.sort(levels)
        -- familiers (démoniste : démons, grimoires du maître des démons ; chasseur : techniques du familier)
        local petLvl, petLevels = {}, {}
        for _, e in ipairs(CS:PetCatalog(self.class)) do
            e.skipKey = "pet:" .. e.name
            if not petLvl[e.level] then petLvl[e.level] = {}; petLevels[#petLevels + 1] = e.level end
            table.insert(petLvl[e.level], e)
        end
        table.sort(petLevels)
        -- tous les sorts affichés (clic sur un rang : les rangs du même sort)
        self.allSpells = {}
        for _, lv in ipairs(levels) do for _, e in ipairs(byLvl[lv]) do table.insert(self.allSpells, e) end end
        for _, lv in ipairs(petLevels) do for _, e in ipairs(petLvl[lv]) do table.insert(self.allSpells, e) end end
        local W = math.max(200, (self.spells:GetWidth() or 400) - 16)
        self.spells.child:SetWidth(W)
        local y, ci, ri, total, kept = 0, 0, 0, 0, 0
        local ar, ag, ab = UI:Accent()
        local function drawLevels(lvls, by)
            for _, lv in ipairs(lvls) do
                ri = ri + 1
                local row = self.lvRows[ri]
                if not row then
                    row = CreateFrame("Frame", nil, self.spells.child)
                    row.n = UI:Text(row, 14); row.n:SetPoint("TOPLEFT", 4, -4); row.n:SetWidth(30)
                    row.n:SetJustifyH("CENTER")
                    row.cost = UI:Text(row, 11, C.gold); row.cost:SetPoint("TOPRIGHT", -4, -6)
                    row.cost:SetJustifyH("RIGHT")
                    row.line = row:CreateTexture(nil, "BACKGROUND"); row.line:SetHeight(1)
                    row.line:SetPoint("BOTTOMLEFT"); row.line:SetPoint("BOTTOMRIGHT")
                    row.line:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
                    self.lvRows[ri] = row
                end
                row.n:SetText(lv)
                -- puces en lignes, entre le niveau (40 px) et le coût (78 px)
                local cx, cy, sum = 0, 0, 0
                local avail = W - 40 - 82
                for _, e in ipairs(by[lv]) do
                    ci = ci + 1
                    local b = self:Chip(ci)
                    b.e = e
                    b.skipped = cp:Skipped(plan, e.skipKey or e.name, e.rank)
                    local rk = (e.rank or ""):gsub("[^%d]", "")
                    b.t:SetText(e.name .. (rk ~= "" and (" " .. UI:Hex(C.muted) .. rk .. "|r") or ""))
                    b.icon:SetTexture(e.icon or 134400)
                    if b.icon.SetDesaturated then b.icon:SetDesaturated(b.skipped) end
                    b:SetAlpha(b.skipped and 0.45 or 1)
                    b.bg:SetColor(unpack(C.surface2))
                    if e.talent then b.edge:SetColor(0.71, 0.55, 1, 0.8)
                    else b.edge:SetColor(ar, ag, ab, b.skipped and 0 or 0.35) end
                    local bw = math.min(avail, (b.t:GetStringWidth() or 60) + 30)
                    b:SetWidth(bw)
                    if cx > 0 and cx + bw > avail then cx = 0; cy = cy + 26 end
                    b:ClearAllPoints(); b:SetPoint("TOPLEFT", 40 + cx, -(y + 3 + cy))
                    b:Show()
                    cx = cx + bw + 6
                    if not b.skipped then
                        kept = kept + 1
                        -- familier : prix connu seulement (pas d'estimation d'après les sorts de classe)
                        local pr, how = CS:Price(self.class, e)
                        if not (e.pet and how == "est") then sum = sum + (pr or 0) end
                    end
                end
                local h = cy + 30
                row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -y); row:SetPoint("TOPRIGHT", 0, -y); row:SetHeight(h)
                row.cost:SetText(sum > 0 and CS:Money(sum) or UI:Hex(C.dim) .. "-|r")
                row:Show()
                total = total + sum
                y = y + h + 2
            end
        end
        drawLevels(levels, byLvl)
        if not self.petHead then
            self.petHead = UI:Text(self.spells.child, 13, C.text)
            self.petNote = UI:Text(self.spells.child, 11, C.muted)
        end
        self.petHead:SetShown(#petLevels > 0)
        self.petNote:SetShown(#petLevels > 0)
        if #petLevels > 0 then
            y = y + 12
            self.petHead:ClearAllPoints(); self.petHead:SetPoint("TOPLEFT", 4, -y)
            self.petHead:SetText(self.class == "WARLOCK" and T("Démons") or T("Familier"))
            self.petNote:ClearAllPoints(); self.petNote:SetPoint("TOPLEFT", self.petHead, "TOPRIGHT", 10, 0)
            self.petNote:SetText(self.class == "WARLOCK"
                and T("grimoires du maître des démons · niveau du démon")
                or T("techniques apprises en apprivoisant · niveau du familier"))
            y = y + 24
            drawLevels(petLevels, petLvl)
        end
        self.spells:SetContentHeight(y + 4)
        self.right.subtitle:SetText(string.format(T("%d sorts choisis"), kept))
        self.selCost:SetText(UI:Hex(C.muted) .. T("Sélection") .. "|r  " .. CS:Money(total))
    end,
})

-- Pastilles de l'en-tête : classe choisie, plans, points prévus
UI.CHIPS.leveling = function()
    local def = UI.pages and UI.pages.leveling
    local me = WK.DB.global.characters[WK:CharKey()]
    local class = (def and def.class) or WK.DB.global.settings.ui.levelClass or (me and me.class)
    if not class then return {} end
    local cp = WK.modules.ClassPlan
    local plan = cp:Active(class)
    return {
        { T("Classe"), T(CLASS_LABEL[class] or class) },
        { T("Plans"), tostring(#cp:Plans(class)) },
        { T("Points prévus"), plan and (#plan.steps .. " / 51") or "-" },
    }
end
