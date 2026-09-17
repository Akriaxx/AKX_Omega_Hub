local J = Quest
local S = J.Style
local MJ = S.mj
local ROW_H = 26
local PANEL_W, PANEL_H = 1080, 780

local function Edit(parent, width, x, y, maximum)
    local edit = OS2.UI.CreateStyledEditBox(parent, width, 26)
    edit:SetPoint("TOPLEFT", x, y)
    edit:SetAutoFocus(false); edit:SetMaxLetters(maximum or 8192)
    edit:SetScript("OnEscapePressed", edit.ClearFocus)
    edit:SetFont(STANDARD_TEXT_FONT, 13)
    edit:SetTextColor(unpack(MJ.ink))
    edit.bg:SetColorTexture(unpack(MJ.surfaceInset))
    edit.border:SetColorTexture(unpack(MJ.borderStrong))
    return edit
end

function J:PanelResult(ok, message)
    if not ok then self.Print(message or "Action impossible.")
    elseif message then self.Print(message) end
end

-- Chemin d'une quête (draft ou enregistrée) : trame, trame + chapitre, ou libre.
function J:QuestParentLabel(q)
    if q.chapitre_id then
        local c = self.mjDB.chapitres[q.chapitre_id]
        local t = c and self.mjDB.trames[c.trame_id]
        if c and t then return "Trame : " .. t.titre .. "  ·  Chapitre : " .. c.titre end
    end
    if q.trame_id then
        local t = self.mjDB.trames[q.trame_id]
        if t then return "Trame : " .. t.titre end
    end
    return "Quête libre"
end

