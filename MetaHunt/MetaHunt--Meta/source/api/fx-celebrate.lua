-- MetaHunt: center-screen celebration effect (message + firework burst).
-- Uses the embedded PizzaSauce animation library. Degrades to a silent no-op
-- when PizzaSauce or the WoW frame API are unavailable (e.g. offline tests).

-- Capture our own PizzaSauce instance now, before another addon that ships its
-- own copy can overwrite the global. This is the pattern the library requires.
local Sauce = PizzaSauce

-- Localization helper: resolve a key through MetaHunt's loc system, falling back
-- to the inline English default. Every user-facing string is keyed so the enUS
-- strings can be harvested later; the inline default is the working English.
local function MTH_FX_L(key, default)
	if MTH and type(MTH.GetLocalization) == "function" then
		return MTH:GetLocalization(key, default)
	end
	return default or key
end

-- ---------------------------------------------------------------------------
-- Animation settings (shared by the effect code and the options "Animations" tab)
-- ---------------------------------------------------------------------------
-- Sections shown, in order, in the options panel. `titleKey` localizes `title`.
MTH_FX_ANIM_SECTIONS = {
	{ id = "pet",  title = "Pet",  titleKey = "ANIM_SECTION_PET" },
	{ id = "level", title = "Leveling", titleKey = "ANIM_SECTION_LEVEL" },
	{ id = "combat", title = "Combat", titleKey = "ANIM_SECTION_COMBAT" },
	{ id = "book", title = "Book", titleKey = "ANIM_SECTION_BOOK" },
	{ id = "ui",   title = "Interface", titleKey = "ANIM_SECTION_UI" },
}

