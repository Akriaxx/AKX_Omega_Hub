-- Studio operations extend themes with optional, backward-compatible fields.
local ZG=ZoneGate
local function copy(value)
    if type(value)~="table" then return value end
    local result={};for k,v in pairs(value) do result[k]=copy(v) end;return result
end
ZG.CopyTheme=copy
ZG.StudioDesigns={classic="Classique",souls="Cendres — dark fantasy",western="Frontière — western",sumi="Encre — samouraï",scifi="Signal — science-fiction",deco="Éclipse — art déco",minimal="Horizon — cinéma"}
ZG.StudioMotions={fade="Fondu lent",rise="Élévation",stamp="Impact",split="Déploiement"}
ZG.StudioPlacements={top="Haut de l'écran",center="Centre",bottom="Bas de l'écran"}
ZG.StudioPresets={
    {name="Cendres",caption="Dark fantasy · solennel",design="souls",motion="fade",font="cinzel",color={.88,.85,.77},sub={.60,.58,.53},bg={.12,.11,.09,.9},frame="none",sep="none",size=34,hold=4},
    {name="Frontière",caption="Western · encre rouge",design="western",motion="stamp",font="cinzel",color={1,.93,.78},sub={.92,.78,.62},bg={.48,.045,.025,.95},frame="none",sep="none",size=34,hold=3},
    {name="Encre",caption="Samouraï · geste au pinceau",design="sumi",motion="split",font="metamorphous",color={.96,.92,.82},sub={.81,.75,.63},bg={.12,.10,.09,.95},frame="none",sep="none",size=32,hold=3},
    {name="Signal",caption="Science-fiction · terminal",design="scifi",motion="rise",font="cinzel",color={.60,.96,1},sub={.60,.78,.80},bg={.04,.35,.40,.9},frame="none",sep="none",size=28,hold=2.5},
    {name="Éclipse",caption="Art déco · or et géométrie",design="deco",motion="split",font="cinzel",color={1,.86,.53},sub={.82,.76,.59},bg={.68,.49,.20,.95},frame="none",sep="none",size=30,hold=3},
    {name="Horizon",caption="Cinéma · sobre et aérien",design="minimal",motion="rise",font="cinzel",color={.94,.92,.83},sub={.77,.80,.82},bg={.55,.58,.62,.6},frame="none",sep="none",size=28,hold=2.5},
}
local landscapes={
    {"forest_spring","Éveil","Forêt · printemps",{.65,.90,.56}},
    {"forest_summer","Canopée","Forêt · été",{.22,.65,.40}},
    {"forest_autumn","Feuilles d'or","Forêt · automne",{.95,.52,.20}},
    {"forest_winter","Bois de givre","Forêt · hiver",{.68,.84,.95}},
    {"mountains","Hautes terres","Montagnes · roche",{.66,.60,.48}},
    {"snowpeaks","Cimes éternelles","Montagnes · neige",{.76,.89,1}},
    {"desert","Dunes","Désert · sable",{.95,.70,.36}},
    {"ocean","Marées","Océan · vagues",{.34,.78,.88}},
    {"marsh","Feux follets","Marais · brume",{.48,.73,.51}},
    {"ruins","Vestiges","Ruines · pierres anciennes",{.77,.72,.56}},
    {"volcano","Fournaise","Volcan · braises",{1,.34,.14}},
    {"cavern","Profondeurs","Grottes · minéraux",{.66,.55,.86}},
    {"relic","Relique céleste","Aventure · sanctuaire",{.87,.77,.40}},
    {"crystal","Chant du cristal","Épopée · cristaux",{.49,.77,1}},
    {"hunt","La grande traque","Chasse · griffes et trophées",{.84,.65,.38}},
    {"gothic","Couronne déchue","Gothique · cathédrale",{.72,.52,.53}},
    {"runes","Serment du Nord","Légende · runes",{.62,.80,.87}},
    {"portal","Seuil astral","Magie · portail",{.74,.48,.96}},
}
for _,entry in ipairs(landscapes) do
    local key,name,caption,color=unpack(entry)
    ZG.StudioDesigns[key]=name.." — "..caption
    ZG.StudioPresets[#ZG.StudioPresets+1]={name=name,caption=caption,design=key,motion="fade",font="cinzel",color={.92,.90,.82},sub={.73,.77,.74},bg={color[1],color[2],color[3],.9},frame="none",sep="none",size=30,hold=3.5}
end
local quiet={
    {"quiet_sacred","Souffle sacré","Aventure · or patiné",{.76,.68,.42}},
    {"quiet_survivor","Après le silence","Survie · gris et olive",{.60,.64,.53}},
    {"quiet_reverie","Rêverie","Épopée · nacre et cristal",{.62,.78,.92}},
    {"quiet_ronin","Dernier haïku","Samouraï · encre et vermillon",{.73,.27,.20}},
    {"quiet_orbit","Orbite","Exploration · blanc froid",{.66,.79,.83}},
    {"quiet_ashen","Dernière braise","Royaume déchu · bronze",{.70,.54,.35}},
    {"quiet_noir","Minuit","Enquête · gris argent",{.68,.70,.72}},
    {"quiet_fable","Conte ancien","Légende · vert sauge",{.57,.71,.55}},
    {"quiet_bamboo","Brise de bambou","Asie · bambou et céladon",{.49,.72,.56}},
    {"quiet_sakura","Fleurs du soir","Japon · fleurs de cerisier",{.86,.63,.69}},
    {"quiet_jade","Cour de jade","Chine · jade et géométrie",{.39,.74,.65}},
    {"quiet_wave","Vagues de soie","Japon · vagues et indigo",{.48,.61,.85}},
    {"quiet_rosette","Rosace d'azur","Perse · rosace et azur",{.36,.68,.88}},
    {"quiet_arch","Porte d'ambre","Moyen-Orient · arc et ambre",{.90,.66,.35}},
    {"quiet_lattice","Lumière ajourée","Moyen-Orient · treillis fin",{.72,.64,.49}},
    {"quiet_arabesque","Jardin de nacre","Moyen-Orient · arabesques",{.70,.84,.77}},
    {"quiet_caravan","Route des sables","Moyen-Orient · sable et textile",{.83,.62,.43}},
    {"quiet_copper","Cuivre ciselé","Moyen-Orient · cuivre gravé",{.84,.48,.30}},
}
for _,entry in ipairs(quiet) do
    local key,name,caption,color=unpack(entry)
    ZG.StudioDesigns[key]=name.." — "..caption
    ZG.StudioPresets[#ZG.StudioPresets+1]={name=name,caption=caption,design=key,motion=key=="quiet_orbit" and "rise" or "fade",font="cinzel",color={.93,.91,.84},sub={.70,.73,.70},bg={color[1],color[2],color[3],.85},frame="none",sep="none",size=key=="quiet_survivor" and 26 or 30,hold=3.5}
end
function ZG:StudioPresetTheme(preset)
    local t=copy(self.DefaultTheme)
    t.name=preset.name;t.font=preset.font;t.titleColor=copy(preset.color);t.subColor=copy(preset.sub)
    t.sepColor={unpack(preset.color)};t.sepColor[4]=.75
    t.frameColor={unpack(preset.color)};t.frameColor[4]=.8
    t.bgColor=copy(preset.bg);t.bgEnabled=true;t.frameStyle=preset.frame;t.sepStyle=preset.sep
    t.titleSize=preset.size;t.fadeIn=.8;t.hold=preset.hold;t.fadeOut=1.2
    t.design=preset.design;t.motion=preset.motion;t.placement="center";t.bannerWidth=600
    t.outline=false;t.uppercase=false;t.letterSpacing=false;t.midSepEnabled=false
    return t
end
function ZG:SetStudioOption(id,key,value)
    local theme=self:GetTheme(id)
    if not theme or theme.creator~=UnitName("player") then return false end
    local allowed=key=="design" and self.StudioDesigns or key=="motion" and self.StudioMotions or key=="placement" and self.StudioPlacements
    if key=="bannerWidth" then value=math.max(400,math.min(900,tonumber(value) or 600))
    elseif not allowed or not allowed[value] then return false end
    theme[key]=value;self:ScheduleBroadcast();return true
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
