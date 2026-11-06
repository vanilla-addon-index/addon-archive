local Q,DB=Questline,QuestlineDB
local function label(parent,text,x,y,width)
  local f=parent:CreateFontString(nil,"OVERLAY")
  f:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",12,"")
  f:SetTextColor(.9,.88,.8);f:SetJustifyH("LEFT");f:SetJustifyV("TOP")
  f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);f:SetWidth(width);f:SetText(text)
  return f
end
local function button(parent,text,x,y,width,action)
  local b=CreateFrame("Button",nil,parent)
  b:SetWidth(width);b:SetHeight(24);b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
  b.text=label(b,text,0,0,width);b.text:SetTextColor(.55,.8,1)
  b:SetScript("OnClick",action)
  Q:StyleTextLink(b)
  return b
end
local function nativeButton(parent,text,x,y,width,action)
  local b=CreateFrame("Button",nil,parent,"OptionsButtonTemplate")
  b:SetWidth(width);b:SetHeight(22);b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);b:SetText(text)
  b:SetScript("OnClick",action)
  return b
end
local function checkbox(parent,name,text,description,x,y,action,labelWidth)
  local c=CreateFrame("CheckButton",name,parent,"OptionsCheckButtonTemplate")
  c:SetWidth(24);c:SetHeight(24);c:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
  c.label=label(parent,text,x+30,y-3,labelWidth or 390);c.label:SetTextColor(1,.82,.32)
  if description then
    c.description=label(parent,description,x+30,y-23,390);c.description:SetTextColor(.72,.72,.68)
  end
  c:SetScript("OnClick",action)
  return c
end
local function navigation(parent,text,y,section)
  local b=CreateFrame("Button",nil,parent)
  b:SetWidth(142);b:SetHeight(32);b:SetPoint("TOPLEFT",parent,"TOPLEFT",8,y)
  b.text=label(b,text,14,-8,120);b.text:SetTextColor(.9,.88,.8)
  b.selected=b:CreateTexture(nil,"BACKGROUND");b.selected:SetAllPoints(b);b.selected:SetTexture(.35,.27,.06,.75);b.selected:Hide()
  b.highlight=b:CreateTexture(nil,"HIGHLIGHT");b.highlight:SetAllPoints(b);b.highlight:SetTexture(.25,.22,.12,.45)
  b.section=section;b:SetScript("OnClick",function() Q:ShowOptionsSection(this.section) end)
  return b
end
local function window(name,parent,title,width,height)
  local f=CreateFrame("Frame",name,parent)
  f:SetWidth(width);f:SetHeight(height);f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:EnableMouse(true);f:SetMovable(true);f:SetClampedToScreen(true)
  f:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=12,insets={left=4,right=4,top=4,bottom=4}})
  f:SetBackdropColor(.025,.045,.065,.98)
  f.title=label(f,title,16,-14,width-60);f.title:SetTextColor(1,.82,.32)
  local close=CreateFrame("Button",nil,f);f.close=close
  close:SetWidth(18);close:SetHeight(18);close:SetPoint("TOPRIGHT",f,"TOPRIGHT",-16,-12)
  -- Same native artwork and crop used by Bagshui; no addon dependency.
  local up=close:CreateTexture(nil,"ARTWORK");up:SetAllPoints(close)
  up:SetTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up");up:SetTexCoord(.2,.75,.25,.75)
  local down=close:CreateTexture(nil,"ARTWORK");down:SetAllPoints(close)
  down:SetTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down");down:SetTexCoord(.2,.75,.25,.75)
  local hover=close:CreateTexture(nil,"HIGHLIGHT");hover:SetAllPoints(close)
  hover:SetTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight");hover:SetTexCoord(.2,.75,.25,.75);hover:SetBlendMode("ADD")
  close:SetNormalTexture(up);close:SetPushedTexture(down);close:SetHighlightTexture(hover)
  close:SetScript("OnClick",function() this:GetParent():Hide() end)
  f:RegisterForDrag("LeftButton");f:SetScript("OnDragStart",function() this:StartMoving() end)
  f:SetScript("OnDragStop",function() this:StopMovingOrSizing() end)
  f.rows={};f.page=1;return f