-- Every individual animation the addon can play. Each has a stable `key`, the
-- section it belongs to, a checkbox label, an optional tooltip, and a default.
-- labelKey/tooltipKey localize label/tooltip (resolved at render time).
-- Adding a new animation = one entry here + one MTH_FX_IsEnabled("key") guard.
MTH_FX_ANIM_DEFS = {
	{ key = "level.hunter", section = "level", default = true,
		label = "Celebrate Hunter training levels",
		tooltip = "Show a banner and burst when a level unlocks Hunter trainer spells." },
	{ key = "level.huntermilestone", section = "level", default = true,
		label = "Celebrate Hunter milestones",
		tooltip = "Use a large celebration at levels 10, 20, 30, 40, 50, and 60." },
	{ key = "level.pet", section = "level", default = true,
		label = "Celebrate pet training levels",
		tooltip = "Show a banner when your current pet gains a level with Pet Trainer spells." },
	{ key = "level.loyalty", section = "level", default = true,
		label = "Celebrate pet loyalty gains",
		tooltip = "Show a golden banner when your current pet gains a loyalty level." },
	{ key = "pet.celebrate", section = "pet", default = true,
		label = "Celebrate new pet abilities", labelKey = "ANIM_PET_CELEBRATE",
		tooltip = "Play a firework and a banner in the middle of the screen when your pet learns a new ability or a new rank.",
		tooltipKey = "ANIM_PET_CELEBRATE_TIP" },
	{ key = "pet.runaway", section = "pet", default = true,
		label = "Warn when a pet runs away", labelKey = "ANIM_PET_RUNAWAY",
		tooltip = "Flash a red, shaking banner in the middle of the screen when one of your pets runs away for good.",
		tooltipKey = "ANIM_PET_RUNAWAY_TIP" },
	{ key = "pet.happiness", section = "pet", default = true,
		label = "Flash zPet on happiness change", labelKey = "ANIM_PET_HAPPINESS",
		tooltip = "Briefly flash the pet happiness area green when your pet cheers up, or red when it gets unhappy.",
		tooltipKey = "ANIM_PET_HAPPINESS_TIP" },
	{ key = "pet.loyaltyup", section = "pet", default = true,
		label = "Glow zPet on loyalty gain", labelKey = "ANIM_PET_LOYALTYUP",
		tooltip = "Give a short golden glow when your pet gains a loyalty level.",
		tooltipKey = "ANIM_PET_LOYALTYUP_TIP" },
	{ key = "pet.feed", section = "pet", default = true,
		label = "Flash zPet when feeding your pet", labelKey = "ANIM_PET_FEED",
		tooltip = "Give a short green flash when Feed-O-Matic feeds your pet.",
		tooltipKey = "ANIM_PET_FEED_TIP" },
	{ key = "combat.ammoswap", section = "combat", default = true,
		label = "Flash zAmmo on Smart Ammo swap", labelKey = "ANIM_COMBAT_AMMOSWAP",
		tooltip = "Briefly highlight the zAmmo button when Smart Ammo swaps your ammo.",
		tooltipKey = "ANIM_COMBAT_AMMOSWAP_TIP" },
	{ key = "combat.ammoout", section = "combat", default = true,
		label = "Warn when current ammo runs out",
		tooltip = "Show a red warning banner when Smart Ammo equips fallback ammunition." },
	{ key = "combat.lowammo", section = "combat", default = true,
		label = "Warn when total ammo is low",
		tooltip = "Show a warning banner when your total arrows or bullets reach the Smart Ammo threshold." },
	{ key = "combat.ammozero", section = "combat", default = true,
		label = "Warn when all ammo is gone",
		tooltip = "Show a sarcastic warning banner when you have no arrows or bullets left." },
	{ key = "combat.rangedswap", section = "combat", default = true,
		label = "Flash zRanged on weapon swap", labelKey = "ANIM_COMBAT_RANGEDSWAP",
		tooltip = "Briefly highlight the zRanged button when you hot-swap a ranged weapon.",
		tooltipKey = "ANIM_COMBAT_RANGEDSWAP_TIP" },
	{ key = "combat.mmprocs", section = "combat", default = true,
		label = "Pulse MM Widget procs", labelKey = "ANIM_COMBAT_MMPROCS",
		tooltip = "Pulse an MM Widget cell when a Lock and Load or Experimental ammo proc lights up.",
		tooltipKey = "ANIM_COMBAT_MMPROCS_TIP" },
	{ key = "book.open", section = "book", default = true,
		label = "Fade in the Hunter's Book", labelKey = "ANIM_BOOK_OPEN",
		tooltip = "Fade the Hunter's Book window in when you open it.",
		tooltipKey = "ANIM_BOOK_OPEN_TIP" },
	{ key = "book.tabs", section = "book", default = true,
		label = "Fade Hunter's Book results on tab changes", labelKey = "ANIM_BOOK_TABS",
		tooltip = "Fade the results list back in when you switch tabs inside the Hunter's Book.",
		tooltipKey = "ANIM_BOOK_TABS_TIP" },
	{ key = "book.model", section = "book", default = true,
		label = "Fade Hunter's Book beast models", labelKey = "ANIM_BOOK_MODEL",
		tooltip = "Fade the beast model viewer in when it loads a new model.",
		tooltipKey = "ANIM_BOOK_MODEL_TIP" },
	{ key = "book.search", section = "book", default = true,
		label = "Fade Hunter's Book search results", labelKey = "ANIM_BOOK_SEARCH",
		tooltip = "Fade the results list when your search filter changes.",
		tooltipKey = "ANIM_BOOK_SEARCH_TIP" },
	{ key = "ui.options", section = "ui", default = true,
		label = "Slide MetaHunt Options open", labelKey = "ANIM_UI_OPTIONS",
		tooltip = "Slide and fade the MetaHunt options window in when you open it.",
		tooltipKey = "ANIM_UI_OPTIONS_TIP" },
	{ key = "ui.optiontabs", section = "ui", default = true,
		label = "Fade MetaHunt Options tab changes", labelKey = "ANIM_UI_OPTIONTABS",
		tooltip = "Fade the settings panel when you switch tabs inside the options window.",
		tooltipKey = "ANIM_UI_OPTIONTABS_TIP" },
	{ key = "ui.optionsclose", section = "ui", default = true,
		label = "Fade MetaHunt windows closed", labelKey = "ANIM_UI_OPTIONSCLOSE",
		tooltip = "Fade the options and Hunter's Book windows out when you close them.",
		tooltipKey = "ANIM_UI_OPTIONSCLOSE_TIP" },
	{ key = "ui.minimap", section = "ui", default = true,
		label = "Pulse MetaHunt minimap button on click", labelKey = "ANIM_UI_MINIMAP",
		tooltip = "Give the minimap button a quick pulse when you click it.",
		tooltipKey = "ANIM_UI_MINIMAP_TIP" },
	{ key = "ui.minimapping", section = "ui", default = true,
		label = "Ping minimap when locating a target", labelKey = "ANIM_UI_MINIMAPPING",
		tooltip = "Send a short ping ripple over the minimap when you locate a tracked NPC.",
		tooltipKey = "ANIM_UI_MINIMAPPING_TIP" },
	{ key = "ui.zbuttons", section = "ui", default = true,
		label = "Fade zButton bars open", labelKey = "ANIM_UI_ZBUTTONS",
		tooltip = "Fade the child buttons in when a collapsible zButton bar (pet, tracking, aspects...) expands.",
		tooltipKey = "ANIM_UI_ZBUTTONS_TIP" },
	{ key = "ui.zbar", section = "ui", default = true,
		label = "Fade the zBar in", labelKey = "ANIM_UI_ZBAR",
		tooltip = "Fade the unified zBar buttons in when the bar becomes active.",
		tooltipKey = "ANIM_UI_ZBAR_TIP" },
	{ key = "ui.stable", section = "ui", default = true,
		label = "Flash Hunter's Book stable slots", labelKey = "ANIM_UI_STABLE",
		tooltip = "Flash a stable slot in the Hunter's Book when a pet is deposited or withdrawn.",
		tooltipKey = "ANIM_UI_STABLE_TIP" },
	{ key = "ui.mappins", section = "ui", default = true,
		label = "Fade World Map markers in", labelKey = "ANIM_UI_MAPPINS",
		tooltip = "Fade the world map markers in when you locate a beast, vendor or master.",
		tooltipKey = "ANIM_UI_MAPPINS_TIP" },
}

