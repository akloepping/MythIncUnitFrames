local ADDON_NAME, ns = ...
local oUF = _G.oUF
if not oUF then error(ADDON_NAME .. " requires the standalone oUF addon.") end

local FLAT = "Interface\\Buttons\\WHITE8x8"
local BLIZZARD = "Interface\\TargetingFrame\\UI-StatusBar"
local FONT = "Fonts\\FRIZQT__.TTF"
local FONTS = {
    friz = "Fonts\\FRIZQT__.TTF",
    arial = "Fonts\\ARIALN.TTF",
    morpheus = "Fonts\\MORPHEUS.TTF",
    skurri = "Fonts\\SKURRI.TTF",
}

local TEXTURES = { flat = FLAT, blizzard = BLIZZARD }
local HEALTH_COLORS = {
    green = { 0.18, 0.72, 0.28 }, blue = { 0.20, 0.48, 0.85 },
    gray = { 0.48, 0.50, 0.52 }, red = { 0.78, 0.22, 0.22 },
}
local POWER_COLORS = {
    blue = { 0.20, 0.45, 0.90 }, purple = { 0.55, 0.28, 0.85 }, gray = { 0.45, 0.47, 0.50 },
}

local function UnitType(unit)
    if unit:match("^party%d+$") then return "party" end
    if unit:match("^boss%d+$") then return "boss" end
    return unit
end

local function CreateBackground(parent)
    local bg = parent:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(parent)
    bg:SetColorTexture(0.03, 0.03, 0.03, 0.92)
    return bg
end

local function CreateBorder(parent)
    local border = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    border:SetPoint("TOPLEFT", -1, 1); border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetBackdrop({ edgeFile = FLAT, edgeSize = 1 })
    border:SetBackdropBorderColor(0.1, 0.1, 0.1, 1)
    border:SetFrameLevel(parent:GetFrameLevel() + 5)
    return border
end

local function CreateCastbar(self)
    local castbar = CreateFrame("StatusBar", nil, self)
    castbar:SetStatusBarTexture(FLAT); castbar:SetStatusBarColor(0.85, 0.65, 0.15, 1)
    castbar:SetHeight(18); castbar:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -5); castbar:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, -5)
    local bg = castbar:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.04, 0.04, 0.04, 0.95)
    local text = castbar:CreateFontString(nil, "OVERLAY"); text:SetFont(FONT, 10, "OUTLINE"); text:SetPoint("LEFT", 4, 0); text:SetPoint("RIGHT", -36, 0); text:SetJustifyH("LEFT"); text:SetWordWrap(false)
    local time = castbar:CreateFontString(nil, "OVERLAY"); time:SetFont(FONT, 10, "OUTLINE"); time:SetPoint("RIGHT", -4, 0); time:SetJustifyH("RIGHT")
    local icon = castbar:CreateTexture(nil, "ARTWORK"); icon:SetSize(18, 18); icon:SetPoint("RIGHT", castbar, "LEFT", -2, 0); icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    castbar.Text = text; castbar.Time = time; castbar.Icon = icon; castbar.timeToHold = 0.35; self.Castbar = castbar
end

local function CreateRaidTargetIndicator(self)
    local icon = self:CreateTexture(nil, "OVERLAY"); icon:SetSize(20, 20); icon:SetPoint("CENTER", self, "TOP", 0, 2); self.RaidTargetIndicator = icon
end
local function CreateRoleIndicator(self)
    local role = self:CreateTexture(nil, "OVERLAY"); role:SetSize(14, 14); role:SetPoint("TOPLEFT", self, "TOPLEFT", 3, -3); self.GroupRoleIndicator = role
end

local function GetAuraAnchor(layout)
    local anchor = layout.anchor == "BOTTOM" and "BOTTOM" or "TOP"
    local growth = layout.growth == "LEFT" and "LEFT" or "RIGHT"
    if anchor == "TOP" then
        if growth == "LEFT" then return "BOTTOMRIGHT", "TOPRIGHT", "TOPRIGHT", "LEFT", "DOWN" end
        return "BOTTOMLEFT", "TOPLEFT", "TOPLEFT", "RIGHT", "DOWN"
    end
    if growth == "LEFT" then return "TOPRIGHT", "BOTTOMRIGHT", "TOPRIGHT", "LEFT", "DOWN" end
    return "TOPLEFT", "BOTTOMLEFT", "TOPLEFT", "RIGHT", "DOWN"
end

local AURA_LABELS = { buffs = "Buffs", debuffs = "Debuffs", defensives = "Defensives" }
local AURA_FIELDS = { buffs = "PlayerBuffs", debuffs = "CombatDebuffs", defensives = "ExternalDefensives" }

local function ApplyAuraAnchorPosition(frame, auraType)
    local field = AURA_FIELDS[auraType]
    local container = field and frame[field]
    local anchor = container and container.MIUF_Anchor
    if not anchor then return end

    local layout = ns.GetAuraLayout(frame.MIUF_UnitType, auraType)
    if not layout then return end
    local point, relativePoint = GetAuraAnchor(layout)
    anchor:ClearAllPoints()
    anchor:SetPoint(point, frame, relativePoint, layout.xOffset or 0, layout.yOffset or 0)
end

