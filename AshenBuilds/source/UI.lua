local AB=AshenBuilds
local qualityColors={[0]={0.62,0.62,0.62},[1]={1,1,1},[2]={0.12,1,0},[3]={0,0.44,0.87},[4]={0.64,0.21,0.93},[5]={1,0.5,0}}
local function MakeButton(parent,text,width,height) local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate"); b:SetWidth(width or 90); b:SetHeight(height or 22); b:SetText(text); AB:SkinButton(b,"ember"); return b end
local function MakeBackdrop(frame) AB:WindowBackdrop(frame) end
-- WoW's screen is only 768 units tall at UI scale 1.0, so the larger windows
-- shrink to fit on open and stay clamped on-screen while dragged.
function AB:FitToScreen(frame)
  if frame.embedded then return end
  local s=math.min(1,(UIParent:GetWidth()*0.96)/frame:GetWidth(),(UIParent:GetHeight()*0.94)/frame:GetHeight())
  frame:SetScale(s)
end

-- Clears keyboard focus from every EditBox inside a window. Not cached: windows
-- are hidden (firing OnHide) before their children are built.
local function ClearWindowFocus(frame)
  local kids={frame:GetChildren()}; local i
  for i=1,table.getn(kids) do if kids[i]:GetObjectType()=="EditBox" then kids[i]:ClearFocus() end; ClearWindowFocus(kids[i]) end
end

-- Brings a window in front of the other AshenBuilds windows and takes keyboard
-- focus away from text boxes in the windows behind it, so typing never lands
-- in a window you are no longer looking at.
function AB:FocusWindow(frame)
  if frame.embedded then frame=self.frame end
  if frame.Raise then frame:Raise() end
  local i,w
  for i=1,table.getn(self.windows) do w=self.windows[i]; if w~=frame then ClearWindowFocus(w) end end
end

-- Shared window behaviour:
--  * all windows share one strata so raising can put any of them in front
--    (toplevel also raises a window when anything inside it is clicked);
--  * draggable by any empty area and clamped on-screen;
--  * swallows the mouse wheel so scrolling never zooms the camera (scroll
--    frames inside still get the wheel first because they enable it themselves);
--  * registered with UISpecialFrames so Escape closes it.
-- opts.fit shrinks the window to fit the screen on open; opts.wheel handles scrolling.
function AB:SetupWindow(frame,opts)
  opts=opts or {}; self.windows=self.windows or {}; table.insert(self.windows,frame)
  frame:SetFrameStrata("DIALOG"); if frame.SetToplevel then frame:SetToplevel(true) end
  frame:EnableMouse(true); frame:SetMovable(true); frame:RegisterForDrag("LeftButton")
  if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
  frame:SetScript("OnMouseDown",function() AB:FocusWindow(this) end)
  frame:SetScript("OnDragStart",function() AB:FocusWindow(this); this:StartMoving() end)
  frame:SetScript("OnDragStop",function() this:StopMovingOrSizing() end)
  frame:SetScript("OnShow",function() if opts.fit then AB:FitToScreen(this) end; AB:FocusWindow(this); AB:FadeIn(this); if AB.UpdateModelMouse then AB:UpdateModelMouse() end end)
  frame:SetScript("OnHide",function() ClearWindowFocus(this); if AB.CloseDropdown then AB.CloseDropdown() end; if AB.UpdateModelMouse then AB:UpdateModelMouse() end end)
  frame:EnableMouseWheel(true); frame:SetScript("OnMouseWheel",opts.wheel or function() end)
  tinsert(UISpecialFrames,frame:GetName())
end
local function Cycle(list,current,delta) local i=AB.IndexOf(list,current)+delta; if i<1 then i=table.getn(list) elseif i>table.getn(list) then i=1 end; return list[i] end
local function F(n) if not n then return "0" end if math.floor(n)==n then return tostring(n) end return string.format("%.2f",n) end
local function Section(parent,title,y)
  local g=AB.THEME.gold
  local t=parent:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); t:SetPoint("TOPLEFT",parent,"TOPLEFT",12,y); t:SetText(title); t:SetTextColor(g[1],g[2],g[3])
  local line=parent:CreateTexture(nil,"ARTWORK"); local d=AB.THEME.divider; line:SetTexture(d[1],d[2],d[3],d[4]); line:SetPoint("TOPLEFT",parent,"TOPLEFT",10,y-13); line:SetPoint("RIGHT",parent,"RIGHT",-10,0); line:SetHeight(1)
end
local function StatLine(parent,left,right,y,color)
  local a=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); a:SetPoint("TOPLEFT",parent,"TOPLEFT",14,y); a:SetText(left); a:SetTextColor(.72,.78,.88)
  local b=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); b:SetPoint("TOPRIGHT",parent,"TOPRIGHT",-14,y); b:SetText(right or ""); if color then b:SetTextColor(color[1],color[2],color[3]) end
  return a,b
end

-- The game's own empty-slot art, as on the character sheet.
local EMPTY_ICON={HEAD="Head",NECK="Neck",SHOULDER="Shoulder",BACK="Chest",CHEST="Chest",SHIRT="Shirt",TABARD="Tabard",WRIST="Wrists",HANDS="Hands",WAIST="Waist",LEGS="Legs",FEET="Feet",
  FINGER1="Finger",FINGER2="Finger",TRINKET1="Trinket",TRINKET2="Trinket",MAINHAND="MainHand",OFFHAND="SecondaryHand",RANGED="Ranged"}
function AB:EmptySlotIcon(slot) return "Interface\\PaperDoll\\UI-PaperDoll-Slot-"..(EMPTY_ICON[slot] or "Chest") end

-- "+ Enchant" only appears while hovering a slot that could take one.
local function Over(f)
  local x,y=GetCursorPosition(); local s=f:GetEffectiveScale(); local l,r,t,bm=f:GetLeft(),f:GetRight(),f:GetTop(),f:GetBottom()
  if not (x and s and l and r and t and bm) then return false end
  x,y=x/s,y/s
  return x>=l and x<=r and y>=bm and y<=t
end
local function EnchantHint(b,show)
  if b.hasEnchant or not b.canEnchant then return end
  if show then b.enchantText:SetText("+ Enchant"); b.enchantText:SetTextColor(AB.THEME.gold[1],AB.THEME.gold[2],AB.THEME.gold[3]); b.enchantButton:Show()
  else b.enchantButton:Hide() end
end
-- Moving from the slot onto its "+ Enchant" line fires the slot's OnLeave first, so
-- the hint is only hidden once the mouse is over neither of them for a moment.
local function HintWatch()
  local b=this
  local focus=GetMouseFocus and GetMouseFocus()
  if GetMouseFocus then
    if focus==b or focus==b.enchantButton then b.hintHideAt=nil; return end
  elseif Over(b) then b.hintHideAt=nil; return end
  if not b.hintHideAt then b.hintHideAt=GetTime()+0.2 end
  if GetTime()>=b.hintHideAt then b.hintHideAt=nil; b:SetScript("OnUpdate",nil); EnchantHint(b,false) end
end
local function WatchHint(b) b.hintHideAt=nil; b:SetScript("OnUpdate",HintWatch) end

function AB:CreateGearSlot(parent,slot,x,y,side)
  local b=CreateFrame("Button",nil,parent); b:SetWidth(155); b:SetHeight(54); b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y); b.slot=slot
  AB:StylePanel(b,"slot")
  b:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
  local hl=b:GetHighlightTexture(); if hl then hl:ClearAllPoints(); hl:SetPoint("TOPLEFT",b,"TOPLEFT",3,-3); hl:SetPoint("BOTTOMRIGHT",b,"BOTTOMRIGHT",-3,3); hl:SetVertexColor(1,.45,.16,.1) end
  local anchor=side=="right" and "RIGHT" or "LEFT"
  -- Dark mat behind the icon, the icon itself (edges trimmed), and a quality glow over it.
  b.iconMat=b:CreateTexture(nil,"BORDER"); b.iconMat:SetTexture(0,0,0,.85); b.iconMat:SetWidth(44); b.iconMat:SetHeight(44); b.iconMat:SetPoint(anchor,b,anchor,side=="right" and -5 or 5,0)
  b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetWidth(40); b.icon:SetHeight(40); b.icon:SetPoint("CENTER",b.iconMat,"CENTER",0,0)
  b.glow=b:CreateTexture(nil,"OVERLAY"); b.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border"); b.glow:SetBlendMode("ADD"); b.glow:SetWidth(74); b.glow:SetHeight(74); b.glow:SetPoint("CENTER",b.iconMat,"CENTER",0,0); b.glow:Hide()
  local g=AB.THEME.gold
  b.label=b:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); b.label:SetPoint("TOP",b,"TOP",side=="right" and -25 or 25,-6); b.label:SetText(self.SLOT_LABELS[slot]); b.label:SetTextColor(g[1],g[2],g[3])
  -- One line only; long names are cut and shown in full in the tooltip.
  b.itemText=b:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); b.itemText:SetPoint("TOP",b.label,"BOTTOM",0,-3); b.itemText:SetWidth(98); b.itemText:SetHeight(12); b.itemText:SetJustifyH("CENTER")
  local eb=CreateFrame("Button",nil,b); eb:SetWidth(100); eb:SetHeight(13); eb:SetPoint("TOP",b.itemText,"BOTTOM",0,-2); eb.slot=slot; b.enchantButton=eb
  eb:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
  b.enchantText=eb:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); b.enchantText:SetAllPoints(eb); b.enchantText:SetJustifyH("CENTER")
  eb:SetScript("OnClick",function() AB:OpenEnchantBrowser(this.slot) end)
  eb:SetScript("OnEnter",function() GameTooltip:SetOwner(this,"ANCHOR_RIGHT"); GameTooltip:SetText(this:GetParent().hasEnchant and "Click to change the enchant" or "Click to choose an enchant",1,.82,0); GameTooltip:Show() end)
  eb:SetScript("OnLeave",function() GameTooltip:Hide(); WatchHint(this:GetParent()) end)
  eb:Hide()
  b:RegisterForClicks("LeftButtonUp","RightButtonUp"); b:SetScript("OnClick",function() if arg1=="RightButton" then AB:RemoveItem(this.slot) elseif IsShiftKeyDown() then AB:OpenEnchantBrowser(this.slot) else AB:OpenItemBrowser(this.slot) end end)
  b:SetScript("OnEnter",function() AB:ShowSlotTooltip(this); EnchantHint(this,true) end)
  b:SetScript("OnLeave",function() GameTooltip:Hide(); WatchHint(this) end)
  self.slotButtons[slot]=b
end

-- The window is wide enough for the three talent trees; the planner keeps its
-- original 980px layout on a page centred inside it.
local FRAME_W,PLANNER_W,FRAME_H,SET_FULL,SET_COMPACT=1060,980,900,148,40

