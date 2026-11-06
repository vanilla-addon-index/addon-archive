-- Questline party protocol 1. Party-only, session-scoped; no saved remote data.
local Q=Questline
local getn,insert=table.getn,table.insert
local prefix="QL_P1"
local chunkSize,maxParts,maxQuests,maxObjectives=180,34,100,20
local function integer(text,minimum,maximum)
  local value=tonumber(text)
  if value and value==math.floor(value) and value>=minimum and value<=maximum then return value end
end
local function split(text,delimiter)
  local result,start={},1
  while true do
    local first,last=string.find(text,delimiter,start,true)
    if not first then insert(result,string.sub(text,start));return result end
    insert(result,string.sub(text,start,first-1));start=last+1
  end
end
local function encode(text)
  return string.gsub(text,"[%%\t\r\n]",function(char) return string.format("%%%02X",string.byte(char)) end)
end
local function decode(text)
  return string.gsub(text,"%%(%x%x)",function(hex) return string.char(tonumber(hex,16)) end)
end
function Q:PartyObjective(objective)
  local text=objective.text or ""
  local _,_,label,current,required=string.find(text,"^(.-):%s*(%d+)%s*/%s*(%d+)%s*$")
  local kind=self:Normalize(objective.kind or "event")
  label=self:Normalize(label or text)
  return kind.."\t"..label,tonumber(current),tonumber(required),kind,label
end
function Q:PartyQuestBody(entry)
  if not entry.id or getn(entry.objectives)>maxObjectives then return nil end
  local rows={entry.failed and "F" or entry.complete and "C" or "A"}
  for _,objective in ipairs(entry.objectives) do
    local key,current,required,kind,label=self:PartyObjective(objective)
    if string.len(kind)>32 or string.len(label)>512 then return nil end
    insert(rows,encode(kind).."\t"..encode(label).."\t"..(current or "").."\t"..(required or "").."\t"..(objective.done and "1" or "0"))
  end
  local body=table.concat(rows,"\n")
  if string.len(body)>6000 then return nil end
  return body
end
function Q:ParsePartyQuest(body)
  if string.len(body)>6000 then return nil end
  local rows=split(body,"\n")
  if (rows[1]~="A" and rows[1]~="C" and rows[1]~="F") or getn(rows)>maxObjectives+1 then return nil end
  local quest={status=rows[1],objectives={},time=GetTime()}
  for index=2,getn(rows) do
    local fields=split(rows[index],"\t")
    if getn(fields)~=5 or (fields[5]~="0" and fields[5]~="1") then return nil end
    local kind,label=decode(fields[1]),decode(fields[2])
    if string.len(kind)>32 or string.len(label)>512 or string.find(kind,"[\t\r\n]") or string.find(label,"[\t\r\n]") then return nil end
    local current,required
    if fields[3]~="" or fields[4]~="" then
      current=integer(fields[3],0,1000000000);required=integer(fields[4],1,1000000000)
      if not current or not required then return nil end
    end
    local key=kind.."\t"..label
    -- Repeated labels cannot be aligned reliably. Never guess by row number.
    if quest.objectives[key]~=nil then quest.objectives[key]=false
    else quest.objectives[key]={current=current,required=required,done=fields[5]=="1"} end
  end
  return quest
end
function Q:EnsurePartyState()
  if not self.party then
    self.party={session=tostring(math.floor(GetTime()*1000)).."-"..math.random(100000,999999),
      members={},byName={},peers={},outbox={},order={},localBodies={},sequence=0,dirty=true,force=true}
  end
  return self.party
