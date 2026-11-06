--[[
	PartySync.lua -- sharing a guide with your party.

	Playing a guide with someone else is awkward when neither of you can see
	which step the other is on: one of you races ahead, the other is left
	killing boars alone. Sharing keeps you together, as Zygor's Share Mode
	does:

	  - The party icon on the guide panel's step row invites your party to
	    share the guide you are on (after a confirmation you can turn off).
	  - Each member gets a popup; accepting opens the guide in a new tab.
	  - Under the step, every member sharing it is listed with their progress
	    on it -- "Ghanndraine [3/6]" -- or which step they are on if it is
	    another.
	  - A step you have finished is held until everyone sharing has finished
	    it too; then the guide moves on for all of you together. The skip
	    arrow still moves you on alone if you want to.

	Members talk over the party (or raid) addon channel with short messages,
	fields separated by "^":

	  INV^guide^step   an invitation, from whoever clicked the icon
	  ACC^guide        accepted       DEC^guide  declined
	  NOG^guide        "I do not have that guide"
	  ST^guide^step^done^have^need    where I am and how far on it
	  REQ^guide        "tell me where you are"    BYE^guide  stopped sharing

	A step is named by its action and quest id (or title) and which
	occurrence of that it is, not by its number: two characters on the same
	guide can have different step numbers, since class and race steps are
	filtered per character.
]]

local AegisPathfinder = AegisPathfinder
local Theme = AegisPathfinder.Theme

local S = {
	PREFIX = "AegisPF",
	SEP = "^",
	POLL = 0.5,          -- how often our own status is looked at
	THROTTLE = 1,        -- a status message at most this often...
	HEARTBEAT = 15,      -- ...and at least this often while sharing
	WIDTH = 380,
	LINE_H = 16,
	BUTTON_H = 22,
}
AegisPathfinder.shareTunables = S

local share = {
	active = false,      -- sharing a guide
	guide = nil,         -- which
	members = {},        -- name -> { key, done, have, need, seen }
	holding = nil,       -- the finished step held for the party, if any
	bypass = nil,        -- a held step the player skipped past alone
	pending = nil,       -- an invitation waiting on the popup: { from, guide }
	lastSent = 0, lastSig = nil, polled = 0,
}
AegisPathfinder.shareState = share

--[[ The channel and who is on it. ]]

local function Channel()
	if GetNumRaidMembers and GetNumRaidMembers() > 0 then return "RAID" end
	if GetNumPartyMembers and GetNumPartyMembers() > 0 then return "PARTY" end
	return nil
end

local function GroupNames()
	local names = {}
	local raid = GetNumRaidMembers and GetNumRaidMembers() or 0
	if raid > 0 then
		for i = 1, raid do
			local n = UnitName("raid" .. i)
			if n then names[n] = true end
		end
	else
		for i = 1, (GetNumPartyMembers and GetNumPartyMembers() or 0) do
			local n = UnitName("party" .. i)
			if n then names[n] = true end
		end
	end
	return names
end

local function Clean(s)
	return (string.gsub(tostring(s or ""), "%^", ""))
end

local function Send(...)
	local channel = Channel()
	if not channel then return false end
	local fields = {}
	for i = 1, arg.n do fields[i] = Clean(arg[i]) end
	SendAddonMessage(S.PREFIX, table.concat(fields, S.SEP), channel)
	return true
end

local function Split(msg)
	local out = {}
	for field in string.gfind((msg or "") .. S.SEP, "(.-)%^") do table.insert(out, field) end
	return out
end

--[[ Steps by name rather than number. ]]

local keyed = { quests = nil, keys = {}, index = {} }

local function Keys(self)
	if keyed.quests ~= self.quests then
		keyed.quests, keyed.keys, keyed.index = self.quests, {}, {}
		local seen = {}
		for i = 1, table.getn(self.actions or {}) do
			local title = string.gsub(self.quests[i] or "", "@.*@", "")
			local qid = self:GetObjectiveTag("QID", i)
			local base = Clean(self.actions[i] .. ":" .. (qid or title))
			seen[base] = (seen[base] or 0) + 1
			local key = base .. "#" .. seen[base]
			keyed.keys[i], keyed.index[key] = key, i
		end
	end
	return keyed