local function SaveDraggedAuraPosition(frame, auraType, anchor)
    local layout = ns.GetAuraLayout(frame.MIUF_UnitType, auraType)
    if not layout then return end

    local point, relativePoint = GetAuraAnchor(layout)
    local x, y = 0, 0
    if point == "BOTTOMLEFT" and relativePoint == "TOPLEFT" then
        x = (anchor:GetLeft() or 0) - (frame:GetLeft() or 0)
        y = (anchor:GetBottom() or 0) - (frame:GetTop() or 0)
    elseif point == "BOTTOMRIGHT" and relativePoint == "TOPRIGHT" then
        x = (anchor:GetRight() or 0) - (frame:GetRight() or 0)
        y = (anchor:GetBottom() or 0) - (frame:GetTop() or 0)
    elseif point == "TOPLEFT" and relativePoint == "BOTTOMLEFT" then
        x = (anchor:GetLeft() or 0) - (frame:GetLeft() or 0)
        y = (anchor:GetTop() or 0) - (frame:GetBottom() or 0)
    elseif point == "TOPRIGHT" and relativePoint == "BOTTOMRIGHT" then
        x = (anchor:GetRight() or 0) - (frame:GetRight() or 0)
        y = (anchor:GetTop() or 0) - (frame:GetBottom() or 0)
    end

    ns.SaveAuraLayout(frame.MIUF_UnitType, auraType, {
        xOffset = math.floor(x + (x >= 0 and 0.5 or -0.5)),
        yOffset = math.floor(y + (y >= 0 and 0.5 or -0.5)),
    })

    -- Re-anchor every frame of this type so party/boss-style groups stay consistent.
    if ns.frames then
        for _, other in pairs(ns.frames) do
            if other.MIUF_UnitType == frame.MIUF_UnitType then
                ApplyAuraAnchorPosition(other, auraType)
            end
        end
    else
        ApplyAuraAnchorPosition(frame, auraType)
    end

    if ns.RefreshConfig then ns.RefreshConfig() end
end

function ns.ApplyAuraPositions(unitType, auraType)
    if InCombatLockdown() then return end
    if not ns.frames then return end
    for _, frame in pairs(ns.frames) do
        if frame.MIUF_UnitType == unitType then
            ApplyAuraAnchorPosition(frame, auraType)
        end
    end
end

-- Preview icon size without rebuilding the protected aura groups. WoW 12.1's
-- AuraContainer owns its AuraButtons, so use SetAuraGroupLayout to resize the
-- group's managed buttons and reflow them in place. The persisted value is still
-- staged by Config.lua and only becomes permanent when Apply Changes is used.
function ns.PreviewAuraIconSize(unitType, auraType, iconSize)
    if InCombatLockdown() then return end
    if not ns.frames then return end

    local field = AURA_FIELDS[auraType]
    if not field then return end

    iconSize = math.max(1, tonumber(iconSize) or 16)
    local layout = ns.GetAuraLayout(unitType, auraType)
    local spacing = (layout and layout.spacing) or 0

    for _, frame in pairs(ns.frames) do
        if frame.MIUF_UnitType == unitType then
            local container = frame[field]
            if container then
                -- Keep oUF's default for any buttons created later in this session.
                container.size = iconSize

                -- Resize the managed group that already exists. This updates the
                -- visible buttons immediately and asks AuraContainer to reflow them.
                if container.MIUF_GroupKey and container.SetAuraGroupLayout then
                    container:SetAuraGroupLayout(container.MIUF_GroupKey, {
                        elementWidth = iconSize,
                        elementHeight = iconSize,
                        elementSpacing = spacing,
                        lineSpacing = spacing,
                    })
                end

                -- The ordinary MIUF anchor also drives the purple mover bounds.
                if container.MIUF_Anchor then
                    container.MIUF_Anchor:SetHeight((iconSize * 2) + spacing + 4)
                end
            end
        end
    end
end

local function CreateAuraMover(self, auraType, container)
    local anchor = container and container.MIUF_Anchor
    if not anchor then return end
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)

    local mover = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    mover:SetFrameStrata("DIALOG")
    mover:SetAllPoints(anchor)
    mover:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
    mover:SetBackdropColor(0.35, 0.18, 0.65, 0.24)
    mover:SetBackdropBorderColor(0.75, 0.45, 1, 1)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")

    local label = mover:CreateFontString(nil, "OVERLAY")
    label:SetFont(FONT, 10, "OUTLINE")
    label:SetPoint("CENTER")
    if self.MIUF_UnitType == "party" then
        label:SetText("Party " .. (AURA_LABELS[auraType] or auraType))
    else
        label:SetText((self.__unit or self.MIUF_UnitType) .. " " .. (AURA_LABELS[auraType] or auraType))
    end

    mover:SetScript("OnDragStart", function()
        if not InCombatLockdown() then anchor:StartMoving() end
    end)
    mover:SetScript("OnDragStop", function()
        anchor:StopMovingOrSizing()
        if InCombatLockdown() then return end
        SaveDraggedAuraPosition(self, auraType, anchor)
    end)
    mover:Hide()

    self.MIUF_AuraMovers = self.MIUF_AuraMovers or {}
    self.MIUF_AuraMovers[auraType] = mover
end

local function CreateAuraContainer(self, width, filter, borderDebuffs, layout, candidateFilters)
    local point, relativePoint, initialAnchor, growthX, growthY = GetAuraAnchor(layout)

    -- Keep positioning outside Blizzard's protected AuraContainer. The anchor is an
    -- ordinary MIUF frame that we are free to place relative to the unit frame; the
    -- AuraContainer only handles protected aura filtering and icon flow inside it.
    local anchor = CreateFrame("Frame", nil, self)
    anchor:SetSize(width, (layout.iconSize * 2) + (layout.spacing or 0) + 4)
    anchor:SetPoint(point, self, relativePoint, layout.xOffset or 0, layout.yOffset or 0)

    local auras = self:CreateAuras({
        initialAnchor = initialAnchor,
        growthX = growthX,
        growthY = growthY,
        layoutLimit = width,
    })
    auras:SetAllPoints(anchor)
    auras.MIUF_Anchor = anchor
    auras.size = layout.iconSize
    auras.elementSpacing = layout.spacing
    auras.lineSpacing = layout.spacing
    -- Aura text is optional. When disabled we suppress both stack counts and
    -- Blizzard's built-in cooldown countdown numbers while keeping the cooldown
    -- swipe itself intact.
    auras.MIUF_ShowText = layout.showText ~= false
    auras.showCount = auras.MIUF_ShowText
    auras.PostCreateButton = function(element, button)
        if button and button.Cooldown and button.Cooldown.SetHideCountdownNumbers then
            button.Cooldown:SetHideCountdownNumbers(not element.MIUF_ShowText)
        end
    end
    -- Blizzard protected AuraButtons already render cooldown duration text.
    -- Do not add oUF's legacy duration text on top of it.
    auras.showDuration = false
    auras.showDebuffBorder = borderDebuffs and true or false
    auras.disableMouse = false
    auras.MIUF_GroupKey = auras:AddGroup(filter, { maxFrameCount = layout.maxCount, candidateFilters = candidateFilters })
    return auras
