-- GrimoireCraft v2.57.47
-- Base stable V2.0 reconstruite avec classement des recettes par métier.

local ADDON_NAME = ...  -- "Omega_Hub" : le Grimoire est désormais un module du Hub
local DB

local ADDON_DATABASE_SYNC_VERSION = "2.57.47"
local DATABASE_CONSERVATORS = { ["Selianà"]=true, ["Ivelnamj"]=true, ["Ritch"]=true, ["Nikolaii"]=true }

local RefreshRecipeList, RefreshDetails, OpenRecipeEditor
local SendTransferMessage

-- v2.57.43 : la database officielle est uniquement celle embarquée dans
-- ObjectDatabase.lua / RecipeDatabase.lua. Aucun import ODS ni échange de database en jeu.

-- Garde-fou d'administration pour les exceptions volontaires.
-- Ce code n'est pas un secret cryptographique : il évite surtout les modifications
-- ou doublons accidentels depuis l'interface.
local OFFICIAL_RECIPE_OVERRIDE_CODE = "Taoestgay"

local UI = {
    main = nil,
    listContent = nil,
    detailContent = nil,
    editor = nil,
    selectedRecipeID = nil,
    openProfessions = {},
    openDifficulties = {},
    recipeTypeFilter = "Tous",
    favoritesOnly = false,
    transferSender = nil,
    transferReceiver = nil,
    outgoingTransfers = {},
    incomingTransfers = {},
    incomingDatabaseSync = {},
}

local QUESTION_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local BOOK_ICON = "Interface\\Icons\\INV_Misc_Book_09"
local STATUS_READY_ICON = "Interface\\AddOns\\Omega_Hub\\Modules\\GrimoireCraft\\Media\\UIIcons\\StatusReady"
local STATUS_MISSING_ICON = "Interface\\AddOns\\Omega_Hub\\Modules\\GrimoireCraft\\Media\\UIIcons\\StatusMissing"
local FAVORITE_ON_ICON = "Interface\\AddOns\\Omega_Hub\\Modules\\GrimoireCraft\\Media\\UIIcons\\FavoriteOn"
local FAVORITE_OFF_ICON = "Interface\\AddOns\\Omega_Hub\\Modules\\GrimoireCraft\\Media\\UIIcons\\FavoriteOff"
local DROPDOWN_ARROW_ICON = "Interface\\AddOns\\Omega_Hub\\Modules\\GrimoireCraft\\Media\\UIIcons\\DropdownArrow"

local DEFAULT_PROFESSIONS = {
    "Alchimiste",
    "Couturier",
    "Cuisinier",
    "Erudit",
    "Forgeron",
    "Ingénieur",
    "Tanneur",
}


-- ============================================================================
-- CONDITIONS DE FABRICATION PAR MÉTIER
-- ============================================================================
local CRAFT_REQUIREMENTS = {
    ["Cuisinier"] = {
        tools = {
            {
                itemID = 14072837,
                name = "Ustensiles de Cuisine",
                required = true,
            },
            {
                itemID = 14072838,
                name = "Marmite",
                required = true,
                alternativeNPC = {
                    id = 2441800,
                    name = "Atelier de Cuisine Classique",
                    maxDistance = 2,
                },
            },
        },
    },
    ["Alchimiste"] = {
        workshop = {
            name = "Atelier d'Alchimiste",
            required = true,
        },
        tools = {
            {
                itemID = 14072844,
                name = "Mortier et Pilon",
                required = true,
            },
        },
    },
    ["Couturier"] = {
        workshop = {
            name = "Atelier de Couture",
            required = true,
            alternativeItems = {
                { itemID = 14072992, name = "Métier à Tisser" },
            },
        },
        tools = {
            { itemID = 14072839, name = "Dé à Coudre", required = true },
            { itemID = 14072840, name = "Aiguille", required = true },
        },
    },
    ["Forgeron"] = {
        workshop = {
            name = "Atelier de Métallurgie",
            required = true,
            alternativeItemSet = {
                { itemID = 14072983, name = "Petite Enclume Trandalion" },
                { itemID = 14072987, name = "Foyer Trandalion" },
            },
        },
        tools = {
            { itemID = 14072846, name = "Marteau de Forge", required = true, allowEquipped = true },
        },
    },
    ["Tanneur"] = {
        workshop = {
            name = "Atelier d'Artisanat",
            required = true,
        },
        tools = {
            { itemID = 14072810, name = "Carnet de Survie", required = true },
        },
    },
    ["Ingénieur"] = {
        workshop = {
            name = "Atelier d'Ingénierie",
            required = true,
        },
        tools = {
            { itemID = 14072841, name = "Mallette d'Ingénieur", required = true },
        },
    },
}

-- État de proximité des ateliers. La détection automatique via .dist sera
-- branchée ici dès que le format exact de réponse du serveur sera connu.
local NearbyCraftNPCs = {}

local function IsCraftNPCNearby(npcID)
    return NearbyCraftNPCs[npcID] == true
end

local function IsItemEquippedByID(itemID)
    if not itemID then return false end
    for slot=1,19 do
        local equippedID = GetInventoryItemID and GetInventoryItemID("player",slot)
        if equippedID and tonumber(equippedID)==tonumber(itemID) then return true end
    end
    return false
end

local function GetCraftToolStatus(requirement)
    local bagCount = 0
    if C_Item and C_Item.GetItemCount then
        bagCount = C_Item.GetItemCount(requirement.itemID,false,false,false) or 0
    elseif GetItemCount then
        bagCount = GetItemCount(requirement.itemID,false,false) or 0
    end

    if bagCount > 0 then
        return true, bagCount, "Sacs"
    end

    if requirement.allowEquipped and IsItemEquippedByID(requirement.itemID) then
        return true, 1, "Équipé"
    end

    if requirement.alternativeNPC and IsCraftNPCNearby(requirement.alternativeNPC.id) then
        return true, 0, requirement.alternativeNPC.name
    end

    return false, 0, nil
end

local CRAFT_DIFFICULTIES = {
    {name="Basique", minimum=0},
    {name="Mineur",      minimum=6},
    {name="Moyen",       minimum=8},
    {name="Fort",        minimum=10},
    {name="Majeur",      minimum=12},
    {name="Eminent",     minimum=14},
    {name="Prodigieux",  minimum=16},
}

local PROFESSION_ICONS = {
    ["Alchimiste"] = "Interface\\AddOns\\Omega_Hub\\Modules\\GrimoireCraft\\Media\\Professions\\Alchimiste",
    ["Couturier"] = "Interface\\AddOns\\Omega_Hub\\Modules\\GrimoireCraft\\Media\\Professions\\Couturier",
    ["Cuisinier"] = "Interface\\AddOns\\Omega_Hub\\Modules\\GrimoireCraft\\Media\\Professions\\Cuisinier",
    ["Erudit"] = "Interface\\AddOns\\Omega_Hub\\Modules\\GrimoireCraft\\Media\\Professions\\Erudit",
    ["Forgeron"] = "Interface\\AddOns\\Omega_Hub\\Modules\\GrimoireCraft\\Media\\Professions\\Forgeron",
    ["Ingénieur"] = "Interface\\AddOns\\Omega_Hub\\Modules\\GrimoireCraft\\Media\\Professions\\Ingenieur",
    ["Tanneur"] = "Interface\\AddOns\\Omega_Hub\\Modules\\GrimoireCraft\\Media\\Professions\\Tanneur",
}

local THEME = {
    bg = {0.025,0.020,0.018,0.98},
    panel = {0.045,0.038,0.030,0.94},
    paper = {0.105,0.080,0.050,0.94},
    gold = {0.72,0.56,0.27,1},
    goldBright = {0.95,0.78,0.38,1},
    ink = {0.90,0.84,0.70},
    muted = {0.55,0.49,0.40},
}

local function ApplyBookBackdrop(frame, alpha)
    frame:SetBackdrop({
        bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true,tileSize=16,edgeSize=12,
        insets={left=3,right=3,top=3,bottom=3}
    })
    frame:SetBackdropColor(THEME.paper[1],THEME.paper[2],THEME.paper[3],alpha or THEME.paper[4])
    frame:SetBackdropBorderColor(THEME.gold[1],THEME.gold[2],THEME.gold[3],1)
end

local function AddGoldRule(parent, y, left, right)
    local line=parent:CreateTexture(nil,"ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT",left or 16,y)
    line:SetPoint("TOPRIGHT",right or -16,y)
    line:SetColorTexture(THEME.gold[1],THEME.gold[2],THEME.gold[3],.55)
    return line
end

local function AddPaperTexture(frame, shade)
    local paper=frame:CreateTexture(nil,"BACKGROUND",nil,-7)
    paper:SetPoint("TOPLEFT",3,-3)
    paper:SetPoint("BOTTOMRIGHT",-3,3)
    paper:SetTexture("Interface\\AddOns\\Omega_Hub\\Modules\\GrimoireCraft\\Media\\MainPage\\Parchment")
    paper:SetTexCoord(0,1,0,1)
    local s=shade or 1
    paper:SetVertexColor(.43*s,.34*s,.22*s,.94)

    -- Assombrit légèrement les bords de page.
    local edge=frame:CreateTexture(nil,"BACKGROUND",nil,-6)
    edge:SetPoint("TOPLEFT",8,-8)
    edge:SetPoint("BOTTOMRIGHT",-8,8)
    edge:SetTexture("Interface\\Buttons\\WHITE8X8")
    edge:SetVertexColor(.055,.038,.024,.13)
end

local function AddPageNumber(parent, text, rightSide)
    local fs=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    fs:SetPoint("BOTTOM",parent,"BOTTOM",rightSide and 120 or -120,12)
    fs:SetText(text)
    fs:SetTextColor(.43,.34,.23)
end

local function AddBookSpine(parent)
    -- Creux de reliure : il reste strictement entre le haut et le bas des pages.
    -- Cela évite la barre verticale qui dépasse dans l'en-tête du livre.
    local spine=CreateFrame("Frame",nil,parent)
    spine:SetPoint("TOP",parent,"TOP",0,-142)
    spine:SetPoint("BOTTOM",parent,"BOTTOM",0,31)
    spine:SetWidth(18)

    local shadow=spine:CreateTexture(nil,"BACKGROUND")
    shadow:SetAllPoints()
    shadow:SetTexture("Interface\\Buttons\\WHITE8X8")
    shadow:SetVertexColor(.012,.008,.006,.72)

    -- Ombres intérieures des deux cahiers de pages.
    local leftShade=spine:CreateTexture(nil,"ARTWORK")
    leftShade:SetWidth(6)
    leftShade:SetPoint("TOPLEFT",0,0)
    leftShade:SetPoint("BOTTOMLEFT",0,0)
    leftShade:SetColorTexture(.10,.060,.030,.38)

    local rightShade=spine:CreateTexture(nil,"ARTWORK")
    rightShade:SetWidth(6)
    rightShade:SetPoint("TOPRIGHT",0,0)
    rightShade:SetPoint("BOTTOMRIGHT",0,0)
    rightShade:SetColorTexture(.10,.060,.030,.38)

    -- Un reflet central très discret suggère le pli sans dessiner une barre.
    local crease=spine:CreateTexture(nil,"ARTWORK")
    crease:SetWidth(1)
    crease:SetPoint("TOP",0,-5)
    crease:SetPoint("BOTTOM",0,5)
    crease:SetColorTexture(.39,.27,.13,.16)

    -- Petites terminaisons horizontales : la reliure se fond dans les pages.
    local topFade=spine:CreateTexture(nil,"ARTWORK")
    topFade:SetHeight(1)
    topFade:SetPoint("TOPLEFT",-5,0)
    topFade:SetPoint("TOPRIGHT",5,0)
    topFade:SetColorTexture(.38,.25,.11,.28)

    local bottomFade=spine:CreateTexture(nil,"ARTWORK")
    bottomFade:SetHeight(1)
    bottomFade:SetPoint("BOTTOMLEFT",-5,0)
    bottomFade:SetPoint("BOTTOMRIGHT",5,0)
    bottomFade:SetColorTexture(.38,.25,.11,.22)
end

local function AddInkFlourish(parent, y, width)
    width=width or 190

    local left=parent:CreateTexture(nil,"ARTWORK")
    left:SetHeight(1)
    left:SetWidth(width)
    left:SetPoint("TOP",parent,"TOP",-width/2-12,y)
    left:SetColorTexture(.42,.29,.14,.48)

    local right=parent:CreateTexture(nil,"ARTWORK")
    right:SetHeight(1)
    right:SetWidth(width)
    right:SetPoint("TOP",parent,"TOP",width/2+12,y)
    right:SetColorTexture(.42,.29,.14,.48)

    local mark=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
    mark:SetPoint("TOP",parent,"TOP",0,y+7)
    mark:SetText("❧")
    mark:SetTextColor(.47,.32,.15)
end

local function AddPageEdgeShade(frame, innerSide)
    local edge=frame:CreateTexture(nil,"ARTWORK",nil,-1)
    edge:SetWidth(28)
    edge:SetPoint("TOP"..innerSide,frame,"TOP"..innerSide,0,-7)
    edge:SetPoint("BOTTOM"..innerSide,frame,"BOTTOM"..innerSide,0,7)
    edge:SetTexture("Interface\\Buttons\\WHITE8X8")
    edge:SetVertexColor(.025,.016,.010,.18)

    local crease=frame:CreateTexture(nil,"ARTWORK")
    crease:SetWidth(1)
    crease:SetPoint("TOP"..innerSide,frame,"TOP"..innerSide,innerSide=="RIGHT" and -7 or 7,-10)
    crease:SetPoint("BOTTOM"..innerSide,frame,"BOTTOM"..innerSide,innerSide=="RIGHT" and -7 or 7,10)
    crease:SetColorTexture(.23,.15,.08,.32)
end

local function AddPageWear(frame)
    -- Very restrained "used recipe book" marks: no ornate UI frame.
    local top=frame:CreateTexture(nil,"ARTWORK")
    top:SetHeight(1)
    top:SetPoint("TOPLEFT",22,-10)
    top:SetPoint("TOPRIGHT",-22,-10)
    top:SetColorTexture(.35,.23,.12,.17)

    local bottom=frame:CreateTexture(nil,"ARTWORK")
    bottom:SetHeight(1)
    bottom:SetPoint("BOTTOMLEFT",28,10)
    bottom:SetPoint("BOTTOMRIGHT",-28,10)
    bottom:SetColorTexture(.35,.23,.12,.13)
end

local function InitDB()
    GrimoireCraftDB = GrimoireCraftDB or {}
    DB = GrimoireCraftDB
    DB.recipes = DB.recipes or {}
    DB.nextID = tonumber(DB.nextID) or 1
    DB.databaseVersion = tonumber(DB.databaseVersion) or 1
    DB.favorites = DB.favorites or {}

    -- Une database reçue reste active uniquement pour cette génération de l'addon.
    -- Installer une nouvelle version de GrimoireCraft rend automatiquement la base embarquée prioritaire.
    if DB.syncedBaseAddonVersion ~= ADDON_DATABASE_SYNC_VERSION then
        DB.syncedOfficialRecipes = nil
        DB.syncedOfficialObjects = nil
        DB.syncedDatabaseSource = nil
        DB.syncedDatabaseReceivedAt = nil
        DB.syncedBaseAddonVersion = ADDON_DATABASE_SYNC_VERSION
    end

    -- Compatibilité avec les recettes créées dans la V2.0.
    local professionMigration = {
        ["Alchimie"] = "Alchimiste",
        ["Cuisine"] = "Cuisinier",
        ["Forge"] = "Forgeron",
        ["Ingénierie"] = "Ingénieur",
        ["Couture"] = "Couturier",
        ["Travail du cuir"] = "Tanneur",
        ["Autre"] = "Cuisinier",
    }

    for _, recipe in ipairs(DB.recipes) do
        if not recipe.profession or recipe.profession == "" then
            recipe.profession = "Cuisinier"
        elseif professionMigration[recipe.profession] then
            recipe.profession = professionMigration[recipe.profession]
        elseif recipe.profession == "Herboristerie"
            or recipe.profession == "Enchantement"
            or recipe.profession == "Joaillerie"
            or recipe.profession == "Calligraphie" then
            recipe.profession = "Cuisinier"
        end

        -- Les recettes créées avant la V2.3.3 avaient toujours un nom saisi manuellement.
        if recipe.customName == nil then
            recipe.customName = true
        end
    end
end

local function NewRecipeID()
    local id = DB.nextID
    DB.nextID = id + 1
    return id
end

local function OfficialRecipes()
    if DB and type(DB.syncedOfficialRecipes)=="table" and #DB.syncedOfficialRecipes>0 then
        return DB.syncedOfficialRecipes
    end
    return GrimoireCraftOfficialRecipes or {}
end

local function OfficialObjects()
    if DB and type(DB.syncedOfficialObjects)=="table" then
        return DB.syncedOfficialObjects
    end
    return GrimoireCraftOfficialObjects or {}
end

local function FindOfficialRecipeByKey(key)
    if not key then return nil end
    for _,recipe in ipairs(OfficialRecipes()) do
        if recipe.officialKey==key then return recipe end
    end
end

local function FindOfficialRecipeByOutputItemID(itemID)
    itemID=tonumber(itemID)
    if not itemID then return nil end
    for _,recipe in ipairs(OfficialRecipes()) do
        if tonumber(recipe.outputItemID)==itemID then return recipe end
    end
end

local function FindOverrideForOfficialKey(key)
    if not key then return nil end
    for index,recipe in ipairs(DB.recipes) do
        if recipe.officialOverrideKey==key then return recipe,index end
    end
end

