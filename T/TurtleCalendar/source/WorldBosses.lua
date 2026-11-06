TurtleCalendar = TurtleCalendar or {}

---@class TurtleCalendar
local m = TurtleCalendar
local getn = table.getn

if m.WorldBosses then return end

---@class WorldBosses
local M = {}

-- Turtle WoW world boss lockout duration: flat 7 days (604,800 seconds).
M.LOCKOUT = 7 * 86400

M.bosses = {
	{ key = "azuregos", name = "Azuregos", aliases = { "azuregos" } },
	{ key = "kazzak", name = "Lord Kazzak", aliases = { "lord kazzak", "kazzak" } },
	{ key = "emeriss", name = "Emeriss", aliases = { "emeriss" } },
	{ key = "lethon", name = "Lethon", aliases = { "lethon" } },
	{ key = "taerar", name = "Taerar", aliases = { "taerar" } },
	{ key = "ysondre", name = "Ysondre", aliases = { "ysondre" } },
	{ key = "nerubian", name = "Nerubian Overseer", aliases = { "nerubian overseer" } },
	{ key = "reaver", name = "Dark Reaver", aliases = { "dark reaver of karazhan", "dark reaver" } },
	{ key = "ostarius", name = "Ostarius", aliases = { "ostarius" } },
	{ key = "concavius", name = "Concavius", aliases = { "concavius" } },
	{ key = "cowking", name = "Cow King", aliases = { "cow king" } },
}

local C_RED = { 0.77, 0.12, 0.23 }
local C_GREEN = { 0, 1, 0.6 }
local EMPTY = {}

local ADDON_PREFIX = "TurtleCalendar"
local ID_LEN = 6
local ID_CHARSET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
local ID_WINDOW = 180
local WHO_TIMEOUT = 5

-- Single module state table to consume only 1 closure upvalue in Lua 5.0
local D = {
	share_queue = {},
	last_send = 0,
	pending_key = nil,
	pending_name = nil,
	confirming = false,
	box = nil,
	last_sig = "",
	who_pending = nil,
	event_frame = nil,
	random_seeded = false,
}

-- Format a duration as a compact countdown string (2d4h / 4h12m / 12m5s / 9s).
local function dhms( seconds )
	if seconds < 0 then seconds = 0 end
	local d, h, min, s = m.seconds_dhms( seconds )
	if d > 0 then
		return string.format( m.T[ "%dd%dh" ], d, h )
	elseif h > 0 then
		return string.format( m.T[ "%dh%dm" ], h, min )
	elseif min > 0 then
		return string.format( m.T[ "%dm%ds" ], min, s )
	end
	return string.format( m.T[ "%ds" ], s )
end

-- Check whether msg contains word as a distinct word (ASCII letter boundaries).
local function has_word( msg, word )
	local i = 1
	local msg_len = string.len( msg )
	while i <= msg_len do
		local s, e = string.find( msg, word, i, true )
		if not s then return false end
		local before = s > 1 and string.sub( msg, s - 1, s - 1 ) or ""
		local after = e < msg_len and string.sub( msg, e + 1, e + 1 ) or ""
		if not string.find( before, "%a" ) and not string.find( after, "%a" ) then
			return true
		end
		i = s + 1
	end
	return false
end

-- Match a combat death message or search query against the world boss roster.
-- Defensively ignores boss adds, shades, images, and minions.
local function find_boss( msg )
	if not msg then return nil end
	local lowered = string.lower( msg )

	-- Ignore adds, phantoms, shades, spirits, images, minions, or spawns
	if string.find( lowered, "shade" ) or string.find( lowered, "spirit" )
		or string.find( lowered, "phantom" ) or string.find( lowered, "image" )
		or string.find( lowered, "minion" ) or string.find( lowered, "spawn" ) then
		return nil
	end

	for i = 1, getn( M.bosses ) do
		local boss = M.bosses[ i ]
		if boss.key == lowered or string.find( string.lower( boss.name ), lowered, 1, true ) then
			return boss
		end
		for j = 1, getn( boss.aliases ) do
			if has_word( lowered, boss.aliases[ j ] ) or string.find( boss.aliases[ j ], lowered, 1, true ) then
				return boss
			end
		end
	end
	return nil
end

local function realm_data()
	local wb = m.gdb and m.gdb.worldbosses
	if not wb or not wb.data or not m.realm then return EMPTY end
	return wb.data[ m.realm ] or EMPTY
end