function J:QuestStatusLabel()
    local panel = self.panel
    local base = panel.draft.id and ("Quête enregistrée · " .. #panel.draft.destinataires .. " destinataire(s)") or "Nouvelle quête"
    return base .. "  ·  " .. self:QuestParentLabel(panel.draft)
end

function J:ReadDraft()
    local panel = self.panel
    panel.draft.titre, panel.draft.donneur = panel.titleEdit:GetText(), panel.giverEdit:GetText()
    local step = panel.draft.etapes[panel.stepIndex]
    if step then step.texte = panel.stepEdit:GetText(); step.revelee = panel.revealed:GetChecked() == true end
    return panel.draft
end

local STATUS_CHIP_SHADE = { en_cours = "accent", terminee = "ok", echouee_annulee = "danger" }

function J:PaintStatusChip()
    local panel = self.panel
    local shade = STATUS_CHIP_SHADE[panel.draft.statut] or "accent"
    panel.statusButton:SetText(self.statuses[panel.draft.statut])
    panel.statusButton.bgN:SetColorTexture(unpack(MJ.ground))
    panel.statusButton.accent:SetColorTexture(unpack(MJ[shade .. "Dim"] or MJ.accentDim))
    panel.statusButton:GetFontString():SetTextColor(unpack(MJ[shade]))
end

-- `initial` (uniquement pour un nouveau brouillon) : { trame_id = } ou
-- { chapitre_id = } pour pré-rattacher la quête créée depuis le builder.
function J:SetDraft(draft, initial)
    if self.letterEditor then self.letterEditor:Hide() end
    local panel = self.panel
    self:ShowQuestForm()
    panel.draft = self:Copy(draft or { titre = "", donneur = "", etapes = { { texte = "", revelee = false } }, statut = "en_cours" })
    if not draft and initial then
        panel.draft.trame_id, panel.draft.chapitre_id = initial.trame_id, initial.chapitre_id
    end
    panel.stepIndex = 1
    panel.titleEdit:SetText(panel.draft.titre); panel.giverEdit:SetText(panel.draft.donneur)
    self:PaintStatusChip()
    panel.trameChip:SetText(self:QuestParentLabel(panel.draft))
    panel.questID:SetText(self:QuestStatusLabel())
    self:RefreshSteps()
    self:LoadStep(1)
end

function J:LoadStep(index)
    local panel = self.panel
    panel.stepIndex = index
    local step = panel.draft.etapes[index]
    panel.stepEdit:SetText(step and step.texte or "")
    panel.revealed:SetChecked(step and step.revelee or false)
    panel.stepHeading:SetText("Texte de l'étape " .. index)
    panel.editScroll:SetVerticalScroll(0)
    for i, row in ipairs(panel.stepRows) do self:PaintStepRow(row, i == index) end
end

function J:PaintStepRow(row, selected)
    row.bgN:SetColorTexture(unpack(selected and MJ.surfaceRaised or MJ.ground))
    row.accent:SetColorTexture(unpack(selected and MJ.accent or MJ.border))
    row:GetFontString():SetTextColor(unpack(selected and MJ.ink or MJ.inkMuted))
end

function J:RefreshSteps()
    local panel = self.panel
    for _, row in ipairs(panel.stepRows) do row:Hide() end
    for i, step in ipairs(panel.draft.etapes) do
        local row = panel.stepRows[i]
        if not row then
            row = S:MJButton(panel.stepsChild, "", 158, 0, -(i - 1) * 30, function()
                self:ReadDraft(); self:LoadStep(i)
            end)
            panel.stepRows[i] = row
        end
        row:SetText(i .. (step.revelee and " · révélée" or " · masquée")); row:Show()
        self:PaintStepRow(row, i == panel.stepIndex)
    end
    panel.stepsChild:SetHeight(math.max(170, #panel.draft.etapes * 30))
end

function J:SavePanelQuest()
    local q, err = self:SaveQuest(self:ReadDraft())
    if not q then self:PanelResult(false, err); return nil end
    local stepIndex = self.panel.stepIndex
    self:SetDraft(q); self:LoadStep(math.min(stepIndex, #q.etapes))
    self:RefreshLibrary(); self:RefreshDeliveryStatus()
    return q
end

function J:SendFromPanel(mode)
    if not self:RequireMJ() then return end
    local targets
    if mode == "group" or mode == "raid" then targets = self:GroupTargets(mode == "raid")
    else
        local target = self:Name(self.panel.targetEdit:GetText())
        if not target then self:PanelResult(false, "Renseigne un personnage destinataire."); return end
        targets = { target }
    end
    if #targets == 0 then self:PanelResult(false, "Ton personnage MJ n'est pas dans le groupe / raid demandé."); return end
    local q = self:SavePanelQuest()
    if not q then return end
    local ok, message = self:Distribute(q.id, targets, mode)
    self:PanelResult(ok, message)
    local stepIndex = self.panel.stepIndex
    self:SetDraft(q); self:LoadStep(math.min(stepIndex, #q.etapes))
    self:RefreshDeliveryStatus()
end

function J:RefreshDeliveryStatus()
    if not self.panel then return end
    local count = 0
    for _, pending in pairs(self.mjDB.outbox) do
        if self:Key(pending.auteur) == self:Key(self:Me()) then count = count + 1 end
    end
    self.panel.delivery:SetText(count > 0 and (count .. " remise(s) sans accusé de réception · nouvelle tentative automatique") or "Toutes les remises envoyées ont été reçues.")
end

-- ── Sommaire : Trames > Chapitres (optionnels) > Quêtes, + Quêtes libres ───

function J:BuildLibraryNodes()
    local panel, nodes = self.panel, {}
    local mjDB, me = self.mjDB, self:Key(self:Me())

    local function questNode(q, depth)
        return { kind = "quest", id = q.id, titre = q.titre, sous_titre = self.statuses[q.statut], statut = q.statut, depth = depth }
    end

    for _, tid in ipairs(mjDB.trameOrder) do
        local t = mjDB.trames[tid]
        if t and self:Key(t.auteur) == me then
            nodes[#nodes + 1] = { kind = "trame", id = t.id, titre = t.titre, count = #t.chapitres + #t.quetes, depth = 0 }
            if panel.expanded[t.id] ~= false then
                for _, cid in ipairs(t.chapitres) do
                    local c = mjDB.chapitres[cid]
                    if c then
                        nodes[#nodes + 1] = { kind = "chapitre", id = c.id, titre = c.titre, trame_id = t.id, count = #c.quetes, depth = 1 }
                        if panel.expanded[c.id] ~= false then
                            for _, qid in ipairs(c.quetes) do
                                local q = mjDB.quetes[qid]
                                if q then nodes[#nodes + 1] = questNode(q, 2) end
                            end
                        end
                    end
                end
                for _, qid in ipairs(t.quetes) do
                    local q = mjDB.quetes[qid]
                    if q then nodes[#nodes + 1] = questNode(q, 1) end
                end
            end
        end
    end

    -- Pas d'en-tête « Quêtes libres » : les quêtes orphelines apparaissent
    -- simplement à la suite, sans regroupement.
    for _, qid in ipairs(mjDB.libres) do
        local q = mjDB.quetes[qid]
        if q and self:Key(q.auteur) == me then nodes[#nodes + 1] = questNode(q, 0) end
    end
    return nodes
end

local STATUS_DOT_SHADE = { en_cours = "accent", terminee = "ok", echouee_annulee = "danger" }

function J:CreateLibraryRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(214, ROW_H - 1)
    row.selection = row:CreateTexture(nil, "BACKGROUND")
    row.selection:SetAllPoints(); row.selection:SetColorTexture(unpack(MJ.surfaceRaised))
    row.accent = row:CreateTexture(nil, "ARTWORK")
    row.accent:SetPoint("TOPLEFT", 0, 0); row.accent:SetPoint("BOTTOMLEFT", 0, 0); row.accent:SetWidth(2)
    row.accent:SetColorTexture(unpack(MJ.accent))
    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(); highlight:SetColorTexture(1, 1, 1, .04)
    row:SetHighlightTexture(highlight)
    row.dot = S:MJDot(row, 7)
    row.label = S:MJText(row, "", 12, 24, -6, 150)
    -- CreatePanelButton réserve 8px de marge de chaque côté du label : sous
    -- ~26px de large, le texte n'a plus aucune place pour s'afficher.
    row.delete = S:MJButton(row, "-", 26, 184, -2, function() self:ConfirmDelete(row.node.kind, row.node.id) end, "tiny")
    row:SetScript("OnClick", function() self:OnLibraryRowClick(row.node) end)
    row:RegisterForDrag("LeftButton")
    row:SetScript("OnDragStart", function()
        self.panel.dragRow = row
        row:SetAlpha(0.55)
    end)
    row:SetScript("OnDragStop", function()
        row:SetAlpha(1)
        local draggedRow = self.panel.dragRow
        self.panel.dragRow = nil
        if not draggedRow then return end
        local target
        for _, other in ipairs(self.panel.rows) do
            if other ~= draggedRow and other:IsShown() and other:IsMouseOver() then target = other.node; break end
        end
        -- Lâchée dans le vide (plus de ligne « Quêtes libres ») : une quête
        -- glissée hors de toute ligne, mais encore dans la bibliothèque,
        -- redevient orpheline.
        if not target and draggedRow.node.kind == "quest" and self.panel.libraryScroll:IsMouseOver() then
            target = { kind = "libre" }
        end
        if target then self:ApplyDrag(draggedRow.node, target) end
    end)
    return row
end

function J:PaintLibraryRow(row, node)
    local panel = self.panel
    local isGroup = node.kind ~= "quest"
    local indent = (node.depth or 0) * 14
    row.dot:SetShown(not isGroup)
    row.label:ClearAllPoints()
    if isGroup then
        local expanded = panel.expanded[node.id] ~= false
        row.label:SetPoint("LEFT", 10 + indent, 0)
        row.label:SetText((expanded and "[-] " or "[+] ") .. node.titre .. "  ·  " .. node.count)
        row.label:SetTextColor(unpack(MJ.accent))
    else
        local qIndent = math.max(0, indent - 14)
        row.dot:ClearAllPoints(); row.dot:SetPoint("LEFT", 24 + qIndent, 0)
        row.dot:SetVertexColor(unpack(MJ[STATUS_DOT_SHADE[node.statut] or "accent"]))
        row.label:SetPoint("LEFT", 38 + qIndent, 0)
        row.label:SetText(node.titre .. "  —  " .. (node.sous_titre or ""))
        row.label:SetTextColor(unpack(MJ.ink))
    end
    row.delete:SetShown(isGroup)
    local selected = (node.kind == "quest" and node.id == panel.draft.id)
        or (isGroup and panel.selected and panel.selected.kind == node.kind and panel.selected.id == node.id)
    row.selection:SetShown(selected)
    row.accent:SetShown(selected)
end

function J:RefreshLibrary()
    local panel = self.panel
    local nodes = self:BuildLibraryNodes()
    for _, row in ipairs(panel.rows) do row:Hide() end
    for i, node in ipairs(nodes) do
        local row = panel.rows[i]
        if not row then row = self:CreateLibraryRow(panel.libraryChild); panel.rows[i] = row end
        row.node = node
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        self:PaintLibraryRow(row, node)
        row:Show()
    end
    panel.libraryChild:SetHeight(math.max(500, #nodes * ROW_H))
end

function J:OnLibraryRowClick(node)
    if not self:RequireMJ() then self.panel:Hide(); return end
    local panel = self.panel
    if node.kind == "quest" then
        local draft = self.mjDB.quetes[node.id]
        if draft then self:SetDraft(draft) end
        self:RefreshLibrary()
        return
    end
    -- Consulter une trame ou un chapitre le sélectionne (son contenu remplit
    -- le côté droit) et bascule son dépli dans le même geste.
    panel.expanded[node.id] = panel.expanded[node.id] == false
    panel.selected = { kind = node.kind, id = node.id }
    self:ShowDetails(node.kind, node.id)
    self:RefreshLibrary()
end

-- ── Glisser-déposer : réorganise trames / chapitres / quêtes ───────────────
-- Règles : une trame ne se réordonne qu'entre trames ; un chapitre change de
-- trame ou d'ordre, jamais d'orphelin ni enfant d'un autre chapitre ; une
-- quête devient enfant d'une trame, d'un chapitre, ou libre.
function J:ApplyDrag(dragged, target)
    if not dragged or not target or (dragged.kind == target.kind and dragged.id == target.id) then return end
    local ok, err
    if dragged.kind == "trame" then
        if target.kind ~= "trame" then return end
        ok, err = self:SetTrameOrder(dragged.id, target.id)
    elseif dragged.kind == "chapitre" then
        if target.kind == "trame" then
            ok, err = self:SetChapitreParent(dragged.id, target.id, nil)
        elseif target.kind == "chapitre" then
            ok, err = self:SetChapitreParent(dragged.id, target.trame_id, target.id)
        else
            self:PanelResult(false, "Un chapitre appartient toujours à une trame.")
            return
        end
    elseif dragged.kind == "quest" then
        if target.kind == "trame" then
            ok, err = self:SetQuestParent(dragged.id, "trame", target.id, nil)
        elseif target.kind == "chapitre" then
            ok, err = self:SetQuestParent(dragged.id, "chapitre", target.id, nil)
        elseif target.kind == "libre" then
            ok, err = self:SetQuestParent(dragged.id, "libre", nil, nil)
        elseif target.kind == "quest" then
            local other = self.mjDB.quetes[target.id]
            if not other then return end
            if other.chapitre_id then ok, err = self:SetQuestParent(dragged.id, "chapitre", other.chapitre_id, target.id)
            elseif other.trame_id then ok, err = self:SetQuestParent(dragged.id, "trame", other.trame_id, target.id)
            else ok, err = self:SetQuestParent(dragged.id, "libre", nil, target.id) end
        end
    end
    if ok ~= nil then self:PanelResult(ok, err) end
    if self.panel.draft.id == dragged.id then self:SetDraft(self.mjDB.quetes[dragged.id]) end
    self:RefreshLibrary()
end

-- ── Contenu de droite : quête, ou détails d'une trame/chapitre consultée ───

-- Affiche le détail minimal d'une trame ou d'un chapitre (un nom, et pour un
-- chapitre sa trame) à la place des cartes de quête.
function J:ShowDetails(kind, id)
    local panel = self.panel
    local obj = kind == "trame" and self.mjDB.trames[id] or self.mjDB.chapitres[id]
    if not obj then return end
    if self.letterEditor then self.letterEditor:Hide() end
    panel.identity:Hide(); panel.steps:Hide(); panel.diffusion:Hide()
    panel.details:Show()
    panel.detailsKind, panel.detailsID = kind, id
    panel.detailsHeading:SetText(kind == "trame" and "Trame" or "Chapitre")
    if kind == "chapitre" then
        local t = self.mjDB.trames[obj.trame_id]
        panel.detailsParent:SetText("Trame : " .. (t and t.titre or "?"))
        panel.detailsParent:Show()
        panel.questID:SetText(panel.detailsParent:GetText() .. "  ·  Chapitre : " .. obj.titre)
    else
        panel.detailsParent:Hide()
        panel.questID:SetText("Trame : " .. obj.titre)
    end
    panel.detailsNameEdit:SetText(obj.titre)
end

function J:SaveDetails()
    local panel = self.panel
    local name = panel.detailsNameEdit:GetText()
    local ok, err
    if panel.detailsKind == "trame" then
        local t = self.mjDB.trames[panel.detailsID]
        ok, err = self:SaveTrame(panel.detailsID, name, t and t.description)
    else
        ok, err = self:SaveChapitre(panel.detailsID, name)
    end
    self:PanelResult(ok ~= nil, ok and "Enregistré." or err)
    self:RefreshLibrary()
    if ok then self:ShowDetails(panel.detailsKind, panel.detailsID) end
end

-- Reprend l'affichage des cartes de quête (Identité / Étapes / Diffusion).
function J:ShowQuestForm()
    local panel = self.panel
    panel.details:Hide()
    panel.identity:Show(); panel.steps:Show(); panel.diffusion:Show()
end

-- Rien à consulter : le côté droit reste entièrement vide tant qu'aucune
-- sélection ni création n'a eu lieu dans le sommaire.
function J:ShowEmpty()
    local panel = self.panel
    panel.details:Hide()
    panel.identity:Hide(); panel.steps:Hide(); panel.diffusion:Hide()
end

function J:ConfirmDelete(kind, id)
    local obj = kind == "trame" and self.mjDB.trames[id] or self.mjDB.chapitres[id]
    if not obj then return end
    StaticPopup_Show(kind == "trame" and "OMEGA_QUEST_DELETE_TRAME" or "OMEGA_QUEST_DELETE_CHAPITRE", obj.titre, nil, id)
end

-- ── Builder : petite fenêtre « nom seul », même identité que l'écritoire ───

function J:CreateNamePrompt()
    if self.namePrompt then return end
    local prompt = CreateFrame("Frame", "OmegaQuestNamePrompt", UIParent, "BackdropTemplate")
    self.namePrompt = prompt
    prompt:SetSize(360, 160)
    S:MJSurface(prompt, "surface", "borderStrong")
    -- Strate strictement au-dessus de l'écritoire (DIALOG) : Raise() seul ne
    -- suffit pas à séparer deux fenêtres qui partagent la même strate (voir
    -- le commentaire de S:Window) et elles finissent par se fondre visuellement.
    S:Window(prompt, "FULLSCREEN_DIALOG")
    prompt.heading = S:MJHeading(prompt, "", 18, 20, -20)
    prompt.nameEdit = Edit(prompt, 320, 20, -54, 180)
    prompt.nameEdit:SetScript("OnEnterPressed", function() self:CommitNamePrompt() end)
    prompt.nameEdit:SetScript("OnEscapePressed", function() prompt.nameEdit:ClearFocus(); prompt:Hide() end)
    S:MJButton(prompt, "Créer", 150, 20, -102, function() self:CommitNamePrompt() end, "primary")
    S:MJButton(prompt, "Annuler", 150, 190, -102, function() prompt:Hide() end)
    return prompt
end

function J:OpenNamePrompt(title, onCreate)
    self:CreateNamePrompt()
    local prompt = self.namePrompt
    prompt.heading:SetText(title)
    prompt.nameEdit:SetText("")
    prompt.onCreate = onCreate
    prompt:Show(); prompt:Raise()
    prompt.nameEdit:SetFocus()
end

function J:CommitNamePrompt()
    local prompt = self.namePrompt
    local name = prompt.nameEdit:GetText()
    prompt:Hide()
    if prompt.onCreate then prompt.onCreate(name) end
end

-- ── Accès MJ : fenêtre séparée ───────────────────────────────────────────

function J:RefreshAccess()
    local panel = self.accessPanel
    if not panel then return end
    local names = { "Nytherah (admin)" }
    for _, name in ipairs(self.mjDB.permissions.mj) do names[#names + 1] = name end
    panel.accessList:SetText(table.concat(names, ",   "))
    panel.accessList:SetHeight(math.max(100, panel.accessList:GetStringHeight()))
    panel.accessChild:SetHeight(math.max(100, panel.accessList:GetStringHeight() + 4))
    panel.accessEdit:SetEnabled(self:IsAdmin())
    panel.grant:SetEnabled(self:IsAdmin()); panel.revoke:SetEnabled(self:IsAdmin())
    panel.sync:SetText(self:IsAdmin() and "Diffuser les accès" or "Actualiser les accès")
end

function J:CreateAccessPanel()
    if self.accessPanel then return end
    local panel = CreateFrame("Frame", "OmegaQuestAccess", UIParent, "BackdropTemplate")
    self.accessPanel = panel
    panel:SetSize(520, 360)
    S:MJSurface(panel, "surface", "borderStrong")
    S:Window(panel, "DIALOG")
    S:MJHeading(panel, "Accès MJ", 22, 24, -20)
    S:MJText(panel, "Nytherah reste toujours administratrice. Elle seule diffuse la liste versionnée ; les autres personnages MJ disposent d'Actualiser les accès.", 11, 24, -54, 470, "inkMuted")
    S:MJText(panel, "Nom-Royaume", 10, 24, -98, 200, "inkFaint")
    panel.accessEdit = Edit(panel, 260, 24, -114, 100)
    panel.grant = S:MJButton(panel, "Ajouter", 95, 294, -114, function()
        local ok, err = self:SetMJ(panel.accessEdit:GetText(), true); self:PanelResult(ok, err); self:RefreshAccess()
    end, "primary")
    panel.revoke = S:MJButton(panel, "Retirer", 95, 399, -114, function()
        local ok, err = self:SetMJ(panel.accessEdit:GetText(), false); self:PanelResult(ok, err); self:RefreshAccess()
    end, "danger")
    local accessWell = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    accessWell:SetPoint("TOPLEFT", 24, -152); accessWell:SetSize(470, 130)
    S:MJSurface(accessWell, "surfaceInset", "border")
    panel.accessScroll, panel.accessChild = S:Scroll(accessWell, 454, 114, 8, -8)
    panel.accessList = S:MJText(panel.accessChild, "", 12, 0, 0, 450, "ink")
    panel.sync = S:MJButton(panel, "Diffuser les accès", 200, 294, -300, function()
        if self:IsAdmin() then self:BroadcastPermissions() else self:RequestPermissions() end
        self.Print("Synchronisation des accès demandée.")
    end, "primary")
    panel:SetScript("OnShow", function()
        if not self:RequireMJ() then panel:Hide(); return end
        self:RefreshAccess()
    end)
end

function J:OpenAccessPanel()
    local ok, err = self:RequireMJ()
    if not ok then self:PanelResult(false, err); return end
    self:CreateAccessPanel()
    self.accessPanel:Show(); self.accessPanel:Raise()
end

-- ── Écritoire du MJ ─────────────────────────────────────────────────────

function J:CreateMJPanel()
    if self.panel then return end
    local panel = CreateFrame("Frame", "OmegaQuestMJ", UIParent, "QuestMJTemplate")
    self.panel = panel
    S:MJSurface(panel, "ground", "borderStrong")
    S:Window(panel, "DIALOG")
    S:MJHeading(panel, "L'écritoire du MJ", 24, 24, -18)
    panel.questID = S:MJText(panel, "Nouvelle quête", 12, 24, -48, 520, "inkMuted")
    panel.testLetter = S:MJButton(panel, "Test", 80, 680, -20, function()
        if not self:RequireMJ() then return end
        self:ShowEnvelope(true, "blp")
    end)
    S:MJButton(panel, "Rédiger la lettre", 150, 770, -20, function() self:OpenLetterEditor() end)
    S:MJButton(panel, "Accès MJ", 110, 930, -20, function() self:OpenAccessPanel() end)

    -- Sommaire : trames (dossiers narratifs), leurs chapitres optionnels et
    -- leurs quêtes ; réorganisation entièrement par glisser-déposer.
    local library = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    library:SetPoint("TOPLEFT", 18, -84); library:SetSize(256, 672); S:MJSurface(library, "surfaceInset", "border")
    S:MJHeading(library, "Mes quêtes", 17, 16, -14)
    panel.rows, panel.expanded, panel.selected = {}, {}, nil
    panel.newTrameButton = S:MJButton(library, "Nouvelle trame", 224, 16, -44, function()
        self:OpenNamePrompt("Nom de la trame", function(name)
            local t, err = self:CreateTrame(name, "")
            self:PanelResult(t ~= nil, t and "Trame créée." or err)
            if t then
                panel.selected, panel.expanded[t.id] = { kind = "trame", id = t.id }, true
                self:ShowDetails("trame", t.id)
            end
            self:RefreshLibrary()
        end)
    end, "accent")
    panel.newChapitreButton = S:MJButton(library, "Nouveau chapitre", 224, 16, -76, function()
        if not (panel.selected and panel.selected.kind == "trame") then
            self:PanelResult(false, "Sélectionne une trame pour y ajouter un chapitre."); return
        end
        local trameID = panel.selected.id
        self:OpenNamePrompt("Nom du chapitre", function(name)
            local c, err = self:CreateChapitre(trameID, name)
            self:PanelResult(c ~= nil, c and "Chapitre créé." or err)
            if c then
                panel.selected, panel.expanded[c.id] = { kind = "chapitre", id = c.id }, true
                self:ShowDetails("chapitre", c.id)
            end
            self:RefreshLibrary()
        end)
    end, "accent")
    S:MJButton(library, "Nouvelle quête", 224, 16, -108, function()
        local initial = {}
        if panel.selected and panel.selected.kind == "chapitre" then initial.chapitre_id = panel.selected.id
        elseif panel.selected and panel.selected.kind == "trame" then initial.trame_id = panel.selected.id end
        self:SetDraft(nil, initial)
        self:RefreshLibrary()
    end, "accent")
    panel.libraryScroll, panel.libraryChild = S:Scroll(library, 222, 500, 16, -140)

    -- Carte : Détails — remplace Identité tant qu'une trame ou un chapitre
    -- est consulté dans le sommaire. Une trame (ou un chapitre) n'a besoin
    -- que d'un nom : pas de troisième carte pour elle.
    local details = S:MJCard(panel, 292, -84, 770, 172, "TRAME / CHAPITRE")
    panel.details = details
    panel.detailsHeading = S:MJHeading(details, "Trame", 20, 18, -16)
    panel.detailsParent = S:MJText(details, "", 11, 18, -48, 700, "inkFaint")
    S:MJText(details, "Nom", 10, 18, -68, 200, "inkFaint")
    panel.detailsNameEdit = Edit(details, 480, 18, -84, 180)
    panel.detailsNameEdit:SetScript("OnEnterPressed", function() self:SaveDetails() end)
    S:MJButton(details, "Enregistrer", 150, 18, -122, function() self:SaveDetails() end, "primary")
    S:MJButton(details, "Supprimer", 110, 178, -122, function()
        self:ConfirmDelete(panel.detailsKind, panel.detailsID)
    end, "danger")
    details:Hide()

    -- Carte : Identité.
    local identity = S:MJCard(panel, 292, -84, 770, 172, "IDENTITÉ")
    panel.identity = identity
    S:MJText(identity, "Titre", 10, 18, -14, 200, "inkFaint")
    panel.titleEdit = Edit(identity, 358, 18, -30, 180)
    S:MJText(identity, "Donneur (couleur et icône possibles)", 10, 394, -14, 340, "inkFaint")
    panel.giverEdit = Edit(identity, 358, 394, -30, 300)
    panel.statusButton = S:MJButton(identity, "En cours", 110, 18, -72, function()
        local statuses = { "en_cours", "terminee", "echouee_annulee" }
        for i, status in ipairs(statuses) do
            if panel.draft.statut == status then panel.draft.statut = statuses[i % #statuses + 1]; break end
        end
        self:PaintStatusChip()
    end)
    panel.trameChip = S:MJButton(identity, "Quête libre", 260, 138, -72, nil)
    S:MJButton(identity, "Enregistrer / actualiser", 190, 18, -118, function()
        if self:SavePanelQuest() then self.Print("Quête enregistrée ; mise à jour des destinataires en attente.") end
    end, "primary")
    S:MJButton(identity, "Supprimer", 90, 218, -118, function()
        local id = panel.draft.id
        if not id then self:PanelResult(false, "Sélectionne une quête enregistrée."); return end
        StaticPopup_Show("OMEGA_JOURNAL_DELETE", nil, nil, id)
    end, "danger")

    -- Carte : Étapes & récit.
    local steps = S:MJCard(panel, 292, -272, 770, 300, "ÉTAPES & RÉCIT")
    panel.steps = steps
    panel.stepHeading = S:MJText(steps, "Texte de l'étape 1", 14, 206, -14, 540, "inkMuted")
    panel.stepsScroll, panel.stepsChild = S:Scroll(steps, 170, 170, 18, -36)
    panel.stepRows = {}
    local editor = CreateFrame("Frame", nil, steps, "BackdropTemplate")
    editor:SetPoint("TOPLEFT", 206, -36); editor:SetSize(546, 170)
    S:MJSurface(editor, "surfaceInset", "border")
    panel.editScroll = S:Scroll(editor, 530, 154, 8, -8)
    panel.stepEdit = CreateFrame("EditBox", nil, panel.editScroll)
    panel.stepEdit:SetMultiLine(true); panel.stepEdit:SetAutoFocus(false); panel.stepEdit:SetWidth(526)
    panel.stepEdit:SetFont(STANDARD_TEXT_FONT, 13); panel.stepEdit:SetTextColor(unpack(MJ.ink))
    panel.stepEdit:SetMaxLetters(8192)
    panel.stepEdit:SetScript("OnEscapePressed", panel.stepEdit.ClearFocus)
    local measure = editor:CreateFontString(nil, "BACKGROUND")
    measure:SetFont(STANDARD_TEXT_FONT, 13); measure:SetWidth(526); measure:Hide()
    panel.stepEdit:SetScript("OnTextChanged", function(edit)
        measure:SetText(edit:GetText():gsub("|", "||"))
        edit:SetHeight(math.max(154, measure:GetStringHeight() + 24))
        panel.editScroll:UpdateScrollChildRect()
    end)
    panel.stepEdit:SetScript("OnCursorChanged", function(_, _, y, _, height)
        local offset = panel.editScroll:GetVerticalScroll()
        local top = -y
        if top < offset then panel.editScroll:SetVerticalScroll(top)
        elseif top + height > offset + 154 then panel.editScroll:SetVerticalScroll(top + height - 154) end
    end)
    panel.editScroll:SetScrollChild(panel.stepEdit)
    S:MJButton(steps, "+ Étape", 80, 18, -214, function()
        local draft = self:ReadDraft()
        if #draft.etapes >= 50 then return end
        draft.etapes[#draft.etapes + 1] = { texte = "", revelee = false }
        self:RefreshSteps(); self:LoadStep(#draft.etapes)
    end, "tiny")
    S:MJButton(steps, "− Étape", 80, 108, -214, function()
        local draft = self:ReadDraft()
        if #draft.etapes <= 1 then return end
        table.remove(draft.etapes, panel.stepIndex)
        self:RefreshSteps(); self:LoadStep(math.min(panel.stepIndex, #draft.etapes))
    end, "tiny")
    panel.revealed = OS2.UI.CreateStyledCheckbox(steps, "")
    panel.revealed:SetPoint("TOPLEFT", 206, -216)
    S:MJText(steps, "Révéler cette étape à tous les destinataires", 12, 232, -218, 500, "inkMuted")
    panel.revealed:SetScript("OnClick", function() self:ReadDraft(); self:RefreshSteps() end)
    S:MJText(steps, "Enregistrer applique textes, révélations et statut à tous les destinataires.", 10, 18, -258, 734, "inkFaint")

    -- Carte : Diffusion.
    local diffusion = S:MJCard(panel, 292, -588, 770, 150, "DIFFUSION")
    panel.diffusion = diffusion
    S:MJText(diffusion, "Destinataire", 10, 18, -14, 200, "inkFaint")
    panel.targetEdit = Edit(diffusion, 300, 18, -30, 100)
    S:MJButton(diffusion, "Utiliser ma cible", 180, 336, -30, function()
        if not UnitIsPlayer("target") then self:PanelResult(false, "Cible un personnage joueur."); return end
        panel.targetEdit:SetText(self:UnitName("target") or "")
    end)
    S:MJButton(diffusion, "Lettre individuelle", 160, 18, -72, function() self:SendFromPanel("letter") end)
    S:MJButton(diffusion, "Lettre de groupe", 150, 188, -72, function() self:SendFromPanel("group") end)
    S:MJButton(diffusion, "Quête débloquée", 150, 348, -72, function() self:SendFromPanel("unlock") end)
    S:MJButton(diffusion, "Transmission raid", 150, 508, -72, function() self:SendFromPanel("raid") end)
    panel.delivery = S:MJText(diffusion, "", 11, 18, -110, 734, "inkMuted")

    panel:SetScript("OnShow", function()
        if not self:RequireMJ() then panel:Hide(); return end
        self:RefreshLibrary(); self:RefreshDeliveryStatus()
    end)
    StaticPopupDialogs.OMEGA_JOURNAL_DELETE = {
        text = "Supprimer définitivement cette quête et la retirer du journal de tous ses destinataires ?",
        button1 = "Supprimer", button2 = "Annuler", timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
        OnAccept = function(_, id)
            local ok, err = self:DeleteQuest(id)
            self:PanelResult(ok, err)
            if ok then self:SetDraft(); self:RefreshLibrary(); self:RefreshDeliveryStatus() end
        end,
    }
    StaticPopupDialogs.OMEGA_QUEST_DELETE_TRAME = {
        text = "Supprimer la trame « %s » ? Ses chapitres sont supprimés et toutes ses quêtes redeviennent des quêtes libres, elles ne sont pas effacées.",
        button1 = "Supprimer", button2 = "Annuler", timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
        OnAccept = function(_, id)
            local ok, err = self:DeleteTrame(id)
            self:PanelResult(ok, err)
            if ok then
                if panel.selected and panel.selected.kind == "trame" and panel.selected.id == id then
                    panel.selected = nil
                    self:ShowQuestForm()
                    panel.questID:SetText(self:QuestStatusLabel())
                end
                self:RefreshLibrary()
            end
        end,
    }
    StaticPopupDialogs.OMEGA_QUEST_DELETE_CHAPITRE = {
        text = "Supprimer le chapitre « %s » ? Ses quêtes redeviennent des quêtes libres, elles ne sont pas effacées.",
        button1 = "Supprimer", button2 = "Annuler", timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
        OnAccept = function(_, id)
            local ok, err = self:DeleteChapitre(id)
            self:PanelResult(ok, err)
            if ok then
                if panel.selected and panel.selected.kind == "chapitre" and panel.selected.id == id then
                    panel.selected = nil
                    self:ShowQuestForm()
                    panel.questID:SetText(self:QuestStatusLabel())
                end
                self:RefreshLibrary()
            end
        end,
    }
    -- Initialise un brouillon vierge (pour que Save/ReadDraft aient toujours
    -- une table valide) sans rien afficher : le côté droit reste vide tant
    -- qu'aucune sélection ni création n'a eu lieu dans le sommaire.
    self:SetDraft()
    self:ShowEmpty()
end

function J:OpenMJPanel()
    local ok, err = self:RequireMJ()
    if not ok then self:PanelResult(false, err); return end
    self:CreateMJPanel()
    self.panel:Show(); self.panel:Raise()
end
