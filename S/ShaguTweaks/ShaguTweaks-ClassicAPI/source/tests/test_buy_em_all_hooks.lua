local root=(arg[1] or '.')..'/'
local env=dofile(root..'tests/fixtures/module_mock.lua')()
local api=env.ShaguTweaks.API
for _,key in ipairs({'GetItemCount','GetItemMaxStackSizeByID','GetItemFamily',
 'GetContainerNumFreeSlots','GetContainerItemID','GetContainerItemStackCount',
 'GetMerchantItemInfo','GetMerchantItemID','IsShiftKeyDown','IsControlKeyDown'}) do api[key]=function()end end
env.IsAddOnLoaded=function()return false end
env.GetLocale=function()return 'enUS'end
env.StaticPopupDialogs={}
env.MerchantFrame=env.CreateFrame();env.MerchantFrame.selectedTab=1
local native,handled,foreign=0,0,0
local lastButton,lastIgnore
env.MerchantItemButton_OnClick=function(button,ignore)
 native=native+1;lastButton,lastIgnore=button,ignore;return 'native',nil,3
end
env.Load(root..'mods/buy-em-all.lua')
local buy=env.STBuyEmAll
local realHandle=buy.HandleMerchantClick
buy.CreateUI=function()env.STBuyEmAllFrame=env.CreateFrame()end
buy.HandleMerchantClick=function()handled=handled+1;return false end
env.module:enable()
local installer=env.frames[table.getn(env.frames)]
local first=env.MerchantItemButton_OnClick
for i=1,10 do env.Invoke(installer,'OnEvent','MERCHANT_SHOW')end
assert(env.MerchantItemButton_OnClick==first)
local saved=first
env.MerchantItemButton_OnClick=function(button,ignore)
 foreign=foreign+1;return saved(button,ignore)
end
env.Invoke(installer,'OnEvent','MERCHANT_SHOW')
local a,b,c=env.MerchantItemButton_OnClick('RightButton',nil)
assert(native==1 and handled==1 and foreign==1 and a=='native' and b==nil and c==3)
assert(lastButton=='RightButton' and lastIgnore==nil)
-- Error paths must release the guard so a following click is handled normally.
buy.HandleMerchantClick=function()error('expected click failure')end
assert(not pcall(env.MerchantItemButton_OnClick,'LeftButton'))
buy.HandleMerchantClick=function()handled=handled+1;return true end
env.MerchantItemButton_OnClick('LeftButton');assert(handled==2 and native==1)
-- The single-item route must reach the predecessor with modifiers bypassed.
buy.HandleMerchantClick=realHandle
buy.GetMerchantData=function()return 'Item',123,1,1,1 end
buy.FreeBagSpace=function()return 10,20 end
api.IsShiftKeyDown=function()return true end;api.IsControlKeyDown=function()return false end
env.GetMoney=function()return 100 end
env.ChatFrameEditBox={IsVisible=function()return false end}
env.this={GetID=function()return 1 end}
env.MerchantItemButton_OnClick('RightButton')
assert(native==2 and lastButton=='LeftButton' and lastIgnore==1)
-- A foreign handler that replaces the chain entirely remains reachable too.
env.MerchantItemButton_OnClick=function()return 'replacement'end
env.Invoke(installer,'OnEvent','MERCHANT_SHOW')
buy.HandleMerchantClick=function()return false end
assert(env.MerchantItemButton_OnClick('LeftButton')=='replacement')
print('Buy Em All: immutable hook predecessors, foreign wrapper/replacement, one dispatch, error recovery, native return values and single-item routing passed')
