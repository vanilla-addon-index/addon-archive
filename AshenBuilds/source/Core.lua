AshenBuilds = AshenBuilds or {}
AshenBuilds.VERSION = "1.0.0"

AshenBuilds.SLOTS = {
  "HEAD","NECK","SHOULDER","BACK","CHEST","SHIRT","TABARD","WRIST","HANDS","WAIST","LEGS","FEET",
  "FINGER1","FINGER2","TRINKET1","TRINKET2","MAINHAND","OFFHAND","RANGED"
}
AshenBuilds.SLOT_LABELS = {
  HEAD="Head", NECK="Neck", SHOULDER="Shoulder", BACK="Back", CHEST="Chest", SHIRT="Shirt", TABARD="Tabard", WRIST="Wrist",
  HANDS="Hands", WAIST="Waist", LEGS="Legs", FEET="Feet", FINGER1="Ring 1", FINGER2="Ring 2",
  TRINKET1="Trinket 1", TRINKET2="Trinket 2", MAINHAND="Main Hand", OFFHAND="Off Hand", RANGED="Ranged"
}
AshenBuilds.INVENTORY_SLOTS = {
  HEAD=1, NECK=2, SHOULDER=3, BACK=15, CHEST=5, SHIRT=4, TABARD=19, WRIST=9, HANDS=10, WAIST=6, LEGS=7, FEET=8,
  FINGER1=11, FINGER2=12, TRINKET1=13, TRINKET2=14, MAINHAND=16, OFFHAND=17, RANGED=18
}
AshenBuilds.CLASSES = {"Warrior","Paladin","Hunter","Rogue","Priest","Shaman","Mage","Warlock","Druid"}
AshenBuilds.RACES = {"Human","Dwarf","Night Elf","Gnome","Orc","Tauren","Troll","Undead","High Elf","Goblin"}
AshenBuilds.SPECS = {
  Warrior={"Arms","Fury","Protection","Custom"}, Paladin={"Holy","Protection","Retribution","Custom"},
  Hunter={"Beast Mastery","Marksmanship","Survival","Custom"}, Rogue={"Assassination","Combat","Subtlety","Custom"},
  Priest={"Discipline","Holy","Shadow","Custom"}, Shaman={"Elemental","Enhancement","Restoration","Custom"},
  Mage={"Arcane","Fire","Frost","Custom"}, Warlock={"Affliction","Demonology","Destruction","Custom"},
  Druid={"Balance","Feral","Restoration","Custom"}
}
AshenBuilds.STAT_LABELS = {
  str="Strength", agi="Agility", sta="Stamina", int="Intellect", spi="Spirit", armor="Armor",
  ap="Attack Power", rap="Ranged Attack Power", spellPower="Spell Power", healing="Healing", hit="Hit", spellHit="Spell Hit",
  crit="Crit", spellCrit="Spell Crit", defense="Defense", dodge="Dodge", parry="Parry", block="Block", blockValue="Block Value",
  mp5="Mana per 5", hp5="Health per 5", fireRes="Fire Resist", frostRes="Frost Resist",
  natureRes="Nature Resist", shadowRes="Shadow Resist", arcaneRes="Arcane Resist",
  swordSkill="Sword Skill", axeSkill="Axe Skill", daggerSkill="Dagger Skill", maceSkill="Mace Skill", fistSkill="Fist Skill", polearmSkill="Polearm Skill", bowSkill="Bow Skill", gunSkill="Gun Skill", crossbowSkill="Crossbow Skill", thrownSkill="Thrown Skill",
  firePower="Fire Power", frostPower="Frost Power", naturePower="Nature Power", shadowPower="Shadow Power", arcanePower="Arcane Power", holyPower="Holy Power", spellPen="Spell Penetration", armorPen="Armor Penetration", haste="Haste",
  rangedHit="Ranged Hit", health="Health", mana="Mana", feralAp="Feral Attack Power", blockValue="Block Value",
  rangedCrit="Ranged Crit", leech="Vampirism"
}
AshenBuilds.GEAR_STAT_ORDER = {
  "str","agi","sta","int","spi","armor","ap","rap","spellPower","healing","hit","spellHit","crit","spellCrit",
  "defense","dodge","parry","block","blockValue","mp5","hp5","fireRes","frostRes","natureRes","shadowRes","arcaneRes",
  "swordSkill","axeSkill","daggerSkill","maceSkill"
}
AshenBuilds.QUALITY_LABELS = {[0]="Poor",[1]="Common",[2]="Uncommon",[3]="Rare",[4]="Epic",[5]="Legendary"}
AshenBuilds.ARMOR_LABELS = {"All","Cloth","Leather","Mail","Plate","Shield","Misc"}
AshenBuilds.DB_PACK = AshenBuildsDBPack or {name="Starter Pack",version="starter",count=0}

local function AB_Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffd76b2aAshen Builds:|r " .. msg)
end
AshenBuilds.Print = AB_Print

local function AB_IndexOf(list, value)
  local i
  for i=1,table.getn(list) do if list[i] == value then return i end end
  return 1
end
AshenBuilds.IndexOf = AB_IndexOf

-- UnitClass/UnitRace return the client's language first ("Krieger", "Mensch");
-- the second value is the English token, which is what builds store.
local CLASS_BY_TOKEN = {WARRIOR="Warrior", PALADIN="Paladin", HUNTER="Hunter", ROGUE="Rogue", PRIEST="Priest",
  SHAMAN="Shaman", MAGE="Mage", WARLOCK="Warlock", DRUID="Druid"}
local RACE_BY_TOKEN = {Human="Human", Dwarf="Dwarf", NightElf="Night Elf", Gnome="Gnome", Orc="Orc", Tauren="Tauren",
  Troll="Troll", Scourge="Undead", Undead="Undead", HighElf="High Elf", BloodElf="High Elf", Goblin="Goblin"}

local function AB_PlayerClass()
  local localized, token = UnitClass("player")
  return CLASS_BY_TOKEN[token or ""] or localized or "Warrior"
end

local function AB_PlayerRace()
  local localized, token = UnitRace("player")
  return RACE_BY_TOKEN[token or ""] or localized or "Human"
end
AshenBuilds.PlayerRace = AB_PlayerRace

local function AB_ValidLevel(value)
  value = tonumber(value)
  if not value or value < 1 or value > 60 then return 60 end
  return math.floor(value)
end
AshenBuilds.ValidLevel = AB_ValidLevel

local function AB_PlayerLevel()
  return AB_ValidLevel(UnitLevel("player"))
end

