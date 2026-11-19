local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Notes de carte perso (Modules/MapNotes.lua) : pastilles sur la carte du monde (appelé par
-- UI/MapPins.lua) et sur la minicarte, pose par Alt + clic (réglable) sur la carte, fenêtre de pose et
-- de modification. Clic sur une pastille : modifier ; Maj + clic : guider jusqu'à la note.
local N = WK.modules.MapNotes

---------------------------------------------------------------------------
-- Pastille (carte et minicarte)
---------------------------------------------------------------------------
local function makePin(parent)
    local p = CreateFrame("Button", nil, parent)
    p.shadow = p:CreateTexture(nil, "BACKGROUND")
    p.shadow:SetTexture(UI.MEDIA .. "circle")
    p.shadow:SetVertexColor(0, 0, 0, 0.55)
    p.ring = p:CreateTexture(nil, "BORDER")
    p.ring:SetTexture(UI.MEDIA .. "circle")
    p.inner = p:CreateTexture(nil, "ARTWORK")
    p.inner:SetTexture(UI.MEDIA .. "circle")
    p.icon = p:CreateTexture(nil, "OVERLAY")
    p.pill = CreateFrame("Frame", nil, p)
    p.pill.bg = UI:Rounded(p.pill, 6, 0, "BACKGROUND", 1)
    p.label = UI:Text(p.pill, 10)
    p.label:SetPoint("CENTER")
    p:SetScript("OnEnter", function(s)
        local n = s.note
        if not n then return end
        UI:TooltipOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText(n.title or T("Note"), 1, 1, 1)
        if n.text and n.text ~= "" then GameTooltip:AddLine(n.text, 0.85, 0.85, 0.85, true) end
        GameTooltip:AddLine(N:ZoneName(n.map) .. "  ·  " .. N:Coords(n), 0.55, 0.55, 0.55)
        if s.onMap then GameTooltip:AddLine(T("Clic : modifier  ·  Maj + clic : guider"), 0.55, 0.55, 0.55) end
        GameTooltip:Show()
        if not s.labelOn and s.onMap then s.pill:Show() end
    end)
    p:SetScript("OnLeave", function(s) GameTooltip:Hide(); if not s.labelOn then s.pill:Hide() end end)
    p:RegisterForClicks("LeftButtonUp")
    p:SetScript("OnClick", function(s)
        if not s.note or not s.onMap then return end
        if IsShiftKeyDown() then N:GuideTo(s.note) else UI:EditMapNote(s.note) end
    end)
    return p
end

local function paintPin(p, n, size, onMap)
    p.note, p.onMap = n, onMap
    local col = N:Color(n.color)
    p:SetSize(size, size)
    p.shadow:SetSize(size + 4, size + 4); p.shadow:ClearAllPoints(); p.shadow:SetPoint("CENTER", 0, -1)
    p.ring:SetAllPoints(); p.ring:SetVertexColor(col[1], col[2], col[3], 1)
    p.inner:ClearAllPoints(); p.inner:SetPoint("CENTER"); p.inner:SetSize(size - 4, size - 4)
    p.inner:SetVertexColor(C.bg[1], C.bg[2], C.bg[3], 0.95)
    p.icon:ClearAllPoints(); p.icon:SetPoint("CENTER"); p.icon:SetSize(size * 0.55, size * 0.55)
    p.icon:SetTexture(UI.MEDIA .. (n.icon or "star"))
    p.icon:SetVertexColor(col[1], col[2], col[3], 1)
    p.label:SetText(n.title or "")
    p.pill:SetSize((p.label:GetStringWidth() or 40) + 12, 16)
    p.pill.bg:SetColor(C.bg[1], C.bg[2], C.bg[3], 0.88)
    p.pill:ClearAllPoints(); p.pill:SetPoint("LEFT", p, "RIGHT", 3, 0)
    p.labelOn = onMap and (n.label or N:Config().labels) or false
    p.pill:SetShown(p.labelOn)
end

---------------------------------------------------------------------------
-- Carte du monde
---------------------------------------------------------------------------
local mapPins = {}
function UI:HideMapNotes() for _, p in ipairs(mapPins) do p:Hide() end end
function UI:DrawMapNotes(cv, mapID, w, h)
    if not WK:FeatureOn("maplayers") then return end
    local size = math.max(11 * UI.MapIconScale(), (N:Config().size or 18) * ((w / 1000) * UI.MapIconScale()) * 1.0) * UI.MapIconSize()
    local lvl = (UI.mapBase or cv:GetFrameLevel() or 1) + 30
    for i, n in ipairs(N:ForMap(mapID)) do
        local p = mapPins[i]
        if not p then p = makePin(cv); p.wk = true; mapPins[i] = p end
        if p:GetParent() ~= cv then p:SetParent(cv) end
        paintPin(p, n, size, true)
        p:SetFrameLevel(lvl)
        p:ClearAllPoints()
        p:SetPoint("CENTER", cv, "TOPLEFT", n.x * w, -n.y * h)
        p:Show()
    end
end

