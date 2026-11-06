--[[
	A minimal stand-in for the WoW 1.12 UI API.

	It exists so the addon's own frame-building code can be executed off-client
	in CI. It is not an emulator: it records what was asked for and enforces the
	parts of the API that are easy to get wrong (anchor points, texture
	coordinates, colour ranges), so a typo or a bad SetPoint surfaces here
	instead of in-game.

	Anything it does not implement is reported as an error rather than silently
	returning nil, which is the whole point -- a silent nil is what makes a
	1.12 UI bug so tedious to chase.
]]

local stub = {}

local VALID_POINTS = {
	TOPLEFT = true, TOP = true, TOPRIGHT = true,
	LEFT = true, CENTER = true, RIGHT = true,
	BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

local VALID_LAYERS = {
	BACKGROUND = true, BORDER = true, ARTWORK = true,
	OVERLAY = true, HIGHLIGHT = true,
}

stub.errors = {}
stub.cursor = { 0, 0 }
stub.mouseDown = false
-- The bags: stub.bags[bag][slot] = { id = n, name = "...", count = n }.
stub.bags = {}

local function complain(fmt, ...)
	local msg = string.format(fmt, ...)
	table.insert(stub.errors, msg)
end

local function checkPoint(what, point)
	if point ~= nil and not VALID_POINTS[point] then
		complain("%s: '%s' is not a valid anchor point", what, tostring(point))
	end
end

local function checkColor(what, r, g, b, a)
	for name, v in pairs({ r = r, g = g, b = b, a = a }) do
		if v ~= nil and (type(v) ~= "number" or v < 0 or v > 1) then
			complain("%s: %s=%s out of 0..1", what, name, tostring(v))
		end
	end
end

-- Shared object behaviour ---------------------------------------------------

local function newObject(kind, name, parent)
	local o = {
		__kind = kind, __name = name, __parent = parent,
		__points = {}, __width = nil, __height = nil,
		__shown = true, __scripts = {}, __children = {}, __regions = {},
	}

	function o:SetWidth(w)
		if type(w) ~= "number" then complain("%s:SetWidth(%s) not a number", kind, tostring(w)) end
		self.__width = w
	end
	function o:SetHeight(h)
		if type(h) ~= "number" then complain("%s:SetHeight(%s) not a number", kind, tostring(h)) end
		self.__height = h
	end
	function o:GetWidth() return self.__width or 0 end
	function o:GetHeight() return self.__height or 0 end

	function o:SetPoint(p, rel, relP, x, y)
		checkPoint(kind .. ":SetPoint", p)
		-- SetPoint("LEFT", 10, 0) is the 3-arg form: rel is then a number.
		if type(rel) == "string" then checkPoint(kind .. ":SetPoint relativePoint", rel) end
		if relP ~= nil and type(relP) == "string" then checkPoint(kind .. ":SetPoint", relP) end
		table.insert(self.__points, { p, rel, relP, x, y })
	end
	function o:SetAllPoints(other) table.insert(self.__points, { "ALL", other }) end
	function o:ClearAllPoints() self.__points = {} end
	function o:GetNumPoints() return table.getn(self.__points) end
	-- 1-indexed like the real API; no index means the first point.
	function o:GetPoint(i)
		local p = self.__points[i or 1]
		if not p then return nil end
		return p[1], p[2], p[3], p[4], p[5]
	end

	--[[ Where the frame sits, in UIParent coordinates (origin bottom-left),
		worked out from its first anchor the way the client does. Enough for
		code that reads an edge and re-anchors by it; SetAllPoints and
		multi-point sizing are not modelled. ]]
	local function frac(point)
		local fx, fy = 0.5, 0.5
		if string.find(point, "LEFT") then fx = 0 elseif string.find(point, "RIGHT") then fx = 1 end
		if string.find(point, "TOP") then fy = 1 elseif string.find(point, "BOTTOM") then fy = 0 end
		return fx, fy
	end
	function o:__rect()
		local pt = self.__points[1]
		local w, h = self:GetWidth(), self:GetHeight()
		if not pt then
			if not self.__parent then return 0, 0, w, h end   -- UIParent / WorldFrame
			return nil
		end
		if pt[1] == "ALL" then return nil end
		local rel, relP, x, y = pt[2], pt[3], pt[4], pt[5]
		if type(rel) == "number" then            -- SetPoint(p, x, y)
			rel, relP, x, y = self.__parent, pt[1], rel, relP
		end
		rel = rel or self.__parent
		if type(rel) ~= "table" or not rel.__rect then return nil end
		local rl, rb, rw, rh = rel:__rect()
		if not rl then return nil end
		local rfx, rfy = frac(relP or pt[1])
		local ax, ay = rl + rfx * rw + (x or 0), rb + rfy * rh + (y or 0)
		local fx, fy = frac(pt[1])
		return ax - fx * w, ay - fy * h, w, h
	end
	function o:GetLeft() local l = self:__rect(); return l end
	function o:GetBottom() local _, b = self:__rect(); return b end
	function o:GetCenter()
		local l, b, w, h = self:__rect()
		if not l then return nil end
		return l + w / 2, b + h / 2
	end
	function o:GetTop()
		local _, b, _, h = self:__rect()
		return b and (b + h)
	end
	function o:GetRight()
		local l, _, w = self:__rect()
		return l and (l + w)
	end

	function o:Show() self.__shown = true end
	function o:Hide() self.__shown = false end
	function o:IsShown() return self.__shown end
	function o:IsVisible() return self.__shown end
	function o:SetAlpha(a) checkColor(kind .. ":SetAlpha", nil, nil, nil, a); self.__alpha = a end
	function o:GetAlpha() return self.__alpha or 1 end
	function o:GetParent() return self.__parent end

	return o
end

local function newTexture(name, parent, layer)
	local t = newObject("Texture", name, parent)
	if layer ~= nil and not VALID_LAYERS[layer] then
		complain("CreateTexture: '%s' is not a valid draw layer", tostring(layer))
	end
	t.__layer = layer
	function t:SetTexture(path, g, b, a)
		if type(path) == "number" then return end -- SetTexture(r,g,b) colour form
		if path == nil then                       -- clears the texture; legal
			self.__texture = nil
			return
		end
		if type(path) ~= "string" then
			complain("Texture:SetTexture(%s) is not a path", tostring(path))
			return
		end
		if string.find(path, "%.tga$") or string.find(path, "%.blp$") then
			complain("Texture:SetTexture('%s') must not carry a file extension", path)
		end
		self.__texture = path
	end
	function t:GetTexture() return self.__texture end
	--[[ Both forms the client accepts.

		Four arguments are the usual left/right/top/bottom crop. Eight map the
		texture onto an arbitrary quad, corner by corner, which is the only way
		to rotate a texture on this client -- there is no SetRotation in 1.12.
	]]
	function t:SetTexCoord(a, b, c, d, e, f, g, h)
		local args = { a, b, c, d, e, f, g, h }
		local n = 0
		for i = 1, 8 do if args[i] ~= nil then n = i end end
		if n ~= 4 and n ~= 8 then
			complain("Texture:SetTexCoord takes 4 or 8 numbers, got %d", n)
			return
		end
		for i = 1, n do
			if type(args[i]) ~= "number" then
				complain("Texture:SetTexCoord got %s", tostring(args[i]))
				return
			end
		end
		self.__texcoord = { unpack(args, 1, n) }
	end
	function t:SetVertexColor(r, g, b, a)
		checkColor("Texture:SetVertexColor", r, g, b, a)
		self.__color = { r, g, b, a }
	end
	function t:GetVertexColor()
		local c = self.__color or { 1, 1, 1, 1 }
		return c[1], c[2], c[3], c[4] or 1
	end
	function t:SetBlendMode() end
	function t:SetRotation() end
	return t
end

local function newFontString(name, parent, layer)
	local fs = newObject("FontString", name, parent)
	fs.__layer = layer
	function fs:SetFont(path, size, flags)
		if type(path) ~= "string" or type(size) ~= "number" then
			complain("FontString:SetFont(%s, %s) bad arguments", tostring(path), tostring(size))
			return false
		end
		self.__font, self.__size = path, size
		-- Report failure for a font file that is not present, mirroring the
		-- client, so fallback paths actually get exercised in tests.
		if stub.missingFonts and stub.missingFonts[path] then return false end
		return true
	end
	function fs:SetFontObject() end
	function fs:SetText(t) self.__text = t end
	function fs:GetText() return self.__text end
	function fs:SetTextColor(r, g, b, a)
		checkColor("FontString:SetTextColor", r, g, b, a)
		self.__color = { r, g, b, a }
	end
	function fs:GetTextColor()
		local c = self.__color or { 1, 1, 1, 1 }
		return c[1], c[2], c[3], c[4] or 1
	end
	function fs:SetJustifyH(v)
		if v ~= "LEFT" and v ~= "RIGHT" and v ~= "CENTER" then
			complain("SetJustifyH('%s')", tostring(v))
		end
	end
	function fs:SetJustifyV() end
	-- Text shadows, recorded rather than ignored: the navigation callout has
	-- no panel behind it, so whether its text is shadowed decides whether it
	-- can be read over snow.
	function fs:SetShadowOffset(x, y)
		if type(x) ~= "number" or type(y) ~= "number" then
			complain("SetShadowOffset(%s, %s) not numbers", tostring(x), tostring(y))
		end
		self.__shadowOffset = { x, y }
	end
	function fs:SetShadowColor(r, g, b, a)
		checkColor("FontString:SetShadowColor", r, g, b, a)
		self.__shadowColor = { r, g, b, a }
	end
	function fs:GetStringWidth() return string.len(self.__text or "") * 6 end
	function fs:SetWordWrap() end

	-- Rough text metrics so layout code that measures a font string can be
	-- exercised. Real glyph widths vary; this only has to be monotonic in the
	-- amount of text, which is what layout logic depends on.
	function fs:GetHeight()
		if self.__height then return self.__height end
		local text = self.__text
		if not text or text == "" then return 0 end
		local size = self.__size or 12
		local perChar = size * 0.5
		local width = self.__width
		if not width or width <= 0 then return size + 2 end
		local perLine = math.max(1, math.floor(width / perChar))
		local lines = math.max(1, math.ceil(string.len(text) / perLine))
		return lines * (size + 2)
	end

	return fs
end

local function newFrame(frameType, name, parent)
	local f = newObject(frameType or "Frame", name, parent)

	function f:CreateTexture(n, layer)
		local t = newTexture(n, self, layer)
		table.insert(self.__regions, t)
		return t
	end
	function f:CreateFontString(n, layer)
		local fs = newFontString(n, self, layer)
		table.insert(self.__regions, fs)
		return fs
	end
	function f:SetScript(event, fn)
		if type(fn) ~= "function" and fn ~= nil then
			complain("SetScript('%s') given a %s", tostring(event), type(fn))
		end
		self.__scripts[event] = fn
	end
	function f:GetScript(event) return self.__scripts[event] end
	function f:HookScript(event, fn) self.__scripts[event] = fn end
	function f:RegisterEvent(e) self.__events = self.__events or {}; self.__events[e] = true end
	function f:UnregisterEvent() end
	function f:EnableMouse(v) self.__mouse = v and true or false end
	function f:IsMouseEnabled() return self.__mouse and true or false end
	function f:RegisterForClicks(...) self.__clicks = { ... } end
	-- Drag state is recorded rather than ignored: "the panel is draggable" is a
	-- claim a test can only check by looking at what was wired up.
	function f:RegisterForDrag(button) self.__dragButton = button end
	function f:SetMovable(v) self.__movable = v and true or false end
	function f:IsMovable() return self.__movable and true or false end
	function f:SetResizable() end
	function f:SetMinResize() end
	function f:SetMaxResize() end
	function f:StartSizing() end
	function f:EnableMouseWheel() end
	function f:SetDisabledFontObject() end
	function f:SetHighlightFontObject() end
	function f:SetTextFontObject() end
	function f:SetDisabledTexture() end
	function f:GetDisabledTexture() return newTexture(nil, self, "ARTWORK") end
	function f:GetHighlightTexture() return newTexture(nil, self, "HIGHLIGHT") end
	function f:GetPushedTexture() return newTexture(nil, self, "ARTWORK") end
	function f:SetClampedToScreen(v) self.__clamped = v and true or false end
	function f:SetFrameStrata(s) self.__strata = s end
	function f:GetFrameStrata() return self.__strata or "MEDIUM" end
	--[[ Frame levels, as the client assigns them: a frame starts one above
		its parent. Whether SetFrameLevel drags a frame's children along with
		it is not something the 1.12 client documents, so stub.cascadeLevels
		lets a test run both ways and check it does not depend on either. ]]
	function f:SetFrameLevel(l)
		if type(l) ~= "number" then complain("SetFrameLevel(%s) not a number", tostring(l)) end
		local delta = l - (self.__level or 0)
		self.__level = l
		if stub.cascadeLevels and delta ~= 0 then
			local function shift(fr)
				for _, c in ipairs(fr.__children) do
					c.__level = (c.__level or 0) + delta
					shift(c)
				end
			end
			shift(self)
		end
	end
	function f:GetFrameLevel() return self.__level or 0 end
	function f:GetChildren() return unpack(self.__children) end
	function f:SetToplevel(v) self.__toplevel = v and true or false end
	function f:IsToplevel() return self.__toplevel or false end
	function f:StartMoving() self.__moving = true end
	function f:StopMovingOrSizing() self.__moving = false end
	function f:SetBackdrop(bd) self.__backdrop = bd end
	function f:SetBackdropColor(r, g, b, a) checkColor("SetBackdropColor", r, g, b, a) end
	function f:SetBackdropBorderColor(r, g, b, a) checkColor("SetBackdropBorderColor", r, g, b, a) end
    function f:SetNormalTexture() end
	function f:SetPushedTexture() end
	function f:SetHighlightTexture() end
	function f:SetCheckedTexture() end
	function f:SetDisabledCheckedTexture() end
	function f:GetNormalTexture() return newTexture(nil, self, "ARTWORK") end
	function f:SetThumbTexture() end
	function f:GetThumbTexture() return newTexture(nil, self, "ARTWORK") end
	-- Sliders remember their range and value, so a scroll bar's wiring can
	-- be checked rather than assumed.
	function f:SetMinMaxValues(lo, hi) self.__min, self.__max = lo, hi end
	function f:GetMinMaxValues() return self.__min or 0, self.__max or 0 end
	function f:SetValue(v)
		self.__value = v
		local h = self.__scripts.OnValueChanged
		if h then
			local oldThis, oldArg = this, arg1
			this, arg1 = self, v
			h()
			this, arg1 = oldThis, oldArg
		end
	end
	function f:GetValue() return self.__value or 0 end
	-- StatusBar: the client fills its texture to the value; the stub keeps
	-- the texture and colour it was given.
	function f:SetStatusBarTexture(path) self.__barTexture = path end
	function f:GetStatusBarTexture() return nil end   -- not relied on: 1.12 may lack it
	function f:SetStatusBarColor(r, g, b, a)
		checkColor("SetStatusBarColor", r, g, b, a)
		self.__barColor = { r, g, b, a }
	end
	function f:GetStatusBarColor()
		local c = self.__barColor or { 1, 1, 1, 1 }
		return c[1], c[2], c[3], c[4]
	end
	-- ScrollFrame: a child that is offset by the vertical scroll.
	function f:SetScrollChild(child) self.__scrollChild = child end
	function f:GetScrollChild() return self.__scrollChild end
	function f:SetVerticalScroll(v) self.__vscroll = v end
	function f:GetVerticalScroll() return self.__vscroll or 0 end
	function f:UpdateScrollChildRect() end
	-- How far the child overhangs the frame; a test sets __vrange to stand
	-- in for the client measuring it.
	function f:GetVerticalScrollRange() return self.__vrange or 0 end
	-- EditBox.
	function f:SetMultiLine(v) self.__multiline = v and true or false end
	function f:SetAutoFocus() end
	function f:SetFontObject() end
	function f:SetID(id) self.__id = id end
	function f:GetName() return self.__name end
	function f:GetID() return self.__id or 0 end
	function f:SetFont() return true end
	function f:SetTextColor(r, g, b, a) checkColor("EditBox:SetTextColor", r, g, b, a) end
	function f:SetJustifyH() end
	function f:SetMaxLetters() end
	function f:SetTextInsets() end
	function f:SetFocus() self.__focus = true end
	function f:ClearFocus() self.__focus = false end
	function f:HasFocus() return self.__focus end
	function f:HighlightText() end
	function f:SetCursorPosition(p) self.__cursor = p end
	function f:SetValueStep() end
	function f:SetOrientation() end
	function f:Disable() self.__enabled = false end
	function f:Enable() self.__enabled = true end
	function f:IsEnabled() return self.__enabled ~= false end
	function f:SetChecked(v) self.__checked = v and true or false end
	function f:GetChecked() return self.__checked end
	function f:SetButtonState(s)
		if s ~= "NORMAL" and s ~= "PUSHED" and s ~= "DISABLED" then
			complain("SetButtonState('%s')", tostring(s))
		end
	end
	function f:SetText(t) self.__text = t end
	function f:GetText() return self.__text end
	function f:SetScale(v)
		if type(v) ~= "number" or v <= 0 then complain("SetScale(%s) not a positive number", tostring(v)) end
		self.__scale = v
	end
	function f:GetScale() return self.__scale or 1 end
	function f:GetEffectiveScale() return 1 end
	function f:SetHitRectInsets() end
	function f:CreateTitleRegion() return newObject("TitleRegion", nil, self) end

	if parent and parent.__children then table.insert(parent.__children, f) end
	f.__level = parent and parent.__level and (parent.__level + 1) or 0
	return f
end

-- Globals the addon expects -------------------------------------------------

function stub.install(env)
	env = env or _G
	env.CreateFrame = function(frameType, name, parent, template)
		local f = newFrame(frameType, name, parent)
		-- The real client publishes a named frame as a global, which is how
		-- UISpecialFrames entries and getglobal() lookups resolve.
		if name then env[name] = f end
		return f
	end
	env.UIParent = newFrame("Frame", "UIParent", nil)
	env.UIParent:SetWidth(1024); env.UIParent:SetHeight(768)
	env.QuestWatchFrame = newFrame("Frame", "QuestWatchFrame", env.UIParent)
	-- The minimap: 140px across, top right of the screen, as the client has it.
	env.Minimap = newFrame("Frame", "Minimap", env.UIParent)
	env.Minimap:SetWidth(140); env.Minimap:SetHeight(140)
	env.Minimap:SetPoint("TOPRIGHT", env.UIParent, "TOPRIGHT", -17, -22)
	env.WorldFrame = newFrame("Frame", "WorldFrame", nil)
	env.GameTooltip = newFrame("GameTooltip", "GameTooltip", env.UIParent)
	env.GameTooltip.SetOwner = function() end
	env.GameTooltip.SetText = function() end
	env.GameTooltip.AddLine = function() end
	env.GameTooltip.Show = function() end
	env.GameTooltip.SetItemByID = function() end
	env.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
	env.GameFontNormal = {}
	env.GameFontNormalSmall = {}
	env.GameFontHighlight = {}
	env.getglobal = function(n) return env[n] end
	-- The cursor, in screen pixels; a test moves it by setting stub.cursor.
	env.GetCursorPosition = function() return stub.cursor[1], stub.cursor[2] end
	env.IsMouseButtonDown = function() return stub.mouseDown end
	env.UnitFactionGroup = function() return "Alliance" end
	env.UnitLevel = function() return 1 end
	env.UnitClass = function() return "Warrior", "WARRIOR" end
	env.UnitRace = function() return "Human", "Human" end
	env.GetLocale = function() return "enUS" end
	env.GetTime = function() return os.clock() end
	env.date = os.date
	-- Bags 0-4, sixteen slots each, filled from stub.bags.
	local function bagItem(bag, slot) return stub.bags[bag] and stub.bags[bag][slot] end
	env.GetContainerNumSlots = function(bag) return 16 end
	env.GetContainerItemLink = function(bag, slot)
		local it = bagItem(bag, slot)
		return it and string.format("|cffffffff|Hitem:%d:0:0:0|h[%s]|h|r", it.id, it.name) or nil
	end
	env.GetContainerItemInfo = function(bag, slot)
		local it = bagItem(bag, slot)
		if not it then return nil end
		return it.texture or "Interface\\Icons\\INV_Misc_QuestionMark", it.count or 1, nil, 1, nil
	end
	return env
end

function stub.reset()
	stub.errors = {}
end

function stub.report()
	return stub.errors
end

return stub
