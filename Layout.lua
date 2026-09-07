local ADDON_NAME, ns = ...
local oUF = _G.oUF
if not oUF then error(ADDON_NAME .. " requires the standalone oUF addon.") end

local FLAT = "Interface\\Buttons\\WHITE8x8"
local FONT = "Fonts\\FRIZQT__.TTF"
local frames, previewEnabled = {}, {}
ns.frames = frames

local function UnitType(unit)
    if unit:match("^party%d+$") then return "party" end
    if unit:match("^boss%d+$") then return "boss" end
    return unit
end

local function CreateBackground(parent)
    local bg = parent:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(parent); bg:SetColorTexture(0.03,0.03,0.03,0.92); return bg
end

local function CreateBorder(parent)
    local border = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    border:SetPoint("TOPLEFT", -1, 1); border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetBackdrop({ edgeFile = FLAT, edgeSize = 1 }); border:SetBackdropBorderColor(0.1,0.1,0.1,1)
    border:SetFrameLevel(parent:GetFrameLevel() + 5); return border
end

local function CreateCastbar(self)
    local castbar = CreateFrame("StatusBar", nil, self)
    castbar:SetStatusBarTexture(FLAT); castbar:SetStatusBarColor(0.85,0.65,0.15,1)
    castbar:SetHeight(18); castbar:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -5); castbar:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, -5)
    local bg=castbar:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.04,0.04,0.04,0.95)
    local text=castbar:CreateFontString(nil,"OVERLAY"); text:SetFont(FONT,10,"OUTLINE"); text:SetPoint("LEFT",4,0); text:SetPoint("RIGHT",-36,0); text:SetJustifyH("LEFT"); text:SetWordWrap(false)
    local time=castbar:CreateFontString(nil,"OVERLAY"); time:SetFont(FONT,10,"OUTLINE"); time:SetPoint("RIGHT",-4,0); time:SetJustifyH("RIGHT")
    local icon=castbar:CreateTexture(nil,"ARTWORK"); icon:SetSize(18,18); icon:SetPoint("RIGHT",castbar,"LEFT",-2,0); icon:SetTexCoord(0.08,0.92,0.08,0.92)
    castbar.Text=text; castbar.Time=time; castbar.Icon=icon; castbar.timeToHold=0.35; self.Castbar=castbar
end

local function CreateRaidTargetIndicator(self)
    local icon=self:CreateTexture(nil,"OVERLAY"); icon:SetSize(20,20); icon:SetPoint("CENTER",self,"TOP",0,2); self.RaidTargetIndicator=icon
end

local function CreateRoleIndicator(self)
    local role=self.Health:CreateTexture(nil,"OVERLAY"); role:SetSize(14,14); role:SetPoint("TOPLEFT",self.Health,"TOPLEFT",3,-3); self.GroupRoleIndicator=role
end

local function CreatePortrait(self)
    local portrait=self:CreateTexture(nil,"ARTWORK"); portrait:SetTexCoord(0.08,0.92,0.08,0.92)
    portrait.Override=function(frame)
        local element, activeUnit=frame.Portrait, frame.__unit
        if element and activeUnit then SetPortraitTexture(element, activeUnit) end
    end
    self.Portrait=portrait
end

local function ApplyPosition(unit, frame)
    local p=ns.GetPosition(unit); if not p then return end
    frame:ClearAllPoints(); frame:SetPoint(p.point,UIParent,p.relativePoint,p.x,p.y)
end

local function SaveMoverPosition(self, unit)
    local point,_,relativePoint,x,y=self:GetPoint(1)
    local unitType=self.MIUF_UnitType
    local positionKey=(unitType=="party" and "party1") or (unitType=="boss" and "boss1") or unit
    ns.SavePosition(positionKey, point or "CENTER", relativePoint or point or "CENTER", x or 0, y or 0)
    if ns.ApplyGroupLayout then ns.ApplyGroupLayout(unitType) end
end

