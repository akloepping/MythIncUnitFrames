local ADDON_NAME, ns = ...

-- Native frame engine bootstrap. During the migration this file is only active
-- when oUF is not installed, which lets us replace one subsystem at a time
-- without changing the known-good oUF path.
if _G.oUF then return end

ns.NativeUnitFrames = true

local FLAT = "Interface\\Buttons\\WHITE8x8"
local FONT = "Fonts\\FRIZQT__.TTF"
local RAID_TARGET_TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local frames, previewEnabled = {}, {}
ns.frames = frames

local function CreateBackground(parent)
    local bg = parent:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(parent)
    bg:SetColorTexture(0.03, 0.03, 0.03, 0.92)
    return bg
end

local function CreateBorder(parent)
    local border = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetBackdrop({ edgeFile = FLAT, edgeSize = 1 })
    border:SetBackdropBorderColor(0.1, 0.1, 0.1, 1)
    border:SetFrameLevel(parent:GetFrameLevel() + 5)
    return border
end

local function ApplyPosition(positionKey, frame)
    local p = ns.GetPosition(positionKey)
    if not p then return end
    frame:ClearAllPoints()
    frame:SetPoint(p.point, UIParent, p.relativePoint, p.x, p.y)
end

local function SaveMoverPosition(frame, positionKey)
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    ns.SavePosition(positionKey, point or "CENTER", relativePoint or point or "CENTER", x or 0, y or 0)
end

local function BuildFrameState(unitType, overrides)
    local savedSize = ns.GetSize(unitType) or {}
    local savedAppearance = ns.GetAppearance(unitType) or {}
    local state = {
        size = { width = savedSize.width, height = savedSize.height },
        powerPercent = ns.GetPowerPercent(unitType),
        appearance = {},
    }
    for key, value in pairs(savedAppearance) do state.appearance[key] = value end

    if overrides then
        if overrides.size then
            if overrides.size.width ~= nil then state.size.width = overrides.size.width end
            if overrides.size.height ~= nil then state.size.height = overrides.size.height end
        end
        if overrides.powerPercent ~= nil then state.powerPercent = overrides.powerPercent end
        if overrides.appearance then
            for key, value in pairs(overrides.appearance) do state.appearance[key] = value end
        end
    end
    return state
end

local function UpdateHealth(frame)
    local unit = frame.MIUF_Unit
    if not unit then return end
    local value = UnitHealthPercent(unit, true, CurveConstants and CurveConstants.ScaleTo100)
    if value ~= nil then frame.Health:SetValue(value) end

    if frame.HealthText then
        if value ~= nil and (not canaccessvalue or canaccessvalue(value)) then
            frame.HealthText:SetFormattedText("%.0f%%", value)
        else
            frame.HealthText:SetText("")
        end
    end
end

local function UpdatePower(frame)
    local unit = frame.MIUF_Unit
    if not unit then return end
    local value = UnitPowerPercent(unit, nil, false, CurveConstants and CurveConstants.ScaleTo100)
    if value ~= nil then frame.Power:SetValue(value) end
end

local function UpdateName(frame)
    local unit = frame.MIUF_Unit
    if not unit then return end
    local name = UnitName(unit)
    if name ~= nil then frame.NameText:SetText(name) else frame.NameText:SetText("") end
end

local function UpdatePortrait(frame)
    if frame.Portrait and frame.MIUF_Unit then SetPortraitTexture(frame.Portrait, frame.MIUF_Unit) end
end

local function GetAutomaticHealthColor(unit)
    if not unit or not UnitExists(unit) then return 0.45, 0.45, 0.45 end

    if UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if color then return color.r, color.g, color.b end
    end

    local reaction = UnitReaction(unit, "player")
    if reaction then
        if reaction <= 3 then return 0.80, 0.18, 0.18 end
        if reaction == 4 then return 0.85, 0.75, 0.20 end
        return 0.20, 0.75, 0.25
    end

    return 0.20, 0.75, 0.25
end

