-- Follow oUF's per-frame suppression (oUF-wow/oUF, blizzard.lua).
-- SetRolesets is protected: apply outside combat, without changing UI-mode filters.
local function SuppressFrame(frame)
    if not frame then return end
    frame:UnregisterAllEvents()
    frame:SetRolesets("alwaysBlocked")
end

local events = CreateFrame("Frame")

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

    SuppressFrame(PartyFrame)
    if PartyFrame and PartyFrame.PartyMemberFramePool then
        for frame in PartyFrame.PartyMemberFramePool:EnumerateActive() do
            SuppressFrame(frame)
        end
    end
    -- CompactPartyFrame_Generate parents compact party frames to PartyFrame.
    -- Later-created members remain covered by the blocked parent, as in oUF.
    for i = 1, 5 do SuppressFrame(_G["CompactPartyFrameMember" .. i]) end
end

events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, addonName)
    if event == "ADDON_LOADED" then
        if addonName ~= "Blizzard_UnitFrame" or not IsLoggedIn() then return end
    end
    SuppressBlizzardFrames()
end)

-- Also support MIUF being loaded after the login event.
if IsLoggedIn() then SuppressBlizzardFrames() end
