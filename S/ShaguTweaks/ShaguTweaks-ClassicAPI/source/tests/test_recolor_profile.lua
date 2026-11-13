local root=(arg[1] or '.')..'/'
local f=assert(io.open(root..'mods/dark-ui-elements.lua'));local source=f:read('*a');f:close();assert(loadstring(source))
local a=assert(string.find(source,'local function IsExcludedFrame',1,true))
local b=assert(string.find(source,'local ADDON_PREFIXES =',a,true))
ShaguTweaks={}
local prefix='local tint={r=.3,g=.3,b=.3,a=.9};local edge=tint;local backgrounds,borders,regionskips={},{},{};'
local darken=assert(loadstring(prefix..string.sub(source,a,b-1)..'return DarkenFrame'))()
local function frame(name)
 return {GetName=function() return name end,GetChildren=function() end,GetRegions=function() end,
 SetBackdropBorderColor=function() end}
end
local parent,child=frame('Parent'),frame('Child')
parent.GetChildren=function() return child end
darken(parent);assert(not ShaguTweaks.RecolorCapture)
local c={roots={},rootIndex={},seen={},frameVisits=0,uniqueFrames=0,repeatVisits=0,borderWrites=0,textureWrites=0}
ShaguTweaks.RecolorCapture=c
darken(parent);darken(parent)
assert(c.frameVisits==4 and c.uniqueFrames==2 and c.repeatVisits==2 and c.borderWrites==4)
assert(table.getn(c.roots)==1 and c.roots[1].calls==2 and c.roots[1].frames==4 and c.roots[1].tables==8)
ShaguTweaks.RecolorCapture=nil;darken(parent);assert(c.frameVisits==4)
print('Recolor diagnostics: opt-in counters, root versus recursive calls, unique/repeat visits, traversal table counts and inactive cleanup passed')
