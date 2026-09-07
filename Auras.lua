local ADDON_NAME, ns = ...
local oUF = _G.oUF
if not oUF then error(ADDON_NAME .. " requires the standalone oUF addon.") end

local FLAT = "Interface\\Buttons\\WHITE8x8"
local FONT = "Fonts\\FRIZQT__.TTF"
local AURA_LABELS = { buffs = "Buffs", debuffs = "Debuffs", defensives = "Defensives" }
local AURA_FIELDS = { buffs = "PlayerBuffs", debuffs = "CombatDebuffs", defensives = "ExternalDefensives" }

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

function ns.ApplyAuraPositions(unitType, auraType)
    if InCombatLockdown() or not ns.frames then return end
    for _, frame in pairs(ns.frames) do
        if frame.MIUF_UnitType == unitType then ApplyAuraAnchorPosition(frame, auraType) end
    end
end

function ns.PreviewAuraIconSize(unitType, auraType, iconSize)
    if InCombatLockdown() or not ns.frames then return end
    local field = AURA_FIELDS[auraType]
    if not field then return end
    iconSize = math.max(1, tonumber(iconSize) or 16)
    local layout = ns.GetAuraLayout(unitType, auraType)
    local spacing = (layout and layout.spacing) or 0
    for _, frame in pairs(ns.frames) do
        if frame.MIUF_UnitType == unitType then
            local container = frame[field]
            if container then
                container.size = iconSize
                if container.MIUF_GroupKey and container.SetAuraGroupLayout then
                    container:SetAuraGroupLayout(container.MIUF_GroupKey, {
                        elementWidth = iconSize, elementHeight = iconSize,
                        elementSpacing = spacing, lineSpacing = spacing,
                    })
                end
                if container.MIUF_Anchor then container.MIUF_Anchor:SetHeight((iconSize * 2) + spacing + 4) end
            end
        end
    end
end

local function CreateAuraMover(self, auraType, container)
    local anchor = container and container.MIUF_Anchor
    if not anchor then return end
    anchor:SetMovable(true); anchor:SetClampedToScreen(true)
    local mover = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    mover:SetFrameStrata("DIALOG"); mover:SetAllPoints(anchor)
    mover:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
    mover:SetBackdropColor(0.35, 0.18, 0.65, 0.24); mover:SetBackdropBorderColor(0.75, 0.45, 1, 1)
    mover:EnableMouse(true); mover:RegisterForDrag("LeftButton")
    local label = mover:CreateFontString(nil, "OVERLAY"); label:SetFont(FONT, 10, "OUTLINE"); label:SetPoint("CENTER")
    label:SetText(self.MIUF_UnitType == "party" and ("Party " .. AURA_LABELS[auraType]) or ((self.__unit or self.MIUF_UnitType) .. " " .. AURA_LABELS[auraType]))
    mover:SetScript("OnDragStart", function() if not InCombatLockdown() then anchor:StartMoving() end end)
    mover:SetScript("OnDragStop", function()
        anchor:StopMovingOrSizing(); if not InCombatLockdown() then SaveDraggedAuraPosition(self, auraType, anchor) end
    end)
    mover:Hide()
    self.MIUF_AuraMovers = self.MIUF_AuraMovers or {}; self.MIUF_AuraMovers[auraType] = mover
end

