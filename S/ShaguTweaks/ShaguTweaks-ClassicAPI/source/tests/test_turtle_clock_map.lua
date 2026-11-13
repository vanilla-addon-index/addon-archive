local root=(arg[1] or '.')..'/'
local env=dofile(root..'tests/fixtures/module_mock.lua')()
env.TargetHPText,env.TargetHPPercText,env.Cartographer=true,true,true
env.ShaguTweaks.L={debuffs={}}
env.GetGameTime=function()return 8,30 end
env.GetMapContinents=function()return 'Kalimdor','Eastern Kingdoms'end
local continent,zone,mutations=2,7,0
env.GetCurrentMapContinent=function()return continent end
env.GetCurrentMapZone=function()return zone end
env.SetMapToCurrentZone=function()mutations=mutations+1;continent,zone=1,3 end
env.SetMapZoom=function(c,z)mutations=mutations+1;continent,zone=c,z or 0 end
local maps={
 [11]={name='Durotar',parentMapID=-13},[-13]={name='Kalimdor',parentMapID=-694},
 [12]={name='Elwynn Forest',parentMapID=-14},[-14]={name='Eastern Kingdoms',parentMapID=-694},
 [-694]={name='World',parentMapID=0},
}
local current=11
env.C_Map={GetBestMapForUnit=function(unit)assert(unit=='player');return current end,
 GetMapInfo=function(id)return maps[id]end}
env.Load(root..'mods/turtle-wow.lua');env.module:enable()
local clock=env.ShaguTweaks.GetTurtleClockTimes
local server,localTime=clock();assert(server=='20:30' and localTime=='08:30')
assert(continent==2 and zone==7 and mutations==0)
current=12;assert(clock()=='08:30' and mutations==0)
-- Missing hierarchy data and old API versions restore the previous view.
current=99;assert(clock()=='20:30' and continent==2 and zone==7 and mutations==2)
env.C_Map=nil;assert(clock()=='20:30' and continent==2 and zone==7 and mutations==4)
continent,zone=0,0;clock();assert(continent==0 and zone==0)
print('Turtle clock: native map hierarchy without view mutation, both continents, missing data, older API fallback and world-map restoration passed')
