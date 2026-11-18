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
    mid:SetHeight(178)
    UI:Panel(mid, 12, C.bg, C.border)
    f.mid = mid
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

    -- Onglet BiS : meilleur objet trouvable en donjon par emplacement
    local bsc = UI:Scroll(f)
    bsc:SetPoint("TOPLEFT", 0, -98)
    bsc:SetPoint("BOTTOMRIGHT")
    bsc:Hide()
    f.bsc = bsc
    f.bisInfo = UI:Text(bsc.child, 11, C.muted)
    f.bisCard = UI:Card(bsc.child, "")
    f.bisNote = UI:Text(bsc.child, 10, C.dim)
    f.bisNote:SetText(T("Meilleur objet des donjons (hors raids) que ta classe peut porter, selon ce qui compte pour elle. Clic sur un objet : guidage vers le donjon."))
    f.bisClear = UI:Button(bsc.child, "Vider", nil, 24, "danger")
    f.bisClear:SetScript("OnClick", function() WK.modules.BiS:ClearList(f.key) end)
    f.bisHeads = {}
    for i, h in ipairs({ "Emplacement", "Porté", "Meilleur trouvable", "Où", "Gain" }) do
        local t = UI:Text(f.bisCard, 10, C.dim)
        t:SetText(UI:Upper(T(h)))
        f.bisHeads[i] = t
    end
    f.bisRows = {}
    for i = 1, #WK.modules.BiS.SLOTS do
        local r = CreateFrame("Frame", nil, f.bisCard)
        r:SetHeight(28)
        r.slot = UI:Text(r, 12, C.muted)
        r.wIcon = r:CreateTexture(nil, "ARTWORK"); r.wIcon:SetSize(20, 20)
        r.wText = UI:Text(r, 11, C.muted)
        r.item = CreateFrame("Button", nil, r)
        r.item:SetHeight(24)
        r.bIcon = r.item:CreateTexture(nil, "ARTWORK"); r.bIcon:SetSize(20, 20); r.bIcon:SetPoint("LEFT", 0, 0)
        r.bText = UI:Text(r.item, 12); r.bText:SetPoint("LEFT", 26, 0); r.bText:SetPoint("RIGHT", 0, 0)
        r.where = UI:Text(r, 11, C.muted)
        r.gain = UI:Text(r, 12, C.positive)
        r.wish = UI:Button(r, "Envie", 76, 22, "secondary", "star")
        r.item:SetScript("OnEnter", function(s)
            if not r.e then return end
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            if GameTooltip.SetItemByID then GameTooltip:SetItemByID(r.e.id) end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(T("Clic : guidage vers le donjon"), 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        r.item:SetScript("OnLeave", function() GameTooltip:Hide() end)
        r.item:SetScript("OnClick", function() if r.e then WK.modules.Dungeons:GuideTo(r.e.d) end end)
        r.wish:SetScript("OnClick", function()
            if r.e then WK.modules.Dungeons:ToggleWish(r.e.id, r.e.d.key, f.key); f:Refresh() end
        end)
        -- Ma liste BiS : champ (Maj+clic sur un objet, glisser-déposer ou n°) et bouton Retirer
        r.input = UI:Input(r, 240, 24, T("Maj+clic, glisse un objet ou tape son n°"))
        r.input.edit.acceptLinks = true
        local function setFrom(id)
            if not id or not r.slotID then return end
            WK.modules.BiS:Set(f.key, r.slotID, id)
            r.input:SetText("")
            r.input.edit:ClearFocus()
        end
        r.input.onChange = function(text, user)
            if not text or text == "" then return end
            local id = WK:ParseItemID(text) or (text:match("^%s*(%d+)%s*$") and tonumber(text))
            if id and (text:find("|H", 1, true) or not user) then setFrom(id) end
        end
        r.input.onEnter = function(text)
            local id = WK:ParseItemID(text) or tonumber(text or "")
            if id then setFrom(id) end
        end
        local function drop()
            local kind, id = GetCursorInfo and GetCursorInfo()
            if kind == "item" and id then setFrom(id); if ClearCursor then ClearCursor() end end
        end
        r.item:SetScript("OnReceiveDrag", drop)
        r.item:HookScript("OnMouseUp", drop)
        r:EnableMouse(true)
        r:SetScript("OnReceiveDrag", drop)
        r.clear = UI:Button(r, "Retirer", 76, 22, "danger")
        r.clear:SetScript("OnClick", function() if r.slotID then WK.modules.BiS:Set(f.key, r.slotID, nil) end end)
        f.bisRows[i] = r
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
    local cw = SIDE_W - 28
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
    for i, tr in ipairs(f.trees) do
        local t = trees[i]
        tr:SetShown(any and t ~= nil)
        if any and t then
            tr:ClearAllPoints()
            tr:SetPoint("TOPLEFT", (i - 1) * (tw + 12), -(any and 28 or 48))
            tr:SetSize(tw, th)
            tr.title:SetText(t.name)
            tr.pts:SetText(t.points or 0)
            if (t.points or 0) > 0 then tr.pts:SetTextColor(r, g, b) else tr.pts:SetTextColor(unpack(C.dim)) end
            local cols = t.cols or 4
            for _, d in ipairs(t.list or {}) do cols = math.max(cols, d[4]) end
            local gx = math.floor((tw - (cols * cs + (cols - 1) * cg)) / 2)
            for _, cell in ipairs(tr.cells) do cell:Hide() end
            for j, d in ipairs(t.list or {}) do
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
                cell.edge:SetVertexColor(col[1], col[2], col[3], 1)
                cell.rk:SetText(rank .. "/" .. max)
                local tc = rank > 0 and col or C.dim
                cell.rk:SetTextColor(tc[1], tc[2], tc[3])
                cell.rkBox:SetWidth(math.max(22, math.ceil(cell.rk:GetStringWidth() or 0) + 8))
                cell.rkBox.border:SetColor(col[1], col[2], col[3], rank > 0 and 1 or 0.6)
                cell:Show()
            end
        end
    end
    f.tsc:SetContentHeight((any and (28 + th) or 60) + 8)
end

-- Onglet BiS, « Ma liste BiS » : objets choisis à la main par emplacement
local refreshBisList
-- Onglet BiS
local function refreshBis(f, c)
    local W = math.max(600, (f.bsc:GetWidth() or 840) - 12)
    f.bsc.child:SetWidth(W)
    return refreshBisList(f, c, W)
end

refreshBisList = function(f, c, W)
    local B, D = WK.modules.BiS, WK.modules.Dungeons
    local list = B:List(f.key)
    local n, worn = 0, 0
    local gear = c.gear or {}
    local wornSet = {}
    for _, l in pairs(gear) do local id = WK:ParseItemID(l); if id then wornSet[id] = true end end
    for _, id in pairs(list) do n = n + 1; if wornSet[id] then worn = worn + 1 end end
    f.bisInfo:ClearAllPoints(); f.bisInfo:SetPoint("TOPLEFT", f.bsc.child, "TOPLEFT", 4, -10)
    f.bisInfo:SetText(string.format(T("Ma liste BiS  ·  %d / %d portés"), worn, n))
    f.bisClear:ClearAllPoints(); f.bisClear:SetPoint("TOPRIGHT", f.bsc.child, "TOPRIGHT", -4, -4)
    local card = f.bisCard
    card:ClearAllPoints(); card:SetPoint("TOPLEFT", 0, -38); card:SetWidth(W)
    local XS = { 16, 120, 220, math.floor(W * 0.55), W - 190 }
    for i, t in ipairs(f.bisHeads) do t:ClearAllPoints(); t:SetPoint("TOPLEFT", XS[i], -16) end
    f.bisHeads[3]:SetText(UI:Upper(T("Objet de ta liste"))); f.bisHeads[5]:SetText(UI:Upper(T("État")))
    local y = -38
    for i, r in ipairs(f.bisRows) do
        local def = B.SLOTS[i]
        r.slotID = def[1]
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, y); r:SetPoint("TOPRIGHT", 0, y)
        r.slot:ClearAllPoints(); r.slot:SetPoint("LEFT", XS[1], 0); r.slot:SetText(T(def[2]))
        r.wIcon:ClearAllPoints(); r.wIcon:SetPoint("LEFT", XS[2], 0)
        r.wText:ClearAllPoints(); r.wText:SetPoint("LEFT", XS[2] + 26, 0)
        local wl = gear[def[1]]
        if wl then
            local d = itemData(wl)
            r.wIcon:SetTexture(d and d.icon or nil); r.wIcon:Show()
            r.wText:SetText(d and d.ilvl and string.format(T("niv. %d"), d.ilvl) or "")
        else
            r.wIcon:Hide(); r.wText:SetText(T("vide"))
        end
        r.wish:Hide()
        r.where:ClearAllPoints(); r.where:SetPoint("LEFT", XS[4], 0); r.where:SetWidth(XS[5] - XS[4] - 10)
        r.gain:ClearAllPoints(); r.gain:SetPoint("LEFT", XS[5], 0)
        r.clear:ClearAllPoints(); r.clear:SetPoint("RIGHT", -12, 0)
        local id = list[def[1]]
        if id then
            r.input:Hide(); r.item:Show(); r.clear:Show()
            r.item:ClearAllPoints(); r.item:SetPoint("LEFT", XS[3], 0); r.item:SetWidth(XS[4] - XS[3] - 12)
            local name, _, q = WK.GetItemInfo(id)
            local qc = QUALITY[q or 1] or QUALITY[1]
            r.bIcon:SetTexture((C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or nil); r.bIcon:Show()
            r.bText:SetText(name or ("#" .. id)); r.bText:SetTextColor(qc[1], qc[2], qc[3])
            local d, boss, drop = B:Source(id)
            r.e = d and { id = id, d = d } or nil
            if d then
                local where = D:Name(d) .. " · " .. (boss.trash and T("monstres") or D:BossName(boss))
                if drop then where = where .. string.format(" · %s %%", string.format("%.0f", drop)) end
                r.where:SetText(where)
            else
                r.where:SetText(T("hors donjon (artisanat, quête, raid…)"))
            end
            if wornSet[id] then r.gain:SetText(T("porté")); r.gain:SetTextColor(unpack(C.positive))
            elseif c.bags and c.bags[id] then r.gain:SetText(T("dans les sacs")); r.gain:SetTextColor(unpack(C.gold))
            elseif c.bank and c.bank[id] then r.gain:SetText(T("à la banque")); r.gain:SetTextColor(unpack(C.gold))
            else r.gain:SetText(T("à obtenir")); r.gain:SetTextColor(unpack(C.muted)) end
        else
            r.e = nil
            r.item:Hide(); r.bIcon:Hide(); r.clear:Hide()
            r.input:ClearAllPoints(); r.input:SetPoint("LEFT", XS[3], 0); r.input:SetWidth(math.max(160, XS[4] - XS[3] - 12)); r.input:Show()
            r.where:SetText(""); r.gain:SetText("")
        end
        y = y - 30
    end
    card:SetHeight(-y + 10)
    f.bisNote:ClearAllPoints(); f.bisNote:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 4, -8)
    f.bisNote:SetText(T("Ta liste, à remplir toi-même (par exemple pour le niveau 60) : Maj+clic sur un objet avec le champ actif, glisser-déposer, ou son n°. Les objets de ta liste le disent dans leur infobulle."))
    f.bsc:SetContentHeight(38 - y + 40)
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
    if f.tab == "talents" then return refreshTalents(f, c) end
    if f.tab == "bis" then return refreshBis(f, c) end
    f.lrows:Reset(); f.lheads:Reset()
    -- largeurs : colonne de droite fixe, la gauche prend le reste
    local W = math.max(600, (f.sc:GetWidth() or 840) - 12)
    f.sc.child:SetWidth(W)
    local leftW = W - SIDE_W - COL_GAP
    local view = setmetatable({ key = key }, { __index = c })
    -- deux rangées alignées : Équipement | Stats, puis Réputations | Métiers (chaque rangée à la hauteur
    -- de sa plus grande carte)
    local GEAR_H = 46 + 8 * SLOT_STEP
    refreshGear(f, view)
    local sh = refreshStats(f, c)
    local row1 = math.max(GEAR_H, sh)
    f.gearCard:ClearAllPoints(); f.gearCard:SetPoint("TOPLEFT", 0, 0); f.gearCard:SetSize(leftW, row1)
    f:PlaceKpis()
    f.statCard:ClearAllPoints(); f.statCard:SetPoint("TOPLEFT", leftW + COL_GAP, 0); f.statCard:SetSize(SIDE_W, row1)
    local y2 = row1 + COL_GAP
    f.repCard:ClearAllPoints(); f.repCard:SetPoint("TOPLEFT", 0, -y2); f.repCard:SetWidth(leftW)
    f.profCard:ClearAllPoints(); f.profCard:SetPoint("TOPLEFT", leftW + COL_GAP, -y2); f.profCard:SetWidth(SIDE_W)
    local rh = refreshReps(f, c, f.repCard, leftW)
    local ph = refreshProfs(f, c, f.profCard, SIDE_W)
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
