-- Frames and drawing: options and log panels, ignore list rows, menus, pfUI skin, chat bubbles

local SS				= SI_Shared.SS
local B_NAME			= SI_Shared.B_NAME
local B_DURATION		= SI_Shared.B_DURATION
local B_REASON			= SI_Shared.B_REASON
local T_Time			= SI_Shared.T_Time
local T_Time_TextOpt	= SI_Shared.T_Time_TextOpt

------------- pfUI Skin

-- pfUI api table while pfUI skinning is active, nil otherwise
SI_PF = nil
-- Every skinnable widget, so the skin can be applied whenever pfUI becomes ready
SI_SkinWidgets = {}

-- Use pfUI's palette (including its class color overrides) for our accents.
local skinAccentColor = function()
	if SI_PF and SI_PF.GetUnitColor then
		local _, r, g, b = SI_PF.GetUnitColor("player")
		return r, g, b
	end
	local _, class = UnitClass("player")
	local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if color then return color.r, color.g, color.b end
	return 1, .82, 0
end

local skinApply = function(w)
	local kind, obj = w[1], w[2]
	if kind == "frame" then
		local _, border = SI_PF.GetBorderSize()
		local parent = w[3]
		local anchor = (parent == IgnoreListFrame and FriendsFrame.backdrop) or parent.backdrop or parent
		obj:SetBackdrop(nil)
		SI_PF.CreateBackdrop(obj, nil, nil, .75)
		SI_PF.CreateBackdropShadow(obj)
		obj:ClearAllPoints()
		obj:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 2 * border + 2, anchor == parent and 0 or -border)
	elseif kind == "window" then
		obj:SetBackdrop(nil)
		SI_PF.CreateBackdrop(obj, nil, nil, .75)
		SI_PF.CreateBackdropShadow(obj)
	elseif kind == "editbox" then
		obj:SetBackdrop(nil)
		SI_PF.CreateBackdrop(obj)
		if SI_PF.SetHighlight then SI_PF.SetHighlight(obj) end
	elseif kind == "font" then
		obj:SetFont(pfUI.font_default, w[3] or pfUI_config.global.font_size, "OUTLINE")
	elseif kind == "accenttexture" then
		obj:SetVertexColor(skinAccentColor())
	elseif kind == "checkbox" then
		SI_PF.SkinCheckbox(obj)
	elseif kind == "button" then
		SI_PF.SkinButton(obj)
	elseif kind == "dropdown" then
		SI_PF.SkinDropDown(obj, nil, nil, nil, true)
	elseif kind == "close" then
		SI_PF.SkinCloseButton(obj, obj:GetParent().backdrop, -6, -6)
	elseif kind == "scroll" then
		SI_PF.SkinScrollbar(getglobal(obj:GetName() .. "ScrollBar"))
	end
end

-- kind: frame (arg = parent), window (keeps its position), font
-- (arg = font size), accenttexture, editbox, checkbox, button, dropdown, scroll
SI_Skin = function(kind, obj, arg)
	local w = {kind, obj, arg}
	table.insert(SI_SkinWidgets, w)
	if SI_PF then skinApply(w) end
end

local skinActivate = function()
	if SI_PF then return end
	SI_PF = pfUI.api
	for _, w in pairs(SI_SkinWidgets) do
		skinApply(w)
	end
	if SI_OptionsFrame then SI_OptionsFrameUpdateWidth() end
	if IgnoreListFrame:IsVisible() then SI_SkinPlaceShowButton(SI_OpenButton) end
end

-- Safe to call repeatedly; pfUI may load before or after SuperIgnore
SI_SkinDetect = function()
	if SI_PF or not (pfUI and pfUI.api and pfUI.api.CreateBackdrop and pfUI.RegisterSkin and pfUI_config) then return end
	-- Registered as a pfUI skin so it can be toggled in pfUI's settings
	if pfUI_config.disabled and pfUI_config.disabled["skin_SuperIgnore"] == "1" then return end
	-- Registered once; pfUI calls it when ready
	if SI_SkinRegistered then return end
	SI_SkinRegistered = true
	-- Runs immediately if pfUI finished booting, otherwise once it does.
	-- pfUI setfenv()s skin functions into its own environment, so only call through an upvalue here.
	pfUI:RegisterSkin("SuperIgnore", function() skinActivate() end)
end

-- Aligns the SuperIgnore toggle with pfUI's relocated ignore list tabs/buttons
SI_SkinPlaceShowButton = function(b)
	if not (SI_PF and b and FriendsFrame.backdrop and IgnoreFrameToggleTab1 and FriendsFrameStopIgnoreButton) then return end
	local right, top = FriendsFrameStopIgnoreButton:GetRight(), IgnoreFrameToggleTab1:GetTop()
	local left, ptop = IgnoreListFrame:GetLeft(), IgnoreListFrame:GetTop()
	if not (right and top and left and ptop) then return end
	b:SetHeight(IgnoreFrameToggleTab1:GetHeight())
	b:ClearAllPoints()
	b:SetPoint("TOPRIGHT", IgnoreListFrame, "TOPLEFT", right - left, top - ptop)
end

------------- GUI Misc

SI_FrameCreateFrame = function(name, width, parent, x, y)
	local f = CreateFrame("Frame", name, parent)

	f:SetWidth(width)
	f:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", tile = true, tileSize = 32,
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,
		insets = {left = 4, right = 4, top = 4, bottom = 4},
	})
	f:SetPoint("TOPLEFT", parent, "TOPRIGHT", x, y)
	f:Hide()
	SI_Skin("frame", f, parent)

	return f
end

SI_FrameCreateHeader = function(frame, text, fontSize, pad)
	local t = frame:CreateFontString(nil, "OVERLAY", frame)
	t:SetPoint("TOP", frame, "TOP", 0, pad)
	t:SetFont("Fonts\\FRIZQT__.TTF", fontSize)
	t:SetTextColor(1,0.82,0)
	SI_Skin("font", t, fontSize)
	t:SetText(text)
	return t
end