local function AB_NewBuild(name)
  local class = AB_PlayerClass()
  if not AshenBuilds.SPECS[class] then class = "Warrior" end
  return {
    name = name or "New Build",
    class = class,
    race = AB_PlayerRace(),
    level = AB_PlayerLevel(),
    spec = AshenBuilds.SPECS[class][1],
    notes = "",
    items = {},
    enchants = {},
    base = nil,
    created = time(),
    updated = time()
  }
end
AshenBuilds.NewBuildData = AB_NewBuild

-- SavedVariables are shared by every character on the account, so the build open
-- in the planner is kept per character: logging in on an alt shows that alt's
-- plan (or a fresh one for its class, race and level), not the last character's.
local function AB_CharKey() return (UnitName("player") or "?") .. "-" .. (GetRealmName and GetRealmName() or "") end

-- A planner build nobody has worked on yet: it follows the character.
local function AB_IsUntouched(build)
  if not build or build.savedName or build.manual then return false end
  local slot, id, key, rank
  for slot, id in pairs(build.items or {}) do return false end
  for key, rank in pairs((build.talents and build.talents.points) or {}) do if (tonumber(rank) or 0) > 0 then return false end end
  return true
end
AshenBuilds.IsUntouchedBuild = AB_IsUntouched

function AshenBuilds:InitializeDB()
  if not AshenBuildsDB then AshenBuildsDB = {} end
  if not AshenBuildsDB.builds then AshenBuildsDB.builds = {} end
  if not AshenBuildsDB.settings then AshenBuildsDB.settings = {scale=1, locked=false} end
  AshenBuildsDB.currentByChar = AshenBuildsDB.currentByChar or {}
  local key = AB_CharKey()
  local current = AshenBuildsDB.currentByChar[key]
  if not current then
    -- Saves from before per-character planners had one shared build: the first
    -- character of that class to log in keeps it, everyone else starts fresh.
    local shared = AshenBuildsDB.current
    if shared and not AshenBuildsDB.sharedCurrentClaimed and shared.class == AB_PlayerClass() then current = shared; AshenBuildsDB.sharedCurrentClaimed = true
    else current = AB_NewBuild("New Build") end
    AshenBuildsDB.currentByChar[key] = current
  end
  AshenBuildsDB.current = current
  self.current = AshenBuildsDB.current
  -- Builds from before rename support: link the planner to the saved build with its name.
  if not self.current.savedName and self.current.name and AshenBuildsDB.builds[self.current.name] then self.current.savedName = self.current.name end
  self:MigrateBuild(self.current)
  local name, build
  for name, build in pairs(AshenBuildsDB.builds) do self:MigrateBuild(build) end
end

function AshenBuilds:MigrateBuild(build)
  -- Builds saved on a non-English client before 1.0 hold the player's localized
  -- class and race ("Krieger", "Mensch"); the client gives us both names, so those
  -- are switched to English here.
  local cLocal, cToken = UnitClass("player")
  if build.class and not self.SPECS[build.class] and build.class == cLocal and CLASS_BY_TOKEN[cToken or ""] then build.class = CLASS_BY_TOKEN[cToken] end
  local rLocal, rToken = UnitRace("player")
  if build.race and build.race == rLocal and RACE_BY_TOKEN[rToken or ""] then build.race = RACE_BY_TOKEN[rToken] end
  if not build.class or not self.SPECS[build.class] then build.class = "Warrior" end
  if not build.race then build.race = "Human" end
  build.level = AB_ValidLevel(build.level)
  if not build.spec then build.spec = (self.SPECS[build.class] and self.SPECS[build.class][1]) or "Custom" end
  if not build.items then build.items = {} end
  if not build.enchants then build.enchants = {} end
end

function AshenBuilds:GetBuildLevel(build)
  build = build or self.current
  local level = AB_ValidLevel(build and build.level)
  if build and build.level ~= level then build.level = level end
  return level
end

function AshenBuilds:NormalizeSlot(slot, item)
  if not item then return nil end
  local s=item.slot
  if s == "FINGER" then
    if slot == "FINGER1" or slot == "FINGER2" then return slot end
  elseif s == "TRINKET" then
    if slot == "TRINKET1" or slot == "TRINKET2" then return slot end
  elseif s == "ROBE" then
    if slot == "CHEST" then return slot end
  elseif s == "WEAPON" then
    if slot == "MAINHAND" or slot == "OFFHAND" then return slot end
  elseif s == "TWOHAND" or s == "MAINHAND" then
    if slot == "MAINHAND" then return slot end
  elseif s == "OFFHAND" or s == "SHIELD" or s == "HOLDABLE" then
    if slot == "OFFHAND" then return slot end
  elseif s == "RANGED" or s == "RANGEDRIGHT" or s == "THROWN" or s == "RELIC" then
    if slot == "RANGED" then return slot end
  elseif s == slot then return slot end
  return nil
end

-- Picks the planner slot for an item when the database is browsed across all slots.
function AshenBuilds:ResolveSlotForItem(item)
  local s = item and item.slot
  if not s then return nil end
  local items = self.current.items
  if s == "FINGER" then return (items.FINGER1 and not items.FINGER2) and "FINGER2" or "FINGER1" end
  if s == "TRINKET" then return (items.TRINKET1 and not items.TRINKET2) and "TRINKET2" or "TRINKET1" end
  if s == "ROBE" then return "CHEST" end
  if s == "WEAPON" or s == "TWOHAND" or s == "MAINHAND" then return "MAINHAND" end
  if s == "OFFHAND" or s == "SHIELD" or s == "HOLDABLE" then return "OFFHAND" end
  if s == "RANGED" or s == "RANGEDRIGHT" or s == "THROWN" or s == "RELIC" then return "RANGED" end
  if self.SLOT_LABELS[s] then return s end
  return nil
end

function AshenBuilds:EquipItem(slot, itemID)
  local item = self:GetItem(itemID)
  if not item then AB_Print("Item not found in the local database.") return end
  if not slot or slot == "ALL" then slot = self:ResolveSlotForItem(item) end
  if not slot then AB_Print(item.n .. " can't be equipped in the planner.") return end
  -- A two-hander frees the off hand; an off-hand item replaces a two-hander.
  if slot == "MAINHAND" and (item.twoHand or item.slot == "TWOHAND") then self.current.items.OFFHAND = nil; self.current.enchants.OFFHAND = nil end
  if slot == "OFFHAND" then local mh = self:GetItem(self.current.items.MAINHAND or 0); if mh and (mh.twoHand or mh.slot == "TWOHAND") then self.current.items.MAINHAND = nil; self.current.enchants.MAINHAND = nil end end
  if not self:NormalizeSlot(slot, item) then AB_Print(item.n .. " does not fit " .. self.SLOT_LABELS[slot] .. ".") return end
  self.current.items[slot] = itemID
  local enchantID = self.current.enchants[slot]
  if enchantID and not self:IsEnchantAllowed(slot, enchantID, item) then self.current.enchants[slot] = nil end
  self.current.updated = time()
  AshenBuildsDB.current = self.current
  self:RefreshUI()