local function CreateMover(self, unit)
    self:SetMovable(true); self:SetClampedToScreen(true)
    local mover=CreateFrame("Frame",nil,UIParent,"BackdropTemplate"); mover:SetFrameStrata("DIALOG"); mover:SetAllPoints(self)
    mover:SetBackdrop({bgFile=FLAT,edgeFile=FLAT,edgeSize=1}); mover:SetBackdropColor(0.05,0.35,0.8,0.28); mover:SetBackdropBorderColor(0.2,0.65,1,1)
    mover:EnableMouse(true); mover:RegisterForDrag("LeftButton")
    local label=mover:CreateFontString(nil,"OVERLAY"); label:SetFont(FONT,11,"OUTLINE"); label:SetPoint("CENTER")
    label:SetText(self.MIUF_UnitType=="party" and "Party Group" or (self.MIUF_UnitType=="boss" and "Boss Group" or unit))
    mover:SetScript("OnDragStart",function() if not InCombatLockdown() then self:StartMoving() end end)
    mover:SetScript("OnDragStop",function() self:StopMovingOrSizing(); if not InCombatLockdown() then SaveMoverPosition(self,unit) end end)

    local resize=CreateFrame("Button",nil,mover,"BackdropTemplate"); resize:SetSize(14,14); resize:SetPoint("BOTTOMRIGHT"); resize:SetFrameLevel(mover:GetFrameLevel()+10)
    resize:SetBackdrop({bgFile=FLAT,edgeFile=FLAT,edgeSize=1}); resize:SetBackdropColor(0.12,0.12,0.12,0.95); resize:SetBackdropBorderColor(0.8,0.8,0.8,1); resize:EnableMouse(true)
    local grip=resize:CreateFontString(nil,"OVERLAY"); grip:SetFont(FONT,10,"OUTLINE"); grip:SetPoint("CENTER",0,1); grip:SetText("↘")
    resize:SetScript("OnMouseDown",function(_,button)
        if button~="LeftButton" or InCombatLockdown() then return end
        local left,top=self:GetLeft(),self:GetTop(); if not left or not top then return end
        local startW,startH=self:GetWidth(),self:GetHeight(); local aspect=startW/math.max(1,startH)
        local minW=math.max(100,24*aspect); local maxW=math.min(600,150*aspect); if minW>maxW then minW,maxW=startW,startW end
        resize.MIUF_ResizeState={unitType=self.MIUF_UnitType,left=left,top=top,startW=startW,startH=startH,aspect=aspect,minW=minW,maxW=maxW}
        self:ClearAllPoints(); self:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",left,top)
        resize:SetScript("OnUpdate",function(handle)
            local s=handle.MIUF_ResizeState; if not s or InCombatLockdown() then return end
            local scale=UIParent:GetEffectiveScale(); local cx,cy=GetCursorPosition(); cx,cy=cx/scale,cy/scale
            local rawW,rawH=math.max(1,cx-s.left),math.max(1,s.top-cy)
            local dw=math.abs(rawW-s.startW)/math.max(1,s.startW); local dh=math.abs(rawH-s.startH)/math.max(1,s.startH)
            local width=(dw>=dh) and rawW or (rawH*s.aspect); width=math.max(s.minW,math.min(s.maxW,width))
            if ns.PreviewFrameSize then ns.PreviewFrameSize(s.unitType,width,width/s.aspect) end
        end)
    end)
    resize:SetScript("OnMouseUp",function(handle,button)
        if button~="LeftButton" then return end
        local s=handle.MIUF_ResizeState; handle:SetScript("OnUpdate",nil); handle.MIUF_ResizeState=nil
        if not s or InCombatLockdown() then return end
        ns.SaveSize(s.unitType,self:GetWidth(),self:GetHeight()); SaveMoverPosition(self,unit)
        if ns.ApplyFrameType then ns.ApplyFrameType(s.unitType) end
        if ns.RefreshConfig then ns.RefreshConfig() end
    end)
    mover.MIUF_ResizeHandle=resize; mover:Hide(); self.MIUF_Mover=mover
end

local function Style(self, unit)
    local unitType=self.MIUF_ForcedUnitType or UnitType(unit); local size=ns.GetSize(unitType)
    self.MIUF_UnitType=unitType; self:SetSize(size.width,size.height); self:RegisterForClicks("AnyUp")
    self:SetScript("OnEnter",function(frame) GameTooltip_SetDefaultAnchor(GameTooltip,frame); if frame.__unit then GameTooltip:SetUnit(frame.__unit) end end)
    self:SetScript("OnLeave",function() GameTooltip:Hide() end)
    self.Background=CreateBackground(self); self.Border=CreateBorder(self)
    local health=CreateFrame("StatusBar",nil,self); health:SetStatusBarTexture(FLAT); health.frequentUpdates=true
    local healthBG=health:CreateTexture(nil,"BACKGROUND"); healthBG:SetAllPoints(health); healthBG:SetColorTexture(0.08,0.08,0.08,1); health.bg=healthBG; health.bg.multiplier=0.25; self.Health=health
    local power=CreateFrame("StatusBar",nil,self); power:SetStatusBarTexture(FLAT); power.frequentUpdates=true
    local powerBG=power:CreateTexture(nil,"BACKGROUND"); powerBG:SetAllPoints(power); powerBG:SetColorTexture(0.05,0.05,0.05,1); self.Power=power
    local name=health:CreateFontString(nil,"OVERLAY"); name:SetFont(FONT,12,"OUTLINE"); name:SetJustifyH("LEFT"); name:SetWordWrap(false); self:Tag(name,"[name]"); self.NameText=name
    local healthText=health:CreateFontString(nil,"OVERLAY"); healthText:SetFont(FONT,11,"OUTLINE"); healthText:SetJustifyH("RIGHT"); self:Tag(healthText,"[perhp<$%]"); self.HealthText=healthText
    CreatePortrait(self); CreateRaidTargetIndicator(self)
    if unitType=="player" or unitType=="party" then CreateRoleIndicator(self) end
    if unitType=="player" or unitType=="target" or unitType=="focus" then CreateCastbar(self) end
    if ns.CreateProtectedAuras then ns.CreateProtectedAuras(self,unitType,size.width) end
    CreateMover(self,unit)
