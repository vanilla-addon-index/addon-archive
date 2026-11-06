-- Module: frames.lua
-- Purpose: create and configure main HUD frames (armor/res/debuff).
-- Exports: aDF:Init().
-- Depends on: GetDB(), aDF_frames, constants, aDF.Create_frame().
-- Used by: core/events.lua at ADDON_LOADED.

-- ==== MAIN ARMOR/RESISTANCE FRAME ====
local floor = math.floor

function aDF:Init()
	local db = GetDB()  -- Get current configuration
    
    -- ==== ARMOR FRAME ==== subsection

    aDF_ArmorFrame = CreateFrame('Button', "aDF_ArmorFrame", UIParent)
    aDF_ArmorFrame:SetFrameStrata("BACKGROUND")
	aDF_ArmorFrame:SetWidth(100)
	aDF_ArmorFrame:SetHeight(30)
    aDF_ArmorFrame:SetPoint("CENTER", db.positions.armor.x, db.positions.armor.y)
    aDF_ArmorFrame:SetMovable(1)
    aDF_ArmorFrame:EnableMouse(1)
    aDF_ArmorFrame:RegisterForDrag("LeftButton")
    
	-- Backdrop for armor

    local armorBackdrop = {
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        tile = false, tileSize = 8, edgeSize = 8,
        insets = {left = 2, right = 2, top = 2, bottom = 2}
    }
    
    if db.display.showArmorBackground then
        aDF_ArmorFrame:SetBackdrop(armorBackdrop)
        aDF_ArmorFrame:SetBackdropColor(0,0,0,1)
    end
    
	-- Armor text

    aDF_ArmorFrame.armor = aDF_ArmorFrame:CreateFontString(nil, "OVERLAY")
    aDF_ArmorFrame.armor:SetPoint("CENTER", aDF_ArmorFrame, "CENTER", 0, 0)
	aDF_ArmorFrame.armor:SetFont("Fonts\\FRIZQT__.TTF", FONT_BASE_ARMOR)
    aDF_ArmorFrame.armor:SetText("Armor")
    
	-- Drag & Drop for armor

    aDF_ArmorFrame:SetScript("OnDragStart", function()
        if not db.locks.armor and IsShiftKeyDown() then
            this:StartMoving()
        end
    end)
    
    aDF_ArmorFrame:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        local x, y = this:GetCenter()
        local ux, uy = UIParent:GetCenter()
        db.positions.armor.x, db.positions.armor.y = floor(x - ux + 0.5), floor(y - uy + 0.5)
    end)
    
    -- ==== RESISTANCE FRAME ==== subsection

    aDF_ResFrame = CreateFrame('Button', "aDF_ResFrame", UIParent)
    aDF_ResFrame:SetFrameStrata("BACKGROUND")
	aDF_ResFrame:SetWidth(100)
	aDF_ResFrame:SetHeight(20)
    aDF_ResFrame:SetPoint("CENTER", db.positions.resistance.x, db.positions.resistance.y)
    aDF_ResFrame:SetMovable(1)
    aDF_ResFrame:EnableMouse(1)
    aDF_ResFrame:RegisterForDrag("LeftButton")
    
	-- Resistance text

    aDF_ResFrame.res = aDF_ResFrame:CreateFontString(nil, "OVERLAY")
    aDF_ResFrame.res:SetPoint("CENTER", aDF_ResFrame, "CENTER", 0, 0)
	if aDF_ResFrame then
		aDF_ResFrame.res:SetFont("Fonts\\FRIZQT__.TTF", FONT_BASE_RES)
	end
    aDF_ResFrame.res:SetText("Resistance")
    
	-- Drag & Drop for resistances

    aDF_ResFrame:SetScript("OnDragStart", function()
        if not db.locks.resistance and IsShiftKeyDown() then
            this:StartMoving()
        end
    end)
    
    aDF_ResFrame:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        local x, y = this:GetCenter()
        local ux, uy = UIParent:GetCenter()
        db.positions.resistance.x, db.positions.resistance.y = floor(x - ux + 0.5), floor(y - uy + 0.5)
    end)
    
    -- ==== DEBUFF FRAME ==== subsection

    aDF_DebuffFrame = CreateFrame('Button', "aDF_DebuffFrame", UIParent)
    aDF_DebuffFrame:SetFrameStrata("BACKGROUND")
	local initSize = math.floor(ICON_BASE * db.display.scale + 0.5)
	aDF_DebuffFrame:SetWidth(initSize * 7)
	aDF_DebuffFrame:SetHeight(initSize * 3)
    aDF_DebuffFrame:SetPoint("CENTER", db.positions.debuffs.x, db.positions.debuffs.y)
    aDF_DebuffFrame:SetMovable(1)
    aDF_DebuffFrame:EnableMouse(1)
    aDF_DebuffFrame:RegisterForDrag("LeftButton")
    
	-- Drag & Drop for debuffs

    aDF_DebuffFrame:SetScript("OnDragStart", function()
        if not db.locks.debuffs and IsShiftKeyDown() then
            this:StartMoving()
        end
    end)
    
    aDF_DebuffFrame:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        local x, y = this:GetCenter()
        local ux, uy = UIParent:GetCenter()
        db.positions.debuffs.x, db.positions.debuffs.y = floor(x - ux + 0.5), floor(y - uy + 0.5)
    end)
    
	-- Create tooltip for debuff detection

	aDF_tooltip = CreateFrame("GAMETOOLTIP", "buffScan")
    aDF_tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    aDF_tooltipTextL = aDF_tooltip:CreateFontString()
    aDF_tooltipTextR = aDF_tooltip:CreateFontString()
    aDF_tooltip:AddFontStrings(aDF_tooltipTextL,aDF_tooltipTextR)
    
	-- Create debuff frames as children of the debuff frame

    for name, texture in pairs(aDFDebuffs) do
		local aDFsize = math.floor(ICON_BASE * db.display.scale + 0.5)
        aDF_frames[name] = aDF_frames[name] or aDF.Create_frame(name)
        local frame = aDF_frames[name]
        frame:SetParent(aDF_DebuffFrame)
        frame:SetWidth(aDFsize)
        frame:SetHeight(aDFsize)
        frame.icon:SetTexture(texture)
        frame:SetFrameLevel(2)
		frame:Hide()  -- Hide initially; aDF:Sort() will show them. this have fail when new adf.lua saved variables?? need checking but have dream

		-- Keep OnEnter/OnLeave scripts

        frame:SetScript("OnEnter", function() 
            GameTooltip:SetOwner(frame, "ANCHOR_TOPRIGHT")
            GameTooltip:SetText(this:GetName(), 255, 255, 0, 1, 1)
            GameTooltip:Show()
        end)
        frame:SetScript("OnLeave", function() GameTooltip:Hide() end)

		-- Allow dragging the debuff container by clicking any icon.

		frame:RegisterForDrag("LeftButton")
		frame:SetScript("OnDragStart", function()
			if not db.locks.debuffs and IsShiftKeyDown() and aDF_DebuffFrame then
				aDF_DebuffFrame:StartMoving()
			end
		end)
		frame:SetScript("OnDragStop", function()
			if not aDF_DebuffFrame then return end
			aDF_DebuffFrame:StopMovingOrSizing()
			local x, y = aDF_DebuffFrame:GetCenter()
			local ux, uy = UIParent:GetCenter()
			db.positions.debuffs.x, db.positions.debuffs.y = floor(x - ux + 0.5), floor(y - uy + 0.5)
		end)
    end
    
	-- Initialize visibility according to options
	-- visuals match the SavedVariables state on startup.

	if aDF_ArmorFrame then
		if db.display.showArmorBackground then
			local backdrop = {
				edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
				bgFile = "Interface/Tooltips/UI-Tooltip-Background",
				tile="false",
				tileSize="8",
				edgeSize="8",
				insets={left="2",right="2",top="2",bottom="2"}
			}
			aDF_ArmorFrame:SetBackdrop(backdrop)
			aDF_ArmorFrame:SetBackdropColor(0,0,0,1)
		else
			aDF_ArmorFrame:SetBackdrop(nil)
		end
	end

	if aDF_ResFrame then
		if db.display.showResistanceBackground then
			local backdrop = {
				edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
				bgFile = "Interface/Tooltips/UI-Tooltip-Background",
				tile=false, tileSize=8, edgeSize=8,
				insets={left=2, right=2, top=2, bottom=2}
			}
			aDF_ResFrame:SetBackdrop(backdrop)
			aDF_ResFrame:SetBackdropColor(0,0,0,1)
		else
			aDF_ResFrame:SetBackdrop(nil)
		end
	end

	if aDF_DebuffFrame then
		if db.display.showDebuffBackground then
			local backdrop = {
				edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
				bgFile = "Interface/Tooltips/UI-Tooltip-Background",
				tile=false, tileSize=8, edgeSize=8,
				insets={left=2, right=2, top=2, bottom=2}
			}
			aDF_DebuffFrame:SetBackdrop(backdrop)
			aDF_DebuffFrame:SetBackdropColor(0,0,0,0.8)
			aDF_DebuffFrame:SetBackdropBorderColor(0.5,0.5,0.5,0.8)
		else
			aDF_DebuffFrame:SetBackdrop(nil)
		end
	end


	-- Text visibility

	if not db.display.showArmorText then aDF_ArmorFrame.armor:Hide() end
	if not db.display.showResistanceText then aDF_ResFrame.res:Hide() end

	-- Persistent visibility for main frames
	if db.display.framesVisible == false then
		if aDF_ArmorFrame then aDF_ArmorFrame:Hide() end
		if aDF_ResFrame then aDF_ResFrame:Hide() end
		if aDF_DebuffFrame then aDF_DebuffFrame:Hide() end
	end
end
