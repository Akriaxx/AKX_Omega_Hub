OmegaSpeak = OmegaSpeak or {}
local OS = OmegaSpeak
local UI = OmegaSpeak.UI

OS.maxTotalLength = 255
OS.sendDelay = 0.35
OS.outputChannel = "RAID"

OS.channels = {
    { key = "SAY",  label = "Say",  prefix = ".n sa " },
    { key = "YELL", label = "Yell", prefix = ".n y "  },
}

OS.db = OS.db or {
    launcherX = 0,
    launcherY = 0,
    panelOpen = false,
    channelKey = "SAY",
}

OS.state = {
    isSending = false,
    queue = {},
}

local launcher
local panel
local editBox
local channelButton
local closeButton
local UpdateLauncherVisualState

-- //////////////////////////////////////////////////////////
-- Helpers
-- //////////////////////////////////////////////////////////

local function Trim(text)
    if type(text) ~= "string" then
        return ""
    end

    text = text:gsub("\r", " ")
    text = text:gsub("\n", " ")
    text = text:gsub("%s+", " ")
    text = text:gsub("^%s+", "")
    text = text:gsub("%s+$", "")

    return text
end

local function GetChannelData(channelKey)
    for i = 1, #OS.channels do
        if OS.channels[i].key == channelKey then
            return OS.channels[i]
        end
    end

    return OS.channels[1]
end

local function SplitMessageForCommand(text, prefix, maxTotalLength)
    text = Trim(text)

    local results = {}

    if text == "" then
        return results
    end

    local maxContentLength = maxTotalLength - string.len(prefix)
    if maxContentLength <= 0 then
        return results
    end

    local currentChunk = ""

    for word in text:gmatch("%S+") do
        local candidate

        if currentChunk == "" then
            candidate = word
        else
            candidate = currentChunk .. " " .. word
        end

        if string.len(candidate) <= maxContentLength then
            currentChunk = candidate
        else
            if currentChunk ~= "" then
                table.insert(results, currentChunk)
            end

            if string.len(word) <= maxContentLength then
                currentChunk = word
            else
                local startIndex = 1
                while startIndex <= string.len(word) do
                    local part = string.sub(word, startIndex, startIndex + maxContentLength - 1)
                    table.insert(results, part)
                    startIndex = startIndex + maxContentLength
                end
                currentChunk = ""
            end
        end
    end

    if currentChunk ~= "" then
        table.insert(results, currentChunk)
    end

    return results
end

local function DequeueAndSendNext()
    if #OS.state.queue == 0 then
        OS.state.isSending = false
        return
    end

    OS.state.isSending = true

    local message = table.remove(OS.state.queue, 1)
    SendChatMessage(message, OS.outputChannel)

    if #OS.state.queue > 0 then
        C_Timer.After(OS.sendDelay, DequeueAndSendNext)
    else
        OS.state.isSending = false
    end
end

local function EnqueueMessages(messages)
    for i = 1, #messages do
        table.insert(OS.state.queue, messages[i])
    end

    if not OS.state.isSending then
        DequeueAndSendNext()
    end
end

local function SendNpcSpeech(text)
    local channelData = GetChannelData(OS.db.channelKey)
    local prefix = channelData.prefix
    local chunks = SplitMessageForCommand(text, prefix, OS.maxTotalLength)

    if #chunks == 0 then
        return
    end

    local messages = {}
    for i = 1, #chunks do
        messages[i] = prefix .. chunks[i]
    end

    EnqueueMessages(messages)
end

-- //////////////////////////////////////////////////////////
-- UI State
-- //////////////////////////////////////////////////////////

local function UpdateChannelButtonText()
    if not channelButton then
        return
    end

    local channelData = GetChannelData(OS.db.channelKey)
    channelButton:SetText("Canal : " .. channelData.label)
end

local function CycleChannel()
    local currentIndex = 1

    for i = 1, #OS.channels do
        if OS.channels[i].key == OS.db.channelKey then
            currentIndex = i
            break
        end
    end

    currentIndex = currentIndex + 1
    if currentIndex > #OS.channels then
        currentIndex = 1
    end

    OS.db.channelKey = OS.channels[currentIndex].key
    UpdateChannelButtonText()
