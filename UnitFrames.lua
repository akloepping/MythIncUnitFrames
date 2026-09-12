local ADDON_NAME, ns = ...

ns.UnitFramesLoaded = true

local FLAT = "Interface\\Buttons\\WHITE8x8"
local FONT = "Fonts\\FRIZQT__.TTF"
local RAID_TARGET_TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local frames, previewEnabled = {}, {}
ns.frames = frames

-- Match SecureButton_GetModifiedUnit's player/pet swap under toggleForVehicle.
-- Blizzard uses "vehicle" for the player's visual data (the secure click uses
-- the equivalent "pet" token). Keep logical identities/configuration unchanged.
local VEHICLE_DISPLAY_UNITS = { player = "vehicle", pet = "player" }
local VEHICLE_EVENTS = {
    UNIT_ENTERING_VEHICLE = true, UNIT_ENTERED_VEHICLE = true,
    UNIT_EXITING_VEHICLE = true, UNIT_EXITED_VEHICLE = true,
    UNIT_PET = true, VEHICLE_UPDATE = true,
}

function ns.GetFrameDisplayUnit(frame)
    local unit = frame and frame.MIUF_Unit
    if VEHICLE_DISPLAY_UNITS[unit] and UnitHasVehicleUI("player") then
        return VEHICLE_DISPLAY_UNITS[unit]
    end
    return unit
end

-- Subscribe to both identities at creation, including during combat transitions.
function ns.RegisterFrameUnitEvent(eventFrame, event, frame)
    local unit = frame.MIUF_Unit
    local vehicleUnit = VEHICLE_DISPLAY_UNITS[unit]
    if vehicleUnit then eventFrame:RegisterUnitEvent(event, unit, vehicleUnit)
    else eventFrame:RegisterUnitEvent(event, unit) end
end

local function CreateBackground(parent)
    local bg = parent:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(parent)
    bg:SetColorTexture(0.03, 0.03, 0.03, 0.92)
    return bg
end

local function CreateBorder(parent)
    local border = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetBackdrop({ edgeFile = FLAT, edgeSize = 1 })
    border:SetBackdropBorderColor(0.1, 0.1, 0.1, 1)
    border:SetFrameLevel(parent:GetFrameLevel() + 5)
    return border
end

local function ApplyPosition(positionKey, frame)
    local p = ns.GetPosition(positionKey)
    if not p then return end
    frame:ClearAllPoints()
    frame:SetPoint(p.point, UIParent, p.relativePoint, p.x, p.y)
end

local function SaveMoverPosition(frame, positionKey)
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    ns.SavePosition(positionKey, point or "CENTER", relativePoint or point or "CENTER", x or 0, y or 0)
end

local function BuildFrameState(unitType, overrides)
    local savedSize = ns.GetSize(unitType) or {}
    local savedAppearance = ns.GetAppearance(unitType) or {}
    local state = { size = { width = savedSize.width, height = savedSize.height }, powerPercent = ns.GetPowerPercent(unitType), appearance = {} }
    for key, value in pairs(savedAppearance) do state.appearance[key] = value end
    if overrides then
        if overrides.size then
            if overrides.size.width ~= nil then state.size.width = overrides.size.width end
            if overrides.size.height ~= nil then state.size.height = overrides.size.height end
        end
        if overrides.powerPercent ~= nil then state.powerPercent = overrides.powerPercent end
        if overrides.appearance then for key, value in pairs(overrides.appearance) do state.appearance[key] = value end end
    end
    return state
end

local function UpdateHealth(frame)
    local unit = ns.GetFrameDisplayUnit(frame)
    if not unit then return end
    local value = UnitHealthPercent(unit, true, CurveConstants and CurveConstants.ScaleTo100)
    if value ~= nil then frame.Health:SetValue(value) end
    if frame.HealthText then
        -- SetFormattedText is a secret-capable display sink. Do not inspect or
        -- calculate with the percentage in Lua; let the FontString format it.
        local displayed = false
        if value ~= nil then
            displayed = pcall(frame.HealthText.SetFormattedText, frame.HealthText, "%.0f%%", value)
        end
        if not displayed then frame.HealthText:SetText("") end
    end
end