SI_FrameCreateCheckbox = function(name, frame, x, pad, desc)
	local c = CreateFrame("CheckButton", name, frame, "UICheckButtonTemplate")
	c:SetHeight(20)
	c:SetWidth(20)
	c:SetPoint("TOPLEFT", frame, "TOPLEFT", x, pad)
	SI_Skin("checkbox", c)

	local ct = frame:CreateFontString(nil, "OVERLAY", frame)
	ct:SetPoint("LEFT", c, "RIGHT", 0, 0)
	ct:SetFont("Fonts\\FRIZQT__.TTF", 11)
	SI_Skin("font", ct)
	ct:SetText(desc)

	return c, ct
end

SI_FrameCreateOption = function(frame, name, desc, pad, onclick)
	local c, ct = SI_FrameCreateCheckbox(name, frame, 15, pad, desc)
	c:SetScript("OnClick", function()
		onclick(c:GetChecked())
	end)

	return c, ct
end

-- Small panel button, e.g. the Copy buttons
SI_FrameCreateButton = function(name, parent, text, width, point, x, y, onclick)
	local b = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
	b:SetHeight(20)
	b:SetWidth(width)
	b:SetPoint(point, parent, point, x, y)
	b:SetText(text)
	b:SetScript("OnClick", onclick)
	SI_Skin("button", b)
	return b
end

-- Scrolling list of lines for log panels; it remembers its lines for the Copy window.
-- Use :AddLine(text, r, g, b), :ClearLines() and :GetAllText() instead of AddMessage/Clear.
SI_FrameCreateLog = function(name, parent, bottom, maxLines)
	local msgs = CreateFrame("ScrollingMessageFrame", name, parent)
	msgs:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, -50)
	msgs:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -15, bottom)
	msgs:SetFontObject(GameFontHighlightSmall)
	msgs:SetJustifyH("LEFT")
	msgs:SetMaxLines(maxLines)
	msgs:SetFading(false)
	msgs:EnableMouseWheel(true)
	msgs:SetScript("OnMouseWheel", function()
		if arg1 > 0 then msgs:ScrollUp() else msgs:ScrollDown() end
	end)

	msgs.lines = {}
	msgs.AddLine = function(self, text, r, g, b)
		table.insert(self.lines, text)
		if table.getn(self.lines) > maxLines then
			table.remove(self.lines, 1)
		end
		self:AddMessage(text, r, g, b)
	end
	msgs.ClearLines = function(self)
		self.lines = {}
		self:Clear()
	end
	msgs.GetAllText = function(self)
		return table.concat(self.lines, "\n")
	end
	return msgs
end

------------- Copy Window

-- Colors and link codes removed, link names kept: "|cff..|Hitem:..|h[Name]|h|r" -> "[Name]"
local plainText = function(text)
	text = string.gsub(text, "|H.-|h(.-)|h", "%1")
	text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
	return (string.gsub(text, "|r", ""))
end

local copyFrame = nil

local createCopyFrame = function()
	local f = CreateFrame("Frame", "SI_CopyFrame", UIParent)
	f:SetWidth(420)
	f:SetHeight(320)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	f:SetFrameStrata("DIALOG")
	f:EnableMouse(true)
	f:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", tile = true, tileSize = 32,
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		insets = {left = 11, right = 12, top = 12, bottom = 11},
	})
	f:Hide()
	SI_Skin("window", f)
	-- Escape closes it even when the text box doesn't have focus
	table.insert(UISpecialFrames, "SI_CopyFrame")

	f.title = SI_FrameCreateHeader(f, "", 12, -15)
	local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("TOP", f, "TOP", 0, -32)
	hint:SetText("All text is selected: press Ctrl+C to copy")

	local close = CreateFrame("Button", "SI_CopyFrameClose", f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
	SI_Skin("close", close)

	local scroll = CreateFrame("ScrollFrame", "SI_CopyFrameScroll", f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -50)
	scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -37, 15)
	SI_Skin("scroll", scroll)

	local box = CreateFrame("EditBox", "SI_CopyFrameBox", scroll)
	box:SetMultiLine(true)
	box:SetAutoFocus(false)
	box:SetFontObject(GameFontHighlightSmall)
	box:SetWidth(360)
	box:SetHeight(250)
	box:SetScript("OnEscapePressed", function() f:Hide() end)
	-- Read-only: any edit is undone, keeping everything selected for copying
	box:SetScript("OnTextChanged", function()
		if this:GetText() ~= f.text then
			this:SetText(f.text)
			this:HighlightText()
		end
		ScrollingEdit_OnTextChanged(scroll)
	end)
	box:SetScript("OnCursorChanged", function()
		ScrollingEdit_OnCursorChanged(arg1, arg2, arg3, arg4)
	end)
	box:SetScript("OnUpdate", function()
		ScrollingEdit_OnUpdate(scroll)
	end)
	scroll:SetScrollChild(box)

	f.box = box
	return f
end

-- Shows text in a window, selected and ready for Ctrl+C
SI_ShowCopyText = function(title, text)
	if not copyFrame then
		copyFrame = createCopyFrame()
	end
	copyFrame.title:SetText(title)
	copyFrame.text = plainText(text)
	copyFrame:Show()
	copyFrame.box:SetText(copyFrame.text)
	copyFrame.box:SetFocus()
	copyFrame.box:HighlightText()
end

------------- Mods

-- Mod panels share one spot next to the options panel, so only one is shown at a time
local shownModPanel = nil

SI_ToggleModPanel = function(panel)
	if panel:IsShown() then
		panel:Hide()
		return
	end
	if shownModPanel and shownModPanel ~= panel then
		shownModPanel:Hide()
	end
	shownModPanel = panel
	panel:Show()
end

