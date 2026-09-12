local ADDON_NAME, ns = ...

local ROLE_ORDER = { TANK = 1, HEALER = 2, DAMAGER = 3, NONE = 4 }
local layoutPending = false
local previewLayouts = {}
local previewFrames = { party = {}, boss = {} }

local PREVIEW_BG = "Interface\\Buttons\\WHITE8x8"
local PREVIEW_FONT = "Fonts\\FRIZQT__.TTF"

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

local function CreatePreviewFrame(unitType, index)
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(40)
    frame:SetBackdrop({ bgFile = PREVIEW_BG, edgeFile = PREVIEW_BG, edgeSize = 1 })
    frame:SetBackdropColor(0.05, 0.35, 0.8, 0.14)
    frame:SetBackdropBorderColor(0.2, 0.65, 1, 0.75)
    frame:EnableMouse(false)

    local label = frame:CreateFontString(nil, "OVERLAY")
    label:SetFont(PREVIEW_FONT, 10, "OUTLINE")
    label:SetPoint("CENTER")
    label:SetText(unitType == "party" and ("Party " .. index) or ("Boss " .. index))
    label:SetTextColor(0.75, 0.9, 1, 0.9)
    frame.Label = label
    frame:Hide()
    return frame
end

local function EnsurePreviewFrames(unitType, count)
    local list = previewFrames[unitType]
    if not list then return nil end
    for index = 1, count do
        if not list[index] then list[index] = CreatePreviewFrame(unitType, index) end
    end
    return list
end

local function HideGroupPreview(unitType)
    local list = previewFrames[unitType]
    if not list then return end
    for _, frame in ipairs(list) do frame:Hide() end
end

local function PositionPreviewFrame(frame, previous, layout, spacing)
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
end

local function GetLiveGroupSize(unitType)
    if not ns.frames then return nil end
    local frame = unitType == "party" and ns.frames.party1 or ns.frames.boss1
    if not frame then return nil end
    local width, height = frame:GetWidth(), frame:GetHeight()
    if not width or not height or width <= 0 or height <= 0 then return nil end
    return width, height
end

function ns.PreviewGroupLayout(unitType, layoutOverride, sizeOverride)
    if InCombatLockdown() or (unitType ~= "party" and unitType ~= "boss") then return end
    if ns.AreFrameMoversLocked and ns.AreFrameMoversLocked() then
        HideGroupPreview(unitType)
        return
    end
    if ns.IsUnitTypePreviewEnabled and not ns.IsUnitTypePreviewEnabled(unitType) then
        HideGroupPreview(unitType)
        return
    end
    if ns.IsFrameTypeEnabled and not ns.IsFrameTypeEnabled(unitType) then
        HideGroupPreview(unitType)
        return
    end

    local savedLayout = ns.GetGroupLayout(unitType) or {}
    local layout = {}
    for key, value in pairs(savedLayout) do layout[key] = value end
    if layoutOverride then
        for key, value in pairs(layoutOverride) do layout[key] = value end
    end
    previewLayouts[unitType] = layout

    local savedSize = ns.GetSize(unitType) or { width = 200, height = 40 }
    local liveWidth, liveHeight = GetLiveGroupSize(unitType)
    local width = tonumber(sizeOverride and sizeOverride.width) or tonumber(liveWidth) or tonumber(savedSize.width) or 200
    local height = tonumber(sizeOverride and sizeOverride.height) or tonumber(liveHeight) or tonumber(savedSize.height) or 40
    local count = unitType == "party" and (layout.includePlayer and 5 or 4) or 5
    local list = EnsurePreviewFrames(unitType, count)
    if not list then return end

    local positionKey = unitType == "party" and "party1" or "boss1"
    local position = ns.GetPosition(positionKey)
    if not position then
        HideGroupPreview(unitType)
        return
    end

    local spacing = tonumber(layout.spacing) or 0
    local previous
    for index = 1, count do
        local frame = list[index]
        frame:SetSize(width, height)
        if index == 1 then
            frame:ClearAllPoints()
            local owner
            if unitType == "party" then owner = ns.partyFrameMoverOwner or (ns.frames and ns.frames.party1)
            else owner = ns.frames and ns.frames.boss1 end
            local mover = owner and owner.MIUF_Mover
            if mover then frame:SetPoint("TOPLEFT", mover, "TOPLEFT")
            else frame:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y) end
        else
            PositionPreviewFrame(frame, previous, layout, spacing)
        end
        frame:Show()
        previous = frame
    end
    for index = count + 1, #list do list[index]:Hide() end