local function char_data( char_name )
	if not char_name then return EMPTY end
	local rdata = realm_data()
	return rdata[ char_name ] or EMPTY
end

local function own_data()
	if not m.gdb or not m.realm or not m.player then return EMPTY end
	m.gdb.worldbosses = m.gdb.worldbosses or { version = 1, data = {}, ids = {} }
	m.gdb.worldbosses.data = m.gdb.worldbosses.data or {}
	m.gdb.worldbosses.data[ m.realm ] = m.gdb.worldbosses.data[ m.realm ] or {}
	local chars = m.gdb.worldbosses.data[ m.realm ]
	chars[ m.player ] = chars[ m.player ] or {}
	return chars[ m.player ]
end

local function own_ids()
	if not m.gdb or not m.realm or not m.player then return EMPTY end
	m.gdb.worldbosses = m.gdb.worldbosses or { version = 1, data = {}, ids = {} }
	m.gdb.worldbosses.ids = m.gdb.worldbosses.ids or {}
	m.gdb.worldbosses.ids[ m.realm ] = m.gdb.worldbosses.ids[ m.realm ] or {}
	local chars = m.gdb.worldbosses.ids[ m.realm ]
	chars[ m.player ] = chars[ m.player ] or {}
	return chars[ m.player ]
end

local function char_ids( char_name )
	if not char_name or not m.gdb or not m.realm then return EMPTY end
	local wb = m.gdb.worldbosses
	if not wb or not wb.ids or not wb.ids[ m.realm ] then return EMPTY end
	return wb.ids[ m.realm ][ char_name ] or EMPTY
end

local function kill_time( v )
	if type( v ) == "number" then return v end
	if type( v ) == "table" and type( v.t ) == "number" then return v.t end
	return nil
end

local function valid_id( id )
	if type( id ) ~= "string" then return false end
	if string.len( id ) < 4 or string.len( id ) > 24 then return false end
	local _, _, tag, code = string.find( id, "^([A-Z]+)%-([A-Z2-9]+)$" )
	if not tag or not code then return false end
	if string.len( code ) ~= ID_LEN then return false end
	return true
end

local function seed_random()
	if not D.random_seeded then
		local s = time() + math.floor( ( GetTime() or 0 ) * 1000 )
		math.randomseed( s )
		D.random_seeded = true
	end
end

local function new_kill_id( key )
	seed_random()
	local tag = string.upper( string.sub( key or "WB", 1, 4 ) )
	local code = ""
	local n = string.len( ID_CHARSET )
	for i = 1, ID_LEN do
		local r = math.random( n )
		if r < 1 then r = 1 end
		if r > n then r = n end
		code = code .. string.sub( ID_CHARSET, r, r )
	end
	return tag .. "-" .. code
end

local function find_server_instance( boss )
	if not m.instances then return nil end
	if m.instances[ boss.name ] then return m.instances[ boss.name ] end

	if boss.aliases then
		for i = 1, getn( boss.aliases ) do
			local alias = boss.aliases[ i ]
			for inst_name, inst_data in pairs( m.instances ) do
				local lowered = string.lower( inst_name )
				if lowered == alias or string.find( lowered, alias, 1, true ) then
					return inst_data
				end
			end
		end
	end
	return nil
end

-- Hybrid lockout resolver: queries server-side GetSavedInstanceInfo first,
-- then falls back to client-side recorded kill timestamp.
local function get_boss_lockout( boss, char_name )
	local now = time()

	-- Check server-side instance save if character is the current logged in player
	if char_name == m.player then
		local inst = find_server_instance( boss )
		if inst and inst.reset and inst.reset > 0 then
			local reset_at = ( inst.timestamp or now ) + inst.reset
			if reset_at > now then
				return reset_at, ( inst.id and tostring( inst.id ) or nil ), true
			end
		end
	end

	-- Fallback to client-side recorded kill timestamp
	local cdata = char_data( char_name )
	local t = kill_time( cdata[ boss.key ] )
	if type( t ) == "number" and ( t + M.LOCKOUT ) > now then
		local cids = char_ids( char_name )
		return t + M.LOCKOUT, cids[ boss.key ], false
	end

	return nil, nil, false
end