-- A mod's row (checkbox, tooltip, Edit button) in the options panel
SI_CreateModUI = function(index, mod)
	local f = SI_OptionsContentFrame

	if index == 1 then
		SI_OptionsFramePad = SI_OptionsFramePad - 5
		SI_FrameCreateHeader(f, SS.TextModules, 11, SI_OptionsFramePad)
		SI_OptionsFramePad = SI_OptionsFramePad - 15
	end

	local c, ct = SI_FrameCreateCheckbox("SI_ModEnable_"..index, f, 15, SI_OptionsFramePad, mod.Name)
	c:SetScript("OnClick", function()
		local checked = c:GetChecked()
		if checked then SI_ModEnable(index) else SI_ModDisable(index) end
	end)
	c:SetChecked(SI_Global.Mods[mod.Name].Enabled)
	-- Leave room for the Edit button
	SI_OptionsFrameAddLabel(ct, mod.OnEdit and 45 or 0)

	if mod.Description then
		c:SetScript("OnEnter", function()
			GameTooltip:SetOwner(c, "ANCHOR_RIGHT")
			GameTooltip:SetText(mod.Name)
			GameTooltip:AddLine(mod.Description, 1, 1, 1, 1)
			if mod.Help then
				GameTooltip:AddLine(mod.Help, .8, .8, .8, 1)
			end
			GameTooltip:Show()
		end)
		c:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	end

	if mod.CreateUI then
		mod.CreateUI(SI_OptionsFrame)
	end

	if mod.OnEdit then
		local b = CreateFrame("Button", "SI_ModEdit_"..index, f, "UIPanelButtonTemplate")
		b:SetHeight(18)
		b:SetWidth(40)
		b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, SI_OptionsFramePad - 1)
		b:SetText(mod.EditText)
		b:SetScript("OnClick", mod.OnEdit)
		SI_Skin("button", b)
	end

	SI_OptionsFramePad = SI_OptionsFramePad - 15
	SI_OptionsFrameUpdateHeight()
end

------------- Chat Bubbles

-- Bubbles are drawn by the client and don't know the sender, so a blocked message's
-- text is looked for among new bubbles (unnamed WorldFrame children) for a moment, and
-- the first bubble showing it is made invisible. Hidden bubbles are tracked because the
-- client recycles them.
local BUBBLE_TYPES = { SAY = true, YELL = true, PARTY = true }
local BUBBLE_DETECT = 1

local bubbleTexts = {}		-- text -> time until which a bubble with it is looked for
local bubbleHidden = {}		-- frame -> text it was hidden for
local bubbleFonts = {}		-- frame -> its FontString, or false; cached, bubbles are reused
local worldKids = {}		-- cached WorldFrame children, refreshed when their number changes
local worldKidCount = -1
local bubbleFrame = CreateFrame("Frame")
bubbleFrame:Hide()

local bubbleGetText = function(frame)
	local font = bubbleFonts[frame]
	if font == nil then
		font = false
		local regions = { frame:GetRegions() }
		for i = 1, table.getn(regions) do
			if regions[i]:GetObjectType() == "FontString" then
				font = regions[i]
				break
			end
		end
		bubbleFonts[frame] = font
	end
	return font and font:GetText()
end

bubbleFrame:SetScript("OnUpdate", function()
	local now = GetTime()
	local active = false

	for text, expiry in pairs(bubbleTexts) do
		if expiry < now then
			bubbleTexts[text] = nil
		else
			active = true
		end
	end

	-- Keep hidden bubbles invisible, give recycled ones their alpha back
	for frame, text in pairs(bubbleHidden) do
		if frame:IsShown() and bubbleGetText(frame) == text then
			frame:SetAlpha(0)
			active = true
		else
			frame:SetAlpha(1)
			bubbleHidden[frame] = nil
		end
	end

	if next(bubbleTexts) then
		local count = WorldFrame:GetNumChildren()
		if count ~= worldKidCount then
			worldKids = { WorldFrame:GetChildren() }
			worldKidCount = count
		end
		for i = 1, count do
			local frame = worldKids[i]
			if not bubbleHidden[frame] and not frame:GetName() and frame:IsShown() then
				local text = bubbleGetText(frame)
				if text and bubbleTexts[text] then
					frame:SetAlpha(0)
					bubbleHidden[frame] = text
					-- One bubble per message, so others saying the same stay visible
					bubbleTexts[text] = nil
					active = true
				end
			end
		end
	end

	if not active then
		this:Hide()
	end
end)

SI_BubbleBlock = function(chatType, text)
	if not BUBBLE_TYPES[chatType] then return end
	bubbleTexts[text] = GetTime() + BUBBLE_DETECT
	bubbleFrame:Show()
end

------------- Ignore List Rows

-- The row's name text, which lives on the row's "$parentButtonText" child frame
local ignoreRowNameText = function(button)
	return getglobal(button:GetName() .. "ButtonTextName")
end

-- Offset from the row's right edge that mirrors the name's left padding.
-- pfUI: measured between the Friends/Ignore tabs (left) and the SuperIgnore button (right).
-- Default UI: the tabs are centered, not edge-aligned, so mirror the padding within the row itself.
local ignoreRowRightOffset = function(button)
	local nameText = ignoreRowNameText(button)
	local textLeft = nameText and nameText:GetLeft()
	local rowLeft, rowRight = button:GetLeft(), button:GetRight()
	if not (textLeft and rowLeft and rowRight) then
		return nil
	end
	local rightEdge, padding
	if SI_PF then
		local leftEdge = IgnoreFrameToggleTab1 and IgnoreFrameToggleTab1:GetLeft()
		rightEdge = SI_OpenButton and SI_OpenButton:GetRight()
		if not (leftEdge and rightEdge) then
			return nil
		end
		padding = textLeft - leftEdge
	else
		rightEdge, padding = rowRight, textLeft - rowLeft
	end

	-- With more than a screen of entries the scrollbar shows: keep the same padding
	-- from its left edge instead, so it never covers the log icon
	local bar = FriendsFrameIgnoreScrollFrame and FriendsFrameIgnoreScrollFrame:IsShown()
		and FriendsFrameIgnoreScrollFrameScrollBar
	local barLeft = bar and bar:GetLeft()
	if barLeft and barLeft < rightEdge then
		rightEdge = barLeft
	end

	return (rightEdge - padding) - rowRight
end

-- Friends list style "Name - Reason"; the reason is cut with "..." so the row text
-- ends before the duration column
local ignoreRowFitText = function(nameText, banned, duration)
	local name, reason = banned[B_NAME], banned[B_REASON]
	local textLeft, durationLeft = nameText:GetLeft(), duration:GetLeft()
	if not reason then return true end
	nameText:SetText(name .. " |cff808080- " .. reason .. "|r")
	if not (textLeft and durationLeft) then return false end

	local maxWidth = durationLeft - 8 - textLeft
	if nameText:GetStringWidth() <= maxWidth then return true end

	local len = string.len(reason)
	while len > 0 do
		len = len - 1
		-- Never cut inside a UTF-8 character (continuation bytes are 128-191)
		local b = string.byte(reason, len + 1)
		while len > 0 and b >= 128 and b < 192 do
			len = len - 1
			b = string.byte(reason, len + 1)
		end
		local cut = string.gsub(string.sub(reason, 1, len), "%s+$", "")
		nameText:SetText(name .. " |cff808080- " .. cut .. "...|r")
		if nameText:GetStringWidth() <= maxWidth then return true end
	end
	nameText:SetText(name)
	return true