function AB:CreateUI()
  if self.frame then return end
  local f=CreateFrame("Frame","AshenBuildsFrame",UIParent); f:SetWidth(FRAME_W); f:SetHeight(FRAME_H); f:SetPoint("CENTER",UIParent,"CENTER",0,0); MakeBackdrop(f); self:SetupWindow(f,{fit=true}); f:Hide(); self.frame=f
  -- Focus keeps the Ashen sigil centred behind the title, cropping rather than stretching the art.
  self:ApplyEmberBackground(f,10,0.33,0.45,0.30); self:AddEmberHeader(f,116); self:AddEmberFloor(f,44)
  local title=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); title:SetPoint("TOP",f,"TOP",0,-16); title:SetText("ASHEN BUILDS  |cff8d96a8v"..self.VERSION.."|r"); title:SetTextColor(1,.45,.16)
  local close=CreateFrame("Button",nil,f,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",f,"TOPRIGHT",-4,-4)

  local nameBox=CreateFrame("EditBox","AshenBuildsNameBox",f,"InputBoxTemplate"); nameBox:SetWidth(220); nameBox:SetHeight(24); nameBox:SetPoint("TOPLEFT",f,"TOPLEFT",24,-48); nameBox:SetAutoFocus(false); self.nameBox=nameBox
  -- Save is the one primary action; everything else on this row is a quieter secondary button.
  local save=MakeButton(f,"Save",64,22); save:SetPoint("LEFT",nameBox,"RIGHT",6,0); save:SetScript("OnClick",function() AB:SaveBuild(AB.nameBox:GetText()) end)
  local function Quiet(text,w) local b=MakeButton(f,text,w,22); AB:SkinQuietButton(b); return b end
  local saveAs=Quiet("Save As",70); saveAs:SetPoint("LEFT",save,"RIGHT",4,0); saveAs:SetScript("OnClick",function() AB:ShowPrompt({title="SAVE AS NEW BUILD",text="Name for the copy:",edit=true,default=AB.nameBox:GetText(),accept="Save",onAccept=function(text) AB:SaveBuild(text,true) end}) end)
  nameBox:SetScript("OnEnterPressed",function() this:ClearFocus(); AB:SaveBuild(this:GetText()) end); nameBox:SetScript("OnEscapePressed",function() this:ClearFocus() end)
  local new=Quiet("New",54); new:SetPoint("LEFT",saveAs,"RIGHT",4,0); new:SetScript("OnClick",function() AB:ConfirmDiscard("a new build",function() AB.current=AB.NewBuildData("New Build"); AshenBuildsDB.current=AB.current; AB.selectedBuild=nil; AB:RefreshUI() end) end)
  local clear=Quiet("Clear Gear",82); clear:SetPoint("LEFT",new,"RIGHT",4,0); clear:SetScript("OnClick",function() AB.current.items={}; AB.current.enchants={}; AB:RefreshUI() end)
  local export=Quiet("Export",62); export:SetPoint("LEFT",clear,"RIGHT",4,0); export:SetScript("OnClick",function() AB:ShowCodeDialog("Export Build",AB:ExportBuild(),false) end)
  local import=Quiet("Import",62); import:SetPoint("LEFT",export,"RIGHT",4,0); import:SetScript("OnClick",function() AB:ShowCodeDialog("Import Build","",true) end)
  self.saveStateText=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); self.saveStateText:SetPoint("LEFT",import,"RIGHT",12,0)
  -- The typed name is kept on the build right away, so a refresh never wipes it; Save still decides whether it renames.
  nameBox:SetScript("OnTextChanged",function() if AB.current then AB.current.name=this:GetText() end end)

  local g=AB.THEME.gold
  local function Profile(label,x,w,listFn,getFn,setFn)
    local fs=f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); fs:SetPoint("TOPLEFT",f,"TOPLEFT",x,-82); fs:SetText(label); fs:SetTextColor(g[1],g[2],g[3])
    local b=MakeButton(f,"",w,22); AB:SkinButton(b,"cycle"); b:SetPoint("TOPLEFT",f,"TOPLEFT",x,-98); b:RegisterForClicks("LeftButtonUp","RightButtonUp"); b:SetScript("OnClick",function() setFn(Cycle(listFn(),getFn(),arg1=="RightButton" and -1 or 1)) end); return b
  end
  self.classButton=Profile("CLASS",24,105,function() return AB.CLASSES end,function() return AB.current.class end,function(v) AB:SetClass(v) end)
  self.raceButton=Profile("RACE",136,105,function() return AB.RACES end,function() return AB.current.race end,function(v) AB:SetRace(v) end)
  self.specButton=Profile("BUILD",248,125,function() return AB.SPECS[AB.current.class] end,function() return AB.current.spec end,function(v) AB:SetSpec(v) end)
  local lf=f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); lf:SetPoint("TOPLEFT",f,"TOPLEFT",380,-82); lf:SetText("LEVEL"); lf:SetTextColor(g[1],g[2],g[3])
  local level=CreateFrame("EditBox","AshenBuildsLevelBox",f,"InputBoxTemplate"); level:SetWidth(42); level:SetHeight(22); level:SetPoint("TOPLEFT",f,"TOPLEFT",380,-98); level:SetNumeric(true); level:SetMaxLetters(2); level:SetAutoFocus(false); level:SetScript("OnEnterPressed",function() AB:SetLevel(this:GetText()); this:ClearFocus() end); level:SetScript("OnEditFocusLost",function() AB:SetLevel(this:GetText()) end); self.levelBox=level
  -- Tabs (styled and lined up on the header rule by SetupTabs).
  self.itemDatabaseButton=MakeButton(f,"ITEM DATABASE",118,26); self.itemDatabaseButton:SetScript("OnClick",function() AB:OpenItemBrowser("ALL") end)
  self.savedBuildsButton=MakeButton(f,"SAVED BUILDS",112,26); self.savedBuildsButton:SetScript("OnClick",function() AB:OpenBuildBrowser() end)
  self.communityButton=MakeButton(f,"COMMUNITY",104,26); self.communityButton:SetScript("OnClick",function() AB:OpenCommunity() end)
  self.itemDatabaseButton:SetPoint("BOTTOMRIGHT",f,"TOPRIGHT",-24,-126)
  self.savedBuildsButton:SetPoint("RIGHT",self.itemDatabaseButton,"LEFT",-3,0)
  self.communityButton:SetPoint("RIGHT",self.savedBuildsButton,"LEFT",-3,0)

  -- Everything below the header belongs to the Planner tab.
  local page=CreateFrame("Frame",nil,f); page:SetWidth(PLANNER_W); page:SetHeight(FRAME_H); page:SetPoint("TOP",f,"TOP",0,0); self.plannerPage=page

  self.slotButtons={}
  local leftSlots={"HEAD","NECK","SHOULDER","BACK","CHEST","SHIRT","TABARD","WRIST"}; local rightSlots={"HANDS","WAIST","LEGS","FEET","FINGER1","FINGER2","TRINKET1","TRINKET2"}; local i
  for i=1,table.getn(leftSlots) do self:CreateGearSlot(page,leftSlots[i],50,-140-(i-1)*58,"left") end
  for i=1,table.getn(rightSlots) do self:CreateGearSlot(page,rightSlots[i],775,-140-(i-1)*58,"right") end

  local stats=CreateFrame("Frame",nil,page); stats:SetWidth(520); stats:SetHeight(490); stats:SetPoint("TOP",f,"TOP",0,-132); self:StylePanel(stats,"sheer"); self.statsPanel=stats
  -- Header switch between the totals and a 3D preview of the gear.
  local function HeaderTab(text,w,view)
    local b=CreateFrame("Button",nil,stats); b:SetWidth(w); b:SetHeight(20); b.view=view
    b.fs=b:CreateFontString(nil,"OVERLAY","GameFontNormal"); b.fs:SetAllPoints(b); b.fs:SetText(text)
    b.bar=b:CreateTexture(nil,"OVERLAY"); b.bar:SetTexture(1,.45,.16,1); b.bar:SetHeight(2); b.bar:SetPoint("BOTTOMLEFT",b,"BOTTOMLEFT",8,-1); b.bar:SetPoint("BOTTOMRIGHT",b,"BOTTOMRIGHT",-8,-1)
    b:SetScript("OnClick",function() AB:SetStatsView(this.view) end)
    return b
  end
  self.totalsTab=HeaderTab("CHARACTER TOTALS",160,"totals"); self.totalsTab:SetPoint("TOPRIGHT",stats,"TOP",-4,-6)
  self.previewTab=HeaderTab("MODEL PREVIEW",140,"preview"); self.previewTab:SetPoint("TOPLEFT",stats,"TOP",4,-6)
  local sep=stats:CreateFontString(nil,"OVERLAY","GameFontDisable"); sep:SetPoint("TOP",stats,"TOP",0,-8); sep:SetText("|")

  local cards=CreateFrame("Frame",nil,stats); cards:SetAllPoints(stats); self.statsCards=cards
  self.statsColumns={}
  local cardPositions={{10,-34,245,125},{265,-34,245,125},{10,-165,245,170},{265,-165,245,170},{10,-341,245,137},{265,-341,245,137}}
  for i=1,6 do
    local pos=cardPositions[i]; local c=CreateFrame("Frame",nil,cards); c:SetWidth(pos[3]); c:SetHeight(pos[4]); c:SetPoint("TOPLEFT",stats,"TOPLEFT",pos[1],pos[2]);
    self:StylePanel(c,"card"); self.statsColumns[i]=c
  end
  self:CreateModelPreview(stats)

  self:CreateGearSlot(page,"MAINHAND",0,0,"left"); self.slotButtons.MAINHAND:ClearAllPoints(); self.slotButtons.MAINHAND:SetPoint("TOPLEFT",stats,"BOTTOMLEFT",17,-10)
  self:CreateGearSlot(page,"OFFHAND",0,0,"left"); self.slotButtons.OFFHAND:ClearAllPoints(); self.slotButtons.OFFHAND:SetPoint("LEFT",self.slotButtons.MAINHAND,"RIGHT",10,0)
  self:CreateGearSlot(page,"RANGED",0,0,"left"); self.slotButtons.RANGED:ClearAllPoints(); self.slotButtons.RANGED:SetPoint("LEFT",self.slotButtons.OFFHAND,"RIGHT",10,0)

  local setPanel=CreateFrame("Frame",nil,page); setPanel:SetWidth(880); setPanel:SetHeight(SET_FULL); setPanel:SetPoint("TOP",self.slotButtons.OFFHAND,"BOTTOM",0,-10); self:StylePanel(setPanel,"panel"); self.setPanel=setPanel
  local sh=setPanel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); sh:SetPoint("TOPLEFT",setPanel,"TOPLEFT",12,-9); sh:SetText("SET BONUSES"); sh:SetTextColor(g[1],g[2],g[3])
  self.setEmptyText=setPanel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); self.setEmptyText:SetPoint("LEFT",sh,"RIGHT",14,0); self.setEmptyText:SetText("No item set pieces equipped."); self.setEmptyText:SetTextColor(AB.THEME.dim[1],AB.THEME.dim[2],AB.THEME.dim[3])
  local scroll=CreateFrame("ScrollFrame","AshenBuildsSetScrollFrame",setPanel,"UIPanelScrollFrameTemplate"); scroll:SetPoint("TOPLEFT",setPanel,"TOPLEFT",10,-26); scroll:SetPoint("BOTTOMRIGHT",setPanel,"BOTTOMRIGHT",-29,9); self.setScroll=scroll
  local child=CreateFrame("Frame",nil,scroll); child:SetWidth(826); child:SetHeight(105); scroll:SetScrollChild(child); self.setScrollChild=child
  self.setColumnTexts={}
  for i=1,2 do local txt=child:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); txt:SetPoint("TOPLEFT",child,"TOPLEFT",(i-1)*413,0); txt:SetWidth(397); txt:SetJustifyH("LEFT"); txt:SetJustifyV("TOP"); self.setColumnTexts[i]=txt end
  scroll:EnableMouseWheel(true); scroll:SetScript("OnMouseWheel",function() local cur=this:GetVerticalScroll() or 0; local max=this:GetVerticalScrollRange() or 0; cur=cur-(arg1*28); if cur<0 then cur=0 elseif cur>max then cur=max end; this:SetVerticalScroll(cur) end)

  self:CreateBuildBrowser(); self:CreateItemBrowser(); self:CreateSourcePanel(); self:CreateEnchantBrowser(); self:CreateCodeDialog()
  self:SetStatsView("totals"); self:RefreshUI()
end

---------------------------------------------------------------------------
-- 3D preview: the player's model wearing the planned gear. Drag to turn,
-- scroll to zoom.
--
-- It borrows the game's own Dressing Room model (DressUpModel) - the frame that
-- Ctrl-clicking an item uses - and hands it back when the preview closes or the
-- real Dressing Room opens. If that frame is busy or missing, a model of our own
-- is used instead. Like the Dressing Room, it only puts items on: slots the
-- plan leaves empty show what you are wearing (/ab model undress strips first).
-- The client can only draw the player's race and only items it has cached.
---------------------------------------------------------------------------
-- Slots that change how the model looks.
local VISIBLE_SLOTS={"HEAD","SHOULDER","BACK","CHEST","SHIRT","TABARD","WRIST","HANDS","WAIST","LEGS","FEET","MAINHAND","OFFHAND","RANGED"}
local MODEL_SCRIPTS={"OnMouseDown","OnMouseUp","OnMouseWheel","OnUpdate","OnEvent"}
-- The model holds either its melee weapons or its ranged weapon: trying on a bow
-- replaces the main and off hand. Melee is shown by default; the toggle swaps.
local function ShowRanged() return AshenBuildsDB.settings and AshenBuildsDB.settings.modelRanged end
local function SkipSlot(slot)
  if slot=="RANGED" then return not ShowRanged() end
  if slot=="MAINHAND" or slot=="OFFHAND" then return ShowRanged() end
  return false
end

local function ModelScripts(m)
  m:EnableMouse(true); m:EnableMouseWheel(true)
  -- The Dressing Room model reloads the player's real gear on model/inventory events,
  -- which flashed the preview back to your own gear at random. Ignore them here.
  m:SetScript("OnEvent",function() end)
  m:SetScript("OnMouseDown",function() AB.previewArea.dragX=GetCursorPosition() end)
  m:SetScript("OnMouseUp",function() AB.previewArea.dragX=nil end)
  m:SetScript("OnMouseWheel",function() local a=AB.previewArea; a.zoom=math.max(0,math.min(2.5,a.zoom+arg1*0.25)); this:SetPosition(a.zoom,0,0) end)
  m:SetScript("OnUpdate",function()
    local a=AB.previewArea
    if a.dragX then local x=GetCursorPosition(); a.facing=a.facing+(x-a.dragX)*0.015; a.dragX=x; this:SetFacing(a.facing) end
    -- Dressing waits for the model SetUnit started loading; see RefreshModel.
    if a.dressAt and GetTime()>=a.dressAt[1] then table.remove(a.dressAt,1); if table.getn(a.dressAt)==0 then a.dressAt=nil end; AB:DressModel() end
    if a.loadUntil and GetTime()>=a.nextCheck then
      a.nextCheck=GetTime()+0.5
      local still=AB:MissingPreviewItems()
      if table.getn(still)<a.waiting then a.waiting=table.getn(still); if a.waiting==0 then a.loadUntil=nil end; AB:DressModel(); AB:UpdatePreviewNote()
      elseif GetTime()>=a.loadUntil then a.loadUntil=nil; AB:UpdatePreviewNote() end
    end
  end)
end

function AB:CreateModelPreview(parent)
  local area=CreateFrame("Frame",nil,parent); self.previewArea=area
  area:SetPoint("TOPLEFT",parent,"TOPLEFT",8,-32); area:SetPoint("BOTTOMRIGHT",parent,"BOTTOMRIGHT",-8,30); area:Hide()
  area.facing=0; area.zoom=0
  local own=CreateFrame("DressUpModel","AshenBuildsPreviewModel",area); own:SetAllPoints(area); own:Hide(); ModelScripts(own); self.ownModel=own
  area.note=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); area.note:SetPoint("BOTTOMLEFT",parent,"BOTTOMLEFT",12,10); area.note:SetWidth(370); area.note:SetJustifyH("LEFT")
  local weapons=MakeButton(parent,"",110,20); self:SkinQuietButton(weapons); weapons:SetPoint("BOTTOMRIGHT",parent,"BOTTOMRIGHT",-10,6); weapons:Hide(); area.weaponToggle=weapons
  weapons:SetScript("OnClick",function()
    AshenBuildsDB.settings.modelRanged=not AshenBuildsDB.settings.modelRanged
    AB:UpdateWeaponToggle(); AB:RefreshModel()
  end)
  weapons:SetScript("OnEnter",function() GameTooltip:SetOwner(this,"ANCHOR_TOP"); GameTooltip:SetText("The model holds either its melee weapons or its ranged weapon.",1,1,1,1,true); GameTooltip:Show() end)
  weapons:SetScript("OnLeave",function() GameTooltip:Hide() end)
  local d=AB.THEME.dim; area.note:SetTextColor(d[1]+.2,d[2]+.2,d[3]+.2); area.note:Hide()
  -- Always give the Dressing Room its model back.
  local oldHide=self.frame:GetScript("OnHide"); self.frame:SetScript("OnHide",function() AB:ReturnModel(); if oldHide then oldHide() end end)
  if DressUpFrame then
    local oldShow=DressUpFrame:GetScript("OnShow")
    DressUpFrame:SetScript("OnShow",function() local was=AB.borrowedModel; AB:ReturnModel(); if oldShow then oldShow() end; if was and AB.previewArea:IsShown() then AB:RefreshModel() end end)
  end
end

-- Moves DressUpModel into the preview, remembering everything needed to put it back.
function AB:BorrowModel()
  local bm=DressUpModel
  if self.borrowedModel then return bm end
  if not bm or not bm.TryOn or not bm.GetParent or (DressUpFrame and DressUpFrame:IsShown()) then return nil end
  local saved={parent=bm:GetParent(),w=bm:GetWidth(),h=bm:GetHeight(),level=bm:GetFrameLevel(),strata=bm:GetFrameStrata(),shown=bm:IsShown(),points={},scripts={}}
  local i,p,rel,rp,x,y
  for i=1,5 do p,rel,rp,x,y=bm:GetPoint(i); if p then table.insert(saved.points,{p,rel,rp,x,y}) end end
  for i=1,table.getn(MODEL_SCRIPTS) do saved.scripts[MODEL_SCRIPTS[i]]=bm:GetScript(MODEL_SCRIPTS[i]) end
  saved.mouse=bm.IsMouseEnabled and bm:IsMouseEnabled(); saved.wheel=bm.IsMouseWheelEnabled and bm:IsMouseWheelEnabled()
  self.borrowedModel=saved
  bm:SetParent(self.previewArea); bm:ClearAllPoints(); bm:SetAllPoints(self.previewArea)
  -- Keep it in the planner's layer so the enchant/item windows draw (and click) above it.
  bm:SetFrameStrata(self.frame:GetFrameStrata()); bm:SetFrameLevel(self.previewArea:GetFrameLevel()+2)
  ModelScripts(bm); bm:Show()
  return bm
end

function AB:ReturnModel()
  local s=self.borrowedModel; if not s then return end
  self.borrowedModel=nil
  local bm=DressUpModel
  bm:SetParent(s.parent); bm:ClearAllPoints()
  local i; for i=1,table.getn(s.points) do local p=s.points[i]; bm:SetPoint(p[1],p[2],p[3],p[4],p[5]) end
  if s.w and s.h then bm:SetWidth(s.w); bm:SetHeight(s.h) end
  if s.strata then bm:SetFrameStrata(s.strata) end
  if s.level then bm:SetFrameLevel(s.level) end
  for i=1,table.getn(MODEL_SCRIPTS) do bm:SetScript(MODEL_SCRIPTS[i],s.scripts[MODEL_SCRIPTS[i]]) end
  bm:EnableMouse(s.mouse and true or false); if bm.EnableMouseWheel then bm:EnableMouseWheel(s.wheel and true or false) end
  bm:SetFacing(0); bm:SetPosition(0,0,0)
  if not s.shown then bm:Hide() end
  if self.activeModel==bm then self.activeModel=nil end
  self.previewArea.unitLoaded=false
