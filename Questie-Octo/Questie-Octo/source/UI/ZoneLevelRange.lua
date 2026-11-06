QuestieOcto.ZoneLevelRange = QuestieOcto.ZoneLevelRange or {}
local Z = QuestieOcto.ZoneLevelRange

-- Zone-level presentation adapted from the user-supplied LevelRange-Turtle and
-- LevelRange-Octo references. Questie-Octo intentionally keeps only the core
-- World Map zone range/diplomacy feature behind one option; LevelRange's
-- separate fishing/instance/raid option system is not imported here.
--
-- Ranges are keyed by the current client's AreaTable IDs. The third value is
-- the current Octo client's AreaTable faction-group mask:
--   0 = contested, 2 = Alliance, 4 = Horde.
-- This preserves LevelRange's Friendly/Hostile/Contested presentation while
-- keeping current-client map identity authoritative.
local ranges={
  -- Eastern Kingdoms
  [12]={1,10,2},     -- Elwynn Forest
  [1]={1,10,2},      -- Dun Morogh
  [85]={1,10,4},     -- Tirisfal Glades
  [38]={10,20,2},    -- Loch Modan
  [130]={10,20,4},   -- Silverpine Forest
  [40]={10,20,2},    -- Westfall
  [44]={15,25,0},    -- Redridge Mountains
  [10]={18,30,0},    -- Duskwood
  [267]={20,30,0},   -- Hillsbrad Foothills
  [11]={20,30,0},    -- Wetlands
  [36]={30,40,0},    -- Alterac Mountains
  [45]={30,40,0},    -- Arathi Highlands
  [33]={30,45,0},    -- Stranglethorn Vale
  [3]={35,45,0},     -- Badlands
  [8]={35,45,0},     -- Swamp of Sorrows
  [47]={40,50,0},    -- The Hinterlands
  [51]={43,50,0},    -- Searing Gorge
  [4]={45,55,0},     -- Blasted Lands
  [46]={50,58,0},    -- Burning Steppes
  [28]={51,58,0},    -- Western Plaguelands
  [139]={53,60,0},   -- Eastern Plaguelands
  [41]={55,60,0},    -- Deadwind Pass

  -- Kalimdor
  [14]={1,10,4},     -- Durotar
  [215]={1,10,4},    -- Mulgore
  [148]={10,20,2},   -- Darkshore
  [17]={10,25,4},    -- The Barrens
  [406]={15,27,0},   -- Stonetalon Mountains
  [331]={18,30,0},   -- Ashenvale
  [400]={25,35,0},   -- Thousand Needles
  [405]={30,40,0},   -- Desolace
  [15]={35,45,0},    -- Dustwallow Marsh
  [357]={40,50,0},   -- Feralas
  [440]={40,50,0},   -- Tanaris
  [16]={45,55,0},    -- Azshara
  [361]={48,55,0},   -- Felwood
  [490]={48,55,0},   -- Un'Goro Crater
  [1377]={55,60,0},  -- Silithus
  [618]={55,60,0},   -- Winterspring
  [493]={1,60,0},    -- Moonglade
  [141]={1,10,2},    -- Teldrassil

  -- Turtle WoW outdoor zones from the current Octo client.
  [5225]={1,10,2},   -- Thalassian Highlands
  [5536]={1,10,4},   -- Blackstone Island
  [5179]={39,46,0},  -- Gilneas
  [5024]={40,50,0},  -- Icepoint Rock
  [408]={48,53,0},   -- Gillijim's Isle
  [409]={48,53,0},   -- Lapidis Isle
  [5642]={50,56,0},  -- Moonwhisper Coast, Patch 1.18.1
  [5121]={54,60,0},  -- Tel'Abim
  [4012]={55,60,0},  -- Scarlet Enclave
  [616]={58,60,0},   -- Hyjal
  [5581]={28,34,0},  -- Northwind
  [5561]={29,34,0},  -- Balor
  [5602]={33,38,0},  -- Grim Reaches
}