end

local function CreateDispelHighlight(self)
    local container = self:CreateAuras({ initialAnchor = "TOPLEFT" }); container:SetAllPoints(self)
    container:AddSlot("HARMFUL|RAID", {
        initializeFrame = function(button)
            -- This AuraButton exists only so Blizzard's protected aura system can
            -- classify the dispel type. Keep the actual aura button effectively
            -- invisible and render the result as a frame-sized border instead.
            button:SetSize(1, 1)
            button:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
            button:EnableMouse(false)

            local function AddEdge(point1, relPoint1, x1, y1, point2, relPoint2, x2, y2, r, g, b, layer)
                local edge = button:CreateTexture(nil, "OVERLAY", nil, layer or 7)
                edge:SetColorTexture(r or 1, g or 1, b or 1, 1)
                edge:SetPoint(point1, self, relPoint1, x1, y1)
                edge:SetPoint(point2, self, relPoint2, x2, y2)

                -- PreserveAsset keeps our rectangular edge while Blizzard owns
                -- the protected show/hide + dispel-color decision.  Black edges
                -- remain black under vertex coloring, so they can provide a
                -- contrast outline behind the colored dispel border.
                button:AddDispelTypeTexture(edge, {
                    style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
                    showWhenHarmful = true,
                    customDispelColorMap = oUF.colors.dispel,
                })
                return edge
            end

            local thickness = 5
            local outline = 1
            local outerThickness = thickness + (outline * 2)

            -- A one-pixel black outline sits behind and slightly outside the
            -- five-pixel colored border.  Both are driven by the same protected
            -- dispel state, and unlike the old full-frame shade this does not
            -- obscure the health/power bars or text.
            local black = {
                top = AddEdge("TOPLEFT", "TOPLEFT", -outline, outline, "TOPRIGHT", "TOPRIGHT", outline, -(outerThickness - outline), 0, 0, 0, 6),
                bottom = AddEdge("BOTTOMLEFT", "BOTTOMLEFT", -outline, outerThickness - outline, "BOTTOMRIGHT", "BOTTOMRIGHT", outline, -outline, 0, 0, 0, 6),
                left = AddEdge("TOPLEFT", "TOPLEFT", -outline, -(outerThickness - outline), "BOTTOMLEFT", "BOTTOMLEFT", outerThickness - outline, outerThickness - outline, 0, 0, 0, 6),
                right = AddEdge("TOPRIGHT", "TOPRIGHT", -(outerThickness - outline), -(outerThickness - outline), "BOTTOMRIGHT", "BOTTOMRIGHT", outline, outerThickness - outline, 0, 0, 0, 6),
            }

            button.DispelHighlight = {
                outline = black,
                top = AddEdge("TOPLEFT", "TOPLEFT", 0, 0, "TOPRIGHT", "TOPRIGHT", 0, -thickness, 1, 1, 1, 7),
                bottom = AddEdge("BOTTOMLEFT", "BOTTOMLEFT", 0, thickness, "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0, 1, 1, 1, 7),
                left = AddEdge("TOPLEFT", "TOPLEFT", 0, -thickness, "BOTTOMLEFT", "BOTTOMLEFT", thickness, thickness, 1, 1, 1, 7),
                right = AddEdge("TOPRIGHT", "TOPRIGHT", -thickness, -thickness, "BOTTOMRIGHT", "BOTTOMRIGHT", 0, thickness, 1, 1, 1, 7),
            }
        end,
    })
    self.DispelAuras = container
end

-- Normal buffs are opt-in.  The protected container still starts with the
-- broad player-applied pool, then Blizzard's spell-ID candidate filter limits display
-- to spell IDs the user explicitly chose to track.
local function GetPlayerBuffCandidateFilters()
    local included = ns.GetTrackedBuffSpellIDs and ns.GetTrackedBuffSpellIDs() or {}
    -- Keep an impossible sentinel so an empty tracked list means "show none"
    -- rather than accidentally behaving like no identity filter was supplied.
    if not next(included) then included[0] = true end
    return { includeSpellIDs = included }
end

local function RecordSeenAura(_, unit, button, data)
    if not data or not ns.RecordSeenBuff then return end
    pcall(function()
        local spellID = tonumber(data.spellId)
        if spellID then ns.RecordSeenBuff(spellID, data.name, data.icon) end
    end)
end

local function CreateBuffDiscoveryContainer(self, width)
    -- A visually hidden protected group observes HELPFUL|PLAYER so MIUF can
    -- build a simple Seen Buffs catalog even when the visible group is whitelist-only.
    local anchor = CreateFrame("Frame", nil, self)
    anchor:SetSize(width, 1)
    anchor:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
    anchor:SetAlpha(0)
    local auras = self:CreateAuras({ initialAnchor = "TOPLEFT", growthX = "RIGHT", growthY = "DOWN", layoutLimit = width })
    auras:SetAllPoints(anchor)
    auras.size = 1
    auras.elementSpacing = 0
    auras.lineSpacing = 0
    auras.disableMouse = true
    auras.disableCooldown = true
    auras.showCount = false
    auras.showDuration = false
    auras.PostUpdateButton = RecordSeenAura
    auras:AddGroup("HELPFUL|PLAYER", { maxFrameCount = 40 })
    return auras
end

local function CreateProtectedAuras(self, unitType, width)
    -- Boss frames intentionally stay aura-free: encounter auras belong on player/group/target frames.
    if unitType == "boss" then return end

    local buffs = ns.GetAuraLayout(unitType, "buffs")
    if (unitType == "player" or unitType == "target" or unitType == "focus" or unitType == "party" or unitType == "targettarget") and buffs and buffs.enabled ~= false then
        self.PlayerBuffs = CreateAuraContainer(self, width, "HELPFUL|PLAYER", false, buffs, GetPlayerBuffCandidateFilters())
        self.MIUF_BuffDiscovery = CreateBuffDiscoveryContainer(self, width)
    end
    local debuffs = ns.GetAuraLayout(unitType, "debuffs")
    if unitType ~= "pet" and debuffs and debuffs.enabled ~= false then
        self.CombatDebuffs = CreateAuraContainer(self, width, "HARMFUL|RAID_IN_COMBAT", true, debuffs)
    end
    local defensives = ns.GetAuraLayout(unitType, "defensives")
    if (unitType == "player" or unitType == "party") and defensives and defensives.enabled ~= false then
        self.ExternalDefensives = CreateAuraContainer(self, width, "HELPFUL|EXTERNAL_DEFENSIVE", false, defensives)
    end
    if unitType == "player" or unitType == "party" or unitType == "focus" then CreateDispelHighlight(self) end
end

local function CreateMover(self, unit)
    self:SetMovable(true); self:SetClampedToScreen(true)
    local mover = CreateFrame("Frame", nil, UIParent, "BackdropTemplate"); mover:SetFrameStrata("DIALOG"); mover:SetAllPoints(self)
    mover:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 }); mover:SetBackdropColor(0.05, 0.35, 0.8, 0.28); mover:SetBackdropBorderColor(0.2, 0.65, 1, 1)
    mover:EnableMouse(true); mover:RegisterForDrag("LeftButton")
    local label = mover:CreateFontString(nil, "OVERLAY"); label:SetFont(FONT, 11, "OUTLINE"); label:SetPoint("CENTER"); label:SetText(unit == "party1" and "Party Group" or (unit == "boss1" and "Boss Group" or unit))
    mover:SetScript("OnDragStart", function() if not InCombatLockdown() then self:StartMoving() end end)
    mover:SetScript("OnDragStop", function()
        self:StopMovingOrSizing(); if InCombatLockdown() then return end
        local point, _, relativePoint, x, y = self:GetPoint(1)
        ns.SavePosition(unit, point or "CENTER", relativePoint or point or "CENTER", x or 0, y or 0)
        if unit == "party1" and ns.ApplyPartyLayout then ns.ApplyPartyLayout() end
        if unit == "boss1" and ns.ApplyBossLayout then ns.ApplyBossLayout() end
    end)

    -- Bottom-right proportional resize handle. The handle is part of the mover,
    -- so it is only available while frame movers are unlocked. Resizing is
    -- intentionally out-of-combat only because oUF unit frames are protected.
    local resize = CreateFrame("Button", nil, mover, "BackdropTemplate")
    resize:SetSize(14, 14)
    resize:SetPoint("BOTTOMRIGHT", mover, "BOTTOMRIGHT", 0, 0)
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
        local unitType = self.MIUF_UnitType
        local left, top = self:GetLeft(), self:GetTop()
        if not left or not top then return end

        local startW, startH = self:GetWidth(), self:GetHeight()
        local aspect = startW / math.max(1, startH)
        local minW = math.max(100, 24 * aspect)
        local maxW = math.min(600, 150 * aspect)
        if minW > maxW then minW, maxW = startW, startW end

        resize.MIUF_ResizeState = {
            unitType = unitType, left = left, top = top,
            startW = startW, startH = startH, aspect = aspect,
            minW = minW, maxW = maxW,
        }

        -- Pin the visual top-left corner while the bottom-right handle moves.
        -- The resulting position is saved on release, so there is no jump when
        -- the frame returns to normal mover behavior.
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)

        resize:SetScript("OnUpdate", function(handle)
            local state = handle.MIUF_ResizeState
            if not state or InCombatLockdown() then return end
            local scale = UIParent:GetEffectiveScale()
            local cursorX, cursorY = GetCursorPosition()
            cursorX, cursorY = cursorX / scale, cursorY / scale

            local rawW = math.max(1, cursorX - state.left)
            local rawH = math.max(1, state.top - cursorY)
            local dw = math.abs(rawW - state.startW) / math.max(1, state.startW)
            local dh = math.abs(rawH - state.startH) / math.max(1, state.startH)
            local width = (dw >= dh) and rawW or (rawH * state.aspect)
            width = math.max(state.minW, math.min(state.maxW, width))
            local height = width / state.aspect

            if ns.PreviewFrameSize then ns.PreviewFrameSize(state.unitType, width, height) end
        end)
    end)

    resize:SetScript("OnMouseUp", function(handle, button)
        if button ~= "LeftButton" then return end
        local state = handle.MIUF_ResizeState
        handle:SetScript("OnUpdate", nil)
        handle.MIUF_ResizeState = nil
        if not state or InCombatLockdown() then return end

        local width, height = self:GetWidth(), self:GetHeight()
        ns.SaveSize(state.unitType, width, height)
        local point, _, relativePoint, x, y = self:GetPoint(1)
        ns.SavePosition(unit, point or "TOPLEFT", relativePoint or point or "BOTTOMLEFT", x or 0, y or 0)
        if ns.ApplyFrameType then ns.ApplyFrameType(state.unitType) end
        if state.unitType == "party" and ns.ApplyPartyLayout then ns.ApplyPartyLayout() end
        if state.unitType == "boss" and ns.ApplyBossLayout then ns.ApplyBossLayout() end
        if ns.RefreshConfig then ns.RefreshConfig() end
    end)

    mover.MIUF_ResizeHandle = resize
    mover:Hide(); self.MIUF_Mover = mover
