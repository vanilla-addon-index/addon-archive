local file = assert(io.open("ui.lua","r"))
local source = file:read("*a"); file:close()
Cursive = {db={profile={classicmenu=true}}}
local function frame()
	return {
		SetBackdrop=function(self,v) self.backdrop=v end,
		SetBackdropColor=function(self,r,g,b,a) self.backgroundAlpha=a end,
		SetBackdropBorderColor=function(self,r,g,b,a) self.r=r; self.g=g end,
		SetHeight=function(self,v) self.height=v end,
        SetTexture=function(self,r,g,b,a) self.textureAlpha=a end,
        SetVertexColor=function(self,r,g,b,a) self.tintR=r; self.tintG=g end,
		Show=function(self) self.shown=true end,
		Hide=function(self) self.shown=false end,
	}
end
ShaguTweaks={GoldMode=true}
GameTooltip={GetBackdropBorderColor=function() return .8,.62,.32,1 end}
CursiveSettingsWindow=frame()
CursiveSettingsWindow.titleBar=frame()
CursiveSettingsWindow.classicHeader=frame()
CursiveSettingsWindow.menuFill=frame()
local start=assert(string.find(source,"local function ThemeBorder",1,true))
local finish=assert(string.find(source,"local utils = Cursive.utils",start,true))
assert(loadstring(string.sub(source,start,finish-1)))()
Cursive.db.profile.menuopacity=60
Cursive.ApplyMenuStyle()
assert(CursiveSettingsWindow.backgroundAlpha==.6)
assert(CursiveSettingsWindow.menuFill.textureAlpha==.6)
assert(CursiveSettingsWindow.classicHeader.tintR==.8)
assert(CursiveSettingsWindow.r==.8)
assert(CursiveSettingsWindow.titleBar.backdrop==nil)
assert(CursiveSettingsWindow.classicHeader.shown)
Cursive.db.profile.menuopacity=100
Cursive.ApplyMenuStyle()
assert(CursiveSettingsWindow.menuFill.textureAlpha==1)
Cursive.db.profile.classicmenu=false
Cursive.ApplyMenuStyle()
assert(CursiveSettingsWindow.r==.25)
assert(not CursiveSettingsWindow.classicHeader.shown)
assert(CursiveSettingsWindow.titleBar.backdrop)
local retired=frame(); function retired:IsShown() return true end
ui={unitFrames={{retired}},flashingCurseIcons={[{}]=3}}
function GetUIFont() return "font" end
function UpdateRootBarFrame() end
function Cursive:ScheduleEvent(name,fn,delay) self.delay=delay; self.scheduled=fn end
start=assert(string.find(source,"Cursive.UpdateFramesFromConfig = function()",1,true))
finish=assert(string.find(source,"ui.BarEnter = function()",start,true))
assert(loadstring(string.sub(source,start,finish-1)))()
Cursive.UpdateFramesFromConfig()
assert(Cursive.delay==.1)
Cursive.scheduled()
assert(next(ui.unitFrames)==nil)
assert(next(ui.flashingCurseIcons)==nil)
print("Menu style and resize refresh tests passed")
local start = assert(string.find(source,"local function UpdateEliteDragon",1,true))
local finish = assert(string.find(source,"ui.BarUpdate = function()",start,true))
local updateDragon = assert(loadstring(string.sub(source,start,finish-1).." return UpdateEliteDragon"))()
local dragon = frame()
function dragon:SetTexture(path) self.texture=path end
function dragon:SetDesaturated(value) self.silver=value end
local bar={eliteDragon=dragon}
updateDragon(bar,"elite"); assert(dragon.shown and string.find(dragon.texture,"Elite"))
updateDragon(bar,"rareelite"); assert(dragon.shown and dragon.silver)
updateDragon(bar,"worldboss"); assert(dragon.shown)
updateDragon(bar,"normal"); assert(not dragon.shown)
updateDragon(bar,"rare"); assert(not dragon.shown)
updateDragon({},"elite")
print("Elite dragon and opacity tests passed")