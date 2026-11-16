local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors

---------------------------------------------------------------------------
-- Bouton arrondi (pilule). Styles : primary (accent), secondary, ghost, danger.
---------------------------------------------------------------------------
function UI:Button(parent, text, width, height, style, icon)
    height = height or 30
    local b = CreateFrame("Button", nil, parent)
    b.style = style or "secondary"
    b.bg = UI:Rounded(b, height / 2, 0, "BACKGROUND", 1)
    b.label = UI:Text(b, 12)
    b.label:SetText(text or "")
    if icon then
        b.icon = UI:Icon(b, icon, 14)
        b.label:SetPoint("CENTER", 9, 0)
        b.icon:SetPoint("RIGHT", b.label, "LEFT", -6, 0)
    else
        b.label:SetPoint("CENTER")
    end
    b:SetSize(width or (b.label:GetStringWidth() + 32 + (icon and 20 or 0)), height)

    function b:Refresh()
        local s, h = self.style, self.hover
        local fg
        if s == "primary" then
            local r, g, bl = UI:Accent()
            local k = h and 1.12 or 1
            self.bg:SetColor(math.min(r * k, 1), math.min(g * k, 1), math.min(bl * k, 1), 1)
            self.bg:Show()
            fg = C.onAccent
        elseif s == "ghost" then
            self.bg:SetColor(unpack(C.hover))
            self.bg:SetShown(h)
            fg = h and C.text or C.muted
        elseif s == "danger" then
            self.bg:SetColor(C.negative[1], C.negative[2], C.negative[3], h and 0.28 or 0.16)
            self.bg:Show()
            fg = C.negative
        else
            self.bg:SetColor(unpack(h and C.hover or C.surface2))
            self.bg:Show()
            fg = C.text
        end
        self.label:SetTextColor(unpack(fg))
        if self.icon then self.icon:SetVertexColor(unpack(fg)) end
        self:SetAlpha(self:IsEnabled() and 1 or 0.45)
    end

    function b:SetStyle(st) self.style = st; self:Refresh() end
    function b:SetLabel(t) self.label:SetText(t) end

    b:SetScript("OnEnter", function(self)
        self.hover = true; self:Refresh()
        if self.tooltip then
            WK.UI:TooltipOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(WK.T(self.tooltip), 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self) self.hover = false; self:Refresh(); GameTooltip:Hide() end)
    b:SetScript("OnDisable", function(self) self:Refresh() end)
    b:SetScript("OnEnable", function(self) self:Refresh() end)
    UI:OnAccent(function() b:Refresh() end)
    return b
end

