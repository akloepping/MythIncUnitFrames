local ADDON_NAME, ns = ...

local settingKey = "partyRoleIconsEnabled"
local configButton

local function InitializeSetting()
    if ns.InitializeDatabase then ns.InitializeDatabase() end
    if type(MythIncUnitFramesDB) ~= "table" then MythIncUnitFramesDB = {} end
    if type(MythIncUnitFramesDB[settingKey]) ~= "boolean" then
        MythIncUnitFramesDB[settingKey] = false
    end
end

local function RoleIconsEnabled()
    InitializeSetting()
    return MythIncUnitFramesDB[settingKey] == true
end

local function ApplyRoleIcon(frame)
    if not frame or frame.MIUF_UnitType ~= "party" or not frame.GroupRoleIndicator then return end

    if RoleIconsEnabled() then
        if frame.EnableElement then frame:EnableElement("GroupRoleIndicator") end
        if frame.GroupRoleIndicator.ForceUpdate then
            frame.GroupRoleIndicator:ForceUpdate()
        else
            frame.GroupRoleIndicator:Show()
        end
    else
        if frame.DisableElement then frame:DisableElement("GroupRoleIndicator") end
        frame.GroupRoleIndicator:Hide()
    end
end

local function ApplyAllRoleIcons()
    if not ns.frames then return end
    for _, frame in pairs(ns.frames) do
        ApplyRoleIcon(frame)
    end
end

local function RefreshButton()
    if not configButton then return end
    configButton:SetText("Party Role Icons: " .. (RoleIconsEnabled() and "On" or "Off"))
end

local function SetRoleIconsEnabled(enabled)
    if InCombatLockdown() then
        print("|cff66ccffMythInc Unit Frames|r party role icons cannot be changed during combat.")
        return
    end

    InitializeSetting()
    MythIncUnitFramesDB[settingKey] = enabled and true or false
    ApplyAllRoleIcons()
    RefreshButton()
end

function ns.ArePartyRoleIconsEnabled()
    return RoleIconsEnabled()
end

function ns.SetPartyRoleIconsEnabled(enabled)
    SetRoleIconsEnabled(enabled)
end

-- Apply the saved choice after Layout.lua creates the party frames.
local originalSpawnAllFrames = ns.SpawnAllFrames
if originalSpawnAllFrames then
    ns.SpawnAllFrames = function(...)
        originalSpawnAllFrames(...)
        ApplyAllRoleIcons()
    end
end

-- Re-apply the visibility choice whenever party appearance/layout is refreshed.
local originalApplyFrameType = ns.ApplyFrameType
if originalApplyFrameType then
    ns.ApplyFrameType = function(unitType, ...)
        originalApplyFrameType(unitType, ...)
        if unitType == "party" then ApplyAllRoleIcons() end
    end
end

-- Config.lua creates its window lazily. Hook the existing toggle so the option
-- is added the first time the main MIUF configuration window is opened.
local originalToggleConfig = ns.ToggleConfig
if originalToggleConfig then
    ns.ToggleConfig = function(...)
        local result = originalToggleConfig(...)
        local config = _G.MIUF_ConfigFrame

        if config and not configButton then
            configButton = CreateFrame("Button", nil, config, "UIPanelButtonTemplate")
            configButton:SetSize(155, 28)
            configButton:SetPoint("BOTTOMLEFT", config, "BOTTOMLEFT", 300, 18)
            configButton:SetScript("OnClick", function()
                SetRoleIconsEnabled(not RoleIconsEnabled())
            end)
        end

        RefreshButton()
        return result
    end
end