-- Safe pruning: two-pass table cleanup to prevent mutating tables during pairs() traversal
local function prune()
	local now = time()
	local wb = m.gdb and m.gdb.worldbosses
	if not wb or not wb.data then return end

	local empty_chars = {}
	local empty_realms = {}

	for realm, chars in pairs( wb.data ) do
		for name, kills in pairs( chars ) do
			local expired = {}
			for key, v in pairs( kills ) do
				local t = kill_time( v )
				if type( t ) ~= "number" or t <= 0 or ( t + M.LOCKOUT ) <= now or t > now + 86400 then
					table.insert( expired, key )
				end
			end
			for i = 1, getn( expired ) do
				kills[ expired[ i ] ] = nil
			end
			if next( kills ) == nil then
				table.insert( empty_chars, { realm = realm, name = name } )
			end
		end
	end

	for i = 1, getn( empty_chars ) do
		local e = empty_chars[ i ]
		if wb.data[ e.realm ] then
			wb.data[ e.realm ][ e.name ] = nil
			if next( wb.data[ e.realm ] ) == nil then
				table.insert( empty_realms, e.realm )
			end
		end
	end

	for i = 1, getn( empty_realms ) do
		wb.data[ empty_realms[ i ] ] = nil
	end

	-- Prune expired IDs
	if wb.ids then
		local empty_id_chars = {}
		local empty_id_realms = {}

		for realm, chars in pairs( wb.ids ) do
			for name, ids in pairs( chars ) do
				local expired_ids = {}
				for key, id in pairs( ids ) do
					local t = nil
					if wb.data and wb.data[ realm ] and wb.data[ realm ][ name ] then
						t = kill_time( wb.data[ realm ][ name ][ key ] )
					end
					if not valid_id( id ) or not t or ( t + M.LOCKOUT ) <= now then
						table.insert( expired_ids, key )
					end
				end
				for i = 1, getn( expired_ids ) do
					ids[ expired_ids[ i ] ] = nil
				end
				if next( ids ) == nil then
					table.insert( empty_id_chars, { realm = realm, name = name } )
				end
			end
		end

		for i = 1, getn( empty_id_chars ) do
			local e = empty_id_chars[ i ]
			if wb.ids[ e.realm ] then
				wb.ids[ e.realm ][ e.name ] = nil
				if next( wb.ids[ e.realm ] ) == nil then
					table.insert( empty_id_realms, e.realm )
				end
			end
		end

		for i = 1, getn( empty_id_realms ) do
			wb.ids[ empty_id_realms[ i ] ] = nil
		end
	end
end

-- Forward declaration of update_box
local update_box

-- ---------------------------------------------------------------------------
-- Calendar Box Widget
-- ---------------------------------------------------------------------------

local function on_row_enter()
	local boss = M.bosses[ this.index ]
	if not boss then return end
	local char_name = m.current_player or m.player
	local unlock_at, id, is_server = get_boss_lockout( boss, char_name )
	local now = time()

	GameTooltip:SetOwner( this, "ANCHOR_RIGHT" )
	GameTooltip:AddLine( boss.name, 1, 1, 1 )

	if unlock_at and unlock_at > now then
		local id_str = id and ( " [" .. id .. "]" ) or ""
		local src_str = is_server and " (Server)" or ""
		GameTooltip:AddLine( string.format( m.T[ "Locked for %s: %s" ], char_name, dhms( unlock_at - now ) .. id_str .. src_str ), C_RED[ 1 ], C_RED[ 2 ], C_RED[ 3 ], 1 )
	else
		GameTooltip:AddLine( char_name .. ": " .. m.T[ "Available" ], C_GREEN[ 1 ], C_GREEN[ 2 ], C_GREEN[ 3 ], 1 )
	end

	-- Also show other alts on this realm that are locked
	local alt_lines = {}
	local rdata = realm_data()
	for alt_name in pairs( rdata ) do
		if alt_name ~= char_name then
			local a_unlock = get_boss_lockout( boss, alt_name )
			if a_unlock and a_unlock > now then
				table.insert( alt_lines, alt_name .. " (" .. dhms( a_unlock - now ) .. ")" )
			end
		end
	end

	if getn( alt_lines ) > 0 then
		GameTooltip:AddLine( "Alts: " .. table.concat( alt_lines, ", " ), 0.8, 0.8, 0.8, 1 )
	end

	GameTooltip:Show()
end

local function on_row_leave()
	GameTooltip:Hide()
end

