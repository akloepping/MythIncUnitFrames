local ADDON_NAME, ns = ...

local pendingEnabled, pendingAuraLayouts = {}, {}
local pendingFrameSettings, pendingGroupLayouts = {}, {}
local pendingTrackedBuffs
local hasPendingChanges = false
local sessionProfile

function ns.ConfigSessionClear()
    pendingEnabled={}; pendingAuraLayouts={}; pendingFrameSettings={}; pendingGroupLayouts={}
    pendingTrackedBuffs=nil; hasPendingChanges=false; sessionProfile=nil
end

local function EnsureProfile()
    -- Core initializes the database. Table identity survives a profile rename,
    -- but changes on switching profiles or replacing the active profile.
    local name=ns.GetActiveProfileName()
    local profile=MythIncUnitFramesDB.profiles[name]
    if sessionProfile~=profile then
        ns.ConfigSessionClear()
        sessionProfile=profile
    end
end

local function CopyValues(source)
    local result={}
    for k,v in pairs(source or {}) do result[k]=type(v)=="table" and CopyValues(v) or v end
    return result
end

-- Compare only staged fields: aura edits are sparse, frame/group edits are snapshots.
local function MatchesSaved(values,saved)
    if type(values)~="table" then return values==saved end
    if type(saved)~="table" then return false end
    for key,value in pairs(values) do
        if not MatchesSaved(value,saved[key]) then return false end
    end
    return true
end

function ns.ConfigSessionIsDirty()
    EnsureProfile()
    for unitType,values in pairs(pendingFrameSettings) do
        if MatchesSaved(values.size,ns.GetSize(unitType))
            and values.powerPercent==ns.GetPowerPercent(unitType)
            and MatchesSaved(values.appearance,ns.GetAppearance(unitType)) then
            pendingFrameSettings[unitType]=nil
        end
    end
    for unitType,values in pairs(pendingGroupLayouts) do
        if MatchesSaved(values,ns.GetGroupLayout(unitType)) then pendingGroupLayouts[unitType]=nil end
    end
    for unitType,enabled in pairs(pendingEnabled) do
        if enabled==ns.IsFrameTypeEnabled(unitType) then pendingEnabled[unitType]=nil end
    end
    for unitType,auraTypes in pairs(pendingAuraLayouts) do
        for auraType,values in pairs(auraTypes) do
            if MatchesSaved(values,ns.GetAuraLayout(unitType,auraType)) then auraTypes[auraType]=nil end
        end
        if not next(auraTypes) then pendingAuraLayouts[unitType]=nil end
    end
    if pendingTrackedBuffs and MatchesSaved(pendingTrackedBuffs,ns.GetTrackedBuffs())
        and MatchesSaved(ns.GetTrackedBuffs(),pendingTrackedBuffs) then pendingTrackedBuffs=nil end
    hasPendingChanges=next(pendingFrameSettings)~=nil or next(pendingGroupLayouts)~=nil
        or next(pendingEnabled)~=nil or next(pendingAuraLayouts)~=nil or pendingTrackedBuffs~=nil
    return hasPendingChanges
end

function ns.ConfigSessionGetEnabled(unitType)
    EnsureProfile()
    if pendingEnabled[unitType]~=nil then return pendingEnabled[unitType] end
    return ns.IsFrameTypeEnabled(unitType)
end

function ns.ConfigSessionGetAura(unitType,auraType)
    EnsureProfile()
    local base=ns.GetAuraLayout(unitType,auraType); if not base then return nil end
    local result={}; for k,v in pairs(base) do result[k]=v end
    local pending=pendingAuraLayouts[unitType] and pendingAuraLayouts[unitType][auraType]
    if pending then for k,v in pairs(pending) do result[k]=v end end
    return result
end

