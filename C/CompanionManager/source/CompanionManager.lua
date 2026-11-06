---@class CompanionManager
CompanionManager = CompanionManager or {}

---@class CompanionManager
local m = CompanionManager

---@class Companion
---@field id number
---@field icon string?
---@field name string
---@field category string

BINDING_HEADER_CM_HEADER = "Companion Manager"
BINDING_NAME_CM_OPENMENU = "Toggle menu"
CM_COMPANIONS_SPELLTAB = "Companions"
CM_TOYS_SPELLTAB = "Toys"

CompanionManager.name = "CompanionManager"
CompanionManager.events = {}
CompanionManager.categories = {
	Cats = { "Black Tabby", "Bombay", "Cornish Rex", "Corrupted Kitten", "Midnight", "Mr. Bigglesworth", "Orange Tabby", "Siamese", "Silver Tabby", "White Kitten", "White Tiger Cub" },
	Frogs = { "A Jubling's Tiny Home", "Azure Frog", "Bullfrog", "Dart Frog", "Dream Frog", "Golden Frog", "Infinite Frog", "Island Frog", "Pink Frog", "Poison Frog", "Pond Frog", "Snow Frog", "Tree Frog", "Wood Frog" },
	Flying = { "Amani Eagle", "Azure Whelpling", "Azure Wind Serpent", "Beaky", "Bronze Whelpling", "Cockatiel", "Dark Wind Serpent", "Dragonhawk Hatchling", "Emerald Wind Serpent", "Gilnean Raven", "Glitterwing", "Green Wing Macaw", "Hawk Owl", "Hippogryph Hatchling", "Phoenix Hatchling", "Senegal", "Snowy Owl", "Spectral Faeling", "Sprite Darter Hatchling", "Tangerine Wind Serpent" },
	Turtles = { "Albino Snapjaw", "Hawksbill Snapjaw", "Leatherback Snapjaw", "Loggerhead Snapjaw", "Olive Snapjaw", "Speedy" },
	Animals = { "Albino Snake", "Ancona", "Baby Moonwhisper Elekk", "Billy", "Black Kingsnake", "Black Piglet", "Crimson Snake", "Farm Chicken", "Fox Kit", "Grumbles", "Little Fawn", "Lost Farm Sheep", "Lulu", "Mr. Wiggles", "Panda Collar", "Pengu", "Poley", "Rufflebeak", "Scarlet Snake", "Snowshoe Rabbit", "Swiftstar", "Wally", "Worg Pup", "Wyvern Roost Hatchling" },
	Mechanical = { "Darkmoon Tonk", "Green Steam Tonk", "Mechanical Chicken", "Purple Steam Tonk" },
	Seasonal = { "Blitzen", "Father Winter's Helper", "Jingling Bell", "Green Helper Box", "Hedwig", "Mini Krampus", "Red Helper Box", "Tiny Snowman", "Winter Reindeer" },
	Hatchlings = { "Araxxna's Hatchling", "Black Widow Hatchling", "Cavernweb Hatchling", "Darkmist Hatchling", "Lava Hatchling", "Maexxna's Hatchling", "Mistbark Hatchling", "Night Web Hatchling", "Razzashi Hatchling", "Skitterweb Hatchling", "Smolderweb Hatchling", "Tarantula Hatchling", "Timberweb Hatchling", "Webwood Hatchling", "Wildthorn Hatchling" },
	Bots = { "Caravan Kodo", "Field Repair Bot 75B", "Forworn Mule", "Mechanical Auctioneer", "Summon: Auctioneer", "Summon: Barber", "Summon: Surgeon" },
	Illusions = {},
	Toys = {},
}

CompanionManager.category_default_order = {
	"Cats",
	"Frogs",
	"Hatchlings",
	"Turtles",
	"Flying",
	"Animals",
	"Seasonal",
	"Mechanical",
	"Other",
	"Bots",
	"Toys",
	"Illusions"
}

