-- Module: sort.lua
-- Purpose: show/hide and position debuff icons in configured order/grid.
-- Exports: aDF:Sort().
-- Depends on: GetDB(), aDFOrder, aDFDebuffs, aDF_frames.
-- Used by: events, options UI and slash workflows.

-- ==== SORT & POSITIONING ==== 
-- This block positions the icons. Sort function to show/hide frames and position them correctly
local floor = math.floor
local ceil = math.ceil
local min = math.min
local mod = math.mod

function aDF:Sort()
	local db = GetDB()  -- Get current configuration

	-- First, build ordered list according to aDFOrder

    local ordered = {}
    for _, debuffName in ipairs(aDFOrder) do
		-- Only include if present in aDFDebuffs and enabled in db.enabledDebuffs
        if aDFDebuffs[debuffName] and db.enabledDebuffs[debuffName] then
            table.insert(ordered, debuffName)
        end
    end
    
	-- Hide all first

    for name, _ in pairs(aDFDebuffs) do
        if aDF_frames[name] then
            aDF_frames[name]:Hide()
        end
    end
    
	-- Show and position only active ones

	local size = math.floor(ICON_BASE * db.display.scale + 0.5)
    local maxColumns = db.debuffSettings.maxColumns
    
	-- Count elements in ordered
	-- needed for frame size adjustment, and need math module in this file

    local orderedCount = 0
    for _ in ipairs(ordered) do
        orderedCount = orderedCount + 1
    end
    
    for index, debuffName in ipairs(ordered) do
        local frame = aDF_frames[debuffName]
        if frame then
            frame:Show()
            frame:ClearAllPoints()

            local currentColumn = mod((index - 1), maxColumns)
            local currentRow = floor((index - 1) / maxColumns)
            
            frame:SetPoint("TOPLEFT", aDF_DebuffFrame, "TOPLEFT", 
                          size * currentColumn, 
                          -size * currentRow)
        end
    end
    
	-- Adjust debuff frame size as needed

    local totalRows = 0
    if orderedCount > 0 then
        totalRows = ceil(orderedCount / maxColumns)
    else
        totalRows = 1
    end
    
    if aDF_DebuffFrame then
        local widthColumns = min(maxColumns, orderedCount)
        aDF_DebuffFrame:SetWidth(size * widthColumns)
        aDF_DebuffFrame:SetHeight(size * totalRows)
    end

end