end
function Q:GetCompletionList(query,manualOnly)
  local list={};query=self:Normalize(query or "")
  for id,done in pairs(QuestlineSettings.completedQuests) do if done then
    local data=DB.quests[id];local source=QuestlineSettings.completionSources[id] or "Existing"
    if source=="Automatic" then source="Completed" end
    local title=data and data.title or ("Unknown quest "..id)
    if (not manualOnly or source=="Manual") and (query=="" or string.find(self:Normalize(title),query,1,true) or tostring(id)==query) then
      table.insert(list,{id=id,title=title,level=data and data.level,source=source})
    end
  end end
  table.sort(list,function(a,b)
    local al,bl=self:QuestLevel(a),self:QuestLevel(b)
    if al and bl and al~=bl then return al>bl end
    if al and not bl then return true end
    if bl and not al then return false end
    if a.title~=b.title then return a.title<b.title end
    return a.id<b.id
  end)
  return list
end
function Q:RefreshOptions()
  local f=self.optionsPanel;if not f then return end
  local list=self:GetCompletionList(f.search:GetText(),f.manualOnly)
  f.pages=math.max(1,math.ceil(table.getn(list)/12));f.page=math.max(1,math.min(f.page,f.pages))
  f.count:SetText(table.getn(list).." records  -  Page "..f.page.." / "..f.pages)
  f.filter:SetChecked(f.manualOnly and true or false)
  f.tracker:SetChecked(QuestlineSettings.tracker and true or false)
  f.mapTracker:SetChecked(QuestlineSettings.mapTracker~=false)
  f.spawns:SetChecked(QuestlineSettings.worldMapSpawns==true)
  f.nameplateBadges:SetChecked(QuestlineSettings.nameplateBadges~=false)
  f.bordered:SetChecked(QuestlineSettings.transparentTracker==false)
  local importing=self.serverQuestHistoryQuery and self.serverQuestHistoryQuery.active
  f.serverImport:EnableMouse(not importing)
  f.serverImport:SetAlpha(importing and .5 or 1)
  if f.section~="completed" then return end
  if table.getn(list)==0 then f.historyEmpty:Show() else f.historyEmpty:Hide() end
  for i=1,12 do
    local row=f.rows[i];local item=list[(f.page-1)*12+i]
    row.hover:Hide()
    if item then
      row.id=item.id;row.fullTitle=item.title
      row.title:SetText(self:QuestTitle(item));row:Show()
    else row.id=nil;row:Hide() end
  end
