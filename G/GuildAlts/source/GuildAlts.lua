---@class GuildAlts
GuildAlts = GuildAlts or {}

---@class GuildAlts
local m = GuildAlts

GuildAlts.name = "GuildAlts"
GuildAlts.prefix = "GALTS"
GuildAlts.tagcolor = "FF57C9B0"
GuildAlts.events = {}
GuildAlts.debug_enabled = false
GuildAlts.api = getfenv()

function GuildAlts:init()
	self.frame = CreateFrame( "Frame" )
	self.frame:SetScript( "OnEvent", function()
		if self.events[ event ] then
			self.events[ event ]( self )
		end
	end )

	for k, _ in pairs( m.events ) do
		self.frame:RegisterEvent( k )
	end

	if m.api.IsAddOnLoaded( "pfUI" ) and m.api.pfUI and m.api.pfUI.api and m.api.pfUI.env and m.api.pfUI.env.C then
		self.pfui_skin_enabled = true
	end
end

function GuildAlts.events:ADDON_LOADED()
	if arg1 ~= self.name then return end

	---@type MessageHandler
	m.msg = m.MessageHandler.new()

	m.player = UnitName( "player" )
	m.player_class = UnitClass( "player" )
	m.offset = 0
	m.selected = nil
	m.frame_items = {}
	m.characters = nil

	GuildAltsDB = GuildAltsDB or {}
	m.db = GuildAltsDB
	m.db.characters = m.db.characters or {}

	if not m.db.last_update or m.db.last_update < m.get_server_timestamp() - 300 then
		m.msg.request_alts()
	end

	self.build_alt_map()

	for i = 1, NUM_CHAT_WINDOWS do
		local frame = self.api[ "ChatFrame" .. i ]
		if frame then self.wrap_chat_frame( frame ) end
	end

	m.api[ "SLASH_GUILDALTS1" ] = "/ga"
	m.api[ "SLASH_GUILDALTS2" ] = "/guildalts"
	SlashCmdList[ "GUILDALTS" ] = function( args )
		if args == "debug" then
			m.debug_enabled = not m.debug_enabled
			if m.debug_enabled then
				m.info( "Debug is enabled" )
			else
				m.info( "Debug is disabled" )
			end
			return
		end

		if args == "clear" then
			m.info( "Clearing and refreshing alt list." )
			m.db.characters = {}
			m.msg.request_alts()
			return
		end

		if args == "refresh" or args == "r" then
			m.info( "Refreshing alt list from other guild members." )
			m.msg.request_alts()
			return
		end

		if args == "broadcast" or args == "b" then
			m.info( "Broadcasting alt list to all guild members." )
			m.msg.send_alts()
			return
		end

		if args == "versioncheck" or args == "vc" then
			m.info( "Requesting version information." )
			m.msg.version_check()
			return
		end

		m.toggle_popup()
	end

	m.version = GetAddOnMetadata( m.name, "Version" )
	self.info( string.format( "(v%s) Loaded", m.version ) )
end

function GuildAlts.build_alt_map()
	m.alt_map = {}
	for main, data in pairs( m.db.characters ) do
		if data.alts then
			for _, alt in data.alts do
				m.alt_map[ alt ] = main
			end
		end
	end
end

---@param frame Frame
function GuildAlts.wrap_chat_frame( frame )
	local original_add_message = frame[ "AddMessage" ]

	frame[ "AddMessage" ] = function( self, msg, ... )
		if msg then
			for alt, main in pairs( m.alt_map ) do
				if alt and alt ~= m.player then
					msg = string.gsub( msg, "(.?|Hplayer:" .. alt .. ".-%]|?h?|?r?)(.*)", function( a, b)
						return a .. "(|cffeeeeee" .. main .. "|r)" .. b
					end )
				end
			end
		end

		return original_add_message( self, msg, unpack( arg ) )
	end
end

