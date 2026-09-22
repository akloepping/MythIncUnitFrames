local ADDON_NAME, ns = ...

local events = CreateFrame("Frame")

-- Blizzard unit frames owned by MIUF should remain fully alive while hidden.
-- Reparenting them to a hidden frame preserves Blizzard's events, state drivers
-- and visibility logic so they can be restored when the corresponding MIUF
-- frame type is disabled.
local unitHiddenParent = CreateFrame("Frame")
unitHiddenParent:Hide()

local unitOwnership = {
    player = {
        getFrame = function()
            return PlayerFrame
        end,
    },
    pet = {
        getFrame = function()
            return PetFrame
        end,
    },
    target = {
        getFrame = function()
            return TargetFrame
        end,
    },
    focus = {
        getFrame = function()
            return FocusFrame
        end,
    },
    boss = {
        getFrame = function()
            return BossTargetFrameContainer
        end,
    },
}

local function UpdateUnitSuppression(unitType)
    if not IsLoggedIn() then return end

    if InCombatLockdown() then
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    local ownership = unitOwnership[unitType]
    if not ownership then return end

    local frame = ownership.getFrame()
    if not frame then return end

    if ownership.frame ~= frame then
        ownership.frame = frame
        ownership.originalParent = frame:GetParent()

        hooksecurefunc(frame, "SetParent", function(self, parent)
            if ownership.changingParent then return end

            -- Preserve later Blizzard parent changes for restoration, but never
            -- treat MIUF's hidden parent as Blizzard's intended parent.
            if parent ~= unitHiddenParent then
                ownership.originalParent = parent
            end

            UpdateUnitSuppression(unitType)
        end)
    end

    if ns.IsFrameTypeEnabled(unitType) then
        if frame:GetParent() ~= unitHiddenParent then
            ownership.changingParent = true
            frame:SetParent(unitHiddenParent)
            ownership.changingParent = false
        end
    elseif frame:GetParent() == unitHiddenParent then
        ownership.changingParent = true
        frame:SetParent(ownership.originalParent)
        ownership.changingParent = false
    end
end

local function UpdateUnitFrameSuppression()
    UpdateUnitSuppression("player")
    UpdateUnitSuppression("pet")
    UpdateUnitSuppression("target")
    UpdateUnitSuppression("focus")
    UpdateUnitSuppression("boss")
end

-- Mainline Blizzard_CompactRaidFrames: the container owns the raid groups,
-- individual raid frames, pets and tank/assist targets. The manager is a
-- separate UIParent child. Keep its controls and all Blizzard events intact.
-- A hidden parent also covers frames generated or shown later, including in
-- combat, without overwriting Blizzard's own shown state or settings.
local raidHiddenParent = CreateFrame("Frame")
raidHiddenParent:Hide()
local raidContainer, raidOriginalParent
local changingRaidParent = false

-- Reversible Blizzard Party-frame suppression.
-- Keep Blizzard's events, pools and visibility state intact while MIUF owns Party.
local partyHiddenParent = CreateFrame("Frame")
partyHiddenParent:Hide()
local partyFrame, partyOriginalParent
local changingPartyParent = false

-- Keep the normal Player castbar alive while reversibly hiding it.
local playerCastbarHiddenParent = CreateFrame("Frame")
playerCastbarHiddenParent:Hide()
local playerCastbar, playerCastbarOriginalParent
local changingPlayerCastbarParent = false

local function UpdateRaidSuppression()
    if not IsLoggedIn() or changingRaidParent then return end

    if InCombatLockdown() then
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    local container = CompactRaidFrameContainer
    if not container then return end

    if raidContainer ~= container then
        raidContainer = container
        raidOriginalParent = container:GetParent()

        hooksecurefunc(container, "SetParent", function(self, parent)
            if changingRaidParent then return end

            -- Preserve a later Blizzard parent change for restoration.
            if parent ~= raidHiddenParent then
                raidOriginalParent = parent
            end

            UpdateRaidSuppression()
        end)
    end

    -- Read saved/applied settings only. ConfigSession previews and Revert
    -- must never change suppression; combat retries read the latest profile.
    if ns.IsFrameTypeEnabled("raid") then
        if container:GetParent() ~= raidHiddenParent then
            changingRaidParent = true
            container:SetParent(raidHiddenParent)
            changingRaidParent = false
        end
    elseif container:GetParent() == raidHiddenParent then
        changingRaidParent = true

        -- Re-evaluate Blizzard's settings/group visibility while still hidden.
        -- Never Show() an empty raid container ourselves.
        if CompactRaidFrameManager_UpdateContainerVisibility then
            CompactRaidFrameManager_UpdateContainerVisibility()
        end

        container:SetParent(raidOriginalParent)
        changingRaidParent = false
    end
