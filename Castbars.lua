local ADDON_NAME, ns = ...

local FLAT = "Interface\\Buttons\\WHITE8x8"
local FONT = "Fonts\\FRIZQT__.TTF"

local CASTBAR_TYPES = {
    player = true,
    target = true,
    focus = true,
    boss = true,
}

local function SetInterruptibleVisual(bar, notInterruptible)
    if bar.LockText and bar.LockText.SetAlphaFromBoolean then
        bar.LockText:SetAlphaFromBoolean(notInterruptible, 1, 0)
    elseif not canaccessvalue or canaccessvalue(notInterruptible) then
        bar.LockText:SetShown(notInterruptible and true or false)
    end

    if not canaccessvalue or canaccessvalue(notInterruptible) then
        if notInterruptible then
            bar:SetStatusBarColor(0.45, 0.45, 0.45, 1)
        else
            bar:SetStatusBarColor(0.95, 0.55, 0.12, 1)
        end
    else
        bar:SetStatusBarColor(0.95, 0.55, 0.12, 1)
    end
end

local function RefreshCastbar(frame)
    local holder = frame and frame.CastbarHolder
    local bar = frame and frame.Castbar
    local unit = frame and frame.MIUF_Unit
    if not holder or not bar or not unit or not UnitExists(unit) then
        if holder then holder:Hide() end
        return
    end

    local name, displayName, _, _, _, _, _, notInterruptible = UnitCastingInfo(unit)
    local duration, direction

    if name then
        duration = UnitCastingDuration and UnitCastingDuration(unit)
        direction = Enum.StatusBarTimerDirection.ElapsedTime
    else
        local isEmpowered
        name, displayName, _, _, _, _, notInterruptible, _, isEmpowered = UnitChannelInfo(unit)
        if name then
            if isEmpowered and UnitEmpoweredChannelDuration then
                duration = UnitEmpoweredChannelDuration(unit, true)
                direction = Enum.StatusBarTimerDirection.ElapsedTime
            else
                duration = UnitChannelDuration and UnitChannelDuration(unit)
                direction = Enum.StatusBarTimerDirection.RemainingTime
            end
        end
    end

    if not name or not duration then
        holder:Hide()
        return
    end

    if displayName then
        bar.Text:SetText(displayName)
    else
        bar.Text:SetText(name)
    end

    bar:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate, direction)
    SetInterruptibleVisual(bar, notInterruptible)
    bar:Show()
    holder:Show()
end

local function CreateCastbar(frame)
    if not frame or frame.Castbar or not CASTBAR_TYPES[frame.MIUF_UnitType] then return end

    local holder = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    holder:SetHeight(18)
    holder:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -3)
    holder:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -3)
    holder:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
    holder:SetBackdropColor(0.03, 0.03, 0.03, 0.95)
    holder:SetBackdropBorderColor(0.12, 0.12, 0.12, 1)
    holder:SetFrameLevel(frame:GetFrameLevel() + 6)
    holder:Hide()

    local bar = CreateFrame("StatusBar", nil, holder)
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMRIGHT", -1, 1)
    bar:SetStatusBarTexture(ns.GetTexturePath and ns.GetTexturePath("flat") or FLAT)
    bar:SetStatusBarColor(0.95, 0.55, 0.12, 1)

    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(bar)
    background:SetColorTexture(0.08, 0.08, 0.08, 1)

    local text = bar:CreateFontString(nil, "OVERLAY")
    text:SetFont(FONT, 10, "OUTLINE")
    text:SetPoint("LEFT", 5, 0)
    text:SetPoint("RIGHT", -38, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    bar.Text = text

    local lockText = bar:CreateFontString(nil, "OVERLAY")
    lockText:SetFont(FONT, 8, "OUTLINE")
    lockText:SetPoint("RIGHT", -4, 0)
    lockText:SetText("LOCK")
    lockText:Hide()
    bar.LockText = lockText

    frame.CastbarHolder = holder
    frame.Castbar = bar

    local events = CreateFrame("Frame")
    events:RegisterUnitEvent("UNIT_SPELLCAST_START", frame.MIUF_Unit)
    events:RegisterUnitEvent("UNIT_SPELLCAST_STOP", frame.MIUF_Unit)
    events:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", frame.MIUF_Unit)
    events:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", frame.MIUF_Unit)
    events:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", frame.MIUF_Unit)
    events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", frame.MIUF_Unit)
    events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", frame.MIUF_Unit)
    events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", frame.MIUF_Unit)
    events:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_START", frame.MIUF_Unit)
    events:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_UPDATE", frame.MIUF_Unit)
    events:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP", frame.MIUF_Unit)
    events:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", frame.MIUF_Unit)
    events:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", frame.MIUF_Unit)
    events:RegisterEvent("PLAYER_ENTERING_WORLD")

    if frame.MIUF_Unit == "target" then
        events:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif frame.MIUF_Unit == "focus" then
        events:RegisterEvent("PLAYER_FOCUS_CHANGED")
    end

    events:SetScript("OnEvent", function()
        RefreshCastbar(frame)
    end)

    frame.MIUF_CastbarEvents = events
    RefreshCastbar(frame)
end

local function AttachCastbars()
    if not ns.frames then return end
    for _, frame in pairs(ns.frames) do
        CreateCastbar(frame)
    end
end

local originalSpawnAllFrames = ns.SpawnAllFrames
function ns.SpawnAllFrames(...)
    if originalSpawnAllFrames then originalSpawnAllFrames(...) end
    AttachCastbars()
end

ns.RefreshCastbars = AttachCastbars
