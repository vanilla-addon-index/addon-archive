module 'aux.core.tooltip'

local T = require 'T'
local aux = require 'aux'
local info = require 'aux.util.info'
local disenchant = require 'aux.core.disenchant'
local history = require 'aux.core.history'
local gui = require 'aux.gui'

local UNKNOWN = GRAY_FONT_COLOR_CODE .. '?' .. FONT_COLOR_CODE_CLOSE

local MONEY_TEXTURE = 'Interface\\MoneyFrame\\UI-MoneyIcons'
local MONEY_ICON_SIZE = 11
local MONEY_ICON_GAP = 1
local MONEY_PART_GAP = 4
local MONEY_SUFFIX_GAP = 6

local tooltip_money_states = {}

local function hide_money_rows(tooltip, reset_width)
    local state = tooltip_money_states[tooltip]
    if not state then return end
    for _, row in state.rows do
        row:Hide()
    end
    state.used = 0
    if reset_width and state.min_width > 0 then
        tooltip:SetMinimumWidth(0)
    end
    state.min_width = 0
end

local function money_state(tooltip)
    local state = tooltip_money_states[tooltip]
    if state then return state end

    state = {rows = {}, used = 0, min_width = 0}
    tooltip_money_states[tooltip] = state

    local on_hide = tooltip:GetScript('OnHide')
    tooltip:SetScript('OnHide', function()
        hide_money_rows(tooltip, true)
        if on_hide then on_hide() end
    end)

    return state
end

local function create_money_row(tooltip, index)
    local name = tooltip:GetName() .. 'AuxMoneyRow' .. index
    local row = CreateFrame('Frame', name, tooltip)
    row:SetHeight(MONEY_ICON_SIZE)
    row:Hide()
    row.texts, row.icons = {}, {}

    for i = 1, 3 do
        local text = row:CreateFontString(name .. 'Text' .. i, 'OVERLAY', 'GameTooltipText')
        text:SetTextColor(1, 1, 1)
        row.texts[i] = text

        local icon = row:CreateTexture(name .. 'Icon' .. i, 'ARTWORK')
        icon:SetTexture(MONEY_TEXTURE)
        icon:SetWidth(MONEY_ICON_SIZE)
        icon:SetHeight(MONEY_ICON_SIZE)
        row.icons[i] = icon
    end

    row.suffix = row:CreateFontString(name .. 'Suffix', 'OVERLAY', 'GameTooltipText')
    row.suffix:SetTextColor(1, 1, 1)

    return row
end

local function acquire_money_row(tooltip)
    local state = money_state(tooltip)
    state.used = state.used + 1

    local row = state.rows[state.used]
    if not row then
        row = create_money_row(tooltip, state.used)
        state.rows[state.used] = row
    end

    return row
end

local function set_coin_icon(icon, coin)
    if coin == 'gold' then
        icon:SetTexCoord(0, .25, 0, 1)
    elseif coin == 'silver' then
        icon:SetTexCoord(.25, .5, 0, 1)
    else
        icon:SetTexCoord(.5, .75, 0, 1)
    end
end

local function set_money_part(row, index, coin, value, x)
    local text, icon = row.texts[index], row.icons[index]
    text:SetText(value)
    text:ClearAllPoints()
    text:SetPoint('LEFT', row, 'LEFT', x, 0)
    text:Show()

    set_coin_icon(icon, coin)
    icon:ClearAllPoints()
    icon:SetPoint('LEFT', text, 'RIGHT', MONEY_ICON_GAP, 0)
    icon:Show()

    return x + text:GetStringWidth() + MONEY_ICON_GAP + MONEY_ICON_SIZE + MONEY_PART_GAP
end

local function layout_money_row(row, value, suffix)
    local gold = floor(value / 10000)
    local silver = floor(mod(value, 10000) / 100)
    local copper = mod(value, 100)

    for i = 1, 3 do
        row.texts[i]:Hide()
        row.icons[i]:Hide()
    end
    row.suffix:Hide()

    local x, index = 0, 0
    if gold > 0 then
        index = index + 1
        x = set_money_part(row, index, 'gold', tostring(gold), x)
        index = index + 1
        x = set_money_part(row, index, 'silver', format('%02d', silver), x)
        index = index + 1
        x = set_money_part(row, index, 'copper', format('%02d', copper), x)
    elseif silver > 0 then
        index = index + 1
        x = set_money_part(row, index, 'silver', tostring(silver), x)
        index = index + 1
        x = set_money_part(row, index, 'copper', format('%02d', copper), x)
    else
        index = index + 1
        x = set_money_part(row, index, 'copper', format('%d', copper), x)
    end

    x = x - MONEY_PART_GAP

    if suffix then
        row.suffix:SetText(suffix)
        row.suffix:ClearAllPoints()
        row.suffix:SetPoint('LEFT', row, 'LEFT', x + MONEY_SUFFIX_GAP, 0)
        row.suffix:Show()
        x = x + MONEY_SUFFIX_GAP + row.suffix:GetStringWidth()
    end

    row:SetWidth(x)
    return x
end

