-- v1.1 Dark Arcane Blizzard: compact, Vanilla 1.12 compatible manager.
local WCF=WorldChatFilter
local panel,entryInput,inputLabel,listTitle,listCount,modeLabel,hint,emptyHint,pageLabel
local enabledButton,partialButton,wholeButton,prevButton,nextButton
local rows,tabs={},{}
local activeTab="players"
local pages={players=1,phrases=1}
local wholeWord=false
local perPage=6

local P={
  base={0.06,0.08,0.12}, bronze={0.37,0.32,0.25},
  normal={0.11,0.14,0.19}, hover={0.18,0.21,0.25},
  active={0.22,0.20,0.16}, quiet={0.08,0.10,0.14},
  gold={0.82,0.72,0.50}, text={0.89,0.87,0.81},
  muted={0.67,0.68,0.70}, sage={0.48,0.77,0.62}
}
local function setRGB(frame,fn,rgb,alpha)
  frame[fn](frame,rgb[1],rgb[2],rgb[3],alpha or 1)
end
local function label(parent,font,text,x,y,width,color)
  local fs=parent:CreateFontString(nil,"OVERLAY",font)
  fs:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
  fs:SetWidth(width)
  fs:SetHeight(20)
  fs:SetJustifyH("LEFT")
  fs:SetText(text or "")
  if color then setRGB(fs,"SetTextColor",color) end
  return fs
end

local function style(btn,hover)
  local c,b,t=P.normal,P.bronze,P.text
  if btn.wcfDisabled then c=P.quiet t=P.muted
  elseif btn.wcfSelected then c=P.active b=P.gold t=P.gold
  elseif hover then c=P.hover b=P.gold t=P.gold
  elseif btn.wcfQuiet then c=P.quiet end
  setRGB(btn,"SetBackdropColor",c,0.96)
  setRGB(btn,"SetBackdropBorderColor",b,0.84)
  setRGB(btn.wcfFont,"SetTextColor",t)
end
local function button(parent,title,x,y,width,onclick,quiet)
  -- Never use red UIPanelButtonTemplate. All our controls share this skin.
  local b=CreateFrame("Button",nil,parent)
  b:SetWidth(width)
  b:SetHeight(25)
  b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
  b:SetBackdrop({
    bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
    tile=true,tileSize=16,edgeSize=11,
    insets={left=3,right=3,top=3,bottom=3}
  })
  local font=b:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
  font:SetPoint("CENTER",b,"CENTER",0,0)
  b:SetFontString(font)
  b.wcfFont=font
  b.wcfQuiet=quiet==true
  b.wcfSelected=false
  b.wcfDisabled=false
  b:SetText(title or "")
  b:SetScript("OnClick",onclick)
  b:SetScript("OnEnter",function() style(b,true) end)
  b:SetScript("OnLeave",function() style(b,false) end)
  style(b,false)
  return b
end
local function selectButton(b,v)
  b.wcfSelected=v==true
  style(b,false)
end
local function available(b,v)
  b.wcfDisabled=not v
  if v then b:Enable() else b:Disable() end
  style(b,false)
end
local function tabItems()
  if activeTab=="players" then return WCF.db.blockedPlayers end
  return WCF.db.blockedPhrases
end

local function addEntry()
  local ok,value
  if activeTab=="players" then
    ok,value=WCF.AddBlockedPlayer(entryInput:GetText())
  else
    ok,value=WCF.AddBlockedPhrase(entryInput:GetText(),wholeWord)
  end
  if ok then
    entryInput:SetText("")
    entryInput:ClearFocus()
    pages[activeTab]=math.max(1,math.ceil(table.getn(tabItems())/perPage))
    WCF.Print((activeTab=="players" and "Blocked World player: " or
             "Blocked World phrase: ")..value)
    WCF.RefreshCustomFiltersUI()
  else
    WCF.Print(value or "Unable to add custom filter.")
  end
end

function WCF.SetCustomFiltersTab(tab)
  if tab~="players" and tab~="phrases" then return false end
  if not panel then WCF.BuildCustomFiltersUI() end
  if not panel then return false end
  if activeTab~=tab then
    entryInput:ClearFocus()
    entryInput:SetText("")
  end
  activeTab=tab
  panel.selectedTab=(tab=="players" and 1 or 2)
  WCF.RefreshCustomFiltersUI()
  return true
end

