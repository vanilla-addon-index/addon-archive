-- Mock WoW 1.12 client + scenario tests for ShardCap. Run with Lua 5.0.
local ADDON_FILE = arg[1] or "ShardCap.lua"
local fails, passes = 0, 0
local function check(cond, name)
	if cond then passes = passes + 1; print("  ok   " .. name)
	else fails = fails + 1; print("  FAIL " .. name) end
end

local now, bags, bagItem, cursor, combat, frames, chat, maxStack
local soulOK = {}
local function isSoulBagItem(id) return id == 22243 or id == 99999 end
local function fits(b, id) return not isSoulBagItem(bagItem[b]) or soulOK[id] end
local itemNames = { [6265] = "Soul Shard", [16265] = "Some Other Item", [6948] = "Hearthstone" }

local function reset(opts)
	opts = opts or {}
	now, cursor, combat, frames, chat = 0, nil, false, {}, {}
	maxStack = opts.maxStack or 3
	soulOK = { [6265] = true }
	if opts.reagentsOK ~= false then soulOK[16583] = true; soulOK[5565] = true end
	familyKnown = opts.familyKnown
	bags, bagItem = {}, {}
	for b = 0, 4 do bags[b] = { size = 0, slots = {} } end
	ShardCapDB, SHARDCAP_CAP_VALUE, SHARDCAP_SPAM = nil, nil, nil
	C_Container, C_Item, GetBagItem, CLASSIC_API_VERSION = nil, nil, nil, nil
	bank = nil
end
local function setBag(b, size, itemID) bags[b].size = size; bagItem[b] = itemID end
local function put(b, s, id, n) bags[b].slots[s] = { id = id, count = n or 1 } end

-- vanilla API
function GetTime() return now end
function GetContainerNumSlots(b) return bags[b] and bags[b].size or 0 end
function GetContainerItemLink(b, s)
	local it = bags[b].slots[s]; if not it then return nil end
	return "|cffffffff|Hitem:" .. it.id .. ":0:0:0|h[" .. (itemNames[it.id] or "?") .. "]|h|r"
end
function GetContainerItemInfo(b, s)
	local it = bags[b].slots[s]; if not it then return nil end
	return "tex", it.count, it.locked
end
function ContainerIDToInventoryID(b) return 19 + b end
function GetInventoryItemLink(u, inv)
	local id = bagItem[inv - 19]; if not id then return nil end
	return "|Hitem:" .. id .. ":0:0:0|h[bag]|h"
end
function GetItemInfo(id)
	id = tonumber(id)
	if id == 6265 then return "Soul Shard", "item:6265", 1, 0, "Reagent", "Reagent", maxStack end
	if id == 16583 then return "Demonic Figurine", "item:16583", 1, 0, "Reagent", "Reagent", 10 end
	if id == 5565 then return "Infernal Stone", "item:5565", 1, 0, "Reagent", "Reagent", 10 end
	if id == 22243 then return "Small Soul Pouch", "item:22243", 2, 0, "Container", "Soul Bag", 1 end
	if id == 99999 then return "Custom Soul Bag", "item:99999", 2, 0, "Container", "Soul Bag", 1 end
	return "Bag", "item:" .. id, 1, 0, "Container", "Bag", 1
end
function CursorHasItem() return cursor ~= nil end
function SpellIsTargeting() return false end
function PickupContainerItem(b, s)
	local it = bags[b].slots[s]
	if cursor then
		if not fits(b, cursor.id) then return end -- "That item doesn't go in that container."
		if it and it.id == cursor.id and it.count + cursor.count <= maxStack then
			it.count = it.count + cursor.count; cursor = nil
		elseif not it then
			bags[b].slots[s] = cursor; cursor = nil
		else
			bags[b].slots[s] = cursor; cursor = it
		end
	elseif it then
		bags[b].slots[s] = nil; cursor = it
	end
