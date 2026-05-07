OS2 = OS2 or {}
OS2.DB = OS2.DB or {}

function OS2.DB.CreateEditPanel(deps)
    deps = deps or {}

    local UI = deps.UI or OS2.UI or {}
    local DBSchema = deps.DBSchema or {}
    local Trim = deps.Trim or function(text) return text or "" end
    local CreatePanelButton = deps.CreatePanelButton or UI.CreatePanelButton
    local CreateStyledEditBox = deps.CreateStyledEditBox or UI.CreateStyledEditBox
    local CreateStyledCheckbox = deps.CreateStyledCheckbox
    local ParseChannelList = deps.ParseChannelList
    local BuildChannelListFromChecks = deps.BuildChannelListFromChecks
    local NormalizePhraseList = deps.NormalizePhraseList
    local NormalizeDisablePhraseEntries = deps.NormalizeDisablePhraseEntries
    local NormalizeDisablePhraseEffect = deps.NormalizeDisablePhraseEffect
    local NormalizeAuraRules = deps.NormalizeAuraRules
    local ConditionNeedsPhrase = deps.ConditionNeedsPhrase
    local GetAuraConditionOptions = deps.GetAuraConditionOptions
    local GetAuraConditionLabel = deps.GetAuraConditionLabel
    local FormatDropdownItemLabel = deps.FormatDropdownItemLabel
    local ItemUsesTimedControls = deps.ItemUsesTimedControls
    local ItemUsesMultiplier = deps.ItemUsesMultiplier
    local ItemUsesDuration = deps.ItemUsesDuration
    local MenuItems = deps.MenuItems or {}

    local DISABLE_CHANNEL_OPTIONS = {
        { value = "RAID", label = "Raid" },
        { value = "GROUP", label = "Groupe" },
        { value = "RAID_WARNING", label = "Raid Warning" },
    }

    local EP_W = 320
    local EP_SIDE_W = 320
    local EP_SIDE_GAP = 10
    local EP_DESC_MIN_H = 90
    local EP_DESC_MAX_H = 240
    local EP_PHRASE_MAX_ROWS = 5

    local DISABLE_PHRASE_EFFECT_OPTIONS = (DBSchema.GetDisablePhraseEffects and DBSchema.GetDisablePhraseEffects()) or {
        { value = "PAUSE", label = "Pause uniquement" },
        { value = "PAUSE_FORCE_OFF", label = "Pause + forcer OFF" },
    }

    local epCurrentItemType = nil
    local epCurrentIsGeneric = false
    local epSaveCallback = nil
    local RefreshEditPanelLayout

    local editPanel = CreateFrame("Frame", nil, UIParent)
    editPanel:SetSize(EP_W, 280)
    editPanel:SetFrameStrata("TOOLTIP")
    editPanel:SetFrameLevel(95)
    editPanel:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    editPanel:Hide()

    local epBg = editPanel:CreateTexture(nil, "BACKGROUND")
    epBg:SetAllPoints()
    UI.ApplyWindowBackground(epBg, 0.98)
    OS2.RegisterWindowFrame(editPanel, epBg)

    local epTitleStr = editPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    epTitleStr:SetPoint("TOP", editPanel, "TOP", 0, -13)
    UI.ApplyTitle(epTitleStr)

    local epTitleSep = editPanel:CreateTexture(nil, "ARTWORK")
    UI.ApplySeparator(epTitleSep)
    epTitleSep:SetHeight(1)
    epTitleSep:SetPoint("TOPLEFT", editPanel, "TOPLEFT", 0, -36)
    epTitleSep:SetPoint("TOPRIGHT", editPanel, "TOPRIGHT", 0, -36)

    UI.CreateCloseButton(editPanel, function()
        editPanel:Hide()
    end)

    do
        local drag = CreateFrame("Frame", nil, editPanel)
        drag:SetPoint("TOPLEFT", editPanel, "TOPLEFT", 0, 0)
        drag:SetPoint("TOPRIGHT", editPanel, "TOPRIGHT", 0, 0)
        drag:SetHeight(36)
        OS2.MakeDraggable(editPanel, drag)
    end

    local epLblNom = editPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    epLblNom:SetText("Nom")
    UI.ApplyLabel(epLblNom)
    local epNomEB = CreateStyledEditBox(editPanel, EP_W - 28, 22)

    local epLblDesc = editPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    epLblDesc:SetText("Description")
    UI.ApplyLabel(epLblDesc)

    local epDescBox = CreateFrame("Frame", nil, editPanel)
    epDescBox:SetSize(EP_W - 28, EP_DESC_MIN_H)
    local epDescBg = epDescBox:CreateTexture(nil, "BACKGROUND")
    epDescBg:SetAllPoints()
    epDescBg:SetColorTexture(unpack(UI.colors.editBoxBg))
    local epDescBorder = epDescBox:CreateTexture(nil, "ARTWORK")
    epDescBorder:SetHeight(1)
    epDescBorder:SetPoint("BOTTOMLEFT", epDescBox, "BOTTOMLEFT", 2, 1)
    epDescBorder:SetPoint("BOTTOMRIGHT", epDescBox, "BOTTOMRIGHT", -2, 1)
    epDescBorder:SetColorTexture(unpack(UI.colors.editBoxAccent))

    local epDescEB = CreateFrame("EditBox", nil, epDescBox)
    epDescEB:SetPoint("TOPLEFT", epDescBox, "TOPLEFT", 6, -4)
    epDescEB:SetPoint("BOTTOMRIGHT", epDescBox, "BOTTOMRIGHT", -18, 4)
    epDescEB:SetFontObject("GameFontNormalSmall")
    UI.ApplyBodyText(epDescEB)
    epDescEB:SetAutoFocus(false)
    epDescEB:SetMultiLine(true)
    epDescEB:SetMaxLetters(512)
    epDescEB:SetJustifyH("LEFT")
    epDescEB:SetJustifyV("TOP")
    epDescEB:SetTextInsets(0, 0, 0, 0)
    epDescEB:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local function ClampDescriptionHeight(height)
        return math.max(EP_DESC_MIN_H, math.min(EP_DESC_MAX_H, math.floor((height or EP_DESC_MIN_H) + 0.5)))
    end

    local epInventoryCheck, epInventoryCheckLabel = CreateStyledCheckbox(editPanel, "Vérification inventaire ?")

    local epInventoryHelp = editPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    epInventoryHelp:SetJustifyH("LEFT")
    epInventoryHelp:SetJustifyV("TOP")
    UI.ApplySoftText(epInventoryHelp)
    epInventoryHelp:SetText("Si coché, l'objet nécessite un item précis dans l'inventaire pour fonctionner.")

    local epInventoryItemLabel = editPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    epInventoryItemLabel:SetText("ID de l'item requis")
    UI.ApplyLabel(epInventoryItemLabel)

    local epInventoryItemEB = CreateStyledEditBox(editPanel, EP_W - 28, 22)

    local function CreateConsumableState(parent)
        local state = {}
        state.check, state.label = CreateStyledCheckbox(parent, "Consommable ?")
        state.help = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        state.help:SetJustifyH("LEFT")
        state.help:SetJustifyV("TOP")
        UI.ApplySoftText(state.help)
        state.help:SetText("Si coché, l'item requis est consommé à chaque rechargement du timer.")
        return state
    end

    local epConsumable = CreateConsumableState(editPanel)

    local epLblVal = editPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    UI.ApplyLabel(epLblVal)
    epLblVal:SetTextColor(0.70, 0.65, 0.50, 1)
    local epValEB = CreateStyledEditBox(editPanel, EP_W - 28, 22)

    local epDisableCheck, epDisableCheckLabel = CreateStyledCheckbox(editPanel, "Désactivable")

    local epDisableHelp = editPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    epDisableHelp:SetJustifyH("LEFT")
    epDisableHelp:SetJustifyV("TOP")
    UI.ApplySoftText(epDisableHelp)
    epDisableHelp:SetText("Si coché, l'objet surveille des canaux et peut se désactiver automatiquement.")

    local epLblChannels = editPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    epLblChannels:SetText("Canaux de désactivation")
    UI.ApplyLabel(epLblChannels)

    local epChannelChecks = {}
    for _, option in ipairs(DISABLE_CHANNEL_OPTIONS) do
        local check, label = CreateStyledCheckbox(editPanel, option.label)
        epChannelChecks[#epChannelChecks + 1] = {
            value = option.value,
            check = check,
            label = label,
        }
    end

    local function CreatePhraseRows()
        local rows = {}
        for _ = 1, EP_PHRASE_MAX_ROWS do
            rows[#rows + 1] = CreateStyledEditBox(editPanel, EP_W - 28, 22)
        end
        return rows
    end

    local function GetDisablePhraseEffectLabel(value)
        local selected = NormalizeDisablePhraseEffect(value)
        for _, option in ipairs(DISABLE_PHRASE_EFFECT_OPTIONS) do
            if option.value == selected then
                return option.label
            end
        end
        return DISABLE_PHRASE_EFFECT_OPTIONS[1].label
    end

    local function CreateDisablePhraseRows()
        local rows = {}

        for _ = 1, EP_PHRASE_MAX_ROWS do
            local row = {
                text = CreateStyledEditBox(editPanel, EP_W - 168, 22),
                effect = "PAUSE",
            }

            row.dropdown = CreateFrame("Frame", nil, editPanel, "UIDropDownMenuTemplate")
            UIDropDownMenu_SetWidth(row.dropdown, 126)
            UI.StyleDropdown(row.dropdown, 14, 0, 26)
            UIDropDownMenu_Initialize(row.dropdown, function(_, level)
                for _, option in ipairs(DISABLE_PHRASE_EFFECT_OPTIONS) do
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = FormatDropdownItemLabel(option.label, option.value == row.effect)
                    info.value = option.value
                    info.notCheckable = true
                    info.func = function()
                        row.effect = option.value
                        UIDropDownMenu_SetSelectedValue(row.dropdown, option.value)
                        UIDropDownMenu_SetText(row.dropdown, option.label)
                    end
                    UIDropDownMenu_AddButton(info, level)
                end
            end)

            row.sep = editPanel:CreateTexture(nil, "ARTWORK")
            UI.ApplySeparator(row.sep, true)
            row.sep:SetHeight(1)
            row.sep:Hide()

            rows[#rows + 1] = row
        end

        return rows
    end

    local function CollectPhraseValues(rows, count)
        local phrases = {}
        for i = 1, math.max(0, count or 0) do
            local phrase = Trim(rows[i]:GetText() or "")
            if phrase ~= "" then
                phrases[#phrases + 1] = phrase
            end
        end
        return phrases
    end

    local function CollectDisablePhraseValues(rows, count)
        local phrases = {}
        for i = 1, math.max(0, count or 0) do
            local row = rows[i]
            local phrase = Trim(row.text:GetText() or "")
            if phrase ~= "" then
                phrases[#phrases + 1] = {
                    text = phrase,
                    effect = NormalizeDisablePhraseEffect(row.effect),
                }
            end
        end
        return phrases
    end

    local function CollectDisablePhraseTexts(rows, count)
        local phrases = {}
        for _, entry in ipairs(CollectDisablePhraseValues(rows, count)) do
            phrases[#phrases + 1] = entry.text
        end
        return phrases
    end

    local epDisablePhraseLabel = editPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    epDisablePhraseLabel:SetText("Phrases de désactivation")
    UI.ApplyLabel(epDisablePhraseLabel)
    local epDisablePhraseAddBtn = UI.CreateAddButton(editPanel)
    local epDisablePhraseRows = CreateDisablePhraseRows()
    local epDisablePhraseCount = 1

    local epEnablePhraseLabel = editPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    epEnablePhraseLabel:SetText("Phrases d'activation")
    UI.ApplyLabel(epEnablePhraseLabel)
    local epEnablePhraseAddBtn = UI.CreateAddButton(editPanel)
    local epEnablePhraseRows = CreatePhraseRows()
    local epEnablePhraseSeps = {}
    for _ = 1, EP_PHRASE_MAX_ROWS do
        local sep = editPanel:CreateTexture(nil, "ARTWORK")
        UI.ApplySeparator(sep, true)
        sep:SetHeight(1)
        sep:Hide()
        epEnablePhraseSeps[#epEnablePhraseSeps + 1] = sep
    end
    local epEnablePhraseCount = 1

    local function CreateAuraEditorState()
        local aura = {
            applyRows = {},
            removeRows = {},
            applyCount = 1,
            removeCount = 1,
        }

        aura.check, aura.checkLabel = CreateStyledCheckbox(editPanel, "Aura ?")
        aura.help = editPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        aura.help:SetJustifyH("LEFT")
        aura.help:SetJustifyV("TOP")
        UI.ApplySoftText(aura.help)
        aura.help:SetText("Si coché, vous pouvez définir des règles d'application et de retrait d'aura exécutées via des commandes raid.")

        aura.applyLabel = editPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        aura.applyLabel:SetText("Conditions d'application")
        UI.ApplyLabel(aura.applyLabel)
        aura.applyAddBtn = UI.CreateAddButton(editPanel)

        aura.removeLabel = editPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        aura.removeLabel:SetText("Conditions de retrait")
        UI.ApplyLabel(aura.removeLabel)
        aura.removeAddBtn = UI.CreateAddButton(editPanel)

        function aura:GetAvailablePhrases(condition)
            if condition == "DISABLE_PHRASE" then
                return CollectDisablePhraseTexts(epDisablePhraseRows, epDisablePhraseCount)
            end
            if condition == "ENABLE_PHRASE" then
                return CollectPhraseValues(epEnablePhraseRows, epEnablePhraseCount)
            end
            return {}
        end

        function aura:RefreshPhraseDropdown(row)
            local phrases = self:GetAvailablePhrases(row.condition)
            if ConditionNeedsPhrase(row.condition) and row.phrase == "" and #phrases > 0 then
                row.phrase = phrases[1]
            end

            UIDropDownMenu_Initialize(row.phraseDropdown, function(_, level)
                for _, phrase in ipairs(phrases) do
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = FormatDropdownItemLabel(phrase, phrase == row.phrase)
                    info.value = phrase
                    info.notCheckable = true
                    info.func = function()
                        row.phrase = phrase
                        UIDropDownMenu_SetSelectedValue(row.phraseDropdown, phrase)
                        UIDropDownMenu_SetText(row.phraseDropdown, phrase)
                    end
                    UIDropDownMenu_AddButton(info, level)
                end
            end)

            UIDropDownMenu_SetSelectedValue(row.phraseDropdown, row.phrase)
            UIDropDownMenu_SetText(row.phraseDropdown, row.phrase ~= "" and row.phrase or "Choisir une phrase")
        end

        local function CreateRows(target)
            for _ = 1, 5 do
                local row = {
                    condition = "ACTIVATE",
                    phrase = "",
                }

                row.conditionDropdown = CreateFrame("Frame", nil, editPanel, "UIDropDownMenuTemplate")
                UIDropDownMenu_SetWidth(row.conditionDropdown, 146)
                UI.StyleDropdown(row.conditionDropdown)
                UIDropDownMenu_Initialize(row.conditionDropdown, function(_, level)
                    for _, option in ipairs(GetAuraConditionOptions(epCurrentItemType)) do
                        local info = UIDropDownMenu_CreateInfo()
                        info.text = FormatDropdownItemLabel(option.label, option.value == row.condition)
                        info.value = option.value
                        info.notCheckable = true
                        info.func = function()
                            row.condition = option.value
                            if not ConditionNeedsPhrase(row.condition) then
                                row.phrase = ""
                            end
                            UIDropDownMenu_SetSelectedValue(row.conditionDropdown, option.value)
                            UIDropDownMenu_SetText(row.conditionDropdown, option.label)
                            aura:RefreshPhraseDropdown(row)
                            RefreshEditPanelLayout()
                        end
                        UIDropDownMenu_AddButton(info, level)
                    end
                end)

                row.phraseDropdown = CreateFrame("Frame", nil, editPanel, "UIDropDownMenuTemplate")
                UIDropDownMenu_SetWidth(row.phraseDropdown, 146)
                UI.StyleDropdown(row.phraseDropdown)

                row.command = CreateStyledEditBox(editPanel, EP_W - 28, 22)
                row.sep = editPanel:CreateTexture(nil, "ARTWORK")
                UI.ApplySeparator(row.sep, true)
                row.sep:SetHeight(1)
                row.sep:Hide()

                target[#target + 1] = row
            end
        end

        CreateRows(aura.applyRows)
        CreateRows(aura.removeRows)

        function aura:CollectRules(rows, count)
            local rules = {}
            for i = 1, math.max(0, count or 0) do
                local row = rows[i]
                local command = Trim(row.command:GetText() or "")
                local condition = Trim(row.condition or "")
                local phrase = Trim(row.phrase or "")
                if condition ~= "" or command ~= "" then
                    if condition ~= "" and command ~= "" then
                        rules[#rules + 1] = {
                            condition = condition,
                            command = command,
                            phrase = ConditionNeedsPhrase(condition) and phrase or "",
                        }
                    else
                        return nil
                    end
                end
            end
            return rules
        end

        aura.maxRows = 5
        return aura
    end

    local epAura = CreateAuraEditorState()

    local function SetFrameTopLeft(frame, y)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", editPanel, "TOPLEFT", 14, -y)
    end

    local function SetFrameTopFill(frame, y)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", editPanel, "TOPLEFT", 14, -y)
        frame:SetPoint("TOPRIGHT", editPanel, "TOPRIGHT", -14, -y)
    end

    local function CreateEditDetailState()
        local state = {}

        local function CreateSidePanel(titleText)
            local panel = CreateFrame("Frame", nil, UIParent)
            panel:SetSize(EP_SIDE_W, 140)
            panel:SetFrameStrata("TOOLTIP")
            panel:SetFrameLevel(editPanel:GetFrameLevel())
            panel:Hide()

            local bg = panel:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            UI.ApplyWindowBackground(bg, 0.98)
            if OS2.RegisterWindowFrame then
                OS2.RegisterWindowFrame(panel, bg)
            end

            local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            title:SetPoint("TOP", panel, "TOP", 0, -13)
            title:SetText(titleText or "")
            UI.ApplyTitle(title)

            local sep = panel:CreateTexture(nil, "ARTWORK")
            UI.ApplySeparator(sep)
            sep:SetHeight(1)
            sep:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -36)
            sep:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -36)

            return panel
        end

        local function SetPanelFrameTopLeft(panel, frame, y)
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -y)
        end

        state.disablePanel = CreateSidePanel("Désactivation")
        state.auraPanel = CreateSidePanel("Aura")
        state.auraSectionSep = state.auraPanel:CreateTexture(nil, "ARTWORK")
        UI.ApplySeparator(state.auraSectionSep)
        state.auraSectionSep:SetHeight(1)
        state.auraSectionSep:Hide()
        state.disableSectionSep = state.disablePanel:CreateTexture(nil, "ARTWORK")
        UI.ApplySeparator(state.disableSectionSep)
        state.disableSectionSep:SetHeight(2)
        state.disableSectionSep:Hide()

        function state.Hide()
            state.disablePanel:Hide()
            state.disablePanel.os2TopOffset = nil
            state.auraPanel:Hide()
        end

        function state.RefreshDisable(showPanel)
            epLblChannels:SetShown(showPanel)
            epDisablePhraseLabel:SetShown(showPanel)
            epDisablePhraseAddBtn:SetShown(showPanel)
            epEnablePhraseLabel:SetShown(showPanel)
            epEnablePhraseAddBtn:SetShown(showPanel)

            for _, entry in ipairs(epChannelChecks) do
                entry.check:SetShown(showPanel)
                entry.label:SetShown(showPanel)
            end

            for index, row in ipairs(epDisablePhraseRows) do
                local isShown = showPanel and index <= epDisablePhraseCount
                row.text:SetShown(isShown)
                row.dropdown:SetShown(isShown)
                row.sep:SetShown(false)
            end

            for index, row in ipairs(epEnablePhraseRows) do
                row:SetShown(showPanel and index <= epEnablePhraseCount)
                epEnablePhraseSeps[index]:SetShown(false)
            end

            if not showPanel then
                state.disableSectionSep:Hide()
                state.disablePanel:Hide()
                state.disablePanel.os2TopOffset = nil
                return
            end

            local y = 50
            SetPanelFrameTopLeft(state.disablePanel, epLblChannels, y)
            y = y + 18

            for _, entry in ipairs(epChannelChecks) do
                entry.check:ClearAllPoints()
                entry.check:SetPoint("TOPLEFT", state.disablePanel, "TOPLEFT", 14, -y)
                entry.label:ClearAllPoints()
                entry.label:SetPoint("LEFT", entry.check, "RIGHT", 8, 0)
                y = y + 22
            end

            y = y + 4
            SetPanelFrameTopLeft(state.disablePanel, epDisablePhraseLabel, y)
            epDisablePhraseAddBtn:ClearAllPoints()
            epDisablePhraseAddBtn:SetPoint("LEFT", epDisablePhraseLabel, "RIGHT", 10, 0)
            y = y + 18

            for i = 1, epDisablePhraseCount do
                local row = epDisablePhraseRows[i]
                row.text:ClearAllPoints()
                row.text:SetPoint("TOPLEFT", state.disablePanel, "TOPLEFT", 14, -y)
                row.text:SetWidth(EP_W - 28)
                row.dropdown:ClearAllPoints()
                row.dropdown:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", -16, -4)
                UIDropDownMenu_SetSelectedValue(row.dropdown, row.effect)
                UIDropDownMenu_SetText(row.dropdown, GetDisablePhraseEffectLabel(row.effect))
                y = y + 56

                if i < epDisablePhraseCount then
                    row.sep:ClearAllPoints()
                    row.sep:SetPoint("TOPLEFT", state.disablePanel, "TOPLEFT", 18, -y)
                    row.sep:SetPoint("TOPRIGHT", state.disablePanel, "TOPRIGHT", -18, -y)
                    row.sep:Show()
                    y = y + 10
                end
            end

            y = y + 2
            state.disableSectionSep:ClearAllPoints()
            state.disableSectionSep:SetPoint("TOPLEFT", state.disablePanel, "TOPLEFT", 14, -y)
            state.disableSectionSep:SetPoint("TOPRIGHT", state.disablePanel, "TOPRIGHT", -14, -y)
            state.disableSectionSep:Show()
            y = y + 18
            SetPanelFrameTopLeft(state.disablePanel, epEnablePhraseLabel, y)
            epEnablePhraseAddBtn:ClearAllPoints()
            epEnablePhraseAddBtn:SetPoint("LEFT", epEnablePhraseLabel, "RIGHT", 10, 0)
            y = y + 18

            for i = 1, epEnablePhraseCount do
                SetPanelFrameTopLeft(state.disablePanel, epEnablePhraseRows[i], y)
                y = y + 28

                if i < epEnablePhraseCount then
                    local sep = epEnablePhraseSeps[i]
                    sep:ClearAllPoints()
                    sep:SetPoint("TOPLEFT", state.disablePanel, "TOPLEFT", 18, -y)
                    sep:SetPoint("TOPRIGHT", state.disablePanel, "TOPRIGHT", -18, -y)
                    sep:Show()
                    y = y + 10
                end
            end

            state.disablePanel:SetHeight(math.max(170, y + 18))
            state.disablePanel:ClearAllPoints()
            state.disablePanel:SetPoint("TOPLEFT", editPanel, "TOPRIGHT", EP_SIDE_GAP, 0)
            state.disablePanel.os2TopOffset = 0
            state.disablePanel:Show()
        end

        function state.RefreshAura(showPanel)
            epAura.applyLabel:SetShown(showPanel)
            epAura.applyAddBtn:SetShown(showPanel)
            epAura.removeLabel:SetShown(showPanel)
            epAura.removeAddBtn:SetShown(showPanel)

            for _, row in ipairs(epAura.applyRows) do
                row.conditionDropdown:SetShown(false)
                row.phraseDropdown:SetShown(false)
                row.command:SetShown(false)
                row.sep:SetShown(false)
            end
            for _, row in ipairs(epAura.removeRows) do
                row.conditionDropdown:SetShown(false)
                row.phraseDropdown:SetShown(false)
                row.command:SetShown(false)
                row.sep:SetShown(false)
            end

            if not showPanel then
                state.auraSectionSep:Hide()
                state.auraPanel:Hide()
                return
            end

            local topOffset = 0
            if state.disablePanel:IsShown() and state.disablePanel.os2TopOffset then
                topOffset = math.max(topOffset, state.disablePanel.os2TopOffset + state.disablePanel:GetHeight() + 8)
            end

            local y = 50
            SetPanelFrameTopLeft(state.auraPanel, epAura.applyLabel, y)
            epAura.applyAddBtn:ClearAllPoints()
            epAura.applyAddBtn:SetPoint("LEFT", epAura.applyLabel, "RIGHT", 10, 0)
            y = y + 20

            for i = 1, epAura.applyCount do
                local row = epAura.applyRows[i]
                row.conditionDropdown:ClearAllPoints()
                row.conditionDropdown:SetPoint("TOPLEFT", state.auraPanel, "TOPLEFT", 2, -y)
                UIDropDownMenu_SetText(row.conditionDropdown, GetAuraConditionLabel(epCurrentItemType, row.condition))
                row.conditionDropdown:Show()
                y = y + 32

                row.command:ClearAllPoints()
                row.command:SetPoint("TOPLEFT", state.auraPanel, "TOPLEFT", 14, -y)
                row.command:SetPoint("TOPRIGHT", state.auraPanel, "TOPRIGHT", -14, -y)
                row.command:Show()
                y = y + 28

                if ConditionNeedsPhrase(row.condition) then
                    epAura:RefreshPhraseDropdown(row)
                    row.phraseDropdown:ClearAllPoints()
                    row.phraseDropdown:SetPoint("TOPLEFT", state.auraPanel, "TOPLEFT", 2, -y)
                    row.phraseDropdown:Show()
                    y = y + 32
                end

                if i < epAura.applyCount then
                    row.sep:ClearAllPoints()
                    row.sep:SetPoint("TOPLEFT", state.auraPanel, "TOPLEFT", 18, -y)
                    row.sep:SetPoint("TOPRIGHT", state.auraPanel, "TOPRIGHT", -18, -y)
                    row.sep:Show()
                    y = y + 8
                end

                y = y + 6
            end

            state.auraSectionSep:ClearAllPoints()
            state.auraSectionSep:SetPoint("TOPLEFT", state.auraPanel, "TOPLEFT", 14, -y)
            state.auraSectionSep:SetPoint("TOPRIGHT", state.auraPanel, "TOPRIGHT", -14, -y)
            state.auraSectionSep:Show()
            y = y + 16

            SetPanelFrameTopLeft(state.auraPanel, epAura.removeLabel, y)
            epAura.removeAddBtn:ClearAllPoints()
            epAura.removeAddBtn:SetPoint("LEFT", epAura.removeLabel, "RIGHT", 10, 0)
            y = y + 20

            for i = 1, epAura.removeCount do
                local row = epAura.removeRows[i]
                row.conditionDropdown:ClearAllPoints()
                row.conditionDropdown:SetPoint("TOPLEFT", state.auraPanel, "TOPLEFT", 2, -y)
                UIDropDownMenu_SetText(row.conditionDropdown, GetAuraConditionLabel(epCurrentItemType, row.condition))
                row.conditionDropdown:Show()
                y = y + 32

                row.command:ClearAllPoints()
                row.command:SetPoint("TOPLEFT", state.auraPanel, "TOPLEFT", 14, -y)
                row.command:SetPoint("TOPRIGHT", state.auraPanel, "TOPRIGHT", -14, -y)
                row.command:Show()
                y = y + 28

                if ConditionNeedsPhrase(row.condition) then
                    epAura:RefreshPhraseDropdown(row)
                    row.phraseDropdown:ClearAllPoints()
                    row.phraseDropdown:SetPoint("TOPLEFT", state.auraPanel, "TOPLEFT", 2, -y)
                    row.phraseDropdown:Show()
                    y = y + 32
                end

                if i < epAura.removeCount then
                    row.sep:ClearAllPoints()
                    row.sep:SetPoint("TOPLEFT", state.auraPanel, "TOPLEFT", 18, -y)
                    row.sep:SetPoint("TOPRIGHT", state.auraPanel, "TOPRIGHT", -18, -y)
                    row.sep:Show()
                    y = y + 8
                end

                y = y + 6
            end

            state.auraPanel:SetHeight(math.max(170, y + 18))
            state.auraPanel:ClearAllPoints()
            state.auraPanel:SetPoint("TOPLEFT", editPanel, "TOPRIGHT", EP_SIDE_GAP, -topOffset)
            state.auraPanel:Show()
        end

        return state
    end

    local editDetailState = CreateEditDetailState()
    editPanel:HookScript("OnHide", function()
        editDetailState.Hide()
    end)

    RefreshEditPanelLayout = function()
        local y = 50

        SetFrameTopLeft(epLblNom, y)
        y = y + 18
        SetFrameTopLeft(epNomEB, y)
        y = y + 34

        SetFrameTopLeft(epLblDesc, y)
        y = y + 18
        SetFrameTopLeft(epDescBox, y)
        y = y + epDescBox:GetHeight() + 12

        epInventoryCheck:ClearAllPoints()
        epInventoryCheck:SetPoint("TOPLEFT", editPanel, "TOPLEFT", 14, -y)
        epInventoryCheckLabel:ClearAllPoints()
        epInventoryCheckLabel:SetPoint("LEFT", epInventoryCheck, "RIGHT", 8, 0)
        y = y + 22

        SetFrameTopFill(epInventoryHelp, y)
        y = y + 28

        local showInventoryItem = epInventoryCheck:GetChecked()
        epInventoryItemLabel:SetShown(showInventoryItem)
        epInventoryItemEB:SetShown(showInventoryItem)
        epConsumable.check:SetShown(showInventoryItem and ItemUsesTimedControls(epCurrentItemType))
        epConsumable.label:SetShown(showInventoryItem and ItemUsesTimedControls(epCurrentItemType))
        epConsumable.help:SetShown(showInventoryItem and ItemUsesTimedControls(epCurrentItemType))

        if showInventoryItem then
            SetFrameTopLeft(epInventoryItemLabel, y)
            y = y + 18
            SetFrameTopLeft(epInventoryItemEB, y)
            y = y + 34
            if ItemUsesTimedControls(epCurrentItemType) then
                epConsumable.check:ClearAllPoints()
                epConsumable.check:SetPoint("TOPLEFT", editPanel, "TOPLEFT", 14, -y)
                epConsumable.label:ClearAllPoints()
                epConsumable.label:SetPoint("LEFT", epConsumable.check, "RIGHT", 8, 0)
                y = y + 22

                SetFrameTopFill(epConsumable.help, y)
                y = y + 28
            end
        end

        epLblVal:SetShown(ItemUsesTimedControls(epCurrentItemType))
        epValEB:SetShown(ItemUsesTimedControls(epCurrentItemType))
        epDisableCheck:SetShown(ItemUsesTimedControls(epCurrentItemType))
        epDisableCheckLabel:SetShown(ItemUsesTimedControls(epCurrentItemType))
        epDisableHelp:SetShown(ItemUsesTimedControls(epCurrentItemType))
        epAura.help:SetShown(true)

        if ItemUsesTimedControls(epCurrentItemType) then
            SetFrameTopLeft(epLblVal, y)
            y = y + 18
            SetFrameTopLeft(epValEB, y)
            y = y + 38

            epDisableCheck:ClearAllPoints()
            epDisableCheck:SetPoint("TOPLEFT", editPanel, "TOPLEFT", 14, -y)
            epDisableCheckLabel:ClearAllPoints()
            epDisableCheckLabel:SetPoint("LEFT", epDisableCheck, "RIGHT", 8, 0)
            y = y + 22

            SetFrameTopFill(epDisableHelp, y)
            y = y + 28

            epAura.check:ClearAllPoints()
            epAura.check:SetPoint("TOPLEFT", editPanel, "TOPLEFT", 14, -y)
            epAura.checkLabel:ClearAllPoints()
            epAura.checkLabel:SetPoint("LEFT", epAura.check, "RIGHT", 8, 0)
            y = y + 22

            SetFrameTopFill(epAura.help, y)
            y = y + 28

            editPanel:SetHeight(math.max(280, y + 58))
            editDetailState.RefreshDisable(epDisableCheck:GetChecked())
            editDetailState.RefreshAura(epAura.check:GetChecked())
            return
        end

        epAura.check:ClearAllPoints()
        epAura.check:SetPoint("TOPLEFT", editPanel, "TOPLEFT", 14, -y)
        epAura.checkLabel:ClearAllPoints()
        epAura.checkLabel:SetPoint("LEFT", epAura.check, "RIGHT", 8, 0)
        y = y + 22

        epDisableHelp:SetShown(false)
        SetFrameTopFill(epAura.help, y)
        y = y + 28

        editPanel:SetHeight(math.max(280, y + 58))
        editDetailState.RefreshDisable(false)
        editDetailState.RefreshAura(epAura.check:GetChecked())
    end

    epDisableCheck.OnValueChanged = function()
        RefreshEditPanelLayout()
    end
    epInventoryCheck.OnValueChanged = function()
        RefreshEditPanelLayout()
    end
    epConsumable.check.OnValueChanged = function()
        RefreshEditPanelLayout()
    end
    epAura.check.OnValueChanged = function()
        RefreshEditPanelLayout()
    end

    epDisablePhraseAddBtn:SetScript("OnClick", function()
        epDisablePhraseCount = math.min(EP_PHRASE_MAX_ROWS, epDisablePhraseCount + 1)
        RefreshEditPanelLayout()
    end)
    epEnablePhraseAddBtn:SetScript("OnClick", function()
        epEnablePhraseCount = math.min(EP_PHRASE_MAX_ROWS, epEnablePhraseCount + 1)
        RefreshEditPanelLayout()
    end)
    epAura.applyAddBtn:SetScript("OnClick", function()
        epAura.applyCount = math.min(epAura.maxRows or 5, epAura.applyCount + 1)
        RefreshEditPanelLayout()
    end)
    epAura.removeAddBtn:SetScript("OnClick", function()
        epAura.removeCount = math.min(epAura.maxRows or 5, epAura.removeCount + 1)
        RefreshEditPanelLayout()
    end)

    local epBotSep = editPanel:CreateTexture(nil, "ARTWORK")
    UI.ApplySeparator(epBotSep)
    epBotSep:SetHeight(1)
    epBotSep:SetPoint("BOTTOMLEFT", editPanel, "BOTTOMLEFT", 0, 14 + 22 + 6)
    epBotSep:SetPoint("BOTTOMRIGHT", editPanel, "BOTTOMRIGHT", 0, 14 + 22 + 6)

    local half = math.floor((EP_W - 28 - 6) / 2)
    local epValider = CreatePanelButton(editPanel, half, 22, "Valider")
    epValider:SetPoint("BOTTOMLEFT", editPanel, "BOTTOMLEFT", 14, 14)
    local epAnnuler = CreatePanelButton(editPanel, half, 22, "Annuler")
    epAnnuler:SetPoint("BOTTOMRIGHT", editPanel, "BOTTOMRIGHT", -14, 14)
    epAnnuler:SetScript("OnClick", function()
        editPanel:Hide()
    end)

    epValider:SetScript("OnClick", function()
        if epSaveCallback then
            epSaveCallback()
        end
    end)

    local function OpenEditPanel(mode, item, itemType, onSave)
        epCurrentItemType = itemType
        epCurrentIsGeneric = not ItemUsesTimedControls(itemType)

        local catLabel = itemType
        for _, menuItem in ipairs(MenuItems) do
            if menuItem.key == itemType then
                catLabel = menuItem.dbLabel or menuItem.label
                break
            end
        end

        if mode == "create" then
            local createTitle = DBSchema.GetCreateTitle and DBSchema.GetCreateTitle(itemType)
            epTitleStr:SetText(createTitle or ("Nouveau : " .. catLabel))
        else
            local editTitle = DBSchema.GetEditTitle and DBSchema.GetEditTitle(itemType)
            epTitleStr:SetText(editTitle or ("Modifier : " .. catLabel))
        end

        epNomEB:SetText(item and item.label or "")
        epDescEB:SetText((item and item.desc) or "")
        epDescBox:SetHeight(EP_DESC_MIN_H)
        epInventoryCheck:SetChecked((item and item.inventoryCheck == true) or ((item and (item.inventoryItemId or item.itemId)) and true or false))
        epInventoryItemEB:SetText(item and tostring(item.inventoryItemId or item.itemId or "") or "")
        epConsumable.check:SetChecked(item and item.consumable == true or false)
        epDisableCheck:SetChecked(item and item.disableEnabled == true or false)
        epAura.check:SetChecked(item and item.auraEnabled == true or false)

        local selectedChannels = ParseChannelList(item and item.disableChannels or "")
        for _, entry in ipairs(epChannelChecks) do
            entry.check:SetChecked(selectedChannels[entry.value] == true)
        end

        local disablePhrases = NormalizeDisablePhraseEntries((item and (item.disablePhrases or item.disablePhrase)) or "")
        local enablePhrases = NormalizePhraseList((item and (item.enablePhrases or item.enablePhrase)) or "")
        local auraApplyRules = NormalizeAuraRules(item and item.auraApplyRules or {})
        local auraRemoveRules = NormalizeAuraRules(item and item.auraRemoveRules or {})

        epDisablePhraseCount = math.max(1, math.min(EP_PHRASE_MAX_ROWS, #disablePhrases > 0 and #disablePhrases or 1))
        epEnablePhraseCount = math.max(1, math.min(EP_PHRASE_MAX_ROWS, #enablePhrases > 0 and #enablePhrases or 1))
        epAura.applyCount = math.max(1, math.min(epAura.maxRows or 5, #auraApplyRules > 0 and #auraApplyRules or 1))
        epAura.removeCount = math.max(1, math.min(epAura.maxRows or 5, #auraRemoveRules > 0 and #auraRemoveRules or 1))

        for i, row in ipairs(epDisablePhraseRows) do
            local entry = disablePhrases[i] or {}
            row.text:SetText(entry.text or "")
            row.effect = NormalizeDisablePhraseEffect(entry.effect)
            UIDropDownMenu_SetSelectedValue(row.dropdown, row.effect)
            UIDropDownMenu_SetText(row.dropdown, GetDisablePhraseEffectLabel(row.effect))
        end

        for i, row in ipairs(epEnablePhraseRows) do
            row:SetText(enablePhrases[i] or "")
        end

        for i, row in ipairs(epAura.applyRows) do
            local rule = auraApplyRules[i] or {}
            row.condition = rule.condition or "ACTIVATE"
            row.phrase = rule.phrase or ""
            row.command:SetText(rule.command or "")
        end

        for i, row in ipairs(epAura.removeRows) do
            local rule = auraRemoveRules[i] or {}
            row.condition = rule.condition or "DEACTIVATE"
            row.phrase = rule.phrase or ""
            row.command:SetText(rule.command or "")
        end

        if ItemUsesMultiplier(itemType) then
            epLblVal:SetText((DBSchema.GetValueLabel and DBSchema.GetValueLabel(itemType)) or "Multiplicateur")
            epValEB:SetText(item and tostring(item.mult) or "1")
        elseif ItemUsesDuration(itemType) then
            epLblVal:SetText((DBSchema.GetValueLabel and DBSchema.GetValueLabel(itemType)) or "Durée d'activation (minutes)")
            epValEB:SetText(item and tostring(item.time) or "60")
        end

        RefreshEditPanelLayout()

        epSaveCallback = function()
            local newLabel = Trim(epNomEB:GetText())
            local newValue = tonumber(epValEB:GetText())
            local newDesc = Trim(epDescEB:GetText() or "")
            local inventoryCheck = epInventoryCheck:GetChecked()
            local inventoryItemId = tonumber(Trim(epInventoryItemEB:GetText() or ""))
            local consumable = epConsumable.check:GetChecked()
            local disableEnabled = epDisableCheck:GetChecked()
            local auraEnabled = epAura.check:GetChecked()
            local disableChannels = BuildChannelListFromChecks(epChannelChecks)
            local collectedDisablePhrases = CollectDisablePhraseValues(epDisablePhraseRows, epDisablePhraseCount)
            local collectedEnablePhrases = CollectPhraseValues(epEnablePhraseRows, epEnablePhraseCount)
            local auraApplyRules = {}
            local auraRemoveRules = {}

            if newLabel == "" then
                if OS2.Notify then
                    OS2.Notify("Le nom de l'objet est obligatoire.", 1, 0.85, 0.35)
                end
                return
            end

            if inventoryCheck and (not inventoryItemId or inventoryItemId <= 0) then
                if OS2.Notify then
                    OS2.Notify("Renseignez un ID d'item valide pour la vérification d'inventaire.", 1, 0.85, 0.35)
                end
                return
            end

            if consumable and not inventoryCheck then
                if OS2.Notify then
                    OS2.Notify("Activez la vérification d'inventaire avant de rendre cet item consommable.", 1, 0.85, 0.35)
                end
                return
            end

            if ItemUsesTimedControls(itemType) then
                if not newValue or newValue <= 0 then
                    if OS2.Notify then
                        OS2.Notify("La valeur numérique doit être supérieure à zéro.", 1, 0.85, 0.35)
                    end
                    return
                end

                if disableEnabled and disableChannels == "" then
                    if OS2.Notify then
                        OS2.Notify("Renseignez au moins un canal à lire.", 1, 0.85, 0.35)
                    end
                    return
                end

                if disableEnabled and #collectedDisablePhrases == 0 then
                    if OS2.Notify then
                        OS2.Notify("Renseignez au moins une phrase de désactivation.", 1, 0.85, 0.35)
                    end
                    return
                end

                if disableEnabled and #collectedEnablePhrases == 0 then
                    if OS2.Notify then
                        OS2.Notify("Renseignez au moins une phrase d'activation.", 1, 0.85, 0.35)
                    end
                    return
                end
            end

            if auraEnabled then
                auraApplyRules = epAura:CollectRules(epAura.applyRows, epAura.applyCount)
                auraRemoveRules = epAura:CollectRules(epAura.removeRows, epAura.removeCount)

                if auraApplyRules == nil or auraRemoveRules == nil then
                    if OS2.Notify then
                        OS2.Notify("Chaque règle d'aura doit avoir une condition et une commande raid.", 1, 0.85, 0.35)
                    end
                    return
                end

                if #auraApplyRules == 0 then
                    if OS2.Notify then
                        OS2.Notify("Renseignez au moins une condition d'application d'aura.", 1, 0.85, 0.35)
                    end
                    return
                end
                if #auraRemoveRules == 0 then
                    if OS2.Notify then
                        OS2.Notify("Renseignez au moins une condition de retrait d'aura.", 1, 0.85, 0.35)
                    end
                    return
                end

                for _, rule in ipairs(auraApplyRules) do
                    if ConditionNeedsPhrase(rule.condition) and rule.phrase == "" then
                        if OS2.Notify then
                            OS2.Notify("Choisissez une phrase pour chaque règle d'aura liée aux phrases.", 1, 0.85, 0.35)
                        end
                        return
                    end
                end

                for _, rule in ipairs(auraRemoveRules) do
                    if ConditionNeedsPhrase(rule.condition) and rule.phrase == "" then
                        if OS2.Notify then
                            OS2.Notify("Choisissez une phrase pour chaque règle d'aura liée aux phrases.", 1, 0.85, 0.35)
                        end
                        return
                    end
                end
            end

            local payload = {
                label = newLabel,
                desc = newDesc,
                inventoryCheck = inventoryCheck,
                inventoryItemId = inventoryCheck and math.max(1, math.floor(inventoryItemId + 0.5)) or nil,
                itemId = inventoryCheck and math.max(1, math.floor(inventoryItemId + 0.5)) or nil,
                consumable = consumable and true or false,
                auraEnabled = auraEnabled,
                auraApplyRules = auraEnabled and auraApplyRules or {},
                auraRemoveRules = auraEnabled and auraRemoveRules or {},
            }

            if ItemUsesTimedControls(itemType) then
                payload.disableEnabled = disableEnabled
                payload.disableChannels = disableChannels
                payload.disablePhrases = collectedDisablePhrases
                payload.enablePhrases = collectedEnablePhrases
                payload.disablePhrase = (collectedDisablePhrases[1] and collectedDisablePhrases[1].text) or ""
                payload.enablePhrase = collectedEnablePhrases[1] or ""
                if ItemUsesMultiplier(itemType) then
                    payload.mult = math.max(1, math.floor(newValue + 0.5))
                else
                    payload.time = math.max(1, math.floor(newValue + 0.5))
                end
            end

            onSave(payload)
            editPanel:Hide()
        end

        if not editPanel:IsVisible() then
            editPanel:ClearAllPoints()
            editPanel:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
        end

        editPanel:Show()
        editPanel:Raise()
    end

    return {
        panel = editPanel,
        OpenEditPanel = OpenEditPanel,
    }
end
