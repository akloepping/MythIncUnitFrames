local ADDON_NAME, ns = ...

local FLAT = "Interface\\Buttons\\WHITE8x8"
local FONT = "Fonts\\FRIZQT__.TTF"
local timeFormatter = C_StringUtil.CreateSecondsFormatter()
timeFormatter:SetDefaultAbbreviation(Enum.SecondsFormatterAbbreviation.OneLetter)
timeFormatter:SetMinInterval(Enum.SecondsFormatterInterval.Seconds)
timeFormatter:SetMillisecondsThreshold(60)

local CASTBAR_TYPES = {
    player = true,
    target = true,
    focus = true,
    boss = true,
}

local function SetInterruptibleVisual(bar, notInterruptible)
    if bar.Shield.SetAlphaFromBoolean then
        bar.Shield:SetAlphaFromBoolean(notInterruptible, 1, 0)
    elseif not canaccessvalue or canaccessvalue(notInterruptible) then
        bar.Shield:SetAlpha(notInterruptible and 1 or 0)
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

local function ClearCastbarVisuals(bar)
    if not bar then return end
    bar.Time.binding:SetToDefaults()
    bar.Time.binding:SetEnabled(false)
    bar.Time:SetText("")
    bar.Text:SetText("")
    bar.Icon:SetTexture(nil)
    bar.Shield:SetAlpha(0)
    bar.Spark:Hide()
end

local function RefreshCastbar(frame)
    local holder = frame and frame.CastbarHolder
    local bar = frame and frame.Castbar
    local unit = ns.GetFrameDisplayUnit(frame)
    if not holder or not bar or not unit or not UnitExists(unit) then
        ClearCastbarVisuals(bar)
        if holder then holder:Hide() end
        return
    end

    local name, displayName, texture, _, _, _, _, notInterruptible = UnitCastingInfo(unit)
    local duration, direction

    if name then
        duration = UnitCastingDuration and UnitCastingDuration(unit)
        direction = Enum.StatusBarTimerDirection.ElapsedTime
    else
        local isEmpowered
        name, displayName, texture, _, _, _, notInterruptible, _, isEmpowered = UnitChannelInfo(unit)
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
        ClearCastbarVisuals(bar)
        holder:Hide()
        return
    end

    if displayName then
        bar.Text:SetText(displayName)
    else
        bar.Text:SetText(name)
    end

    bar:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate, direction)
    bar.Icon:SetTexture(texture)
    local binding = bar.Time.binding
    binding:SetFontString(bar.Time)
    binding:SetFormatter(timeFormatter)
    binding:SetDuration(duration)
    binding:UpdateFontString()
    bar.Spark:Show()
    SetInterruptibleVisual(bar, notInterruptible)
    bar:Show()
    holder:Show()
    binding:SetEnabled(holder:IsVisible())
end

ns.UpdateFrameCastbar = RefreshCastbar

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
    bar:SetPoint("TOPLEFT", 19, -1)
    bar:SetPoint("BOTTOMRIGHT", -1, 1)
    bar:SetStatusBarTexture(ns.GetTexturePath and ns.GetTexturePath("flat") or FLAT)
    bar:SetStatusBarColor(0.95, 0.55, 0.12, 1)

    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(bar)
    background:SetColorTexture(0.08, 0.08, 0.08, 1)

    local icon = holder:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", holder, "LEFT", 1, 0)
    bar.Icon = icon

    local shield = bar:CreateTexture(nil, "OVERLAY")
    shield:SetAtlas("ui-castingbar-shield", false)
    shield:SetSize(14, 16)
    shield:SetPoint("RIGHT", -1, 0)
    shield:SetAlpha(0)
    bar.Shield = shield

    local timer = bar:CreateFontString(nil, "OVERLAY")
    timer:SetFont(FONT, 9, "OUTLINE")
    timer:SetSize(40, 16)
    timer:SetPoint("RIGHT", shield, "LEFT", -2, 0)
    timer:SetJustifyH("RIGHT")
    timer:SetWordWrap(false)
    timer.binding = C_DurationUtil.CreateDurationTextBinding()
    timer.binding:SetEnabled(false)
    bar.Time = timer

    -- Follow the native fill edge without inspecting restricted progress values.
    local spark = bar:CreateTexture(nil, "ARTWORK")
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    spark:SetBlendMode("ADD")
    spark:SetSize(6, 16)
    spark:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT", 0, 0)
    spark:Hide()
    bar.Spark = spark

    local text = bar:CreateFontString(nil, "OVERLAY")
    text:SetFont(FONT, 10, "OUTLINE")
    text:SetPoint("LEFT", 5, 0)
    text:SetPoint("RIGHT", timer, "LEFT", -4, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    bar.Text = text

    holder:SetScript("OnHide", function() timer.binding:SetEnabled(false) end)
    holder:SetScript("OnShow", function()
        timer.binding:SetEnabled(true)
        timer.binding:UpdateFontString()
    end)

    frame.CastbarHolder = holder
    frame.Castbar = bar

    local events = CreateFrame("Frame")
    ns.RegisterFrameUnitEvent(events, "UNIT_SPELLCAST_START", frame)
    ns.RegisterFrameUnitEvent(events, "UNIT_SPELLCAST_STOP", frame)
    ns.RegisterFrameUnitEvent(events, "UNIT_SPELLCAST_FAILED", frame)
    ns.RegisterFrameUnitEvent(events, "UNIT_SPELLCAST_INTERRUPTED", frame)
    ns.RegisterFrameUnitEvent(events, "UNIT_SPELLCAST_DELAYED", frame)
    ns.RegisterFrameUnitEvent(events, "UNIT_SPELLCAST_CHANNEL_START", frame)
    ns.RegisterFrameUnitEvent(events, "UNIT_SPELLCAST_CHANNEL_UPDATE", frame)
    ns.RegisterFrameUnitEvent(events, "UNIT_SPELLCAST_CHANNEL_STOP", frame)
    ns.RegisterFrameUnitEvent(events, "UNIT_SPELLCAST_EMPOWER_START", frame)
    ns.RegisterFrameUnitEvent(events, "UNIT_SPELLCAST_EMPOWER_UPDATE", frame)
    ns.RegisterFrameUnitEvent(events, "UNIT_SPELLCAST_EMPOWER_STOP", frame)
    ns.RegisterFrameUnitEvent(events, "UNIT_SPELLCAST_INTERRUPTIBLE", frame)
    ns.RegisterFrameUnitEvent(events, "UNIT_SPELLCAST_NOT_INTERRUPTIBLE", frame)
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