end

local function HidePanel()
    if panel then
        panel:Hide()
    end
    OS.db.panelOpen = false
    UpdateLauncherVisualState()
end

local function ShowPanel()
    if panel then
        panel:Show()
    end
    OS.db.panelOpen = true
    UpdateLauncherVisualState()

    if editBox then
        editBox:SetFocus()
    end
end

local function TogglePanel()
    if panel:IsShown() then
        HidePanel()
    else
        ShowPanel()
    end
end

-- //////////////////////////////////////////////////////////
-- UI Creation
-- //////////////////////////////////////////////////////////

UpdateLauncherVisualState = function()
    if not launcher then
        return
    end

    if OS.db.panelOpen then
        if launcher.icon then
            launcher.icon:SetVertexColor(1.00, 0.92, 0.72, 1.00)
        end
        if launcher.bg then
            launcher.bg:SetColorTexture(0.10, 0.08, 0.04, 0.98)
        end
        if launcher.glow then
            launcher.glow:Show()
        end
    else
        if launcher.icon then
            launcher.icon:SetVertexColor(1.00, 1.00, 1.00, 1.00)
        end
        if launcher.bg then
            launcher.bg:SetColorTexture(0.04, 0.04, 0.04, 0.96)
        end
        if launcher.glow then
            launcher.glow:Hide()
        end
    end
end

local function CreateLauncher()
    launcher = CreateFrame("Button", "OmegaSpeakLauncher", UIParent)
    launcher:SetSize(36, 36)
    launcher:SetPoint("CENTER", UIParent, "CENTER", OS.db.launcherX, OS.db.launcherY)
    launcher:SetMovable(true)
    launcher:EnableMouse(true)
    launcher:RegisterForDrag("LeftButton")
    launcher:SetClampedToScreen(true)

    local bg = launcher:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.04, 0.04, 0.04, 0.96)
    launcher.bg = bg

    local icon = launcher:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", launcher, "TOPLEFT", 4, -4)
    icon:SetPoint("BOTTOMRIGHT", launcher, "BOTTOMRIGHT", -4, 4)
    icon:SetTexture("Interface\\Icons\\Ability_Warrior_BattleShout")
    icon:SetTexCoord(0, 1, 0, 1)
    launcher.icon = icon

    local borderTop = launcher:CreateTexture(nil, "ARTWORK")
    borderTop:SetPoint("TOPLEFT", launcher, "TOPLEFT", 1, -1)
    borderTop:SetPoint("TOPRIGHT", launcher, "TOPRIGHT", -1, -1)
    borderTop:SetHeight(1)
    borderTop:SetColorTexture(0.82, 0.66, 0.20, 1)

    local borderBottom = launcher:CreateTexture(nil, "ARTWORK")
    borderBottom:SetPoint("BOTTOMLEFT", launcher, "BOTTOMLEFT", 1, 1)
    borderBottom:SetPoint("BOTTOMRIGHT", launcher, "BOTTOMRIGHT", -1, 1)
    borderBottom:SetHeight(1)
    borderBottom:SetColorTexture(0.82, 0.66, 0.20, 1)

    local borderLeft = launcher:CreateTexture(nil, "ARTWORK")
    borderLeft:SetPoint("TOPLEFT", launcher, "TOPLEFT", 1, -1)
    borderLeft:SetPoint("BOTTOMLEFT", launcher, "BOTTOMLEFT", 1, 1)
    borderLeft:SetWidth(1)
    borderLeft:SetColorTexture(0.82, 0.66, 0.20, 1)

    local borderRight = launcher:CreateTexture(nil, "ARTWORK")
    borderRight:SetPoint("TOPRIGHT", launcher, "TOPRIGHT", -1, -1)
    borderRight:SetPoint("BOTTOMRIGHT", launcher, "BOTTOMRIGHT", -1, 1)
    borderRight:SetWidth(1)
    borderRight:SetColorTexture(0.82, 0.66, 0.20, 1)

    local glow = launcher:CreateTexture(nil, "OVERLAY")
    glow:SetAllPoints()
    glow:SetColorTexture(1.00, 0.82, 0.22, 0.12)
    glow:Hide()
    launcher.glow = glow

    local hl = launcher:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1.0, 0.88, 0.30, 0.10)

    launcher:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() then
            self:StartMoving()
        end
    end)

    launcher:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()

        local centerX = self:GetLeft() + (self:GetWidth() / 2)
        local centerY = self:GetBottom() + (self:GetHeight() / 2)
        local uiCenterX = UIParent:GetWidth() / 2
        local uiCenterY = UIParent:GetHeight() / 2

        OS.db.launcherX = centerX - uiCenterX
        OS.db.launcherY = centerY - uiCenterY
    end)

    launcher:SetScript("OnClick", function()
        TogglePanel()
    end)

    OS.Launcher = launcher

    local mask = launcher:CreateMaskTexture()
    mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(launcher)

    bg:AddMaskTexture(mask)
    icon:AddMaskTexture(mask)
    glow:AddMaskTexture(mask)
    hl:AddMaskTexture(mask)
    borderTop:AddMaskTexture(mask)
    borderBottom:AddMaskTexture(mask)
    borderLeft:AddMaskTexture(mask)
    borderRight:AddMaskTexture(mask)

    UpdateLauncherVisualState()
