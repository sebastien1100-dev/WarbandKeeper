local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors

local M = WK:NewModule("MinimapButton")

local function position(b)
    local cfg = WK.DB.global.settings.ui.minimap
    local a = math.rad(cfg.angle or 215)
    local r = (Minimap:GetWidth() / 2) + 8
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local function onDragUpdate(b)
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local s = Minimap:GetEffectiveScale()
    cx, cy = cx / s, cy / s
    WK.DB.global.settings.ui.minimap.angle = math.deg(math.atan2(cy - my, cx - mx))
    position(b)
end

function M:Create()
    if self.button then return self.button end
    local b = CreateFrame("Button", "WarbandKeeperMinimapButton", Minimap)
    self.button = b
    b:SetSize(32, 32)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")

    -- Anneau d'accent + disque sombre + logo : entièrement rond.
    local ring = UI:Icon(b, "circle", 32, nil, "BACKGROUND")
    ring:SetPoint("CENTER")
    local disc = UI:Icon(b, "circle", 28, C.sidebar, "BORDER")
    disc:SetPoint("CENTER")
    local logo = UI:Icon(b, "logo", 18, nil, "ARTWORK")
    logo:SetPoint("CENTER")

    local function refresh()
        local r, g, bl = UI:Accent()
        ring:SetVertexColor(r, g, bl, b.hover and 1 or 0.75)
        if b.hover then logo:SetVertexColor(1, 1, 1, 1) else logo:SetVertexColor(r, g, bl, 1) end
    end
    UI:OnAccent(refresh, "window") -- bouton refait par UI:Rebuild

    b:SetScript("OnClick", function(_, button)
        if button == "RightButton" then UI:ToggleWindow("options") else UI:ToggleWindow() end
    end)
    b:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", onDragUpdate) end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    b:SetScript("OnEnter", function(self)
        self.hover = true; refresh()
        WK.UI:TooltipOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Warband Keeper")
        local total = 0
        for _, c in pairs(WK.DB.global.characters) do total = total + (c.money or 0) end
        GameTooltip:AddDoubleLine(WK.T("Or du compte"), WK:FormatMoney(total), 0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(WK.T("|cffffffffClic gauche|r : ouvrir / fermer"), 0.6, 0.6, 0.6)
        GameTooltip:AddLine(WK.T("|cffffffffClic droit|r : options"), 0.6, 0.6, 0.6)
        GameTooltip:AddLine(WK.T("|cffffffffGlisser|r : déplacer le bouton"), 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self) self.hover = false; refresh(); GameTooltip:Hide() end)

    position(b)
    return b
end

function M:Update()
    local hide = WK.DB.global.settings.ui.minimap.hide
    if hide then
        if self.button then self.button:Hide() end
    else
        self:Create():Show()
    end
end

function M:OnLogin() self:Update() end

-- Menu "compartiment d'addons" du client (si disponible).
function WarbandKeeper_OnAddonCompartmentClick() UI:ToggleWindow() end

---------------------------------------------------------------------------
-- Raccourci « Warband Keeper » dans le menu du jeu (Échap), juste au-dessus d'EllesmereUI s'il est là,
-- sinon au-dessus d'« Add-ons » ; réglage settings.ui.gameMenu (Options > Général > Fenêtre).
-- Menu du jeu moderne : GameMenuFrame:AddButton pendant InitButtons, ordre par layoutIndex.
---------------------------------------------------------------------------
local function plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function gameMenuOn() return WK.DB.global.settings.ui.gameMenu ~= false end
local gmBtn -- notre bouton du menu (bouton recyclé du menu du jeu)
local function storeButton(menu)
    for b in menu.buttonPool:EnumerateActive() do
        local t = b.GetText and b:GetText()
        if t and BLIZZARD_STORE and t == BLIZZARD_STORE then return b end
    end
