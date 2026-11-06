CompanionManager = CompanionManager or {}
---@class CompanionManager
local m = CompanionManager

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
			DEFAULT_CHAT_FRAME:AddMessage( string.format( "|cff71d5ff%s Help|r", m.name ) )
			DEFAULT_CHAT_FRAME:AddMessage( "|cff71d5ff/cm|r Toggle menu" )
			DEFAULT_CHAT_FRAME:AddMessage( "|cff71d5ff/cm toggle|r|||cff71d5ffshow|r|||cff71d5ffhide|r Toggle/show/hide the menu" )
			DEFAULT_CHAT_FRAME:AddMessage( "|cff71d5ff/cm icon-size|r Set icon size <|cffaaaaaasize|r>" )
			DEFAULT_CHAT_FRAME:AddMessage( "|cff71d5ff/cm reset-order|r Reset order of all icons" )
			DEFAULT_CHAT_FRAME:AddMessage( "|cff71d5ff/cm verbose|r Toggle showing companion name on summon" )
			DEFAULT_CHAT_FRAME:AddMessage( "|cff71d5ff/cm toys|r Toggle showing toys in menu" )
		end )

		register( { "icon-size", "iconsize", "is" }, function( args )
			local size = tonumber( args[ 1 ] )
			if not size then
				m.info( string.format( "Current icon size is %d", m.db.icon_size ) )
			elseif size and size >= 32 and size <= 64 then
				m.info( string.format( "Icon size set to %d.", size ) )
				m.update_size( size )
			else
				m.info( "Size must be between 32 and 64" )
			end
		end )

		register( "verbose", function()
			m.db.verbose = not m.db.verbose
			m.info( string.format( "Show companion name on summon: %s", m.db.verbose and "|cff00dd00ON|r" or "|cffdd0000OFF|r" ) )
		end )

		register( "toys", function()
			m.db.show_toys = not m.db.show_toys
			m.update_size( m.db.icon_size )

			m.info( string.format( "Show toys in menu: %s", m.db.show_toys and "|cff00dd00ON|r" or "|cffdd0000OFF|r" ) )
		end )

		register( "reset-order", function()
			m.db.companion_order = {}
			m.info( "Companion sort order has been reset." )
		end )

		register( "show", function() m.show() end )
		register( "hide", function() m.hide() end )
		register( "toggle", function() m.toggle() end )
	end

	return {
		register = register,
		init = init
	}
end

m.SlashCommand = M
return M