local POWER_COLORS = {
    MANA = { 0.10, 0.35, 0.95 },
    RAGE = { 0.90, 0.12, 0.12 },
    FOCUS = { 0.95, 0.45, 0.10 },
    ENERGY = { 0.95, 0.85, 0.10 },
    RUNIC_POWER = { 0.10, 0.80, 0.95 },
    LUNAR_POWER = { 0.25, 0.50, 1.00 },
    INSANITY = { 0.55, 0.20, 0.80 },
    FURY = { 0.75, 0.20, 1.00 },
    MAELSTROM = { 0.10, 0.55, 1.00 },
}

local function GetAutomaticPowerColor(unit)
    if not unit or not UnitExists(unit) then return 0.20, 0.40, 0.90 end
    local _, powerToken = UnitPowerType(unit)
    local color = powerToken and POWER_COLORS[powerToken]
    if color then return color[1], color[2], color[3] end
    return 0.20, 0.40, 0.90
end

local function ApplyColors(frame, appearance)
    if appearance.healthColor == "automatic" then
        local r, g, b = GetAutomaticHealthColor(frame.MIUF_Unit)
        frame.Health:SetStatusBarColor(r, g, b, 1)
    else
        local healthEntry = ns.Media.healthColors[appearance.healthColor] or ns.Media.healthColors.green
        local hc = healthEntry.rgb
        frame.Health:SetStatusBarColor(hc[1], hc[2], hc[3], 1)
    end

    if appearance.powerColor == "automatic" then
        local r, g, b = GetAutomaticPowerColor(frame.MIUF_Unit)
        frame.Power:SetStatusBarColor(r, g, b, 1)
    else
        local powerEntry = ns.Media.powerColors[appearance.powerColor] or ns.Media.powerColors.blue
        local pc = powerEntry.rgb
        frame.Power:SetStatusBarColor(pc[1], pc[2], pc[3], 1)
    end
end

local function ApplyIndicatorLayout(frame, appearance)
    if frame.RaidTargetIndicator then
        local size = math.max(8, tonumber(appearance.raidMarkerSize) or 20)
        frame.RaidTargetIndicator:SetSize(size, size)
        frame.RaidTargetIndicator:ClearAllPoints()
        frame.RaidTargetIndicator:SetPoint("CENTER", frame, "TOP", appearance.raidMarkerXOffset or 0, appearance.raidMarkerYOffset or 2)
    end

    if frame.GroupRoleIndicator then
        frame.GroupRoleIndicator:ClearAllPoints()
        frame.GroupRoleIndicator:SetPoint("TOPLEFT", frame.Health, "TOPLEFT", appearance.roleIconXOffset or 3, appearance.roleIconYOffset or -3)
    end
end

local function UpdateRaidTarget(frame, appearance)
    local icon = frame.RaidTargetIndicator
    if not icon then return end
    appearance = appearance or ns.GetAppearance(frame.MIUF_UnitType) or {}
    if appearance.showRaidMarker == false then
        icon:Hide()
        return
    end

    if not frame.MIUF_Unit or not UnitExists(frame.MIUF_Unit) then
        icon:Hide()
        return
    end

    local index = GetRaidTargetIndex(frame.MIUF_Unit)
    if index then
        icon:SetTexture(RAID_TARGET_TEXTURE)
        SetRaidTargetIconTexture(icon, index)
        icon:Show()
    else
        icon:Hide()
    end
end

local function UpdateRoleIndicator(frame, appearance)
    local icon = frame.GroupRoleIndicator
    if not icon then return end

    appearance = appearance or ns.GetAppearance(frame.MIUF_UnitType) or {}
    if not appearance.showRoleIcon then
        icon:Hide()
        return
    end

    local role = UnitGroupRolesAssigned(frame.MIUF_Unit)
    local atlas
    if role == "TANK" then atlas = "groupfinder-icon-role-large-tank"
    elseif role == "HEALER" then atlas = "groupfinder-icon-role-large-heal"
    elseif role == "DAMAGER" then atlas = "groupfinder-icon-role-large-dps"
    end

    if atlas then
        icon:SetAtlas(atlas, true)
        icon:Show()
    else
        icon:Hide()
    end
end

