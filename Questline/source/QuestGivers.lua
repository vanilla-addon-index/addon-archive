local Q,DB=Questline,QuestlineDB
local getn,insert=table.getn,table.insert
local iconSize,hoverRadius=16,10
local texturePath="Interface\\AddOns\\Questline\\Textures\\"
local outside={[0]=466.6667,400,333.3333,266.6667,200,133.3333}
local inside={[0]=300,240,180,120,80,50}

local function hide(pool,first)
  for i=first or 1,getn(pool or {}) do pool[i]:Hide() end
end
function Q:GetAvailableGivers(zone)
  if not zone then return {} end
  self.giverCache=self.giverCache or {}
  local cached=self.giverCache[zone]
  if cached and cached.expires>GetTime() then return cached.entries end
  local entries={}
  for _,id in ipairs(DB.zoneGivers[zone] or {}) do
    local giver=DB.givers[id]
    local quests=self:GetAvailableNPCQuests(giver.name,giver.quests,giver.kind,giver.faction)
    if getn(quests)>0 then
      local points={}
      for _,point in ipairs(giver.coordinates) do if point[3]==zone then insert(points,point) end end
      if getn(points)>0 then insert(entries,{id=id,kind=giver.kind,name=giver.name,quests=quests,points=points}) end
    end
  end
  -- Only the displayed zones are queried. A short expiry also retires NPC
  -- dialogue observations; quest, skill and level events invalidate immediately.
  self.giverCache[zone]={entries=entries,expires=GetTime()+2}
  return entries
end
function Q:GetMinimapQuestNPCs(zone)
  local entries,byID={},{}
  for _,giver in ipairs(self:GetAvailableGivers(zone)) do
    local entry={id=giver.id,kind=giver.kind,name=giver.name,quests=giver.quests,points=giver.points,turnins={}}
    insert(entries,entry);byID[entry.id]=entry
  end
  if not zone then return entries end
  for _,quest in ipairs(self.quests) do if quest.complete and not quest.failed and quest.data then
    local seen={}
    for _,target in ipairs(quest.data.finishers or {}) do
      local id=target.kind=="object" and -target.id or target.id
      if (target.kind=="unit" or target.kind=="object") and not seen[id] then
      seen[id]=true
      local location=DB.locations[target.key] and DB.locations[target.key][zone]
      if location then
        local entry=byID[id]
        if not entry then
          local points=location.points or {}
          if getn(points)==0 and location.anchor then points={location.anchor} end
          entry={id=id,kind=target.kind,name=target.name,quests={},points=points,turnins={}}
          insert(entries,entry);byID[id]=entry
        end
        insert(entry.turnins,quest)
      end
    end end
  end end
  return entries
end
function Q:GetNearbyGivers(pin,minimap)
  local pool=minimap and self.minimapGivers or self.mapGivers
  local nearby,seen={pin.giver},{[pin.giver.id]=true}
  local radius=hoverRadius*pin:GetWidth()/iconSize
  for _,other in ipairs(pool) do
    if other:IsVisible() and other.giver and not seen[other.giver.id] and other.giverX and other.giverY then
      local dx,dy=other.giverX-pin.giverX,other.giverY-pin.giverY
      if dx*dx+dy*dy<=radius*radius then
        insert(nearby,other.giver);seen[other.giver.id]=true
      end
    end
  end
  table.sort(nearby,function(a,b) if a.name~=b.name then return a.name<b.name end;return a.id<b.id end)
  return nearby
end
function Q:ShowGiverTooltip(pin,minimap)
  if not pin.giver then return end
  local nearby=self:GetNearbyGivers(pin,minimap)
  local tip=minimap and GameTooltip or WorldMapTooltip
  tip:SetOwner(pin,"ANCHOR_CURSOR")
  for index,giver in ipairs(nearby) do
    if index==1 then self:SetSourceTooltipTitle(tip,giver.name)
    else tip:AddLine(" ");tip:AddLine(giver.name,1,1,1,true) end
    local available,complete,seenAvailable,seenComplete={},{},{},{}
    for _,quest in ipairs(giver.quests or {}) do
      local key=quest.key or quest.id or quest.title
      if not seenAvailable[key] then seenAvailable[key]=true;insert(available,quest) end
    end
    for _,quest in ipairs(giver.turnins or {}) do
      local key=quest.key or quest.id or quest.title
      if not seenComplete[key] then seenComplete[key]=true;insert(complete,quest) end
    end
    self:SortQuests(available);self:SortQuests(complete)
    if getn(available)>0 then
      tip:AddLine("  Available",.8,.85,.9)
      for _,quest in ipairs(available) do tip:AddLine("    "..self:QuestTitle(quest),1,.85,.4,true) end
    end
    if getn(complete)>0 then
      tip:AddLine("  Complete",.8,.85,.9)
      for _,quest in ipairs(complete) do tip:AddLine("    "..self:QuestTitle(quest),1,.85,.4,true) end
    end
  end
  tip:Show()