end
function Q:ToggleOptions()
  if self.optionsPanel and self.optionsPanel:IsShown() then self.optionsPanel:Hide();return end
  if not self.optionsPanel then
    local f=window("QuestlineOptions",UIParent,"Questline Options",720,520);self.optionsPanel=f
    f:SetPoint("CENTER",UIParent,"CENTER",0,0)
    f.title:ClearAllPoints();f.title:SetPoint("TOP",f,"TOP",0,-14);f.title:SetWidth(660);f.title:SetJustifyH("CENTER")
    f.sidebar=CreateFrame("Frame",nil,f);f.sidebar:SetWidth(160);f.sidebar:SetHeight(458);f.sidebar:SetPoint("TOPLEFT",f,"TOPLEFT",14,-46)
    f.sidebar:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
    f.sidebar:SetBackdropColor(.035,.035,.03,.96);f.sidebar:SetBackdropBorderColor(.42,.39,.30,.9)
    f.navigation={
      navigation(f.sidebar,"General",-10,"general"),
      navigation(f.sidebar,"Appearance",-46,"appearance"),
      navigation(f.sidebar,"Completed Quests",-82,"completed")
    }
    f.content=CreateFrame("Frame",nil,f);f.content:SetWidth(524);f.content:SetHeight(458);f.content:SetPoint("TOPLEFT",f,"TOPLEFT",182,-46)
    f.content:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
    f.content:SetBackdropColor(.018,.018,.015,.82);f.content:SetBackdropBorderColor(.42,.39,.30,.9)
    f.general=CreateFrame("Frame",nil,f.content);f.general:SetAllPoints(f.content)
    label(f.general,"General",18,-18,300):SetTextColor(1,.82,.32)
    f.tracker=checkbox(f.general,"QuestlineShowTracker","Show quest tracker","Display the main quest tracker on the HUD.",18,-54,function()
      Q:Command(QuestlineSettings.tracker and "tracker off" or "tracker on");Q:RefreshOptions()
    end)
    f.mapTracker=checkbox(f.general,"QuestlineShowMapTracker","Show tracker on world map","Display the quest list alongside the world map.",18,-112,function()
      Q:Command(QuestlineSettings.mapTracker~=false and "maptracker off" or "maptracker on");Q:RefreshOptions()
    end)
    f.spawns=checkbox(f.general,"QuestlineShowWorldMapSpawns","Show precise spawn markers","Show bag, sword, and gear markers for highlighted quests on the world map.",18,-170,function()
      QuestlineSettings.worldMapSpawns=not QuestlineSettings.worldMapSpawns
      Q.mapDirty=true;Q:RefreshMap();Q:RefreshOptions()
    end)
    f.nameplateBadges=checkbox(f.general,"QuestlineShowNameplateBadges","Show nameplate badges","Display quest number badges beside creatures' nameplates.",18,-228,function()
      QuestlineSettings.nameplateBadges=QuestlineSettings.nameplateBadges==false
      Q:RefreshNameplates();Q:RefreshOptions()
    end)
    nativeButton(f.general,"Reset Tracker Layout",48,-306,180,function() Q:Command("reset") end)
    f.appearance=CreateFrame("Frame",nil,f.content);f.appearance:SetAllPoints(f.content)
    label(f.appearance,"Appearance",18,-18,300):SetTextColor(1,.82,.32)
    f.bordered=checkbox(f.appearance,"QuestlineBorderedTracker","Bordered tracker","Add a background and border to the HUD tracker. Transparent mode is the default; the world-map tracker always stays bordered.",18,-54,function()
      QuestlineSettings.transparentTracker=not QuestlineSettings.transparentTracker
      Q:ApplyTrackerAppearance();Q:RefreshTrackers();Q:RefreshOptions()
    end)
    f.history=CreateFrame("Frame",nil,f.content);f.history:SetAllPoints(f.content)
    local h=f.history
    label(h,"Completed Quests",18,-18,190):SetTextColor(1,.82,.32)
    f.restoreAll=nativeButton(h,"Restore All",224,-14,104,function() Q:RestoreAllCompletedQuests() end)
    f.serverImport=nativeButton(h,"Import from Server",336,-14,170,function() Q:BeginServerQuestHistoryImport() end)
    label(h,"Search title / ID:",18,-58,100)
    f.search=CreateFrame("EditBox",nil,h);f.search:SetWidth(190);f.search:SetHeight(24)
    f.search:SetPoint("TOPLEFT",h,"TOPLEFT",120,-53);f.search:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",12,"")
    f.search:SetAutoFocus(false);f.search:SetMaxLetters(100)
    f.search:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=3,right=3,top=3,bottom=3}})
    f.search:SetBackdropColor(.1,.13,.16,1)
    f.search:SetScript("OnTextChanged",function() f.page=1;Q:RefreshOptions() end)
    f.search:SetScript("OnEscapePressed",function() this:ClearFocus() end)
    f.filter=checkbox(h,"QuestlineManualCompletions","Manually skipped only",nil,330,-53,function() f.manualOnly=not f.manualOnly;f.page=1;Q:RefreshOptions() end,146)
    f.filter.label:ClearAllPoints();f.filter.label:SetPoint("TOPLEFT",h,"TOPLEFT",360,-59)
    f.historyEmpty=label(h,"No entries to show",18,-225,488)
    f.historyEmpty:SetJustifyH("CENTER");f.historyEmpty:SetTextColor(.62,.66,.72)
    f.historyEmpty:Hide()
    for i=1,12 do
      local row=CreateFrame("Frame",nil,h);row:SetWidth(488);row:SetHeight(22);row:SetPoint("TOPLEFT",h,"TOPLEFT",18,-94-(i-1)*25)
      row.hover=row:CreateTexture(nil,"BACKGROUND");row.hover:SetAllPoints(row);row.hover:SetTexture(.08,.3,.5,.5);row.hover:Hide()
      row.title=label(row,"",4,-3,380);row.title:SetHeight(18);row.title:SetTextColor(1,.82,.32)
      row.restore=nativeButton(row,"Restore",402,0,82,function() Q:RestoreCompletedQuest(this:GetParent().id) end)
      row.restore:ClearAllPoints();row.restore:SetPoint("TOPRIGHT",row,"TOPRIGHT",0,0);row.restore:SetHeight(22)
      row.restore:SetScript("OnEnter",function() this:GetParent().hover:Show() end)
      row.restore:SetScript("OnLeave",function() this:GetParent().hover:Hide() end)
      row:EnableMouse(true)
      row:SetScript("OnEnter",function()
        if not this.id then return end
        this.hover:Show()
        GameTooltip:SetOwner(this,"ANCHOR_RIGHT");GameTooltip:SetText(this.fullTitle,1,.85,.4)
        GameTooltip:AddLine("Quest #"..this.id,.8,.85,.9);GameTooltip:Show()
      end)
      row:SetScript("OnLeave",function() this.hover:Hide();GameTooltip:Hide() end)
      f.rows[i]=row
    end
    f.count=label(h,"",100,-430,324)
    f.count:ClearAllPoints();f.count:SetPoint("BOTTOM",h,"BOTTOM",0,34);f.count:SetHeight(12);f.count:SetJustifyH("CENTER")
    f.previous=nativeButton(h,"<",18,-430,32,function() f.page=math.max(1,f.page-1);Q:RefreshOptions() end)
    f.next=nativeButton(h,">",474,-430,32,function() f.page=math.min(f.pages,f.page+1);Q:RefreshOptions() end)
    f.previous:ClearAllPoints();f.previous:SetPoint("LEFT",h,"BOTTOMLEFT",18,40)
    f.next:ClearAllPoints();f.next:SetPoint("RIGHT",h,"BOTTOMRIGHT",-18,40)
    h:EnableMouseWheel(true);h:SetScript("OnMouseWheel",function() f.page=math.max(1,math.min(f.pages,f.page-(arg1 or 0)));Q:RefreshOptions() end)
  end
  self:ShowOptionsSection(self.optionsPanel.section or "general");self.optionsPanel:Show()