CompanionManager.category_icons = {
	Cats = "Interface\\Icons\\inv_pet_cats_cornishrexcat",
	Frogs = "Interface\\Icons\\Spell_Shaman_Hex",
	Hatchlings = "Interface\\Icons\\Ability_Hunter_Pet_Spider",
	Flying = "Interface\\Icons\\INV_Feather_03",
	Turtles = "Interface\\Icons\\Ability_Hunter_Pet_Turtle",
	Animals = "Interface\\Icons\\Spell_Magic_PolymorphChicken",
	Mechanical = "Interface\\Icons\\INV_Gizmo_02",
	Seasonal = "Interface\\Icons\\inv_pet_snowman",
	Bots = "Interface\\Icons\\INV_Egg_05",
	Other = "Interface\\Icons\\INV_Box_PetCarrier_01",
	Toys = "Interface\\Icons\\inv_misc_toy_10",
	Illusions = "Interface\\Icons\\Ability_Rogue_Disguise"
}

function CompanionManager:init()
	self.radius = 1.5625
	self.frame_cache = {}
	---@type Companion[]
	self.companions = {}

	self.frame = CreateFrame( "Frame" )
	self.frame:SetScript( "OnEvent", function()
		if m.events[ event ] then
			m.events[ event ]()
		end
	end )

	for k, _ in pairs( m.events ) do
		m.frame:RegisterEvent( k )
	end
end

function CompanionManager.events.PLAYER_LOGIN()
	m.spells_changed = true

	m.slash_command = m.SlashCommand.new( m.name, "cm" )
	m.slash_command.init()

	CompanionManagerOptions = CompanionManagerOptions or {}
	m.db = CompanionManagerOptions
	m.db.icon_size = m.db.icon_size or 32
	if m.db.verbose == nil then m.db.verbose = true end
	if m.db.show_toys == nil then m.db.show_toys = false end
	m.db.companion_order = m.db.companion_order or {}
	m.db.category_angle = m.db.category_angle or 0
	m.db.category_order = m.db.category_order or m.category_default_order

	for _, v in m.db.companion_order do
		if v[ 1 ] and type( v[ 1 ] ) == "number" then
			m.db.companion_order = {}
			m.info( "Companion sort order has been reset (required by new version)." )
			break
		end
	end

	local version = GetAddOnMetadata( m.name, "Version" )
	m.info( string.format( "Loaded (|cffeda55fv%s|r).", version ), true )
end

function CompanionManager.events.SPELLS_CHANGED()
	m.spells_changed = true
end

function CompanionManager.create_frame()
	local frame = CreateFrame( "Frame", "CompanionManagerMainFrame" )
	frame:SetWidth( 200 )
	frame:SetHeight( 200 )

	---@class TooltipFrame: Frame
	m.tooltip = CreateFrame( "Frame", nil, frame )
	m.tooltip:SetFrameStrata( "TOOLTIP" )
	m.tooltip:SetBackdrop( {
		bgFile = "Interface\\Addons\\CompanionManager\\assets\\Companion-Tooltip",
		tile = false,
	} )
	m.tooltip:SetBackdropColor( 0, 0, 0, 0.8 )
	m.tooltip:SetWidth( 64 )
	m.tooltip:SetHeight( 64 )
	m.tooltip:SetPoint( "Center", frame, "Center", 0, 0 )
	m.tooltip.label = m.tooltip:CreateFontString( nil, "ARTWORK", "GameFontNormalSmall" )
	m.tooltip.label:SetPoint( "Center", frame, "Center", 0, 0 )
	m.tooltip:Hide()

	---@class DragFrame: Frame
	m.drag_frame = CreateFrame( "Frame", nil, UIParent )
	m.drag_frame:SetWidth( 32 )
	m.drag_frame:SetHeight( 32 )
	m.drag_frame:SetFrameStrata( "TOOLTIP" )
	m.drag_frame:Hide()
	m.drag_frame:SetScript( "OnUpdate", m.drag_frame_update )
	m.drag_frame.icon = m.drag_frame:CreateTexture( nil, "OVERLAY" )
	m.drag_frame.icon:SetAllPoints()

	---@class CompanionButton: Button
	m.center_button = m.button_category_create( frame, "Interface\\Buttons\\UI-GroupLoot-Dice-Up", "Random" )
	m.center_button:SetPoint( "Center", frame, "Center", 0, 0 )
	m.center_button:RegisterForDrag( "LeftButton" )
	m.center_button.is_center = true

	m.center_button:SetScript( "OnDragStart", function()
		local _, y = GetCursorPosition()
		m.rotate_start = y
		m.rotate_start_angle = m.db.category_angle
		this:SetScript( "OnUpdate", m.center_button_update )
	end )
	m.center_button:SetScript( "OnDragStop", function()
		this:SetScript( "OnUpdate", nil )
	end )

	return frame