local function MTH_FX_Store()
	if MTH and type(MTH.GetModuleSavedVariables) == "function" then
		return MTH:GetModuleSavedVariables("animations")
	end
	return nil
end

local function MTH_FX_DefaultFor(key)
	local i = 1
	while i <= table.getn(MTH_FX_ANIM_DEFS) do
		if MTH_FX_ANIM_DEFS[i].key == key then
			return MTH_FX_ANIM_DEFS[i].default and true or false
		end
		i = i + 1
	end
	return true
end

function MTH_FX_AnimationsEnabled()
	local store = MTH_FX_Store()
	if not store or store.enabled == nil then
		return true
	end
	return store.enabled and true or false
end

function MTH_FX_SetAnimationsEnabled(value)
	local store = MTH_FX_Store()
	if not store then return end
	store.enabled = value and true or false
end

function MTH_FX_GetFlag(key)
	local store = MTH_FX_Store()
	if store and store.flags and store.flags[key] ~= nil then
		return store.flags[key] and true or false
	end
	return MTH_FX_DefaultFor(key)
end

function MTH_FX_SetFlag(key, value)
	local store = MTH_FX_Store()
	if not store then return end
	store.flags = store.flags or {}
	store.flags[key] = value and true or false
end

-- Master gate every animation call site checks: false when animations are
-- globally disabled, or when this specific animation is turned off.
function MTH_FX_IsEnabled(key)
	if not MTH_FX_AnimationsEnabled() then
		return false
	end
	if key == nil then
		return true
	end
	return MTH_FX_GetFlag(key)
end

-- Register a one-shot "ballistic" tween type: a spark that flies out from the
-- center along a velocity vector while gravity pulls it back down.
if Sauce and type(Sauce.RegisterType) == "function" and not Sauce.MTH_HasBallistic then
	local ok, err = pcall(function()
		Sauce.MTH_HasBallistic = true
		Sauce:RegisterType("mth_ballistic", {
			init = function(target, from)
				return from or { 0, 0 }
			end,
			apply = function(target, from, to, t, tween)
				local dur = tween.dur or 1
				local elapsed = t * dur
				local vx = tween.vx or 0
				local vy = tween.vy or 0
				local gravity = tween.gravity or 0
				local x = from[1] + vx * elapsed
				local y = from[2] + vy * elapsed - 0.5 * gravity * elapsed * elapsed
				local anchor = tween.anchor or UIParent
				target:ClearAllPoints()
				target:SetPoint("CENTER", anchor, "CENTER", x, y)
			end,
		})
	end)
end

-- Register a decaying "shake" tween type: oscillates the frame around its own
-- current anchor point, with the amplitude fading to zero over the tween so it
-- always lands back exactly where it started. Used for negative events.
if Sauce and type(Sauce.RegisterType) == "function" and not Sauce.MTH_HasShake then
	local ok, err = pcall(function()
		Sauce.MTH_HasShake = true
		Sauce:RegisterType("mth_shake", {
			init = function(target)
				local p, rel, rp, x, y = target:GetPoint(1)
				return { p or "CENTER", rel, rp or p or "CENTER", x or 0, y or 0 }
			end,
			apply = function(target, from, to, t, tween)
				local mag = tween.magnitude or 8
				local freq = tween.freq or 34
				local decay = 1 - t
				local offset = math.sin(t * freq) * mag * decay
				target:ClearAllPoints()
				target:SetPoint(from[1], from[2], from[3], (from[4] or 0) + offset, from[5] or 0)
			end,
		})
	end)
end

if Sauce and type(Sauce.RegisterType) == "function" and not Sauce.MTH_HasSpiral then
	local ok, err = pcall(function()
		Sauce.MTH_HasSpiral = true
		Sauce:RegisterType("mth_spiral", {
			init = function(target, from)
				return from or 0
			end,
			apply = function(target, from, to, t, tween)
				local radius = (tween.radius or 0) * (1 - t)
				local angle = (tween.startAngle or 0) + (tween.rotations or 1) * 2 * math.pi * t
				target:ClearAllPoints()
				target:SetPoint("CENTER", tween.anchor or UIParent, "CENTER",
					(tween.cx or 0) + math.cos(angle) * radius,
					(tween.cy or 0) + math.sin(angle) * radius)
			end,
		})
	end)