local function UpdatePower(frame)
    local unit = ns.GetFrameDisplayUnit(frame)
    if not unit then return end
    local value = UnitPowerPercent(unit, nil, false, CurveConstants and CurveConstants.ScaleTo100)
    if value ~= nil then frame.Power:SetValue(value) end
end

local function UpdateName(frame)
    local unit = ns.GetFrameDisplayUnit(frame)
    if not unit then return end
    local name = UnitName(unit)
    frame.NameText:SetText(name or "")
end

local function UpdatePortrait(frame)
    local unit = ns.GetFrameDisplayUnit(frame)
    if frame.Portrait and unit then SetPortraitTexture(frame.Portrait, unit) end
end

local function GetAutomaticHealthColor(unit)
    if not unit or not UnitExists(unit) then return 0.45, 0.45, 0.45 end
    if UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        -- The native API accepts secret class tokens; pass its RGB values straight
        -- to SetStatusBarColor rather than indexing a Lua table with the token.
        local color = class and C_ClassColor.GetClassColor(class)
        if color then return color:GetRGB() end
    end
    local reaction = UnitReaction(unit, "player")
    if not canaccessvalue(reaction) then return 0.45, 0.45, 0.45 end
    if reaction then
        if reaction <= 3 then return 0.80, 0.18, 0.18 end
        if reaction == 4 then return 0.85, 0.75, 0.20 end
        return 0.20, 0.75, 0.25
    end
    return 0.20, 0.75, 0.25
end

local POWER_COLORS = {
    MANA={0.10,0.35,0.95}, RAGE={0.90,0.12,0.12}, FOCUS={0.95,0.45,0.10}, ENERGY={0.95,0.85,0.10},
    RUNIC_POWER={0.10,0.80,0.95}, LUNAR_POWER={0.25,0.50,1.00}, INSANITY={0.55,0.20,0.80}, FURY={0.75,0.20,1.00}, MAELSTROM={0.10,0.55,1.00},
}

local function GetAutomaticPowerColor(unit)
    if not unit or not UnitExists(unit) then return 0.20,0.40,0.90 end
    local _, token = UnitPowerType(unit)
    -- Preserve MIUF's palette for public tokens; never use a secret table key.
    if not canaccessvalue(token) then return 0.20,0.40,0.90 end
    local c = token and POWER_COLORS[token]
    if c then return c[1],c[2],c[3] end
    return 0.20,0.40,0.90
end

local function ApplyColors(frame, appearance)
    if appearance.healthColor == "automatic" then
        local r,g,b = GetAutomaticHealthColor(ns.GetFrameDisplayUnit(frame)); frame.Health:SetStatusBarColor(r,g,b,1)
    else
        local e = ns.Media.healthColors[appearance.healthColor] or ns.Media.healthColors.green; local c=e.rgb; frame.Health:SetStatusBarColor(c[1],c[2],c[3],1)
    end
    if appearance.powerColor == "automatic" then
        local r,g,b = GetAutomaticPowerColor(ns.GetFrameDisplayUnit(frame)); frame.Power:SetStatusBarColor(r,g,b,1)
    else
        local e = ns.Media.powerColors[appearance.powerColor] or ns.Media.powerColors.blue; local c=e.rgb; frame.Power:SetStatusBarColor(c[1],c[2],c[3],1)
    end
end

local function ApplyIndicatorLayout(frame, appearance)
    if frame.RaidTargetIndicatorFrame then
        local size=math.max(8,tonumber(appearance.raidMarkerSize) or 20)
        frame.RaidTargetIndicatorFrame:SetSize(size,size); frame.RaidTargetIndicatorFrame:ClearAllPoints()
        frame.RaidTargetIndicatorFrame:SetPoint("CENTER",frame,"TOP",appearance.raidMarkerXOffset or 0,appearance.raidMarkerYOffset or 2)
    end
    if frame.GroupRoleIndicator then
        local size=math.max(8,math.min(48,tonumber(appearance.roleIconSize) or 14))
        frame.GroupRoleIndicator:SetSize(size,size)
        frame.GroupRoleIndicator:ClearAllPoints(); frame.GroupRoleIndicator:SetPoint("TOPLEFT",frame.Health,"TOPLEFT",appearance.roleIconXOffset or 3,appearance.roleIconYOffset or -3)
    end
end