end

-- Positions aren't always resolved on the frame a list first shows; retry a few frames later
local ignoreRowRetries = 0
local ignoreRowRetry = CreateFrame("Frame")
ignoreRowRetry:Hide()
ignoreRowRetry:SetScript("OnUpdate", function()
	this:Hide()
	IgnoreList_Update()
end)

-- Right-aligned, dimmed duration on each ignore list row
SI_IgnoreList_Update_Old = nil
SI_IgnoreList_Update_New = function()
	-- Section headings exist only while drawing. Public ignore APIs still return
	-- real players, and clickable rows retain their real saved-list indices.
	SI_IgnoreListRows = {}
	for section = 1, 2 do
		local soft = section == 2
		local count = 0
		local heading = {title = soft and SS.SectionSoft or SS.SectionFull}
		table.insert(SI_IgnoreListRows, heading)
		for index = 1, table.getn(SI_RealmSpecific.BannedPlayers) do
			if SI_BannedIsSoft(index) == soft then
				table.insert(SI_IgnoreListRows, {index = index})
				count = count + 1
			end
		end
		heading.title = heading.title .. " (" .. count .. ")"
	end
	if not SI_RealmSpecific.BannedPlayers[SI_RealmSpecific.BannedSelected] then
		SI_RealmSpecific.BannedSelected = table.getn(SI_RealmSpecific.BannedPlayers) > 0 and 1 or 0
	end
	-- Always run the stock update: it also hides the scrollbar (shown by default), and the
	-- default UI calls it just before showing the list
	SI_IgnoreListRendering = true
	SI_IgnoreList_Update_Old()
	SI_IgnoreListRendering = nil
	-- Stop Ignore reads this field directly, outside the drawing context.
	FriendsFrame.selectedIgnore = SI_RealmSpecific.BannedSelected
	if FriendsFrame.selectedIgnore == 0 then FriendsFrameStopIgnoreButton:Disable() end
	-- Our row extras only while visible; the list redraws itself when shown (SI_CreateFrames)
	if not IgnoreListFrame:IsVisible() then return end
	local unmeasured = false

	for i = 1, IGNORES_TO_DISPLAY do
		local button = getglobal("FriendsFrameIgnoreButton" .. i)
		if button then
			if not button.siDuration then
				local log = CreateFrame("Button", nil, button)
				log:SetWidth(14)
				log:SetHeight(14)
				log:SetFrameLevel(button:GetFrameLevel() + 2)
				log:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
				log:SetHighlightTexture("Interface\\Buttons\\GlowStar", "ADD")
				SI_Skin("accenttexture", log:GetHighlightTexture())
				log:SetScript("OnEnter", function() this:SetAlpha(1) end)
				log:SetScript("OnLeave", function() this:SetAlpha(this.alpha) end)
				log:SetScript("OnClick", function() SI_LogFrameShow(this.name) end)
				button.siLog = log

				button.siDuration = button:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
				button.siDuration:SetPoint("RIGHT", log, "LEFT", -4, 0)
				button.siDuration:SetJustifyH("RIGHT")
				-- Separate header widgets keep their typography out of player rows
				-- when the stock scrolling list reuses the same buttons.
				button.siHeading = button:CreateFontString(nil, "OVERLAY")
				button.siHeading:SetPoint("CENTER", button, "CENTER", 0, 0)
				local _, entryFontSize = ignoreRowNameText(button):GetFont()
				button.siHeading:SetFont("Fonts\\FRIZQT__.TTF", entryFontSize or 12, "OUTLINE")
				button.siHeading:SetTextColor(1, .82, 0)
				SI_Skin("font", button.siHeading)
				button.siHeadingBand = button:CreateTexture(nil, "BACKGROUND")
				button.siHeadingBand:SetAllPoints(button)
				button.siHeadingBand:SetTexture(1, 1, 1, .03)
			end
			local row = SI_IgnoreListRows[button:GetID()]
			local index = row and row.index
			local banned = index and SI_RealmSpecific.BannedPlayers[index]
			button:SetID(index or 0)
			button:EnableMouse(index and true or false)
			local text = ignoreRowNameText(button)
			if row and row.title then
				if text then text:Hide() end
				button.siHeading:SetText(row.title)
				button.siHeading:Show()
				button.siHeadingBand:Show()
			else
				if text then text:Show() end
				button.siHeading:Hide()
				button.siHeadingBand:Hide()
			end

			local offset = ignoreRowRightOffset(button)
			if not offset then
				offset = -8
				if banned then unmeasured = true end
			end
			button.siLog:ClearAllPoints()
			button.siLog:SetPoint("RIGHT", button, "RIGHT", offset, 0)
			button.siDuration:SetText(banned and SI_FormatTimeNoColor(banned[B_DURATION]) or "")
			if banned then
				local log = button.siLog
				log.name = banned[B_NAME]
				-- Dim and grey when empty, full color when something was blocked
				if SI_LogHasName(log.name) then
					log.alpha = 1
					log:GetNormalTexture():SetVertexColor(1, 1, 1)
				else
					log.alpha = .35
					log:GetNormalTexture():SetVertexColor(.6, .6, .6)
				end
				if not MouseIsOver(log) then log:SetAlpha(log.alpha) end
				log:Show()

				local nameText = ignoreRowNameText(button)
				if nameText and not ignoreRowFitText(nameText, banned, button.siDuration) then
					unmeasured = true
				end
			else
				button.siLog:Hide()
			end
		end
	end

	if unmeasured and ignoreRowRetries < 5 and IgnoreListFrame:IsVisible() then
		ignoreRowRetries = ignoreRowRetries + 1
		ignoreRowRetry:Show()
	elseif not unmeasured then
		ignoreRowRetries = 0
	end
