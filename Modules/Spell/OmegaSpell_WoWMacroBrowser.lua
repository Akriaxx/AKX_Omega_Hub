-- OmegaSpell - Acces aux macros WoW depuis l'interface commune de macros

OmegaSpell = OmegaSpell or {}
OmegaSpell.WoWMacroBrowser = OmegaSpell.WoWMacroBrowser or {}

local Lib = OmegaSpell.WoWMacroBrowser

function Lib.Open()
    if OmegaSpell.MacroLibrary and OmegaSpell.MacroLibrary.Open then
        OmegaSpell.MacroLibrary.Open("wow")
    end
end

function Lib.Refresh()
    if OmegaSpell.MacroLibrary and OmegaSpell.MacroLibrary.Refresh then
        OmegaSpell.MacroLibrary.Refresh()
    end
end

function Lib.Close()
    if OmegaSpell.MacroLibrary and OmegaSpell.MacroLibrary.Close then
        OmegaSpell.MacroLibrary.Close()
    end
end