local function UpdateRaidTarget(frame, appearance)
    local holder,icon=frame.RaidTargetIndicatorFrame,frame.RaidTargetIndicator
    if not holder or not icon then return end
    appearance=appearance or ns.GetAppearance(frame.MIUF_UnitType) or {}
    local unit=ns.GetFrameDisplayUnit(frame)
    if appearance.showRaidMarker==false or not unit or not UnitExists(unit) then holder:Hide(); return end
    local index=GetRaidTargetIndex(unit)
    if frame.MIUF_UnitType=="raid" and not canaccessvalue(index) then holder:Hide(); return end
    if index then icon:SetTexture(RAID_TARGET_TEXTURE); SetRaidTargetIconTexture(icon,index); holder:Show() else holder:Hide() end
end

local function UpdateRoleIndicator(frame, appearance)
    local icon=frame.GroupRoleIndicator; if not icon then return end
    appearance=appearance or ns.GetAppearance(frame.MIUF_UnitType) or {}
    if not appearance.showRoleIcon then icon:Hide(); return end
    local role=UnitGroupRolesAssigned(ns.GetFrameDisplayUnit(frame)); local atlas
    if not canaccessvalue(role) then icon:Hide(); return end
    if role=="TANK" then atlas="groupfinder-icon-role-large-tank" elseif role=="HEALER" then atlas="groupfinder-icon-role-large-heal" elseif role=="DAMAGER" then atlas="groupfinder-icon-role-large-dps" end
    if atlas then icon:SetAtlas(atlas); icon:Show() else icon:Hide() end
end

local function UpdateConnectionState(frame)
    local text,unit=frame.OfflineText,ns.GetFrameDisplayUnit(frame)
    if not text or not unit or not UnitExists(unit) then if text then text:Hide() end; return end
    local connected=UnitIsConnected(unit)
    if canaccessvalue and not canaccessvalue(connected) then text:Hide(); return end
    if connected==false then frame.Health:SetStatusBarColor(0.32,0.32,0.32,1); frame.Power:SetStatusBarColor(0.20,0.20,0.20,1); text:Show() else text:Hide() end
end

local function UpdateFrame(frame)
    UpdateHealth(frame); UpdatePower(frame); UpdateName(frame); UpdatePortrait(frame)
    local appearance=ns.GetAppearance(frame.MIUF_UnitType) or {}
    ApplyColors(frame,appearance)
    -- Raid roster callbacks only update display sinks. Indicator anchors are
    -- established by ApplyFrameState outside combat, never by roster updates.
    if frame.MIUF_UnitType~="raid" then ApplyIndicatorLayout(frame,appearance) end
    UpdateRaidTarget(frame,appearance); UpdateRoleIndicator(frame,appearance); UpdateConnectionState(frame)
end