end

-- True when the enchant fits this slot and the item currently in it (two-hand only,
-- shield only and weapon only enchants check the item).
function AshenBuilds:IsEnchantAllowed(slot, enchantID, item)
  local e = AshenBuildsEnchants and AshenBuildsEnchants[enchantID]
  if not e or not e.slots[slot] then return false end
  if not item then return true end
  if e.minIlvl and (item.ilvl or 0) < e.minIlvl then return false end
  if e.req == "shield" then return item.shield and true or false end
  if e.req == "twohand" then return (item.twoHand or item.slot == "TWOHAND") and true or false end
  if e.req == "weapon" then return item.itemClass == 2 end
  return true
end

function AshenBuilds:ApplyEnchant(slot, enchantID)
  if enchantID == 0 then self.current.enchants[slot] = nil
  elseif self:IsEnchantAllowed(slot, enchantID, self:GetItem(self.current.items[slot] or 0)) then self.current.enchants[slot] = enchantID
  else AB_Print("That enchant can't be applied to this item.") return end
  self.current.updated = time()
  self:RefreshUI()
end

function AshenBuilds:RemoveItem(slot)
  self.current.items[slot] = nil
  self.current.enchants[slot] = nil
  self.current.updated = time()
  self:RefreshUI()
end

local function AddStats(target, stats)
  local stat, value
  if not stats then return end
  for stat, value in pairs(stats) do target[stat] = (target[stat] or 0) + value end
end

-- Equip effects the item export leaves out of the stat table, read once from the tooltip text.
local EFFECT_STATS = {}
local EFFECT_PATTERNS = {
  {"block value of your shield by (%d+)", "blockValue"},
  {"^Block Value %+(%d+)", "blockValue"},
  {"^%+(%d+) Block Value", "blockValue"},
}
function AshenBuilds:GetItemEffectStats(id)
  id = tonumber(id)
  if not id then return nil end
  if EFFECT_STATS[id] then return EFFECT_STATS[id] end
  local stats = {}
  local d = AshenDB and AshenDB.ItemDetails and AshenDB.ItemDetails[id]
  local effects = d and d[9]
  local i, j, e, text, value
  if effects then
    for i=1,table.getn(effects) do
      e = effects[i]; text = type(e)=="table" and e[2] or e
      if type(text) == "string" then
        for j=1,table.getn(EFFECT_PATTERNS) do
          local _, _, n = string.find(text, EFFECT_PATTERNS[j][1])
          value = tonumber(n)
          if value then stats[EFFECT_PATTERNS[j][2]] = (stats[EFFECT_PATTERNS[j][2]] or 0) + value end
        end
      end
    end
  end
  EFFECT_STATS[id] = stats
  return stats
end

function AshenBuilds:GetGearTotals(build)
  build = build or self.current
  local totals = {}
  local i, slot, id, item, enchantID, enchant
  for i=1,table.getn(self.SLOTS) do
    slot = self.SLOTS[i]
    id = build.items[slot]
    item = id and self:GetItem(id)
    if item then AddStats(totals, item.stats); AddStats(totals, self:GetItemEffectStats(id)) end
    enchantID = build.enchants and build.enchants[slot]
    enchant = enchantID and AshenBuildsEnchants and AshenBuildsEnchants[enchantID]
    if enchant then AddStats(totals, enchant.stats) end
  end
  return totals
end

function AshenBuilds:GetSetCounts(build)
  build = build or self.current
  local counts = {}
  local i, item
  for i=1,table.getn(self.SLOTS) do
    item = self:GetItem(build.items[self.SLOTS[i]] or 0)
    if item and item.set then local setId=tonumber(item.set); if setId then counts[setId] = (counts[setId] or 0) + 1 end end
  end
  return counts
end

function AshenBuilds:SetClass(value)
  self.current.class = value; self.current.manual = true
  self.current.spec = self.SPECS[value][1]
  self.current.updated = time(); self:RefreshUI()
end
function AshenBuilds:SetRace(value) self.current.race=value; self.current.manual=true; self.current.updated=time(); self:RefreshUI() end
function AshenBuilds:SetSpec(value) self.current.spec=value; self.current.updated=time(); self:RefreshUI() end
function AshenBuilds:SetLevel(value)
  value=AB_ValidLevel(value)
  self.current.level=value; self.current.manual=true; self.current.updated=time(); self:RefreshUI()
end

function AshenBuilds:ImportEquipped()
  local found, missing = 0, 0
  local i, slot, inv, link, id
  for i=1,table.getn(self.SLOTS) do
    slot=self.SLOTS[i]; inv=self.INVENTORY_SLOTS[slot]; link=GetInventoryItemLink("player",inv)
    if link then
      local _,_,raw=string.find(link,"item:(%d+)"); id=tonumber(raw)
      if id and self:GetItem(id) then self.current.items[slot]=id; found=found+1 else missing=missing+1 end
    else self.current.items[slot]=nil end
  end
  self.current.class=AB_PlayerClass(); self.current.race=AB_PlayerRace(); self.current.level=AB_PlayerLevel()
  self.current.updated=time(); self:RefreshUI()
  AB_Print("Imported "..found.." database items. "..missing.." equipped items are not in the current data pack.")
end

local function AB_CleanName(name)
  name = string.gsub(tostring(name or ""), "^%s+", "")
  name = string.gsub(name, "%s+$", "")
  return name
end
AshenBuilds.CleanBuildName = AB_CleanName

-- current.savedName remembers which saved build the planner is editing, so saving under a
-- new name renames that build instead of creating a copy. saveAs=true always makes a copy.
function AshenBuilds:SaveBuild(name, saveAs)
  name = AB_CleanName(name or self.current.name); if name == "" then name = "Unnamed Build" end
  local old = self.current.savedName
  if old and AshenBuildsDB.builds[old] and old ~= name and not saveAs then
    if not self:RenameBuild(old, name) then return false end
  elseif AshenBuildsDB.builds[name] and name ~= old then
    AB_Print("A saved build named |cffffffff"..name.."|r already exists. Load it or delete it first, or pick another name.")
    return false
  end
  self.current.name=name; self.current.savedName=name; self.current.updated=time()
  local copy=self:DeepCopy(self.current); copy.savedName=nil
  AshenBuildsDB.builds[name]=copy; AshenBuildsDB.current=self.current
  AB_Print("Saved |cffffffff"..name.."|r."); self:RefreshBuildList(); self:RefreshUI()
  if self.OnBuildSaved then self:OnBuildSaved(name) end
  return true
