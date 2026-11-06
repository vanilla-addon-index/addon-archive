-- =====================================================================
-- MetaHunt Option Panel Layout Engine
-- ---------------------------------------------------------------------
-- One reusable builder that every option panel uses. It removes ALL
-- hand-typed pixel offsets and box heights from the panels: you declare
-- rows, the engine stacks them and auto-sizes each box.
--
-- Think of it as CSS + flexbox for WoW 1.12:
--   * MTH_Layout.Theme  -> the "CSS variables" (spacing / fonts / colors).
--                          Change a value here to restyle every panel.
--   * panel / box methods -> the "flexbox": append rows, boxes grow to fit.
--
-- Design rules baked in (so the classic bugs are impossible):
--   * Each box TITLE lives INSIDE its box -> titles can never collide.
--   * Box HEIGHT is computed from its content -> never cramped/too short.
--   * Box CONTENT is parented to the box frame -> correct z-order.
--   * Everything is reuse-by-name (getglobal) -> no duplicates on /rl.
--
-- Typical usage:
--   local panel = MTH_Layout.Panel(container)
--   panel:Title("Feed-O-Matic")
--   panel:Note("blue helper paragraph", { lines = 3 })
--   panel:TopCheckbox("MyEnable", "Enable module", { onClick = fn, checked = fn })
--   local box = panel:Box("left", "MyBoxName", "General")
--   box:Text("MyStatus", "Feed key: P")
--   box:Buttons({ { name="A", label="Set Key", width=90, onClick=fn },
--                 { name="B", label="Clear",   width=70, onClick=fn } })
--   box:Note("MyHint", "blue helper text", { lines = 3 })
--   local cb = box:Checkbox("MyOpt", "Some option", { onClick = fn, checked = true })
--   box:EditRow("MyLbl", "Keep open bag slots:", "MyEdit", 40, { numeric = true, onChange = fn })
--   panel:Finish()
-- =====================================================================

MTH_Layout = MTH_Layout or {}
local L = MTH_Layout

-- ---------------------------------------------------------------------
-- THEME  ("CSS variables": tweak these to restyle the whole UI)
-- ---------------------------------------------------------------------
L.Theme = {
	-- Spacing (pixels)
	panelPad     = 12,   -- outer gutter from the panel edges
	colGap       = 12,   -- horizontal gap between the two columns
	boxGap       = 16,   -- vertical gap between stacked boxes
	colTopGap    = 8,    -- gap between the header block and the first boxes

	boxPadX      = 10,   -- content inset from a box's left edge
	boxPadTop    = 28,   -- first row offset from a box's top (clears inside title)
	boxPadBottom = 12,   -- padding beneath the last row inside a box
	cbInset      = 8,    -- checkbox inset from a box's left edge

	rowCheckbox  = 24,   -- vertical step consumed by a checkbox / edit row
	rowButton    = 30,   -- vertical step consumed by a button row
	rowSlider    = 46,   -- vertical step consumed by a slider (label+track+value)
	rowDropdown  = 50,   -- vertical step consumed by a dropdown (label+menu)
	textLine     = 14,   -- height of one wrapped text line
	textGap      = 6,    -- extra gap after a text/note block

	titleInsetX  = 10,   -- box title inset X (inside the box)
	titleInsetY  = -12,  -- box title inset Y (inside the box)

	headTop      = -12,  -- Y where the panel header starts
	headTitleStep = 24,  -- vertical step after the panel title
	headNoteGap  = 10,   -- extra gap after a header note
	headRowGap   = 8,    -- extra gap after a header checkbox
	headLinkStep = 18,   -- vertical step after a header link

	-- Fonts
	fontPanelTitle = "GameFontNormal",       -- panel heading
	fontBoxTitle   = "GameFontNormal",       -- box title (recolored)
	fontLabel      = "GameFontNormalSmall",  -- checkbox / edit labels
	fontText       = "GameFontNormalSmall",  -- plain text
	fontNote       = "GameFontNormalSmall",  -- helper paragraphs
	fontLink       = "GameFontHighlightSmall",

	-- Colors { r, g, b }
	colPanelTitle = { 1.00, 0.82, 0.00 },  -- gold
	colBoxTitle   = { 1.00, 1.00, 1.00 },  -- white
	colNote       = { 0.35, 0.65, 1.00 },  -- blue helper text
	colText       = { 0.93, 0.93, 0.93 },  -- normal text
	colLink       = { 0.40, 0.75, 1.00 },  -- link idle
	colLinkHover  = { 0.60, 0.90, 1.00 },  -- link hover

	-- Templates
	boxTemplate    = "OptionFrameBoxTemplate",
	checkTemplate  = "UICheckButtonTemplate",
	buttonTemplate = "UIPanelButtonTemplate",
	editTemplate   = "InputBoxTemplate",
}