local function UpdateFrame(frame)
    UpdateHealth(frame)
    UpdatePower(frame)
    UpdateName(frame)
    UpdatePortrait(frame)
    local appearance = ns.GetAppearance(frame.MIUF_UnitType) or {}
    ApplyColors(frame, appearance)
    ApplyIndicatorLayout(frame, appearance)
    UpdateRaidTarget(frame, appearance)
    UpdateRoleIndicator(frame, appearance)
end

local function ApplyFrameState(frame, state)
    local appearance = state.appearance
    local width, height = state.size.width, state.size.height
    frame:SetSize(width, height)

    local texture = ns.GetTexturePath(appearance.texture)
    frame.Health:SetStatusBarTexture(texture)
    frame.Power:SetStatusBarTexture(texture)
    frame.Background:SetColorTexture(0.03, 0.03, 0.03, appearance.backgroundOpacity / 100)
    frame.Border:SetBackdropBorderColor(0.1, 0.1, 0.1, appearance.borderOpacity / 100)

    local portraitWidth = appearance.showPortrait and math.max(18, math.floor(width * (appearance.portraitPercent / 100))) or 0
    frame.Portrait:ClearAllPoints()
    if appearance.showPortrait then
        frame.Portrait:SetWidth(portraitWidth)
        frame.Portrait:SetPoint("TOP", frame, "TOP", 0, -2)
        frame.Portrait:SetPoint("BOTTOM", frame, "BOTTOM", 0, 2)
        if appearance.portraitSide == "RIGHT" then
            frame.Portrait:SetPoint("RIGHT", frame, "RIGHT", -2, 0)
        else
            frame.Portrait:SetPoint("LEFT", frame, "LEFT", 2, 0)
        end
        frame.Portrait:Show()
    else
        frame.Portrait:Hide()
    end

    local leftInset, rightInset = 2, 2
    if appearance.showPortrait then
        if appearance.portraitSide == "RIGHT" then rightInset = portraitWidth + 4 else leftInset = portraitWidth + 4 end
    end

    local powerHeight = math.max(8, math.floor(height * (state.powerPercent / 100)))
    frame.Health:ClearAllPoints()
    frame.Health:SetPoint("TOPLEFT", frame, "TOPLEFT", leftInset, -2)
    frame.Health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -rightInset, -2)
    frame.Health:SetPoint("BOTTOM", frame, "BOTTOM", 0, powerHeight)

    frame.Power:ClearAllPoints()
    frame.Power:SetPoint("TOPLEFT", frame.Health, "BOTTOMLEFT", 0, -1)
    frame.Power:SetPoint("TOPRIGHT", frame.Health, "BOTTOMRIGHT", 0, -1)
    frame.Power:SetPoint("BOTTOM", frame, "BOTTOM", 0, 2)

    local nameX, nameY = appearance.nameXOffset or 6, appearance.nameYOffset or 0
    frame.NameText:ClearAllPoints()
    frame.NameText:SetPoint("LEFT", frame.Health, "LEFT", nameX, nameY)
    frame.NameText:SetPoint("RIGHT", frame.Health, "RIGHT", nameX - 48, nameY)

    local healthX, healthY = appearance.healthXOffset or -6, appearance.healthYOffset or 0
    frame.HealthText:ClearAllPoints()
    frame.HealthText:SetPoint("RIGHT", frame.Health, "RIGHT", healthX, healthY)
    frame.HealthText:SetWidth(42)

    local font = ns.GetFontPath(appearance.fontFace)
    frame.NameText:SetFont(font, appearance.fontSize, "OUTLINE")
    frame.HealthText:SetFont(font, math.max(9, appearance.fontSize - 1), "OUTLINE")
    frame.NameText:SetShown(appearance.showName)
    frame.HealthText:SetShown(appearance.showHealthText)

    ApplyColors(frame, appearance)
    ApplyIndicatorLayout(frame, appearance)
    UpdateRoleIndicator(frame, appearance)
    UpdateRaidTarget(frame, appearance)
end