end

--- A step's name across characters, and the step a name is here (or nil).
function AegisPathfinder:ShareStepKey(i)
	return Keys(self).keys[i]
end
function AegisPathfinder:ShareStepIndex(key)
	return key and Keys(self).index[key]
end

local function SharingHere(self)
	return share.active and share.guide ~= nil and self.db and share.guide == self.db.char.currentguide
end

--[[ Holding the step (called by UpdateStatusFrame). ]]

--- The step to stay on instead of `nextstep`, or nil to carry on. A member
--- on step p lets you go as far as p -- or p + 1 once they have finished p
--- -- and no further; you never go back to meet someone behind you, you wait
--- where you are.
function AegisPathfinder:ShareHold(nextstep, oldcurrent)
	share.holding = nil
	if not SharingHere(self) or not self.actions then return nil end
	local k = Keys(self)
	local limit
	for _, m in pairs(share.members) do
		local pos = m.key and k.index[m.key]
		if pos then
			local frontier = m.done and pos + 1 or pos
			if not limit or frontier < limit then limit = frontier end
		end
	end
	if not limit then return nil end
	-- A step skipped alone stays skipped until the party catches up.
	if share.bypass then
		if limit > share.bypass then share.bypass = nil else limit = share.bypass + 1 end
	end
	local last = nextstep or (table.getn(self.actions) + 1)
	local held = limit
	if oldcurrent and oldcurrent > held then held = oldcurrent end
	if held >= last then return nil end
	share.holding = held
	return held
end

-- The skip arrow on a held step moves you on alone.
local skip = AegisPathfinder.SkipToNextObjective
function AegisPathfinder:SkipToNextObjective()
	if share.holding and share.holding == self.current then share.bypass = self.current end
	return skip(self)
end

--[[ Our own status. ]]

local function OwnStatus(self)
	local i = self.current
	if not i or not self.actions or not self.actions[i] then return nil end
	local key = Keys(self).keys[i]
	local done = share.holding == i
	local have, need = "", ""
	if not done and self.actions[i] == "COMPLETE" and self.ReadLeaderboard then
		local _, logi, complete = self:GetObjectiveStatus(i)
		if logi and not complete then
			local _, h, n = self.ReadLeaderboard(logi)
			if h and n then have, need = h, n end
		end
	end
	return key, done, have, need
end

local driver = CreateFrame("Frame")
driver:Hide()
AegisPathfinder.shareDriver = driver

local function Wake()
	driver:Show()
end

local function SendStatus(self, now)
	local key, done, have, need = OwnStatus(self)
	if not key then return end
	share.lastSig = table.concat({ key, done and 1 or 0, have, need }, S.SEP)
	share.lastSent = now
	Send("ST", share.guide, key, done and 1 or 0, have, need)
end

driver:SetScript("OnUpdate", function()
	local self = AegisPathfinder
	local now = GetTime()
	-- Members' news settles once a frame: the hold, then the panel.
	if share.engineDirty then
		share.engineDirty = nil
		if self.UpdateStatusFrame then self:UpdateStatusFrame() end
		if self.UpdateOHPanel then self:UpdateOHPanel() end
	end
	if not share.active then
		this:Hide()
		return
	end
	if share.sendNow then
		share.sendNow = nil
		if SharingHere(self) then SendStatus(self, now) end
		return
	end
	if now - share.polled < S.POLL then return end
	share.polled = now
	if not SharingHere(self) then return end
	local key, done, have, need = OwnStatus(self)
	if not key then return end
	local sig = table.concat({ key, done and 1 or 0, have, need }, S.SEP)
	if (sig ~= share.lastSig and now - share.lastSent >= S.THROTTLE) or now - share.lastSent >= S.HEARTBEAT then
		SendStatus(self, now)
	end
end)

