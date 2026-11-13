local root=(arg[1] or '.')..'/'
local f=assert(io.open(root..'mods/dark-ui-elements.lua'));local source=f:read('*a');f:close()
assert(loadstring(source))
local function Slice(first,last)
 local a=assert(string.find(source,first,1,true));local b=assert(string.find(source,last,a,true))
 return string.sub(source,a,b-1)
end
local lowerCalls=0
local environment=setmetatable({ShaguTweaks={},CountLower=function() lowerCalls=lowerCalls+1 end},{__index=getfenv(0)})
local chunk=assert(loadstring('local originalString=string;local string={find=string.find,lower=function(path) CountLower();return originalString.lower(path) end};'
 ..Slice('local blacklist =','local regionskips =')
 ..Slice('local whitelist =','local showframes =')
 ..Slice('local PATH_CACHE_LIMIT =','local function AddSpecialBackground')
 ..'return IsBlacklisted,pathCache,pathKeys,PATH_CACHE_LIMIT'))
setfenv(chunk,environment)
local blocked,cache,keys,limit=chunk()
local texture={path='Interface\\FrameXML\\CustomFrameArt',name='FrameArt'}
function texture:GetName() return self.name end
function texture:GetTexture() return self.path end
assert(not blocked(texture) and lowerCalls==1)
texture.name='ActionIcon';assert(blocked(texture) and lowerCalls==1)
texture.name='FrameArt';assert(not blocked(texture) and lowerCalls==1)
texture.path='Interface\\AddOns\\Outfitter\\Textures\\OutfitterFrame';texture.name='Icon'
assert(not blocked(texture)) -- explicit whitelist precedes ordinary name exclusions
texture.name='StationeryBackgroundLeft';assert(blocked(texture))
texture.path='Interface\\MailFrame\\MailItemBorder';texture.name='FrameArt';assert(blocked(texture))
texture.path='Interface\\Stationery\\CustomPaper';assert(blocked(texture))
texture.path='Interface\\QuestFrame\\UI-QuestLog-Empty-BotLeft';assert(blocked(texture))
texture.path='Interface\\Icons\\Test';assert(blocked(texture))
texture.path=nil;assert(blocked(texture))
for i=1,300 do texture.path='Interface\\FrameXML\\CustomArt'..i;assert(not blocked(texture)) end
local count=0;for _ in pairs(cache) do count=count+1 end
assert(count==limit and table.getn(keys)==limit and not cache['Interface\\FrameXML\\CustomFrameArt'])
texture.path='Interface\\FrameXML\\CustomFrameArt';local previous=lowerCalls
assert(not blocked(texture) and lowerCalls==previous+1) -- evicted entries recompute safely

local queue,passes,hooks={},{},0
local env=setmetatable({},{__index=getfenv(0)})
env._G=env
env.C_Timer={After=function(delay,fn) assert(delay==0);table.insert(queue,fn) end}
env.ShaguTweaks={HookScript=function(frame,event,fn) hooks=hooks+1;frame[event]=fn end}
env.golden={}
env.DarkenFrame=function(frame) table.insert(passes,frame.children) end
local showChunk=assert(loadstring(Slice('local function RecolorOnShow','local function LockAddonFrames')..'return RecolorOnShow'))
setfenv(showChunk,env);local install=showChunk()
local frame={children=0,GetName=function() return 'RollForLootFrameHeader' end,IsShown=function() return false end}
install(frame);install(frame);assert(hooks==1 and table.getn(passes)==0)
frame.OnShow();frame.OnShow();frame.OnShow()
assert(table.getn(passes)==3 and table.getn(queue)==1)
frame.children=10 -- late-created rows must be included by the trailing pass
local callback=table.remove(queue,1);callback()
assert(passes[4]==10)
frame.OnShow();assert(table.getn(queue)==1 and queue[1]==callback) -- reuse callback/rearm
queue[1]();queue={}
env.C_Timer=nil;frame.OnShow();assert(table.getn(queue)==0)
print('Recolors: bounded path cache, live name exclusions, whitelist/paper rules, eviction; immediate passes retained, one trailing callback, late children and rearming passed')
