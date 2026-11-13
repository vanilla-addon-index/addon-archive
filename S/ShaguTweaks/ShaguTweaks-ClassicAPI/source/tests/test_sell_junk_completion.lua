local root=(arg[1] or '.')..'/'
assert(loadfile(root..'mods/sell-junk.lua'))
local env=assert(loadfile(root..'tests/fixtures/module_mock.lua'))()()
local now,count,money,sales,queries,enabled,messages=0,3,100,0,0,true,{}
env.GetTime=function()return now end
env.GetMoney=function()return money end
env.floor,env.mod=math.floor,math.mod
env.ShaguTweaks.API.GetNumJunkItems=function()queries=queries+1;return count end
env.ShaguTweaks.API.SellAllJunkItems=function()sales=sales+1 end
env.MerchantFrame={selectedTab=1}
env.MerchantFrame_Update=function()end
env.MerchantRepairText={SetText=function()end}
env.MerchantRepairItemButton={IsShown=function()return false end}
env.DEFAULT_CHAT_FRAME.AddMessage=function(_,text)table.insert(messages,text)end
env.Load(root..'mods/sell-junk.lua');env.module:enable()
local driver=env.frames[1];local button=driver.button
-- Model native OnHide delivery without changing the shared fixture.
function driver:Hide()
 local visible=self.visible;self.visible=false
 if visible and self.scripts.OnHide then env.Invoke(self,'OnHide') end
end
function button:Enable()enabled=true end
function button:Disable()enabled=false end
local function tick(dt)
 now=now+dt
 if driver:IsVisible() then env.Invoke(driver,'OnUpdate',nil,dt) end
end
local function start()
 env.Invoke(driver,'OnEvent','MERCHANT_SHOW')
 env.Invoke(button,'OnClick')
 assert(driver:IsVisible() and not enabled)
end
start();local before=queries
for i=1,9 do tick(.01) end
assert(queries==before,'must not scan every frame')
tick(.02);assert(queries==before+1)
tick(4);assert(driver:IsVisible())
tick(1);assert(not driver:IsVisible() and enabled and sales==1)
assert(not driver.started and not driver.progressUntil and table.getn(messages)==0)
-- Progress extends the deadline, including queues taking over five seconds.
start();tick(4);count=2;money=110;tick(.2)
tick(4);assert(driver:IsVisible())
count=0;money=140;tick(.2)
assert(not driver:IsVisible() and not enabled and sales==2)
assert(table.getn(messages)==1)
-- Merchant close cancels waiting; later attempts start a fresh deadline.
count=2;start();tick(1)
env.Invoke(driver,'OnEvent','MERCHANT_CLOSED')
assert(not driver:IsVisible() and not driver.started)
now=now+20;start();tick(.2);assert(driver:IsVisible())
tick(5);assert(not driver:IsVisible() and enabled and sales==4)
count=0;env.Invoke(button,'OnClick')
assert(not driver:IsVisible() and sales==4)
print('Sell Junk: throttled completion, stalled-sale timeout, progress renewal, profit once, merchant close and clean retry passed')