end

---@param parent Frame
---@param type string
---@return Button
function CompanionManager.create_button( parent, type )
	---@type CompanionButton
	local button = m.get_from_cache( type )

	if button then
		button.is_used = true
		button:Show()
		return button
	end

	---@class CompanionButton: Button
	button = CreateFrame( "Button", nil, parent )
	button:SetWidth( m.db.icon_size )
	button:SetHeight( m.db.icon_size )
	button:RegisterForDrag( "LeftButton" )

	local frame_tex = button:CreateTexture( nil, "ARTWORK" )
	frame_tex:SetTexture( "Interface\\Addons\\CompanionManager\\assets\\Companion-Button.tga" )
	frame_tex:SetAllPoints( button )

	local bg_tex = button:CreateTexture( nil, "BACKGROUND" )
	bg_tex:SetTexture( "Interface\\CharacterFrame\\TempPortraitAlphaMaskSmall" )
	bg_tex:SetPoint( "TopLeft", button, "TopLeft", m.db.icon_size / 10.666, -m.db.icon_size / 10.666 )
	bg_tex:SetPoint( "BottomRight", button, "BottomRight", -m.db.icon_size / 10.6666, m.db.icon_size / 10.666 )
	bg_tex:SetVertexColor( 0, 0, 0, 1 )
	button.bg_tex = bg_tex

	local center = button:CreateTexture( nil, "BORDER" )
	center:SetTexCoord( 0.15, 0.85, 0.15, 0.85 )
	center:SetWidth( m.db.icon_size * 0.656 )
	center:SetHeight( m.db.icon_size * 0.656 )
	center:SetPoint( "Center", button, "Center", 0, 0 )
	button.center = center

	local top = button:CreateTexture( nil, "BORDER" )
	top:SetTexCoord( 0.3, 0.7, 0.1, 0.15 )
	top:SetWidth( m.db.icon_size * 0.4 )
	top:SetHeight( m.db.icon_size / 12.8 )
	top:SetPoint( "Bottom", center, "Top" )
	button.top = top

	local bottom = button:CreateTexture( nil, "BORDER" )
	bottom:SetTexCoord( 0.3, 0.7, 0.85, 0.9 )
	bottom:SetWidth( m.db.icon_size * 0.4 )
	bottom:SetHeight( m.db.icon_size / 12.8 )
	bottom:SetPoint( "Top", center, "Bottom" )
	button.bottom = bottom

	local left = button:CreateTexture( nil, "BORDER" )
	left:SetTexCoord( 0.1, 0.15, 0.3, 0.7 )
	left:SetWidth( m.db.icon_size / 12.8 )
	left:SetHeight( m.db.icon_size * 0.4 )
	left:SetPoint( "Right", center, "Left" )
	button.left = left

	local right = button:CreateTexture( nil, "BORDER" )
	right:SetTexCoord( 0.85, 0.9, 0.3, 0.7 )
	right:SetWidth( m.db.icon_size / 12.8 )
	right:SetHeight( m.db.icon_size * 0.4 )
	right:SetPoint( "Left", center, "Right" )
	button.right = right

	local hover_tex = button:CreateTexture( nil, "ARTWORK" )
	hover_tex:SetTexture( "Interface\\Addons\\CompanionManager\\assets\\Companion-Button-Glow.tga" )
	hover_tex:SetPoint( "TopLeft", button, "TopLeft", m.db.icon_size / 15, -m.db.icon_size / 15 )
	hover_tex:SetPoint( "BottomRight", button, "BottomRight", -m.db.icon_size / 15, m.db.icon_size / 15 )
	hover_tex:SetBlendMode( "ADD" )
	hover_tex:SetVertexColor( 1, 1, 0, 0 )
	button.hover_tex = hover_tex

	local text = button:CreateFontString( nil, "OVERLAY", "NumberFontNormal" )
	text:SetPoint( "Center", button, "Center", 0, 0 )
	button.text = text

	button.set_icon = function( button_icon )
		button.icon = button_icon
		center:SetTexture( button_icon )
		top:SetTexture( button_icon )
		bottom:SetTexture( button_icon )
		left:SetTexture( button_icon )
		right:SetTexture( button_icon )
	end

	button:RegisterForClicks( "LeftButtonUp", "MiddleButtonUp" )
	button:SetScript( "OnDragStart", m.button_drag_start )
	button:SetScript( "OnDragStop", m.button_drag_stop )

	button:SetScript( "OnEnter", function()
		hover_tex:SetVertexColor( 1, 1, 0, 1 )
	end )

	button:SetScript( "OnLeave", function()
		hover_tex:SetVertexColor( 1, 1, 0, 0 )
		GameTooltip:Hide()
		m.tooltip:Hide()
	end )

	button.is_used = true
	table.insert( m.frame_cache[ type ], button )

	return button
