-- Run from the repository root: lua5.1 tests/aura-mover-preview.lua
local combat, created, stagedWrites = false, 0, 0
local methods = {}
local function object()
    return setmetatable({shown=true,scripts={},events={},x=0,y=0}, {__index=methods})
end
local function noop() end
for _,name in ipairs({"SetMovable","SetClampedToScreen","SetFrameStrata","SetAllPoints",
    "SetBackdrop","SetBackdropColor","SetBackdropBorderColor","EnableMouse","RegisterForDrag",
    "SetFont","SetText","ClearAllPoints","SetAuraGroupFilterString","SetAuraGroupCandidateFilters"}) do methods[name]=noop end
function methods:SetPoint(_,_,_,x,y) self.x=x; self.y=y end
function methods:GetLeft() return self.x end
function methods:GetTop() return self.y end
function methods:GetBottom() return self.y end
function methods:GetWidth() return 120 end
function methods:SetSize(width,height) self.width=width; self.height=height end
function methods:IsVisible() return self.shown end
function methods:StartMoving() self.moving=true end
function methods:StopMovingOrSizing() self.moving=false end
function methods:SetScript(name,fn) assert(name~="OnUpdate"); self.scripts[name]=fn end
function methods:RegisterEvent(name) self.events[name]=true end
function methods:UnregisterEvent(name) self.events[name]=nil end
function methods:CreateFontString() return object() end
function methods:Show() self.shown=true end
function methods:Hide()
    local wasShown=self.shown; self.shown=false
    if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