end

-- Reusable flash: overlays a short additive colour glow on any frame/button and
-- fades it out. Safe on any frame that supports CreateTexture; silent no-op
-- otherwise. The overlay texture is cached on the frame for reuse.
function MTH_FX_Flash(frame, r, g, b, duration)
	if not Sauce or not frame then
		return
	end
	if type(frame.CreateTexture) ~= "function" then
		return
	end
	local tex = frame.mthFxFlash
	if not tex then
		tex = frame:CreateTexture(nil, "OVERLAY")
		tex:SetTexture("Interface\\Buttons\\CheckButtonHilight")
		tex:SetBlendMode("ADD")
		tex:SetAllPoints(frame)
		frame.mthFxFlash = tex
	end
	tex:SetVertexColor(r or 1, g or 1, b or 1)
	tex:SetAlpha(0)
	tex:Show()
	local dur = duration or 0.45
	Sauce:Stop(tex)
	Sauce:Sequence({
		Sauce:FadeTo(tex, 0.85, dur * 0.35),
		Sauce:FadeTo(tex, 0, dur * 0.65, "inQuad", {
			onFinish = function() tex:Hide() end,
		}),
	})
end


local MTH_FX_NUM_SPARKS = 22
local MTH_FX_NUM_CONFETTI = 48
local MTH_FX_NUM_BLACKHOLE = 40
local MTH_FX_Container
local MTH_FX_MsgFrame
local MTH_FX_TitleFS
local MTH_FX_SubFS
local MTH_FX_Sparks = {}
local MTH_FX_Confetti = {}
local MTH_FX_BlackHole = {}

-- Palette for the firework sparks (r, g, b), warm celebratory tones.
local MTH_FX_Colors = {
	{ 1.00, 0.82, 0.00 },
	{ 1.00, 0.45, 0.10 },
	{ 1.00, 0.20, 0.30 },
	{ 0.35, 0.70, 1.00 },
	{ 0.55, 1.00, 0.45 },
	{ 0.85, 0.50, 1.00 },
}

local function MTH_FX_EnsureFrames()
	if type(CreateFrame) ~= "function" then
		return false
	end
	if MTH_FX_Container then
		return true
	end

	MTH_FX_Container = CreateFrame("Frame", "MTH_FX_Container", UIParent)
	MTH_FX_Container:SetWidth(1)
	MTH_FX_Container:SetHeight(1)
	MTH_FX_Container:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	MTH_FX_Container:SetFrameStrata("FULLSCREEN_DIALOG")
	MTH_FX_Container:Hide()

	MTH_FX_MsgFrame = CreateFrame("Frame", "MTH_FX_Message", UIParent)
	MTH_FX_MsgFrame:SetWidth(512)
	MTH_FX_MsgFrame:SetHeight(90)
	MTH_FX_MsgFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
	MTH_FX_MsgFrame:SetFrameStrata("FULLSCREEN_DIALOG")

	MTH_FX_TitleFS = MTH_FX_MsgFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	MTH_FX_TitleFS:SetPoint("CENTER", MTH_FX_MsgFrame, "CENTER", 0, 14)
	MTH_FX_TitleFS:SetTextColor(1, 0.82, 0)

	MTH_FX_SubFS = MTH_FX_MsgFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	MTH_FX_SubFS:SetPoint("TOP", MTH_FX_TitleFS, "BOTTOM", 0, -8)
	MTH_FX_SubFS:SetTextColor(1, 1, 1)

	MTH_FX_MsgFrame:Hide()

	local i = 1
	while i <= MTH_FX_NUM_SPARKS do
		local spark = MTH_FX_Container:CreateTexture(nil, "OVERLAY")
		spark:SetTexture("Interface\\Cooldown\\star4")
		spark:SetWidth(22)
		spark:SetHeight(22)
		spark:SetBlendMode("ADD")
		spark:SetPoint("CENTER", MTH_FX_Container, "CENTER", 0, 0)
		spark:Hide()
		MTH_FX_Sparks[i] = spark
		i = i + 1
	end

	i = 1
	while i <= MTH_FX_NUM_CONFETTI do
		local bit = MTH_FX_Container:CreateTexture(nil, "OVERLAY")
		bit:SetTexture("Interface\\Buttons\\WHITE8X8")
		bit:SetWidth(5)
		bit:SetHeight(8)
		bit:SetPoint("CENTER", MTH_FX_Container, "CENTER", 0, 0)
		bit:Hide()
		MTH_FX_Confetti[i] = bit
		i = i + 1
	end

	i = 1
	while i <= MTH_FX_NUM_BLACKHOLE do
		local particle = MTH_FX_Container:CreateTexture(nil, "OVERLAY")
		particle:SetTexture("Interface\\Cooldown\\star4")
		particle:SetWidth(10)
		particle:SetHeight(10)
		particle:SetBlendMode("ADD")
		particle:SetPoint("CENTER", MTH_FX_Container, "CENTER", 0, 0)
		particle:Hide()
		MTH_FX_BlackHole[i] = particle
		i = i + 1
	end

	return true
