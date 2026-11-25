local _, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Page Leveling (maquette A) : barre des 9 classes, puis le plan de montée de la classe choisie
-- (Modules/ClassPlan.lua) en deux colonnes : à gauche les arbres de talents avec l'ordre des points
-- (clic = point suivant, clic droit = retirer le dernier), à droite les sorts du maître rangés par niveau
-- (clic = acheter / écarter). Tous les persos de la classe suivent le plan actif (pastilles « Suivi par »).
local CreateFrame = _G.CreateFrame
local GAP = 12
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

        -- bandeau : plans de la classe, nom, persos qui suivent --------------------------------------------
        local head = CreateFrame("Frame", nil, p)
        head:SetPoint("TOPLEFT", 0, -58 - 8); head:SetPoint("TOPRIGHT", 0, -58 - 8); head:SetHeight(30)
        self.planBtns = {}
        self.newBtn = UI:Button(head, "+ plan", nil, 26, "ghost")
        self.newBtn:SetScript("OnClick", function()
            local n = #CP():Plans(self.class) + 1
            local i = CP():New(self.class, string.format(T("Plan %d"), n))
            CP():SetActive(self.class, i)
            self:Refresh()
        end)
        self.copyBtn = UI:Button(head, "Copier mon plan", nil, 26, "ghost")
        self.copyBtn.tooltip = "Reprend l'ancien plan de montée de ce perso (d'avant cette page) comme plan de la classe."
        self.copyBtn:SetScript("OnClick", function()
            local key = WK:CharKey()
            local pp = WK.modules.TalentPlan:Active(key)
            if not pp then return end
            local i = CP():New(self.class, pp.name, pp.steps)
            CP():SetActive(self.class, i)
            self:Refresh()
        end)
        self.nameIn = UI:Input(head, 150, 26, "Nom du plan")
        self.nameIn.onEnter = function()
            local _, ai = CP():Active(self.class)
            if ai then CP():Rename(self.class, ai, self.nameIn:GetText()) end
            self:Refresh()
        end
        self.del = UI:IconButton(head, "trash", 22, "Supprimer ce plan (deux clics)", true)
        self.del:SetScript("OnClick", function(b)
            local _, ai = CP():Active(self.class)
            if not ai then return end
            if not b.armed then
                b.armed = true
                _G.C_Timer.After(3, function() b.armed = nil end)
                WK:Print(T("Clique encore sur la corbeille pour supprimer ce plan."))
                return
            end
            b.armed = nil
            CP():Delete(self.class, ai)
            self:Refresh()
        end)
        self.follow = UI:Text(head, 11, C.muted)
        self.followBtns = {}

        -- deux colonnes ------------------------------------------------------------------------------------
        local body = CreateFrame("Frame", nil, p)
        body:SetPoint("TOPLEFT", 0, -58 - 8 - 30 - 10); body:SetPoint("BOTTOMRIGHT")
        self.left = UI:Card(body, T("Talents"), " ")
        self.right = UI:Card(body, T("Achats chez le maître"), " ")
        UI:OnResize(body, function(w)
            local half = (w - GAP) / 2
            self.left:ClearAllPoints(); self.left:SetPoint("TOPLEFT"); self.left:SetPoint("BOTTOMLEFT")
            self.left:SetWidth(half)
            self.right:ClearAllPoints(); self.right:SetPoint("TOPRIGHT"); self.right:SetPoint("BOTTOMRIGHT")
            self.right:SetWidth(half)
            UI:RefreshSoon()
        end)
        -- arbres
        self.treeHost = CreateFrame("Frame", nil, self.left)
        self.treeHost:SetPoint("TOPLEFT", 12, -40); self.treeHost:SetPoint("BOTTOMRIGHT", -12, 46)
        self.treeHeads, self.nodes = {}, {}
        self.leftMsg = UI:Text(self.left, 12, C.muted); self.leftMsg:SetPoint("TOPLEFT", 16, -44)
        self.leftMsg:SetPoint("TOPRIGHT", -16, -44); self.leftMsg:SetJustifyH("LEFT")
        if self.leftMsg.SetWordWrap then self.leftMsg:SetWordWrap(true) end
        self.undo = UI:Button(self.left, "Annuler le dernier point", nil, 24, "secondary")
        self.undo:SetPoint("BOTTOMLEFT", 12, 12)
        self.undo:SetScript("OnClick", function()
            local _, ai = CP():Active(self.class)
            if ai then CP():RemoveLast(self.class, ai); self:Refresh() end
        end)
        self.leftFoot = UI:Text(self.left, 10, C.dim); self.leftFoot:SetPoint("LEFT", self.undo, "RIGHT", 10, 0)
        self.leftFoot:SetPoint("RIGHT", -12, 0); self.leftFoot:SetJustifyH("LEFT")
        -- achats
        self.spells = UI:Scroll(self.right)
        self.spells:SetPoint("TOPLEFT", 8, -40); self.spells:SetPoint("BOTTOMRIGHT", -8, 34)
        self.lvRows, self.chips = {}, {}
        self.rightFoot = UI:Text(self.right, 10, C.dim); self.rightFoot:SetPoint("BOTTOMLEFT", 14, 12)
        self.rightFoot:SetPoint("BOTTOMRIGHT", -14, 12); self.rightFoot:SetJustifyH("LEFT")
        self.rightFoot:SetText(T("Clic sur un sort : l'acheter ou l'écarter chez le maître. Bordure violette : sort"
            .. " d'un talent du plan."))
    end,

    -- un nœud de talent (bouton réutilisé)
    Node = function(self, i)
        local n = self.nodes[i]
        if n then return n end
        n = CreateFrame("Button", nil, self.treeHost)
        n:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        n.bg = n:CreateTexture(nil, "BACKGROUND"); n.bg:SetAllPoints(); n.bg:SetColorTexture(0, 0, 0, 0.5)
        n.icon = n:CreateTexture(nil, "ARTWORK"); n.icon:SetPoint("TOPLEFT", 2, -2)
        n.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        n.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        n.edge = n:CreateTexture(nil, "BORDER"); n.edge:SetAllPoints()
        n.lab = UI:Text(n, 9, C.text); n.lab:SetPoint("BOTTOMRIGHT", 3, -3)
        if n.lab.SetIgnoreParentAlpha then n.lab:SetIgnoreParentAlpha(true) end
        n.rk = UI:Text(n, 9, C.muted); n.rk:SetPoint("TOPLEFT", -2, 3)
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
            GT:SetText(s.d and s.d[1] or "", 1, 1, 1)
            if s.when then GT:AddLine(string.format(T("Niveaux : %s"), s.when), C.muted[1], C.muted[2], C.muted[3]) end
            GT:AddLine(T("Clic : point suivant du plan · clic droit : retirer le dernier"), 0.6, 0.6, 0.6)
            GT:Show()
        end)
        n:SetScript("OnLeave", function() _G.GameTooltip:Hide() end)
        self.nodes[i] = n
        return n
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
        b:SetScript("OnClick", function(s)
            local _, ai = CP():Active(self.class)
            if not (ai and s.e) then return end
            CP():SetSkip(self.class, ai, s.e.skipKey or s.e.name, not s.skipped)
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
                GT:AddLine(s.skipped and T("Écarté : pas acheté chez le maître · clic : l'acheter")
                    or T("Acheté chez le maître · clic : l'écarter"), 0.6, 0.6, 0.6)
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
        local plans = cp:Plans(class)
        local plan, ai = cp:Active(class)
        -- bandeau
        local x = 0
        for i = 1, math.max(#plans, #self.planBtns) do
            local b = self.planBtns[i]
            if not b and plans[i] then
                b = UI:Button(self.newBtn:GetParent(), "", nil, 26, "ghost")
                b:SetScript("OnClick", function() cp:SetActive(self.class, i); self:Refresh() end)
                self.planBtns[i] = b
            end
            if b then
                if plans[i] then
                    b:SetLabel(plans[i].name); b:SetStyle(i == ai and "primary" or "ghost")
                    b:ClearAllPoints(); b:SetPoint("LEFT", x, 0); b:Show()
                    x = x + b:GetWidth() + 6
                else b:Hide() end
            end
        end
        self.newBtn:ClearAllPoints(); self.newBtn:SetPoint("LEFT", x, 0); x = x + self.newBtn:GetWidth() + 6
        local myKey = WK:CharKey()
        local mine = WK.DB.global.characters[myKey]
        local canCopy = mine and mine.class == class and WK.modules.TalentPlan:Active(myKey) ~= nil
        self.copyBtn:SetShown(canCopy and true or false)
        if canCopy then
            self.copyBtn:ClearAllPoints(); self.copyBtn:SetPoint("LEFT", x, 0); x = x + self.copyBtn:GetWidth() + 6
        end
        self.nameIn:SetShown(plan ~= nil); self.del:SetShown(plan ~= nil)
        if plan then
            self.nameIn:ClearAllPoints(); self.nameIn:SetPoint("LEFT", x + 6, 0)
            -- nom remis seulement en changeant de plan (pas pendant la frappe : la page se redessine souvent)
            local nk = self.class .. ":" .. ai .. ":" .. plan.name
            if self.nameFor ~= nk then self.nameFor = nk; self.nameIn:SetText(plan.name) end
            self.del:ClearAllPoints(); self.del:SetPoint("LEFT", self.nameIn, "RIGHT", 6, 0)
        end
        -- persos de la classe : pastille par perso (accent = suit le plan, clic = suivre ou non)
        local chars = cp:Chars(class)
        local fx = 0
        for i = 1, math.max(#chars, #self.followBtns) do
            local b = self.followBtns[i]
            local e = chars[i]
            if not b and e then
                b = UI:Button(self.newBtn:GetParent(), "", nil, 24, "ghost")
                b:SetScript("OnClick", function(s) cp:SetFollow(s.key, not cp:Follows(s.key)); self:Refresh() end)
                b.tooltip = "Clic : ce perso suit le plan de sa classe, ou n'en suit aucun (sauf un ancien plan à lui)."
                self.followBtns[i] = b
            end
            if b then
                if e and i <= 4 then
                    b.key = e.key
                    b:SetLabel(string.format("%s (%d)", WK:CharName(e.c, e.key), e.c.level or 1))
                    b:SetStyle(cp:Follows(e.key) and "secondary" or "ghost")
                    b:ClearAllPoints(); b:SetPoint("RIGHT", self.newBtn:GetParent(), "RIGHT", -fx, 0); b:Show()
                    fx = fx + b:GetWidth() + 6
                else b:Hide() end
            end
        end
        self.follow:ClearAllPoints(); self.follow:SetPoint("RIGHT", self.newBtn:GetParent(), "RIGHT", -fx - 4, 0)
        self.follow:SetText(#chars > 0 and T("Suivi par") or T("Aucun perso de cette classe pour l'instant"))
        self:RefreshTalents(plan)
        self:RefreshSpells(plan)
    end,

    RefreshTalents = function(self, plan)
        local cp = CP()
        local trees = cp:Trees(self.class)
        for _, n in ipairs(self.nodes) do n:Hide() end
        for _, h in ipairs(self.treeHeads) do h:Hide() end
        local msg
        if not plan then msg = T("Pas encore de plan pour cette classe : « + plan » pour en créer un.")
        elseif not trees then
            msg = T("Arbres de talents pas encore relevés : connecte une fois un perso de cette classe (ils le sont"
                .. " à la connexion).")
        end
        self.leftMsg:SetText(msg or ""); self.leftMsg:SetShown(msg ~= nil)
        self.undo:SetShown(plan ~= nil and trees ~= nil)
        local used = 0
        for _ in pairs(plan and plan.steps or {}) do used = used + 1 end
        self.left.subtitle:SetText(plan and string.format(T("%d / 51 points prévus"), #plan.steps) or "")
        self.leftFoot:SetText(plan and trees and T("Le chiffre : niveaux où le point est pris") or "")
        if msg then return end
        local TP = WK.modules.TalentPlan
        local labels = TP:LevelLabels(plan)
        local ranks = TP:Ranks(plan)
        local W = (self.treeHost:GetWidth() or 400)
        local nT = #trees
        local tw = (W - (nT - 1) * 10) / math.max(1, nT)
        local idx = 0
        local ar, ag, ab = UI:Accent()
        for ti, t in ipairs(trees) do
            local h = self.treeHeads[ti]
            if not h then h = UI:Text(self.treeHost, 11, C.muted); self.treeHeads[ti] = h end
            local inTree = 0
            for k, v in pairs(ranks) do if k:match("^(%d+):") == tostring(ti) then inTree = inTree + v end end
            h:ClearAllPoints(); h:SetPoint("TOP", self.treeHost, "TOPLEFT", (ti - 1) * (tw + 10) + tw / 2, 0)
            h:SetText(string.format("%s  %s%d|r", t.name or "", UI:Hex(C.gold), inTree)); h:Show()
            local maxCol = 1
            for _, d in ipairs(t.list or {}) do if (d[4] or 1) > maxCol then maxCol = d[4] end end
            local cell = math.min(40, math.floor(tw / math.max(4, maxCol)))
            local size = cell - 6
            local x0 = (ti - 1) * (tw + 10) + (tw - cell * math.max(4, maxCol)) / 2
            for j, d in ipairs(t.list or {}) do
                idx = idx + 1
                local n = self:Node(idx)
                n.ti, n.j, n.d = ti, j, d
                local r = ranks[ti .. ":" .. j] or 0
                n.when = labels[ti .. ":" .. j]
                n:SetSize(size, size)
                n:ClearAllPoints()
                n:SetPoint("TOPLEFT", x0 + ((d[4] or 1) - 1) * cell + 3, -20 - ((d[3] or 1) - 1) * cell)
                n.icon:SetTexture(d[2] or 134400)
                if n.icon.SetDesaturated then n.icon:SetDesaturated(r == 0) end
                n.icon:SetAlpha(r > 0 and 1 or 0.45)
                n.edge:SetColorTexture(ar, ag, ab, r > 0 and 0.9 or 0)
                n.lab:SetText(n.when and (UI:Hex(C.gold) .. n.when .. "|r") or "")
                n.rk:SetText(r > 0 and string.format("%d/%d", r, d[6] or 1) or "")
                n:Show()
            end
        end
    end,

    RefreshSpells = function(self, plan)
        local cp, CS = CP(), WK.modules.ClassSpells
        for _, r in ipairs(self.lvRows) do r:Hide() end
        for _, b in ipairs(self.chips) do b:Hide() end
        if self.petHead then self.petHead:Hide(); self.petNote:Hide() end
        if not plan then self.right.subtitle:SetText(""); self.spells:SetContentHeight(1) return end
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
        local W = math.max(200, (self.spells:GetWidth() or 400) - 16)
        self.spells.child:SetWidth(W)
        local y, ci, ri, total = 0, 0, 0, 0
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
                    b.skipped = cp:Skipped(plan, e.skipKey or e.name)
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
        self.right.subtitle:SetText(string.format(T("total %s"), CS:Money(total)))
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
