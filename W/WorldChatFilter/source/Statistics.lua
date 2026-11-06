-- WorldChatFilter v1.1: Dark Arcane Statistics panel.
-- Counters are updated ONLY when a message is hidden in the World channel.
local WCF=WorldChatFilter
local categories={"Trade","LFG","Guild","Services","Repeats","Custom"}
local session=nil
local statsFrame,cells,resetAllButton,resetHint
local confirmReset=false

local function freshCounts()
  return {total=0,Trade=0,LFG=0,Guild=0,Services=0,Repeats=0,Custom=0}
end
local function normalizeCounts(value)
  if type(value)~="table" then value={} end
  local defaults=freshCounts()
  local key
  for key in pairs(defaults) do
    local n=tonumber(value[key]) or 0
    if n<0 then n=0 end
    value[key]=math.floor(n)
  end
  return value
end

function WCF.InitializeStats()
  if not WCF.db then return end
  WCF.db.stats=normalizeCounts(WCF.db.stats)
  if not session then session=freshCounts() end
  WCF.sessionHidden=session.total
end

function WCF.GetStats()
  if not WCF.db then WCF.Initialize() end
  if not session then WCF.InitializeStats() end
  return session,WCF.db.stats
end

function WCF.RecordHiddenMessage(category)
  local current,lifetime=WCF.GetStats()
  if category~="Trade" and category~="LFG" and category~="Guild" and
     category~="Services" and category~="Custom" then
    category="Repeats"
  end
  current.total=current.total+1
  lifetime.total=lifetime.total+1
  current[category]=current[category]+1
  lifetime[category]=lifetime[category]+1
  WCF.sessionHidden=current.total
  if WCF.UpdateStatsUI then WCF.UpdateStatsUI() end
end

function WCF.ResetSessionStats()
  session=freshCounts()
  WCF.sessionHidden=0
  if WCF.UpdateStatsUI then WCF.UpdateStatsUI() end
end

function WCF.ResetAllStats()
  if not WCF.db then WCF.Initialize() end
  WCF.db.stats=freshCounts()
  WCF.ResetSessionStats()
end

local function clearConfirmation()
  confirmReset=false
  if resetAllButton then resetAllButton:SetText("Reset All") end
  if resetHint then
    resetHint:SetText("Resets are local to this character.")
  end
end

function WCF.UpdateStatsUI()
  if not statsFrame or not statsFrame:IsShown() then return end
  local current,lifetime=WCF.GetStats()
  local i
  for i=1,table.getn(categories) do
    local key=categories[i]
    cells[key][1]:SetText(tostring(current[key]))
    cells[key][2]:SetText(tostring(lifetime[key]))
  end
  cells.total[1]:SetText(tostring(current.total))
  cells.total[2]:SetText(tostring(lifetime.total))
end

function WCF.BuildStatsUI()
  if statsFrame then return statsFrame end
  if not WCF.db then WCF.Initialize() end
  local T=WCF.PanelTheme
  local P=T.colors
  local f=T.Panel("WorldChatFilterStatisticsFrame",530,462,
                  "World Chat Filter","STATISTICS",
                  "Messages hidden from /World (this character)")
  statsFrame=f
  cells={}

  T.Label(f,"GameFontNormal","Category",35,-112,213,P.gold)
  T.Label(f,"GameFontNormal","Session",301,-112,82,P.gold,"RIGHT")
  T.Label(f,"GameFontNormal","All-time",403,-112,91,P.gold,"RIGHT")

  local i
  for i=1,table.getn(categories) do
    local category=categories[i]
    local top=-145-(i-1)*32
    T.Row(f,27,top-2,474,29,i)
    T.Label(f,"GameFontHighlight",
            category=="Repeats" and "Repeated Messages" or category,
            40,top,215,P.text)
    cells[category]={
      T.Label(f,"GameFontHighlight","0",300,top,81,P.text,"RIGHT"),
      T.Label(f,"GameFontHighlight","0",407,top,85,P.text,"RIGHT")
    }
  end
  T.Row(f,27,-346,474,32,2)
  T.Label(f,"GameFontNormal","TOTAL HIDDEN",40,-350,230,P.gold)
  cells.total={
    T.Label(f,"GameFontNormal","0",300,-350,81,P.gold,"RIGHT"),
    T.Label(f,"GameFontNormal","0",407,-350,85,P.gold,"RIGHT")
  }

  resetHint=T.Label(f,"GameFontHighlightSmall",
                    "Resets are local to this character.",
                    30,-389,460,P.muted)
  local resetSession=T.Button(f,"Reset Session",31,-424,160,function()
    WCF.ResetSessionStats()
    clearConfirmation()
  end,false,"WorldChatFilterResetSession")
  resetAllButton=T.Button(f,"Reset All",343,-424,156,function()
    if not confirmReset then
      confirmReset=true
      resetAllButton:SetText("Confirm Reset")
      resetHint:SetText("Click Confirm Reset to erase all-time statistics.")
    else
      WCF.ResetAllStats()
      clearConfirmation()
    end
  end,true,"WorldChatFilterResetAll")
  f:SetScript("OnHide",clearConfirmation)
  return f
end

function WCF.ToggleStatsUI()
  local f=WCF.BuildStatsUI()
  if f:IsShown() then
    f:Hide()
  else
    if type(CloseDropDownMenus)=="function" then CloseDropDownMenus() end
    f:Show()
    WCF.UpdateStatsUI()
  end
end
