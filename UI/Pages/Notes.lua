local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Couleurs de sens de la palette (UI/Themes.lua), lues à l'affichage : ajouts en vert (positive),
-- modifications en ambre (warning), corrections en rouge doux (negative).
local SECTIONS = {
    { "added", "+  AJOUTS", "positive" },
    { "changed", "~  MODIFICATIONS", "warning" },
    { "fixed", "!  CORRECTIONS", "negative" },
}

local function notesSeen() return WK.DB.global.settings.notesSeenVersion == WK.version end

-- Texte à la ligne automatique (largeur posée par la mise en page de la carte)
local function wrapped(parent, text, color, size)
    local fs = UI:Text(parent, size or 12, color)
    if fs.SetWordWrap then fs:SetWordWrap(true) end
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    fs:SetSpacing(3)
    fs:SetText(text)
    return fs
end

-- Carte d'une version (ou de la feuille de route). Les éléments sont créés une fois ;
-- card:Layout(largeur) les place et renvoie la hauteur (appelé à chaque changement de taille).
local function VersionCard(parent, entry, isCurrent)
    local card = UI:Card(parent, nil, nil, isCurrent)

    local title = UI:Text(card, 16)
    title:SetPoint("TOPLEFT", 18, -16)
    title:SetText(entry.roadmap and "À venir" or ("v" .. entry.version))
    UI:OnAccent(function() title:SetTextColor(UI:Accent()) end)
    local after = title
    if entry.date then
        local d = UI:Badge(card, entry.date, C.muted)
        d:SetPoint("LEFT", after, "RIGHT", 10, 0)
        after = d
    end
    if not entry.roadmap then
        local r = entry.restart and UI:Badge(card, T("redémarrer le jeu"), C.warning) or UI:Badge(card, T("/reload suffit"), C.muted)
        r:SetPoint("LEFT", after, "RIGHT", 6, 0)
        after = r
    end
    if isCurrent then
        local cur = UI:Badge(card, "version installée")
        cur:SetPoint("LEFT", after, "RIGHT", 6, 0)
    end
    if entry.roadmap then
        local hint = UI:Text(card, 11, C.muted)
        hint:SetPoint("LEFT", title, "RIGHT", 12, 0)
        hint:SetText("prévu, pas encore commencé")
    end

    -- éléments à placer : { kind = "bullet", dot, fs } / { kind = "head", badge, stripe } / { kind = "end", stripe }
    local parts = {}
    local function bullets(list, color)
        for _, line in ipairs(list) do
            table.insert(parts, { kind = "bullet", dot = UI:Icon(card, "circle", 5, color or C.muted, "ARTWORK"),
                fs = wrapped(card, line, C.text, 12) })
        end
    end
    if entry.roadmap then
        bullets(entry.items, C.dim)
    else
        for _, sec in ipairs(SECTIONS) do
            local list = entry[sec[1]]
            if list and #list > 0 then
                -- liseré de la couleur de la rubrique, sur toute sa hauteur
                local stripe = card:CreateTexture(nil, "ARTWORK")
                local col = C[sec[3]]
                stripe:SetColorTexture(unpack(col))
                table.insert(parts, { kind = "head", badge = UI:Badge(card, sec[2], col), stripe = stripe })
                bullets(list, col)
                table.insert(parts, { kind = "end", stripe = stripe })
            end
        end
    end

    function card:Layout(width)
        local h, top = 48, 0
        local textW = width - 18 - 34 - 18
        for _, e in ipairs(parts) do
            if e.kind == "head" then
                top = h
                e.badge:ClearAllPoints(); e.badge:SetPoint("TOPLEFT", 26, -h)
                h = h + 26
            elseif e.kind == "bullet" then
                e.dot:ClearAllPoints(); e.dot:SetPoint("TOPLEFT", 30, -h - 6)
                e.fs:ClearAllPoints(); e.fs:SetPoint("TOPLEFT", 44, -h); e.fs:SetWidth(textW)
                h = h + (e.fs:GetStringHeight() or 16) + 7
            else
                e.stripe:ClearAllPoints(); e.stripe:SetPoint("TOPLEFT", 16, -top)
                e.stripe:SetSize(3, math.max(1, h - top - 2))
                h = h + 6
            end
        end
        h = h + 10
        self:SetHeight(h)
        return h
    end
    return card
