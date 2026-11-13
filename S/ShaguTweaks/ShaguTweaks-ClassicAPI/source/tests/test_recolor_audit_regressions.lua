local root=(arg[1] or '.')..'/'
local f=assert(io.open(root..'mods/dark-ui-elements.lua'));local source=f:read('*a');f:close()
assert(loadstring(source))
local function Extract(first,last,suffix,prefix)
 local a=assert(string.find(source,first,1,true))
 local b=assert(string.find(source,last,a,true))
 return assert(loadstring((prefix or '')..string.sub(source,a,b-1)..suffix))()
end
local palette='local tint={r=.3,g=.3,b=.3,a=.9};local edge={r=.3,g=.3,b=.3,a=.9};'
ShaguTweaks={}
local darken=Extract('local function IsExcludedFrame','local ADDON_PREFIXES =','return DarkenFrame',
 palette..'local backgrounds,borders,regionskips={},{},{};')
local lock=Extract('local ADDON_PREFIXES =','local function LockTextureBorder','return LockBorder',palette)
local frame={stPreserveRarityColor=true,color={0,1,0,1}}
function frame:GetName() return 'MailAttachmentAudit' end
function frame:GetChildren() end
function frame:GetRegions() end
function frame:SetBackdropBorderColor(r,g,b,a) self.color={r,g,b,a} end
function frame:GetBackdropBorderColor() return unpack(self.color) end
lock(frame);assert(frame.color[2]==1)
darken(frame);assert(frame.color[1]==0 and frame.color[2]==1)
print('Recursive recoloring preserves marked rarity borders')

local redraw=Extract('local function RedrawTitle','local function ShadeTitleBar','return RedrawTitle')
local title={text='Old title'}
function title:GetText() return self.text end
function title:SetText(text) self.text=text end
function title:SetFormattedText(format,value) self.text=string.format(format,value) end
function title:SetAlpha(value) self.alpha=value end
local holder={}
function holder:CreateFontString()
 return {SetAllPoints=function() end,SetText=function(self,text) self.text=text end}
end
local copy=redraw(holder,title)
title:SetFormattedText('New %s','title')
assert(title.text=='New title' and copy.text=='New title' and title.alpha==0)
title:SetText('Plain again');assert(copy.text=='Plain again')
print('Golden title copies track plain and formatted text')

local restore=Extract('local function RestoreMailParchment','module.enable =','return RestoreMailParchment')
local made=0
function ShaguTweaks.HookScript(object,event,callback) object[event]=callback end
local function noop() end
InboxFrame={CreateTexture=function()
 made=made+1
 return {SetTexture=noop,SetVertexColor=noop,SetTexCoord=noop,SetWidth=noop,SetHeight=noop,SetPoint=noop}
end}
MailFrameTopLeft=nil;MailFrameTopRight=nil;MailFrameBotLeft=nil;MailFrameBotRight=nil
restore();assert(not InboxFrame.stOriginalParchment and made==0 and InboxFrame.OnShow)
local width=0
MailFrameTopLeft={GetTexture=function() return 'LateTile' end,GetWidth=function() return width end,GetHeight=function() return 256 end}
local function tile() return {GetTexture=function() return 'NativeTile' end,GetWidth=function() return 256 end,GetHeight=function() return 256 end} end
MailFrameTopRight=tile();MailFrameBotLeft=tile();MailFrameBotRight=tile()
InboxFrame.OnShow();assert(made==3 and not InboxFrame.stOriginalParchment)
local right=InboxFrame.stParchmentTiles[2]
width=256;InboxFrame.OnShow();assert(made==4 and InboxFrame.stOriginalParchment)
assert(InboxFrame.stParchmentTiles[2]==right)
restore();InboxFrame.OnShow();assert(made==4)
-- Transparent/common rarity borders must retain their exact color and alpha.
frame.color={1,1,1,.4};darken(frame);assert(frame.color[1]==1 and frame.color[4]==.4)
frame.stPreserveRarityColor=nil;darken(frame);assert(frame.color[1]==.3)
print('Mail parchment: absent/zero-size tiles retry on show, partial pieces reused, completed initialization idempotent')
local blocked=Extract('local PATH_CACHE_LIMIT =','local function AddSpecialBackground','return IsBlacklisted',
 'local blacklist={StationeryTest=true};local whitelist={};')
