-- WorldChatFilter v1.1: on-screen Help / Commands, no help spam in chat.
-- Every command listed here is implemented by Core.lua on Vanilla 1.12.
local WCF=WorldChatFilter
local T=WCF.PanelTheme
local P=T.colors
local panel,tabs,sectionLabel,footer
local rows={}
local activePage="general"
local pageData={
  general={
    title="General commands",
    {
      {"/wcf","Open addon settings"},
      {"/wcf options","Open addon settings (also /wcf settings)"},
      {"/wcf help","Open this Help / Commands window"},
      {"/wcf toggle","Toggle all World filtering (macro-friendly)"},
      {"/wcf on","Enable World filtering"},
      {"/wcf off","Disable World filtering"},
      {"/wcf status","Print filter status and session count"},
      {"/wcf mode <level>","Choose careful, balanced or aggressive"},
      {"/wcf stats","Open the Statistics panel"}
    }
  },
  custom={
    title="Custom World-only filters",
    {
      {"/wcf custom","Open the personal filter manager"},
      {"/wcf custom on","Enable personal lists (or custom off)"},
      {"/wcf block player NAME","Block NAME from World chat only"},
      {"/wcf unblock player NAME","Remove a blocked player"},
      {"/wcf block text PHRASE","Block messages containing this phrase"},
      {"/wcf block word PHRASE","Block whole-word / phrase matches"},
      {"/wcf unblock text PHRASE","Remove a blocked word or phrase"},
      {"Right-click a chat name","Block or unblock from World Chat"}
    }
  },
  tools={
    title="Color, diagnostics and tips",
    {
      {"/wcf color on","Turn on the World color override"},
      {"/wcf color off","Turn off the World color override"},
      {"/wcf color picker","Open RGB color picker (or color custom)"},
      {"/wcf color reset","Restore Dusty Gold (or color default)"},
      {"/wcf test <message>","Print classifier result for sample text"},
      {"/wcf debug","Toggle blocked-message explanations"},
      {"/wcf channeldebug","Log channel metadata for diagnosis"},
      {"World chat only","Trade, Party, Guild, whispers stay untouched"}
    }
  }
}

function WCF.SelectHelpPage(page)
  if not pageData[page] then return false end
  if not panel then WCF.BuildHelpUI() end
  activePage=page
  panel.selectedPage=page
  WCF.RefreshHelpUI()
  return true
end

function WCF.RefreshHelpUI()
  if not panel then return end
  local keys={"general","custom","tools"}
  local i
  for i=1,table.getn(keys) do
    T.ActiveTab(tabs[i],activePage==keys[i])
  end
  local data=pageData[activePage]
  sectionLabel:SetText(data.title)
  for i=1,9 do
    local row=rows[i]
    local item=data[1][i]
    if item then
      row.command:SetText(item[1])
      row.description:SetText(item[2])
      row.background:Show()
      row.command:Show()
      row.description:Show()
    else
      row.command:SetText("")
      row.description:SetText("")
      row.background:Hide()
      row.command:Hide()
      row.description:Hide()
    end
  end
  if activePage=="general" then
    footer:SetText("Tip: put /wcf toggle into a WoW macro for one-key control.")
  elseif activePage=="custom" then
    footer:SetText("Personal lists apply only to World and are saved per character.")
  else
    footer:SetText("The filter runs locally. No AI, APIs or external services.")
  end
end

function WCF.BuildHelpUI()
  if panel then return panel end
  local f=T.Panel("WorldChatFilterHelpFrame",620,535,
                  "World Chat Filter","HELP / COMMANDS",
                  "Available slash commands and in-game shortcuts")
  panel=f
  f.selectedPage="general"
  tabs={
    T.Tab(f,"General",29,-116,178,function() WCF.SelectHelpPage("general") end),
    T.Tab(f,"Custom Filters",221,-116,178,function() WCF.SelectHelpPage("custom") end),
    T.Tab(f,"Tools",413,-116,178,function() WCF.SelectHelpPage("tools") end)
  }
  sectionLabel=T.Label(f,"GameFontNormal","",34,-166,440,P.gold)
  T.Label(f,"GameFontHighlightSmall","Command",38,-189,227,P.muted)
  T.Label(f,"GameFontHighlightSmall","Description",285,-189,302,P.muted)
  local i
  for i=1,9 do
    local row={}
    local top=-213-(i-1)*28
    row.background=T.Row(f,28,top,565,27,i)
    row.command=T.Label(f,"GameFontHighlightSmall","",39,top-3,235,P.gold)
    row.description=T.Label(f,"GameFontHighlightSmall","",286,top-3,298,P.text)
    rows[i]=row
  end
  footer=T.Label(f,"GameFontHighlightSmall","",36,-478,543,P.muted)
  WCF.RefreshHelpUI()
  return f
end

function WCF.ToggleHelpUI()
  local f=WCF.BuildHelpUI()
  if f:IsShown() then
    f:Hide()
  else
    if type(CloseDropDownMenus)=="function" then CloseDropDownMenus() end
    WCF.RefreshHelpUI()
    f:Show()
  end
end
