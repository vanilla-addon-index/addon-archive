local maximumEventsCached = 200

SCT.unitPlayerGuid = ""
SCT.eventCache = {}
SCT.playerBuffCache = {}
SCT.playerDebuffCache = {}


local function CacheDropOverHead(cacheTable)
   local eventCacheSize = table.getn(cacheTable)
   if eventCacheSize < maximumEventsCached then
      return
   end

   local eventCacheOverHead = eventCacheSize - maximumEventsCached

   for overHead=1,eventCacheOverHead do
      table.remove(cacheTable, overHead)
   end
end

local function MaybeCacheSpellByID(cacheTable, spellID)

   local name, rank, textureFile, minRange, maxRange = SpellInfo(spellID)

   if cacheTable[name] then
      --[[
         Event already cached.
      --]]
      return
   end

   if not name or not textureFile then
      return
   end

   CacheDropOverHead(cacheTable)

   cacheTable[name] = {
      ["spellID"] = spellID,
      ["textureFile"] = textureFile,
   }
end


local function CacheSearchSpellByName(cacheTable, spellName)
   if not cacheTable[spellName] then
      return
   end

   return cacheTable[spellName]["textureFile"]
end

function SCT:EventCacheInit()
   --return;
   local _, unitPlayerGuid = UnitExists("player")
   self.unitPlayerGuid = unitPlayerGuid
end

function SCT:EventCacheDropEvents()
  -- local self = SCT
   CacheDropOverHead(self.eventCache)
end

function SCT:EventCacheUnitCast(casterGUID, targetGUID, eventType, spellID, castDuration)
   if not ((casterGUID == self.unitPlayerGuid)
      or  (targetGUID == self.unitPlayerGuid))
   then--[[
     Only track events related to the player.
   --]]
      return
   end

   MaybeCacheSpellByID(self.eventCache, spellID)
end

function SCT:EventCacheSearch(spellName)
   return CacheSearchSpellByName(self.eventCache, spellName)
end

function SCT:EventUnitPlayerAuraSearchByName(spellName, typ)
   if typ == "HELPFUL" then
      return CacheSearchSpellByName(self.playerBuffCache, spellName)
   else
      if typ == "HARMFUL" then
         return CacheSearchSpellByName(self.playerDebuffCache, spellName)
      end
   end

   return nil
end


local function GatherPlayerAurasOfType(tbl, typ)
   local i = 0;
   while not (GetPlayerBuff(i, typ) == -1) do
      local AuraID = GetPlayerBuffID(i)
      MaybeCacheSpellByID(tbl, AuraID)
      i=i+1
   end
end

function SCT:EventUnitPlayerAurasChanged()
   GatherPlayerAurasOfType(self.playerBuffCache, "HELPFUL")
   GatherPlayerAurasOfType(self.playerDebuffCache, "HARMFUL")
end
