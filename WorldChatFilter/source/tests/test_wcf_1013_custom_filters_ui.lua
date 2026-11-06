-- Vanilla 1.12 two-tab Custom Filters GUI regression.
-- Mock the existing Blizzard TabButtonTemplate / PanelTemplates contract.
table.getn = table.getn or function(t) return #t end
SlashCmdList = {}
DEFAULT_CHAT_FRAME = {AddMessage=function() end}
function UnitName() return "Tester" end
local frames={}
local function mock(kind,name,parent,template)
  local f={kind=kind,name=name,parent=parent,template=template,scripts={},
           text="",visible=true,enabled=true}
  function f:GetName() return self.name end
  function f:SetPoint(...) self.point={...} end
  function f:SetWidth(x) self.width=x end
  function f:SetHeight(x) self.height=x end
  function f:SetText(x) self.text=x end
  function f:GetText() return self.text end
  function f:Show() self.visible=true end
  function f:Hide() self.visible=false end
  function f:IsShown() return self.visible end
  function f:Enable() self.enabled=true end
  function f:Disable() self.enabled=false end
  function f:EnableMouse() end
  function f:SetMovable() end
  function f:RegisterForDrag() end
  function f:RegisterEvent() end
  function f:SetFrameStrata() end
  function f:SetBackdrop(x) self.backdrop=x end
  function f:SetBackdropColor(r,g,b,a) self.backdropColor={r,g,b,a} end
  function f:SetBackdropBorderColor(r,g,b,a) self.backdropBorderColor={r,g,b,a} end
  function f:SetTextColor(r,g,b,a) self.textColor={r,g,b,a} end
  function f:SetFontString(font) self.fontString=font end
  function f:SetAutoFocus() end
  function f:SetMaxLetters(x) self.maxLetters=x end
  function f:ClearFocus() self.unfocused=true end
  function f:SetScript(name,fn) self.scripts[name]=fn end
  function f:GetScript(name) return self.scripts[name] end
  function f:SetTexture(value) self.texture=value end
  function f:SetVertexColor(r,g,b,a) self.vertex={r,g,b,a} end
  function f:CreateFontString()
    local result=mock("FontString",nil,self)
    function result:SetJustifyH() end
    return result
  end
  function f:CreateTexture()
    return mock("Texture",nil,self)
  end
  function f:StartMoving() end
  function f:StopMovingOrSizing() end
  frames[#frames+1]=f
  if name then _G[name]=f end
  return f
end
UIParent=mock("Frame","UIParent",nil)
function CreateFrame(kind,name,parent,template) return mock(kind,name,parent,template) end
function getglobal(name) return _G[name] end
local entries,closed={},0
function UIDropDownMenu_CreateInfo() return {} end
function UIDropDownMenu_AddButton(info,level)
  entries[#entries+1]={info=info,level=level}
end
function UIDropDownMenu_Initialize(frame,fn) frame.initialize=fn end
function CloseDropDownMenus() closed=closed+1 end
local resized={}
function PanelTemplates_TabResize(_,tab,width) resized[tab:GetName()]=width end
function PanelTemplates_SetNumTabs(frame,n) frame.numTabs=n end
function PanelTemplates_SetTab(frame,id)
  assert(frame.numTabs==2 and id>=1 and id<=2,"bad native tab index")
  frame.selectedTab=id
end

WorldChatFilterDB=nil
for _,name in ipairs({"Core.lua","CustomFilters.lua","CustomFiltersUI.lua","UI.lua"}) do dofile(name) end
local W=WorldChatFilter
W.Initialize()
W.BuildUI()
assert(WorldChatFilterSettingsDropdown.initialize,"settings menu missing")
entries={}
WorldChatFilterSettingsDropdown.initialize(nil,1)
local menuItem
for _,item in ipairs(entries) do
 if item.info.text=="Custom Filters" then menuItem=item.info end
end
assert(menuItem and menuItem.hasArrow and menuItem.value=="custom","missing Custom Filters submenu")
entries={}
UIDROPDOWNMENU_MENU_VALUE="custom"
WorldChatFilterSettingsDropdown.initialize(nil,2)
local enabled,manager
for _,item in ipairs(entries) do
 if item.info.text=="Enable Custom Filters" then enabled=item.info end
 if item.info.text=="Manage Blocked Players & Phrases..." then manager=item.info end
end
assert(enabled and manager and type(manager.func)=="function","submenu controls missing")
manager.func()
local panel=WorldChatFilterCustomFiltersFrame
assert(panel and panel:IsShown() and closed==1,"manager should open from dropdown")
assert(panel.width==530 and panel.height==463,"manager must use compact layout")
assert(panel.backdropColor and panel.backdropColor[4]>=0.95,
       "window background should obscure the game behind it")
assert(panel.customState:GetText()=="Enabled","custom status initial")
assert(panel.customState.template==nil and panel.customState.backdropBorderColor,
       "status must be a dark custom button without the red Blizzard template")
assert(panel.customState.wcfDot and panel.customState.wcfDot.vertex[2]>0.7,
       "enabled indicator must be muted sage green")
local tab1,tab2
for _,frame in ipairs(frames) do
 if frame.kind=="Button" and frame.text=="Blocked Players" then tab1=frame end
 if frame.kind=="Button" and frame.text=="Words & Phrases" then tab2=frame end
end
assert(tab1 and tab2,"dark custom tabs missing")
assert(tab1.template==nil and tab2.template==nil and
       tab1.fontString and tab2.fontString and
       tab1.backdrop and tab2.backdrop,
       "tabs must use coherent custom Arcane styling instead of native red elements")
assert(tab1.underline:IsShown() and not tab2.underline:IsShown(),
       "selected tab should have a subtle gold underline")
assert(panel.selectedTab==1,"default tab must be Players")
local input=WorldChatFilterCustomEntryInput
assert(input and input.template=="InputBoxTemplate" and input.maxLetters==120,
       "must use one named input to avoid Vanilla $parent texture collisions")
local add,partial,whole,prev,next,removes=nil,nil,nil,nil,nil,{}
for _,frame in ipairs(frames) do
 if frame.kind=="Button" then
  if frame.text=="+  Add" then add=frame end
  if frame.text=="Partial" then partial=frame end
  if frame.text=="Whole word" then whole=frame end
  if frame.text=="< Previous" then prev=frame end
  if frame.text=="Next >" then next=frame end
  if frame.text=="Remove" then removes[#removes+1]=frame end
 end
end
assert(add and partial and whole and prev and next and #removes==6,
       "one Add, segmented match controls, six row buttons, and pagination required")
assert(not partial:IsShown() and not whole:IsShown(),"matching hidden on Players tab")
for _,frame in ipairs(frames) do
 if frame.kind=="Button" and frame~=WorldChatFilterCustomFiltersClose then
  assert(frame.template~= "UIPanelButtonTemplate" and frame.fontString and
         frame.backdrop and frame.backdropBorderColor,
         "every custom control should use the dark Arcane skin")
 end
end
local firstColor=add.backdropColor
add.scripts.OnEnter()
assert(add.backdropColor[1]>firstColor[1],"hover should lighten Add button")
add.scripts.OnLeave()
assert(math.abs(add.backdropColor[1]-firstColor[1])<0.000001,
       "hover style should restore after mouse leaves")
local function hasLabel(fragment)
 for _,frame in ipairs(frames) do
  if frame.kind=="FontString" and string.find(frame.text,fragment,1,true) then
    return true
  end
 end
 return false
end
input:SetText("ChatSpammer")
add.scripts.OnClick()
assert(W.IsBlockedPlayer("chatspammer") and input:GetText()=="","GUI must add player")
assert(hasLabel("ChatSpammer"),"player row should display saved player")
assert(removes[1]:IsShown(),"active row should have Remove button")
-- Tab switching updates shared input, switches list and shows match controls.
input:SetText("unsaved value")
tab2.scripts.OnClick()
assert(panel.selectedTab==2 and input:GetText()=="","switching tabs clears unsafe pending entry")
assert(partial:IsShown() and whole:IsShown(),"segmented matching must show on phrases")
assert(not tab1.underline:IsShown() and tab2.underline:IsShown(),
       "gold underline must move to active Words tab")
assert(not hasLabel("ChatSpammer"),"Players must not appear under Words/Phrases")
input:SetText("discord.gg")
add.scripts.OnClick()
assert(#W.db.blockedPhrases==1 and W.db.blockedPhrases[1].text=="discord.gg"
       and W.db.blockedPhrases[1].wholeWord==false,"partial phrase saved")
assert(hasLabel("discord.gg") and hasLabel("[partial]"),"phrase row and match mode")
whole.scripts.OnClick()
assert(whole.wcfSelected and not partial.wcfSelected,
       "Whole word option must become the selected segment")
input:SetText("Boost")
input.scripts.OnEnterPressed()
assert(#W.db.blockedPhrases==2 and W.db.blockedPhrases[2].wholeWord==true,
       "Enter should add whole-word phrase")
assert(hasLabel("[whole word]"),"whole word matching label visible")
-- UI changes must not silently erase the other tab's entries.
tab1.scripts.OnClick()
assert(panel.selectedTab==1 and not partial:IsShown() and not whole:IsShown(),
       "Players tab restored with no phrase-only controls")
assert(hasLabel("ChatSpammer") and W.IsBlockedPlayer("ChatSpammer"),
       "player entries persist across tab switches")
removes[1].scripts.OnClick()
assert(not W.IsBlockedPlayer("chatspammer"),"Remove player from active tab")
tab2.scripts.OnClick()
assert(#W.db.blockedPhrases==2 and hasLabel("Boost"),
       "phrase entries must survive switching back")
removes[1].scripts.OnClick()
assert(#W.db.blockedPhrases==1 and W.db.blockedPhrases[1].text=="Boost",
       "Remove should act only on the active tab")

-- Pagination is independent for each tab, supports deleting last entries.
tab1.scripts.OnClick()
for i=1,8 do assert(W.AddBlockedPlayer("Tester"..i)) end
assert(not prev.enabled and next.enabled,"first page should allow next only")
next.scripts.OnClick()
assert(prev.enabled and not next.enabled,"second page should allow previous only")
assert(hasLabel("Page 2 / 2") and hasLabel("Tester7"),
       "second page must show final players and page number")
removes[1].scripts.OnClick()
removes[1].scripts.OnClick()
assert(hasLabel("Page 1 / 1") and not next.enabled,
       "after deleting last page, page index must clamp automatically")
tab2.scripts.OnClick()
assert(hasLabel("Page 1 / 1"),"phrases should retain their own pagination")
assert(W.SetCustomFiltersTab("invalid")==false,"reject unknown tabs")

enabled.func()
assert(not W.db.customEnabled,"submenu should disable custom filtering")
W.RefreshCustomFiltersUI()
assert(panel.customState:GetText()=="Disabled","UI should reflect submenu state")
assert(panel.customState.wcfDot.vertex[1]==0.67,
       "disabled indicator should turn neutral gray")
enabled.func()
assert(W.db.customEnabled,"submenu should enable custom filtering")
W.ToggleCustomFiltersUI()
assert(not panel:IsShown(),"manager should close")
W.ToggleCustomFiltersUI()
assert(panel:IsShown(),"manager should re-open")
assert(W.IsBlockedPlayer("Tester1") and #W.db.blockedPhrases==1,
       "all saved entries must survive window toggles")
print("PASS v1.1 Dark Arcane skin, matching segments, player/phrase tabs, pagination, opaque layout and GUI persistence")