for _,path in ipairs({'Interface\\Stationery\\Stationery_Illidan','Interface\\Stationery\\StationeryTest1','interface\\stationery\\custom'}) do
 local paper={GetName=function() return 'Paper' end,GetTexture=function() return path end}
 assert(blocked(paper))
end
assert(blocked({GetName=function() return 'StationeryBackgroundRight' end,GetTexture=function() return 'CustomPaper' end}))
-- Exercise the real traversal with an already-assigned stationery texture.
IsBlacklisted=blocked
IsSlotArtwork=Extract('local function IsSlotArtwork','local function TintSlotBorder','return IsSlotArtwork')
local paper={GetName=function() return 'StationeryBackgroundLeft' end,
 GetTexture=function() return 'Interface\\Stationery\\Stationery_Default' end,
 GetObjectType=function() return 'Texture' end,GetBlendMode=function() return 'BLEND' end,
 SetVertexColor=function() error('Recursive recoloring must not tint stationery') end}
frame.GetRegions=function() return paper end
darken(frame);darken(frame)
for _,path in ipairs({'Interface\\QuestFrame\\UI-QuestLog-Empty-TopLeft','Interface\\QuestFrame\\UI-QuestLog-Empty-BotRight'}) do
 assert(blocked({GetName=function() return nil end,GetTexture=function() return path end}))
end
assert(not string.find(source,'["^QuestLogDetailScrollFrame$"]',1,true))
assert(not string.find(source,'["^EmptyQuestLogFrame$"]',1,true))
print('Send-mail stationery and empty quest-log artwork are excluded from tinting; replacement quest-log stationery removed')
local restoreLog=Extract('local function RestoreQuestLogParchment','local function DarkenFrame','return RestoreQuestLogParchment')
local regions={}
local textureMethods={}
function textureMethods:GetTexture() return self.path end
function textureMethods:GetWidth() return self.width end
function textureMethods:GetHeight() return self.height end
function textureMethods:SetTexture(v) self.path=v end
function textureMethods:SetWidth(v) self.width=v end
function textureMethods:SetHeight(v) self.height=v end
function textureMethods:SetPoint(...) self.point=arg end
function textureMethods:SetTexCoord(...) self.coords=arg end
function textureMethods:SetVertexColor(...) self.color=arg end
local function native(path,width,height)
 local t=setmetatable({path=path,width=width,height=height},{__index=textureMethods})
 table.insert(regions,t);return t
end
local left=native('Interface\\QuestFrame\\UI-QuestLog-Left',512,512)
local right=native('Interface\\QuestFrame\\UI-QuestLog-Right',256,512)
local log={GetName=function() return 'QuestLogFrame' end,GetRegions=function() return unpack(regions) end}
function log:CreateTexture(_,layer) assert(layer=='OVERLAY');return native() end
restoreLog(log)
assert(table.getn(regions)==5 and table.getn(left.stQuestLogCrops)==2 and table.getn(right.stQuestLogCrops)==1)
local paper=left.stQuestLogCrops[2]
assert(paper.path==left.path and paper.width==164 and paper.height==382 and paper.point[4]==348)
assert(paper.coords[1]==348/512 and paper.color[4]==1 and paper.stOriginalQuestPaper)
assert(right.stQuestLogCrops[1].width==136 and right.stQuestLogCrops[1].height==382)
assert(left.stQuestLogCrops[1].width==301 and left.stQuestLogCrops[1].height==362)
restoreLog(log);assert(table.getn(regions)==5)
print('Native Turtle quest log: original list/paper textures, torn-edge crops, white opaque fills and idempotent reuse')
