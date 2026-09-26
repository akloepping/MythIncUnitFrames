-- Run from the repository root: lua5.1 tests/healer-power-bars.lua
function CreateFrame()
    return {RegisterEvent=function() end,SetScript=function() end}
end
function InCombatLockdown() return false end
SlashCmdList={}
local ns={}
assert(loadfile("Core.lua"))("MythIncUnitFrames",ns)
assert(loadfile("ConfigSession.lua"))("MythIncUnitFrames",ns)
assert(loadfile("UnitFrames.lua"))("MythIncUnitFrames",ns)
local function findUpvalue(fn,wanted,seen)
    seen=seen or {}; if seen[fn] then return end; seen[fn]=true
    for i=1,100 do
        local name,value=debug.getupvalue(fn,i); if not name then break end
        if name==wanted then return value end
        if type(value)=="function" then
            local found=findUpvalue(value,wanted,seen); if found then return found end
        end
    end
end
local update=assert(findUpvalue(ns.PreviewFrameType,"UpdatePowerVisibility"))
local role,queriedUnit
function UnitGroupRolesAssigned(unit) queriedUnit=unit; return role end
local function visual()
    return {
        points={},
        ClearAllPoints=function(self) self.points={}; self.allPoints=nil end,
        SetAllPoints=function(self,owner) self.allPoints=owner end,
        SetPoint=function(self,point,relative,relativePoint,x,y)
            self.points[point]={relative,relativePoint,x,y}
        end,
    }
end
local function addVisuals(frame)
    frame.Background=visual(); frame.Border=visual(); frame.Health=visual()
    frame.Background:SetAllPoints(frame)
    frame.Border:SetPoint("TOPLEFT",frame,"TOPLEFT",-1,1)
    frame.Border:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",1,-1)
    frame.Health:SetPoint("TOPLEFT",frame,"TOPLEFT",2,-2)
    frame.Health:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-2,-2)
    frame.MIUF_PowerHeight=10
    frame.NameText=visual(); frame.HealthText=visual()
    frame.MIUF_PowerTextLayout={nameX=7,nameRightX=-41,nameY=3,healthX=-8,healthY=-2}
    return frame
end
local function assertVisuals(frame,shown)
    assert(frame.Background.allPoints==frame)
    local bottom=frame.Border.points.BOTTOMRIGHT
    assert(bottom[1]==frame and bottom[2]=="BOTTOMRIGHT" and bottom[3]==1 and bottom[4]==-1)
    assert(not frame.Border.points.BOTTOM)
    local healthBottom=frame.Health.points.BOTTOM
    assert(healthBottom[1]==frame and healthBottom[2]=="BOTTOM" and healthBottom[3]==0)
    assert(healthBottom[4]==(shown and frame.MIUF_PowerHeight or 2))
    assert(frame.Health.points.TOPLEFT[4]==-2 and frame.Health.points.TOPRIGHT[4]==-2)
    -- Absolute text heights must stay fixed as the health bar's center moves.
    local height=60
    local center=(-2+(-height+healthBottom[4]))/2
    local normalCenter=(-2+(-height+frame.MIUF_PowerHeight))/2
    local layout=frame.MIUF_PowerTextLayout
    for _,entry in ipairs({{frame.NameText,"LEFT",layout.nameX,layout.nameY},
        {frame.NameText,"RIGHT",layout.nameRightX,layout.nameY},
        {frame.HealthText,"RIGHT",layout.healthX,layout.healthY}}) do
        local point=entry[1].points[entry[2]]
        assert(point[1]==frame.Health and point[2]==entry[2] and point[3]==entry[3])
        assert(center+point[4]==normalCenter+entry[4],"text shifted when power visibility changed")
    end
end
for _,kind in ipairs({"party","raid"}) do
    assert(ns.GetAppearance(kind).healerPowerBarsOnly==false)
    local gate={SetShown=function(self,value) self.shown=value end}
    local frame=addVisuals({MIUF_UnitType=kind,MIUF_Unit=kind.."1",MIUF_PowerDisplayGate=gate,
        Power={shown=false},MIUF_HealerPowerBarsOnly=false})
    for _,assigned in ipairs({"HEALER","TANK","DAMAGER","NONE"}) do
        role=assigned; update(frame); assert(gate.shown); assertVisuals(frame,true)
    end
    frame.MIUF_HealerPowerBarsOnly=true
    for _,assigned in ipairs({"HEALER","TANK","HEALER","DAMAGER","NONE","HEALER"}) do
        role=assigned; update(frame)
        assert(gate.shown==(role=="HEALER") and queriedUnit==frame.MIUF_Unit)
        assertVisuals(frame,gate.shown)
        assert(frame.Power.shown==false,"role filter must not enable a disabled power bar")
    end
    frame.MIUF_Unit="player"; update(frame); assert(queriedUnit=="player")
    frame.MIUF_Unit=nil; update(frame); assert(not gate.shown)
    frame.MIUF_HealerPowerBarsOnly=false; update(frame); assert(gate.shown); assertVisuals(frame,true)
    -- Restoring power uses the current preview geometry, not saved dimensions.
    frame.MIUF_PowerHeight=18; frame.MIUF_HealerPowerBarsOnly=true; frame.MIUF_Unit=kind.."1"
    role="DAMAGER"; update(frame); assertVisuals(frame,false)
    role="HEALER"; update(frame); assertVisuals(frame,true)