end

local function CreatePortrait(self)
    local portrait = self:CreateTexture(nil, "ARTWORK")
    portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- WoW 12.1 can return secret booleans from unit identity/visibility checks in combat.
    -- oUF 14.0.2's default Portrait update path compares event units before updating,
    -- which can trigger a secret-value boolean error for units such as targettarget.
    -- Our override deliberately avoids all boolean/unit-identity tests and simply asks
    -- Blizzard to refresh this frame's portrait from its own current oUF unit token.
    portrait.Override = function(frame)
        local element = frame.Portrait
        local activeUnit = frame.__unit
        if element and activeUnit then
            SetPortraitTexture(element, activeUnit)
        end
    end

    self.Portrait = portrait
end

local function Style(self, unit)
    local unitType = self.MIUF_ForcedUnitType or UnitType(unit); local configuredSize = ns.GetSize(unitType)
    self.MIUF_UnitType = unitType; self:SetSize(configuredSize.width, configuredSize.height); self:RegisterForClicks("AnyUp")
    self:SetScript("OnEnter", function(frame)
        GameTooltip_SetDefaultAnchor(GameTooltip, frame)
        if frame.__unit then GameTooltip:SetUnit(frame.__unit) end
    end)
    self:SetScript("OnLeave", function() GameTooltip:Hide() end)

    self.Background = CreateBackground(self); self.Border = CreateBorder(self)
    local health = CreateFrame("StatusBar", nil, self); health:SetStatusBarTexture(FLAT); health.frequentUpdates = true
    local healthBG = health:CreateTexture(nil, "BACKGROUND"); healthBG:SetAllPoints(health); healthBG:SetColorTexture(0.08, 0.08, 0.08, 1); health.bg = healthBG; health.bg.multiplier = 0.25
    self.Health = health
    local power = CreateFrame("StatusBar", nil, self); power:SetStatusBarTexture(FLAT); power.frequentUpdates = true
    local powerBG = power:CreateTexture(nil, "BACKGROUND"); powerBG:SetAllPoints(power); powerBG:SetColorTexture(0.05, 0.05, 0.05, 1); self.Power = power

    -- oUF can evaluate tags immediately while Spawn() is still constructing the frame.
    -- Give the FontStrings a valid font before registering tags; ApplyFrame() will
    -- replace these with the user's saved font sizes immediately after spawning.
    local name = health:CreateFontString(nil, "OVERLAY"); name:SetFont(FONT, 12, "OUTLINE"); name:SetJustifyH("LEFT"); name:SetWordWrap(false); self:Tag(name, "[name]"); self.NameText = name
    local healthText = health:CreateFontString(nil, "OVERLAY"); healthText:SetFont(FONT, 11, "OUTLINE"); healthText:SetJustifyH("RIGHT"); self:Tag(healthText, "[perhp<$%]"); self.HealthText = healthText

    CreatePortrait(self); CreateRaidTargetIndicator(self)
    if unitType == "player" or unitType == "party" then CreateRoleIndicator(self) end
    if unitType == "player" or unitType == "target" or unitType == "focus" then CreateCastbar(self) end
    CreateProtectedAuras(self, unitType, configuredSize.width)
    if self.PlayerBuffs then CreateAuraMover(self, "buffs", self.PlayerBuffs) end
    if self.CombatDebuffs then CreateAuraMover(self, "debuffs", self.CombatDebuffs) end
    if self.ExternalDefensives then CreateAuraMover(self, "defensives", self.ExternalDefensives) end
    CreateMover(self, unit)
