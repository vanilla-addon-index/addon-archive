module 'aux'

local gui = require 'aux.gui'

local drag_outline

local function stop_window_drag(apply_position)
    if not drag_outline or not drag_outline.owner then return end
    local owner = drag_outline.owner
    drag_outline:StopMovingOrSizing()
    local left, top = drag_outline:GetLeft(), drag_outline:GetTop()
    drag_outline.owner = nil
    drag_outline:Hide()
    if apply_position and left and top then
        owner:ClearAllPoints()
        owner:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', left, top)
    end
end

local function start_window_drag()
    local owner = this
    local left, top = owner:GetLeft(), owner:GetTop()
    if not left or not top then return end
    stop_window_drag(false)
    if not drag_outline then
        drag_outline = CreateFrame('Frame', 'AuxDragOutline', UIParent)
        drag_outline:SetFrameStrata('FULLSCREEN_DIALOG')
        drag_outline:SetMovable(true)
        drag_outline:EnableMouse(true)
        drag_outline:SetClampedToScreen(true)
        drag_outline:SetBackdrop({
            bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
            edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
            tile = true, tileSize = 16, edgeSize = 16,
            insets = {left = 4, right = 4, top = 4, bottom = 4},
        })
        drag_outline:SetBackdropColor(0, 0, 0, .3)
        drag_outline:SetBackdropBorderColor(1, 1, 1, .9)
        drag_outline:SetScript('OnMouseUp', function()
            if arg1 == 'LeftButton' then stop_window_drag(true) end
        end)
    end
    -- Both frames have UIParent as parent, so matching scale preserves coordinates.
    drag_outline:SetScale(owner:GetScale())
    drag_outline:SetWidth(owner:GetWidth())
    drag_outline:SetHeight(owner:GetHeight())
    drag_outline:ClearAllPoints()
    drag_outline:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', left, top)
    drag_outline.owner = owner
    drag_outline:Show()
    drag_outline:StartMoving()
end

function handle.LOAD()
	for _, v in ipairs(tab_info) do
		tabs:create_tab(v.name)
	end
end

function handle.INIT_UI()
    do
        local frame = CreateFrame('Frame', 'aux_frame', UIParent)
        tinsert(UISpecialFrames, 'aux_frame')
        if not gui.is_blizzard() then
            gui.set_window_style(frame)
            frame:SetBackdropColor(24/255, 24/255, 24/255, .98)
        end
        gui.set_size(frame, 768, 447)
        if gui.is_blizzard() then
            local frameBorder = CreateFrame('Frame', '$parentBorder', frame)
            frameBorder:SetWidth(frame:GetWidth() + 24)
            frameBorder:SetHeight(frame:GetHeight() + 24)
            frameBorder:SetPoint('CENTER', frame, 'CENTER')
            frameBorder:SetBackdrop({edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]], edgeSize = 24, 
                tile = true, tileSize = 24, bgFile = [[Interface\Buttons\WHITE8X8]],
                insets = { 
                    left = 6, right = 6, top = 6, bottom = 6 }})
            frameBorder:SetBackdropColor(24/255, 24/255, 24/255, .98)
        end
        frame:SetPoint('LEFT', 100, 0)
        frame:SetToplevel(true)
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:SetClampedToScreen(true)
        frame:RegisterForDrag('LeftButton')
        frame:SetScript('OnDragStart', start_window_drag)
        frame:SetScript('OnDragStop', function() stop_window_drag(true) end)
        frame:SetScript('OnShow', function() PlaySound('AuctionWindowOpen') end)
        frame:SetScript('OnHide', function()
            stop_window_drag(false)
            PlaySound('AuctionWindowClose')
            CloseAuctionHouse()
        end)
        frame.content = CreateFrame('Frame', nil, frame)
        frame.content:SetPoint('TOPLEFT', 4, -80)
        frame.content:SetPoint('BOTTOMRIGHT', -4, 35)
        frame:Hide()
        M.frame = frame
    end
    do
        tabs = gui.tabs(frame, 'DOWN')
        tabs._on_select = on_tab_click
        function M.set_tab(id) tabs:select(id) end
    end
    do
        local btn = gui.button(frame)
        btn:SetPoint('BOTTOMRIGHT', -5, 5)
        gui.set_size(btn, 60, 24)
        btn:SetText('Close')
        btn:SetScript('OnClick', function() frame:Hide() end)
        btn:SetFrameLevel(btn:GetFrameLevel() + 2)
        close_button = btn
    end
    do
        local btn = gui.button(frame, gui.font_size.small)
        btn:SetPoint('RIGHT', close_button, 'LEFT' , -5, 0)
        gui.set_size(btn, gui.is_blizzard() and 80 or 60, 24)
        btn:SetText(color.blizzard'Blizzard UI')
        btn:SetFrameLevel(btn:GetFrameLevel() + 2)
        btn:SetScript('OnClick',function()
            if AuctionFrame:IsVisible() then HideUIPanel(AuctionFrame) else ShowUIPanel(AuctionFrame) end
        end)
        local money_frame = CreateFrame('Frame', '$parentMoneyFrame', aux_frame.content, 'SmallMoneyFrameTemplate')
        money_frame:SetPoint('RIGHT', btn, 'LEFT', 5, 0)
        money_frame:SetToplevel()
        if gui.is_blizzard() then
            local texture = aux_frame.content:CreateTexture(nil, 'ARTWORK')
            gui.set_size(texture, 145, 34)
            texture:SetTexture('Interface\\MoneyFrame\\UI-MONEYFRAME-BORDER')
            texture:SetPoint('TOPRIGHT', money_frame, -6, 4)
        end
    end
end