end
function SplitContainerItem(b, s, n)
	local it = bags[b].slots[s]
	if cursor or not it or n >= it.count then return end
	it.count = it.count - n; cursor = { id = it.id, count = n }
end
function DeleteCursorItem() cursor = nil end
function UnitAffectingCombat() return combat end
function IsAddOnLoaded() return false end
DEFAULT_CHAT_FRAME = { AddMessage = function(self, m) table.insert(chat, m) end }
SlashCmdList = {}
-- Minimal widget mock: enough of Frame/CheckButton/Slider/EditBox/FontString for Options.lua
local W = {}
local function call(w, script)
	local fn = w.scripts[script]
	if fn then local old = this; this = w; fn(); this = old end
end
function W:RegisterEvent(e) self.events[e] = true end
function W:SetScript(k, fn) self.scripts[k] = fn end
function W:Show() self.shown = true end
function W:Hide() self.shown = false end
function W:GetName() return self.name end
function W:SetText(t) self.text = t and tostring(t) or "" end
function W:GetText() return self.text end
function W:SetChecked(v) if v then self.checked = 1 else self.checked = nil end end
function W:GetChecked() return self.checked end
function W:Enable() self.enabled = true end
function W:Disable() self.enabled = false end
function W:SetMinMaxValues(lo, hi) self.lo, self.hi = lo, hi end
function W:GetValue() return self.value end
function W:SetValue(v)
	if self.lo and v < self.lo then v = self.lo end
	if self.hi and v > self.hi then v = self.hi end
	if v ~= self.value then self.value = v; call(self, "OnValueChanged") end
end
function W:SetFocus() self.focus = true; call(self, "OnEditFocusGained") end
function W:ClearFocus() if self.focus then self.focus = false; call(self, "OnEditFocusLost") end end
function W:CreateFontString() return newWidget("FontString") end
for _, m in ipairs({ "SetPoint", "SetWidth", "SetHeight", "SetJustifyH", "SetTextColor", "SetValueStep",
	"SetAutoFocus", "SetNumeric", "SetMaxLetters", "SetOwner" }) do W[m] = function() end end
local WMT = { __index = W }
function newWidget(kind, name)
	local w = setmetatable({ kind = kind, name = name, scripts = {}, events = {}, shown = true, text = "", value = 0, enabled = true }, WMT)
	if name then _G[name] = w end
	table.insert(allWidgets, w)
	return w
end
allWidgets = {}
function getglobal(n) return _G[n] end
function CreateFrame(kind, name, parent, template)
	local f = newWidget(kind, name)
	if name and template then
		for _, sub in ipairs({ "Text", "Low", "High" }) do newWidget("FontString", name .. sub) end
	end
	table.insert(frames, f)
	return f
end
GameTooltip = newWidget("GameTooltip")
NORMAL_FONT_COLOR = { r = 1, g = 0.82, b = 0 }
GRAY_FONT_COLOR = { r = 0.5, g = 0.5, b = 0.5 }

local F
local function fire(e, a1)
	if not F.events[e] then return end
	event, arg1 = e, a1
	this = F; F.scripts.OnEvent()
end
local function run(seconds)
	local stop = now + (seconds or 10)
	while now < stop do
		now = now + 0.05
		if F.shown and F.scripts.OnUpdate then this = F; F.scripts.OnUpdate() end
	end
