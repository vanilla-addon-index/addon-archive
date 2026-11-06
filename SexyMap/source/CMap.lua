local useUiScale = tonumber(GetCVar("useUiScale"))
local uiScale = GetCVar("uiScale")
if useUiScale ~= 1 then uiScale = 1 end
frameWidth = UIParent:GetWidth() / uiScale
xMiddle = frameWidth / 2
frameHeight = UIParent:GetHeight() / uiScale
yMiddle = frameHeight / 2
frameScale = 0.75999999046326
local _G = getfenv(0)
local timeElapsed = 0
local updateTime = 1/60
CTextures = {}
CRotateTextures = {}

-- Default minimap dimensions (before any scaling)
local defaultMinimapWidth = 140
local defaultMinimapHeight = 140

-- Track hidden minimap buttons so we can restore them
local hiddenMinimapButtons = {}


-- Minimap cluster Show hook state (for minimap hide/show toggle)
local minimapClusterHooked = false
local minimapClusterOrigShow = nil
local minimapOrigShow = nil

-- Minimap button Show hook state
local minimapBtnHooked = false

-- Saved original Show functions for minimap buttons
local hiddenBtnOrigShows = {}

-- Saved original anchor points for minimap buttons (so positions are preserved across hide/show)
-- Format: hiddenBtnOrigPoints[frame] = { {point, relativeTo, relativePoint, xOfs, yOfs}, ... }
local hiddenBtnOrigPoints = {}

-- Addon version for SavedVariables migration
local ADDON_VERSION = 8

local function print(msg)
	if msg and msg ~= "" then
		DEFAULT_CHAT_FRAME:AddMessage(msg, 1, 1, 0)
	end
end

function deepCopyHash(t)
	if t == nil then return nil end
	local nt = {}
	for k, v in pairs(t) do
		if type(v) == "table" then
			nt[k] = deepCopyHash(v)
		else
			nt[k] = v
		end
	end
	return nt
end

function destroyTable(t)
	setmetatable(t, nil)
	for k,v in pairs(t) do
		t[k] = nil
	end
end

-- ============================================
-- SavedVariables Migration
-- ============================================
-- Detects and fixes stale/invalid data from older addon versions.
-- Called during PLAYER_ENTERING_WORLD before any settings are applied.
local function MigrateSavedVariables()
	if not SexyMap2DB then
		SexyMap2DB = {}
	end

	-- Version-based migration: if the saved version is older than current,
	-- apply fixes. This runs ONCE per version bump.
	local savedVersion = SexyMap2DB.version or 0

	-- Always check for invalid data regardless of version,
	-- since the user might have stale data from before version tracking existed.

	-- Fix empty borders array (from v1.4 when some presets had empty borders)
	if SexyMap2DB.borders == nil or (type(SexyMap2DB.borders) == "table" and table.getn(SexyMap2DB.borders) == 0 and next(SexyMap2DB.borders) == nil) then
		SexyMap2DB.borders = deepCopyHash(borderPresets["Diablo by Zork"].borders)
		print("[SexyMap] Migrated: empty borders reset to default preset.")
	end

	-- Fix backdrop with invalid/missing data
	if SexyMap2DB.backdrop == nil then
		SexyMap2DB.backdrop = deepCopyHash(borderPresets["Diablo by Zork"].backdrop)
		print("[SexyMap] Migrated: missing backdrop reset to default preset.")
	else
		-- Fix empty borderColor/textureColor that cause green rendering
		if SexyMap2DB.backdrop.borderColor == nil or (type(SexyMap2DB.backdrop.borderColor) == "table" and next(SexyMap2DB.backdrop.borderColor) == nil) then
			SexyMap2DB.backdrop.borderColor = { r = 1, g = 1, b = 1, a = 1 }
		end
		if SexyMap2DB.backdrop.textureColor == nil or (type(SexyMap2DB.backdrop.textureColor) == "table" and next(SexyMap2DB.backdrop.textureColor) == nil) then
			SexyMap2DB.backdrop.textureColor = { r = 0, g = 0, b = 0, a = 1 }
		end
		-- Fix settings with .blp in edgeFile/bgFile (WoW 1.12 auto-appends .blp)
		if SexyMap2DB.backdrop.settings then
			local s = SexyMap2DB.backdrop.settings
			if s.edgeFile and string.find(s.edgeFile, "%.blp$") then
				s.edgeFile = string.gsub(s.edgeFile, "%.blp$", "")
				print("[SexyMap] Migrated: removed .blp from backdrop edgeFile.")
			end
			if s.bgFile and string.find(s.bgFile, "%.blp$") then
				s.bgFile = string.gsub(s.bgFile, "%.blp$", "")
				print("[SexyMap] Migrated: removed .blp from backdrop bgFile.")
			end
		end
	end

	-- Fix missing/empty shape
	if SexyMap2DB.shape == nil or SexyMap2DB.shape == "" then
		SexyMap2DB.shape = "Round"
	end

	-- Ensure all expected fields exist
	if SexyMap2DB.showZoneText == nil then
		SexyMap2DB.showZoneText = true
	end
	if SexyMap2DB.showMinimapButtons == nil then
		SexyMap2DB.showMinimapButtons = true
	end
	if SexyMap2DB.mapScale == nil then
		SexyMap2DB.mapScale = 1.0
	end
	if SexyMap2DB.showMinimap == nil then
		SexyMap2DB.showMinimap = true
	end
	if not SexyMap2DB.userPresets then
		SexyMap2DB.userPresets = {}
	end
	if not SexyMap2DB.buttonPositions then
		SexyMap2DB.buttonPositions = {}
	end

	-- Mark the current version so migration doesn't re-run needlessly
	-- (but the checks above still protect against manually-edited bad data)
	SexyMap2DB.version = ADDON_VERSION
