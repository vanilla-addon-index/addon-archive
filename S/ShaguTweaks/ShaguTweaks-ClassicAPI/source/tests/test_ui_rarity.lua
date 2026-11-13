local root=(arg[1] or '.') .. '/'
for _,p in ipairs({'mods/item-colors.lua','mods/loot-quality.lua','mods/dark-ui-elements.lua'}) do assert(loadfile(root..p)) end
local f=assert(io.open(root..'mods/item-colors.lua','r')); local source=f:read('*a'); f:close()
ShaguTweaks={T={},API={}}
function ShaguTweaks.GetGlobalEnv() return _G end
function ShaguTweaks:register(t) return t end
function ShaguTweaks.API.GetItemQualityByID(id) return id end
function ShaguTweaks.API.GetItemInfoInstant() return nil,nil,nil,nil,nil,0 end
function GetItemQualityColor(q) return q/10,.5,1-q/10 end
function ShaguTweaks.AddBorder(button)
 if not button.ShaguTweaks_border then
  button.ShaguTweaks_border={}
  function button.ShaguTweaks_border:SetBackdropBorderColor(r,g,b,a) self.r,self.g,self.b,self.a=r,g,b,a end
 end
 return button.ShaguTweaks_border
end
local cut=assert(string.find(source,'function Engine:Install()',1,true))
local result=assert(loadstring(string.sub(source,1,cut-1)..'return { SetVisualColor, mailTradeOptions, mailTradeOptions, Engine }'))()
local paint,opts,fallback,engine=result[1],result[2],result[3],result[4]
engine.borders=true
local button={}
for q=0,5 do
 paint(button,q,opts)
 local b=button.ShaguTweaks_border
 assert(b.r==q/10 and b.g==.5 and b.b==1-q/10 and b.a==1)
 assert(b.stPreserveRarityColor)
end
paint(button,nil,opts); assert(button.ShaguTweaks_border.a==0)
paint(button,nil,opts,3); assert(button.ShaguTweaks_border.r==.3)
engine.borders=false; paint(button,3,fallback); assert(button.ShaguTweaks_border.a==0 and not button.ShaguTweaks_border.stPreserveRarityColor)
engine.borders=true; local otherButton={}; paint(otherButton,3,{quest=false}); assert(otherButton.ShaguTweaks_border.a==1)
-- Exercise the actual outgoing-mail reader for base mail and TurtleMail.
local first=assert(string.find(source,'  local function RefreshSendMail()',1,true))
local last=assert(string.find(source,'  local function RefreshTrade()',first,true))
Engine=engine; engine.borders=true
mailTradeOptions=opts; mailTradeFallbackOptions=fallback
API={GetItemIDFromLink=function() return 9 end, GetContainerItemID=function(b,s) return b*100+s end}
function GetSendMailItemLink() return 'item:9' end
function GetSendMailItem() return 'Item','icon',1,2 end
SendMailPackageButton={}; MailAttachment1={item={2,7}}; MailAttachment2={}
local seen={}
function SetVisualColor(b,id,o,q) seen[b]={id=id,quality=q} end
local refresh=assert(loadstring(string.sub(source,first,last-1)..'return RefreshSendMail'))()
refresh(); assert(seen[SendMailPackageButton].id==9 and seen[SendMailPackageButton].quality==2)
assert(seen[MailAttachment1].id==207 and seen[MailAttachment2].id==nil)
MailAttachment1.item=nil; refresh(); assert(seen[MailAttachment1].id==nil)
print('Lua 5.0: all changed files parse; rarity 0-5, empty-slot cleanup, option disable and native/TurtleMail item data passed')
-- Exercise the real per-button hooks with the global refresh absent/replaced.
local start=assert(string.find(source,'  local function RefreshAttachmentTexture',1,true))
local finish=assert(string.find(source,'  local function RefreshTradeSkill',start,true))
local installed=0
function hooksecurefunc(button,name,callback)
 installed=installed+1
 local old=button[name]
 button[name]=function(self,texture) old(self,texture); callback(self,texture) end