end

oUF:RegisterStyle("MythIncUnitFrames",Style)
oUF:RegisterStyle("MythIncUnitFramesPartyPlayer",function(self,unit) self.MIUF_ForcedUnitType="party"; Style(self,unit) end)
oUF:SetActiveStyle("MythIncUnitFrames")

local function Spawn(unit,name,key,style)
    if style then oUF:SetActiveStyle(style) end
    local frame=oUF:Spawn(unit,name)
    if style then oUF:SetActiveStyle("MythIncUnitFrames") end
    frames[key or unit]=frame
    if not key or key==unit then ApplyPosition(unit,frame) end
    return frame
end

local function ApplyColorModes(frame,appearance)
    local health=frame.Health
    health.colorClass=false; health.colorReaction=false; health.colorDisconnected=true; health.colorTapping=true; health.colorHealth=false
    if appearance.healthColor=="automatic" then
        health.colorClass=true; health.colorReaction=true; health.colorHealth=true; if health.ForceUpdate then health:ForceUpdate() end
    else
        local entry=ns.Media.healthColors[appearance.healthColor] or ns.Media.healthColors.green; local c=entry.rgb
        health:SetStatusBarColor(c[1],c[2],c[3],1)
    end
    local power=frame.Power; power.colorPower=false
    if appearance.powerColor=="automatic" then power.colorPower=true; if power.ForceUpdate then power:ForceUpdate() end
    else
        local entry=ns.Media.powerColors[appearance.powerColor] or ns.Media.powerColors.blue; local c=entry.rgb
        power:SetStatusBarColor(c[1],c[2],c[3],1)
    end
end

local function ApplyRoleIcon(frame,appearance)
    local role=frame.GroupRoleIndicator; if not role then return end
    if appearance.showRoleIcon then
        if frame.EnableElement then frame:EnableElement("GroupRoleIndicator") end
        if role.ForceUpdate then role:ForceUpdate() else role:Show() end
    else
        if frame.DisableElement then frame:DisableElement("GroupRoleIndicator") end
        role:Hide()
    end
end

