AshenBuilds = AshenBuilds or {}
-- AshenDB adapter for Ashen Builds v0.7.4
-- Converts AshenDB's compact positional records into the planner's item format on demand.
AshenBuildsItemOrder = (AshenDB and AshenDB.ItemOrder) or {}
AshenBuildsDBPack = {
  name = "AshenDB",
  version = (AshenDB and AshenDB.Manifest and AshenDB.Manifest.version) or "missing",
  count = (AshenDB and AshenDB.GetItemCount and AshenDB:GetItemCount()) or table.getn(AshenBuildsItemOrder)
}

local CACHE = {}
local function IconPath(icon)
  icon = icon or "INV_Misc_QuestionMark"
  if string.find(icon, "\\", 1, true) or string.find(icon, "/", 1, true) then return icon end
  return "Interface\\Icons\\" .. icon
end

local function WeaponInfo(name)
  if not name or name == "" then return nil, false end
  local two = string.find(name, "Two%-Hand") ~= nil
  local t = name
  t = string.gsub(t, "Two%-Hand%s*", "")
  t = string.gsub(t, "%s+", "")
  if t == "FishingPole" then t = "Staff" end
  return t, two
end

function AshenBuilds:GetRawItem(id)
  return AshenDB and AshenDB.Items and AshenDB.Items[tonumber(id)]
end

function AshenBuilds:GetItem(id)
  id = tonumber(id)
  if not id then return nil end
  if CACHE[id] then return CACHE[id] end
  local r = self:GetRawItem(id)
  if not r then return nil end
  local weaponType, twoHand = WeaponInfo(r[18])
  local sources = r[20] or {}
  local item = {
    id=id, n=r[1] or ("Item "..id), q=r[2] or 1, slot=r[3], req=r[4] or 0, ilvl=r[5] or 0,
    icon=IconPath(r[6]), itemClass=r[7] or 0, subclass=r[8] or 0, armor=r[9] or 0,
    set=((tonumber(r[10]) and tonumber(r[10]) ~= 0) and tonumber(r[10])) or (self.ItemToSet and self.ItemToSet[id]) or (AshenDB and AshenDB.ItemToSet and AshenDB.ItemToSet[id]), classMask=r[11] or -1, raceMask=r[12] or -1,
    bind=r[13] or 0, unique=r[14] or 0, speed=(r[15] or 0)/1000, minDamage=r[16] or 0,
    maxDamage=r[17] or 0, weaponType=weaponType, twoHand=twoHand,
    shield=(r[3] == "SHIELD"), stats=r[19] or {}, sources=sources,
    source=table.concat(sources, ", ")
  }
  CACHE[id] = item
  return item
end

function AshenBuilds:GetItemSet(setId)
  setId = tonumber(setId)
  if not setId then return nil end
  if self.SetCatalog and self.SetCatalog[setId] then return self.SetCatalog[setId] end
  if AshenDB and AshenDB.ItemSets then return AshenDB.ItemSets[setId] or AshenDB.ItemSets[tostring(setId)] end
  return nil
end

function AshenBuilds:GetItemSetId(id,item)
  id=tonumber(id)
  local setId=item and tonumber(item.set)
  if not setId or setId==0 then
    local raw=id and self:GetRawItem(id)
    setId=raw and tonumber(raw[10])
  end
  if (not setId or setId==0) and id then
    setId=(self.ItemToSet and self.ItemToSet[id]) or (AshenDB and AshenDB.ItemToSet and AshenDB.ItemToSet[id])
  end
  setId=tonumber(setId)
  if not setId or setId==0 then return nil end
  return setId
end

function AshenBuilds:GetItemSetForItem(id,item)
  local setId=self:GetItemSetId(id,item)
  if not setId then return nil,nil end
  return self:GetItemSet(setId),setId
end

function AshenBuilds:IsClassAllowedRaw(r, className)
  if not r then return false end
  local mask = tonumber(r[11]) or -1
  if mask < 0 then return true end
  local bits={Warrior=1,Paladin=2,Hunter=4,Rogue=8,Priest=16,Shaman=64,Mage=128,Warlock=256,Druid=1024}
  local bit=bits[className or ""]
  if not bit then return true end
  return math.mod(math.floor(mask/bit),2) == 1
end

function AshenBuilds:IsHiddenRaw(r)
  if not r then return true end
  local n=string.upper(r[1] or "")
  local bad={"TEST","OLD","DEPRECATED","UNUSED","PLACEHOLDER","INTERNAL","DEBUG","GAMEMASTER","GM ONLY","QA ","NPC ONLY"}
  local i
  for i=1,table.getn(bad) do if string.find(n,bad[i],1,true) then return true end end
  return false
end

function AshenBuilds:GetArmorTypeRaw(r)
  if not r or r[7] ~= 4 then return "Other" end
  local map={[1]="Cloth",[2]="Leather",[3]="Mail",[4]="Plate",[6]="Shield"}
  return map[r[8]] or "Other"
end

function AshenBuilds:GetWeaponTypeRaw(r)
  if not r or r[7] ~= 2 then return "Other" end
  return r[18] or "Other"
end
