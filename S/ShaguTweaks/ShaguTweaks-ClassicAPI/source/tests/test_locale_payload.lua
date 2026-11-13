local root=(arg[1] or '.')..'/'
local env={};setmetatable(env,{__index=getfenv(0)})
local chunk=assert(loadfile(root..'locales/locales_enUS.lua'));setfenv(chunk,env);chunk()
local locale=env.ShaguTweaks_locale.enUS
local sections=0
for key in pairs(locale)do
 assert(key=='class' or key=='customcast','unused locale section still loaded: '..key)
 sections=sections+1
end
assert(sections==2)
local count=0;for name,token in pairs(locale.class)do assert(type(name)=='string' and type(token)=='string');count=count+1 end
assert(count==9 and locale.class.Warlock=='WARLOCK' and locale.class.Druid=='DRUID')
assert(locale.customcast.AIMEDSHOT=='Aimed Shot' and locale.customcast.MULTISHOT=='Multi-Shot')
local f=assert(io.open(root..'mods/turtle-wow.lua'));local turtle=f:read('*a');f:close()
assert(not string.find(turtle,'L["debuffs"]',1,true),'obsolete Turtle writes remain')
print('Locale payload: only the nine class mappings and two live Hunter cast names remain; obsolete Turtle debuff writes removed')