local function ApplyFrame(frame,sizeOverride)
    local unitType=frame.MIUF_UnitType; local size=sizeOverride or ns.GetSize(unitType); local appearance=ns.GetAppearance(unitType)
    local width,height=size.width,size.height; frame:SetSize(width,height)
    local texture=ns.GetTexturePath(appearance.texture)
    frame.Health:SetStatusBarTexture(texture); frame.Power:SetStatusBarTexture(texture); if frame.Castbar then frame.Castbar:SetStatusBarTexture(texture) end
    frame.Background:SetColorTexture(0.03,0.03,0.03,appearance.backgroundOpacity/100); frame.Border:SetBackdropBorderColor(0.1,0.1,0.1,appearance.borderOpacity/100)
    local portraitWidth=appearance.showPortrait and math.max(18,math.floor(width*(appearance.portraitPercent/100))) or 0
    frame.Portrait:ClearAllPoints()
    if appearance.showPortrait then
        frame.Portrait:SetWidth(portraitWidth); frame.Portrait:SetPoint("TOP",frame,"TOP",0,-2); frame.Portrait:SetPoint("BOTTOM",frame,"BOTTOM",0,2)
        if appearance.portraitSide=="RIGHT" then frame.Portrait:SetPoint("RIGHT",frame,"RIGHT",-2,0) else frame.Portrait:SetPoint("LEFT",frame,"LEFT",2,0) end
        frame.Portrait:Show()
    else frame.Portrait:Hide() end
    local leftInset,rightInset=2,2
    if appearance.showPortrait then if appearance.portraitSide=="RIGHT" then rightInset=portraitWidth+4 else leftInset=portraitWidth+4 end end
    local powerHeight=math.max(8,math.floor(height*(ns.GetPowerPercent(unitType)/100)))
    frame.Health:ClearAllPoints(); frame.Health:SetPoint("TOPLEFT",frame,"TOPLEFT",leftInset,-2); frame.Health:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-rightInset,-2); frame.Health:SetPoint("BOTTOM",frame,"BOTTOM",0,powerHeight)
    frame.Power:ClearAllPoints(); frame.Power:SetPoint("TOPLEFT",frame.Health,"BOTTOMLEFT",0,-1); frame.Power:SetPoint("TOPRIGHT",frame.Health,"BOTTOMRIGHT",0,-1); frame.Power:SetPoint("BOTTOM",frame,"BOTTOM",0,2)
    local function PositionText(text,align,leftOffset,rightOffset,rightText)
        text:ClearAllPoints(); align=align=="TOP" and "TOP" or (align=="BOTTOM" and "BOTTOM" or "MIDDLE")
        if rightText then
            if align=="TOP" then text:SetPoint("TOPRIGHT",frame.Health,"TOPRIGHT",-rightOffset,-3)
            elseif align=="BOTTOM" then text:SetPoint("BOTTOMRIGHT",frame.Health,"BOTTOMRIGHT",-rightOffset,3)
            else text:SetPoint("RIGHT",frame.Health,"RIGHT",-rightOffset,0) end
        else
            if align=="TOP" then text:SetPoint("TOPLEFT",frame.Health,"TOPLEFT",leftOffset,-3); text:SetPoint("TOPRIGHT",frame.Health,"TOPRIGHT",-rightOffset,-3)
            elseif align=="BOTTOM" then text:SetPoint("BOTTOMLEFT",frame.Health,"BOTTOMLEFT",leftOffset,3); text:SetPoint("BOTTOMRIGHT",frame.Health,"BOTTOMRIGHT",-rightOffset,3)
            else text:SetPoint("LEFT",frame.Health,"LEFT",leftOffset,0); text:SetPoint("RIGHT",frame.Health,"RIGHT",-rightOffset,0) end
        end
    end
    PositionText(frame.NameText,appearance.nameVAlign,6,48,false); PositionText(frame.HealthText,appearance.healthVAlign,0,6,true); frame.HealthText:SetWidth(42)
    local font=ns.GetFontPath(appearance.fontFace); frame.NameText:SetFont(font,appearance.fontSize,"OUTLINE"); frame.HealthText:SetFont(font,math.max(9,appearance.fontSize-1),"OUTLINE")
    frame.NameText:SetShown(appearance.showName); frame.HealthText:SetShown(appearance.showHealthText)
    ApplyColorModes(frame,appearance); ApplyRoleIcon(frame,appearance)
    if ns.ResizeAuraContainers then ns.ResizeAuraContainers(frame,width) end
end

function ns.ApplyFrameType(unitType)
    for _,frame in pairs(frames) do if frame.MIUF_UnitType==unitType then ApplyFrame(frame) end end
    if not InCombatLockdown() and ns.ApplyGroupLayout then ns.ApplyGroupLayout(unitType) end
end
ns.ApplySize=ns.ApplyFrameType

function ns.PreviewFrameSize(unitType,width,height)
    if InCombatLockdown() then return end
    local preview={width=width,height=height}
    for _,frame in pairs(frames) do if frame.MIUF_UnitType==unitType then ApplyFrame(frame,preview) end end
    if ns.ApplyGroupLayout then ns.ApplyGroupLayout(unitType) end
end

function ns.IsUnitTypePreviewEnabled(unitType) return previewEnabled[unitType] ~= false end

local lockButton=CreateFrame("Button","MIUF_LockMoversButton",UIParent,"UIPanelButtonTemplate")
lockButton:SetSize(130,28); lockButton:SetPoint("TOP",UIParent,"TOP",0,-90); lockButton:SetFrameStrata("TOOLTIP"); lockButton:SetText("Lock Movers"); lockButton:Hide()
function ns.UpdateLockMoversButton() if ns.AreFrameMoversLocked() and ns.AreAuraMoversLocked() then lockButton:Hide() else lockButton:Show() end end
lockButton:SetScript("OnClick",function()
    ns.SetFrameMoversLockedState(true); ns.SetAuraMoversLockedState(true); ns.SetFrameMoversLocked(true); if ns.SetAuraMoversLocked then ns.SetAuraMoversLocked(true) end; ns.UpdateLockMoversButton()
end)

