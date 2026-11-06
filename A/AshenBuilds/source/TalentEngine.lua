AshenBuilds = AshenBuilds or {}
local AB = AshenBuilds

AB.CLASS_TOKENS = {Warrior="WARRIOR",Paladin="PALADIN",Hunter="HUNTER",Rogue="ROGUE",Priest="PRIEST",Shaman="SHAMAN",Mage="MAGE",Warlock="WARLOCK",Druid="DRUID"}
AB.TREE_NAMES = {
  WARRIOR={"Arms","Fury","Protection"}, PALADIN={"Holy","Protection","Retribution"}, HUNTER={"Beast Mastery","Marksmanship","Survival"},
  ROGUE={"Assassination","Combat","Subtlety"}, PRIEST={"Discipline","Holy","Shadow"}, SHAMAN={"Elemental","Enhancement","Restoration"},
  MAGE={"Arcane","Fire","Frost"}, WARLOCK={"Affliction","Demonology","Destruction"}, DRUID={"Balance","Feral","Restoration"}
}

local function ensureTalents(build)
  build.talents = build.talents or {}
  build.talents.points = build.talents.points or {}
  return build.talents.points
end
AB.EnsureTalents = ensureTalents

local oldMigrate = AB.MigrateBuild
function AB:MigrateBuild(build)
  oldMigrate(self, build)
  ensureTalents(build)
end

function AB:GetTalentData(className)
  local token=self.CLASS_TOKENS[className] or string.upper(className or "")
  return AshenBuildsTalentData and AshenBuildsTalentData[token], token
end

function AB:GetTalentKey(treeIndex,talentIndex) return tostring(treeIndex)..":"..tostring(talentIndex) end
function AB:GetTalentRank(build,treeIndex,talentIndex)
  local p=ensureTalents(build or self.current)
  return tonumber(p[self:GetTalentKey(treeIndex,talentIndex)]) or 0
end
function AB:GetTalentPointsInTree(build,treeIndex)
  local data=self:GetTalentData((build or self.current).class); if not data or not data[treeIndex] then return 0 end
  local total=0; local i
  for i=1,table.getn(data[treeIndex]) do total=total+self:GetTalentRank(build,treeIndex,i) end
  return total
end
function AB:GetTalentPointsSpent(build)
  local total=0; local t
  for t=1,3 do total=total+self:GetTalentPointsInTree(build or self.current,t) end
  return total
end
function AB:GetTalentBudget(build)
  local level=self:GetBuildLevel(build or self.current)
  return math.max(0,level-9)
end
function AB:CanAddTalent(build,treeIndex,talentIndex)
  build=build or self.current
  local data=self:GetTalentData(build.class); local talent=data and data[treeIndex] and data[treeIndex][talentIndex]
  if not talent then return false,"Talent data unavailable" end
  local rank=self:GetTalentRank(build,treeIndex,talentIndex); local max=table.getn(talent.ranks or {})
  if rank>=max then return false,"Maximum rank" end
  if self:GetTalentPointsSpent(build)>=self:GetTalentBudget(build) then return false,"No talent points available" end
  local required=(tonumber(talent.row) or 1)-1; required=required*5
  if self:GetTalentPointsInTree(build,treeIndex)<required then return false,"Requires "..required.." points in this tree" end
  if talent.req then
    local reqRank=self:GetTalentRank(build,treeIndex,tonumber(talent.req))
    local reqTalent=data[treeIndex][tonumber(talent.req)]
    local reqMax=reqTalent and table.getn(reqTalent.ranks or {}) or 1
    if reqRank<reqMax then return false,"Requires "..((reqTalent and reqTalent.name) or "prerequisite talent") end
  end
  return true
end
function AB:SetTalentRank(treeIndex,talentIndex,rank)
  local build=self.current; local data=self:GetTalentData(build.class); local talent=data and data[treeIndex] and data[treeIndex][talentIndex]
  if not talent then return end
  local max=table.getn(talent.ranks or {}); rank=math.max(0,math.min(max,tonumber(rank) or 0))
  local key=self:GetTalentKey(treeIndex,talentIndex); ensureTalents(build)[key]=rank>0 and rank or nil
  build.spec="Custom"; build.updated=time(); self:RefreshUI(); if self.RefreshTalentUI then self:RefreshTalentUI() end