local function add_money_line(tooltip, label, value, color, suffix)
    if value >= 10000 then
        value = aux.round(value / 100) * 100
    end

    local r, g, b = color()
    tooltip:AddDoubleLine(label, ' ', r, g, b, 1, 1, 1)

    local line_number = tooltip:NumLines()
    local left = getglobal(tooltip:GetName() .. 'TextLeft' .. line_number)
    local right = getglobal(tooltip:GetName() .. 'TextRight' .. line_number)
    local row = acquire_money_row(tooltip)
    local width = layout_money_row(row, value, suffix)

    row:ClearAllPoints()
    row:SetPoint('RIGHT', right, 'RIGHT', 0, 0)
    row:Show()

    local state = money_state(tooltip)
    local min_width = left:GetStringWidth() + width + 32
    if min_width > state.min_width then
        state.min_width = min_width
        tooltip:SetMinimumWidth(min_width)
    end
end

local game_tooltip_hooks, game_tooltip_money = {}, 0

function aux.handle.LOAD()
	settings = aux.character_data.tooltip
	do
		local inside_hook = false
	    for name, f in game_tooltip_hooks do
	        local name, f = name, f
	        aux.hook(name, GameTooltip, T.vararg-function(arg)
                game_tooltip_money = 0
                inside_hook = true
	            local tmp = T.list(aux.orig[GameTooltip][name](unpack(arg)))
	            inside_hook = false
	            f(unpack(arg))
	            return T.unpack(tmp)
	        end)
	    end
        SetTooltipMoney = SetTooltipMoney
        _G.SetTooltipMoney = T.vararg-function(arg)
            if inside_hook then
                game_tooltip_money = arg[2]
            else
                return SetTooltipMoney(unpack(arg))
            end
        end
    end
    local orig = SetItemRef
    setglobal('SetItemRef', T.vararg-function(arg)
        local name, _, quality = GetItemInfo(arg[1])
        local tmp = T.list(orig(unpack(arg)))
        if not IsShiftKeyDown() and not IsControlKeyDown() and name then
            local color_code = aux.select(4, GetItemQualityColor(quality))
            local link = color_code ..  '|H' .. arg[1] .. '|h[' .. name .. ']|h' .. FONT_COLOR_CODE_CLOSE
            extend_tooltip(ItemRefTooltip, link, 1)
        end
        return T.unpack(tmp)
    end)
end

function M.extend_tooltip(tooltip, link, quantity)
    hide_money_rows(tooltip)

    local item_id, suffix_id = info.parse_link(link)
    quantity = IsShiftKeyDown() and quantity or 1
    local item_info = T.temp-info.item(item_id)
    if item_info and (settings.disenchant_distribution or settings.disenchant_value) then
        local distribution = disenchant.distribution(item_info.slot, item_info.quality, item_info.level, item_id)
        if getn(distribution) > 0 then
            if settings.disenchant_distribution then
                tooltip:AddLine('Disenchants into:', aux.color.tooltip.disenchant.distribution())
                sort(distribution, function(a,b) return a.probability > b.probability end)
                for _, event in ipairs(distribution) do
                    tooltip:AddLine(format('  %s%% %s (%s-%s)', event.probability * 100, info.display_name(event.item_id, true) or 'item:' .. event.item_id, event.min_quantity, event.max_quantity), aux.color.tooltip.disenchant.distribution())
                end
            end
            if settings.disenchant_value then
                local disenchant_value = disenchant.value(item_info.slot, item_info.quality, item_info.level, item_id)
                if disenchant_value then
                    add_money_line(tooltip, 'Disenchant:', disenchant_value, aux.color.tooltip.disenchant.value)
                else
                    tooltip:AddLine('Disenchant: ' .. UNKNOWN, aux.color.tooltip.disenchant.value())
                end
            end
        end
    end
    if settings.merchant_buy then
        local _, price, limited = info.merchant_info(item_id)
        if price then
            add_money_line(tooltip, 'Vendor Buy ' .. (limited and '(limited):' or ':'), price * quantity, aux.color.tooltip.merchant)
        end
    end
    if settings.merchant_sell then
        local price = info.merchant_info(item_id)
		if price == nil and ShaguTweaks and ShaguTweaks.SellValueDB[item_id] ~= nil then
			local charges = 1
			if info.max_item_charges(item_id) ~= nil then 
				charges=info.max_item_charges(item_id) 
			end
			price = ShaguTweaks.SellValueDB[item_id] / charges
		end
        if price ~= 0 then
            if price then
                add_money_line(tooltip, 'Vendor:', price * quantity, aux.color.tooltip.merchant)
            else
                tooltip:AddLine('Vendor: ' .. UNKNOWN, aux.color.tooltip.merchant())
            end
        end
    end
    local auctionable = not item_info or info.auctionable(T.temp-info.tooltip('link', item_info.itemstring), item_info.quality)
    local item_key = (item_id or 0) .. ':' .. (suffix_id or 0)
    local value = history.value(item_key)
    if auctionable then
        if settings.value then
            if value then
                add_money_line(tooltip, 'Auction:', value * quantity, aux.color.tooltip.value)
            else
                tooltip:AddLine('Auction: ' .. UNKNOWN, aux.color.tooltip.value())
            end
        end
        if settings.daily then
            local market_value = history.market_value(item_key)
            if market_value then
                local percentage = '(' .. gui.percentage_historical(aux.round(market_value / value * 100)) .. ')'
                add_money_line(tooltip, 'Today:', market_value * quantity, aux.color.tooltip.value, percentage)
            else
                tooltip:AddLine('Today: ' .. UNKNOWN, aux.color.tooltip.value())
            end
        end
    end

    if tooltip == GameTooltip and game_tooltip_money > 0 then
        SetTooltipMoney(tooltip, game_tooltip_money)
        local state = tooltip_money_states[tooltip]
        if state and state.min_width > 0 then
            local money_frame = getglobal(tooltip:GetName() .. 'MoneyFrame')
            if money_frame and money_frame:GetWidth() > state.min_width then
                state.min_width = money_frame:GetWidth()
            end
            tooltip:SetMinimumWidth(state.min_width)
        end
    end
    tooltip:Show()
