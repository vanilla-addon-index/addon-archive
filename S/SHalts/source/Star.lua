-------------------------------------------------------------------------------
-- One-time GitHub star ask, the same rules as AutoSpam's.
--
-- Once SHAlts has been used for STAR_HOURS hours it is due, but it only shows
-- when the player isn't busy: not in combat, a party, a raid, a battleground
-- or instance, dead, on a flight, casting, or with a vendor, bank, auction,
-- mail, trade or loot window open, and not in the first minute after logging
-- in. Until then it keeps waiting, across logins if need be. Closing it in any
-- way means it never shows again (saved account wide, and passed to your other
-- accounts through the sync file).
-------------------------------------------------------------------------------
local S = SHAlts

S.Try("Star.lua", function()

-- the SHAlts repo
S.GITHUB_URL = "https://github.com/TheRealFayz/SHalts"

local STAR_HOURS = 200          -- hours of use before the ask is due
local STAR_LOGIN_WAIT = 60      -- never show it in the first minute after logging in
local STAR_CHECK_EVERY = 5      -- seconds between "is now a good time?" checks

-- windows that mean the player is in the middle of something
local BUSY_FRAMES = {
	"MerchantFrame", "BankFrame", "AuctionFrame", "MailFrame", "TradeFrame",
	"LootFrame", "GossipFrame", "QuestFrame", "ClassTrainerFrame",
	"TradeSkillFrame", "CraftFrame", "TaxiFrame", "StaticPopup1", "StaticPopup2",
	"StaticPopup3", "StaticPopup4",
}

local loginTime = 0
local lastCheck = 0
local popup

S.On("PLAYER_LOGIN", function() loginTime = GetTime() end)

function S.IsPlayerFree()
	if UnitAffectingCombat and UnitAffectingCombat("player") then return false end
	if GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0 then return false end
	if IsInInstance and IsInInstance() then return false end
	if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return false end
	if UnitOnTaxi and UnitOnTaxi("player") then return false end
	if CastingBarFrame and CastingBarFrame:IsVisible() then return false end
	for i = 1, table.getn(BUSY_FRAMES) do
		local f = getglobal(BUSY_FRAMES[i])
		if f and f.IsVisible and f:IsVisible() then return false end
	end
	return true
end

-------------------------------------------------------------------------------
-- The popup, styled like AutoSpam's
-------------------------------------------------------------------------------
local function CreatePopup()
	local p = CreateFrame("Frame", "SHAltsStarPopup", UIParent)
	p:SetWidth(340); p:SetHeight(200)
	p:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
	p:SetFrameStrata("DIALOG")
	p:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
	})
	p:EnableMouse(true)
	p:Hide()
	table.insert(UISpecialFrames, "SHAltsStarPopup")   -- Escape closes it

	-- text starts below the corner X so the two never overlap
	p.text = p:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	p.text:SetPoint("TOP", p, "TOP", 0, -34)
	p.text:SetWidth(290)

	-- shows the link; it can be selected and copied, but typing just puts it back
	local link = CreateFrame("EditBox", "SHAltsStarLink", p, "InputBoxTemplate")
	link:SetWidth(270); link:SetHeight(20)
	link:SetAutoFocus(false)
	link:SetMaxLetters(200)
	link:SetText(S.GITHUB_URL)
	link:SetScript("OnTextChanged", function()
		if link:GetText() ~= S.GITHUB_URL then link:SetText(S.GITHUB_URL) end
	end)
	link:SetScript("OnEditFocusGained", function() link:HighlightText() end)
	link:SetScript("OnEnterPressed", function() link:ClearFocus() end)
	link:SetScript("OnEscapePressed", function() p:Hide() end)
	p.link = link

	p.note = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	p.note:SetPoint("TOP", link, "BOTTOM", 0, -6)
	p.note:SetWidth(300)

	-- close X, shown once they've copied the link
	local x = CreateFrame("Button", "SHAltsStarClose", p, "UIPanelCloseButton")
	x:SetPoint("TOPRIGHT", p, "TOPRIGHT", -5, -5)
	x:SetScript("OnClick", function() p:Hide() end)
	x:Hide()
	p.closeX = x

	local copy = CreateFrame("Button", "SHAltsStarCopy", p, "UIPanelButtonTemplate")
	copy:SetWidth(128); copy:SetHeight(22)
	copy:SetPoint("BOTTOMRIGHT", p, "BOTTOM", -6, 16)
	copy:SetText("Copy")
	copy:SetScript("OnClick", function() S.StarCopy() end)

	local no = CreateFrame("Button", "SHAltsStarNo", p, "UIPanelButtonTemplate")
	no:SetWidth(128); no:SetHeight(22)
	no:SetPoint("BOTTOMLEFT", p, "BOTTOM", 6, 16)
	no:SetText("No Thank You")
	no:SetScript("OnClick", function() p:Hide() end)

	-- However it closes (button, X, Escape), it never comes back. Only the
	-- natural one counts; /shalts star previews don't.
	p:SetScript("OnHide", function()
		if p.natural and S.db then
			S.db.starAsked = true
			S.syncDirty = true   -- let the other accounts know
		end
		p.natural = nil
		link:ClearFocus()
	end)

	p.SetBody = function(self, body)
		self.text:SetText(body)
		local h = self.text:GetHeight() or 30
		self.link:ClearAllPoints()
		self.link:SetPoint("TOP", self, "TOP", 3, -(34 + h + 12))
		self:SetHeight(h + 142)   -- room for a two line note under the link
	end

	popup = p