end

---@param parent Frame
---@param icon string
---@param category string
function CompanionManager.button_category_create( parent, icon, category )
	---@class CompanionButton
	local button = m.create_button( parent, "category_button" )
	button.on_enter = button:GetScript( "OnEnter" )

	button.set_icon( icon )
	button.category = category

	button:SetScript( "OnEnter", function()
		button.on_enter()
		m.hide_companions()

		if m.is_dragging or category == "Random" then return end

		local _, _, _, x, y = button:GetPoint()
		local angle = math.atan2( y - 100, x - 100 )

		m.show_companions( angle, category )
		m.tooltip.label:SetText( category )
		m.tooltip:Show()
	end )

	button:SetScript( "OnClick", m.button_category_on_click )

	return button
end

---@param parent Frame
---@param companion Companion
function CompanionManager.button_companion_create( parent, companion )
	---@class CompanionButton
	local button = m.create_button( parent, "companion_button" )
	button.set_icon( companion.icon )
	button.category = companion.category
	button.name = companion.name
	button.id = companion.id
	button:Hide()

	local on_enter = button:GetScript( "OnEnter" )
	button:SetScript( "OnEnter", function()
		if on_enter then on_enter() end
		if m.is_dragging then return end

		GameTooltip:SetOwner( this, "ANCHOR_RIGHT" )
		if (GameTooltip:SetSpell( companion.id, BOOKTYPE_SPELL )) then
			GameTooltip:Show()
		end
	end )

	button:SetScript( "OnClick", function()
		if arg1 == "LeftButton" then
			m.summon_companion( companion )
			m.hide()
		else
			m.hide()
		end
	end )

	button:SetScript( "OnShow", function()
		local start, duration = GetSpellCooldown( companion.id, BOOKTYPE_SPELL )
		if duration > 0 then
			button:SetScript( "OnUpdate", m.button_update )
			local remaining = start + duration - GetTime()
			this.text:SetText( m.format_sec_to_min( math.ceil( remaining ) ) )
		else
			this.text:SetText( "" )
			button:SetScript( "OnUpdate", nil )
		end
	end )

	button:Show()

	return button
end

function CompanionManager.button_update()
	this.elapsed_since_update = this.elapsed_since_update and this.elapsed_since_update + arg1 or arg1

	if this.elapsed_since_update >= 1 then
		this.elapsed_since_update = 0
		local start, duration = GetSpellCooldown( this.id, BOOKTYPE_SPELL )
		if duration > 0 then
			local remaining = start + duration - GetTime()
			this.text:SetText( m.format_sec_to_min( math.ceil( remaining ) ) )
		else
			this:SetScript( "OnUpdate", nil )
			this.text:SetText( "" )
		end
	end
end

function CompanionManager.button_drag_start()
	m.is_dragging = true
	m.drag_frame.icon:SetTexture( this.icon )
	m.drag_frame:Show()
end

