local ADDON_NAME, ns = ...

local MEDIA = "Interface\\Buttons\\WHITE8x8"
local FONT = "Fonts\\FRIZQT__.TTF"
local FRAME_TYPES = { "player", "target", "focus", "pet", "targettarget", "party", "boss" }
local DISPLAY_NAMES = { player="Player", target="Target", focus="Focus", pet="Pet", targettarget="Target of Target", party="Party", boss="Boss" }
local TEXTURE_NAMES = { flat="Flat", blizzard="Blizzard" }
local HEALTH_NAMES = { automatic="Automatic", green="Green", blue="Blue", gray="Gray", red="Red" }
local POWER_NAMES = { automatic="Automatic", blue="Blue", purple="Purple", gray="Gray" }
local TEXTURE_ORDER = { "flat", "blizzard" }
local HEALTH_ORDER = { "automatic", "green", "blue", "gray", "red" }
local POWER_ORDER = { "automatic", "blue", "purple", "gray" }
local FONT_NAMES = { friz="Friz Quadrata", arial="Arial Narrow", morpheus="Morpheus", skurri="Skurri" }
local FONT_ORDER = { "friz", "arial", "morpheus", "skurri" }
local VALIGN_NAMES = { TOP="Top", MIDDLE="Center", BOTTOM="Bottom" }
local VALIGN_ORDER = { "TOP", "MIDDLE", "BOTTOM" }
local AURA_TYPES = { "buffs", "debuffs", "defensives" }
local AURA_NAMES = { buffs="Buffs", debuffs="Debuffs", defensives="Defensives" }
local ANCHOR_NAMES = { TOP="Top", BOTTOM="Bottom" }
local GROWTH_NAMES = { RIGHT="Right", LEFT="Left" }
local ANCHOR_ORDER = { "TOP", "BOTTOM" }
local GROWTH_ORDER = { "RIGHT", "LEFT" }
local GROUP_ORIENTATION_NAMES = { VERTICAL="Vertical", HORIZONTAL="Horizontal" }
local GROUP_ORIENTATION_ORDER = { "VERTICAL", "HORIZONTAL" }

local selectedType = "player"
local selectedAura = "buffs"
local selectedPage = "frames"
local config, framesPage, aurasPage
local widthSlider, heightSlider, powerSlider, fontSlider, portraitSlider, bgSlider, borderSlider
local auraSizeSlider, auraCountSlider, auraSpacingSlider, auraXSlider, auraYSlider
local selectedLabel, statusText, nameButton, healthTextButton, portraitButton, sideButton, textureButton, healthColorButton, powerColorButton, fontButton, nameAlignButton, healthAlignButton
local auraLabel, auraEnableButton, auraTextButton, auraAnchorButton, auraGrowthButton, frameLockButton, auraLockButton, applyChangesButton
local frameTab, auraTab
local partyLayoutPanel, partyOrientationButton, partyDirectionButton, partySpacingSlider, partyIncludePlayerButton
local frameButtons, frameEnableChecks, auraButtons = {}, {}, {}
local refreshing = false
local working, auraWorking, partyWorking = {}, {}, {}
local pendingEnabled, pendingAuraLayouts = {}, {}
local pendingTrackedBuffs = nil
local buffFilterPanel, seenBuffButtons, trackedBuffButtons = nil, {}, {}
local trackedBuffWindow, manageTrackedButton, clearSeenButton
local pendingPartyIncludePlayer = nil
local hasPendingChanges = false

local function Round(v) return math.floor((v or 0) + 0.5) end

local function MakeButton(parent, text, width, height)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, height)
    b:SetText(text)
    return b
end

local function MakeSlider(parent, name, label, minValue, maxValue, step, width)
    local slider = CreateFrame("Slider", "MIUF_" .. name .. "Slider", parent, "OptionsSliderTemplate")
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetWidth(width or 235)
    local text, low, high = _G[slider:GetName() .. "Text"], _G[slider:GetName() .. "Low"], _G[slider:GetName() .. "High"]
    if text then text:SetText(label) end
    if low then low:SetText(tostring(minValue)) end
    if high then high:SetText(tostring(maxValue)) end

    -- Sliders are convenient for rough adjustment, but exact unit-frame values
    -- should also be easy to type.  Keep one small edit box synchronized with
    -- every slider so either input method drives the same OnValueChanged hooks.
    local valueBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    valueBox:SetSize(52, 20)
    valueBox:SetAutoFocus(false)
    valueBox:SetJustifyH("CENTER")
    valueBox:SetPoint("TOP", slider, "BOTTOM", 0, -1)
    slider.ValueBox = valueBox

    local function FormatValue(value)
        if step and step < 1 then
            return string.format("%.2f", value)
        end
        return tostring(Round(value))
    end

    local function CommitValue()
        local value = tonumber(valueBox:GetText())
        if not value then
            valueBox:SetText(FormatValue(slider:GetValue()))
            valueBox:ClearFocus()
            return
        end
        value = math.max(minValue, math.min(maxValue, value))
        if step and step > 0 then
            value = minValue + math.floor(((value - minValue) / step) + 0.5) * step
            value = math.max(minValue, math.min(maxValue, value))
        end
        slider:SetValue(value)
        valueBox:SetText(FormatValue(slider:GetValue()))
        valueBox:ClearFocus()
    end

    slider:SetScript("OnValueChanged", function(self, value)
        if not self.ValueBox:HasFocus() then
            self.ValueBox:SetText(FormatValue(value))
        end
    end)
    valueBox:SetScript("OnEnterPressed", CommitValue)
    valueBox:SetScript("OnEscapePressed", function(self)
        self:SetText(FormatValue(slider:GetValue()))
        self:ClearFocus()
    end)
    valueBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    valueBox:SetScript("OnEditFocusLost", function(self)
        local value = tonumber(self:GetText())
        if value then
            value = math.max(minValue, math.min(maxValue, value))
            if step and step > 0 then
                value = minValue + math.floor(((value - minValue) / step) + 0.5) * step
                value = math.max(minValue, math.min(maxValue, value))
            end
            slider:SetValue(value)
        end
        self:SetText(FormatValue(slider:GetValue()))
    end)
    return slider
end


local function MakeSection(parent, title, width, height)
    local section = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    section:SetSize(width, height)
    section:SetBackdrop({ bgFile=MEDIA, edgeFile=MEDIA, edgeSize=1 })
    section:SetBackdropColor(0.02, 0.025, 0.03, 0.55)
    section:SetBackdropBorderColor(0.18, 0.22, 0.28, 0.95)

    local label = section:CreateFontString(nil, "OVERLAY")
    label:SetFont(FONT, 12, "OUTLINE")
    label:SetPoint("TOPLEFT", 10, -8)
    label:SetText(title)
    label:SetTextColor(0.82, 0.88, 0.95)
    section.Title = label
    return section
