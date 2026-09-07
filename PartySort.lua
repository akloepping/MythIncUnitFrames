local ADDON_NAME, ns = ...

local frames = ns.frames
if not frames then return end

local ROLE_ORDER = {
    TANK = 1,
    HEALER = 2,
    DAMAGER = 3,
    NONE = 4,
}

local function GetRoleRank(frame)
    local unit = frame and frame.__unit
    if not unit then return ROLE_ORDER.NONE end
    return ROLE_ORDER[UnitGroupRolesAssigned(unit)] or ROLE_ORDER.NONE
end

local function GetUnitRank(frame)
    local unit = frame and frame.__unit or ""
    local partyIndex = unit:match("^party(%d+)$")
    if partyIndex then return tonumber(partyIndex) or 99 end
    if unit == "player" then return 5 end
    return 99
end

local function AnchorPartyFrames(ordered, layout)
    if #ordered == 0 then return nil end

    local first = ordered[1]
    local position = ns.GetPosition("party1")
    if position then
        first:ClearAllPoints()
        first:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
    end

    local previous = first
    local spacing = layout.spacing or 0
    for index = 2, #ordered do
        local frame = ordered[index]
        frame:ClearAllPoints()

        if layout.orientation == "HORIZONTAL" then
            if layout.direction == "LEFT" then
                frame:SetPoint("TOPRIGHT", previous, "TOPLEFT", -spacing, 0)
            else
                frame:SetPoint("TOPLEFT", previous, "TOPRIGHT", spacing, 0)
            end
        elseif layout.direction == "UP" then
            frame:SetPoint("BOTTOMLEFT", previous, "TOPLEFT", 0, spacing)
        else
            frame:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -spacing)
        end

        previous = frame
    end

    return first
end

local function ApplyRoleSortedPartyLayout()
    if InCombatLockdown() then return end

    local layout = ns.GetGroupLayout("party")
    if not layout then return end

    if not IsInGroup() or IsInRaid() then
        ns.partyAuraMoverOwner = nil
        return
    end

    local ordered = {}
    for i = 1, 4 do
        local unit = "party" .. i
        local frame = frames[unit]
        if frame and UnitExists(unit) then
            ordered[#ordered + 1] = frame
        end
    end

    if layout.includePlayer and frames.partyplayer then
        ordered[#ordered + 1] = frames.partyplayer
    end

    table.sort(ordered, function(a, b)
        local roleA, roleB = GetRoleRank(a), GetRoleRank(b)
        if roleA ~= roleB then return roleA < roleB end
        return GetUnitRank(a) < GetUnitRank(b)
    end)

    ns.partyAuraMoverOwner = AnchorPartyFrames(ordered, layout)
    if ns.partyAuraMoverOwner and ns.SetAuraMoversLocked and ns.AreAuraMoversLocked then
        ns.SetAuraMoversLocked(ns.AreAuraMoversLocked())
    end
end

-- Keep the role sort as the final party-layout pass whenever exposed layout
-- helpers are called. Layout.lua still owns frame creation and protected state;
-- this module only changes the visual anchoring order out of combat.
local originalApplyPartyLayout = ns.ApplyPartyLayout
if originalApplyPartyLayout then
    ns.ApplyPartyLayout = function(...)
        originalApplyPartyLayout(...)
        ApplyRoleSortedPartyLayout()
    end
end

local originalApplyFrameType = ns.ApplyFrameType
if originalApplyFrameType then
    ns.ApplyFrameType = function(unitType, ...)
        originalApplyFrameType(unitType, ...)
        if unitType == "party" then ApplyRoleSortedPartyLayout() end
    end
end

local originalPreviewFrameSize = ns.PreviewFrameSize
if originalPreviewFrameSize then
    ns.PreviewFrameSize = function(unitType, ...)
        originalPreviewFrameSize(unitType, ...)
        if unitType == "party" then ApplyRoleSortedPartyLayout() end
    end
end

local originalResetLayout = ns.ResetLayout
if originalResetLayout then
    ns.ResetLayout = function(...)
        originalResetLayout(...)
        ApplyRoleSortedPartyLayout()
    end
end

local layoutPending = false
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("GROUP_ROSTER_UPDATE")
watcher:RegisterEvent("PLAYER_ROLES_ASSIGNED")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
watcher:SetScript("OnEvent", function(_, event)
    if InCombatLockdown() then
        layoutPending = true
        return
    end

    if event == "PLAYER_REGEN_ENABLED" and not layoutPending then return end
    layoutPending = false
    ApplyRoleSortedPartyLayout()
end)