end
function Q:ShowOptionsSection(section)
  local f=self.optionsPanel;f.section=section
  f.general:Hide();f.appearance:Hide();f.history:Hide();f.search:ClearFocus();GameTooltip:Hide()
  if section=="completed" then f.history:Show()
  elseif section=="appearance" then f.appearance:Show()
  else section="general";f.section=section;f.general:Show() end
  for _,item in ipairs(f.navigation) do
    local selected=item.section==section
    if selected then item.selected:Show();item.text:SetTextColor(1,.82,.32)
    else item.selected:Hide();item.text:SetTextColor(.9,.88,.8) end
  end
  self:RefreshOptions()
end
function Q:ShowCompletionMenu(pin,minimap)
  if minimap or not pin.giver then return end
  GameTooltip:Hide();WorldMapTooltip:Hide()
  if self.completionMenu then self.completionMenu:Hide() end
  local f=self.completionMenu
  if not f then
    f=window("QuestlineCompletionMenu",WorldMapFrame,"Mark quest completed",310,90);self.completionMenu=f
    f.dismiss=CreateFrame("Frame",nil,WorldMapFrame)
    f.dismiss:SetAllPoints(UIParent);f.dismiss:EnableMouse(true)
    f.dismiss:SetScript("OnMouseDown",function() f:Hide() end)
    f:SetScript("OnHide",function() f.dismiss:Hide() end)
    for i=1,6 do
      local b=button(f,"",22,-40,274,function()
        if Q:SetQuestCompleted(this.id,"Manual") then f:Hide();Q:RefreshQuestGivers() end
      end)
      f.rows[i]=b
    end
    f.count=label(f,"",50,-40,210);f.count:SetJustifyH("CENTER")
    f.previous=button(f,"<",14,-40,25,function() f.page=math.max(1,f.page-1);Q:RefreshCompletionMenu() end)
    f.next=button(f,">",271,-40,25,function() f.page=math.min(f.pages,f.page+1);Q:RefreshCompletionMenu() end)
    f.next.text:SetJustifyH("RIGHT")
  end
  local seen={};f.items={};f.page=1
  for _,giver in ipairs(self:GetNearbyGivers(pin,false)) do for _,quest in ipairs(giver.quests) do
    if quest.id and not seen[quest.id] and not self.byKey[tostring(quest.id)] then
      seen[quest.id]=true;table.insert(f.items,{id=quest.id,title=quest.title})
    end
  end end
  local level=WorldMapFrame:GetFrameLevel()+60
  f:SetFrameStrata("FULLSCREEN");f:SetFrameLevel(level)
  f.dismiss:SetFrameStrata("FULLSCREEN");f.dismiss:SetFrameLevel(level-1)
  -- Explicit child levels avoid stale levels after raising the pane above the map.
  f.close:SetFrameStrata("FULLSCREEN");f.close:SetFrameLevel(level+2)
  for _,row in ipairs(f.rows) do row:SetFrameStrata("FULLSCREEN");row:SetFrameLevel(level+1) end
  f.previous:SetFrameStrata("FULLSCREEN");f.previous:SetFrameLevel(level+1)
  f.next:SetFrameStrata("FULLSCREEN");f.next:SetFrameLevel(level+1)
  f:ClearAllPoints();f:SetPoint("TOPLEFT",pin,"BOTTOMRIGHT",0,0)
  self:RefreshCompletionMenu();f.dismiss:Show();f:Show()