local function init_box( b )
	D.box = b

	if b.sub1 then
		b.sub1:SetText( "" )
		b.sub1:Hide()
	end

	if b.sub2 then
		b.sub2:SetText( "" )
		b.sub2:Hide()
	end

	-- Adjust header position for compact 184px bottom-row height
	if b.header then
		b.header:ClearAllPoints()
		b.header:SetPoint( "Top", b, "Top", 0, -10 )
	end

	-- Dedicated footer text anchored cleanly above the bottom border
	if not b.wb_footer then
		local footer = b:CreateFontString( nil, "OVERLAY", "TCFontTiny" )
		footer:SetPoint( "Bottom", b, "Bottom", 0, 6 )
		footer:SetPoint( "Left", b, "Left", 10, 0 )
		footer:SetPoint( "Right", b, "Right", -10, 0 )
		footer:SetJustifyH( "Center" )
		footer:SetTextColor( 0.8, 0.8, 0.8, 1 )
		b.wb_footer = footer
	end

	b.rows = {}
	for i = 1, getn( M.bosses ) do
		-- Anchor each row from TopLeft downwards (header ends around y = -34)
		local y = -36 - ( ( i - 1 ) * 11 )

		local hover = CreateFrame( "Frame", nil, b )
		hover:SetPoint( "TopLeft", b, "TopLeft", 6, y )
		hover:SetPoint( "TopRight", b, "TopRight", -6, y )
		hover:SetHeight( 11 )
		hover:EnableMouse( true )
		hover.index = i
		hover:SetScript( "OnEnter", on_row_enter )
		hover:SetScript( "OnLeave", on_row_leave )

		local dot = hover:CreateTexture( nil, "ARTWORK" )
		dot:SetTexture( "Interface\\Buttons\\WHITE8X8" )
		dot:SetWidth( 4 )
		dot:SetHeight( 4 )
		dot:SetPoint( "Left", hover, "Left", 4, 0 )

		local name = hover:CreateFontString( nil, "OVERLAY", "TCFontTiny" )
		name:SetPoint( "Left", dot, "Right", 4, 0 )
		name:SetJustifyH( "Left" )

		local status = hover:CreateFontString( nil, "OVERLAY", "TCFontTiny" )
		status:SetPoint( "Right", hover, "Right", -4, 0 )
		status:SetJustifyH( "Right" )

		b.rows[ i ] = { dot = dot, name = name, status = status, hover = hover }
	end

	update_box()
end

update_box = function()
	if not D.box or not D.box.rows then return end
	if not m.popup or not m.popup:IsVisible() then return end
	if not D.box.is_visible then return end

	local now = time()
	local char_name = m.current_player or m.player
	local plan = {}
	local sig = ( char_name or "" ) .. ";"
	local next_at = nil

	for i = 1, getn( M.bosses ) do
		local boss = M.bosses[ i ]
		local unlock_at, id = get_boss_lockout( boss, char_name )

		if unlock_at and unlock_at > now then
			local ds = dhms( unlock_at - now )
			if not next_at or unlock_at < next_at then next_at = unlock_at end
			sig = sig .. "L" .. ds .. ";"
			plan[ i ] = { text = ds, locked = true, id = id }
		else
			sig = sig .. "R;"
			plan[ i ] = { text = m.T[ "Ready" ], locked = false }
		end
	end

	local sub2_text
	if next_at then
		sub2_text = string.format( m.T[ "Next unlock: %s" ], dhms( next_at - now ) )
	else
		sub2_text = m.T[ "All world bosses available" ]
	end
	sig = sig .. sub2_text

	if sig == D.last_sig then return end
	D.last_sig = sig

	for i = 1, getn( M.bosses ) do
		local boss = M.bosses[ i ]
		local p = plan[ i ]
		local row = D.box.rows[ i ]
		local c = p.locked and C_RED or C_GREEN
		row.name:SetText( boss.name )
		row.name:SetTextColor( c[ 1 ], c[ 2 ], c[ 3 ], 1 )
		row.status:SetText( p.text )
		row.status:SetTextColor( c[ 1 ], c[ 2 ], c[ 3 ], 1 )
		row.dot:SetVertexColor( c[ 1 ], c[ 2 ], c[ 3 ], 1 )
	end

	if D.box.wb_footer then
		D.box.wb_footer:SetText( sub2_text )
	elseif D.box.sub2 then
		D.box.sub2:SetText( sub2_text )
	end
end

-- ---------------------------------------------------------------------------
-- Group Communication (SendAddonMessage over RAID/PARTY)
-- ---------------------------------------------------------------------------

