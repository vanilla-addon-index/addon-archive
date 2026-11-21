---
--- Minimap.lua - [Atlas-CFM split] always-loaded minimap button and World Map
--- cursor coordinates.
---
--- The two `do ... end` blocks below are moved verbatim from CFMAtlas\AtlasUI.lua.
--- The minimap button logic functions are copied from CFMAtlas\AtlasUILogic.lua
--- (which still redefines them identically once Atlas-CFM_Core is loaded); the
--- only change is that AtlasCFM.OptionsInit() is called only when it exists.
--- Button clicks call AtlasCFM.ToggleAtlas / AtlasCFM.OptionsOnClick, which the
--- stub Loader.lua turns into "load Atlas-CFM_Core, then forward".
---
--- @compatible World of Warcraft 1.12
---

local _G = getfenv()
local AtlasCFM = _G.AtlasCFM

local L = AtlasCFM.Localization.UI

local function OptionsInitIfLoaded()
	if AtlasCFM.OptionsInit then AtlasCFM.OptionsInit() end
end

local function AtlasCFMButtonSetPosition(v)
	if v < 0 then
		v = v + 360
	end
	AtlasCFMOptions.AtlasButtonPosition = v
	AtlasCFM.MinimapButtonUpdatePosition()
end

function AtlasCFM.MinimapButtonInit()
	if AtlasCFMOptions.AtlasButtonShown then
		AtlasCFMButtonFrame:Show()
	else
		AtlasCFMButtonFrame:Hide()
	end
	AtlasCFM.MinimapButtonUpdatePosition()
end

function AtlasCFM.MinimapButtonUpdatePosition()
	local radius = AtlasCFMOptions.AtlasButtonRadius
	local position = AtlasCFMOptions.AtlasButtonPosition
	AtlasCFMButtonFrame:SetPoint(
		"TOPLEFT",
		"Minimap",
		"TOPLEFT",
		54 - (radius * cos(position)),
		(radius * sin(position)) - 55
	)
	OptionsInitIfLoaded()
end

function AtlasCFM.MinimapButtonBeingDragged()
	local xpos, ypos = GetCursorPosition()
	local xmin, ymin = Minimap:GetLeft(), Minimap:GetBottom()
	local scale = UIParent:GetScale()
	xpos = xmin - xpos / scale + 70
	ypos = ypos / scale - ymin - 70
	AtlasCFMButtonSetPosition(math.deg(math.atan2(ypos, xpos)))
end

function AtlasCFM.MinimapButtonOnEnter()
	GameTooltip:SetOwner(this, "ANCHOR_LEFT")
	GameTooltip:SetText(AtlasCFM.Name)
	GameTooltip:AddLine(
		L["Left-click to open Atlas-CFM.\nMiddle-click for Atlas-CFM options.\nRight-click and drag to move this button."],
		1,
		1, 1, true)
	GameTooltip:Show()
end

