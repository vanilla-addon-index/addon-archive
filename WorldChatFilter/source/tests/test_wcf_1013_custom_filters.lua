-- v1.1 custom filters, standalone Vanilla Lua 5.1 regression.
table.getn=table.getn or function(t) return #t end
SlashCmdList={}
local notices={}
DEFAULT_CHAT_FRAME={AddMessage=function(_,t) table.insert(notices,t) end}
function UnitName() return "Ownhero" end
local now,delivered=100,0
function GetTime() return now end
function ChatFrame_OnEvent() delivered=delivered+1 end
function CreateFrame()
  return {RegisterEvent=function() end,SetScript=function() end}
end
WorldChatFilterDB={
  enabled=true, filterGuild=true,filterLFG=true,filterServices=true,
  filterTrade=true,filterRepeats=false,sensitivity="balanced"
}
for _,f in ipairs({"Core.lua","CustomFilters.lua","Statistics.lua","Classifier.lua","Filter.lua"}) do
 dofile(f)
end
local W=WorldChatFilter
W.Initialize()
local db=W.db
assert(db.customEnabled and type(db.blockedPlayers)=="table" and type(db.blockedPhrases)=="table",
       "new characters should have empty enabled custom lists")
local function evt(body,author,channel)
 now=now+1
 arg1,arg2,arg4,arg7,arg9=body,author,"4. "..channel,7,channel
 local before,count=delivered,W.GetStats().total
 ChatFrame_OnEvent("CHAT_MSG_CHANNEL")
 return delivered-before,W.GetStats().total-count
end
local function expect(blocked,body,author,channel)
 local shown,count=evt(body,author or "Unrelated",channel or "World")
 assert(shown==(blocked and 0 or 1) and count==(blocked and 1 or 0),
        "message "..body.." from "..tostring(author).." in "..tostring(channel)..
        " should be "..(blocked and "BLOCKED" or "ALLOWED")..
        " but got shown="..shown.." count="..count)
end
local ok
ok=W.AddBlockedPlayer("AnnoyingPlayer")
assert(ok and W.IsBlockedPlayer("ANNOYINGPLAYER"),"store blocked author ignoring case")
assert(not W.AddBlockedPlayer("annoyingplayer"),"case-insensitive duplicates")
assert(not W.AddBlockedPlayer("Two Words"),"invalid player name")
assert(not W.AddBlockedPlayer("Ownhero"),"self blocking must be refused")
expect(true,"hello everyone","aNnOyInGpLaYeR","World")
expect(false,"hello everyone","AnnoyingPlayer","Trade")
expect(false,"hello everyone","AnnoyingPlayer","General")
expect(false,"hello everyone","AnnoyingPlayer","Guild")
expect(false,"hello everyone","AnnoyingPlayer","LookingForGroup")
expect(false,"hello everyone","AnnoyingPlayer","Party")
expect(false,"hello everyone","Ownhero","World")
local current,all=W.GetStats()
assert(current.Custom==1 and all.Custom==1 and current.Repeats==0,
       "custom blocks require their own counters, not Repeats")
assert(W.RemoveBlockedPlayer("ANNOYINGPLAYER"),"remove blocked author casefolded")
assert(not W.IsBlockedPlayer("annoyingplayer"),"unblock must take immediate effect")
expect(false,"hello everyone","AnnoyingPlayer","World")
assert(W.AddBlockedPhrase("discord.gg"),"add literal fragment")
assert(not W.AddBlockedPhrase("DISCORD.GG"),"no duplicate text")
expect(true,"come see DISCORD.GG/abc123","Other","World")
expect(false,"come see discordXgg today","Other","World")
expect(false,"come see discord.gg today","Ownhero","World")
expect(false,"come see discord.gg today","Other","Trade")
assert(W.AddBlockedPhrase("Boost",true),"add whole word")
expect(true,"Need a BOOST!","Other","World")
expect(false,"That is a booster","Other","World")
expect(false,"superboost is fun","Other","World")
expect(false,"boosting this character","Other","World")
expect(true,"(boost)","Other","World")
assert(W.AddBlockedPhrase("enchants",false),"add item display filter")
expect(true,"LF |cff0070dd|Hitem:123:0|h[enchants]|h|r","Other","World")
-- Hidden WoW link metadata must never be considered message text.
expect(false,"|cff0070dd|Hitem:enchants:3|h[Clean Item]|h|r","Other","World")
assert(W.RemoveBlockedPhrase("DISCORD.GG"),"remove custom phrase")
expect(false,"come see discord.gg today","Other","World")
db.customEnabled=false
expect(false,"Need a BOOST!","Other","World")
db.customEnabled=true
expect(true,"Need a BOOST!","Other","World")
db.enabled=false
expect(false,"Need a BOOST!","Other","World")
db.enabled=true
-- SavedVariables still refer to the same table through a re-initialization.
W.db=nil
W.Initialize()
assert(W.db==db and W.db.customEnabled and W.IsBlockedPlayer("Ownhero")==false,
       "saved config should survive new init")