local function CreateAuraContainer(self, width, filter, borderDebuffs, layout, candidateFilters)
    local point, relativePoint, initialAnchor, growthX, growthY = GetAuraAnchor(layout)
    local anchor = CreateFrame("Frame", nil, self)
    anchor:SetSize(width, (layout.iconSize * 2) + (layout.spacing or 0) + 4)
    anchor:SetPoint(point, self, relativePoint, layout.xOffset or 0, layout.yOffset or 0)
    local auras = self:CreateAuras({ initialAnchor = initialAnchor, growthX = growthX, growthY = growthY, layoutLimit = width })
    auras:SetAllPoints(anchor); auras.MIUF_Anchor = anchor
    auras.size = layout.iconSize; auras.elementSpacing = layout.spacing; auras.lineSpacing = layout.spacing
    auras.MIUF_ShowText = layout.showText ~= false; auras.showCount = auras.MIUF_ShowText
    auras.PostCreateButton = function(element, button)
        if button and button.Cooldown and button.Cooldown.SetHideCountdownNumbers then
            button.Cooldown:SetHideCountdownNumbers(not element.MIUF_ShowText)
        end
    end
    auras.showDuration = false; auras.showDebuffBorder = borderDebuffs and true or false; auras.disableMouse = false
    auras.MIUF_GroupKey = auras:AddGroup(filter, { maxFrameCount = layout.maxCount, candidateFilters = candidateFilters })
    return auras
end

local function CreateDispelHighlight(self)
    local container = self:CreateAuras({ initialAnchor = "TOPLEFT" }); container:SetAllPoints(self)
    container:AddSlot("HARMFUL|RAID", {
        initializeFrame = function(button)
            button:SetSize(1, 1); button:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0); button:EnableMouse(false)
            local function AddEdge(point1, relPoint1, x1, y1, point2, relPoint2, x2, y2, layer, colorMap)
                local edge = button:CreateTexture(nil, "OVERLAY", nil, layer or 7)
                edge:SetColorTexture(1, 1, 1, 1)
                edge:SetPoint(point1, self, relPoint1, x1, y1); edge:SetPoint(point2, self, relPoint2, x2, y2)
                button:AddDispelTypeTexture(edge, {
                    style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
                    showWhenHarmful = true,
                    customDispelColorMap = colorMap or oUF.colors.dispel,
                })
                return edge
            end
            local fixedOutlineMap = {
                Magic=CreateColor(1,1,1), Curse=CreateColor(1,1,1), Disease=CreateColor(1,1,1), Poison=CreateColor(1,1,1),
                Bleed=CreateColor(1,1,1), Enrage=CreateColor(1,1,1), None=CreateColor(1,1,1),
            }
            local t, o = 5, 1
            local outlineEdges = {
                top=AddEdge("BOTTOMLEFT","TOPLEFT",-o,0,"TOPRIGHT","TOPRIGHT",o,o,6,fixedOutlineMap),
                bottom=AddEdge("TOPLEFT","BOTTOMLEFT",-o,0,"BOTTOMRIGHT","BOTTOMRIGHT",o,-o,6,fixedOutlineMap),
                left=AddEdge("TOPRIGHT","TOPLEFT",0,o,"BOTTOMLEFT","BOTTOMLEFT",-o,-o,6,fixedOutlineMap),
                right=AddEdge("TOPLEFT","TOPRIGHT",0,o,"BOTTOMRIGHT","BOTTOMRIGHT",o,-o,6,fixedOutlineMap),
            }
            button.DispelHighlight = {
                outline=outlineEdges,
                top=AddEdge("TOPLEFT","TOPLEFT",0,0,"BOTTOMRIGHT","TOPRIGHT",0,-t,7),
                bottom=AddEdge("BOTTOMLEFT","BOTTOMLEFT",0,0,"TOPRIGHT","BOTTOMRIGHT",0,t,7),
                left=AddEdge("TOPLEFT","TOPLEFT",0,-t,"BOTTOMRIGHT","BOTTOMLEFT",t,t,7),
                right=AddEdge("TOPLEFT","TOPRIGHT",-t,-t,"BOTTOMRIGHT","BOTTOMRIGHT",0,t,7),
            }
        end,
    })
    self.DispelAuras = container
end