end

function ns.ResetGroupPreview(unitType)
    previewLayouts[unitType] = nil
    ns.PreviewGroupLayout(unitType)
end

function ns.UpdateGroupPreviews(locked)
    if locked or InCombatLockdown() then
        HideGroupPreview("party")
        HideGroupPreview("boss")
        return
    end
    ns.PreviewGroupLayout("party", previewLayouts.party)
    ns.PreviewGroupLayout("boss", previewLayouts.boss)
end

function ns.ApplyPartyLayout()
    if InCombatLockdown() or not ns.frames then return end
    local layout = ns.GetGroupLayout("party")
    if not layout then return end

    local partyPlayer = ns.frames.partyplayer
    if not IsInGroup() or IsInRaid() then
        if partyPlayer then partyPlayer:Hide() end
        ns.partyFrameMoverOwner = AnchorGroupFrames(ns.frames.party1 and { ns.frames.party1 } or {}, layout, "party1")
        ns.partyAuraMoverOwner = nil
        if ns.SetFrameMoversLocked and ns.AreFrameMoversLocked then
            ns.SetFrameMoversLocked(ns.AreFrameMoversLocked())
        end
        return
    end

    local ordered = {}
    for i = 1, 4 do
        local unit = "party" .. i
        local frame = ns.frames[unit]
        if frame and UnitExists(unit) then ordered[#ordered + 1] = frame end
    end

    if partyPlayer then
        if layout.includePlayer then
            partyPlayer:Show()
            ordered[#ordered + 1] = partyPlayer
        else
            partyPlayer:Hide()
        end
    end

    table.sort(ordered, function(a, b)
        local roleA, roleB = GetRoleRank(a), GetRoleRank(b)
        if roleA ~= roleB then return roleA < roleB end
        return GetUnitRank(a) < GetUnitRank(b)
    end)

    local owner = AnchorGroupFrames(ordered, layout, "party1")
    ns.partyFrameMoverOwner = owner or AnchorGroupFrames(ns.frames.party1 and { ns.frames.party1 } or {}, layout, "party1")
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
    elseif unitType == "boss" then ns.ApplyBossLayout()
    else return end

    if ns.AreFrameMoversLocked and not ns.AreFrameMoversLocked() then
        ns.PreviewGroupLayout(unitType, previewLayouts[unitType])
    end
end

local originalSetFrameMoversLocked = ns.SetFrameMoversLocked
if originalSetFrameMoversLocked then
    ns.SetFrameMoversLocked = function(locked)
        originalSetFrameMoversLocked(locked)
        ns.UpdateGroupPreviews(locked)
    end
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("GROUP_ROSTER_UPDATE")
watcher:RegisterEvent("PLAYER_ROLES_ASSIGNED")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
watcher:SetScript("OnEvent", function(_, event)
    if InCombatLockdown() then
        layoutPending = true
        ns.UpdateGroupPreviews(true)
        return
    end
    if event == "PLAYER_REGEN_ENABLED" and not layoutPending then
        if ns.AreFrameMoversLocked then ns.UpdateGroupPreviews(ns.AreFrameMoversLocked()) end
        return
    end
    layoutPending = false
    ns.ApplyPartyLayout()
    if ns.AreFrameMoversLocked then ns.UpdateGroupPreviews(ns.AreFrameMoversLocked()) end
end)
-- Pure geometry: offsets are frame TOPLEFT coordinates relative to the raid anchor.
-- The secondary wrap axis grows down for horizontal groups, right for vertical groups.
function ns.CalculateRaidGeometry(layout, width, height)
    local memberHorizontal = layout.memberOrientation == "HORIZONTAL"
    local groupHorizontal = layout.subgroupOrientation == "HORIZONTAL"
    local memberSpacing = math.max(0, tonumber(layout.memberSpacing) or 0)
    local groupSpacing = math.max(0, tonumber(layout.subgroupSpacing) or 0)
    local perRow = math.max(1, math.min(8, math.floor(tonumber(layout.groupsPerRow) or 4)))
    local memberSign = (layout.memberDirection == "LEFT" or layout.memberDirection == "UP") and -1 or 1
    local groupSign = (layout.subgroupDirection == "LEFT" or layout.subgroupDirection == "UP") and -1 or 1
    local groupWidth = memberHorizontal and (5 * width + 4 * memberSpacing) or width
    local groupHeight = memberHorizontal and height or (5 * height + 4 * memberSpacing)
    local positions, bounds = {}, { left = math.huge, right = -math.huge, top = -math.huge, bottom = math.huge }
    for index = 1, 40 do
        local group = math.floor((index - 1) / 5)
        local member = (index - 1) % 5
        local major, minor = group % perRow, math.floor(group / perRow)
        local gx = (groupHorizontal and major * groupSign or minor) * (groupWidth + groupSpacing)
        local gy = -(groupHorizontal and minor or major * groupSign) * (groupHeight + groupSpacing)
        local mx = memberHorizontal and member * memberSign * (width + memberSpacing) or 0
        local my = memberHorizontal and 0 or -member * memberSign * (height + memberSpacing)
        local x, y = gx + mx, gy + my
        positions[index] = { x = x, y = y, group = group + 1, member = member + 1 }
        bounds.left = math.min(bounds.left, x); bounds.right = math.max(bounds.right, x + width)
        bounds.top = math.max(bounds.top, y); bounds.bottom = math.min(bounds.bottom, y - height)
    end
    bounds.width = bounds.right - bounds.left; bounds.height = bounds.top - bounds.bottom
    return positions, bounds
end

local raidAnchor, raidGhosts = nil, {}


function ns.HideRaidPreview()
    if raidAnchor then raidAnchor:Hide() end
end

function ns.ShowRaidPreview()
    if InCombatLockdown() then return end
    local size = ns.GetSize("party")
    local layout = ns.ConfigSessionGetGroup("raid")
    local position = ns.ConfigSessionGetPosition("raid")
    if not raidAnchor then
        raidAnchor = CreateFrame("Frame", nil, UIParent)
        raidAnchor:SetSize(size.width, size.height)
        raidAnchor:SetFrameStrata("DIALOG")
        raidAnchor:SetMovable(true)
        -- One non-secure mover owns the eventual group anchor, never a unit frame.
        local mover = CreateFrame("Button", nil, raidAnchor, "BackdropTemplate")
        mover:SetAllPoints(raidAnchor); mover:SetFrameLevel(45)
        mover:SetBackdrop({ bgFile = PREVIEW_BG, edgeFile = PREVIEW_BG, edgeSize = 1 })
        mover:SetBackdropColor(0.05, 0.35, 0.8, 0.2)
        mover:SetBackdropBorderColor(0.2, 0.65, 1, 1)
        mover:RegisterForDrag("LeftButton")
        mover:SetScript("OnDragStart", function() if not InCombatLockdown() then raidAnchor:StartMoving() end end)
        mover:SetScript("OnDragStop", function()
            raidAnchor:StopMovingOrSizing()
            if InCombatLockdown() then return end
            local point, _, relativePoint, x, y = raidAnchor:GetPoint(1)
            ns.ConfigSessionStagePosition("raid", { point = point, relativePoint = relativePoint, x = x, y = y })
            if ns.RefreshConfig then ns.RefreshConfig() end
        end)
        raidAnchor.MIUF_Mover = mover
        ns.raidFrameMoverOwner = raidAnchor
        for index = 1, 40 do
            local ghost = CreatePreviewFrame("raid", index)
            ghost:SetParent(raidAnchor)
            ghost.Label:SetText("Raid " .. index .. " (G" .. math.ceil(index / 5) .. ")")
            raidGhosts[index] = ghost
        end
    end
    raidAnchor:SetSize(size.width, size.height)
    raidAnchor:ClearAllPoints()
    raidAnchor:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
    local positions = ns.CalculateRaidGeometry(layout, size.width, size.height)
    for index, ghost in ipairs(raidGhosts) do
        ghost:SetSize(size.width, size.height); ghost:ClearAllPoints()
        ghost:SetPoint("TOPLEFT", raidAnchor, "TOPLEFT", positions[index].x, positions[index].y)
        ghost:Show()
    end
    raidAnchor:Show()
end

local setMoversLocked = ns.SetFrameMoversLocked
ns.SetFrameMoversLocked = function(locked)
    setMoversLocked(locked)
    if locked then ns.HideRaidPreview() end
end
local raidWatcher = CreateFrame("Frame")
raidWatcher:RegisterEvent("PLAYER_REGEN_DISABLED")
raidWatcher:SetScript("OnEvent", function() ns.HideRaidPreview() end)