local function ApplyFrameState(frame,state)
    local appearance=state.appearance; local width,height=state.size.width,state.size.height; frame:SetSize(width,height)
    local texture=ns.GetTexturePath(appearance.texture); frame.Health:SetStatusBarTexture(texture); frame.Power:SetStatusBarTexture(texture)
    frame.Background:SetColorTexture(0.03,0.03,0.03,appearance.backgroundOpacity/100); frame.Border:SetBackdropBorderColor(0.1,0.1,0.1,appearance.borderOpacity/100)
    local showPortrait=frame.Portrait and appearance.showPortrait
    local portraitWidth=showPortrait and math.max(18,math.floor(width*(appearance.portraitPercent/100))) or 0
    if frame.Portrait then frame.Portrait:ClearAllPoints() end
    if showPortrait then
        frame.Portrait:SetWidth(portraitWidth); frame.Portrait:SetPoint("TOP",frame,"TOP",0,-2); frame.Portrait:SetPoint("BOTTOM",frame,"BOTTOM",0,2)
        if appearance.portraitSide=="RIGHT" then frame.Portrait:SetPoint("RIGHT",frame,"RIGHT",-2,0) else frame.Portrait:SetPoint("LEFT",frame,"LEFT",2,0) end
        frame.Portrait:Show()
    elseif frame.Portrait then frame.Portrait:Hide() end
    local leftInset,rightInset=2,2
    if showPortrait then if appearance.portraitSide=="RIGHT" then rightInset=portraitWidth+4 else leftInset=portraitWidth+4 end end
    local powerHeight=math.max(8,math.floor(height*(state.powerPercent/100)))
    frame.Health:ClearAllPoints(); frame.Health:SetPoint("TOPLEFT",frame,"TOPLEFT",leftInset,-2); frame.Health:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-rightInset,-2); frame.Health:SetPoint("BOTTOM",frame,"BOTTOM",0,powerHeight)
    frame.Power:ClearAllPoints(); frame.Power:SetPoint("TOPLEFT",frame.Health,"BOTTOMLEFT",0,-1); frame.Power:SetPoint("TOPRIGHT",frame.Health,"BOTTOMRIGHT",0,-1); frame.Power:SetPoint("BOTTOM",frame,"BOTTOM",0,2)
    local nameX,nameY=appearance.nameXOffset or 6,appearance.nameYOffset or 0
    local healthTextWidth=frame.MIUF_UnitType=="raid" and math.min(42,math.floor(width*0.35)) or 42
    frame.NameText:ClearAllPoints(); frame.NameText:SetPoint("LEFT",frame.Health,"LEFT",nameX,nameY); frame.NameText:SetPoint("RIGHT",frame.Health,"RIGHT",nameX-healthTextWidth-6,nameY)
    local healthX,healthY=appearance.healthXOffset or -6,appearance.healthYOffset or 0
    frame.HealthText:ClearAllPoints(); frame.HealthText:SetPoint("RIGHT",frame.Health,"RIGHT",healthX,healthY); frame.HealthText:SetWidth(healthTextWidth)
    local font=ns.GetFontPath(appearance.fontFace); frame.NameText:SetFont(font,appearance.fontSize,"OUTLINE"); frame.HealthText:SetFont(font,math.max(9,appearance.fontSize-1),"OUTLINE")
    frame.NameText:SetShown(appearance.showName); frame.HealthText:SetShown(appearance.showHealthText)
    ApplyColors(frame,appearance); ApplyIndicatorLayout(frame,appearance); UpdateRoleIndicator(frame,appearance); UpdateRaidTarget(frame,appearance); UpdateConnectionState(frame)
end

local function CreateMover(frame,labelText,positionKey)
    frame:SetMovable(true); frame:SetClampedToScreen(true)
    local mover=CreateFrame("Frame",nil,UIParent,"BackdropTemplate"); mover:SetFrameStrata("DIALOG"); mover:SetAllPoints(frame)
    mover:SetMovable(true); mover:SetClampedToScreen(true)
    mover:SetBackdrop({bgFile=FLAT,edgeFile=FLAT,edgeSize=1}); mover:SetBackdropColor(0.05,0.35,0.8,0.28); mover:SetBackdropBorderColor(0.2,0.65,1,1); mover:EnableMouse(true); mover:RegisterForDrag("LeftButton")
    local label=mover:CreateFontString(nil,"OVERLAY"); label:SetFont(FONT,11,"OUTLINE"); label:SetPoint("CENTER"); label:SetText(labelText)
    local dragTarget=frame
    mover:SetScript("OnDragStart",function()
        if InCombatLockdown() then return end
        -- Hidden group frames keep their secure visibility; move their independent mover instead.
        local group=frame.MIUF_UnitType=="party" or frame.MIUF_UnitType=="boss"
        dragTarget=group and not frame:IsShown() and mover or frame
        dragTarget:StartMoving()
    end)
    mover:SetScript("OnDragStop",function()
        dragTarget:StopMovingOrSizing()
        if not InCombatLockdown() then
            SaveMoverPosition(dragTarget,positionKey)
            if ns.ApplyGroupLayout then ns.ApplyGroupLayout(frame.MIUF_UnitType) end
        end
        if dragTarget==mover then mover:ClearAllPoints(); mover:SetAllPoints(frame) end
        dragTarget=frame
    end)
    local resize=CreateFrame("Button",nil,mover,"BackdropTemplate"); resize:SetSize(14,14); resize:SetPoint("BOTTOMRIGHT"); resize:SetFrameLevel(mover:GetFrameLevel()+10)
    resize:SetBackdrop({bgFile=FLAT,edgeFile=FLAT,edgeSize=1}); resize:SetBackdropColor(0.12,0.12,0.12,0.95); resize:SetBackdropBorderColor(0.8,0.8,0.8,1); resize:EnableMouse(true)
    local grip=resize:CreateFontString(nil,"OVERLAY"); grip:SetFont(FONT,10,"OUTLINE"); grip:SetPoint("CENTER",0,1); grip:SetText("↘")
    resize:SetScript("OnMouseDown",function(_,button)
        if button~="LeftButton" or InCombatLockdown() then return end
        local left,top=frame:GetLeft(),frame:GetTop(); if not left or not top then return end
        resize.MIUF_ResizeState={unitType=frame.MIUF_UnitType,left=left,top=top,minW=100,maxW=600,minH=24,maxH=150}; frame:ClearAllPoints(); frame:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",left,top)
        resize:SetScript("OnUpdate",function(handle)
            local s=handle.MIUF_ResizeState; if not s or InCombatLockdown() then return end
            local scale=UIParent:GetEffectiveScale(); local cx,cy=GetCursorPosition(); cx,cy=cx/scale,cy/scale
            ns.PreviewFrameSize(s.unitType,math.max(s.minW,math.min(s.maxW,cx-s.left)),math.max(s.minH,math.min(s.maxH,s.top-cy)))
        end)
    end)
    resize:SetScript("OnMouseUp",function(handle,button)
        if button~="LeftButton" then return end
        local s=handle.MIUF_ResizeState; handle:SetScript("OnUpdate",nil); handle.MIUF_ResizeState=nil; if not s or InCombatLockdown() then return end
        ns.SaveSize(s.unitType,frame:GetWidth(),frame:GetHeight()); SaveMoverPosition(frame,positionKey); ns.ApplyFrameType(s.unitType); if ns.RefreshConfig then ns.RefreshConfig() end
    end)
    mover.MIUF_ResizeHandle=resize; mover:Hide(); frame.MIUF_Mover=mover
