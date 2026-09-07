local ADDON_NAME, ns = ...

local ROLE_ORDER = { TANK = 1, HEALER = 2, DAMAGER = 3, NONE = 4 }
local layoutPending = false

local function AnchorGroupFrames(ordered, layout, positionKey)
    if #ordered == 0 then return nil end

    local first = ordered[1]
    local position = ns.GetPosition(positionKey)
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

function ns.ApplyPartyLayout()
    if InCombatLockdown() or not ns.frames then return end
    local layout = ns.GetGroupLayout("party")
    if not layout then return end

    if not IsInGroup() or IsInRaid() then
        ns.partyFrameMoverOwner = nil
        ns.partyAuraMoverOwner = nil
        return
    end

    local ordered = {}
    for i = 1, 4 do
        local unit = "party" .. i
        local frame = ns.frames[unit]
        if frame and UnitExists(unit) then ordered[#ordered + 1] = frame end
    end
    if layout.includePlayer and ns.frames.partyplayer then
        ordered[#ordered + 1] = ns.frames.partyplayer
    end

    table.sort(ordered, function(a, b)
        local roleA, roleB = GetRoleRank(a), GetRoleRank(b)
        if roleA ~= roleB then return roleA < roleB end
        return GetUnitRank(a) < GetUnitRank(b)
    end)

    local owner = AnchorGroupFrames(ordered, layout, "party1")
    ns.partyFrameMoverOwner = owner
    ns.partyAuraMoverOwner = owner
    if ns.partyAuraMoverOwner and ns.SetAuraMoversLocked and ns.AreAuraMoversLocked then
        ns.SetAuraMoversLocked(ns.AreAuraMoversLocked())
    end
    if ns.SetFrameMoversLocked and ns.AreFrameMoversLocked then
        ns.SetFrameMoversLocked(ns.AreFrameMoversLocked())
    end
end

function ns.ApplyBossLayout()
    if InCombatLockdown() or not ns.frames then return end
    local layout = ns.GetGroupLayout("boss")
    if not layout then return end

    local ordered = {}
    for i = 1, 5 do
        local frame = ns.frames["boss" .. i]
        if frame then ordered[#ordered + 1] = frame end
    end
    AnchorGroupFrames(ordered, layout, "boss1")
end

function ns.ApplyGroupLayout(unitType)
    if unitType == "party" then ns.ApplyPartyLayout()
    elseif unitType == "boss" then ns.ApplyBossLayout() end
end

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
    ns.ApplyPartyLayout()
end)