end

-- Public entry point: play a full-screen celebration. `style` defaults to the
-- original firework burst and may be firework, victory, starfall, fanfare, or comet.
function MTH_Celebrate(title, subtitle, style, displaySeconds)
	if not Sauce then
		return
	end
	if not MTH_FX_EnsureFrames() then
		return
	end
	style = string.lower(tostring(style or "firework"))
	local fadeDelay = tonumber(displaySeconds) or 5
	if fadeDelay < 0.5 then fadeDelay = 0.5 end

	if style == "starfall" then
		MTH_FX_TitleFS:SetTextColor(0.45, 0.80, 1.00)
	else
		MTH_FX_TitleFS:SetTextColor(1, 0.82, 0)
	end
	MTH_FX_TitleFS:SetText(title or "")
	MTH_FX_SubFS:SetText(subtitle or "")

	Sauce:Stop(MTH_FX_MsgFrame)
	MTH_FX_MsgFrame:SetAlpha(0)
	MTH_FX_MsgFrame:Show()
	if style == "victory" or style == "fanfare" then
		Sauce:Sequence({
			Sauce:Group({
				Sauce:SlideIn(MTH_FX_MsgFrame, "UP", 80, 0.36, "outBack", { defer = true }),
				Sauce:Pulse(MTH_FX_MsgFrame, style == "victory" and 1.32 or 1.18, 0.52, { defer = true }),
			}),
			Sauce:FadeOut(MTH_FX_MsgFrame, 0.6, "inQuad", { delay = fadeDelay }),
		})
	else
		Sauce:Sequence({
			Sauce:Group({
				Sauce:FadeTo(MTH_FX_MsgFrame, 1, 0.25),
				Sauce:Pulse(MTH_FX_MsgFrame, 1.22, 0.5),
			}),
			Sauce:FadeOut(MTH_FX_MsgFrame, 0.6, "inQuad", { delay = fadeDelay }),
		})
	end

	MTH_FX_Container:Show()
	local colorCount = table.getn(MTH_FX_Colors)
	local colorIdx = 0
	local i = 1
	while i <= MTH_FX_NUM_SPARKS do
		local spark = MTH_FX_Sparks[i]
		spark:SetTexture("Interface\\Cooldown\\star4")
		spark:SetTexCoord(0, 1, 0, 1)
		local startX, startY = 0, 0
		local delay, gravity = 0, 300
		local angle = (i / MTH_FX_NUM_SPARKS) * 2 * math.pi + (math.random() - 0.5) * 0.4
		local speed = 150 + math.random() * 130
		local vx = math.cos(angle) * speed
		local vy = math.sin(angle) * speed + 70
		local dur = 0.9 + math.random() * 0.4

		if style == "victory" then
			startX = ((i - math.floor(i / 2) * 2) == 0) and -130 or 130
			speed = 100 + math.random() * 100
			vx = math.cos(angle) * speed
			vy = math.sin(angle) * speed + 105
		elseif style == "starfall" then
			startX = -230 + math.random() * 460
			startY = 200 + math.random() * 100
			vx = -35 + math.random() * 70
			vy = -10 + math.random() * 25
			gravity = 235
			dur = 1.1 + math.random() * 0.5
		elseif style == "fanfare" then
			delay = ((i - 1) - math.floor((i - 1) / 3) * 3) * 0.18
			speed = 110 + math.random() * 90
			vx = math.cos(angle) * speed
			vy = math.sin(angle) * speed + 90
		elseif style == "comet" then
			if i == 1 then
				startY = -180
				vx, vy, gravity, dur = 0, 430, 0, 0.52
			else
				delay = 0.5
				startY = 45
				speed = 130 + math.random() * 120
				vx = math.cos(angle) * speed
				vy = math.sin(angle) * speed + 70
			end
		end

		colorIdx = colorIdx + 1
		if colorIdx > colorCount then colorIdx = 1 end
		local color = MTH_FX_Colors[colorIdx]
		spark:SetVertexColor(color[1], color[2], color[3])
		spark:SetAlpha(delay > 0 and 0 or 1)
		spark:Show()

		Sauce:Stop(spark)
		Sauce:Group({
			Sauce:Tween(spark, {
				type = "mth_ballistic",
				from = { startX, startY },
				duration = dur,
				easing = "linear",
				delay = delay,
				anchor = MTH_FX_Container,
				dur = dur,
				vx = vx,
				vy = vy,
				gravity = gravity,
			}),
			Sauce:FadeTo(spark, 1, 0.05, "outQuad", { delay = delay }),
			Sauce:FadeTo(spark, 0, 0.45, "inQuad", {
				delay = delay + dur - 0.45,
				onFinish = function()
					spark:Hide()
				end,
			}),
		})
		i = i + 1
	end