end
local OPTIONS_FILE = string.gsub(ADDON_FILE, "ShardCap%.lua$", "Options.lua")
local categories, bank
local function load(classic, withOptions)
	categories = {}
	if withOptions then
		InterfaceOptions_AddCategory = function(p) p:Hide(); table.insert(categories, p) end
		InterfaceOptionsFrame_OpenToCategory = function(p) p:Show(); p.refresh(p); categories.opened = p end
	else
		InterfaceOptions_AddCategory, InterfaceOptionsFrame_OpenToCategory = nil, nil
	end
	if classic then
		CLASSIC_API_VERSION = 10000
		C_Container = {
			GetContainerItemInfo = function(b, s)
				local it = bags[b].slots[s]; if not it then return nil end
				return { itemID = it.id, stackCount = it.count, isLocked = it.locked and true or false }
			end,
			GetContainerNumFreeSlots = function(b)
				local id = bagItem[b]
				local t = (id == 22243 or id == 99999) and 4 or 0
				return 0, t
			end,
			SwapItems = function(sb, ss, db_, ds)
				local a, b2 = bags[sb].slots[ss], bags[db_].slots[ds]
				if (a and not fits(db_, a.id)) or (b2 and not fits(sb, b2.id)) then return true end -- server refuses silently
				bags[sb].slots[ss], bags[db_].slots[ds] = b2, a; return true
			end,
			MoveItem = function(sb, ss, db_, ds, n)
				local src, dst = bags[sb].slots[ss], bags[db_].slots[ds]
				if not src or n > src.count then return false end
				if dst and (dst.id ~= src.id or dst.count + n > maxStack) then return false end
				if dst then dst.count = dst.count + n else bags[db_].slots[ds] = { id = src.id, count = n } end
				src.count = src.count - n; if src.count == 0 then bags[sb].slots[ss] = nil end
				return true
			end,
		}
		C_Item = { GetItemMaxStackSizeByID = function(id) return maxStack end,
			GetItemFamily = function(id)
				if not familyKnown then return 0 end -- family not reported: fall back to heuristics
				return soulOK[id] and 4 or 0
			end }
	end
	if classic then
		C_Item.GetItemCount = function(id, includeBank)
			local t = 0
			for b = 0, 4 do for s = 1, bags[b].size do
				local it = bags[b].slots[s]; if it and it.id == id then t = t + it.count end
			end end
			if includeBank and bank then t = t + (bank[id] or 0) end
			return t
		end
	end
	dofile(ADDON_FILE)
	dofile(OPTIONS_FILE)
	F = frames[1]
	fire("ADDON_LOADED", "ShardCap")
	fire("PLAYER_ENTERING_WORLD")
end
local function count(onlyBag)
	local t = 0
	for b = 0, 4 do
		if not onlyBag or onlyBag == b then
			for s = 1, bags[b].size do
				local it = bags[b].slots[s]
				if it and it.id == 6265 then t = t + it.count end
			end
		end
	end
	return t
end
local function where(id)
	local t = {}
	for b = 0, 4 do for s = 1, bags[b].size do
		local it = bags[b].slots[s]; if it and it.id == id then table.insert(t, b) end
	end end
	return t
end
local function slotsUsed()
	local t = 0
	for b = 0, 4 do for s = 1, bags[b].size do
		local it = bags[b].slots[s]; if it and it.id == 6265 then t = t + 1 end
	end end
	return t
end