-- Bouton rond ne contenant qu'une icône (fermer, supprimer...).
function UI:IconButton(parent, icon, size, tooltip, danger)
    size = size or 28
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b.bg = UI:Rounded(b, size / 2, 0, "BACKGROUND", 1)
    b.icon = UI:Icon(b, icon, math.floor(size * 0.55))
    b.icon:SetPoint("CENTER")
    b.tooltip = tooltip
    -- danger = true : rouge ; danger = "accent" : icône de la couleur d'accent du thème.
    local function refresh(h)
        if danger == "accent" then
            local r, g, bl = UI:Accent()
            b.bg:SetColor(r, g, bl, 0.18)
            b.icon:SetVertexColor(r, g, bl, h and 1 or 0.85)
        elseif danger then
            b.bg:SetColor(C.negative[1], C.negative[2], C.negative[3], 0.2)
            b.icon:SetVertexColor(unpack(h and C.negative or C.muted))
        else
            b.bg:SetColor(unpack(C.hover))
            b.icon:SetVertexColor(unpack(h and C.text or C.muted))
        end
        b.bg:SetShown(h)
    end
    refresh(false)
    b:SetScript("OnEnter", function(self)
        refresh(true)
        if self.tooltip then
            WK.UI:TooltipOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(WK.T(self.tooltip), 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function() refresh(false); GameTooltip:Hide() end)
    if danger == "accent" then UI:OnAccent(function() refresh(false) end) end
    return b
end

---------------------------------------------------------------------------
-- Interrupteur (toggle) en pilule.
---------------------------------------------------------------------------
function UI:Toggle(parent, getter, setter)
    local t = CreateFrame("Button", nil, parent)
    t:SetSize(40, 22)
    t.track = UI:Rounded(t, 11, 0, "BACKGROUND", 1)
    t.knob = UI:Icon(t, "circle", 16, nil, "ARTWORK")
    function t:Refresh()
        local on = getter()
        self.knob:ClearAllPoints()
        if on then
            local r, g, b = UI:Accent()
            self.track:SetColor(r, g, b, 1)
            self.knob:SetPoint("RIGHT", -3, 0)
            self.knob:SetVertexColor(unpack(C.onAccent))
        else
            self.track:SetColor(unpack(C.border))
            self.knob:SetPoint("LEFT", 3, 0)
            self.knob:SetVertexColor(unpack(C.muted))
        end
    end
    t:SetScript("OnClick", function(self)
        setter(not getter())
        self:Refresh()
    end)
    UI:OnAccent(function() t:Refresh() end)
    return t
end

---------------------------------------------------------------------------
-- Barre de progression arrondie.
---------------------------------------------------------------------------
function UI:Progress(parent, height)
    height = height or 6
    local p = CreateFrame("Frame", nil, parent)
    p:SetHeight(height)
    p.track = UI:Rounded(p, height / 2, 0, "BACKGROUND", 1)
    p.track:SetColor(unpack(C.surface2))
    p.fillFrame = CreateFrame("Frame", nil, p)
    p.fillFrame:SetPoint("TOPLEFT")
    p.fillFrame:SetPoint("BOTTOMLEFT")
    p.fill = UI:Rounded(p.fillFrame, height / 2, 0, "ARTWORK", 1)
    p.value = 0

    function p:Apply()
        local w = self:GetWidth()
        if self.value <= 0 or w <= 0 then
            self.fillFrame:Hide()
        else
            self.fillFrame:Show()
            self.fillFrame:SetWidth(math.max(height, w * math.min(self.value, 1)))
        end
        if self.color then self.fill:SetColor(unpack(self.color))
        else local r, g, b = UI:Accent(); self.fill:SetColor(r, g, b, 1) end
    end
    function p:SetValue(v) self.value = v or 0; self:Apply() end
    p:SetScript("OnSizeChanged", function(self) self:Apply() end)
    UI:OnAccent(function() p:Apply() end)
    return p
end

---------------------------------------------------------------------------
-- Champ de saisie arrondi. acceptLinks : Maj+clic sur un objet insère son lien.
---------------------------------------------------------------------------
function UI:Input(parent, width, height, placeholder, icon)
    height = height or 32
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, height)
    UI:Panel(f, height / 2, C.surface, C.border)

    if icon then
        f.icon = UI:Icon(f, icon, 14, C.dim)
        f.icon:SetPoint("LEFT", 12, 0)
    end

    local e = CreateFrame("EditBox", nil, f)
    e:SetAutoFocus(false)
    e:SetFont(UI.FONT, 12, "")
    e:SetTextColor(unpack(C.text))
    e:SetPoint("LEFT", icon and 32 or 14, 0)
    e:SetPoint("RIGHT", -14, 0)
    e:SetHeight(height)
    f.edit = e

    f.placeholder = UI:Text(f, 12, C.dim)
    f.placeholder:SetPoint("LEFT", e, "LEFT", 0, 0)
    f.placeholder:SetText(placeholder or "")

    local function update()
        f.placeholder:SetShown(e:GetText() == "" and not e:HasFocus())
    end
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        if f.onEnter then f.onEnter(self:GetText()) end
    end)
    e:SetScript("OnEditFocusGained", function()
        local r, g, b = UI:Accent()
        f.border:SetColor(r, g, b, 1)
        update()
    end)
    e:SetScript("OnEditFocusLost", function()
        f.border:SetColor(unpack(C.border))
        update()
    end)
    e:SetScript("OnTextChanged", function(self, user)
        update()
        if f.onChange then f.onChange(self:GetText(), user) end
    end)

    function f:GetText() return e:GetText() end
    function f:SetText(t) e:SetText(t or ""); update() end
    table.insert(UI.inputs, e)
    return f
end

-- Insertion des liens d'objets (Maj+clic) dans nos champs qui ont le focus.
local function insertLink(link)
    if not link then return end
    for _, e in ipairs(UI.inputs) do
        if e:HasFocus() and e.acceptLinks then e:SetText(link) end
    end
end
if ChatEdit_InsertLink then hooksecurefunc("ChatEdit_InsertLink", insertLink) end
if ChatFrameUtil and ChatFrameUtil.InsertLink then hooksecurefunc(ChatFrameUtil, "InsertLink", insertLink) end