-- Capital/subzone labels that LevelRange historically treated as their parent
-- outdoor leveling zone when hovered on the continent map.
local aliases={
  [1519]=12,   -- Stormwind City -> Elwynn Forest
  [1537]=1,    -- Ironforge -> Dun Morogh
  [1497]=85,   -- Undercity -> Tirisfal Glades
  [1637]=14,   -- Orgrimmar -> Durotar
  [1638]=215,  -- Thunder Bluff -> Mulgore
  [1657]=141,  -- Darnassus -> Teldrassil
  [2040]=5225, -- Alah'Thalas -> Thalassian Highlands
}

local tooltip=nil
local hoverFrame=nil
local normalizedAreas=nil
local lastArea=nil
local lastTexture=nil
local lastContinent=nil
local lastZone=nil
local elapsed=0

local function Trim(text)
  text=tostring(text or "")
  text=string.gsub(text,"^%s+","")
  text=string.gsub(text,"%s+$","")
  return text
end

local function Normalize(text)
  return string.lower(Trim(text))
end

local function ApplyAlias(id)
  id=tonumber(id)
  if id and aliases[id] then id=aliases[id] end
  return id
end

local function BuildAreaIndex()
  if normalizedAreas then return normalizedAreas end
  local areas=QuestieOcto.API and QuestieOcto.API.GetClientAreas
    and QuestieOcto.API:GetClientAreas() or nil
  if type(areas)~="table" then return {} end
  normalizedAreas={}
  for id,name in pairs(areas) do
    local key=Normalize(name)
    if key~="" then
      local previous=normalizedAreas[key]
      if previous==nil then
        normalizedAreas[key]=tonumber(id)
      elseif tonumber(previous)~=tonumber(id) then
        -- Keep duplicate names explicitly ambiguous. 1.18.1 currently has
        -- both AreaTable 40 and 206 named "Westfall", which is why 1.0.56's
        -- name-only hover fallback could not safely resolve the main zone.
        normalizedAreas[key]=false
      end
    end
  end
  return normalizedAreas
end

-- Blizzard's native WorldMapButton_OnUpdate calls UpdateMapHighlight(), which
-- assigns the exact current zone highlight texture. Prefer that texture identity
-- over the display name: WorldMapArea texture names are unique even when
-- AreaTable display names are not (Westfall is the current real example).
local function GetHoveredTextureName()
  if not WorldMapHighlight or not WorldMapHighlight.GetTexture then return nil end
  if WorldMapHighlight.IsShown and not WorldMapHighlight:IsShown() then return nil end
  local texture=WorldMapHighlight:GetTexture()
  if type(texture)~="string" or texture=="" then return nil end
  local file=string.gsub(texture,"^.*\\","")
  file=string.gsub(file,"Highlight$","")
  if file=="" then return nil end
  return file
end

local function ResolveAreaID(areaName,textureName)
  local api=QuestieOcto.API
  local id=nil

  -- Exact current-client WorldMapArea identity first. This is localized-client
  -- safe because it does not depend on the displayed zone text.
  if textureName and api and api.GetMapAreaIDForTexture then
    id=api:GetMapAreaIDForTexture(textureName)
  end
  id=ApplyAlias(id)
  if id then return id end

  if not areaName or areaName=="" then return nil end

  -- Fall back to the existing duplicate-safe client/package name indexes for
  -- clients or UI states where the native highlight texture is unavailable.
  local db=QuestieOcto.DatabaseAPI
  id=db and db.GetMapIDByName and db:GetMapIDByName(areaName) or nil
  if not id then
    local trimmed=Trim(areaName)
    if trimmed~=areaName then
      id=db and db.GetMapIDByName and db:GetMapIDByName(trimmed) or nil
    end
  end
  if not id then
    local index=BuildAreaIndex()
    local resolved=index[Normalize(areaName)]
    if type(resolved)=="number" then id=resolved end
  end

  return ApplyAlias(id)
end

local function IsContinentOverview()
  local continent=GetCurrentMapContinent and GetCurrentMapContinent() or 0
  local zone=GetCurrentMapZone and GetCurrentMapZone() or 0
  if not continent or continent<=0 or (zone and zone>0) then return false end

  -- Custom Turtle zones can leave GetCurrentMapZone() at zero even while a
  -- real zone texture is selected. Reuse Questie-Octo's current-client texture
  -- identity so the range panel remains a continent-hover feature only.
  local textureArea=QuestieOcto.API and QuestieOcto.API.GetDisplayedMapAreaID
    and QuestieOcto.API:GetDisplayedMapAreaID() or nil
  local continentArea=QuestieOcto.ContinentProjection
    and QuestieOcto.ContinentProjection.GetClientContinentMapID
    and QuestieOcto.ContinentProjection:GetClientContinentMapID(continent) or nil
  if textureArea and continentArea~=nil and tonumber(textureArea)~=tonumber(continentArea) then
    return false
  end
  return true
