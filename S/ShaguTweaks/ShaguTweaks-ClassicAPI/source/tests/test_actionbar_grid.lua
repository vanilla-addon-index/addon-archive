local root=(arg[1] or '.')..'/'
local update,events
ShaguTweaks={GetGlobalEnv=function() return getfenv(0) end,API={IsSupportedRuntime=function() return true end}}
function ShaguTweaks.hooksecurefunc(object,key,fn)
 if type(object)=='string' then update=key;return end
 local original=object[key]
 object[key]=function(self,...) original(self,unpack(arg));fn(self,unpack(arg)) end
end
function ShaguTweaks.HookScript(frame,name,fn) frame.scripts[name]=fn end
local function button(action)
 return {action=action,showgrid=0,shown=false,Show=function(self) self.shown=true end,Hide=function(self) self.shown=false end}
end
BonusActionBarFrame={visible=false,scripts={},IsVisible=function(self) return self.visible end}
ActionButton1=button(true);ActionButton2=button(true);ActionButton3=button(false)
BonusActionButton1=button(false)
ActionButton_Update=function() if this.action or this.showgrid>0 then this:Show() else this:Hide() end end
CreateFrame=function() events={RegisterEvent=function() end,SetScript=function(self,_,fn) self.fire=fn end};return events end
ActionButton_ShowGrid=function(b) b.showgrid=b.showgrid+1;b:Show() end
ActionButton_HideGrid=function(b) b.showgrid=b.showgrid-1;if b.showgrid==0 and not b.action then b:Hide() end end
PickupAction=function() error('must not change action contents') end
PlaceAction=PickupAction
dofile(root..'mods/actionbar-grid.lua')
ALWAYS_SHOW_MULTIBARS='1';events.fire();update()
assert(ActionButton1.showgrid==1 and ActionButton1.shown and ActionButton3.shown and BonusActionButton1.shown)
BonusActionBarFrame.visible=true;this=BonusActionBarFrame;BonusActionBarFrame.scripts.OnShow()
assert(not ActionButton1.shown and not ActionButton2.shown and not ActionButton3.shown)
assert(this==BonusActionBarFrame and BonusActionButton1.shown)
-- Native refreshes and drag-grid events cannot re-expose caster icons below
-- a transparent, empty form slot. Show hooks leave counters untouched.
this=ActionButton1;ActionButton_Update();assert(not ActionButton1.shown)
ActionButton_ShowGrid(ActionButton1);assert(ActionButton1.showgrid==2 and not ActionButton1.shown)
ALWAYS_SHOW_MULTIBARS=0;update();assert(ActionButton1.showgrid==1 and not ActionButton1.shown)
ActionButton_HideGrid(ActionButton1);assert(ActionButton1.showgrid==0 and not ActionButton1.shown)
assert(not BonusActionButton1.shown)
BonusActionBarFrame.visible=false;this=BonusActionBarFrame;BonusActionBarFrame.scripts.OnHide()
assert(ActionButton1.shown and ActionButton2.shown and not ActionButton3.shown and this==BonusActionBarFrame)
ALWAYS_SHOW_MULTIBARS=1;update();assert(ActionButton3.shown)
for i=1,3 do
 BonusActionBarFrame.visible=true;BonusActionBarFrame.scripts.OnShow();assert(not ActionButton1.shown)
 BonusActionBarFrame.visible=false;BonusActionBarFrame.scripts.OnHide();assert(ActionButton1.shown)
end
update();assert(ActionButton1.showgrid==1)
assert(ActionButton1.action and not BonusActionButton1.action)
print('Action grids: native setting/drag counters, form-bar coverage, native Show suppression, caster restoration, empty slots and untouched action contents passed')
