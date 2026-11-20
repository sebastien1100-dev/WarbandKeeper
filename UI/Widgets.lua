local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors

---------------------------------------------------------------------------
-- Bouton arrondi (pilule). Styles : primary (plein, couleur d'accent = couleur de classe en Graphite),
-- secondary (fond teinté et texte de la couleur d'accent), ghost (discret, teinté au survol), danger.
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
            local r, g, bl = UI:Accent()
            self.bg:SetColor(r, g, bl, 0.14)
            self.bg:SetShown(h)
            fg = { r, g, bl, h and 1 or 0.85 } -- couleur de l'apparence, même au repos
        elseif s == "danger" then
            self.bg:SetColor(C.negative[1], C.negative[2], C.negative[3], h and 0.28 or 0.16)
            self.bg:Show()
            fg = C.negative
        elseif UI.skin == "ink" then
            -- Encre : boutons pleins
            local r, g, bl = UI:Accent()
            self.bg:SetColor(r, g, bl, h and 1 or 0.85)
            self.bg:Show()
            fg = C.onAccent
        else
            local r, g, bl = UI:Accent()
            self.bg:SetColor(r, g, bl, h and 0.30 or 0.16)
            self.bg:Show()
            fg = { math.min(1, r * 1.08 + 0.06), math.min(1, g * 1.08 + 0.06), math.min(1, bl * 1.08 + 0.06), 1 }
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

-- Bouton « Guider » : rond teinté de la couleur d'accent avec la flèche de guidage ; il se remplit
-- au survol. Même icône que la flèche de guidage à l'écran.
function UI:GuideButton(parent, size, tooltip)
    size = size or 28
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    -- vrai rond, quel que soit l'arrondi choisi pour le thème
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetTexture(UI.MEDIA .. "circle")
    function b.bg:SetColor(r, g, bl, a) self:SetVertexColor(r, g, bl, a or 1) end
    b.icon = UI:Icon(b, "guide", math.floor(size * 0.52))
    b.icon:SetPoint("CENTER")
    b.tooltip = tooltip or "Guider jusqu'ici"
    function b:Refresh()
        local r, g, bl = UI:Accent()
        if self.hover then
            self.bg:SetColor(r, g, bl, 1)
            self.icon:SetVertexColor(unpack(C.onAccent))
        else
            self.bg:SetColor(r, g, bl, 0.18)
            self.icon:SetVertexColor(r, g, bl, 1)
        end
    end
    b:SetScript("OnEnter", function(self)
        self.hover = true; self:Refresh()
        WK.UI:TooltipOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(WK.T(self.tooltip), 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self) self.hover = false; self:Refresh(); GameTooltip:Hide() end)
    UI:OnAccent(function() b:Refresh() end)
    b:Refresh()
    return b
end

-- Bouton rond ne contenant qu'une icône (fermer, supprimer...).
function UI:IconButton(parent, icon, size, tooltip, danger)
    size = size or 28
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    -- rond teinté toujours visible : liseré et fond légers à la couleur d'accent (rouge pour danger),
    -- icône pleine couleur ; plus foncé au survol, plein quand le bouton est « ouvert » (SetActive)
    local big = size >= 20
    b.ring = UI:Rounded(b, size / 2, 0, "BACKGROUND", 0)
    b.bg = UI:Rounded(b, size / 2, big and 1 or 0, "BACKGROUND", 1)
    b.icon = UI:Icon(b, icon, math.floor(size * 0.55))
    b.icon:SetPoint("CENTER")
    b.tooltip = tooltip
    local function refresh(h)
        local r, g, bl
        if danger == true then r, g, bl = C.negative[1], C.negative[2], C.negative[3] else r, g, bl = UI:Accent() end
        if b.active then
            b.ring:SetColor(r, g, bl, 1); b.bg:SetColor(r, g, bl, 1)
            b.icon:SetVertexColor(unpack(C.onAccent))
        else
            b.ring:SetColor(r, g, bl, big and (h and 0.75 or 0.45) or 0)
            -- fond : mélange de l'accent et de la surface (opaque, pour garder le liseré fin)
            local s = C.surface
            local k = h and 0.32 or 0.16
            b.bg:SetColor(s[1] + (r - s[1]) * k, s[2] + (g - s[2]) * k, s[3] + (bl - s[3]) * k, 1)
            b.icon:SetVertexColor(r, g, bl, 1)
        end
        b.ring:SetShown(big or b.active)
        b.bg:Show()
    end
    b.Paint = refresh
    function b:SetActive(on) self.active = on and true or false; refresh(self.hover) end
    refresh(false)
    b:SetScript("OnEnter", function(self)
        self.hover = true
        refresh(true)
        if self.tooltip then
            WK.UI:TooltipOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(WK.T(self.tooltip), 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self) self.hover = false; refresh(false); GameTooltip:Hide() end)
    UI:OnAccent(function() refresh(b.hover) end)
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
        -- dégradé d'accent (Options > Apparence) : 2e couleur sur les jauges à la couleur de l'accent
        local r2, g2, b2 = (not self.color) and UI:Accent2()
        -- Cuir et or : jauges en dégradé doré (accent vers accent assombri)
        if not r2 and not self.color and UI.skin == "leather" then
            local r, g, b = UI:Accent(); r2, g2, b2 = r * 0.62, g * 0.62, b * 0.62
        end
        if r2 then
            if not self.grad then
                self.grad = self.fillFrame:CreateTexture(nil, "ARTWORK", nil, 2)
                self.grad:SetAllPoints(self.fillFrame)
            end
            local r, g, b = UI:Accent()
            UI:SetGradient(self.grad, "HORIZONTAL", { r, g, b, 1 }, { r2, g2, b2, 1 })
            self.grad:Show(); self.fill:Hide()
        else
            if self.grad then self.grad:Hide() end
            self.fill:Show()
            if self.color then self.fill:SetColor(unpack(self.color))
            else local r, g, b = UI:Accent(); self.fill:SetColor(r, g, b, 1) end
        end
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
    -- style des cartes (Options > Apparence) : liseré (défaut), plat (sans bordure), halo (lueur en haut)
    UI:Panel(f, 12, C.surface, UI.cardStyle == "flat" and C.surface or C.border)
    if highlight or UI.cardStyle == "halo" then UI:TopHighlight(f) end
    local skin = UI.skin
    if skin == "ink" then
        -- Encre : ni fond ni bordure, un trait d'accent à gauche
        f.bg:Hide(); if f.border then f.border:Hide() end
        f.skinBar = f:CreateTexture(nil, "BORDER")
        f.skinBar:SetWidth(3); f.skinBar:SetPoint("TOPLEFT", 0, -4); f.skinBar:SetPoint("BOTTOMLEFT", 0, 4)
        UI:OnAccent(function() f.skinBar:SetColorTexture(UI:Accent()) end)
    elseif skin == "leather" then
        -- Cuir et or : double liseré
        f.inner = UI:Rounded(f, 9, 4, "BACKGROUND", 2)
        f.inner:SetColor(C.border[1], C.border[2], C.border[3], 0.55)
        f.inner2 = UI:Rounded(f, 8, 5, "BACKGROUND", 3)
        f.inner2:SetColor(unpack(C.surface))
    end
    if title then
        local host = f
        if skin == "heraldic" then
            -- Héraldique : titre blanc sur un bandeau de couleur (coins du haut arrondis, bas droit)
            f.band = CreateFrame("Frame", nil, f)
            f.band:SetPoint("TOPLEFT", 1, -1); f.band:SetPoint("TOPRIGHT", -1, -1); f.band:SetHeight(36)
            if f.band.SetClipsChildren then f.band:SetClipsChildren(true) end
            local holder = CreateFrame("Frame", nil, f.band)
            holder:SetPoint("TOPLEFT"); holder:SetPoint("TOPRIGHT"); holder:SetHeight(60)
            local fill = UI:Rounded(holder, 11, 0, "BACKGROUND", 1)
            UI:OnAccent(function() local r, g, b = UI:Accent(); fill:SetColor(r * 0.55, g * 0.55, b * 0.55, 1) end)
            host = f.band
        end
        f.title = UI:Text(host, skin == "ink" and 17 or 13, C.text)
        if UI.CARD_TITLE_FONT then f.title:SetFont(UI.CARD_TITLE_FONT, math.floor((skin == "ink" and 17 or 14) * (UI.textScale or 1) + 0.5), "") end
        if skin == "heraldic" then f.title:SetTextColor(1, 1, 1) end
        if skin == "leather" then
            f.title:SetPoint("TOP", 0, -13)
            UI:OnAccent(function() f.title:SetTextColor(UI:Accent()) end)
            local fil = f:CreateTexture(nil, "ARTWORK")
            fil:SetHeight(1); fil:SetPoint("TOPLEFT", 40, -32); fil:SetPoint("TOPRIGHT", f, "TOP", 0, -32)
            UI:OnAccent(function()
                local r, g, b = UI:Accent()
                UI:SetGradient(fil, "HORIZONTAL", { r, g, b, 0 }, { r, g, b, 0.9 })
            end)
            local fil2 = f:CreateTexture(nil, "ARTWORK")
            fil2:SetHeight(1); fil2:SetPoint("TOPLEFT", f, "TOP", 0, -32); fil2:SetPoint("TOPRIGHT", -40, -32)
            UI:OnAccent(function()
                local r, g, b = UI:Accent()
                UI:SetGradient(fil2, "HORIZONTAL", { r, g, b, 0.9 }, { r, g, b, 0 })
            end)
        else
            f.title:SetPoint("TOPLEFT", 16, skin == "ink" and -12 or -14)
        end
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
        -- (place de la commande : au moins sa vraie largeur, la largeur annoncée peut être plus petite)
        UI:OnResize(row, function(w)
            local cw = math.max(width or 60, control and control.GetWidth and control:GetWidth() or 0)
            d:SetWidth(math.max(100, w - cw - 8))
        end)
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
        a.hoverPt = nil
        a:SetScript("OnUpdate", function()
            local pts = chart.points
            if #pts == 0 then return end
            local x = GetCursorPosition() / a:GetEffectiveScale() - a:GetLeft()
            local best, bd = pts[1], math.huge
            for _, pt in ipairs(pts) do
                local d = math.abs(pt.x - x)
                if d < bd then best, bd = pt, d end
            end
            -- rien à refaire tant que le point le plus proche ne change pas
            if a.hoverPt == best then return end
            a.hoverPt = best
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
        a.hoverPt = nil
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
-- Infobulles aux couleurs de l'addon : fond et bordure des cartes, police de l'interface.
-- UI:TooltipOwner (dans l'addon) les habille toujours ; les infobulles du jeu (objets, PNJ, sorts, liens du
-- chat, comparaisons) aussi quand le réglage settings.ui.gameTooltipFont est actif (par défaut). Le cadre du
-- jeu est masqué le temps de l'infobulle et rendu à sa fermeture. Un habillage par infobulle (skins[tt]).
---------------------------------------------------------------------------
local skins = {} -- [infobulle] = { border, bg, accent, backdrop, active, reshow }
local function hideGameFrame(tt)
    local sk = skins[tt]
    if type(tt.NineSlice) == "table" and tt.NineSlice.Hide then tt.NineSlice:Hide() end
    if tt.SetBackdropColor and sk and sk.backdrop then
        tt:SetBackdropColor(0, 0, 0, 0)
        tt:SetBackdropBorderColor(0, 0, 0, 0)
    end
end

-- Police des infobulles : celle de l'interface (Options > Apparence), sans contour,
-- 13 pour le titre et 12 pour le reste. Les polices d'origine sont rendues à la fermeture.
local ttFonts = {} -- [FontString] = { police, taille, contour, infobulle } d'origine
local function applyTooltipFonts(tt)
    local name = tt.GetName and tt:GetName()
    if not name or not tt.NumLines then return false end
    local changed = false
    for i = 1, tt:NumLines() do
        for _, side in ipairs({ "Left", "Right" }) do
            local fs = _G[name .. "Text" .. side .. i]
            if fs and fs.GetFont then
                local f, sz, fl = fs:GetFont()
                local want = i == 1 and 13 or 12
                if f ~= UI.FONT or math.floor((sz or 0) + 0.5) ~= want or (fl or "") ~= "" then
                    if not ttFonts[fs] then ttFonts[fs] = { f, sz, fl, tt } end
                    fs:SetFont(UI.FONT, want, "")
                    changed = true
                end
            end
        end
    end
    return changed
end
local function restoreTooltipFonts(tt)
    for fs, o in pairs(ttFonts) do
        if o[4] == tt then
            if o[1] then pcall(fs.SetFont, fs, o[1], o[2], o[3] or "") end
            ttFonts[fs] = nil
        end
    end
end

-- Infobulles du jeu (objets, PNJ, sorts…) : même police fine, par les polices partagées du jeu.
-- Réglage settings.ui.gameTooltipFont (activé par défaut) ; coupé : polices d'origine rendues.
local GAME_TT_FONTS = { { "GameTooltipHeaderText", 13 }, { "GameTooltipText", 12 }, { "GameTooltipTextSmall", 11 } }
local gameTTOrig
function UI:ApplyGameTooltipFonts()
    local on = WK.DB.global.settings.ui.gameTooltipFont ~= false
    if not gameTTOrig then
        if not on then return end
        gameTTOrig = {}
        for _, f in ipairs(GAME_TT_FONTS) do
            local o = _G[f[1]]
            if o and o.GetFont then gameTTOrig[f[1]] = { o:GetFont() } end
        end
    end
    for _, f in ipairs(GAME_TT_FONTS) do
        local o, orig = _G[f[1]], gameTTOrig[f[1]]
        if o and o.SetFont and orig then
            if on then pcall(o.SetFont, o, UI.FONT, f[2], "") else pcall(o.SetFont, o, orig[1], orig[2], orig[3] or "") end
        end
    end
end
WK:On("PLAYER_LOGIN", function() UI:ApplyGameTooltipFonts() end)

function UI:SkinTooltip(tt)
    tt = tt or GameTooltip
    local sk = skins[tt]
    if not sk then
        sk = {
            border = UI:Rounded(tt, 8, 0, "BACKGROUND", -7),
            bg = UI:Rounded(tt, 7, 1, "BACKGROUND", -6),
        }
        skins[tt] = sk
        sk.accent = tt:CreateTexture(nil, "BACKGROUND", nil, -5)
        sk.accent:SetHeight(2)
        sk.accent:SetPoint("TOPLEFT", tt, "TOPLEFT", 10, -1)
        sk.accent:SetPoint("TOPRIGHT", tt, "TOPRIGHT", -10, -1)
        if tt.GetBackdropColor and tt:GetBackdropColor() then
            sk.backdrop = { { tt:GetBackdropColor() }, { tt:GetBackdropBorderColor() } }
        end
        sk.border:Hide(); sk.bg:Hide(); sk.accent:Hide()
        tt:HookScript("OnHide", function(self) UI:UnskinTooltip(self) end)
        -- Le jeu peut remettre son cadre en remplissant l'infobulle : on le retire à nouveau.
        tt:HookScript("OnShow", function(self) if sk.active then hideGameFrame(self) end end)
        -- à chaque Show (lignes ajoutées) : police de l'addon, puis taille recalculée
        if hooksecurefunc then
            hooksecurefunc(tt, "Show", function(self)
                if not sk.active or sk.reshow then return end
                if applyTooltipFonts(self) then
                    sk.reshow = true
                    self:Show()
                    sk.reshow = nil
                end
            end)
        end
    end
    -- Mêmes couleurs que les cadres (cartes) du thème choisi : fond et bordure.
    sk.border:SetColor(unpack(C.border))
    sk.bg:SetColor(C.surface[1], C.surface[2], C.surface[3], 0.98 * (WK.DB.global.settings.ui.tipOpacity or 1))
    sk.border:Show(); sk.bg:Show(); sk.accent:Hide()
    hideGameFrame(tt)
    sk.active = true
    -- habillée après coup (déjà affichée) : polices et taille tout de suite
    if tt:IsShown() and not sk.reshow and applyTooltipFonts(tt) then
        sk.reshow = true
        tt:Show()
        sk.reshow = nil
    end
end

function UI:UnskinTooltip(tt)
    tt = tt or GameTooltip
    local sk = skins[tt]
    if not sk or not sk.active then return end
    sk.active = false
    restoreTooltipFonts(tt)
    sk.border:Hide(); sk.bg:Hide(); sk.accent:Hide()
    if type(tt.NineSlice) == "table" and tt.NineSlice.Show then tt.NineSlice:Show() end
    if tt.SetBackdropColor and sk.backdrop then
        tt:SetBackdropColor(unpack(sk.backdrop[1]))
        tt:SetBackdropBorderColor(unpack(sk.backdrop[2]))
    end
end

-- Infobulles du jeu au style de l'addon (réglage settings.ui.gameTooltipFont) : habillées à chaque affichage.
local GAME_TOOLTIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2",
    "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2", "EmbeddedItemTooltip" }
WK:On("PLAYER_LOGIN", function()
    local list, seen = {}, {}
    for _, name in ipairs(GAME_TOOLTIPS) do local tt = _G[name]; if tt then seen[tt] = true; table.insert(list, tt) end end
    for _, base in ipairs({ GameTooltip, ItemRefTooltip }) do
        for _, st in ipairs(base and base.shoppingTooltips or {}) do if not seen[st] then seen[st] = true; table.insert(list, st) end end
    end
    for _, tt in ipairs(list) do
        if tt and tt.HookScript then
            tt:HookScript("OnShow", function(self)
                if WK.DB.global.settings.ui.gameTooltipFont == false then return end
                local sk = skins[self]
                if not (sk and sk.active) then UI:SkinTooltip(self) end
            end)
        end
    end
end)

-- Nos infobulles d'objet n'ouvrent pas la comparaison du jeu à côté (deux infobulles qui se chevauchent) ;
-- Maj enfoncée la montre quand même.
-- Infobulles de comparaison : celles du jeu (GameTooltip.shoppingTooltips) et les noms connus.
local function compareTooltips(tt)
    local out, seen = {}, {}
    for _, st in ipairs((tt and tt.shoppingTooltips) or {}) do if not seen[st] then seen[st] = true; table.insert(out, st) end end
    for _, name in ipairs({ "ShoppingTooltip1", "ShoppingTooltip2", "ShoppingTooltip3" }) do
        local st = _G[name]
        if st and not seen[st] then seen[st] = true; table.insert(out, st) end
    end
    return out
end
UI.CompareTooltips = compareTooltips
local function noCompare() return GameTooltip.wkOwned and not (IsShiftKeyDown and IsShiftKeyDown()) end
local compareHooked
local function hookCompare()
    if compareHooked then return end
    compareHooked = true
    GameTooltip:HookScript("OnHide", function(t)
        t.wkOwned = nil
        if t.wkCompare ~= nil then t.supportsItemComparison = t.wkCompare; t.wkCompare = nil end
    end)
    for _, st in ipairs(compareTooltips(GameTooltip)) do
        if st.HookScript then
            st:HookScript("OnShow", function(s) if noCompare() then s:Hide() end end)
        end
    end
    -- le jeu (re)montre la comparaison après coup : on la referme aussitôt
    if hooksecurefunc and GameTooltip_ShowCompareItem then
        hooksecurefunc("GameTooltip_ShowCompareItem", function(tt)
            if tt == GameTooltip and noCompare() then
                for _, st in ipairs(compareTooltips(tt)) do st:Hide() end
            end
        end)
    end
end
function UI:TooltipOwner(owner, anchor, x, y)
    hookCompare()
    GameTooltip:SetOwner(owner, anchor, x, y)
    GameTooltip.wkOwned = true
    -- pas de comparaison sur nos infobulles (Maj enfoncée : comme le jeu)
    if GameTooltip.supportsItemComparison ~= nil and GameTooltip.wkCompare == nil then
        GameTooltip.wkCompare = GameTooltip.supportsItemComparison
        GameTooltip.supportsItemComparison = (IsShiftKeyDown and IsShiftKeyDown()) and true or false
    end
    UI:SkinTooltip(GameTooltip)
end

-- Ligne (tuile) entièrement cliquable : au survol, bordure et fond à la couleur de l'apparence.
-- border / bg : fonds arrondis de la ligne (UI:Rounded) ; base() rend la couleur de fond au repos.
-- Les enfants qui prennent la souris (boutons) gardent le survol : il ne tombe que hors de la ligne.
function UI:HoverRow(r, border, bg, base, onClick)
    r:EnableMouse(true)
    local function paint(s)
        local on = s:IsMouseOver()
        local ar, ag, ab = UI:Accent()
        if on then
            border:SetColor(ar, ag, ab, 1)
            local b0 = base and base(s) or C.surface
            bg:SetColor(b0[1] * 0.82 + ar * 0.18, b0[2] * 0.82 + ag * 0.18, b0[3] * 0.82 + ab * 0.18, 1)
        else
            border:SetColor(unpack(C.border))
            bg:SetColor(unpack(base and base(s) or C.surface))
        end
    end
    r.PaintHover = paint
    r:HookScript("OnEnter", paint)
    r:HookScript("OnLeave", function(s) C_Timer.After(0, function() paint(s) end) end)
    if onClick then
        r:SetScript("OnMouseUp", function(s, button) onClick(s, button) end)
    end
    -- enfants : leur sortie peut être la sortie de la ligne
    function r:HoverChild(ch)
        ch:HookScript("OnEnter", function() paint(r) end)
        ch:HookScript("OnLeave", function() C_Timer.After(0, function() paint(r) end) end)
    end
end

---------------------------------------------------------------------------
-- Roue dentée de réglages d'une page : un volet posé par-dessus le contenu (sous la barre du haut),
-- qui reprend des cartes de réglages construites ailleurs (QoL, Options : un seul endroit par réglage).
--   opts.top     : décalage du volet depuis le haut de la page (barre d'onglets au-dessus)
--   opts.cards   : function() renvoie la liste des cartes à reprendre (appelée à chaque ouverture)
--   opts.columns : 1 ou 2 (2 par défaut) ; opts.title : infobulle de la roue
--   opts.onToggle(open) : la page cache ou montre ce qui doit l'être
-- Renvoie gp : gp.gear (à placer), gp:Open(on), gp:IsOpen(), gp:Refresh().
---------------------------------------------------------------------------
function UI:PageGear(p, opts, def)
    local gp = { open = false }
    local gear = UI:IconButton(p, opts.icon or "gear", opts.size or 32, opts.title or "Réglages")
    gp.gear = gear
    local ov = CreateFrame("Frame", nil, p)
    ov:SetPoint("TOPLEFT", 0, -(opts.top or 42))
    ov:SetPoint("BOTTOMRIGHT")
    ov:SetFrameLevel((p:GetFrameLevel() or 1) + 40)
    ov:EnableMouse(true)
    ov.bg = ov:CreateTexture(nil, "BACKGROUND")
    ov.bg:SetAllPoints()
    ov.bg:SetColorTexture(C.bg[1], C.bg[2], C.bg[3], 1)
    ov:Hide()
    local sc = UI:Scroll(ov)
    sc:SetAllPoints()
    gp.overlay, gp.scroll = ov, sc
    local GAPV = 12
    function gp:Layout()
        local list = self.list or {}
        local W = math.max(400, (sc:GetWidth() or 800) - 12)
        sc.child:SetWidth(W)
        local cols = (opts.columns == 1 or W < 760) and 1 or 2
        local cw = cols == 1 and W or math.floor((W - GAPV) / 2)
        local colY = { 0, 0 }
        for _, c in ipairs(list) do
            local col = (cols == 2 and colY[2] < colY[1]) and 2 or 1
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", (col - 1) * (cw + GAPV), -colY[col])
            c:SetWidth(cw)
            colY[col] = colY[col] + (c:GetHeight() or 100) + GAPV
        end
        sc:SetContentHeight(math.max(colY[1], colY[2]))
    end
    UI:OnResize(sc, function() if ov:IsShown() then gp:Layout() end end)
    -- interrupteurs et textes des cartes reprises : tenus par leurs pages d'origine
    local function refreshOwners()
        for _, key in ipairs({ "qol", "options" }) do
            local d = UI.pages and UI.pages[key]
            if d and d.frame then
                for _, t in ipairs(d.toggles or {}) do if t:IsVisible() then t:Refresh() end end
                for _, fn in ipairs(d.dyn or {}) do pcall(fn) end
                if key == "options" and d.Refresh then pcall(d.Refresh, d) end
            end
        end
    end
    -- reprise des cartes : dès la construction (la recherche les trouve ici), puis à chaque ouverture
    function gp:Adopt()
        local list = opts.cards and opts.cards() or {}
        for _, c in ipairs(list) do
            if c:GetParent() ~= sc.child then c:SetParent(sc.child) end
            c:Show()
        end
        self.list = list
    end
    function gp:Refresh()
        if not self.open then return end
        self:Adopt()
        refreshOwners() -- avant la mise en page : une carte peut changer de hauteur
        self:Layout()
    end
    -- opts.seeThrough : fond du volet transparent (le halo de la fenêtre reste visible, pas de bande plus
    -- sombre) ; ce qui est dessous dans la zone du volet est caché pendant qu'il est ouvert, puis rendu
    local hidden = {}
    local function coverUnder(open)
        if not opts.seeThrough then return end
        if open then
            local left = ov:GetLeft() or 0
            -- rendu invisible (alpha) plutôt que caché : un rafraîchissement de la page qui le remontre
            -- ne le fait pas réapparaître sous le volet ; les clics vont au volet, posé au-dessus
            local function take(x)
                if x ~= ov and x ~= gear and (x:GetLeft() or left) >= left - 1 then
                    table.insert(hidden, { x, x:GetAlpha() }); x:SetAlpha(0)
                end
            end
            for _, c in ipairs({ p:GetChildren() }) do take(c) end
            for _, r in ipairs({ p:GetRegions() }) do take(r) end
        else
            for _, e in ipairs(hidden) do e[1]:SetAlpha(e[2] or 1) end
            wipe(hidden)
        end
    end
    if opts.seeThrough then ov.bg:SetColorTexture(0, 0, 0, 0) end
    function gp:Open(on)
        local was = self.open
        self.open = on and true or false
        if self.open ~= was then coverUnder(self.open) end
        ov:SetShown(self.open)
        gear:SetActive(self.open)
        if opts.onToggle then opts.onToggle(self.open) end
        if self.open then self:Refresh() end
    end
    function gp:IsOpen() return self.open end
    gear:SetScript("OnClick", function() gp:Open(not gp.open) end)
    gp:Adopt()
    -- recherche de la barre latérale : un réglage du volet ouvre le volet
    if def then
        local prev = def.RevealSetting
        def.RevealSetting = function(d, row)
            local f = row
            while f do
                if f == sc.child then gp:Open(true) return end
                f = f:GetParent()
            end
            if prev then prev(d, row) end
        end
    end
    return gp
end

-- Cartes d'une section de la page QoL ou Options (construite au besoin), filtrées par titre.
-- titles = nil : toutes ; sinon { ["Titre"] = true }.
function UI:SectionCards(pageKey, sectionKey, titles)
    local def = UI:EnsurePage(pageKey)
    local sec = def and def.sections and def.sections[sectionKey]
    local out = {}
    for _, c in ipairs(sec and sec.cards or {}) do
        local t = c.title and c.title:GetText()
        if not titles or (t and (titles[t] or titles[WK.T(t)])) or (c.cardKey and titles[c.cardKey]) then table.insert(out, c) end
    end
    return out
end

---------------------------------------------------------------------------
-- Alertes d'un perso en petites icônes (lignes de Persos et du Résumé) : sac (sacs), coffre (banque),
-- marteau (réparation), étincelle (composants, munitions), étoile (familier) ; rond rouge si plein ou
-- urgent, orange si presque. Survol : le détail. icons:Set(clé du perso) ; renvoie la largeur prise.
---------------------------------------------------------------------------
local ALERT_ICON = { durability = "hammer", reagent = "spark", ammo = "spark", poison = "spark", pet = "star" }
function UI:CharAlertIcons(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(1, 20)
    f.icons = {}
    for i = 1, 4 do
        local b = CreateFrame("Frame", nil, f)
        b:SetSize(20, 20)
        b.ring = UI:Rounded(b, 10, 0, "BACKGROUND", 0)
        b.bg = UI:Rounded(b, 10, 1, "BACKGROUND", 1)
        b.ic = UI:Icon(b, "bag", 12, nil, "ARTWORK"); b.ic:SetPoint("CENTER")
        b:SetPoint("LEFT", (i - 1) * 23, 0)
        b:EnableMouse(true)
        b:SetScript("OnEnter", function(s)
            WK.UI:TooltipOwner(s, "ANCHOR_TOP")
            GameTooltip:SetText(s.title or "", 1, 1, 1)
            for _, a in ipairs(s.list or {}) do
                local col = a.red and C.negative or C.warning
                GameTooltip:AddLine(a.text, col[1], col[2], col[3], true)
            end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:Hide()
        f.icons[i] = b
    end
    function f:Set(key)
        local Q = WK.modules.QoL
        local c = WK.DB.global.characters[key]
        local groups, order = {}, {}
        for _, a in ipairs(Q and Q:Alerts() or {}) do
            if a.key == key then
                local ic = (a.kind == "bags" and a.bank) and "safe" or (a.kind == "bags" and "bag") or ALERT_ICON[a.kind] or "bang"
                local red = a.urgent or (a.kind == "bags" and a.bank and c and c.bankFree == 0) or false
                local g = groups[ic]
                if not g then g = { icon = ic, list = {}, red = false }; groups[ic] = g; table.insert(order, g) end
                table.insert(g.list, { text = a.text, red = red })
                if red then g.red = true end
            end
        end
        for i, b in ipairs(self.icons) do
            local g = order[i]
            b:SetShown(g ~= nil)
            if g then
                local col = g.red and C.negative or C.warning
                b.ic:SetTexture(UI.MEDIA .. g.icon)
                b.ic:SetVertexColor(col[1], col[2], col[3], 1)
                b.ring:SetColor(col[1], col[2], col[3], 0.9)
                local s = C.surface
                b.bg:SetColor(s[1] + (col[1] - s[1]) * 0.22, s[2] + (col[2] - s[2]) * 0.22, s[3] + (col[3] - s[3]) * 0.22, 1)
                b.title = c and WK:CharName(c, key) or ""
                b.list = g.list
            end
        end
        local n = math.min(#order, #self.icons)
        self:SetWidth(math.max(1, n * 23))
        self:SetShown(n > 0)
        return n > 0 and n * 23 or 0
    end
    return f
end

---------------------------------------------------------------------------
-- Bandeau de chiffres clés (pages Quêtes et Rares) : n cartes côte à côte, la première plus large.
-- k:Set(i, { label, value, sub, color, frac?, onClick? })
---------------------------------------------------------------------------
function UI:KpiRow(parent, n, height)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(height or 74)
    row.cards = {}
    for i = 1, n do
        local c = CreateFrame("Button", nil, row)
        UI:Panel(c, 10, C.surface, C.border)
        c.tint = c:CreateTexture(nil, "BORDER")
        c.tint:SetPoint("TOPLEFT", 4, -4); c.tint:SetPoint("BOTTOMRIGHT", -4, 4)
        c.l = UI:Text(c, 10, C.muted); c.l:SetPoint("TOPLEFT", 12, -10); c.l:SetPoint("RIGHT", -10, 0)
        c.v = UI:Text(c, 20, C.text); c.v:SetPoint("TOPLEFT", c.l, "BOTTOMLEFT", 0, -4); c.v:SetPoint("RIGHT", -10, 0)
        c.s = UI:Text(c, 10, C.muted); c.s:SetPoint("BOTTOMLEFT", 12, 9); c.s:SetPoint("RIGHT", -10, 0)
        c.barBg = c:CreateTexture(nil, "ARTWORK"); c.barBg:SetHeight(4)
        c.barBg:SetPoint("BOTTOMLEFT", 12, 25); c.barBg:SetPoint("BOTTOMRIGHT", -12, 25)
        c.barBg:SetColorTexture(1, 1, 1, 0.08)
        c.bar = c:CreateTexture(nil, "OVERLAY"); c.bar:SetHeight(4); c.bar:SetPoint("TOPLEFT", c.barBg, "TOPLEFT")
        c:SetScript("OnClick", function(s) if s.onClick then s.onClick() end end)
        c:SetScript("OnEnter", function(s)
            if not s.tip then return end
            UI:TooltipOwner(s, "ANCHOR_BOTTOM")
            GameTooltip:SetText(s.tip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        c:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.cards[i] = c
    end
    local function place()
        local w = row:GetWidth() or 800
        if w < 100 then w = 800 end
        local gap = 10
        local unit = (w - gap * (n - 1)) / (n + 0.6) -- la première carte compte pour 1,6
        local x = 0
        for i, c in ipairs(row.cards) do
            local cw = i == 1 and unit * 1.6 or unit
            c:ClearAllPoints(); c:SetPoint("TOPLEFT", x, 0); c:SetSize(cw, row:GetHeight())
            x = x + cw + gap
        end
    end
    UI:OnResize(row, function() place() end)
    function row:Set(i, e)
        local c = self.cards[i]
        if not c then return end
        place()
        local col = e.color or C.text
        c.l:SetText(e.label or "")
        c.v:SetText(e.value or "")
        c.v:SetTextColor(col[1], col[2], col[3], 1)
        c.s:SetText(e.sub or "")
        c.onClick, c.tip = e.onClick, e.tip
        c.barBg:SetShown(e.frac ~= nil); c.bar:SetShown(e.frac ~= nil and e.frac > 0)
        if e.frac then
            c.bar:SetWidth(math.max(1, ((c:GetWidth() or 200) - 24) * math.min(1, e.frac)))
            c.bar:SetColorTexture(col[1], col[2], col[3], 1)
        end
        c.tint:SetColorTexture(1, 1, 1, 1)
        local ok = i == 1 and c.tint.SetGradient and CreateColor and pcall(c.tint.SetGradient, c.tint, "HORIZONTAL",
            CreateColor(col[1], col[2], col[3], 0.14), CreateColor(col[1], col[2], col[3], 0))
        if not ok then c.tint:SetColorTexture(col[1], col[2], col[3], i == 1 and 0.06 or 0) end
    end
    return row
end

---------------------------------------------------------------------------
-- Carte d'un continent (pages Quêtes et Rares) : la carte du jeu (tuiles C_Map) en fond, assombrie,
-- une bulle par zone (taille et couleur = avancement), ta zone en pointillés, la zone choisie cerclée,
-- onglets des continents. m:SetData(zones, opts) ; zones = { { map, name, frac, total, done } } ;
-- opts = { selected, player, best, color = fn(z), onClick = fn(map), tip = fn(z) }.
---------------------------------------------------------------------------
local mapRects, contOf = {}, {}
local function continentOf(mapID)
    if contOf[mapID] then return contOf[mapID] end
    local id, guard = mapID, 0
    while id and guard < 8 do
        local ok, i = pcall(C_Map.GetMapInfo, id)
        if not (ok and i) then break end
        if i.mapType == 2 then contOf[mapID] = id; return id, i.name end
        id, guard = i.parentMapID, guard + 1
    end
    return nil
end
local function rectOn(mapID, cont)
    local k = mapID .. ":" .. cont
    if mapRects[k] ~= nil then return mapRects[k] or nil end
    local r = false
    if C_Map.GetMapRectOnMap then
        local ok, x0, x1, y0, y1 = pcall(C_Map.GetMapRectOnMap, mapID, cont)
        if ok and x0 and x1 and y0 and y1 and x1 > x0 and y1 > y0 then r = { x0, x1, y0, y1 } end
    end
    if r then mapRects[k] = r end
    return r or nil
end

function UI:ZoneMap(parent)
    local m = CreateFrame("Frame", nil, parent)
    UI:Panel(m, 10, C.surface, C.border)
    m.area = CreateFrame("Frame", nil, m)
    m.area:SetPoint("TOPLEFT", 8, -42); m.area:SetPoint("BOTTOMRIGHT", -8, 24)
    if m.area.SetClipsChildren then m.area:SetClipsChildren(true) end
    m.areaBg = m.area:CreateTexture(nil, "BACKGROUND"); m.areaBg:SetAllPoints(); m.areaBg:SetColorTexture(0, 0, 0, 0.3)
    m.tiles = {}
    m.shade = m.area:CreateTexture(nil, "BORDER"); m.shade:SetColorTexture(0, 0, 0, 0.45)
    m.pins = CreateFrame("Frame", nil, m.area); m.pins:SetAllPoints(); m.pins:SetFrameLevel(m.area:GetFrameLevel() + 5)
    m.bubbles, m.labels = {}, {}
    m.legend = UI:Text(m, 10, C.dim); m.legend:SetPoint("BOTTOMLEFT", 12, 7)
    m.empty = UI:Text(m.area, 11, C.dim); m.empty:SetPoint("CENTER")
    m.tabsHolder = CreateFrame("Frame", nil, m); m.tabsHolder:SetPoint("TOPLEFT", 8, -8); m.tabsHolder:SetSize(10, 26)

    local function bubble(i)
        local b = m.bubbles[i]
        if b then return b end
        b = CreateFrame("Button", nil, m.pins)
        b.dot = b:CreateTexture(nil, "ARTWORK"); b.dot:SetAllPoints(); b.dot:SetTexture(UI.MEDIA .. "circle")
        b.edge = b:CreateTexture(nil, "BACKGROUND"); b.edge:SetPoint("CENTER"); b.edge:SetTexture(UI.MEDIA .. "circle")
        b.edge:SetVertexColor(0, 0, 0, 0.8)
        b.ring = b:CreateTexture(nil, "OVERLAY"); b.ring:SetPoint("CENTER")
        b:SetScript("OnClick", function(s) if m.opts.onClick then m.opts.onClick(s.z.map) end end)
        b:SetScript("OnEnter", function(s)
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetText(s.z.name, 1, 1, 1)
            if m.opts.tip then m.opts.tip(s.z, GameTooltip) end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        m.bubbles[i] = b
        return b
    end
    local function label(i)
        local l = m.labels[i]
        if not l then l = UI:Text(m.pins, 9, C.text); l:SetJustifyH("CENTER"); m.labels[i] = l end
        return l
    end

    -- fond : tuiles du continent posées dans le rectangle (x, y, w, h) de la zone d'affichage
    local function paintArt(cont, x, y, w, h)
        for _, t in ipairs(m.tiles) do t:Hide() end
        local okL, layers = pcall(C_Map.GetMapArtLayers, cont)
        local L = okL and layers and layers[1]
        local okT, files = pcall(C_Map.GetMapArtLayerTextures, cont, 1)
        if not (L and okT and files) then return end
        local tw, th = L.tileWidth or 256, L.tileHeight or 256
        local lw, lh = L.layerWidth or tw, L.layerHeight or th
        local cols = math.ceil(lw / tw)
        for idx, file in ipairs(files) do
            local col, row = (idx - 1) % cols, math.floor((idx - 1) / cols)
            local t = m.tiles[idx]
            if not t then t = m.area:CreateTexture(nil, "BACKGROUND", nil, 1); m.tiles[idx] = t end
            t:SetTexture(file)
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", m.area, "TOPLEFT", x + col * tw / lw * w, -(y + row * th / lh * h))
            t:SetSize(tw / lw * w, th / lh * h)
            t:Show()
        end
    end

    function m:SetData(zones, opts)
        self.zones, self.opts = zones, opts or {}
        -- continents présents (onglets), construits une fois
        if not (self.contList and #self.contList > 0) then
            local seen, list = {}, {}
            for _, z in ipairs(zones) do
                local c, name = continentOf(z.map)
                if c and not seen[c] then
                    seen[c] = true
                    local _, nm = pcall(function() return C_Map.GetMapInfo(c).name end)
                    table.insert(list, { c, name or nm or ("#" .. c) })
                end
            end
            table.sort(list, function(a, b) return a[2] < b[2] end)
            if #list > 0 then
                if self.tabs then self.tabs:Hide() end
                self.tabs = UI:Segmented(self.tabsHolder, list, function(v) self.cont = v; self:Paint() end, 26)
                self.tabs:SetPoint("TOPLEFT")
            end
            self.contList = list
        end
        -- continent affiché : celui de la zone choisie (sinon de ta zone, sinon le premier)
        local want = (opts.selected and continentOf(opts.selected)) or (opts.player and continentOf(opts.player))
        if want and want ~= self.lastWant then self.cont = want end
        self.lastWant = want
        if not self.cont and self.contList and self.contList[1] then self.cont = self.contList[1][1] end
        self:Paint()
    end

    function m:Paint()
        local cont = self.cont
        if self.tabs then self.tabs:Select(cont) end
        for _, b in ipairs(self.bubbles) do b:Hide() end
        for _, l in ipairs(self.labels) do l:Hide() end
        local AW, AH = self.area:GetWidth() or 0, self.area:GetHeight() or 0
        if not cont or AW < 50 or AH < 50 then
            self.empty:SetText(WK.T("Carte indisponible")); self.empty:Show()
            return
        end
        self.empty:Hide()
        -- cadrage sur les terres : le rectangle qui englobe les zones du continent (plus une marge)
        -- remplit le cadre, proportions gardées ; la carte déborde (coupée) plutôt que de montrer la mer
        local okL, layers = pcall(C_Map.GetMapArtLayers, cont)
        local L = okL and layers and layers[1]
        local ratio = L and L.layerWidth and L.layerHeight and (L.layerWidth / L.layerHeight) or 1.5
        local u0, u1, v0, v1 = 1, 0, 1, 0
        for _, z in ipairs(self.zones or {}) do
            if continentOf(z.map) == cont then
                local r = rectOn(z.map, cont)
                if r then u0, u1, v0, v1 = math.min(u0, r[1]), math.max(u1, r[2]), math.min(v0, r[3]), math.max(v1, r[4]) end
            end
        end
        if u1 <= u0 or v1 <= v0 then u0, u1, v0, v1 = 0, 1, 0, 1 end
        local pu, pv = (u1 - u0) * 0.04, (v1 - v0) * 0.04
        u0, u1 = math.max(0, u0 - pu), math.min(1, u1 + pu)
        v0, v1 = math.max(0, v0 - pv), math.min(1, v1 + pv)
        -- largeur de la carte entière (px) pour que le cadrage tienne en largeur et en hauteur
        local w = math.min(AW / (u1 - u0), AH * ratio / (v1 - v0), AW * 5)
        local h = w / ratio
        local x = AW / 2 - (u0 + u1) / 2 * w
        local y = AH / 2 - (v0 + v1) / 2 * h
        local key = cont .. ":" .. math.floor(AW) .. "x" .. math.floor(AH) .. ":" .. math.floor(w)
        if self.artKey ~= key then self.artKey = key; paintArt(cont, x, y, w, h) end
        self.shade:ClearAllPoints(); self.shade:SetAllPoints(self.area)
        -- bulles : d'abord les grosses, puis les étiquettes sans chevauchement (zone choisie, ta zone,
        -- conseillée en premier)
        local items = {}
        for _, z in ipairs(self.zones or {}) do
            if continentOf(z.map) == cont then
                local r = rectOn(z.map, cont)
                if r then
                    local cx, cy = x + (r[1] + r[2]) / 2 * w, y + (r[3] + r[4]) / 2 * h
                    table.insert(items, { z = z, x = cx, y = cy })
                end
            end
        end
        local o = self.opts
        local function prio(it)
            local mp = it.z.map
            if mp == o.selected then return 0 end
            if mp == o.player then return 1 end
            if mp == o.best then return 2 end
            return 3
        end
        table.sort(items, function(a, b)
            local pa, pb = prio(a), prio(b)
            if pa ~= pb then return pa > pb end -- les prioritaires dessinées en dernier (au-dessus)
            return (a.z.total or 0) > (b.z.total or 0)
        end)
        local placed = {}
        local n = 0
        for i, it in ipairs(items) do
            local z = it.z
            local b = bubble(i)
            b.z = z
            local frac = z.frac or 0
            local size = math.floor(12 + 12 * frac)
            b:SetSize(size, size); b.edge:SetSize(size + 3, size + 3)
            b:ClearAllPoints(); b:SetPoint("CENTER", self.area, "TOPLEFT", it.x, -it.y)
            local col = (o.color and o.color(z)) or C.text
            b.dot:SetVertexColor(col[1], col[2], col[3], 0.9)
            b:SetFrameLevel(self.pins:GetFrameLevel() + (4 - prio(it)))
            local mp = z.map
            if mp == o.selected then
                b.ring:SetTexture(UI.MEDIA .. "ring"); b.ring:SetSize(size + 12, size + 12); b.ring:SetVertexColor(1, 1, 1, 1); b.ring:Show()
            elseif mp == o.player then
                b.ring:SetTexture(UI.MEDIA .. "ring_dash"); b.ring:SetSize(size + 14, size + 14); b.ring:SetVertexColor(1, 1, 1, 0.9); b.ring:Show()
            else b.ring:Hide() end
            b:Show()
            n = i
        end
        -- étiquettes : priorité d'abord, puis les zones les plus fournies
        local order = {}
        for i = n, 1, -1 do table.insert(order, i) end
        local li = 0
        for _, i in ipairs(order) do
            local it = items[i]
            local tw = math.min(110, 6 * #(it.z.name or ""))
            local lx0, ly0 = it.x - tw / 2, it.y + 10 + 6 * (it.z.frac or 0)
            local ok = lx0 > 0 and lx0 + tw < AW and ly0 + 10 < AH
            for _, r in ipairs(placed) do
                if ok and lx0 < r[3] and lx0 + tw > r[1] and ly0 < r[4] and ly0 + 11 > r[2] then ok = false end
            end
            if ok then
                li = li + 1
                local l = label(li)
                l:ClearAllPoints(); l:SetPoint("TOP", self.area, "TOPLEFT", it.x, -ly0)
                l:SetText(it.z.name)
                local pr = prio(it)
                l:SetTextColor(unpack(pr < 3 and C.text or C.muted))
                l:Show()
                table.insert(placed, { lx0, ly0, lx0 + tw, ly0 + 11 })
            end
        end
    end
    UI:OnResize(m, function() if m.zones then m.artKey = nil; m:Paint() end end)
    return m
end

-- Ligne d'une zone (pages Quêtes et Rares) : nom, étiquette, niveaux colorés selon le perso, barre
-- d'avancement, texte à droite. r:Fill(z, { selected, frac, color, tag = { texte, couleur }, level, right })
UI.ZONE_ROW_H = 30
function UI:ZoneRow(parent, onClick)
    local r = CreateFrame("Button", nil, parent)
    r:SetHeight(UI.ZONE_ROW_H - 2)
    r.bg = UI:Rounded(r, 6, 0, "BACKGROUND", 1)
    r.name = UI:Text(r, 12); r.name:SetPoint("LEFT", 10, 0); r.name:SetWidth(150)
    r.tag = UI:Text(r, 10); r.tag:SetPoint("LEFT", r.name, "RIGHT", 4, 0)
    r.right = UI:Text(r, 10, C.muted); r.right:SetPoint("RIGHT", -10, 0); r.right:SetJustifyH("RIGHT"); r.right:SetWidth(60)
    r.lv = UI:Text(r, 10); r.lv:SetPoint("RIGHT", r.right, "LEFT", -8, 0); r.lv:SetJustifyH("RIGHT"); r.lv:SetWidth(38)
    r.barBg = r:CreateTexture(nil, "ARTWORK"); r.barBg:SetHeight(4); r.barBg:SetColorTexture(1, 1, 1, 0.08)
    r.barBg:SetPoint("RIGHT", r.lv, "LEFT", -10, 0); r.barBg:SetWidth(56)
    r.bar = r:CreateTexture(nil, "OVERLAY"); r.bar:SetHeight(4); r.bar:SetPoint("LEFT", r.barBg, "LEFT")
    r.count = UI:Text(r, 10, C.muted); r.count:SetPoint("RIGHT", r.barBg, "LEFT", -6, 0); r.count:SetJustifyH("RIGHT")
    r:SetScript("OnClick", function(s) if s.z then onClick(s.z.map) end end)
    r:SetScript("OnEnter", function(s) if not s.sel then s.bg:SetColor(1, 1, 1, 0.04) end end)
    r:SetScript("OnLeave", function(s) if not s.sel then s.bg:SetColor(0, 0, 0, 0) end end)
    function r:Fill(z, o)
        self.z, self.sel = z, o.selected
        local col = o.color or C.text
        self.bg:SetColor(unpack(o.selected and { col[1], col[2], col[3], 0.16 } or { 0, 0, 0, 0 }))
        self.name:SetText(z.name)
        self.tag:SetShown(o.tag ~= nil)
        if o.tag then self.tag:SetText(o.tag[1]); self.tag:SetTextColor(unpack(o.tag[2])) end
        -- le nom prend la place qui reste (coupé s'il le faut)
        local tagW = o.tag and ((self.tag:GetStringWidth() or 50) + 4) or 0
        self.name:SetWidth(math.max(60, math.min((self.name:GetStringWidth() or 100) + 2, (self:GetWidth() or 400) - 236 - tagW)))
        -- niveaux : vert = ton niveau, orange un peu haut, rouge trop haut, gris trop bas
        local lvl, lc = o.level or 1, C.positive
        if (z.min or 0) > lvl + 3 then lc = C.negative elseif (z.min or 0) > lvl then lc = C.warning
        elseif (z.max or 0) < lvl - 10 then lc = C.dim end
        self.lv:SetText((z.min or 0) .. "-" .. (z.max or 0)); self.lv:SetTextColor(unpack(lc))
        local f = math.min(1, o.frac or 0)
        self.bar:SetShown(f > 0); self.bar:SetWidth(math.max(1, 56 * f))
        self.bar:SetColorTexture(f >= 1 and C.positive[1] or col[1], f >= 1 and C.positive[2] or col[2], f >= 1 and C.positive[3] or col[3], 1)
        self.count:SetText((z.done or z.killed or 0) .. "/" .. (z.total or 0))
        self.right:SetText(o.right or "")
        self:Show()
    end
    return r
end

-- Disposition commune des pages Quêtes et Rares : bandeau, puis carte à gauche, zones et liste à droite.
-- page = la définition (kpi, map, zcard, list) ; open = réglages ouverts (tout est caché).
function UI:ZoneLayout(page, p, top, w, h, open)
    local show = not open
    for _, f in ipairs({ page.kpi, page.map, page.zcard, page.list }) do f:SetShown(show); f:ClearAllPoints() end
    if open then return end
    w = (w and w > 100) and w or 800
    page.kpi:SetPoint("TOPLEFT", 0, -top); page.kpi:SetPoint("TOPRIGHT", 0, -top)
    local y = top + page.kpi:GetHeight() + 12
    local mw = math.floor(w * 0.46)
    page.map:SetPoint("TOPLEFT", 0, -y); page.map:SetPoint("BOTTOMLEFT", 0, 0); page.map:SetWidth(mw)
    local bodyH = math.max(200, h - y)
    local zh = math.floor(bodyH * 0.40)
    page.zcard:SetPoint("TOPLEFT", mw + 12, -y); page.zcard:SetPoint("TOPRIGHT", 0, -y); page.zcard:SetHeight(zh)
    page.list:SetPoint("TOPLEFT", mw + 12, -(y + zh + 12)); page.list:SetPoint("BOTTOMRIGHT", 0, 0)
end

---------------------------------------------------------------------------
-- Recharger l'interface : sur ce client, ReloadUI() appelé par un addon est bloqué (ADDON_ACTION_BLOCKED,
-- même après un clic). Seule la commande /reload passe, lancée par un bouton protégé du jeu (macro).
-- UI:SecureReload(b) pose ce bouton, invisible, sur un de nos boutons (b garde son style et son infobulle).
---------------------------------------------------------------------------
-- Le bouton protégé est un enfant d'UIParent (jamais de notre fenêtre : elle deviendrait protégée et ne
-- s'ouvrirait plus en combat), posé hors combat sur notre bouton tant qu'il est visible, retiré en combat.
local reloads = {}
local function placeReload(s)
    if InCombatLockdown and InCombatLockdown() then return end
    local b = s.owner
    if b:IsVisible() then
        s:ClearAllPoints(); s:SetAllPoints(b)
        -- une strate au-dessus de notre bouton : aucune partie de notre fenêtre (remontée au clic) ne le couvre
        local UP = { BACKGROUND = "LOW", LOW = "MEDIUM", MEDIUM = "HIGH", HIGH = "DIALOG", DIALOG = "FULLSCREEN",
            FULLSCREEN = "FULLSCREEN_DIALOG", FULLSCREEN_DIALOG = "TOOLTIP", TOOLTIP = "TOOLTIP" }
        s:SetFrameStrata(UP[b:GetFrameStrata() or "HIGH"] or "DIALOG")
        s:SetFrameLevel(10)
        s:Show()
    else
        s:Hide()
    end
end
function UI:SecureReload(b)
    if b.reloadSec then return b.reloadSec end
    if InCombatLockdown and InCombatLockdown() then return nil end
    local s = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
    s.owner = b
    -- clic de souris : au relâchement (avec « touche enfoncée » du jeu, un clic ne partait pas)
    if s.RegisterForClicks then s:RegisterForClicks("AnyUp", "AnyDown") end
    s:SetAttribute("useOnKeyDown", false)
    s:SetAttribute("type", "macro")
    s:SetAttribute("macrotext", "/reload")
    -- survol transmis à notre bouton (surbrillance, infobulle)
    s:SetScript("OnEnter", function() local fn = b:GetScript("OnEnter"); if fn then fn(b) end end)
    s:SetScript("OnLeave", function() local fn = b:GetScript("OnLeave"); if fn then fn(b) end end)
    -- diagnostic (/wk rechargement) : dernier clic reçu et ce que le jeu a dit juste après
    s:HookScript("PreClick", function(_, button, down)
        UI.reloadLast = { at = GetTime(), button = button, down = down, keyDown = WK.GetCVar and WK.GetCVar("ActionButtonUseKeyDown") }
    end)
    s:Hide()
    b:HookScript("OnShow", function() placeReload(s) end)
    -- notre fenêtre passe devant au clic (niveau relevé) : le bouton protégé est remonté au-dessus de b dès
    -- que la souris arrive dessus, pour recevoir le clic
    b:HookScript("OnEnter", function()
        if (s:GetFrameLevel() or 0) <= (b:GetFrameLevel() or 0) or not s:IsShown() then placeReload(s) end
    end)
    b:HookScript("OnHide", function() placeReload(s) end)
    b.reloadSec = s
    table.insert(reloads, s)
    C_Timer.After(0, function() placeReload(s) end)
    return s
end
-- /wk rechargement : état des boutons de rechargement (affiché, devant, souris dessus, dernier clic)
function UI:ReloadDiag()
    local out = {}
    for i, s in ipairs(reloads) do
        local b = s.owner
        table.insert(out, string.format("%d. bouton %s · notre bouton %s, %s %d · protégé %s, %s %d · souris dessus : %s / %s · macro « %s »",
            i, tostring(b.tooltip or (b.label and (b.label:GetText())) or "?"), b:IsVisible() and "visible" or "caché",
            tostring((b:GetFrameStrata())), b:GetFrameLevel() or 0, s:IsShown() and "affiché" or "caché",
            tostring((s:GetFrameStrata())), s:GetFrameLevel() or 0,
            tostring((b:IsMouseOver())), tostring((s:IsMouseOver())), tostring((s:GetAttribute("macrotext")))))
    end
    local l = UI.reloadLast
    table.insert(out, l and string.format("dernier clic reçu il y a %.0f s (%s, %s, touche enfoncée du jeu : %s)", GetTime() - l.at,
        tostring(l.button), l.down and "enfoncé" or "relâché", tostring(l.keyDown)) or "aucun clic reçu par le bouton protégé")
    return out
end

-- en combat : retirés (un bouton protégé ne se déplace ni ne se cache plus ensuite) ; remis après
WK:On("PLAYER_REGEN_DISABLED", function() for _, s in ipairs(reloads) do s:Hide(); s:ClearAllPoints() end end)
WK:On("PLAYER_REGEN_ENABLED", function() for _, s in ipairs(reloads) do placeReload(s) end end)

-- Petite fenêtre « recharger maintenant ? » (changement de profil…) : le bouton recharge par /reload protégé.
local reloadAsk
function UI:AskReload(text)
    if not reloadAsk then
        local f = CreateFrame("Frame", "WarbandKeeperReloadAsk", UIParent)
        f:SetSize(380, 120)
        f:SetPoint("CENTER", 0, 120)
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:EnableMouse(true)
        UI:Panel(f, 12, C.surface, C.border)
        f.text = UI:Text(f, 12); f.text:SetPoint("TOPLEFT", 18, -18); f.text:SetPoint("RIGHT", -18, 0)
        f.text:SetJustifyH("LEFT"); if f.text.SetWordWrap then f.text:SetWordWrap(true) end
        f.go = UI:Button(f, "Recharger maintenant", nil, 28, "primary", "power")
        f.go:SetPoint("BOTTOMRIGHT", -14, 14)
        f.later = UI:Button(f, "Plus tard", nil, 28, "ghost")
        f.later:SetPoint("RIGHT", f.go, "LEFT", -8, 0)
        f.later:SetScript("OnClick", function() f:Hide() end)
        UI:SecureReload(f.go)
        f:Hide()
        reloadAsk = f
    end
    -- bouton protégé pas encore posé (première demande pendant un combat) : posé maintenant si possible
    UI:SecureReload(reloadAsk.go)
    reloadAsk.text:SetText(text or WK.T("Recharger l'interface pour appliquer le changement."))
    reloadAsk:Show()
end