end

local function CreatePanel()
    panel = CreateFrame("Frame", "OmegaSpeakPanel", UIParent)
    panel:SetSize(420, 100)
    panel:SetPoint("TOP", launcher, "BOTTOM", 0, -8)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:Hide()

    panel:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() then
            self:StartMoving()
        end
    end)

    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    UI.ApplyWindowBackground(bg, 0.92)
    panel.bg = bg


    local borderTop = panel:CreateTexture(nil, "ARTWORK")
    borderTop:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -1)
    borderTop:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -1)
    borderTop:SetHeight(1)
    borderTop:SetColorTexture(0.60, 0.52, 0.28, 1)

    local borderBottom = panel:CreateTexture(nil, "ARTWORK")
    borderBottom:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 1, 1)
    borderBottom:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -1, 1)
    borderBottom:SetHeight(1)
    borderBottom:SetColorTexture(0.60, 0.52, 0.28, 1)

    local borderLeft = panel:CreateTexture(nil, "ARTWORK")
    borderLeft:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -1)
    borderLeft:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 1, 1)
    borderLeft:SetWidth(1)
    borderLeft:SetColorTexture(0.60, 0.52, 0.28, 1)

    local borderRight = panel:CreateTexture(nil, "ARTWORK")
    borderRight:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -1)
    borderRight:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -1, 1)
    borderRight:SetWidth(1)
    borderRight:SetColorTexture(0.60, 0.52, 0.28, 1)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -12)
    title:SetText("Omega Speak")
    UI.ApplyTitle(title)
    panel.title = title

    local separator = panel:CreateTexture(nil, "ARTWORK")
    separator:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -30)
    separator:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, -30)
    separator:SetHeight(1)
    UI.ApplySeparator(separator)

    closeButton = UI.CreateCloseButton(panel, function()
        HidePanel()
    end)

    -- Bouton paramètres (à gauche du bouton fermeture)
    local settingsBtn = CreateFrame("Button", nil, panel)
    settingsBtn:SetSize(16, 16)
    settingsBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -28, -8)
    settingsBtn:SetFrameLevel(panel:GetFrameLevel() + 10)
    settingsBtn:EnableMouse(true)
    settingsBtn:RegisterForClicks("AnyButtonUp")

    local sbTex = settingsBtn:CreateTexture(nil, "ARTWORK")
    sbTex:SetAllPoints()
    sbTex:SetTexture("Interface/Icons/INV_Misc_Gear_01")
    sbTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local sbHl = settingsBtn:CreateTexture(nil, "HIGHLIGHT")
    sbHl:SetTexture("Interface/Buttons/ButtonHilight-Square")
    sbHl:SetAllPoints()
    sbHl:SetBlendMode("ADD")

    settingsBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Paramètres", 0.95, 0.90, 0.78)
        GameTooltip:Show()
    end)
    settingsBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    settingsBtn:SetScript("OnClick", function()
        if OS.ToggleSettings then OS:ToggleSettings() end
    end)

    OS.panel  = panel

    editBox = UI.CreateStyledEditBox(panel, 396, 44, true)
    editBox:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -40)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetMaxLetters(4000)

    OS.editBox = editBox

    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        HidePanel()
    end)

    editBox:SetScript("OnEnterPressed", function(self)
        if IsShiftKeyDown() then
            self:Insert("\n")
            return
        end

        local text = Trim(self:GetText())
        if text ~= "" then
            SendNpcSpeech(text)
            self:SetText("")
        end

        self:HighlightText(0, 0)
        C_Timer.After(0, function()
            if self and self:IsShown() then
                self:SetFocus()
                self:HighlightText(0, 0)
            end
        end)
    end)

    channelButton = UI.CreatePanelButton(panel, 110, 20, "")
    channelButton:SetPoint("TOPRIGHT", editBox, "BOTTOMRIGHT", 0, -6)
    channelButton:SetScript("OnClick", function()
        CycleChannel()
    end)

    UpdateChannelButtonText()
