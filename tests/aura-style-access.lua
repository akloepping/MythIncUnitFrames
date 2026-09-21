-- Run from the repository root: lua5.1 tests/aura-style-access.lua
-- Exercise the actual module/public preview and combat-event paths, not a copy
-- of its guard. Restricted styling attempts fail even if production catches them.
local combat, secret = false, {}
local events, secretChecks, forbiddenAttempts = {}, 0, 0
function InCombatLockdown() return combat end
function canaccessvalue(value)
    if value == secret then secretChecks = secretChecks + 1 end
    return value ~= secret
end
function UnitExists() return true end
function UnitIsConnected() return true end
function hooksecurefunc() end -- unrelated saved-list hooks are not exercised
function CreateFrame()
    local frame = { events = {}, scripts = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:SetScript(script, callback)
        assert(script ~= "OnUpdate", "styling must not poll")
        self.scripts[script] = callback
    end
    events[#events + 1] = frame
    return frame
end
local function fire(event)
    for _, frame in ipairs(events) do
        if frame.events[event] then frame.scripts.OnEvent(frame, event) end
    end
end
local function region()
    local r = { access = true, writes = 0 }
    function r:CanBeAccessedInContext() return self.access end
    local function writable(self)
        if self.access ~= true then
            forbiddenAttempts = forbiddenAttempts + 1
            error("forbidden styling operation")
        end
        self.writes = self.writes + 1
    end
    function r:SetFont(font, size, flags)
        writable(self)
        self.font, self.size, self.flags = font, size, flags
    end
    function r:SetHideCountdownNumbers(hidden)
        writable(self)
        self.hidden = hidden
    end
    return r
end
local count, cooldown = region(), region()
local regions = { count = count, cooldown = cooldown }
local anchor = {}
function anchor:SetSize() end
function anchor:ClearAllPoints() end
function anchor:SetPoint() end
local container = {}
function container:SetShown() end
local data = { anchor = anchor, container = container, style = {},
    styleRegions = { regions }, groupKeys = {} }
local frame = { MIUF_UnitType = "raid", MIUF_Unit = "raid1",
    MIUF_Auras = { debuffs = data } }
function frame:GetWidth() return 120 end
local requested = { iconSize = 22, showText = true }
local callerReads = 0
local ns = { UnitFramesLoaded = true, frames = { raid1 = frame } }
function ns.IsFrameTypeEnabled() return true end
function ns.GetFrameDisplayUnit(f) return f.MIUF_Unit end
function ns.AreAuraMoversLocked() return true end
function ns.GetAuraLayout() return { iconSize = 10, showText = true } end
function ns.ConfigSessionGetAura(unitType, auraType)
    assert(unitType == "raid" and auraType == "debuffs")
    callerReads = callerReads + 1
    return { iconSize = requested.iconSize, showText = requested.showText }
end
assert(loadfile("Auras.lua"))("MythIncUnitFrames", ns)
local function preview()
    ns.PreviewRaidDebuffLayout(ns.ConfigSessionGetAura("raid", "debuffs"))
end
local function expectStyle(size, hidden)
    assert(count.size == math.max(8, math.floor(size * 0.45)), "wrong count font size")
    assert(count.font == "Fonts\\FRIZQT__.TTF" and count.flags == "OUTLINE")
    assert(cooldown.hidden == hidden, "wrong cooldown text style")
    assert(not data.stylePending and not regions.stylePending, "retry not cleared")
end
preview()
expectStyle(22, false)
assert(count.writes > 0 and cooldown.writes > 0)

-- Denial of either descendant must prevent both styling operations. A truthy
-- inaccessible result also must not be treated as permission.
for _, pair in ipairs({ {false, true}, {true, false}, {secret, true}, {true, secret} }) do
    count.access, cooldown.access = pair[1], pair[2]
    local beforeCount, beforeCooldown, beforeChecks = count.writes, cooldown.writes, secretChecks
    requested = { iconSize = 30, showText = false }
    preview()
    assert(count.writes == beforeCount and cooldown.writes == beforeCooldown)
    if pair[1] == secret or pair[2] == secret then
        assert(secretChecks > beforeChecks, "restricted access result bypassed canaccessvalue")
    end
    assert(data.stylePending and regions.stylePending)
    assert(data.style.iconSize == 30 and data.style.showText == false)
end

local beforeCount, beforeCooldown, beforeReads = count.writes, cooldown.writes, callerReads
count.access, cooldown.access = false, secret
for i = 1, 40 do
    combat = true
    fire("PLAYER_REGEN_DISABLED")
    requested = { iconSize = 30 + i, showText = i % 2 == 1 }
    combat = false
    fire("PLAYER_REGEN_ENABLED")
    assert(callerReads == beforeReads + i, "combat exit skipped ConfigSessionGetAura/raid preview")
    assert(count.writes == beforeCount and cooldown.writes == beforeCooldown)
    assert(data.stylePending and regions.stylePending)
    assert(data.style.iconSize == requested.iconSize and data.style.showText == requested.showText)
end
assert(forbiddenAttempts == 0, "denied styling was attempted or suppressed")

-- Availability retry uses the latest retained request, not saved defaults.
count.access, cooldown.access = true, true
combat = true
ns.RefreshFrameAuraAvailability(frame)
assert(count.writes == beforeCount and cooldown.writes == beforeCooldown)
combat = false
ns.RefreshFrameAuraAvailability(frame)
expectStyle(70, true)
assert(count.writes == beforeCount + 1 and cooldown.writes == beforeCooldown + 1)
ns.RefreshFrameAuraAvailability(frame)
assert(count.writes == beforeCount + 1, "settled styles should not keep retrying")

-- The combat-exit caller also recovers with the latest staged configuration.
count.access = false
requested = { iconSize = 40, showText = false }
fire("PLAYER_REGEN_ENABLED")
count.access = true
requested = { iconSize = 50, showText = true }
fire("PLAYER_REGEN_ENABLED")
expectStyle(50, false)
assert(forbiddenAttempts == 0)
print("PASS: native aura access, 40 denied combat exits, latest-style recovery")