end
local eventFrames={}
function CreateFrame()
    created=created+1
    local frame=object(); eventFrames[#eventFrames+1]=frame; return frame
end
function InCombatLockdown() return combat end
local solo=false
function UnitExists() return not solo end
function hooksecurefunc(target,key,callback)
    local original=target[key]
    target[key]=function(...) if original then original(...) end; callback(...) end
end
local saved={enabled=true,anchor="TOP",growth="RIGHT",xOffset=5,yOffset=6}
local staged, enabled={},true
local ns={UnitFramesLoaded=true,frames={}}
local ghosts={party=object(),raid=object()}
function ns.GetGroupStatusPreviewFrame(unitType)
    local host=ghosts[unitType]
    return host and host.shown and host or nil
end
-- Aura-only preview actions must not call castbar cleanup or alter its state.
local castbarPreview={active=true}
function ns.ClearCastbarPreview() error("aura action canceled castbar preview") end
function ns.IsFrameTypeEnabled() return true end
function ns.ConfigSessionGetEnabled() return enabled end
function ns.AreAuraMoversLocked() return true end
function ns.ConfigSessionGetAura(unitType,auraType)
    local result={}; for k,v in pairs(saved) do result[k]=v end
    for k,v in pairs(staged[unitType..":"..auraType] or {}) do result[k]=v end
    return result
end
ns.GetAuraLayout=ns.ConfigSessionGetAura
function ns.ConfigSessionStageAura(unitType,auraType,values)
    stagedWrites=stagedWrites+1; staged[unitType..":"..auraType]=values
end
assert(loadfile("Auras.lua"))("MythIncUnitFrames",ns)

-- Reach the real mover constructor without constructing native aura containers
-- or copying its drag implementation into this focused visibility test.
local function findUpvalue(fn,wanted,seen)
    seen=seen or {}; if seen[fn] then return end; seen[fn]=true
    for i=1,100 do
        local name,value=debug.getupvalue(fn,i); if not name then break end
        if name==wanted then return value end
        if type(value)=="function" then
            local found=findUpvalue(value,wanted,seen); if found then return found end
        end
    end
end
local createMover=assert(findUpvalue(ns.RefreshAuras,"CreateAuraMover"))
for _,key in ipairs({"target","focus","party1","party2","raid1","raid2"}) do
    local frame=object(); frame.MIUF_Unit=key
    frame.MIUF_UnitType=key:match("^party") and "party" or (key:match("^raid") and "raid" or key)
    frame.MIUF_Auras={}; ns.frames[key]=frame
    for _,aura in ipairs({"buffs","debuffs"}) do
        if frame.MIUF_UnitType~="raid" or aura=="debuffs" then
            local anchor=object(); frame.MIUF_Auras[aura]={anchor=anchor,container=object()}
            createMover(frame,aura,anchor)
        end
    end
end
local function only(...)
    local expected={}
    for _,mover in ipairs({...}) do expected[mover]=true end
    for _,frames in ipairs({ns.frames,ghosts}) do
        for _,frame in pairs(frames) do
            for _,mover in pairs(frame.MIUF_AuraMovers or {}) do
                assert(mover.shown==(expected[mover]==true), "unexpected visible mover")
            end
        end
    end
end
local count=created
ns.SetAuraMoversLocked(false); only(nil) -- no legacy global exposure
local target=ns.frames.target
local buffs,debuffs=target.MIUF_AuraMovers.buffs,target.MIUF_AuraMovers.debuffs
ns.PreviewAuraMover("target","buffs",true); only(buffs)
ns.SetAuraMoversLocked(true); only(buffs) -- saved-lock refresh preserves UI selection
ns.PreviewAuraMover("target","debuffs",true); only(buffs,debuffs)
ns.PreviewAuraMover("target","buffs",false); only(debuffs)
ns.PreviewAuraMover("target","buffs",true); only(buffs,debuffs)
assert(castbarPreview.active)
ns.PreviewAuraMover("focus","buffs",true); only(ns.frames.focus.MIUF_AuraMovers.buffs)
ns.PreviewAuraMover("party","buffs",true); only(ns.frames.party1.MIUF_AuraMovers.buffs)
ns.frames.party1:Hide(); ns.RefreshAuraMoverPreview(); only(ns.frames.party2.MIUF_AuraMovers.buffs)
ns.PreviewAuraMover("raid","debuffs",true); only(ns.frames.raid1.MIUF_AuraMovers.debuffs)
ns.ClearAuraMoverPreview(); only(nil)
assert(stagedWrites==0 and created==count, "visibility must not allocate or stage positions")

-- Solo previews reuse the existing visible configuration ghosts and the same
-- mover constructor. They never need a real unit or a native aura container.
solo=true
ns.PreviewAuraMover("party","buffs",true)
local ghostBuff=ghosts.party.MIUF_AuraMovers.buffs
only(ghostBuff)
assert(ghosts.party.MIUF_Auras.buffs.container==nil)
ns.PreviewAuraMover("party","debuffs",true)
only(ghostBuff,ghosts.party.MIUF_AuraMovers.debuffs)
local mockAnchor=ghosts.party.MIUF_Auras.buffs.anchor
ghostBuff.scripts.OnDragStart(); mockAnchor.x=44; mockAnchor.y=55
ghostBuff.scripts.OnDragStop()
assert(staged["party:buffs"].xOffset==44 and staged["party:buffs"].yOffset==55)
assert(saved.xOffset==5 and saved.yOffset==6)
ns.PreviewAuraMover("raid","debuffs",true)
only(ghosts.raid.MIUF_AuraMovers.debuffs)
assert(ghosts.raid.MIUF_Auras.debuffs.container==nil)
local cachedCount=created
ns.ClearAuraMoverPreview(); only(nil)
ns.PreviewAuraMover("party","buffs",true); only(ghostBuff)
assert(created==cachedCount, "configuration movers should be reused")
-- Run the real GUI slider preview path against active Party/Raid ghosts.
-- ApplyAuraVisual handles real units, so leave it empty to isolate the ghost
-- refresh that used to be missing after X/Y edits.
local configFile=assert(io.open("Config.lua","r"))
local configSource=configFile:read("*a"); configFile:close()
local sliderSource=assert(configSource:match("(local function PreviewAuraSliders%(%)%s.-)\nlocal function ChooseAvailableAura"))
local sliderFactory=assert(loadstring([[
    local ns,selectedType,selectedAura,x,y=...
    local refreshing=false
    local auraWorking={}
    local function Round(v) return v end
    local function AuraAvailable() return true end
    local function ApplyAuraVisual() end
    local function slider(v) return {GetValue=function() return v end} end
    local auraCountSlider,auraSpacingSlider=slider(4),slider(2)
    local auraXSlider,auraYSlider=slider(x),slider(y)
]]..sliderSource..[[
    return PreviewAuraSliders
]]))
for _,kind in ipairs({"party","raid"}) do
    local aura=kind=="party" and "buffs" or "debuffs"
    ns.PreviewAuraMover(kind,aura,true)
    local host=ghosts[kind]
    local activeMover=host.MIUF_AuraMovers[aura]
    local activeAnchor=host.MIUF_Auras[aura].anchor
    local allocations=created
    for _,offset in ipairs({{71,6},{71,-29},{-43,82}}) do
        ns.ConfigSessionStageAura(kind,aura,{xOffset=offset[1],yOffset=offset[2]})
        sliderFactory(ns,kind,aura,offset[1],offset[2])()
        assert(activeAnchor.x==offset[1] and activeAnchor.y==offset[2],kind.." ghost did not move live")
        assert(activeMover.shown and host.MIUF_AuraMovers[aura]==activeMover)
        assert(created==allocations,"slider refresh recreated a preview")
        assert(saved.xOffset==5 and saved.yOffset==6,"slider refresh saved pending edits")
    end
end
ns.PreviewAuraMover("party","buffs",true)
solo=false; ns.frames.party1:Show(); ns.RefreshAuraMoverPreview()
only(ns.frames.party1.MIUF_AuraMovers.buffs)
ns.ClearAuraMoverPreview(); only(nil)
count=created
local writesBefore=stagedWrites

ns.PreviewAuraMover("target","buffs",true)
local anchor=target.MIUF_Auras.buffs.anchor
buffs.scripts.OnDragStart(); assert(anchor.moving)
anchor.x=23; anchor.y=31
buffs.scripts.OnDragStop()
assert(not anchor.moving and stagedWrites==writesBefore+1)
assert(staged["target:buffs"].xOffset==23 and staged["target:buffs"].yOffset==31)
assert(saved.xOffset==5 and saved.yOffset==6, "drag must remain staged")
buffs.scripts.OnDragStart(); anchor.x=99
ns.ClearAuraMoverPreview(); buffs.scripts.OnDragStop()
assert(not anchor.moving and stagedWrites==writesBefore+1 and anchor.x==23, "context exit must cancel unfinished drag")
ns.PreviewAuraMover("target","buffs",true); enabled=false
ns.RefreshAuraMoverPreview(); only(nil)
enabled=true; staged["target:buffs"].enabled=false
ns.RefreshAuraMoverPreview(); only(nil)
staged["target:buffs"].enabled=true
ns.PreviewAuraMover("target","buffs",true); ns.SetActiveProfile("Other"); only(nil)
ns.PreviewAuraMover("target","buffs",true); ns.ResetAllSettings(); only(nil)
ns.PreviewAuraMover("target","buffs",true); combat=true
for _,frame in ipairs(eventFrames) do
    if frame.events.PLAYER_REGEN_DISABLED then frame.scripts.OnEvent(frame,"PLAYER_REGEN_DISABLED") end
end
only(nil); combat=false; ns.RefreshAuraMoverPreview(); only(nil)
assert(created==count and stagedWrites==writesBefore+1 and castbarPreview.active)
print("PASS: composed aura previews, frame scope, solo ghosts, shared staged drag, cleanup, no global exposure")
