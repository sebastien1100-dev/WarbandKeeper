local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Réglages de la fiche (roue en haut à droite) : settings.ui.sheet = { ilvl, enchant, statColor }
local function sheetCfg()
    local s = WK.DB.global.settings.ui
    s.sheet = s.sheet or {}
    local c = s.sheet
    if c.ilvl == nil then c.ilvl = true end
    if c.enchant == nil then c.enchant = true end
    if c.statColor == nil then c.statColor = true end
    if type(c.chips) ~= "table" then c.chips = { "ilvl", "armor", "dur" } end
    return c
end
UI.SheetConfig = sheetCfg
local HEAD_MAX = 5 -- pastilles d'en-tête au plus

-- Fiche de personnage : page « charsheet » de la fenêtre (hors barre latérale, Persos y reste en
-- surbrillance), ouverte au clic sur un perso (pages Persos et Résumé), pour n'importe quel perso du compte.
-- Une seule page qui défile : à gauche Équipement (emplacements autour du portrait : cadre à la couleur de
-- qualité, niveau d'objet, point = enchanté ; armure, durabilité, sacs) puis Réputations (les plus avancées,
-- « Tout voir ») ; à droite Stats (barre colorée pour ce qui compte pour la classe, combat, résistances)
-- puis Métiers. Niveau moyen de l'équipement dans l'en-tête.
-- Données : Modules/Gear.lua (relevées à chaque connexion du perso), c.professions.
local SQ = 34
local sheet
local buildSpells, refreshSpells, spellChips -- onglet Sorts (plus bas)
local buildWeapons, refreshWeapons -- onglet Armes (plus bas)

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
UI.StatWeights = WEIGHTS -- poids des caractéristiques par classe (aussi pour l'amélioration à porter, Modules/BagHelp.lua)
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
    -- 17 emplacements comptés (1-3, 5-18, distance comprise), cases vides à 0, comme le jeu
    return total / 17
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
    b.dot:SetVertexColor(C.info[1], C.info[2], C.info[3])
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
    b.wkNoCompare = true -- objet porté : pas d'infobulle de comparaison « Équipé » (il se comparerait à lui-même)
    b:SetScript("OnEnter", function(s)
        if not s.link then return end
        UI:TooltipOwner(s, "ANCHOR_RIGHT")
        if not pcall(GameTooltip.SetHyperlink, GameTooltip, s.link) then GameTooltip:SetText(s.link) end
        GameTooltip:Show()
        UI:HideCompare()
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
            self.lvl:SetText(d.ilvl and tostring(d.ilvl) or ""); self.lvl:SetShown(sheetCfg().ilvl)
            self.sub:SetText(d.ilvl and string.format(T("niv. %d"), d.ilvl) or "")
            self.dot:SetShown(d.enchant and sheetCfg().enchant)
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


-- Chiffres possibles des pastilles d'en-tête : { clé, libellé, valeur(c) -> texte, couleur?, infobulle }
local function durColor(d)
    if not d then return nil end
    local p = math.max(0, math.min(1, d / 100))
    local g, n, y = C.positive, C.negative, C.gold
    local a, b, t
    if p >= 0.5 then a, b, t = y, g, (p - 0.5) * 2 else a, b, t = n, y, p * 2 end
    return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end
local function statOf(key, pct) return function(c) local v = c.stats and c.stats[key]; return v and fmt(v, pct) end end
UI.SHEET_CHIPS = {
    { "ilvl", "Niv. objet", function(c) local a = averageIlvl(c.gear); return a and (string.format("%.1f", a):gsub("%.", ",")) end, nil, "Niveau d'objet moyen de l'équipement porté" },
    { "armor", "Armure", statOf("armor") },
    { "dur", "Durabilité", function(c) local d = c.durability or (c.gear and 100); return d and (math.floor(d) .. " %") end },
    { "bags", "Sacs libres", function(c) return c.totalSlots and ((c.freeSlots or 0) .. "/" .. c.totalSlots) end },
    { "str", "Force", statOf("str") }, { "agi", "Agilité", statOf("agi") }, { "sta", "Endurance", statOf("sta") },
    { "int", "Intelligence", statOf("int") }, { "spi", "Esprit", statOf("spi") },
    { "ap", "Puiss. d'attaque", statOf("ap") }, { "crit", "Critique", statOf("crit", true) }, { "hit", "Toucher", statOf("hit", true) },
    { "spell", "Puiss. des sorts", statOf("spell") }, { "heal", "Soins", statOf("heal") }, { "scrit", "Crit. des sorts", statOf("scrit", true) },
    { "dodge", "Esquive", statOf("dodge", true) }, { "parry", "Parade", statOf("parry", true) }, { "block", "Blocage", statOf("block", true) },
    { "gold", "Or", function(c) return c.money and UI:ShortGold(c.money) end },
}
-- valeurs des pastilles choisies pour ce perso : { { label, value, color, tip } }
function UI.SheetChipValues(c)
    local out = {}
    local byKey = {}
    for _, d in ipairs(UI.SHEET_CHIPS) do byKey[d[1]] = d end
    for _, k in ipairs(sheetCfg().chips) do
        local d = byKey[k]
        if d and #out < HEAD_MAX then
            local ok, v = pcall(d[3], c)
            local color = d[4]
            if k == "dur" then color = durColor(c.durability or (c.gear and 100)) end
            table.insert(out, { label = d[2], value = (ok and v) or "-", color = color, tip = d[5] and T(d[5]) })
        end
    end
    return out
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
    -- fiche d'un autre perso : retour direct au perso connecté
    f.mine = UI:Button(f, "Mon perso", nil, 24, "secondary", "users")
    f.mine:SetScript("OnClick", function() UI:ShowCharSheet(WK:CharKey()) end)
    f.mine:Hide()
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
    -- pastilles d'en-tête, à gauche de la roue des réglages : chiffres choisis dans la roue (Fiche)
    f.hchips = {}
    for i = 1, HEAD_MAX do
        local ch = CreateFrame("Frame", nil, f)
        ch:SetHeight(28)
        ch.edge = UI:Rounded(ch, 14, 0, "BACKGROUND", 0)
        ch.bg = UI:Rounded(ch, 13, 1, "BACKGROUND", 1)
        ch.text = UI:Text(ch, 12); ch.text:SetPoint("CENTER")
        ch:EnableMouse(true)
        ch:SetScript("OnEnter", function(s)
            if not s.tip then return end
            UI:TooltipOwner(s, "ANCHOR_BOTTOM"); GameTooltip:SetText(s.tip, 1, 1, 1); GameTooltip:Show()
        end)
        ch:SetScript("OnLeave", function() GameTooltip:Hide() end)
        ch:Hide()
        f.hchips[i] = ch
    end

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
    for _, t in ipairs({ { "sheet", "Fiche" }, { "talents", "Talents" }, { "spells", "Sorts" }, { "weapons", "Armes" }, { "bis", "BiS" } }) do
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
        if b.RegisterForClicks then b:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
        -- mode plan : clic = point suivant du plan, clic droit = retirer le dernier
        b:SetScript("OnClick", function(s, btn)
            if not f.planEdit or tr.preview then return end
            local P = WK.modules.TalentPlan
            if btn == "RightButton" then P:RemoveLast(f.key, f.planEdit)
            else
                local ok, why = P:AddStep(f.key, f.planEdit, s.tab, s.index)
                if not ok and why then WK:Print(why) end
            end
        end)
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
        UI:Panel(b.rkBox, 7, { C.bg[1], C.bg[2], C.bg[3], 0.95 }, C.border)
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
        tr.preview = true
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
    UI:OnAccent(function() dlg.border:SetColor(UI:Accent()) end)
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

    -- Plans de montée (Modules/TalentPlan.lua) : carte sous les builds, mode plan sur les arbres
    f.pcard = UI:Card(tsc.child, T("Plans de montée"))
    f.pcount = UI:Text(f.pcard, 11, C.muted); f.pcount:SetPoint("LEFT", f.pcard.title, "RIGHT", 10, 0)
    f.pnew = UI:Button(f.pcard, "Nouveau plan", nil, 26, "primary"); f.pnew:SetPoint("TOPRIGHT", -12, -10)
    f.pimport = UI:Button(f.pcard, "Importer un code", nil, 26, "secondary"); f.pimport:SetPoint("RIGHT", f.pnew, "LEFT", -8, 0)
    f.ppanel = UI:Button(f.pcard, "Ouvrir le panneau", nil, 26, "secondary"); f.ppanel:SetPoint("RIGHT", f.pimport, "LEFT", -8, 0)
    f.ppanel:SetScript("OnClick", function() if UI.ToggleTalentPlan then UI:ToggleTalentPlan() end end)
    f.pempty = UI:Text(f.pcard, 11, C.muted); f.pempty:SetPoint("TOPLEFT", 16, -48)
    f.pempty:SetText(T("Aucun plan. « Nouveau plan » puis clique les talents dans l'ordre, un plan « Montée enregistrée » se remplit aussi tout seul quand tu prends tes talents."))
    f.pempty:SetPoint("RIGHT", -16, 0); f.pempty:SetJustifyH("LEFT"); if f.pempty.SetWordWrap then f.pempty:SetWordWrap(true) end
    f.prows = UI:Pool(function()
        local r = CreateFrame("Frame", nil, f.pcard)
        r:SetHeight(32)
        r.line = r:CreateTexture(nil, "ARTWORK"); r.line:SetTexture("Interface\\Buttons\\WHITE8X8")
        r.line:SetVertexColor(C.border[1], C.border[2], C.border[3], 0.8); r.line:SetHeight(1); r.line:SetPoint("TOPLEFT"); r.line:SetPoint("TOPRIGHT")
        r.name = UI:Text(r, 12); r.name:SetPoint("LEFT", 14, 0)
        r.info = UI:Text(r, 11, C.muted)
        r.del = UI:Button(r, "Suppr.", nil, 22, "danger"); r.del:SetPoint("RIGHT", -6, 0)
        r.ren = UI:Button(r, "Renommer", nil, 22, "secondary"); r.ren:SetPoint("RIGHT", r.del, "LEFT", -6, 0)
        r.code = UI:Button(r, "Code", nil, 22, "secondary"); r.code:SetPoint("RIGHT", r.ren, "LEFT", -6, 0)
        r.edit = UI:Button(r, "Modifier", nil, 22, "secondary"); r.edit:SetPoint("RIGHT", r.code, "LEFT", -6, 0)
        r.act = UI:Button(r, "Suivre", nil, 22, "primary"); r.act:SetPoint("RIGHT", r.edit, "LEFT", -6, 0)
        return r
    end)
    -- bandeau du mode plan, au-dessus des arbres
    f.planBar = CreateFrame("Frame", nil, tsc.child)
    f.planBar:SetHeight(26)
    -- fond : violet du mode plan (C.plan) très assombri
    UI:Panel(f.planBar, 8, { C.plan[1] * 0.2, C.plan[2] * 0.2, C.plan[3] * 0.19, 1 }, C.plan)
    f.planBarText = UI:Text(f.planBar, 11); f.planBarText:SetPoint("LEFT", 10, 0)
    f.planDone = UI:Button(f.planBar, "Terminer", nil, 20, "primary"); f.planDone:SetPoint("RIGHT", -4, 0)
    f.planDone:SetScript("OnClick", function() f.planEdit = nil; f:Refresh() end)
    f.planBar:Hide()
    local P = WK.modules.TalentPlan
    f.pnew:SetScript("OnClick", function()
        f:Ask(T("Nouveau plan de montée"), T("Donne-lui un nom ; tu cliqueras ensuite les talents dans l'ordre (clic droit : retirer le dernier)."),
            T("Montée de niveau"), function(v)
                f.planEdit = P:New(f.key, (v ~= "" and v) or T("Montée de niveau"))
            end, T("Créer"))
    end)
    f.pimport:SetScript("OnClick", function()
        f:Ask(T("Importer un plan"), T("Colle un code de plan (WKP1:…) d'un joueur de la même classe."), "", function(v)
            local i, why = P:Import(f.key, v)
            if not i then WK:Print(T("Import impossible : ") .. (why or "")) end
        end, T("Importer"))
    end)

    -- Onglet Sorts : sorts de classe à apprendre (Modules/ClassSpells.lua)
    buildSpells(f)
    -- Onglet Armes : compétences d'armes (Modules/WeaponSkills.lua)
    buildWeapons(f)

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
    -- actions : « Équiper ce que j'ai », puis Partager, Copier d'un perso et le menu « ⋯ » en petites icônes
    f.bisShare = UI:IconButton(bsc.child, "send", 26, T("Partager (liens dans le chat)"))
    f.bisCopy = UI:IconButton(bsc.child, "users", 26, T("Copier la liste d'un autre perso"))
    f.bisMore = UI:IconButton(bsc.child, "menu", 26, T("Renommer, dupliquer, code, importer, vider, supprimer"))
    f.bisEquip = UI:Button(bsc.child, "Équiper ce que j'ai", nil, 26, "primary")
    f.bisEquip:SetScript("OnClick", function()
        local n, why = B:EquipOwned()
        WK:Print(n > 0 and string.format(T("%d objet(s) de la liste équipé(s)."), n) or (why or T("Rien à équiper : aucun objet de la liste dans tes sacs.")))
    end)
    -- listes en onglets (comme Fiche / Talents / BiS), « + Nouvelle » en dernier
    f.bisTabs = UI:Pool(function()
        local b = CreateFrame("Button", nil, bsc.child)
        b:SetHeight(28)
        b.label = UI:Text(b, 12); b.label:SetPoint("LEFT", 12, 1)
        b.count = UI:Text(b, 10, C.dim); b.count:SetPoint("LEFT", b.label, "RIGHT", 6, 0)
        b.under = b:CreateTexture(nil, "OVERLAY"); b.under:SetTexture("Interface\\Buttons\\WHITE8X8")
        b.under:SetHeight(2); b.under:SetPoint("BOTTOMLEFT", 0, -1); b.under:SetPoint("BOTTOMRIGHT", 0, -1)
        b:SetScript("OnEnter", function(s) s.hover = true; if s.Paint then s:Paint() end end)
        b:SetScript("OnLeave", function(s) s.hover = false; if s.Paint then s:Paint() end end)
        function b:Paint()
            local r, g, bl = UI:Accent()
            if self.sel then self.label:SetTextColor(unpack(C.text)) else self.label:SetTextColor(r, g, bl, self.hover and 1 or 0.85) end
            self.under:SetVertexColor(r, g, bl, 1); self.under:SetShown(self.sel)
        end
        return b
    end)
    f.bisTabLine = bsc.child:CreateTexture(nil, "ARTWORK")
    f.bisTabLine:SetTexture("Interface\\Buttons\\WHITE8X8"); f.bisTabLine:SetHeight(1)
    f.bisTabLine:SetVertexColor(C.border[1], C.border[2], C.border[3], 1)
    f.bisNew = CreateFrame("Button", nil, bsc.child)
    f.bisNew:SetHeight(28)
    f.bisNew.label = UI:Text(f.bisNew, 12); f.bisNew.label:SetPoint("LEFT", 12, 1); f.bisNew.label:SetText(T("+ Nouvelle"))
    f.bisNew:SetWidth(f.bisNew.label:GetStringWidth() + 24)
    -- menu « ⋯ »
    local menu = CreateFrame("Frame", nil, bsc.child)
    menu:SetSize(170, 6 * 26 + 12)
    menu:SetFrameLevel(bsc.child:GetFrameLevel() + 30)
    UI:Panel(menu, 10, C.bg, { UI:Accent() })
    UI:OnAccent(function() menu.border:SetColor(UI:Accent()) end)
    menu:Hide()
    f.bisMenu = menu
    f.bisMore:SetScript("OnClick", function() menu:SetShown(not menu:IsShown()) end)
    f.bisLBtns = {}
    for i, lab in ipairs({ "Dupliquer", "Renommer", "Code", "Importer", "Supprimer la liste" }) do
        local btn = UI:Button(menu, lab, 154, 22, i == 5 and "danger" or "ghost")
        btn:SetPoint("TOPLEFT", 8, -6 - (i - 1) * 26)
        btn:SetScript("PostClick", function() menu:Hide() end) -- PostClick : survit au SetScript("OnClick") plus bas
        f.bisLBtns[i] = btn
    end
    f.bisClear = UI:Button(menu, "Vider la liste", 154, 22, "danger")
    f.bisClear:SetPoint("TOPLEFT", 8, -6 - 5 * 26)
    f.bisClear:SetScript("PostClick", function() menu:Hide() end)
    -- clic en dehors du menu (et du bouton qui l'ouvre) : on le ferme
    menu:SetScript("OnShow", function(s) s.wasDown = true end)
    menu:SetScript("OnUpdate", function(s)
        local down = IsMouseButtonDown and (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton"))
        if down and not s.wasDown and not (s:IsMouseOver() or f.bisMore:IsMouseOver()) then s:Hide() end
        s.wasDown = down
    end)
    f.bisNew:SetScript("OnClick", function()
        f:Ask(T("Nouvelle liste BiS"), T("Donne-lui un nom (JcE, tank, montée, JcJ…)."), T("Nouvelle liste"), function(v)
            B:NewList(f.key, (v ~= "" and v) or T("Nouvelle liste"))
        end, T("Créer"))
    end)
    f.bisLBtns[1]:SetScript("OnClick", function()
        local i = B:ActiveIndex(f.key)
        local l = B:Lists(f.key)[i]
        B:NewList(f.key, (l.name or "") .. " " .. T("(copie)"), l.items)
    end)
    f.bisLBtns[2]:SetScript("OnClick", function()
        local i = B:ActiveIndex(f.key)
        f:Ask(T("Renommer la liste"), nil, B:Lists(f.key)[i].name or "", function(v) B:RenameList(f.key, i, v) end, T("Renommer"))
    end)
    f.bisLBtns[3]:SetScript("OnClick", function()
        f:Ask(T("Code de la liste"), T("Copie ce code (Ctrl+C) pour la partager ; « Importer » la reprend."), B:ExportList(f.key, B:ActiveIndex(f.key)) or "", nil, T("Fermer"))
    end)
    f.bisLBtns[4]:SetScript("OnClick", function()
        f:Ask(T("Importer une liste"), T("Colle un code de liste BiS (WKB1:…)."), "", function(v)
            local i, why = B:ImportList(f.key, v)
            if not i then WK:Print(T("Import impossible : ") .. (why or "")) end
        end, T("Importer"))
    end)
    f.bisLBtns[5]:SetScript("OnClick", function()
        local i = B:ActiveIndex(f.key)
        f:Ask(T("Supprimer la liste ?"), string.format(T("« %s » sera supprimée."), B:Lists(f.key)[i].name or ""), nil, function() B:DeleteList(f.key, i) end, T("Supprimer"))
    end)
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
    local okm, bm = pcall(CreateFrame, "DressUpModel", nil, f.bisMid)
    if okm and bm then
        bm:SetPoint("TOPLEFT", 4, -40); bm:SetPoint("BOTTOMRIGHT", -4, 42)
        bm:EnableMouse(true)
        bm:SetScript("OnMouseDown", function(m) m.drag = GetCursorPosition() end)
        bm:SetScript("OnMouseUp", function(m) m.drag = nil end)
        bm:SetScript("OnUpdate", function(m)
            if not m.drag then return end
            local x = GetCursorPosition()
            m.rot = (m.rot or 0) + (x - m.drag) * 0.01; m.drag = x
            if m.SetFacing then m:SetFacing(m.rot) end
        end)
        bm:Hide()
        f.bisModel = bm
    end
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
        -- pastille d'état : vert porté, jaune dans les sacs ou la banque, gris à obtenir
        b.dot = b:CreateTexture(nil, "OVERLAY", nil, 3)
        b.dot:SetTexture(UI.MEDIA .. "circle"); b.dot:SetSize(10, 10)
        b.dot:SetPoint("CENTER", b.edge, "BOTTOMRIGHT", -1, 1)
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
            local kind, id
            if GetCursorInfo then kind, id = GetCursorInfo() end
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
    local LEFT_S, RIGHT_S, MID_S = { 1, 2, 3, 15, 5, 4, 19, 9 }, { 10, 6, 7, 8, 11, 12, 13, 14 }, { 16, 17, 18 }
    for _, sl in ipairs(LEFT_S) do local t = tile(bsc.child, "left"); t.slot = sl; t.side = "left"; table.insert(f.bisTiles, t) end
    for _, sl in ipairs(RIGHT_S) do local t = tile(bsc.child, "right"); t.slot = sl; t.side = "right"; table.insert(f.bisTiles, t) end
    for _, sl in ipairs(MID_S) do local t = tile(bsc.child, "mid"); t.slot = sl; t.side = "mid"; table.insert(f.bisTiles, t) end
    -- bascule de l'aperçu : la liste ou l'équipement porté
    f.bisSwList = UI:Button(f.bisMid, "La liste", nil, 22, "primary")
    f.bisSwWorn = UI:Button(f.bisMid, "Mon équipement", nil, 22, "secondary")
    f.bisSwList:SetPoint("BOTTOMRIGHT", f.bisMid, "BOTTOM", -2, 12)
    f.bisSwWorn:SetPoint("BOTTOMLEFT", f.bisMid, "BOTTOM", 2, 12)
    f.bisSwList:SetScript("OnClick", function() f.bisShowWorn = nil; f:Refresh() end)
    f.bisSwWorn:SetScript("OnClick", function() f.bisShowWorn = true; f:Refresh() end)
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
            local link = id and select(2, WK.GetItemInfo(id))
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
        f:Ask(T("Copier une liste BiS"), T("Tape le nom du perso dont copier la liste affichée (elle devient une nouvelle liste ici) : ") .. table.concat(names, ", "), names[1], function(v)
            for i, nm in ipairs(names) do
                if nm:lower() == (v or ""):lower() then
                    local src = B:Lists(keys[i])[B:ActiveIndex(keys[i])]
                    B:NewList(f.key, (src.name or "") .. " · " .. nm, src.items)
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
    UI:OnAccent(function() pk.border:SetColor(UI:Accent()) end)
    pk:Hide()
    f.picker = pk
    pk.title = UI:Text(pk, 14); pk.title:SetPoint("TOPLEFT", 16, -18)
    pk.close = UI:IconButton(pk, "close", 26, T("Fermer")); pk.close:SetPoint("TOPRIGHT", -12, -12)
    pk.close:SetScript("OnClick", function() pk:Hide() end)
    pk.search = UI:Input(pk, 530, 28, T("Rechercher un objet…"), "search")
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
    -- filtres rangés par ligne : nom à gauche, choix collés dans un même bloc
    pk.rowBgs, pk.rowLabels = {}, {}
    function pk:Chips()
        self.chips:Reset()
        local fl = self.f
        local y = -52
        local n = 0
        local function row(label, opts)
            n = n + 1
            local lab = self.rowLabels[n]
            if not lab then lab = UI:Text(self, 10, C.dim); self.rowLabels[n] = lab end
            lab:SetText(UI:Upper(T(label))); lab:ClearAllPoints(); lab:SetPoint("TOPLEFT", 16, y - 8); lab:Show()
            local bg = self.rowBgs[n]
            if not bg then
                bg = CreateFrame("Frame", nil, self)
                UI:Panel(bg, 9, C.surface, C.border)
                self.rowBgs[n] = bg
            end
            local x = 2
            for _, o in ipairs(opts) do
                local btn = self.chips:Get()
                btn:SetParent(bg); btn:SetFrameLevel(bg:GetFrameLevel() + 2)
                btn:SetLabel(T(o[1])); btn:SetWidth(btn.label:GetStringWidth() + 20); btn:SetHeight(20)
                btn:SetStyle(o[2] and "primary" or "ghost")
                btn:ClearAllPoints(); btn:SetPoint("TOPLEFT", x, -2)
                local fn = o[3]
                btn:SetScript("OnClick", function() fn(); self:Chips(); self:Fill() end)
                x = x + btn:GetWidth() + 2
            end
            bg:ClearAllPoints(); bg:SetPoint("TOPLEFT", 96, y); bg:SetSize(x + 1, 24); bg:Show()
            y = y - 30
        end
        local src = {}
        for _, s in ipairs({ { "all", "Toutes" }, { "dungeon", "Donjons" }, { "raid", "Raids" }, { "craft", "Artisanat" }, { "quest", "Quêtes" }, { "other", "Autres" } }) do
            src[#src + 1] = { s[2], fl.source == s[1], function() fl.source = s[1] end }
        end
        row("Source", src)
        local qual = {}
        for _, q in ipairs({ { 2, "Vert et +" }, { 3, "Bleu et +" }, { 4, "Violet et +" } }) do
            qual[#qual + 1] = { q[2], fl.quality == q[1], function() fl.quality = q[1] end }
        end
        row("Qualité", qual)
        local lv = {}
        for _, l in ipairs({ { nil, "Tous" }, { { 50, 60 }, "50-60" }, { { 30, 49 }, "30-49" }, { { 0, 29 }, "1-29" } }) do
            lv[#lv + 1] = { l[2], (fl.level and l[1] and fl.level[1] == l[1][1]) or (not fl.level and not l[1]), function() fl.level = l[1] end }
        end
        row("Niveau", lv)
        if ARMOR_SLOTS[self.slot] then
            local c = WK.DB.global.characters[f.key]
            local ar = { { "Toutes", not fl.armor, function() fl.armor = nil end } }
            for _, sub in ipairs(B:ArmorTypes(c)) do ar[#ar + 1] = { B.ARMOR[sub], fl.armor == sub, function() fl.armor = sub end } end
            row("Armure", ar)
        end
        for i = n + 1, #self.rowBgs do self.rowBgs[i]:Hide(); self.rowLabels[i]:Hide() end
        -- la liste commence sous la dernière rangée de filtres
        for i, t in ipairs(self.heads) do t:ClearAllPoints(); t:SetPoint("TOPLEFT", 12 + PX[i], y - 6) end
        self.list:ClearAllPoints(); self.list:SetPoint("TOPLEFT", 12, y - 22); self.list:SetPoint("BOTTOMRIGHT", -12, 34)
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
    -- couleur selon l'usure : vert à 100 %, jaune vers 50 %, rouge à 0 %
    local dur = c.durability or (c.gear and 100)
    if dur then
        local p = math.max(0, math.min(1, dur / 100))
        local g, n = C.positive, C.negative
        local y = C.gold
        local a, b, t
        if p >= 0.5 then a, b, t = y, g, (p - 0.5) * 2 else a, b, t = n, y, p * 2 end
        f.kpis[2].v:SetTextColor(a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t)
    else
        f.kpis[2].v:SetTextColor(unpack(C.text))
    end
    f.kpis[3].v:SetText(c.totalSlots and ((c.freeSlots or 0) .. "/" .. c.totalSlots) or "-"); f.kpis[3].l:SetText(T("sacs libres"))
    f.noGear:SetShown(not gear)
    f.noGear:SetText(T("Équipement pas encore relevé : connecte ce perso une fois avec cette version."))
end

-- Stats ; rend la hauteur de la carte
-- Couleur des données d'une fiche : l'accent pour le perso connecté ; pour un autre perso, la couleur de sa
-- classe (l'accent suit la classe du perso connecté dans certains thèmes : un chasseur vu depuis un
-- paladin ne doit pas s'afficher en rose)
local function viewAccent(f, c)
    if not c or f.key == WK:CharKey() then return UI:Accent() end
    return UI:ClassColor(c.class)
end

local function refreshStats(f, c)
    local s = c.stats
    local w = WEIGHTS[c.class or ""] or {}
    local r1, g1, b1 = viewAccent(f, c)
    local cls = c.class and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c.class]
    local colorOn = sheetCfg().statColor
    f.hUse:SetText((cls and colorOn) and T("en couleur : utile") or "")
    local maxV = 1
    for _, r in ipairs(f.statRows) do maxV = math.max(maxV, s and s[r.key] or 0) end
    for _, r in ipairs(f.statRows) do
        local v = s and s[r.key]
        r.val:SetText(v and fmt(v) or "-")
        local useful = not colorOn or (w[r.key] or 0.5) >= 0.5
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
    local r1, g1, b1 = viewAccent(f, c)
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

function UI:ShowCharSheet(key, tab)
    if not WK.DB.global.characters[key] then return end
    UI.charSheetKey = key
    UI.charSheetTab = tab -- onglet à ouvrir (« spells » depuis « À faire »), lu par Refresh
    local f = UI:Create()
    -- fenêtre fermée : on oublie le perso choisi (la fenêtre est créée à la demande, et recréée par
    -- un changement d'apparence : le crochet est posé ici, sur la fenêtre du moment)
    if not f.wkSheetHooked then
        f.wkSheetHooked = true
        f:HookScript("OnHide", function() UI.charSheetKey = nil end)
    end
    f:Show()
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
    local r, g, b = viewAccent(f, c)
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
    -- mode plan : les arbres montrent les rangs du plan et, sur chaque talent, ses niveaux
    local P = WK.modules.TalentPlan
    local editPlan = f.planEdit and P:Plans(f.key)[f.planEdit]
    if f.planEdit and not editPlan then f.planEdit = nil end
    local shownTrees = trees
    local ty = 28
    if editPlan then
        local ranks = P:Ranks(editPlan)
        shownTrees = {}
        for ti, t in ipairs(trees) do
            local nt = { name = t.name, cols = t.cols, list = {} }
            for j, d in ipairs(t.list or {}) do nt.list[j] = { d[1], d[2], d[3], d[4], ranks[ti .. ":" .. j] or 0, d[6], d[7], d[8] } end
            shownTrees[ti] = nt
        end
        f.planBar:ClearAllPoints(); f.planBar:SetPoint("TOPLEFT", 0, -26); f.planBar:SetWidth(W); f.planBar:Show()
        f.planBarText:SetText(string.format(T("Mode plan : %s · %d point(s), niveaux %d à %d · clic : point suivant · clic droit : retirer le dernier"),
            UI:Hex(C.plan) .. (editPlan.name or "") .. "|r", #editPlan.steps, P.FIRST_LEVEL, P.FIRST_LEVEL + math.max(0, #editPlan.steps - 1)))
        ty = 58
    else
        f.planBar:Hide()
    end
    paintTrees(f, f.trees, shownTrees, ty, tw, cs, cg, th, mine, nil)
    if editPlan then
        local labels = P:LevelLabels(editPlan)
        for ti, tr in ipairs(f.trees) do
            for j, cell in ipairs(tr.cells) do
                if cell:IsShown() then
                    local lab = labels[ti .. ":" .. j]
                    cell.rk:SetText(lab or "")
                    cell.rkBox:SetShown(lab ~= nil)
                    if lab then cell.rkBox:SetWidth(math.max(22, math.ceil(cell.rk:GetStringWidth() or 0) + 8)) end
                end
            end
        end
    else
        for _, tr in ipairs(f.trees) do for _, cell in ipairs(tr.cells) do cell.rkBox:Show() end end
    end
    th = th + (ty - 28)
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
        if add == 0 and rem == 0 then row.diff:SetText(UI:Hex(C.positive) .. T("actif") .. "|r")
        elseif rem == 0 then row.diff:SetText(string.format(T("+%d point(s) à placer"), add))
        else row.diff:SetText(string.format(UI:Hex(C.negative) .. T("%d à retirer") .. "|r · " .. T("%d à placer"), rem, add)) end
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
    -- plans de montée, sous les builds
    local pcard = f.pcard
    local py = by + y + 20
    pcard:ClearAllPoints(); pcard:SetPoint("TOPLEFT", 0, -py); pcard:SetWidth(W)
    local plans = P:Plans(f.key)
    local _, active = P:Active(f.key)
    f.pcount:SetText(string.format(T("%d plan(s)"), #plans))
    f.pnew:SetEnabled(any)
    f.pempty:SetShown(#plans == 0)
    f.prows:Reset()
    local ry = #plans == 0 and 84 or 44
    for i, pl in ipairs(plans) do
        local row = f.prows:Get()
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 8, -ry); row:SetPoint("TOPRIGHT", -8, -ry)
        row.name:SetText((pl.name or "?") .. (i == active and ("  " .. UI:Hex(C.positive) .. T("suivi") .. "|r") or "") .. (f.planEdit == i and ("  " .. UI:Hex(C.plan) .. T("en cours de modification") .. "|r") or ""))
        row.info:ClearAllPoints(); row.info:SetPoint("LEFT", math.floor(W * 0.42), 0)
        row.info:SetText(#pl.steps > 0 and string.format(T("%d point(s) · niveaux %d à %d"), #pl.steps, P.FIRST_LEVEL, P.FIRST_LEVEL + #pl.steps - 1) or T("vide"))
        row.act:SetShown(i ~= active)
        row.act:SetScript("OnClick", function() P:SetActive(f.key, i) end)
        row.edit:SetLabel(f.planEdit == i and T("Terminer") or T("Modifier"))
        row.edit:SetScript("OnClick", function() f.planEdit = (f.planEdit ~= i) and i or nil; f:Refresh() end)
        row.code:SetScript("OnClick", function()
            f:Ask(T("Code du plan"), T("Copie ce code (Ctrl+C) pour le partager ; « Importer un code » le reprend sur un perso de la même classe."), P:Export(f.key, i) or "", nil, T("Fermer"))
        end)
        row.ren:SetScript("OnClick", function() f:Ask(T("Renommer le plan"), nil, pl.name or "", function(v) P:Rename(f.key, i, v) end, T("Renommer")) end)
        row.del:SetScript("OnClick", function()
            f:Ask(T("Supprimer le plan ?"), string.format(T("« %s » sera supprimé."), pl.name or ""), nil, function()
                if f.planEdit == i then f.planEdit = nil end
                P:Delete(f.key, i)
            end, T("Supprimer"))
        end)
        ry = ry + 34
    end
    pcard:SetHeight(ry + 14)
    f.tsc:SetContentHeight(py + ry + 22)
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
    local c = WK.DB.global.characters[f.key]
    local r, g, b = viewAccent(f, c)
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
            tr.sicon:SetTexture(ic)
            tr.sicon:SetShown(ic ~= nil)
            tr.sicon:SetAlpha(ic and 1 or 0)
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
                -- rangée accessible : 5 points par rangée au-dessus dans cet arbre
                local open = pts >= ((d[3] or 1) - 1) * 5
                if cell.icon.SetDesaturated then cell.icon:SetDesaturated(rank == 0 and not open) end
                cell.icon:SetAlpha(rank > 0 and 1 or (open and 0.9 or 0.3))
                local col = rank >= max and C.gold or rank > 0 and C.positive or (open and { r, g, b } or C.border)
                if cur then
                    local now = WK.modules.Gear.CurRank(cur, i, j, d)
                    if rank > now then col = C.plan elseif rank < now then col = C.negative end
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
local RACE_IDS = { Human = 1, Orc = 2, Dwarf = 3, NightElf = 4, Scourge = 5, Tauren = 6, Gnome = 7, Troll = 8, BloodElf = 10, Draenei = 11 }
local function refreshBis(f, c)
    local B = WK.modules.BiS
    for _, s in ipairs(B.SLOTS) do SLOT_LABEL[s[1]] = s[2] end
    local W = math.max(600, (f.bsc:GetWidth() or 840) - 12)
    f.bsc.child:SetWidth(W)
    local mine = f.key == WK:CharKey()
    local gear = c.gear or {}
    local wornSet = {}
    for _, l in pairs(gear) do local id = WK:ParseItemID(l); if id then wornSet[id] = true end end
    local function counts(items)
        local n, worn, bags = 0, 0, 0
        for _, id in pairs(items) do
            n = n + 1
            if wornSet[id] then worn = worn + 1 elseif (c.bags and c.bags[id]) or (c.bank and c.bank[id]) then bags = bags + 1 end
        end
        return n, worn, bags
    end
    local r1, g1, b1 = UI:Accent()
    local d1, d2, d3 = viewAccent(f, c)
    -- onglets des listes
    local lists, active = B:Lists(f.key), B:ActiveIndex(f.key)
    f.bisTabs:Reset()
    local tx = 0
    for i, l in ipairs(lists) do
        local tb = f.bisTabs:Get()
        local n, worn = counts(l.items)
        tb.label:SetText(l.name or "?")
        tb.count:SetText(worn .. " / " .. n)
        tb:SetWidth(tb.label:GetStringWidth() + tb.count:GetStringWidth() + 30)
        tb.sel = i == active
        tb:Paint()
        tb:SetScript("OnClick", function() f.bisMenu:Hide(); B:SetActiveList(f.key, i) end)
        tb:ClearAllPoints(); tb:SetPoint("TOPLEFT", tx, -2)
        tx = tx + tb:GetWidth() + 2
    end
    f.bisNew:ClearAllPoints(); f.bisNew:SetPoint("TOPLEFT", tx, -2)
    f.bisNew.label:SetTextColor(r1, g1, b1, 0.85)
    f.bisTabLine:ClearAllPoints(); f.bisTabLine:SetPoint("TOPLEFT", 0, -31); f.bisTabLine:SetPoint("TOPRIGHT", 0, -31)
    -- actions à droite des onglets
    f.bisMore:ClearAllPoints(); f.bisMore:SetPoint("TOPRIGHT", f.bsc.child, "TOPRIGHT", -2, -2)
    f.bisCopy:ClearAllPoints(); f.bisCopy:SetPoint("RIGHT", f.bisMore, "LEFT", -6, 0)
    f.bisShare:ClearAllPoints(); f.bisShare:SetPoint("RIGHT", f.bisCopy, "LEFT", -6, 0)
    f.bisEquip:ClearAllPoints(); f.bisEquip:SetPoint("RIGHT", f.bisShare, "LEFT", -8, 0)
    f.bisEquip:SetShown(mine)
    f.bisMenu:ClearAllPoints(); f.bisMenu:SetPoint("TOPRIGHT", f.bisMore, "BOTTOMRIGHT", 0, -4)
    -- progression de la liste affichée
    local list = B:List(f.key)
    local n, worn, bags = counts(list)
    f.bisTitle:Hide()
    f.bisProg:ClearAllPoints(); f.bisProg:SetPoint("TOPLEFT", 2, -44); f.bisProg:SetWidth(160)
    f.bisProg.color = { d1, d2, d3 }; f.bisProg:SetValue(n > 0 and worn / n or 0)
    f.bisInfo:ClearAllPoints(); f.bisInfo:SetPoint("LEFT", f.bisProg, "RIGHT", 10, 0)
    f.bisInfo:SetText(string.format(T("%d / %d obtenus · %d dans les sacs ou la banque"), worn, n, bags))
    -- mannequin centré : 8 emplacements de chaque côté, aperçu au centre, armes dessous
    local DW = math.min(W, 960)
    local x0 = math.floor((W - DW) / 2)
    local colW = 230
    local MIDW = DW - 2 * colW - 28
    local top, step = 64, 50
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
        local inBags = id and ((c.bags and c.bags[id]) or (c.bank and c.bank[id]))
        if id then
            t.icon:SetTexture((C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or "Interface\\Icons\\INV_Misc_QuestionMark")
            t.icon:Show(); t.plus:Hide()
            t.edge:SetVertexColor(qc[1], qc[2], qc[3], 1)
            local dc = wornSet[id] and C.positive or inBags and C.gold or C.dim
            t.dot:SetVertexColor(dc[1], dc[2], dc[3], 1); t.dot:Show()
        else
            t.icon:Hide(); t.plus:Show(); t.plus:SetTextColor(r1, g1, b1, 0.8)
            t.edge:SetVertexColor(C.border[1], C.border[2], C.border[3], 1)
            t.dot:Hide()
        end
        if t.side ~= "mid" then
            if id then
                t.name:SetText(name or (e and e[8]) or ("#" .. id)); t.name:SetTextColor(qc[1], qc[2], qc[3])
                local _, where = B:SourceOf(id)
                t.sub:SetText(T(t.label) .. " · " .. where)
            else
                t.name:SetText(T(t.label)); t.name:SetTextColor(unpack(C.muted))
                t.sub:SetText(T("vide · choisir"))
            end
        end
        t:ClearAllPoints()
        if t.side == "left" then
            t:SetPoint("TOPLEFT", x0, -(top + li * step)); t:SetWidth(colW); li = li + 1
        elseif t.side == "right" then
            t:SetPoint("TOPLEFT", x0 + DW - colW, -(top + ri * step)); t:SetWidth(colW); ri = ri + 1
        end
    end
    local h = 8 * step - 6
    f.bisMid:ClearAllPoints(); f.bisMid:SetPoint("TOPLEFT", x0 + colW + 14, -top); f.bisMid:SetSize(MIDW, h)
    UI:SetClassIcon(f.bisCls, c.class)
    local cr, cg, cb = UI:ClassColor(c.class)
    f.bisRing:SetVertexColor(cr, cg, cb)
    f.bisClass:SetText(WK:CharName(c, f.key))
    f.bisSwList:SetStyle(f.bisShowWorn and "secondary" or "primary")
    f.bisSwWorn:SetStyle(f.bisShowWorn and "primary" or "secondary")
    -- aperçu 3D habillé avec la liste (ou l'équipement porté)
    local shown = false
    local m = f.bisModel
    if m then
        shown = pcall(function()
            m:SetUnit("player")
            if not mine then
                if not (m.SetCustomRace and RACE_IDS[c.race or ""]) then error("race") end
                m:SetCustomRace(RACE_IDS[c.race], (c.sex == 3) and 1 or 0)
            end
            if m.Undress then m:Undress() end
            if f.bisShowWorn then
                for _, l in pairs(gear) do pcall(m.TryOn, m, l) end
            else
                for _, id in pairs(list) do pcall(m.TryOn, m, "item:" .. id) end
            end
            if m.SetFacing then m:SetFacing(m.rot or 0) end
        end)
        m:SetShown(shown)
    end
    f.bisRing:SetShown(not shown); f.bisCls:SetShown(not shown)
    f.bisClass:ClearAllPoints()
    if shown then f.bisClass:SetPoint("TOP", f.bisMid, "TOP", 0, -10) else f.bisClass:SetPoint("TOP", f.bisRing, "BOTTOM", 0, -10) end
    f.bisHint:ClearAllPoints(); f.bisHint:SetPoint("TOP", f.bisClass, "BOTTOM", 0, -3)
    f.bisHint:SetText(shown and T("glisser pour tourner") or "")
    local mi = 0
    for _, t in ipairs(f.bisTiles) do
        if t.side == "mid" then
            t:ClearAllPoints(); t:SetPoint("TOP", f.bisMid, "BOTTOM", (mi - 1) * 58, -10); mi = mi + 1
        end
    end
    local bottom = top + h + 64
    f.bisNote:ClearAllPoints(); f.bisNote:SetPoint("TOPLEFT", 4, -(bottom + 8)); f.bisNote:SetPoint("RIGHT", -4, 0)
    f.bisNote:SetJustifyH("LEFT")
    f.bisNote:SetText(T("Pastilles : vert porté, jaune dans les sacs ou la banque, gris à obtenir. Clic sur un emplacement : choisir · clic droit : retirer · glisser-déposer un objet. Objets du jeu : wowlayerup-forever/opendata (CC BY 4.0)."))
    f.bsc:SetContentHeight(bottom + 34)
    if f.picker:IsShown() then f.picker:Fill() end
end

-- Onglet Sorts (frise des niveaux) : une ligne par niveau, ses sorts en vignettes et ce qu'il coûte ;
-- en tête le total maintenant / jusqu'au 60, l'or du compte et le guidage vers le maître de classe.
-- Prix : relevé chez le maître, sinon prix de base (What's Training), sinon estimé (« env. »).
local SPELL_KEY_W, SPELL_COST_W, CHIP_H, CHIP_GAP = 76, 120, 24, 6
local function CS() return WK.modules.ClassSpells end
local function money(c) local M = CS(); return M and M:Money(c) or "?" end
local function accountGold()
    local g = 0
    for _, c in pairs(WK.DB.global.characters) do g = g + (c.money or 0) end
    return g
end
-- coût d'une liste de sorts : texte « env. » quand un prix est estimé ou inconnu, « ? » quand aucun n'est connu
local function listCost(list)
    local sum, approx, any = 0, false, false
    for _, e in ipairs(list) do
        if e.cost then sum = sum + e.cost; any = true; if e.src == "est" then approx = true end else approx = true end
    end
    if not any then return "?" end
    return (approx and (T("env.") .. " ") or "") .. money(sum)
end
local function rankNum(rank) return rank and rank:match("(%d+)") end

spellChips = function(r, c)
    local all = {}
    for _, l in ipairs({ r.now, r.next, r.later }) do for _, e in ipairs(l) do table.insert(all, e) end end
    local out = {}
    table.insert(out, { label = "À apprendre", value = #r.now .. (#r.now > 0 and (" · " .. listCost(r.now)) or ""),
        color = #r.now > 0 and C.info or nil })
    if r.nextLevel then
        table.insert(out, { label = "Prochain niveau", value = string.format(T("%d sorts"), #r.next), tip = string.format(T("Au niveau %d"), r.nextLevel) })
    end
    table.insert(out, { label = "Jusqu'au 60", value = listCost(all), color = C.gold,
        tip = r.unknownPrice > 0 and string.format(T("%d prix encore inconnus"), r.unknownPrice) or nil })
    table.insert(out, { label = "Or du perso", value = c.money and UI:ShortGold(c.money) or "-" })
    return out
end

buildSpells = function(f)
    local ssc = UI:Scroll(f)
    ssc:SetPoint("TOPLEFT", 0, -98)
    ssc:SetPoint("BOTTOMRIGHT")
    ssc:Hide()
    f.ssc = ssc
    local lc = UI:Card(ssc.child)
    f.spList = lc
    -- en-tête
    lc.title = UI:Text(lc, 14); lc.title:SetPoint("TOPLEFT", 16, -14); lc.title:SetText(T("Sorts de classe"))
    lc.lvl = UI:Text(lc, 11, C.positive); lc.lvl:SetPoint("LEFT", lc.title, "RIGHT", 10, 0)
    lc.go = UI:Button(lc, "Guider vers le maître", nil, 26, "secondary", "guide")
    lc.go:SetPoint("TOPRIGHT", -14, -10)
    lc.go:SetScript("OnClick", function() local G = WK.modules.Guide; if G then G:GoTo("trainer") end end)
    lc.sum = UI:Text(lc, 12, C.muted); lc.sum:SetJustifyH("RIGHT")
    lc.gold = UI:Text(lc, 11, C.muted); lc.gold:SetPoint("TOPLEFT", 16, -38); lc.gold:SetPoint("RIGHT", -16, 0)
    lc.gold:SetJustifyH("LEFT")
    -- lignes de niveau
    f.spGroups = UI:Pool(function()
        local g = CreateFrame("Frame", nil, lc)
        g.line = g:CreateTexture(nil, "ARTWORK"); g.line:SetHeight(1)
        g.line:SetPoint("TOPLEFT", 16, 0); g.line:SetPoint("TOPRIGHT", -16, 0)
        g.line:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
        g.tag = UI:Text(g, 9, C.muted); g.tag:SetPoint("TOPLEFT", 16, -10)
        g.big = UI:Text(g, 16); g.big:SetPoint("TOPLEFT", 16, -22)
        g.cost = UI:Text(g, 12, C.gold); g.cost:SetPoint("TOPRIGHT", -16, -12); g.cost:SetJustifyH("RIGHT")
        g.more = UI:Button(g, "Tout voir", nil, 24, "secondary")
        g.more:SetPoint("TOPRIGHT", -14, -8)
        return g
    end)
    -- vignettes de sort : clic droit = écarter / remettre (tous les rangs)
    f.spChips = UI:Pool(function()
        local b = CreateFrame("Button", nil, lc)
        b:SetHeight(CHIP_H)
        b:RegisterForClicks("RightButtonUp")
        UI:Panel(b, 6, C.surface2, C.border)
        b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(16, 16); b.icon:SetPoint("LEFT", 4, 0)
        b.text = UI:Text(b, 11); b.text:SetPoint("LEFT", 25, 0)
        b:SetScript("OnClick", function(s)
            local M = CS()
            if not (M and s.e) then return end
            M:Skip(f.key, s.e.name, not s.skipped)
            f:Refresh()
        end)
        b:SetScript("OnEnter", function(s)
            if s.border then s.border:SetColor(UI:Accent()) end
            if not s.e then return end
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            if s.e.id and GameTooltip.SetSpellByID then pcall(GameTooltip.SetSpellByID, GameTooltip, s.e.id)
            else GameTooltip:SetText(s.e.name or "", 1, 1, 1) end
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine(T("Niveau"), tostring(s.e.level or "?"), 0.6, 0.6, 0.6, 1, 1, 1)
            local src = s.e.src == "exact" and T("Prix relevé chez le maître") or s.e.src == "base" and T("Prix de base")
                or s.e.src == "est" and T("Prix estimé") or T("Prix")
            GameTooltip:AddDoubleLine(src, (s.e.src == "est" and (T("env.") .. " ") or "") .. money(s.e.cost), 0.6, 0.6, 0.6, 1, 0.82, 0.3)
            GameTooltip:AddLine(s.skipped and T("Clic droit : remettre ce sort") or T("Clic droit : écarter ce sort (tous ses rangs)"), 0.6, 0.6, 0.6, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function(s) if s.border then s.border:SetColor(unpack(C.border)) end GameTooltip:Hide() end)
        return b
    end)
end

refreshSpells = function(f, c)
    local M = CS()
    local r = f.spR or (M and M:ForChar(f.key))
    if not r then return end
    local W = math.max(600, (f.ssc:GetWidth() or 840) - 12)
    f.ssc.child:SetWidth(W)
    local mine = f.key == WK:CharKey()
    local lc = f.spList
    local lvl = r.level or 1
    f.spGroups:Reset(); f.spChips:Reset()

    -- en-tête : niveau, total maintenant / jusqu'au 60, guidage
    local all = {}
    for _, l in ipairs({ r.now, r.next, r.later }) do for _, e in ipairs(l) do table.insert(all, e) end end
    lc.lvl:SetText(string.format(T("niveau %d"), lvl))
    lc.go:SetShown(mine)
    lc.sum:ClearAllPoints()
    if mine then lc.sum:SetPoint("RIGHT", lc.go, "LEFT", -12, 0) else lc.sum:SetPoint("TOPRIGHT", -16, -16) end
    lc.sum:SetText(T("maintenant") .. "  " .. UI:Hex(C.text) .. (#r.now > 0 and listCost(r.now) or "-") .. "|r   ·   "
        .. T("jusqu'au 60") .. "  " .. UI:Hex(C.gold) .. listCost(all) .. "|r")
    -- jusqu'à quel niveau l'or du compte paie tout
    local gold, cum, reach = accountGold(), 0, nil
    local byLevel = {}
    for _, e in ipairs(all) do local L = math.max(e.level, lvl); byLevel[L] = (byLevel[L] or 0) + (e.cost or 0) end
    for L = lvl, 60 do
        cum = cum + (byLevel[L] or 0)
        if cum <= gold then reach = L else break end
    end
    local goldText = reach and string.format(T("Or du compte : %s, de quoi tout payer jusqu'au niveau %d."), money(gold), reach)
        or string.format(T("Or du compte : %s, pas assez pour les sorts de ton niveau."), money(gold))
    if r.estimated or r.unknownPrice > 0 then
        goldText = goldText .. "  " .. UI:Hex(C.dim) .. T("« env. » : prix estimé, remplacé par le vrai au passage chez le maître.") .. "|r"
    end
    if r.notRecorded then goldText = goldText .. "  " .. UI:Hex(C.warning) .. T("Sorts connus relevés à la prochaine connexion de ce perso.") .. "|r" end
    lc.gold:SetText(goldText)
    if lc.gold.SetWordWrap then lc.gold:SetWordWrap(true) end
    local y = 38 + math.max(14, lc.gold:GetStringHeight() or 14) + 12

    -- une ligne de niveau : étiquette, vignettes qui passent à la ligne, coût
    local chipsW = W - 16 - SPELL_KEY_W - SPELL_COST_W - 16
    local function group(tag, tagColor, big, list, skipped)
        local g = f.spGroups:Get()
        g:ClearAllPoints(); g:SetPoint("TOPLEFT", 0, -y); g:SetPoint("TOPRIGHT", 0, -y)
        g.tag:ClearAllPoints(); g.tag:SetPoint("TOPLEFT", 16, -10)
        g.tag:SetText(tag or ""); g.tag:SetTextColor(unpack(tagColor or C.muted))
        g.big:SetText(big)
        g.big:ClearAllPoints(); g.big:SetPoint("TOPLEFT", 16, tag and -22 or -12)
        g.more:Hide(); g.cost:Show()
        g.cost:SetText(skipped and "" or listCost(list))
        local x, cy = 0, 8
        for _, e in ipairs(list) do
            local b = f.spChips:Get()
            b.e, b.skipped = e, skipped
            b.icon:SetTexture(e.icon or 134400)
            b.icon:SetDesaturated(skipped and true or false)
            local n = rankNum(e.rank)
            b.text:SetText((e.name or "?") .. (n and ("  " .. UI:Hex(C.muted) .. n .. "|r") or "")
                .. (e.talent and ("  " .. UI:Hex(C.plan) .. T("talent") .. "|r") or ""))
            b.text:SetTextColor(unpack(skipped and C.dim or C.text))
            local w = math.min(chipsW, math.ceil(b.text:GetStringWidth() or 60) + 34)
            if x > 0 and x + w > chipsW then x = 0; cy = cy + CHIP_H + CHIP_GAP end
            b:SetWidth(w)
            b:ClearAllPoints(); b:SetPoint("TOPLEFT", 16 + SPELL_KEY_W + x, -(y + cy))
            b:Show()
            x = x + w + CHIP_GAP
        end
        local h = math.max(tag and 50 or 40, cy + CHIP_H + 10)
        g:SetHeight(h)
        y = y + h
        return g
    end

    -- maintenant, prochain niveau, puis un niveau par ligne
    if #r.now > 0 then group(T("DISPO"), C.positive, tostring(lvl), r.now)
    else group(T("DISPO"), C.positive, tostring(lvl), {}).cost:SetText(UI:Hex(C.dim) .. T("Rien à apprendre pour l'instant.") .. "|r") end
    if r.nextLevel then group(T("PROCHAIN"), C.warning, tostring(r.nextLevel), r.next) end
    local levels, byL = {}, {}
    for _, e in ipairs(r.later) do
        if not byL[e.level] then byL[e.level] = {}; table.insert(levels, e.level) end
        table.insert(byL[e.level], e)
    end
    table.sort(levels)
    local SHOW = 3
    for i, L in ipairs(levels) do
        if i > SHOW and not f.spLaterOpen then break end
        group(nil, nil, tostring(L), byL[L])
    end
    if #levels > SHOW then
        local rest = 0
        for i = SHOW + 1, #levels do rest = rest + #byL[levels[i]] end
        local g = group(nil, nil, "", {})
        g:SetHeight(40); g.cost:Hide()
        g.big:SetText("")
        g.tag:ClearAllPoints(); g.tag:SetPoint("LEFT", g, "TOPLEFT", 16, -20)
        g.tag:SetText(f.spLaterOpen and "" or string.format(T("… niveaux %d à %d · %d sorts"), levels[SHOW + 1], levels[#levels], rest))
        g.more:Show()
        g.more:SetLabel(f.spLaterOpen and T("Replier") or T("Tout voir"))
        g.more:SetWidth(g.more.label:GetStringWidth() + 32)
        g.more:SetScript("OnClick", function() f.spLaterOpen = not f.spLaterOpen; f:Refresh() end)
    end
    if #r.skipped > 0 then group(T("ÉCARTÉS"), C.dim, tostring(#r.skipped), r.skipped, true) end

    lc:ClearAllPoints(); lc:SetPoint("TOPLEFT", 0, 0); lc:SetWidth(W); lc:SetHeight(y + 8)
    f.ssc:SetContentHeight(y + 16)
end

-- Onglet Armes : à gauche les armes apprises (jauge vert / orange / rouge selon le retard, « équipée »),
-- à droite les armes que la classe peut encore apprendre (prix) et le maître d'armes le plus proche
-- (Modules/WeaponSkills.lua)
local WEAP_SIDE, WEAP_ROW = 330, 34
local function WS() return WK.modules.WeaponSkills end
local LAG_COL = { ok = "positive", warn = "warning", bad = "negative" }

buildWeapons = function(f)
    local wsc = UI:Scroll(f)
    wsc:SetPoint("TOPLEFT", 0, -98)
    wsc:SetPoint("BOTTOMRIGHT")
    wsc:Hide()
    f.wsc = wsc
    local root = wsc.child
    -- armes apprises
    local lc = UI:Card(root)
    f.wpList = lc
    lc.head = UI:Text(lc, 10, C.muted); lc.head:SetPoint("TOPLEFT", 16, -14)
    lc.note = UI:Text(lc, 10, C.muted); lc.note:SetJustifyH("LEFT")
    if lc.note.SetWordWrap then lc.note:SetWordWrap(true) end
    f.wpRows = UI:Pool(function()
        local r = CreateFrame("Frame", nil, lc)
        r:SetHeight(WEAP_ROW)
        r:EnableMouse(true)
        r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(22, 22); r.icon:SetPoint("LEFT", 16, 0)
        r.name = UI:Text(r, 12); r.name:SetPoint("LEFT", 46, 0); r.name:SetWidth(200); r.name:SetJustifyH("LEFT")
        r.bar = UI:Progress(r, 8)
        r.bar:SetPoint("LEFT", 252, 0); r.bar:SetPoint("RIGHT", -112, 0)
        r.val = UI:Text(r, 12); r.val:SetPoint("RIGHT", -16, 0); r.val:SetJustifyH("RIGHT")
        r:SetScript("OnEnter", function(s)
            if not s.e then return end
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetText(s.e.name, 1, 1, 1)
            local gap = (s.e.max or 0) - (s.e.rank or 0)
            if gap > 0 then
                GameTooltip:AddLine(string.format(T("%d points de retard : frappe avec cette arme pour les rattraper (tu rates plus souvent en attendant)."), gap),
                    C.muted[1], C.muted[2], C.muted[3], true)
            else
                GameTooltip:AddLine(T("Au maximum pour ton niveau."), C.positive[1], C.positive[2], C.positive[3])
            end
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return r
    end)
    -- à apprendre + maître d'armes
    local rc = UI:Card(root, T("À apprendre"))
    f.wpLearn = rc
    f.wpLearnRows = UI:Pool(function()
        local r = CreateFrame("Button", nil, rc)
        r:SetHeight(28)
        r.hl = r:CreateTexture(nil, "BACKGROUND"); r.hl:SetAllPoints()
        r.hl:SetColorTexture(C.surface2[1], C.surface2[2], C.surface2[3], 0.5); r.hl:Hide()
        r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(20, 20); r.icon:SetPoint("LEFT", 16, 0)
        r.icon:SetDesaturated(true)
        r.name = UI:Text(r, 12); r.name:SetPoint("LEFT", 44, 0); r.name:SetPoint("RIGHT", -90, 0); r.name:SetJustifyH("LEFT")
        r.cost = UI:Text(r, 12, C.gold); r.cost:SetPoint("RIGHT", -16, 0); r.cost:SetJustifyH("RIGHT")
        r:SetScript("OnEnter", function(s)
            s.hl:Show()
            if not s.e then return end
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetText(s.e.name, 1, 1, 1)
            local m = WS():Masters(s.e.id)[1]
            if m then GameTooltip:AddLine(string.format(T("Enseignée par %s (%s)"), m.name, WS():Zone(m)), C.muted[1], C.muted[2], C.muted[3], true) end
            if s.e.soon then GameTooltip:AddLine(string.format(T("À partir du niveau %d"), s.e.level), C.warning[1], C.warning[2], C.warning[3]) end
            if f.key == WK:CharKey() and m then GameTooltip:AddLine(T("Clic : guider vers ce maître d'armes"), C.muted[1], C.muted[2], C.muted[3]) end
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function(s) s.hl:Hide(); GameTooltip:Hide() end)
        r:SetScript("OnClick", function(s)
            if not s.e or f.key ~= WK:CharKey() then return end
            WS():GuideTo(WS():Masters(s.e.id)[1])
        end)
        return r
    end)
    rc.line = rc:CreateTexture(nil, "ARTWORK"); rc.line:SetHeight(1)
    rc.line:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
    rc.mt = UI:Text(rc, 11, C.muted); rc.mt:SetText(T("Maître d'armes le plus proche"))
    rc.mname = UI:Text(rc, 12); rc.mname:SetJustifyH("LEFT")
    if rc.mname.SetWordWrap then rc.mname:SetWordWrap(true) end
    rc.go = UI:Button(rc, "Guider", 110, 28, "secondary", "guide")
    rc.go:SetScript("OnClick", function() WS():GuideTo(rc.master) end)
end

refreshWeapons = function(f, c)
    local M = WS()
    if not M then return end
    local r = M:ForChar(f.key)
    local W = math.max(600, (f.wsc:GetWidth() or 840) - 12)
    f.wsc.child:SetWidth(W)
    local wide = W >= 900
    local leftW = wide and (W - WEAP_SIDE - COL_GAP) or W
    local mine = f.key == WK:CharKey()
    -- armes apprises
    local lc = f.wpList
    f.wpRows:Reset()
    lc.head:SetText(string.format(T("MES ARMES  ·  NIVEAU %d  ·  MAX %d"), r.level, r.max))
    local y = 34
    for _, e in ipairs(r.learned) do
        local row = f.wpRows:Get()
        row.e = e
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -y); row:SetPoint("TOPRIGHT", 0, -y)
        row.icon:SetTexture(e.icon)
        row.name:SetText(e.name .. (e.equipped and ("  " .. UI:Hex({ UI:Accent() }) .. T("équipée") .. "|r") or ""))
        local col = C[LAG_COL[M:Lag(e)]]
        row.bar.color = col
        row.bar:SetValue(e.max > 0 and e.rank / e.max or 0)
        row.val:SetText(string.format("%d / %d", e.rank, e.max))
        row.val:SetTextColor(unpack(col))
        row:Show()
        y = y + WEAP_ROW
    end
    if #r.learned == 0 then
        lc.note:ClearAllPoints(); lc.note:SetPoint("TOPLEFT", 16, -y); lc.note:SetPoint("RIGHT", -16, 0)
        lc.note:SetText(r.recorded and T("Aucune compétence d'arme relevée.") or T("Compétences d'armes relevées à la prochaine connexion de ce perso."))
        y = y + 24
    else
        y = y + 6
        lc.note:ClearAllPoints(); lc.note:SetPoint("TOPLEFT", 16, -y); lc.note:SetPoint("RIGHT", -16, 0)
        lc.note:SetText(T("Vert : au maximum · orange : un peu en retard · rouge : très en retard (tu rates plus souvent). Survol : le détail."))
        y = y + math.max(14, lc.note:GetStringHeight() or 14) + 6
    end
    lc:ClearAllPoints(); lc:SetPoint("TOPLEFT", 0, 0); lc:SetWidth(leftW); lc:SetHeight(y + 10)

    -- à apprendre
    local rc = f.wpLearn
    local sideW = wide and WEAP_SIDE or W
    local sx, sy = wide and (leftW + COL_GAP) or 0, wide and 0 or (y + 10 + COL_GAP)
    rc:ClearAllPoints(); rc:SetPoint("TOPLEFT", sx, -sy); rc:SetWidth(sideW)
    f.wpLearnRows:Reset()
    local ry = 42
    for _, e in ipairs(r.toLearn) do
        local row = f.wpLearnRows:Get()
        row.e = e
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -ry); row:SetPoint("TOPRIGHT", 0, -ry)
        row.icon:SetTexture(e.icon)
        row.name:SetText(e.name)
        row.name:SetTextColor(unpack(e.soon and C.muted or C.text))
        row.cost:SetText(e.soon and string.format(T("niv. %d"), e.level) or WK:FormatMoney(e.cost))
        row.cost:SetTextColor(unpack(e.soon and C.muted or C.gold))
        row:Show()
        ry = ry + 28
    end
    rc.mt:ClearAllPoints(); rc.mname:ClearAllPoints(); rc.line:ClearAllPoints()
    if #r.toLearn == 0 then
        rc.mname:SetPoint("TOPLEFT", 16, -ry); rc.mname:SetPoint("RIGHT", -16, 0)
        rc.mname:SetText(UI:Hex(C.positive) .. T("Toutes les armes de ta classe sont apprises.") .. "|r")
        rc.mt:Hide(); rc.line:Hide(); rc.go:Hide()
        rc:SetHeight(ry + 30)
    else
        ry = ry + 8
        rc.line:SetPoint("TOPLEFT", 16, -ry); rc.line:SetPoint("TOPRIGHT", -16, -ry); rc.line:Show()
        ry = ry + 10
        rc.mt:SetPoint("TOPLEFT", 16, -ry); rc.mt:Show()
        ry = ry + 18
        -- le plus proche qui enseigne au moins une des armes à apprendre
        local want = {}
        for _, e in ipairs(r.toLearn) do want[e.id] = true end
        local master
        for _, m in ipairs(M:Masters()) do
            for id in pairs(m.teaches) do if want[id] then master = m break end end
            if master then break end
        end
        rc.master = master
        rc.mname:SetPoint("TOPLEFT", 16, -ry); rc.mname:SetPoint("RIGHT", -16, 0)
        if master then
            local d = master.distance and mine and ("  " .. UI:Hex(C.muted) .. "· " .. string.format(T("%d m"), math.floor(master.distance)) .. "|r") or ""
            rc.mname:SetText(master.name .. "  " .. UI:Hex(C.muted) .. "· " .. M:Zone(master) .. "|r" .. d)
        else
            rc.mname:SetText(UI:Hex(C.muted) .. T("Aucun maître d'armes connu pour ta faction.") .. "|r")
        end
        ry = ry + math.max(16, rc.mname:GetStringHeight() or 16) + 8
        rc.go:ClearAllPoints(); rc.go:SetPoint("TOPLEFT", 16, -ry)
        rc.go:SetShown(mine and master ~= nil)
        if mine and master then ry = ry + 28 + 6 end
        rc:SetHeight(ry + 12)
    end
    local bottom = wide and math.max(y + 10, rc:GetHeight()) or (sy + rc:GetHeight())
    f.wsc:SetContentHeight(bottom + 8)
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
    f.mine:SetShown(key ~= WK:CharKey() and WK.DB.global.characters[WK:CharKey()] ~= nil)
    -- à droite de l'en-tête, avant le niveau moyen : le nom et la ligne de classe restent seuls à gauche
    -- pastilles d'en-tête (roue > Fiche) : de droite à gauche depuis la roue ; la 1re en accent
    -- onglet Sorts : ses propres pastilles (à apprendre, prochain niveau, jusqu'au 60, or)
    f.spR = (f.tab == "spells" and WK.modules.ClassSpells) and WK.modules.ClassSpells:ForChar(key) or nil
    local chips = f.spR and spellChips(f.spR, c) or UI.SheetChipValues(c)
    local ar, ag, ab = viewAccent(f, c)
    local x, shown = 46, 0
    for i, ch in ipairs(f.hchips) do
        local e = chips[#chips - i + 1]
        if e then
            local first = (#chips - i + 1) == 1
            ch.text:SetText(UI:Hex(C.muted) .. T(e.label) .. "|r  " .. UI:Hex(e.color or (first and { ar, ag, ab } or C.text)) .. e.value .. "|r")
            ch:SetWidth(math.ceil(ch.text:GetStringWidth() or 60) + 26)
            if first then ch.edge:SetColor(ar, ag, ab, 0.55); ch.bg:SetColor(ar * 0.18, ag * 0.18, ab * 0.18, 1)
            else ch.edge:SetColor(C.border[1], C.border[2], C.border[3], 1); ch.bg:SetColor(C.surface[1], C.surface[2], C.surface[3], 1) end
            ch.tip = e.tip
            ch:ClearAllPoints(); ch:SetPoint("TOPRIGHT", f, "TOPRIGHT", -x, -27)
            x = x + ch:GetWidth() + 8
            ch:Show(); shown = i
        else ch:Hide() end
    end
    f.mine:ClearAllPoints()
    if shown > 0 then f.mine:SetPoint("RIGHT", f.hchips[shown], "LEFT", -16, 0) else f.mine:SetPoint("TOPRIGHT", -62, -28) end
    for _, b in pairs(f.tabs) do b:Paint() end
    f.sc:SetShown(f.tab == "sheet"); f.tsc:SetShown(f.tab == "talents"); f.bsc:SetShown(f.tab == "bis")
    f.ssc:SetShown(f.tab == "spells")
    f.wsc:SetShown(f.tab == "weapons")
    if f.tab ~= "bis" then f.picker:Hide() end
    if f.tab == "talents" then return refreshTalents(f, c) end
    if f.tab == "spells" then return refreshSpells(f, c) end
    if f.tab == "weapons" then return refreshWeapons(f, c) end
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
        UI.charSheetFrame = sheet
        sheet.Refresh = refresh
        -- roue en haut à droite : réglages des trois onglets (Fiche, Talents, BiS), rangés en onglets dans le volet
        local function redraw() if sheet:IsVisible() then sheet:Refresh() end end
        local function card(title, rows)
            local c = UI:Card(sheet, T(title))
            local y = -44
            for _, r in ipairs(rows) do
                UI:SettingRow(c, y, r[1], r[2], UI:Toggle(c, r[3], function(v) r[4](v); redraw() end), 80)
                y = y - 46
            end
            c:SetHeight(-y + 8)
            return c
        end
        local S = sheetCfg
        local ui = function() return WK.DB.global.settings.ui end
        -- pastilles d'en-tête : un bouton par chiffre possible, allumé s'il est affiché (dans l'ordre des clics)
        local chipCard = UI:Card(sheet, T("En-tête : pastilles"))
        chipCard.note = UI:Text(chipCard, 10, C.muted); chipCard.note:SetPoint("TOPLEFT", 16, -38); chipCard.note:SetPoint("RIGHT", -16, 0)
        chipCard.note:SetJustifyH("LEFT")
        chipCard.note:SetText(string.format(T("Choisis jusqu'à %d chiffres affichés en haut à droite de la fiche ; la 1re pastille est mise en avant."), HEAD_MAX))
        chipCard.btns = {}
        for _, d in ipairs(UI.SHEET_CHIPS) do
            local b = UI:Button(chipCard, T(d[2]), nil, 24, "ghost")
            b.key = d[1]
            b:SetScript("OnClick", function(s)
                local list = S().chips
                local at
                for n, k in ipairs(list) do if k == s.key then at = n end end
                if at then table.remove(list, at) elseif #list < HEAD_MAX then table.insert(list, s.key) end
                chipCard:Paint(); redraw()
            end)
            table.insert(chipCard.btns, b)
        end
        chipCard.Paint = function(cc)
            local on = {}
            for n, k in ipairs(S().chips) do on[k] = n end
            for _, b in ipairs(cc.btns) do b:SetStyle(on[b.key] and "primary" or "ghost") end
        end
        -- boutons en lignes, à la largeur de la carte
        chipCard.Flow = function(cc)
            local w = (cc:GetWidth() or 600) - 32
            local x, y = 0, 0
            for _, b in ipairs(cc.btns) do
                local bw = b:GetWidth() or 80
                if x > 0 and x + bw > w then x = 0; y = y + 30 end
                b:ClearAllPoints(); b:SetPoint("TOPLEFT", 16 + x, -(62 + y))
                x = x + bw + 6
            end
            cc:SetHeight(62 + y + 24 + 16)
        end
        chipCard:SetScript("OnSizeChanged", function(c) c:Flow() end)
        chipCard:SetWidth(600); chipCard:Flow(); chipCard:Paint()
        local cards = {
            sheet = { chipCard, card("Fiche", {
                { "Niveau d'objet sur les icônes", "Le niveau de chaque objet porté, en bas de son icône.",
                    function() return S().ilvl end, function(v) S().ilvl = v end },
                { "Point bleu : objet enchanté", "Un petit point en haut de l'icône des objets enchantés.",
                    function() return S().enchant end, function(v) S().enchant = v end },
                { "Stats utiles en couleur", "Les caractéristiques qui comptent pour la classe en couleur, les autres en gris.",
                    function() return S().statColor end, function(v) S().statColor = v end },
            }) },
            talents = { card("Talents", {
                { "Panneau collé à la fenêtre des talents du jeu", "Le plan de montée s'ouvre à côté de la fenêtre des talents.",
                    function() return UI.TalentPlanEnabled and UI.TalentPlanEnabled() end, function(v) ui().talentPlanPanel = v end },
                { "Faire clignoter le prochain talent dans la fenêtre du jeu", "Le talent à prendre selon ton plan clignote.",
                    function() return UI.TalentPlanGlowEnabled and UI.TalentPlanGlowEnabled() end,
                    function(v) ui().talentPlanGlow = v; if UI.TalentPlanGlow then UI:TalentPlanGlow() end end },
            }) },
            bis = { card("BiS", {
                { "Ligne « Liste BiS de… » dans les infobulles", "Sur un objet de ta liste BiS : quels persos le veulent.",
                    function() return ui().bisTooltip ~= false end, function(v) ui().bisTooltip = v end },
            }) },
        }
        -- onglets du volet, comme ceux de la fiche ; ouvert sur l'onglet affiché
        local tabCard = CreateFrame("Frame", nil, sheet); tabCard:SetHeight(34)
        sheet.setTab = "sheet"
        -- (réglages des sorts de classe : QoL > Classes > Général)
        local seg = UI:Segmented(tabCard, { { "sheet", "Fiche" }, { "talents", "Talents" }, { "bis", "BiS" } }, function(v)
            sheet.setTab = v
            if self.gp then self.gp:Refresh() end
        end, 28)
        seg:SetPoint("TOPLEFT", 0, 0)
        sheet.setSeg = seg
        local all = { chipCard }
        for _, list in pairs(cards) do for _, c in ipairs(list) do table.insert(all, c) end end
        sheet.setCards = all
        for _, c in ipairs(all) do c:Hide() end
        sheet.setByTab = cards
        self.gp = UI:PageGear(p, { title = "Réglages de la fiche", top = 64, columns = 1,
            cards = function()
                for _, c in ipairs(all) do c:Hide() end
                local out = { tabCard }
                for _, c in ipairs(cards[sheet.setTab] or cards.sheet) do table.insert(out, c) end
                return out
            end,
            onToggle = function(open)
                -- volet ouvert : seuls ses onglets à lui (ceux de la fiche sont masqués, le volet prend leur place)
                for _, b in pairs(sheet.tabs) do b:SetShown(not open) end
                sheet.tabLine:SetShown(not open)
                if open then
                    sheet.setTab = (sheet.tab and cards[sheet.tab]) and sheet.tab or "sheet"
                    seg:Select(sheet.setTab); chipCard:Paint()
                end
            end }, self)
        self.gp.gear:SetPoint("TOPRIGHT", p, "TOPRIGHT", -6, -24)
        self.gp.gear:SetFrameLevel(sheet:GetFrameLevel() + 20)
        UI:OnResize(p, function() if sheet:IsVisible() then sheet:Refresh() end end)
    end,
    Refresh = function(self)
        if not sheet then return end
        local key = UI.charSheetKey or WK:CharKey()
        if sheet.key ~= key then
            -- autre perso : rien de l'ancien ne doit rester actif (mode plan, build déplié, fenêtres ouvertes)
            sheet.planEdit, sheet.openBuild, sheet.repAll, sheet.talentTried = nil, nil, false, nil
            if sheet.picker then sheet.picker:Hide() end
            if sheet.dlg then sheet.dlg:Hide() end
            if sheet.bisMenu then sheet.bisMenu:Hide() end
        end
        sheet.key = key
        if UI.charSheetTab then sheet.tab = UI.charSheetTab; UI.charSheetTab = nil end
        sheet:Refresh()
    end,
})

-- objets reçus du serveur : un seul rafraîchissement par demi-seconde (ils arrivent par dizaines)
local itemRefresh
WK:On("GET_ITEM_INFO_RECEIVED", function()
    if itemRefresh or not (sheet and sheet:IsVisible()) then return end
    itemRefresh = true
    C_Timer.After(0.5, function() itemRefresh = nil; if sheet and sheet:IsVisible() then sheet:Refresh() end end)
end)
-- La fiche montre le perso connecté par défaut : on oublie le perso choisi à la connexion
-- et quand la fenêtre se ferme (un autre perso ne s'affiche que sur un clic dans Persos ou le Résumé)
WK:On("PLAYER_LOGIN", function() UI.charSheetKey = nil end)

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