function CompanionManager.button_drag_stop()
	m.is_dragging = false
	m.drag_frame:Hide()

	---@class CompanionButton
	local focus = GetMouseFocus()
	if this.category and focus.category then
		m.swap_category( this.category, focus.category )
		m.update_size( m.db.icon_size, true )
	end

	if this.id and focus.id then
		m.swap_companion(
			{ id = this.id, name = this.name, category = this.category },
			{ id = focus.id, name = focus.name, category = focus.category }
		)
		m.hide_companions()
		m.show_companions( m.current_angle, this.category )
	end
end

function CompanionManager.drag_frame_update()
	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	this:SetPoint( "Center", UIParent, "BottomLeft", x / scale, y / scale )
end

function CompanionManager.center_button_update()
	local _, y = GetCursorPosition()
	m.db.category_angle = m.rotate_start_angle + (m.rotate_start - y) / 50

	m.update_size( m.db.icon_size, true )
	m.show_categories()
end

---@param category1 string
---@param category2 string
function CompanionManager.swap_category( category1, category2 )
	for i, category in ipairs( m.db.category_order ) do
		if category == category1 then
			m.db.category_order[ i ] = category2
		elseif category == category2 then
			m.db.category_order[ i ] = category1
		end
	end
end

---@param companion1 Companion
---@param companion2 Companion
function CompanionManager.swap_companion( companion1, companion2 )
	local category = companion1.category

	for i, name in ipairs( m.db.companion_order[ category ] ) do
		if name == companion1.name then
			m.db.companion_order[ category ][ i ] = companion2.name
		elseif name == companion2.name then
			m.db.companion_order[ category ][ i ] = companion1.name
		end
	end
end

function CompanionManager.show_categories()
	local centerX, centerY = m.popup:GetWidth() / 2, m.popup:GetHeight() / 2
	local icon_count = 0

	for _ in pairs( m.companions ) do
		icon_count = icon_count + 1
	end

	m.radius = math.max( icon_count * 0.17, 1.5 )

	local radius = m.db.icon_size * m.radius
	local i = 0
	for _, category in ipairs( m.db.category_order ) do
		local icon = m.category_icons[ category ]
		local angle = (i / icon_count) * (2 * math.pi)
		angle = angle + m.db.category_angle
		local x = centerX + radius * math.cos( angle )
		local y = centerY + radius * math.sin( angle )

		if m.companions[ category ] then
			local b = m.button_category_create( m.popup, icon, category )
			b:SetPoint( "Center", m.popup, "BottomLeft", x, y )
			i = i + 1
		end
	end
end

---@param angle number
---@param category string
function CompanionManager.show_companions( angle, category )
	local radius = m.db.icon_size * m.radius * 1.78
	local count = getn( m.companions[ category ] )
	local spread = 36 / (32 * m.radius * 1.72)
	local px, py = 100, 100

	radius = math.min( radius, 120 )
	m.visible_category = category
	m.current_angle = angle

	local function find( t, name )
		for i, companion in ipairs( t ) do
			if type( companion ) == "string" and companion == name then return i end
			if type( companion ) == "table" and companion.name == name then return i end
		end
		return nil
	end

	m.db.companion_order[ category ] = m.db.companion_order[ category ] or {}
	if count ~= getn( m.db.companion_order[ category ] ) then
		for _, companion in ipairs( m.companions[ category ] ) do
			if not find( m.db.companion_order[ category ], companion.name ) then
				table.insert( m.db.companion_order[ category ], companion.name )
			end
		end
	end

	local i = (-count / 2)
	local c = count
	for k, name in pairs( m.db.companion_order[ category ] ) do
		local index = find( m.companions[ category ], name )
		local companion = m.companions[ category ][ index ]

		if companion then
			companion.category = category
			if k > 15 then
				radius = m.db.icon_size * m.radius * 2.6
				spread = 36 / (32 * m.radius * 2.6)
				i = (-c / 2)
			end
			local offsetAngle = angle + ((i + 0.5) * spread)
			local x = px + radius * math.cos( offsetAngle )
			local y = py + radius * math.sin( offsetAngle )

			local button = m.button_companion_create( m.popup, companion )
			button:SetPoint( "Center", m.popup, "BottomLeft", x, y )
			i = i + 1
			c = c - 1
		end
	end
end

