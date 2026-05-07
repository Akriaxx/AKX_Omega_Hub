OS2 = OS2 or {}
OS2.DB = OS2.DB or {}

function OS2.DB.BuildTorchDatabaseTab(ctx)
    local DBSchema = (OS2.DB and OS2.DB.Schema) or {}
    local torchTab = ctx.tabCDB[(ctx.tabIndexByKey and ctx.tabIndexByKey["torche"]) or 3]
    if not torchTab then
        return
    end

    local torchHeader = torchTab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    torchHeader:SetPoint("TOPLEFT", torchTab, "TOPLEFT", ctx.X_LEFT, -8)
    torchHeader:SetText((DBSchema.GetPluralLabel and DBSchema.GetPluralLabel("torche")) or "Torches")
    ctx.UI.ApplyStrongLabel(torchHeader)

    local fuelHeader = torchTab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fuelHeader:SetPoint("TOPLEFT", torchTab, "TOPLEFT", ctx.X_MID + 8, -8)
    fuelHeader:SetText((DBSchema.GetPluralLabel and DBSchema.GetPluralLabel("combustible")) or "Combustibles")
    ctx.UI.ApplyStrongLabel(fuelHeader)

    local torchDiv = torchTab:CreateTexture(nil, "ARTWORK")
    ctx.UI.ApplySeparator(torchDiv, true)
    torchDiv:SetWidth(1)
    local torchDivX = ctx.X_LEFT + ctx.COL_W + math.floor(ctx.COL_GAP / 2)
    torchDiv:SetPoint("TOP", torchTab, "TOPLEFT", torchDivX, -4)
    torchDiv:SetPoint("BOTTOM", torchTab, "BOTTOMLEFT", torchDivX, ctx.BTN_H - 4)

    local torchSF, torchSB = ctx.CreateScrollList(torchTab, ctx.X_LEFT, -ctx.HDR_H)
    local fuelSF, fuelSB = ctx.CreateScrollList(torchTab, ctx.X_MID, -ctx.HDR_H)

    ctx.setRebuildTorchList(function()
        ctx.BuildRows(torchSF, torchSB, OS2.Core.TorchModels or {}, "torche",
            ctx.torchEditBtns, ctx.torchLinkBtns, ctx.torchModBtns,
            function(idx)
                table.remove(OS2.Core.TorchModels, idx)
                if OS2.RebuildCoreLookups then
                    OS2.RebuildCoreLookups()
                end
                ctx.RebuildTorchList()
            end,
            function(idx)
                local item = OS2.Core.TorchModels[idx]
                if not item then return end
                ctx.OpenEditPanel("edit", item, "torche", function(payload)
                    item.label = payload.label
                    item.mult = payload.mult
                    item.desc = payload.desc
                    item.inventoryCheck = payload.inventoryCheck
                    item.inventoryItemId = payload.inventoryItemId
                    item.itemId = payload.itemId
                    item.consumable = payload.consumable
                    item.auraEnabled = payload.auraEnabled
                    item.auraApplyRules = payload.auraApplyRules
                    item.auraRemoveRules = payload.auraRemoveRules
                    item.disableEnabled = payload.disableEnabled
                    item.disableChannels = payload.disableChannels
                    item.disablePhrases = payload.disablePhrases
                    item.enablePhrases = payload.enablePhrases
                    item.disablePhrase = payload.disablePhrase
                    item.enablePhrase = payload.enablePhrase
                    if OS2.RebuildCoreLookups then
                        OS2.RebuildCoreLookups()
                    end
                    ctx.RebuildTorchList()
                end)
            end
        )
    end)

    ctx.setRebuildFuelList(function()
        ctx.BuildRows(fuelSF, fuelSB, OS2.Core.TorchFuels or {}, "combustible",
            ctx.fuelEditBtns, ctx.fuelLinkBtns, ctx.fuelModBtns,
            function(idx)
                table.remove(OS2.Core.TorchFuels, idx)
                if OS2.RebuildCoreLookups then
                    OS2.RebuildCoreLookups()
                end
                ctx.RebuildFuelList()
            end,
            function(idx)
                local item = OS2.Core.TorchFuels[idx]
                if not item then return end
                ctx.OpenEditPanel("edit", item, "combustible", function(payload)
                    item.label = payload.label
                    item.time = payload.time
                    item.desc = payload.desc
                    item.inventoryCheck = payload.inventoryCheck
                    item.inventoryItemId = payload.inventoryItemId
                    item.itemId = payload.itemId
                    item.consumable = payload.consumable
                    item.auraEnabled = payload.auraEnabled
                    item.auraApplyRules = payload.auraApplyRules
                    item.auraRemoveRules = payload.auraRemoveRules
                    item.disableEnabled = payload.disableEnabled
                    item.disableChannels = payload.disableChannels
                    item.disablePhrases = payload.disablePhrases
                    item.enablePhrases = payload.enablePhrases
                    item.disablePhrase = payload.disablePhrase
                    item.enablePhrase = payload.enablePhrase
                    if OS2.RebuildCoreLookups then
                        OS2.RebuildCoreLookups()
                    end
                    ctx.RebuildFuelList()
                end)
            end
        )
    end)

    local torchAddBtn = ctx.CreateAddButton(torchTab, ctx.X_LEFT + ctx.COL_W - 18, -4, function()
        ctx.OpenEditPanel("create", nil, "torche", function(payload)
            local key = ctx.GenerateKey(payload.label, "torche")
            table.insert(OS2.Core.TorchModels, {
                key = key,
                label = payload.label,
                mult = payload.mult,
                desc = payload.desc,
                inventoryCheck = payload.inventoryCheck,
                inventoryItemId = payload.inventoryItemId,
                itemId = payload.itemId,
                consumable = payload.consumable,
                auraEnabled = payload.auraEnabled,
                auraApplyRules = payload.auraApplyRules,
                auraRemoveRules = payload.auraRemoveRules,
                disableEnabled = payload.disableEnabled,
                disableChannels = payload.disableChannels,
                disablePhrases = payload.disablePhrases,
                enablePhrases = payload.enablePhrases,
                disablePhrase = payload.disablePhrase,
                enablePhrase = payload.enablePhrase,
            })
            if OS2.RebuildCoreLookups then
                OS2.RebuildCoreLookups()
            end
            ctx.RebuildTorchList()
        end)
    end)
    torchAddBtn:ClearAllPoints()
    torchAddBtn:SetPoint("TOPRIGHT", torchTab, "TOPLEFT", ctx.X_LEFT + ctx.COL_W + 2, -5)

    local fuelAddBtn = ctx.CreateAddButton(torchTab, ctx.X_MID + ctx.COL_W - 18, -4, function()
        ctx.OpenEditPanel("create", nil, "combustible", function(payload)
            local key = ctx.GenerateKey(payload.label, "combustible")
            table.insert(OS2.Core.TorchFuels, {
                key = key,
                label = payload.label,
                time = payload.time,
                desc = payload.desc,
                inventoryCheck = payload.inventoryCheck,
                inventoryItemId = payload.inventoryItemId,
                itemId = payload.itemId,
                consumable = payload.consumable,
                auraEnabled = payload.auraEnabled,
                auraApplyRules = payload.auraApplyRules,
                auraRemoveRules = payload.auraRemoveRules,
                disableEnabled = payload.disableEnabled,
                disableChannels = payload.disableChannels,
                disablePhrases = payload.disablePhrases,
                enablePhrases = payload.enablePhrases,
                disablePhrase = payload.disablePhrase,
                enablePhrase = payload.enablePhrase,
            })
            if OS2.RebuildCoreLookups then
                OS2.RebuildCoreLookups()
            end
            ctx.RebuildFuelList()
        end)
    end)
    fuelAddBtn:ClearAllPoints()
    fuelAddBtn:SetPoint("TOPRIGHT", torchTab, "TOPLEFT", ctx.X_MID + ctx.COL_W + 2, -5)