-- ---------------------------------------------------------------------
-- Small shared helpers
-- ---------------------------------------------------------------------
local function applyColor(region, c)
	if region and c then region:SetTextColor(c[1], c[2], c[3]) end
end

local function ensureFontString(parent, name, font)
	local fs = getglobal(name)
	if not fs then
		fs = parent:CreateFontString(name, "ARTWORK", font)
	end
	fs:Show()
	return fs
end

local function ensureFrame(kind, name, parent, template)
	local f = getglobal(name)
	if not f then
		f = CreateFrame(kind, name, parent, template)
	end
	f:SetParent(parent)
	return f
end

-- Attach (or refresh) a checkbox's label, tooltip, checked state and click.
-- labelWidth (optional) enables word-wrap; the wrapped text height is returned
-- so the caller can grow the row to fit multi-line labels.
local function configureCheckbox(cb, label, opts, T, labelWidth)
	local txt = getglobal(cb:GetName() .. "Text")
	if not txt then
		txt = cb:CreateFontString(cb:GetName() .. "Text", "ARTWORK", T.fontLabel)
	end
	-- Anchor the label to the checkbox's top-right and let it grow downward so
	-- wrapped lines never collide with the row above. Centre a single line
	-- vertically against the checkbox.
	local cbH = (cb.GetHeight and cb:GetHeight()) or 24
	local topOff = -((cbH - T.textLine) / 2)
	if topOff > 0 then topOff = 0 end
	txt:ClearAllPoints()
	txt:SetPoint("TOPLEFT", cb, "TOPRIGHT", 4, topOff)
	if labelWidth and labelWidth > 0 then
		txt:SetWidth(labelWidth)
	else
		txt:SetWidth(0)
	end
	txt:SetJustifyH("LEFT")
	txt:SetJustifyV("TOP")
	txt:SetText(label or "")
	txt:Show()

	if opts.checked ~= nil then
		if type(opts.checked) == "function" then
			cb:SetChecked(opts.checked())
		else
			cb:SetChecked(opts.checked)
		end
	end

	if opts.onClick then
		cb:SetScript("OnClick", opts.onClick)
	end

	if opts.tooltip and opts.tooltip ~= "" then
		cb.mthTooltip = opts.tooltip
		cb:SetScript("OnEnter", function()
			GameTooltip:SetOwner(cb, "ANCHOR_RIGHT")
			GameTooltip:SetText(cb.mthTooltip, 1, 1, 1, 1, true)
			GameTooltip:Show()
		end)
		cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
	end

	local h = 0
	if txt.GetStringHeight then h = txt:GetStringHeight() end
	if (not h or h <= 0) and txt.GetHeight then h = txt:GetHeight() end
	return h or 0
end