end

local function MTH_FX_ShowPreviewBanner(title, subtitle, r, g, b)
	MTH_FX_TitleFS:SetTextColor(r, g, b)
	MTH_FX_TitleFS:SetText(title)
	MTH_FX_SubFS:SetText(subtitle)
	Sauce:Stop(MTH_FX_MsgFrame)
	MTH_FX_MsgFrame:SetAlpha(0)
	MTH_FX_MsgFrame:Show()
	Sauce:Sequence({
		Sauce:Group({
			Sauce:FadeTo(MTH_FX_MsgFrame, 1, 0.18),
			Sauce:Pulse(MTH_FX_MsgFrame, 1.18, 0.45),
		}),
		Sauce:FadeOut(MTH_FX_MsgFrame, 0.55, "inQuad", { delay = 5 }),
	})
end

function MTH_CelebrateConfetti(title, subtitle)
	if not Sauce or not MTH_FX_EnsureFrames() then return end
	MTH_FX_ShowPreviewBanner(title or "Celebration!", subtitle or "Confetti", 1, 0.82, 0.15)
	MTH_FX_Container:Show()
	local count = table.getn(MTH_FX_Colors)
	local i = 1
	while i <= MTH_FX_NUM_CONFETTI do
		local bit = MTH_FX_Confetti[i]
		local color = MTH_FX_Colors[((i - 1) - math.floor((i - 1) / count) * count) + 1]
		local size = 3 + math.random() * 5
		local angle = math.random() * 2 * math.pi
		local speed = 90 + math.random() * 210
		local dur = 1.25 + math.random() * 0.7
		bit:SetWidth(size)
		bit:SetHeight(size * 1.6)
		bit:SetVertexColor(color[1], color[2], color[3])
		bit:SetAlpha(1)
		bit:Show()
		Sauce:Stop(bit)
		Sauce:Group({
			Sauce:Tween(bit, {
				type = "mth_ballistic", from = { 0, 0 }, duration = dur,
				easing = "linear", anchor = MTH_FX_Container, dur = dur,
				vx = math.cos(angle) * speed, vy = math.sin(angle) * speed + 100, gravity = 255,
			}),
			Sauce:FadeTo(bit, 0, 0.35, "inQuad", {
				delay = dur - 0.35, onFinish = function() bit:Hide() end,
			}),
		})
		i = i + 1
	end
end

function MTH_CelebrateBlackHole(title, subtitle)
	if not Sauce or not MTH_FX_EnsureFrames() then return end
	MTH_FX_ShowPreviewBanner(title or "Gravity Well", subtitle or "Black Hole", 0.68, 0.45, 1.00)
	MTH_FX_Container:Show()
	local colors = { { 0.45, 0.25, 1 }, { 0.30, 0.50, 1 }, { 0.80, 0.55, 1 } }
	local i = 1
	while i <= MTH_FX_NUM_BLACKHOLE do
		local particle = MTH_FX_BlackHole[i]
		local color = colors[((i - 1) - math.floor((i - 1) / 3) * 3) + 1]
		local startAngle = math.random() * 2 * math.pi
		local radius = 95 + math.random() * 145
		local duration = 1.5 + math.random() * 1.0
		local size = 7 + math.random() * 8
		particle:SetWidth(size)
		particle:SetHeight(size)
		particle:SetVertexColor(color[1], color[2], color[3])
		particle:SetAlpha(1)
		particle:Show()
		Sauce:Stop(particle)
		Sauce:Group({
			Sauce:Tween(particle, {
				type = "mth_spiral", from = 0, to = 1, duration = duration,
				easing = "inQuad", anchor = MTH_FX_Container, cx = 0, cy = 0,
				radius = radius, startAngle = startAngle, rotations = 1.5 + math.random() * 2.0,
			}),
			Sauce:Size(particle, { size, size }, { 2, 2 }, duration, "inQuad"),
			Sauce:FadeTo(particle, 0, duration * 0.3, "inQuad", {
				delay = duration * 0.7, onFinish = function() particle:Hide() end,
			}),
		})
		i = i + 1
	end
end