end

-- Planned, visible items the client hasn't cached yet (the Dressing Room can't show those).
function AB:MissingPreviewItems()
  local out,i,id={},nil,nil
  for i=1,table.getn(VISIBLE_SLOTS) do
    id=self.current.items[VISIBLE_SLOTS[i]]
    if id and not SkipSlot(VISIBLE_SLOTS[i]) and not GetItemInfo(id) then table.insert(out,id) end
  end
  return out
end

-- Asks the server for an item the same way hovering an unseen link does.
local scanTip
local function RequestItem(id)
  if not scanTip then scanTip=CreateFrame("GameTooltip","AshenBuildsScanTooltip",UIParent,"GameTooltipTemplate") end
  scanTip:SetOwner(UIParent,"ANCHOR_NONE"); scanTip:SetHyperlink("item:"..id..":0:0:0"); scanTip:Hide()
end

-- What the model should be wearing; re-dressing only happens when this changes.
local function Outfit()
  local parts,i,id={},nil,nil
  for i=1,table.getn(VISIBLE_SLOTS) do
    id=AB.current.items[VISIBLE_SLOTS[i]]
    if id and not SkipSlot(VISIBLE_SLOTS[i]) then table.insert(parts,VISIBLE_SLOTS[i].."="..id) end
  end
  local s=AshenBuildsDB.settings or {}
  table.insert(parts,s.modelKeepGear and "keep" or "strip")
  return table.concat(parts,";")
end

-- Keeps the preview smooth:
--  * the character is loaded (SetUnit) only when the preview gets a model, since
--    SetUnit shows your real gear until the planned gear goes back on;
--  * SetUnit loads over the next frame or two, so the first dressing waits a moment
--    and repeats once in case the model was slow;
--  * after that, changes re-dress in a single step, and only when the visible gear
--    actually changed (stat or enchant refreshes leave the model alone);
--  * items the client hasn't cached are fetched and put on as they arrive.
function AB:RefreshModel()
  local area=self.previewArea
  if not area or not area:IsShown() then return end
  local m=self:BorrowModel()
  if m then self.ownModel:Hide() else m=self.ownModel; m:Show() end
  if self.activeModel~=m then self.activeModel=m; self.previewArea.unitLoaded=false; self:UpdateModelMouse() end
  if not area.unitLoaded then
    self.activeModel=m; area.unitLoaded=true; area.outfit=nil
    m:SetUnit("player")
    area.dressAt={GetTime()+0.1,GetTime()+0.6}
  elseif not area.dressAt and area.outfit~=Outfit() then
    self:DressModel()
  end
  local missing=self:MissingPreviewItems()
  local i
  if table.getn(missing)>0 and not area.loadUntil and area.requested~=Outfit() then
    for i=1,table.getn(missing) do RequestItem(missing[i]) end
    area.requested=Outfit(); area.loadUntil=GetTime()+10; area.nextCheck=GetTime()+0.5; area.waiting=table.getn(missing)
  end
  self:UpdatePreviewNote()
end

function AB:UpdatePreviewNote()
  local area=self.previewArea
  local n=table.getn(self:MissingPreviewItems())
  local notes={"Drag to turn, scroll to zoom."}
  local myRace=self.PlayerRace()
  if myRace and self.current.race and string.gsub(myRace,"%s","")~=string.gsub(self.current.race,"%s","") then table.insert(notes,"Shown on your own "..myRace.." model.") end
  if n>0 and area.loadUntil then table.insert(notes,"Loading "..n.." item"..(n==1 and "" or "s").." from the server...")
  elseif n>0 then table.insert(notes,n.." item"..(n==1 and "" or "s").." couldn't be loaded; your own gear shows there.") end
  area.note:SetText(table.concat(notes,"  "))
end

-- Puts the planned gear on through the client's own DressUpItemLink.
-- On this client that routine is not the stock one: it tries the item ID and
-- then a translated appearance ID for Turtle's custom items (the /ab model
-- probe showed TryOn(80314) followed by TryOn("47250")), so a plain TryOn
-- can't dress custom gear. While it runs, DressUpModel points at the preview
-- model, the Dressing Room window is kept closed and the per-item SetUnit that
-- would reset the model is skipped; everything is restored afterwards.
local function DressThroughClient(m,links)
  local realModel,realShow,realDressUp=DressUpModel,ShowUIPanel,DressUpFrame
  DressUpModel=m
  if realShow then ShowUIPanel=function(frame,a2) if frame~=realDressUp then return realShow(frame,a2) end end end
  m.SetUnit=function() end
  local i
  local ok,err=pcall(function() for i=1,table.getn(links) do DressUpItemLink(links[i]) end end)
  m.SetUnit=nil
  ShowUIPanel=realShow; DressUpModel=realModel
  return ok,err
end

function AB:DressModel()
  local m=self.activeModel
  if not m or not self.previewArea:IsShown() then return end
  -- Strip first (unless the player chose to keep their own gear): a one-hand weapon
  -- goes to whichever hand is free, so with the player's real weapon still in the
  -- main hand, the planned one-hander would land in the off hand over the shield.
  local undress=not (AshenBuildsDB.settings and AshenBuildsDB.settings.modelKeepGear)
  if undress and m.Undress then m:Undress() end
  -- Main hand before off hand so a two-hander never clears the off hand afterwards.
  local links,i,id={},nil,nil
  for i=1,table.getn(VISIBLE_SLOTS) do
    id=self.current.items[VISIBLE_SLOTS[i]]
    if id and not SkipSlot(VISIBLE_SLOTS[i]) then
      table.insert(links,"item:"..id..":0:0:0")
      -- The client decides which hand a one-hander goes in. Trying it on twice puts
      -- it in both hands whether it alternates or fills the free hand first; the
      -- off-hand item that follows then replaces the off hand, leaving it in the main hand.
      local item=VISIBLE_SLOTS[i]=="MAINHAND" and self:GetItem(id)
      if item and item.slot=="WEAPON" then table.insert(links,"item:"..id..":0:0:0") end
    end
  end
  local ok,err=true,nil
  if DressUpItemLink then ok,err=DressThroughClient(m,links) end
  -- No client routine, or it failed: fall back to trying the item IDs directly.
  if not DressUpItemLink or not ok then
    for i=1,table.getn(links) do local _,_,n=string.find(links[i],"item:(%d+)"); m:TryOn(tonumber(n)) end
  end
  self.previewArea.lastLink=links[1]; self.previewArea.lastError=err; self.previewArea.outfit=Outfit()
  m:SetFacing(self.previewArea.facing); m:SetPosition(self.previewArea.zoom,0,0)
  self.previewArea.worn=table.getn(links)
end

-- The model takes the mouse for turning and zooming; while any other Ashen Builds
-- window is open it lets go, so it can never swallow clicks meant for that window.
function AB:UpdateModelMouse()
  local m=self.activeModel
  if not m then return end
  local blocked,i,w=false,nil,nil
  for i=1,table.getn(self.windows or {}) do w=self.windows[i]; if w~=self.frame and w:IsShown() then blocked=true end end
  m:EnableMouse(not blocked); if m.EnableMouseWheel then m:EnableMouseWheel(not blocked) end
  if blocked then self.previewArea.dragX=nil end
end

function AB:UpdateWeaponToggle()
  self.previewArea.weaponToggle:SetText(ShowRanged() and "Show Melee" or "Show Ranged")
end

function AB:SetStatsView(view)
  self.statsView=view
  local totals=view~="preview"
  if totals then
    self.statsCards:Show(); self:ReturnModel(); self.ownModel:Hide(); self.previewArea.unitLoaded=false; self.previewArea.dressAt=nil; self.previewArea:Hide(); self.previewArea.note:Hide(); self.previewArea.weaponToggle:Hide()
  else
    self.statsCards:Hide(); self.previewArea:Show(); self.previewArea.note:Show(); self:UpdateWeaponToggle(); self.previewArea.weaponToggle:Show()
  end
  local on,off=self.totalsTab,self.previewTab
  if not totals then on,off=off,on end
  on.fs:SetTextColor(1,1,1); on.bar:Show()
  off.fs:SetTextColor(AB.THEME.gold[1],AB.THEME.gold[2],AB.THEME.gold[3]); off.bar:Hide()
  if not totals then self:RefreshModel() end
end

function AB:ShowSlotTooltip(button)
  local id=self.current.items[button.slot] or 0; if id>0 then self:ShowItemTooltip(button,id); local e=AshenBuildsEnchants[self.current.enchants[button.slot] or 0]; if e then GameTooltip:AddLine(" "); GameTooltip:AddLine("Enchanted: "..e.n,0.1,1,0.1); local sum=self:StatSummary(e.stats); if sum=="" then sum=e.tip or "" end; if sum~="" then GameTooltip:AddLine(sum,0.1,1,0.1,true) end; GameTooltip:Show() end else GameTooltip:SetOwner(button,"ANCHOR_RIGHT"); GameTooltip:SetText(self.SLOT_LABELS[button.slot].." - Empty",.6,.65,.75); GameTooltip:AddLine("Click to choose an item",1,1,1); GameTooltip:Show() end
end

function AB:RefreshUI()
  -- Every change to the build ends in a refresh, so this is where edits are kept.
  self:AutoSave()
  if not self.frame then return end
  if self.saveStateText then
    if self.current.savedName then self.saveStateText:SetText("|cff7fd97fChanges save automatically|r") else self.saveStateText:SetText("|cffffb347Not saved yet - press Save|r") end
  end
  self.nameBox:SetText(self.current.name or "New Build"); self.classButton:SetText(self.current.class); self.raceButton:SetText(self.current.race); self.specButton:SetText(self.current.spec); self.levelBox:SetText(self:GetBuildLevel())
  local slot,b,id,item,c,enchant
  local muted=AB.THEME.muted
  for slot,b in pairs(self.slotButtons) do
    id=self.current.items[slot]; item=id and self:GetItem(id); enchant=AshenBuildsEnchants[(self.current.enchants and self.current.enchants[slot]) or 0]
    if item then
      b.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark"); b.icon:SetTexCoord(.07,.93,.07,.93); b.icon:SetVertexColor(1,1,1)
      b.itemText:SetText(item.n); c=qualityColors[item.q] or qualityColors[1]; b.itemText:SetTextColor(c[1],c[2],c[3])
      if (item.q or 1)>=2 then b.glow:SetVertexColor(c[1],c[2],c[3]); b.glow:Show() else b.glow:Hide() end
    else
      b.icon:SetTexture(self:EmptySlotIcon(slot)); b.icon:SetTexCoord(0,1,0,1); b.icon:SetVertexColor(.8,.8,.8)
      b.itemText:SetText("Empty"); b.itemText:SetTextColor(AB.THEME.dim[1],AB.THEME.dim[2],AB.THEME.dim[3]); b.glow:Hide()
    end
    b.hasEnchant=enchant and true or false
    b.canEnchant=item and AshenBuildsEnchantSlots[slot] and true or false
    if enchant then b.enchantText:SetText(enchant.n); b.enchantText:SetTextColor(.2,1,.2); b.enchantButton:Show() else b.enchantButton:Hide() end
  end
  self:RefreshStats(); self:RefreshSetBonuses()
  if self.statsView=="preview" then self:RefreshModel() end
end

-- Stat lines are pooled per column: refreshing reuses the same font strings
-- instead of creating new ones every time the build changes. Each line has an
-- invisible hover area that explains where the number comes from.
function AB:ClearStatColumns()
  local i,c,j
  for i=1,6 do c=self.statsColumns[i]; c.used=0; if c.lines then for j=1,table.getn(c.lines) do c.lines[j][1]:Hide(); c.lines[j][2]:Hide(); c.lines[j][3]:Hide() end else c.lines={} end end
end
function AB:PutStat(col,label,value,y,key,isZero)
  local c=self.statsColumns[col]; c.used=c.used+1
  local line=c.lines[c.used]
  if not line then
    local a,b=StatLine(c,"","",y)
    local hit=CreateFrame("Button",nil,c); hit:SetHeight(15)
    hit:SetScript("OnEnter",function() AB:ShowStatTooltip(this) end); hit:SetScript("OnLeave",function() GameTooltip:Hide() end)
    line={a,b,hit}; c.lines[c.used]=line
  end
  local t=AB.THEME
  line[1]:ClearAllPoints(); line[1]:SetPoint("TOPLEFT",c,"TOPLEFT",14,y); line[1]:SetText(label)
  line[2]:ClearAllPoints(); line[2]:SetPoint("TOPRIGHT",c,"TOPRIGHT",-14,y); line[2]:SetText(value or "")
  -- Zeroes fade back so the stats that matter for this build stand out.
  if isZero then line[1]:SetTextColor(t.dim[1],t.dim[2],t.dim[3]); line[2]:SetTextColor(t.dim[1],t.dim[2],t.dim[3])
  else line[1]:SetTextColor(t.label[1],t.label[2],t.label[3]); line[2]:SetTextColor(1,1,1) end
  line[3]:ClearAllPoints(); line[3]:SetPoint("TOPLEFT",c,"TOPLEFT",8,y+1); line[3]:SetPoint("RIGHT",c,"RIGHT",-8,0)
  line[3].key=key; line[3].label=label; line[3].value=value
  line[1]:Show(); line[2]:Show(); line[3]:Show()
end

function AB:ShowStatTooltip(hit)
  local d=self.lastStats; if not d or not hit.key then return end
  local lines=d.explain and d.explain[hit.key]
  local note=(hit.key=="parry" and d.parryNote) or ((hit.key=="block" or hit.key=="blockValue") and d.blockNote)
  if (not lines or table.getn(lines)==0) and not note then return end
  GameTooltip:SetOwner(hit,"ANCHOR_RIGHT")
  GameTooltip:SetText(hit.label.."  "..(hit.value or ""),1,.82,.28)
  local i,l,v
  for i=1,table.getn(lines or {}) do
    l=lines[i]; v=l[2]
    v=(v>0 and "+" or "")..(math.floor(v)==v and tostring(v) or string.format("%.2f",v))..(l[3] and "%" or "")
    self:AddTooltipDouble(l[1],v,.85,.8,.7,1,1,1)
  end
  if note then GameTooltip:AddLine(note,.6,.6,.6,true) end
  GameTooltip:Show()
end

