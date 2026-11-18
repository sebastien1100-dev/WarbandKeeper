local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Fiche de personnage : page « charsheet » de la fenêtre (hors barre latérale, Persos y reste en
-- surbrillance), ouverte au clic sur un perso (pages Persos et Résumé), pour n'importe quel perso du compte.
-- Une seule page qui défile : à gauche Équipement (emplacements autour du portrait : cadre à la couleur de
-- qualité, niveau d'objet, point = enchanté ; armure, durabilité, sacs) puis Réputations (les plus avancées,
-- « Tout voir ») ; à droite Stats (barre colorée pour ce qui compte pour la classe, combat, résistances)
-- puis Métiers. Niveau moyen de l'équipement dans l'en-tête.
-- Données : Modules/Gear.lua (relevées à chaque connexion du perso), c.professions.
local SQ = 34
local sheet

local QUALITY = { [0] = { 0.62, 0.62, 0.62 }, { 1, 1, 1 }, { 0.12, 1, 0 }, { 0, 0.44, 0.87 }, { 0.64, 0.21, 0.93 }, { 1, 0.5, 0 }, { 0.9, 0.8, 0.5 } }
-- emplacements : n° du jeu, nom, texture vide
local LEFT = { { 1, "Tête", "Head" }, { 2, "Cou", "Neck" }, { 3, "Épaules", "Shoulder" }, { 15, "Dos", "Chest" },
    { 5, "Torse", "Chest" }, { 4, "Chemise", "Shirt" }, { 19, "Tabard", "Tabard" }, { 9, "Poignets", "Wrists" } }
local RIGHT = { { 10, "Mains", "Hands" }, { 6, "Taille", "Waist" }, { 7, "Jambes", "Legs" }, { 8, "Pieds", "Feet" },
    { 11, "Doigt", "Finger" }, { 12, "Doigt", "Finger" }, { 13, "Bijou", "Trinket" }, { 14, "Bijou", "Trinket" } }
local WEAPONS = { { 16, "Main droite", "MainHand" }, { 17, "Main gauche", "SecondaryHand" }, { 18, "Distance", "Ranged" } }
-- pour la moyenne : chemise et tabard n'en sont pas
local NO_AVG = { [4] = true, [19] = true }

-- Ce que chaque classe tire de ses caractéristiques (0 à 1) : barre colorée à partir de 0,5
local WEIGHTS = {
    WARRIOR = { str = 1, agi = 0.6, sta = 0.8, int = 0, spi = 0.1 }, ROGUE = { str = 0.4, agi = 1, sta = 0.7, int = 0, spi = 0.1 },
    HUNTER = { str = 0.1, agi = 1, sta = 0.6, int = 0.5, spi = 0.2 }, MAGE = { str = 0, agi = 0, sta = 0.6, int = 1, spi = 0.5 },
    PRIEST = { str = 0, agi = 0, sta = 0.5, int = 1, spi = 0.9 }, WARLOCK = { str = 0, agi = 0, sta = 0.9, int = 0.9, spi = 0.4 },
    PALADIN = { str = 0.9, agi = 0.3, sta = 0.7, int = 0.7, spi = 0.3 }, SHAMAN = { str = 0.6, agi = 0.5, sta = 0.6, int = 0.8, spi = 0.4 },
    DRUID = { str = 0.6, agi = 0.6, sta = 0.6, int = 0.8, spi = 0.5 },
}
local RACE = { Human = "humain", Dwarf = "nain", NightElf = "elfe de la nuit", Gnome = "gnome", Orc = "orc",
    Scourge = "mort-vivant", Undead = "mort-vivant", Tauren = "tauren", Troll = "troll", BloodElf = "elfe de sang", Draenei = "draeneï" }
local STANDING = { "Haï", "Hostile", "Inamical", "Neutre", "Amical", "Honoré", "Révéré", "Exalté" }
local STANDING_COL = { { 0.8, 0.13, 0.13 }, { 1, 0, 0 }, { 0.93, 0.4, 0.13 }, { 1, 1, 0 }, { 0, 0.8, 0 }, { 0, 0.8, 0.5 }, { 0, 0.6, 0.8 }, { 0.6, 0.4, 1 } }

