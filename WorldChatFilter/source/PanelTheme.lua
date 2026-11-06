-- WorldChatFilter v1.1: shared Dark Arcane visual primitives.
-- Uses only the Vanilla WoW 1.12 FrameXML APIs and built-in textures.
local WCF=WorldChatFilter
local T={}
WCF.PanelTheme=T

T.colors={
  base={0.06,0.08,0.12}, bronze={0.37,0.32,0.25},
  normal={0.11,0.14,0.19}, hover={0.18,0.21,0.25},
  active={0.22,0.20,0.16}, quiet={0.08,0.10,0.14},
  gold={0.82,0.72,0.50}, text={0.89,0.87,0.81},
  muted={0.67,0.68,0.70}, sage={0.48,0.77,0.62},
  stripe={0.13,0.16,0.22}
}
local P=T.colors
function T.RGB(frame,method,color,alpha)
  frame[method](frame,color[1],color[2],color[3],alpha or 1)
end

function T.Label(parent,font,caption,x,y,width,color,justify)
  local f=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlightSmall")
  f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
  f:SetWidth(width)
  f:SetHeight(20)
  f:SetJustifyH(justify or "LEFT")
  f:SetText(caption or "")
  if color then T.RGB(f,"SetTextColor",color) end
  return f
end

function T.StyleButton(b,hover)
  local color,border,foreground=P.normal,P.bronze,P.text
  if b.wcfDisabled then
    color,foreground=P.quiet,P.muted
  elseif b.wcfSelected then
    color,border,foreground=P.active,P.gold,P.gold
  elseif hover then
    color,border,foreground=P.hover,P.gold,P.gold
  elseif b.wcfQuiet then
    color=P.quiet
  end
  T.RGB(b,"SetBackdropColor",color,0.96)
  T.RGB(b,"SetBackdropBorderColor",border,0.84)
  T.RGB(b.wcfFont,"SetTextColor",foreground)
end

function T.Button(parent,caption,x,y,width,callback,quiet,name)
  -- Plain dark button: the stock UIPanelButtonTemplate has a red texture.
  local b=CreateFrame("Button",name,parent)
  b:SetWidth(width)
  b:SetHeight(25)
  b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
  b:SetBackdrop({
    bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
    tile=true,tileSize=16,edgeSize=11,
    insets={left=3,right=3,top=3,bottom=3}
  })
  local text=b:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
  text:SetPoint("CENTER",b,"CENTER",0,0)
  b:SetFontString(text)
  b.wcfFont=text
  b.wcfSelected=false
  b.wcfDisabled=false
  b.wcfQuiet=quiet==true
  b:SetText(caption or "")
  b:SetScript("OnClick",callback)
  b:SetScript("OnEnter",function() T.StyleButton(b,true) end)
  b:SetScript("OnLeave",function() T.StyleButton(b,false) end)
  T.StyleButton(b,false)
  return b
end

function T.Select(b,value)
  b.wcfSelected=value==true
  T.StyleButton(b,false)
end

function T.Enabled(b,value)
  b.wcfDisabled=not value
  if value then b:Enable() else b:Disable() end
  T.StyleButton(b,false)
end

function T.Row(parent,x,y,width,height,index)
  local bg=parent:CreateTexture(nil,"BACKGROUND")
  bg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
  bg:SetVertexColor(P.stripe[1],P.stripe[2],P.stripe[3],
                    index%2==0 and 0.71 or 0.50)
  bg:SetWidth(width)
  bg:SetHeight(height)
  bg:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
  return bg
end

function T.Panel(name,width,height,title,section,subtitle)
  local f=CreateFrame("Frame",name,UIParent)
  f:SetWidth(width)
  f:SetHeight(height)
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
  T.RGB(f,"SetBackdropColor",P.base,0.99)
  local veil=f:CreateTexture(nil,"BACKGROUND")
  veil:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
  veil:SetVertexColor(0.05,0.07,0.10,0.92)
  veil:SetPoint("TOPLEFT",f,"TOPLEFT",12,-12)
  veil:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-12,12)
  f:Hide()

  local close=CreateFrame("Button",name.."Close",f,"UIPanelCloseButton")
  close:SetPoint("TOPRIGHT",f,"TOPRIGHT",-5,-5)
  close:SetScript("OnClick",function() f:Hide() end)
  T.Label(f,"GameFontNormalLarge",title or "World Chat Filter",
          23,-23,275,P.gold)
  T.Label(f,"GameFontHighlightSmall",section,290,-26,width-336,P.sage)
  T.Label(f,"GameFontHighlightSmall",subtitle,26,-54,width-54,P.muted)
  return f
end

function T.Tab(parent,title,x,y,width,click)
  local tab=T.Button(parent,title,x,y,width,click)
  tab:SetHeight(31)
  local line=tab:CreateTexture(nil,"ARTWORK")
  line:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
  line:SetVertexColor(P.gold[1],P.gold[2],P.gold[3],0.95)
  line:SetWidth(width-30)
  line:SetHeight(2)
  line:SetPoint("BOTTOM",tab,"BOTTOM",0,3)
  tab.wcfUnderline=line
  return tab
end

function T.ActiveTab(tab,selected)
  T.Select(tab,selected)
  if selected then tab.wcfUnderline:Show()
  else tab.wcfUnderline:Hide() end
end