end
-- Habillage : quand les boutons voisins sont habillés (EllesmereUI : textures du bouton masquées, fond
-- sombre et fin liseré), le nôtre prend le même style ; sinon il garde celui du jeu. Le bouton vient de la
-- réserve du menu (recyclé pour d'autres entrées) : nos textures sont cachées sur les autres boutons.
-- Couleurs d'EllesmereUI (son code public : réglage du fond des boutons du menu, gris 0,1 à 80 % par défaut,
-- posé dans un cadre en retrait de 2 px, surbrillance blanche à 10 %). Avant, notre fond était un gris plus
-- sombre et presque opaque posé SOUS le fond qu'EllesmereUI ajoute déjà au bouton recyclé : le bouton sortait
-- plus foncé que ses voisins.
local function euiButtonColor()
    local db = _G.EllesmereUIDB
    local c = db and type(db.popupMenuButtonBackgroundColor) == "table" and db.popupMenuButtonBackgroundColor
    if c and c.r then return c.r, c.g, c.b, c.a == nil and 0.8 or c.a end
    return 0.1, 0.1, 0.1, 0.8
end
-- fond déjà posé par EllesmereUI sur ce bouton (cadre enfant en retrait qui n'est pas à nous)
local function foreignInset(b)
    for _, ch in ipairs({ b:GetChildren() }) do
        if not ch.wkOwn and ch.GetRegions then
            for _, r in ipairs({ ch:GetRegions() }) do
                if r.IsObjectType and r:IsObjectType("Texture") and r:GetDrawLayer() == "BACKGROUND" then return ch end
            end
        end
    end
end
local function skinPieces(b)
    if b.wkSkin then return b.wkSkin end
    local k = {}
    k.inset = _G.CreateFrame("Frame", nil, b)
    k.inset.wkOwn = true
    k.inset:SetPoint("TOPLEFT", 2, -2); k.inset:SetPoint("BOTTOMRIGHT", -2, 2)
    k.inset:SetFrameLevel(b:GetFrameLevel())
    k.bg = k.inset:CreateTexture(nil, "BACKGROUND", nil, -6); k.bg:SetAllPoints()
    k.edges = {}
    for i, pt in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local e = k.inset:CreateTexture(nil, "BORDER", nil, 7)
        e:SetColorTexture(1, 1, 1, 0.06)
        e:SetPoint(pt[1], k.inset, pt[1]); e:SetPoint(pt[2], k.inset, pt[2])
        if pt[3] then e:SetHeight(1) else e:SetWidth(1) end
        k.edges[i] = e
    end
    -- liseré : celui d'EllesmereUI s'il le donne (même réglage que ses boutons), sinon le nôtre
    local border = _G.EllesmereUI and _G.EllesmereUI._applyBlizzardConfiguredBorder
    if border and pcall(border, k.inset, "popupMenuButton", 1) then
        for _, e in ipairs(k.edges) do e:Hide() end
        k.edges = {}
    end
    k.hl = b:CreateTexture(nil, "HIGHLIGHT"); k.hl:SetAllPoints(k.inset); k.hl:SetColorTexture(1, 1, 1, 0.1)
    k.own = { [k.hl] = true }
    b.wkSkin = k
    return k
end
local function showSkin(b, on)
    local k = b.wkSkin
    if not k then return end
    k.inset:SetShown(on); k.hl:SetShown(on)
    if on then k.bg:SetColorTexture(euiButtonColor()) end
end
local function skinned(b)
    local l = b and rawget(b, "Left")
    if type(l) ~= "table" and b and b.GetNormalTexture then l = b:GetNormalTexture() end
    return type(l) == "table" and l.GetAlpha and (l:GetAlpha() or 1) < 0.05
end
local function skinGameMenuButton(menu, btn)
    if not (menu and menu.buttonPool and btn) then return end
    local ref
    for b in menu.buttonPool:EnumerateActive() do
        if b ~= btn then
            if b.wkSkin then showSkin(b, false) end
            if not ref and skinned(b) then ref = b end
        end
    end
    if not ref then showSkin(btn, false); btn:SetText("Warband Keeper") return end
    -- bouton recyclé déjà habillé par EllesmereUI : son fond suffit, le nôtre en plus l'assombrissait
    local theirs = foreignInset(btn)
    local k = skinPieces(btn)
    showSkin(btn, not theirs)
    for _, r in ipairs({ btn:GetRegions() }) do
        if r.IsObjectType and r:IsObjectType("Texture") and not k.own[r] then r:SetAlpha(0) end
    end
    for _, key in ipairs({ "Left", "Middle", "Right" }) do
        local t = rawget(btn, key)
        if type(t) == "table" and t.SetAlpha then t:SetAlpha(0) end
    end
    local fs, rfs = btn.GetFontString and btn:GetFontString(), ref.GetFontString and ref:GetFontString()
    if fs and rfs and rfs.GetFont then
        local font, size, flags = rfs:GetFont()
        if font then fs:SetFont(font, size, flags or "") end
        -- couleur du texte des voisins (réglage d'EllesmereUI s'il le donne)
        local tc = _G.EllesmereUI and _G.EllesmereUI._getPopupMenuButtonTextColor
        local ok, r, g, bl = false
        if tc then ok, r, g, bl = pcall(tc) end
        if ok and r then fs:SetTextColor(r, g, bl, 1) else fs:SetTextColor(1, 1, 1, 1) end
        -- nom de marque en deux tons, comme « Naowh Forever » et « EllesmereUI » : « Keeper » à l'accent
        btn:SetText("Warband " .. UI:Hex({ UI:Accent() }) .. "Keeper|r")
    end
end
local function addGameMenuButton(menu)
    gmBtn = nil
    if not gameMenuOn() or not (menu and menu.AddButton) then return end
    local btn = menu:AddButton("Warband Keeper", function()
        if HideUIPanel then HideUIPanel(menu) else menu:Hide() end
        UI:ToggleWindow()
    end)
    if not btn then return end
    gmBtn = btn
    -- place : juste avant « Add-ons » ; EllesmereUI, qui pose son bouton sous la Boutique hors de la liste
    -- du menu, est remis sous le nôtre après la mise en page (voir plus bas)
    local target, eui = nil, _G.EllesmereUI_GameMenuButton
    if menu.buttonPool and menu.buttonPool.EnumerateActive then
        local addons = ADDONS and plain(ADDONS) or "Add-ons"
        for b in menu.buttonPool:EnumerateActive() do
            if b ~= btn and b.GetText then
                local t = plain(b:GetText())
                if t:find("EllesmereUI", 1, true) then target = b break end
                if t == addons and not target then target = b end
            end
        end
        if eui and eui:IsShown() then
            local store = storeButton(menu)
            if store and store.layoutIndex then target = nil; btn.layoutIndex = store.layoutIndex + 0.5 end
        end
    end
    if target and target.layoutIndex then btn.layoutIndex = target.layoutIndex - 0.5 end
    if menu.MarkDirty then menu:MarkDirty() end
    -- habillage : maintenant, puis une image plus tard (EllesmereUI habille les boutons à l'ouverture du menu)
    skinGameMenuButton(menu, btn)
    if C_Timer and C_Timer.After then C_Timer.After(0, function() if gmBtn == btn then skinGameMenuButton(menu, btn) end end) end
end
-- Après la mise en page (et après celle d'EllesmereUI) : notre bouton prend la place du sien, sous la
-- Boutique, et le sien passe juste sous le nôtre ; les autres boutons ne bougent pas
local function swapWithEllesmere()
    local menu, eui = GameMenuFrame, _G.EllesmereUI_GameMenuButton
    if not (gmBtn and gmBtn:IsShown() and eui and eui:IsShown() and menu and menu.buttonPool) then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local store = storeButton(menu)
    local p, rel = eui:GetPoint(1)
    if not (store and p and rel == store) then return end
    gmBtn:ClearAllPoints(); gmBtn:SetPoint("TOP", store, "BOTTOM", 0, -12)
    eui:ClearAllPoints(); eui:SetPoint("TOP", gmBtn, "BOTTOM", 0, -4)
end
local hooked
local function hookGameMenu()
    if hooked or not (GameMenuFrame and GameMenuFrame.InitButtons) then return end
    hooked = true
    -- tout de suite : l'habillage d'EllesmereUI (à l'ouverture du menu) prend ainsi notre bouton aussi
    hooksecurefunc(GameMenuFrame, "InitButtons", function(menu) addGameMenuButton(menu) end)
    if GameMenuFrame.Layout then
        hooksecurefunc(GameMenuFrame, "Layout", function()
            swapWithEllesmere()
            if C_Timer and C_Timer.After then C_Timer.After(0, swapWithEllesmere) end
        end)
    end
end
WK:On("PLAYER_LOGIN", hookGameMenu)