end
function Q:RefreshCompletionMenu()
  local f=self.completionMenu;f.pages=math.max(1,math.ceil(table.getn(f.items)/6))
  local top=40
  for i=1,6 do
    local item=f.items[(f.page-1)*6+i];local row=f.rows[i]
    if item then
      row.id=item.id;row.text:SetText(item.title)
      local height=math.max(18,row.text:GetHeight())+6
      row:ClearAllPoints();row:SetPoint("TOPLEFT",f,"TOPLEFT",22,-top);row:SetHeight(height)
      top=top+height;row:Show()
    else row:Hide() end
  end
  f.count:Hide();f.previous:Hide();f.next:Hide()
  if table.getn(f.items)==0 or f.pages>1 then
    f.count:SetText(table.getn(f.items)==0 and "No identified quests to mark." or ("Page "..f.page.." / "..f.pages))
    f.count:ClearAllPoints();f.count:SetPoint("TOP",f,"TOP",0,-top);f.count:Show()
    if f.pages>1 then
      f.previous:ClearAllPoints();f.previous:SetPoint("TOPLEFT",f,"TOPLEFT",14,-top);f.previous:Show()
      f.next:ClearAllPoints();f.next:SetPoint("TOPRIGHT",f,"TOPRIGHT",-14,-top);f.next:Show()
    end
    top=top+24
  end
  f:SetHeight(top+10)
end