end

------------- Right-Click Menu

-- A separate window uses the same skin registry as the main panels, including
-- when pfUI becomes ready after this window was created.
local ignorePrompt

SI_ShowIgnorePrompt = function(name, reason)
	if not ignorePrompt then
		local f = CreateFrame("Frame", "SI_IgnorePrompt", UIParent)
		f:SetWidth(280)
		f:SetHeight(182)
		f:SetPoint("TOP", UIParent, "TOP", 0, -128)
		f:SetFrameStrata("DIALOG")
		f:EnableMouse(true)
		f:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", tile = true, tileSize = 32,
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			insets = {left = 11, right = 12, top = 12, bottom = 11},
		})
		f:Hide()
		SI_Skin("window", f)
		table.insert(UISpecialFrames, "SI_IgnorePrompt")
		f.title = SI_FrameCreateHeader(f, "", 12, -14)
		local playerLabel = SI_FrameCreateHeader(f, SS.PopupPlayerLabel, 11, -14)
		playerLabel:ClearAllPoints()
		playerLabel:SetPoint("LEFT", f, "TOPLEFT", 18, -46)
		local nameBox = CreateFrame("EditBox", "SI_IgnorePromptName", f)
		nameBox:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, -36)
		nameBox:SetWidth(184)
		nameBox:SetHeight(20)
		nameBox:SetAutoFocus(false)
		nameBox:SetMaxLetters(48)
		nameBox:SetFontObject(GameFontHighlightSmall)
		SI_Skin("font", nameBox)
		nameBox:SetTextInsets(6, 6, 0, 0)
		nameBox:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
			insets = {left = 3, right = 3, top = 3, bottom = 3},
		})
		nameBox:SetBackdropColor(0, 0, 0, .5)
		SI_Skin("editbox", nameBox)
		f.nameBox, f.playerLabel = nameBox, playerLabel
		local full = SI_FrameCreateButton("SI_IgnorePromptFull", f, SS.ModeFull, 110, "TOPLEFT", 18, -36,
			function()
				f.soft = false
				f.full:SetText("[" .. SS.ModeFull .. "]")
				f.softButton:SetText(SS.ModeSoft)
			end)
		local soft = SI_FrameCreateButton("SI_IgnorePromptSoft", f, SS.ModeSoft, 110, "TOPRIGHT", -18, -36,
			function()
				f.soft = true
				f.full:SetText(SS.ModeFull)
				f.softButton:SetText("[" .. SS.ModeSoft .. "]")
			end)
		f.full, f.softButton = full, soft
		local durationLabel = SI_FrameCreateHeader(f, SS.PopupDuration, 11, -45)
		f.durationLabel = durationLabel
		durationLabel:ClearAllPoints()
		durationLabel:SetPoint("LEFT", f, "TOPLEFT", 18, -76)
		local dd = CreateFrame("Button", "SI_IgnorePromptDuration", f, "UIDropDownMenuTemplate")
		dd:SetPoint("TOPLEFT", f, "TOPLEFT", 80, -62)
		UIDropDownMenu_SetWidth(140, dd)
		UIDropDownMenu_JustifyText("LEFT", dd)
		UIDropDownMenu_Initialize(dd, function()
			for i = 1, table.getn(T_Time_TextOpt) do
				local option = i
				local info = {}
				info.text = T_Time_TextOpt[i]
				info.value = i
				info.checked = f.option == i
				info.func = function()
					f.option = option
					UIDropDownMenu_SetSelectedID(dd, option)
					UIDropDownMenu_SetText(T_Time_TextOpt[option], dd)
				end
				UIDropDownMenu_AddButton(info, 1)
			end
		end)
		SI_Skin("dropdown", dd)
		f.reasonLabel = SI_FrameCreateHeader(f, SS.PopupReasonLabel, 11, -104)
		local box = CreateFrame("EditBox", "SI_IgnorePromptReason", f)
		box:SetPoint("TOP", f, "TOP", 0, -120)
		box:SetWidth(244)
		box:SetHeight(22)
		box:SetAutoFocus(false)
		box:SetMaxLetters(64)
		box:SetFontObject(GameFontHighlightSmall)
		SI_Skin("font", box)
		box:SetTextInsets(6, 6, 0, 0)
		box:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
			insets = {left = 3, right = 3, top = 3, bottom = 3},
		})
		box:SetBackdropColor(0, 0, 0, .5)
		SI_Skin("editbox", box)
		local accept = function()
			local target, option, text, soft = f.target, f.option, box:GetText(), f.soft
			if not target then
				target = string.gsub(nameBox:GetText(), "^%s*(.-)%s*$", "%1")
				if target == "" then nameBox:SetFocus(); return end
				target = SI_FixPlayerName(target)
				if target == UnitName("player") then
					SI_Print(SS.ChatSelf)
					nameBox:SetFocus()
					return
				end
			end
			f:Hide()
			if not target then return end
			text = string.gsub(string.gsub(text, "^%s+", ""), "%s+$", "")
			SI_AddIgnore_New(target, false, SI_CalcBanTime(option), text ~= "" and text or nil, soft, option)
		end
		box:SetScript("OnEnterPressed", accept)
		box:SetScript("OnEscapePressed", function() f:Hide() end)
		nameBox:SetScript("OnEnterPressed", function() nameBox:ClearFocus(); box:SetFocus() end)
		nameBox:SetScript("OnTabPressed", function() nameBox:ClearFocus(); box:SetFocus() end)
		nameBox:SetScript("OnEscapePressed", function() f:Hide() end)
		f:SetScript("OnHide", function()
			box:ClearFocus()
			nameBox:ClearFocus()
			f.target = nil
			CloseDropDownMenus()
		end)
		SI_FrameCreateButton("SI_IgnorePromptAccept", f, TEXT(ACCEPT), 110, "BOTTOMLEFT", 18, 14, accept)
		SI_FrameCreateButton("SI_IgnorePromptCancel", f, TEXT(CANCEL), 110, "BOTTOMRIGHT", -18, 14,
			function() f:Hide() end)
		f.box, f.dropdown = box, dd
		ignorePrompt = f
	end
	CloseDropDownMenus()
	ignorePrompt.target = name
	ignorePrompt.option = SI_Shared.T_FOREVER
	ignorePrompt.soft = false
	ignorePrompt.full:SetText("[" .. SS.ModeFull .. "]")
	ignorePrompt.softButton:SetText(SS.ModeSoft)
	if name then
		ignorePrompt.nameBox:Hide()
		ignorePrompt.playerLabel:Hide()
		ignorePrompt.title:SetText(string.format(SS.PopupIgnore, name))
	else
		ignorePrompt.title:SetText(SS.PopupIgnorePlayer)
		ignorePrompt.nameBox:SetText("")
		ignorePrompt.nameBox:Show()
		ignorePrompt.playerLabel:Show()
	end
	ignorePrompt.title:Show()
	-- Leave room for the name row only when the player must be entered.
	local extra = name and 0 or 28
	ignorePrompt:SetHeight(182 + extra)
	ignorePrompt.full:ClearAllPoints()
	ignorePrompt.full:SetPoint("TOPLEFT", ignorePrompt, "TOPLEFT", 18, -36 - extra)
	ignorePrompt.softButton:ClearAllPoints()
	ignorePrompt.softButton:SetPoint("TOPRIGHT", ignorePrompt, "TOPRIGHT", -18, -36 - extra)
	ignorePrompt.durationLabel:ClearAllPoints()
	ignorePrompt.durationLabel:SetPoint("LEFT", ignorePrompt, "TOPLEFT", 18, -76 - extra)
	ignorePrompt.dropdown:ClearAllPoints()
	ignorePrompt.dropdown:SetPoint("TOPLEFT", ignorePrompt, "TOPLEFT", 80, -62 - extra)
	ignorePrompt.reasonLabel:ClearAllPoints()
	ignorePrompt.reasonLabel:SetPoint("TOP", ignorePrompt, "TOP", 0, -104 - extra)
	ignorePrompt.box:ClearAllPoints()
	ignorePrompt.box:SetPoint("TOP", ignorePrompt, "TOP", 0, -120 - extra)
	UIDropDownMenu_SetSelectedID(ignorePrompt.dropdown, ignorePrompt.option)
	-- Vanilla dropdowns share menu rows with the player context menu. Set the
	-- caption explicitly so a stale row cannot supply "Ignore Player" here.
	UIDropDownMenu_SetText(T_Time_TextOpt[ignorePrompt.option], ignorePrompt.dropdown)
	ignorePrompt.box:SetText(reason or "")
	ignorePrompt:Show()
	ignorePrompt.box:ClearFocus()
	ignorePrompt.nameBox:ClearFocus()
	local focus = name and ignorePrompt.box or ignorePrompt.nameBox
	focus:SetFocus()
	focus:HighlightText()
