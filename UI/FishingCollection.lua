local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Collection de pêche (QoL > Pêche) : carte à deux onglets.
--   Album : une tuile par espèce (référence Modules/FishDB.lua + prises du carnet), par palier de
--           compétence ; en couleur si un perso du compte l'a pêchée, en gris sinon. Clic : fiche à
--           droite (prises, prix, où elle mord, première prise, guidage vers le meilleur coin).
--   Par zone : atlas des eaux, une ligne par zone (compétence conseillée, espèces, progression,
--           rythme, guidage vers ton dernier coin de pêche de la zone).
-- La carte change de hauteur selon l'onglet et la largeur : onHeight(h) prévient la page.
local FL = WK.modules.FishingLog
local TILE, STEP, HEAD, DETAIL_W, ROW_H = 40, 46, 84, 250, 34
local CAT_LABEL = { fish = "Poisson", chest = "Coffre", curio = "Curiosité", other = "Autre prise" }
local FILTERS = { { "all", "Tout" }, { "fish", "Poissons" }, { "chest", "Coffres" }, { "curio", "Curiosités" }, { "missing", "Manquants" } }

local function uiCfg()
    local ui = WK.DB.global.settings.ui
    ui.fishCol = ui.fishCol or { tab = "album", filter = "all" }
    return ui.fishCol
end
local function tierLabel(tier)
    local t = WK.FishDB.TIERS[tier]
    if not t then return T("AUTRES PRISES") end
    if tier == #WK.FishDB.TIERS then return string.format(T("COMPÉTENCE %d ET PLUS"), t[1]) end
    return string.format(T("COMPÉTENCE %d À %d"), t[1], t[2])
end
local function skillColor(need)
    local sk = WK.modules.Fishing:Skill()
    if not need or not sk then return C.muted end
    if sk >= need + 25 then return C.positive end
    if sk >= need then return C.warning end
    return C.negative
end
local function isNew(e)
    return e.first and (time() - e.first) < FL.NEW_DAYS * 86400
end

