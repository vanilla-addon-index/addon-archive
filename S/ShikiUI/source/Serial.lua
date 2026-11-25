-- ShikiUI Serial : serialisation texte sure (JAMAIS de loadstring sur une chaine importee).
-- Grammaire : valeur := nombre | "chaine" | true | false | { "cle":valeur , ... }
-- Format d'export : SUI1:<somme de controle sur 8 chiffres hexa>:<corps>
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local Serial = {}
SUI.Serial = Serial

local getn, tinsert = table.getn, table.insert
local MAXLEN = 60000
local MAXDEPTH = 6

local function esc(s)
	s = string.gsub(s, "\\", "\\\\")
	s = string.gsub(s, "\"", "\\\"")
	return s
end

local function ser(v, out, depth)
	local t = type(v)
	if t == "number" then
		if v ~= v or v == 1 / 0 or v == -1 / 0 then v = 0 end
		tinsert(out, string.format("%.14g", v))
	elseif t == "boolean" then
		tinsert(out, v and "true" or "false")
	elseif t == "string" then
		tinsert(out, "\"" .. esc(v) .. "\"")
	elseif t == "table" then
		if depth >= MAXDEPTH then error("table trop profonde") end
		local keys = {}
		for k, _ in pairs(v) do
			if type(v[k]) ~= "function" and type(v[k]) ~= "userdata" then tinsert(keys, tostring(k)) end
		end
		table.sort(keys)
		tinsert(out, "{")
		for i = 1, getn(keys) do
			local k = keys[i]
			local val = v[k]
			if val == nil then val = v[tonumber(k)] end
			if i > 1 then tinsert(out, ",") end
			tinsert(out, "\"" .. esc(k) .. "\":")
			ser(val, out, depth + 1)
		end
		tinsert(out, "}")
	else
		error("type non serialisable : " .. t)
	end
end

function Serial.Encode(v)
	local out = {}
	ser(v, out, 0)
	return table.concat(out)
end

-- Decodeur recursif : retourne la valeur, ou leve une erreur (a rattraper avec pcall).
local function parse(s)
	local pos, len = 1, string.len(s)

	local function fail(msg)
		error(msg .. " (position " .. pos .. ")")
	end

	local function str()
		pos = pos + 1
		local buf = {}
		while pos <= len do
			local c = string.sub(s, pos, pos)
			if c == "\\" then
				pos = pos + 1
				if pos > len then fail("echappement tronque") end
				tinsert(buf, string.sub(s, pos, pos))
				pos = pos + 1
			elseif c == "\"" then
				pos = pos + 1
				return table.concat(buf)
			else
				tinsert(buf, c)
				pos = pos + 1
			end
		end
		fail("chaine non terminee")
	end

	local value

	local function tbl(depth)
		if depth > MAXDEPTH then fail("table trop profonde") end
		pos = pos + 1
		local t = {}
		if string.sub(s, pos, pos) == "}" then
			pos = pos + 1
			return t
		end
		while true do
			if string.sub(s, pos, pos) ~= "\"" then fail("cle attendue") end
			local k = str()
			if string.sub(s, pos, pos) ~= ":" then fail("':' attendu") end
			pos = pos + 1
			t[k] = value(depth)
			local c = string.sub(s, pos, pos)
			pos = pos + 1
			if c == "}" then return t end
			if c ~= "," then fail("',' ou '}' attendu") end
		end
	end

	value = function(depth)
		local c = string.sub(s, pos, pos)
		if c == "{" then
			return tbl((depth or 0) + 1)
		elseif c == "\"" then
			return str()
		elseif string.sub(s, pos, pos + 3) == "true" then
			pos = pos + 4
			return true
		elseif string.sub(s, pos, pos + 4) == "false" then
			pos = pos + 5
			return false
		else
			local a = pos
			while pos <= len and string.find(string.sub(s, pos, pos), "[0-9%+%-%.eE]") do pos = pos + 1 end
			local n = tonumber(string.sub(s, a, pos - 1))
			if not n then fail("valeur invalide") end
			return n
		end
	end

	local v = value(0)
	if pos <= len then fail("donnees en trop") end
	return v
end

function Serial.Decode(s)
	if type(s) ~= "string" then return nil, "pas une chaine" end
	if string.len(s) > MAXLEN then return nil, "chaine trop longue" end
	local ok, res = pcall(parse, s)
	if not ok then return nil, tostring(res) end
	return res
end

function Serial.Checksum(s)
	local a, b = 1, 0
	for i = 1, string.len(s) do
		a = SUI.Mod(a + string.byte(s, i), 65521)
		b = SUI.Mod(b + a, 65521)
	end
	return string.format("%04x%04x", b, a)
end

function Serial.Pack(v)
	local body = Serial.Encode(v)
	return "SUI1:" .. Serial.Checksum(body) .. ":" .. body
end

function Serial.Unpack(s)
	if type(s) ~= "string" then return nil, "pas une chaine" end
	s = string.gsub(s, "^%s+", "")
	s = string.gsub(s, "%s+$", "")
	if string.sub(s, 1, 5) ~= "SUI1:" then return nil, "en-tete SUI1 absent" end
	local c = string.find(s, ":", 6, true)
	if not c then return nil, "somme de controle absente" end
	local sum = string.sub(s, 6, c - 1)
	local body = string.sub(s, c + 1)
	if sum ~= Serial.Checksum(body) then return nil, "somme de controle invalide" end
	return Serial.Decode(body)
end