end
function Q:RefreshPartyRoster()
  local state=self:EnsurePartyState()
  local members,byName,signature={},{},{}
  local count=GetNumPartyMembers and GetNumPartyMembers() or 0
  if GetNumRaidMembers and GetNumRaidMembers()>0 then count=0 end
  for index=1,math.min(4,count) do
    local unit="party"..index;local name=UnitName(unit)
    if name and name~=UnitName("player") then
      local connected=true
      if UnitIsConnected then connected=UnitIsConnected(unit) and true or false end
      local member={name=name,unit=unit,connected=connected}
      insert(members,member);byName[name]=member;insert(signature,name..":"..(connected and "1" or "0"))
      local old=state.byName[name]
      if old and not old.connected and connected then state.peers[name]=nil end
    end
  end
  for name in pairs(state.peers) do if not byName[name] then state.peers[name]=nil end end
  local key=table.concat(signature,";")
  state.members=members;state.byName=byName
  if key~=state.roster then
    state.roster=key;state.force=true;state.dirty=true;state.hello=getn(members)>0;self.dirty=true
    state.outbox={};state.order={};state.localBodies={}
    if getn(members)==0 then state.peers={};state.manifest=nil end
  end
end
function Q:ReadPartyQuestMembership(index,entry)
  if not IsUnitOnQuest or not GetNumPartyMembers then return end
  if GetNumRaidMembers and GetNumRaidMembers()>0 then return end
  entry.partyMembers={}
  for member=1,math.min(4,GetNumPartyMembers()) do
    local unit="party"..member;local name=UnitName(unit)
    if name then
      local ok,shared=pcall(IsUnitOnQuest,index,unit)
      if ok and shared and shared~=0 then entry.partyMembers[name]=true end
    end
  end
end
function Q:PartyPackets(id,body,sequence,session)
  local messages={};local count=math.max(1,math.ceil(string.len(body)/chunkSize))
  if count>maxParts then return nil end
  for part=1,count do
    insert(messages,"D\t"..session.."\t"..sequence.."\t"..id.."\t"..part.."\t"..count.."\t"..string.sub(body,(part-1)*chunkSize+1,part*chunkSize))
  end
  return messages
end
function Q:QueuePartyRecord(id,body)
  local state=self.party;local old=state.outbox[id]
  if old and old.body==body then return end
  state.sequence=state.sequence+1
  local messages=self:PartyPackets(id,body,state.sequence,state.session)
  if not messages then return end
  if not old then insert(state.order,id) end
  state.outbox[id]={messages=messages,next=1,body=body}
end
function Q:BuildPartyOutbox()
  local state=self.party;local bodies,ids={},{}
  for _,entry in ipairs(self.quests) do
    if entry.id and getn(ids)<maxQuests and not bodies[entry.id] then
      local body=self:PartyQuestBody(entry)
      if body then bodies[entry.id]=body;insert(ids,entry.id) end
    end
  end
  table.sort(ids)
  local names={};for _,id in ipairs(ids) do insert(names,tostring(id)) end
  local manifest=table.concat(names,",")
  if state.force or manifest~=state.manifest then self:QueuePartyRecord(0,manifest) end
  for _,id in ipairs(ids) do if state.force or bodies[id]~=state.localBodies[id] then self:QueuePartyRecord(id,bodies[id]) end end
  for id in pairs(state.outbox) do if id~=0 and not bodies[id] then state.outbox[id]=nil end end
  state.localBodies=bodies;state.manifest=manifest;state.dirty=false;state.force=false;state.lastSnapshot=GetTime()
