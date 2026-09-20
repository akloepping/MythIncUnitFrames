-- Run from the repository root with Lua 5.1.
local created, bindings = 0, 0
local methods = {}
local function object(parent)
    created = created + 1
    return setmetatable({parent=parent, shown=true, scripts={}, points={}, events={}}, {__index=methods})
end
local function noop() end
for _, key in ipairs({"SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "SetFrameLevel",
    "SetAllPoints", "SetColorTexture", "SetFont", "SetJustifyH", "SetWordWrap", "SetBlendMode"}) do
    methods[key] = noop
end
function methods:GetFrameLevel() return 1 end
function methods:SetHeight(h) self.height=h end
function methods:SetSize(w,h) self.width=w; self.height=h end
function methods:SetPoint(...) self.points[#self.points+1]={...} end
function methods:CreateTexture() return object(self) end
function methods:CreateFontString() return object(self) end
function methods:SetTexture(t) self.texture=t end
function methods:SetAtlas(a, useSize) self.atlas=a; self.useAtlasSize=useSize end
function methods:SetText(t) self.text=t end
function methods:SetAlpha(a) self.alpha=a end
function methods:SetAlphaFromBoolean(value, yes, no)
    self.alphaInput=value; self.alphaYes=yes; self.alphaNo=no
end
function methods:SetStatusBarTexture(t) self.fill=object(self); self.fill.texture=t end
function methods:GetStatusBarTexture() return self.fill end
function methods:SetStatusBarColor(...) self.color={...} end
function methods:SetTimerDuration(d, interpolation, direction)
    self.duration=d; self.interpolation=interpolation; self.direction=direction
end
function methods:SetScript(event, fn) self.scripts[event]=fn end
function methods:RegisterEvent(event) self.events[event]=true end
function methods:Hide()
    if self.shown then self.shown=false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
end
function methods:Show()
    if not self.shown then self.shown=true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function CreateFrame(_, _, parent) return object(parent) end
Enum={SecondsFormatterAbbreviation={OneLetter=1}, SecondsFormatterInterval={Seconds=1},
    StatusBarInterpolation={Immediate=1}, StatusBarTimerDirection={ElapsedTime=1, RemainingTime=2}}
C_StringUtil={CreateSecondsFormatter=function()
    return {SetDefaultAbbreviation=noop, SetMinInterval=noop, SetMillisecondsThreshold=noop}
end}
C_DurationUtil={CreateDurationTextBinding=function()
    bindings=bindings+1
    return {
        SetEnabled=function(self, v) self.enabled=v end,
        SetToDefaults=function(self) self.duration=nil; self.fontString=nil; self.formatter=nil end,
        SetFontString=function(self, v) self.fontString=v end,
        SetFormatter=function(self, v) self.formatter=v end,
        SetDuration=function(self, v) assert(v, "SetDuration is not nullable"); self.duration=v end,
        UpdateFontString=function(self)
            assert(self.duration and self.formatter and self.fontString, "binding configured")
            self.fontString:SetText("native remaining time")
        end,
    }
end}
local secret=setmetatable({}, {__tostring=function() error("secret formatted") end,
    __add=function() error("secret arithmetic") end, __sub=function() error("secret arithmetic") end})
function canaccessvalue(v) return v~=secret end
local current, missing = {}, {}
function UnitExists(unit) return not missing[unit] end
function UnitCastingInfo(unit)
    local c=current[unit]
    if c and c.mode=="cast" then return c.name,c.display,c.texture,secret,secret,false,secret,c.lock end
end
function UnitChannelInfo(unit)
    local c=current[unit]
    if c and c.mode~="cast" then return c.name,c.display,c.texture,secret,secret,false,c.lock,secret,c.mode=="empower" end
end
function UnitCastingDuration(unit) return current[unit].duration end
UnitChannelDuration=UnitCastingDuration
function UnitEmpoweredChannelDuration(unit, hold) assert(hold==true); return current[unit].duration end
local ns={frames={}}
function ns.GetFrameDisplayUnit(frame) return frame and (frame.displayUnit or frame.MIUF_Unit) end
function ns.RegisterFrameUnitEvent(events, event) events:RegisterEvent(event) end
for _, unit in ipairs({"player","target","focus","boss1","boss2","boss3","boss4","boss5","pet"}) do
    local frame=object(); frame.MIUF_Unit=unit; frame.MIUF_UnitType=unit:match("boss") and "boss" or unit
    ns.frames[unit]=frame
end
assert(loadfile("Castbars.lua"))("MythIncUnitFrames", ns)
ns.SpawnAllFrames()
assert(not ns.frames.pet.Castbar and bindings==8)
local count=created
local function clear(frame)
    local bar=frame.Castbar
    assert(not frame.CastbarHolder.shown and not bar.Time.binding.enabled)
    assert(bar.Time.binding.duration==nil and bar.Time.text=="" and bar.Text.text=="")
    assert(bar.Icon.texture==nil and bar.Shield.alpha==0 and not bar.Spark.shown)
end
for unit, frame in pairs(ns.frames) do
    if frame.Castbar then
        clear(frame)
        local bar=frame.Castbar
        assert(frame.CastbarHolder.height==18 and bar.Icon.width==16 and bar.Icon.height==16)
        assert(bar.Shield.atlas=="ui-castingbar-shield" and bar.Shield.useAtlasSize==false)
        assert(bar.LockText==nil and bar.Spark.points[1][2]==bar:GetStatusBarTexture())
        for _, mode in ipairs({"cast","channel","empower"}) do
            current[unit]={mode=mode,name="Spell",display="Display",texture=secret,lock=secret,duration=secret}
            ns.UpdateFrameCastbar(frame)
            assert(bar.Icon.texture==secret and bar.Text.text=="Display")
            assert(bar.Time.binding.duration==secret and bar.Time.binding.enabled)
            assert(bar.Time.text=="native remaining time" and bar.Spark.shown)
            assert(bar.Shield.alphaInput==secret and bar.Shield.alphaYes==1 and bar.Shield.alphaNo==0)
            assert(bar.color[1]==0.95 and bar.duration==secret)
            assert(bar.direction==(mode=="channel" and 2 or 1))
            current[unit].lock=true
            frame.MIUF_CastbarEvents.scripts.OnEvent(nil,"UNIT_SPELLCAST_NOT_INTERRUPTIBLE",unit)
            assert(bar.Shield.alphaInput==true and bar.color[1]==0.45)
            current[unit].lock=false; current[unit].display=nil
            frame.MIUF_CastbarEvents.scripts.OnEvent(nil,"UNIT_SPELLCAST_INTERRUPTIBLE",unit)
            assert(bar.Shield.alphaInput==false and bar.color[1]==0.95 and bar.Text.text=="Spell")
            frame.CastbarHolder:Hide(); assert(not bar.Time.binding.enabled)
            frame.CastbarHolder:Show(); assert(bar.Time.binding.enabled)
            current[unit]=nil
            frame.MIUF_CastbarEvents.scripts.OnEvent(nil,"UNIT_SPELLCAST_STOP",unit)
            clear(frame)
        end
        current[unit]={mode="cast",name="Spell",texture=123,lock=false,duration=secret}
        ns.UpdateFrameCastbar(frame)
        assert(frame.Castbar.Icon.texture==123)
        frame:Hide(); ns.UpdateFrameCastbar(frame)
        assert(not frame.Castbar.Time.binding.enabled, "hidden owner does not tick timer")
        frame:Show(); ns.UpdateFrameCastbar(frame)
        assert(frame.Castbar.Time.binding.enabled)
        missing[unit]=true; ns.UpdateFrameCastbar(frame); clear(frame); missing[unit]=nil
        current[unit].duration=nil; ns.UpdateFrameCastbar(frame); clear(frame)
        current[unit]=nil
    end
end
local player=ns.frames.player
player.displayUnit="vehicle"
current.vehicle={mode="cast",name="Vehicle",texture=456,lock=false,duration=secret}
ns.UpdateFrameCastbar(player)
assert(player.Castbar.Icon.texture==456 and player.Castbar.Text.text=="Vehicle")
player.displayUnit=nil; ns.UpdateFrameCastbar(player); clear(player)
ns.RefreshCastbars()
assert(created==count and bindings==8, "no allocations while refreshing")
print("PASS: castbar presentation, eight frames, cast/channel/empower, restricted sinks, cleanup, vehicle routing")