function WCF.RefreshCustomFiltersUI()
  if not panel or not WCF.db then return end
  local isPhrase=activeTab=="phrases"
  enabledButton:SetText(WCF.db.customEnabled and "Enabled" or "Disabled")
  selectButton(enabledButton,WCF.db.customEnabled)
  setRGB(enabledButton.wcfDot,"SetVertexColor",
         WCF.db.customEnabled and P.sage or P.muted)
  selectButton(tabs[1],not isPhrase)
  selectButton(tabs[2],isPhrase)
  if isPhrase then
    tabs[1].underline:Hide()
    tabs[2].underline:Show()
  else
    tabs[1].underline:Show()
    tabs[2].underline:Hide()
  end
  inputLabel:SetText(isPhrase and "Add word or phrase" or "Add player")
  listTitle:SetText(isPhrase and "Blocked Words / Phrases" or "Blocked Players")
  if isPhrase then
    modeLabel:Show()
    partialButton:Show()
    wholeButton:Show()
    hint:Hide()
  else
    modeLabel:Hide()
    partialButton:Hide()
    wholeButton:Hide()
    hint:Show()
  end
  selectButton(partialButton,not wholeWord)
  selectButton(wholeButton,wholeWord)

  local items=tabItems()
  local count=table.getn(items)
  listCount:SetText(tostring(count)..(count==1 and " entry" or " entries"))
  local maxPage=math.max(1,math.ceil(count/perPage))
  if pages[activeTab]>maxPage then pages[activeTab]=maxPage end
  local i
  for i=1,perPage do
    local item=items[(pages[activeTab]-1)*perPage+i]
    local row=rows[i]
    if item then
      row.value=isPhrase and item.text or item
      local text=isPhrase and (item.text .. (item.wholeWord and
             "  |cffd1b77f[whole word]|r" or "  |cffd1b77f[partial]|r")) or item
      row.label:SetText(text)
      row.background:Show()
      row.remove:Show()
    else
      row.value=nil
      row.label:SetText("")
      row.background:Hide()
      row.remove:Hide()
    end
  end
  if count==0 then emptyHint:Show() else emptyHint:Hide() end
  pageLabel:SetText("Page "..pages[activeTab].." / "..maxPage)
  available(prevButton,pages[activeTab]>1)
  available(nextButton,pages[activeTab]<maxPage)
end

