local root=(arg[1] or '.')..'/'
local env=dofile(root..'tests/fixtures/module_mock.lua')()
local selected,scans=11,0
local actions={[1]='macro',[2]='spell'}
env.NUM_ACTIONBAR_BUTTONS=12
for i=1,2 do
 env['ActionButton'..i]=env.CreateFrame('Button','ActionButton'..i);env['ActionButton'..i].id=i
 env['ActionButton'..i..'Count']=env.CreateFrame()
end
env.ActionButton_GetPagedID=function(button)return button.id end
env.HasAction=function(slot)scans=scans+1;return actions[slot]~=nil end
env.IsConsumableAction=function()return false end
env.C_EventUtils={IsEventValid=function(name)return name~='UPDATE_SHAPESHIFT_FORM'end}
local api=env.ShaguTweaks.API
api.eventutils=true
api.RegisterUnitEvent=function(frame,event,unit)assert(unit=='player');frame:RegisterEvent(event)end
api.GetActionInfo=function(slot)return actions[slot],slot end
api.GetMacroSpell=function()return 'Conditional','',selected end
api.GetSpellReagents=function(id)if id~=33 then return {{itemID=id}}end end
api.GetItemCount=function(id)return id*10 end
env.Load(root..'mods/actionbar-reagents.lua');env.module:enable()
local frame=env.module.counter
local function flush(event,unit)
 env.Invoke(frame,'OnEvent',event,unit)
 if frame.visible then env.Invoke(frame,'OnUpdate')end
end
flush('PLAYER_ENTERING_WORLD');assert(env.ActionButton1Count.text==110 and env.ActionButton2Count.text==20)
assert(frame.events.MODIFIER_STATE_CHANGED and not frame.events.UPDATE_SHAPESHIFT_FORM)
assert(frame.events.UPDATE_SHAPESHIFT_FORMS and frame.events.UNIT_AURA)
local initial=scans
selected=22;flush('MODIFIER_STATE_CHANGED');assert(env.ActionButton1Count.text==220 and scans==initial+1)
selected=33;flush('PLAYER_TARGET_CHANGED');assert(env.ActionButton1Count.text==nil)
selected=44;flush('UNIT_AURA','target');assert(env.ActionButton1Count.text==nil and not frame.pending)
flush('UNIT_AURA','player');assert(env.ActionButton1Count.text==440)
selected=nil;flush('UPDATE_SHAPESHIFT_FORMS');assert(env.ActionButton1Count.text==nil)
selected=55;flush('SPELL_UPDATE_COOLDOWN');assert(env.ActionButton1Count.text==550)
initial=scans;flush('BAG_UPDATE');assert(scans==initial and env.ActionButton1Count.text==550)
actions[1]=nil;flush('ACTIONBAR_SLOT_CHANGED')
assert(not frame.events.MODIFIER_STATE_CHANGED and not frame.events.UNIT_AURA)
assert(env.ActionButton1Count.text==nil)
actions[1]='macro';selected=66;flush('UPDATE_MACROS')
assert(frame.events.MODIFIER_STATE_CHANGED and env.ActionButton1Count.text==660)
env.ActionButton1Count.text='native cleared';env.this=env.ActionButton1
env.hooks.ActionButton_UpdateCount();assert(env.ActionButton1Count.text==660)
local count=table.getn(env.frames);env.module:enable();assert(table.getn(env.frames)==count)
print('Reagents: conditional spell/reagent-free/unresolved transitions, macro-only scans, native event guards, unit filtering, count ownership and listener teardown/rearming passed')