end

-- Player whose reason is being edited, and the popup doing it
SI_ReasonTarget = nil
SI_ReasonDialog = nil

StaticPopupDialogs["SI_SetReason"] = {
	text = SS.PopupReason,
	button1 = TEXT(ACCEPT),
	button2 = TEXT(CANCEL),
	hasEditBox = 1,
	maxLetters = 64,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	OnShow = function()
		local box = getglobal(this:GetName() .. "EditBox")
		local index = SI_BannedGetIndex(SI_ReasonTarget)
		box:SetText(index and SI_BannedGetReason(index) or "")
		box:HighlightText()
		box:SetFocus()
	end,
	OnAccept = function()
		if SI_ReasonDialog then
			SI_BannedChangeReason(SI_ReasonTarget, getglobal(SI_ReasonDialog:GetName() .. "EditBox"):GetText())
		end
	end,
	EditBoxOnEnterPressed = function()
		SI_BannedChangeReason(SI_ReasonTarget, this:GetText())
		this:GetParent():Hide()
	end,
	EditBoxOnEscapePressed = function()
		this:GetParent():Hide()
	end,
}

local rightClickName = nil

local rightClickMenuInit = function()
	local name = rightClickName
	local index = name and SI_BannedGetIndex(name)
	if not index then return end
	local info

	if UIDROPDOWNMENU_MENU_LEVEL == 2 then
		local current = SI_BannedGetDuration(index)
		local currentOption = SI_BannedGetOption(index)
		for i = 1, table.getn(T_Time_TextOpt) do
			local option = i
			info = {}
			info.text = T_Time_TextOpt[i]
			-- Entries from older versions have no option; their special durations still match
			info.checked = currentOption == i or (SI_IsTimeSpecial(T_Time[i]) and current == T_Time[i])
			info.func = function()
				SI_BannedChangeDuration(name, option)
				CloseDropDownMenus()
			end
			UIDropDownMenu_AddButton(info, 2)
		end
		return
	end

	info = {}
	info.text = name
	info.isTitle = 1
	info.notCheckable = 1
	UIDropDownMenu_AddButton(info)

	info = {}
	info.text = SS.MenuDuration
	info.hasArrow = 1
	info.value = "SI_DURATION"
	info.notCheckable = 1
	UIDropDownMenu_AddButton(info)

	info = {}
	info.text = SI_BannedIsSoft(index) and SS.MenuMakeFull or SS.MenuMakeSoft
	info.notCheckable = 1
	info.func = function()
		SI_BannedChangeMode(name, not SI_BannedIsSoft(index))
		CloseDropDownMenus()
	end
	UIDropDownMenu_AddButton(info)

	info = {}
	info.text = SS.MenuReason
	info.notCheckable = 1
	info.func = function()
		SI_ReasonTarget = name
		SI_ReasonDialog = StaticPopup_Show("SI_SetReason", name)
	end
	UIDropDownMenu_AddButton(info)

	info = {}
	info.text = SS.MenuUnignore
	info.notCheckable = 1
	info.func = function()
		SI_DelIgnore_New(name)
	end
	UIDropDownMenu_AddButton(info)

	info = {}
	info.text = TEXT(CANCEL)
	info.notCheckable = 1
	info.func = function() CloseDropDownMenus() end
	UIDropDownMenu_AddButton(info)
end

