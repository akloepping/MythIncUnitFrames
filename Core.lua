local ADDON_NAME, ns = ...

ns.addonName = ADDON_NAME
do
    local getMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    ns.version = (getMetadata and getMetadata(ADDON_NAME, "Version")) or "unknown"
end

local defaultPositions = {
    player = { point = "CENTER", relativePoint = "CENTER", x = -285, y = -150 },
    target = { point = "CENTER", relativePoint = "CENTER", x = 285, y = -150 },
    targettarget = { point = "CENTER", relativePoint = "CENTER", x = 285, y = -205 },
    focus = { point = "CENTER", relativePoint = "CENTER", x = 285, y = 20 },
    pet = { point = "CENTER", relativePoint = "CENTER", x = -285, y = -205 },
}

for i = 1, 4 do
    defaultPositions["party" .. i] = {
        point = "TOPLEFT", relativePoint = "TOPLEFT", x = 35,
        y = -220 - ((i - 1) * 78),
    }
end

for i = 1, 5 do
    defaultPositions["boss" .. i] = {
        point = "RIGHT", relativePoint = "RIGHT", x = -45,
        y = 140 - ((i - 1) * 78),
    }
end

local defaultSizes = {
    player = { width = 250, height = 54 }, target = { width = 250, height = 54 },
    focus = { width = 220, height = 48 }, pet = { width = 180, height = 38 },
    targettarget = { width = 180, height = 38 }, party = { width = 210, height = 46 },
    boss = { width = 220, height = 46 },
}

local defaultEnabled = {
    player = true, target = true, focus = true, pet = true,
    targettarget = true, party = true, boss = true,
}

local defaultGroupLayout = {
    party = { orientation = "VERTICAL", direction = "DOWN", spacing = 32, includePlayer = false },
    boss = { orientation = "VERTICAL", direction = "DOWN", spacing = 32 },
}

local defaultBarLayout = {}
local defaultAppearance = {}
local defaultAuraLayout = {}
for unitType in pairs(defaultSizes) do
    defaultBarLayout[unitType] = { powerPercent = 22 }
    defaultAppearance[unitType] = {
        fontSize = unitType == "party" and 11 or 12,
        fontFace = "friz",
        nameVAlign = "MIDDLE",
        healthVAlign = "MIDDLE",
        texture = "flat",
        healthColor = "automatic",
        powerColor = "automatic",
        backgroundOpacity = 92,
        borderOpacity = 100,
        showName = true,
        showHealthText = true,
        showPortrait = false,
        portraitSide = "LEFT",
        portraitPercent = 22,
    }
    defaultAuraLayout[unitType] = {
        buffs = { enabled = true, showText = true, iconSize = 22, maxCount = 6, spacing = 2, anchor = "TOP", growth = "RIGHT", xOffset = 0, yOffset = 5 },
        debuffs = { enabled = true, showText = true, iconSize = 22, maxCount = 6, spacing = 2, anchor = "BOTTOM", growth = "RIGHT", xOffset = 0, yOffset = -26 },
        defensives = { enabled = true, showText = true, iconSize = 20, maxCount = 3, spacing = 2, anchor = "TOP", growth = "LEFT", xOffset = 0, yOffset = 26 },
    }
end

local function CopyTable(source)
    local result = {}
    for key, value in pairs(source) do
        result[key] = type(value) == "table" and CopyTable(value) or value
    end
    return result
end

local function FillMissing(dest, defaults)
    if type(dest) ~= "table" then return CopyTable(defaults) end
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            dest[key] = FillMissing(dest[key], value)
        elseif dest[key] == nil or type(dest[key]) ~= type(value) then
            dest[key] = value
        end
    end
    return dest
end