end
function Q:ReceivePartyMessage(message,channel,sender)
  if channel~="PARTY" or type(message)~="string" or string.len(message)>249 then return end
  self:RefreshPartyRoster()
  local state=self.party;local member=state.byName[sender]
  if not member or not member.connected or sender==UnitName("player") then return end
  local peer=state.peers[sender]
  if not peer then peer={quests={},revisions={},pending={},retired={}};state.peers[sender]=peer end
  local now=GetTime()
  if not peer.window or now-peer.window>=5 then peer.window=now;peer.received=0 end
  peer.received=peer.received+1;if peer.received>80 then return end
  local _,_,hello=string.find(message,"^H\t([%w%-]+)$")
  local _,_,session,sequence,id,part,total,payload=string.find(message,"^D\t([%w%-]+)\t(%d+)\t(%d+)\t(%d+)\t(%d+)\t(.*)$")
  session=hello or session
  if not session or string.len(session)>24 then return end
  if not hello then
    sequence=integer(sequence,1,1000000000);id=integer(id,0,1000000000)
    part=integer(part,1,maxParts);total=integer(total,1,maxParts)
    if not sequence or not id or not part or not total or part>total or string.len(payload)>chunkSize then return end
  end
  if peer.session~=session then
    for _,old in ipairs(peer.retired) do if old==session then return end end
    if peer.session then insert(peer.retired,peer.session);if getn(peer.retired)>8 then table.remove(peer.retired,1) end end
    peer.session=session;peer.quests={};peer.revisions={};peer.pending={};peer.manifest=nil;peer.manifestRevision=nil
    peer.lastRequest=nil
  end
  if hello then
    if not peer.lastRequest or now-peer.lastRequest>=5 then state.force=true;peer.lastRequest=now end
    return
  end
  if sequence<=(peer.revisions[id] or 0) then return end
  -- A replacement manifest may overtake an unchanged queued quest record.
  -- Older records are still valid for included quests; removed quests must
  -- remain protected against late packets resurrecting their counters.
  if sequence<(peer.manifestRevision or 0) and (id==0 or not peer.manifest[id]) then return end
  local pending=peer.pending[id]
  if pending and pending.sequence>sequence then return end
  if not pending or pending.sequence~=sequence or now-pending.time>15 then
    local count=0;for key in pairs(peer.pending) do count=count+1 end
    if count>=maxQuests+1 and not pending then return end
    pending={sequence=sequence,total=total,parts={},count=0,time=now};peer.pending[id]=pending
  end
  if pending.total~=total then return end
  if pending.parts[part] and pending.parts[part]~=payload then peer.pending[id]=nil;return end
  if not pending.parts[part] then pending.parts[part]=payload;pending.count=pending.count+1 end
  if pending.count~=total then return end
  local body=table.concat(pending.parts);peer.pending[id]=nil
  if string.len(body)>6000 then return end
  if id==0 then
    local manifest={};local ids=body=="" and {} or split(body,",")
    if getn(ids)>maxQuests then return end
    for _,value in ipairs(ids) do local questId=integer(value,1,1000000000);if not questId or manifest[questId] then return end;manifest[questId]=true end
    peer.manifest=manifest;peer.manifestRevision=sequence;peer.manifestTime=now
    for questId in pairs(peer.quests) do
      if not manifest[questId] and (peer.revisions[questId] or 0)<=sequence then peer.quests[questId]=nil;peer.revisions[questId]=nil end
    end
  else
    local quest=self:ParsePartyQuest(body);if not quest then return end
    local count=0;for key in pairs(peer.quests) do count=count+1 end
    if count>=maxQuests and not peer.quests[id] then return end
    peer.quests[id]=quest
  end
  peer.revisions[id]=sequence
end
function Q:GetPartyQuestMembers(entry)
  local state=self.party;local result={}
  if not state or not entry then return result end
  for _,member in ipairs(state.members) do
    local peer=state.peers[member.name];local quest=peer and entry.id and peer.quests[entry.id]
    -- Missing, disconnected or expired progress is omitted from tooltips.
    if quest and member.connected and GetTime()-quest.time<=90 then
      insert(result,{name=member.name,unit=member.unit,quest=quest,status=quest.status=="F" and "Quest failed" or nil})
    end
  end
  return result
end
function Q:PartyMemberName(member)
  local class
  if member.unit and UnitClass then local localized;localized,class=UnitClass(member.unit) end
  local color=RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if not color then return member.name end
  return string.format("|cff%02x%02x%02x%s|r",math.floor(color.r*255+.5),math.floor(color.g*255+.5),math.floor(color.b*255+.5),member.name)