end
function AB:AddTalentPoint(treeIndex,talentIndex)
  local ok,msg=self:CanAddTalent(self.current,treeIndex,talentIndex); if not ok then self.Print(msg); return end
  self:SetTalentRank(treeIndex,talentIndex,self:GetTalentRank(self.current,treeIndex,talentIndex)+1)
end
function AB:RemoveTalentPoint(treeIndex,talentIndex)
  local rank=self:GetTalentRank(self.current,treeIndex,talentIndex); if rank<=0 then return end
  local data=self:GetTalentData(self.current.class); local tree=data and data[treeIndex]; local i,t
  for i=1,table.getn(tree or {}) do t=tree[i]; if tonumber(t.req)==talentIndex and self:GetTalentRank(self.current,treeIndex,i)>0 then self.Print("Remove dependent talent "..t.name.." first."); return end end
  self:SetTalentRank(treeIndex,talentIndex,rank-1)
end
function AB:ResetTalents()
  self.current.talents={points={}}; self.current.spec="Custom"; self.current.updated=time(); self:RefreshUI(); if self.RefreshTalentUI then self:RefreshTalentUI() end
end

local function rankValue(desc,rank)
  if not desc or rank<=0 then return nil end
  local nums={}; local n
  for n in string.gfind(desc,"(%d+%.?%d*)") do table.insert(nums,tonumber(n)) end
  return nums[rank] or nums[table.getn(nums)]
end
local function add(m,k,v) if v and v~=0 then m[k]=(m[k] or 0)+v end end

