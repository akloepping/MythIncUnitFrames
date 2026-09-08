local ADDON_NAME, ns = ...

if not ns.UnitFramesLoaded then return end

-- WoW 12.1 aura data becomes secret in restricted combat contexts. MIUF never
-- enumerates UnitAura data here; AuraContainer owns filtering and assignment.
local FLAT = "Interface\\Buttons\\WHITE8x8"
local FONT = "Fonts\\FRIZQT__.TTF"
local AURA_LABELS = { buffs = "Buffs", debuffs = "Debuffs", defensives = "Defensives" }
local AURA_TYPES = {
    buffs = { groups = { { key = "buffs", filter = "HELPFUL|PLAYER" } } },
    debuffs = { groups = { { key = "debuffs", filter = "HARMFUL" } } },
    defensives = { groups = {
        { key = "defensivesBig", filter = "HELPFUL|BIG_DEFENSIVE" },
        { key = "defensivesExternal", filter = "HELPFUL|EXTERNAL_DEFENSIVE" },
    } },
}
local AURA_UNIT_TYPES = { player = true, target = true, focus = true, party = true, targettarget = true }
local DISPEL_HIGHLIGHT_TYPES = { player = true, party = true, focus = true }

local function BuildCandidateFilters(auraType)
    if auraType ~= "buffs" then return {} end
    local includeSpellIDs = {}
    local tracked = ns.GetTrackedBuffs and ns.GetTrackedBuffs() or {}
    local count = 0
    for spellID in pairs(tracked) do
        local id = tonumber(spellID)
        if id then includeSpellIDs[id] = true; count = count + 1 end
    end
    if count == 0 then includeSpellIDs[0] = true end
    return { includeSpellIDs = includeSpellIDs }
end

local function GetAnchor(layout)
    local anchor = layout.anchor == "BOTTOM" and "BOTTOM" or "TOP"
    local growth = layout.growth == "LEFT" and "LEFT" or "RIGHT"
    if anchor == "TOP" then
        if growth == "LEFT" then return "BOTTOMRIGHT", "TOPRIGHT", "TOPRIGHT", "LEFT", "DOWN" end
        return "BOTTOMLEFT", "TOPLEFT", "TOPLEFT", "RIGHT", "DOWN"
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
    icon:SetAllPoints(button); icon:SetTexCoord(0.08, 0.92, 0.08, 0.92); button:SetIcon(icon)
    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints(button); cooldown:SetDrawEdge(false); cooldown:SetDrawBling(false)
    if cooldown.SetHideCountdownNumbers then cooldown:SetHideCountdownNumbers(layout.showText == false) end
    button:SetDurationCooldown(cooldown)
    local count = button:CreateFontString(nil, "OVERLAY")
    count:SetFont(FONT, math.max(8, math.floor(size * 0.45)), "OUTLINE")
    count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    button:SetApplicationCount(count, {})
end

local function PositionAuraAnchor(frame, auraType)
    local data = frame.MIUF_Auras and frame.MIUF_Auras[auraType]
    if not data or not data.anchor then return end
    local layout = ns.GetAuraLayout(frame.MIUF_UnitType, auraType)
    if not layout then return end
    local point, relativePoint = GetAnchor(layout)
    data.anchor:ClearAllPoints()
    data.anchor:SetPoint(point, frame, relativePoint, layout.xOffset or 0, layout.yOffset or 0)
end

local function ApplyContainerLayout(frame, auraType)
    local data = frame.MIUF_Auras and frame.MIUF_Auras[auraType]
    if not data then return end
    local layout = ns.GetAuraLayout(frame.MIUF_UnitType, auraType)
    if not layout then return end
    local size = math.max(8, tonumber(layout.iconSize) or 22)
    local spacing = math.max(0, tonumber(layout.spacing) or 2)
    local width = math.max(size, frame:GetWidth())
    local _, _, flowAnchor, growthX, growthY = GetAnchor(layout)
    data.anchor:SetSize(width, size)
    PositionAuraAnchor(frame, auraType)
    SetFlowLayout(data.container, flowAnchor, growthX, growthY)
    for _, groupKey in ipairs(data.groupKeys or {}) do
        if data.container.SetAuraGroupLayout then
            data.container:SetAuraGroupLayout(groupKey, { elementWidth = size, elementHeight = size, elementSpacing = spacing, lineSpacing = spacing })
        end
        if data.container.SetAuraGroupEnabled then data.container:SetAuraGroupEnabled(groupKey, layout.enabled ~= false) end
    end
    if not data.container.SetAuraGroupEnabled then data.container:SetShown(layout.enabled ~= false) end
