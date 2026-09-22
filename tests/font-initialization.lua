-- Run from the repository root: lua5.1 tests/font-initialization.lua
local watchers={}
function CreateFrame()
    local frame={events={},scripts={}}
    function frame:RegisterEvent(event) self.events[event]=true end
    function frame:UnregisterEvent(event) self.events[event]=nil end
    function frame:SetScript(script,callback) self.scripts[script]=callback end
    watchers[#watchers+1]=frame
    return frame
end
local ns={}
assert(loadfile("Media.lua"))("MythIncUnitFrames",ns)
assert(loadfile("UnitFrames.lua"))("MythIncUnitFrames",ns)
-- Exercise the real helpers without mocking unrelated secure unit layout.
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
local apply=assert(findUpvalue(ns.PreviewFrameType,"ApplyFrameFonts"))
local startup,updater
for _,watcher in ipairs(watchers) do
    if watcher.events.LOADING_SCREEN_DISABLED then startup=watcher end
    if watcher.scripts.OnUpdate then assert(not updater); updater=watcher end
end
assert(startup and updater)
local function tick(elapsed) updater.scripts.OnUpdate(updater,elapsed or 0.25) end
local friz=ns.GetFontPath("friz")
local function region()
    local text={calls={},succeeds=false,font=friz,size=12}
    function text:SetFont(font,size,flags)
        self.calls[#self.calls+1]={font=font,size=size,flags=flags}
        local success=self.succeeds
        if self.result then success=self:result(font,size,flags) end
        if success then self.font,self.size,self.flags=font,size,flags end
        return success
    end
    return text
end
-- No visibility/unit methods: recovery must work for hidden regions too.
local function frame() return {NameText=region(),HealthText=region()} end
local function calls(f) return #f.NameText.calls+#f.HealthText.calls end
local function expectSequence(text,start,font,sizes)
    assert(#text.calls==start+#sizes,"unexpected font calls")
    for i,size in ipairs(sizes) do
        local call=text.calls[start+i]
        assert(call.font==font and call.size==size and call.flags=="OUTLINE")
    end
end
local player=frame()
apply(player,{fontFace="oxanium",fontSize=12})
assert(player.NameText.MIUF_FontRecovery.attempts==0)
assert(player.HealthText.MIUF_FontRecovery.attempts==0)
assert(player.NameText.font==friz)
startup.scripts.OnEvent(startup,"LOADING_SCREEN_DISABLED")
assert(not startup.events.LOADING_SCREEN_DISABLED and calls(player)==4)
tick(0.1); assert(calls(player)==4)
player.NameText.succeeds=true
tick(0.15)
expectSequence(player.NameText,2,ns.GetFontPath("oxanium"),{12,13,12})
assert(not player.NameText.MIUF_FontRecovery)
assert(player.HealthText.MIUF_FontRecovery.attempts==2)
tick(); assert(#player.NameText.calls==5 and #player.HealthText.calls==4)
player.HealthText.succeeds=true
tick()
expectSequence(player.HealthText,4,ns.GetFontPath("oxanium"),{11,12,11})
local recovered=calls(player)
for i=1,150 do tick() end
assert(calls(player)==recovered)

for _,font in ipairs({"oxanium","orbitron","uncial"}) do
    local f=frame(); f.NameText.succeeds=true; f.HealthText.succeeds=true
    apply(f,{fontFace=font,fontSize=12})
    assert(calls(f)==2,"immediate success must not toggle")
    apply(f,{fontFace=font,fontSize=13})
    tick(); assert(calls(f)==4,"ordinary preview must not toggle")
end

-- Preview changes replace path/size, preserve attempts, and use shared recovery.
local preview=frame()
apply(preview,{fontFace="oxanium",fontSize=12})
tick()
local latest={fontFace="orbitron",fontSize=19}
apply(preview,latest)
assert(preview.NameText.MIUF_FontRecovery.attempts==2)
assert(preview.NameText.MIUF_FontRecovery.font==ns.GetFontPath("orbitron"))
assert(preview.NameText.MIUF_FontRecovery.size==19)
preview.NameText.succeeds=true; preview.HealthText.succeeds=true
local nameStart,healthStart=#preview.NameText.calls,#preview.HealthText.calls
apply(preview,latest)
expectSequence(preview.NameText,nameStart,ns.GetFontPath("orbitron"),{19,20,19})
expectSequence(preview.HealthText,healthStart,ns.GetFontPath("orbitron"),{18,19,18})
assert(latest.fontSize==19 and latest.fontFace=="orbitron")
local before=calls(preview); tick(); assert(calls(preview)==before)

for _,font in ipairs({"friz","arial","morpheus","unknown"}) do
    local f=frame()
    apply(f,{fontFace=font,fontSize=8})
    assert(calls(f)==2 and not f.NameText.MIUF_FontRecovery)
    apply(f,{fontFace="uncial",fontSize=12})
    apply(f,{fontFace=font,fontSize=8})
    assert(not f.NameText.MIUF_FontRecovery)
    assert(f.HealthText.calls[#f.HealthText.calls].size==9)
    local count=calls(f); tick(); assert(calls(f)==count)
end

-- Repeated config attempts consume the same budget; exhaustion stays exhausted.
local broken=frame()
apply(broken,{fontFace="uncial",fontSize=12})
for i=1,60 do tick(); apply(broken,{fontFace="uncial",fontSize=12}) end
assert(broken.NameText.MIUF_FontRecovery.attempts==120)
assert(calls(broken)==242)
for i=1,150 do tick() end
assert(calls(broken)==242)
apply(broken,{fontFace="uncial",fontSize=14})
assert(broken.NameText.MIUF_FontRecovery.attempts==121)
local capped=calls(broken)
for i=1,150 do tick() end
assert(calls(broken)==capped)
broken.NameText.succeeds=true; broken.HealthText.succeeds=true
nameStart=#broken.NameText.calls
apply(broken,{fontFace="uncial",fontSize=14})
expectSequence(broken.NameText,nameStart,ns.GetFontPath("uncial"),{14,15,14})
assert(not broken.NameText.MIUF_FontRecovery)

-- Even a failed temporary call must be followed by restoration.
local temporary=frame()
apply(temporary,{fontFace="oxanium",fontSize=12})
function temporary.NameText:result(_,size) return size~=13 end
function temporary.HealthText:result(_,size) return size~=12 end
tick()
expectSequence(temporary.NameText,1,ns.GetFontPath("oxanium"),{12,13,12})
assert(temporary.NameText.size==12 and not temporary.NameText.MIUF_FontRecovery)
assert(temporary.HealthText.size==11 and not temporary.HealthText.MIUF_FontRecovery)

-- Restoration failure falls back synchronously at the intended size, remains
-- pending, and terminates at the cap even when initial assignment always works.
local restore=frame()
apply(restore,{fontFace="orbitron",fontSize=12})
for _,text in ipairs({restore.NameText,restore.HealthText}) do
    text.phase=0
    function text:result(font)
        if font==friz then return true end
        self.phase=self.phase+1
        return self.phase%3~=0
    end
end
for i=1,120 do
    tick()
    assert(restore.NameText.font==friz and restore.NameText.size==12)
    assert(restore.HealthText.font==friz and restore.HealthText.size==11)
end
assert(restore.NameText.MIUF_FontRecovery.attempts==120)
assert(#restore.NameText.calls==481)
local stopped=calls(restore)
for i=1,150 do tick() end
assert(calls(restore)==stopped)
print("font initialization tests passed")