function AB:GetTalentModifiers(build)
  build=build or self.current
  local data=self:GetTalentData(build.class); local m={notes={},sources={}}; if not data then return m end
  local ti,i,talent,rank,desc,v,name
  for ti=1,3 do
    for i=1,table.getn(data[ti] or {}) do
      talent=data[ti][i]; rank=self:GetTalentRank(build,ti,i)
      if rank>0 then
        desc=string.lower(talent.desc or ""); name=talent.name or "Talent"; v=rankValue(talent.desc,rank)
        local applied={}
        local function effect(k,val,label) add(m,k,val); table.insert(applied,label or k) end
        -- Direct character sheet stats.
        if string.find(desc,"chance to get a critical strike with melee weapons",1,true) or name=="Cruelty" then effect("meleeCrit",v,"melee crit") end
        if string.find(desc,"critical strike chance with ranged weapons",1,true) or string.find(desc,"ranged critical strike chance",1,true) or name=="Lethal Shots" then effect("rangedCrit",v,"ranged crit") end
        if string.find(desc,"critical strike chance while in bear",1,true) or name=="Sharpened Claws" then effect("feralCrit",v,"feral crit") end
        if string.find(desc,"chance to dodge",1,true) and not string.find(desc,"target",1,true) then effect("dodge",v,"dodge") end
        if string.find(desc,"parry chance",1,true) then effect("parry",v,"parry") end
        if string.find(desc,"chance to block",1,true) then effect("block",v,"block") end
        if string.find(desc,"chance to hit with melee attacks and spells",1,true) then effect("hit",v,"melee hit"); effect("spellHit",v,"spell hit") end
        if string.find(desc,"chance to hit with melee attacks",1,true) and not string.find(desc,"and spells",1,true) then effect("hit",v,"melee hit") end
        if string.find(desc,"chance to hit with ranged weapons",1,true) or string.find(desc,"ranged hit chance",1,true) then effect("rangedHit",v,"ranged hit") end
        if string.find(desc,"chance for enemies to resist your",1,true) or string.find(desc,"reduces the chance for enemies to resist",1,true) then effect("spellHit",v,"spell hit") end
        if string.find(desc,"critical effect chance of your holy and discipline spells",1,true) then effect("spellCrit",v,"spell crit") end
        if string.find(desc,"critical strike chance of all fire spells",1,true) or string.find(desc,"critical strike chance of your fire spells",1,true) then effect("spellCrit",v,"spell crit") end
        if string.find(desc,"critical strike chance of your frost spells",1,true) then effect("spellCrit",v,"spell crit") end
        if string.find(desc,"critical strike chance of your nature spells",1,true) then effect("spellCrit",v,"spell crit") end
        if string.find(desc,"critical strike chance of your offensive spells",1,true) then effect("spellCrit",v,"spell crit") end
        if string.find(desc,"spell damage and the critical strike chance",1,true) then effect("spellPowerPct",v,"spell damage %"); effect("spellCrit",v,"spell crit") end
        if string.find(desc,"total intellect by",1,true) then effect("intPct",v,"Intellect %") end
        if string.find(desc,"total spirit by",1,true) then effect("spiPct",v,"Spirit %") end
        if string.find(desc,"total strength by",1,true) then effect("strPct",v,"Strength %") end
        if string.find(desc,"total stamina by",1,true) then effect("staPct",v,"Stamina %") end
        if string.find(desc,"total agility by",1,true) then effect("agiPct",v,"Agility %") end
        if string.find(desc,"maximum mana by",1,true) or string.find(desc,"total mana by",1,true) then effect("manaPct",v,"Mana %") end
        if string.find(desc,"maximum health by",1,true) or string.find(desc,"total health by",1,true) then effect("healthPct",v,"Health %") end
        if string.find(desc,"armor contribution from items by",1,true) then effect("armorPct",v,"Armor %") end
        if string.find(desc,"increases your armor value from items by",1,true) then effect("armorPct",v,"Armor %") end
        if string.find(desc,"melee attack power in cat, bear",1,true) then effect("feralAPPct",v,"Feral AP %") end
        if string.find(desc,"spell damage and healing by up to",1,true) and string.find(desc,"of your total spirit",1,true) then effect("spiritToSpellPct",v,"Spirit to spell/healing") end
        if string.find(desc,"all spell damage and healing by",1,true) and string.find(desc,"of your total intellect",1,true) then effect("intToSpellPct",v,"Intellect to spell/healing") end
        if string.find(desc,"increases your defense skill by",1,true) then effect("defense",v,"defense") end
        if string.find(desc,"block value of your shield by",1,true) and string.find(desc,"%",1,true) then effect("blockValuePct",v,"block value %") end
        if string.find(desc,"skill in all two-handed weapons by",1,true) then effect("twoHandSkill",v,"two-hand skill") end
        if string.find(desc,"skill with swords",1,true) then effect("swordSkill",v,"sword skill") end
        if string.find(desc,"skill with axes",1,true) then effect("axeSkill",v,"axe skill") end
        if string.find(desc,"skill with maces",1,true) then effect("maceSkill",v,"mace skill") end
        -- Explicit Turtle talents whose text has multiple independent numeric series.
        if name=="Force of Will" then effect("spellPowerPct",rank,"spell damage %"); effect("spellCrit",rank,"spell crit") end
        if name=="Mental Strength" then local vals={3,6,10}; m.intPct=(m.intPct or 0)+(vals[rank] or 0); table.insert(applied,"Intellect %") end
        if name=="Spirit of Redemption" then effect("spiPct",10,"Spirit %") end
        if name=="Natural Weapons" then local vals={1,2,3}; effect("hit",vals[rank],"melee hit"); effect("spellHit",vals[rank],"spell hit") end
        if name=="Feral Swiftness" then local vals={2,4}; effect("feralDodge",vals[rank],"feral dodge") end
        if name=="Moonkin Form" then effect("moonkinArmorPct",180,"Moonkin armor"); effect("spellCrit",3,"party spell crit") end
        if name=="Thick Hide" then local vals={3,6,10}; effect("armorPct",vals[rank],"Armor %") end
        if name=="Sharpened Claws" then local vals={2,4,6}; effect("feralCrit",vals[rank],"feral crit") end
        if name=="Predatory Strikes" then local vals={3,6,10}; effect("feralAPPct",vals[rank],"Feral AP %") end
        if name=="Divinity" then effect("spellCrit",rank,"Holy/Discipline spell crit") end
        if name=="Spiritual Guidance" then effect("spiritToSpellPct",rank*5,"Spirit to spell/healing") end
        if table.getn(applied)>0 then table.insert(m.sources,{name=name,rank=rank,effects=table.concat(applied,", ")}) end
      end
    end
  end
  return m
end