-- ---------------------------------------------------------------------
-- Box object (returned by panel:Box). Appends rows top-to-bottom and
-- keeps the box height in sync with its content.
-- ---------------------------------------------------------------------
local function makeBox(container, box, boxWidth, state, T)
	local self = {}

	local function apply()
		state.height = -state.cursor + T.boxPadBottom
		box:SetHeight(state.height)
	end

	function self:Checkbox(name, label, opts)
		opts = opts or {}
		local cb = ensureFrame("CheckButton", name, box, T.checkTemplate)
		cb:ClearAllPoints()
		cb:SetPoint("TOPLEFT", box, "TOPLEFT", T.cbInset, state.cursor)
		cb:Show()
		-- Wrap width = box content width minus the checkbox frame, the 4px label
		-- gap, and a 2px right cushion so wrapped text never touches the border.
		local cbW = (cb.GetWidth and cb:GetWidth()) or 26
		local labelWidth = boxWidth - T.boxPadX - (T.cbInset + cbW + 4) - 2
		local txtH = configureCheckbox(cb, label, opts, T, labelWidth)
		-- A single line keeps the compact row height; a wrapped label grows the
		-- row to clear its top-centre offset plus a gap before the next row.
		local rowH = T.rowCheckbox
		local needed = txtH + 8
		if txtH > (T.textLine + 4) then needed = txtH + 14 end
		if needed > rowH then rowH = needed end
		state.cursor = state.cursor - rowH
		apply()
		return cb
	end

	function self:Text(name, text, opts)
		opts = opts or {}
		local fs = ensureFontString(box, name, opts.font or T.fontText)
		fs:ClearAllPoints()
		fs:SetPoint("TOPLEFT", box, "TOPLEFT", T.boxPadX, state.cursor)
		fs:SetWidth(opts.width or (boxWidth - T.boxPadX * 2))
		fs:SetJustifyH("LEFT")
		fs:SetJustifyV("TOP")
		fs:SetText(text or "")
		applyColor(fs, opts.color or T.colText)
		-- Reserve vertical space: honour an explicit line count, otherwise
		-- measure the wrapped height so callers don't have to guess.
		local reserve
		if opts.lines then
			reserve = opts.lines * T.textLine
		else
			local h = (fs.GetStringHeight and fs:GetStringHeight()) or 0
			if (not h or h <= 0) and fs.GetHeight then h = fs:GetHeight() end
			if not h or h <= 0 then h = T.textLine end
			reserve = h
		end
		state.cursor = state.cursor - reserve - T.textGap
		apply()
		return fs
	end

	-- Blue helper paragraph (same as MM Widget style), usable inside a box.
	function self:Note(name, text, opts)
		opts = opts or {}
		opts.color = opts.color or T.colNote
		opts.font = opts.font or T.fontNote
		return self:Text(name, text, opts)
	end

	-- One row of buttons placed left-to-right.
	-- list = { { name, label, width, height, onClick, gap, template }, ... }
	function self:Buttons(list)
		local out = {}
		local x = T.boxPadX
		local i = 1
		while list and i <= table.getn(list) do
			local spec = list[i]
			local b = ensureFrame("Button", spec.name, box, spec.template or T.buttonTemplate)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", box, "TOPLEFT", x, state.cursor)
			b:SetWidth(spec.width or 90)
			b:SetHeight(spec.height or 22)
			b:SetText(spec.label or "")
			b:Show()
			if spec.onClick then b:SetScript("OnClick", spec.onClick) end
			table.insert(out, b)
			x = x + (spec.width or 90) + (spec.gap or 8)
			i = i + 1
		end
		state.cursor = state.cursor - T.rowButton
		apply()
		return out
	end

	-- Label + edit box on one row (e.g. "Keep open bag slots: [__]").
	function self:EditRow(labelName, labelText, editName, editWidth, opts)
		opts = opts or {}
		local lbl = ensureFontString(box, labelName, T.fontLabel)
		lbl:ClearAllPoints()
		lbl:SetPoint("TOPLEFT", box, "TOPLEFT", T.boxPadX, state.cursor)
		lbl:SetText(labelText or "")
		applyColor(lbl, T.colText)

		local edit = ensureFrame("EditBox", editName, box, T.editTemplate)
		edit:ClearAllPoints()
		edit:SetPoint("LEFT", lbl, "RIGHT", 8, 0)
		edit:SetWidth(editWidth or 40)
		edit:SetHeight(opts.height or 20)
		if opts.numeric then edit:SetNumeric(true) end
		edit:SetAutoFocus(false)
		edit:Show()
		if opts.onChange then edit:SetScript("OnTextChanged", opts.onChange) end
		edit:SetScript("OnEnterPressed", function() if this then this:ClearFocus() end end)
		edit:SetScript("OnEscapePressed", function() if this then this:ClearFocus() end end)

		state.cursor = state.cursor - T.rowCheckbox
		apply()
		return edit, lbl
	end

	-- Slider with a left label and a right-aligned live value readout.
	-- opts = { label, min, max, step, value, width, onChange, format }
	-- format(value) -> string (defaults to a rounded integer).
	function self:Slider(name, opts)
		opts = opts or {}
		local lbl = ensureFontString(box, name .. "Caption", T.fontLabel)
		lbl:ClearAllPoints()
		lbl:SetPoint("TOPLEFT", box, "TOPLEFT", T.boxPadX, state.cursor)
		lbl:SetText(opts.label or "")
		applyColor(lbl, T.colText)

		local valueFs = ensureFontString(box, name .. "Value", T.fontLabel)
		valueFs:ClearAllPoints()
		valueFs:SetPoint("TOPRIGHT", box, "TOPRIGHT", -T.boxPadX, state.cursor)
		valueFs:SetJustifyH("RIGHT")
		applyColor(valueFs, T.colPanelTitle)

		local slider = ensureFrame("Slider", name, box, "OptionsSliderTemplate")
		slider:ClearAllPoints()
		slider:SetPoint("TOPLEFT", box, "TOPLEFT", T.boxPadX + 4, state.cursor - 18)
		slider:SetWidth(opts.width or (boxWidth - T.boxPadX * 2 - 8))
		slider:SetMinMaxValues(opts.min or 0, opts.max or 1)
		slider:SetValueStep(opts.step or 1)
		slider:Show()

		-- OptionsSliderTemplate ships Low/High/Text children; silence them.
		local lowFs = getglobal(name .. "Low");  if lowFs then lowFs:SetText(""); lowFs:Hide() end
		local highFs = getglobal(name .. "High"); if highFs then highFs:SetText(""); highFs:Hide() end
		local midFs = getglobal(name .. "Text"); if midFs then midFs:SetText("") end

		slider.mthValueFs = valueFs
		slider.mthFormat = opts.format
		slider.mthOnChange = opts.onChange
		slider:SetScript("OnValueChanged", function()
			local v = tonumber(arg1)
			if not v and this and this.GetValue then v = this:GetValue() end
			if not v then v = 0 end
			if this.mthValueFs then
				if this.mthFormat then
					this.mthValueFs:SetText(this.mthFormat(v))
				else
					this.mthValueFs:SetText(tostring(math.floor(v + 0.5)))
				end
			end
			if this.mthOnChange then this.mthOnChange(v) end
		end)
		slider:SetValue(opts.value or opts.min or 0)

		state.cursor = state.cursor - T.rowSlider
		apply()
		return slider
	end

	-- Dropdown menu with a left label. The caller supplies the standard
	-- UIDropDownMenu initialize function and (optionally) the current text.
	-- opts = { label, width, initialize, text }
	function self:Dropdown(name, opts)
		opts = opts or {}
		local lbl = ensureFontString(box, name .. "Caption", T.fontLabel)
		lbl:ClearAllPoints()
		lbl:SetPoint("TOPLEFT", box, "TOPLEFT", T.boxPadX, state.cursor)
		lbl:SetText(opts.label or "")
		applyColor(lbl, T.colText)

		local dd = ensureFrame("Frame", name, box, "UIDropDownMenuTemplate")
		dd:ClearAllPoints()
		-- UIDropDownMenu textures carry ~15px of built-in left inset.
		dd:SetPoint("TOPLEFT", box, "TOPLEFT", T.boxPadX - 15, state.cursor - 16)
		dd:Show()
		if UIDropDownMenu_SetWidth then
			UIDropDownMenu_SetWidth(opts.width or (boxWidth - T.boxPadX * 2 - 20), dd)
		end
		if UIDropDownMenu_JustifyText then UIDropDownMenu_JustifyText("LEFT", dd) end
		if opts.initialize and UIDropDownMenu_Initialize then
			UIDropDownMenu_Initialize(dd, opts.initialize)
		end
		if opts.text and UIDropDownMenu_SetText then
			UIDropDownMenu_SetText(opts.text, dd)
		end

		state.cursor = state.cursor - T.rowDropdown
		apply()
		return dd
	end

	-- Single button occupying one button row (thin wrapper over :Buttons).
	function self:Button(name, label, opts)
		opts = opts or {}
		local out = self:Buttons({ {
			name = name, label = label,
			width = opts.width, height = opts.height,
			onClick = opts.onClick, template = opts.template,
		} })
		return out[1]
	end

	-- Label on the left, a colour swatch + "Pick" button on the right.
	-- opts = { label, color = {r,g,b}, buttonText, buttonWidth, onClick }
	function self:ColorRow(name, opts)
		opts = opts or {}
		local lbl = ensureFontString(box, name .. "Caption", T.fontLabel)
		lbl:ClearAllPoints()
		lbl:SetPoint("TOPLEFT", box, "TOPLEFT", T.boxPadX, state.cursor)
		lbl:SetText(opts.label or "")
		applyColor(lbl, T.colText)

		local btn = ensureFrame("Button", name .. "Button", box, T.buttonTemplate)
		btn:ClearAllPoints()
		btn:SetPoint("TOPRIGHT", box, "TOPRIGHT", -T.boxPadX, state.cursor + 2)
		btn:SetWidth(opts.buttonWidth or 60)
		btn:SetHeight(20)
		btn:SetText(opts.buttonText or "Pick")
		btn:Show()
		if opts.onClick then btn:SetScript("OnClick", opts.onClick) end

		local swatch = getglobal(name .. "Swatch")
		if not swatch then
			swatch = btn:CreateTexture(name .. "Swatch", "OVERLAY")
			swatch:SetTexture("Interface\\Buttons\\WHITE8X8")
			swatch:SetWidth(12)
			swatch:SetHeight(12)
			swatch:SetPoint("LEFT", btn, "LEFT", 5, 0)
		end
		if opts.color then
			swatch:SetVertexColor(opts.color[1], opts.color[2], opts.color[3])
		end

		state.cursor = state.cursor - T.rowCheckbox
		apply()
		return btn, swatch
	end

	-- Manual vertical spacer.
	function self:Gap(px)
		state.cursor = state.cursor - (px or 12)
		apply()
	end

	-- Reserve a custom row of the given pixel height. Returns the box frame and
	-- the TOPLEFT y-offset (within the box) where custom widgets can anchor.
	-- Use for composite rows the primitives don't cover (e.g. checkbox +
	-- dropdown + edit box on one line). x anchoring is left to the caller.
	function self:Row(height)
		local y = state.cursor
		state.cursor = state.cursor - (height or T.rowCheckbox)
		apply()
		return box, y
	end

	-- Left content inset (px) for callers positioning custom row widgets.
	function self:PadX() return T.boxPadX end

	function self:Frame() return box end

	return self