expect(true,"Need a BOOST!","Other","World")
assert(W.RemoveBlockedPhrase("boost"),"remove remaining rule")

-- CLI must agree with GUI/popup and preserve matching modes.
SlashCmdList.WORLDCHATFILTER("block player Testdude")
assert(W.IsBlockedPlayer("testdude"),"CLI player block")
SlashCmdList.WORLDCHATFILTER("unblock player testdude")
assert(not W.IsBlockedPlayer("testdude"),"CLI player unblock")
SlashCmdList.WORLDCHATFILTER("block word LoOt")
expect(false,"looting now","Other","World")
expect(true,"loot now","Other","World")
SlashCmdList.WORLDCHATFILTER("unblock text loot")
expect(false,"loot now","Other","World")
SlashCmdList.WORLDCHATFILTER("custom off")
assert(not db.customEnabled,"CLI custom off")
SlashCmdList.WORLDCHATFILTER("custom on")
assert(db.customEnabled,"CLI custom on")

-- Real 1.12 chat hyperlinks open the FRIEND popup. Patch only that menu;
-- preserve previously installed handlers and unrelated popup categories.
local showCalls,clickCalls,closed=0,0,0
UnitPopupMenus={FRIEND={"WHISPER","INVITE","CANCEL"},PLAYER={"WHISPER","CANCEL"}}
UnitPopupButtons={WHISPER={text="Whisper"},INVITE={text="Invite"},CANCEL={text="Cancel"}}
function UnitPopup_ShowMenu(menu,which,unit,name)
 showCalls=showCalls+1
 assert(UnitPopupButtons["WCF_WORLD_BLOCK"],"popup button should exist")
end
function UnitPopup_OnClick() clickCalls=clickCalls+1 end
function getglobal(name) return _G[name] end
function CloseDropDownMenus() closed=closed+1 end
FriendsDropDown={name="Spammer"}
UIDROPDOWNMENU_INIT_MENU="FriendsDropDown"
local originalShow,originalClick=UnitPopup_ShowMenu,UnitPopup_OnClick
assert(W.InstallCustomPlayerPopup(),"install popup hook")
assert(W.InstallCustomPlayerPopup(),"second install must be idempotent")
assert(UnitPopup_ShowMenu~=originalShow and UnitPopup_OnClick~=originalClick)
local total=0
for _,id in ipairs(UnitPopupMenus.FRIEND) do
 if id=="WCF_WORLD_BLOCK" then total=total+1 end
end
assert(total==1 and UnitPopupMenus.FRIEND[#UnitPopupMenus.FRIEND-1]=="WCF_WORLD_BLOCK",
       "one option added before CANCEL")
assert(#UnitPopupMenus.PLAYER==2,"unrelated menu must be untouched")
UnitPopup_ShowMenu(FriendsDropDown,"FRIEND",nil,"Spammer")
assert(showCalls==1 and UnitPopupButtons.WCF_WORLD_BLOCK.text=="Block from World Chat")
this={value="WCF_WORLD_BLOCK"}
UnitPopup_OnClick()
assert(W.IsBlockedPlayer("Spammer") and clickCalls==0 and closed==1,"popup should block only World")
UnitPopup_ShowMenu(FriendsDropDown,"FRIEND",nil,"Spammer")
assert(UnitPopupButtons.WCF_WORLD_BLOCK.text=="Unblock from World Chat")
UnitPopup_OnClick()
assert(not W.IsBlockedPlayer("Spammer") and closed==2,"popup should unblock player")
this={value="WHISPER"}
UnitPopup_OnClick()
assert(clickCalls==1,"non-custom clicks must delegate to original Blizzard handler")
assert(showCalls==2,"original popup initialization must still run")
-- The popup can block a player without turning on WoW Ignore.
assert(type(AddIgnore)=="nil","test must never require the global Ignore API")
print("PASS v1.1 custom: players/text/word, WoW links, own messages, channels, saved DB, CLI, popup, stats")
