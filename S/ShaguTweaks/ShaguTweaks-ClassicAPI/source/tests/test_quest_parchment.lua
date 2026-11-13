local root=(arg[1] or '.')..'/'
local f=assert(io.open(root..'mods/dark-ui-elements.lua','r'))
local source=f:read('*a');f:close();assert(loadstring(source))
local a=assert(string.find(source,'local function RestoreQuestParchment',1,true))
local b=assert(string.find(source,'local function DarkenFrame',a,true))
local restore=assert(loadstring(string.sub(source,a,b-1)..'return RestoreQuestParchment'))()
local methods={}
function methods:GetTexture() return self.path end
function methods:SetTexture(v) self.path=v end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:SetWidth(v) self.width=v end
function methods:SetHeight(v) self.height=v end
function methods:SetPoint(...) self.point=arg end
function methods:SetTexCoord(...) self.uv=arg end
function methods:SetVertexColor(...) self.color=arg end
function methods:SetDrawLayer(layer) self.layer=layer end
local function texture(path,w,h) return setmetatable({path=path,width=w,height=h},{__index=methods}) end

local spellbookStart=assert(string.find(source,'local spellbookPaper =',1,true))
local restoreSpellbook=assert(loadstring(string.sub(source,spellbookStart,a-1)..'return RestoreSpellbookParchment'))()
SpellBookPageText=texture()
local spellbook={copies=0}
function spellbook:CreateTexture(_,layer)
 self.copies=self.copies+1
 local paper=texture();paper:SetDrawLayer(layer);return paper
end
for _,suffix in ipairs({'TopLeft','TopRight','BotLeft','BotRight'}) do
 local left=string.find(suffix,'Left',1,true)
 local top=string.find(suffix,'Top',1,true)
 local tile=texture('Interface\\Spellbook\\UI-SpellbookPanel-'..suffix,left and 256 or 128,256)
 restoreSpellbook(spellbook,tile)
 restoreSpellbook(spellbook,tile)
 local paper=assert(tile.stSpellbookPaper)
 assert(paper.path==tile.path and paper.color[1]==1 and paper.color[4]==1)
 assert(paper.width==(left and 234 or 85) and paper.height==(top and 182 or 175))
 assert(paper.point[2]==tile and paper.point[4]==(left and 22 or 0) and paper.point[5]==(top and -74 or 0))
 assert(tile.layer=='BORDER' and paper.layer=='ARTWORK' and SpellBookPageText.layer=='OVERLAY')
end
restoreSpellbook(spellbook,texture('Interface\\Spellbook\\Spellbook-Icon',58,58))
assert(spellbook.copies==4)
assert(not string.find(source,'["^SpellBookFrame$"]',1,true))

for _,name in ipairs({'GossipFrameGreetingPanel','QuestFrameGreetingPanel','QuestFrameDetailPanel','QuestFrameProgressPanel','QuestFrameRewardPanel'}) do
 local regions={}
 for _,suffix in ipairs({'TopLeft','TopRight','BotLeft','BotRight'}) do
  table.insert(regions,texture('Interface\\QuestFrame\\UI-QuestGreeting-'..suffix,string.find(suffix,'Left') and 256 or 128,256))
 end
 table.insert(regions,texture('Interface\\QuestFrame\\UI-Quest-BotLeftPatch',128,64))
 local panel={GetName=function() return name end,GetRegions=function() return unpack(regions) end}
 function panel:CreateTexture(_,layer) assert(layer=='ARTWORK');local t=texture();table.insert(regions,t);return t end
 restore(panel);assert(table.getn(regions)==9)
 local left,right=regions[1].stQuestPaper,regions[2].stQuestPaper
 assert(left.width==234 and left.height==174 and left.color[1]==1)
 assert(right.width==67 and right.uv[2]==67/128)
 assert(left.point[5]==-82 and regions[3].stQuestPaper.uv[4]==160/256)
 assert(regions[4].stQuestPaper.height==160)
 assert(not regions[5].stQuestPaper) -- the bottom patch is not a 256px tile
 restore(panel);assert(table.getn(regions)==9)
end
assert(not string.find(source,'["^GossipFrameGreetingPanel$"]',1,true))
assert(not string.find(source,'["^QuestFrame(.+)Panel$"]',1,true))
local f=assert(io.open(root..'mods/reduced-actionbar.lua','r'));local reduced=f:read('*a');f:close()
assert(loadstring(reduced));assert(string.find(reduced,'ShaguTweaks.EnableActionBarMovers()',1,true))
print('Native quest/gossip parchment: four original crops, right-tile dimensions, no stationery overlay, idempotence; Reduced Actionbar enables movement')
local start=assert(string.find(source,'local function ShadeNpcTitleBar',1,true))
local finish=assert(string.find(source,'local function ShadeTitleBars',start,true))
local shade=assert(loadstring(string.sub(source,start,finish-1)..'return ShadeNpcTitleBar'))()
local rootFrame={GetFrameLevel=function() return 1 end}
local nameFrame={level=2,GetFrameLevel=function(self) return self.level end,SetFrameLevel=function(self,v) self.level=v end}
local calls=0
function ShadeTitleBar(frame,strip,title,color,level)
 calls=calls+1;assert(frame==rootFrame and title==nil and level==61)
 assert(strip[2]==-22 and strip[4]==-39)
 frame.stTitleBar={}
end
shade(rootFrame,nameFrame,{[1]={GetFrameLevel=function() return 57 end},[3]={GetFrameLevel=function() return 60 end}}, {})
assert(nameFrame.level==62 and calls==1)
shade(rootFrame,nameFrame,{},{});assert(calls==1)
print('NPC Golden title shade stays above all panels and below the native name, without duplicate text or shade')
