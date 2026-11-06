---@class TitleRotator
TitleRotator = TitleRotator or {}

---@class TitleRotator
local m = TitleRotator

TitleRotator.name = "TitleRotator"
TitleRotator.tagcolor = "ff71d5ff"
TitleRotator.events = {}

function TitleRotator:init()
	self.frame = CreateFrame( "Frame" )
	self.frame:SetScript( "OnUpdate", m.on_update )
	self.frame:SetScript( "OnEvent", function()
		if m.events[ event ] then
			m.events[ event ]()
		end
	end )

	for k, _ in pairs( m.events ) do
		m.frame:RegisterEvent( k )
	end
end

function TitleRotator.events.PLAYER_LOGIN()
	-- Initialize DB
	TitleRotatorOptions = TitleRotatorOptions or {}
	m.db = TitleRotatorOptions
	m.db.enabled = m.db.enabled or false
	if m.db.raid_disable == nil then m.db.raid_disable = true end
	m.db.titles = m.db.titles or {}
	m.db.delay = m.db.delay or 2

	m.enabled = m.db.enabled
	m.frame_cache = {}
	m.api = getfenv()

	-- Create main button in character frame
	m.btn = CreateFrame( "Button", "TitleRotatorButton", PaperDollFrame, "UIPanelButtonTemplate" )
	m.btn:SetPoint( "Top", "CharacterLevelText", "Bottom", -68, -6 )
	m.btn:SetFrameLevel( PaperDollFrame:GetFrameLevel() + 2 )
	m.btn:SetWidth( 60 )
	m.btn:SetHeight( 18 )
	m.btn:SetTextFontObject( GameFontNormalSmall )
	m.btn:SetHighlightFontObject( GameFontNormalSmall )
	m.btn:SetText( "Rotator" )
	m.btn:SetScript( "OnClick", function() m.toggle() end )

	if next( m.db.titles ) == nil then
		m.btn:Disable()
	end

	-- Disable when paperdoll is open
	local orig_doll_show = m.api.PaperDollFrame:GetScript( "OnShow" )
	m.api.PaperDollFrame:SetScript( "OnShow", function()
		m.disable_rotate()
		-- Ensure PaperDollFrame always have the right active title
		SendAddonMessage("TW_TITLES", "Titles:List", "GUILD")
		if orig_doll_show then orig_doll_show()	end
	end )

	-- Enable when paperdoll is closed
	local orig_doll_hide = m.api.PaperDollFrame:GetScript( "OnHide" )
	m.api.PaperDollFrame:SetScript( "OnHide", function()
		if orig_doll_hide then orig_doll_hide()	end
		m.raid_check()
		m.hide()
	end )

	local version = GetAddOnMetadata( m.name, "Version" )
	m.info( string.format( "(v%s) Loaded", version ) )
end

function TitleRotator.events.CHAT_MSG_ADDON()
	if arg1 == "TWT_TITLES" then
		-- Receive new title notification from TW_Titles
		local _, _, titleID = string.find( arg2, "newTitle:(%d+)" )
		if titleID then
			table.insert( m.db.titles, {
				id = titleID,
				delay = 3
			} )

			m.btn:Enable()
		end

		-- Receive available titles from TW_Titles
		if next( m.db.titles ) == nil then
			if string.find( arg2, "TW_AVAILABLE_TITLES:", 1, true ) then
				local fEx = string.gsub( arg2, 'TW_AVAILABLE_TITLES:', "" )
				if fEx then
					local aEx = m.explode( fEx, ';' )

					for _, titleData in aEx do
						local _, _, id = string.find( titleData, '(%d+):(%d+)' )

						if id ~= '0' then
							table.insert( m.db.titles, {
								id = id,
								delay = 3
							} )
						end
					end
				end
			end
		end
	end
end

function TitleRotator.events.PLAYERS_ENTERING_WORLD()
	m.raid_check()
end

function TitleRotator.events.PARTY_MEMBERS_CHANGED()
	m.raid_check()
end

function TitleRotator.events.RAID_ROSTER_UPDATE()
	m.raid_check()
end

function TitleRotator.raid_check()
	if m.db.enabled and m.db.raid_disable then
		if GetNumRaidMembers() > 0 then
			m.disable_rotate()
			return
		end
	end

	m.enabled = m.db.enabled
