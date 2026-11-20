-- Compat.lua: bridges the WoW 3.3 / Lua 5.1 constructs used by Auctionator 2.6.2 to the 1.12 client
-- (Lua 5.0, vanilla auction API).  Loaded first.  Everything here is prefixed Atr_ unless noted.

AtrNS = AtrNS or {}

local G = getfenv(0)

----------------------------------------------------------------------
-- small language helpers
----------------------------------------------------------------------

-- strsplit(delim, str): pieces as multiple return values; delim is matched literally
function Atr_strsplit(delim, str, pieces)
	if str == nil then return nil end
	local t, pos = {}, 1
	while true do
		local s, e = string.find(str, delim, pos, true)
		if (not s) or (pieces and getn(t) >= pieces - 1) then
			tinsert(t, string.sub(str, pos))
			break
		end
		tinsert(t, string.sub(str, pos, s - 1))
		pos = e + 1
	end
	return unpack(t)
end

-- Atr_hooksecurefunc(table, "Method", fn) / Atr_hooksecurefunc("Global", fn): runs fn after the original.
-- Auctionator always uses its own copy: 1.12 has no hooksecurefunc, and addons loaded earlier define
-- incompatible globals (Atlas-CFM's only knows the ("Global", fn) form, so every tooltip hook was a no-op).
function Atr_hooksecurefunc(a1, a2, a3)
	local tbl, name, fn
	if type(a1) == "string" then
		tbl, name, fn = G, a1, a2
	else
		tbl, name, fn = a1, a2, a3
	end
	local orig = tbl[name]
	if type(orig) ~= "function" then return end
	tbl[name] = function(p1, p2, p3, p4, p5, p6, p7, p8, p9)
		local r1, r2, r3, r4 = orig(p1, p2, p3, p4, p5, p6, p7, p8, p9)
		fn(p1, p2, p3, p4, p5, p6, p7, p8, p9)
		return r1, r2, r3, r4
	end
end

-- Lua errors coming from this addon are also echoed to the chat frame (once per message), so they show up
-- in screenshots even when the error popup is off.  The previous handler still runs.
do
	local seen = {}

	-- errors caught by pcall (tooltip hooks) are reported here, once per message
	function Atr_ReportError(msg)
		msg = tostring(msg)
		if seen[msg] then return end
		seen[msg] = true
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff3333Auctionator error:|r " .. msg)
		end
	end

	local prev = (G.geterrorhandler and geterrorhandler()) or G._ERRORMESSAGE
	if G.seterrorhandler and prev then
		seterrorhandler(function(msg)
			if type(msg) == "string" and string.find(msg, "Auctionator") and not seen[msg] then
				seen[msg] = true
				if DEFAULT_CHAT_FRAME then
					DEFAULT_CHAT_FRAME:AddMessage("|cffff3333Auctionator error:|r " .. msg)
				end
			end
			return prev(msg)
		end)
	end
end

function Atr_GetVersion()
	return "1.0.0"
end

----------------------------------------------------------------------
-- item info (3.x layout: name, link, rarity, ilevel, minLevel, type, subType, stack, equipLoc, texture, sellPrice)
----------------------------------------------------------------------

local linkByName = {}   -- lower(name) -> item link, filled from everything we see

function Atr_RememberItemLink(name, link)
	if name and link then linkByName[string.lower(name)] = link end
end

local function ItemIdOf(x)
	if type(x) == "number" then return x end
	if type(x) ~= "string" then return nil end
	local _, _, id = string.find(x, "item:(%d+)")
	if id then return tonumber(id) end
	local l = linkByName[string.lower(x)]
	if l then
		local _, _, id2 = string.find(l, "item:(%d+)")
		if id2 then return tonumber(id2) end
	end
	return nil
end

function Atr_ItemIdFromAnything(x)
	return ItemIdOf(x)
end

-- SellValues (checked below as a fallback) only exists if the player has the separate, optional
-- "SellValue" addon installed (see the .toc's OptionalDeps) - without it this always returned nil.
-- C_Item.GetItemSellPriceByID is this server's own extension for vendor price and needs nothing
-- else installed, so prefer it (confirmed available here via SnapAuction, a known-working addon).
function Atr_GetSellValueById(id)
	if not id then return nil end
	if G.C_Item and G.C_Item.GetItemSellPriceByID then
		local v = G.C_Item.GetItemSellPriceByID(id)
		if v and v > 0 then return v end
	end
	if G.SellValues then
		local v = G.SellValues["item:" .. id]
		if v then return v end
	end
	return nil
end

-- SetHyperlink/GetItemInfo want the bare "item:id:ench:suffix:unique" string, never the full
-- "|cxxxxxxxx|Hitem:...|h[Name]|h|r" hyperlink. This server sometimes hands back something that is
-- neither - e.g. just the bracketed display name "[Heavy Stone]" - instead of a real link (seen from
-- GetAuctionSellItemInfo, and possibly GetItemInfo too). Extract the bare form out of whatever we're
-- given, or return nil if it isn't in there at all, rather than passing bad data to SetHyperlink.
function Atr_NormalizeItemLink(link)
	if not link then return nil end
	local _, _, itemString = string.find(tostring(link), "(item:%d+:%d+:%d+:%d+)")
	return itemString
end

-- the inverse of Atr_NormalizeItemLink: builds a clickable chat/tooltip hyperlink
-- ("|cxxxxxxxx|Hitem:...|h[Name]|h|r") from the bare item string, for anywhere we want to print
-- a link in a chat message rather than hand it to SetHyperlink.
function Atr_BuildDisplayLink(itemString)
	if not itemString then return nil end
	local name, _, rarity = Atr_GetItemInfo(itemString)
	if not name then return itemString end
	local hex = "ffffffff"
	local _, _, _, h = GetItemQualityColor(rarity or 1)
	if h then hex = h end
	return hex .. "|H" .. itemString .. "|h[" .. name .. "]|h|r"
end

function Atr_GetItemInfo(x)
	-- preserve the enchant/suffix/unique fields when they're already in `x` - rebuilding the
	-- query as bare "item:ID:0:0:0" always asked for the base item, silently dropping any random
	-- property ("of the Owl" etc.) and returning the wrong (suffix-less) name/price lookups for it
	local id = ItemIdOf(x)
	local itemString = Atr_NormalizeItemLink(x)
	if not itemString then
		if not id then return nil end
		itemString = "item:" .. id .. ":0:0:0"
	end
	local a, b, c, d, e, f, g, h, i, j = GetItemInfo(itemString)
	if not a then return nil end
	local name, link, rarity, ilevel, minLevel, itemType, subType, stack, equip, texture
	if type(e) == "string" then
		-- 1.12 layout: name, link, rarity, minLevel, type, subType, stack, equipLoc, texture
		name, link, rarity, minLevel, itemType, subType, stack, equip, texture = a, b, c, d, e, f, g, h, i
	else
		-- 2.x+ layout (extended clients)
		name, link, rarity, ilevel, minLevel, itemType, subType, stack, equip, texture = a, b, c, d, e, f, g, h, i, j
	end
	link = Atr_NormalizeItemLink(link)
	if link then Atr_RememberItemLink(name, link) end
	return name, link, rarity, ilevel, minLevel, itemType, subType, stack, equip, texture, Atr_GetSellValueById(id)
end

function Atr_GetItemIcon(x)
	local _, _, _, _, _, _, _, _, _, texture = Atr_GetItemInfo(x)
	return texture
end

----------------------------------------------------------------------
-- cursor / inventory
----------------------------------------------------------------------

function Atr_CursorIsItem()
	return CursorHasItem() and true or false
end

local function DropCursorAnywhere()
	if not CursorHasItem() then return end
	for bag = 0, 4 do
		for slot = 1, (GetContainerNumSlots(bag) or 0) do
			if not GetContainerItemLink(bag, slot) then
				PickupContainerItem(bag, slot)
				if not CursorHasItem() then return end
			end
		end
	end
	if G.ClearCursor then ClearCursor() end
end
Atr_DropCursorAnywhere = DropCursorAnywhere

local function LinkId(link)
	if not link then return nil end
	local _, _, id = string.find(link, "item:(%d+)")
	return id and tonumber(id) or nil
end

-- a bare display name like "Heavy Stone", not a link: find a matching item still in the bags.
-- GetContainerItemLink returns the full "|c..|H..|h[Name]|h|r" hyperlink, so normalize it down
-- to the bare form SetHyperlink/GetItemInfo actually want.
local function FindBagItemLinkByName(name)
	if not name then return nil end
	local lname = string.lower(name)
	for bag = 0, 4 do
		for slot = 1, (GetContainerNumSlots(bag) or 0) do
			local link = GetContainerItemLink(bag, slot)
			if link then
				local _, _, nm = string.find(link, "%[(.-)%]")
				if nm and string.lower(nm) == lname then return Atr_NormalizeItemLink(link) end
			end
		end
	end
	return nil
end

-- link of the item currently sitting in the auction sell slot
function Atr_SellSlotLink()
	-- this server's GetAuctionSellItemInfo does NOT return a real link as its 8th value (despite
	-- what older comments here assumed) - it's just the bracketed display name, e.g. "[Heavy Stone]".
	-- Always resolve the link ourselves instead of trusting that value.
	local name, texture, count, quality, canUse, price, maxStack = GetAuctionSellItemInfo()
	if not name then return nil end
	local link = Atr_NormalizeItemLink(linkByName[string.lower(name)])
	if not link then
		link = FindBagItemLinkByName(name)
		if link then Atr_RememberItemLink(name, link) end
	end
	return link, name, count, maxStack, price
end

-- total of an item (by name) in bags; a stack inside the auction slot is counted once
function Atr_CountItemInBags(itemName)
	local total, lockedCounts = 0, {}
	local lname = itemName and string.lower(itemName)
	for bag = 0, 4 do
		for slot = 1, (GetContainerNumSlots(bag) or 0) do
			local link = GetContainerItemLink(bag, slot)
			if link then
				local _, _, nm = string.find(link, "%[(.-)%]")
				if nm and string.lower(nm) == lname then
					local _, count, locked = GetContainerItemInfo(bag, slot)
					total = total + (count or 1)
					if locked then lockedCounts[count or 1] = true end
				end
			end
		end
	end
	local slotLink, slotName, slotCount = Atr_SellSlotLink()
	if slotName and string.lower(slotName) == lname and slotCount and not lockedCounts[slotCount] then
		total = total + slotCount
	end
	return total
end

----------------------------------------------------------------------
-- auction house call adapters
----------------------------------------------------------------------

-- 1.12 has no getAll; class/subclass/slot indexes of 0 mean "any" and must be nil
function Atr_QueryAuctionItems(name, minLevel, maxLevel, invType, itemClass, itemSubclass, page, usable, quality)
	if minLevel == "" then minLevel = nil end
	if maxLevel == "" then maxLevel = nil end
	if invType == 0 then invType = nil end
	if itemClass == 0 then itemClass = nil end
	if itemSubclass == 0 then itemSubclass = nil end
	if usable == 0 then usable = nil end
	if quality == 0 or quality == -1 then quality = nil end
	QueryAuctionItems(name or "", minLevel, maxLevel, invType, itemClass, itemSubclass, page or 0, usable, quality)
end

function Atr_CanSendAuctionQuery()
	local can = CanSendAuctionQuery()
	return can, false
end

-- durations: 1,2,3 as Auctionator uses them -> minutes understood by StartAuction on this server
AtrNS.durationMinutes = { 120, 480, 1440 }
AtrNS.durationText = { "6 hours", "24 hours", "72 hours" }

----------------------------------------------------------------------
-- multi stack posting (the 3.3 client did this in StartAuction itself)
----------------------------------------------------------------------

local post = nil
local driver = CreateFrame("Frame", "AtrCompatDriver")

-- all bag slots holding `id`, plus one empty slot to split into. Splitting a bigger stack
-- straight into the auction sell slot does not carry the split amount through on this server
-- (confirmed: the source stack is left untouched and the full stack ends up in the sell slot
-- regardless of the requested split size) - but splitting into an empty bag slot first, letting
-- it settle into its own real stack, and placing THAT into the sell slot on a later pass works
-- correctly. This mirrors the approach used by SnapAuction, a known-working addon on this server.
local function CollectStacks(id)
	local list, empty = {}, nil
	for bag = 0, 4 do
		for slot = 1, (GetContainerNumSlots(bag) or 0) do
			local link = GetContainerItemLink(bag, slot)
			if not link then
				empty = empty or { bag = bag, slot = slot }
			elseif LinkId(link) == id then
				local _, count, locked = GetContainerItemInfo(bag, slot)
				tinsert(list, { bag = bag, slot = slot, count = count or 1, locked = locked })
			end
		end
	end
	return list, empty
end

local function ClearSlot()
	if not GetAuctionSellItemInfo() then return end
	if CursorHasItem() and G.ClearCursor then ClearCursor() end
	ClickAuctionSellItemButton()
	DropCursorAnywhere()
end

local function Finish(msg)
	local p = post
	post = nil
	-- a refill is a best-effort courtesy (see below), not a real posting attempt: fail silently,
	-- there's nothing to report and nothing that actually went wrong with any auction
	if p and p.refillOnly then
		ClearSlot()
		return
	end
	if p and msg and G.Atr_OnAuctionMultiSellFailureMsg then
		Atr_OnAuctionMultiSellFailureMsg(msg)
	elseif msg and DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ffffAuctionator:|r " .. msg)
	end
	ClearSlot()
	if p and p.multi and p.done < p.n and G.Atr_OnAuctionMultiSellFailure then
		Atr_OnAuctionMultiSellFailure()
	end
end

local function Step()
	local p = post
	if not p then return end
	local now = GetTime()
	if not AtrNS.ahOpen and AuctionFrame and not AuctionFrame:IsVisible() then
		Finish("Auction house closed, posting stopped.")
		return
	end
	if p.state == "prep" then
		if now < p.t then return end

		local name, nativeCount = GetAuctionSellItemInfo()
		if name then
			if p.refillOnly then
				post = nil	-- already something there (e.g. a split still settling); good enough
				if G.Atr_OnRefillSettled then Atr_OnRefillSettled() end
				return
			end
			if nativeCount == p.size then
				p.state = "ready"
				return
			end
			ClearSlot()
			p.pendingBag, p.pendingSlot = nil, nil
			p.t = now + 0.4
			return
		end

		if p.refillOnly then
			-- just move whatever's left back into the sell slot as a single stack, exactly as
			-- it already sits in the bags - no splitting. The point is to save a re-drag for the
			-- next post, not to pre-chop the remainder into another stackSize-sized piece.
			local list = CollectStacks(p.id)
			local biggest
			for _, st in ipairs(list) do
				if st.locked then
					p.t = now + 0.2
					return
				end
				if not biggest or st.count > biggest.count then biggest = st end
			end
			if biggest then
				PickupContainerItem(biggest.bag, biggest.slot)
				ClickAuctionSellItemButton()
			end
			post = nil
			if G.Atr_OnRefillSettled then Atr_OnRefillSettled() end
			return
		end

		if CursorHasItem() and G.ClearCursor then ClearCursor() end	-- leftover from a split that didn't fully settle last cycle

		-- after a split, the slot we dropped the split-off piece into takes noticeably longer to
		-- report its new contents than the source stack takes to shrink. Scanning again too soon
		-- found the destination still reporting empty and split yet another piece off the
		-- remainder (it looked like nothing had worked yet), snowballing into many tiny stacks.
		-- Wait specifically for THAT slot to show the expected count before doing anything else.
		if p.pendingBag then
			local _, pendingCount, pendingLocked = GetContainerItemInfo(p.pendingBag, p.pendingSlot)
			if pendingLocked or pendingCount ~= p.size then
				if now - p.pendingSince > 3 then
					Finish("A split didn't settle in the bags (" .. p.done .. " of " .. p.n .. " posted).")
					return
				end
				p.t = now + 0.2
				return
			end
			p.pendingBag, p.pendingSlot = nil, nil
		end

		local list, empty = CollectStacks(p.id)
		for _, st in ipairs(list) do
			if st.locked then
				p.t = now + 0.2	-- still settling from a previous split; wait
				return
			end
		end

		-- a stack of exactly the right size already exists: straight into the sell slot. Re-check
		-- this exact slot fresh right before acting - CollectStacks's scan can be a frame stale
		-- against a bag slot the previous post just vacated, and acting on that stale read is
		-- what caused "Item was not found"; if it's changed, just retry next frame instead of
		-- guessing how long to wait
		for _, st in ipairs(list) do
			if st.count == p.size then
				local _, freshCount, freshLocked = GetContainerItemInfo(st.bag, st.slot)
				if freshLocked or freshCount ~= p.size then
					return
				end
				PickupContainerItem(st.bag, st.slot)
				ClickAuctionSellItemButton()
				p.state = "placing"
				p.t = now
				return
			end
		end

		-- only bigger stacks: split the needed amount into an empty slot and let it settle
		-- there before trying to sell it (see CollectStacks' comment above)
		for _, st in ipairs(list) do
			if st.count > p.size then
				if not empty then
					Finish("Need an empty bag slot to split stacks (" .. p.done .. " of " .. p.n .. " posted).")
					return
				end
				local _, freshCount, freshLocked = GetContainerItemInfo(st.bag, st.slot)
				if freshLocked or (freshCount or 0) < p.size then
					return
				end
				SplitContainerItem(st.bag, st.slot, p.size)
				PickupContainerItem(empty.bag, empty.slot)
				p.pendingBag, p.pendingSlot, p.pendingSince = empty.bag, empty.slot, now
				p.t = now + 0.2
				return
			end
		end

		Finish("Not enough items to finish posting (" .. p.done .. " of " .. p.n .. " posted).")
	elseif p.state == "placing" then
		local name, _, count = GetAuctionSellItemInfo()
		if name and count == p.size then
			p.state = "ready"
		elseif now - p.t > 3 then
			if CursorHasItem() then DropCursorAnywhere() end
			Finish("Could not place the item in the auction slot (" .. p.done .. " of " .. p.n .. " posted).")
		end
	elseif p.state == "ready" then
		if p.refillOnly then
			-- the item is already sitting in the sell slot at the right size; that's the whole
			-- point of a refill pass, so stop here instead of actually posting it
			post = nil
			return
		end
		StartAuction(p.bid, p.buyout, p.minutes)
		p.state = "posting"
		p.auctionConfirmed = false
		p.t = now
	elseif p.state == "posting" then
		-- confirmed ONLY by the server actually saying so (same signal the chat-spam suppressor in
		-- Auctionator.lua already watches for). The sell slot clearing is NOT a safe stand-in for
		-- this - the client resets that UI optimistically the instant StartAuction is called,
		-- before the server has had any chance to accept or reject it, so a slot-empty check
		-- reports "confirmed" even when the post was silently rejected server-side.
		if p.auctionConfirmed then
			p.done = p.done + 1
			if p.multi and G.Atr_OnAuctionMultiSellUpdate then
				local sv1, sv2 = G.arg1, G.arg2
				G.arg1, G.arg2 = p.done, p.n
				Atr_OnAuctionMultiSellUpdate()
				G.arg1, G.arg2 = sv1, sv2
			end
			if p.done >= p.n then
				-- leave whatever's left of this item sitting in the sell slot rather than
				-- leaving it empty - posting another batch of the same item right after is
				-- common, and this saves having to drag it back in from the bags. The "prep"
				-- refillOnly branch moves it over as a single stack, with no splitting.
				p.refillOnly = true
				p.pendingBag, p.pendingSlot = nil, nil
				p.state = "prep"
				p.t = now
			else
				p.state = "prep"
				p.t = now
			end
		elseif now - p.t > 6 then
			Finish("The server did not confirm the auction (" .. p.done .. " of " .. p.n .. " posted).")
		end
	end
end

-- runs every frame, same as the reference addon this was benchmarked against - the 0.1s
-- throttle this used to have, plus fixed grace periods sprinkled through Step() itself, were
-- adding real, noticeable delay per auction for no safety benefit over just polling state as
-- fast as the game already ticks
driver:SetScript("OnUpdate", function()
	if not post then return end
	Step()
end)

-- UI_ERROR_MESSAGE used to abort posting unconditionally on ANY such event, but that channel
-- isn't specific to auctions - something entirely unrelated (seen in testing: "Unknown unit")
-- can fire one mid-sequence and would wrongly cancel a posting run that wasn't actually broken.
-- Genuine stalls are still caught by the per-state timeouts below (3s placing, 6s posting).
driver:RegisterEvent("AUCTION_HOUSE_CLOSED")
driver:RegisterEvent("CHAT_MSG_SYSTEM")
driver:SetScript("OnEvent", function()
	if not post then return end
	if event == "AUCTION_HOUSE_CLOSED" then
		post = nil
	elseif event == "CHAT_MSG_SYSTEM" then
		if arg1 == ERR_AUCTION_STARTED and post.state == "posting" then
			post.auctionConfirmed = true
		end
	end
end)

function Atr_PostingInProgress()
	return post ~= nil
end

-- startingBid / buyout are per stack; duration is 1,2,3
function Atr_StartAuction(startingBid, buyout, duration, stackSize, numStacks)
	if post then return end
	local link, name, count = Atr_SellSlotLink()
	local id = LinkId(link)
	stackSize = stackSize or count or 1
	numStacks = numStacks or 1
	if not name then return end
	local minutes = AtrNS.durationMinutes[duration] or duration or 1440
	if numStacks == 1 and count == stackSize then
		StartAuction(startingBid, buyout, minutes)
		return
	end
	if not id then
		StartAuction(startingBid, buyout, minutes)
		return
	end
	post = { id = id, size = stackSize, n = numStacks, done = 0, bid = startingBid, buyout = buyout,
		minutes = minutes, state = "prep", t = GetTime(), multi = (numStacks > 1) }
	if post.multi and G.Atr_OnAuctionMultiSellStart then Atr_OnAuctionMultiSellStart() end
end

----------------------------------------------------------------------
-- selected row in the lists.  The 3.x code locked the button in its PUSHED state; the list buttons have
-- no NormalTexture and the 1.12 client never hid the pushed texture again, so every clicked row stayed
-- yellow.  The rows now carry their own selection texture instead (the XML PushedTextures are removed).
----------------------------------------------------------------------

function Atr_SetRowSelected(row, on)
	local sel = row.atrSel
	if not sel then
		sel = row:CreateTexture(nil, "BACKGROUND")
		sel:SetTexture("Interface\\HelpFrame\\HelpFrameButton-Highlight")
		sel:SetAllPoints(row)
		local name = row:GetName() or ""
		if string.find(name, "^AuctionatorEntry") then
			sel:SetTexCoord(0.25, 0.35, 0.0, 0.6)
		else
			sel:SetTexCoord(0.15, 0.25, 0.0, 0.6)
			if sel.SetBlendMode then sel:SetBlendMode("ADD") end
		end
		row.atrSel = sel
	end
	if on then sel:Show() else sel:Hide() end
end

----------------------------------------------------------------------
-- Blizzard coins instead of g/s/c letters (1.12 text cannot hold inline textures, so prices use small
-- money frames: tooltips, the Stack Price column, the deposit line)
----------------------------------------------------------------------

local moneyFrames = 0

function Atr_CreateMoneyFrame(parent, moneyType)
	moneyFrames = moneyFrames + 1
	local f = CreateFrame("Frame", "AtrMoneyFrame" .. moneyFrames, parent, "SmallMoneyFrameTemplate")
	local saved = G.this
	G.this = f
	f.small = 1
	MoneyFrame_SetType(moneyType or "STATIC")
	G.this = saved
	return f
end

function Atr_SetMoney(frame, money)
	-- deposit math in particular (CalculateAuctionDeposit split across stacks) can produce a
	-- fractional copper amount, which MoneyFrame_Update then shows as a decimal on one of the
	-- coin textures instead of rounding it away
	MoneyFrame_Update(frame:GetName(), math.floor((money or 0) + 0.5))
end

-- tooltips: one pooled money frame per priced line, hidden whenever the tooltip is reused or hidden
local function TipHideMoney(tip, resetWidth)
	if tip.atrMoney then
		for i = 1, getn(tip.atrMoney) do tip.atrMoney[i]:Hide() end
	end
	tip.atrMoneyUsed = 0
	if resetWidth and tip.atrMinWidth then
		tip.atrMinWidth = nil
		tip:SetMinimumWidth(0)
	end
end

local function TipHook(tip)
	if tip.atrMoney then return end
	tip.atrMoney = {}
	local origHide = tip:GetScript("OnHide")
	tip:SetScript("OnHide", function()
		TipHideMoney(tip, true)
		if origHide then origHide() end
	end)
	Atr_hooksecurefunc(tip, "SetOwner", function(t) TipHideMoney(tip, true) end)
	Atr_hooksecurefunc(tip, "ClearLines", function(t) TipHideMoney(tip, true) end)
end

function Atr_TipBeginMoney(tip)
	TipHideMoney(tip, false)
end

function Atr_TipAddMoneyLine(tip, label, money)
	TipHook(tip)
	tip:AddDoubleLine(label, " ")
	local n = tip:NumLines()
	local used = (tip.atrMoneyUsed or 0) + 1
	tip.atrMoneyUsed = used
	local mf = tip.atrMoney[used]
	if not mf then
		mf = Atr_CreateMoneyFrame(tip, "STATIC")
		tip.atrMoney[used] = mf
	end
	Atr_SetMoney(mf, money)
	mf:ClearAllPoints()
	local tname = tip:GetName()
	local left = getglobal(tname .. "TextLeft" .. n)
	local right = getglobal(tname .. "TextRight" .. n)
	if right then
		mf:SetPoint("RIGHT", right, "RIGHT", 13, 0)		-- the coins sit 13px inside the frame's right edge
	elseif left then
		mf:SetPoint("LEFT", left, "RIGHT", 8, 0)
	end
	mf:Show()
	local need = (left and left:GetStringWidth() or 80) + mf:GetWidth() + 30
	if need > (tip.atrMinWidth or 0) then
		tip.atrMinWidth = need
		tip:SetMinimumWidth(need)
	end
end

-- Stack Price column of the auction list rows
function Atr_ShowRowStackMoney(row, money)
	local mf = row.atrStackMoney
	if not money then
		if mf then mf:Hide() end
		return
	end
	if not mf then
		mf = Atr_CreateMoneyFrame(row, "STATIC")
		mf:SetPoint("RIGHT", row, "LEFT", 573, 0)		-- right edge of the 120px column at x=440
		row.atrStackMoney = mf
	end
	Atr_SetMoney(mf, money)
	mf:Show()
end

-- "Deposit:" line of the Sell tab
function Atr_ShowDepositMoney(money, suffix)
	local mf = AtrNS.depositMoney
	if not money then
		if mf then mf:Hide() end
		return
	end
	if not mf then
		mf = Atr_CreateMoneyFrame(Atr_Deposit_Text:GetParent(), "STATIC")
		mf:SetPoint("LEFT", Atr_Deposit_Text, "RIGHT", 2, 0)
		local fs = mf:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		fs:SetPoint("LEFT", mf, "RIGHT", -8, 0)
		mf.atrSuffix = fs
		AtrNS.depositMoney = mf
	end
	Atr_SetMoney(mf, money)
	mf.atrSuffix:SetText(suffix or "")
	mf:Show()
end

----------------------------------------------------------------------
-- odds and ends the 3.x code takes for granted
----------------------------------------------------------------------

function Atr_ItemStackSize(link)
	if not link then return 0 end
	local _, _, _, _, _, _, _, stack = Atr_GetItemInfo(link)
	return stack or 0
end

-- no sort-clear call on 1.12; Auctionator only used it to start from a known state
function Atr_SortAuctionClearSort(kind)
end

-- the stock helper returns nil until the first scroll
do
	local origGetOffset = G.FauxScrollFrame_GetOffset
	if origGetOffset then
		function FauxScrollFrame_GetOffset(frame)
			return origGetOffset(frame) or 0
		end
	end
end

if not G.ClearCursor then
	function ClearCursor()
		if CursorHasItem() then Atr_DropCursorAnywhere() end
	end
end

-- addon memory reporting does not exist on 1.12 (only used by /atr mem)
if not G.UpdateAddOnMemoryUsage then
	function UpdateAddOnMemoryUsage() end
end
if not G.GetAddOnMemoryUsage then
	function GetAddOnMemoryUsage() return 0 end
end
if not G.GetAddOnMetadata then
	function GetAddOnMetadata() return Atr_GetVersion() end
end
