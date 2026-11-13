local root=(arg[1] or '.')..'/'
local f=assert(io.open(root..'mods/minimap-zoom.lua'));local source=f:read('*a');f:close()
assert(loadstring(source))
local a=assert(string.find(source,'local function FixLFTButtonDrag()',1,true))
local b=assert(string.find(source,'local module =',a,true))
local function Check(uiScale,mapScale,buttonScale)
 local env=dofile(root..'tests/fixtures/module_mock.lua')()
 env.UIParent={effective=uiScale};env.Minimap={effective=uiScale*mapScale}
 local calls=0
 local button={parent=env.Minimap,scale=buttonScale,scripts={}}
 function button:GetParent()return self.parent end
 function button:GetScale()return self.scale end
 function button:GetEffectiveScale()return self.parent.effective*self.scale end
 function button:SetParent(parent)self.parent=parent end
 function button:SetScale(scale)self.scale=scale end
 function button:GetLeft()return self.left end
 function button:GetTop()return self.top end
 function button:ClearAllPoints()self.cleared=true end
 function button:SetPoint(point,parent,relative,x,y)
  assert(point=='TOPLEFT' and parent==env.UIParent and relative=='BOTTOMLEFT')
  self.left,self.top=x,y
 end
 function button:GetScript(script)return self.scripts[script]end
 function button:SetScript(script,callback)self.scripts[script]=callback end
 local reset=function()button:SetParent(env.Minimap);button.left,button.top=-22,-14 end
 button.scripts.OnMouseUp=reset
 button.scripts.OnDragStop=function(mouse)
  assert(mouse=='LeftButton');calls=calls+1
  -- Exact native LFT XML behavior: StopMoving, then SetParent('UIParent').
  button:SetParent(env.UIParent)
 end
 button.left,button.top=1000/button:GetEffectiveScale(),650/button:GetEffectiveScale()
 env.LFTMinimapButton=button
 local chunk=assert(loadstring('local _G=ShaguTweaks.GetGlobalEnv();\n'..string.sub(source,a,b-1)..'return FixLFTButtonDrag'))
 setfenv(chunk,env);local install=chunk()
 install();local hook=button.scripts.OnDragStop;install();assert(button.scripts.OnDragStop==hook)
 local before=button:GetEffectiveScale()
 hook('LeftButton')
 assert(calls==1 and button:GetParent()==env.Minimap and button.scale==buttonScale)
 assert(math.abs(button:GetEffectiveScale()-before)<.000001)
 assert(math.abs(button:GetLeft()*before-1000)<.000001 and math.abs(button:GetTop()*before-650)<.000001)
 assert(button.scripts.OnMouseUp==reset)
 reset();assert(button.parent==env.Minimap and button.scale==buttonScale and button.left==-22)
 -- A foreign parent remains owned by its existing native/other-addon handler.
 button.parent={effective=uiScale*2};hook('LeftButton');assert(button.parent==env.UIParent)
 env.LFTMinimapButton=nil;install() -- non-Turtle clients
 env.LFTMinimapButton={GetScript=function()end};install()
end
Check(.7,1.2,1);Check(1,1.5,.8);Check(.65,2,1)
print('LFT minimap drag: native reparenting preserves inherited size and screen position, custom/UI scales, unchanged reset, foreign parent and idempotent/non-Turtle setup passed')
