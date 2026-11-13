local root=(arg[1] or '.')..'/'
assert(loadfile(root..'mods/item-colors.lua'))
local file=assert(io.open(root..'mods/item-colors.lua'));local source=file:read('*a');file:close()
local cut=assert(string.find(source,'function Engine:Install()',1,true))
local function Check(nativeTimer)
 local env=assert(loadfile(root..'tests/fixtures/module_mock.lua'))()()
 local qualities,live,queued={},{},{}
 local refreshes,hideHooks=0,0
 env.ShaguTweaks.API.eventutils=true
 env.ShaguTweaks.API.timer=nativeTimer
 env.C_EventUtils={IsEventValid=function()return true end}
 env.ShaguTweaks.API.GetItemQualityByID=function(id)return qualities[id]end
 env.ShaguTweaks.API.GetItemInfoInstant=function()return nil,nil,nil,nil,nil,0 end
 env.GetItemQualityColor=function(q)return q/10,.5,1 end
 env.ShaguTweaks.AddBorder=function(button)
  if not rawget(button,'ShaguTweaks_border') then
   button.ShaguTweaks_border={SetBackdropBorderColor=function(self,r,g,b,a)self.r,self.a=r,a end}
  end
  return button.ShaguTweaks_border
 end
 env.ShaguTweaks.HookScript=function(button,script,callback)
  hideHooks=hideHooks+1;assert(script=='OnHide');button.scripts[script]=callback
 end
 local function defer(callback)table.insert(queued,callback)end
 env.ShaguTweaks.API.Defer=defer;env.ShaguTweaks.QueueFunction=defer
 local chunk=assert(loadstring(string.sub(source,1,cut-1)..'return SetVisualColor, Engine, mailTradeOptions'))
 setfenv(chunk,env);local paint,engine,opts=chunk()
 engine.borders=true
 engine.RefreshAll=function()
  refreshes=refreshes+1
  for slot,id in pairs(live) do if slot:IsVisible() then paint(slot,id,opts) end end
 end
 local function button(id)
  local slot=env.CreateFrame('Button');live[slot]=id;paint(slot,id,opts);return slot
 end
 local a=button(100);local events=env.frames[2]
 local b=button(100)
 assert(events.events.GET_ITEM_INFO_RECEIVED and a.ShaguTweaks_border.a==0)
 paint(a,100,opts);assert(hideHooks==2,'one hide hook per cold button')
 local function reply(id,success)
  env.arg2=success;env.Invoke(events,'OnEvent','GET_ITEM_INFO_RECEIVED',id);env.arg2=nil
 end
 local function flush()
  local work=queued;queued={}
  for _,callback in ipairs(work)do callback()end
 end
 reply(999,true);assert(table.getn(queued)==0)
 qualities[100]=3;reply(100,true);reply(100,true)
 assert(table.getn(queued)==1 and not events.events.GET_ITEM_INFO_RECEIVED)
 flush();assert(refreshes==1 and a.ShaguTweaks_border.r==.3 and b.ShaguTweaks_border.r==.3)
 -- Warm items need neither an event listener nor a new hide hook.
 button(100);assert(not events.events.GET_ITEM_INFO_RECEIVED and hideHooks==2)
 -- Slot reused before the old reply: refresh reads the new identity.
 live[a]=200;paint(a,200,opts)
 live[a]=100 -- native slot changed, its ordinary paint has not run yet
 qualities[200]=4;reply(200,1);flush()
 assert(a.ShaguTweaks_border.r==.3,'old reply must not paint old quality')
 -- Removed and hidden slots clear pending state and never resurrect a border.
 live[a]=300;paint(a,300,opts);live[a]=nil;paint(a,nil,opts)
 reply(300,true);assert(table.getn(queued)==0 and a.ShaguTweaks_border.a==0)
 live[a]=400;paint(a,400,opts);a.visible=false;env.Invoke(a,'OnHide')
 assert(not events.events.GET_ITEM_INFO_RECEIVED)
 reply(400,true);assert(table.getn(queued)==0)
 a.visible=true;live[a]=500;paint(a,500,opts);reply(500,false)
 assert(not events.events.GET_ITEM_INFO_RECEIVED and table.getn(queued)==0)
 paint(a,500,opts);reply(500,0)
 assert(not events.events.GET_ITEM_INFO_RECEIVED and table.getn(queued)==0)
 paint(a,500,opts);reply(500,nil) -- native ClassicAPI failure encoding
 assert(not events.events.GET_ITEM_INFO_RECEIVED and table.getn(queued)==0)
 -- Distinct replies in the same frame share one live refresh.
 live[a]=600;paint(a,600,opts);live[b]=700;paint(b,700,opts)
 qualities[600],qualities[700]=2,4;reply(600,true);reply(700,true)
 assert(table.getn(queued)==1);flush()
 assert(a.ShaguTweaks_border.r==.2 and b.ShaguTweaks_border.r==.4)
 assert(not events.events.GET_ITEM_INFO_RECEIVED)
 -- Disabling visuals before a deferred reply prevents repainting.
 live[a]=800;paint(a,800,opts);qualities[800]=2;reply(800,true)
 local before=refreshes;engine.borders=false;flush();assert(refreshes==before)
 -- Older clients retain their ordinary refresh behavior without this event.
 env.C_EventUtils.IsEventValid=function()return false end
 engine.borders=true;paint(a,900,opts);assert(not events.events.GET_ITEM_INFO_RECEIVED)
 -- The same retry works when only rarity glows are enabled.
 env.C_EventUtils.IsEventValid=function()return true end
 engine.borders=false;engine.glows=true
 function a:CreateTexture()
  local texture={}
  function texture:SetTexture()end
  function texture:SetBlendMode()end
  function texture:SetPoint()end
  function texture:SetVertexColor(r)self.r=r end
  function texture:Hide()self.visible=false end
  function texture:Show()self.visible=true end
  return texture
 end
 -- Keep this scenario to one visible slot.
 live[b]=nil
 for slot in pairs(live)do if slot~=a then live[slot]=nil end end
 a.ShaguTweaks_itemRarityGlow=false
 live[a]=1000;paint(a,1000,opts)
 assert(not a.ShaguTweaks_itemRarityGlow.visible)
 qualities[1000]=4;reply(1000,1);flush()
 assert(a.ShaguTweaks_itemRarityGlow.visible and a.ShaguTweaks_itemRarityGlow.r==.4)
end
Check(true);Check(false)
print('Item cache retry: cold/warm data, shared replies, live slot identities, removed/hidden items, failed replies, coalescing, disabled visuals and timer fallback passed')
