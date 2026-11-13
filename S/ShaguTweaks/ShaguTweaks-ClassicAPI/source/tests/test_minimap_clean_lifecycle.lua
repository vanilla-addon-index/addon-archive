local root=(arg[1] or '.')..'/'
local env=dofile(root..'tests/fixtures/module_mock.lua')()
local function button(name,clickable)
 return {alpha=1,GetName=function()return name end,
  GetScript=function(self,k)if k=='OnClick' and self.clickable then return function()end end end,
  SetAlpha=function(self,a)self.alpha=a end,clickable=clickable}
end
local first=button('FirstAddon',true)
local ignored=button('LFT_Minimap',true)
local children={first,ignored}
local scans,now,over=0,0,false
env.Minimap={GetNumChildren=function()return table.getn(children)end,
 GetChildren=function()scans=scans+1;return unpack(children)end}
env.GetTime=function()return now end
env.ShaguTweaks.API={regionmouseover=true,IsMouseOver=function()return over end}
env.Load(root..'mods/minimap-clean.lua');env.module:enable()
local frame=env.module.frame
local function tick(time)now=time;env.Invoke(frame,'OnUpdate',nil,.1)end
tick(0);tick(4);assert(first.alpha==0 and ignored.alpha==1)
local before=scans
for i=1,50 do tick(4+i*.1)end
assert(scans==before) -- no subtree rebuild while the count is unchanged
local late=button('LateAddon',true);table.insert(children,late)
tick(10);assert(late.alpha==0 and first.alpha==0 and ignored.alpha==1)
-- Replaced children at the same count are invalidated when an addon loads.
local replacement=button('ReplacementAddon',true);children[3]=replacement
env.Invoke(frame,'OnEvent','ADDON_LOADED');tick(11);assert(replacement.alpha==0)
over=true;tick(12);assert(first.alpha==1 and replacement.alpha==1)
over=false;tick(13);tick(17);assert(replacement.alpha==0)
env.module:disable();assert(not frame.scripts.OnUpdate and not frame.events.ADDON_LOADED)
assert(first.alpha==1 and replacement.alpha==1)
env.module:enable();assert(frame.events.ADDON_LOADED and frame.scripts.OnUpdate)
assert(env.module.frame==frame and replacement.alpha==1)
print('Minimap Clean: late/replaced buttons inherit state, unchanged cache avoids traversal, LFT exclusion, hover delay and disable/re-enable passed')