end
function Q:GetGiverPin(index,minimap)
  local pool=minimap and self.minimapGivers or self.mapGivers
  if not pool[index] then
    local parent=minimap and Minimap or self.pinLayer
    local pin=CreateFrame("Button",nil,parent)
    pin:SetWidth(iconSize);pin:SetHeight(iconSize);pin:SetFrameLevel(parent:GetFrameLevel()+3)
    pin.texture=pin:CreateTexture(nil,"ARTWORK");pin.texture:SetAllPoints(pin)
    pin.texture:SetTexture(texturePath.."quest-available")
    if not minimap then
      pin.glow=pin:CreateTexture(nil,"BACKGROUND");pin.glow:SetPoint("CENTER",pin,"CENTER",0,0);pin.glow:SetTexture(texturePath.."turnin-glow");pin.glow:Hide()
      pin:RegisterForClicks("RightButtonUp")
      pin:SetScript("OnClick",function() if arg1=="RightButton" then Q:ShowCompletionMenu(this,false) end end)
    end
    pin:SetScript("OnEnter",function() Q:ShowGiverTooltip(this,minimap) end)
    pin:SetScript("OnLeave",function() GameTooltip:Hide();WorldMapTooltip:Hide() end)
    pool[index]=pin
  end
  return pool[index]
end
function Q:RefreshGiverMap()
  if not self.pinLayer or not WorldMapFrame:IsVisible() then hide(self.mapGivers);self.giverMapLayout=nil;return end
  local zone=self:GetMapZone()
  local entries=self:GetMinimapQuestNPCs(zone)
  local width,height=WorldMapButton:GetWidth(),WorldMapButton:GetHeight()
  local scale=WorldMapFrame:GetEffectiveScale()/WorldMapButton:GetEffectiveScale()
  local key=tostring(zone)..":"..width..":"..height..":"..scale
  if self.giverMapLayout==key and self.giverMapEntries==entries then return end
  self.giverMapLayout=key;self.giverMapEntries=entries
  local count=0
  if width>0 and height>0 then for _,giver in ipairs(entries) do
    count=count+1
    local pin=self:GetGiverPin(count,false);pin.giver=giver
    pin:SetWidth(iconSize*scale);pin:SetHeight(iconSize*scale)
    local hasTurnin=getn(giver.turnins or {})>0
    pin.texture:SetTexture(texturePath..(hasTurnin and "quest-complete" or "quest-available"))
    local selected=false
    for _,quest in ipairs(giver.turnins or {}) do if self:IsSelected(quest.key) then selected=true;break end end
    if selected then pin.glow:SetWidth(26*scale);pin.glow:SetHeight(26*scale);pin.glow:Show() else pin.glow:Hide() end
    pin:SetFrameLevel(self.pinLayer:GetFrameLevel()+(selected and 6 or 3))
    pin.giverX=giver.points[1][1]/100*width;pin.giverY=-giver.points[1][2]/100*height
    -- One marker per NPC in the zone, even if it has several quests/spawns.
    self:PlacePin(pin,giver.points[1],width,height)
  end end
  hide(self.mapGivers,count+1)
end
function Q:MinimapDiameter()
  local zoom=Minimap:GetZoom()
  local a,b=tonumber(GetCVar("minimapZoom")),tonumber(GetCVar("minimapInsideZoom"))
  local key=tostring(zoom)..":"..tostring(a)..":"..tostring(b)
  if self.minimapDiameterKey==key then return self.minimapDiameterValue end
  local indoor
  -- The minimap's active zoom CVar determines its scale. Physical indoor
  -- status (IsIndoors on extended clients) need not match the city's map mode.
  if not a or not b then return nil end
  if a==b then
    -- Probe only on a new map/zoom context, never on each movement frame.
    -- Ignore the synchronous and queued zoom events generated by this probe.
    local probe=zoom<5 and zoom+1 or zoom-1
    self.minimapZoomProbe=true
    self.minimapZoomProbeUntil=GetTime()+0.25
    Minimap:SetZoom(probe)
    indoor=tonumber(GetCVar("minimapInsideZoom"))==probe
    Minimap:SetZoom(zoom)
    self.minimapZoomProbe=nil
  else indoor=zoom==b end
  self.minimapDiameterKey=key;self.minimapDiameterValue=(indoor and inside or outside)[zoom]
  return self.minimapDiameterValue