end

function game_tooltip_hooks:SetHyperlink(itemstring)
    local name, _, quality = GetItemInfo(itemstring)
    if name then
        local hex = aux.select(4, GetItemQualityColor(quality))
        local link = hex ..  '|H' .. itemstring .. '|h[' .. name .. ']|h' .. FONT_COLOR_CODE_CLOSE
        extend_tooltip(GameTooltip, link, 1)
    end
end

function game_tooltip_hooks:SetAuctionItem(type, index)
	local link = GetAuctionItemLink(type, index)
    if link then
        extend_tooltip(GameTooltip, link, aux.select(3, GetAuctionItemInfo(type, index)))
    end
end

function game_tooltip_hooks:SetLootItem(slot)
	local link = GetLootSlotLink(slot)
    if link then
        extend_tooltip(GameTooltip, link, aux.select(3, GetLootSlotInfo(slot)))
    end
end

function game_tooltip_hooks:SetQuestItem(qtype, slot)
	local link = GetQuestItemLink(qtype, slot)
    if link then
        extend_tooltip(GameTooltip, link, aux.select(3, GetQuestItemInfo(qtype, slot)))
    end
end

function game_tooltip_hooks:SetQuestLogItem(qtype, slot)
	local link = GetQuestLogItemLink(qtype, slot)
    if link then
        extend_tooltip(GameTooltip, link, aux.select(3, GetQuestLogRewardInfo(slot)))
    end
end

function game_tooltip_hooks:SetBagItem(bag, slot)
	local link = GetContainerItemLink(bag, slot)
    if link then
        extend_tooltip(GameTooltip, link, aux.select(2, GetContainerItemInfo(bag, slot)))
    end
end

function game_tooltip_hooks:SetInboxItem(index)
    local name, _, quantity = GetInboxItem(index)
    local id = name and info.item_id(name)
    if id then
        local _, itemstring, quality = GetItemInfo(id)
		if quality and itemstring then
			local hex = aux.select(4, GetItemQualityColor(tonumber(quality)))
			local link = hex ..  '|H' .. itemstring .. '|h[' .. name .. ']|h' .. FONT_COLOR_CODE_CLOSE
			extend_tooltip(GameTooltip, link, quantity)
		end
    end
end

function game_tooltip_hooks:SetInventoryItem(unit, slot)
	local link = GetInventoryItemLink(unit, slot)
    if link then
        extend_tooltip(GameTooltip, link, 1)
    end
end

function game_tooltip_hooks:SetMerchantItem(slot)
	local link = GetMerchantItemLink(slot)
    if link then
        local quantity = aux.select(4, GetMerchantItemInfo(slot))
        extend_tooltip(GameTooltip, link, quantity)
    end
end

function game_tooltip_hooks:SetCraftItem(skill, slot)
    local link, quantity
    if slot then
        link, quantity = GetCraftReagentItemLink(skill, slot), aux.select(3, GetCraftReagentInfo(skill, slot))
    else
        link, quantity = GetCraftItemLink(skill), 1
    end
    if link then
	    extend_tooltip(GameTooltip, link, quantity)
    end
end

function game_tooltip_hooks:SetCraftSpell(slot)
	local link = GetCraftItemLink(slot)
    if link then
        extend_tooltip(GameTooltip, link, 1)
    end
end

function game_tooltip_hooks:SetTradeSkillItem(skill, slot)
    local link, quantity
    if slot then
        link, quantity = GetTradeSkillReagentItemLink(skill, slot), aux.select(3, GetTradeSkillReagentInfo(skill, slot))
    else
        link, quantity = GetTradeSkillItemLink(skill), 1
    end
    if link then
        extend_tooltip(GameTooltip, link, quantity)
    end
end

function game_tooltip_hooks:SetAuctionSellItem()
    local name, _, quantity = GetAuctionSellItemInfo()
    if name then
        for slot in info.inventory() do
	        T.temp(slot)
            local link = GetContainerItemLink(unpack(slot))
            if link and aux.select(5, info.parse_link(link)) == name then
                extend_tooltip(GameTooltip, link, quantity)
                return
            end
        end
    end
end