---------------------------------------------------------------------------
-- Zone défilante avec barre de défilement fine et arrondie.
---------------------------------------------------------------------------
function UI:Scroll(parent)
    local s = CreateFrame("ScrollFrame", nil, parent)
    local child = CreateFrame("Frame", nil, s)
    child:SetSize(1, 1)
    s:SetScrollChild(child)
    s.child = child

    -- Rail cliquable (12 px à droite, hors du contenu) et curseur déplaçable.
    local track = CreateFrame("Frame", nil, s)
    track:SetPoint("TOPRIGHT")
    track:SetPoint("BOTTOMRIGHT")
    track:SetWidth(12)
    track:SetFrameLevel(s:GetFrameLevel() + 5)
    track:EnableMouse(true)
    s.track = track
    local bar = CreateFrame("Frame", nil, track)
    bar:SetWidth(4)
    bar.tex = UI:Rounded(bar, 2, 0, "OVERLAY", 1)
    bar.tex:SetColor(unpack(C.border))

    function s:MaxScroll() return math.max(0, child:GetHeight() - self:GetHeight()) end
    function s:UpdateBar()
        local h, ch = self:GetHeight(), child:GetHeight()
        if ch <= h + 1 or h <= 0 then track:Hide() return end
        track:Show()
        local bh = math.max(24, h * h / ch)
        local pos = (self:GetVerticalScroll() / self:MaxScroll()) * (h - bh)
        bar.bh = bh
        bar:SetHeight(bh)
        bar:SetWidth((track.hover or track.dragging) and 6 or 4)
        bar:ClearAllPoints()
        bar:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -pos)
        bar.tex:SetColor(unpack((track.hover or track.dragging) and C.muted or C.border))
    end

    -- Position du curseur de la souris dans le rail (0 = haut).
    local function cursorOffset()
        local _, y = GetCursorPosition()
        return (track:GetTop() or 0) - y / (track:GetEffectiveScale() or 1)
    end
    -- Place le haut du curseur de défilement à `top` px du haut du rail.
    local function scrollToThumb(top)
        local h = s:GetHeight()
        local room = h - (bar.bh or 24)
        if room <= 0 then return end
        local v = math.max(0, math.min(1, top / room)) * s:MaxScroll()
        s:SetVerticalScroll(v)
        s:UpdateBar()
    end
    track:SetScript("OnMouseDown", function(self, button)
        if button and button ~= "LeftButton" then return end
        local y = cursorOffset()
        local thumbTop = (s:GetVerticalScroll() / math.max(1, s:MaxScroll())) * (s:GetHeight() - (bar.bh or 24))
        -- Clic sur le curseur : on le saisit là où on l'a pris ; clic sur le rail : il saute sous la souris.
        if y >= thumbTop and y <= thumbTop + (bar.bh or 24) then
            self.grab = y - thumbTop
        else
            self.grab = (bar.bh or 24) / 2
            scrollToThumb(y - self.grab)
        end
        self.dragging = true
        self:SetScript("OnUpdate", function() scrollToThumb(cursorOffset() - track.grab) end)
    end)
    track:SetScript("OnMouseUp", function(self)
        self.dragging = false
        self:SetScript("OnUpdate", nil)
        s:UpdateBar()
    end)
    track:SetScript("OnEnter", function(self) self.hover = true; s:UpdateBar() end)
    track:SetScript("OnLeave", function(self) self.hover = false; s:UpdateBar() end)
    track:SetScript("OnHide", function(self)
        self.dragging, self.hover = false, false
        self:SetScript("OnUpdate", nil)
    end)
    track:SetScript("OnMouseWheel", function(_, delta) s:GetScript("OnMouseWheel")(s, delta) end)
    track:EnableMouseWheel(true)
    function s:SetContentHeight(h)
        local w = self:GetWidth()
        if w and w > 12 then child:SetWidth(w - 12) end
        child:SetHeight(math.max(1, h))
        if self:GetVerticalScroll() > self:MaxScroll() then self:SetVerticalScroll(self:MaxScroll()) end
        self:UpdateBar()
    end

    s:EnableMouseWheel(true)
    s:SetScript("OnMouseWheel", function(self, delta)
        local v = math.max(0, math.min(self:MaxScroll(), self:GetVerticalScroll() - delta * 40))
        self:SetVerticalScroll(v)
        self:UpdateBar()
    end)
    s:SetScript("OnSizeChanged", function(self, w)
        child:SetWidth(math.max(1, w - 12))
        self:UpdateBar()
    end)
    return s