--[[ Starting and stopping. ]]

local function Refresh(self)
	share.engineDirty = true
	Wake()
	if self.PaintShareButton then self:PaintShareButton() end
end

--- Members sharing with us, sorted by name.
function AegisPathfinder:ShareMembers()
	local out = {}
	for name in pairs(share.members) do table.insert(out, name) end
	table.sort(out)
	return out
end

function AegisPathfinder:StartSharing()
	local guide = self.db.char.currentguide
	if not guide or (self.HasNoGuide and self:HasNoGuide()) then
		self:Print("Open a guide first: that is what gets shared.")
		return false
	end
	if not Channel() then
		self:Print("Join a party first: sharing needs someone to share with.")
		return false
	end
	share.active, share.guide, share.members, share.bypass = true, guide, {}, nil
	Send("INV", guide, self:ShareStepKey(self.current) or "")
	share.sendNow = true
	self:Print(string.format("Invited your party to share %s. They need Aegis: Pathfinder to join.", guide))
	Refresh(self)
	return true
end

function AegisPathfinder:StopSharing(quiet)
	if not share.active then return end
	Send("BYE", share.guide)
	if not quiet then self:Print(string.format("Stopped sharing %s.", share.guide)) end
	share.active, share.guide, share.members, share.holding, share.bypass = false, nil, {}, nil, nil
	Refresh(self)
end

--- The party icon: start (after asking, unless told not to) or stop.
function AegisPathfinder:ToggleSharing()
	if share.active then return self:StopSharing() end
	if not Channel() then
		self:Print("Join a party first: sharing needs someone to share with.")
		return
	end
	if self.db.char.sharenowarn then return self:StartSharing() end
	self:ShowShareConfirm()
end

function AegisPathfinder:AcceptShareInvite()
	local inv = share.pending
	if not inv then return false end
	share.pending = nil
	if share.active and share.guide ~= inv.guide then self:StopSharing(true) end
	if self.db.char.currentguide ~= inv.guide then
		if self.OpenGuideTab then self:OpenGuideTab(inv.guide) else self:LoadGuide(inv.guide) end
	end
	share.active, share.guide, share.bypass = true, inv.guide, nil
	share.members = { [inv.from] = { seen = GetTime() } }
	Send("ACC", inv.guide)
	Send("REQ", inv.guide)
	share.sendNow = true
	self:Print(string.format("Sharing %s with %s.", inv.guide, inv.from))
	Refresh(self)
	return true
end

function AegisPathfinder:DeclineShareInvite()
	local inv = share.pending
	if not inv then return false end
	share.pending = nil
	Send("DEC", inv.guide)
	return true
end

--[[ Messages. ]]

function AegisPathfinder:OnShareMessage(msg, sender)
	if not sender or sender == UnitName("player") then return end
	local f = Split(msg)
	local kind, guide = f[1], f[2]
	if not kind or not guide then return end

	if kind == "INV" then
		-- Party sync off (the Step Display page): no, without a popup.
		if self.db.char.partysync == false then
			Send("DEC", guide)
			return
		end
		if share.active and share.guide == guide and share.members[sender] then
			Send("ACC", guide)
			return
		end
		if not (self.guides and self.guides[guide]) then
			Send("NOG", guide)
			self:Print(string.format("%s wants to share %s, which you do not have.", sender, guide))
			return
		end
		share.pending = { from = sender, guide = guide }
		self:ShowShareInvite(sender, guide)
		return
	end

	local mine = share.active and share.guide == guide
	if kind == "ACC" then
		if not mine then return end
		share.members[sender] = share.members[sender] or { seen = GetTime() }
		share.sendNow = true
		self:Print(string.format("%s is sharing %s with you.", sender, guide))
		Refresh(self)
	elseif kind == "DEC" then
		if mine then self:Print(string.format("%s declined to share %s.", sender, guide)) end
	elseif kind == "NOG" then
		if mine then self:Print(string.format("%s does not have %s, so cannot share it.", sender, guide)) end
	elseif kind == "ST" then
		if not mine then return end
		share.members[sender] = {
			key = f[3] ~= "" and f[3] or nil,
			done = f[4] == "1",
			have = tonumber(f[5] or ""), need = tonumber(f[6] or ""),
			seen = GetTime(),
		}
		Refresh(self)
	elseif kind == "REQ" then
		if mine then share.sendNow = true; Wake() end
	elseif kind == "BYE" then
		if mine and share.members[sender] then
			share.members[sender] = nil
			self:Print(string.format("%s stopped sharing %s.", sender, guide))
			Refresh(self)
		end
	end