end
function Q:MinimapGiverPosition(point,x,y,size,diameter,facing)
  local dx=(point[1]/100-x)*size[1]
  local dy=(y-point[2]/100)*size[2]
  if facing then
    local cosine,sine=math.cos(facing),math.sin(facing)
    dx,dy=dx*cosine+dy*sine,-dx*sine+dy*cosine
  end
  dx=dx*Minimap:GetWidth()/diameter;dy=dy*Minimap:GetHeight()/diameter
  local rx,ry=Minimap:GetWidth()/2-iconSize/2,Minimap:GetHeight()/2-iconSize/2
  if rx<=0 or ry<=0 then return nil end
  local square=GetMinimapShape and GetMinimapShape()=="SQUARE"
  if (square and math.abs(dx)<=rx and math.abs(dy)<=ry) or
    (not square and dx*dx/(rx*rx)+dy*dy/(ry*ry)<=1) then return dx,dy end
end
function Q:RefreshGiverMinimap(motionOnly)
  local previous=self.minimapSpawnContext
  self.minimapSpawnContext=nil
  -- GetPlayerMapPosition uses the currently browsed map in Vanilla. Never
  -- reset that map while the player is looking at it, or use wrong-zone coords.
  if not Minimap or not Minimap:IsVisible() or not GetPlayerMapPosition then hide(self.minimapGivers);return end
  local zone=self:GetPlayerZone()
  local size=zone and DB.zones[zone] and DB.zones[zone].mapSize
  if not size or not size[1] or not size[2] or size[1]<=0 or size[2]<=0 then hide(self.minimapGivers);return end
  if self:GetMapZone()~=zone and not WorldMapFrame:IsVisible() and SetMapToCurrentZone then SetMapToCurrentZone() end
  local x,y
  if self:GetMapZone()==zone then
    x,y=GetPlayerMapPosition("player")
    if not x or not y or (x==0 and y==0) then self.minimapPlayerPosition=nil;hide(self.minimapGivers);return end
    self.minimapPlayerPosition={zone=zone,x=x,y=y}
  else
    -- Keep nearby pins visible while a windowed map browses another zone.
    -- Its coordinates cannot locate the player: reuse only a same-zone sample.
    local last=self.minimapPlayerPosition
    if not last or last.zone~=zone then hide(self.minimapGivers);return end
    x,y=last.x,last.y
  end
  local diameter=self:MinimapDiameter()
  if not diameter then hide(self.minimapGivers);return end
  local data=self.minimapRenderData
  if not motionOnly or not data or data.zone~=zone then
    data={zone=zone,entries=self:GetMinimapQuestNPCs(zone),spawns=self:SelectedSpawns(zone)}
    self.minimapRenderData=data
    self.minimapRotates=false
    if GetPlayerFacing and GetCVar then
      local ok,rotation=pcall(GetCVar,"rotateMinimap")
      self.minimapRotates=ok and rotation=="1"
    end
  end
  local facing
  if self.minimapRotates and GetPlayerFacing then facing=GetPlayerFacing() end
  local width,height=Minimap:GetWidth(),Minimap:GetHeight()
  local shape=GetMinimapShape and GetMinimapShape() or "ROUND"
  self.minimapSpawnContext={zone=zone,size=size,x=x,y=y,diameter=diameter,facing=facing,width=width,height=height,shape=shape}
  if motionOnly and previous and previous.zone==zone and previous.x==x and previous.y==y and
    previous.diameter==diameter and previous.facing==facing and previous.width==width and previous.height==height and previous.shape==shape then return false end
  local count=0
  local entries=data.entries
  for _,giver in ipairs(entries) do
    local bestX,bestY,distance
    for _,point in ipairs(giver.points) do
      local dx,dy=self:MinimapGiverPosition(point,x,y,size,diameter,facing)
      if dx and (not distance or dx*dx+dy*dy<distance) then bestX,bestY,distance=dx,dy,dx*dx+dy*dy end
    end
    if bestX then
      count=count+1
      local pin=self:GetGiverPin(count,true);pin.giver=giver
      pin.texture:SetTexture(texturePath..(getn(giver.turnins)>0 and "quest-complete" or "quest-available"))
      pin.giverX=bestX;pin.giverY=bestY
      pin:ClearAllPoints();pin:SetPoint("CENTER",Minimap,"CENTER",bestX,bestY);pin:Show()
    end
  end
  hide(self.minimapGivers,count+1)
end
function Q:RefreshMinimapMotion()
  self.minimapGivers=self.minimapGivers or {}
  if self:RefreshGiverMinimap(true)~=false then self:RefreshSpawnMinimap() end
end
function Q:RefreshQuestGivers()
  self.mapGivers=self.mapGivers or {};self.minimapGivers=self.minimapGivers or {}
  self:RefreshGiverMap();self:RefreshGiverMinimap()
  self:RefreshSpawnMinimap()
end