-- Return independent GUI copies; callers stage changes explicitly.
function ns.ConfigSessionGetFrame(unitType)
    EnsureProfile()
    return CopyValues(pendingFrameSettings[unitType] or {
        size=ns.GetSize(unitType), powerPercent=ns.GetPowerPercent(unitType),
        appearance=ns.GetAppearance(unitType),
    })
end

function ns.ConfigSessionGetGroup(unitType)
    EnsureProfile()
    return CopyValues(pendingGroupLayouts[unitType] or ns.GetGroupLayout(unitType))
end

function ns.ConfigSessionGetTrackedBuffs()
    EnsureProfile()
    return CopyValues(pendingTrackedBuffs or ns.GetTrackedBuffs())
end

function ns.ConfigSessionStageFrame(unitType,values)
    EnsureProfile()
    pendingFrameSettings[unitType]=CopyValues(values)
end

function ns.ConfigSessionStageGroup(unitType,values)
    EnsureProfile()
    pendingGroupLayouts[unitType]=CopyValues(values)
end

function ns.ConfigSessionStageEnabled(unitType,enabled)
    EnsureProfile()
    pendingEnabled[unitType]=enabled
end

function ns.ConfigSessionStageAura(unitType,auraType,values)
    EnsureProfile()
    pendingAuraLayouts[unitType]=pendingAuraLayouts[unitType] or {}
    local current=pendingAuraLayouts[unitType][auraType] or {}
    for key,value in pairs(values) do current[key]=value end
    pendingAuraLayouts[unitType][auraType]=current
end

function ns.ConfigSessionStageTrackedBuffs(values)
    EnsureProfile()
    local result={}
    for id,info in pairs(values or {}) do
        result[tonumber(id) or id]=type(info)=="table" and {name=info.name,icon=info.icon} or {}
    end
    pendingTrackedBuffs=result
end

function ns.ConfigSessionStageFrameReset(unitType)
    EnsureProfile()
    pendingFrameSettings[unitType]={
        size=CopyValues(ns.defaultSizes[unitType]),
        powerPercent=ns.defaultBarLayout[unitType].powerPercent,
        appearance=CopyValues(ns.defaultAppearance[unitType]),
    }
    if ns.defaultGroupLayout[unitType] then
        pendingGroupLayouts[unitType]=CopyValues(ns.defaultGroupLayout[unitType])
    end
end

function ns.ConfigSessionStageAuraReset(unitType,auraType)
    EnsureProfile()
    pendingAuraLayouts[unitType]=pendingAuraLayouts[unitType] or {}
    pendingAuraLayouts[unitType][auraType]=CopyValues(ns.defaultAuraLayout[unitType][auraType])
end

function ns.ConfigSessionStageResetAll()
    EnsureProfile()
    for unitType in pairs(ns.defaultSizes) do
        ns.ConfigSessionStageFrameReset(unitType)
        pendingEnabled[unitType]=ns.defaultEnabled[unitType]
        pendingAuraLayouts[unitType]=CopyValues(ns.defaultAuraLayout[unitType])
    end
    pendingTrackedBuffs={}
end

function ns.ConfigSessionCommit()
    EnsureProfile()
    if InCombatLockdown() or not ns.ConfigSessionIsDirty() then return false end
    for unitType,values in pairs(pendingFrameSettings) do
        ns.SaveSize(unitType,values.size.width,values.size.height)
        ns.SavePowerPercent(unitType,values.powerPercent)
        ns.SaveAppearance(unitType,values.appearance)
    end
    for unitType,values in pairs(pendingGroupLayouts) do ns.SaveGroupLayout(unitType,values) end
    for unitType,enabled in pairs(pendingEnabled) do ns.SetFrameTypeEnabled(unitType,enabled) end
    for unitType,auraTypes in pairs(pendingAuraLayouts) do for auraType,values in pairs(auraTypes) do ns.SaveAuraLayout(unitType,auraType,values) end end
    if pendingTrackedBuffs then ns.SetTrackedBuffs(pendingTrackedBuffs) end
    ns.ConfigSessionClear()

    return true
end