function GuildAlts.create_popup()
	---@param parent Frame
	---@return FrameItem
	local function create_item( parent )
		---@class FrameItem: Button
		local frame = m.FrameBuilder.new()
				:type( "Button" )
				:parent( parent )
				:width( 382 )
				:height( 16 )
				:frame_style( "NONE" )
				:build()

		frame:SetHighlightTexture( "Interface\\QuestFrame\\UI-QuestTitleHighlight" )
		frame:SetScript( "OnClick", function()
			if m.selected == frame.index then
				m.selected = nil
				m.show_info()
			else
				m.selected = frame.index
				m.show_info( frame.index )
			end
			m.refresh()
		end )

		local selected_tex = frame:CreateTexture( nil, "BACKGROUND" )
		selected_tex:SetTexture( "Interface\\QuestFrame\\UI-QuestLogTitleHighlight" )
		selected_tex:SetAllPoints( frame )
		selected_tex:SetVertexColor( 0.3, 0.3, 1, 1 )
		selected_tex:Hide()

		local text_main = frame:CreateFontString( nil, "ARTWORK", "GameFontHighlightSmall" )
		text_main:SetPoint( "Left", frame, "Left", 5, 0 )
		text_main:SetHeight( 16 )

		local text_alts = frame:CreateFontString( nil, "ARTWORK", "GameFontHighlightSmall" )
		text_alts:SetPoint( "Right", frame, "Right", -5, 0 )
		text_alts:SetWidth( 310 )
		text_alts:SetHeight( 16 )
		text_alts:SetJustifyH( "Right" )

		---@param select boolean
		frame.set_selected = function( select )
			if select then
				selected_tex:Show()
			else
				selected_tex:Hide()
			end
		end

		frame.set_item = function( index )
			frame.index = index
			text_main:SetText( m.characters[ index ].main )

			local alts = ""
			for _, alt in ipairs( m.characters[ index ].alts ) do
				alts = alts .. alt .. ", "
			end
			text_alts:SetText( string.match( alts, "(.-), $" ) )

			frame:Show()
		end

		return frame
	end

	---@class FrameAlts: Frame
	local frame = m.FrameBuilder.new()
			:name( "GuildAltsFrame" )
			:title( string.format( "Guild Alts v%s", m.version ) )
			:width( 427 )
			:height( 343 )
			:frame_style( "TOOLTIP" )
			:backdrop_color( 0, 0, 0, 1 )
			:close_button()
			:movable()
			:esc()
			:hidden()
			:on_drag_stop( function( self )
				local point, _, relative_point, x, y = self:GetPoint()
				m.db.position = { point = point, relative_point = relative_point, x = x, y = y }
			end )
			:build()

	if m.db.position then
		local p = m.db.position
		frame:ClearAllPoints()
		frame:SetPoint( p.point, UIParent, p.relative_point, p.x, p.y )
	end
	frame.locked = false

	local border_characters = m.FrameBuilder.new()
			:parent( frame )
			:point( "TopLeft", frame, "TopLeft", 10, -35 )
			:point( "Right", frame, "Right", -10, 0 )
			:height( 177 )
			:frame_style( "TOOLTIP" )
			:backdrop( { bgFile = "Interface/Buttons/WHITE8x8" } )
			:backdrop_color( 0, 0, 0, 1 )
			:build()

	border_characters:EnableMouseWheel( true )
	border_characters:SetScript( "OnMouseWheel", function()
		local value = frame.scroll_bar:GetValue() - arg1
		frame.scroll_bar:SetValue( value )
	end )

	local scroll_bar = CreateFrame( "Slider", "GuildAltsScrollBar", border_characters, "UIPanelScrollBarTemplate" )
	frame.scroll_bar = scroll_bar
	scroll_bar:SetPoint( "TopRight", border_characters, "TopRight", -5, -20 )
	scroll_bar:SetPoint( "Bottom", border_characters, "Bottom", 0, 20 )
	scroll_bar:SetMinMaxValues( 0, 0 )
	scroll_bar:SetValueStep( 1 )
	scroll_bar:SetScript( "OnValueChanged", function()
		m.offset = arg1
		m.refresh()
	end )

	for i = 1, 10 do
		local item = create_item( border_characters )
		item:SetPoint( "TopLeft", border_characters, "TopLeft", 4, ((i - 1) * -17) - 4 )
		table.insert( m.frame_items, item )
	end

	local border_info = m.FrameBuilder.new()
			:parent( frame )
			:point( "TopLeft", border_characters, "BottomLeft", 0, -10 )
			:point( "Right", frame, "Right", -10, 0 )
			:height( 110 )
			:frame_style( "TOOLTIP" )
			:backdrop( { bgFile = "Interface/Buttons/WHITE8x8" } )
			:backdrop_color( 0, 0, 0, 1 )
			:build()

	local input_main = CreateFrame( "EditBox", "GuildAltsInputMain", border_info, "InputBoxTemplate" )
	input_main:SetPoint( "TopLeft", border_info, "TopLeft", 45, -8 )
	input_main:SetWidth( 90 )
	input_main:SetHeight( 22 )
	input_main:SetAutoFocus( false )
	input_main:EnableKeyboard( true )
	frame.input_main = input_main

	local label_main = border_info:CreateFontString( nil, "ARTWORK", "GameFontHighlight" )
	label_main:SetPoint( "Right", input_main, "Left", -10, 0 )
	label_main:SetText( "Main:" )

	local input_alts = CreateFrame( "EditBox", "GuildAltsInputAlts", border_info, "InputBoxTemplate" )
	input_alts:SetPoint( "TopLeft", input_main, "BottomLeft", 0, -5 )
	input_alts:SetWidth( 350 )
	input_alts:SetHeight( 22 )
	input_alts:SetAutoFocus( false )
	input_alts:EnableKeyboard( true )
	frame.input_alts = input_alts

	local label_alts = border_info:CreateFontString( nil, "ARTWORK", "GameFontHighlight" )
	label_alts:SetPoint( "Right", input_alts, "Left", -10, 0 )
	label_alts:SetText( "Alts:" )

	local cb_lock = CreateFrame( "CheckButton", "GuildAltsLock", border_info, "UICheckButtonTemplate" )
	cb_lock:SetPoint( "TopRight", input_alts, "BottomLeft", -5, -5 )
	cb_lock:SetWidth( 22 )
	cb_lock:SetHeight( 22 )
	m.api[ cb_lock:GetName() .. "Text" ]:SetText( "Lock" )
	cb_lock:Hide()
	frame.cb_lock = cb_lock

	local btn_update = m.GuiElements.create_button( border_info, "Add", 80, function()
		local main = m.normalize_and_validate_name( input_main:GetText() )
		local str_alts = input_alts:GetText()
		local alts = {}

		if not main then
			m.error( "Invalid main character name." )
			return
		end

		for alt in string.gmatch( str_alts, "%s*([^,]+)%s*,?" ) do
			local alt_name = m.normalize_and_validate_name( strtrim( alt ) )
			if not alt_name then
				m.error( string.format( "%q is not a valid name.", alt ) )
				return
			end
			if m.get_main( alt_name ) and m.get_main( alt_name ) ~= main then
				m.error( string.format( "%q already exists.", alt_name ) )
				return
			end
			if m.db.characters[ alt_name ] then
				m.error( string.format( "%q is a main.", alt_name ) )
				return
			end
			table.insert( alts, alt_name )
		end

		if getn( alts ) == 0 then
			m.error( "Missing alt name(s)." )
			return
		end

		local data = {
			[ main ] = {
				locked = cb_lock:GetChecked(),
				alts = alts
			}
		}

		m.update_character( data )
		m.msg.send_character( data )

		m.selected = nil
		m.show_info()
		input_main:SetFocus()
	end )

	btn_update:SetPoint( "BottomRight", border_info, "BottomRight", -10, 13 )
	frame.btn_update = btn_update

	local btn_delete = m.GuiElements.create_button( border_info, "Delete", 80, function()
		local main = m.normalize_and_validate_name( input_main:GetText() )
		if main then
			local data = { [ main ] = {} }

			m.update_character( data )
			m.msg.send_character( data )
			m.selected = nil
			m.show_info()
			input_main:SetFocus()
		end
	end )
	btn_delete:SetPoint( "Right", btn_update, "Left", -10, 0 )
	btn_delete:Hide()
	frame.btn_delete = btn_delete


	input_main:SetScript( "OnTabPressed", function()
		input_alts:SetFocus()
	end )
	input_main:SetScript( "OnEnterPressed", function()
		input_alts:SetFocus()
	end )

	input_alts:SetScript( "OnTabPressed", function()
		input_main:SetFocus()
	end )
	input_alts:SetScript( "OnEnterPressed", function()
		if frame.locked then return end
		btn_update:Click( "LeftButton" )
	end )

	return frame