end

-- Writes the planner back into the saved build it came from, so edits to a saved
-- build (gear, enchants, talents, class...) survive switching builds or logging
-- out. Renaming and republishing still wait for an explicit Save.
function AshenBuilds:AutoSave()
  local name = self.current and self.current.savedName
  if not name or not AshenBuildsDB.builds[name] then return end
  local copy = self:DeepCopy(self.current); copy.savedName = nil; copy.name = name
  AshenBuildsDB.builds[name] = copy
end

-- True when a build has anything worth keeping.
function AshenBuilds:BuildHasContent(build)
  if next(build.items or {}) or next(build.enchants or {}) then return true end
  return next((build.talents and build.talents.points) or {}) and true or false
end

-- Runs fn now, or after a confirmation when it would throw away a never-saved build.
function AshenBuilds:ConfirmDiscard(what, fn)
  if self.current.savedName or not self:BuildHasContent(self.current) or not self.ShowPrompt then fn(); return true end
  self:ShowPrompt({title="UNSAVED BUILD", text="Your current build hasn't been saved.\nDiscard it and load |cffffffff"..what.."|r?", accept="Discard", onAccept=fn})
  return false
end

function AshenBuilds:RenameBuild(old, new)
  new = AB_CleanName(new)
  local build = AshenBuildsDB.builds[old]
  if not build then return false end
  if new == "" then AB_Print("Build names can't be empty.") return false end
  if new == old then return true end
  if AshenBuildsDB.builds[new] then AB_Print("A saved build named |cffffffff"..new.."|r already exists.") return false end
  local wasPublished = self.IsBuildPublished and self:IsBuildPublished(old)
  if wasPublished then self:UnpublishBuild(old) end
  AshenBuildsDB.builds[old] = nil
  build.name = new; build.updated = time()
  AshenBuildsDB.builds[new] = build
  if self.current.savedName == old then self.current.savedName = new; self.current.name = new end
  if wasPublished then self:PublishBuild(new) end
  AB_Print("Renamed |cffffffff"..old.."|r to |cffffffff"..new.."|r.")
  self:RefreshBuildList(); self:RefreshUI()
  return true
end

function AshenBuilds:LoadBuild(name)
  local build=AshenBuildsDB.builds[name]; if not build then return end
  self.current=self:DeepCopy(build); self.current.name=name; self.current.savedName=name; self:MigrateBuild(self.current); AshenBuildsDB.current=self.current; self:RefreshUI(); AB_Print("Loaded |cffffffff"..name.."|r.")
end
function AshenBuilds:DeleteBuild(name)
  if not AshenBuildsDB.builds[name] then return end
  if self.OnBuildDeleted then self:OnBuildDeleted(name) end
  AshenBuildsDB.builds[name]=nil; if self.selectedBuild==name then self.selectedBuild=nil end
  if self.current.savedName==name then self.current.savedName=nil end
  self:RefreshBuildList(); AB_Print("Deleted |cffffffff"..name.."|r.")
end
function AshenBuilds:DeepCopy(value)
  if type(value)~="table" then return value end
  local result={},k,v; for k,v in pairs(value) do result[self:DeepCopy(k)]=self:DeepCopy(v) end; return result
end

local AB_CHARS="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"
local function Enc(n) n=tonumber(n) or 0; if n==0 then return "0" end; local out=""; while n>0 do local r=math.mod(n,64); out=string.sub(AB_CHARS,r+1,r+1)..out; n=math.floor(n/64) end; return out end
local function Dec(s) local n=0; for i=1,string.len(s) do local p=string.find(AB_CHARS,string.sub(s,i,i),1,true); if not p then return nil end; n=n*64+(p-1) end; return n end

AshenBuilds.EncodeNumber=Enc
AshenBuilds.DecodeNumber=Dec

function AshenBuilds:ExportBuild(build)
  build=build or self.current
  local parts={"AB2",Enc(AB_IndexOf(self.CLASSES,build.class)),Enc(AB_IndexOf(self.RACES,build.race)),Enc(build.level),Enc(AB_IndexOf(self.SPECS[build.class],build.spec))}
  local i,slot
  for i=1,table.getn(self.SLOTS) do slot=self.SLOTS[i]; table.insert(parts,Enc(build.items[slot] or 0)); table.insert(parts,Enc((build.enchants and build.enchants[slot]) or 0)) end
  return table.concat(parts,".")
end

function AshenBuilds:ImportBuild(code)
  if not code then AB_Print("Invalid build code.") return false end
  if string.sub(code,1,4)=="AB1." then return self:ImportLegacyBuild(code) end
  local build,err=self:DecodeBuild(code)
  if not build then AB_Print(err) return false end
  self.current=build; AshenBuildsDB.current=build; self:RefreshUI(); AB_Print("Build imported."); return true
end

-- Parses an AB2 code into a build table without touching the planner.
-- Returns nil plus a message when the code is malformed.
function AshenBuilds:DecodeBuild(code)
  if type(code)~="string" or string.sub(code,1,4)~="AB2." then return nil,"Invalid build code." end
  local tokens={}; for token in string.gfind(code,"[^%.]+") do table.insert(tokens,token) end
  local legacy17={"HEAD","NECK","SHOULDER","BACK","CHEST","WRIST","HANDS","WAIST","LEGS","FEET","FINGER1","FINGER2","TRINKET1","TRINKET2","MAINHAND","OFFHAND","RANGED"}
  local newCount=5+(table.getn(self.SLOTS)*2)
  local legacyCount=5+(table.getn(legacy17)*2)
  local slots=self.SLOTS
  if table.getn(tokens)==legacyCount then slots=legacy17
  elseif table.getn(tokens)~=newCount then return nil,"Incomplete build code." end
  local build=AB_NewBuild("Imported Build")
  build.class=self.CLASSES[Dec(tokens[2]) or 1] or "Warrior"; build.race=self.RACES[Dec(tokens[3]) or 1] or "Human"; build.level=AB_ValidLevel(Dec(tokens[4]) or 60)
  build.spec=(self.SPECS[build.class] or {"Custom"})[Dec(tokens[5]) or 1] or "Custom"
  local i,id,enchantID,pos=1,nil,nil,6
  for i=1,table.getn(slots) do id=Dec(tokens[pos]); enchantID=Dec(tokens[pos+1]); if id and self:GetItem(id) then build.items[slots[i]]=id end; if enchantID and enchantID>0 and AshenBuildsEnchants[enchantID] then build.enchants[slots[i]]=enchantID end; pos=pos+2 end
  return build
