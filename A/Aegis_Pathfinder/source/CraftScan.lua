--[[
	CraftScan.lua -- auction prices for the crafting route planner.

	The planner needs to know what reagents cost at the auction house. With
	Aegis: Exchange loaded it can ask Exchange; without it, this scans for
	itself. Open the auction house, press Scan prices in the crafting route
	window, and it searches for each reagent the profession uses, one name
	at a time, and keeps every listing it finds -- cheapest first, per realm
	-- so the planner can price forty of something as forty.

	The auction house rules of the suite (Aegis: Exchange's CLAUDE.md) hold
	here too:

	  - CanSendAuctionQuery() is asked before every query, and is the only
	    pacing: with the AuctionQueryThrottle DLL it opens fast, without it
	    the client holds it shut for a few seconds.
	  - QueryAuctionItems gets strings for its name and level arguments and
	    nil for the rest; pages count from 0.
	  - AUCTION_ITEM_LIST_UPDATE is only read while a reply is awaited, and
	    reading it ends the wait, so a burst of them reads one page once.

	A search is by name, and the auction house matches any name containing
	it -- "Linen Cloth" finds "Bolt of Linen Cloth" too -- so only listings
	with exactly the name searched for are kept.
]]

local AegisPathfinder = AegisPathfinder

local S = {
	PAGE = 50,              -- listings per page (fixed by the client)
	MAX_PAGES = 4,          -- per item; past 200 listings the price is known
	KEEP = 40,              -- price steps kept per item
	RECENT = 30 * 60,       -- an item scanned this recently is not scanned again
	TIMEOUT = 10,           -- seconds to wait for a reply before moving on
}
AegisPathfinder.craftScanTunables = S

local scan = {
	phase = "idle",         -- "idle", "send" (waiting on the gate) or "wait" (on a reply)
	queue = {}, index = 0, page = 0, found = nil, sentAt = 0, priced = 0,
}
AegisPathfinder.craftScanState = scan

local function Store(self)
	local realm = self.db and self.db.realm
	if not realm then return end
	realm.craftprices = realm.craftprices or {}

	local found = scan.found or {}
	table.sort(found, function(a, b) return a[1] < b[1] end)

	-- Flattened, one price step per distinct price: { price, count, ... }.
	local p = {}
	for _, listing in ipairs(found) do
		local n = table.getn(p)
		if n > 0 and p[n - 1] == listing[1] then
			p[n] = p[n] + listing[2]
		elseif n < S.KEEP * 2 then
			table.insert(p, listing[1])
			table.insert(p, listing[2])
		end
	end
	-- An empty list is kept too: "searched, none listed" is worth knowing,
	-- and stops the item being searched again straight away.
	realm.craftprices[scan.queue[scan.index]] = { t = time(), p = p }
	if p[1] then scan.priced = scan.priced + 1 end
end

local function Finish(self, stopped)
	local done, priced = scan.index, scan.priced
	scan.phase, scan.found = "idle", nil
	if scan.driver then scan.driver:Hide() end
	if stopped then
		self:Print(string.format("Price scan stopped after %d of %d items.", done - 1, table.getn(scan.queue)))
	else
		self:Print(string.format("Price scan done: %d of %d items are on the auction house.",
			priced, table.getn(scan.queue)))
	end
	if self.OnCraftDataChanged then self:OnCraftDataChanged(true) end
end

-- On to the next item in the queue, or done.
local function Advance(self)
	scan.index = scan.index + 1
	scan.page, scan.found = 0, {}
	if scan.index > table.getn(scan.queue) then
		Finish(self)
		return
	end
	scan.phase = "send"
	if self.OnCraftDataChanged then self:OnCraftDataChanged(false) end
end

local function ReadPage(self)
	scan.phase = "reading"
	local name = scan.queue[scan.index]
	local shown, total = GetNumAuctionItems("list")
	for i = 1, shown or 0 do
		local listed, _, count, _, _, _, _, _, buyout = GetAuctionItemInfo("list", i)
		if listed == name and buyout and buyout > 0 and count and count > 0 then
			table.insert(scan.found, { math.floor(buyout / count + 0.5), count })
		end
	end

	if (scan.page + 1) * S.PAGE < (total or 0) and scan.page + 1 < S.MAX_PAGES then
		scan.page = scan.page + 1
		scan.phase = "send"
		return
	end
	Store(self)
	Advance(self)
end

--- True while a scan is running; and how far it has got.
function AegisPathfinder:IsCraftScanning()
	return scan.phase ~= "idle", scan.index, table.getn(scan.queue)
end

--- True while the auction house is open.
function AegisPathfinder:AtAuctionHouse()
	return scan.open == true
end

--- Search the auction house for each of `items`, skipping any searched in
--- the last half hour (unless `force`). Returns how many it will search, or
--- nil and why not.
function AegisPathfinder:StartCraftScan(items, force)
	if not self:AtAuctionHouse() then return nil, "Open the auction house first." end
	if scan.phase ~= "idle" then return nil, "A price scan is already running." end

	local realm = self.db and self.db.realm
	local store = realm and realm.craftprices or {}
	local now, queue, seen = time(), {}, {}
	for _, item in ipairs(items or {}) do
		local last = store[item]
		if not seen[item] and (force or not last or now - (last.t or 0) >= S.RECENT) then
			seen[item] = true
			table.insert(queue, item)
		end
	end
	if table.getn(queue) == 0 then return 0 end

	scan.queue, scan.index, scan.priced = queue, 0, 0
	Advance(self)
	scan.driver:Show()
	return table.getn(queue)
end

function AegisPathfinder:StopCraftScan()
	if scan.phase ~= "idle" then Finish(self, true) end
end

--[[ The driver: sends each query once the client's gate opens, and gives up
	on a reply that never comes (someone else's search can swallow ours). ]]
local driver = CreateFrame("Frame")
driver:Hide()
scan.driver = driver
driver:SetScript("OnUpdate", function()
	local self = AegisPathfinder
	if scan.phase == "send" then
		if CanSendAuctionQuery() then
			QueryAuctionItems(scan.queue[scan.index], "", "", nil, nil, nil, scan.page, nil, nil)
			scan.phase, scan.sentAt = "wait", GetTime()
		end
	elseif scan.phase == "wait" and GetTime() - scan.sentAt > S.TIMEOUT then
		Store(self)
		Advance(self)
	end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("AUCTION_HOUSE_SHOW")
events:RegisterEvent("AUCTION_HOUSE_CLOSED")
events:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
events:SetScript("OnEvent", function()
	local self = AegisPathfinder
	if event == "AUCTION_ITEM_LIST_UPDATE" then
		-- State-gated: one read per query sent, however many fire.
		if scan.phase == "wait" then ReadPage(self) end
	elseif event == "AUCTION_HOUSE_SHOW" then
		scan.open = true
		if self.OnCraftDataChanged then self:OnCraftDataChanged(false) end
	elseif event == "AUCTION_HOUSE_CLOSED" then
		scan.open = false
		if scan.phase ~= "idle" then
			Finish(self, true)
		elseif self.OnCraftDataChanged then
			self:OnCraftDataChanged(false)
		end
	end
end)
AegisPathfinder.craftScanEvents = events