end

oUF:RegisterStyle("MythIncUnitFrames", Style)
oUF:RegisterStyle("MythIncUnitFramesPartyPlayer", function(self, unit)
    self.MIUF_ForcedUnitType = "party"
    Style(self, unit)
end)
oUF:SetActiveStyle("MythIncUnitFrames")
local frames = {}; ns.frames = frames
local previewEnabled = {}

local function ApplyPosition(unit, frame)
    local p = ns.GetPosition(unit); if not p then return end
    frame:ClearAllPoints(); frame:SetPoint(p.point, UIParent, p.relativePoint, p.x, p.y)
end
local function Spawn(unit, name, key, style)
    if style then oUF:SetActiveStyle(style) end
    local frame = oUF:Spawn(unit, name)
    if style then oUF:SetActiveStyle("MythIncUnitFrames") end
    frames[key or unit] = frame
    if not key or key == unit then ApplyPosition(unit, frame) end
    return frame
end

local function AnchorGroupFrames(ordered, layout, positionKey)
    if #ordered == 0 then return nil end

    local first = ordered[1]
    local position = ns.GetPosition(positionKey)
    if position then
        first:ClearAllPoints()
        first:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
    end

    local previous = first
    local spacing = layout.spacing or 0
    for index = 2, #ordered do
        local frame = ordered[index]
        frame:ClearAllPoints()
        if layout.orientation == "HORIZONTAL" then
            if layout.direction == "LEFT" then
                frame:SetPoint("TOPRIGHT", previous, "TOPLEFT", -spacing, 0)
            else
                frame:SetPoint("TOPLEFT", previous, "TOPRIGHT", spacing, 0)
            end
        elseif layout.direction == "UP" then
            frame:SetPoint("BOTTOMLEFT", previous, "TOPLEFT", 0, spacing)
        else
            frame:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -spacing)
        end
        previous = frame
    end
    return first
end