end

-- natural = true when shown by the hours milestone, false/nil for /shalts star
function S.ShowStarPopup(natural)
	if not popup then CreatePopup() end
	if popup:IsShown() then
		if natural then popup.natural = true end
		return
	end
	popup.natural = natural
	local hours = math.floor(((S.db and S.db.usedSeconds) or 0) / 3600)
	popup:SetBody("You've used SHAlts for over " .. hours .. " hours. If it's been useful, a star or follow on GitHub helps other players find my addons. " ..
		"This is the only time it will ask. Once you close this window it won't come up again for any of your characters.")
	popup.link:SetText(S.GITHUB_URL)
	popup.note:SetText("")
	popup.closeX:Hide()
	popup:Show()
end

function S.StarCopy()
	local p = popup
	if not p then return end
	if CopyToClipboard then
		-- some clients add a clipboard function; use it when it's there
		CopyToClipboard(S.GITHUB_URL)
		p.note:SetText("|cff33ff33Copied! Paste it into your browser and close this window with the X when you are ready. Thanks!|r")
	else
		-- stock 1.12 can't write to the clipboard, so select the link for Ctrl+C
		p.link:SetFocus()
		p.link:HighlightText()
		p.note:SetText("|cff33ff33Link selected. Press Ctrl+C to copy it, then close this window with the X when you are ready. Thanks!|r")
	end
	p.closeX:Show()
end

-------------------------------------------------------------------------------
-- Called about once a second by the scan tick with the seconds since last call
-------------------------------------------------------------------------------
function S.StarTick(dt)
	local db = S.db
	if not db or db.starAsked then return end
	db.usedSeconds = (db.usedSeconds or 0) + dt
	if db.usedSeconds < STAR_HOURS * 3600 then return end

	local now = GetTime()
	if now - lastCheck < STAR_CHECK_EVERY then return end
	lastCheck = now
	if now - loginTime < STAR_LOGIN_WAIT then return end
	if not S.IsPlayerFree() then return end
	S.ShowStarPopup(true)
end

-- hours used, for /shalts debug
function S.HoursUsed()
	return ((S.db and S.db.usedSeconds) or 0) / 3600, STAR_HOURS
end

end)
