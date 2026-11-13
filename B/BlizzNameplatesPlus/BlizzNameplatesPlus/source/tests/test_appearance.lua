local files = {
 "core/appearance.lua", "core/config.lua", "core/options.lua",
 "modules/classcolors.lua", "modules/fullalpha.lua", "modules/personalnameplate.lua",
 "modules/shagu_darkmode.lua", "modules/visualguard.lua", "modules/auras.lua", "modules/castbar.lua",
}
for _, path in ipairs(files) do assert(loadfile(path)) end
dofile("core/appearance.lua")
local level={size=12}
function level:GetFont()return "font",self.size,"OUTLINE" end
function level:SetFont(font,size,flags)self.size=size;assert(flags=="OUTLINE")end
local levelScalePlate={level=level}
BNP_DB={levelNumberScale=.5}
BNP:ApplyLevelNumberScale(levelScalePlate)
assert(level.size==6)
BNP_DB.levelNumberScale=1.5
BNP:ApplyLevelNumberScale(levelScalePlate)
BNP:ApplyLevelNumberScale(levelScalePlate)
assert(level.size==18)
BNP_DB.levelNumberScale=1
BNP:ApplyLevelNumberScale(levelScalePlate)
assert(level.size==12)
local function color(r,g,b,a)
 local cr,cg,cb,ca=BNP:GetRecoloredBorderColor()
 assert(cr==r and cg==g and cb==b and ca==a)
end
color(.3,.3,.3,.9)
ShaguTweaks={GoldMode=true,overwrites={["goldmode.color"]={r=.9,g=.7,b=.2,a=1}}}
color(.9,.7,.2,1)
ShaguTweaks.DarkMode=true
ShaguTweaks.overwrites["darkmode.color"]={r=.2,g=.2,b=.2,a=.8}
color(.2,.2,.2,.8)
ShaguTweaks=nil
local bar={path="original"}
function bar:GetStatusBarTexture() return self.path end
function bar:SetStatusBarTexture(path) self.path=path end
local plate={healthbar=bar}
BNP_DB={modernClassColors=true}
BNP:ApplyModernHealthTexture(plate)
assert(string.find(bar.path,"BlizzardRetailBar",1,true))
BNP:ApplyModernHealthTexture(plate)
BNP_DB.modernClassColors=false
BNP:ApplyModernHealthTexture(plate)
assert(bar.path=="original")
for _,class in ipairs({"WARRIOR","MAGE","ROGUE","DRUID","HUNTER","SHAMAN","PRIEST","WARLOCK","PALADIN"}) do
 assert(BNP:GetModernClassColor(class))
end
local function region()
 local t={}
 function t:SetPoint() end
 function t:SetTexCoord(...) self.coords=arg end
 function t:SetHeight(n) self.height=n end
 function t:SetWidth(n) self.width=n end
 function t:SetTexture(path) self.path=path end
 function t:SetVertexColor(...) self.color=arg end
 function t:Show() self.shown=true end
 function t:Hide() self.shown=false end
 return t
end
local icon={texture={GetTexture=function()return "spell-one" end},created=0}
function icon:CreateTexture() self.created=self.created+1;return region() end
function icon:GetWidth() return 32 end
function icon:GetHeight() return 16 end
BNP.IsDarkNameplateBorderEnabled=function()return BNP_DB.darkNameplateBorder end
BNP_DB.darkNameplateBorder=true
ShaguTweaks={GoldMode=true,overwrites={["goldmode.border"]={r=.7,g=.5,b=.2,a=1}}}
BNP:ApplyAuraBorderColor(icon)
assert(icon.created==4)
for i=1,4 do
 local strip=icon.BNPRecoloredEdges[i]
 assert(strip.shown and strip.path=="spell-one" and strip.color[1]==.7 and strip.color[2]==.5)
end
assert(icon.BNPRecoloredEdges[1].height==1 and icon.BNPRecoloredEdges[3].width==2)
icon.texture.GetTexture=function()return "spell-two" end
ShaguTweaks.DarkMode=true
ShaguTweaks.overwrites["darkmode.color"]={r=.1,g=.2,b=.3,a=1}
BNP:ApplyAuraBorderColor(icon)
assert(icon.created==4 and icon.BNPRecoloredEdges[1].path=="spell-two")
assert(icon.BNPRecoloredEdges[1].color[1]==.1)
BNP_DB.darkNameplateBorder=false
BNP:ApplyAuraBorderColor(icon)
for i=1,4 do assert(not icon.BNPRecoloredEdges[i].shown) end
local writes = 0
local fill = region()
function fill:GetParent() return icon end
function fill:IsShown() return self.shown end
function fill:ClearAllPoints() end
function fill:SetAllPoints(relative) self.anchor=relative end
function fill:SetTexture(path) self.path=path;writes=writes+1 end
function fill:SetVertexColor(...) self.color=arg;writes=writes+1 end
local rim={GetParent=function()return icon end,GetWidth=function()return 128 end,GetHeight=function()return 32 end}
function rim:GetTexCoord() return 0,0,0,1,1,0,1,1 end
function icon:CreateTexture() return fill end
bar.path="modern-health"
BNP_DB.modernClassColors=true
bar.color={1,0,0,1}
function bar:GetStatusBarColor() return unpack(self.color) end
local levelPlate={border=rim,healthbar=bar}
BNP:UpdateLevelBackground(levelPlate)
assert(string.find(fill.path,"level_fill_dark",1,true) and fill.color[1]==.055 and fill.color[2]==.065 and fill.shown)
assert(fill.anchor==rim)
function fill:SetPoint(point,relative,relativePoint,x,y) self.x=x;self.y=y end
function rim:GetTexCoord() return 0,.5,0,1,1, .5,1,1 end
BNP:UpdateLevelBackground(levelPlate)
assert(fill.anchor==rim and fill.coords[2]==.5 and fill.coords[4]==1)
function rim:GetWidth()return 256 end
BNP:UpdateLevelBackground(levelPlate)
assert(fill.anchor==rim)
local before=writes
BNP:UpdateLevelBackground(levelPlate)
assert(writes==before)
bar.color={.96,.55,.73,1} -- paladin
bar.path="classic-health"
BNP_DB.modernClassColors=false
BNP:UpdateLevelBackground(levelPlate)
assert(string.find(fill.path,"level_fill_dark",1,true) and fill.color[1]==.055 and fill.color[2]==.065)
BNP.IsNameplateBorderHidden=function()return true end
BNP:UpdateLevelBackground(levelPlate)
assert(not fill.shown)
print("Lua 5.0: ten Lua files parse; palette, texture restoration, aura rims and masked dark level backgrounds pass")