SI_RightClickMenu = function(index)
	if not SI_RealmSpecific.BannedPlayers[index] then return end
	rightClickName = SI_BannedGetName(index)

	SI_RealmSpecific.BannedSelected = index
	IgnoreList_Update()

	if not SI_IgnoreMenu then
		CreateFrame("Frame", "SI_IgnoreMenu", UIParent, "UIDropDownMenuTemplate")
	end
	UIDropDownMenu_Initialize(SI_IgnoreMenu, rightClickMenuInit, "MENU")
	ToggleDropDownMenu(1, nil, SI_IgnoreMenu, "cursor")
end

------------- Frames


SI_CreateOptionsFrame = function()

	-- Height set at function end
	SI_OptionsFrame = SI_FrameCreateFrame("SI_OptionsFrame", 185, IgnoreListFrame, -34, -7)
	-- Keep content clear of Classic's thin panel border.
	SI_OptionsContentFrame = CreateFrame("Frame", "SI_OptionsContentFrame", SI_OptionsFrame)
	local f = SI_OptionsContentFrame

	local pad = 0

	local createOpt = function(index, var, desc, padding, onclick)
		local c, ct = SI_FrameCreateOption(f, "SI_Box_"..index, desc, padding, function(checked)
			SI_Global[var] = checked and true or false
			if onclick then onclick(checked) end
		end)
		c:SetChecked(SI_Global[var])
		SI_OptionsFrameAddLabel(ct)

		return c, ct
	end

	pad = pad - 15
	local version = f:CreateFontString(nil, "OVERLAY", f)
	version:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 8)
	version:SetFont("Fonts\\FRIZQT__.TTF", 9)
	SI_Skin("font", version, 9)
	version:SetTextColor(.5, .5, .5, .6)
	version:SetText("v" .. SS.AddonVersion)

	SI_FrameCreateHeader(f, SS.TextGeneral, 11, pad)
	pad = pad - 15

	createOpt(100, "WhisperBlock", SS.TextWhisperBlock, pad, function(checked)
		if checked and SI_Box_101:GetChecked() then SI_Box_101:Click() end
	end)
	pad = pad - 18

	createOpt(101, "WhisperUnignore", SS.TextWhisperUnignore, pad, function(checked)
		if checked and SI_Box_100:GetChecked() then SI_Box_100:Click() end
	end)
	pad = pad - 18

	createOpt(102, "WarnIgnoredPlayers", SS.TextWarnIgnoredPlayers, pad)
	pad = pad - 28

	SI_FrameCreateHeader(f, SS.TextOptions, 11, pad)
	pad = pad - 15
	local ignoreOnly = f:CreateFontString(nil, "OVERLAY")
	ignoreOnly:SetPoint("TOP", f, "TOP", 0, pad)
	ignoreOnly:SetFont("Fonts\\FRIZQT__.TTF", 10)
	SI_Skin("font", ignoreOnly, 10)
	ignoreOnly:SetTextColor(.6, .6, .6)
	ignoreOnly:SetText(SS.TextIgnoreOnly)
	SI_OptionsFrameAddLabel(ignoreOnly)
	pad = pad - 16

	local options = {
		{"BanOptWhisper",	SS.BanWhisper,	15},
		{"BanOptParty",		SS.BanParty,	15},
		{"BanOptGuild",		SS.BanGuild,	15},
		{"BanOptOfficer",	SS.BanOfficer,	15},
		{"BanOptSay",		SS.BanSay,		15},
		{"BanOptYell",		SS.BanYell,		15},
		{"BanOptBg",		SS.BanBG,		15},
		{"BanOptPublic",	SS.BanChannel,	15},
		{"BanOptEmote",		SS.BanEmote,	15},
		{"BanOptTrade",		SS.BanTrade,	15},
		{"BanOptInvite",	SS.BanInvite,	15},
		{"BanOptDuel",		SS.BanDuel,		25}
	}

	for i = 1, table.getn(options) do
		local optVar		= options[i][1]
		local optDesc		= options[i][2]
		local optPadding	= options[i][3]
		createOpt(i, optVar, optDesc, pad)
		pad = pad - optPadding
	end

	SI_FrameCreateHeader(f, SS.TextDuration, 11, pad)
	pad = pad - 15

	local dd = CreateFrame("Button", "SI_BanDuration", f, "UIDropDownMenuTemplate")
	dd:SetPoint("TOP", f, "TOP", 0, pad)
	UIDropDownMenu_SetWidth(100, dd)
	UIDropDownMenu_JustifyText("LEFT", dd)
	UIDropDownMenu_Initialize(dd, function()
		local info = {}
		for i = 1, table.getn(T_Time_TextOpt) + 1 do
			local option = i == 1 and SI_Shared.T_ASK or i - 1
			info.text = i == 1 and SS.TimeAsk or T_Time_TextOpt[option]
			info.value = option
			info.func = function()
				UIDropDownMenu_SetSelectedID(dd, this:GetID())
				SI_Global.BanDuration = option
			end
			info.checked = nil
			UIDropDownMenu_AddButton(info, 1)
		end
	end)
	UIDropDownMenu_SetSelectedID(dd, SI_Global.BanDuration == SI_Shared.T_ASK
		and 1 or SI_Global.BanDuration + 1)
	SI_Skin("dropdown", dd)

	SI_OptionsFramePad = pad - 35
	SI_OptionsFrameUpdateWidth()
	SI_OptionsFrame:SetScript("OnShow", SI_OptionsFrameUpdateWidth)
end

-- Option labels and the extra space each row needs to their right
SI_OptionsFrameLabels = {}

SI_OptionsFrameAddLabel = function(label, extra)
	table.insert(SI_OptionsFrameLabels, {label, extra or 0})
end

-- Fits the frame to its widest row, so labels never wrap (font depends on pfUI)
SI_OptionsFrameUpdateWidth = function()
	local inset = SI_PF and 0 or 4
	SI_OptionsContentFrame:ClearAllPoints()
	SI_OptionsContentFrame:SetPoint("TOPLEFT", SI_OptionsFrame, "TOPLEFT", inset, -inset)
	SI_OptionsContentFrame:SetPoint("BOTTOMRIGHT", SI_OptionsFrame, "BOTTOMRIGHT", -inset, inset)
	local width = 185
	for _, l in pairs(SI_OptionsFrameLabels) do
		-- checkbox offset + checkbox + label + row extra + right margin
		width = math.max(width, 15 + 20 + l[1]:GetStringWidth() + l[2] + 20)
	end
	SI_OptionsFrame:SetWidth(math.ceil(width) + 2 * inset)
	SI_OptionsFrameUpdateHeight()
