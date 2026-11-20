local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors

-- Profils de réglages (Modules/Profiles.lua) : section « Profils » des Options, sous Apparence.
-- Une seule carte en deux colonnes : à gauche « Mes profils » (créer, et pour chaque profil : utiliser,
-- exporter, copier dans mon profil, supprimer ; réglages d'origine du profil en place), à droite « Partager »
-- (code du profil choisi à copier, code collé avec aperçu avant l'import).
-- UI:BuildProfileCards(def, card) : def = page Options (reçoit RefreshProfiles), card(titre, hauteur) = carte de la section.
local ROW_H = 44
function UI.BuildProfileCards(_, self, card)
    local P = WK.modules.Profiles
    local T = WK.T
    local function label(n) return n == P.DEFAULT and T("Défaut") or n end
    local box = card("Profils", 420, "tes réglages, par perso, et leur partage")
    box.title:Hide(); if box.subtitle then box.subtitle:Hide() end
    local left = CreateFrame("Frame", nil, box)
    left:SetPoint("TOPLEFT", 16, -16); left:SetPoint("BOTTOMLEFT", 16, 16)
    local right = CreateFrame("Frame", nil, box)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 14, 0); right:SetPoint("BOTTOMRIGHT", -16, 16)
    box:SetScript("OnSizeChanged", function(b, w) left:SetWidth(math.max(380, math.floor(((w or b:GetWidth()) - 46) * 0.56))) end)
    left:SetWidth(460)
    -- fond de la colonne Partager
    right.bg = UI:Rounded(right, 10, 0, "BACKGROUND", 2); right.bg:SetColor(C.surface2[1], C.surface2[2], C.surface2[3], 0.6)

    ---------------------------------------------------------------- Mes profils
    local head = UI:Text(left, 13); head:SetPoint("TOPLEFT", 0, -8); head:SetText(T("Mes profils"))
    self.profCount = UI:Text(left, 11, C.muted); self.profCount:SetPoint("LEFT", head, "RIGHT", 10, 0)
    local createBtn = UI:Button(left, "Créer", 84, 28, "primary", "plus")
    createBtn:SetPoint("TOPRIGHT", 0, 0)
    local nameBox = UI:Input(left, 170, 28, "Nom du profil")
    nameBox:SetPoint("RIGHT", createBtn, "LEFT", -8, 0)
    self.profMsg = UI:Text(left, 11, C.muted); self.profMsg:SetPoint("TOPLEFT", 0, -36); self.profMsg:SetPoint("RIGHT", 0, 0)
    self.profMsg:SetJustifyH("LEFT")
    local function say(txt, col) self.profMsg:SetText(txt or ""); self.profMsg:SetTextColor(unpack(col or C.muted)) end
    local function create()
        local ok, err = P:Create(nameBox:GetText())
        if ok then say(string.format(T("Profil « %s » créé."), nameBox:GetText()), C.positive); nameBox:SetText("")
        else say(err, C.warning) end
        self:RefreshProfiles()
    end
    createBtn:SetScript("OnClick", create)
    nameBox.onEnter = create

    local rows = {}
    local function row(i)
        if rows[i] then return rows[i] end
        local r = CreateFrame("Frame", nil, left)
        r:SetHeight(ROW_H - 6)
        r.edge = UI:Rounded(r, 9, 0, "BACKGROUND", 1)
        r.bg = UI:Rounded(r, 8, 1, "BACKGROUND", 2)
        r.name = UI:Text(r, 12); r.name:SetPoint("LEFT", 12, 0)
        r.pill = CreateFrame("Frame", nil, r); r.pill:SetHeight(16)
        r.pill.bg = UI:Rounded(r.pill, 8, 0, "BACKGROUND", 3)
        r.pill.t = UI:Text(r.pill, 9); r.pill.t:SetPoint("CENTER"); r.pill.t:SetText(T("ce perso"))
        r.pill:SetWidth((r.pill.t:GetStringWidth() or 40) + 14)
        r.pill:SetPoint("LEFT", r.name, "RIGHT", 8, 0)
        r.users = UI:Text(r, 10, C.muted)
        r.del = UI:Button(r, "", 26, 24, "ghost", "trash"); r.del:SetPoint("RIGHT", -6, 0)
        r.del.tooltip = "Maj + clic : supprimer ce profil. Ses persos reviennent sur « Défaut »."
        r.copy = UI:Button(r, "Copier", nil, 24, "ghost"); r.copy:SetPoint("RIGHT", r.del, "LEFT", -2, 0)
        r.copy.tooltip = "Remplace les réglages de ton profil par ceux-ci (rechargement demandé)."
        r.exp = UI:Button(r, "Exporter", nil, 24, "ghost"); r.exp:SetPoint("RIGHT", r.copy, "LEFT", -2, 0)
        r.exp.tooltip = "Affiche son code dans Partager, à droite."
        r.use = UI:Button(r, "Utiliser", nil, 24, "secondary"); r.use:SetPoint("RIGHT", r.exp, "LEFT", -6, 0)
        r.use.tooltip = "Ce perso passe sur ce profil (rechargement demandé)."
        r.use:SetScript("OnClick", function(s) P:Use(s:GetParent().prof) end)
        r.exp:SetScript("OnClick", function(s) self.profPicked = s:GetParent().prof; self:RefreshProfiles() end)
        r.copy:SetScript("OnClick", function(s) P:CopyFrom(s:GetParent().prof) end)
        r.del:SetScript("OnClick", function(s)
            if not IsShiftKeyDown() then say(T("Maj + clic pour supprimer."), C.warning) return end
            local n = s:GetParent().prof
            if P:Delete(n) then
                if self.profPicked == n then self.profPicked = nil end
                say(string.format(T("Profil « %s » supprimé."), label(n)), C.muted)
            end
            self:RefreshProfiles()
        end)
        r.users:SetPoint("LEFT", r.pill, "RIGHT", 10, 0); r.users:SetPoint("RIGHT", r.use, "LEFT", -8, 0)
        r.users:SetJustifyH("LEFT")
        rows[i] = r
        return r
    end
    self.profRows = rows
    local resetL = UI:Text(left, 11, C.muted)
    local resetBtn = UI:Button(left, "Réinitialiser", nil, 24, "ghost", "refresh")
    resetBtn.tooltip = "Maj + clic : remet le profil en place aux réglages d'origine (rechargement demandé)."
    resetBtn:SetScript("OnClick", function()
        if IsShiftKeyDown() then P:Reset() else say(T("Maj + clic pour remettre les réglages d'origine."), C.warning) end
    end)

    ---------------------------------------------------------------- Partager
    local sh = UI:Text(right, 13); sh:SetPoint("TOPLEFT", 14, -12); sh:SetText(T("Partager"))
    local expL = UI:Text(right, 10, C.muted); expL:SetPoint("TOPLEFT", 14, -40)
    local codeBox = UI:Input(right, 200, 30, "")
    codeBox:SetPoint("TOPLEFT", 14, -56); codeBox:SetPoint("RIGHT", -14, 0)
    if codeBox.edit.SetMaxLetters then codeBox.edit:SetMaxLetters(0) end
    -- le code reste celui du profil : une frappe dans la case le remet
    codeBox.onChange = function(_, user) if user and self.profCode then codeBox:SetText(self.profCode) end end
    local selBtn = UI:Button(right, "Tout sélectionner", nil, 24, "secondary")
    selBtn:SetPoint("TOPRIGHT", codeBox, "BOTTOMRIGHT", 0, -6)
    selBtn:SetScript("OnClick", function() codeBox.edit:SetFocus(); codeBox.edit:HighlightText() end)
    local copyHint = UI:Text(right, 10, C.muted); copyHint:SetPoint("LEFT", codeBox, "BOTTOMLEFT", 2, -18)
    copyHint:SetText(T("Ctrl+C pour copier"))

    local impL = UI:Text(right, 10, C.muted); impL:SetPoint("TOPLEFT", 14, -136); impL:SetText(T("IMPORTER UN CODE"))
    local pasteBox = UI:Input(right, 200, 30, "Colle ici un code WKP1:… (Ctrl+V)")
    pasteBox:SetPoint("TOPLEFT", 14, -152); pasteBox:SetPoint("RIGHT", -14, 0)
    if pasteBox.edit.SetMaxLetters then pasteBox.edit:SetMaxLetters(0) end
    local impBtn = UI:Button(right, "Importer", 96, 28, "primary")
    impBtn:SetPoint("TOPRIGHT", pasteBox, "BOTTOMRIGHT", 0, -8)
    local impName = UI:Input(right, 200, 28, "Nom (facultatif)")
    impName:SetPoint("TOPLEFT", pasteBox, "BOTTOMLEFT", 0, -8); impName:SetPoint("RIGHT", impBtn, "LEFT", -8, 0)
    local peek = UI:Text(right, 11, C.muted); peek:SetPoint("TOPLEFT", impName, "BOTTOMLEFT", 2, -10); peek:SetPoint("RIGHT", -14, 0)
    peek:SetJustifyH("LEFT"); if peek.SetWordWrap then peek:SetWordWrap(true) end
    self.profPeek = peek
    -- aperçu à chaque collage : nom du profil d'origine et nombre de groupes de réglages, ou la raison du refus
    local function preview()
        local txt = pasteBox:GetText() or ""
        if txt == "" then
            peek:SetText(T("Le code devient un nouveau profil : rien ne change avant que tu le choisisses.")); peek:SetTextColor(unpack(C.muted))
            return
        end
        local ok, a, n = P:Peek(txt)
        if ok then
            peek:SetText(string.format(T("Code valide : « %s », %d groupes de réglages."), a or T("Importé"), n)); peek:SetTextColor(unpack(C.positive))
        else
            peek:SetText(a); peek:SetTextColor(unpack(C.warning))
        end
    end
    pasteBox.onChange = function() preview() end
    local function doImport()
        local ok, res = P:Import(pasteBox:GetText(), impName:GetText())
        if ok then
            pasteBox:SetText(""); impName:SetText("")
            peek:SetText(string.format(T("Profil « %s » importé : clique « Utiliser » dans la liste pour le prendre."), res)); peek:SetTextColor(unpack(C.positive))
            self.profPicked = res
            self:RefreshProfiles()
        else
            peek:SetText(res); peek:SetTextColor(unpack(C.warning))
        end
    end
    impBtn:SetScript("OnClick", doImport)
    pasteBox.onEnter = doImport
    impName.onEnter = doImport
    preview()

    ---------------------------------------------------------------- rafraîchissement
    function self:RefreshProfiles()
        local cur = P:Current()
        local names = P:Names()
        local seen
        for _, n in ipairs(names) do if n == self.profPicked then seen = true end end
        if not seen then self.profPicked = cur end
        self.profCount:SetText(string.format(T("%d profil(s)"), #names))
        local ar, ag, ab = UI:Accent()
        local y = 58
        for i, n in ipairs(names) do
            local r = row(i)
            r.prof = n
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:SetPoint("TOPRIGHT", 0, -y)
            local mine, picked = n == cur, n == self.profPicked
            r.name:SetText(label(n))
            r.pill:SetShown(mine)
            r.pill.bg:SetColor(ar, ag, ab, 1); r.pill.t:SetTextColor(unpack(C.onAccent or C.bg))
            local users = P:Users(n)
            r.users:SetText(#users > 0 and table.concat(users, ", ") or T("aucun perso"))
            r.users:ClearAllPoints()
            if mine then r.users:SetPoint("LEFT", r.pill, "RIGHT", 10, 0) else r.users:SetPoint("LEFT", r.name, "RIGHT", 10, 0) end
            r.users:SetPoint("RIGHT", r.use, "LEFT", -8, 0)
            r.use:SetShown(not mine); r.copy:SetShown(not mine)
            r.del:SetShown(n ~= P.DEFAULT and not mine)
            r.exp:SetStyle(picked and "secondary" or "ghost")
            if mine then
                r.edge:SetColor(ar, ag, ab, 1); r.bg:SetColor(ar * 0.16 + C.surface2[1] * 0.5, ag * 0.16 + C.surface2[2] * 0.5, ab * 0.16 + C.surface2[3] * 0.5, 1)
            else
                r.edge:SetColor(C.border[1], C.border[2], C.border[3], 1); r.bg:SetColor(C.surface2[1], C.surface2[2], C.surface2[3], 1)
            end
            r:Show()
            y = y + ROW_H
        end
        for i = #names + 1, #rows do rows[i]:Hide() end
        resetL:ClearAllPoints(); resetL:SetPoint("TOPLEFT", 2, -(y + 8))
        resetL:SetText(string.format(T("Réglages d'origine pour « %s »"), label(cur)))
        resetBtn:ClearAllPoints(); resetBtn:SetPoint("TOPRIGHT", 0, -(y + 2))
        -- Partager : code du profil choisi (« Exporter » sur une ligne), le tien d'office
        local code, err = P:Export(self.profPicked)
        self.profCode = code
        expL:SetText(string.format(T("EXPORTER « %s »"), label(self.profPicked)))
        codeBox:SetText(code or err or "")
        selBtn:SetShown(code ~= nil)
        -- hauteur : la plus grande des deux colonnes
        local h = math.max(y + 40, 250) + 32
        box:SetHeight(h)
        local sec = self.sections and self.sections.profiles
        if sec and sec.scroll then sec.scroll:SetContentHeight(h + 8) end
    end
    self:RefreshProfiles()
end