end
for _,kind in ipairs({"player","target","focus","pet","targettarget","boss"}) do
    assert(ns.GetAppearance(kind).healerPowerBarsOnly==nil)
    update({MIUF_UnitType=kind,MIUF_HealerPowerBarsOnly=true,
        MIUF_PowerDisplayGate={SetShown=function() error("non-group frame changed") end}})
end

-- Run the production event handler with unrelated rendering stubbed out.
local file=assert(io.open("UnitFrames.lua","r"))
local source=file:read("*a"); file:close()
local handler=assert(source:match('frame:SetScript%("OnEvent",(function%(self,event%).-)\n    end%)')).."\nend"
local updatePower=assert(findUpvalue(ns.SpawnAllFrames,"UpdatePower"))
function UnitPowerPercent() return 50 end
local factory=assert(loadstring([[
    local ns,UpdatePowerVisibility,UpdatePower=...
    local VEHICLE_EVENTS,VEHICLE_DISPLAY_UNITS={},{}
    local function noop() end
    local UpdateLeaderIndicator,UpdateRoleIndicator,ApplyColors,UpdateConnectionState=noop,noop,noop,noop
    local function UpdateFrame(frame) UpdatePower(frame) end
    return ]]..handler))
local onEvent=factory(ns,update,updatePower)
for _,kind in ipairs({"party","raid"}) do
    local gate={SetShown=function(self,value) self.shown=value end}
    local frame=addVisuals({MIUF_UnitType=kind,MIUF_Unit=kind.."1",MIUF_HealerPowerBarsOnly=true,
        MIUF_DisplayUnit=kind.."1",MIUF_PowerDisplayGate=gate,Power={SetValue=function() end}})
    for _,event in ipairs({"PLAYER_ROLES_ASSIGNED","GROUP_ROSTER_UPDATE"}) do
        role="TANK"; onEvent(frame,event); assert(not gate.shown); assertVisuals(frame,false)
        role="HEALER"; onEvent(frame,event); assert(gate.shown); assertVisuals(frame,true)
    end
end

-- Exercise real persistence/session code, replacing only live UI restoration.
ns.ApplySavedConfiguration=function() return true end
ns.SetFrameMoversLocked=function() end
ns.SetAuraMoversLocked=function() end
local function stage(kind,value)
    local settings=ns.ConfigSessionGetFrame(kind)
    settings.appearance.healerPowerBarsOnly=value
    ns.ConfigSessionStageFrame(kind,settings)
end
assert(ns.ConfigSessionBegin())
stage("party",true)
assert(ns.ConfigSessionIsDirty() and not ns.GetAppearance("party").healerPowerBarsOnly)
assert(ns.ConfigSessionCommit())
assert(ns.GetAppearance("party").healerPowerBarsOnly and not ns.GetAppearance("raid").healerPowerBarsOnly)
stage("party",false); assert(ns.ConfigSessionRevert())
assert(ns.ConfigSessionGetFrame("party").appearance.healerPowerBarsOnly)
stage("raid",true); assert(ns.ConfigSessionClose())
assert(not ns.GetAppearance("raid").healerPowerBarsOnly)
assert(ns.ConfigSessionBegin())
ns.ConfigSessionStageFrameReset("party")
assert(not ns.ConfigSessionGetFrame("party").appearance.healerPowerBarsOnly)
assert(ns.ConfigSessionCommit())
assert(not ns.GetAppearance("party").healerPowerBarsOnly)
stage("raid",true); assert(ns.ConfigSessionCommit())
assert(ns.CopyProfile("Default","Copied"))
assert(ns.CreateProfile("Fresh"))
stage("party",true)
assert(ns.SetActiveProfile("Fresh"))
assert(not ns.ConfigSessionIsDirty())
assert(not ns.ConfigSessionGetFrame("raid").appearance.healerPowerBarsOnly)
assert(ns.SetActiveProfile("Copied"))
assert(ns.ConfigSessionGetFrame("raid").appearance.healerPowerBarsOnly)
print("PASS: healer power roles, scope, visibility, defaults, Apply/Revert/Close/reset/profiles")
