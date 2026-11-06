-- Vanilla API mock integration test for WorldChatFilter.
table.getn = table.getn or function(t) return #t end
mock = {now=0, delivered=0, printed={}, menuByLevel={}, frames={}}
DEFAULT_CHAT_FRAME = {AddMessage = function(_,text) table.insert(mock.printed,text) end}
SlashCmdList={}
function GetTime() return mock.now end
function UnitName() return 'Tester' end
function GetCursorPosition() return 980, 610 end
function IsShiftKeyDown() return true end
function ChatFrame_OnEvent(evt) mock.delivered=mock.delivered+1 end
local p={}
function p:CreateFontString() return setmetatable({}, {__index=p}) end
function p:CreateTexture() return setmetatable({}, {__index=p}) end
function p:RegisterEvent(e) self.events[e]=true end
function p:SetScript(k,v) self.scripts[k]=v end
function p:GetScript(k) return self.scripts[k] end
function p:GetName() return self.name end
function p:GetEffectiveScale() return 1 end
function p:GetFrameLevel() return 1 end
function p:GetCenter() return 500,500 end
function p:Show() self.shown=true end
function p:Hide() self.shown=false end
function p:IsShown() return self.shown end
function p:SetText(t) self.text=t end
function p:GetText() return self.text end
function p:SetChecked(t) self.checked=t end
function p:GetChecked() return self.checked end
setmetatable(p,{__index=function(_,method) return function(self,...) return self end end})
function CreateFrame(kind,name,parent,template)
  local o=setmetatable({name=name,events={},scripts={},template=template}, {__index=p})
  if name then _G[name]=o end
  table.insert(mock.frames,o)
  return o
end
UIParent=CreateFrame('Frame','UIParent')
Minimap=CreateFrame('Frame','Minimap')
GameTooltip=setmetatable({}, {__index=p})
function UIDropDownMenu_CreateInfo() return {} end
function UIDropDownMenu_AddButton(info,level)
 local k=level or UIDROPDOWNMENU_MENU_LEVEL or 1
 mock.menuByLevel[k]=mock.menuByLevel[k] or {}
 table.insert(mock.menuByLevel[k],info)
end
function UIDropDownMenu_Initialize(drop,fn,kind) drop.initialize=fn;drop.mode=kind;fn(drop,1) end
function ToggleDropDownMenu(level,value,frame,anchorName)
 mock.anchor=anchorName
 mock.menuByLevel={}; UIDROPDOWNMENU_MENU_LEVEL=1
 frame.initialize(frame,1)
end
function CloseDropDownMenus() mock.closed=true end
function JoinChannelByName() error('unexpected join') end
function LeaveChannelByName() error('unexpected leave') end
function ChannelBan() error('unexpected ban') end
function ChannelMute() error('unexpected mute') end
function SendChatMessage() error('unexpected sending') end

-- Clean standalone upgrade: no SocialChat addon, legacy DB or globals loaded.
SocialChatDB=nil
WorldChatFilterDB={enabled=true,filterTrade=true,filterLFG=false,filterGuild=true,filterServices=true,filterRepeats=true,sensitivity='aggressive',minimapAngle=117, stats={total=0,Trade=0,LFG=0,Guild=0,Services=0,Repeats=0}}
local prevDB=WorldChatFilterDB
local base=''
dofile(base..'Core.lua')
dofile(base..'PanelTheme.lua')
dofile(base..'Statistics.lua')
dofile(base..'Classifier.lua')
dofile(base..'Filter.lua')
dofile(base..'UI.lua')
local WCF=WorldChatFilter
WCF.Initialize(); WCF.BuildUI()
assert(WCF.VERSION=='1.1.2')
assert(WorldChatFilterDB==prevDB)
assert(WCF.db.sensitivity=='aggressive')
assert(WCF.db.minimapAngle==117)
assert(WCF.db.filterLFG==false)
assert(WCF.db.stats.total==0)
assert(SLASH_WORLDCHATFILTER1=='/wcf' and SlashCmdList.WORLDCHATFILTER)
assert(SlashCmdList.SOCIALCHAT==nil and SLASH_SOCIALCHAT1==nil)
assert(WorldChatFilterMinimapButton and WorldChatFilterSettingsDropdown)
WCF.db.sensitivity='balanced'
WCF.db.filterLFG=true

