local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Éléments affichés à l'écran (pile d'alertes, bouton du familier, flèche de guidage…) :
-- position, taille et opacité communes, et un mode édition plein écran pour les régler.
--
--   UI:RegisterHUD(key, frame, { label, point = "CENTER", default = { x, y }, legacy = function() ... end,
--                                 preview = function(box) end, options = { ... }, onApply = function() end })
-- La position est celle du point de référence (CENTER par défaut, ou TOP / BOTTOM) par rapport au
-- centre de l'écran, en unités de l'interface : elle ne dépend pas de la taille de l'élément.

local registry, order = {}, {}
UI.hudRegistry = registry -- (lecture seule : tests, diagnostic)
local stopTest -- mode test (plus bas)

-- « Disposition : ce perso » est un choix du perso (WK.DB.char.hudPerChar), pas du compte : avant, le drapeau
-- était au compte et l'activer sur un perso remettait les HUD des autres à leur place par défaut. Ancien
-- drapeau du compte : repris pour un perso seulement s'il a déjà sa disposition à lui.
local function perChar()
    local ch = WK.DB.char
    if ch.hudPerChar == nil then
        local ui = WK.DB.global.settings.ui
        ch.hudPerChar = (ui.hudPerChar and ch.hud and next(ch.hud) ~= nil) and true or false
    end
    return ch.hudPerChar
end
UI.HUDPerChar = perChar
local function store()
    local ui = WK.DB.global.settings.ui
    if perChar() then
        WK.DB.char.hud = WK.DB.char.hud or {}
        return WK.DB.char.hud
    end
    ui.hud = ui.hud or {}
    return ui.hud
end

function UI:HUDEntry(key)
    local s = store()
    s[key] = s[key] or {}
    return s[key]
end

local function refPoint(key)
    local r = registry[key]
    local e = UI:HUDEntry(key)
    if r.dynamicPoint then return r.dynamicPoint(e) end
    return r.point or "CENTER"
end