end

function CMap_OnLoad()
	print("[SexyMap] v1.8 loaded for OctoWoW. Type '/sm' or '/sexymap' to open the menu.")
	this:SetScript("OnEvent", CMap_OnEvent)
	this:SetScript("OnUpdate", CMap_OnUpdate)
	this:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function CMap_OnEvent()
	if event == "PLAYER_ENTERING_WORLD" then
		this:UnregisterEvent("PLAYER_ENTERING_WORLD")

		-- Run migration FIRST, before any settings are applied
		MigrateSavedVariables()

		-- Capture the default minimap dimensions before we modify anything
		defaultMinimapWidth = Minimap:GetWidth()
		defaultMinimapHeight = Minimap:GetHeight()

		CreateFrame("Frame", "CMinimapBackdrop", Minimap)
		CMinimapBackdrop:SetFrameStrata("BACKGROUND")
		CMinimapBackdrop:SetFrameLevel(CMinimapBackdrop:GetFrameLevel() - 1)
		CMinimapBackdrop:SetPoint("CENTER", Minimap, "CENTER")
		CMinimapBackdrop:SetWidth(Minimap:GetWidth())
		CMinimapBackdrop:SetHeight(Minimap:GetHeight())
		-- Set an explicit default backdrop so the frame never renders as green
		-- (a frame with no backdrop set can render as solid green in WoW 1.12)
		CMinimapBackdrop:SetBackdrop({
			bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = false,
			edgeSize = 16,
			insets = { left = 4, right = 4, top = 4, bottom = 4 }
		})
		CMinimapBackdrop:SetBackdropColor(0, 0, 0, 1)
		CMinimapBackdrop:SetBackdropBorderColor(1, 1, 1, 1)

		CHideAnnoyingStuff()
		CUpdateZoneText()
		CUpdateMinimapButtonsVisibility()
		CUpdateMinimapVisibility()
		CApplyMapScale()
		CLoadArtwork()
		CApplyButtonPositions()
		SlashCmdList["CMAP"] = CMap_SlashCmdHandler
		SLASH_CMAP1 = "/cm"
		SLASH_CMAP2 = "/sm"
		SLASH_CMAP3 = "/sexymap"
	end
