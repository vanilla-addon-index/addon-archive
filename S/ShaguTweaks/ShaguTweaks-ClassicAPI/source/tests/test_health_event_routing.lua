local root=(arg[1] or '.')..'/'
local f=assert(io.open(root..'mods/health-numbers.lua'));local source=f:read('*a');f:close()
local a=assert(string.find(source,'  self.valueEvents =',1,true))
local b=assert(string.find(source,'  local alternatePowerBar =',a,true))
local handler,registered,calls=nil,{},{}
local function record(kind,unit) table.insert(calls,kind..':'..(unit or '')) end
local events={}
function events:RegisterEvent(name) registered[name]=true end
function events:SetScript(name,callback) assert(name=='OnEvent');handler=callback end
CreateFrame=function() return events end
ShaguTweaks={API={RegisterUnitEvent=function(frame,name,...) registered[name]=arg end}}
local self={valueTexts={playerHealth='ph',targetHealth='th',petHealth='eh',playerMana='pp',targetMana='tp',petMana='ep'}}
local init=assert(loadstring('return function(self,UpdateHealth,UpdatePower,PositionTexts,UpdatePlayer,UpdateTarget,UpdatePet,UpdateAlternatePower) '..string.sub(source,a,b-1)..' end'))()
init(self,function(text,unit,estimated)
 assert(text==self.valueTexts[unit..'Health'] and estimated==(unit=='target'));record('health',unit)
end,function(text,unit) assert(text==self.valueTexts[unit..'Mana']);record('power',unit) end,
 function() record('position') end,function() record('full','player') end,
 function() record('full','target') end,function() record('full','pet') end,function() record('alternate') end)
local function emit(name,unit) calls={};event,arg1=name,unit;handler() end
for _,unit in ipairs({'player','target','pet'}) do
 for _,name in ipairs({'UNIT_HEALTH','UNIT_MAXHEALTH'}) do
  emit(name,unit);assert(table.getn(calls)==1 and calls[1]=='health:'..unit)
 end
 for _,name in ipairs({'UNIT_MANA','UNIT_MAXMANA','UNIT_RAGE','UNIT_MAXRAGE','UNIT_ENERGY','UNIT_MAXENERGY','UNIT_FOCUS','UNIT_MAXFOCUS','UNIT_HAPPINESS','UNIT_MAXHAPPINESS','UNIT_DISPLAYPOWER'}) do
  assert(registered[name]);emit(name,unit)
  assert(calls[1]=='power:'..unit and table.getn(calls)==(unit=='player' and 2 or 1))
  if unit=='player' then assert(calls[2]=='alternate:') end
 end
end
emit('UNIT_HEALTH','party1');assert(not next(calls))
emit('PLAYER_TARGET_CHANGED');assert(table.getn(calls)==1 and calls[1]=='full:target')
emit('PET_UI_UPDATE');assert(table.getn(calls)==1 and calls[1]=='full:pet')
emit('PLAYER_ENTERING_WORLD');assert(table.getn(calls)==5 and calls[1]=='position:' and calls[5]=='alternate:')
print('Health routing: independent health/power events for player/target/pet, alternate power, unit filtering and full identity/startup refreshes passed')
