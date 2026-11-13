local root=(arg[1] or '.')..'/'
local modules,frames,published,calls,tickers={},{},{},{},{}
local modifier=false
local bodies={
 [1]='#showtooltip Fireball\n/cast Fireball',
 [2]='--showtooltip Frostbolt\n/cast Fireball',
 [3]='/pfcast Heal(Rank 1)',
 [4]='#showtooltip [mod:shift] Fireball; Frostbolt\n--showtooltip Heal',
 [5]='/castsequence Fireball,Frostbolt',
 [6]='--showtooltip [mod:shift] Heal; Frostbolt',
}
local nativeSelectedIcon='chosen-custom-icon'
C_EventUtils={IsEventValid=function() return true end}
GetMacroInfo=function(id) if bodies[id] then return 'Macro '..id,nativeSelectedIcon,bodies[id] end end
CreateFrame=function(_,name)
 local f={events={},scripts={}}
 function f:RegisterEvent(name) self.events[name]=true end
 function f:UnregisterEvent(name) self.events[name]=nil end
 function f:UnregisterAllEvents() self.events={} end
 function f:SetScript(k,v) self.scripts[k]=v end
 table.insert(frames,f);return f
end
SecureCmdOptionParse=function(value) return modifier and 'Heal' or 'Frostbolt','mouseover' end
C_Macro={SetMacroDisplay=function(id,value,unit)
 published[id]=value;table.insert(calls,{id,value,unit})
 return true
end,GetMacroIcon=function() return nativeSelectedIcon end}
C_Timer={NewTicker=function(interval,callback)
 assert(interval==.2);local t={callback=callback};function t:Cancel() self.cancelled=true end
 table.insert(tickers,t);return t
end}
local sent,executed={},{}
SendChatMessage=function(text) table.insert(sent,text) end
local originalChat=SendChatMessage
RunMacroText=function(text) table.insert(executed,text) end
ChatFrameEditBox={scripts={},AddHistoryLine=function() end,GetScript=function(self,k) return self.scripts[k] end,
 SetScript=function(self,k,v) self.scripts[k]=v end}
SlashCmdList={}
SLASH_OTHERUSE1='/use';SlashCmdList.OTHERUSE=function() end
ShaguTweaks={T=setmetatable({},{__index=function(t,k) return k end}),GetGlobalEnv=function() return getfenv(0) end,
 API={macrodisplay=true,nativemacrocommands=true},
 libspell={GetSpellIndex=function() error('Native macros must not scan the spellbook') end}}
function ShaguTweaks:register(m) modules[m.title]=m;return m end
dofile(root..'mods/macro-icons.lua');dofile(root..'mods/macro-tweaks.lua')
local icons=modules['Macro Icons'];icons:enable();local driver=icons.nativeDriver
assert(not published[1] and published[2]=='Frostbolt' and published[3]=='Heal(Rank 1)' and not published[4] and not published[5])
assert(published[6]=='Frostbolt' and C_Macro.GetMacroIcon(1)=='chosen-custom-icon')
assert(not driver.events.ACTIONBAR_SLOT_CHANGED and not driver.events.ACTIONBAR_PAGE_CHANGED and not driver.scripts.OnUpdate)
local initial=table.getn(calls);tickers[1].callback();assert(table.getn(calls)==initial)
modifier=true;event='MODIFIER_STATE_CHANGED';driver.scripts.OnEvent();assert(published[6]=='Heal')
assert(calls[table.getn(calls)][3]=='mouseover')
bodies[2]='#showtooltip Fireball';bodies[6]='/cast Fireball';event='UPDATE_MACROS';driver.scripts.OnEvent()
assert(not published[2] and not published[6] and tickers[1].cancelled)
assert(not driver.events.MODIFIER_STATE_CHANGED)
-- A custom item hint that initially lacks cached data is retried on arrival.
bodies[7]='--showtooltip item:789'
local publish=C_Macro.SetMacroDisplay
local cached=false
C_Macro.SetMacroDisplay=function(id,value,unit)
 if id==7 and value and not cached then return false end
 return publish(id,value,unit)
end
event='UPDATE_MACROS';driver.scripts.OnEvent();assert(not published[7] and driver.events.GET_ITEM_INFO_RECEIVED)
cached=true;event='GET_ITEM_INFO_RECEIVED';driver.scripts.OnEvent();assert(published[7]=='item:789')
local count=table.getn(frames);icons:enable();assert(table.getn(frames)==count)
modules['Macro Tweaks']:enable()
assert(SendChatMessage==originalChat and not SLASH_SHAGUTWEAKS_USE1 and SlashCmdList.OTHERUSE)
SlashCmdList.SHAGUTWEAKS_EQUIP('[combat] item:123')
SlashCmdList.SHAGUTWEAKS_FOCUS('[@mouseover]')
SlashCmdList.SHAGUTWEAKS_STARTATTACK('[harm]')
assert(executed[1]=='/equip [combat] item:123' and executed[2]=='/focus [@mouseover]' and executed[3]=='/startattack [harm]')
modules['Macro Tweaks']:enable();assert(SendChatMessage==originalChat)
SendChatMessage('#showtooltip is ordinary chat here');assert(table.getn(sent)==1)
-- Older command surface retains the metadata filter and legacy bag-slot use.
modules['Macro Tweaks'].installed=nil;ShaguTweaks.API.nativemacrocommands=false
SLASH_OTHERUSE1=nil;SLASH_SHAGUTWEAKS_EQUIP1=nil
UseContainerItem=function(bag,slot) assert(bag==0 and slot==2);table.insert(executed,'legacy-use') end
modules['Macro Tweaks']:enable();SendChatMessage('#showtooltip Fireball');assert(table.getn(sent)==1)
SendChatMessage('hello');assert(sent[2]=='hello')
SlashCmdList.SHAGUTWEAKS_EQUIP('0 2');assert(executed[4]=='legacy-use')
event='PLAYER_LOGOUT';driver.scripts.OnEvent();assert(not published[3])
icons.installed=nil;CleveRoids={};local before=table.getn(frames);icons:enable();assert(table.getn(frames)==before);CleveRoids=nil
-- Older icon surface still initializes the existing event-driven fallback.
ShaguTweaks.API.macrodisplay=false;icons.installed=nil;icons:enable()
assert(frames[table.getn(frames)].events.ACTIONBAR_SLOT_CHANGED)
print('Macros: native ownership/chosen icons, custom hints/conditions, edit release, conditional-only ticker, idempotence, native aliases, foreign aliases and older API paths passed')