end

UI:RegisterPage({
    key = "notes", order = 9, navIcon = "notes",
    title = "Patch notes",
    subtitle = "Tout ce qui a été ajouté, modifié et corrigé, version par version.",
    count = function() return notesSeen() and "" or "•" end,

    Build = function(self, p)
        -- deux onglets : notes de version (sommaire à gauche) et « À venir » rangé par thème
        local nTodo = #(WK.Roadmap or {})
        local views = {}
        local tabSeg = UI:Segmented(p, { { "notes", "Notes de version" }, { "todo", string.format(T("À venir · %d"), nTodo) } },
            function(v) for k, f in pairs(views) do f:SetShown(k == v) end end, 30)
        tabSeg:SetPoint("TOPLEFT")
        local function view(key)
            local f = CreateFrame("Frame", nil, p)
            f:SetPoint("TOPLEFT", 0, -44); f:SetPoint("BOTTOMRIGHT")
            views[key] = f
            return f
        end

        -----------------------------------------------------------------
        -- Notes de version : sommaire à gauche (clic : saute à la version), cartes à droite.
        -- Plus de 400 versions : cartes créées par lots de 15 (sinon la page est trop lourde et reste vide).
        -----------------------------------------------------------------
        local nv = view("notes")
        local IDX_W = 170
        local idx = UI:Scroll(nv)
        idx:SetPoint("TOPLEFT"); idx:SetPoint("BOTTOMLEFT"); idx:SetWidth(IDX_W)
        local scroll = UI:Scroll(nv)
        scroll:SetPoint("TOPLEFT", IDX_W + 12, 0); scroll:SetPoint("BOTTOMRIGHT")
        local cards, rows, made = {}, {}, 0
        local PAGE = 15
        local more = UI:Button(scroll.child, "Versions plus anciennes", 240, 30, "secondary")
        local idxMore = UI:Text(idx.child, 11, C.text)
        local idxMoreB = CreateFrame("Button", nil, idx.child); idxMoreB:SetAllPoints(idxMore)
        UI:OnAccent(function() idxMore:SetTextColor(UI:Accent()) end)
        local sel = 1
        local layout
        local function paintRows()
            for i, r in ipairs(rows) do
                r.bg:SetColor(C.surface2[1], C.surface2[2], C.surface2[3], i == sel and 1 or 0)
                r.v:SetTextColor(unpack(i == sel and C.text or C.muted))
            end
        end
        local function addBatch()
            local last = math.min(#WK.Changelog, made + PAGE)
            for i = made + 1, last do
                local entry = WK.Changelog[i]
                local ok, card = pcall(VersionCard, scroll.child, entry, i == 1 and entry.version == WK.version)
                if ok and card then
                    table.insert(cards, card)
                    local r = CreateFrame("Button", nil, idx.child)
                    r:SetHeight(24)
                    r.bg = UI:Rounded(r, 6, 0, "BACKGROUND", 1)
                    r.v = UI:Text(r, 12, C.muted); r.v:SetPoint("LEFT", 10, 0); r.v:SetText("v" .. entry.version)
                    r.d = UI:Text(r, 10, C.dim); r.d:SetPoint("RIGHT", -8, 0); r.d:SetText(entry.date and entry.date:sub(1, 5) or "")
                    local n = #rows + 1
                    r:SetScript("OnClick", function()
                        sel = n; paintRows()
                        scroll:SetVerticalScroll(math.min(scroll:MaxScroll(), card.y or 0)); scroll:UpdateBar()
                    end)
                    rows[n] = r
                end
            end
            made = last
            more:SetShown(made < #WK.Changelog)
            more:SetLabel(string.format(T("Versions plus anciennes (%d)"), #WK.Changelog - made))
            idxMore:SetShown(made < #WK.Changelog)
            idxMore:SetText(string.format(T("+ %d plus anciennes"), #WK.Changelog - made))
            paintRows()
        end
        layout = function(w)
            local width = math.max(360, (w or scroll:GetWidth() or UI.PAGE_W) - 12)
            local y = 0
            for _, c in ipairs(cards) do
                c:ClearAllPoints()
                c:SetPoint("TOPLEFT", 0, -y)
                c:SetPoint("TOPRIGHT", 0, -y)
                c.y = y
                y = y + c:Layout(width) + 12
            end
            if more:IsShown() then
                more:ClearAllPoints(); more:SetPoint("TOP", scroll.child, "TOP", 0, -y)
                y = y + 42
            end
            scroll:SetContentHeight(y)
            local iy = 0
            idx.child:SetWidth(IDX_W)
            for _, r in ipairs(rows) do
                r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -iy); r:SetPoint("TOPRIGHT", -6, -iy)
                iy = iy + 26
            end
            if idxMore:IsShown() then
                idxMore:ClearAllPoints(); idxMore:SetPoint("TOPLEFT", 10, -(iy + 6))
                iy = iy + 28
            end
            idx:SetContentHeight(iy)
        end
        local function loadMore() addBatch(); layout() end
        more:SetScript("OnClick", loadMore)
        idxMoreB:SetScript("OnClick", loadMore)
        addBatch()
        UI:OnResize(scroll, layout)

        -----------------------------------------------------------------
        -- À venir : une colonne par thème (masonry sur 3 colonnes), une carte par idée (titre + phrase)
        -----------------------------------------------------------------
        local tv = view("todo")
        local ts = UI:Scroll(tv)
        ts:SetAllPoints()
        local blocks = {}
        for _, th in ipairs(WK.RoadmapThemes or {}) do
            local list = {}
            for _, it in ipairs(WK.Roadmap or {}) do if it.theme == th.key then list[#list + 1] = it end end
            if #list > 0 then
                local blk = CreateFrame("Frame", nil, ts.child)
                blk.dot = UI:Icon(blk, "circle", 8, nil, "ARTWORK"); blk.dot:SetPoint("TOPLEFT", 2, -4)
                blk.head = UI:Text(blk, 10, C.dim); blk.head:SetPoint("TOPLEFT", 16, -2)
                blk.head:SetText(string.upper(T(th.label)))
                local function tint()
                    local col = th.color == "accent" and { UI:Accent() } or C[th.color] or C.muted
                    blk.dot:SetVertexColor(col[1], col[2], col[3], 1)
                end
                tint(); UI:OnAccent(tint)
                blk.items = {}
                for _, it in ipairs(list) do
                    local box = CreateFrame("Frame", nil, blk)
                    UI:Panel(box, 9, C.surface2, C.border)
                    box.t = UI:Text(box, 12, C.text); box.t:SetPoint("TOPLEFT", 11, -9); box.t:SetJustifyH("LEFT")
                    box.t:SetText(T(it.title))
                    box.d = wrapped(box, T(it.text), C.muted, 11)
                    box.d:SetPoint("TOPLEFT", box.t, "BOTTOMLEFT", 0, -4)
                    table.insert(blk.items, box)
                end
                function blk.Layout(b, w)
                    local y = 22
                    for _, box in ipairs(b.items) do
                        box:ClearAllPoints(); box:SetPoint("TOPLEFT", 0, -y); box:SetWidth(w)
                        box.t:SetWidth(w - 22); box.d:SetWidth(w - 22)
                        local h = 9 + (box.t:GetStringHeight() or 14) + 4 + (box.d:GetStringHeight() or 14) + 10
                        box:SetHeight(h)
                        y = y + h + 7
                    end
                    b:SetSize(w, y)
                    return y
                end
                table.insert(blocks, blk)
            end
        end
        UI:OnResize(ts, function(w)
            local W = math.max(360, (w or ts:GetWidth() or UI.PAGE_W) - 12)
            local cols = W < 760 and 2 or 3
            local GAP = 12
            local cw = math.floor((W - GAP * (cols - 1)) / cols)
            local colY = {}
            for c = 1, cols do colY[c] = 0 end
            for _, blk in ipairs(blocks) do
                local best = 1
                for c = 2, cols do if colY[c] < colY[best] then best = c end end
                blk:ClearAllPoints(); blk:SetPoint("TOPLEFT", (best - 1) * (cw + GAP), -colY[best])
                colY[best] = colY[best] + blk:Layout(cw) + 14
            end
            local maxY = 0
            for c = 1, cols do maxY = math.max(maxY, colY[c]) end
            ts:SetContentHeight(maxY)
        end)

        tabSeg:Select("notes")
        views.todo:Hide()
    end,

    Refresh = function()
        WK.DB.global.settings.notesSeenVersion = WK.version
    end,
})
