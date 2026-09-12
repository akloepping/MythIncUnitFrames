local ADDON_NAME, ns = ...

local MEDIA = "Interface\\Buttons\\WHITE8x8"
local FONT = "Fonts\\FRIZQT__.TTF"
local FRAME_TYPES = { "player", "target", "focus", "pet", "targettarget", "party", "boss" }
local DISPLAY_NAMES = { player="Player", target="Target", focus="Focus", pet="Pet", targettarget="Target of Target", party="Party", boss="Boss" }
local AURA_TYPES = { "buffs", "debuffs", "defensives" }
local AURA_NAMES = { buffs="Buffs", debuffs="Debuffs", defensives="Defensives" }
local AURA_FIELDS = { buffs="PlayerBuffs", debuffs="CombatDebuffs", defensives="ExternalDefensives" }
local ANCHOR_NAMES = { TOP="Top", BOTTOM="Bottom" }
local GROWTH_NAMES = { RIGHT="Right", LEFT="Left" }
local ANCHOR_ORDER = { "TOP", "BOTTOM" }
local GROWTH_ORDER = { "RIGHT", "LEFT" }
local GROUP_ORIENTATION_NAMES = { VERTICAL="Vertical", HORIZONTAL="Horizontal" }
local GROUP_ORIENTATION_ORDER = { "VERTICAL", "HORIZONTAL" }

local selectedType, selectedAura, selectedPage = "player", "buffs", "frames"
local config, framesPage, aurasPage, profilesPage, trackedBuffWindow
local widthSlider, heightSlider, powerSlider, fontSlider, portraitSlider, bgSlider, borderSlider
local nameXSlider, nameYSlider, healthXSlider, healthYSlider
local roleXSlider, roleYSlider, raidXSlider, raidYSlider, raidSizeSlider
local auraSizeSlider, auraCountSlider, auraSpacingSlider, auraXSlider, auraYSlider
local selectedLabel, statusText, applyChangesButton, frameLockButton, auraLockButton
local nameButton, healthTextButton, portraitButton, sideButton, roleIconButton, raidMarkerButton
local textureButton, textureMenu, healthColorButton, powerColorButton, fontButton, fontMenu
local auraLabel, auraEnableButton, auraTextButton, auraAnchorButton, auraGrowthButton
local frameTab, auraTab, profileTab
local partyLayoutPanel, partyOrientationButton, partyDirectionButton, partySpacingSlider, partyIncludePlayerButton
local frameButtons, frameEnableChecks, auraButtons = {}, {}, {}
local buffFilterPanel, seenBuffButtons, trackedBuffButtons = nil, {}, {}
local manageTrackedButton
local profileCurrentLabel, profileCharacterLabel, profileNameBox, profileActionStatus
local profileButtons = {}
local selectedProfileName
local refreshing = false
local working, auraWorking, groupWorking = {}, {}, {}
local raidPage, refreshRaidControls
local MarkPending
local previewFrameType
local previewAuraUnitType, previewAuraType