end

local function CreateUnitFrame(unit,name,unitType,positionKey,registerWatch,storageKey)
    unitType=unitType or unit; positionKey=positionKey or unit
    local size=ns.GetSize(unitType); local frame=CreateFrame("Button",name,UIParent,"SecureUnitButtonTemplate")
    frame.MIUF_Unit=unit; frame.MIUF_UnitType=unitType; frame.MIUF_PositionKey=positionKey; frame.__unit=unit
    frame:SetAttribute("unit",unit); frame:SetAttribute("*type1","target"); frame:SetAttribute("*type2","togglemenu"); frame:RegisterForClicks("AnyUp"); frame:SetSize(size.width,size.height)
    if VEHICLE_DISPLAY_UNITS[unit] then frame:SetAttribute("toggleForVehicle",true) end
    frame.MIUF_DisplayUnit=ns.GetFrameDisplayUnit(frame)
    frame:SetScript("OnEnter",function(self) GameTooltip_SetDefaultAnchor(GameTooltip,self); GameTooltip:SetUnit(ns.GetFrameDisplayUnit(self)) end); frame:SetScript("OnLeave",function() GameTooltip:Hide() end)
    frame.Background=CreateBackground(frame); frame.Border=CreateBorder(frame)
    local health=CreateFrame("StatusBar",nil,frame); health:SetMinMaxValues(0,100); health:SetStatusBarTexture(FLAT); local hbg=health:CreateTexture(nil,"BACKGROUND"); hbg:SetAllPoints(health); hbg:SetColorTexture(0.08,0.08,0.08,1); frame.Health=health
    local power=CreateFrame("StatusBar",nil,frame); power:SetMinMaxValues(0,100); power:SetStatusBarTexture(FLAT); local pbg=power:CreateTexture(nil,"BACKGROUND"); pbg:SetAllPoints(power); pbg:SetColorTexture(0.05,0.05,0.05,1); frame.Power=power
    local nameText=health:CreateFontString(nil,"OVERLAY"); nameText:SetFont(FONT,12,"OUTLINE"); nameText:SetJustifyH("LEFT"); nameText:SetWordWrap(false); frame.NameText=nameText
    local healthText=health:CreateFontString(nil,"OVERLAY"); healthText:SetFont(FONT,11,"OUTLINE"); healthText:SetJustifyH("RIGHT"); frame.HealthText=healthText
    local offlineText=health:CreateFontString(nil,"OVERLAY"); offlineText:SetFont(FONT,10,"OUTLINE"); offlineText:SetPoint("CENTER"); offlineText:SetText("OFFLINE"); offlineText:Hide(); frame.OfflineText=offlineText
    if unitType~="raid" then local portrait=frame:CreateTexture(nil,"ARTWORK"); portrait:SetTexCoord(0.08,0.92,0.08,0.92); frame.Portrait=portrait end
    local markerFrame=CreateFrame("Frame",nil,frame); markerFrame:SetFrameLevel(frame.Border:GetFrameLevel()+5); markerFrame:SetSize(20,20); markerFrame:SetPoint("CENTER",frame,"TOP",0,2); markerFrame:Hide(); frame.RaidTargetIndicatorFrame=markerFrame
    local marker=markerFrame:CreateTexture(nil,"OVERLAY"); marker:SetAllPoints(markerFrame); marker:SetTexture(RAID_TARGET_TEXTURE); frame.RaidTargetIndicator=marker
    if unitType=="player" or unitType=="party" or unitType=="raid" then local role=health:CreateTexture(nil,"OVERLAY"); role:SetSize(14,14); role:SetPoint("TOPLEFT",health,"TOPLEFT",3,-3); role:Hide(); frame.GroupRoleIndicator=role end

    ns.RegisterFrameUnitEvent(frame,"UNIT_HEALTH",frame); ns.RegisterFrameUnitEvent(frame,"UNIT_MAXHEALTH",frame); ns.RegisterFrameUnitEvent(frame,"UNIT_POWER_UPDATE",frame); ns.RegisterFrameUnitEvent(frame,"UNIT_MAXPOWER",frame); ns.RegisterFrameUnitEvent(frame,"UNIT_DISPLAYPOWER",frame); ns.RegisterFrameUnitEvent(frame,"UNIT_NAME_UPDATE",frame); ns.RegisterFrameUnitEvent(frame,"UNIT_FACTION",frame); ns.RegisterFrameUnitEvent(frame,"UNIT_CONNECTION",frame); ns.RegisterFrameUnitEvent(frame,"UNIT_PORTRAIT_UPDATE",frame); ns.RegisterFrameUnitEvent(frame,"UNIT_MODEL_CHANGED",frame)
    frame:RegisterEvent("PLAYER_ENTERING_WORLD"); frame:RegisterEvent("RAID_TARGET_UPDATE"); frame:RegisterEvent("PLAYER_ROLES_ASSIGNED"); frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    -- Boss tokens become available or change after initial creation. Unit watch
    -- handles visibility; this event takes the full UpdateFrame path below.
    if unitType=="boss" then frame:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT") end
    if unit=="target" then frame:RegisterEvent("PLAYER_TARGET_CHANGED") elseif unit=="focus" then frame:RegisterEvent("PLAYER_FOCUS_CHANGED") elseif unit=="pet" then frame:RegisterUnitEvent("UNIT_PET","player") elseif unit=="targettarget" then frame:RegisterUnitEvent("UNIT_TARGET","target") end

    if VEHICLE_DISPLAY_UNITS[unit] then
        for event in pairs(VEHICLE_EVENTS) do
            if event=="VEHICLE_UPDATE" then frame:RegisterEvent(event)
            else frame:RegisterUnitEvent(event,"player") end
        end
    end

    frame:SetScript("OnEvent",function(self,event)
        local displayUnit=ns.GetFrameDisplayUnit(self)
        if displayUnit~=self.MIUF_DisplayUnit or (VEHICLE_DISPLAY_UNITS[self.MIUF_Unit] and VEHICLE_EVENTS[event]) then
            self.MIUF_DisplayUnit=displayUnit
            UpdateFrame(self)
            if ns.UpdateFrameAuraUnit then ns.UpdateFrameAuraUnit(self) end
            if ns.UpdateFrameCastbar then ns.UpdateFrameCastbar(self) end
            if GameTooltip:IsOwned(self) then GameTooltip:SetUnit(displayUnit) end
            return
        end
        if event=="UNIT_HEALTH" or event=="UNIT_MAXHEALTH" then UpdateHealth(self)
        elseif event=="UNIT_POWER_UPDATE" or event=="UNIT_MAXPOWER" then UpdatePower(self)
        elseif event=="UNIT_DISPLAYPOWER" then UpdatePower(self); ApplyColors(self,ns.GetAppearance(self.MIUF_UnitType) or {}); UpdateConnectionState(self)
        elseif event=="UNIT_NAME_UPDATE" then UpdateName(self)
        elseif event=="UNIT_PORTRAIT_UPDATE" or event=="UNIT_MODEL_CHANGED" then UpdatePortrait(self)
        elseif event=="RAID_TARGET_UPDATE" then UpdateRaidTarget(self)
        elseif event=="GROUP_ROSTER_UPDATE" and (self.MIUF_UnitType=="party" or self.MIUF_UnitType=="raid") then UpdateFrame(self)
        elseif event=="PLAYER_ROLES_ASSIGNED" or event=="GROUP_ROSTER_UPDATE" then UpdateRoleIndicator(self); ApplyColors(self,ns.GetAppearance(self.MIUF_UnitType) or {}); UpdateConnectionState(self)
        elseif event=="UNIT_CONNECTION" then UpdateFrame(self)
        elseif event=="UNIT_FACTION" then ApplyColors(self,ns.GetAppearance(self.MIUF_UnitType) or {}); UpdateConnectionState(self)
        elseif event=="UNIT_TARGET" and self.MIUF_Unit=="targettarget" then UpdateFrame(self)
        else UpdateFrame(self) end
    end)

    -- Blizzard continuously reconciles target-of-target data instead of trusting
    -- UNIT_TARGET alone. RegisterUnitWatch remains responsible for secure visibility;
    -- this updater only keeps the displayed unit data synchronized.
    if unit=="targettarget" then
        local totElapsed=0
        frame:SetScript("OnUpdate",function(self,elapsed)
            totElapsed=totElapsed+elapsed
            if totElapsed<0.10 then return end
            totElapsed=0
            if UnitExists("target") and UnitExists("targettarget") then UpdateFrame(self) end
        end)
    end

    if unitType~="raid" then
        local moverLabel=(unitType=="party" or unitType=="boss") and unit or unitType; CreateMover(frame,moverLabel,positionKey); ApplyPosition(positionKey,frame)
    end
    ApplyFrameState(frame,BuildFrameState(unitType)); UpdateFrame(frame)
    if registerWatch~=false then
        if unitType=="party" and unit:match("^party%d+$") and RegisterStateDriver then RegisterStateDriver(frame,"visibility",string.format("[group:raid] hide; [group:party,@%s,exists] show; hide",unit)) else RegisterUnitWatch(frame) end
    else frame:Hide() end
    frames[storageKey or unit]=frame; return frame
