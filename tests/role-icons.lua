-- Run from the repository root: lua5.1 tests/role-icons.lua
function CreateFrame() return {RegisterEvent=function() end,SetScript=function() end} end
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
local update=assert(findUpvalue(ns.PreviewFrameType,"UpdateRoleIndicator"))
local keys={"showTankRoleIcon","showHealerRoleIcon","showDamageRoleIcon"}
local roles={"TANK","HEALER","DAMAGER"}
local files={"Tank","Healer","Damage"}
local role,queriedUnit,secret
function UnitGroupRolesAssigned(unit) queriedUnit=unit; return role end
function canaccessvalue(value) return value~=secret end
local icon={}
function icon:SetTexture(path) self.texture=path end
function icon:Show() self.shown=true end
function icon:Hide() self.shown=false end
for _,kind in ipairs({"party","raid"}) do
    local frame={MIUF_UnitType=kind,MIUF_Unit=kind.."1",GroupRoleIndicator=icon}
    for mask=0,7 do
        local appearance={}
        for i,key in ipairs(keys) do appearance[key]=math.floor(mask/2^(i-1))%2==1 end
        for i,assigned in ipairs(roles) do
            role=assigned; update(frame,appearance)
            assert(queriedUnit==frame.MIUF_Unit)
            assert(icon.shown==appearance[keys[i]],kind.." role filter failed")
            if icon.shown then
                assert(icon.texture=="Interface\\AddOns\\MythIncUnitFrames\\Media\\Artwork\\MIUF_Role_"..files[i]..".tga")
            end
        end
        role="NONE"; update(frame,appearance); assert(not icon.shown)
        secret={}; role=secret; update(frame,appearance); assert(not icon.shown)
    end
end
for _,kind in ipairs({"player","target","focus","pet","targettarget","boss"}) do
    role="TANK"; update({MIUF_UnitType=kind,GroupRoleIndicator=icon},{showTankRoleIcon=true})
    assert(not icon.shown)
end
local function loadProfile(profile)
    MythIncUnitFramesDB={profiles={Default=profile},profileKeys={}}
    return ns.GetAppearance("party"),ns.GetAppearance("raid")
end
local function all(appearance,expected)
    for _,key in ipairs(keys) do assert(appearance[key]==expected,key) end
    assert(appearance.showRoleIcon==nil)
end
local party,raid=loadProfile({})
all(party,false); all(raid,true)
for _,enabled in ipairs({false,true}) do
    party,raid=loadProfile({appearance={party={showRoleIcon=enabled},raid={showRoleIcon=enabled},player={showRoleIcon=true}}})
    all(party,enabled); all(raid,enabled)
    assert(ns.GetAppearance("player").showRoleIcon==nil)
    local profile=MythIncUnitFramesDB.profiles.Default
    party,raid=loadProfile(profile); all(party,enabled); all(raid,enabled)
    party=loadProfile({partyRoleIconsEnabled=enabled,appearance={party={showRoleIcon=not enabled}}})
    all(party,enabled); assert(MythIncUnitFramesDB.profiles.Default.partyRoleIconsEnabled==nil)
end
party,raid=loadProfile({appearance={party={showRoleIcon=true,showTankRoleIcon=false},raid={showRoleIcon=false,showDamageRoleIcon=true}}})
assert(not party.showTankRoleIcon and party.showHealerRoleIcon and party.showDamageRoleIcon)
assert(not raid.showTankRoleIcon and not raid.showHealerRoleIcon and raid.showDamageRoleIcon)
-- The existing configuration session persists independent selections and resets defaults.
ns.ApplySavedConfiguration=function() return true end
ns.SetFrameMoversLocked=function() end
ns.SetAuraMoversLocked=function() end
assert(ns.ConfigSessionBegin())
local settings=ns.ConfigSessionGetFrame("party")
settings.appearance.showTankRoleIcon=true; settings.appearance.showHealerRoleIcon=false
ns.ConfigSessionStageFrame("party",settings)
assert(ns.ConfigSessionCommit())
assert(ns.GetAppearance("party").showTankRoleIcon and not ns.GetAppearance("party").showHealerRoleIcon)
ns.ConfigSessionStageFrameReset("party"); ns.ConfigSessionStageFrameReset("raid")
assert(ns.ConfigSessionCommit())
all(ns.GetAppearance("party"),false); all(ns.GetAppearance("raid"),true)
print("PASS: Party/Raid role combinations, textures, NONE/restricted roles, non-group scope, legacy conversion, defaults and session persistence/reset")
