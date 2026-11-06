-- v0.3.8 tests exercise classifier AND the actual World/Trade chat hook.
table.getn = table.getn or function(t) return #t end
SlashCmdList = {}
local mock={now=100, delivered=0}
DEFAULT_CHAT_FRAME={AddMessage=function() end}
function CreateFrame() return {RegisterEvent=function() end,SetScript=function() end} end
function ChatFrame_OnEvent() mock.delivered=mock.delivered+1 end
function UnitName() return 'Mychar' end
function GetTime() return mock.now end
WorldChatFilterDB = {sensitivity='aggressive'}
local root=''
dofile(root ..'Core.lua')
dofile(root ..'Statistics.lua')
dofile(root ..'Classifier.lua')
dofile(root ..'Filter.lua')
WorldChatFilter.Initialize()
local WCF=WorldChatFilter
assert(WCF.VERSION=='1.1.2')
local ads={
  'Kara10 LF7M Need All 3/10 [Leggings of the Inferno] hr',
  'LF6M BRD, DPS and healer needed',
  'LF8M AQ20 rep farm PST',
  'LF9M for MC',
  'LF10M ZG',
  'LF12M for Naxx',
  'LF1M tank for SFK',
  'LF2M Scholo',
  'LF40M raid tonight',
  'LFM BM rep farm',
  'LF3M Scholo need all 58+',
}
for _,m in ipairs(ads) do
  local cat,score,why,blocked=WCF.ClassifyMessage(m)
  assert(blocked and cat=='LFG', 'did not detect ad: '..m..' - '..tostring(cat)..', score='..tostring(score)..' '..tostring(why))
end
local allow={
  'What does LF7M mean?',
  'Is LF12M a shortcut for something?',
  'LF7MX looks like a weird username',
  'ALF7M is a weird character name',
  'People keep saying LF10M in World chat, what is it?',
  'Please stop spamming LF7M in chat',
  'Anyone knows what LF8M means?',
  'How does LF7M work?',
  'Kara10 last night was fun',
}
for _,m in ipairs(allow) do
  local cat,score,why,blocked=WCF.ClassifyMessage(m)
  assert(not blocked, 'false positive: '..m..' - '..tostring(cat)..', score='..tostring(score)..' '..tostring(why))
end
local ad=ads[1]
local function event(m,base,decorated,zoneID)
  mock.now=mock.now+1
  arg1,arg2,arg4,arg7,arg9=m,'OtherPlayer',decorated,zoneID,base
  local before=mock.delivered
  ChatFrame_OnEvent('CHAT_MSG_CHANNEL')
  return mock.delivered-before
end
local stats0=WCF.GetStats().total
assert(event(ad,'World','4. World',7)==0,'World must be hidden')
assert(WCF.GetStats().total==stats0+1,'World stats missed')
for _,c in ipairs({{'Trade - City','2. Trade - City'}, {'General - Elwynn Forest','1. General - Elwynn Forest'}, {'LookingForGroup','3. LookingForGroup'}, {'WorldDefense','4. WorldDefense'}}) do
  assert(event(ad,c[1],c[2],7)==1,'unexpected filtering for '..c[1])
end
assert(WCF.GetStats().total==stats0+1,'non-World affected stats')
assert(event(allow[1],'World','4. World',7)==1,'ordinary chat hidden')
-- Aggressive -> Careful: the screenshot ad should still block with context.
WCF.db.sensitivity='careful'
local cat,score,why,blocked=WCF.ClassifyMessage(ad)
assert(blocked and cat=='LFG','Careful should block real LF7M advert')
print('v0.3.8 LF<number>M, negative cases, World-only hook and stats PASS')