end

function ns.ApplyFrameType(unitType)
    if unitType=="raid" and InCombatLockdown() then return end
    local state=BuildFrameState(unitType); for _,frame in pairs(frames) do if frame.MIUF_UnitType==unitType then ApplyFrameState(frame,state) end end
    if not InCombatLockdown() and ns.ApplyGroupLayout then ns.ApplyGroupLayout(unitType) end
end
ns.ApplySize=ns.ApplyFrameType

function ns.PreviewFrameType(unitType,overrides)
    if InCombatLockdown() then return end
    local state=BuildFrameState(unitType,overrides); for _,frame in pairs(frames) do if frame.MIUF_UnitType==unitType then ApplyFrameState(frame,state) end end
    if ns.ApplyGroupLayout then ns.ApplyGroupLayout(unitType) end
end
function ns.PreviewFrameSize(unitType,width,height) ns.PreviewFrameType(unitType,{size={width=width,height=height}}) end
function ns.IsUnitTypePreviewEnabled(unitType) return previewEnabled[unitType]~=false end

function ns.SetFrameMoversLocked(locked)
    for _,frame in pairs(frames) do
        local mover=frame.MIUF_Mover
        if mover then
            local unitType=frame.MIUF_UnitType; local groupOwnerMismatch=unitType=="party" and ns.partyFrameMoverOwner~=frame; local bossOwnerMismatch=unitType=="boss" and frame.MIUF_Unit~="boss1"
            if locked or previewEnabled[unitType]==false or not ns.IsFrameTypeEnabled(unitType) or groupOwnerMismatch or bossOwnerMismatch then mover:Hide() else mover:Show() end
        end
    end
    if ns.UpdateLockMoversButton then ns.UpdateLockMoversButton() end
