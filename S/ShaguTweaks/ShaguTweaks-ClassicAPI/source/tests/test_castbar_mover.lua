local root=(arg[1] or '.')..'/'
local methods={}
local frames={}
local function object()
 local f=setmetatable({scripts={}}, {__index=function(t,k) return methods[k] or function() end end})
 table.insert(frames,f);return f
end
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:CreateTexture() return object() end
function methods:CreateFontString() return object() end
function methods:SetPoint(...) self.point=arg end
function methods:ClearAllPoints() self.point=nil end
function methods:SetVertexColor(...)self.tint=arg end
UIParent=object();CastingBarFrame=object()
CreateFrame=function(_,name) local f=object();if name then _G[name]=f end;return f end
ShaguTweaks={T=setmetatable({},{__index=function(t,k) return k end}),GetGlobalEnv=function() return _G end}
dofile(root..'api.lua')
local keys=false
ShaguTweaks.API.AreMoveModifiersDown=function()return keys end
function ShaguTweaks:register() error('Cast-bar checkbox must not be registered') end
ShaguTweaks_config={['Movable Cast Bar']=0,CastBarPosition={123,234}}
local f=assert(io.open(root..'main.lua'));local source=f:read('*a');f:close();assert(loadstring(source))
local a=assert(string.find(source,'  if expansion == "vanilla" and ShaguTweaks.EnableCastBarMover then',1,true))
local b=assert(string.find(source,'\n  end',a,true))
local initialize=assert(loadstring('local expansion="vanilla"\n'..string.sub(source,a,b+5)))
dofile(root..'mods/castbar-move.lua')
initialize()
assert(ShaguTweaksCastBarMover)
assert(CastingBarFrame.point[4]==123 and CastingBarFrame.point[5]==234)
CastingBarFrame:SetPoint('BOTTOM',UIParent,'BOTTOM',1,2)
assert(CastingBarFrame.point[4]==123)
local mover=ShaguTweaksCastBarMover
local listener
for _,frame in ipairs(frames)do if frame~=mover and frame.scripts.OnEvent then listener=frame end end
for _,palette in ipairs({{r=.3,g=.3,b=.3,a=.9},{r=1,g=.78,b=.4,a=1},{r=1,g=1,b=1,a=1}})do
 ShaguTweaks.UITint=palette
 event='MODIFIER_STATE_CHANGED';keys=true;listener.scripts.OnEvent()
 assert(mover.border.tint[1]==palette.r and mover.border.tint[2]==palette.g and mover.border.tint[4]==palette.a)
 keys=false;listener.scripts.OnEvent()
end
initialize();assert(ShaguTweaksCastBarMover==mover)
arg1='RightButton';mover.scripts.OnMouseUp()
assert(not ShaguTweaks_config.CastBarPosition and CastingBarFrame.point[5]==60)
print('Always-on cast-bar mover: old disabled flag ignored, no checkbox, saved position, idempotent initialization and reset passed')