end

local function SaveDraggedAuraPosition(frame, auraType, anchor)
    local layout = ns.GetAuraLayout(frame.MIUF_UnitType, auraType)
    if not layout then return end
    local point, relativePoint = GetAnchor(layout)
    local x, y = 0, 0
    if point == "BOTTOMLEFT" and relativePoint == "TOPLEFT" then
        x = (anchor:GetLeft() or 0) - (frame:GetLeft() or 0); y = (anchor:GetBottom() or 0) - (frame:GetTop() or 0)
    elseif point == "BOTTOMRIGHT" and relativePoint == "TOPRIGHT" then
        x = (anchor:GetRight() or 0) - (frame:GetRight() or 0); y = (anchor:GetBottom() or 0) - (frame:GetTop() or 0)
    elseif point == "TOPLEFT" and relativePoint == "BOTTOMLEFT" then
        x = (anchor:GetLeft() or 0) - (frame:GetLeft() or 0); y = (anchor:GetTop() or 0) - (frame:GetBottom() or 0)
    elseif point == "TOPRIGHT" and relativePoint == "BOTTOMRIGHT" then
        x = (anchor:GetRight() or 0) - (frame:GetRight() or 0); y = (anchor:GetTop() or 0) - (frame:GetBottom() or 0)
    end
    ns.SaveAuraLayout(frame.MIUF_UnitType, auraType, {
        xOffset = math.floor(x + (x >= 0 and 0.5 or -0.5)),
        yOffset = math.floor(y + (y >= 0 and 0.5 or -0.5)),
    })
    ns.ApplyAuraPositions(frame.MIUF_UnitType, auraType)
    if ns.RefreshConfig then ns.RefreshConfig() end
end

local function CreateAuraMover(frame, auraType, anchor)
    anchor:SetMovable(true); anchor:SetClampedToScreen(true)
    local mover = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    mover:SetFrameStrata("DIALOG"); mover:SetAllPoints(anchor)
    mover:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
    mover:SetBackdropColor(0.35, 0.18, 0.65, 0.24); mover:SetBackdropBorderColor(0.75, 0.45, 1, 1)
    mover:EnableMouse(true); mover:RegisterForDrag("LeftButton")
    local label = mover:CreateFontString(nil, "OVERLAY")
    label:SetFont(FONT, 10, "OUTLINE"); label:SetPoint("CENTER")
    label:SetText((frame.MIUF_UnitType or frame.MIUF_Unit) .. " " .. AURA_LABELS[auraType])
    mover:SetScript("OnDragStart", function() if not InCombatLockdown() then anchor:StartMoving() end end)
    mover:SetScript("OnDragStop", function()
        anchor:StopMovingOrSizing()
        if not InCombatLockdown() then SaveDraggedAuraPosition(frame, auraType, anchor) end
    end)
    mover:Hide()
    frame.MIUF_AuraMovers = frame.MIUF_AuraMovers or {}; frame.MIUF_AuraMovers[auraType] = mover
end