-- Pose : Alt + clic (ou Ctrl + clic) sur la carte du monde
local function placeKeyDown()
    local k = N:Config().place
    if k == "ctrl" then return IsControlKeyDown() and not IsAltKeyDown() end
    if k == "shiftalt" then return IsAltKeyDown() and IsShiftKeyDown() end
    return IsAltKeyDown() and not IsShiftKeyDown()
end
local hooked
local function hookMap()
    if hooked or not (WorldMapFrame and WorldMapFrame.ScrollContainer) then return end
    hooked = true
    WorldMapFrame.ScrollContainer:HookScript("OnMouseUp", function(sc, button)
        if button ~= "LeftButton" or not placeKeyDown() or not WK:FeatureOn("maplayers") then return end
        local mapID = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
        if not mapID or not sc.GetNormalizedCursorPosition then return end
        local x, y = sc:GetNormalizedCursorPosition()
        if not x or x < 0 or x > 1 or y < 0 or y > 1 then return end
        UI:EditMapNote({ map = mapID, x = x, y = y, icon = "star", color = "blue", mini = true })
    end)
end
WK:On("PLAYER_LOGIN", hookMap)
WK:On("ADDON_LOADED", function(name) if name == "Blizzard_WorldMap" then hookMap() end end)

---------------------------------------------------------------------------
-- Minicarte : notes « aussi sur la minicarte » autour du joueur
---------------------------------------------------------------------------
local holder, miniPins = nil, {}
local viewRadius = UI.MiniViewRadius -- aide commune de la minicarte (UI/MapPins.lua)
local function updateMini()
    for _, p in ipairs(miniPins) do p:Hide() end
    if not WK:FeatureOn("maplayers") or not Minimap:IsVisible() then return end
    local list = N:List()
    if #list == 0 then return end
    local pl = WK.modules.Guide:PlayerPos()
    if not (pl and pl.cont) then return end
    local radius = viewRadius()
    local limit = radius * 0.92
    local half = Minimap:GetWidth() / 2
    local rotate = GetCVar and GetCVar("rotateMinimap") == "1"
    local facing = rotate and GetPlayerFacing and GetPlayerFacing() or nil
    local cs, sn = facing and math.cos(facing) or 1, facing and math.sin(facing) or 0
    local size = math.max(12, (N:Config().size or 18) * 0.8)
    local k = 0
    for _, n in ipairs(list) do
        if n.mini ~= false and n.cont == pl.cont and n.wx then
            -- monde : x vers le nord, y vers l'ouest
            local dy, dx = n.wx - pl.wx, -(n.wy - pl.wy)
            if dx * dx + dy * dy < limit * limit then
                if facing then dx, dy = dx * cs + dy * sn, -dx * sn + dy * cs end
                k = k + 1
                local p = miniPins[k]
                if not p then p = makePin(holder); p:EnableMouse(true); miniPins[k] = p end
                paintPin(p, n, size, false)
                p:ClearAllPoints()
                p:SetPoint("CENTER", Minimap, "CENTER", dx / radius * half, dy / radius * half)
                p:Show()
            end
        end
    end
end
WK:On("PLAYER_LOGIN", function()
    C_Timer.After(2, function()
        if not Minimap or holder then return end
        holder = CreateFrame("Frame", "WarbandKeeperMapNotes", Minimap)
        holder:SetAllPoints(Minimap)
        holder:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 5)
        holder.acc = 0
        holder:SetScript("OnUpdate", function(s, el)
            s.acc = s.acc + el
            if s.acc < 0.15 then return end
            s.acc = 0
            updateMini()
        end)
    end)
end)

function UI:RefreshMapNotes()
    if holder then updateMini() end
    if WK.modules.Guide.Redraw then WK.modules.Guide.Redraw() end
    if UI.pages and UI.pages.qol and UI.pages.qol.RefreshNotesList then UI.pages.qol:RefreshNotesList() end
end

