local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors

-- Profils de réglages (Modules/Profiles.lua) : section « Profils » des Options, sous Apparence.
-- Choisir le profil de ce perso, en créer, copier, supprimer, réinitialiser.
-- UI:BuildProfileCards(def, card) : def = page Options (reçoit RefreshProfiles), card(titre, hauteur) = carte de la section.
function UI.BuildProfileCards(_, self, card)
    do
        local P = WK.modules.Profiles
        local T = WK.T
        local function names()
            local o = {}
            for _, n in ipairs(P:Names()) do table.insert(o, { n, n == P.DEFAULT and T("Défaut") or n }) end
            return o
        end
        local useCard = card("Profil de ce perso", 40 + 46 + 40)
        self.profUse = UI:Dropdown(useCard, 220, 30, names(), function(v)
            if v ~= P:Current() then P:Use(v) end
        end)
        UI:SettingRow(useCard, -40, "Profil utilisé", "Apparence, QoL, halo, rares, récolte… Changer de profil recharge l'interface.", self.profUse, 240)
        self.profInfo = UI:Text(useCard, 11, C.muted)
        self.profInfo:SetPoint("TOPLEFT", 16, -96)
        self.profInfo:SetPoint("TOPRIGHT", -16, -96)
        self.profInfo:SetJustifyH("LEFT")

        local newCard = card("Nouveau profil", 40 + 46 + 30)
        local nameBox = UI:Input(newCard, 200, 30, "Nom du profil")
        local createBtn = UI:Button(newCard, "Créer", 80, 30, "primary", "plus")
        local holder = CreateFrame("Frame", nil, newCard)
        holder:SetSize(290, 30)
        nameBox:SetParent(holder); nameBox:SetPoint("LEFT")
        createBtn:SetParent(holder); createBtn:SetPoint("LEFT", nameBox, "RIGHT", 8, 0)
        UI:SettingRow(newCard, -40, "Copie des réglages actuels", "Le nouveau profil part de tes réglages d'aujourd'hui ; choisis-le ensuite pour ce perso ou un autre.", holder, 300)
        self.profMsg = UI:Text(newCard, 11, C.muted)
        self.profMsg:SetPoint("TOPLEFT", 16, -92)
        local function create()
            local ok, err = P:Create(nameBox:GetText())
            if ok then
                self.profMsg:SetText(string.format(T("Profil « %s » créé."), nameBox:GetText()))
                self.profMsg:SetTextColor(unpack(C.positive))
                nameBox:SetText("")
            else
                self.profMsg:SetText(err)
                self.profMsg:SetTextColor(unpack(C.warning))
            end
            self:RefreshProfiles()
        end
        createBtn:SetScript("OnClick", create)
        nameBox.onEnter = create

        local manage = card("Gérer les profils", 40 + 4 * 46 + 20)
        self.profPick = UI:Dropdown(manage, 220, 30, names(), function(v) self.profPicked = v; self:RefreshProfiles() end)
        UI:SettingRow(manage, -40, "Profil", nil, self.profPick, 240)
        local copyBtn = UI:Button(manage, "Copier dans mon profil", 190, 28, "secondary")
        copyBtn.tooltip = "Remplace les réglages du profil actuel par ceux du profil choisi, puis recharge l'interface."
        copyBtn:SetScript("OnClick", function() if self.profPicked then P:CopyFrom(self.profPicked) end end)
        UI:SettingRow(manage, -86, "Copier ses réglages", "Dans le profil que ce perso utilise.", copyBtn, 200)
        local delBtn = UI:Button(manage, "Supprimer", 120, 28, "ghost", "trash")
        delBtn.tooltip = "Maj + clic. Ni « Défaut », ni le profil en cours. Ses persos reviennent sur « Défaut »."
        delBtn:SetScript("OnClick", function()
            if not IsShiftKeyDown() or not self.profPicked then return end
            if P:Delete(self.profPicked) then self.profPicked = nil end
            self:RefreshProfiles()
        end)
        UI:SettingRow(manage, -132, "Supprimer le profil choisi", "Maj + clic.", delBtn, 130)
        local resetBtn = UI:Button(manage, "Réinitialiser", 120, 28, "ghost", "refresh")
        resetBtn.tooltip = "Maj + clic : remet le profil en cours aux réglages d'origine, puis recharge l'interface."
        resetBtn:SetScript("OnClick", function() if IsShiftKeyDown() then P:Reset() end end)
        UI:SettingRow(manage, -178, "Réglages d'origine pour mon profil", "Maj + clic.", resetBtn, 130)

        -- Partager : code d'un profil à copier, ou code collé qui devient un nouveau profil
        local dlg = CreateFrame("Frame", "WarbandKeeperProfileCode", UIParent)
        dlg:SetSize(520, 170); dlg:SetPoint("CENTER", 0, 80)
        dlg:SetFrameStrata("FULLSCREEN_DIALOG"); dlg:EnableMouse(true)
        UI:Panel(dlg, 12, C.surface, C.border)
        dlg.title = UI:Text(dlg, 14); dlg.title:SetPoint("TOPLEFT", 18, -16)
        dlg.text = UI:Text(dlg, 11, C.muted); dlg.text:SetPoint("TOPLEFT", 18, -40); dlg.text:SetPoint("RIGHT", -18, 0)
        dlg.text:SetJustifyH("LEFT"); if dlg.text.SetWordWrap then dlg.text:SetWordWrap(true) end
        dlg.input = UI:Input(dlg, 484, 30, "")
        dlg.input:SetPoint("TOPLEFT", 18, -78)
        if dlg.input.edit.SetMaxLetters then dlg.input.edit:SetMaxLetters(0) end
        dlg.name = UI:Input(dlg, 200, 30, T("Nom du profil (facultatif)"))
        dlg.name:SetPoint("BOTTOMLEFT", 18, 16)
        dlg.ok = UI:Button(dlg, "Importer", nil, 28, "primary")
        dlg.ok:SetPoint("BOTTOMRIGHT", -18, 16)
        dlg.close = UI:Button(dlg, "Fermer", nil, 28, "ghost")
        dlg.close:SetPoint("RIGHT", dlg.ok, "LEFT", -8, 0)
        dlg.close:SetScript("OnClick", function() dlg:Hide() end)
        dlg:Hide()
        if UISpecialFrames then table.insert(UISpecialFrames, "WarbandKeeperProfileCode") end
        self.profDlg = dlg

        local share = card("Partager un profil", 40 + 2 * 46 + 30)
        local expBtn = UI:Button(share, "Exporter", 120, 28, "secondary")
        expBtn.tooltip = "Affiche le code du profil choisi dans « Gérer les profils » (le tien par défaut), à copier avec Ctrl+C."
        expBtn:SetScript("OnClick", function()
            local name = self.profPicked or P:Current()
            local code, err = P:Export(name)
            dlg.title:SetText(string.format(T("Code du profil « %s »"), name == P.DEFAULT and T("Défaut") or name))
            dlg.text:SetText(code and T("Ctrl+C pour copier, puis colle-le dans « Importer » chez un autre perso, un autre compte ou un ami.") or err)
            dlg.input:SetText(code or ""); dlg.input:SetShown(code ~= nil)
            dlg.name:Hide(); dlg.ok:Hide()
            dlg:Show()
            if code then dlg.input.edit:SetFocus(); dlg.input.edit:HighlightText() end
        end)
        UI:SettingRow(share, -40, "Exporter un profil", "Le profil choisi dans « Gérer les profils » devient un code texte à copier.", expBtn, 130)
        local impBtn = UI:Button(share, "Importer", 120, 28, "primary")
        impBtn:SetScript("OnClick", function()
            dlg.title:SetText(T("Importer un profil"))
            dlg.text:SetText(T("Colle un code de profil (WKP1:…) avec Ctrl+V. Il devient un nouveau profil : choisis-le ensuite dans « Profil de ce perso »."))
            dlg.input:SetText(""); dlg.input:Show()
            dlg.name:SetText(""); dlg.name:Show(); dlg.ok:Show()
            dlg:Show(); dlg.input.edit:SetFocus()
        end)
        local function doImport()
            local ok, res = P:Import(dlg.input:GetText(), dlg.name:GetText())
            if ok then
                dlg:Hide()
                self.profMsg:SetText(string.format(T("Profil « %s » importé."), res))
                self.profMsg:SetTextColor(unpack(C.positive))
                self.shareMsg:SetText(string.format(T("Profil « %s » importé : choisis-le dans « Profil de ce perso »."), res))
                self.shareMsg:SetTextColor(unpack(C.positive))
                self.profPicked = res
                self:RefreshProfiles()
            else
                dlg.text:SetText(res); dlg.text:SetTextColor(unpack(C.warning))
                C_Timer.After(3, function() dlg.text:SetTextColor(unpack(C.muted)) end)
            end
        end
        dlg.ok:SetScript("OnClick", doImport)
        dlg.input.onEnter = function() if dlg.ok:IsShown() then doImport() end end
        UI:SettingRow(share, -86, "Importer un profil", "Colle un code partagé : un nouveau profil est créé, rien ne change avant que tu le choisisses.", impBtn, 130)
        self.shareMsg = UI:Text(share, 11, C.muted)
        self.shareMsg:SetPoint("TOPLEFT", 16, -138)

        function self:RefreshProfiles()
            local cur = P:Current()
            self.profUse:SetOptions(names()); self.profUse:Select(cur)
            self.profPick:SetOptions(names())
            if self.profPicked then self.profPick:Select(self.profPicked) end
            -- le menu affiche toujours un profil : c'est lui que visent Copier et Supprimer
            self.profPicked = self.profPick.selected
            local users = P:Users(cur)
            self.profInfo:SetText(string.format(T("%d profil(s) · celui-ci sert à : %s"), #P:Names(),
                #users > 0 and table.concat(users, ", ") or T("aucun perso")))
            if self.profPicked then
                local pu = P:Users(self.profPicked)
                self.profPick.tooltip = #pu > 0 and table.concat(pu, ", ") or nil
            end
        end
        self:RefreshProfiles()
    end
end