end

local function EnsureTooltip()
  if tooltip then return tooltip end
  if not WorldMapFrame then return nil end

  tooltip=CreateFrame("GameTooltip","QuestieOctoZoneLevelRangeTooltip",WorldMapFrame,"GameTooltipTemplate")
  tooltip:SetFrameStrata("TOOLTIP")
  tooltip:Hide()
  return tooltip
end

local function HideTooltip()
  if tooltip then tooltip:Hide() end
end

local function GetPlayerFaction()
  if not UnitFactionGroup then return nil end
  local first,second=UnitFactionGroup("player")
  if first=="Alliance" or first=="Horde" then return first end
  if second=="Alliance" or second=="Horde" then return second end
  return nil
end

local function GetDiplomacy(sideMask)
  sideMask=tonumber(sideMask) or 0
  if sideMask==0 then
    return "Contested",0.8,0.6,0.4
  end

  local zoneFaction=nil
  if sideMask==2 then zoneFaction="Alliance" end
  if sideMask==4 then zoneFaction="Horde" end
  if not zoneFaction then return nil end

  local playerFaction=GetPlayerFaction()
  if not playerFaction then return nil end
  if playerFaction==zoneFaction then
    return "Friendly",0.2,0.9,0.2
  end
  return "Hostile",0.9,0.2,0.2
end

local function ShowTooltip(areaName,range)
  local tip=EnsureTooltip()
  local anchor=WorldMapDetailFrame or WorldMapFrame
  if not tip or not anchor then return end

  tip:SetOwner(anchor,"ANCHOR_NONE")
  tip:ClearLines()
  tip:SetText(Trim(areaName),1,1,1)
  tip:AddLine(string.format("Levels %d - %d",range[1],range[2]),0.8,0.6,0.0)
  local diplomacy,r,g,b=GetDiplomacy(range[3])
  if diplomacy then tip:AddLine(diplomacy,r,g,b) end
  tip:ClearAllPoints()
  tip:SetPoint("BOTTOMLEFT",anchor,"BOTTOMLEFT",0,0)
  tip:Show()
end

function Z:Refresh()
  lastArea=nil
  lastTexture=nil
  lastContinent=nil
  lastZone=nil
  elapsed=0
  if not QuestieOcto.MinimapSettings or not QuestieOcto.MinimapSettings:Get("showZoneLevelRanges") then
    HideTooltip()
  end
end

local function Update()
  local settings=QuestieOcto.MinimapSettings
  if not settings or not settings:Get("showZoneLevelRanges") or not WorldMapFrame or not WorldMapFrame:IsShown() then
    HideTooltip()
    return
  end

  if not IsContinentOverview() then
    HideTooltip()
    return
  end

  local areaName=WorldMapFrame.areaName or ""
  local textureName=GetHoveredTextureName()
  local continent=GetCurrentMapContinent and GetCurrentMapContinent() or 0
  local zone=GetCurrentMapZone and GetCurrentMapZone() or 0
  if areaName==lastArea and textureName==lastTexture and continent==lastContinent and zone==lastZone then return end
  lastArea=areaName
  lastTexture=textureName
  lastContinent=continent
  lastZone=zone

  local areaID=ResolveAreaID(areaName,textureName)
  local range=areaID and ranges[areaID] or nil
  if not range then
    HideTooltip()
    return
  end

  ShowTooltip(areaName,range)
end

function Z:Initialize()
  if hoverFrame or not WorldMapFrame then return end
  hoverFrame=CreateFrame("Frame","QuestieOctoZoneLevelRangeFrame",WorldMapFrame)
  hoverFrame:Show()
  hoverFrame:SetScript("OnUpdate",function()
    elapsed=elapsed+(arg1 or 0)
    if elapsed<0.10 then return end
    elapsed=0
    Update()
  end)
end

Z:Initialize()