---------------------------------------------------------------------------
-- Fenêtre de pose et de modification
---------------------------------------------------------------------------
local ed
local function buildEditor()
    local f = CreateFrame("Frame", "WarbandKeeperMapNoteEditor", UIParent)
    f:SetSize(320, 452)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    UI:Panel(f, 14, C.bg, C.border)
    if UISpecialFrames then table.insert(UISpecialFrames, "WarbandKeeperMapNoteEditor") end
    f.title = UI:Text(f, 14)
    f.title:SetPoint("TOPLEFT", 16, -14)
    f.where = UI:Text(f, 10, C.muted)
    f.where:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)
    local function head(text, y)
        local h = UI:Text(f, 10, C.muted)
        h:SetPoint("TOPLEFT", 16, y)
        h:SetText(UI:Upper(T(text)))
    end
    -- icônes
    head("Icône", -56)
    f.icons = {}
    for i, name in ipairs(N.ICONS) do
        local b = CreateFrame("Button", nil, f)
        b:SetSize(28, 28)
        b:SetPoint("TOPLEFT", 16 + (i - 1) * 32, -72)
        b.edge = UI:Rounded(b, 7, 0, "BACKGROUND", 1)
        b.bg = UI:Rounded(b, 6, 1, "BACKGROUND", 2)
        b.tex = UI:Icon(b, name, 15, nil, "ARTWORK")
        b.tex:SetPoint("CENTER")
        b:SetScript("OnClick", function() f.data.icon = name; f:Paint() end)
        b.name = name
        f.icons[i] = b
    end
    -- couleurs
    head("Couleur", -112)
    f.colors = {}
    for i, c in ipairs(N.COLORS) do
        local b = CreateFrame("Button", nil, f)
        b:SetSize(22, 22)
        b:SetPoint("TOPLEFT", 16 + (i - 1) * 28, -128)
        b.ring = UI:Icon(b, "circle", 22, nil, "BACKGROUND")
        b.ring:SetPoint("CENTER")
        b.dot = UI:Icon(b, "circle", 16, nil, "ARTWORK")
        b.dot:SetPoint("CENTER")
        b:SetScript("OnClick", function() f.data.color = c.key; f:Paint() end)
        b.key = c.key
        f.colors[i] = b
    end
    -- titre et texte
    head("Titre", -162)
    f.name = UI:Input(f, 288, 30, T("Titre de la note"))
    f.name:SetPoint("TOPLEFT", 16, -178)
    f.name.onEnter = function() f:Save() end
    head("Note", -218)
    local box = CreateFrame("Frame", nil, f)
    box:SetPoint("TOPLEFT", 16, -234)
    box:SetSize(288, 70)
    UI:Panel(box, 10, C.surface, C.border)
    local te = CreateFrame("EditBox", nil, box)
    te:SetMultiLine(true)
    te:SetAutoFocus(false)
    te:SetMaxLetters(400)
    te:SetFont(UI.FONT, 12, "")
    te:SetTextColor(unpack(C.text))
    te:SetPoint("TOPLEFT", 10, -8)
    te:SetPoint("BOTTOMRIGHT", -10, 8)
    te:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    box:EnableMouse(true)
    box:SetScript("OnMouseDown", function() te:SetFocus() end)
    f.text = te
    -- options
    f.miniT = UI:Toggle(f, function() return f.data and f.data.mini ~= false end, function(v) f.data.mini = v end)
    UI:SettingRow(f, -312, "Aussi sur la minicarte", nil, f.miniT, 60)
    f.labelT = UI:Toggle(f, function() return f.data and f.data.label end, function(v) f.data.label = v end)
    UI:SettingRow(f, -350, "Nom toujours affiché", nil, f.labelT, 60)
    -- boutons
    f.save = UI:Button(f, "Enregistrer", 104, 30, "primary")
    f.save:SetPoint("BOTTOMRIGHT", -16, 16)
    f.save:SetScript("OnClick", function() f:Save() end)
    f.cancel = UI:Button(f, "Annuler", 80, 30, "secondary")
    f.cancel:SetPoint("RIGHT", f.save, "LEFT", -8, 0)
    f.cancel:SetScript("OnClick", function() f:Hide() end)
    f.del = UI:Button(f, "Supprimer", 88, 30, "danger")
    f.del:SetPoint("BOTTOMLEFT", 16, 16)
    f.del:SetScript("OnClick", function()
        if f.data and f.data.id then N:Delete(f.data.id) end
        f:Hide()
    end)

    function f:Paint()
        local d = self.data
        local r1, g1, b1 = UI:Accent()
        local col = N:Color(d.color)
        for _, b in ipairs(self.icons) do
            local on = b.name == d.icon
            b.edge:SetColor(unpack(on and { r1, g1, b1, 1 } or C.border))
            b.bg:SetColor(unpack(on and C.surface2 or C.surface))
            b.tex:SetVertexColor(unpack(on and col or C.muted))
        end
        for _, b in ipairs(self.colors) do
            local c = N:Color(b.key)
            b.dot:SetVertexColor(c[1], c[2], c[3], 1)
            local on = b.key == d.color
            b.ring:SetVertexColor(unpack(on and C.text or C.bg))
        end
        self.miniT:Refresh(); self.labelT:Refresh()
    end
    function f:Save()
        local d = self.data
        -- note supprimée ailleurs pendant qu'on la modifiait : on ferme sans la recréer
        if d.id and not N:Get(d.id) then self:Hide() return end
        d.title = self.name:GetText()
        d.text = self.text:GetText()
        N:Save(d)
        self:Hide()
    end
    return f
end

-- Ouvre la fenêtre pour une note existante (modifier) ou nouvelle (sans id), près de la souris
function UI:EditMapNote(note)
    ed = ed or buildEditor()
    local d = {}
    for k, v in pairs(note) do d[k] = v end
    ed.data = d
    ed.title:SetText(d.id and T("Modifier la note") or T("Nouvelle note"))
    ed.where:SetText(N:ZoneName(d.map) .. "  ·  " .. N:Coords(d))
    ed.name:SetText(d.title or "")
    ed.text:SetText(d.text or "")
    ed.del:SetShown(d.id ~= nil)
    ed:Paint()
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    ed:ClearAllPoints()
    ed:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s + 24, y / s + 40)
    ed:Show()
    if not d.id then ed.name.edit:SetFocus() end
end