local function GetAllRecipes()
    local result={}

    -- Une surcharge personnelle autorisée remplace visuellement la recette officielle,
    -- mais la recette livrée dans RecipeDatabase.lua reste intacte.
    for _,official in ipairs(OfficialRecipes()) do
        local override=FindOverrideForOfficialKey(official.officialKey)
        if override then
            override.isOfficialOverride=true
            result[#result+1]=override
        else
            official.official=true
            result[#result+1]=official
        end
    end

    for _,recipe in ipairs(DB.recipes) do
        if not recipe.officialOverrideKey then
            result[#result+1]=recipe
        end
    end

    return result
end

local function FindRecipeByID(id)
    -- Les recettes personnelles / surcharges restent dans SavedVariables.
    for index,recipe in ipairs(DB.recipes) do
        if recipe.id==id then return recipe,index end
    end

    -- Les recettes officielles sont en lecture seule dans RecipeDatabase.lua.
    for _,recipe in ipairs(OfficialRecipes()) do
        if recipe.id==id or recipe.officialKey==id then
            recipe.official=true
            return recipe,nil
        end
    end
end

local function ApplyBackdrop(frame, alpha)
    frame:SetBackdrop({
        bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true,tileSize=16,edgeSize=12,
        insets={left=3,right=3,top=3,bottom=3}
    })
    frame:SetBackdropColor(THEME.bg[1],THEME.bg[2],THEME.bg[3],alpha or THEME.bg[4])
    frame:SetBackdropBorderColor(THEME.gold[1],THEME.gold[2],THEME.gold[3],1)
end

local function Label(parent,text,x,y,width,font)
    local fs=parent:CreateFontString(nil,"OVERLAY",font or "GameFontNormal")
    fs:SetPoint("TOPLEFT",x,y)
    fs:SetWidth(width or 300)
    fs:SetJustifyH("LEFT")
    fs:SetText(text or "")
    return fs
end

local function Button(parent,text,width,height)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
    b:SetSize(width or 100,height or 26)
    b:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1 })
    b:SetBackdropColor(0,0,0,0)
    b:SetBackdropBorderColor(.31,.22,.10,.85)

    local skin=b:CreateTexture(nil,"BACKGROUND")
    skin:SetPoint("TOPLEFT",1,-1); skin:SetPoint("BOTTOMRIGHT",-1,1)
    skin:SetTexture("Interface\\AddOns\\Omega_Hub\\Modules\\GrimoireCraft\\Media\\MainPage\\ButtonNormal")
    b._skin=skin

    local fs=b:CreateFontString(nil,"OVERLAY","GameFontNormal")
    b.label=fs; fs:SetPoint("CENTER",0,0); fs:SetText(text or ""); fs:SetTextColor(.90,.81,.62)
    fs:SetShadowColor(.02,.01,.005,.95); fs:SetShadowOffset(1,-1)

    b:SetScript("OnEnter",function(self)
        self._skin:SetTexture("Interface\\AddOns\\Omega_Hub\\Modules\\GrimoireCraft\\Media\\MainPage\\ButtonHover")
        self:SetBackdropBorderColor(.67,.46,.18,1); self.label:SetTextColor(1,.90,.61)
    end)
    b:SetScript("OnLeave",function(self)
        if self._filterSelected then
            self._skin:SetTexture("Interface\\AddOns\\Omega_Hub\\Modules\\GrimoireCraft\\Media\\MainPage\\ButtonSelected")
            self.label:SetTextColor(1,.88,.52)
        else
            self._skin:SetTexture("Interface\\AddOns\\Omega_Hub\\Modules\\GrimoireCraft\\Media\\MainPage\\ButtonNormal")
            self.label:SetTextColor(.90,.81,.62)
        end
        self:SetBackdropBorderColor(.31,.22,.10,.85)
    end)
    b:SetScript("OnMouseDown",function(self) self.label:SetPoint("CENTER",1,-1) end)
    b:SetScript("OnMouseUp",function(self) self.label:SetPoint("CENTER",0,0) end)
    b.SetText=function(self,newText) self.label:SetText(newText or "") end
    b.GetText=function(self) return self.label:GetText() end
    return b
end

-- v2.57.14 : registre de présence dédié à la transmission de savoir.
-- La liste ne contient que les membres de guilde ayant réellement répondu avec GrimoireCraft.
local TRANSFER_PREFIX = "GC_RECIPE"
-- Taille volontairement conservative : les messages addon WoW ont une taille maximale.
-- Cette constante avait disparu lors des refontes de la fenêtre de transmission,
-- ce qui provoquait une erreur Lua au clic sur « Confier le manuscrit ».
local TRANSFER_CHUNK_SIZE = 180
local GC_PEERS = {}
local TRANSFER_VERSION = "2.57.47"

local function NormalizePlayerName(name)
    name=tostring(name or "")
    if Ambiguate and name~="" then
        local ok,short=pcall(Ambiguate,name,"none")
        if ok and short and short~="" then return short end
    end
    return (name:gsub("%-.*$",""))
end

local function GetOwnRPName()
    if TRP3_API and TRP3_API.register and TRP3_API.register.getPlayerCompleteName then
        local ok,name=pcall(TRP3_API.register.getPlayerCompleteName,true)
        if ok and name and name~="" then return name end
    end
    return UnitName("player") or "Artisan inconnu"
end

local function GetTRPNameForUnitID(unitID,fallback)
    if TRP3_API and TRP3_API.register then
        local reg=TRP3_API.register
        if reg.profileExists and reg.getUnitIDProfile and reg.getCompleteName then
            local ok,exists=pcall(reg.profileExists,unitID)
            if ok and exists then
                local ok2,profile=pcall(reg.getUnitIDProfile,unitID)
                if ok2 and profile and profile.characteristics then
                    local ok3,name=pcall(reg.getCompleteName,profile.characteristics,fallback or unitID,true)
                    if ok3 and name and name~="" then return name end
                end
            end
        end
    end
    return fallback or unitID
end

local function AnnounceGrimoirePresence()
    if not IsInGuild() then return end
    local rp=EscapeTransfer and EscapeTransfer(GetOwnRPName()) or GetOwnRPName()
    local msg="HELLO;"..rp..";"..TRANSFER_VERSION
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then C_ChatInfo.SendAddonMessage(TRANSFER_PREFIX,msg,"GUILD")
    elseif SendAddonMessage then SendAddonMessage(TRANSFER_PREFIX,msg,"GUILD") end
end

local function GetAvailablePeers()
    local list={}
    local now=time()
    local selfShort=NormalizePlayerName(UnitName("player"))
    for wowName,data in pairs(GC_PEERS) do
        local short=NormalizePlayerName(wowName)
        if wowName and data and (now-(data.seen or 0)) < 1800 and short~=selfShort then
            list[#list+1]={wowName=wowName,rpName=data.rpName or short or wowName,version=data.version}
        end
    end
    table.sort(list,function(a,b) return string.lower(a.rpName or a.wowName) < string.lower(b.rpName or b.wowName) end)
    return list
end

local function EscapeTransfer(v)
    v=tostring(v or "")
    return (v:gsub("%%","%%25"):gsub("|","%%7C"):gsub(";","%%3B"):gsub(",","%%2C"):gsub(":","%%3A"))
end

local function UnescapeTransfer(v)
    v=tostring(v or "")
    return (v:gsub("%%3A",":"):gsub("%%2C",","):gsub("%%3B",";"):gsub("%%7C","|"):gsub("%%25","%%"))
end

local function IsDatabaseConservator(name)
    return DATABASE_CONSERVATORS[NormalizePlayerName(name)] == true
end

local function DBEscape(v)
    v=EscapeTransfer(v)
    return (v:gsub("%^","%%5E"):gsub("~","%%7E"):gsub("/","%%2F"):gsub("=","%%3D"))
end

local function DBUnescape(v)
    v=tostring(v or "")
    v=v:gsub("%%3D","="):gsub("%%2F","/"):gsub("%%7E","~"):gsub("%%5E","^")
    return UnescapeTransfer(v)
end

local function SerializeOfficialDatabase()
    local records={"V^"..ADDON_DATABASE_SYNC_VERSION}
    local objects=OfficialObjects()
    local keys={}
    for key in pairs(objects) do keys[#keys+1]=key end
    table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
    for _,key in ipairs(keys) do
        local o=objects[key] or {}
        records[#records+1]=table.concat({
            "O",DBEscape(key),DBEscape(o.name or ""),DBEscape(o.category or ""),
            DBEscape(o.profession or ""),DBEscape(o.usage or ""),DBEscape(o.notes or "")
        },"^")
    end
    for _,r in ipairs(OfficialRecipes()) do
        local mats={}
        for _,m in ipairs(r.materials or {}) do
            mats[#mats+1]=table.concat({DBEscape(m.itemID or ""),DBEscape(m.quantity or ""),DBEscape(m.name or "")},"=")
        end
        records[#records+1]=table.concat({
            "R",DBEscape(r.officialKey or ""),DBEscape(r.name or ""),DBEscape(r.outputItemID or ""),
            DBEscape(r.outputQuantity or ""),DBEscape(r.profession or ""),DBEscape(r.difficulty or ""),
            DBEscape(r.difficultyMinimum or ""),DBEscape(r.displayType or ""),table.concat(mats,"/"),
            DBEscape(r.outputName or ""),DBEscape(r.sourceNotes or "")
        },"^")
    end
    return table.concat(records,"~")
end

local function DeserializeOfficialDatabase(payload)
    local objects,recipes={},{}
    local syncVersion=nil
    for record in string.gmatch(tostring(payload or ""),"([^~]+)") do
        local f={strsplit("^",record)}
        if f[1]=="V" then
            syncVersion=f[2]
        elseif f[1]=="O" then
            local raw=DBUnescape(f[2] or "")
            local key=tonumber(raw) or raw
            objects[key]={name=DBUnescape(f[3] or ""),category=DBUnescape(f[4] or ""),profession=DBUnescape(f[5] or ""),usage=DBUnescape(f[6] or ""),notes=DBUnescape(f[7] or "")}
        elseif f[1]=="R" then
            local r={
                officialKey=DBUnescape(f[2] or ""),name=DBUnescape(f[3] or ""),
                outputItemID=(function(v) v=DBUnescape(v or ""); if v=="" then return nil end; return tonumber(v) or v end)(f[4]),
                outputQuantity=tonumber(DBUnescape(f[5] or "")) or DBUnescape(f[5] or ""),
                profession=DBUnescape(f[6] or ""),difficulty=DBUnescape(f[7] or ""),
                difficultyMinimum=tonumber(DBUnescape(f[8] or "")) or DBUnescape(f[8] or ""),
                displayType=DBUnescape(f[9] or ""),materials={},outputName=DBUnescape(f[11] or ""),sourceNotes=DBUnescape(f[12] or ""),official=true,
            }
            for mat in string.gmatch(f[10] or "","([^/]+)") do
                local mf={strsplit("=",mat)}
                r.materials[#r.materials+1]={itemID=tonumber(DBUnescape(mf[1] or "")) or DBUnescape(mf[1] or ""),quantity=tonumber(DBUnescape(mf[2] or "")) or DBUnescape(mf[2] or ""),name=DBUnescape(mf[3] or "")}
            end
            recipes[#recipes+1]=r
        end
    end
    if not syncVersion or #recipes==0 then return nil end
    return objects,recipes,syncVersion
end

local function ShowDatabaseUpdateWindow(sender,token)
    StaticPopupDialogs["GRIMOIRECRAFT_DATABASE_UPDATE_AVAILABLE"] = StaticPopupDialogs["GRIMOIRECRAFT_DATABASE_UPDATE_AVAILABLE"] or {
        text="De nouveaux savoirs sont proposés par %s.\n\nVoulez-vous actualiser votre database officielle ?",
        button1="Actualiser le grimoire", button2="Plus tard", timeout=0, whileDead=true, hideOnEscape=true, preferredIndex=3,
        OnAccept=function(self,data)
            if data and data.sender and data.token then SendTransferMessage(data.sender,"DBREQ;"..data.token) end
        end,
    }
    StaticPopup_Show("GRIMOIRECRAFT_DATABASE_UPDATE_AVAILABLE",NormalizePlayerName(sender),nil,{sender=sender,token=token})
end

local function SendOfficialDatabaseTo(target,token)
    if not target or not IsDatabaseConservator(UnitName("player")) then return end
    local payload=SerializeOfficialDatabase()
    local chunkSize=180
    local total=math.ceil(#payload/chunkSize)
    local transferToken=(token and token~="" and token) or (tostring(time()).."-"..tostring(math.random(1000,9999)))
    local function sendChunk(i)
        local first=(i-1)*chunkSize+1
        SendTransferMessage(target,"DBCHUNK;"..transferToken..";"..i..";"..total..";"..string.sub(payload,first,first+chunkSize-1))
    end
    if C_Timer and C_Timer.After then
        for i=1,total do local n=i; C_Timer.After((n-1)*.09,function() sendChunk(n) end) end
    else
        for i=1,total do sendChunk(i) end
    end
end

local function BroadcastDatabaseUpdate()
    if not IsDatabaseConservator(UnitName("player")) or not IsInGuild() then return end
    local token=tostring(time()).."-"..tostring(math.random(1000,9999))
    local msg="DBPUSH;"..token
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then C_ChatInfo.SendAddonMessage(TRANSFER_PREFIX,msg,"GUILD")
    elseif SendAddonMessage then SendAddonMessage(TRANSFER_PREFIX,msg,"GUILD") end
    DEFAULT_CHAT_FRAME:AddMessage("|cffb8a36a[Grimoire]|r Mise à jour de la database proposée à la guilde.")
end

local function ApplyReceivedDatabase(sender,payload)
    if not IsDatabaseConservator(sender) then return end
    local objects,recipes=DeserializeOfficialDatabase(payload)
    if not objects or not recipes then
        DEFAULT_CHAT_FRAME:AddMessage("|cffb8a36a[Grimoire]|r |cffff6b6bLa database reçue est incomplète et n'a pas été appliquée.|r")
        return
    end
    DB.syncedOfficialObjects=objects
    DB.syncedOfficialRecipes=recipes
    DB.syncedDatabaseSource=NormalizePlayerName(sender)
    DB.syncedDatabaseReceivedAt=time()
    DB.syncedBaseAddonVersion=ADDON_DATABASE_SYNC_VERSION
    if RefreshRecipeList then RefreshRecipeList() end
    if RefreshDetails then RefreshDetails() end
    DEFAULT_CHAT_FRAME:AddMessage("|cffb8a36a[Grimoire]|r |cff72c472Database actualisée depuis "..NormalizePlayerName(sender)..".|r")
end

local function SerializePersonalRecipe(recipe)
    local mats={}
    for _,m in ipairs(recipe.materials or {}) do
        mats[#mats+1]=tostring(tonumber(m.itemID) or 0)..":"..tostring(math.max(1,tonumber(m.quantity) or 1))
    end
    local fields={
        EscapeTransfer(recipe.name or ""), EscapeTransfer(recipe.profession or "Cuisinier"),
        EscapeTransfer(recipe.difficulty or "Mineur"), tostring(tonumber(recipe.difficultyMinimum) or 0),
        tostring(tonumber(recipe.outputItemID) or 0), tostring(tonumber(recipe.outputQuantity) or 1),
        EscapeTransfer(recipe.notes or ""), table.concat(mats,",")
    }
    return table.concat(fields,"|")
end

local function DeserializePersonalRecipe(payload)
    local f={strsplit("|",payload or "")}
    if #f<8 then return nil end
    local recipe={
        name=UnescapeTransfer(f[1]), customName=true, profession=UnescapeTransfer(f[2]),
        difficulty=UnescapeTransfer(f[3]), difficultyMinimum=tonumber(f[4]) or 0,
        outputItemID=tonumber(f[5]), outputQuantity=tonumber(f[6]) or 1,
        notes=UnescapeTransfer(f[7]), materials={}
    }
    for token in string.gmatch(f[8] or "","[^,]+") do
        local a,b=strsplit(":",token)
        if tonumber(a) and tonumber(a)>0 then recipe.materials[#recipe.materials+1]={itemID=tonumber(a),quantity=tonumber(b) or 1} end
    end
    return recipe
end

SendTransferMessage = function(target,msg)
    if not target or target=="" then return end
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then C_ChatInfo.SendAddonMessage(TRANSFER_PREFIX,msg,"WHISPER",target)
    elseif SendAddonMessage then SendAddonMessage(TRANSFER_PREFIX,msg,"WHISPER",target) end
end

local function SetTransferStatus(frame,text,r,g,b)
    if frame and frame.status then frame.status:SetText(text or "") frame.status:SetTextColor(r or .75,g or .68,b or .52) end
end

local function AddTransmissionOrnaments(frame)
    local corners={
        {"TOPLEFT","Interface\\AddOns\\Omega_Hub\\Modules\\GrimoireCraft\\Media\\CornerTL"},
        {"TOPRIGHT","Interface\\AddOns\\Omega_Hub\\Modules\\GrimoireCraft\\Media\\CornerTR"},
        {"BOTTOMLEFT","Interface\\AddOns\\Omega_Hub\\Modules\\GrimoireCraft\\Media\\CornerBL"},
        {"BOTTOMRIGHT","Interface\\AddOns\\Omega_Hub\\Modules\\GrimoireCraft\\Media\\CornerBR"},
    }
    for _,c in ipairs(corners) do
        local t=frame:CreateTexture(nil,"ARTWORK")
        t:SetSize(54,54); t:SetPoint(c[1],0,0); t:SetTexture(c[2]); t:SetAlpha(.72)
    end
    AddGoldRule(frame,-76,28,-28)
end

local function AddTransmissionSeal(frame, x, y, icon)
    local ring=frame:CreateTexture(nil,"ARTWORK")
    ring:SetSize(54,54); ring:SetPoint("TOPLEFT",x,y)
    ring:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    ring:SetVertexColor(.74,.55,.23,.92)
    local tx=frame:CreateTexture(nil,"OVERLAY")
    tx:SetSize(38,38); tx:SetPoint("CENTER",ring,"CENTER",0,0)
    tx:SetTexture(icon or BOOK_ICON); tx:SetTexCoord(.08,.92,.08,.92)
    return tx
end

local function MakeTransmissionMovable(frame)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetScript("OnDragStart",function(self)
        if not self.isMoving then self:StartMoving(); self.isMoving=true end
    end)
    frame:SetScript("OnDragStop",function(self)
        if self.isMoving then self:StopMovingOrSizing(); self.isMoving=nil end
    end)
end

local TRANSMISSION_SEAL_ICON = "Interface\\AddOns\\Omega_Hub\\Modules\\GrimoireCraft\\Media\\ManuscriptSeal"

local TRANSMISSION_BACKDROP_CLOSED = "Interface\\AddOns\\Omega_Hub\\Modules\\GrimoireCraft\\Media\\TransmissionBackdropClosed"

local function ApplyTransmissionSkin(frame)
    -- v2.57.6: sender artwork cropped to the real gold frame; legacy top strip removed.
    -- The illustration itself IS the interface.
    -- Only dynamic data and invisible hit-zones are layered above it.
    frame:SetBackdrop(nil)
    local art=frame:CreateTexture(nil,"BACKGROUND",nil,-8)
    art:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    art:SetSize(900,544)
    art:SetTexture(TRANSMISSION_BACKDROP_CLOSED)
    -- Sender artwork is pre-fitted to the gold frame: there are no rendered pixels below it.
    art:SetTexCoord(0,900/1024,0,544/1024)
    frame.transmissionArt=art
    frame.transmissionMenuOpen=false
    function frame:SetTransmissionMenuOpen(open)
        self.transmissionMenuOpen = open and true or false
    end
end

local function CreateArtisanSelector(parent, x, y, width)
    width=width or 360
    -- v2.53: no visible widget chrome. The illustration supplies the frame.
    local selector=CreateFrame("Button",nil,parent)
    selector:SetSize(width,34); selector:SetPoint("TOPLEFT",x,y)
    local text=selector:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    text:SetPoint("LEFT",42,0); text:SetPoint("RIGHT",-28,0); text:SetJustifyH("LEFT"); text:SetTextColor(.93,.81,.58)
    selector.label=text
    -- No highlight texture here: the selector frame is already painted into the artwork.

    -- The dropdown list is also baked into the artwork; rows are transparent hit-zones + text only.
    local menu=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    menu:SetPoint("TOPLEFT",302,-279); menu:SetSize(292,238); menu:SetFrameStrata("TOOLTIP"); menu:SetFrameLevel(parent:GetFrameLevel()+30)
    -- Standalone dropdown only: opaque enough for names to read, with no duplicated illustration behind it.
    menu:SetBackdrop({
        bgFile="Interface\\Buttons\\WHITE8X8",
        edgeFile="Interface\\Buttons\\WHITE8X8",
        edgeSize=1,
    })
    menu:SetBackdropColor(.018,.022,.024,.97)
    menu:SetBackdropBorderColor(.63,.42,.12,.95)
    menu:Hide()
    selector.menu=menu

    function selector:SetDisplay(value) self.label:SetText(value or "Choisir un artisan…") end
    function selector:Rebuild(peers,onChoose)
        for _,child in ipairs({menu:GetChildren()}) do child:Hide(); child:SetParent(nil) end
        local rowH=40
        if #peers==0 then
            local empty=menu:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
            empty:SetPoint("TOPLEFT",18,-20); empty:SetText("Aucun grimoire n'a répondu au cercle."); empty:SetTextColor(.58,.50,.38)
            return
        end
        for i,peer in ipairs(peers) do
            if i>6 then break end
            local b=CreateFrame("Button",nil,menu); b:SetSize(270,rowH); b:SetPoint("TOPLEFT",8,-4-(i-1)*rowH)
            local rp=b:CreateFontString(nil,"OVERLAY","GameFontNormal"); rp:SetPoint("TOPLEFT",48,-5); rp:SetText(peer.rpName or peer.wowName); rp:SetTextColor(.96,.83,.58)
            local wow=b:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); wow:SetPoint("TOPLEFT",rp,"BOTTOMLEFT",0,-2); wow:SetText(peer.wowName or ""); wow:SetTextColor(.55,.49,.40)
            local icon=b:CreateTexture(nil,"OVERLAY"); icon:SetSize(30,30); icon:SetPoint("LEFT",9,0); icon:SetTexture(TRANSMISSION_SEAL_ICON); icon:SetTexCoord(0,1,0,1)
            local h=b:CreateTexture(nil,"HIGHLIGHT"); h:SetAllPoints(); h:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight"); h:SetBlendMode("ADD"); h:SetAlpha(.22)
            b:SetScript("OnClick",function()
                menu:Hide()
                if parent.SetTransmissionMenuOpen then parent:SetTransmissionMenuOpen(false) end
                if onChoose then onChoose(peer) end
            end)
        end
    end
    selector:SetScript("OnClick",function(self)
        local opening = not menu:IsShown()
        if opening then menu:Show() else menu:Hide() end
        if parent.SetTransmissionMenuOpen then parent:SetTransmissionMenuOpen(opening) end
    end)
    return selector
end

local function OpenTransferSender(recipe)
    -- La transmission concerne uniquement les recettes personnelles.
    -- Ouvre toujours une nouvelle fenêtre propre afin qu'un ancien frame caché ne bloque pas l'interaction.
    if not recipe then return end
    if recipe.official or recipe.isOfficialOverride then
        DEFAULT_CHAT_FRAME:AddMessage("|cffb8a36a[Grimoire]|r Seuls les savoirs personnels peuvent être transmis.")
        return
    end
    if UI.transferSender then UI.transferSender:Hide() UI.transferSender=nil end
    local f=CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
    UI.transferSender=f
    f:SetSize(900,544); f:SetPoint("CENTER"); f:SetFrameStrata("FULLSCREEN_DIALOG"); f:SetFrameLevel(50)
    f:EnableMouse(true); f:SetClampedToScreen(true)
    ApplyTransmissionSkin(f); MakeTransmissionMovable(f)
    f:Show()
    f:Raise()
    -- La fenêtre doit s'ouvrir même si l'annonce réseau/guilde rencontre un souci.
    if C_Timer and C_Timer.After then
        C_Timer.After(0,function() pcall(AnnounceGrimoirePresence) end)
    else
        pcall(AnnounceGrimoirePresence)
    end

    local function Hit(x,y,w,h,fn)
        local b=CreateFrame("Button",nil,f); b:SetPoint("TOPLEFT",x,y); b:SetSize(w,h); b:SetScript("OnClick",fn)
        -- Invisible hit-zone only; the artwork supplies the visual control.
        return b
    end

    -- Only dynamic information is drawn. All frames, buttons and ornaments come from the illustration.
    local ownRP=GetOwnRPName() or UnitName("player") or "Artisan"
    local sub=Label(f,"Extrait du grimoire de "..ownRP,350,-65,200,"GameFontHighlightSmall"); sub:SetJustifyH("CENTER"); sub:SetTextColor(.72,.62,.47)
    local icon=f:CreateTexture(nil,"OVERLAY"); icon:SetPoint("TOPLEFT",235,-110); icon:SetSize(52,52); icon:SetTexture(PROFESSION_ICONS[recipe.profession] or BOOK_ICON); icon:SetTexCoord(.08,.92,.08,.92)
    local rn=Label(f,recipe.name or "Recette sans nom",315,-108,330,"GameFontNormalLarge"); rn:SetTextColor(.98,.86,.60)
    local category=(recipe.category and recipe.category~="" and recipe.category) or "Savoir personnel"
    local meta=Label(f,"( "..(recipe.profession or "Artisanat").." )  -  ( "..category.." )",315,-137,330,"GameFontHighlightSmall"); meta:SetTextColor(.83,.73,.56); meta:SetWordWrap(true)
    local rank=Label(f,(recipe.profession or "Artisanat").."  •  "..(recipe.difficulty or "Savoir personnel"),315,-162,330,"GameFontHighlightSmall"); rank:SetTextColor(.68,.58,.44)

    f.selectedPeer=nil
    local selector=CreateArtisanSelector(f,244,-239,360)
    local function RefreshPeerText()
        if f.selectedPeer then selector:SetDisplay(f.selectedPeer.rpName or f.selectedPeer.wowName) else selector:SetDisplay("Choisir un artisan…") end
        selector:Rebuild(GetAvailablePeers(),function(peer) f.selectedPeer=peer; RefreshPeerText(); SetTransferStatus(f,"Le manuscrit sera confié à "..(peer.rpName or peer.wowName)..".",.76,.64,.42) end)
    end
    function f:RefreshPeerList(silent)
        RefreshPeerText()
        if not silent and #GetAvailablePeers()==0 then SetTransferStatus(f,"Recherche des grimoires connectés à la guilde…",.78,.67,.45) end
    end
    RefreshPeerText()
    AnnounceGrimoirePresence()
    if C_Timer and C_Timer.After then
        C_Timer.After(.35,function() if f:IsShown() then RefreshPeerText() end end)
        C_Timer.After(1.0,function() if f:IsShown() then RefreshPeerText() end end)
    end

    f.status=Label(f,"",260,-525,380,"GameFontHighlightSmall"); f.status:SetJustifyH("CENTER"); f.status:SetTextColor(.72,.61,.44)

    local function RefreshCircle()
        AnnounceGrimoirePresence(); SetTransferStatus(f,"Les grimoires du cercle sont interrogés…",.78,.67,.45)
        if C_Timer and C_Timer.After then
            C_Timer.After(.35,function() if f:IsShown() then RefreshPeerText() end end)
            C_Timer.After(1.0,function() if f:IsShown() then RefreshPeerText() end end)
            C_Timer.After(2.0,function() if f:IsShown() then RefreshPeerText() end end)
        else RefreshPeerText() end
    end
    local function SendSelected()
        local peer=f.selectedPeer
        if not peer then
            SetTransferStatus(f,"Aucun destinataire n'a encore été choisi.",1,.35,.25)
            return
        end
        local who=peer.wowName
        if not who or who=="" then
            SetTransferStatus(f,"Le destinataire sélectionné n'est plus disponible.",1,.35,.25)
            return
        end

        local payload=SerializePersonalRecipe(recipe)
        local token=tostring(time())..tostring(math.random(100,999))
        local total=math.max(1,math.ceil(#payload/TRANSFER_CHUNK_SIZE))
        UI.outgoingTransfers[token]={frame=f,target=who,targetRP=peer.rpName,recipeName=recipe.name or "Recette",total=total}

        -- Envoi fragmenté : évite de dépasser la limite des messages addon et laisse
        -- le temps au canal WHISPER addon d'absorber les recettes plus longues.
        local function SendChunk(i)
            if not f or not UI.outgoingTransfers[token] then return end
            local chunk=payload:sub((i-1)*TRANSFER_CHUNK_SIZE,i*TRANSFER_CHUNK_SIZE)
            SendTransferMessage(who,"OFFER;"..token..";"..i..";"..total..";"..chunk)
        end
        if C_Timer and C_Timer.After and total>1 then
            for i=1,total do
                local n=i
                C_Timer.After((n-1)*0.04,function() SendChunk(n) end)
            end
        else
            for i=1,total do SendChunk(i) end
        end

        SetTransferStatus(f,"Manuscrit envoyé à "..(peer.rpName or who)..". En attente de sa décision…",.86,.69,.35)
    end

    -- Invisible interaction zones aligned to the painted controls.
    Hit(625,-238,200,42,RefreshCircle)
    Hit(34,-472,240,55,SendSelected)
    Hit(638,-472,230,55,function() f:Hide() UI.transferSender=nil end)
    Hit(862,-3,25,25,function() f:Hide() UI.transferSender=nil end)
end

local RECEPTION_BACKDROP = "Interface\\AddOns\\Omega_Hub\\Modules\\GrimoireCraft\\Media\\ReceptionBackdrop"

local function ApplyReceptionSkin(frame)
    -- Dedicated reception artwork. This frame never reuses the sender artwork.
    frame:SetBackdrop(nil)
    local art=frame:CreateTexture(nil,"BACKGROUND",nil,-8)
    art:SetAllPoints(frame)
    art:SetTexture(RECEPTION_BACKDROP)
    art:SetTexCoord(0,1,0,683/1024)
    frame.receptionArt=art
end

local function OpenTransferReceiver(sender,token,recipe)
    local peer=GC_PEERS[sender]; local senderRP=(peer and peer.rpName) or GetTRPNameForUnitID(sender,sender)
    if UI.transferReceiver then UI.transferReceiver:Hide() UI.transferReceiver=nil end
    local f=CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
    UI.transferReceiver=f; f:SetSize(900,600); f:SetPoint("CENTER"); f:SetFrameStrata("FULLSCREEN_DIALOG"); ApplyReceptionSkin(f); MakeTransmissionMovable(f)

    local function Hit(x,y,w,h,fn)
        local b=CreateFrame("Button",nil,f); b:SetPoint("TOPLEFT",x,y); b:SetSize(w,h); b:SetScript("OnClick",fn)
        -- Intentionally no normal/highlight/pushed textures: painted artwork is the button.
        return b
    end
    local function Mask(x,y,w,h,a)
        local t=f:CreateTexture(nil,"ARTWORK"); t:SetPoint("TOPLEFT",x,y); t:SetSize(w,h)
        t:SetTexture("Interface\\Buttons\\WHITE8X8"); t:SetVertexColor(.025,.022,.018,a or .94); return t
    end

    -- Clear only the baked example data; fixed labels and decorative controls remain part of the artwork.

    local ownRP=GetOwnRPName() or UnitName("player") or "Artisan"
    local subtitle=Label(f,"Extrait du grimoire de "..ownRP,315,-79,270,"GameFontHighlightSmall"); subtitle:SetJustifyH("CENTER"); subtitle:SetTextColor(.76,.66,.50)
    local intro=Label(f,(senderRP or "Un artisan").." vous confie une copie de l'un de ses savoirs.",270,-116,410,"GameFontHighlightSmall"); intro:SetJustifyH("CENTER"); intro:SetTextColor(.80,.70,.53)

    local icon=f:CreateTexture(nil,"OVERLAY"); icon:SetPoint("TOPLEFT",247,-158); icon:SetSize(72,72); icon:SetTexture(PROFESSION_ICONS[recipe.profession] or BOOK_ICON); icon:SetTexCoord(.08,.92,.08,.92)
    local rn=Label(f,recipe.name or "Recette sans nom",340,-158,315,"GameFontNormalLarge"); rn:SetTextColor(.98,.82,.42)
    local category=(recipe.category and recipe.category~="" and recipe.category) or "Savoir personnel"
    local cat=Label(f,"( "..(recipe.profession or "Artisanat").." )  -  ( "..category.." )",340,-187,315,"GameFontHighlight"); cat:SetTextColor(.90,.80,.61); cat:SetWordWrap(true)
    local prof=Label(f,recipe.profession or "Artisanat",375,-221,125,"GameFontHighlight"); prof:SetTextColor(.85,.73,.54)
    local diff=Label(f,recipe.difficulty or "Savoir personnel",520,-221,125,"GameFontHighlight"); diff:SetTextColor(.85,.73,.54)

    local provenance=Label(f,senderRP or sender or "Artisan inconnu",334,-304,285,"GameFontNormal"); provenance:SetTextColor(.94,.79,.49)
    local provenanceSub=Label(f,"Personnage transmetteur",334,-324,285,"GameFontHighlightSmall"); provenanceSub:SetTextColor(.70,.60,.46)

    f.status=Label(f,"",275,-420,350,"GameFontHighlightSmall"); f.status:SetJustifyH("CENTER"); f.status:SetTextColor(.78,.62,.34)

    local function Accept()
        recipe.id=NewRecipeID(); recipe.official=nil; recipe.officialKey=nil; recipe.officialOverrideKey=nil; recipe.isOfficialOverride=nil
        recipe.source={kind="transmission",from=senderRP or sender or "Inconnu",rpName=senderRP or sender or "Inconnu",wowName=sender or "Inconnu",receivedAt=time(),originalName=recipe.name or ""}
        DB.recipes[#DB.recipes+1]=recipe; SendTransferMessage(sender,"ACK;"..token); f:Hide(); UI.transferReceiver=nil
        RefreshRecipeList(); DEFAULT_CHAT_FRAME:AddMessage("|cffb8a36a[Grimoire]|r Le savoir « "..(recipe.name or "Recette").." » a été inscrit dans votre grimoire.")
    end
    local function Decline() SendTransferMessage(sender,"DENY;"..token); f:Hide(); UI.transferReceiver=nil end

    -- Invisible hit zones aligned with the two painted reception buttons and close seal.
    Hit(45,-493,245,58,Accept)
    Hit(620,-493,240,58,Decline)
    Hit(866,-19,24,24,Decline)
end

local function HandleTransferMessage(message,sender)
    local kind,token,a,b,chunk=strsplit(";",message or "",5)
    if kind=="HELLO" then
        local rpName=UnescapeTransfer(token or sender or "Artisan")
        GC_PEERS[sender]={rpName=rpName,version=a or "?",seen=time()}
        if UI.transferSender and UI.transferSender:IsShown() and UI.transferSender.RefreshPeerList then UI.transferSender:RefreshPeerList(true) end
        -- Répondre discrètement afin que le nouvel arrivant découvre aussi les grimoires déjà connectés.
        if sender and NormalizePlayerName(sender)~=NormalizePlayerName(UnitName("player")) then
            local reply="HELLO;"..EscapeTransfer(GetOwnRPName())..";"..TRANSFER_VERSION
            SendTransferMessage(sender,reply)
        end
        return
    end
    if kind=="DBPUSH" then
        if IsDatabaseConservator(sender) then ShowDatabaseUpdateWindow(sender,token) end
        return
    elseif kind=="DBREQ" then
        if IsDatabaseConservator(UnitName("player")) then SendOfficialDatabaseTo(sender,token) end
        return
    elseif kind=="DBCHUNK" then
        if not IsDatabaseConservator(sender) then return end
        local index,total=tonumber(a),tonumber(b)
        if not token or not index or not total or total<1 or total>1000 then return end
        local t=UI.incomingDatabaseSync[token] or {sender=sender,total=total,chunks={}}
        UI.incomingDatabaseSync[token]=t
        if t.sender~=sender or t.total~=total then return end
        t.chunks[index]=chunk or ""
        local count=0; for i=1,total do if t.chunks[i] then count=count+1 end end
        if count==total then
            local payload=table.concat(t.chunks,"")
            UI.incomingDatabaseSync[token]=nil
            ApplyReceivedDatabase(sender,payload)
        end
        return
    end
    if kind=="OFFER" then
        local index,total=tonumber(a),tonumber(b)
        if not token or not index or not total then return end
        local t=UI.incomingTransfers[token] or {sender=sender,total=total,chunks={}}
        UI.incomingTransfers[token]=t; t.chunks[index]=chunk or ""
        local count=0; for i=1,total do if t.chunks[i] then count=count+1 end end
        if count==total then
            local payload=table.concat(t.chunks,""); UI.incomingTransfers[token]=nil
            local recipe=DeserializePersonalRecipe(payload)
            if recipe then OpenTransferReceiver(sender,token,recipe) end
        end
    elseif kind=="ACK" then
        local t=UI.outgoingTransfers[token]
        if t then SetTransferStatus(t.frame,t.target.." a consigné votre savoir dans son grimoire.",.45,.85,.48); UI.outgoingTransfers[token]=nil end
    elseif kind=="DENY" then
        local t=UI.outgoingTransfers[token]
        if t then SetTransferStatus(t.frame,t.target.." a décliné la transmission.",.85,.45,.35); UI.outgoingTransfers[token]=nil end
    end
end

local function EditBox(parent,x,y,width,height,value,numeric)
    local e=CreateFrame("EditBox",nil,parent,"InputBoxTemplate")
    e:SetPoint("TOPLEFT",x,y)
    e:SetSize(width,height or 24)
    e:SetAutoFocus(false)
    e:SetText(value or "")
    if numeric then e:SetNumeric(true) end
    return e
end

local function HideChildren(frame)
    for _, child in ipairs({frame:GetChildren()}) do
        child:Hide()
    end
end

local function GetItemData(itemID)
    itemID=tonumber(itemID)
    if not itemID then return nil,QUESTION_ICON end
    if C_Item and C_Item.RequestLoadItemDataByID then
        pcall(C_Item.RequestLoadItemDataByID,itemID)
    end
    local name,_,_,_,_,_,_,_,_,icon=GetItemInfo(itemID)
    return name,icon or QUESTION_ICON
end

local function AddItemTooltip(frame,itemID)
    itemID=tonumber(itemID)
    if not frame or not itemID then return end

    frame:EnableMouse(true)

    frame:SetScript("OnEnter",function(self)
        if C_Item and C_Item.RequestLoadItemDataByID then
            pcall(C_Item.RequestLoadItemDataByID,itemID)
        end

        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:"..itemID)
        GameTooltip:Show()
    end)

    frame:SetScript("OnLeave",function()
        GameTooltip:Hide()
    end)
end

local function RefreshItemDataForProfession(profession)
    -- Ask WoW/Epsilon to load every item used by this profession.
    for _, recipe in ipairs(DB.recipes) do
        if (recipe.profession or "Cuisinier") == profession then
            if recipe.outputItemID then
                GetItemData(recipe.outputItemID)
            end
            for _, material in ipairs(recipe.materials or {}) do
                if material.itemID then
                    GetItemData(material.itemID)
                end
            end
        end
    end

    -- Item data can arrive asynchronously after a /reload.
    -- Redraw a few times without touching saved data.
    if C_Timer and C_Timer.After then
        C_Timer.After(0.15, function()
            if UI.main and UI.main:IsShown() then
                RefreshRecipeList()
                RefreshDetails()
            end
        end)
        C_Timer.After(0.60, function()
            if UI.main and UI.main:IsShown() then
                RefreshRecipeList()
                RefreshDetails()
            end
        end)
        C_Timer.After(1.50, function()
            if UI.main and UI.main:IsShown() then
                RefreshRecipeList()
                RefreshDetails()
            end
        end)
    end
end

-- ============================================================================
-- FICHE RECETTE
-- ============================================================================


-- ============================================================================
-- LOCALISATION DES RESSOURCES : SACS / COFFRE DE GUILDE
-- ============================================================================
local GuildBankCache={}
local GuildBankScanned=false

local function GetBagItemCount(itemID)
    if C_Item and C_Item.GetItemCount then
        return C_Item.GetItemCount(itemID,false,false,false) or 0
    elseif GetItemCount then
        return GetItemCount(itemID,false,false) or 0
    end
    return 0
end

local function ScanGuildBank()
    wipe(GuildBankCache)
    if not GetNumGuildBankTabs or not GetGuildBankItemLink or not GetGuildBankItemInfo then
        GuildBankScanned=false
        return
    end

    local tabs=GetNumGuildBankTabs() or 0
    for tab=1,tabs do
        for slot=1,98 do
            local link=GetGuildBankItemLink(tab,slot)
            if link then
                local itemID=tonumber(link:match("item:(%d+)"))
                if itemID then
                    local _,count=GetGuildBankItemInfo(tab,slot)
                    GuildBankCache[itemID]=(GuildBankCache[itemID] or 0)+(tonumber(count) or 0)
                end
            end
        end
    end
    GuildBankScanned=true
end

local function GetGuildBankItemCount(itemID)
    return GuildBankCache[itemID] or 0
end

local function AddResourceLocationTooltip(frame,itemID)
    frame:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        GameTooltip:SetItemByID(itemID)

        local bagCount=GetBagItemCount(itemID)
        local guildCount=GetGuildBankItemCount(itemID)

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Disponibilité",.83,.69,.43)

        if bagCount>0 then
            GameTooltip:AddDoubleLine("Sacs",tostring(bagCount),1,1,1,.62,.78,.62)
        else
            GameTooltip:AddDoubleLine("Sacs","Aucun",.75,.75,.75,.90,.28,.28)
        end

        if GuildBankScanned then
            if guildCount>0 then
                GameTooltip:AddDoubleLine("Stockage du Campement",tostring(guildCount),1,1,1,.62,.78,.62)
            else
                GameTooltip:AddDoubleLine("Stockage du Campement","Aucun",.75,.75,.75,.90,.28,.28)
            end
        else
            GameTooltip:AddDoubleLine("Stockage du Campement","Non consulté",.75,.75,.75,.65,.55,.38)
            GameTooltip:AddLine("Ouvrez le Stockage du Campement une fois pour actualiser son contenu.",.55,.48,.38,true)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave",function() GameTooltip:Hide() end)
end


-- ============================================================================
-- FABRICATION CUISINE - PREMIER TEST
-- ============================================================================
local PendingCraft=nil

local function SendCraftChatCommand(text)
    if not text or text=="" then return end
    if ChatFrame_OpenChat then
        ChatFrame_OpenChat(text)
    end
end

local function GetRequiredBagCount(itemID)
    if C_Item and C_Item.GetItemCount then
        return C_Item.GetItemCount(itemID,false,false,false) or 0
    elseif GetItemCount then
        return GetItemCount(itemID,false,false) or 0
    end
    return 0
end

local function HasAllRecipeMaterialsInBags(recipe)
    for _,material in ipairs(recipe.materials or {}) do
        local needed=math.max(1,tonumber(material.quantity) or 1)
        if GetRequiredBagCount(material.itemID) < needed then
            return false,material
        end
    end
    return true,nil
end

local function GetWorkshopAlternativeStatus(workshop)
    if not workshop then return false,nil end
    if workshop.alternativeItems then
        for _,alt in ipairs(workshop.alternativeItems) do
            if GetRequiredBagCount(alt.itemID) > 0 then return true,alt.name end
        end
    end
    if workshop.alternativeItemSet then
        local names={}
        for _,alt in ipairs(workshop.alternativeItemSet) do
            if GetRequiredBagCount(alt.itemID) <= 0 then return false,nil end
            names[#names+1]=alt.name
        end
        return true,table.concat(names," + ")
    end
    return false,nil
end

local function HasProfessionConditions(recipe,workshopAvailable)
    local profession=(recipe and recipe.profession) or "Cuisinier"
    local rules=CRAFT_REQUIREMENTS[profession]
    if not rules then return true end

    if rules.workshop and rules.workshop.required and not workshopAvailable then
        local alternativeOK=GetWorkshopAlternativeStatus(rules.workshop)
        if not alternativeOK then return false,rules.workshop end
    end

    for _,requirement in ipairs(rules.tools or {}) do
        local ok=GetCraftToolStatus(requirement)
        local itemID=tonumber(requirement.itemID or requirement.id)

        -- Pour la Cuisine, l'Atelier de Cuisine Classique peut remplacer la Marmite.
        -- Les Ustensiles de Cuisine restent obligatoires.
        if profession=="Cuisinier" and workshopAvailable and itemID==14072838 then
            ok=true
        end

        if not ok then return false,requirement end
    end
    return true,nil
end

local function HasCuisineConditions(recipe,workshopAvailable)
    return HasProfessionConditions(recipe,workshopAvailable)
end

local function GetBagSlotsForItem(itemID)
    local found={}
    local firstBag=(Enum and Enum.BagIndex and Enum.BagIndex.Backpack) or 0
    local lastBag=(Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or 5

    for bag=firstBag,lastBag do
        local slots
        if C_Container and C_Container.GetContainerNumSlots then
            slots=C_Container.GetContainerNumSlots(bag) or 0
        elseif GetContainerNumSlots then
            slots=GetContainerNumSlots(bag) or 0
        else
            slots=0
        end

        for slot=1,slots do
            local info
            if C_Container and C_Container.GetContainerItemInfo then
                info=C_Container.GetContainerItemInfo(bag,slot)
                if info and info.itemID==itemID then
                    found[#found+1]={bag=bag,slot=slot,count=info.stackCount or 1}
                end
            elseif GetContainerItemID then
                local id=GetContainerItemID(bag,slot)
                if id==itemID then
                    local _,count=GetContainerItemInfo(bag,slot)
                    found[#found+1]={bag=bag,slot=slot,count=count or 1}
                end
            end
        end
    end
    return found
end

local function PickupBagItem(bag,slot)
    if C_Container and C_Container.PickupContainerItem then
        C_Container.PickupContainerItem(bag,slot)
    elseif PickupContainerItem then
        PickupContainerItem(bag,slot)
    end
end

local function DeleteOneRequiredStack(itemID,needed)
    local slots=GetBagSlotsForItem(itemID)
    for _,entry in ipairs(slots) do
        if needed>0 then
            -- Pour éviter de détruire plus que nécessaire, on ne supprime
            -- automatiquement qu'une pile dont la taille ne dépasse pas le besoin.
            -- Si la pile est plus grande, SplitContainerItem prépare exactement
            -- la quantité requise sur le curseur avant DeleteCursorItem.
            local take=math.min(needed,entry.count)

            if entry.count>take then
                if C_Container and C_Container.SplitContainerItem then
                    C_Container.SplitContainerItem(entry.bag,entry.slot,take)
                elseif SplitContainerItem then
                    SplitContainerItem(entry.bag,entry.slot,take)
                else
                    return false,"split"
                end
            else
                PickupBagItem(entry.bag,entry.slot)
            end

            if CursorHasItem and CursorHasItem() then
                DeleteCursorItem()
                return true,take
            end
        end
    end
    return false,"missing"
end

local function ContinueCraftConsumption()
    local craft=PendingCraft
    if not craft or craft.stage~="consume" then return end

    -- Attendre qu'une éventuelle confirmation native de suppression soit terminée.
    if StaticPopup1 and StaticPopup1:IsShown() then
        if C_Timer and C_Timer.After then C_Timer.After(.35,ContinueCraftConsumption) end
        return
    end
    if CursorHasItem and CursorHasItem() then
        if C_Timer and C_Timer.After then C_Timer.After(.35,ContinueCraftConsumption) end
        return
    end

    local material=craft.materials[craft.materialIndex]
    if not material then
        craft.stage="reward"
        local qty=math.max(1,tonumber(craft.outputQuantity) or 1)
        SendCraftChatCommand(".additem "..tostring(craft.outputItemID).." "..tostring(qty))
        DEFAULT_CHAT_FRAME:AddMessage("|cff9fbf9f[Grimoire]|r Fabrication validée. Commande d'ajout préparée.")
        PendingCraft=nil
        return
    end

    local remaining=material.remaining or math.max(1,tonumber(material.quantity) or 1)
    if remaining<=0 then
        craft.materialIndex=craft.materialIndex+1
        ContinueCraftConsumption()
        return
    end

    local ok,removed=DeleteOneRequiredStack(material.itemID,remaining)
    if not ok then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[Grimoire]|r Impossible de retirer automatiquement un composant. Fabrication interrompue.")
        PendingCraft=nil
        return
    end

    material.remaining=remaining-(tonumber(removed) or 0)
    if material.remaining<=0 then
        craft.materialIndex=craft.materialIndex+1
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(.45,ContinueCraftConsumption)
    else
        ContinueCraftConsumption()
    end
end

local function BeginCraftConsumption(recipe)
    if not PendingCraft then return end
    PendingCraft.stage="consume"
    PendingCraft.materials={}
    for _,m in ipairs(recipe.materials or {}) do
        PendingCraft.materials[#PendingCraft.materials+1]={
            itemID=m.itemID,
            quantity=math.max(1,tonumber(m.quantity) or 1),
            remaining=math.max(1,tonumber(m.quantity) or 1),
        }
    end
    PendingCraft.materialIndex=1
    ContinueCraftConsumption()
end

local function ResolveCuisineCraft(total)
    local craft=PendingCraft
    if not craft or craft.stage~="roll" then return end

    local recipe=FindRecipeByID(craft.recipeID)
    if not recipe then PendingCraft=nil return end

    local target=tonumber(recipe.difficultyMinimum) or 6
    local success=total>=target

    if craft.manualFlow and craft.assistant then
        local assistant=craft.assistant
        if success then
            if assistant.rewardButton then assistant.rewardButton:Enable() end
            DEFAULT_CHAT_FRAME:AddMessage("|cff9fbf9f[Grimoire]|r Réussite : "..total.." / "..target..". Supprimez les composants puis recevez l'objet.")
        else
            if (recipe.difficulty or "Mineur")=="Mineur" then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff6666[Grimoire]|r Échec : "..total.." / "..target..". Composants conservés.")
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cffff6666[Grimoire]|r Échec : "..total.." / "..target..". Supprimez les composants.")
            end
        end
        craft.stage="resolved"
        return
    end

    if success then
        DEFAULT_CHAT_FRAME:AddMessage("|cff9fbf9f[Grimoire]|r Réussite : "..total.." / "..target..". Consommation des composants.")
        BeginCraftConsumption(recipe)
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffff6666[Grimoire]|r Échec : "..total.." / "..target..".")
        if (recipe.difficulty or "Mineur")=="Mineur" then
            DEFAULT_CHAT_FRAME:AddMessage("|cffd7bd82[Grimoire]|r Difficulté Mineur : composants conservés.")
            PendingCraft=nil
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffd7bd82[Grimoire]|r Les composants sont perdus.")
            BeginCraftConsumption(recipe)
        end
    end
end



-- ============================================================================
-- FABRICATION CUISINE V3 - REBUILD COMPLET
-- Détection du jet par lecture des lignes réellement affichées dans le chat.
-- ============================================================================
local CraftV3=nil

local function V3SecureButton(parent,text,w,h)
    local b=CreateFrame("Button",nil,parent,"SecureActionButtonTemplate,BackdropTemplate")
    b:SetSize(w,h)
    ApplyBackdrop(b,.96)
    b:SetBackdropColor(.10,.065,.035,.96)
    b:SetBackdropBorderColor(.52,.36,.16,.92)
    b:SetAttribute("type","macro")
    b:SetAttribute("macrotext","")
    b:RegisterForClicks("AnyUp")
    local fs=b:CreateFontString(nil,"OVERLAY","GameFontNormal")
    fs:SetPoint("CENTER")
    fs:SetText(text or "")
    fs:SetTextColor(1.00,.91,.70)
    b.craftText=fs
    function b:SetCraftText(t) self.craftText:SetText(t or "") end
    return b
end

local function V3CleanChatText(text)
    text=tostring(text or "")
    text=text:gsub("|c%x%x%x%x%x%x%x%x","")
    text=text:gsub("|r","")
    text=text:gsub("|H.-|h(.-)|h","%1")
    text=text:gsub("\n"," ")
    return text
end

local function V3ExtractCraftTotal(text,profession)
    local clean=V3CleanChatText(text)
    profession=tostring(profession or "Cuisine")

    -- Les métiers actuellement pris en charge utilisent leur nom exact
    -- dans l'étiquette du jet Omega Dice.
    local tagPattern=tostring(profession or "Nature")
    if not clean:match("%[%s*"..tagPattern.."%s*%]") then return nil end

    local total=
        clean:match("%(%s*Total%s*:%s*([%-]?%d+)%s*%)%s*%[%s*"..tagPattern.."%s*%]") or
        clean:match("%[%s*Total%s*:%s*([%-]?%d+)%s*%]%s*%[%s*"..tagPattern.."%s*%]")

    return tonumber(total)
end

-- Une seule source de vérité pour le Rand de fabrication.
-- Les nouvelles recettes enregistrent difficultyMinimum.
-- Pour les anciennes recettes uniquement, on reconstruit depuis le rang.
local function V3RecipeTarget(recipe)
    if not recipe then return nil end

    local exact=tonumber(recipe.difficultyMinimum)
    if exact then return exact end

    local rank=recipe.difficulty
    if rank then
        for _,d in ipairs(CRAFT_DIFFICULTIES or {}) do
            if d.name==rank then return tonumber(d.minimum) end
        end
    end
    return nil
end

local CRAFT_ROLL_BY_PROFESSION = {
    ["Cuisinier"]="Nature",
    ["Cuisine"]="Nature",
    ["Alchimiste"]="Alchimie",
    ["Alchimie"]="Alchimie",
    ["Forge"]="Forge",
    ["Forgeron"]="Forge",
    ["Erudit"]="Savoir",
    ["Érudit"]="Savoir",
    ["Couture"]="Couture",
    ["Couturier"]="Couture",
    ["Ingénieur"]="Ingénierie",
    ["Ingenieur"]="Ingénierie",
    ["Tanneur"]="Artisanat",
}

local function V3RecipeProfession(recipe)
    if not recipe then return "Cuisinier" end
    return tostring(recipe.profession or recipe.category or recipe.trade or "Cuisinier")
end

local function V3RequiredRoll(recipe)
    local profession=V3RecipeProfession(recipe)
    return CRAFT_ROLL_BY_PROFESSION[profession]
end

local function V3State(text,r,g,b)
    local f=UI.craftV3
    if f and f.state then
        f.state:SetText(text or "")
        f.state:SetTextColor(r or .96,g or .86,b or .68)
    end
end

local function V3Close()
    if UI.craftV3 then
        UI.craftV3:SetScript("OnUpdate",nil)
        if UI.craftV3.veil then UI.craftV3.veil:Hide() end
        UI.craftV3:Hide()
        UI.craftV3=nil
    end
    CraftV3=nil
end

-- Le résultat n'est JAMAIS mémorisé comme "réussite" de manière libre.
-- Cette fonction recalcule systématiquement total >= target.
local function V3IsSuccess()
    local s=CraftV3
    if not s then return false end
    local total=tonumber(s.rollTotal)
    local target=tonumber(s.target)
    if target~=nil and target<=0 then return true end
    return total~=nil and target~=nil and total>=target
end

local function V3Finish()
    local s=CraftV3
    local f=UI.craftV3
    if not s or not f then return end

    -- HARD GATE : aucune commande d'ajout avant cette comparaison.
    f.action:SetAttribute("macrotext","")
    f.action:SetScript("PostClick",nil)

    local total=tonumber(s.rollTotal)
    local target=tonumber(s.target)
    local success=V3IsSuccess()

    f.action:Show()
    f.action:Enable()

    if success then
        if f.recipeWaiting then f.recipeWaiting:Hide() end
        f.action:SetCraftText("Achever la fabrication")
        f.action:SetAttribute("macrotext",".additem "..tostring(s.recipe.outputItemID).." 1")

        if not f.action.leftOrnament then
            local left=f.action:CreateTexture(nil,"ARTWORK")
            left:SetTexture("Interface\\COMMON\\Indicator-Yellow")
            left:SetSize(11,11)
            left:SetPoint("LEFT",18,0)
            f.action.leftOrnament=left

            local right=f.action:CreateTexture(nil,"ARTWORK")
            right:SetTexture("Interface\\COMMON\\Indicator-Yellow")
            right:SetSize(11,11)
            right:SetPoint("RIGHT",-18,0)
            f.action.rightOrnament=right
        end
        f.action.leftOrnament:Show()
        f.action.rightOrnament:Show()

        V3State("Réussite : "..total.." / "..target.." — fabrication autorisée.",.78,.94,.72)
        f.action:SetScript("PostClick",function()
            f.action:Disable()
            f.action:SetAttribute("macrotext","")
            f.action:SetCraftText("Fabrication terminée")
            if C_Timer and C_Timer.After then C_Timer.After(1,V3Close) end
        end)
    else
        if f.action.leftOrnament then f.action.leftOrnament:Hide() end
        if f.action.rightOrnament then f.action.rightOrnament:Hide() end

        f.action:SetCraftText("Fabrication refusée — refermer")
        f.action:SetAttribute("macrotext","")
        V3State("Vous échouez pitoyablement votre fabrication.  ("..tostring(total or "?").." / "..tostring(target or "?")..")",1,.58,.46)
        f.action:SetScript("PostClick",V3Close)
    end
end

local function V3Resume()
    local s=CraftV3
    local f=UI.craftV3
    if not s or not f then return end
    s.paused=false
    s.lastTick=GetTime()
    f.action:SetAttribute("macrotext","")
    f.action:Hide()
    V3State("La préparation prend forme...",.96,.84,.64)
end

local function V3MaterialStop(index)
    local s=CraftV3
    local f=UI.craftV3
    if not s or not f then return end
    local m=s.materials[index]
    if not m then return end

    s.paused=true
    local qty=math.max(1,tonumber(m.quantity) or 1)
    local name=GetItemData(m.itemID) or ("Objet #"..tostring(m.itemID))

    if f.recipeWaiting then f.recipeWaiting:Hide() end
    if f.materialLines[index] then
        local line=f.materialLines[index]
        line:SetText(qty.." × "..name.."  - à incorporer")
        line:SetTextColor(1,.88,.60)
        line:Show()
        if line.craftIcon then line.craftIcon:Show() end
    end

    -- Sur réussite OU échec non-mineur : composants consommés.
    -- Sur échec mineur : cette étape n'est jamais atteinte.
    local failedCraft=not V3IsSuccess()
    if failedCraft then
        f.action:SetCraftText("Ajout maladroit : "..qty.." × "..name)
        V3State("Dans la précipitation, vous ajoutez maladroitement "..qty.." × "..name..".",1,.68,.48)
    else
        f.action:SetCraftText("Incorporer "..qty.." × "..name)
        V3State("Incorporer "..qty.." × "..name..".",1,.86,.60)
    end

    f.action:SetAttribute("macrotext",".additem "..tostring(m.itemID).." -"..tostring(qty))
    f.action:Show()
    f.action:Enable()

    f.action:SetScript("PostClick",function()
        f.action:SetAttribute("macrotext","")
        if f.materialLines[index] then
            local line=f.materialLines[index]
            if failedCraft then
                line:SetText(qty.." × "..name.."  — incorporation maladroite")
                line:SetTextColor(1,.66,.46)
            else
                line:SetText(qty.." × "..name)
                line:SetTextColor(.96,.84,.64)
            end
            line:Show()
            if line.craftIcon then line.craftIcon:Show() end
        end
        s.nextMaterial=index+1
        V3Resume()
    end)
end

local function V3BeginChannel()
    local s=CraftV3
    local f=UI.craftV3
    if not s or not f then return end

    f.roll:Hide()

    local success=V3IsSuccess()
    local isMinor=((s.recipe.difficulty or "Mineur")=="Mineur")

    -- Échec mineur : aucun composant perdu, aucun canal de suppression.
    if not success and isMinor then
        f.bar:SetValue(10)
        f.barText:SetText("Échec mineur")
        V3Finish()
        return
    end

    -- Réussite ou échec > Mineur : la confection déroule les composants.
    s.elapsed=0
    s.lastTick=GetTime()
    s.nextMaterial=1
    s.paused=false
    V3State(success and "Jet réussi — confection en cours..." or "Jet échoué — les composants seront perdus...", success and .78 or 1, success and .94 or .60, success and .72 or .48)
end

local function V3Resolve(total)
    local s=CraftV3
    if not s or not s.waitingRoll or s.rollResolved then return end

    total=tonumber(total)
    if not total then return end

    -- Le target a été figé à l'ouverture depuis LA RECETTE.
    local target=tonumber(s.target)
    if not target then
        s.waitingRoll=false
        s.rollResolved=true
        s.rollTotal=total
        V3State("Erreur : aucun Rand de fabrication valide n'est attribué à cette recette.",1,.35,.30)
        s.forceFailure=true
        V3Finish()
        return
    end

    s.rollTotal=total
    s.rollResolved=true
    s.waitingRoll=false

    if V3IsSuccess() then
        V3State("Jet reconnu : "..total.." / "..target.." — réussite.",.78,.94,.72)
    else
        V3State("Jet reconnu : "..total.." / "..target.." — échec.",1,.58,.46)
    end

    V3BeginChannel()
end

local function V3TryReadRollLine(text)
    local s=CraftV3
    if not s or not s.waitingRoll or s.rollResolved then return false end
    local total=V3ExtractCraftTotal(text,s.rollType)
    if total~=nil then
        V3Resolve(total)
        return true
    end
    return false
end

local function V3SnapshotChat()
    local snap={}
    for i=1,(NUM_CHAT_WINDOWS or 10) do
        local cf=_G["ChatFrame"..i]
        if cf and cf.GetNumMessages then
            snap[i]=cf:GetNumMessages() or 0
        end
    end
    return snap
end

local function V3ScanNewChatLines()
    local s=CraftV3
    if not s or not s.waitingRoll or s.rollResolved then return end

    for i=1,(NUM_CHAT_WINDOWS or 10) do
        local cf=_G["ChatFrame"..i]
        if cf and cf.GetNumMessages and cf.GetMessageInfo then
            local count=cf:GetNumMessages() or 0
            local previous=(s.chatSnapshot and s.chatSnapshot[i]) or count
            for n=previous+1,count do
                local text=cf:GetMessageInfo(n)
                if V3TryReadRollLine(text) then return end
            end
            if s.chatSnapshot then s.chatSnapshot[i]=count end
        end
    end
end

local V3ChatHooksInstalled=false
local function V3InstallChatHooks()
    if V3ChatHooksInstalled then return end
    V3ChatHooksInstalled=true
    for i=1,(NUM_CHAT_WINDOWS or 10) do
        local cf=_G["ChatFrame"..i]
        if cf and cf.AddMessage then
            hooksecurefunc(cf,"AddMessage",function(_,text)
                V3TryReadRollLine(text)
            end)
        end
    end
end

local function V3Open(recipe,natureModifier,selectedRollType,workshopAvailable)
    if CraftV3 then return end
    V3InstallChatHooks()

    local target=V3RecipeTarget(recipe)
    local profession=V3RecipeProfession(recipe)

    local allowedRollTypes={
        ["Nature"]=true, ["Alchimie"]=true, ["Forge"]=true, ["Couture"]=true,
        ["Ingénierie"]=true, ["Savoir"]=true, ["Artisanat"]=true,
    }
    local requiredRoll=V3RequiredRoll(recipe)
    local rollType=tostring(selectedRollType or requiredRoll or "Nature")
    if not allowedRollTypes[rollType] then
        rollType=requiredRoll or "Nature"
    end

    if not requiredRoll or rollType~=requiredRoll then
        print("|cffff5555GrimoireCraft : cette fabrication exige un jet de "..requiredRoll..".|r")
        return
    end

    local materialsOK=HasAllRecipeMaterialsInBags(recipe)

    -- Conditions d'outils et d'installation définies métier par métier.
    local toolsOK=HasProfessionConditions(recipe,workshopAvailable)

    if not materialsOK or not toolsOK or not recipe.outputItemID then return end

    -- Une recette sans seuil n'est pas fabricable.
    if not target then
        print("|cffff5555GrimoireCraft : cette recette n'a aucun Rand de fabrication valide.|r")
        return
    end

    local veil=CreateFrame("Frame",nil,UIParent)
    veil:SetAllPoints(UIParent)
    veil:SetFrameStrata("DIALOG")
    veil:SetFrameLevel(700)
    veil:EnableMouse(true)
    local shade=veil:CreateTexture(nil,"BACKGROUND")
    shade:SetAllPoints()
    shade:SetColorTexture(0,0,0,.40)

    local f=CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
    UI.craftV3=f
    f.veil=veil
    f:SetSize(620,430)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(710)
    ApplyBackdrop(f,.995)
    f:SetBackdropColor(.025,.016,.010,.995)
    f:SetBackdropBorderColor(.60,.42,.19,.98)

    local page=CreateFrame("Frame",nil,f,"BackdropTemplate")
    page:SetPoint("TOPLEFT",18,-18)
    page:SetPoint("BOTTOMRIGHT",-18,18)
    page:SetFrameStrata(f:GetFrameStrata())
    page:SetFrameLevel(math.max(0,f:GetFrameLevel()-1))
    ApplyBackdrop(page,.96)
    page:SetBackdropColor(.090,.057,.030,.88)
    page:SetBackdropBorderColor(.48,.33,.14,.88)

    -- Cadre enluminé conservé depuis la V2.30.
    local function DecoLine(parent,layer,sublevel,w,h,point,rel,relPoint,x,y,r,g,b,a)
        local t=parent:CreateTexture(nil,layer,nil,sublevel)
        t:SetTexture("Interface\\Buttons\\WHITE8X8")
        t:SetSize(w,h); t:SetPoint(point,rel,relPoint,x,y)
        t:SetVertexColor(r,g,b); t:SetAlpha(a or 1)
        return t
    end
    DecoLine(page,"ARTWORK",0,548,2,"TOP",page,"TOP",0,-8,.78,.52,.20,.92)
    DecoLine(page,"ARTWORK",0,548,2,"BOTTOM",page,"BOTTOM",0,8,.78,.52,.20,.92)
    DecoLine(page,"ARTWORK",0,2,332,"LEFT",page,"LEFT",8,0,.78,.52,.20,.92)
    DecoLine(page,"ARTWORK",0,2,332,"RIGHT",page,"RIGHT",-8,0,.78,.52,.20,.92)
    DecoLine(page,"ARTWORK",0,532,1,"TOP",page,"TOP",0,-14,.39,.23,.08,.95)
    DecoLine(page,"ARTWORK",0,532,1,"BOTTOM",page,"BOTTOM",0,14,.39,.23,.08,.95)
    DecoLine(page,"ARTWORK",0,1,316,"LEFT",page,"LEFT",14,0,.39,.23,.08,.95)
    DecoLine(page,"ARTWORK",0,1,316,"RIGHT",page,"RIGHT",-14,0,.39,.23,.08,.95)

    local cornerData={{"TOPLEFT",18,-18},{"TOPRIGHT",-18,-18},{"BOTTOMLEFT",18,18},{"BOTTOMRIGHT",-18,18}}
    for _,c in ipairs(cornerData) do
        local outer=page:CreateTexture(nil,"ARTWORK",nil,2)
        outer:SetTexture("Interface\\Buttons\\WHITE8X8")
        outer:SetSize(30,30); outer:SetPoint(c[1],page,c[1],c[2],c[3])
        outer:SetVertexColor(.46,.25,.075); outer:SetRotation(math.rad(45))
        local middle=page:CreateTexture(nil,"ARTWORK",nil,3)
        middle:SetTexture("Interface\\Buttons\\WHITE8X8")
        middle:SetSize(21,21); middle:SetPoint("CENTER",outer)
        middle:SetVertexColor(.84,.55,.18); middle:SetRotation(math.rad(45))
        local core=page:CreateTexture(nil,"ARTWORK",nil,4)
        core:SetTexture("Interface\\COMMON\\Indicator-Yellow")
        core:SetSize(10,10); core:SetPoint("CENTER",outer); core:SetAlpha(.92)
    end

    local close=CreateFrame("Button",nil,f,"UIPanelCloseButton")
    close:SetPoint("TOPRIGHT",-7,-7)
    close:SetScript("OnClick",V3Close)

    local title=Label(f,"L'ATELIER DE L'ARTISAN",0,-24,620,"QuestFont_Huge")
    title:SetJustifyH("CENTER"); title:SetDrawLayer("OVERLAY",7)
    title:SetTextColor(1,.92,.68)

    local rn=Label(f,recipe.name or "Recette",0,-53,620,"GameFontHighlight")
    rn:SetJustifyH("CENTER"); rn:SetDrawLayer("OVERLAY",7)
    rn:SetTextColor(1,.86,.64)

    local threshold=Label(f,"Rand de fabrication : "..target,0,-76,620,"GameFontHighlightSmall")
    threshold:SetJustifyH("CENTER"); threshold:SetDrawLayer("OVERLAY",7)
    threshold:SetTextColor(.95,.72,.38)

    local barBG=CreateFrame("Frame",nil,f,"BackdropTemplate")
    barBG:SetFrameStrata(f:GetFrameStrata()); barBG:SetFrameLevel(f:GetFrameLevel()+2)
    barBG:SetPoint("TOPLEFT",65,-103); barBG:SetSize(490,33)
    ApplyBackdrop(barBG,.98)
    barBG:SetBackdropColor(.035,.025,.016,.98)
    barBG:SetBackdropBorderColor(.40,.29,.14,.90)

    local bar=CreateFrame("StatusBar",nil,barBG)
    bar:SetPoint("TOPLEFT",3,-3); bar:SetPoint("BOTTOMRIGHT",-3,3)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0,10); bar:SetValue(0); f.bar=bar

    local bt=bar:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    bt:SetPoint("CENTER"); bt:SetText("En attente du jet"); f.barText=bt

    local state=Label(f,"Le Rand doit être égal ou supérieur à "..target..".",45,-151,530,"GameFontHighlightSmall")
    state:SetJustifyH("CENTER"); state:SetWordWrap(true); state:SetDrawLayer("OVERLAY",7)
    state:SetTextColor(1,.91,.72); f.state=state

    local listTitle=Label(f,"—  FEUILLET DE CONFECTION  —",55,-188,510,"QuestFont_Large")
    listTitle:SetJustifyH("CENTER"); listTitle:SetDrawLayer("OVERLAY",7)
    listTitle:SetTextColor(1,.87,.58)

    local manuscript=CreateFrame("Frame",nil,f,"BackdropTemplate")
    manuscript:SetPoint("TOPLEFT",68,-214); manuscript:SetSize(484,112)
    manuscript:SetFrameStrata(f:GetFrameStrata()); manuscript:SetFrameLevel(f:GetFrameLevel()+1)
    ApplyBackdrop(manuscript,.55)
    manuscript:SetBackdropColor(.050,.031,.016,.68)
    manuscript:SetBackdropBorderColor(.38,.27,.12,.55)

    local waiting=Label(manuscript,"Les ingrédients seront consignés ici au fil de la préparation…",18,-17,448,"GameFontHighlightSmall")
    waiting:SetJustifyH("CENTER"); waiting:SetTextColor(.90,.80,.64); f.recipeWaiting=waiting

    f.materialLines={}
    local y=-16
    for i,m in ipairs(recipe.materials or {}) do
        local qty=math.max(1,tonumber(m.quantity) or 1)
        local name=GetItemData(m.itemID) or ("Objet #"..tostring(m.itemID))
        local icon=manuscript:CreateTexture(nil,"ARTWORK")
        icon:SetTexture("Interface\\COMMON\\Indicator-Yellow")
        icon:SetSize(12,12); icon:SetPoint("TOPLEFT",17,y+1); icon:Hide()
        local line=Label(manuscript,"",38,y,414,"GameFontHighlightSmall")
        line:SetTextColor(.98,.84,.62); line:SetWordWrap(true); line:Hide()
        line.craftIcon=icon; f.materialLines[i]=line
        y=y-27
    end

    local mod=tonumber(natureModifier) or 0
    mod=math.floor(mod)
    if mod>20 then mod=20 elseif mod<-20 then mod=-20 end
    local modifier=(mod>0 and ("+"..mod)) or (mod<0 and tostring(mod)) or ""

    local roll=V3SecureButton(f,"Effectuer le jet",210,34)
    roll:SetPoint("BOTTOM",0,62)
    roll:SetAttribute("macrotext","/rd 1d20"..modifier.." "..rollType)
    f.roll=roll

    local action=V3SecureButton(f,"Incorporer le composant",300,34)
    action:SetPoint("BOTTOM",0,22); action:Hide(); f.action=action

    CraftV3={
        recipe=recipe,
        materials=recipe.materials or {},
        profession=profession,
        rollType=rollType,
        target=target,                 -- FIGÉ depuis la recette
        modifier=mod,
        waitingRoll=false,
        rollResolved=false,
        rollTotal=nil,
        paused=false,
        chatSnapshot=V3SnapshotChat(),
    }

    roll:SetScript("PreClick",function()
        local s=CraftV3
        if not s or s.rollResolved then return end
        s.chatSnapshot=V3SnapshotChat()
        s.waitingRoll=true
        V3State("Résolution du jet... seuil requis : "..s.target..".",.92,.78,.52)
    end)
    roll:SetScript("PostClick",function()
        roll:Disable()
        roll:SetCraftText("Rand lancé")
    end)

    f:SetScript("OnUpdate",function(self)
        local s=CraftV3
        if not s then return end

        if s.waitingRoll then
            V3ScanNewChatLines()
            return
        end

        if not s.rollResolved or s.paused or s.elapsed==nil then return end

        local now=GetTime()
        local dt=now-(s.lastTick or now)
        s.lastTick=now
        s.elapsed=math.min(10,s.elapsed+dt)
        self.bar:SetValue(s.elapsed)
        self.barText:SetText(string.format("%.1f / 10 s",s.elapsed))

        local n=#s.materials
        if s.nextMaterial<=n then
            local stop=(10/(n+1))*s.nextMaterial
            if s.elapsed>=stop then
                V3MaterialStop(s.nextMaterial)
                return
            end
        end

        if s.elapsed>=10 then
            s.elapsed=nil
            self.bar:SetValue(10)
            self.barText:SetText(V3IsSuccess() and "Confection réussie" or "Confection échouée")
            V3Finish()
        end
    end)
end

local function CreateCraftAssistant(recipe,natureBonus)
    if UI.craftAssistant then
        UI.craftAssistant:Hide()
        UI.craftAssistant=nil
    end

    local f=CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
    UI.craftAssistant=f
    f:SetSize(560,430)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(500)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",f.StartMoving)
    f:SetScript("OnDragStop",f.StopMovingOrSizing)
    ApplyBackdrop(f,.995)
    f:SetBackdropColor(.025,.017,.012,.995)
    f:SetBackdropBorderColor(.52,.36,.16,.98)

    local veil=CreateFrame("Frame",nil,UIParent)
    veil:SetAllPoints(UIParent)
    veil:SetFrameStrata("DIALOG")
    veil:SetFrameLevel(490)
    veil:EnableMouse(true)
    local shade=veil:CreateTexture(nil,"BACKGROUND")
    shade:SetAllPoints()
    shade:SetColorTexture(0,0,0,.48)
    f.veil=veil

    local function CloseAssistant()
        if f.veil then f.veil:Hide() end
        f:Hide()
        if UI.craftAssistant==f then UI.craftAssistant=nil end
    end

    local close=CreateFrame("Button",nil,f,"UIPanelCloseButton")
    close:SetPoint("TOPRIGHT",-7,-7)
    close:SetScript("OnClick",CloseAssistant)

    local title=Label(f,"Rituel de Fabrication",0,-18,560,"QuestFont_Huge")
    title:SetJustifyH("CENTER")
    title:SetTextColor(.84,.69,.42)
    title:SetShadowColor(.02,.01,.01,.95)
    title:SetShadowOffset(1,-2)

    local sub=Label(f,recipe.name or "Recette",0,-50,560,"GameFontHighlight")
    sub:SetJustifyH("CENTER")
    sub:SetTextColor(.62,.50,.32)
    AddGoldRule(f,-74,115,-115)

    local sheet=CreateFrame("Frame",nil,f,"BackdropTemplate")
    sheet:SetPoint("TOPLEFT",26,-92)
    sheet:SetPoint("BOTTOMRIGHT",-26,58)
    ApplyBackdrop(sheet,.97)
    sheet:SetBackdropColor(.090,.066,.041,.98)
    sheet:SetBackdropBorderColor(.34,.24,.12,.92)
    AddPaperTexture(sheet,.98)
    AddPageWear(sheet)

    -- Zone défilante : même avec beaucoup de composants, rien ne sort du parchemin.
    local craftScroll=CreateFrame("ScrollFrame",nil,sheet,"UIPanelScrollFrameTemplate")
    craftScroll:SetPoint("TOPLEFT",10,-10)
    craftScroll:SetPoint("BOTTOMRIGHT",-30,10)
    craftScroll:EnableMouseWheel(true)

    local craftContent=CreateFrame("Frame",nil,craftScroll)
    craftContent:SetSize(474,1)
    craftScroll:SetScrollChild(craftContent)

    craftScroll:SetScript("OnMouseWheel",function(self,delta)
        local current=self:GetVerticalScroll() or 0
        local maxScroll=self:GetVerticalScrollRange() or 0
        self:SetVerticalScroll(math.max(0,math.min(maxScroll,current-(delta*38))))
    end)

    local target=tonumber(recipe.difficultyMinimum) or 6
    local diff=Label(craftContent,"Difficulté : "..(recipe.difficulty or "Mineur").."   •   Rand de fabrication : "..target,10,-8,445,"GameFontNormal")
    diff:SetTextColor(.42,.29,.15)

    local step1=Label(craftContent,"I. Le jet",20,-52,470,"QuestFont_Large")
    step1:SetTextColor(.30,.20,.11)

    local bonus=tonumber(natureBonus) or 0
    local modifier=(bonus>0 and ("+"..bonus)) or (bonus<0 and tostring(bonus)) or ""
    local rollPreview=Label(craftContent,"/rd 1d20"..modifier.." Cuisine",32,-82,300,"GameFontHighlight")
    rollPreview:SetTextColor(.76,.65,.46)

    local rollBtn=Button(craftContent,"Lancer le jet",130,28)
    rollBtn:SetPoint("TOPRIGHT",craftContent,"TOPRIGHT",-14,-60)

    local step2=Label(craftContent,"II. Les composants",20,-124,470,"QuestFont_Large")
    step2:SetTextColor(.30,.20,.11)

    local materialFrames={}
    local my=-154
    for _,m in ipairs(recipe.materials or {}) do
        local itemName=GetItemData(m.itemID) or ("Objet #"..tostring(m.itemID))
        local have=GetRequiredBagCount(m.itemID)
        local need=math.max(1,tonumber(m.quantity) or 1)

        local row=CreateFrame("Frame",nil,craftContent,"BackdropTemplate")
        row:SetPoint("TOPLEFT",28,my)
        row:SetSize(445,31)
        ApplyBackdrop(row,.55)
        row:SetBackdropColor(.045,.032,.020,.82)
        row:SetBackdropBorderColor(.34,.24,.12,.50)

        local text=Label(row,need.." × "..itemName.."   ["..have.." dans les sacs]",8,-8,335,"GameFontHighlightSmall")
        text:SetTextColor(have>=need and .82 or .92, have>=need and .78 or .25, have>=need and .68 or .22)

        local remove=Button(row,"Supprimer",82,23)
        remove:SetPoint("RIGHT",-5,0)
        remove:SetScript("OnClick",function()
            local ok,amount=DeleteOneRequiredStack(m.itemID,need)
            if not ok then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[Grimoire]|r Impossible de préparer la suppression de "..itemName..".")
                return
            end
            if C_Timer and C_Timer.After then
                C_Timer.After(.35,function()
                    if f:IsShown() then
                        local now=GetRequiredBagCount(m.itemID)
                        text:SetText(need.." × "..itemName.."   ["..now.." dans les sacs]")
                    end
                end)
            end
        end)
        AddItemTooltip(row,m.itemID)
        materialFrames[#materialFrames+1]=row
        my=my-35
    end

    local step3Y=math.max(-286,my-8)
    local step3=Label(craftContent,"III. Finaliser",20,step3Y,470,"QuestFont_Large")
    step3:SetTextColor(.30,.20,.11)

    local finalInfo=Label(craftContent,"Après le résultat du jet et la suppression des composants,\nvalidez la réception de l'objet fabriqué.",32,step3Y-30,320,"GameFontHighlightSmall")
    finalInfo:SetTextColor(.66,.59,.48)
    finalInfo:SetWordWrap(true)

    local rewardBtn=Button(craftContent,"Recevoir l'objet",135,28)
    rewardBtn:SetPoint("TOPRIGHT",craftContent,"TOPRIGHT",-14,step3Y-28)
    rewardBtn:Disable()

    rollBtn:SetScript("OnClick",function()
        local rollText="/rd 1d20"..modifier.." Cuisine"
        PendingCraft={
            recipeID=recipe.id,
            stage="roll",
            profession="Cuisine",
            outputItemID=recipe.outputItemID,
            outputQuantity=1,
            assistant=f,
            manualFlow=true,
        }
        local rollArgs="1d20"..modifier.." Cuisine"
        if SlashCmdList and SlashCmdList["RD"] then
            SlashCmdList["RD"](rollArgs)
        elseif ChatFrame_OpenChat then
            ChatFrame_OpenChat(rollText)
            if ChatEdit_SendText and ChatEdit_GetActiveWindow then
                local editBox=ChatEdit_GetActiveWindow()
                if editBox then ChatEdit_SendText(editBox,0) end
            end
        end
        rollBtn:Disable()
        rollBtn:SetText("Jet lancé")
    end)

    rewardBtn:SetScript("OnClick",function()
        if recipe.outputItemID then
            local addText=".additem "..tostring(recipe.outputItemID).." 1"
            if C_ChatInfo and C_ChatInfo.SendChatMessage then
                C_ChatInfo.SendChatMessage(addText,"SAY")
            elseif SendChatMessage then
                SendChatMessage(addText,"SAY")
            else
                SendCraftChatCommand(addText)
            end
        end
        CloseAssistant()
    end)

    craftContent:SetHeight(math.max(330,math.abs(step3Y)+105))

    f.rewardButton=rewardBtn
    f.rollButton=rollBtn
    f.CloseAssistant=CloseAssistant
    f:Show()
end

local function StartCuisineCraft(recipe,natureBonus)
    if PendingCraft then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff6666[Grimoire]|r Une fabrication est déjà en attente.")
        return
    end

    local materialsOK,missing=HasAllRecipeMaterialsInBags(recipe)
    if not materialsOK then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff6666[Grimoire]|r Composants insuffisants dans les sacs.")
        return
    end

    local toolsOK=HasCuisineConditions()
    if not toolsOK then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff6666[Grimoire]|r Conditions de Cuisine non remplies.")
        return
    end

    if not recipe.outputItemID then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff6666[Grimoire]|r Aucun ID d'objet fabriqué n'est défini.")
        return
    end

    local bonus=tonumber(natureBonus) or 0
    local modifier=""
    if bonus>0 then modifier="+"..bonus
    elseif bonus<0 then modifier=tostring(bonus) end

    PendingCraft={
        recipeID=recipe.id,
        stage="roll",
        profession="Cuisine",
        outputItemID=recipe.outputItemID,
        outputQuantity=1,
    }

    -- /rd est un slash-command : l'envoyer dans le canal de saisie permet
    -- au client/serveur RP de l'interpréter exactement comme une saisie joueur.
    -- Lance uniquement la commande de jet, sans message Grimoire supplémentaire.
    local rollText="/rd 1d20"..modifier.." Cuisine"

    if ChatFrame_OpenChat then
        ChatFrame_OpenChat(rollText)
        if ChatEdit_SendText and ChatEdit_GetActiveWindow then
            local editBox=ChatEdit_GetActiveWindow()
            if editBox then
                ChatEdit_SendText(editBox,0)
            end
        end
    else
        PendingCraft=nil
        return
    end
end

local function ParseCuisineRollMessage(message)
    if not PendingCraft or PendingCraft.stage~="roll" then return end
    if type(message)~="string" then return end
    if not message:find("%[ Cuisine %]") and not message:find("%[Cuisine%]") then return end

    local total=message:match("%(%s*Total%s*:%s*([%-]?%d+)%s*%)")
    total=tonumber(total)
    if total then ResolveCuisineCraft(total) end
end

RefreshDetails=function()
    if not UI.detailContent then return end
    HideChildren(UI.detailContent)

    local recipe=UI.selectedRecipeID and FindRecipeByID(UI.selectedRecipeID)
    if not recipe then
        return
    end

    -- Fiche sélectionnée défilante : la recette reste contenue dans la page,
    -- même avec beaucoup de conditions et de composants.
    local detailScroll=CreateFrame("ScrollFrame",nil,UI.detailContent,"UIPanelScrollFrameTemplate")
    detailScroll:SetPoint("TOPLEFT",8,-8)
    detailScroll:SetPoint("BOTTOMRIGHT",-28,8)
    detailScroll:EnableMouseWheel(true)

    local page=CreateFrame("Frame",nil,detailScroll)
    page:SetSize(390,1)
    detailScroll:SetScrollChild(page)

    detailScroll:SetScript("OnMouseWheel",function(self,delta)
        local current=self:GetVerticalScroll() or 0
        local maximum=self:GetVerticalScrollRange() or 0
        self:SetVerticalScroll(math.max(0,math.min(maximum,current-(delta*42))))
    end)

    local ornament=Label(page,"Recette",0,-10,420,"QuestFont_Large")
    ornament:SetJustifyH("CENTER")
    ornament:SetTextColor(.34,.23,.12)
    AddGoldRule(page,-36,30,-30)

    local productName,productIcon=GetItemData(recipe.outputItemID)
    local icon=page:CreateTexture(nil,"ARTWORK")
    icon:SetSize(58,58)
    icon:SetPoint("TOPLEFT",14,-52)
    icon:SetTexture(productIcon or BOOK_ICON)

    local title=Label(page,recipe.name or "Recette sans nom",82,-55,300,"QuestFont_Large")
    title:SetWordWrap(true)
    title:SetTextColor(THEME.goldBright[1],THEME.goldBright[2],THEME.goldBright[3])

    local prof=Label(page,recipe.profession or "Cuisinier",82,-88,300,"GameFontHighlightSmall")
    prof:SetWordWrap(true)

    local difficultyName=recipe.difficulty or "Mineur"
    local difficultyMinimum=recipe.difficultyMinimum
    if not difficultyMinimum then
        for _,data in ipairs(CRAFT_DIFFICULTIES) do
            if data.name==difficultyName then difficultyMinimum=data.minimum break end
        end
    end
    difficultyMinimum=difficultyMinimum or 6

    local diff=Label(page,"Difficulté : "..difficultyName.."  •  Rand de fabrication : "..difficultyMinimum,82,-108,300,"GameFontNormal")
    diff:SetTextColor(.67,.47,.22)
    diff:SetWordWrap(true)
    prof:SetTextColor(.38,.29,.20)

    if recipe.outputItemID then
        local line=Label(page,(productName or ("Objet #"..recipe.outputItemID)).."  •  ID "..recipe.outputItemID,82,-130,300,"GameFontHighlightSmall")
        line:SetWordWrap(true)
        line:SetTextColor(.55,.58,.64)

        -- Zone survolable : icône + nom de l'objet fabriqué.
        local productHover=CreateFrame("Frame",nil,page)
        productHover:SetPoint("TOPLEFT",18,-50)
        productHover:SetSize(385,72)
        AddItemTooltip(productHover,recipe.outputItemID)
    end

    local y=-180

    -- Conditions propres au métier.
    local requirements=CRAFT_REQUIREMENTS[recipe.profession]
    if requirements and requirements.tools then
        local reqTitle=Label(page,"Conditions de fabrication",18,y,365,"QuestFont_Large")
        reqTitle:SetTextColor(.31,.21,.11)
        y=y-28

        for _,requirement in ipairs(requirements.tools) do
            local ok,count,source=GetCraftToolStatus(requirement)
            local text
            if requirement.alternativeNPC then
                if ok and source=="Sacs" then
                    text=requirement.name.."  ["..count.." disponible"..(count>1 and "s" or "").."]"
                elseif ok then
                    text=requirement.name.."  [Remplacée par "..source.."]"
                else
                    text=requirement.name.."  [Requise]"
                end
            else
                text=requirement.name..(ok and ("  ["..count.." disponible"..(count>1 and "s" or "").."]") or "  [Requis]")
            end

            -- Icône graphique dédiée : l'état n'est plus dépendant des glyphes de police WoW.
            local statusIcon=page:CreateTexture(nil,"ARTWORK")
            statusIcon:SetSize(18,18)
            statusIcon:SetPoint("TOPLEFT",28,y+3)
            statusIcon:SetTexture(ok and STATUS_READY_ICON or STATUS_MISSING_ICON)

            local line=Label(page,text,52,y,326,"GameFontNormal")
            line:SetWordWrap(true)
            if ok then
                line:SetTextColor(.63,.78,.63)
            else
                line:SetTextColor(.90,.22,.20)
            end

            local hit=CreateFrame("Frame",nil,page)
            hit:SetPoint("TOPLEFT",line,"TOPLEFT",-4,4)
            hit:SetPoint("BOTTOMRIGHT",line,"BOTTOMRIGHT",4,-4)
            hit:EnableMouse(true)
            AddItemTooltip(hit,requirement.itemID)

            y=y-24
        end

        if recipe.profession=="Cuisinier" then
            -- Tant que .dist n'est pas parsé, on indique clairement l'alternative
            -- sans prétendre connaître automatiquement sa distance.
            local npcInfo=Label(page,"Alternative : Atelier de Cuisine Classique (≤ 2 m) remplace la Marmite.",28,y,350,"GameFontHighlightSmall")
            npcInfo:SetTextColor(.48,.38,.25)
            npcInfo:SetWordWrap(true)
            y=y-34
        elseif requirements.workshop then
            local workshopText="Installation requise : "..tostring(requirements.workshop.name or "Atelier de métier").."."
            if requirements.workshop.alternativeItems then
                local names={}; for _,alt in ipairs(requirements.workshop.alternativeItems) do names[#names+1]=alt.name end
                workshopText=workshopText.." Alternative portable : "..table.concat(names," ou ").."."
            elseif requirements.workshop.alternativeItemSet then
                local names={}; for _,alt in ipairs(requirements.workshop.alternativeItemSet) do names[#names+1]=alt.name end
                workshopText=workshopText.." Alternative portable : "..table.concat(names," + ").." (les deux requis)."
            end
            local workshopInfo=Label(page,workshopText,28,y,350,"GameFontHighlightSmall")
            workshopInfo:SetTextColor(.48,.38,.25)
            workshopInfo:SetWordWrap(true)
            y=y-46
        end

        local rule=page:CreateTexture(nil,"ARTWORK")
        rule:SetHeight(1)
        rule:SetPoint("TOPLEFT",18,y+7)
        rule:SetPoint("TOPRIGHT",-18,y+7)
        rule:SetColorTexture(.45,.30,.13,.32)
        y=y-8
    end

    if V3RequiredRoll(recipe)~=nil then
        local craftRule=page:CreateTexture(nil,"ARTWORK")
        craftRule:SetHeight(1)
        craftRule:SetPoint("TOPLEFT",18,y+5)
        craftRule:SetPoint("TOPRIGHT",-18,y+5)
        craftRule:SetColorTexture(.45,.30,.13,.32)
        y=y-10

        local craftTitle=Label(page,"Fabrication",18,y,365,"QuestFont_Large")
        craftTitle:SetTextColor(.31,.21,.11)
        y=y-29

        local recipeProfession=V3RecipeProfession(recipe)
        local selectedRollType=V3RequiredRoll(recipe) or "Nature"
        local selectedNatureModifier=0
        local workshopAvailable=false
        local RefreshCraftButton

        -- Validation RP manuelle de l'atelier / installation de métier.
        local professionRequirements=CRAFT_REQUIREMENTS[recipe.profession]
        local workshopName=(professionRequirements and professionRequirements.workshop and professionRequirements.workshop.name) or "Installation de métier"
        if recipe.profession=="Cuisinier" then workshopName="Atelier de Cuisine Classique" end
        local workshopLabel=Label(page,"Installation",28,y,150,"GameFontNormal")
        workshopLabel:SetTextColor(.37,.27,.16)

        local workshopButton=CreateFrame("Button",nil,page,"BackdropTemplate")
        workshopButton:SetSize(218,27)
        workshopButton:SetPoint("TOPLEFT",148,y+6)
        ApplyBackdrop(workshopButton,.98)
        workshopButton:SetBackdropColor(.075,.070,.065,.96)
        workshopButton:SetBackdropBorderColor(.30,.29,.27,.92)

        local workshopGem=workshopButton:CreateTexture(nil,"ARTWORK")
        workshopGem:SetTexture("Interface\\Buttons\\WHITE8X8")
        workshopGem:SetSize(6,6)
        workshopGem:SetPoint("LEFT",10,0)
        workshopGem:SetRotation(math.rad(45))
        workshopGem:SetVertexColor(.46,.45,.43)

        local workshopStatus=workshopButton:CreateTexture(nil,"ARTWORK")
        workshopStatus:SetSize(16,16)
        workshopStatus:SetPoint("LEFT",19,0)
        workshopStatus:SetTexture(STATUS_MISSING_ICON)

        local workshopText=workshopButton:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        workshopText:SetPoint("LEFT",40,0)
        workshopText:SetPoint("RIGHT",-7,0)
        workshopText:SetJustifyH("LEFT")
        workshopText:SetText(workshopName.." indisponible")
        workshopText:SetTextColor(.52,.50,.47)

        local function RefreshWorkshopButton()
            local alternativeOK,alternativeName=GetWorkshopAlternativeStatus(professionRequirements and professionRequirements.workshop)
            if workshopAvailable or alternativeOK then
                workshopButton:SetBackdropColor(.18,.105,.035,.98)
                workshopButton:SetBackdropBorderColor(.88,.63,.24,1)
                workshopGem:SetVertexColor(.92,.68,.26)
                if workshopAvailable then
                    workshopStatus:SetTexture(STATUS_READY_ICON)
                    workshopText:SetText(workshopName.." à disposition")
                else
                    workshopStatus:SetTexture(STATUS_READY_ICON)
                    workshopText:SetText(tostring(alternativeName or "Alternative portable").." disponible")
                end
                workshopText:SetTextColor(1,.88,.50)
            else
                workshopButton:SetBackdropColor(.075,.070,.065,.96)
                workshopButton:SetBackdropBorderColor(.30,.29,.27,.92)
                workshopGem:SetVertexColor(.46,.45,.43)
                workshopStatus:SetTexture(STATUS_MISSING_ICON)
                workshopText:SetText(workshopName.." indisponible")
                workshopText:SetTextColor(.52,.50,.47)
            end
        end

        workshopButton:SetScript("OnClick",function()
            workshopAvailable=not workshopAvailable
            RefreshWorkshopButton()
            if RefreshCraftButton then RefreshCraftButton() end
        end)
        RefreshWorkshopButton()

        y=y-36

        local rollLabel=Label(page,"Nature du Rand",28,y,110,"GameFontNormal")
        rollLabel:SetTextColor(.37,.27,.16)

        local rollTypes={"Nature","Alchimie","Forge","Couture","Ingénierie","Savoir","Artisanat"}
        local rollDrop=CreateFrame("Frame",nil,page,"UIDropDownMenuTemplate")
        rollDrop:SetPoint("TOPLEFT",105,y+8)
        rollDrop:SetSize(142,28)
        UIDropDownMenu_SetWidth(rollDrop,122)
        UIDropDownMenu_SetText(rollDrop,"")
        rollDrop:SetAlpha(.01)

        local rollVisual=CreateFrame("Button",nil,page,"BackdropTemplate")
        rollVisual:SetSize(132,27)
        rollVisual:SetPoint("TOPLEFT",120,y+6)
        ApplyBackdrop(rollVisual,.98)
        rollVisual:SetBackdropColor(.075,.047,.025,.98)
        rollVisual:SetBackdropBorderColor(.57,.39,.16,.96)

        local rollGem=rollVisual:CreateTexture(nil,"ARTWORK")
        rollGem:SetTexture("Interface\\Buttons\\WHITE8X8")
        rollGem:SetSize(6,6)
        rollGem:SetPoint("LEFT",9,0)
        rollGem:SetVertexColor(.78,.54,.20)
        rollGem:SetRotation(math.rad(45))

        local rollValue=rollVisual:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        rollValue:SetPoint("CENTER",-6,0)
        rollValue:SetText(selectedRollType)
        rollValue:SetTextColor(1,.86,.57)

        local rollArrow=rollVisual:CreateTexture(nil,"ARTWORK")
        rollArrow:SetSize(14,14)
        rollArrow:SetPoint("RIGHT",-7,0)
        rollArrow:SetTexture(DROPDOWN_ARROW_ICON)

        rollVisual:SetScript("OnClick",function()
            ToggleDropDownMenu(1,nil,rollDrop,rollVisual,0,0)
        end)

        UIDropDownMenu_Initialize(rollDrop,function(self,level)
            for _,value in ipairs(rollTypes) do
                local info=UIDropDownMenu_CreateInfo()
                info.text=value
                info.value=value
                info.checked=(selectedRollType==value)
                info.func=function()
                    selectedRollType=value
                    UIDropDownMenu_SetSelectedValue(rollDrop,value)
                    rollValue:SetText(value)
                    CloseDropDownMenus()
                    if RefreshCraftButton then RefreshCraftButton() end
                end
                UIDropDownMenu_AddButton(info,level)
            end
        end)
        UIDropDownMenu_SetSelectedValue(rollDrop,selectedRollType)

        y=y-36

        local bonusLabel=Label(page,"Bonus / malus",28,y,178,"GameFontNormal")
        bonusLabel:SetTextColor(.37,.27,.16)

        -- Sélecteur compact dans la DA du grimoire.
        -- On conserve UIDropDownMenu pour sa fiabilité, mais on masque son habillage WoW
        -- et on lui superpose un bouton cuivre/or assorti au reste de l'interface.
        local natureDrop=CreateFrame("Frame",nil,page,"UIDropDownMenuTemplate")
        natureDrop:SetPoint("TOPLEFT",181,y+7)
        natureDrop:SetSize(104,28)
        UIDropDownMenu_SetWidth(natureDrop,82)
        UIDropDownMenu_SetText(natureDrop,"")
        natureDrop:SetAlpha(.01)

        local natureVisual=CreateFrame("Button",nil,page,"BackdropTemplate")
        natureVisual:SetSize(96,27)
        natureVisual:SetPoint("TOPLEFT",196,y+6)
        ApplyBackdrop(natureVisual,.98)
        natureVisual:SetBackdropColor(.075,.047,.025,.98)
        natureVisual:SetBackdropBorderColor(.57,.39,.16,.96)

        local natureValue=natureVisual:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        natureValue:SetPoint("CENTER",-7,0)
        natureValue:SetText("0")
        natureValue:SetTextColor(1,.86,.57)

        local arrow=natureVisual:CreateTexture(nil,"ARTWORK")
        arrow:SetSize(14,14)
        arrow:SetPoint("RIGHT",-7,0)
        arrow:SetTexture(DROPDOWN_ARROW_ICON)

        local leftGem=natureVisual:CreateTexture(nil,"ARTWORK")
        leftGem:SetTexture("Interface\\Buttons\\WHITE8X8")
        leftGem:SetSize(6,6)
        leftGem:SetPoint("LEFT",9,0)
        leftGem:SetVertexColor(.78,.54,.20)
        leftGem:SetRotation(math.rad(45))
        leftGem:SetAlpha(.90)

        natureVisual:SetScript("OnEnter",function(self)
            self:SetBackdropBorderColor(.86,.62,.25,1)
            natureValue:SetTextColor(1,.94,.72)
        end)
        natureVisual:SetScript("OnLeave",function(self)
            self:SetBackdropBorderColor(.57,.39,.16,.96)
            natureValue:SetTextColor(1,.86,.57)
        end)
        natureVisual:SetScript("OnClick",function()
            ToggleDropDownMenu(1,nil,natureDrop,natureVisual,0,0)
        end)

        UIDropDownMenu_Initialize(natureDrop,function(self,level)
            for value=-20,20 do
                local info=UIDropDownMenu_CreateInfo()
                info.text=(value>0 and ("+"..value)) or tostring(value)
                info.value=value
                info.checked=(selectedNatureModifier==value)
                info.func=function()
                    selectedNatureModifier=value
                    UIDropDownMenu_SetSelectedValue(natureDrop,value)
                    natureValue:SetText((value>0 and ("+"..value)) or tostring(value))
                    CloseDropDownMenus()
                end
                UIDropDownMenu_AddButton(info,level)
            end
        end)
        UIDropDownMenu_SetSelectedValue(natureDrop,0)

        local craftButton=Button(page,"Fabriquer",108,28)
        craftButton:SetPoint("TOPLEFT",304,y+6)

        RefreshCraftButton=function()
            local materialsOK=HasAllRecipeMaterialsInBags(recipe)
            local recipeProfession=V3RecipeProfession(recipe)
            local toolsOK=HasProfessionConditions(recipe,workshopAvailable)
            local requiredRoll=V3RequiredRoll(recipe)
            local rollOK=(requiredRoll~=nil and selectedRollType==requiredRoll)
            local canCraft=materialsOK and toolsOK and rollOK and recipe.outputItemID~=nil and PendingCraft==nil

            if rollOK then
                rollVisual:SetBackdropColor(.075,.047,.025,.98)
                rollVisual:SetBackdropBorderColor(.57,.39,.16,.96)
                rollValue:SetTextColor(1,.86,.57)
                rollGem:SetVertexColor(.78,.54,.20)
            else
                rollVisual:SetBackdropColor(.16,.035,.025,.98)
                rollVisual:SetBackdropBorderColor(.82,.20,.14,1)
                rollValue:SetTextColor(1,.38,.30)
                rollGem:SetVertexColor(.95,.20,.14)
            end

            if canCraft then
                craftButton:Enable()
                craftButton:SetBackdropColor(.19,.105,.030,.98)
                craftButton:SetBackdropBorderColor(.92,.67,.25,1)
                craftButton:SetAlpha(1)
                if craftButton.GetFontString and craftButton:GetFontString() then
                    craftButton:GetFontString():SetTextColor(1,.88,.48)
                end
            else
                craftButton:Disable()
                craftButton:SetBackdropColor(.070,.066,.060,.96)
                craftButton:SetBackdropBorderColor(.30,.29,.27,.92)
                craftButton:SetAlpha(.70)
                if craftButton.GetFontString and craftButton:GetFontString() then
                    craftButton:GetFontString():SetTextColor(.46,.45,.43)
                end
            end
        end

        RefreshCraftButton()

        -- Actualise automatiquement l'état si les composants changent dans le sac.
        craftButton._refreshElapsed=0
        craftButton:SetScript("OnUpdate",function(self,elapsed)
            self._refreshElapsed=(self._refreshElapsed or 0)+elapsed
            if self._refreshElapsed>=.35 then
                self._refreshElapsed=0
                RefreshCraftButton()
            end
        end)

        craftButton:SetScript("OnClick",function()
            V3Open(recipe,selectedNatureModifier,selectedRollType,workshopAvailable)
        end)

        y=y-42

        y=y-42
    end

    local h=Label(page,"Composants nécessaires",18,y,365,"QuestFont_Large")
    h:SetTextColor(.31,.21,.11)
    y=y-34

    if not recipe.materials or #recipe.materials==0 then
        Label(page,"Aucun composant.",25,y,350):SetTextColor(.55,.58,.64)
    else
        for _,material in ipairs(recipe.materials) do
            local itemName,itemIcon=GetItemData(material.itemID)
            local row=CreateFrame("Frame",nil,page)
            row:SetSize(372,45)
            row:SetPoint("TOPLEFT",18,y)

            local tx=row:CreateTexture(nil,"ARTWORK")
            tx:SetSize(35,35)
            tx:SetPoint("LEFT")
            tx:SetTexture(itemIcon)

            local fs=row:CreateFontString(nil,"OVERLAY","GameFontNormal")
            fs:SetPoint("LEFT",tx,"RIGHT",10,0)
            fs:SetPoint("RIGHT",row,"RIGHT",-8,0)
            fs:SetJustifyH("LEFT")
            fs:SetWordWrap(true)

            -- Disponibilité cumulée : sacs + dernier contenu connu du coffre de guilde.
            local bagCount=GetBagItemCount(material.itemID)
            local guildCount=GetGuildBankItemCount(material.itemID)
            local availableCount=bagCount+guildCount

            local resourceStatus
            local requiredCount=math.max(1,tonumber(material.quantity) or 1)

            -- Blanc seulement lorsque les sacs contiennent toute la quantité
            -- nécessaire à cette recette.
            if bagCount >= requiredCount then
                fs:SetTextColor(1,1,1)
                resourceStatus=" |cff9fbf9f["..bagCount.." disponible"..(bagCount > 1 and "s" or "").."]|r"
            elseif bagCount > 0 then
                fs:SetTextColor(.92,.18,.18)
                resourceStatus=" |cffff7777["..bagCount.."/"..requiredCount.." disponibles]|r"
            else
                fs:SetTextColor(.92,.18,.18)
                resourceStatus=" [Ressource manquante]"
            end

            local materialOK=(bagCount >= requiredCount)
            local materialStatus=row:CreateTexture(nil,"OVERLAY")
            materialStatus:SetSize(16,16)
            materialStatus:SetPoint("TOPLEFT",tx,"TOPLEFT",-6,6)
            materialStatus:SetTexture(materialOK and STATUS_READY_ICON or STATUS_MISSING_ICON)
            fs:SetText((material.quantity or 1).." × "..(itemName or ("Objet #"..tostring(material.itemID)))..resourceStatus)

            -- Tooltip de l'objet + détail de l'endroit où se trouvent les exemplaires.
            AddResourceLocationTooltip(row,material.itemID)

            y=y-48
        end
    end

    if recipe.source and recipe.source.kind=="transmission" then
        local provenance=page:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        provenance:SetPoint("BOTTOMLEFT",18,58)
        provenance:SetWidth(390); provenance:SetJustifyH("LEFT")
        provenance:SetText("Transmis par "..tostring(recipe.source.from or "Inconnu").." — savoir personnel recopié")
        provenance:SetTextColor(.57,.47,.31)
    end

    local edit=Button(page,recipe.official and "Annoter le manuscrit" or "Réviser la recette",recipe.official and 154 or 95,26)
    edit:SetPoint("BOTTOMLEFT",18,24)
    edit:SetScript("OnClick",function() OpenRecipeEditor(recipe.id or recipe.officialKey) end)

    if recipe.official then
        -- Une recette officielle est un statut, pas une action : simple sceau visuel non cliquable.
        local seal=page:CreateTexture(nil,"ARTWORK")
        seal:SetSize(18,18); seal:SetPoint("LEFT",edit,"RIGHT",16,0)
        seal:SetTexture(BOOK_ICON)
        seal:SetTexCoord(.08,.92,.08,.92)
        seal:SetVertexColor(.95,.76,.32)
        local officialMark=page:CreateFontString(nil,"OVERLAY","GameFontNormal")
        officialMark:SetPoint("LEFT",seal,"RIGHT",6,0)
        officialMark:SetText("Recette officielle")
        officialMark:SetTextColor(.78,.62,.30)
    else
        local delete=Button(page,recipe.isOfficialOverride and "Rétablir officielle" or "Supprimer",125,26)
        delete:SetPoint("BOTTOMLEFT",120,24)
        delete:SetScript("OnClick",function()
            local _,index=FindRecipeByID(recipe.id)
            if index then table.remove(DB.recipes,index) end
            UI.selectedRecipeID=nil
            RefreshRecipeList()
            RefreshDetails()
        end)
        if not recipe.isOfficialOverride then
            -- v2.57.13 : le bouton de transmission n'est plus enfant du ScrollChild.
            -- Il est créé ci-dessous directement sur detailContent pour qu'aucun scroll,
            -- masque ou frame de recette ne puisse intercepter son clic.
        end
    end

    page:SetHeight(math.max((UI.detailContent:GetHeight() or 470)-16,math.abs(y)+70))

    if (not recipe.official) and (not recipe.isOfficialOverride) then
        -- Replacé dans la barre d’actions de la recette, comme sur la base stable.
        local transmit=Button(page,"Confier ce savoir",165,26)
        transmit:SetPoint("BOTTOMLEFT",252,24)
        transmit:SetFrameLevel((page:GetFrameLevel() or 1)+12)
        transmit:EnableMouse(true)
        transmit:RegisterForClicks("LeftButtonUp")
        transmit:SetScript("OnClick",function() OpenTransferSender(recipe) end)
    end

end

-- ============================================================================
-- LISTE PAR MÉTIERS / MENUS DÉROULANTS
-- ============================================================================

local EQUIPMENT_NAME_HINTS = {
    "armure", "bottes", "cape", "capuche", "capuchon", "casque", "ceinture", "cuirasse",
    "gants", "gilet", "heaume", "plastron", "pourpoint", "robe", "tunique", "veste", "vêtement",
    "bandeau", "coiffe", "chemise", "brigandine", "harnois", "masque", "diadème", "bassinet",
    "épée", "epee", "hache", "lance", "masse", "dague", "poignard", "rapière", "rapiere",
    "arc ", "arbalète", "arbalete", "bâton", "baton", "baguette", "sceptre", "bouclier", "pavois",
    "anneau", "bague", "amulette", "pendentif", "sautoir", "médaillon", "medaillon"
}

local CONSUMABLE_NAME_HINTS = {
    "elixir", "élixir", "bandage", "parchemin", "glyphe", "bouillon", "brochette",
    "pain ", "potage", "ragoût", "ragout", "soufflé", "tourte",
    "viande fumée", "bière", "biere", "vin ", "rhum", "vodka", "brandy",
    "hydromel", "lait de vache", "eau bénite", "eau benite"
}

local function RecipeDisplayType(recipe)
    local objectDB=OfficialObjects()
    local object=recipe and recipe.outputItemID and objectDB[tonumber(recipe.outputItemID)] or nil
    local usage=object and string.lower(tostring(object.usage or "")) or ""
    local name=string.lower(tostring((recipe and recipe.name) or (object and object.name) or ""))

    -- Une catégorie explicite dans la recette / base objet est toujours prioritaire.
    -- Les mots-clés ne servent plus que de solution de secours pour les anciennes entrées.
    local explicit=recipe and tostring(recipe.displayType or recipe.type or "") or ""
    if explicit=="Équipements" or explicit=="Equipements" then return "Équipements" end
    if explicit=="Composants" then return "Composants" end
    if explicit=="Consommables" then return "Consommables" end
    if string.find(usage,"équipement",1,true) or string.find(usage,"equipement",1,true) then return "Équipements" end
    if string.find(usage,"composant",1,true) then return "Composants" end
    if string.find(usage,"consommable",1,true) then return "Consommables" end
    for _,hint in ipairs(CONSUMABLE_NAME_HINTS) do
        if string.find(name,hint,1,true) then return "Consommables" end
    end
    for _,hint in ipairs(EQUIPMENT_NAME_HINTS) do
        if string.find(name,hint,1,true) then return "Équipements" end
    end
    return "Autres"
end

local function RecipeFavoriteKey(recipe)
    if not recipe then return nil end
    if recipe.officialKey then return "official:"..tostring(recipe.officialKey) end
    if recipe.id then return "personal:"..tostring(recipe.id) end
    if recipe.outputItemID then return "item:"..tostring(recipe.outputItemID) end
    return "name:"..tostring(recipe.name or "")
end

local function IsRecipeFavorite(recipe)
    if not DB or not DB.favorites then return false end
    local key=RecipeFavoriteKey(recipe)
    return key and DB.favorites[key]==true or false
end

local function ToggleRecipeFavorite(recipe)
    if not DB then return end
    DB.favorites=DB.favorites or {}
    local key=RecipeFavoriteKey(recipe)
    if not key then return end
    DB.favorites[key]=not DB.favorites[key]
    if DB.favorites[key]~=true then DB.favorites[key]=nil end
end

local function RecipesForProfession(profession)
    local result={}
    local activeFilter=UI.recipeTypeFilter or "Tous"
    for _,recipe in ipairs(GetAllRecipes()) do
        local typeOK=(activeFilter=="Tous") or (RecipeDisplayType(recipe)==activeFilter)
        local favoriteOK=(not UI.favoritesOnly) or IsRecipeFavorite(recipe)
        if (recipe.profession or "Cuisinier")==profession and typeOK and favoriteOK then
            result[#result+1]=recipe
        end
    end
    table.sort(result,function(a,b)
        return string.lower(a.name or "") < string.lower(b.name or "")
    end)
    return result
end

RefreshRecipeList=function()
    if not UI.listContent then return end
    HideChildren(UI.listContent)

    local y=-4

    for _,profession in ipairs(DEFAULT_PROFESSIONS) do
        local recipes=RecipesForProfession(profession)
        local profName=profession

        local header=CreateFrame("Button",nil,UI.listContent,"BackdropTemplate")
        header:SetSize(372,48)
        header:SetPoint("TOPLEFT",4,y)
        ApplyBackdrop(header,.72)

        header:SetBackdropColor(.16,.105,.050,.34)
        header:SetBackdropBorderColor(.48,.34,.15,.52)

        -- Fine ligne noble, comme un chapitre manuscrit du livre.
        local rule=header:CreateTexture(nil,"ARTWORK")
        rule:SetHeight(1)
        rule:SetPoint("BOTTOMLEFT",9,3)
        rule:SetPoint("BOTTOMRIGHT",-9,3)
        rule:SetColorTexture(.58,.39,.16,.48)

        local capL=header:CreateFontString(nil,"OVERLAY","GameFontNormal")
        capL:SetPoint("LEFT",8,0)
        capL:SetText("•")
        capL:SetTextColor(.66,.47,.22)

        local profIcon=header:CreateTexture(nil,"ARTWORK")
        profIcon:SetSize(42,42)
        profIcon:SetPoint("LEFT",capL,"RIGHT",6,0)
        profIcon:SetTexture(PROFESSION_ICONS[profName] or BOOK_ICON)
        if PROFESSION_ICONS[profName] then profIcon:SetTexCoord(0,1,0,1) end

        -- Plus de carré/flèche entre l'icône et le nom.
        local name=header:CreateFontString(nil,"OVERLAY","QuestFont_Large")
        name:SetPoint("LEFT",profIcon,"RIGHT",10,1)
        name:SetText(profName)
        name:SetTextColor(.76,.56,.28)
        name:SetShadowColor(.02,.012,.006,.95)
        name:SetShadowOffset(1,-1)

        local count=header:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        count:SetPoint("RIGHT",-28,0)
        count:SetText("("..tostring(#recipes)..")")
        count:SetTextColor(.70,.52,.29)

        local capR=header:CreateFontString(nil,"OVERLAY","GameFontNormal")
        capR:SetPoint("RIGHT",-9,0)
        capR:SetText(UI.openProfessions[profName] and "—" or "›")
        capR:SetTextColor(.66,.47,.22)

        header:SetScript("OnEnter",function(self)
            self:SetBackdropColor(.22,.145,.065,.48)
            self:SetBackdropBorderColor(.63,.45,.20,.72)
            name:SetTextColor(.96,.76,.40)
        end)
        header:SetScript("OnLeave",function(self)
            self:SetBackdropColor(.16,.105,.050,.34)
            self:SetBackdropBorderColor(.48,.34,.15,.52)
            name:SetTextColor(.76,.56,.28)
        end)

        header:SetScript("OnClick",function()
            local opening = not UI.openProfessions[profName]
            UI.openProfessions[profName]=opening
            RefreshRecipeList()

            if opening then
                RefreshItemDataForProfession(profName)
            end
        end)

        y=y-52

        if UI.openProfessions[profName] then
            if #recipes==0 then
                local empty=CreateFrame("Frame",nil,UI.listContent)
                empty:SetSize(360,28)
                empty:SetPoint("TOPLEFT",10,y)
                local fs=empty:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
                fs:SetPoint("LEFT",16,0)
                fs:SetText("Aucune recette apprise")
                fs:SetTextColor(.42,.34,.25)
                y=y-31
            else
                UI.openDifficulties[profName]=UI.openDifficulties[profName] or {}

                for _,difficultyData in ipairs(CRAFT_DIFFICULTIES) do
                    local difficultyName=difficultyData.name
                    local difficultyRecipes={}

                    for _,recipe in ipairs(recipes) do
                        if (recipe.difficulty or "Mineur")==difficultyName then
                            difficultyRecipes[#difficultyRecipes+1]=recipe
                        end
                    end

                    if #difficultyRecipes>0 then
                        local diffKey=difficultyName
                        local diffHeader=CreateFrame("Button",nil,UI.listContent,"BackdropTemplate")
                        diffHeader:SetSize(354,32)
                        diffHeader:SetPoint("TOPLEFT",14,y)
                        ApplyBackdrop(diffHeader,.60)
                        diffHeader:SetBackdropColor(.105,.072,.038,.34)
                        diffHeader:SetBackdropBorderColor(.40,.28,.12,.44)

                        local ornament=diffHeader:CreateTexture(nil,"ARTWORK")
                        ornament:SetTexture("Interface\\Buttons\\WHITE8X8")
                        ornament:SetSize(6,6)
                        ornament:SetPoint("LEFT",11,0)
                        ornament:SetRotation(math.rad(45))
                        ornament:SetVertexColor(.62,.43,.18,.82)

                        local diffNameText=diffHeader:CreateFontString(nil,"OVERLAY","GameFontNormal")
                        diffNameText:SetPoint("LEFT",25,0)
                        diffNameText:SetText(difficultyName)
                        diffNameText:SetTextColor(.64,.45,.22)

                        local diffCount=diffHeader:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
                        diffCount:SetPoint("RIGHT",-28,0)
                        diffCount:SetText("("..tostring(#difficultyRecipes)..")")
                        diffCount:SetTextColor(.55,.42,.26)

                        local diffArrow=diffHeader:CreateFontString(nil,"OVERLAY","GameFontNormal")
                        diffArrow:SetPoint("RIGHT",-10,0)
                        diffArrow:SetText(UI.openDifficulties[profName][diffKey] and "—" or "›")
                        diffArrow:SetTextColor(.60,.43,.20)

                        diffHeader:SetScript("OnEnter",function(self)
                            self:SetBackdropColor(.16,.105,.050,.48)
                            self:SetBackdropBorderColor(.58,.40,.17,.64)
                            diffNameText:SetTextColor(.88,.65,.31)
                        end)
                        diffHeader:SetScript("OnLeave",function(self)
                            self:SetBackdropColor(.105,.072,.038,.34)
                            self:SetBackdropBorderColor(.40,.28,.12,.44)
                            diffNameText:SetTextColor(.64,.45,.22)
                        end)
                        diffHeader:SetScript("OnClick",function()
                            UI.openDifficulties[profName][diffKey]=not UI.openDifficulties[profName][diffKey]
                            RefreshRecipeList()
                        end)

                        y=y-35

                        if UI.openDifficulties[profName][diffKey] then
                            for _,recipeValue in ipairs(difficultyRecipes) do
                                local recipe=recipeValue
                                local row=CreateFrame("Button",nil,UI.listContent,"BackdropTemplate")
                                row:SetSize(338,44)
                                ApplyBackdrop(row,.42)
                                row:SetBackdropColor(.13,.092,.052,.38)
                                row:SetBackdropBorderColor(.42,.29,.13,.30)
                                row:SetPoint("TOPLEFT",30,y)

                                local guide=row:CreateTexture(nil,"ARTWORK")
                                guide:SetWidth(1)
                                guide:SetPoint("TOPLEFT",2,-2)
                                guide:SetPoint("BOTTOMLEFT",2,2)
                                guide:SetColorTexture(.46,.31,.13,.30)

                                local _,ico=GetItemData(recipe.outputItemID)
                                local tx=row:CreateTexture(nil,"ARTWORK")
                                tx:SetSize(30,30)
                                tx:SetPoint("LEFT",8,0)
                                tx:SetTexture(ico)

                                local fs=row:CreateFontString(nil,"OVERLAY","GameFontHighlight")
                                fs:SetPoint("LEFT",tx,"RIGHT",10,0)
                                fs:SetWidth(244)
                                fs:SetJustifyH("LEFT")
                                fs:SetText(recipe.name or "Sans nom")

                                local favorite=CreateFrame("Button",nil,row)
                                favorite:SetSize(26,26)
                                favorite:SetPoint("RIGHT",-6,0)
                                favorite:SetFrameLevel((row:GetFrameLevel() or 1)+4)
                                local favoriteIcon=favorite:CreateTexture(nil,"ARTWORK")
                                favoriteIcon:SetSize(22,22)
                                favoriteIcon:SetPoint("CENTER")
                                local function RefreshFavoriteIcon()
                                    favoriteIcon:SetTexture(IsRecipeFavorite(recipe) and FAVORITE_ON_ICON or FAVORITE_OFF_ICON)
                                end
                                RefreshFavoriteIcon()
                                favorite:SetScript("OnEnter",function(self)
                                    favoriteIcon:SetAlpha(1)
                                    GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                                    GameTooltip:SetText(IsRecipeFavorite(recipe) and "Retirer des favoris" or "Ajouter aux favoris")
                                    GameTooltip:Show()
                                end)
                                favorite:SetScript("OnLeave",function()
                                    GameTooltip:Hide()
                                    favoriteIcon:SetAlpha(.92)
                                    RefreshFavoriteIcon()
                                end)
                                favorite:SetScript("OnClick",function(self)
                                    ToggleRecipeFavorite(recipe)
                                    RefreshRecipeList()
                                end)

                                local recipeSelectionID=recipe.id or recipe.officialKey
                                if recipeSelectionID==UI.selectedRecipeID then
                                    fs:SetTextColor(1,.78,.34)
                                    row:SetBackdropColor(.24,.15,.055,.64)
                                    row:SetBackdropBorderColor(.72,.50,.20,.72)
                                else
                                    fs:SetTextColor(.96,.88,.72)
                                end

                                row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                                if recipe.outputItemID then AddItemTooltip(row,recipe.outputItemID) end

                                row:SetScript("OnClick",function()
                                    UI.selectedRecipeID=recipe.id or recipe.officialKey
                                    if recipe.outputItemID then GetItemData(recipe.outputItemID) end
                                    for _,material in ipairs(recipe.materials or {}) do
                                        if material.itemID then GetItemData(material.itemID) end
                                    end
                                    RefreshRecipeList()
                                    RefreshDetails()
                                    if C_Timer and C_Timer.After then
                                        C_Timer.After(0.25,function()
                                            if UI.selectedRecipeID==(recipe.id or recipe.officialKey) then RefreshDetails() end
                                        end)
                                    end
                                end)

                                y=y-46
                            end
                        end
                    end
                end
            end
        end
    end

    UI.listContent:SetHeight(math.max(470,-y+10))
end

-- ============================================================================
-- ÉDITEUR DE RECETTE
-- ============================================================================

OpenRecipeEditor=function(recipeID)
    if UI.editor then UI.editor:Hide() UI.editor=nil end

    local existing=recipeID and FindRecipeByID(recipeID)
    local existingIsOfficial=existing and existing.official==true
    local rows={}
    local chosenProfession=(existing and existing.profession) or "Cuisinier"
    local chosenDifficulty=(existing and existing.difficulty) or "Mineur"

    local f=CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
    UI.editor=f
    f:SetSize(700,650)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",f.StartMoving)
    f:SetScript("OnDragStop",f.StopMovingOrSizing)
    ApplyBackdrop(f,.99)
    f:SetBackdropColor(.025,.017,.012,.995)
    f:SetBackdropBorderColor(.42,.29,.13,.95)

    -- Enluminures de couverture, identiques au grimoire principal.
    local cornerData = {
        {"TOPLEFT","CornerTL",0,0},
        {"TOPRIGHT","CornerTR",0,0},
        {"BOTTOMLEFT","CornerBL",0,0},
        {"BOTTOMRIGHT","CornerBR",0,0},
    }
    for _,c in ipairs(cornerData) do
        local tex=f:CreateTexture(nil,"OVERLAY")
        tex:SetSize(92,92)
        tex:SetPoint(c[1],f,c[1],c[3],c[4])
        tex:SetTexture("Interface\\AddOns\\Omega_Hub\\Modules\\GrimoireCraft\\Media\\MainPage\\"..c[2])
        tex:SetAlpha(.90)
    end

    local title=Label(f,existing and "Modifier la Recette" or "Nouvelle Recette",0,-16,700,"QuestFont_Huge")
    title:SetJustifyH("CENTER")
    title:SetTextColor(.83,.69,.43)
    title:SetShadowColor(.03,.02,.01,.95)
    title:SetShadowOffset(1,-2)

    local subtitle=Label(f,"— Feuillet de l'Artisan —",0,-48,700,"GameFontHighlight")
    subtitle:SetJustifyH("CENTER")
    subtitle:SetTextColor(.56,.45,.30)
    AddGoldRule(f,-72,145,-145)

    local close=CreateFrame("Button",nil,f,"UIPanelCloseButton")
    close:SetPoint("TOPRIGHT",-5,-5)
    close:SetScript("OnClick",function() f:Hide() UI.editor=nil end)

    -- Grande feuille de parchemin : les champs semblent écrits dans le livre.
    local page=CreateFrame("Frame",nil,f,"BackdropTemplate")
    page:SetPoint("TOPLEFT",30,-92)
    page:SetPoint("BOTTOMRIGHT",-30,62)
    ApplyBackdrop(page,.96)
    page:SetBackdropColor(.095,.071,.044,.98)
    page:SetBackdropBorderColor(.31,.22,.12,.95)
    AddPaperTexture(page,.98)
    AddPageWear(page)

    local topRule=page:CreateTexture(nil,"ARTWORK")
    topRule:SetHeight(1)
    topRule:SetPoint("TOPLEFT",18,-12)
    topRule:SetPoint("TOPRIGHT",-18,-12)
    topRule:SetColorTexture(.62,.43,.18,.55)

    local pageTitle=Label(page,"Consigner une recette",0,-18,620,"QuestFont_Large")
    pageTitle:SetJustifyH("CENTER")
    pageTitle:SetTextColor(.31,.21,.11)
    AddGoldRule(page,-42,70,-70)

    local function InkLabel(text,x,y,w,font)
        local l=Label(page,text,x,y,w,font)
        l:SetTextColor(.37,.27,.16)
        return l
    end

    InkLabel("Nom personnalisé",24,-62,270,"GameFontNormal")
    local nameBox=EditBox(page,24,-82,275,26,existing and existing.customName and existing.name or "")

    InkLabel("ID de l'objet fabriqué",330,-62,250,"GameFontNormal")
    local outputBox=EditBox(page,330,-82,180,26,existing and existing.outputItemID or "",true)

    local autoNamePreview=Label(page,"",24,-113,565,"GameFontHighlightSmall")
    autoNamePreview:SetTextColor(.43,.34,.24)

    local function UpdateAutomaticRecipeName()
        local custom=nameBox:GetText() or ""
        if custom~="" then
            autoNamePreview:SetText("Nom utilisé : "..custom)
            return
        end
        local itemID=tonumber(outputBox:GetText())
        if not itemID then
            autoNamePreview:SetText("Sans nom personnalisé : le nom de l'objet sera utilisé.")
            return
        end
        local itemName=GetItemData(itemID)
        if itemName then
            autoNamePreview:SetText("Nom automatique : "..itemName)
        else
            autoNamePreview:SetText("Nom automatique : chargement de l'objet #"..itemID.."...")
            if C_Timer and C_Timer.After then
                C_Timer.After(.25,function()
                    if f and f:IsShown() then UpdateAutomaticRecipeName() end
                end)
            end
        end
    end

    nameBox:SetScript("OnTextChanged",UpdateAutomaticRecipeName)
    outputBox:SetScript("OnTextChanged",UpdateAutomaticRecipeName)
    UpdateAutomaticRecipeName()

    InkLabel("Métier",24,-145,180,"GameFontNormal")
    local professionButton=Button(page,chosenProfession,220,26)
    professionButton:SetPoint("TOPLEFT",24,-165)

    local dropdown=CreateFrame("Frame",nil,page,"BackdropTemplate")
    dropdown:SetSize(220,#DEFAULT_PROFESSIONS*24+8)
    dropdown:SetPoint("TOPLEFT",professionButton,"BOTTOMLEFT",0,-2)
    dropdown:SetFrameLevel(page:GetFrameLevel()+20)
    ApplyBackdrop(dropdown,.99)
    dropdown:SetBackdropColor(.035,.025,.017,.99)
    dropdown:SetBackdropBorderColor(.48,.34,.15,.92)
    dropdown:Hide()

    local dy=-4
    for _,professionValue in ipairs(DEFAULT_PROFESSIONS) do
        local profession=professionValue
        local b=CreateFrame("Button",nil,dropdown)
        b:SetSize(210,23)
        b:SetPoint("TOPLEFT",5,dy)
        local fs=b:CreateFontString(nil,"OVERLAY","GameFontNormal")
        fs:SetPoint("LEFT",8,0)
        fs:SetText(profession)
        fs:SetTextColor(.78,.61,.34)
        b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        b:SetScript("OnClick",function()
            chosenProfession=profession
            professionButton:SetText(profession)
            dropdown:Hide()
        end)
        dy=dy-24
    end

    professionButton:SetScript("OnClick",function()
        if dropdown:IsShown() then dropdown:Hide() else dropdown:Show() end
    end)

    InkLabel("Difficulté du craft",330,-145,220,"GameFontNormal")
    local difficultyButton=Button(page,chosenDifficulty,220,26)
    difficultyButton:SetPoint("TOPLEFT",330,-165)

    local difficultyDrop=CreateFrame("Frame",nil,page,"BackdropTemplate")
    difficultyDrop:SetSize(220,#CRAFT_DIFFICULTIES*27+8)
    difficultyDrop:SetPoint("TOPLEFT",difficultyButton,"BOTTOMLEFT",0,-2)
    difficultyDrop:SetFrameLevel(page:GetFrameLevel()+21)
    ApplyBackdrop(difficultyDrop,.99)
    difficultyDrop:SetBackdropColor(.035,.025,.017,.99)
    difficultyDrop:SetBackdropBorderColor(.48,.34,.15,.92)
    difficultyDrop:Hide()

    local ddy=-4
    for _,difficultyData in ipairs(CRAFT_DIFFICULTIES) do
        local data=difficultyData
        local b=CreateFrame("Button",nil,difficultyDrop)
        b:SetSize(210,26)
        b:SetPoint("TOPLEFT",5,ddy)

        local n=b:CreateFontString(nil,"OVERLAY","GameFontNormal")
        n:SetPoint("LEFT",8,0)
        n:SetText(data.name)
        n:SetTextColor(.82,.69,.48)

        local rank=b:CreateFontString(nil,"OVERLAY","GameFontNormal")
        rank:SetPoint("RIGHT",-9,0)
        rank:SetText(tostring(data.minimum))
        rank:SetTextColor(1,.66,.29)

        b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        b:SetScript("OnClick",function()
            chosenDifficulty=data.name
            difficultyButton:SetText(data.name.."  —  "..data.minimum)
            difficultyDrop:Hide()
        end)
        ddy=ddy-27
    end

    local function DifficultyMinimum(name)
        for _,data in ipairs(CRAFT_DIFFICULTIES) do
            if data.name==name then return data.minimum end
        end
        return 6
    end
    difficultyButton:SetText(chosenDifficulty.."  —  "..DifficultyMinimum(chosenDifficulty))
    difficultyButton:SetScript("OnClick",function()
        if difficultyDrop:IsShown() then difficultyDrop:Hide() else difficultyDrop:Show() end
    end)

    local divider=page:CreateTexture(nil,"ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT",24,-257)
    divider:SetPoint("TOPRIGHT",-24,-257)
    divider:SetColorTexture(.50,.34,.15,.38)

    local ch=Label(page,"Composants nécessaires",24,-270,560,"QuestFont_Large")
    ch:SetTextColor(.31,.21,.11)

    local scroll=CreateFrame("ScrollFrame",nil,page,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",24,-302)
    scroll:SetSize(575,135)

    local content=CreateFrame("Frame",nil,scroll)
    content:SetSize(545,135)
    scroll:SetScrollChild(content)

    local function LayoutRows()
        local y=-4
        for _,row in ipairs(rows) do
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT",0,y)
            y=y-62
        end
        content:SetHeight(math.max(135,#rows*62+10))
    end

    local function AddRow(quantity,itemID)
        local row=CreateFrame("Frame",nil,content,"BackdropTemplate")
        row:SetSize(520,56)
        ApplyBackdrop(row,.72)
        row:SetBackdropColor(.050,.036,.023,.88)
        row:SetBackdropBorderColor(.40,.29,.15,.62)

        local ql=Label(row,"Quantité",9,-5,90,"GameFontHighlightSmall")
        ql:SetTextColor(.62,.49,.31)
        row.qty=EditBox(row,9,-24,75,24,tostring(quantity or 1),true)

        local il=Label(row,"ID de l'objet",110,-5,130,"GameFontHighlightSmall")
        il:SetTextColor(.62,.49,.31)
        row.item=EditBox(row,110,-24,135,24,itemID and tostring(itemID) or "",true)

        row.preview=Label(row,"",265,-25,205)
        row.preview:SetTextColor(.77,.65,.45)
        local function Preview()
            local id=tonumber(row.item:GetText())
            local itemName=id and GetItemData(id)
            row.preview:SetText(itemName or (id and ("Objet #"..id) or ""))
        end
        row.item:SetScript("OnTextChanged",Preview)

        local minus=Button(row,"−",30,24)
        minus:SetPoint("RIGHT",-8,-7)
        minus:SetScript("OnClick",function()
            for i,v in ipairs(rows) do
                if v==row then table.remove(rows,i) break end
            end
            row:Hide()
            LayoutRows()
        end)

        rows[#rows+1]=row
        LayoutRows()
        Preview()
    end

    for _,material in ipairs(existing and existing.materials or {}) do
        AddRow(material.quantity,material.itemID)
    end

    local plus=Button(page,"+ Ajouter un composant",180,28)
    -- Bouton séparé de la liste : il ne recouvre plus la dernière ligne.
    plus:SetPoint("BOTTOMLEFT",24,10)
    plus:SetFrameLevel(page:GetFrameLevel()+5)
    plus:SetScript("OnClick",function() AddRow(1,nil) end)

    -- Autorisation des recettes officielles : zone dédiée en bas de page.
    -- Elle était auparavant placée au milieu de la section Composants et pouvait
    -- recouvrir le titre/la liste. Elle est désormais alignée avec le bouton
    -- d'ajout de composant, sans empiéter sur le contenu de la recette.
    local authorizationLabel=Label(page,"Sceau d'autorisation",230,0,165,"GameFontHighlightSmall")
    authorizationLabel:ClearAllPoints()
    authorizationLabel:SetPoint("BOTTOMLEFT",230,39)
    authorizationLabel:SetTextColor(.52,.36,.18)

    local authorizationBox=CreateFrame("EditBox",nil,page,"InputBoxTemplate")
    authorizationBox:SetSize(190,26)
    authorizationBox:SetPoint("BOTTOMLEFT",230,9)
    authorizationBox:SetAutoFocus(false)
    authorizationBox:SetText("")

    local authorizationHint=Label(page,"Recette officielle uniquement",0,0,175,"GameFontHighlightSmall")
    authorizationHint:ClearAllPoints()
    authorizationHint:SetPoint("LEFT",authorizationBox,"RIGHT",8,0)
    authorizationHint:SetTextColor(.42,.34,.24)

    -- Sur une recette officielle, la zone est mise en évidence pour rendre
    -- immédiatement compréhensible qu'un code est requis pour l'annoter.
    if existingIsOfficial or (existing and existing.isOfficialOverride) then
        authorizationLabel:SetTextColor(.72,.48,.18)
        authorizationHint:SetText("Code requis pour annoter l'officielle")
        authorizationHint:SetTextColor(.66,.43,.20)
    end

    local footer=Label(f,"Encre, matière & savoir-faire",0,-596,700,"GameFontHighlightSmall")
    footer:SetJustifyH("CENTER")
    footer:SetTextColor(.40,.31,.21)

    local save=Button(f,"Enregistrer",110,30)
    save:SetPoint("BOTTOMRIGHT",-145,17)
    save:SetScript("OnClick",function()
        local outputItemID=tonumber(outputBox:GetText())
        local customName=nameBox:GetText() or ""
        customName=customName:gsub("^%s+",""):gsub("%s+$","")

        local automaticName=nil
        if outputItemID then
            automaticName=GetItemData(outputItemID)
        end

        if customName=="" and not automaticName then
            DEFAULT_CHAT_FRAME:AddMessage("|cffb8a36a[Grimoire]|r Indique un nom personnalisé ou un ID d'objet valide.")
            return
        end

        local enteredCode=authorizationBox:GetText() or ""
        enteredCode=enteredCode:gsub("^%s+",""):gsub("%s+$","")
        local codeOK=(enteredCode==OFFICIAL_RECIPE_OVERRIDE_CODE)
        local officialCollision=FindOfficialRecipeByOutputItemID(outputItemID)

        -- Une recette personnelle ne peut pas fabriquer un objet déjà réservé
        -- par la base officielle, sauf autorisation explicite.
        local editingSameOfficial = existing and (
            (existing.official and officialCollision and existing.officialKey==officialCollision.officialKey)
            or (existing.officialOverrideKey and officialCollision and existing.officialOverrideKey==officialCollision.officialKey)
        )

        if officialCollision and not editingSameOfficial and not codeOK then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[Grimoire]|r Cet objet possède déjà une recette officielle. Code d'autorisation requis.")
            authorizationBox:SetFocus()
            return
        end

        -- Une recette officielle embarquée n'est jamais modifiée en mémoire.
        -- Avec le code, on crée une surcharge personnelle persistante.
        local recipe=existing
        if existingIsOfficial then
            if not codeOK then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[Grimoire]|r Une recette officielle est en lecture seule. Entre le code d'autorisation pour créer une surcharge.")
                authorizationBox:SetFocus()
                return
            end

            local previousOverride=FindOverrideForOfficialKey(existing.officialKey)
            if previousOverride then
                recipe=previousOverride
            else
                recipe={
                    id=NewRecipeID(),
                    materials={},
                    officialOverrideKey=existing.officialKey,
                    isOfficialOverride=true,
                }
                DB.recipes[#DB.recipes+1]=recipe
            end
        elseif not recipe then
            recipe={id=NewRecipeID(),materials={}}
            DB.recipes[#DB.recipes+1]=recipe
        end

        recipe.outputItemID=outputItemID
        recipe.customName=(customName~="")
        recipe.name=(customName~="" and customName) or automaticName

        if officialCollision and codeOK and not recipe.officialOverrideKey then
            recipe.officialOverrideKey=officialCollision.officialKey
            recipe.isOfficialOverride=true
        end

        recipe.profession=chosenProfession
        recipe.difficulty=chosenDifficulty
        recipe.difficultyMinimum=DifficultyMinimum(chosenDifficulty)
        recipe.materials={}

        for _,row in ipairs(rows) do
            local itemID=tonumber(row.item:GetText())
            if itemID then
                recipe.materials[#recipe.materials+1]={
                    quantity=math.max(1,tonumber(row.qty:GetText()) or 1),
                    itemID=itemID
                }
            end
        end

        UI.selectedRecipeID=recipe.id
        UI.openProfessions[chosenProfession]=true
        UI.openDifficulties[chosenProfession]=UI.openDifficulties[chosenProfession] or {}
        UI.openDifficulties[chosenProfession][chosenDifficulty]=true
        f:Hide()
        UI.editor=nil
        RefreshRecipeList()
        RefreshDetails()
    end)

    local cancel=Button(f,"Annuler",95,30)
    cancel:SetPoint("BOTTOMRIGHT",-35,17)
    cancel:SetScript("OnClick",function() f:Hide() UI.editor=nil end)
end

-- ============================================================================
-- FENÊTRE PRINCIPALE
-- ============================================================================

local function BuildMain()
    if UI.main then
        UI.main:Show()
        RefreshRecipeList()
        RefreshDetails()
        return
    end

    local f=CreateFrame("Frame","GrimoireCraftMainFrame",UIParent,"BackdropTemplate")
    UI.main=f
    f:SetSize(980,640)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",f.StartMoving)
    f:SetScript("OnDragStop",f.StopMovingOrSizing)
    ApplyBackdrop(f,.99)
    f:SetBackdropColor(.025,.017,.012,.99)
    f:SetBackdropBorderColor(.30,.21,.11,.95)

    -- Fond principal : cuir brun/noir texturé créé pour le grimoire.
    local mainLeather=f:CreateTexture(nil,"BACKGROUND",nil,-8)
    mainLeather:SetPoint("TOPLEFT",4,-4); mainLeather:SetPoint("BOTTOMRIGHT",-4,4)
    mainLeather:SetTexture("Interface\\AddOns\\Omega_Hub\\Modules\\GrimoireCraft\\Media\\MainPage\\Leather")
    mainLeather:SetHorizTile(true); mainLeather:SetVertTile(true)
    mainLeather:SetVertexColor(.82,.76,.68,1)

    -- Enluminures nobles or/cuivre sur les quatre angles du grimoire.
    local cornerData = {
        {"TOPLEFT","CornerTL",0,0},
        {"TOPRIGHT","CornerTR",0,0},
        {"BOTTOMLEFT","CornerBL",0,0},
        {"BOTTOMRIGHT","CornerBR",0,0},
    }
    for _,c in ipairs(cornerData) do
        local tex=f:CreateTexture(nil,"OVERLAY")
        tex:SetSize(124,124)
        tex:SetPoint(c[1],f,c[1],c[3],c[4])
        tex:SetTexture("Interface\\AddOns\\Omega_Hub\\Modules\\GrimoireCraft\\Media\\"..c[2])
        tex:SetAlpha(.96)
    end

    local outerTop=f:CreateTexture(nil,"ARTWORK")
    outerTop:SetHeight(1)
    outerTop:SetPoint("TOPLEFT",112,-8)
    outerTop:SetPoint("TOPRIGHT",-112,-8)
    outerTop:SetColorTexture(.54,.37,.16,.58)

    local outerBottom=f:CreateTexture(nil,"ARTWORK")
    outerBottom:SetHeight(1)
    outerBottom:SetPoint("BOTTOMLEFT",112,8)
    outerBottom:SetPoint("BOTTOMRIGHT",-112,8)
    outerBottom:SetColorTexture(.54,.37,.16,.58)

    local outerLeft=f:CreateTexture(nil,"ARTWORK")
    outerLeft:SetWidth(1)
    outerLeft:SetPoint("TOPLEFT",8,-112)
    outerLeft:SetPoint("BOTTOMLEFT",8,112)
    outerLeft:SetColorTexture(.42,.23,.10,.55)

    local outerRight=f:CreateTexture(nil,"ARTWORK")
    outerRight:SetWidth(1)
    outerRight:SetPoint("TOPRIGHT",-8,-112)
    outerRight:SetPoint("BOTTOMRIGHT",-8,112)
    outerRight:SetColorTexture(.42,.23,.10,.55)

    local cover= f:CreateTexture(nil,"BACKGROUND",nil,-8)
    cover:SetPoint("TOPLEFT",8,-70)
    cover:SetPoint("BOTTOMRIGHT",-8,8)
    cover:SetTexture("Interface\\Buttons\\WHITE8X8")
    cover:SetVertexColor(.025,.018,.013,.42)

    local title=Label(f,"Grimoire des Artisans",0,-14,980,"QuestFont_Huge")
    title:SetJustifyH("CENTER")
    title:SetTextColor(.83,.69,.43)
    title:SetShadowColor(.03,.02,.01,.95)
    title:SetShadowOffset(1,-2)

    local subtitle=Label(f,"— Recettes & Savoir-Faire —",0,-43,980,"GameFontHighlight")
    subtitle:SetJustifyH("CENTER")
    subtitle:SetTextColor(.56,.45,.30)
    subtitle:SetShadowColor(.02,.015,.01,.75)
    subtitle:SetShadowOffset(1,-1)

    -- Bandeau supérieur enrichi : enluminures indépendantes, sans toucher à la logique de l'interface.
    local headerShade=f:CreateTexture(nil,"BACKGROUND",nil,-5)
    headerShade:SetPoint("TOPLEFT",20,-10); headerShade:SetPoint("TOPRIGHT",-20,-10)
    headerShade:SetHeight(105)
    headerShade:SetTexture("Interface\\Buttons\\WHITE8X8")
    headerShade:SetVertexColor(.018,.014,.011,.54)

    local headerLeft=f:CreateTexture(nil,"ARTWORK")
    headerLeft:SetSize(360,90); headerLeft:SetPoint("TOPLEFT",28,-16)
    headerLeft:SetTexture("Interface\\AddOns\\Omega_Hub\\Modules\\GrimoireCraft\\Media\\MainPage\\HeaderFlourishLeft")
    headerLeft:SetAlpha(.88)

    local headerRight=f:CreateTexture(nil,"ARTWORK")
    headerRight:SetSize(360,90); headerRight:SetPoint("TOPRIGHT",-28,-16)
    headerRight:SetTexture("Interface\\AddOns\\Omega_Hub\\Modules\\GrimoireCraft\\Media\\MainPage\\HeaderFlourishRight")
    headerRight:SetAlpha(.88)

    -- Petit sceau de livre sous le titre : pure décoration, aucun clic ni texte figé.
    local headerMedallion=f:CreateTexture(nil,"OVERLAY")
    headerMedallion:SetSize(48,48); headerMedallion:SetPoint("TOP",f,"TOP",0,-66)
    headerMedallion:SetTexture("Interface\\AddOns\\Omega_Hub\\Modules\\GrimoireCraft\\Media\\MainPage\\HeaderMedallion")

    local titleDivider=f:CreateTexture(nil,"ARTWORK")
    titleDivider:SetSize(520,28); titleDivider:SetPoint("TOP",f,"TOP",0,-77)
    titleDivider:SetTexture("Interface\\AddOns\\Omega_Hub\\Modules\\GrimoireCraft\\Media\\MainPage\\Divider")
    titleDivider:SetAlpha(.72)

    -- Fines règles latérales qui raccordent visuellement le bandeau aux deux pages.
    local headerBottom=f:CreateTexture(nil,"ARTWORK")
    headerBottom:SetHeight(1); headerBottom:SetPoint("TOPLEFT",42,-118); headerBottom:SetPoint("TOPRIGHT",-42,-118)
    headerBottom:SetColorTexture(.54,.37,.16,.62)


    local close=CreateFrame("Button",nil,f,"UIPanelCloseButton")
    close:SetPoint("TOPRIGHT",-5,-5)

    -- Sceau de diffusion : visible uniquement pour Selianà, Ivelnamj, Ritch et Nikolaii.
    if IsDatabaseConservator(UnitName("player")) then
        local dbSeal=CreateFrame("Button","GrimoireCraftDatabasePushButton",f)
        dbSeal:SetSize(34,34); dbSeal:SetPoint("TOPRIGHT",-40,-7); dbSeal:SetFrameLevel(f:GetFrameLevel()+20)
        local tex=dbSeal:CreateTexture(nil,"ARTWORK"); tex:SetAllPoints(); tex:SetTexture("Interface\\AddOns\\Omega_Hub\\Modules\\GrimoireCraft\\Media\\ManuscriptSeal"); tex:SetVertexColor(.92,.74,.39,1)
        local glow=dbSeal:CreateTexture(nil,"HIGHLIGHT"); glow:SetAllPoints(); glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border"); glow:SetBlendMode("ADD"); glow:SetAlpha(.45)
        dbSeal:SetScript("OnEnter",function(self)
            GameTooltip:SetOwner(self,"ANCHOR_BOTTOMLEFT")
            GameTooltip:AddLine("Sceau du conservateur",.93,.75,.40)
            GameTooltip:AddLine("Proposer votre database actuelle aux autres utilisateurs du Grimoire.",.78,.70,.55,true)
            GameTooltip:Show()
        end)
        dbSeal:SetScript("OnLeave",function() GameTooltip:Hide() end)
        dbSeal:SetScript("OnClick",function()
            StaticPopupDialogs["GRIMOIRECRAFT_DATABASE_PUSH_CONFIRM"] = StaticPopupDialogs["GRIMOIRECRAFT_DATABASE_PUSH_CONFIRM"] or {
                text="Proposer votre database actuelle à la guilde ?",
                button1="Proposer la mise à jour",button2="Annuler",timeout=0,whileDead=true,hideOnEscape=true,preferredIndex=3,
                OnAccept=function() BroadcastDatabaseUpdate() end,
            }
            StaticPopup_Show("GRIMOIRECRAFT_DATABASE_PUSH_CONFIRM")
        end)
        UI.databasePushButton=dbSeal
    end

    local add=Button(f,"Inscrire une recette",166,29)
    add:SetPoint("TOPLEFT",52,-96)
    add:SetScript("OnClick",function() OpenRecipeEditor(nil) end)

    local listBox=CreateFrame("Frame",nil,f,"BackdropTemplate")
    listBox:SetPoint("TOPLEFT",28,-126)
    listBox:SetSize(450,485)
    ApplyBackdrop(listBox,.96)
    listBox:SetBackdropColor(.095,.071,.044,.98)
    listBox:SetBackdropBorderColor(.31,.22,.12,.95)
    AddPaperTexture(listBox,1.00)
    AddPageEdgeShade(listBox,"RIGHT")
    AddPageWear(listBox)

    local pageGoldL=listBox:CreateTexture(nil,"ARTWORK")
    pageGoldL:SetPoint("TOPLEFT",10,-8)
    pageGoldL:SetPoint("TOPRIGHT",-10,-8)
    pageGoldL:SetHeight(1)
    pageGoldL:SetColorTexture(.62,.43,.18,.58)
    local pageCopperL=listBox:CreateTexture(nil,"ARTWORK")
    pageCopperL:SetPoint("BOTTOMLEFT",12,9)
    pageCopperL:SetPoint("BOTTOMRIGHT",-12,9)
    pageCopperL:SetHeight(1)
    pageCopperL:SetColorTexture(.43,.23,.10,.48)

    local tocTitle=Label(listBox,"Table des Recettes",0,-13,440,"QuestFont_Large")
    tocTitle:SetJustifyH("CENTER")
    tocTitle:SetTextColor(.25,.18,.11)
    AddGoldRule(listBox,-37,34,-34)
    AddPageNumber(listBox,"— I —",false)
    local leftNote=Label(listBox,"Métiers & recettes consignées",22,-458,390,"GameFontHighlightSmall")
    leftNote:SetJustifyH("CENTER")
    leftNote:SetTextColor(.38,.30,.21)

    local filterLabel=Label(listBox,"Afficher :",22,-50,62,"GameFontHighlightSmall")
    filterLabel:SetTextColor(.38,.30,.21)

    local filterNames={"Tous","Équipements","Composants","Consommables"}
    local filterX=70
    UI.recipeFilterButtons={}

    local function RefreshFilterButtonColors()
        for name,button in pairs(UI.recipeFilterButtons or {}) do
            local selected=(UI.recipeTypeFilter or "Tous")==name
            button._filterSelected=selected
            if selected then
                if button._skin then button._skin:SetTexture("Interface\\AddOns\\Omega_Hub\\Modules\\GrimoireCraft\\Media\\MainPage\\ButtonSelected") end
                button:SetBackdropColor(0,0,0,0); button:SetBackdropBorderColor(.82,.58,.20,1)
                button.label:SetTextColor(1,.88,.52)
            else
                if button._skin then button._skin:SetTexture("Interface\\AddOns\\Omega_Hub\\Modules\\GrimoireCraft\\Media\\MainPage\\ButtonNormal") end
                button:SetBackdropColor(0,0,0,0); button:SetBackdropBorderColor(.31,.22,.10,.85)
                button.label:SetTextColor(.90,.81,.62)
            end
        end
    end

    for _,filterName in ipairs(filterNames) do
        local w=(filterName=="Équipements" and 92) or (filterName=="Composants" and 88) or (filterName=="Consommables" and 98) or 48
        local b=Button(listBox,filterName,w,24)
        b:SetPoint("TOPLEFT",filterX,-44)
        UI.recipeFilterButtons[filterName]=b
        b:SetScript("OnEnter",function(self)
            if not self._filterSelected then
                self:SetBackdropColor(.055,.055,.050,.98)
                self:SetBackdropBorderColor(.35,.29,.18,1)
                self.label:SetTextColor(.95,.84,.61)
            end
        end)
        b:SetScript("OnLeave",function(self)
            RefreshFilterButtonColors()
        end)
        b:SetScript("OnClick",function()
            UI.recipeTypeFilter=filterName
            RefreshFilterButtonColors()
            RefreshRecipeList()
        end)
        filterX=filterX+w+4
    end
    RefreshFilterButtonColors()

    -- Filtre Favoris : petit sceau étoilé indépendant des catégories de recette.
    local favoriteFilter=Button(listBox,"",28,24)
    favoriteFilter:SetPoint("TOPRIGHT",-14,-44)
    local favoriteFilterIcon=favoriteFilter:CreateTexture(nil,"ARTWORK")
    favoriteFilterIcon:SetSize(20,20)
    favoriteFilterIcon:SetPoint("CENTER")
    local function RefreshFavoriteFilter()
        if UI.favoritesOnly then
            favoriteFilterIcon:SetTexture(FAVORITE_ON_ICON)
            favoriteFilter:SetBackdropColor(.20,.12,.035,.98)
            favoriteFilter:SetBackdropBorderColor(.88,.62,.20,1)
            favoriteFilter.label:SetTextColor(1,.84,.32)
        else
            favoriteFilterIcon:SetTexture(FAVORITE_OFF_ICON)
            favoriteFilter:SetBackdropColor(.055,.045,.032,.94)
            favoriteFilter:SetBackdropBorderColor(.31,.22,.10,.85)
            favoriteFilter.label:SetTextColor(.68,.56,.38)
        end
    end
    favoriteFilter:SetScript("OnEnter",function(self)
        favoriteFilterIcon:SetAlpha(1)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        GameTooltip:SetText(UI.favoritesOnly and "Afficher toutes les recettes" or "Afficher uniquement les favoris")
        GameTooltip:Show()
    end)
    favoriteFilter:SetScript("OnLeave",function() GameTooltip:Hide(); favoriteFilterIcon:SetAlpha(.92); RefreshFavoriteFilter() end)
    favoriteFilter:SetScript("OnClick",function()
        UI.favoritesOnly=not UI.favoritesOnly
        RefreshFavoriteFilter()
        RefreshRecipeList()
    end)
    RefreshFavoriteFilter()

    local listScroll=CreateFrame("ScrollFrame",nil,listBox,"UIPanelScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT",18,-76)
    listScroll:SetSize(412,377)

    UI.listContent=CreateFrame("Frame",nil,listScroll)
    UI.listContent:SetSize(385,377)
    listScroll:SetScrollChild(UI.listContent)

    local detailBox=CreateFrame("Frame",nil,f,"BackdropTemplate")
    detailBox:SetPoint("TOPLEFT",502,-126)
    detailBox:SetSize(450,485)
    ApplyBackdrop(detailBox,.96)
    detailBox:SetBackdropColor(.095,.071,.044,.98)
    detailBox:SetBackdropBorderColor(.31,.22,.12,.95)
    AddPaperTexture(detailBox,.96)
    AddPageEdgeShade(detailBox,"LEFT")
    AddPageWear(detailBox)

    local pageGoldR=detailBox:CreateTexture(nil,"ARTWORK")
    pageGoldR:SetPoint("TOPLEFT",10,-8)
    pageGoldR:SetPoint("TOPRIGHT",-10,-8)
    pageGoldR:SetHeight(1)
    pageGoldR:SetColorTexture(.62,.43,.18,.58)
    local pageCopperR=detailBox:CreateTexture(nil,"ARTWORK")
    pageCopperR:SetPoint("BOTTOMLEFT",12,9)
    pageCopperR:SetPoint("BOTTOMRIGHT",-12,9)
    pageCopperR:SetHeight(1)
    pageCopperR:SetColorTexture(.43,.23,.10,.48)
    AddPageNumber(detailBox,"— II —",true)
    local rightNote=Label(detailBox,"Notes de l'artisan",22,-458,390,"GameFontHighlightSmall")
    rightNote:SetJustifyH("CENTER")
    rightNote:SetTextColor(.38,.30,.21)

    UI.detailContent=CreateFrame("Frame",nil,detailBox)
    UI.detailContent:SetAllPoints()

    AddBookSpine(f)

    RefreshRecipeList()
    RefreshDetails()
end


-- ============================================================================
-- BOUTON LIBRE — accès rapide au Grimoire
-- Indépendant de la minicarte : position libre et persistante sur l'écran.
-- ============================================================================
local function ToggleGrimoireMain()
    if UI.main and UI.main:IsShown() then
        UI.main:Hide()
    else
        BuildMain()
    end
end

local function SaveGrimoireLauncherPosition(button)
    if not button or not DB then return end
    local cx,cy=button:GetCenter()
    local ux,uy=UIParent:GetCenter()
    if not cx or not cy or not ux or not uy then return end
    DB.launcherX=cx-ux
    DB.launcherY=cy-uy
end

local function UpdateGrimoireLauncherPosition(button)
    if not button then return end
    local x=(DB and tonumber(DB.launcherX)) or 430
    local y=(DB and tonumber(DB.launcherY)) or 210
    button:ClearAllPoints()
    button:SetPoint("CENTER",UIParent,"CENTER",x,y)
end

local function CreateGrimoireLauncherButton()
    if UI.launcherButton then return UI.launcherButton end

    local button=CreateFrame("Button","GrimoireCraftLauncherButton",UIParent,"BackdropTemplate")
    UI.launcherButton=button
    -- Alias conservé pour éviter toute régression avec un ancien code qui le rechercherait.
    UI.minimapButton=button
    button:SetSize(68,68)
    button:SetFrameStrata("HIGH")
    button:SetFrameLevel(20)
    button:SetMovable(true)
    button:SetClampedToScreen(true)
    button:RegisterForClicks("LeftButtonUp","RightButtonUp")
    button:RegisterForDrag("LeftButton")

    -- Ombre discrète pour détacher le médaillon du décor du jeu.
    local shadow=button:CreateTexture(nil,"BACKGROUND")
    shadow:SetSize(74,74)
    shadow:SetPoint("CENTER",2,-2)
    shadow:SetTexture("Interface\\AddOns\\Omega_Hub\\Modules\\GrimoireCraft\\Media\\UIIcons\\GrimoireLauncher")
    shadow:SetVertexColor(0,0,0,.46)

    -- Icône dédiée : véritable grimoire d’artisan, reliure, sceau et enclume gravée.
    local icon=button:CreateTexture(nil,"ARTWORK")
    button.icon=icon
    icon:SetAllPoints(button)
    icon:SetTexture("Interface\\AddOns\\Omega_Hub\\Modules\\GrimoireCraft\\Media\\UIIcons\\GrimoireLauncher")

    -- Halo au survol, sans cerclage de minicarte.
    local hover=button:CreateTexture(nil,"HIGHLIGHT")
    hover:SetSize(78,78)
    hover:SetPoint("CENTER")
    hover:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    hover:SetBlendMode("ADD")
    hover:SetVertexColor(.95,.68,.24,.55)

    button:SetScript("OnClick",function(self,mouseButton)
        -- Un relâchement après déplacement ne doit pas ouvrir/fermer le grimoire.
        if self._wasDragged then
            self._wasDragged=false
            return
        end
        if mouseButton=="LeftButton" or mouseButton=="RightButton" then
            ToggleGrimoireMain()
        end
    end)

    button:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_LEFT")
        GameTooltip:AddLine("Grimoire des Artisans",.95,.78,.38)
        GameTooltip:AddLine("Ouvrir le grimoire et consulter les savoir-faire",.82,.74,.61)
        GameTooltip:AddLine("Glisser : déplacer librement sur l'écran",.58,.50,.40)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave",function() GameTooltip:Hide() end)

    button:SetScript("OnDragStart",function(self)
        self._dragging=true
        self._wasDragged=true
        GameTooltip:Hide()
        self:StartMoving()
    end)
    button:SetScript("OnDragStop",function(self)
        self._dragging=false
        self:StopMovingOrSizing()
        SaveGrimoireLauncherPosition(self)
    end)

    UpdateGrimoireLauncherPosition(button)
    return button
end

-- ============================================================================
-- Intégration Omega Hub : le module ne s'affiche et ne communique que lorsqu'il
-- est activé depuis le panneau du Hub (/omh).
-- ============================================================================
local GC = {}
OmegaGrimoire = GC
local moduleEnabled = false

function GC:Enable()
    moduleEnabled = true
    CreateGrimoireLauncherButton():Show()
    OmegaHub:SetModuleLoaded("GrimoireCraft", true)
    if not OmegaHub._startingUp then
        OmegaHub.Print("Grimoire de Craft activé.  |cffAAAAAA/grimoire|r")
    end
    if C_Timer and C_Timer.After then C_Timer.After(2,AnnounceGrimoirePresence) else AnnounceGrimoirePresence() end
end

function GC:Disable()
    moduleEnabled = false
    for _,key in ipairs({"main","editor","transferSender","transferReceiver","launcherButton"}) do
        local frame=UI[key]
        if type(frame)=="table" and frame.Hide then frame:Hide() end
    end
    OmegaHub:SetModuleLoaded("GrimoireCraft", false)
    OmegaHub.Print("Grimoire de Craft désactivé.")
end

function GC:Toggle()
    if moduleEnabled then ToggleGrimoireMain() end
end

SLASH_GRIMOIRECRAFT1="/grimoire"
SLASH_GRIMOIRECRAFT2="/craft"
SLASH_GRIMOIRECRAFT3="/gc"
SlashCmdList.GRIMOIRECRAFT=function()
    if not moduleEnabled then
        OmegaHub.Print("Grimoire de Craft est désactivé.  |cffAAAAAA/omh|r pour l'activer.")
        return
    end
    BuildMain()
end

local events=CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
events:RegisterEvent("GUILDBANKFRAME_OPENED")
events:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED")
events:RegisterEvent("CHAT_MSG_SYSTEM")
events:RegisterEvent("CHAT_MSG_SAY")
events:RegisterEvent("CHAT_MSG_EMOTE")
events:RegisterEvent("CHAT_MSG_RAID")
events:RegisterEvent("CHAT_MSG_RAID_LEADER")
events:RegisterEvent("CHAT_MSG_PARTY")
events:RegisterEvent("CHAT_MSG_PARTY_LEADER")
events:RegisterEvent("CHAT_MSG_ADDON")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("GUILD_ROSTER_UPDATE")
events:SetScript("OnEvent",function(_,event,addonName,...)
    if event=="ADDON_LOADED" then
        if addonName==ADDON_NAME then
            InitDB()
            if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(TRANSFER_PREFIX)
            elseif RegisterAddonMessagePrefix then RegisterAddonMessagePrefix(TRANSFER_PREFIX) end
        end
        return
    elseif event=="PLAYER_LOGIN" then
        OmegaHub:RegisterModule({
            name    = "GrimoireCraft",
            title   = "Grimoire de Craft",
            desc    = "Recettes d'artisanat et transmission de savoir — /grimoire",
            version = GRIMOIRE_VERSION,
            module  = GC,
        })
        if OmegaHub:IsModuleEnabled("GrimoireCraft") then GC:Enable() end
        return
    end

    -- Module désactivé dans le Hub : aucun traitement ni échange réseau.
    if not moduleEnabled then return end

    if event=="CHAT_MSG_ADDON" then
        local prefix,message,channel,sender=addonName,...
        if prefix==TRANSFER_PREFIX then HandleTransferMessage(message,sender) end
        return
    elseif event and event:find("^CHAT_MSG_") then
        local message=addonName
        ParseCuisineRollMessage(message)
        return
    end

    if event=="PLAYER_ENTERING_WORLD" or event=="GUILD_ROSTER_UPDATE" then
        if C_Timer and C_Timer.After then C_Timer.After(1,AnnounceGrimoirePresence) else AnnounceGrimoirePresence() end
    elseif event=="BAG_UPDATE_DELAYED" then
        -- Mise à jour immédiate des couleurs lorsqu'un objet entre ou sort des sacs.
        if UI.main and UI.main:IsShown() and UI.selectedRecipeID then
            RefreshDetails()
        end
    elseif event=="GET_ITEM_INFO_RECEIVED" then
        if UI.main and UI.main:IsShown() then
            RefreshRecipeList()
            RefreshDetails()
        end
    elseif event=="GUILDBANKFRAME_OPENED" or event=="GUILDBANKBAGSLOTS_CHANGED" then
        local function UpdateGuildBankCache()
            ScanGuildBank()
            if UI.main and UI.main:IsShown() and UI.selectedRecipeID then
                RefreshDetails()
            end
        end
        if C_Timer and C_Timer.After then
            C_Timer.After(.20,UpdateGuildBankCache)
        else
            UpdateGuildBankCache()
        end
    end
end)