-- Coordonnées actuelles du point de référence d'un cadre, depuis le centre de l'écran.
local function readRef(frame, point)
    local l, b, w, h = frame:GetRect()
    if not l then return nil end
    local k = (frame:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
    l, b, w, h = l * k, b * k, w * k, h * k
    local cx = l + w / 2 - UIParent:GetWidth() / 2
    local cy
    if point == "TOP" then cy = b + h elseif point == "BOTTOM" then cy = b else cy = b + h / 2 end
    return cx, cy - UIParent:GetHeight() / 2
end

function UI:HUDApply(key)
    local r = registry[key]
    if not r or not r.frame then return end
    local f, e = r.frame, self:HUDEntry(key)
    if not e.x then
        -- Première fois : ancienne position enregistrée (versions précédentes) ou position par défaut.
        if r.legacy and r.legacy() then
            e.x, e.y = readRef(f, refPoint(key))
        end
        if not e.x then e.x, e.y = r.default[1], r.default[2] end
    end
    local s = e.scale or 1
    if r.protected and InCombatLockdown and InCombatLockdown() then
        r.pending = true -- un bouton protégé ne bouge pas en combat : appliqué à la sortie
        return
    end
    r.pending = nil
    f:SetScale(s)
    f:ClearAllPoints()
    local p = refPoint(key)
    f:SetPoint(p, UIParent, "CENTER", e.x / s, e.y / s)
    if not r.protected or not (InCombatLockdown and InCombatLockdown()) then f:SetAlpha(e.alpha or 1) end
    if r.onApply then r.onApply(e) end
end

-- Après un déplacement direct (glisser hors du mode édition) : on relit la position.
function UI:HUDCapture(key)
    local r = registry[key]
    if not r or not r.frame then return end
    local e = self:HUDEntry(key)
    e.x, e.y = readRef(r.frame, refPoint(key))
    self:HUDApply(key)
end

function UI:RegisterHUD(key, frame, opts)
    opts.frame = frame
    opts.key = key
    opts.default = opts.default or { 0, 0 }
    if not registry[key] then table.insert(order, key) end
    registry[key] = opts
    self:HUDApply(key)
    if self.editing then self:EditRefresh() end
end

-- Tests en plus des éléments placés (bandeau de connexion…) : { start = fn, stop = fn }
local extraTests = {}
function UI:RegisterHUDTest(start, stop) table.insert(extraTests, { start = start, stop = stop }) end

function UI:HUDReset(key)
    local s = store()
    s[key] = nil
    local r = registry[key]
    if r then
        local e = self:HUDEntry(key)
        e.x, e.y = r.default[1], r.default[2]
        self:HUDApply(key)
    end
end

function UI:HUDReapplyAll()
    for _, key in ipairs(order) do self:HUDApply(key) end
end

---------------------------------------------------------------------------
-- Mode édition
---------------------------------------------------------------------------
local overlay, toolbar, popup
local boxes = {}
local selected
local gridSize, magnet = 32, true

local function cursor()
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale() or 1
    return x / s, y / s
end

local function snap(v)
    if not magnet or IsShiftKeyDown() then return math.floor(v + 0.5) end
    return math.floor(v / gridSize + 0.5) * gridSize
end

local gridLines = {}
local function drawGrid()
    for _, t in ipairs(gridLines) do t:Hide() end
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    local i = 0
    local function line(vertical, pos)
        i = i + 1
        local t = gridLines[i] or overlay:CreateTexture(nil, "BACKGROUND", nil, 1)
        gridLines[i] = t
        local strong = math.abs(pos) < 1
        local r, g, b = UI:Accent()
        -- grille fine (4, 8) : traits plus légers, un trait sur quatre un peu plus marqué
        local fine = gridSize <= 8
        local major = math.floor(math.abs(pos) / gridSize + 0.5) % 4 == 0
        t:SetColorTexture(r, g, b, strong and 0.45 or (fine and (major and 0.12 or 0.05) or 0.12))
        t:ClearAllPoints()
        if vertical then
            t:SetPoint("TOP", overlay, "TOP", pos, 0); t:SetPoint("BOTTOM", overlay, "BOTTOM", pos, 0); t:SetWidth(1)
        else
            t:SetPoint("LEFT", overlay, "LEFT", 0, pos); t:SetPoint("RIGHT", overlay, "RIGHT", 0, pos); t:SetHeight(1)
        end
        t:Show()
    end
    for x = 0, w / 2, gridSize do line(true, x); if x > 0 then line(true, -x) end end
    for y = 0, h / 2, gridSize do line(false, y); if y > 0 then line(false, -y) end end
end

local function select(key)
    selected = key
    for k, b in pairs(boxes) do b:Paint(k == key) end
    if popup then popup:Fill(key) end
end

local function buildBox(key)
    local r = registry[key]
    local b = CreateFrame("Button", nil, overlay)
    b:SetFrameLevel(overlay:GetFrameLevel() + 10)
    -- Fond léger et contour fin : l'élément reste visible à travers le cadre.
    b.fill = b:CreateTexture(nil, "BACKGROUND")
    b.fill:SetAllPoints()
    b.edges = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = b:CreateTexture(nil, "BORDER")
        if side == "TOP" or side == "BOTTOM" then
            t:SetPoint(side .. "LEFT"); t:SetPoint(side .. "RIGHT"); t:SetHeight(2)
        else
            t:SetPoint("TOP" .. side); t:SetPoint("BOTTOM" .. side); t:SetWidth(2)
        end
        table.insert(b.edges, t)
    end
    b.tagF = CreateFrame("Frame", nil, b)
    b.tagF:SetPoint("BOTTOM", b, "TOP", 0, 4) -- titre centré au-dessus de l'élément
    b.tagF:SetHeight(18)
    b.tagBg = UI:Rounded(b.tagF, 6, 0, "BACKGROUND", 1)
    b.tag = UI:Text(b.tagF, 11, C.onAccent)
    b.tag:SetPoint("LEFT", 8, 0)
    b.tag:SetText(r.label)
    b.tagF:SetWidth(b.tag:GetStringWidth() + 16)
    if r.preview then r.preview(b) end
    -- poignée de taille (coin bas-droit)
    b.grip = CreateFrame("Button", nil, b)
    b.grip:SetSize(14, 14)
    b.grip:SetPoint("BOTTOMRIGHT", 5, -5)
    b.gripTex = UI:Rounded(b.grip, 3, 0, "OVERLAY", 1)
    function b:Paint(sel)
        local ar, ag, ab = UI:Accent()
        for _, t in ipairs(self.edges) do t:SetColorTexture(ar, ag, ab, sel and 1 or 0.6) end
        self.fill:SetColorTexture(ar, ag, ab, sel and 0.12 or 0.05)
        self.tagBg:SetColor(ar, ag, ab, 1)
        self.gripTex:SetColor(ar, ag, ab, 1)
    end
    b:SetAllPoints(r.frame)
    b:RegisterForClicks("LeftButtonUp")
    -- Glisser : déplace l'élément (aimanté à la grille, Maj = libre)
    b:SetScript("OnMouseDown", function(s, button)
        if button ~= "LeftButton" then return end
        local e = UI:HUDEntry(key)
        local cx, cy = cursor()
        s.drag = { cx = cx, cy = cy, x = e.x, y = e.y, moved = false }
        s:SetScript("OnUpdate", function(self2)
            local d = self2.drag
            local nx, ny = cursor()
            if math.abs(nx - d.cx) + math.abs(ny - d.cy) > 3 then d.moved = true end
            e.x, e.y = snap(d.x + nx - d.cx), snap(d.y + ny - d.cy)
            UI:HUDApply(key)
        end)
    end)
    b:SetScript("OnMouseUp", function(s)
        s:SetScript("OnUpdate", nil)
        local moved = s.drag and s.drag.moved
        s.drag = nil
        select(key)
        if not moved and popup then popup:Show() end
    end)
    -- Tirer le coin : change la taille (50 % à 200 %)
    b.grip:SetScript("OnMouseDown", function(g)
        local e = UI:HUDEntry(key)
        local cx = cursor()
        local w = (r.frame:GetWidth() or 100) * (e.scale or 1)
        g.drag = { cx = cx, s = e.scale or 1, w = math.max(20, w) }
        g:SetScript("OnUpdate", function(g2)
            local nx = cursor()
            local sc = g2.drag.s * (1 + (nx - g2.drag.cx) / g2.drag.w)
            e.scale = math.max(0.5, math.min(2, math.floor(sc * 20 + 0.5) / 20))
            UI:HUDApply(key)
            if popup and selected == key then popup:Fill(key) end
        end)
    end)
    b.grip:SetScript("OnMouseUp", function(g) g:SetScript("OnUpdate", nil); select(key) end)
    b:Paint(false)
    return b
end

local function buildPopup()
    local p = UI:Card(overlay, "")
    p:SetSize(280, 220)
    p:SetFrameLevel(overlay:GetFrameLevel() + 30)
    p:EnableMouse(true)
    p:Hide()
    p.sets = {} -- un jeu de commandes par élément, construit une fois puis montré / caché
    local close = UI:IconButton(p, "close", 22, nil, "accent")
    close:SetPoint("TOPRIGHT", -8, -8)
    close:SetScript("OnClick", function() p:Hide() end)
    -- Les commandes relisent l'entrée à chaque fois (HUDReset ou « Disposition » en changent la table).
    local function entry(key) return UI:HUDEntry(key) end
    local function buildSet(key)
        local r = registry[key]
        local set = { rows = {}, segs = {} }
        local y = -42
        local function addRow(label, ctl, w)
            local row = UI:SettingRow(p, y, label, nil, ctl, w)
            table.insert(set.rows, row)
            y = y - 38
            return row
        end
        addRow(T("Taille"), UI:Slider(p, 150, 0.5, 2, 0.05, function() return entry(key).scale or 1 end,
            function(v) entry(key).scale = v; UI:HUDApply(key) end, "%.2fx"), 150)
        addRow(T("Opacité"), UI:Slider(p, 150, 0.3, 1, 0.05, function() return entry(key).alpha or 1 end,
            function(v) entry(key).alpha = v; UI:HUDApply(key) end, "%.2f"), 150)
        for _, opt in ipairs(r.options or {}) do
            if opt.type == "seg" then
                local seg = UI:Segmented(p, opt.items, function(v) opt.set(entry(key), v); UI:HUDApply(key) end, 26)
                table.insert(set.segs, { seg = seg, opt = opt })
                addRow(T(opt.label), seg, 150)
            elseif opt.type == "toggle" then
                local tg = UI:Toggle(p, function() return opt.get(entry(key)) end, function(v) opt.set(entry(key), v); UI:HUDApply(key) end)
                set.toggles = set.toggles or {}
                table.insert(set.toggles, tg)
                addRow(T(opt.label), tg, 60)
            end
        end
        local reset = UI:Button(p, "Réinitialiser", nil, 26, "secondary")
        reset:SetPoint("BOTTOMLEFT", 14, 12)
        reset:SetScript("OnClick", function() UI:HUDReset(key); p.built = nil; p:Fill(key) end)
        table.insert(set.rows, reset)
        set.height = -y + 50
        return set
    end
    function p:Fill(key)
        local r = registry[key]
        if not r then return end
        local e = UI:HUDEntry(key)
        self.title:SetText(r.label)
        self.sets[key] = self.sets[key] or buildSet(key)
        local set = self.sets[key]
        if self.built ~= key then
            for k, other in pairs(self.sets) do
                if k ~= key then for _, row in ipairs(other.rows) do row:Hide() end end
            end
            for _, row in ipairs(set.rows) do row:Show() end
            self.built = key
            self:SetHeight(set.height)
        end
        -- valeurs à jour (les curseurs se relisent à l'affichage)
        for _, sg in ipairs(set.segs) do sg.seg:Select(sg.opt.get(e)) end
        for _, tg in ipairs(set.toggles or {}) do tg:Refresh() end
        for _, row in ipairs(set.rows) do
            if row:IsShown() then row:Hide(); row:Show() end
        end
        -- à côté de l'élément choisi, sans sortir de l'écran
        self:ClearAllPoints()
        local fx = (r.frame:GetCenter())
        if fx and fx * (r.frame:GetEffectiveScale() / UIParent:GetEffectiveScale()) > UIParent:GetWidth() / 2 then
            self:SetPoint("RIGHT", boxes[key], "LEFT", -16, 0)
        else
            self:SetPoint("LEFT", boxes[key], "RIGHT", 16, 0)
        end
        self:SetClampedToScreen(true)
    end
    return p
end

local function buildOverlay()
    overlay = CreateFrame("Frame", "WarbandKeeperEditMode", UIParent)
    overlay:SetAllPoints(UIParent)
    overlay:SetFrameStrata("DIALOG")
    overlay:EnableMouse(false)
    overlay.dim = overlay:CreateTexture(nil, "BACKGROUND")
    overlay.dim:SetAllPoints()
    overlay.dim:SetColorTexture(0, 0, 0, 0.35)
    -- Clavier : Échap pour quitter, flèches pour ajuster l'élément choisi (Maj : 10 px)
    overlay:EnableKeyboard(true)
    overlay:SetScript("OnKeyDown", function(s, key)
        local handled = true
        if key == "ESCAPE" then UI:ExitEditMode()
        elseif selected and (key == "UP" or key == "DOWN" or key == "LEFT" or key == "RIGHT") then
            local e = UI:HUDEntry(selected)
            local d = IsShiftKeyDown() and 10 or 1
            if key == "UP" then e.y = e.y + d elseif key == "DOWN" then e.y = e.y - d
            elseif key == "LEFT" then e.x = e.x - d else e.x = e.x + d end
            UI:HUDApply(selected)
        else
            handled = false
        end
        if s.SetPropagateKeyboardInput then s:SetPropagateKeyboardInput(not handled) end
    end)

    toolbar = CreateFrame("Frame", nil, overlay)
    toolbar:SetSize(560, 44)
    toolbar:SetFrameLevel(overlay:GetFrameLevel() + 40)
    UI:Panel(toolbar, 12, { C.bg[1], C.bg[2], C.bg[3], 0.96 }, C.border)
    toolbar:EnableMouse(true)
    -- déplaçable : glisser la barre (hors boutons) ; position gardée (settings.ui.editBar), double-clic = en bas
    toolbar:SetMovable(true)
    toolbar:SetClampedToScreen(true)
    toolbar:RegisterForDrag("LeftButton")
    local function placeBar()
        local pos = WK.DB.global.settings.ui.editBar
        toolbar:ClearAllPoints()
        if pos then toolbar:SetPoint("CENTER", UIParent, "BOTTOMLEFT", pos[1], pos[2])
        else toolbar:SetPoint("BOTTOM", overlay, "BOTTOM", 0, 34) end -- en bas de l'écran, au-dessus de la consigne
    end
    placeBar()
    toolbar:SetScript("OnDragStart", function(s) s:StartMoving() end)
    toolbar:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        local x, y = s:GetCenter()
        if x and y then WK.DB.global.settings.ui.editBar = { x, y } end
        placeBar()
    end)
    toolbar:SetScript("OnMouseUp", function(s, btn)
        local now = GetTime()
        if btn == "LeftButton" and s.lastClick and now - s.lastClick < 0.35 then
            WK.DB.global.settings.ui.editBar = nil
            placeBar()
        end
        s.lastClick = now
    end)
    toolbar.grip = UI:Icon(toolbar, "grip", 14, nil, "ARTWORK")
    toolbar.grip:SetPoint("LEFT", 6, 0)
    toolbar.grip:SetVertexColor(C.dim[1], C.dim[2], C.dim[3], 1)
    local title = UI:Text(toolbar, 13)
    title:SetPoint("LEFT", 24, 0)
    title:SetText("Mode édition")
    UI:OnAccent(function() title:SetTextColor(UI:Accent()) end)
    local x = title:GetStringWidth() + 40
    local function tb(text, style, fn, tip)
        local b = UI:Button(toolbar, text, nil, 28, style)
        b:SetPoint("LEFT", x, 0)
        b:SetScript("OnClick", fn)
        b.tooltip = tip
        x = x + b:GetWidth() + 8
        return b
    end
    local gridBtn
    local ui = WK.DB.global.settings.ui
    gridSize = ui.editGrid or gridSize
    gridBtn = tb(string.format(T("Grille : %d"), gridSize), "secondary", function()
        -- 4, 8, 16, 32, 64, puis on recommence ; le choix est retenu
        local SIZES = { 4, 8, 16, 32, 64 }
        local nxt = SIZES[1]
        for i, v in ipairs(SIZES) do if v == gridSize then nxt = SIZES[i % #SIZES + 1] end end
        gridSize = nxt
        ui.editGrid = gridSize
        gridBtn.label:SetText(string.format(T("Grille : %d"), gridSize))
        drawGrid()
    end)
    local magBtn
    magBtn = tb(T("Aimant : oui"), "secondary", function()
        magnet = not magnet
        magBtn.label:SetText(magnet and T("Aimant : oui") or T("Aimant : non"))
    end, "Les éléments s'alignent sur la grille. Maj enfoncée : placement libre.")
    local perBtn
    local function perLabel() return perChar() and T("Disposition : ce perso") or T("Disposition : compte") end
    perBtn = tb(perLabel(), "secondary", function()
        local ch = WK.DB.char
        local on = not perChar()
        -- passage à une disposition propre au perso : elle part de celle du compte (rien ne saute)
        if on and not (ch.hud and next(ch.hud)) then
            local function deep(t)
                if type(t) ~= "table" then return t end
                local o = {}
                for a, b in pairs(t) do o[a] = deep(b) end
                return o
            end
            ch.hud = deep(WK.DB.global.settings.ui.hud or {})
        end
        ch.hudPerChar = on
        perBtn.label:SetText(perLabel())
        UI:HUDReapplyAll()
        if popup then popup.built = nil; popup:Hide() end
    end, "Disposition commune à tout le compte, ou propre à ce perso.")
    tb("Tout réinitialiser", "ghost", function()
        if not IsShiftKeyDown() then WK:Print(T("Maj + clic pour tout réinitialiser.")) return end
        for _, key in ipairs(order) do UI:HUDReset(key) end
        if popup then popup.built = nil; if selected then popup:Fill(selected) end end
    end, "Maj + clic : remet tous les éléments à leur place et à leur taille d'origine.")
    tb("Tester", "secondary", function() UI:TestHUD() end,
        "Joue chaque élément comme en jeu (alerte de rare et son son, récap de pêche, bandeau de connexion…) pendant quelques secondes.")
    tb("Terminer", "primary", function() UI:ExitEditMode() end)
    toolbar:SetWidth(x + 8)
    local hint = UI:Text(overlay, 11, C.text)
    hint:SetPoint("TOP", toolbar, "BOTTOM", 0, -6)
    hint:SetText("Glisser pour déplacer · coin pour la taille · clic pour les réglages · flèches pour ajuster · Échap pour quitter · cette barre se déplace aussi (double-clic : la remettre en bas)")
    popup = buildPopup()
end

-- aperçus ouverts : refermés à la sortie même si l'élément a été coupé entre-temps (avant, un élément coupé
-- pendant le mode édition gardait son aperçu, par exemple l'encart du feu de camp, bloqué jusqu'au /reload)
local sampled = {}
local function sampleOn(key, r)
    if r.sample then r.sample(true); sampled[key] = true end
end
local function sampleOff(key, r)
    if sampled[key] and r.sample then sampled[key] = nil; r.sample(false) end
end
UI.EditSampled = sampled

function UI:EnterEditMode()
    if InCombatLockdown and InCombatLockdown() then WK:Print(T("Pas en combat.")) return end
    if self.editing then return end
    if not overlay then buildOverlay() end
    self.editing = true
    -- La fenêtre se ferme pendant l'édition et se rouvre à la sortie si elle était ouverte.
    self.reopenAfterEdit = self.frame and self.frame:IsShown() or false
    if self.reopenAfterEdit then self.frame:Hide() end
    overlay:Show()
    drawGrid()
    local first
    for _, key in ipairs(order) do
        local r = registry[key]
        -- élément coupé dans ses réglages (opts.enabled) : absent du mode édition
        if not r.enabled or r.enabled() then
            sampleOn(key, r)
            boxes[key] = boxes[key] or buildBox(key)
            boxes[key]:SetAllPoints(r.frame)
            boxes[key]:Show()
            first = first or key
        elseif boxes[key] then
            boxes[key]:Hide()
        end
    end
    if first then select(first) end
    popup:Hide()
end


function UI:EditRefresh()
    if not self.editing then return end
    for _, key in ipairs(order) do
        local r = registry[key]
        if not r.enabled or r.enabled() then
            boxes[key] = boxes[key] or buildBox(key)
            boxes[key]:SetAllPoints(r.frame)
            boxes[key]:Show()
        else
            -- coupé pendant le mode édition : son aperçu est refermé tout de suite
            sampleOff(key, r)
            if boxes[key] then boxes[key]:Hide() end
        end
    end
end

function UI:ExitEditMode()
    if not self.editing then return end
    if self.testing then self.editing = false; stopTest(); self.editing = true end
    self.editing = false
    for _, key in ipairs(order) do
        local r = registry[key]
        sampleOff(key, r)
    end
    if popup then popup:Hide() end
    overlay:Hide()
    -- (pas si un combat commence et que l'option « fermer la fenêtre en combat » est active)
    local combatClose = InCombatLockdown and InCombatLockdown() and WK.DB.global.settings.ui.closeInCombat
    if self.reopenAfterEdit and self.frame and not combatClose then self.frame:Show(); self:Refresh() end
    self.reopenAfterEdit = nil
end

---------------------------------------------------------------------------
-- Mode test : les cadres d'édition s'effacent et chaque élément est joué comme en jeu (opts.test :
-- vrai comportement, minuterie, son ; sinon son aperçu), puis retour au mode édition
---------------------------------------------------------------------------
local TEST_TIME = 10
local testBar
stopTest = function()
    if not UI.testing then return end
    UI.testing = false
    if testBar then testBar:Hide() end
    for _, key in ipairs(order) do
        local r = registry[key]
        if (not r.enabled or r.enabled()) and r.testStop then pcall(r.testStop) end
        sampleOff(key, r)
    end
    for _, t in ipairs(extraTests) do if t.stop then pcall(t.stop) end end
    if UI.editing and overlay then
        overlay:Show()
        for _, key in ipairs(order) do
            local r = registry[key]
            if not r.enabled or r.enabled() then sampleOn(key, r) end
        end
        UI:EditRefresh()
    end
end
function UI:TestHUD()
    if self.testing or (InCombatLockdown and InCombatLockdown()) then return end
    self.testing = true
    if overlay then overlay:Hide() end
    if popup then popup:Hide() end
    for _, key in ipairs(order) do
        local r = registry[key]
        if not r.enabled or r.enabled() then
            sampleOff(key, r)
            if r.test then pcall(r.test) else sampleOn(key, r) end
        end
    end
    for _, t in ipairs(extraTests) do if t.start then pcall(t.start) end end
    if not testBar then
        testBar = CreateFrame("Frame", nil, UIParent)
        testBar:SetFrameStrata("TOOLTIP")
        testBar:SetSize(300, 40)
        testBar:SetPoint("BOTTOM", 0, 40)
        UI:Panel(testBar, 12, { C.bg[1], C.bg[2], C.bg[3], 0.96 }, C.border)
        testBar.text = UI:Text(testBar, 12)
        testBar.text:SetPoint("LEFT", 16, 2)
        testBar.stop = UI:Button(testBar, "Arrêter", nil, 26, "primary")
        testBar.stop:SetPoint("RIGHT", -8, 0)
        testBar.stop:SetScript("OnClick", stopTest)
        testBar.fill = testBar:CreateTexture(nil, "OVERLAY")
        testBar.fill:SetHeight(3)
        testBar.fill:SetPoint("BOTTOMLEFT", 12, 1)
        testBar:SetScript("OnUpdate", function(s)
            local left = s.untilT - GetTime()
            if left <= 0 then stopTest() return end
            s.text:SetText(string.format(T("Test en cours · %d s"), math.ceil(left)))
            s.fill:SetColorTexture(UI:Accent())
            s.fill:SetWidth(math.max(0.01, (s:GetWidth() - 24) * left / TEST_TIME))
        end)
    end
    testBar.untilT = GetTime() + TEST_TIME
    testBar:Show()
end

-- Un combat met fin au mode édition ; un bouton protégé déplacé en combat se place à la sortie.
WK:On("PLAYER_REGEN_DISABLED", function() UI:ExitEditMode() end)
WK:On("PLAYER_REGEN_ENABLED", function()
    for _, key in ipairs(order) do if registry[key].pending then UI:HUDApply(key) end end
end)