end

local function Cycle(current, order)
    for i, value in ipairs(order) do
        if value == current then return order[(i % #order) + 1] end
    end
    return order[1]
end

local function AuraAvailable(unitType, auraType)
    if unitType == "boss" then return false end
    if auraType == "buffs" then
        return unitType == "player" or unitType == "target" or unitType == "focus" or unitType == "party" or unitType == "targettarget"
    end
    if auraType == "debuffs" then return unitType ~= "pet" end
    if auraType == "defensives" then return unitType == "player" or unitType == "party" end
    return false
end

local function ChooseAvailableAura()
    if AuraAvailable(selectedType, selectedAura) then return end
    for _, auraType in ipairs(AURA_TYPES) do
        if AuraAvailable(selectedType, auraType) then
            selectedAura = auraType
            return
        end
    end
end

local function GetPendingEnabled(unitType)
    if pendingEnabled[unitType] ~= nil then return pendingEnabled[unitType] end
    return ns.IsFrameTypeEnabled(unitType)
end

local function GetPendingAuraLayout(unitType, auraType)
    local base = ns.GetAuraLayout(unitType, auraType)
    if not base then return nil end
    local result = {}
    for k, v in pairs(base) do result[k] = v end
    if pendingAuraLayouts[unitType] and pendingAuraLayouts[unitType][auraType] then
        for k, v in pairs(pendingAuraLayouts[unitType][auraType]) do result[k] = v end
    end
    return result
end

local function CopyTrackedBuffs(source)
    local result = {}
    for spellID, info in pairs(source or {}) do
        result[tonumber(spellID) or spellID] = type(info) == "table" and { name = info.name, icon = info.icon } or {}
    end
    return result
end

local function GetWorkingTrackedBuffs()
    return pendingTrackedBuffs or ns.GetTrackedBuffs()
end

local function GetBuffPickerUnits()
    if selectedType == "party" then
        local units = { "party1", "party2", "party3", "party4" }
        local includePlayer = partyWorking and partyWorking.includePlayer
        if includePlayer then units[#units + 1] = "player" end
        return units
    end
    if selectedType == "player" or selectedType == "target" or selectedType == "focus" or selectedType == "targettarget" then
        return { selectedType }
    end
    return {}
end

local function GetCurrentSelectedBuffs()
    local result, seen = {}, {}
    if InCombatLockdown() or not C_UnitAuras or not C_UnitAuras.GetUnitAuras then return result end

    for _, unit in ipairs(GetBuffPickerUnits()) do
        local ok, auras = pcall(C_UnitAuras.GetUnitAuras, unit, "HELPFUL|PLAYER", 40)
        if ok and type(auras) == "table" then
            for _, aura in ipairs(auras) do
                local spellID = aura and tonumber(aura.spellId)
                if spellID and not seen[spellID] then
                    seen[spellID] = true
                    local name = aura.name
                    local icon = aura.icon
                    if C_Spell then
                        if not name and C_Spell.GetSpellName then name = C_Spell.GetSpellName(spellID) end
                        if not icon and C_Spell.GetSpellTexture then icon = C_Spell.GetSpellTexture(spellID) end
                    end
                    result[#result + 1] = { spellID = spellID, name = name or ("Spell " .. spellID), icon = icon }
                end
            end
        end
    end

    table.sort(result, function(a, b) return (a.name or "") < (b.name or "") end)
    for _, info in ipairs(result) do
        if ns.RecordSeenBuff then ns.RecordSeenBuff(info.spellID, info.name, info.icon) end
    end
    return result
end

local function MarkPending(message)
    hasPendingChanges = true
    if applyChangesButton then applyChangesButton:SetEnabled(true) end
    if statusText and message then statusText:SetText(message .. "  Click Apply Changes when ready.") end
end

local function StageAuraValue(key, value)
    if refreshing or not AuraAvailable(selectedType, selectedAura) then return end
    pendingAuraLayouts[selectedType] = pendingAuraLayouts[selectedType] or {}
    pendingAuraLayouts[selectedType][selectedAura] = pendingAuraLayouts[selectedType][selectedAura] or {}
    pendingAuraLayouts[selectedType][selectedAura][key] = value
    auraWorking[key] = value
    MarkPending(DISPLAY_NAMES[selectedType] .. " " .. AURA_NAMES[selectedAura] .. " change staged.")
end

local function CopyWorking()
    local appearance = ns.GetAppearance(selectedType)
    working = {}
    for k, v in pairs(appearance) do working[k] = v end
    ChooseAvailableAura()
    auraWorking = {}
    local layout = GetPendingAuraLayout(selectedType, selectedAura)
    if layout then for k, v in pairs(layout) do auraWorking[k] = v end end
    partyWorking = {}
    if selectedType == "party" or selectedType == "boss" then
        local groupLayout = ns.GetGroupLayout(selectedType)
        if groupLayout then for k, v in pairs(groupLayout) do partyWorking[k] = v end end
        if selectedType == "party" and pendingPartyIncludePlayer ~= nil then partyWorking.includePlayer = pendingPartyIncludePlayer end
    end
end

local function RefreshToggleButtons()
    nameButton:SetText("Name: " .. (working.showName and "On" or "Off"))
    healthTextButton:SetText("Health %: " .. (working.showHealthText and "On" or "Off"))
    portraitButton:SetText("Portrait: " .. (working.showPortrait and "On" or "Off"))
    sideButton:SetText("Portrait Side: " .. (working.portraitSide == "RIGHT" and "Right" or "Left"))
    textureButton:SetText("Texture: " .. (TEXTURE_NAMES[working.texture] or working.texture))
    healthColorButton:SetText("Health: " .. (HEALTH_NAMES[working.healthColor] or working.healthColor))
    powerColorButton:SetText("Power: " .. (POWER_NAMES[working.powerColor] or working.powerColor))
    fontButton:SetText("Font: " .. (FONT_NAMES[working.fontFace] or FONT_NAMES.friz))
    nameAlignButton:SetText("Name V: " .. (VALIGN_NAMES[working.nameVAlign] or "Center"))
    healthAlignButton:SetText("Health V: " .. (VALIGN_NAMES[working.healthVAlign] or "Center"))
end

local function RefreshFrameButtons()
    for unitType, button in pairs(frameButtons) do
        button:SetEnabled(unitType ~= selectedType)
        if frameEnableChecks[unitType] then frameEnableChecks[unitType]:SetChecked(GetPendingEnabled(unitType)) end
    end
end

local function RefreshAuraButtons()
    for auraType, button in pairs(auraButtons) do
        button:SetEnabled(AuraAvailable(selectedType, auraType) and auraType ~= selectedAura)
    end
end

local function RefreshBuffFilterPanel()
    if not buffFilterPanel then return end
    local show = selectedPage == "auras" and selectedAura == "buffs"
    buffFilterPanel:SetShown(show)
    if not show then return end

    -- Refresh discovery from the currently selected unit(s) when that API is safe.
    GetCurrentSelectedBuffs()

    local tracked = GetWorkingTrackedBuffs()
    local trackedList = {}
    for spellID, meta in pairs(tracked or {}) do
        local id = tonumber(spellID)
        if id then trackedList[#trackedList + 1] = { spellID=id, name=meta.name or ("Spell "..id), icon=meta.icon } end
    end
    table.sort(trackedList, function(a,b) return (a.name or "") < (b.name or "") end)

    if manageTrackedButton then
        local count = #trackedList
        manageTrackedButton:SetText(count > 0 and ("Manage Tracked Buffs (" .. count .. ")") or "Manage Tracked Buffs")
    end

    if not trackedBuffWindow then return end
    local seenList = {}
    for spellID, meta in pairs(ns.GetSeenBuffs() or {}) do
        local id = tonumber(spellID)
        if id and not tracked[id] then
            seenList[#seenList + 1] = { spellID=id, name=meta.name or ("Spell "..id), icon=meta.icon, lastSeen=meta.lastSeen or 0 }
        end
    end
    table.sort(seenList, function(a,b)
        if (a.lastSeen or 0) ~= (b.lastSeen or 0) then return (a.lastSeen or 0) > (b.lastSeen or 0) end
        return (a.name or "") < (b.name or "")
    end)

    local function Configure(button, info, isTracked)
        if not info then button:Hide(); return end
        button.info = info
        button.icon:SetTexture(info.icon or 134400)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(info.name or ("Spell " .. info.spellID))
            GameTooltip:AddLine(isTracked and "Click to stop tracking this buff." or "Click to track this buff on unit frames.", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("Spell ID: " .. tostring(info.spellID), 0.55, 0.55, 0.55)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", GameTooltip_Hide)
        button:SetScript("OnClick", function()
            if InCombatLockdown() then statusText:SetText("Tracked buffs can only be edited out of combat."); return end
            if not pendingTrackedBuffs then pendingTrackedBuffs = CopyTrackedBuffs(ns.GetTrackedBuffs()) end
            if isTracked then
                pendingTrackedBuffs[info.spellID] = nil
                MarkPending((info.name or "Buff") .. " will no longer be tracked.")
            else
                pendingTrackedBuffs[info.spellID] = { name = info.name, icon = info.icon }
                MarkPending((info.name or "Buff") .. " will be tracked.")
            end
            RefreshBuffFilterPanel()
        end)
        button:Show()
    end

    for i, button in ipairs(seenBuffButtons) do Configure(button, seenList[i], false) end
    for i, button in ipairs(trackedBuffButtons) do Configure(button, trackedList[i], true) end
end

local function SetSliderEnabled(slider, enabled)
    if enabled then slider:Enable() else slider:Disable() end
end

local function RefreshAuraControls()
    RefreshBuffFilterPanel()
    local available = AuraAvailable(selectedType, selectedAura) and auraWorking.iconSize ~= nil
    auraLabel:SetText("Aura layout: " .. (AURA_NAMES[selectedAura] or selectedAura))
    SetSliderEnabled(auraSizeSlider, available)
    SetSliderEnabled(auraCountSlider, available)
    SetSliderEnabled(auraSpacingSlider, available)
    SetSliderEnabled(auraXSlider, available)
    SetSliderEnabled(auraYSlider, available)
    auraEnableButton:SetEnabled(available)
    auraTextButton:SetEnabled(available and auraWorking.enabled ~= false)
    auraAnchorButton:SetEnabled(available and auraWorking.enabled ~= false)
    auraGrowthButton:SetEnabled(available and auraWorking.enabled ~= false)
    if available then
        auraEnableButton:SetText("Enabled: " .. (auraWorking.enabled ~= false and "On" or "Off"))
        auraTextButton:SetText("Text: " .. (auraWorking.showText ~= false and "On" or "Off"))
        auraSizeSlider:SetValue(auraWorking.iconSize)
        auraCountSlider:SetValue(auraWorking.maxCount)
        auraSpacingSlider:SetValue(auraWorking.spacing)
        auraXSlider:SetValue(auraWorking.xOffset)
        auraYSlider:SetValue(auraWorking.yOffset)
        auraAnchorButton:SetText("Position: " .. (ANCHOR_NAMES[auraWorking.anchor] or auraWorking.anchor))
        auraGrowthButton:SetText("Grow: " .. (GROWTH_NAMES[auraWorking.growth] or auraWorking.growth))
    else
        auraEnableButton:SetText("Enabled: N/A")
        auraTextButton:SetText("Text: N/A")
        auraAnchorButton:SetText("Position: N/A")
        auraGrowthButton:SetText("Grow: N/A")
    end
end

local function RefreshGroupLayoutControls()
    if not partyLayoutPanel then return end
    local isGroup = selectedType == "party" or selectedType == "boss"
    partyLayoutPanel:SetShown(isGroup)
    if not isGroup then return end
    if partyLayoutPanel.Title then partyLayoutPanel.Title:SetText(selectedType == "party" and "Party group layout" or "Boss group layout") end
    partyIncludePlayerButton:SetShown(selectedType == "party")
    partyOrientationButton:SetText("Layout: " .. (GROUP_ORIENTATION_NAMES[partyWorking.orientation] or "Vertical"))
    local direction = partyWorking.direction or "DOWN"
    partyDirectionButton:SetText("Grow: " .. direction:sub(1,1) .. direction:sub(2):lower())
    partySpacingSlider:SetValue(partyWorking.spacing or 32)
    partyIncludePlayerButton:SetText("Include Player: " .. (partyWorking.includePlayer and "On" or "Off"))
end

local function ShowPage(page)
    selectedPage = page
    framesPage:SetShown(page == "frames")
    aurasPage:SetShown(page == "auras")
    frameTab:SetEnabled(page ~= "frames")
    auraTab:SetEnabled(page ~= "auras")
    ns.RefreshConfig()
end

function ns.RefreshConfig()
    if not config or not config:IsShown() then return end
    refreshing = true
    CopyWorking()
    RefreshFrameButtons()
    selectedLabel:SetText(DISPLAY_NAMES[selectedType] .. " Settings")
    if selectedType == "boss" and selectedPage == "auras" then
        selectedPage = "frames"
        framesPage:Show()
        aurasPage:Hide()
    end
    auraTab:SetShown(selectedType ~= "boss")

    if selectedPage == "frames" then
        local size = ns.GetSize(selectedType)
        widthSlider:SetValue(size.width)
        heightSlider:SetValue(size.height)
        powerSlider:SetValue(ns.GetPowerPercent(selectedType))
        fontSlider:SetValue(working.fontSize)
        portraitSlider:SetValue(working.portraitPercent)
        bgSlider:SetValue(working.backgroundOpacity)
        borderSlider:SetValue(working.borderOpacity)
        RefreshToggleButtons()
        RefreshGroupLayoutControls()
        frameLockButton:SetText(ns.AreFrameMoversLocked() and "Unlock Frame Movers" or "Lock Frame Movers")
        statusText:SetText(InCombatLockdown() and "Frame changes are disabled during combat." or (hasPendingChanges and "Pending changes are waiting. Click Apply Changes when ready." or "Frame appearance can apply live. Enable/disable changes wait for Apply Changes."))
    else
        RefreshAuraButtons()
        RefreshAuraControls()
        auraLockButton:SetText(ns.AreAuraMoversLocked() and "Unlock Aura Movers" or "Lock Aura Movers")
        statusText:SetText(InCombatLockdown() and "Aura changes are disabled during combat." or (hasPendingChanges and "Pending changes are waiting. Click Apply Changes when ready." or "Aura position and icon size preview live. Protected aura changes wait for Apply Changes."))
    end
    refreshing = false
end

local function ApplySelected()
    if refreshing then return end
    if InCombatLockdown() then statusText:SetText("Cannot change unit frames during combat."); return end
    ns.SaveSize(selectedType, Round(widthSlider:GetValue()), Round(heightSlider:GetValue()))
    ns.SavePowerPercent(selectedType, Round(powerSlider:GetValue()))
    working.fontSize = Round(fontSlider:GetValue())
    working.portraitPercent = Round(portraitSlider:GetValue())
    working.backgroundOpacity = Round(bgSlider:GetValue())
    working.borderOpacity = Round(borderSlider:GetValue())
    ns.SaveAppearance(selectedType, working)
    if selectedType == "party" or selectedType == "boss" then
        local values = {
            orientation = partyWorking.orientation or "VERTICAL",
            direction = partyWorking.direction or "DOWN",
            spacing = Round(partySpacingSlider:GetValue()),
        }
        if selectedType == "party" then values.includePlayer = ns.GetGroupLayout("party").includePlayer and true or false end
        ns.SaveGroupLayout(selectedType, values)
    end
    if ns.ApplyFrameType then ns.ApplyFrameType(selectedType) end
    if selectedType == "party" and ns.ApplyPartyLayout then ns.ApplyPartyLayout() end
    if selectedType == "boss" and ns.ApplyBossLayout then ns.ApplyBossLayout() end
    statusText:SetText(DISPLAY_NAMES[selectedType] .. " appearance applied.")
end

local function SaveAuraPositionLive()
    if refreshing or InCombatLockdown() then return end
    if not AuraAvailable(selectedType, selectedAura) then return end
    auraWorking.xOffset = Round(auraXSlider:GetValue())
    auraWorking.yOffset = Round(auraYSlider:GetValue())
    ns.SaveAuraLayout(selectedType, selectedAura, {
        xOffset = auraWorking.xOffset,
        yOffset = auraWorking.yOffset,
        anchor = auraWorking.anchor,
    })
    if ns.ApplyAuraPositions then ns.ApplyAuraPositions(selectedType, selectedAura) end
end

local function ApplyPendingChanges()
    if InCombatLockdown() then statusText:SetText("Cannot apply protected frame changes during combat."); return end
    if not hasPendingChanges then statusText:SetText("No pending reload changes."); return end

    for unitType, enabled in pairs(pendingEnabled) do
        ns.SetFrameTypeEnabled(unitType, enabled)
    end
    for unitType, auraTypes in pairs(pendingAuraLayouts) do
        for auraType, values in pairs(auraTypes) do
            ns.SaveAuraLayout(unitType, auraType, values)
        end
    end
    if pendingPartyIncludePlayer ~= nil then
        ns.SaveGroupLayout("party", { includePlayer = pendingPartyIncludePlayer })
    end
    if pendingTrackedBuffs then ns.SetTrackedBuffs(pendingTrackedBuffs) end

    pendingEnabled = {}
    pendingAuraLayouts = {}
    pendingPartyIncludePlayer = nil
    pendingTrackedBuffs = nil
    hasPendingChanges = false

    -- Applying protected changes is a clean configuration checkpoint.
    -- Never carry visible movers across the reload caused by Apply Changes.
    ns.SetFrameMoversLockedState(true)
    ns.SetAuraMoversLockedState(true)
    if ns.SetFrameMoversLocked then ns.SetFrameMoversLocked(true) end
    if ns.SetAuraMoversLocked then ns.SetAuraMoversLocked(true) end

    ReloadUI()
end

local function ResetFrameSelected()
    if InCombatLockdown() then statusText:SetText("Cannot reset during combat."); return end
    ns.ResetFrameAppearance(selectedType)
    if ns.ApplyFrameType then ns.ApplyFrameType(selectedType) end
    ns.RefreshConfig()
    statusText:SetText(DISPLAY_NAMES[selectedType] .. " frame settings reset.")
end

local function ResetAuraSelected()
    if InCombatLockdown() then statusText:SetText("Cannot reset during combat."); return end
    if not AuraAvailable(selectedType, selectedAura) then return end
    ns.ResetAuraLayout(selectedType, selectedAura)
    if ns.ApplyAuraPositions then ns.ApplyAuraPositions(selectedType, selectedAura) end
    ns.RefreshConfig()
    statusText:SetText(DISPLAY_NAMES[selectedType] .. " " .. AURA_NAMES[selectedAura] .. " reset. Reload to rebuild icon layout.")
end

local function ToggleFrameLock()
    if InCombatLockdown() then statusText:SetText("Cannot unlock frame movers during combat."); return end
    local locked = not ns.AreFrameMoversLocked()
    ns.SetFrameMoversLockedState(locked)
    if ns.SetFrameMoversLocked then ns.SetFrameMoversLocked(locked) end
    ns.RefreshConfig()
end

local function ToggleAuraLock()
    if InCombatLockdown() then statusText:SetText("Cannot unlock aura movers during combat."); return end
    local locked = not ns.AreAuraMoversLocked()
    ns.SetAuraMoversLockedState(locked)
    if ns.SetAuraMoversLocked then ns.SetAuraMoversLocked(locked) end
    ns.RefreshConfig()
end

local function ResetAll()
    if InCombatLockdown() then statusText:SetText("Cannot reset during combat."); return end
    ns.ResetAllSettings()
    if ns.ResetLayout then ns.ResetLayout() end
    ns.RefreshConfig()
    statusText:SetText("All frame and aura settings reset. Reload to fully rebuild aura defaults.")
end

local function CreateConfigShell()
    config = CreateFrame("Frame", "MIUF_ConfigFrame", UIParent, "BackdropTemplate")
    config:SetSize(900, 650)
    config:SetPoint("CENTER")
    config:SetFrameStrata("DIALOG")
    config:SetClampedToScreen(true)
    config:SetMovable(true)
    config:EnableMouse(true)
    config:RegisterForDrag("LeftButton")
    config:SetScript("OnDragStart", config.StartMoving)
    config:SetScript("OnDragStop", config.StopMovingOrSizing)
    config:SetBackdrop({ bgFile=MEDIA, edgeFile=MEDIA, edgeSize=1 })
    config:SetBackdropColor(0.035,0.035,0.04,0.97)
    config:SetBackdropBorderColor(0.2,0.55,0.85,1)

    local title = config:CreateFontString(nil, "OVERLAY")
    title:SetFont(FONT, 17, "OUTLINE")
    title:SetPoint("TOPLEFT", 18, -16)
    title:SetText("MythInc Unit Frames")

    local version = config:CreateFontString(nil, "OVERLAY")
    version:SetFont(FONT, 10, "OUTLINE")
    version:SetPoint("LEFT", title, "RIGHT", 10, -1)
    version:SetText(ns.version)
    version:SetTextColor(0.65,0.7,0.75)

    local close = MakeButton(config, "X", 28, 24)
    close:SetPoint("TOPRIGHT", -10, -10)
    close:SetScript("OnClick", function() config:Hide() end)

    frameTab = MakeButton(config, "Frames", 110, 28)
    frameTab:SetPoint("TOPLEFT", 180, -48)
    frameTab:SetScript("OnClick", function() ShowPage("frames") end)
    auraTab = MakeButton(config, "Auras", 110, 28)
    auraTab:SetPoint("LEFT", frameTab, "RIGHT", 8, 0)
    auraTab:SetScript("OnClick", function() ShowPage("auras") end)

    local divider = config:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(0.18,0.18,0.2,1)
    divider:SetPoint("TOPLEFT", 155, -52)
    divider:SetPoint("BOTTOMLEFT", 155, 18)
    divider:SetWidth(1)

    local choose = config:CreateFontString(nil, "OVERLAY")
    choose:SetFont(FONT, 11, "OUTLINE")
    choose:SetPoint("TOPLEFT", 16, -58)
    choose:SetText("Units   Enabled")

    local previous
    for _, unitType in ipairs(FRAME_TYPES) do
        local row = CreateFrame("Frame", nil, config)
        row:SetSize(130, 28)
        if previous then
            row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -6)
        else
            row:SetPoint("TOPLEFT", 12, -80)
        end

        local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        check:SetSize(24, 24)
        check:SetPoint("LEFT", 0, 0)
        check:SetChecked(ns.IsFrameTypeEnabled(unitType))
        check:SetScript("OnClick", function(self)
            if InCombatLockdown() then
                self:SetChecked(ns.IsFrameTypeEnabled(unitType))
                statusText:SetText("Cannot enable or disable unit frames during combat.")
                return
            end
            pendingEnabled[unitType] = self:GetChecked() and true or false
            MarkPending(DISPLAY_NAMES[unitType] .. (self:GetChecked() and " will be enabled." or " will be disabled."))
            if ns.PreviewUnitTypeMovers then ns.PreviewUnitTypeMovers(unitType, self:GetChecked()) end
        end)
        frameEnableChecks[unitType] = check

        local button = MakeButton(row, DISPLAY_NAMES[unitType], 101, 28)
        button:SetPoint("LEFT", check, "RIGHT", 1, 0)
        button:SetScript("OnClick", function() selectedType = unitType; ns.RefreshConfig() end)
        frameButtons[unitType] = button
        previous = row
    end

    local resetAll = MakeButton(config, "Reset All", 90, 26)
    resetAll:SetPoint("BOTTOMLEFT", 16, 20)
    resetAll:SetScript("OnClick", ResetAll)

    applyChangesButton = MakeButton(config, "Apply Changes", 120, 28)
    applyChangesButton:SetPoint("BOTTOMLEFT", 170, 18)
    applyChangesButton:SetEnabled(false)
    applyChangesButton:SetScript("OnClick", ApplyPendingChanges)

    selectedLabel = config:CreateFontString(nil, "OVERLAY")
    selectedLabel:SetFont(FONT, 14, "OUTLINE")
    selectedLabel:SetPoint("TOPLEFT", 180, -94)

    statusText = config:CreateFontString(nil, "OVERLAY")
    statusText:SetFont(FONT, 9, "OUTLINE")
    statusText:SetPoint("BOTTOMLEFT", 520, 22)
    statusText:SetWidth(355)
    statusText:SetJustifyH("LEFT")
end

local function CreateFramesPage()
    framesPage = CreateFrame("Frame", nil, config)
    framesPage:SetPoint("TOPLEFT", 160, -80)
    framesPage:SetPoint("BOTTOMRIGHT", -10, 50)

    -- Keep the Frames page organized by purpose instead of adding more top-level tabs.
    -- Layout/geometry lives on the left; text and appearance live on the right.
    local layoutSection = MakeSection(framesPage, "Frame Layout", 330, 405)
    layoutSection:SetPoint("TOPLEFT", 20, -62)

    local textSection = MakeSection(framesPage, "Text", 345, 235)
    textSection:SetPoint("TOPLEFT", 365, -62)

    local appearanceSection = MakeSection(framesPage, "Appearance", 345, 175)
    appearanceSection:SetPoint("TOPLEFT", 365, -297)

    widthSlider = MakeSlider(layoutSection, "Width", "Width", 100, 600, 1, 285)
    widthSlider:SetPoint("TOPLEFT", 20, -42)
    heightSlider = MakeSlider(layoutSection, "Height", "Height", 24, 150, 1, 285)
    heightSlider:SetPoint("TOPLEFT", 20, -102)
    powerSlider = MakeSlider(layoutSection, "PowerPercent", "Power bar height (%)", 10, 40, 1, 285)
    powerSlider:SetPoint("TOPLEFT", 20, -162)
    portraitSlider = MakeSlider(layoutSection, "PortraitPercent", "Portrait width (%)", 12, 40, 1, 285)
    portraitSlider:SetPoint("TOPLEFT", 20, -222)

    portraitButton = MakeButton(layoutSection, "Portrait: Off", 118, 26)
    portraitButton:SetPoint("TOPLEFT", 15, -282)
    portraitButton:SetScript("OnClick", function() working.showPortrait = not working.showPortrait; RefreshToggleButtons() end)
    sideButton = MakeButton(layoutSection, "Portrait Side: Left", 155, 26)
    sideButton:SetPoint("LEFT", portraitButton, "RIGHT", 8, 0)
    sideButton:SetScript("OnClick", function() working.portraitSide = (working.portraitSide == "LEFT") and "RIGHT" or "LEFT"; RefreshToggleButtons() end)

    partyLayoutPanel = CreateFrame("Frame", nil, layoutSection)
    partyLayoutPanel:SetSize(300, 78)
    partyLayoutPanel:SetPoint("TOPLEFT", 15, -320)

    local partyTitle = partyLayoutPanel:CreateFontString(nil, "OVERLAY")
    partyTitle:SetFont(FONT, 10, "OUTLINE")
    partyTitle:SetPoint("TOPLEFT", 0, 0)
    partyTitle:SetText("Party group layout")
    partyTitle:SetTextColor(0.70, 0.76, 0.82)
    partyLayoutPanel.Title = partyTitle

    partyOrientationButton = MakeButton(partyLayoutPanel, "Layout: Vertical", 128, 24)
    partyOrientationButton:SetPoint("TOPLEFT", 0, -18)
    partyOrientationButton:SetScript("OnClick", function()
        partyWorking.orientation = Cycle(partyWorking.orientation or "VERTICAL", GROUP_ORIENTATION_ORDER)
        partyWorking.direction = partyWorking.orientation == "HORIZONTAL" and "RIGHT" or "DOWN"
        RefreshGroupLayoutControls()
    end)

    partyDirectionButton = MakeButton(partyLayoutPanel, "Grow: Down", 105, 24)
    partyDirectionButton:SetPoint("LEFT", partyOrientationButton, "RIGHT", 7, 0)
    partyDirectionButton:SetScript("OnClick", function()
        if partyWorking.orientation == "HORIZONTAL" then
            partyWorking.direction = partyWorking.direction == "LEFT" and "RIGHT" or "LEFT"
        else
            partyWorking.direction = partyWorking.direction == "UP" and "DOWN" or "UP"
        end
        RefreshGroupLayoutControls()
    end)

    partyIncludePlayerButton = MakeButton(partyLayoutPanel, "Include Player: Off", 140, 24)
    partyIncludePlayerButton:SetPoint("TOPLEFT", 0, -48)
    partyIncludePlayerButton:SetScript("OnClick", function()
        if refreshing then return end
        partyWorking.includePlayer = not partyWorking.includePlayer
        pendingPartyIncludePlayer = partyWorking.includePlayer and true or false
        RefreshGroupLayoutControls()
        MarkPending("Party player inclusion change staged.")
    end)

    partySpacingSlider = MakeSlider(partyLayoutPanel, "PartySpacing", "Spacing", 0, 80, 1, 125)
    partySpacingSlider:SetPoint("TOPLEFT", 160, -43)
    partySpacingSlider:HookScript("OnValueChanged", function(_, value) if not refreshing then partyWorking.spacing = Round(value) end end)

    fontButton = MakeButton(textSection, "Font: Friz Quadrata", 190, 26)
    fontButton:SetPoint("TOPLEFT", 15, -34)
    fontButton:SetScript("OnClick", function() working.fontFace = Cycle(working.fontFace or "friz", FONT_ORDER); RefreshToggleButtons() end)

    fontSlider = MakeSlider(textSection, "FontSize", "Font size", 8, 24, 1, 285)
    fontSlider:SetPoint("TOPLEFT", 20, -82)

    nameButton = MakeButton(textSection, "Name: On", 105, 26)
    nameButton:SetPoint("TOPLEFT", 15, -145)
    nameButton:SetScript("OnClick", function() working.showName = not working.showName; RefreshToggleButtons() end)
    nameAlignButton = MakeButton(textSection, "Name V: Center", 145, 26)
    nameAlignButton:SetPoint("LEFT", nameButton, "RIGHT", 8, 0)
    nameAlignButton:SetScript("OnClick", function() working.nameVAlign = Cycle(working.nameVAlign or "MIDDLE", VALIGN_ORDER); RefreshToggleButtons() end)

    healthTextButton = MakeButton(textSection, "Health %: On", 105, 26)
    healthTextButton:SetPoint("TOPLEFT", 15, -181)
    healthTextButton:SetScript("OnClick", function() working.showHealthText = not working.showHealthText; RefreshToggleButtons() end)
    healthAlignButton = MakeButton(textSection, "Health V: Center", 145, 26)
    healthAlignButton:SetPoint("LEFT", healthTextButton, "RIGHT", 8, 0)
    healthAlignButton:SetScript("OnClick", function() working.healthVAlign = Cycle(working.healthVAlign or "MIDDLE", VALIGN_ORDER); RefreshToggleButtons() end)

    textureButton = MakeButton(appearanceSection, "Texture: Flat", 145, 26)
    textureButton:SetPoint("TOPLEFT", 15, -34)
    textureButton:SetScript("OnClick", function() working.texture = Cycle(working.texture, TEXTURE_ORDER); RefreshToggleButtons() end)
    healthColorButton = MakeButton(appearanceSection, "Health: Automatic", 155, 26)
    healthColorButton:SetPoint("LEFT", textureButton, "RIGHT", 8, 0)
    healthColorButton:SetScript("OnClick", function() working.healthColor = Cycle(working.healthColor, HEALTH_ORDER); RefreshToggleButtons() end)

    powerColorButton = MakeButton(appearanceSection, "Power: Automatic", 155, 26)
    powerColorButton:SetPoint("TOPLEFT", 15, -68)
    powerColorButton:SetScript("OnClick", function() working.powerColor = Cycle(working.powerColor, POWER_ORDER); RefreshToggleButtons() end)

    bgSlider = MakeSlider(appearanceSection, "BackgroundOpacity", "Background opacity (%)", 0, 100, 1, 135)
    bgSlider:SetPoint("TOPLEFT", 180, -75)
    borderSlider = MakeSlider(appearanceSection, "BorderOpacity", "Border opacity (%)", 0, 100, 1, 135)
    borderSlider:SetPoint("TOPLEFT", 180, -125)

    local apply = MakeButton(framesPage, "Apply Frame", 100, 28)
    apply:SetPoint("BOTTOMLEFT", 20, 8)
    apply:SetScript("OnClick", ApplySelected)
    local resetFrame = MakeButton(framesPage, "Reset Frame", 105, 28)
    resetFrame:SetPoint("LEFT", apply, "RIGHT", 8, 0)
    resetFrame:SetScript("OnClick", ResetFrameSelected)
    frameLockButton = MakeButton(framesPage, "Unlock Frame Movers", 145, 28)
    frameLockButton:SetPoint("LEFT", resetFrame, "RIGHT", 8, 0)
    frameLockButton:SetScript("OnClick", ToggleFrameLock)
end

local function CreateAurasPage()
    aurasPage = CreateFrame("Frame", nil, config)
    aurasPage:SetPoint("TOPLEFT", 160, -80)
    aurasPage:SetPoint("BOTTOMRIGHT", -10, 50)

    auraLabel = aurasPage:CreateFontString(nil, "OVERLAY")
    auraLabel:SetFont(FONT, 13, "OUTLINE")
    auraLabel:SetPoint("TOPLEFT", 20, -70)
    auraLabel:SetText("Aura layout")

    local prevAura
    for _, auraType in ipairs(AURA_TYPES) do
        local button = MakeButton(aurasPage, AURA_NAMES[auraType], 105, 26)
        if prevAura then
            button:SetPoint("LEFT", prevAura, "RIGHT", 7, 0)
        else
            button:SetPoint("TOPLEFT", 20, -96)
        end
        button:SetScript("OnClick", function() selectedAura = auraType; ns.RefreshConfig() end)
        auraButtons[auraType] = button
        prevAura = button
    end

    auraEnableButton = MakeButton(aurasPage, "Enabled: On", 125, 26)
    auraEnableButton:SetPoint("TOPLEFT", 20, -132)
    auraEnableButton:SetScript("OnClick", function()
        if InCombatLockdown() then statusText:SetText("Cannot enable or disable protected auras during combat."); return end
        if not AuraAvailable(selectedType, selectedAura) then return end
        auraWorking.enabled = auraWorking.enabled == false
        StageAuraValue("enabled", auraWorking.enabled)
        RefreshAuraControls()
        if ns.PreviewAuraMover then ns.PreviewAuraMover(selectedType, selectedAura, auraWorking.enabled ~= false) end
    end)

    auraTextButton = MakeButton(aurasPage, "Text: On", 110, 26)
    auraTextButton:SetPoint("LEFT", auraEnableButton, "RIGHT", 7, 0)
    auraTextButton:SetScript("OnClick", function()
        if InCombatLockdown() then statusText:SetText("Cannot change protected aura text during combat."); return end
        if not AuraAvailable(selectedType, selectedAura) then return end
        auraWorking.showText = auraWorking.showText == false
        StageAuraValue("showText", auraWorking.showText)
        RefreshAuraControls()
    end)

    auraSizeSlider = MakeSlider(aurasPage, "AuraIconSize", "Icon size", 12, 40, 1, 180)
    auraSizeSlider:SetPoint("TOPLEFT", 35, -195)
    auraSizeSlider:HookScript("OnValueChanged", function(_, value)
        if refreshing or InCombatLockdown() then return end
        if not AuraAvailable(selectedType, selectedAura) then return end
        local size = Round(value)
        StageAuraValue("iconSize", size)
        if ns.PreviewAuraIconSize then ns.PreviewAuraIconSize(selectedType, selectedAura, size) end
    end)
    auraCountSlider = MakeSlider(aurasPage, "AuraCount", "Max icons", 1, 12, 1, 180)
    auraCountSlider:SetPoint("TOPLEFT", 260, -195)
    auraCountSlider:HookScript("OnValueChanged", function(_, value) StageAuraValue("maxCount", Round(value)) end)
    auraSpacingSlider = MakeSlider(aurasPage, "AuraSpacing", "Spacing", 0, 10, 1, 180)
    auraSpacingSlider:SetPoint("TOPLEFT", 485, -195)
    auraSpacingSlider:HookScript("OnValueChanged", function(_, value) StageAuraValue("spacing", Round(value)) end)

    auraXSlider = MakeSlider(aurasPage, "AuraXOffset", "X offset", -400, 400, 1, 180)
    auraXSlider:SetPoint("TOPLEFT", 35, -275)
    auraXSlider:HookScript("OnValueChanged", SaveAuraPositionLive)
    auraYSlider = MakeSlider(aurasPage, "AuraYOffset", "Y offset", -400, 400, 1, 180)
    auraYSlider:SetPoint("TOPLEFT", 260, -275)
    auraYSlider:HookScript("OnValueChanged", SaveAuraPositionLive)

    auraAnchorButton = MakeButton(aurasPage, "Position: Top", 125, 26)
    auraAnchorButton:SetPoint("TOPLEFT", 485, -264)
    auraAnchorButton:SetScript("OnClick", function()
        auraWorking.anchor = Cycle(auraWorking.anchor, ANCHOR_ORDER)
        ns.SaveAuraLayout(selectedType, selectedAura, {
            anchor = auraWorking.anchor,
            xOffset = Round(auraXSlider:GetValue()),
            yOffset = Round(auraYSlider:GetValue()),
        })
        if ns.ApplyAuraPositions then ns.ApplyAuraPositions(selectedType, selectedAura) end
        RefreshAuraControls()
    end)

    auraGrowthButton = MakeButton(aurasPage, "Grow: Right", 125, 26)
    auraGrowthButton:SetPoint("LEFT", auraAnchorButton, "RIGHT", 7, 0)
    auraGrowthButton:SetScript("OnClick", function() auraWorking.growth = Cycle(auraWorking.growth, GROWTH_ORDER); StageAuraValue("growth", auraWorking.growth); RefreshAuraControls() end)

    buffFilterPanel = CreateFrame("Frame", nil, aurasPage)
    buffFilterPanel:SetPoint("TOPLEFT", 20, -350)
    buffFilterPanel:SetSize(650, 72)

    local buffTrackingLabel = buffFilterPanel:CreateFontString(nil, "OVERLAY")
    buffTrackingLabel:SetFont(FONT, 11, "OUTLINE")
    buffTrackingLabel:SetPoint("TOPLEFT", 0, 0)
    buffTrackingLabel:SetText("Tracked Buffs: only buffs you choose are shown on normal buff frames.")

    local function MakeAuraChoiceButton(parent, x, y)
        local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
        b:SetSize(34, 34); b:SetPoint("TOPLEFT", x, y)
        b:SetBackdrop({ bgFile=MEDIA, edgeFile=MEDIA, edgeSize=1 })
        b:SetBackdropColor(0.05,0.05,0.05,0.9); b:SetBackdropBorderColor(0.3,0.3,0.3,1)
        b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetPoint("TOPLEFT", 2, -2); b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        return b
    end

    manageTrackedButton = MakeButton(buffFilterPanel, "Manage Tracked Buffs", 180, 24)
    manageTrackedButton:SetPoint("TOPLEFT", 0, -25)

    trackedBuffWindow = CreateFrame("Frame", "MIUF_TrackedBuffWindow", UIParent, "BackdropTemplate")
    trackedBuffWindow:SetSize(620, 300)
    trackedBuffWindow:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    trackedBuffWindow:SetFrameStrata("DIALOG")
    trackedBuffWindow:SetClampedToScreen(true)
    trackedBuffWindow:SetMovable(true)
    trackedBuffWindow:EnableMouse(true)
    trackedBuffWindow:RegisterForDrag("LeftButton")
    trackedBuffWindow:SetScript("OnDragStart", trackedBuffWindow.StartMoving)
    trackedBuffWindow:SetScript("OnDragStop", trackedBuffWindow.StopMovingOrSizing)
    trackedBuffWindow:SetBackdrop({ bgFile=MEDIA, edgeFile=MEDIA, edgeSize=1 })
    trackedBuffWindow:SetBackdropColor(0.035, 0.04, 0.05, 0.98)
    trackedBuffWindow:SetBackdropBorderColor(0.35, 0.38, 0.45, 1)
    trackedBuffWindow:Hide()

    local trackedTitle = trackedBuffWindow:CreateFontString(nil, "OVERLAY")
    trackedTitle:SetFont(FONT, 14, "OUTLINE")
    trackedTitle:SetPoint("TOPLEFT", 14, -12)
    trackedTitle:SetText("Manage Tracked Buffs")

    local seenTitle = trackedBuffWindow:CreateFontString(nil, "OVERLAY")
    seenTitle:SetFont(FONT, 11, "OUTLINE")
    seenTitle:SetPoint("TOPLEFT", 14, -42)
    seenTitle:SetText("Seen Buffs - click to track (most recently seen first)")

    for i=1,24 do
        local col=(i-1)%12; local row=math.floor((i-1)/12)
        seenBuffButtons[i] = MakeAuraChoiceButton(trackedBuffWindow, 14 + col*40, -60 - row*40)
    end

    local trackedListTitle = trackedBuffWindow:CreateFontString(nil, "OVERLAY")
    trackedListTitle:SetFont(FONT, 11, "OUTLINE")
    trackedListTitle:SetPoint("TOPLEFT", 14, -150)
    trackedListTitle:SetText("Tracked Buffs - click to stop tracking")

    for i=1,24 do
        local col=(i-1)%12; local row=math.floor((i-1)/12)
        trackedBuffButtons[i] = MakeAuraChoiceButton(trackedBuffWindow, 14 + col*40, -168 - row*40)
    end

    local closeTracked = MakeButton(trackedBuffWindow, "X", 26, 22)
    closeTracked:SetPoint("TOPRIGHT", -8, -8)
    closeTracked:SetScript("OnClick", function()
        trackedBuffWindow:Hide()
        if config then config:Show() end
    end)

    clearSeenButton = MakeButton(trackedBuffWindow, "Clear Seen History", 130, 24)
    clearSeenButton:SetPoint("BOTTOMLEFT", 14, 12)
    clearSeenButton:SetScript("OnClick", function()
        if InCombatLockdown() then statusText:SetText("Seen buff history can only be cleared out of combat."); return end
        ns.ClearSeenBuffs()
        statusText:SetText("Seen buff history cleared. Tracked buffs were not changed.")
        RefreshBuffFilterPanel()
    end)

    local backTrackedButton = MakeButton(trackedBuffWindow, "Back to Auras", 120, 24)
    backTrackedButton:SetPoint("LEFT", clearSeenButton, "RIGHT", 8, 0)
    backTrackedButton:SetScript("OnClick", function()
        trackedBuffWindow:Hide()
        if config then config:Show() end
    end)

    manageTrackedButton:SetScript("OnClick", function()
        RefreshBuffFilterPanel()
        if config then config:Hide() end
        trackedBuffWindow:Show()
    end)

    local auraNote = aurasPage:CreateFontString(nil, "OVERLAY")
    auraNote:SetFont(FONT, 10, "OUTLINE")
    auraNote:SetPoint("TOPLEFT", 20, -435)
    auraNote:SetWidth(650)
    auraNote:SetJustifyH("LEFT")
    auraNote:SetText("Normal Buffs are opt-in: MIUF remembers player-applied buffs it sees, but only displays buffs you choose under Manage Tracked Buffs. External Defensives remain automatic. Tracking changes are staged until Apply Changes.")
    auraNote:SetTextColor(0.72,0.75,0.8)

    local resetAura = MakeButton(aurasPage, "Reset Aura", 105, 28)
    resetAura:SetPoint("BOTTOMLEFT", 20, 8)
    resetAura:SetScript("OnClick", ResetAuraSelected)
    auraLockButton = MakeButton(aurasPage, "Unlock Aura Movers", 145, 28)
    auraLockButton:SetPoint("LEFT", resetAura, "RIGHT", 8, 0)
    auraLockButton:SetScript("OnClick", ToggleAuraLock)
end

local function CreateConfig()
    if config then return config end
    CreateConfigShell()
    CreateFramesPage()
    CreateAurasPage()
    local auraWatcher = CreateFrame("Frame", nil, config)
    auraWatcher:RegisterEvent("UNIT_AURA")
    auraWatcher:SetScript("OnEvent", function(_, _, unit)
        if (config:IsShown() or (trackedBuffWindow and trackedBuffWindow:IsShown())) and selectedPage == "auras" and selectedAura == "buffs" then
            RefreshBuffFilterPanel()
        end
    end)
    config:SetScript("OnShow", function() if applyChangesButton then applyChangesButton:SetEnabled(hasPendingChanges) end; ShowPage(selectedPage) end)
    config:Hide()
    return config
end

function ns.ToggleConfig()
    CreateConfig()
    if config:IsShown() then config:Hide() else config:Show() end
end

local combatWatcher = CreateFrame("Frame")
combatWatcher:RegisterEvent("PLAYER_REGEN_DISABLED")
combatWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
combatWatcher:SetScript("OnEvent", function()
    if config and config:IsShown() then ns.RefreshConfig() end
end)