end

function GuildAlts.show_info( index )
	if index then
		local alts = ""
		for _, alt in ipairs( m.characters[ index ].alts ) do
			alts = alts .. alt .. ", "
		end

		m.popup.input_main:SetText( m.characters[ index ].main )
		m.popup.input_alts:SetText( string.match( alts, "(.-), $" ) or "" )
		m.popup.btn_update:SetText( "Update" )
		m.popup.btn_delete:Show()
		m.popup.cb_lock:SetChecked( m.characters[ index ].locked )

		if m.characters[ index ].locked and m.characters[ index ].main ~= m.player then
			m.popup.locked = true
			m.popup.btn_update:Disable()
			m.popup.btn_delete:Disable()
		else
			m.popup.locked = false
			m.popup.btn_update:Enable()
			m.popup.btn_delete:Enable()
		end

		if m.player == m.characters[ index ].main then
			m.popup.cb_lock:Show()
		else
			m.popup.cb_lock:Hide()
		end
	else
		m.popup.locked = false
		m.popup.input_main:SetText( "" )
		m.popup.input_alts:SetText( "" )
		m.popup.btn_update:SetText( "Add" )
		m.popup.btn_update:Enable()
		m.popup.btn_delete:Hide()
		m.popup.cb_lock:Hide()
	end
