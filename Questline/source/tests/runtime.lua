-- Strict WoW 1.12 UI/API simulation; this does not claim to render the game.
table.getn = table.getn or function(t) return #t end
math.mod = math.mod or math.fmod
unpack = unpack or table.unpack
-- Lua 5.0 uses ipairs itself as the iterator. Supplying ANY second argument
-- (even nil) performs an iteration step, unlike Fengari's newer Lua behavior.
-- Reference: https://www.lua.org/source/5.0/lbaselib.c.html#luaB_ipairs
function ipairs(t,...)
  assert(type(t)=="table","ipairs expects a table")
  if select("#",...)==0 then return ipairs,t,0 end
  local index=(tonumber((...)) or 0)+1
  local integer=math.modf(index)
  local value=rawget(t,integer)
  if value~=nil then return index,value end
end
local checks=0
function expect(test,message) checks=checks+1;if not test then error(message) end end
local widgets={}
local methods={}
local minimapIndoor,playerX,playerY,playerFacing=false,.522,.31,0
local minimapShape="ROUND"
local cvars={minimapZoom="0",minimapInsideZoom="0",rotateMinimap="0"}
local zoomWrites,mapResets=0,0
function GetCVar(name)
  if cvars[name]==nil then error("Couldn't find CVar named '"..name.."'") end
  return cvars[name]
end
function GetPlayerFacing() return playerFacing end
function GetPlayerMapPosition() return playerX,playerY end
function GetMinimapShape() return minimapShape end
function methods:GetZoom() return tonumber(cvars[minimapIndoor and "minimapInsideZoom" or "minimapZoom"]) end
function methods:SetZoom(value) cvars[minimapIndoor and "minimapInsideZoom" or "minimapZoom"]=tostring(value);zoomWrites=zoomWrites+1 end
function methods:SetResizable(v) self.resizable=v end
function methods:SetNormalTexture(texture) self.normalTexture=texture end
function methods:SetBlendMode(mode) self.blendMode=mode end
function methods:SetPushedTexture(texture) self.pushedTexture=texture end
function methods:SetHighlightTexture(texture) self.highlightTexture=texture end
function methods:SetParent(parent) self.parent=parent end
function methods:SetAutoFocus(value) self.autoFocus=value end
function methods:SetMaxLetters(value) self.maxLetters=value end
function methods:ClearFocus() self.focused=false end
function methods:SetMinResize(w,h) self.minResize={w,h} end
function methods:SetMaxResize(w,h) self.maxResize={w,h} end
function methods:StartSizing(point) self.sizing=point end
function methods:SetWidth(v) self.width=v end
function methods:SetHeight(v) self.height=v end
function methods:SetAlpha(v) self.alpha=v end
function methods:SetVertexColor(...) self.vertexColor={...} end
function methods:SetChecked(v) self.checked=v end
function methods:GetChecked() return self.checked end
function methods:GetWidth() return self.width or (self.allPoints and self.allPoints:GetWidth()) or 100 end
function methods:GetHeight()
  if self.kind=="FontString" and not self.height then
    local text=string.gsub(self.text or "","|c%x%x%x%x%x%x%x%x","");text=string.gsub(text,"|r","")
    local lines=0
    for line in string.gmatch(text.."\n","(.-)\n") do lines=lines+math.max(1,math.ceil(string.len(line)*(self.fontSize or 12)*.5/self:GetWidth())) end
    return lines*(self.fontSize or 12)
  end
  return self.height or (self.allPoints and self.allPoints:GetHeight()) or 100
end
function methods:SetPoint(...) self.point={...} end
function methods:ClearAllPoints() self.point=nil end
function methods:SetAllPoints(frame) self.allPoints=frame or self.parent end
function methods:Show() self.shown=true;self.fading=false;self.showCalls=(self.showCalls or 0)+1 end
function methods:FadeOut() self.fading=true end
function methods:Hide()
  local shown=self.shown;self.shown=false
  if shown and self.scripts.OnHide then
    local previous=this;this=self;self.scripts.OnHide();this=previous
  end
  if shown and self==GameTooltip and QuestlineMobTooltip then
    local previous=this;this=QuestlineMobTooltip;this.scripts.OnHide();this=previous
  end
end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:SetFrameLevel(level) self.level=level end
function methods:GetFrameLevel() return self.level or 1 end
function methods:SetFrameStrata(strata) self.strata=strata end
function methods:GetFrameStrata() return self.strata or (self.parent and self.parent:GetFrameStrata()) or "MEDIUM" end
function methods:GetEffectiveScale() return self.scale or (self.parent and self.parent:GetEffectiveScale()) or 1 end
function methods:GetParent() return self.parent end
function methods:GetName() return self.name end
function methods:GetObjectType() return self.kind end
function methods:GetTexture() return self.textureValue and self.textureValue[1] end
function methods:GetFontObject() return self.fontObject end
function methods:SetFontObject(value) self.fontObject=value end
function methods:SetOwner(owner) self.owner=owner end
function methods:GetLeft() return 20 end
function methods:GetTop() return 600 end
function methods:RegisterEvent(event) self.events[event]=true end
function methods:UnregisterEvent(event) self.events[event]=nil end
function methods:EnableMouse(enabled) self.mouseEnabled=enabled end
function methods:RegisterForClicks(...) self.clicks={...} end
function methods:SetFocus() self.focused=true end
function methods:Insert(text)
  local cursor=self.cursor or string.len(self.text or "")
  self.text=string.sub(self.text or "",1,cursor)..text..string.sub(self.text or "",cursor+1)
  self.cursor=cursor+string.len(text)
end
function methods:SetValue(value)
  self.value=value
  if self==QuestLogListScrollFrameScrollBar then QuestLogListScrollFrame.offset=math.floor(value/16) end
end
function methods:SetScript(event,script) self.scripts[event]=script end
function methods:GetScript(event) return self.scripts[event] end
function methods:SetTexture(...) self.textureValue={...} end
function methods:SetTexCoord(...) self.texCoords={...} end
function methods:SetShadowColor(...) self.shadowColor={...} end
function methods:SetShadowOffset(...) self.shadowOffset={...} end
function methods:SetFont(file,size,flags) self.fontSize=size end
function methods:SetText(text)
  self.text=tostring(text or "")
  if self==GameTooltip then
    for i=1,self:NumLines() do _G["GameTooltipTextLeft"..i]:Hide() end
    self.numLines=0;self:AddLine(self.text)
  end
end
function methods:GetText() return self.text end
function methods:GetStringWidth() return string.len(self.text or "")*(self.fontSize or 12)*.5 end
function methods:AddMessage(text) self.text=text end
function methods:NumLines() return self.numLines or 0 end
function methods:AddLine(text,...)
  self.text=(self.text or "").."\n"..text
  if self==GameTooltip then
    self.numLines=self:NumLines()+1
    local name="GameTooltipTextLeft"..self.numLines
    local line=_G[name]
    if not line then
      line=self:CreateFontString(name,"OVERLAY")
      line:SetFontObject(self.numLines==1 and GameTooltipHeaderText or GameTooltipText)
    end
    line:SetText(text);line:SetTextColor(...);line:Show()
  end
end
function methods:SetTextColor(...) self.color={...} end
for _,key in ipairs({"SetMovable","SetClampedToScreen","SetBackdrop","RegisterForDrag","EnableMouseWheel","SetJustifyH","SetJustifyV","StartMoving","StopMovingOrSizing"}) do methods[key]=function() end end
function methods:SetBackdropColor(...) self.backdropColor={...} end
function methods:SetBackdropBorderColor(...) self.backdropBorderColor={...} end
local function widget(kind,name,parent)
  local o=setmetatable({kind=kind,name=name,parent=parent,shown=true,scripts={},events={}}, {__index=function(_,k) if methods[k] then return methods[k] end end})
  if name then _G[name]=o end
  table.insert(widgets,o);return o
end
function methods:CreateTexture(name,layer) return widget("Texture",name,self) end
function methods:CreateFontString(name,layer) return widget("FontString",name,self) end
CreateFrame=widget
UIParent=widget("Frame","UIParent");UIParent:SetWidth(1440);UIParent:SetHeight(900)
WorldMapFrame=widget("Frame","WorldMapFrame",UIParent);WorldMapFrame:Hide()
WorldMapButton=widget("Button","WorldMapButton",WorldMapFrame);WorldMapButton:SetWidth(1002);WorldMapButton:SetHeight(668)
Minimap=widget("Minimap","Minimap",UIParent);Minimap:SetWidth(140);Minimap:SetHeight(140)
QuestWatchFrame=widget("Frame","QuestWatchFrame",UIParent)
QuestLogFrame=widget("Frame","QuestLogFrame",UIParent);QuestLogFrame:Hide()
QuestLogListScrollFrame=widget("Frame","QuestLogListScrollFrame",QuestLogFrame)
QuestLogListScrollFrameScrollBar=widget("Slider","QuestLogListScrollFrameScrollBar",QuestLogFrame)
ChatFrameEditBox=widget("EditBox","ChatFrameEditBox",UIParent);ChatFrameEditBox:Hide()
GameTooltip=widget("Frame","GameTooltip",UIParent)
GameTooltipHeaderText={}
GameTooltipText={}
WorldMapTooltip=widget("Frame","WorldMapTooltip",WorldMapFrame)
DEFAULT_CHAT_FRAME=widget("Frame",nil,UIParent)
SlashCmdList={}
STANDARD_TEXT_FONT="Fonts\\FRIZQT__.TTF"
local now=10
local shiftDown=false
function IsShiftKeyDown() return shiftDown end
function GetTime() return now end
local mouseoverName,mouseoverPlayer=nil,false
local npcName=nil
local playerLevel=12
function UnitLevel() return playerLevel end
function UnitName(unit) if unit=="mouseover" then return mouseoverName elseif unit=="npc" then return npcName end;return "Tester" end
function UnitIsPlayer(unit) return unit=="player" or (unit=="mouseover" and mouseoverPlayer) end
function getglobal(name) return _G[name] end
function UnitClass() return "Warrior","WARRIOR" end
function UnitRace() return "Orc","Orc" end
function UnitSex() return 2 end
local continent,zone=1,1
local playerZone="The Barrens"
function GetRealZoneText() return playerZone end
function GetZoneText() return playerZone end
function GetCurrentMapContinent() return continent end
function GetCurrentMapZone() return zone end
function GetMapZones(c) if c==1 then return "The Barrens","Durotar" else return "Elwynn Forest" end end
function GetMapContinents() return "Kalimdor","Eastern Kingdoms" end
function SetMapZoom(c,z) continent,zone=c,z end
function SetMapToCurrentZone()
  mapResets=mapResets+1
  if playerZone=="The Barrens" then continent,zone=1,1 elseif playerZone=="Durotar" then continent,zone=1,2 end
end
function ShowUIPanel(frame)
  frame:Show()
  if frame==QuestLogFrame then QuestLog_SetSelection(GetQuestLogSelection());QuestLog_Update() end
end
function HideUIPanel(frame) frame:Hide() end
function QuestWatch_Update() QuestWatchFrame:Show() end
local selection=1
local log={}
local function visible()
  local list={}
  for _,header in ipairs(log) do
    table.insert(list,header)
    if not header.closed then for _,quest in ipairs(header.quests) do table.insert(list,quest) end end
  end
  return list
end
function GetNumQuestLogEntries() return #visible() end
function GetQuestLogSelection() return selection end
function SelectQuestLogEntry(index) selection=index end
function QuestLog_SetSelection(index)
  assert(visible()[index] and not visible()[index].header,"quest log opened on a header or invalid entry")
  SelectQuestLogEntry(index);QuestLogFrame.selectedButtonID=index
end
function QuestLog_Update() QuestLogFrame.updateCount=(QuestLogFrame.updateCount or 0)+1 end
function GetQuestLogTitle(index)
  local q=visible()[index];if not q then return end
  return q.title,q.level,q.tag,q.header,q.closed,q.complete
end
function ExpandQuestHeader(index) visible()[index].closed=nil end
function CollapseQuestHeader(index) visible()[index].closed=true end
function GetQuestLogQuestText() local q=visible()[selection];return q.description or "",q.summary or "" end
function GetNumQuestLeaderBoards(index) return #(visible()[index].objectives or {}) end
function GetQuestLogLeaderBoard(i,index) local o=visible()[index].objectives[i];return o.text,o.kind,o.done end
function GetQuestLogRequiredMoney() return visible()[selection].money or 0 end
function GetMoney() return 100 end
function fire(name)
  event=name
  for _,w in ipairs(widgets) do if w.events[name] and w.scripts.OnEvent then this=w;w.scripts.OnEvent() end end
end
function tick(delta)
  now=now+delta;arg1=delta;this=QuestlineEvents;QuestlineEvents.scripts.OnUpdate()
end
function click(frame,button)
  button=button or "LeftButton"
  if button=="RightButton" then assert(frame.clicks and table.concat(frame.clicks,","):find("RightButtonUp"),"button has not registered right clicks") end
  this=frame;arg1=button;frame.scripts.OnClick()
end
local function quest(id,objectives,complete)
  local data=QuestlineDB.quests[id]
  return {id=id,title=data.title,level=data.level,summary=data.summary,description=data.description,objectives=objectives or {},complete=complete}
end

