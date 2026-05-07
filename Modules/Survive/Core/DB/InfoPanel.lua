OS2 = OS2 or {}
OS2.DB = OS2.DB or {}

function OS2.DB.CreateInfoPanel(deps)
    deps = deps or {}

    local UI = deps.UI or OS2.UI or {}
    local CreatePanelButton = deps.CreatePanelButton or UI.CreatePanelButton
    local AddItemToDatabase = deps.AddItemToDatabase
    local Trim = deps.Trim or function(text) return text or "" end
    local GetCategoryLabel = deps.GetCategoryLabel
    local MenuItems = deps.MenuItems or {}

    local IP_W = 336

    local itemInfoPanel = CreateFrame("Frame", nil, UIParent)
    itemInfoPanel:SetSize(IP_W, 10)
    itemInfoPanel:SetFrameStrata("TOOLTIP")
    itemInfoPanel:SetFrameLevel(90)
    itemInfoPanel:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    itemInfoPanel:Hide()

    local ipBg = itemInfoPanel:CreateTexture(nil, "BACKGROUND")
    ipBg:SetAllPoints()
    UI.ApplyWindowBackground(ipBg, 0.98)
    OS2.RegisterWindowFrame(itemInfoPanel, ipBg)

    local ipTitleStr = itemInfoPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ipTitleStr:SetPoint("TOP", itemInfoPanel, "TOP", 0, -13)
    ipTitleStr:SetText("Informations")
    UI.ApplyTitle(ipTitleStr)

    local ipTitleSep = itemInfoPanel:CreateTexture(nil, "ARTWORK")
    UI.ApplySeparator(ipTitleSep)
    ipTitleSep:SetHeight(1)
    ipTitleSep:SetPoint("TOPLEFT", itemInfoPanel, "TOPLEFT", 0, -36)
    ipTitleSep:SetPoint("TOPRIGHT", itemInfoPanel, "TOPRIGHT", 0, -36)

    UI.CreateCloseButton(itemInfoPanel, function()
        itemInfoPanel:Hide()
    end)

    do
        local drag = CreateFrame("Frame", nil, itemInfoPanel)
        drag:SetPoint("TOPLEFT", itemInfoPanel, "TOPLEFT", 0, 0)
        drag:SetPoint("TOPRIGHT", itemInfoPanel, "TOPRIGHT", 0, 0)
        drag:SetHeight(36)
        OS2.MakeDraggable(itemInfoPanel, drag)
    end

    local ipNameStr = itemInfoPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ipNameStr:SetPoint("TOPLEFT", itemInfoPanel, "TOPLEFT", 16, -52)
    ipNameStr:SetPoint("TOPRIGHT", itemInfoPanel, "TOPRIGHT", -124, -52)
    ipNameStr:SetJustifyH("LEFT")
    ipNameStr:SetJustifyV("TOP")
    UI.ApplyTitle(ipNameStr)

    local ipCategoryStr = itemInfoPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ipCategoryStr:SetPoint("TOPRIGHT", itemInfoPanel, "TOPRIGHT", -16, -54)
    ipCategoryStr:SetJustifyH("RIGHT")
    ipCategoryStr:SetJustifyV("TOP")
    UI.ApplyMutedText(ipCategoryStr)

    local ipNameSep = itemInfoPanel:CreateTexture(nil, "ARTWORK")
    UI.ApplySeparator(ipNameSep, true)
    ipNameSep:SetHeight(1)

    local ipDescLabel = itemInfoPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ipDescLabel:SetJustifyH("LEFT")
    ipDescLabel:SetJustifyV("TOP")
    UI.ApplySoftText(ipDescLabel)
    ipDescLabel:SetText("Description :")

    local ipDescText = itemInfoPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ipDescText:SetJustifyH("LEFT")
    ipDescText:SetJustifyV("TOP")
    UI.ApplyBodyText(ipDescText)
    ipDescText:SetSpacing(4)

    local ipBotSep = itemInfoPanel:CreateTexture(nil, "ARTWORK")
    UI.ApplySeparator(ipBotSep)
    ipBotSep:SetHeight(1)

    local ipAddBtn = CreatePanelButton(itemInfoPanel, IP_W - 32, 22, "Ajouter")
    local ipAddCallback = nil

    ipAddBtn:SetScript("OnClick", function()
        if ipAddCallback then
            ipAddCallback()
        end
    end)

    local function ResolveCategoryLabel(itemType)
        local catLabel = GetCategoryLabel and GetCategoryLabel(itemType) or nil
        if catLabel then
            return catLabel
        end

        for _, menuItem in ipairs(MenuItems) do
            if menuItem.key == itemType then
                return menuItem.dbLabel or menuItem.label
            end
        end

        return "Objet"
    end

    local function ShowItemInfo(item, itemType)
        local topPadding = 120
        local descBottomGap = 18
        local buttonBlockHeight = 47
        local bottomPadding = 16

        ipNameStr:SetText(item.label)
        ipCategoryStr:SetText(ResolveCategoryLabel(itemType))

        local desc = item.desc
        if desc == nil or Trim(desc) == "" then
            desc = "Aucune description."
        end

        ipNameSep:ClearAllPoints()
        ipNameSep:SetPoint("TOPLEFT", itemInfoPanel, "TOPLEFT", 16, -82)
        ipNameSep:SetPoint("TOPRIGHT", itemInfoPanel, "TOPRIGHT", -16, -82)

        ipDescLabel:ClearAllPoints()
        ipDescLabel:SetPoint("TOPLEFT", itemInfoPanel, "TOPLEFT", 16, -98)
        ipDescLabel:SetPoint("TOPRIGHT", itemInfoPanel, "TOPRIGHT", -16, -98)
        ipDescLabel:Show()

        ipDescText:ClearAllPoints()
        ipDescText:SetPoint("TOPLEFT", itemInfoPanel, "TOPLEFT", 16, -120)
        ipDescText:SetPoint("TOPRIGHT", itemInfoPanel, "TOPRIGHT", -16, -120)
        ipDescText:SetText(desc)
        ipDescText:Show()

        local descH = math.max(36, math.ceil(ipDescText:GetStringHeight()))
        local panelHeight = math.max(198, topPadding + descH + descBottomGap + buttonBlockHeight + bottomPadding)
        itemInfoPanel:SetHeight(panelHeight)

        local descBottomOffset = topPadding + descH

        ipBotSep:ClearAllPoints()
        ipBotSep:SetPoint("TOPLEFT", itemInfoPanel, "TOPLEFT", 0, -(descBottomOffset + descBottomGap))
        ipBotSep:SetPoint("TOPRIGHT", itemInfoPanel, "TOPRIGHT", 0, -(descBottomOffset + descBottomGap))

        ipAddBtn:ClearAllPoints()
        ipAddBtn:SetPoint("TOPLEFT", itemInfoPanel, "TOPLEFT", 16, -(descBottomOffset + descBottomGap + 15))

        ipAddCallback = function()
            local added = AddItemToDatabase(item, itemType)
            if added then
                OS2.Notify(item.label .. " a été ajouté à votre base de donnée.")
            else
                OS2.Notify(item.label .. " existe déjà dans votre base de donnée.", 1, 0.85, 0.35)
            end
            itemInfoPanel:Hide()
        end

        if not itemInfoPanel:IsVisible() then
            itemInfoPanel:ClearAllPoints()
            itemInfoPanel:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
        end

        itemInfoPanel:Show()
        itemInfoPanel:Raise()
    end

    return {
        panel = itemInfoPanel,
        ShowItemInfo = ShowItemInfo,
    }
end