local function CreateAuraContainer(frame, auraType)
    local typeInfo = AURA_TYPES[auraType]
    local layout = ns.GetAuraLayout(frame.MIUF_UnitType, auraType)
    if not typeInfo or not layout then return end
    local size = math.max(8, tonumber(layout.iconSize) or 22)
    local spacing = math.max(0, tonumber(layout.spacing) or 2)
    local maxCount = math.max(1, tonumber(layout.maxCount) or 6)
    local width = math.max(size, frame:GetWidth())
    local point, relativePoint, flowAnchor, growthX, growthY = GetAnchor(layout)
    local anchor = CreateFrame("Frame", nil, frame)
    anchor:SetSize(width, size); anchor:SetPoint(point, frame, relativePoint, layout.xOffset or 0, layout.yOffset or 0)
    local ok, container = pcall(CreateFrame, "AuraContainer", nil, anchor, "CustomAuraContainerTemplate")
    if not ok or not container then print("|cffff5555MIUF: unable to create aura container.|r"); anchor:Hide(); return end
    container:SetPoint(flowAnchor, anchor, flowAnchor, 0, 0)
    local groupKeys = {}
    for _, group in ipairs(typeInfo.groups or {}) do
        local groupOptions = {
            maxFrameCount = maxCount,
            candidateFilters = BuildCandidateFilters(auraType),
            layout = { elementWidth = size, elementHeight = size, elementSpacing = spacing, lineSpacing = spacing },
            initializeFrame = function(button) InitializeAuraButton(button, layout) end,
        }
        local added, addError = pcall(container.AddAuraGroup, container, group.key, group.filter, groupOptions)
        if not added then print("|cffff5555MIUF: " .. auraType .. " group failed: " .. tostring(addError) .. "|r"); anchor:Hide(); return end
        groupKeys[#groupKeys + 1] = group.key
    end
    SetFlowLayout(container, flowAnchor, growthX, growthY)
    local unitSet, unitError = pcall(container.SetUnit, container, frame.MIUF_Unit)
    if not unitSet then print("|cffff5555MIUF: aura unit assignment failed: " .. tostring(unitError) .. "|r"); anchor:Hide(); return end
    frame.MIUF_Auras = frame.MIUF_Auras or {}
    frame.MIUF_Auras[auraType] = { container = container, anchor = anchor, groupKeys = groupKeys }
    local previewAnchor = {}
    function previewAnchor:SetHeight(_) end
    function previewAnchor:ClearAllPoints() anchor:ClearAllPoints() end
    function previewAnchor:SetPoint(...) anchor:SetPoint(...) end
    container.MIUF_Anchor = previewAnchor
    if auraType == "buffs" then frame.PlayerBuffs = container
    elseif auraType == "debuffs" then frame.CombatDebuffs = container
    elseif auraType == "defensives" then frame.ExternalDefensives = container end
    CreateAuraMover(frame, auraType, anchor)
    ApplyContainerLayout(frame, auraType)
end

-- Reproduce MIUF's original dispel treatment: a thin white outline surrounding a
-- thicker inner edge colored by the aura's dispel type. AuraButton owns all color
-- assignment, so the addon never reads the protected dispel type itself.
local function CreateDispelHighlight(frame)
    if not frame or not DISPEL_HIGHLIGHT_TYPES[frame.MIUF_UnitType] or frame.MIUF_DispelHighlight then return end
    local ok, container = pcall(CreateFrame, "AuraContainer", nil, frame, "CustomAuraContainerTemplate")
    if not ok or not container then print("|cffff5555MIUF: unable to create dispel highlight.|r"); return end
    container:SetAllPoints(frame); container:SetFrameLevel(frame:GetFrameLevel() + 4)

    local slotOptions = {
        initializeFrame = function(button)
            button:SetSize(1, 1)
            button:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
            button:SetMouseMotionEnabled(false)

            local preserve = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle and Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset or 3
            local fixedOutlineMap = {
                Magic = CreateColor(1, 1, 1), Curse = CreateColor(1, 1, 1), Disease = CreateColor(1, 1, 1),
                Poison = CreateColor(1, 1, 1), Bleed = CreateColor(1, 1, 1), Enrage = CreateColor(1, 1, 1), None = CreateColor(1, 1, 1),
            }
            local function AddEdge(point1, relPoint1, x1, y1, point2, relPoint2, x2, y2, subLayer, colorMap)
                local edge = button:CreateTexture(nil, "OVERLAY", nil, subLayer)
                edge:SetColorTexture(1, 1, 1, 1)
                edge:SetPoint(point1, frame, relPoint1, x1, y1)
                edge:SetPoint(point2, frame, relPoint2, x2, y2)
                button:AddDispelTypeTexture(edge, {
                    style = preserve,
                    showWhenHarmful = true,
                    customDispelColorMap = colorMap,
                })
                return edge
            end

            local t, o = 5, 1
            local outline = {
                top = AddEdge("BOTTOMLEFT", "TOPLEFT", -o, 0, "TOPRIGHT", "TOPRIGHT", o, o, 6, fixedOutlineMap),
                bottom = AddEdge("TOPLEFT", "BOTTOMLEFT", -o, 0, "BOTTOMRIGHT", "BOTTOMRIGHT", o, -o, 6, fixedOutlineMap),
                left = AddEdge("TOPRIGHT", "TOPLEFT", 0, o, "BOTTOMLEFT", "BOTTOMLEFT", -o, -o, 6, fixedOutlineMap),
                right = AddEdge("TOPLEFT", "TOPRIGHT", 0, o, "BOTTOMRIGHT", "BOTTOMRIGHT", o, -o, 6, fixedOutlineMap),
            }
            button.DispelHighlight = {
                outline = outline,
                top = AddEdge("TOPLEFT", "TOPLEFT", 0, 0, "BOTTOMRIGHT", "TOPRIGHT", 0, -t, 7),
                bottom = AddEdge("BOTTOMLEFT", "BOTTOMLEFT", 0, 0, "TOPRIGHT", "BOTTOMRIGHT", 0, t, 7),
                left = AddEdge("TOPLEFT", "TOPLEFT", 0, -t, "BOTTOMRIGHT", "BOTTOMLEFT", t, t, 7),
                right = AddEdge("TOPLEFT", "TOPRIGHT", -t, -t, "BOTTOMRIGHT", "BOTTOMRIGHT", 0, t, 7),
            }
        end,
    }
    local added, slotOrError = pcall(container.AddAuraSlot, container, "miufDispel", "HARMFUL|RAID", slotOptions)
    if not added then print("|cffff5555MIUF: dispel highlight failed: " .. tostring(slotOrError) .. "|r"); container:Hide(); return end
    local unitSet, unitError = pcall(container.SetUnit, container, frame.MIUF_Unit)
    if not unitSet then print("|cffff5555MIUF: dispel highlight unit assignment failed: " .. tostring(unitError) .. "|r"); container:Hide(); return end
    frame.MIUF_DispelHighlight = container
end

local function AttachFrameAuras(frame)
    if not frame or not AURA_UNIT_TYPES[frame.MIUF_UnitType] or frame.MIUF_AurasAttached then return end
    frame.MIUF_AurasAttached = true
    CreateAuraContainer(frame, "buffs")
    CreateAuraContainer(frame, "debuffs")
    if frame.MIUF_UnitType == "player" or frame.MIUF_UnitType == "party" then CreateAuraContainer(frame, "defensives") end
    CreateDispelHighlight(frame)
end

local function AttachAuras()
    if not ns.frames then return end
    for _, frame in pairs(ns.frames) do AttachFrameAuras(frame) end
end

function ns.ApplyAuraPositions(unitType, auraType)
    if InCombatLockdown() or not ns.frames then return end
    for _, frame in pairs(ns.frames) do
        if frame.MIUF_UnitType == unitType then
            if auraType then ApplyContainerLayout(frame, auraType)
            else ApplyContainerLayout(frame, "buffs"); ApplyContainerLayout(frame, "debuffs"); ApplyContainerLayout(frame, "defensives") end
        end
    end
end

function ns.ResizeAuraContainers(frame, width)
    if not frame or not frame.MIUF_Auras then return end
    for auraType, data in pairs(frame.MIUF_Auras) do
        if data.anchor then data.anchor:SetWidth(width or frame:GetWidth()) end
        ApplyContainerLayout(frame, auraType)
    end
end

function ns.ResetAuraPositionsForFrame(frame)
    if not frame then return end
    PositionAuraAnchor(frame, "buffs"); PositionAuraAnchor(frame, "debuffs"); PositionAuraAnchor(frame, "defensives")
end

function ns.SetAuraMoversLocked(locked)
    for _, frame in pairs(ns.frames or {}) do
        if frame.MIUF_AuraMovers then
            for auraType, mover in pairs(frame.MIUF_AuraMovers) do
                local layout = ns.GetAuraLayout(frame.MIUF_UnitType, auraType)
                local previewOff = ns.IsUnitTypePreviewEnabled and not ns.IsUnitTypePreviewEnabled(frame.MIUF_UnitType)
                if locked or previewOff or not ns.IsFrameTypeEnabled(frame.MIUF_UnitType) or not layout or layout.enabled == false then mover:Hide() else mover:Show() end
            end
        end
    end
    if ns.UpdateLockMoversButton then ns.UpdateLockMoversButton() end
end

function ns.PreviewAuraMover(unitType, auraType, enabled)
    if not ns.frames then return end
    for _, frame in pairs(ns.frames) do
        if frame.MIUF_UnitType == unitType and frame.MIUF_AuraMovers and frame.MIUF_AuraMovers[auraType] then
            local mover = frame.MIUF_AuraMovers[auraType]
            local previewOn = not ns.IsUnitTypePreviewEnabled or ns.IsUnitTypePreviewEnabled(unitType)
            if enabled and previewOn and not ns.AreAuraMoversLocked() and ns.IsFrameTypeEnabled(unitType) then mover:Show() else mover:Hide() end
        end
    end
end

local deferred = CreateFrame("Frame")
deferred:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    AttachAuras()
end)

local originalSpawnAllFrames = ns.SpawnAllFrames
function ns.SpawnAllFrames(...)
    if originalSpawnAllFrames then originalSpawnAllFrames(...) end
    if InCombatLockdown() then deferred:RegisterEvent("PLAYER_REGEN_ENABLED") else AttachAuras() end
end

ns.RefreshAuras = AttachAuras