end

function OS2.DB.BuildGenericDatabaseTabs(ctx)
    local CAT_SF_W = ctx.CAT_SF_W or (ctx.DB_W - ctx.PAD * 2 - ctx.SB_W - ctx.SB_GAP)

    for i, mi in ipairs(ctx.TABS_ITEMS or {}) do
        if mi.key ~= "lanterne" and mi.key ~= "torche" and mi.key ~= "gourde" then
            local tab = ctx.tabCDB[i]
            local key = mi.key

            local hdr = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            hdr:SetPoint("TOPLEFT", tab, "TOPLEFT", ctx.PAD, -8)
            hdr:SetText(mi.dbLabel or mi.label)
            ctx.UI.ApplyStrongLabel(hdr)

            local catEditBtns = {}
            local catLinkBtns = {}
            local catModBtns = {}

            local catSF = CreateFrame("ScrollFrame", nil, tab)
            catSF:SetPoint("TOPLEFT", tab, "TOPLEFT", ctx.PAD, -ctx.HDR_H)
            catSF:SetSize(CAT_SF_W, ctx.LIST_H)
            catSF:EnableMouseWheel(true)

            local catTrack = tab:CreateTexture(nil, "BACKGROUND")
            catTrack:SetColorTexture(0.07, 0.07, 0.07, 1)
            catTrack:SetWidth(ctx.SB_W)
            catTrack:SetPoint("TOPLEFT", catSF, "TOPRIGHT", ctx.SB_GAP, 0)
            catTrack:SetPoint("BOTTOMLEFT", catSF, "BOTTOMRIGHT", ctx.SB_GAP, 0)

            local catSB = CreateFrame("Slider", nil, tab)
            catSB:SetPoint("TOPLEFT", catSF, "TOPRIGHT", ctx.SB_GAP, 0)
            catSB:SetPoint("BOTTOMLEFT", catSF, "BOTTOMRIGHT", ctx.SB_GAP, 0)
            catSB:SetWidth(ctx.SB_W)
            catSB:SetOrientation("VERTICAL")
            catSB:SetMinMaxValues(0, 0)
            catSB:SetValue(0)
            local catThumb = catSB:CreateTexture(nil, "THUMB")
            catThumb:SetSize(ctx.SB_W - 2, 30)
            catThumb:SetColorTexture(0.50, 0.42, 0.22, 0.85)
            catSB:SetThumbTexture(catThumb)
            catSF:SetScript("OnMouseWheel", function(_, delta)
                local cur = catSB:GetValue()
                local _, mx = catSB:GetMinMaxValues()
                catSB:SetValue(math.max(0, math.min(mx, cur - delta * ctx.ROW_H * 3)))
            end)
            catSB:SetScript("OnValueChanged", function(_, v)
                catSF:SetVerticalScroll(v)
            end)

            local capturedKey = key
            local rebuildRef = {}

            ctx.CreateAddButton(tab, ctx.PAD + CAT_SF_W - 16, -4, function()
                ctx.OpenEditPanel("create", nil, capturedKey, function(payload)
                    local data = (OS2.Core.Categories and OS2.Core.Categories[capturedKey]) or {}
                    local generatedKey = ctx.GenerateKey(payload.label, capturedKey)
                    table.insert(data, {
                        key = generatedKey,
                        label = payload.label,
                        desc = payload.desc or "",
                        inventoryCheck = payload.inventoryCheck,
                        inventoryItemId = payload.inventoryItemId,
                        itemId = payload.itemId,
                        consumable = payload.consumable,
                        auraEnabled = payload.auraEnabled,
                        auraApplyRules = payload.auraApplyRules,
                        auraRemoveRules = payload.auraRemoveRules,
                    })
                    if rebuildRef.fn then
                        rebuildRef.fn()
                    end
                end)
            end)

            local function RebuildCatList()
                local data = (OS2.Core.Categories and OS2.Core.Categories[capturedKey]) or {}
                ctx.BuildRows(catSF, catSB, data, capturedKey,
                    catEditBtns, catLinkBtns, catModBtns,
                    function(idx)
                        table.remove(data, idx)
                        RebuildCatList()
                    end,
                    function(idx)
                        local it = data[idx]
                        if not it then return end
                        ctx.OpenEditPanel("edit", it, capturedKey, function(payload)
                            it.label = payload.label
                            it.desc = payload.desc or ""
                            it.inventoryCheck = payload.inventoryCheck
                            it.inventoryItemId = payload.inventoryItemId
                            it.itemId = payload.itemId
                            it.consumable = payload.consumable
                            it.auraEnabled = payload.auraEnabled
                            it.auraApplyRules = payload.auraApplyRules
                            it.auraRemoveRules = payload.auraRemoveRules
                            RebuildCatList()
                        end)
                    end
                )
            end

            rebuildRef.fn = RebuildCatList
            ctx.genericCatInfos[#ctx.genericCatInfos + 1] = {
                key = key,
                editBtns = catEditBtns,
                linkBtns = catLinkBtns,
                modBtns = catModBtns,
                rebuildFn = RebuildCatList,
            }
        end
    end
end