local function GetPlayerBuffCandidateFilters()
    local included = ns.GetTrackedBuffSpellIDs and ns.GetTrackedBuffSpellIDs() or {}
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
    local anchor = CreateFrame("Frame", nil, self); anchor:SetSize(width, 1); anchor:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0); anchor:SetAlpha(0)
    local auras = self:CreateAuras({ initialAnchor="TOPLEFT", growthX="RIGHT", growthY="DOWN", layoutLimit=width })
    auras:SetAllPoints(anchor); auras.size=1; auras.elementSpacing=0; auras.lineSpacing=0
    auras.disableMouse=true; auras.disableCooldown=true; auras.showCount=false; auras.showDuration=false; auras.PostUpdateButton=RecordSeenAura
    auras:AddGroup("HELPFUL|PLAYER", { maxFrameCount = 40 })
    return auras
end

function ns.CreateProtectedAuras(self, unitType, width)
    if unitType == "boss" then return end
    local buffs = ns.GetAuraLayout(unitType, "buffs")
    if (unitType == "player" or unitType == "target" or unitType == "focus" or unitType == "party" or unitType == "targettarget") and buffs and buffs.enabled ~= false then
        self.PlayerBuffs = CreateAuraContainer(self, width, "HELPFUL|PLAYER", false, buffs, GetPlayerBuffCandidateFilters())
        self.MIUF_BuffDiscovery = CreateBuffDiscoveryContainer(self, width)
    end
    local debuffs = ns.GetAuraLayout(unitType, "debuffs")
    if unitType ~= "pet" and debuffs and debuffs.enabled ~= false then self.CombatDebuffs = CreateAuraContainer(self, width, "HARMFUL|RAID_IN_COMBAT", true, debuffs) end
    local defensives = ns.GetAuraLayout(unitType, "defensives")
    if (unitType == "player" or unitType == "party") and defensives and defensives.enabled ~= false then self.ExternalDefensives = CreateAuraContainer(self, width, "HELPFUL|EXTERNAL_DEFENSIVE", false, defensives) end
    if unitType == "player" or unitType == "party" or unitType == "focus" then CreateDispelHighlight(self) end

    if self.PlayerBuffs then CreateAuraMover(self, "buffs", self.PlayerBuffs) end
    if self.CombatDebuffs then CreateAuraMover(self, "debuffs", self.CombatDebuffs) end
    if self.ExternalDefensives then CreateAuraMover(self, "defensives", self.ExternalDefensives) end
end

function ns.ResizeAuraContainers(frame, width)
    for _, field in pairs(AURA_FIELDS) do
        local container = frame[field]
        if container then
            if container.MIUF_Anchor then container.MIUF_Anchor:SetWidth(width) else container:SetWidth(width) end
            if container.SetFlowLayoutMaximumLineSize then container:SetFlowLayoutMaximumLineSize(width) end
        end
    end
end

function ns.ResetAuraPositionsForFrame(frame)
    ApplyAuraAnchorPosition(frame, "buffs"); ApplyAuraAnchorPosition(frame, "debuffs"); ApplyAuraAnchorPosition(frame, "defensives")
end

function ns.SetAuraMoversLocked(locked)
    if not ns.frames then return end
    for _, frame in pairs(ns.frames) do
        if frame.MIUF_AuraMovers then
            for auraType, auraMover in pairs(frame.MIUF_AuraMovers) do
                local layout = ns.GetAuraLayout(frame.MIUF_UnitType, auraType)
                local duplicatePartyMover = frame.MIUF_UnitType == "party" and frame ~= ns.partyAuraMoverOwner
                local previewOff = ns.IsUnitTypePreviewEnabled and not ns.IsUnitTypePreviewEnabled(frame.MIUF_UnitType)
                if locked or duplicatePartyMover or previewOff or not ns.IsFrameTypeEnabled(frame.MIUF_UnitType) or not layout or layout.enabled == false then auraMover:Hide() else auraMover:Show() end
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
            local duplicatePartyMover = unitType == "party" and frame ~= ns.partyAuraMoverOwner
            local previewOn = not ns.IsUnitTypePreviewEnabled or ns.IsUnitTypePreviewEnabled(unitType)
            if enabled and not duplicatePartyMover and previewOn and not ns.AreAuraMoversLocked() and ns.IsFrameTypeEnabled(unitType) then mover:Show() else mover:Hide() end
        end
    end
end
