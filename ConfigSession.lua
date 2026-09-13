local ADDON_NAME, ns = ...

local pendingEnabled, pendingAuraLayouts = {}, {}
local pendingFrameSettings, pendingGroupLayouts = {}, {}
local pendingPositions = {}
local pendingTrackedBuffs
local hasPendingChanges = false
local sessionProfile

function ns.ConfigSessionClear()
    pendingEnabled={}; pendingAuraLayouts={}; pendingFrameSettings={}; pendingGroupLayouts={}
    pendingPositions={}; pendingTrackedBuffs=nil; hasPendingChanges=false; sessionProfile=nil
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
    for key,value in pairs(pendingPositions) do
        if MatchesSaved(value,ns.GetPosition(key)) then pendingPositions[key]=nil end
    end
    hasPendingChanges=next(pendingPositions)~=nil or next(pendingFrameSettings)~=nil or next(pendingGroupLayouts)~=nil
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
    pendingPositions.raid=CopyValues(ns.defaultPositions.raid)
    pendingTrackedBuffs={}
end

-- Sparse field masks contain names only, never references to settings values.
local function ChangedFields(values, saved, includeRemoved)
    if type(values)~="table" or type(saved)~="table" then
        if values~=saved then return true end
        return nil
    end
    local fields={}
    for key,value in pairs(values) do
        local changed=ChangedFields(value,saved[key],includeRemoved)
        if changed then fields[key]=changed end
    end
    if includeRemoved then
        for key in pairs(saved) do if values[key]==nil then fields[key]=true end end
    end
    if next(fields) then return fields end
end

local function BuildChangeSummary()
    local summary={profileName=ns.GetActiveProfileName(),frameTypes={},categories={},requiresReloadFallback=false,reloadFallbackReasons={}}
    local function Record(unitType,category,fields)
        if not fields then return end
        summary.categories[category]=true
        local frame=summary.frameTypes[unitType] or {}
        summary.frameTypes[unitType]=frame
        frame[category]=fields
    end
    local function Fallback(reason,unitType,auraType)
        summary.requiresReloadFallback=true
        summary.reloadFallbackReasons[#summary.reloadFallbackReasons+1]={reason=reason,frameType=unitType,auraType=auraType}
    end
    for unitType,values in pairs(pendingFrameSettings) do
        Record(unitType,"size",ChangedFields(values.size,ns.GetSize(unitType)))
        if values.powerPercent~=ns.GetPowerPercent(unitType) then Record(unitType,"powerBar",{powerPercent=true}) end
        Record(unitType,"appearance",ChangedFields(values.appearance,ns.GetAppearance(unitType)))
    end
    for unitType,values in pairs(pendingGroupLayouts) do
        local fields=ChangedFields(values,ns.GetGroupLayout(unitType))
        Record(unitType,"groupLayout",fields)
        if unitType=="raid" and fields and fields.legacy40 then Fallback("raidCapacityChanged",unitType) end
    end
    for unitType,enabled in pairs(pendingEnabled) do
        if enabled~=ns.IsFrameTypeEnabled(unitType) then
            Record(unitType,"enabled",{enabled=true})
            Fallback("frameEnabledStateChanged",unitType)
        end
    end
    for unitType,auraTypes in pairs(pendingAuraLayouts) do
        local auras={}
        for auraType,values in pairs(auraTypes) do
            local fields=ChangedFields(values,ns.GetAuraLayout(unitType,auraType))
            if fields then
                auras[auraType]=fields
                if fields.iconSize then Fallback("auraIconSizeChanged",unitType,auraType) end
                if fields.showText then Fallback("auraTextDisplayChanged",unitType,auraType) end
            end
        end
        if next(auras) then Record(unitType,"auras",auras) end
    end
    for key,value in pairs(pendingPositions) do
        local fields=ChangedFields(value,ns.GetPosition(key))
        if fields then
            local unitType=key:match("^party%d+$") and "party" or (key:match("^boss%d+$") and "boss" or key)
            local frame=summary.frameTypes[unitType]
            local positions=frame and frame.positions or {}
            positions[key]=fields
            Record(unitType,"positions",positions)
        end
    end
    if pendingTrackedBuffs then
        summary.trackedBuffs=ChangedFields(pendingTrackedBuffs,ns.GetTrackedBuffs(),true)
        if summary.trackedBuffs then
            for _,unitType in ipairs({"player","target","focus","targettarget","party"}) do Record(unitType,"trackedBuffs",true) end
        end
    end
    return summary
end

function ns.ConfigSessionCommit()
    EnsureProfile()
    if InCombatLockdown() or not ns.ConfigSessionIsDirty() then return false end
    local summary=BuildChangeSummary()
    for unitType,values in pairs(pendingFrameSettings) do
        ns.SaveSize(unitType,values.size.width,values.size.height)
        ns.SavePowerPercent(unitType,values.powerPercent)
        ns.SaveAppearance(unitType,values.appearance)
    end
    for key,value in pairs(pendingPositions) do ns.SavePosition(key,value.point,value.relativePoint,value.x,value.y) end
    for unitType,values in pairs(pendingGroupLayouts) do ns.SaveGroupLayout(unitType,values) end
    for unitType,enabled in pairs(pendingEnabled) do ns.SetFrameTypeEnabled(unitType,enabled) end
    for unitType,auraTypes in pairs(pendingAuraLayouts) do for auraType,values in pairs(auraTypes) do ns.SaveAuraLayout(unitType,auraType,values) end end
    if pendingTrackedBuffs then ns.SetTrackedBuffs(pendingTrackedBuffs) end
    ns.ConfigSessionClear()

    return true,summary
end

function ns.ConfigSessionGetPosition(key)
    EnsureProfile()
    return CopyValues(pendingPositions[key] or ns.GetPosition(key))
end

function ns.ConfigSessionStagePosition(key, value)
    EnsureProfile()
    pendingPositions[key] = CopyValues(value)
end