function CompanionManager.hide_companions()
	m.drag_frame:Hide()
	m.is_dragging = false
	m.visible_category = nil

	if m.frame_cache[ "companion_button" ] then
		for i = 1, getn( m.frame_cache[ "companion_button" ] ) do
			local b = m.frame_cache[ "companion_button" ][ i ]
			b.is_used = false
			b:Hide()
		end
	end
end

function CompanionManager.button_category_on_click()
	if arg1 == "LeftButton" then
		if this.category == "Random" then
			m.summon_random_companion()
		else
			if m.visible_category == this.category then
				m.hide_companions()
			else
				local _, _, _, x, y = this:GetPoint()
				local angle = math.atan2( y - 100, x - 100 )
				m.show_companions( angle, this.category )
			end
		end
	else
		m.hide()
	end
end

---@param companion Companion
function CompanionManager.summon_companion( companion )
	CastSpell( companion.id, BOOKTYPE_SPELL )
	if m.db.verbose then
		m.info( "Summoning " .. m.make_link( companion.name, companion.id ) )
	end
end

function CompanionManager.summon_random_companion()
	local count = 0

	for category, companions in pairs( m.companions ) do
		if category ~= "Toys" and category ~= "Illusions" then
			for _, _ in pairs( companions ) do
				count = count + 1
			end
		end
	end

	local random = math.random( count )
	count = 0

	for category, companions in pairs( m.companions ) do
		if category ~= "Toys" and category ~= "Illusions" then
			for _, companion in pairs( companions ) do
				count = count + 1
				if count == random then
					m.summon_companion( companion )
					break
				end
			end
		end
	end

	m.hide()
end

---@param seconds integer
function CompanionManager.format_sec_to_min( seconds )
	if seconds < 100 then
		return string.format( "%d", seconds - 1 )
	else
		local mins = math.floor( (seconds + 28) / 60 )
		return string.format( "|cff71d5ff%d|rM", mins )
	end
end

---@param name string
---@param id number
function CompanionManager.make_link( name, id )
	return string.format( "|cff71d5ff|Hspell:%d:0:%s:|h[%s]|h|r", id, UnitName( "player" ), name )
end

function CompanionManager.get_from_cache( type )
	m.frame_cache[ type ] = m.frame_cache[ type ] or {}

	for i = getn( m.frame_cache[ type ] ), 1, -1 do
		if not m.frame_cache[ type ][ i ].is_used then
			return m.frame_cache[ type ][ i ]
		end
	end
end

---@param name string
function CompanionManager.find_category( name )
	for category, names in pairs( m.categories ) do
		for _, n in ipairs( names ) do
			if n == name then
				return category
			end
		end
	end
	return nil
end

function CompanionManager.get_toys()
	local MAX_SKILLLINE_TABS = 8
	if not m.toys_tab then
		for i = 1, MAX_SKILLLINE_TABS do
			local tab_name = GetSpellTabInfo( i )
			if tab_name == CM_TOYS_SPELLTAB then
				m.toys_tab = i
				break
			end
		end
	end

	if not m.toys_tab then
		m.info( "|cffff0000ERROR|r: No toys found!" )
		return false
	end

	local _, _, offset, count = GetSpellTabInfo( m.toys_tab )
	for i = offset + 1, offset + count do
		local name = GetSpellName( i, BOOKTYPE_SPELL )
		local texture = GetSpellTexture( i, BOOKTYPE_SPELL )
		local category = "Toys"

		if name and string.find( name, "^Illusion: " ) then
			category = "Illusions"
		end

		if category and not m.companions[ category ] then
			m.companions[ category ] = {}
		end

		table.insert( m.companions[ category ], {
			id = i,
			name = name,
			icon = texture
		} )
	end

	return true
end