end

local function UpdatePartySuppression()
    if not IsLoggedIn() or changingPartyParent then return end

    if InCombatLockdown() then
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    local frame = PartyFrame
    if not frame then return end

    if partyFrame ~= frame then
        partyFrame = frame
        partyOriginalParent = frame:GetParent()

        hooksecurefunc(frame, "SetParent", function(self, parent)
            if changingPartyParent then return end

            -- Preserve a later Blizzard parent change for restoration.
            if parent ~= partyHiddenParent then
                partyOriginalParent = parent
            end

            UpdatePartySuppression()
        end)
    end

    if ns.IsFrameTypeEnabled("party") then
        if frame:GetParent() ~= partyHiddenParent then
            changingPartyParent = true
            frame:SetParent(partyHiddenParent)
            changingPartyParent = false
        end
    elseif frame:GetParent() == partyHiddenParent then
        changingPartyParent = true
        frame:SetParent(partyOriginalParent)
        changingPartyParent = false
    end
end

local function UpdatePlayerCastbarSuppression()
    if not IsLoggedIn() or changingPlayerCastbarParent then return end

    if InCombatLockdown() then
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    local frame = PlayerCastingBarFrame
    if not frame then return end

    if playerCastbar ~= frame then
        playerCastbar = frame
        playerCastbarOriginalParent = frame:GetParent()

        hooksecurefunc(frame, "SetParent", function(self, parent)
            if changingPlayerCastbarParent then return end

            -- Preserve a later Blizzard parent change for restoration.
            if parent ~= playerCastbarHiddenParent then
                playerCastbarOriginalParent = parent
            end

            UpdatePlayerCastbarSuppression()
        end)
    end

    -- Ownership follows saved settings, not staged configuration previews.
    if ns.IsFrameTypeEnabled("player") and ns.GetCastbarLayout("player").enabled then
        if frame:GetParent() ~= playerCastbarHiddenParent then
            changingPlayerCastbarParent = true
            frame:SetParent(playerCastbarHiddenParent)
            changingPlayerCastbarParent = false
        end
    elseif frame:GetParent() == playerCastbarHiddenParent then
        changingPlayerCastbarParent = true
        frame:SetParent(playerCastbarOriginalParent)
        changingPlayerCastbarParent = false
    end
end

-- Saved-setting changes are the application boundary, including non-GUI
-- callers. Apply normally updates live; profile selection reloads the UI.
hooksecurefunc(ns, "SetFrameTypeEnabled", UpdateUnitFrameSuppression)
hooksecurefunc(ns, "SetActiveProfile", UpdateUnitFrameSuppression)
hooksecurefunc(ns, "ResetAllSettings", UpdateUnitFrameSuppression)

hooksecurefunc(ns, "SetFrameTypeEnabled", UpdateRaidSuppression)
hooksecurefunc(ns, "SetActiveProfile", UpdateRaidSuppression)
hooksecurefunc(ns, "ResetAllSettings", UpdateRaidSuppression)

hooksecurefunc(ns, "SetFrameTypeEnabled", UpdatePartySuppression)
hooksecurefunc(ns, "SetActiveProfile", UpdatePartySuppression)
hooksecurefunc(ns, "ResetAllSettings", UpdatePartySuppression)

hooksecurefunc(ns, "SetFrameTypeEnabled", UpdatePlayerCastbarSuppression)
hooksecurefunc(ns, "SetActiveProfile", UpdatePlayerCastbarSuppression)
hooksecurefunc(ns, "ResetAllSettings", UpdatePlayerCastbarSuppression)
hooksecurefunc(ns, "SaveCastbarLayout", UpdatePlayerCastbarSuppression)

local function UpdateAllSuppression()
    UpdateUnitFrameSuppression()
    UpdateRaidSuppression()
    UpdatePartySuppression()
    UpdatePlayerCastbarSuppression()
end

events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("GROUP_ROSTER_UPDATE")

events:SetScript("OnEvent", function(_, event, addonName)
    if event == "ADDON_LOADED" then
        if not IsLoggedIn() then return end

        if addonName == "Blizzard_CompactRaidFrames" then
            UpdateRaidSuppression()
            return
        end

        if addonName ~= "Blizzard_UnitFrame" then
            return
        end
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        UpdateAllSuppression()
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        events:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end

    UpdateAllSuppression()
end)

-- Also support MIUF being loaded after the login event.
if IsLoggedIn() then
    UpdateAllSuppression()
end