end


function CMap_OnUpdate()
	timeElapsed = timeElapsed + arg1
	if timeElapsed >= updateTime then
		for k,v in pairs(CRotateTextures) do
			CRotateTexture(_G[k], v * timeElapsed)
		end
		timeElapsed = 0
	end
end


function CMap_SlashCmdHandler(msg)
	if not CMinimapOptionFrame.menuState then
		CInitiateMenu()
	else
		CHideMenu()
	end
end


function CHideAnnoyingStuff()
	-- Hide the default minimap border art (we draw our own borders)
	MinimapBorder:Hide()
	MinimapBorderTop:Hide()
	-- Hide the X button (minimap toggle) — we now control this from the GUI
	MinimapToggleButton:Hide()
	-- Hide zoom buttons ( SexyMap handles its own zoom or user doesn't need them )
	MinimapZoomIn:Hide()
	MinimapZoomOut:Hide()
	-- Style the zone text font
	MinimapZoneText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
end

-- ============================================
-- Minimap visibility (replaces the X button)
-- ============================================
-- In vanilla WoW 1.12, MinimapToggleButton calls ToggleMinimap() which
-- hides/shows just the Minimap frame. We replace this with a full
-- MinimapCluster hide/show controlled from the GUI, and hook Show/Hide
-- to prevent anything from re-showing the minimap when it should be hidden.

local function MinimapClusterHookedShow(self)
	if not SexyMap2DB.showMinimap then
		return  -- Block the Show, minimap stays hidden
	end
	if minimapClusterOrigShow then
		minimapClusterOrigShow(self)
	end
end

local function MinimapHookedShow(self)
	if not SexyMap2DB.showMinimap then
		return  -- Block the Show, minimap stays hidden
	end
	if minimapOrigShow then
		minimapOrigShow(self)
	end
end

function CUpdateMinimapVisibility()
	if SexyMap2DB.showMinimap then
		-- Show the minimap cluster - unhook first
		if minimapClusterHooked then
			if MinimapCluster then
				MinimapCluster.Show = minimapClusterOrigShow
			end
			if Minimap then
				Minimap.Show = minimapOrigShow
			end
			minimapClusterHooked = false
			minimapClusterOrigShow = nil
			minimapOrigShow = nil
		end
		-- Show everything
		if MinimapCluster then MinimapCluster:Show() end
		if Minimap then Minimap:Show() end
		-- Re-apply our hidden stuff (borders, zoom buttons, X button stay hidden)
		CHideAnnoyingStuff()
		-- Re-apply button visibility settings
		CUpdateMinimapButtonsVisibility()
	else
		-- Hide the entire minimap cluster and hook Show to prevent re-appearance
		if MinimapCluster then
			if not minimapClusterHooked then
				minimapClusterOrigShow = MinimapCluster.Show
				MinimapCluster.Show = MinimapClusterHookedShow
				minimapOrigShow = Minimap.Show
				Minimap.Show = MinimapHookedShow
				minimapClusterHooked = true
			end
			MinimapCluster:Hide()
		end
	end
end

-- ============================================
-- Minimap buttons visibility
-- ============================================

local function MinimapBtnHookedShow(self)
	if not SexyMap2DB.showMinimapButtons then
		return  -- Block Show while buttons should be hidden
	end
	-- When buttons are allowed, call the original Show
	local orig = hiddenBtnOrigShows[self]
	if orig then
		orig(self)
	end
end

-- Save a frame's current anchor points so we can restore them later
local function SaveButtonPoints(frame)
	local points = {}
	local numPoints = frame:GetNumPoints()
	if numPoints and numPoints > 0 then
		for i = 1, numPoints do
			local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint(i)
			if point then
				table.insert(points, {
					point = point,
					relativeTo = relativeTo,
					relativePoint = relativePoint,
					xOfs = xOfs,
					yOfs = yOfs,
				})
			end
		end
	end
	-- Only store if we actually got points; don't overwrite existing saved points with empty
	if table.getn(points) > 0 then
		hiddenBtnOrigPoints[frame] = points
	end
end

-- Restore a frame's saved anchor points
local function RestoreButtonPoints(frame)
	local points = hiddenBtnOrigPoints[frame]
	if points and table.getn(points) > 0 then
		frame:ClearAllPoints()
		for _, pt in ipairs(points) do
			frame:SetPoint(pt.point, pt.relativeTo, pt.relativePoint, pt.xOfs, pt.yOfs)
		end
	end
	-- Clean up saved points for this frame
	hiddenBtnOrigPoints[frame] = nil
end

-- ============================================
-- Persistent minimap button positions
-- ============================================
-- Minimap buttons are children of the (scaled) MinimapCluster / Minimap.
-- When the user drags one, we save its position in UIParent screen space
-- (i.e. multiplied by its effective scale, divided by UIParent effective
-- scale) so that changing the map scale later does NOT visually move the
-- button. On login we restore that same on-screen center regardless of
-- the current map scale.

-- Frames we have already made draggable / hooked (avoid double-hooking).
local dragEnabledButtons = {}

-- Save a frame's on-screen center to SavedVariables, keyed by frame name.
local function CSaveButtonScreenPos(frame)
	if not frame or not frame.GetName or not frame.GetCenter then return end
	local name = frame:GetName()
	if not name or name == "" then return end
	local x, y = frame:GetCenter()
	if not x or not y then return end
	local fScale = frame:GetEffectiveScale() or 1
	local uScale = UIParent:GetEffectiveScale() or 1
	if uScale == 0 then uScale = 1 end
	-- Convert into UIParent-space (screen) coordinates.
	local ux = x * fScale / uScale
	local uy = y * fScale / uScale
	if not SexyMap2DB.buttonPositions then
		SexyMap2DB.buttonPositions = {}
	end
	SexyMap2DB.buttonPositions[name] = { x = ux, y = uy }
end

-- Restore a frame to its saved on-screen center, compensating for the
-- current parent scale so it lands in the same screen pixel.
local function CRestoreButtonScreenPos(frame)
	if not frame or not frame.GetName or not frame.ClearAllPoints then return end
	local name = frame:GetName()
	if not name or name == "" then return end
	if not SexyMap2DB.buttonPositions then return end
	local saved = SexyMap2DB.buttonPositions[name]
	if not saved or not saved.x or not saved.y then return end
	local fScale = frame:GetEffectiveScale() or 1
	if fScale == 0 then fScale = 1 end
	local uScale = UIParent:GetEffectiveScale() or 1
	-- Convert UIParent-space coords back into the frame's own coord space.
	local fx = saved.x * uScale / fScale
	local fy = saved.y * uScale / fScale
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", fx, fy)
end

-- OnDragStart / OnDragStop handlers used by hooked buttons.
local function CButton_OnDragStart()
	if this and this.StartMoving then
		this:StartMoving()
	end
end

local function CButton_OnDragStop()
	if this then
		if this.StopMovingOrSizing then this:StopMovingOrSizing() end
		CSaveButtonScreenPos(this)
	end
end

-- Make a single frame movable + save on drag stop. Safe to call repeatedly.
local function CEnableDragForButton(frame)
	if not frame or dragEnabledButtons[frame] then return end
	-- Guard: must be a real Frame-derived object (not a Texture/FontString).
	if type(frame) ~= "table" or not frame.GetObjectType then return end
	local ok, objType = pcall(frame.GetObjectType, frame)
	if not ok or not objType then return end
	if objType ~= "Frame" and objType ~= "Button" and objType ~= "CheckButton" then return end
	if not frame.GetScript or not frame.SetScript then return end
	local name = frame:GetName()
	if not name or name == "" then return end
	if frame.SetMovable then frame:SetMovable(true) end
	if frame.RegisterForDrag then frame:RegisterForDrag("LeftButton") end
	local origStart = frame:GetScript("OnDragStart")
	local origStop  = frame:GetScript("OnDragStop")
	frame:SetScript("OnDragStart", function()
		if origStart then origStart() end
		CButton_OnDragStart()
	end)
	frame:SetScript("OnDragStop", function()
		CButton_OnDragStop()
		if origStop then origStop() end
	end)
	dragEnabledButtons[frame] = true
end

-- Iterate all current minimap side buttons: make them draggable and
-- restore any saved position. Called on login (after CApplyMapScale) and
-- again whenever the map scale changes.
function CApplyButtonPositions()
	if not Minimap then return end

	local excludeNames = {
		["MinimapZoomIn"] = true,
		["MinimapZoomOut"] = true,
		["MinimapToggleButton"] = true,
		["CMinimapBackdrop"] = true,
		["MinimapPing"] = true,
		["MiniMapPing"] = true,
	}

	-- Named side buttons
	local namedFrames = {
		"MiniMapTracking", "MiniMapTrackingButton", "MiniMapTrackingFrame",
		"MiniMapMailFrame", "MiniMapMailBorder",
		"MiniMapBattlefieldFrame", "MiniMapMeetingStoneFrame",
		"MiniMapWorldMapButton", "MinimapVoiceChatFrame", "MiniMapLFGFrame",
		"GameTimeFrame",
	}
	for _, n in ipairs(namedFrames) do
		local f = _G[n]
		if f then
			CEnableDragForButton(f)
			if SexyMap2DB.buttonPositions and SexyMap2DB.buttonPositions[n] then
				CRestoreButtonScreenPos(f)
			end
		end
	end

	-- Any addon buttons parented to Minimap
	local children = { Minimap:GetChildren() }
	for _, frame in ipairs(children) do
		local objType = frame:GetObjectType()
		if objType == "Button" or objType == "CheckButton" then
			local name = frame:GetName() or ""
			if name ~= "" and not excludeNames[name]
			   and not string.find(name, "POI")
			   and not string.find(name, "[Qq]uest")
			   and not string.find(name, "^MinimapPin")
			   and not string.find(name, "^MiniMapPOI")
			   and not string.find(name, "[Pp]in%d")
			then
				CEnableDragForButton(frame)
				if SexyMap2DB.buttonPositions and SexyMap2DB.buttonPositions[name] then
					CRestoreButtonScreenPos(frame)
				end
			end
		end
	end
end

function CUpdateMinimapButtonsVisibility()
	if SexyMap2DB.showMinimapButtons then
		-- Show only the buttons we previously hid (preserves original visibility)
		for _, btn in ipairs(hiddenMinimapButtons) do
			if btn then
				-- Restore original Show
				local orig = hiddenBtnOrigShows[btn]
				if orig then
					btn.Show = orig
					hiddenBtnOrigShows[btn] = nil
				end
				-- Restore saved anchor points (preserves button positions across hide/show)
				RestoreButtonPoints(btn)
				btn:Show()
			end
		end
		hiddenMinimapButtons = {}
	else
		-- Find and hide only VISIBLE minimap SIDE BUTTONS, hook their Show
		-- IMPORTANT: We only hide addon buttons and UI side-panel buttons.
		-- We do NOT hide quest/POI indicators so that map pins remain visible.
		hiddenMinimapButtons = {}

		-- Set of frame names to EXCLUDE from hiding (map content, not side buttons)
		local excludeNames = {
			-- WoW native controls (already hidden elsewhere)
			["MinimapZoomIn"] = true,
			["MinimapZoomOut"] = true,
			["MinimapToggleButton"] = true,
			["GameTimeFrame"] = true,
			["CMinimapBackdrop"] = true,
			-- Quest/POI indicators - map content, not side buttons
			["MinimapPing"] = true,
			["MiniMapPing"] = true,
		}

		local children = { Minimap:GetChildren() }
		for idx, frame in ipairs(children) do
			local objType = frame:GetObjectType()
			if objType == "Button" or objType == "CheckButton" then
				local name = frame:GetName() or ""
				-- Skip excluded frames
				if not excludeNames[name] then
					-- Skip frames that are map content indicators (quest/POI pins)
					-- These are typically unnamed or have "Pin", "POI", "Quest" in name
					if not string.find(name, "POI")
					   and not string.find(name, "[Qq]uest")
					   and not string.find(name, "^MinimapPin")
					   and not string.find(name, "^MiniMapPOI")
					   and not string.find(name, "[Pp]in%d")
					   then
						-- Only hide buttons that are currently visible
						-- (buttons already hidden by other addons should stay hidden)
						if frame:IsVisible() then
							-- Additional check: skip very small frames (likely icons not buttons)
							local width = frame:GetWidth()
							if width and width > 15 then
								-- Save anchor points before hiding so we can restore them later
								SaveButtonPoints(frame)
								-- Hook Show to prevent re-appearance
								if not hiddenBtnOrigShows[frame] then
									hiddenBtnOrigShows[frame] = frame.Show
									frame.Show = MinimapBtnHookedShow
								end
								frame:Hide()
								table.insert(hiddenMinimapButtons, frame)
							end
						end
					end
				end
			end
		end

		-- Hide known WoW minimap SIDE BUTTON frames by name (only if visible)
		-- These are UI chrome buttons around the minimap edge, NOT map content.
		local sideButtonFrames = {
			"MiniMapTracking",
			"MiniMapTrackingButton",
			"MiniMapTrackingFrame",
			"MiniMapMailFrame",
			"MiniMapMailBorder",
			"MiniMapBattlefieldFrame",
			"MiniMapMeetingStoneFrame",
			"MiniMapWorldMapButton",
			"MinimapVoiceChatFrame",
			"MiniMapLFGFrame",
		}
		for _, frameName in ipairs(sideButtonFrames) do
			local frame = _G[frameName]
			if frame and frame:IsVisible() then
				-- Save anchor points before hiding so we can restore them later
				SaveButtonPoints(frame)
				if not hiddenBtnOrigShows[frame] then
					hiddenBtnOrigShows[frame] = frame.Show
					frame.Show = MinimapBtnHookedShow
				end
				frame:Hide()
				table.insert(hiddenMinimapButtons, frame)
			end
		end
	end
end


function CApplyMapScale()
	local scale = SexyMap2DB.mapScale or 1.0
	if scale < 0.3 then scale = 0.3 end
	if scale > 1.0 then scale = 1.0 end
	SexyMap2DB.mapScale = scale

	-- Apply scale to the MinimapCluster which contains everything
	MinimapCluster:SetScale(scale)

	-- Re-anchor to TOPRIGHT - the anchor point is TOPRIGHT so when scaled down,
	-- the right side and top stay put, while the left and bottom move inward
	MinimapCluster:ClearAllPoints()
	MinimapCluster:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -14, 10)

	-- Update backdrop to match current minimap size
	CMinimapBackdrop:SetWidth(Minimap:GetWidth())
	CMinimapBackdrop:SetHeight(Minimap:GetHeight())

	-- Update border textures to match new minimap size
	CUpdateBackdrop()

	-- Re-place any user-positioned minimap buttons so they stay in the
	-- same on-screen spot regardless of the new scale.
	if CApplyButtonPositions then CApplyButtonPositions() end
