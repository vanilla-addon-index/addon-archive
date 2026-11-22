module 'aux.util.purchase_summary'

local T = require 'T'
local aux = require 'aux'
local gui = require 'aux.gui'
local money = require 'aux.util.money'

-- Purchase summary data storage
local purchase_summaries = {}

-- Purchase summary display frame
local purchase_summary_frame

function M.get_summaries()
	return purchase_summaries
end

function M.clear_summaries()
	T.wipe(purchase_summaries)
end

function M.add_purchase(name, texture, quantity, cost)
	if not name then return end

	if not purchase_summaries[name] then
		purchase_summaries[name] = {
			item_name = name,
			texture = texture or '',
			total_quantity = 0,
			total_cost = 0,
			purchase_count = 0
		}
	end

	purchase_summaries[name].total_quantity = purchase_summaries[name].total_quantity + (quantity or 0)
	purchase_summaries[name].total_cost = purchase_summaries[name].total_cost + (cost or 0)
	purchase_summaries[name].purchase_count = purchase_summaries[name].purchase_count + 1
end

function create_purchase_summary_frame()
	if purchase_summary_frame then return purchase_summary_frame end

	purchase_summary_frame = CreateFrame('Frame', 'AuxPurchaseSummary', UIParent)
	purchase_summary_frame:SetWidth(300)
	purchase_summary_frame:SetHeight(100)
	purchase_summary_frame:SetClampedToScreen(true)
	purchase_summary_frame:SetFrameLevel(aux.frame:GetFrameLevel())

	-- Use aux's standard panel styling
	gui.set_panel_style(purchase_summary_frame, 2, 2, 2, 2)
	purchase_summary_frame:Hide()

	-- Title text using aux color scheme
	local title = purchase_summary_frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	title:SetPoint('TOPLEFT', 8, -8)
	title:SetText('Purchase Summary')
	title:SetTextColor(aux.color.label.enabled())
	purchase_summary_frame.title = title

	-- Total spent amount aligned with cost column
	local total_spent_text = purchase_summary_frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	total_spent_text:SetPoint('TOPLEFT', 208, -8)  -- Same x as cost column (200 + 8 offset)
	total_spent_text:SetWidth(80)
	total_spent_text:SetJustifyH('RIGHT')
	total_spent_text:SetTextColor(aux.color.label.enabled())
	purchase_summary_frame.total_spent_text = total_spent_text

	-- Column headers
	local header_item = purchase_summary_frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	header_item:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -4)
	header_item:SetWidth(150)
	header_item:SetJustifyH('LEFT')
	header_item:SetText('Item')
	header_item:SetTextColor(aux.color.label.enabled())
	purchase_summary_frame.header_item = header_item

	local header_count = purchase_summary_frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	header_count:SetPoint('LEFT', header_item, 'RIGHT', 5, 0)
	header_count:SetWidth(40)
	header_count:SetJustifyH('RIGHT')
	header_count:SetText('Count')
	header_count:SetTextColor(aux.color.label.enabled())
	purchase_summary_frame.header_count = header_count

	local header_cost = purchase_summary_frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	header_cost:SetPoint('LEFT', header_count, 'RIGHT', 5, 0)
	header_cost:SetWidth(80)
	header_cost:SetJustifyH('RIGHT')
	header_cost:SetText('Gold Spent')
	header_cost:SetTextColor(aux.color.label.enabled())
	purchase_summary_frame.header_cost = header_cost

    local frame = purchase_summary_frame
    local viewport = CreateFrame('ScrollFrame', nil, frame)
    viewport:SetPoint('TOPLEFT', 8, -38)
    viewport:SetPoint('BOTTOMRIGHT', -8, 12)
    local body = CreateFrame('Frame', nil, viewport)
    body:SetWidth(280)
    body:SetHeight(1)
    viewport:SetScrollChild(body)
    viewport:EnableMouseWheel(true)
    viewport:SetScript('OnMouseWheel', function()
        this:SetVerticalScroll(math.max(0, math.min(frame.scroll_limit, this:GetVerticalScroll() - arg1 * 32)))
    end)
    frame.viewport, frame.body = viewport, body
    local hint = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
    hint:SetPoint('BOTTOM', 0, 2)
    hint:SetText('Scroll for more')
    frame.scroll_hint = hint

	-- Storage for row frames
	purchase_summary_frame.rows = {}
    purchase_summary_frame.names = {}
	return purchase_summary_frame
end