end

function AshenBuilds:ImportLegacyBuild(code)
  local tokens={}; for token in string.gfind(code,"[^%.]+") do table.insert(tokens,token) end
  local legacy17={"HEAD","NECK","SHOULDER","BACK","CHEST","WRIST","HANDS","WAIST","LEGS","FEET","FINGER1","FINGER2","TRINKET1","TRINKET2","MAINHAND","OFFHAND","RANGED"}
  local newCount=table.getn(self.SLOTS)+1
  local legacyCount=table.getn(legacy17)+1
  local slots=self.SLOTS
  if table.getn(tokens)==legacyCount then slots=legacy17
  elseif table.getn(tokens)~=newCount then AB_Print("Incomplete legacy build code.") return false end
  local build=AB_NewBuild("Imported Build")
  local i,id; for i=1,table.getn(slots) do id=Dec(tokens[i+1]); if id and id>0 and self:GetItem(id) then build.items[slots[i]]=id end end
  self.current=build; AshenBuildsDB.current=build; self:RefreshUI(); AB_Print("Legacy build imported."); return true
end


-- Universal stat engine. Mirrors how the game server (vmangos) builds the numbers that
-- BetterCharacterStats reads back from the client:
--   base stats and base health/mana come from the real per class/race/level tables,
--   health = base health + first 20 stamina at 1 HP each + every further point at 10 HP,
--   mana   = base mana + first 20 intellect at 1 mana each + every further point at 15 mana,
--   crit/dodge per agility are interpolated between the level 1 and level 60 class rates.
local AB=AshenBuilds
local RACE_ORDER={"Human","Orc","Dwarf","NightElf","Undead","Tauren","Gnome","Troll"}
local STAT_KEYS={"str","agi","sta","int","spi"}

local function StatData() return AshenBuildsBaseStats or {} end

local function NormalizeClassName(value)
  local lower=string.lower(tostring(value or "Warrior"))
  local i
  for i=1,table.getn(AB.CLASSES) do if string.lower(AB.CLASSES[i])==lower then return AB.CLASSES[i] end end
  return "Warrior"
end

local function NormalizeRaceKey(value)
  local v=string.gsub(tostring(value or "Human"),"%s+","")
  if v=="Nightelf" then return "NightElf" end
  if v=="Highelf" then return "HighElf" end
  if v=="Scourge" then return "Undead" end
  return v
end
AB.NormalizeRaceKey=NormalizeRaceKey

local function LevelRate(pair,level)
  if not pair then return 20 end
  return pair[1]*(60-level)/59+pair[2]*(level-1)/59
end

local function HealthFromStamina(sta) if sta<20 then return sta end return 20+(sta-20)*10 end
local function ManaFromIntellect(int) if int<20 then return int end return 20+(int-20)*15 end

function AB:GetBaseProfile(build)
  build=build or self.current or {}
  local data=StatData()
  local className=NormalizeClassName(build.class)
  local raceKey=NormalizeRaceKey(build.race)
  local level=self.ValidLevel(build.level)
  local out={className=className,raceKey=raceKey,level=level}
  local classRows=(data.levelStats and data.levelStats[className]) or {}
  local row=classRows[raceKey]
  local offsets=data.raceOffsets or {}
  local adjust={0,0,0,0,0}
  local i,k
  if not row then
    -- Turtle-only class/race combinations: borrow another race's row for this class and
    -- shift it by the difference in racial stats.
    for i=1,table.getn(RACE_ORDER) do
      if classRows[RACE_ORDER[i]] then
        row=classRows[RACE_ORDER[i]]
        local want=offsets[raceKey] or {0,0,0,0,0}; local have=offsets[RACE_ORDER[i]] or {0,0,0,0,0}
        for k=1,5 do adjust[k]=(want[k] or 0)-(have[k] or 0) end
        break
      end
    end
  end
  local at=(level-1)*5
  for i=1,5 do out[STAT_KEYS[i]]=((row and row[at+i]) or 0)+adjust[i] end
  local pools=data.classLevel and data.classLevel[className]
  out.health=(pools and pools[(level-1)*2+1]) or 0
  out.mana=(pools and pools[(level-1)*2+2]) or 0
  return out
end

function AB:GetWeaponInfo(build,slot)
  local item=self:GetItem(build.items[slot] or 0)
  if not item then return nil end
  local wt=item.weaponType
  if item.twoHand and wt then wt="TwoHand"..wt end
  return {name=item.n,type=wt or (item.shield and "Shield" or "Unknown")}
end

local SKILL_KEYS={Sword="swordSkill",TwoHandSword="twoHandSwordSkill",Axe="axeSkill",TwoHandAxe="twoHandAxeSkill",Dagger="daggerSkill",Mace="maceSkill",TwoHandMace="twoHandMaceSkill",Fist="fistSkill",Polearm="polearmSkill",Bow="bowSkill",Gun="gunSkill",Crossbow="crossbowSkill",Thrown="thrownSkill"}
-- Talents such as Sword Specialization name the weapon family, not the one/two-hand split.
local SKILL_FAMILY={TwoHandSword="swordSkill",TwoHandAxe="axeSkill",TwoHandMace="maceSkill"}

function AB:GetWeaponSkill(build,slot,gear,talents)
  local w=self:GetWeaponInfo(build,slot)
  if not w or w.type=="Shield" or w.type=="Unknown" then return nil end
  local level=self.ValidLevel(build.level)
  local base=level*5
  local racial=((StatData().racialWeaponSkill or {})[NormalizeRaceKey(build.race)] or {})[w.type] or 0
  local gearBonus=gear[SKILL_KEYS[w.type] or ""] or 0
  local talent=0
  if talents then
    talent=talents[SKILL_FAMILY[w.type] or SKILL_KEYS[w.type] or ""] or 0
    if string.find(w.type,"TwoHand",1,true) then talent=talent+(talents.twoHandSkill or 0) end
  end
  return {type=w.type,base=base,racial=racial,gear=gearBonus,talent=talent,total=base+racial+gearBonus+talent}
end

function AB:GetClassAttackPower(class,level,str,agi)
  if class=="Warrior" or class=="Paladin" then return (3*level)+(2*str)-20
  elseif class=="Rogue" or class=="Hunter" then return (2*level)+str+agi-20
  elseif class=="Shaman" then return (2*level)+(2*str)-20
  elseif class=="Druid" then return (2*str)-20
  else return str-10 end
end

function AB:GetClassRangedAttackPower(class,level,agi)
  if class=="Hunter" then return (2*level)+(2*agi)-10 end
  if class=="Rogue" or class=="Warrior" then return level+agi-10 end
  return agi-10