local STAT_HEADINGS={"BASE STATS","RESOURCES","MELEE & RANGED","SPELLS & HEALING","DEFENSE","RESISTANCES"}
function AB:RefreshStats()
  local i
  if not self.statHeadings then self.statHeadings=true; for i=1,6 do Section(self.statsColumns[i],STAT_HEADINGS[i],-8) end end
  self:ClearStatColumns(); local ok,d=pcall(function() return AB:GetDerivedStats(self.current) end); if not ok or not d then self:PutStat(1,"Calculation error",tostring(d),-34); return end
  self.lastStats=d
  local y
  local step=16
  local function Row(col,label,v,pct,key) self:PutStat(col,label,F(v)..(pct and "%" or ""),y,key,(v or 0)==0); y=y-step end
  step=16; y=-34; Row(1,"Strength",d.str,false,"str"); Row(1,"Agility",d.agi,false,"agi"); Row(1,"Stamina",d.sta,false,"sta"); Row(1,"Intellect",d.int,false,"int"); Row(1,"Spirit",d.spi,false,"spi")
  step=17; y=-34; Row(2,"Health",d.health,false,"health"); if d.mana and d.mana>0 then Row(2,"Mana",d.mana,false,"mana") end; Row(2,"Armor",d.armor,false,"armor"); if d.haste and d.haste>0 then Row(2,"Haste",d.haste,true,"haste") end
  step=16; y=-34; Row(3,"Attack Power",d.attackPower,false,"attackPower"); Row(3,"Ranged AP",d.rangedAttackPower,false,"rangedAttackPower"); Row(3,"Melee Crit",d.meleeCrit,true,"meleeCrit"); Row(3,"Ranged Crit",d.rangedCrit,true,"rangedCrit"); Row(3,"Melee Hit",d.hit,true,"hit"); Row(3,"Ranged Hit",d.rangedHit,true,"rangedHit")
  if d.mainSkill then Row(3,"MH "..d.mainSkill.type,d.mainSkill.total) end; if d.rangedSkill then Row(3,"Ranged "..d.rangedSkill.type,d.rangedSkill.total) end
  step=17; y=-34; Row(4,"Spell Power",d.spellPower,false,"spellPower"); Row(4,"Healing",d.healing,false,"healing"); Row(4,"Spell Crit",d.spellCrit,true,"spellCrit"); Row(4,"Spell Hit",d.spellHit,true,"spellHit"); Row(4,"MP5 (items)",d.mp5); if d.spiritRegen and d.spiritRegen>0 then Row(4,"MP5 (spirit, not casting)",d.spiritRegen,false,"spiritRegen") end
  step=17; y=-34; Row(5,"Defense",d.defense,false,"defense"); Row(5,"Dodge",d.dodge,true,"dodge"); Row(5,"Parry",d.parry,true,"parry"); Row(5,"Block",d.block,true,"block"); Row(5,"Block Value",d.blockValue,false,"blockValue")
  step=17; y=-34; Row(6,"Fire",d.resistances.fire); Row(6,"Frost",d.resistances.frost); Row(6,"Nature",d.resistances.nature); Row(6,"Shadow",d.resistances.shadow); Row(6,"Arcane",d.resistances.arcane)
end

-- The set panel collapses to one line (and the window shrinks) when no set pieces are equipped.
function AB:SetSetPanelCompact(compact)
  if self.setCompact==compact then return end
  self.setCompact=compact
  if compact then self.setPanel:SetHeight(SET_COMPACT); self.setScroll:Hide(); self.setEmptyText:Show()
  else self.setPanel:SetHeight(SET_FULL); self.setScroll:Show(); self.setEmptyText:Hide() end
  self:ApplyWindowHeight()
end

function AB:RefreshSetBonuses()
  local counts={}; local slot,id,item,setId
  for slot,id in pairs(self.current.items or {}) do item=self:GetItem(id); setId=self:GetItemSetId(id,item); if setId then counts[setId]=(counts[setId] or 0)+1 end end
  local ids={}; for setId in pairs(counts) do table.insert(ids,setId) end; table.sort(ids)
  self:SetSetPanelCompact(table.getn(ids)==0)
  if table.getn(ids)==0 then return end
  local cols={{},{}}
  local lineCounts={0,0}
  local index,count,set,i,b,total,col,block
  for index=1,table.getn(ids) do
    setId=ids[index]; count=counts[setId]; set=self:GetItemSet(setId); col=math.mod(index-1,2)+1; block={}
    if set then
      total=table.getn(set.items or {}); table.insert(block,"|cffffd100"..(set.name or "Item Set").." ("..count.."/"..total..")|r")
      for i=1,table.getn(set.bonuses or {}) do b=set.bonuses[i]; if b and b[3] and b[3]~="" then table.insert(block,(count>=(b[1] or 0) and "|cff33ff66" or "|cff9ea5b2").."("..(b[1] or 0)..") Set: "..b[3].."|r") end end
    else
      local loaded=(self.SetCatalogMeta and self.SetCatalogMeta.setCount) or (AshenDB and AshenDB.GetSetCount and AshenDB:GetSetCount()) or 0; table.insert(block,"|cffff3333Set data missing for #"..setId.." ("..loaded.." definitions loaded)|r")
    end
    table.insert(cols[col],table.concat(block,"\n")); lineCounts[col]=lineCounts[col]+table.getn(block)+1
  end
  self.setColumnTexts[1]:SetText(table.concat(cols[1],"\n\n")); self.setColumnTexts[2]:SetText(table.concat(cols[2],"\n\n"))
  local maxLines=math.max(lineCounts[1],lineCounts[2]); local h=math.max(105,maxLines*15+8); self.setScrollChild:SetHeight(h); self.setColumnTexts[1]:SetHeight(h); self.setColumnTexts[2]:SetHeight(h); self.setScroll:SetVerticalScroll(0); if self.setScroll.UpdateScrollChildRect then self.setScroll:UpdateScrollChildRect() end
end

---------------------------------------------------------------------------
-- Saved builds
---------------------------------------------------------------------------
local BUILD_ROWS=10
function AB:GetSavedBuildNames()
  local names={}; local name
  for name in pairs(AshenBuildsDB.builds or {}) do table.insert(names,name) end
  table.sort(names,function(a,b) return string.lower(a)<string.lower(b) end)
  return names
end

function AB:RefreshBuildList()
  if not self.buildRows then return end
  local names=self:GetSavedBuildNames(); local total=table.getn(names)
  local maxOffset=math.max(0,total-BUILD_ROWS)
  if (self.buildOffset or 0)>maxOffset then self.buildOffset=maxOffset end
  local i,row,name,pub
  for i=1,BUILD_ROWS do
    row=self.buildRows[i]; name=names[(self.buildOffset or 0)+i]
    if name then
      row.buildName=name; pub=self.IsBuildPublished and self:IsBuildPublished(name)
      local label=name
      if self.current.savedName==name then label="|cffffd100> |r"..label end
      if pub then label=label.."  |cffffd100public|r" else local alt=self.PublishedByAlt and self:PublishedByAlt(name); if alt then label=label.."  |cffbdb8adpublic as "..alt.."|r" end end
      row.text:SetText(label); row.publish:SetText(pub and "Unpublish" or "Publish"); row:Show()
    else row.buildName=nil; row:Hide() end
  end
  if self.buildCountText then
    local shown=total>BUILD_ROWS and ("  -  showing "..((self.buildOffset or 0)+1).."-"..math.min(total,(self.buildOffset or 0)+BUILD_ROWS).." (scroll for more)") or ""
    self.buildCountText:SetText(total.." saved build"..(total==1 and "" or "s")..shown)
  end
end

function AB:PromptRenameBuild(name)
  self:ShowPrompt({title="RENAME BUILD",text="New name for |cffffffff"..name.."|r:",edit=true,default=name,accept="Rename",
    onAccept=function(text) AB:RenameBuild(name,text) end})
end

function AB:PromptDeleteBuild(name)
  self:ShowPrompt({title="DELETE BUILD",text="Delete |cffffffff"..name.."|r?\nThis can't be undone.",accept="Delete",
    onAccept=function() AB:DeleteBuild(name) end})
end

function AB:CreateBuildBrowser()
  local f=CreateFrame("Frame","AshenBuildsBuildBrowser",UIParent); f:SetWidth(560); f:SetHeight(500); f:SetPoint("CENTER",UIParent,"CENTER",260,0); MakeBackdrop(f)
  self:SetupWindow(f,{wheel=function() AB.buildOffset=math.max(0,(AB.buildOffset or 0)-arg1); AB:RefreshBuildList() end}); f:Hide(); self.buildBrowser=f
  self:ApplyEmberBackground(f,10,0.33,0.4,0.4); self:AddEmberHeader(f,34); self:AddEmberWell(f,22,-72,-22,58)
  local t=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); t:SetPoint("TOP",f,"TOP",0,-18); t:SetText("SAVED BUILDS")
  local close=CreateFrame("Button",nil,f,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",f,"TOPRIGHT",-4,-4); f.closeButton=close; self:AddChrome(f,t); self:AddChrome(f,close)
  self.buildCountText=f:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); self.buildCountText:SetPoint("TOP",f,"TOP",0,-50); self.buildCountText:SetTextColor(AB.THEME.muted[1],AB.THEME.muted[2],AB.THEME.muted[3])
  self.buildRows={}; local i
  for i=1,BUILD_ROWS do
    local r=CreateFrame("Button",nil,f); r:SetWidth(506); r:SetHeight(32); r:SetPoint("TOPLEFT",f,"TOPLEFT",28,-78-(i-1)*36); r:SetPoint("RIGHT",f,"RIGHT",-28,0); r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    r.text=r:CreateFontString(nil,"OVERLAY","GameFontHighlight"); r.text:SetPoint("LEFT",r,"LEFT",8,0); r.text:SetWidth(240); r.text:SetJustifyH("LEFT")
    r.publish=MakeButton(r,"Publish",82,22); r.publish:SetPoint("RIGHT",r,"RIGHT",-2,0); r.publish:SetScript("OnClick",function() local n=this:GetParent().buildName; if not n then return end; if AB:IsBuildPublished(n) then AB:UnpublishBuild(n) else AB:PublishBuild(n) end end)
    r.delete=MakeButton(r,"Delete",66,22); r.delete:SetPoint("RIGHT",r.publish,"LEFT",-4,0); r.delete:SetScript("OnClick",function() local n=this:GetParent().buildName; if n then AB:PromptDeleteBuild(n) end end)
    r.rename=MakeButton(r,"Rename",70,22); r.rename:SetPoint("RIGHT",r.delete,"LEFT",-4,0); r.rename:SetScript("OnClick",function() local n=this:GetParent().buildName; if n then AB:PromptRenameBuild(n) end end)
    r:RegisterForClicks("LeftButtonUp","RightButtonUp")
    r:SetScript("OnClick",function() if not this.buildName then return end; if arg1=="RightButton" then AB:PromptDeleteBuild(this.buildName) else local n=this.buildName; AB:ConfirmDiscard(n,function() AB:LoadBuild(n); f:Hide() end) end end)
    self.buildRows[i]=r
  end
  local help=f:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); help:SetPoint("BOTTOM",f,"BOTTOM",0,24); help:SetText("Click a build to load it  -  Saving a loaded build under a new name renames it"); help:SetTextColor(AB.THEME.muted[1],AB.THEME.muted[2],AB.THEME.muted[3])
end
function AB:OpenBuildBrowser() self.buildOffset=0; self:RefreshBuildList(); self.buildBrowser:Show() end

---------------------------------------------------------------------------
-- Item database
---------------------------------------------------------------------------
local ITEM_ROWS=12
local SLOT_FILTERS={{"ALL","All Slots"},{"HEAD","Head"},{"NECK","Neck"},{"SHOULDER","Shoulder"},{"BACK","Back"},{"CHEST","Chest"},{"SHIRT","Shirt"},{"TABARD","Tabard"},{"WRIST","Wrist"},{"HANDS","Hands"},{"WAIST","Waist"},{"LEGS","Legs"},{"FEET","Feet"},{"FINGER1","Ring"},{"TRINKET1","Trinket"},{"MAINHAND","Main Hand"},{"OFFHAND","Off Hand"},{"RANGED","Ranged"}}
local FILTER_SLOT_OF={FINGER2="FINGER1",TRINKET2="TRINKET1"}
local QUALITY_FILTERS={-1,5,4,3,2,1,0}
local SORTS={{"ilvl","Item Level (high)"},{"ilvlUp","Item Level (low)"},{"name","Name (A-Z)"},{"req","Required Level (high)"}}
local FILTER_STATS={"str","agi","sta","int","spi","armor","ap","rap","crit","hit","haste","spellPower","healing","spellCrit","spellHit","mp5","defense","dodge","parry","block","firePower","frostPower","shadowPower","arcanePower","naturePower","holyPower","spellPen","fireRes","frostRes","natureRes","shadowRes","arcaneRes"}
local MAX_STAT_FILTERS=4
local ARMOR_FILTERS={{0,"All Armor"},{1,"Cloth"},{2,"Leather"},{3,"Mail"},{4,"Plate"}}

local function LabelOf(list,value) local i for i=1,table.getn(list) do if list[i][1]==value then return list[i][2] end end return "" end

function AB:ItemFilterDefaults()
  self.itemFilter={slot="ALL",quality=-1,source=0,armor=0,minIlvl=nil,maxIlvl=nil,stats={},usable=true,classOnly=true,showHidden=false,sort="ilvl"}
end

function AB:QueueItemRefresh(delay) self.itemRefreshAt=GetTime()+(delay or 0) end