local function CreateMover(frame, labelText, positionKey)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)

    local mover = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    mover:SetFrameStrata("DIALOG")
    mover:SetAllPoints(frame)
    mover:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
    mover:SetBackdropColor(0.05, 0.35, 0.8, 0.28)
    mover:SetBackdropBorderColor(0.2, 0.65, 1, 1)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")

    local label = mover:CreateFontString(nil, "OVERLAY")
    label:SetFont(FONT, 11, "OUTLINE")
    label:SetPoint("CENTER")
    label:SetText(labelText)

    mover:SetScript("OnDragStart", function()
        if not InCombatLockdown() then frame:StartMoving() end
    end)
    mover:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        if not InCombatLockdown() then
            SaveMoverPosition(frame, positionKey)
            if frame.MIUF_UnitType == "party" and ns.ApplyPartyLayout then
                ns.ApplyPartyLayout()
            elseif frame.MIUF_UnitType == "boss" and ns.ApplyBossLayout then
                ns.ApplyBossLayout()
            end
        end
    end)

    local resize = CreateFrame("Button", nil, mover, "BackdropTemplate")
    resize:SetSize(14, 14)
    resize:SetPoint("BOTTOMRIGHT")
    resize:SetFrameLevel(mover:GetFrameLevel() + 10)
    resize:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
    resize:SetBackdropColor(0.12, 0.12, 0.12, 0.95)
    resize:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)
    resize:EnableMouse(true)

    local grip = resize:CreateFontString(nil, "OVERLAY")
    grip:SetFont(FONT, 10, "OUTLINE")
    grip:SetPoint("CENTER", 0, 1)
    grip:SetText("↘")

    resize:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" or InCombatLockdown() then return end
        local left, top = frame:GetLeft(), frame:GetTop()
        if not left or not top then return end
        resize.MIUF_ResizeState = { unitType = frame.MIUF_UnitType, left = left, top = top, minW = 100, maxW = 600, minH = 24, maxH = 150 }
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        resize:SetScript("OnUpdate", function(handle)
            local s = handle.MIUF_ResizeState
            if not s or InCombatLockdown() then return end
            local scale = UIParent:GetEffectiveScale()
            local cx, cy = GetCursorPosition()
            cx, cy = cx / scale, cy / scale
            local width = math.max(s.minW, math.min(s.maxW, cx - s.left))
            local height = math.max(s.minH, math.min(s.maxH, s.top - cy))
            ns.PreviewFrameSize(s.unitType, width, height)
        end)
    end)

    resize:SetScript("OnMouseUp", function(handle, button)
        if button ~= "LeftButton" then return end
        local s = handle.MIUF_ResizeState
        handle:SetScript("OnUpdate", nil)
        handle.MIUF_ResizeState = nil
        if not s or InCombatLockdown() then return end
        ns.SaveSize(s.unitType, frame:GetWidth(), frame:GetHeight())
        SaveMoverPosition(frame, positionKey)
        ns.ApplyFrameType(s.unitType)
        if ns.RefreshConfig then ns.RefreshConfig() end
    end)

    mover.MIUF_ResizeHandle = resize
    mover:Hide()
    frame.MIUF_Mover = mover
end

