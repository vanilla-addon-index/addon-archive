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
local MONEY_LABEL_GAP = 3
local MONEY_TOOLTIP_PADDING = 12

local tooltip_money_states = {}

local function hide_money_rows(tooltip)
    local state = tooltip_money_states[tooltip]
    if not state then return end
    for _, row in state.rows do
        row:Hide()
    end
    state.used = 0
    state.min_width = 0
end

local function money_state(tooltip)
    local state = tooltip_money_states[tooltip]
    if state then return state end

    state = {rows = {}, used = 0, min_width = 0}
    tooltip_money_states[tooltip] = state

    -- Bag tooltips and other addons can call Show again after our item hook.
    -- Native layout only measures text, so keep the custom coins' width on
    -- every subsequent layout, not just at the end of extend_tooltip.
    local show = tooltip.Show
    tooltip.Show = function(self)
        show(self)
        if state.used > 0 and self:GetWidth() < state.min_width then
            self:SetWidth(state.min_width)
        end
    end

    local on_hide = tooltip:GetScript('OnHide')
    tooltip:SetScript('OnHide', function()
        hide_money_rows(tooltip)
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
    -- A blank right-hand FontString is not a reliable vertical anchor on
    -- 1.12 clients. Reserve a real text line and follow its visible label.
    tooltip:AddLine(label, r, g, b)

    local line_number = tooltip:NumLines()
    local left = getglobal(tooltip:GetName() .. 'TextLeft' .. line_number)
    local row = acquire_money_row(tooltip)
    row.label, row.value, row.value_suffix = left, value, suffix
    layout_money_row(row, value, suffix)

    row:ClearAllPoints()
    row:SetPoint('LEFT', left, 'LEFT', left:GetStringWidth() + MONEY_LABEL_GAP, 0)
    row:Show()

end

local function finish_money_layout(tooltip)
    -- Custom child frames do not contribute to GameTooltip's automatic size.
    -- Measure again after Show has laid out the text, including newly created
    -- FontStrings, then enforce the completed coin rows' actual right edge.
    tooltip:Show()
    local state = tooltip_money_states[tooltip]
    if not state or state.used == 0 then return end

    local required_width = 0
    for i = 1, state.used do
        local row = state.rows[i]
        local width = layout_money_row(row, row.value, row.value_suffix)
        local label_width = row.label:GetStringWidth()
        row:ClearAllPoints()
        row:SetPoint('LEFT', row.label, 'LEFT', label_width + MONEY_LABEL_GAP, 0)
        local right, left = row:GetRight(), tooltip:GetLeft()
        if right and left then
            required_width = max(required_width, right - left + MONEY_TOOLTIP_PADDING)
        else
            required_width = max(required_width, label_width + MONEY_LABEL_GAP + width + 2 * MONEY_TOOLTIP_PADDING)
        end
    end
    state.min_width = required_width
    -- SetMinimumWidth is also used by Blizzard's money/content layout.
    -- Leave it alone: our bound already includes the tooltip's edge padding.
    -- The Show wrapper expands the native result only when coins need space.
    tooltip:Show()
end

local game_tooltip_hooks, game_tooltip_money = {}, 0

function aux.handle.LOAD()
	settings = aux.character_data.tooltip
	do
		local inside_hook = false
	    for name, f in game_tooltip_hooks do
            if type(GameTooltip[name]) == 'function' then
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

local function vendor_sell_price(item_id)
    local api = C_Item
    -- Aux prices charged items per charge; retain its existing path for those.
    -- ClassicAPI returns a per-item value and can request data on a cache miss.
    if item_id and not info.max_item_charges(item_id) and api
        and type(api.IsItemDataCachedByID) == 'function'
        and type(api.GetItemSellPriceByID) == 'function' then
        local ok, cached = pcall(api.IsItemDataCachedByID, item_id)
        if ok and cached then
            local good, price = pcall(api.GetItemSellPriceByID, item_id)
            if good and type(price) == 'number' and price >= 0 then return price end
        end
    end
    return info.merchant_info(item_id)
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
        local price = vendor_sell_price(item_id)
        local vendor_prices = ShaguTweaks and ShaguTweaks.SellValueDB
		if price == nil and type(vendor_prices) == 'table' and type(vendor_prices[item_id]) == 'number' then
			local charges = 1
			if info.max_item_charges(item_id) ~= nil then 
				charges=info.max_item_charges(item_id) 
			end
			price = vendor_prices[item_id] / charges
		end
        if price ~= 0 then
            if price then
                add_money_line(tooltip, 'Vendor:', price * quantity, aux.color.tooltip.merchant)
            else
                tooltip:AddLine('Vendor: ' .. UNKNOWN, aux.color.tooltip.merchant())
            end
        end
    end
    if settings.value or settings.daily then
        local auctionable = not item_info or info.auctionable(T.temp-info.tooltip('link', item_info.itemstring), item_info.quality)
        local item_key = (item_id or 0) .. ':' .. (suffix_id or 0)
        local value = history.value(item_key)
        if auctionable then
            if settings.value then
                if value then
                    add_money_line(tooltip, 'Aux:', value * quantity, aux.color.tooltip.value)
                else
                    tooltip:AddLine('Aux: ' .. UNKNOWN, aux.color.tooltip.value())
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
    end

    if tooltip == GameTooltip and game_tooltip_money > 0 then
        SetTooltipMoney(tooltip, game_tooltip_money)
    end
    finish_money_layout(tooltip)
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

function game_tooltip_hooks:SetLootRollItem(roll_id)
    local link = GetLootRollItemLink(roll_id)
    if link then
        local _, _, quantity = GetLootRollItemInfo(roll_id)
        extend_tooltip(GameTooltip, link, quantity or 1)
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
        local quantity = IsShiftKeyDown() and GetInventoryItemCount(unit, slot)
        extend_tooltip(GameTooltip, link, quantity and quantity > 0 and quantity or 1)
    end
end

function game_tooltip_hooks:SetTradePlayerItem(slot)
    local link = GetTradePlayerItemLink(slot)
    if link then
        local _, _, quantity = GetTradePlayerItemInfo(slot)
        extend_tooltip(GameTooltip, link, quantity or 1)
    end
end

function game_tooltip_hooks:SetTradeTargetItem(slot)
    local link = GetTradeTargetItemLink(slot)
    if link then
        local _, _, quantity = GetTradeTargetItemInfo(slot)
        extend_tooltip(GameTooltip, link, quantity or 1)
    end
end

-- These link APIs are optional on the 1.12 client.
if type(GetSendMailItemLink) == 'function' then
    function game_tooltip_hooks:SetSendMailItem(index)
        local link = GetSendMailItemLink(index)
        if link then
            local _, _, quantity = GetSendMailItem(index)
            extend_tooltip(GameTooltip, link, quantity or 1)
        end
    end
end

if type(GetBuybackItemLink) == 'function' then
    function game_tooltip_hooks:SetBuybackItem(slot)
        local link = GetBuybackItemLink(slot)
        if link then
            local _, _, _, quantity = GetBuybackItemInfo(slot)
            extend_tooltip(GameTooltip, link, quantity or 1)
        end
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