do
    -- Create the minimap button frame
    local buttonFrame = CreateFrame("Frame", "AtlasCFMButtonFrame", Minimap)
    buttonFrame:SetFrameStrata("MEDIUM")
    buttonFrame:SetWidth(32)
    buttonFrame:SetHeight(32)
    buttonFrame:SetPoint("TOPLEFT", 2, 0)
    buttonFrame:EnableMouse(true)
    buttonFrame:RegisterEvent("VARIABLES_LOADED")
    buttonFrame:Show()

    -- Frame scripts
    buttonFrame:SetScript("OnEvent", function()
        AtlasCFM.MinimapButtonInit()
    end)

    -- Create the button
    local button = CreateFrame("Button", "AtlasCFMMinimapButton", buttonFrame)
    button:SetWidth(33)
    button:SetHeight(33)
    button:SetPoint("TOPLEFT", 0, 0)
    button:RegisterForDrag("RightButton")

    -- Button scripts
    button:SetScript("OnHide", function()
        button:StopMovingOrSizing()
        button.isMoving = false
    end)
    button:SetScript("OnDragStart", function()
        button.isMoving = true
        AtlasCFM.MinimapButtonBeingDragged()
    end)
    button:SetScript("OnDragStop", function()
        button:StopMovingOrSizing()
        button.isMoving = false
    end)

    button:SetScript("OnClick", function() AtlasCFM.ToggleAtlas() end)
    button:SetScript("OnMouseUp", function()
        button:StopMovingOrSizing()
        button.isMoving = false
        if (arg1 == "MiddleButton") then
            AtlasCFM.OptionsOnClick()
        end
    end)
    button:SetScript("OnEnter", function() AtlasCFM.MinimapButtonOnEnter() end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Button textures
    local icon = button:CreateTexture("AtlasCFMButtonIcon", "BORDER")
    icon:SetTexture("Interface\\WorldMap\\WorldMap-Icon")
    icon:SetWidth(20)
    icon:SetHeight(20)
    icon:SetPoint("CENTER", -2, 1)
    icon:SetVertexColor(1, 1, 0)

    local border = button:CreateTexture("AtlasCFMButtonBorder", "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetWidth(52)
    border:SetHeight(52)
    border:SetPoint("TOPLEFT", 0, 0)

    local highlight = button:CreateTexture()
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")
    button:SetHighlightTexture(highlight)
end

-- World Map cursor coordinates (shows cursor coords on default World Map)
-- Respects AtlasCFMOptions.AtlasCursorCoords setting
do
    -- Create the coordinates if Blizzard world map frames are available
    local function CreateAtlasWorldMapCoords()
        if AtlasCFMWorldMapCursorText then return true end
        if not WorldMapFrame or not WorldMapDetailFrame then return false end

        local wmCoordText = WorldMapDetailFrame:CreateFontString("AtlasCFMWorldMapCursorText", "OVERLAY",
            "GameFontNormal")
        wmCoordText:SetTextColor(1, 1, 1)
        wmCoordText:Hide()
        -- Anchor text at the bottom-left of the World Map (fixed position)
        wmCoordText:SetPoint("BOTTOMLEFT", WorldMapDetailFrame, 10, 8)

        local function wm_round1(x)
            return math.floor(x * 10 + .5) / 10
        end

        -- Helper: approximate effective scale for frames in WoW 1.12 (multiply parent scales)
        local function wm_getEffectiveScale(f)
            local s = 1
            while f do
                local fs = f:GetScale()
                if fs then s = s * fs end
                f = f:GetParent()
            end
            return s
        end

        WorldMapDetailFrame:SetScript("OnUpdate", function()
            -- Respect option and visibility
            if not AtlasCFMOptions or not AtlasCFMOptions.AtlasCursorCoords or not WorldMapFrame:IsShown() then
                wmCoordText:Hide()
                return
            end
            local cursorX, cursorY = GetCursorPosition()
            -- Use effective scale of the detail frame to be correct when the map is reduced
            local wmScale = wm_getEffectiveScale(WorldMapDetailFrame) or 1
            cursorX = cursorX / wmScale
            cursorY = cursorY / wmScale
            local mapLeft, mapBottom = WorldMapDetailFrame:GetLeft(), WorldMapDetailFrame:GetBottom()
            local mapWidth, mapHeight = WorldMapDetailFrame:GetWidth(), WorldMapDetailFrame:GetHeight()
            if not mapLeft or not mapBottom or not mapWidth or not mapHeight then
                wmCoordText:Hide()
                return
            end
            local relX = cursorX - mapLeft
            local relY = cursorY - mapBottom
            if relX < 0 or relY < 0 or relX > mapWidth or relY > mapHeight then
                wmCoordText:Hide()
                return
            end
            if not wmCoordText:IsShown() then wmCoordText:Show() end
            local fracX = relX / mapWidth
            local fracY = 1 - (relY / mapHeight)
            local xPercent = wm_round1(fracX * 100)
            local yPercent = wm_round1(fracY * 100)
            wmCoordText:SetText(xPercent .. ", " .. yPercent)
        end)
        return true
    end

    -- Try to create immediately
    CreateAtlasWorldMapCoords()
end
