-- v1.1 regression: shared Dark Arcane Statistics and Help/Commands UI.
table.getn=table.getn or function(t) return #t end
SlashCmdList={}
local messages,frames,menuEntries={},{},{}
DEFAULT_CHAT_FRAME={AddMessage=function(_,s) table.insert(messages,s) end}
function UnitName() return "Tester" end
local function mock(kind,name,parent,template)
  local f={kind=kind,name=name,parent=parent,template=template,
           scripts={},text="",visible=true,enabled=true}
  function f:GetName() return self.name end
  function f:SetPoint(...) self.point={...} end
  function f:SetWidth(n) self.width=n end
  function f:SetHeight(n) self.height=n end
  function f:SetText(t) self.text=t end
  function f:GetText() return self.text end
  function f:SetTextColor(r,g,b,a) self.textColor={r,g,b,a} end
  function f:SetJustifyH(j) self.justify=j end
  function f:SetFontString(fs) self.fontString=fs end
  function f:SetTexture(value) self.texture=value end
  function f:SetVertexColor(r,g,b,a) self.vertex={r,g,b,a} end
  function f:SetBackdrop(x) self.backdrop=x end
  function f:SetBackdropColor(r,g,b,a) self.bgColor={r,g,b,a} end
  function f:SetBackdropBorderColor(r,g,b,a) self.borderColor={r,g,b,a} end
  function f:SetFrameStrata() end
  function f:EnableMouse() end
  function f:SetMovable() end
  function f:RegisterForDrag() end
  function f:RegisterEvent() end
  function f:StartMoving() end
  function f:StopMovingOrSizing() end
  function f:Enable() self.enabled=true end
  function f:Disable() self.enabled=false end
  function f:SetScript(key,fn) self.scripts[key]=fn end
  function f:GetScript(key) return self.scripts[key] end
  function f:Show() self.visible=true end
  function f:Hide()
    self.visible=false
    if self.scripts.OnHide then self.scripts.OnHide() end
  end
  function f:IsShown() return self.visible end
  function f:CreateFontString(...) return mock("FontString",nil,self) end
  function f:CreateTexture(...) return mock("Texture",nil,self) end
  frames[#frames+1]=f
  if name then _G[name]=f end
  return f
end
UIParent=mock("Frame","UIParent")
function CreateFrame(kind,name,parent,template)
  return mock(kind,name,parent,template)
end
function getglobal(name) return _G[name] end
local menuInit,closed=nil,0
function UIDropDownMenu_Initialize(frame,callback) menuInit=callback end
function UIDropDownMenu_CreateInfo() return {} end
function UIDropDownMenu_AddButton(info,level)
  menuEntries[#menuEntries+1]={info=info,level=level}
end
function CloseDropDownMenus() closed=closed+1 end
WorldChatFilterDB={enabled=true,sensitivity="balanced",
  stats={total=14,Trade=4,LFG=6,Guild=1,Services=2,Repeats=1,Custom=0}}
for _,file in ipairs({"Core.lua","PanelTheme.lua","Statistics.lua","HelpUI.lua","UI.lua"}) do
  dofile(file)
end
local W=WorldChatFilter
W.Initialize()
local T=W.PanelTheme
assert(T and T.Panel and T.Button and T.Label,"shared theme must be available")
local session,all=W.GetStats()
assert(all.total==14 and all.LFG==6,"saved statistics should be preserved")

local stats=W.BuildStatsUI()
assert(stats==WorldChatFilterStatisticsFrame and stats.width==530
       and stats.height==462 and stats.bgColor[4]>=0.98,
       "statistics should use opaque Dark Arcane layout")
assert(stats.backdrop and stats.backdrop.edgeFile:find("DialogBox%-Border"),
       "statistics must share native Blizzard border")
local function buttonsWithText(text)
  local found={}
  for _,f in ipairs(frames) do
    if f.kind=="Button" and f:GetText()==text then
      found[#found+1]=f
    end
  end
  return found
end
local function labelWithText(text)
  local found={}
  for _,f in ipairs(frames) do
    if f.kind=="FontString" and f:GetText()==text then
      found[#found+1]=f
    end
  end
  return found
end
assert(#labelWithText("Repeated Messages")>=1 and #labelWithText("Custom")>=1,
       "all six categories must be visible")
local sessionReset=buttonsWithText("Reset Session")[1]
local allReset=buttonsWithText("Reset All")[1]
assert(sessionReset and allReset and not sessionReset.template and not allReset.template
       and sessionReset.borderColor and allReset.borderColor,
       "statistics reset controls must use dark buttons instead of red templates")
W.ToggleStatsUI()
assert(stats:IsShown(),"statistics should open with slash command")
assert(#labelWithText("14")>=1,"saved all-time total should be displayed")
W.RecordHiddenMessage("Custom")
session,all=W.GetStats()
assert(session.Custom==1 and all.Custom==1 and all.total==15,
       "custom block must increment correct counters")
assert(#labelWithText("15")>=1,"all-time labels must update while window is shown")
sessionReset.scripts.OnClick()
session,all=W.GetStats()
assert(session.total==0 and all.total==15 and all.Custom==1,
       "Reset Session must preserve lifetime counters")
local oldChats=#messages
allReset.scripts.OnClick()
assert(allReset:GetText()=="Confirm Reset" and W.GetStats().total==0,
       "first click must only request confirmation")
local _,totalBefore=W.GetStats()
assert(totalBefore.total==15,"first click must never delete lifetime stats")
assert(#messages==oldChats,"reset confirmation must stay in UI, not chat")
W.ToggleStatsUI()
assert(not stats:IsShown() and allReset:GetText()=="Reset All",
       "closing stats should cancel the pending reset")
W.ToggleStatsUI()
allReset.scripts.OnClick()
allReset.scripts.OnClick()
local current,lifetime=W.GetStats()
assert(current.total==0 and lifetime.total==0 and lifetime.Custom==0,
       "confirmed reset must clear session and all-time stats")
assert(allReset:GetText()=="Reset All","confirmed reset should restore button")

-- The help panel should NEVER print command lists into the chat.
local helpMessages=#messages
SlashCmdList.WORLDCHATFILTER("help")
local help=WorldChatFilterHelpFrame
assert(help and help:IsShown() and help.width==620 and help.height==535,
       "/wcf help should open an on-screen panel")
assert(#messages==helpMessages,"/wcf help must not spam chat")
assert(help.bgColor and help.bgColor[4]>=0.98,
       "help must share the Statistics and Custom Filters theme")
assert(help.selectedPage=="general","General commands should open by default")
assert(#labelWithText("/wcf toggle")==1,"General page must show macro toggle")
assert(#labelWithText("/wcf stats")==1,"General page must include stats shortcut")
assert(#labelWithText("/wcf mode <level>")==1,"General page must include sensitivity")
local customTab,toolsTab,generalTab
for _,f in ipairs(frames) do
  if f.kind=="Button" and f:GetText()=="Custom Filters" then customTab=f end
  if f.kind=="Button" and f:GetText()=="Tools" then toolsTab=f end
  if f.kind=="Button" and f:GetText()=="General" then generalTab=f end
end
assert(customTab and toolsTab and generalTab,"three coherent Help tabs required")
assert(customTab.borderColor and toolsTab.borderColor
       and customTab.template==nil and generalTab.fontString,
       "Help tabs must be custom bronze/arcane controls")
customTab.scripts.OnClick()
assert(help.selectedPage=="custom" and #labelWithText("/wcf block player NAME")==1,
       "Custom page must list player blocking")
assert(#labelWithText("/wcf block word PHRASE")==1,
       "Custom page must explain whole-word blocking")
toolsTab.scripts.OnClick()
assert(help.selectedPage=="tools","Tools page must open")
assert(#labelWithText("/wcf test <message>")==1,"Tools page lists classifier test")
assert(#labelWithText("/wcf channeldebug")==1,"Tools page lists diagnostics")
assert(#labelWithText("/wcf explain <message>")==0,
       "do not advertise a nonexistent explain command")
assert(not W.SelectHelpPage("unknown"),"reject invalid Help page")
W.Help()
assert(not help:IsShown(),"Help function should toggle existing window")
W.Help()
assert(help:IsShown() and #messages==helpMessages,
       "Help function should reopen panel with no chat spam")

-- The existing dropdown Help / Commands item should route to the panel.
W.BuildUI()
assert(menuInit,"Settings dropdown should initialize")
menuEntries={}
menuInit(nil,1)
local menuHelp=nil
for _,entry in ipairs(menuEntries) do
  if entry.info.text=="Help / Commands" then menuHelp=entry.info end
end
assert(menuHelp and type(menuHelp.func)=="function","Help menu entry missing")
menuHelp.func()
assert(not help:IsShown() and #messages==helpMessages,
       "menu Help / Commands should toggle panel without chat")
-- Command list remains stored on the page and is readable without chat.
assert(W.db.stats.total==0 and W.db.enabled==true,
       "UI redesign must preserve saved filter configuration")
print("PASS v1.1 Dark Arcane Stats and Help panels, category counters, safe reset, real commands, no chat spam")