end

--- Whoever leaves the group leaves the share; with nobody left, it ends.
function AegisPathfinder:OnShareRosterChanged()
	if not share.active then return end
	if not Channel() then
		share.active, share.guide, share.members, share.holding, share.bypass = false, nil, {}, nil, nil
		self:Print("Your group is gone, so guide sharing has stopped.")
		Refresh(self)
		return
	end
	local here, changed = GroupNames(), false
	for name in pairs(share.members) do
		if not here[name] then share.members[name] = nil; changed = true end
	end
	if changed then Refresh(self) end
end

local events = CreateFrame("Frame")
events:RegisterEvent("CHAT_MSG_ADDON")
events:RegisterEvent("PARTY_MEMBERS_CHANGED")
events:RegisterEvent("RAID_ROSTER_UPDATE")
events:SetScript("OnEvent", function()
	if event == "CHAT_MSG_ADDON" then
		if arg1 == S.PREFIX then AegisPathfinder:OnShareMessage(arg2, arg4) end
	else
		AegisPathfinder:OnShareRosterChanged()
	end
end)
AegisPathfinder.shareEvents = events

--[[ The party icon on the step row. ]]

function AegisPathfinder:ShareHint()
	if not share.active then
		return "Share this guide with your party [BETA]", {
			"Keeps everyone on the same step and shows each other's progress under it. Your party needs Aegis: Pathfinder too.",
		}
	end
	local names = self:ShareMembers()
	if table.getn(names) == 0 then
		return "Waiting for your party to accept", { "Sharing " .. share.guide .. ". Click to stop." }
	end
	return "Sharing with " .. table.concat(names, ", "), { share.guide .. ". Click to stop sharing." }
end

function AegisPathfinder:PaintShareButton()
	local b = self.sharebutton
	if not b then return end
	-- Party sync off (the Step Display page): no party icon, and the step
	-- count takes its place.
	local count = b:GetParent() and b:GetParent().count
	if self.db.char.partysync == false then
		if b:IsShown() then
			b:Hide()
			if count then
				count:ClearAllPoints()
				count:SetPoint("RIGHT", b:GetParent(), "RIGHT", -14, 0)
			end
		end
		return
	elseif not b:IsShown() then
		b:Show()
		if count then
			count:ClearAllPoints()
			count:SetPoint("RIGHT", b, "LEFT", -6, 0)
		end
	end
	if b.hover then return end
	if not share.active then
		Theme:Tint(b.glyph, "textDim")
	elseif next(share.members) then
		Theme:Tint(b.glyph, "accent")
	else
		Theme:Tint(b.glyph, "gold")
	end
end

--- Called by the panel's builder once its step row exists.
function AegisPathfinder:AttachShareButton(navrow)
	local b = Theme:GlyphButton(navrow, "party", 13, 20)
	b:SetPoint("RIGHT", navrow, "RIGHT", -8, 0)
	b:SetScript("OnClick", function() AegisPathfinder:ToggleSharing() end)
	b:SetScript("OnEnter", function()
		this.hover = true
		Theme:Tint(this.glyph, "text")
		Theme:ShowTip(this, "BOTTOM", AegisPathfinder:ShareHint())
	end)
	b:SetScript("OnLeave", function()
		this.hover = nil
		Theme:HideTip(this)
		AegisPathfinder:PaintShareButton()
	end)
	-- The step count moves over to make room.
	if navrow.count then
		navrow.count:ClearAllPoints()
		navrow.count:SetPoint("RIGHT", b, "LEFT", -6, 0)
	end
	self.sharebutton = b
	self:PaintShareButton()
	return b