local function Round(v) return math.floor((v or 0) + 0.5) end
local function Cycle(current, order)
    for i,v in ipairs(order) do if v==current then return order[(i % #order)+1] end end
    return order[1]
end
local function DisplayName(catalog,key,fallback)
    local entry=catalog and catalog[key]
    return (entry and entry.name) or fallback or key
end

local function MakeButton(parent,text,width,height)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate"); b:SetSize(width,height); b:SetText(text); return b
end

local function MakeSlider(parent,name,label,minValue,maxValue,step,width)
    local slider=CreateFrame("Slider","MIUF_"..name.."Slider",parent,"OptionsSliderTemplate")
    slider:SetMinMaxValues(minValue,maxValue); slider:SetValueStep(step); slider:SetObeyStepOnDrag(true); slider:SetWidth(width or 235)
    local text,low,high=_G[slider:GetName().."Text"],_G[slider:GetName().."Low"],_G[slider:GetName().."High"]
    if text then text:SetText(label) end; if low then low:SetText(tostring(minValue)) end; if high then high:SetText(tostring(maxValue)) end
    local box=CreateFrame("EditBox",nil,parent,"InputBoxTemplate"); box:SetSize(52,20); box:SetAutoFocus(false); box:SetJustifyH("CENTER"); box:SetPoint("TOP",slider,"BOTTOM",0,-1); slider.ValueBox=box
    local function Format(v) return step and step<1 and string.format("%.2f",v) or tostring(Round(v)) end
    local function Clamp(v)
        v=math.max(minValue,math.min(maxValue,v)); if step and step>0 then v=minValue+math.floor(((v-minValue)/step)+0.5)*step end
        return math.max(minValue,math.min(maxValue,v))
    end
    slider:SetScript("OnValueChanged",function(self,v) if not box:HasFocus() then box:SetText(Format(v)) end end)
    local function Commit()
        local v=tonumber(box:GetText()); if v then slider:SetValue(Clamp(v)) end; box:SetText(Format(slider:GetValue())); box:ClearFocus()
    end
    box:SetScript("OnEnterPressed",Commit); box:SetScript("OnEscapePressed",function() box:SetText(Format(slider:GetValue())); box:ClearFocus() end)
    box:SetScript("OnEditFocusGained",function(self) self:HighlightText() end); box:SetScript("OnEditFocusLost",Commit)
    return slider
end

local function MakeSection(parent,title,width,height)
    local section=CreateFrame("Frame",nil,parent,"BackdropTemplate"); section:SetSize(width,height)
    section:SetBackdrop({bgFile=MEDIA,edgeFile=MEDIA,edgeSize=1}); section:SetBackdropColor(0.02,0.025,0.03,0.55); section:SetBackdropBorderColor(0.18,0.22,0.28,0.95)
    local label=section:CreateFontString(nil,"OVERLAY"); label:SetFont(FONT,12,"OUTLINE"); label:SetPoint("TOPLEFT",10,-8); label:SetText(title); label:SetTextColor(0.82,0.88,0.95); section.Title=label
    return section
end

local function RestoreFramePreview(unitType)
    if InCombatLockdown() then return end
    unitType=unitType or previewFrameType
    if unitType and ns.ResetGroupPreview then ns.ResetGroupPreview(unitType) end
    if unitType and ns.ApplyFrameType then ns.ApplyFrameType(unitType) end
    if previewFrameType==unitType then previewFrameType=nil end
end

local function PreviewGroupControls(sizeOverride)
    if refreshing or InCombatLockdown() or (selectedType~="party" and selectedType~="boss") then return end
    if ns.PreviewGroupLayout then ns.PreviewGroupLayout(selectedType,groupWorking,sizeOverride) end
    previewFrameType=selectedType
end

local function PreviewFrameSliders()
    if refreshing then return end
    local width,height=Round(widthSlider:GetValue()),Round(heightSlider:GetValue())
    local powerPercent=Round(powerSlider:GetValue())
    local portraitPercent=Round(portraitSlider:GetValue())
    local fontSize=Round(fontSlider:GetValue())
    local backgroundOpacity=Round(bgSlider:GetValue())
    local borderOpacity=Round(borderSlider:GetValue())
    local nameX,nameY=Round(nameXSlider:GetValue()),Round(nameYSlider:GetValue())
    local healthX,healthY=Round(healthXSlider:GetValue()),Round(healthYSlider:GetValue())
    local roleX,roleY=Round(roleXSlider:GetValue()),Round(roleYSlider:GetValue())
    local raidX,raidY=Round(raidXSlider:GetValue()),Round(raidYSlider:GetValue())
    local raidSize=Round(raidSizeSlider:GetValue())

    working.fontSize=fontSize; working.portraitPercent=portraitPercent
    working.backgroundOpacity=backgroundOpacity; working.borderOpacity=borderOpacity
    working.nameXOffset=nameX; working.nameYOffset=nameY
    working.healthXOffset=healthX; working.healthYOffset=healthY
    working.roleIconXOffset=roleX; working.roleIconYOffset=roleY
    working.raidMarkerXOffset=raidX; working.raidMarkerYOffset=raidY; working.raidMarkerSize=raidSize
    if selectedType=="party" or selectedType=="boss" then groupWorking.spacing=Round(partySpacingSlider:GetValue()) end

    ns.ConfigSessionStageFrame(selectedType,{size={width=width,height=height},powerPercent=powerPercent,appearance=working})
    MarkPending("Configuration changes are pending.")
    if InCombatLockdown() or not ns.PreviewFrameType then return end
    ns.PreviewFrameType(selectedType,{
        size={width=width,height=height},
        powerPercent=powerPercent,
        appearance=working,
    })
    PreviewGroupControls({width=width,height=height})
    previewFrameType=selectedType
end

local function GetAuraAnchor(layout)
    local anchor=layout.anchor=="BOTTOM" and "BOTTOM" or "TOP"
    local growth=layout.growth=="LEFT" and "LEFT" or "RIGHT"
    if anchor=="TOP" then
        if growth=="LEFT" then return "BOTTOMRIGHT","TOPRIGHT" end
        return "BOTTOMLEFT","TOPLEFT"
    end
    if growth=="LEFT" then return "TOPRIGHT","BOTTOMRIGHT" end
    return "TOPLEFT","BOTTOMLEFT"
end

local function ApplyAuraVisual(unitType,auraType,layout)
    if InCombatLockdown() or not ns.frames or not layout then return end
    local field=AURA_FIELDS[auraType]; if not field then return end
    local point,relativePoint=GetAuraAnchor(layout)
    local savedLayout=ns.GetAuraLayout(unitType,auraType)
    local iconSize=math.max(1,tonumber(savedLayout and savedLayout.iconSize) or 16)
    local spacing=math.max(0,tonumber(layout.spacing) or 0)
    local maxCount=math.max(1,tonumber(layout.maxCount) or 1)
    for _,frame in pairs(ns.frames) do
        if frame.MIUF_UnitType==unitType then
            local container=frame[field]
            if container then
                container.size=iconSize; container.elementSpacing=spacing; container.lineSpacing=spacing; container.maxFrameCount=maxCount
                if container.MIUF_GroupKey and container.SetAuraGroupLayout then
                    container:SetAuraGroupLayout(container.MIUF_GroupKey,{elementWidth=iconSize,elementHeight=iconSize,elementSpacing=spacing,lineSpacing=spacing,maxFrameCount=maxCount})
                end
                if container.MIUF_Anchor then
                    container.MIUF_Anchor:SetHeight((iconSize*2)+spacing+4)
                    container.MIUF_Anchor:ClearAllPoints(); container.MIUF_Anchor:SetPoint(point,frame,relativePoint,layout.xOffset or 0,layout.yOffset or 0)
                end
                if container.ForceUpdate then container:ForceUpdate() end
            end
        end
    end
end

local function RestoreAuraPreview()
    if InCombatLockdown() then return end
    if previewAuraUnitType and previewAuraType then ApplyAuraVisual(previewAuraUnitType,previewAuraType,ns.GetAuraLayout(previewAuraUnitType,previewAuraType)) end
    previewAuraUnitType,previewAuraType=nil,nil
end

local function AuraAvailable(unitType,auraType)
    if unitType=="boss" then return false end
    if auraType=="buffs" then return unitType=="player" or unitType=="target" or unitType=="focus" or unitType=="party" or unitType=="targettarget" end
    if auraType=="debuffs" then return unitType~="pet" end
    if auraType=="defensives" then return unitType=="player" or unitType=="party" end
    return false
end

local function PreviewAuraSliders()
    if refreshing or InCombatLockdown() or not AuraAvailable(selectedType,selectedAura) then return end
    auraWorking.maxCount=Round(auraCountSlider:GetValue()); auraWorking.spacing=Round(auraSpacingSlider:GetValue())
    auraWorking.xOffset=Round(auraXSlider:GetValue()); auraWorking.yOffset=Round(auraYSlider:GetValue())
    ApplyAuraVisual(selectedType,selectedAura,auraWorking)
    previewAuraUnitType,previewAuraType=selectedType,selectedAura
end

local function ChooseAvailableAura()
    if AuraAvailable(selectedType,selectedAura) then return end
    for _,auraType in ipairs(AURA_TYPES) do if AuraAvailable(selectedType,auraType) then selectedAura=auraType; return end end
end

MarkPending=function(message)
    local dirty=ns.ConfigSessionIsDirty()
    if applyChangesButton then applyChangesButton:SetEnabled(dirty and not InCombatLockdown()) end
    if statusText then
        statusText:SetText(InCombatLockdown() and "Apply Changes is unavailable during combat."
            or (dirty and ((message or "Changes are pending.").."  Click Apply Changes when ready.")
            or "No pending changes."))
    end
end

local function CopyWorking()
    working=ns.ConfigSessionGetFrame(selectedType).appearance
    ChooseAvailableAura(); auraWorking=ns.ConfigSessionGetAura(selectedType,selectedAura) or {}
    groupWorking=ns.ConfigSessionGetGroup(selectedType)
end

local function StageGroupControls()
    if refreshing or (selectedType~="party" and selectedType~="boss") then return end
    ns.ConfigSessionStageGroup(selectedType,groupWorking)
    MarkPending("Group layout changes are pending.")
end

local function StageAuraValue(key,value)
    if refreshing or not AuraAvailable(selectedType,selectedAura) then return end
    ns.ConfigSessionStageAura(selectedType,selectedAura,{[key]=value})
    auraWorking[key]=value; MarkPending(DISPLAY_NAMES[selectedType].." "..AURA_NAMES[selectedAura].." change staged.")
end

local function RefreshFrameControls()
    nameButton:SetText("Name: "..(working.showName and "On" or "Off")); healthTextButton:SetText("Health %: "..(working.showHealthText and "On" or "Off"))
    portraitButton:SetText("Portrait: "..(working.showPortrait and "On" or "Off")); sideButton:SetText("Portrait Side: "..(working.portraitSide=="RIGHT" and "Right" or "Left"))
    local roleAvailable=selectedType=="player" or selectedType=="party"
    roleIconButton:SetShown(roleAvailable); roleIconButton:SetText("Role Icon: "..(working.showRoleIcon and "On" or "Off"))
    roleXSlider:SetShown(roleAvailable); roleXSlider.ValueBox:SetShown(roleAvailable); roleYSlider:SetShown(roleAvailable); roleYSlider.ValueBox:SetShown(roleAvailable)
    raidMarkerButton:SetText("Raid Marker: "..(working.showRaidMarker~=false and "On" or "Off"))
    textureButton:SetText("Bar Texture: "..DisplayName(ns.Media.textures,working.texture,"Flat").."  v"); healthColorButton:SetText("Health: "..DisplayName(ns.Media.healthColors,working.healthColor,"Automatic"))
    powerColorButton:SetText("Power: "..DisplayName(ns.Media.powerColors,working.powerColor,"Automatic")); fontButton:SetText("Font: "..DisplayName(ns.Media.fonts,working.fontFace,"Friz Quadrata").."  v")
end

local function RefreshGroupControls()
    local show=selectedType=="party" or selectedType=="boss"; partyLayoutPanel:SetShown(show); if not show then return end
    partyLayoutPanel.Title:SetText(selectedType=="party" and "Party group layout" or "Boss group layout"); partyIncludePlayerButton:SetShown(selectedType=="party")
    partyOrientationButton:SetText("Layout: "..(GROUP_ORIENTATION_NAMES[groupWorking.orientation] or "Vertical")); local dir=groupWorking.direction or "DOWN"
    partyDirectionButton:SetText("Grow: "..dir:sub(1,1)..dir:sub(2):lower()); partySpacingSlider:SetValue(groupWorking.spacing or 32)
    partyIncludePlayerButton:SetText("Include Player: "..(groupWorking.includePlayer and "On" or "Off"))
end

local function RefreshAuraControls()
    local wasRefreshing=refreshing; refreshing=true
    local available=AuraAvailable(selectedType,selectedAura) and auraWorking.iconSize~=nil
    auraLabel:SetText("Aura layout: "..(AURA_NAMES[selectedAura] or selectedAura))
    for _,slider in ipairs({auraSizeSlider,auraCountSlider,auraSpacingSlider,auraXSlider,auraYSlider}) do if available then slider:Enable() else slider:Disable() end end
    auraEnableButton:SetEnabled(available); auraTextButton:SetEnabled(available and auraWorking.enabled~=false); auraAnchorButton:SetEnabled(available and auraWorking.enabled~=false); auraGrowthButton:SetEnabled(available and auraWorking.enabled~=false)
    if available then
        auraEnableButton:SetText("Enabled: "..(auraWorking.enabled~=false and "On" or "Off")); auraTextButton:SetText("Text: "..(auraWorking.showText~=false and "On" or "Off"))
        auraSizeSlider:SetValue(auraWorking.iconSize); auraCountSlider:SetValue(auraWorking.maxCount); auraSpacingSlider:SetValue(auraWorking.spacing); auraXSlider:SetValue(auraWorking.xOffset); auraYSlider:SetValue(auraWorking.yOffset)
        auraAnchorButton:SetText("Anchor: "..(ANCHOR_NAMES[auraWorking.anchor] or auraWorking.anchor)); auraGrowthButton:SetText("Grow: "..(GROWTH_NAMES[auraWorking.growth] or auraWorking.growth))
    else
        auraEnableButton:SetText("Enabled: N/A"); auraTextButton:SetText("Text: N/A"); auraAnchorButton:SetText("Anchor: N/A"); auraGrowthButton:SetText("Grow: N/A")
    end
    refreshing=wasRefreshing
end

local function BuffPickerUnits()
    if selectedType=="party" then local u={"party1","party2","party3","party4"}; if groupWorking.includePlayer then u[#u+1]="player" end; return u end
    if selectedType=="player" or selectedType=="target" or selectedType=="focus" or selectedType=="targettarget" then return {selectedType} end
    return {}
end
local function ObserveCurrentBuffs()
    if InCombatLockdown() or not C_UnitAuras or not C_UnitAuras.GetUnitAuras then return end
    for _,unit in ipairs(BuffPickerUnits()) do
        local ok,auras=pcall(C_UnitAuras.GetUnitAuras,unit,"HELPFUL|PLAYER",40)
        if ok and type(auras)=="table" then for _,aura in ipairs(auras) do
            local id=aura and tonumber(aura.spellId); if id then ns.RecordSeenBuff(id,aura.name,aura.icon) end
        end end
    end
end

local function RefreshTrackedWindow()
    if not buffFilterPanel then return end
    local show=selectedPage=="auras" and selectedAura=="buffs"; buffFilterPanel:SetShown(show); if not show then return end
    ObserveCurrentBuffs(); local tracked=ns.ConfigSessionGetTrackedBuffs(); local trackedList,seenList={},{}
    for id,meta in pairs(tracked or {}) do local n=tonumber(id); if n then trackedList[#trackedList+1]={spellID=n,name=meta.name or ("Spell "..n),icon=meta.icon} end end
    for id,meta in pairs(ns.GetSeenBuffs() or {}) do local n=tonumber(id); if n and not tracked[n] then seenList[#seenList+1]={spellID=n,name=meta.name or ("Spell "..n),icon=meta.icon,lastSeen=meta.lastSeen or 0} end end
    table.sort(trackedList,function(a,b) return a.name<b.name end); table.sort(seenList,function(a,b) if a.lastSeen~=b.lastSeen then return a.lastSeen>b.lastSeen end return a.name<b.name end)
    manageTrackedButton:SetText(#trackedList>0 and ("Manage Tracked Buffs ("..#trackedList..")") or "Manage Tracked Buffs")
    if not trackedBuffWindow then return end
    local function Configure(button,info,isTracked)
        if not info then button:Hide(); return end
        button.icon:SetTexture(info.icon or 134400); button:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText(info.name); GameTooltip:AddLine(isTracked and "Click to stop tracking." or "Click to track.",0.8,0.8,0.8); GameTooltip:Show() end); button:SetScript("OnLeave",GameTooltip_Hide)
        button:SetScript("OnClick",function()
            if InCombatLockdown() then return end; local values=ns.ConfigSessionGetTrackedBuffs()
            if isTracked then values[info.spellID]=nil else values[info.spellID]={name=info.name,icon=info.icon} end
            ns.ConfigSessionStageTrackedBuffs(values)
            MarkPending(info.name..(isTracked and " will no longer be tracked." or " will be tracked.")); RefreshTrackedWindow()
        end); button:Show()
    end
    for i,b in ipairs(seenBuffButtons) do Configure(b,seenList[i],false) end; for i,b in ipairs(trackedBuffButtons) do Configure(b,trackedList[i],true) end
end

local function SetProfileStatus(text, errorState)
    if not profileActionStatus then return end
    profileActionStatus:SetText(text or "")
    profileActionStatus:SetTextColor(errorState and 1 or 0.65, errorState and 0.35 or 0.78, errorState and 0.35 or 0.88)
end

local function RefreshProfilesControls()
    if not profilesPage then return end
    local active = ns.GetActiveProfileName()
    local names = ns.GetProfileNames()
    if not selectedProfileName or not ns.ProfileExists(selectedProfileName) then selectedProfileName = active end
    profileCurrentLabel:SetText("Current profile: |cff66ccff"..active.."|r")
    profileCharacterLabel:SetText("Character: "..ns.GetCharacterProfileKey())
    for i,button in ipairs(profileButtons) do
        local name=names[i]
        if name then
            button.ProfileName=name
            button:SetText((name==active and "* " or "")..name)
            button:SetEnabled(name~=selectedProfileName)
            button:Show()
        else
            button.ProfileName=nil
            button:Hide()
        end
    end
end

function ns.RefreshConfig()
    if not config or not config:IsShown() then return end
    refreshing=true; MarkPending(); CopyWorking()
    for unitType,button in pairs(frameButtons) do button:SetEnabled(unitType~=selectedType); frameEnableChecks[unitType]:SetChecked(ns.ConfigSessionGetEnabled(unitType)) end
    if selectedPage=="profiles" then
        selectedLabel:SetText("Profiles")
    else
        selectedLabel:SetText(DISPLAY_NAMES[selectedType].." Settings")
    end
    if selectedType=="boss" and selectedPage=="auras" then selectedPage="frames" end
    auraTab:SetShown(selectedType~="boss" or selectedPage=="profiles")
    raidPage:SetShown(selectedPage=="raid"); if selectedPage=="raid" then selectedLabel:SetText("Raid Layout Preview"); refreshRaidControls() end
    framesPage:SetShown(selectedPage=="frames"); aurasPage:SetShown(selectedPage=="auras"); profilesPage:SetShown(selectedPage=="profiles")
    frameTab:SetEnabled(selectedPage~="frames"); auraTab:SetEnabled(selectedPage~="auras"); profileTab:SetEnabled(selectedPage~="profiles")
    if selectedPage=="frames" then
        local frameSettings=ns.ConfigSessionGetFrame(selectedType); local size=frameSettings.size; widthSlider:SetValue(size.width); heightSlider:SetValue(size.height); powerSlider:SetValue(frameSettings.powerPercent); fontSlider:SetValue(working.fontSize); portraitSlider:SetValue(working.portraitPercent); bgSlider:SetValue(working.backgroundOpacity); borderSlider:SetValue(working.borderOpacity)
        nameXSlider:SetValue(working.nameXOffset or 6); nameYSlider:SetValue(working.nameYOffset or 0); healthXSlider:SetValue(working.healthXOffset or -6); healthYSlider:SetValue(working.healthYOffset or 0)
        roleXSlider:SetValue(working.roleIconXOffset or 3); roleYSlider:SetValue(working.roleIconYOffset or -3)
        raidXSlider:SetValue(working.raidMarkerXOffset or 0); raidYSlider:SetValue(working.raidMarkerYOffset or 2); raidSizeSlider:SetValue(working.raidMarkerSize or 20)
        RefreshFrameControls(); RefreshGroupControls(); frameLockButton:SetText(ns.AreFrameMoversLocked() and "Unlock Frame Movers" or "Lock Frame Movers")
    elseif selectedPage=="auras" then
        for auraType,button in pairs(auraButtons) do button:SetEnabled(AuraAvailable(selectedType,auraType) and auraType~=selectedAura) end
        RefreshAuraControls(); RefreshTrackedWindow(); auraLockButton:SetText(ns.AreAuraMoversLocked() and "Unlock Aura Movers" or "Lock Aura Movers")
    else
        if selectedPage=="profiles" then RefreshProfilesControls() end
    end
    statusText:SetText(InCombatLockdown() and "Apply Changes is unavailable during combat." or (ns.ConfigSessionIsDirty() and "Pending changes are waiting. Click Apply Changes when ready." or (selectedPage=="profiles" and "Profile switches reload the UI so protected frames rebuild cleanly." or "Edit settings, then click Apply Changes.")))
    applyChangesButton:SetEnabled(ns.ConfigSessionIsDirty() and not InCombatLockdown())
    refreshing=false
    if not InCombatLockdown() and selectedPage=="auras" and AuraAvailable(selectedType,selectedAura) and auraWorking.iconSize then
        ApplyAuraVisual(selectedType,selectedAura,auraWorking); previewAuraUnitType,previewAuraType=selectedType,selectedAura
    end
end

local function ApplyChanges()
    if not ns.ConfigSessionCommit() then return end
    previewAuraUnitType,previewAuraType=nil,nil
    previewFrameType=nil; applyChangesButton:SetEnabled(false)
    ns.SetFrameMoversLockedState(true); ns.SetAuraMoversLockedState(true)
    ns.SetMoversLocked(true)
    ReloadUI()
end

local function SelectPage(page)
    if fontMenu then fontMenu:Hide() end
    if textureMenu then textureMenu:Hide() end
    if page=="frames" then RestoreAuraPreview() elseif page=="auras" then RestoreFramePreview(); ChooseAvailableAura() else RestoreFramePreview(); RestoreAuraPreview() end
    if ns.HideRaidPreview then ns.HideRaidPreview() end
    selectedPage=page
    ns.RefreshConfig()
end

local function CreateShell()
    config=CreateFrame("Frame","MIUF_ConfigFrame",UIParent,"BackdropTemplate"); config:SetSize(900,840); config:SetPoint("CENTER"); config:SetFrameStrata("DIALOG"); config:SetClampedToScreen(true); config:SetMovable(true); config:EnableMouse(true); config:RegisterForDrag("LeftButton")
    local function FitConfigToScreen()
        config:SetScale(math.min(1,(UIParent:GetWidth()-32)/900,(UIParent:GetHeight()-32)/840))
    end
    config:SetScript("OnShow",FitConfigToScreen)
    config:RegisterEvent("UI_SCALE_CHANGED"); config:RegisterEvent("DISPLAY_SIZE_CHANGED")
    config:SetScript("OnEvent",FitConfigToScreen)
    FitConfigToScreen()
    config:SetScript("OnDragStart",config.StartMoving); config:SetScript("OnDragStop",config.StopMovingOrSizing); config:SetBackdrop({bgFile=MEDIA,edgeFile=MEDIA,edgeSize=1}); config:SetBackdropColor(0.035,0.035,0.04,0.97); config:SetBackdropBorderColor(0.2,0.55,0.85,1)
    config:SetScript("OnHide",function() if fontMenu then fontMenu:Hide() end; if textureMenu then textureMenu:Hide() end; RestoreFramePreview(); RestoreAuraPreview(); ns.HideRaidPreview() end)
    local title=config:CreateFontString(nil,"OVERLAY"); title:SetFont(FONT,17,"OUTLINE"); title:SetPoint("TOPLEFT",18,-16); title:SetText("MythInc Unit Frames")
    local ver=config:CreateFontString(nil,"OVERLAY"); ver:SetFont(FONT,10,"OUTLINE"); ver:SetPoint("LEFT",title,"RIGHT",10,-1); ver:SetText(ns.version); ver:SetTextColor(0.65,0.7,0.75)
    local close=MakeButton(config,"X",28,24); close:SetPoint("TOPRIGHT",-10,-10); close:SetScript("OnClick",function() config:Hide() end)
    frameTab=MakeButton(config,"Frames",110,28); frameTab:SetPoint("TOPLEFT",180,-48); frameTab:SetScript("OnClick",function() SelectPage("frames") end)
    auraTab=MakeButton(config,"Auras",110,28); auraTab:SetPoint("LEFT",frameTab,"RIGHT",8,0); auraTab:SetScript("OnClick",function() SelectPage("auras") end)
    profileTab=MakeButton(config,"Profiles",110,28); profileTab:SetPoint("LEFT",auraTab,"RIGHT",8,0); profileTab:SetScript("OnClick",function() SelectPage("profiles") end)
    local prev
    for _,unitType in ipairs(FRAME_TYPES) do
        local row=CreateFrame("Frame",nil,config); row:SetSize(130,28); if prev then row:SetPoint("TOPLEFT",prev,"BOTTOMLEFT",0,-6) else row:SetPoint("TOPLEFT",12,-80) end
        local check=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate"); check:SetSize(24,24); check:SetPoint("LEFT"); check:SetScript("OnClick",function(self)
            if InCombatLockdown() then self:SetChecked(ns.ConfigSessionGetEnabled(unitType)); return end
            ns.ConfigSessionStageEnabled(unitType,self:GetChecked() and true or false); MarkPending(DISPLAY_NAMES[unitType].." enable state staged."); if ns.PreviewUnitTypeMovers then ns.PreviewUnitTypeMovers(unitType,self:GetChecked()) end
        end); frameEnableChecks[unitType]=check
        local b=MakeButton(row,DISPLAY_NAMES[unitType],101,28); b:SetPoint("LEFT",check,"RIGHT",1,0); b:SetScript("OnClick",function()
            if fontMenu then fontMenu:Hide() end; if textureMenu then textureMenu:Hide() end
            if previewFrameType and previewFrameType~=unitType then RestoreFramePreview(previewFrameType) end
            if previewAuraUnitType then RestoreAuraPreview() end
            ns.HideRaidPreview(); selectedType=unitType; if selectedPage=="profiles" or selectedPage=="raid" then selectedPage="frames" end; ns.RefreshConfig()
        end); frameButtons[unitType]=b; prev=row
    end
    applyChangesButton=MakeButton(config,"Apply Changes",120,28); applyChangesButton:SetPoint("BOTTOMLEFT",170,18); applyChangesButton:SetEnabled(false); applyChangesButton:SetScript("OnClick",ApplyChanges)
    local resetAll=MakeButton(config,"Reset All",90,26); resetAll:SetPoint("BOTTOMLEFT",16,20); resetAll:SetScript("OnClick",function() if not InCombatLockdown() then RestoreFramePreview(); RestoreAuraPreview()
        ns.ConfigSessionStageResetAll(); MarkPending("Reset of all configuration settings is pending."); ns.RefreshConfig() end end)
    selectedLabel=config:CreateFontString(nil,"OVERLAY"); selectedLabel:SetFont(FONT,14,"OUTLINE"); selectedLabel:SetPoint("TOPLEFT",180,-94)
    statusText=config:CreateFontString(nil,"OVERLAY"); statusText:SetFont(FONT,9,"OUTLINE"); statusText:SetPoint("BOTTOMLEFT",520,22); statusText:SetWidth(355); statusText:SetJustifyH("LEFT")
end

local function CreateFramesPage()
    framesPage=CreateFrame("Frame",nil,config); framesPage:SetPoint("TOPLEFT",160,-80); framesPage:SetPoint("BOTTOMRIGHT",-10,50)
    local layout=MakeSection(framesPage,"Frame Layout",330,405); layout:SetPoint("TOPLEFT",20,-62)
    local text=MakeSection(framesPage,"Text",345,315); text:SetPoint("TOPLEFT",365,-62)
    local appearance=MakeSection(framesPage,"Appearance",345,175); appearance:SetPoint("TOPLEFT",365,-387)
    local indicators=MakeSection(framesPage,"Indicators",330,175); indicators:SetPoint("TOPLEFT",20,-480)
    widthSlider=MakeSlider(layout,"Width","Width",100,600,1,285); widthSlider:SetPoint("TOPLEFT",20,-42); widthSlider:HookScript("OnValueChanged",PreviewFrameSliders)
    heightSlider=MakeSlider(layout,"Height","Height",24,150,1,285); heightSlider:SetPoint("TOPLEFT",20,-102); heightSlider:HookScript("OnValueChanged",PreviewFrameSliders)
    powerSlider=MakeSlider(layout,"PowerPercent","Power bar height (%)",10,40,1,285); powerSlider:SetPoint("TOPLEFT",20,-162); powerSlider:HookScript("OnValueChanged",PreviewFrameSliders)
    portraitSlider=MakeSlider(layout,"PortraitPercent","Portrait width (%)",12,40,1,285); portraitSlider:SetPoint("TOPLEFT",20,-222); portraitSlider:HookScript("OnValueChanged",PreviewFrameSliders)
    portraitButton=MakeButton(layout,"Portrait: Off",118,26); portraitButton:SetPoint("TOPLEFT",15,-282); portraitButton:SetScript("OnClick",function() working.showPortrait=not working.showPortrait; RefreshFrameControls(); PreviewFrameSliders() end)
    sideButton=MakeButton(layout,"Portrait Side: Left",155,26); sideButton:SetPoint("LEFT",portraitButton,"RIGHT",8,0); sideButton:SetScript("OnClick",function() working.portraitSide=working.portraitSide=="LEFT" and "RIGHT" or "LEFT"; RefreshFrameControls(); PreviewFrameSliders() end)
    partyLayoutPanel=CreateFrame("Frame",nil,layout); partyLayoutPanel:SetSize(300,78); partyLayoutPanel:SetPoint("TOPLEFT",15,-320)
    local ptitle=partyLayoutPanel:CreateFontString(nil,"OVERLAY"); ptitle:SetFont(FONT,10,"OUTLINE"); ptitle:SetPoint("TOPLEFT"); ptitle:SetTextColor(0.7,0.76,0.82); partyLayoutPanel.Title=ptitle
    partyOrientationButton=MakeButton(partyLayoutPanel,"Layout: Vertical",128,24); partyOrientationButton:SetPoint("TOPLEFT",0,-18); partyOrientationButton:SetScript("OnClick",function() groupWorking.orientation=Cycle(groupWorking.orientation or "VERTICAL",GROUP_ORIENTATION_ORDER); groupWorking.direction=groupWorking.orientation=="HORIZONTAL" and "RIGHT" or "DOWN"; StageGroupControls(); RefreshGroupControls(); PreviewFrameSliders() end)
    partyDirectionButton=MakeButton(partyLayoutPanel,"Grow: Down",105,24); partyDirectionButton:SetPoint("LEFT",partyOrientationButton,"RIGHT",7,0); partyDirectionButton:SetScript("OnClick",function() if groupWorking.orientation=="HORIZONTAL" then groupWorking.direction=groupWorking.direction=="LEFT" and "RIGHT" or "LEFT" else groupWorking.direction=groupWorking.direction=="UP" and "DOWN" or "UP" end; StageGroupControls(); RefreshGroupControls(); PreviewFrameSliders() end)
    partyIncludePlayerButton=MakeButton(partyLayoutPanel,"Include Player: Off",140,24); partyIncludePlayerButton:SetPoint("TOPLEFT",0,-48); partyIncludePlayerButton:SetScript("OnClick",function() groupWorking.includePlayer=not groupWorking.includePlayer; StageGroupControls(); RefreshGroupControls(); PreviewFrameSliders() end)
    partySpacingSlider=MakeSlider(partyLayoutPanel,"PartySpacing","Spacing",0,80,1,125); partySpacingSlider:SetPoint("TOPLEFT",160,-43); partySpacingSlider:HookScript("OnValueChanged",function(_,v) if not refreshing then groupWorking.spacing=Round(v); StageGroupControls(); PreviewFrameSliders() end end)

    fontButton=MakeButton(text,"Font",190,26); fontButton:SetPoint("TOPLEFT",15,-34)
    fontMenu=CreateFrame("Frame",nil,text,"BackdropTemplate"); fontMenu:SetWidth(190); fontMenu:SetHeight((#ns.Media.fontOrder*24)+8); fontMenu:SetPoint("TOPLEFT",fontButton,"BOTTOMLEFT",0,-2); fontMenu:SetFrameLevel(text:GetFrameLevel()+20)
    fontMenu:SetBackdrop({bgFile=MEDIA,edgeFile=MEDIA,edgeSize=1}); fontMenu:SetBackdropColor(0.03,0.035,0.045,0.98); fontMenu:SetBackdropBorderColor(0.25,0.5,0.75,1); fontMenu:Hide()
    for i,key in ipairs(ns.Media.fontOrder) do
        local entry=ns.Media.fonts[key]; local choice=MakeButton(fontMenu,entry.name,180,22); choice:SetPoint("TOPLEFT",5,-4-((i-1)*24))
        local label=choice:GetFontString(); if label then label:SetFont(entry.path,12,"OUTLINE") end
        choice:SetScript("OnClick",function() working.fontFace=key; fontMenu:Hide(); RefreshFrameControls(); PreviewFrameSliders() end)
    end
    fontButton:SetScript("OnClick",function() if textureMenu then textureMenu:Hide() end; if fontMenu:IsShown() then fontMenu:Hide() else fontMenu:Show() end end)
    fontSlider=MakeSlider(text,"FontSize","Font size",8,24,1,285); fontSlider:SetPoint("TOPLEFT",20,-76); fontSlider:HookScript("OnValueChanged",PreviewFrameSliders)
    nameButton=MakeButton(text,"Name: On",105,26); nameButton:SetPoint("TOPLEFT",15,-132); nameButton:SetScript("OnClick",function() working.showName=not working.showName; RefreshFrameControls(); PreviewFrameSliders() end)
    nameXSlider=MakeSlider(text,"NameXOffset","Name X",-200,200,1,135); nameXSlider:SetPoint("TOPLEFT",20,-172); nameXSlider:HookScript("OnValueChanged",PreviewFrameSliders)
    nameYSlider=MakeSlider(text,"NameYOffset","Name Y",-100,100,1,135); nameYSlider:SetPoint("TOPLEFT",190,-172); nameYSlider:HookScript("OnValueChanged",PreviewFrameSliders)
    healthTextButton=MakeButton(text,"Health %: On",105,26); healthTextButton:SetPoint("TOPLEFT",15,-224); healthTextButton:SetScript("OnClick",function() working.showHealthText=not working.showHealthText; RefreshFrameControls(); PreviewFrameSliders() end)
    healthXSlider=MakeSlider(text,"HealthXOffset","Health X",-200,200,1,135); healthXSlider:SetPoint("TOPLEFT",20,-264); healthXSlider:HookScript("OnValueChanged",PreviewFrameSliders)
    healthYSlider=MakeSlider(text,"HealthYOffset","Health Y",-100,100,1,135); healthYSlider:SetPoint("TOPLEFT",190,-264); healthYSlider:HookScript("OnValueChanged",PreviewFrameSliders)

    textureButton=MakeButton(appearance,"Bar Texture",155,26); textureButton:SetPoint("TOPLEFT",15,-34)
    textureMenu=CreateFrame("Frame",nil,appearance,"BackdropTemplate"); textureMenu:SetWidth(155); textureMenu:SetHeight((#ns.Media.textureOrder*28)+8); textureMenu:SetPoint("TOPLEFT",textureButton,"BOTTOMLEFT",0,-2); textureMenu:SetFrameLevel(appearance:GetFrameLevel()+20)
    textureMenu:SetBackdrop({bgFile=MEDIA,edgeFile=MEDIA,edgeSize=1}); textureMenu:SetBackdropColor(0.03,0.035,0.045,0.98); textureMenu:SetBackdropBorderColor(0.25,0.5,0.75,1); textureMenu:Hide()
    for i,key in ipairs(ns.Media.textureOrder) do
        local entry=ns.Media.textures[key]; local choice=MakeButton(textureMenu,entry.name,145,26); choice:SetPoint("TOPLEFT",5,-4-((i-1)*28))
        local sample=choice:CreateTexture(nil,"OVERLAY"); sample:SetSize(38,8); sample:SetPoint("LEFT",8,0); sample:SetTexture(entry.path)
        local label=choice:GetFontString(); if label then label:SetJustifyH("RIGHT"); label:SetWidth(88); label:ClearAllPoints(); label:SetPoint("RIGHT",-8,0) end
        choice:SetScript("OnClick",function() working.texture=key; textureMenu:Hide(); RefreshFrameControls(); PreviewFrameSliders() end)
    end
    textureButton:SetScript("OnClick",function() if fontMenu then fontMenu:Hide() end; if textureMenu:IsShown() then textureMenu:Hide() else textureMenu:Show() end end)
    healthColorButton=MakeButton(appearance,"Health",155,26); healthColorButton:SetPoint("LEFT",textureButton,"RIGHT",8,0); healthColorButton:SetScript("OnClick",function() working.healthColor=Cycle(working.healthColor,ns.Media.healthColorOrder); RefreshFrameControls(); PreviewFrameSliders() end)
    powerColorButton=MakeButton(appearance,"Power",155,26); powerColorButton:SetPoint("TOPLEFT",15,-68); powerColorButton:SetScript("OnClick",function() working.powerColor=Cycle(working.powerColor,ns.Media.powerColorOrder); RefreshFrameControls(); PreviewFrameSliders() end)
    bgSlider=MakeSlider(appearance,"BackgroundOpacity","Background opacity (%)",0,100,1,135); bgSlider:SetPoint("TOPLEFT",180,-75); bgSlider:HookScript("OnValueChanged",PreviewFrameSliders)
    borderSlider=MakeSlider(appearance,"BorderOpacity","Border opacity (%)",0,100,1,135); borderSlider:SetPoint("TOPLEFT",180,-125); borderSlider:HookScript("OnValueChanged",PreviewFrameSliders)

    roleIconButton=MakeButton(indicators,"Role Icon: Off",145,24); roleIconButton:SetPoint("TOPLEFT",10,-30); roleIconButton:SetScript("OnClick",function() working.showRoleIcon=not working.showRoleIcon; RefreshFrameControls(); PreviewFrameSliders() end)
    raidMarkerButton=MakeButton(indicators,"Raid Marker: On",145,24); raidMarkerButton:SetPoint("LEFT",roleIconButton,"RIGHT",10,0); raidMarkerButton:SetScript("OnClick",function() working.showRaidMarker=working.showRaidMarker==false; RefreshFrameControls(); PreviewFrameSliders() end)
    roleXSlider=MakeSlider(indicators,"RoleIconXOffset","Role X",-100,100,1,125); roleXSlider:SetPoint("TOPLEFT",15,-78); roleXSlider:HookScript("OnValueChanged",PreviewFrameSliders)
    roleYSlider=MakeSlider(indicators,"RoleIconYOffset","Role Y",-100,100,1,125); roleYSlider:SetPoint("TOPLEFT",180,-78); roleYSlider:HookScript("OnValueChanged",PreviewFrameSliders)
    raidXSlider=MakeSlider(indicators,"RaidMarkerXOffset","Marker X",-150,150,1,85); raidXSlider:SetPoint("TOPLEFT",10,-135); raidXSlider:HookScript("OnValueChanged",PreviewFrameSliders)
    raidYSlider=MakeSlider(indicators,"RaidMarkerYOffset","Marker Y",-150,150,1,85); raidYSlider:SetPoint("TOPLEFT",120,-135); raidYSlider:HookScript("OnValueChanged",PreviewFrameSliders)
    raidSizeSlider=MakeSlider(indicators,"RaidMarkerSize","Size",8,48,1,85); raidSizeSlider:SetPoint("TOPLEFT",230,-135); raidSizeSlider:HookScript("OnValueChanged",PreviewFrameSliders)

    local reset=MakeButton(framesPage,"Reset Frame",105,28); reset:SetPoint("BOTTOMLEFT",20,8); reset:SetScript("OnClick",function() if not InCombatLockdown() then RestoreFramePreview(); ns.ConfigSessionStageFrameReset(selectedType); MarkPending("Frame reset is pending."); ns.RefreshConfig() end end)
    frameLockButton=MakeButton(framesPage,"Unlock Frame Movers",145,28); frameLockButton:SetPoint("LEFT",reset,"RIGHT",8,0); frameLockButton:SetScript("OnClick",function() if not InCombatLockdown() then local locked=not ns.AreFrameMoversLocked(); ns.SetFrameMoversLockedState(locked); ns.SetFrameMoversLocked(locked); ns.RefreshConfig() end end)
end

local function CreateAurasPage()
    aurasPage=CreateFrame("Frame",nil,config); aurasPage:SetPoint("TOPLEFT",160,-80); aurasPage:SetPoint("BOTTOMRIGHT",-10,50)
    auraLabel=aurasPage:CreateFontString(nil,"OVERLAY"); auraLabel:SetFont(FONT,13,"OUTLINE"); auraLabel:SetPoint("TOPLEFT",20,-70)
    local prev
    for _,auraType in ipairs(AURA_TYPES) do
        local b=MakeButton(aurasPage,AURA_NAMES[auraType],105,26); if prev then b:SetPoint("LEFT",prev,"RIGHT",7,0) else b:SetPoint("TOPLEFT",20,-96) end
        b:SetScript("OnClick",function() RestoreAuraPreview(); selectedAura=auraType; ns.RefreshConfig() end); auraButtons[auraType]=b; prev=b
    end
    auraEnableButton=MakeButton(aurasPage,"Enabled: On",125,26); auraEnableButton:SetPoint("TOPLEFT",20,-132); auraEnableButton:SetScript("OnClick",function() auraWorking.enabled=auraWorking.enabled==false; StageAuraValue("enabled",auraWorking.enabled); RefreshAuraControls(); if ns.PreviewAuraMover then ns.PreviewAuraMover(selectedType,selectedAura,auraWorking.enabled~=false) end end)
    auraTextButton=MakeButton(aurasPage,"Text: On",110,26); auraTextButton:SetPoint("LEFT",auraEnableButton,"RIGHT",7,0); auraTextButton:SetScript("OnClick",function() auraWorking.showText=auraWorking.showText==false; StageAuraValue("showText",auraWorking.showText); RefreshAuraControls() end)
    auraSizeSlider=MakeSlider(aurasPage,"AuraIconSize","Icon size",12,40,1,180); auraSizeSlider:SetPoint("TOPLEFT",35,-195); auraSizeSlider:HookScript("OnValueChanged",function(_,v) if not refreshing then StageAuraValue("iconSize",Round(v)) end end)
    auraCountSlider=MakeSlider(aurasPage,"AuraCount","Max icons",1,12,1,180); auraCountSlider:SetPoint("TOPLEFT",260,-195); auraCountSlider:HookScript("OnValueChanged",function(_,v) if not refreshing then StageAuraValue("maxCount",Round(v)); PreviewAuraSliders() end end)
    auraSpacingSlider=MakeSlider(aurasPage,"AuraSpacing","Spacing",0,10,1,180); auraSpacingSlider:SetPoint("TOPLEFT",485,-195); auraSpacingSlider:HookScript("OnValueChanged",function(_,v) if not refreshing then StageAuraValue("spacing",Round(v)); PreviewAuraSliders() end end)
    local function StageAuraPosition()
        if refreshing or not AuraAvailable(selectedType,selectedAura) then return end
        local x,y=Round(auraXSlider:GetValue()),Round(auraYSlider:GetValue())
        StageAuraValue("xOffset",x); StageAuraValue("yOffset",y); PreviewAuraSliders()
    end
    auraXSlider=MakeSlider(aurasPage,"AuraXOffset","X offset",-400,400,1,180); auraXSlider:SetPoint("TOPLEFT",35,-275); auraXSlider:HookScript("OnValueChanged",StageAuraPosition)
    auraYSlider=MakeSlider(aurasPage,"AuraYOffset","Y offset",-400,400,1,180); auraYSlider:SetPoint("TOPLEFT",260,-275); auraYSlider:HookScript("OnValueChanged",StageAuraPosition)
    auraAnchorButton=MakeButton(aurasPage,"Anchor: Top",125,26); auraAnchorButton:SetPoint("TOPLEFT",485,-264); auraAnchorButton:SetScript("OnClick",function() auraWorking.anchor=Cycle(auraWorking.anchor,ANCHOR_ORDER); StageAuraValue("anchor",auraWorking.anchor); PreviewAuraSliders(); RefreshAuraControls() end)
    auraGrowthButton=MakeButton(aurasPage,"Grow: Right",125,26); auraGrowthButton:SetPoint("LEFT",auraAnchorButton,"RIGHT",7,0); auraGrowthButton:SetScript("OnClick",function() auraWorking.growth=Cycle(auraWorking.growth,GROWTH_ORDER); StageAuraValue("growth",auraWorking.growth); RefreshAuraControls() end)
    local anchorNote=aurasPage:CreateFontString(nil,"OVERLAY"); anchorNote:SetFont(FONT,10,"OUTLINE"); anchorNote:SetPoint("TOPLEFT",35,-323); anchorNote:SetWidth(620); anchorNote:SetJustifyH("LEFT"); anchorNote:SetText("X/Y offsets are measured from the selected unit frame's Top or Bottom anchor edge."); anchorNote:SetTextColor(0.7,0.76,0.82)
    buffFilterPanel=CreateFrame("Frame",nil,aurasPage); buffFilterPanel:SetPoint("TOPLEFT",20,-365); buffFilterPanel:SetSize(650,72)
    local note=buffFilterPanel:CreateFontString(nil,"OVERLAY"); note:SetFont(FONT,11,"OUTLINE"); note:SetPoint("TOPLEFT"); note:SetText("Tracked Buffs: only buffs you choose are shown on normal buff frames.")
    manageTrackedButton=MakeButton(buffFilterPanel,"Manage Tracked Buffs",180,24); manageTrackedButton:SetPoint("TOPLEFT",0,-25)
    trackedBuffWindow=CreateFrame("Frame","MIUF_TrackedBuffWindow",UIParent,"BackdropTemplate"); trackedBuffWindow:SetSize(620,300); trackedBuffWindow:SetPoint("CENTER"); trackedBuffWindow:SetFrameStrata("DIALOG"); trackedBuffWindow:SetBackdrop({bgFile=MEDIA,edgeFile=MEDIA,edgeSize=1}); trackedBuffWindow:SetBackdropColor(0.035,0.04,0.05,0.98); trackedBuffWindow:Hide()
    local function Choice(x,y)
        local b=CreateFrame("Button",nil,trackedBuffWindow,"BackdropTemplate"); b:SetSize(34,34); b:SetPoint("TOPLEFT",x,y); b:SetBackdrop({bgFile=MEDIA,edgeFile=MEDIA,edgeSize=1}); b:SetBackdropColor(0.05,0.05,0.05,0.9); b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetPoint("TOPLEFT",2,-2); b.icon:SetPoint("BOTTOMRIGHT",-2,2); return b
    end
    for i=1,24 do local col=(i-1)%12; local row=math.floor((i-1)/12); seenBuffButtons[i]=Choice(14+col*40,-60-row*40); trackedBuffButtons[i]=Choice(14+col*40,-168-row*40) end
    local seenTitle=trackedBuffWindow:CreateFontString(nil,"OVERLAY"); seenTitle:SetFont(FONT,11,"OUTLINE"); seenTitle:SetPoint("TOPLEFT",14,-42); seenTitle:SetText("Seen Buffs - click to track")
    local trackedTitle=trackedBuffWindow:CreateFontString(nil,"OVERLAY"); trackedTitle:SetFont(FONT,11,"OUTLINE"); trackedTitle:SetPoint("TOPLEFT",14,-150); trackedTitle:SetText("Tracked Buffs - click to stop tracking")
    local close=MakeButton(trackedBuffWindow,"Back to Auras",120,24); close:SetPoint("BOTTOMLEFT",14,12); close:SetScript("OnClick",function() trackedBuffWindow:Hide(); config:Show() end)
    local clear=MakeButton(trackedBuffWindow,"Clear Seen History",130,24); clear:SetPoint("LEFT",close,"RIGHT",8,0); clear:SetScript("OnClick",function() if not InCombatLockdown() then ns.ClearSeenBuffs(); RefreshTrackedWindow() end end)
    manageTrackedButton:SetScript("OnClick",function() RefreshTrackedWindow(); config:Hide(); trackedBuffWindow:Show() end)
    local reset=MakeButton(aurasPage,"Reset Aura",105,28); reset:SetPoint("BOTTOMLEFT",20,8); reset:SetScript("OnClick",function() if not InCombatLockdown() then RestoreAuraPreview(); if not AuraAvailable(selectedType,selectedAura) then return end; ns.ConfigSessionStageAuraReset(selectedType,selectedAura); MarkPending("Aura reset is pending."); ns.RefreshConfig() end end)
    auraLockButton=MakeButton(aurasPage,"Unlock Aura Movers",145,28); auraLockButton:SetPoint("LEFT",reset,"RIGHT",8,0); auraLockButton:SetScript("OnClick",function() if not InCombatLockdown() then local locked=not ns.AreAuraMoversLocked(); ns.SetAuraMoversLockedState(locked); ns.SetAuraMoversLocked(locked); ns.RefreshConfig() end end)
end

local function CreateRaidPage()
    raidPage=CreateFrame("Frame",nil,config); raidPage:SetPoint("TOPLEFT",160,-80); raidPage:SetPoint("BOTTOMRIGHT",-10,50)
    local tab=MakeButton(config,"Raid Layout",110,28); tab:SetPoint("LEFT",profileTab,"RIGHT",8,0)
    tab:SetScript("OnClick",function() SelectPage("raid") end)
    local controls, raidWorking = {}, {}
    local function Stage()
        if refreshing or InCombatLockdown() then return end
        ns.ConfigSessionStageGroup("raid",raidWorking); MarkPending("Raid geometry changes are pending.")
        refreshRaidControls()
        if ns.raidFrameMoverOwner and ns.raidFrameMoverOwner:IsShown() then ns.ShowRaidPreview() end
    end
    -- Both geometry levels use the same control builder and orientation rules.
    local function BuildLevel(title,prefix,y)
        local panel=MakeSection(raidPage,title,650,150); panel:SetPoint("TOPLEFT",20,y)
        local orientation=MakeButton(panel,"",180,26); orientation:SetPoint("TOPLEFT",15,-35)
        local direction=MakeButton(panel,"",140,26); direction:SetPoint("LEFT",orientation,"RIGHT",10,0)
        local spacing=MakeSlider(panel,"Raid"..prefix.."Spacing","Spacing",0,80,1,180); spacing:SetPoint("TOPLEFT",15,-85)
        orientation:SetScript("OnClick",function()
            raidWorking[prefix.."Orientation"]=Cycle(raidWorking[prefix.."Orientation"],GROUP_ORIENTATION_ORDER)
            raidWorking[prefix.."Direction"]=raidWorking[prefix.."Orientation"]=="HORIZONTAL" and "RIGHT" or "DOWN"; Stage()
        end)
        direction:SetScript("OnClick",function()
            local horizontal=raidWorking[prefix.."Orientation"]=="HORIZONTAL"
            local forward,reverse=horizontal and "RIGHT" or "DOWN",horizontal and "LEFT" or "UP"
            raidWorking[prefix.."Direction"]=raidWorking[prefix.."Direction"]==forward and reverse or forward; Stage()
        end)
        spacing:HookScript("OnValueChanged",function(_,v) if not refreshing then raidWorking[prefix.."Spacing"]=Round(v); Stage() end end)
        controls[prefix]={orientation=orientation,direction=direction,spacing=spacing}
    end
    BuildLevel("Raid members (5 per subgroup)","member",-62)
    BuildLevel("Raid subgroups (8 groups)","subgroup",-222)
    local rows=MakeSlider(raidPage,"RaidGroupsPerRow","Groups per row",1,8,1,180); rows:SetPoint("TOPLEFT",35,-412)
    rows:HookScript("OnValueChanged",function(_,v) if not refreshing then raidWorking.groupsPerRow=Round(v); Stage() end end)
    local show=MakeButton(raidPage,"Show Raid Preview",155,28); show:SetPoint("TOPLEFT",35,-480)
    show:SetScript("OnClick",function() ns.ShowRaidPreview() end)
    local hide=MakeButton(raidPage,"Hide Preview",120,28); hide:SetPoint("LEFT",show,"RIGHT",8,0); hide:SetScript("OnClick",ns.HideRaidPreview)
    local revert=MakeButton(raidPage,"Revert Raid Changes",155,28); revert:SetPoint("LEFT",hide,"RIGHT",8,0)
    revert:SetScript("OnClick",function()
        if InCombatLockdown() then return end
        ns.ConfigSessionStageGroup("raid",ns.GetGroupLayout("raid")); ns.ConfigSessionStagePosition("raid",ns.GetPosition("raid"))
        refreshRaidControls(); MarkPending()
        if ns.raidFrameMoverOwner and ns.raidFrameMoverOwner:IsShown() then ns.ShowRaidPreview() end
    end)
    refreshRaidControls=function()
        local previous=refreshing; refreshing=true; raidWorking=ns.ConfigSessionGetGroup("raid")
        for prefix,c in pairs(controls) do
            c.orientation:SetText("Layout: "..GROUP_ORIENTATION_NAMES[raidWorking[prefix.."Orientation"]])
            c.direction:SetText("Grow: "..raidWorking[prefix.."Direction"])
            c.spacing:SetValue(raidWorking[prefix.."Spacing"])
        end
        rows:SetValue(raidWorking.groupsPerRow); refreshing=previous
    end
end
local function CreateProfilesPage()
    profilesPage=CreateFrame("Frame",nil,config); profilesPage:SetPoint("TOPLEFT",160,-80); profilesPage:SetPoint("BOTTOMRIGHT",-10,50)
    local section=MakeSection(profilesPage,"Profile Management",690,430); section:SetPoint("TOPLEFT",20,-62)

    profileCurrentLabel=section:CreateFontString(nil,"OVERLAY"); profileCurrentLabel:SetFont(FONT,14,"OUTLINE"); profileCurrentLabel:SetPoint("TOPLEFT",18,-38)
    profileCharacterLabel=section:CreateFontString(nil,"OVERLAY"); profileCharacterLabel:SetFont(FONT,10,"OUTLINE"); profileCharacterLabel:SetPoint("TOPLEFT",18,-62); profileCharacterLabel:SetTextColor(0.7,0.76,0.82)

    local listTitle=section:CreateFontString(nil,"OVERLAY"); listTitle:SetFont(FONT,11,"OUTLINE"); listTitle:SetPoint("TOPLEFT",18,-96); listTitle:SetText("Profiles")
    for i=1,10 do
        local b=MakeButton(section,"",220,26); b:SetPoint("TOPLEFT",18,-118-((i-1)*29)); b:SetScript("OnClick",function(self)
            selectedProfileName=self.ProfileName
            SetProfileStatus("Selected "..selectedProfileName..". Use Profile will switch this character and reload the UI.",false)
            RefreshProfilesControls()
        end); profileButtons[i]=b
    end

    local nameLabel=section:CreateFontString(nil,"OVERLAY"); nameLabel:SetFont(FONT,11,"OUTLINE"); nameLabel:SetPoint("TOPLEFT",275,-96); nameLabel:SetText("Profile name")
    profileNameBox=CreateFrame("EditBox",nil,section,"InputBoxTemplate"); profileNameBox:SetSize(250,24); profileNameBox:SetPoint("TOPLEFT",275,-118); profileNameBox:SetAutoFocus(false); profileNameBox:SetMaxLetters(40)
    profileNameBox:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
    profileNameBox:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)

    local use=MakeButton(section,"Use Profile",120,28); use:SetPoint("TOPLEFT",275,-158); use:SetScript("OnClick",function()
        if InCombatLockdown() then SetProfileStatus("Profiles cannot be switched during combat.",true); return end
        if ns.ConfigSessionIsDirty() then SetProfileStatus("Apply pending changes before switching profiles.",true); return end
        local target=selectedProfileName or ns.GetActiveProfileName()
        if target==ns.GetActiveProfileName() then SetProfileStatus(target.." is already active.",false); return end
        local ok,msg=ns.SetActiveProfile(target)
        if not ok then SetProfileStatus(msg,true); return end
        ReloadUI()
    end)

    local create=MakeButton(section,"Create New",120,28); create:SetPoint("LEFT",use,"RIGHT",8,0); create:SetScript("OnClick",function()
        if InCombatLockdown() then SetProfileStatus("Profiles cannot be changed during combat.",true); return end
        local ok,msg=ns.CreateProfile(profileNameBox:GetText())
        if not ok then SetProfileStatus(msg,true); return end
        selectedProfileName=msg; profileNameBox:SetText(""); SetProfileStatus("Created "..msg.." from defaults.",false); RefreshProfilesControls()
    end)

    local copy=MakeButton(section,"Copy Current",120,28); copy:SetPoint("TOPLEFT",275,-198); copy:SetScript("OnClick",function()
        if InCombatLockdown() then SetProfileStatus("Profiles cannot be changed during combat.",true); return end
        local ok,msg=ns.CopyProfile(ns.GetActiveProfileName(),profileNameBox:GetText())
        if not ok then SetProfileStatus(msg,true); return end
        selectedProfileName=msg; profileNameBox:SetText(""); SetProfileStatus("Copied current profile to "..msg..".",false); RefreshProfilesControls()
    end)

    local rename=MakeButton(section,"Rename Selected",120,28); rename:SetPoint("LEFT",copy,"RIGHT",8,0); rename:SetScript("OnClick",function()
        if InCombatLockdown() then SetProfileStatus("Profiles cannot be changed during combat.",true); return end
        local source=selectedProfileName or ns.GetActiveProfileName()
        local ok,msg=ns.RenameProfile(source,profileNameBox:GetText())
        if not ok then SetProfileStatus(msg,true); return end
        selectedProfileName=msg; profileNameBox:SetText(""); SetProfileStatus("Profile renamed to "..msg..".",false); RefreshProfilesControls()
    end)

    local delete=MakeButton(section,"Delete Selected",120,28); delete:SetPoint("TOPLEFT",275,-238); delete:SetScript("OnClick",function()
        if InCombatLockdown() then SetProfileStatus("Profiles cannot be changed during combat.",true); return end
        local source=selectedProfileName
        if not source then SetProfileStatus("Select a profile first.",true); return end
        local ok,msg=ns.DeleteProfile(source)
        if not ok then SetProfileStatus(msg,true); return end
        selectedProfileName=ns.GetActiveProfileName(); SetProfileStatus("Deleted "..source..".",false); RefreshProfilesControls()
    end)

    local note=section:CreateFontString(nil,"OVERLAY"); note:SetFont(FONT,10,"OUTLINE"); note:SetPoint("TOPLEFT",275,-292); note:SetWidth(380); note:SetJustifyH("LEFT")
    note:SetText("Create New starts from MythInc defaults. Copy Current duplicates every setting in the active profile. Each character remembers which profile it uses. Switching profiles reloads the UI so secure frames and aura containers rebuild from one consistent settings set.")
    note:SetTextColor(0.7,0.76,0.82)

    profileActionStatus=section:CreateFontString(nil,"OVERLAY"); profileActionStatus:SetFont(FONT,10,"OUTLINE"); profileActionStatus:SetPoint("TOPLEFT",275,-365); profileActionStatus:SetWidth(380); profileActionStatus:SetJustifyH("LEFT")
end

local function CreateConfig()
    if config then return end; CreateShell(); CreateFramesPage(); CreateAurasPage(); CreateProfilesPage(); CreateRaidPage()
    local watcher=CreateFrame("Frame",nil,config); watcher:RegisterEvent("UNIT_AURA"); watcher:SetScript("OnEvent",function() if (config:IsShown() or trackedBuffWindow:IsShown()) and selectedPage=="auras" and selectedAura=="buffs" then RefreshTrackedWindow() end end)
    config:HookScript("OnShow",function() applyChangesButton:SetEnabled(ns.ConfigSessionIsDirty()); ns.RefreshConfig() end); config:Hide()
end

function ns.ToggleConfig() CreateConfig(); if config:IsShown() then config:Hide() else config:Show() end end

local lockMoversButton=MakeButton(UIParent,"Lock Movers",120,28)
lockMoversButton:SetPoint("TOP",UIParent,"TOP",0,-100)
lockMoversButton:SetFrameStrata("DIALOG")
lockMoversButton:SetClampedToScreen(true)
lockMoversButton:Hide()

function ns.UpdateLockMoversButton()
    local frameLocked,auraLocked=ns.AreFrameMoversLocked(),ns.AreAuraMoversLocked()
    lockMoversButton:SetShown(not InCombatLockdown() and (not frameLocked or not auraLocked))
    if frameLockButton then frameLockButton:SetText(frameLocked and "Unlock Frame Movers" or "Lock Frame Movers") end
    if auraLockButton then auraLockButton:SetText(auraLocked and "Unlock Aura Movers" or "Lock Aura Movers") end
end

lockMoversButton:SetScript("OnClick",function()
    if InCombatLockdown() then return end
    ns.SetFrameMoversLockedState(true); ns.SetAuraMoversLockedState(true)
    ns.SetMoversLocked(true)
end)

local combatWatcher=CreateFrame("Frame")
combatWatcher:RegisterEvent("PLAYER_REGEN_DISABLED"); combatWatcher:RegisterEvent("PLAYER_REGEN_ENABLED"); combatWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
combatWatcher:SetScript("OnEvent",function(_,event)
    if event~="PLAYER_ENTERING_WORLD" then
        if not InCombatLockdown() then RestoreFramePreview(); RestoreAuraPreview() end
        ns.SetAuraMoversLocked(InCombatLockdown() or ns.AreAuraMoversLocked())
        if config and config:IsShown() then ns.RefreshConfig() end
    end
    ns.UpdateLockMoversButton()
end)