-- All past real-world ad patterns must remain supported.
local examples={
 'LF BM REP RUNS PST',
 'need 1 heal 1 tank for sfk summon available',
 '<Nagas in Paris> inviting ... to our small, chill guild',
 '<Cleave> Looking for new recruits, Fastest MC, Ony, Zg and K10. Alternating Parse- and Speedruns every week. Interested in adding 1 Boomkin, 1 Mage 1 SPriest. /w Warriortypeb if intrested',
 'feeling lonely? < wanted > recruits based chuds',
 'Enchanter LFW Weapon: Crusader/30Spell Power/Str/Unholy/Spirit! +9dmg',
 'LF 2 DPS 1 HEAL BM',
 'DPS looking for BM rep farm',
 'LF BM REP RUNS PST',
 'WTS 20 stacks of herbs 15g PST',
 'One of Turtle WoW top speedrun guilds, now looking for Mages/Shamans/Warlocks for our main rooster! https://discord.gg/99VREUC4P for more information!',
 'BS LFW - does you soul stir with desire? [Bloodsoul Gauntlets][Darksoul Shoulders] /w me',
 '<Nerds of a Feather> is a great place for returning gamers, players new to OctoWoW, first-time raiders, or leveling at all levels, are just about anybody else. just ONE rule: NO JERKS allowed! Whisper for invite and find your flock today.'
}
for _,m in ipairs(examples) do assert(WCF.IsAdvertisement(m),'missed: '..m) end
for _,m in ipairs({'What does LFG mean?','LF some advice on BM rep farming','I love my guild','Looking for advice on my DPS talents','I am just chilling in Stormwind', 'BS stands for Blacksmithing, right?', 'Does BS LFW mean blacksmith looking for work?', 'Whisper for invite? Is there an event today?', 'Nerds of a Feather are a fun group, I met them yesterday.', 'I am a returning player and enjoy leveling', 'The place for returning gamers is probably the starter zones' }) do
 assert(not WCF.IsAdvertisement(m), 'false positive: '..m)
end

local function send(channel,msg,author,now)
 arg1=msg;arg2=author;arg9=channel;arg4='4. '..channel;mock.now=now
 ChatFrame_OnEvent('CHAT_MSG_CHANNEL')
end
local function counters() return WCF.GetStats() end
send('World','WTS 20 stacks of herbs 15g PST','Seller',10)
local st,all=counters()
assert(st.Trade==1 and all.Trade==1 and st.total==1)
-- Multiple chat frames must NOT count the same event twice.
send('World','WTS 20 stacks of herbs 15g PST','Seller',10)
st,all=counters();assert(st.total==1 and all.total==1)
send('World','LF 2 DPS 1 HEAL BM','Looker',11)
send('World','<Nagas in Paris> recruiting new members PST','Guildie',12)
send('World','Enchanter LFW Crusader PST free tips','Crafter',13)
st,all=counters()
assert(st.LFG==1 and st.Guild==1 and st.Services==1, 'category recording')
assert(st.total==4 and all.total==4)
send('World','We are all just hanging around in Goldshire tonight','Chatter',14)
send('World','We are all just hanging around in Goldshire tonight','Chatter',15)
st,all=counters();assert(st.Repeats==1 and st.total==5 and all.total==5)
send('General - Elwynn Forest','WTS 20 stacks of herbs 15g PST','Seller',16)
send('World','WTS 20 stacks of herbs 15g PST','Tester',16.5)
st,all=counters();assert(st.total==5 and all.total==5,'only World and other authors')