end

---------------------------------------------------------------------------
-- Sélecteur segmenté (onglets en pilules dans un conteneur arrondi).
---------------------------------------------------------------------------
function UI:Segmented(parent, items, onSelect, height)
    height = height or 32
    local f = CreateFrame("Frame", nil, parent)
    UI:Panel(f, height / 2, C.surface, C.border)
    f.buttons = {}
    local x = 3
    for _, it in ipairs(items) do
        local b = UI:Button(f, it[2], nil, height - 6, "ghost")
        b:SetPoint("LEFT", x, 0)
        x = x + b:GetWidth() + 2
        b:SetScript("OnClick", function() f:Select(it[1]); onSelect(it[1]) end)
        f.buttons[it[1]] = b
    end
    f:SetSize(x + 1, height)
    function f:Select(key)
        self.selected = key
        for k, b in pairs(self.buttons) do b:SetStyle(k == key and "primary" or "ghost") end
    end
    return f
end

---------------------------------------------------------------------------
-- Curseur (slider) : valeur appliquée au relâchement.
---------------------------------------------------------------------------
function UI:Slider(parent, width, minV, maxV, step, getter, setter, fmt)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, 20)
    f:EnableMouse(true)
    local track = CreateFrame("Frame", nil, f)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT", -52, 0)
    track:SetHeight(4)
    UI:Rounded(track, 2, 0, "BACKGROUND", 1):SetColor(unpack(C.border))
    local fillF = CreateFrame("Frame", nil, track)
    fillF:SetPoint("TOPLEFT"); fillF:SetPoint("BOTTOMLEFT")
    local fill = UI:Rounded(fillF, 2, 0, "ARTWORK", 1)
    local knob = UI:Icon(f, "circle", 14, { 1, 1, 1, 1 }, "OVERLAY")
    local label = UI:Text(f, 12, C.muted)
    label:SetPoint("RIGHT")
    label:SetJustifyH("RIGHT")

    local value = getter()
    local function render()
        local w = track:GetWidth()
        local p = (value - minV) / (maxV - minV)
        fillF:SetWidth(math.max(4, w * p))
        knob:ClearAllPoints()
        knob:SetPoint("CENTER", track, "LEFT", w * p, 0)
        label:SetText(string.format(fmt or "%.2f", value))
        local r, g, b = UI:Accent()
        fill:SetColor(r, g, b, 1)
    end
    local function fromCursor()
        local x = GetCursorPosition() / f:GetEffectiveScale() - track:GetLeft()
        local p = math.max(0, math.min(1, x / track:GetWidth()))
        local v = minV + p * (maxV - minV)
        value = math.floor(v / step + 0.5) * step
        render()
    end
    f:SetScript("OnMouseDown", function(self)
        self:SetScript("OnUpdate", fromCursor)
        fromCursor()
    end)
    f:SetScript("OnMouseUp", function(self)
        self:SetScript("OnUpdate", nil)
        setter(value)
    end)
    f:SetScript("OnSizeChanged", render)
    f:SetScript("OnShow", function() value = getter(); render() end)
    UI:OnAccent(render)
    return f
end

---------------------------------------------------------------------------
-- Carte : panneau arrondi avec titre optionnel.
---------------------------------------------------------------------------
function UI:Card(parent, title, subtitle, highlight)
    local f = CreateFrame("Frame", nil, parent)
    UI:Panel(f, 12, C.surface, C.border)
    if highlight then UI:TopHighlight(f) end
    if title then
        f.title = UI:Text(f, 13, C.text)
        f.title:SetPoint("TOPLEFT", 16, -14)
        f.title:SetText(title)
        if subtitle then
            f.subtitle = UI:Text(f, 11, C.muted)
            f.subtitle:SetPoint("LEFT", f.title, "RIGHT", 8, 0)
            f.subtitle:SetText(subtitle)
        end
    end
    return f
end

