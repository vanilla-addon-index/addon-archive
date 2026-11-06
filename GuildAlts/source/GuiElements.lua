GuildAlts = GuildAlts or {}
---@class GuildAlts
local m = GuildAlts

if m.GuiElements then return end

---@class GuiElements
---@field tiny_button fun( parent: Frame, text: string?, tooltip: string?, color: table|string?, font-size: number? ): TinyButton
---@field create_button fun( parent: Frame, title: string, width: integer?, onclick: function, on_receive_drag: function? ): MyButton
local M = {}

---@param parent Frame
---@param text string?
---@param tooltip string?
---@param color string|table?
---@param font_size number?
---@return TinyButton
function M.tiny_button( parent, text, tooltip, color, font_size )
	---@class TinyButton: Button
	local button = CreateFrame( "Button", nil, parent )
	button.active = false
	if not text then text = 'X' end

	if type( color ) == "string" and color ~= "" then
		local str_color = color
		color = {}
		color.r, color.g, color.b, color.a = m.hex_to_rgba( str_color )
	end


	if not color then color = { r = .9, g = .8, b = .25 } end
	button:SetWidth( 18 )
	button:SetHeight( 18 )

	button:SetHighlightTexture( "Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight" )
	if text == 'X' then
		button:SetNormalTexture( "Interface\\Buttons\\UI-Panel-MinimizeButton-Up" )
		button:SetPushedTexture( "Interface\\Buttons\\UI-Panel-MinimizeButton-Down" )
	else
		button:SetNormalTexture( "Interface\\AddOns\\GuildInventory\\assets\\tiny-button-up.tga" )
		button:SetPushedTexture( "Interface\\AddOns\\GuildInventory\\assets\\tiny-button-down.tga" )
	end
	button:GetHighlightTexture():SetTexCoord( .1875, .78125, .21875, .78125 )
	button:GetNormalTexture():SetTexCoord( .1875, .78125, .21875, .78125 )
	button:GetPushedTexture():SetTexCoord( .1875, .78125, .21875, .78125 )

	if text ~= 'X' then
		local font_x, font_y

		button:SetText( text )
		button:SetPushedTextOffset( -1.5, -1.5 )

		if string.upper( text ) == text then
			font_x, font_y = 0, 0
			font_size = font_size or 13
		else
			font_x, font_y = -1, 2
			font_size = font_size or 15
		end

		button:GetFontString():SetFont( "FONTS\\FRIZQT__.TTF", font_size, "" )
		button:GetFontString():SetTextColor( color.r, color.g, color.b, color.a or 1 )
		button:GetFontString():SetPoint( "Center", button, "Center", font_x, font_y )
	end

	button:SetScript( "OnEnter", function()
		local self = button
		self:SetBackdropBorderColor( color.r, color.g, color.b, color.a or 1 )
		if tooltip then
			GameTooltip:SetOwner( button, "ANCHOR_RIGHT" )
			GameTooltip:SetText( tooltip )
			GameTooltip:SetScale( 0.8 )
			GameTooltip:Show()
		end
	end )

	button:SetScript( "OnLeave", function()
		if tooltip and GameTooltip:IsVisible() then
			GameTooltip:SetScale( 1 )
			GameTooltip:Hide()
		end
	end )

	return button
end

---@param parent Frame
---@param title string
---@param width integer?
---@param on_click function
---@param on_receive_drag function?
---@return MyButton
function M.create_button( parent, title, width, on_click, on_receive_drag )
	---@class MyButton: Button
	local btn = CreateFrame( "Button", nil, parent, title == "Cancel" and nil or "UIPanelButtonTemplate" )
	btn:SetScript( "OnClick", on_click )
	btn:SetScript( "OnReceiveDrag", on_receive_drag )

	if title == "Cancel" then
		btn:SetNormalTexture( "Interface\\Buttons\\CancelButton-Up" )
		btn:GetNormalTexture():SetTexCoord( 0, 1, 0, 1 )
		btn:SetPushedTexture( "Interface\\Buttons\\CancelButton-Down" )
		btn:GetPushedTexture():SetTexCoord( 0, 1, 0, 1 )
		btn:SetHighlightTexture( "Interface\\Buttons\\CancelButton-Highlight" )
		btn:GetHighlightTexture():SetTexCoord( 0, 1, 0, 1 )
		btn:GetHighlightTexture():SetBlendMode( "ADD" )
		btn:SetHitRectInsets( 9, 7, 7, 10 )
		btn:SetWidth( 34 )
		btn:SetHeight( 34 )
	else
		btn:SetWidth( width and width or 100 )
		btn:SetHeight( 24 )
		btn:SetText( title )
	end

	btn.Disable = function()
		btn:EnableMouse( false )
		btn:GetFontString():SetTextColor( 0.5, 0.41, 0 )
		btn:GetNormalTexture():SetVertexColor( 0.5, 0.5, 0.5 )
	end

	btn.Enable = function()
		btn:EnableMouse( true )
		btn:GetFontString():SetTextColor( 1, 0.82, 0 )
		btn:GetNormalTexture():SetVertexColor( 1, 1, 1 )
	end

	return btn
end

m.GuiElements = M

return M