function MTH_CelebrateShockwave(title, subtitle)
	if not Sauce or not MTH_FX_EnsureFrames() then return end
	MTH_FX_ShowPreviewBanner(title or "Impact!", subtitle or "Shockwave", 1, 0.62, 0.15)
	MTH_FX_Container:Show()
	local dotsPerWave = 16
	local i = 1
	while i <= MTH_FX_NUM_CONFETTI do
		local dot = MTH_FX_Confetti[i]
		local wave = math.floor((i - 1) / dotsPerWave) + 1
		local pos = (i - 1) - math.floor((i - 1) / dotsPerWave) * dotsPerWave
		local angle = pos / dotsPerWave * 2 * math.pi
		local duration = 1.1 + wave * 0.18
		local radius = 115 + wave * 52
		local delay = (wave - 1) * 0.18
		local intensity = 1 - (wave - 1) * 0.20
		dot:SetWidth(5)
		dot:SetHeight(5)
		dot:SetVertexColor(1 * intensity, 0.65 * intensity, 0.18 * intensity)
		dot:SetAlpha(0)
		dot:Show()
		Sauce:Stop(dot)
		Sauce:Group({
			Sauce:Tween(dot, {
				type = "mth_ballistic", from = { 0, 0 }, duration = duration,
				easing = "outQuad", delay = delay, anchor = MTH_FX_Container, dur = duration,
				vx = math.cos(angle) * radius / duration, vy = math.sin(angle) * radius / duration, gravity = 0,
			}),
			Sauce:FadeTo(dot, 1, 0.04, "outQuad", { delay = delay }),
			Sauce:FadeTo(dot, 0, 0.4, "inQuad", {
				delay = delay + duration - 0.4, onFinish = function() dot:Hide() end,
			}),
		})
		i = i + 1
	end
end

function MTH_CelebrateShatter(title, subtitle)
	if not Sauce or not MTH_FX_EnsureFrames() then return end
	MTH_FX_ShowPreviewBanner(title or "Shattered!", subtitle or "Shatter", 0.70, 0.85, 1.00)
	MTH_FX_Container:Show()
	local grid = 4
	local iconSize = 80
	local fragmentSize = iconSize / grid
	local i = 1
	while i <= MTH_FX_NUM_SPARKS do
		local spark = MTH_FX_Sparks[i]
		if i <= grid * grid then
			local row = math.floor((i - 1) / grid)
			local col = (i - 1) - row * grid
			local x = (col - grid / 2 + 0.5) * fragmentSize
			local y = ((grid - 1 - row) - grid / 2 + 0.5) * fragmentSize
			local duration = 1.1 + math.random() * 0.45
			spark:SetTexture("Interface\\Icons\\Ability_Hunter_SniperShot")
			spark:SetTexCoord(col / grid, (col + 1) / grid, row / grid, (row + 1) / grid)
			spark:SetWidth(fragmentSize)
			spark:SetHeight(fragmentSize)
			spark:SetVertexColor(1, 1, 1)
			spark:SetAlpha(1)
			spark:Show()
			Sauce:Stop(spark)
			Sauce:Group({
				Sauce:Tween(spark, {
					type = "mth_ballistic", from = { x, y }, duration = duration,
					easing = "linear", anchor = MTH_FX_Container, dur = duration,
					vx = x * 4 + (math.random() - 0.5) * 90,
					vy = y * 4 + 95 + math.random() * 80, gravity = 265,
				}),
				Sauce:FadeTo(spark, 0, 0.35, "inQuad", {
					delay = duration - 0.35, onFinish = function() spark:Hide() end,
				}),
			})
		end
		i = i + 1
	end
end

function MTH_CelebratePreview(style)
	style = string.lower(tostring(style or "firework"))
	if style == "all" then
		if not Sauce then return end
		local styles = { "firework", "blackhole", "shockwave", "shatter" }
		local steps = {}
		local i = 1
		while i <= table.getn(styles) do
			local previewStyle = styles[i]
			table.insert(steps, Sauce:Run(function()
				MTH_CelebratePreview(previewStyle)
			end, { defer = true }))
			table.insert(steps, Sauce:Delay(5.7))
			i = i + 1
		end
		Sauce:Sequence(steps)
		return true
	end

	if style == "blackhole" then
		MTH_CelebrateBlackHole("Celebration Preview", "Black Hole")
		return true
	elseif style == "shockwave" then
		MTH_CelebrateShockwave("Celebration Preview", "Shockwave")
		return true
	elseif style == "shatter" then
		MTH_CelebrateShatter("Celebration Preview", "Shatter")
		return true
	end

	local labels = {
		firework = "Firework Burst",
	}
	if not labels[style] then return false end
	MTH_Celebrate("Celebration Preview", labels[style], style)
	return true
end

-- Convenience wrapper used when the hunter's pet learns a new ability/rank.
function MTH_CelebratePetAbility(label)
	if not MTH_FX_IsEnabled("pet.celebrate") then
		return
	end
	MTH_Celebrate(MTH_FX_L("ANIM_PET_LEARNED_TITLE", "New Pet Ability!"), label)