end

-- //////////////////////////////////////////////////////////
-- Enable / Disable (API Hub)
-- //////////////////////////////////////////////////////////

function OS:Enable()
    if not launcher then
        CreateLauncher()
        CreatePanel()
        launcher:ClearAllPoints()
        launcher:SetPoint("CENTER", UIParent, "CENTER", OS.db.launcherX, OS.db.launcherY)
        UpdateChannelButtonText()
    end

    launcher:Show()
    UpdateLauncherVisualState()

    if OS.ApplySettings then OS:ApplySettings() end

    if OS.db.panelOpen then ShowPanel() else HidePanel() end

    SLASH_OMEGASPEAK1 = "/ospeak"
    SlashCmdList["OMEGASPEAK"] = function(msg)
        msg = Trim(msg or "")
        if msg == "" then TogglePanel() return end
        SendNpcSpeech(msg)
    end

    OmegaHub:SetModuleLoaded("Omega_Speak", true)
    if not OmegaHub._startingUp then
        OmegaHub.Print("Omega Speak activé.  |cffAAAAAA/ospeak [message]|r")
    end
end

function OS:Disable()
    if panel  then panel:Hide()    end
    if launcher then launcher:Hide() end
    if OS.db  then OS.db.panelOpen = false end

    SLASH_OMEGASPEAK1 = nil
    SlashCmdList["OMEGASPEAK"] = nil

    OmegaHub:SetModuleLoaded("Omega_Speak", false)
    OmegaHub.Print("Omega Speak désactivé.")
end

-- //////////////////////////////////////////////////////////
-- Init
-- //////////////////////////////////////////////////////////

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
    OmegaSpeakDB = OmegaSpeakDB or {}
    if OmegaSpeakDB.launcherX  == nil then OmegaSpeakDB.launcherX  = 0     end
    if OmegaSpeakDB.launcherY  == nil then OmegaSpeakDB.launcherY  = 0     end
    if OmegaSpeakDB.panelOpen  == nil then OmegaSpeakDB.panelOpen  = false  end
    if OmegaSpeakDB.channelKey == nil then OmegaSpeakDB.channelKey = "SAY" end
    OmegaSpeakDB.settings = OmegaSpeakDB.settings or {}
    local _s = OmegaSpeakDB.settings
    if _s.launcherSize  == nil then _s.launcherSize  = 36   end
    if _s.textScale     == nil then _s.textScale     = 1.0  end
    if _s.windowScale   == nil then _s.windowScale   = 1.0  end
    if _s.windowOpacity == nil then _s.windowOpacity = 0.92 end
    OS.db = OmegaSpeakDB

    -- Lie la référence du module au Hub pour Enable/Disable dynamique
    OmegaHub:RegisterModule({ name = "Omega_Speak", module = OS })

    if OmegaHub:IsModuleEnabled("Omega_Speak") then
        OS:Enable()
    end
end)