local function group_channel()
	if GetNumRaidMembers and GetNumRaidMembers() > 0 then return "RAID" end
	if GetNumPartyMembers and GetNumPartyMembers() > 0 then return "PARTY" end
	return nil
end

local function send_kill_id( key, id, t )
	if not valid_id( id ) then return end
	local channel = group_channel()
	if channel and SendAddonMessage then
		SendAddonMessage( ADDON_PREFIX, "WBK:" .. key .. ":" .. id .. ":" .. t, channel )
		m.debug( "WB kill-ID sent: " .. key .. " " .. id )
	end
end

-- Merge received group ID: updates local ID if kill was recent without rebroadcasting
local function merge_id( key, id, t, now )
	if not valid_id( id ) then return end
	local odata = own_data()
	local o_t = kill_time( odata[ key ] )

	-- If we witnessed a local kill within the ID_WINDOW
	if o_t and math.abs( now - o_t ) <= ID_WINDOW then
		local ids = own_ids()
		local mine = ids[ key ]
		if mine == id then return end
		if not mine or id < mine then
			ids[ key ] = id
			D.last_sig = ""
			m.debug( "WB kill-ID converged: " .. key .. " " .. id )
		end
	elseif not o_t or ( o_t + M.LOCKOUT ) <= now then
		-- If client missed the local death event (e.g. released to graveyard)
		-- and packet is fresh within 60s
		if math.abs( now - t ) <= 60 then
			odata[ key ] = t
			local ids = own_ids()
			ids[ key ] = id
			D.last_sig = ""
			m.info( string.format( m.T[ "World boss kill recorded: %s" ], key .. " [" .. id .. "]" ) )
			update_box()
		end
	end
end

-- Handle /tc wb who queries
local function on_who_msg( msg, sender )
	local _, _, key, id = string.find( msg, "^WBWHO:([^:]+):([^:]+)$" )
	if key and id then
		if not valid_id( id ) then return end
		local mine = own_ids()[ key ]
		if not valid_id( mine ) then return end
		local channel = group_channel()
		if channel and SendAddonMessage then
			SendAddonMessage( ADDON_PREFIX, "WBANS:" .. key .. ":" .. mine, channel )
		end
		return
	end

	local _, _, akey, aid = string.find( msg, "^WBANS:([^:]+):([^:]+)$" )
	if akey and aid and D.who_pending and akey == D.who_pending.key then
		if not valid_id( aid ) then return end
		if ( GetTime() - D.who_pending.t ) > WHO_TIMEOUT then return end
		D.who_pending.replies[ sender ] = aid
	end
end

local function on_addon_msg( prefix, msg, channel, sender )
	if prefix ~= ADDON_PREFIX then return end
	if not msg or not sender or sender == "" or sender == m.player then return end

	local _, _, key, id, ts = string.find( msg, "^WBK:([^:]+):([^:]+):(%d+)$" )
	if key and id and ts then
		ts = tonumber( ts )
		if not ts then return end
		local boss_ok = false
		for i = 1, getn( M.bosses ) do
			if M.bosses[ i ].key == key then boss_ok = true break end
		end
		if not boss_ok then return end
		local now = time()
		if ts <= 0 or ts > now + 60 or ( ts + M.LOCKOUT ) <= now then return end
		merge_id( key, id, ts, now )
		return
	end

	on_who_msg( msg, sender )
end

-- Mint and broadcast a fresh group kill-ID upon local confirmation
local function accept_pending_kill()
	if not D.pending_key then return end
	local key = D.pending_key
	local name = D.pending_name or key
	local now = time()

	local data = own_data()
	data[ key ] = now

	local ids = own_ids()
	local id = ids[ key ]
	if not valid_id( id ) then
		id = new_kill_id( key )
		ids[ key ] = id
	end

	send_kill_id( key, id, now )
	m.info( string.format( m.T[ "World boss kill recorded: %s" ], name .. " [" .. id .. "]" ) )

	D.pending_key = nil
	D.pending_name = nil
	D.confirming = false
	D.last_sig = ""

	update_box()
end

-- ---------------------------------------------------------------------------
-- Lockout Sharing (Announce over SAY or GUILD)
-- ---------------------------------------------------------------------------

