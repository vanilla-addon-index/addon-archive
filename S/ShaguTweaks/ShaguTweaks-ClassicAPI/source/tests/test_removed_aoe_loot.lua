local root=(arg[1] or '.')..'/'
local function read(path)local f=assert(io.open(root..path));local s=f:read('*a');f:close();return s end
local toc=read('ShaguTweaks.toc');assert(not string.find(toc,'mods\\aoe-loot.lua',1,true))
local file=io.open(root..'mods/aoe-loot.lua');assert(not file)
local api=read('api.lua');assert(loadstring(api))
for _,name in ipairs({'API.aoeloot','API.containeropenable','API.IsContainerItemOpenable',
 'API.GetNearbyLootableUnits','API.IsLootScanInProgress','API.LootAllCorpses'}) do
 assert(not string.find(api,name,1,true),name)
end
local main=read('main.lua');assert(loadstring(main))
local retired='ShaguTweaks_config[ShaguTweaks.T["AoE Loot"]] = nil'
assert(string.find(main,retired,1,true))
local env={ShaguTweaks_config={['AoE Loot']=1,['Loot Quality']=1},ShaguTweaks={T=setmetatable({},{__index=function(_,k)return k end})}}
local chunk=assert(loadstring(retired));setfenv(chunk,env);chunk()
assert(env.ShaguTweaks_config['AoE Loot']==nil and env.ShaguTweaks_config['Loot Quality']==1)
assert(string.find(read('Docs/EXTRAS_MERGE.md'),'https://github.com/rotaruandrei93/AutoAreaLoot',1,true))
print('Removed AoE Loot: source/manifest/API cleanup, retired saved setting and migration replacement link passed')