local function completionHistoryTests(Q)
  local original=Q.quests
  local history,sources=QuestlineSettings.completedQuests,QuestlineSettings.completionSources
  QuestlineSettings.completedQuests={};QuestlineSettings.completionSources={};Q:SetEntries({})
  for i=1,12 do QuestlineDB.quests[991000+i]={title="History quest "..i,level=1,minLevel=1,objectives={},prerequisites={},blockedBy={}} end
  expect(Q:SetQuestCompleted(991001,"Manual") and not Q:IsQuestAvailable(991001),"manual history suppresses available quests")
  expect(QuestlineSettings.completionSources[991001]=="Manual","manual source is saved separately from compatibility history")
  Q.npcOffers["test npc"]={time=GetTime(),quests={{title="History quest 1",level=1}}}
  expect(#Q:GetAvailableNPCQuests("Test NPC",{991001})==0,"observed offers cannot resurrect a hidden completed quest")
  Q:RestoreCompletedQuest(991001)
  expect(Q:IsQuestAvailable(991001) and not QuestlineSettings.completionSources[991001],"restoring removes history and metadata and allows eligibility")
  QuestlineDB.quests[991001].repeatable=true
  Q:SetQuestCompleted(991001,"Automatic");expect(Q:IsQuestAvailable(991001),"automatic completion retains repeatable offers")
  Q:SetQuestCompleted(991001,"Manual");expect(not Q:IsQuestAvailable(991001),"manual completion hides even repeatable offers until restored")
  local active={key="991002",id=991002,title="History quest 2",level=1,objectives={}}
  Q:SetEntries({active})
  expect(not Q:SetQuestCompleted(991002,"Manual"),"cannot manually mark a live quest completed")
  Q:ObserveQuestCompletion("History quest 2 completed.")
  expect(not QuestlineSettings.completedQuests[991002] and Q.pendingTurnIn and Q.pendingTurnIn.confirmed,"completion message before log removal creates a pending turn-in even without a reward snapshot")
  Q:SetEntries({})
  expect(QuestlineSettings.completionSources[991002]=="Automatic","confirmed completion records automatic provenance")
  Q:SetEntries({});Q:InitializeNPCQuests()
  expect(QuestlineSettings.completedQuests[991001] and QuestlineSettings.completionSources[991001]=="Manual","initialization preserves manual history")
  for i=3,12 do Q:SetQuestCompleted(991000+i,"Manual") end
  QuestlineSettings.completedQuests[991013]=true
  expect(#Q:GetCompletionList("991001",true)==1 and #Q:GetCompletionList("history quest",false)==12,"history supports ID/title search and manual filtering")
  expect(Q:GetCompletionList("991013",false)[1].source=="Existing","old completion records keep unknown provenance rather than invented sources")
  Q:Command("");local f=Q.optionsPanel
  expect(f.section=="general" and f.general:IsShown() and not f.history:IsShown() and not f.appearance:IsShown(),"slash menu opens the General sidebar section")
  expect(#f.navigation==3 and f.navigation[1].text:GetText()=="General" and f.navigation[2].text:GetText()=="Appearance" and f.navigation[3].text:GetText()=="Completed Quests","options pane has persistent category navigation")
  expect(f:GetWidth()==720 and f:GetHeight()==520 and f.serverImport:GetParent()==f.history and f.restoreAll:GetParent()==f.history,"options pane uses a fixed Blizzard-style two-column layout")
  expect(f.tracker:GetChecked() and f.mapTracker:GetChecked() and not f.spawns:GetChecked() and f.nameplateBadges:GetChecked(),"General feature states use checkboxes with nameplate badges enabled by default")
  click(f.navigation[2]);expect(f.section=="appearance" and f.appearance:IsShown() and f.navigation[2].selected:IsShown(),"Appearance category opens and highlights its sidebar row")
  Q:SetEntries(original);Q:Select(Q.tracker.rows[1].entry.key)
  expect(not f.bordered:GetChecked() and f.bordered.label:GetText()=="Bordered tracker","Appearance offers an unchecked bordered tracker option for transparent mode")
  click(f.bordered)
  expect(f.bordered:GetChecked() and not QuestlineSettings.transparentTracker,"checking bordered tracker enables the border")
  click(f.bordered)
  expect(QuestlineSettings.transparentTracker and Q.tracker.backdropColor[4]==0 and Q.tracker.backdropBorderColor[4]==0,"transparent mode removes the HUD tracker background and border")
  expect(Q.tracker.headerBar:IsShown() and not Q.tracker.rule:IsShown() and not Q.mapTracker.headerBar:IsShown(),"transparent HUD uses the gold-edged header strip without changing the map header")
  local detail=Q.tracker.rows[1].detail
  expect(detail.color[1]==1 and detail.color[2]==1 and detail.color[3]==1,"tracker detail text uses a pure white base")
  expect(detail.shadowColor[4]==1 and detail.shadowOffset[1]==1 and detail.shadowOffset[2]==-1 and Q.tracker.rows[1].title.shadowOffset[2]==-1,"tracker refresh preserves the black shadow one pixel right and down")
  expect(Q.mapTracker.backdropColor[4]==.9 and Q.mapTracker.backdropBorderColor[4]==.85,"world-map tracker remains bordered in transparent HUD mode")
  expect(not Q.tracker.rows[1].shade:IsShown() and Q.tracker.rows[1].glow:IsShown() and Q.tracker.rows[1].glow.alpha==.24 and Q.tracker.rows[1].badge.glow:IsShown(),"transparent mode gives the selected row a faint soft blue glow and keeps the selected badge")
  expect(Q.mapTracker.rows[1].shade:IsShown() and not Q.mapTracker.rows[1].glow:IsShown(),"world-map tracker retains its selected-row fill without the transparent HUD glow")
  click(f.bordered)
  expect(not QuestlineSettings.transparentTracker and Q.tracker.backdropColor[4]==.9 and Q.tracker.backdropBorderColor[4]==.85,"appearance toggle restores the bordered tracker style")
  expect(not Q.tracker.headerBar:IsShown() and Q.tracker.rule:IsShown(),"bordered mode restores the original header rule")
  local hud=QuestlineSettings.tracker
  expect(not f.legacy and f.mapTracker,"map tracker control replaces legacy pins in options")
  click(f.navigation[1])
  click(f.mapTracker)
  expect(QuestlineSettings.mapTracker==false and not Q.mapTracker:IsShown() and QuestlineSettings.tracker==hud,"map tracker toggle leaves HUD preference unchanged")
  Q:RefreshTrackers();Q:Command("reset")
  expect(not Q.mapTracker:IsShown(),"refresh and layout reset preserve hidden map tracker")
  click(f.mapTracker)
  expect(QuestlineSettings.mapTracker and Q.mapTracker:IsShown(),"options can restore map tracker")
  click(f.navigation[3])
  expect(f.section=="completed" and f.history:IsShown() and f.navigation[3].selected:IsShown(),"Completed Quests opens from the persistent sidebar")
  expect(f.restoreAll:GetText()=="Restore All" and f.restoreAll.point[4]+f.restoreAll:GetWidth()==328,"completed quests view has a Restore All action")
  expect(f.serverImport:GetWidth()==170 and f.serverImport.point[4]+f.serverImport:GetWidth()==506,"server import fits its label and remains aligned with Restore All")
  expect(f.filter.label.point[4]+f.filter.label:GetWidth()==506 and f.filter.label.point[5]==-59 and f.search.point[4]==120 and f.search:GetWidth()==190,"completed filter is vertically aligned and the compact search field shares the available header width")
  QuestlineDB.quests[991014]={title="Imported test quest",level=1,minLevel=1,objectives={},prerequisites={},blockedBy={}}
  local oldSend,sends=SendChatMessage,0
  SendChatMessage=function(message,channel)
    sends=sends+1
    expect(message==".queststatus" and channel=="GUILD","server import uses Octo's quest history request")
  end
  click(f.serverImport)
  expect(sends==1 and f.serverImport.mouseEnabled==false and not Q:BeginServerQuestHistoryImport(),"server import link cannot send another request while busy")
  arg1="TWQUEST";arg2="991001 991014 999999";fire("CHAT_MSG_ADDON")
  now=now+3.1;this=Q.serverQuestHistoryQuery;Q.serverQuestHistoryQuery.scripts.OnUpdate()
  expect(QuestlineSettings.completedQuests[991014] and QuestlineSettings.completionSources[991014]=="Server" and QuestlineSettings.completionSources[991001]=="Server","server result confirms known quests and upgrades existing completion provenance")
  expect(f.serverImport.mouseEnabled and f.serverImport.alpha==1 and string.find(DEFAULT_CHAT_FRAME:GetText(),"1 quest marked as completed",1,true),"completed import restores the native action button and reports only newly added quests")
  expect(#Q:GetCompletionList("Imported test quest",false)==1 and f.serverImport:GetText()=="Import from Server","completed list updates without changing the import action label")
  click(f.serverImport);arg1="TWQUEST";arg2="991001 991014";fire("CHAT_MSG_ADDON")
  now=now+3.1;this=Q.serverQuestHistoryQuery;Q.serverQuestHistoryQuery.scripts.OnUpdate()
  expect(string.find(DEFAULT_CHAT_FRAME:GetText(),"Completed quests are up to date",1,true),"repeated server import reports no new completions")
  Q:RestoreCompletedQuest(991014)
  click(f.serverImport);arg1="TWQUEST";arg2="991001 991014";fire("CHAT_MSG_ADDON")
  now=now+3.1;this=Q.serverQuestHistoryQuery;Q.serverQuestHistoryQuery.scripts.OnUpdate()
  expect(QuestlineSettings.completedQuests[991014] and string.find(DEFAULT_CHAT_FRAME:GetText(),"1 quest marked as completed",1,true),"restored quests can be marked completed again by the server")
  SendChatMessage=oldSend
  expect(f and f:IsShown() and f.pages==2,"bare slash command opens paginated options/history panel")
  f.page=2;Q:RefreshOptions();expect(f.rows[1]:IsShown(),"later history page is reachable")
  local display=f.rows[1]
  expect(#f.rows==12 and display:GetHeight()==22 and not display.source,"completed quests use compact rows without visible source labels")
  expect(display.title:GetText()==Q:QuestTitle({title=display.fullTitle,level=QuestlineDB.quests[display.id].level}) and display.title.color[1]==1 and display.title.color[2]==.82,"completed quest title uses tracker level coloring and gold text")
  this=display.restore;display.restore.scripts.OnEnter()
  expect(display.hover:IsShown(),"hovering Restore highlights its entire quest row")
  this=display.restore;display.restore.scripts.OnLeave()
  expect(not display.hover:IsShown(),"completed quest highlight clears after leaving Restore")
  Q:SetQuestCompleted(991001,"Manual")
  click(f.filter);expect(f.manualOnly and f.page==1,"manual-only filter resets history page")
  f.search:SetText("991001");this=f.search;f.search.scripts.OnTextChanged()
  expect(f.rows[1].id==991001 and not f.rows[2]:IsShown(),"search narrows the displayed completion records")
  click(f.rows[1].restore);expect(not f.rows[1]:IsShown(),"restore button refreshes the open list immediately")
  expect(not Q:GetGiverPin(1,true).scripts.OnClick,"minimap markers have no completion click action")
  local pin=Q:GetGiverPin(1,false)
  for _,other in ipairs(Q.mapGivers) do other:Hide() end
  pin.giver={id=991101,name="Test NPC",quests={{id=991001,title="History quest 1"},{title="Ambiguous offer"}},points={}}
  pin.giverX=0;pin.giverY=0;pin:Show()
  click(pin,"RightButton")
  expect(Q.completionMenu:IsShown() and #Q.completionMenu.items==1,"right-click offers only uniquely identified available quests")
  Q:ShowCompletionMenu(pin,false)
  expect(Q.completionMenu:GetParent()==WorldMapFrame and Q.completionMenu:GetFrameLevel()==WorldMapFrame:GetFrameLevel()+60,"map context pane is elevated above map artwork like tracker")
  local menu=Q.completionMenu
  expect(menu:GetHeight()<100 and not menu.count:IsShown() and not menu.next:IsShown(),"one-quest menu is compact without page controls")
  expect(menu.rows[1].text:GetText()=="History quest 1","context rows contain only quest names")
  expect(menu.close:GetFrameLevel()>menu:GetFrameLevel() and menu.dismiss:GetFrameLevel()<menu:GetFrameLevel(),"close and menu controls stay above outside-click layer")
  this=menu.dismiss;menu.dismiss.scripts.OnMouseDown()
  expect(not menu:IsShown() and not menu.dismiss:IsShown(),"clicking outside closes menu and removes click catcher")
  Q:ShowCompletionMenu(pin,false);click(menu.close)
  expect(not menu:IsShown() and not menu.dismiss:IsShown(),"close button also dismisses menu and click catcher")
  Q:ShowCompletionMenu(pin,false)
  click(Q.completionMenu.rows[1])
  expect(not Q.completionMenu:IsShown() and QuestlineSettings.completionSources[991001]=="Manual","context action records manual completion and closes menu")
  f.search:SetText("");f.manualOnly=nil;Q:RefreshOptions()
  click(f.restoreAll)
  expect(next(QuestlineSettings.completedQuests)==nil and next(QuestlineSettings.completionSources)==nil,"Restore All clears every completion record and its provenance")
  expect(not f.rows[1]:IsShown() and string.find(DEFAULT_CHAT_FRAME:GetText(),"14 quests restored",1,true),"Restore All refreshes the list and reports how many quests were restored")
  Q:Command("");expect(not f:IsShown(),"slash command toggles options closed")
  f.search:SetText("");f.manualOnly=nil
  QuestlineSettings.completedQuests=history;QuestlineSettings.completionSources=sources
  for i=1,12 do QuestlineDB.quests[991000+i]=nil end
  QuestlineDB.quests[991014]=nil
  Q:SetEntries(original);Q.npcOffers={};Q:InvalidateQuestAvailability()
end

local function vendorMapTooltipTests(Q)
  local original,oldMapZone,spawns=Q.quests,Q.GetMapZone,QuestlineSettings.worldMapSpawns
  local oldScale=WorldMapButton.scale
  local data=QuestlineDB.quests[375]
  local entry={key="375",id=375,title=data.title,level=data.level,data=data,objectives={
    {text="Duskbat Pelt: 5/5",kind="item",done=true},{text="Coarse Thread: 0/1",kind="item",done=false}}}
  Q.GetMapZone=function() return 85 end
  QuestlineSettings.worldMapSpawns=true
  WorldMapFrame:Show();WorldMapButton.scale=2
  Q:SetEntries({entry});Q:Select(entry.key);Q:RefreshMap()
  local pin,spawn
  for _,p in ipairs(Q.objectivePins) do if p:IsShown() and p.sourceName=="Abigail Shiel" then pin=p end end
  for _,p in ipairs(Q.mapSpawns) do if p:IsShown() and p.spawn.sourceName=="Abigail Shiel" then spawn=p end end
  expect(pin and spawn,"real Coarse Thread vendor identity reaches both precise and spawn pins")
  expect(pin:GetWidth()==7 and spawn:GetWidth()==6 and pin.texture.textureValue[1]=="Interface\\GossipFrame\\VendorGossipIcon","native bag markers use smaller sizes while compensating for map zoom")
  this=pin;pin.scripts.OnEnter()
  local text=WorldMapTooltip:GetText()
  expect(string.sub(text,1,14)=="Abigail Shiel\n" and string.find(text,Q:QuestTitle(entry),1,true)>14,"vendor map tooltip starts with the NPC name before the quest title")
  expect(not string.find(text,"Duskbat Pelt",1,true) and string.find(text,"Coarse Thread: 0/1",1,true),"vendor tooltip shows only the supplied item, matched by name rather than objective position")
  expect(Q.partyQuestTooltip.sourceName=="Abigail Shiel","party tooltip refresh retains the hovered vendor identity")
  this=spawn;spawn.scripts.OnEnter()
  expect(string.sub(WorldMapTooltip:GetText(),1,14)=="Abigail Shiel\n","vendor spawn tooltip also starts with the source NPC")
  expect(not string.find(WorldMapTooltip:GetText(),"Duskbat Pelt",1,true) and string.find(WorldMapTooltip:GetText(),"Coarse Thread: 0/1",1,true),"vendor spawn tooltip also filters unrelated objectives")
  Q:ShowQuestTooltip(pin,entry,pin.target)
  expect(string.find(WorldMapTooltip:GetText(),Q:QuestTitle(entry),1,true)==1,"markers without source metadata retain the quest-first fallback")
  expect(string.find(WorldMapTooltip:GetText(),"Duskbat Pelt: 5/5",1,true),"full quest tooltips retain all objectives")
  WorldMapTooltip:Hide();Q.partyQuestTooltip=nil
  Q.GetMapZone=oldMapZone;WorldMapButton.scale=oldScale;QuestlineSettings.worldMapSpawns=spawns
  Q.spawnCache=nil;Q:SetEntries(original);Q.mapDirty=true;Q:RefreshMap()
end

local function sourceMapTooltipTests(Q)
  local original,oldMapZone,spawns=Q.quests,Q.GetMapZone,QuestlineSettings.worldMapSpawns
  local data=QuestlineDB.quests[408]
  local entry={key="408",id=408,title=data.title,level=data.level,data=data,objectives={
    {text="Wailing Ancestor slain: 0/8",kind="monster",done=false},
    {text="Rotting Ancestor slain: 0/8",kind="monster",done=false},
    {text="Dargol's Skull: 0/1",kind="item",done=false}}}
  Q.GetMapZone=function() return 85 end;QuestlineSettings.worldMapSpawns=true
  WorldMapFrame:Show();Q:SetEntries({entry});Q:Select(entry.key);Q:RefreshMap()
  local pin,spawn,ancestor
  for _,p in ipairs(Q.objectivePins) do if p:IsShown() and p.sourceName=="Captain Dargol" then pin=p end end
  for _,p in ipairs(Q.mapSpawns) do if p:IsShown() then
    if p.spawn.sourceName=="Captain Dargol" then spawn=p end
    if p.spawn.sourceName=="Wailing Ancestor" then ancestor=p end
  end end
  expect(pin and spawn and ancestor,"real drop and kill sources retain NPC identities on precise and spawn markers")
  this=pin;pin.scripts.OnEnter();local text=WorldMapTooltip:GetText()
  expect(string.find(text,"Captain Dargol\n",1,true)==1 and string.find(text,Q:QuestTitle(entry),1,true),"Dargol's Skull marker shows its recorded drop NPC before the quest")
  expect(string.find(text,"Dargol's Skull: 0/1",1,true) and not string.find(text,"Ancestor",1,true),"skull tooltip shows only the related item despite reordered quest-log objectives")
  this=spawn;spawn.scripts.OnEnter()
  expect(string.find(WorldMapTooltip:GetText(),"Captain Dargol\n",1,true)==1 and not string.find(WorldMapTooltip:GetText(),"Ancestor",1,true),"drop spawn tooltip applies the same source-first objective filtering")
  this=ancestor;ancestor.scripts.OnEnter();text=WorldMapTooltip:GetText()
  expect(string.find(text,"Wailing Ancestor\n",1,true)==1 and string.find(text,"Wailing Ancestor slain: 0/8",1,true) and not string.find(text,"Rotting Ancestor",1,true) and not string.find(text,"Dargol's Skull",1,true),"kill-source tooltips also keep only their matching live objective")
  Q:ShowQuestTooltip(Q.tracker.rows[1],entry)
  text=WorldMapTooltip:GetText()
  expect(string.find(text,"Dargol's Skull: 0/1",1,true) and string.find(text,"Rotting Ancestor slain: 0/8",1,true),"tracker tooltip still provides the full quest overview")
  local source={kind="item",name="Unknown-source item",key="unknown-source-item"}
  entry.objectives={{text="Different live text: 0/1",kind="item",done=false}}
  Q:ShowQuestTooltip(pin,entry,source,"Recorded NPC")
  expect(string.find(WorldMapTooltip:GetText(),source.name,1,true) and not string.find(WorldMapTooltip:GetText(),"Different live text",1,true),"unmatched source objectives show their known name without guessing counters or including unrelated progress")
  WorldMapTooltip:Hide();Q.partyQuestTooltip=nil
  Q.GetMapZone=oldMapZone;QuestlineSettings.worldMapSpawns=spawns
  Q.spawnCache=nil;Q:SetEntries(original);Q.mapDirty=true;Q:RefreshMap()
end

local function craftingHintTests(Q)
  local original,mode=Q.quests,QuestlineSettings.trackerMode
  local data=QuestlineDB.quests[60140]
  local entry={key="60140",id=60140,title=data.title,level=data.level,summary="",data=data,
    objectives={{text="Linen Bandage: 0/10",kind="item",done=false}}}
  local hint="Craft with First Aid or obtain from another player"
  expect(not Q:HasLocations(entry) and Q:MissingLocationHint(entry)==hint,"real Linen Bandage quest derives its crafting hint from the imported quest summary")
  Q:SetEntries({entry});Q:SetTrackerMode("world")
  local detail=Q.tracker.rows[1].detail:GetText()
  expect(string.find(detail,"Linen Bandage: 0/10",1,true) and string.find(detail,hint,1,true) and not string.find(detail,"No known map location",1,true),"tracker keeps live bandage progress and replaces the missing-location warning with crafting guidance")
  local mapShown=WorldMapFrame:IsShown();WorldMapFrame:Hide()
  Q:ShowQuestTooltip(Q.tracker.rows[1],entry)
  expect(string.find(GameTooltip:GetText(),hint,1,true),"quest tooltip uses the same crafting guidance")
  Q:TrackerDoubleClick(entry,"LeftButton")
  expect(string.find(DEFAULT_CHAT_FRAME:GetText(),hint,1,true) and not WorldMapFrame:IsShown(),"double-clicking a crafting objective explains how to obtain it without opening an unrelated map")
  entry.complete=true
  expect(Q:HasLocations(entry) and Q:MissingLocationHint(entry)==nil,"completed crafting quests map their real finisher instead of retaining the crafting hint")
  entry.complete=nil
  entry.data={summary="",objectives=data.objectives,finishers=data.finishers}
  expect(Q:MissingLocationHint(entry)=="No known map location for this objective","missing item sources alone never imply a crafting requirement")
  entry.summary=data.summary
  expect(Q:MissingLocationHint(entry)==hint,"live quest summary can also provide an explicit crafting instruction")
  entry.data={summary=data.summary,objectives={{kind="unit",key="unit:unmapped",name="Unmapped creature"}},finishers={}}
  expect(Q:MissingLocationHint(entry)=="No known map location for this objective","crafting text does not relabel a non-item objective")
  entry.complete=true
  expect(Q:MissingLocationHint(entry)=="No known map location for the turn-in","unmapped completed quests report the missing turn-in rather than a crafting instruction")
  entry.failed=true
  expect(Q:MissingLocationHint(entry)==nil,"failed quests do not display acquisition guidance")
  GameTooltip:Hide();Q.partyQuestTooltip=nil
  if mapShown then WorldMapFrame:Show() end
  Q:SetEntries(original);Q:SetTrackerMode(mode)
end

local function requestedBehaviorTests(Q)
  local original=Q.quests
  local first={kind="unit",id=990001,key="unit:990001",name="First Mob",icon="kill"}
  local second={kind="unit",id=990002,key="unit:990002",name="Second Mob",icon="kill"}
  local finisher={kind="unit",id=990003,key="turnin:unit:990003",name="Helpful NPC",icon="turnin"}
  local active={key="requested-active",id=990010,title="Requested behavior",level=5,number=1,objectives={{text="First Mob: 1/1",done=true},{text="Second Mob: 0/1",done=false}},data={objectives={first,second},finishers={finisher}}}
  expect(#Q:Targets(active)==1 and Q:Targets(active)[1].key==second.key,"completed mob objectives are removed from the remaining map area")

  local complete={key="requested-complete",id=990011,title="Completed context",level=5,complete=true,objectives={{text="Keep this objective context",done=true}},data={objectives={first},finishers={finisher}}}
  local talk={key="requested-talk",id=990012,title="A Conversation",level=5,complete=true,objectives={},data={objectives={},finishers={finisher}}}
  Q:SetEntries({complete,talk,active});Q:SetTrackerMode("world")
  local completeText,talkText
  for _,row in ipairs(Q.tracker.rows) do if row:IsShown() and row.entry then
    if row.entry.key==active.key then expect(string.find(row.detail:GetText(),"|cffffffff- Second Mob: 0/1|r",1,true),"unfinished tracker objectives use pure white") end
    if row.entry.key==complete.key then completeText=row.detail:GetText() end
    if row.entry.key==talk.key then talkText=row.detail:GetText() end
  end end
  expect(completeText and string.find(completeText,"Keep this objective context",1,true) and not string.find(completeText,"Ready for turn-in",1,true),"completed tracker rows retain their green objective context")
  expect(talkText and string.find(talkText,"Speak with Helpful NPC",1,true),"talk-only quests name their destination NPC")

  QuestlineDB.mobObjectives[Q:Normalize(second.name)]={second.key}
  local plate=CreateFrame("Frame",nil,UIParent);plate.health=CreateFrame("Frame",nil,plate)
  plate.original={name=plate:CreateFontString(nil,"OVERLAY")};plate.original.name:SetText(second.name)
  QuestlineSettings.selected=active.key;QuestlineSettings.selectedKeys=nil
  local savedGuda=GudaPlates
  local native=CreateFrame("Frame",nil,UIParent);native:Show();plate:Show()
  GudaPlates={registry={[native]=plate}}
  local function nameplateFrame()
    this=QuestlineNameplateUpdater;arg1=1/120;this.scripts.OnUpdate()
  end
  nameplateFrame()
  expect(plate.questlineBadges and plate.questlineBadges[1]:IsShown() and plate.questlineBadges[1].text:GetText()==tostring(active.number),"relevant GudaPlates mobs receive the quest number badge")
  expect(plate.questlineBadges[1].glow:IsShown(),"the selected tracker quest highlights its nameplate badge")
  local locationKey=second.key
  local oldLocation=QuestlineDB.locations[locationKey]
  QuestlineDB.locations[locationKey]={[Q:GetPlayerZone()]={anchor={50,50},runs="",points={}}}
  Q:SetTrackerMode("zone");Q:PaintNameplate(plate)
  expect(plate.questlineBadges[1].text:GetText()=="1" and Q.tracker.rows[1].badge.text:GetText()=="1","nameplate badges match the physical Zone tracker after skipping full-log turn-ins")
  Q:SetTrackerMode("world");Q:PaintNameplate(plate)
  expect(plate.questlineBadges[1].text:GetText()=="1" and active.number==1,"World nameplate numbering also skips completed quests")
  QuestlineDB.locations[locationKey]=oldLocation
  click(Q.optionsPanel.nameplateBadges)
  expect(QuestlineSettings.nameplateBadges==false and not Q.optionsPanel.nameplateBadges:GetChecked() and not plate.questlineBadges[1]:IsShown(),"disabling nameplate badges immediately hides existing badges and updates the checkbox")
  nameplateFrame();Q:PaintNameplate(plate)
  expect(not plate.questlineBadges[1]:IsShown(),"disabled badges stay hidden during frame updates and direct paints")
  local unpainted=CreateFrame("Frame",nil,UIParent)
  Q:PaintNameplate(unpainted)
  expect(not unpainted.questlineBadges,"disabled badges are not allocated for new plates")
  click(Q.optionsPanel.nameplateBadges)
  expect(QuestlineSettings.nameplateBadges==true and Q.optionsPanel.nameplateBadges:GetChecked() and plate.questlineBadges[1]:IsShown(),"enabling nameplate badges immediately restores visible plates")
  plate.original.name:SetText("Unrelated creature");nameplateFrame()
  expect(not plate.questlineBadges[1]:IsShown(),"reused nameplates remove stale badges on the first frame after a name change")
  plate.original.name:SetText(second.name);nameplateFrame()
  expect(plate.questlineBadges[1]:IsShown(),"a newly populated name gets its badge without waiting for the progress timer")
  native:Hide();nameplateFrame()
  expect(not plate.questlineBadges[1]:IsShown(),"hidden native plates immediately clear their badge state")
  native:Show();nameplateFrame()
  expect(plate.questlineBadges[1]:IsShown(),"a returning plate restores its badge on the first visible frame")
  active.objectives[2].done=true;Q:PaintNameplate(plate)
  expect(not plate.questlineBadges[1]:IsShown(),"finishing a mob objective removes its nameplate badge")
  GudaPlates=savedGuda
  QuestlineDB.mobObjectives[Q:Normalize(second.name)]=nil
  Q:SetEntries(original)
end

local function blizzardNameplateTests(Q)
  local original,savedGuda,savedWorld=Q.quests,GudaPlates,WorldFrame
  local savedSetting=QuestlineSettings.nameplateBadges
  local savedSelected,savedKeys=QuestlineSettings.selected,QuestlineSettings.selectedKeys
  local target={kind="unit",id=992030,key="unit:992030",name="Native Quest Mob",icon="kill"}
  local active={key="native-plate-quest",title="Native plate quest",level=5,
    objectives={{text="Native Quest Mob: 0/1",done=false}},data={objectives={target},finishers={}}}
  local key=Q:Normalize(target.name);local oldIndex=QuestlineDB.mobObjectives[key]
  QuestlineDB.mobObjectives[key]={target.key}
  Q:SetEntries({active});QuestlineSettings.selected=active.key;QuestlineSettings.selectedKeys=nil
  QuestlineSettings.nameplateBadges=true;GudaPlates=nil
  local world=CreateFrame("Frame",nil,UIParent);WorldFrame=world
  local children,scans={},0
  world.GetNumChildren=function() return #children end
  world.GetChildren=function() scans=scans+1;return unpack(children) end
  local function nativePlate(name)
    local frame=CreateFrame("Button",nil,world)
    local border=frame:CreateTexture(nil,"ARTWORK");border:SetTexture("Interface\\Tooltips\\Nameplate-Border")
    local glow=frame:CreateTexture(nil,"ARTWORK")
    local title=frame:CreateFontString(nil,"OVERLAY");title:SetText(name)
    local level=frame:CreateFontString(nil,"OVERLAY");level:SetText("5")
    local skull=frame:CreateTexture(nil,"ARTWORK")
    local raid=frame:CreateTexture(nil,"ARTWORK")
    local health=CreateFrame("StatusBar",nil,frame)
    frame.GetRegions=function() return border,glow,title,level,skull,raid end
    frame.GetChildren=function() return health end
    return frame,title,health,border
  end
  local plate,name,health=nativePlate(target.name)
  local unrelated=nativePlate("Unrelated Creature")
  local impostor,_,_,border=nativePlate(target.name);border:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
  local onShow,onUpdate,onClick=function() end,function() end,function() end
  plate:SetScript("OnShow",onShow);plate:SetScript("OnUpdate",onUpdate);plate:SetScript("OnClick",onClick)
  children={plate,unrelated,impostor};Q:RefreshNameplates(true)
  local badge=plate.questlineBadges and plate.questlineBadges[1]
  expect(badge and badge:IsShown() and badge.text:GetText()==tostring(active.number),"default Blizzard plates discover matching quest mobs without GudaPlates")
  expect(badge.glow:IsShown() and badge.parent==plate and badge.mouseEnabled==false,"native badge inherits plate visibility and preserves target clicks")
  expect(badge.point[2]==health and badge.point[4]==24,"native badge anchors beside the health bar with space for level and skull")
  expect(not unrelated.questlineBadges[1] and not impostor.questlineBadges,"unrelated mobs and non-nameplate WorldFrame children get no badges")
  expect(plate:GetScript("OnShow")==onShow and plate:GetScript("OnUpdate")==onUpdate and plate:GetScript("OnClick")==onClick and name:GetText()==target.name,"native discovery preserves Blizzard scripts and name text")
  local before=scans;Q:RefreshNameplates(true)
  expect(scans==before,"unchanged WorldFrame child count avoids full discovery on every frame")
  name:SetText("Unrelated Creature");Q:RefreshNameplates(true)
  expect(not badge:IsShown(),"native plate name reuse clears stale badges immediately")
  name:SetText(target.name);Q:RefreshNameplates(true)
  expect(badge:IsShown(),"reused native quest mob restores its badge immediately")
  plate:Hide();Q:RefreshNameplates(true)
  expect(not badge:IsShown() and not plate.questlineVisible,"hidden native plate clears badge reuse state")
  plate:Show();Q:RefreshNameplates(true)
  expect(badge:IsShown(),"returning native plate restores badges on its first visible frame")
  QuestlineSettings.selected=nil;Q:RefreshNameplates(false)
  expect(not badge.glow:IsShown(),"native selected-quest highlight follows the periodic repaint")
  active.objectives[1].done=true;Q:RefreshNameplates(false)
  expect(not badge:IsShown(),"finished objective removes its native nameplate badge")
  active.objectives[1].done=false;Q:RefreshNameplates(false)
  QuestlineSettings.nameplateBadges=false;Q:RefreshNameplates()
  expect(not badge:IsShown(),"nameplate option immediately hides Blizzard badges")
  QuestlineSettings.nameplateBadges=true;Q:RefreshNameplates()
  expect(badge:IsShown(),"nameplate option restores Blizzard badges")
  local fresh=nativePlate(target.name);table.insert(children,fresh);Q:RefreshNameplates(true)
  expect(fresh.questlineBadges[1]:IsShown(),"new WorldFrame child discovers its native badge immediately")
  local replacement=nativePlate(target.name);children[4]=replacement;Q:RefreshNameplates(false)
  expect(replacement.questlineBadges[1]:IsShown() and not fresh.questlineBadges[1]:IsShown(),"periodic scan handles same-count replacement and retires removed plate badges")
  local late,lateName,_,lateBorder=nativePlate("");lateBorder:SetTexture(nil)
  table.insert(children,late);Q:RefreshNameplates(true)
  expect(not late.questlineBadges,"uninitialized native regions are deferred")
  lateBorder:SetTexture("Interface\\Tooltips\\Nameplate-Border");Q:RefreshNameplates(false)
  expect(late.questlineBadges and not late.questlineBadges[1],"periodic discovery retains an initialized plate with an empty name")
  lateName:SetText(target.name);Q:RefreshNameplates(true)
  expect(late.questlineBadges[1]:IsShown(),"late native name population paints on the first frame")
  local guda=CreateFrame("Frame",nil,plate);guda.health=CreateFrame("StatusBar",nil,guda)
  guda.original={name=name};GudaPlates={registry={[plate]=guda}};Q:RefreshNameplates(true)
  expect(not badge:IsShown() and not replacement.questlineBadges[1]:IsShown() and guda.questlineBadges[1]:IsShown(),"GudaPlates backend hides native badge sets before painting its own")
  expect(guda.questlineBadges[1].point[2]==guda.health and guda.questlineBadges[1].point[4]==5,"GudaPlates keeps its existing badge placement")
  GudaPlates=nil;Q:RefreshNameplates(true)
  expect(badge:IsShown() and not guda.questlineBadges[1]:IsShown(),"returning to native plates hides the GudaPlates badge set")
  -- pfUI can finish constructing its replacement after native discovery,
  -- and hides/blanks the original artwork rather than moving the native bar.
  local pf=CreateFrame("Button",nil,plate)
  pf.original={name=name,healthbar=health,level=plate:CreateFontString(nil,"OVERLAY")}
  pf.health=CreateFrame("StatusBar",nil,pf)
  pf.health:SetWidth(180);pf.health:SetPoint("BOTTOM",pf,"BOTTOM",0,-20)
  plate.nameplate=pf
  local nativeBorder=plate:GetRegions();nativeBorder:SetTexture(nil)
  Q:RefreshNameplates(false)
  local pfBadge=pf.questlineBadges and pf.questlineBadges[1]
  expect(pfBadge and pfBadge:IsShown() and not badge:IsShown(),"late pfUI overlay replaces native badges even with a blank native border")
  expect(pfBadge.parent==pf and pfBadge.point[1]=="LEFT" and pfBadge.point[2]==pf.health and pfBadge.point[3]=="RIGHT" and pfBadge.point[4]==5 and pfBadge.point[5]==0,"pfUI badge inherits overlay scaling and anchors beside the visible health bar")
  pf.health:SetWidth(250);Q:RefreshNameplates(false)
  expect(pfBadge.point[2]==pf.health and pfBadge.point[4]==5,"pfUI target zoom keeps badges attached to the visible bar")
  local extra={key="pf-extra",title="Second plate quest",level=6,
    objectives={{text="Native Quest Mob: 0/1",done=false}},data={objectives={target},finishers={}}}
  Q:SetEntries({active,extra});Q:RefreshNameplates(false)
  expect(pf.questlineBadges[2]:IsShown() and pf.questlineBadges[2].point[2]==pfBadge and pf.questlineBadges[2].point[4]==2,"multiple pfUI badges extend neatly to the right")
  Q:SetEntries({active});Q:RefreshNameplates(false)
  expect(not pf.questlineBadges[2]:IsShown(),"pfUI hides surplus badges when a quest is removed")
  pf:Hide();Q:RefreshNameplates(true)
  expect(not pfBadge:IsShown() and not pf.questlineVisible,"hidden pfUI overlay clears its badge state while the native parent stays visible")
  pf:Show();Q:RefreshNameplates(true)
  expect(pfBadge:IsShown(),"pfUI overlay shows badges immediately on reuse")
  name:SetText("Unrelated Creature");Q:RefreshNameplates(true)
  expect(not pfBadge:IsShown(),"pfUI reads the original name to remove stale badges on reuse")
  name:SetText(target.name);Q:RefreshNameplates(true)
  GudaPlates={registry={[plate]=guda}};Q:RefreshNameplates(true)
  expect(not pfBadge:IsShown() and guda.questlineBadges[1]:IsShown() and guda.questlineBadges[1].point[4]==5,"switching from pfUI to GudaPlates preserves Guda placement and hides pfUI badges")
  GudaPlates=nil;Q:RefreshNameplates(true)
  expect(pfBadge:IsShown() and not guda.questlineBadges[1]:IsShown(),"returning from GudaPlates restores only pfUI badges")
  children={};Q:RefreshNameplates(false);world:Hide()
  expect(not pfBadge:IsShown(),"removing a pfUI native parent retires its overlay badges")
  WorldFrame=savedWorld;GudaPlates=savedGuda;QuestlineSettings.nameplateBadges=savedSetting
  QuestlineSettings.selected=savedSelected;QuestlineSettings.selectedKeys=savedKeys
  QuestlineDB.mobObjectives[key]=oldIndex;Q:SetEntries(original)
end

local function vendorTooltipTests(Q)
  local original=Q.quests
  local target={kind="item",id=990020,key="item:990020",name="Test Thread",icon="buy"}
  local entry={key="vendor-tooltip",id=990021,title="Shopping Test",level=8,objectives={{text="Test Thread: 0/1",kind="item",done=false}},data={objectives={target},finishers={}}}
  QuestlineDB.vendorObjectives["test supplier"]={target.key}
  Q:SetEntries({entry})
  mouseoverName="Test Supplier";mouseoverPlayer=false
  GameTooltip:SetOwner(UIParent,"ANCHOR_NONE");GameTooltip:SetText(mouseoverName);GameTooltip:AddLine("Trade Supplies");GameTooltip:Show();Q:RefreshMobTooltip()
  expect(GameTooltipTextLeft3:GetText()==Q:QuestTitle(entry),"vendor tooltip uses the tracker's colored level and quest title")
  expect(GameTooltipTextLeft4:GetText()=="  Test Thread - 0/1","vendor tooltip identifies the sold quest item and live progress")
  local lines=GameTooltip:NumLines();Q:RefreshMobTooltip()
  expect(GameTooltip:NumLines()==lines,"vendor tooltip details do not duplicate while hovering")
  QuestlineDB.vendorObjectives["test supplier"]=nil;mouseoverName=nil;GameTooltip:Hide();Q:SetEntries(original)
end
local function availabilityRegressionTests(Q)
  local original=Q.quests
  local history,sources=QuestlineSettings.completedQuests,QuestlineSettings.completionSources
  QuestlineSettings.completedQuests={};QuestlineSettings.completionSources={};Q:SetEntries({})
  expect(not Q:IsQuestAvailable(3096),"real Encrypted Scroll rogue quest is unavailable to warrior")
  Q.npcOffers["class npc"]={time=GetTime(),quests={{title=QuestlineDB.quests[3096].title,level=1}}}
  expect(#Q:GetAvailableNPCQuests("Class NPC",{3096})==0,"observed NPC offers cannot bypass class gate")
  local oldClass=UnitClass
  UnitClass=function() return "Unknown" end
  expect(not Q:MeetsQuestRestrictions({classMask=8}),"unknown class cannot silently permit class-restricted quests")
  UnitClass=oldClass
  local a,b=992001,992002
  for _,id in ipairs({a,b}) do QuestlineDB.quests[id]={title="Shared chain title",level=1,minLevel=1,classMask=1,raceMask=0,objectives={},finishers={},summary="step "..id,description="step "..id} end
  local first={id=a,key=tostring(a),title="Shared chain title",level=1,complete=true,objectives={},data=QuestlineDB.quests[a]}
  local second={id=b,key=tostring(b),title="Shared chain title",level=1,objectives={},data=QuestlineDB.quests[b]}
  local oldLink,oldLegacy=GetQuestLinkForLogIndex,GetQuestLink
  GetQuestLinkForLogIndex=function() return "|Hquest:"..a..":1|h[Shared chain title]|h" end
  GetQuestLink=function() return "|Hquest:"..b..":1|h[Shared chain title]|h" end
  expect(Q:ResolveQuest(1,first.title,1,"","")==a,"explicit log-index API identifies correct same-title chain step")
  GetQuestLinkForLogIndex=oldLink;GetQuestLink=oldLegacy
  local reward,title,abandon=GetQuestReward,GetTitleText,AbandonQuest
  local rewardHook,abandonHook=Q.rewardHooked,Q.abandonHooked
  GetTitleText=function() return first.title end
  GetQuestReward=function(choice) expect(choice==1,"reward hook preserves selection argument") end
  AbandonQuest=function() end
  Q.rewardHooked=nil;Q.abandonHooked=nil;Q:InitializeNPCQuests();Q:SetEntries({first})
  local scan=Q.ScanLog;Q.ScanLog=function() end
  fire("QUEST_COMPLETE")
  expect(not QuestlineSettings.completedQuests[a],"opening reward dialogue alone never records completion")
  GetQuestReward(1)
  Q:ObserveQuestCompletion("Shared chain title completed.")
  expect(not QuestlineSettings.completedQuests[a] and Q.pendingTurnIn and Q.pendingTurnIn.confirmed,
    "completion message waits for quest-log removal instead of racing live-state repair")
  Q:SetEntries({first})
  expect(not QuestlineSettings.completedQuests[a] and Q.pendingTurnIn,
    "intermediate quest-log scan retains the confirmed pending turn-in")
  QuestlineSettings.completedQuests[b]=true
  Q:SetEntries({second})
  expect(QuestlineSettings.completedQuests[a] and QuestlineSettings.completionSources[a]=="Automatic","reward and log removal record the old chain step")
  expect(not QuestlineSettings.completedQuests[b],"active one-time successor repairs contradictory old Existing record")
  Q:ObserveQuestCompletion("Shared chain title completed.")
  expect(not QuestlineSettings.completedQuests[b],"delayed same-title message cannot complete the successor")
  expect(Q:GetCompletionList(tostring(a),false)[1].source=="Completed","automatic history is displayed as Completed")
  Q:RestoreCompletedQuest(a);Q:SetEntries({first});GetQuestReward(1);AbandonQuest();Q:SetEntries({})
  expect(not QuestlineSettings.completedQuests[a],"abandoning after an unsuccessful reward attempt is not a completion")
  GetQuestReward=reward;GetTitleText=title;AbandonQuest=abandon;Q.rewardHooked=rewardHook;Q.abandonHooked=abandonHook
  Q.ScanLog=scan
  Q.pendingTurnIn=nil;Q.turnInDialog=nil;Q.recentQuests={}
  QuestlineSettings.completedQuests=history;QuestlineSettings.completionSources=sources
  QuestlineDB.quests[a]=nil;QuestlineDB.quests[b]=nil
  Q:SetEntries(original);Q.npcOffers={};Q:InvalidateQuestAvailability()
end

local function starterFactionTests(Q)
  local DB=QuestlineDB
  local original,oldLevel,oldOffers,oldFaction=Q.quests,playerLevel,Q.npcOffers,UnitFactionGroup
  local oldCompleted,oldSources=QuestlineSettings.completedQuests,QuestlineSettings.completionSources
  Q:SetEntries({});playerLevel=60;Q.npcOffers={}
  QuestlineSettings.completedQuests={};QuestlineSettings.completionSources={}
  local group="Horde"
  UnitFactionGroup=function() return group end
  local function hasGiver(entries,id)
    for _,giver in ipairs(entries) do if giver.id==id then return true end end
    return false
  end
  for _,case in ipairs({{1155,41905},{1156,41906},{62414,41850}}) do
    local giver=DB.givers[case[1]]
    expect(DB.quests[case[2]].raceMask==0 and giver.faction=="A","reported quest is restricted by its starter rather than race mask")
    expect(#Q:GetAvailableNPCQuests(giver.name,{case[2]})==0,"Horde NPC tooltip excludes reported Alliance offer")
  end
  Q:InvalidateQuestAvailability()
  expect(not hasGiver(Q:GetAvailableGivers(38),1155) and not hasGiver(Q:GetAvailableGivers(38),1156),"Loch Modan world-map pickup list excludes both Alliance NPCs for Horde")
  expect(not hasGiver(Q:GetMinimapQuestNPCs(5602),62414),"Grim Reaches minimap pickup list excludes Alliance prospector for Horde")
  group="Alliance";Q:InvalidateQuestAvailability()
  expect(hasGiver(Q:GetAvailableGivers(38),1155) and hasGiver(Q:GetAvailableGivers(38),1156),"Alliance retains both Loch Modan pickups")
  expect(hasGiver(Q:GetMinimapQuestNPCs(5602),62414),"Alliance retains Grim Reaches prospector pickup")
  for _,case in ipairs({{1155,41905},{1156,41906},{62414,41850}}) do
    expect(#Q:GetAvailableNPCQuests(DB.givers[case[1]].name,{case[2]})==1,"Alliance NPC tooltip retains reported offer")
  end
  expect(not Q:StarterFactionAllows("H") and Q:StarterFactionAllows("A"),"Alliance rejects Horde-only starters")
  group="Horde"
  expect(Q:StarterFactionAllows("H") and not Q:StarterFactionAllows("A"),"Horde rejects Alliance-only starters")
  expect(Q:StarterFactionAllows("AH") and Q:StarterFactionAllows("") and Q:StarterFactionAllows(nil),"neutral and unspecified starter factions stay permissive")
  expect(#Q:GetAvailableNPCQuests("Wanted!",{398},"object","A")==0,"hostile-faction object starters are filtered")
  expect(#Q:GetAvailableNPCQuests("Wanted!",{398},"object","H")==1,"friendly-faction object starters remain available")
  expect(#Q:GetAvailableNPCQuests("Same Name",{41905},"unit","H")==1,"a friendly variant is evaluated independently of other starters")
  expect(#Q:GetAvailableNPCQuests("Same Name",{41905},"unit","A")==0,"an enemy variant cannot inherit another starter's eligibility")
  local name=DB.givers[1155].name
  Q.npcOffers[Q:Normalize(name)]={quests={{title=DB.quests[41905].title,level=18}}}
  expect(#Q:GetAvailableNPCQuests(name,{41905},"unit","A")==1,"actual server offer takes precedence over predicted starter faction")
  Q.npcOffers={};UnitFactionGroup=nil
  expect(#Q:GetAvailableNPCQuests(name,{41905})==1,"missing faction API does not invent a restriction")
  UnitFactionGroup=function() return nil end
  expect(Q:StarterFactionAllows("A"),"unknown player faction stays permissive")
  UnitFactionGroup=oldFaction;playerLevel=oldLevel;Q.npcOffers=oldOffers
  QuestlineSettings.completedQuests=oldCompleted;QuestlineSettings.completionSources=oldSources
  Q:SetEntries(original);Q:InvalidateQuestAvailability()
end
local function activePrerequisiteTests(Q)
  local original,history,sources,offers=Q.quests,QuestlineSettings.completedQuests,QuestlineSettings.completionSources,Q.npcOffers
  local mapZone,physicalZone,x,y=Q.GetMapZone,Q.GetPlayerZone,playerX,playerY
  QuestlineSettings.completedQuests={};QuestlineSettings.completionSources={};Q.npcOffers={};Q:SetEntries({})
  local function entry(id,complete)
    local e=quest(id,{},complete);e.key=tostring(id);e.data=QuestlineDB.quests[id];return e
  end
  local function helpers(available,message)
    for _,id in ipairs({410,431}) do expect(Q:IsQuestAvailable(id)==available,message..": "..QuestlineDB.quests[id].title) end
  end
  local function find(pool,id)
    for _,pin in ipairs(pool) do if pin:IsShown() and pin.giver.id==id then return pin end end
  end
  helpers(false,"summoning helpers require the parent in the live quest log")
  Q:SetEntries({entry(409)});helpers(true,"accepting Proving Allegiance enables its summoning helpers")
  Q.GetMapZone=function() return 85 end;Q.GetPlayerZone=function() return 85 end
  playerX,playerY=.666,.449;WorldMapFrame:Show();Q:RefreshQuestGivers()
  expect(find(Q.mapGivers,-1557) and find(Q.mapGivers,-1586),"active parent shows both helper object pickup markers")
  expect(find(Q.minimapGivers,-1557),"active parent shows the nearby summoning table on the minimap")
  Q:SetEntries({entry(409,true)});helpers(true,"killing Lillith retains the live parent until it is rewarded")
  Q:SetEntries({});helpers(false,"abandoning the parent removes its helpers")
  Q:SetQuestCompleted(409,"Automatic");helpers(false,"rewarding the parent cannot unlock active-only helper quests")
  Q:SetEntries({entry(411,true)});helpers(false,"completed Prodigal Lich Returns awaiting turn-in cannot revive helpers")
  Q:RefreshQuestGivers()
  expect(not find(Q.mapGivers,-1557) and not find(Q.mapGivers,-1586),"reported follow-up state hides both Tirisfal helper pickup markers")
  expect(not find(Q.minimapGivers,-1557) and not find(Q.minimapGivers,-1586),"reported follow-up state hides both minimap helper pickup markers")
  Q.GetMapZone=function() return 1497 end;Q:RefreshQuestGivers()
  local turnin=find(Q.mapGivers,1498)
  expect(turnin and #turnin.giver.turnins==1 and turnin.giver.turnins[1].id==411,"Bethor Iceshard retains the real completed follow-up turn-in marker")
  local id=992010
  QuestlineDB.quests[id]={title="Alternative active requirement",level=1,minLevel=1,prerequisites={409,366},activePrerequisites={409}}
  expect(not Q:IsQuestAvailable(id),"completed active-only parent does not satisfy a mixed requirement")
  Q:SetQuestCompleted(366,"Server")
  expect(Q:IsQuestAvailable(id),"an independent completed predecessor remains a valid alternative")
  QuestlineDB.quests[id].prerequisites={};QuestlineDB.quests[id].activePrerequisites={409,366}
  Q:SetEntries({entry(366)});expect(Q:IsQuestAvailable(id),"any live active predecessor can satisfy an active-only requirement")
  Q:SetEntries({});expect(not Q:IsQuestAvailable(id),"completion history alone cannot satisfy any active-only predecessor")
  QuestlineDB.quests[id]=nil
  Q.GetMapZone=mapZone;Q.GetPlayerZone=physicalZone;playerX,playerY=x,y
  QuestlineSettings.completedQuests=history;QuestlineSettings.completionSources=sources;Q:SetEntries(original)
  Q.npcOffers=offers;Q:InvalidateQuestAvailability();WorldMapFrame:Hide();Q:RefreshQuestGivers()
end
local function instantClassTurnInTests(Q)
  local original,savedLog,savedSelection=Q.quests,log,selection
  local history,sources=QuestlineSettings.completedQuests,QuestlineSettings.completionSources
  local oldClass,oldRace,oldAPI=UnitClass,UnitRace,C_QuestLog
  local oldLink,oldLegacy=GetQuestLinkForLogIndex,GetQuestLink
  local reward,title,rewardHook=GetQuestReward,GetTitleText,Q.rewardHooked
  QuestlineSettings.completedQuests={};QuestlineSettings.completionSources={}
  Q.pendingTurnIn=nil;Q.recentQuests={};Q:SetEntries({})
  UnitClass=function() return "Priest","PRIEST" end
  UnitRace=function() return "Undead","Scourge" end
  local data=QuestlineDB.quests[5658]
  GetQuestLinkForLogIndex=nil;GetQuestLink=nil
  C_QuestLog={GetQuestIDForLogIndex=function() return 5658 end}
  expect(Q:ResolveQuest(2,data.title,10,"","")==5658,"native client quest IDs identify the real empty-text Touch of Weakness among same-title variants")
  GetQuestLink=function() return "|Hquest:5663:10|h[Touch of Weakness]|h" end
  expect(Q:ResolveQuest(2,data.title,10,"","")==5658,"exact native ID takes precedence over a stale same-title link")
  C_QuestLog.GetQuestIDForLogIndex=function() error("API unavailable") end
  expect(Q:ResolveQuest(2,data.title,10,"","")==5663,"unavailable native ID API retains the supported link fallback")
  GetQuestLink=nil;C_QuestLog.GetQuestIDForLogIndex=function() return 0 end
  expect(Q:ResolveQuest(2,data.title,10,"","")==nil,"zero native ID does not guess a same-title class quest")
  C_QuestLog.GetQuestIDForLogIndex=function() return 5658 end
  local accepted=quest(5658,{})
  log={{title="Undercity",header=true,closed=true,quests={accepted}}};selection=1
  GetTitleText=function() return data.title end
  GetQuestReward=function()
    expect(Q.pendingTurnIn and Q.pendingTurnIn.id==5658,"reward hook captures a newly accepted class quest before the native reward call")
    Q:ObserveQuestCompletion("Touch of Weakness completed.")
    Q:ScanLog()
    expect(not QuestlineSettings.completedQuests[5658] and Q.pendingTurnIn.confirmed,"early completion message survives an intermediate live-log scan")
    log[1].quests={}
  end
  Q.rewardHooked=nil;Q:InitializeNPCQuests()
  expect(not Q.byKey["5658"],"instant turn-in begins before the periodic tracker snapshot sees the quest")
  fire("QUEST_COMPLETE")
  expect(Q.turnInDialog and Q.turnInDialog.id==5658 and not QuestlineSettings.completedQuests[5658],"reward dialogue refreshes the log without prematurely recording history")
  expect(log[1].closed and selection==1,"turn-in refresh preserves collapsed headers and the selected quest-log row")
  -- Simulate an automation addon claiming the reward without waiting for the
  -- normal QUEST_COMPLETE handler or tracker refresh.
  Q:SetEntries({});GetQuestReward(1);Q:ScanLog()
  expect(QuestlineSettings.completedQuests[5658] and QuestlineSettings.completionSources[5658]=="Automatic" and not Q.byKey["5658"],"Touch of Weakness clears and records automatically after reward and log removal")
  for id=5659,5663 do expect(not QuestlineSettings.completedQuests[id],"turn-in does not complete another same-title priest quest") end
  expect(not Q:IsQuestAvailable(5658) and not Q:IsQuestAvailable(5663),"automatic completion hides the completed priest quest and its mutually exclusive offers")
  GetQuestReward=reward;GetTitleText=title;Q.rewardHooked=rewardHook
  UnitClass=oldClass;UnitRace=oldRace;C_QuestLog=oldAPI;GetQuestLinkForLogIndex=oldLink;GetQuestLink=oldLegacy
  QuestlineSettings.completedQuests=history;QuestlineSettings.completionSources=sources
  Q.pendingTurnIn=nil;Q.turnInDialog=nil;Q.recentQuests={}
  log=savedLog;selection=savedSelection;Q:SetEntries(original)
end

local function spawnDotTests(Q)
  expect(QuestlineDB.quests[5482].objectives[1].icon=="interact","Doom Weed uses gear for its world-object objective")
  local doom=QuestlineDB.locations["item:13702"][85]
  expect(doom and doom.spawnKinds and string.len(doom.spawnKinds)==string.len(doom.spawnPoints)/4 and not string.find(doom.spawnKinds,"[^g]"),"all Doom Weed spawn positions retain object source classification")
  local alphabetCheck="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"
  local packedTargets=0
  for key,zones in pairs(QuestlineDB.locations) do for _,location in pairs(zones) do
    if location.spawnPoints then
      assert(not string.find(key,"^turnin:"),"turn-ins must not compile spawn markers")
      assert(math.mod(string.len(location.spawnPoints),4)==0,"packed spawn pairs must be complete")
      local seen={}
      for i=1,string.len(location.spawnPoints),4 do
        local xy=string.sub(location.spawnPoints,i,i+3)
        assert(not seen[xy],"compiled spawn positions are deduplicated");seen[xy]=true
        for j=i,i+2,2 do
          local a=string.find(alphabetCheck,string.sub(location.spawnPoints,j,j),1,true)
          local b=string.find(alphabetCheck,string.sub(location.spawnPoints,j+1,j+1),1,true)
          assert(a and b and (a-1)*64+b-1<=4000,"spawn coordinate within map bounds")
        end
      end
      packedTargets=packedTargets+1
    end
  end end
  expect(packedTargets>1000,"database retains spawn coordinates for mob/item/object targets")
  local original,setting=Q.quests,QuestlineSettings.worldMapSpawns
  local oldX,oldY,oldPlayerZone=playerX,playerY,playerZone
  local alphabet="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"
  local function pair(v)
    v=math.floor(v*40+.5)
    return string.sub(alphabet,math.floor(v/64)+1,math.floor(v/64)+1)..string.sub(alphabet,math.mod(v,64)+1,math.mod(v,64)+1)
  end
  local target={key="test:spawns",kind="unit",name="Spawn mob",icon="kill"}
  QuestlineDB.locations[target.key]={[17]={runs="",points={},anchor={52.2,31},spawnPoints=pair(52.2)..pair(31)..pair(52.3)..pair(31)..pair(90)..pair(90)}}
  local a={key="spawn:a",id=993001,title="Spawn test",level=1,objectives={{text="Spawn mob slain: 0/2",done=false}},data={objectives={target},finishers={}}}
  local b={key="spawn:b",id=993002,title="Shared spawn test",level=2,objectives={},data={objectives={target},finishers={}}}
  Q:SetEntries({a,b});Q:Select(a.key);Q.spawnCache=nil
  playerZone="The Barrens";playerX=.522;playerY=.31;minimapIndoor=false;Minimap:SetZoom(0);cvars.rotateMinimap="0"
  QuestlineSettings.worldMapSpawns=true;WorldMapFrame:Show();SetMapZoom(1,1);Q.mapDirty=true;Q:RefreshMap();Q:RefreshQuestGivers()
  local function shown(pool) local n=0;for _,p in ipairs(pool or {}) do if p:IsShown() then n=n+1 end end;return n end
  expect(shown(Q.mapSpawns)==3 and shown(Q.minimapSpawns)==2,"world map shows all selected spawns; minimap clips distant ones")
  expect(Q.overlay:GetFrameLevel()<Q.mapPins[1]:GetFrameLevel() and Q.mapPins[1]:GetFrameLevel()<Q.mapSpawns[1]:GetFrameLevel() and Q.mapPins[1].parent==Q.pinLayer,"badges share the foreground pin layer above areas and below spawn icons")
  Q.mapPins[1]:SetFrameLevel(500);Q:RefreshMap()
  expect(Q.overlay:GetFrameLevel()<Q.mapPins[1]:GetFrameLevel() and Q.mapPins[1]:GetFrameLevel()<Q.mapSpawns[1]:GetFrameLevel(),"cached map refresh repairs marker layering")
  expect(Q.mapSpawns[1]:GetWidth()==14 and Q.minimapSpawns[1]:GetWidth()==14,"spawn action icons are compact")
  expect(Q.mapSpawns[1].texture.textureValue[1]:find("action%-kill") and Q.minimapSpawns[1].texture.textureValue[1]:find("action%-kill"),"mob spawns use sword artwork on both maps")
  local oldCandidates,oldSpawns,oldScan=Q.GetMinimapQuestNPCs,Q.SelectedSpawns,Q.ScanLog
  Q.GetMinimapQuestNPCs=function() error("motion frame rebuilt questgiver eligibility") end
  Q.SelectedSpawns=function() error("motion frame rebuilt selected spawns") end
  Q.ScanLog=function() error("motion frame scanned quest log") end
  Q.minimapRenderData.entries={{id=993999,name="Motion NPC",points={{52.2,31}},quests={},turnins={}}}
  Q.elapsed=0
  local previousX=Q.minimapSpawns[1].point[4]
  for frame=1,3 do
    playerX=playerX-.0001;tick(.016)
    expect(Q.minimapSpawns[1].point[4]>previousX,"objective markers move on consecutive frames below quest refresh interval")
    previousX=Q.minimapSpawns[1].point[4]
    expect(Q.minimapGivers[1].point[4]==previousX,"questgiver and objective markers use the same per-frame position")
  end
  local shows=Q.minimapSpawns[1].showCalls;tick(.016)
  expect(Q.minimapSpawns[1].showCalls==shows,"stationary frames skip redundant marker rendering")
  Q.GetMinimapQuestNPCs=oldCandidates;Q.SelectedSpawns=oldSpawns;Q.ScanLog=oldScan
  playerX=.522;Q:RefreshQuestGivers()
  target.icon="loot";Q.mapDirty=true;Q:RefreshMap();Q:RefreshQuestGivers()
  expect(Q.mapSpawns[1].texture.textureValue[1]=="Interface\\GossipFrame\\VendorGossipIcon" and Q.minimapSpawns[1].texture.textureValue[1]=="Interface\\GossipFrame\\VendorGossipIcon" and Q.mapSpawns[1]:GetWidth()==12 and Q.minimapSpawns[1]:GetWidth()==12,"pooled item-source markers switch to smaller native bags")
  target.icon="interact";Q.mapDirty=true;Q:RefreshMap();Q:RefreshQuestGivers()
  expect(Q.mapSpawns[1].texture.textureValue[1]:find("action%-interact") and Q.minimapSpawns[1].texture.textureValue[1]:find("action%-interact"),"pooled interaction markers switch to gears")
  QuestlineDB.locations[target.key][17].spawnKinds="gll";Q.spawnCache=nil;Q.mapDirty=true;Q:RefreshMap();Q:RefreshQuestGivers()
  expect(Q.mapSpawns[1].texture.textureValue[1]:find("action%-interact") and Q.mapSpawns[2].texture.textureValue[1]=="Interface\\GossipFrame\\VendorGossipIcon","mixed item sources distinguish objects from mob drops on world map")
  expect(Q.minimapSpawns[1].texture.textureValue[1]:find("action%-interact") and Q.minimapSpawns[2].texture.textureValue[1]=="Interface\\GossipFrame\\VendorGossipIcon","mixed item sources retain their individual icons on minimap")
  Q:Select(b.key,true);Q:RefreshQuestGivers()
  expect(shown(Q.mapSpawns)==3,"shared target coordinates are deduplicated across selected quests")
  local before=#widgets;Q.mapDirty=true;Q:RefreshMap();Q:RefreshQuestGivers()
  expect(#widgets==before,"spawn dots reuse pooled frames and cached coordinates")
  click(Q.optionsPanel.spawns);Q:RefreshQuestGivers()
  expect(QuestlineSettings.worldMapSpawns==false and shown(Q.mapSpawns)==0 and shown(Q.minimapSpawns)==2,"world-map option hides dots without hiding minimap spawns")
  Q:Select(a.key);a.objectives[1].done=true;Q:SetEntries({a,b});Q:RefreshQuestGivers()
  expect(shown(Q.minimapSpawns)==0,"finished objective spawns disappear")
  a.objectives[1].done=false;a.complete=true;Q:SetEntries({a,b});Q:RefreshQuestGivers()
  expect(shown(Q.minimapSpawns)==0,"ready turn-ins have no spawn dots")
  a.complete=false;Q:SetEntries({a,b});Q:Select(a.key);Q:RefreshQuestGivers()
  SetMapZoom(1,2);Q.mapDirty=true;Q:RefreshMap();Q:RefreshQuestGivers()
  expect(shown(Q.mapSpawns)==0 and shown(Q.minimapSpawns)==2,"browsing another zone preserves same-zone minimap sample only")
  playerZone="Durotar";Q:RefreshQuestGivers();expect(shown(Q.minimapSpawns)==0,"crossing zones clears stale minimap dots")
  QuestlineDB.locations[target.key]=nil;Q.spawnCache=nil
  QuestlineSettings.worldMapSpawns=setting;playerX,playerY,playerZone=oldX,oldY,oldPlayerZone
  Q:SetEntries(original);SetMapZoom(1,1);Q.mapDirty=true;Q:RefreshMap();Q:RefreshQuestGivers()
end
local function objectTooltipTests(Q)
  local original=Q.quests
  local oldFocus,oldWorld=GetMouseFocus,WorldFrame
  WorldFrame=WorldFrame or CreateFrame("Frame",nil,UIParent)
  local focus=WorldFrame;GetMouseFocus=function() return focus end
  for _,id in ipairs({365,5481,5482}) do
    local data=QuestlineDB.quests[id];local target=data.objectives[1]
    local entry={id=id,key=tostring(id),title=data.title,level=data.level,data=data,objectives={{text=target.name..": 2/10",kind="item",done=false}}}
    Q:SetEntries({entry});mouseoverName=nil;mouseoverPlayer=false;focus=WorldFrame
    GameTooltip:Hide();GameTooltip:SetOwner(UIParent,"ANCHOR_NONE");GameTooltip:SetText(target.name);GameTooltip:Show()
    Q:RefreshMobTooltip()
    expect(GameTooltip:NumLines()==3 and GameTooltipTextLeft2:GetText()==Q:QuestTitle(entry),"quest object tooltip adds quest heading for "..target.name)
    expect(GameTooltipTextLeft3:GetText()=="  "..target.name.." - 2/10","quest object tooltip adds item count without mob drop rate")
    local shows=GameTooltip.showCalls;Q:RefreshMobTooltip()
    expect(GameTooltip:NumLines()==3 and GameTooltip.showCalls==shows,"object tooltip updates do not duplicate lines or restart tooltip")
    focus=UIParent;GameTooltip:FadeOut();Q:RefreshMobTooltip()
    expect(GameTooltipTextLeft3:IsShown() and GameTooltip.fading,"object progress persists through native fade")
    GameTooltip:Hide();GameTooltip:SetText(target.name);GameTooltip:Show();Q:RefreshMobTooltip()
    expect(GameTooltip:NumLines()==1,"same-name inventory tooltip does not get world-object details")
  end
  GameTooltip:Hide();GetMouseFocus=oldFocus;WorldFrame=oldWorld;Q:SetEntries(original)
end
local function trackerMapTests(Q)
  local original,mode=Q.quests,QuestlineSettings.trackerMode
  local a={key="double:objective",name="Test target",kind="unit",icon="sword"}
  local b={key="double:finisher",id=991112,name="Test giver",kind="unit",icon="turnin"}
  QuestlineDB.locations[a.key]={[14]={points={{50,50}},runs="",anchor={50,50}}}
  QuestlineDB.locations[b.key]={[17]={points={{50,50}},runs="",anchor={50,50}}}
  local entry={key="double:quest",id=991111,title="Map test",level=1,objectives={},data={objectives={a},finishers={b}}}
  Q:SetEntries({entry});Q:SetTrackerMode("world");playerZone="The Barrens";SetMapZoom(1,1);WorldMapFrame:Hide()
  local row=Q.tracker.rows[1]
  click(row);expect(not WorldMapFrame:IsShown() and Q:IsSelected(entry.key),"single click highlights without opening map")
  this=row;arg1="LeftButton";row.scripts.OnDoubleClick()
  expect(WorldMapFrame:IsShown() and Q:GetMapZone()==14 and Q:IsSelected(entry.key),"tracker double-click opens off-zone objective map and highlights quest")
  entry.complete=true;Q:SetEntries({entry})
  this=Q.tracker.rows[1].badge;arg1="LeftButton";this.scripts.OnDoubleClick()
  expect(Q:GetMapZone()==17,"badge double-click on completed quest opens turn-in zone")
  entry.complete=false;entry.objectives={{text="Test target: 1/1",done=true}}
  Q:SetEntries({entry});WorldMapFrame:Hide();Q:TrackerDoubleClick(entry,"LeftButton")
  expect(not WorldMapFrame:IsShown(),"completed objective locations are not used when nothing remains mapped")
  entry.objectives={};QuestlineDB.locations[a.key][17]=QuestlineDB.locations[b.key][17]
  Q:TrackerDoubleClick(entry,"LeftButton");expect(Q:GetMapZone()==17,"multi-zone quest prefers physical zone")
  shiftDown=true;WorldMapFrame:Hide();Q:TrackerDoubleClick(entry,"LeftButton");shiftDown=false
  expect(not WorldMapFrame:IsShown(),"shift double-click preserves chat-link gesture")
  Q:TrackerDoubleClick(entry,"RightButton");expect(not WorldMapFrame:IsShown(),"right double-click cannot trigger map navigation")
  Q:SetEntries({});Q:TrackerDoubleClick(entry,"LeftButton")
  expect(not WorldMapFrame:IsShown(),"stale tracker entry cannot open a quest map")
  QuestlineDB.locations[a.key]=nil;QuestlineDB.locations[b.key]=nil
  Q:SetEntries(original);Q:SetTrackerMode(mode);SetMapZoom(1,1)
end
local function trackerResizeTests(Q)
  local original,mode=Q.quests,QuestlineSettings.trackerMode
  local oldMouseIsOver=MouseIsOver
  local hovered
  MouseIsOver=function(frame) return hovered==frame end
  local entries={}
  for i=1,12 do entries[i]={key="resize:"..i,title="Resize quest "..i,level=i,summary="",objectives={{text="Collect quest items: 0/8",done=false}}} end
  Q:SetEntries(entries);Q:SetTrackerMode("world");Q:Command("reset")
  local panel=Q.tracker
  expect(panel:GetWidth()==258 and panel.pages==3,"unresized tracker retains five quests per page")
  expect(not panel.grip.texture:IsShown(),"resize grip is invisible by default")
  hovered=panel;this=panel;panel.scripts.OnUpdate()
  expect(panel.grip.texture:IsShown(),"hovering anywhere within tracker bounds reveals the corner grip")
  this=panel.grip;panel.grip.scripts.OnLeave()
  expect(panel.grip.texture:IsShown(),"moving from grip to another part of the tracker keeps the anchor visible")
  hovered=nil;this=panel;panel.scripts.OnUpdate()
  expect(not panel.grip.texture:IsShown(),"leaving tracker bounds hides the resize anchor")
  this=panel.grip;panel.grip.scripts.OnEnter()
  expect(panel.grip.texture:IsShown(),"resize grip appears on corner hover")
  arg1="RightButton";panel.grip.scripts.OnMouseDown()
  expect(not panel.resizing,"right click does not resize")
  arg1="LeftButton";panel.grip.scripts.OnMouseDown()
  expect(panel.resizing and panel.sizing=="BOTTOMRIGHT" and panel.point[1]=="TOPLEFT","resize fixes the top-left corner and starts bottom-right sizing")
  panel:SetWidth(420);panel:SetHeight(600);this=panel;panel.scripts.OnSizeChanged()
  expect(panel.rows[1]:GetWidth()==400 and panel.rows[1].detail:GetWidth()==365,"rows and objective wrapping follow resized width")
  expect(panel.pages<3 and QuestlineSettings.trackerSize.height==600,"taller tracker fits more quests and saves dimensions")
  this=panel.grip;panel.grip.scripts.OnLeave()
  expect(panel.grip.texture:IsShown(),"grip remains visible while dragging outside the corner")
  panel.grip.scripts.OnMouseUp()
  expect(not panel.resizing and not panel.grip.texture:IsShown(),"releasing resize stops sizing and hides grip")
  expect(QuestlineSettings.trackerPosition.x==panel:GetLeft(),"resize saves the new top-left anchor")
  hovered=panel;this=panel.grip;arg1="LeftButton";panel.grip.scripts.OnMouseDown();panel.grip.scripts.OnMouseUp()
  expect(panel.grip.texture:IsShown(),"releasing resize while hovering the tracker keeps its anchor visible")
  hovered=nil;this=panel;panel.scripts.OnUpdate()
  Q:RefreshTrackers();expect(panel:GetWidth()==420 and panel:GetHeight()==600,"ordinary refresh retains saved dimensions")
  expect(Q.mapTracker:GetWidth()==258 and not QuestlineSettings.mapSize,"HUD resize does not resize map tracker")
  click(panel.toggle);expect(panel:GetHeight()==33 and not panel.grip:IsShown(),"collapsed tracker hides resize handle")
  hovered=panel;this=panel;panel.scripts.OnUpdate()
  expect(not panel.grip.texture:IsShown(),"collapsed tracker cannot reveal its resize anchor on hover")
  hovered=nil
  click(panel.toggle);expect(panel:GetWidth()==420 and panel:GetHeight()==600,"expansion restores expanded dimensions")
  QuestlineSettings.trackerSize={width=258,height=180};Q:RefreshTrackers()
  local seen={}
  for page=1,panel.pages do
    panel.page=page;Q:RefreshTrackers()
    for _,row in ipairs(panel.rows) do if row:IsShown() then
      expect(not seen[row.entry.key],"resized pagination does not duplicate quests");seen[row.entry.key]=true
    end end
  end
  for _,entry in ipairs(entries) do expect(seen[entry.key],"resized pagination keeps every quest reachable") end
  entries[1].objectives={{text=string.rep("Long objective text ",70),done=false}}
  panel.page=1;Q:RefreshTrackers()
  expect(panel:GetHeight()>=37+panel.rows[1]:GetHeight()+28,"single oversized quest expands panel rather than clipping objectives")
  local map=Q.mapTracker
  this=map.grip;arg1="LeftButton";map.grip.scripts.OnMouseDown()
  map:SetWidth(350);map:SetHeight(400);this=map;map.scripts.OnSizeChanged();map.scripts.OnHide()
  expect(not map.resizing and QuestlineSettings.mapSize.width==350,"hiding map during resize finalizes its independent size")
  expect(not map.grip.texture:IsShown(),"hiding tracker clears its resize anchor")
  Q:Command("reset")
  expect(not QuestlineSettings.trackerSize and not QuestlineSettings.mapSize and panel:GetWidth()==258,"reset restores automatic tracker sizing")
  expect(panel:GetFrameStrata()=="BACKGROUND" and panel:GetFrameLevel()==0,"HUD tracker stays at the back after clicking, resizing, collapsing and resetting")
  for _,control in ipairs({panel.header,panel.mode,panel.toggle,panel.previous,panel.next,panel.grip,panel.rows[1],panel.rows[1].badge}) do
    expect(control:GetFrameStrata()=="BACKGROUND","all HUD click surfaces remain behind ordinary windows")
  end
  expect(map:GetFrameStrata()=="FULLSCREEN" and map:GetFrameLevel()==WorldMapFrame:GetFrameLevel()+40,"world-map tracker preserves its elevated map layer")
  Q:SetEntries(original);Q:SetTrackerMode(mode)
  MouseIsOver=oldMouseIsOver
end
local function trackerModeTests(Q)
  local original,selected=Q.quests,QuestlineSettings.selected
  local targets={}
  for _,id in ipairs({14,17}) do
    local key="test-zone:"..id
    QuestlineDB.locations[key]={[id]={runs="",points={},anchor={50,50}}}
    targets[id]={key=key,name="Objective",kind="unit"}
  end
  local entries={}
  for i=1,14 do
    local target=targets[i<=6 and 14 or 17]
    entries[i]={key="test-quest:"..i,id=990000+i,title="Quest "..i,summary="",objectives={},
      complete=i==14,data={objectives={target},finishers={targets[14]}}}
  end
  entries[13].data=nil;entries[13].id=nil -- Unmapped quests still belong in World mode.
  Q:SetTrackerMode("world")
  Q:SetEntries(entries)
  WorldMapFrame:Hide();Q:RefreshTrackers()
  expect(Q.tracker:IsVisible(),"normal tracker shown outside the map")
  expect(QuestlineSettings.trackerMode=="world" and Q.tracker.heading:GetText()=="Quests - World","explicit World mode shows all quests")
  expect(Q.tracker.mode.text:GetText()=="Show Zone" and #Q:GetTrackerEntries()==14,"World offers Show Zone and includes unmapped quests")
  Q.tracker.page=3;Q:RefreshTrackers();Q:Select(entries[12].key);expect(Q.tracker.page==3 and Q.tracker.rows[2].entry==entries[12],"single selection preserves page three and level sorting")
  click(Q.tracker.mode)
  expect(QuestlineSettings.trackerMode=="zone" and Q.tracker.heading:GetText()=="Quests - The Barrens","mode click uses physical zone and saves preference")
  expect(Q.tracker.mode.text:GetText()=="Show World" and Q.tracker.page==1,"mode switch resets pagination and offers Show World")
  expect(#Q:GetTrackerEntries()==6 and Q.tracker.rows[1].badge.text:GetText()=="1" and Q.tracker.rows[1].entry.number==7,"Zone starts badges at one without mutating full-log numbers and excludes off-zone turn-ins")
  expect(QuestlineSettings.selected==entries[12].key,"mode switch preserves highlighted quest")
  Q:Select(entries[12].key)
  expect(Q.tracker.page==1 and Q.tracker.rows[1].entry==entries[7],"single selection leaves filtered level order unchanged")

  WorldMapFrame:Show();Q:RefreshMap()
  Q:RefreshTrackers();expect(Q.tracker:IsVisible() and Q.mapTracker:IsVisible(),"both trackers remain visible with a windowed world map")
  click(Q.mapPins[1])
  expect(QuestlineSettings.selected==entries[7].key and Q.tracker.page==1,"map click selects and pages correctly in Zone mode")
  Q:Select(entries[12].key)

  WorldMapFrame:Show();SetMapZoom(1,2);fire("WORLD_MAP_UPDATE");Q:RefreshMap()
  expect(Q:GetMapZone()==14 and Q:GetPlayerZone()==17,"browsed map and physical zone remain independent")
  expect(Q.tracker.heading:GetText()=="Quests - The Barrens" and #Q:GetTrackerEntries()==6,"browsing another map leaves HUD scope unchanged")
  expect(Q.tracker.rows[1].badge.text:GetText()=="1" and Q.mapTracker.rows[1].badge.text:GetText()=="1","HUD and browsed map each number their own zone from one")
  expect(Q.mapTracker.rows[1].entry==entries[1] and Q.mapTracker.pages==2,"map tracker continues filtering the displayed map")
  Q:Select(entries[14].key)
  click(Q.mapTracker.next);expect(Q.mapTracker.rows[2].badge.text:GetText()=="?","completed quest retains its level-sorted position")
  expect(Q.tracker.page==1 and #Q:GetTrackerEntries()==6,"selecting an off-zone map quest preserves HUD filter and resets its page")

  playerZone="Durotar";fire("ZONE_CHANGED_NEW_AREA")
  expect(Q.tracker.heading:GetText()=="Quests - Durotar" and Q.tracker.page==1,"travel updates zone heading and resets page")
  expect(#Q:GetTrackerEntries()==7,"new zone includes active objectives and completed turn-ins")
  click(Q.tracker.next);fire("ZONE_CHANGED_INDOORS")
  expect(Q.tracker.page==2,"moving indoors in the same zone preserves pagination")
  entries[1].objectives={{text="Objective: 1/1",done=true}};Q:SetEntries(entries)
  expect(#Q:GetTrackerEntries()==6,"finished objectives stop contributing to the zone list")
  click(Q.tracker.mode)
  expect(#Q:GetTrackerEntries()==14 and Q.tracker.heading:GetText()=="Quests - World","World restores every quest")
  expect(Q.mapTracker.page==2 and Q.mapTracker.rows[1].entry==entries[14],"HUD mode toggle preserves map filtering and page")

  WorldMapFrame:Hide();Q:RefreshTrackers()
  click(Q.tracker.toggle);click(Q.tracker.mode)
  expect(QuestlineSettings.collapsed and Q.tracker.mode:IsVisible(),"mode remains available on the collapsed tracker")
  playerZone="An Unmapped Zone With A Very Long Name";fire("ZONE_CHANGED")
  expect(Q.tracker.heading:GetText()=="Quests - Zone","long zone names leave room for header controls")
  expect(Q.tracker.headingText=="Quests - "..playerZone,"header retains full zone name for tooltip")
  click(Q.tracker.toggle)
  expect(#Q:GetTrackerEntries()==0 and Q.tracker.empty:IsShown(),"unknown zone does not fall back to the browsed map")
  expect(Q.tracker.empty:GetText():find("Click Show World"),"empty zone offers an escape to all quests")
  WorldMapFrame:Show();Q:RefreshMap();click(Q.mapPins[1])
  expect(QuestlineSettings.selected==entries[2].key and #Q:GetTrackerEntries()==0,"map selection works when physical zone has no database ID")
  fire("PLAYER_ENTERING_WORLD")
  expect(QuestlineSettings.trackerMode=="zone","world-entry refresh preserves saved mode")
  click(Q.tracker.mode)
  expect(#Q:GetTrackerEntries()==14,"World remains usable in an unmapped zone")

  -- Four unfinished quests remain among off-zone quests and two turn-ins.
  entries[3].complete=true;entries[6].tag="Dungeon";Q:SetEntries(entries);Q:RefreshMap()
  local nextNumber=0
  for _,entry in ipairs(Q.quests) do
    if not entry.complete then
      nextNumber=nextNumber+1
      expect(entry.number==nextNumber,"World quest numbers are contiguous across dungeon, ordinary, off-zone, and unmapped quests")
    else expect(entry.number==nil,"completed question marks consume no World number") end
  end
  for _,p in ipairs(Q.mapPins) do if p:IsShown() and not p.entry.complete then
    expect(p.text:GetText()==tostring(p.entry.number),"World map uses full-log numbers for dungeon and ordinary quests mixed with off-zone quests")
  end end
  for page=1,Q.mapTracker.pages do
    Q.mapTracker.page=page;Q:RefreshTrackers()
    for _,r in ipairs(Q.mapTracker.rows) do if r:IsShown() and not r.entry.complete then
      expect(r.badge.text:GetText()==tostring(r.entry.number),"filtered map tracker uses the World tracker's full-log numbers across pages")
    end end
  end
  Q:SetTrackerMode("zone")
  local expected={[entries[2].key]="1",[entries[3].key]="?",[entries[4].key]="2",[entries[5].key]="3",[entries[6].key]="4",[entries[14].key]="?"}
  for page=1,Q.mapTracker.pages do
    Q.mapTracker.page=page;Q:RefreshTrackers()
    for _,r in ipairs(Q.mapTracker.rows) do if r:IsShown() then
      expect(r.badge.text:GetText()==expected[r.entry.key],"zone badges compact across pages and skip interleaved turn-in question marks")
    end end
  end
  for _,p in ipairs(Q.mapPins) do if p:IsShown() and not p.entry.complete then
    expect(p.text:GetText()==expected[p.entry.key],"map pin numbers match compact zone tracker numbers")
  end end
  Q:Select(entries[2].key);Q:Select(entries[6].key,true)
  expect(Q.mapTracker.rows[2].entry==entries[6] and Q.mapTracker.rows[2].badge.text:GetText()=="4","moving a highlighted quest to the front preserves its zone number")
  Q:Select(entries[2].key)
  entries[4].objectives={{text="Objective: 1/1",done=true}};Q:SetEntries(entries);Q:RefreshMap()
  expect(Q:GetZoneQuestNumbers(14)[entries[6].key]==3,"finishing another zone quest closes its numbering gap")
  expect(Q:GetZoneQuestNumbers(nil)[entries[6].key]==nil,"unknown zones have no invented local numbers")
  Q:SetTrackerMode("world")
  for _,p in ipairs(Q.mapPins) do if p:IsShown() and not p.entry.complete then
    expect(p.text:GetText()==tostring(p.entry.number),"switching to World immediately repaints cached map badges without a map or quest update")
  end end
  for _,r in ipairs(Q.mapTracker.rows) do if r:IsShown() and not r.entry.complete then
    expect(r.badge.text:GetText()==tostring(r.entry.number),"switching to World immediately restores matching map tracker numbers")
  end end
  expect(Q.tracker.rows[1].badge.text:GetText()==tostring(Q.tracker.rows[1].entry.number),"World tracker retains full-log numbering")

  playerZone="The Barrens";SetMapZoom(1,1)
  QuestlineDB.locations[targets[14].key]=nil;QuestlineDB.locations[targets[17].key]=nil
  QuestlineSettings.selected=selected;Q:SetEntries(original);Q:RefreshMap()
end

local function mobTooltipTests(Q)
  expect(GameTooltip.GetOwner==nil,"Vanilla tooltip tests run without the unavailable GetOwner method")
  local savedLog,savedSelection=log,selection
  local ribs=quest(426,{{text="Blackened Skull: 0/3",kind="item"},{text="Notched Rib: 0/5",kind="item"}})
  local kills=quest(380,{{text="Night Web Spider slain: 3/8",kind="monster"},{text="Young Night Web Spider slain: 2/10",kind="monster"}})
  log={{title="Tirisfal Glades",header=true,closed=true,quests={ribs,kills}}}
  Q:ScanLog();Q:SetTrackerMode("zone");Q:Select("380")
  expect(Q.byKey["426"] and Q.byKey["380"],"tooltip fixtures resolve from the real imported quests")
  local function hover(name)
    mouseoverName=name;mouseoverPlayer=false
    GameTooltip:SetOwner(UIParent,"ANCHOR_NONE")
    GameTooltip:SetText(name);GameTooltip:AddLine("Level 7 Undead");GameTooltip:Show()
    this=QuestlineMobTooltip;arg1=.2;this.scripts.OnUpdate()
  end
  hover("Rattlecage Soldier")
  expect(GameTooltip:NumLines()==4 and GameTooltipTextLeft3:GetText()==Q:QuestTitle(QuestlineDB.quests[426]),"mob tooltip includes the relevant quest heading")
  expect(GameTooltipTextLeft4:GetText()=="  Notched Rib (40%) - 0/5","mob tooltip indents its quest item's live count")
  expect(GameTooltipTextLeft2:GetText()=="Level 7 Undead","existing tooltip details retained")
  expect(log[1].closed and QuestlineSettings.selected=="380","tooltip reads collapsed quests without changing shared selection")
  for i=1,5 do Q:RefreshMobTooltip() end
  expect(GameTooltip:NumLines()==4,"repeated tooltip updates never append duplicate headings or progress")
  mouseoverName=nil;GameTooltip:FadeOut();local shows=GameTooltip.showCalls
  for i=1,5 do Q:RefreshMobTooltip() end
  expect(GameTooltipTextLeft3:IsShown() and GameTooltipTextLeft4:GetText()=="  Notched Rib (40%) - 0/5","quest heading and item progress persist after leaving the mob")
  expect(GameTooltip:NumLines()==4 and GameTooltip.fading and GameTooltip.showCalls==shows,"lingering quest details neither duplicate lines nor restart the tooltip fade")
  expect(not Q.updatingMobTooltip,"leaving the mob does not lock future tooltip refreshes")
  mouseoverName="Night Web Spider";Q:RefreshMobTooltip()
  expect(GameTooltipTextLeft4:GetText()=="  Notched Rib (40%) - 0/5","moving toward a different mob keeps the original tooltip intact until it is replaced")
  hover("Night Web Spider")
  expect(GameTooltipTextLeft3:GetText()==Q:QuestTitle(QuestlineDB.quests[380]) and GameTooltipTextLeft4:GetText()=="  Night Web Spider - 3/8","replacement mob tooltip shows only the new mob's quest")
  mouseoverName=nil;GameTooltip:Hide()
  expect(Q.mobTooltipName==nil and Q.mobTooltipOwner==nil and #Q.mobTooltipLines==0,"hiding the tooltip ends its remembered unit lifetime")
  GameTooltip:SetText("Night Web Spider");GameTooltip:Show();Q:RefreshMobTooltip()
  expect(GameTooltip:NumLines()==1,"a new non-unit tooltip with the same title cannot resurrect old quest details")
  hover("Rattlecage Soldier");mouseoverName=nil
  GameTooltip:SetText("A bag item");Q:RefreshMobTooltip()
  expect(GameTooltip:NumLines()==1 and Q.mobTooltipName==nil,"replacing a fading tooltip with an item clears its unit association")
  hover("Rattlecage Soldier");mouseoverName=nil
  GameTooltip:SetText("Rattlecage Soldier");GameTooltip:AddLine("A different tooltip with the same title");Q:RefreshMobTooltip()
  expect(GameTooltip:NumLines()==2 and Q.mobTooltipName==nil,"same-title content replacement is detected when the original quest lines are gone")
  -- Also check the optional owner safeguard on clients that provide a getter.
  GameTooltip.GetOwner=function(tooltip) return tooltip.owner end
  hover("Rattlecage Soldier");mouseoverName=nil;GameTooltip:SetOwner(Q.tracker,"ANCHOR_RIGHT");Q:RefreshMobTooltip()
  expect(not GameTooltipTextLeft3:IsShown() and not GameTooltipTextLeft4:IsShown(),"changing tooltip owners cannot retain the previous unit's quest lines")
  GameTooltip.GetOwner=nil
  hover("Rattlecage Soldier")
  ribs.objectives[2].text="Notched Rib: 1/5";now=now+1;fire("QUEST_LOG_UPDATE");tick(.2);Q:RefreshMobTooltip()
  expect(GameTooltipTextLeft4:GetText()=="  Notched Rib (40%) - 1/5" and GameTooltip:NumLines()==4,"quest-log events update counters while still hovering")
  hover("Cracked Skull Soldier")
  expect(GameTooltipTextLeft4:GetText()=="  Notched Rib (40%) - 1/5","other recorded drop sources show the same collection progress")
  hover("Darkeye Bonecaster")
  expect(GameTooltipTextLeft4:GetText()=="  Blackened Skull (40%) - 0/3","a different mob gets only its own relevant item objective")
  hover("Young Night Web Spider")
  expect(GameTooltipTextLeft3:GetText()==Q:QuestTitle(QuestlineDB.quests[380]) and GameTooltipTextLeft4:GetText()=="  Young Night Web Spider - 2/10","kill counters appear under their quest and match names rather than database objective order")
  hover("Night Web Spider")
  expect(GameTooltipTextLeft4:GetText()=="  Night Web Spider - 3/8","similar mob names do not mix kill counters")

  ribs.objectives[2].text="Notched Rib: 5/5";ribs.objectives[2].done=1;Q:ScanLog();hover("Rattlecage Soldier")
  expect(GameTooltipTextLeft4:GetText()=="  Notched Rib (40%) - 5/5" and GameTooltipTextLeft4.color[2]>GameTooltipTextLeft4.color[1],"completed objectives show full progress in green")
  ribs.complete=1;Q:ScanLog();Q:RefreshMobTooltip()
  expect(GameTooltipTextLeft4:GetText()=="  Notched Rib (40%) - 5/5","completed quest progress remains available until turn-in")
  ribs.complete=-1;Q:ScanLog();Q:RefreshMobTooltip()
  expect(not GameTooltipTextLeft3:IsShown() and not GameTooltipTextLeft4:IsShown(),"failed quest removes its heading and counter while hovering")
  ribs.complete=nil;Q:ScanLog();Q:RefreshMobTooltip()
  expect(GameTooltipTextLeft4:IsShown() and GameTooltip:NumLines()==4,"cleared tooltip slots are reused")
  hover("Rattlecage Soldier")
  expect(GameTooltip:NumLines()==4,"rebuilding a tooltip for the same mob restores exactly one quest group")

  -- Two accepted quests can need the exact same item/count, while one also needs
  -- another drop from this mob. Preserve both groups and live objective ordering.
  local mills,spiders=Q.byKey["426"],Q.byKey["380"]
  local shared={key="test:shared-ribs",id=990001,level=1,title="Supplies for Brill",summary="",
    data={objectives={{kind="item",key="item:2589",name="Linen Cloth"},{kind="item",key="item:3162",name="Notched Rib"}},finishers={}},
    objectives={{text="Notched Rib: 5/5",kind="item",done=true},{text="Linen Cloth: 1/10",kind="item"}}}
  Q:SetEntries({shared,mills,spiders});hover("Rattlecage Soldier")
  expect(GameTooltip:NumLines()==7 and GameTooltipTextLeft3:GetText()==Q:QuestTitle(shared) and GameTooltipTextLeft6:GetText()==Q:QuestTitle(mills),"shared mobs show quest groups in level order")
  expect(GameTooltipTextLeft4:GetText()=="  Notched Rib (40%) - 5/5" and GameTooltipTextLeft5:GetText()=="  Linen Cloth (30%) - 1/10","multiple relevant objectives share one heading in live log order")
  expect(GameTooltipTextLeft7:GetText()=="  Notched Rib (40%) - 5/5","identical counters remain visible under each quest")
  shared.objectives[1]={text="Notched Rib: 3/7",kind="item"};Q:SetEntries({shared,mills,spiders});Q:RefreshMobTooltip()
  expect(GameTooltipTextLeft4:GetText()=="  Notched Rib (40%) - 3/7" and GameTooltipTextLeft7:GetText()=="  Notched Rib (40%) - 5/5","quests sharing an item retain independent current and required counts")
  GameTooltip:SetText("Rattlecage Soldier")
  GameTooltip:AddLine("|cff555555[|cffffcc00!|cff555555]|r "..mills.title)
  GameTooltip:AddLine("|cffaaaaaa- |rNotched Rib: 5/5 |cff555555[40%]|r");Q:RefreshMobTooltip()
  expect(GameTooltip:NumLines()==6 and GameTooltipTextLeft4:GetText()==Q:QuestTitle(shared),"an existing quest group does not suppress another quest using the same item")
  expect(GameTooltipTextLeft5:GetText()=="  Notched Rib (40%) - 3/7" and GameTooltipTextLeft6:GetText()=="  Linen Cloth (30%) - 1/10","new group keeps its own counters beside pfQuest content")
  hover("Rattlecage Soldier");Q:SetEntries({shared,spiders});Q:RefreshMobTooltip()
  expect(GameTooltipTextLeft3:GetText()==Q:QuestTitle(shared) and not GameTooltipTextLeft6:IsShown() and not GameTooltipTextLeft7:IsShown(),"removing one quest clears only its group")
  Q:ScanLog();hover("Rattlecage Soldier")

  GameTooltip:SetText("Rattlecage Soldier")
  GameTooltip:AddLine("|cff555555[|cffffcc00!|cff555555]|r The Mills Overrun")
  GameTooltip:AddLine("|cffaaaaaa- |rNotched Rib: 5/5 |cff555555[40%]|r")
  GameTooltip:AddLine("Another addon's detail");Q:RefreshMobTooltip()
  expect(GameTooltip:NumLines()==4 and GameTooltipTextLeft4:GetText()=="Another addon's detail","existing matching pfQuest group is not duplicated or overwritten")
  GameTooltip:SetText("Rattlecage Soldier");GameTooltip:AddLine("Notched Rib: 5/5");Q:RefreshMobTooltip()
  expect(GameTooltipTextLeft3:GetText()==Q:QuestTitle(mills) and GameTooltipTextLeft4:GetText()=="  Notched Rib (40%) - 5/5","unlabelled external progress cannot hide the requested quest grouping")
  hover("Cow");expect(GameTooltip:NumLines()==2,"unrelated mobs have no quest progress")
  mouseoverName="Rattlecage Soldier";mouseoverPlayer=true;GameTooltip:SetText(mouseoverName);Q:RefreshMobTooltip()
  expect(GameTooltip:NumLines()==1,"player tooltips are ignored")
  mouseoverPlayer=false;GameTooltip:SetText("Some bag item");Q:RefreshMobTooltip()
  expect(GameTooltip:NumLines()==1,"item tooltip is not decorated just because a mob is under the cursor")
  Q:ScanLog();hover("Rattlecage Soldier")
  log[1].quests={kills};Q:ScanLog();Q:RefreshMobTooltip()
  expect(not GameTooltipTextLeft3:IsShown() and not GameTooltipTextLeft4:IsShown() and #Q:GetMobProgress("Rattlecage Soldier")==0,"abandoning or turning in a quest clears its heading and cached progress")
  log=savedLog;selection=savedSelection;mouseoverName=nil
  Q:SetTrackerMode("world");Q:ScanLog();GameTooltip:Hide()
end

local function trackerClickTests(Q)
  local function row(id)
    for page=1,Q.tracker.pages do
      Q.tracker.page=page;Q:RefreshTrackers()
      for _,r in ipairs(Q.tracker.rows) do if r:IsShown() and r.entry.id==id then return r end end
    end
    error("Missing visible tracker quest "..id)
  end
  local savedLog,savedSelection=log,selection
  local savedCompat=pfQuestCompat
  local beaks=quest(844,{{text="Plainstrider Beak: 0/7",kind="item"}})
  local hooves=quest(845,{{text="Zhevra Hooves: 0/4",kind="item"}})
  log={{title="The Barrens",header=true,closed=true,quests={beaks,hooves}},
    {title="Tirisfal Glades",header=true,closed=true,quests={quest(426)}},
    {title="Durotar",header=true,quests={quest(869,{},1)}}}
  selection=4;Q:ScanLog();Q:SetTrackerMode("world");Q:Select("869")
  WorldMapFrame:Hide();QuestLogFrame:Hide();Q:RefreshTrackers()
  local nativeCalls=0
  local function nativeLink(index)
    nativeCalls=nativeCalls+1
    local q=visible()[index];assert(q and not q.header,"native quest link given invalid index")
    return "|cffffff00|Hquest:"..q.id..":"..q.level.."|h["..q.title.."]|h|r"
  end
  GetQuestLinkForLogIndex=nativeLink
  shiftDown=true;ChatFrameEditBox:Show();ChatFrameEditBox:SetText("Before  after");ChatFrameEditBox.cursor=7
  click(row(844))
  expect(ChatFrameEditBox:GetText()=="Before |cffffff00|Hquest:844:"..beaks.level.."|h["..beaks.title.."]|h|r after","shift-click inserts the client's native quest link at the chat cursor")
  expect(nativeCalls>=1 and ChatFrameEditBox.focused,"uses the same link API as Octo's Blizzard quest log")
  expect(selection==4 and log[1].closed and log[2].closed,"linking restores collapsed categories and quest-log selection")
  expect(QuestlineSettings.selected=="869" and not QuestLogFrame:IsShown(),"linking preserves highlighted quest and does not open the log")
  local callsBeforeSelection=nativeCalls
  ChatFrameEditBox:Hide();click(row(845).badge)
  expect(QuestlineSettings.selected=="845" and not ChatFrameEditBox:IsShown() and nativeCalls==callsBeforeSelection,"shift-click with chat closed keeps normal selection behavior")
  ChatFrameEditBox:Show();local draft=ChatFrameEditBox:GetText()
  click(row(844).badge,"RightButton")
  expect(QuestLogFrame:IsShown() and visible()[selection].id==844,"right-click on a tracker circle opens that quest")
  expect(not log[1].closed and log[2].closed and ChatFrameEditBox:GetText()==draft,"right-click expands only the needed category and wins over Shift")
  expect(QuestlineSettings.selected=="845","opening the log preserves the highlighted map quest")
  shiftDown=false;log[1].closed=true;log[2].closed=true;selection=4
  click(row(426),"RightButton")
  expect(selection==3 and visible()[selection].id==426 and log[1].closed and not log[2].closed,"restoring earlier collapsed categories remaps the destination index correctly")

  SetMapZoom(1,1);WorldMapFrame:Show();Q.mapDirty=true;Q:RefreshMap()
  click(Q.mapTracker.rows[2],"RightButton")
  expect(not WorldMapFrame:IsShown() and QuestLogFrame:IsShown() and visible()[selection].id==845,"map tracker right-click reveals the quest log instead of leaving it behind the map")
  shiftDown=true;ChatFrameEditBox:SetText("");ChatFrameEditBox.cursor=0
  click(Q.mapTracker.rows[1].badge)
  expect(ChatFrameEditBox:GetText():find("|Hquest:844:"),"map tracker badges also support chat links")
  GetQuestLinkForLogIndex=nil;GetQuestLink=nativeLink
  ChatFrameEditBox:SetText("");ChatFrameEditBox.cursor=0;click(row(845))
  expect(ChatFrameEditBox:GetText():find("|Hquest:845:"),"standard GetQuestLink is supported when the Octo API is absent")
  GetQuestLink=nil
  pfQuestCompat={InsertQuestLink=function(id,title) ChatFrameEditBox:Insert("pfQuest:"..id..":"..title) end}
  ChatFrameEditBox:SetText("");ChatFrameEditBox.cursor=0;click(row(844))
  expect(ChatFrameEditBox:GetText()=="pfQuest:844:"..beaks.title,"pfQuest's configured link format remains a fallback")
  pfQuestCompat=nil;ChatFrameEditBox:SetText("");ChatFrameEditBox.cursor=0;click(row(844))
  expect(ChatFrameEditBox:GetText()=="["..beaks.title.."]","unmodified Vanilla falls back to the quest title")

  shiftDown=false;QuestLogFrame:Hide()
  log[1].quests={hooves};selection=2 -- Quest removed before the next tracker refresh.
  click(row(844),"RightButton")
  expect(not QuestLogFrame:IsShown() and selection==2,"stale tracker entry cannot open a different quest")
  local custom={id=999995,title="Uncatalogued Delivery",level=12,summary="Custom objective",description="Custom details",objectives={}}
  log={{title="Custom",header=true,closed=true,quests={custom}}};selection=1;Q:ScanLog()
  click(Q.tracker.rows[1],"RightButton")
  expect(visible()[selection]==custom and not Q.quests[1].id,"quests without a database match still open from their live text")
  GetQuestLinkForLogIndex=nativeLink;shiftDown=true;ChatFrameEditBox:SetText("");ChatFrameEditBox.cursor=0
  click(Q.tracker.rows[1]);expect(ChatFrameEditBox:GetText():find("|Hquest:999995:"),"unknown database quests still get native chat links")
  shiftDown=false;GetQuestLinkForLogIndex=nil
  log[1].quests={custom,custom};log[1].closed=true;selection=1;QuestLogFrame:Hide()
  click(Q.tracker.rows[1],"RightButton")
  expect(not QuestLogFrame:IsShown() and log[1].closed,"ambiguous live entries are not guessed")

  local many={};for _,id in ipairs({844,845,895,900,869,426,380,903}) do table.insert(many,quest(id)) end
  log={{title="Mixed",header=true,closed=true,quests=many}};selection=1;Q:ScanLog();Q:Select("903")
  click(row(903),"RightButton")
  expect(visible()[selection].id==903 and QuestLogListScrollFrameScrollBar.value==48,"right-click scrolls the destination quest into the visible log list")
  pfQuestCompat=savedCompat;log=savedLog;selection=savedSelection
  ChatFrameEditBox:Hide();QuestLogFrame:Hide();Q:ScanLog()
end

local function npcQuestTests(Q)
  local DB=QuestlineDB
  local original,history,level=Q.quests,QuestlineSettings.completedQuests,playerLevel
  QuestlineSettings.completedQuests={};Q:SetEntries({});Q.npcOffers={};Q.recentQuests={}
  expect(Q:IsQuestAvailable(786),"Thwarting Kolkar Aggression is available without the absent quest 785 or completion history")
  local lar
  for _,giver in ipairs(Q:GetAvailableGivers(14)) do if giver.id==3140 then lar=giver end end
  expect(lar and lar.quests[1].id==786,"Lar Prowltusk has a predicted Durotar pickup marker")
  local minimapLar
  for _,giver in ipairs(Q:GetMinimapQuestNPCs(14)) do if giver.id==3140 then minimapLar=giver end end
  expect(minimapLar and minimapLar.quests[1].id==786,"minimap NPC data retains Lar's available quest")
  local name="Deathguard Dillinger"
  expect(DB.quests[700001].disabled and not Q:IsQuestAvailable(700001),"absent Oink, Oink! quest is disabled by the upstream database")
  expect(#Q:GetAvailableNPCQuests("Pig",{700001})==0,"absent Pig cannot generate an available quest marker")
  local function has(groups,title)
    for _,g in ipairs(groups) do if g.title==title then return g end end
  end
  local function entry(id,objectives,complete)
    local e=quest(id,objectives,complete);e.key=tostring(id);e.data=DB.quests[id];return e
  end
  local function hover(npc)
    mouseoverName=npc;mouseoverPlayer=false;GameTooltip:SetText(npc);GameTooltip:AddLine("Level 55");GameTooltip:Show();Q:RefreshMobTooltip()
  end
  local sections=Q:GetNPCSections(name)
  expect(has(sections[1].groups,"A Putrid Task") and not has(sections[1].groups,"The Mills Overrun"),"NPC offers the first quest, not its locked follow-up")
  playerLevel=3;expect(not Q:IsQuestAvailable(404),"quests below their minimum level are hidden")
  playerLevel=12
  hover(name)
  expect(GameTooltipTextLeft3:GetText()=="Available" and GameTooltipTextLeft4:GetText()=="  "..Q:QuestTitle(QuestlineDB.quests[404]),"NPC tooltip groups eligible offers under Available")
  expect(GameTooltip:NumLines()==4,"empty NPC status sections are omitted")
  local task=entry(404,{{text="Putrid Claw: 7/10",kind="item"}})
  Q:SetEntries({task});hover(name);sections=Q:GetNPCSections(name)
  expect(#sections[1].groups==0 and #sections[2].groups==1,"accepting moves the quest from Available to In Progress")
  expect(GameTooltipTextLeft3:GetText()=="In Progress" and GameTooltipTextLeft5:GetText()=="    Putrid Claw - 7/10","NPC progress appears under an indented quest title")
  mouseoverName=nil;GameTooltip:FadeOut();local shows=GameTooltip.showCalls;Q:RefreshMobTooltip()
  expect(GameTooltipTextLeft3:GetText()=="In Progress" and GameTooltipTextLeft5:IsShown() and GameTooltipTextLeft5:GetText()=="    Putrid Claw - 7/10","NPC sections and indented quest counters persist during fade")
  expect(GameTooltip.fading and GameTooltip.showCalls==shows,"NPC details leave the normal fade timing intact")
  mouseoverName=name
  task.objectives[1]={text="Putrid Claw: 10/10",kind="item",done=true};task.complete=true;Q:SetEntries({task});Q:RefreshMobTooltip()
  expect(GameTooltipTextLeft3:GetText()=="Complete" and GameTooltipTextLeft4:GetText()=="  "..Q:QuestTitle(QuestlineDB.quests[404]) and not GameTooltipTextLeft5:IsShown(),"ready-to-turn-in quest replaces progress without leaving old counters")
  expect(not Q:IsQuestAvailable(426),"finishing objectives alone does not unlock the next quest")
  Q:SetEntries({});expect(not QuestlineSettings.completedQuests[404] and Q:IsQuestAvailable(404),"removing or abandoning a quest does not record a turn-in")
  arg1="A Putrid Task completed.";fire("CHAT_MSG_SYSTEM")
  expect(QuestlineSettings.completedQuests[404] and Q:IsQuestAvailable(426) and not Q:IsQuestAvailable(404),"completion message after log removal records the recent quest and unlocks its successor")
  hover(name);expect(GameTooltipTextLeft4:GetText()=="  "..Q:QuestTitle(QuestlineDB.quests[426]),"NPC tooltip advances to the unlocked quest")
  local oldFormat=ERR_QUEST_COMPLETE_S;ERR_QUEST_COMPLETE_S="Completed [%s]!"
  local mills=entry(426,{{text="Notched Rib: 2/5",kind="item"},{text="Blackened Skull: 1/3",kind="item"}})
  Q:SetEntries({mills});hover(name)
  expect(GameTooltipTextLeft5:GetText()=="    Notched Rib - 2/5" and GameTooltipTextLeft6:GetText()=="    Blackened Skull - 1/3","questgiver lists every live objective in log order")
  arg1="Completed [The Mills Overrun]!";fire("CHAT_MSG_SYSTEM");ERR_QUEST_COMPLETE_S=oldFormat
  expect(not QuestlineSettings.completedQuests[426] and Q.pendingTurnIn,"localized completion message also waits for live quest removal")
  Q:SetEntries({})
  expect(QuestlineSettings.completedQuests[426],"completion parsing honors the client's localized format and pattern punctuation")
  Q:SetEntries({});Q.recentQuests={};QuestlineSettings.completedQuests[404]=nil
  arg1="A Putrid Task completed.";fire("CHAT_MSG_SYSTEM")
  expect(not QuestlineSettings.completedQuests[404],"unrelated or expired completion names cannot mark unknown quests completed")

  local oldImported,oldPf=QuestlineSettings.importedQuestHistory,pfQuest_history
  pfQuest_history={[860]={123,12},[404]={123,12},[999999]=false};QuestlineSettings.importedQuestHistory=nil
  Q:InitializeNPCQuests()
  expect(QuestlineSettings.completedQuests[860] and not QuestlineSettings.completedQuests[999999],"login imports valid local pfQuest history")
  expect(pfQuest_history[860][1]==123,"history import leaves pfQuest settings untouched")
  pfQuest_history=oldPf;QuestlineSettings.importedQuestHistory=oldImported
  local synthetic={title="Restricted offer",level=12,minLevel=10,raceMask=2,classMask=1,prerequisites={},blockedBy={}}
  DB.quests[990011]=synthetic
  expect(Q:IsQuestAvailable(990011),"matching race/class can receive an unrestricted quest")
  synthetic.raceMask=1;expect(not Q:IsQuestAvailable(990011),"opposite race quest is hidden")
  synthetic.raceMask=2;synthetic.classMask=128;expect(not Q:IsQuestAvailable(990011),"other class quest is hidden")
  synthetic.classMask=1;synthetic.prerequisites={426,999999};expect(Q:IsQuestAvailable(990011),"alternative prerequisites unlock when any supported predecessor is completed")
  synthetic.blockedBy={426};expect(not Q:IsQuestAvailable(990011),"completed mutually exclusive quest prevents offer")
  synthetic.blockedBy={};synthetic.event=25;expect(not Q:IsQuestAvailable(990011),"seasonal quests require a server offer")
  synthetic.event=nil;synthetic.skill="Cooking";Q.npcSkills=nil
  local oldSkills,oldSkill=GetNumSkillLines,GetSkillLineInfo
  GetNumSkillLines=function() return 1 end;GetSkillLineInfo=function() return "Cooking",nil,nil,0 end
  expect(not Q:IsQuestAvailable(990011),"unlearned profession quests are hidden")
  GetSkillLineInfo=function() return "Cooking",nil,nil,25 end;fire("SKILL_LINES_CHANGED")
  expect(Q:IsQuestAvailable(990011),"learning a profession unlocks its quests")
  QuestlineSettings.completedQuests[990011]=true;expect(not Q:IsQuestAvailable(990011),"completed one-time quests stay hidden")
  synthetic.repeatable=true;expect(Q:IsQuestAvailable(990011),"explicit repeatable quests can be offered again")
  QuestlineSettings.completedQuests[990011]=nil;DB.quests[990011]=nil;GetNumSkillLines=oldSkills;GetSkillLineInfo=oldSkill;Q.npcSkills=nil

  local oldGossip=GetGossipAvailableQuests;npcName=name
  GetGossipAvailableQuests=function() return "A holiday surprise",12,"A server-only quest",13 end
  fire("GOSSIP_SHOW");sections=Q:GetNPCSections(name)
  expect(#sections[1].groups==2 and sections[1].groups[2].title=="A server-only quest","actual Vanilla gossip title/level pairs override predicted offers")
  GetGossipAvailableQuests=function() end;fire("GOSSIP_SHOW")
  expect(#Q:GetNPCSections(name)[1].groups==0,"an explicitly empty server offer list suppresses stale predictions")
  QuestlineSettings.completedQuests[404]=nil;now=now+61
  expect(#Q:GetNPCSections(name)[1].groups==0,"observed server offers remain authoritative during the current quest state")
  fire("PLAYER_LEVEL_UP")
  expect(has(Q:GetNPCSections(name)[1].groups,"A Putrid Task"),"level changes invalidate observed server offers")
  local oldNum,oldTitle,oldLevel=GetNumAvailableQuests,GetAvailableTitle,GetAvailableLevel
  GetNumAvailableQuests=function() return 1 end;GetAvailableTitle=function() return "Greeting offer" end;GetAvailableLevel=function() return 12 end
  fire("QUEST_GREETING");expect(Q:GetNPCSections(name)[1].groups[1].title=="Greeting offer","non-gossip quest greetings also supply actual offers")
  GetGossipAvailableQuests=oldGossip;GetNumAvailableQuests=oldNum;GetAvailableTitle=oldTitle;GetAvailableLevel=oldLevel;npcName=nil;Q.npcOffers={}

  local travel=entry(80209,{{text="Speak to Magistrix Ishalah: 0/1",kind="event"},{text="Portal used: 0/1",kind="event"}})
  Q:SetEntries({travel});hover("Magistrix Ishalah")
  local group=has(Q:GetNPCSections("Magistrix Ishalah")[2].groups,travel.title)
  expect(group and #group.objectives==1 and group.objectives[1].text=="Talk to Magistrix Ishalah - 0/1","a conversation objective is identified without treating the NPC as a giver or finisher")
  expect(GameTooltipTextLeft3:GetText()=="In Progress","talk-to quest uses the In Progress section")
  travel.complete=true;Q:SetEntries({travel})
  local s=Q:GetNPCSections("Magistrix Ishalah");expect(not s or (#s[2].groups==0 and #s[3].groups==0),"finished talk objective is not advertised as a turn-in at the wrong NPC")
  local unknown={key="unknown:talk",title="A new conversation",summary="",objectives={{text="Talk with A Helpful Stranger: 0/1",kind="event"}}}
  Q:SetEntries({unknown});expect(Q:GetNPCSections("A Helpful Stranger")[2].groups[1].objectives[1].text=="Talk to A Helpful Stranger - 0/1","explicit live conversation objectives work for quests absent from the database")
  unknown.summary="Speak to A Helpful Stranger.";unknown.data={objectives={{kind="unit",name="A Helpful Stranger",key="unit:990012"}},finishers={}}
  unknown.objectives={{text="A Helpful Stranger slain: 0/1",kind="monster"}};Q:SetEntries({unknown})
  expect(Q:GetNPCSections("A Helpful Stranger")==nil,"a kill objective is not relabeled as conversation because the summary also says speak")
  QuestlineSettings.completedQuests=history;playerLevel=level;Q:SetEntries(original)
  Q:InvalidateQuestAvailability();mouseoverName=nil;GameTooltip:Hide()
end

local function giverMapTests(Q)
  local history,sources,original=QuestlineSettings.completedQuests,QuestlineSettings.completionSources,Q.quests
  QuestlineSettings.completedQuests={[860]=true};QuestlineSettings.completionSources={[860]="Server"};Q:SetEntries({});Q.npcOffers={};Q:InvalidateQuestAvailability()
  playerZone="The Barrens";SetMapZoom(1,1);WorldMapFrame:Show();Q:RefreshQuestGivers()
  local function find(pool,id)
    for _,pin in ipairs(pool) do if pin:IsShown() and pin.giver.id==id then return pin end end
  end
  local pin=find(Q.mapGivers,3338)
  expect(pin and math.abs(pin.point[4]-.522*1002)<.001 and math.abs(pin.point[5]+.31*668)<.001,"available Sergra Darkthorn marker is placed at her imported Barrens position")
  expect(#pin.giver.quests==1 and pin.giver.quests[1].title=="Plainstrider Menace","giver pin lists only eligible quests")
  this=pin;pin.scripts.OnEnter();expect(WorldMapTooltip:GetText():find("Available") and WorldMapTooltip:GetText():find("Plainstrider Menace"),"map marker hover identifies NPC and available quest")
  WorldMapButton.scale=4;Q:RefreshQuestGivers();expect(pin.width==4,"giver icon retains screen size under map zoom")
  WorldMapButton.scale=1
  SetMapZoom(1,2);Q:RefreshQuestGivers();expect(not find(Q.mapGivers,3338),"browsing another zone removes Barrens questgivers")
  local resets=mapResets;Q:RefreshQuestGivers();expect(mapResets==resets and Q:GetMapZone()==14,"minimap never resets a map the player is browsing")
  WorldMapFrame:Hide();playerX,playerY=.522,.31;Q:RefreshQuestGivers()
  expect(Q:GetMapZone()==17 and mapResets==resets+1,"closing an off-zone map restores player coordinates before minimap drawing")
  pin=find(Q.minimapGivers,3338)
  expect(pin and math.abs(pin.point[4])<.001 and math.abs(pin.point[5])<.001,"nearby questgiver appears at minimap center when beside the NPC")
  expect(not find(Q.mapGivers,3338),"hidden world map releases visible marker state")
  local size=QuestlineDB.zones[17].mapSize
  WorldMapFrame:Show();Q:RefreshQuestGivers()
  expect(find(Q.minimapGivers,3338) and find(Q.mapGivers,3338),"opening current-zone map keeps minimap questgivers visible")
  playerX=.522-50/size[1];Q:RefreshQuestGivers();pin=find(Q.minimapGivers,3338)
  expect(pin and math.abs(pin.point[4]-15)<.01,"minimap markers still follow movement while the world map is open")
  SetMapZoom(1,2);resets=mapResets;playerX,playerY=.05,.95;Q:RefreshQuestGivers();pin=find(Q.minimapGivers,3338)
  expect(pin and math.abs(pin.point[4]-15)<.01,"browsing another zone retains last valid minimap position instead of interpreting other-zone coordinates")
  expect(mapResets==resets and Q:GetMapZone()==14,"retaining minimap markers does not change the browsed map")
  playerZone="Durotar";SetMapZoom(2,1);Q:RefreshQuestGivers()
  expect(not find(Q.minimapGivers,3338),"crossing a physical zone boundary cannot reuse the previous zone's cached position")
  playerZone="The Barrens";SetMapZoom(1,1);playerX,playerY=.522,.31;Q:RefreshQuestGivers()
  expect(find(Q.minimapGivers,3338),"returning to current-zone view resumes live positioning")
  WorldMapFrame:Hide()
  playerX=.522-100/size[1];Q:RefreshQuestGivers();pin=find(Q.minimapGivers,3338)
  expect(pin and math.abs(pin.point[4]-30)<.01 and math.abs(pin.point[5])<.01,"minimap translates one hundred yards to thirty pixels at outdoor zoom zero")
  Minimap:SetZoom(3);Q:RefreshQuestGivers();pin=find(Q.minimapGivers,3338)
  expect(pin and math.abs(pin.point[4]-52.5)<.01,"minimap marker follows zoom changes")
  Minimap:SetZoom(5);Q:RefreshQuestGivers();expect(not find(Q.minimapGivers,3338),"out-of-range giver is clipped rather than pinned beyond the minimap")
  Minimap:SetZoom(0);cvars.rotateMinimap="1";playerFacing=math.pi/2;Q:RefreshQuestGivers();pin=find(Q.minimapGivers,3338)
  expect(pin and math.abs(pin.point[4])<.01 and math.abs(pin.point[5]+30)<.01,"rotation applies player facing when the client supports it")
  cvars.rotateMinimap=nil
  Q:RefreshQuestGivers();pin=find(Q.minimapGivers,3338)
  expect(pin and math.abs(pin.point[4]-30)<.01 and math.abs(pin.point[5])<.01,"missing rotation CVar falls back to north-up even with facing API")
  local savedGetCVar,savedFacing=GetCVar,GetPlayerFacing
  GetCVar=function(name) if name=="rotateMinimap" then return nil end;return savedGetCVar(name) end
  Q:RefreshQuestGivers();pin=find(Q.minimapGivers,3338)
  expect(pin and math.abs(pin.point[4]-30)<.01 and math.abs(pin.point[5])<.01,"nil rotation setting also uses north-up")
  GetCVar=savedGetCVar;GetPlayerFacing=nil
  Q:RefreshQuestGivers();pin=find(Q.minimapGivers,3338)
  expect(pin and math.abs(pin.point[4]-30)<.01,"minimap markers work without facing API or rotation CVar")
  GetPlayerFacing=savedFacing;cvars.rotateMinimap="1"
  Q:RefreshQuestGivers();pin=find(Q.minimapGivers,3338)
  expect(pin and math.abs(pin.point[4])<.01 and math.abs(pin.point[5]+30)<.01,"available rotation setting is still read after fallback")
  cvars.rotateMinimap="0";playerFacing=0
  minimapIndoor=true;cvars.minimapInsideZoom="0";Q.minimapDiameterKey=nil;local writes=zoomWrites
  Q:RefreshQuestGivers();pin=find(Q.minimapGivers,3338)
  expect(pin and math.abs(pin.point[4]-46.6667)<.01 and Minimap:GetZoom()==0,"indoor radius is detected and user's zoom is restored")
  Q:RefreshQuestGivers();expect(zoomWrites==writes+2,"indoor detection probe is cached, not repeated every update")
  minimapIndoor=false;fire("ZONE_CHANGED_INDOORS");Q:RefreshQuestGivers();pin=find(Q.minimapGivers,3338)
  expect(pin and math.abs(pin.point[4]-30)<.01,"crossing indoors/outdoors invalidates radius even when both zoom settings match")
  local p={(.522+180/size[1])*100,(.31-180/size[2])*100}
  expect(not Q:MinimapGiverPosition(p,.522,.31,size,466.6667),"round minimap clips diagonal corners")
  minimapShape="SQUARE";expect(Q:MinimapGiverPosition(p,.522,.31,size,466.6667),"square minimap retains visible corner markers");minimapShape="ROUND"
  local accepted=quest(844,{{text="Plainstrider Beak: 0/7",kind="item"}});accepted.key="844";accepted.data=QuestlineDB.quests[844]
  Q:SetEntries({accepted});Q:RefreshQuestGivers();expect(not find(Q.minimapGivers,3338),"accepting the giver's only available quest immediately removes its minimap marker")
  accepted.complete=true;Q:SetEntries({accepted});Q:RefreshQuestGivers();pin=find(Q.minimapGivers,3338)
  expect(pin and pin.texture.textureValue[1]=="Interface\\AddOns\\Questline\\Textures\\quest-complete","ready quest creates a matching gold question mark on the minimap")
  expect(#pin.giver.turnins==1 and #pin.giver.quests==0,"turn-in marker appears even without available pickup quests")
  this=pin;pin.scripts.OnEnter()
  expect(GameTooltip:GetText():find("Complete",1,true) and GameTooltip:GetText():find("Plainstrider Menace",1,true),"turn-in hover lists the ready quest")
  local delivery=quest(842,{},1);delivery.key="842";delivery.data=QuestlineDB.quests[842];delivery.complete=true
  Q:SetEntries({accepted,delivery});Q:RefreshQuestGivers();pin=find(Q.minimapGivers,3338)
  expect(pin and #pin.giver.turnins==2,"multiple completed quests share the NPC's question mark")
  local onlyFinisher={id=990022,key="990022",title="Delivery only",complete=true,objectives={},data={objectives={},finishers={{kind="unit",id=990023,name="A turn-in-only NPC",key="turnin:unit:3338"}}}}
  Q:SetEntries({accepted,onlyFinisher});Q:RefreshQuestGivers()
  local finishPin=find(Q.minimapGivers,990023)
  expect(finishPin and finishPin.texture.textureValue[1]:find("quest-complete",1,true),"finishers absent from the pickup-NPC index still receive a question mark")
  this=finishPin;finishPin.scripts.OnEnter()
  expect(GameTooltip:GetText():find("Delivery only",1,true) and GameTooltip:GetText():find("Plainstrider Menace",1,true),"clustered turn-in tooltips include neighboring NPCs and ready quests")
  onlyFinisher.failed=true;Q:SetEntries({accepted,onlyFinisher});Q:RefreshQuestGivers()
  expect(not find(Q.minimapGivers,990023),"failed quests never create turn-in question marks")
  Q:SetEntries({accepted});Q:RefreshQuestGivers()
  Q.npcOffers[Q:Normalize("Sergra Darkthorn")]={time=GetTime(),quests={{title="Another available quest",level=12}}}
  Q:InvalidateQuestAvailability();Q:RefreshQuestGivers();pin=find(Q.minimapGivers,3338)
  expect(pin and #pin.giver.quests==1 and pin.texture.textureValue[1]:find("quest-complete",1,true),"turn-in question mark wins when the NPC also offers another quest")
  this=pin;pin.scripts.OnEnter()
  expect(GameTooltip:GetText():find("Another available quest",1,true) and GameTooltip:GetText():find("Complete",1,true),"combined tooltip retains both pickup and turn-in information")
  local count=0;for _,p in ipairs(Q.minimapGivers) do if p:IsShown() and p.giver.id==3338 then count=count+1 end end
  expect(count==1,"one NPC never receives stacked pickup and turn-in minimap icons")
  accepted.complete=false;Q:SetEntries({accepted});Q:RefreshQuestGivers();pin=find(Q.minimapGivers,3338)
  expect(pin and pin.texture.textureValue[1]:find("quest-available",1,true),"reused marker switches back to exclamation when turn-in readiness is lost")
  Q.npcOffers={};Q:InvalidateQuestAvailability()
  QuestlineSettings.completedQuests[844]=true;QuestlineSettings.completionSources[844]="Automatic";Q:SetEntries({});Q:InvalidateQuestAvailability();Q:RefreshQuestGivers();pin=find(Q.minimapGivers,3338)
  expect(pin and pin.giver.quests[1].title=="The Zhevra","turn-in unlocks next offer and restores the giver marker")
  playerX,playerY=0,0;Q:RefreshQuestGivers();expect(not find(Q.minimapGivers,3338),"invalid player coordinates hide minimap pins")
  playerX,playerY=.522,.31;QuestlineSettings.completedQuests=history;QuestlineSettings.completionSources=sources;Q:SetEntries(original);Q:InvalidateQuestAvailability()
  WorldMapFrame:Hide();Q:RefreshQuestGivers()
end

local function minimapScaleTests(Q)
  local oldZone,oldMap,oldGivers,oldSpawns=Q.GetPlayerZone,Q.GetMapZone,Q.GetMinimapQuestNPCs,Q.SelectedSpawns
  local oldIndoors,oldSetZoom=IsIndoors,Minimap.SetZoom
  local oldX,oldY,oldIndoor=playerX,playerY,minimapIndoor
  local oldOutside,oldInside=cvars.minimapZoom,cvars.minimapInsideZoom
  local size=QuestlineDB.zones[1497].mapSize
  local point={53.1,36.2,icon="interact",target={icon="interact"}}
  Q.GetPlayerZone=function() return 1497 end;Q.GetMapZone=Q.GetPlayerZone
  Q.GetMinimapQuestNPCs=function() return {{id=990099,name="City scale test",points={point},quests={},turnins={}}} end
  Q.SelectedSpawns=function() return {point} end
  Minimap.SetZoom=function(self,value) oldSetZoom(self,value);fire("MINIMAP_UPDATE_ZOOM") end
  local spans={{466.6667,400,333.3333,266.6667,200,133.3333},{300,240,180,120,80,50}}
  for mode=1,2 do for zoom=0,5 do
    minimapIndoor=mode==2
    -- Deliberately disagree with the minimap: physical indoors is not its scale.
    IsIndoors=function() return not minimapIndoor end
    cvars.minimapZoom=tostring(zoom);cvars.minimapInsideZoom=tostring(zoom)
    playerX,playerY=.531-10/size[1],.362+10/size[2]
    now=now+1;fire("MINIMAP_UPDATE_ZOOM")
    local writes=zoomWrites
    Q:RefreshQuestGivers()
    expect(zoomWrites==writes+2 and Minimap:GetZoom()==zoom,"equal city zoom settings are probed once and restored at every zoom level")
    local diameter=spans[mode][zoom+1]
    local function positionCheck(distance)
      local giver,spawn=Q.minimapGivers[1],Q.minimapSpawns[1]
      expect(giver:IsShown() and spawn:IsShown(),"both marker types remain visible in the city")
      expect(math.abs(giver.point[4]-distance*Minimap:GetWidth()/diameter)<.001 and
        math.abs(giver.point[5]-10*Minimap:GetHeight()/diameter)<.001,"Undercity marker uses the active minimap scale in both axes")
      expect(spawn.point[4]==giver.point[4] and spawn.point[5]==giver.point[5],"objectives and questgivers share the same city projection")
    end
    positionCheck(10)
    fire("MINIMAP_UPDATE_ZOOM");Q:RefreshMinimapMotion()
    expect(zoomWrites==writes+2,"queued probe zoom events do not cause repeated zoom writes")
    playerX=playerX-5/size[1];Q:RefreshMinimapMotion();positionCheck(15)
    expect(zoomWrites==writes+2,"moving through the city reuses the detected scale")
  end end
  -- A map-mode switch can leave both saved zoom values and the physical zone unchanged.
  minimapIndoor=false;now=now+1;fire("MINIMAP_UPDATE_ZOOM");Q:RefreshMinimapMotion()
  expect(Q.minimapSpawnContext.diameter==spans[1][6],"native mode event invalidates identical cached zoom values without a zone event")
  minimapIndoor=true;fire("MINIMAP_ZONE_CHANGED");Q:RefreshMinimapMotion()
  expect(Q.minimapSpawnContext.diameter==50,"minimap zone changes also invalidate scale during the probe suppression window")
  -- Unequal saved zooms reveal the active mode without changing the user's zoom.
  cvars.minimapZoom="2";cvars.minimapInsideZoom="1";now=now+1
  local writes=zoomWrites;fire("MINIMAP_UPDATE_ZOOM");Q:RefreshMinimapMotion()
  expect(Q.minimapSpawnContext.diameter==240 and zoomWrites==writes,"unequal indoor zoom values select the city scale without probing")
  minimapIndoor=false;fire("MINIMAP_UPDATE_ZOOM");Q:RefreshMinimapMotion()
  expect(Q.minimapSpawnContext.diameter==spans[1][3] and zoomWrites==writes,"unequal outdoor zoom values select the terrain scale without probing")
  Q.GetPlayerZone,Q.GetMapZone,Q.GetMinimapQuestNPCs,Q.SelectedSpawns=oldZone,oldMap,oldGivers,oldSpawns
  IsIndoors,Minimap.SetZoom=oldIndoors,oldSetZoom
  playerX,playerY,minimapIndoor=oldX,oldY,oldIndoor
  cvars.minimapZoom,cvars.minimapInsideZoom=oldOutside,oldInside
  Q.minimapDiameterKey=nil;Q.minimapZoomProbeUntil=nil;Q:RefreshQuestGivers()
end

local function objectGiverTests(Q)
  local original,history,sources=Q.quests,QuestlineSettings.completedQuests,QuestlineSettings.completionSources
  local mapZone,physicalZone,offers=Q.GetMapZone,Q.GetPlayerZone,Q.npcOffers
  local x,y,level=playerX,playerY,playerLevel
  Q.GetMapZone=function() return 85 end;Q.GetPlayerZone=function() return 85 end
  playerX,playerY=.607,.515;playerLevel=12
  QuestlineSettings.completedQuests={};QuestlineSettings.completionSources={};Q:SetEntries({})
  -- A generic name shared with another giver cannot erase this poster's offers.
  Q.npcOffers={["wanted!"]={quests={}}};Q:InvalidateQuestAvailability()
  local function find(pool)
    for _,pin in ipairs(pool) do if pin:IsShown() and pin.giver.id==-711 then return pin end end
  end
  WorldMapFrame:Show();Q:RefreshQuestGivers()
  local pin=find(Q.mapGivers)
  expect(pin and pin.giver.kind=="object" and pin.giver.name=="Wanted!","wanted poster has a distinct named world-map giver marker")
  expect(math.abs(pin.point[4]-.607*1002)<.001 and math.abs(pin.point[5]+.515*668)<.001,"wanted poster uses its upstream coordinates")
  expect(pin.texture.textureValue[1]:find("quest-available",1,true),"wanted poster uses an exclamation")
  this=pin;pin.scripts.OnEnter()
  expect(WorldMapTooltip:GetText():find("Wanted!\n  Available",1,true) and WorldMapTooltip:GetText():find("Wanted: Maggot Eye",1,true),"poster tooltip shows its name and offered quest in the nearby cluster")
  pin=find(Q.minimapGivers)
  expect(pin and math.abs(pin.point[4])<.001 and math.abs(pin.point[5])<.001,"wanted poster also appears at the correct minimap position")
  this=pin;pin.scripts.OnEnter()
  expect(GameTooltip:GetText():find("Wanted!\n  Available",1,true) and GameTooltip:GetText():find("Wanted: Maggot Eye",1,true),"minimap poster tooltip names the poster and quest")
  local active=quest(398);active.key="398";active.data=QuestlineDB.quests[398]
  Q:SetEntries({active});Q:InvalidateQuestAvailability();Q:RefreshQuestGivers()
  expect(not find(Q.mapGivers) and not find(Q.minimapGivers),"accepting the wanted quest removes its pickup markers")
  Q:SetEntries({});Q:InvalidateQuestAvailability();Q:RefreshQuestGivers()
  expect(find(Q.mapGivers) and find(Q.minimapGivers),"abandoning the wanted quest restores its pickup markers")
  Q:SetQuestCompleted(398,"Automatic");Q:RefreshQuestGivers()
  expect(not find(Q.mapGivers) and not find(Q.minimapGivers),"completed wanted quests are not advertised")
  QuestlineSettings.completedQuests={};QuestlineSettings.completionSources={};playerLevel=5
  Q:InvalidateQuestAvailability();Q:RefreshQuestGivers()
  expect(not find(Q.mapGivers),"wanted posters respect the quest minimum level")
  Q.GetMapZone=function() return 130 end;Q.GetPlayerZone=function() return 130 end
  playerX,playerY=.584,.349
  local boatData=QuestlineDB.quests[438]
  local boat={id=438,key="438",title=boatData.title,level=boatData.level,complete=true,objectives={},data=boatData}
  Q:SetEntries({boat});Q:Select("438");Q:RefreshMap();Q:RefreshQuestGivers()
  local function boatPin(pool)
    for _,p in ipairs(pool) do if p:IsShown() and p.giver.id==-1593 then return p end end
  end
  for _,pool in ipairs({Q.mapGivers,Q.minimapGivers}) do
    local p=boatPin(pool)
    expect(p and p.giver.kind=="object" and p.giver.name=="Corpse Laden Boat","object turn-in appears on both maps under its own identity")
    expect(p.texture.textureValue[1]:find("quest-complete",1,true) and #p.giver.turnins==1,"boat uses a single gold turn-in question mark")
    this=p;p.scripts.OnEnter()
    local tip=pool==Q.mapGivers and WorldMapTooltip or GameTooltip
    expect(tip:GetText():find("Corpse Laden Boat\n  Complete",1,true) and tip:GetText():find("The Decrepit Ferry",1,true),"boat marker tooltip identifies the object and ready quest")
  end
  local p=boatPin(Q.minimapGivers)
  expect(math.abs(p.point[4])<.001 and math.abs(p.point[5])<.001,"boat minimap turn-in uses the real object coordinates")
  Q:ShowQuestTooltip(UIParent,boat)
  expect(WorldMapTooltip:GetText():find("Interact with Corpse Laden Boat",1,true),"object destination tooltip uses interaction wording")
  local available=Q.GetAvailableGivers
  Q.GetAvailableGivers=function() return {
    {id=1593,kind="unit",name="Same ID NPC",quests={},points={{58.4,34.9}}},
    {id=-1593,kind="object",name="Corpse Laden Boat",quests={{id=439,title="Follow-up",level=16}},points={{58.4,34.9}}}
  } end
  local entries=Q:GetMinimapQuestNPCs(130)
  expect(#entries==2 and #entries[1].turnins==0 and #entries[2].turnins==1 and #entries[2].quests==1,"object turn-ins merge with object pickups without colliding with equal NPC IDs")
  Q.GetAvailableGivers=available
  boat.failed=true;Q:SetEntries({boat});Q:RefreshQuestGivers()
  expect(not boatPin(Q.mapGivers) and not boatPin(Q.minimapGivers),"failed quests cannot advertise object turn-ins")
  Q:SetEntries({});Q:RefreshQuestGivers()
  expect(not boatPin(Q.minimapGivers),"removing the quest retires its object turn-in")
  Q.GetMapZone=mapZone;Q.GetPlayerZone=physicalZone;playerX,playerY=x,y;playerLevel=level
  QuestlineSettings.completedQuests=history;QuestlineSettings.completionSources=sources;Q:SetEntries(original)
  Q.npcOffers=offers;Q:InvalidateQuestAvailability();WorldMapFrame:Hide();Q:RefreshQuestGivers()
  GameTooltip:Hide();WorldMapTooltip:Hide()
end

local function giverClusterTests(Q)
  local mapPool,miniPool=Q.mapGivers,Q.minimapGivers
  Q.mapGivers={};Q.minimapGivers={};WorldMapFrame:Show()
  local names={"A nearby giver","B nearby giver","C nearby giver","D distant giver","E hidden giver","B nearby giver","F separate giver"}
  local coords={{100,100},{109,100},{106,104},{200,100},{104,100},{108,101},{100,118}}
  for i=1,7 do
    local pin=Q:GetGiverPin(i,false)
    pin.giver={id=i==6 and 2 or i,name=names[i],quests={{title=names[i].." quest one"},{title=names[i].." quest two"}}}
    pin.giverX=coords[i][1];pin.giverY=coords[i][2];pin:Show()
  end
  local shared={id=991111,title="Shared offer"}
  table.insert(Q.mapGivers[1].giver.quests,shared);table.insert(Q.mapGivers[1].giver.quests,shared)
  table.insert(Q.mapGivers[2].giver.quests,shared)
  Q.mapGivers[1].giver.turnins={{id=991112,title="A turn-in"}}
  Q.mapGivers[3].giver.turnins=Q.mapGivers[3].giver.quests;Q.mapGivers[3].giver.quests={}
  Q.mapGivers[5]:Hide()
  expect(#Q:GetNearbyGivers(Q.mapGivers[1],false)==3,"nearby giver hover combines three visible NPCs without duplicates, distant or hidden pins")
  this=Q.mapGivers[1];this.scripts.OnEnter();local text=WorldMapTooltip:GetText()
  for i=1,3 do
    expect(text:find(names[i].." quest one",1,true) and text:find(names[i].." quest two",1,true),"cluster tooltip includes each nearby NPC and all its quests")
  end
  local a=text:find(names[1].."\n",1,true)
  local b=text:find(names[2].."\n",1,true)
  local c=text:find(names[3].."\n",1,true)
  expect(a==1 and b and c and a<b and b<c,"cluster tooltip starts with alphabetically ordered NPC name headers")
  expect(text:find("  Available",a,true)<text:find("  Complete",a,true) and text:find("A turn-in",1,true)<b,"each NPC's Available and Complete sections stay under its own name")
  expect(not string.find(string.sub(text,b,c-1),"  Complete",1,true) and not string.find(string.sub(text,c),"  Available",1,true),"NPC sections omit empty Available and Complete subheaders")
  local _,sharedCount=string.gsub(text,"Shared offer","")
  expect(sharedCount==2,"shared offers appear once under each eligible NPC instead of losing NPC ownership or duplicating within an NPC")
  expect(not text:find(names[7],1,true) and #Q:GetNearbyGivers(Q.mapGivers[7],false)==1,"individually hoverable icons eighteen pixels apart no longer bundle")
  expect(not text:find(names[4],1,true) and not text:find(names[5],1,true),"cluster tooltip excludes distant and hidden NPCs")
  expect(#Q:GetNearbyGivers(Q.mapGivers[2],false)==3,"hovering another overlapping giver still exposes its neighbors")
  for _,pin in ipairs(Q.mapGivers) do pin:SetWidth(3.5);pin:SetHeight(3.5) end
  expect(#Q:GetNearbyGivers(Q.mapGivers[1],false)==1,"world-map zoom separates clusters according to on-screen distance")
  this=Q.mapGivers[2];this.scripts.OnEnter();text=WorldMapTooltip:GetText()
  expect(string.find(text,names[2].."\n  Available",1,true)==1 and not string.find(text,"  Complete",1,true),"individual giver tooltips retain the NPC-first layout and omit empty state sections")
  for i=1,3 do
    local pin=Q:GetGiverPin(i,true);pin.giver=Q.mapGivers[i].giver
    pin.giverX=i==3 and 50 or (i-1)*8;pin.giverY=0;pin:Show()
  end
  this=Q.minimapGivers[1];this.scripts.OnEnter();text=GameTooltip:GetText()
  expect(text:find(names[1].." quest one",1,true) and text:find(names[2].." quest two",1,true) and not text:find(names[3],1,true),"minimap hover also combines nearby NPC names and quests")
  expect(GameTooltipTextLeft1:GetText()==names[1] and GameTooltipTextLeft2:GetText()=="  Available" and string.find(text,names[2].."\n  Available",1,true),"minimap clusters use the same NPC-first section layout")
  expect(GameTooltipTextLeft1:GetFontObject()==GameTooltipText,"first clustered NPC uses the smaller body font")
  for _,pool in ipairs({Q.mapGivers,Q.minimapGivers}) do for _,pin in ipairs(pool) do pin:Hide() end end
  Q.mapGivers=mapPool;Q.minimapGivers=miniPool;WorldMapFrame:Hide();GameTooltip:Hide();WorldMapTooltip:Hide()
  expect(GameTooltipTextLeft1:GetFontObject()==GameTooltipHeaderText,"closing the NPC tooltip restores the shared header font")
end

local function eliteQuestTests(Q)
  local savedLog,savedSelection,savedMode=log,selection,QuestlineSettings.trackerMode
  local mapZone=Q.GetMapZone
  local arugal=quest(99,{{text="Pyrewood Shackles: 0/6",kind="item"}})
  log={{title="Silverpine Forest",header=true,closed=true,quests={arugal}}};selection=1
  Q:ScanLog();Q:SetTrackerMode("world");Q:Select("99")
  local entry=Q.byKey["99"]
  expect(entry and entry.data.questType==1,"Arugal's Folly retains the shared elite quest type")
  expect(Q.tracker.rows[1].title:GetText():find("15+|r]",1,true),"tracker level marks the elite Arugal step with a plus")
  expect(log[1].closed and selection==1 and entry.title==arugal.title,"elite presentation preserves raw quest titles, headers, and log selection")
  Q.GetMapZone=function() return 130 end;WorldMapFrame:Show();Q.mapDirty=true;Q:RefreshMap()
  Q:ShowQuestTooltip(Q.mapPins[1],entry)
  expect(WorldMapTooltip:GetText():find("15+|r]",1,true),"elite quest's world-map tooltip uses the same level suffix")
  local sections=Q:GetNPCSections("Dalar Dawnweaver")
  expect(sections and #sections[2].groups>0 and Q:QuestTitle(sections[2].groups[1]):find("15+|r]",1,true),"NPC progress groups retain elite classification")
  entry.complete=true;Q:SetEntries({entry});sections=Q:GetNPCSections("Dalar Dawnweaver")
  expect(sections and #sections[3].groups==1 and Q:QuestTitle(sections[3].groups[1]):find("15+|r]",1,true),"completed NPC quest groups retain elite classification")
  expect(Q:QuestTitle({id=99,title=arugal.title,level=15}):find("15+|r]",1,true),"available map quest labels use elite metadata before acceptance")
  expect(not Q:QuestTitle({id=422,title=arugal.title,level=11}):find("11+",1,true),"ordinary same-title Arugal steps are not marked elite")
  local unknown={title="Unmapped elite",level=15,tag="Elite",objectives={}}
  log={{title="Unmapped",header=true,closed=true,quests={unknown}}};Q:ScanLog()
  expect(not Q.quests[1].id and Q.quests[1].tag=="Elite" and Q:QuestTitle(Q.quests[1]):find("15+|r]",1,true),"live elite tags mark unresolved quests without guessing a database match")
  expect(not Q:QuestTitle({id=99,title=arugal.title,level=15,tag="Dungeon"}):find("15+",1,true),"explicit live non-elite tags override stored elite types")
  expect(Q:QuestTitle({title="Unknown level",tag="Elite"})=="Unknown level (Elite)","elite quests without a known level retain an explicit label")
  local dungeon={title="Unmapped dungeon",level=16,tag="Dungeon",objectives={}}
  log={{title="Unmapped",header=true,closed=true,quests={dungeon}}};Q:ScanLog()
  expect(not Q.quests[1].id and Q.tracker.rows[1].title:GetText():find("16D|r]",1,true),"live dungeon tags mark unresolved tracker quests with D")
  Q:ShowQuestTooltip(Q.tracker.rows[1],Q.quests[1])
  expect(WorldMapTooltip:GetText():find("16D|r]",1,true),"dungeon quest tooltips share the level suffix")
  expect(Q:QuestTitle({key=Q.quests[1].key,title=dungeon.title,level=16}):find("16D|r]",1,true),"active tooltip groups resolve live dungeon tags through their key")
  expect(Q:QuestTitle({title="Stored dungeon",level=16,data={questType=81}}):find("16D|r]",1,true),"database dungeon types mark quests before acceptance")
  expect(Q:QuestTitle({id=99,title=arugal.title,level=15,tag="Dungeon"}):find("15D|r]",1,true),"live dungeon tags override stored elite types")
  expect(Q:QuestTitle({title="Live elite",level=16,questType=81,tag="Elite"}):find("16+|r]",1,true),"live elite tags override stored dungeon types")
  expect(not Q:QuestTitle({title="Live raid",level=16,questType=81,tag="Raid"}):find("16D",1,true),"live raid tags suppress stored dungeon suffixes")
  expect(Q:QuestTitle({title="Unknown level",tag="Dungeon"})=="Unknown level (Dungeon)","dungeon quests without a known level retain an explicit label")
  Q.GetMapZone=mapZone;WorldMapFrame:Hide();WorldMapTooltip:Hide()
  log=savedLog;selection=savedSelection;Q:ScanLog();Q:SetTrackerMode(savedMode)
end

local function questLevelAndRateTests(Q)
  local savedLog,savedSelection,savedLevel=log,selection,playerLevel
  local selected=QuestlineSettings.selected
  local beaks,hooves,mills,raptors=quest(844),quest(845),quest(426),quest(869)
  log={{title="Mixed levels",header=true,closed=true,quests={hooves,mills,beaks,raptors}}};selection=1
  QuestlineSettings.selected="845";Q:ScanLog();Q:SetTrackerMode("world")
  expect(Q.quests[1].id==426 and Q.quests[2].id==844 and Q.quests[3].id==845 and Q.quests[4].id==869,"tracker quests sort from lowest level to highest with stable log-order ties")
  expect(log[1].quests[1]==hooves and log[1].closed and selection==1,"level sorting never rearranges or expands the actual quest log")
  expect(QuestlineSettings.selected=="845" and Q.byKey["845"].number==3,"level sorting preserves selected quest identity and updates shared numbering")
  expect(Q:Normalize(Q.tracker.rows[1].title:GetText())=="[8] the mills overrun","normal tracker displays quest level before its title after the highlighted quest")
  SetMapZoom(1,1);WorldMapFrame:Show();Q:RefreshMap()
  expect(Q.mapTracker.rows[1].entry.id==844 and Q.mapTracker.rows[2].entry.id==845,"zone-filtered map tracker prioritizes highlights before other quests")
  local mapped
  for _,pin in ipairs(Q.mapPins) do if pin:IsShown() and pin.entry.id==845 then mapped=pin end end
  expect(mapped and mapped.text:GetText()=="3" and Q.mapTracker.rows[2].badge.text:GetText()=="3","World tracker, filtered map tracker, and map circle share the full-log quest number")
  playerLevel=12
  local expected={{18,"ff1919"},{15,"ff7f3f"},{12,"ffff00"},{8,"3fbf3f"},{1,"7f7f7f"}}
  for _,case in ipairs(expected) do
    expect(Q:QuestTitle({title="Keep this gold",level=case[1]})=="[|cff"..case[2]..case[1].."|r] Keep this gold","only the level number gets the expected fallback difficulty color")
  end
  expect(Q:QuestTitle({title="Unknown level"})=="Unknown level" and Q:QuestTitle({title="Unspecified",level=-1})=="Unspecified","unknown levels do not display invented numbers")
  local getter=GetDifficultyColor
  GetDifficultyColor=function(level) expect(level==8,"native Vanilla color API receives quest level");return {r=.2,g=.4,b=.6} end
  expect(Q:QuestTitle({title="Native colors",level=8})=="[|cff3366998|r] Native colors","native difficulty colors take precedence when provided by the client")
  GetDifficultyColor=getter
  playerLevel=14;arg1=14;fire("PLAYER_LEVEL_UP");tick(.2)
  expect(Q.tracker.rows[1].title:GetText():find("|cff7f7f7f8|r",1,true),"level-up events refresh difficulty colors in visible trackers")
  local unknown={title="Unknown",key="unknown",objectives={},summary=""}
  local lower={title="Lower",key="lower",level=2,objectives={},summary=""}
  Q:SetEntries({unknown,lower});expect(Q.quests[2]==unknown,"unidentified levels sort after numbered quests")

  local meat=quest(40535,{{text="Leg Meat: 1/2",kind="item"}})
  log={{title="Mulgore",header=true,quests={meat}}};selection=2;Q:ScanLog()
  local groups=Q:GetMobProgress("Adult Plainstrider")
  expect(groups[1].objectives[1].text=="Leg Meat (10%) - 1/2","mob progress rounds its drop percentage to the nearest whole number")
  expect(Q:GetMobProgress("Plainstrider")[1].objectives[1].text=="Leg Meat (17%) - 1/2","different mobs can show different rates for the same quest item")
  expect(Q.tooltipProgress['item:7097'][1].text=="Leg Meat - 1/2","per-mob display never mutates shared quest counters")
  local rates=QuestlineDB.mobDropRates['adult plainstrider'];local rate=rates['item:7097']
  rates['item:7097']=nil;expect(Q:GetMobProgress("Adult Plainstrider")[1].objectives[1].text=="Leg Meat - 1/2","unknown percentages are omitted without losing item progress")
  rates['item:7097']=100;expect(Q:GetMobProgress("Adult Plainstrider")[1].objectives[1].text=="Leg Meat (100%) - 1/2","integer percentages have no trailing decimal zeros")
  rates['item:7097']=12.5;expect(Q:GetMobProgress("Adult Plainstrider")[1].objectives[1].text=="Leg Meat (13%) - 1/2","half-percent values round upward")
  rates['item:7097']=12.49;expect(Q:GetMobProgress("Adult Plainstrider")[1].objectives[1].text=="Leg Meat (12%) - 1/2","values below half a percent round downward")
  rates['item:7097']=.0065;expect(Q:GetMobProgress("Adult Plainstrider")[1].objectives[1].text=="Leg Meat (0%) - 1/2","small known rates follow the same nearest-whole-percent rounding")
  rates['item:7097']=rate
  mouseoverName="Adult Plainstrider";mouseoverPlayer=false
  GameTooltip:SetText(mouseoverName);GameTooltip:AddLine(Q:QuestTitle(Q.quests[1]));GameTooltip:AddLine("  Leg Meat (10%) - 1/2");GameTooltip:Show();Q:RefreshMobTooltip()
  expect(GameTooltip:NumLines()==3,"existing groups with colored level prefixes and percentage labels are not duplicated")
  log=savedLog;selection=savedSelection;playerLevel=savedLevel;QuestlineSettings.selected=selected;Q:ScanLog()
  mouseoverName=nil;GameTooltip:Hide();WorldMapFrame:Hide()
end

local function completedTooltipSortTests(Q)
  local original=Q.quests
  local DB=QuestlineDB
  local name,key="completed tooltip sort fixture","item:tooltip-sort-fixture"
  local objectIndex=DB.objectObjectives
  DB.objectObjectives=objectIndex or {}
  DB.mobObjectives[name]={key};DB.objectObjectives[name]={key};DB.vendorObjectives[name]={key}
  local target={kind="item",key=key,name="Tooltip sort item"}
  local entries={}
  for index=1,3 do
    entries[index]={key="tooltip-sort-"..index,title="Tooltip sort "..index,level=index*10,
      data={objectives={target},finishers={}},objectives={{text="Tooltip sort item: 0/1",kind="item",done=false}}}
  end
  for _,state in ipairs({"unfinished","mixed","completed","single"}) do
    for index,entry in ipairs(entries) do
      entry.complete=state=="completed" or state=="single" or (state=="mixed" and index==2)
      entry.objectives[1].done=entry.complete
      entry.objectives[1].text=entry.complete and "Tooltip sort item: 1/1" or "Tooltip sort item: 0/1"
    end
    local count=state=="single" and 1 or 3
    if count==1 then Q:SetEntries({entries[2]}) else Q:SetEntries({entries[3],entries[1],entries[2]}) end
    local sources={Q:GetMobProgress(name),Q:GetMobProgress(name,true),Q:GetVendorProgress(name)}
    for _,groups in ipairs(sources) do
      expect(#groups==count,"mob, object, and vendor tooltips retain every "..state.." quest")
      for index,group in ipairs(groups) do
        local entry=Q.quests[index]
        expect(group.key==entry.key,"tooltip groups follow level-sorted quest order with "..state.." quests")
        expect(group.number==entry.number and (not entry.complete or group.number==nil),"tooltip sorting preserves compact badge numbers and unnumbered completed quests")
        expect(group.objectives[1].done==entry.complete,"completed tooltip objectives retain their live status")
      end
    end
  end
  DB.mobObjectives[name]=nil;DB.objectObjectives[name]=nil;DB.vendorObjectives[name]=nil
  DB.objectObjectives=objectIndex
  Q:SetEntries(original)
end

local function areaAnchorTests(Q)
  local original=Q.quests
  local point={key="anchor-point",name="Specialty supply",kind="item",icon="loot"}
  local area={key="anchor-area",name="Hunting target",kind="item",icon="loot"}
  QuestlineDB.locations[point.key]={[17]={points={{5,60}},runs="",anchor={5,60},spawns=1}}
  QuestlineDB.locations[area.key]={[17]={points={},runs="01010A",anchor={60,50},spawns=100}}
  local entry={key="anchor-test",id=980100,title="Area anchor",level=8,objectives={},data={objectives={point,area},finishers={point}}}
  Q:SetEntries({entry});SetMapZoom(1,1);WorldMapFrame:Show();Q.mapDirty=true;Q:RefreshMap()
  expect(math.abs(Q.mapPins[1].point[4]-WorldMapButton:GetWidth()*.6)<.001,"badge prefers the hunting area's center over the first point objective")
  entry.complete=true;Q.mapDirty=true;Q:RefreshMap()
  expect(math.abs(Q.mapPins[1].point[4]-WorldMapButton:GetWidth()*.05)<.001,"completed quest keeps its exact turn-in anchor")
  local vendor={key="anchor-vendors",name="Vendor supply",kind="item",icon="buy"}
  local turnin={key="anchor-turnin",name="Turn-in NPC",kind="unit",icon="turnin"}
  QuestlineDB.locations[vendor.key]={[17]={points={{5,60},{61,52.4},{90,20}},pointKinds={"v","v","v"},runs="",anchor={5,60},spawns=3}}
  QuestlineDB.locations[turnin.key]={[17]={points={{60,52}},runs="",anchor={60,52},spawns=1}}
  local vendorEntry={key="vendor-anchor-test",id=980101,title="Vendor anchor",level=8,objectives={{text="Vendor supply: 0/1",done=false}},data={objectives={vendor},finishers={turnin}}}
  local closest=Q:ClosestVendorAnchor(vendorEntry,vendor,QuestlineDB.locations[vendor.key][17],17)
  expect(closest[1]==61 and closest[2]==52.4,"vendor-only quests anchor beside the supplier closest to their turn-in")
  QuestlineDB.locations[point.key]=nil;QuestlineDB.locations[area.key]=nil
  QuestlineDB.locations[vendor.key]=nil;QuestlineDB.locations[turnin.key]=nil
  Q:SetEntries(original);WorldMapFrame:Hide()
end

local function multiSelectionTests(Q)
  local original,oldSelected,oldKeys=Q.quests,QuestlineSettings.selected,QuestlineSettings.selectedKeys
  local oldControl,oldMode=IsControlKeyDown,QuestlineSettings.trackerMode
  local ctrl=false;IsControlKeyDown=function() return ctrl end
  local entries,targets={},{}
  local alphabet="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"
  local function coord(n) return alphabet:sub(math.floor(n/64)+1,math.floor(n/64)+1)..alphabet:sub(n%64+1,n%64+1) end
  for i=1,12 do
    local key="multi-target:"..i
    local zone=i==11 and 14 or 17
    local runs=""
    if i<9 then for y=100+i*12,103+i*12 do runs=runs..coord(y)..coord(100+i*15)..coord(110+i*15) end end
    QuestlineDB.locations[key]={[zone]={runs=runs,points=i>=9 and {{50,50}} or {},anchor={20+i*4,30}}}
    targets[i]={key=key,name="Objective "..i,kind="unit",icon="kill"}
    entries[i]={key="multi:"..i,id=980000+i,title="Multi "..i,level=math.ceil(i/2),summary="",objectives={},data={objectives={targets[i]},finishers={targets[9] or targets[i]}}}
  end
  entries[10].data.objectives={targets[9]} -- A shared point must not create duplicate icons.
  entries[12].data=nil;entries[12].id=nil;entries[12].level=nil
  QuestlineSettings.selectedKeys=nil;QuestlineSettings.selected="multi:1"
  SetMapZoom(1,1);playerZone="The Barrens";Q:SetEntries(entries);Q:SetTrackerMode("world");WorldMapFrame:Show();Q:RefreshMap()
  local function pin(i)
    for _,p in ipairs(Q.mapPins) do if p:IsShown() and p.entry.key=="multi:"..i then return p end end
    error("Missing map pin "..i)
  end
  local function row(panel,i)
    for page=1,panel.pages do
      panel.page=page;Q:RefreshTrackers()
      for _,r in ipairs(panel.rows) do if r:IsShown() and r.entry.key=="multi:"..i then return r end end
    end
    error("Missing tracker row "..i)
  end
  local function selectedCount()
    local n=0;for _,entry in ipairs(Q.quests) do if Q:IsSelected(entry.key) then n=n+1 end end;return n
  end
  local function visibleCount(pool)
    local n=0;for _,item in ipairs(pool) do if item:IsShown() then n=n+1 end end;return n
  end
  expect(Q:IsSelected("multi:1") and selectedCount()==1,"old single-selection settings work before the first Ctrl-click")
  ctrl=true;click(pin(8))
  expect(selectedCount()==2 and Q:IsSelected("multi:1") and Q:IsSelected("multi:8"),"Ctrl-click on a map circle extends the existing highlight")
  expect(Q.tracker.page==1 and Q.mapTracker.page==1 and Q.tracker.rows[2].entry.key=="multi:8","selection resets both trackers to highlighted quests on page one")
  expect(pin(1).glow:IsShown() and pin(8).glow:IsShown() and not pin(2).glow:IsShown(),"all selected map badges glow and other badges remain unselected")
  expect(visibleCount(Q.fills)==2,"two separated selected areas render together")
  click(row(Q.mapTracker,2).badge)
  expect(selectedCount()==3 and Q.tracker.rows[2].entry.key=="multi:2" and Q.tracker.rows[3].entry.key=="multi:8","map tracker Ctrl-click preserves level order within highlights, including tied levels")
  WorldMapFrame:Hide();click(row(Q.tracker,9))
  expect(selectedCount()==4 and Q:IsSelected("multi:9"),"outside-map tracker rows support Ctrl-click")
  click(row(Q.tracker,8).badge)
  expect(selectedCount()==3 and not Q:IsSelected("multi:8"),"Ctrl-click on an already selected tracker badge removes just that quest")
  WorldMapFrame:Show();Q:RefreshMap()
  expect(visibleCount(Q.fills)==2 and visibleCount(Q.objectivePins)==1,"remaining blue areas and a selected single-point action icon coexist")
  click(pin(10))
  expect(selectedCount()==4 and visibleCount(Q.objectivePins)==1,"shared single-point objectives use one action icon while both quest circles remain highlighted")
  for _,entry in ipairs(Q.quests) do expect(entry.number==tonumber(entry.key:sub(7)),"highlight changes preserve shared map and tracker numbers") end
  local layout=Q.areaLayoutKey;local widgetCount=#widgets
  Q.mapDirty=true;Q:RefreshMap()
  expect(Q.areaLayoutKey==layout and #widgets==widgetCount,"unchanged multi-selection reuses area layout and UI objects")
  for _,i in ipairs({8,7,6}) do click(pin(i)) end
  local ordered=Q:GetTrackerEntries()
  expect(selectedCount()==7 and ordered[1].key=="multi:1" and ordered[3].key=="multi:6" and ordered[7].key=="multi:10" and ordered[8].key=="multi:3","more than five highlights sort first by level before the remaining quests")
  click(Q.tracker.next)
  expect(Q.tracker.rows[1].entry.key=="multi:9" and Q.tracker.rows[1].glow:IsShown() and not Q.tracker.rows[3].glow:IsShown(),"highlighted overflow continues on page two ahead of unselected quests in the default transparent style")
  click(row(Q.tracker,12))
  expect(Q:IsSelected("multi:12") and Q.tracker.rows[5].entry.key=="multi:8","unmapped quests can join a highlighted group and unknown levels sort last within it")
  click(row(Q.tracker,11))
  Q:SetTrackerMode("zone")
  local scoped=Q:GetTrackerEntries()
  expect(#scoped==10 and not Q:HasZone(Q.byKey["multi:11"],17) and Q:IsSelected("multi:11") and Q:IsSelected("multi:12"),"Zone mode filters off-zone and unmapped highlights without deselecting them")
  SetMapZoom(1,2);Q.mapDirty=true;Q:RefreshMap()
  expect(Q.mapTracker.rows[1].entry.key=="multi:11" and pin(11).glow:IsShown() and #Q:GetTrackerEntries()==10,"browsing another map displays its highlighted quests without changing the physical-zone tracker")
  SetMapZoom(1,1);Q.mapDirty=true;Q:RefreshMap();Q:SetTrackerMode("world")
  local count=selectedCount();local oldAction=Q.QuestLogAction;local action
  Q.QuestLogAction=function(self,entry,open) action=open and "open" or "link" end
  shiftDown=true;ChatFrameEditBox:Show();click(row(Q.tracker,3))
  expect(action=="link" and selectedCount()==count and not Q:IsSelected("multi:3"),"Shift-chat linking takes precedence over Ctrl and preserves the highlighted set")
  click(row(Q.mapTracker,3),"RightButton")
  expect(action=="open" and selectedCount()==count,"right-click keeps opening the quest log without changing multiple highlights")
  Q.QuestLogAction=oldAction;shiftDown=false;ChatFrameEditBox:Hide()
  entries[9].complete=true;Q:SetEntries(entries);Q:RefreshMap()
  expect(Q:IsSelected("multi:9") and pin(9).text:GetText()=="?" and pin(9).glow:IsShown(),"quest completion preserves its highlight and uses the turn-in marker")
  local remaining={};for _,entry in ipairs(entries) do if entry.key~="multi:1" then table.insert(remaining,entry) end end
  Q:SetEntries(remaining);Q:RefreshMap()
  expect(not Q:IsSelected("multi:1") and Q:IsSelected("multi:2") and Q:IsSelected("multi:9"),"removing a selected quest prunes only that quest from saved highlights")
  local savedSet={};for key,value in pairs(QuestlineSettings.selectedKeys) do savedSet[key]=value end
  QuestlineSettings.selectedKeys=savedSet;QuestlineSettings.selected=nil;Q:SetEntries(remaining)
  expect(selectedCount()==count-1 and Q:IsSelected("multi:12"),"saved multi-selection restores by quest key on a fresh quest-log snapshot")
  Q:ShowQuestTooltip(row(Q.tracker,2),Q.byKey["multi:2"])
  ctrl=false;click(pin(3))
  expect(selectedCount()==1 and Q:IsSelected("multi:3") and Q:GetTrackerEntries()[1].key=="multi:2","normal map click replaces the group with one highlighted quest at the front")
  expect(not Q.partyQuestTooltip and not WorldMapTooltip:IsShown(),"moving tracker rows clears their stale tooltip and party hover refresh")
  ctrl=true;click(pin(8));ctrl=false;click(row(Q.mapTracker,7).badge)
  expect(selectedCount()==1 and Q:IsSelected("multi:7"),"normal map tracker click replaces a multi-selection")
  ctrl=true;click(pin(3));ctrl=false;WorldMapFrame:Hide();click(row(Q.tracker,10))
  expect(selectedCount()==1 and Q:IsSelected("multi:10"),"normal outside-map tracker click replaces a multi-selection")
  WorldMapFrame:Show();Q:RefreshMap();ctrl=true;click(Q.objectivePins[1])
  expect(selectedCount()==0 and visibleCount(Q.fills)==0 and visibleCount(Q.edges)==0 and visibleCount(Q.objectivePins)==0,"Ctrl-clicking the last selected action icon clears all highlights and map helpers")
  Q:SetEntries(remaining);Q:RefreshMap()
  expect(selectedCount()==0,"an intentionally empty selection survives quest-log updates")
  QuestlineSettings.selectedKeys={};QuestlineSettings.selected=nil;Q:SetEntries(remaining)
  expect(selectedCount()==0,"saved empty selection stays empty when restored")
  ctrl=false;click(pin(8))
  expect(selectedCount()==1 and Q:IsSelected("multi:8"),"normal click restores one highlight from an empty selection")
  Q.tracker.page=3;Q.mapTracker.page=2;Q:RefreshTrackers()
  local clicked=Q.tracker.rows[1].entry.key
  click(Q.tracker.rows[1])
  expect(Q:IsSelected(clicked) and Q.tracker.page==3 and Q.mapTracker.page==2 and Q.tracker.rows[1].entry.key==clicked,"normal tracker click on page three preserves both trackers' pages and row order")
  click(pin(7))
  expect(Q:IsSelected("multi:7") and Q.tracker.page==3 and Q.mapTracker.page==2,"normal map circle click preserves independently browsed tracker pages")
  clicked=Q.mapTracker.rows[1].entry.key;click(Q.mapTracker.rows[1].badge)
  expect(Q:IsSelected(clicked) and Q.mapTracker.page==2 and Q.tracker.page==3,"normal map tracker badge click keeps pagination unchanged")
  IsControlKeyDown=oldControl;QuestlineSettings.selected=oldSelected;QuestlineSettings.selectedKeys=oldKeys
  QuestlineSettings.trackerMode=oldMode
  for _,target in ipairs(targets) do QuestlineDB.locations[target.key]=nil end
  Q:SetEntries(original);Q:RefreshMap();WorldMapFrame:Hide();Q:RefreshTrackers()
end

local function partySyncTests(Q)
  local savedLog,savedSelection,savedParty=log,selection,Q.party
  local oldName,oldCount,oldRaid,oldConnected,oldShared,oldSend,oldMouse=UnitName,GetNumPartyMembers,GetNumRaidMembers,UnitIsConnected,IsUnitOnQuest,SendAddonMessage,MouseIsOver
  local roster={"Alice","Bob"};local connected={Alice=true,Bob=true,Tester=true};local who="Tester";local raid=0
  local sent={};local hovered
  UnitName=function(unit)
    if unit=="player" then return who end
    local _,_,index=string.find(unit,"^party(%d+)$")
    if index then return roster[tonumber(index)] end
    return oldName(unit)
  end
  GetNumPartyMembers=function() return #roster end;GetNumRaidMembers=function() return raid end
  UnitIsConnected=function(unit) return connected[UnitName(unit)] end
  IsUnitOnQuest=function(index,unit)
    local q=visible()[index];assert(q and not q.header,"shared quest lookup used a header or stale log index")
    return q.id==40535 or q.id==426
  end
  SendAddonMessage=function(p,message,channel) table.insert(sent,{prefix=p,message=message,channel=channel,time=now}) end
  MouseIsOver=function(frame) return frame==hovered end
  local function pump(seconds)
    for i=1,math.ceil(seconds/.3) do now=now+.3;Q:UpdatePartySync() end
  end
  local function receive(message,sender,channel,p)
    arg1=p or "QL_P1";arg2=message;arg3=channel or "PARTY";arg4=sender or "Alice";fire("CHAT_MSG_ADDON")
  end
  local function deliver(id,body,sequence,session)
    local messages=Q:PartyPackets(id,body,sequence,session or "alice-one")
    for _,message in ipairs(messages) do receive(message) end
  end
  local function remote(id,objectives,complete)
    return Q:PartyQuestBody({id=id,objectives=objectives,complete=complete})
  end
  local function findLine(text)
    for i=1,GameTooltip:NumLines() do local line=_G["GameTooltipTextLeft"..i];if line:IsShown() and line:GetText()==text then return line end end
  end
  local function hover(name)
    mouseoverName=name;mouseoverPlayer=false;GameTooltip:SetOwner(UIParent,"ANCHOR_NONE");GameTooltip:SetText(name);GameTooltip:AddLine("Level 7");GameTooltip:Show();Q:RefreshMobTooltip()
  end
  local meat=quest(40535,{{text="Leg Meat: 1/2",kind="item"}})
  local mills=quest(426,{{text="Notched Rib: 0/5",kind="item"},{text="Blackened Skull: 1/3",kind="item"}})
  log={{title="Party quests",header=true,closed=true,quests={meat,mills}}};selection=1;Q.party=nil
  fire("PARTY_MEMBERS_CHANGED");Q:ScanLog();pump(3)
  local entry=Q.byKey["40535"]
  expect(entry.partyMembers.Alice and entry.partyMembers.Bob and log[1].closed and selection==1,"native shared-quest checks run against expanded live indices and preserve log state")
  expect(#sent>=4 and sent[1].message:find("^H\t"),"joining a party sends a handshake followed by a quest snapshot")
  for index,message in ipairs(sent) do
    expect(message.prefix=="QL_P1" and message.channel=="PARTY" and #message.prefix+#message.message+1<=254,"wire messages use only the party channel and fit Vanilla's byte limit")
    if index>1 then expect(message.time-sent[index-1].time>=.25,"outgoing packets are throttled") end
  end
  local count=#sent;pump(3);expect(#sent==count,"unchanged quest logs produce no repeated counter traffic")

  -- A second endpoint receives actual emitted packets, using the same runtime.
  local senderState=Q.party;Q.party=nil
  local receiver=setmetatable({quests={},byKey={}}, {__index=Q});receiver:EnsurePartyState();Q.party=senderState
  who="Alice";roster={"Tester"}
  for _,message in ipairs(sent) do receiver:ReceivePartyMessage(message.message,message.channel,"Tester") end
  expect(receiver.party.peers.Tester.quests[40535].objectives['item\tleg meat'].current==1,"a second endpoint reconstructs the sender's quest counters")
  expect(receiver.party.peers.Tester.quests[426].objectives['item\tnotched rib'].required==5,"full snapshot includes every accepted identified quest")
  local queuedBody=receiver:PartyQuestBody({id=40535,objectives={{text="Leg Meat: 0/2",kind="item"}}})
  for _,message in ipairs(receiver:PartyPackets(0,"40535,426",30,senderState.session)) do receiver:ReceivePartyMessage(message,"PARTY","Tester") end
  for _,message in ipairs(receiver:PartyPackets(40535,queuedBody,29,senderState.session)) do receiver:ReceivePartyMessage(message,"PARTY","Tester") end
  expect(receiver.party.peers.Tester.quests[40535].objectives['item\tleg meat'].current==0,"a newer manifest does not discard an older queued update for an included quest")
  who="Tester";roster={"Alice","Bob"};Q:RefreshPartyRoster()

  local body=remote(40535,{{text="Leg Meat: 0/2",kind="item"}})
  receive("H\talice-one");deliver(0,"40535,426",1);deliver(40535,body,2)
  hover("Adult Plainstrider")
  expect(findLine("  Leg Meat (10%)") and findLine("    You: 1/2") and findLine("    Alice: 0/2"),"mob tooltip groups local and synchronized party counts beneath its item and drop rate")
  local savedColors=RAID_CLASS_COLORS
  RAID_CLASS_COLORS={WARRIOR={r=.78,g=.61,b=.43}}
  Q:RefreshMobTooltip()
  expect(findLine("    |cffc79c6eAlice|r: 0/2"),"only a synchronized party member's name receives the native class color")
  local classLines=Q:PartyStatusLines(entry,"")
  expect(classLines[1].text=="|cffc79c6eAlice|r: In progress","overall party status uses the same class-colored name")
  RAID_CLASS_COLORS={};Q:RefreshMobTooltip()
  expect(findLine("    Alice: 0/2"),"unknown class colors fall back to a plain member name")
  RAID_CLASS_COLORS=savedColors
  expect(not findLine("    Bob: On this quest; progress unavailable"),"non-addon members are omitted from the tooltip")
  local lines=GameTooltip:NumLines();Q:RefreshMobTooltip();expect(GameTooltip:NumLines()==lines,"party progress refresh does not duplicate tooltip lines")
  deliver(40535,remote(40535,{{text="Leg Meat: 2/2",kind="item",done=true}},true),3);Q:RefreshMobTooltip()
  local completeLine=findLine("    Alice: 2/2")
  expect(completeLine and completeLine.color[2]>completeLine.color[1],"remote completed objectives show full counts in green while still hovering")
  mouseoverName=nil;GameTooltip:FadeOut();local shows=GameTooltip.showCalls;Q:RefreshMobTooltip()
  expect(findLine("    Alice: 2/2") and GameTooltip.fading and GameTooltip.showCalls==shows,"party details persist through the existing unit-tooltip fade")

  local long=string.rep("Explore this 100% place ",15)
  local multibody=remote(426,{{text="Blackened Skull: 3/3",kind="item",done=true},{text="Notched Rib: 4/5",kind="item"},{text=long,kind="event"}})
  local packets=Q:PartyPackets(426,multibody,4,"alice-one")
  expect(#packets>1,"long objective text is split into bounded packets")
  receive(packets[#packets]);expect(not Q.party.peers.Alice.quests[426],"partial quest update never exposes incomplete counters")
  for i=#packets-1,1,-1 do receive(packets[i]) end
  local sharedLines=Q:PartyObjectiveLines(Q.byKey['426'],1,"Notched Rib - 0/5",false,"")
  expect(sharedLines[3].text=="  Alice: 4/5","objectives match by type and text even when the other player's objective order differs")
  expect(Q.party.peers.Alice.quests[426].objectives['event\t'..Q:Normalize(long)],"escaped percent signs survive fragmented transport")
  local interrupted=Q:PartyPackets(426,multibody,5,"alice-one")
  receive(interrupted[1]);receive(interrupted[1])
  expect(Q.party.peers.Alice.pending[426].count==1,"duplicate fragments do not advance incomplete records")
  pump(16)
  expect(not Q.party.peers.Alice.pending[426] and Q.party.peers.Alice.revisions[426]==4,"interrupted fragments expire without replacing the last complete record")
  for _,message in ipairs(interrupted) do receive(message) end
  expect(Q.party.peers.Alice.revisions[426]==5,"a complete resend repairs an interrupted record")
  local oldQuest=Q.party.peers.Alice.quests[40535]
  receive(Q:PartyPackets(40535,body,2,"alice-one")[1]);expect(Q.party.peers.Alice.quests[40535]==oldQuest,"out-of-order older updates cannot replace newer progress")
  receive("D\tbogus\t0\t40535\t1\t99\tx")
  expect(Q.party.peers.Alice.session=="alice-one" and Q.party.peers.Alice.quests[40535]==oldQuest,"malformed headers cannot reset a valid peer session")
  local message=Q:PartyPackets(40535,body,5,"alice-one")[1]
  receive(message,"Stranger");receive(message,"Alice","RAID");receive(message,"Alice","PARTY","AnotherAddon")
  expect(not Q.party.peers.Stranger and Q.party.peers.Alice.quests[40535]==oldQuest,"non-members, non-party channels and other prefixes are ignored")
  expect(not Q:ParsePartyQuest("A\nitem\tfoo\tbad\t2\t1") and not Q:ParsePartyQuest("A\nitem\tfoo\t1\t0\t1"),"invalid counters and zero required counts are rejected")
  local duplicate=Q:ParsePartyQuest("A\nitem\tfoo\t1\t2\t0\nitem\tfoo\t2\t2\t1")
  expect(duplicate and duplicate.objectives['item\tfoo']==false,"ambiguous duplicate objective labels are not matched by position")
  deliver(40535,remote(40535,{{text="Leg Meat: 1/3",kind="item"}}),6)
  expect(#Q:PartyObjectiveLines(entry,1,"Leg Meat - 1/2",false,"")==1,"different required counts are not presented as matching objectives")
  deliver(40535,body,7);now=now+91
  expect(#Q:PartyObjectiveLines(entry,1,"Leg Meat - 1/2",false,"")==1,"expired counters quietly return to the compact local objective")
  deliver(40535,body,8)
  expect(Q:PartyObjectiveLines(entry,1,"Leg Meat - 1/2",false,"")[3].text=="  Alice: 0/2","a fresh synchronization restores current counters")
  connected.Alice=false;Q:RefreshPartyRoster()
  expect(#Q:PartyObjectiveLines(entry,1,"Leg Meat - 1/2",false,"")==1,"disconnected members do not add placeholder rows")
  connected.Alice=true;Q:RefreshPartyRoster()
  expect(#Q:PartyObjectiveLines(entry,1,"Leg Meat - 1/2",false,"")==1,"reconnecting does not revive counters from before disconnect")
  deliver(0,"40535,426",10);deliver(40535,body,11)
  deliver(0,"426",12)
  local members=Q:GetPartyQuestMembers(entry)
  expect(#members==0,"remote removal clears a quest even while native membership still reports it shared")
  deliver(40535,body,11);expect(not Q.party.peers.Alice.quests[40535],"old packets cannot resurrect a quest after its removal manifest")
  receive("H\talice-two");deliver(40535,remote(40535,{{text="Leg Meat: 2/2",kind="item",done=true}},true),1,"alice-two")
  expect(Q.party.peers.Alice.quests[40535].status=="C","addon reload begins a new session with fresh sequence numbers")
  deliver(40535,body,500,"alice-one")
  expect(Q.party.peers.Alice.session=="alice-two" and Q.party.peers.Alice.quests[40535].status=="C","late packets from a retired session are ignored")

  WorldMapFrame:Hide();GameTooltip:Hide();hovered=Q.tracker.rows[1]
  Q:ShowQuestTooltip(hovered,entry,nil,"Test Vendor")
  expect(findLine("  Alice: 2/2") and findLine("  You: 1/2"),"tracker quest tooltip also shows synchronized objective counts")
  deliver(40535,body,2,"alice-two");pump(1.2)
  expect(findLine("  Alice: 0/2"),"party changes refresh an actively hovered tracker tooltip")
  expect(GameTooltipTextLeft1:GetText()=="Test Vendor","party refresh preserves the NPC-first tooltip header")
  hovered=nil;entry.complete=true;Q:ShowQuestTooltip(Q.tracker.rows[1],entry)
  expect(findLine("  Alice: In progress") and findLine("Party"),"turn-in tooltip shows other members' overall quest status")
  entry.complete=false;GameTooltip:Hide()

  sent={};Q.party.force=false;Q.party.fullAt=now+60;Q.party.outbox={};Q.party.order={};Q.party.hello=false
  meat.objectives[1].text="Leg Meat: 2/2";Q:ScanLog();Q:BuildPartyOutbox()
  meat.objectives[1].text="Leg Meat: 1/2";Q:ScanLog();Q:BuildPartyOutbox();pump(2)
  expect(#sent==1 and sent[1].message:find("\t40535\t",1,true),"rapid objective changes coalesce into one current quest update without resending unrelated quests")
  sent={};now=Q.party.fullAt+.1;Q:UpdatePartySync();pump(3)
  expect(#sent>=3,"periodic snapshots repair missed packets and renew freshness")
  log[1].quests={meat};Q:ScanLog();sent={};pump(2)
  expect(#sent>=1 and sent[1].message:find("\t0\t",1,true),"abandoning a local quest sends a new manifest")
  roster={"Bob"};Q:RefreshPartyRoster();expect(not Q.party.peers.Alice,"leaving party immediately discards that member's remote data")
  roster={};fire("PARTY_MEMBERS_CHANGED");sent={};pump(2)
  expect(#sent==0 and not next(Q.party.peers) and #Q.party.order==0,"solo play clears remote state and queued traffic")
  roster={"Alice"};raid=10;Q:RefreshPartyRoster();pump(1)
  expect(#Q.party.members==0 and #sent==0,"party synchronization does not broadcast into raid groups")
  UnitName=oldName;GetNumPartyMembers=oldCount;GetNumRaidMembers=oldRaid;UnitIsConnected=oldConnected;IsUnitOnQuest=oldShared;SendAddonMessage=oldSend;MouseIsOver=oldMouse
  Q.party=savedParty;Q.partyQuestTooltip=nil;log=savedLog;selection=savedSelection;Q:ScanLog();mouseoverName=nil;GameTooltip:Hide()
end

-- Files are loaded by the JS harness between the stub setup and test body.
function runTests()
  local q844=quest(844,{{text="Plainstrider Beak: 0/7",kind="item"}})
  local q845=quest(845,{{text="Zhevra Hooves: 0/4",kind="item"}})
  local q895=quest(895,{{text="Baron Longshore's Head: 0/1",kind="item"}})
  local q900=quest(900,{{text="Shut off Main Control Valve: 0/1",kind="object"}})
  log={{title="The Barrens",header=true,closed=true,quests={q844,q845,q895,q900}},{title="Durotar",header=true,quests={quest(869,{},1)}}}
  selection=3 -- second header's quest in the collapsed view
  playerZone="Mulgore";fire("PLAYER_LOGIN");tick(.2)
  local Q=Questline
  expect(QuestlineSettings.mapTracker==false and not Q.mapTracker:IsShown(),"new settings hide the world-map tracker by default")
  Q:Command("maptracker on")
  expect(QuestlineSettings.nameplateBadges==true,"new settings enable nameplate badges by default")
  expect(QuestlineSettings.transparentTracker==true and Q.tracker.backdropColor[4]==0,"new settings default to the transparent HUD tracker")
  expect(Q.ready,"login initialized")
  expect(QuestlineSettings.trackerMode=="zone" and Q.tracker.heading:GetText()=="Quests - Mulgore","fresh characters start with their physical zone")
  playerZone="The Barrens";fire("ZONE_CHANGED_NEW_AREA")
  expect(#Q.quests==5,"collapsed headers included")
  expect(log[1].closed,"header collapse restored")
  expect(selection==3,"quest selection restored")
  expect(Q.byKey["900"]~=nil,"duplicate-title chain identified by quest text")
  expect(Q.byKey["844"]~=nil,"normal title resolved without GetQuestLink")
  expect(Q.byKey["869"].complete,"complete quest recognized")
  expect(not QuestWatchFrame:IsShown(),"legacy tracker suppressed")

  WorldMapFrame:Show();tick(.2);Q:Select("844")
  local visibleFills=0;for _,fill in ipairs(Q.fills) do if fill:IsShown() then visibleFills=visibleFills+1 end end
  expect(visibleFills>0,"Barrens area rendered")
  expect(#Q.mapPins>1,"clickable numbered markers created")
  expect(Q.mapPins[1].glow:IsShown() and not Q.mapPins[2].glow:IsShown(),"only selected quest badge glows")
  expect(Q.mapPins[1].texture.textureValue[1]:find("circle%-selected%-v2"),"selected badge uses gold-filled texture")
  expect(Q.mapPins[1].text.point[1]=="CENTER" and Q.mapPins[1].text.point[4]<Q.mapPins[2].text.point[4],"standalone 1 gets extra optical correction without shifting other numerals")
  click(Q.mapPins[2]);expect(QuestlineSettings.selected==Q.mapPins[2].entry.key,"map click changes shared selection")
  click(Q.mapTracker.rows[1].badge);expect(QuestlineSettings.selected==Q.mapTracker.rows[1].entry.key,"tracker circle changes selection")

  Q:Select("895")
  for _,fill in ipairs(Q.fills) do expect(not fill:IsShown(),"single target clears previous area") end
  expect(Q.objectivePins[1]:IsShown(),"single target action icon visible")
  expect(Q.objectivePins[1].point[4]~=Q.mapPins[3].point[4],"selector does not cover action icon")
  Q:Select("869")
  local completedPin
  for _,pin in ipairs(Q.mapPins) do if pin.entry.id==869 then completedPin=pin end end
  expect(completedPin and not completedPin.text:IsShown() and completedPin:GetWidth()==16 and completedPin.texture.textureValue[1]=="Interface\\AddOns\\Questline\\Textures\\quest-complete","completed quest uses bundled turn-in question mark without badge text")
  Q:Select("869")
  expect(completedPin.glow:IsShown() and completedPin.glow.textureValue[1]:find("turnin%-glow"),"highlighted turn-in uses blue glow")
  Q:Select(Q.mapPins[1].entry.key)
  expect(not completedPin.glow:IsShown(),"turn-in glow disappears when deselected")
  for _,pin in ipairs(Q.objectivePins) do expect(not pin:IsShown(),"completed quest has only turn-in selectors") end
  SetMapZoom(1,0);Q.mapDirty=true;Q:RefreshMap()
  for _,pin in ipairs(Q.mapPins) do expect(not pin:IsShown(),"continent map clears pins") end
  SetMapZoom(1,1);Q.mapDirty=true;Q:RefreshMap()
  WorldMapButton.scale=4;Q:RefreshMap()
  expect(Q.mapPins[1]:GetWidth()==6.25,"Magnify zoom keeps map markers a constant screen size")
  expect(Q.mapPins[1].glow:GetWidth()==9.75,"Magnify zoom keeps halo a constant screen size")
  expect(Q.mapPins[1].text.point[4]==-1.3/4,"standalone 1 correction scales with map zoom")
  WorldMapButton.scale=1;Q:RefreshMap()

  -- Only the selected quest's unfinished target contributes shading.
  local target=QuestlineDB.quests[844].objectives[1]
  local e=Q.byKey["844"]
  e.objectives={{text=target.name..": 7/7",kind="item",done=true}}
  expect(#Q:Targets(e)==0,"finished item objectives excluded")
  e.failed=true;expect(#Q:Targets(e)==0,"failed quest has no objectives")
  e.failed=false
  local data=QuestlineDB.quests[844]
  QuestlineDB.quests[999991]=data
  table.insert(Q.titleIndex[Q:Normalize(data.title)],999991)
  expect(Q:ResolveQuest(1,data.title,data.level,data.description,data.summary)==nil,"ambiguous matches are not guessed")
  table.remove(Q.titleIndex[Q:Normalize(data.title)]);QuestlineDB.quests[999991]=nil
  GetQuestLink=function() return "|Hquest:999992:12|h[Plainstrider Menace]|h" end
  expect(Q:ResolveQuest(1,data.title,data.level,data.description,data.summary)==nil,"unknown explicit ID does not match different ID")
  GetQuestLink=nil
  q844.complete=-1;now=now+1;Q:ScanLog();expect(Q.byKey["844"].failed and not Q.byKey["844"].complete,"negative completion means failed")

  local rows=Q:AreaRows({target,target},17)
  local rectangles=Q:AreaRectangles(rows)
  expect(#rectangles>0,"scanlines unioned into rectangles")
  local corners=Q:ContourPatches({[10]={{10,11}}})
  local masks={};for _,p in ipairs(corners) do masks[p[5]]=true end
  expect(#corners==4 and masks[1] and masks[2] and masks[4] and masks[8],"single-cell contour uses four rounded corners")
  local solidRows={};for y=10,19 do solidRows[y]={{10,20}} end
  local compact=Q:ContourPatches(solidRows)
  expect(#compact==9,"solid rectangle compresses to one interior plus eight border pieces")
  local areaA=Q:ContourPatches(Q:AreaRows({target},17))
  local areaB=Q:ContourPatches(Q:AreaRows({target,target},17))
  expect(#areaA==#areaB,"overlapping objectives do not duplicate contour tiles")
  for i,p in ipairs(areaA) do for k=1,5 do assert(p[k]==areaB[i][k],"overlap changed tile") end end
  Q:DrawAreas({target},17,1002,668)
  for _,edge in ipairs(Q.edges) do if edge:IsShown() then
    assert(edge.textureValue[1]:find("area%-contours"),"edge is a contour tile")
    assert(edge.texCoords[1]>=0 and edge.texCoords[2]<=1 and edge.texCoords[3]>=0 and edge.texCoords[4]<=1,"atlas coordinates out of range")
    assert(edge.point[4]>=0 and edge.point[5]<=0,"area extends beyond map origin")
  end end
  for y,spans in pairs(rows) do for i=2,#spans do expect(spans[i][1]>spans[i-1][2],"scanline intervals never overlap") end end
  local before=#widgets;Q:Select("845");local highwater=#widgets;Q.mapDirty=true;Q:RefreshMap();expect(#widgets==highwater,"unchanged geometry reuses UI objects")
  expect(Q.fills[1]:IsShown(),"cached area remains visible after an unchanged map refresh")
  expect(highwater>=before,"pool growth bounded by new area")
  Q:Command("tracker off");expect(QuestWatchFrame:IsShown(),"old tracker restored")

  -- pfQuest pins: existing/future nodes, explicit restore, no saved config writes.
  Q.minimapBlipsApplied=nil
  Q:ApplyCompatibility()
  expect(not Q.minimapBlipsApplied,"clients without SetBlipTexture remain supported")
  local blipCalls=0
  Minimap.SetBlipTexture=function(self,texture)
    blipCalls=blipCalls+1
    expect(texture=="Interface\\AddOns\\Questline\\Textures\\minimap-blips","native atlas replaced with turn-in-free texture")
  end
  Q:ApplyCompatibility();Q:ApplyCompatibility()
  expect(blipCalls==1,"native atlas applied once without repeated overrides")
  Minimap.SetBlipTexture=nil
  pfQuest_config={showspawn="1"}
  pfMap={pins={CreateFrame("Button",nil,WorldMapButton)}}
  function pfMap:BuildNode(name,parent) local pin=CreateFrame("Button",name,parent);return pin end
  function pfMap:UpdateNodes() for _,pin in ipairs(self.pins) do pin:Show() end end
  Q:ApplyCompatibility();expect(not pfMap.pins[1]:IsShown(),"existing pfQuest pin hidden")
  local newpin=pfMap:BuildNode(nil,WorldMapButton);newpin:Show();expect(not newpin:IsShown(),"future pfQuest pin hidden")
  Q:Command("legacy on");expect(pfMap.pins[1]:IsShown(),"legacy pins restored")
  expect(pfQuest_config.showspawn=="1","pfQuest saved setting unchanged")
  QuestlineSettings.trackerPosition={x=30,y=500};QuestlineSettings.mapPosition=nil
  Q:PositionTrackers();expect(Q.mapTracker.point[1]=="TOPRIGHT","HUD position is not reused for unset map position")
  -- Real progress arriving during synthetic header events is eventually refreshed.
  q844.complete=1;now=now+6;tick(.2)
  expect(Q.byKey["844"].complete,"collapsed-header fallback refresh catches completion")
  Q:Command("tracker on");trackerModeTests(Q)
  mobTooltipTests(Q)
  trackerClickTests(Q)
  npcQuestTests(Q)
  giverMapTests(Q)
  minimapScaleTests(Q)
  objectGiverTests(Q)
  giverClusterTests(Q)
  questLevelAndRateTests(Q)
  completedTooltipSortTests(Q)
  eliteQuestTests(Q)
  partySyncTests(Q)
  areaAnchorTests(Q)
  multiSelectionTests(Q)
  trackerResizeTests(Q)
  trackerMapTests(Q)
  completionHistoryTests(Q)
  availabilityRegressionTests(Q)
  starterFactionTests(Q)
  activePrerequisiteTests(Q)
  instantClassTurnInTests(Q)
  spawnDotTests(Q)
  objectTooltipTests(Q)
  requestedBehaviorTests(Q)
  blizzardNameplateTests(Q)
  vendorTooltipTests(Q)
  craftingHintTests(Q)
  vendorMapTooltipTests(Q)
  sourceMapTooltipTests(Q)
  QuestlineSettings.nameplateBadges=false
  Q:SetTrackerMode("world");Q.titleIndex={};fire("PLAYER_LOGIN");tick(.2)
  expect(QuestlineSettings.nameplateBadges==false,"login preserves a saved disabled nameplate badges preference")
  expect(QuestlineSettings.trackerMode=="world","login preserves an existing saved World preference")
  expect(QuestlineSettings.transparentTracker==false,"login preserves an explicitly saved bordered tracker preference")
  print("Runtime: "..checks.." assertions passed.")
end