end

function TitleRotator.disable_rotate()
	if getn( m.db.titles ) > 0 then
		m.current_title = 1
		m.set_title( m.db.titles[ m.current_title ].id )
	end
	m.enabled = false
end


---@param titleID integer
function TitleRotator.set_title( titleID )
	if m.enabled then
		SendAddonMessage( "TW_TITLES", "ChangeTitle:" .. titleID, "GUILD" )
	end
end

function TitleRotator.on_update()
	if m.enabled and m.db.titles and getn( m.db.titles ) > 1 then
		m.timeSinceLast = (m.timeSinceLast or 0) + arg1

		if m.timeSinceLast >= (m.db.titles[ m.current_title or 1 ].delay or 2) then
			m.timeSinceLast = 0
			m.current_title = (m.current_title or 0) + 1
			if m.current_title > getn( m.db.titles ) then
				m.current_title = 1
			end

			if m.db.titles[ m.current_title ].delay == 0 then
				m.current_title = m.current_title + 1
			end
			if m.current_title > getn( m.db.titles ) then
				m.current_title = 1
			end

			m.set_title( m.db.titles[ m.current_title ].id )
		end
	end
end

---@param index integer
---@return TitleButton
---@nodiscard
function TitleRotator.create_title_button( index )
	---@class TitleButton: Button
	local btn = m.get_from_cache( "button" )

	if not btn then
		---@class TitleButton: Button
		btn = CreateFrame( "Frame", nil, m.popup )
		btn:SetWidth( 190 )
		btn:SetHeight( 25 )
		btn:SetBackdrop( {
			bgFile = "Interface/Buttons/WHITE8x8",
			edgeFile = "Interface/Buttons/WHITE8x8",
			edgeSize = 0.8
		} )

		btn:SetBackdropColor( 0, 0, 0, 1 )
		btn:SetBackdropBorderColor( 0.5, 0.5, 0.5, 1 )

		btn.title = btn:CreateFontString( nil, "ARTWORK", "GameFontNormal" )
		btn.title:SetPoint( "Left", btn, "Left", 5, 0 )
		btn.title:SetWidth( 145 )
		btn.title:SetHeight( 22 )
		btn.title:SetJustifyH( "Left" )

		btn.btn_up = CreateFrame( "Button", nil, btn )
		btn.btn_up:SetWidth( 12 )
		btn.btn_up:SetHeight( 12 )
		btn.btn_up:SetPoint( "TopRight", btn, "TopRight", -1, -1 )
		btn.btn_up:SetNormalTexture( "Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up" )
		btn.btn_up:GetNormalTexture():SetTexCoord( 0.15, 0.85, 0.15, 0.85 )
		btn.btn_up:SetPushedTexture( "Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Down" )
		btn.btn_up:GetPushedTexture():SetTexCoord( 0.15, 0.85, 0.15, 0.85 )
		btn.btn_up:SetDisabledTexture( "Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Disabled" )
		btn.btn_up:GetDisabledTexture():SetTexCoord( 0.15, 0.85, 0.15, 0.85 )
		btn.btn_up:SetScript( "OnClick", function()
			local i = this:GetParent().index
			m.move_title( i, i - 1 )
			m.refresh()
		end )

		btn.btn_down = CreateFrame( "Button", nil, btn )
		btn.btn_down:SetWidth( 12 )
		btn.btn_down:SetHeight( 12 )
		btn.btn_down:SetPoint( "BottomRight", btn, "BottomRight", -1, 1 )
		btn.btn_down:SetNormalTexture( "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up" )
		btn.btn_down:GetNormalTexture():SetTexCoord( 0.15, 0.85, 0.15, 0.85 )
		btn.btn_down:SetPushedTexture( "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down" )
		btn.btn_down:GetPushedTexture():SetTexCoord( 0.15, 0.85, 0.15, 0.85 )
		btn.btn_down:SetDisabledTexture( "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Disabled" )
		btn.btn_down:GetDisabledTexture():SetTexCoord( 0.15, 0.85, 0.15, 0.85 )
		btn.btn_down:SetScript( "OnClick", function()
			local i = this:GetParent().index
			m.move_title( i, i + 1 )
			m.refresh()
		end )

		btn.input_delay = CreateFrame( "EditBox", nil, btn )
		btn.input_delay:SetWidth( 20 )
		btn.input_delay:SetHeight( 15 )
		btn.input_delay:SetPoint( "Right", btn, "Right", -20, 0 )
		btn.input_delay:SetAutoFocus( false )
		btn.input_delay:EnableKeyboard( true )
		btn.input_delay:SetFontObject( GameFontNormal )
		btn.input_delay:SetTextColor( 1, 1, 1, 1 )
		btn.input_delay:SetTextInsets( 2, 2, 0, 0 )
		btn.input_delay:SetMaxLetters( 2 )
		btn.input_delay:SetBackdrop( {
			bgFile = "Interface/Buttons/WHITE8x8",
			edgeFile = "Interface/Buttons/WHITE8x8",
			edgeSize = 1
		} )

		btn.input_delay:SetBackdropColor( 0, 0, 0, 1 )
		btn.input_delay:SetBackdropBorderColor( 0.6, 0.6, 0.6, 1 )

		btn.input_delay:SetScript( "OnEscapePressed", function()
			this:ClearFocus()
		end )

		btn.input_delay:SetScript( "OnEnterPressed", function()
			this:ClearFocus()
		end )

		btn.input_delay:SetScript( "OnEditFocusGained", function()
			this:HighlightText()
		end )

		btn.input_delay:SetScript( "OnTextChanged", function()
			local v = tonumber( this:GetText() )
			if this:GetText() ~= tostring( v ) then
				this:SetTextColor( 1, .3, .3, 1 )
			else
				this:SetTextColor( 1, 1, 1, 1 )
				if this:GetParent().index then
					m.db.titles[ this:GetParent().index ].delay = v
				end
			end
		end )

		table.insert( m.frame_cache[ "button" ], btn )
	end

	local title = m.db.titles[ index ]
	btn.is_used = true
	btn.index = index
	btn.title:SetText( m.api[ "PVP_MEDAL" .. title.id ] )
	btn.input_delay:SetText( tostring( title.delay or 3 ) )

	if index == 1 then
		btn.btn_up:Disable()
	else
		btn.btn_up:Enable()
	end

	if index == getn( m.db.titles ) then
		btn.btn_down:Disable()
	else
		btn.btn_down:Enable()
	end

	btn:Show()

	return btn
