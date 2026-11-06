-- Questie-Octo Karazhan map-context compatibility.
--
-- Current Turtle/Octo client data reuses AreaTable ID 3457 for two distinct
-- playable map contexts:
--   server map 532 / texture Karazhan      -> Lower Karazhan Halls
--   server map 814 / texture UpperKarazhan -> Upper Karazhan, first floor
--
-- Most Questie-Octo map data is intentionally keyed by the numeric AreaTable
-- ID. Keep that architecture unchanged and isolate only this known collision by
-- retaining a small secondary context for rendering/selection. Unclassified
-- sources fail closed on 3457 rather than appearing on a believable wrong map.

QuestieOcto.KarazhanContext = QuestieOcto.KarazhanContext or {}
local K = QuestieOcto.KarazhanContext

K.sharedAreaID=3457
K.lowerServerMapID=532
K.upperServerMapID=814
K.lowerTexture="karazhan"
K.upperTexture="upperkarazhan"

-- Current WorldMapArea bounds give different physical spans for the two maps.
-- Data/runtime/minimap.lua can only retain one value for numeric ID 3457, so
-- the minimap must select the span from the physical instance context instead.
K.lowerMinimapWidth=619
K.lowerMinimapHeight=410
K.upperMinimapWidth=823
K.upperMinimapHeight=549

local function AddIDs(target,list)
  local _,id
  for _,id in pairs(list or {}) do target[tonumber(id)]=true end
end

-- Static current-server spawns on map 532. These are source identities, not
-- copied coordinates; the existing Questie runtime remains the coordinate
-- authority used for rendering.
K.lowerCreatures={}
AddIDs(K.lowerCreatures,{
  4075,14881,40026,
  61191,61192,61193,61194,61195,61196,61197,61198,61199,61200,61201,61202,
  61204,61205,61206,61207,61208,61209,61210,61211,61221,61223,61224,61225,
  61254,61255,61256,61319,61320,61321,61322,61323,61324,61328,61571
})

-- Static current-server spawns on map 814 plus current quest-relevant scripted
-- or non-static Upper Karazhan sources whose server quest relationships place
-- them in the Tower of Karazhan context.
K.upperCreatures={}
AddIDs(K.upperCreatures,{
  59967,59968,59970,59971,59988,
  61932,61933,61934,61935,61936,61937,61938,61939,61940,61942,61943,61944,
  61945,61946,61947,61948,61949,61950,61951,61954,61955,61956,61957,61958,
  61990,61997,61998,61999,62000,62001,62002,62003,62030,
  61952,61953,62582,62604,62605,62606,62607
})

K.lowerObjects={}
AddIDs(K.lowerObjects,{2020040,2020050})

K.upperObjects={}
AddIDs(K.upperObjects,{
  2020098,2020111,2020112,2020126,2020187
})

-- Current client AreaTrigger.dbc identifies the server-map context directly.
-- These are retained for quest-bound exploration objectives and tracker targets;
-- generic exploration markers remain governed by the existing objective rules.
K.lowerAreaTriggers={}
AddIDs(K.lowerAreaTriggers,{5019})

K.upperAreaTriggers={}
AddIDs(K.upperAreaTriggers,{5341,5349,5350,5351})

function K:IsSharedArea(mapID)
  return tonumber(mapID)==self.sharedAreaID
end

local function NormalizeTexture(textureName)
  if type(textureName)~="string" or textureName=="" then return nil end
  local value=string.lower(textureName)
  value=string.gsub(value,"/","\\")
  local upperLength=string.len(K.upperTexture)
  if string.len(value)>=upperLength and string.sub(value,-upperLength)==K.upperTexture then
    return K.upperTexture
  end
  local lowerLength=string.len(K.lowerTexture)
  if string.len(value)>=lowerLength and string.sub(value,-lowerLength)==K.lowerTexture then
    return K.lowerTexture
  end
  return value
end

function K:GetDisplayedContext(mapID)
  if not self:IsSharedArea(mapID) then return nil end
  local api=QuestieOcto.API
  local texture=api and api.GetDisplayedMapTextureName and api:GetDisplayedMapTextureName() or nil
  texture=NormalizeTexture(texture)
  if texture==self.lowerTexture then return "lower" end
  if texture==self.upperTexture then return "upper" end
  return nil
end

function K:GetPhysicalContext(mapID)
  if not self:IsSharedArea(mapID) then return nil end
  local api=QuestieOcto.API
  local serverMapID=api and api.GetInstanceMapID and tonumber(api:GetInstanceMapID()) or nil
  if serverMapID==self.lowerServerMapID then return "lower" end
  if serverMapID==self.upperServerMapID then return "upper" end
  return nil
end

function K:GetMinimapSize(context)
  if context=="lower" then return self.lowerMinimapWidth,self.lowerMinimapHeight end
  if context=="upper" then return self.upperMinimapWidth,self.upperMinimapHeight end
  return nil,nil
end

function K:GetSourceContext(sourceKind,sourceID)
  sourceID=tonumber(sourceID)
  if not sourceID then return nil end

  local kind=type(sourceKind)=="string" and string.lower(sourceKind) or ""
  if kind=="creature" or kind=="unit" then
    if self.lowerCreatures[sourceID] then return "lower" end
    if self.upperCreatures[sourceID] then return "upper" end
    return nil
  end

  if kind=="gameobject" or kind=="object" then
    if self.lowerObjects[sourceID] then return "lower" end
    if self.upperObjects[sourceID] then return "upper" end
    return nil
  end

  if kind=="areatrigger" then
    if self.lowerAreaTriggers[sourceID] then return "lower" end
    if self.upperAreaTriggers[sourceID] then return "upper" end
    return nil
  end

  return nil
end

function K:GetAnySourceContext(sourceID)
  sourceID=tonumber(sourceID)
  if not sourceID then return nil end

  local lower=(self.lowerCreatures[sourceID] or self.lowerObjects[sourceID]
    or self.lowerAreaTriggers[sourceID]) and true or false
  local upper=(self.upperCreatures[sourceID] or self.upperObjects[sourceID]
    or self.upperAreaTriggers[sourceID]) and true or false
  if lower and not upper then return "lower" end
  if upper and not lower then return "upper" end
  return nil
end

function K:NodeAllowed(node,context)
  if context~="lower" and context~="upper" then return false end
  if not node then return false end
  return self:GetSourceContext(node.sourceKind,node.sourceID)==context
end

function K:ItemAreaAllowed(area,context)
  if context~="lower" and context~="upper" then return false end
  if not area then return false end

  local found=false
  local _,source
  for _,source in pairs(area.sourceList or {}) do
    local sourceContext=self:GetAnySourceContext(source and source.id)
    -- A mixed or unclassified aggregated source is safer hidden than projected
    -- onto the wrong Karazhan floor/context.
    if not sourceContext or sourceContext~=context then return false end
    found=true
  end
  return found
end