end

function GuildAlts.refresh( get_data )
	if not m.characters or get_data then
		m.build_alt_map()
		m.characters = {}
		for main, data in pairs( m.db.characters ) do
			local cdata = { main = main, alts = {} }
			cdata.locked = data.locked
			if data.alts then
				for _, alt in data.alts do
					table.insert( cdata.alts, alt )
				end
			end
			table.insert( m.characters, cdata )
		end

		table.sort( m.characters, function( a, b )
			return a.main < b.main
		end )

		local max = math.max( 0, getn( m.characters ) - 10 )
		m.popup.scroll_bar:SetMinMaxValues( 0, max )
	end

	for i = 1, 10 do
		if m.characters[ i ] then
			m.frame_items[ i ].set_item( i + m.offset )
			m.frame_items[ i ].set_selected( m.selected == i + m.offset )
		else
			m.frame_items[ i ]:Hide()
		end
	end

	local max = math.max( 0, getn( m.characters ) - 10 )
	local value = math.min( max, m.popup.scroll_bar:GetValue() )

	if value == 0 then
		m.api[ "GuildAltsScrollBarScrollUpButton" ]:Disable()
	else
		m.api[ "GuildAltsScrollBarScrollUpButton" ]:Enable()
	end

	if value == max then
		m.api[ "GuildAltsScrollBarScrollDownButton" ]:Disable()
	else
		m.api[ "GuildAltsScrollBarScrollDownButton" ]:Enable()
	end
end

function GuildAlts.toggle_popup( show )
	if not m.popup then
		m.popup = GuildAlts.create_popup()
	end

	if show == false or (show == nil and m.popup:IsVisible()) then
		m.popup:Hide()
	elseif show == true or (show == nil and not m.popup:IsVisible()) then
		m.popup:Show()
		m.refresh( true )
	end
end

---@param character CharacterName
---@return CharacterName|nil
function GuildAlts.get_main( character )
	return m.alt_map[ character ]
end

---@param character AltMap
function GuildAlts.update_character( character )
	for main in pairs( character ) do
		if next( character[ main ] ) == nil then
			m.db.characters[ main ] = nil
		else
			m.db.characters[ main ] = character[ main ]
		end
		m.db.last_update = m.get_server_timestamp()
	end

	if m.popup and m.popup:IsVisible() then
		m.refresh( true )
	else
		m.build_alt_map()
	end
end

GuildAlts:init()