local function ApplyPartyLayout()
    if InCombatLockdown() then return end
    local layout = ns.GetGroupLayout("party")
    if not layout then return end

    -- Secure state drivers own party-frame visibility.  Layout code only
    -- determines which existing frames participate and where they are anchored.
    if not IsInGroup() or IsInRaid() then
        ns.partyAuraMoverOwner = nil
        return
    end

    local ordered = {}
    for i = 1, 4 do
        local unit = "party" .. i
        local frame = frames[unit]
        if frame and UnitExists(unit) then table.insert(ordered, frame) end
    end
    if layout.includePlayer and frames.partyplayer then
        table.insert(ordered, frames.partyplayer)
    end

    -- Party is a shared template.  The first active party-style frame owns the
    -- representative aura movers; all party frames use the same saved layout.
    ns.partyAuraMoverOwner = AnchorGroupFrames(ordered, layout, "party1")
    if ns.partyAuraMoverOwner and ns.SetAuraMoversLocked and ns.AreAuraMoversLocked then
        ns.SetAuraMoversLocked(ns.AreAuraMoversLocked())
    end
end

function ns.ApplyPartyLayout()
    ApplyPartyLayout()
end

local function ApplyBossLayout()
    if InCombatLockdown() then return end
    local layout = ns.GetGroupLayout("boss")
    if not layout then return end

    local ordered = {}
    for i = 1, 5 do
        local frame = frames["boss" .. i]
        if frame then table.insert(ordered, frame) end
    end
    AnchorGroupFrames(ordered, layout, "boss1")
end

function ns.ApplyBossLayout()
    ApplyBossLayout()
end

-- Spawn only after ADDON_LOADED, once SavedVariables have been restored.
-- Spawning while Lua files are still executing can read an empty DB and recreate
-- defaults before WoW has finished loading MythIncUnitFramesDB.
local framesSpawned = false
function ns.SpawnAllFrames()
    if framesSpawned then return end
    framesSpawned = true

    if ns.IsFrameTypeEnabled("player") then Spawn("player", "MIUF_Player") end
    if ns.IsFrameTypeEnabled("target") then Spawn("target", "MIUF_Target") end
    if ns.IsFrameTypeEnabled("targettarget") then Spawn("targettarget", "MIUF_TargetTarget") end
    if ns.IsFrameTypeEnabled("focus") then Spawn("focus", "MIUF_Focus") end
    if ns.IsFrameTypeEnabled("pet") then Spawn("pet", "MIUF_Pet") end
    if ns.IsFrameTypeEnabled("party") then
        -- Party frames are a group UI, not an alternate solo player frame.
        -- Use a secure visibility driver so every party-style frame disappears
        -- while solo (and in raid) and comes back automatically in a party.
        for i = 1, 4 do
            local frame = Spawn("party" .. i, "MIUF_Party" .. i)
            RegisterStateDriver(frame, "visibility", "[group:party] show; hide")
        end
        local partyLayout = ns.GetGroupLayout("party")
        if partyLayout and partyLayout.includePlayer then
            local frame = Spawn("player", "MIUF_PartyPlayer", "partyplayer", "MythIncUnitFramesPartyPlayer")
            -- oUF automatically registers every spawned unit frame with UnitWatch.
            -- That is correct for party1-party4, but this duplicate frame watches
            -- the always-existing "player" unit.  If UnitWatch remains active it
            -- can re-show the frame after the party state driver hides it when the
            -- group ends.  This frame is party UI, so its visibility belongs only
            -- to the secure party state driver below.
            UnregisterUnitWatch(frame)
            RegisterStateDriver(frame, "visibility", "[group:party] show; hide")
        end
    end
    if ns.IsFrameTypeEnabled("boss") then for i = 1, 5 do Spawn("boss" .. i, "MIUF_Boss" .. i) end end
    ApplyPartyLayout()
    ApplyBossLayout()

    -- Style creation intentionally uses only safe bootstrap values for anything
    -- oUF may touch during Spawn(). Once all frames exist, apply the complete
    -- persisted appearance/layout and the saved mover lock states.
    for unitType in pairs(ns.defaultSizes) do
        if ns.ApplyFrameType then ns.ApplyFrameType(unitType) end
    end
    if ns.SetFrameMoversLocked then ns.SetFrameMoversLocked(ns.AreFrameMoversLocked()) end
    if ns.SetAuraMoversLocked then ns.SetAuraMoversLocked(ns.AreAuraMoversLocked()) end
end

local function ResizeAuraContainer(container, width)
    if not container then return end
    if container.MIUF_Anchor then
        container.MIUF_Anchor:SetWidth(width)
    else
        container:SetWidth(width)
    end
    if container.SetFlowLayoutMaximumLineSize then container:SetFlowLayoutMaximumLineSize(width) end
end

local function ApplyColorModes(frame, appearance)
    local health = frame.Health
    health.colorClass = false; health.colorReaction = false; health.colorDisconnected = true; health.colorTapping = true; health.colorHealth = false
    if appearance.healthColor == "automatic" then
        health.colorClass = true; health.colorReaction = true; health.colorHealth = true
        if health.ForceUpdate then health:ForceUpdate() end
    else
        local c = HEALTH_COLORS[appearance.healthColor] or HEALTH_COLORS.green
        health:SetStatusBarColor(c[1], c[2], c[3], 1)
    end
    local power = frame.Power; power.colorPower = false
    if appearance.powerColor == "automatic" then
        power.colorPower = true; if power.ForceUpdate then power:ForceUpdate() end
    else
        local c = POWER_COLORS[appearance.powerColor] or POWER_COLORS.blue
        power:SetStatusBarColor(c[1], c[2], c[3], 1)
    end
end