-- Ligne de réglage : libellé + description à gauche, contrôle à droite.
function UI:SettingRow(parent, y, label, desc, control, width)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", 16, y)
    row:SetPoint("TOPRIGHT", -16, y)
    row:SetHeight(desc and 42 or 32)
    local l = UI:Text(row, 12, C.text)
    l:SetPoint("TOPLEFT", 0, desc and -4 or -9)
    l:SetText(label)
    if desc then
        local d = UI:Text(row, 11, C.muted)
        d:SetPoint("TOPLEFT", l, "BOTTOMLEFT", 0, -4)
        d:SetJustifyH("LEFT")
        -- Largeur = ligne moins la commande, recalculée quand la fenêtre change de taille.
        UI:OnResize(row, function(w) d:SetWidth(math.max(100, w - (width or 60) - 8)) end)
        d:SetText(desc)
        row.desc = d
    end
    row.label = l
    -- inscrit pour la recherche de la barre latérale (UI/Search.lua)
    UI.settingIndex = UI.settingIndex or {}
    table.insert(UI.settingIndex, { row = row, label = label, desc = desc })
    if control then
        control:SetParent(row)
        control:ClearAllPoints()
        control:SetPoint("RIGHT", 0, 0)
    end
    return row
end

-- Petit badge en pilule ("connecté", niveaux...).
function UI:Badge(parent, text, color)
    local f = CreateFrame("Frame", nil, parent)
    f.bg = UI:Rounded(f, 9, 0, "BACKGROUND", 1)
    f.text = UI:Text(f, 10)
    f.text:SetPoint("CENTER")
    function f:Set(t, col)
        self.col = col
        self.text:SetText(t)
        self:SetSize(self.text:GetStringWidth() + 16, 18)
        local r, g, b
        if col then r, g, b = col[1], col[2], col[3] else r, g, b = UI:Accent() end
        self.bg:SetColor(r, g, b, 0.18)
        self.text:SetTextColor(r, g, b, 1)
    end
    f:Set(text or "", color)
    UI:OnAccent(function() f:Set(f.text:GetText(), f.col) end)
    return f
end

-- Pool simple de lignes réutilisables.
function UI:Pool(createFn)
    local pool = { items = {}, used = 0 }
    function pool:Reset()
        for _, it in ipairs(self.items) do it:Hide() end
        self.used = 0
    end
    function pool:Get()
        self.used = self.used + 1
        local it = self.items[self.used]
        if not it then
            it = createFn()
            self.items[self.used] = it
        end
        it:Show()
        return it
    end
    return pool
end

-- Liseré doré qui s'estompe sur les bords, en haut d'une carte (style « plaque »).
function UI:TopHighlight(f)
    local l = f:CreateTexture(nil, "BORDER")
    local r = f:CreateTexture(nil, "BORDER")
    l:SetHeight(1); r:SetHeight(1)
    l:SetPoint("TOPLEFT", 14, 0); l:SetPoint("TOPRIGHT", f, "TOP", 0, 0)
    r:SetPoint("TOPLEFT", f, "TOP", 0, 0); r:SetPoint("TOPRIGHT", -14, 0)
    UI:OnAccent(function()
        local cr, cg, cb = UI:Accent()
        UI:SetGradient(l, "HORIZONTAL", { cr, cg, cb, 0 }, { cr, cg, cb, 1 })
        UI:SetGradient(r, "HORIZONTAL", { cr, cg, cb, 1 }, { cr, cg, cb, 0 })
    end)
end