local function queue_share( channel )
	local now = time()
	local data = own_data()
	local ids = own_ids()
	local count = 0

	-- Clear any stale queued shares to prevent macro spam queue buildup
	D.share_queue = {}

	for i = 1, getn( M.bosses ) do
		local boss = M.bosses[ i ]
		local unlock_at, id = get_boss_lockout( boss, m.player )
		if unlock_at and unlock_at > now then
			local id_str = id and ( " [" .. id .. "]" ) or ""
			table.insert( D.share_queue, {
				channel = channel,
				text = string.format( "%s: locked %s%s", boss.name, dhms( unlock_at - now ), id_str )
			} )
			count = count + 1
			if count >= 12 then break end
		end
	end

	if count > 0 then
		m.info( string.format( m.T[ "Share queued: %d lockout(s)." ], count ) )
	else
		m.info( m.T[ "No world boss lockouts to share." ] )
	end
end

local function flush_share()
	if getn( D.share_queue ) == 0 then return end
	local now = GetTime()
	if now - D.last_send < 1 then return end

	local item = table.remove( D.share_queue, 1 )
	if item and SendChatMessage then
		SendChatMessage( item.text, item.channel )
	end
	D.last_send = now
end

-- ---------------------------------------------------------------------------
-- Event Frame & Ticker
-- ---------------------------------------------------------------------------

local function on_event()
	if event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" then
		if not m.db or not m.db.worldbosses_track then return end
		if D.confirming then return end

		local boss = find_boss( arg1 )
		if boss then
			local unlock_at = get_boss_lockout( boss, m.player )
			if unlock_at and unlock_at > time() then return end

			D.pending_key = boss.key
			D.pending_name = boss.name
			D.confirming = true
			StaticPopup_Show( "TURTLECALENDAR_WB_CONFIRM", boss.name )
		end
	elseif event == "CHAT_MSG_ADDON" then
		on_addon_msg( arg1, arg2, arg3, arg4 )
	elseif event == "PLAYER_REGEN_ENABLED" then
		if m.popup and m.popup:IsVisible() then
			update_box()
		end
	end
end

local function on_update()
	if ( this.wb_tick or 1 ) > GetTime() then return else this.wb_tick = GetTime() + 1 end

	flush_share()
	update_box()

	-- Check pending who check resolution
	if D.who_pending and ( GetTime() - D.who_pending.t ) > WHO_TIMEOUT then
		local p = D.who_pending
		local count = 0
		local matches = {}
		for sender, id in pairs( p.replies ) do
			count = count + 1
			if id == p.id then
				table.insert( matches, sender )
			end
		end
		if count > 0 then
			m.info( string.format( "Kill-ID check for %s: %d matches (%s)", p.key, getn( matches ), table.concat( matches, ", " ) ), true )
		end
		D.who_pending = nil
	end
end

-- ---------------------------------------------------------------------------
-- Slash Commands (/tc wb ...)
-- ---------------------------------------------------------------------------

local function slash_status()
	local now = time()
	local locked = {}

	for i = 1, getn( M.bosses ) do
		local boss = M.bosses[ i ]
		local unlock_at, id = get_boss_lockout( boss, m.player )
		if unlock_at and unlock_at > now then
			local entry = boss.name .. " " .. dhms( unlock_at - now )
			if valid_id( id ) then entry = entry .. " [" .. id .. "]" end
			table.insert( locked, entry )
		end
	end

	local count = getn( locked )
	if count > 0 then
		m.info( string.format( m.T[ "World bosses (%s): %d/%d locked" ], m.player, count, getn( M.bosses ) ) .. " - " .. table.concat( locked, ", " ), true )
	else
		m.info( string.format( m.T[ "World bosses (%s): all available" ], m.player ), true )
	end

	-- Report lockouts for other characters on this realm
	local others = {}
	local rdata = realm_data()
	for name in pairs( rdata ) do
		if name ~= m.player then
			local n = 0
			for i = 1, getn( M.bosses ) do
				local a_unlock = get_boss_lockout( M.bosses[ i ], name )
				if a_unlock and a_unlock > now then n = n + 1 end
			end
			if n > 0 then table.insert( others, name .. " (" .. n .. ")" ) end
		end
	end

	if getn( others ) > 0 then
		m.info( string.format( m.T[ "Other characters: %s" ], table.concat( others, ", " ) ), true )
	end
end