end

--[[ Members under the step. ]]

--- What one member's line says, and in which colour.
function AegisPathfinder:ShareMemberStatus(name)
	local m = share.members[name]
	if not m or not m.key then return "joining...", "textDim" end
	local pos, here = self:ShareStepIndex(m.key), self.current
	if not pos then return "on a step you do not have", "textDim" end
	if pos == here then
		if m.done then return "[done]", "accent" end
		if m.have and m.need then return string.format("[%d/%d]", m.have, m.need), "gold" end
		return "on this step", "textDim"
	end
	if pos < here then return string.format("step %d, behind", pos), "gold" end
	return string.format("step %d%s", pos, m.done and ", waiting" or ""), "textDim"
end

local function BlockLine(block, i)
	local line = block.lines[i]
	if not line then
		line = {}
		line.name = block:CreateFontString(nil, "OVERLAY")
		Theme:SetFont(line.name, "body", 11)
		line.name:SetJustifyH("LEFT")
		line.status = block:CreateFontString(nil, "OVERLAY")
		Theme:SetFont(line.status, "body2", 11)
		line.status:SetJustifyH("RIGHT")
		local y = -(4 + (i - 1) * S.LINE_H)
		line.name:SetPoint("TOPLEFT", block, "TOPLEFT", 11, y)
		line.status:SetPoint("TOPRIGHT", block, "TOPRIGHT", -11, y)
		line.name:SetPoint("RIGHT", line.status, "LEFT", -8, 0)
		block.lines[i] = line
	end
	return line
end

--- Draw the members under the step in focus mode, anchored below `anchor`
--- (the meter, or the step row). Returns true when it is showing.
function AegisPathfinder:PaintPartyBlock(frame, anchor, x)
	local block = frame.partyblock
	if not block then
		block = CreateFrame("Frame", nil, frame)
		Theme:NineSlice(block, Theme.texture.tabFill, "BACKGROUND", "text", 0.04)
		Theme:NineSlice(block, Theme.texture.tabBorder, "BORDER", "border")
		block.lines = {}
		frame.partyblock = block
	end
	local names = SharingHere(self) and not self.db.char.overviewmode and self.current and self:ShareMembers() or {}
	if table.getn(names) == 0 then
		block:Hide()
		return false
	end

	local n = 0
	if share.holding and share.holding == self.current then
		n = n + 1
		local line = BlockLine(block, n)
		line.name:SetText("Done. Waiting for your party to finish this step.")
		Theme:TextColor(line.name, "accent")
		line.status:SetText("")
	end
	for _, name in ipairs(names) do
		n = n + 1
		local line = BlockLine(block, n)
		local text, color = self:ShareMemberStatus(name)
		line.name:SetText(name)
		Theme:TextColor(line.name, "text")
		line.status:SetText(text)
		Theme:TextColor(line.status, color)
	end
	for i, line in ipairs(block.lines) do
		if i <= n then line.name:Show(); line.status:Show() else line.name:Hide(); line.status:Hide() end
	end

	block:ClearAllPoints()
	block:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x or 0, -2)
	block:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
	block:SetHeight(n * S.LINE_H + 8)
	block:Show()
	return true
end

--[[ The popups: confirming a share, and an invitation. ]]

local function Hex(name)
	local c = Theme.color[name]
	return string.format("%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5),
		math.floor(c[3] * 255 + 0.5))
end

