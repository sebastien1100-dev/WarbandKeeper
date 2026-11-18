local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors

-- Page Profils (barre latérale, entre Patch notes et Options) : profils de réglages
-- (Modules/Profiles.lua). Choisir le profil de ce perso, en créer, copier, supprimer, réinitialiser.
local GAP = 12

UI:RegisterPage({
    key = "profiles", order = 98, nav = "Profils",

    Build = function(self, p)
        local sc = UI:Scroll(p)
        sc:SetAllPoints()
        local root, y = sc.child, 0
        local W = UI.PAGE_W - 12
        local function card(title, h)
            local c = UI:Card(root, title)
            c:SetSize(W, h)
            c:SetPoint("TOPLEFT", 0, -y)
            c:SetPoint("TOPRIGHT", 0, -y)
            y = y + h + GAP
            return c
        end
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

        sc.child:SetSize(W, y)
        UI:OnResize(p, function(w) sc.child:SetWidth(w) end)
    end,

    Refresh = function(self)
        if self.RefreshProfiles then self:RefreshProfiles() end
    end,
})