local function InitializeDatabase()
    if type(MythIncUnitFramesDB) ~= "table" then MythIncUnitFramesDB = {} end
    MythIncUnitFramesDB.positions = FillMissing(MythIncUnitFramesDB.positions, defaultPositions)
    MythIncUnitFramesDB.sizes = FillMissing(MythIncUnitFramesDB.sizes, defaultSizes)
    MythIncUnitFramesDB.barLayout = FillMissing(MythIncUnitFramesDB.barLayout, defaultBarLayout)
    MythIncUnitFramesDB.appearance = FillMissing(MythIncUnitFramesDB.appearance, defaultAppearance)
    MythIncUnitFramesDB.auraLayout = FillMissing(MythIncUnitFramesDB.auraLayout, defaultAuraLayout)
    MythIncUnitFramesDB.enabled = FillMissing(MythIncUnitFramesDB.enabled, defaultEnabled)
    MythIncUnitFramesDB.groupLayout = FillMissing(MythIncUnitFramesDB.groupLayout, defaultGroupLayout)
    if type(MythIncUnitFramesDB.trackedBuffs) ~= "table" then MythIncUnitFramesDB.trackedBuffs = {} end
    if type(MythIncUnitFramesDB.seenBuffs) ~= "table" then MythIncUnitFramesDB.seenBuffs = {} end
    -- 0.6.5 splits unit-frame movers and aura movers into independent lock states.
    -- Migrate the old single `locked` value so existing users keep the behavior they had.
    local legacyLocked = type(MythIncUnitFramesDB.locked) == "boolean" and MythIncUnitFramesDB.locked or true
    if type(MythIncUnitFramesDB.frameLocked) ~= "boolean" then MythIncUnitFramesDB.frameLocked = legacyLocked end
    if type(MythIncUnitFramesDB.auraLocked) ~= "boolean" then MythIncUnitFramesDB.auraLocked = legacyLocked end
    MythIncUnitFramesDB.locked = nil
    MythIncUnitFramesDB.version = 15
end

-- SavedVariables are not guaranteed to be populated while addon files are still
-- executing. Initialize only after ADDON_LOADED (or from runtime calls after that).

ns.defaultPositions = defaultPositions
ns.defaultSizes = defaultSizes
ns.defaultBarLayout = defaultBarLayout
ns.defaultAppearance = defaultAppearance
ns.defaultAuraLayout = defaultAuraLayout
ns.defaultEnabled = defaultEnabled
ns.defaultGroupLayout = defaultGroupLayout
ns.CopyTable = CopyTable
ns.InitializeDatabase = InitializeDatabase

function ns.GetPosition(unit) InitializeDatabase(); return MythIncUnitFramesDB.positions[unit] or defaultPositions[unit] end
function ns.SavePosition(unit, point, relativePoint, x, y)
    InitializeDatabase()
    MythIncUnitFramesDB.positions[unit] = {
        point = point, relativePoint = relativePoint,
        x = math.floor((x or 0) + 0.5), y = math.floor((y or 0) + 0.5),
    }
end

function ns.GetSize(unitType) InitializeDatabase(); return MythIncUnitFramesDB.sizes[unitType] or defaultSizes[unitType] end
function ns.SaveSize(unitType, width, height)
    InitializeDatabase()
    MythIncUnitFramesDB.sizes[unitType] = { width = math.floor(width + 0.5), height = math.floor(height + 0.5) }
end

function ns.GetPowerPercent(unitType)
    InitializeDatabase()
    return MythIncUnitFramesDB.barLayout[unitType].powerPercent
end
function ns.SavePowerPercent(unitType, percent)
    InitializeDatabase()
    MythIncUnitFramesDB.barLayout[unitType].powerPercent = math.floor(percent + 0.5)
end

function ns.GetAppearance(unitType)
    InitializeDatabase()
    return MythIncUnitFramesDB.appearance[unitType]
end
function ns.SaveAppearance(unitType, values)
    InitializeDatabase()
    local current = MythIncUnitFramesDB.appearance[unitType]
    for key, value in pairs(values) do current[key] = value end
end

function ns.IsFrameTypeEnabled(unitType)
    InitializeDatabase()
    return MythIncUnitFramesDB.enabled[unitType] ~= false
end
function ns.SetFrameTypeEnabled(unitType, enabled)
    InitializeDatabase()
    MythIncUnitFramesDB.enabled[unitType] = enabled and true or false
end

function ns.GetGroupLayout(unitType)
    InitializeDatabase()
    return MythIncUnitFramesDB.groupLayout[unitType]
end
function ns.SaveGroupLayout(unitType, values)
    InitializeDatabase()
    local current = MythIncUnitFramesDB.groupLayout[unitType]
    if type(current) ~= "table" then
        local defaults = defaultGroupLayout[unitType]
        current = defaults and CopyTable(defaults) or {}
        MythIncUnitFramesDB.groupLayout[unitType] = current
    end
    for key, value in pairs(values) do current[key] = value end
end

function ns.GetAuraLayout(unitType, auraType)
    InitializeDatabase()
    local frameAuras = MythIncUnitFramesDB.auraLayout[unitType]
    return frameAuras and frameAuras[auraType] or nil
end
function ns.SaveAuraLayout(unitType, auraType, values)
    InitializeDatabase()
    if not MythIncUnitFramesDB.auraLayout[unitType] then MythIncUnitFramesDB.auraLayout[unitType] = {} end
    local current = MythIncUnitFramesDB.auraLayout[unitType][auraType]
    if type(current) ~= "table" then
        local defaults = defaultAuraLayout[unitType] and defaultAuraLayout[unitType][auraType]
        current = defaults and CopyTable(defaults) or {}
        MythIncUnitFramesDB.auraLayout[unitType][auraType] = current
    end
    for key, value in pairs(values) do current[key] = value end