local function Dialog(self)
	local f = share.dialog
	if f then return f end
	f = CreateFrame("Frame", "AegisPathfinderShareDialog", UIParent)
	f:SetFrameStrata("DIALOG")
	f:SetWidth(S.WIDTH)
	f:SetHeight(190)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
	Theme:Panel(f, "panel")
	Theme:Chrome(f, "Guide sharing (beta)")
	f:Hide()

	f.lines = {}
	local y = 30 + 18 + 12
	for i = 1, 4 do
		local fs = f:CreateFontString(nil, "OVERLAY")
		Theme:SetFont(fs, i == 2 and "display" or "body", i == 2 and 14 or 12)
		fs:SetWidth(S.WIDTH - 32)
		fs:SetJustifyH("CENTER")
		fs:SetPoint("TOP", f, "TOP", 0, -y)
		y = y + (i == 4 and 30 or 18)
		f.lines[i] = fs
	end

	local check = Theme:StepCheck(f, 14)
	check:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 12 + S.BUTTON_H + 10)
	check:SetScript("OnClick", function() this:SetChecked(not this.__checked) end)
	local checkLabel = f:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(checkLabel, "body", 11)
	checkLabel:SetPoint("LEFT", check, "RIGHT", 6, 0)
	checkLabel:SetText("Don't warn me again.")
	Theme:TextColor(checkLabel, "textDim")
	f.check, f.checkLabel = check, checkLabel

	local half = (S.WIDTH - 32 - 8) / 2
	local yes = Theme:PanelButton(f, "Accept", half, S.BUTTON_H)
	yes:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 12)
	local no = Theme:PanelButton(f, "Cancel", half, S.BUTTON_H)
	no:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 12)
	yes:SetScript("OnClick", function()
		local dialog = share.dialog
		if dialog.mode == "confirm" then
			if dialog.check.__checked then AegisPathfinder.db.char.sharenowarn = true end
			dialog.mode = nil
			dialog:Hide()
			AegisPathfinder:StartSharing()
		else
			dialog.mode = nil
			dialog:Hide()
			AegisPathfinder:AcceptShareInvite()
		end
	end)
	no:SetScript("OnClick", function()
		local dialog = share.dialog
		if dialog.mode == "invite" then
			dialog.mode = nil
			AegisPathfinder:DeclineShareInvite()
		end
		dialog:Hide()
	end)
	f.yes, f.no = yes, no

	-- Closing an invitation any way but Accept declines it.
	f:SetScript("OnHide", function()
		if this.mode == "invite" then AegisPathfinder:DeclineShareInvite() end
		this.mode = nil
	end)

	table.insert(UISpecialFrames, "AegisPathfinderShareDialog")
	share.dialog = f
	return f
end

function AegisPathfinder:ShowShareConfirm()
	local f = Dialog(self)
	f.mode = nil
	f:Hide()
	f.mode = "confirm"
	f.lines[1]:SetText("Do you want to start sharing the guide:")
	f.lines[2]:SetText(self.db.char.currentguide or "")
	Theme:TextColor(f.lines[2], "gold")
	f.lines[3]:SetText("with your party?")
	f.lines[4]:SetText("Note: they have to be running Aegis: Pathfinder.")
	Theme:TextColor(f.lines[1], "text")
	Theme:TextColor(f.lines[3], "text")
	Theme:TextColor(f.lines[4], "textDim")
	f.check:SetChecked(false)
	f.check:Show()
	f.checkLabel:Show()
	f.no:SetText("Cancel")
	f:Show()
	Theme:BringToFront(f)
end

function AegisPathfinder:ShowShareInvite(from, guide)
	local f = Dialog(self)
	f.mode = nil
	f:Hide()
	f.mode = "invite"
	f.lines[1]:SetText(string.format("|cff%s%s|r would like to share the following guide with you:", Hex("gold"), from))
	f.lines[2]:SetText(guide)
	Theme:TextColor(f.lines[2], "gold")
	f.lines[3]:SetText("")
	f.lines[4]:SetText("By accepting, a new tab will open in which steps from this guide will be shared with you.")
	Theme:TextColor(f.lines[1], "text")
	Theme:TextColor(f.lines[4], "textDim")
	f.check:Hide()
	f.checkLabel:Hide()
	f.no:SetText("Decline")
	f:Show()
	Theme:BringToFront(f)
end