end

-- Dramatic negative banner: a red, shaking message shown when a pet runs away
-- for good. Gated on pet.runaway. Reuses the shared message frame.
function MTH_CelebrateRunaway(petName)
	if not MTH_FX_IsEnabled("pet.runaway") then
		return
	end
	if not Sauce then
		return
	end
	if not MTH_FX_EnsureFrames() then
		return
	end

	MTH_FX_TitleFS:SetTextColor(1, 0.15, 0.15)
	MTH_FX_TitleFS:SetText(MTH_FX_L("ANIM_PET_RUNAWAY_TITLE", "Your pet ran away!"))
	MTH_FX_SubFS:SetText(petName or "")

	Sauce:Stop(MTH_FX_MsgFrame)
	MTH_FX_MsgFrame:SetAlpha(0)
	MTH_FX_MsgFrame:Show()
	Sauce:Sequence({
		Sauce:FadeTo(MTH_FX_MsgFrame, 1, 0.18),
		Sauce:Tween(MTH_FX_MsgFrame, {
			type = "mth_shake",
			duration = 0.55,
			easing = "linear",
			magnitude = 11,
			freq = 42,
		}),
		Sauce:FadeOut(MTH_FX_MsgFrame, 0.7, "inQuad", { delay = 5 }),
	})
end

function MTH_CelebrateAmmoFallback(previousAmmo, newAmmo)
	if not MTH_FX_IsEnabled("combat.ammoout") or not Sauce or not MTH_FX_EnsureFrames() then return end

	MTH_FX_TitleFS:SetTextColor(1, 0.15, 0.15)
	MTH_FX_TitleFS:SetText("Out of " .. tostring(previousAmmo or "ammo") .. "!")
	MTH_FX_SubFS:SetText("Equipped " .. tostring(newAmmo or "fallback ammunition"))

	Sauce:Stop(MTH_FX_MsgFrame)
	MTH_FX_MsgFrame:SetAlpha(0)
	MTH_FX_MsgFrame:Show()
	Sauce:Sequence({
		Sauce:FadeTo(MTH_FX_MsgFrame, 1, 0.18),
		Sauce:Tween(MTH_FX_MsgFrame, {
			type = "mth_shake",
			duration = 0.55,
			easing = "linear",
			magnitude = 11,
			freq = 42,
		}),
		Sauce:FadeOut(MTH_FX_MsgFrame, 0.7, "inQuad", { delay = 5 }),
	})
end

function MTH_CelebrateLowAmmo(ammoType, total)
	if not MTH_FX_IsEnabled("combat.lowammo") or not Sauce or not MTH_FX_EnsureFrames() then return end
	MTH_FX_TitleFS:SetTextColor(1, 0.55, 0.10)
	MTH_FX_TitleFS:SetText("Running low on " .. tostring(ammoType or "ammo") .. "!")
	MTH_FX_SubFS:SetText(tostring(total or 0) .. " left before you're reduced to harsh language.")

	Sauce:Stop(MTH_FX_MsgFrame)
	MTH_FX_MsgFrame:SetAlpha(0)
	MTH_FX_MsgFrame:Show()
	Sauce:Sequence({
		Sauce:FadeTo(MTH_FX_MsgFrame, 1, 0.18),
		Sauce:Tween(MTH_FX_MsgFrame, {
			type = "mth_shake",
			duration = 0.55,
			easing = "linear",
			magnitude = 11,
			freq = 42,
		}),
		Sauce:FadeOut(MTH_FX_MsgFrame, 0.7, "inQuad", { delay = 5 }),
	})
end

function MTH_CelebrateAmmoZero(ammoType)
	if not MTH_FX_IsEnabled("combat.ammozero") or not Sauce or not MTH_FX_EnsureFrames() then return end
	MTH_FX_TitleFS:SetTextColor(1, 0.15, 0.15)
	MTH_FX_TitleFS:SetText("Out of " .. tostring(ammoType or "ammo") .. "!")
	MTH_FX_SubFS:SetText("Your ranged weapon is now a very expensive club. Well done.")

	Sauce:Stop(MTH_FX_MsgFrame)
	MTH_FX_MsgFrame:SetAlpha(0)
	MTH_FX_MsgFrame:Show()
	Sauce:Sequence({
		Sauce:FadeTo(MTH_FX_MsgFrame, 1, 0.18),
		Sauce:Tween(MTH_FX_MsgFrame, {
			type = "mth_shake",
			duration = 0.55,
			easing = "linear",
			magnitude = 11,
			freq = 42,
		}),
		Sauce:FadeOut(MTH_FX_MsgFrame, 0.7, "inQuad", { delay = 5 }),
	})
end