function WCF.BuildCustomFiltersUI()
  if panel then return panel end
  if not WCF.db then WCF.Initialize() end
  local f=CreateFrame("Frame","WorldChatFilterCustomFiltersFrame",UIParent)
  f:SetWidth(530)
  f:SetHeight(463)
  f:SetPoint("CENTER",UIParent,"CENTER",0,0)
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart",function() f:StartMoving() end)
  f:SetScript("OnDragStop",function() f:StopMovingOrSizing() end)
  f:SetBackdrop({
    bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
    tile=true,tileSize=16,edgeSize=32,
    insets={left=11,right=12,top=12,bottom=11}
  })
  setRGB(f,"SetBackdropColor",P.base,0.99)
  -- Extra charcoal layer stops the world scene showing through the manager.
  local veil=f:CreateTexture(nil,"BACKGROUND")
  veil:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
  veil:SetVertexColor(0.05,0.07,0.10,0.92)
  veil:SetPoint("TOPLEFT",f,"TOPLEFT",12,-12)
  veil:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-12,12)
  f:Hide()
  panel=f
  local close=CreateFrame("Button","WorldChatFilterCustomFiltersClose",f,"UIPanelCloseButton")
  close:SetPoint("TOPRIGHT",f,"TOPRIGHT",-5,-5)
  close:SetScript("OnClick",function() f:Hide() end)

  label(f,"GameFontNormalLarge","World Chat Filter",23,-23,250,P.gold)
  label(f,"GameFontHighlightSmall","CUSTOM FILTERS",290,-26,180,P.sage)
  label(f,"GameFontHighlightSmall",
        "Only /World is affected. Other channels and whispers are untouched.",
        26,-54,475,P.muted)
  label(f,"GameFontNormal","Custom filtering",30,-85,161,P.text)
  enabledButton=button(f,"Enabled",192,-79,116,function()
    WCF.db.customEnabled=not WCF.db.customEnabled
    if WCF.InvalidateMessageCache then WCF.InvalidateMessageCache() end
    WCF.RefreshCustomFiltersUI()
  end)
  f.customState=enabledButton
  local dot=enabledButton:CreateTexture(nil,"ARTWORK")
  dot:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
  dot:SetWidth(7)
  dot:SetHeight(7)
  dot:SetPoint("LEFT",enabledButton,"LEFT",9,0)
  enabledButton.wcfDot=dot
  label(f,"GameFontHighlightSmall","Saved per character",353,-83,150,P.muted)

  tabs[1]=button(f,"Blocked Players",27,-119,233,function()
    WCF.SetCustomFiltersTab("players")
  end)
  tabs[2]=button(f,"Words & Phrases",270,-119,233,function()
    WCF.SetCustomFiltersTab("phrases")
  end)
  local _,tab
  for _,tab in ipairs(tabs) do
    tab:SetHeight(31)
    local line=tab:CreateTexture(nil,"ARTWORK")
    line:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    line:SetVertexColor(P.gold[1],P.gold[2],P.gold[3],0.95)
    line:SetWidth(200)
    line:SetHeight(2)
    line:SetPoint("BOTTOM",tab,"BOTTOM",0,3)
    tab.underline=line
  end
  f.selectedTab=1

  inputLabel=label(f,"GameFontNormal","",31,-162,400,P.gold)
  -- One named InputBoxTemplate keeps Vanilla's $parentMiddle texture intact.
  entryInput=CreateFrame("EditBox","WorldChatFilterCustomEntryInput",f,"InputBoxTemplate")
  entryInput:SetWidth(340)
  entryInput:SetHeight(22)
  entryInput:SetPoint("TOPLEFT",f,"TOPLEFT",34,-190)
  entryInput:SetAutoFocus(false)
  entryInput:SetMaxLetters(120)
  entryInput:SetScript("OnEscapePressed",function() entryInput:ClearFocus() end)
  entryInput:SetScript("OnEnterPressed",addEntry)
  button(f,"+  Add",399,-188,96,addEntry)

  hint=label(f,"GameFontHighlightSmall",
         "Right-click a player's name in chat to block them from /World.",
         31,-223,460,P.muted)
  modeLabel=label(f,"GameFontHighlightSmall","Matching method",31,-223,205,P.muted)
  partialButton=button(f,"Partial",288,-219,98,function()
    wholeWord=false
    WCF.RefreshCustomFiltersUI()
  end)
  wholeButton=button(f,"Whole word",391,-219,105,function()
    wholeWord=true
    WCF.RefreshCustomFiltersUI()
  end)
  listTitle=label(f,"GameFontNormal","",31,-259,345,P.gold)
  listCount=label(f,"GameFontHighlightSmall","",418,-259,85,P.muted)

  local i
  for i=1,perPage do
    local row={}
    local top=-282-(i-1)*24
    local bg=f:CreateTexture(nil,"BACKGROUND")
    bg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    bg:SetVertexColor(0.13,0.16,0.22,i%2==0 and 0.71 or 0.50)
    bg:SetWidth(473)
    bg:SetHeight(23)
    bg:SetPoint("TOPLEFT",f,"TOPLEFT",28,top)
    row.background=bg
    row.label=label(f,"GameFontHighlightSmall","",40,top-2,345,P.text)
    row.remove=button(f,"Remove",416,top,77,function()
      if row.value then
        if activeTab=="players" then WCF.RemoveBlockedPlayer(row.value)
        else WCF.RemoveBlockedPhrase(row.value) end
      end
    end,true)
    row.remove:SetHeight(21)
    row.remove:Hide()
    bg:Hide()
    rows[i]=row
  end
  emptyHint=label(f,"GameFontHighlightSmall",
                  "No blocked entries yet. Add one above to get started.",
                  43,-306,440,P.muted)
  prevButton=button(f,"< Previous",31,-432,113,function()
    if pages[activeTab]>1 then
      pages[activeTab]=pages[activeTab]-1
      WCF.RefreshCustomFiltersUI()
    end
  end,true)
  nextButton=button(f,"Next >",386,-432,113,function()
    pages[activeTab]=pages[activeTab]+1
    WCF.RefreshCustomFiltersUI()
  end,true)
  pageLabel=label(f,"GameFontHighlightSmall","",223,-433,135,P.muted)
  WCF.RefreshCustomFiltersUI()
  return f
end

function WCF.ToggleCustomFiltersUI()
  local f=WCF.BuildCustomFiltersUI()
  if f:IsShown() then f:Hide()
  else
    if type(CloseDropDownMenus)=="function" then CloseDropDownMenus() end
    WCF.RefreshCustomFiltersUI()
    f:Show()
  end
end