end

-- Racial passives that change the character sheet.
local RACIALS={Human={spiPct=5}, Gnome={intPct=5}, Tauren={healthPct=5}, NightElf={dodge=1}}

local function Pct(value,pct) return value*(1+(pct or 0)/100) end

function AB:GetDerivedStats(build)
  build=build or self.current
  local data=StatData()
  local gear=self:GetGearTotals(build)
  local base=self:GetBaseProfile(build)
  local m=(self.GetTalentModifiers and self:GetTalentModifiers(build)) or {}
  local className=base.className
  local level=base.level
  local racial=RACIALS[base.raceKey] or {}
  -- Form-only talents (Sharpened Claws, Moonkin Form...) only count for the matching spec.
  local feral=(className=="Druid" and build.spec=="Feral")
  local out={gear=gear,base=base,talentModifiers=m,warnings={}}

  local function Primary(key)
    local v=(base[key] or 0)+(gear[key] or 0)
    return math.floor(Pct(Pct(v,m[key.."Pct"]),racial[key.."Pct"])+0.5)
  end
  out.str=Primary("str"); out.agi=Primary("agi"); out.sta=Primary("sta"); out.int=Primary("int"); out.spi=Primary("spi")

  out.health=math.floor(Pct(Pct(base.health+HealthFromStamina(out.sta)+(gear.health or 0),m.healthPct),racial.healthPct))
  out.mana=0
  if base.mana>0 then out.mana=math.floor(Pct(base.mana+ManaFromIntellect(out.int)+(gear.mana or 0),m.manaPct)) end

  -- Talents such as Toughness scale armor from items; each point of agility adds 2 armor.
  local itemArmor=(gear.armor or 0)+(gear.bonusArmor or 0)
  if className=="Druid" and build.spec=="Balance" and m.moonkinArmorPct then itemArmor=Pct(itemArmor,m.moonkinArmorPct) end
  out.armor=math.floor(Pct(itemArmor,m.armorPct)+out.agi*2)

  out.attackPower=self:GetClassAttackPower(className,level,out.str,out.agi)+(gear.ap or 0)
  if feral then out.attackPower=Pct(out.attackPower+(gear.feralAp or 0),m.feralAPPct) end
  out.attackPower=math.floor(out.attackPower)
  out.rangedAttackPower=math.floor(self:GetClassRangedAttackPower(className,level,out.agi)+(gear.ap or 0)+(gear.rap or 0))

  out.mainSkill=self:GetWeaponSkill(build,"MAINHAND",gear,m)
  out.offSkill=self:GetWeaponSkill(build,"OFFHAND",gear,m)
  out.rangedSkill=self:GetWeaponSkill(build,"RANGED",gear,m)
  local maxSkill=level*5
  local function SkillCrit(skill) if not skill then return 0 end return (skill.total-maxSkill)*0.04 end

  local agiCrit=out.agi/LevelRate(data.critPerAgi and data.critPerAgi[className],level)
  local baseCrit=(data.baseCrit and data.baseCrit[className]) or 0
  out.meleeCrit=baseCrit+agiCrit+(gear.crit or 0)+(m.meleeCrit or 0)+SkillCrit(out.mainSkill)
  if feral then out.meleeCrit=out.meleeCrit+(m.feralCrit or 0) end
  out.rangedCrit=baseCrit+agiCrit+(gear.crit or 0)+(gear.rangedCrit or 0)+(m.rangedCrit or 0)+SkillCrit(out.rangedSkill)
  if out.meleeCrit<0 then out.meleeCrit=0 end
  if out.rangedCrit<0 then out.rangedCrit=0 end

  local sc=data.spellCrit and data.spellCrit[className]
  out.spellCrit=(gear.spellCrit or 0)+(m.spellCrit or 0)
  if sc then out.spellCrit=out.spellCrit+sc[1]+out.int/(sc[2]+sc[3]*level) end

  out.hit=(gear.hit or 0)+(m.hit or 0)
  out.rangedHit=out.hit+(gear.rangedHit or 0)+(m.rangedHit or 0)
  out.spellHit=(gear.spellHit or 0)+(m.spellHit or 0)

  -- Defense above the level cap adds 0.04% dodge, parry and block per point.
  out.defense=maxSkill+(gear.defense or 0)+(m.defense or 0)
  local defBonus=(out.defense-maxSkill)*0.04
  out.dodge=baseCrit+out.agi/LevelRate(data.dodgePerAgi and data.dodgePerAgi[className],level)+defBonus+(gear.dodge or 0)+(m.dodge or 0)+(racial.dodge or 0)
  if feral then out.dodge=out.dodge+(m.feralDodge or 0) end
  if out.dodge<0 then out.dodge=0 end
  out.parry=(gear.parry or 0)+(m.parry or 0)
  if data.canParry and data.canParry[className] then out.parry=out.parry+5+defBonus end
  local shield=self:GetItem(build.items.OFFHAND or 0)
  out.block=0; out.blockValue=0
  if shield and shield.shield and data.canBlock and data.canBlock[className] then
    out.block=5+defBonus+(gear.block or 0)+(m.block or 0)
    out.blockValue=math.floor(Pct((gear.blockValue or 0)+out.str/20-1,m.blockValuePct))
    if out.blockValue<0 then out.blockValue=0 end
  end

  -- Item "healing" already includes +damage and healing, so the talent bonuses add to both.
  local spiritBonus=out.spi*((m.spiritToSpellPct or 0)/100); local intBonus=out.int*((m.intToSpellPct or 0)/100)
  out.spellPower=math.floor(Pct(gear.spellPower or 0,m.spellPowerPct)+spiritBonus+intBonus)
  out.healing=math.floor((gear.healing or 0)+spiritBonus+intBonus)
  out.arcanePower=out.spellPower+(gear.arcanePower or 0); out.firePower=out.spellPower+(gear.firePower or 0)
  out.frostPower=out.spellPower+(gear.frostPower or 0); out.naturePower=out.spellPower+(gear.naturePower or 0)
  out.shadowPower=out.spellPower+(gear.shadowPower or 0); out.holyPower=out.spellPower+(gear.holyPower or 0)

  out.mp5=gear.mp5 or 0
  out.spiritRegen=0
  local regen=data.spiritRegen and data.spiritRegen[className]
  if regen and out.mana>0 then out.spiritRegen=(out.spi/regen[1]+regen[2])*2.5 end
  out.hp5=gear.hp5 or 0; out.haste=(gear.haste or 0)+(m.haste or 0); out.armorPen=gear.armorPen or 0; out.spellPen=gear.spellPen or 0
  out.resistances={fire=gear.fireRes or 0,frost=gear.frostRes or 0,nature=gear.natureRes or 0,shadow=gear.shadowRes or 0,arcane=gear.arcaneRes or 0}

  -- Where each total comes from, for the stat tooltips: {label, value, isPercent}.
  -- Lines worth 0 are dropped so every tooltip only lists real contributions.
  local ex={}
  local function Explain(key,lines)
    local kept={}; local i
    for i=1,table.getn(lines) do if lines[i][2] and lines[i][2]~=0 then table.insert(kept,lines[i]) end end
    ex[key]=kept
  end
  local function PrimaryLines(key)
    local lines={{"Base ("..base.raceKey.." "..className..")",base[key]},{"Gear and enchants",gear[key] or 0}}
    if m[key.."Pct"] then table.insert(lines,{"Talents +"..m[key.."Pct"].."%",out[key]-math.floor(Pct((base[key] or 0)+(gear[key] or 0),racial[key.."Pct"])+0.5)}) end
    if racial[key.."Pct"] then table.insert(lines,{"Racial +"..racial[key.."Pct"].."%",out[key]-math.floor(Pct((base[key] or 0)+(gear[key] or 0),m[key.."Pct"])+0.5)}) end
    Explain(key,lines)
  end
  PrimaryLines("str"); PrimaryLines("agi"); PrimaryLines("sta"); PrimaryLines("int"); PrimaryLines("spi")
  local hpBefore=base.health+HealthFromStamina(out.sta)+(gear.health or 0)
  Explain("health",{{"Base health (level "..level..")",base.health},{"Stamina "..out.sta.." (1 each for 20, then 10)",HealthFromStamina(out.sta)},{"Gear and enchants",gear.health or 0},
    {"Talents and racials",out.health-hpBefore}})
  if out.mana>0 then Explain("mana",{{"Base mana (level "..level..")",base.mana},{"Intellect "..out.int.." (1 each for 20, then 15)",ManaFromIntellect(out.int)},{"Gear and enchants",gear.mana or 0},
    {"Talents",out.mana-(base.mana+ManaFromIntellect(out.int)+(gear.mana or 0))}}) end
  Explain("armor",{{"Items and enchants",itemArmor},{"Talents",math.floor(Pct(itemArmor,m.armorPct))-math.floor(itemArmor)},{"Agility x2",out.agi*2}})
  local classAP=self:GetClassAttackPower(className,level,out.str,out.agi)
  Explain("attackPower",{{"Level, Strength and Agility ("..className..")",classAP},{"Gear and enchants",gear.ap or 0},{"Feral bonuses",out.attackPower-classAP-(gear.ap or 0)}})
  local classRAP=self:GetClassRangedAttackPower(className,level,out.agi)
  Explain("rangedAttackPower",{{"Level and Agility ("..className..")",classRAP},{"Gear and enchants",(gear.ap or 0)+(gear.rap or 0)}})
  Explain("meleeCrit",{{"Class base",baseCrit,true},{"Agility "..out.agi,agiCrit,true},{"Gear and enchants",gear.crit or 0,true},{"Talents",(m.meleeCrit or 0)+(feral and m.feralCrit or 0),true},{"Weapon skill",SkillCrit(out.mainSkill),true}})
  Explain("rangedCrit",{{"Class base",baseCrit,true},{"Agility "..out.agi,agiCrit,true},{"Gear and enchants",(gear.crit or 0)+(gear.rangedCrit or 0),true},{"Talents",m.rangedCrit or 0,true},{"Weapon skill",SkillCrit(out.rangedSkill),true}})
  Explain("hit",{{"Gear and enchants",gear.hit or 0,true},{"Talents",m.hit or 0,true}})
  Explain("rangedHit",{{"Gear and enchants",(gear.hit or 0)+(gear.rangedHit or 0),true},{"Talents",(m.hit or 0)+(m.rangedHit or 0),true}})
  if sc then Explain("spellCrit",{{"Class base",sc[1],true},{"Intellect "..out.int,out.int/(sc[2]+sc[3]*level),true},{"Gear and enchants",gear.spellCrit or 0,true},{"Talents",m.spellCrit or 0,true}})
  else Explain("spellCrit",{{"Gear and enchants",gear.spellCrit or 0,true},{"Talents",m.spellCrit or 0,true}}) end
  Explain("spellHit",{{"Gear and enchants",gear.spellHit or 0,true},{"Talents",m.spellHit or 0,true}})
  Explain("spellPower",{{"Gear and enchants",gear.spellPower or 0},{"Talents",out.spellPower-(gear.spellPower or 0)}})
  Explain("healing",{{"Gear and enchants (includes +damage and healing)",gear.healing or 0},{"Talents",out.healing-(gear.healing or 0)}})
  Explain("defense",{{"Base (level "..level.." x5)",maxSkill},{"Gear and enchants",gear.defense or 0},{"Talents",m.defense or 0}})
  Explain("dodge",{{"Class base",baseCrit,true},{"Agility "..out.agi,out.agi/LevelRate(data.dodgePerAgi and data.dodgePerAgi[className],level),true},{"Defense above cap",defBonus,true},
    {"Gear and enchants",gear.dodge or 0,true},{"Talents",(m.dodge or 0)+(feral and m.feralDodge or 0),true},{"Racial",racial.dodge or 0,true}})
  if data.canParry and data.canParry[className] then Explain("parry",{{"Base",5,true},{"Defense above cap",defBonus,true},{"Gear and enchants",gear.parry or 0,true},{"Talents",m.parry or 0,true}})
  else Explain("parry",{{"Gear and enchants",gear.parry or 0,true},{"Talents",m.parry or 0,true}}); out.parryNote=className.."s can't parry" end
  if out.block>0 then
    Explain("block",{{"Base (shield)",5,true},{"Defense above cap",defBonus,true},{"Gear and enchants",gear.block or 0,true},{"Talents",m.block or 0,true}})
    Explain("blockValue",{{"Shield and equip effects",gear.blockValue or 0},{"Strength / 20 - 1",out.str/20-1},{"Talents",out.blockValue-math.floor((gear.blockValue or 0)+out.str/20-1)}})
  else
    out.blockNote=(data.canBlock and data.canBlock[className]) and "Equip a shield to block" or (className.."s can't block")
  end
  if regen then Explain("spiritRegen",{{"Spirit "..out.spi.." / "..regen[1].." + "..regen[2].." every 2 sec, x2.5",out.spiritRegen}}) end
  out.explain=ex
  return out
