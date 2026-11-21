local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Section « Fiabilité » des Options : bandeau des erreurs notées (Modules/Maintenance.lua) et nettoyage des
-- sauvegardes en cases à cocher, chacune avec ce qu'elle libère ; un seul bouton « Nettoyer », confirmé
-- par un second clic.
local Mt = function() return WK.modules.Maintenance end
-- avant la première ouverture de la section : seulement le point de l'icône Options
Mt().OnChange = function() if UI.RefreshUpdate then UI:RefreshUpdate() end end

---------------------------------------------------------------------------
-- Fenêtre du rapport : texte déjà sélectionné, Ctrl+C pour le copier
---------------------------------------------------------------------------
local pop
local function reportWindow()
    if pop then return pop end
    local f = CreateFrame("Frame", "WarbandKeeperErrorReport", UIParent)
    f:SetSize(600, 380)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    UI:Panel(f, 14, C.bg, C.border)
    if UISpecialFrames then table.insert(UISpecialFrames, "WarbandKeeperErrorReport") end
    f.title = UI:Text(f, 14); f.title:SetPoint("TOPLEFT", 16, -14); f.title:SetText(T("Rapport d'erreurs"))
    f.hint = UI:Text(f, 10, C.muted); f.hint:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)
    f.hint:SetText(T("Le texte est sélectionné : Ctrl+C pour le copier, puis colle-le tel quel."))
    local box = CreateFrame("Frame", nil, f)
    box:SetPoint("TOPLEFT", 16, -52); box:SetPoint("BOTTOMRIGHT", -16, 54)
    UI:Panel(box, 10, C.surface, C.border)
    local sc = UI:Scroll(box)
    sc:SetPoint("TOPLEFT", 8, -8); sc:SetPoint("BOTTOMRIGHT", -8, 8)
    local te = CreateFrame("EditBox", nil, sc.child)
    te:SetMultiLine(true)
    te:SetAutoFocus(false)
    te:SetFont(UI.FONT, 11, "")
    te:SetTextColor(unpack(C.text))
    te:SetWidth(540)
    te:SetPoint("TOPLEFT")
    te:SetScript("OnEscapePressed", function() f:Hide() end)
    -- lecture seule : toute frappe remet le rapport
    te:SetScript("OnTextChanged", function(s, user) if user and f.text then s:SetText(f.text); s:HighlightText() end end)
    f.edit, f.scroll = te, sc
    f.close = UI:Button(f, "Fermer", 90, 28, "primary")
    f.close:SetPoint("BOTTOMRIGHT", -16, 14)
    f.close:SetScript("OnClick", function() f:Hide() end)
    f.sel = UI:Button(f, "Tout sélectionner", 140, 28, "secondary")
    f.sel:SetPoint("RIGHT", f.close, "LEFT", -8, 0)
    f.sel:SetScript("OnClick", function() te:SetFocus(); te:HighlightText() end)
    f:Hide()
    pop = f
    return f
end
function UI:ShowErrorReport(select)
    local f = reportWindow()
    f.text = Mt():Report()
    f.edit:SetText(f.text)
    f:Show()
    C_Timer.After(0, function()
        f.scroll.child:SetSize(560, (f.edit:GetHeight() or 200) + 8)
        if f.scroll.UpdateBar then f.scroll:UpdateBar() end
    end)
    if select then f.edit:SetFocus(); f.edit:HighlightText() end
    Mt():MarkSeen()
    if UI.RefreshUpdate then UI:RefreshUpdate() end
end