local function slash_log()
	local now = time()
	local data = own_data()
	local ids = own_ids()
	local any = false

	for i = 1, getn( M.bosses ) do
		local boss = M.bosses[ i ]
		local t = kill_time( data[ boss.key ] )
		if t then
			any = true
			local state = ( t + M.LOCKOUT ) > now and dhms( t + M.LOCKOUT - now ) or m.T[ "Ready" ]
			local line = boss.name .. ": " .. date( m.db.date_format or "%d.%m.%Y", t ) .. " -> " .. state
			if valid_id( ids[ boss.key ] ) then line = line .. " [" .. ids[ boss.key ] .. "]" end
			m.info( line, true )
		end
	end

	if not any then
		m.info( m.T[ "No world boss kills recorded." ], true )
	end
end

local function slash_who()
	local now = time()
	local data = own_data()
	local ids = own_ids()
	local key, name, t = nil, nil, nil

	for i = 1, getn( M.bosses ) do
		local boss = M.bosses[ i ]
		local bt = kill_time( data[ boss.key ] )
		if bt and ( bt + M.LOCKOUT ) > now and ( not t or bt > t ) then
			key, name, t = boss.key, boss.name, bt
		end
	end

	if not key then
		m.info( m.T[ "No world boss lockouts to share." ], true )
		return
	end

	local mine = ids[ key ]
	if not valid_id( mine ) then
		m.info( string.format( m.T[ "No kill-ID for %s yet." ], name ), true )
		return
	end

	D.who_pending = { key = key, id = mine, t = GetTime(), replies = {} }
	local channel = group_channel()
	if channel and SendAddonMessage then
		SendAddonMessage( ADDON_PREFIX, "WBWHO:" .. key .. ":" .. mine, channel )
	end
	m.info( string.format( m.T[ "Kill-ID check sent for %s [%s]." ], name, mine ), true )
end

local function slash_debug()
	local wb = m.gdb and m.gdb.worldbosses
	if not wb or not wb.data then
		m.info( "No world boss data.", true )
		return
	end

	for realm, chars in pairs( wb.data ) do
		for char, kills in pairs( chars ) do
			for key, v in pairs( kills ) do
				local t = kill_time( v )
				local id = nil
				if wb.ids and wb.ids[ realm ] and wb.ids[ realm ][ char ] then
					id = wb.ids[ realm ][ char ][ key ]
				end
				if id then
					m.info( string.format( "%s/%s/%s = %d [%s]", realm, char, key, t or 0, id ), true )
				else
					m.info( string.format( "%s/%s/%s = %d", realm, char, key, t or 0 ), true )
				end
			end
		end
	end
end