end


-- Startup is deliberately registered after every calculation method exists.
local eventFrame=CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:SetScript("OnEvent",function()
  local AB=AshenBuilds
  if event=="PLAYER_ENTERING_WORLD" or event=="PLAYER_LEVEL_UP" then
    -- Unit level isn't reliable while addons load, so an untouched build picks up
    -- the character's class, race and level once in the world (and on level up).
    local b=AB.current
    if b and AB_IsUntouched(b) then
      local class=AB_PlayerClass()
      if AB.SPECS[class] and b.class~=class then b.class=class; b.spec=AB.SPECS[class][1] end
      b.race=AB_PlayerRace()
      b.level=AB_ValidLevel((event=="PLAYER_LEVEL_UP" and arg1) or UnitLevel("player"))
      if AB.RefreshUI then AB:RefreshUI() end
    end
  elseif event=="PLAYER_LOGOUT" then
    -- Loading a saved build or starting a new one replaces AshenBuildsDB.current.
    if AshenBuildsDB and AshenBuildsDB.currentByChar then AshenBuildsDB.currentByChar[AB_CharKey()]=AshenBuildsDB.current end
  elseif event=="ADDON_LOADED" and arg1=="AshenBuilds" then
    AshenBuilds:InitializeDB(); AshenBuilds:CreateUI(); AshenBuilds:SetupTabs()
    SLASH_ASHENBUILDS1="/ab"; SLASH_ASHENBUILDS2="/ashenbuilds"
    SlashCmdList["ASHENBUILDS"]=function(msg)
      msg=string.lower(msg or "")
      local split=string.find(msg," ",1,true)
      local cmd=split and string.sub(msg,1,split-1) or msg
      local arg=split and string.sub(msg,split+1) or ""
      if cmd=="reset" then AshenBuilds.current=AB_NewBuild("New Build"); AshenBuildsDB.current=AshenBuilds.current; AshenBuilds:RefreshUI()
      elseif cmd=="importgear" then AshenBuilds:ImportEquipped()
      elseif cmd=="minimap" then AshenBuilds:ToggleMinimapButton()
      elseif cmd=="model" then
        if string.sub(arg,1,5)=="probe" then local w=string.gsub(string.sub(arg,6),"^%s+",""); AshenBuilds:ProbeDressingRoom(w~="" and w or nil)
        elseif arg=="undress" then
          AshenBuildsDB.settings.modelKeepGear=not AshenBuildsDB.settings.modelKeepGear
          AB_Print(AshenBuildsDB.settings.modelKeepGear and "Model preview now keeps your own gear in slots the plan leaves empty (one-hand weapons may land in the off hand)." or "Model preview now strips your own gear before putting the planned gear on.")
          if AshenBuilds.previewArea then AshenBuilds.previewArea.unitLoaded=false end
          AshenBuilds:RefreshModel()
        else
          local a=AshenBuilds.previewArea
          AB_Print("Model preview: "..((a and a:IsShown()) and "open" or "closed")..", using "..(AshenBuilds.borrowedModel and "the Dressing Room model" or "its own model")..", items put on last time: "..((a and a.worn) or 0)..((a and a.lastLink) and (" (e.g. "..a.lastLink..")") or "")..".")
        end
      elseif cmd=="sync" then
        if arg=="off" then AshenBuilds:SetChannelSync(false)
        elseif arg=="on" then AshenBuilds:SetChannelSync(true)
        elseif arg=="status" then AshenBuilds:PrintSyncStatus()
        else AB_Print("Community sync over the realm channel is "..(AshenBuilds:IsChannelSyncOn() and "on" or "off")..". /ab sync off uses guild and party only; /ab sync status shows who you can reach.") end
      elseif cmd=="unhide" then
        local hidden=AshenBuilds:HiddenAuthors(); local key=string.lower(arg or "")
        if hidden[key] then local n=hidden[key]; AshenBuilds:HideAuthor(n,false); AB_Print("Showing builds from "..n.." again.")
        else AB_Print("Usage: /ab unhide <player>. Hidden players: "..(function() local t,k,v={} for k,v in pairs(hidden) do table.insert(t,v) end return table.getn(t)>0 and table.concat(t,", ") or "none" end)()) end
      elseif cmd=="community" then if not AshenBuilds.frame:IsShown() then AshenBuilds:ToggleUI() end; AshenBuilds:OpenCommunity()
      elseif cmd=="debugset" then
        local itemId=tonumber(arg)
        if not itemId then
          AB_Print("Usage: /ab debugset <itemID>")
        else
          local item=AshenBuilds:GetItem(itemId)
          local raw=AshenBuilds:GetRawItem(itemId)
          local rawSet=raw and tonumber(raw[10]) or 0
          local reverseSet=(AshenBuilds.ItemToSet and AshenBuilds.ItemToSet[itemId]) or (AshenDB and AshenDB.ItemToSet and AshenDB.ItemToSet[itemId]) or 0
          local setId=AshenBuilds:GetItemSetId(itemId,item) or 0
          local set=AshenBuilds:GetItemSet(setId)
          local members=set and table.getn(set.items or {}) or 0
          local bonuses=set and table.getn(set.bonuses or {}) or 0
          AB_Print("Set debug: item="..itemId.." ("..((item and item.n) or "not found").."), raw="..rawSet..", reverse="..reverseSet..", resolved="..setId..", set="..((set and set.name) or "missing")..", members="..members..", bonuses="..bonuses..".")
        end
      elseif cmd=="debug" then
        local itemCount=(AshenDB and AshenDB.GetItemCount and AshenDB:GetItemCount()) or 0
        local setCount=(AshenBuilds.SetCatalogMeta and AshenBuilds.SetCatalogMeta.setCount) or (AshenDB and AshenDB.GetSetCount and AshenDB:GetSetCount()) or 0
        local memberCount=(AshenBuilds.SetCatalogMeta and AshenBuilds.SetCatalogMeta.memberCount) or 0
        local bonusCount=(AshenBuilds.SetCatalogMeta and AshenBuilds.SetCatalogMeta.bonusCount) or 0
        local sourceCount=(AshenDB and AshenDB.GetSourceItemCount and AshenDB:GetSourceItemCount()) or 0
        AB_Print("Debug: level="..AshenBuilds:GetBuildLevel()..", items="..itemCount..", sets="..setCount..", set members="..memberCount..", set bonuses="..bonusCount..", sourced items="..sourceCount..".")
      else AshenBuilds:ToggleUI() end
    end
    local setCount=(AshenDB and AshenDB.GetSetCount and AshenDB:GetSetCount()) or 0
    AB_Print("v"..AshenBuilds.VERSION.." loaded - "..setCount.." item sets ready. Type |cffffffff/ab|r to open.")
  end
end)