local function CreateNativeUnitFrame(unit, name, unitType, positionKey, registerWatch)
    unitType = unitType or unit
    positionKey = positionKey or unit

    local size = ns.GetSize(unitType)
    local frame = CreateFrame("Button", name, UIParent, "SecureUnitButtonTemplate")
    frame.MIUF_Unit = unit
    frame.MIUF_UnitType = unitType
    frame.MIUF_PositionKey = positionKey
    frame.__unit = unit
    frame:SetAttribute("unit", unit)
    frame:SetAttribute("*type1", "target")
    frame:SetAttribute("*type2", "togglemenu")
    frame:RegisterForClicks("AnyUp")
    frame:SetSize(size.width, size.height)

    frame:SetScript("OnEnter", function(self)
        GameTooltip_SetDefaultAnchor(GameTooltip, self)
        GameTooltip:SetUnit(self.MIUF_Unit)
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)

    frame.Background = CreateBackground(frame)
    frame.Border = CreateBorder(frame)

    local health = CreateFrame("StatusBar", nil, frame)
    health:SetMinMaxValues(0, 100)
    health:SetStatusBarTexture(FLAT)
    local healthBG = health:CreateTexture(nil, "BACKGROUND")
    healthBG:SetAllPoints(health)
    healthBG:SetColorTexture(0.08, 0.08, 0.08, 1)
    frame.Health = health

    local power = CreateFrame("StatusBar", nil, frame)
    power:SetMinMaxValues(0, 100)
    power:SetStatusBarTexture(FLAT)
    local powerBG = power:CreateTexture(nil, "BACKGROUND")
    powerBG:SetAllPoints(power)
    powerBG:SetColorTexture(0.05, 0.05, 0.05, 1)
    frame.Power = power

    local nameText = health:CreateFontString(nil, "OVERLAY")
    nameText:SetFont(FONT, 12, "OUTLINE")
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    frame.NameText = nameText

    local healthText = health:CreateFontString(nil, "OVERLAY")
    healthText:SetFont(FONT, 11, "OUTLINE")
    healthText:SetJustifyH("RIGHT")
    frame.HealthText = healthText

    local portrait = frame:CreateTexture(nil, "ARTWORK")
    portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.Portrait = portrait

    local raidTarget = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    raidTarget:SetTexture(RAID_TARGET_TEXTURE)
    raidTarget:SetSize(20, 20)
    raidTarget:SetPoint("CENTER", frame, "TOP", 0, 2)
    raidTarget:Hide()
    frame.RaidTargetIndicator = raidTarget

    if unitType == "player" or unitType == "party" then
        local role = health:CreateTexture(nil, "OVERLAY")
        role:SetSize(14, 14)
        role:SetPoint("TOPLEFT", health, "TOPLEFT", 3, -3)
        role:Hide()
        frame.GroupRoleIndicator = role
    end

    frame:RegisterUnitEvent("UNIT_HEALTH", unit)
    frame:RegisterUnitEvent("UNIT_MAXHEALTH", unit)
    frame:RegisterUnitEvent("UNIT_POWER_UPDATE", unit)
    frame:RegisterUnitEvent("UNIT_MAXPOWER", unit)
    frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", unit)
    frame:RegisterUnitEvent("UNIT_NAME_UPDATE", unit)
    frame:RegisterUnitEvent("UNIT_FACTION", unit)
    frame:RegisterUnitEvent("UNIT_CONNECTION", unit)
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("RAID_TARGET_UPDATE")
    frame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")

    if unit == "target" then
        frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif unit == "focus" then
        frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    elseif unit == "pet" then
        frame:RegisterUnitEvent("UNIT_PET", "player")
    elseif unit == "targettarget" then
        frame:RegisterUnitEvent("UNIT_TARGET", "target")
    end

    frame:SetScript("OnEvent", function(self, event)
        if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
            UpdateHealth(self)
        elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" then
            UpdatePower(self)
        elseif event == "UNIT_DISPLAYPOWER" then
            UpdatePower(self)
            ApplyColors(self, ns.GetAppearance(self.MIUF_UnitType) or {})
        elseif event == "UNIT_NAME_UPDATE" then
            UpdateName(self)
        elseif event == "RAID_TARGET_UPDATE" then
            UpdateRaidTarget(self)
        elseif event == "PLAYER_ROLES_ASSIGNED" or event == "GROUP_ROSTER_UPDATE" then
            UpdateRoleIndicator(self)
            ApplyColors(self, ns.GetAppearance(self.MIUF_UnitType) or {})
        elseif event == "UNIT_FACTION" or event == "UNIT_CONNECTION" then
            ApplyColors(self, ns.GetAppearance(self.MIUF_UnitType) or {})
        else
            UpdateFrame(self)
        end
    end)

    local moverLabel = (unitType == "party" or unitType == "boss") and unit or unitType
    CreateMover(frame, moverLabel, positionKey)
    ApplyPosition(positionKey, frame)
    ApplyFrameState(frame, BuildFrameState(unitType))
    UpdateFrame(frame)
    if registerWatch ~= false then
        RegisterUnitWatch(frame)
    else
        frame:Hide()
    end
    frames[unit] = frame
    return frame
end

function ns.ApplyFrameType(unitType)
    local state = BuildFrameState(unitType)
    for _, frame in pairs(frames) do
        if frame.MIUF_UnitType == unitType then ApplyFrameState(frame, state) end
    end
    if not InCombatLockdown() and ns.ApplyGroupLayout then ns.ApplyGroupLayout(unitType) end
