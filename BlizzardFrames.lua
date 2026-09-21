-- Follow oUF's per-frame suppression (oUF-wow/oUF, blizzard.lua).
-- SetRolesets is protected: apply outside combat, without changing UI-mode filters.
local ADDON_NAME, ns = ...

local function SuppressFrame(frame)
    if not frame then return end
    frame:UnregisterAllEvents()
    frame:SetRolesets("alwaysBlocked")
end

local events = CreateFrame("Frame")

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
            if parent ~= raidHiddenParent then raidOriginalParent = parent end
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

    -- Temporary ownership condition until a dedicated castbar setting exists.
    if ns.IsFrameTypeEnabled("player") then
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
-- callers. The GUI currently reloads after Apply and profile selection.
hooksecurefunc(ns, "SetFrameTypeEnabled", UpdateRaidSuppression)
hooksecurefunc(ns, "SetActiveProfile", UpdateRaidSuppression)
hooksecurefunc(ns, "ResetAllSettings", UpdateRaidSuppression)

hooksecurefunc(ns, "SetFrameTypeEnabled", UpdatePartySuppression)
hooksecurefunc(ns, "SetActiveProfile", UpdatePartySuppression)
hooksecurefunc(ns, "ResetAllSettings", UpdatePartySuppression)

hooksecurefunc(ns, "SetFrameTypeEnabled", UpdatePlayerCastbarSuppression)
hooksecurefunc(ns, "SetActiveProfile", UpdatePlayerCastbarSuppression)
hooksecurefunc(ns, "ResetAllSettings", UpdatePlayerCastbarSuppression)

local function SuppressBlizzardFrames()
    if InCombatLockdown() then
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    events:UnregisterEvent("PLAYER_REGEN_ENABLED")

    SuppressFrame(PlayerFrame)
    SuppressFrame(PetFrame)
    SuppressFrame(TargetFrame)
    SuppressFrame(FocusFrame)

    -- Block the containers too, so layout resets cannot restore their children.
    SuppressFrame(BossTargetFrameContainer)
    for i = 1, 5 do SuppressFrame(_G["Boss" .. i .. "TargetFrame"]) end
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
        if addonName ~= "Blizzard_UnitFrame" then return end
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        UpdateRaidSuppression()
        UpdatePartySuppression()
        UpdatePlayerCastbarSuppression()
        return
    end
    SuppressBlizzardFrames()
    UpdateRaidSuppression()
    UpdatePartySuppression()
    UpdatePlayerCastbarSuppression()
end)

-- Also support MIUF being loaded after the login event.
if IsLoggedIn() then
    SuppressBlizzardFrames()
    UpdateRaidSuppression()
    UpdatePartySuppression()
    UpdatePlayerCastbarSuppression()
end