SlashCmdList.WORLDCHATFILTER('test LF 2 DPS 1 HEAL BM')
st,all=counters();assert(st.total==5,'test mode must not increment')
SlashCmdList.WORLDCHATFILTER('stats')
assert(WorldChatFilterStatisticsFrame:IsShown())
assert(WorldChatFilterResetSession and WorldChatFilterResetAll)
assert(WorldChatFilterResetAll.text=='Reset All')
SlashCmdList.WORLDCHATFILTER('stats')
assert(not WorldChatFilterStatisticsFrame:IsShown())
SlashCmdList.WORLDCHATFILTER('')
local found = false
for _,e in ipairs(mock.menuByLevel[1]) do
  if e.text == 'Statistics Panel' then found = true; e.func() end
end
assert(found and WorldChatFilterStatisticsFrame:IsShown())
-- Reset Session should retain all-time totals.
WorldChatFilterResetSession.scripts.OnClick()
st,all=counters();assert(st.total==0 and all.total==5 and WCF.sessionHidden==0)
WorldChatFilterResetAll.scripts.OnClick()
st,all=counters();assert(all.total==5 and WorldChatFilterResetAll.text=='Confirm Reset')
WorldChatFilterResetAll.scripts.OnClick()
st,all=counters();assert(all.total==0 and st.total==0)
-- Persistence across Initialize (same loaded SavedVariables table).
WCF.RecordHiddenMessage('Guild')
WCF.Initialize()
st,all=counters();assert(all.Guild==1 and all.total==1)
assert(mock.anchor=='WorldChatFilterMenuAnchor')
local source=io.open(base..'UI.lua','r'):read('*a')
local n=0;string.gsub(source,'miniButton:CreateTexture',function() n=n+1 end)
assert(n==1 and not string.find(source,'border:SetTexture',1,true))
print('WorldChatFilter v034: standalone addon, classifier, menu, orb, stats, persistence, dedup and reset tests PASS')

-- Isolation/guard tests: the message is deliberately identical spam on all channels.
local spam='WTS 20 stacks of herbs 15g PST'
local initialTotal=WCF.GetStats().total
local function sendMeta(baseName, decoratedName, zoneID, evt, msg,now)
  arg1=msg;arg2='Seller';arg9=baseName;arg4=decoratedName;arg7=zoneID;mock.now=now
  local before=mock.delivered
  ChatFrame_OnEvent(evt or 'CHAT_MSG_CHANNEL')
  return mock.delivered - before
end
for _,entry in ipairs({
 {'Trade - City','2. Trade - City',2},
 {'General - Stormwind City','1. General - Stormwind City',1},
 {'LookingForGroup','3. LookingForGroup',26},
 {'WorldDefense','6. WorldDefense',23},
 {'world','8. Trade - City',0},
 {'Trade - City','4. World',2},
 -- removed obsolete zone-channel-ID expectation
 {'World Chat','5. World Chat',0},
 {nil,'4. Trade - City',2},
}) do
 assert(sendMeta(entry[1],entry[2],entry[3],nil,spam,18)==1,'non-World/inconsistent channel must be shown')
end
assert(sendMeta('Trade - City','5. Trade - City',2,'CHAT_MSG_CHANNEL',spam,19)==1)
assert(sendMeta('World','5. World',0,'CHAT_MSG_SAY',spam,19.2)==1,'non-channel events must not be filtered')
assert(WCF.GetStats().total==initialTotal,'non-World stats changed')
assert(sendMeta('World','5. World',0,nil,spam,20)==0,'custom World should filter')
assert(sendMeta(nil,'7. World',0,nil,spam,21)==0,'numbered World without arg9 should filter')
assert(sendMeta('WORLD',nil,nil,nil,spam,22)==0,'bare World should filter')
assert(sendMeta('world','8. world',0,nil,spam,23)==0,'World case-insensitive')
assert(WCF.GetStats().total==initialTotal+4,'World totals must increment only for World events')
print('World-only isolation tests PASS (Trade / General / LFG unchanged)')
