-- Exercise the actual icon/layout helper without loading the full WoW UI.
ShaguDPS = { data={dispels_done={[0]={},[1]={}},dispels_received={[0]={},[1]={}}}, expansion=function() return 'vanilla' end, window={}, config={class_icons=1,height=15,spacing=0} }
local f = assert(io.open('window.lua'))
local source = f:read('*a')
f:close()
local boundary = assert(string.find(source, '-- default backdrops', 1, true))
assert(loadstring(string.sub(source, 1, boundary - 1)))()
local icon = {
 SetTexture=function(self,v) self.texture=v end,
 SetTexCoord=function(self,a,b,c,d) self.coords={a,b,c,d} end,
 SetWidth=function(self,v) self.width=v end, SetHeight=function(self,v) self.height=v end,
 SetPoint=function() end, Show=function(self) self.shown=true end, Hide=function(self) self.shown=false end,
}
local bar = {CreateTexture=function() return icon end,textLeft={SetPoint=function(self,a,b,c,x) self.offset=x end}}
local update = ShaguDPS.window.UpdateClassIcon
update(bar, 'MAGE')
assert(icon.shown and icon.width==13 and bar.textLeft.offset==18)
assert(icon.coords[1]==.25 and icon.coords[2]==.5)
update(bar, 'PRIEST')
assert(icon.coords[1]==.5 and icon.coords[3]==.25, 'recycled bar updates class')
update(bar, nil)
assert(not icon.shown and bar.textLeft.offset==5, 'threshold/unknown rows have no icon gap')
ShaguDPS.config.class_icons=0
update(bar, 'MAGE')
assert(not icon.shown and bar.textLeft.offset==5, 'toggle restores original layout')
ShaguDPS.config.class_icons=1
ShaguDPS.config.height=24
ShaguDPS.config.spacing=2
update(bar,'WARRIOR')
assert(icon.shown and icon.width==20 and bar.textLeft.offset==25, 'icons follow bar sizing')
print('Class icon layout checks passed (Lua 5.0)')

local percent = ShaguDPS.window.FormatThreatPercent
assert(percent(44.200001) == '44.2')
assert(percent(43.299999) == '43.3')
assert(percent(100) == '100')
assert(percent(99.99) == '100')
assert(percent('110-130') == '110-130')
assert(percent(nil) == '0')
print('Threat percentage formatting checks passed (Lua 5.0)')

local rate, total = ShaguDPS.window.FormatRate, ShaguDPS.window.FormatTotal
assert(rate(1000.4) == '1000' and rate(1000.6) == '1001')
assert(rate(12345.6) == '12346' and rate(nil) == '0')
assert(total(100000) == '100K' and total(1000000) == '1M')
assert(total(12345) == '12.3K' and total(1234567) == '1.23M')
assert(total(1000) == '1000' and total(0) == '0')
print('Whole-number rates and compact totals passed (Lua 5.0)')

local templateStart = assert(string.find(source, 'local view_templates = {', 1, true))
local templateEnd = assert(string.find(source, '-- views of older versions:', templateStart, true))
local templates = assert(loadstring(string.sub(source, templateStart, templateEnd - 1) .. '\nreturn view_templates'))()
for _, id in pairs({1, 3, 5}) do
  local label = id == 1 and 'DPS' or (id == 3 and 'HPS' or 'TPS')
  assert(string.format(templates[id].bar_string, total(100000), rate(1000.3), percent(100)) == '100K (1000 ' .. label .. ') [100%]')
end
print('Damage, healing and threat line formats passed (Lua 5.0)')

local function text()
 return {ClearAllPoints=function(self) self.points={} end,
 SetPoint=function(self,point,bar,relative,x,y) self.points=self.points or {};self.points[point]=x end,
 SetWidth=function(self,width) self.width=width end}
end
local function row(shown)
 return {IsShown=function() return shown end,textRight=text(),textRate=text(),textPercent=text(),textLeft=text()}
end
local rows={row(true),row(true),row(false)}
ShaguDPS.window.AlignValueColumns(rows,3,{40,65,35})
for i=1,2 do
 assert(rows[i].textPercent.points.TOPRIGHT==-5)
 assert(rows[i].textRate.points.TOPRIGHT==-46)
 assert(rows[i].textRight.points.TOPRIGHT==-117)
 assert(rows[i].textLeft.points.BOTTOMRIGHT==-163)
 assert(rows[i].textRate.width==65)
end
assert(not rows[3].textRight.points, 'hidden rows do not affect layout')
ShaguDPS.window.AlignValueColumns(rows,2,{35,55,25})
assert(rows[1].textRate.width==55 and rows[1].textRight.points.TOPRIGHT==-97)
print('Shared column alignment checks passed (Lua 5.0)')

local dispelSegment = ShaguDPS.window.GetDispelSegment
assert(dispelSegment({segment=1}) == ShaguDPS.data.dispels_done[1])
assert(dispelSegment({segment=0,dispels_received=1}) == ShaguDPS.data.dispels_received[0])
assert(not next(dispelSegment({segment=2},{damage={},heal={}})), 'old history shows empty dispels')
local saved = {dispels_done={Priest={_sum=2}},dispels_received={Mage={_sum=2}}}
assert(dispelSegment({},saved).Priest._sum == 2)
assert(dispelSegment({dispels_received=1},saved).Mage._sum == 2)
assert(string.format(templates[6].bar_string,'4','25') == '4 [25%]')
print('Dispels view direction and saved-history selection passed (Lua 5.0)')

local dispelStatus = ShaguDPS.window.DispelStatus
assert(string.find(dispelStatus({}, {damage={}}, true), 'not recorded', 1, true))
assert(string.find(dispelStatus({}, {dispels_done={},dispels_recorded=false}, true), 'not recorded', 1, true))
assert(dispelStatus({}, {dispels_done={},dispels_recorded=true}, false) == nil, 'saved data available without ClassicAPI')
assert(dispelStatus({}, {dispels_done={}}, true) == nil, 'earlier dispel snapshots remain readable')
assert(string.find(dispelStatus({}, nil, false), 'requires ClassicAPI', 1, true))
print('Missing versus zero dispel-data checks passed (Lua 5.0)')