for _, classic in ipairs({ false, true }) do
	local tag = classic and "[ClassicAPI] " or "[vanilla] "
	print(tag)

	-- 1. WoW 1.18.1 Clients stacks of 3: trims to exactly the cap, backpack first
	reset(); setBag(0, 16); setBag(4, 12, 22243)
	put(0, 2, 6265, 3); put(4, 1, 6265, 3); put(4, 2, 6265, 3); put(4, 3, 6265, 2)
	load(classic); ShardCapDB.cap = 6; ShardCapDB.sort = false; fire("BAG_UPDATE"); fire("BAG_UPDATE_DELAYED"); run()
	check(count() == 6, tag .. "trim 11 -> 6 with stacks of 3 (got " .. count() .. ")")
	check(count(0) == 0, tag .. "deleted from backpack before soul bag")
	check(cursor == nil, tag .. "cursor left empty")

	-- 2. Exactness: 13 shards, cap 12 -> deletes exactly 1 (ShardCapPlus deleted a whole stack of 3)
	reset(); setBag(0, 16); setBag(4, 12, 22243)
	put(0, 1, 6265, 1); for s = 1, 4 do put(4, s, 6265, 3) end
	load(classic); ShardCapDB.cap = 12; fire("BAG_UPDATE"); fire("BAG_UPDATE_DELAYED"); run()
	check(count() == 12, tag .. "13 -> exactly 12 (got " .. count() .. ")")

	reset(); setBag(0, 16); setBag(4, 12, 22243)
	put(0, 1, 6265, 3); for s = 1, 4 do put(4, s, 6265, 3) end
	load(classic); ShardCapDB.cap = 13; ShardCapDB.sort = false; fire("BAG_UPDATE"); fire("BAG_UPDATE_DELAYED"); run()
	check(count() == 13 and count(0) == 1, tag .. "15 -> 13 splits the backpack stack (got " .. count() .. ")")

	-- 3. No false positives: item 16265 is never touched
	reset(); setBag(0, 16)
	put(0, 1, 16265, 1); put(0, 2, 6265, 1); put(0, 3, 6265, 1)
	load(classic); ShardCapDB.cap = 1; fire("BAG_UPDATE"); fire("BAG_UPDATE_DELAYED"); run()
	check(bags[0].slots[1] and bags[0].slots[1].id == 16265, tag .. "item 16265 kept")
	check(count() == 1, tag .. "shards trimmed to 1")

	-- 4. Merge partial stacks into the soul bag stack
	reset(); setBag(0, 16); setBag(4, 12, 22243)
	put(0, 5, 6265, 1); put(4, 1, 6265, 2); put(4, 2, 6265, 1)
	load(classic); ShardCapDB.cap = 20; fire("BAG_UPDATE"); fire("BAG_UPDATE_DELAYED"); run()
	check(count() == 4, tag .. "merge keeps all 4 shards")
	check(slotsUsed() == 2, tag .. "4 shards in 2 slots after merging (got " .. slotsUsed() .. ")")
	check(count(0) == 0, tag .. "backpack emptied into soul bag")

	-- 5. Blizzlike (no stacking): move shards into free soul bag slots
	reset({ maxStack = 1 }); setBag(0, 16); setBag(2, 16, 22243)
	put(0, 1, 6265); put(0, 2, 6265); put(2, 1, 6265)
	load(classic); ShardCapDB.cap = 20; fire("BAG_UPDATE"); fire("BAG_UPDATE_DELAYED"); run()
	check(count(2) == 3 and count(0) == 0, tag .. "shards moved into soul bag in bag 2")

	-- 6. Combat: nothing deleted in combat, trimmed on leaving it
	reset(); setBag(0, 16)
	for s = 1, 5 do put(0, s, 6265, 1) end
	load(classic); run(); ShardCapDB.cap = 2
	combat = true; fire("PLAYER_REGEN_DISABLED"); put(0, 6, 6265, 1); fire("BAG_UPDATE"); fire("BAG_UPDATE_DELAYED"); run()
	check(count() == 6, tag .. "no deletion during combat")
	combat = false; fire("PLAYER_REGEN_ENABLED"); run()
	check(count() == 2, tag .. "trimmed after combat (got " .. count() .. ")")

	-- 7. Manual /shardcap delete works in combat
	reset(); setBag(0, 16); for s = 1, 4 do put(0, s, 6265, 1) end
	load(classic); combat = true; fire("PLAYER_REGEN_DISABLED"); ShardCapDB.cap = 1
	SlashCmdList.SHARDCAP("delete"); run()
	check(count() == 1, tag .. "manual delete in combat")

	-- 8. Holding an item on the cursor blocks deletion
	reset(); setBag(0, 16); for s = 1, 4 do put(0, s, 6265, 1) end
	cursor = { id = 6948, count = 1 }
	load(classic); ShardCapDB.cap = 1; fire("BAG_UPDATE"); fire("BAG_UPDATE_DELAYED"); run(2)
	check(count() == 4 and cursor.id == 6948, tag .. "waits while the cursor holds an item")
	cursor = nil; run()
	check(count() == 1, tag .. "proceeds once the cursor is free")

	-- 9. Locked stack is skipped until unlocked
	reset(); setBag(0, 16); put(0, 1, 6265, 1); put(0, 2, 6265, 1)
	bags[0].slots[2].locked = true; bags[0].slots[1].locked = true
	load(classic); ShardCapDB.cap = 0; fire("BAG_UPDATE"); fire("BAG_UPDATE_DELAYED"); run(1)
	check(count() == 2, tag .. "locked stacks untouched")
	bags[0].slots[2].locked = nil; bags[0].slots[1].locked = nil; run()
	check(count() == 0, tag .. "deleted after unlock")

	-- 10. Reagents go into the soul bag when there's room beyond the shard reserve
	reset({ familyKnown = true }); setBag(0, 16); setBag(4, 12, 22243)
	put(0, 1, 16583, 2); put(0, 2, 5565, 7); put(4, 1, 6265, 3)
	load(classic); ShardCapDB.cap = 12; fire("BAG_UPDATE"); fire("BAG_UPDATE_DELAYED"); run()
	check(where(16583)[1] == 4 and where(5565)[1] == 4, tag .. "figurine and infernal stone moved to soul bag")
	check(bags[4].slots[12] ~= nil and bags[4].slots[11] ~= nil, tag .. "reagents fill soul bag from the end")
	check(count() == 3, tag .. "shards untouched by reagent moves")

	-- 11. Reserve: cap 12 / 3 per slot = 4 slots kept for shards
	reset({ familyKnown = true }); setBag(0, 16); setBag(4, 5, 22243)
	put(0, 1, 16583, 1); put(0, 2, 5565, 1); put(4, 1, 6265, 1)
	load(classic); ShardCapDB.cap = 12; fire("BAG_UPDATE"); fire("BAG_UPDATE_DELAYED"); run()
	local moved = 0
	if where(16583)[1] == 4 then moved = moved + 1 end
	if where(5565)[1] == 4 then moved = moved + 1 end
	check(moved == 1, tag .. "only 1 reagent moved into a 5-slot soul bag (4 kept for shards), got " .. moved)

	-- 12. Shards outside the soul bag get the free slots first
	reset({ familyKnown = true }); setBag(0, 16); setBag(4, 2, 22243)
	put(0, 1, 16583, 1); put(0, 2, 6265, 1); put(0, 3, 6265, 1)
	load(classic); ShardCapDB.cap = 6; ShardCapDB.sort = true; fire("BAG_UPDATE"); fire("BAG_UPDATE_DELAYED"); run()
	check(where(16583)[1] == 0, tag .. "reagent waits when shards need the space")

	-- 13. Server that doesn't allow reagents in soul bags: gives up, no endless retries
	reset({ reagentsOK = false }); setBag(0, 16); setBag(4, 12, 22243)
	put(0, 1, 16583, 1); put(0, 2, 5565, 1)
	load(classic); ShardCapDB.cap = 3; local before = table.getn(chat)
	fire("BAG_UPDATE"); fire("BAG_UPDATE_DELAYED"); run(20)
	check(where(16583)[1] == 0 and where(5565)[1] == 0 and cursor == nil, tag .. "refused reagents stay put, cursor empty")
	check(table.getn(chat) - before == 2, tag .. "one notice per refused item (got " .. (table.getn(chat) - before) .. ")")
	check(not F.shown, tag .. "scheduler goes idle after giving up")

	-- 14. Blizzlike server (shards don't stack): reagents left alone
	reset({ maxStack = 1, reagentsOK = false }); setBag(0, 16); setBag(4, 12, 22243)
	put(0, 1, 16583, 1)
	load(classic); fire("BAG_UPDATE"); fire("BAG_UPDATE_DELAYED"); run()
	check(where(16583)[1] == 0 and table.getn(chat) == 0, tag .. "no attempt on Blizzlike servers")

	-- 15. Toggle off
	reset({ familyKnown = true }); setBag(0, 16); setBag(4, 12, 22243); put(0, 1, 5565, 1)
	load(classic); SlashCmdList.SHARDCAP("reagents"); run()
	check(where(5565)[1] == 0 and ShardCapDB.reagents == false, tag .. "/shardcap reagents turns it off")
end

-- 10. Migration from ShardCap 1.x and slash parsing
print("[misc]")
reset(); setBag(0, 16)
dofile(ADDON_FILE); F = frames[1]
SHARDCAP_CAP_VALUE, SHARDCAP_SPAM = 7, true
fire("ADDON_LOADED", "ShardCap")
check(ShardCapDB.cap == 7 and ShardCapDB.notify == true, "migrated 1.x cap and spam setting")
check(SHARDCAP_CAP_VALUE == nil, "old globals cleared")
SlashCmdList.SHARDCAP("-3"); check(ShardCapDB.cap == 7, "negative cap rejected")
SlashCmdList.SHARDCAP("2.5"); check(ShardCapDB.cap == 7, "fractional cap rejected")
SlashCmdList.SHARDCAP("  15 "); check(ShardCapDB.cap == 15, "cap set with whitespace")
SlashCmdList.SHARDCAP("soulbag 3"); check(ShardCapDB.soulbags and ShardCapDB.soulbags[3], "manual soul bag")
SlashCmdList.SHARDCAP("soulbag auto"); check(ShardCapDB.soulbags == nil, "back to auto")
SlashCmdList.SHARDCAP("status"); SlashCmdList.SHARDCAP("help")
check(table.getn(chat) > 5, "status/help print")
reset(); setBag(0, 16); put(0, 1, 6265, 3); put(0, 2, 6265, 2)
load(false); ShardCapDB.cap = 12; chat = {}; SlashCmdList.SHARDCAP("")
check(string.find(chat[2] or "", "Demonic Figurines: |cffffffff0|r  Infernal Stones: |cffffffff0|r", 1, true) ~= nil, "reagent line with none carried")
reset(); setBag(0, 16); setBag(4, 12, 22243); put(0, 1, 6265, 3); put(0, 2, 6265, 2)
put(0, 3, 16583, 2); put(4, 5, 16583, 1); put(0, 4, 5565, 7)
load(false); ShardCapDB.cap = 12; ShardCapDB.reagents = false; chat = {}; SlashCmdList.SHARDCAP("")
check(string.find(chat[2] or "", "Demonic Figurines: |cffffffff3|r  Infernal Stones: |cffffffff7|r", 1, true) ~= nil, "reagents counted across all bags incl. soul bag (got: " .. (chat[2] or "nil") .. ")")
check(string.find(chat[1] or "", "Soul Shards: |cffffffff5/12|r", 1, true) ~= nil, "/shardcap shows 5/12 (got: " .. (chat[1] or "nil") .. ")")

-- 11. Unknown custom soul bag found through its "Soul Bag" subtype
reset(); setBag(0, 16); setBag(3, 20, 99999); put(0, 1, 6265, 1)
load(false); ShardCapDB.cap = 10; fire("BAG_UPDATE"); run()
check(count(3) == 1, "soul bag detected by subtype")

-- 12. Options window (ClassicAPI AddOn Options)
print("[options]")
local function findControl(page, label)
	for _, c in ipairs(page.controls) do
		local t = c.name and _G[c.name .. "Text"]
		if t and string.find(t.text, label, 1, true) then return c end
	end
end
local function click(c) if c.checked then c.checked = nil else c.checked = 1 end; call(c, "OnClick") end
local function findKind(page, kind)
	for _, c in ipairs(page.controls) do if c.kind == kind then return c end end
end

reset(); setBag(0, 16); setBag(4, 12, 22243)
put(0, 1, 6265, 3); put(0, 2, 6265, 2); put(4, 1, 16583, 2); put(0, 3, 5565, 4)
bank = { [6265] = 4, [5565] = 10 }
load(true, true); ShardCapDB.cap = 12
local main, bp = categories[1], categories[2]
check(main and main.name == "ShardCap" and bp and bp.name == "Soul Bag" and bp.parent == "ShardCap", "two pages registered, Soul Bag under ShardCap")

SlashCmdList.SHARDCAP("options")
check(categories.opened == main and main.shown, "/shardcap options opens the ShardCap page")
local texts = {}
for _, f in ipairs(allWidgets) do if f.kind == "FontString" and f.text ~= "" then table.insert(texts, f.text) end end
local joined = table.concat(texts, "\n")
check(string.find(joined, "5/12", 1, true) ~= nil, "status shows 5/12")
check(string.find(joined, "(+4 in bank)", 1, true) ~= nil, "status shows shards in bank")
check(string.find(joined, "Infernal Stones: |cffffffff4|r |cffaaaaaa(+10 in bank)|r", 1, true) ~= nil, "status shows stones with bank count")

local slider = findKind(main, "Slider")
check(slider.value == 12, "slider shows the cap")
slider:SetValue(30)
check(ShardCapDB.cap == 30, "slider sets the cap")
local box
for _, f in ipairs(frames) do if f.kind == "EditBox" then box = f end end
check(box.text == "30", "box follows the slider")
box:SetFocus(); box:SetText("150"); call(box, "OnEnterPressed")
check(ShardCapDB.cap == 150 and slider.value == 100, "box sets caps above the slider range")
box:SetFocus(); box:SetText("250"); call(box, "OnEnterPressed")
check(ShardCapDB.cap == 150 and box.text == "150", "out-of-range box value rejected")
box:SetFocus(); box:SetText("7"); call(box, "OnEscapePressed")
check(ShardCapDB.cap == 150 and box.text == "150", "Escape in the box discards the edit")

local notify = findControl(main, "Chat notifications")
click(notify); check(ShardCapDB.notify == true, "notifications checkbox")

-- Cancel restores what was there when the window opened; Okay keeps changes
main.cancel(main); bp.cancel(bp)
check(ShardCapDB.cap == 12 and ShardCapDB.notify == false, "Cancel restores settings")
SlashCmdList.SHARDCAP("options"); slider:SetValue(20); main.okay(main); bp.okay(bp)
SlashCmdList.SHARDCAP("options"); main.cancel(main)
check(ShardCapDB.cap == 20, "Okay keeps settings")

-- Defaults reset only the page shown
ShardCapDB.notify = true; ShardCapDB.reagents = false
main.default(main)
check(ShardCapDB.cap == 12 and ShardCapDB.notify == false and ShardCapDB.reagents == false, "Defaults on ShardCap page leave Soul Bag settings")
bp.default(bp)
check(ShardCapDB.reagents == true, "Defaults on Soul Bag page")

-- Soul bag page
bp:Show(); bp.refresh(bp)
local auto = findControl(bp, "Detect soul bags automatically")
local bag4 = findControl(bp, "Bag 4")
local bag2 = findControl(bp, "Bag 2")
check(auto.checked and bag4.checked and not bag4.enabled, "auto detection on; bag 4 shown as soul bag but locked")
check(not bag2.enabled and string.find(_G[bag2.name .. "Text"].text, "empty slot", 1, true) ~= nil, "empty bag slot greyed out")
click(auto)
check(type(ShardCapDB.soulbags) == "table" and ShardCapDB.soulbags[4] and bag4.enabled, "manual mode seeded from detection")
click(bag4)
check(not ShardCapDB.soulbags[4], "bag checkbox clears a soul bag")
click(auto)
check(ShardCapDB.soulbags == nil, "back to auto")
local reag = findControl(bp, "Demonic Figurines and Infernal Stones")
click(reag); check(ShardCapDB.reagents == false, "reagents checkbox")

-- Live refresh only while shown
put(0, 4, 6265, 1)
this = main; arg1 = 0.6; main.scripts.OnUpdate()
texts = {}
for _, f in ipairs(allWidgets) do if f.kind == "FontString" then table.insert(texts, f.text) end end
check(string.find(table.concat(texts, "\n"), "6/12", 1, true) ~= nil, "status refreshes while open")

-- Without ClassicAPI's options window
reset(); setBag(0, 16)
load(false, false); chat = {}
SlashCmdList.SHARDCAP("options")
check(table.getn(categories) == 0 and string.find(chat[1] or "", "needs ClassicAPI", 1, true) ~= nil, "no panel without ClassicAPI; slash explains")
SlashCmdList.SHARDCAP("")
check(string.find(chat[2] or "", "5/12", 1, true) == nil and string.find(chat[2] or "", "in bank", 1, true) == nil, "no bank text without ClassicAPI")

-- New ClassicAPI buffer contract: empty slots leave stale buffer fields intact.
reset(); setBag(0, 4); setBag(4, 4, 22243)
put(0, 1, 6265, 3); put(0, 2, 16583, 2); put(4, 1, 5565, 1)
load(true)
local bufferSeen, bufferCalls = nil, 0
C_Container.GetContainerItemInfo = function(b, s, buf)
	check(type(buf) == "table" and (not bufferSeen or bufferSeen == buf), "one shared item-info buffer")
	bufferSeen = buf; bufferCalls = bufferCalls + 1
	local it = bags[b].slots[s]
	if not it then return nil end
	buf.itemID, buf.stackCount, buf.isLocked = it.id, it.count, false
	return buf
end
local shards, reagents, soul = ShardCapAPI.StatusLines()
check(bufferCalls == 8 and string.find(shards, "3/12", 1, true) ~= nil,
	"buffer scan ignores stale data in empty slots")
check(string.find(reagents, "2|r", 1, true) ~= nil and string.find(reagents, "1|r", 1, true) ~= nil
	and string.find(soul, "3 free soul slots", 1, true) ~= nil, "count-only status includes reagents and free soul slots")
-- Status refresh must not build action records (table.insert is used by Scan).
local oldInsert = table.insert
table.insert = function(t, value)
	if type(value) == "table" then error("status allocated an action record") end
	return oldInsert(t, value)
end
local statusOK = pcall(ShardCapAPI.StatusLines)
table.insert = oldInsert
check(statusOK, "status avoids sorting records")
run()
check(count() == 3 and count(0) == 0 and not F.shown,
	"action scans copy values from the shared buffer before reusing it")

-- Refused sends must stop rather than notify, retry, or reject a reagent.
for _, kind in ipairs({ "merge", "shard", "reagent", "shard MoveItem" }) do
	reset(); setBag(0, 4); setBag(4, 8, 22243)
	if kind == "merge" then put(0, 1, 6265, 1); put(4, 1, 6265, 1)
	elseif kind ~= "reagent" then put(0, 1, 6265, 3)
	else put(0, 1, 16583, 2) end
	load(true); ShardCapDB.notify = true
	if kind == "shard MoveItem" then
		C_Container.SwapItems = nil
		fire("ADDON_LOADED", "ShardCap") -- detect MoveItem without SwapItems
	end
	local calls = 0
	local function refuse() calls = calls + 1; return false end
	local move, swap = C_Container.MoveItem, C_Container.SwapItems
	C_Container.MoveItem, C_Container.SwapItems = refuse, refuse
	chat = {}; run()
	check(calls == 1 and table.getn(chat) == 0 and not F.shown,
		kind .. " refused send stops without a success notice or polling")
	C_Container.MoveItem, C_Container.SwapItems = move, swap
	fire("BAG_UPDATE_DELAYED"); run()
	check(not F.shown and (kind == "reagent" and bags[0].slots[1] == nil
		or kind ~= "reagent" and count(0) == 0), kind .. " retries on a later bag event")
end

print(string.format("\n%d passed, %d failed", passes, fails))
if fails > 0 then os.exit(1) end
