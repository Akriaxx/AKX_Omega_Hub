OS2 = OS2 or {}
OS2.DB = OS2.DB or {}

function OS2.DB.BuildLanternDatabaseTab(ctx)
    local DBSchema = (OS2.DB and OS2.DB.Schema) or {}

    local lantLabelStr = ctx.lantTab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lantLabelStr:SetPoint("TOPLEFT", ctx.lantTab, "TOPLEFT", ctx.X_LEFT, -8)
    lantLabelStr:SetText((DBSchema.GetPluralLabel and DBSchema.GetPluralLabel("lanterne")) or "Lanternes")
    ctx.UI.ApplyStrongLabel(lantLabelStr)

    local crystLabelStr = ctx.lantTab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    crystLabelStr:SetPoint("TOPLEFT", ctx.lantTab, "TOPLEFT", ctx.X_MID + 8, -8)
    crystLabelStr:SetText((DBSchema.GetPluralLabel and DBSchema.GetPluralLabel("cristal")) or "Réactifs")
    ctx.UI.ApplyStrongLabel(crystLabelStr)

    local colDiv1 = ctx.lantTab:CreateTexture(nil, "ARTWORK")
    ctx.UI.ApplySeparator(colDiv1, true)
    colDiv1:SetWidth(1)
    local divX1 = ctx.X_LEFT + ctx.COL_W + math.floor(ctx.COL_GAP / 2)
    colDiv1:SetPoint("TOP", ctx.lantTab, "TOPLEFT", divX1, -4)
    colDiv1:SetPoint("BOTTOM", ctx.lantTab, "BOTTOMLEFT", divX1, ctx.BTN_H - 4)

    local lantSF, lantSB = ctx.CreateScrollList(ctx.lantTab, ctx.X_LEFT, -ctx.HDR_H)
    local crystSF, crystSB = ctx.CreateScrollList(ctx.lantTab, ctx.X_MID, -ctx.HDR_H)

    local modSF, modSB
    if ctx.MODULES_ENABLED then
        local modLabelStr = ctx.lantTab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        modLabelStr:SetPoint("TOPLEFT", ctx.lantTab, "TOPLEFT", ctx.X_RIGHT + 8, -8)
        modLabelStr:SetText("Modules")
        ctx.UI.ApplyStrongLabel(modLabelStr)

        local colDiv2 = ctx.lantTab:CreateTexture(nil, "ARTWORK")
        ctx.UI.ApplySeparator(colDiv2, true)
        colDiv2:SetWidth(1)
        local divX2 = ctx.X_MID + ctx.COL_W + math.floor(ctx.COL_GAP / 2)
        colDiv2:SetPoint("TOP", ctx.lantTab, "TOPLEFT", divX2, -4)
        colDiv2:SetPoint("BOTTOM", ctx.lantTab, "BOTTOMLEFT", divX2, ctx.BTN_H - 4)

        modSF, modSB = ctx.CreateScrollList(ctx.lantTab, ctx.X_RIGHT, -ctx.HDR_H)
    end

    ctx.setRebuildLantList(function()
        ctx.BuildRows(lantSF, lantSB, OS2.Core.Models, "lanterne",
            ctx.lantEditBtns, ctx.lantLinkBtns, ctx.lantModBtns,
            function(idx)
                table.remove(OS2.Core.Models, idx)
                if OS2.RebuildCoreLookups then
                    OS2.RebuildCoreLookups()
                end
                ctx.RebuildLantList()
                if OS2.RefreshLanternPanel then OS2.RefreshLanternPanel() end
                if OS2.RefreshLanternConfigPanel then OS2.RefreshLanternConfigPanel() end
            end,
            function(idx)
                local item = OS2.Core.Models[idx]; if not item then return end
                ctx.OpenEditPanel("edit", item, "lanterne", function(payload)
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
                    ctx.RebuildLantList()
                    if OS2.RefreshLanternPanel then OS2.RefreshLanternPanel() end
                    if OS2.RefreshLanternConfigPanel then OS2.RefreshLanternConfigPanel() end
                end)
            end
        )
    end)

    ctx.setRebuildCrystList(function()
        ctx.BuildRows(crystSF, crystSB, OS2.Core.Crystals, "cristal",
            ctx.crystEditBtns, ctx.crystLinkBtns, ctx.crystModBtns,
            function(idx)
                table.remove(OS2.Core.Crystals, idx)
                if OS2.RebuildCoreLookups then
                    OS2.RebuildCoreLookups()
                end
                ctx.RebuildCrystList()
                if OS2.RefreshLanternPanel then OS2.RefreshLanternPanel() end
                if OS2.RefreshLanternConfigPanel then OS2.RefreshLanternConfigPanel() end
            end,
            function(idx)
                local item = OS2.Core.Crystals[idx]; if not item then return end
                ctx.OpenEditPanel("edit", item, "cristal", function(payload)
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
                    ctx.RebuildCrystList()
                    if OS2.RefreshLanternPanel then OS2.RefreshLanternPanel() end
                    if OS2.RefreshLanternConfigPanel then OS2.RefreshLanternConfigPanel() end
                end)
            end
        )
    end)

    local lantAddBtn = ctx.CreateAddButton(ctx.lantTab, ctx.X_LEFT + ctx.COL_W - 18, -4, function()
        ctx.OpenEditPanel("create", nil, "lanterne", function(payload)
            local key = ctx.GenerateKey(payload.label, "lanterne")
            table.insert(OS2.Core.Models, {
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
            ctx.RebuildLantList()
            if OS2.RefreshLanternPanel then OS2.RefreshLanternPanel() end
            if OS2.RefreshLanternConfigPanel then OS2.RefreshLanternConfigPanel() end
        end)
    end)
    lantAddBtn:ClearAllPoints()
    lantAddBtn:SetPoint("TOPRIGHT", ctx.lantTab, "TOPLEFT", ctx.X_LEFT + ctx.COL_W + 2, -5)

    local crystAddBtn = ctx.CreateAddButton(ctx.lantTab, ctx.X_MID + ctx.COL_W - 18, -4, function()
        ctx.OpenEditPanel("create", nil, "cristal", function(payload)
            local key = ctx.GenerateKey(payload.label, "cristal")
            table.insert(OS2.Core.Crystals, {
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
            ctx.RebuildCrystList()
            if OS2.RefreshLanternPanel then OS2.RefreshLanternPanel() end
            if OS2.RefreshLanternConfigPanel then OS2.RefreshLanternConfigPanel() end
        end)
    end)
    crystAddBtn:ClearAllPoints()
    crystAddBtn:SetPoint("TOPRIGHT", ctx.lantTab, "TOPLEFT", ctx.X_MID + ctx.COL_W + 2, -5)

    if ctx.MODULES_ENABLED then
        ctx.setRebuildModList(function()
            ctx.BuildRows(modSF, modSB, OS2.Core.Modules or {}, "lanternModule",
                ctx.modEditBtns, ctx.modLinkBtns, ctx.modModBtns,
                function(idx)
                    table.remove(OS2.Core.Modules, idx)
                    if OS2.RebuildCoreLookups then OS2.RebuildCoreLookups() end
                    ctx.RebuildModList()
                end,
                function(idx)
                    local item = OS2.Core.Modules[idx]; if not item then return end
                    ctx.OpenEditPanel("edit", item, "lanternModule", function(payload)
                        item.label = payload.label
                        item.desc  = payload.desc or ""
                        item.inventoryCheck = payload.inventoryCheck
                        item.inventoryItemId = payload.inventoryItemId
                        item.itemId = payload.itemId
                        item.auraEnabled = payload.auraEnabled
                        item.auraApplyRules = payload.auraApplyRules
                        item.auraRemoveRules = payload.auraRemoveRules
                        if OS2.RebuildCoreLookups then OS2.RebuildCoreLookups() end
                        ctx.RebuildModList()
                    end)
                end
            )
        end)

        local modAddBtn = ctx.CreateAddButton(ctx.lantTab, ctx.X_RIGHT + ctx.COL_W - 18, -4, function()
            ctx.OpenEditPanel("create", nil, "lanternModule", function(payload)
                local key = ctx.GenerateKey(payload.label, "lanternModule")
                table.insert(OS2.Core.Modules, {
                    key   = key,
                    label = payload.label,
                    desc  = payload.desc or "",
                    inventoryCheck = payload.inventoryCheck,
                    inventoryItemId = payload.inventoryItemId,
                    itemId = payload.itemId,
                    auraEnabled = payload.auraEnabled,
                    auraApplyRules = payload.auraApplyRules,
                    auraRemoveRules = payload.auraRemoveRules,
                })
                if OS2.RebuildCoreLookups then OS2.RebuildCoreLookups() end
                ctx.RebuildModList()
            end)
        end)
        modAddBtn:ClearAllPoints()
        modAddBtn:SetPoint("TOPRIGHT", ctx.lantTab, "TOPLEFT", ctx.X_RIGHT + ctx.COL_W + 2, -5)
    end
end