-- Talents in build codes (AB3). An AB3 code is the AB2 gear code followed by
-- one token per talent tree. Each character packs two talents' ranks (0-5) as
-- first*6+second, and trailing all-zero characters are trimmed, so a full
-- build adds about 30 characters and still fits in one chat message.
local function encodeTree(build,data,tree)
  local out,i,a,b="",nil,nil,nil
  for i=1,table.getn(data[tree] or {}),2 do
    a=AB:GetTalentRank(build,tree,i); b=AB:GetTalentRank(build,tree,i+1)
    out=out..AB.EncodeNumber(a*6+b)
  end
  out=string.gsub(out,"0+$","")
  if out=="" then out="0" end
  return out
end

local function decodeTree(token,points,tree)
  local k,v
  for k=1,string.len(token) do
    v=AB.DecodeNumber(string.sub(token,k,k))
    if not v or v>35 then return false end
    if math.floor(v/6)>0 then points[AB:GetTalentKey(tree,k*2-1)]=math.floor(v/6) end
    if math.mod(v,6)>0 then points[AB:GetTalentKey(tree,k*2)]=math.mod(v,6) end
  end
  return true
end

-- Checks a finished allocation the way the talent UI would have built it:
-- known talents only, ranks within max, enough points in lower rows, maxed
-- prerequisites, and no more points than the level allows.
function AB:ValidateTalents(build)
  local points=ensureTalents(build); local data=self:GetTalentData(build.class)
  local key,rank,tree,index,talent,below,i,other,_
  for key,rank in pairs(points) do
    _,_,tree,index=string.find(key,"^(%d+):(%d+)$"); tree=tonumber(tree); index=tonumber(index)
    talent=data and tree and data[tree] and data[tree][index]
    if not talent then return false,"unknown talent "..key end
    rank=tonumber(rank) or 0
    if rank<1 or rank>table.getn(talent.ranks or {}) then return false,talent.name.." has too many ranks" end
    below=0
    for i=1,table.getn(data[tree]) do
      other=data[tree][i]
      if (tonumber(other.row) or 1)<(tonumber(talent.row) or 1) then below=below+self:GetTalentRank(build,tree,i) end
    end
    if below<((tonumber(talent.row) or 1)-1)*5 then return false,talent.name.." needs more points in earlier rows" end
    if talent.req then
      other=data[tree][tonumber(talent.req)]
      if not other or self:GetTalentRank(build,tree,tonumber(talent.req))<table.getn(other.ranks or {}) then return false,talent.name.." is missing its prerequisite" end
    end
  end
  if self:GetTalentPointsSpent(build)>self:GetTalentBudget(build) then return false,"more talent points than level "..self:GetBuildLevel(build).." allows" end
  return true
end

-- "31/20/0"-style point split, used by the community list.
function AB:GetTalentSplit(build)
  return self:GetTalentPointsInTree(build,1).."/"..self:GetTalentPointsInTree(build,2).."/"..self:GetTalentPointsInTree(build,3)
end

local baseExport=AB.ExportBuild
function AB:ExportBuild(build)
  build=build or self.current
  local code=baseExport(self,build)
  local data=self:GetTalentData(build.class)
  if not data then return code end
  return "AB3."..string.sub(code,5).."."..encodeTree(build,data,1).."."..encodeTree(build,data,2).."."..encodeTree(build,data,3)
end

local baseDecode=AB.DecodeBuild
function AB:DecodeBuild(code)
  if type(code)~="string" or string.sub(code,1,4)~="AB3." then
    local build,err=baseDecode(self,code)
    if build then ensureTalents(build) end
    return build,err
  end
  local tokens={}; local token
  for token in string.gfind(code,"[^%.]+") do table.insert(tokens,token) end
  local n=table.getn(tokens)
  if n<8 then return nil,"Incomplete build code." end
  local build,err=baseDecode(self,"AB2."..table.concat(tokens,".",2,n-3))
  if not build then return nil,err end
  local points={}; local tree
  for tree=1,3 do
    if not decodeTree(tokens[n-3+tree],points,tree) then return nil,"Invalid talents in build code." end
  end
  build.talents={points=points}
  local ok,why=self:ValidateTalents(build)
  if not ok then return nil,"Invalid talents in build code ("..why..")." end
  return build
end