---------------------------------------------------------------------------
-- Courbe (lignes) avec remplissage dégradé optionnel sous la courbe.
-- f.points contient ensuite les positions {x, y} pour le survol.
---------------------------------------------------------------------------
function UI:LineChart(parent, thickness, withFill)
    local f = CreateFrame("Frame", nil, parent)
    f.lines, f.cols, f.dots, f.points = {}, {}, {}, {}
    f.thickness = thickness or 2

    function f:SetData(vals, col, minV, maxV)
        for _, o in ipairs(self.lines) do o:Hide() end
        for _, o in ipairs(self.cols) do o:Hide() end
        for _, o in ipairs(self.dots) do o:Hide() end
        wipe(self.points)
        local n = #vals
        if n == 0 then return end
        local W, H = self:GetWidth(), self:GetHeight()
        if not minV then
            minV, maxV = math.huge, -math.huge
            for _, v in ipairs(vals) do
                if v < minV then minV = v end
                if v > maxV then maxV = v end
            end
        end
        local span = maxV - minV
        for i = 1, n do
            local y = span > 0 and (vals[i] - minV) / span * H or H / 2
            self.points[i] = { x = n == 1 and W / 2 or (i - 1) / (n - 1) * W, y = y, v = vals[i] }
        end
        local r, g, b = col[1], col[2], col[3]

        if withFill and n > 1 then
            local cols = math.max(1, math.floor(W / 4))
            local cw = W / cols
            for c = 1, cols do
                local pos = ((c - 0.5) * cw) / W * (n - 1) + 1
                local i = math.min(n - 1, math.floor(pos))
                local t = pos - i
                local yy = self.points[i].y + (self.points[i + 1].y - self.points[i].y) * t
                local tex = self.cols[c]
                if not tex then
                    tex = self:CreateTexture(nil, "BACKGROUND", nil, 3)
                    self.cols[c] = tex
                end
                tex:ClearAllPoints()
                tex:SetPoint("BOTTOMLEFT", (c - 1) * cw, 0)
                tex:SetSize(cw + 0.5, math.max(1, yy))
                UI:SetGradient(tex, "VERTICAL", { r, g, b, 0 }, { r, g, b, 0.22 })
                tex:Show()
            end
        end

        if self.CreateLine and n > 1 then
            for i = 1, n - 1 do
                local l = self.lines[i]
                if not l then
                    l = self:CreateLine(nil, "ARTWORK")
                    self.lines[i] = l
                end
                local p1, p2 = self.points[i], self.points[i + 1]
                l:SetThickness(self.thickness)
                l:SetColorTexture(r, g, b, 1)
                l:SetStartPoint("BOTTOMLEFT", self, p1.x, p1.y)
                l:SetEndPoint("BOTTOMLEFT", self, p2.x, p2.y)
                l:Show()
            end
        else
            -- Repli sans CreateLine : un point par valeur.
            for i, p in ipairs(self.points) do
                local d = self.dots[i]
                if not d then
                    d = UI:Icon(self, "circle", 4, nil, "ARTWORK")
                    self.dots[i] = d
                end
                d:SetVertexColor(r, g, b, 1)
                d:ClearAllPoints()
                d:SetPoint("CENTER", self, "BOTTOMLEFT", p.x, p.y)
                d:Show()
            end
        end
    end
    return f
end

-- Survol d'une courbe : repère vertical, point et infobulle sur la valeur la plus proche.
-- format(point) renvoie le texte de la 2e ligne ; chaque point doit avoir un champ t (date).
function UI:ChartHover(area, chart, format)
    local marker = area:CreateTexture(nil, "OVERLAY")
    marker:SetWidth(1)
    marker:SetColorTexture(unpack(C.muted))
    local dot = UI:Icon(area, "circle", 9, nil, "OVERLAY")
    marker:Hide(); dot:Hide()
    UI:OnAccent(function() dot:SetVertexColor(UI:Accent()) end)
    area:EnableMouse(true)
    area:SetScript("OnEnter", function(a)
        a:SetScript("OnUpdate", function()
            local pts = chart.points
            if #pts == 0 then return end
            local x = GetCursorPosition() / a:GetEffectiveScale() - a:GetLeft()
            local best, bd = pts[1], math.huge
            for _, pt in ipairs(pts) do
                local d = math.abs(pt.x - x)
                if d < bd then best, bd = pt, d end
            end
            marker:ClearAllPoints()
            marker:SetPoint("BOTTOM", a, "BOTTOMLEFT", best.x, 0)
            marker:SetPoint("TOP", a, "TOPLEFT", best.x, 0)
            dot:ClearAllPoints()
            dot:SetPoint("CENTER", a, "BOTTOMLEFT", best.x, best.y)
            marker:Show(); dot:Show()
            WK.UI:TooltipOwner(a, "ANCHOR_NONE")
            GameTooltip:ClearAllPoints()
            GameTooltip:SetPoint("BOTTOM", a, "BOTTOMLEFT", best.x, best.y + 14)
            GameTooltip:SetText(date("%d/%m %Hh", best.t or time()), 1, 1, 1)
            GameTooltip:AddLine(format(best))
            GameTooltip:Show()
        end)
    end)
    area:SetScript("OnLeave", function(a)
        a:SetScript("OnUpdate", nil)
        marker:Hide(); dot:Hide()
        GameTooltip:Hide()
    end)
end

