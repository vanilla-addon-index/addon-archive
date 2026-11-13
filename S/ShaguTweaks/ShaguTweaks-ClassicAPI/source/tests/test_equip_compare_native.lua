local root=(arg[1] or '.')..'/'
local frames,modules,pending={},{},{}
local shift=true
local methods={}
local function noop() end
local function frame(name)
 local f=setmetatable({name=name,scripts={},events={},shown=false}, {__index=function(t,k)
  return methods[k] or (string.find(k,'^[A-Z]') and noop or nil)
 end})
 table.insert(frames,f);return f
end
function methods:SetOwner(owner) self.owner=owner;self.nativeContent=nil end
function methods:GetOwner() return self.owner end
function methods:GetBackdropColor() return unpack(self.background or {0,0,0,.5}) end
function methods:SetBackdropColor(r,g,b,a) self.background={r,g,b,a} end
function methods:ClearAllPoints() self.point=nil end
function methods:SetPoint(...) self.point=arg end
function methods:GetPoint() if self.point then return unpack(self.point) end return 'TOPLEFT',UIParent end
function methods:GetItem() if self.link then return 'Item',self.link end end
function methods:HookScript(k,v) self.scripts[k]=v end
function methods:RegisterEvent(k) self.events[k]=true end
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:IsShown() return self.shown end
function methods:Show()
 local changed=not self.shown;self.shown=true
 if changed and self.scripts.OnShow then self.scripts.OnShow() end
end
function methods:Hide()
 local changed=self.shown
 self.hides=(self.hides or 0)+1;self.shown=false;self.owner=nil
 -- Stock source-tooltip hide scripts also hide the shared shopping tooltips.
 if self==GameTooltip or self==ItemRefTooltip then ShoppingTooltip1:Hide();ShoppingTooltip2:Hide() end
 if changed and self.scripts.OnHide then self.scripts.OnHide() end
end
local compared,builds={},0
function methods:SetHyperlinkCompareItem(link,index,button,source)
 builds=builds+1
 assert(source.link==link and button==true)
 compared[index]=link
 self.nativeContent=link
 -- Simulate native/third-party callbacks during comparison construction.
 source.scripts.OnTooltipCleared();source.scripts.OnTooltipSetItem()
 return index==1 or source.two
end
UIParent=frame('UIParent');UIParent.GetEffectiveScale=function() return 1 end
local hover=frame('BagshuiItemButton')
GameTooltip=frame('GameTooltip');ItemRefTooltip=frame('ItemRefTooltip')
ShoppingTooltip1=frame('ShoppingTooltip1');ShoppingTooltip2=frame('ShoppingTooltip2')
CreateFrame=function() return frame() end
GetCursorPosition=function() return 100 end;GetScreenWidth=function() return 1000 end
ShaguTweaks={T=setmetatable({},{__index=function(t,k) return k end}),GetGlobalEnv=function() return getfenv(0) end,
 API={tooltipsetitem=true,modifierstate=true,timer=true,IsShiftKeyDown=function() return shift end,
 Defer=function(callback) table.insert(pending,callback) end},HookAddonOrVariable=function(_,callback) callback() end}
function ShaguTweaks:register(m) modules[m.title]=m;return m end
dofile(root..'mods/equip-compare.lua');local module=modules['Equip Compare'];module:enable()
local function flush()
 local queue=pending;pending={}
 for _,callback in ipairs(queue) do callback() end
 assert(table.getn(pending)==0,'Comparison construction scheduled a recursive refresh')
end
ShaguTweaks_config={['Darkened UI']=1}
GameTooltip.background={.2,.2,.2,1}
GameTooltip:SetOwner(hover);GameTooltip.link='item:123:enchant:randomsuffix';GameTooltip.two=true;GameTooltip:Show()
GameTooltip.scripts.OnTooltipSetItem();GameTooltip.scripts.OnTooltipSetItem();assert(table.getn(pending)==1)
flush();assert(compared[1]==GameTooltip.link and compared[2]==GameTooltip.link)
assert(ShoppingTooltip1:IsShown() and ShoppingTooltip2:IsShown())
assert(ShoppingTooltip1.background[1]==.2 and ShoppingTooltip1.background[4]==1)
assert(ShoppingTooltip2.background[1]==.2 and ShoppingTooltip2.background[4]==1)
assert(ShoppingTooltip2.point[2]==ShoppingTooltip1)
assert(ShoppingTooltip1:GetOwner()==hover and ShoppingTooltip2:GetOwner()==hover)
local beforeBuild,beforeHide=builds,ShoppingTooltip1.hides
for i=1,50 do
 GameTooltip.scripts.OnTooltipCleared();GameTooltip.scripts.OnTooltipSetItem()
 assert(ShoppingTooltip1:IsShown())
 flush()
