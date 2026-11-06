-- Planner defaults to the character; item database shows only what that character can use.
local AB = AshenBuilds

check("an alt of another class starts fresh", AB.current.class == "Mage" and AB.current.race == "Gnome" and AB.current.name ~= "Old")
LEVEL = 23; FireEvent("PLAYER_ENTERING_WORLD")
check("level is picked up once in the world", AB.current.level == 23)
FireEvent("PLAYER_LEVEL_UP", 24)
check("level follows a level up", AB.current.level == 24)
AB:SetLevel(60)
FireEvent("PLAYER_LEVEL_UP", 25)
check("a level set by hand is kept", AB.current.level == 60)
AB:SetLevel(24)
FireEvent("PLAYER_LOGOUT")
check("the planner build is saved for this character", AshenBuildsDB.currentByChar["Tester-Realm"] == AB.current)
check("the old shared build is left for its own class", AshenBuildsDB.currentByChar["Tester-Realm"].name ~= "Old" and not AshenBuildsDB.sharedCurrentClaimed)

local IDX = AB.ItemIndex
local function Q(f) f.slot = f.slot or "ALL"; return IDX:Query(f) end
local function All(list, fn) for _, p in ipairs(list) do if not fn(p) then return false end end return true end
local function Any(list, fn) for _, p in ipairs(list) do if fn(p) then return true end end return false end

-- A level 24 mage.
local mage = Q({class = "Mage", maxReq = 24, level = 24})
check("mage results are not empty", table.getn(mage) > 100)
check("no items above the build level", All(mage, function(p) return IDX.req[p] <= 24 and IDX.use[p] <= 24 end))
check("no leather, mail, plate or shields for a mage", All(mage, function(p) local a = IDX.armor[p]; return a ~= 2 and a ~= 3 and a ~= 4 and a ~= 6 end))
check("no weapons a mage can't use", All(mage, function(p) local w = IDX.wtype[p]; return w == "" or w == "Sword" or w == "Dagger" or w == "Staff" or w == "Wand" or w == "Weapon" or w == "Fishing Pole" end))
check("mages can't dual wield", not Any(Q({slot = "OFFHAND", class = "Mage", maxReq = 60, level = 60}), function(p) return IDX.slot[p] == "WEAPON" end))

-- Quest rewards count the quest's level.
local questGated
for p = 1, IDX.n do if IDX.use[p] > IDX.req[p] then questGated = p; break end end
check("some quest rewards need a higher level than the item says", questGated ~= nil)
if questGated then
  local lvl = IDX.use[questGated] - 1
  check("a quest reward is hidden below its quest level", not Any(Q({maxReq = lvl}), function(p) return p == questGated end))
  check("and shown at its quest level", Any(Q({maxReq = lvl + 1}), function(p) return p == questGated end))
end

-- Plate and mail come at 40.
check("no plate for a level 39 warrior", not Any(Q({class = "Warrior", maxReq = 39, level = 39}), function(p) return IDX.armor[p] == 4 end))
check("plate for a level 40 warrior", Any(Q({class = "Warrior", maxReq = 40, level = 40}), function(p) return IDX.armor[p] == 4 end))
check("mail for a level 40 hunter, not at 39", Any(Q({class = "Hunter", maxReq = 40, level = 40}), function(p) return IDX.armor[p] == 3 end)
  and not Any(Q({class = "Hunter", maxReq = 39, level = 39}), function(p) return IDX.armor[p] == 3 end))
check("unticking 'My class' shows every armor type", Any(Q({maxReq = 60}), function(p) return IDX.armor[p] == 4 end))

-- Armor type filter.
local leather = Q({armor = 2})
check("armor filter: leather only", table.getn(leather) > 50 and All(leather, function(p) return IDX.armor[p] == 2 end))
AB:OpenItemBrowser("ALL")
AB.itemFilter.armor = 4; AB.itemFilter.classOnly = false; AB.itemFilter.usable = false
AB:RefreshItemResults()
check("armor dropdown drives the item list", table.getn(AB.itemMatches) > 50 and All(AB.itemMatches, function(p) return IDX.armor[p] == 4 end))
AB.itemFilter.armor = 0; AB.itemFilter.classOnly = true; AB.itemFilter.usable = true
AB:RefreshItemResults()
check("default filters apply the character's rules", All(AB.itemMatches, function(p) return IDX.armor[p] ~= 4 and IDX.use[p] <= 24 end))