---------------------------------------------------------------------------
-- Liste déroulante : bouton pilule + liste arrondie qui s'ouvre dessous.
-- options = { {clé, libellé}, ... } ; onSelect(clé).
---------------------------------------------------------------------------
function UI:Dropdown(parent, width, height, options, onSelect)
    height = height or 32
    local d = CreateFrame("Button", nil, parent)
    d:SetSize(width, height)
    UI:Panel(d, height / 2, C.surface, C.border)
    d.label = UI:Text(d, 12)
    d.label:SetPoint("LEFT", 14, 0)
    d.label:SetPoint("RIGHT", -28, 0)
    d.arrow = UI:Icon(d, "chevron", 14, C.muted)
    d.arrow:SetPoint("RIGHT", -12, 0)

    local list = CreateFrame("Frame", nil, d)
    list:SetFrameStrata("DIALOG")
    list:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -4)
    list:SetWidth(width)
    UI:Panel(list, 12, C.surface2, C.border)
    list:Hide()
    d.list = list

    local rowH = 26
    local buttons = {}
    -- (Re)construit les choix : la liste peut changer (ex. persos du compte).
    function d:SetOptions(opts)
        options = opts
        for i, opt in ipairs(options) do
            local b = buttons[i]
            if not b then
                b = CreateFrame("Button", nil, list)
                b:SetHeight(rowH)
                b:SetPoint("TOPLEFT", 4, -4 - (i - 1) * rowH)
                b:SetPoint("TOPRIGHT", -4, -4 - (i - 1) * rowH)
                b.bg = UI:Rounded(b, 9, 0, "BACKGROUND", 2)
                b.bg:SetColor(unpack(C.hover))
                b.bg:Hide()
                b.text = UI:Text(b, 12)
                b.text:SetPoint("LEFT", 10, 0)
                b.text:SetPoint("RIGHT", -10, 0)
                b:SetScript("OnEnter", function(s) s.bg:Show() end)
                b:SetScript("OnLeave", function(s) s.bg:Hide() end)
                b:SetScript("OnClick", function(s)
                    d:Select(s.key)
                    list:Hide()
                    if onSelect then onSelect(s.key) end
                end)
                buttons[i] = b
            end
            b.key = opt[1]
            b.text:SetText(opt[2])
            if opt[3] then b.text:SetTextColor(unpack(opt[3])) else b.text:SetTextColor(unpack(C.text)) end
            b:Show()
        end
        for i = #options + 1, #buttons do buttons[i]:Hide() end
        list:SetHeight(#options * rowH + 8)
        -- Choix courant disparu : retour au premier.
        local found = false
        for _, opt in ipairs(options) do if opt[1] == self.selected then found = true end end
        if self.selected ~= nil and found then self:Select(self.selected)
        elseif options[1] then self:Select(options[1][1]) end
    end

    function d:Select(key)
        self.selected = key
        for _, opt in ipairs(options) do
            if opt[1] == key then
                self.label:SetText(opt[2])
                if opt[3] then self.label:SetTextColor(unpack(opt[3])) else self.label:SetTextColor(unpack(C.text)) end
            end
        end
    end
    d:SetScript("OnClick", function() list:SetShown(not list:IsShown()) end)
    d:SetScript("OnHide", function() list:Hide() end)
    d:SetScript("OnEnter", function(s) s.border:SetColor(UI:Accent()) end)
    d:SetScript("OnLeave", function(s) s.border:SetColor(unpack(C.border)) end)
    d:SetOptions(options)
    return d
end

-- Petit champ numérique (ex. « garder 20 »).
function UI:NumberInput(parent, width, height, placeholder)
    local f = UI:Input(parent, width, height, placeholder)
    f.edit:SetNumeric(true)
    f.edit:SetMaxLetters(5)
    function f:GetNumber() return tonumber(self.edit:GetText()) or 0 end
    return f
end

-- Ouvre le sélecteur de couleur du jeu ; onChange(r, g, b) à chaque modification
-- (et avec la couleur d'origine si le joueur annule).
function UI:PickColor(r, g, b, onChange)
    if not ColorPickerFrame then return end
    local function current() onChange(ColorPickerFrame:GetColorRGB()) end
    local function cancel() onChange(r, g, b) end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b, hasOpacity = false, swatchFunc = current, cancelFunc = cancel,
        })
    else
        ColorPickerFrame.func = current
        ColorPickerFrame.cancelFunc = cancel
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.previousValues = { r, g, b }
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end
end