end

function CUpdateZoneText()
	MinimapCluster:ClearAllPoints()
	-- Map position: always anchored TOPRIGHT so scale keeps right/top fixed
	MinimapCluster:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -14, 10)
	MinimapZoneText:ClearAllPoints()
	if SexyMap2DB.showZoneText then
		MinimapZoneText:Show()
		-- Zone name positioned below the minimap
		MinimapZoneText:SetPoint("TOP", Minimap, "BOTTOM", 0, -20)
	else
		-- Only hide the zone text; map and border do NOT move
		MinimapZoneText:Hide()
	end
end

-- ============================================
-- Set Defaults - resets all settings to factory
-- ============================================
function CSetDefaults()
	-- Reset all SavedVariables to defaults
	SexyMap2DB.borders = deepCopyHash(borderPresets["Diablo by Zork"].borders)
	SexyMap2DB.backdrop = deepCopyHash(borderPresets["Diablo by Zork"].backdrop)
	SexyMap2DB.shape = "Round"
	SexyMap2DB.userPresets = {}
	SexyMap2DB.showZoneText = true
	SexyMap2DB.showMinimapButtons = true
	SexyMap2DB.mapScale = 1.0
	SexyMap2DB.showMinimap = true
	SexyMap2DB.version = ADDON_VERSION

	-- Reapply everything
	CHideAnnoyingStuff()
	CUpdateZoneText()
	CUpdateMinimapButtonsVisibility()
	CUpdateMinimapVisibility()
	CApplyMapScale()
	CClearArtwork()
	CLoadArtwork()

	-- Refresh the GUI if it's open
	if CMinimapOptionFrame and CMinimapOptionFrame.menuState then
		CUpdatePresetList()
		CUpdateShapeList()
		CTexture_Update()
		CZoneTextToggle_Update()
		CMinimapButtonsToggle_Update()
		CMinimapToggle_Update()
		CMapScaleSlider_Update()
		CVariable_Update()
	end

	print("[SexyMap] All settings reset to defaults.")