function M.update_display()
	local frame = create_purchase_summary_frame()

	-- Check if purchase summary is disabled
	if not aux.account_data.purchase_summary then
		frame:Hide()
		return
	end

	if not purchase_summaries or aux.size(purchase_summaries) == 0 then
		frame:Hide()
		return
	end

	-- Calculate total spent across all purchases
	local total_spent = 0
    local names = frame.names
    T.wipe(names)
	for item_name, summary in purchase_summaries do
        tinsert(names, item_name)
		total_spent = total_spent + (summary.total_cost or 0)
	end

	-- Update total spent display aligned with cost column
	if total_spent > 0 then
		-- Drop copper when displaying gold amounts (same logic as cost column)
		local total_string
		if total_spent >= 10000 then  -- 1 gold = 10000 copper
			-- For gold amounts, round to silver and hide copper
			local rounded_total = aux.round(total_spent / 100) * 100  -- Round to nearest silver
			total_string = money.to_string(rounded_total, nil, true)
		else
			total_string = money.to_string(total_spent, nil, true)  -- Show full amount for smaller values
		end
		frame.total_spent_text:SetText(total_string)
		frame.total_spent_text:Show()
	else
		frame.total_spent_text:Hide()
	end

	-- Clear existing row frames
	for _, row in frame.rows do
		row:Hide()
	end

    sort(names)
	-- Create rows for each item
	local row_count = 0
	local content_height = 0
	for _, item_name in ipairs(names) do
        local summary = purchase_summaries[item_name]
		row_count = row_count + 1

		-- Create new row frame if needed
		if not frame.rows[row_count] then
			local row = CreateFrame('Frame', nil, frame.body)
			row:SetHeight(14)
			row:SetWidth(280)  -- Reduced width

			-- Item name column
			local item_text = row:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
			item_text:SetPoint('TOPLEFT', row, 'TOPLEFT', 0, 0)
			item_text:SetWidth(150)
			item_text:SetJustifyH('LEFT')
			item_text:SetTextColor(aux.color.text.enabled())
			row.item_text = item_text

			-- Count column
			local count_text = row:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
			count_text:SetPoint('TOPLEFT', row, 'TOPLEFT', 155, 0)  -- 150 + 5 spacing
			count_text:SetWidth(40)
			count_text:SetJustifyH('RIGHT')
			count_text:SetTextColor(aux.color.text.enabled())
			row.count_text = count_text

			-- Cost column
			local cost_text = row:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
			cost_text:SetPoint('TOPLEFT', row, 'TOPLEFT', 200, 0)  -- 155 + 40 + 5 spacing
			cost_text:SetWidth(80)
			cost_text:SetJustifyH('RIGHT')
			cost_text:SetTextColor(aux.color.text.enabled())
			row.cost_text = cost_text

			frame.rows[row_count] = row
		end

		local row = frame.rows[row_count]

		row:ClearAllPoints()
		-- Position each row inside the scroll child.
		if row_count == 1 then
			row:SetPoint('TOPLEFT', frame.body, 'TOPLEFT', 0, 0)
		else
			row:SetPoint('TOPLEFT', frame.rows[row_count - 1], 'BOTTOMLEFT', 0, 0)
		end

		-- Set the text content
		row.item_text:SetText(item_name)
		row.count_text:SetText(summary.total_quantity .. 'x')

		-- Drop copper when displaying gold amounts
		local cost = summary.total_cost or 0
		local cost_string
		if cost >= 10000 then  -- 1 gold = 10000 copper
			-- For gold amounts, round to silver and hide copper
			local rounded_cost = aux.round(cost / 100) * 100  -- Round to nearest silver
			cost_string = money.to_string(rounded_cost, nil, true)
		else
			cost_string = money.to_string(cost, nil, true)  -- Show full amount for smaller values
		end
		row.cost_text:SetText(cost_string)

		-- Wrapped names need their full height before the next row is anchored.
		local row_height = math.max(14, row.item_text:GetHeight(), row.count_text:GetHeight(), row.cost_text:GetHeight()) + 2
		row:SetHeight(row_height)
		content_height = content_height + row_height

		row:Show()
	end

    local anchor = aux.frame
    local root_scale = UIParent:GetEffectiveScale()
    local scale = anchor:GetEffectiveScale() / root_scale
    local left = (anchor:GetLeft() or 0) * scale
    local right = (anchor:GetRight() or 0) * scale
    local top = (anchor:GetTop() or 0) * scale
    local screen_width, screen_height = UIParent:GetWidth(), UIParent:GetHeight()
    local max_height = math.max(84, math.min(240, screen_height - top - 12))
    frame:ClearAllPoints()
    if aux.account_data.purchase_sidebar and right + 316 <= screen_width then
        frame:SetPoint('TOPLEFT', anchor, 'TOPRIGHT', 16, 0)
        max_height = math.min(420, screen_height - 24)
    elseif aux.account_data.purchase_sidebar and left >= 316 then
        frame:SetPoint('TOPRIGHT', anchor, 'TOPLEFT', -16, 0)
        max_height = math.min(420, screen_height - 24)
    else
        frame:SetPoint('BOTTOM', anchor, 'TOP', 0, gui.is_blizzard() and 9 or 2)
    end
    local height = math.max(60, math.min(max_height, 50 + content_height))
    frame:SetHeight(height)
    frame.body:SetHeight(math.max(1, content_height))
    frame.scroll_limit = math.max(0, 50 + content_height - height)
    frame.viewport:SetVerticalScroll(math.min(frame.viewport:GetVerticalScroll(), frame.scroll_limit))
    if frame.scroll_limit > 0 then frame.scroll_hint:Show() else frame.scroll_hint:Hide() end

	frame:Show()
end

function M.refresh_sidebar()
    if aux.frame and aux.frame:IsVisible() then
        update_display()
    end
end

function M.hide()
	if purchase_summary_frame then
		purchase_summary_frame:Hide()
	end
end

-- Set up handlers - use direct function references instead of M.
function aux.handle.CLOSE()
	if purchase_summary_frame then
		purchase_summary_frame:Hide()
        purchase_summary_frame.viewport:SetVerticalScroll(0)
	end
	T.wipe(purchase_summaries)
end