-- Fenêtre de correction du nom complet d'un perso (« Prénom Nom ») : affichage et courrier.
function UI:EditCharName(key)
    local T = WK.T
    local c = WK.DB.global.characters[key]
    if not c or not StaticPopupDialogs or not StaticPopup_Show then return end
    StaticPopupDialogs.WARBANDKEEPER_MAILNAME = StaticPopupDialogs.WARBANDKEEPER_MAILNAME or {
        button1 = OKAY or "OK", button2 = CANCEL or "Annuler",
        hasEditBox = true, editBoxWidth = 220, timeout = 0, whileDead = true, hideOnEscape = true,
        OnShow = function(s, data)
            local eb = s.editBox or s.EditBox
            if eb then eb:SetText(data.name or ""); eb:HighlightText() end
        end,
        OnAccept = function(s, data)
            local eb = s.editBox or s.EditBox
            WK.modules.Mail:SetMailName(data.key, eb and eb:GetText() or "")
        end,
        EditBoxOnEnterPressed = function(eb, data)
            WK.modules.Mail:SetMailName(data.key, eb:GetText() or "")
            eb:GetParent():Hide()
        end,
    }
    StaticPopupDialogs.WARBANDKEEPER_MAILNAME.text = string.format(
        T("Nom complet de %s pour le courrier (tel que tu le tapes dans « À : ») :"), WK:CharName(c, key))
    StaticPopup_Show("WARBANDKEEPER_MAILNAME", nil, nil, { key = key, name = WK.modules.Mail:MailName(c) })
end

---------------------------------------------------------------------------
-- Infobulles aux couleurs de l'addon. UI:TooltipOwner remplace GameTooltip:SetOwner
-- dans l'addon : le cadre du jeu est masqué le temps de l'infobulle, puis rendu
-- tel quel à sa fermeture (les infobulles du jeu et des autres addons ne changent pas).
---------------------------------------------------------------------------
local ttSkin
local function hideGameFrame(tt)
    if type(tt.NineSlice) == "table" and tt.NineSlice.Hide then tt.NineSlice:Hide() end
    if tt.SetBackdropColor and ttSkin.backdrop then
        tt:SetBackdropColor(0, 0, 0, 0)
        tt:SetBackdropBorderColor(0, 0, 0, 0)
    end
end

function UI:SkinTooltip(tt)
    tt = tt or GameTooltip
    if not ttSkin then
        ttSkin = {
            border = UI:Rounded(tt, 8, 0, "BACKGROUND", -7),
            bg = UI:Rounded(tt, 7, 1, "BACKGROUND", -6),
        }
        ttSkin.accent = tt:CreateTexture(nil, "BACKGROUND", nil, -5)
        ttSkin.accent:SetHeight(2)
        ttSkin.accent:SetPoint("TOPLEFT", tt, "TOPLEFT", 10, -1)
        ttSkin.accent:SetPoint("TOPRIGHT", tt, "TOPRIGHT", -10, -1)
        if tt.GetBackdropColor and tt:GetBackdropColor() then
            ttSkin.backdrop = { { tt:GetBackdropColor() }, { tt:GetBackdropBorderColor() } }
        end
        ttSkin.border:Hide(); ttSkin.bg:Hide(); ttSkin.accent:Hide()
        tt:HookScript("OnHide", function(self) UI:UnskinTooltip(self) end)
        -- Le jeu peut remettre son cadre en remplissant l'infobulle : on le retire à nouveau.
        tt:HookScript("OnShow", function(self) if ttSkin.active then hideGameFrame(self) end end)
    end
    -- Mêmes couleurs que les cadres (cartes) du thème choisi : fond et bordure.
    ttSkin.border:SetColor(unpack(C.border))
    ttSkin.bg:SetColor(C.surface[1], C.surface[2], C.surface[3], 0.98)
    ttSkin.border:Show(); ttSkin.bg:Show(); ttSkin.accent:Hide()
    hideGameFrame(tt)
    ttSkin.active = true
end

function UI:UnskinTooltip(tt)
    if not ttSkin or not ttSkin.active then return end
    tt = tt or GameTooltip
    ttSkin.active = false
    ttSkin.border:Hide(); ttSkin.bg:Hide(); ttSkin.accent:Hide()
    if type(tt.NineSlice) == "table" and tt.NineSlice.Show then tt.NineSlice:Show() end
    if tt.SetBackdropColor and ttSkin.backdrop then
        tt:SetBackdropColor(unpack(ttSkin.backdrop[1]))
        tt:SetBackdropBorderColor(unpack(ttSkin.backdrop[2]))
    end
end

function UI:TooltipOwner(owner, anchor, x, y)
    GameTooltip:SetOwner(owner, anchor, x, y)
    UI:SkinTooltip(GameTooltip)
end
