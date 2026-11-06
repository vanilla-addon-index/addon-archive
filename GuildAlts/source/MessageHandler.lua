GuildAlts = GuildAlts or {}

---@class GuildAlts
local m = GuildAlts

if m.MessageHandler then return end

---@type MessageCommand
local MessageCommand = {
	SendCharacter = "SCHAR",
	SendAlts = "SALTS",
	RequestAlts = "RALTS",
	Ping = "PING",
	Pong = "PONG",
	VersionCheck = "VERC",
	Version = "VER"
}

---@alias MessageCommand
---| "SCHAR"
---| "SALTS"
---| "RALTS"
---| "PING"
---| "PONG"
---| "VERC"
---| "VER"

---@alias CharacterName string  -- Max 12 characters (WoW limitation)

---@class MainCharacterEntry
---@field locked integer 				-- 1 if locked, 0 or nil if not
---@field alts CharacterName[]	-- List of alt names

---@class AltMap
---@field [CharacterName] MainCharacterEntry

---@class AceSerializer
---@field Serialize fun( self: any, ... ): string
---@field Deserialize fun( self: any, str: string ): any

---@class AceComm
---@field RegisterComm fun( self: any, prefix: string, method: function? )
---@field SendCommMessage fun( self: any, prefix: string, text: string, distribution: string, target: string?, prio: "BULK"|"NORMAL"|"ALERT"?, callbackFn: function?, callbackArg: any? )

---@alias NotAceTimer any
---@alias TimerId number

---@class AceTimer
---@field ScheduleTimer fun( self: NotAceTimer, callback: function, delay: number, ... ): TimerId
---@field ScheduleRepeatingTimer fun( self: NotAceTimer, callback: function, delay: number, arg: any ): TimerId
---@field CancelTimer fun( self: NotAceTimer, timer_id: number )
---@field TimeLeft fun( self: NotAceTimer, timer_id: number )

---@class MessageHandler
---@field send_character fun( character: AltMap )
---@field send_alts fun()
---@field request_alts fun()
---@field version_check fun()

local M = {}

function M.new()
	---@diagnostic disable-next-line: undefined-global
	local lib_stub = LibStub

	---@type AceSerializer
	local ace_serializer = lib_stub( "AceSerializer-3.0" )

	---@type AceComm
	local ace_comm = lib_stub( "AceComm-3.0" )

	---@type AceTimer
	local ace_timer = lib_stub( "AceTimer-3.0" )

	local pinging = false
	local best_ping = nil
	local alts_sent = false
	local var_names = {
		lu = "last_update",
		c = "count",
	}
	setmetatable( var_names, { __index = function( _, key ) return key end } );

	---@param t table
	local function decode( t )
		local l = {}
		for key, value in pairs( t ) do
			if type( value ) == "table" then
				value = decode( value )
			end
			l[ var_names[ key ] ] = value
		end
		return l
	end

	---@param command MessageCommand
	---@param data table?
	local function broadcast( command, data )
		m.debug( string.format( "Broadcasting %s", command ) )

		ace_comm:SendCommMessage( m.prefix, command .. "::" .. ace_serializer.Serialize( M, data ), "GUILD", nil, "NORMAL" )
	end

	---@param character AltMap
	local function send_character( character )
		broadcast( MessageCommand.SendCharacter, character )
	end

	local function send_alts()
		broadcast( MessageCommand.SendAlts, m.db.characters )
	end

	local function request_alts()
		pinging = true
		alts_sent = false
		best_ping = nil

		broadcast( MessageCommand.Ping, {
			c = m.count( m.db.characters )
		} )
	end

	local function version_check()
		broadcast( MessageCommand.VersionCheck )
	end

	---@param command string
	---@param data table
	---@param sender string
	local function on_command( command, data, sender )
		if command == MessageCommand.SendCharacter then
			--
			-- Receive single character
			--
			m.update_character( data )
		elseif command == MessageCommand.RequestAlts and data.player == m.player then
			--
			-- Receive request for all alts
			--
			send_alts()
		elseif command == MessageCommand.SendAlts then
			--
			-- Receive alts
			--
			for main, cdata in pairs( data ) do
				m.db.characters[ main ] = cdata
			end

			m.db.last_update = m.get_server_timestamp()
			m.build_alt_map()
		elseif command == MessageCommand.Ping then
			--
			-- Recive ping
			--
			broadcast( MessageCommand.Pong, {
				lu = m.db.last_update,
				c = m.count( m.db.characters )
			} )
		elseif command == MessageCommand.Pong and pinging then
			--
			-- Receive pong
			--
			if not best_ping or (data and ((data.last_update and data.last_update > best_ping.last_update) or (data.count and data.count > best_ping.count))) then
				best_ping = {
					player = sender,
					count = data.count or 0,
					last_update = data.last_update or 0
				}
			end

			if data and data.count < m.count( m.db.characters ) and not alts_sent then
				alts_sent = true
				send_alts()
			end

			if ace_timer:TimeLeft( M[ "ping_timer" ] ) == 0 then
				M[ "ping_timer" ] = ace_timer.ScheduleTimer( M, function()
					if pinging then
						pinging = false
						m.debug( "Fetching from " .. m.dump( best_ping ) )
						if best_ping.count and best_ping.count ~= m.count( m.db.characters ) then
							broadcast( MessageCommand.RequestAlts, { player = best_ping.player } )
						else
							m.debug( "Alt list is already up to date." )
						end
					end
				end, 2 )
			end
		elseif command == MessageCommand.VersionCheck then
			--
			-- Receive version request
			--
			broadcast( MessageCommand.Version, { requester = sender, version = m.version, class = m.player_class } )
		elseif command == MessageCommand.Version then
			--
			-- Receive version
			--
			if data.requester == m.player then
				m.info( string.format( "%s [v%s]", m.colorize_player_by_class( sender, data.class ), data.version ), true )
			end
		end
	end

	local function on_comm_received( prefix, data_str, _, sender )
		if prefix ~= m.prefix or sender == m.player then return end

		local command = string.match( data_str, "^(.-)::" )
		data_str = string.gsub( data_str, "^.-::", "" )

		m.debug( "Received " .. command )

		local success, data = ace_serializer.Deserialize( M, data_str )
		if success then
			if data then
				data = decode( data )
			end

			on_command( command, data, sender )
		else
			m.error( "Corrupt data in addon message!" )
		end
	end

	ace_comm.RegisterComm( M, m.prefix, on_comm_received )

	---@type MessageHandler
	return {
		send_character = send_character,
		send_alts = send_alts,
		request_alts = request_alts,
		version_check = version_check
	}
end

m.MessageHandler = M
return M