---------------------------------------------------------------------------
-- Cartes de la section
---------------------------------------------------------------------------
function UI:BuildMaintenanceCards(page, card)
    local M = Mt()
    -- bandeau des erreurs
    local eb = card(nil, 76)
    eb.count = UI:Badge(eb, "0", C.negative); eb.count:SetPoint("LEFT", 18, 0)
    eb.title = UI:Text(eb, 13, C.text); eb.title:SetPoint("TOPLEFT", 64, -20)
    eb.sub = UI:Text(eb, 11, C.muted); eb.sub:SetPoint("TOPLEFT", eb.title, "BOTTOMLEFT", 0, -4)
    eb.sub:SetPoint("RIGHT", -360, 0); eb.sub:SetJustifyH("LEFT")
    if eb.sub.SetWordWrap then eb.sub:SetWordWrap(false) end
    eb.clear = UI:Button(eb, "Effacer", 90, 28, "danger")
    eb.clear:SetPoint("RIGHT", -16, 0)
    eb.clear:SetScript("OnClick", function() M:Clear(); UI:RefreshMaintenance() end)
    eb.copy = UI:Button(eb, "Copier le rapport", 150, 28, "primary")
    eb.copy:SetPoint("RIGHT", eb.clear, "LEFT", -8, 0)
    eb.copy:SetScript("OnClick", function() UI:ShowErrorReport(true); UI:RefreshMaintenance() end)
    eb.see = UI:Button(eb, "Voir", 70, 28, "secondary")
    eb.see:SetPoint("RIGHT", eb.copy, "LEFT", -8, 0)
    eb.see:SetScript("OnClick", function() UI:ShowErrorReport(false); UI:RefreshMaintenance() end)
    eb.bg2 = UI:Rounded(eb, 12, 1, "BACKGROUND", 3)

    -- données à la demande (dossier WarbandKeeper_Data, Core/Utils.lua : WK:NeedData)
    local dc = card("Données", 42 + 52 + 2 * 36 + 16, "grosses bases chargées seulement quand il le faut")
    dc.dot = dc:CreateTexture(nil, "ARTWORK"); dc.dot:SetTexture(UI.MEDIA .. "circle"); dc.dot:SetSize(10, 10)
    dc.dot:SetPoint("TOPLEFT", 18, -58)
    dc.label = UI:Text(dc, 12, C.text); dc.label:SetPoint("TOPLEFT", 38, -50)
    dc.label:SetText(T("Objectifs de quête, objets des listes BiS, recettes"))
    dc.sub = UI:Text(dc, 10, C.muted); dc.sub:SetPoint("TOPLEFT", dc.label, "BOTTOMLEFT", 0, -3)
    dc.go = UI:Button(dc, "Charger maintenant", 170, 28, "secondary")
    dc.go:SetPoint("TOPRIGHT", -16, -48)
    dc.go:SetScript("OnClick", function()
        if WK:NeedData("à la main") then UI:RefreshMaintenance(true)
        elseif not WK.dataMissing then WK:Print(T("En combat : les données seront chargées à la sortie du combat.")) end
        UI:RefreshMaintenance(true)
    end)
    local dcfg = WK.DataConfig
    UI:SettingRow(dc, -94, "Précharger après la connexion",
        "20 s après la connexion, hors combat, si une quête est suivie.",
        UI:Toggle(dc, function() return dcfg().preload end, function(v) dcfg().preload = v end), 50)
    UI:SettingRow(dc, -130, "Message quand les données sont chargées", "Une ligne dans le chat, une fois par séance.",
        UI:Toggle(dc, function() return dcfg().msg end, function(v) dcfg().msg = v or nil end), 50)
    function dc.Paint()
        local col, txt
        if WK.dataLoaded then
            col = C.positive
            txt = string.format(T("chargées à %s · %s"), _G.date("%H:%M", WK.dataAt or _G.time()), T(WK.dataWhy or "?"))
            dc.go:Hide()
        elseif WK.dataMissing then
            col = C.negative
            -- désactivé dans la liste des AddOns (pas absent) : le dire, réinstaller n'y changerait rien
            txt = (WK.dataMissing == "DISABLED")
                and T("WarbandKeeper_Data désactivé : coche-le dans les AddOns")
                or T("dossier WarbandKeeper_Data absent : réinstalle avec le client PC")
            dc.go:Hide()
        else
            col = C.dim
            txt = T("en attente : chargées au premier besoin")
            dc.go:Show()
        end
        dc.dot:SetVertexColor(col[1], col[2], col[3], 1)
        dc.sub:SetText(txt)
    end

    -- nettoyage
    local ROWH = 48
    local cc = card("Nettoyage", 46 + #M.PURGES * ROWH + 56, "une sauvegarde plus légère = connexion et /reload plus rapides")
    cc.total = UI:Text(cc, 11, C.muted); cc.total:SetPoint("TOPRIGHT", -18, -16); cc.total:SetJustifyH("RIGHT")
    cc.rows = {}
    for i, p in ipairs(M.PURGES) do
        local r = CreateFrame("Frame", nil, cc)
        r:SetHeight(ROWH)
        r:SetPoint("TOPLEFT", 16, -(42 + (i - 1) * ROWH)); r:SetPoint("TOPRIGHT", -16, -(42 + (i - 1) * ROWH))
        r.tg = UI:Toggle(r, function() return M.checked[p.key] end, function(v) M.checked[p.key] = v; UI:RefreshMaintenance(true) end)
        r.tg:SetPoint("LEFT", 0, 0)
        r.label = UI:Text(r, 12, C.text); r.label:SetPoint("TOPLEFT", 54, -9); r.label:SetText(T(p.label))
        r.sub = UI:Text(r, 10, C.muted); r.sub:SetPoint("TOPLEFT", r.label, "BOTTOMLEFT", 0, -3)
        r.gain = UI:Text(r, 13, C.positive); r.gain:SetPoint("RIGHT", -4, 0); r.gain:SetJustifyH("RIGHT")
        if i < #M.PURGES then
            r.line = r:CreateTexture(nil, "ARTWORK"); r.line:SetHeight(1)
            r.line:SetPoint("BOTTOMLEFT"); r.line:SetPoint("BOTTOMRIGHT"); r.line:SetColorTexture(unpack(C.border))
        end
        r.p = p
        cc.rows[i] = r
    end
    cc.go = UI:Button(cc, "Nettoyer", 200, 30, "primary")
    cc.go:SetPoint("BOTTOMLEFT", 16, 16)
    cc.note = UI:Text(cc, 11, C.muted); cc.note:SetPoint("LEFT", cc.go, "RIGHT", 12, 0)
    cc.note:SetText(T("Rien n'est effacé sans ce clic ; un second clic confirme."))
    cc.go:SetScript("OnClick", function()
        local gain = cc.gain or 0
        if gain <= 0 then return end
        if not cc.armed then
            cc.armed = true
            cc.go.label:SetText(string.format(T("Confirmer (-%s)"), M.Bytes(gain)))
            cc.note:SetText(UI:Hex(C.warning) .. T("Clique encore pour effacer ce qui est coché.") .. "|r")
            C_Timer.After(5, function() if cc.armed then cc.armed = nil; UI:RefreshMaintenance(true) end end)
            return
        end
        cc.armed = nil
        local freed = M:Clean(cc.scan)
        WK:Print(string.format(T("Nettoyage fait : environ %s libérés (au prochain /reload)."), M.Bytes(freed)))
        cc.scan = nil
        UI:RefreshMaintenance()
    end)

    -- rafraîchi à l'ouverture de la section ; « keep » garde la mesure déjà faite
    UI.RefreshMaintenance = function(_, keep)
        if not eb:IsVisible() then return end
        dc.Paint()
        local n = #M:List()
        local r1, g1, b1 = UI:Accent()
        if n > 0 then
            local e = M:List()[1]
            eb.count:Set(tostring(n), C.negative); eb.count:Show()
            eb.title:SetText(string.format(T(n > 1 and "%d erreurs notées depuis la %s" or "%d erreur notée depuis la %s"), n, M:Since() or WK.version))
            eb.sub:SetText(string.format(T("La dernière : %s, %s (x%d)"), e.m, date("%d/%m %H:%M", e.last or 0), e.n or 1))
            eb.bg2:SetColor(C.negative[1], C.negative[2], C.negative[3], 0.07)
        else
            eb.count:Set("0", C.positive)
            eb.title:SetText(T("Aucune erreur notée"))
            eb.sub:SetText(T("Si l'addon se trompe un jour, l'erreur s'affiche ici avec un rapport à copier."))
            eb.bg2:SetColor(r1, g1, b1, 0)
        end
        eb.see:SetShown(n > 0); eb.copy:SetShown(n > 0); eb.clear:SetShown(n > 0)
        -- mesure (une fois à l'ouverture, puis après chaque nettoyage)
        -- (gardée 5 min : la mesure parcourt toute la sauvegarde, prix de l'HV compris ; refaite après un
        -- nettoyage, qui remet cc.scanAt à nil)
        local now = _G.GetTime and _G.GetTime() or 0
        if not (cc.scan and (keep or (cc.scanAt and now - cc.scanAt < 300))) then
            cc.scan = M:Scan()
            cc.size = M:Total()
            cc.scanAt = now
        end
        cc.total:SetText(string.format(T("sauvegarde env. %s"), M.Bytes(cc.size)))
        local gain = 0
        for _, r in ipairs(cc.rows) do
            local s = cc.scan[r.p.key] or { n = 0, bytes = 0 }
            local on = M.checked[r.p.key]
            r.tg:Refresh()
            r.sub:SetText((s.text or "") .. (r.p.hint and (" · " .. T(r.p.hint)) or ""))
            r.gain:SetText(s.n > 0 and ("-" .. M.Bytes(s.bytes)) or T("rien"))
            r.gain:SetTextColor(unpack((on and s.n > 0) and C.positive or C.muted))
            if on and s.n > 0 then gain = gain + s.bytes end
        end
        cc.gain = gain
        if not cc.armed then
            cc.go.label:SetText(gain > 0 and string.format(T("Nettoyer (-%s)"), M.Bytes(gain)) or T("Rien à nettoyer"))
            cc.note:SetText(T("Rien n'est effacé sans ce clic ; un second clic confirme."))
        end
        cc.go:SetAlpha(gain > 0 and 1 or 0.5)
        -- vue : les erreurs ne comptent plus comme nouvelles
        if n > 0 then M:MarkSeen(); if UI.RefreshUpdate then UI:RefreshUpdate() end end
    end
    eb:HookScript("OnShow", function() C_Timer.After(0, function() UI:RefreshMaintenance() end) end)
    M.OnChange = function() if UI.RefreshUpdate then UI:RefreshUpdate() end; pcall(UI.RefreshMaintenance, UI, true) end
end
