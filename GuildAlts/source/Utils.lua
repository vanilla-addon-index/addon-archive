GuildAlts = GuildAlts or {}

---@class GuildAlts
local M = GuildAlts

---@param str string
---@return string|nil
function M.normalize_and_validate_name( str )
	if string.len( str ) > 12 then return nil end

	local normalized = string.upper( string.sub( str, 1, 1 ) ) .. string.lower( string.sub( str, 2 ) )

	if string.find( normalized, "^[A-Z][a-z]*$" ) then
		return normalized
	end

	return nil
end

---@param hex string
---@return number r
---@return number g
---@return number b
---@return number a
function M.hex_to_rgba( hex )
	local r, g, b, a = string.match( hex, "^#?(%x%x)(%x%x)(%x%x)(%x?%x?)$" )

	r, g, b = tonumber( r, 16 ) / 255, tonumber( g, 16 ) / 255, tonumber( b, 16 ) / 255
	a = a ~= "" and tonumber( a, 16 ) / 255 or 1
	return r, g, b, a
end

---@param name string
---@param class string
---@return string
function M.colorize_player_by_class( name, class )
	if not class then return name end
	local color = RAID_CLASS_COLORS[ string.upper( class ) ]
	if not color.colorStr then
		color.colorStr = string.format( "ff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255 )
	end
	return "|c" .. color.colorStr .. name .. "|r"
end

function M.get_server_timestamp()
	local server_hour, server_min = GetGameTime()
	local local_time = date( "*t" )

	local t = {
		year = local_time.year,
		month = local_time.month,
		day = local_time.day,
		hour = server_hour,
		min = server_min,
		sec = 0,
	}

	local hour_diff = server_hour - local_time.hour
	if hour_diff <= -20 then
		t.day = t.day + 1
	elseif hour_diff >= 20 then
		t.day = t.day - 1
	end

	return time( t )
end

---@param t table
---@return number
function M.count( t )
	local count = 0
	for _ in pairs( t ) do
		count = count + 1
	end

	return count
end

---@param message string
---@param short boolean?
function M.info( message, short )
	local tag = string.format( "|c%s%s|r", M.tagcolor, short and "GA" or "GuildAlts" )
	DEFAULT_CHAT_FRAME:AddMessage( string.format( "%s: %s", tag, message ) )
end

---@param message string
function M.error( message )
	local tag = string.format( "|c%s%s|r|cffff0000%s|r", M.tagcolor, "GA", "ERROR" )
	DEFAULT_CHAT_FRAME:AddMessage( string.format( "%s: %s", tag, message ) )
end

---@param message string
function M.debug( message )
	if M.debug_enabled then
		M.info( message, true )
	end
end

---@param o any
---@return string
function M.dump( o )
	if not o then return "nil" end
	if type( o ) ~= 'table' then return tostring( o ) end

	local entries = 0
	local s = "{"

	for k, v in pairs( o ) do
		if (entries == 0) then s = s .. " " end

		local key = type( k ) ~= "number" and '"' .. k .. '"' or k

		if (entries > 0) then s = s .. ", " end

		s = s .. "[" .. key .. "] = " .. M.dump( v )
		entries = entries + 1
	end

	if (entries > 0) then s = s .. " " end
	return s .. "}"
end

---@diagnostic disable-next-line: undefined-field
if not string.gmatch then string.gmatch = string.gfind end

---@diagnostic disable-next-line: duplicate-set-field
string.match = string.match or function( str, pattern )
	if not str then return nil end

	local _, _, r1, r2, r3, r4, r5, r6, r7, r8, r9 = string.find( str, pattern )
	return r1, r2, r3, r4, r5, r6, r7, r8, r9
end

---@diagnostic disable-next-line: lowercase-global
strtrim = strtrim or function( s )
	if type( s ) ~= "string" then
		return ""
	end
	return string.match( s, "^%s*(.-)%s*$" )
end
