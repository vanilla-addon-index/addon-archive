local root=(arg[1] or '.')..'/'
local made,frames=0,{}
local methods={}
local function new(name)
 made=made+1
 local f=setmetatable({scripts={},events={},shown=true},{__index=function(t,k) return methods[k] or function() end end})
 if name then _G[name]=f end
 table.insert(frames,f);return f
end
function methods:SetBackdrop(v) self.backdrop=v end
function methods:SetBackdropBorderColor(...) self.rim=arg end
function methods:SetVertexColor(...) self.tint=arg end
function methods:SetTexture(v) self.texture=v end
function methods:SetWidth(v) self.width=v end
function methods:SetFontObject(v) self.font=v end
function methods:SetText(v) self.text=v end
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:RegisterEvent(k) self.events[k]=true end
function methods:UnregisterAllEvents() self.events={} end
function methods:IsShown() return self.shown end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:CreateTexture() return new() end
function methods:CreateFontString() return new() end
CreateFrame=function(_,name) return new(name) end
UIParent=new();GameFontNormalLarge='NormalLarge';GameFontHighlightSmall='HighlightSmall'
SlashCmdList={};ShaguTweaks_config={}
local module
ShaguTweaks={T=setmetatable({},{__index=function(t,k) return k end}),GetGlobalEnv=function() return _G end}
dofile(root..'api.lua')
function ShaguTweaks:register(m) module=m;return m end
dofile(root..'mods/loss-of-control.lua')
local baseline=made;module:enable();assert(made==baseline) -- unavailable API stays dormant
local data={locType='STUN',timeRemaining=4,duration=8,iconTexture='stun',displayText='Hammer of Justice'}
C_LossOfControl={GetActiveLossOfControlDataCount=function() return data and 1 or 0 end,GetActiveLossOfControlData=function() return data end}
module:enable()
local f=ShaguTweaksLossOfControl
assert(f.backdrop.edgeFile=='Interface\\Tooltips\\UI-Tooltip-Border')
assert(f.border.backdrop.edgeFile==f.backdrop.edgeFile)
assert(f.rim[1]==.6 and f.border.rim[1]==.6 and f.icon.tint[1]==1)
assert(f.bar.texture=='Interface\\TargetingFrame\\UI-StatusBar' and f.bar.width==107)
assert(f.title.font==GameFontNormalLarge and f.detail.text=='Hammer of Justice')
local driver
for _,frame in ipairs(frames) do if frame.events.LOSS_OF_CONTROL_UPDATE then driver=frame end end
local count=made
for _,color in ipairs({{r=.2,g=.2,b=.2,a=1},{r=.8,g=.62,b=.32,a=1}}) do
 ShaguTweaks.UIBorder=color
 event='LOSS_OF_CONTROL_UPDATE';driver.scripts.OnEvent()
 assert(f.rim[1]==color.r and f.rim[2]==color.g and f.border.rim[3]==color.b)
 assert(f.icon.tint[1]==1 and f.bar.tint[1]==1 and f.bar.tint[2]==.2)
 assert(made==count) -- palette application never allocates additional widgets
end
data=nil;driver.scripts.OnEvent();assert(not f.shown)
module:disable();assert(not next(driver.events))
print('Loss of Control: tooltip rims, classic fonts/status fill, default/dark/gold palettes, native icon color, API guard and hide/disable passed')