function AB:CreateItemBrowser()
  self:ItemFilterDefaults()
  local f=CreateFrame("Frame","AshenBuildsItemBrowser",UIParent); f:SetWidth(880); f:SetHeight(700); f:SetPoint("CENTER",UIParent,"CENTER",0,0); MakeBackdrop(f); self:SetupWindow(f,{fit=true,wheel=function() AB:ScrollItemPage(arg1) end}); f:Hide(); self.itemBrowser=f
  self:ApplyEmberBackground(f,10,0.55,0.5,0.4); self:AddEmberHeader(f,34); self:AddEmberWell(f,22,-190,-22,48)
  local t=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); t:SetPoint("TOP",f,"TOP",0,-17); t:SetText("ITEM DATABASE"); self.itemBrowserTitle=t
  local close=CreateFrame("Button",nil,f,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",f,"TOPRIGHT",-4,-4); f.closeButton=close; self:AddChrome(f,t); self:AddChrome(f,close)
  -- Search typing is debounced; everything else refreshes on the next frame.
  f:SetScript("OnUpdate",function() if AB.itemRefreshAt and GetTime()>=AB.itemRefreshAt then AB.itemRefreshAt=nil; AB.itemPage=1; AB:RefreshItemResults() end end)

  -- Row 1: search and toggles
  local search=CreateFrame("EditBox","AshenBuildsItemSearch",f,"InputBoxTemplate"); search:SetWidth(330); search:SetHeight(24); search:SetPoint("TOPLEFT",f,"TOPLEFT",32,-66); search:SetAutoFocus(false); self.itemSearch=search
  search:SetScript("OnTextChanged",function() AB:QueueItemRefresh(0.25) end); search:SetScript("OnEnterPressed",function() this:ClearFocus(); AB:QueueItemRefresh(0) end); search:SetScript("OnEscapePressed",function() this:ClearFocus() end)
  self:Caption(f,"Search (name, NPC or zone)",search,-6,4)
  local clear=MakeButton(f,"Clear Filters",96,22); clear:SetPoint("LEFT",search,"RIGHT",8,0); clear:SetScript("OnClick",function() local slot=AB.itemFilter.slot; AB:ItemFilterDefaults(); AB.itemFilter.slot=slot; AB.itemSearch:SetText(""); AB:SyncItemFilterControls(); AB:QueueItemRefresh(0) end)
  self.usableCheck=self:CreateCheck(f,"Usable at build level",function(v) AB.itemFilter.usable=v; AB:QueueItemRefresh(0) end); self.usableCheck:SetPoint("LEFT",clear,"RIGHT",10,0)
  self.classCheck=self:CreateCheck(f,"My class",function(v) AB.itemFilter.classOnly=v; AB:QueueItemRefresh(0) end); self.classCheck:SetPoint("LEFT",self.usableCheck,"RIGHT",128,0)
  self.hiddenCheck=self:CreateCheck(f,"Show hidden",function(v) AB.itemFilter.showHidden=v; AB:QueueItemRefresh(0) end); self.hiddenCheck:SetPoint("LEFT",self.classCheck,"RIGHT",62,0)

  -- Row 2: dropdowns and item level range
  local y=-118
  self.slotDrop=self:CreateDropdown(f,140,{
    items=function() local out={}; local i; for i=1,table.getn(SLOT_FILTERS) do table.insert(out,{value=SLOT_FILTERS[i][1],text=SLOT_FILTERS[i][2]}) end; return out end,
    getText=function() return LabelOf(SLOT_FILTERS,AB.itemFilter.slot) end,
    isChecked=function(v) return AB.itemFilter.slot==v end,
    onSelect=function(v) AB.itemFilter.slot=v; AB.browserSlot=v; AB:QueueItemRefresh(0) end})
  self.slotDrop:SetPoint("TOPLEFT",f,"TOPLEFT",26,y); self.slotCaption=self:Caption(f,"Equipment Slot",self.slotDrop)

  local levelBoxes=0
  local function LevelBox(anchor,x)
    levelBoxes=levelBoxes+1; local e=CreateFrame("EditBox","AshenBuildsIlvlBox"..levelBoxes,f,"InputBoxTemplate"); e:SetWidth(52); e:SetHeight(24); e:SetPoint("LEFT",anchor,"RIGHT",x,0); e:SetAutoFocus(false); e:SetNumeric(true); e:SetMaxLetters(3)
    e:SetScript("OnTextChanged",function() AB:QueueItemRefresh(0.35) end); e:SetScript("OnEnterPressed",function() this:ClearFocus() end); e:SetScript("OnEscapePressed",function() this:ClearFocus() end)
    return e
  end
  self.minIlvlBox=LevelBox(self.slotDrop,20); self:Caption(f,"Item Level",self.minIlvlBox,-6,4)
  local dash=f:CreateFontString(nil,"OVERLAY","GameFontHighlight"); dash:SetPoint("LEFT",self.minIlvlBox,"RIGHT",4,0); dash:SetText("-")
  self.maxIlvlBox=LevelBox(self.minIlvlBox,18)

  self.sourceDrop=self:CreateDropdown(f,118,{
    items=function() local out={}; local i,s; for i=1,table.getn(AB.SOURCE_FILTERS) do s=AB.SOURCE_FILTERS[i]; table.insert(out,{value=s.value,text=s.text}) end; return out end,
    getText=function() local i; for i=1,table.getn(AB.SOURCE_FILTERS) do if AB.SOURCE_FILTERS[i].value==AB.itemFilter.source then return AB.SOURCE_FILTERS[i].text end end; return "All Sources" end,
    isChecked=function(v) return AB.itemFilter.source==v end,
    onSelect=function(v) AB.itemFilter.source=v; AB:QueueItemRefresh(0) end})
  self.sourceDrop:SetPoint("LEFT",self.maxIlvlBox,"RIGHT",16,0); self:Caption(f,"Source",self.sourceDrop)

  self.qualityDrop=self:CreateDropdown(f,110,{
    items=function() local out={}; local i,q,c; for i=1,table.getn(QUALITY_FILTERS) do q=QUALITY_FILTERS[i]; c=q>=0 and qualityColors[q] or nil; table.insert(out,{value=q,text=q<0 and "All Qualities" or AB.QUALITY_LABELS[q],color=c}) end; return out end,
    getText=function() local q=AB.itemFilter.quality; return q<0 and "All Qualities" or AB.QUALITY_LABELS[q] end,
    isChecked=function(v) return AB.itemFilter.quality==v end,
    onSelect=function(v) AB.itemFilter.quality=v; AB:QueueItemRefresh(0) end})
  self.qualityDrop:SetPoint("LEFT",self.sourceDrop,"RIGHT",12,0); self:Caption(f,"Quality",self.qualityDrop)

  self.sortDrop=self:CreateDropdown(f,150,{
    items=function() local out={}; local i; for i=1,table.getn(SORTS) do table.insert(out,{value=SORTS[i][1],text=SORTS[i][2]}) end; return out end,
    getText=function() return LabelOf(SORTS,AB.itemFilter.sort) end,
    isChecked=function(v) return AB.itemFilter.sort==v end,
    onSelect=function(v) AB.itemFilter.sort=v; AB:QueueItemRefresh(0) end})
  self.sortDrop:SetPoint("LEFT",self.qualityDrop,"RIGHT",12,0); self:Caption(f,"Sort",self.sortDrop)

  self.armorDrop=self:CreateDropdown(f,108,{
    items=function() local out={}; local i; for i=1,table.getn(ARMOR_FILTERS) do table.insert(out,{value=ARMOR_FILTERS[i][1],text=ARMOR_FILTERS[i][2]}) end; return out end,
    getText=function() return LabelOf(ARMOR_FILTERS,AB.itemFilter.armor) end,
    isChecked=function(v) return AB.itemFilter.armor==v end,
    onSelect=function(v) AB.itemFilter.armor=v; AB:QueueItemRefresh(0) end})
  self.armorDrop:SetPoint("LEFT",self.sortDrop,"RIGHT",12,0); self:Caption(f,"Armor Type",self.armorDrop)

  -- Row 3: stat filters (multi-select) with a minimum per stat
  self.statDrop=self:CreateDropdown(f,140,{multi=true,listWidth=170,
    items=function() local out={}; local i; for i=1,table.getn(FILTER_STATS) do table.insert(out,{value=FILTER_STATS[i],text=AB.STAT_LABELS[FILTER_STATS[i]] or FILTER_STATS[i]}) end; return out end,
    getText=function() local n=table.getn(AB.itemFilter.stats); if n==0 then return "Select stats..." end; return n.." stat"..(n==1 and "" or "s").." selected" end,
    isChecked=function(v) local i; for i=1,table.getn(AB.itemFilter.stats) do if AB.itemFilter.stats[i][1]==v then return true end end; return false end,
    onSelect=function(v) AB:ToggleStatFilter(v) end})
  self.statDrop:SetPoint("TOPLEFT",f,"TOPLEFT",26,-160); self:Caption(f,"Stats",self.statDrop)
  self.statChips={}; local i
  for i=1,MAX_STAT_FILTERS do
    local c=CreateFrame("Frame",nil,f); c:SetWidth(158); c:SetHeight(24); self:StylePanel(c,"card"); c:SetBackdropColor(.12,.09,.07,.95)
    if i==1 then c:SetPoint("LEFT",self.statDrop,"RIGHT",12,0) else c:SetPoint("LEFT",self.statChips[i-1],"RIGHT",8,0) end
    c.label=c:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); c.label:SetPoint("LEFT",c,"LEFT",8,0); c.label:SetWidth(70); c.label:SetJustifyH("LEFT")
    local ge=c:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); ge:SetPoint("LEFT",c,"LEFT",80,0); ge:SetText(">=")
    c.edit=CreateFrame("EditBox","AshenBuildsStatMin"..i,c,"InputBoxTemplate"); c.edit:SetWidth(34); c.edit:SetHeight(18); c.edit:SetPoint("LEFT",ge,"RIGHT",8,0); c.edit:SetAutoFocus(false); c.edit:SetNumeric(true); c.edit:SetMaxLetters(3); c.index=i
    c.edit:SetScript("OnTextChanged",function() local s=AB.itemFilter.stats[this:GetParent().index]; if s then s[2]=tonumber(this:GetText()) or 0; AB:QueueItemRefresh(0.35) end end)
    c.edit:SetScript("OnEnterPressed",function() this:ClearFocus() end); c.edit:SetScript("OnEscapePressed",function() this:ClearFocus() end)
    c.remove=CreateFrame("Button",nil,c); c.remove:SetWidth(16); c.remove:SetHeight(16); c.remove:SetPoint("RIGHT",c,"RIGHT",-4,0)
    local x=c.remove:CreateFontString(nil,"OVERLAY","GameFontNormal"); x:SetAllPoints(c.remove); x:SetText("x"); c.remove:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    c.remove:SetScript("OnClick",function() local s=AB.itemFilter.stats[this:GetParent().index]; if s then AB:ToggleStatFilter(s[1]) end end)
    c:Hide(); self.statChips[i]=c
  end

  -- Results
  self.itemRows={}
  for i=1,ITEM_ROWS do
    local r=CreateFrame("Button",nil,f); r:SetWidth(820); r:SetHeight(36); r:SetPoint("TOPLEFT",f,"TOPLEFT",28,-196-(i-1)*38); r:SetPoint("RIGHT",f,"RIGHT",-28,0); r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    r.icon=r:CreateTexture(nil,"ARTWORK"); r.icon:SetWidth(30); r.icon:SetHeight(30); r.icon:SetPoint("LEFT",r,"LEFT",2,0)
    r.name=r:CreateFontString(nil,"OVERLAY","GameFontHighlight"); r.name:SetPoint("TOPLEFT",r.icon,"TOPRIGHT",8,-1); r.name:SetWidth(520); r.name:SetJustifyH("LEFT")
    r.meta=r:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); r.meta:SetPoint("TOPRIGHT",r,"TOPRIGHT",-6,-3); r.meta:SetWidth(250); r.meta:SetJustifyH("RIGHT"); r.meta:SetTextColor(.64,.67,.72)
    r.stats=r:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); r.stats:SetTextColor(AB.THEME.muted[1],AB.THEME.muted[2],AB.THEME.muted[3]); r.stats:SetPoint("BOTTOMLEFT",r.icon,"BOTTOMRIGHT",8,2); r.stats:SetWidth(770); r.stats:SetJustifyH("LEFT")
    r:RegisterForClicks("LeftButtonUp","RightButtonUp")
    r:SetScript("OnClick",function()
      if not this.itemID then return end
      if arg1=="RightButton" or IsControlKeyDown() then AB:OpenSourcePanel(this.itemID); return end
      AB:EquipItem(AB.browserSlot,this.itemID)
      if AB.browserSlot~="ALL" then AB.itemBrowser:Hide() end
    end)
    r:SetScript("OnEnter",function() if this.itemID then AB:ShowItemTooltip(this,this.itemID) end end); r:SetScript("OnLeave",function() GameTooltip:Hide() end)
    self.itemRows[i]=r
  end
  self.prevItem=MakeButton(f,"Previous",82,22); self.prevItem:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",28,18); self.prevItem:SetScript("OnClick",function() AB:ScrollItemPage(1) end)
  self.nextItem=MakeButton(f,"Next",82,22); self.nextItem:SetPoint("LEFT",self.prevItem,"RIGHT",8,0); self.nextItem:SetScript("OnClick",function() AB:ScrollItemPage(-1) end)
  self.pageText=f:CreateFontString(nil,"OVERLAY","GameFontHighlight"); self.pageText:SetPoint("LEFT",self.nextItem,"RIGHT",12,0)
  self.packText=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); self.packText:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-26,22)
  local hint=f:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); hint:SetPoint("BOTTOM",f,"BOTTOM",60,22); hint:SetText("Click to equip  -  Right-click for sources"); hint:SetTextColor(AB.THEME.muted[1],AB.THEME.muted[2],AB.THEME.muted[3])
  self:SyncItemFilterControls()
end

function AB:ToggleStatFilter(key)
  local stats=self.itemFilter.stats; local i
  for i=1,table.getn(stats) do if stats[i][1]==key then table.remove(stats,i); self:SyncItemFilterControls(); self:QueueItemRefresh(0); return end end
  if table.getn(stats)>=MAX_STAT_FILTERS then self.Print("You can filter on up to "..MAX_STAT_FILTERS.." stats at once."); return end
  table.insert(stats,{key,0}); self:SyncItemFilterControls(); self:QueueItemRefresh(0)
end

-- Pushes self.itemFilter into every filter control.
function AB:SyncItemFilterControls()
  local fl=self.itemFilter
  self.slotDrop:Refresh(); self.sourceDrop:Refresh(); self.qualityDrop:Refresh(); self.sortDrop:Refresh(); self.armorDrop:Refresh(); self.statDrop:Refresh()
  self.usableCheck:SetChecked(fl.usable and 1 or nil); self.classCheck:SetChecked(fl.classOnly and 1 or nil); self.hiddenCheck:SetChecked(fl.showHidden and 1 or nil)
  self.minIlvlBox:SetText(fl.minIlvl and tostring(fl.minIlvl) or ""); self.maxIlvlBox:SetText(fl.maxIlvl and tostring(fl.maxIlvl) or "")
  local i,c,s
  for i=1,MAX_STAT_FILTERS do
    c=self.statChips[i]; s=fl.stats[i]
    if s then c.label:SetText(self.STAT_LABELS[s[1]] or s[1]); c.edit:SetText(s[2]>0 and tostring(s[2]) or ""); c:Show() else c:Hide() end
  end
end

-- Wheel down / Next = next page, wheel up / Previous = previous page.
function AB:ScrollItemPage(delta)
  local pages=self.itemPages or 1
  if delta<0 and self.itemPage<pages then self.itemPage=self.itemPage+1
  elseif delta>0 and self.itemPage>1 then self.itemPage=self.itemPage-1
  else return end
  self:RenderItemPage()
end

function AB:OpenItemBrowser(slot)
  slot=slot or "ALL"
  self.browserSlot=slot; self.itemFilter.slot=FILTER_SLOT_OF[slot] or slot; self.itemPage=1
  self.itemBrowserTitle:SetText(slot=="ALL" and "ITEM DATABASE" or ("ITEM DATABASE  |cff8d96a8-  "..self.SLOT_LABELS[slot].."|r"))
  self.slotCaption:SetText(slot=="ALL" and "Equipment Slot" or ("Choosing for: |cffffffff"..self.SLOT_LABELS[slot].."|r"))
  self.itemSearch:SetText("")
  self:SyncItemFilterControls()
  self.itemBrowser:Show()
  self.itemRefreshAt=nil; self:RefreshItemResults()
end

-- Runs the filters against the search index and shows page 1.
function AB:RefreshItemResults()
  if not self.itemRows or not AshenDB or not AshenDB.Items then return end
  local fl=self.itemFilter
  fl.minIlvl=tonumber(self.minIlvlBox:GetText() or ""); fl.maxIlvl=tonumber(self.maxIlvlBox:GetText() or "")
  local idx=self.ItemIndex
  local matches=idx:Query({slot=fl.slot,query=string.lower(self.itemSearch:GetText() or ""),quality=fl.quality,minIlvl=fl.minIlvl,maxIlvl=fl.maxIlvl,source=fl.source,stats=fl.stats,
    maxReq=fl.usable and self:GetBuildLevel() or nil,class=fl.classOnly and self.current.class or nil,showHidden=fl.showHidden,
    level=fl.usable and self:GetBuildLevel() or nil,armor=(fl.armor or 0)>0 and fl.armor or nil})
  if fl.sort=="ilvlUp" then
    local n=table.getn(matches); local i; for i=1,math.floor(n/2) do matches[i],matches[n-i+1]=matches[n-i+1],matches[i] end
  elseif fl.sort=="name" then
    local names=idx.name; table.sort(matches,function(a,b) return names[a]<names[b] end)
  elseif fl.sort=="req" then
    local req,ilvl=idx.req,idx.ilvl; table.sort(matches,function(a,b) if req[a]~=req[b] then return req[a]>req[b] end return ilvl[a]>ilvl[b] end)
  end
  self.itemMatches=matches
  self:RenderItemPage()
