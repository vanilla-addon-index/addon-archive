local Q, DB = Questline, QuestlineDB
local getn = table.getn
local blizzardPlates={}
local worldChildCount,lastRegistry

function Q:NameplateQuests(name)
  local keys=DB.mobObjectives[self:Normalize(name or "")]
  if not keys then return {} end
  local wanted={}
  for _,key in ipairs(keys) do wanted[key]=true end
  local result={}
  for _,entry in ipairs(self.quests) do
    if not entry.complete and not entry.failed then
      for _,target in ipairs(self:Targets(entry)) do if wanted[target.key] then
        table.insert(result,entry);break
      end end
    end
  end
  return result
end

local function plateName(nameplate)
  if nameplate.questlineNameRegion then return nameplate.questlineNameRegion:GetText() end
  local original=nameplate.original
  local name=original and original.name and original.name:GetText()
  if not name or name=="" then name=nameplate.name and nameplate.name:GetText() end
  return name
end

local function blizzardParts(frame)
  if not frame.GetObjectType or not frame.GetRegions or not frame.GetChildren then return end
  local kind=frame:GetObjectType()
  if kind~="Button" and kind~="Frame" then return end
  -- pfUI hides the native bar and draws a scaled/offset replacement overlay.
  -- Use its visible health bar, including when the native border is blanked.
  local replacement=frame.nameplate
  local original=replacement and replacement.original
  if original and original.healthbar and original.name and original.level and replacement.health then
    return original.name,replacement.health,replacement
  end
  local regions={frame:GetRegions()}
  local border=false
  for _,region in ipairs(regions) do
    if region.GetObjectType and region:GetObjectType()=="Texture" and
      region:GetTexture()=="Interface\\Tooltips\\Nameplate-Border" then border=true;break end
  end
  if not border then return end
  -- Vanilla's regions are border, glow, name, level, skull, raid icon.
  -- Keep the name region even while empty: the client fills it on plate reuse.
  local name=regions[3]
  if not name or not name.GetObjectType or name:GetObjectType()~="FontString" then return end
  for _,child in ipairs({frame:GetChildren()}) do
    if child.GetObjectType and child:GetObjectType()=="StatusBar" then return name,child end
  end
end

local function hideBadges(nameplate)
  nameplate.questlineVisible=nil;nameplate.questlineName=nil
  if nameplate.questlineBadges then
    for _,badge in ipairs(nameplate.questlineBadges) do badge:Hide() end
  end
end

local function scanBlizzardPlates(changesOnly)
  if not WorldFrame or not WorldFrame.GetChildren or not WorldFrame.GetNumChildren then return end
  local count=WorldFrame:GetNumChildren()
  -- Discover new children immediately; retry late initialization/replacement
  -- on the regular repaint. Cached plates are still checked every frame.
  if changesOnly and worldChildCount==count then return end
  worldChildCount=count
  local present={}
  for _,frame in ipairs({WorldFrame:GetChildren()}) do
    present[frame]=true
    local name,health,replacement=blizzardParts(frame)
    if name then
      local plate=replacement or frame
      if blizzardPlates[frame] and blizzardPlates[frame]~=plate then hideBadges(blizzardPlates[frame]) end
      plate.questlineNameRegion=name;plate.questlineHealthAnchor=health
      plate.questlineHealthGap=replacement and 5 or 24
      blizzardPlates[frame]=plate
    end
  end
  for frame,plate in pairs(blizzardPlates) do if not present[frame] then
    hideBadges(plate);blizzardPlates[frame]=nil
  end end
end

function Q:PaintNameplate(nameplate)
  if not nameplate then return end
  if QuestlineSettings and QuestlineSettings.nameplateBadges==false then hideBadges(nameplate);return end
  local name=plateName(nameplate)
  local entries=self:NameplateQuests(name)
  local numbers=QuestlineSettings.trackerMode=="zone" and self:GetZoneQuestNumbers(self:GetPlayerZone()) or {}
  nameplate.questlineBadges=nameplate.questlineBadges or {}
  local anchor=nameplate.questlineHealthAnchor or nameplate.health or nameplate
  local gap=nameplate.questlineHealthGap or (nameplate.questlineHealthAnchor and 24 or 5)
  for index,entry in ipairs(entries) do
    local badge=nameplate.questlineBadges[index]
    if not badge then
      badge=self:MakeBadge(nameplate,18);badge:EnableMouse(false)
      nameplate.questlineBadges[index]=badge
    end
    self:SizeBadge(badge,18,.78)
    badge:ClearAllPoints()
    if index==1 then badge:SetPoint("LEFT",anchor,"RIGHT",gap,0)
    else badge:SetPoint("LEFT",nameplate.questlineBadges[index-1],"RIGHT",2,0) end
    self:PaintBadge(badge,entry,self:IsSelected(entry.key),numbers[entry.key]);badge:Show()
  end
  for index=getn(entries)+1,getn(nameplate.questlineBadges) do nameplate.questlineBadges[index]:Hide() end
end

function Q:RefreshNameplates(changesOnly)
  local registry=GudaPlates and GudaPlates.registry
  if not registry then scanBlizzardPlates(changesOnly);registry=blizzardPlates end
  if lastRegistry and lastRegistry~=registry then
    for _,nameplate in pairs(lastRegistry) do hideBadges(nameplate) end
  end
  lastRegistry=registry
  for frame,nameplate in pairs(registry) do
    if (not QuestlineSettings or QuestlineSettings.nameplateBadges~=false) and frame:IsShown() and nameplate:IsShown() then
      local name=plateName(nameplate)
      if not changesOnly or not nameplate.questlineVisible or nameplate.questlineName~=name then
        self:PaintNameplate(nameplate)
      end
      nameplate.questlineVisible=true;nameplate.questlineName=name
    else
      hideBadges(nameplate)
    end
  end
end

local updater=CreateFrame("Frame","QuestlineNameplateUpdater")
local elapsed=0
updater:SetScript("OnUpdate",function()
  if QuestlineSettings and QuestlineSettings.nameplateBadges==false then return end
  elapsed=elapsed+arg1
  -- New/reused plates need badges on their first visible frame. Keep the
  -- more expensive quest-progress/selection repaint on the existing timer.
  local changesOnly=elapsed<.2
  if not changesOnly then elapsed=0 end
  Q:RefreshNameplates(changesOnly)
end)