end
function ns.PreviewUnitTypeMovers(unitType,enabled) previewEnabled[unitType]=enabled and true or false; ns.SetFrameMoversLocked(ns.AreFrameMoversLocked()) end
function ns.SetMoversLocked(locked) ns.SetFrameMoversLocked(locked); if ns.SetAuraMoversLocked then ns.SetAuraMoversLocked(locked) end end
function ns.ResetLayout() for _,frame in pairs(frames) do ApplyPosition(frame.MIUF_PositionKey or frame.MIUF_Unit,frame) end; for unitType in pairs(ns.defaultSizes) do ns.ApplyFrameType(unitType) end; ns.SetFrameMoversLocked(true) end

local spawned=false
function ns.SpawnAllFrames()
    if spawned or InCombatLockdown() then return end; spawned=true
    if ns.IsFrameTypeEnabled("player") then CreateUnitFrame("player","MIUF_Player") end
    if ns.IsFrameTypeEnabled("target") then CreateUnitFrame("target","MIUF_Target") end
    if ns.IsFrameTypeEnabled("focus") then CreateUnitFrame("focus","MIUF_Focus") end
    if ns.IsFrameTypeEnabled("pet") then CreateUnitFrame("pet","MIUF_Pet") end
    if ns.IsFrameTypeEnabled("targettarget") then CreateUnitFrame("targettarget","MIUF_TargetTarget") end
    if ns.IsFrameTypeEnabled("party") then
        for i=1,4 do local unit="party"..i; CreateUnitFrame(unit,"MIUF_Party"..i,"party","party1") end
        CreateUnitFrame("player","MIUF_PartyPlayer","party","party1",false,"partyplayer")
    end
    if ns.IsFrameTypeEnabled("boss") then for i=1,5 do local unit="boss"..i; CreateUnitFrame(unit,"MIUF_Boss"..i,"boss","boss1") end end
    if ns.IsFrameTypeEnabled("raid") then
        local anchor=ns.GetRaidAnchor()
        local capacity=ns.GetGroupLayout("raid").legacy40 and 40 or 30
        for i=1,capacity do
            local frame=CreateUnitFrame("raid"..i,"MIUF_Raid"..i,"raid","raid")
            frame:SetParent(anchor)
        end
        ns.ApplyRaidLayout()
    end
    if ns.ApplyPartyLayout then ns.ApplyPartyLayout() end; if ns.ApplyBossLayout then ns.ApplyBossLayout() end; ns.SetFrameMoversLocked(ns.AreFrameMoversLocked())