end
function Q:PartyObjectiveLines(entry,index,text,done,indent)
  local members=self:GetPartyQuestMembers(entry)
  if getn(members)==0 or not index or not entry.objectives[index] then return {{text=indent..text,done=done}} end
  local key,current,required=self:PartyObjective(entry.objectives[index])
  local label=string.gsub(string.gsub(text," %-%s*%d+/%d+$",""),":%s*%d+%s*/%s*%d+%s*$","")
  local own=current and (current.."/"..required) or (done and "Complete" or "Incomplete")
  local lines={{text=indent..label},{text=indent.."  You: "..own,done=done}}
  for _,member in ipairs(members) do
    local objective=member.quest and member.quest.objectives[key]
    local status,finished=member.status,false
    if not status then
      if objective and objective.required==required then
        status=objective.current and (objective.current.."/"..objective.required) or (objective.done and "Complete" or "Incomplete")
        finished=member.quest.status=="C" or objective.done or (objective.current and objective.current>=objective.required)
      elseif member.quest.status=="C" then status="Ready for turn-in";finished=true
      end
    end
    if status then insert(lines,{text=indent.."  "..self:PartyMemberName(member)..": "..status,done=finished}) end
  end
  if getn(lines)==2 then return {{text=indent..text,done=done}} end
  return lines
end
function Q:PartyStatusLines(entry,indent)
  local lines={}
  for _,member in ipairs(self:GetPartyQuestMembers(entry)) do
    local complete=not member.status and member.quest.status=="C"
    insert(lines,{text=indent..self:PartyMemberName(member)..": "..(member.status or (complete and "Ready for turn-in" or "In progress")),done=complete})
  end
  return lines
end
function Q:UpdatePartySync()
  local state=self:EnsurePartyState();local now=GetTime()
  if not state.rosterAt or now>=state.rosterAt then
    self:RefreshPartyRoster();state.rosterAt=now+1
    for name,peer in pairs(state.peers) do for id,pending in pairs(peer.pending) do if now-pending.time>15 then peer.pending[id]=nil end end end
  end
  if getn(state.members)==0 then return end
  if not state.membershipAt or now>=state.membershipAt then self.dirty=true;state.membershipAt=now+15 end
  if not state.fullAt or now>=state.fullAt then state.force=true;state.fullAt=now+60 end
  if state.dirty or state.force then self:BuildPartyOutbox() end
  if SendAddonMessage and (not state.sentAt or now-state.sentAt>=.25) then
    local message
    if state.hello then message="H\t"..state.session;state.hello=false
    else while getn(state.order)>0 do
      local id=state.order[1];local record=state.outbox[id]
      if not record then table.remove(state.order,1)
      else
        message=record.messages[record.next];record.next=record.next+1
        if record.next>getn(record.messages) then state.outbox[id]=nil;table.remove(state.order,1) end
        break
      end
    end end
    if message then SendAddonMessage(prefix,message,"PARTY");state.sentAt=now end
  end
  -- Rebuild only our own actively hovered quest tooltip. Unit tooltips already
  -- refresh through their child watcher; fading tooltips remain untouched.
  local hover=self.partyQuestTooltip
  if hover and MouseIsOver and hover.owner:IsVisible() and hover.tip:IsShown() and MouseIsOver(hover.owner)
    and (not state.tooltipAt or now>=state.tooltipAt) then
    local entry=self.byKey[hover.key]
    if entry then self:ShowQuestTooltip(hover.owner,entry,hover.target,hover.sourceName) end
    state.tooltipAt=now+1
  end
end
local events=CreateFrame("Frame","QuestlinePartyEvents")
for _,name in ipairs({"CHAT_MSG_ADDON","PARTY_MEMBERS_CHANGED","PARTY_MEMBER_ENABLE","PARTY_MEMBER_DISABLE","PLAYER_ENTERING_WORLD"}) do events:RegisterEvent(name) end
events:SetScript("OnEvent",function()
  if not Q.ready then return end
  if event=="CHAT_MSG_ADDON" then
    if arg1==prefix then Q:ReceivePartyMessage(arg2,arg3,arg4) end
  else Q:RefreshPartyRoster();Q.party.force=true;Q.dirty=true end
end)