end

function CClearArtwork()
	for k,v in pairs(CTextures) do
		_G[k]:SetTexCoord(0,1,0,1)
		_G[k]:Hide()
	end
	destroyTable(CTextures)
	CTextures = {}
	destroyTable(CRotateTextures)
	CRotateTextures = {}
end


function CLoadArtwork()
	if SexyMap2DB.shape then
		CApplyShape(SexyMap2DB.shape)
	end
	for k,v in ipairs(SexyMap2DB.borders) do
		CCreateBorder(v)
	end
	CUpdateBackdrop()
end


function CUpdateBackdrop()
	if not SexyMap2DB.backdrop or not SexyMap2DB.backdrop.show then
		CMinimapBackdrop:Hide()
	else
		local backdrop = CMinimapBackdrop
		backdrop:Show()
		backdrop:SetWidth(Minimap:GetWidth() * (SexyMap2DB.backdrop.scale or 1))
		backdrop:SetHeight(Minimap:GetHeight() * (SexyMap2DB.backdrop.scale or 1))

		-- Validate the backdrop settings before applying.
		-- If edgeFile or bgFile references are invalid, WoW 1.12 renders the frame
		-- as solid green (missing texture fallback). We check that the paths exist
		-- in the settings table before calling SetBackdrop.
		local settings = SexyMap2DB.backdrop.settings
		if settings then
			-- Ensure edgeFile doesn't have .blp extension (WoW 1.12 auto-appends it)
			if settings.edgeFile and string.find(settings.edgeFile, "%.blp$") then
				settings.edgeFile = string.gsub(settings.edgeFile, "%.blp$", "")
			end
			if settings.bgFile and string.find(settings.bgFile, "%.blp$") then
				settings.bgFile = string.gsub(settings.bgFile, "%.blp$", "")
			end
			backdrop:SetBackdrop(settings)
		end

		-- Set backdrop color with safe defaults for empty/missing color tables
		local c = SexyMap2DB.backdrop.textureColor
		if c and (c.r or c.g or c.b or c.a) then
			backdrop:SetBackdropColor(c.r or 0, c.g or 0, c.b or 0, c.a or 1)
		else
			-- Default: black background, full opacity
			backdrop:SetBackdropColor(0, 0, 0, 1)
		end

		-- Set border color with safe defaults for empty/missing color tables
		c = SexyMap2DB.backdrop.borderColor
		if c and (c.r or c.g or c.b or c.a) then
			backdrop:SetBackdropBorderColor(c.r or 1, c.g or 1, c.b or 1, c.a or 1)
		else
			-- Default: white border, full opacity
			backdrop:SetBackdropBorderColor(1, 1, 1, 1)
		end
	end
end
