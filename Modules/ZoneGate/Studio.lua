-- Studio operations keep the existing theme format and network protocol.
local ZG=ZoneGate
local function copy(value)
    if type(value)~="table" then return value end
    local result={};for k,v in pairs(value) do result[k]=copy(v) end;return result
end
ZG.CopyTheme=copy
ZG.StudioPresets={
    {name="Sanctuaire",caption="Or pâle · cérémoniel",font="cinzel",color={1,.86,.53},sub={.84,.80,.67},bg={.055,.04,.025,.82},frame="ornate",sep="double",size=32,hold=3.5},
    {name="Sylve ancienne",caption="Émeraude · mystérieux",font="metamorphous",color={.64,.92,.74},sub={.72,.82,.71},bg={.015,.07,.045,.85},frame="ornate",sep="single",size=30,hold=3},
    {name="Terres maudites",caption="Pourpre · menaçant",font="pirataone",color={.94,.38,.34},sub={.82,.63,.59},bg={.08,.01,.025,.88},frame="box",sep="none",size=36,hold=3},
    {name="Royaume oublié",caption="Bronze · ancestral",font="morpheus",color={.88,.72,.46},sub={.75,.69,.57},bg={.065,.05,.035,.87},frame="ornate",sep="double",size=34,hold=3.5},
    {name="Nexus arcanique",caption="Violet · ésotérique",font="metamorphous",color={.78,.64,1},sub={.74,.80,1},bg={.04,.025,.10,.85},frame="ornate",sep="single",size=30,hold=3},
    {name="Voyage",caption="Ivoire · épuré",font="cinzel",color={.94,.92,.83},sub={.77,.80,.82},bg={.025,.035,.055,.65},frame="none",sep="single",size=28,hold=2.5},
}
function ZG:StudioPresetTheme(preset)
    local t=copy(self.DefaultTheme)
    t.name=preset.name;t.font=preset.font;t.titleColor=copy(preset.color);t.subColor=copy(preset.sub)
    t.sepColor={unpack(preset.color)};t.sepColor[4]=.75
    t.frameColor={unpack(preset.color)};t.frameColor[4]=.8
    t.bgColor=copy(preset.bg);t.bgEnabled=true;t.frameStyle=preset.frame;t.sepStyle=preset.sep
    t.titleSize=preset.size;t.fadeIn=.8;t.hold=preset.hold;t.fadeOut=1.2
    t.outline=false;t.uppercase=false;t.letterSpacing=false;t.midSepEnabled=false
    return t
end
function ZG:RestoreStudioTheme(id,snapshot)
    local theme=self:GetTheme(id)
    if not theme or theme.creator~=UnitName("player") then return false end
    for key in pairs(self.DefaultTheme) do
        if key~="id" and key~="creator" then theme[key]=copy(snapshot[key]) end
    end
    self:ScheduleBroadcast();return true
end
function ZG:CreateStudioTheme(preset,source)
    local snapshot=source and copy(source) or self:StudioPresetTheme(preset)
    local theme=self:CreateTheme(source and ((source.name or "Thème").." — copie") or snapshot.name)
    if not theme then return end
    snapshot.name=theme.name
    self:RestoreStudioTheme(theme.id,snapshot)
    return theme
end