local function ApplyFrame(frame, sizeOverride)
    local unitType = frame.MIUF_UnitType; local size = sizeOverride or ns.GetSize(unitType); local appearance = ns.GetAppearance(unitType)
    local width, height = size.width, size.height; frame:SetSize(width, height)
    local texture = TEXTURES[appearance.texture] or FLAT
    frame.Health:SetStatusBarTexture(texture); frame.Power:SetStatusBarTexture(texture)
    if frame.Castbar then frame.Castbar:SetStatusBarTexture(texture) end
    frame.Background:SetColorTexture(0.03, 0.03, 0.03, appearance.backgroundOpacity / 100)
    frame.Border:SetBackdropBorderColor(0.1, 0.1, 0.1, appearance.borderOpacity / 100)

    local portraitWidth = 0
    if appearance.showPortrait then portraitWidth = math.max(18, math.floor(width * (appearance.portraitPercent / 100))) end
    frame.Portrait:ClearAllPoints()
    if appearance.showPortrait then
        frame.Portrait:SetWidth(portraitWidth); frame.Portrait:SetPoint("TOP", frame, "TOP", 0, -2); frame.Portrait:SetPoint("BOTTOM", frame, "BOTTOM", 0, 2)
        if appearance.portraitSide == "RIGHT" then frame.Portrait:SetPoint("RIGHT", frame, "RIGHT", -2, 0) else frame.Portrait:SetPoint("LEFT", frame, "LEFT", 2, 0) end
        frame.Portrait:Show()
    else frame.Portrait:Hide() end

    local leftInset, rightInset = 2, 2
    if appearance.showPortrait then
        if appearance.portraitSide == "RIGHT" then rightInset = portraitWidth + 4 else leftInset = portraitWidth + 4 end
    end
    local powerHeight = math.max(8, math.floor(height * (ns.GetPowerPercent(unitType) / 100)))
    frame.Health:ClearAllPoints(); frame.Health:SetPoint("TOPLEFT", frame, "TOPLEFT", leftInset, -2); frame.Health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -rightInset, -2); frame.Health:SetPoint("BOTTOM", frame, "BOTTOM", 0, powerHeight)
    frame.Power:ClearAllPoints(); frame.Power:SetPoint("TOPLEFT", frame.Health, "BOTTOMLEFT", 0, -1); frame.Power:SetPoint("TOPRIGHT", frame.Health, "BOTTOMRIGHT", 0, -1); frame.Power:SetPoint("BOTTOM", frame, "BOTTOM", 0, 2)

    local function ApplyVerticalTextPosition(text, align, leftOffset, rightOffset, isRightText)
        text:ClearAllPoints()
        align = align == "TOP" and "TOP" or (align == "BOTTOM" and "BOTTOM" or "MIDDLE")
        if isRightText then
            if align == "TOP" then text:SetPoint("TOPRIGHT", frame.Health, "TOPRIGHT", -rightOffset, -3)
            elseif align == "BOTTOM" then text:SetPoint("BOTTOMRIGHT", frame.Health, "BOTTOMRIGHT", -rightOffset, 3)
            else text:SetPoint("RIGHT", frame.Health, "RIGHT", -rightOffset, 0) end
        else
            if align == "TOP" then
                text:SetPoint("TOPLEFT", frame.Health, "TOPLEFT", leftOffset, -3)
                text:SetPoint("TOPRIGHT", frame.Health, "TOPRIGHT", -rightOffset, -3)
            elseif align == "BOTTOM" then
                text:SetPoint("BOTTOMLEFT", frame.Health, "BOTTOMLEFT", leftOffset, 3)
                text:SetPoint("BOTTOMRIGHT", frame.Health, "BOTTOMRIGHT", -rightOffset, 3)
            else
                text:SetPoint("LEFT", frame.Health, "LEFT", leftOffset, 0)
                text:SetPoint("RIGHT", frame.Health, "RIGHT", -rightOffset, 0)
            end
        end
    end

    ApplyVerticalTextPosition(frame.NameText, appearance.nameVAlign, 6, 48, false)
    ApplyVerticalTextPosition(frame.HealthText, appearance.healthVAlign, 0, 6, true)
    frame.HealthText:SetWidth(42)
    local fontPath = FONTS[appearance.fontFace] or FONT
    frame.NameText:SetFont(fontPath, appearance.fontSize, "OUTLINE"); frame.HealthText:SetFont(fontPath, math.max(9, appearance.fontSize - 1), "OUTLINE")
    frame.NameText:SetShown(appearance.showName); frame.HealthText:SetShown(appearance.showHealthText)
    ApplyColorModes(frame, appearance)
    ResizeAuraContainer(frame.PlayerBuffs, width); ResizeAuraContainer(frame.CombatDebuffs, width); ResizeAuraContainer(frame.ExternalDefensives, width)
end

function ns.ApplyFrameType(unitType)
    for _, frame in pairs(frames) do if frame.MIUF_UnitType == unitType then ApplyFrame(frame) end end
    if unitType == "party" and not InCombatLockdown() then ApplyPartyLayout() end
    if unitType == "boss" and not InCombatLockdown() then ApplyBossLayout() end
end
ns.ApplySize = ns.ApplyFrameType

-- Live proportional resizing used by the frame mover handle. This previews the
-- selected unit type without committing SavedVariables until the mouse is released.
-- Party and Boss are shared templates, so every frame in the group resizes together.
function ns.PreviewFrameSize(unitType, width, height)
    if InCombatLockdown() then return end
    local previewSize = { width = width, height = height }
    for _, frame in pairs(frames) do
        if frame.MIUF_UnitType == unitType then ApplyFrame(frame, previewSize) end
    end
    if unitType == "party" then ApplyPartyLayout() end
    if unitType == "boss" then ApplyBossLayout() end
end

local lockMoversButton = CreateFrame("Button", "MIUF_LockMoversButton", UIParent, "UIPanelButtonTemplate")
lockMoversButton:SetSize(130, 28)
lockMoversButton:SetPoint("TOP", UIParent, "TOP", 0, -90)
lockMoversButton:SetFrameStrata("TOOLTIP")
lockMoversButton:SetText("Lock Movers")
lockMoversButton:Hide()