end

local SLOT_TEXT={HEAD="Head",NECK="Neck",SHOULDER="Shoulder",BACK="Back",CHEST="Chest",ROBE="Chest",SHIRT="Shirt",TABARD="Tabard",WRIST="Wrist",HANDS="Hands",WAIST="Waist",LEGS="Legs",FEET="Feet",FINGER="Finger",TRINKET="Trinket",WEAPON="One-Hand",MAINHAND="Main Hand",OFFHAND="Off Hand",TWOHAND="Two-Hand",SHIELD="Shield",HOLDABLE="Held In Off-hand",RANGED="Ranged",RANGEDRIGHT="Ranged",THROWN="Thrown",RELIC="Relic"}
local ARMOR_TEXT={[1]="Cloth",[2]="Leather",[3]="Mail",[4]="Plate"}

function AB:RenderItemPage()
  local matches=self.itemMatches or {}; local total=table.getn(matches)
  local pages=math.max(1,math.ceil(total/ITEM_ROWS)); self.itemPages=pages
  if self.itemPage>pages then self.itemPage=pages end
  local idx=self.ItemIndex
  local i,row,id,item,c,kind
  for i=1,ITEM_ROWS do
    row=self.itemRows[i]; id=matches[(self.itemPage-1)*ITEM_ROWS+i]; id=id and idx.id[id]; item=id and self:GetItem(id)
    if item then
      row.itemID=id; row.icon:SetTexture(item.icon); row.name:SetText(item.n)
      c=qualityColors[item.q] or qualityColors[1]; row.name:SetTextColor(c[1],c[2],c[3])
      kind=SLOT_TEXT[item.slot] or ""
      if item.itemClass==4 and ARMOR_TEXT[item.subclass] then kind=ARMOR_TEXT[item.subclass].." "..kind elseif item.itemClass==2 and item.weaponType then kind=kind.." "..item.weaponType end
      row.meta:SetText(kind.."   |cffd9c9a3iLvl "..(item.ilvl or 0).."|r"..((item.req or 0)>0 and ("   Req "..item.req) or ""))
      local text=self:StatSummary(item.stats); local direct=self:GetDirectSourceSummary(id)
      if direct~="" then text=(text~="" and (text.."  -  ") or "")..direct end
      row.stats:SetText(text); row:Show()
    else row.itemID=nil; row:Hide() end
  end
  self.pageText:SetText("Page "..self.itemPage.." / "..pages.."  ("..total.." items)")
  if self.itemPage>1 then self.prevItem:Enable() else self.prevItem:Disable() end
  if self.itemPage<pages then self.nextItem:Enable() else self.nextItem:Disable() end
  local pack=AshenBuildsDBPack; self.packText:SetText((pack and pack.name or "AshenDB").." - "..(pack and pack.count or 0).." items")
end

-- "+12 Stamina, +8 Strength" in a fixed stat order.
local SUMMARY_ORDER={"str","agi","sta","int","spi","health","mana","ap","rap","feralAp","crit","hit","rangedHit","rangedCrit","haste","leech","armorPen","spellPower","healing","spellCrit","spellHit","mp5","hp5","defense","dodge","parry","block","blockValue","firePower","frostPower","shadowPower","arcanePower","naturePower","holyPower","fireRes","frostRes","natureRes","shadowRes","arcaneRes","armor"}
local PCT_STATS={crit=true,hit=true,rangedHit=true,rangedCrit=true,leech=true,haste=true,spellCrit=true,spellHit=true,dodge=true,parry=true,block=true}
function AB:StatSummary(stats)
  if not stats then return "" end
  local parts={}; local i,k,v
  for i=1,table.getn(SUMMARY_ORDER) do
    k=SUMMARY_ORDER[i]; v=stats[k]
    if v and v~=0 then table.insert(parts,"+"..v..(PCT_STATS[k] and "% " or " ")..(self.STAT_LABELS[k] or k)) end
  end
  return table.concat(parts,", ")
end

---------------------------------------------------------------------------
-- Enchants
---------------------------------------------------------------------------
local ENCHANT_ROWS=10
-- Stat groups for the enchant filter; picking one also sorts by that group's total.
local ENCHANT_GROUPS={
  {"all","All Stats"},
  {"str","Strength",{"str"}},{"agi","Agility",{"agi"}},{"sta","Stamina",{"sta"}},{"int","Intellect",{"int"}},{"spi","Spirit",{"spi"}},
  {"ap","Attack Power",{"ap","rap"}},{"hitcrit","Hit & Crit",{"hit","crit","rangedHit","rangedCrit","spellHit","spellCrit"}},{"haste","Haste",{"haste"}},
  {"spell","Spell Damage",{"spellPower","firePower","frostPower","shadowPower","arcanePower","naturePower","holyPower"}},{"healing","Healing",{"healing"}},
  {"mana","Mana & Regen",{"mana","mp5"}},{"health","Health",{"health"}},
  {"tank","Armor & Defense",{"armor","defense","dodge","parry","block","blockValue"}},
  {"resist","Resistances",{"fireRes","frostRes","natureRes","shadowRes","arcaneRes"}},
  {"pen","Penetration",{"armorPen","spellPen"}},{"leech","Vampirism",{"leech"}},
  {"other","Other Effects"},
}
local function GroupOf(key) local i for i=1,table.getn(ENCHANT_GROUPS) do if ENCHANT_GROUPS[i][1]==key then return ENCHANT_GROUPS[i] end end return ENCHANT_GROUPS[1] end
local function GroupValue(e,group) local v,i=0,nil; for i=1,table.getn(group[3] or {}) do v=v+(e.stats[group[3][i]] or 0) end; return v end

-- a beats b when it has at least as much of every stat b has, more of something, and nothing b lacks isn't a bonus.
local function Dominates(a,b)
  if not next(a.stats) or not next(b.stats) then return false end
  local k,v,better=nil,nil,false
  for k,v in pairs(b.stats) do if (a.stats[k] or 0)<v then return false elseif (a.stats[k] or 0)>v then better=true end end
  for k,v in pairs(a.stats) do if not b.stats[k] and v>0 then better=true end end
  return better
end

function AB:CreateEnchantBrowser()
  self.enchantFilter={group="all",lower=false}
  local f=CreateFrame("Frame","AshenBuildsEnchantBrowser",UIParent); f:SetWidth(560); f:SetHeight(566); f:SetPoint("CENTER",UIParent,"CENTER",0,0); MakeBackdrop(f)
  self:SetupWindow(f,{wheel=function() AB.enchantOffset=math.max(0,(AB.enchantOffset or 0)-arg1); AB:RenderEnchantRows() end}); f:Hide(); self.enchantBrowser=f
  self:ApplyEmberBackground(f,10,0.5,0.5,0.4); self:AddEmberHeader(f,34); self:AddEmberWell(f,22,-130,-22,44)
  f.title=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); f.title:SetPoint("TOP",f,"TOP",0,-18)
  local close=CreateFrame("Button",nil,f,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",f,"TOPRIGHT",-4,-4)
  f.item=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); f.item:SetPoint("TOPLEFT",f,"TOPLEFT",28,-58); f.item:SetWidth(340); f.item:SetJustifyH("LEFT")
  local none=MakeButton(f,"Remove Enchant",130,22); none:SetPoint("TOPRIGHT",f,"TOPRIGHT",-26,-52); none:SetScript("OnClick",function() AB:ApplyEnchant(AB.enchantSlot,0); f:Hide() end)

  local search=CreateFrame("EditBox","AshenBuildsEnchantSearch",f,"InputBoxTemplate"); search:SetWidth(200); search:SetHeight(24); search:SetPoint("TOPLEFT",f,"TOPLEFT",32,-100); search:SetAutoFocus(false); self.enchantSearch=search
  search:SetScript("OnTextChanged",function() AB:FilterEnchants() end); search:SetScript("OnEnterPressed",function() this:ClearFocus() end); search:SetScript("OnEscapePressed",function() this:ClearFocus() end)
  self:Caption(f,"Search (name or effect)",search,-6,4)
  self.enchantGroupDrop=self:CreateDropdown(f,150,{
    items=function() local out={}; local i; for i=1,table.getn(ENCHANT_GROUPS) do table.insert(out,{value=ENCHANT_GROUPS[i][1],text=ENCHANT_GROUPS[i][2]}) end; return out end,
    getText=function() return GroupOf(AB.enchantFilter.group)[2] end,
    isChecked=function(v) return AB.enchantFilter.group==v end,
    onSelect=function(v) AB.enchantFilter.group=v; AB:FilterEnchants() end})
  self.enchantGroupDrop:SetPoint("LEFT",search,"RIGHT",14,0); self:Caption(f,"Stat",self.enchantGroupDrop)
  self.enchantLowerCheck=self:CreateCheck(f,"Show lower ranks",function(v) AB.enchantFilter.lower=v; AB:FilterEnchants() end); self.enchantLowerCheck:SetPoint("LEFT",self.enchantGroupDrop,"RIGHT",10,0)

  self.enchantRows={}; local i
  for i=1,ENCHANT_ROWS do
    local r=CreateFrame("Button",nil,f); r:SetWidth(506); r:SetHeight(36); r:SetPoint("TOPLEFT",f,"TOPLEFT",26,-136-(i-1)*38); r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    r.text=r:CreateFontString(nil,"OVERLAY","GameFontHighlight"); r.text:SetPoint("TOPLEFT",r,"TOPLEFT",8,-3); r.text:SetWidth(490); r.text:SetJustifyH("LEFT")
    r.desc=r:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); r.desc:SetPoint("BOTTOMLEFT",r,"BOTTOMLEFT",8,3); r.desc:SetWidth(490); r.desc:SetJustifyH("LEFT"); r.desc:SetTextColor(.3,.95,.3)
    r:SetScript("OnClick",function() if this.enchantID then AB:ApplyEnchant(AB.enchantSlot,this.enchantID); f:Hide() end end)
    r:SetScript("OnEnter",function() local e=this.enchantID and AshenBuildsEnchants[this.enchantID]; if e and e.tip then GameTooltip:SetOwner(this,"ANCHOR_RIGHT"); GameTooltip:SetText(e.n,1,.82,0); GameTooltip:AddLine(e.tip,.1,1,.1,true); GameTooltip:Show() end end)
    r:SetScript("OnLeave",function() GameTooltip:Hide() end)
    self.enchantRows[i]=r
  end
  f.more=f:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); f.more:SetPoint("BOTTOM",f,"BOTTOM",0,22); f.more:SetTextColor(AB.THEME.muted[1],AB.THEME.muted[2],AB.THEME.muted[3])
end

function AB:OpenEnchantBrowser(slot)
  if not AshenBuildsEnchantSlots[slot] then self.Print(self.SLOT_LABELS[slot].." can't be enchanted."); return end
  local item=self:GetItem(self.current.items[slot] or 0)
  if not item then self.Print("Equip an item in "..self.SLOT_LABELS[slot].." before choosing an enchant."); return end
  self.enchantSlot=slot
  -- Everything that fits this item, before search and stat filters.
  self.enchantCandidates={}
  local i,id
  for i=1,table.getn(AshenBuildsEnchantOrder) do id=AshenBuildsEnchantOrder[i]; if self:IsEnchantAllowed(slot,id,item) then table.insert(self.enchantCandidates,id) end end
  local f=self.enchantBrowser; f.title:SetText("ENCHANT "..string.upper(self.SLOT_LABELS[slot]))
  local c=qualityColors[item.q] or qualityColors[1]; f.item:SetText(item.n); f.item:SetTextColor(c[1],c[2],c[3])
  self.enchantSearch:SetText(""); self.enchantGroupDrop:Refresh(); self.enchantLowerCheck:SetChecked(self.enchantFilter.lower and 1 or nil)
  self:FilterEnchants(); f:Show()
end

function AB:FilterEnchants()
  if not self.enchantCandidates then return end
  local query=string.lower(self.enchantSearch:GetText() or "")
  local group=GroupOf(self.enchantFilter.group)
  local current=self.current.enchants[self.enchantSlot]
  local pool,out={},{}
  local i,j,id,e,keep,text
  for i=1,table.getn(self.enchantCandidates) do
    id=self.enchantCandidates[i]; e=AshenBuildsEnchants[id]; keep=true
    if group[1]=="other" then keep=not next(e.stats)
    elseif group[3] then keep=GroupValue(e,group)>0 end
    if keep and query~="" then
      text=string.lower(e.n.." "..(e.tip or "").." "..self:StatSummary(e.stats))
      keep=string.find(text,query,1,true) and true or false
    end
    if keep then table.insert(pool,id) end
  end
  for i=1,table.getn(pool) do
    id=pool[i]; keep=true
    -- Hide enchants another candidate strictly beats (Minor/Lesser/Greater Stamina when Superior exists),
    -- but never the one currently applied.
    if not self.enchantFilter.lower and id~=current then
      for j=1,table.getn(pool) do if pool[j]~=id and Dominates(AshenBuildsEnchants[pool[j]],AshenBuildsEnchants[id]) then keep=false; break end end
    end
    if keep then table.insert(out,id) end
  end
  if group[3] then
    local g=group; table.sort(out,function(a,b) local va,vb=GroupValue(AshenBuildsEnchants[a],g),GroupValue(AshenBuildsEnchants[b],g); if va~=vb then return va>vb end return AshenBuildsEnchants[a].n<AshenBuildsEnchants[b].n end)
  end
  self.enchantMatches=out; self.enchantHidden=table.getn(pool)-table.getn(out); self.enchantOffset=0
  self:RenderEnchantRows()
end

function AB:RenderEnchantRows()
  local matches=self.enchantMatches or {}; local total=table.getn(matches)
  local maxOffset=math.max(0,total-ENCHANT_ROWS); if self.enchantOffset>maxOffset then self.enchantOffset=maxOffset end
  local current=self.current.enchants[self.enchantSlot]
  local i,id,e,r,desc
  for i=1,ENCHANT_ROWS do
    r=self.enchantRows[i]; id=matches[self.enchantOffset+i]; e=id and AshenBuildsEnchants[id]
    if e then
      r.enchantID=id; r.text:SetText((id==current and "|cffffd100> |r" or "")..e.n)
      desc=self:StatSummary(e.stats); if desc=="" then desc=e.tip or e.desc or "" end
      r.desc:SetText(desc); r:Show()
    else r.enchantID=nil; r:Hide() end
  end
  local text
  if total==0 then text="No enchants match." elseif total>ENCHANT_ROWS then text="Showing "..(self.enchantOffset+1).."-"..math.min(total,self.enchantOffset+ENCHANT_ROWS).." of "..total.." - scroll for more" else text=total.." enchant"..(total==1 and "" or "s") end
  if (self.enchantHidden or 0)>0 then text=text.."   |cff9ea5b2("..self.enchantHidden.." lower ranks hidden)|r" end
  self.enchantBrowser.more:SetText(text)
end

