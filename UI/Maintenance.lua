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
    local MEM_H = 118 -- bloc « mémoire » : chiffre, barre, deux lignes
    local dc = card("Données", 42 + 52 + MEM_H + 2 * 36 + 16, "grosses bases chargées seulement quand il le faut")
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
    -- mémoire réellement utilisée, lue dans le jeu (GetAddOnMemoryUsage) : l'addon (fenêtre, modules, bases
    -- chargées au démarrage) et le dossier des données à la demande (seulement une fois chargé)
    local my = -96
    dc.memBig = UI:Text(dc, 20, C.text); dc.memBig:SetPoint("TOPLEFT", 16, my)
    dc.memSub = UI:Text(dc, 11, C.muted); dc.memSub:SetPoint("BOTTOMLEFT", dc.memBig, "BOTTOMRIGHT", 8, 2)
    dc.memSub:SetText(T("de mémoire utilisée par l'addon"))
    dc.memBtn = UI:Button(dc, "Mesurer", 90, 24, "ghost")
    dc.memBtn:SetPoint("TOPRIGHT", -16, my + 2)
    dc.memBtn:SetScript("OnClick", function() dc.memAt = nil; dc.PaintMem() end)
    dc.track = _G.CreateFrame("Frame", nil, dc)
    dc.track:SetPoint("TOPLEFT", 16, my - 32); dc.track:SetPoint("TOPRIGHT", -16, my - 32); dc.track:SetHeight(8)
    dc.trackBg = dc.track:CreateTexture(nil, "BACKGROUND"); dc.trackBg:SetAllPoints()
    dc.segA = dc.track:CreateTexture(nil, "ARTWORK"); dc.segA:SetPoint("TOPLEFT"); dc.segA:SetPoint("BOTTOMLEFT")
    dc.segB = dc.track:CreateTexture(nil, "ARTWORK")
    dc.segB:SetPoint("TOPLEFT", dc.segA, "TOPRIGHT"); dc.segB:SetPoint("BOTTOMLEFT", dc.segA, "BOTTOMRIGHT")
    local function memLine(i, label)
        local l = { dot = dc:CreateTexture(nil, "ARTWORK"), t = UI:Text(dc, 12, C.text),
            v = UI:Text(dc, 12, C.text), tag = UI:Badge(dc, "") }
        l.dot:SetTexture(UI.MEDIA .. "circle"); l.dot:SetSize(8, 8)
        l.dot:SetPoint("TOPLEFT", 18, my - 50 - (i - 1) * 24)
        l.t:SetPoint("LEFT", l.dot, "RIGHT", 8, 0); l.t:SetText(T(label))
        l.tag:SetPoint("LEFT", l.t, "RIGHT", 8, 0)
        l.v:SetPoint("TOPRIGHT", -16, my - 47 - (i - 1) * 24); l.v:SetJustifyH("RIGHT")
        return l
    end
    dc.lineA = memLine(1, "Addon : fenêtre, modules, bases de démarrage")
    dc.lineB = memLine(2, "Données : objectifs de quête, listes BiS, recettes")
    local function memOf(name)
        local get = _G.GetAddOnMemoryUsage
        if not get then return nil end
        local ok, kb = pcall(get, name)
        return ok and type(kb) == "number" and kb or nil
    end
    local function fmt(kb)
        if not kb then return "?" end
        if kb >= 1024 then return (string.format(T("%.1f Mo"), kb / 1024):gsub("%.", ",")) end
        return string.format(T("%d Ko"), math.floor(kb + 0.5))
    end
    function dc.PaintMem()
        local now = _G.GetTime and _G.GetTime() or 0
        -- mesure du jeu : hors combat, au plus toutes les 3 s (elle parcourt la mémoire de tous les addons)
        if not (dc.memAt and now - dc.memAt < 3) and not (_G.InCombatLockdown and _G.InCombatLockdown()) then
            if _G.UpdateAddOnMemoryUsage then pcall(_G.UpdateAddOnMemoryUsage) end
            dc.memAt = now
        end
        local a = memOf("WarbandKeeper")
        local b = WK.dataLoaded and memOf("WarbandKeeper_Data") or 0
        local r, g, bl = UI:Accent()
        dc.trackBg:SetColorTexture(unpack(C.surface2))
        dc.segA:SetColorTexture(r, g, bl, 1)
        dc.segB:SetColorTexture(r, g, bl, 0.5)
        dc.lineA.dot:SetVertexColor(r, g, bl, 1)
        dc.lineB.dot:SetVertexColor(r, g, bl, 0.5)
        if not a then
            dc.memBig:SetText("?"); dc.segA:Hide(); dc.segB:Hide()
            dc.lineA.v:SetText("?"); dc.lineB.v:SetText("?")
            dc.lineA.tag:Set(T("au démarrage"), C.muted); dc.lineB.tag:Set(T("à la demande"), { r, g, bl })
            return
        end
        local total = a + b
        dc.memBig:SetText(fmt(total))
        local w = dc.track:GetWidth() or 0
        if w <= 0 then w = 400 end
        dc.segA:Show(); dc.segA:SetWidth(math.max(1, w * a / math.max(total, 1)))
        dc.segB:SetShown(b > 0); dc.segB:SetWidth(math.max(1, w * b / math.max(total, 1)))
        dc.lineA.v:SetText(fmt(a))
        dc.lineB.v:SetText(WK.dataLoaded and fmt(b) or T("pas chargées"))
        dc.lineA.tag:Set(T("au démarrage"), C.muted)
        dc.lineB.tag:Set(WK.dataLoaded and T("chargées") or T("à la demande"),
            WK.dataLoaded and C.positive or { r, g, bl })
    end
    UI.maintDataCard = dc
    local dcfg = WK.DataConfig
    UI:SettingRow(dc, -94 - MEM_H, "Précharger après la connexion",
        "20 s après la connexion, hors combat, si ton journal a des quêtes (repères des plaques actifs).",
        UI:Toggle(dc, function() return dcfg().preload end, function(v) dcfg().preload = v end), 50)
    UI:SettingRow(dc, -130 - MEM_H, "Message quand les données sont chargées",
        "Une ligne dans le chat, une fois par séance.",
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
        dc.PaintMem()
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
        r.tg = UI:Toggle(r, function() return M.checked[p.key] end, function(v)
            -- case changée : le bouton se désarme, le clic suivant redemande une confirmation (avec le bon montant)
            M.checked[p.key] = v; cc.armed = nil; UI:RefreshMaintenance(true)
        end)
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
            cc.armed = _G.GetTime() -- jeton : le minuteur ne désarme que cet armement-ci
            cc.go.label:SetText(string.format(T("Confirmer (-%s)"), M.Bytes(gain)))
            cc.note:SetText(UI:Hex(C.warning) .. T("Clique encore pour effacer ce qui est coché.") .. "|r")
            local tok = cc.armed
            C_Timer.After(5, function() if cc.armed == tok then cc.armed = nil; UI:RefreshMaintenance(true) end end)
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

---------------------------------------------------------------------------
-- Section « Diagnostics » des Options (maquette B) : liste des diagnostics à gauche (recherche, groupes), détail à
-- droite (à quoi ça sert, quand le lancer), « Lancer » = la commande /wk, dont les lignes écrites dans le chat sont
-- aussi reprises dans la fenêtre ; « Copier » sélectionne le résultat (Ctrl+C).
---------------------------------------------------------------------------
UI.DIAGS = {
    { "Interface", {
        { "sacs", "Sacs",
            "Sacs ouverts (du jeu ou d'un autre addon), cases trouvées, cadenas, sacs " ..
                "reconnus pour la fenêtre de désenchantement.",
            "Ouvre tes sacs avant de lancer." },
        { "halo", "Halo des métiers",
            "Halo des fenêtres de métier : ce qui est allumé et pourquoi.",
            "Ouvre la fenêtre d'un métier avant de lancer." },
        { "micro", "Micro menu",
            "Boutons du micro menu et horloge : ce qui est posé, ce qui manque." },
        { "rechargement", "Rechargement",
            "Boutons « /reload » posés par l'addon (le jeu bloque le rechargement direct)." },
        { "perf 30", "Performances",
            "Chronomètre pendant 30 s les évènements et cadres de l'addon, puis classe les " ..
                "plus lourds.",
            "Le classement arrive dans le chat au bout de 30 s." },
    } },
    { "Carte et voyage", {
        { "carte", "Carte du monde",
            "Calques dessinés, erreurs, pastilles placées, trajet du guidage.",
            "Ouvre la carte du monde avant de lancer." },
        { "nav", "Guidage",
            "Trajet calculé : étapes, chemins, vols et bateaux utilisés.",
            "Lance-le pendant un guidage." },
        { "bateau", "Bateaux",
            "Dernières traversées notées, lignes reconnues, raisons d'un refus." },
        { "vol diag", "Vols",
            "Relais de vol connus du perso, relais manquants, durées apprises." },
    } },
    { "Personnage", {
        { "talents", "Talents",
            "Relit les talents et montre ce que le jeu donne (arbres, rangs, points libres)." },
        { "plan diag", "Plan de montée",
            "Panneau du plan sur la fenêtre des talents : cadre trouvé, boutons repérés.",
            "Ouvre la fenêtre des talents avant de lancer." },
        { "armes", "Compétences d'armes",
            "Compétences d'armes lues (rang / max) et lignes non reconnues." },
        { "pistage", "Pistages",
            "Pistages de la minicarte lus, pour les buffs à ne pas oublier." },
        { "buff", "Buffer le suivant",
            "Candidats du bouton, sort choisi, joueurs refusés." },
        { "statsjeu", "Statistiques du jeu",
            "Statistiques du jeu relevées pour les cartes des stats en vol." },
    } },
    { "Économie et quêtes", {
        { "hv", "Hôtel des ventes",
            "État du dernier scan, prix enregistrés, enchères suivies." },
        { "lien", "Lien de métier",
            "Liens de métier gardés pour « Link tchat »." },
        { "chaines", "Chaînes de quêtes",
            "Chaînes de quêtes apprises en jeu (quête et quête d'avant)." },
    } },
}

-- lance /wk <cmd> et rend les lignes écrites dans le chat (couleurs et icônes retirées)
function UI.RunDiag(cmd)
    local lines = {}
    local old = WK.Print
    WK.Print = function(s, msg, ...)
        local txt = tostring(msg or "")
        txt = txt:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|H.-|h(.-)|h", "%1")
        lines[#lines + 1] = txt
        return old(s, msg, ...)
    end
    local ok, err = pcall(_G.SlashCmdList.WARBANDKEEPER, cmd)
    WK.Print = old
    if not ok then lines[#lines + 1] = "Erreur : " .. tostring(err) end
    return lines
end

function UI.BuildDiagPanel(_, host)
    local LIST_W = 300
    local left = UI:Card(host)
    left:SetPoint("TOPLEFT"); left:SetPoint("BOTTOMLEFT"); left:SetWidth(LIST_W)
    local right = UI:Card(host)
    right:SetPoint("TOPLEFT", LIST_W + 12, 0); right:SetPoint("BOTTOMRIGHT")
    local search = UI:Input(left, LIST_W - 28, 30, "Rechercher...", "search")
    search:SetPoint("TOPLEFT", 14, -14)
    local sc = UI:Scroll(left)
    sc:SetPoint("TOPLEFT", 8, -54); sc:SetPoint("BOTTOMRIGHT", -8, 10)
    local rows, heads = {}, {}
    local selected, query
    -- détail
    local title = UI:Text(right, 15); title:SetPoint("TOPLEFT", 18, -16)
    local cmdT = UI:Text(right, 11); cmdT:SetPoint("LEFT", title, "RIGHT", 10, 0)
    local desc = UI:Text(right, 12, C.muted); desc:SetPoint("TOPLEFT", 18, -44); desc:SetPoint("TOPRIGHT", -18, -44)
    desc:SetJustifyH("LEFT"); if desc.SetWordWrap then desc:SetWordWrap(true) end
    local hint = UI:Text(right, 11, C.gold)
    hint:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -6); hint:SetPoint("RIGHT", -18, 0)
    hint:SetJustifyH("LEFT")
    local copy = UI:Button(right, "Copier", 90, 28, "secondary")
    copy:SetPoint("TOPRIGHT", -18, -12)
    local run = UI:Button(right, "Lancer", 100, 28, "primary", "play")
    run:SetPoint("RIGHT", copy, "LEFT", -8, 0)
    local box = _G.CreateFrame("Frame", nil, right)
    box:SetPoint("TOPLEFT", 18, -104); box:SetPoint("BOTTOMRIGHT", -18, 34)
    UI:Panel(box, 10, C.surface, C.border)
    local osc = UI:Scroll(box)
    osc:SetPoint("TOPLEFT", 10, -8); osc:SetPoint("BOTTOMRIGHT", -10, 8)
    local te = _G.CreateFrame("EditBox", nil, osc.child)
    te:SetMultiLine(true); te:SetAutoFocus(false)
    te:SetFont(UI.MONO or UI.FONT, 11, ""); te:SetTextColor(unpack(C.text))
    te:SetWidth(400); te:SetPoint("TOPLEFT")
    te:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    te:SetScript("OnTextChanged", function(s, user)
        if user and s.text then s:SetText(s.text); s:HighlightText() end
    end)
    local foot = UI:Text(right, 10, C.dim); foot:SetPoint("BOTTOMLEFT", 18, 12)
    foot:SetText(T("Le résultat s'écrit aussi dans le chat. Copier : texte sélectionné, Ctrl+C pour le copier."))
    local function setOut(txt)
        te.text = txt
        te:SetText(txt)
        _G.C_Timer.After(0, function()
            osc.child:SetSize(te:GetWidth() + 4, (te:GetHeight() or 100) + 8)
            if osc.UpdateBar then osc:UpdateBar() end
        end)
    end
    UI:OnResize(right, function(w) te:SetWidth(math.max(200, w - 72)) end)

    local function show(d)
        selected = d
        title:SetText(T(d[2]))
        cmdT:SetText(UI:Hex({ UI:Accent() }) .. "/wk " .. d[1] .. "|r")
        desc:SetText(T(d[3]))
        hint:SetText(d[4] and T(d[4]) or "")
        setOut(d.out or T("Pas encore lancé : clique sur « Lancer »."))
        for _, r in ipairs(rows) do r:Paint() end
    end
    run:SetScript("OnClick", function()
        if not selected then return end
        local lines = UI.RunDiag(selected[1])
        selected.out = #lines > 0 and table.concat(lines, "\n") or T("(rien n'a été écrit)")
        setOut(selected.out)
    end)
    copy:SetScript("OnClick", function() te:SetFocus(); te:HighlightText() end)

    local function layout()
        local y = 0
        local hi, ri = 0, 0
        for _, grp in ipairs(UI.DIAGS) do
            local shown = {}
            for _, d in ipairs(grp[2]) do
                local hay = (T(d[2]) .. " " .. d[1] .. " " .. T(d[3])):lower()
                if not query or query == "" or hay:find(query, 1, true) then shown[#shown + 1] = d end
            end
            if #shown > 0 then
                hi = hi + 1
                local h = heads[hi]
                if not h then h = UI:Text(sc.child, 10, C.dim); heads[hi] = h end
                h:ClearAllPoints(); h:SetPoint("TOPLEFT", 8, -y - 8); h:SetText(UI:Upper(T(grp[1]))); h:Show()
                y = y + 26
                for _, d in ipairs(shown) do
                    ri = ri + 1
                    local r = rows[ri]
                    if not r then
                        r = _G.CreateFrame("Button", nil, sc.child)
                        r:SetHeight(28)
                        r.bg = UI:Rounded(r, 7, 0, "BACKGROUND", 1)
                        r.n = UI:Text(r, 12); r.n:SetPoint("LEFT", 10, 0)
                        r.c = UI:Text(r, 10, C.dim); r.c:SetPoint("RIGHT", -10, 0)
                        function r:Paint()
                            local sel = selected == self.d
                            local ar, ag, ab = UI:Accent()
                            self.bg:SetColor(ar, ag, ab, sel and 0.16 or 0.08)
                            self.bg:SetShown(sel or self.hover)
                            if sel then self.c:SetTextColor(ar, ag, ab) else self.c:SetTextColor(unpack(C.dim)) end
                        end
                        r:SetScript("OnEnter", function(s) s.hover = true; s:Paint() end)
                        r:SetScript("OnLeave", function(s) s.hover = false; s:Paint() end)
                        r:SetScript("OnClick", function(s) show(s.d) end)
                        UI:OnAccent(function() r:Paint() end)
                        rows[ri] = r
                    end
                    r.d = d
                    r.n:SetText(T(d[2])); r.c:SetText("/wk " .. d[1])
                    r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:SetPoint("RIGHT", sc.child, "RIGHT", 0, 0)
                    r:Show(); r:Paint()
                    y = y + 30
                end
            end
        end
        for i = hi + 1, #heads do heads[i]:Hide() end
        for i = ri + 1, #rows do rows[i]:Hide() end
        sc.child:SetWidth(LIST_W - 28)
        sc:SetContentHeight(y + 8)
    end
    search.onChange = function(t) query = (t or ""):lower(); layout() end
    layout()
    show(UI.DIAGS[1][2][1])
end