local function UpdateLockMoversButton()
    if ns.AreFrameMoversLocked() and ns.AreAuraMoversLocked() then
        lockMoversButton:Hide()
    else
        lockMoversButton:Show()
    end
end

lockMoversButton:SetScript("OnClick", function()
    ns.SetFrameMoversLockedState(true)
    ns.SetAuraMoversLockedState(true)
    if ns.SetFrameMoversLocked then ns.SetFrameMoversLocked(true) end
    if ns.SetAuraMoversLocked then ns.SetAuraMoversLocked(true) end
    UpdateLockMoversButton()
end)

function ns.UpdateLockMoversButton() UpdateLockMoversButton() end

function ns.SetFrameMoversLocked(locked)
    for _, frame in pairs(frames) do
        local mover = frame.MIUF_Mover
        if mover then
            local hideExtraGroupMover = (frame.MIUF_UnitType == "party" and frame.__unit ~= "party1") or (frame.MIUF_UnitType == "boss" and frame.__unit ~= "boss1")
            if locked or hideExtraGroupMover or previewEnabled[frame.MIUF_UnitType] == false or not ns.IsFrameTypeEnabled(frame.MIUF_UnitType) then mover:Hide() else mover:Show() end
        end
    end
    UpdateLockMoversButton()
end

function ns.SetAuraMoversLocked(locked)
    for _, frame in pairs(frames) do
        if frame.MIUF_AuraMovers then
            for auraType, auraMover in pairs(frame.MIUF_AuraMovers) do
                local layout = ns.GetAuraLayout(frame.MIUF_UnitType, auraType)
                local duplicatePartyMover = frame.MIUF_UnitType == "party" and frame ~= ns.partyAuraMoverOwner
                if locked or duplicatePartyMover or previewEnabled[frame.MIUF_UnitType] == false or not ns.IsFrameTypeEnabled(frame.MIUF_UnitType) or not layout or layout.enabled == false then
                    auraMover:Hide()
                else
                    auraMover:Show()
                end
            end
        end
    end
    UpdateLockMoversButton()
end

function ns.PreviewUnitTypeMovers(unitType, enabled)
    previewEnabled[unitType] = enabled and true or false
    for _, frame in pairs(frames) do
        if frame.MIUF_UnitType == unitType then
            if frame.MIUF_Mover then
                local isGroupMover = (unitType ~= "party" and unitType ~= "boss") or frame.__unit == (unitType == "party" and "party1" or "boss1")
                if enabled and isGroupMover and not ns.AreFrameMoversLocked() then frame.MIUF_Mover:Show() else frame.MIUF_Mover:Hide() end
            end
            if frame.MIUF_AuraMovers then
                for auraType, mover in pairs(frame.MIUF_AuraMovers) do
                    local layout = ns.GetAuraLayout(unitType, auraType)
                    local duplicatePartyMover = unitType == "party" and frame ~= ns.partyAuraMoverOwner
                    if enabled and not duplicatePartyMover and not ns.AreAuraMoversLocked() and layout and layout.enabled ~= false then mover:Show() else mover:Hide() end
                end
            end
        end
    end
end

function ns.PreviewAuraMover(unitType, auraType, enabled)
    for _, frame in pairs(frames) do
        if frame.MIUF_UnitType == unitType and frame.MIUF_AuraMovers and frame.MIUF_AuraMovers[auraType] then
            local mover = frame.MIUF_AuraMovers[auraType]
            local duplicatePartyMover = unitType == "party" and frame ~= ns.partyAuraMoverOwner
            if enabled and not duplicatePartyMover and previewEnabled[unitType] ~= false and not ns.AreAuraMoversLocked() and ns.IsFrameTypeEnabled(unitType) then mover:Show() else mover:Hide() end
        end
    end
end


-- Compatibility helper retained; the UI uses the independent mover functions.
function ns.SetMoversLocked(locked)
    ns.SetFrameMoversLocked(locked)
    ns.SetAuraMoversLocked(locked)
end

function ns.ResetLayout()
    for unit, frame in pairs(frames) do
        ApplyPosition(unit, frame)
        ApplyAuraAnchorPosition(frame, "buffs")
        ApplyAuraAnchorPosition(frame, "debuffs")
        ApplyAuraAnchorPosition(frame, "defensives")
    end
    ApplyPartyLayout()
    ApplyBossLayout()
    for unitType in pairs(ns.defaultSizes) do ns.ApplyFrameType(unitType) end
    ns.SetFrameMoversLocked(true)
    ns.SetAuraMoversLocked(true)
end

-- Keep the party group compact when members join or leave.  Protected frame
-- anchoring is deferred until combat ends when roster changes happen in combat.
local partyLayoutPending = false
local partyWatcher = CreateFrame("Frame")
partyWatcher:RegisterEvent("GROUP_ROSTER_UPDATE")
partyWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
partyWatcher:SetScript("OnEvent", function()
    if InCombatLockdown() then
        partyLayoutPending = true
    else
        partyLayoutPending = false
        ApplyPartyLayout()
    end
end)

local combatWatcher = CreateFrame("Frame"); combatWatcher:RegisterEvent("PLAYER_REGEN_DISABLED"); combatWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
combatWatcher:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        ns.SetFrameMoversLocked(true)
        ns.SetAuraMoversLocked(true)
    elseif event == "PLAYER_REGEN_ENABLED" then
        if partyLayoutPending then
            partyLayoutPending = false
            ApplyPartyLayout()
        end
        ns.SetFrameMoversLocked(ns.AreFrameMoversLocked())
        ns.SetAuraMoversLocked(ns.AreAuraMoversLocked())
    end
end)