function CompanionManager.get_companions()
	local MAX_SKILLLINE_TABS = 8
	if not m.companion_tab then
		for i = 1, MAX_SKILLLINE_TABS do
			local tab_name = GetSpellTabInfo( i )
			if tab_name == CM_COMPANIONS_SPELLTAB then
				m.companion_tab = i
				break
			end
		end
	end

	if not m.companion_tab then
		m.info( "|cffff0000ERROR|r: No companions found!" )
		return false
	end

	local _, _, offset, count = GetSpellTabInfo( m.companion_tab )

	---@type table<string, Companion[]>
	m.companions = {}
	for i = offset + 1, offset + count do
		local name = GetSpellName( i, BOOKTYPE_SPELL )
		local texture = GetSpellTexture( i, BOOKTYPE_SPELL )
		local category = name and m.find_category( name ) or "Other"

		if category and not m.companions[ category ] then
			m.companions[ category ] = {}
		end

		table.insert( m.companions[ category ], {
			id = i,
			name = name,
			icon = texture
		} )
	end

	return true
end

---@param size number
---@param rotating boolean?
function CompanionManager.update_size( size, rotating )
	local is_visible = false
	m.spells_changed = true
	m.db.icon_size = size and size or m.db.icon_size

	if not m.popup then return end

	if not rotating and m.popup:IsVisible() then
		is_visible = true
		m.hide_companions()
		m.hide()
	end

	local function set_size( b )
		b:SetWidth( m.db.icon_size )
		b:SetHeight( m.db.icon_size )

		b.bg_tex:SetPoint( "TopLeft", m.db.icon_size / 10.666, -m.db.icon_size / 10.666 )
		b.bg_tex:SetPoint( "BottomRight", -m.db.icon_size / 10.6666, m.db.icon_size / 10.666 )
		b.center:SetWidth( m.db.icon_size * 0.656 )
		b.center:SetHeight( m.db.icon_size * 0.656 )
		b.top:SetWidth( m.db.icon_size * 0.4 )
		b.top:SetHeight( m.db.icon_size / 12.8 )
		b.bottom:SetWidth( m.db.icon_size * 0.4 )
		b.bottom:SetHeight( m.db.icon_size / 12.8 )
		b.left:SetWidth( m.db.icon_size / 12.8 )
		b.left:SetHeight( m.db.icon_size * 0.4 )
		b.right:SetWidth( m.db.icon_size / 12.8 )
		b.right:SetHeight( m.db.icon_size * 0.4 )
		b.hover_tex:SetPoint( "TopLeft", m.db.icon_size / 14, -m.db.icon_size / 14 )
		b.hover_tex:SetPoint( "BottomRight", -m.db.icon_size / 14, m.db.icon_size / 14 )
	end

	if m.frame_cache[ "category_button" ] then
		for i = 1, getn( m.frame_cache[ "category_button" ] ) do
			local b = m.frame_cache[ "category_button" ][ i ]
			set_size( b )
			if not b.is_center then
				b.is_used = false
				b:SetScript( "OnEnter", b.on_enter )
				b:Hide()
			end
		end
	end

	if m.frame_cache[ "companion_button" ] then
		for i = 1, getn( m.frame_cache[ "companion_button" ] ) do
			local button = m.frame_cache[ "companion_button" ][ i ]
			set_size( button )
		end
	end

	if not rotating and is_visible then
		m.show( true )
	elseif rotating then
		m.show_categories()
	end
end

---@param refresh boolean?
function CompanionManager.show( refresh )
	local x, y = GetCursorPosition()

	if not m.popup then
		m.popup = m.create_frame()
	end

	if m.spells_changed then
		local got_companions = m.get_companions()
		local got_toys = false
		if m.db.show_toys then
			got_toys = m.get_toys()
		end

		if got_companions or got_toys then
			m.spells_changed = false
		else
			return
		end

		m.show_categories()
	end

	if not refresh then
		m.popup:ClearAllPoints()
		m.popup:SetPoint( "Center", UIParent, "BottomLeft", (x), (y) )
	end
	m.hide_companions()
	m.popup:Show()
end

function CompanionManager.hide()
	if m.popup then
		m.popup:Hide()
	end
end

function CompanionManager.toggle()
	if m.popup and m.popup:IsVisible() then
		m.hide()
	else
		m.show()
	end
end

---@param message string
---@param long boolean?
function CompanionManager.info( message, long )
	local tag = long and "|cff71d5ffCompanion|cff209ff9Manager|r" or "|cff71d5ffC|cff209ff9M|r"
	DEFAULT_CHAT_FRAME:AddMessage( string.format( "%s: %s", tag, message ) )
end

CompanionManager:init()