end

local rangeWatcher=CreateFrame("Frame"); local rangeElapsed=0
rangeWatcher:SetScript("OnUpdate",function(_,elapsed)
    rangeElapsed=rangeElapsed+elapsed; if rangeElapsed<0.25 then return end; rangeElapsed=0
    for _,frame in pairs(frames) do
        if (frame.MIUF_UnitType=="party" or frame.MIUF_UnitType=="raid") and frame.MIUF_Unit~="player" and UnitExists(frame.MIUF_Unit) then
            local inRange=UnitInRange(frame.MIUF_Unit)
            if frame.SetAlphaFromBoolean then frame:SetAlphaFromBoolean(inRange,1,0.55) elseif not canaccessvalue or canaccessvalue(inRange) then frame:SetAlpha(inRange and 1 or 0.55) end
        elseif frame.MIUF_UnitType~="party" or frame.MIUF_Unit=="player" then frame:SetAlpha(1) end
    end
end)

local combatWatcher=CreateFrame("Frame"); combatWatcher:RegisterEvent("PLAYER_REGEN_DISABLED"); combatWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
combatWatcher:SetScript("OnEvent",function(_,event)
    if event=="PLAYER_REGEN_DISABLED" then ns.SetFrameMoversLocked(true)
    else if ns.ApplyPartyLayout then ns.ApplyPartyLayout() end; if ns.ApplyBossLayout then ns.ApplyBossLayout() end; ns.SetFrameMoversLocked(ns.AreFrameMoversLocked()) end
end)
