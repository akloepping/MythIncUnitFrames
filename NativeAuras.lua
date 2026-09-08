local ADDON_NAME, ns = ...

if _G.oUF or not ns.NativeUnitFrames then return end

-- WoW 12.1 makes aura data secret in combat.  Do not enumerate UnitAura data in
-- addon Lua.  CustomAuraContainerTemplate owns the aura data and creates the
-- protected AuraButtons for us; MIUF only defines presentation in initializeFrame.

local FONT = "Fonts\\FRIZQT__.TTF"
local AURA_TYPES = {
    buffs = { filter = "HELPFUL" },
    debuffs = { filter = "HARMFUL" },
}

local FIRST_MILESTONE_TYPES = {
    player = true,
    target = true,
}

local function GetAnchor(layout)
    local anchor = layout.anchor == "BOTTOM" and "BOTTOM" or "TOP"
    local growth = layout.growth == "LEFT" and "LEFT" or "RIGHT"

    if anchor == "TOP" then
        if growth == "LEFT" then return "BOTTOMRIGHT", "TOPRIGHT", "BOTTOMRIGHT", "LEFT", "DOWN" end
        return "BOTTOMLEFT", "TOPLEFT", "BOTTOMLEFT", "RIGHT", "DOWN"
    end

    if growth == "LEFT" then return "TOPRIGHT", "BOTTOMRIGHT", "TOPRIGHT", "LEFT", "UP" end
    return "TOPLEFT", "BOTTOMLEFT", "TOPLEFT", "RIGHT", "UP"
end

local function SetFlowLayout(container, anchorPoint, growthX, growthY)
    local setAnchor = container.SetFlowLayoutAnchorPoint or container.SetAuraLayoutAnchorPoint
    if setAnchor then setAnchor(container, anchorPoint) end

    local setGrowth = container.SetFlowLayoutGrowthDirection or container.SetAuraLayoutGrowthDirection
    local directions = AnchorUtil and AnchorUtil.FlowDirection
    if setGrowth and directions then
        local x = growthX == "LEFT" and directions.Left or directions.Right
        local y = growthY == "UP" and directions.Up or directions.Down
        setGrowth(container, x, y)
    end
end

local function InitializeAuraButton(button, layout)
    local size = math.max(8, tonumber(layout.iconSize) or 22)
    button:SetSize(size, size)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button:SetIcon(icon)

    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints(button)
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawBling(false)
    if cooldown.SetHideCountdownNumbers then
        cooldown:SetHideCountdownNumbers(layout.showText == false)
    end
    button:SetDurationCooldown(cooldown)

    local count = button:CreateFontString(nil, "OVERLAY")
    count:SetFont(FONT, math.max(8, math.floor(size * 0.45)), "OUTLINE")
    count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    button:SetApplicationCount(count, {})

    button.MIUF_Icon = icon
    button.MIUF_Cooldown = cooldown
    button.MIUF_Count = count
end

local function CreateAuraContainer(frame, auraType)
    local typeInfo = AURA_TYPES[auraType]
    local layout = ns.GetAuraLayout(frame.MIUF_UnitType, auraType)
    if not typeInfo or not layout or layout.enabled == false then return end

    local size = math.max(8, tonumber(layout.iconSize) or 22)
    local spacing = math.max(0, tonumber(layout.spacing) or 2)
    local maxCount = math.max(1, tonumber(layout.maxCount) or 6)
    local width = math.max(size, frame:GetWidth())
    local point, relativePoint, flowAnchor, growthX, growthY = GetAnchor(layout)

    local ok, container = pcall(CreateFrame, "AuraContainer", nil, frame, "CustomAuraContainerTemplate")
    if not ok or not container then
        print("|cffff5555MIUF: unable to create native aura container.|r")
        return
    end

    container:SetSize(width, size)
    container:ClearAllPoints()
    container:SetPoint(point, frame, relativePoint, layout.xOffset or 0, layout.yOffset or 0)
    container:Show()

    local groupOptions = {
        maxFrameCount = maxCount,
        candidateFilters = {},
        layout = {
            elementWidth = size,
            elementHeight = size,
            elementSpacing = spacing,
            lineSpacing = spacing,
        },
        initializeFrame = function(button)
            InitializeAuraButton(button, layout)
        end,
    }

    local added, addError = pcall(container.AddAuraGroup, container, auraType, typeInfo.filter, groupOptions)
    if not added then
        print("|cffff5555MIUF: native " .. auraType .. " group failed: " .. tostring(addError) .. "|r")
        container:Hide()
        return
    end

    SetFlowLayout(container, flowAnchor, growthX, growthY)

    local unitSet, unitError = pcall(container.SetUnit, container, frame.MIUF_Unit)
    if not unitSet then
        print("|cffff5555MIUF: native aura unit assignment failed: " .. tostring(unitError) .. "|r")
        container:Hide()
        return
    end

    frame.MIUF_NativeAuras = frame.MIUF_NativeAuras or {}
    frame.MIUF_NativeAuras[auraType] = container
end

local function AttachFrameAuras(frame)
    if not frame or not FIRST_MILESTONE_TYPES[frame.MIUF_UnitType] then return end
    if frame.MIUF_NativeAurasAttached then return end

    frame.MIUF_NativeAurasAttached = true
    CreateAuraContainer(frame, "buffs")
    CreateAuraContainer(frame, "debuffs")
end

local function AttachNativeAuras()
    if not ns.frames then return end
    for _, frame in pairs(ns.frames) do
        AttachFrameAuras(frame)
    end
end

local deferred = CreateFrame("Frame")
deferred:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    AttachNativeAuras()
end)

local originalSpawnAllFrames = ns.SpawnAllFrames
function ns.SpawnAllFrames(...)
    if originalSpawnAllFrames then originalSpawnAllFrames(...) end

    if InCombatLockdown() then
        deferred:RegisterEvent("PLAYER_REGEN_ENABLED")
    else
        AttachNativeAuras()
    end
end

ns.RefreshNativeAuras = AttachNativeAuras
