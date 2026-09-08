local ADDON_NAME, ns = ...

if not ns.UnitFrames then return end

-- ClickCastFrames is the long-standing shared registration table used by
-- Clique and other click-casting addons. MIUF frames are already
-- SecureUnitButtonTemplate buttons with a secure "unit" attribute, so they
-- only need to be advertised through this table.
_G.ClickCastFrames = _G.ClickCastFrames or {}

local function RegisterClickCastFrame(frame)
    if not frame or not frame.GetName or not frame:GetName() then return end
    _G.ClickCastFrames[frame] = true
end

local oldSpawnAllFrames = ns.SpawnAllFrames
function ns.SpawnAllFrames(...)
    oldSpawnAllFrames(...)

    if not ns.frames then return end
    for _, frame in pairs(ns.frames) do
        RegisterClickCastFrame(frame)
    end
end