end
ns.ApplySize = ns.ApplyFrameType

function ns.PreviewFrameType(unitType, overrides)
    if InCombatLockdown() then return end
    local state = BuildFrameState(unitType, overrides)
    for _, frame in pairs(frames) do
        if frame.MIUF_UnitType == unitType then ApplyFrameState(frame, state) end
    end
    if ns.ApplyGroupLayout then ns.ApplyGroupLayout(unitType) end
end

function ns.PreviewFrameSize(unitType, width, height)
    ns.PreviewFrameType(unitType, { size = { width = width, height = height } })
end

function ns.IsUnitTypePreviewEnabled(unitType) return previewEnabled[unitType] ~= false end

function ns.SetFrameMoversLocked(locked)
    for _, frame in pairs(frames) do
        local mover = frame.MIUF_Mover
        if mover then
            local unitType = frame.MIUF_UnitType
            local groupOwnerMismatch = unitType == "party" and ns.partyFrameMoverOwner ~= frame
            local bossOwnerMismatch = unitType == "boss" and frame.MIUF_Unit ~= "boss1"
            if locked or previewEnabled[unitType] == false or not ns.IsFrameTypeEnabled(unitType) or groupOwnerMismatch or bossOwnerMismatch then
                mover:Hide()
            else
                mover:Show()
            end
        end
    end
end

function ns.PreviewUnitTypeMovers(unitType, enabled)
    previewEnabled[unitType] = enabled and true or false
    ns.SetFrameMoversLocked(ns.AreFrameMoversLocked())
end

function ns.SetMoversLocked(locked)
    ns.SetFrameMoversLocked(locked)
    if ns.SetAuraMoversLocked then ns.SetAuraMoversLocked(locked) end
end

function ns.ResetLayout()
    for _, frame in pairs(frames) do ApplyPosition(frame.MIUF_PositionKey or frame.MIUF_Unit, frame) end
    for unitType in pairs(ns.defaultSizes) do ns.ApplyFrameType(unitType) end
    ns.SetFrameMoversLocked(true)
end

local spawned = false
function ns.SpawnAllFrames()
    if spawned then return end
    spawned = true

    if ns.IsFrameTypeEnabled("player") then CreateNativeUnitFrame("player", "MIUF_Player") end
    if ns.IsFrameTypeEnabled("target") then CreateNativeUnitFrame("target", "MIUF_Target") end
    if ns.IsFrameTypeEnabled("focus") then CreateNativeUnitFrame("focus", "MIUF_Focus") end
    if ns.IsFrameTypeEnabled("pet") then CreateNativeUnitFrame("pet", "MIUF_Pet") end
    if ns.IsFrameTypeEnabled("targettarget") then CreateNativeUnitFrame("targettarget", "MIUF_TargetTarget") end

    if ns.IsFrameTypeEnabled("party") then
        for i = 1, 4 do
            local unit = "party" .. i
            CreateNativeUnitFrame(unit, "MIUF_Party" .. i, "party", "party1")
        end
        local primaryPlayer = frames.player
        local partyPlayer = CreateNativeUnitFrame("player", "MIUF_PartyPlayer", "party", "party1", false)
        frames.player = primaryPlayer
        frames.partyplayer = partyPlayer
    end

    if ns.IsFrameTypeEnabled("boss") then
        for i = 1, 5 do
            local unit = "boss" .. i
            CreateNativeUnitFrame(unit, "MIUF_Boss" .. i, "boss", "boss1")
        end
    end

    if ns.ApplyPartyLayout then ns.ApplyPartyLayout() end
    if ns.ApplyBossLayout then ns.ApplyBossLayout() end
    ns.SetFrameMoversLocked(ns.AreFrameMoversLocked())
end

local combatWatcher = CreateFrame("Frame")
combatWatcher:RegisterEvent("PLAYER_REGEN_DISABLED")
combatWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
combatWatcher:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        ns.SetFrameMoversLocked(true)
    else
        if ns.ApplyPartyLayout then ns.ApplyPartyLayout() end
        if ns.ApplyBossLayout then ns.ApplyBossLayout() end
        ns.SetFrameMoversLocked(ns.AreFrameMoversLocked())
    end
end)