end

function TitleRotator.create_frame()
	---@class TitleRotatorFrame: Frame
	local frame = CreateFrame( "Frame", "TitleRotatorPopup", UIParent )
	frame:SetFrameStrata( "DIALOG" )
	frame:SetWidth( 200 )
	frame:SetHeight( 100 )
	frame:SetPoint( "TopLeft", "CharacterModelFrame", "TopLeft", 1, 1 )
	frame:SetBackdrop( { bgFile = "Interface/Buttons/WHITE8x8" } )
	frame:SetBackdropColor( 0, 0, 0, 0.8 )
	frame:EnableMouse( true )

	local cb_enabled = CreateFrame( "CheckButton", "TitleRotatorEnabled", frame, "UICheckButtonTemplate" )
	cb_enabled:SetPoint( "TopLeft", frame, "TopLeft", 5, -5 )
	cb_enabled:SetChecked( m.db.enabled )
	cb_enabled:SetHitRectInsets( 0, -50, 0, 0 )
	cb_enabled:SetScale( 0.8 )

	local cb_enabled_label = frame:CreateFontString( nil, "OVERLAY", "GameFontNormal" )
	cb_enabled_label:SetPoint( "Left", cb_enabled, "Right", 0, 0 )
	cb_enabled_label:SetText( "Enable" )

	local cb_raid = CreateFrame( "CheckButton", "TitleRotatorRaidDisable", frame, "UICheckButtonTemplate" )
	cb_raid:SetPoint( "Left", cb_enabled_label, "Right", 10, 0 )
	cb_raid:SetChecked( m.db.raid_disable )
	cb_raid:SetHitRectInsets( 0, -113, 0, 0 )
	cb_raid:SetScale( 0.8 )

	local cb_raid_label = frame:CreateFontString( nil, "OVERLAY", "GameFontNormal" )
	cb_raid_label:SetPoint( "Left", cb_raid, "Right", 0, 0 )
	cb_raid_label:SetText( "Disable in raids" )

	cb_enabled:SetScript( "OnClick", function()
		m.db.enabled = cb_enabled:GetChecked() and true or false

		if m.db.enabled then
			cb_raid:Enable()
		else
			cb_raid:Disable()
		end
	end )

	cb_raid:SetScript( "OnClick", function()
		m.db.raid_disable = cb_raid:GetChecked() and true or false
		m.raid_check()
	end )

	if not m.db.enabled then
		cb_raid:Disable()
	end

	return frame
