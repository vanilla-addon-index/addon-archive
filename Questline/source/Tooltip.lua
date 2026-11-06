local Q,DB=Questline,QuestlineDB

-- Match live counters by objective name, never by the database's target order.
function Q:BuildTooltipProgress()
  self.tooltipProgress={};self.tooltipQuestTitles={}
  for questOrder,entry in ipairs(self.quests) do
    self.tooltipQuestTitles[self:Normalize(entry.title)]=true
    if entry.data and not entry.failed then
      for objectiveIndex,objective in ipairs(entry.objectives) do
        local _,_,name,current,required=string.find(objective.text,"^(.-):%s*(%d+)%s*/%s*(%d+)%s*$")
        if name and (objective.kind=="item" or objective.kind=="monster" or objective.kind=="object") then
          name=self:Normalize(name)
          if objective.kind=="monster" then
            name=string.gsub(name,"%s+slain$","");name=string.gsub(name,"%s+killed$","")
          end
          for _,target in ipairs(entry.data.objectives) do
            local kind=objective.kind=="item" and "item" or (objective.kind=="object" and "object" or "unit")
            if target.kind==kind and self:Normalize(target.name)==name then
              local progress={text=target.name.." - "..current.."/"..required,name=name,
                questKey=entry.key,questTitle=entry.title,questLevel=entry.level,questNumber=entry.number,questOrder=questOrder,objectiveIndex=objectiveIndex,
                current=tonumber(current),required=tonumber(required),done=objective.done or tonumber(current)>=tonumber(required)}
              self.tooltipProgress[target.key]=self.tooltipProgress[target.key] or {}
              table.insert(self.tooltipProgress[target.key],progress)
            end
          end
        end
      end
    end
  end
end
function Q:GetMobProgress(name,object)
  local groups,byQuest={},{}
  local mobName=self:Normalize(name)
  local rates=not object and DB.mobDropRates and DB.mobDropRates[mobName] or {}
  local index=object and (DB.objectObjectives or {}) or DB.mobObjectives
  for _,key in ipairs(index[mobName] or {}) do
    for _,progress in ipairs((self.tooltipProgress or {})[key] or {}) do
      local group=byQuest[progress.questKey]
      if not group then
        group={key=progress.questKey,title=progress.questTitle,level=progress.questLevel,number=progress.questNumber,order=progress.questOrder,objectives={},seen={}}
        byQuest[progress.questKey]=group;table.insert(groups,group)
      end
      if not group.seen[progress.objectiveIndex] then
        local displayed={}
        for field,value in pairs(progress) do displayed[field]=value end
        local rate=rates[key]
        if rate and rate>0 and rate<=100 then
          local percent=tostring(math.floor(rate+.5))
          local label=string.gsub(progress.text," %-%s*%d+/%d+$","")
          displayed.text=label.." ("..percent.."%) - "..progress.current.."/"..progress.required
        end
        table.insert(group.objectives,displayed);group.seen[progress.objectiveIndex]=true
      end
    end
  end
  -- Completed quests have no badge number; retain the sorted quest-list order.
  table.sort(groups,function(a,b) return a.order<b.order end)
  for _,group in ipairs(groups) do table.sort(group.objectives,function(a,b) return a.objectiveIndex<b.objectiveIndex end) end
  return groups
end
function Q:GetVendorProgress(name)
  local groups,byQuest={},{}
  for _,key in ipairs((DB.vendorObjectives or {})[self:Normalize(name)] or {}) do
    for _,progress in ipairs((self.tooltipProgress or {})[key] or {}) do
      local group=byQuest[progress.questKey]
      if not group then
        group={key=progress.questKey,title=progress.questTitle,level=progress.questLevel,number=progress.questNumber,order=progress.questOrder,objectives={},seen={}}
        byQuest[progress.questKey]=group;table.insert(groups,group)
      end
      if not group.seen[progress.objectiveIndex] then
        table.insert(group.objectives,progress);group.seen[progress.objectiveIndex]=true
      end
    end
  end
  table.sort(groups,function(a,b) return a.order<b.order end)
  for _,group in ipairs(groups) do table.sort(group.objectives,function(a,b) return a.objectiveIndex<b.objectiveIndex end) end
  return groups