local function slash( args )
	args = args or ""
	if args == "" or string.find( args, "^help" ) then
		m.info( m.T[ "World boss commands:" ], true )
		m.info( m.T[ "/tc wb status - Show your world boss lockouts" ], true )
		m.info( m.T[ "/tc wb share [guild] - Share your lockouts" ], true )
		m.info( m.T[ "/tc wb who - Check kill-ID match with group" ], true )
		m.info( m.T[ "/tc wb log - List recorded world boss kills" ], true )
		m.info( m.T[ "/tc wb track - Toggle kill detection" ], true )
		m.info( m.T[ "/tc wb kill <boss> [days] - Record manual kill (e.g. /tc wb kill reaver)" ], true )
		m.info( m.T[ "/tc wb clear <boss> - Clear specific boss lockout" ], true )
		m.info( m.T[ "/tc wb reset - Clear all your world boss data" ], true )
		m.info( m.T[ "/tc wb test - Record test kills" ], true )
		m.info( m.T[ "/tc wb debug - Dump stored world boss data" ], true )
	elseif string.find( args, "^status" ) then
		slash_status()
	elseif string.find( args, "^share" ) then
		queue_share( string.find( args, "guild" ) and "GUILD" or "SAY" )
	elseif string.find( args, "^who" ) then
		slash_who()
	elseif string.find( args, "^log" ) then
		slash_log()
	elseif string.find( args, "^track" ) then
		m.db.worldbosses_track = not m.db.worldbosses_track
		m.info( m.db.worldbosses_track and m.T[ "World boss tracking is now on." ] or m.T[ "World boss tracking is now off." ] )
	elseif string.find( args, "^kill" ) then
		local _, _, target_boss, days_ago = string.find( args, "^kill%s+([%w'_%-]+)%s*(%d*)" )
		if target_boss then
			local b = find_boss( target_boss )
			if b then
				local now = time()
				local offset = tonumber( days_ago ) or 0
				local kill_ts = now - ( offset * 86400 )
				local data = own_data()
				local ids = own_ids()
				data[ b.key ] = kill_ts
				local id = ids[ b.key ]
				if not valid_id( id ) then
					id = new_kill_id( b.key )
					ids[ b.key ] = id
				end
				send_kill_id( b.key, id, kill_ts )
				D.last_sig = ""
				m.info( string.format( m.T[ "World boss kill recorded: %s" ], b.name .. " [" .. id .. "]" ), true )
				update_box()
				return
			end
		end
		m.info( "Usage: /tc wb kill <boss> [days_ago] (e.g. /tc wb kill reaver 2)", true )
	elseif string.find( args, "^clear" ) or string.find( args, "^unlock" ) then
		local _, _, target_boss = string.find( args, "^%w+%s+([%w'_%-]+)" )
		if target_boss then
			local b = find_boss( target_boss )
			if b then
				local data = own_data()
				local ids = own_ids()
				data[ b.key ] = nil
				ids[ b.key ] = nil
				D.last_sig = ""
				m.info( string.format( "Cleared lockout for %s.", b.name ), true )
				update_box()
				return
			end
		end
		m.info( "Usage: /tc wb clear <boss> (e.g. /tc wb clear reaver)", true )
	elseif string.find( args, "^reset" ) then
		if m.gdb and m.gdb.worldbosses then
			if m.gdb.worldbosses.data and m.gdb.worldbosses.data[ m.realm ] then
				m.gdb.worldbosses.data[ m.realm ][ m.player ] = nil
			end
			if m.gdb.worldbosses.ids and m.gdb.worldbosses.ids[ m.realm ] then
				m.gdb.worldbosses.ids[ m.realm ][ m.player ] = nil
			end
		end
		D.last_sig = ""
		m.info( string.format( m.T[ "World boss data cleared for %s." ], m.player ) )
		update_box()
	elseif string.find( args, "^test" ) then
		local data = own_data()
		local ids = own_ids()
		local now = time()
		data[ M.bosses[ 1 ].key ] = now
		ids[ M.bosses[ 1 ].key ] = new_kill_id( M.bosses[ 1 ].key )

		data[ M.bosses[ 2 ].key ] = now - 3 * 86400
		ids[ M.bosses[ 2 ].key ] = new_kill_id( M.bosses[ 2 ].key )

		data[ M.bosses[ 3 ].key ] = now - 6 * 86400
		ids[ M.bosses[ 3 ].key ] = new_kill_id( M.bosses[ 3 ].key )

		D.last_sig = ""
		m.info( string.format( m.T[ "Test kills recorded for %d bosses." ], 3 ) )
		update_box()
	elseif string.find( args, "^debug" ) then
		slash_debug()
	end
end

-- ---------------------------------------------------------------------------
-- Module Lifecycle
-- ---------------------------------------------------------------------------

function M.new()
	if m.db and m.db.worldbosses_track == nil then
		m.db.worldbosses_track = true
	end

	-- Global cross-character SavedVariables storage
	m.gdb = m.gdb or TurtleCalendarGlobalOptions or {}
	m.gdb.worldbosses = m.gdb.worldbosses or { version = 1, data = {}, ids = {} }
	m.gdb.worldbosses.version = 1
	m.gdb.worldbosses.data = m.gdb.worldbosses.data or {}
	m.gdb.worldbosses.ids = m.gdb.worldbosses.ids or {}

	prune()

	StaticPopupDialogs[ "TURTLECALENDAR_WB_CONFIRM" ] = {
		text = m.T[ "Record world boss kill of %s?" ],
		button1 = m.T[ "Record" ],
		button2 = m.T[ "Cancel" ],
		timeout = 0,
		whileDead = 1,
		hideOnEscape = 1,
		OnAccept = function()
			accept_pending_kill()
		end,
		OnCancel = function()
			D.pending_key = nil
			D.pending_name = nil
			D.confirming = false
		end,
		OnHide = function()
			D.pending_key = nil
			D.pending_name = nil
			D.confirming = false
		end,
	}

	local frame = CreateFrame( "Frame", nil, UIParent )
	frame:RegisterEvent( "CHAT_MSG_COMBAT_HOSTILE_DEATH" )
	frame:RegisterEvent( "CHAT_MSG_ADDON" )
	frame:RegisterEvent( "PLAYER_REGEN_ENABLED" )
	frame:SetScript( "OnEvent", on_event )
	frame:SetScript( "OnUpdate", on_update )
	D.event_frame = frame

	return {
		init_box = init_box,
		update_box = update_box,
		slash = slash,
	}
end

m.WorldBosses = M
return M