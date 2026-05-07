-- OmegaSurvive 2.0 — Plonger
local panel = OS2.panels["plonger"]

local configPanel = OS2.CreateSimpleSettingsPanel(
    "Paramètres Plonger",
    "Les paramètres du module de plongée seront disponibles prochainement.",
    160,
    panel
)

OS2.BuildModuleShell(panel, {
    title = "Plonger",
    onSettings = function()
        OS2.ToggleSettingsPanel(configPanel, OS2.Launcher)
    end,
})

local placeholder = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
placeholder:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -52)
placeholder:SetPoint("RIGHT", panel, "RIGHT", -14, 0)
placeholder:SetJustifyH("LEFT")
placeholder:SetJustifyV("TOP")
placeholder:SetText(
    "Les fonctionnalités de la plongée seront disponibles prochainement.\n\n"
    .. "Cette fiche utilise déjà le même gabarit que les autres modules."
)

OS2.SetPanelAutoHeight(panel, 52 + placeholder:GetStringHeight(), 18, 170)
