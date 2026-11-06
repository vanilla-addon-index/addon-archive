-- Real display helpers, isolated from WoW widget creation.
local f=assert(io.open('window.lua'));local source=f:read('*a');f:close()
local start=assert(string.find(source,'-- Shared, display-only caches.',1,true))
local finish=assert(string.find(source,'local function barTooltipShow()',start,true))
ShaguDPS={window={},data={classes={Alice='MAGE',Bob='PRIEST'}},config={height=15,spacing=0,texture=2,[1]={view=1,bars=8},[2]={view=1,bars=8}}}
RAID_CLASS_COLORS={MAGE={r=.25,g=.78,b=.92},PRIEST={r=1,g=1,b=1}}
local prefix='local window,data,config=ShaguDPS.window,ShaguDPS.data,ShaguDPS.config\n'
assert(loadstring(prefix..string.sub(source,start,finish-1)))()
local w=ShaguDPS.window
local function order(t,a,b) return t[a]._sum>t[b]._sum end
local segment={Alice={_sum=100,_ctime=1},Bob={_sum=50,_ctime=1}}
local c=w.DisplaySnapshot(segment,order)
assert(c.sorts==1 and c.keys[1]=='Alice')
local function frame(id)
 return {GetID=function() return id end,GetWidth=function() return 400 end,GetHeight=function() return 160 end,scroll=0}
end
local first,second=frame(1),frame(2)
assert(not w.PaintUnchanged(first,c,nil,false,false))
for i=1,1000 do
 local shared=w.DisplaySnapshot(segment,order)
 assert(shared==c and w.PaintUnchanged(first,shared,nil,false,false))
end
assert(c.sorts==1,'unchanged windows do not repeat sorting')
assert(not w.PaintUnchanged(second,c,nil,false,false))
assert(w.PaintUnchanged(second,c,nil,false,false))
segment.Bob._sum=150
w.DisplaySnapshot(segment,order)
assert(c.sorts==2 and c.keys[1]=='Bob')
assert(not w.PaintUnchanged(first,c,nil,false,false))
assert(not w.PaintUnchanged(second,c,nil,false,false))
assert(not w.PaintUnchanged(first,c,10,false,false))
assert(not w.PaintUnchanged(first,c,11,false,false),'live fight-duration rates must redraw')
assert(not w.PaintUnchanged(first,c,11,true,false),'settings refresh must redraw')
assert(not w.PaintUnchanged(first,c,11,false,true),'reports must execute')
first.scroll=1
assert(not w.PaintUnchanged(first,c,11,false,false))
ShaguDPS.config.class_icons=1
assert(not w.PaintUnchanged(first,c,11,false,false))
ShaguDPS.data.classes.Alice='PRIEST'
w.DisplaySnapshot(segment,order)
assert(not w.PaintUnchanged(first,c,11,false,false))
segment.Bob=nil
w.DisplaySnapshot(segment,order)
assert(c.count==1 and table.getn(c.keys)==1)
ShaguDPS.config[1].view=5
assert(not w.PaintUnchanged(first,c,nil,false,false))
assert(not w.PaintUnchanged(first,c,nil,false,false),'threat must bypass paint skip')
print('Shared sorting and repaint invalidation checks passed (Lua 5.0)')