end
local function leftLine(index) return getglobal("GameTooltipTextLeft"..index) end
local function sameProgress(text,progress)
  text=Q:Normalize(text);text=string.gsub(text,"^%-%s*","")
  text=string.gsub(text,"%s*%([<%d%.]+%%%)","")
  local _,_,name,current,required=string.find(text,"^(.-):%s*(%d+)%s*/%s*(%d+)")
  if not name then _,_,name,current,required=string.find(text,"^(.-)%s+%-%s+(%d+)%s*/%s*(%d+)") end
  return name and Q:Normalize(name)==progress.name and tonumber(current)==progress.current and tonumber(required)==progress.required
end
local function existingQuestGroup(group,owned,count,sectionTitle)
  local title=Q:Normalize(group.title)
  local section,seen,found,status=nil,{},false,nil
  for index=2,count do
    local line=leftLine(index)
    if not owned[index] and line and line:IsShown() then
      local text=line:GetText()
      -- pfQuest prefixes its quest headings with [!] or [?].
      local heading=string.gsub(Q:Normalize(text),"^%[[!%?]%]%s*","")
      heading=string.gsub(heading,"^%[%d+%]%s*","")
      if heading=="available" or heading=="in progress" or heading=="complete" then status=heading;section=nil
      elseif (Q.tooltipQuestTitles or {})[heading] or heading==title then
        section=heading
        if section==title and (not sectionTitle or status==Q:Normalize(sectionTitle)) then found=true end
      elseif section==title and (not sectionTitle or status==Q:Normalize(sectionTitle)) then
        for objective,progress in ipairs(group.objectives) do
          if sameProgress(text,progress) then seen[objective]=true end
        end
      end
    end
  end
  for index=1,table.getn(group.objectives) do if not seen[index] then return false end end
  return found