end
MailAttachment1={}; MailAttachment2={}
function MailAttachment1:SetNormalTexture(texture) self.texture=texture end
MailAttachment2.SetNormalTexture=MailAttachment1.SetNormalTexture
local hook=assert(loadstring(string.sub(source,start,finish-1)..'return HookAttachmentTextures'))()
hook(); hook(); assert(installed==2)
function SetVisualColor(button,id,o,q) paint(button,id,o,q) end
MailAttachment1.item={0,3}; MailAttachment1:SetNormalTexture('icon')
assert(MailAttachment1.ShaguTweaks_border.a==1 and MailAttachment1.ShaguTweaks_border.r==.3)
-- TurtleMail clears .item AFTER SetNormalTexture(nil); this must still clear.
MailAttachment1:SetNormalTexture(nil)
assert(MailAttachment1.ShaguTweaks_border.a==0)
MailAttachment1.item=nil
MailAttachment2.item={0,4}; MailAttachment2:SetNormalTexture('icon')
assert(MailAttachment2.ShaguTweaks_border.a==1 and MailAttachment2.ShaguTweaks_border.r==.4)
MailAttachment2.item=nil; MailAttachment2:SetNormalTexture(nil)
assert(MailAttachment2.ShaguTweaks_border.a==0)
print('Direct texture hooks: immediate add/remove, both item-clear orderings and idempotent install passed')
-- Read each trade column's own displayed item metadata, with asymmetric offers.
function API.GetItemIDFromLink(link) local _,_,id=string.find(link or '', 'item:(%d+)'); return id and tonumber(id) end
function GetItemInfo() return nil end
local a=assert(string.find(source,'  local function PaintTradeSlot',1,true))
local b=assert(string.find(source,'  -- TurtleMail replaces',a,true))
local offeredPlayer,offeredTarget={},{}
function GetItemInfo(link) local quality=({['item:3']=3,['item:2']=2,['item:4']=4})[link]; return nil,link,quality end
function GetTradePlayerItemLink(i) return ({Blue='item:3',Green='item:2',Purple='item:4'})[offeredPlayer[i]] end
function GetTradeTargetItemLink(i) return ({Blue='item:3',Green='item:2',Purple='item:4'})[offeredTarget[i]] end
function GetTradePlayerItemInfo(i) return offeredPlayer[i] end
function GetTradeTargetItemInfo(i) return offeredTarget[i] end
for i=1,7 do _G['TradePlayerItem'..i..'ItemButton']={}; _G['TradeRecipientItem'..i..'ItemButton']={} end
local funcs=assert(loadstring(string.sub(source,a,b-1)..'return { RefreshTrade, RefreshPlayerTradeSlot, RefreshTargetTradeSlot, PaintTradeSlot }'))()
local refreshAll,refreshPlayer,refreshTarget=funcs[1],funcs[2],funcs[3]
offeredTarget[1]='Blue'; offeredTarget[2]='Green'
refreshAll()
assert(TradePlayerItem1ItemButton.ShaguTweaks_border.a==0)
assert(TradeRecipientItem1ItemButton.ShaguTweaks_border.r==.3 and TradeRecipientItem2ItemButton.ShaguTweaks_border.r==.2)
offeredPlayer[1]='Purple'; refreshPlayer(1)
assert(TradePlayerItem1ItemButton.ShaguTweaks_border.r==.4 and TradeRecipientItem1ItemButton.ShaguTweaks_border.r==.3)
offeredTarget[1]=nil; refreshTarget(1)
assert(TradeRecipientItem1ItemButton.ShaguTweaks_border.a==0 and TradePlayerItem1ItemButton.ShaguTweaks_border.a==1)
funcs[4](TradePlayerItem1ItemButton,nil); assert(TradePlayerItem1ItemButton.ShaguTweaks_border.a==0)
print('Trade: asymmetric offers, correct columns, independent add/remove and close cleanup passed')
-- Loot Quality must neither enable nor disable Item Rarity Borders.
local registered={}
function ShaguTweaks:register(module) registered[module.title]=module; return module end
setmetatable(ShaguTweaks.T,{__index=function(t,k) return k end})
local dummy={}
function dummy:SetTexture() end
function dummy:SetPoint() end
function dummy:SetAllPoints() end
function dummy:SetDrawLayer() end
function dummy:SetBlendMode() end
function dummy:Hide() end
function dummy:UnregisterAllEvents() end
function dummy:RegisterEvent() end
function dummy:SetScript() end
LootFrame={}
function LootFrame:CreateTexture() return dummy end
function LootFrame:GetRegions() end
function CreateFrame() return dummy end
dofile(root..'mods/loot-quality.lua')
local loot=registered['Loot Quality']; assert(loot)
engine.borders=false; loot:enable(); assert(not engine.borders); loot:disable(); assert(not engine.borders)
engine.borders=true; loot:enable(); assert(engine.borders); loot:disable(); assert(engine.borders)
print('Option independence: toggling Loot Quality leaves Item Rarity Borders on/off state unchanged')
-- Coalesce bursts through the native timer, with an idle fallback queue.
local x=assert(string.find(source,'  local sendMailRefreshPending',1,true))
local y=assert(string.find(source,'  local function PaintTradeSlot',x,true))
local calls,runs=0,0
local scheduled
API.timer=true
function API.Defer(callback) calls=calls+1; scheduled=callback end
function ShaguTweaks.QueueFunction(callback) calls=calls+1; scheduled=callback end
function RefreshSendMail() runs=runs+1 end
local visible=true
MailFrame={IsShown=function() return visible end}
local queue=assert(loadstring(string.sub(source,x,y-1)..'return QueueSendMailRefresh'))()
queue(); queue(); queue(); assert(calls==1 and runs==0)
scheduled(); assert(runs==1)
API.timer=false
queue(); queue(); assert(calls==2)
visible=false; scheduled(); assert(runs==1)
visible=true; queue(); scheduled(); assert(calls==3 and runs==2)
print('Mail refresh batching, native timer/fallback and hidden-window skip passed')
