-- WorldChatFilter 1.1 dev: /wcf toggle macro regression, Vanilla-compatible behavior.
table.getn = table.getn or function(t) return #t end
SlashCmdList = {}
local messages = {}
DEFAULT_CHAT_FRAME = {AddMessage=function(_,line) table.insert(messages, line) end}
function UnitName() return "CurrentCharacter" end
local now,shown = 0,0
function GetTime() return now end
function ChatFrame_OnEvent() shown=shown+1 end
function CreateFrame()
  return {RegisterEvent=function() end, SetScript=function() end}
end
WorldChatFilterDB = {
 enabled=true, filterGuild=true, filterLFG=true,
 filterServices=true, filterTrade=true, filterRepeats=false,
 sensitivity="balanced", tintWorld=true, worldColorPreset="sage"
}
for _,file in ipairs({"Core.lua","Statistics.lua","Classifier.lua","Filter.lua"}) do dofile(file) end
local W = WorldChatFilter
W.Initialize()
assert(W.VERSION == "1.1.2", "stable hotfix version must match the release")
local db = W.db
local colorRefresh,uiRefresh = 0,0
W.RefreshWorldColor=function() colorRefresh=colorRefresh+1 end
W.RefreshUI=function() uiRefresh=uiRefresh+1 end
local function command(input)
  SlashCmdList.WORLDCHATFILTER(input)
  assert(W.db == db and W.db == WorldChatFilterDB, "must preserve existing saved DB")
end
local function event(text,channel)
  now=now+1
  arg1,arg2,arg4,arg7,arg9=text,"Advertiser","4. "..channel,7,channel
  local prevShown,prevCount=shown,W.GetStats().total
  ChatFrame_OnEvent("CHAT_MSG_CHANNEL")
  return shown-prevShown,W.GetStats().total-prevCount
end
local ad="LF JC [Deep Sapphire Circlet]"
local show,hidden=event(ad,"World")
assert(show==0 and hidden==1,"default World filter should block ad")
show,hidden=event(ad,"Trade")
assert(show==1 and hidden==0,"Trade must never be filtered")
local index=#messages
local beforeUI, beforeColor=uiRefresh,colorRefresh
command("toggle")
assert(W.db.enabled==false,"toggle should switch ON to OFF")
assert(colorRefresh==beforeColor+1 and uiRefresh==beforeUI+1,"toggle should refresh color and UI")
assert(#messages==index+1 and string.find(messages[#messages],"World filtering: OFF",1,true),
       "toggle should report OFF in chat")
show,hidden=event(ad,"World")
assert(show==1 and hidden==0,"OFF must allow World ads without stats")
show,hidden=event(ad,"General")
assert(show==1 and hidden==0,"General unaffected by toggle")
assert(W.db.tintWorld==true and W.db.worldColorPreset=="sage"
  and W.db.filterServices==true and W.db.filterLFG==true and W.db.sensitivity=="balanced",
  "toggle must preserve category and color settings")
beforeUI,beforeColor=uiRefresh,colorRefresh
command("  ToGgLe  ")
assert(W.db.enabled==true,"second toggle should switch OFF to ON")
assert(colorRefresh==beforeColor+1 and uiRefresh==beforeUI+1,"second toggle should refresh color and UI")
assert(string.find(messages[#messages],"World filtering: ON",1,true),
       "second toggle should report ON in chat")
show,hidden=event(ad,"World")
assert(show==0 and hidden==1,"filter must resume after second toggle")
beforeUI,beforeColor=uiRefresh,colorRefresh
command("off")
assert(W.db.enabled==false and colorRefresh==beforeColor+1 and uiRefresh==beforeUI+1,"/wcf off regression")
command("off")
assert(W.db.enabled==false,"/wcf off should be idempotent")
command("toggle")
assert(W.db.enabled==true,"toggle after OFF should enable")
command("on")
assert(W.db.enabled==true,"/wcf on should be idempotent")
command("status")
assert(string.find(messages[#messages],"World filtering: ON",1,true),"status regression")
W.db=nil
W.Initialize()
assert(W.db==db and W.db.enabled==true,"enabled state must persist across init")
command("toggle")
W.db=nil
W.Initialize()
assert(W.db==db and W.db.enabled==false,"disabled state must persist across init")
local opened=0
W.ToggleHelpUI=function() opened=opened+1 end
local oldMessages=#messages
W.Help()
assert(opened==1 and #messages==oldMessages,"Help should open UI, not write to chat")
command("help")
assert(opened==2 and #messages==oldMessages,"/wcf help must open Help window")
print("PASS v1.1 macro toggle: ON/OFF, feedback, UI/color refresh, persistence, original commands, World-only")