end
function Q:RefreshMobTooltip()
  if not self.ready or self.updatingMobTooltip or not GameTooltip:IsShown() then return end
  self.updatingMobTooltip=true
  local first=leftLine(1)
  local name=UnitName("mouseover")
  local title=first and self:Normalize(first:GetText())
  -- Original Vanilla lacks GetOwner. Title and retained-line checks below
  -- identify a lingering tooltip; use owner identity only on clients exposing it.
  local owner=GameTooltip.GetOwner and GameTooltip:GetOwner()
  local hovering=name and not UnitIsPlayer("mouseover") and title==self:Normalize(name)
  -- World objects have no mouseover unit on Vanilla. Only use the world
  -- tooltip title while the cursor is over the world, never inventory/UI items.
  local object=not name and title and DB.objectObjectives and DB.objectObjectives[title] and
    WorldFrame and GetMouseFocus and GetMouseFocus()==WorldFrame
  if object then name=first:GetText();hovering=true end
  -- Track only lines we appended. Other addons retain their own tooltip content.
  local owned,slots={},{}
  local count=GameTooltip:NumLines()
  for _,record in ipairs(self.mobTooltipLines or {}) do
    local line=leftLine(record.index)
    if record.index<=count and line and line:GetText()==record.text then
      owned[record.index]=true;table.insert(slots,record)
    end
  end
  -- A unit tooltip can linger/fade after "mouseover" stops identifying it.
  -- Keep its existing lines untouched, including its fade timer. Require the
  -- original owner (when available), title and our still-visible lines so a reused tooltip cannot
  -- inherit an old unit's quest details (even if it has the same title).
  if not hovering and self.mobTooltipName==title and self.mobTooltipOwner==owner then
    for _,record in ipairs(slots) do
      if record.text~="" and leftLine(record.index):IsShown() then self.updatingMobTooltip=false;return end
    end
  end
  self.mobTooltipName=hovering and title or nil
  self.mobTooltipOwner=hovering and owner or nil
  local desired,sections={},nil
  if hovering then
    if not object then sections=self:GetNPCSections(name) end
    if not object then desired=self:GetVendorProgress(name) end
    if not sections then for _,group in ipairs(self:GetMobProgress(name,object)) do table.insert(desired,group) end end
  end
  local lines={}
  if sections then for _,section in ipairs(sections) do
    local added=false
    for _,group in ipairs(section.groups) do
      local entry=group.key and self.byKey[group.key]
      local party=self:GetPartyQuestMembers(entry)
      if table.getn(party)>0 or not existingQuestGroup(group,owned,count,section.title) then
        if not added then table.insert(lines,{text=section.title,heading=true,section=true});added=true end
        table.insert(lines,{text="  "..self:QuestTitle(group),heading=true})
        for _,objective in ipairs(group.objectives) do
          local objectiveLines=self:PartyObjectiveLines(entry,objective.objectiveIndex,objective.text,objective.done,"    ")
          for _,line in ipairs(objectiveLines) do table.insert(lines,line) end
        end
        if entry and table.getn(group.objectives)==0 then
          local statusLines=self:PartyStatusLines(entry,"    ")
          for _,line in ipairs(statusLines) do table.insert(lines,line) end
        end
      end
    end
  end end
  for _,group in ipairs(desired) do
    -- Identical counters in different quests must each retain their own heading.
    local entry=group.key and self.byKey[group.key]
    local party=self:GetPartyQuestMembers(entry)
    if table.getn(party)>0 or not existingQuestGroup(group,owned,count) then
      table.insert(lines,{text=self:QuestTitle(group),heading=true})
      for _,progress in ipairs(group.objectives) do
        local objectiveLines=self:PartyObjectiveLines(entry,progress.objectiveIndex,progress.text,progress.done,"  ")
        for _,line in ipairs(objectiveLines) do table.insert(lines,line) end
      end
    end
  end
  local used,changed=0,false
  for _,progress in ipairs(lines) do
    used=used+1
    local record=slots[used]
    local red,green,blue=0.9,0.88,0.8
    if progress.section then red,green,blue=0.8,0.85,0.9
    elseif progress.heading then red,green,blue=1,0.82,0.32
    elseif progress.done then red,green,blue=0.4,0.9,0.45 end
    if not record then
      GameTooltip:AddLine(progress.text,red,green,blue,true)
      record={index=GameTooltip:NumLines()};slots[used]=record
    end
    if record.text~=progress.text or record.done~=progress.done or record.heading~=progress.heading or record.section~=progress.section then
      local line=leftLine(record.index)
      line:SetText(progress.text);line:SetTextColor(red,green,blue);line:Show()
      record.text=progress.text;record.done=progress.done;record.heading=progress.heading;record.section=progress.section;changed=true
    end
  end
  -- If a quest disappears while hovering, clear our old line without rebuilding
  -- the base tooltip (which would discard health bars and other addon details).
  for index=used+1,table.getn(slots) do
    local record=slots[index]
    if record.text~="" then leftLine(record.index):SetText("");leftLine(record.index):Hide();record.text="";changed=true end
  end
  self.mobTooltipLines=slots
  if changed then GameTooltip:Show() end
  self.updatingMobTooltip=false
end

-- Vanilla has no OnTooltipSetUnit script. A child frame preserves all existing
-- GameTooltip scripts and also notices tooltip rebuilds while the cursor stays put.
local watcher=CreateFrame("Frame","QuestlineMobTooltip",GameTooltip)
watcher:SetScript("OnShow",function() Q:RefreshMobTooltip() end)
watcher:SetScript("OnHide",function() Q.mobTooltipLines={};Q.mobTooltipName=nil;Q.mobTooltipOwner=nil end)
watcher:SetScript("OnUpdate",function()
  this.elapsed=(this.elapsed or 0)+(arg1 or 0)
  if this.elapsed<0.1 then return end
  this.elapsed=0;Q:RefreshMobTooltip()
end)
