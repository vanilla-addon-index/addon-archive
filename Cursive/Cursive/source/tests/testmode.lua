local file=assert(io.open("ui.lua","r")); local source=file:read("*a"); file:close()
local function widget()
	return {
		SetScript=function() end, ClearAllPoints=function() end,
		SetPoint=function(self,...) self.point=arg end,
		SetText=function(self,value) self.text=value end,
		SetMinMaxValues=function() end,SetValue=function() end,SetStatusBarColor=function() end,
		SetTexture=function() end, SetAlpha=function() end,
		Show=function(self) self.shown=true end,Hide=function(self) self.shown=false end,
	}
end
Cursive={db={profile={maxcol=2,maxrow=3,maxcurses=4,notifyshadowvuln=true,
	curseiconsize=20,healthborder=true}},ResetUnitFrames=function() ui.unitFrames={} end}
ui={unitFrames={},rootBarFrame={},padding=2}
local created=0
function CreateBar(row,col,guid)
	assert(guid==nil) -- never give samples a real unit identity
	created=created+1
	local bar=widget()
	bar.nameText=widget();bar.hpText=widget();bar.healthBar=widget()
	bar.healthBar.border=widget();bar.icon=widget();bar.target_left=widget()
	bar.shadowVulnIcon=widget();bar.shadowVulnIcon.timer=widget()
	bar.ghostIcons={}
	for i=1,4 do bar["curse"..i]=widget();bar["curse"..i].timer=widget();bar.ghostIcons[i]=widget() end
	ui.unitFrames[col][row]=bar
	return bar
end
function GetBarCords(row,col) return col*100,-row*20 end
function GetTime() return 100 end
function ThemeBorder() end
function UpdateEliteDragon() end
function UpdateAuraBorder() end
function SetRaidTargetIconTexture() end
local start=assert(string.find(source,"function Cursive.SetTestMode",1,true))
local finish=assert(string.find(source,"local shouldDisplayGuids",start,true))
local render=assert(loadstring(string.sub(source,start,finish-1).." return RenderTestBars"))()
Cursive.SetTestMode(true); render()
assert(created==6)
assert(ui.unitFrames[1][1].testMode)
assert(ui.unitFrames[1][1].curse1.shown)
assert(not ui.unitFrames[1][1].curse4.shown)
render();assert(created==6) -- reuse samples on each refresh
Cursive.db.profile.invertbars=true
Cursive.db.profile.expandupwards=true
render();assert(ui.unitFrames[1][1].point[1]=="BOTTOMLEFT")
Cursive.SetTestMode(false)
assert(not Cursive.testMode and next(ui.unitFrames)==nil)
print("Test mode layout and isolation tests passed")