end

SI_OptionsFrameUpdateHeight = function()
	local inset = SI_PF and 0 or 4
	SI_OptionsFrame:SetHeight(28 + (- SI_OptionsFramePad) + 2 * inset)
end

SI_CreateLogFrame = function()
	SI_LogFrame = SI_FrameCreateFrame("SI_LogFrame", 260, IgnoreListFrame, -34, -7)
	local f = SI_LogFrame
	f:SetHeight(300)

	f.title = SI_FrameCreateHeader(f, "", 12, -15)

	local sub = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	sub:SetPoint("TOP", f, "TOP", 0, -32)
	sub:SetText(SS.LogTitle)

	local close = CreateFrame("Button", "SI_LogFrameClose", f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
	SI_Skin("close", close)

	f.messages = SI_FrameCreateLog("SI_LogFrameMessages", f, 40, 500)
	SI_FrameCreateButton("SI_LogFrameCopy", f, "Copy", 85, "BOTTOMLEFT", 15, 14, function()
		SI_ShowCopyText(f.name, f.messages:GetAllText())
	end)
end

SI_LogFrameAddLine = function(msg)
	SI_LogFrame.messages:AddLine("|cff808080" .. msg[3] .. "|r  " .. msg[2])
end

-- Toggles the log panel for one player; shares its spot with the options panel
SI_LogFrameShow = function(name)
	local f = SI_LogFrame
	if f:IsShown() and f.name == name then
		f:Hide()
		return
	end

	f.name = name
	f.title:SetText(name)
	f.messages:ClearLines()
	local log = SI_LogGetByName(name)
	for _, msg in pairs(log) do
		SI_LogFrameAddLine(msg)
	end
	f.empty = table.getn(log) == 0 or nil
	if f.empty then
		f.messages:AddLine(SS.LogEmpty, .5, .5, .5)
	end

	SI_OptionsFrame:Hide()
	f:Show()
end

SI_CreateShowButton = function()
	local b = CreateFrame("Button", "SI_OpenButton", IgnoreListFrame, "UIPanelButtonTemplate")
	b:SetHeight(21)
	b:SetWidth(130)
	b:SetText(SS.AddonName)
	b:SetPoint("TOPLEFT", IgnoreListFrame, "TOPLEFT", 210, -50)
	SI_Skin("button", b)
	b:SetScript("OnClick", function()
		if SI_OptionsFrame:IsShown() then
			SI_OptionsFrame:Hide()
		else
			SI_LogFrame:Hide()
			SI_OptionsFrame:Show()
		end
	end)
end

SI_CreateFrames = function()
	SI_CreateOptionsFrame()
	SI_CreateLogFrame()
	SI_CreateShowButton()
	FriendsFrameIgnorePlayerButton:SetScript("OnClick", function()
		local target = UnitCanCooperate("player", "target") and UnitName("target") or nil
		SI_ShowIgnorePrompt(target)
	end)

	local oldOnShow = IgnoreListFrame:GetScript("OnShow")
	IgnoreListFrame:SetScript("OnShow", function()
		if oldOnShow then oldOnShow() end
		-- Place the button first; row padding is measured against it
		SI_SkinPlaceShowButton(SI_OpenButton)
		IgnoreList_Update()
	end)
end

SI_EnableIgnoreListRightclick = function()
	for i = 1, IGNORES_TO_DISPLAY do
		local item = getglobal("FriendsFrameIgnoreButton" .. i)
		item:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	end
end

------------- Unit Popup Menus

-- Inserts "IGNORE" before the anchor entry (at the end if it's missing), so menus
-- other addons changed still get it in a sensible spot, and only once
local addIgnoreToMenu = function(menu, anchor)
	local items = UnitPopupMenus[menu]
	if not items then return end
	local pos = table.getn(items) + 1
	for i = 1, table.getn(items) do
		if items[i] == "IGNORE" then return end
		if items[i] == anchor and pos > i then pos = i end
	end
	table.insert(items, pos, "IGNORE")
end

--Add Ignore button to dropdown menus (skip on Turtle WoW, which already has it)
if getglobal("TURTLE_WOW_VERSION") == nil then
	UnitPopupButtons["IGNORE"]	= { text = TEXT(IGNORE), dist = 0 };
	addIgnoreToMenu("FRIEND", "GUILD_PROMOTE")
	addIgnoreToMenu("PLAYER", "CANCEL")
	addIgnoreToMenu("RAID", "CANCEL")
	addIgnoreToMenu("PARTY", "CANCEL")
end

local function PostHookFunction(original, hook, pre)
	return function(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
		if pre then pre() end
		original(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
		hook(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
	end
end

local function SI_UnitPopup_HideButtons()
	local dropdownMenu = getglobal(UIDROPDOWNMENU_INIT_MENU);
	local canCoop = 0;
	if ( dropdownMenu.unit and UnitCanCooperate("player", dropdownMenu.unit) ) then
		canCoop = 1;
	end
	for index, value in ipairs(UnitPopupMenus[dropdownMenu.which]) do
		if ( value == "IGNORE" ) then
			if ( dropdownMenu.name == UnitName("player") or (dropdownMenu.unit and canCoop == 0) ) then
				UnitPopupShown[index] = 0;
			end
		end
	end
end
UnitPopup_HideButtons = PostHookFunction(UnitPopup_HideButtons, SI_UnitPopup_HideButtons)
local function SI_UnitPopup_OnClick()
	local dropdownFrame = getglobal(UIDROPDOWNMENU_INIT_MENU);
	local button = this.value;
	local name = dropdownFrame.name;

	if ( button == "IGNORE" and not SI_IgnoreHandled ) then
		SI_AddOrDelIgnore_New(name);
	end
end
-- Clear the flag before the original runs, so only this click can mark it handled
-- (ignores from /ignore, filters or expiry would otherwise leave it set)
UnitPopup_OnClick = PostHookFunction(UnitPopup_OnClick, SI_UnitPopup_OnClick,
	function() SI_IgnoreHandled = false end)
----