end


function ns.GetTrackedBuffs()
    InitializeDatabase()
    return MythIncUnitFramesDB.trackedBuffs
end
function ns.SetTrackedBuffs(values)
    InitializeDatabase()
    MythIncUnitFramesDB.trackedBuffs = type(values) == "table" and CopyTable(values) or {}
end
function ns.GetTrackedBuffSpellIDs()
    InitializeDatabase()
    local ids = {}
    for spellID in pairs(MythIncUnitFramesDB.trackedBuffs) do
        local id = tonumber(spellID)
        if id then ids[id] = true end
    end
    return ids
end
function ns.GetSeenBuffs()
    InitializeDatabase()
    return MythIncUnitFramesDB.seenBuffs
end
function ns.RecordSeenBuff(spellID, name, icon)
    InitializeDatabase()
    local id = tonumber(spellID)
    if not id then return end
    local current = MythIncUnitFramesDB.seenBuffs[id]
    if type(current) ~= "table" then current = {}; MythIncUnitFramesDB.seenBuffs[id] = current end
    if name then current.name = name end
    if icon then current.icon = icon end
    current.lastSeen = time and time() or 0
end
function ns.ClearSeenBuffs()
    InitializeDatabase()
    MythIncUnitFramesDB.seenBuffs = {}
end

function ns.AreFrameMoversLocked() InitializeDatabase(); return MythIncUnitFramesDB.frameLocked end
function ns.SetFrameMoversLockedState(locked) InitializeDatabase(); MythIncUnitFramesDB.frameLocked = locked and true or false end
function ns.AreAuraMoversLocked() InitializeDatabase(); return MythIncUnitFramesDB.auraLocked end
function ns.SetAuraMoversLockedState(locked) InitializeDatabase(); MythIncUnitFramesDB.auraLocked = locked and true or false end

-- Compatibility aliases retained so the cleanup pass does not change callers.
function ns.IsLocked() return ns.AreFrameMoversLocked() end
function ns.SetLocked(locked) ns.SetFrameMoversLockedState(locked) end

function ns.ResetAllSettings()
    InitializeDatabase()
    MythIncUnitFramesDB.positions = CopyTable(defaultPositions)
    MythIncUnitFramesDB.sizes = CopyTable(defaultSizes)
    MythIncUnitFramesDB.barLayout = CopyTable(defaultBarLayout)
    MythIncUnitFramesDB.appearance = CopyTable(defaultAppearance)
    MythIncUnitFramesDB.auraLayout = CopyTable(defaultAuraLayout)
    MythIncUnitFramesDB.enabled = CopyTable(defaultEnabled)
    MythIncUnitFramesDB.groupLayout = CopyTable(defaultGroupLayout)
    MythIncUnitFramesDB.trackedBuffs = {}
    MythIncUnitFramesDB.seenBuffs = {}
    MythIncUnitFramesDB.frameLocked = true
    MythIncUnitFramesDB.auraLocked = true
end

function ns.ResetFrameType(unitType)
    InitializeDatabase()
    if defaultSizes[unitType] then
        MythIncUnitFramesDB.sizes[unitType] = CopyTable(defaultSizes[unitType])
        MythIncUnitFramesDB.barLayout[unitType] = CopyTable(defaultBarLayout[unitType])
        MythIncUnitFramesDB.appearance[unitType] = CopyTable(defaultAppearance[unitType])
        MythIncUnitFramesDB.auraLayout[unitType] = CopyTable(defaultAuraLayout[unitType])
    end
end

function ns.ResetFrameAppearance(unitType)
    InitializeDatabase()
    if defaultSizes[unitType] then
        MythIncUnitFramesDB.sizes[unitType] = CopyTable(defaultSizes[unitType])
        MythIncUnitFramesDB.barLayout[unitType] = CopyTable(defaultBarLayout[unitType])
        MythIncUnitFramesDB.appearance[unitType] = CopyTable(defaultAppearance[unitType])
        if defaultGroupLayout[unitType] then
            MythIncUnitFramesDB.groupLayout[unitType] = CopyTable(defaultGroupLayout[unitType])
        end
    end
end