local function itemData(link)
    if type(link) ~= "string" then return end
    local id = tonumber(link:match("item:(%d+)"))
    local enchant = tonumber(link:match("item:%d+:(%d*)") or "") or 0
    local name, _, quality, ilvl = WK.GetItemInfo(link)
    if C_Item and C_Item.GetDetailedItemLevelInfo then
        local ok, v = pcall(C_Item.GetDetailedItemLevelInfo, link)
        if ok and type(v) == "number" and v > 0 then ilvl = v end
    end
    if not name and id and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
    local icon = id and ((C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or (GetItemIcon and GetItemIcon(id)))
    return { id = id, name = name, quality = quality, ilvl = ilvl, icon = icon, enchant = enchant > 0 }
end

-- Niveau moyen de l'équipement (deux mains : compte double, comme le jeu)
local function averageIlvl(gear)
    local total, n = 0, 0
    for slot = 1, 18 do
        if not NO_AVG[slot] then
            local d = itemData(gear and gear[slot])
            if d and d.ilvl then total = total + d.ilvl; n = n + 1 end
        end
    end
    if gear and gear[16] and not gear[17] then
        local d = itemData(gear[16])
        if d and d.ilvl then total = total + d.ilvl; n = n + 1 end
    end
    if n == 0 then return nil end
    return total / 16
end

local function fmt(v, pct)
    if v == nil then return "-" end
    if pct then return (string.format("%.1f %%", v):gsub("%.", ",")) end
    local n = tostring(math.floor(v + 0.5))
    return (n:reverse():gsub("(%d%d%d)(%d)", "%1 %2"):reverse())
end

---------------------------------------------------------------------------
local function slotButton(parent, side)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(150, SQ)
    b.box = CreateFrame("Frame", nil, b)
    b.box:SetSize(SQ, SQ)
    b.edge = UI:Rounded(b.box, 7, 0, "BACKGROUND", 1)
    b.bg = UI:Rounded(b.box, 6, 1.5, "BACKGROUND", 2)
    b.icon = b.box:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 2, -2); b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.lvl = UI:Text(b.box, 10, nil, "OVERLAY")
    b.lvl:SetPoint("BOTTOMRIGHT", -2, 2)
    b.lvl:SetShadowOffset(1, -1)
    b.dot = UI:Icon(b.box, "circle", 7, nil, "OVERLAY")
    b.dot:SetPoint("TOPLEFT", 3, -3)
    b.dot:SetVertexColor(0.38, 0.71, 1)
    b.name = UI:Text(b, 11)
    b.sub = UI:Text(b, 10, C.dim)
    if side == "right" then
        b.box:SetPoint("RIGHT")
        b.name:SetPoint("BOTTOMRIGHT", b.box, "LEFT", -7, 1); b.name:SetJustifyH("RIGHT")
        b.sub:SetPoint("TOPRIGHT", b.box, "LEFT", -7, -1); b.sub:SetJustifyH("RIGHT")
    elseif side == "weapon" then
        b:SetSize(80, SQ + 30)
        b.box:SetPoint("TOP")
        b.name:SetPoint("TOP", b.box, "BOTTOM", 0, -3); b.name:SetJustifyH("CENTER")
        b.sub:SetPoint("TOP", b.name, "BOTTOM", 0, -1); b.sub:SetJustifyH("CENTER")
    else
        b.box:SetPoint("LEFT")
        b.name:SetPoint("BOTTOMLEFT", b.box, "RIGHT", 7, 1)
        b.sub:SetPoint("TOPLEFT", b.box, "RIGHT", 7, -1)
    end
    b:SetScript("OnEnter", function(s)
        if not s.link then return end
        UI:TooltipOwner(s, "ANCHOR_RIGHT")
        if not pcall(GameTooltip.SetHyperlink, GameTooltip, s.link) then GameTooltip:SetText(s.link) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(s)
        if s.link and IsShiftKeyDown() and WK.InsertChatLink then WK.InsertChatLink(s.link) end
    end)
    function b:Set(slot, label, empty, link)
        self.link = link
        local d = itemData(link)
        self.name:SetText(T(label))
        if d then
            local q = QUALITY[d.quality or 1] or QUALITY[1]
            self.edge:SetColor(q[1], q[2], q[3], 1)
            self.icon:SetTexture(d.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            self.icon:SetDesaturated(false); self.icon:SetAlpha(1)
            self.name:SetTextColor(q[1], q[2], q[3])
            self.lvl:SetText(d.ilvl and tostring(d.ilvl) or "")
            self.sub:SetText(d.ilvl and string.format(T("niv. %d"), d.ilvl) or "")
            self.dot:SetShown(d.enchant)
        else
            self.edge:SetColor(unpack(C.border))
            self.icon:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-" .. empty)
            self.icon:SetDesaturated(true); self.icon:SetAlpha(0.45)
            self.name:SetTextColor(unpack(C.dim))
            self.lvl:SetText("")
            self.sub:SetText(T("vide"))
            self.dot:Hide()
        end
        self.bg:SetColor(unpack(C.surface))
    end
    return b
end

local function kpi(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(100, 44)
    UI:Panel(f, 9, C.surface, C.border)
    f.v = UI:Text(f, 14)
    f.v:SetPoint("TOP", 0, -7)
    f.l = UI:Text(f, 10, C.dim)
    f.l:SetPoint("BOTTOM", 0, 7)
    return f
end

local SIDE_W, COL_GAP = 290, 12
local SLOT_W, SLOT_STEP = 124, SQ + 15
local REP_SHORT = 6

local function build(parent)
    local f = CreateFrame("Frame", "WarbandKeeperCharSheet", parent)
    f:SetAllPoints()
    -- en-tête : icône de classe dans un anneau, nom, classe et niveau, niveau moyen, retour à Persos
    -- retour à Persos à gauche, puis l'icône de classe
    f.back = UI:Button(f, "Persos", nil, 26, "ghost", "back")
    f.back:SetPoint("TOPLEFT", 2, -16)
    f.back:SetScript("OnClick", function() UI:ShowPage("characters") end)
    f.ring = UI:Icon(f, "ring", 50, nil, "ARTWORK")
    f.ring:SetPoint("LEFT", f.back, "RIGHT", 12, 0)
    f.cls = f:CreateTexture(nil, "ARTWORK", nil, -1)
    f.cls:SetSize(40, 40)
    f.cls:SetPoint("CENTER", f.ring)
    if f.CreateMaskTexture then
        local m = f:CreateMaskTexture()
        m:SetTexture(UI.MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        m:SetAllPoints(f.cls)
        f.cls:AddMaskTexture(m)
    end
    f.title = UI:Text(f, 17)
    f.title:SetPoint("TOPLEFT", f.ring, "TOPRIGHT", 12, -6)
    f.sub = UI:Text(f, 11, C.muted)
    f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)
    f.score = UI:Text(f, 22)
    f.score:SetPoint("TOPRIGHT", -8, -8)
    f.scoreL = UI:Text(f, 10, C.dim)
    f.scoreL:SetPoint("TOPRIGHT", f.score, "BOTTOMRIGHT", 0, -2)
    f.scoreL:SetText(T("niv. moyen"))

    -- tout le reste défile : à gauche Équipement puis Réputations, à droite Stats puis Métiers
    -- onglets sous l'en-tête : Fiche, Talents, BiS (soulignés, comme ceux des donjons)
    f.tab = "sheet"
    f.tabs = {}
    f.tabLine = f:CreateTexture(nil, "ARTWORK")
    f.tabLine:SetTexture("Interface\\Buttons\\WHITE8X8")
    f.tabLine:SetVertexColor(C.border[1], C.border[2], C.border[3], 1)
    f.tabLine:SetHeight(1)
    f.tabLine:SetPoint("TOPLEFT", 0, -90); f.tabLine:SetPoint("TOPRIGHT", 0, -90)
    local prev
    for _, t in ipairs({ { "sheet", "Fiche" }, { "talents", "Talents" }, { "bis", "BiS" } }) do
        local b = CreateFrame("Button", nil, f)
        b:SetHeight(26)
        b.label = UI:Text(b, 12)
        b.label:SetPoint("CENTER", 0, 1)
        b.label:SetText(T(t[2]))
        b:SetWidth(b.label:GetStringWidth() + 28)
        b.under = b:CreateTexture(nil, "OVERLAY")
        b.under:SetTexture("Interface\\Buttons\\WHITE8X8")
        b.under:SetHeight(2)
        b.under:SetPoint("BOTTOMLEFT", 0, -1); b.under:SetPoint("BOTTOMRIGHT", 0, -1)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", 6, -64) end
        prev = b
        function b:Paint()
            local sel = f.tab == t[1]
            local r, g, bl = UI:Accent()
            if sel then self.label:SetTextColor(unpack(C.text)) else self.label:SetTextColor(r, g, bl, self.hover and 1 or 0.85) end
            self.under:SetVertexColor(r, g, bl, 1)
            self.under:SetShown(sel)
        end
        b:SetScript("OnEnter", function(s) s.hover = true; s:Paint() end)
        b:SetScript("OnLeave", function(s) s.hover = false; s:Paint() end)
        b:SetScript("OnClick", function() f.tab = t[1]; f:Refresh() end)
        f.tabs[t[1]] = b
    end

    local sc = UI:Scroll(f)
    sc:SetPoint("TOPLEFT", 0, -98)
    sc:SetPoint("BOTTOMRIGHT")
    f.sc = sc
    local root = sc.child

    -- Équipement
    local gear = UI:Card(root, T("Équipement"))
    f.gearCard = gear
    gear:SetHeight(46 + 8 * SLOT_STEP)
    f.slots = {}
    for i, s in ipairs(LEFT) do
        local b = slotButton(gear, "left")
        b:SetWidth(SLOT_W)
        b:SetPoint("TOPLEFT", 14, -44 - (i - 1) * SLOT_STEP)
        b.def = s
        table.insert(f.slots, b)
    end
    for i, s in ipairs(RIGHT) do
        local b = slotButton(gear, "right")
        b:SetWidth(SLOT_W)
        b:SetPoint("TOPRIGHT", -14, -44 - (i - 1) * SLOT_STEP)
        b.def = s
        table.insert(f.slots, b)
    end
    local mid = CreateFrame("Frame", nil, gear)
    mid:SetPoint("TOPLEFT", 14 + SLOT_W + 8, -44); mid:SetPoint("TOPRIGHT", -(14 + SLOT_W + 8), -44)
    mid:SetHeight(8 * SLOT_STEP - 120)
    UI:Panel(mid, 12, C.bg, C.border)
    f.mid = mid
    -- aperçu 3D du perso (perso connecté ; les autres si le jeu permet de changer de race), glisser pour tourner
    local ok, model = pcall(CreateFrame, "DressUpModel", nil, mid)
    if ok and model then
        model:SetPoint("TOPLEFT", 4, -4); model:SetPoint("BOTTOMRIGHT", -4, 4)
        model:EnableMouse(true)
        model:SetScript("OnMouseDown", function(s) s.drag = GetCursorPosition() end)
        model:SetScript("OnMouseUp", function(s) s.drag = nil end)
        model:SetScript("OnUpdate", function(s)
            if not s.drag then return end
            local x = GetCursorPosition()
            s.rot = (s.rot or 0) + (x - s.drag) * 0.01
            s.drag = x
            if s.SetFacing then s:SetFacing(s.rot) end
        end)
        model:EnableMouseWheel(true)
        model:SetScript("OnMouseWheel", function(s, d)
            s.zoom = math.max(0, math.min(0.7, (s.zoom or 0) + d * 0.1))
            if s.SetPortraitZoom then s:SetPortraitZoom(s.zoom) end
        end)
        model:Hide()
        f.model = model
    end
    f.big = UI:Icon(mid, "ring", 78, nil, "ARTWORK")
    f.big:SetPoint("TOP", 0, -22)
    f.bigCls = mid:CreateTexture(nil, "ARTWORK", nil, -1)
    f.bigCls:SetSize(64, 64)
    f.bigCls:SetPoint("CENTER", f.big)
    if mid.CreateMaskTexture then
        local m = mid:CreateMaskTexture()
        m:SetTexture(UI.MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        m:SetAllPoints(f.bigCls)
        f.bigCls:AddMaskTexture(m)
    end
    f.spec = UI:Text(mid, 13)
    f.spec:SetPoint("TOP", f.big, "BOTTOM", 0, -10)
    f.seen = UI:Text(mid, 10, C.dim)
    f.seen:SetPoint("TOP", f.spec, "BOTTOM", 0, -4)
    f.kpis = {}
    for i = 1, 3 do f.kpis[i] = kpi(gear) end
    function f:PlaceKpis()
        local w = (mid:GetWidth() or 300)
        local kw = math.floor((w - 12) / 3)
        for i, k in ipairs(self.kpis) do
            k:SetWidth(kw)
            k:ClearAllPoints(); k:SetPoint("TOPLEFT", mid, "BOTTOMLEFT", (i - 1) * (kw + 6), -8)
        end
    end
    for i, s in ipairs(WEAPONS) do
        local b = slotButton(gear, "weapon")
        b:SetPoint("TOP", mid, "BOTTOM", (i - 2) * 86, -62)
        b.def = s
        table.insert(f.slots, b)
    end
    f.noGear = UI:Text(gear, 11, C.muted)
    f.noGear:SetPoint("BOTTOM", 0, 10)

    -- Réputations (sous l'équipement) : les plus avancées, « Tout voir » pour toutes, par groupe
    local reps = UI:Card(root, T("Réputations"))
    f.repCard = reps
    f.repAll = false
    f.repMore = UI:Button(reps, "Tout voir", nil, 24, "ghost")
    f.repMore:SetPoint("TOPRIGHT", -10, -9)
    f.repMore:SetScript("OnClick", function() f.repAll = not f.repAll; f:Refresh() end)

    -- Stats (colonne de droite)
    local st = UI:Card(root, T("Stats"))
    f.statCard = st
    f.hUse = UI:Text(st, 10, C.dim)
    f.hUse:SetPoint("TOPRIGHT", -14, -17)
    f.statRows = {}
    for i, k in ipairs({ { "str", "Force" }, { "agi", "Agilité" }, { "sta", "Endurance" }, { "int", "Intelligence" }, { "spi", "Esprit" } }) do
        local r = CreateFrame("Frame", nil, st)
        r:SetHeight(22)
        r:SetPoint("TOPLEFT", 14, -42 - (i - 1) * 24); r:SetPoint("TOPRIGHT", -14, -42 - (i - 1) * 24)
        r.name = UI:Text(r, 12)
        r.name:SetPoint("LEFT")
        r.name:SetText(T(k[2]))
        r.val = UI:Text(r, 12)
        r.val:SetPoint("RIGHT")
        r.val:SetJustifyH("RIGHT")
        r.bar = UI:Progress(r, 5)
        r.bar:SetPoint("LEFT", 92, 0); r.bar:SetPoint("RIGHT", -44, 0)
        r.key = k[1]
        f.statRows[i] = r
    end
    f.hCombat = UI:Text(st, 10, C.muted)
    f.hCombat:SetPoint("TOPLEFT", 14, -170)
    f.hCombat:SetText(UI:Upper(T("Combat")))
    f.combat = {}
    for i = 1, 8 do
        local r = CreateFrame("Frame", nil, st)
        r:SetHeight(19)
        r:SetPoint("TOPLEFT", 14, -188 - (i - 1) * 20); r:SetPoint("TOPRIGHT", -14, -188 - (i - 1) * 20)
        r.name = UI:Text(r, 11, C.muted)
        r.name:SetPoint("LEFT")
        r.val = UI:Text(r, 11)
        r.val:SetPoint("RIGHT")
        r.val:SetJustifyH("RIGHT")
        f.combat[i] = r
    end
    f.hRes = UI:Text(st, 10, C.muted)
    f.hRes:SetText(UI:Upper(T("Résistances")))
    f.res = UI:Text(st, 11)
    f.res:SetJustifyH("LEFT")
    if f.res.SetWordWrap then f.res:SetWordWrap(true) end
    f.statNote = UI:Text(st, 10, C.dim)
    f.statNote:SetJustifyH("LEFT")
    if f.statNote.SetWordWrap then f.statNote:SetWordWrap(true) end

    -- Métiers (sous les stats)
    local pr = UI:Card(root, T("Métiers"))
    f.profCard = pr

    -- lignes « nom, valeur à droite, barre dessous » (réputations et métiers)
    f.lrows = UI:Pool(function()
        local r = CreateFrame("Frame", nil, root)
        r:SetHeight(30)
        r.name = UI:Text(r, 12)
        r.name:SetPoint("TOPLEFT", 0, -2)
        r.right = UI:Text(r, 11, C.muted)
        r.right:SetPoint("TOPRIGHT", 0, -2)
        r.right:SetJustifyH("RIGHT")
        r.bar = UI:Progress(r, 4)
        r.bar:SetPoint("BOTTOMLEFT", 0, 5); r.bar:SetPoint("BOTTOMRIGHT", 0, 5)
        return r
    end)
    f.lheads = UI:Pool(function() return UI:Text(root, 10, C.muted) end)
    f.repEmpty = UI:Text(reps, 11, C.muted)
    f.repEmpty:SetPoint("TOPLEFT", 16, -44)
    f.profEmpty = UI:Text(pr, 11, C.muted)
    f.profEmpty:SetPoint("TOPLEFT", 16, -44)
    mid:SetScript("OnSizeChanged", function() f:PlaceKpis() end)

    -- Onglet Talents : les arbres côte à côte, chaque talent à sa place
    local tsc = UI:Scroll(f)
    tsc:SetPoint("TOPLEFT", 0, -98)
    tsc:SetPoint("BOTTOMRIGHT")
    tsc:Hide()
    f.tsc = tsc
    f.tsum = UI:Text(tsc.child, 12)
    f.tsum:SetPoint("TOPLEFT", 4, -4)
    f.tempty = UI:Text(tsc.child, 11, C.muted)
    f.tempty:SetPoint("TOPLEFT", 4, -28)
    f.trees = {}
    for i = 1, 4 do
        local tr = UI:Card(tsc.child, "")
        tr.pts = UI:Text(tr, 14)
        tr.pts:SetPoint("TOPRIGHT", -14, -12)
        tr.cells = {}
        f.trees[i] = tr
    end
    f.talentCell = function(tr, j)
        local b = tr.cells[j]
        if b then return b end
        b = CreateFrame("Button", nil, tr)
        b:SetSize(34, 34)
        b.edge = b:CreateTexture(nil, "BACKGROUND")
        b.edge:SetTexture("Interface\\Buttons\\WHITE8X8")
        b.edge:SetAllPoints()
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("TOPLEFT", 2, -2); b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        -- rang dans une petite pastille sombre, à cheval sur le coin bas droit (au-dessus des voisins)
        b.rkBox = CreateFrame("Frame", nil, b)
        b.rkBox:SetFrameLevel(b:GetFrameLevel() + 4)
        b.rkBox:SetSize(26, 14)
        b.rkBox:SetPoint("CENTER", b, "BOTTOMRIGHT", -2, 2)
        UI:Panel(b.rkBox, 7, { 0.05, 0.05, 0.06, 0.95 }, C.border)
        b.rk = b.rkBox:CreateFontString(nil, "OVERLAY")
        b.rk:SetFont(UI.FONT, 10, "")
        b.rk:SetPoint("CENTER", 0, 0)
        b:SetScript("OnEnter", function(s)
            local d = s.data
            if not d then return end
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            local done = false
            -- description complète : seulement pour le perso connecté (le jeu ne la donne que pour lui)
            if d[7] and GameTooltip.SetSpellByID then
                done = pcall(GameTooltip.SetSpellByID, GameTooltip, d[7])
                if done then GameTooltip:AddLine(string.format(T("Rang %d/%d"), d[5], d[6]), 0.62, 0.82, 0.48) end
            elseif s.mine and GameTooltip.SetTalent then done = pcall(GameTooltip.SetTalent, GameTooltip, s.tab, s.index) end
            if not done then
                GameTooltip:SetText(d[1], 1, 1, 1)
                GameTooltip:AddLine(string.format(T("Rang %d/%d"), d[5], d[6]), 0.8, 0.8, 0.8)
            end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        tr.cells[j] = b
        return b
    end

    -- Builds de talents : carte sous les arbres, une ligne par build ; clic = aperçu déplié
    f.ptrees = {}
    for i = 1, 4 do
        local tr = UI:Card(tsc.child, "")
        tr.pts = UI:Text(tr, 14)
        tr.pts:SetPoint("TOPRIGHT", -14, -12)
        tr.cells = {}
        tr:Hide()
        f.ptrees[i] = tr
    end
    f.bcard = UI:Card(tsc.child, T("Mes builds"))
    f.bcount = UI:Text(f.bcard, 11, C.muted)
    f.bcount:SetPoint("LEFT", f.bcard.title, "RIGHT", 10, 0)
    f.bsave = UI:Button(f.bcard, "Enregistrer le build actuel", nil, 26, "primary")
    f.bsave:SetPoint("TOPRIGHT", -12, -10)
    f.bimport = UI:Button(f.bcard, "Importer un code", nil, 26, "secondary")
    f.bimport:SetPoint("RIGHT", f.bsave, "LEFT", -8, 0)
    f.bempty = UI:Text(f.bcard, 11, C.muted)
    f.bempty:SetPoint("TOPLEFT", 16, -48)
    f.bempty:SetText(T("Aucun build enregistré : « Enregistrer le build actuel » garde tes talents sous un nom."))
    f.bheads = {}
    for i, h in ipairs({ "Nom", "Répartition", "Niveau", "Différences" }) do
        local t = UI:Text(f.bcard, 10, C.dim); t:SetText(UI:Upper(T(h))); f.bheads[i] = t
    end
    f.brows = UI:Pool(function()
        local r = CreateFrame("Button", nil, f.bcard)
        r:SetHeight(32)
        r.hl = r:CreateTexture(nil, "BACKGROUND")
        r.hl:SetTexture("Interface\\Buttons\\WHITE8X8")
        r.hl:SetAllPoints()
        r.line = r:CreateTexture(nil, "ARTWORK")
        r.line:SetTexture("Interface\\Buttons\\WHITE8X8")
        r.line:SetVertexColor(C.border[1], C.border[2], C.border[3], 0.8)
        r.line:SetHeight(1); r.line:SetPoint("TOPLEFT"); r.line:SetPoint("TOPRIGHT")
        r.arrow = UI:Text(r, 11, C.muted); r.arrow:SetPoint("LEFT", 6, 0)
        r.name = UI:Text(r, 12); r.name:SetPoint("LEFT", 22, 0)
        r.split = UI:Text(r, 12); r.level = UI:Text(r, 12); r.diff = UI:Text(r, 11, C.muted)
        r.del = UI:Button(r, "Suppr.", nil, 22, "danger"); r.del:SetPoint("RIGHT", -6, 0)
        r.ren = UI:Button(r, "Renommer", nil, 22, "secondary"); r.ren:SetPoint("RIGHT", r.del, "LEFT", -6, 0)
        r.code = UI:Button(r, "Code", nil, 22, "secondary"); r.code:SetPoint("RIGHT", r.ren, "LEFT", -6, 0)
        r.apply = UI:Button(r, "Appliquer", nil, 22, "primary"); r.apply:SetPoint("RIGHT", r.code, "LEFT", -6, 0)
        r:SetScript("OnEnter", function(s) s.hover = true; s.hl:SetVertexColor(C.hover[1], C.hover[2], C.hover[3], 0.6) end)
        r:SetScript("OnLeave", function(s) s.hover = false; s.hl:SetVertexColor(0, 0, 0, 0) end)
        r:SetScript("OnClick", function(s) f.openBuild = (f.openBuild ~= s.index) and s.index or nil; f:Refresh() end)
        return r
    end)
    -- petite fenêtre : nom d'un build, code à copier ou à coller, confirmation
    local dlg = CreateFrame("Frame", nil, f)
    dlg:SetSize(440, 150)
    dlg:SetPoint("CENTER")
    dlg:SetFrameLevel(f:GetFrameLevel() + 40)
    dlg:EnableMouse(true)
    UI:Panel(dlg, 12, C.bg, { UI:Accent() })
    dlg.title = UI:Text(dlg, 14); dlg.title:SetPoint("TOPLEFT", 16, -14)
    dlg.text = UI:Text(dlg, 11, C.muted); dlg.text:SetPoint("TOPLEFT", 16, -38); dlg.text:SetPoint("RIGHT", -16, 0)
    dlg.text:SetJustifyH("LEFT"); if dlg.text.SetWordWrap then dlg.text:SetWordWrap(true) end
    dlg.input = UI:Input(dlg, 408, 30, "")
    dlg.input:SetPoint("TOPLEFT", 16, -64)
    dlg.ok = UI:Button(dlg, "OK", 100, 28, "primary"); dlg.ok:SetPoint("BOTTOMRIGHT", -16, 12)
    dlg.cancel = UI:Button(dlg, "Annuler", 100, 28, "secondary"); dlg.cancel:SetPoint("RIGHT", dlg.ok, "LEFT", -8, 0)
    dlg.cancel:SetScript("OnClick", function() dlg:Hide() end)
    dlg:Hide()
    f.dlg = dlg
    -- title, text, valeur du champ (nil = pas de champ), action OK (reçoit le texte)
    function f:Ask(title, text, value, onOk, okLabel)
        dlg.title:SetText(title); dlg.text:SetText(text or "")
        dlg.input:SetShown(value ~= nil)
        dlg.input:SetText(value or "")
        dlg.ok:SetLabel(okLabel or T("OK"))
        dlg.ok:SetScript("OnClick", function() local v = dlg.input:GetText(); dlg:Hide(); if onOk then onOk(v) end end)
        dlg.input.onEnter = function(v) dlg:Hide(); if onOk then onOk(v) end end
        dlg:Show()
        if value ~= nil then dlg.input.edit:SetFocus(); dlg.input.edit:HighlightText() end
    end
    local G = WK.modules.Gear
    f.bsave:SetScript("OnClick", function()
        local c = WK.DB.global.characters[f.key]
        local def = string.format(T("Build du %s"), date("%d/%m"))
        f:Ask(T("Enregistrer le build actuel"), string.format(T("Répartition %s · donne-lui un nom."), G:Split(c and c.talents)), def, function(v)
            if not G:SaveBuild(f.key, (v ~= "" and v) or def) then WK:Print(T("Talents pas encore relevés pour ce perso.")) end
        end, T("Enregistrer"))
    end)
    f.bimport:SetScript("OnClick", function()
        f:Ask(T("Importer un code"), T("Colle un code de build (WK1:…) partagé par un autre joueur de la même classe."), "", function(v)
            local b, why = G:ImportBuild(f.key, v)
            if not b then WK:Print(T("Import impossible : ") .. (why or "")) end
        end, T("Importer"))
    end)

    -- Onglet BiS : ta liste, en mannequin (emplacements comme dans la Fiche) ; clic sur un emplacement = fenêtre de choix
    local bsc = UI:Scroll(f)
    bsc:SetPoint("TOPLEFT", 0, -98)
    bsc:SetPoint("BOTTOMRIGHT")
    bsc:Hide()
    f.bsc = bsc
    local B = WK.modules.BiS
    f.bisTitle = UI:Text(bsc.child, 13)
    f.bisTitle:SetText(T("Ma liste BiS"))
    f.bisProg = UI:Progress(bsc.child, 7)
    f.bisInfo = UI:Text(bsc.child, 11, C.muted)
    f.bisClear = UI:Button(bsc.child, "Vider", nil, 24, "danger")
    f.bisShare = UI:Button(bsc.child, "Partager (lien chat)", nil, 24, "secondary")
    f.bisCopy = UI:Button(bsc.child, "Copier depuis un autre perso", nil, 24, "secondary")
    f.bisMid = CreateFrame("Frame", nil, bsc.child)
    UI:Panel(f.bisMid, 12, C.bg, C.border)
    f.bisRing = UI:Icon(f.bisMid, "ring", 78, nil, "ARTWORK")
    f.bisRing:SetPoint("TOP", 0, -24)
    f.bisCls = f.bisMid:CreateTexture(nil, "ARTWORK", nil, -1)
    f.bisCls:SetSize(64, 64); f.bisCls:SetPoint("CENTER", f.bisRing)
    if f.bisMid.CreateMaskTexture then
        local m = f.bisMid:CreateMaskTexture()
        m:SetTexture(UI.MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        m:SetAllPoints(f.bisCls); f.bisCls:AddMaskTexture(m)
    end
    f.bisClass = UI:Text(f.bisMid, 13); f.bisClass:SetPoint("TOP", f.bisRing, "BOTTOM", 0, -10)
    f.bisHint = UI:Text(f.bisMid, 10, C.dim); f.bisHint:SetPoint("TOP", f.bisClass, "BOTTOM", 0, -4)
    f.bisHint:SetText(T("clic : choisir · clic droit : retirer"))
    -- une tuile d'emplacement : icône (liseré de qualité), nom, emplacement · source · état
    local function tile(parent, side)
        local b = CreateFrame("Button", nil, parent)
        b:SetHeight(44)
        if b.RegisterForClicks then b:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
        UI:Panel(b, 8, C.surface, C.border)
        b.edge = b:CreateTexture(nil, "ARTWORK")
        b.edge:SetTexture("Interface\\Buttons\\WHITE8X8")
        b.edge:SetSize(36, 36)
        b.icon = b:CreateTexture(nil, "ARTWORK", nil, 1)
        b.icon:SetSize(32, 32); b.icon:SetPoint("CENTER", b.edge)
        b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        b.plus = UI:Text(b, 18); b.plus:SetPoint("CENTER", b.edge); b.plus:SetText("+")
        b.name = UI:Text(b, 12); b.sub = UI:Text(b, 10, C.muted)
        if side == "right" then
            b.edge:SetPoint("RIGHT", -6, 0)
            b.name:SetPoint("TOPRIGHT", -50, -7); b.sub:SetPoint("TOPRIGHT", -50, -24)
            b.name:SetJustifyH("RIGHT"); b.sub:SetJustifyH("RIGHT")
            b.name:SetPoint("LEFT", 8, 0); b.sub:SetPoint("LEFT", 8, 0)
        elseif side == "left" then
            b.edge:SetPoint("LEFT", 6, 0)
            b.name:SetPoint("TOPLEFT", 50, -7); b.sub:SetPoint("TOPLEFT", 50, -24)
            b.name:SetPoint("RIGHT", -8, 0); b.sub:SetPoint("RIGHT", -8, 0)
        else
            b:SetSize(44, 44)
            b.edge:SetPoint("CENTER")
            b.name:Hide(); b.sub:Hide()
        end
        b:SetScript("OnEnter", function(s)
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            if s.id and GameTooltip.SetItemByID then GameTooltip:SetItemByID(s.id) else GameTooltip:SetText(T(s.label or ""), 1, 1, 1) end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(s.id and T("Clic : changer · clic droit : retirer") or T("Clic : choisir un objet (ou glisse-le ici)"), 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        local function drop(s)
            local kind, id = GetCursorInfo and GetCursorInfo()
            if kind == "item" and id then B:Set(f.key, s.slot, id); if ClearCursor then ClearCursor() end return true end
        end
        b:SetScript("OnReceiveDrag", drop)
        b:SetScript("OnClick", function(s, btn)
            if drop(s) then return end
            if btn == "RightButton" then B:Set(f.key, s.slot, nil) return end
            f:OpenPicker(s.slot, s.label)
        end)
        return b
    end
    f.bisTiles = {}
    local LEFT_S, RIGHT_S, MID_S = { 1, 2, 3, 15, 5, 9 }, { 10, 6, 7, 8, 11, 12, 13, 14 }, { 16, 17, 18 }
    for _, sl in ipairs(LEFT_S) do local t = tile(bsc.child, "left"); t.slot = sl; t.side = "left"; table.insert(f.bisTiles, t) end
    for _, sl in ipairs(RIGHT_S) do local t = tile(bsc.child, "right"); t.slot = sl; t.side = "right"; table.insert(f.bisTiles, t) end
    for _, sl in ipairs(MID_S) do local t = tile(f.bisMid, "mid"); t.slot = sl; t.side = "mid"; table.insert(f.bisTiles, t) end
    f.bisWeap = UI:Text(f.bisMid, 10, C.dim)
    f.bisWeap:SetText(T("Main droite · Main gauche · Distance"))
    f.bisNote = UI:Text(bsc.child, 10, C.dim)
    f.bisNote:SetText(T("Objets du jeu : wowlayerup-forever/opendata (CC BY 4.0). Maj+clic sur un objet avec la recherche active, ou glisser-déposer sur un emplacement, marchent aussi."))
    f.bisClear:SetScript("OnClick", function()
        f:Ask(T("Vider la liste BiS ?"), T("Tous les objets de la liste de ce perso seront retirés."), nil, function() B:ClearList(f.key) end, T("Vider"))
    end)
    f.bisShare:SetScript("OnClick", function()
        local list = B:List(f.key)
        local c = WK.DB.global.characters[f.key]
        local text = T("Ma BiS") .. " (" .. ((c and c.class and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c.class]) or "") .. ") :"
        local n = 0
        for _, s in ipairs(B.SLOTS) do
            local id = list[s[1]]
            local _, link = id and WK.GetItemInfo(id)
            if link and #text + #link + 1 < 250 then text = text .. " " .. link; n = n + 1 end
        end
        if n == 0 then WK:Print(T("Liste vide (ou objets pas encore chargés par le jeu : réessaie).")) return end
        WK.ChatInsert(text)
    end)
    f.bisCopy:SetScript("OnClick", function()
        local names, keys = {}, {}
        for key, c in pairs(WK.DB.global.characters) do
            if key ~= f.key and next(B:List(key)) then table.insert(keys, key); table.insert(names, WK:CharName(c, key)) end
        end
        if #keys == 0 then WK:Print(T("Aucun autre perso n'a de liste BiS.")) return end
        f:Ask(T("Copier une liste BiS"), T("Tape le nom du perso dont copier la liste : ") .. table.concat(names, ", "), names[1], function(v)
            for i, nm in ipairs(names) do
                if nm:lower() == (v or ""):lower() then
                    local dst = B:List(f.key)
                    for slot, id in pairs(B:List(keys[i])) do dst[slot] = id end
                    WK:NotifyChanged()
                    return
                end
            end
            WK:Print(T("Perso introuvable."))
        end, T("Copier"))
    end)

    -- Fenêtre de choix d'un objet pour un emplacement
    local pk = CreateFrame("Frame", nil, f)
    pk:SetSize(700, 470)
    pk:SetPoint("CENTER", 0, -20)
    pk:SetFrameLevel(f:GetFrameLevel() + 30)
    pk:EnableMouse(true)
    UI:Panel(pk, 12, C.bg, { UI:Accent() })
    pk:Hide()
    f.picker = pk
    pk.title = UI:Text(pk, 14); pk.title:SetPoint("TOPLEFT", 16, -18)
    pk.close = UI:Button(pk, "Fermer", nil, 26, "secondary"); pk.close:SetPoint("TOPRIGHT", -12, -12)
    pk.close:SetScript("OnClick", function() pk:Hide() end)
    pk.search = UI:Input(pk, 400, 28, T("Rechercher un objet…"), "search")
    pk.search:SetPoint("TOPLEFT", 110, -12)
    pk.search.edit.acceptLinks = true
    pk.search.onChange = function(text, user)
        local id = text and text:find("|H", 1, true) and WK:ParseItemID(text)
        if id then B:Set(f.key, pk.slot, id); pk:Hide() return end
        pk.f.query = text; pk:Fill()
    end
    pk.filters = { source = "all", quality = 3 }
    pk.chips = UI:Pool(function()
        local b = UI:Button(pk, "", nil, 22, "secondary")
        return b
    end)
    pk.rows = {}
    local list = UI:Scroll(pk)
    list:SetPoint("TOPLEFT", 12, -110); list:SetPoint("BOTTOMRIGHT", -12, 34)
    pk.list = list
    pk.count = UI:Text(pk, 10, C.dim); pk.count:SetPoint("BOTTOMLEFT", 16, 12)
    pk.heads = {}
    for i, h in ipairs({ "Objet", "Niv.", "Où", "Caractéristiques" }) do
        local t = UI:Text(pk, 10, C.dim); t:SetText(UI:Upper(T(h))); pk.heads[i] = t
    end
    local PX = { 4, 290, 330, 520 }
    for i, t in ipairs(pk.heads) do t:SetPoint("TOPLEFT", 12 + PX[i], -94) end
    local function prow(i)
        local r = pk.rows[i]
        if r then return r end
        r = CreateFrame("Button", nil, list.child)
        r:SetHeight(28)
        r.hl = r:CreateTexture(nil, "HIGHLIGHT"); r.hl:SetTexture("Interface\\Buttons\\WHITE8X8"); r.hl:SetAllPoints(); r.hl:SetVertexColor(1, 1, 1, 0.06)
        r.edge = r:CreateTexture(nil, "ARTWORK"); r.edge:SetTexture("Interface\\Buttons\\WHITE8X8"); r.edge:SetSize(24, 24); r.edge:SetPoint("LEFT", PX[1], 0)
        r.icon = r:CreateTexture(nil, "ARTWORK", nil, 1); r.icon:SetSize(20, 20); r.icon:SetPoint("CENTER", r.edge); r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        r.name = UI:Text(r, 12); r.name:SetPoint("LEFT", PX[1] + 32, 0); r.name:SetWidth(PX[2] - PX[1] - 40)
        r.lvl = UI:Text(r, 12); r.lvl:SetPoint("LEFT", PX[2], 0)
        r.src = UI:Text(r, 11, C.muted); r.src:SetPoint("LEFT", PX[3], 0); r.src:SetWidth(PX[4] - PX[3] - 10)
        r.stats = UI:Text(r, 11); r.stats:SetPoint("LEFT", PX[4], 0); r.stats:SetPoint("RIGHT", -6, 0)
        r:SetScript("OnEnter", function(s) UI:TooltipOwner(s, "ANCHOR_RIGHT"); if GameTooltip.SetItemByID then GameTooltip:SetItemByID(s.id) end; GameTooltip:Show() end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        r:SetScript("OnClick", function(s) B:Set(f.key, pk.slot, s.id); pk:Hide() end)
        pk.rows[i] = r
        return r
    end
    local MAXR = 150
    function pk:Fill()
        local c = WK.DB.global.characters[f.key]
        if not c then return end
        local fl = self.f
        local items = B:Candidates(self.slot, c, fl)
        for _, r in ipairs(self.rows) do r:Hide() end
        local y = 0
        for i, e in ipairs(items) do
            if i > MAXR then break end
            local r = prow(i)
            r.id = e[1]
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:SetPoint("TOPRIGHT", 0, -y)
            local qc = QUALITY[e[5]] or QUALITY[2]
            r.edge:SetVertexColor(qc[1], qc[2], qc[3], 1)
            r.icon:SetTexture((C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(e[1])) or "Interface\\Icons\\INV_Misc_QuestionMark")
            r.name:SetText(e[8]); r.name:SetTextColor(qc[1], qc[2], qc[3])
            r.lvl:SetText(e[7] > 0 and e[7] or "-")
            local _, where = B:SourceOf(e[1])
            r.src:SetText(where)
            r.stats:SetText(e[9])
            r:Show()
            y = y + 30
        end
        list:SetContentHeight(y)
        self.count:SetText(#items > MAXR and string.format(T("%d objets (les %d premiers affichés : affine la recherche)"), #items, MAXR)
            or string.format(T("%d objet(s) pour cet emplacement · clic : choisir · survol : infobulle"), #items))
    end
    -- rangées de filtres : source, qualité, niveau, type d'armure (emplacements d'armure seulement)
    local ARMOR_SLOTS = { [1] = true, [3] = true, [5] = true, [9] = true, [10] = true, [6] = true, [7] = true, [8] = true }
    function pk:Chips()
        self.chips:Reset()
        local fl = self.f
        local x, y = 16, -50
        local function chip(label, sel, fn)
            local b = self.chips:Get()
            b:SetLabel(T(label)); b:SetWidth(b.label:GetStringWidth() + 22)
            b:SetStyle(sel and "primary" or "secondary")
            if x + b:GetWidth() > 690 then x = 16; y = y - 26 end
            b:ClearAllPoints(); b:SetPoint("TOPLEFT", x, y)
            b:SetScript("OnClick", function() fn(); self:Chips(); self:Fill() end)
            x = x + b:GetWidth() + 5
        end
        for _, s in ipairs({ { "all", "Toutes sources" }, { "dungeon", "Donjons" }, { "raid", "Raids" }, { "craft", "Artisanat" }, { "quest", "Quêtes" }, { "other", "Autres" } }) do
            chip(s[2], fl.source == s[1], function() fl.source = s[1] end)
        end
        x = x + 10
        for _, q in ipairs({ { 2, "Vert et +" }, { 3, "Bleu et +" }, { 4, "Violet et +" } }) do
            chip(q[2], fl.quality == q[1], function() fl.quality = q[1] end)
        end
        x = x + 10
        for _, l in ipairs({ { nil, "Tous niveaux" }, { { 50, 60 }, "Niv. 50-60" }, { { 30, 49 }, "Niv. 30-49" }, { { 0, 29 }, "Niv. 1-29" } }) do
            chip(l[2], (fl.level and l[1] and fl.level[1] == l[1][1]) or (not fl.level and not l[1]), function() fl.level = l[1] end)
        end
        if ARMOR_SLOTS[self.slot] then
            x = x + 10
            local c = WK.DB.global.characters[f.key]
            chip("Toutes armures", not fl.armor, function() fl.armor = nil end)
            for _, sub in ipairs(B:ArmorTypes(c)) do
                chip(B.ARMOR[sub], fl.armor == sub, function() fl.armor = sub end)
            end
        end
        -- la liste commence sous la dernière rangée de filtres
        for i, t in ipairs(self.heads) do t:ClearAllPoints(); t:SetPoint("TOPLEFT", 12 + PX[i], y - 32) end
        self.list:ClearAllPoints(); self.list:SetPoint("TOPLEFT", 12, y - 48); self.list:SetPoint("BOTTOMRIGHT", -12, 34)
    end
    function f:OpenPicker(slot, label)
        pk.slot = slot
        pk.title:SetText(T(label or ""))
        pk.f = { source = pk.filters.source, quality = pk.filters.quality }
        local c = WK.DB.global.characters[f.key]
        -- armure : par défaut la meilleure que la classe porte au niveau 60
        if ARMOR_SLOTS[slot] and c then local a = B:ArmorTypes(c); pk.f.armor = a[#a] end
        pk.f.level = { 50, 60 }
        pk.search:SetText("")
        pk:Chips()
        pk:Fill()
        pk:Show()
    end
    return f
end

---------------------------------------------------------------------------
local function refreshGear(f, c)
    local gear = c.gear
    for _, b in ipairs(f.slots) do
        local d = b.def
        b:Set(d[1], d[2], d[3], gear and gear[d[1]])
    end
    UI:SetClassIcon(f.bigCls, c.class)
    local cr, cg, cb = UI:ClassColor(c.class)
    f.big:SetVertexColor(cr, cg, cb)
    local cls = c.class and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c.class] or c.class or ""
    local spec
    for _, t in ipairs(c.talents or {}) do
        if (t.points or 0) > 0 and (not spec or t.points > spec.points) then spec = t end
    end
    f.spec:SetText(spec and (cls .. "  ·  " .. spec.name) or cls)
    -- aperçu 3D : portrait de classe s'il n'est pas possible
    local RACE_ID = { Human = 1, Orc = 2, Dwarf = 3, NightElf = 4, Scourge = 5, Tauren = 6, Gnome = 7, Troll = 8, BloodElf = 10, Draenei = 11 }
    local shown = false
    local m = f.model
    if m then
        local mine = c.key == WK:CharKey()
        local okm = pcall(function()
            m:SetUnit("player")
            if not mine then
                if not (m.SetCustomRace and RACE_ID[c.race or ""]) then error("race") end
                m:SetCustomRace(RACE_ID[c.race], (c.sex == 3) and 1 or 0)
                if m.Undress then m:Undress() end
                for _, link in pairs(c.gear or {}) do pcall(m.TryOn, m, link) end
            end
            if m.SetFacing then m:SetFacing(m.rot or 0) end
        end)
        shown = okm
        m:SetShown(shown)
    end
    f.big:SetShown(not shown); f.bigCls:SetShown(not shown)
    f.spec:ClearAllPoints(); f.seen:ClearAllPoints()
    if shown then
        f.spec:SetPoint("TOP", f.mid, "TOP", 0, -10)
    else
        f.spec:SetPoint("TOP", f.big, "BOTTOM", 0, -10)
    end
    f.seen:SetPoint("TOP", f.spec, "BOTTOM", 0, -4)
    f.spec:SetDrawLayer("OVERLAY", 7); f.seen:SetDrawLayer("OVERLAY", 7)
    f.seen:SetText(c.key == WK:CharKey() and T("connecté") or (c.lastSeen and string.format(T("vu %s"), UI:Ago(c.lastSeen)) or ""))
    f:PlaceKpis()
    local s = c.stats or {}
    f.kpis[1].v:SetText(fmt(s.armor)); f.kpis[1].l:SetText(T("armure"))
    f.kpis[2].v:SetText(c.durability and (math.floor(c.durability) .. " %") or (c.gear and "100 %" or "-")); f.kpis[2].l:SetText(T("durabilité"))
    f.kpis[3].v:SetText(c.totalSlots and ((c.freeSlots or 0) .. "/" .. c.totalSlots) or "-"); f.kpis[3].l:SetText(T("sacs libres"))
    f.noGear:SetShown(not gear)
    f.noGear:SetText(T("Équipement pas encore relevé : connecte ce perso une fois avec cette version."))
end

-- Stats ; rend la hauteur de la carte
local function refreshStats(f, c)
    local s = c.stats
    local w = WEIGHTS[c.class or ""] or {}
    local r1, g1, b1 = UI:Accent()
    local cls = c.class and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c.class]
    f.hUse:SetText(cls and T("en couleur : utile") or "")
    local maxV = 1
    for _, r in ipairs(f.statRows) do maxV = math.max(maxV, s and s[r.key] or 0) end
    for _, r in ipairs(f.statRows) do
        local v = s and s[r.key]
        r.val:SetText(v and fmt(v) or "-")
        local useful = (w[r.key] or 0.5) >= 0.5
        r.name:SetTextColor(unpack(useful and C.text or C.muted))
        r.bar.color = useful and { r1, g1, b1, 1 } or C.dim
        r.bar:SetValue(v and v / maxV or 0)
    end
    -- combat : selon ce que le perso utilise
    local list = {}
    local function add(label, v, pct) if v and v > 0 then table.insert(list, { label, fmt(v, pct) }) end end
    if s then
        local caster = (w.int or 0) >= 0.8
        if not caster or (w.str or 0) >= 0.5 then add(T("Puissance d'attaque"), s.ap) end
        if c.class == "HUNTER" then add(T("Puiss. d'attaque à distance"), s.rap) end
        if not caster then add(T("Critique"), c.class == "HUNTER" and s.rcrit or s.crit, true) end
        add(T("Toucher"), s.hit, true)
        if caster or c.class == "PALADIN" or c.class == "SHAMAN" or c.class == "DRUID" then
            add(T("Puissance des sorts"), s.spell)
            if c.class == "PRIEST" or c.class == "DRUID" or c.class == "PALADIN" or c.class == "SHAMAN" then add(T("Soins"), s.heal) end
            add(T("Critique des sorts"), s.scrit, true)
        end
        add(T("Esquive"), s.dodge, true)
        add(T("Parade"), s.parry, true)
        add(T("Blocage"), s.block, true)
    end
    local n = 0
    for i, r in ipairs(f.combat) do
        local e = list[i]
        r:SetShown(e ~= nil)
        if e then r.name:SetText(e[1]); r.val:SetText(e[2]); n = i end
    end
    f.hCombat:SetShown(n > 0)
    local y = n > 0 and (188 + n * 20 + 8) or 170
    f.hRes:ClearAllPoints(); f.hRes:SetPoint("TOPLEFT", 14, -y)
    local res = s and s.res or {}
    local RES = { { "fire", "Feu", "ff7a3d" }, { "frost", "Givre", "62b6ff" }, { "nature", "Nature", "8dd65c" },
        { "shadow", "Ombre", "b48cff" }, { "arcane", "Arcanes", "ffe27a" } }
    local parts = {}
    for _, x in ipairs(RES) do table.insert(parts, "|cff" .. x[3] .. T(x[2]) .. " " .. (res[x[1]] or 0) .. "|r") end
    local cw = (f.sideW or SIDE_W) - 28
    f.res:ClearAllPoints(); f.res:SetPoint("TOPLEFT", 14, -(y + 18)); f.res:SetWidth(cw)
    f.res:SetText(s and table.concat(parts, "   ") or "-")
    y = y + 18 + math.max(16, f.res:GetStringHeight() or 16) + 10
    f.statNote:ClearAllPoints(); f.statNote:SetPoint("TOPLEFT", 14, -y); f.statNote:SetWidth(cw)
    f.statNote:SetText(s and c.sheetAt and string.format(T("Relevées à la dernière connexion de ce perso (%s)."), UI:Ago(c.sheetAt))
        or T("Stats pas encore relevées : connecte ce perso une fois avec cette version."))
    return y + math.max(14, f.statNote:GetStringHeight() or 14) + 14
end

-- Métiers dans leur carte ; rend la hauteur
local function refreshProfs(f, c, card, w)
    local r1, g1, b1 = UI:Accent()
    local profs = {}
    for name, p in pairs(c.professions or {}) do table.insert(profs, { name, p }) end
    table.sort(profs, function(a, b) return (a[2].rank or 0) > (b[2].rank or 0) end)
    local y = 44
    for _, e in ipairs(profs) do
        local r = f.lrows:Get()
        r:SetParent(card)
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -y); r:SetWidth(w - 28)
        r.name:SetText(T(e[1])); r.name:SetTextColor(unpack(C.text))
        local p = e[2]
        r.right:SetText((p.rank or 0) .. " / " .. (p.max or 0))
        r.bar.color = { r1, g1, b1, 1 }
        r.bar:SetValue((p.max or 0) > 0 and (p.rank or 0) / p.max or 0)
        y = y + 34
    end
    f.profEmpty:SetShown(#profs == 0)
    f.profEmpty:SetText(T("Aucun métier relevé pour ce perso."))
    return (#profs == 0 and 74) or (y + 8)
end

-- Réputations dans leur carte ; rend la hauteur. Repliée : les plus avancées, sans les groupes.
local function refreshReps(f, c, card, w)
    local all = c.reps or {}
    local list = {}
    if f.repAll then
        list = all
    else
        for _, e in ipairs(all) do if not e.header then table.insert(list, e) end end
        table.sort(list, function(a, b)
            if (a.standing or 0) ~= (b.standing or 0) then return (a.standing or 0) > (b.standing or 0) end
            return (a.cur or 0) / math.max(1, a.max or 1) > (b.cur or 0) / math.max(1, b.max or 1)
        end)
    end
    local nReal = 0
    for _, e in ipairs(all) do if not e.header then nReal = nReal + 1 end end
    f.repMore:SetShown(nReal > REP_SHORT)
    f.repMore:SetLabel(f.repAll and T("Réduire") or string.format(T("Tout voir (%d)"), nReal))
    local y, shown = 44, 0
    for _, e in ipairs(list) do
        if not f.repAll and shown >= REP_SHORT then break end
        if e.header then
            local h = f.lheads:Get()
            h:SetParent(card)
            h:ClearAllPoints(); h:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -(y + 6))
            h:SetText(UI:Upper(e.name))
            y = y + 24
        else
            local r = f.lrows:Get()
            r:SetParent(card)
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -y); r:SetWidth(w - 28)
            r.name:SetText(e.name); r.name:SetTextColor(unpack(C.text))
            local sc = STANDING_COL[e.standing] or C.muted
            r.right:SetText("|cff" .. string.format("%02x%02x%02x", sc[1] * 255, sc[2] * 255, sc[3] * 255) .. T(STANDING[e.standing] or "?")
                .. "|r  " .. (e.cur or 0) .. " / " .. (e.max or 0))
            r.bar.color = { sc[1], sc[2], sc[3], 1 }
            r.bar:SetValue((e.max or 0) > 0 and (e.cur or 0) / e.max or 0)
            y = y + 34
            shown = shown + 1
        end
    end
    f.repEmpty:SetShown(nReal == 0)
    f.repEmpty:SetText(T("Réputations pas encore relevées : connecte ce perso une fois avec cette version."))
    return (nReal == 0 and 74) or (y + 8)
end

function UI:ShowCharSheet(key)
    if not WK.DB.global.characters[key] then return end
    if sheet then sheet.repAll = false end
    UI.charSheetKey = key
    UI:Create():Show()
    UI:ShowPage("charsheet")
end

-- Onglet Talents
local CELL, CGAP = 34, 10
local paintTrees
local function refreshTalents(f, c)
    -- perso connecté sans détail : on relève tout de suite (talents pas prêts à la connexion)
    if f.key == WK:CharKey() and not (c.talents and c.talents[1] and c.talents[1].list) and not f.talentTried then
        f.talentTried = true
        WK.modules.Gear:Scan({ talents = true })
        c = WK.DB.global.characters[f.key] or c
    end
    local W = math.max(600, (f.tsc:GetWidth() or 840) - 12)
    f.tsc.child:SetWidth(W)
    local trees = c.talents or {}
    local split = {}
    for _, t in ipairs(trees) do table.insert(split, t.points or 0) end
    local any = #trees > 0 and trees[1].list ~= nil
    local r, g, b = UI:Accent()
    f.tsum:SetText(#split > 0 and string.format(T("Répartition |cff%02x%02x%02x%s|r  ·  %s"), r * 255, g * 255, b * 255, table.concat(split, " / "),
        (c.talentFree and c.talentFree > 0) and string.format(T("%d point(s) à dépenser"), c.talentFree) or T("aucun point à dépenser")) or "")
    f.tempty:SetShown(not any)
    f.tempty:SetText(f.key == WK:CharKey() and T("Le jeu n'a pas encore donné tes talents. Tape /wk talents et envoie le résultat si ça dure.") or T("Talents pas encore relevés : connecte ce perso une fois avec cette version."))
    local nt = math.max(1, math.min(#trees, #f.trees))
    local tw = math.floor((W - (nt - 1) * 12) / nt)
    local maxTier, maxCols = 1, 4
    for _, t in ipairs(trees) do
        for _, d in ipairs(t.list or {}) do maxTier = math.max(maxTier, d[3]); maxCols = math.max(maxCols, d[4]) end
    end
    -- cases plus petites si l'arbre est large
    -- cases aussi grandes que la place le permet : largeur d'un arbre et hauteur de la page (écart = 30 % de la case)
    local availH = math.max(200, (f.tsc:GetHeight() or 480) - 28 - 52 - 14)
    local byW = math.floor((tw - 40) / (maxCols + (maxCols - 1) * 0.3))
    local byH = math.floor(availH / (maxTier + (maxTier - 1) * 0.3))
    local cs = math.max(24, math.min(60, byW, byH))
    local cg = math.max(4, math.floor(cs * 0.3))
    local th = 52 + maxTier * cs + (maxTier - 1) * cg + 14
    local mine = f.key == WK:CharKey()
    paintTrees(f, f.trees, trees, 28, tw, cs, cg, th, mine, nil)
    -- builds sous les arbres
    local G = WK.modules.Gear
    local builds = G:Builds(f.key)
    local by = (any and (28 + th) or 60) + 12
    local card = f.bcard
    card:ClearAllPoints(); card:SetPoint("TOPLEFT", 0, -by); card:SetWidth(W)
    f.bcount:SetText(string.format(T("%s · %d enregistré(s)"), WK:CharName(c, f.key), #builds))
    f.bsave:SetEnabled(any)
    f.bempty:SetShown(#builds == 0)
    local XS = { 22, math.floor(W * 0.36), math.floor(W * 0.47), math.floor(W * 0.55) }
    for i, t in ipairs(f.bheads) do t:ClearAllPoints(); t:SetPoint("TOPLEFT", XS[i], -44); t:SetShown(#builds > 0) end
    f.brows:Reset()
    for _, tr in ipairs(f.ptrees) do tr:Hide() end
    local y = #builds > 0 and 62 or 70
    local ptw = math.floor((W - 24 - (nt - 1) * 10) / nt)
    local pcs = math.max(20, math.min(36, cs))
    local pcg = math.max(4, math.floor(pcs * 0.3))
    local pth = 52 + maxTier * pcs + (maxTier - 1) * pcg + 14
    for i, bd in ipairs(builds) do
        local row = f.brows:Get()
        row.index = i
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 8, -y); row:SetPoint("TOPRIGHT", -8, -y)
        row.hl:SetVertexColor(0, 0, 0, 0)
        local open = f.openBuild == i
        row.arrow:SetText(open and "-" or "+")
        row.name:SetText(bd.name or "?")
        row.name:SetTextColor(unpack(open and C.text or C.text))
        row.split:ClearAllPoints(); row.split:SetPoint("LEFT", XS[2] - 8, 0); row.split:SetText(G:Split(bd.trees)); row.split:SetTextColor(r, g, b)
        row.level:ClearAllPoints(); row.level:SetPoint("LEFT", XS[3] - 8, 0); row.level:SetText(bd.level or "-")
        local add, rem = G:Diff(bd, trees)
        row.diff:ClearAllPoints(); row.diff:SetPoint("LEFT", XS[4] - 8, 0)
        if add == 0 and rem == 0 then row.diff:SetText("|cff9ed17a" .. T("actif") .. "|r")
        elseif rem == 0 then row.diff:SetText(string.format(T("+%d point(s) à placer"), add))
        else row.diff:SetText(string.format("|cffe86b6b" .. T("%d à retirer") .. "|r · " .. T("%d à placer"), rem, add)) end
        row.apply:SetShown(mine and (add > 0))
        row.apply:SetScript("OnClick", function()
            f:Ask(string.format(T("Appliquer « %s » ?"), bd.name or ""), rem > 0
                and string.format(T("%d point(s) à retirer d'abord : réinitialise tes talents chez ton maître de classe, puis reviens ici."), rem)
                or string.format(T("%d point(s) à placer, dans l'ordre du build, avec tes points libres (%d)."), add, c.talentFree or 0), nil, function()
                local n, why = G:ApplyBuild(f.key, i)
                if n and n > 0 then WK:Print(string.format(T("%d point(s) placé(s)."), n)) else WK:Print(why or T("Rien à placer.")) end
            end, rem > 0 and T("Compris") or T("Placer"))
        end)
        row.code:SetScript("OnClick", function()
            f:Ask(T("Code du build"), T("Copie ce code (Ctrl+C) pour le partager ; « Importer un code » le reprend sur un perso de la même classe."), G:ExportBuild(f.key, i) or "", nil, T("Fermer"))
        end)
        row.ren:SetScript("OnClick", function()
            f:Ask(T("Renommer le build"), nil, bd.name or "", function(v) G:RenameBuild(f.key, i, v) end, T("Renommer"))
        end)
        row.del:SetScript("OnClick", function()
            f:Ask(T("Supprimer le build ?"), string.format(T("« %s » sera supprimé."), bd.name or ""), nil, function()
                if f.openBuild == i then f.openBuild = nil end
                G:DeleteBuild(f.key, i)
            end, T("Supprimer"))
        end)
        y = y + 34
        if open then
            -- aperçu : arbres du build, liseré violet = à ajouter, rouge = à retirer
            paintTrees(f, f.ptrees, bd.trees, y, ptw, pcs, pcg, pth, false, trees, 12)
            y = y + pth + 10
        end
    end
    card:SetHeight(y + 8)
    f.tsc:SetContentHeight(by + y + 16)
end

-- Icônes des spécialisations (ordre classique des arbres, de gauche à droite)
local SPEC_ICONS = {
    WARRIOR = { "Ability_Warrior_SavageBlow", "Ability_Warrior_InnerRage", "INV_Shield_06" },
    PALADIN = { "Spell_Holy_HolyBolt", "Spell_Holy_DevotionAura", "Spell_Holy_AuraOfLight" },
    HUNTER = { "Ability_Hunter_BeastTaming", "Ability_Marksmanship", "Ability_Hunter_SwiftStrike" },
    ROGUE = { "Ability_Rogue_Eviscerate", "Ability_BackStab", "Ability_Stealth" },
    PRIEST = { "Spell_Holy_WordFortitude", "Spell_Holy_GuardianSpirit", "Spell_Shadow_ShadowWordPain" },
    SHAMAN = { "Spell_Nature_Lightning", "Spell_Nature_LightningShield", "Spell_Nature_MagicImmunity" },
    MAGE = { "Spell_Holy_MagicalSentry", "Spell_Fire_FireBolt02", "Spell_Frost_FrostBolt02" },
    WARLOCK = { "Spell_Shadow_DeathCoil", "Spell_Shadow_Metamorphosis", "Spell_Shadow_RainOfFire" },
    DRUID = { "Spell_Nature_StarFall", "Ability_Racial_BearForm", "Spell_Nature_HealingTouch" },
}
-- Dessine des arbres de talents (set de cartes) à la hauteur y ; cur = talents actuels pour marquer les écarts
paintTrees = function(f, set, trees, y, tw, cs, cg, th, mine, cur, x0)
    local r, g, b = UI:Accent()
    local c = WK.DB.global.characters[f.key]
    local icons = c and #trees == 3 and SPEC_ICONS[c.class or ""]
    local parent = set == f.ptrees and f.bcard or nil
    for i, tr in ipairs(set) do
        local t = trees[i]
        tr:SetShown(t ~= nil and t.list ~= nil)
        if t and t.list then
            if parent then tr:SetParent(parent); tr:SetFrameLevel(parent:GetFrameLevel() + 2) end
            tr:ClearAllPoints()
            tr:SetPoint("TOPLEFT", (x0 or 0) + (i - 1) * (tw + (parent and 10 or 12)), -y)
            tr:SetSize(tw, th)
            tr.title:SetText(t.name)
            -- icône de la spécialisation devant le nom
            if not tr.sicon then
                tr.sicon = UI:RoundIcon(tr, 24)
                tr.sicon:SetPoint("TOPLEFT", 12, -9)
            end
            local ic = t.icon or (icons and icons[i] and ("Interface\\Icons\\" .. icons[i]))
            tr.sicon:SetShown(ic ~= nil)
            if ic then tr.sicon:SetTexture(ic) end
            tr.title:ClearAllPoints(); tr.title:SetPoint("TOPLEFT", ic and 44 or 16, -14)
            local pts = 0
            for _, d in ipairs(t.list) do pts = pts + (d[5] or 0) end
            tr.pts:SetText(pts)
            if pts > 0 then tr.pts:SetTextColor(r, g, b) else tr.pts:SetTextColor(unpack(C.dim)) end
            local cols = t.cols or 4
            for _, d in ipairs(t.list) do cols = math.max(cols, d[4]) end
            local gx = math.floor((tw - (cols * cs + (cols - 1) * cg)) / 2)
            for _, cell in ipairs(tr.cells) do cell:Hide() end
            for j, d in ipairs(t.list) do
                local cell = f.talentCell(tr, j)
                cell.data, cell.tab, cell.index, cell.mine = d, i, j, mine
                cell:ClearAllPoints()
                cell:SetSize(cs, cs)
                cell.rk:SetFont(UI.FONT, cs >= 44 and 12 or 10, "")
                cell.rkBox:SetHeight(cs >= 44 and 17 or 14)
                cell:SetPoint("TOPLEFT", gx + (d[4] - 1) * (cs + cg), -46 - (d[3] - 1) * (cs + cg))
                cell.icon:SetTexture(d[2] or "Interface\\Icons\\INV_Misc_QuestionMark")
                local rank, max = d[5] or 0, d[6] or 1
                if cell.icon.SetDesaturated then cell.icon:SetDesaturated(rank == 0) end
                cell.icon:SetAlpha(rank == 0 and 0.45 or 1)
                local col = rank >= max and C.gold or rank > 0 and C.positive or C.border
                if cur then
                    local now = WK.modules.Gear.CurRank(cur, i, j, d)
                    if rank > now then col = { 0.71, 0.49, 0.95 } elseif rank < now then col = C.negative end
                end
                cell.edge:SetVertexColor(col[1], col[2], col[3], 1)
                cell.rk:SetText(rank .. "/" .. max)
                local tc = (rank > 0 or cur) and col or C.dim
                cell.rk:SetTextColor(tc[1], tc[2], tc[3])
                cell.rkBox:SetWidth(math.max(22, math.ceil(cell.rk:GetStringWidth() or 0) + 8))
                cell.rkBox.border:SetColor(col[1], col[2], col[3], rank > 0 and 1 or 0.6)
                cell:Show()
            end
        end
    end
end


-- Onglet BiS : ta liste en mannequin
local SLOT_LABEL = {}
local function refreshBis(f, c)
    local B = WK.modules.BiS
    for _, s in ipairs(B.SLOTS) do SLOT_LABEL[s[1]] = s[2] end
    local W = math.max(600, (f.bsc:GetWidth() or 840) - 12)
    f.bsc.child:SetWidth(W)
    local list = B:List(f.key)
    local gear = c.gear or {}
    local wornSet = {}
    for _, l in pairs(gear) do local id = WK:ParseItemID(l); if id then wornSet[id] = true end end
    local n, worn, bags = 0, 0, 0
    for _, id in pairs(list) do
        n = n + 1
        if wornSet[id] then worn = worn + 1 elseif (c.bags and c.bags[id]) or (c.bank and c.bank[id]) then bags = bags + 1 end
    end
    -- barre du haut
    f.bisTitle:ClearAllPoints(); f.bisTitle:SetPoint("TOPLEFT", 4, -10)
    f.bisProg:ClearAllPoints(); f.bisProg:SetPoint("LEFT", f.bisTitle, "RIGHT", 12, 0); f.bisProg:SetWidth(180)
    f.bisProg.color = { UI:Accent() }; f.bisProg:SetValue(n > 0 and worn / n or 0)
    f.bisInfo:ClearAllPoints(); f.bisInfo:SetPoint("LEFT", f.bisProg, "RIGHT", 12, 0)
    f.bisInfo:SetText(string.format(T("%d / %d obtenus · %d dans les sacs ou la banque"), worn, n, bags))
    f.bisClear:ClearAllPoints(); f.bisClear:SetPoint("TOPRIGHT", f.bsc.child, "TOPRIGHT", -4, -4)
    f.bisShare:ClearAllPoints(); f.bisShare:SetPoint("RIGHT", f.bisClear, "LEFT", -6, 0)
    f.bisCopy:ClearAllPoints(); f.bisCopy:SetPoint("RIGHT", f.bisShare, "LEFT", -6, 0)
    -- trois colonnes : gauche, centre (portrait et armes), droite
    local MIDW = 200
    local colW = math.floor((W - MIDW - 24) / 2)
    local top, step = 40, 50
    local li, ri = 0, 0
    for _, t in ipairs(f.bisTiles) do
        t.label = SLOT_LABEL[t.slot]
        local id = list[t.slot]
        t.id = id
        local e = id and B:Info(id)
        local name, _, q = nil, nil, nil
        if id then name, _, q = WK.GetItemInfo(id) end
        q = q or (e and e[5]) or 1
        local qc = QUALITY[q] or QUALITY[1]
        if id then
            t.icon:SetTexture((C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or "Interface\\Icons\\INV_Misc_QuestionMark")
            t.icon:Show(); t.plus:Hide()
            t.edge:SetVertexColor(qc[1], qc[2], qc[3], 1)
        else
            t.icon:Hide(); t.plus:Show(); t.plus:SetTextColor(UI:Accent())
            t.edge:SetVertexColor(C.border[1], C.border[2], C.border[3], 1)
        end
        if t.side ~= "mid" then
            if id then
                t.name:SetText(name or (e and e[8]) or ("#" .. id)); t.name:SetTextColor(qc[1], qc[2], qc[3])
                local _, where = B:SourceOf(id)
                local state = wornSet[id] and ("|cff9ed17a" .. T("porté") .. "|r")
                    or ((c.bags and c.bags[id]) and ("|cfff5d76e" .. T("dans les sacs") .. "|r"))
                    or ((c.bank and c.bank[id]) and ("|cfff5d76e" .. T("à la banque") .. "|r"))
                    or T("à obtenir")
                t.sub:SetText(T(t.label) .. " · " .. where .. " · " .. state)
            else
                local r, g, b = UI:Accent()
                t.name:SetText(string.format("%s · |cff%02x%02x%02x%s|r", T(t.label), r * 255, g * 255, b * 255, T("choisir…")))
                t.name:SetTextColor(unpack(C.text))
                t.sub:SetText(T("vide"))
            end
        end
        t:ClearAllPoints()
        if t.side == "left" then
            t:SetPoint("TOPLEFT", 0, -(top + li * step)); t:SetWidth(colW); li = li + 1
        elseif t.side == "right" then
            t:SetPoint("TOPLEFT", colW + MIDW + 24, -(top + ri * step)); t:SetWidth(colW); ri = ri + 1
        end
    end
    local rows = math.max(li, ri)
    local h = rows * step - 6
    f.bisMid:ClearAllPoints(); f.bisMid:SetPoint("TOPLEFT", colW + 12, -top); f.bisMid:SetSize(MIDW, h)
    UI:SetClassIcon(f.bisCls, c.class)
    local cr, cg, cb = UI:ClassColor(c.class)
    f.bisRing:SetVertexColor(cr, cg, cb)
    f.bisClass:SetText(c.class and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c.class] or "")
    local mi = 0
    for _, t in ipairs(f.bisTiles) do
        if t.side == "mid" then
            t:ClearAllPoints(); t:SetPoint("BOTTOM", f.bisMid, "BOTTOM", (mi - 1) * 54, 30); mi = mi + 1
        end
    end
    f.bisWeap:ClearAllPoints(); f.bisWeap:SetPoint("BOTTOM", 0, 12)
    f.bisNote:ClearAllPoints(); f.bisNote:SetPoint("TOPLEFT", 4, -(top + h + 10)); f.bisNote:SetPoint("RIGHT", -4, 0)
    f.bisNote:SetJustifyH("LEFT")
    f.bsc:SetContentHeight(top + h + 34)
    if f.picker:IsShown() then f.picker:Fill() end
end

-- Mise à jour de la fiche : en-tête, puis les deux colonnes
local function refresh(f)
    local key = f.key
    local c = WK.DB.global.characters[key]
    if not c then return end
    UI:SetClassIcon(f.cls, c.class)
    local cr, cg, cb = UI:ClassColor(c.class)
    f.ring:SetVertexColor(cr, cg, cb)
    f.title:SetText(WK:CharName(c, key))
    f.title:SetTextColor(cr, cg, cb)
    local cls = c.class and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c.class] or ""
    local race = c.race and T(RACE[c.race] or c.race) or ""
    f.sub:SetText(string.format(T("%s %s · niveau %s · %s"), cls, race, tostring(c.level or "?"), UI:FactionRealm(c)))
    local avg = averageIlvl(c.gear)
    f.score:SetText(avg and (string.format("%.1f", avg):gsub("%.", ",")) or "-")
    f.score:SetTextColor(UI:Accent())
    for _, b in pairs(f.tabs) do b:Paint() end
    f.sc:SetShown(f.tab == "sheet"); f.tsc:SetShown(f.tab == "talents"); f.bsc:SetShown(f.tab == "bis")
    if f.tab ~= "bis" then f.picker:Hide() end
    if f.tab == "talents" then return refreshTalents(f, c) end
    if f.tab == "bis" then return refreshBis(f, c) end
    f.lrows:Reset(); f.lheads:Reset()
    -- largeurs : colonne de droite fixe, la gauche prend le reste
    local W = math.max(600, (f.sc:GetWidth() or 840) - 12)
    f.sc.child:SetWidth(W)
    -- équipement au format de la fenêtre de perso du jeu : pas plus large que 680, la place qui reste va aux Stats
    local leftW = math.min(W - SIDE_W - COL_GAP, 680)
    local sideW = W - leftW - COL_GAP
    f.sideW = sideW
    local view = setmetatable({ key = key }, { __index = c })
    -- deux rangées alignées : Équipement | Stats, puis Réputations | Métiers (chaque rangée à la hauteur
    -- de sa plus grande carte)
    local GEAR_H = 46 + 8 * SLOT_STEP
    refreshGear(f, view)
    local sh = refreshStats(f, c)
    local row1 = math.max(GEAR_H, sh)
    f.gearCard:ClearAllPoints(); f.gearCard:SetPoint("TOPLEFT", 0, 0); f.gearCard:SetSize(leftW, row1)
    f:PlaceKpis()
    f.statCard:ClearAllPoints(); f.statCard:SetPoint("TOPLEFT", leftW + COL_GAP, 0); f.statCard:SetSize(sideW, row1)
    local y2 = row1 + COL_GAP
    f.repCard:ClearAllPoints(); f.repCard:SetPoint("TOPLEFT", 0, -y2); f.repCard:SetWidth(leftW)
    f.profCard:ClearAllPoints(); f.profCard:SetPoint("TOPLEFT", leftW + COL_GAP, -y2); f.profCard:SetWidth(sideW)
    local rh = refreshReps(f, c, f.repCard, leftW)
    local ph = refreshProfs(f, c, f.profCard, sideW)
    local row2 = math.max(rh, ph)
    f.repCard:SetHeight(row2); f.profCard:SetHeight(row2)
    f.sc:SetContentHeight(y2 + row2 + 8)
end

-- branché après build (les fonctions locales ci-dessus doivent exister)
UI:RegisterPage({
    key = "charsheet", order = 2.05, title = "Fiche du personnage",
    Build = function(self, p)
        sheet = build(p)
        sheet.Refresh = refresh
        UI:OnResize(p, function() if sheet:IsVisible() then sheet:Refresh() end end)
    end,
    Refresh = function(self)
        if not sheet then return end
        sheet.key = UI.charSheetKey or WK:CharKey()
        sheet:Refresh()
    end,
})

WK:On("GET_ITEM_INFO_RECEIVED", function() if sheet and sheet:IsVisible() then sheet:Refresh() end end)

-- Pastilles de l'en-tête : le perso affiché
UI.CHIPS.charsheet = function()
    local key = UI.charSheetKey or WK:CharKey()
    local c = WK.DB.global.characters[key]
    if not c then return {} end
    return { { T("Perso"), WK:CharName(c, key), { UI:ClassColor(c.class) }, "characters" },
             { T("Niveau"), tostring(c.level or "-") },
             { T("Or"), UI:GoldText(c.money) },
             { T("Temps de jeu"), WK:FormatTime(c.played) },
             { T("Royaume"), UI:FactionRealm(c) } }
end