end
assert(builds==beforeBuild and ShoppingTooltip1.hides==beforeHide,'Unchanged tooltip blinked/rebuilt')
-- Bag slots can hide/re-show the source every refresh. The prior regression
-- tested Clear/Set only and therefore missed this separate lifecycle.
for i=1,50 do
 GameTooltip:Hide()
 assert(not ShoppingTooltip1:IsShown()) -- native hide side effect
 assert(not ShoppingTooltip1:GetOwner()) -- native Hide clears ownership
 GameTooltip:SetOwner(hover)
 GameTooltip.scripts.OnTooltipCleared()
 GameTooltip.scripts.OnTooltipSetItem()
 GameTooltip:Show()
 assert(ShoppingTooltip1:IsShown() and ShoppingTooltip2:IsShown(),'Cached comparison was not restored synchronously')
 assert(ShoppingTooltip1:GetOwner()==hover and ShoppingTooltip1.nativeContent==GameTooltip.link)
 flush()
end
assert(builds==beforeBuild+100,'Lost native ownership must refill each hidden comparison once')
-- Independently hidden comparisons also recover when the source emits no event.
beforeBuild=builds;ShoppingTooltip1:Hide();flush()
assert(ShoppingTooltip1:IsShown() and ShoppingTooltip1:GetOwner()==hover and builds==beforeBuild+1)
arg1='LSHIFT';shift=false;module.nativeModifier.scripts.OnEvent();assert(not ShoppingTooltip1:IsShown())
shift=true;module.nativeModifier.scripts.OnEvent();assert(ShoppingTooltip1:IsShown())
GameTooltip.two=false;event='UNIT_INVENTORY_CHANGED';arg1='player';module.nativeModifier.scripts.OnEvent();flush()
assert(ShoppingTooltip1:IsShown() and not ShoppingTooltip2:IsShown())
beforeBuild=builds;GameTooltip.link='item:789:new-enchant';GameTooltip.scripts.OnTooltipSetItem();flush()
assert(builds==beforeBuild+2 and compared[1]==GameTooltip.link)
GameTooltip:Hide();flush();assert(not ShoppingTooltip1:IsShown())
ItemRefTooltip.link='item:456';ItemRefTooltip:Show();ItemRefTooltip.scripts.OnTooltipSetItem();flush()
assert(ShoppingTooltip1.owner==UIParent and ShoppingTooltip1.point[2]==ItemRefTooltip)
GameTooltip.scripts.OnTooltipCleared();flush();assert(ShoppingTooltip1:IsShown()) -- another tooltip cannot clear the active owner's comparisons
ItemRefTooltip.link=nil;ItemRefTooltip.scripts.OnTooltipCleared();flush();assert(not ShoppingTooltip1:IsShown())
local count=table.getn(frames);module:enable();assert(table.getn(frames)==count)
ItemRefTooltip.scripts.OnTooltipSetItem();ItemRefTooltip:Hide();flush();assert(not ShoppingTooltip1:IsShown())
-- Missing newer comparison methods select the existing compatibility path.
ShoppingTooltip1.SetHyperlinkCompareItem=false;module.installed=nil;module.nativeModifier=nil
ShaguTweaks.API.iteminventorytype=true;ShaguTweaks.API.iteminventoryslotkey=true
module:enable();assert(module.installed and not module.nativeModifier)
print('Equip Compare: links/Shift/invalidation, unchanged refresh reuse, hidden-owner loss/refill, hovered-button ownership, independent comparison-hide recovery, reentrancy and fallback passed')