function UI:FishCollection(card, onHeight)
    local cfg = uiCfg()
    local col = { height = 400 }

    -- en-tête : onglets et filtres
    local tabs = UI:Segmented(card, { { "album", "Album" }, { "atlas", "Par zone" } }, function(k) cfg.tab = k; col:Refresh() end, 28)
    tabs:SetPoint("TOPRIGHT", -12, -8)
    local filter = UI:Segmented(card, FILTERS, function(k) cfg.filter = k; col:Refresh() end, 28)
    filter:SetPoint("TOPLEFT", 16, -44)
    local prog = UI:Progress(card, 5)
    prog:SetPoint("LEFT", card.subtitle or card.title, "RIGHT", 12, 0)
    prog:SetWidth(120)

    ---------------------------------------------------------------- Album
    local album = CreateFrame("Frame", nil, card)
    album:SetPoint("TOPLEFT", 16, -HEAD)
    album:SetPoint("BOTTOMRIGHT", -(16 + DETAIL_W + 12), 12)
    local headers = UI:Pool(function()
        return UI:Text(album, 10, C.dim)
    end)
    local tiles = UI:Pool(function()
        local b = CreateFrame("Button", nil, album)
        b:SetSize(TILE, TILE)
        b.edge = UI:Rounded(b, 9, 0, "BACKGROUND", 0)
        b.bg = UI:Rounded(b, 8, 1.5, "BACKGROUND", 1)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("TOPLEFT", 4, -4)
        b.icon:SetPoint("BOTTOMRIGHT", -4, 4)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.n = UI:Text(b, 9, C.text)
        b.n:SetPoint("BOTTOMRIGHT", -2, 2)
        b.dot = UI:Icon(b, "circle", 8, nil, "OVERLAY")
        b.dot:SetPoint("TOPLEFT", -2, 2)
        b:SetScript("OnClick", function(s) cfg.sel = s.e.id; col:Refresh() end)
        b:SetScript("OnEnter", function(s)
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            if GameTooltip.SetItemByID then GameTooltip:SetItemByID(s.e.id) else GameTooltip:SetText(UI:ItemInfo(s.e.id)) end
            GameTooltip:AddLine(s.e.n > 0 and string.format(T("%d pêché(s) sur le compte"), s.e.n) or T("Pas encore pêché"), 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return b
    end)
    local empty = UI:Text(album, 11, C.muted)
    empty:SetPoint("TOPLEFT", 0, -4)
    empty:SetText(T("Rien dans ce filtre."))

    -- fiche de l'espèce choisie
    local det = CreateFrame("Frame", nil, card)
    det:SetPoint("TOPRIGHT", -16, -HEAD)
    det:SetSize(DETAIL_W, 330)
    UI:Panel(det, 10, C.surface2, C.border)
    det.icon = det:CreateTexture(nil, "ARTWORK")
    det.icon:SetSize(36, 36)
    det.icon:SetPoint("TOPLEFT", 12, -12)
    det.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    det.name = UI:Text(det, 13)
    det.name:SetPoint("TOPLEFT", 56, -13)
    det.name:SetPoint("RIGHT", -10, 0)
    det.name:SetJustifyH("LEFT")
    det.sub = UI:Text(det, 10, C.muted)
    det.sub:SetPoint("TOPLEFT", det.name, "BOTTOMLEFT", 0, -4)
    det.kp = {}
    for i = 1, 2 do
        local k = CreateFrame("Frame", nil, det)
        k:SetSize((DETAIL_W - 32) / 2, 40)
        k:SetPoint("TOPLEFT", 12 + (i - 1) * ((DETAIL_W - 32) / 2 + 8), -60)
        UI:Panel(k, 8, C.surface, C.border)
        k.v = UI:Text(k, 13)
        k.v:SetPoint("TOP", 0, -6)
        k.l = UI:Text(k, 9, C.muted)
        k.l:SetPoint("BOTTOM", 0, 5)
        det.kp[i] = k
    end
    det.whereH = UI:Text(det, 9, C.dim)
    det.whereH:SetPoint("TOPLEFT", 12, -112)
    det.whereH:SetText(T("OÙ ÇA MORD"))
    det.where = {}
    for i = 1, 5 do
        local r = CreateFrame("Frame", nil, det)
        r:SetHeight(18)
        r:SetPoint("TOPLEFT", 12, -128 - (i - 1) * 20)
        r:SetPoint("RIGHT", -12, 0)
        r.l = UI:Text(r, 11)
        r.l:SetPoint("LEFT")
        r.l:SetPoint("RIGHT", -70, 0)
        r.l:SetJustifyH("LEFT")
        r.r = UI:Text(r, 10, C.muted)
        r.r:SetPoint("RIGHT")
        det.where[i] = r
    end
    det.firstH = UI:Text(det, 9, C.dim)
    det.firstH:SetPoint("TOPLEFT", 12, -236)
    det.firstH:SetText(T("PREMIÈRE PRISE"))
    det.first = UI:Text(det, 11)
    det.first:SetPoint("TOPLEFT", 12, -252)
    det.first:SetPoint("RIGHT", -12, 0)
    det.first:SetJustifyH("LEFT")
    det.guide = UI:Button(det, T("Meilleur coin"), nil, 26, "primary", "guide")
    det.guide:SetPoint("BOTTOMLEFT", 12, 12)
    det.link = UI:Button(det, T("Lien"), nil, 26, "secondary")
    det.link:SetPoint("BOTTOMRIGHT", -12, 12)
    det.guide:SetScript("OnClick", function() if cfg.sel then FL:GuideSpecies(cfg.sel) end end)
    det.guide:HookScript("OnEnter", function(s)
        UI:TooltipOwner(s, "ANCHOR_TOP")
        GameTooltip:SetText(T("Guider vers ton dernier coin de pêche de la zone où elle mord le plus"), 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    det.guide:HookScript("OnLeave", function() GameTooltip:Hide() end)
    det.link:SetScript("OnClick", function()
        local link = cfg.sel and select(6, UI:ItemInfo(cfg.sel))
        if link then WK.InsertChatLink(link) end
    end)

    ---------------------------------------------------------------- Atlas
    local atlas = CreateFrame("Frame", nil, card)
    atlas:SetPoint("TOPLEFT", 16, -52)
    atlas:SetPoint("BOTTOMRIGHT", -16, 12)
    local AH = {}
    for i, h in ipairs({ { "ZONE", 0 }, { "COMPÉTENCE", 210 }, { "ESPÈCES", 300 } }) do
        local t = UI:Text(atlas, 10, C.dim)
        t:SetPoint("TOPLEFT", h[2], 0)
        t:SetText(T(h[1]))
        AH[i] = t
    end
    local ahCol = UI:Text(atlas, 10, C.dim)
    ahCol:SetPoint("TOPRIGHT", -116, 0)
    ahCol:SetText(T("COLLECTION"))
    local ahRate = UI:Text(atlas, 10, C.dim)
    ahRate:SetPoint("TOPRIGHT", -40, 0)
    ahRate:SetText(T("RYTHME"))
    local rows = UI:Pool(function()
        local r = CreateFrame("Frame", nil, atlas)
        r:SetHeight(ROW_H - 4)
        r:SetPoint("RIGHT")
        r.bg = UI:Rounded(r, 6, 0, "BACKGROUND", 1)
        r.name = UI:Text(r, 12)
        r.name:SetPoint("LEFT", 8, 0)
        r.name:SetWidth(196)
        r.name:SetJustifyH("LEFT")
        r.skill = UI:Text(r, 11)
        r.skill:SetPoint("LEFT", 210, 0)
        r.icons = {}
        r.prog = UI:Progress(r, 5)
        r.prog:SetWidth(54)
        r.prog:SetPoint("RIGHT", -134, 0)
        r.n = UI:Text(r, 10, C.muted)
        r.n:SetPoint("RIGHT", -96, 0)
        r.rate = UI:Text(r, 10, C.muted)
        r.rate:SetPoint("RIGHT", -40, 0)
        r.guide = UI:GuideButton(r, 22, "Guider vers ton dernier coin de pêche de cette zone")
        r.guide:SetPoint("RIGHT", -4, 0)
        r.guide:SetScript("OnClick", function() FL:GuideZone(r.map) end)
        return r
    end)
    local function rowIcon(r, i)
        local ic = r.icons[i]
        if not ic then
            ic = CreateFrame("Frame", nil, r)
            ic:SetSize(18, 18)
            ic:SetPoint("LEFT", 300 + (i - 1) * 21, 0)
            ic.t = UI:RoundIcon(ic, 18)
            ic.t:SetAllPoints()
            ic:EnableMouse(true)
            ic:SetScript("OnEnter", function(s)
                UI:TooltipOwner(s, "ANCHOR_TOP")
                GameTooltip:SetText((UI:ItemInfo(s.id)), 1, 1, 1)
                GameTooltip:AddLine(s.have and T("Déjà pêché dans cette zone") or T("Pas encore pêché ici"), 0.7, 0.7, 0.7)
                GameTooltip:Show()
            end)
            ic:SetScript("OnLeave", function() GameTooltip:Hide() end)
            r.icons[i] = ic
        end
        return ic
    end

    ---------------------------------------------------------------- Dessin
    local function drawAlbum(w)
        local list = FL:Collection()
        local f = cfg.filter
        local groups, order = {}, {}
        for _, e in ipairs(list) do
            local ok = f == "all" or (f == "missing" and e.n == 0) or e.cat == f or (f == "curio" and e.cat == "other")
            if ok then
                if not groups[e.tier] then groups[e.tier] = {}; table.insert(order, e.tier) end
                table.insert(groups[e.tier], e)
            end
        end
        table.sort(order, function(a, b) return (a == 0 and 99 or a) < (b == 0 and 99 or b) end)
        headers:Reset(); tiles:Reset()
        local cols = math.max(1, math.floor((w + STEP - TILE) / STEP))
        local y, selFound = 0, false
        local r1, g1, b1 = UI:Accent()
        for _, tier in ipairs(order) do
            local h = headers:Get()
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", 0, -y)
            h:SetText(tierLabel(tier))
            y = y + 18
            for i, e in ipairs(groups[tier]) do
                local b = tiles:Get()
                b.e = e
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", ((i - 1) % cols) * STEP, -(y + math.floor((i - 1) / cols) * STEP))
                local _, icon = UI:ItemInfo(e.id)
                b.icon:SetTexture(icon)
                local has = e.n > 0
                if b.icon.SetDesaturated then b.icon:SetDesaturated(not has) end
                b.icon:SetAlpha(has and 1 or 0.35)
                b.n:SetText(has and tostring(e.n) or "")
                b.dot:SetShown(has and isNew(e) or false)
                b.dot:SetVertexColor(r1, g1, b1)
                local sel = cfg.sel == e.id
                if sel then selFound = true end
                b.edge:SetColor(r1, g1, b1, sel and 1 or 0)
                b.bg:SetColor(unpack(C.surface2))
            end
            y = y + math.ceil(#groups[tier] / cols) * STEP + 8
        end
        empty:SetShown(#order == 0)
        if not selFound then
            local firstTile = tiles.items[1]
            cfg.sel = (tiles.used > 0 and firstTile and firstTile.e.id) or cfg.sel
            if tiles.used > 0 then firstTile.edge:SetColor(r1, g1, b1, 1) end
        end
        return math.max(y, det:GetHeight() + 4, 60)
    end

    local function drawDetail()
        local id = cfg.sel
        det:SetShown(id ~= nil)
        if not id then return end
        local e
        for _, x in ipairs(FL:Collection()) do if x.id == id then e = x break end end
        e = e or { id = id, n = 0, cat = "other", tier = 0 }
        local name, icon, qr, qg, qb = UI:ItemInfo(id)
        det.icon:SetTexture(icon)
        if det.icon.SetDesaturated then det.icon:SetDesaturated(e.n == 0) end
        det.name:SetText(name)
        det.name:SetTextColor(qr, qg, qb)
        local t = WK.FishDB.TIERS[e.tier]
        det.sub:SetText(T(CAT_LABEL[e.cat] or "Autre prise") .. (t and ("  ·  " .. string.format(T("compétence %d à %d"), t[1], t[2])) or ""))
        det.kp[1].v:SetText(tostring(e.n)); det.kp[1].l:SetText(T("pêchés"))
        local V = WK.modules.Value
        local price = V and V:Price(id) or 0
        det.kp[2].v:SetText(price > 0 and UI:GoldText(price) or "-"); det.kp[2].l:SetText(T("prix HV"))
        local mine, refz = FL:SpeciesZones(id)
        local lines = {}
        for _, r in ipairs(mine) do table.insert(lines, { FL:ZoneName(r.map), r.pct .. " %", C.text }) end
        for _, r in ipairs(refz) do
            if #lines >= #det.where then break end
            table.insert(lines, { FL:ZoneName(r.map), string.format(T("conseillé %d"), r.skill), C.muted })
        end
        for i, row in ipairs(det.where) do
            local l = lines[i]
            row:SetShown(l ~= nil)
            if l then row.l:SetText(l[1]); row.l:SetTextColor(unpack(l[3])); row.r:SetText(l[2]) end
        end
        if #lines == 0 then
            det.where[1]:Show(); det.where[1].l:SetText(T("Pas encore de zone connue")); det.where[1].l:SetTextColor(unpack(C.muted)); det.where[1].r:SetText("")
        end
        if e.first then
            local c = WK.DB.global.characters[e.by or ""]
            det.first:SetText((c and WK:CharName(c, e.by) or "?") .. "  ·  " .. date("%d/%m/%Y", e.first))
        else
            det.first:SetText(T("Pas encore pêché"))
        end
        local canGuide = false
        for _, r in ipairs(mine) do
            local z = FL:Data().zones[r.map]
            if z and z.pos then canGuide = true break end
        end
        det.guide:SetShown(canGuide)
    end

    local function drawAtlas(w)
        rows:Reset()
        local r1, g1, b1 = UI:Accent()
        local iconsW = w - 300 - 200
        local maxIcons = math.max(1, math.floor(iconsW / 21))
        for i, z in ipairs(FL:Atlas()) do
            local r = rows:Get()
            r.map = z.map
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -(20 + (i - 1) * ROW_H))
            r:SetPoint("RIGHT")
            r.bg:SetColor(C.surface2[1], C.surface2[2], C.surface2[3], i % 2 == 0 and 0.5 or 0)
            r.name:SetText(FL:ZoneName(z.map))
            r.skill:SetText(z.skill and tostring(z.skill) or "-")
            r.skill:SetTextColor(unpack(skillColor(z.skill)))
            local have = 0
            for k, id in ipairs(z.fish) do
                local got = z.have[id] or false
                if got then have = have + 1 end
                local ic = rowIcon(r, k)
                ic:SetShown(k <= maxIcons)
                ic.id, ic.have = id, got
                local _, icon = UI:ItemInfo(id)
                ic.t:SetTexture(icon)
                if ic.t.SetDesaturated then ic.t:SetDesaturated(not got) end
                ic.t:SetAlpha(got and 1 or 0.35)
            end
            for k = #z.fish + 1, #r.icons do r.icons[k]:Hide() end
            local total = math.max(1, #z.fish)
            r.prog.color = { r1, g1, b1, 1 }
            r.prog:SetValue(have / total)
            r.n:SetText(have .. "/" .. #z.fish)
            local rate = FL.Rate(z.n, z.time)
            r.rate:SetText(rate and (rate .. "/h") or "-")
            r.guide:SetShown(z.pos ~= nil)
        end
        return 20 + rows.used * ROW_H
    end

    function col:Refresh()
        local w = card:GetWidth()
        if not w or w < 100 then return end
        tabs:Select(cfg.tab)
        filter:Select(cfg.filter)
        local have, total = FL:CollectionCount()
        if card.subtitle then card.subtitle:SetText(string.format(T("%d / %d espèces"), have, total)) end
        prog.color = { UI:Accent() }
        prog:SetValue(have / math.max(1, total))
        local isAlbum = cfg.tab ~= "atlas"
        album:SetShown(isAlbum); det:SetShown(isAlbum); filter:SetShown(isAlbum)
        atlas:SetShown(not isAlbum)
        local h
        if isAlbum then
            h = HEAD + drawAlbum(w - 32 - DETAIL_W - 12) + 12
            drawDetail()
        else
            h = 52 + drawAtlas(w - 32) + 12
        end
        if h ~= self.height then
            self.height = h
            card:SetHeight(h)
            if onHeight then onHeight(h) end
        end
    end
    UI:OnResize(card, function() col:Refresh() end)
    return col
end