function ns.ResetAuraLayout(unitType, auraType)
    InitializeDatabase()
    local defaults = defaultAuraLayout[unitType] and defaultAuraLayout[unitType][auraType]
    if defaults then
        MythIncUnitFramesDB.auraLayout[unitType][auraType] = CopyTable(defaults)
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, event, addon)
    if event ~= "ADDON_LOADED" or addon ~= ADDON_NAME then return end
    InitializeDatabase()
    if ns.SpawnAllFrames then ns.SpawnAllFrames() end
    print("|cff66ccffMythInc Unit Frames|r " .. ns.version .. " loaded.")
end)

local function PrintHelp()
    print("|cff66ccffMythInc Unit Frames|r " .. ns.version)
    print("/miuf or /miuf config - open configuration")
    print("/miuf unlock          - show unit-frame movers")
    print("/miuf lock            - hide unit-frame movers")
    print("/miuf auraunlock      - show aura movers")
    print("/miuf auralock        - hide aura movers")
    print("/miuf size <frame> <width> <height>")
    print("/miuf reset           - restore all defaults")
    print("/miuf version         - show addon version")
end

SLASH_MYTHINCUNITFRAMES1 = "/miuf"
SlashCmdList.MYTHINCUNITFRAMES = function(msg)
    InitializeDatabase()
    local input = (msg or ""):match("^%s*(.-)%s*$")
    local command, rest = input:match("^(%S+)%s*(.-)$")
    command = command and command:lower() or ""

    if command == "" or command == "config" or command == "options" then
        if ns.ToggleConfig then ns.ToggleConfig() else PrintHelp() end
        return
    end
    if command == "help" then PrintHelp(); return end
    if command == "version" then print("|cff66ccffMythInc Unit Frames|r version " .. ns.version); return end

    if command == "unlock" then
        if InCombatLockdown() then print("|cff66ccffMythInc Unit Frames|r cannot unlock frames during combat."); return end
        ns.SetFrameMoversLockedState(false)
        if ns.SetFrameMoversLocked then ns.SetFrameMoversLocked(false) end
        if ns.RefreshConfig then ns.RefreshConfig() end
        print("|cff66ccffMythInc Unit Frames|r frames unlocked.")
        return
    end

    if command == "lock" then
        ns.SetFrameMoversLockedState(true)
        if ns.SetFrameMoversLocked then ns.SetFrameMoversLocked(true) end
        if ns.RefreshConfig then ns.RefreshConfig() end
        print("|cff66ccffMythInc Unit Frames|r frames locked.")
        return
    end


    if command == "auraunlock" then
        if InCombatLockdown() then print("|cff66ccffMythInc Unit Frames|r cannot unlock aura movers during combat."); return end
        ns.SetAuraMoversLockedState(false)
        if ns.SetAuraMoversLocked then ns.SetAuraMoversLocked(false) end
        if ns.RefreshConfig then ns.RefreshConfig() end
        print("|cff66ccffMythInc Unit Frames|r aura movers unlocked.")
        return
    end

    if command == "auralock" then
        ns.SetAuraMoversLockedState(true)
        if ns.SetAuraMoversLocked then ns.SetAuraMoversLocked(true) end
        if ns.RefreshConfig then ns.RefreshConfig() end
        print("|cff66ccffMythInc Unit Frames|r aura movers locked.")
        return
    end

    if command == "size" then
        local unitType, widthText, heightText = rest:match("^(%S+)%s+(%d+)%s+(%d+)$")
        unitType = unitType and unitType:lower() or nil
        local width, height = tonumber(widthText), tonumber(heightText)
        if not unitType or not defaultSizes[unitType] then
            print("|cff66ccffMythInc Unit Frames|r unknown frame type."); return
        end
        if not width or not height or width < 100 or width > 600 or height < 24 or height > 150 then
            print("|cff66ccffMythInc Unit Frames|r size limits: width 100-600, height 24-150."); return
        end
        if InCombatLockdown() then print("|cff66ccffMythInc Unit Frames|r cannot resize during combat."); return end
        ns.SaveSize(unitType, width, height)
        if ns.ApplyFrameType then ns.ApplyFrameType(unitType) elseif ns.ApplySize then ns.ApplySize(unitType) end
        if ns.RefreshConfig then ns.RefreshConfig() end
        print(string.format("|cff66ccffMythInc Unit Frames|r %s size set to %dx%d.", unitType, width, height))
        return
    end

    if command == "reset" then
        if InCombatLockdown() then print("|cff66ccffMythInc Unit Frames|r cannot reset during combat."); return end
        ns.ResetAllSettings()
        if ns.ResetLayout then ns.ResetLayout() end
        if ns.RefreshConfig then ns.RefreshConfig() end
        print("|cff66ccffMythInc Unit Frames|r settings reset to defaults.")
        return
    end
    PrintHelp()
end
