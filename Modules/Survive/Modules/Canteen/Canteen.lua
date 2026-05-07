-- OmegaSurvive 2.0 — Gourde
local panel = OS2.panels["gourde"]

local configPanel = OS2.CreateSimpleSettingsPanel(
    "Paramètres Gourde",
    "Les paramètres de la gourde seront disponibles prochainement.",
    160,
    panel
)

OS2.BuildModuleShell(panel, {
    title = "Hydratation",
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
    "Les fonctionnalités de la gourde seront disponibles prochainement.\n\n"
    .. "Cette fiche adopte déjà le gabarit commun des modules."
)

OS2.SetPanelAutoHeight(panel, 52 + placeholder:GetStringHeight(), 18, 170)