end

function TitleRotator.refresh()
	if not m.popup or not m.popup:IsVisible() then
		return
	end

	-- Reset cached elements
	for _, type in m.frame_cache do
		for _, frame in type do
			frame.is_used = false
			frame:Hide()
		end
	end

	for i in ipairs( m.db.titles ) do
		local btn = m.create_title_button( i )
		btn:SetPoint( "TopLeft", m.popup, "TopLeft", 5, -35 - ((i - 1) * 27) )
	end

	m.popup:SetHeight( 40 + getn( m.db.titles ) * 27 )
end

function TitleRotator.show()
	if not m.popup then
		m.popup = m.create_frame()
	end
	m.popup:Show()
	m.refresh()
end

function TitleRotator.hide()
	if m.popup then
		m.popup:Hide()
	end
end

function TitleRotator.toggle()
	if m.popup and m.popup:IsVisible() then
		m.hide()
	else
		m.show()
	end
end

---@param message string
---@param short boolean?
function TitleRotator.info( message, short )
	local tag = string.format( "|c%s%s|r", m.tagcolor, short and "TR" or "TitleRotator" )
	DEFAULT_CHAT_FRAME:AddMessage( string.format( "%s: %s", tag, message ) )
end

---@param frame_type string
---@return Frame?
---@nodiscard
function TitleRotator.get_from_cache( frame_type )
	m.frame_cache[ frame_type ] = m.frame_cache[ frame_type ] or {}

	for i = getn( m.frame_cache[ frame_type ] ), 1, -1 do
		if not m.frame_cache[ frame_type ][ i ].is_used then
			return m.frame_cache[ frame_type ][ i ]
		end
	end

	return nil
end

---@param i1 integer
---@param i2 integer
function TitleRotator.move_title( i1, i2 )
	local n = getn( m.db.titles )
	local val = m.db.titles[ i1 ]

	if i1 == i2 or i1 < 1 or i1 > n or i2 < 1 or i2 > n then
		return
	end

	if i1 < i2 then
		for i = i1, i2 - 1 do
			m.db.titles[ i ] = m.db.titles[ i + 1 ]
		end
	else
		for i = i1, i2 + 1, -1 do
			m.db.titles[ i ] = m.db.titles[ i - 1 ]
		end
	end

	m.db.titles[ i2 ] = val
end

---@param str string
---@param delimiter string
---@return table
---@nodiscard
function TitleRotator.explode( str, delimiter )
	local result = {}
	local from = 1
	local delim_from, delim_to = string.find( str, delimiter, from, true )
	while delim_from do
		table.insert( result, string.sub( str, from, delim_from - 1 ) )
		from = delim_to + 1
		delim_from, delim_to = string.find( str, delimiter, from, true )
	end
	table.insert( result, string.sub( str, from ) )
	return result
end

TitleRotator:init()

-- Stop TitlesDropDown_Initialize from being run each time title changes
local orig_PaperDollFrame_OnEvent = PaperDollFrame_OnEvent
local first_run = true
function PaperDollFrame_OnEvent( event, unit )
	if (event == "CHAT_MSG_ADDON" and arg1 == "TWT_TITLES") then
		if not m.api.PaperDollFrame:IsVisible() and m.enabled then
			local _, _, titleID = string.find( arg2, "newTitle:(%d+)" )

			-- Make sure dropdown data gets populated on first response
			-- Make sure original event is run on new titles
			if first_run or titleID then
				first_run = false
			else
				arg1 = ""
			end
		end
	end

	if orig_PaperDollFrame_OnEvent then
		orig_PaperDollFrame_OnEvent( event, unit )
	end
end