end

-- ---------------------------------------------------------------------
-- Panel object (returned by MTH_Layout.Panel).
-- ---------------------------------------------------------------------
function L.Panel(container)
	if not container then return nil end
	local T = L.Theme
	MTH_ClearContainer(container)

	local cname = (container.GetName and container:GetName()) or "MTHPanel"
	local width = (container.GetWidth and container:GetWidth()) or 0
	if not width or width < 460 then width = 580 end

	local colWidth = math.floor((width - T.panelPad * 2 - T.colGap) / 2)
	if colWidth < 220 then colWidth = 220 end
	local leftX = T.panelPad
	local rightX = T.panelPad + colWidth + T.colGap
	local fullWidth = width - T.panelPad * 2

	local headY = T.headTop
	local started = false
	local col = {
		left  = { x = leftX,  y = 0, open = nil },
		right = { x = rightX, y = 0, open = nil },
	}
	local noteId = 0

	local panel = {}

	local function startColumns()
		if started then return end
		started = true
		local top = headY - T.colTopGap
		col.left.y = top
		col.right.y = top
	end

	local function closeSide(side)
		local c = col[side]
		if c and c.open then
			c.y = c.y - c.open.height - T.boxGap
			c.open = nil
		end
	end

	-- ---- Header elements (full width, above the columns) ----
	function panel:Title(text)
		local fs = ensureFontString(container, cname .. "_Title", T.fontPanelTitle)
		fs:ClearAllPoints()
		fs:SetPoint("TOPLEFT", container, "TOPLEFT", T.panelPad, headY)
		fs:SetText(text or "")
		applyColor(fs, T.colPanelTitle)
		headY = headY - T.headTitleStep
		return fs
	end

	function panel:Note(text, opts)
		opts = opts or {}
		noteId = noteId + 1
		local fs = ensureFontString(container, cname .. "_Note" .. noteId, T.fontNote)
		fs:ClearAllPoints()
		fs:SetPoint("TOPLEFT", container, "TOPLEFT", T.panelPad, headY)
		fs:SetWidth(opts.width or fullWidth)
		fs:SetJustifyH("LEFT")
		fs:SetJustifyV("TOP")
		fs:SetText(text or "")
		applyColor(fs, opts.color or T.colNote)
		local lines = opts.lines or 1
		headY = headY - (lines * T.textLine) - T.headNoteGap
		return fs
	end

	function panel:Link(name, text, onClick)
		local btn = ensureFrame("Button", name, container, nil)
		btn:ClearAllPoints()
		btn:SetPoint("TOPLEFT", container, "TOPLEFT", T.panelPad, headY)
		btn:SetHeight(16)
		btn:SetWidth(fullWidth)
		local fs = getglobal(name .. "Text")
		if not fs then
			fs = btn:CreateFontString(name .. "Text", "ARTWORK", T.fontLink)
			fs:SetPoint("LEFT", btn, "LEFT", 0, 0)
			fs:SetJustifyH("LEFT")
		end
		fs:SetText(text or "")
		applyColor(fs, T.colLink)
		btn:Show()
		btn:SetScript("OnEnter", function() applyColor(fs, T.colLinkHover) end)
		btn:SetScript("OnLeave", function() applyColor(fs, T.colLink) end)
		if onClick then btn:SetScript("OnClick", onClick) end
		headY = headY - T.headLinkStep
		return btn
	end

	function panel:TopCheckbox(name, label, opts)
		opts = opts or {}
		local cb = ensureFrame("CheckButton", name, container, T.checkTemplate)
		cb:ClearAllPoints()
		cb:SetPoint("TOPLEFT", container, "TOPLEFT", T.panelPad, headY)
		cb:Show()
		local txtH = configureCheckbox(cb, label, opts, T, fullWidth - 26)
		local rowH = T.rowCheckbox
		if (txtH + 8) > rowH then rowH = txtH + 8 end
		headY = headY - rowH - T.headRowGap
		return cb
	end

	-- ---- Boxes (columns) ----
	function panel:Box(side, name, title)
		startColumns()
		side = (side == "right") and "right" or "left"
		closeSide(side)
		local c = col[side]

		local box = ensureFrame("Frame", name, container, T.boxTemplate)
		box:ClearAllPoints()
		box:SetPoint("TOPLEFT", container, "TOPLEFT", c.x, c.y)
		box:SetWidth(colWidth)
		box:Show()

		local titleFS = getglobal(name .. "Title")
		if titleFS then
			titleFS:SetText(title or "")
			applyColor(titleFS, T.colBoxTitle)
			titleFS:ClearAllPoints()
			titleFS:SetPoint("TOPLEFT", box, "TOPLEFT", T.titleInsetX, T.titleInsetY)
		end

		local state = {
			cursor = -T.boxPadTop,
			height = T.boxPadTop + T.boxPadBottom,
		}
		box:SetHeight(state.height)
		c.open = state

		return makeBox(container, box, colWidth, state, T)
	end

	-- Returns "left" or "right": whichever column currently has more room
	-- left (i.e. its content bottom is higher). Lets callers auto-balance
	-- a variable number of boxes without hand-picking columns.
	function panel:ShorterSide()
		startColumns()
		local function bottom(side)
			local c = col[side]
			local y = c.y
			if c.open then y = y - c.open.height - T.boxGap end
			return y
		end
		if bottom("right") > bottom("left") then return "right" end
		return "left"
	end

	function panel:Finish()
		closeSide("left")
		closeSide("right")
	end

	-- Expose geometry for callers that need it (rare).
	panel.colWidth = colWidth
	panel.fullWidth = fullWidth

	return panel
end