function ns.SetFrameMoversLocked(locked)
    for _,frame in pairs(frames) do
        local mover=frame.MIUF_Mover
        if mover then
            local groupOwner=(frame.MIUF_UnitType=="party" and frame==ns.partyFrameMoverOwner) or (frame.MIUF_UnitType=="boss" and frame.__unit=="boss1")
            local normal=frame.MIUF_UnitType~="party" and frame.MIUF_UnitType~="boss"
            if locked or (not normal and not groupOwner) or previewEnabled[frame.MIUF_UnitType]==false or not ns.IsFrameTypeEnabled(frame.MIUF_UnitType) then mover:Hide() else mover:Show() end
        end
    end
    ns.UpdateLockMoversButton()
end

function ns.PreviewUnitTypeMovers(unitType,enabled)
    previewEnabled[unitType]=enabled and true or false
    ns.SetFrameMoversLocked(ns.AreFrameMoversLocked())
    if ns.SetAuraMoversLocked then ns.SetAuraMoversLocked(ns.AreAuraMoversLocked()) end
end

function ns.SetMoversLocked(locked) ns.SetFrameMoversLocked(locked); if ns.SetAuraMoversLocked then ns.SetAuraMoversLocked(locked) end end

function ns.ResetLayout()
    for unit,frame in pairs(frames) do
        local positionKey=(frame.MIUF_UnitType=="party" and "party1") or (frame.MIUF_UnitType=="boss" and "boss1") or unit
        if frame.MIUF_UnitType~="party" and frame.MIUF_UnitType~="boss" then ApplyPosition(positionKey,frame) end
        if ns.ResetAuraPositionsForFrame then ns.ResetAuraPositionsForFrame(frame) end
    end
    if ns.ApplyPartyLayout then ns.ApplyPartyLayout() end; if ns.ApplyBossLayout then ns.ApplyBossLayout() end
    for unitType in pairs(ns.defaultSizes) do ns.ApplyFrameType(unitType) end
    ns.SetFrameMoversLocked(true); if ns.SetAuraMoversLocked then ns.SetAuraMoversLocked(true) end
end

local spawned=false
function ns.SpawnAllFrames()
    if spawned then return end; spawned=true
    if ns.IsFrameTypeEnabled("player") then Spawn("player","MIUF_Player") end
    if ns.IsFrameTypeEnabled("target") then Spawn("target","MIUF_Target") end
    if ns.IsFrameTypeEnabled("targettarget") then Spawn("targettarget","MIUF_TargetTarget") end
    if ns.IsFrameTypeEnabled("focus") then Spawn("focus","MIUF_Focus") end
    if ns.IsFrameTypeEnabled("pet") then Spawn("pet","MIUF_Pet") end
    if ns.IsFrameTypeEnabled("party") then
        for i=1,4 do local frame=Spawn("party"..i,"MIUF_Party"..i); RegisterStateDriver(frame,"visibility","[group:party] show; hide") end
        local group=ns.GetGroupLayout("party")
        if group and group.includePlayer then
            local frame=Spawn("player","MIUF_PartyPlayer","partyplayer","MythIncUnitFramesPartyPlayer"); UnregisterUnitWatch(frame); RegisterStateDriver(frame,"visibility","[group:party] show; hide")
        end
    end
    if ns.IsFrameTypeEnabled("boss") then for i=1,5 do Spawn("boss"..i,"MIUF_Boss"..i) end end
    if ns.ApplyPartyLayout then ns.ApplyPartyLayout() end; if ns.ApplyBossLayout then ns.ApplyBossLayout() end
    for unitType in pairs(ns.defaultSizes) do ns.ApplyFrameType(unitType) end
    ns.SetFrameMoversLocked(ns.AreFrameMoversLocked()); if ns.SetAuraMoversLocked then ns.SetAuraMoversLocked(ns.AreAuraMoversLocked()) end
end

local combatWatcher=CreateFrame("Frame"); combatWatcher:RegisterEvent("PLAYER_REGEN_DISABLED"); combatWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
combatWatcher:SetScript("OnEvent",function(_,event)
    if event=="PLAYER_REGEN_DISABLED" then ns.SetFrameMoversLocked(true); if ns.SetAuraMoversLocked then ns.SetAuraMoversLocked(true) end
    else ns.SetFrameMoversLocked(ns.AreFrameMoversLocked()); if ns.SetAuraMoversLocked then ns.SetAuraMoversLocked(ns.AreAuraMoversLocked()) end end
end)