function AB:CreateCodeDialog() local f=CreateFrame("Frame","AshenBuildsCodeDialog",UIParent); f:SetWidth(650); f:SetHeight(190); f:SetPoint("CENTER",UIParent,"CENTER",0,0); MakeBackdrop(f); self:SetupWindow(f); f:Hide(); self.codeDialog=f; self:ApplyEmberBackground(f,10,0.5,0.5,0.45); self:AddEmberHeader(f,34); f.title=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); f.title:SetPoint("TOP",f,"TOP",0,-18); local edit=CreateFrame("EditBox","AshenBuildsCodeEdit",f,"InputBoxTemplate"); edit:SetWidth(580); edit:SetHeight(30); edit:SetPoint("TOP",f,"TOP",0,-62); edit:SetAutoFocus(false); edit:SetMaxLetters(4096); self.codeEdit=edit; local action=MakeButton(f,"Import",90,24); action:SetPoint("BOTTOM",f,"BOTTOM",-50,24); self.codeAction=action; local cancel=MakeButton(f,"Close",90,24); cancel:SetPoint("LEFT",action,"RIGHT",10,0); cancel:SetScript("OnClick",function() f:Hide() end) end
function AB:ShowCodeDialog(title,text,isImport) self.codeDialog.title:SetText(title); self.codeEdit:SetText(text or ""); self.codeDialog:Show(); self.codeEdit:SetFocus(); self.codeEdit:HighlightText(); if isImport then self.codeAction:SetText("Import"); self.codeAction:Show(); self.codeAction:SetScript("OnClick",function() if AB:ImportBuild(AB.codeEdit:GetText()) then AB.codeDialog:Hide() end end) else self.codeAction:Hide() end end
function AB:ToggleUI() if self.frame:IsShown() then self.frame:Hide() else self:RefreshUI(); self.frame:Show() end end

---------------------------------------------------------------------------
-- Tabs. Talents, Item Database, Saved Builds and Community are pages inside
-- the main window instead of separate windows. Each is still built as a window
-- by its Create* function; EmbedPage then moves it under the tab strip and
-- hides its window decoration. One page is visible at a time, and the Planner
-- page is shown whenever no other page is (e.g. after picking an item for a
-- slot or loading a build).
---------------------------------------------------------------------------
local PAGE_TOP=-130   -- top of the page area, just under the tab strip

local function HookScript(frame,script,fn)
  local old=frame:GetScript(script)
  frame:SetScript(script,function() if old then old() end; fn() end)
end

-- Frame levels are fixed when a frame is created, so a reparented window keeps
-- levels from its old life. Re-level the whole tree above the main window while
-- keeping each child's offset from its parent (talent buttons sit above their
-- tree panels, and so on).
local function Relevel(frame,level)
  local old=frame:GetFrameLevel(); frame:SetFrameLevel(level)
  local kids={frame:GetChildren()}; local i
  for i=1,table.getn(kids) do Relevel(kids[i],level+math.max(1,kids[i]:GetFrameLevel()-old)) end
end

-- cut: height of the window's own title strip. It ends up above the page area,
-- hidden behind the tab strip, so page content starts right under the tabs.
-- fill: stretch over the whole page area (list pages); otherwise keep the
-- window's size, centred (the talent trees have a fixed layout).
function AB:EmbedPage(frame,cut,fill)
  local i,t
  frame.embedded=true
  -- No longer a separate window: Escape closes the whole planner, and only the
  -- main window is dragged, fitted to the screen and raised.
  for i=table.getn(self.windows),1,-1 do if self.windows[i]==frame then table.remove(self.windows,i) end end
  for i=table.getn(UISpecialFrames),1,-1 do if UISpecialFrames[i]==frame:GetName() then table.remove(UISpecialFrames,i) end end
  frame:SetParent(self.frame); frame:SetScale(1); frame:ClearAllPoints()
  if fill then
    frame:SetPoint("TOPLEFT",self.frame,"TOPLEFT",12,PAGE_TOP+cut)
    frame:SetPoint("BOTTOMRIGHT",self.frame,"BOTTOMRIGHT",-12,12)
  else
    frame:SetPoint("TOP",self.frame,"TOP",0,PAGE_TOP+cut)
  end
  frame:SetFrameStrata(self.frame:GetFrameStrata()); Relevel(frame,self.frame:GetFrameLevel()+1)
  if frame.SetToplevel then frame:SetToplevel(false) end
  frame:SetMovable(false)
  -- Clicks on the page's empty space fall through to the main window, so the
  -- tabs under the hidden title strip stay clickable and dragging still works.
  frame:EnableMouse(false)
  frame:SetBackdrop(nil)
  if frame.emberScrim then frame.emberScrim:Hide() end
  for i,t in pairs(frame.emberTiles or {}) do t:Hide() end
  for i,t in pairs(frame.innerRule or {}) do t:Hide() end
  for i,t in pairs(frame.chrome or {}) do t:Hide() end
end

function AB:RefreshTabStates()
  local i,t
  for i=1,table.getn(self.tabs or {}) do t=self.tabs[i]; self:SetTabActive(t.button,t.frame:IsShown()) end
end

-- The Planner's set-bonus panel shrinks when empty, which shortens the window;
-- other pages always get the full height.
function AB:ApplyWindowHeight()
  local h=FRAME_H
  if self.plannerPage:IsShown() and self.setCompact then h=FRAME_H-(SET_FULL-SET_COMPACT) end
  if self.frame:GetHeight()==h then return end
  self.frame:SetHeight(h)
  self:ApplyEmberBackground(self.frame,10,0.33,0.45,0.30)
  if self.frame:IsShown() then self:FitToScreen(self.frame) end
end

function AB:OnPageShown(frame)
  local i,t
  for i=1,table.getn(self.tabs) do t=self.tabs[i]; if t.frame~=frame and t.frame:IsShown() then t.frame:Hide() end end
  self:RefreshTabStates(); self:ApplyWindowHeight()
end

function AB:OnPageHidden()
  local i
  for i=1,table.getn(self.tabs) do if self.tabs[i].frame:IsShown() then self:RefreshTabStates(); return end end
  self.plannerPage:Show()
end

function AB:AddTab(key,button,frame,open,isOpen)
  local tab={key=key,button=button,frame=frame,open=open,isOpen=isOpen}
  table.insert(self.tabs,tab)
  button:SetScript("OnClick",function() AB:SelectTab(tab) end)
  HookScript(frame,"OnShow",function() AB:OnPageShown(this) end)
  HookScript(frame,"OnHide",function() AB:OnPageHidden() end)
  return tab
end

-- Clicking the open tab does nothing, except that the item database switches
-- from choosing an item for one slot back to browsing everything.
function AB:SelectTab(tab)
  if tab.frame:IsShown() and (not tab.isOpen or tab.isOpen()) then return end
  tab.open(); PlaySound("igCharacterInfoTab")
end
AB.ToggleTab=AB.SelectTab

function AB:ShowTab(key)
  local i; for i=1,table.getn(self.tabs or {}) do if self.tabs[i].key==key then self:SelectTab(self.tabs[i]) end end
end

-- Called once every window exists (after Talent and Community UIs have been built).
function AB:SetupTabs()
  if self.tabs then return end
  self.tabs={}
  self.plannerButton=MakeButton(self.frame,"PLANNER",84,26)
  -- Left to right: Planner, Talents, Item Database, Saved Builds, Community.
  local order={self.plannerButton,self.talentOpenButton,self.itemDatabaseButton,self.savedBuildsButton,self.communityButton}
  local widths={84,84,118,112,104}
  local i,prev
  for i=table.getn(order),1,-1 do
    local b=order[i]
    if b then
      self:StyleTab(b); b:SetWidth(widths[i]); b:SetHeight(26); b:ClearAllPoints()
      if prev then b:SetPoint("RIGHT",prev,"LEFT",-3,0) else b:SetPoint("BOTTOMRIGHT",self.frame,"TOPRIGHT",-24,PAGE_TOP+4) end
      prev=b
    end
  end

  local page=self.plannerPage
  self:AddTab("planner",self.plannerButton,page,function() page:Show() end)
  -- The 3D preview borrows the game's Dressing Room model: hand it back while
  -- another page is showing and take it again on return.
  HookScript(page,"OnHide",function() if AB.statsView=="preview" then AB:ReturnModel() end end)
  HookScript(page,"OnShow",function() if AB.statsView=="preview" then AB:SetStatsView("preview") end end)

  if self.talentOpenButton and self.talentFrame then
    self:EmbedPage(self.talentFrame,36)
    self:AddTab("talents",self.talentOpenButton,self.talentFrame,function() AB.talentFrame:Show(); AB:RefreshTalentUI() end)
  end
  self:EmbedPage(self.itemBrowser,40,true)
  self:AddTab("items",self.itemDatabaseButton,self.itemBrowser,function() AB:OpenItemBrowser("ALL") end,function() return AB.browserSlot=="ALL" end)
  self:EmbedPage(self.buildBrowser,40,true)
  self:AddTab("saved",self.savedBuildsButton,self.buildBrowser,function() AB:OpenBuildBrowser() end)
  if self.communityButton and self.communityFrame then
    self:EmbedPage(self.communityFrame,40,true)
    self:AddTab("community",self.communityButton,self.communityFrame,function() AB:OpenCommunity() end)
  end
  -- Pages let clicks through (see EmbedPage), so the main window forwards the
  -- mouse wheel to whichever page is showing (item and community paging, etc.).
  self.frame:SetScript("OnMouseWheel",function()
    local i,t,fn
    for i=1,table.getn(AB.tabs) do t=AB.tabs[i]; fn=t.frame:IsShown() and t.frame:GetScript("OnMouseWheel"); if fn then fn() end end
  end)
  self:RefreshTabStates()
end


-- v0.6.1 complete item effects and visible sources
local AB_BIND_COLORS={red={1,0.15,0.15},white={1,1,1}}
local AB_SLOT_NAMES={HEAD="Head",NECK="Neck",SHOULDER="Shoulder",BACK="Back",CHEST="Chest",SHIRT="Shirt",TABARD="Tabard",ROBE="Chest",WRIST="Wrist",HANDS="Hands",WAIST="Waist",LEGS="Legs",FEET="Feet",FINGER="Finger",TRINKET="Trinket",WEAPON="One-Hand",MAINHAND="Main Hand",OFFHAND="Off Hand",TWOHAND="Two-Hand",SHIELD="Off Hand",HOLDABLE="Held In Off-hand",RANGED="Ranged",RANGEDRIGHT="Ranged",THROWN="Thrown",RELIC="Relic",WAND="Wand"}
local AB_ARMOR_NAMES={[1]="Cloth",[2]="Leather",[3]="Mail",[4]="Plate",[6]="Shield"}
local AB_STAT_ORDER={"str","agi","sta","int","spi","armor","holyRes","fireRes","natureRes","frostRes","shadowRes","arcaneRes"}
local AB_STAT_TOOLTIP={str="Strength",agi="Agility",sta="Stamina",int="Intellect",spi="Spirit",holyRes="Holy Resistance",fireRes="Fire Resistance",natureRes="Nature Resistance",frostRes="Frost Resistance",shadowRes="Shadow Resistance",arcaneRes="Arcane Resistance"}

function AB:MoneyText(copper)
  copper=tonumber(copper) or 0; local g=math.floor(copper/10000); local s=math.floor(math.mod(copper,10000)/100); local c=math.mod(copper,100); local t={}
  if g>0 then table.insert(t,g.."|cffffd700g|r") end; if s>0 or g>0 then table.insert(t,s.."|cffc7c7cfs|r") end; table.insert(t,c.."|cffeda55fc|r"); return table.concat(t," ")
end

function AB:GetItemDetail(id) return AshenDB and AshenDB.ItemDetails and AshenDB.ItemDetails[tonumber(id)] end
function AB:GetItemSources(id) return (AshenDB and AshenDB.ItemSources and AshenDB.ItemSources[tonumber(id)]) or {} end

function AB:GetDirectSourceSummary(id)
  local ss=self:GetItemSources(id); local s=ss[1]
  if not s then
    local item=self:GetItem(id); local broad=item and item.source or ""
    return broad~="" and ("Source: "..broad) or ""
  end
  if s[1]=="craft" then return "Crafted by "..(s[4] or "Profession") end
  if s[1]=="drop" then return "Dropped by "..(s[3] or "Unknown")..((s[4] and s[4]~="") and " - "..s[4] or "") end
  if s[1]=="vendor" then return "Sold by "..(s[3] or "Unknown")..((s[4] and s[4]~="") and " - "..s[4] or "") end
  if s[1]=="quest" then return "Reward from "..(s[3] or "Unknown") end
  local item=self:GetItem(id); local broad=item and item.source or ""
  return broad~="" and ("Source: "..broad) or ""
end

function AB:AddTooltipDouble(left,right,lr,lg,lb,rr,rg,rb)
  if GameTooltip.AddDoubleLine then GameTooltip:AddDoubleLine(left,right,lr or 1,lg or 1,lb or 1,rr or 1,rg or 1,rb or 1) else GameTooltip:AddLine(left.."                         "..right,lr or 1,lg or 1,lb or 1) end
end

function AB:FormatDropChance(chance)
  chance=tonumber(chance)
  if not chance or chance<=0 then return nil end
  if chance<0.01 then return "<0.01%" end
  if chance<0.1 then return string.format("%.3f%%",chance) end
  return string.format("%.2f%%",chance)
end

function AB:AddSourceTooltipLines(id)
  local ss=self:GetItemSources(id); local count=table.getn(ss); local i,s,reags,j
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Ashen Source",1,0.82,0)
  if count==0 then
    local item=self:GetItem(id); local broad=item and item.source or ""; GameTooltip:AddLine(broad~="" and ("Source category: "..broad) or "Direct source details are not available in this database build.",0.55,0.55,0.55,true)
    return
  end
  for i=1,count do
    s=ss[i]
    if s[1]=="craft" then
      GameTooltip:AddLine("Crafted by "..(s[4] or "Profession"),0.3,0.8,1,true)
      if s[3] and s[3]~="" then GameTooltip:AddLine("Recipe: "..s[3],1,1,1,true) end
      if s[5] and s[5]>0 then GameTooltip:AddLine("Requires "..(s[4] or "Skill").." "..s[5],0.75,0.75,0.75,true) end
      reags=s[8] or {}
      if table.getn(reags)>0 then
        local mats={}
        for j=1,math.min(table.getn(reags),5) do table.insert(mats,(reags[j][2] or "Item").." x"..(reags[j][3] or 1)) end
        GameTooltip:AddLine("Materials: "..table.concat(mats,", "),0.75,0.75,0.75,true)
      end
    elseif s[1]=="drop" then
      GameTooltip:AddLine("Dropped by "..(s[3] or "Unknown Creature"),0.3,0.8,1,true)
      if s[4] and s[4]~="" then GameTooltip:AddLine(s[4],1,1,1,true) end
      local chance=self:FormatDropChance(s[5]); if chance then GameTooltip:AddLine("Drop Chance: "..chance,0.75,0.75,0.75) end
    elseif s[1]=="more" then
      GameTooltip:AddLine("+"..(s[2] or 0).." additional creature drop sources",0.55,0.55,0.55,true)
    elseif s[1]=="vendor" then
      GameTooltip:AddLine("Sold by "..(s[3] or "Unknown Vendor"),0.3,0.8,1,true)
      if s[4] and s[4]~="" then GameTooltip:AddLine(s[4],1,1,1,true) end
    elseif s[1]=="quest" then
      GameTooltip:AddLine("Reward from "..(s[3] or "Unknown Quest"),0.3,0.8,1,true)
      if s[4] and s[4]~="" then GameTooltip:AddLine(s[4],1,1,1,true) end
      if s[7] and s[7]>0 then GameTooltip:AddLine("Quest Level: "..s[7]..(s[5]=="choice" and " (Choose one)" or ""),0.75,0.75,0.75,true) end
    end
    if i>=3 and count>3 then GameTooltip:AddLine("+"..(count-3).." additional sources",0.55,0.55,0.55); break end
  end
  GameTooltip:AddLine("Right-click item for full source details",0.5,0.5,0.5,true)
