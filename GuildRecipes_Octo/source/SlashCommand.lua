GuildRecipesOcto = GuildRecipesOcto or {}

---@class GuildRecipesOcto
local m = GuildRecipesOcto

if m.SlashCommand then return end

---@class SlashCommand
---@field register fun( command: string|string[], func: fun( args: string[] ) )
---@field init fun()
local M = {}

---@param name string
---@param slash_commands string|string[]
function M.new( name, slash_commands )
	local _G = getfenv()
	local commands = {}

	---@param command string
	---@return boolean
	local function has_command( command )
		for k, _ in pairs( commands ) do
			if k == command then return true end
		end
		return false
	end

	---@param command string
	---@return fun(args: string[])
	local function get_command( command )
		local cmd = commands[ command ]
		if cmd then return cmd else return commands[ "__DEFAULT__" ] end
	end

	---@param command string
	---@param args string[]
	local function handle_command( command, args )
		local cmd = get_command( command )
		if cmd then
			cmd( args )
		else
			m.info( string.format( "%q is not a valid command.", command ) )
		end
	end

	if type( slash_commands ) == "string" then
		slash_commands = { slash_commands }
	end

	for i, v in ipairs( slash_commands ) do
		_G[ "SLASH_" .. string.upper( name ) .. i ] = "/" .. v
	end

	SlashCmdList[ string.upper( name ) ] = function( msg )
		local args = {}
		local t = {}

		msg = string.gsub( msg, "^%s*(.-)%s*$", "%1" )
		for part in string.gmatch( msg, "%S+" ) do
			table.insert( args, part )
		end

		local command = args[ 1 ]
		if getn( args ) > 1 then
			for i = 2, getn( args ) do
				table.insert( t, args[ i ] )
			end
		end

		handle_command( command, t )
	end

	---@param command string|string[]
	---@param func fun(args: string[])
	local function register( command, func )
		if type( command ) == "string" then
			command = { command }
		end
		for _, v in pairs( command ) do
			if not has_command( v ) then
				if v ~= "__DEFAULT__" then v = string.lower( v ) end
				commands[ v ] = func
			end
		end
	end

	local function init()
		register( "__DEFAULT__", function()
			DEFAULT_CHAT_FRAME:AddMessage( string.format( "|c%s%s Help|r", m.tagcolor, m.name ) )
			DEFAULT_CHAT_FRAME:AddMessage( "|c" ..
			m.tagcolor .. "/gro toggle|r|||c" .. m.tagcolor .. "show|r|||c" .. m.tagcolor .. "hide|r Toggle/show/hide guild recipes" )
			DEFAULT_CHAT_FRAME:AddMessage( "|c" .. m.tagcolor .. "/gro remove_player|r <|cffaaaaaaPlayer|r> Remove player" )
			DEFAULT_CHAT_FRAME:AddMessage( "|c" .. m.tagcolor .. "/gro clear|r Clears all tradeskills" )
			DEFAULT_CHAT_FRAME:AddMessage( "|c" .. m.tagcolor .. "/gro refresh|r Request updated tradeskills from other players" )
			DEFAULT_CHAT_FRAME:AddMessage( "|c" .. m.tagcolor .. "/gro players|r List players with synced tradeskill data" )
			DEFAULT_CHAT_FRAME:AddMessage( "|c" .. m.tagcolor .. "/gro legacywarning|r Toggle whisper warnings to players using the old addon (default: off)" )
		end )

		register( { "toggle", "t" }, function()
			m.tsgui.toggle()
		end )

		register( { "show", "s" }, function()
			m.tsgui.show()
		end )

		register( { "hide", "s" }, function()
			m.tsgui.hide()
		end )

		register( { "refresh", "r" }, function()
			m.msg.request_tradeskills()
		end )

		register( { "players", "p" }, function()
			if not m.db.players or not next( m.db.players ) then
				m.info( "No players synced yet.", true )
				return
			end

			m.info( "Players with synced tradeskill data:", true )
			local online_roster = m.build_online_roster()
			for _, player in pairs( m.db.players ) do
				local tradeskills = {}
				for ts, recipes in pairs( m.db.tradeskills ) do
					if m.count_recipes( recipes, player ) > 0 then
						table.insert( tradeskills, ts )
					end
				end
				local online = online_roster[ player ] and "|cff00ff00online|r" or "|cffaaaaaaoffline|r"
				local ts_list = getn( tradeskills ) > 0 and table.concat( tradeskills, ", " ) or "none"
				m.info( string.format( "%s [%s] - %s", player, online, ts_list ), true )
			end
		end )

		register( { "clear", "c" }, function()
			m.db.tradeskills = {}
			m.db.tradeskills_last_update = {}
			m.db.players = {}
			m.info( "Cleared all tradeskill data.", true )
		end )

		register( { "remove_player", "rp" }, function( args )
			if args and args[ 1 ] then
				local player = args[ 1 ]
				local _, player_id = m.find( player, m.db.players )
				local found = false

				if player_id then
					for ts, tradeskill in pairs( m.db.tradeskills ) do
						for id, recipe in pairs( tradeskill ) do
							local players = m.comma_separated_to_table( recipe.p )
							local _, idx = m.find( tostring( player_id ), players )
							if idx then
								found = true
								table.remove( players, idx )
								recipe.p = m.table_to_comma_separated( players )
								if getn( players ) == 0 then
									-- No players left for this recipe, remove it
									tradeskill[ id ] = nil
								end
							end
						end
						if found then
							-- If we removed any recipes, send updated tradeskill
							m.msg.send_tradeskill( ts )
						end
						if not next( tradeskill ) then
							-- No recipes left for this tradeskill, remove it
							m.db.tradeskills[ ts ] = nil
						end
					end
					-- Remove player from player list
					m.db.players[ player_id ] = nil
				end
				if found then
					m.info( string.format( "Removed all recipes for %q", player ), true )
				else
					m.info( string.format( "No recipes found for %q", player ), true )
				end
			else
				m.info( "You must provide a player name.", true )
			end
		end )

		register( { "versioncheck", "vc" }, function()
			m.msg.version_check()
		end )

		register( "debug", function()
			m.debug_enabled = not m.debug_enabled
			if m.debug_enabled then
				m.info( "Debug is enabled", true )
			else
				m.info( "Debug is disabled", true )
			end
		end )

		register( { "legacywarning", "lw" }, function()
			m.legacy_warning_enabled = not m.legacy_warning_enabled
			if m.legacy_warning_enabled then
				m.info( "Legacy warning whispers enabled. Players using the old GuildRecipes addon will be notified.", true )
			else
				m.info( "Legacy warning whispers disabled.", true )
			end
		end )
	end

	return {
		register = register,
		init = init
	}
end

m.SlashCommand = M
return M