end

function AB:GetEquippedSetCount(setId)
  setId=tonumber(setId)
  if not setId or not self.current or not self.current.items then return 0 end
  local count=0; local slot,itemId,item,itemSetId
  for slot,itemId in pairs(self.current.items) do
    item=self:GetItem(itemId); itemSetId=self:GetItemSetId(itemId,item)
    if itemSetId==setId then count=count+1 end
  end
  return count
end

function AB:IsBuildItemEquipped(itemId)
  itemId=tonumber(itemId)
  if not itemId or not self.current or not self.current.items then return false end
  local _,equippedId
  for _,equippedId in pairs(self.current.items) do if tonumber(equippedId)==itemId then return true end end
  return false
end

function AB:AddSetTooltipLines(id,item)
  local set,setId=self:GetItemSetForItem(id,item)
  if not setId then return end
  GameTooltip:AddLine(" ")
  if not set then
    GameTooltip:AddLine("Set data missing (#"..setId..")",1,0.15,0.15,true)
    return
  end

  local equipped=self:GetEquippedSetCount(setId)
  local total=table.getn(set.items or {})
  GameTooltip:AddLine("|cffffd100"..(set.name or "Item Set").." ("..total..")|r",1,0.82,0)

  local classText=self:GetRequiredClassText(set.classMask)
  if classText then GameTooltip:AddLine("Classes: "..classText,1,1,1,true) end

  local i,piece,pieceId,pieceName
  for i=1,total do
    piece=set.items[i]
    pieceId=piece and tonumber(piece[1])
    pieceName=(piece and piece[2]) or "Unknown item"
    if pieceId==tonumber(id) then
      GameTooltip:AddLine(pieceName,1,1,1,true)
    elseif self:IsBuildItemEquipped(pieceId) then
      GameTooltip:AddLine(pieceName,0.1,1,0.1,true)
    else
      GameTooltip:AddLine(pieceName,0.5,0.5,0.5,true)
    end
  end

  local bonuses=set.bonuses or {}; local b,threshold,text,line
  for i=1,table.getn(bonuses) do
    b=bonuses[i]
    threshold=b and tonumber(b[1]) or 0
    text=b and b[3] or ""
    if text~="" then
      if equipped>=threshold then
        line="|cffffffff("..threshold..") Set: |r|cff20ff20"..text.."|r"
      else
        line="|cff777f8f("..threshold..") Set: "..text.."|r"
      end
      GameTooltip:AddLine(line,1,1,1,true)
    end
  end
end

local AB_CLASS_BITS={{"Warrior",1},{"Paladin",2},{"Hunter",4},{"Rogue",8},{"Priest",16},{"Shaman",64},{"Mage",128},{"Warlock",256},{"Druid",1024}}
function AB:GetRequiredClassText(mask)
  mask=tonumber(mask) or -1; if mask<0 then return nil end
  local names={}; local i,p
  for i=1,table.getn(AB_CLASS_BITS) do p=AB_CLASS_BITS[i]; if math.mod(math.floor(mask/p[2]),2)==1 then table.insert(names,p[1]) end end
  if table.getn(names)==0 or table.getn(names)==9 then return nil end
  return table.concat(names,", ")
end

function AB:ShowItemTooltip(owner,id)
  local item=self:GetItem(id); if not item then return end; local d=self:GetItemDetail(id) or {}; local qc=qualityColors[item.q] or qualityColors[1]
  GameTooltip:SetOwner(owner,"ANCHOR_RIGHT"); GameTooltip:ClearLines(); GameTooltip:SetText(item.n,qc[1],qc[2],qc[3])
  if d[1] and d[1]~="" then GameTooltip:AddLine(d[1],1,1,1) end
  local slot=AB_SLOT_NAMES[item.slot] or item.slot or ""; local typeName=""
  if item.itemClass==4 then typeName=AB_ARMOR_NAMES[item.subclass] or "" elseif item.itemClass==2 then typeName=item.weaponType or "" end
  if slot~="" then self:AddTooltipDouble(slot,typeName,1,1,1,1,1,1) end
  if item.itemClass==2 and item.minDamage and item.maxDamage and item.maxDamage>0 then self:AddTooltipDouble(string.format("%d - %d Damage",item.minDamage,item.maxDamage),item.speed and item.speed>0 and string.format("Speed %.2f",item.speed) or "",1,1,1,1,1,1); if item.stats and item.stats.dps then GameTooltip:AddLine(string.format("(%.1f damage per second)",item.stats.dps),1,1,1) end end
  if item.armor and item.armor>0 then GameTooltip:AddLine(item.armor.." Armor",1,1,1) end
  local i,k,v,e,trig,prefix
  for i=1,table.getn(AB_STAT_ORDER) do k=AB_STAT_ORDER[i]; v=item.stats and item.stats[k]; if v and v~=0 and not (k=="armor") then GameTooltip:AddLine("+"..v.." "..(AB_STAT_TOOLTIP[k] or k),1,1,1) end end
  if d[2] and d[2]>0 then GameTooltip:AddLine("Durability "..d[2].." / "..d[2],1,1,1) end
  if item.req and item.req>0 then local usable=self:GetBuildLevel()>=item.req; GameTooltip:AddLine("Requires Level "..item.req,1,usable and 1 or 0.15,usable and 1 or 0.15) end
  local classText=self:GetRequiredClassText(item.classMask); if classText then local allowed=self:IsClassAllowedRaw(self:GetRawItem(id),self.current.class); GameTooltip:AddLine("Classes: "..classText,1,allowed and 1 or 0.15,allowed and 1 or 0.15,true) end
  if d[5] and tostring(d[5])~="" and tostring(d[5])~="0" and tonumber(d[6] or 0)>0 then GameTooltip:AddLine("Requires "..d[5].." ("..d[6]..")",1,0.15,0.15) end
  if d[7] and tostring(d[7])~="" and tostring(d[7])~="0" then local reqText="Requires "..d[7]; if d[8] and tostring(d[8])~="" and tostring(d[8])~="0" then reqText=reqText.." - "..d[8] end; GameTooltip:AddLine(reqText,1,0.15,0.15) end
  if d[9] then
    for i=1,table.getn(d[9]) do
      e=d[9][i]
      if type(e)=="table" then trig=e[1]; v=e[2] else trig=1; v=e end
      if trig==0 then prefix="Use: " elseif trig==2 then prefix="Chance on hit: " elseif trig==4 then prefix="Use: " else prefix="Equip: " end
      if v and v~="" then GameTooltip:AddLine(prefix..v,0.1,1,0.1,true) end
    end
  end
  self:AddSetTooltipLines(id,item)
  if d[4] and d[4]~="" then GameTooltip:AddLine('"'..d[4]..'"',1,0.82,0,true) end
  if d[3] and d[3]>0 then GameTooltip:AddLine("Sell Price: "..self:MoneyText(d[3]),1,1,1) end
  self:AddSourceTooltipLines(id)
  GameTooltip:Show()
end

function AB:CreateSourcePanel()
  local f=CreateFrame("Frame","AshenBuildsSourcePanel",UIParent); f:SetWidth(610); f:SetHeight(650); f:SetPoint("CENTER",UIParent,"CENTER",180,0); MakeBackdrop(f); self:SetupWindow(f,{fit=true}); f:Hide(); self.sourcePanel=f
  self:ApplyEmberBackground(f,10,0.33,0.45,0.4); self:AddEmberHeader(f,36); self:AddEmberWell(f,20,-104,-20,20)
  f.title=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); f.title:SetPoint("TOPLEFT",f,"TOPLEFT",28,-22); f.title:SetWidth(520); f.title:SetJustifyH("LEFT")
  local close=CreateFrame("Button",nil,f,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",f,"TOPRIGHT",-4,-4)
  f.icon=f:CreateTexture(nil,"ARTWORK"); f.icon:SetWidth(44); f.icon:SetHeight(44); f.icon:SetPoint("TOPLEFT",f,"TOPLEFT",28,-52)
  f.meta=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); f.meta:SetPoint("TOPLEFT",f.icon,"TOPRIGHT",10,-2); f.meta:SetWidth(490); f.meta:SetJustifyH("LEFT")
  f.text=f:CreateFontString(nil,"OVERLAY","GameFontHighlight"); f.text:SetPoint("TOPLEFT",f,"TOPLEFT",30,-112); f.text:SetWidth(550); f.text:SetHeight(500); f.text:SetJustifyH("LEFT"); f.text:SetJustifyV("TOP")
end

function AB:OpenSourcePanel(id)
  local item=self:GetItem(id); if not item then return end; local ss=self:GetItemSources(id); local f=self.sourcePanel; local qc=qualityColors[item.q] or qualityColors[1]; f.title:SetText(item.n); f.title:SetTextColor(qc[1],qc[2],qc[3]); f.icon:SetTexture(item.icon); f.meta:SetText("Item #"..id.." - Item Level "..(item.ilvl or 0).." - Requires "..(item.req or 0))
  local lines={}; local i,j,s,reags
  if table.getn(ss)==0 then
    table.insert(lines,"|cffffd100SOURCE|r")
    local broad=item.source or ""
    table.insert(lines,broad~="" and ("Source category: "..broad) or "No direct source relationship is available in AshenDB.")
  end
  for i=1,table.getn(ss) do s=ss[i]; if i>1 then table.insert(lines,"") end
    if s[1]=="craft" then
      table.insert(lines,"|cffffd100CRAFTED|r"); table.insert(lines,"|cffffffffProfession:|r "..(s[4] or "Unknown")); if s[5] and s[5]>0 then table.insert(lines,"|cffffffffRequired Skill:|r "..s[5]) end; table.insert(lines,"|cffffffffRecipe:|r "..(s[3] or item.n)); reags=s[8] or {}; if table.getn(reags)>0 then table.insert(lines,""); table.insert(lines,"|cffffd100MATERIALS|r"); for j=1,table.getn(reags) do table.insert(lines,(reags[j][2] or "Item").." x"..(reags[j][3] or 1)) end end
    elseif s[1]=="drop" then
      table.insert(lines,"|cffffd100DROPPED BY|r"); table.insert(lines,"|cffffffff"..(s[3] or "Unknown Creature").."|r"); if s[4] and s[4]~="" then table.insert(lines,s[4]) end; local chance=self:FormatDropChance(s[5]); if chance then table.insert(lines,"Drop Chance: "..chance) else table.insert(lines,"Drop chance not available") end
    elseif s[1]=="more" then
      table.insert(lines,"|cff9ea5b2+"..(s[2] or 0).." additional creature drop sources omitted from the in-memory pack.|r")
    elseif s[1]=="vendor" then
      table.insert(lines,"|cffffd100SOLD BY|r"); table.insert(lines,"|cffffffff"..(s[3] or "Unknown Vendor").."|r"); if s[4] and s[4]~="" then table.insert(lines,s[4]) end
    elseif s[1]=="quest" then
      table.insert(lines,"|cffffd100QUEST REWARD|r"); table.insert(lines,"|cffffffff"..(s[3] or "Unknown Quest").."|r"); if s[4] and s[4]~="" then table.insert(lines,s[4]) end; if s[7] and s[7]>0 then table.insert(lines,"Quest Level: "..s[7]) end; if s[5]=="choice" then table.insert(lines,"Choose-one reward") end
    end
  end
  f.text:SetText(table.concat(lines,"\n")); f:Show()
end

---------------------------------------------------------------------------
-- /ab model probe: shows what this client's Dressing Room actually does.
-- Server scripts (AIO) and client mods can replace DressUpItemLink, so this
-- watches every model frame and the panel functions while calling it the way
-- Atlas does, then prints each call with its frame and arguments.

local WATCHED = {"TryOn", "SetUnit", "Undress", "Dress", "SetModel", "SetCreature", "SetDisplayInfo", "SetItem", "SetItemAppearance"}
local MODEL_TYPES = {DressUpModel = true, PlayerModel = true, Model = true, TabardModel = true, CinematicModel = true}

local function Describe(v)
  if type(v) == "string" then return '"' .. v .. '"' end
  if type(v) == "table" and v.GetName then return v:GetName() or "<unnamed frame>" end
  return tostring(v)
end

local function Args(list)
  local out, i = {}, nil
  for i = 1, table.getn(list) do table.insert(out, Describe(list[i])) end
  return table.concat(out, ", ")
end

local function ModelFrames()
  local frames, f = {}, nil
  if EnumerateFrames then
    f = EnumerateFrames()
    while f do
      if f.GetObjectType and MODEL_TYPES[f:GetObjectType()] then table.insert(frames, f) end
      f = EnumerateFrames(f)
    end
  elseif DressUpModel then
    table.insert(frames, DressUpModel)
  end
  return frames
end

function AB:ProbeDressingRoom(slot)
  slot = slot and string.upper(slot) or nil
  local id = (slot and self.current.items[slot]) or self.current.items.CHEST or self.current.items.HEAD or 16963
  local link = "item:" .. id .. ":0:0:0"
  local log, wrapped, i, j = {}, {}, nil, nil
  local frames = ModelFrames()

  -- Wrap the watched methods on every model frame (instance fields shadow the shared methods).
  for i = 1, table.getn(frames) do
    local f = frames[i]
    for j = 1, table.getn(WATCHED) do
      local name = WATCHED[j]
      local original = f[name]
      if type(original) == "function" then
        f[name] = function(self, a1, a2, a3, a4)
          table.insert(log, Describe(self) .. ":" .. name .. "(" .. Args({a1, a2, a3, a4}) .. ")")
          return original(self, a1, a2, a3, a4)
        end
        table.insert(wrapped, {f, name})
      end
    end
  end
  local oldShow = ShowUIPanel
  if oldShow then ShowUIPanel = function(frame, a2) table.insert(log, "ShowUIPanel(" .. Describe(frame) .. ")"); return oldShow(frame, a2) end end

  self.Print("Model probe: " .. table.getn(frames) .. " model frames watched. DressUpItemLink is a " .. type(DressUpItemLink) .. ".")
  self:ReturnModel()
  local ok, err = pcall(function() DressUpItemLink(link) end)

  for i = 1, table.getn(wrapped) do wrapped[i][1][wrapped[i][2]] = nil end
  ShowUIPanel = oldShow

  if not ok then self.Print("DressUpItemLink(" .. link .. ") raised: " .. tostring(err)) end
  if table.getn(log) == 0 then self.Print("DressUpItemLink(" .. link .. ") made no model calls.") end
  for i = 1, table.getn(log) do self.Print("  " .. i .. ". " .. log[i]) end
  self.Print("Please screenshot these lines. The Dressing Room should now be showing that item.")
end
